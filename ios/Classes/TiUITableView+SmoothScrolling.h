//  TiUITableView+SmoothScrolling.h
//  TableViewExtension
//
//  Smooth scrolling optimizations: height caching, estimated heights, prefetching
//

#import "DeMarcbenderTableviewextensionModule.h"
#import "TiUITableView.h"

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

@end
