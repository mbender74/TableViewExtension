//
//  TiUITableViewRowProxy+WithVisibility.m
//  TableViewRowExtension
//
//  Created by Matteo De Rose on 04/12/15.
//
//

#define USE_TI_UITABLEVIEW

#import "TiUITableView.h"
#import "TiUITableView+Snappy.h"
#import "TiUITableViewSectionProxy.h"
#import "TiUITableViewRowProxy.h"
#import "TiUITableViewRowProxy+WithVisibility.h"

// Scroll event throttling
static CFAbsoluteTime lastRowVisibleTime = 0;
static const CGFloat kRowVisibleThrottleInterval = 0.032; // ~30fps (reduced from 60fps to prevent jank)

// Debug logging macro
#ifndef DEBUG
#define TableViewExtensionLog(fmt, ...) do {} while(0)
#else
#define TableViewExtensionLog(fmt, ...) NSLog(@"[TableViewExtension] " fmt, ##__VA_ARGS__)
#endif

@interface TiUITableView (SnappyMethods)
- (void)insertRow:(TiUITableViewRowProxy *)row before:(TiUITableViewRowProxy *)before;
- (TiUITableViewRowProxy *)rowForIndexPath:(NSIndexPath *)indexPath;
- (TiUITableViewSectionProxy *)sectionForIndex:(NSInteger)sectionIndex;
- (NSInteger)rowIndexForIndexPath:(NSIndexPath *)indexPath andSections:(NSArray *)sections;
- (CGFloat)computeRowWidth;
@end

@implementation TiUITableView (Snappy)

// Configurable constants
static const CGFloat kRoundingHeight = 160;           // Snapping tolerance in points
static const CGFloat kDecelerationRateSlow = 0.9975;
static const CGFloat kDecelerationRateFast = 0.9980;
static const CGFloat kDefaultAnimationDuration = 180; // ms

#define RECOGNIZE_SIMULTANEOUSLY_PAN    (1 << 15)
UIEdgeInsets tableContentInsets;

typedef struct {
    float x;
    float y;
    CGPoint memory;
} MemoryPoint;



-(void)runBlock:(void (^)(void))block
{
    block();
}
-(void)runAfterDelay:(CGFloat)delay block:(void (^)(void))block
{
    void (^block_)(void) = [block copy];
    [self performSelector:@selector(runBlock:) withObject:block_ afterDelay:delay];
}


- (void)setScrollSlow_:(id)args
{
  UITableView *table = [self tableView];
    BOOL scrollSlow = [TiUtils boolValue:args];
    if (scrollSlow == YES){
      // NSLog ( @"\n SCROLL SLOW ");
        //0.993840
//        CGFloat decelerationRate = 0.994090;
//        //            [self setValue:[NSValue valueWithCGSize:CGSizeMake(decelerationRate,decelerationRate)] forKey:@"_decelerationFactor"];
//        [self setValue:[NSValue valueWithCGSize:CGSizeMake(decelerationRate,decelerationRate)] forKey:@"_decelerationFactor"];
//
//         NSLog ( @"\n SCROLL SLOW %f",decelerationRate);
//
//        table.decelerationRate = decelerationRate;
        CGFloat decelerationRate = kDecelerationRateSlow;

        //CGFloat decelerationRate = UIScrollViewDecelerationRateFast +(UIScrollViewDecelerationRateNormal - UIScrollViewDecelerationRateFast) * .52;
        [table setValue:[NSValue valueWithCGSize:CGSizeMake(decelerationRate,decelerationRate)] forKey:@"_decelerationFactor"];
    }
    else {
       // NSLog ( @"\n SCROLL FAST ");
//        CGFloat decelerationRate = UIScrollViewDecelerationRateNormal;
//
//        NSLog ( @"\n SCROLL SLOW %f",decelerationRate);
//
//        table.decelerationRate = UIScrollViewDecelerationRateNormal;
        CGFloat decelerationRate = kDecelerationRateFast;

        //CGFloat decelerationRate = UIScrollViewDecelerationRateFast +(UIScrollViewDecelerationRateNormal - UIScrollViewDecelerationRateFast) * .52;
        [table setValue:[NSValue valueWithCGSize:CGSizeMake(decelerationRate,decelerationRate)] forKey:@"_decelerationFactor"];
    }



//////      //0.993840
//////
//////      //0.995160
//    @try {
//        CGFloat decelerationRate = 0.997600;
//
//        //CGFloat decelerationRate = UIScrollViewDecelerationRateFast +(UIScrollViewDecelerationRateNormal - UIScrollViewDecelerationRateFast) * .52;
//        [tableview setValue:[NSValue valueWithCGSize:CGSizeMake(decelerationRate,decelerationRate)] forKey:@"_decelerationFactor"];
//        //NSLog ( @"\n SCROLL SLOW %f",decelerationRate);
//
//    }
//    @catch (NSException *exception) {
//        // if they modify the way it works under us.
//       // NSLog ( @"\n SCROLL Exception %@",exception);
//
//    }




}


