#import "CTTabStripModel2.h"

NSString* const kCTTabInsertedNotification = @"kCTTabInsertedNotification";
NSString* const kCTTabClosingNotification = @"kCTTabClosingNotification";
NSString* const kCTTabDetachedNotification = @"kCTTabDetachedNotification";
NSString* const kCTTabDeselectedNotification = @"kCTTabDeselectedNotification";
NSString* const kCTTabSelectedNotification = @"kCTTabSelectedNotification";
NSString* const kCTTabMovedNotification = @"kCTTabMovedNotification";
NSString* const kCTTabChangedNotification = @"kCTTabChangedNotification";
NSString* const kCTTabReplacedNotification = @"kCTTabReplacedNotification";
NSString* const kCTTabPinnedStateChangedNotification = @"kCTTabPinnedStateChangedNotification";
NSString* const kCTTabMiniStateChangedNotification = @"kCTTabMiniStateChangedNotification";
NSString* const kCTTabBlockedStateChangedNotification = @"kCTTabBlockedStateChangedNotification";
NSString* const kCTTabStripEmptyNotification = @"kCTTabStripEmptyNotification";
NSString* const kCTTabStripModelDeletedNotification = @"kCTTabStripModelDeletedNotification";

NSString* const kCTTabContentsUserInfoKey = @"kCTTabContentsUserInfoKey";
NSString* const kCTTabNewContentsUserInfoKey = @"kCTTabNewContentsUserInfoKey";
NSString* const kCTTabIndexUserInfoKey = @"kCTTabIndexUserInfoKey";
NSString* const kCTTabToIndexUserInfoKey = @"kCTTabToIndexUserInfoKey";
NSString* const kCTTabForegroundUserInfoKey = @"kCTTabForegroundUserInfoKey";
NSString* const kCTTabUserGestureUserInfoKey = @"kCTTaUserGestureUserInfoKey";
NSString* const kCTTabOptionsUserInfoKey = @"kCTTaOptionsInfoKey";

const int kNoTab = -1;

@interface TabContentsData : NSObject {
@public
    CTTabContents* contents;
    BOOL pinned;
    BOOL blocked;
}
@end

@implementation TabContentsData

@end

@interface CTTabStripModel2 (Private)

- (NSInteger) indexOfNextNonPhantomTabFromIndex:(NSInteger)index ignoreIndex:(NSInteger)ignoreIndex;
- (void) changeSelectedContentsFrom:(CTTabContents*)old_contents toIndex:(NSInteger)toIndex userGesture:(BOOL)userGesture;
- (NSInteger) constrainInsertionIndex:(NSInteger)index miniTab:(BOOL)miniTab;
- (void) _moveTabContentsFromIndex:(NSInteger)fromIndex toIndex:(NSInteger)toIndex selectAfterMove:(BOOL)selectedAfterMove;
- (BOOL) _closeTabsatIndices:(NSArray*)indices options:(uint32)options;
- (void) _closeTabAtIndex:(NSInteger)index contents:(CTTabContents*)contents history:(BOOL)createHistory;
- (CTTabContents*) _contentsAtIndex:(NSInteger)index;

@end

@interface CTTabStripModel2 (OrderController)

- (NSInteger) determineInsertionIndexForContents:(CTTabContents*)contents pageTransition:(CTPageTransition)transition foreground:(BOOL)foreground;
- (NSInteger) determineInsertionIndexForAppending;
- (NSInteger) determineNewSelectedIndexByRemovingIndex:(NSInteger)removing_index isRemove:(BOOL)is_remove;
- (NSInteger) validIndexForIndex:(NSInteger)index removingIndex:(NSInteger)removing_index isRemove:(BOOL)is_remove;
- (void) selectRelativeTab:(BOOL)next;

@end


@implementation CTTabStripModel2 {
    NSMutableArray* contents_data_;
    BOOL closing_all_;
    NSObject<CTTabStripModelDelegate>* delegate_;
}

@synthesize insertionPolicy = insertionPolicy_;
@synthesize selectedIndex = selectedIndex_;

- (id) initWithDelegate:(NSObject<CTTabStripModelDelegate>*)delegate
{
    if (nil != (self = [super init])) {
        delegate_ = delegate;
        contents_data_ = [NSMutableArray array];
    }
    return self;
}

