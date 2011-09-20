#import "CTTabView.h"
#import "CTTabViewController.h"
#import "CTTabWindowController.h"
#import "CTTabStripView.h"
#import "NSWindow+CTThemed.h"

const CGFloat kInsetMultiplier = 2.0/3.0;
const CGFloat kControlPoint1Multiplier = 1.0/3.0;
const CGFloat kControlPoint2Multiplier = 3.0/8.0;
const NSTimeInterval kHoverShowDuration = 0.2;
const NSTimeInterval kHoverHoldDuration = 0.02;
const NSTimeInterval kHoverHideDuration = 0.4;
const NSTimeInterval kAlertShowDuration = 0.4;
const NSTimeInterval kAlertHoldDuration = 0.4;
const NSTimeInterval kAlertHideDuration = 0.4;
const NSTimeInterval kGlowUpdateInterval = 0.025;
const CGFloat kTearDistance = 36.0;
const NSTimeInterval kTearDuration = 0.333;
const CGFloat kRapidCloseDist = 2.5;

@interface CTTabView(Private)

- (void)resetLastGlowUpdateTime;
- (NSTimeInterval)timeElapsedSinceLastGlowUpdate;
- (void)adjustGlowValue;
- (NSBezierPath*)bezierPathForRect:(NSRect)rect;

@end

@implementation CTTabView {
    IBOutlet CTTabViewController* tabController_;
    IBOutlet HoverCloseButton* closeButton_;
    BOOL closing_;
    NSTrackingArea* closeTrackingArea_;
    
    BOOL isMouseInside_;
    AlertState alertState_;
    
    CGFloat hoverAlpha_;
    NSTimeInterval hoverHoldEndTime_;
    
    CGFloat alertAlpha_;
    NSTimeInterval alertHoldEndTime_;
    
    NSTimeInterval lastGlowUpdate_;
    
    NSPoint hoverPoint_;
    
    BOOL moveWindowOnDrag_;
    BOOL tabWasDragged_;
    BOOL draggingWithinTabStrip_;
    BOOL chromeIsVisible_;
    
    NSTimeInterval tearTime_;
    NSPoint tearOrigin_;
    NSPoint dragOrigin_;
    CTTabWindowController* sourceController_;
    NSWindow* sourceWindow_;
    NSRect sourceWindowFrame_;
    NSRect sourceTabFrame_;
    
    CTTabWindowController* draggedController_;
    NSWindow* dragWindow_;
    NSWindow* dragOverlay_;
    NSMutableDictionary* workspaceIDCache_;
    
    CTTabWindowController* targetController_;
    NSCellStateValue state_;
}

@synthesize state = state_;
@synthesize hoverAlpha = hoverAlpha_;
@synthesize alertAlpha = alertAlpha_;
@synthesize closing = closing_;

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setShowsDivider:NO];
        workspaceIDCache_ = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)awakeFromNib {
    [self setShowsDivider:NO];
}

