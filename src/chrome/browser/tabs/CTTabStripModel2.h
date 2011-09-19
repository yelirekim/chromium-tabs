#import "CTPageTransition.h"

enum InsertionPolicy {
    INSERT_AFTER,
    INSERT_BEFORE,
};

enum CloseTypes {
    CLOSE_NONE                     = 0,
    CLOSE_USER_GESTURE             = 1 << 0,
    CLOSE_CREATE_HISTORICAL_TAB    = 1 << 1,
};

enum AddTabTypes {
    ADD_NONE          = 0,
    ADD_SELECTED      = 1 << 0,
    ADD_PINNED        = 1 << 1,
    ADD_FORCE_INDEX   = 1 << 2,
    ADD_INHERIT_GROUP = 1 << 3,
    ADD_INHERIT_OPENER = 1 << 4,
};

enum CTTabChangeType {
    CTTabChangeTypeLoadingOnly,
    CTTabChangeTypeTitleNotLoading,
    CTTabChangeTypeAll
};

enum CTTabReplaceType {
    REPLACE_MADE_PHANTOM,
    REPLACE_MATCH_PREVIEW
};

class CTTabStripModel;
class CTTabStripModelObserver;

@class CTTabContents;

@interface CTTabStripModel2 : NSObject

@property (nonatomic) InsertionPolicy insertionPolicy;
@property (nonatomic) NSInteger selectedIndex;

- (id) initWithPointer:(CTTabStripModel*)tabStripModel;

- (void) addObserver:(CTTabStripModelObserver*)observer;
- (void) removeObserver:(CTTabStripModelObserver*)observer;
- (BOOL) hasNonPhantomTabs;
- (BOOL) hasObserver:(CTTabStripModelObserver*)observer;
- (NSInteger) count;
- (CTTabContents*) tabContentsAtIndex:(NSInteger)index;
- (NSInteger) indexOfTabContents:(CTTabContents*)tabContents;
- (CTTabContents*) selectedTabContents;
- (BOOL) containsIndex:(NSInteger)index;
- (void) selectTabContentsAtIndex:(NSInteger)index userGesture:(BOOL)userGesture;
- (BOOL) closeTabContentsAtIndex:(NSInteger)index options:(NSInteger)options;
- (NSInteger) indexOfFirstNonMiniTab;
- (BOOL) isMiniTabAtIndex:(NSInteger)index;
- (BOOL) isTabPinnedAtIndex:(NSInteger)index;
- (BOOL) isAppTabAtIndex:(NSInteger)index;
- (BOOL) isPhantomTabAtIndex:(NSInteger)index;
- (void) moveTabContentsFromIndex:(NSInteger)fromIndex toIndex:(NSInteger)toIndex selectAfterMove:(BOOL)selectedAfterMove;
- (void) insertTabContents:(CTTabContents*)contents atIndex:(NSInteger)index options:(NSInteger)options;
- (void) updateTabContentsStateAtIndex:(NSInteger)index changeType:(CTTabChangeType)changeType;
- (void) replaceTabContentsAtIndex:(NSInteger)index withContents:contents replaceType:(CTTabReplaceType)replaceType;
- (void) closeAllTabs;
- (NSInteger) addTabContents:(CTTabContents*)contents atIndex:(NSInteger)index withPageTransition:(CTPageTransition)pageTransition options:(NSInteger)options;
- (void) selectNextTab;
- (void) selectPreviousTab;
- (void) moveTabNext;
- (void) moveTabPrevious;
- (void) selectLastTab;
- (void) appendTabContents:(CTTabContents*)contents foreground:(BOOL)foreground;
- (CTTabContents*) detachTabContentsAtIndex:(NSInteger)index;

@end


extern NSString* const kCTTabInsertedNotification;
extern NSString* const kCTTabClosingNotification;
extern NSString* const kCTTabDetachedNotification;
extern NSString* const kCTTabDeselectedNotification;
extern NSString* const kCTTabSelectedNotification;
extern NSString* const kCTTabMovedNotification;
extern NSString* const kCTTabChangedNotification;
extern NSString* const kCTTabReplacedNotification;
extern NSString* const kCTTabPinnedStateChangedNotification;
extern NSString* const kCTTabMiniStateChangedNotification;
extern NSString* const kCTTabBlockedStateChangedNotification;
extern NSString* const kCTTabStripEmptyNotification;
extern NSString* const kCTTabStripModelDeletedNotification;

extern NSString* const kCTTabContentsUserInfoKey;
extern NSString* const kCTTabIndexUserInfoKey;
extern NSString* const kCTTabForegroundUserInfoKey;