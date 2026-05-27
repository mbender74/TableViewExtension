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

// Performance logging - always enabled
#define SmoothLog(fmt, ...) NSLog(@"[TableViewExtension/Smooth] " fmt, ##__VA_ARGS__)

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

// Static cache for row heights
static NSCache<NSString *, NSNumber *> *sharedHeightCache;
static NSUInteger cacheHitCount = 0;
static NSUInteger cacheMissCount = 0;
static CGFloat totalHeightCalculationTime = 0;

@implementation TiUITableView (SmoothScrolling)

#pragma mark - Height Caching

- (void)enableHeightCaching
{
    if (sharedHeightCache == nil) {
        sharedHeightCache = [[NSCache alloc] init];
        sharedHeightCache.countLimit = 500;
        sharedHeightCache.totalCostLimit = 10 * 1024 * 1024; // 10MB
        cacheHitCount = 0;
        cacheMissCount = 0;
        totalHeightCalculationTime = 0;
        SmoothLog(@"Height cache initialized (limit: 500 entries, 10MB)");
        SmoothLog(@"Performance tracking enabled");
    }
}

- (void)invalidateHeightCache
{
    if (sharedHeightCache) {
        [sharedHeightCache removeAllObjects];
        SmoothLog(@"Height cache cleared");
    }
}

- (void)invalidateHeightCacheForIndexPath:(NSIndexPath *)indexPath
{
    if (sharedHeightCache) {
        NSString *key = [self cacheKeyForIndexPath:indexPath];
        [sharedHeightCache removeObjectForKey:key];
        SmoothLog(@"Height cache invalidated for row %ld section %ld", (long)indexPath.row, (long)indexPath.section);
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
    
    SmoothLog(@"Cache stats: %ld hits, %ld misses, %.1f%% hit rate, avg %.2fms/calc",
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
    // Get the row proxy to include height info in key
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
        SmoothLog(@"Cache HIT for row %ld: %.1f", (long)indexPath.row, cached.floatValue);
        return cached.floatValue;
    }
    
    cacheMissCount++;
    SmoothLog(@"Cache MISS for row %ld, calculating...", (long)indexPath.row);
    
    // Measure height calculation time
    PerformanceTimer timer = timerStart();
    
    // Calculate height
    CGFloat width = [row sizeWidthForDecorations:[self computeRowWidth] forceResizing:YES];
    CGFloat height = [row rowHeight:width];
    
    timer = timerStop(timer);
    totalHeightCalculationTime += timer.durationMs;
    
    SmoothLog(@"Height calculated: %.1fpt in %.2fms", height, timer.durationMs);
    
    // Store in cache
    [sharedHeightCache setObject:@(height) forKey:key cost:sizeof(CGFloat)];
    
    return height;
}

#pragma mark - Estimated Heights

- (void)enableEstimatedHeights:(CGFloat)estimatedHeight
{
    if (estimatedHeight > 0) {
        tableview.estimatedRowHeight = estimatedHeight;
        tableview.estimatedSectionHeaderHeight = estimatedHeight * 0.5;
        tableview.estimatedSectionFooterHeight = estimatedHeight * 0.3;
        
        // Use automatic dimension for rows with Ti.UI.SIZE
        tableview.rowHeight = UITableViewAutomaticDimension;
        
        SmoothLog(@"Estimated heights enabled: %.1f", estimatedHeight);
    }
}

#pragma mark - Prefetching

- (void)enablePrefetching
{
    // Prefetching is handled by iOS UITableView automatically
    // We just need to make sure our height calculation is fast
    SmoothLog(@"Prefetching enabled (uses cached heights)");
}

@end

// Override heightForRowAtIndexPath to use cache
@implementation TiUITableView (SmoothScrollingHeightOverride)

- (CGFloat)tableView:(UITableView *)ourTableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    TiUITableViewRowProxy *row = [self rowForIndexPath:indexPath];
    
    // Try cache first
    if (sharedHeightCache != nil) {
        return [self cachedHeightForRow:row indexPath:indexPath];
    }
    
    // Fallback to original calculation
    CGFloat width = [row sizeWidthForDecorations:[self computeRowWidth] forceResizing:YES];
    CGFloat height = [row rowHeight:width];
    height = [self tableRowHeight:height];
    return height < 1 ? tableview.rowHeight : height;
}

@end

// Scroll performance monitoring
@implementation TiUITableView (SmoothScrollingPerformance)

static CFAbsoluteTime lastScrollTime = 0;
static NSInteger frameCount = 0;
static CGFloat fps = 60;

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    // Call super implementation first
    if ([self.nextResponder respondsToSelector:@selector(scrollViewDidScroll:)]) {
        [self.nextResponder scrollViewDidScroll:scrollView];
    }
    
    // Track scroll performance
    frameCount++;
    CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
    
    if (lastScrollTime > 0) {
        CGFloat delta = (currentTime - lastScrollTime) * 1000.0; // ms
        if (delta > 0) {
            fps = 1000.0 / delta;
        }
    }
    lastScrollTime = currentTime;
    
    // Log performance every 30 frames
    if (frameCount % 30 == 0) {
        SmoothLog(@"Scroll FPS: %.1f | Cache: %ld entries", 
                 fps, (long)[sharedHeightCache count]);
    }
}

- (NSDictionary *)getPerformanceStats
{
    return @{
        @"fps": @(fps),
        @"frameCount": @(frameCount),
        @"cacheEntries": @(sharedHeightCache ? [sharedHeightCache count] : @0)
    };
}

@end