- (void)dealloc {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

- (NSMenu*)menu {
    if ([self isClosing])
        return nil;
    
    if ([[self window] attachedSheet])
        return nil;
    
    return [tabController_ menu];
}

- (BOOL)acceptsFirstMouse:(NSEvent*)theEvent {
    return YES;
}

- (void)mouseEntered:(NSEvent*)theEvent {
    isMouseInside_ = YES;
    [self resetLastGlowUpdateTime];
    [self adjustGlowValue];
}

- (void)mouseMoved:(NSEvent*)theEvent {
    hoverPoint_ = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    [self setNeedsDisplay:YES];
}

- (void)mouseExited:(NSEvent*)theEvent {
    isMouseInside_ = NO;
    hoverHoldEndTime_ = [NSDate timeIntervalSinceReferenceDate] + kHoverHoldDuration;
    [self resetLastGlowUpdateTime];
    [self adjustGlowValue];
}

- (void)setTrackingEnabled:(BOOL)enabled {
    [closeButton_ setTrackingEnabled:enabled];
}

- (NSView*)hitTest:(NSPoint)aPoint {
    NSPoint viewPoint = [self convertPoint:aPoint fromView:[self superview]];
    NSRect frame = [self frame];
    
    NSRect hitRect = NSInsetRect(frame, frame.size.height / 3.0f, 0);
    if (![closeButton_ isHidden]) {
        if (NSPointInRect(viewPoint, [closeButton_ frame])) {
            return closeButton_;
        }
    }
    if (NSPointInRect(aPoint, hitRect)) {
        return self;
    }
    return nil;
}

- (BOOL)canBeDragged {
    if ([self isClosing]) {
        return NO;
    }
    NSWindowController* controller = [sourceWindow_ windowController];
    if ([controller isKindOfClass:[CTTabWindowController class]]) {
        CTTabWindowController* realController = (CTTabWindowController*) controller;
        return [realController isTabDraggable:self];
    }
    return YES;
}

- (NSArray*)dropTargetsForController:(CTTabWindowController*)dragController {
    NSMutableArray* targets = [NSMutableArray array];
    NSWindow* dragWindow = [dragController window];
    for (NSWindow* window in [NSApp orderedWindows]) {
        if (window == dragWindow) continue;
        if (![window isVisible]) continue;
        if ([window respondsToSelector:@selector(isOnActiveSpace)]) {
            if (![window performSelector:@selector(isOnActiveSpace)])
                continue;
        }
        NSWindowController* controller = [window windowController];
        if ([controller isKindOfClass:[CTTabWindowController class]]) {
            CTTabWindowController* realController = (CTTabWindowController*) controller;
            if ([realController canReceiveFrom:dragController])
                [targets addObject:controller];
        }
    }
    return targets;
}

- (void)resetDragControllers {
    draggedController_ = nil;
    dragWindow_ = nil;
    dragOverlay_ = nil;
    sourceController_ = nil;
    sourceWindow_ = nil;
    targetController_ = nil;
    [workspaceIDCache_ removeAllObjects];
}

- (void)setWindowBackgroundVisibility:(BOOL)shouldBeVisible {
    if (chromeIsVisible_ == shouldBeVisible) {
        return;
    }
    
    [[draggedController_ overlayWindow] setAlphaValue:1.0];
    if (targetController_) {
        [dragWindow_ setAlphaValue:0.0];
        [[draggedController_ overlayWindow] setHasShadow:YES];
        [[targetController_ window] makeMainWindow];
    } else {
        [dragWindow_ setAlphaValue:0.5];
        [[draggedController_ overlayWindow] setHasShadow:NO];
        [[draggedController_ window] makeMainWindow];
    }
    chromeIsVisible_ = shouldBeVisible;
}

- (void)mouseDown:(NSEvent*)theEvent {
    if ([self isClosing]) {
        return;
    }
    
    NSPoint downLocation = [theEvent locationInWindow];
    BOOL closeButtonActive = [closeButton_ isHidden] ? NO : YES;
    
    if (closeButtonActive && [tabController_ inRapidClosureMode]) {
        NSPoint hitLocation = [[self superview] convertPoint:downLocation fromView:nil];
        if ([self hitTest:hitLocation] == closeButton_) {
            [closeButton_ mouseDown:theEvent];
            return;
        }
    }
    
    if ([[tabController_ target] respondsToSelector:[tabController_ action]]) {
        [[tabController_ target] performSelector:[tabController_ action] withObject:self];
    }
    
    [self resetDragControllers];
    
    sourceWindow_ = [self window];
    if ([sourceWindow_ isKindOfClass:[NSPanel class]]) {
        sourceWindow_ = [sourceWindow_ parentWindow];
    }
    
    sourceWindowFrame_ = [sourceWindow_ frame];
    sourceTabFrame_ = [self frame];
    sourceController_ = [sourceWindow_ windowController];
    sourceController_.didShowNewTabButtonBeforeTemporalAction = sourceController_.showsNewTabButton;
    tabWasDragged_ = NO;
    tearTime_ = 0.0;
    draggingWithinTabStrip_ = YES;
    chromeIsVisible_ = NO;
    
    NSArray* targets = [self dropTargetsForController:sourceController_];
    moveWindowOnDrag_ = ([sourceController_ numberOfTabs] < 2 && ![targets count]) || ![self canBeDragged] || ![sourceController_ tabDraggingAllowed];
    if (!moveWindowOnDrag_) {
        draggingWithinTabStrip_ = [sourceController_ numberOfTabs] > 1;
    }
    
    if (!draggingWithinTabStrip_) {
        [sourceController_ willStartTearingTab];
    }
    
    dragOrigin_ = [NSEvent mouseLocation];
    
    CTTabViewController* controller = tabController_;
    while (1) {
        theEvent = [NSApp nextEventMatchingMask:NSLeftMouseUpMask | NSLeftMouseDraggedMask untilDate:[NSDate distantFuture] inMode:NSDefaultRunLoopMode dequeue:YES];
        NSEventType type = [theEvent type];
        if (type == NSLeftMouseDragged) {
            [self mouseDragged:theEvent];
        } else if (type == NSLeftMouseUp) {
            NSPoint upLocation = [theEvent locationInWindow];
            CGFloat dx = upLocation.x - downLocation.x;
            CGFloat dy = upLocation.y - downLocation.y;
            if (closeButtonActive && (dx*dx + dy*dy) <= kRapidCloseDist*kRapidCloseDist && [controller inRapidClosureMode]) {
                NSPoint hitLocation = [[self superview] convertPoint:[theEvent locationInWindow] fromView:nil];
                if ([self hitTest:hitLocation] == closeButton_) {
                    [controller closeTab:self];
                    break;
                }
            }
            
            [self mouseUp:theEvent];
            break;
        }
    }
}

- (void)mouseDragged:(NSEvent*)theEvent {
    if (moveWindowOnDrag_) {
        if ([sourceController_ windowMovementAllowed]) {
            NSPoint thisPoint = [NSEvent mouseLocation];
            NSPoint origin = sourceWindowFrame_.origin;
            origin.x += (thisPoint.x - dragOrigin_.x);
            origin.y += (thisPoint.y - dragOrigin_.y);
            [sourceWindow_ setFrameOrigin:NSMakePoint(origin.x, origin.y)];
        }
        return;
    }
    
    tabWasDragged_ = YES;
    
    if (draggingWithinTabStrip_) {
        NSPoint thisPoint = [NSEvent mouseLocation];
        CGFloat stretchiness = thisPoint.y - dragOrigin_.y;
        stretchiness = copysign(sqrtf(fabs(stretchiness))/sqrtf(kTearDistance), stretchiness) / 2.0;
        CGFloat offset = thisPoint.x - dragOrigin_.x;
        if (fabsf(offset) > 100) { 
            stretchiness = 0;
        }
        [sourceController_ insertPlaceholderForTab:self frame:NSOffsetRect(sourceTabFrame_, offset, 0) yStretchiness:stretchiness];
        BOOL stillVisible = [sourceController_ isTabFullyVisible:self];
        CGFloat tearForce = fabs(thisPoint.y - dragOrigin_.y);
        if ([sourceController_ tabTearingAllowed] && (tearForce > kTearDistance || !stillVisible)) {
            draggingWithinTabStrip_ = NO;
            [sourceController_ willStartTearingTab];
            dragOrigin_.x = thisPoint.x;
        } else {
            return;
        }
    }
    
    NSDate* targetDwellDate = nil;
    
    NSPoint thisPoint = [NSEvent mouseLocation];
    NSArray* targets = [self dropTargetsForController:draggedController_];
    CTTabWindowController* newTarget = nil;
    for (CTTabWindowController* target in targets) {
        NSRect windowFrame = [[target window] frame];
        if (NSPointInRect(thisPoint, windowFrame)) {
            [[target window] orderFront:self];
            NSRect tabStripFrame = [[target tabStripView] frame];
            tabStripFrame.origin = [[target window] convertBaseToScreen:tabStripFrame.origin];
            if (NSPointInRect(thisPoint, tabStripFrame)) {
                newTarget = target;
            }
            break;
        }
    }
    
    if (targetController_ != newTarget) {
        targetDwellDate = [NSDate date];
        [targetController_ removePlaceholder];
        targetController_ = newTarget;
        if (!newTarget) {
            tearTime_ = [NSDate timeIntervalSinceReferenceDate];
            tearOrigin_ = [dragWindow_ frame].origin;
        }
    }
    
    if (!draggedController_) {
        [sourceController_ removePlaceholder];
        
        draggedController_ = [sourceController_ detachTabToNewWindow:self];
        dragWindow_ = [draggedController_ window];
        [dragWindow_ setAlphaValue:0.0];
        if (![sourceController_ hasLiveTabs]) {
            sourceController_ = draggedController_;
            sourceWindow_ = dragWindow_;
        }
        
        [dragWindow_ setLevel:NSFloatingWindowLevel];
        [dragWindow_ setHasShadow:YES];
        [dragWindow_ orderFront:nil];
        [dragWindow_ makeMainWindow];
        [draggedController_ showOverlay];
        dragOverlay_ = [draggedController_ overlayWindow];
        draggedController_.didShowNewTabButtonBeforeTemporalAction =
        draggedController_.showsNewTabButton;
        draggedController_.showsNewTabButton = NO;
        tearTime_ = [NSDate timeIntervalSinceReferenceDate];
        tearOrigin_ = sourceWindowFrame_.origin;
    }
    
    if (!draggedController_ || !sourceController_) {
        return;
    }
    
    NSTimeInterval tearProgress = [NSDate timeIntervalSinceReferenceDate] - tearTime_;
    tearProgress /= kTearDuration;
    tearProgress = sqrtf(MAX(MIN(tearProgress, 1.0), 0.0));
    
    NSPoint origin = sourceWindowFrame_.origin;
    origin.x += (thisPoint.x - dragOrigin_.x);
    origin.y += (thisPoint.y - dragOrigin_.y);
    
    if (tearProgress < 1) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self];
        [self performSelector:@selector(mouseDragged:) withObject:theEvent afterDelay:1.0f/30.0f];
        
        origin.x = (1 - tearProgress) * tearOrigin_.x + tearProgress * origin.x;
        origin.y = (1 - tearProgress) * tearOrigin_.y + tearProgress * origin.y;
    }
    
    if (targetController_) {
        NSRect targetFrame = [[targetController_ window] frame];
        NSRect sourceFrame = [dragWindow_ frame];
        origin.y = NSMinY(targetFrame) +
        (NSHeight(targetFrame) - NSHeight(sourceFrame));
    }
    [dragWindow_ setFrameOrigin:NSMakePoint(origin.x, origin.y)];
    
    if (targetController_) {
        if (![[targetController_ window] isKeyWindow]) {
            [[targetController_ window] orderFront:nil];
            targetDwellDate = nil;
        }
        
        CTTabView* draggedTabView = (CTTabView*)[draggedController_ selectedTabView];
        NSRect tabFrame = [draggedTabView frame];
        tabFrame.origin = [dragWindow_ convertBaseToScreen:tabFrame.origin];
        tabFrame.origin = [[targetController_ window] convertScreenToBase:tabFrame.origin];
        tabFrame = [[targetController_ tabStripView] convertRect:tabFrame fromView:nil];
        [targetController_ insertPlaceholderForTab:self frame:tabFrame yStretchiness:0];
        [targetController_ layoutTabs];
    } else {
        [dragWindow_ makeKeyAndOrderFront:nil];
    }
    
    BOOL chromeShouldBeVisible = targetController_ == nil;
    [self setWindowBackgroundVisibility:chromeShouldBeVisible];
}

