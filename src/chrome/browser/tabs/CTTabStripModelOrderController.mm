#import "CTTabStripModelOrderController.h"
#import "CTTabContents.h"


CTTabStripModelOrderController::CTTabStripModelOrderController(CTTabStripModel* tab_strip_model) : tabStripModel_(tab_strip_model), insertion_policy_(CTTabStripModel::INSERT_AFTER) 
{
    tabStripModel_->AddObserver(this);
}

CTTabStripModelOrderController::~CTTabStripModelOrderController() 
{
    tabStripModel_->RemoveObserver(this);
}

int CTTabStripModelOrderController::DetermineInsertionIndex(CTTabContents* new_contents, CTPageTransition transition, bool foreground) 
{
    int tab_count = tabStripModel_->count();
    if (!tab_count)
        return 0;
    
    if (transition == CTPageTransitionLink &&
        tabStripModel_->selected_index() != -1) {
        int delta = (insertion_policy_ == CTTabStripModel::INSERT_AFTER) ? 1 : 0;
        if (foreground) {
            return tabStripModel_->selected_index() + delta;
        }
        return tabStripModel_->selected_index() + delta;
    }

    return DetermineInsertionIndexForAppending();
}

int CTTabStripModelOrderController::DetermineInsertionIndexForAppending() 
{
    return (insertion_policy_ == CTTabStripModel::INSERT_AFTER) ?
    tabStripModel_->count() : 0;
}

int CTTabStripModelOrderController::DetermineNewSelectedIndex(int removing_index, bool is_remove) const 
{
    int tab_count = tabStripModel_->count();
    assert(removing_index >= 0 && removing_index < tab_count);
    
    CTTabContents* parentOpener =
    tabStripModel_->GetTabContentsAt(removing_index).parentOpener;
    if (parentOpener) {
        int index = tabStripModel_->GetIndexOfTabContents(parentOpener);
        if (index != CTTabStripModel::kNoTab)
            return GetValidIndex(index, removing_index, is_remove);
    }
    
    int selected_index = tabStripModel_->selected_index();
    if (is_remove && selected_index >= (tab_count - 1))
        return selected_index - 1;
    return selected_index;
}

void CTTabStripModelOrderController::TabSelectedAt(CTTabContents* old_contents, CTTabContents* new_contents, int index, bool user_gesture) 
{
}

int CTTabStripModelOrderController::GetValidIndex(int index, int removing_index, bool is_remove) const 
{
    if (is_remove && removing_index < index)
        index = std::max(0, index - 1);
    return index;
}
