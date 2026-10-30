#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>
#include <atomic>
#include <cstdio>
#include <mutex>
#include <chrono>
#include <deque>

static std::atomic<bool> metalHUDEnabled{false};
static NSTimer *metalHUDTimer;
static NSMapTable<CAMetalLayer *,NSNumber *> *appliedLayers;

static std::mutex guestLock;
static std::deque<double> guestTimes;
static double lastGuest=0;
static std::atomic<bool> hudSpanish{false};
@interface GRFSGuestLabel : NSTextField
@end
@implementation GRFSGuestLabel
- (NSView *)hitTest:(NSPoint)p { return nil; }
@end
static NSMapTable<NSWindow *,GRFSGuestLabel *> *guestLabels;
static BOOL HasMetal(CALayer *layer) {
 if([layer isKindOfClass:CAMetalLayer.class])return YES;
 for(CALayer *child in layer.sublayers)if(HasMetal(child))return YES;
 return NO;
}
static BOOL ViewHasMetal(NSView *view){if(HasMetal(view.layer))return YES;for(NSView *v in view.subviews)if(ViewHasMetal(v))return YES;return NO;}

static double GuestNow() { return std::chrono::duration<double>(std::chrono::steady_clock::now().time_since_epoch()).count(); }
// Counts guest swap requests, not guaranteed unique displayed images.
static NSString *GuestText() {
    const double now=GuestNow(); double last; size_t count;
    { std::lock_guard<std::mutex> guard(guestLock);
      while(!guestTimes.empty() && guestTimes.front()<now-1.0)guestTimes.pop_front();
      count=guestTimes.size();last=lastGuest; }
    if(!last)return hudSpanish.load()?@"JUEGO: esperando cuadros\nMetal cuenta presentaciones":@"GAME: waiting for frames\nMetal counts presentations";
    const double age=now-last;
    return [NSString stringWithFormat:hudSpanish.load()?@"JUEGO: %zu envios/s (ultimo segundo)\nSin envio nuevo: %.2f s\nNo equivale a cuadros unicos de pantalla":@"GAME: %zu submissions/s (last second)\nNo new submission: %.2f s\nNot unique displayed frames",count,age];
}
extern "C" __attribute__((visibility("default"))) void GRFSRecordGuestSwap(void) {
    const double stamp=GuestNow();
    { std::lock_guard<std::mutex> guard(guestLock);lastGuest=stamp;guestTimes.push_back(stamp);while(!guestTimes.empty() && guestTimes.front()<stamp-1.0)guestTimes.pop_front(); }
    static FILE *trace=[](){const char *p=getenv("GRFS_EDRAM_FRAME_TRACE");return p?fopen(p,"a"):nullptr;}();
    if (!trace) return;
    static std::mutex lock;
    const double now=std::chrono::duration<double>(std::chrono::steady_clock::now().time_since_epoch()).count();
    std::lock_guard<std::mutex> guard(lock);
    fprintf(trace,"%.9f\n",now);fflush(trace);
}
static void ApplyLayer(CALayer *layer,BOOL show) {
    if (!layer) return;
    if ([layer isKindOfClass:CAMetalLayer.class]) {
        CAMetalLayer *metal=(CAMetalLayer *)layer;
        NSNumber *previous=[appliedLayers objectForKey:metal];
        if (!previous || previous.boolValue!=show) {
            NSMutableDictionary *properties=[metal.developerHUDProperties mutableCopy] ?: [NSMutableDictionary dictionary];
            if(show) properties[@"mode"]=@"default";
            else [properties removeObjectForKey:@"mode"];
            metal.developerHUDProperties=properties;
            [appliedLayers setObject:@(show) forKey:metal];
            if(getenv("GRFS_HUD_TRACE"))fprintf(stderr,"[GRFS METAL HUD] enabled=%d alignment=topright layer=%p\n",show,metal);
        }
    }
    for(CALayer *child in layer.sublayers)ApplyLayer(child,show);
}
static void ApplyView(NSView *view,BOOL show) {
    ApplyLayer(view.layer,show);
    for(NSView *child in view.subviews)ApplyView(child,show);
}
static void UpdateMetalHUD() {
    const BOOL show=metalHUDEnabled.load(std::memory_order_relaxed);
    if(!guestLabels)guestLabels=[NSMapTable weakToStrongObjectsMapTable];
    for(NSWindow *window in NSApp.windows){
        NSView *root=window.contentView;ApplyView(root,show);
        if(!ViewHasMetal(root))continue;
        GRFSGuestLabel *label=[guestLabels objectForKey:window];
        if(!label){label=[[GRFSGuestLabel alloc]initWithFrame:NSZeroRect];label.editable=NO;label.selectable=NO;label.bezeled=NO;label.drawsBackground=YES;label.backgroundColor=[NSColor colorWithWhite:0 alpha:.85];label.textColor=NSColor.whiteColor;label.font=[NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightMedium];[guestLabels setObject:label forKey:window];}
        if(label.superview!=root)[root addSubview:label positioned:NSWindowAbove relativeTo:nil];
        CGFloat w=MIN(340.0,MAX(100.0,root.bounds.size.width-16));
        CGFloat y=root.isFlipped?260:root.bounds.size.height-330;
        label.frame=NSMakeRect(MAX(8.0,root.bounds.size.width-w-8),MAX(8.0,y),w,70);
        label.stringValue=GuestText();label.hidden=!show;
    }
}
extern "C" __attribute__((visibility("default"))) void GRFSSetPerformanceHUD(int show,int spanish) {
    hudSpanish.store(spanish!=0);
    metalHUDEnabled.store(show!=0,std::memory_order_relaxed);
    dispatch_async(dispatch_get_main_queue(), ^{
        if(!appliedLayers)appliedLayers=[NSMapTable weakToStrongObjectsMapTable];
        UpdateMetalHUD();
        if(!metalHUDTimer){
            // Also apply to new layers after fullscreen/swapchain recreation.
            metalHUDTimer=[NSTimer timerWithTimeInterval:.25 repeats:YES block:^(NSTimer *timer){UpdateMetalHUD();}];
            [NSRunLoop.mainRunLoop addTimer:metalHUDTimer forMode:NSRunLoopCommonModes];
        }
    });
}
