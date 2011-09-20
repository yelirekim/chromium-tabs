#import "CTBrowserWindowController.h"
#import "CTBrowser+Private.h"
#import "CTTabStripModel2.h"
#import "CTTabContents.h"
#import "CTTabStripController.h"
#import "CTTabView.h"
#import "CTTabStripView.h"
#import "CTToolbarController.h"
#import "FastResizeView.h"

@interface NSWindow (ThingsThatMightBeImplemented)
- (void)setShouldHideTitle:(BOOL)y;
- (void)setBottomCornerRounded:(BOOL)y;
@end

@interface CTBrowserWindowController (Private)

- (CGFloat)layoutTabStripAtMaxY:(CGFloat)maxY width:(CGFloat)width fullscreen:(BOOL)fullscreen;
- (CGFloat)layoutToolbarAtMinX:(CGFloat)minX  maxY:(CGFloat)maxY width:(CGFloat)width;

@end

@implementation NSDocumentController (CTBrowserWindowControllerAdditions)
- (id)openUntitledDocumentWithWindowController:(NSWindowController*)windowController display:(BOOL)display error:(NSError **)outError {
    return [self openUntitledDocumentAndDisplay:display error:outError];
}
@end

static CTBrowserWindowController* _currentMain = nil;

@implementation CTBrowserWindowController {
    BOOL initializing_;
    id ob1;
    id ob2;
    id ob3;
    id ob4;
    id ob5;
    id ob6;
}

@synthesize tabStripController = tabStripController_;
@synthesize toolbarController = toolbarController_;
@synthesize browser = browser_;

+ (CTBrowserWindowController*)browserWindowController {
    return [[self alloc] init];
}

+ (CTBrowserWindowController*)mainBrowserWindowController {
    return _currentMain;
}

+ (CTBrowserWindowController*)browserWindowControllerForWindow:(NSWindow*)window {
    while (window) {
        id controller = [window windowController];
        if ([controller isKindOfClass:[CTBrowserWindowController class]]) {
            return (CTBrowserWindowController*)controller;
        }
        window = [window parentWindow];
    }
    return nil;
}

