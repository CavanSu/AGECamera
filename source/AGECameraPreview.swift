//
//  AGECameraPreview.swift
//  AGECamera
//
//  Created by CavanSu on 2019/12/16.
//  Copyright © 2019 Agora. All rights reserved.
//

import UIKit
import AVFoundation

class AGECameraPreview: UIView {
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("Expected `AVCaptureVideoPreviewLayer` type for layer. Check AGECameraPreview.layerClass implementation.")
        }
        
        layer.videoGravity = .resizeAspect
        return layer
    }
    
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    override func layoutSublayers(of layer: CALayer) {
        defer {
            super.layoutSublayers(of: layer)
        }
        
        var interfaceOrientation: UIInterfaceOrientation
        
        if #available(iOS 13.0, *) {
            guard let orientation = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation else {
                return
            }
            interfaceOrientation = orientation
        } else {
            interfaceOrientation = UIApplication.shared.statusBarOrientation
        }
        
        guard let orientation = interfaceOrientationToVideoOrientation(orientation: interfaceOrientation) else {
            return
        }
        
        self.videoPreviewLayer.connection?.videoOrientation = orientation
    }
    
    func interfaceOrientationToVideoOrientation(orientation: UIInterfaceOrientation) -> AVCaptureVideoOrientation? {
        switch (orientation) {
        case .portrait:
            return .portrait;
        case .portraitUpsideDown:
            return .portraitUpsideDown;
        case .landscapeLeft:
            return .landscapeLeft;
        case .landscapeRight:
            return .landscapeRight;
        default:
            return nil
        }
    }
}
