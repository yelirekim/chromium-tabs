#import "CTBrowser.h"
#import "CTTabStripModel2.h"
#import "CTTabStripController.h"
#import "CTPageTransition.h"
#import "CTBrowserWindowController.h"
#import "CTTabContentsController.h"
#import "CTToolbarController.h"

@implementation CTBrowser
@synthesize windowController = windowController_;
@synthesize tabStripModel2 = tabStripModel2_;


/*- (id)retain {
 self = [super retain];
 NSLog(@"%@  did retain  (retainCount: %u)", self, [self retainCount]);
 NSLog(@"%@", [NSThread callStackSymbols]);
 return self;
 }
 
 - (void)release {
 NSLog(@"%@ will release (retainCount: %u)", self, [self retainCount]);
 NSLog(@"%@", [NSThread callStackSymbols]);
 [super release];
 }*/


+ (CTBrowser*)browser {
    return [[self alloc] init];
}


- (id)init {
    if ((self = [super init])) {
        tabStripModel2_ = [[CTTabStripModel2 alloc] initWithDelegate:self];
    }
    return self;
}

-(CTToolbarController *)createToolbarController {
    // subclasses could override this -- returning nil means no toolbar
    return [[CTToolbarController alloc] initWithBrowser:self];
}

-(CTTabContentsController*)createTabContentsControllerWithContents:
(CTTabContents*)contents {
    // subclasses could override this
    return [[CTTabContentsController alloc]
            initWithContents:contents];
}


#pragma mark -
#pragma mark Accessors

-(NSWindow*)window {
    return [windowController_ window];
}

// TabStripModel convenience helpers

-(int)tabCount {
    return [tabStripModel2_ count];
}

-(int)selectedTabIndex {
    return [tabStripModel2_ selectedIndex];
}

-(CTTabContents*)selectedTabContents {
    return [tabStripModel2_ selectedTabContents];
}

-(CTTabContents*)tabContentsAtIndex:(int)index {
    return [tabStripModel2_ tabContentsAtIndex:index];
}

- (NSArray*)allTabContents {
    NSUInteger i = 0, count = [tabStripModel2_ count];
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:count];
    for (; i<count; ++i) {
        [array insertObject:[tabStripModel2_ tabContentsAtIndex:i] atIndex:i];
    }
    return array;
}

-(int)indexOfTabContents:(CTTabContents*)contents {
    return [tabStripModel2_ indexOfTabContents:contents];
}

-(void)selectTabContentsAtIndex:(int)index userGesture:(BOOL)userGesture {
    [tabStripModel2_ selectTabContentsAtIndex:index userGesture:userGesture];
}

-(void)updateTabStateAtIndex:(int)index {
    [tabStripModel2_ updateTabContentsStateAtIndex:index changeType:CTTabChangeTypeAll];
}

-(void)updateTabStateForContent:(CTTabContents*)contents {
    int index = [tabStripModel2_ indexOfTabContents:contents];
    if (index != -1) {
        [tabStripModel2_ updateTabContentsStateAtIndex:index changeType:CTTabChangeTypeAll];;
    }
}

-(void)replaceTabContentsAtIndex:(int)index withTabContents:(CTTabContents*)contents {
    [tabStripModel2_ replaceTabContentsAtIndex:index withContents:contents replaceType:(CTTabReplaceType)0];
}

-(void)closeTabAtIndex:(int)index makeHistory:(BOOL)makeHistory {
    [tabStripModel2_ closeTabContentsAtIndex:index options:makeHistory ? CLOSE_CREATE_HISTORICAL_TAB : 0];
}

-(void)closeAllTabs {
    [tabStripModel2_ closeAllTabs];
}

#pragma mark -
#pragma mark Callbacks

-(void)loadingStateDidChange:(CTTabContents*)contents {
    // TODO: Make sure the loading state is updated correctly
}

-(void)windowDidBeginToClose {
    [tabStripModel2_ closeAllTabs];
}


#pragma mark -
#pragma mark UI state


/*-(NSRect)savedWindowBounds {
 gfx::Rect restored_bounds = override_bounds_;
 bool maximized;
 WindowSizer::GetBrowserWindowBounds(app_name_, restored_bounds, NULL,
 &restored_bounds, &maximized);
 return restored_bounds;
 }*/


#pragma mark -
#pragma mark Commands

-(void)newWindow {
    // Create a new browser & window when we start
    Class cls = self.windowController ? [self.windowController class] :
    [CTBrowserWindowController class];
    CTBrowser *browser = [isa browser];
    CTBrowserWindowController* windowController =
    [[cls alloc] initWithBrowser:browser];
    [browser addBlankTabInForeground:YES];
    [windowController showWindow:self];
}

