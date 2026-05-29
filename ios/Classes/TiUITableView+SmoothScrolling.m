//  TiUITableView+SmoothScrolling.m
//  TableViewExtension
//
//  Smooth scrolling optimizations: height caching, estimated heights, prefetching
//

#define USE_TI_UITABLEVIEW

#import "TiUITableView+SmoothScrolling.h"
#import "TiUITableViewRowProxy.h"
#import "TiUITableViewSectionProxy.h"
#import "TiUITableViewProxy.h"
#import "TiUtils.h"
#import "TiUITableView.h"
#import <UIKit/UIImageView.h>
#import <os/lock.h>

// Forward declarations for private TiUITableView methods
@interface TiUITableView (PrivateMethods)
- (CGFloat)computeRowWidth;
- (TiUITableViewRowProxy *)rowForIndexPath:(NSIndexPath *)indexPath;
@end

// Forward declaration for prefetch delegate
@interface TiUITableViewRowProxy (ImagePreload)
@end

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
static NSCache<NSNumber *, NSNumber *> *sharedHeightCache;
static NSCache<NSNumber *, NSNumber *> *sharedTemplateCache; // Template-based cache
static NSUInteger cacheHitCount = 0;
static NSUInteger cacheMissCount = 0;
static NSUInteger templateHitCount = 0; // Template cache hits
static CGFloat totalHeightCalculationTime = 0;

// Track cache stats manually (iOS 26.2 removed count/totalCost from NSCache)
static NSUInteger heightCacheEntryCount = 0;
static NSUInteger heightCacheTotalCost = 0;
static NSUInteger templateCacheEntryCount = 0;
static NSUInteger templateCacheTotalCost = 0;

// Cell reuse statistics (visible to other files)
NSUInteger cellReuseCount;
NSUInteger cellCreateCount;

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

// Preload queue configuration - adaptive based on scroll speed (thread-safe with dispatch_once)
static dispatch_once_t preloadQueueOnce;
static dispatch_queue_t preloadQueue;

// Adaptive preload counts (updated on main thread, read on background)
static volatile NSInteger gPreloadAheadRows = 5;
static volatile NSInteger gPreloadBehindRows = 3;

static BOOL isPreloading = NO;
static NSInteger lastVisibleRow = -1;
static NSInteger scrollEventCount = 0;
static CGFloat lastScrollVelocity = 0;

// Cache access mutex for thread safety
static os_unfair_lock_t cacheLock = nil;

// Scroll event throttling - centralized (used by Snappy too)
CFAbsoluteTime lastRowVisibleTime = 0;
CFAbsoluteTime lastRowNotVisibleTime = 0;
const CGFloat kRowVisibleThrottleInterval = 0.032; // ~30fps

@implementation TiUITableView (SmoothScrolling)

#pragma mark - Height Caching

- (void)enableHeightCaching
{
    if (sharedHeightCache == nil) {
        // Get device memory for dynamic limits
        uint64_t totalMemory = [[NSProcessInfo processInfo] physicalMemory];
        uint64_t memoryMB = totalMemory / (1024 * 1024);
        
        // Adaptive cache limits based on device memory
        NSUInteger cacheLimit = (memoryMB > 3000) ? 3000 : 2000;
        NSUInteger costLimit = (memoryMB > 3000) ? 30 : 20;
        
        sharedHeightCache = [[NSCache alloc] init];
        sharedHeightCache.countLimit = cacheLimit;
        sharedHeightCache.totalCostLimit = costLimit * 1024 * 1024;
        
        sharedTemplateCache = [[NSCache alloc] init];
        sharedTemplateCache.countLimit = (memoryMB > 3000) ? 750 : 500;
        sharedTemplateCache.totalCostLimit = (costLimit / 4) * 1024 * 1024;
        
        // Thread-safe preload queue
        dispatch_once(&preloadQueueOnce, ^{
            preloadQueue = dispatch_queue_create("de.marcbender.tableviewextension.preload", DISPATCH_QUEUE_CONCURRENT);
        });
        
        // Initialize cache lock
        if (cacheLock == nil) {
            cacheLock = malloc(sizeof(os_unfair_lock_t));
            *cacheLock = OS_UNFAIR_LOCK_INIT;
        }
        
        cacheHitCount = 0;
        cacheMissCount = 0;
        templateHitCount = 0;
        totalHeightCalculationTime = 0;
        heightCacheEntryCount = 0;
        heightCacheTotalCost = 0;
        templateCacheEntryCount = 0;
        templateCacheTotalCost = 0;
        lastVisibleRow = -1;
    }
}

