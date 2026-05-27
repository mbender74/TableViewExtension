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


@implementation TiUIView (Extended)

-(void)opaqueView
{
    /*
     * Make view and all subviews opaque with clipping enabled.
     * Useful for performance optimization by reducing compositing costs.
     */
    UIView *myView = self;

    myView.opaque = YES;
    myView.layer.masksToBounds = YES;
    myView.clipsToBounds = YES;
    
    for (CALayer *layer in [myView.layer sublayers]) {
        layer.masksToBounds = YES;
    }
    
    for (UIView *view in [myView subviews]) {
        view.clipsToBounds = YES;
        view.opaque = YES;
        view.layer.masksToBounds = YES;
    }

}


@end
