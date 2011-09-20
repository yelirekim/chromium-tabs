// Copyright (c) 2010 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE-chromium file.

#import "CTTabStripController.h"

#import <QuartzCore/QuartzCore.h>
#import "CTTabContents.h"
#import "CTBrowser.h"
#import "CTUtil.h"
#import "NSImage+CTAdditions.h"

#import <limits>
#import <string>

#import "NewTabButton.h"
#import "CTTabStripView.h"
#import "CTTabContentsController.h"
#import "CTTabController.h"
#import "CTTabStripModelObserverBridge.h"
#import "CTTabView.h"
#import "ThrobberView.h"
#import "CTTabStripModel.h"
#import "GTMNSAnimation+Duration.h"

NSString* const kTabStripNumberOfTabsChanged = @"kTabStripNumberOfTabsChanged";

static NSImage* kNewTabHoverImage = nil;
static NSImage* kNewTabImage = nil;
static NSImage* kNewTabPressedImage = nil;
static NSImage* kDefaultIconImage = nil;
const CGFloat kUseFullAvailableWidth = -1.0;
const CGFloat kTabOverlap = 20.0;
const CGFloat kIconWidthAndHeight = 16.0;
const CGFloat kNewTabButtonOffset = 8.0;
const CGFloat kIncognitoBadgeTabStripShrink = 18;
const NSTimeInterval kAnimationDuration = 0.125;

class ScopedNSAnimationContextGroup {
public:
    explicit ScopedNSAnimationContextGroup(bool animate)
    : animate_(animate) {
        if (animate_) {
            [NSAnimationContext beginGrouping];
        }
    }
    
    ~ScopedNSAnimationContextGroup() {
        if (animate_) {
            [NSAnimationContext endGrouping];
        }
    }
    
    void SetCurrentContextDuration(NSTimeInterval duration) {
        if (animate_) {
            [[NSAnimationContext currentContext] gtm_setDuration:duration
                                                       eventMask:NSLeftMouseUpMask];
        }
    }
    
    void SetCurrentContextShortestDuration() {
        if (animate_) {
            // The minimum representable time interval.  This used to stop an
            // in-progress animation as quickly as possible.
            const NSTimeInterval kMinimumTimeInterval =
            std::numeric_limits<NSTimeInterval>::min();
            // Directly set the duration to be short, avoiding the Steve slowmotion
            // ettect the gtm_setDuration: provides.
            [[NSAnimationContext currentContext] setDuration:kMinimumTimeInterval];
        }
    }
    
private:
    bool animate_;
    DISALLOW_COPY_AND_ASSIGN(ScopedNSAnimationContextGroup);
};

@interface CTTabStripController (Private)
- (void)installTrackingArea;
- (void)addSubviewToPermanentList:(NSView*)aView;
- (void)regenerateSubviewList;
- (NSInteger)indexForContentsView:(NSView*)view;
- (void)updateFavIconForContents:(CTTabContents*)contents atIndex:(NSInteger)modelIndex;
- (void)layoutTabsWithAnimation:(BOOL)animate regenerateSubviews:(BOOL)doUpdate;
- (void)animationDidStopForController:(CTTabController*)controller finished:(BOOL)finished;
- (NSInteger)indexFromModelIndex:(NSInteger)index;
- (NSInteger)numberOfOpenTabs;
- (NSInteger)numberOfOpenMiniTabs;
- (NSInteger)numberOfOpenNonMiniTabs;
- (void)mouseMoved:(NSEvent*)event;
- (void)setTabTrackingAreasEnabled:(BOOL)enabled;
- (void)setNewTabButtonHoverState:(BOOL)showHover;
- (CTTabController*)newTab;
- (void)setTabTitle:(NSViewController*)tab withContents:(CTTabContents*)contents;
- (void)swapInTabAtIndex:(NSInteger)modelIndex;
- (void)startClosingTabWithAnimation:(CTTabController*)closingTab;
- (void)removeTab:(CTTabController*)controller;
@end


@interface TabStripControllerDragBlockingView : NSView {
    CTTabStripController* controller_;  // weak; owns us
}

- (id)initWithFrame:(NSRect)frameRect
         controller:(CTTabStripController*)controller;
@end

@implementation TabStripControllerDragBlockingView
- (BOOL)mouseDownCanMoveWindow {return NO;}
- (void)drawRect:(NSRect)rect {}

- (id)initWithFrame:(NSRect)frameRect
         controller:(CTTabStripController*)controller {
    if ((self = [super initWithFrame:frameRect]))
        controller_ = controller;
    return self;
}

- (void)mouseDown:(NSEvent*)event {
    if ([controller_ inRapidClosureMode]) {
        NSView* superview = [self superview];
        NSPoint hitLocation =
        [[superview superview] convertPoint:[event locationInWindow]
                                   fromView:nil];
        NSView* hitView = [superview hitTest:hitLocation];
        if (hitView != self) {
            [hitView mouseDown:event];
            return;
        }
    }
    [super mouseDown:event];
}
@end

#pragma mark -

@interface TabCloseAnimationDelegate : NSObject {
@private
    CTTabStripController* strip_;  // weak; owns us indirectly
    CTTabController* controller_;  // weak
}

- (id)initWithTabStrip:(CTTabStripController*)strip tabController:(CTTabController*)controller;

- (void)invalidate;
- (void)animationDidStop:(CAAnimation*)animation finished:(BOOL)finished;

@end

@implementation TabCloseAnimationDelegate

- (id)initWithTabStrip:(CTTabStripController*)strip tabController:(CTTabController*)controller {
    if (nil != (self = [super init])) {
        assert(strip && controller);
        strip_ = strip;
        controller_ = controller;
    }
    return self;
}

- (void)invalidate {
    strip_ = nil;
    controller_ = nil;
}

- (void)animationDidStop:(CAAnimation*)animation finished:(BOOL)finished {
    [strip_ animationDidStopForController:controller_ finished:finished];
}

@end

