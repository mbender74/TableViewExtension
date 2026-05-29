/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009-2010 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import "DeMarcbenderTableviewextensionModule.h"
#import <TitaniumKit/TiUIView.h>


@interface TiUIView (Extended)

@end

// Extension for recursive subviews
@interface UIView (RecursiveSubviews)
- (NSArray<UIView *> *)recursiveSubviews;
@end
