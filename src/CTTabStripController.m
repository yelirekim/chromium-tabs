#import "CTTabStripController.h"
#import "CTTabContents.h"
#import "CTBrowser.h"
#import "CTTabStripView.h"
#import "CTTabContentsViewController.h"
#import "CTTabViewController.h"
#import "CTTabView.h"
#import "CTTabStripModel.h"
#import "CTBrowserCommand.h"

#import <QuartzCore/QuartzCore.h>

NSString* const kTabStripNumberOfTabsChanged = @"kTabStripNumberOfTabsChanged";

const CGFloat kUseFullAvailableWidth = -1.0;
const CGFloat kTabOverlap = 10.0;
const CGFloat kIconWidthAndHeight = 16.0;
const CGFloat kNewTabButtonOffset = 8.0;
const CGFloat kIncognitoBadgeTabStripShrink = 18;
const NSTimeInterval kAnimationDuration = 0.125;

@interface CTTabStripController (Private)
- (void)addSubviewToPermanentList:(NSView*)aView;
- (void)regenerateSubviewListWithOrderedArray:(NSArray*)orderedSubviews delayed:(NSArray*)delayedIndices;
- (NSInteger)indexForContentsView:(NSView*)view;
- (void)updateFavIconForContents:(CTTabContents*)contents atIndex:(NSInteger)modelIndex;
- (void)layoutTabsWithAnimation:(BOOL)animate regenerateSubviews:(BOOL)doUpdate;
- (void)animationDidStopForController:(CTTabViewController*)controller finished:(BOOL)finished;
- (NSInteger)indexFromModelIndex:(NSInteger)index;
- (NSInteger)numberOfOpenTabs;
- (void)mouseMoved:(NSEvent*)event;
- (void)setTabTrackingAreasEnabled:(BOOL)enabled;
- (void)setNewTabButtonHoverState:(BOOL)showHover;
- (CTTabViewController*)newTab;
- (void)setTabTitle:(NSViewController*)tab withContents:(CTTabContents*)contents;
- (void)swapInTabAtIndex:(NSInteger)modelIndex;
- (void)startClosingTabWithAnimation:(CTTabViewController*)closingTab;
- (void)removeTab:(CTTabViewController*)controller;
@end


@interface TabStripControllerDragBlockingView : NSView {
    CTTabStripController* controller_;
}

- (id)initWithFrame:(NSRect)frameRect
         controller:(CTTabStripController*)controller;
@end

@implementation TabStripControllerDragBlockingView
- (BOOL)mouseDownCanMoveWindow {return NO;}
- (void)drawRect:(NSRect)rect {}

- (id)initWithFrame:(NSRect)frameRect
         controller:(CTTabStripController*)controller {
    if ((self = [super initWithFrame:frameRect]))
        controller_ = controller;
    return self;
}

- (void)mouseDown:(NSEvent*)event {
    if ([controller_ inRapidClosureMode]) {
        NSView* superview = [self superview];
        NSPoint hitLocation =
        [[superview superview] convertPoint:[event locationInWindow]
                                   fromView:nil];
        NSView* hitView = [superview hitTest:hitLocation];
        if (hitView != self) {
            [hitView mouseDown:event];
            return;
        }
    }
    [super mouseDown:event];
}
@end

#pragma mark -

@interface TabCloseAnimationDelegate : NSObject {
@private
    CTTabStripController* strip_;
    CTTabViewController* controller_;
}

- (id)initWithTabStrip:(CTTabStripController*)strip tabController:(CTTabViewController*)controller;

- (void)invalidate;
- (void)animationDidStop:(CAAnimation*)animation finished:(BOOL)finished;

@end

@implementation TabCloseAnimationDelegate

- (id)initWithTabStrip:(CTTabStripController*)strip tabController:(CTTabViewController*)controller {
    if (nil != (self = [super init])) {
        assert(strip && controller);
        strip_ = strip;
        controller_ = controller;
    }
    return self;
}

- (void)invalidate {
    strip_ = nil;
    controller_ = nil;
}

- (void)animationDidStop:(CAAnimation*)animation finished:(BOOL)finished {
    [strip_ animationDidStopForController:controller_ finished:finished];
}

@end

#pragma mark -


@implementation CTTabStripController {
    BOOL verticalLayout_;
    CTTabContents* currentTab_;
    CTTabStripView* tabStripView_;
    NSView* switchView_;
    NSView* dragBlockingView_;
    NSTrackingArea* newTabTrackingArea_;
    CTBrowser *browser_;
    CTTabStripModel* tabStripModel2_;
    BOOL newTabButtonShowingHoverImage_;
    NSMutableArray* tabContentsArray_;
    NSMutableArray* tabArray_;
    NSMutableSet* closingControllers_;
    CTTabView* placeholderTab_;
    NSRect placeholderFrame_;
    CGFloat placeholderStretchiness_;
    NSRect droppedTabFrame_;
    NSMutableDictionary* targetFrames_;
    NSRect newTabTargetFrame_;
    BOOL forceNewTabButtonHidden_;
    BOOL initialLayoutComplete_;
    float availableResizeWidth_;
    NSTrackingArea* trackingArea_;
    CTTabView* hoveredTab_;
    NSMutableArray* permanentSubviews_;
    NSImage* defaultFavIcon_;
    CGFloat indentForControls_;
    BOOL mouseInside_;
    BOOL isDetachingTab_;
    
    id ob1;
    id ob2;
    id ob3;
    id ob4;
    id ob5;
}

