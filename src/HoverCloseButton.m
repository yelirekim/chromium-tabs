#import "HoverCloseButton.h"

@interface HoverCloseButton(Private)
- (void)setUpDrawingPaths;
- (void)commonInit;
@end


@implementation HoverCloseButton {
    NSTrackingArea* trackingArea_;
}

static NSImage* closeButtonImage;
static NSImage* closeButtonHoverImage;
static NSImage* closeButtonPressedImage;

+ (void) initialize
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        closeButtonImage = [[NSImage alloc] initWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"<HoverCloseButton> TabClose" ofType:@"png"]];
        closeButtonHoverImage = [[NSImage alloc] initWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"<HoverCloseButton> TabCloseRollover" ofType:@"png"]];
        closeButtonPressedImage = [[NSImage alloc] initWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"<HoverCloseButton> TabClosePressed" ofType:@"png"]];
    });
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

- (void)commonInit {
    [self setTrackingEnabled:YES];
    [self setImage:closeButtonImage];
    [self setAlternateImage:closeButtonPressedImage];
    [[self cell] accessibilitySetOverrideValue:@"Close" forAttribute:NSAccessibilityDescriptionAttribute];
}

- (void)mouseEntered:(NSEvent*)theEvent {
    [self setImage:closeButtonHoverImage];
}

- (void)mouseExited:(NSEvent*)theEvent {
    [self setImage:closeButtonImage];
}

- (void)setTrackingEnabled:(BOOL)enabled {
    if (enabled) {
        trackingArea_ = [[NSTrackingArea alloc] initWithRect:[self bounds] options:NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways owner:self userInfo:nil];
        [self addTrackingArea:trackingArea_];
    } else if (trackingArea_) {
        [self removeTrackingArea:trackingArea_];
        trackingArea_ = nil;
    }
}

@end