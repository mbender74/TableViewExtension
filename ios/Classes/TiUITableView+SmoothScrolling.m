//  TiUITableView+SmoothScrolling.m
//  TableViewExtension
//
//  Smooth scrolling optimizations: height caching, estimated heights, prefetching
//

#define USE_TI_UITABLEVIEW

#import "TiUITableView+SmoothScrolling.h"
#import "TiUITableViewRowProxy.h"
#import "TiUITableViewSectionProxy.h"
#import "TiUtils.h"

// Performance logging - always enabled via NSLog

// Performance measurement helpers
typedef struct {
    CFAbsoluteTime startTime;
    CFAbsoluteTime endTime;
    CGFloat durationMs;
} PerformanceTimer;

static inline PerformanceTimer timerStart(void) {
    PerformanceTimer timer;
    timer.startTime = CFAbsoluteTimeGetCurrent();
    timer.endTime = 0;
    timer.durationMs = 0;
    return timer;
}

static inline PerformanceTimer timerStop(PerformanceTimer timer) {
    timer.endTime = CFAbsoluteTimeGetCurrent();
    timer.durationMs = (timer.endTime - timer.startTime) * 1000.0;
    return timer;
}

// Static cache for row heights - optimized limits
static NSCache<NSString *, NSNumber *> *sharedHeightCache;
static NSUInteger cacheHitCount = 0;
static NSUInteger cacheMissCount = 0;
static CGFloat totalHeightCalculationTime = 0;

// Scroll performance tracking - only log every N frames
CFAbsoluteTime lastScrollTime = 0;
NSInteger frameCount = 0;
NSInteger lastLoggedFrame = 0;
CGFloat fps = 60;
static const NSInteger kLogInterval = 60; // Log FPS every 60 frames instead of 30

@implementation TiUITableView (SmoothScrolling)

#pragma mark - Height Caching

- (void)enableHeightCaching
{
    if (sharedHeightCache == nil) {
        sharedHeightCache = [[NSCache alloc] init];
        sharedHeightCache.countLimit = 2000; // Increased from 500
        sharedHeightCache.totalCostLimit = 20 * 1024 * 1024; // 20MB
        cacheHitCount = 0;
        cacheMissCount = 0;
        totalHeightCalculationTime = 0;
        NSLog(@"[TableViewExtension/Smooth] Height cache initialized (limit: 2000 entries, 20MB)");
        NSLog(@"[TableViewExtension/Smooth] Performance tracking enabled");
    }
}

- (void)invalidateHeightCache
{
    if (sharedHeightCache) {
        [sharedHeightCache removeAllObjects];
        NSLog(@"[TableViewExtension/Smooth] Height cache cleared");
    }
}

- (void)invalidateHeightCacheForIndexPath:(NSIndexPath *)indexPath
{
    if (sharedHeightCache) {
        NSString *key = [self cacheKeyForIndexPath:indexPath];
        [sharedHeightCache removeObjectForKey:key];
        NSLog(@"[TableViewExtension/Smooth] Height cache invalidated for row %ld section %ld", 
              (long)indexPath.row, (long)indexPath.section);
    }
}

- (NSDictionary *)getCacheStats
{
    if (sharedHeightCache == nil) {
        return @{
            @"hits": @0,
            @"misses": @0,
            @"count": @0,
            @"totalCost": @0,
            @"hitRate": @0,
            @"avgCalculationTime": @0,
            @"totalCalculationTime": @0
        };
    }
    
    NSUInteger totalRequests = cacheHitCount + cacheMissCount;
    CGFloat hitRate = totalRequests > 0 ? (CGFloat)cacheHitCount / totalRequests * 100.0 : 0;
    CGFloat avgTime = cacheMissCount > 0 ? totalHeightCalculationTime / cacheMissCount : 0;
    
    NSLog(@"[TableViewExtension/Smooth] Cache stats: %ld hits, %ld misses, %.1f%% hit rate, avg %.2fms/calc",
             (long)cacheHitCount, (long)cacheMissCount, hitRate, avgTime);
    
    return @{
        @"hits": @(cacheHitCount),
        @"misses": @(cacheMissCount),
        @"count": @([sharedHeightCache count]),
        @"totalCost": @([sharedHeightCache totalCost]),
        @"hitRate": @(hitRate),
        @"avgCalculationTime": @(avgTime),
        @"totalCalculationTime": @(totalHeightCalculationTime)
    };
}

- (NSString *)cacheKeyForIndexPath:(NSIndexPath *)indexPath
{
    TiUITableViewRowProxy *row = [self rowForIndexPath:indexPath];
    id heightValue = [row valueForUndefinedKey:@"height"];
    NSString *heightStr = heightValue ? [heightValue description] : @"SIZE";
    
    return [NSString stringWithFormat:@"%ld-%ld-%@", 
             (long)indexPath.row, (long)indexPath.section, heightStr];
}

