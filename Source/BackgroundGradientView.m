#import "BackgroundGradientView.h"

#define kToolbarTopOffset 12
#define kToolbarMaxHeight 100

@implementation BackgroundGradientView {
    BOOL showsDivider_;
}
@synthesize showsDivider = showsDivider_;

static NSGradient *_gradientFaded = nil;
static NSGradient *_gradientNotFaded = nil;
static NSColor* kDefaultColorToolbarStroke = nil;
static NSColor* kDefaultColorToolbarStrokeInactive = nil;

+ (void) initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _gradientFaded = [[NSGradient alloc] initWithColorsAndLocations:[NSColor colorWithCalibratedRed:0.957321 green:0.957428 blue:0.957302 alpha:1.0], 0.0,
                          [NSColor colorWithCalibratedRed:0.904617 green:0.904718 blue:0.904599 alpha:1.0], 0.25,
                          [NSColor colorWithCalibratedRed:0.836730 green:0.836823 blue:0.836713 alpha:1.0], 0.5,
                          [NSColor colorWithCalibratedRed:0.897006 green:0.897106 blue:0.896989 alpha:1.0], 0.75,
                          nil];
        _gradientNotFaded = [[NSGradient alloc] initWithColorsAndLocations:[NSColor colorWithCalibratedRed:0.940553 green:0.940579 blue:0.940562 alpha:1.0], 0.0,
                             [NSColor colorWithCalibratedRed:0.870679 green:0.870699 blue:0.870688 alpha:1.0], 0.25,
                             [NSColor colorWithCalibratedRed:0.785800 green:0.785800 blue:0.785810 alpha:1.0], 0.5,
                             [NSColor colorWithCalibratedRed:0.860891 green:0.860910 blue:0.860901 alpha:1.0], 0.75,
                             nil];;
        kDefaultColorToolbarStroke = [NSColor colorWithCalibratedWhite: 0x67 / 0xff alpha:1.0];
        kDefaultColorToolbarStrokeInactive = [NSColor colorWithCalibratedWhite: 0x7b / 0xff alpha:1.0];
    });
}

- (id)initWithFrame:(NSRect)frameRect {
  if (nil != (self = [super initWithFrame:frameRect])) {
    showsDivider_ = YES;
  }
  return self;
}

- (void)awakeFromNib {
  showsDivider_ = YES;
}

- (void)setShowsDivider:(BOOL)show {
  showsDivider_ = show;
  [self setNeedsDisplay:YES];
}

- (void)drawBackground {
  NSGradient *gradient = [[self window] isKeyWindow] ? _gradientNotFaded :  _gradientFaded;
  CGFloat winHeight = NSHeight([[self window] frame]);
  NSPoint startPoint = [self convertPoint:NSMakePoint(0, winHeight - kToolbarTopOffset) fromView:nil];
  NSPoint endPoint = NSMakePoint(0, winHeight - kToolbarTopOffset - kToolbarMaxHeight);
  endPoint = [self convertPoint:endPoint fromView:nil];

  [gradient drawFromPoint:startPoint toPoint:endPoint options:(NSGradientDrawsBeforeStartingLocation | NSGradientDrawsAfterEndingLocation)];

  if (showsDivider_) {
    [[self strokeColor] set];
    NSRect borderRect, contentRect;
    NSDivideRect([self bounds], &borderRect, &contentRect, 1, NSMinYEdge);
    NSRectFillUsingOperation(borderRect, NSCompositeSourceOver);
  }
}

- (NSColor*)strokeColor {
  return [[self window] isKeyWindow] ? kDefaultColorToolbarStroke : kDefaultColorToolbarStrokeInactive;
}

@end