- (BOOL) hasNonPhantomTabs
{
    return [self count];
}

- (NSInteger) count
{
    return contents_data_.count;
}

- (CTTabContents*) tabContentsAtIndex:(NSInteger)index
{
    if ([self containsIndex:index]) {
        return [self _contentsAtIndex:index];
    }
    return nil;
}

- (NSInteger) indexOfTabContents:(CTTabContents*)tabContents
{
    int index = 0;
    for (TabContentsData* data in contents_data_) {
        if (data->contents == tabContents) {
            return index;
        }
        index++;
    }
    return kNoTab;
}

- (CTTabContents*) selectedTabContents
{
    return [self tabContentsAtIndex:self.selectedIndex];
}

- (BOOL) containsIndex:(NSInteger)index
{
    return index >= 0 && index < [self count];
}
    
- (void) selectTabContentsAtIndex:(NSInteger)index userGesture:(BOOL)userGesture
{
    if ([self containsIndex:index]) {
        [self changeSelectedContentsFrom:[self selectedTabContents] toIndex:index userGesture:userGesture];
    }
}

- (BOOL) closeTabContentsAtIndex:(NSInteger)index options:(NSInteger)options
{
    NSMutableArray* closing_tabs = [NSMutableArray array];
    [closing_tabs addObject:[NSNumber numberWithInt:index]];
    return [self _closeTabsatIndices:closing_tabs options:options];
}

- (NSInteger) indexOfFirstNonMiniTab
{
    for (size_t i = 0; i < contents_data_.count; ++i) {
        if (![self isMiniTabAtIndex:i]) {
            return i;
        }
    }
    return self.count;
}

- (BOOL) isMiniTabAtIndex:(NSInteger)index
{
    return [self isTabPinnedAtIndex:index] || [self isAppTabAtIndex:index];
}

- (BOOL) isTabPinnedAtIndex:(NSInteger)index
{
    TabContentsData* data = [contents_data_ objectAtIndex:index];
    return data->pinned;
}

- (BOOL) isAppTabAtIndex:(NSInteger)index
{
    CTTabContents* contents = [self tabContentsAtIndex:index];
    return contents && contents.isApp;
}

- (BOOL) isPhantomTabAtIndex:(NSInteger)index
{
    return NO;
}

- (void) moveTabContentsFromIndex:(NSInteger)fromIndex toIndex:(NSInteger)toIndex selectAfterMove:(BOOL)selectedAfterMove
{
    assert([self containsIndex:toIndex]);
    if (fromIndex == toIndex)
        return;
    
    int first_non_mini_tab = [self indexOfFirstNonMiniTab];
    if ((fromIndex < first_non_mini_tab && toIndex >= first_non_mini_tab) || (toIndex < first_non_mini_tab && fromIndex >= first_non_mini_tab)) {
        return;
    }
    
    [self _moveTabContentsFromIndex:fromIndex toIndex:toIndex selectAfterMove:selectedAfterMove];
}

- (void) insertTabContents:(CTTabContents*)contents atIndex:(NSInteger)index options:(NSInteger)options
{
    bool foreground = options & ADD_SELECTED;
    // Force app tabs to be pinned.
    bool pin = contents.isApp || options & ADD_PINNED;
    index = [self constrainInsertionIndex:index miniTab:pin];
    
    closing_all_ = false;
    
    CTTabContents* selected_contents = [self selectedTabContents];
    TabContentsData* data = [[TabContentsData alloc] init];
    data->contents = contents;
    data->pinned = pin;
    
    [contents_data_ insertObject:data atIndex:index];
    
    if (index <= self.selectedIndex) {
        ++self.selectedIndex;
    }
    
    NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              contents, kCTTabContentsUserInfoKey,
                              [NSNumber numberWithInt:index], kCTTabIndexUserInfoKey,
                              [NSNumber numberWithBool:foreground], kCTTabForegroundUserInfoKey, 
                              nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:kCTTabInsertedNotification object:self userInfo:userInfo];
    
    if (foreground) {
        [self changeSelectedContentsFrom:selected_contents toIndex:index userGesture:NO];
    }
}

