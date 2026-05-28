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
static NSCache<NSString *, NSNumber *> *sharedTemplateCache; // Template-based cache
static NSUInteger cacheHitCount = 0;
static NSUInteger cacheMissCount = 0;
static NSUInteger templateHitCount = 0; // Template cache hits
static CGFloat totalHeightCalculationTime = 0;

// Scroll performance tracking - only log every N frames
CFAbsoluteTime lastScrollTime = 0;
NSInteger frameCount = 0;
NSInteger lastLoggedFrame = 0;
CGFloat fps = 60;
static const NSInteger kLogInterval = 60; // Log FPS every 60 frames instead of 30

// FPS smoothing - rolling average over last N frames
static const NSInteger kFPSSampleWindow = 60;
static CFAbsoluteTime frameTimestamps[60];
static NSInteger fpsSampleIndex = 0;

// Preload queue configuration
static const NSInteger kPreloadAheadRows = 5;   // Rows to preload ahead (reduced from 10 to prevent jank)
static const NSInteger kPreloadBehindRows = 3;  // Rows to preload behind (reduced from 5)
static dispatch_queue_t preloadQueue = nil;
static BOOL isPreloading = NO;
static NSInteger lastVisibleRow = -1;
static NSInteger scrollEventCount = 0; // Counter to throttle preload calls

// Scroll event throttling
static CFAbsoluteTime lastRowVisibleTime = 0;
static const CGFloat kRowVisibleThrottleInterval = 0.016; // ~60fps

@implementation TiUITableView (SmoothScrolling)

#pragma mark - Height Caching

- (void)enableHeightCaching
{
    if (sharedHeightCache == nil) {
        sharedHeightCache = [[NSCache alloc] init];
        sharedHeightCache.countLimit = 2000;
        sharedHeightCache.totalCostLimit = 20 * 1024 * 1024;
        
        // Template cache - stores heights by row configuration
        sharedTemplateCache = [[NSCache alloc] init];
        sharedTemplateCache.countLimit = 500; // Fewer unique templates
        sharedTemplateCache.totalCostLimit = 5 * 1024 * 1024;
        
        // Preload queue for background height calculation
        if (preloadQueue == nil) {
            preloadQueue = dispatch_queue_create("de.marcbender.tableviewextension.preload", DISPATCH_QUEUE_SERIAL);
        }
        
        cacheHitCount = 0;
        cacheMissCount = 0;
        templateHitCount = 0;
        totalHeightCalculationTime = 0;
        lastVisibleRow = -1;
        
        NSLog(@"[TableViewExtension/Smooth] Height cache initialized (limit: 2000 entries, 20MB)");
        NSLog(@"[TableViewExtension/Smooth] Template cache initialized (limit: 500 templates, 5MB)");
        NSLog(@"[TableViewExtension/Smooth] Preload queue initialized (ahead: %d, behind: %d)", kPreloadAheadRows, kPreloadBehindRows);
        NSLog(@"[TableViewExtension/Smooth] Performance tracking enabled");
    }
}

