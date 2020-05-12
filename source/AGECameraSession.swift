//
//  AGECameraSession.swift
//  AGECamera
//
//  Created by CavanSu on 2019/12/17.
//  Copyright © 2019 Agora. All rights reserved.
//

import UIKit
import AVFoundation

protocol AGECameraSession {
    var noumenon: AVCaptureSession {get set}
    
    var backCameraInput: AVCaptureDeviceInput? {get set}
    var backVideoDataOutput: AVCaptureVideoDataOutput? {get set}
    var backVideoDataConnection: AVCaptureConnection? {get set}
    var backVideoPreviewConnection: AVCaptureConnection? {get set}
    
    var frontCameraInput: AVCaptureDeviceInput? {get set}
    var frontVideoDataOutput: AVCaptureVideoDataOutput? {get set}
    var frontVideoDataConnection: AVCaptureConnection? {get set}
    var frontVideoPreviewConnection: AVCaptureConnection? {get set}
    
    func clean()
}

extension AGECameraSession {
    func clean() {
        for item in noumenon.inputs {
            noumenon.removeInput(item)
        }
        
        for item in noumenon.outputs {
            noumenon.removeOutput(item)
        }
        
        if #available(iOS 13.0, *) {
            for item in noumenon.connections {
                noumenon.removeConnection(item)
            }
        } else {
            // Fallback on earlier versions
        }
    }
}

class AGECameraCaptureSingleSession: NSObject, AGECameraSession {
    var noumenon: AVCaptureSession
    
    var backCameraInput: AVCaptureDeviceInput?
    var backVideoDataOutput: AVCaptureVideoDataOutput?
    var backVideoDataConnection: AVCaptureConnection?
    var backVideoPreviewConnection: AVCaptureConnection?
       
    var frontCameraInput: AVCaptureDeviceInput?
    var frontVideoDataOutput: AVCaptureVideoDataOutput?
    var frontVideoDataConnection: AVCaptureConnection?
    var frontVideoPreviewConnection: AVCaptureConnection?
    
    override init() {
        self.noumenon = AVCaptureSession()
    }
    
    deinit {
        noumenon.beginConfiguration()
        clean()
        noumenon.commitConfiguration()
    }
}

class AGECameraCaptureMultiSession: NSObject, AGECameraSession {
    var noumenon: AVCaptureSession
    
    var backCameraInput: AVCaptureDeviceInput?
    var backVideoDataOutput: AVCaptureVideoDataOutput?
    var backVideoDataConnection: AVCaptureConnection?
    var backVideoPreviewConnection: AVCaptureConnection?
    
    var frontCameraInput: AVCaptureDeviceInput?
    var frontVideoDataOutput: AVCaptureVideoDataOutput?
    var frontVideoDataConnection: AVCaptureConnection?
    var frontVideoPreviewConnection: AVCaptureConnection?
    
    override init() {
        if #available(iOS 13.0, *) {
            self.noumenon = AVCaptureMultiCamSession()
        } else {
            fatalError()
        }
    }
    
    deinit {
        noumenon.beginConfiguration()
        clean()
        noumenon.commitConfiguration()
    }
}