- (void)setEnableBounce_:(id)value
{
    tableview.bounces = [TiUtils boolValue:value];
    tableview.alwaysBounceVertical = [TiUtils boolValue:value];
}
- (void)setAalwaysBounceVertical_:(id)value
{
    tableview.alwaysBounceVertical = [TiUtils boolValue:value];
}
- (void)setDirectionalLockEnabled_:(id)value
{
    tableview.directionalLockEnabled = [TiUtils boolValue:value];
    tableview.delaysContentTouches = ![TiUtils boolValue:value];

}
- (void)setPaginEnabled_:(id)value
{
    tableview.pagingEnabled = [TiUtils boolValue:value];
}

- (void)handlePanGesture:(UIPanGestureRecognizer *)sender
{
   // NSLog(@"[ERROR] handlePanGesture Module:");

    CGPoint translation = [sender translationInView:self.superview];
    CGPoint velocity = [sender velocityInView:self.superview];

    TiPoint *translationPoint = [[TiPoint alloc] initWithPoint:translation];
    TiPoint *velocityPoint = [[TiPoint alloc] initWithPoint:velocity];
    NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:
                          translationPoint, @"translation",
                          velocityPoint, @"velocity", nil];
    if([self.proxy _hasListeners:@"pan"]){
        [self.proxy fireEvent:@"pan" withObject:args];
    }

    if(sender.state == UIGestureRecognizerStateEnded &&
       [self.proxy _hasListeners:@"panend"]){
        [self.proxy fireEvent:@"panend"];
    }
}

