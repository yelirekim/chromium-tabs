#import "ThrobberView.h"

static const float kAnimationIntervalSeconds = 0.03;

@interface ThrobberView(PrivateMethods)
- (id)initWithFrame:(NSRect)frame delegate:(id<ThrobberDataDelegate>)delegate;
- (void)maintainTimer;
- (void)animate;
@end

@protocol ThrobberDataDelegate <NSObject>

- (BOOL)animationIsComplete;
- (void)drawFrameInRect:(NSRect)rect;
- (void)advanceFrame;

@end

@interface ThrobberFilmstripDelegate : NSObject<ThrobberDataDelegate> {
    NSImage* image_;
    unsigned int numFrames_;
    unsigned int animationFrame_;
}

- (id)initWithImage:(NSImage*)image;

@end

@implementation ThrobberFilmstripDelegate

- (id)initWithImage:(NSImage*)image {
    if (nil != (self = [super init])) {
        animationFrame_ = 0;
        
        NSSize imageSize = [image size];
        assert(imageSize.height && imageSize.width);
        if (!imageSize.height) {
            return nil;
        }
        assert((int)imageSize.width % (int)imageSize.height == 0);
        numFrames_ = (int)imageSize.width / (int)imageSize.height;
        assert(numFrames_);
        image_ = image;
    }
    return self;
}

- (BOOL)animationIsComplete {
    return NO;
}

- (void)drawFrameInRect:(NSRect)rect {
    float imageDimension = [image_ size].height;
    float xOffset = animationFrame_ * imageDimension;
    NSRect sourceImageRect =
    NSMakeRect(xOffset, 0, imageDimension, imageDimension);
    [image_ drawInRect:rect fromRect:sourceImageRect operation:NSCompositeSourceOver fraction:1.0];
}

- (void)advanceFrame {
    animationFrame_ = ++animationFrame_ % numFrames_;
}

@end

@interface ThrobberToastDelegate : NSObject <ThrobberDataDelegate> {
    NSImage* image1_;
    NSImage* image2_;
    NSSize image1Size_;
    NSSize image2Size_;
    int animationFrame_;
}

- (id)initWithImage1:(NSImage*)image1 image2:(NSImage*)image2;

@end

@implementation ThrobberToastDelegate

- (id)initWithImage1:(NSImage*)image1 image2:(NSImage*)image2 {
    if (nil != (self = [super init])) {
        image1_ = image1;
        image2_ = image2;
        image1Size_ = [image1 size];
        image2Size_ = [image2 size];
        animationFrame_ = 0;
    }
    return self;
}

- (BOOL)animationIsComplete {
    if (animationFrame_ >= image1Size_.height + image2Size_.height) {
        return YES;
    }
    
    return NO;
}

- (void)drawFrameInRect:(NSRect)rect {
    NSImage* image = nil;
    NSSize srcSize;
    NSRect destRect;
    
    if (animationFrame_ < image1Size_.height) {
        image = image1_;
        srcSize = image1Size_;
        destRect = NSMakeRect(0, -animationFrame_, image1Size_.width, image1Size_.height);
    } else if (animationFrame_ == image1Size_.height) {
        // nothing; intermediate blank frame
    } else {
        image = image2_;
        srcSize = image2Size_;
        destRect = NSMakeRect(0, animationFrame_ - (image1Size_.height + image2Size_.height), image2Size_.width, image2Size_.height);
    }
    
    if (image) {
        NSRect sourceImageRect =
        NSMakeRect(0, 0, srcSize.width, srcSize.height);
        [image drawInRect:destRect fromRect:sourceImageRect operation:NSCompositeSourceOver fraction:1.0];
    }
}

- (void)advanceFrame {
    ++animationFrame_;
}

@end

@interface ThrobberTimer : NSObject {
    NSMutableSet* throbbers_;
    NSTimer* timer_;
    BOOL timerRunning_;
    NSThread* validThread_;
}

+ (ThrobberTimer*)sharedThrobberTimer;

- (void)invalidate;
- (void)addThrobber:(ThrobberView*)throbber;
- (void)removeThrobber:(ThrobberView*)throbber;

@end