#pragma mark -


@implementation CTTabStripController {
    BOOL verticalLayout_;
    CTTabContents* currentTab_;  // weak, tab for which we're showing state
    CTTabStripView* tabStripView_;
    NSView* switchView_;  // weak
    NSView* dragBlockingView_;  // avoid bad window server drags
    NewTabButton* newTabButton_;  // weak, obtained from the nib.
    NSTrackingArea* newTabTrackingArea_;
    CTTabStripModelObserverBridge* bridge_;
    CTBrowser *browser_;  // weak
    CTTabStripModel* tabStripModel_;  // weak
    CTTabStripModel2* tabStripModel2_;
    BOOL newTabButtonShowingHoverImage_;
    NSMutableArray* tabContentsArray_;
    NSMutableArray* tabArray_;
    NSMutableSet* closingControllers_;
    CTTabView* placeholderTab_;  // weak. Tab being dragged
    NSRect placeholderFrame_;  // Frame to use
    CGFloat placeholderStretchiness_; // Vertical force shown by streching tab.
    NSRect droppedTabFrame_;
    NSMutableDictionary* targetFrames_;
    NSRect newTabTargetFrame_;
    BOOL forceNewTabButtonHidden_;
    BOOL initialLayoutComplete_;
    float availableResizeWidth_;
    NSTrackingArea* trackingArea_;
    CTTabView* hoveredTab_;  // weak. Tab that the mouse is hovering over
    NSMutableArray* permanentSubviews_;
    NSImage* defaultFavIcon_;
    CGFloat indentForControls_;
    BOOL mouseInside_;
    
    id ob1;
    id ob2;
    id ob3;
    id ob4;
    id ob5;
    id ob6;
}

@synthesize indentForControls = indentForControls_;

+ (void)initialize {
    kNewTabHoverImage = [NSImage imageInAppOrCTFrameworkNamed:@"newtab_h"];
    kNewTabImage = [NSImage imageInAppOrCTFrameworkNamed:@"newtab"];
    kNewTabPressedImage = [NSImage imageInAppOrCTFrameworkNamed:@"newtab_p"];
    kDefaultIconImage = [NSImage imageInAppOrCTFrameworkNamed:@"default-icon"];
}

