//
//  MBCameraViewController.swift
//  DirectAPI-sample-Swift
//
//  Created by Jura Skrlec on 10/05/2018.
//  Copyright © 2018 Microblink. All rights reserved.
//

import UIKit
import AVFoundation
import MicroBlink

class MBCameraViewController: UIViewController, AVCaptureAudioDataOutputSampleBufferDelegate, AVCaptureVideoDataOutputSampleBufferDelegate, MBScanningRecognizerRunnerDelegate {
    var reconfigure: Bool = true

    @IBOutlet var cameraPausedLabel: UILabel!
    @IBOutlet weak var faceStatus: UIButton!
    @IBOutlet weak var mrzStatus: UIButton!

    var captureSession: AVCaptureSession?
    var recognizerRunner: MBRecognizerRunner?
    var pdf417Recognizer: MBPdf417Recognizer?

    var frameGrabber: MBFrameGrabberRecognizer!
    var mrzRecognizer: MBMrtdRecognizer!
    var faceRecognizer: MBDocumentFaceRecognizer!
    var capture = false

    var isPauseRecognition = false
    
    @IBOutlet weak var myView: UIView!
    
    var session: AVCaptureSession?
    var device: AVCaptureDevice?
    var input: AVCaptureDeviceInput?
    var output: AVCaptureMetadataOutput?
    var prevLayer: AVCaptureVideoPreviewLayer?
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        startCaptureSession()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        
        // Note that the app delegate controls the device orientation notifications required to use the device orientation.
        coordinator.animate(alongsideTransition: { (context) -> Void in
            self.prevLayer?.connection?.videoOrientation = self.transformOrientation(orientation: UIInterfaceOrientation(rawValue: UIApplication.shared.statusBarOrientation.rawValue)!)
            self.prevLayer?.frame.size = self.myView.frame.size
        }, completion: { (context) -> Void in
            
        })
        