- (void)mouseUp:(NSEvent*)theEvent {
    if (moveWindowOnDrag_) {
        return;
    }
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    
    if (!sourceController_) {
        return;
    }
    
    draggedController_.showsNewTabButton = draggedController_.didShowNewTabButtonBeforeTemporalAction;
    
    if (draggingWithinTabStrip_) {
        if (tabWasDragged_) {
            assert([sourceController_ numberOfTabs]);
            [sourceController_ moveTabView:[sourceController_ selectedTabView] fromController:nil];
        }
    } else {
        [draggedController_ willEndTearingTab];
        if (targetController_) {
            NSView* draggedTabView = [draggedController_ selectedTabView];
            [targetController_ moveTabView:draggedTabView fromController:draggedController_];
            [[targetController_ window] display];
            [targetController_ showWindow:nil];
            [targetController_ didEndTearingTab];
        } else {
            [draggedController_ removeOverlay];
            if ([dragWindow_ isVisible]) {
                [dragWindow_ setAlphaValue:1.0];
                [dragOverlay_ setHasShadow:NO];
                [dragWindow_ setHasShadow:YES];
                [dragWindow_ makeKeyAndOrderFront:nil];
            }
            [[draggedController_ window] setLevel:NSNormalWindowLevel];
            [draggedController_ removePlaceholder];
            [draggedController_ didEndTearingTab];
        }
    }
    [sourceController_ removePlaceholder];
    chromeIsVisible_ = YES;
    
    [self resetDragControllers];
}