- (id)initWithView:(CTTabStripView*)view switchView:(NSView*)switchView browser:(CTBrowser*)browser {
    assert(view && switchView && browser);
    if ((self = [super init])) {
        tabStripView_ = view;
        switchView_ = switchView;
        browser_ = browser;
        tabStripModel_ = [browser_ tabStripModel];
        tabStripModel2_ = [browser_ tabStripModel2];
        bridge_ = new CTTabStripModelObserverBridge(tabStripModel_, self);
        
        tabContentsArray_ = [[NSMutableArray alloc] init];
        tabArray_ = [[NSMutableArray alloc] init];
        
        permanentSubviews_ = [[NSMutableArray alloc] init];
        
        defaultFavIcon_ = kDefaultIconImage;
        
        [self setIndentForControls:[[self class] defaultIndentForControls]];
        
        newTabButton_ = [view addTabButton];
        [self addSubviewToPermanentList:newTabButton_];
        [newTabButton_ setTarget:nil];
        [newTabButton_ setAction:@selector(commandDispatch:)];
        [newTabButton_ setTag:CTBrowserCommandNewTab];
        [newTabButton_ setImage:kNewTabImage];
        [newTabButton_ setAlternateImage:kNewTabPressedImage];
        newTabButtonShowingHoverImage_ = NO;
        newTabTrackingArea_ = 
        [[NSTrackingArea alloc] initWithRect:[newTabButton_ bounds]
                                     options:(NSTrackingMouseEnteredAndExited |
                                              NSTrackingActiveAlways)
                                       owner:self
                                    userInfo:nil];
        [newTabButton_ addTrackingArea:newTabTrackingArea_];
        targetFrames_ = [[NSMutableDictionary alloc] init];
        
        dragBlockingView_ = 
        [[TabStripControllerDragBlockingView alloc] initWithFrame:NSZeroRect
                                                       controller:self];
        [self addSubviewToPermanentList:dragBlockingView_];
        
        newTabTargetFrame_ = NSMakeRect(0, 0, 0, 0);
        availableResizeWidth_ = kUseFullAvailableWidth;
        
        closingControllers_ = [[NSMutableSet alloc] init];
        
        [self regenerateSubviewList];
        
        [[NSNotificationCenter defaultCenter]
         addObserver:self
         selector:@selector(tabViewFrameChanged:)
         name:NSViewFrameDidChangeNotification
         object:tabStripView_];
        
        trackingArea_ = [[NSTrackingArea alloc]
                         initWithRect:NSZeroRect  // Ignored by NSTrackingInVisibleRect
                         options:NSTrackingMouseEnteredAndExited |
                         NSTrackingMouseMoved |
                         NSTrackingActiveAlways |
                         NSTrackingInVisibleRect
                         owner:self
                         userInfo:nil];
        [tabStripView_ addTrackingArea:trackingArea_];
        
        NSPoint mouseLoc = [[view window] mouseLocationOutsideOfEventStream];
        mouseLoc = [view convertPoint:mouseLoc fromView:nil];
        if (NSPointInRect(mouseLoc, [view bounds])) {
            [self setTabTrackingAreasEnabled:YES];
            mouseInside_ = YES;
        }
        
        [[newTabButton_ cell]
         accessibilitySetOverrideValue:@"New tab"
         forAttribute:NSAccessibilityDescriptionAttribute];
#if 0        
        const int existingTabCount = [tabStripModel2_ count];
        const CTTabContents* selection = [tabStripModel2_ selectedTabContents];
        for (int i = 0; i < existingTabCount; ++i) {
            CTTabContents* currentContents = [tabStripModel2_ tabContentsAtIndex:i];
            [self tabInsertedWithContents:currentContents
                                  atIndex:i
                             inForeground:NO];
            if (selection == currentContents) {
                [self tabSelectedWithContents:currentContents
                             previousContents:NULL
                                      atIndex:i
                                  userGesture:NO];
            }
        }
        if (existingTabCount) {
            [self performSelectorOnMainThread:@selector(layoutTabs)
                                   withObject:nil
                                waitUntilDone:NO];
        }
#endif
        
        ob1 = [[NSNotificationCenter defaultCenter] addObserverForName:kCTTabInsertedNotification object:tabStripModel2_ queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification* notification) {
            NSDictionary* userInfo = notification.userInfo;
            CTTabContents* contents = [userInfo objectForKey:kCTTabContentsUserInfoKey];
            NSInteger modelIndex = [[userInfo valueForKey:kCTTabIndexUserInfoKey] intValue];
            BOOL inForeground = [[userInfo objectForKey:kCTTabForegroundUserInfoKey] boolValue];
            assert(contents);
            assert(modelIndex == CTTabStripModel::kNoTab || [tabStripModel2_ containsIndex:modelIndex]);
            
            NSInteger index = [self indexFromModelIndex:modelIndex];
            
            CTTabContentsController* contentsController =
            [browser_ createTabContentsControllerWithContents:contents];
            [tabContentsArray_ insertObject:contentsController atIndex:index];
            
            CTTabController* newController = [self newTab];
            [newController setMini:[tabStripModel2_ isMiniTabAtIndex:modelIndex]];
            [newController setPinned:[tabStripModel2_ isTabPinnedAtIndex:modelIndex]];
            [newController setApp:[tabStripModel2_ isAppTabAtIndex:modelIndex]];
            [tabArray_ insertObject:newController atIndex:index];
            NSView* newView = [newController view];
            
            [newView setFrame:NSOffsetRect([newView frame],
                                           0, -[[self class] defaultTabHeight])];
            
            [self setTabTitle:newController withContents:contents];
            
            availableResizeWidth_ = kUseFullAvailableWidth;
            
            if (!inForeground) {
                [self layoutTabs];
            }
            
            [self updateFavIconForContents:contents atIndex:modelIndex];
            
            [[NSNotificationCenter defaultCenter]
             postNotificationName:kTabStripNumberOfTabsChanged
             object:self];
        }];
        
        ob2 = [[NSNotificationCenter defaultCenter] addObserverForName:kCTTabSelectedNotification object:tabStripModel2_ queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification* notification) {
            NSDictionary* userInfo = notification.userInfo;
            CTTabContents* oldContents = [userInfo objectForKey:kCTTabContentsUserInfoKey];
            CTTabContents* newContents = [userInfo objectForKey:kCTTabNewContentsUserInfoKey];
            NSInteger modelIndex = [[userInfo valueForKey:kCTTabIndexUserInfoKey] intValue];
            
            NSInteger index = [self indexFromModelIndex:modelIndex];
            
            if (oldContents) {
                int oldModelIndex = [tabStripModel2_ indexOfTabContents:oldContents];
                if (oldModelIndex != -1) {  // When closing a tab, the old tab may be gone.
                    NSInteger oldIndex = [self indexFromModelIndex:oldModelIndex];
                    CTTabContentsController* oldController = [tabContentsArray_ objectAtIndex:oldIndex];
                    [oldController willResignSelectedTab];
                }
            }
            
            int i = 0;
            for (CTTabController* current in tabArray_) {
                [current setSelected:(i == index) ? YES : NO];
                ++i;
            }
            
            CTTabContentsController *newController =
            [tabContentsArray_ objectAtIndex:index];
            [newController willBecomeSelectedTab];
            
            [self layoutTabs];
            
            [self swapInTabAtIndex:modelIndex];
            
            if (newContents) {
                newContents.isVisible = oldContents.isVisible;
                newContents.isSelected = YES;
            }
            if (oldContents) {
                oldContents.isVisible = NO;
                oldContents.isSelected = NO;
            }
        }];
        
        ob3 = [[NSNotificationCenter defaultCenter] addObserverForName:kCTTabMovedNotification object:tabStripModel2_ queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification* notification) {
            NSDictionary* userInfo = notification.userInfo;
            CTTabContents* contents = [userInfo objectForKey:kCTTabContentsUserInfoKey];
            NSInteger modelFrom = [[userInfo valueForKey:kCTTabIndexUserInfoKey] intValue];
            NSInteger modelTo = [[userInfo valueForKey:kCTTabToIndexUserInfoKey] intValue];
            NSInteger from = [self indexFromModelIndex:modelFrom];
            NSInteger to = [self indexFromModelIndex:modelTo];
            
            CTTabContentsController* movedTabContentsController = [tabContentsArray_ objectAtIndex:from];
            [tabContentsArray_ removeObjectAtIndex:from];
            [tabContentsArray_ insertObject:movedTabContentsController atIndex:to];
            CTTabController* movedTabController = [tabArray_ objectAtIndex:from];
            assert([movedTabController isKindOfClass:[CTTabController class]]);
            [tabArray_ removeObjectAtIndex:from];
            [tabArray_ insertObject:movedTabController atIndex:to];
            
            if ([tabStripModel2_ isMiniTabAtIndex:modelTo] != [movedTabController mini]) {
                [self tabMiniStateChangedWithContents:contents atIndex:modelTo];
            }
        }];
        
        ob4 = [[NSNotificationCenter defaultCenter] addObserverForName:kCTTabChangedNotification object:tabStripModel2_ queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification* notification) {
            NSDictionary* userInfo = notification.userInfo;
            CTTabContents* contents = [userInfo objectForKey:kCTTabContentsUserInfoKey];
            NSInteger modelIndex = [[userInfo valueForKey:kCTTabIndexUserInfoKey] intValue];
            CTTabChangeType change = (CTTabChangeType)[[userInfo valueForKey:kCTTabOptionsUserInfoKey] intValue];
            NSInteger index = [self indexFromModelIndex:modelIndex];
            
            if (change == CTTabChangeTypeTitleNotLoading) {
                return;
            }
            
            CTTabController* tabController = [tabArray_ objectAtIndex:index];
            
            if (change != CTTabChangeTypeLoadingOnly) {
                [self setTabTitle:tabController withContents:contents];
            }
            
            bool isPhantom = [tabStripModel2_ isPhantomTabAtIndex:modelIndex];
            if (isPhantom != [tabController phantom]) {
                [tabController setPhantom:isPhantom];
            }
            
            [self updateFavIconForContents:contents atIndex:modelIndex];
            
            CTTabContentsController* updatedController = [tabContentsArray_ objectAtIndex:index];
            [updatedController tabDidChange:contents];
        }];
        
        ob5 = [[NSNotificationCenter defaultCenter] addObserverForName:kCTTabChangedNotification object:tabStripModel2_ queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification* notification) {
            NSDictionary* userInfo = notification.userInfo;
            CTTabContents* contents = [userInfo objectForKey:kCTTabContentsUserInfoKey];
            NSInteger modelIndex = [[userInfo valueForKey:kCTTabIndexUserInfoKey] intValue];
            NSInteger index = [self indexFromModelIndex:modelIndex];
            
            CTTabController* tabController = [tabArray_ objectAtIndex:index];
            assert([tabController isKindOfClass:[CTTabController class]]);
            [tabController setMini:[tabStripModel2_ isMiniTabAtIndex:modelIndex]];
            [tabController setPinned:[tabStripModel2_ isTabPinnedAtIndex:modelIndex]];
            [tabController setApp:[tabStripModel2_ isAppTabAtIndex:modelIndex]];
            [self updateFavIconForContents:contents atIndex:modelIndex];
            [self layoutTabs];
        }];
        
        ob6 = [[NSNotificationCenter defaultCenter] addObserverForName:kCTTabDetachedNotification object:tabStripModel2_ queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification* notification) {
            NSDictionary* userInfo = notification.userInfo;
            NSInteger modelIndex = [[userInfo valueForKey:kCTTabIndexUserInfoKey] intValue];
            NSInteger index = [self indexFromModelIndex:modelIndex];
            
            CTTabController* tab = [tabArray_ objectAtIndex:index];
            if ([tabStripModel2_ count] > 0) {
                [self startClosingTabWithAnimation:tab];
                [self layoutTabs];
            } else {
                [self removeTab:tab];
            }
            
            [[NSNotificationCenter defaultCenter] postNotificationName:kTabStripNumberOfTabsChanged object:self];
        }];
    }
    return self;
}