- (void)setPanGesture_:(id)value
{
    ENSURE_SINGLE_ARG(value, NSNumber);
    BOOL value_ = [value boolValue];

    if(value_){
        for(UIGestureRecognizer *gesure in self.gestureRecognizers){
            if([gesure isKindOfClass:[UIPanGestureRecognizer class]]){
                return;
            }
        }

        UIPanGestureRecognizer *panGesture =[[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                                    action:@selector(handlePanGesture:)];
        [self addGestureRecognizer:panGesture];

        if(self.tag & RECOGNIZE_SIMULTANEOUSLY_PAN)
        {
            panGesture.delegate = self;
        }
    } else{
        UIGestureRecognizer *panGesture = nil;
        for(UIGestureRecognizer *gesure in self.gestureRecognizers){
            if([gesure isKindOfClass:[UIPanGestureRecognizer class]]){
                panGesture = gesure;
                break;
            }
        }

        panGesture.delegate = nil;

        if(panGesture){
            [self removeGestureRecognizer:panGesture];
        }
    }
}

-(void)handleTouches:(id)value
{
    [self setHandleTouches_:value];
}

- (void)setHandleTouches_:(id)value
{
    tableview.userInteractionEnabled = [TiUtils boolValue:value];
}

//
//
//- (void)cancelGesture:(id)value
//{
//    NSLog(@"[ERROR] cancelGesture_ Module:");
//
//    tableview.panGestureRecognizer.enabled = NO;
//    tableview.panGestureRecognizer.enabled = YES;
//
////    tableview.panGestureRecognizer.enabled = NO;
////
////    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
////        tableview.panGestureRecognizer.enabled = YES;
////        NSLog(@"[ERROR] cancelGesture_ enabled again:");
////
////    });
//
////    [self performTouchEndInView:tableview];
//
////    for (UIGestureRecognizer *gesture in [tableview gestureRecognizers]) {
////        NSLog(@"[ERROR] gesture: %@",gesture);
////        gesture.state = UIGestureRecognizerStateCancelled;
////        gesture.enabled = ![TiUtils boolValue:value];
////        [tableview removeGestureRecognizer:gesture];
////        gesture.enabled = [TiUtils boolValue:value];
////        [tableview addGestureRecognizer:gesture];
////        return;
////    }
//
//}


//- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
//{
//   //<my stuff>
//
//    NSLog(@"[ERROR] touchesMoved Module:");
//
//
//   [super touchesMoved:touches withEvent:event];
//}
//
//- (void)insertRow:(TiUITableViewRowProxy *)row before:(TiUITableViewRowProxy *)before
//{
//    [UIView performWithoutAnimation:^{
//          row.table = self;
//          row.section = before.section;
//          NSMutableArray *rows = [row.section rows];
//          [rows insertObject:row atIndex:row.row];
//          [row.section rememberProxy:row];
//          [row.section reorderRows];
//    }];
//}

#pragma mark Public APIs



-(void)appendRowBeforeRow:(id)newRow
{
   // TiThreadPerformOnMainThread(^{

    dispatch_async(dispatch_get_main_queue(), ^{

      //  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        TiUITableViewRowProxy *row = (TiUITableViewRowProxy *)newRow;
             NSInteger index = row.row;
             TiUITableViewRowProxy *oldrow = [[row.section rows] objectAtIndex:0];
    [self insertRow:row before:oldrow];


             NSIndexPath *path = [NSIndexPath indexPathForRow:row.row inSection:0];
             CGFloat cellheight;

    id rowProxyHeight = [row valueForUndefinedKey:@"height"];
    if (rowProxyHeight && ![rowProxyHeight isEqual:@"SIZE"]) {
            cellheight = [TiUtils floatValue:rowProxyHeight];
            //row.height = [NSNumber numberWithFloat:cellheight];
         //   NSLog(@"row.height %f",cellheight);
         //  NSLog(@"row.height %f",cellheight);

    }
    else {
        //CGRect cellRect = [tableview rectForRowAtIndexPath:path];
        //cellheight = cellRect.size.height;
        cellheight = ceil([row rowHeight:[row sizeWidthForDecorations:[self computeRowWidth] forceResizing:NO]]);
        //row.height = [NSNumber numberWithFloat:cellheight];
        [row replaceValue:[NSNumber numberWithFloat:cellheight] forKey:@"height" notification:NO];
       // NSLog(@"row.height calculated %f",cellheight);
    }


    //  if (![self isSearchStarted]) {

      //  dispatch_async(dispatch_get_main_queue(), ^{

          [UIView performWithoutAnimation:^{
              CGPoint contentOffet = self->tableview.contentOffset;
             // NSLog(@"row.preoffset  %f\n",contentOffet.y);

              CGFloat preoffset = contentOffet.y;
              CGFloat afteroffset = 0;
              afteroffset = preoffset + cellheight;//
              contentOffet.y = afteroffset;
           //   [tableview beginUpdates];
              [self->tableview setContentOffset:contentOffet];
              [self->tableview insertRowsAtIndexPaths:[NSArray arrayWithObject:path] withRowAnimation:UITableViewRowAnimationNone];
           //   [tableview endUpdates];

          }];
//                  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.001 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//                       [(TiUITableViewProxy *)[self proxy] replaceValue:NUMBOOL(NO) forKey:@"isLoading" notification:NO];
//                  });
     // });
 //});
//    }, YES);
    });

}


//- (id)contentInsets_
//{
//
//   // if ([self tableView] != nil) {
//
//        UIEdgeInsets tableViewContentInsets = tableview.contentInset;
//        CGFloat *topInset = &tableViewContentInsets.top;
//        CGFloat *bottomInset = &tableViewContentInsets.bottom;
//        CGFloat *leftInset = &tableViewContentInsets.left;
//        CGFloat *rightInset = &tableViewContentInsets.right;
//
//        NSMutableDictionary *contentDictionary = [[NSMutableDictionary alloc]init];
//        [contentDictionary setValue:(id)topInset forKey:@"top"];
//        [contentDictionary setValue:(id)bottomInset forKey:@"bottom"];
//        [contentDictionary setValue:(id)leftInset forKey:@"left"];
//        [contentDictionary setValue:(id)rightInset forKey:@"right"];
//
//
////        NSData *data = [NSJSONSerialization dataWithJSONObject:contentDictionary options:NSJSONWritingPrettyPrinted error:nil];
////        NSString *jsonStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
//
////        NSDictionary *propertiesDict = @{
////                  @"top" : (id)topInset,
////                  @"bottom" : (id)bottomInset
////        };
////
////
//
////        NSArray *contentInsets = [[NSMutableArray alloc] initWithObjects:propertiesDict, nil];
//     //   return NSString @"{top:"%i",bottom:"%i"}";
////
////  } else {
////      NSDictionary *propertiesDict = @{
////                @"top" : (id)0,
////                @"bottom" : (id)0
////      };
////    //  NSArray *contentInsets = [[NSMutableArray alloc] initWithObjects:propertiesDict, nil];
////      return propertiesDict;
////  }
//
//    return contentDictionary;
//}


-(void)setContentInset:(id)value withObject:(id)props
{

    UIEdgeInsets insets = [TiUtils contentInsets:value];
    UIEdgeInsets insetsScroll = [TiUtils contentInsets:value];



   // self.contentInsets = value;

    int newoffset = [TiUtils intValue:@"newoffset" properties:props def:0];

    int safeArea = [TiUtils intValue:@"safearea" properties:props def:0];

    BOOL animated = [TiUtils boolValue:@"animated" properties:props def:NO];
    BOOL nobottom = [TiUtils boolValue:@"nobottom" properties:props def:NO];
    BOOL noOffset = [TiUtils boolValue:@"noOffset" properties:props def:NO];


    void (^setInset)(void) = ^{

        [self->tableview setContentInset:insets];
        [self->tableview setScrollIndicatorInsets:insets];
        tableContentInsets = [self->tableview contentInset];


        CGFloat topInset = insets.top;
        CGFloat bottomInset = insets.bottom;
        CGFloat leftInset = insets.left;
        CGFloat rightInset = insets.right;



        NSMutableDictionary *contentDictionary = [[NSMutableDictionary alloc]init];
        [contentDictionary setValue:[NSNumber numberWithFloat:topInset] forKey:@"top"];
        [contentDictionary setValue:[NSNumber numberWithFloat:bottomInset] forKey:@"bottom"];
        [contentDictionary setValue:[NSNumber numberWithFloat:leftInset] forKey:@"left"];
        [contentDictionary setValue:[NSNumber numberWithFloat:rightInset] forKey:@"right"];


        [self.proxy replaceValue:contentDictionary
                    forKey:@"contentInsets"
              notification:NO];

        if (noOffset == NO){
            if (nobottom == NO){
                CGSize svContentSize = self->tableview.contentSize;
                CGSize svBoundSize = self->tableview.bounds.size;
                CGFloat svBottomInsets = self->tableview.contentInset.bottom;
                CGFloat bottomHeight = svContentSize.height - svBoundSize.height + svBottomInsets + safeArea;
                CGFloat bottomWidth = svContentSize.width - svBoundSize.width;

                CGPoint newOffset = CGPointMake(bottomWidth, bottomHeight);

                [self->tableview setContentOffset:newOffset];
            }
            if (newoffset != 0){
                CGSize svContentSize = self->tableview.contentSize;
                CGSize svBoundSize = self->tableview.bounds.size;
                CGFloat svBottomInsets = self->tableview.contentInset.bottom;
                CGFloat bottomHeight = svContentSize.height - svBoundSize.height + svBottomInsets + safeArea;
                CGFloat bottomWidth = svContentSize.width - svBoundSize.width;

                CGPoint newOffset = CGPointMake(bottomWidth, newoffset);

                [self->tableview setContentOffset:newOffset];
            }
        }

    };
    if (animated) {
        double duration = [TiUtils doubleValue:@"duration" properties:props def:kDefaultAnimationDuration]/1000;
        [UIView animateWithDuration:duration animations:setInset];
    }
    else {
        setInset();
    }
}


- (void)autoSnappping:(CGPoint)velocity withTargetOffset:(CGPoint *)targetOffset
{


//    NSLog(@"[ERROR] autoSnappping Module: %f %f",myvelocity.y,targetOffset->memory.y);
//    NSLog(@"[ERROR] tableview.contentSize.height Module: %f",tableview.contentSize.height);
//    NSLog(@"[ERROR] tableview.frame.size.height Module: %f",tableview.frame.size.height);
//    NSLog(@"[ERROR] tableview.contentInset.top Module: %f",tableview.contentInset.top);
//    NSLog(@"[ERROR] tableview.contentInset.bottom Module: %f",tableview.contentInset.bottom);

    TableViewExtensionLog(@"autoSnappping velocity: %f, targetOffset: %f", velocity.y, targetOffset->y);

    CGPoint *mytargetOffset = targetOffset;

    if (targetOffset->y >= (tableview.contentSize.height - tableview.frame.size.height - tableview.contentInset.top - tableview.contentInset.bottom)) {
      //  NSLog(@"[ERROR] autoSnappping return: %@ %@",CGPointEqualToPoint(velocity, CGPointZero), (targetOffset->memory.y >= tableview.contentSize.height - tableview.frame.size.height - tableview.contentInset.top - tableview.contentInset.bottom));

        return;
    }

    NSIndexPath *indexPath = nil;
    indexPath = [tableview indexPathForRowAtPoint:*mytargetOffset];

    if (indexPath != nil){
        CGPoint *offset = targetOffset;
        CGRect cellRect = [tableview rectForRowAtIndexPath:indexPath];

        CGFloat targetOffsetYDif = offset->y - CGRectGetMinY(cellRect);
        if (targetOffsetYDif < kRoundingHeight) {
            offset->y = CGRectGetMinY(cellRect) - tableview.contentInset.top;
            TableViewExtensionLog(@"snapping to top: cellMinY=%f, offset=%f", CGRectGetMinY(cellRect), offset->y);

        }
        else if (targetOffsetYDif > cellRect.size.height - kRoundingHeight) {
            offset->y = CGRectGetMaxY(cellRect) - tableview.contentInset.top;
            TableViewExtensionLog(@"snapping to bottom: cellMaxY=%f, offset=%f", CGRectGetMaxY(cellRect), offset->y);

        }
       // [tableview setContentOffset:*offset];
        TableViewExtensionLog(@"final targetOffset: %f -> %f", targetOffset->y, offset->y);

    }
    else {
        return;
    }


}
//
//
#pragma mark Delegate




- (void)tableView:(UITableView *)thisTableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSIndexPath *index = indexPath;
    TiUITableViewRowProxy *row = [self rowForIndexPath:index];
    
    // Set background color (no dispatch needed - already on main thread)
    NSString *color = [row valueForKey:@"backgroundColor"];
    if (color == nil) {
        color = [self.proxy valueForKey:@"rowBackgroundColor"];
        if (color == nil) {
            color = [self.proxy valueForKey:@"backgroundColor"];
        }
    }
    UIColor *cellColor = [TiUtils colorValue:color].color;
    if (cellColor == nil) {
        cellColor = [UIColor whiteColor];
    }
    cell.backgroundColor = cellColor;
    
    // Fire rowvisible event with throttling (~30fps to prevent jank)
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if (now - lastRowVisibleTime >= kRowVisibleThrottleInterval) {
        lastRowVisibleTime = now;
        
        if ([[self proxy] _hasListeners:@"rowvisible"]) {
            NSInteger rowTopOffset = [row getTopOffset:nil];
            NSInteger rowVisible = [row isVisible:nil];
            
            NSInteger sectionIdx = [index section];
            NSArray *sections = [(TiUITableViewProxy *)[self proxy] internalSections];
            TiUITableViewSectionProxy *section = [self sectionForIndex:sectionIdx];
            
            NSInteger dataIndex = [self rowIndexForIndexPath:index andSections:sections];
            
            NSMutableDictionary *eventObject = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                section, @"section",
                NUMINTEGER(dataIndex), @"index",
                NUMINTEGER(rowTopOffset), @"topOffset",
                row, @"row",
                NUMINTEGER(rowVisible), @"isVisible",
                row, @"rowData",
                nil];
            
            [[self proxy] fireEvent:@"rowvisible" withObject:eventObject propagate:NO];
        }
    }
}




