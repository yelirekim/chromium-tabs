#import "HoverButton+Private.h"

@implementation HoverButton {
    HoverState hoverState_;
    NSTrackingArea* trackingArea_;
}

- (id)initWithFrame:(NSRect)frameRect {
    if ((self = [super initWithFrame:frameRect])) {
        [self setTrackingEnabled:YES];
        hoverState_ = kHoverStateNone;
        [self updateTrackingAreas];
    }
    return self;
}

- (void)awakeFromNib {
    [self setTrackingEnabled:YES];
    hoverState_ = kHoverStateNone;
    [self updateTrackingAreas];
}

- (void)dealloc {
    [self setTrackingEnabled:NO];
}

- (void)mouseEntered:(NSEvent*)theEvent {
    hoverState_ = kHoverStateMouseOver;
    [self setNeedsDisplay:YES];
}

- (void)mouseExited:(NSEvent*)theEvent {
    hoverState_ = kHoverStateNone;
    [self setNeedsDisplay:YES];
}

- (void)mouseDown:(NSEvent*)theEvent {
    hoverState_ = kHoverStateMouseDown;
    [self setNeedsDisplay:YES];
    
    [super mouseDown:theEvent];
    [self checkImageState];
    
}

- (void)setTrackingEnabled:(BOOL)enabled {
    if (enabled) {
        trackingArea_ = [[NSTrackingArea alloc] initWithRect:[self bounds] options:NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways owner:self userInfo:nil];
        [self addTrackingArea:trackingArea_];
        [self checkImageState];
    } else if (trackingArea_) {
        [self removeTrackingArea:trackingArea_];
        trackingArea_ = nil;
    }
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    [self checkImageState];
}

- (void)checkImageState {
    if (!trackingArea_) {
        return;
    }
    
    NSPoint mouseLoc = [[self window] mouseLocationOutsideOfEventStream];
    mouseLoc = [self convertPoint:mouseLoc fromView:nil];
    hoverState_ = NSPointInRect(mouseLoc, [self bounds]) ? kHoverStateMouseOver : kHoverStateNone;
    [self setNeedsDisplay:YES];
}

- (HoverState) hoverState
{
    return hoverState_;
}

@end