        super.viewWillTransition(to: size, with: coordinator)
    }
    
    @IBAction func closeCamera(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    func addNotificationObserver() {
        NotificationCenter.default.addObserver(self, selector: #selector(MBCameraViewController.appplicationWillResignActive(_:)), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(MBCameraViewController.appplicationWillEnterForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(MBCameraViewController.applicationDidEnterBackgroundNotification(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(MBCameraViewController.applicationWillTerminateNotification(_:)), name: UIApplication.willTerminateNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(MBCameraViewController.captureSessionDidStartRunning(_:)), name: .AVCaptureSessionDidStartRunning, object: nil)
        NotificationCenter.default.addObserver(self, selector :#selector(MBCameraViewController.captureSessionDidStopRunning(_:)), name: .AVCaptureSessionDidStopRunning, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(MBCameraViewController.captureSessionRuntimeErrorNotification(_:)), name: .AVCaptureSessionRuntimeError, object: nil)
    }
    
    func removeNotificationObserver() {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        addNotificationObserver()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopCaptureSession()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        removeNotificationObserver()
    }
    
    @objc func appplicationWillResignActive(_ note: Notification?) {
        print("Will resign active!")
    }
    
    @objc func appplicationWillEnterForeground(_ note: Notification?) {
        print("appplicationWillEnterForeground!")
        startCaptureSession()
    }
    
    @objc func applicationDidEnterBackgroundNotification(_ note: Notification?) {
        print("applicationDidEnterBackgroundNotification!")
        stopCaptureSession()
    }
    
    @objc func applicationWillTerminateNotification(_ note: Notification?) {
        print("applicationWillTerminateNotification!")
    }
    
    @objc func captureSessionDidStartRunning(_ note: Notification?) {
        print("captureSessionDidStartRunningNotification!")
        UIView.animate(withDuration: 0.3, animations: {() -> Void in
            self.cameraPausedLabel.alpha = 0.0
        })
    }
    
    @objc func captureSessionDidStopRunning(_ note: Notification?) {
        print("captureSessionDidStopRunningNotification!")
        UIView.animate(withDuration: 0.3, animations: {() -> Void in
            self.cameraPausedLabel.alpha = 1.0
        })
    }
    
    @objc func captureSessionRuntimeErrorNotification(_ note: Notification?) {
        print("captureSessionRuntimeErrorNotification!")
    }
    
    func startCaptureSession() {
        debugPrint("Reconfigure: \(reconfigure)")
        // Create session
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .high
        // Init the device inputs
        let videoInput = try? AVCaptureDeviceInput(device: cameraWithPosition(AVCaptureDevice.Position.back)!)
        if let anInput = videoInput {
            captureSession?.addInput(anInput)
        }
        // setup video data output
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey : kCVPixelFormatType_32BGRA] as [String : Any]
        captureSession?.addOutput(videoDataOutput)
        let queue = DispatchQueue(label: "myQueue")
        videoDataOutput.setSampleBufferDelegate(self, queue: queue)
        
        prevLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
        prevLayer?.frame.size = myView.frame.size
        prevLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        
        prevLayer?.connection?.videoOrientation = transformOrientation(orientation: UIInterfaceOrientation(rawValue: UIApplication.shared.statusBarOrientation.rawValue)!)
        
        myView.layer.addSublayer(prevLayer!)

        frameGrabber = MBFrameGrabberRecognizer(frameGrabberDelegate: self)
        faceRecognizer = MBDocumentFaceRecognizer()
        mrzRecognizer = MBMrtdRecognizer()

        let recognizers: [MBRecognizer] = [
            frameGrabber,
            faceRecognizer,
            mrzRecognizer
        ]
//        pdf417Recognizer = MBPdf417Recognizer()
//        recognizers.append(pdf417Recognizer!)

        let recognizerCollection = MBRecognizerCollection(recognizers: recognizers)
        recognizerRunner = MBRecognizerRunner(recognizerCollection: recognizerCollection)
        recognizerRunner?.scanningRecognizerRunnerDelegate = self
        
        captureSession?.startRunning()
    }
    
    func stopCaptureSession() {
        captureSession?.stopRunning()
        captureSession = nil
    }
    
    // Find a camera with the specificed AVCaptureDevicePosition, returning nil if one is not found
    func cameraWithPosition(_ position: AVCaptureDevice.Position) -> AVCaptureDevice?
    {
        let deviceDescoverySession = AVCaptureDevice.DiscoverySession.init(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera],
                                                                              mediaType: AVMediaType.video,
                                                                             position: AVCaptureDevice.Position.unspecified)
        for device in deviceDescoverySession.devices {
            if device.position == position {
                return device
            }
        }
        return nil
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let image = MBImage(cmSampleBuffer: sampleBuffer)
        image.orientation = MBProcessingOrientation.left
        if !isPauseRecognition {
            recognizerRunner?.processImage(image)
        }
    }
    
    func recognizerRunner(_ recognizerRunner: MBRecognizerRunner, didFinishScanningWith state: MBRecognizerResultState) {
        let face = faceRecognizer.result.resultState == .valid
        let mrz = mrzRecognizer.result.resultState == .valid

        debugPrint("FACE: \(face), MRZ \(mrz)")
        if reconfigure {
            if mrz {
                recognizerRunner.reconfigureRecognizers(MBRecognizerCollection(recognizers: [faceRecognizer]))
            }
            if face {
                recognizerRunner.reconfigureRecognizers(MBRecognizerCollection(recognizers: [mrzRecognizer]))
            }
        }

        if face, mrz {
            debugPrint("BOTH VALID!!!")
            capture = true
            isPauseRecognition = true
        } else if face {
            debugPrint("MRZ NOT FOUND!!!")
            reconfigure ? recognizerRunner.resetState(true) : recognizerRunner.resetState()
        } else if mrz {
            debugPrint("FACE NOT FOUND!!!")
            reconfigure ? recognizerRunner.resetState(true) : recognizerRunner.resetState()
        } else {
            debugPrint("NOTHING FOUND!!!")
            reconfigure ? recognizerRunner.resetState(true) : recognizerRunner.resetState()
        }

        DispatchQueue.main.async {
            self.faceStatus.isHighlighted = !face
            self.mrzStatus.isHighlighted = !mrz
        }
    }
    
    func transformOrientation(orientation: UIInterfaceOrientation) -> AVCaptureVideoOrientation {
        switch orientation {
        case .landscapeLeft:
            return .landscapeLeft
        case .landscapeRight:
            return .landscapeRight
        case .portraitUpsideDown:
            return .portraitUpsideDown
        default:
            return .portrait
        }
    }
}

extension MBCameraViewController: MBFrameGrabberRecognizerDelegate {
    public func onFrameAvailable(_ cameraFrame: MBImage, isFocused focused: Bool, frameQuality: CGFloat) {
        guard capture else {
            return
        }
        capture = false
        debugPrint("Grabbing image!")

        DispatchQueue.main.async {
            let title = "SUCCESS"
            // Save the string representation of the code
            let message = "Face and mrz found: \(cameraFrame.image.size)"
            let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .default, handler: {(_ action: UIAlertAction) -> Void in
                self.dismiss(animated: true) {() -> Void in }
            })
            alertController.addAction(okAction)
            self.present(alertController, animated: true) {() -> Void in }
        }
    }
}

extension UIDeviceOrientation {
    var videoOrientation: AVCaptureVideoOrientation? {
        switch self {
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeRight: return .landscapeLeft
        case .landscapeLeft: return .landscapeRight
        case .portrait: return .portrait
        default: return nil
        }
    }
}

extension UIInterfaceOrientation {
    var videoOrientation: AVCaptureVideoOrientation? {
        switch self {
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeRight: return .landscapeRight
        case .landscapeLeft: return .landscapeLeft
        case .portrait: return .portrait
        default: return nil
        }
    }
}
