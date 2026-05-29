/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009-2010 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import "TiUIView.h"
#import "TiUIView+Extended.h"

#import <TitaniumKit/TiUtils.h>
#import <TitaniumKit/TiWindowProxy.h>


@implementation UIView (RecursiveSubviews)

- (NSArray<UIView *> *)recursiveSubviews
{
    NSMutableArray *result = [NSMutableArray array];
    for (UIView *subview in self.subviews) {
        [result addObject:subview];
        [result addObjectsFromArray:[subview recursiveSubviews]];
    }
    return result;
}

@end

@implementation TiUIView (Extended)

@end
