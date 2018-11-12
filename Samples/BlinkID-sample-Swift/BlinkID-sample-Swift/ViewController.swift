//
//  ViewController.swift
//  BlinkID-sample-Swift
//
//  Created by Dino on 22/12/15.
//  Copyright © 2015 Dino. All rights reserved.
//

import UIKit
import MicroBlink
import AVFoundation

extension MBCameraPreset {
    var name: String {
        switch self {
        case .preset480p:       return "480p"
        case .preset720p:       return "720p"
        case .presetPhoto:      return "photo"
        case .presetMax:        return "max"
        case .presetOptimal:    return "optimal"
        }
    }
}

class ViewController: UIViewController {
    
    var mrtdRecognizer : MBMrtdRecognizer?
    var usdlRecognizer : MBUsdlRecognizer?
    var eudlRecognizer : MBEudlRecognizer?
    var grabber: MBFrameGrabberRecognizer?
    var overlayController: MBDocumentOverlayViewController?
    var runner: MBRecognizerRunnerViewController!

    var session: AVCaptureSession!
//    var device: AVCaptureDevice!
//    var input: AVCaptureDeviceInput!
    var image: AVCaptureStillImageOutput!
    var preset: MBCameraPreset!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Valid until: 2018-12-24
        MBMicroblinkSDK.sharedInstance().setLicenseResource("blinkid-license", withExtension: "txt", inSubdirectory: "", for: Bundle.main)
    }

    func setupSession() {
        print("setting up session")
        session = AVCaptureSession.current;
        print("Session \(session) isRunning = \(session.isRunning)")

        session.sessionPreset = .photo
//        let devices = AVCaptureDevice.devices(for: AVMediaType.video)
//
//        guard let device = devices.first(where: { $0.position == .back }) else {
//            fatalError()
//        }
//
//        let input: AVCaptureDeviceInput = try! AVCaptureDeviceInput(device: device)
//        self.input = input
//        session.addInput(input)

        image = (session.outputs.first(where: { output -> Bool in
            print(output)
            return output is AVCaptureStillImageOutput
        }) as? AVCaptureStillImageOutput)

        if image == nil {
            print("Still image output not found! Crating new")
            image = AVCaptureStillImageOutput()
            session.addOutput(image)
        }

        if session.isRunning {
            print("Session already running")
        } else {
            print("Session not running - START")
            session.startRunning()
        }
    }

    @IBAction func didTapScan(_ sender: AnyObject) {
        
        // To specify we want to perform MRTD (machine readable travel document) recognition, initialize the MRTD recognizer settings
        self.mrtdRecognizer = MBMrtdRecognizer()
        self.mrtdRecognizer?.returnFullDocumentImage = true;
        self.mrtdRecognizer?.allowUnverifiedResults = true;
        self.mrtdRecognizer?.saveImageDPI = 400

        /** Create usdl recognizer */
        self.usdlRecognizer = MBUsdlRecognizer()

        /** Create eudl recognizer */
        self.eudlRecognizer = MBEudlRecognizer()
        self.eudlRecognizer?.returnFullDocumentImage = true

        /** Create frame grabber */
        self.grabber = MBFrameGrabberRecognizer(frameGrabberDelegate: self)

        /** Create barcode settings */
        let settings : MBDocumentOverlaySettings = MBDocumentOverlaySettings()

        // MARK: - Testing various camera presets
//        settings.cameraSettings.cameraPreset = MBCameraPreset.presetPhoto
        settings.cameraSettings.cameraPreset = MBCameraPreset.presetMax
//        settings.cameraSettings.cameraPreset = MBCameraPreset.presetOptimal
//        settings.cameraSettings.cameraPreset = MBCameraPreset.preset720p
        self.preset = settings.cameraSettings.cameraPreset
        settings.tooltipText = "Capture with \(preset.name)"
        
        /** Crate recognizer collection */
        let recognizerList = [self.mrtdRecognizer!, self.usdlRecognizer!, self.eudlRecognizer!]
        let recognizerCollection : MBRecognizerCollection = MBRecognizerCollection(recognizers: recognizerList)
        
        /** Create your overlay view controller */
        let barcodeOverlayViewController :
            MBDocumentOverlayViewController = MBDocumentOverlayViewController(settings: settings, recognizerCollection: recognizerCollection, delegate: self)
        self.overlayController = barcodeOverlayViewController


        /** Create recognizer view controller with wanted overlay view controller */
        let recognizerRunneViewController : UIViewController = MBViewControllerFactory.recognizerRunnerViewController(withOverlayViewController: barcodeOverlayViewController)
//        recognizerRunneViewController.supportedInterfaceOrientations = UIInterfaceOrientationMask.landscape
        let runner = recognizerRunneViewController as! MBRecognizerRunnerViewController
//        runner.autorotate = true
        runner.supportedOrientations = UIInterfaceOrientationMask.landscape
        self.runner = runner

        /** Present the recognizer runner view controller. You can use other presentation methods as well (instead of presentViewController) */
        self.present(recognizerRunneViewController, animated: true, completion: nil)

//        setupSession()
    }

    public func takePhoto() {
        setupSession()

        guard let videoConnection = image.connection(with: AVMediaType.video) else {
            return
        }
        guard !image.isCapturingStillImage else {
            return
        }

        func convert(cmage: CIImage) -> UIImage {
            let context = CIContext(options: nil)
            guard let cgImage: CGImage = context.createCGImage(cmage, from: cmage.extent) else {
                fatalError("Failed to create CGImage from CIImage")
            }
            return UIImage(cgImage: cgImage)
        }

        image.captureStillImageAsynchronously(from: videoConnection) { [weak self] sampleBuffer, error in
            guard let buffer = sampleBuffer, error == nil else {
                fatalError("Sample Buffer is nil, or there is error = \(String(describing: error))")
            }
            print(buffer)

            guard let imageBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(buffer) else {
                fatalError("Cannot construct CVPixelBuffer")
            }

            let ciimage : CIImage = CIImage(cvPixelBuffer: imageBuffer)
            let image : UIImage = convert(cmage: ciimage)

            let sizeMessage = "\(image.size.mpx >= 3 ? "√" : "X") - Image size is \(image.size), \(image.size.mpx)Mpx"
            print(sizeMessage)

            guard let `self` = self else { return }

            /** Needs to be called on main thread beacuse everything prior is on background thread */
            DispatchQueue.main.async {
                // present the alert view with scanned results

                let alertController: UIAlertController = UIAlertController.init(title: self.alertTitle,
                                                                                message: "\(sizeMessage)\n" + self.message,
                                                                                preferredStyle: .alert)

                let okAction: UIAlertAction = UIAlertAction.init(title: "OK",
                                                                 style: .default,
                                                                 handler: { _ in
                                                                    self.dismiss(animated: true, completion: nil)
                })
                alertController.addAction(okAction)
                self.presentedViewController?.present(alertController, animated: true, completion: nil)
            }
        }
    }

    var captured = false
    var message: String = ""
    var alertTitle: String = ""
}