@synthesize indentForControls = indentForControls_;

- (id)initWithView:(CTTabStripView*)view switchView:(NSView*)switchView browser:(CTBrowser*)browser {
    assert(view && switchView && browser);
    if ((self = [super init])) {
        tabStripView_ = view;
        switchView_ = switchView;
        browser_ = browser;
        tabStripModel2_ = [browser_ tabStripModel2];
        
        tabContentsArray_ = [[NSMutableArray alloc] init];
        tabArray_ = [[NSMutableArray alloc] init];
        
        permanentSubviews_ = [[NSMutableArray alloc] init];
        
        defaultFavIcon_ = nil;
        
        [self setIndentForControls:[[self class] defaultIndentForControls]];
        
        targetFrames_ = [[NSMutableDictionary alloc] init];
        
        dragBlockingView_ = 
        [[TabStripControllerDragBlockingView alloc] initWithFrame:NSZeroRect
                                                       controller:self];
        [self addSubviewToPermanentList:dragBlockingView_];
        
        newTabTargetFrame_ = NSMakeRect(0, 0, 0, 0);
        availableResizeWidth_ = kUseFullAvailableWidth;
        
        closingControllers_ = [[NSMutableSet alloc] init];
        
        [[NSNotificationCenter defaultCenter]
         addObserver:self
         selector:@selector(tabViewFrameChanged:)
         name:NSViewFrameDidChangeNotification
         object:tabStripView_];
        
        trackingArea_ = [[NSTrackingArea alloc]
                         initWithRect:NSZeroRect  // Ignored by NSTrackingInVisibleRect
                         options:NSTrackingMouseEnteredAndExited |
                         NSTrackingMouseMoved |
                         NSTrackingActiveAlways |
                         NSTrackingInVisibleRect
                         owner:self
                         userInfo:nil];
        [tabStripView_ addTrackingArea:trackingArea_];
        
        NSPoint mouseLoc = [[view window] mouseLocationOutsideOfEventStream];
        mouseLoc = [view convertPoint:mouseLoc fromView:nil];
        if (NSPointInRect(mouseLoc, [view bounds])) {
            [self setTabTrackingAreasEnabled:YES];
            mouseInside_ = YES;
        }
        
        ob1 = [[NSNotificationCenter defaultCenter] addObserverForName:kCTTabInsertedNotification object:tabStripModel2_ queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification* notification) {
            NSDictionary* userInfo = notification.userInfo;
            CTTabContents* contents = [userInfo objectForKey:kCTTabContentsUserInfoKey];
            NSInteger modelIndex = [[userInfo valueForKey:kCTTabIndexUserInfoKey] intValue];
            BOOL inForeground = [[userInfo objectForKey:kCTTabForegroundUserInfoKey] boolValue];
            assert(contents);
            assert(modelIndex == kNoTab || [tabStripModel2_ containsIndex:modelIndex]);
            
            NSInteger index = [self indexFromModelIndex:modelIndex];
            
            CTTabContentsViewController* contentsController =
            [browser_ createTabContentsControllerWithContents:contents];
            [tabContentsArray_ insertObject:contentsController atIndex:index];
            
            CTTabViewController* newController = [self newTab];
            [tabArray_ insertObject:newController atIndex:index];
            CTTabView* newView = (CTTabView*)[newController view];
            newView.tabStyle = kTabStyleShowBoth;
            
            [newView setFrame:NSOffsetRect([newView frame],
                                           0, -[[self class] defaultTabHeight])];
            
            [self setTabTitle:newController withContents:contents];
            
            availableResizeWidth_ = kUseFullAvailableWidth;
            
            if (!inForeground) {
                [self layoutTabs];
            }
            
            [self updateFavIconForContents:contents atIndex:modelIndex];
            
            [[NSNotificationCenter defaultCenter]
             postNotificationName:kTabStripNumberOfTabsChanged
             object:self];
        }];
        
        ob2 = [[NSNotificationCenter defaultCenter] addObserverForName:kCTTabSelectedNotification object:tabStripModel2_ queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification* notification) {
            NSDictionary* userInfo = notification.userInfo;
            CTTabContents* oldContents = [userInfo objectForKey:kCTTabContentsUserInfoKey];
            CTTabContents* newContents = [userInfo objectForKey:kCTTabNewContentsUserInfoKey];
            NSInteger modelIndex = [[userInfo valueForKey:kCTTabIndexUserInfoKey] intValue];
            
            NSInteger index = [self indexFromModelIndex:modelIndex];
            
            if (oldContents) {
                NSInteger oldModelIndex = [tabStripModel2_ indexOfTabContents:oldContents];
                if (oldModelIndex != -1) {  // When closing a tab, the old tab may be gone.
                    NSInteger oldIndex = [self indexFromModelIndex:oldModelIndex];
                    CTTabContentsViewController* oldController = [tabContentsArray_ objectAtIndex:oldIndex];
                    [oldController willResignSelectedTab];
                }
            }
            
            int i = 0;
            for (CTTabViewController* current in tabArray_) {
                [current setSelected:(i == index) ? YES : NO];
                ++i;
            }
            
            CTTabContentsViewController *newController =
            [tabContentsArray_ objectAtIndex:index];
            [newController willBecomeSelectedTab];
            
            [self layoutTabs];
            
            [self swapInTabAtIndex:modelIndex];
            
            if (newContents) {
                newContents.isVisible = oldContents.isVisible;
                newContents.isSelected = YES;
            }
            if (oldContents) {
                oldContents.isVisible = NO;
                oldContents.isSelected = NO;
            }
        }];
        
        ob3 = [[NSNotificationCenter defaultCenter] addObserverForName:kCTTabMovedNotification object:tabStripModel2_ queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification* notification) {
            NSDictionary* userInfo = notification.userInfo;
            NSInteger modelFrom = [[userInfo valueForKey:kCTTabIndexUserInfoKey] intValue];
            NSInteger modelTo = [[userInfo valueForKey:kCTTabToIndexUserInfoKey] intValue];
            NSInteger from = [self indexFromModelIndex:modelFrom];
            NSInteger to = [self indexFromModelIndex:modelTo];
            
            CTTabContentsViewController* movedTabContentsController = [tabContentsArray_ objectAtIndex:from];
            [tabContentsArray_ removeObjectAtIndex:from];
            [tabContentsArray_ insertObject:movedTabContentsController atIndex:to];
            CTTabViewController* movedTabController = [tabArray_ objectAtIndex:from];
            assert([movedTabController isKindOfClass:[CTTabViewController class]]);
            [tabArray_ removeObjectAtIndex:from];
            [tabArray_ insertObject:movedTabController atIndex:to];
        }];
        
        ob4 = [[NSNotificationCenter defaultCenter] addObserverForName:kCTTabChangedNotification object:tabStripModel2_ queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification* notification) {
            NSDictionary* userInfo = notification.userInfo;
            CTTabContents* contents = [userInfo objectForKey:kCTTabContentsUserInfoKey];
            NSInteger modelIndex = [[userInfo valueForKey:kCTTabIndexUserInfoKey] intValue];
            CTTabChangeType change = (CTTabChangeType)[[userInfo valueForKey:kCTTabOptionsUserInfoKey] intValue];
            NSInteger index = [self indexFromModelIndex:modelIndex];
            
            if (change == CTTabChangeTypeTitleNotLoading) {
                return;
            }
            
            CTTabViewController* tabController = [tabArray_ objectAtIndex:index];
            
            if (change != CTTabChangeTypeLoadingOnly) {
                [self setTabTitle:tabController withContents:contents];
            }
            
            [self updateFavIconForContents:contents atIndex:modelIndex];
            
            CTTabContentsViewController* updatedController = [tabContentsArray_ objectAtIndex:index];
            [updatedController tabDidChange:contents];
        }];
        
        ob5 = [[NSNotificationCenter defaultCenter] addObserverForName:kCTTabDetachedNotification object:tabStripModel2_ queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification* notification) {
            NSDictionary* userInfo = notification.userInfo;
            NSInteger modelIndex = [[userInfo valueForKey:kCTTabIndexUserInfoKey] intValue];
            NSInteger index = [self indexFromModelIndex:modelIndex];
            
            CTTabViewController* tab = [tabArray_ objectAtIndex:index];
            if ([tabStripModel2_ count] > 0) {
                [self startClosingTabWithAnimation:tab];
                isDetachingTab_ = YES;
                [self layoutTabs];
                isDetachingTab_ = NO;
            } else {
                [self removeTab:tab];
            }
            
            [[NSNotificationCenter defaultCenter] postNotificationName:kTabStripNumberOfTabsChanged object:self];
        }];
    }
    return self;
}