- (void)dealloc {
    if (trackingArea_)
        [tabStripView_ removeTrackingArea:trackingArea_];
    
    [newTabButton_ removeTrackingArea:newTabTrackingArea_];
    for (CTTabController* controller in closingControllers_) {
        NSView* view = [controller view];
        [[[view animationForKey:@"frameOrigin"] delegate] invalidate];
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:ob1];
    [[NSNotificationCenter defaultCenter] removeObserver:ob2];
    [[NSNotificationCenter defaultCenter] removeObserver:ob3];
    [[NSNotificationCenter defaultCenter] removeObserver:ob4];
    [[NSNotificationCenter defaultCenter] removeObserver:ob5];
    [[NSNotificationCenter defaultCenter] removeObserver:ob6];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

+ (CGFloat)defaultTabHeight {
    return 25.0;
}

+ (CGFloat)defaultIndentForControls {
    return 64.0;
}

- (void)swapInTabAtIndex:(NSInteger)modelIndex {
    assert(modelIndex >= 0 && modelIndex < [tabStripModel2_ count]);
    NSInteger index = [self indexFromModelIndex:modelIndex];
    CTTabContentsController* controller = [tabContentsArray_ objectAtIndex:index];
    
    NSView* newView = [controller view];
    NSRect frame = [switchView_ bounds];
    [newView setFrame:frame];
    [controller ensureContentsVisible];
    
    NSArray* subviews = [switchView_ subviews];
    if ([subviews count]) {
        NSView* oldView = [subviews objectAtIndex:0];
        [switchView_ replaceSubview:oldView with:newView];
    } else {
        [switchView_ addSubview:newView];
    }
}

- (CTTabController*)newTab {
    CTTabController* controller = [[CTTabController alloc] init];
    [controller setTarget:self];
    [controller setAction:@selector(selectTab:)];
    [[controller view] setHidden:YES];
    
    return controller;
}

- (NSInteger)numberOfOpenTabs {
    return static_cast<NSInteger>([tabStripModel2_ count]);
}

- (NSInteger)numberOfOpenMiniTabs {
    return [tabStripModel2_ indexOfFirstNonMiniTab];
}

- (NSInteger)numberOfOpenNonMiniTabs {
    NSInteger number = [self numberOfOpenTabs] - [self numberOfOpenMiniTabs];
    DCHECK_GE(number, 0);
    return number;
}

- (NSInteger)indexFromModelIndex:(NSInteger)index {
    assert(index >= 0);
    if (index < 0)
        return index;
    
    NSInteger i = 0;
    for (CTTabController* controller in tabArray_) {
        if ([closingControllers_ containsObject:controller]) {
            assert([(CTTabView*)[controller view] isClosing]);
            ++index;
        }
        if (i == index)  // No need to check anything after, it has no effect.
            break;
        ++i;
    }
    return index;
}

- (NSInteger)modelIndexForTabView:(NSView*)view {
    NSInteger index = 0;
    for (CTTabController* current in tabArray_) {
        if ([closingControllers_ containsObject:current])
            continue;
        else if ([current view] == view)
            return index;
        ++index;
    }
    return -1;
}

- (NSInteger)modelIndexForContentsView:(NSView*)view {
    NSInteger index = 0;
    NSInteger i = 0;
    for (CTTabContentsController* current in tabContentsArray_) {
        // If the CTTabController corresponding to |current| is closing, skip it.
        CTTabController* controller = [tabArray_ objectAtIndex:i];
        if ([closingControllers_ containsObject:controller]) {
            ++i;
            continue;
        } else if ([current view] == view) {
            return index;
        }
        ++index;
        ++i;
    }
    return -1;
}

- (NSView*)viewAtIndex:(NSUInteger)index {
    if (index >= [tabArray_ count])
        return NULL;
    return [[tabArray_ objectAtIndex:index] view];
}

- (NSUInteger)viewsCount {
    return [tabArray_ count];
}

- (void)selectTab:(id)sender {
    assert([sender isKindOfClass:[NSView class]]);
    int index = [self modelIndexForTabView:sender];
    if ([tabStripModel2_ containsIndex:index]) {
        [tabStripModel2_ selectTabContentsAtIndex:index userGesture:YES];
    }
}

- (void)closeTab:(id)sender {
    assert([sender isKindOfClass:[CTTabView class]]);
    if ([hoveredTab_ isEqual:sender]) {
        hoveredTab_ = nil;
    }
    
    NSInteger index = [self modelIndexForTabView:sender];
    if (![tabStripModel2_ containsIndex:index])
        return;
    
    const NSInteger numberOfOpenTabs = [self numberOfOpenTabs];
    if (numberOfOpenTabs > 1) {
        bool isClosingLastTab = index == numberOfOpenTabs - 1;
        if (!isClosingLastTab) {
            NSView* penultimateTab = [self viewAtIndex:numberOfOpenTabs - 2];
            availableResizeWidth_ = NSMaxX([penultimateTab frame]);
        } else {
            NSView* lastTab = [self viewAtIndex:numberOfOpenTabs - 1];
            availableResizeWidth_ = NSMaxX([lastTab frame]);
        }
        [tabStripModel2_ closeTabContentsAtIndex:index options: CLOSE_USER_GESTURE | CLOSE_CREATE_HISTORICAL_TAB];
    } else {
        [[tabStripView_ window] performClose:nil];
    }
}

- (void)insertPlaceholderForTab:(CTTabView*)tab
                          frame:(NSRect)frame
                  yStretchiness:(CGFloat)yStretchiness {
    placeholderTab_ = tab;
    placeholderFrame_ = frame;
    placeholderStretchiness_ = yStretchiness;
    [self layoutTabsWithAnimation:initialLayoutComplete_ regenerateSubviews:NO];
}

- (BOOL)isTabFullyVisible:(CTTabView*)tab {
    NSRect frame = [tab frame];
    return NSMinX(frame) >= [self indentForControls] &&
    NSMaxX(frame) <= NSMaxX([tabStripView_ frame]);
}


- (void)setShowsNewTabButton:(BOOL)show {
    if (!!forceNewTabButtonHidden_ == !!show) {
        forceNewTabButtonHidden_ = !show;
        [newTabButton_ setHidden:forceNewTabButtonHidden_];
    }
}


- (BOOL)showsNewTabButton {
    return !forceNewTabButtonHidden_ && newTabButton_;
}

- (void)layoutTabsWithAnimation:(BOOL)animate
             regenerateSubviews:(BOOL)doUpdate {
    assert([NSThread isMainThread]);
    if (![tabArray_ count])
        return;
    
    const CGFloat kMaxTabWidth = [CTTabController maxTabWidth];
    const CGFloat kMinTabWidth = [CTTabController minTabWidth];
    const CGFloat kMinSelectedTabWidth = [CTTabController minSelectedTabWidth];
    const CGFloat kMiniTabWidth = [CTTabController miniTabWidth];
    const CGFloat kAppTabWidth = [CTTabController appTabWidth];
    
    NSRect enclosingRect = NSZeroRect;
    ScopedNSAnimationContextGroup mainAnimationGroup(animate);
    mainAnimationGroup.SetCurrentContextDuration(kAnimationDuration);
    
    if (doUpdate)
        [self regenerateSubviewList];
    
    CGFloat availableSpace = 0;
    if (verticalLayout_) {
        availableSpace = NSHeight([tabStripView_ bounds]);
    } else {
        if ([self inRapidClosureMode]) {
            availableSpace = availableResizeWidth_;
        } else {
            availableSpace = NSWidth([tabStripView_ frame]);
            if (forceNewTabButtonHidden_) {
                availableSpace -= 5.0; // margin
            } else {
                availableSpace -= NSWidth([newTabButton_ frame]) + kNewTabButtonOffset;
            }
        }
        availableSpace -= [self indentForControls];
    }
    
    CGFloat availableSpaceForNonMini = availableSpace;
    if (!verticalLayout_) {
        availableSpaceForNonMini -=
        [self numberOfOpenMiniTabs] * (kMiniTabWidth - kTabOverlap);
    }
    
    CGFloat nonMiniTabWidth = kMaxTabWidth;
    const NSInteger numberOfOpenNonMiniTabs = [self numberOfOpenNonMiniTabs];
    if (!verticalLayout_ && numberOfOpenNonMiniTabs) {
        availableSpaceForNonMini += (numberOfOpenNonMiniTabs - 1) * kTabOverlap;
        nonMiniTabWidth = availableSpaceForNonMini / numberOfOpenNonMiniTabs;
        nonMiniTabWidth = MAX(MIN(nonMiniTabWidth, kMaxTabWidth), kMinTabWidth);
    }
    
    BOOL visible = [[tabStripView_ window] isVisible];
    
    CGFloat offset = [self indentForControls];
    NSUInteger i = 0;
    bool hasPlaceholderGap = false;
    for (CTTabController* tab in tabArray_) {
        if ([closingControllers_ containsObject:tab])
            continue;
        
        BOOL isPlaceholder = [[tab view] isEqual:placeholderTab_];
        NSRect tabFrame = [[tab view] frame];
        tabFrame.size.height = [[self class] defaultTabHeight] + 1;
        if (verticalLayout_) {
            tabFrame.origin.y = availableSpace - tabFrame.size.height - offset;
            tabFrame.origin.x = 0;
        } else {
            tabFrame.origin.y = 0;
            tabFrame.origin.x = offset;
        }
        BOOL newTab = [[tab view] isHidden];
        if (newTab) {
            [[tab view] setHidden:NO];
        }
        
        if (isPlaceholder) {
            ScopedNSAnimationContextGroup localAnimationGroup(animate);
            localAnimationGroup.SetCurrentContextShortestDuration();
            if (verticalLayout_)
                tabFrame.origin.y = availableSpace - tabFrame.size.height - offset;
            else
                tabFrame.origin.x = placeholderFrame_.origin.x;
            id target = animate ? [[tab view] animator] : [tab view];
            [target setFrame:tabFrame];
            
            NSValue* identifier = [NSValue valueWithPointer:(__bridge const void*)[tab view]];
            [targetFrames_ setObject:[NSValue valueWithRect:tabFrame]
                              forKey:identifier];
            continue;
        }
        
        if (placeholderTab_ && !hasPlaceholderGap) {
            const CGFloat placeholderMin =
            verticalLayout_ ? NSMinY(placeholderFrame_) :
            NSMinX(placeholderFrame_);
            if (verticalLayout_) {
                if (NSMidY(tabFrame) > placeholderMin) {
                    hasPlaceholderGap = true;
                    offset += NSHeight(placeholderFrame_);
                    tabFrame.origin.y = availableSpace - tabFrame.size.height - offset;
                }
            } else {
                if (NSMidX(tabFrame) > placeholderMin) {
                    hasPlaceholderGap = true;
                    offset += NSWidth(placeholderFrame_);
                    offset -= kTabOverlap;
                    tabFrame.origin.x = offset;
                }
            }
        }
        
        tabFrame.size.width = [tab mini] ?
        ([tab app] ? kAppTabWidth : kMiniTabWidth) : nonMiniTabWidth;
        if ([tab selected])
            tabFrame.size.width = MAX(tabFrame.size.width, kMinSelectedTabWidth);
        
        if (newTab && visible && animate) {
            if (NSEqualRects(droppedTabFrame_, NSZeroRect)) {
                [[tab view] setFrame:NSOffsetRect(tabFrame, 0, -NSHeight(tabFrame))];
            } else {
                [[tab view] setFrame:droppedTabFrame_];
                droppedTabFrame_ = NSZeroRect;
            }
        }
        
        id frameTarget = visible && animate ? [[tab view] animator] : [tab view];
        NSValue* identifier = [NSValue valueWithPointer:(__bridge const void*)[tab view]];
        NSValue* oldTargetValue = [targetFrames_ objectForKey:identifier];
        if (!oldTargetValue ||
            !NSEqualRects([oldTargetValue rectValue], tabFrame)) {
            [frameTarget setFrame:tabFrame];
            [targetFrames_ setObject:[NSValue valueWithRect:tabFrame]
                              forKey:identifier];
        }
        
        enclosingRect = NSUnionRect(tabFrame, enclosingRect);
        
        if (verticalLayout_) {
            offset += NSHeight(tabFrame);
        } else {
            offset += NSWidth(tabFrame);
            offset -= kTabOverlap;
        }
        i++;
    }
    
    if (forceNewTabButtonHidden_) {
        [newTabButton_ setHidden:YES];
    } else {
        NSRect newTabNewFrame = [newTabButton_ frame];
        newTabNewFrame.origin = NSMakePoint(offset, 0);
        newTabNewFrame.origin.x = MAX(newTabNewFrame.origin.x,
                                      NSMaxX(placeholderFrame_)) +
        kNewTabButtonOffset;
        if ([tabContentsArray_ count])
            [newTabButton_ setHidden:NO];
        
        if (!NSEqualRects(newTabTargetFrame_, newTabNewFrame)) {
            // Set the new tab button image correctly based on where the cursor is.
            NSWindow* window = [tabStripView_ window];
            NSPoint currentMouse = [window mouseLocationOutsideOfEventStream];
            currentMouse = [tabStripView_ convertPoint:currentMouse fromView:nil];
            
            BOOL shouldShowHover = [newTabButton_ pointIsOverButton:currentMouse];
            [self setNewTabButtonHoverState:shouldShowHover];
            
            if (visible && animate) {
                ScopedNSAnimationContextGroup localAnimationGroup(true);
                BOOL movingLeft = NSMinX(newTabNewFrame) < NSMinX(newTabTargetFrame_);
                if (!movingLeft) {
                    localAnimationGroup.SetCurrentContextShortestDuration();
                }
                [[newTabButton_ animator] setFrame:newTabNewFrame];
                newTabTargetFrame_ = newTabNewFrame;
            } else {
                [newTabButton_ setFrame:newTabNewFrame];
                newTabTargetFrame_ = newTabNewFrame;
            }
        }
    }
    
    [dragBlockingView_ setFrame:enclosingRect];
    
    initialLayoutComplete_ = YES;
}

- (void)layoutTabs {
    [self layoutTabsWithAnimation:initialLayoutComplete_ regenerateSubviews:YES];
}

- (void)setTabTitle:(NSViewController*)tab withContents:(CTTabContents*)contents {
    NSString* titleString = nil;
    if (contents)
        titleString = contents.title;
    if (!titleString || ![titleString length])
        titleString = L10n(@"New Tab");
    [tab setTitle:titleString];
}

- (void)removeTab:(CTTabController*)controller {
    NSUInteger index = [tabArray_ indexOfObject:controller];
    
    [tabContentsArray_ removeObjectAtIndex:index];
    
    NSView* tab = [controller view];
    [tab removeFromSuperview];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSViewDidUpdateTrackingAreasNotification object:tab];
    
    [controller setTarget:nil];
    
    if ([hoveredTab_ isEqual:tab])
        hoveredTab_ = nil;
    
    NSValue* identifier = [NSValue valueWithPointer:(__bridge const void*)tab];
    [targetFrames_ removeObjectForKey:identifier];
    
    [tabArray_ removeObjectAtIndex:index];
}

