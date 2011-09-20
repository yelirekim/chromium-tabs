
@class CTBrowser;
@class CTTabContents;

@protocol CTTabStripModelDelegate
-(CTTabContents*)addBlankTabInForeground:(BOOL)foreground;
-(CTTabContents*)addBlankTabAtIndex:(int)index inForeground:(BOOL)foreground;
-(CTBrowser*)createNewStripWithContents:(CTTabContents*)contents;
-(void)continueDraggingDetachedTab:(CTTabContents*)contents windowBounds:(const NSRect)windowBounds tabBounds:(const NSRect)tabBounds;
-(BOOL)canDuplicateContentsAt:(int)index;
-(void)duplicateContentsAt:(int)index;
-(void)closeFrameAfterDragSession;
-(void)createHistoricalTab:(CTTabContents*)contents;
-(BOOL)runUnloadListenerBeforeClosing:(CTTabContents*)contents;
-(BOOL)canRestoreTab;
-(void)restoreTab;
-(BOOL)canCloseContentsAt:(int)index;
-(BOOL)canCloseTab;

@end
