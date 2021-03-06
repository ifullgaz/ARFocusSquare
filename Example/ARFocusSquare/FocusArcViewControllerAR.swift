//
//  ViewController.swift
//  ARFocusFrame
//
//  Created by Emmanuel Merali on 12/15/2019.
//  Copyright (c) 2019 Emmanuel Merali. All rights reserved.
//

import ARKit
import ARFocusSquare

class FocusArcViewControllerAR: UIViewController, ARSCNViewDelegate, FocusNodeDelegate {
    @IBOutlet weak var sceneView: ARSCNView!
        
    @IBOutlet var focusNode: FocusNode!
    
    /// A serial queue used to coordinate adding or removing nodes from the scene.
    lazy var updateQueue = DispatchQueue(label: "org.cocoapods.demo.ARFocusSquare-Example")

    override func viewDidLoad() {
        super.viewDidLoad()
        sceneView.showsStatistics = true
        focusNode.updateQueue = updateQueue
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        sceneView.session.run(configuration)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        focusNode.updateFocusNode()
    }

    func focusNodeChangedDisplayState(_ node: FocusNode, state: FocusNode.DisplayState) {
        // Do something
    }
}

