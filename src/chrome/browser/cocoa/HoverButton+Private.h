#import "HoverButton.h"

typedef enum {
    kHoverStateNone = 0,
    kHoverStateMouseOver = 1,
    kHoverStateMouseDown = 2
} HoverState;

@interface HoverButton (CTPrivate)

@property (nonatomic, readonly) HoverState hoverState;

@end
