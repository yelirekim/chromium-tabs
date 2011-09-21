#import "HoverCloseButton.h"

typedef enum {
    kHoverStateNone = 0,
    kHoverStateMouseOver = 1,
    kHoverStateMouseDown = 2
} HoverState;

static const CGFloat kCircleRadiusPercentage = 0.415;
static const CGFloat kCircleHoverWhite = 0.565;
static const CGFloat kCircleClickWhite = 0.396;
static const CGFloat kXShadowAlpha = 0.75;
static const CGFloat kXShadowCircleAlpha = 0.1;

@interface HoverCloseButton(Private)
- (HoverState) hoverState;
- (void)setUpDrawingPaths;
- (void)commonInit;
@end

@implementation HoverCloseButton {
    HoverState hoverState_;
    NSTrackingArea* trackingArea_;
    
    NSBezierPath* xPath_;
    NSBezierPath* circlePath_;
}

- (void)dealloc {
    [self setTrackingEnabled:NO];
}

- (id)initWithFrame:(NSRect)frameRect {
    if ((self = [super initWithFrame:frameRect])) {
        [self commonInit];
    }
    return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    [self commonInit];
}

- (void)drawRect:(NSRect)rect {
    if (!circlePath_ || !xPath_)
        [self setUpDrawingPaths];
    
    NSColor* innerColor;
    if (hoverState_ != kHoverStateNone) {
        CGFloat white = (hoverState_ == kHoverStateMouseOver) ? kCircleHoverWhite : kCircleClickWhite;
        [[NSColor colorWithCalibratedWhite:white alpha:1.0] set];
        [circlePath_ fill];
        innerColor = [NSColor whiteColor];
    } else {
        innerColor = [NSColor grayColor];
    }
    
    [innerColor set];
    [xPath_ fill];
}

- (void)commonInit {
    [self setTrackingEnabled:YES];
    hoverState_ = kHoverStateNone;
    [self updateTrackingAreas];
    [[self cell] accessibilitySetOverrideValue:@"Close" forAttribute:NSAccessibilityDescriptionAttribute];
}

- (void)setUpDrawingPaths {
    NSRect bounds = [self bounds];
    NSPoint viewCenter = NSMakePoint(NSMidX(bounds), NSMidY(bounds));
    
    circlePath_ = [NSBezierPath bezierPath];
    [circlePath_ moveToPoint:viewCenter];
    CGFloat radius = kCircleRadiusPercentage * NSWidth([self bounds]);
    [circlePath_ appendBezierPathWithArcWithCenter:viewCenter radius:radius startAngle:0.0 endAngle:365.0];
    
    xPath_ = [NSBezierPath bezierPath];
    [xPath_ appendBezierPathWithRect:NSMakeRect(3.5, 7.0, 9.0, 2.0)];
    [xPath_ appendBezierPathWithRect:NSMakeRect(7.0, 3.5, 2.0, 9.0)];
    
    NSRect xPathBounds = [xPath_ bounds];
    NSPoint pathCenter = NSMakePoint(NSMidX(xPathBounds), NSMidY(xPathBounds));
    
    NSAffineTransform* transform = [NSAffineTransform transform];
    [transform translateXBy:viewCenter.x yBy:viewCenter.y];
    [transform rotateByDegrees:45.0];
    [transform translateXBy:-pathCenter.x yBy:-pathCenter.y];
    
    [xPath_ transformUsingAffineTransform:transform];
}

- (void)mouseEntered:(NSEvent*)theEvent {
    hoverState_ = kHoverStateMouseOver;
    [self setNeedsDisplay:YES];
}

- (void)mouseExited:(NSEvent*)theEvent {
    hoverState_ = kHoverStateNone;
    [self setNeedsDisplay:YES];
}

- (void)mouseDown:(NSEvent*)theEvent {
    hoverState_ = kHoverStateMouseDown;
    [self setNeedsDisplay:YES];
    
    [super mouseDown:theEvent];
    [self checkImageState];
    
}

- (void)setTrackingEnabled:(BOOL)enabled {
    if (enabled) {
        trackingArea_ = [[NSTrackingArea alloc] initWithRect:[self bounds] options:NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways owner:self userInfo:nil];
        [self addTrackingArea:trackingArea_];
        [self checkImageState];
    } else if (trackingArea_) {
        [self removeTrackingArea:trackingArea_];
        trackingArea_ = nil;
    }
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    [self checkImageState];
}

- (void)checkImageState {
    if (!trackingArea_) {
        return;
    }
    
    NSPoint mouseLoc = [[self window] mouseLocationOutsideOfEventStream];
    mouseLoc = [self convertPoint:mouseLoc fromView:nil];
    hoverState_ = NSPointInRect(mouseLoc, [self bounds]) ? kHoverStateMouseOver : kHoverStateNone;
    [self setNeedsDisplay:YES];
}

- (HoverState) hoverState
{
    return hoverState_;
}

@end