- (void)invalidateHeightCache
{
    if (sharedHeightCache) {
        os_unfair_lock_lock(cacheLock);
        [sharedHeightCache removeAllObjects];
        [sharedTemplateCache removeAllObjects];
        cacheHitCount = 0;
        cacheMissCount = 0;
        templateHitCount = 0;
        heightCacheEntryCount = 0;
        heightCacheTotalCost = 0;
        templateCacheEntryCount = 0;
        templateCacheTotalCost = 0;
        os_unfair_lock_unlock(cacheLock);
    }
}

- (void)invalidateHeightCacheForIndexPath:(NSIndexPath *)indexPath
{
    if (sharedHeightCache) {
        os_unfair_lock_lock(cacheLock);
        NSNumber *key = [self cacheKeyForIndexPath:indexPath];
        // Only decrement accounting if the key actually existed
        if ([sharedHeightCache objectForKey:key] != nil) {
            [sharedHeightCache removeObjectForKey:key];
            heightCacheEntryCount--;
            heightCacheTotalCost -= sizeof(CGFloat);
        }
        os_unfair_lock_unlock(cacheLock);
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
        @"count": @(heightCacheEntryCount),
        @"totalCost": @(heightCacheTotalCost),
        @"hitRate": @(hitRate),
        @"avgCalculationTime": @(avgTime),
        @"totalCalculationTime": @(totalHeightCalculationTime)
    };
}

- (NSNumber *)cacheKeyForIndexPath:(NSIndexPath *)indexPath
{
    // Use NSNumber with combined UInt64 - no string allocation
    UInt64 combined = ((UInt64)indexPath.section << 32) | (UInt64)indexPath.row;
    return @(combined);
}

- (NSNumber *)templateKeyForRow:(TiUITableViewRowProxy *)row
{
    // Generate key from layout-relevant properties - no string allocation
    id heightValue = [row valueForUndefinedKey:@"height"];
    id widthValue = [row valueForUndefinedKey:@"width"];
    NSString *className = [row tableClass];
    
    // Combine hashes into single UInt64
    NSUInteger hHash = heightValue ? [heightValue hash] : 0;
    NSUInteger wHash = widthValue ? [widthValue hash] : 1;
    NSUInteger cHash = className ? [className hash] : 2;
    
    // XOR combination - fast, collision-safe enough for this use case
    UInt64 combined = ((UInt64)hHash << 32) ^ ((UInt64)wHash << 16) ^ (UInt64)cHash;
    return @(combined);
}

