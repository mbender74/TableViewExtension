//  TiUITableView+SmoothScrolling.h
//  TableViewExtension
//
//  Smooth scrolling optimizations: height caching, estimated heights, prefetching
//

#import "DeMarcbenderTableviewextensionModule.h"
#import "TiUITableView.h"

// Cell reuse statistics (shared across files)
extern NSUInteger cellReuseCount;
extern NSUInteger cellCreateCount;

// Scroll event throttling (shared with Snappy)
extern CFAbsoluteTime lastRowVisibleTime;
extern CFAbsoluteTime lastRowNotVisibleTime;
extern const CGFloat kRowVisibleThrottleInterval;

// ProMotion support (shared across files)
extern BOOL gPromotionEnabled;
extern CGFloat gThrottleInterval;  // adaptive: 0.016s (120Hz) or 0.032s (60Hz)

@interface TiUITableView (SmoothScrolling)

#pragma mark - Height Caching

/**
 * Enable row height caching to avoid recalculating heights during scrolling.
 * Cache is automatically invalidated when rows are inserted/removed.
 */
- (void)enableHeightCaching;

/**
 * Clear the entire height cache. Call this after significant data changes.
 */
- (void)invalidateHeightCache;

/**
 * Invalidate cache for a specific row index path.
 */
- (void)invalidateHeightCacheForIndexPath:(NSIndexPath *)indexPath;

/**
 * Get cache statistics (hits, misses, size, performance metrics).
 * Returns NSDictionary with keys:
 * - hits, misses, count, totalCost
 * - hitRate (percentage)
 * - avgCalculationTime (ms per height calculation)
 * - totalCalculationTime (ms)
 */
- (NSDictionary *)getCacheStats;

/**
 * Get scroll performance statistics.
 * Returns NSDictionary with keys: fps, frameCount, cacheEntries
 */
- (NSDictionary *)getPerformanceStats;

/**
 * Get current scroll FPS.
 */
- (CGFloat)currentFPS;

/**
 * Log current performance stats to console (NSLog).
 * Call this from JavaScript to see real-time metrics.
 */
- (void)logPerformance;

#pragma mark - Estimated Heights

/**
 * Enable estimated row heights for lazy layout.
 * @param estimatedHeight The estimated height value to use
 */
- (void)enableEstimatedHeights:(CGFloat)estimatedHeight;

#pragma mark - Prefetching

/**
 * Enable async row preparation for smoother scrolling.
 */
- (void)enablePrefetching;

/**
 * Enable image preloading for visible rows to prevent scroll jank.
 * Proactively loads images for rows just outside the visible area.
 */
- (void)enableImagePreloading;

/**
 * Enable memory warning handling to clear caches when memory is low.
 */
- (void)enableMemoryWarningHandling;

/**
 * Enable height caching for section headers and footers.
 * @param headerHeight Estimated header height (0 to disable)
 * @param footerHeight Estimated footer height (0 to disable)
 */
- (void)enableSectionHeaderFooterCachingWithHeaderHeight:(CGFloat)headerHeight
                                             footerHeight:(CGFloat)footerHeight;

/**
 * Invalidate cache for a specific row when its content changes.
 */
- (void)invalidateCacheForRow:(TiUITableViewRowProxy *)row;

/**
 * Clean up all caches and the lock. Call this when the module is being
 * shut down or uninstalled to prevent memory leaks.
 */
+ (void)cleanupCaches;

@end
