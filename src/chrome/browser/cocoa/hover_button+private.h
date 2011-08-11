#import "chrome/browser/cocoa/hover_button.h"

// Enumeration of the hover states that the close button can be in at any one
// time. The button cannot be in more than one hover state at a time.
enum HoverState {
    kHoverStateNone = 0,
    kHoverStateMouseOver = 1,
    kHoverStateMouseDown = 2
};

@interface HoverButton (CTPrivate)

@property (nonatomic, readonly) HoverState hoverState;

@end