- (void)animationDidStopForController:(CTTabController*)controller
                             finished:(BOOL)finished {
    [closingControllers_ removeObject:controller];
    [self removeTab:controller];
}

- (void)startClosingTabWithAnimation:(CTTabController*)closingTab {
    assert([NSThread isMainThread]);
    [closingControllers_ addObject:closingTab];
    
    [(CTTabView*)[closingTab view] setClosing:YES];
    
    NSView* tabView = [closingTab view];
    CAAnimation* animation = [[tabView animationForKey:@"frameOrigin"] copy];
    TabCloseAnimationDelegate* delegate = 
    [[TabCloseAnimationDelegate alloc] initWithTabStrip:self
                                          tabController:closingTab];
    [animation setDelegate:delegate];  // Retains delegate.
    NSMutableDictionary* animationDictionary =
    [NSMutableDictionary dictionaryWithDictionary:[tabView animations]];
    [animationDictionary setObject:animation forKey:@"frameOrigin"];
    [tabView setAnimations:animationDictionary];
    
    NSRect newFrame = [tabView frame];
    newFrame = NSOffsetRect(newFrame, 0, -newFrame.size.height);
    ScopedNSAnimationContextGroup animationGroup(true);
    animationGroup.SetCurrentContextDuration(kAnimationDuration);
    [[tabView animator] setFrame:newFrame];
}