+ (CTBrowserWindowController*)browserWindowControllerForView:(NSView*)view {
    return [CTBrowserWindowController browserWindowControllerForWindow:[view window]];
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
        
        toolbarController_ = [browser_ createToolbarController];
        if (toolbarController_) {
            [[[self window] contentView] addSubview:[toolbarController_ view]];
        }
        
        [self setShouldCloseDocument:YES];
        
        [self layoutSubviews];
        
        initializing_ = NO;
        if (!_currentMain) {
            _currentMain = self;
        }
        
        ob1 = [[NSNotificationCenter defaultCenter] addObserverForName:kCTTabInsertedNotification object:browser_.tabStripModel2 queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification* notification) {
            NSDictionary* userInfo = notification.userInfo;
            CTTabContents* contents = [userInfo objectForKey:kCTTabContentsUserInfoKey];
            NSInteger index = [[userInfo valueForKey:kCTTabIndexUserInfoKey] intValue];
            BOOL foreground = [[userInfo objectForKey:kCTTabForegroundUserInfoKey] boolValue];
            [contents tabDidInsertIntoBrowser:browser_
                                      atIndex:index
                                 inForeground:foreground];
        }];
        
        ob2 = [[NSNotificationCenter defaultCenter] addObserverForName:kCTTabClosingNotification object:browser_.tabStripModel2 queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification* notification) {
            NSDictionary* userInfo = notification.userInfo;
            CTTabContents* contents = [userInfo objectForKey:kCTTabContentsUserInfoKey];
            NSInteger index = [[userInfo valueForKey:kCTTabIndexUserInfoKey] intValue];
            [contents tabWillCloseInBrowser:browser_ atIndex:index];
            if (contents.isSelected) {
                [self updateToolbarWithContents:nil shouldRestoreState:NO];
            }
        }];
        
        ob3 = [[NSNotificationCenter defaultCenter] addObserverForName:kCTTabSelectedNotification object:browser_.tabStripModel2 queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification* notification) {
            NSDictionary* userInfo = notification.userInfo;
            CTTabContents* oldContents = [userInfo objectForKey:kCTTabContentsUserInfoKey];
            CTTabContents* newContents = [userInfo objectForKey:kCTTabNewContentsUserInfoKey];
            assert(newContents != oldContents);
            [self updateToolbarWithContents:newContents
                         shouldRestoreState:nil != oldContents];
        }];
        
        ob4 = [[NSNotificationCenter defaultCenter] addObserverForName:kCTTabReplacedNotification object:browser_.tabStripModel2 queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification* notification) {
            NSDictionary* userInfo = notification.userInfo;
            CTTabContents* oldContents = [userInfo objectForKey:kCTTabContentsUserInfoKey];
            CTTabContents* contents = [userInfo objectForKey:kCTTabNewContentsUserInfoKey];
            NSInteger index = [[userInfo valueForKey:kCTTabIndexUserInfoKey] intValue];
            [contents tabReplaced:oldContents inBrowser:browser_ atIndex:index];
            if ([self selectedTabIndex] == index) {
                [self updateToolbarWithContents:contents shouldRestoreState:!!oldContents];
            }
        }];
        
        ob5 = [[NSNotificationCenter defaultCenter] addObserverForName:kCTTabDetachedNotification object:browser_.tabStripModel2 queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification* notification) {
            NSDictionary* userInfo = notification.userInfo;
            CTTabContents* contents = [userInfo objectForKey:kCTTabContentsUserInfoKey];
            NSInteger index = [[userInfo valueForKey:kCTTabIndexUserInfoKey] intValue];
            [contents tabDidDetachFromBrowser:browser_ atIndex:index];
            if (contents.isSelected) {
                [self updateToolbarWithContents:nil shouldRestoreState:NO];
            }
        }];
        
        ob6 = [[NSNotificationCenter defaultCenter] addObserverForName:kCTTabStripEmptyNotification object:browser_.tabStripModel2 queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification* notification) {
            [self close];
        }];
    }
    
    return self;
}


- (id)initWithBrowser:(CTBrowser *)browser {
    // subclasses could override this to provie a custom nib
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *windowNibPath = [bundle pathForResource:@"BrowserWindow" ofType:@"nib"];
    return [self initWithWindowNibPath:windowNibPath browser:browser];
}


- (id)init {
    // subclasses could override this to provide a custom |CTBrowser|
    return [self initWithBrowser:[CTBrowser browser]];
}


-(void)dealloc {
    if (_currentMain == self) {
        _currentMain = nil;
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:ob1];
    [[NSNotificationCenter defaultCenter] removeObserver:ob2];
    [[NSNotificationCenter defaultCenter] removeObserver:ob3];
    [[NSNotificationCenter defaultCenter] removeObserver:ob4];
    [[NSNotificationCenter defaultCenter] removeObserver:ob5];
    [[NSNotificationCenter defaultCenter] removeObserver:ob6];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    toolbarController_ = nil;
}

- (BOOL)isFullscreen {
    return NO;
}

- (BOOL)hasToolbar {
    return nil != toolbarController_;
}

- (void)updateToolbarWithContents:(CTTabContents*)contents shouldRestoreState:(BOOL)shouldRestore {
    [toolbarController_ updateToolbarWithContents:contents shouldRestoreState:shouldRestore];
}

- (void)synchronizeWindowTitleWithDocumentName {
}

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
    CTTabContents *baseTabContents = browser_.selectedTabContents;
    CTTabContents *tabContents =
    [docController openUntitledDocumentWithWindowController:self display:YES error:&error];
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
    CTTabStripModel2 *tabStripModel2 = browser_.tabStripModel2;
    [tabStripModel2 closeTabContentsAtIndex:[tabStripModel2 selectedIndex] options:CLOSE_CREATE_HISTORICAL_TAB];
}


#pragma mark -
#pragma mark CTTabWindowController implementation

