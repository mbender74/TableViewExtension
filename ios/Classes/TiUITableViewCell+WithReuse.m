//
//  TiUITableViewCell+WithReuse.m
//  TableViewExtension
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
#import <TitaniumKit/TiUtils.h>

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
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = objc_getClass("TiUITableViewCell");
        if (!class) {
            return;
        }

        // 1. prepareForReuse — logging only
        Method originalPrepare = class_getInstanceMethod(class, @selector(prepareForReuse));
        Method swizzledPrepare = class_getInstanceMethod(class, sel_getUid("_swizzledPrepareForReuse"));
        if (originalPrepare && swizzledPrepare) {
            _originalPrepareForReuse = (void (*)(id, SEL))method_getImplementation(originalPrepare);
            method_setImplementation(originalPrepare, method_getImplementation(swizzledPrepare));
        }

        // 2. setSelected:animated: — opaqueRow selection support
        Method originalSelected = class_getInstanceMethod(class, @selector(setSelected:animated:));
        Method swizzledSelected = class_getInstanceMethod(class, @selector(tve_setSelected:animated:));
        if (originalSelected && swizzledSelected) {
            method_exchangeImplementations(originalSelected, swizzledSelected);
        }

        // 3. setHighlighted:animated: — opaqueRow selection support
        Method originalHighlighted = class_getInstanceMethod(class, @selector(setHighlighted:animated:));
        Method swizzledHighlighted = class_getInstanceMethod(class, @selector(tve_setHighlighted:animated:));
        if (originalHighlighted && swizzledHighlighted) {
            method_exchangeImplementations(originalHighlighted, swizzledHighlighted);
        }
    });
}

- (void)_swizzledPrepareForReuse
{
    _swizzledPrepareForReuse(self, _cmd);
}

#pragma mark - Opaque Selection Support

- (void)tve_setSelected:(BOOL)selected animated:(BOOL)animated {
    // Call original implementation (now at tve_setSelected: due to swizzle)
    [self tve_setSelected:selected animated:animated];
    [self tve_updateOpaqueSelectionState];
}

- (void)tve_setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    // Call original implementation (now at tve_setHighlighted: due to swizzle)
    [self tve_setHighlighted:highlighted animated:animated];
    [self tve_updateOpaqueSelectionState];
}

- (void)tve_updateOpaqueSelectionState {
    TiUITableViewRowProxy *rowProxy = self.proxy;
    if (!rowProxy) {
        return;
    }

    id opaqueRowValue = [rowProxy valueForUndefinedKey:@"opaqueRow"];
    BOOL opaqueRow = [TiUtils boolValue:opaqueRowValue def:NO];
    if (!opaqueRow) {
        return;
    }

    // If the row has no explicit backgroundColor, skip selection-color handling.
    id bgColorValue = [rowProxy valueForKey:@"backgroundColor"];
    if (!bgColorValue) {
        return;
    }

    BOOL isActive = self.isSelected || self.isHighlighted;

    // Resolve the row's normal backgroundColor (used when not selected)
    UIColor *normalColor = [TiUtils colorValue:bgColorValue].color;
    if (!normalColor) {
        normalColor = [UIColor whiteColor];
    }
    CGFloat r, g, b, a;
    if ([normalColor getRed:&r green:&g blue:&b alpha:&a] && a < 1.0) {
        normalColor = [UIColor colorWithRed:r green:g blue:b alpha:1.0];
    }

    static char tve_pendingRestoreKey;

    if (isActive) {
        // Cancel any pending restore
        dispatch_block_t pending = objc_getAssociatedObject(self, &tve_pendingRestoreKey);
        if (pending) {
            dispatch_block_cancel(pending);
            objc_setAssociatedObject(self, &tve_pendingRestoreKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }

        // Immediately transparent so selectedBackgroundView shows through
        [self tve_applyTransparencyToView:self.contentView recursive:YES];
        if (self.textLabel) {
            [self tve_applyTransparencyToView:self.textLabel recursive:NO];
        }
        if (self.detailTextLabel) {
            [self tve_applyTransparencyToView:self.detailTextLabel recursive:NO];
        }
        if (self.imageView) {
            [self tve_applyTransparencyToView:self.imageView recursive:NO];
        }
        if (self.accessoryView) {
            [self tve_applyTransparencyToView:self.accessoryView recursive:YES];
        }
    } else {
        // Schedule restore after 0.6s so the native accessoryView / selection
        // animation can finish before we snap everything back to opaque.
        __weak TiUITableViewCell *weakSelf = self;
        __weak TiUITableViewRowProxy *weakProxy = rowProxy;

        dispatch_block_t block = dispatch_block_create(0, ^{
            __strong TiUITableViewCell *strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            // Abort if cell got selected/highlighted again
            if (strongSelf.isSelected || strongSelf.isHighlighted) {
                return;
            }
            // Abort if cell was recycled to a different row
            if (strongSelf.proxy != weakProxy) {
                return;
            }

            [strongSelf tve_applyOpacityToView:strongSelf.contentView withColor:normalColor recursive:YES];
            if (strongSelf.textLabel) {
                [strongSelf tve_applyOpacityToView:strongSelf.textLabel withColor:normalColor recursive:NO];
            }
            if (strongSelf.detailTextLabel) {
                [strongSelf tve_applyOpacityToView:strongSelf.detailTextLabel withColor:normalColor recursive:NO];
            }
            if (strongSelf.imageView) {
                [strongSelf tve_applyOpacityToView:strongSelf.imageView withColor:normalColor recursive:NO];
            }
            if (strongSelf.accessoryView) {
                [strongSelf tve_applyOpacityToView:strongSelf.accessoryView withColor:normalColor recursive:YES];
            }

            objc_setAssociatedObject(strongSelf, &tve_pendingRestoreKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        });

        objc_setAssociatedObject(self, &tve_pendingRestoreKey, block, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), block);
    }
}

- (void)tve_applyOpacityToView:(UIView *)view withColor:(UIColor *)color recursive:(BOOL)recursive {
    if (!view) {
        return;
    }
    [view.layer removeAnimationForKey:@"tve_bgColor"];
    view.backgroundColor = color;
    view.opaque = YES;
    view.layer.opaque = YES;
    view.layer.backgroundColor = color.CGColor;
    view.layer.masksToBounds = YES;
    if (recursive) {
        for (UIView *subview in view.subviews) {
            [self tve_applyOpacityToView:subview withColor:color recursive:YES];
        }
    }
}

- (void)tve_applyTransparencyToView:(UIView *)view recursive:(BOOL)recursive {
    if (!view) {
        return;
    }
    [view.layer removeAnimationForKey:@"tve_bgColor"];
    UIColor *clear = [UIColor clearColor];
    view.backgroundColor = clear;
    view.opaque = NO;
    view.layer.opaque = NO;
    view.layer.backgroundColor = clear.CGColor;
    if (recursive) {
        for (UIView *subview in view.subviews) {
            [self tve_applyTransparencyToView:subview recursive:YES];
        }
    }
}

@end
