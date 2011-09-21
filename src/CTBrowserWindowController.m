#import "CTBrowserWindowController.h"
#import "CTBrowser+Private.h"
#import "CTTabStripModel.h"
#import "CTTabContents.h"
#import "CTTabStripController.h"
#import "CTTabView.h"
#import "CTTabStripView.h"
#import "FastResizeView.h"

@interface NSWindow (ThingsThatMightBeImplemented)
- (void)setShouldHideTitle:(BOOL)y;
- (void)setBottomCornerRounded:(BOOL)y;
@end

@interface CTBrowserWindowController (Private)

- (CGFloat)layoutTabStripAtMaxY:(CGFloat)maxY width:(CGFloat)width;
- (void)setUseOverlay:(BOOL)useOverlay;
- (void)detachTabView:(NSView*)view;
- (void)layoutSubviews;

@end

@interface TabWindowOverlayWindow : NSWindow
@end

@implementation TabWindowOverlayWindow

- (NSPoint)themePatternPhase {
    return NSZeroPoint;
}

@end

@implementation NSDocumentController (CTBrowserWindowControllerAdditions)
- (id)openUntitledDocumentWithWindowController:(NSWindowController*)windowController display:(BOOL)display error:(NSError **)outError {
    return [self openUntitledDocumentAndDisplay:display error:outError];
}
@end

@implementation CTBrowserWindowController {
    BOOL initializing_;
    IBOutlet FastResizeView* tabContentArea_;
    IBOutlet CTTabStripView* topTabStripView_;
    NSWindow* overlayWindow_;
    NSView* cachedContentView_;
    NSMutableSet* lockedTabs_;
    BOOL closeDeferred_;
    CGFloat contentAreaHeightDelta_;
    BOOL didShowNewTabButtonBeforeTemporalAction_;
    id ob1;
}

@synthesize tabContentArea = tabContentArea_;
@synthesize didShowNewTabButtonBeforeTemporalAction = didShowNewTabButtonBeforeTemporalAction_;
@synthesize tabStripController = tabStripController_;
@synthesize browser = browser_;

+ (CTBrowserWindowController*)browserWindowController {
    return [[self alloc] init];
}

- (void)dealloc {
    if (overlayWindow_) {
        [self setUseOverlay:NO];
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:ob1];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (id)initWithWindowNibPath:(NSString *)windowNibPath browser:(CTBrowser*)browser {
    if (nil != (self = [super initWithWindowNibPath:windowNibPath owner:self])) {
        initializing_ = YES;
        
        browser_ = browser;
        browser_.windowController = self;
        
        NSWindow *window = [self window];
        if ([window respondsToSelector:@selector(setBottomCornerRounded:)]) {
            [window setBottomCornerRounded:NO];
        }
        [[window contentView] setAutoresizesSubviews:YES];
        
        tabStripController_ = [[CTTabStripController alloc] initWithView:self.tabStripView switchView:self.tabContentArea browser:browser_];
        
        [self setShouldCloseDocument:YES];
        
        [self layoutSubviews];
        
        initializing_ = NO;
        
        ob1 = [[NSNotificationCenter defaultCenter] addObserverForName:kCTTabStripEmptyNotification object:browser_.tabStripModel2 queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification* notification) {
            [self close];
        }];
    }
    
    return self;
}

- (id)initWithBrowser:(CTBrowser *)browser {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *windowNibPath = [bundle pathForResource:@"BrowserWindow" ofType:@"nib"];
    return [self initWithWindowNibPath:windowNibPath browser:browser];
}

- (id)init {
    return [self initWithBrowser:[CTBrowser browser]];
}

- (void)addTopTabStripToWindow {
    NSRect contentFrame = [tabContentArea_ frame];
    NSRect tabFrame = NSMakeRect(0, NSMaxY(contentFrame),
                                 NSWidth(contentFrame),
                                 NSHeight([topTabStripView_ frame]));
    [topTabStripView_ setFrame:tabFrame];
    NSView* contentParent = [[[self window] contentView] superview];
    [contentParent addSubview:topTabStripView_];
}

