//
//  NSBezierPath+MCAdditions.m
//
//  Created by Sean Patrick O'Brien on 4/1/08.
//  Copyright 2008 MolokoCacao. All rights reserved.
//

#import "NSBezierPath+MCAdditions.h"

// remove/comment out this line of you don't want to use undocumented functions
#define MCBEZIER_USE_PRIVATE_FUNCTION

#ifdef MCBEZIER_USE_PRIVATE_FUNCTION
extern CGPathRef CGContextCopyPath(CGContextRef context);
#endif

@implementation NSBezierPath (MCAdditions)

- (void)fillWithInnerShadow:(NSShadow *)shadow
{
  [NSGraphicsContext saveGraphicsState];
  
  NSSize offset = shadow.shadowOffset;
  NSSize originalOffset = offset;
  CGFloat radius = shadow.shadowBlurRadius;
  NSRect bounds = NSInsetRect(self.bounds, -(ABS(offset.width) + radius), -(ABS(offset.height) + radius));
  offset.height += bounds.size.height;
  shadow.shadowOffset = offset;
  NSAffineTransform *transform = [NSAffineTransform transform];
  if ([[NSGraphicsContext currentContext] isFlipped])
    [transform translateXBy:0 yBy:bounds.size.height];
  else
    [transform translateXBy:0 yBy:-bounds.size.height];
  
  NSBezierPath *drawingPath = [NSBezierPath bezierPathWithRect:bounds];
  [drawingPath setWindingRule:NSEvenOddWindingRule];
  [drawingPath appendBezierPath:self];
  [drawingPath transformUsingAffineTransform:transform];
  
  [self addClip];
  [shadow set];
  [[NSColor blackColor] set];
  [drawingPath fill];
  
  shadow.shadowOffset = originalOffset;
  
  [NSGraphicsContext restoreGraphicsState];
}

@end
