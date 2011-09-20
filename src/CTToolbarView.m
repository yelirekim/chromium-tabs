#import "CTToolbarView.h"
#import "NSWindow+CTThemed.h"

@implementation CTToolbarView

@synthesize dividerOpacity = dividerOpacity_;

- (BOOL)mouseDownCanMoveWindow {
    return NO;
}

- (void)drawRect:(NSRect)rect {
    NSPoint phase = [[self window] themePatternPhase];
    [[NSGraphicsContext currentContext] setPatternPhase:phase];
    [self drawBackground];
}

- (NSColor*)strokeColor {
    return [[super strokeColor] colorWithAlphaComponent:[self dividerOpacity]];
}

- (BOOL)accessibilityIsIgnored {
    return NO;
}

- (id)accessibilityAttributeValue:(NSString*)attribute {
    if ([attribute isEqual:NSAccessibilityRoleAttribute]) {
        return NSAccessibilityToolbarRole;
    }
    return [super accessibilityAttributeValue:attribute];
}

@end
