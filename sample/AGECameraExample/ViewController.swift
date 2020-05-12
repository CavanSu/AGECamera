//
//  ViewController.swift
//  AGECamera
//
//  Created by CavanSu on 2019/12/12.
//  Copyright © 2019 CavanSu. All rights reserved.
//

import UIKit
import AGECamera

class ViewController: UIViewController {
    
    @IBOutlet weak var backPreview: AGECameraPreview!
    @IBOutlet weak var frontPreview: AGECameraPreview!
    @IBOutlet weak var multiBackPreview: AGECameraPreview!
    @IBOutlet weak var multiFrontPreview: AGECameraPreview!
    
    private var single: AGESingleCamera?
    private var multi: AGEMultiCamera?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        do {
//            single = try AGESingleCamera(position: .front)
//            single?.preview = frontPreview
//            try single?.start(work: .capture)
            
            multi = try AGEMultiCamera(backPreview: multiBackPreview, frontPreview: multiFrontPreview)
            multi?.backPreview = multiBackPreview
                       multi?.frontPreview = multiFrontPreview
            try multi?.start(work: .capture)
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
                multi?.stopWork()
                single?.preview = frontPreview
                try single?.switchPosition(.front)
                try single?.start(work: .capture)
            case "Back":
                multi?.stopWork()
                single?.preview = backPreview
                try single?.switchPosition(.back)
                try single?.start(work: .capture)
            case "Multi":
                single?.set(resolution: .hd1920x1080)
                single?.stopWork()
                try multi?.start(work: .capture)
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

