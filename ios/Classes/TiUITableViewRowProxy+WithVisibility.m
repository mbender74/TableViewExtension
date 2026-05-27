//
//  TiUITableViewRowProxy+WithVisibility.m
//  TableViewRowExtension
//
//  Created by Matteo De Rose on 04/12/15.
//
//
#define USE_TI_UITABLEVIEW
#import "TiViewProxy.h"
#import "TiUITableView.h"
#import "TiUITableViewProxy.h"
#import "TiUITableViewRowProxy+WithVisibility.h"
#import <TitaniumKit/TiDimension.h>
#import <TitaniumKit/TiViewProxy.h>
#import "TiUITableViewSectionProxy.h"
#import "TiUITableViewRowProxy.h"

@interface TiUITableViewRowProxy (WithVisibility)

@end

@implementation TiUITableViewRowProxy (WithVisibility)

-(NSInteger)getTopOffset:(id)args
{
    
    NSInteger index = [table indexForRow:self];
    NSIndexPath* path = [table indexPathFromInt:index];
    CGRect rectOfCellInTableView = [[table tableView] rectForRowAtIndexPath: path];
    CGRect rectOfCellInSuperview = [[table tableView] convertRect: rectOfCellInTableView toView: [[table tableView] superview]];
    return rectOfCellInSuperview.origin.y;
}

-(NSInteger)isVisible:(id)args
{
    NSInteger index = [table indexForRow:self];
    NSIndexPath* path = [table indexPathFromInt:index];
    
    if(![[table tableView].indexPathsForVisibleRows containsObject:path])
    {
        return 0;
    } else {
        return 1;
    }
}

- (BOOL)reusable
{
    return [TiUtils boolValue:[self valueForKey:@"isReusable"] def:NO];
}


- (void)setSubView:(id)value
{
    dispatch_async(dispatch_get_main_queue(), ^{

       //     [UIView performWithoutAnimation:^{

//    if (tableClass == nil) {
//        //NSLog(@"row.tableClass NULL");
//      // must use undefined key since class is a special
//      // property on the NSObject class
//      id value = [self valueForUndefinedKey:@"className"];
//      if (value == nil) {
//          NSLog(@"row.tableClass value NULL");
//
//        value = defaultRowTableClass;
//      }
//      else {
//          defaultRowTableClass = value;
//      }
//      // tableClass must always be a string so we coerce it
//      tableClass = [[TiUtils stringValue:value] retain];
//      self.tableClass = tableClass;
//    }
    //self.reusable = YES;
       // [self add:value];

            

//
    if (![self valueForUndefinedKey:@"height"] || [[value valueForUndefinedKey:@"height"] isEqual:@"SIZE"]) {
       // NSLog(@"height not set OR SIZE");

        int topMargin = [TiUtils intValue:[value valueForUndefinedKey:@"top"] def:0];
        int bottomMargin = [TiUtils intValue:[value valueForUndefinedKey:@"bottom"] def:0];
        int myViewHeight = [TiUtils intValue:[value valueForUndefinedKey:@"height"] def:0];

        CGFloat viewWidth = 0.0;
        int viewHeight = 0;

        
        [self add:value];
//        [(TiViewProxy*)value windowWillOpen];
//
//        NSArray *children = [(TiViewProxy*)value children];
//        for (TiViewProxy *proxy in children) {
//            [proxy windowWillOpen];
//            [proxy reposition];
//            //[proxy windowDidOpen];
//            [proxy layoutChildrenIfNeeded];
//        }


       // NSLog(@"\n\nview margins %i %i  height :%i",topMargin,bottomMargin,myViewHeight);
       // NSLog(@"view id %@",[TiUtils stringValue:[value valueForUndefinedKey:@"elementId"]]);
        if ([[value valueForUndefinedKey:@"height"] isEqual:@"SIZE"] || ![self valueForUndefinedKey:@"height"]) {

            viewWidth = [value autoWidthForSize:CGSizeMake(1000, 1000)];
           // [self replaceValue:[NSNumber numberWithInt:viewWidth] forKey:@"width" notification:NO];

            CGFloat calculatedRowHeight = ceil([self rowHeight:viewWidth]);

       //     NSLog(@"calculatedRowHeight %f",calculatedRowHeight);

            viewHeight = (int) calculatedRowHeight;
          //  NSLog(@"viewHeight %i",viewHeight);

           // viewHeight = [value autoHeightForSize:CGSizeMake(viewWidth, 0)] + 10;
           // NSLog(@"view.height calculated %i",viewHeight);

        }
        else {
            viewHeight = [TiUtils intValue:[value valueForKey:@"height"]] + topMargin + bottomMargin;
           // NSLog(@"view.height preSet %i",viewHeight);
        }

    //    int viewHeightRaw = viewHeight;
    //    int viewHeightWithMargins = viewHeight + (topMargin + bottomMargin);
//        [value replaceValue:[NSNumber numberWithInt:viewHeight] forKey:@"height" notification:NO];
        height = [TiUtils dimensionValue:[NSNumber numberWithInt:viewHeight]];
        [self replaceValue:[NSNumber numberWithInt:viewHeight] forKey:@"height" notification:NO];

        //
    }
    else {
        [self add:value];
//        [(TiViewProxy*)value windowWillOpen];
//
//        NSArray *children = [(TiViewProxy*)value children];
//        for (TiViewProxy *proxy in children) {
//            [proxy windowWillOpen];
//            [proxy reposition];
//            //[proxy windowDidOpen];
//            [proxy layoutChildrenIfNeeded];
//        }

    }
                
                
//    [(TiViewProxy*)value reposition];
//
//    [(TiViewProxy*)value windowDidOpen];



   // [value replaceValue:[NSNumber numberWithInt:viewHeightRaw] forKey:@"height" notification:NO];

    
    //    [[self currentRowContainerView].prox addSubview:];
                
          //  }];
                
    });

}




@end

