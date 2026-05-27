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
     * Calculate the bottom height & width and, sets the offset from the
     * content view’s origin that corresponds to the receiver’s origin.
     */
    UIView *myView = self;

    myView.layer.backgroundColor = [UIColor yellowColor].CGColor;
    myView.opaque = YES;
    myView.layer.masksToBounds = YES;
    myView.clipsToBounds = YES;
    
    for (CALayer *layer in [myView.layer sublayers]) {

        layer.masksToBounds = YES;
        layer.backgroundColor = [UIColor yellowColor].CGColor;
    }
    for (UIView *view in [myView subviews]) {
        view.clipsToBounds = YES;
        view.opaque = YES;
        view.layer.masksToBounds = YES;
        view.backgroundColor = [UIColor yellowColor];
    }

}


@end