- (void)dealloc {
    if (trackingArea_)
        [tabStripView_ removeTrackingArea:trackingArea_];
    
    for (CTTabViewController* controller in closingControllers_) {
        NSView* view = [controller view];
        [[[view animationForKey:@"frameOrigin"] delegate] invalidate];
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:ob1];
    [[NSNotificationCenter defaultCenter] removeObserver:ob2];
    [[NSNotificationCenter defaultCenter] removeObserver:ob3];
    [[NSNotificationCenter defaultCenter] removeObserver:ob4];
    [[NSNotificationCenter defaultCenter] removeObserver:ob5];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

+ (CGFloat)defaultTabHeight {
    return 25.0;
}

+ (CGFloat)defaultIndentForControls {
    return 68.0;
}

- (void)swapInTabAtIndex:(NSInteger)modelIndex {
    assert(modelIndex >= 0 && modelIndex < [tabStripModel2_ count]);
    NSInteger index = [self indexFromModelIndex:modelIndex];
    CTTabContentsViewController* controller = [tabContentsArray_ objectAtIndex:index];
    
    NSView* newView = [controller view];
    NSRect frame = [switchView_ bounds];
    [newView setFrame:frame];
    [controller ensureContentsVisible];
    
    NSArray* subviews = [switchView_ subviews];
    if ([subviews count]) {
        NSView* oldView = [subviews objectAtIndex:0];
        [switchView_ replaceSubview:oldView with:newView];
    } else {
        [switchView_ addSubview:newView];
    }
}

- (CTTabViewController*)newTab {
    CTTabViewController* controller = [[CTTabViewController alloc] init];
    [controller setTarget:self];
    [controller setAction:@selector(selectTab:)];
    [[controller view] setHidden:YES];
    
    return controller;
}

- (NSInteger)numberOfOpenTabs {
    return [tabStripModel2_ count];
}

- (NSInteger)indexFromModelIndex:(NSInteger)index {
    assert(index >= 0);
    if (index < 0)
        return index;
    
    NSInteger i = 0;
    for (CTTabViewController* controller in tabArray_) {
        if ([closingControllers_ containsObject:controller] && i == index) {
            assert([(CTTabView*)[controller view] isClosing]);
            ++index;
        }
        if (i == index)  // No need to check anything after, it has no effect.
            break;
        ++i;
    }
    return index;
}

- (NSInteger)modelIndexForTabView:(NSView*)view {
    NSInteger index = 0;
    for (CTTabViewController* current in tabArray_) {
        if ([closingControllers_ containsObject:current])
            continue;
        else if ([current view] == view)
            return index;
        ++index;
    }
    return -1;
}

- (NSInteger)modelIndexForContentsView:(NSView*)view {
    NSInteger index = 0;
    NSInteger i = 0;
    for (CTTabContentsViewController* current in tabContentsArray_) {
        // If the CTTabController corresponding to |current| is closing, skip it.
        CTTabViewController* controller = [tabArray_ objectAtIndex:i];
        if ([closingControllers_ containsObject:controller]) {
            ++i;
            continue;
        } else if ([current view] == view) {
            return index;
        }
        ++index;
        ++i;
    }
    return -1;
}

- (NSView*)viewAtIndex:(NSUInteger)index {
    if (index >= [tabArray_ count])
        return NULL;
    return [[tabArray_ objectAtIndex:index] view];
}

- (void)selectTab:(id)sender {
    assert([sender isKindOfClass:[NSView class]]);
    NSInteger index = [self modelIndexForTabView:sender];
    if ([tabStripModel2_ containsIndex:index]) {
        [tabStripModel2_ selectTabContentsAtIndex:index userGesture:YES];
    }
}

- (void)closeTab:(id)sender {
    assert([sender isKindOfClass:[CTTabView class]]);
    if ([hoveredTab_ isEqual:sender]) {
        hoveredTab_ = nil;
    }
    
    NSInteger index = [self modelIndexForTabView:sender];
    if (![tabStripModel2_ containsIndex:index])
        return;
    
    const NSInteger numberOfOpenTabs = [self numberOfOpenTabs];
    if (numberOfOpenTabs > 1) {
        bool isClosingLastTab = index == numberOfOpenTabs - 1;
        if (!isClosingLastTab) {
            NSView* penultimateTab = [self viewAtIndex:numberOfOpenTabs - 2];
            availableResizeWidth_ = NSMaxX([penultimateTab frame]);
        } else {
            NSView* lastTab = [self viewAtIndex:numberOfOpenTabs - 1];
            availableResizeWidth_ = NSMaxX([lastTab frame]);
        }
        [tabStripModel2_ closeTabContentsAtIndex:index options: CLOSE_USER_GESTURE | CLOSE_CREATE_HISTORICAL_TAB];
    } else {
        [[tabStripView_ window] performClose:nil];
    }
}

- (void)insertPlaceholderForTab:(CTTabView*)tab
                          frame:(NSRect)frame
                  yStretchiness:(CGFloat)yStretchiness {
    placeholderTab_ = tab;
    placeholderFrame_ = frame;
    placeholderStretchiness_ = yStretchiness;
    [self layoutTabsWithAnimation:initialLayoutComplete_ regenerateSubviews:YES];
}

- (BOOL)isTabFullyVisible:(CTTabView*)tab {
    NSRect frame = [tab frame];
    return NSMinX(frame) >= [self indentForControls] &&
    NSMaxX(frame) <= NSMaxX([tabStripView_ frame]);
}

- (void)layoutTabsWithAnimation:(BOOL)animate
             regenerateSubviews:(BOOL)doUpdate {
    assert([NSThread isMainThread]);
    if (![tabArray_ count])
        return;
    
    const CGFloat kMaxTabWidth = [CTTabViewController maxTabWidth];
    const CGFloat kMinTabWidth = [CTTabViewController minTabWidth];
    const CGFloat kMinSelectedTabWidth = [CTTabViewController minSelectedTabWidth];
    
    NSRect enclosingRect = NSZeroRect;
    if (animate) {
        [NSAnimationContext beginGrouping];
        [[NSAnimationContext currentContext] setDuration:kAnimationDuration];
    }
    
    CGFloat availableSpace = 0;
    if (verticalLayout_) {
        availableSpace = NSHeight([tabStripView_ bounds]);
    } else {
        if ([self inRapidClosureMode]) {
            availableSpace = availableResizeWidth_;
        } else {
            availableSpace = NSWidth([tabStripView_ frame]) - 5.0;
        }
        availableSpace -= [self indentForControls];
    }
    
    CGFloat availableSpaceForNonMini = availableSpace;
    
    CGFloat nonMiniTabWidth = kMaxTabWidth;
    const NSInteger numberOfOpenNonMiniTabs = [self numberOfOpenTabs];
    if (!verticalLayout_ && numberOfOpenNonMiniTabs) {
        availableSpaceForNonMini += (numberOfOpenNonMiniTabs - 1) * kTabOverlap;
        nonMiniTabWidth = availableSpaceForNonMini / numberOfOpenNonMiniTabs;
        nonMiniTabWidth = MAX(MIN(nonMiniTabWidth, kMaxTabWidth), kMinTabWidth);
    }
    
    BOOL visible = [[tabStripView_ window] isVisible];
    
    CGFloat offset = [self indentForControls];
    NSInteger i = 0;
    bool hasPlaceholderGap = false;
    NSInteger placeHolderIndex = -1;
    BOOL hasPlaceHolder = NO;
    NSMutableArray* viewsInOrder = [NSMutableArray arrayWithCapacity:tabArray_.count];
    NSMutableArray* delayedStyleUpdated = [NSMutableArray array];
    for (CTTabViewController* tab in tabArray_) {
        if ([closingControllers_ containsObject:tab])
            continue;
        
        CTTabView* tabView = (CTTabView*) tab.view;
        BOOL isPlaceholder = [tabView isEqual:placeholderTab_];
        NSRect tabFrame = [tabView frame];
        tabFrame.size.height = [[self class] defaultTabHeight] + 1;
        if (verticalLayout_) {
            tabFrame.origin.y = availableSpace - tabFrame.size.height - offset;
            tabFrame.origin.x = 0;
        } else {
            tabFrame.origin.y = 0;
            tabFrame.origin.x = offset;
        }
        BOOL newTab = [tabView isHidden];
        if (newTab) {
            [tabView setHidden:NO];
        }
        
        CAAnimation* frameAnimation = [tabView animationForKey:@"frameOrigin"];
        frameAnimation.delegate = self;
        [tabView setAnimations:[NSDictionary dictionaryWithObject:frameAnimation forKey:@"frameOrigin"]];
        
        if (isPlaceholder) {
            hasPlaceHolder = YES;
            if (animate) {
                [NSAnimationContext beginGrouping];
                [[NSAnimationContext currentContext] setDuration:0];
            }
            if (verticalLayout_)
                tabFrame.origin.y = availableSpace - tabFrame.size.height - offset;
            else
                tabFrame.origin.x = placeholderFrame_.origin.x;
            id target = animate ? [tabView animator] : tabView;
            [target setFrame:tabFrame];
            
            NSValue* identifier = [NSValue valueWithPointer:(__bridge const void*)tabView];
            [targetFrames_ setObject:[NSValue valueWithRect:tabFrame]
                              forKey:identifier];
            [NSAnimationContext endGrouping];
            continue;
        }
        
        if (placeholderTab_ && !hasPlaceholderGap) {
            const CGFloat placeholderMin =
            verticalLayout_ ? NSMinY(placeholderFrame_) :
            NSMinX(placeholderFrame_);
            if (verticalLayout_) {
                if (NSMidY(tabFrame) > placeholderMin) {
                    hasPlaceholderGap = true;
                    offset += NSHeight(placeholderFrame_);
                    tabFrame.origin.y = availableSpace - tabFrame.size.height - offset;
                }
            } else {
                if (NSMidX(tabFrame) > placeholderMin) {
                    hasPlaceholderGap = true;
                    offset += NSWidth(placeholderFrame_);
                    offset -= kTabOverlap;
                    tabFrame.origin.x = offset;
                    placeHolderIndex = i;
                    [viewsInOrder insertObject:[NSNull null] atIndex:placeHolderIndex];
                    i++;
                }
            }
        }
        
        tabView.tag = i;
        [viewsInOrder insertObject:tabView atIndex:i];
        
        tabFrame.size.width = nonMiniTabWidth;
        if ([tab selected])
            tabFrame.size.width = MAX(tabFrame.size.width, kMinSelectedTabWidth);
        
        if (newTab && visible && animate) {
            if (NSEqualRects(droppedTabFrame_, NSZeroRect)) {
                [tabView setFrame:NSOffsetRect(tabFrame, 0, -NSHeight(tabFrame))];
            } else {
                [tabView setFrame:droppedTabFrame_];
                droppedTabFrame_ = NSZeroRect;
            }
        }
        
        id frameTarget = visible && animate ? [tabView animator] : tabView;
        NSValue* identifier = [NSValue valueWithPointer:(__bridge const void*)tabView];
        NSValue* oldTargetValue = [targetFrames_ objectForKey:identifier];
        NSRect oldRect = [oldTargetValue rectValue];
        if (!oldTargetValue ||
            !NSEqualRects(oldRect, tabFrame)) {
            if ((oldRect.origin.x + kTabOverlap < tabFrame.origin.x) && (i + 1 < tabArray_.count)) {
                [delayedStyleUpdated addObject:[NSNumber numberWithInteger:i + 1]];
            } else if ((oldRect.origin.x - kTabOverlap > tabFrame.origin.x) && (i - 1 >= 0)) {
                [delayedStyleUpdated addObject:[NSNumber numberWithInteger:i - 1]];
            }
            [frameTarget setFrame:tabFrame];
            [targetFrames_ setObject:[NSValue valueWithRect:tabFrame]
                              forKey:identifier];
        }
        
        enclosingRect = NSUnionRect(tabFrame, enclosingRect);
        
        if (verticalLayout_) {
            offset += NSHeight(tabFrame);
        } else {
            offset += NSWidth(tabFrame);
            offset -= kTabOverlap;
        }
        i++;
    }
    if (placeholderTab_ && hasPlaceHolder) {
        if (-1 == placeHolderIndex) {
            [viewsInOrder addObject:placeholderTab_];
        } else if (placeHolderIndex >= 0 && placeHolderIndex < viewsInOrder.count) {
            [viewsInOrder replaceObjectAtIndex:placeHolderIndex withObject:placeholderTab_];
        }
    }
    
    [self regenerateSubviewListWithOrderedArray:viewsInOrder delayed:delayedStyleUpdated];
    [dragBlockingView_ setFrame:enclosingRect];
    if (animate) {
        [NSAnimationContext endGrouping];
    }
    initialLayoutComplete_ = YES;
}

- (void)layoutTabs {
    [self layoutTabsWithAnimation:initialLayoutComplete_ regenerateSubviews:YES];
}

- (void)setTabTitle:(NSViewController*)tab withContents:(CTTabContents*)contents {
    NSString* titleString = nil;
    if (contents)
        titleString = contents.title;
    if (!titleString || ![titleString length])
        titleString = @"New Tab";
    [tab setTitle:titleString];
}

- (void)removeTab:(CTTabViewController*)controller {
    NSUInteger index = [tabArray_ indexOfObject:controller];
    
    [tabContentsArray_ removeObjectAtIndex:index];
    
    NSView* tab = [controller view];
    [tab removeFromSuperview];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSViewDidUpdateTrackingAreasNotification object:tab];
    
    [controller setTarget:nil];
    
    if ([hoveredTab_ isEqual:tab])
        hoveredTab_ = nil;
    
    NSValue* identifier = [NSValue valueWithPointer:(__bridge const void*)tab];
    [targetFrames_ removeObjectForKey:identifier];
    
    [tabArray_ removeObjectAtIndex:index];
}

