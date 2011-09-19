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

///////////////////////////////////////////////////////////////////////////////
// CTTabStripModelDelegate, public:

/*bool CTTabStripModelDelegate::CanCloseTab() const {
 return true;
 }*/

///////////////////////////////////////////////////////////////////////////////
// TabStripModel, public:

CTTabStripModel::CTTabStripModel(NSObject<CTTabStripModelDelegate>* delegate)
: selected_index_(kNoTab),
closing_all_(false),
order_controller_(NULL) {
    delegate_ = delegate; // weak
    // TODO replace with nsnotificationcenter?
    /*registrar_.Add(this,
     NotificationType::TAB_CONTENTS_DESTROYED,
     NotificationService::AllSources());
     registrar_.Add(this,
     NotificationType::EXTENSION_UNLOADED);*/
    order_controller_ = new CTTabStripModelOrderController(this);
    contents_data_ = [NSMutableArray array];
}

CTTabStripModel::~CTTabStripModel() {
    FOR_EACH_OBSERVER(CTTabStripModelObserver, observers_,
                      TabStripModelDeleted());
    
    delegate_ = NULL; // weak
    
    // Before deleting any phantom tabs remove our notification observers so that
    // we don't attempt to notify our delegate or do any processing.
    //TODO: replace with nsnotificationcenter unregs
    //registrar_.RemoveAll();
    
    // Phantom tabs still have valid TabConents that we own and need to delete.
    /*for (int i = count() - 1; i >= 0; --i) {
     if (IsPhantomTab(i))
     delete contents_data_[i]->contents;
     }*/
    
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
    /*for (int i = 0; i < count(); i++) {
     if (!IsPhantomTab(i))
     return true;
     }
     return false;*/
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
void CTTabStripModel::SelectTabContentsAt(int index, bool user_gesture) {
    if (ContainsIndex(index)) {
        ChangeSelectedContentsFrom(GetSelectedTabContents(), index, user_gesture);
    } else {
        DLOG("[ChromiumTabs] internal inconsistency: !ContainsIndex(index) in %s",
             __PRETTY_FUNCTION__);
    }
}
//DONE
CTTabContents* CTTabStripModel::GetSelectedTabContents() const {
    return GetTabContentsAt(selected_index_);
}
//DONE
CTTabContents* CTTabStripModel::GetTabContentsAt(int index) const {
    if (ContainsIndex(index))
        return GetContentsAt(index);
    return NULL;
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

/*int TabStripModel::GetIndexOfController(
 const NavigationController* controller) const {
 int index = 0;
 TabContentsDataVector::const_iterator iter = contents_data_.begin();
 for (; iter != contents_data_.end(); ++iter, ++index) {
 if (&(*iter)->contents->controller() == controller)
 return index;
 }
 return kNoTab;
 }*/
//DONE
bool CTTabStripModel::CloseTabContentsAt(int index, uint32 close_types) {
    NSMutableArray* closing_tabs = [NSMutableArray array];
    [closing_tabs addObject:[NSNumber numberWithInt:index]];
    return InternalCloseTabs(closing_tabs, close_types);
}

void CTTabStripModel::SetTabPinned(int index, bool pinned) {
    assert(ContainsIndex(index));
    TabContentsData* data = [contents_data_ objectAtIndex:index];
    if (data->pinned == pinned)
        return;
    
    if (IsAppTab(index)) {
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
        int non_mini_tab_index = IndexOfFirstNonMiniTab();
        data->pinned = pinned;
        if (pinned && index != non_mini_tab_index) {
            MoveTabContentsAtImpl(index, non_mini_tab_index, false);
            return;  // Don't send TabPinnedStateChanged notification.
        } else if (!pinned && index + 1 != non_mini_tab_index) {
            MoveTabContentsAtImpl(index, non_mini_tab_index - 1, false);
            return;  // Don't send TabPinnedStateChanged notification.
        }
        
        
        FOR_EACH_OBSERVER(CTTabStripModelObserver, observers_,
                          TabMiniStateChanged(data->contents,
                                              index));
    }
    
    // else: the tab was at the boundary and it's position doesn't need to
    // change.
    FOR_EACH_OBSERVER(CTTabStripModelObserver, observers_,
                      TabPinnedStateChanged(data->contents,
                                            index));
}
//DONE
bool CTTabStripModel::IsTabPinned(int index) const {
    TabContentsData* data = [contents_data_ objectAtIndex:index];
    return data->pinned;
}
//DONE
bool CTTabStripModel::IsMiniTab(int index) const {
    return IsTabPinned(index) || IsAppTab(index);
}
//DONE
bool CTTabStripModel::IsAppTab(int index) const {
    CTTabContents* contents = GetTabContentsAt(index);
    return contents && contents.isApp;
}
//DONE
bool CTTabStripModel::IsPhantomTab(int index) const {
    /*return IsTabPinned(index) &&
     GetTabContentsAt(index)->controller().needs_reload();*/
    return false;
}
//DONE
int CTTabStripModel::IndexOfFirstNonMiniTab() const {
    for (size_t i = 0; i < contents_data_.count; ++i) {
        if (!IsMiniTab(static_cast<int>(i)))
            return static_cast<int>(i);
    }
    // No mini-tabs.
    return count();
}

NSArray* CTTabStripModel::GetIndicesClosedByCommand(
                                                            int index,
                                                            ContextMenuCommand id) const {
    assert(ContainsIndex(index));
    
    // NOTE: some callers assume indices are sorted in reverse order.
    NSMutableArray* indices = [NSMutableArray array];
    
    if (id != CommandCloseTabsToRight && id != CommandCloseOtherTabs)
        return indices;
    
    int start = (id == CommandCloseTabsToRight) ? index + 1 : 0;
    for (int i = count() - 1; i >= start; --i) {
        if (i != index && !IsMiniTab(i))
            [indices addObject:[NSNumber numberWithInt:i]];
    }
    return indices;
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

bool CTTabStripModel::IsNewTabAtEndOfTabStrip(CTTabContents* contents) const {
    return !contents || contents == GetContentsAt(count() - 1);
    /*return LowerCaseEqualsASCII(contents->GetURL().spec(),
     chrome::kChromeUINewTabURL) &&
     contents == GetContentsAt(count() - 1) &&
     contents->controller().entry_count() == 1;*/
}

bool CTTabStripModel::InternalCloseTabs(NSArray* indices,
                                        uint32 close_types) {
    bool retval = true;
    
    // We now return to our regularly scheduled shutdown procedure.
    for (size_t i = 0; i < indices.count; ++i) {
        CTTabContents* detached_contents = GetContentsAt([[indices objectAtIndex:i] intValue]);
        [detached_contents closingOfTabDidStart:this]; // TODO notification
        
        if (![delegate_ canCloseContentsAt:[[indices objectAtIndex:i] intValue]]) {
            retval = false;
            continue;
        }
        
        // Update the explicitly closed state. If the unload handlers cancel the
        // close the state is reset in CTBrowser. We don't update the explicitly
        // closed state if already marked as explicitly closed as unload handlers
        // call back to this if the close is allowed.
        if (!detached_contents.closedByUserGesture) {
            detached_contents.closedByUserGesture = close_types & CLOSE_USER_GESTURE;
        }
        
        //if (delegate_->RunUnloadListenerBeforeClosing(detached_contents)) {
        if ([delegate_ runUnloadListenerBeforeClosing:detached_contents]) {
            retval = false;
            continue;
        }
        
        InternalCloseTab(detached_contents, [[indices objectAtIndex:i] intValue],
                         (close_types & CLOSE_CREATE_HISTORICAL_TAB) != 0);
    }
    
    return retval;
}

void CTTabStripModel::InternalCloseTab(CTTabContents* contents,
                                       int index,
                                       bool create_historical_tabs) {
    FOR_EACH_OBSERVER(CTTabStripModelObserver, observers_,
                      TabClosingAt(contents, index));
    
    // Ask the delegate to save an entry for this tab in the historical tab
    // database if applicable.
    if (create_historical_tabs) {
        [delegate_ createHistoricalTab:contents];
        //delegate_->CreateHistoricalTab(contents);
    }
    
    // Deleting the CTTabContents will call back to us via NotificationObserver
    // and detach it.
    [contents destroy:this];
}
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

void CTTabStripModel::SelectRelativeTab(bool next) {
    // This may happen during automated testing or if a user somehow buffers
    // many key accelerators.
    if (contents_data_.count == 0)
        return;
    
    // Skip pinned-app-phantom tabs when iterating.
    int index = selected_index_;
    int delta = next ? 1 : -1;
    do {
        index = (index + count() + delta) % count();
    } while (index != selected_index_ && IsPhantomTab(index));
    SelectTabContentsAt(index, true);
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

const bool kPhantomTabsEnabled = false;

bool CTTabStripModel::ShouldMakePhantomOnClose(int index) {
    if (kPhantomTabsEnabled && IsTabPinned(index) && !IsPhantomTab(index) &&
        !closing_all_) {
        if (!IsAppTab(index))
            return true;  // Always make non-app tabs go phantom.
        
        //ExtensionsService* extension_service = profile()->GetExtensionsService();
        //if (!extension_service)
        return false;
        
        //Extension* extension_app = GetTabContentsAt(index)->extension_app();
        //assert(extension_app);
        
        // Only allow the tab to be made phantom if the extension still exists.
        //return extension_service->GetExtensionById(extension_app->id(),
        //                                           false) != NULL;
    }
    return false;
}


void CTTabStripModel::MoveTabContentsAtImpl(int index, int to_position,
                                            bool select_after_move) {
    TabContentsData* moved_data = [contents_data_ objectAtIndex:index];
    [contents_data_ removeObjectAtIndex:index];
    [contents_data_ insertObject:moved_data atIndex:to_position];
    
    // if !select_after_move, keep the same tab selected as was selected before.
    if (select_after_move || index == selected_index_) {
        selected_index_ = to_position;
    } else if (index < selected_index_ && to_position >= selected_index_) {
        selected_index_--;
    } else if (index > selected_index_ && to_position <= selected_index_) {
        selected_index_++;
    }
    
    FOR_EACH_OBSERVER(CTTabStripModelObserver, observers_,
                      TabMoved(moved_data->contents, index, to_position));
}
//DONE
CTTabContents* CTTabStripModel::ReplaceTabContentsAtImpl(
                                                         int index,
                                                         CTTabContents* new_contents,
                                                         CTTabReplaceType type) {
    assert(ContainsIndex(index));
    CTTabContents* old_contents = GetContentsAt(index);
    TabContentsData* data = [contents_data_ objectAtIndex:index];
    data->contents = new_contents;
    FOR_EACH_OBSERVER(CTTabStripModelObserver, observers_,
                      TabReplacedAt(old_contents, new_contents, index, type));
    return old_contents;
}
