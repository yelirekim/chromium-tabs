
@class NewTabButton;

@interface CTTabStripView : NSView

@property(strong, nonatomic) IBOutlet NewTabButton* addTabButton;
@property(assign, nonatomic) BOOL dropArrowShown;
@property(assign, nonatomic) NSPoint dropArrowPosition;

@end

@interface CTTabStripView (Protected)

- (void)drawBottomBorder:(NSRect)bounds;
- (BOOL)doubleClickMinimizesWindow;

@end