- (NSImageView*)iconImageViewForContents:(CTTabContents*)contents {
    NSImage* image = contents.icon;
    if (!image)
        image = defaultFavIcon_;
    NSRect frame = NSMakeRect(0, 0, kIconWidthAndHeight, kIconWidthAndHeight);
    NSImageView* view = [[NSImageView alloc] initWithFrame:frame];
    [view setImage:image];
    return view;
}

- (void)updateFavIconForContents:(CTTabContents*)contents
                         atIndex:(NSInteger)modelIndex {
    if (!contents)
        return;
    
    static NSImage* throbberWaitingImage = nil;
    static NSImage* throbberLoadingImage = nil;
    static NSImage* sadFaviconImage = nil;
    if (throbberWaitingImage == nil) {
        throbberWaitingImage =
        [NSImage imageInAppOrCTFrameworkNamed:@"throbber_waiting"];
        assert(throbberWaitingImage);
        throbberLoadingImage =
        [NSImage imageInAppOrCTFrameworkNamed:@"throbber"];
        assert(throbberLoadingImage);
        sadFaviconImage =
        [NSImage imageInAppOrCTFrameworkNamed:@"sadfavicon"];
        assert(sadFaviconImage);
    }
    
    NSInteger index = [self indexFromModelIndex:modelIndex];
    
    CTTabController* tabController = [tabArray_ objectAtIndex:index];
    
    if ([tabController phantom]) {
        [tabController setPhantom:NO];
        [[tabController view] setNeedsDisplay:YES];
    }
    
    bool oldHasIcon = [tabController iconView] != nil;
    bool newHasIcon = contents.hasIcon || [tabStripModel2_ isMiniTabAtIndex:modelIndex];  // Always show icon if mini.
    
    CTTabLoadingState oldState = [tabController loadingState];
    CTTabLoadingState newState = CTTabLoadingStateDone;
    NSImage* throbberImage = nil;
    if (contents.isCrashed) {
        newState = CTTabLoadingStateCrashed;
        newHasIcon = true;
    } else if (contents.isWaitingForResponse) {
        newState = CTTabLoadingStateWaiting;
        throbberImage = throbberWaitingImage;
    } else if (contents.isLoading) {
        newState = CTTabLoadingStateLoading;
        throbberImage = throbberLoadingImage;
    }
    
    if (oldState != newState)
        [tabController setLoadingState:newState];
    
    if (newState == CTTabLoadingStateDone || oldState != newState ||
        oldHasIcon != newHasIcon) {
        NSView* iconView = nil;
        if (newHasIcon) {
            if (newState == CTTabLoadingStateDone) {
                iconView = [self iconImageViewForContents:contents];
            } else if (newState == CTTabLoadingStateCrashed) {
                NSImage* oldImage = [[self iconImageViewForContents:contents] image];
                NSRect frame =
                NSMakeRect(0, 0, kIconWidthAndHeight, kIconWidthAndHeight);
                iconView = [ThrobberView toastThrobberViewWithFrame:frame
                                                        beforeImage:oldImage
                                                         afterImage:sadFaviconImage];
            } else {
                NSRect frame =
                NSMakeRect(0, 0, kIconWidthAndHeight, kIconWidthAndHeight);
                iconView = [ThrobberView filmstripThrobberViewWithFrame:frame
                                                                  image:throbberImage];
            }
        }
        
        [tabController setIconView:iconView];
    }
}

