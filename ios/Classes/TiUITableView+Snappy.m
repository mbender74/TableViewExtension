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
#import "TiUITableView+SmoothScrolling.h"
#import "TiUITableViewSectionProxy.h"
#import "TiUITableViewRowProxy.h"
#import "TiUITableViewRowProxy+WithVisibility.h"

// Scroll event throttling - imported from header
#import "TiUITableView+SmoothScrolling.h"

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
static const CGFloat kDefaultAnimationDuration = 167; // ms — frame-aligned: 12 frames @ 120Hz, 10 frames @ 60Hz

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
- (void)setPagingEnabled_:(id)value
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
- (void)insertRow:(TiUITableViewRowProxy *)row before:(TiUITableViewRowProxy *)before
{
    [UIView performWithoutAnimation:^{
        row.table = self;
        row.section = before.section;
        NSMutableArray *rows = [row.section rows];
        [rows insertObject:row atIndex:row.row];
        [row.section rememberProxy:row];
        [row.section reorderRows];
    }];
}

#pragma mark - Opaque Helpers

- (UIColor *)opaqueColorFrom:(UIColor *)color
{
    if (!color) {
        return [UIColor whiteColor];
    }
    CGFloat r, g, b, a;
    if ([color getRed:&r green:&g blue:&b alpha:&a] && a < 1.0) {
        return [UIColor colorWithRed:r green:g blue:b alpha:1.0];
    }
    return color;
}

- (void)makeViewOpaque:(UIView *)view withColor:(UIColor *)color
{
    if (!view) {
        return;
    }
    view.backgroundColor = color;
    view.opaque = YES;
    view.layer.opaque = YES;
    view.layer.backgroundColor = color.CGColor;
    view.layer.masksToBounds = YES;
    for (UIView *subview in view.subviews) {
        [self makeViewOpaque:subview withColor:color];
    }
}

