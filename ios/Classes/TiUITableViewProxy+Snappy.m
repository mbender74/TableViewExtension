//
//  TiUITableViewRowProxy+WithVisibility.m
//  TableViewRowExtension
//
//  Created by Matteo De Rose on 04/12/15.
//
//

#define USE_TI_UITABLEVIEW

#ifndef USE_TI_UISEARCHBAR
#define USE_TI_UISEARCHBAR
#endif

#import "TiUITableViewProxy.h"
#import "TiUITableViewProxy+Snappy.h"
#import "TiUITableView+Snappy.h"
#import "TiUITableView+SmoothScrolling.h"

@interface TiUITableViewProxy (Snappy)
//-(NSInteger)isVisible:(id)args;
//-(NSInteger)getTopOffset:(id)args;
@end


@implementation TiUITableViewProxy (Snappy)

USE_VIEW_FOR_CONTENT_HEIGHT


#pragma mark Internal

- (NSString *)apiName
{
  return @"Ti.UI.TableViewExtended";
}

#pragma mark Public APIs

//- (id)contentInsets
//{
//
//    UIEdgeInsets tableViewContentInsets = [(TiUITableView *)[self view] tableView].contentInset;
//    CGFloat *topInset = &tableViewContentInsets.top;
//    CGFloat *bottomInset = &tableViewContentInsets.bottom;
//    CGFloat *leftInset = &tableViewContentInsets.left;
//    CGFloat *rightInset = &tableViewContentInsets.right;
//
//    NSMutableDictionary *contentDictionary = [[NSMutableDictionary alloc]init];
//    [contentDictionary setValue:(id)topInset forKey:@"top"];
//    [contentDictionary setValue:(id)bottomInset forKey:@"bottom"];
//    [contentDictionary setValue:(id)leftInset forKey:@"left"];
//    [contentDictionary setValue:(id)rightInset forKey:@"right"];
//
//    return contentDictionary;
//   // return [(TiUITableView *)[self view] contentInsets];
//   // return self.contentInsets;
//}
    
- (void)setContentInsets:(id)args
{
  ENSURE_UI_THREAD(setContentInsets, args);
  id arg1;
  id arg2;
  if ([args isKindOfClass:[NSDictionary class]]) {
    arg1 = args;
    arg2 = [NSDictionary dictionary];
  } else {
    arg1 = [args objectAtIndex:0];
    arg2 = [args count] > 1 ? [args objectAtIndex:1] : [NSDictionary dictionary];
  }
  [(TiUITableView *)[self view] setContentInset:arg1 withObject:arg2];
}


-(void)handleTouches:(id)value
{
    [(TiUITableView *)[self view] handleTouches:value];
}

- (void)setEstimatedRowHeight
{
    // Set estimatedRowHeight to 0 for consistent height calculation (SDK behavior)
    [(TiUITableView *)[self view] setEstimatedRowHeight:0];
}

- (id)logPerformance:(id)args
{
    TiUITableView *table = (TiUITableView *)[self view];
    
    NSLog(@"[TableViewExtension/Smooth] === Performance Report ===");
    NSLog(@"[TableViewExtension/Smooth] TableView: %@", table);
    NSLog(@"[TableViewExtension/Smooth] UITableView: %@", [table tableView]);
    NSLog(@"[TableViewExtension/Smooth] Content Size: {%f, %f}", 
         [table tableView].contentSize.width, [table tableView].contentSize.height);
    NSLog(@"[TableViewExtension/Smooth] ============================");
    
    return nil;
}

//-(void)appendRowBeforeRow:(id)newRow
//{
//    [(TiUITableView *)[self view] appendRowBefore:newRow];
//}


@end

