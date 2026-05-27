/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009-2010 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */
#define USE_TI_UISCROLLVIEW
#import "TiUIScrollViewProxy.h"
#import "TiUIScrollViewProxy+Extended.h"
#import "TiUIScrollView+Extended.h"

#import <TitaniumKit/TiUtils.h>

@implementation TiUIScrollViewProxy (Extended)

#pragma mark Internal

- (NSString *)apiName
{
  return @"Ti.UI.ScrollViewExtended";
}

#pragma mark Public APIs

-(void)scrollToBottomNoAnim:(id)args
{
    TiThreadPerformOnMainThread(^{
        [(TiUIScrollView *)[self view] scrollToBottomNoAnim];
    }, YES);
}


-(void)setContentInsets:(id)args
{
    ENSURE_UI_THREAD(setContentInsets,args);
    id arg1;
    id arg2;
    if ([args isKindOfClass:[NSDictionary class]])
    {
        arg1 = args;
        arg2 = [NSDictionary dictionary];
    }
    else
    {
        arg1 = [args objectAtIndex:0];
        arg2 = [args count] > 1 ? [args objectAtIndex:1] : [NSDictionary dictionary];
    }
    [[self view] performSelector:@selector(setContentInsets_:withObject:) withObject:arg1 withObject:arg2];
}

@end
