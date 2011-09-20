#import "CTBrowser.h"
#import "CTTabStripModelDelegate.h"
#import "CTTabWindowController.h"

@class CTTabStripController;

@interface NSDocumentController (CTBrowserWindowControllerAdditions)

- (id)openUntitledDocumentWithWindowController:(NSWindowController*)windowController display:(BOOL)display error:(NSError **)outError;

@end

@interface CTBrowserWindowController : CTTabWindowController

@property(strong, readonly, nonatomic) CTTabStripController *tabStripController;
@property(strong, readonly, nonatomic) CTBrowser *browser;
@property(readonly, nonatomic) BOOL isFullscreen;

+ (CTBrowserWindowController*)mainBrowserWindowController;
+ (CTBrowserWindowController*)browserWindowControllerForWindow:(NSWindow*)window;
+ (CTBrowserWindowController*)browserWindowControllerForView:(NSView*)view;
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

@end
