#import <ApplicationServices/ApplicationServices.h>

#import "BackgroundGradientView.h"

typedef enum {
  kAlertNone = 0,
  kAlertRising,
  kAlertHolding,
  kAlertFalling
} AlertState;

typedef enum {
    kTabStyleShowLeft       = 0x01,
    kTabStyleShowRight      = 0x02,
    kTabStyleShowBoth       = 0x03,
} TabStyle;

@class CTTabViewController;
@class CTTabWindowController;

@interface CTTabView : BackgroundGradientView

@property(assign, nonatomic) NSCellStateValue state;
@property(assign, nonatomic) CGFloat hoverAlpha;
@property(assign, nonatomic) CGFloat alertAlpha;
@property(assign, nonatomic, getter=isClosing) BOOL closing;
@property(assign, nonatomic) TabStyle tabStyle;
@property(assign, nonatomic) TabStyle delayedTabStyle;
@property(assign, nonatomic) NSInteger tag;

- (void)setTrackingEnabled:(BOOL)enabled;
- (void)startAlert;
- (void)cancelAlert;

@end

@interface CTTabView (TabControllerInterface)
- (void)setController:(CTTabViewController*)controller;
- (CTTabViewController*)controller;
@end
