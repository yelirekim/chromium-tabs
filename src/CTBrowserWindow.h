
const NSInteger CTWindowButtonsWithTabStripOffsetFromTop = 4;
const NSInteger CTWindowButtonsWithoutTabStripOffsetFromTop = 4;
const NSInteger CTWindowButtonsOffsetFromLeft = 8;
const NSInteger CTWindowButtonsInterButtonSpacing = 7;


@interface CTBrowserWindow : NSWindow

- (void)setShouldHideTitle:(BOOL)flag;
- (BOOL)mouseInGroup:(NSButton*)widget;
- (void)updateTrackingAreas;

@end

@interface NSWindow (UndocumentedAPI)

-(BOOL)_isTitleHidden;

@end
