//
//  ViewController.swift
//  AGECamera
//
//  Created by CavanSu on 2019/12/12.
//  Copyright © 2019 CavanSu. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet weak var backPreview: AGECameraPreview!
    @IBOutlet weak var frontPreview: AGECameraPreview!
    @IBOutlet weak var multiBackPreview: AGECameraPreview!
    @IBOutlet weak var multiFrontPreview: AGECameraPreview!
    
    private var camera: AGECamera?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        do {
            camera = try AGECamera(position: .front)
            camera?.backPreview = backPreview
            camera?.frontPreview = frontPreview
            try camera?.start(work: .capture)
            
            
        } catch let error as AGECameraError {
            print("\(error.localizedDescription)")
        } catch {
            print("\(error.localizedDescription)")
        }
    }
    
    @IBAction func doSegChanged(_ sender: UISegmentedControl) {
        guard let title = sender.titleForSegment(at: sender.selectedSegmentIndex) else {
            return
        }
        
        do {
            print("select: \(title)")
            switch title {
            case "Front":
                camera?.backPreview = backPreview
                camera?.frontPreview = frontPreview
                try camera?.switchPosition(.front)
            case "Back":
                camera?.backPreview = backPreview
                camera?.frontPreview = frontPreview
                try camera?.switchPosition(.back)
            case "Multi":
                camera?.backPreview = multiBackPreview
                camera?.frontPreview = multiFrontPreview
                try camera?.switchPosition(.multi)
            default:
                break
            }
        } catch let error as AGECameraError {
            print("Error: \(error.localizedDescription)")
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
}