- (CGFloat)cachedHeightForRow:(TiUITableViewRowProxy *)row
                   indexPath:(NSIndexPath *)indexPath
{
    NSNumber *templateKey = [self templateKeyForRow:row];
    NSNumber *indexPathKey = [self cacheKeyForIndexPath:indexPath];
    
    // First try template cache (configuration-based) - single lock/unlock
    os_unfair_lock_lock(cacheLock);
    NSNumber *templateCached = [sharedTemplateCache objectForKey:templateKey];
    if (templateCached) {
        templateHitCount++;
        cacheHitCount++;
        // Lazy: only store in indexPath cache if not already there
        if ([sharedHeightCache objectForKey:indexPathKey] == nil) {
            [sharedHeightCache setObject:templateCached forKey:indexPathKey cost:sizeof(CGFloat)];
            heightCacheEntryCount++;
            heightCacheTotalCost += sizeof(CGFloat);
        }
        os_unfair_lock_unlock(cacheLock);
        return templateCached.floatValue;
    }
    
    // Try indexPath cache
    NSNumber *cached = [sharedHeightCache objectForKey:indexPathKey];
    if (cached) {
        cacheHitCount++;
        os_unfair_lock_unlock(cacheLock);
        return cached.floatValue;
    }
    os_unfair_lock_unlock(cacheLock);

    cacheMissCount++;

    // NOTE: Fixed-height fast path lives in tableView:heightForRowAtIndexPath:.
    // cachedHeightForRow:indexPath: is only reached for dynamic heights (SIZE/FILL/%)
    // because callers already check fixed heights first.

    PerformanceTimer timer = timerStart();
    
    // Use forceResizing:NO on cache miss to avoid redundant layout calculations
    CGFloat width = [row sizeWidthForDecorations:[self computeRowWidth] forceResizing:NO];
    CGFloat height = [row rowHeight:width];
    
    timer = timerStop(timer);
    totalHeightCalculationTime += timer.durationMs;
    
    os_unfair_lock_lock(cacheLock);
    [sharedHeightCache setObject:@(height) forKey:indexPathKey cost:sizeof(CGFloat)];
    heightCacheEntryCount++;
    heightCacheTotalCost += sizeof(CGFloat);
    [sharedTemplateCache setObject:@(height) forKey:templateKey cost:sizeof(CGFloat)];
    templateCacheEntryCount++;
    templateCacheTotalCost += sizeof(CGFloat);
    os_unfair_lock_unlock(cacheLock);
    
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
    
    // Preload in concurrent background queue with dispatch_group
    dispatch_group_t group = dispatch_group_create();
    
    // Get sections
    NSArray *sections = [(TiUITableViewProxy *)[self proxy] internalSections];
    if (sections.count == 0) {
        isPreloading = NO;
        return;
    }
    
    // Helper: check if row needs height calculation (SIZE, FILL, or %)
    BOOL (^needsHeightCalc)(TiUITableViewRowProxy *) = ^(TiUITableViewRowProxy *row) {
        id heightValue = [row valueForUndefinedKey:@"height"];
        NSString *heightStr = heightValue ? [heightValue description] : @"";
        BOOL result = [heightStr isEqualToString:@"SIZE"] || 
                      [heightStr isEqualToString:@"FILL"] || 
                      [heightStr hasSuffix:@"%"];
        return result;
    };
    
    // Preload rows ahead (concurrent) - use volatile globals
    NSInteger aheadLimit = gPreloadAheadRows;
    NSInteger aheadCount = 0;
    for (NSInteger s = currentSection; s < sections.count && aheadCount < aheadLimit; s++) {
        TiUITableViewSectionProxy *section = sections[s];
        NSInteger sectionRowCount = [(NSArray *)[section rows] count];
        
        for (NSInteger r = (s == currentSection ? currentRow + 1 : 0); r < sectionRowCount && aheadCount < aheadLimit; r++) {
            NSIndexPath *path = [NSIndexPath indexPathForRow:r inSection:s];
            TiUITableViewRowProxy *row = [self rowForIndexPath:path];
            if (row && needsHeightCalc(row)) {
                dispatch_group_async(group, preloadQueue, ^{
                    [self cachedHeightForRow:row indexPath:path];
                });
            }
            aheadCount++;
        }
    }
    
    // Preload rows behind (concurrent)
    NSInteger behindLimit = gPreloadBehindRows;
    NSInteger behindCount = 0;
    for (NSInteger s = currentSection; s >= 0 && behindCount < behindLimit; s--) {
        TiUITableViewSectionProxy *section = sections[s];
        NSArray *rows = [section rows];
        NSInteger sectionRowCount = rows.count;
        
        for (NSInteger r = (s == currentSection ? currentRow - 1 : sectionRowCount - 1); r >= 0 && behindCount < behindLimit; r--) {
            NSIndexPath *path = [NSIndexPath indexPathForRow:r inSection:s];
            TiUITableViewRowProxy *row = [self rowForIndexPath:path];
            if (row && needsHeightCalc(row)) {
                dispatch_group_async(group, preloadQueue, ^{
                    [self cachedHeightForRow:row indexPath:path];
                });
            }
            behindCount++;
        }
    }
    
    // Non-blocking: notify when done instead of waiting
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
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

#pragma mark - Image Preloading

- (void)enableImagePreloading
{
    // Use UITableView prefetching API (iOS 15+)
    if (@available(iOS 15.0, *)) {
        tableview.prefetchingEnabled = YES;
    }
    
    NSLog(@"[TableViewExtension/Smooth] Image preloading enabled (including nested views)");
}

- (void)tableView:(UITableView *)tableView prefetchRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
    // Preload images from upcoming rows
    for (NSIndexPath *path in indexPaths) {
        TiUITableViewRowProxy *row = [self rowForIndexPath:path];
        if (row) {
            // Get row view hierarchy
            NSArray *rowViews = [row valueForUndefinedKey:@"views"];
            if (rowViews) {
                [self preloadImagesFromViews:rowViews];
            }
        }
    }
}

