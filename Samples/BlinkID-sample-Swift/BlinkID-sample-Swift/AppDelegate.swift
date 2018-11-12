//
//  AppDelegate.swift
//  BlinkID-sample-Swift
//
//  Created by Dino on 22/12/15.
//  Copyright © 2015 Dino. All rights reserved.
//

import UIKit
import MicroBlink
import AVFoundation

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        return true
    }
}


//extension NSURLConnection{
//    public override class func initialize() {
//        struct Static {
//            static var token: dispatch_once_t = 0
//        }
//
//        if self !== NSURLConnection.self {
//            return
//        }
//
//        dispatch_once(&Static.token) {
//            let originalSelector = Selector("initWithRequest:delegate:startImmediately:")
//            let swizzledSelector = Selector("initWithTest:delegate:startImmediately:")
//
//            let originalMethod = class_getInstanceMethod(self, originalSelector)
//            let swizzledMethod = class_getInstanceMethod(self, swizzledSelector)
//
//            let didAddMethod = class_addMethod(self, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))
//
//            if didAddMethod {
//                class_replaceMethod(self, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod))
//            } else {
//                method_exchangeImplementations(originalMethod, swizzledMethod)
//            }
//        }
//    }
//
//    // MARK: - Method Swizzling
//    convenience init(test: NSURLRequest, delegate: AnyObject?, startImmediately: Bool){
//        print("Inside Swizzled Method")
//        self.init()
//    }
//}
