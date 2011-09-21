#import "TruncatingTextFieldCell.h"

@implementation TruncatingTextFieldCell

- (void)awakeFromNib {
    [self setLineBreakMode:NSLineBreakByClipping];
}

- (id)initTextCell:(NSString *)aString {
    if (nil != (self = [super initTextCell:aString])) {
        [self setLineBreakMode:NSLineBreakByClipping];
    }
    return self;
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    [super drawInteriorWithFrame:cellFrame inView:controlView];
    
    // TODO: This need to be fixed to fade the text
}

@end
