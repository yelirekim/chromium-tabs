#import "CTBrowserWindow.h"
#import "CTBrowserWindowController.h"
#import "CTTabStripController.h"
const CGFloat kWindowGradientHeight = 24.0;

@interface CTBrowserWindow(CTBrowserWindowPrivateMethods)
- (NSView*)frameView;
@end

@interface NSButton (_NSThemeCloseWidget)
- (void)setDocumentEdited:(BOOL)arg1;
@end

@implementation CTBrowserWindow {
    BOOL shouldHideTitle_;
    NSButton* closeButton_;
    NSButton* miniaturizeButton_;
    NSButton* zoomButton_;
    BOOL entered_;
    NSTrackingArea* widgetTrackingArea_;
}

- (id)initWithContentRect:(NSRect)contentRect
                styleMask:(NSUInteger)aStyle
                  backing:(NSBackingStoreType)bufferingType
                    defer:(BOOL)flag {
  if ((self = [super initWithContentRect:contentRect
                               styleMask:aStyle
                                 backing:bufferingType
                                   defer:flag])) {
    if (aStyle & NSTexturedBackgroundWindowMask) {
      [self setAutorecalculatesContentBorderThickness:NO forEdge:NSMaxYEdge];
      [self setContentBorderThickness:kWindowGradientHeight forEdge:NSMaxYEdge];
    }
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
  if (widgetTrackingArea_) {
    [[self frameView] removeTrackingArea:widgetTrackingArea_];
    widgetTrackingArea_ = nil;
  }
}

- (void)setWindowController:(NSWindowController*)controller {
  if (controller == [self windowController]) {
    return;
  }
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
  [closeButton_ removeFromSuperview];
  closeButton_ = nil;
  [miniaturizeButton_ removeFromSuperview];
  miniaturizeButton_ = nil;
  [zoomButton_ removeFromSuperview];
  zoomButton_ = nil;

  [super setWindowController:controller];

  CTBrowserWindowController* browserController = (CTBrowserWindowController*)controller;
  if ([browserController isKindOfClass:[CTBrowserWindowController class]]) {
    NSDistributedNotificationCenter* distCenter =
        [NSDistributedNotificationCenter defaultCenter];
    [distCenter addObserver:self
                   selector:@selector(systemThemeDidChangeNotification:)
                       name:@"AppleAquaColorVariantChanged"
                     object:nil];
    NSView* frameView = [self frameView];
    NSRect frameViewBounds = [frameView bounds];

    NSButton* oldButton = [self standardWindowButton:NSWindowCloseButton];
    [oldButton setHidden:YES];
    oldButton = [self standardWindowButton:NSWindowMiniaturizeButton];
    [oldButton setHidden:YES];
    oldButton = [self standardWindowButton:NSWindowZoomButton];
    [oldButton setHidden:YES];

    NSUInteger aStyle = [self styleMask];
    closeButton_ = [NSWindow standardWindowButton:NSWindowCloseButton
                                     forStyleMask:aStyle];
    NSRect closeButtonFrame = [closeButton_ frame];
    CGFloat yOffset = [browserController hasTabStrip] ?
        CTWindowButtonsWithTabStripOffsetFromTop :
        CTWindowButtonsWithoutTabStripOffsetFromTop;
    closeButtonFrame.origin =
        NSMakePoint(CTWindowButtonsOffsetFromLeft,
                    (NSHeight(frameViewBounds) -
                     NSHeight(closeButtonFrame) - yOffset));

    [closeButton_ setFrame:closeButtonFrame];
    [closeButton_ setTarget:self];
    [closeButton_ setAutoresizingMask:NSViewMaxXMargin | NSViewMinYMargin];
    [frameView addSubview:closeButton_];

    miniaturizeButton_ =
        [NSWindow standardWindowButton:NSWindowMiniaturizeButton
                          forStyleMask:aStyle];
    NSRect miniaturizeButtonFrame = [miniaturizeButton_ frame];
    miniaturizeButtonFrame.origin =
        NSMakePoint((NSMaxX(closeButtonFrame) +
                     CTWindowButtonsInterButtonSpacing),
                    NSMinY(closeButtonFrame));
    [miniaturizeButton_ setFrame:miniaturizeButtonFrame];
    [miniaturizeButton_ setTarget:self];
    [miniaturizeButton_ setAutoresizingMask:(NSViewMaxXMargin |
                                             NSViewMinYMargin)];
    [frameView addSubview:miniaturizeButton_];

    zoomButton_ = [NSWindow standardWindowButton:NSWindowZoomButton
                                    forStyleMask:aStyle];
    NSRect zoomButtonFrame = [zoomButton_ frame];
    zoomButtonFrame.origin =
        NSMakePoint((NSMaxX(miniaturizeButtonFrame) +
                     CTWindowButtonsInterButtonSpacing),
                    NSMinY(miniaturizeButtonFrame));
    [zoomButton_ setFrame:zoomButtonFrame];
    [zoomButton_ setTarget:self];
    [zoomButton_ setAutoresizingMask:(NSViewMaxXMargin |
                                      NSViewMinYMargin)];

    [frameView addSubview:zoomButton_];
  }

  [self updateTrackingAreas];
}

- (NSView*)frameView {
  return [[self contentView] superview];
}

- (id)accessibilityHitTest:(NSPoint)point {
  NSPoint windowPoint = [self convertScreenToBase:point];
  NSControl* controls[] = { closeButton_, zoomButton_, miniaturizeButton_ };
  id value = nil;
  for (size_t i = 0; i < sizeof(controls) / sizeof(controls[0]); ++i) {
    if (NSPointInRect(windowPoint, [controls[i] frame])) {
      value = [controls[i] accessibilityHitTest:point];
      break;
    }
  }
  if (!value) {
    value = [super accessibilityHitTest:point];
  }
  return value;
}

- (id)accessibilityAttributeValue:(NSString*)attribute {
  id value = nil;
    NSDictionary* cellByAttribute = [NSDictionary dictionaryWithObjectsAndKeys:
        [closeButton_ cell], NSAccessibilityCloseButtonAttribute,
        [zoomButton_ cell], NSAccessibilityZoomButtonAttribute,
        [miniaturizeButton_ cell], NSAccessibilityMinimizeButtonAttribute,
        nil];

  for (NSString* dictAttribute in cellByAttribute) {
    if ([dictAttribute isEqualToString:attribute]) {
      value = [cellByAttribute objectForKey:dictAttribute];
      break;
    }
  }
  if (!value) {
    value = [super accessibilityAttributeValue:attribute];
  }
  return value;
}

- (void)updateTrackingAreas {
  NSView* frameView = [self frameView];
  if (widgetTrackingArea_) {
    [frameView removeTrackingArea:widgetTrackingArea_];
  }
  if (closeButton_) {
    NSRect trackingRect = [closeButton_ frame];
    trackingRect.size.width = NSMaxX([zoomButton_ frame]) -
        NSMinX(trackingRect);
    widgetTrackingArea_ =
        [[NSTrackingArea alloc] initWithRect:trackingRect
                                     options:(NSTrackingMouseEnteredAndExited |
                                              NSTrackingActiveAlways)
                                       owner:self
                                    userInfo:nil];
    [frameView addTrackingArea:widgetTrackingArea_];

    NSPoint point = [self mouseLocationOutsideOfEventStream];
    point = [[self contentView] convertPoint:point fromView:nil];
    BOOL newEntered = NSPointInRect (point, trackingRect);
    if (newEntered != entered_) {
      entered_ = newEntered;
      [closeButton_ setNeedsDisplay];
      [zoomButton_ setNeedsDisplay];
      [miniaturizeButton_ setNeedsDisplay];
    }
  }
}

- (void)windowMainStatusChanged {
  [closeButton_ setNeedsDisplay];
  [zoomButton_ setNeedsDisplay];
  [miniaturizeButton_ setNeedsDisplay];
  NSView* frameView = [self frameView];
  NSView* contentView = [self contentView];
  NSRect updateRect = [frameView frame];
  NSRect contentRect = [contentView frame];
  CGFloat tabStripHeight = [CTTabStripController defaultTabHeight];
  updateRect.size.height -= NSHeight(contentRect) - tabStripHeight;
  updateRect.origin.y = NSMaxY(contentRect) - tabStripHeight;
  [[self frameView] setNeedsDisplayInRect:updateRect];
}

- (void)becomeMainWindow {
  [self windowMainStatusChanged];
  [super becomeMainWindow];
}

- (void)resignMainWindow {
  [self windowMainStatusChanged];
  [super resignMainWindow];
}

- (void)themeDidChangeNotification:(NSNotification*)aNotification {
  [[self frameView] setNeedsDisplay:YES];
}

- (void)systemThemeDidChangeNotification:(NSNotification*)aNotification {
  [closeButton_ setNeedsDisplay];
  [zoomButton_ setNeedsDisplay];
  [miniaturizeButton_ setNeedsDisplay];
}

- (void)sendEvent:(NSEvent*)event {
  BOOL eventHandled = NO;
  if (![self isMainWindow]) {
    if ([event type] == NSLeftMouseDown) {
      NSView* frameView = [self frameView];
      NSPoint mouse = [frameView convertPoint:[event locationInWindow]
                                     fromView:nil];
      if (NSPointInRect(mouse, [closeButton_ frame])) {
        [closeButton_ mouseDown:event];
        eventHandled = YES;
      } else if (NSPointInRect(mouse, [miniaturizeButton_ frame])) {
        [miniaturizeButton_ mouseDown:event];
        eventHandled = YES;
      }
    }
  }
  if (!eventHandled) {
    [super sendEvent:event];
  }
}

- (void)mouseEntered:(NSEvent*)event {
  entered_ = YES;
  [closeButton_ setNeedsDisplay];
  [zoomButton_ setNeedsDisplay];
  [miniaturizeButton_ setNeedsDisplay];
}

- (void)mouseExited:(NSEvent*)event {
  entered_ = NO;
  [closeButton_ setNeedsDisplay];
  [zoomButton_ setNeedsDisplay];
  [miniaturizeButton_ setNeedsDisplay];
}

- (BOOL)mouseInGroup:(NSButton*)widget {
  return entered_;
}

- (void)setShouldHideTitle:(BOOL)flag {
  shouldHideTitle_ = flag;
}

-(BOOL)_isTitleHidden {
  return shouldHideTitle_;
}

- (NSRect)constrainFrameRect:(NSRect)frame toScreen:(NSScreen*)screen {
  id delegate = [self delegate];
  if ([delegate respondsToSelector:@selector(shouldConstrainFrameRect)] &&
      ![delegate shouldConstrainFrameRect])
    return frame;
  return [super constrainFrameRect:frame toScreen:screen];
}

- (NSPoint)themePatternPhase {
  id delegate = [self delegate];
  if (![delegate respondsToSelector:@selector(themePatternPhase)])
    return NSMakePoint(0, 0);
  return [delegate themePatternPhase];
}

- (void)setDocumentEdited:(BOOL)documentEdited {
  [super setDocumentEdited:documentEdited];
  [closeButton_ setDocumentEdited:documentEdited];
}

@end