- (void)preloadImagesFromViews:(NSArray *)views
{
    for (id view in views) {
        // Check if it's an ImageView
        if ([view isKindOfClass:[UIImageView class]]) {
            id imageValue = [view valueForUndefinedKey:@"image"];
            if ([imageValue isKindOfClass:[NSString class]]) {
                NSString *path = (NSString *)imageValue;
                // Use imageWithContentsOfFile: instead of imageNamed: for thread safety.
                // imageNamed: is not guaranteed to be thread-safe and may hit the main thread internally.
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                    // Try resolving as absolute path first, then as bundle resource
                    UIImage *image = nil;
                    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
                        image = [UIImage imageWithContentsOfFile:path];
                    } else {
                        NSString *bundlePath = [[NSBundle mainBundle] pathForResource:path ofType:nil];
                        if (bundlePath) {
                            image = [UIImage imageWithContentsOfFile:bundlePath];
                        }
                    }
                    (void)image; // Preload into memory; assignment suppresses unused-variable warning
                });
            }
        }

        // Recursively check subviews
        NSArray *subviews = [view valueForUndefinedKey:@"subviews"];
        if (subviews) {
            [self preloadImagesFromViews:subviews];
        }
    }
}

#pragma mark - Memory Warning Handling

- (void)enableMemoryWarningHandling
{
    // Register for memory warnings
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didReceiveMemoryWarning)
                                                 name:UIApplicationDidReceiveMemoryWarningNotification
                                               object:nil];
    
    NSLog(@"[TableViewExtension/Smooth] Memory warning handling enabled");
}

- (void)didReceiveMemoryWarning
{
    // Clear caches to free memory - thread-safe
    if (sharedHeightCache) {
        os_unfair_lock_lock(cacheLock);
        NSUInteger beforeCount = heightCacheEntryCount;
        [sharedHeightCache removeAllObjects];
        [sharedTemplateCache removeAllObjects];
        heightCacheEntryCount = 0;
        heightCacheTotalCost = 0;
        templateCacheEntryCount = 0;
        templateCacheTotalCost = 0;
        os_unfair_lock_unlock(cacheLock);
        
        NSLog(@"[TableViewExtension/Smooth] Memory warning: cleared %ld height cache entries", beforeCount);
    }
}

#pragma mark - Section Header/Footer Caching

- (void)enableSectionHeaderFooterCachingWithHeaderHeight:(CGFloat)headerHeight
                                             footerHeight:(CGFloat)footerHeight
{
    if (headerHeight > 0) {
        tableview.estimatedSectionHeaderHeight = headerHeight;
        NSLog(@"[TableViewExtension/Smooth] Section header caching enabled: %.1f", headerHeight);
    }
    
    if (footerHeight > 0) {
        tableview.estimatedSectionFooterHeight = footerHeight;
        NSLog(@"[TableViewExtension/Smooth] Section footer caching enabled: %.1f", footerHeight);
    }
    
    // Enable caching for headers/footers
    if (headerHeight > 0 || footerHeight > 0) {
        tableview.estimatedSectionHeaderHeight = headerHeight > 0 ? headerHeight : 44;
        tableview.estimatedSectionFooterHeight = footerHeight > 0 ? footerHeight : 22;
    }
}

