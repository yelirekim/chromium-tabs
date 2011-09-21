#import <ApplicationServices/ApplicationServices.h>

#import "BackgroundGradientView.h"

typedef enum {
  kAlertNone = 0,
  kAlertRising,
  kAlertHolding,
  kAlertFalling
} AlertState;

@class CTTabViewController;
@class CTTabWindowController;

@interface CTTabView : BackgroundGradientView

@property(assign, nonatomic) NSCellStateValue state;
@property(assign, nonatomic) CGFloat hoverAlpha;
@property(assign, nonatomic) CGFloat alertAlpha;
@property(assign, nonatomic, getter=isClosing) BOOL closing;

- (void)setTrackingEnabled:(BOOL)enabled;
- (void)startAlert;
- (void)cancelAlert;

@end

@interface CTTabView (TabControllerInterface)
- (void)setController:(CTTabViewController*)controller;
- (CTTabViewController*)controller;
@end