- (void)animationDidStopForController:(CTTabViewController*)controller
                             finished:(BOOL)finished {
    [closingControllers_ removeObject:controller];
    [self removeTab:controller];
}

- (void)startClosingTabWithAnimation:(CTTabViewController*)closingTab {
    assert([NSThread isMainThread]);
    [closingControllers_ addObject:closingTab];
    
    [(CTTabView*)[closingTab view] setClosing:YES];
    
    NSView* tabView = [closingTab view];
    CAAnimation* animation = [[tabView animationForKey:@"frameOrigin"] copy];
    TabCloseAnimationDelegate* delegate = 
    [[TabCloseAnimationDelegate alloc] initWithTabStrip:self
                                          tabController:closingTab];
    [animation setDelegate:delegate];  // Retains delegate.
    NSMutableDictionary* animationDictionary =
    [NSMutableDictionary dictionaryWithDictionary:[tabView animations]];
    [animationDictionary setObject:animation forKey:@"frameOrigin"];
    [tabView setAnimations:animationDictionary];
    
    NSRect newFrame = [tabView frame];
    newFrame = NSOffsetRect(newFrame, 0, -newFrame.size.height);
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:kAnimationDuration];
    [[tabView animator] setFrame:newFrame];
    [NSAnimationContext endGrouping];
}

