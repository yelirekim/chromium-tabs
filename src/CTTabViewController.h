
typedef enum {
  CTTabLoadingStateDone,
  CTTabLoadingStateLoading,
  CTTabLoadingStateWaiting,
  CTTabLoadingStateCrashed,
} CTTabLoadingState;

@class CTTabView;

@interface CTTabViewController : NSViewController

@property(assign, nonatomic) CTTabLoadingState loadingState;
@property(assign, nonatomic) SEL action;
@property(assign, nonatomic) BOOL phantom;
@property(assign, nonatomic) BOOL selected;
@property(assign, nonatomic) id target;

+ (CGFloat)minTabWidth;
+ (CGFloat)maxTabWidth;
+ (CGFloat)minSelectedTabWidth;
+ (CGFloat)appTabWidth;

- (id)init;
- (id)initWithNibName:(NSString*)nibName bundle:(NSBundle*)bundle;

- (CTTabView*)tabView;

- (IBAction)closeTab:(id)sender;
- (void)setIconView:(NSView*)iconView;
- (NSView*)iconView;
- (BOOL)inRapidClosureMode;
- (void)updateVisibility;
- (void)updateTitleColor;

@end

@interface CTTabViewController(TestingAPI)
- (NSString*)toolTip;
- (CGFloat)iconCapacity;
- (BOOL)shouldShowIcon;
- (BOOL)shouldShowCloseButton;
@end