- (void)otherMouseUp:(NSEvent*)theEvent {
    if ([self isClosing])
        return;
    
    if ([theEvent buttonNumber] == 2) {
        NSPoint upLocation =
        [[self superview] convertPoint:[theEvent locationInWindow] fromView:nil];
        if ([self hitTest:upLocation]) {
            [tabController_ closeTab:self];
        }
    }
}

- (void)drawRect:(NSRect)dirtyRect {
    if ([tabController_ phantom]) {
        return;
    }
    
    NSGraphicsContext* context = [NSGraphicsContext currentContext];
    [context saveGraphicsState];
    [context setPatternPhase:[[self window] themePatternPhase]];
    
    NSRect rect = [self bounds];
    NSBezierPath* path = [self bezierPathForRect:rect];
    
    BOOL selected = [self state];
    if (!selected) {
        [[[self window] backgroundColor] set];
        [path fill];
        [[NSColor colorWithCalibratedWhite:1.0 alpha:0.3] set];
        [path fill];
    }
    
    [context saveGraphicsState];
    [path addClip];
    
    CGFloat hoverAlpha = [self hoverAlpha];
    CGFloat alertAlpha = [self alertAlpha];
    if (selected || hoverAlpha > 0 || alertAlpha > 0) {
        [context saveGraphicsState];
        CGContextRef cgContext = [context graphicsPort];
        CGContextBeginTransparencyLayer(cgContext, 0);
        if (!selected) {
            CGFloat backgroundAlpha = 0.8 * alertAlpha;
            backgroundAlpha += (1 - backgroundAlpha) * 0.5 * hoverAlpha;
            CGContextSetAlpha(cgContext, backgroundAlpha);
        }
        [path addClip];
        [context saveGraphicsState];
        [super drawBackground];
        [context restoreGraphicsState];
        
        if (!selected && hoverAlpha > 0) {
            NSGradient* glow = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedWhite:1.0
                                                                                                     alpha:1.0 * hoverAlpha]
                                                             endingColor:[NSColor colorWithCalibratedWhite:1.0
                                                                                                     alpha:0.0]];
            
            NSPoint point = hoverPoint_;
            point.y = NSHeight(rect);
            [glow drawFromCenter:point radius:0.0 toCenter:point radius:NSWidth(rect) / 3.0 options:NSGradientDrawsBeforeStartingLocation];
            
            [glow drawInBezierPath:path relativeCenterPosition:hoverPoint_];
        }
        
        CGContextEndTransparencyLayer(cgContext);
        [context restoreGraphicsState];
    }
    
    BOOL active = [[self window] isKeyWindow] || [[self window] isMainWindow];
    CGFloat borderAlpha = selected ? (active ? 0.3 : 0.2) : 0.2;
    NSColor* borderColor = [NSColor colorWithDeviceWhite:0.0 alpha:borderAlpha];
    NSColor* highlightColor = [NSColor colorWithCalibratedWhite:0xf7/255.0 alpha:1.0];
    if (selected) {
        NSAffineTransform* highlightTransform = [NSAffineTransform transform];
        [highlightTransform translateXBy:1.0 yBy:-1.0];
        NSBezierPath* highlightPath = [path copy];
        [highlightPath transformUsingAffineTransform:highlightTransform];
        [highlightColor setStroke];
        [highlightPath setLineWidth:1.0];
        [highlightPath stroke];
        highlightTransform = [NSAffineTransform transform];
        [highlightTransform translateXBy:-2.0 yBy:0.0];
        [highlightPath transformUsingAffineTransform:highlightTransform];
        [highlightPath stroke];
    }
    
    [context restoreGraphicsState];
    
    [context saveGraphicsState];
    [borderColor set];
    [path setLineWidth:1.0];
    [path stroke];
    [context restoreGraphicsState];
    
    if (!selected) {
        [path addClip];
        NSRect borderRect = rect;
        borderRect.origin.y = 1;
        borderRect.size.height = 1;
        [borderColor set];
        NSRectFillUsingOperation(borderRect, NSCompositeSourceOver);
        
        borderRect.origin.y = 0;
        [highlightColor set];
        NSRectFillUsingOperation(borderRect, NSCompositeSourceOver);
    }
    
    [context restoreGraphicsState];
}

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    if ([self window]) {
        [tabController_ updateTitleColor];
    }
}

