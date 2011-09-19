// Copyright (c) 2010 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE-chromium file.

#import "CTTabStripModel.h"

#import <algorithm>

#import "stl_util-inl.h"
#import "CTTabStripModelOrderController.h"
#import "CTPageTransition.h"
#import "CTTabContents.h"


@implementation TabContentsData

@end

///////////////////////////////////////////////////////////////////////////////
// TabStripModelObserver, public:
void CTTabStripModelObserver::TabInsertedAt(CTTabContents* contents,
                                            int index,
                                            bool foreground) {
}

void CTTabStripModelObserver::TabClosingAt(CTTabContents* contents, int index) {
}

void CTTabStripModelObserver::TabDetachedAt(CTTabContents* contents, int index) {
}

void CTTabStripModelObserver::TabDeselectedAt(CTTabContents* contents, int index) {
}

void CTTabStripModelObserver::TabSelectedAt(CTTabContents* old_contents,
                                            CTTabContents* new_contents,
                                            int index,
                                            bool user_gesture) {
}

void CTTabStripModelObserver::TabMoved(CTTabContents* contents,
                                       int from_index,
                                       int to_index) {
}

void CTTabStripModelObserver::TabChangedAt(CTTabContents* contents, int index,
                                           CTTabChangeType change_type) {
}

void CTTabStripModelObserver::TabReplacedAt(CTTabContents* old_contents,
                                            CTTabContents* new_contents,
                                            int index) {
}

void CTTabStripModelObserver::TabReplacedAt(CTTabContents* old_contents,
                                            CTTabContents* new_contents,
                                            int index,
                                            CTTabReplaceType type) {
    TabReplacedAt(old_contents, new_contents, index);
}

void CTTabStripModelObserver::TabPinnedStateChanged(CTTabContents* contents,
                                                    int index) {
}

void CTTabStripModelObserver::TabMiniStateChanged(CTTabContents* contents,
                                                  int index) {
}

void CTTabStripModelObserver::TabBlockedStateChanged(CTTabContents* contents,
                                                     int index) {
}

void CTTabStripModelObserver::TabStripEmpty() {}

void CTTabStripModelObserver::TabStripModelDeleted() {}

CTTabStripModel::CTTabStripModel(NSObject<CTTabStripModelDelegate>* delegate)
: selected_index_(kNoTab),
closing_all_(false),
order_controller_(NULL) {
    delegate_ = delegate;
    order_controller_ = new CTTabStripModelOrderController(this);
    contents_data_ = [NSMutableArray array];
}

CTTabStripModel::~CTTabStripModel() {
    FOR_EACH_OBSERVER(CTTabStripModelObserver, observers_,
                      TabStripModelDeleted());
    
    delegate_ = NULL;
    
    delete order_controller_;
}
//DONE
void CTTabStripModel::AddObserver(CTTabStripModelObserver* observer) {
    observers_.AddObserver(observer);
}
//DONE
void CTTabStripModel::RemoveObserver(CTTabStripModelObserver* observer) {
    observers_.RemoveObserver(observer);
}
//DONE
bool CTTabStripModel::HasNonPhantomTabs() const {
    return !!count();
}
//DONE
void CTTabStripModel::SetInsertionPolicy(InsertionPolicy policy) {
    order_controller_->set_insertion_policy(policy);
}
//DONE
InsertionPolicy CTTabStripModel::insertion_policy() const {
    return order_controller_->insertion_policy();
}
//DONE
bool CTTabStripModel::HasObserver(CTTabStripModelObserver* observer) {
    return observers_.HasObserver(observer);
}
//DONE
bool CTTabStripModel::ContainsIndex(int index) const {
    return index >= 0 && index < count();
}
//DONE
CTTabContents* CTTabStripModel::DetachTabContentsAt(int index) {
    if (contents_data_.count == 0)
        return NULL;
    
    assert(ContainsIndex(index));
    
    CTTabContents* removed_contents = GetContentsAt(index);
    int next_selected_index =
    order_controller_->DetermineNewSelectedIndex(index, true);
    [contents_data_ removeObjectAtIndex:index];
    next_selected_index = IndexOfNextNonPhantomTab(next_selected_index, -1);
    if (!HasNonPhantomTabs())
        closing_all_ = true;
    TabStripModelObservers::Iterator iter(observers_);
    while (CTTabStripModelObserver* obs = iter.GetNext()) {
        obs->TabDetachedAt(removed_contents, index);
        if (!HasNonPhantomTabs())
            obs->TabStripEmpty();
    }
    if (HasNonPhantomTabs()) {
        if (index == selected_index_) {
            ChangeSelectedContentsFrom(removed_contents, next_selected_index, false);
        } else if (index < selected_index_) {
            // The selected tab didn't change, but its position shifted; update our
            // index to continue to point at it.
            --selected_index_;
        }
    }
    return removed_contents;
}
//DONE
int CTTabStripModel::GetIndexOfTabContents(const CTTabContents* contents) const {
    int index = 0;
    for (TabContentsData* data in contents_data_) {
        if (data->contents == contents) {
            return index;
        }
        index++;
    }
    return kNoTab;
}
//DONE
bool CTTabStripModel::IsTabPinned(int index) const {
    TabContentsData* data = [contents_data_ objectAtIndex:index];
    return data->pinned;
}
//DONE
bool CTTabStripModel::IsPhantomTab(int index) const {
    return false;
}

