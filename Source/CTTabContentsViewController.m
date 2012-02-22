#import "CTTabContentsViewController.h"
#import "CTTabContents.h"

@implementation CTTabContentsViewController {
    CTTabContents* contents_;
    IBOutlet NSSplitView* contentsContainer_;
}

- (id)initWithContents:(CTTabContents*)contents {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    return [self initWithNibName:@"TabContents" bundle:bundle contents:contents];
}

- (id)initWithNibName:(NSString*)name bundle:(NSBundle*)bundle contents:(CTTabContents*)contents {
    if ((self = [super initWithNibName:name bundle:bundle])) {
        contents_ = contents;
    }
    return self;
}

- (void)dealloc {
    [[self view] removeFromSuperview];
}

- (void)ensureContentsVisible {
    NSArray* subviews = [contentsContainer_ subviews];
    if ([subviews count] == 0) {
        [contentsContainer_ addSubview:contents_.view];
        [contents_ viewFrameDidChange:[contentsContainer_ bounds]];
    } else if ([subviews objectAtIndex:0] != contents_.view) {
        NSView *subview = [subviews objectAtIndex:0];
        [contentsContainer_ replaceSubview:subview with:contents_.view];
        [contents_ viewFrameDidChange:[subview bounds]];
    }
}

- (BOOL)isCurrentTab {
    return [[self view] superview] ? YES : NO;
}

- (void)willBecomeSelectedTab {
    [contents_ tabWillBecomeSelected];
}

- (void)willResignSelectedTab {
    [contents_ tabWillResignSelected];
}

- (void)tabDidChange:(CTTabContents*)updatedContents {
    if (contents_ != updatedContents) {
        updatedContents.isSelected = contents_.isSelected;
        updatedContents.isVisible = contents_.isVisible;
        contents_ = updatedContents;
        [self ensureContentsVisible];
    }
}

@end
