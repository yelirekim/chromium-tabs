
@class FastResizeView;
@class CTTabStripView;
@class CTTabView;

@interface CTTabWindowController : NSWindowController<NSWindowDelegate>

@property(strong, readonly, nonatomic) CTTabStripView* tabStripView;
@property(strong, readonly, nonatomic) FastResizeView* tabContentArea;
@property(assign, nonatomic) BOOL didShowNewTabButtonBeforeTemporalAction;
@property(nonatomic, assign) BOOL showsNewTabButton;

- (void)showOverlay;
- (void)removeOverlay;
- (NSWindow*)overlayWindow;
- (BOOL)shouldConstrainFrameRect;
- (void)layoutTabs;
- (CTTabWindowController*)detachTabToNewWindow:(CTTabView*)tabView;
- (void)insertPlaceholderForTab:(CTTabView*)tab frame:(NSRect)frame yStretchiness:(CGFloat)yStretchiness;
- (void)removePlaceholder;

- (BOOL)tabDraggingAllowed;
- (BOOL)tabTearingAllowed;
- (BOOL)windowMovementAllowed;

-(void)willStartTearingTab;
-(void)willEndTearingTab;
-(void)didEndTearingTab;

- (BOOL)isTabFullyVisible:(CTTabView*)tab;
- (BOOL)canReceiveFrom:(CTTabWindowController*)source;
- (void)moveTabView:(NSView*)view fromController:(CTTabWindowController*)controller;
- (NSInteger)numberOfTabs;
- (BOOL)hasLiveTabs;
- (NSView *)selectedTabView;
- (NSString*)selectedTabTitle;
- (BOOL)hasTabStrip;
- (BOOL)useVerticalTabs;
- (BOOL)isTabDraggable:(NSView*)tabView;
- (void)setTab:(NSView*)tabView isDraggable:(BOOL)draggable;
- (void)deferPerformClose;

@end

@interface CTTabWindowController(ProtectedMethods)

- (void)detachTabView:(NSView*)view;
- (void)toggleTabStripDisplayMode;
- (void)layoutSubviews;

@end