#pragma mark -
#pragma mark NSWindowController

- (BOOL)windowShouldClose:(id)sender {
    NSDisableScreenUpdates();
    @try {
        if ([browser_.tabStripModel2 count]) {
            [[self window] orderOut:self];
            [browser_ windowDidBeginToClose];
            return NO;
        }
        
        return YES;
    } @finally {
        NSEnableScreenUpdates();
    }
}

- (void)windowDidBecomeMain:(NSNotification*)notification {
    [[self window] setViewsNeedDisplay:YES];
}

- (void)windowDidResignMain:(NSNotification*)notification {
    [[self window] setViewsNeedDisplay:YES];
}

- (void)windowDidBecomeKey:(NSNotification*)notification {
    if (![[self window] isMiniaturized]) {
        CTTabContents* contents = [self selectedTabContents];
        if (contents) {
            contents.isVisible = YES;
        }
    }
}

- (void)windowDidResignKey:(NSNotification*)notification {
    if ([NSApp isActive] && ([NSApp keyWindow] == [self window])) {
        return;
    }
}

- (void)windowDidMiniaturize:(NSNotification *)notification {
    CTTabContents* contents = [self selectedTabContents];
    if (contents) {
        contents.isVisible = NO;
    }
}

- (void)windowDidDeminiaturize:(NSNotification *)notification {
    CTTabContents* contents = [self selectedTabContents];
    if (contents) {
        contents.isVisible = YES;
    }
}

- (void)applicationDidHide:(NSNotification *)notification {
    if (![[self window] isMiniaturized]) {
        CTTabContents* contents = [self selectedTabContents];
        if (contents) {
            contents.isVisible = NO;
        }
    }
}

- (void)applicationDidUnhide:(NSNotification *)notification {
    if (![[self window] isMiniaturized]) {
        CTTabContents* contents = [self selectedTabContents];
        if (contents) {
            contents.isVisible = YES;
        }
    }
}

- (void)windowDidLoad {
    NSRect tabFrame = [tabContentArea_ frame];
    NSRect contentFrame = [[[self window] contentView] frame];
    contentAreaHeightDelta_ = NSHeight(contentFrame) - NSHeight(tabFrame);
    
    if ([self hasTabStrip]) {
        [self addTopTabStripToWindow];
    } else {
        tabFrame.size.height = contentFrame.size.height;
        [tabContentArea_ setFrame:tabFrame];
    }
}

#pragma mark -

- (CTTabStripView*)tabStripView {
    return topTabStripView_;
}

- (void)removeOverlay {
    [self setUseOverlay:NO];
    if (closeDeferred_) {
        [[self window] orderOut:self];
        [[self window] performClose:self];
    }
}

- (void)showOverlay {
    [self setUseOverlay:YES];
}

- (void)moveViewsBetweenWindowAndOverlay:(BOOL)useOverlay {
    if (useOverlay) {
        [[[overlayWindow_ contentView] superview] addSubview:[self tabStripView]];
        [[overlayWindow_ contentView] addSubview:cachedContentView_];
    } else {
        [[self window] setContentView:cachedContentView_];
        [[[[self window] contentView] superview] addSubview:[self tabStripView]];
        [[[[self window] contentView] superview] updateTrackingAreas];
    }
}

- (void)setUseOverlay:(BOOL)useOverlay {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(removeOverlay) object:nil];
    NSWindow* window = [self window];
    if (useOverlay && !overlayWindow_) {
        assert(!cachedContentView_);
        overlayWindow_ = [[TabWindowOverlayWindow alloc] initWithContentRect:[window frame] styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:YES];
        [overlayWindow_ setTitle:@"overlay"];
        [overlayWindow_ setBackgroundColor:[NSColor clearColor]];
        [overlayWindow_ setOpaque:NO];
        [overlayWindow_ setDelegate:self];
        cachedContentView_ = [window contentView];
        [window addChildWindow:overlayWindow_ ordered:NSWindowAbove];
        [self moveViewsBetweenWindowAndOverlay:useOverlay];
        [overlayWindow_ orderFront:nil];
    } else if (!useOverlay && overlayWindow_) {
        assert(cachedContentView_);
        [overlayWindow_ setDelegate:nil];
        [window setDelegate:nil];
        [window setContentView:cachedContentView_];
        [self moveViewsBetweenWindowAndOverlay:useOverlay];
        [window makeFirstResponder:cachedContentView_];
        [window display];
        [window removeChildWindow:overlayWindow_];
        [overlayWindow_ orderOut:nil];
        overlayWindow_ = nil;
        cachedContentView_ = nil;
    }
}

