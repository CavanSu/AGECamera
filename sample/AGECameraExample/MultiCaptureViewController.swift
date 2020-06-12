//
//  MultiCameraViewController.swift
//  AGECamera
//
//  Created by CavanSu on 2019/12/19.
//  Copyright © 2019 CavanSu. All rights reserved.
//

import UIKit
import AVFoundation
import AGECamera

class MultiCaptureViewController: UIViewController {
    @IBOutlet weak var frontPreview: AGECameraPreview!
    @IBOutlet weak var backPreview: AGECameraPreview!
    
    private var camera: AGEMultiCamera?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        do {
            camera = try AGEMultiCamera()
            camera?.backPreview = backPreview
            camera?.frontPreview = frontPreview
            camera?.delegate = self
            try camera?.start(work: .capture)
        } catch let error as AGECameraError {
            print("\(error.localizedDescription)")
        } catch {
            print("\(error.localizedDescription)")
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        camera?.stopWork()
    }
}

extension MultiCaptureViewController: AGEMultiCameraDelegate {
    func multiCamera(_ camera: AGEMultiCamera, position: Position, didOutput sampleBuffer: CMSampleBuffer) {
        guard let pixelbuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        let width = CVPixelBufferGetWidth(pixelbuffer)
        let height = CVPixelBufferGetHeight(pixelbuffer)
        
        print("position: \(position.description), resolution: \(width) x \(height)")
    }
}