- (NSImageView*)iconImageViewForContents:(CTTabContents*)contents {
    NSImage* image = contents.icon;
    if (!image)
        image = defaultFavIcon_;
    NSRect frame = NSMakeRect(0, 0, kIconWidthAndHeight, kIconWidthAndHeight);
    NSImageView* view = [[NSImageView alloc] initWithFrame:frame];
    [view setImage:image];
    return view;
}

- (void)updateFavIconForContents:(CTTabContents*)contents
                         atIndex:(NSInteger)modelIndex {
    if (!contents)
        return;
    
    NSInteger index = [self indexFromModelIndex:modelIndex];
    
    CTTabViewController* tabController = [tabArray_ objectAtIndex:index];
    
    if ([tabController phantom]) {
        [tabController setPhantom:NO];
        [[tabController view] setNeedsDisplay:YES];
    }
    
    bool oldHasIcon = [tabController iconView] != nil;
    bool newHasIcon = contents.hasIcon;
    
    CTTabLoadingState oldState = [tabController loadingState];
    CTTabLoadingState newState = CTTabLoadingStateDone;
    if (contents.isCrashed) {
        newState = CTTabLoadingStateCrashed;
        newHasIcon = true;
    } else if (contents.isWaitingForResponse) {
        newState = CTTabLoadingStateWaiting;
    } else if (contents.isLoading) {
        newState = CTTabLoadingStateLoading;
    }
    
    if (oldState != newState)
        [tabController setLoadingState:newState];
    
    if (newState == CTTabLoadingStateDone || oldState != newState || oldHasIcon != newHasIcon) {
        NSView* iconView = nil;
        if (newHasIcon) {
            if (newState == CTTabLoadingStateDone) {
                iconView = [self iconImageViewForContents:contents];
            }
        }
        
        [tabController setIconView:iconView];
    }
}

