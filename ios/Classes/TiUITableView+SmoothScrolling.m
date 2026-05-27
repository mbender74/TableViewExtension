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

// Debug logging macro
#ifndef DEBUG
#define SmoothLog(fmt, ...) do {} while(0)
#else
#define SmoothLog(fmt, ...) NSLog(@"[TableViewExtension/Smooth] " fmt, ##__VA_ARGS__)
#endif

// Static cache for row heights
static NSCache<NSString *, NSNumber *> *sharedHeightCache;

@implementation TiUITableView (SmoothScrolling)

#pragma mark - Height Caching

- (void)enableHeightCaching
{
    if (sharedHeightCache == nil) {
        sharedHeightCache = [[NSCache alloc] init];
        sharedHeightCache.countLimit = 500;
        sharedHeightCache.totalCostLimit = 10 * 1024 * 1024; // 10MB
        SmoothLog(@"Height cache initialized (limit: 500 entries, 10MB)");
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
            @"totalCost": @0
        };
    }
    
    return @{
        @"hits": @([sharedHeightCache totalCount] - [sharedHeightCache count]),
        @"misses": @([sharedHeightCache count]),
        @"count": @([sharedHeightCache count]),
        @"totalCost": @([sharedHeightCache totalCost])
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
        SmoothLog(@"Cache HIT for row %ld: %.1f", (long)indexPath.row, cached.floatValue);
        return cached.floatValue;
    }
    
    SmoothLog(@"Cache MISS for row %ld, calculating...", (long)indexPath.row);
    
    // Calculate height
    CGFloat width = [row sizeWidthForDecorations:[self computeRowWidth] forceResizing:YES];
    CGFloat height = [row rowHeight:width];
    
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