///////////////////////////////////////////////////////////////////////////////
// TabStripModel, NotificationObserver implementation:

// TODO replace with NSNotification if possible
// Invoked by CTTabContents when they dealloc
void CTTabStripModel::TabContentsWasDestroyed(CTTabContents *contents) {
    // Sometimes, on qemu, it seems like a CTTabContents object can be destroyed
    // while we still have a reference to it. We need to break this reference
    // here so we don't crash later.
    int index = GetIndexOfTabContents(contents);
    if (index != CTTabStripModel::kNoTab) {
        // Note that we only detach the contents here, not close it - it's
        // already been closed. We just want to undo our bookkeeping.
        //if (ShouldMakePhantomOnClose(index)) {
        //  // We don't actually allow pinned tabs to close. Instead they become
        //  // phantom.
        //  MakePhantom(index);
        //} else {
        DetachTabContentsAt(index);
        //}
    }
}

///////////////////////////////////////////////////////////////////////////////
// TabStripModel, private:
//DONE
CTTabContents* CTTabStripModel::GetContentsAt(int index) const {
    assert(ContainsIndex(index));
    //<< "Failed to find: " << index << " in: " << count() << " entries.";
    TabContentsData* data = [contents_data_ objectAtIndex:index];
    return data->contents;
}
//DONE
void CTTabStripModel::ChangeSelectedContentsFrom(
                                                 CTTabContents* old_contents, int to_index, bool user_gesture) {
    assert(ContainsIndex(to_index));
    CTTabContents* new_contents = GetContentsAt(to_index);
    if (old_contents == new_contents)
        return;
    
    CTTabContents* last_selected_contents = old_contents;
    if (last_selected_contents) {
        FOR_EACH_OBSERVER(CTTabStripModelObserver, observers_,
                          TabDeselectedAt(last_selected_contents, selected_index_));
    }
    
    selected_index_ = to_index;
    FOR_EACH_OBSERVER(CTTabStripModelObserver, observers_,
                      TabSelectedAt(last_selected_contents, new_contents, selected_index_,
                                    user_gesture));
}
//DONE
int CTTabStripModel::IndexOfNextNonPhantomTab(int index,
                                              int ignore_index) {
    if (index == kNoTab)
        return kNoTab;
    
    if (empty())
        return index;
    
    index = std::min(count() - 1, std::max(0, index));
    int start = index;
    do {
        if (index != ignore_index && !IsPhantomTab(index))
            return index;
        index = (index + 1) % count();
    } while (index != start);
    
    // All phantom tabs.
    return start;
}

