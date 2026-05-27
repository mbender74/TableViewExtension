/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009-2010 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */
#define USE_TI_UISCROLLVIEW

#ifdef USE_TI_UIREFRESHCONTROL
#import "TiUIRefreshControlProxy.h"
#endif
#import "DeMarcbenderTableviewextensionModule.h"
#import "TiUIScrollView.h"

#import <TitaniumKit/TiUIView.h>


@interface TiUIScrollView (Extended)

-(void)scrollToBottomNoAnim;
- (void)setContentInsets_:(id)value withObject:(id)property;
- (void)setScrollIndicatorInsets_:(id)value withObject:(id)property;

@end
