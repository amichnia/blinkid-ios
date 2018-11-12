//
//  AVCaptureSession+InitSwizzle.h
//  BlinkID-sample-Swift
//
//  Created by Andrzej Michnia on 12/11/2018.
//  Copyright © 2018 Dino. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AVCaptureSession (InitSwizzle)

/**
 Current AVCaptureSession instance. Will contain the last session created.
 */
@property (class) AVCaptureSession *current;

@end

NS_ASSUME_NONNULL_END
