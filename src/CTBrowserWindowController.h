#import "CTBrowser.h"
#import "CTTabStripModelDelegate.h"

@class CTTabStripController;
@class CTTabStripView;
@class FastResizeView;
@class CTTabView;

@interface NSDocumentController (CTBrowserWindowControllerAdditions)

- (id)openUntitledDocumentWithWindowController:(NSWindowController*)windowController display:(BOOL)display error:(NSError **)outError;

@end

@interface CTBrowserWindowController : NSWindowController<NSWindowDelegate>

@property(strong, readonly, nonatomic) CTTabStripController *tabStripController;
@property(strong, readonly, nonatomic) CTBrowser *browser;
@property(readonly, nonatomic) BOOL isFullscreen;

+ (CTBrowserWindowController*)browserWindowController;

- (id)initWithWindowNibPath:(NSString *)windowNibPath browser:(CTBrowser*)browser;
- (id)initWithBrowser:(CTBrowser *)browser;
- (id)init;

- (NSPoint)themePatternPhase;

- (IBAction)saveAllDocuments:(id)sender;
- (IBAction)openDocument:(id)sender;
- (IBAction)newDocument:(id)sender;

- (CTTabContents*)selectedTabContents;
- (int)selectedTabIndex;
- (void)activate;
- (void)focusTabContents;
- (void)layoutTabContentArea:(NSRect)frame;

// Tab Window Controller

@property(strong, readonly, nonatomic) CTTabStripView* tabStripView;
@property(strong, readonly, nonatomic) FastResizeView* tabContentArea;
@property(assign, nonatomic) BOOL didShowNewTabButtonBeforeTemporalAction;
@property(nonatomic, assign) BOOL showsNewTabButton;

- (void)showOverlay;
- (void)removeOverlay;
- (NSWindow*)overlayWindow;
- (BOOL)shouldConstrainFrameRect;
- (void)layoutTabs;
- (CTBrowserWindowController*)detachTabToNewWindow:(CTTabView*)tabView;
- (void)insertPlaceholderForTab:(CTTabView*)tab frame:(NSRect)frame yStretchiness:(CGFloat)yStretchiness;
- (void)removePlaceholder;

- (BOOL)tabDraggingAllowed;
- (BOOL)tabTearingAllowed;
- (BOOL)windowMovementAllowed;

-(void)willStartTearingTab;
-(void)willEndTearingTab;
-(void)didEndTearingTab;

- (BOOL)isTabFullyVisible:(CTTabView*)tab;
- (BOOL)canReceiveFrom:(CTBrowserWindowController*)source;
- (void)moveTabView:(NSView*)view fromController:(CTBrowserWindowController*)controller;
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

@interface CTBrowserWindowController(ProtectedMethods)

- (void)detachTabView:(NSView*)view;
- (void)toggleTabStripDisplayMode;
- (void)layoutSubviews;

@end
