#import "CTTabStripModel2.h"
#import "CTTabStripModel.h"

extern NSString* const kCTTabInsertedNotification = @"kCTTabInsertedNotification";
extern NSString* const kCTTabClosingNotification = @"kCTTabClosingNotification";
extern NSString* const kCTTabDetachedNotification = @"kCTTabDetachedNotification";
extern NSString* const kCTTabDeselectedNotification = @"kCTTabDeselectedNotification";
extern NSString* const kCTTabSelectedNotification = @"kCTTabSelectedNotification";
extern NSString* const kCTTabMovedNotification = @"kCTTabMovedNotification";
extern NSString* const kCTTabChangedNotification = @"kCTTabChangedNotification";
extern NSString* const kCTTabReplacedNotification = @"kCTTabReplacedNotification";
extern NSString* const kCTTabPinnedStateChangedNotification = @"kCTTabPinnedStateChangedNotification";
extern NSString* const kCTTabMiniStateChangedNotification = @"kCTTabMiniStateChangedNotification";
extern NSString* const kCTTabBlockedStateChangedNotification = @"kCTTabBlockedStateChangedNotification";
extern NSString* const kCTTabStripEmptyNotification = @"kCTTabStripEmptyNotification";
extern NSString* const kCTTabStripModelDeletedNotification = @"kCTTabStripModelDeletedNotification";

extern NSString* const kCTTabContentsUserInfoKey = @"kCTTabContentsUserInfoKey";
extern NSString* const kCTTabIndexUserInfoKey = @"kCTTabIndexUserInfoKey";
extern NSString* const kCTTabForegroundUserInfoKey = @"kCTTabForegroundUserInfoKey";

@interface CTTabStripModel2 (Private)

- (NSInteger) indexOfNextNonPhantomTabFromIndex:(NSInteger)index ignoreIndex:(NSInteger)ignoreIndex;
- (void) changeSelectedContentsFrom:(CTTabContents*)old_contents toIndex:(NSInteger)toIndex userGesture:(BOOL)userGesture;
- (NSInteger) constrainInsertionIndex:(NSInteger)index miniTab:(BOOL)miniTab;
- (void) _moveTabContentsFromIndex:(NSInteger)fromIndex toIndex:(NSInteger)toIndex selectAfterMove:(BOOL)selectedAfterMove;
- (BOOL) _closeTabsatIndices:(NSArray*)indices options:(uint32)options;
- (void) _closeTabAtIndex:(NSInteger)index contents:(CTTabContents*)contents history:(BOOL)createHistory;

@end

@interface CTTabStripModel2 (OrderController)

- (NSInteger) determineInsertionIndexForContents:(CTTabContents*)contents pageTransition:(CTPageTransition)transition foreground:(BOOL)foreground;
- (NSInteger) determineInsertionIndexForAppending;
- (NSInteger) determineNewSelectedIndexByRemovingIndex:(NSInteger)removing_index isRemove:(BOOL)is_remove;
- (NSInteger) validIndexForIndex:(NSInteger)index removingIndex:(NSInteger)removing_index isRemove:(BOOL)is_remove;
- (void) selectRelativeTab:(BOOL)next;

@end


@implementation CTTabStripModel2 {
    CTTabStripModel* tabStripModel_;
    ObserverList<CTTabStripModelObserver> observers_;
}

@synthesize insertionPolicy = insertionPolicy_;

static const int kNoTab = -1;

- (id) initWithPointer:(CTTabStripModel*)tabStripModel
{
    if (nil != (self = [super init])) {
        tabStripModel_ = tabStripModel;
    }
    return self;
}

- (void) addObserver:(CTTabStripModelObserver*)observer
{
    tabStripModel_->AddObserver(observer);
    observers_.AddObserver(observer);
}

- (void) removeObserver:(CTTabStripModelObserver*)observer
{
    tabStripModel_->RemoveObserver(observer);
    observers_.RemoveObserver(observer);
}

