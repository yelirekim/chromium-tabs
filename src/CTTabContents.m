#import "CTTabContents.h"
#import "CTTabStripModel2.h"
#import "CTBrowser.h"

NSString* const CTTabContentsDidCloseNotification =
    @"CTTabContentsDidCloseNotification";

@implementation CTTabContents {
    BOOL isApp_;
    BOOL isLoading_;
    BOOL isWaitingForResponse_;
    BOOL isCrashed_;
    BOOL isVisible_;
    BOOL isSelected_;
    BOOL isTeared_; // true while being "teared" (dragged between windows)
    id delegate_;
    unsigned int closedByUserGesture_; // TabStripModel::CloseTypes
    NSView *view_; // the actual content
    NSString *title_; // title of this tab
    NSImage *icon_; // tab icon (nil means no or default icon)
    CTBrowser *browser_;
    CTTabContents* parentOpener_; // the tab which opened this tab (unless nil)
}
@synthesize delegate = delegate_;
@synthesize closedByUserGesture = closedByUserGesture_;
@synthesize view = view_;
@synthesize isApp = isApp_;
@synthesize browser = browser_;
@synthesize isLoading = isLoading_;
@synthesize isCrashed = isCrashed_;
@synthesize isWaitingForResponse = isWaitingForResponse_;
@synthesize title = title_;
@synthesize icon = icon_;

#undef _synth


// KVO support
+ (BOOL)automaticallyNotifiesObserversForKey:(NSString*)key {
  if ([key isEqualToString:@"isLoading"] ||
      [key isEqualToString:@"isWaitingForResponse"] ||
      [key isEqualToString:@"isCrashed"] ||
      [key isEqualToString:@"isVisible"] ||
      [key isEqualToString:@"title"] ||
      [key isEqualToString:@"icon"] ||
      [key isEqualToString:@"parentOpener"] ||
      [key isEqualToString:@"isSelected"] ||
      [key isEqualToString:@"isTeared"]) {
    return YES;
  }
  return [super automaticallyNotifiesObserversForKey:key];
}


-(id)initWithBaseTabContents:(CTTabContents*)baseContents {
  // subclasses should probably override this
  self.parentOpener = baseContents;
  return [super init];
}

#pragma mark Properties impl.

-(BOOL)hasIcon {
  return YES;
}


- (CTTabContents*)parentOpener {
  return parentOpener_;
}

- (void)setParentOpener:(CTTabContents*)parentOpener {
  NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
  if (parentOpener_) {
    [nc removeObserver:self
                  name:CTTabContentsDidCloseNotification
                object:parentOpener_];
  }
    [self willChangeValueForKey:@"parentOpener"];
    parentOpener_ = parentOpener; // weak
    [self didChangeValueForKey:@"parentOpener"];
  if (parentOpener_) {
    [nc addObserver:self
           selector:@selector(tabContentsDidClose:)
               name:CTTabContentsDidCloseNotification
             object:parentOpener_];
  }
}

- (void)tabContentsDidClose:(NSNotification*)notification {
  // detach (NULLify) our parentOpener_ when it closes
  CTTabContents* tabContents = [notification object];
  if (tabContents == parentOpener_) {
    parentOpener_ = nil;
  }
}


-(void)setIsVisible:(BOOL)visible {
  if (isVisible_ != visible && !isTeared_) {
    isVisible_ = visible;
    if (isVisible_) {
      [self tabDidBecomeVisible];
    } else {
      [self tabDidResignVisible];
    }
  }
}

-(BOOL)isVisible {
  return isVisible_;
}

-(void)setIsSelected:(BOOL)selected {
  if (isSelected_ != selected && !isTeared_) {
    isSelected_ = selected;
    if (isSelected_) {
      [self tabDidBecomeSelected];
    } else {
      [self tabDidResignSelected];
    }
  }
}

-(BOOL)isSelected {
  return isSelected_;
}

