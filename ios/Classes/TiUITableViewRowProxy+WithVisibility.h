//
//  TiUITableViewRowProxy+WithVisibility.h
//  TableViewRowExtension
//
//  Created by Matteo De Rose on 04/12/15.
//
//
#define USE_TI_UITABLEVIEW
#import "DeMarcbenderTableviewextensionModule.h"
#import "TiUITableView.h"
#import "TiUITableViewProxy.h"
#import "TiUITableViewRowProxy.h"
#import "TiUITableView+Snappy.h"
#import "TiUITableViewProxy+Snappy.h"
#import <TitaniumKit/TiDimension.h>
#import <TitaniumKit/TiViewProxy.h>
#import "TiUITableViewSectionProxy.h"


@class TiUITableViewRowContainer;


@interface TiUITableViewRowProxy (WithVisibility){
}
#pragma mark Public APIs
-(NSInteger)isVisible:(id)args;
-(NSInteger)getTopOffset:(id)args;
- (void)setOpaqueRow:(id)value;
- (void)prepareTableRowForReuse;
@end
