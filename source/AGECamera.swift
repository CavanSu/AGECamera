//
//  AGECamera.swift
//  AGECamera
//
//  Created by CavanSu on 2019/12/12.
//  Copyright © 2019 CavanSu. All rights reserved.
//

import UIKit
import AVFoundation

class AGECamera: NSObject {
    
    enum Position {
        case front, back, multi
        
        fileprivate var isMulti: Bool {
            switch self {
            case .front, .back: return false
            case .multi:        return true
            }
        }
        
        fileprivate var description: String {
            switch self {
            case .front: return "front"
            case .back:  return "back"
            case .multi: return "multi"
            }
        }
    }
    
    enum WorkMode {
        case capture
        
        fileprivate var isWorking: Bool {
            switch self {
            case .capture: return true
            }
        }
    }
    
    enum PreviewType {
        struct Front {
            var view: AGECameraPreview
        }
        
        struct Back {
            var view: AGECameraPreview
        }
        
        case single(AGECameraPreview), multi(Front, Back)
        
        var views: [AGECameraPreview] {
            switch self {
            case .single(let view):           return [view]
            case .multi(let front, let back): return [front.view, back.view]
            }
        }
    }
    
    fileprivate struct OldItems {
        var deviceInput: AVCaptureDeviceInput?
        var videoDataOutput: AVCaptureVideoDataOutput?
        var videoDataConnection: AVCaptureConnection?
        var previewConnnection: AVCaptureConnection?
    }
    
    private(set) var position: Position = .back
    
    private var preview: PreviewType?
    
    var backPreview: AGECameraPreview?
    var frontPreview: AGECameraPreview?
    
    private lazy var singleSession = AGECameraCaptureSingleSession()
    private lazy var multiSession = AGECameraCaptureMultiSession()
    
    private let mediaOutputQueue = DispatchQueue(label: "AGECameraMediaDataOutputQueue")
    
    private var workingMode: WorkMode?
    
    private var workingSession: AGECameraSession? {
        switch position {
        case .front, .back: return singleSession
        case .multi:        return multiSession
        }
    }
    
    init?(position: Position) throws {
        super.init()
        
        try checkIsSimulator()
        
        if position == .multi {
            try checkSystemVersionSupportMultiStream()
        }
        
        self.position = position
    }
}

// MARK: -
extension AGECamera {
    func start(work: WorkMode) throws {
        if let current = workingMode, current == work {
            return
        }
        
        switch work {
        case .capture: try startVideoCapture(); workingMode = work
        }
    }
    
    func stopWork() {
        guard let _ = workingMode else {
            return
        }
        workingMode = nil
        workingSession?.noumenon.stopRunning()
    }
    
    func switchPosition(_ position: Position) throws {
        let oldPosition = self.position
        guard oldPosition != position else {
            return
        }
        
        if position == .multi {
            try checkSystemVersionSupportMultiStream()
        }
        
        self.position = position
        
        guard let mode = workingMode else {
            return
        }
        
        switch mode {
        case .capture: try prepareSessionConfigurateion(position: position, oldPosition: oldPosition)
        }

        if !oldPosition.isMulti, position.isMulti {
            singleSession.noumenon.stopRunning()
            multiSession.noumenon.startRunning()
        } else if oldPosition.isMulti, !position.isMulti {
            multiSession.noumenon.stopRunning()
            singleSession.noumenon.startRunning()
        }
    }
}