- (void)invalidateHeightCache
{
    if (sharedHeightCache) {
        [sharedHeightCache removeAllObjects];
        [sharedTemplateCache removeAllObjects];
        cacheHitCount = 0;
        cacheMissCount = 0;
        templateHitCount = 0;
        NSLog(@"[TableViewExtension/Smooth] Height cache cleared (indexPath + template)");
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
            @"templateHits": @0,
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
    
    NSLog(@"[TableViewExtension/Smooth] Cache stats: %ld hits (%ld template), %ld misses, %.1f%% hit rate, avg %.2fms/calc",
             (long)cacheHitCount, (long)templateHitCount, (long)cacheMissCount, hitRate, avgTime);
    
    return @{
        @"hits": @(cacheHitCount),
        @"misses": @(cacheMissCount),
        @"templateHits": @(templateHitCount),
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

- (NSString *)templateKeyForRow:(TiUITableViewRowProxy *)row
{
    // Generate key from layout-relevant properties only
    // Margins (top/bottom) don't affect intrinsic height, so skip them
    id heightValue = [row valueForUndefinedKey:@"height"];
    id widthValue = [row valueForUndefinedKey:@"width"];
    NSString *className = [row tableClass];
    
    return [NSString stringWithFormat:@"%@-%@-%@", 
             heightValue ? [heightValue description] : @"SIZE",
             widthValue ? [widthValue description] : @"AUTO",
             className ? className : @"TiUITableView"];
}

- (CGFloat)cachedHeightForRow:(TiUITableViewRowProxy *)row
                   indexPath:(NSIndexPath *)indexPath
{
    // First try template cache (configuration-based)
    NSString *templateKey = [self templateKeyForRow:row];
    NSNumber *templateCached = [sharedTemplateCache objectForKey:templateKey];
    
    if (templateCached) {
        templateHitCount++;
        cacheHitCount++;
        // Also store in indexPath cache for faster future access
        NSString *key = [self cacheKeyForIndexPath:indexPath];
        [sharedHeightCache setObject:templateCached forKey:key cost:sizeof(CGFloat)];
        return templateCached.floatValue;
    }
    
    // Try indexPath cache
    NSString *key = [self cacheKeyForIndexPath:indexPath];
    NSNumber *cached = [sharedHeightCache objectForKey:key];
    
    if (cached) {
        cacheHitCount++;
        return cached.floatValue;
    }
    
    cacheMissCount++;
    
    // Check if row has a fixed height set (not SIZE or FILL)
    id heightValue = [row valueForUndefinedKey:@"height"];
    NSString *heightStr = heightValue ? [heightValue description] : @"";
    
    // If height is a fixed number (not "SIZE" or "FILL"), use it directly
    if (![heightStr isEqualToString:@"SIZE"] && ![heightStr isEqualToString:@"FILL"] && ![heightStr isEqualToString:@""]) {
        CGFloat fixedHeight = [heightValue floatValue];
        if (fixedHeight > 0) {
            // Store in cache for future access
            [sharedHeightCache setObject:@(fixedHeight) forKey:key cost:sizeof(CGFloat)];
            [sharedTemplateCache setObject:@(fixedHeight) forKey:templateKey cost:sizeof(CGFloat)];
            return fixedHeight;
        }
    }
    
    PerformanceTimer timer = timerStart();
    
    // Use forceResizing:NO on cache miss to avoid redundant layout calculations
    CGFloat width = [row sizeWidthForDecorations:[self computeRowWidth] forceResizing:NO];
    CGFloat height = [row rowHeight:width];
    
    timer = timerStop(timer);
    totalHeightCalculationTime += timer.durationMs;
    
    // Store in both caches
    [sharedHeightCache setObject:@(height) forKey:key cost:sizeof(CGFloat)];
    [sharedTemplateCache setObject:@(height) forKey:templateKey cost:sizeof(CGFloat)];
    
    // Only log slow calculations (>10ms)
    if (timer.durationMs > 10.0) {
        NSLog(@"[TableViewExtension/Smooth] Slow height calc: row %ld = %.1fpt in %.2fms",
              (long)indexPath.row, height, timer.durationMs);
    }
    
    return height;
}

#pragma mark - Preload Queue

- (void)preloadRowHeightsIfNeeded
{
    if (isPreloading) return;
    
    // Get current visible rows
    NSArray *visiblePaths = [tableview indexPathsForVisibleRows];
    if (visiblePaths.count == 0) return;
    
    // Find the last visible row (multi-section aware)
    NSIndexPath *lastPath = [visiblePaths lastObject];
    NSInteger currentSection = lastPath.section;
    NSInteger currentRow = lastPath.row;
    
    // Only preload if we scrolled significantly
    NSInteger scrollKey = (currentSection << 16) | currentRow;
    if (scrollKey == lastVisibleRow) return;
    lastVisibleRow = scrollKey;
    
    // Throttle preload calls: only preload every 2nd scroll event to reduce main thread pressure
    scrollEventCount++;
    if (scrollEventCount % 2 != 0) {
        return;
    }
    
    isPreloading = YES;
    
    // Preload in background queue
    dispatch_async(preloadQueue, ^{
        // Get sections
        NSArray *sections = [(TiUITableViewProxy *)[self proxy] internalSections];
        if (sections.count == 0) {
            isPreloading = NO;
            return;
        }
        
        // Preload rows ahead (same section, then next sections)
        NSInteger aheadCount = 0;
        for (NSInteger s = currentSection; s < sections.count && aheadCount < kPreloadAheadRows; s++) {
            TiUITableViewSectionProxy *section = sections[s];
            NSInteger sectionRowCount = [section rows] count;
            
            for (NSInteger r = (s == currentSection ? currentRow + 1 : 0); r < sectionRowCount && aheadCount < kPreloadAheadRows; r++) {
                NSIndexPath *path = [NSIndexPath indexPathForRow:r inSection:s];
                TiUITableViewRowProxy *row = [self rowForIndexPath:path];
                if (row) {
                    [self cachedHeightForRow:row indexPath:path];
                }
                aheadCount++;
            }
        }
        
        // Preload rows behind (same section, then previous sections)
        NSInteger behindCount = 0;
        for (NSInteger s = currentSection; s >= 0 && behindCount < kPreloadBehindRows; s--) {
            TiUITableViewSectionProxy *section = sections[s];
            NSArray *rows = [section rows];
            NSInteger sectionRowCount = rows.count;
            
            for (NSInteger r = (s == currentSection ? currentRow - 1 : sectionRowCount - 1); r >= 0 && behindCount < kPreloadBehindRows; r--) {
                NSIndexPath *path = [NSIndexPath indexPathForRow:r inSection:s];
                TiUITableViewRowProxy *row = [self rowForIndexPath:path];
                if (row) {
                    [self cachedHeightForRow:row indexPath:path];
                }
                behindCount++;
            }
        }
        
        isPreloading = NO;
    });
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
    NSLog(@"[TableViewExtension/Smooth] Prefetching enabled (preload queue active)");
}

#pragma mark - Performance Logging

- (void)logPerformance
{
    NSUInteger totalRequests = cacheHitCount + cacheMissCount;
    CGFloat hitRate = totalRequests > 0 ? (CGFloat)cacheHitCount / totalRequests * 100.0 : 0;
    CGFloat avgTime = cacheMissCount > 0 ? totalHeightCalculationTime / cacheMissCount : 0;
    
    NSLog(@"[TableViewExtension/Smooth] === Performance Report ===");
    NSLog(@"[TableViewExtension/Smooth] Scroll FPS: %.1f", fps);
    NSLog(@"[TableViewExtension/Smooth] Cache Hit Rate: %.1f%% (%ld/%ld, %ld template)", 
         hitRate, (long)cacheHitCount, (long)totalRequests, (long)templateHitCount);
    NSLog(@"[TableViewExtension/Smooth] Avg Height Calc: %.2fms", avgTime);
    NSLog(@"[TableViewExtension/Smooth] Cache Size: %ld entries (%.1fKB), Templates: %ld (%.1fKB)",
         (long)[sharedHeightCache count], 
         (double)[sharedHeightCache totalCost] / 1024.0,
         (long)[sharedTemplateCache count],
         (double)[sharedTemplateCache totalCost] / 1024.0);
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
    
    // Check if row has a fixed height set (not SIZE or FILL)
    id heightValue = [row valueForUndefinedKey:@"height"];
    NSString *heightStr = heightValue ? [heightValue description] : @"";
    
    // If height is a fixed number, use it directly - skip all caching overhead
    if (![heightStr isEqualToString:@"SIZE"] && ![heightStr isEqualToString:@"FILL"] && ![heightStr isEqualToString:@""]) {
        CGFloat fixedHeight = [heightValue floatValue];
        if (fixedHeight > 0) {
            return fixedHeight;
        }
    }
    
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
    
    // Store frame timestamp for rolling FPS calculation
    frameTimestamps[fpsSampleIndex % kFPSSampleWindow] = currentTime;
    fpsSampleIndex++;
    
    // Calculate rolling average FPS over last N frames
    if (lastScrollTime > 0) {
        CGFloat delta = (currentTime - lastScrollTime) * 1000.0;
        if (delta > 0) {
            fps = 1000.0 / delta;
        }
    }
    lastScrollTime = currentTime;
    
    // Calculate smoothed FPS from rolling window
    if (fpsSampleIndex >= kFPSSampleWindow) {
        CFAbsoluteTime oldestTime = frameTimestamps[(fpsSampleIndex - kFPSSampleWindow) % kFPSSampleWindow];
        CFAbsoluteTime newestTime = frameTimestamps[(fpsSampleIndex - 1) % kFPSSampleWindow];
        CGFloat totalTime = (newestTime - oldestTime) * 1000.0;
        if (totalTime > 0) {
            fps = (CGFloat)(kFPSSampleWindow - 1) / (totalTime / 1000.0);
        }
    }
    
    // Trigger preload queue
    [self preloadRowHeightsIfNeeded];
    
    // Log FPS every 60 frames (reduced from 30)
    if (frameCount - lastLoggedFrame >= kLogInterval) {
        lastLoggedFrame = frameCount;
        NSUInteger totalRequests = cacheHitCount + cacheMissCount;
        CGFloat hitRate = totalRequests > 0 ? (CGFloat)cacheHitCount / totalRequests * 100.0 : 0;
        NSLog(@"[TableViewExtension/Smooth] Scroll FPS: %.1f (smoothed) | Cache: %ld/%ld (%.0f%% hit rate)", 
             fps, (long)cacheHitCount, (long)totalRequests, hitRate);
    }
}

@end
