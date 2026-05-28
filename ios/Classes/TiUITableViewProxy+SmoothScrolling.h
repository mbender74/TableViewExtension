//  TiUITableViewProxy+SmoothScrolling.h
//  TableViewExtension
//
//  JavaScript API for smooth scrolling features
//

#define USE_TI_UITABLEVIEW

#import "DeMarcbenderTableviewextensionModule.h"
#import <TitaniumKit/TiViewProxy.h>
#import "TiUITableViewProxy.h"

@interface TiUITableViewProxy (SmoothScrolling)

- (void)setEnableHeightCaching:(id)value;
- (void)setEstimatedRowHeight:(id)value;
- (void)setPrefetchEnabled:(id)value;
- (void)setImagePreloadEnabled:(id)value;
- (void)setMemoryWarningHandling:(id)value;
- (void)setSectionHeaderFooterCaching:(id)value;
- (void)setSmoothScrolling:(id)value;
- (void)invalidateHeightCache:(id)args;
- (NSDictionary *)getCacheStats:(id)args;
- (NSDictionary *)getPerformanceStats:(id)args;
- (id)logPerformance:(id)args;

@end
