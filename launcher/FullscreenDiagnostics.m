#import <AppKit/AppKit.h>
#import <QuartzCore/CAMetalLayer.h>

static void GRFSDumpMetalViews(NSView *view) {
    if ([view.layer isKindOfClass:CAMetalLayer.class]) {
        CAMetalLayer *layer=(CAMetalLayer *)view.layer;
        fprintf(stderr,"[GRFS fullscreen] Metal view=%s bounds=%s frame=%s drawable=%s scale=%.2f hidden=%d attached=%d\n",NSStringFromClass(view.class).UTF8String,NSStringFromRect(view.bounds).UTF8String,NSStringFromRect(view.frame).UTF8String,NSStringFromSize(NSSizeFromCGSize(layer.drawableSize)).UTF8String,layer.contentsScale,view.hidden,view.window!=nil);
    }
    for (NSView *child in view.subviews) GRFSDumpMetalViews(child);
}
@interface GRFSFullscreenDiagnostics : NSObject @end
@implementation GRFSFullscreenDiagnostics
+ (void)load {
    if (!getenv("GRFS_FULLSCREEN_TRACE")) return;
    dispatch_async(dispatch_get_main_queue(),^{
        for (NSString *name in @[NSWindowWillEnterFullScreenNotification,NSWindowDidEnterFullScreenNotification,NSWindowWillExitFullScreenNotification,NSWindowDidExitFullScreenNotification,NSWindowDidResizeNotification,NSWindowDidChangeBackingPropertiesNotification]) {
            [NSNotificationCenter.defaultCenter addObserverForName:name object:nil queue:nil usingBlock:^(NSNotification *note){
                NSWindow *window=note.object;
                fprintf(stderr,"[GRFS fullscreen] %s window=%s style=%lu visible=%d occluded=%d main=%d\n",note.name.UTF8String,NSStringFromRect(window.frame).UTF8String,(unsigned long)window.styleMask,window.visible,(window.occlusionState & NSWindowOcclusionStateVisible)==0,NSThread.isMainThread);
                GRFSDumpMetalViews(window.contentView);fflush(stderr);
            }];
        }
    });
}
@end
