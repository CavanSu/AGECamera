//
//  AGECameraProtocol.swift
//  AGECamera
//
//  Created by CavanSu on 2019/12/19.
//  Copyright © 2019 Agora. All rights reserved.
//

import UIKit
import AVFoundation

typealias AGECameraEXCompletion = (() throws -> Void)?

typealias AGECameraPosition = AVCaptureDevice.Position

extension AGECameraPosition {
    var description: String {
        switch self {
        case .front:        return "front"
        case .back:         return "back"
        case .unspecified:  return "unspecified"
        @unknown default:   fatalError()
        }
    }
    
    var toggle: AGECameraPosition {
        switch self {
        case .front: return .back
        case .back:  return .front
        default:     fatalError()
        }
    }
}

protocol AGECameraProtocol {
    func checkIsSimulator() throws
    func checkCameraPermision(granted: AGECameraEXCompletion) throws
}

extension AGECameraProtocol {
    func checkIsSimulator() throws {
        #if targetEnvironment(simulator)
        throw AGECameraError(type: .fail("please run on physical device"))
        #endif
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

protocol AGEMultiCameraProtocol: AGECameraProtocol {
    @discardableResult func checkSystemVersionSupportMultiStream() throws -> Bool
}

extension AGEMultiCameraProtocol {
    @discardableResult func checkSystemVersionSupportMultiStream() throws -> Bool {
        if #available(iOS 13.0, *) {
            if !ProcessInfo().isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 13, minorVersion: 0, patchVersion: 0)),
                !AVCaptureMultiCamSession.isMultiCamSupported {
                throw AGECameraError(type: .fail("multi camera at least iOS 13 and device iphone xs or later"))
            }
            return true
        } else {
            return false
        }
    }
}
