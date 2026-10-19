#import <AppKit/AppKit.h>
#import <objc/runtime.h>
// Presentation-only hook: keep the validated renderer and game runtime unchanged.
@interface NSWindow (GRFSDisplayTitle)
- (void)grfs_setTitle:(NSString *)title;
@end
@implementation NSWindow (GRFSDisplayTitle)
+ (void)load {
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
