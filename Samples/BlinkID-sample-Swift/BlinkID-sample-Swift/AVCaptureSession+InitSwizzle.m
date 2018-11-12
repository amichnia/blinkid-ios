//
//  AVCaptureSession+InitSwizzle.m
//  BlinkID-sample-Swift
//
//  Created by Andrzej Michnia on 12/11/2018.
//  Copyright © 2018 Dino. All rights reserved.
//

#import "AVCaptureSession+InitSwizzle.h"
#import <objc/runtime.h>

@implementation AVCaptureSession (InitSwizzle)

static AVCaptureSession* __current_session;

+ (AVCaptureSession *)current {
    return __current_session;
}

+ (void)setCurrent:(AVCaptureSession *)current {
    __current_session = current;
}

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];

        SEL originalSelector = @selector(init);
        SEL swizzledSelector = @selector(xxx_init);

        Method originalMethod = class_getInstanceMethod(class, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);

        BOOL didAddMethod = class_addMethod(class, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));

        if (didAddMethod) {
            class_replaceMethod(class, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    });
}

#pragma mark - Method Swizzling
- (instancetype)xxx_init {
    id newSession = [self xxx_init];
    NSLog(@"Session is being initialized!");
    AVCaptureSession.current = newSession;
    return  newSession;
}

@end