// Sets opaque flags without overwriting existing backgroundColor.
// Used when a row has opaqueRow=true but no explicit backgroundColor.
- (void)tve_setOpaqueFlagsOnView:(UIView *)view
{
    if (!view) {
        return;
    }
    // If the view already has an opaque backgroundColor, keep it and just ensure flags
    UIColor *bg = view.backgroundColor;
    CGFloat r, g, b, a;
    BOOL hasOpaqueBg = (bg != nil && [bg getRed:&r green:&g blue:&b alpha:&a] && a >= 0.99);
    if (hasOpaqueBg) {
        view.opaque = YES;
        view.layer.opaque = YES;
        view.layer.backgroundColor = bg.CGColor;
        view.layer.masksToBounds = YES;
    } else {
        // No solid background — leave as-is (will show as blended layer, but user chose this)
        view.opaque = NO;
        view.layer.opaque = NO;
    }
    for (UIView *subview in view.subviews) {
        [self tve_setOpaqueFlagsOnView:subview];
    }
}

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


    [UIView performWithoutAnimation:^{
        CGFloat currentOffset = self->tableview.contentOffset.y;
        [self->tableview insertRowsAtIndexPaths:[NSArray arrayWithObject:path] withRowAnimation:UITableViewRowAnimationNone];
        [self->tableview setContentOffset:CGPointMake(0, currentOffset + cellheight)];
    }];
    // Alte Variante:
    // [UIView performWithoutAnimation:^{
    //     CGPoint contentOffet = self->tableview.contentOffset;
    //     CGFloat preoffset = contentOffet.y;
    //     CGFloat afteroffset = preoffset + cellheight;
    //     contentOffet.y = afteroffset;
    //     [self->tableview setContentOffset:contentOffet];
    //     [self->tableview insertRowsAtIndexPaths:[NSArray arrayWithObject:path] withRowAnimation:UITableViewRowAnimationNone];
    // }];
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

    // Cache row lookup - use for both background color and event
    TiUITableViewRowProxy *row = [self rowForIndexPath:index];

    // Track cell reuse
    if (cell.reuseIdentifier) {
        cellReuseCount++;
    } else {
        cellCreateCount++;
    }

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

    // Make cell opaque if opaqueRow is set
    id opaqueRowValue = [row valueForUndefinedKey:@"opaqueRow"];
    BOOL opaqueRow = [TiUtils boolValue:opaqueRowValue def:NO];
    if (opaqueRow) {
        // Check whether the ROW ITSELF has an explicit backgroundColor.
        // Do NOT use the fallback chain (rowBackgroundColor / tableView backgroundColor)
        // because those are not the row's own color.
        id rowBgValue = [row valueForKey:@"backgroundColor"];
        BOOL hasExplicitRowBg = (rowBgValue != nil);

        if (hasExplicitRowBg) {
            // --- Row has explicit backgroundColor: apply it everywhere ---
            cellColor = [self opaqueColorFrom:cellColor];

            // Resolve selected/focused colors so opaqueRow does not overwrite them with cellColor
            id selectedBgValue = [row valueForKey:@"backgroundSelectedColor"];
            if (selectedBgValue == nil) {
                selectedBgValue = [row valueForKey:@"selectedBackgroundColor"]; // legacy
            }
            UIColor *selectedColor = [self opaqueColorFrom:[TiUtils colorValue:selectedBgValue].color];

            id focusedBgValue = [row valueForKey:@"backgroundFocusedColor"];
            (void)[self opaqueColorFrom:[TiUtils colorValue:focusedBgValue].color];

            // backgroundView
            BOOL hasGradient = [row valueForKey:@"backgroundGradient"] != nil;
            BOOL hasBgImage  = [row valueForKey:@"backgroundImage"] != nil;
            if (cell.backgroundView && !hasGradient && !hasBgImage) {
                cell.backgroundView.opaque = YES;
                cell.backgroundView.backgroundColor = cellColor;
                cell.backgroundView.layer.opaque = YES;
                cell.backgroundView.layer.backgroundColor = cellColor.CGColor;
                cell.backgroundView.layer.masksToBounds = YES;
            }

            // selectedBackgroundView
            BOOL hasSelectedGradient = [row valueForKey:@"selectedBackgroundGradient"] != nil ||
                                       [row valueForKey:@"backgroundSelectedGradient"] != nil;
            BOOL hasSelectedBgImage  = [row valueForKey:@"backgroundSelectedImage"] != nil ||
                                       [row valueForKey:@"selectedBackgroundImage"] != nil;
            if (cell.selectedBackgroundView && !hasSelectedGradient && !hasSelectedBgImage) {
                UIColor *selColor = selectedColor ?: cellColor;
                cell.selectedBackgroundView.opaque = YES;
                cell.selectedBackgroundView.backgroundColor = selColor;
                cell.selectedBackgroundView.layer.opaque = YES;
                cell.selectedBackgroundView.layer.backgroundColor = selColor.CGColor;
                cell.selectedBackgroundView.layer.masksToBounds = YES;
            }

            cell.opaque = YES;
            cell.layer.opaque = YES;
            cell.layer.backgroundColor = cellColor.CGColor;
            cell.layer.masksToBounds = YES;

            cell.contentView.backgroundColor = cellColor;
            cell.contentView.opaque = YES;
            cell.contentView.layer.opaque = YES;
            cell.contentView.layer.backgroundColor = cellColor.CGColor;
            cell.contentView.layer.masksToBounds = YES;

            UILabel *textLabel = [cell textLabel];
            if (textLabel) {
                textLabel.backgroundColor = cellColor;
                textLabel.opaque = YES;
                textLabel.layer.opaque = YES;
                textLabel.layer.backgroundColor = cellColor.CGColor;
                textLabel.layer.masksToBounds = YES;
            }

            UILabel *detailTextLabel = [cell detailTextLabel];
            if (detailTextLabel) {
                detailTextLabel.backgroundColor = cellColor;
                detailTextLabel.opaque = YES;
                detailTextLabel.layer.opaque = YES;
                detailTextLabel.layer.backgroundColor = cellColor.CGColor;
                detailTextLabel.layer.masksToBounds = YES;
            }

            UIImageView *imageView = [cell imageView];
            if (imageView) {
                imageView.backgroundColor = cellColor;
                imageView.opaque = YES;
                imageView.layer.opaque = YES;
                imageView.layer.backgroundColor = cellColor.CGColor;
                imageView.layer.masksToBounds = YES;
            }

            UIView *accessoryView = [cell accessoryView];
            if (accessoryView) {
                accessoryView.backgroundColor = cellColor;
                accessoryView.opaque = YES;
                accessoryView.layer.opaque = YES;
                accessoryView.layer.backgroundColor = cellColor.CGColor;
                accessoryView.layer.masksToBounds = YES;
            }

            for (UIView *subview in cell.contentView.subviews) {
                [self makeViewOpaque:subview withColor:cellColor];
            }

            cell.backgroundColor = cellColor;

        } else {
            // --- Row has NO explicit backgroundColor: keep subview colors, just set opaque flags ---
            // opaqueRow must NOT affect contentView itself — leave contentView untouched.
            // Only make cell.background clear so subviews with their own backgroundColor show through.
            cell.backgroundColor = [UIColor clearColor];

            // Do NOT touch contentView.backgroundColor or contentView.opaque.
            // Subviews that have their own opaque backgroundColor will be opaque,
            // and because they cover the full row area the compositor is happy.

            // Only set opaque flags on subviews, do NOT overwrite their backgroundColor
            for (UIView *subview in cell.contentView.subviews) {
                [self tve_setOpaqueFlagsOnView:subview];
            }
        }
    }
    
    // Fire rowvisible event with adaptive throttling (60fps on ProMotion, 30fps on standard)
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if (now - lastRowVisibleTime >= gThrottleInterval) {
        lastRowVisibleTime = now;
        
        if ([[self proxy] _hasListeners:@"rowvisible"]) {
            // Reuse cached row reference - no second rowForIndexPath call
            // Optimize: skip expensive getTopOffset/isVisible if not needed
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
                NUMINTEGER(YES), @"isVisible", // Always YES in willDisplayCell
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
        // Throttle rownotvisible events with adaptive timer (60fps on ProMotion, 30fps on standard)
        CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
        if (now - lastRowNotVisibleTime >= gThrottleInterval) {
            lastRowNotVisibleTime = now;
            
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


- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset
{
    if ([self.nextResponder respondsToSelector:@selector(scrollViewWillEndDragging:withVelocity:targetContentOffset:)]) {
        [(id)self.nextResponder scrollViewWillEndDragging:scrollView withVelocity:velocity targetContentOffset:targetContentOffset];
    }

    if ([TiUtils boolValue:[self.proxy valueForUndefinedKey:@"snappingEnabled"] def:NO]) {
        if (![TiUtils boolValue:[self.proxy valueForUndefinedKey:@"isLoading"] def:NO]) {
            [self autoSnappping:velocity withTargetOffset:targetContentOffset];
        }
    }
}


@end
