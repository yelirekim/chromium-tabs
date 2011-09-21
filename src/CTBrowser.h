#import "CTTabStripModelDelegate.h"

typedef enum {
  CTWindowOpenDispositionCurrentTab,
  CTWindowOpenDispositionNewForegroundTab,
  CTWindowOpenDispositionNewBackgroundTab,
} CTWindowOpenDisposition;

@class CTTabStripModel;
@class CTBrowserWindowController;
@class CTTabContentsViewController;
@class CTToolbarController;

// There is one CTBrowser instance per percieved window.
// A CTBrowser instance has one TabStripModel.

@interface CTBrowser : NSObject <CTTabStripModelDelegate> 

@property(retain, readonly, nonatomic) CTTabStripModel* tabStripModel2;
@property(strong, readonly, nonatomic, retain) CTBrowserWindowController* windowController;
@property(strong, readonly, nonatomic) NSWindow* window;

+(CTBrowser*)browser;

-(id)init;

-(CTTabContentsViewController*)createTabContentsControllerWithContents:(CTTabContents*)contents;
-(CTTabContents*)createBlankTabBasedOn:(CTTabContents*)baseContents;
-(CTTabContents*)addBlankTabAtIndex:(int)index inForeground:(BOOL)foreground;
-(CTTabContents*)addBlankTabInForeground:(BOOL)foreground;
-(CTTabContents*)addBlankTab;

-(CTTabContents*)addTabContents:(CTTabContents*)contents atIndex:(int)index inForeground:(BOOL)foreground;
-(CTTabContents*)addTabContents:(CTTabContents*)contents inForeground:(BOOL)foreground;
-(CTTabContents*)addTabContents:(CTTabContents*)contents;

-(void)newWindow;
-(void)closeWindow;
-(void)closeTab;
-(void)selectNextTab;
-(void)selectPreviousTab;
-(void)moveTabNext;
-(void)moveTabPrevious;
-(void)selectTabAtIndex:(int)index;
-(void)selectLastTab;
-(void)duplicateTab;

-(void)executeCommand:(int)cmd withDisposition:(CTWindowOpenDisposition)disposition;
-(void)executeCommand:(int)cmd;

+(void)executeCommand:(int)cmd;

-(void)loadingStateDidChange:(CTTabContents*)contents;
-(void)windowDidBeginToClose;

-(void)updateTabStateForContent:(CTTabContents*)contents;

@end