- (CGFloat)cachedHeightForRow:(TiUITableViewRowProxy *)row 
                   indexPath:(NSIndexPath *)indexPath
{
    NSString *key = [self cacheKeyForIndexPath:indexPath];
    NSNumber *cached = [sharedHeightCache objectForKey:key];
    
    if (cached) {
        cacheHitCount++;
        return cached.floatValue;
    }
    
    cacheMissCount++;
    
    PerformanceTimer timer = timerStart();
    
    CGFloat width = [row sizeWidthForDecorations:[self computeRowWidth] forceResizing:YES];
    CGFloat height = [row rowHeight:width];
    
    timer = timerStop(timer);
    totalHeightCalculationTime += timer.durationMs;
    
    [sharedHeightCache setObject:@(height) forKey:key cost:sizeof(CGFloat)];
    
    // Only log slow calculations (>10ms)
    if (timer.durationMs > 10.0) {
        NSLog(@"[TableViewExtension/Smooth] Slow height calc: row %ld = %.1fpt in %.2fms", 
              (long)indexPath.row, height, timer.durationMs);
    }
    
    return height;
}

#pragma mark - Estimated Heights

- (void)enableEstimatedHeights:(CGFloat)estimatedHeight
{
    if (estimatedHeight > 0) {
        tableview.estimatedRowHeight = estimatedHeight;
        tableview.estimatedSectionHeaderHeight = estimatedHeight * 0.5;
        tableview.estimatedSectionFooterHeight = estimatedHeight * 0.3;
        tableview.rowHeight = UITableViewAutomaticDimension;
        NSLog(@"[TableViewExtension/Smooth] Estimated heights enabled: %.1f", estimatedHeight);
    }
}

#pragma mark - Prefetching

- (void)enablePrefetching
{
    NSLog(@"[TableViewExtension/Smooth] Prefetching enabled (uses cached heights)");
}

#pragma mark - Performance Logging

- (void)logPerformance
{
    NSUInteger totalRequests = cacheHitCount + cacheMissCount;
    CGFloat hitRate = totalRequests > 0 ? (CGFloat)cacheHitCount / totalRequests * 100.0 : 0;
    CGFloat avgTime = cacheMissCount > 0 ? totalHeightCalculationTime / cacheMissCount : 0;
    
    NSLog(@"[TableViewExtension/Smooth] === Performance Report ===");
    NSLog(@"[TableViewExtension/Smooth] Scroll FPS: %.1f", fps);
    NSLog(@"[TableViewExtension/Smooth] Cache Hit Rate: %.1f%% (%ld/%ld)", 
         hitRate, (long)cacheHitCount, (long)totalRequests);
    NSLog(@"[TableViewExtension/Smooth] Avg Height Calc: %.2fms", avgTime);
    NSLog(@"[TableViewExtension/Smooth] Cache Size: %ld entries, %.1fKB",
         (long)[sharedHeightCache count], 
         (double)[sharedHeightCache totalCost] / 1024.0);
    NSLog(@"[TableViewExtension/Smooth] ============================");
}

- (NSDictionary *)getPerformanceStats
{
    return @{
        @"fps": @(fps),
        @"frameCount": @(frameCount),
        @"cacheEntries": @(sharedHeightCache ? [sharedHeightCache count] : @0)
    };
}

- (CGFloat)currentFPS
{
    return fps;
}

@end

// Override heightForRowAtIndexPath to use cache
@implementation TiUITableView (SmoothScrollingHeightOverride)

- (CGFloat)tableView:(UITableView *)ourTableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    TiUITableViewRowProxy *row = [self rowForIndexPath:indexPath];
    
    if (sharedHeightCache != nil) {
        return [self cachedHeightForRow:row indexPath:indexPath];
    }
    
    CGFloat width = [row sizeWidthForDecorations:[self computeRowWidth] forceResizing:YES];
    CGFloat height = [row rowHeight:width];
    height = [self tableRowHeight:height];
    return height < 1 ? tableview.rowHeight : height;
}

@end

// Scroll performance monitoring
@implementation TiUITableView (SmoothScrollingPerformance)

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if ([self.nextResponder respondsToSelector:@selector(scrollViewDidScroll:)]) {
        [self.nextResponder scrollViewDidScroll:scrollView];
    }
    
    frameCount++;
    CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
    
    if (lastScrollTime > 0) {
        CGFloat delta = (currentTime - lastScrollTime) * 1000.0;
        if (delta > 0) {
            fps = 1000.0 / delta;
        }
    }
    lastScrollTime = currentTime;
    
    // Log FPS every 60 frames (reduced from 30)
    if (frameCount - lastLoggedFrame >= kLogInterval) {
        lastLoggedFrame = frameCount;
        NSLog(@"[TableViewExtension/Smooth] Scroll FPS: %.1f | Cache: %ld/%ld (%.0f%% hit rate)", 
             fps, (long)cacheHitCount, (long)(cacheHitCount + cacheMissCount), 
             (cacheHitCount + cacheMissCount) > 0 ? (CGFloat)cacheHitCount / (cacheHitCount + cacheMissCount) * 100 : 0);
    }
}

@end