- (void)setFrameOfSelectedTab:(NSRect)frame {
    NSView* view = [self selectedTabView];
    NSValue* identifier = [NSValue valueWithPointer:(__bridge const void*)view];
    [targetFrames_ setObject:[NSValue valueWithRect:frame]
                      forKey:identifier];
    [view setFrame:frame];
}

- (NSView*)selectedTabView {
    NSInteger selectedIndex = [tabStripModel2_ selectedIndex];
    selectedIndex = [self indexFromModelIndex:selectedIndex];
    return [self viewAtIndex:selectedIndex];
}

- (int)indexOfPlaceholder {
    double placeholderX = placeholderFrame_.origin.x;
    int index = 0;
    int location = 0;
    const NSInteger count = [tabArray_ count];
    while (index < count) {
        if ([closingControllers_ containsObject:[tabArray_ objectAtIndex:index]]) {
            index++;
            continue;
        }
        NSView* curr = [self viewAtIndex:index];
        if (curr == placeholderTab_) {
            index++;
            continue;
        }
        if (placeholderX <= NSMinX([curr frame]))
            break;
        index++;
        location++;
    }
    return location;
}

- (void)moveTabFromIndex:(NSInteger)from {
    int toIndex = [self indexOfPlaceholder];
    [tabStripModel2_ moveTabContentsFromIndex:from toIndex:toIndex selectAfterMove:YES];
}

