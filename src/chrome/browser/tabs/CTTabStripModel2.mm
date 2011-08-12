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

@end
