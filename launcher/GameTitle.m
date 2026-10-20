#import <AppKit/AppKit.h>
#import <objc/runtime.h>
static void GRFSApplyDockIcon(void) {
    NSURL *url = [NSBundle.mainBundle URLForResource:@"DockIcon" withExtension:@"png"];
    if (!url) return;
    NSImage *image = [[NSImage alloc] initWithContentsOfURL:url];
    if (image) NSApp.applicationIconImage = image;
}
// Presentation-only hook: keep the validated renderer and game runtime unchanged.
@interface NSWindow (GRFSDisplayTitle)
- (void)grfs_setTitle:(NSString *)title;
@end
@implementation NSWindow (GRFSDisplayTitle)
+ (void)load {
    dispatch_async(dispatch_get_main_queue(), ^{ GRFSApplyDockIcon(); });
    [NSNotificationCenter.defaultCenter addObserverForName:NSApplicationDidFinishLaunchingNotification
        object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
            GRFSApplyDockIcon();
        }];
    if (getenv("GRFS_WINDOW_TITLE")) {
        method_exchangeImplementations(class_getInstanceMethod(self, @selector(setTitle:)),
                                       class_getInstanceMethod(self, @selector(grfs_setTitle:)));
    }
}
- (void)grfs_setTitle:(NSString *)title {
    if ([title isEqualToString:@"grfs"] || [title hasPrefix:@"grfs [rexglue-"]) {
        title = [NSString stringWithUTF8String:getenv("GRFS_WINDOW_TITLE")];
    }
    [self grfs_setTitle:title];
}
@end