- (void)dropTabContents:(CTTabContents*)contents
              withFrame:(NSRect)frame {
    int modelIndex = [self indexOfPlaceholder];
    
    droppedTabFrame_ = frame;
    
    [tabStripModel2_ insertTabContents:contents atIndex:modelIndex options:ADD_SELECTED];
}

- (void)tabViewFrameChanged:(NSNotification*)info {
    [self layoutTabsWithAnimation:NO regenerateSubviews:NO];
}

- (void)tabUpdateTracking:(NSNotification*)notification {
    assert([[notification object] isKindOfClass:[CTTabView class]]);
    assert(mouseInside_);
    NSWindow* window = [tabStripView_ window];
    NSPoint location = [window mouseLocationOutsideOfEventStream];
    if (NSPointInRect(location, [tabStripView_ frame])) {
        NSEvent* mouseEvent = [NSEvent mouseEventWithType:NSMouseMoved
                                                 location:location
                                            modifierFlags:0
                                                timestamp:0
                                             windowNumber:[window windowNumber]
                                                  context:nil
                                              eventNumber:0
                                               clickCount:0
                                                 pressure:0];
        [self mouseMoved:mouseEvent];
    }
}

- (BOOL)inRapidClosureMode {
    return availableResizeWidth_ != kUseFullAvailableWidth;
}

- (BOOL)tabDraggingAllowed {
    return [closingControllers_ count] == 0;
}