@interface ThrobberTimer(PrivateMethods)
- (void)maintainTimer;
- (void)fire:(NSTimer*)timer;
@end

@implementation ThrobberTimer
- (id)init {
    if (nil != (self = [super init])) {
        throbbers_ = [[NSMutableSet alloc] init];
        timer_ = [NSTimer scheduledTimerWithTimeInterval:kAnimationIntervalSeconds target:self selector:@selector(fire:) userInfo:nil repeats:YES];
        [timer_ setFireDate:[NSDate distantFuture]];
        timerRunning_ = NO;
        
        validThread_ = [NSThread currentThread];
    }
    return self;
}

+ (ThrobberTimer*)sharedThrobberTimer {
    static ThrobberTimer* sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[ThrobberTimer alloc] init];
    });
    return sharedInstance;
}

- (void)invalidate {
    [timer_ invalidate];
}

- (void)addThrobber:(ThrobberView*)throbber {
    assert([NSThread currentThread] == validThread_);
    [throbbers_ addObject:throbber];
    [self maintainTimer];
}

- (void)removeThrobber:(ThrobberView*)throbber {
    assert([NSThread currentThread] == validThread_);
    [throbbers_ removeObject:throbber];
    [self maintainTimer];
}

- (void)maintainTimer {
    BOOL oldRunning = timerRunning_;
    BOOL newRunning = ![throbbers_ count] ? NO : YES;
    
    if (oldRunning == newRunning) {
        return;
    }
    
    NSDate* fireDate;
    if (newRunning) {
        fireDate = [NSDate dateWithTimeIntervalSinceNow:kAnimationIntervalSeconds];
    } else {
        fireDate = [NSDate distantFuture];
    }
    
    [timer_ setFireDate:fireDate];
    timerRunning_ = newRunning;
}

- (void)fire:(NSTimer*)timer 
{
    for (ThrobberView* throbber in throbbers_) {
        [throbber animate];
    }
}
@end

@implementation ThrobberView {
    id<ThrobberDataDelegate> dataDelegate_;
}

+ (id)filmstripThrobberViewWithFrame:(NSRect)frame
                               image:(NSImage*)image {
    ThrobberFilmstripDelegate* delegate = [[ThrobberFilmstripDelegate alloc] initWithImage:image];
    if (!delegate) {
        return nil;
    }
    
    return [[ThrobberView alloc] initWithFrame:frame delegate:delegate];
}

+ (id)toastThrobberViewWithFrame:(NSRect)frame beforeImage:(NSImage*)beforeImage afterImage:(NSImage*)afterImage {
    ThrobberToastDelegate* delegate = [[ThrobberToastDelegate alloc] initWithImage1:beforeImage image2:afterImage];
    if (!delegate) {
        return nil;
    }
    
    return [[ThrobberView alloc] initWithFrame:frame delegate:delegate];
}

- (id)initWithFrame:(NSRect)frame delegate:(id<ThrobberDataDelegate>)delegate {
    if (nil != (self = [super initWithFrame:frame])) {
        dataDelegate_ = delegate;
    }
    return self;
}

- (void)dealloc {
    [[ThrobberTimer sharedThrobberTimer] removeThrobber:self];
    
}

- (void)maintainTimer {
    ThrobberTimer* throbberTimer = [ThrobberTimer sharedThrobberTimer];
    
    if ([self window] && ![self isHidden] && ![dataDelegate_ animationIsComplete]) {
        [throbberTimer addThrobber:self];
    } else {
        [throbberTimer removeThrobber:self];
    }
}

- (void)viewDidMoveToWindow {
    [self maintainTimer];
    [super viewDidMoveToWindow];
}

- (void)viewDidHide {
    [self maintainTimer];
    [super viewDidHide];
}

- (void)viewDidUnhide {
    [self maintainTimer];
    [super viewDidUnhide];
}

- (void)animate {
    [dataDelegate_ advanceFrame];
    [self setNeedsDisplay:YES];
    
    if ([dataDelegate_ animationIsComplete]) {
        [[ThrobberTimer sharedThrobberTimer] removeThrobber:self];
    }
}

- (void)drawRect:(NSRect)rect {
    [dataDelegate_ drawFrameInRect:[self bounds]];
}

@end