- (void) updateTabContentsStateAtIndex:(NSInteger)index changeType:(CTTabChangeType)changeType
{
    assert([self containsIndex:index]);
    NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              [self tabContentsAtIndex:index], kCTTabContentsUserInfoKey,
                              [NSNumber numberWithInt:index], kCTTabIndexUserInfoKey,
                              [NSNumber numberWithInt:changeType], kCTTabOptionsUserInfoKey, 
                              nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:kCTTabChangedNotification object:self userInfo:userInfo];
}

- (void) replaceTabContentsAtIndex:(NSInteger)index withContents:contents replaceType:(CTTabReplaceType)replaceType
{
    assert([self containsIndex:index]);
    CTTabContents* old_contents = [self tabContentsAtIndex:index];
    TabContentsData* data = [contents_data_ objectAtIndex:index];
    data->contents = contents;
    
    NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              old_contents, kCTTabContentsUserInfoKey,
                              contents, kCTTabNewContentsUserInfoKey,
                              [NSNumber numberWithInt:index], kCTTabIndexUserInfoKey,
                              [NSNumber numberWithInt:replaceType], kCTTabOptionsUserInfoKey, 
                              nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:kCTTabReplacedNotification object:self userInfo:userInfo];
    [self detachTabContentsAtIndex:index];
}

- (void) closeAllTabs
{
    NSMutableArray* closing_tabs = [NSMutableArray array];
    for (int i = self.count - 1; i >= 0; --i) {
        [closing_tabs addObject:[NSNumber numberWithInt:i]];
    }
    [self _closeTabsatIndices:closing_tabs options:CLOSE_CREATE_HISTORICAL_TAB];
}

- (NSInteger) addTabContents:(CTTabContents*)contents atIndex:(NSInteger)index withPageTransition:(CTPageTransition)pageTransition options:(NSInteger)options
{
    bool inherit_group = (options & ADD_INHERIT_GROUP) == ADD_INHERIT_GROUP;
    
    if (pageTransition == CTPageTransitionLink && (options & ADD_FORCE_INDEX) == 0) {
        index = [self determineInsertionIndexForContents:contents pageTransition:pageTransition foreground:options & ADD_SELECTED];
        inherit_group = true;
    } else {
        if (index < 0 || index > self.count)
            index = [self determineInsertionIndexForAppending];
        }
    
    if (pageTransition == CTPageTransitionTyped && index == self.count) {
        inherit_group = true;
    }
    [self insertTabContents:contents atIndex:index options:options | (inherit_group ? ADD_INHERIT_GROUP : 0)];
    
    index = [self indexOfTabContents:contents];
    
    return index;
}

- (void) selectNextTab
{
    [self selectRelativeTab:YES];
}

- (void) selectPreviousTab
{
    [self selectRelativeTab:NO];
}

- (void) moveTabNext
{
    int new_index = MIN(self.selectedIndex + 1, self.count - 1);
    [self moveTabContentsFromIndex:self.selectedIndex toIndex:new_index selectAfterMove:YES];
}

- (void) moveTabPrevious
{
    int new_index = MAX(self.selectedIndex - 1, 0);
    [self moveTabContentsFromIndex:self.selectedIndex toIndex:new_index selectAfterMove:YES];
}

- (void) selectLastTab
{
    [self selectTabContentsAtIndex:self.count - 1 userGesture:YES];
}

- (void) appendTabContents:(CTTabContents*)contents foreground:(BOOL)foreground
{
    int index = [self determineInsertionIndexForAppending];
    [self insertTabContents:contents atIndex:index options:foreground ? (ADD_INHERIT_GROUP | ADD_SELECTED) : ADD_NONE];
}

- (CTTabContents*) detachTabContentsAtIndex:(NSInteger)index
{
    if (contents_data_.count == 0)
        return nil;
    
    assert([self containsIndex:index]);
    
    CTTabContents* removed_contents = [self tabContentsAtIndex:index];
    int next_selected_index = [self determineNewSelectedIndexByRemovingIndex:index isRemove:YES];
    [contents_data_ removeObjectAtIndex:index];
    next_selected_index = [self indexOfNextNonPhantomTabFromIndex:next_selected_index ignoreIndex:-1];
    if (![self hasNonPhantomTabs]) {
        closing_all_ = true;
    }
    NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              removed_contents, kCTTabContentsUserInfoKey,
                              [NSNumber numberWithInt:index], kCTTabIndexUserInfoKey,
                              nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:kCTTabDetachedNotification object:self userInfo:userInfo];
    if (![self hasNonPhantomTabs]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kCTTabStripEmptyNotification object:self userInfo:nil];
    }
    if ([self hasNonPhantomTabs]) {
        if (index == selectedIndex_) {
            [self changeSelectedContentsFrom:removed_contents toIndex:next_selected_index userGesture:NO];
        } else if (index < selectedIndex_) {
            --selectedIndex_;
        }
    }
    return removed_contents;
}