extension ViewController: MBFrameGrabberRecognizerDelegate {
    func onFrameAvailable(_ cameraFrame: MBImage, isFocused focused: Bool, frameQuality: CGFloat) {
        guard !captured else { return }
        let image = cameraFrame.image
        print("Preset: \(preset.name), size: \(image.size)")
        captured = true
    }
}

extension ViewController: MBDocumentOverlayViewControllerDelegate {
    
    func documentOverlayViewControllerDidFinishScanning(_ documentOverlayViewController: MBDocumentOverlayViewController, state: MBRecognizerResultState) {
        /** This is done on background thread */
        documentOverlayViewController.recognizerRunnerViewController?.pauseScanning()

        if (self.mrtdRecognizer?.result.resultState == MBRecognizerResultState.valid) {
            alertTitle = "MRTD"
            
            let fullDocumentImage: UIImage! = self.mrtdRecognizer?.result.fullDocumentImage?.image
            print("Got MRTD image with width: \(fullDocumentImage.size.width), height: \(fullDocumentImage.size.height)")
            
            // Save the string representation of the code
            message = self.mrtdRecognizer!.result.description

            takePhoto() // Take full photo with current hijacked session

            // Not using frame grabber, as the image size is too small
//            documentOverlayViewController.reconfigureRecognizers(MBRecognizerCollection(recognizers: [grabber!]))
//            runner.resumeScanningAndResetState(true)
        }
        else if (self.usdlRecognizer?.result.resultState == MBRecognizerResultState.valid) {
            alertTitle = "USDL"
            
            // Save the string representation of the code
            message = (self.usdlRecognizer?.result.description)!

            takePhoto() // Take full photo with current hijacked session
        }
        else if (self.eudlRecognizer?.result.resultState == MBRecognizerResultState.valid) {
            alertTitle = "EUDL"
            
            let fullDocumentImage: UIImage! = self.eudlRecognizer?.result.fullDocumentImage?.image
            print("Got EUDL image with width: \(fullDocumentImage.size.width), height: \(fullDocumentImage.size.height)")
            
            // Save the string representation of the code
            message = (self.eudlRecognizer?.result.description)!

            takePhoto() // Take full photo with current hijacked session
        }
    }
    
    func documentOverlayViewControllerDidTapClose(_ documentOverlayViewController: MBDocumentOverlayViewController) {
        self.dismiss(animated: true, completion: nil)
    }
}



