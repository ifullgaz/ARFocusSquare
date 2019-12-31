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

    var focusNode: FocusNode!
    var visualFocusNode: FocusIndicatorNode!
    var newPlane: Bool = false
    
    var displayState: FocusNode.DisplayState = .offPlane
    
    lazy var updateQueue = DispatchQueue(label: "org.cocoapods.demo.ARFocusSquare-Example")

    @IBAction func viewTapped(_ sender: Any) {
        switch displayState {
            case .billboard:
                displayState = .offPlane
            case .offPlane:
                newPlane = !newPlane
                displayState = newPlane ? .onPlane : .onNewPlane
            case .onNewPlane, .onPlane:
                displayState = .billboard
            default:
                displayState = .billboard
        }
        visualFocusNode.displayState = displayState
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
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 0.8)
        scene.rootNode.addChildNode(cameraNode)
        
        visualFocusNode = FocusArc()
        focusNode = FocusNode(content: visualFocusNode!)
        focusNode!.updateQueue = updateQueue
        scene.rootNode.addChildNode(self.focusNode!)
    }
}