- (void)setClosing:(BOOL)closing {
    closing_ = closing;
    if (closing) {
        [closeButton_ setTarget:nil];
        [closeButton_ setAction:nil];
    }
}

- (void)startAlert {
    if (alertState_ == kAlertNone) {
        alertState_ = kAlertRising;
        [self resetLastGlowUpdateTime];
        [self adjustGlowValue];
    }
}

- (void)cancelAlert {
    if (alertState_ != kAlertNone) {
        alertState_ = kAlertFalling;
        alertHoldEndTime_ =
        [NSDate timeIntervalSinceReferenceDate] + kGlowUpdateInterval;
        [self resetLastGlowUpdateTime];
        [self adjustGlowValue];
    }
}

- (BOOL)accessibilityIsIgnored {
    return NO;
}

- (NSArray*)accessibilityActionNames {
    NSArray* parentActions = [super accessibilityActionNames];
    return [parentActions arrayByAddingObject:NSAccessibilityPressAction];
}

- (NSArray*)accessibilityAttributeNames {
    NSMutableArray* attributes =
    [[super accessibilityAttributeNames] mutableCopy];
    [attributes addObject:NSAccessibilityTitleAttribute];
    [attributes addObject:NSAccessibilityEnabledAttribute];
    
    return attributes;
}