- (void)mouseMoved:(NSEvent*)event {
    NSView* targetView = [tabStripView_ hitTest:[event locationInWindow]];
   
    CTTabView* tabView = (CTTabView*)targetView;
    if (![tabView isKindOfClass:[CTTabView class]]) {
        if ([[tabView superview] isKindOfClass:[CTTabView class]]) {
            tabView = (CTTabView*)[targetView superview];
        } else {
            tabView = nil;
        }
    }
    
    if (hoveredTab_ != tabView) {
        [hoveredTab_ mouseExited:nil];
        [tabView mouseEntered:nil];
        hoveredTab_ = tabView;
    } else {
        [hoveredTab_ mouseMoved:event];
    }
}

- (void)mouseEntered:(NSEvent*)event {
    NSTrackingArea* area = [event trackingArea];
    if ([area isEqual:trackingArea_]) {
        mouseInside_ = YES;
        [self setTabTrackingAreasEnabled:YES];
        [self mouseMoved:event];
    }
}

- (void)mouseExited:(NSEvent*)event {
    NSTrackingArea* area = [event trackingArea];
    if ([area isEqual:trackingArea_]) {
        mouseInside_ = NO;
        [self setTabTrackingAreasEnabled:NO];
        availableResizeWidth_ = kUseFullAvailableWidth;
        [hoveredTab_ mouseExited:event];
        hoveredTab_ = nil;
        [self layoutTabs];
    } else if ([area isEqual:newTabTrackingArea_]) {
        [self setNewTabButtonHoverState:NO];
    }
}

- (void)setTabTrackingAreasEnabled:(BOOL)enabled {
    NSNotificationCenter* defaultCenter = [NSNotificationCenter defaultCenter];
    for (CTTabViewController* controller in tabArray_) {
        CTTabView* tabView = [controller tabView];
        if (enabled) {
            [defaultCenter addObserver:self
                              selector:@selector(tabUpdateTracking:)
                                  name:NSViewDidUpdateTrackingAreasNotification
                                object:tabView];
        } else {
            [defaultCenter removeObserver:self
                                     name:NSViewDidUpdateTrackingAreasNotification
                                   object:tabView];
        }
        [tabView setTrackingEnabled:enabled];
    }
}

- (void)addSubviewToPermanentList:(NSView*)aView {
    if (aView)
        [permanentSubviews_ addObject:aView];
}

- (void)regenerateSubviewListWithOrderedArray:(NSArray*)orderedTabs delayed:(NSArray*)delayedIndices {
    [self setTabTrackingAreasEnabled:NO];
    NSMutableArray* subviews = [NSMutableArray arrayWithArray:permanentSubviews_];
    
    NSUInteger minTabViewIndex = subviews.count;
    BOOL passedPlaceHolder = NO;
    CTTabView* selectedTabView = (CTTabView*) self.selectedTabView;
    CTTabView* prevTabView = nil;
    for (id object in orderedTabs) {
        TabStyle tabStyle = 0;
        if ([object isKindOfClass:[CTTabView class]]) {
            CTTabView* tabView = (CTTabView*) object;
            if (tabView == selectedTabView) {
                tabStyle = kTabStyleShowBoth;
                [subviews addObject:tabView];
                passedPlaceHolder = YES;
            } else if (!passedPlaceHolder) {
                tabStyle = kTabStyleShowLeft;
                [subviews addObject:tabView];
            } else {
                tabStyle = kTabStyleShowRight;
                [subviews insertObject:tabView atIndex:minTabViewIndex];
            }
            
            if (tabView == placeholderTab_) {
                prevTabView.tabStyle |= kTabStyleShowRight;
            } else if (prevTabView && (prevTabView == placeholderTab_ || [prevTabView isEqualTo:[NSNull null]])) {
                tabStyle |= kTabStyleShowLeft;
            }
            prevTabView = tabView;
            
            if (!isDetachingTab_ && tabView.delayedTabStyle) {
                tabView.tabStyle = kTabStyleShowBoth;
                continue;
            } else if (isDetachingTab_) {
                tabView.delayedTabStyle = 0;
            }
            
            NSInteger index = tabView.tag;
            if ([delayedIndices containsObject:[NSNumber numberWithInteger:index]]) {
                tabView.delayedTabStyle = tabStyle;
            } else {
                tabView.tabStyle = tabStyle;
            }
        } else if (object == [NSNull null]) {
            prevTabView.tabStyle |= kTabStyleShowRight;
            prevTabView = object;
        }
    }
    [tabStripView_ setSubviews:subviews];
    [self setTabTrackingAreasEnabled:mouseInside_];
}

- (void)animationDidStop:(CAAnimation*)animation finished:(BOOL)flag
{
    for (CTTabViewController* tab in tabArray_) {
        CTTabView* tabView = (CTTabView*) tab.view;
        if (tabView.delayedTabStyle) {
            tabView.tabStyle = tabView.delayedTabStyle;
            tabView.delayedTabStyle = 0;
        }
    }
    [tabStripView_ setNeedsDisplay:YES];
}

@end
