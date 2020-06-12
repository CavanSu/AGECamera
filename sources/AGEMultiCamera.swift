//
//  AGEMultiCamera.swift
//  AGECamera
//
//  Created by CavanSu on 2019/12/19.
//  Copyright © 2019 CavanSu. All rights reserved.
//

import UIKit
import AVFoundation

public protocol AGEMultiCameraDelegate: NSObjectProtocol {
    func multiCamera(_ camera: AGEMultiCamera, position: Position, didOutput sampleBuffer: CMSampleBuffer)
}

public class AGEMultiCamera: NSObject, AGEMultiCameraProtocol {
    fileprivate struct OldItems {
        var deviceInput: AVCaptureDeviceInput?
        var videoDataOutput: AVCaptureVideoDataOutput?
        var videoDataConnection: AVCaptureConnection?
        var previewConnnection: AVCaptureConnection?
    }
    
    public enum WorkMode {
        case capture
        
        fileprivate var isWorking: Bool {
            switch self {
            case .capture: return true
            }
        }
    }
    
    private lazy var workingSession = AGECameraCaptureMultiSession()
    
    private let mediaOutputQueue = DispatchQueue(label: "AGEMultiCameraMediaDataOutputQueue")
    
    private var workingMode: WorkMode?
    
    public weak var delegate: AGEMultiCameraDelegate?
    
    public var backPreview: AGECameraPreview?
    public var frontPreview: AGECameraPreview?
    
    public init?(backPreview: AGECameraPreview? = nil, frontPreview: AGECameraPreview? = nil) throws {
        super.init()
        self.backPreview = backPreview
        self.frontPreview = frontPreview
        try checkIsSimulator()
        try checkSystemVersionSupportMultiStream()
    }
}

public extension AGEMultiCamera {
    func start(work: WorkMode) throws {
        if let current = workingMode, current == work {
            return
        }
        
        workingMode = work
        
        switch work {
        case .capture: try startVideoCapture()
        }
    }
    
    func stopWork() {
        guard let _ = workingMode else {
            return
        }
        workingMode = nil
        workingSession.noumenon.stopRunning()
    }
}

private extension AGEMultiCamera {
    func startVideoCapture() throws {
        try checkCameraPermision { [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            try strongSelf.prepareSessionConfigurateion()
            
            strongSelf.workingSession.noumenon.startRunning()
        }
    }
}

private extension AGEMultiCamera {
    func prepareSessionConfigurateion() throws {
        let session = workingSession
        
        let frontOlds = OldItems(deviceInput: session.frontCameraInput,
                                 videoDataOutput: session.frontVideoDataOutput,
                                 videoDataConnection: session.frontVideoPreviewConnection,
                                 previewConnnection: session.frontVideoPreviewConnection)
        
        try sessionConfiguration(position: .front, preview: frontPreview, olds: frontOlds)
        
        let backOlds = OldItems(deviceInput: session.backCameraInput,
                                videoDataOutput: session.backVideoDataOutput,
                                videoDataConnection: session.backVideoPreviewConnection,
                                previewConnnection: session.backVideoPreviewConnection)
        
        try sessionConfiguration(position: .back, preview: backPreview, olds: backOlds)
    }
    
    func sessionConfiguration(position: Position, preview: AGECameraPreview?, olds: OldItems) throws {
        guard #available(iOS 13.0, *) else {
            throw AGECameraError(type: .fail("unsupport this position: \(position.rawValue)"))
        }
        
        let session = workingSession
        
        // AVCaptureDevice search camera
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video,
                                                   position: position == .front ? .front : .back) else {
                                                    throw AGECameraError(type: .fail("no \(position.description) camera"))
        }
        
        try camera.lockForConfiguration()
        // start configuring session
        session.noumenon.beginConfiguration()
        
        defer {
            //save configuration setting
            session.noumenon.commitConfiguration()
            camera.unlockForConfiguration()
        }
        
        // remove device input
        if let oldDeviceInput = olds.deviceInput {
            session.noumenon.removeInput(oldDeviceInput)
        }
        
        // append camera input to session
        let newCameraDeviceInput = try AVCaptureDeviceInput(device: camera)
        
        guard session.noumenon.canAddInput(newCameraDeviceInput) else {
                throw AGECameraError(type: .fail("session can not add \(position.description) camera input"))
        }
        session.noumenon.addInputWithNoConnections(newCameraDeviceInput)
        
        // AVCaptureSession.Preset
        if session.noumenon.canSetSessionPreset(.inputPriority) {
            session.noumenon.sessionPreset = .inputPriority
        }
        
        // AVCaptureVideoDataOutput
        if let oldVideoDataOutput = olds.videoDataOutput {
            session.noumenon.removeOutput(oldVideoDataOutput)
        }
        
        let newVideoDataOutput = AVCaptureVideoDataOutput()
        guard session.noumenon.canAddOutput(newVideoDataOutput) else {
            throw AGECameraError(type: .fail("no \(position.description) camera output"))
        }
        session.noumenon.addOutputWithNoConnections(newVideoDataOutput)
        newVideoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
        newVideoDataOutput.setSampleBufferDelegate(self, queue: mediaOutputQueue)
        
        // AVCaptureInput.Port
        guard let videoPort = newCameraDeviceInput.ports(for: .video,
                                                      sourceDeviceType: camera.deviceType,
                                                      sourceDevicePosition: camera.position).first else {
                                                        throw AGECameraError(type: .fail("no \(position.description) camera input's video port"))
        }
                
        let newDataConnection = AVCaptureConnection(inputPorts: [videoPort], output: newVideoDataOutput)
        guard session.noumenon.canAdd(newDataConnection) else {
            throw AGECameraError(type: .fail("no connection to the \(position.description) camera video data output"))
        }
        session.noumenon.add(newDataConnection)
        newDataConnection.videoOrientation = .landscapeLeft
        
        // connect input to layer
        var newPreviewConnection: AVCaptureConnection?
        
        if let preview = preview {
            preview.videoPreviewLayer.setSessionWithNoConnection(session.noumenon)
            
            newPreviewConnection = AVCaptureConnection(inputPort: videoPort, videoPreviewLayer: preview.videoPreviewLayer)
            guard session.noumenon.canAdd(newPreviewConnection!) else {
                throw AGECameraError(type: .fail("no a connection to the \(position.description) camera video preview layer"))
            }
            session.noumenon.add(newPreviewConnection!)
        }
        
        switch position {
        case .front:
            session.frontCameraInput = newCameraDeviceInput
            session.frontVideoDataOutput = newVideoDataOutput
            session.frontVideoDataConnection = newDataConnection
            session.frontVideoPreviewConnection = newPreviewConnection
        case .back:
            session.backCameraInput = newCameraDeviceInput
            session.backVideoDataOutput = newVideoDataOutput
            session.backVideoDataConnection = newDataConnection
            session.backVideoPreviewConnection = newPreviewConnection
        case .unspecified:
            throw AGECameraError(type: .fail("unsupport this position: \(position.rawValue)"))
        @unknown default:
            fatalError()
        }
    }
}

extension AGEMultiCamera: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        var position: Position
        
        if connection == workingSession.backVideoDataConnection {
            position = .back
        } else if connection == workingSession.frontVideoDataConnection {
            position = .front
        } else {
            return
        }
        
        delegate?.multiCamera(self,
                              position: position,
                              didOutput: sampleBuffer)
    }
}
