//
//  ViewController.swift
//  ARFocusFrame
//
//  Created by Emmanuel Merali on 12/15/2019.
//  Copyright (c) 2019 Emmanuel Merali. All rights reserved.
//

import ARKit
import ARFocusSquare

class FocusSquareViewController: UIViewController, ARSCNViewDelegate, FocusNodeDelegate {

    var sceneView = ARSCNView()

    let focusNode = FocusSquare()

    override func viewDidLoad() {
        super.viewDidLoad()

        sceneView.frame = self.view.bounds
        self.view.addSubview(sceneView)
        self.sceneView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        sceneView.delegate = self
        sceneView.showsStatistics = true

        self.focusNode.sceneView = sceneView
        self.focusNode.delegate = self
        sceneView.scene.rootNode.addChildNode(focusNode)
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
        self.focusNode.updateFocusNode()
    }

    func focusNode(_ node: FocusNode, changedDisplayState state: FocusNode.DisplayState) {
        print("Node: ")
        print(node)
        print(" changed state to: ")
        print("\(state)")
    }
}

