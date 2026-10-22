#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>
#include <atomic>
#include <mutex>
#include <deque>
#include <vector>
#include <algorithm>
#include <chrono>

static std::atomic<bool> enabled{false};
static std::mutex samplesMutex;
static std::deque<double> samples;
static NSView *hudView;
static NSTextField *hudLabel;
static NSTimer *hudTimer;
static bool spanish;
@interface GRFSPassThroughHUD : NSView @end
@implementation GRFSPassThroughHUD
- (NSView *)hitTest:(NSPoint)point { return nil; }
@end
static double Now() {
    return std::chrono::duration<double>(std::chrono::steady_clock::now().time_since_epoch()).count();
}
extern "C" __attribute__((visibility("default"))) void GRFSRecordGuestSwap(void) {
    if (!enabled.load(std::memory_order_relaxed)) return;
    const double now = Now();
    std::lock_guard<std::mutex> lock(samplesMutex);
    samples.push_back(now);
    while (samples.size() > 240 || (!samples.empty() && now - samples.front() > 2)) samples.pop_front();
}
static void UpdateHUD() {
    NSWindow *game = nil;
    for (NSWindow *w in NSApp.windows) {
        if (w.visible && [w.title hasPrefix:@"Ghost Recon Future Soldier"]) { game = w; break; }
    }
    if (!game) return;
    if (hudView.superview != game.contentView) {
        [hudView removeFromSuperview];
        [game.contentView addSubview:hudView positioned:NSWindowAbove relativeTo:nil];
    }
    NSRect bounds = game.contentView.bounds;
    hudView.frame = NSMakeRect(12, MAX(12, bounds.size.height - 92), 355, 80);
    std::vector<double> intervals;
    double first = 0, last = 0;
    {
        std::lock_guard<std::mutex> lock(samplesMutex);
        if (samples.size() >= 2) {
            first = samples.front(); last = samples.back();
            for (size_t i=1;i<samples.size();++i) intervals.push_back((samples[i]-samples[i-1])*1000);
        }
    }
    NSString *title = spanish ? @"GRFS // RENDIMIENTO" : @"GRFS // PERFORMANCE";
    if (intervals.empty() || Now() - last > 1) {
        hudLabel.stringValue = [NSString stringWithFormat:@"%@\n%@\n%@",title,
            spanish ? @"Sin cuadros recientes" : @"No recent game swaps",
            spanish ? @"No cuenta redibujados de interfaz" : @"Excludes UI redraws"];
        return;
    }
    const double fps = intervals.size() / (last - first);
    const double mean = (last - first)*1000/intervals.size();
    std::sort(intervals.begin(), intervals.end());
    const double p95 = intervals[(intervals.size()-1)*95/100];
    if (getenv("GRFS_HUD_TRACE")) fprintf(stderr,"[GRFS HUD] swaps/s=%.2f mean_ms=%.2f p95_ms=%.2f\n",fps,mean,p95);
    hudLabel.stringValue = [NSString stringWithFormat:@"%@\n%.1f %@ | %.1f ms | p95 %.1f ms\n%@",title,fps,
        spanish ? @"envios/s" : @"swaps/s", mean,p95,
        spanish ? @"Solicitudes del juego; no FPS de pantalla" : @"Game requests; not display FPS"];
}
extern "C" __attribute__((visibility("default"))) void GRFSSetPerformanceHUD(int show, int es) {
    enabled.store(show != 0, std::memory_order_relaxed);
    { std::lock_guard<std::mutex> lock(samplesMutex); samples.clear(); }
    dispatch_async(dispatch_get_main_queue(), ^{
        spanish = es != 0;
        [hudTimer invalidate]; hudTimer = nil;
        [hudView removeFromSuperview];
        if (!show) return;
        if (!hudView) {
            hudView = [[GRFSPassThroughHUD alloc] initWithFrame:NSMakeRect(0,0,355,80)];
            hudView.wantsLayer = YES;
            hudView.layer.backgroundColor = [NSColor colorWithRed:.02 green:.06 blue:.08 alpha:.88].CGColor;
            hudView.layer.borderWidth = 1;
            hudView.layer.borderColor = [NSColor colorWithRed:.2 green:.7 blue:.8 alpha:.7].CGColor;
            hudLabel = [NSTextField labelWithString:@""];
            hudLabel.frame = NSMakeRect(10,8,335,64);
            hudLabel.font = [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightMedium];
            hudLabel.textColor = [NSColor colorWithRed:.75 green:.95 blue:1 alpha:1];
            hudLabel.maximumNumberOfLines = 3;
            [hudView addSubview:hudLabel];
        }
        UpdateHUD();
        hudTimer = [NSTimer timerWithTimeInterval:.25 repeats:YES block:^(NSTimer *timer) { UpdateHUD(); }];
        [NSRunLoop.mainRunLoop addTimer:hudTimer forMode:NSRunLoopCommonModes];
    });
}
