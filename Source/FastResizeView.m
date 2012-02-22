#import "FastResizeView.h"

@interface FastResizeView (Private)
- (void)layoutSubviews;
@end

@implementation FastResizeView {
    BOOL fastResizeMode_;
}

- (void)setFastResizeMode:(BOOL)fastResizeMode {
    fastResizeMode_ = fastResizeMode;
    if (!fastResizeMode_) {
        [self layoutSubviews];
    }
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize {
    [self layoutSubviews];
}

- (void)drawRect:(NSRect)dirtyRect {
    if (fastResizeMode_) {
        [[NSColor whiteColor] set];
        NSRectFill(dirtyRect);
    }
}

@end

@implementation FastResizeView (Private)

- (void)layoutSubviews {
    NSArray* subviews = [self subviews];
    assert([subviews count] <= 1);
    if ([subviews count] < 1) {
        return;
    }
    
    NSView* subview = [subviews objectAtIndex:0];
    NSRect bounds = [self bounds];
    
    if (fastResizeMode_) {
        NSRect frame = [subview frame];
        frame.origin.x = 0;
        frame.origin.y = NSHeight(bounds) - NSHeight(frame);
        [subview setFrame:frame];
    } else {
        [subview setFrame:bounds];
    }
}

@end
