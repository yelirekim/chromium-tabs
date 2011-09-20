#import "CTToolbarController.h"
#import "CTBrowser.h"
#import "CTToolbarView.h"
#import "CTTabContents.h"
#import "BackgroundGradientView.h"

@interface CTToolbarController (Private)
- (BackgroundGradientView*)backgroundGradientView;
- (void)toolbarFrameChanged;
@end

@implementation CTToolbarController {
    CTBrowser* browser_;
    NSTrackingArea* trackingArea_;
}

- (id)initWithBrowser:(CTBrowser*)browser {
    if (nil != (self = [self initWithNibName:@"Toolbar" bundle:[NSBundle bundleForClass:[self class]]])) {
        browser_ = browser;
    }
    return self;
}

- (void)updateToolbarWithContents:(CTTabContents*)contents shouldRestoreState:(BOOL)shouldRestore {
    // subclasses should implement this
}

- (void)setDividerOpacity:(CGFloat)opacity {
    BackgroundGradientView* view = [self backgroundGradientView];
    [view setShowsDivider:(opacity > 0 ? YES : NO)];
    if ([view isKindOfClass:[CTToolbarView class]]) {
        CTToolbarView* toolbarView = (CTToolbarView*)view;
        [toolbarView setDividerOpacity:opacity];
    }
}

#pragma mark -
#pragma mark Private

- (BackgroundGradientView*)backgroundGradientView {
    assert([[super view] isKindOfClass:[BackgroundGradientView class]]);
    return (BackgroundGradientView*)[super view];
}


@end
