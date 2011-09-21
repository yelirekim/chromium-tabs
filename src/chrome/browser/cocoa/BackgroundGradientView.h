
@interface BackgroundGradientView : NSView

@property(nonatomic, assign) BOOL showsDivider;

- (NSColor *)strokeColor;
- (void)drawBackground;

@end