#pragma mark - Row Management

- (void)appendRowFast:(id)dict
{
    BOOL animated = [TiUtils boolValue:[dict objectForKey:@"animated"] def:NO];
    NSInteger section = [[dict objectForKey:@"section"] integerValue];

    // Get sections and row count
    NSArray *sections = [self valueForKey:@"sections"];
    TiUITableViewSectionProxy *sectionProxy = [sections objectAtIndex:section];
    NSInteger numberOfRows = [[sectionProxy rows] count];

    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:numberOfRows inSection:section];

    // Begin updates for fast row insertion
    [tableview beginUpdates];
    [tableview insertRowsAtIndexPaths:@[indexPath] withRowAnimation:animated ? UITableViewRowAnimationAutomatic : UITableViewRowAnimationNone];
    [tableview endUpdates];

    // Fire visibility callback
    [self.proxy replaceValue:@"rowvisible" forKey:@"isVisible" notification:YES];
}

- (void)setOpaqueRows:(BOOL)opaque
{
    // Set all row views to opaque for reduced compositing costs
    NSArray *sections = [self valueForKey:@"sections"];
    for (TiUITableViewSectionProxy *section in sections) {
        NSArray *rows = [section rows];
        for (TiUITableViewRowProxy *row in rows) {
            NSArray *children = [row valueForKey:@"children"];
            for (TiViewProxy *child in children) {
                [[child view] setOpaque:opaque];
                if (opaque) {
                    [[child view] setBackgroundColor:[UIColor whiteColor]];
                }
            }
        }
    }
}

