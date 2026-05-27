//
//  TiUITableViewCell+WithReuse.m
//  TableViewRowExtension
//
//  Extension to automatically call prepareTableRowForReuse on cell reuse
//
//  Da TiUITableViewCell aus dem TitaniumKit.framework kommt und keinen Header hat,
//  verwenden wir Method Swizzling um logging hinzuzufügen.
//  Das eigentliche prepareTableRowForReuse wird vom SDK bereits aufgerufen.

#define USE_TI_UITABLEVIEW

// Debug logging macro
#ifndef DEBUG
#define TableViewExtensionLog(fmt, ...) do {} while(0)
#else
#define TableViewExtensionLog(fmt, ...) NSLog(@"[TableViewExtension] " fmt, ##__VA_ARGS__)
#endif

#import "TiUITableViewRowProxy.h"
#import "TiUITableViewRowProxy+WithVisibility.h"
#import <objc/runtime.h>

static void (*_originalPrepareForReuse)(id, SEL);

// Declare the swizzled method so Xcode knows about it
@interface TiUITableViewCell (Swizzle)
- (void)_swizzledPrepareForReuse;
@end

static void _swizzledPrepareForReuse(id self, SEL _cmd)
{
    // Call original
    _originalPrepareForReuse(self, _cmd);
    
    // Add logging
    id proxy = [self valueForKey:@"proxy"];
    if (proxy && [proxy isKindOfClass:[TiUITableViewRowProxy class]]) {
        TiUITableViewRowProxy *rowProxy = (TiUITableViewRowProxy *)proxy;
        if (rowProxy.callbackCell == self) {
            TableViewExtensionLog(@"Cell RECYCLED — className: %@", [rowProxy tableClass]);
        }
    }
}

@implementation TiUITableViewCell (WithReuse)

+ (void)load
{
    // Swizzle prepareForReuse to add logging
    Class class = objc_getClass("TiUITableViewCell");
    if (class) {
        Method originalMethod = class_getInstanceMethod(class, @selector(prepareForReuse));
        Method swizzledMethod = class_getInstanceMethod(class, sel_getUid("_swizzledPrepareForReuse"));
        
        if (originalMethod && swizzledMethod) {
            _originalPrepareForReuse = (void (*)(id, SEL))method_getImplementation(originalMethod);
            method_setImplementation(originalMethod, method_getImplementation(swizzledMethod));
        }
    }
}

- (void)_swizzledPrepareForReuse
{
    _swizzledPrepareForReuse(self, _cmd);
}

@end
