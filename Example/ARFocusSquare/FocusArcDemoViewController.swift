//
//  FocusArcViewController.swift
//  ARFocusSquare_Example
//
//  Created by Emmanuel Merali on 26/12/2019.
//  Copyright © 2019 CocoaPods. All rights reserved.
//

import ARKit
import ARFocusSquare

class FocusArcDemoViewController: UIViewController {

    @IBOutlet weak var sceneView: SCNView!

    var focusNode: FocusArc?
    
    var displayState: FocusNode.DisplayState = .offPlane
    var newPlane: Bool = false
    
    lazy var updateQueue = DispatchQueue(label: "org.cocoapods.demo.ARFocusSquare-Example")

    @IBAction func viewTapped(_ sender: Any) {
        switch displayState {
            case .offPlane:
                newPlane = !newPlane
                displayState = .onPlane(newPlane: newPlane)
                focusNode?.displayStateChanged(displayState, newPlane: newPlane)
            default:
                displayState = .offPlane
                focusNode?.displayStateChanged(displayState)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let scene = SCNScene()
        sceneView.scene = scene
        sceneView.allowsCameraControl = true
        sceneView.backgroundColor = UIColor.darkGray
        let cameraNode = SCNNode()
        let camera = SCNCamera()
        camera.zNear = 0.1
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 1)
        scene.rootNode.addChildNode(cameraNode)
        
        focusNode = FocusArc()
        focusNode?.updateQueue = updateQueue
        scene.rootNode.addChildNode(focusNode!)
    }
}