- (NSWindow*)overlayWindow {
    return overlayWindow_;
}

- (BOOL)shouldConstrainFrameRect {
    return overlayWindow_ == nil;
}

- (BOOL)tabTearingAllowed {
    return YES;
}

- (BOOL)windowMovementAllowed {
    return YES;
}

- (BOOL)isTabDraggable:(NSView*)tabView {
    return ![lockedTabs_ containsObject:tabView];
}

- (void)setTab:(NSView*)tabView isDraggable:(BOOL)draggable {
    if (draggable) {
        [lockedTabs_ removeObject:tabView];
    } else {
        [lockedTabs_ addObject:tabView];
    }
}

- (void)deferPerformClose {
    closeDeferred_ = YES;
}

// Browser Window

#pragma mark -
#pragma mark NSWindow (CTThemed)

- (NSPoint)themePatternPhase {
    const CGFloat kPatternHorizontalOffset = -5;
    NSView* tabStripView = [self tabStripView];
    NSRect tabStripViewWindowBounds = [tabStripView bounds];
    NSView* windowChromeView = [[[self window] contentView] superview];
    tabStripViewWindowBounds =
    [tabStripView convertRect:tabStripViewWindowBounds toView:windowChromeView];
    return NSMakePoint(NSMinX(tabStripViewWindowBounds) + kPatternHorizontalOffset, NSMinY(tabStripViewWindowBounds) + [CTTabStripController defaultTabHeight]);
}


#pragma mark -
#pragma mark Actions

- (IBAction)saveAllDocuments:(id)sender {
    [[NSDocumentController sharedDocumentController] saveAllDocuments:sender];
}

- (IBAction)openDocument:(id)sender {
    [[NSDocumentController sharedDocumentController] openDocument:sender];
}

- (IBAction)newDocument:(id)sender {
    NSDocumentController* docController =
    [NSDocumentController sharedDocumentController];
    NSError *error = nil;
    assert(browser_);
    CTTabContents *baseTabContents = [self selectedTabContents];
    CTTabContents *tabContents = [docController openUntitledDocumentWithWindowController:self display:YES error:&error];
    if (!tabContents) {
        [NSApp presentError:error];
    } else if (baseTabContents) {
        tabContents.parentOpener = baseTabContents;
    }
}

- (IBAction)newWindow:(id)sender {
    CTBrowserWindowController* windowController = [isa browserWindowController];
    [windowController newDocument:sender];
    [windowController showWindow:self];
}

- (void)commandDispatch:(id)sender {
    assert(sender);
    CTBrowserWindowController* targetController = self;
    if ([sender respondsToSelector:@selector(window)]) {
        targetController = [[sender window] windowController];
    }
    assert([targetController isKindOfClass:[CTBrowserWindowController class]]);
    [targetController.browser executeCommand:[sender tag]];
}

-(IBAction)closeTab:(id)sender {
    CTTabStripModel *tabStripModel2 = browser_.tabStripModel2;
    [tabStripModel2 closeTabContentsAtIndex:[tabStripModel2 selectedIndex] options:CLOSE_CREATE_HISTORICAL_TAB];
}

#pragma mark -
#pragma mark CTBrowserWindowController implementation

- (BOOL)canReceiveFrom:(CTBrowserWindowController*)source {
    if (![source isKindOfClass:[isa class]]) {
        return NO;
    }
    return YES;
}