- (void)invalidateCacheForRow:(TiUITableViewRowProxy *)row
{
    if (sharedHeightCache) {
        os_unfair_lock_lock(cacheLock);
        // Invalidate template cache entry only if it exists
        NSNumber *templateKey = [self templateKeyForRow:row];
        if ([sharedTemplateCache objectForKey:templateKey] != nil) {
            [sharedTemplateCache removeObjectForKey:templateKey];
            templateCacheEntryCount--;
            templateCacheTotalCost -= sizeof(CGFloat);
        }

        // Also invalidate all indexPath entries for this row
        for (NSIndexPath *path in [tableview indexPathsForVisibleRows]) {
            TiUITableViewRowProxy *rowProxy = [self rowForIndexPath:path];
            if (rowProxy == row) {
                NSNumber *key = [self cacheKeyForIndexPath:path];
                if ([sharedHeightCache objectForKey:key] != nil) {
                    [sharedHeightCache removeObjectForKey:key];
                    heightCacheEntryCount--;
                    heightCacheTotalCost -= sizeof(CGFloat);
                }
            }
        }
        os_unfair_lock_unlock(cacheLock);
    }
}

#pragma mark - Performance Logging

- (void)logPerformance
{
    NSUInteger totalRequests = cacheHitCount + cacheMissCount;
    CGFloat hitRate = totalRequests > 0 ? (CGFloat)cacheHitCount / totalRequests * 100.0 : 0;
    CGFloat avgTime = cacheMissCount > 0 ? totalHeightCalculationTime / cacheMissCount : 0;
    
    NSUInteger totalCells = cellReuseCount + cellCreateCount;
    CGFloat reuseRate = totalCells > 0 ? (CGFloat)cellReuseCount / totalCells * 100.0 : 0;
    
    NSLog(@"[TableViewExtension/Smooth] === Performance Report ===");
    NSLog(@"[TableViewExtension/Smooth] Scroll FPS: %.1f (frames: %ld)", fps, (long)frameCount);
    NSLog(@"[TableViewExtension/Smooth] Cache Hit Rate: %.1f%% (%ld/%ld, %ld template)", 
         hitRate, (long)cacheHitCount, (long)totalRequests, (long)templateHitCount);
    NSLog(@"[TableViewExtension/Smooth] Avg Height Calc: %.2fms (total: %.2fms)", avgTime, totalHeightCalculationTime);
    NSLog(@"[TableViewExtension/Smooth] Cache Size: %ld entries (%.1fKB), Templates: %ld (%.1fKB)",
         (long)heightCacheEntryCount, 
         (double)heightCacheTotalCost / 1024.0,
         (long)templateCacheEntryCount,
         (double)templateCacheTotalCost / 1024.0);
    NSLog(@"[TableViewExtension/Smooth] Cell Reuse: %ld reused, %ld created (%.1f%% reuse rate)",
         (long)cellReuseCount, (long)cellCreateCount, reuseRate);
    NSLog(@"[TableViewExtension/Smooth] ============================");
}