- (BOOL) hasNonPhantomTabs
{
    return [self count];
}

- (BOOL) hasObserver:(CTTabStripModelObserver*)observer
{
    return tabStripModel_->HasObserver(observer);
}

- (NSInteger) count
{
    return tabStripModel_->count();
}

- (NSInteger) selectedIndex
{
    return tabStripModel_->selected_index();
}

- (void) setSelectedIndex:(NSInteger)selectedIndex
{
    tabStripModel_->selected_index_ = selectedIndex;
}

- (CTTabContents*) tabContentsAtIndex:(NSInteger)index
{
    if ([self containsIndex:index]) {
        TabContentsData* data = [tabStripModel_->contents_data_ objectAtIndex:index];
        return data->contents;
    }
    return nil;
}

- (NSInteger) indexOfTabContents:(CTTabContents*)tabContents
{
    int index = 0;
    for (TabContentsData* data in tabStripModel_->contents_data_) {
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
    for (size_t i = 0; i < tabStripModel_->contents_data_.count; ++i) {
        if (![self isMiniTabAtIndex:i]) {
            return i;
        }
    }
    // No mini-tabs.
    return self.count;
}

- (BOOL) isMiniTabAtIndex:(NSInteger)index
{
    return [self isTabPinnedAtIndex:index] || [self isAppTabAtIndex:index];
}

- (BOOL) isTabPinnedAtIndex:(NSInteger)index
{
    TabContentsData* data = [tabStripModel_->contents_data_ objectAtIndex:index];
    return data->pinned;
}

- (BOOL) isAppTabAtIndex:(NSInteger)index
{
    CTTabContents* contents = [self tabContentsAtIndex:index];
    return contents && contents.isApp;
}

- (BOOL) isPhantomTabAtIndex:(NSInteger)index
{
    return tabStripModel_->IsPhantomTab(index);
}

- (void) moveTabContentsFromIndex:(NSInteger)fromIndex toIndex:(NSInteger)toIndex selectAfterMove:(BOOL)selectedAfterMove
{
    assert([self containsIndex:toIndex]);
    if (fromIndex == toIndex)
        return;
    
    int first_non_mini_tab = [self indexOfFirstNonMiniTab];
    if ((fromIndex < first_non_mini_tab && toIndex >= first_non_mini_tab) || (toIndex < first_non_mini_tab && fromIndex >= first_non_mini_tab)) {
        // This would result in mini tabs mixed with non-mini tabs. We don't allow that.
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
    
    // In tab dragging situations, if the last tab in the window was detached
    // then the user aborted the drag, we will have the |closing_all_| member
    // set (see DetachTabContentsAt) which will mess with our mojo here. We need
    // to clear this bit.
    tabStripModel_->closing_all_ = false;
    
    // Have to get the selected contents before we monkey with |contents_|
    // otherwise we run into problems when we try to change the selected contents
    // since the old contents and the new contents will be the same...
    CTTabContents* selected_contents = [self selectedTabContents];
    TabContentsData* data = [[TabContentsData alloc] init];
    data->contents = contents;
    data->pinned = pin;
    
    [tabStripModel_->contents_data_ insertObject:data atIndex:index];
    
    if (index <= self.selectedIndex) {
        // If a tab is inserted before the current selected index,
        // then |selected_index| needs to be incremented.
        ++self.selectedIndex;
    }
    
    FOR_EACH_OBSERVER(CTTabStripModelObserver, tabStripModel_->observers_,
                      TabInsertedAt(contents, index, foreground));
    
    if (foreground) {
        [self changeSelectedContentsFrom:selected_contents toIndex:index userGesture:NO];
    }
}

- (void) updateTabContentsStateAtIndex:(NSInteger)index changeType:(CTTabChangeType)changeType
{
    assert([self containsIndex:index]);
    FOR_EACH_OBSERVER(CTTabStripModelObserver, tabStripModel_->observers_,
                      TabChangedAt([self tabContentsAtIndex:index], index, changeType));
}

- (void) replaceTabContentsAtIndex:(NSInteger)index withContents:contents replaceType:(CTTabReplaceType)replaceType
{
    assert([self containsIndex:index]);
    CTTabContents* old_contents = [self tabContentsAtIndex:index];
    TabContentsData* data = [tabStripModel_->contents_data_ objectAtIndex:index];
    data->contents = contents;
    FOR_EACH_OBSERVER(CTTabStripModelObserver, tabStripModel_->observers_,
                      TabReplacedAt(old_contents, contents, index, replaceType));
    [old_contents destroy:tabStripModel_];
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
    
    // Reset the index, just in case insert ended up moving it on us.
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
    NSMutableArray* contents_data_ = tabStripModel_->contents_data_;
    if (contents_data_.count == 0)
        return nil;
    
    assert([self containsIndex:index]);
    
    CTTabContents* removed_contents = [self tabContentsAtIndex:index];
    int next_selected_index = [self determineNewSelectedIndexByRemovingIndex:index isRemove:YES];
    [contents_data_ removeObjectAtIndex:index];
    next_selected_index = [self indexOfNextNonPhantomTabFromIndex:next_selected_index ignoreIndex:-1];
    if (![self hasNonPhantomTabs]) {
        tabStripModel_->closing_all_ = true;
    }
    ObserverList<CTTabStripModelObserver>::Iterator iter(tabStripModel_->observers_);
    while (CTTabStripModelObserver* obs = iter.GetNext()) {
        obs->TabDetachedAt(removed_contents, index);
        if (![self hasNonPhantomTabs])
            obs->TabStripEmpty();
    }
    if ([self hasNonPhantomTabs]) {
        if (index == tabStripModel_->selected_index_) {
            [self changeSelectedContentsFrom:removed_contents toIndex:next_selected_index userGesture:NO];
        } else if (index < tabStripModel_->selected_index_) {
            // The selected tab didn't change, but its position shifted; update our
            // index to continue to point at it.
            --tabStripModel_->selected_index_;
        }
    }
    return removed_contents;
}

- (void) setTabPinnedAtIndex:(NSInteger)index pinned:(BOOL)pinned
{
    assert([self containsIndex:index]);
    TabContentsData* data = [tabStripModel_->contents_data_ objectAtIndex:index];
    if (data->pinned == pinned)
        return;
    
    if ([self isAppTabAtIndex:index]) {
        if (!pinned) {
            // App tabs should always be pinned.
            NOTREACHED();
            return;
        }
        // Changing the pinned state of an app tab doesn't effect it's mini-tab
        // status.
        data->pinned = pinned;
    } else {
        // The tab is not an app tab, it's position may have to change as the
        // mini-tab state is changing.
        int non_mini_tab_index = [self indexOfFirstNonMiniTab];
        data->pinned = pinned;
        if (pinned && index != non_mini_tab_index) {
            [self _moveTabContentsFromIndex:index toIndex:non_mini_tab_index selectAfterMove:NO];
            return;  // Don't send TabPinnedStateChanged notification.
        } else if (!pinned && index + 1 != non_mini_tab_index) {
            [self _moveTabContentsFromIndex:index toIndex:non_mini_tab_index - 1 selectAfterMove:NO];
            return;  // Don't send TabPinnedStateChanged notification.
        }
        
        FOR_EACH_OBSERVER(CTTabStripModelObserver, tabStripModel_->observers_,
                          TabMiniStateChanged(data->contents,
                                              index));
    }
    
    // else: the tab was at the boundary and it's position doesn't need to change.
    FOR_EACH_OBSERVER(CTTabStripModelObserver, tabStripModel_->observers_,
                      TabPinnedStateChanged(data->contents,
                                            index));
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
    if (old_contents == new_contents)
        return;
    
    CTTabContents* last_selected_contents = old_contents;
    if (last_selected_contents) {
        FOR_EACH_OBSERVER(CTTabStripModelObserver, tabStripModel_->observers_,
                          TabDeselectedAt(last_selected_contents, self.selectedIndex));
    }
    
    self.selectedIndex = toIndex;
    FOR_EACH_OBSERVER(CTTabStripModelObserver, tabStripModel_->observers_,
                      TabSelectedAt(last_selected_contents, new_contents, self.selectedIndex, userGesture));
}

- (NSInteger) constrainInsertionIndex:(NSInteger)index miniTab:(BOOL)miniTab
{
    return miniTab ? MIN(MAX(0, index), [self indexOfFirstNonMiniTab]) : MIN(self.count, MAX(index, [self indexOfFirstNonMiniTab]));
}
     
- (void) _moveTabContentsFromIndex:(NSInteger)fromIndex toIndex:(NSInteger)toIndex selectAfterMove:(BOOL)selectedAfterMove
{
    TabContentsData* moved_data = [tabStripModel_->contents_data_ objectAtIndex:fromIndex];
    [tabStripModel_->contents_data_ removeObjectAtIndex:fromIndex];
    [tabStripModel_->contents_data_ insertObject:moved_data atIndex:toIndex];

    // if !select_after_move, keep the same tab selected as was selected before.
    int selectedIndex = self.selectedIndex;
    if (selectedAfterMove || fromIndex == selectedIndex) {
        self.selectedIndex = toIndex;
    } else if (fromIndex < selectedIndex && toIndex >= selectedIndex) {
        self.selectedIndex--;
    } else if (fromIndex > selectedIndex && toIndex <= selectedIndex) {
        self.selectedIndex++;
    }

    FOR_EACH_OBSERVER(CTTabStripModelObserver, tabStripModel_->observers_,
                   TabMoved(moved_data->contents, fromIndex, toIndex));
}

- (void) selectRelativeTab:(BOOL)next
{
    // This may happen during automated testing or if a user somehow buffers
    // many key accelerators.
    if (tabStripModel_->contents_data_.count == 0)
        return;
    
    // Skip pinned-app-phantom tabs when iterating.
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
    
    // We now return to our regularly scheduled shutdown procedure.
    for (size_t i = 0; i < indices.count; ++i) {
        int index = [[indices objectAtIndex:i] intValue];
        CTTabContents* detached_contents = tabStripModel_->GetContentsAt(index);
        [detached_contents closingOfTabDidStart:nil]; // TODO notification
        
        if (![tabStripModel_->delegate_ canCloseContentsAt:index]) {
            retval = false;
            continue;
        }
        
        // Update the explicitly closed state. If the unload handlers cancel the
        // close the state is reset in CTBrowser. We don't update the explicitly
        // closed state if already marked as explicitly closed as unload handlers
        // call back to this if the close is allowed.
        if (!detached_contents.closedByUserGesture) {
            detached_contents.closedByUserGesture = options & CLOSE_USER_GESTURE;
        }
        
        //if (delegate_->RunUnloadListenerBeforeClosing(detached_contents)) {
        if ([tabStripModel_->delegate_ runUnloadListenerBeforeClosing:detached_contents]) {
            retval = false;
            continue;
        }
        
        [self _closeTabAtIndex:index contents:detached_contents history:(options & CLOSE_CREATE_HISTORICAL_TAB) != 0];
    }
    
    return retval;
}

- (void) _closeTabAtIndex:(NSInteger)index contents:(CTTabContents*)contents history:(BOOL)createHistory
{
    FOR_EACH_OBSERVER(CTTabStripModelObserver, tabStripModel_->observers_,
                      TabClosingAt(contents, index));
    
    // Ask the delegate to save an entry for this tab in the historical tab
    // database if applicable.
    if (createHistory) {
        [tabStripModel_->delegate_ createHistoricalTab:contents];
        //delegate_->CreateHistoricalTab(contents);
    }
    
    // Deleting the CTTabContents will call back to us via NotificationObserver
    // and detach it.
    [contents destroy:tabStripModel_];
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
        if (index != CTTabStripModel::kNoTab)
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
