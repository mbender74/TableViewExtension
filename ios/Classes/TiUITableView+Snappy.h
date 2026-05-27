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
#import "TiUITableViewRowProxy.h"
#import "TiUITableViewSectionProxy.h"
#import <TitaniumKit/TiViewProxy.h>


@interface TiUITableView (Snappy)
//@property(nonatomic,readwrite) id contentInsets;
-(void)setContentInset:(id)value withObject:(id)props;
-(void)appendRowBeforeRow:(id)newRow;
-(void)appendRowFast:(id)dict;
-(void)setOpaqueRows:(BOOL)opaque;
-(void)setEstimatedRowHeight:(CGFloat)height;
-(void)handleTouches:(id)value;
@end