-(void)closeWindow {
    [self.windowController close];
}

-(CTTabContents*)addTabContents:(CTTabContents*)contents
                        atIndex:(int)index
                   inForeground:(BOOL)foreground {
    int addTypes = foreground ? (ADD_SELECTED |
                                 ADD_INHERIT_GROUP)
    : ADD_NONE;
    index = [tabStripModel2_ addTabContents:contents atIndex:index withPageTransition:CTPageTransitionTyped options:addTypes];
    if ((addTypes & ADD_SELECTED) == 0) {
        // TabStripModel::AddTabContents invokes HideContents if not foreground.
        contents.isVisible = NO;
    }
    return contents;
}


-(CTTabContents*)addTabContents:(CTTabContents*)contents
                   inForeground:(BOOL)foreground {
    return [self addTabContents:contents atIndex:-1 inForeground:foreground];
}


-(CTTabContents*)addTabContents:(CTTabContents*)contents {
    return [self addTabContents:contents atIndex:-1 inForeground:YES];
}


-(CTTabContents*)createBlankTabBasedOn:(CTTabContents*)baseContents {
    // subclasses should override this to provide a custom CTTabContents type
    // and/or initialization
    return [[CTTabContents alloc]
            initWithBaseTabContents:baseContents];
}

// implementation conforms to CTTabStripModelDelegate
-(CTTabContents*)addBlankTabAtIndex:(int)index inForeground:(BOOL)foreground {
    CTTabContents* baseContents = [tabStripModel2_ selectedTabContents];
    CTTabContents* contents = [self createBlankTabBasedOn:baseContents];
    return [self addTabContents:contents atIndex:index inForeground:foreground];
}

// implementation conforms to CTTabStripModelDelegate
-(CTTabContents*)addBlankTabInForeground:(BOOL)foreground {
    return [self addBlankTabAtIndex:-1 inForeground:foreground];
}

-(CTTabContents*)addBlankTab {
    return [self addBlankTabInForeground:YES];
}

-(void)closeTab {
    if ([self canCloseTab]) {
        [tabStripModel2_ closeTabContentsAtIndex:[tabStripModel2_ selectedIndex] options:CLOSE_USER_GESTURE | CLOSE_CREATE_HISTORICAL_TAB];
    }
}

-(void)selectNextTab {
    [tabStripModel2_ selectNextTab];
}

-(void)selectPreviousTab {
    [tabStripModel2_ selectPreviousTab];
}

-(void)moveTabNext {
    [tabStripModel2_ moveTabNext];
}

-(void)moveTabPrevious {
    [tabStripModel2_ moveTabPrevious];
}

-(void)selectTabAtIndex:(int)index {
    if (index < [tabStripModel2_ count]) {
        [tabStripModel2_ selectTabContentsAtIndex:index userGesture:YES];
    }
}

-(void)selectLastTab {
    [tabStripModel2_ selectLastTab];
}

-(void)duplicateTab {
}


-(void)executeCommand:(int)cmd
      withDisposition:(CTWindowOpenDisposition)disposition {
    //DLOG_EXPR(cmd); //< useful to debug incoming |cmd| values
    // No commands are enabled if there is not yet any selected tab.
    // TODO(pkasting): It seems like we should not need this, because either
    // most/all commands should not have been enabled yet anyway or the ones that
    // are enabled should be global, or safe themselves against having no selected
    // tab.  However, Ben says he tried removing this before and got lots of
    // crashes, e.g. from Windows sending WM_COMMANDs at random times during
    // window construction.  This probably could use closer examination someday.
    if (![self selectedTabContents])
        return;
    
    // If command execution is blocked then just record the command and return.
    /*if (block_command_execution_) {
     // We actually only allow no more than one blocked command, otherwise some
     // commands maybe lost.
     DCHECK_EQ(last_blocked_command_id_, -1);
     last_blocked_command_id_ = id;
     last_blocked_command_disposition_ = disposition;
     return;
     }*/
    
    // The order of commands in this switch statement must match the function
    // declaration order in BrowserCommands.h
    switch (cmd) {
            // Window management commands
        case CTBrowserCommandNewWindow:            [self newWindow]; break;
            //case CTBrowserCommandNewIncognitoWindow: break;
        case CTBrowserCommandCloseWindow:          [self closeWindow]; break;
            //case CTBrowserCommandAlwaysOnTop: break;
        case CTBrowserCommandNewTab:               [self addBlankTab]; break;
        case CTBrowserCommandCloseTab:             [self closeTab]; break;
        case CTBrowserCommandSelectNextTab:       [self selectNextTab]; break;
        case CTBrowserCommandSelectPreviousTab:   [self selectPreviousTab]; break;
        case CTBrowserCommandSelectTab0:
        case CTBrowserCommandSelectTab1:
        case CTBrowserCommandSelectTab2:
        case CTBrowserCommandSelectTab3:
        case CTBrowserCommandSelectTab4:
        case CTBrowserCommandSelectTab5:
        case CTBrowserCommandSelectTab6:
        case CTBrowserCommandSelectTab7: {
            [self selectTabAtIndex:cmd - CTBrowserCommandSelectTab0];
            break;
        }
        case CTBrowserCommandSelectLastTab:    [self selectLastTab]; break;
        case CTBrowserCommandDuplicateTab:     [self duplicateTab]; break;
            //case CTBrowserCommandRestoreTab:     break;
            //case CTBrowserCommandShowAsTab:      break;
            //case CTBrowserCommandFullscreen:     DLOG("TODO ToggleFullscreenMode();"); break;
        case CTBrowserCommandExit:             [NSApp terminate:self]; break;
        case CTBrowserCommandMoveTabNext:      [self moveTabNext]; break;
        case CTBrowserCommandMoveTabPrevious:  [self moveTabPrevious]; break;
    }
}

