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
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var sizeLabel: UILabel!
    
    var captureSession: AVCaptureSession?
    var recognizerRunner: MBRecognizerRunner?

    var mrzRecognizer: MBMrtdRecognizer!
    var faceRecognizer: MBDocumentFaceRecognizer!
    var capture = false

    var isPauseRecognition = false
    
    @IBOutlet weak var myView: UIView!

    var device: AVCaptureDevice?
    var input: AVCaptureDeviceInput?
    var video: AVCaptureVideoDataOutput?
    var image: AVCaptureStillImageOutput?
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
        captureSession?.sessionPreset = .photo
        // Init the device inputs
        let videoInput = try? AVCaptureDeviceInput(device: cameraWithPosition(AVCaptureDevice.Position.back)!)
        if let anInput = videoInput {
            captureSession?.addInput(anInput)
        }
        // setup video data output
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey : kCVPixelFormatType_32BGRA] as [String : Any]
        captureSession?.addOutput(videoDataOutput)
        video = videoDataOutput

        // MARK: - Add Additional Output to capture still images
        let imageOutput = AVCaptureStillImageOutput() // deprecated in iOS 10.0, we still support iOS 9.0
        captureSession?.addOutput(imageOutput)
        image = imageOutput

        let queue = DispatchQueue(label: "myQueue")
        videoDataOutput.setSampleBufferDelegate(self, queue: queue)
        
        prevLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
        prevLayer?.frame.size = myView.frame.size
        prevLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        
        prevLayer?.connection?.videoOrientation = transformOrientation(orientation: UIInterfaceOrientation(rawValue: UIApplication.shared.statusBarOrientation.rawValue)!)
        
        myView.layer.addSublayer(prevLayer!)

        faceRecognizer = MBDocumentFaceRecognizer()
        mrzRecognizer = MBMrtdRecognizer()

        let recognizers: [MBRecognizer] = [
            faceRecognizer,
            mrzRecognizer
        ]

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

    @IBAction func simulateFaceWasFound() {
        faceWasFound = true
    }

    var faceWasFound = false
    var mrzWasFound = false

    func recognizerRunner(_ recognizerRunner: MBRecognizerRunner, didFinishScanningWith state: MBRecognizerResultState) {
        let mrz = mrzRecognizer.result.resultState == .valid
        let face = faceRecognizer.result.resultState == .valid // That is never true, face never is found in 4.0.3


        if mrz {
            mrzWasFound = true
            recognizerRunner.reconfigureRecognizers(MBRecognizerCollection(recognizers: [faceRecognizer]))
        }
        if face {
            faceWasFound = true
            recognizerRunner.reconfigureRecognizers(MBRecognizerCollection(recognizers: [mrzRecognizer]))
        }

        if mrzWasFound, faceWasFound {
            // Take manual photo to assure highest quality possible
            takePhoto()
            mrzWasFound = false
            faceWasFound = false
        } else {
            recognizerRunner.resetState(true)
        }

        DispatchQueue.main.async {
            self.faceStatus.isHighlighted = !self.faceWasFound
            self.mrzStatus.isHighlighted = !self.mrzWasFound
        }
    }

    // MARK: - Important!!!
    /// This is something we could do only with using direct api now. One of the possible solutions to providing us the images big enough, is to
    /// expose this "takePhoto" thing within SDK, to be able to use it with using DocumentOverlayViewControllers provided by Microblink.
    public func takePhoto() {
        guard let image = self.image else { return }
        guard let videoConnection = image.connection(with: AVMediaType.video) else {
            return
        }
        guard !image.isCapturingStillImage else { return }

        image.captureStillImageAsynchronously(from: videoConnection) { [weak self] sampleBuffer, error in
            guard sampleBuffer != nil, error == nil else { return }
            guard let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(sampleBuffer!) else { return }
            guard let image = UIImage(data: imageData) else { return }

            DispatchQueue.main.async {
                self?.presentCaptured(image)
            }
        }
    }

    func presentCaptured(_ image: UIImage) {
        self.sizeLabel.text = "Image size: \(image.size)"
        let imageView = UIImageView(image: image)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        view.insertSubview(imageView, belowSubview: closeButton)
        imageView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        imageView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        imageView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
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
