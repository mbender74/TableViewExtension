//  TiUITableViewProxy+SmoothScrolling.m
//  TableViewExtension
//
//  JavaScript API for smooth scrolling features
//

#define USE_TI_UITABLEVIEW

#import "TiUITableViewProxy+SmoothScrolling.h"
#import "TiUITableView+SmoothScrolling.h"
#import "TiUtils.h"

@implementation TiUITableViewProxy (SmoothScrolling)

#pragma mark Internal

- (NSString *)apiName
{
  return @"Ti.UI.TableViewSmooth";
}

#pragma mark - JavaScript Properties

- (void)setEnableHeightCaching:(id)value
{
    BOOL enabled = [TiUtils boolValue:value];
    if (enabled) {
        [(TiUITableView *)[self view] enableHeightCaching];
    }
}

- (void)setEstimatedRowHeight:(id)value
{
    CGFloat estimatedHeight = [TiUtils floatValue:value];
    if (estimatedHeight > 0) {
        [(TiUITableView *)[self view] enableEstimatedHeights:estimatedHeight];
    }
}

- (void)setPrefetchEnabled:(id)value
{
    BOOL enabled = [TiUtils boolValue:value];
    if (enabled) {
        [(TiUITableView *)[self view] enablePrefetching];
    }
}

- (void)setImagePreloadEnabled:(id)value
{
    BOOL enabled = [TiUtils boolValue:value];
    if (enabled) {
        [(TiUITableView *)[self view] enableImagePreloading];
    }
}

- (void)setMemoryWarningHandling:(id)value
{
    BOOL enabled = [TiUtils boolValue:value];
    if (enabled) {
        [(TiUITableView *)[self view] enableMemoryWarningHandling];
    }
}

- (void)setSectionHeaderFooterCaching:(id)value
{
    BOOL enabled = [TiUtils boolValue:value];
    if (enabled) {
        // Default header/footer heights
        [(TiUITableView *)[self view] enableSectionHeaderFooterCachingWithHeaderHeight:44
                                                                          footerHeight:22];
    }
}

- (void)setSmoothScrolling:(id)value
{
    // Convenience property: enables all optimizations
    BOOL enabled = [TiUtils boolValue:value];
    if (enabled) {
        [(TiUITableView *)[self view] enableHeightCaching];
        [(TiUITableView *)[self view] enableEstimatedHeights:80]; // Default 80pt
        [(TiUITableView *)[self view] enablePrefetching];
    }
}

#pragma mark - JavaScript Methods

- (void)invalidateHeightCache:(id)args
{
    [(TiUITableView *)[self view] invalidateHeightCache];
}

- (NSDictionary *)getCacheStats:(id)args
{
    return [(TiUITableView *)[self view] getCacheStats];
}

- (NSDictionary *)getPerformanceStats:(id)args
{
    return [(TiUITableView *)[self view] getPerformanceStats];
}

- (id)logPerformance:(id)args
{
    [(TiUITableView *)[self view] logPerformance];
    return nil;
}

@end
