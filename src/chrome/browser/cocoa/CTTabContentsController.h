
@class CTTabContents;

@interface CTTabContentsController : NSViewController

- (id)initWithNibName:(NSString*)name bundle:(NSBundle*)bundle contents:(CTTabContents*)contents;
- (id)initWithContents:(CTTabContents*)contents;

- (BOOL)isCurrentTab;
- (void)willResignSelectedTab;
- (void)willBecomeSelectedTab;
- (void)ensureContentsVisible;
- (void)tabDidChange:(CTTabContents*)updatedContents;

@end
