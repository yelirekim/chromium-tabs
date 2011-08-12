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


@interface CTTabStripModel2 (OrderController)

- (NSInteger) determineInsertionIndexForContents:(CTTabContents*)contents pageTransition:(CTPageTransition)transition foreground:(BOOL)foreground;
- (NSInteger) determineInsertionIndexForAppending;
- (NSInteger) determineNewSelectedIndexByRemovingIndex:(NSInteger)removing_index isRemove:(BOOL)is_remove;
- (NSInteger) validIndexForIndex:(NSInteger)index removingIndex:(NSInteger)removing_index isRemove:(BOOL)is_remove;

@end


@implementation CTTabStripModel2 {
    CTTabStripModel* tabStripModel_;
    ObserverList<CTTabStripModelObserver> observers_;
}

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

- (void) setInsertionPolicy:(InsertionPolicy)insertionPolicy
{
    tabStripModel_->SetInsertionPolicy(insertionPolicy);
}

- (InsertionPolicy) insertionPolicy
{
    return tabStripModel_->insertion_policy();
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

- (CTTabContents*) tabContentsAtIndex:(NSInteger)index
{
    return tabStripModel_->GetTabContentsAt(index);
}

- (NSInteger) indexOfTabContents:(CTTabContents*)tabContents
{
    return tabStripModel_->GetIndexOfTabContents(tabContents);
}

- (CTTabContents*) selectedTabContents
{
    return tabStripModel_->GetSelectedTabContents();
}

- (BOOL) containsIndex:(NSInteger)index
{
    return index >= 0 && index < [self count];
}
    
- (void) selectTabContentsAtIndex:(NSInteger)index userGesture:(BOOL)userGesture
{
    tabStripModel_->SelectTabContentsAt(index, userGesture);
}

- (BOOL) closeTabContentsAtIndex:(NSInteger)index options:(NSInteger)options
{
    return tabStripModel_->CloseTabContentsAt(index, options);
}

- (NSInteger) indexOfFirstNonMiniTab
{
    return tabStripModel_->IndexOfFirstNonMiniTab();
}

- (BOOL) isMiniTabAtIndex:(NSInteger)index
{
    return tabStripModel_->IsMiniTab(index);
}

- (BOOL) isTabPinnedAtIndex:(NSInteger)index
{
    return tabStripModel_->IsTabPinned(index);
}

- (BOOL) isAppTabAtIndex:(NSInteger)index
{
    return tabStripModel_->IsAppTab(index);
}

- (BOOL) isPhantomTabAtIndex:(NSInteger)index
{
    return tabStripModel_->IsPhantomTab(index);
}

- (void) moveTabContentsFromIndex:(NSInteger)fromIndex toIndex:(NSInteger)toIndex selectAfterMove:(BOOL)selectedAfterMove
{
    tabStripModel_->MoveTabContentsAt(fromIndex, toIndex, selectedAfterMove);
}

- (void) insertTabContents:(CTTabContents*)contents atIndex:(NSInteger)index options:(NSInteger)options
{
    tabStripModel_->InsertTabContentsAt(index, contents, options);
}

- (void) updateTabContentsStateAtIndex:(NSInteger)index changeType:(CTTabChangeType)changeType
{
    tabStripModel_->UpdateTabContentsStateAt(index, changeType);
}

- (void) replaceTabContentsAtIndex:(NSInteger)index withContents:contents replaceType:(CTTabReplaceType)replaceType
{
    tabStripModel_->ReplaceTabContentsAt(index, contents, replaceType);
}

- (void) closeAllTabs
{
    tabStripModel_->CloseAllTabs();
}

- (NSInteger) addTabContents:(CTTabContents*)contents atIndex:(NSInteger)index withPageTransition:(CTPageTransition)pageTransition options:(NSInteger)options
{
    return tabStripModel_->AddTabContents(contents, index, pageTransition, options);
}

- (void) selectNextTab
{
    tabStripModel_->SelectNextTab();
}

- (void) selectPreviousTab
{
    tabStripModel_->SelectPreviousTab();
}

- (void) moveTabNext
{
    tabStripModel_->MoveTabNext();
}

- (void) moveTabPrevious
{
    tabStripModel_->MoveTabPrevious();
}

- (void) selectLastTab
{
    tabStripModel_->SelectLastTab();
}

- (void) appendTabContents:(CTTabContents*)contents foreground:(BOOL)foreground
{
    int index = [self determineInsertionIndexForAppending];
    [self insertTabContents:contents atIndex:index options:foreground ? (ADD_INHERIT_GROUP | ADD_SELECTED) : ADD_NONE];
}

- (void) detachTabContentsAtIndex:(NSInteger)index
{
    tabStripModel_->DetachTabContentsAt(index);
}

// Model Order Controller Functions

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