- (void)setEstimatedRowHeight:(CGFloat)height
{
    tableview.estimatedRowHeight = height;
    tableview.estimatedSectionHeaderHeight = height;
    tableview.estimatedSectionFooterHeight = height;
}

- (void)tableView:(UITableView *)thisTableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([[self proxy] _hasListeners:@"rownotvisible"]) {
        // Throttle rownotvisible events to ~60fps
        CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
        if (now - lastRowVisibleTime >= kRowVisibleThrottleInterval) {
            lastRowVisibleTime = now;
            
            NSIndexPath *index = indexPath;
            TiUITableViewRowProxy *row = [self rowForIndexPath:index];
            
            NSInteger rowTopOffset = [row getTopOffset:nil];
            
            NSInteger sectionIdx = [index section];
            NSArray *sections = [(TiUITableViewProxy *)[self proxy] internalSections];
            TiUITableViewSectionProxy *section = [self sectionForIndex:sectionIdx];
            
            NSInteger dataIndex = [self rowIndexForIndexPath:index andSections:sections];
            
            NSMutableDictionary *eventObject = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                section, @"section",
                NUMINTEGER(dataIndex), @"index",
                NUMINTEGER(rowTopOffset), @"topOffset",
                row, @"row",
                row, @"rowData",
                nil];
            
            [[self proxy] fireEvent:@"rownotvisible" withObject:eventObject propagate:NO];
        }
    }
}




