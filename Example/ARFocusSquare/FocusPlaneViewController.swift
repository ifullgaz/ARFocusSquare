//
//  ViewController.swift
//  ARFocusFrame
//
//  Created by Emmanuel Merali on 12/15/2019.
//  Copyright (c) 2019 Emmanuel Merali. All rights reserved.
//

import ARKit
import ARFocusSquare

class FocusPlaneViewController: UIViewController, ARSCNViewDelegate, FocusNodeDelegate {
    
    var sceneView = ARSCNView()

    var focusNode: FocusNode?

    override func viewDidLoad() {
        super.viewDidLoad()

        sceneView.frame = self.view.bounds
        self.view.addSubview(sceneView)
        self.sceneView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        sceneView.delegate = self
        sceneView.showsStatistics = true

        focusNode = setupFocusNode(ofType: FocusPlane.self, in: sceneView)
        sceneView.scene.rootNode.addChildNode(focusNode!)
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
        focusNode!.updateFocusNode()
    }
    
    func focusNode(_ node: FocusNode, changedDisplayState state: FocusNode.DisplayState) {
        print("Node: ")
        print(node)
        print(" changed state to: ")
        print("\(state)")
    }
}

