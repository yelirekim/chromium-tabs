#import "CTTabViewController.h"
#import "CTTabView.h"
#import "HoverCloseButton.h"

static NSString* const kBrowserThemeDidChangeNotification = @"BrowserThemeDidChangeNotification";

@implementation CTTabViewController {
    IBOutlet NSView* iconView_;
    IBOutlet NSTextField* titleView_;
    IBOutlet HoverCloseButton* closeButton_;
    
    NSRect originalIconFrame_;
    BOOL isIconShowing_;
    
    BOOL app_;
    BOOL phantom_;
    BOOL selected_;
    CTTabLoadingState loadingState_;
    CGFloat iconTitleXOffset_;
    CGFloat titleCloseWidthOffset_;
    SEL action_;
}

@synthesize action = action_;
@synthesize app = app_;
@synthesize loadingState = loadingState_;
@synthesize phantom = phantom_;
@synthesize target = target_;

+ (CGFloat)minTabWidth { return 31; }
+ (CGFloat)minSelectedTabWidth { return 46; }
+ (CGFloat)maxTabWidth { return 220; }
+ (CGFloat)appTabWidth { return 66; }

- (CTTabView*)tabView {
    return (CTTabView*)[self view];
}

- (id)init {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    return [self initWithNibName:@"TabView" bundle:bundle];
}

- (id)initWithNibName:(NSString*)nibName bundle:(NSBundle*)bundle {
    self = [super initWithNibName:nibName bundle:bundle];
    assert(self);
    if (self != nil) {
        isIconShowing_ = YES;
        NSNotificationCenter* defaultCenter = [NSNotificationCenter defaultCenter];
        [defaultCenter addObserver:self selector:@selector(viewResized:) name:NSViewFrameDidChangeNotification object:[self view]];
        [defaultCenter addObserver:self selector:@selector(themeChangedNotification:) name:kBrowserThemeDidChangeNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[self tabView] setController:nil];
}

- (void)internalSetSelected:(BOOL)selected {
    selected_ = selected;
    CTTabView* tabView = (CTTabView*)[self view];
    assert([tabView isKindOfClass:[CTTabView class]]);
    [tabView setState:selected];
    [tabView cancelAlert];
    [self updateVisibility];
    [self updateTitleColor];
}

- (void)awakeFromNib {
    originalIconFrame_ = [iconView_ frame];
    
    NSRect titleFrame = [titleView_ frame];
    iconTitleXOffset_ = NSMinX(titleFrame) - NSMinX(originalIconFrame_);
    titleCloseWidthOffset_ = NSMaxX([closeButton_ frame]) - NSMaxX(titleFrame);
    
    [self internalSetSelected:selected_];
}

- (NSMenu*)menu {
    return nil;
}

- (IBAction)closeTab:(id)sender {
    if ([[self target] respondsToSelector:@selector(closeTab:)]) {
        [[self target] performSelector:@selector(closeTab:) withObject:[self view]];
    }
}

- (void)setTitle:(NSString*)title {
    [[self view] setToolTip:title];
    [super setTitle:title];
}

- (void)setSelected:(BOOL)selected {
    if (selected_ != selected) {
        [self internalSetSelected:selected];
    }
}

- (BOOL)selected {
    return selected_;
}

- (void)setIconView:(NSView*)iconView {
    [iconView_ removeFromSuperview];
    iconView_ = iconView;
    if ([self app]) {
        NSRect appIconFrame = [iconView frame];
        appIconFrame.origin = originalIconFrame_.origin;
        appIconFrame.origin.x = ([CTTabViewController appTabWidth] - NSWidth(appIconFrame)) / 2.0;
        [iconView setFrame:appIconFrame];
    } else {
        [iconView_ setFrame:originalIconFrame_];
    }
    [self updateVisibility];
    
    if (iconView_) {
        [[self view] addSubview:iconView_];
    }
}

- (NSView*)iconView {
    return iconView_;
}

- (NSString*)toolTip {
    return [[self view] toolTip];
}

- (CGFloat)iconCapacity {
    CGFloat width = NSMaxX([closeButton_ frame]) - NSMinX(originalIconFrame_);
    CGFloat iconWidth = NSWidth(originalIconFrame_);
    
    return width / iconWidth;
}

- (BOOL)shouldShowIcon {
    if (!iconView_) {
        return NO;
    }
    
    CGFloat iconCapacity = [self iconCapacity];
    if ([self selected]) {
        return iconCapacity >= 2.0;
    }
    return iconCapacity >= 1.0;
}

- (BOOL)shouldShowCloseButton {
    return ([self selected] || [self iconCapacity] >= 3.0);
}

- (void)updateVisibility {
    BOOL oldShowIcon = isIconShowing_ ? YES : NO;
    BOOL newShowIcon = [self shouldShowIcon] ? YES : NO;
    
    [iconView_ setHidden:newShowIcon ? NO : YES];
    isIconShowing_ = newShowIcon;
    
    BOOL oldShowCloseButton = [closeButton_ isHidden] ? NO : YES;
    BOOL newShowCloseButton = [self shouldShowCloseButton] ? YES : NO;
    
    [closeButton_ setHidden:newShowCloseButton ? NO : YES];
    
    NSRect titleFrame = [titleView_ frame];
    
    if (oldShowIcon != newShowIcon) {
        if (newShowIcon) {
            titleFrame.origin.x += iconTitleXOffset_;
            titleFrame.size.width -= iconTitleXOffset_;
        } else {
            titleFrame.origin.x -= iconTitleXOffset_;
            titleFrame.size.width += iconTitleXOffset_;
        }
    }
    
    if (oldShowCloseButton != newShowCloseButton) {
        if (newShowCloseButton) {
            titleFrame.size.width -= titleCloseWidthOffset_;
        } else {
            titleFrame.size.width += titleCloseWidthOffset_;
        }
    }
    
    [titleView_ setFrame:titleFrame];
}

- (void)updateTitleColor {
    NSColor* titleColor = [self selected] ? [NSColor blackColor] :
    [NSColor darkGrayColor];
    [titleView_ setTextColor:titleColor];
}

- (void)viewResized:(NSNotification*)info {
    [self updateVisibility];
}

- (void)themeChangedNotification:(NSNotification*)notification {
    [self updateTitleColor];
}

- (BOOL)inRapidClosureMode {
    if ([[self target] respondsToSelector:@selector(inRapidClosureMode)]) {
        return [[self target] performSelector:@selector(inRapidClosureMode)] ? YES : NO;
    }
    return NO;
}

@end