- (NSDictionary *)getPerformanceStats
{
    NSUInteger totalCells = cellReuseCount + cellCreateCount;
    CGFloat reuseRate = totalCells > 0 ? (CGFloat)cellReuseCount / totalCells * 100.0 : 0;
    
    return @{
        @"fps": @(fps),
        @"frameCount": @(frameCount),
        @"cacheEntries": @(sharedHeightCache ? heightCacheEntryCount : 0),
        @"cellReuseCount": @(cellReuseCount),
        @"cellCreateCount": @(cellCreateCount),
        @"cellReuseRate": @(reuseRate)
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
    
    // Check row height type: fixed number, SIZE, FILL, or percentage
    id heightValue = [row valueForUndefinedKey:@"height"];
    NSString *heightStr = heightValue ? [heightValue description] : @"";
    
    // Fast path: fixed height (e.g., height:69)
    // Skip all caching and layout calculation
    if (![heightStr isEqualToString:@"SIZE"] && 
        ![heightStr isEqualToString:@"FILL"] && 
        ![heightStr isEqualToString:@""] &&
        ![heightStr hasSuffix:@"%"]) {
        CGFloat fixedHeight = [heightValue floatValue];
        if (fixedHeight > 0) {
            return fixedHeight;
        }
    }
    
    // Slow path: SIZE, FILL, or percentage → use cache or calculate
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

- (NSDictionary *)eventObjectForScrollView:(UIScrollView *)scrollView
{
    // Get scroll velocity from pan gesture recognizer
    UIPanGestureRecognizer *pan = scrollView.panGestureRecognizer;
    CGPoint velocity = [pan velocityInView:scrollView.superview];
    
    return [NSDictionary dictionaryWithObjectsAndKeys:
        [TiUtils pointToDictionary:scrollView.contentOffset], @"contentOffset",
        [TiUtils sizeToDictionary:scrollView.contentSize], @"contentSize",
        [TiUtils sizeToDictionary:tableview.bounds.size], @"size",
        [TiUtils pointToDictionary:velocity], @"velocity",
        nil];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if ([self.nextResponder respondsToSelector:@selector(scrollViewDidScroll:)]) {
        [(id)self.nextResponder scrollViewDidScroll:scrollView];
    }
    
    CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
    
    // Throttle scroll processing to ~30fps to reduce main thread load
    static CFAbsoluteTime lastScrollProcessTime = 0;
    if (currentTime - lastScrollProcessTime < 0.032) {
        return; // Skip this frame
    }
    lastScrollProcessTime = currentTime;
    
    frameCount++;
    
    // Adaptive preload: adjust based on scroll velocity (throttled to every 3rd frame)
    if (frameCount % 3 == 0) {
        UIPanGestureRecognizer *pan = scrollView.panGestureRecognizer;
        CGPoint velocity = [pan velocityInView:scrollView.superview];
        lastScrollVelocity = velocity.y;
        
        CGFloat speed = fabs(lastScrollVelocity);
        
        // Update volatile globals (main thread only)
        if (speed > 1000) {
            gPreloadAheadRows = 10;
            gPreloadBehindRows = 5;
        } else if (speed > 500) {
            gPreloadAheadRows = 7;
            gPreloadBehindRows = 4;
        } else {
            gPreloadAheadRows = 5;
            gPreloadBehindRows = 3;
        }
    }
    
    // Store frame timestamp for rolling FPS calculation
    frameTimestamps[fpsSampleIndex % kFPSSampleWindow] = currentTime;
    fpsSampleIndex++;
    
    // Calculate smoothed FPS from rolling window with better guards
    if (fpsSampleIndex >= kFPSSampleWindow) {
        CFAbsoluteTime oldestTime = frameTimestamps[(fpsSampleIndex - kFPSSampleWindow) % kFPSSampleWindow];
        CFAbsoluteTime newestTime = frameTimestamps[(fpsSampleIndex - 1) % kFPSSampleWindow];
        CGFloat totalTime = (newestTime - oldestTime) * 1000.0;
        if (totalTime > 1.0) { // Guard: must be at least 1ms to avoid division issues
            fps = (CGFloat)(kFPSSampleWindow - 1) / (totalTime / 1000.0);
        }
    }
    
    // Fire scroll event to JavaScript
    if ([self.proxy _hasListeners:@"scroll"]) {
        [self.proxy fireEvent:@"scroll" withObject:[self eventObjectForScrollView:scrollView]];
    }
    
    // Trigger preload queue
    [self preloadRowHeightsIfNeeded];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if ([self.nextResponder respondsToSelector:@selector(scrollViewDidEndDragging:willDecelerate:)]) {
        [(id)self.nextResponder scrollViewDidEndDragging:scrollView willDecelerate:decelerate];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    if ([self.nextResponder respondsToSelector:@selector(scrollViewDidEndDecelerating:)]) {
        [(id)self.nextResponder scrollViewDidEndDecelerating:scrollView];
    }
    
    // Fire scrollend event to JavaScript
    if ([self.proxy _hasListeners:@"scrollend"]) {
        [self.proxy fireEvent:@"scrollend" withObject:[self eventObjectForScrollView:scrollView]];
    }
}

@end