- (void) setTabPinnedAtIndex:(NSInteger)index pinned:(BOOL)pinned
{
    assert([self containsIndex:index]);
    TabContentsData* data = [contents_data_ objectAtIndex:index];
    if (data->pinned == pinned)
        return;
    
    if ([self isAppTabAtIndex:index]) {
        if (!pinned) {
            return;
        }
        data->pinned = pinned;
    } else {
        int non_mini_tab_index = [self indexOfFirstNonMiniTab];
        data->pinned = pinned;
        if (pinned && index != non_mini_tab_index) {
            [self _moveTabContentsFromIndex:index toIndex:non_mini_tab_index selectAfterMove:NO];
            return;
        } else if (!pinned && index + 1 != non_mini_tab_index) {
            [self _moveTabContentsFromIndex:index toIndex:non_mini_tab_index - 1 selectAfterMove:NO];
            return;
        }
        
        NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                  data->contents, kCTTabContentsUserInfoKey,
                                  [NSNumber numberWithInt:index], kCTTabIndexUserInfoKey,
                                  nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:kCTTabMiniStateChangedNotification object:self userInfo:userInfo];
    }
}

- (void) closeSelectedTab
{
    [self closeTabContentsAtIndex:self.selectedIndex options:CLOSE_CREATE_HISTORICAL_TAB];
}

#pragma mark -
#pragma mark Private Functions

- (NSInteger) indexOfNextNonPhantomTabFromIndex:(NSInteger)index ignoreIndex:(NSInteger)ignoreIndex
{
    if (index == kNoTab) {
        return kNoTab;
    }
    
    if (self.count == 0) {
        return index;
    }
    
    index = MIN(self.count - 1, MAX(0, index));
    int start = index;
    do {
        if (index != ignoreIndex && ![self isPhantomTabAtIndex:index])
            return index;
        index = (index + 1) % self.count;
    } while (index != start);
    
    // All phantom tabs.
    return start;
}

- (void) changeSelectedContentsFrom:(CTTabContents*)old_contents toIndex:(NSInteger)toIndex userGesture:(BOOL)userGesture
{
    assert([self containsIndex:toIndex]);
    CTTabContents* new_contents = [self tabContentsAtIndex:toIndex];
    if (old_contents == new_contents) {
        return;
    }
    
    self.selectedIndex = toIndex;
    NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              new_contents, kCTTabNewContentsUserInfoKey,
                              [NSNumber numberWithInt:self.selectedIndex], kCTTabIndexUserInfoKey,
                              [NSNumber numberWithBool:userGesture], kCTTabUserGestureUserInfoKey,
                              old_contents, kCTTabContentsUserInfoKey,
                              nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:kCTTabSelectedNotification object:self userInfo:userInfo];
}

- (NSInteger) constrainInsertionIndex:(NSInteger)index miniTab:(BOOL)miniTab
{
    return miniTab ? MIN(MAX(0, index), [self indexOfFirstNonMiniTab]) : MIN(self.count, MAX(index, [self indexOfFirstNonMiniTab]));
}
     
- (void) _moveTabContentsFromIndex:(NSInteger)fromIndex toIndex:(NSInteger)toIndex selectAfterMove:(BOOL)selectedAfterMove
{
    TabContentsData* moved_data = [contents_data_ objectAtIndex:fromIndex];
    [contents_data_ removeObjectAtIndex:fromIndex];
    [contents_data_ insertObject:moved_data atIndex:toIndex];

    int selectedIndex = self.selectedIndex;
    if (selectedAfterMove || fromIndex == selectedIndex) {
        self.selectedIndex = toIndex;
    } else if (fromIndex < selectedIndex && toIndex >= selectedIndex) {
        self.selectedIndex--;
    } else if (fromIndex > selectedIndex && toIndex <= selectedIndex) {
        self.selectedIndex++;
    }

    NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              moved_data->contents, kCTTabNewContentsUserInfoKey,
                              [NSNumber numberWithInt:fromIndex], kCTTabIndexUserInfoKey,
                              [NSNumber numberWithInt:toIndex], kCTTabToIndexUserInfoKey,
                              nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:kCTTabMovedNotification object:self userInfo:userInfo];
}

