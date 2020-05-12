//
//  SingleCaptureViewController.swift
//  AGECamera
//
//  Created by CavanSu on 2019/12/19.
//  Copyright © 2019 CavanSu. All rights reserved.
//

import UIKit
import AGECamera
import AVFoundation

class SingleCaptureViewController: UIViewController {
    @IBOutlet weak var preview: AGECameraPreview!
    
    private var camera: AGESingleCamera?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        do {
            camera = try AGESingleCamera(position: .front)
            camera?.delegate = self
            camera?.preview = preview
            try camera?.start(work: .capture)
        } catch let error as AGECameraError {
            print("Error: \(error.localizedDescription)")
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // attention!! workaround!!
        // this 'set(resolution: .hd1920x1080)' makes multi session work normally
        camera?.set(resolution: .hd1920x1080)
        camera?.stopWork()
    }
    
    @IBAction func doSegChanged(_ sender: UISegmentedControl) {
        guard let title = sender.titleForSegment(at: sender.selectedSegmentIndex) else {
            return
        }
        
        print("select: \(title)")
        
        do {
            switch title {
            case "Front":
                try camera?.switchPosition(.front)
            case "Back":
                try camera?.switchPosition(.back)
            default:
                break
            }
        } catch let error as AGECameraError {
            print("Error: \(error.localizedDescription)")
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
    
    @IBAction func doResolutionSegChanged(_ sender: UISegmentedControl) {
        guard let title = sender.titleForSegment(at: sender.selectedSegmentIndex) else {
            return
        }
        
        print("title: \(title)")
        
        switch title {
        case "1920x1080":
            camera?.set(resolution: .hd1920x1080)
        case "1280x720":
            camera?.set(resolution: .hd1280x720)
        case "640x480":
            camera?.set(resolution: .vga640x480)
        default:
            break
        }
    }
}

extension SingleCaptureViewController: AGESingleCameraDelegate {
    func camera(_ camera: AGESingleCamera, position: AGECameraPosition, didOutput sampleBuffer: CMSampleBuffer) {
        guard let pixelbuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        let width = CVPixelBufferGetWidth(pixelbuffer)
        let height = CVPixelBufferGetHeight(pixelbuffer)
        
        print("position: \(position.description), resolution: \(width) x \(height)")
    }
}
