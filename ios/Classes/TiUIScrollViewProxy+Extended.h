/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009-2010 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */
#import "DeMarcbenderTableviewextensionModule.h"
#import <TitaniumKit/TiViewProxy.h>
#import "TiUIScrollViewProxy.h"

#define USE_TI_UISCROLLVIEW
@interface TiUIScrollViewProxy (Extended)
- (void)setContentInsets:(id)args;
@end