// MARK: - Video Data Capture
private extension AGECamera {
    func startVideoCapture() throws {
        if position == .multi {
            try checkSystemVersionSupportMultiStream()
        }
        
        try checkCameraPermision { [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            try strongSelf.prepareSessionConfigurateion(position: strongSelf.position, oldPosition: strongSelf.position)
            
            guard let session = strongSelf.workingSession else {
                throw AGECameraError(type: .valueNil("workingSession"))
            }
            
            session.noumenon.startRunning()
        }
    }
}

private extension AGECamera {
    func prepareSessionConfigurateion(position: Position, oldPosition: Position) throws {
        guard var session = workingSession else {
            throw AGECameraError(type: .valueNil("workingSession"))
        }
        
        // start configuring session
        session.noumenon.beginConfiguration()
        defer {
            //save configuration setting
            session.noumenon.commitConfiguration()
        }
        
        if !oldPosition.isMulti, position.isMulti {
            singleSession.clean()
        } else if oldPosition.isMulti, !position.isMulti {
            multiSession.clean()
        }
        
        switch position {
        case .front, .back:
            let oldDeviceInput = (position == .back ? singleSession.frontCameraInput : singleSession.backCameraInput)
            let oldVideoDataOutput = (position == .back ? singleSession.frontVideoDataOutput : singleSession.backVideoDataOutput)
            let oldVideoConnection = (position == .back ? singleSession.frontVideoDataConnection : singleSession.backVideoDataConnection)
            let oldPreviewConnection = (position == .back ? singleSession.frontVideoPreviewConnection : singleSession.backVideoPreviewConnection)
            
            let preview = position == .back ? backPreview : frontPreview
            
            let olds = OldItems(deviceInput: oldDeviceInput,
                                videoDataOutput: oldVideoDataOutput,
                                videoDataConnection: oldVideoConnection,
                                previewConnnection: oldPreviewConnection)

            try sessionConfiguration(position: position, preview: preview, olds: olds)
        case .multi:
            let frontOlds = OldItems(deviceInput: multiSession.frontCameraInput,
                                     videoDataOutput: multiSession.frontVideoDataOutput,
                                     videoDataConnection: multiSession.frontVideoPreviewConnection,
                                     previewConnnection: multiSession.frontVideoPreviewConnection)
            
            try sessionConfiguration(position: .front, preview: frontPreview, olds: frontOlds)
            
            let backOlds = OldItems(deviceInput: multiSession.backCameraInput,
                                    videoDataOutput: multiSession.backVideoDataOutput,
                                    videoDataConnection: multiSession.backVideoPreviewConnection,
                                    previewConnnection: multiSession.backVideoPreviewConnection)
            
            try sessionConfiguration(position: .back, preview: backPreview, olds: backOlds)
        }
    }
    
    func sessionConfiguration(position: Position, preview: AGECameraPreview?, olds: OldItems) throws {
        guard var session = workingSession else {
            throw AGECameraError(type: .valueNil("workingSession"))
        }
        
        // AVCaptureDevice search camera
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video,
                                                   position: position == .front ? .front : .back) else {
                                                    throw AGECameraError(type: .fail("no \(position.description) camera"))
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
//        if session.noumenon is AVCaptureMultiCamSession {
//            session.noumenon.sessionPreset = .inputPriority
//        } else if session.noumenon.canSetSessionPreset(.hd1280x720) {
//            session.noumenon.sessionPreset = .hd1280x720
//        }
        
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
        guard session.noumenon.canAddConnection(newDataConnection) else {
            throw AGECameraError(type: .fail("no connection to the \(position.description) camera video data output"))
        }
        session.noumenon.addConnection(newDataConnection)
        newDataConnection.videoOrientation = .landscapeLeft
        
        // connect input to layer
        var newPreviewConnection: AVCaptureConnection?
        
        if let preview = preview {
            preview.videoPreviewLayer.setSessionWithNoConnection(session.noumenon)
            
            newPreviewConnection = AVCaptureConnection(inputPort: videoPort, videoPreviewLayer: preview.videoPreviewLayer)
            guard session.noumenon.canAddConnection(newPreviewConnection!) else {
                throw AGECameraError(type: .fail("no a connection to the \(position.description) camera video preview layer"))
            }
            session.noumenon.addConnection(newPreviewConnection!)
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
        default: break
        }
    }
}

extension AGECamera: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
    }
}

// MARK: - Check system, device, premission
private extension AGECamera {
    func checkIsSimulator() throws {
        #if targetEnvironment(simulator)
        throw AGECameraError(type: .fail("please run on physical device"))
        #endif
    }
    
    @discardableResult func checkSystemVersionSupportMultiStream() throws -> Bool {
        if !ProcessInfo().isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 13, minorVersion: 0, patchVersion: 0)),
            !AVCaptureMultiCamSession.isMultiCamSupported {
            throw AGECameraError(type: .fail("multi camera at least iOS 13 and device iphone xs or later"))
        }
        return true
    }
    
    func checkCameraPermision(granted: AGECameraEXCompletion) throws {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            if let granted = granted {
                try granted()
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { isGranted in
                if isGranted, let granted = granted {
                    try? granted()
                }
            })
        default:
            // previously denied access.
            throw AGECameraError(type: .fail("device doesn't have permission to use the camera, please change privacy settings"))
        }
    }
}
