//
//  CameraController.swift
//  ReceiptTracker-v2
//
//  Created by Chen Yu Hang on 21/2/22.
//

import Foundation
import AVFoundation
import UIKit

class CameraController:NSObject {
    
    var captureSession: AVCaptureSession?
    
    // For the rear camera
    var rearCamera: AVCaptureDevice?
    var rearCameraInput: AVCaptureDeviceInput?
    
    
    // Photo output
    var photoOutput: AVCapturePhotoOutput?
    
    
    // Need a preview to see the screen
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    // create a var to hold the completion function for photo taking
    var photoOutputCompletionBlock: ((UIImage?, Error?) -> Void)?
}


extension CameraController {
    
    func prepare(completionHandler: @escaping (Error?) -> Void){
        
        
        func createCaptureSession() {
            self.captureSession = AVCaptureSession()
        }
        
        func configureDevices() throws {
            let session = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .unspecified)
            
            let cameras = session.devices.compactMap{ $0 }
            
            guard !cameras.isEmpty else { throw CameraControllerError.NoCameraAvailable }
            
            for camera in cameras {
                if camera.position == .back {
                    self.rearCamera = camera
                    
                    // In order to set hardware properties on an AVCaptureDevice, such as focusMode and exposureMode, clients must first acquire a lock on the device.
                    try camera.lockForConfiguration()
                    self.rearCamera?.focusMode = .continuousAutoFocus
                    camera.unlockForConfiguration()
                }
            }
        }
        
        
        func configureInputDevices() throws {
            guard let captureSession = self.captureSession else { throw CameraControllerError.CaptureSessionInvalid }
        
            if let rearCamera = self.rearCamera {
                self.rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
                
                if captureSession.canAddInput(self.rearCameraInput!) {
                    captureSession.addInput(self.rearCameraInput!)
                }
            }
        }
        
        
        func configureOutput() throws {
            guard let captureSession = self.captureSession else { throw CameraControllerError.CaptureSessionInvalid }
            
            self.photoOutput = AVCapturePhotoOutput()
            self.photoOutput?.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey : AVVideoCodecType.jpeg])], completionHandler: nil)
            
            if captureSession.canAddOutput(self.photoOutput!) {
                captureSession.addOutput(self.photoOutput!)
            }
            
            captureSession.startRunning()
        }
        
        DispatchQueue(label: "prepare").async {
            do {
                // Create Capture Session
                createCaptureSession()
                // Configure and find the available devices
                try configureDevices()
                // Create the inputs from the devices
                try configureInputDevices()
                // Configure the outputs
                try configureOutput()
                
            } catch {
                // Dispatch back to main thread
                DispatchQueue.main.async {
                    completionHandler(error)
                }
            }
            
            // Dispatch back to main thread
            DispatchQueue.main.async {
                completionHandler(nil)
            }
        }
    }
    
    
    func displayPreview(on view: UIView) throws {
        guard let captureSession = self.captureSession, captureSession.isRunning else { throw CameraControllerError.CaptureSessionInvalid }
        
        self.previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.previewLayer?.frame = view.frame
        self.previewLayer?.connection?.videoOrientation = .portrait
        self.previewLayer?.videoGravity = .resizeAspectFill
        
        view.layer.insertSublayer(self.previewLayer!, at: 0)
    }
    
    func captureImage(completion: @escaping (UIImage?, Error?) -> Void) {
        guard let captureSession = self.captureSession, captureSession.isRunning else { completion(nil, CameraControllerError.CaptureSessionInvalid); return }
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        
        self.photoOutput?.capturePhoto(with: settings, delegate: self)
        self.photoOutputCompletionBlock = completion
    }
    
    func focusCamera(focusPoint: CGPoint) throws {
        guard let captureSession = self.captureSession, captureSession.isRunning else { throw CameraControllerError.CaptureSessionInvalid }
        
        let focusScaledPointX = focusPoint.x / self.previewLayer!.frame.width
        let focusScaledPointY = focusPoint.y / self.previewLayer!.frame.height
        
        if self.rearCamera!.isFocusModeSupported(.autoFocus) && self.rearCamera!.isFocusPointOfInterestSupported {
            do {
                try self.rearCamera!.lockForConfiguration()
            } catch {
                print("ERROR: Could not lock camera device for configuration")
                return
            }
             
            self.rearCamera!.focusMode = .autoFocus
            self.rearCamera!.focusPointOfInterest = CGPoint(x: focusScaledPointX, y: focusScaledPointY)
                
            self.rearCamera!.unlockForConfiguration()
        }
    }
}

extension CameraController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error { self.photoOutputCompletionBlock?(nil, error); return }
        
        else if let imageData = photo.fileDataRepresentation(), let UIImage = UIImage(data: imageData) {
            photoOutputCompletionBlock?(UIImage, nil)
        } else {
            photoOutputCompletionBlock?(nil, CameraControllerError.CaptureSessionInvalid)
        }
    }
}

extension CameraController {
    enum CameraControllerError: Swift.Error {
        case CaptureSessionIsRunning
        case CaptureSessionInvalid
        case CaptureInputDeviceInvalid
        case InvalidOperation
        case NoCameraAvailable
        case unknown
    }
}
