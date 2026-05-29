//
//  TiUITableViewRowProxy+WithVisibility.m
//  TableViewRowExtension
//
//  Created by Matteo De Rose on 04/12/15.
//
//
#define USE_TI_UITABLEVIEW

// Debug logging macro
#ifndef DEBUG
#define TableViewExtensionLog(fmt, ...) do {} while(0)
#else
#define TableViewExtensionLog(fmt, ...) NSLog(@"[TableViewExtension] " fmt, ##__VA_ARGS__)
#endif

#import "TiViewProxy.h"
#import "TiUITableView.h"
#import "TiUITableViewProxy.h"
#import "TiUITableViewRowProxy+WithVisibility.h"
#import "TiUIView+Extended.h"
#import <TitaniumKit/TiDimension.h>
#import <TitaniumKit/TiViewProxy.h>
#import "TiUITableViewSectionProxy.h"
#import "TiUITableViewRowProxy.h"
#import "TiUITableView+SmoothScrolling.h"

@interface TiUITableView (IndexPathExtension)
- (NSIndexPath *)indexPathFromInt:(NSInteger)index;
@end

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


- (void)prepareTableRowForReuse
{
    NSString *tableClass = [self tableClass];
    TableViewExtensionLog(@"prepareTableRowForReuse - className: %@", tableClass);

    // Wenn row nicht als reusable markiert ist: nur rowContainerView entfernen
    if (![self reusable]) {
        TableViewExtensionLog(@"not reusable, removing rowContainerView only");
        id rowContainer = [self valueForKey:@"rowContainerView"];
        if (rowContainer) {
            [rowContainer removeFromSuperview];
        }
        return;
    }

    // Bei custom tableClass: kein Cleanup (SDK-Verhalten)
    if (![tableClass isEqualToString:@"TiUITableView"]) {
        TableViewExtensionLog(@"custom tableClass, skipping cleanup");
        return;
    }

    TableViewExtensionLog(@"cleaning up rowContainerView + children");
    // rowContainerView bereinigen
    id rowContainer = [self valueForKey:@"rowContainerView"];
    if (rowContainer) {
        [rowContainer removeFromSuperview];
        [self setValue:nil forKey:@"rowContainerView"];
    }

    // Alle Children detachView aufrufen (SDK-Verhalten)
    NSArray *children = [self valueForKey:@"children"];
    for (TiViewProxy *child in children) {
        [child detachView];
    }

    // Invalidate height cache for this row so recycled cells with changed
    // dimensions don't use stale cached heights.
    TiUITableView *parentTable = self.table;
    if (parentTable) {
        [parentTable invalidateCacheForRow:self];
    }
}

