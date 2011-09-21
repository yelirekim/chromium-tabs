#import "NewTabButton.h"

@implementation NewTabButton {
    NSBezierPath* imagePath_;
}

- (NSBezierPath*)pathForButton {
    if (imagePath_) {
        return imagePath_;
    }
    
    imagePath_ = [NSBezierPath bezierPath];
    [imagePath_ moveToPoint:NSMakePoint(9, 7)];
    [imagePath_ lineToPoint:NSMakePoint(26, 7)];
    [imagePath_ lineToPoint:NSMakePoint(33, 23)];
    [imagePath_ lineToPoint:NSMakePoint(14, 23)];
    [imagePath_ lineToPoint:NSMakePoint(9, 7)];
    return imagePath_;
}

- (BOOL)pointIsOverButton:(NSPoint)point {
    NSPoint localPoint = [self convertPoint:point fromView:[self superview]];
    NSBezierPath* buttonPath = [self pathForButton];
    return [buttonPath containsPoint:localPoint];
}

- (NSView*)hitTest:(NSPoint)aPoint {
    if ([self pointIsOverButton:aPoint]) {
        return [super hitTest:aPoint];
    }
    return nil;
}

@end
