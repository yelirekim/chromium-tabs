#import "CTTabWindowController.h"
#import "CTTabStripView.h"
#import "FastResizeView.h"

@interface CTTabWindowController(PRIVATE)
- (void)setUseOverlay:(BOOL)useOverlay;
@end

@interface TabWindowOverlayWindow : NSWindow
@end

@implementation TabWindowOverlayWindow

- (NSPoint)themePatternPhase {
    return NSZeroPoint;
}

@end

@implementation CTTabWindowController {
    IBOutlet FastResizeView* tabContentArea_;
    IBOutlet CTTabStripView* topTabStripView_;
    IBOutlet CTTabStripView* sideTabStripView_;
    NSWindow* overlayWindow_;
    NSView* cachedContentView_;
    NSMutableSet* lockedTabs_;
    BOOL closeDeferred_;
    CGFloat contentAreaHeightDelta_;
    BOOL didShowNewTabButtonBeforeTemporalAction_;
}
@synthesize tabContentArea = tabContentArea_;
@synthesize didShowNewTabButtonBeforeTemporalAction = didShowNewTabButtonBeforeTemporalAction_;

- (id)initWithWindow:(NSWindow*)window {
    if ((self = [super initWithWindow:window]) != nil) {
        lockedTabs_ = [[NSMutableSet alloc] initWithCapacity:10];
    }
    return self;
}

- (void)dealloc {
    if (overlayWindow_) {
        [self setUseOverlay:NO];
    }
}

- (void)addSideTabStripToWindow {
    NSView* contentView = [[self window] contentView];
    NSRect contentFrame = [contentView frame];
    NSRect sideStripFrame = NSMakeRect(0, 0,
                                       NSWidth([sideTabStripView_ frame]),
                                       NSHeight(contentFrame));
    [sideTabStripView_ setFrame:sideStripFrame];
    [contentView addSubview:sideTabStripView_];
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

- (void)windowDidLoad {
    NSRect tabFrame = [tabContentArea_ frame];
    NSRect contentFrame = [[[self window] contentView] frame];
    contentAreaHeightDelta_ = NSHeight(contentFrame) - NSHeight(tabFrame);
    
    if ([self hasTabStrip]) {
        if ([self useVerticalTabs]) {
            tabFrame.size.height = contentFrame.size.height;
            [tabContentArea_ setFrame:tabFrame];
            [self addSideTabStripToWindow];
        } else {
            [self addTopTabStripToWindow];
        }
    } else {
        tabFrame.size.height = contentFrame.size.height;
        [tabContentArea_ setFrame:tabFrame];
    }
}

- (void)toggleTabStripDisplayMode {
    BOOL useVertical = [self useVerticalTabs];
    NSRect tabContentsFrame = [tabContentArea_ frame];
    tabContentsFrame.size.height += useVertical ?
    contentAreaHeightDelta_ : -contentAreaHeightDelta_;
    [tabContentArea_ setFrame:tabContentsFrame];
    
    if (useVertical) {
        [topTabStripView_ removeFromSuperview];
        [self addSideTabStripToWindow];
    } else {
        [sideTabStripView_ removeFromSuperview];
        NSRect tabContentsFrame = [tabContentArea_ frame];
        tabContentsFrame.size.height -= contentAreaHeightDelta_;
        [tabContentArea_ setFrame:tabContentsFrame];
        [self addTopTabStripToWindow];
    }
    
    [self layoutSubviews];
}

- (CTTabStripView*)tabStripView {
    if ([self useVerticalTabs])
        return sideTabStripView_;
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

-(void)willStartTearingTab {
}

-(void)willEndTearingTab {
}

-(void)didEndTearingTab {
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

- (BOOL)canReceiveFrom:(CTTabWindowController*)source {
    // subclass must implement
    [self doesNotRecognizeSelector:_cmd];
    return NO;
}

- (void)moveTabView:(NSView*)view fromController:(CTTabWindowController*)dragController {
    [self doesNotRecognizeSelector:_cmd];
}

- (NSView*)selectedTabView {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (void)layoutTabs {
    // subclass must implement
    [self doesNotRecognizeSelector:_cmd];
}

- (CTTabWindowController*)detachTabToNewWindow:(CTTabView*)tabView {
    // subclass must implement
    [self doesNotRecognizeSelector:_cmd];
    return NULL;
}

- (void)insertPlaceholderForTab:(CTTabView*)tab frame:(NSRect)frame yStretchiness:(CGFloat)yStretchiness {
    self.showsNewTabButton = NO;
}

- (void)removePlaceholder {
    if (didShowNewTabButtonBeforeTemporalAction_) {
        self.showsNewTabButton = YES;
    }
}

- (BOOL)tabDraggingAllowed {
    return YES;
}

- (BOOL)tabTearingAllowed {
    return YES;
}

- (BOOL)windowMovementAllowed {
    return YES;
}

- (BOOL)isTabFullyVisible:(CTTabView*)tab {
    // Subclasses should implement this, but it's not necessary.
    return YES;
}

- (void)setShowsNewTabButton:(BOOL)show {
    // subclass must implement
    [self doesNotRecognizeSelector:_cmd];
}

- (BOOL)showsNewTabButton {
    // subclass must implement
    [self doesNotRecognizeSelector:_cmd];
    return NO;
}


- (void)detachTabView:(NSView*)view {
    // subclass must implement
    [self doesNotRecognizeSelector:_cmd];
}

- (NSInteger)numberOfTabs {
    // subclass must implement
    [self doesNotRecognizeSelector:_cmd];
    return 0;
}

- (BOOL)hasLiveTabs {
    // subclass must implement
    [self doesNotRecognizeSelector:_cmd];
    return NO;
}

- (NSString*)selectedTabTitle {
    // subclass must implement
    [self doesNotRecognizeSelector:_cmd];
    return @"";
}

- (BOOL)hasTabStrip {
    // Subclasses should implement this.
    [self doesNotRecognizeSelector:_cmd];
    return YES;
}

- (BOOL)useVerticalTabs {
    // Subclasses should implement this.
    [self doesNotRecognizeSelector:_cmd];
    return NO;
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

- (void)layoutSubviews {
    [self doesNotRecognizeSelector:_cmd];
}

@end
