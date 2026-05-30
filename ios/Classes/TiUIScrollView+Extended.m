/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009-2010 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */
#define USE_TI_UISCROLLVIEW

#import "TiUIScrollView.h"
#import "TiUIScrollView+Extended.h"

#import <TitaniumKit/TiUtils.h>
#import <TitaniumKit/TiWindowProxy.h>


@implementation TiUIScrollView (Extended)

// Configurable constants
static const CGFloat kDefaultSafeAreaOffset = 34;  // Default safe area offset (iOS tab bar)
static const CGFloat kDefaultAnimationDuration = 200; // ms — frame-aligned: 15 frames @ 120Hz, 12 frames @ 60Hz

UIEdgeInsets scrollViewContentInsets;


-(void)scrollToBottomNoAnim
{
    /*
     * Calculate the bottom height & width and, sets the offset from the
     * content view's origin that corresponds to the receiver's origin.
     */
    UIScrollView *currScrollView = [self scrollView];
    
    CGSize svContentSize = currScrollView.contentSize;
    CGSize svBoundSize = currScrollView.bounds.size;
    CGFloat svBottomInsets = currScrollView.contentInset.bottom;
    
    CGFloat bottomHeight = svContentSize.height - svBoundSize.height + svBottomInsets + kDefaultSafeAreaOffset;
    CGFloat bottomWidth = svContentSize.width - svBoundSize.width;

    CGPoint newOffset = CGPointMake(bottomWidth,bottomHeight);
    [UIView setAnimationsEnabled:NO];
    [currScrollView setContentOffset:newOffset animated:NO];
    [UIView setAnimationsEnabled:YES];
}


-(void)setContentInsets_:(id)value withObject:(id)props
{
    UIScrollView *currScrollView = [self scrollView];

    UIEdgeInsets insets = [TiUtils contentInsets:value];
    UIEdgeInsets insetsScroll = [TiUtils contentInsets:value];

    int newoffset = [TiUtils intValue:@"newoffset" properties:props def:0];

    int safeArea = [TiUtils intValue:@"safearea" properties:props def:0];

    BOOL animated = [TiUtils boolValue:@"animated" properties:props def:NO];
    BOOL nobottom = [TiUtils boolValue:@"nobottom" properties:props def:NO];
    BOOL noOffset = [TiUtils boolValue:@"noOffset" properties:props def:NO];




    void (^setInset)(void) = ^{

        [currScrollView setContentInset:insets];
        [currScrollView setScrollIndicatorInsets:insets];

        scrollViewContentInsets = [currScrollView contentInset];

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
                CGSize svContentSize = currScrollView.contentSize;
                CGSize svBoundSize = currScrollView.bounds.size;
                CGFloat svBottomInsets = currScrollView.contentInset.bottom;
                CGFloat bottomHeight = svContentSize.height - svBoundSize.height + svBottomInsets + safeArea;
                CGFloat bottomWidth = svContentSize.width - svBoundSize.width;

                CGPoint newOffset = CGPointMake(bottomWidth, bottomHeight);

                [currScrollView setContentOffset:newOffset];
            }
            if (newoffset != 0){
                CGSize svContentSize = currScrollView.contentSize;
                CGSize svBoundSize = currScrollView.bounds.size;
                CGFloat svBottomInsets = currScrollView.contentInset.bottom;
                CGFloat bottomHeight = svContentSize.height - svBoundSize.height + svBottomInsets + safeArea;
                CGFloat bottomWidth = svContentSize.width - svBoundSize.width;

                CGPoint newOffset = CGPointMake(bottomWidth, newoffset);

                [currScrollView setContentOffset:newOffset];
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



-(void)setScrollIndicatorInsets_:(id)value withObject:(id)props
{
    UIScrollView *currScrollView = [self scrollView];

    UIEdgeInsets insetsScroll = [TiUtils contentInsets:value];


    BOOL animated = [TiUtils boolValue:@"animated" properties:props def:NO];
    BOOL nobottom = [TiUtils boolValue:@"nobottom" properties:props def:NO];



    void (^setInset)(void) = ^{

        [currScrollView setScrollIndicatorInsets:insetsScroll];



    };
    if (animated) {
        double duration = [TiUtils doubleValue:@"duration" properties:props def:kDefaultAnimationDuration]/1000;
        [UIView animateWithDuration:duration animations:setInset];
    }
    else {
        setInset();
    }
}


@end
