/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009-2010 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */
#import "TiUIViewProxy.h"
#import "TiUIViewProxy+Extended.h"
#import "TiUIView+Extended.h"

#import <TitaniumKit/TiUtils.h>

@implementation TiUIViewProxy (Extended)

#pragma mark Internal

- (NSString *)apiName
{
  return @"Ti.UI.ViewExtended";
}

@end
