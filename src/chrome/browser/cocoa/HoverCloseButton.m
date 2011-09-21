#import "HoverCloseButton.h"
#import "HoverButton+Private.h"

static NSPoint MidRect(NSRect rect) {
    return NSMakePoint(NSMidX(rect), NSMidY(rect));
}

static const CGFloat kCircleRadiusPercentage = 0.415;
static const CGFloat kCircleHoverWhite = 0.565;
static const CGFloat kCircleClickWhite = 0.396;
static const CGFloat kXShadowAlpha = 0.75;
static const CGFloat kXShadowCircleAlpha = 0.1;

@interface HoverCloseButton(Private)
- (void)setUpDrawingPaths;
@end

@implementation HoverCloseButton {
    NSBezierPath* xPath_;
    NSBezierPath* circlePath_;
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
    if (self.hoverState != kHoverStateNone) {
        CGFloat white = (self.hoverState == kHoverStateMouseOver) ?
        kCircleHoverWhite : kCircleClickWhite;
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
    NSString* description = @"Close";
    [[self cell] accessibilitySetOverrideValue:description forAttribute:NSAccessibilityDescriptionAttribute];
}

- (void)setUpDrawingPaths {
    NSPoint viewCenter = MidRect([self bounds]);
    
    circlePath_ = [NSBezierPath bezierPath];
    [circlePath_ moveToPoint:viewCenter];
    CGFloat radius = kCircleRadiusPercentage * NSWidth([self bounds]);
    [circlePath_ appendBezierPathWithArcWithCenter:viewCenter radius:radius startAngle:0.0 endAngle:365.0];
    
    xPath_ = [NSBezierPath bezierPath];
    [xPath_ appendBezierPathWithRect:NSMakeRect(3.5, 7.0, 9.0, 2.0)];
    [xPath_ appendBezierPathWithRect:NSMakeRect(7.0, 3.5, 2.0, 9.0)];
    
    NSPoint pathCenter = MidRect([xPath_ bounds]);
    
    NSAffineTransform* transform = [NSAffineTransform transform];
    [transform translateXBy:viewCenter.x yBy:viewCenter.y];
    [transform rotateByDegrees:45.0];
    [transform translateXBy:-pathCenter.x yBy:-pathCenter.y];
    
    [xPath_ transformUsingAffineTransform:transform];
}

@end