- (void)setFrameOfSelectedTab:(NSRect)frame {
    NSView* view = [self selectedTabView];
    NSValue* identifier = [NSValue valueWithPointer:(__bridge const void*)view];
    [targetFrames_ setObject:[NSValue valueWithRect:frame]
                      forKey:identifier];
    [view setFrame:frame];
}

- (NSView*)selectedTabView {
    int selectedIndex = [tabStripModel2_ selectedIndex];
    selectedIndex = [self indexFromModelIndex:selectedIndex];
    return [self viewAtIndex:selectedIndex];
}

- (int)indexOfPlaceholder {
    double placeholderX = placeholderFrame_.origin.x;
    int index = 0;
    int location = 0;
    const int count = [tabArray_ count];
    while (index < count) {
        if ([closingControllers_ containsObject:[tabArray_ objectAtIndex:index]]) {
            index++;
            continue;
        }
        NSView* curr = [self viewAtIndex:index];
        if (curr == placeholderTab_) {
            index++;
            continue;
        }
        if (placeholderX <= NSMinX([curr frame]))
            break;
        index++;
        location++;
    }
    return location;
}

- (void)moveTabFromIndex:(NSInteger)from {
    int toIndex = [self indexOfPlaceholder];
    [tabStripModel2_ moveTabContentsFromIndex:from toIndex:toIndex selectAfterMove:YES];
}