- (void)moveTabView:(NSView*)view fromController:(CTBrowserWindowController*)dragController {
    if (dragController) {
        BOOL isBrowser =
        [dragController isKindOfClass:[CTBrowserWindowController class]];
        assert(isBrowser);
        if (!isBrowser) return;
        CTBrowserWindowController* dragBWC = (CTBrowserWindowController*)dragController;
        int index = [dragBWC->tabStripController_ modelIndexForTabView:view];
        CTTabContents* contents =
        [dragBWC->browser_.tabStripModel2 tabContentsAtIndex:index];
        if (!contents) {
            return;
        }
        
        NSRect destinationFrame = [view frame];
        NSPoint tabOrigin = destinationFrame.origin;
        tabOrigin = [[dragController tabStripView] convertPoint:tabOrigin toView:nil];
        tabOrigin = [[view window] convertBaseToScreen:tabOrigin];
        tabOrigin = [[self window] convertScreenToBase:tabOrigin];
        tabOrigin = [[self tabStripView] convertPoint:tabOrigin fromView:nil];
        destinationFrame.origin = tabOrigin;
        
        [dragController detachTabView:view];
        [tabStripController_ dropTabContents:contents withFrame:destinationFrame];
    } else {
        int index = [tabStripController_ modelIndexForTabView:view];
        [tabStripController_ moveTabFromIndex:index];
    }
    
    [self removePlaceholder];
}

- (NSView*)selectedTabView {
    return [tabStripController_ selectedTabView];
}

- (void)layoutTabs {
    [tabStripController_ layoutTabs];
}

- (CTBrowserWindowController*)detachTabToNewWindow:(CTTabView*)tabView {
    NSDisableScreenUpdates();
    @try {
        CTTabStripModel *tabStripModel2 = [browser_ tabStripModel2];
        
        int index = [tabStripController_ modelIndexForTabView:tabView];
        CTTabContents* contents = [tabStripModel2 tabContentsAtIndex:index];
        
        NSWindow* sourceWindow = [tabView window];
        NSRect windowRect = [sourceWindow frame];
        NSScreen* screen = [sourceWindow screen];
        windowRect.origin.y = [screen frame].size.height - windowRect.size.height - windowRect.origin.y;
        
        NSRect tabRect = [tabView frame];
        [tabStripModel2 detachTabContentsAtIndex:index];
        
        CTBrowser* newBrowser = [[browser_ class] browser];
        CTBrowserWindowController* controller = [[[self class] alloc] initWithBrowser:newBrowser];
        
        [newBrowser.tabStripModel2 appendTabContents:contents foreground:YES];
        [newBrowser loadingStateDidChange:contents];
        
        [controller.window setFrame:windowRect display:NO];
        tabRect.size.height = [CTTabStripController defaultTabHeight];
        [[controller tabStripController] setFrameOfSelectedTab:tabRect];
        
        return controller;
    } @finally {
        NSEnableScreenUpdates();
    }
}

- (void)insertPlaceholderForTab:(CTTabView*)tab frame:(NSRect)frame yStretchiness:(CGFloat)yStretchiness {
    self.showsNewTabButton = NO;
    [tabStripController_ insertPlaceholderForTab:tab frame:frame yStretchiness:yStretchiness];
}

- (void)removePlaceholder {
    if (didShowNewTabButtonBeforeTemporalAction_) {
        self.showsNewTabButton = YES;
    }
    [tabStripController_ insertPlaceholderForTab:nil frame:NSZeroRect yStretchiness:0];
}

- (BOOL)tabDraggingAllowed {
    return [tabStripController_ tabDraggingAllowed];
}

- (BOOL)isTabFullyVisible:(CTTabView*)tab {
	return [tabStripController_ isTabFullyVisible:tab];
}

- (void)setShowsNewTabButton:(BOOL)show {
    tabStripController_.showsNewTabButton = show;
}

- (BOOL)showsNewTabButton {
    return tabStripController_.showsNewTabButton;
}

