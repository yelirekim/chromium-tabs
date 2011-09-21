
@protocol ThrobberDataDelegate;

@interface ThrobberView : NSView

+ (id)filmstripThrobberViewWithFrame:(NSRect)frame image:(NSImage*)image;
+ (id)toastThrobberViewWithFrame:(NSRect)frame beforeImage:(NSImage*)beforeImage afterImage:(NSImage*)afterImage;

@end
