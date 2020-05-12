//
//  AGESingleCamera.swift
//  AGECamera
//
//  Created by CavanSu on 2019/12/18.
//  Copyright © 2019 Agora. All rights reserved.
//

import UIKit
import AVFoundation

protocol AGESingleCameraDelegate: NSObjectProtocol {
    func camera(_ camera: AGESingleCamera, position: AGECameraPosition, didOutput sampleBuffer: CMSampleBuffer)
}

class AGESingleCamera: NSObject, AGECameraProtocol {
    fileprivate struct OldItems {
        var deviceInput: AVCaptureDeviceInput?
        var videoDataOutput: AVCaptureVideoDataOutput?
        var videoDataConnection: AVCaptureConnection?
        var previewConnnection: AVCaptureConnection?
    }
    
    enum WorkMode {
        case capture
        
        fileprivate var isWorking: Bool {
            switch self {
            case .capture: return true
            }
        }
    }
    
    private(set) var position: AGECameraPosition
    
    private lazy var workingSession = AGECameraCaptureSingleSession()
    
    private let mediaOutputQueue = DispatchQueue(label: "AGESingleCameraMediaDataOutputQueue")
    
    private var workingMode: WorkMode?
    
    weak var delegate: AGESingleCameraDelegate?
    
    var preview: AGECameraPreview?
    
    init?(position: AGECameraPosition) throws {
        self.position = position
        super.init()
        try checkIsSimulator()
    }
}

extension AGESingleCamera {
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
        workingSession.clean()
    }
    
    func switchPosition(_ position: AGECameraPosition) throws {
        let oldPosition = self.position
        guard oldPosition != position else {
            return
        }
        
        self.position = position
        
        guard let mode = workingMode else {
            return
        }
        
        switch mode {
        case .capture: try prepareSessionConfigurateion(position: position)
        }
    }
    
    func set(resolution: AVCaptureSession.Preset) {
        if workingSession.noumenon.canSetSessionPreset(resolution) {
            workingSession.noumenon.sessionPreset = resolution
        }
    }
}

// MARK: - Video Data Capture
private extension AGESingleCamera {
    func startVideoCapture() throws {
        try checkCameraPermision { [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            try strongSelf.prepareSessionConfigurateion(position: strongSelf.position)
            
            strongSelf.workingSession.noumenon.startRunning()
        }
    }
}

private extension AGESingleCamera {
    func prepareSessionConfigurateion(position: AGECameraPosition) throws {
        let oldDeviceInput = (position == .back ? workingSession.frontCameraInput : workingSession.backCameraInput)
        let oldVideoDataOutput = (position == .back ? workingSession.frontVideoDataOutput : workingSession.backVideoDataOutput)
        let oldVideoConnection = (position == .back ? workingSession.frontVideoDataConnection : workingSession.backVideoDataConnection)
        let oldPreviewConnection = (position == .back ? workingSession.frontVideoPreviewConnection : workingSession.backVideoPreviewConnection)
        
        let olds = OldItems(deviceInput: oldDeviceInput,
                            videoDataOutput: oldVideoDataOutput,
                            videoDataConnection: oldVideoConnection,
                            previewConnnection: oldPreviewConnection)
        
        try sessionConfiguration(position: position, preview: preview, olds: olds)       
    }
    
    func sessionConfiguration(position: AGECameraPosition, preview: AGECameraPreview?, olds: OldItems) throws {
        let session = workingSession
        
        var camera: AVCaptureDevice
        
        // AVCaptureDevice search camera
        if #available(iOS 10.0, *) {
            guard let tCamera = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                       for: .video,
                                                       position: position) else {
                                                        throw AGECameraError(type: .fail("no \(position.description) camera"))
            }
            camera = tCamera
        } else {
            
            let cameras = AVCaptureDevice.devices(for: .video)
            
            var tCamera: AVCaptureDevice?
            
            for item in cameras where item.position == position {
                tCamera = item
            }
            
            guard let temp = tCamera else {
                throw AGECameraError(type: .fail("no \(position.description) camera"))
            }
            
            camera = temp
            
            guard let camera = AVCaptureDevice.default(for: .video) else {
                throw AGECameraError(type: .fail("no \(position.description) camera"))
            }
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
        var videoPort: AVCaptureInput.Port
        if #available(iOS 13.0, *) {
            guard let tVideoPort = newCameraDeviceInput.ports(for: .video,
                                                             sourceDeviceType: camera.deviceType,
                                                             sourceDevicePosition: camera.position).first else {
                                                                throw AGECameraError(type: .fail("no \(position.description) camera input's video port"))
            }
            videoPort = tVideoPort
        } else {
            guard let tVideoPort = newCameraDeviceInput.ports.first else {
                throw AGECameraError(type: .fail("no \(position.description) camera input's video port"))
            }
            videoPort = tVideoPort
        }
                
        let newDataConnection = AVCaptureConnection(inputPorts: [videoPort], output: newVideoDataOutput)
        guard session.noumenon.canAddConnection(newDataConnection) else {
            throw AGECameraError(type: .fail("no connection to the \(position.description) camera video data output"))
        }
        session.noumenon.addConnection(newDataConnection)
        newDataConnection.videoOrientation = .portrait
        
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
        default:
            fatalError()
        }
    }
}

extension AGESingleCamera: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        delegate?.camera(self,
                         position: position,
                         didOutput: sampleBuffer)
    }
}
