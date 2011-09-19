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
// TabStripModel, private:
//DONE
CTTabContents* CTTabStripModel::GetContentsAt(int index) const {
    assert(ContainsIndex(index));
    //<< "Failed to find: " << index << " in: " << count() << " entries.";
    TabContentsData* data = [contents_data_ objectAtIndex:index];
    return data->contents;
}

