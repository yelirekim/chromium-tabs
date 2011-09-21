// Copyright (c) 2010 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE-chromium file.

#import "HoverCloseButton.h"
#import "HoverButton+Private.h"

// Convenience function to return the middle point of the given |rect|.
static NSPoint MidRect(NSRect rect) {
    return NSMakePoint(NSMidX(rect), NSMidY(rect));
}

static const CGFloat kCircleRadiusPercentage = 0.415;
static const CGFloat kCircleHoverWhite = 0.565;
static const CGFloat kCircleClickWhite = 0.396;
static const CGFloat kXShadowAlpha = 0.75;
static const CGFloat kXShadowCircleAlpha = 0.1;

@interface HoverCloseButton(Private)
- (void)setUpDrawingPaths;
@end

@implementation HoverCloseButton {
    // Bezier path for drawing the 'x' within the button.
    NSBezierPath* xPath_;
    
    // Bezier path for drawing the hover state circle behind the 'x'.
    NSBezierPath* circlePath_;
}

- (id)initWithFrame:(NSRect)frameRect {
    if ((self = [super initWithFrame:frameRect])) {
        [self commonInit];
    }
    return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    [self commonInit];
}

- (void)drawRect:(NSRect)rect {
    if (!circlePath_ || !xPath_)
        [self setUpDrawingPaths];
    
    NSColor* innerColor;
    if (self.hoverState != kHoverStateNone) {
        // Adjust the darkness of the circle depending on whether it is being
        // clicked.
        CGFloat white = (self.hoverState == kHoverStateMouseOver) ?
        kCircleHoverWhite : kCircleClickWhite;
        [[NSColor colorWithCalibratedWhite:white alpha:1.0] set];
        [circlePath_ fill];
        innerColor = [NSColor whiteColor];
    } else {
        innerColor = [NSColor grayColor];
    }
    
    [innerColor set];
    [xPath_ fill];
}

- (void)commonInit {
    // Set accessibility description.
    NSString* description = @"Close";
    [[self cell]
     accessibilitySetOverrideValue:description
     forAttribute:NSAccessibilityDescriptionAttribute];
}

- (void)setUpDrawingPaths {
    NSPoint viewCenter = MidRect([self bounds]);
    
    circlePath_ = [NSBezierPath bezierPath];
    [circlePath_ moveToPoint:viewCenter];
    CGFloat radius = kCircleRadiusPercentage * NSWidth([self bounds]);
    [circlePath_ appendBezierPathWithArcWithCenter:viewCenter
                                            radius:radius
                                        startAngle:0.0
                                          endAngle:365.0];
    
    // Construct an 'x' by drawing two intersecting rectangles in the shape of a
    // cross and then rotating the path by 45 degrees.
    xPath_ = [NSBezierPath bezierPath];
    [xPath_ appendBezierPathWithRect:NSMakeRect(3.5, 7.0, 9.0, 2.0)];
    [xPath_ appendBezierPathWithRect:NSMakeRect(7.0, 3.5, 2.0, 9.0)];
    
    NSPoint pathCenter = MidRect([xPath_ bounds]);
    
    NSAffineTransform* transform = [NSAffineTransform transform];
    [transform translateXBy:viewCenter.x yBy:viewCenter.y];
    [transform rotateByDegrees:45.0];
    [transform translateXBy:-pathCenter.x yBy:-pathCenter.y];
    
    [xPath_ transformUsingAffineTransform:transform];
}

@end