- (BOOL)accessibilityIsAttributeSettable:(NSString*)attribute {
    if ([attribute isEqual:NSAccessibilityTitleAttribute])
        return NO;
    
    if ([attribute isEqual:NSAccessibilityEnabledAttribute])
        return NO;
    
    return [super accessibilityIsAttributeSettable:attribute];
}

- (id)accessibilityAttributeValue:(NSString*)attribute {
    if ([attribute isEqual:NSAccessibilityRoleAttribute])
        return NSAccessibilityButtonRole;
    
    if ([attribute isEqual:NSAccessibilityTitleAttribute])
        return [tabController_ title];
    
    if ([attribute isEqual:NSAccessibilityEnabledAttribute])
        return [NSNumber numberWithBool:YES];
    
    if ([attribute isEqual:NSAccessibilityChildrenAttribute]) {
        NSArray* children = [super accessibilityAttributeValue:attribute];
        NSMutableArray* okChildren = [NSMutableArray array];
        for (id child in children) {
            if ([child isKindOfClass:[NSButtonCell class]])
                [okChildren addObject:child];
        }
        
        return okChildren;
    }
    
    return [super accessibilityAttributeValue:attribute];
}

@end

@implementation CTTabView (TabControllerInterface)

- (void)setController:(CTTabViewController*)controller {
    tabController_ = controller;
}
- (CTTabViewController*)controller { return tabController_; }

@end

@implementation CTTabView(Private)

- (void)resetLastGlowUpdateTime {
    lastGlowUpdate_ = [NSDate timeIntervalSinceReferenceDate];
}

- (NSTimeInterval)timeElapsedSinceLastGlowUpdate {
    return [NSDate timeIntervalSinceReferenceDate] - lastGlowUpdate_;
}