- (void)dropTabContents:(CTTabContents*)contents
              withFrame:(NSRect)frame
            asPinnedTab:(BOOL)pinned {
    int modelIndex = [self indexOfPlaceholder];
    
    droppedTabFrame_ = frame;
    
    [tabStripModel2_ insertTabContents:contents atIndex:modelIndex options:ADD_SELECTED | (pinned ? ADD_PINNED : 0)];
}

- (void)tabViewFrameChanged:(NSNotification*)info {
    [self layoutTabsWithAnimation:NO regenerateSubviews:NO];
}

- (void)tabUpdateTracking:(NSNotification*)notification {
    assert([[notification object] isKindOfClass:[CTTabView class]]);
    assert(mouseInside_);
    NSWindow* window = [tabStripView_ window];
    NSPoint location = [window mouseLocationOutsideOfEventStream];
    if (NSPointInRect(location, [tabStripView_ frame])) {
        NSEvent* mouseEvent = [NSEvent mouseEventWithType:NSMouseMoved
                                                 location:location
                                            modifierFlags:0
                                                timestamp:0
                                             windowNumber:[window windowNumber]
                                                  context:nil
                                              eventNumber:0
                                               clickCount:0
                                                 pressure:0];
        [self mouseMoved:mouseEvent];
    }
}

- (BOOL)inRapidClosureMode {
    return availableResizeWidth_ != kUseFullAvailableWidth;
}

- (BOOL)tabDraggingAllowed {
    return [closingControllers_ count] == 0;
}

- (void)mouseMoved:(NSEvent*)event {
    NSView* targetView = [tabStripView_ hitTest:[event locationInWindow]];
    
    BOOL shouldShowHoverImage = [targetView isKindOfClass:[NewTabButton class]];
    [self setNewTabButtonHoverState:shouldShowHoverImage];
    
    CTTabView* tabView = (CTTabView*)targetView;
    if (![tabView isKindOfClass:[CTTabView class]]) {
        if ([[tabView superview] isKindOfClass:[CTTabView class]]) {
            tabView = (CTTabView*)[targetView superview];
        } else {
            tabView = nil;
        }
    }
    
    if (hoveredTab_ != tabView) {
        [hoveredTab_ mouseExited:nil];  // We don't pass event because moved events
        [tabView mouseEntered:nil];  // don't have valid tracking areas
        hoveredTab_ = tabView;
    } else {
        [hoveredTab_ mouseMoved:event];
    }
}

- (void)mouseEntered:(NSEvent*)event {
    NSTrackingArea* area = [event trackingArea];
    if ([area isEqual:trackingArea_]) {
        mouseInside_ = YES;
        [self setTabTrackingAreasEnabled:YES];
        [self mouseMoved:event];
    }
}

- (void)mouseExited:(NSEvent*)event {
    NSTrackingArea* area = [event trackingArea];
    if ([area isEqual:trackingArea_]) {
        mouseInside_ = NO;
        [self setTabTrackingAreasEnabled:NO];
        availableResizeWidth_ = kUseFullAvailableWidth;
        [hoveredTab_ mouseExited:event];
        hoveredTab_ = nil;
        [self layoutTabs];
    } else if ([area isEqual:newTabTrackingArea_]) {
        [self setNewTabButtonHoverState:NO];
    }
}

- (void)setTabTrackingAreasEnabled:(BOOL)enabled {
    NSNotificationCenter* defaultCenter = [NSNotificationCenter defaultCenter];
    for (CTTabController* controller in tabArray_) {
        CTTabView* tabView = [controller tabView];
        if (enabled) {
            [defaultCenter addObserver:self
                              selector:@selector(tabUpdateTracking:)
                                  name:NSViewDidUpdateTrackingAreasNotification
                                object:tabView];
        } else {
            [defaultCenter removeObserver:self
                                     name:NSViewDidUpdateTrackingAreasNotification
                                   object:tabView];
        }
        [tabView setTrackingEnabled:enabled];
    }
}

- (void)setNewTabButtonHoverState:(BOOL)shouldShowHover {
    if (shouldShowHover && !newTabButtonShowingHoverImage_) {
        newTabButtonShowingHoverImage_ = YES;
        [newTabButton_ setImage:kNewTabHoverImage];
    } else if (!shouldShowHover && newTabButtonShowingHoverImage_) {
        newTabButtonShowingHoverImage_ = NO;
        [newTabButton_ setImage:kNewTabImage];
    }
}

- (void)addSubviewToPermanentList:(NSView*)aView {
    if (aView)
        [permanentSubviews_ addObject:aView];
}

- (void)regenerateSubviewList {
    [self setTabTrackingAreasEnabled:NO];
    
    NSMutableArray* subviews = [NSMutableArray arrayWithArray:permanentSubviews_];
    
    NSView* selectedTabView = nil;
    for (CTTabController* tab in [tabArray_ reverseObjectEnumerator]) {
        NSView* tabView = [tab view];
        if ([tab selected]) {
            assert(!selectedTabView);
            selectedTabView = tabView;
        } else {
            [subviews addObject:tabView];
        }
    }
    if (selectedTabView) {
        [subviews addObject:selectedTabView];
    }
    [tabStripView_ setSubviews:subviews];
    [self setTabTrackingAreasEnabled:mouseInside_];
}

- (CTTabContentsController*)activeTabContentsController {
    int modelIndex = [tabStripModel2_ selectedIndex];
    if (modelIndex < 0)
        return nil;
    NSInteger index = [self indexFromModelIndex:modelIndex];
    if (index < 0 ||
        index >= (NSInteger)[tabContentsArray_ count])
        return nil;
    return [tabContentsArray_ objectAtIndex:index];
}

@end
