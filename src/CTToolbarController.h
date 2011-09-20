
@class CTBrowser;
@class CTTabContents;

@interface CTToolbarController : NSViewController

- (id)initWithBrowser:(CTBrowser*)browser;

- (void)setDividerOpacity:(CGFloat)opacity;
- (void)updateToolbarWithContents:(CTTabContents*)contents shouldRestoreState:(BOOL)shouldRestore;

@end