- (void)adjustGlowValue {
    const NSTimeInterval kNoUpdate = 1000000;
    
    NSTimeInterval nextUpdate = kNoUpdate;
    
    NSTimeInterval elapsed = [self timeElapsedSinceLastGlowUpdate];
    NSTimeInterval currentTime = [NSDate timeIntervalSinceReferenceDate];
    
    CGFloat hoverAlpha = [self hoverAlpha];
    if (isMouseInside_) {
        if (hoverAlpha < 1) {
            hoverAlpha = MIN(hoverAlpha + elapsed / kHoverShowDuration, 1);
            [self setHoverAlpha:hoverAlpha];
            nextUpdate = MIN(kGlowUpdateInterval, nextUpdate);
        }
    } else {
        if (currentTime >= hoverHoldEndTime_) {
            if (hoverAlpha > 0) {
                hoverAlpha = MAX(hoverAlpha - elapsed / kHoverHideDuration, 0);
                [self setHoverAlpha:hoverAlpha];
                nextUpdate = MIN(kGlowUpdateInterval, nextUpdate);
            }
        } else {
            nextUpdate = MIN(hoverHoldEndTime_ - currentTime, nextUpdate);
        }
    }
    
    CGFloat alertAlpha = [self alertAlpha];
    if (alertState_ == kAlertRising) {
        alertAlpha = MIN(alertAlpha + elapsed / kAlertShowDuration, 1);
        [self setAlertAlpha:alertAlpha];
        
        if (alertAlpha >= 1) {
            alertState_ = kAlertHolding;
            alertHoldEndTime_ = currentTime + kAlertHoldDuration;
            nextUpdate = MIN(kAlertHoldDuration, nextUpdate);
        } else {
            nextUpdate = MIN(kGlowUpdateInterval, nextUpdate);
        }
    } else if (alertState_ != kAlertNone) {
        if (alertAlpha > 0) {
            if (currentTime >= alertHoldEndTime_) {
                if (alertState_ == kAlertHolding) {
                    alertState_ = kAlertFalling;
                    nextUpdate = MIN(kGlowUpdateInterval, nextUpdate);
                } else {
                    assert(kAlertFalling == alertState_);
                    alertAlpha = MAX(alertAlpha - elapsed / kAlertHideDuration, 0);
                    [self setAlertAlpha:alertAlpha];
                    nextUpdate = MIN(kGlowUpdateInterval, nextUpdate);
                }
            } else {
                nextUpdate = MIN(alertHoldEndTime_ - currentTime, nextUpdate);
            }
        } else {
            alertState_ = kAlertNone;
        }
    }
    
    if (nextUpdate < kNoUpdate)
        [self performSelector:_cmd withObject:nil afterDelay:nextUpdate];
    
    [self resetLastGlowUpdateTime];
    [self setNeedsDisplay:YES];
}

- (NSBezierPath*)bezierPathForRect:(NSRect)rect {
    rect = NSInsetRect(rect, -0.5, -0.5);
    rect.size.height -= 1.0;
    
    NSPoint bottomLeft = NSMakePoint(NSMinX(rect), NSMinY(rect) + 2);
    NSPoint bottomRight = NSMakePoint(NSMaxX(rect), NSMinY(rect) + 2);
    NSPoint topRight =
    NSMakePoint(NSMaxX(rect) - kInsetMultiplier * NSHeight(rect),
                NSMaxY(rect));
    NSPoint topLeft =
    NSMakePoint(NSMinX(rect)  + kInsetMultiplier * NSHeight(rect),
                NSMaxY(rect));
    
    CGFloat baseControlPointOutset = NSHeight(rect) * kControlPoint1Multiplier;
    CGFloat bottomControlPointInset = NSHeight(rect) * kControlPoint2Multiplier;
    
    NSBezierPath* path = [NSBezierPath bezierPath];
    [path moveToPoint:NSMakePoint(bottomLeft.x - 1, bottomLeft.y - 2)];
    [path lineToPoint:NSMakePoint(bottomLeft.x - 1, bottomLeft.y)];
    [path lineToPoint:bottomLeft];
    [path curveToPoint:topLeft
         controlPoint1:NSMakePoint(bottomLeft.x + baseControlPointOutset,
                                   bottomLeft.y)
         controlPoint2:NSMakePoint(topLeft.x - bottomControlPointInset,
                                   topLeft.y)];
    [path lineToPoint:topRight];
    [path curveToPoint:bottomRight
         controlPoint1:NSMakePoint(topRight.x + bottomControlPointInset,
                                   topRight.y)
         controlPoint2:NSMakePoint(bottomRight.x - baseControlPointOutset,
                                   bottomRight.y)];
    [path lineToPoint:NSMakePoint(bottomRight.x + 1, bottomRight.y)];
    [path lineToPoint:NSMakePoint(bottomRight.x + 1, bottomRight.y - 2)];
    return path;
}

@end
