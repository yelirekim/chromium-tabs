
@class CTBrowser;
@class CTTabStripModel2;

extern NSString* const CTTabContentsDidCloseNotification;

@interface CTTabContents : NSDocument

@property(assign, nonatomic) BOOL isApp;
@property(assign, nonatomic) BOOL isLoading;
@property(assign, nonatomic) BOOL isCrashed;
@property(assign, nonatomic) BOOL isWaitingForResponse;
@property(assign, nonatomic) BOOL isVisible;
@property(assign, nonatomic) BOOL isSelected;
@property(assign, nonatomic) BOOL isTeared;
@property(retain, nonatomic) id delegate;
@property(assign, nonatomic) unsigned int closedByUserGesture;
@property(retain, nonatomic) NSView *view;
@property(retain, nonatomic) NSString *title;
@property(retain, nonatomic) NSImage *icon;
@property(strong, nonatomic) CTBrowser *browser;
@property(strong, nonatomic) CTTabContents* parentOpener;
@property(readonly, nonatomic) BOOL hasIcon;

-(id)initWithBaseTabContents:(CTTabContents*)baseContents;

- (void)makeKeyAndOrderFront:(id)sender;
- (BOOL)becomeFirstResponder;

-(void)closingOfTabDidStart:(CTTabStripModel2*)model;
- (void)tabDidInsertIntoBrowser:(CTBrowser*)browser atIndex:(NSInteger)index inForeground:(bool)foreground;
- (void)tabReplaced:(CTTabContents*)oldContents inBrowser:(CTBrowser*)browser atIndex:(NSInteger)index;
- (void)tabWillCloseInBrowser:(CTBrowser*)browser atIndex:(NSInteger)index;
- (void)tabDidDetachFromBrowser:(CTBrowser*)browser atIndex:(NSInteger)index;

-(void)tabDidBecomeVisible;
-(void)tabDidResignVisible;
-(void)tabWillBecomeSelected;
-(void)tabWillResignSelected;
-(void)tabDidBecomeSelected;
-(void)tabDidResignSelected;
-(void)tabWillBecomeTeared;
-(void)tabWillResignTeared;
-(void)tabDidResignTeared;

-(void)viewFrameDidChange:(NSRect)newFrame;

@end

@protocol TabContentsDelegate
-(BOOL)canReloadContents:(CTTabContents*)contents;
-(BOOL)reload;
@end