-(void)executeCommand:(int)cmd {
    [self executeCommand:cmd withDisposition:CTWindowOpenDispositionCurrentTab];
}

+(void)executeCommand:(int)cmd {
    switch (cmd) {
        case CTBrowserCommandExit:      [NSApp terminate:self]; break;
    }
}


#pragma mark -
#pragma mark CTTabStripModelDelegate protocol implementation


-(CTBrowser*)createNewStripWithContents:(CTTabContents*)contents {
    //assert(CanSupportWindowFeature(FEATURE_TABSTRIP));
    
    //gfx::Rect new_window_bounds = window_bounds;
    //if (dock_info.GetNewWindowBounds(&new_window_bounds, &maximize))
    //  dock_info.AdjustOtherWindowBounds();
    
    // Create an empty new browser window the same size as the old one.
    CTBrowser* browser = [isa browser];
    [browser.tabStripModel2 appendTabContents:contents foreground:YES];
    [browser loadingStateDidChange:contents];
    
    return browser;
}

// Creates a new CTBrowser object and window containing the specified
// |contents|, and continues a drag operation that began within the source
// window's tab strip. |window_bounds| are the bounds of the source window in
// screen coordinates, used to place the new window, and |tab_bounds| are the
// bounds of the dragged Tab view in the source window, in screen coordinates,
// used to place the new Tab in the new window.
-(void)continueDraggingDetachedTab:(CTTabContents*)contents
                      windowBounds:(const NSRect)windowBounds
                         tabBounds:(const NSRect)tabBounds {
    [self doesNotRecognizeSelector:_cmd];
}


// Returns whether some contents can be duplicated.
-(BOOL)canDuplicateContentsAt:(int)index {
    return NO;
}

// Duplicates the contents at the provided index and places it into its own
// window.
-(void)duplicateContentsAt:(int)index {
    [self doesNotRecognizeSelector:_cmd];
}

// Called when a drag session has completed and the frame that initiated the
// the session should be closed.
-(void)closeFrameAfterDragSession {
    
}

// Creates an entry in the historical tab database for the specified
// CTTabContents.
-(void)createHistoricalTab:(CTTabContents*)contents {
    
}

// Runs any unload listeners associated with the specified CTTabContents before
// it is closed. If there are unload listeners that need to be run, this
// function returns true and the TabStripModel will wait before closing the
// CTTabContents. If it returns false, there are no unload listeners and the
// TabStripModel can close the CTTabContents immediately.
-(BOOL)runUnloadListenerBeforeClosing:(CTTabContents*)contents {
    return NO;
}

// Returns true if a tab can be restored.
-(BOOL)canRestoreTab {
    return NO;
}

// Restores the last closed tab if CanRestoreTab would return true.
-(void)restoreTab {
}

// Returns whether some contents can be closed.
-(BOOL)canCloseContentsAt:(int)index {
    return YES;
}

// Returns true if any of the tabs can be closed.
-(BOOL)canCloseTab {
    return YES;
}

- (void) setWindowController:(CTBrowserWindowController *)windowController
{
    if (windowController_ != windowController) {
        windowController_ = windowController;
    }
}

@end
