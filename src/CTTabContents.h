
@class CTBrowser;
@class CTTabStripModel;

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
@property(strong, nonatomic) CTTabContents* parentOpener;
@property(readonly, nonatomic) BOOL hasIcon;

-(id)initWithBaseTabContents:(CTTabContents*)baseContents;

- (BOOL)becomeFirstResponder;

-(void)closingOfTabDidStart:(CTTabStripModel*)model;

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