// #pragma Scroll View Delegate


//- (NSDictionary *)eventObjectForScrollView:(UIScrollView *)scrollView
//{
//  return [NSDictionary dictionaryWithObjectsAndKeys:
//                       [TiUtils pointToDictionary:scrollView.contentOffset], @"contentOffset",
//                       [TiUtils sizeToDictionary:scrollView.contentSize], @"contentSize",
//                       [TiUtils sizeToDictionary:tableview.bounds.size], @"size",
//                       nil];
//}
//
//- (void)fireScrollEvent:(UIScrollView *)scrollView
//{
//
//  if ([self.proxy _hasListeners:@"scroll"]) {
//    [self.proxy fireEvent:@"scroll" withObject:[self eventObjectForScrollView:scrollView]];
//  }
//}


//
//- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset
//{
//
////    NSLog(@"[ERROR] scrollViewWillEndDragging Module: %f",targetContentOffset->y);
//
//
//
//
//    if ([TiUtils boolValue:[self.proxy valueForUndefinedKey:@"snappingEnabled"] def:NO]){
//        if (![TiUtils boolValue:[self.proxy valueForUndefinedKey:@"isLoading"] def:NO]){
//
//            [self autoSnappping:velocity withTargetOffset:targetContentOffset];
//        }
//    }
//
//    if ([self tableView].pagingEnabled){
//        UITableView *tv = (UITableView*)scrollView;
//        NSIndexPath *indexPathOfTopRowAfterScrolling = [tv indexPathForRowAtPoint:*targetContentOffset];
//        CGRect rectForTopRowAfterScrolling = [tv rectForRowAtIndexPath: indexPathOfTopRowAfterScrolling];
//        targetContentOffset->y = rectForTopRowAfterScrolling.origin.y;
//    }
//
//    if ([[self proxy] _hasListeners:@"scrolled"]) {
//        NSString *direction = nil;
//
//        if (velocity.y > 0) {
//          direction = @"up";
//        }
//
//        if (velocity.y < 0) {
//          direction = @"down";
//        }
//
//        NSMutableDictionary *event = [NSMutableDictionary dictionaryWithDictionary:@{
//            @"contentOffset" : NUMFLOAT(scrollView.contentOffset.y),
//            @"contentHeight" : NUMFLOAT(scrollView.contentSize.height),
//            @"targetContentOffset" : NUMFLOAT(targetContentOffset->y),
//          @"velocity" : NUMFLOAT(velocity.y)
//        }];
//        if (direction != nil) {
//          [event setValue:direction forKey:@"direction"];
//        }
//
//        [[self proxy] fireEvent:@"scrolled" withObject:event];
//        RELEASE_TO_NIL(direction);
//  }
//}


@end

