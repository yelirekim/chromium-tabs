#import "CTTabStripModel2.h"
#import "CTTabStripModel.h"

@implementation CTTabStripModel2 {
    CTTabStripModel* tabStripModel_;
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
}

- (void) removeObserver:(CTTabStripModelObserver*)observer
{
    tabStripModel_->RemoveObserver(observer);
}

- (BOOL) hasNonPhantomTabs
{
    return tabStripModel_->HasNonPhantomTabs();
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
    return tabStripModel_->ContainsIndex(index);
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

@end
