#import "CTTabStripView.h"
#import "CTTabStripController.h"

static bool ShouldWindowsMiniaturizeOnDoubleClick() {
    BOOL methodImplemented = [NSWindow respondsToSelector:@selector(_shouldMiniaturizeOnDoubleClick)];
    assert(methodImplemented);
    return !methodImplemented || [NSWindow performSelector:@selector(_shouldMiniaturizeOnDoubleClick)];
}

@implementation CTTabStripView {
    NSTimeInterval lastMouseUp_;
    NewTabButton* newTabButton_;
    BOOL dropArrowShown_;
    NSPoint dropArrowPosition_;
}

@synthesize addTabButton = addTabButton_;
@synthesize dropArrowShown = dropArrowShown_;
@synthesize dropArrowPosition = dropArrowPosition_;

- (id)initWithFrame:(NSRect)frame {
    if (nil != (self = [super initWithFrame:frame])) {
        lastMouseUp_ = -1000.0;
    }
    return self;
}

- (void)drawBorder:(NSRect)bounds {
    NSRect borderRect, contentRect;
    
    borderRect = bounds;
    borderRect.origin.y = 1;
    borderRect.size.height = 1;
    [[NSColor colorWithCalibratedWhite:0.0 alpha:0.2] set];
    NSRectFillUsingOperation(borderRect, NSCompositeSourceOver);
    NSDivideRect(bounds, &borderRect, &contentRect, 1, NSMinYEdge);
    NSColor* bezelColor = [NSColor colorWithCalibratedWhite:0xf7/255.0 alpha:1.0];
    [bezelColor set];
    NSRectFill(borderRect);
    NSRectFillUsingOperation(borderRect, NSCompositeSourceOver);
}

- (void)drawRect:(NSRect)rect {
    NSRect boundsRect = [self bounds];
    
    [self drawBorder:boundsRect];
    
    if ([self dropArrowShown]) {
        const CGFloat kArrowTopInset = 1.5;
        const CGFloat kArrowBottomInset = 1;
        const CGFloat kArrowTipProportion = 0.5;
        const CGFloat kArrowTipSlope = 1.2;
        const CGFloat kArrowStemProportion = 0.33;
        
        NSPoint arrowTipPos = [self dropArrowPosition];
        arrowTipPos.y += kArrowBottomInset;
        
        CGFloat availableHeight =
        NSMaxY(boundsRect) - arrowTipPos.y - kArrowTopInset;
        assert(availableHeight >= 5);
        
        CGFloat arrowTipHeight = kArrowTipProportion * availableHeight;
        CGFloat arrowTipWidth = 2 * arrowTipHeight / kArrowTipSlope;
        CGFloat arrowStemHeight = availableHeight - arrowTipHeight;
        CGFloat arrowStemWidth = kArrowStemProportion * arrowTipWidth;
        CGFloat arrowStemInset = (arrowTipWidth - arrowStemWidth) / 2;
        
        NSBezierPath* arrow = [NSBezierPath bezierPath];
        [arrow setLineJoinStyle:NSMiterLineJoinStyle];
        [arrow setLineWidth:1];
        
        [arrow moveToPoint:arrowTipPos];
        [arrow relativeLineToPoint:NSMakePoint(-arrowTipWidth / 2, arrowTipHeight)];
        [arrow relativeLineToPoint:NSMakePoint(arrowStemInset, 0)];
        [arrow relativeLineToPoint:NSMakePoint(0, arrowStemHeight)];
        [arrow relativeLineToPoint:NSMakePoint(arrowStemWidth, 0)];
        [arrow relativeLineToPoint:NSMakePoint(0, -arrowStemHeight)];
        [arrow relativeLineToPoint:NSMakePoint(arrowStemInset, 0)];
        [arrow closePath];
        
        [[NSColor colorWithCalibratedWhite:0 alpha:0.67] set];
        [arrow stroke];
        [[NSColor colorWithCalibratedWhite:1 alpha:0.67] setFill];
        [arrow fill];
    }
}

- (BOOL)doubleClickMinimizesWindow {
    return YES;
}

- (BOOL)acceptsFirstMouse:(NSEvent*)event {
    return YES;
}

- (void)mouseUp:(NSEvent*)event {
    if (![self doubleClickMinimizesWindow]) {
        [super mouseUp:event];
        return;
    }
    
    NSInteger clickCount = [event clickCount];
    NSTimeInterval timestamp = [event timestamp];
    
    if (clickCount == 2 && (timestamp - lastMouseUp_) < 0.8) {
        if (ShouldWindowsMiniaturizeOnDoubleClick())
            [[self window] performMiniaturize:self];
    } else {
        [super mouseUp:event];
    }
    
    lastMouseUp_ = (clickCount == 1) ? timestamp : -1000.0;
}

- (BOOL)accessibilityIsIgnored {
    return NO;
}

- (id)accessibilityAttributeValue:(NSString*)attribute {
    if ([attribute isEqual:NSAccessibilityRoleAttribute]) {
        return NSAccessibilityGroupRole;
    }
    
    return [super accessibilityAttributeValue:attribute];
}

@end