- (void)detachTabView:(NSView*)view {
    int index = [tabStripController_ modelIndexForTabView:view];
    [browser_.tabStripModel2 detachTabContentsAtIndex:index];
}

- (NSInteger)numberOfTabs {
    return browser_.tabStripModel2.count;
}

- (BOOL)hasLiveTabs {
    return [browser_.tabStripModel2 count];
}

- (int)selectedTabIndex {
    return [browser_.tabStripModel2 selectedIndex];
}

- (CTTabContents*)selectedTabContents {
    return [browser_.tabStripModel2 selectedTabContents];
}

- (NSString*)selectedTabTitle {
    CTTabContents* contents = [self selectedTabContents];
    return contents ? contents.title : nil;
}

- (BOOL)hasTabStrip {
    return YES;
}

- (void)layoutSubviews {
    NSWindow* window = [self window];
    NSView* contentView = [window contentView];
    NSRect contentBounds = [contentView bounds];
    CGFloat minX = NSMinX(contentBounds);
    CGFloat minY = NSMinY(contentBounds);
    CGFloat width = NSWidth(contentBounds);
    
    if ([window respondsToSelector:@selector(setShouldHideTitle:)])
        [window setShouldHideTitle:YES];
    
    CGFloat yOffset = 0;
    CGFloat maxY = NSMaxY(contentBounds) + yOffset;
    
    if ([self hasTabStrip]) {
        NSRect windowFrame = [contentView convertRect:[window frame] fromView:nil];
        maxY = NSHeight(windowFrame) + yOffset;
        maxY = [self layoutTabStripAtMaxY:maxY width:width];
    }
    
    assert(maxY >= minY);
    assert(maxY <= NSMaxY(contentBounds) + yOffset);
    
    NSRect contentAreaRect = NSMakeRect(minX, minY, width, maxY - minY);
    [self layoutTabContentArea:contentAreaRect];
}

-(void)willStartTearingTab {
    CTTabContents* contents = [self selectedTabContents];
    if (contents) {
        contents.isTeared = YES;
    }
}

-(void)willEndTearingTab {
    CTTabContents* contents = [self selectedTabContents];
    if (contents) {
        contents.isTeared = NO;
    }
}

-(void)didEndTearingTab {
    CTTabContents* contents = [self selectedTabContents];
    if (contents) {
        [contents tabDidResignTeared];
    }
}

#pragma mark -
#pragma mark Layout

- (void)layoutTabContentArea:(NSRect)newFrame {
    FastResizeView* tabContentView = self.tabContentArea;
    NSRect tabContentFrame = tabContentView.frame;
    BOOL contentShifted =
    NSMaxY(tabContentFrame) != NSMaxY(newFrame) ||
    NSMinX(tabContentFrame) != NSMinX(newFrame);
    tabContentFrame.size.height = newFrame.size.height;
    [tabContentView setFrame:tabContentFrame];
    if (contentShifted) {
        CTTabContents* contents = [self selectedTabContents];
        if (contents) {
            [contents viewFrameDidChange:newFrame];
        }
    }
}

#pragma mark -
#pragma mark Private

- (CGFloat)layoutTabStripAtMaxY:(CGFloat)maxY width:(CGFloat)width {
    if (![self hasTabStrip]) {
        return maxY;
    }
    
    NSView* tabStripView = [self tabStripView];
    CGFloat tabStripHeight = NSHeight([tabStripView frame]);
    maxY -= tabStripHeight;
    [tabStripView setFrame:NSMakeRect(0, maxY, width, tabStripHeight)];
    
    [tabStripController_ setIndentForControls:[[tabStripController_ class] defaultIndentForControls]];
    
    [tabStripController_ layoutTabs];
    
    return maxY;
}

#pragma mark -
#pragma mark Etc (need sorting out)

- (void)activate {
    [[self window] makeKeyAndOrderFront:self];
}

- (void)focusTabContents {
    CTTabContents* contents = [self selectedTabContents];
    if (contents) {
        [[self window] makeFirstResponder:contents.view];
    }
}

@end