-(void)setIsTeared:(BOOL)teared {
  if (isTeared_ != teared) {
    isTeared_ = teared;
    if (isTeared_) {
      [self tabWillBecomeTeared];
    } else {
      [self tabWillResignTeared];
      [self tabDidBecomeSelected];
    }
  }
}

-(BOOL)isTeared {
  return isTeared_;
}


#pragma mark Actions

- (void)makeKeyAndOrderFront:(id)sender {
  if (browser_) {
    NSWindow *window = browser_.window;
    if (window)
      [window makeKeyAndOrderFront:sender];
    int index = [browser_ indexOfTabContents:self];
    assert(index > -1); // we should exist in browser
    [browser_ selectTabAtIndex:index];
  }
}


- (BOOL)becomeFirstResponder {
  if (isVisible_) {
    return [[view_ window] makeFirstResponder:view_];
  }
  return NO;
}


#pragma mark Callbacks

-(void)closingOfTabDidStart:(CTTabStripModel2*)closeInitiatedByTabStripModel {
  NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
  [nc postNotificationName:CTTabContentsDidCloseNotification object:self];
}

// Called when this tab was inserted into a browser
- (void)tabDidInsertIntoBrowser:(CTBrowser*)browser
                        atIndex:(NSInteger)index
                   inForeground:(bool)foreground {
  self.browser = browser;
}

// Called when this tab replaced another tab
- (void)tabReplaced:(CTTabContents*)oldContents
          inBrowser:(CTBrowser*)browser
            atIndex:(NSInteger)index {
  self.browser = browser;
}

// Called when this tab is about to close
- (void)tabWillCloseInBrowser:(CTBrowser*)browser atIndex:(NSInteger)index {
  self.browser = nil;
}

// Called when this tab was removed from a browser. Will be followed by a
// |tabDidInsertIntoBrowser:atIndex:inForeground:|.
- (void)tabDidDetachFromBrowser:(CTBrowser*)browser atIndex:(NSInteger)index {
  self.browser = nil;
}

-(void)tabWillBecomeSelected {}
-(void)tabWillResignSelected {}

-(void)tabDidBecomeSelected {
  [self becomeFirstResponder];
}

-(void)tabDidResignSelected {}
-(void)tabDidBecomeVisible {}
-(void)tabDidResignVisible {}

-(void)tabWillBecomeTeared {
  // Teared tabs should always be visible and selected since tearing is invoked
  // by the user selecting the tab on screen.
  assert(isVisible_);
  assert(isSelected_);
}

-(void)tabWillResignTeared {
  assert(isVisible_);
  assert(isSelected_);
}

// Unlike the above callbacks, this one is explicitly called by
// CTBrowserWindowController
-(void)tabDidResignTeared {
  [[view_ window] makeFirstResponder:view_];
}

-(void)viewFrameDidChange:(NSRect)newFrame {
  [view_ setFrame:newFrame];
}

- (void) setIsLoading:(BOOL)isLoading
{
    if (isLoading_ != isLoading) {
        isLoading_ = isLoading;
    }
    if (browser_) [browser_ updateTabStateForContent:self];
}

- (void) setIsWaitingForResponse:(BOOL)isWaitingForResponse
{
    if (isWaitingForResponse_ != isWaitingForResponse) {
        isWaitingForResponse_ = isWaitingForResponse;
    }
    if (browser_) [browser_ updateTabStateForContent:self];
}

- (void) setIsCrashed:(BOOL)isCrashed
{
    if (isCrashed_ != isCrashed) {
        isCrashed_ = isCrashed;
    }
    if (browser_) [browser_ updateTabStateForContent:self];
}

- (void) setTitle:(NSString*)title
{
    if (title_ != title) {
        title_ = title;
    }
    if (browser_) [browser_ updateTabStateForContent:self];
}

- (void) setIcon:(NSImage*)icon
{
    if (icon_ != icon) {
        icon_ = icon;
    }
    if (browser_) [browser_ updateTabStateForContent:self];
}

@end