- (BOOL)canReceiveFrom:(CTTabWindowController*)source {
    if (![source isKindOfClass:[isa class]]) {
        return NO;
    }
    return YES;
}

- (void)moveTabView:(NSView*)view fromController:(CTTabWindowController*)dragController {
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
        
        bool isPinned = [dragBWC->browser_.tabStripModel2 isTabPinnedAtIndex:index];
        [dragController detachTabView:view];
        [tabStripController_ dropTabContents:contents withFrame:destinationFrame asPinnedTab:isPinned];
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

- (CTTabWindowController*)detachTabToNewWindow:(CTTabView*)tabView {
    NSDisableScreenUpdates();
    @try {
        CTTabStripModel2 *tabStripModel2 = [browser_ tabStripModel2];
        
        int index = [tabStripController_ modelIndexForTabView:tabView];
        CTTabContents* contents = [tabStripModel2 tabContentsAtIndex:index];
        
        NSWindow* sourceWindow = [tabView window];
        NSRect windowRect = [sourceWindow frame];
        NSScreen* screen = [sourceWindow screen];
        windowRect.origin.y = [screen frame].size.height - windowRect.size.height - windowRect.origin.y;
        
        NSRect tabRect = [tabView frame];
        bool isPinned = [tabStripModel2 isTabPinnedAtIndex:index];
        [tabStripModel2 detachTabContentsAtIndex:index];
        
        CTBrowser* newBrowser = [[browser_ class] browser];
        CTBrowserWindowController* controller = [[[self class] alloc] initWithBrowser:newBrowser];
        
        [newBrowser.tabStripModel2 appendTabContents:contents foreground:YES];
        [newBrowser loadingStateDidChange:contents];
        
        [controller.window setFrame:windowRect display:NO];
        [newBrowser.tabStripModel2 setTabPinnedAtIndex:0 pinned:isPinned];
        tabRect.size.height = [CTTabStripController defaultTabHeight];
        [[controller tabStripController] setFrameOfSelectedTab:tabRect];
        
        return controller;
    } @finally {
        NSEnableScreenUpdates();
    }
}

- (void)insertPlaceholderForTab:(CTTabView*)tab frame:(NSRect)frame yStretchiness:(CGFloat)yStretchiness {
    [super insertPlaceholderForTab:tab frame:frame yStretchiness:yStretchiness];
    [tabStripController_ insertPlaceholderForTab:tab frame:frame yStretchiness:yStretchiness];
}

- (void)removePlaceholder {
    [super removePlaceholder];
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
    return [browser_.tabStripModel2 hasNonPhantomTabs];
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

- (BOOL)useVerticalTabs {
    return NO;
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
    
    BOOL isFullscreen = [self isFullscreen];
    CGFloat yOffset = 0;
    CGFloat maxY = NSMaxY(contentBounds) + yOffset;
    CGFloat startMaxY = maxY;
    
    if ([self hasTabStrip] && ![self useVerticalTabs]) {
        NSRect windowFrame = [contentView convertRect:[window frame] fromView:nil];
        startMaxY = maxY = NSHeight(windowFrame) + yOffset;
        maxY = [self layoutTabStripAtMaxY:maxY width:width fullscreen:isFullscreen];
    }
    
    assert(maxY >= minY);
    assert(maxY <= NSMaxY(contentBounds) + yOffset);
    
    if ([self hasToolbar]) {
        maxY = [self layoutToolbarAtMinX:minX maxY:maxY width:width];
    }
    
    if (isFullscreen) {
        maxY = NSMaxY(contentBounds);
    }
    
    NSRect contentAreaRect = NSMakeRect(minX, minY, width, maxY - minY);
    [self layoutTabContentArea:contentAreaRect];
    
    if (toolbarController_) {
        [toolbarController_ setDividerOpacity:0.4];
    }
}

- (CGFloat)layoutToolbarAtMinX:(CGFloat)minX maxY:(CGFloat)maxY width:(CGFloat)width {
    assert([self hasToolbar]);
    NSView* toolbarView = [toolbarController_ view];
    NSRect toolbarFrame = [toolbarView frame];
    assert(![toolbarView isHidden]);
    toolbarFrame.origin.x = minX;
    toolbarFrame.origin.y = maxY - NSHeight(toolbarFrame);
    toolbarFrame.size.width = width;
    maxY -= NSHeight(toolbarFrame);
    [toolbarView setFrame:toolbarFrame];
    return maxY;
}

-(void)willStartTearingTab {
    CTTabContents* contents = [browser_ selectedTabContents];
    if (contents) {
        contents.isTeared = YES;
    }
}

-(void)willEndTearingTab {
    CTTabContents* contents = [browser_ selectedTabContents];
    if (contents) {
        contents.isTeared = NO;
    }
}

-(void)didEndTearingTab {
    CTTabContents* contents = [browser_ selectedTabContents];
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
        CTTabContents* contents = [browser_ selectedTabContents];
        if (contents) {
            [contents viewFrameDidChange:newFrame];
        }
    }
}

#pragma mark -
#pragma mark Private

- (CGFloat)layoutTabStripAtMaxY:(CGFloat)maxY width:(CGFloat)width fullscreen:(BOOL)fullscreen {
    if (![self hasTabStrip]) {
        return maxY;
    }
    
    NSView* tabStripView = [self tabStripView];
    CGFloat tabStripHeight = NSHeight([tabStripView frame]);
    maxY -= tabStripHeight;
    [tabStripView setFrame:NSMakeRect(0, maxY, width, tabStripHeight)];
    
    [tabStripController_ setIndentForControls:(fullscreen ? 0 : [[tabStripController_ class] defaultIndentForControls])];
    
    [tabStripController_ layoutTabs];
    
    return maxY;
}


#pragma mark -
#pragma mark NSWindowController impl

- (BOOL)windowShouldClose:(id)sender {
    NSDisableScreenUpdates();
    @try {
        if ([browser_.tabStripModel2 hasNonPhantomTabs]) {
            [[self window] orderOut:self];
            [browser_ windowDidBeginToClose];
            if (_currentMain == self) {
                _currentMain = nil;
            }
            return NO;
        }
        
        return YES;
    } @finally {
        NSEnableScreenUpdates();
    }
}


- (void)windowWillClose:(NSNotification *)notification {
}


- (void)windowDidBecomeMain:(NSNotification*)notification {
    _currentMain = self;
    
    [[self window] setViewsNeedDisplay:YES];
}

- (void)windowDidResignMain:(NSNotification*)notification {
    if (_currentMain == self) {
        _currentMain = nil;
    }
    
    [[self window] setViewsNeedDisplay:YES];
}

- (void)windowDidBecomeKey:(NSNotification*)notification {
    if (![[self window] isMiniaturized]) {
        CTTabContents* contents = [browser_ selectedTabContents];
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
    CTTabContents* contents = [browser_ selectedTabContents];
    if (contents) {
        contents.isVisible = NO;
    }
}

- (void)windowDidDeminiaturize:(NSNotification *)notification {
    CTTabContents* contents = [browser_ selectedTabContents];
    if (contents) {
        contents.isVisible = YES;
    }
}

- (void)applicationDidHide:(NSNotification *)notification {
    if (![[self window] isMiniaturized]) {
        CTTabContents* contents = [browser_ selectedTabContents];
        if (contents) {
            contents.isVisible = NO;
        }
    }
}

- (void)applicationDidUnhide:(NSNotification *)notification {
    if (![[self window] isMiniaturized]) {
        CTTabContents* contents = [browser_ selectedTabContents];
        if (contents) {
            contents.isVisible = YES;
        }
    }
}

#pragma mark -
#pragma mark Etc (need sorting out)

- (void)activate {
    [[self window] makeKeyAndOrderFront:self];
}

- (void)focusTabContents {
    CTTabContents* contents = [browser_ selectedTabContents];
    if (contents) {
        [[self window] makeFirstResponder:contents.view];
    }
}

@end