- (void) selectRelativeTab:(BOOL)next
{
    if (contents_data_.count == 0)
        return;
    
    int index = self.selectedIndex;
    int delta = next ? 1 : -1;
    do {
        index = (index + self.count + delta) % self.count;
    } while (index != self.selectedIndex && [self isPhantomTabAtIndex:index]);
    [self selectTabContentsAtIndex:index userGesture:YES];
}

- (BOOL) _closeTabsatIndices:(NSArray*)indices options:(uint32)options
{
    bool retval = true;
    
    for (size_t i = 0; i < indices.count; ++i) {
        int index = [[indices objectAtIndex:i] intValue];
        CTTabContents* detached_contents = [self _contentsAtIndex:index];
        [detached_contents closingOfTabDidStart:self]; // TODO notification
        
        if (![delegate_ canCloseContentsAt:index]) {
            retval = false;
            continue;
        }
        
        if (!detached_contents.closedByUserGesture) {
            detached_contents.closedByUserGesture = options & CLOSE_USER_GESTURE;
        }
        
        if ([delegate_ runUnloadListenerBeforeClosing:detached_contents]) {
            retval = false;
            continue;
        }
        
        [self _closeTabAtIndex:index contents:detached_contents history:(options & CLOSE_CREATE_HISTORICAL_TAB) != 0];
    }
    
    return retval;
}

- (void) _closeTabAtIndex:(NSInteger)index contents:(CTTabContents*)contents history:(BOOL)createHistory
{
    NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              contents, kCTTabContentsUserInfoKey,
                              [NSNumber numberWithInt:index], kCTTabIndexUserInfoKey,
                              nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:kCTTabClosingNotification object:self userInfo:userInfo];
    
    if (createHistory) {
        [delegate_ createHistoricalTab:contents];
    }
    
    [self detachTabContentsAtIndex:index];
}

- (CTTabContents*) _contentsAtIndex:(NSInteger)index
{
    TabContentsData* data = [contents_data_ objectAtIndex:index];
    return data->contents;
}

#pragma mark -
#pragma mark Model Order Controller Functions

- (NSInteger) determineInsertionIndexForContents:(CTTabContents*)contents pageTransition:(CTPageTransition)transition foreground:(BOOL)foreground
{
    int tab_count = [self count];
    if (!tab_count)
        return 0;
    
    NSInteger selectedIndex = [self selectedIndex];
    if (transition == CTPageTransitionLink && selectedIndex != -1) {
        int delta = (self.insertionPolicy == INSERT_AFTER) ? 1 : 0;
        if (foreground) {
            return selectedIndex + delta;
        }
        return selectedIndex + delta;
    }
    
    return [self determineInsertionIndexForAppending];
}

- (NSInteger) determineInsertionIndexForAppending
{
    return (self.insertionPolicy == INSERT_AFTER) ? [self count] : 0;
}

- (NSInteger) determineNewSelectedIndexByRemovingIndex:(NSInteger)removing_index isRemove:(BOOL)is_remove
{
    int tab_count = [self count];
    assert(removing_index >= 0 && removing_index < tab_count);
    
    CTTabContents* parentOpener = [[self tabContentsAtIndex:removing_index] parentOpener];
    if (parentOpener) {
        int index = [self indexOfTabContents:parentOpener];
        if (index != kNoTab)
            return [self validIndexForIndex:index removingIndex:removing_index isRemove:is_remove];
    }
    
    int selected_index = [self selectedIndex];
    if (is_remove && selected_index >= (tab_count - 1))
        return selected_index - 1;
    return selected_index;
}

- (NSInteger) validIndexForIndex:(NSInteger)index removingIndex:(NSInteger)removing_index isRemove:(BOOL)is_remove
{
    if (is_remove && removing_index < index)
        index = MAX(0, index - 1);
    return index;
}

@end