- (void)setOpaqueRow:(id)value
{
    // Store the value so willDisplayCell can read it later
    [self replaceValue:value forKey:@"opaqueRow" notification:NO];

    BOOL opaque = [TiUtils boolValue:value];

    if (!opaque) {
        return;
    }
    
    // Determine row's backgroundColor
    UIColor *rowBgColor = nil;
    id bgColorValue = [self valueForKey:@"backgroundColor"];
    if (bgColorValue && [bgColorValue isKindOfClass:[NSString class]]) {
        NSString *colorStr = (NSString *)bgColorValue;
        if ([colorStr isEqualToString:@"green"]) {
            rowBgColor = [UIColor greenColor];
        } else if ([colorStr isEqualToString:@"red"]) {
            rowBgColor = [UIColor redColor];
        } else if ([colorStr isEqualToString:@"blue"]) {
            rowBgColor = [UIColor blueColor];
        } else if ([colorStr isEqualToString:@"white"]) {
            rowBgColor = [UIColor whiteColor];
        } else if ([colorStr isEqualToString:@"black"]) {
            rowBgColor = [UIColor blackColor];
        } else if ([colorStr isEqualToString:@"yellow"]) {
            rowBgColor = [UIColor yellowColor];
        } else if ([colorStr isEqualToString:@"orange"]) {
            rowBgColor = [UIColor orangeColor];
        } else if ([colorStr isEqualToString:@"purple"]) {
            rowBgColor = [UIColor purpleColor];
        } else if ([colorStr isEqualToString:@"gray"]) {
            rowBgColor = [UIColor grayColor];
        } else if ([colorStr hasPrefix:@"#"] || colorStr.length == 6) {
            rowBgColor = [self colorFromHexString:colorStr];
        }
    }
    
    // Default to green if no backgroundColor set
    if (!rowBgColor) {
        rowBgColor = [UIColor greenColor];
    }
    
    // Make row container and all subviews opaque
    UIView *rowContainer = (UIView *)[self valueForKey:@"rowContainerView"];
    if (rowContainer) {
        // Get the cell's contentView and make it opaque too
        UIView *contentView = [rowContainer superview];
        if (contentView) {
            contentView.backgroundColor = rowBgColor;
            contentView.opaque = YES;
            contentView.layer.opaque = YES;
        }
        
        // Get the cell itself (superview of contentView)
        UIView *cell = [contentView superview];
        if (cell) {
            // Make ALL subviews of the cell opaque (textLabel, imageView, accessoryView)
            for (UIView *subview in [cell recursiveSubviews]) {
                subview.opaque = YES;
                subview.layer.opaque = YES;
                subview.layer.masksToBounds = YES;
                subview.clipsToBounds = YES;
                
                // Set backgroundColor to row's backgroundColor for ALL subviews
                subview.backgroundColor = rowBgColor;
            }
        }
        
        // Set backgroundColor FIRST
        rowContainer.backgroundColor = rowBgColor;
        
        // Ensure backgroundColor is fully opaque (no alpha)
        CGFloat r, g, b, a;
        [rowContainer.backgroundColor getRed:&r green:&g blue:&b alpha:&a];
        if (a < 1.0) {
            rowContainer.backgroundColor = [UIColor colorWithRed:r green:g blue:b alpha:1.0];
        }
        
        // Set opaque AFTER backgroundColor
        rowContainer.opaque = YES;
        rowContainer.layer.opaque = YES;
        rowContainer.layer.masksToBounds = YES;
        rowContainer.clipsToBounds = YES;
        
        // Recursively make all subviews opaque
        for (UIView *view in [rowContainer recursiveSubviews]) {
            view.opaque = YES;
            view.layer.opaque = YES;
            view.layer.masksToBounds = YES;
            view.clipsToBounds = YES;
            
            // Set backgroundColor to row's backgroundColor for ALL subviews (including UILabels)
            view.backgroundColor = rowBgColor;
        }
        
        // Force layer update
        [rowContainer setNeedsDisplay];
    }
    
    // Also make all TiViewProxy children opaque
    NSArray *children = [self valueForKey:@"children"];
    for (TiViewProxy *child in children) {
        UIView *childView = (UIView *)[child view];
        if (childView) {
            childView.opaque = YES;
            childView.layer.opaque = YES;
            childView.layer.masksToBounds = YES;
            childView.clipsToBounds = YES;
            
            // Set backgroundColor to row's backgroundColor for ALL children
            childView.backgroundColor = rowBgColor;
            
            for (UIView *subview in [childView recursiveSubviews]) {
                subview.opaque = YES;
                subview.layer.opaque = YES;
                subview.layer.masksToBounds = YES;
                subview.clipsToBounds = YES;
                
                // Set backgroundColor to row's backgroundColor for ALL subviews
                subview.backgroundColor = rowBgColor;
            }
        }
    }
}

- (BOOL)isColorTransparent:(UIColor *)color
{
    if (!color) {
        return YES;
    }
    CGFloat r, g, b, a;
    [color getRed:&r green:&g blue:&b alpha:&a];
    return a < 0.99;
}

- (UIColor *)colorFromHexString:(NSString *)hexString
{
    NSString *colorString = [hexString stringByReplacingOccurrencesOfString:@"#" withString:@""];
    if (colorString.length == 6) {
        unsigned int red, green, blue;
        [[NSScanner scannerWithString:[colorString substringWithRange:NSMakeRange(0, 2)]] scanHexInt:&red];
        [[NSScanner scannerWithString:[colorString substringWithRange:NSMakeRange(2, 2)]] scanHexInt:&green];
        [[NSScanner scannerWithString:[colorString substringWithRange:NSMakeRange(4, 2)]] scanHexInt:&blue];
        return [UIColor colorWithRed:((float)red / 255.0f) green:((float)green / 255.0f) blue:((float)blue / 255.0f) alpha:1.0];
    }
    return [UIColor whiteColor];
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
        self->height = [TiUtils dimensionValue:[NSNumber numberWithInt:viewHeight]];
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

