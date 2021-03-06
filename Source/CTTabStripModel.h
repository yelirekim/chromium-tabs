#import "CTTabStripModelDelegate.h"

typedef enum {
    INSERT_AFTER,
    INSERT_BEFORE,
} InsertionPolicy;

typedef enum {
    CLOSE_NONE                     = 0,
    CLOSE_USER_GESTURE             = 1 << 0,
    CLOSE_CREATE_HISTORICAL_TAB    = 1 << 1,
} CloseTypes;

typedef enum {
    ADD_NONE          = 0,
    ADD_SELECTED      = 1 << 0,
    ADD_PINNED        = 1 << 1,
    ADD_FORCE_INDEX   = 1 << 2,
    ADD_INHERIT_GROUP = 1 << 3,
    ADD_INHERIT_OPENER = 1 << 4,
} AddTabTypes;

typedef enum {
    CTTabChangeTypeLoadingOnly,
    CTTabChangeTypeTitleNotLoading,
    CTTabChangeTypeAll
} CTTabChangeType;

typedef enum {
    REPLACE_MADE_PHANTOM,
    REPLACE_MATCH_PREVIEW
} CTTabReplaceType;

@class CTTabContents;

@interface CTTabStripModel : NSObject

@property (nonatomic) InsertionPolicy insertionPolicy;
@property (nonatomic) NSInteger selectedIndex;

- (id) initWithDelegate:(NSObject<CTTabStripModelDelegate>*)delegate;

- (NSInteger) count;
- (CTTabContents*) tabContentsAtIndex:(NSInteger)index;
- (NSInteger) indexOfTabContents:(CTTabContents*)tabContents;
- (CTTabContents*) selectedTabContents;
- (BOOL) containsIndex:(NSInteger)index;
- (void) selectTabContentsAtIndex:(NSInteger)index userGesture:(BOOL)userGesture;
- (BOOL) closeTabContentsAtIndex:(NSInteger)index options:(NSInteger)options;
- (void) moveTabContentsFromIndex:(NSInteger)fromIndex toIndex:(NSInteger)toIndex selectAfterMove:(BOOL)selectedAfterMove;
- (void) insertTabContents:(CTTabContents*)contents atIndex:(NSInteger)index options:(NSInteger)options;
- (void) updateTabContentsStateAtIndex:(NSInteger)index changeType:(CTTabChangeType)changeType;
- (void) replaceTabContentsAtIndex:(NSInteger)index withContents:contents replaceType:(CTTabReplaceType)replaceType;
- (void) closeAllTabs;
- (NSInteger) addTabContents:(CTTabContents*)contents atIndex:(NSInteger)index options:(NSInteger)options;
- (void) selectNextTab;
- (void) selectPreviousTab;
- (void) moveTabNext;
- (void) moveTabPrevious;
- (void) selectLastTab;
- (void) appendTabContents:(CTTabContents*)contents foreground:(BOOL)foreground;
- (CTTabContents*) detachTabContentsAtIndex:(NSInteger)index;
- (void) closeSelectedTab;

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
extern NSString* const kCTTabStripEmptyNotification;
extern NSString* const kCTTabStripModelDeletedNotification;

extern NSString* const kCTTabContentsUserInfoKey;
extern NSString* const kCTTabNewContentsUserInfoKey;
extern NSString* const kCTTabIndexUserInfoKey;
extern NSString* const kCTTabToIndexUserInfoKey;
extern NSString* const kCTTabForegroundUserInfoKey;
extern NSString* const kCTTabOptionsUserInfoKey;

extern const int kNoTab;
