//
//  ViewController.swift
//  ARFocusFrame
//
//  Created by Emmanuel Merali on 12/15/2019.
//  Copyright (c) 2019 Emmanuel Merali. All rights reserved.
//

import ARKit
import ARFocusSquare

class FocusSquareViewController: UIViewController, ARSCNViewDelegate, FocusNodePresenter {

    var sceneView = ARSCNView()

    var focusNode: FocusNode?

    @IBAction func showFocusNode(_ sender: Any) {
        focusNode?.isHidden = false
    }
    
    @IBAction func hideFocusNode(_ sender: Any) {
        focusNode?.isHidden = true
    }

    @IBAction func showFocusNodeAnimated(_ sender: Any) {
        focusNode?.set(hidden: false, animated: true)
    }
    
    @IBAction func hideFocusNodeAnimated(_ sender: Any) {
        focusNode?.set(hidden: true, animated: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.sceneView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        sceneView.frame = self.view.bounds
        self.view.addSubview(sceneView)
        self.view.sendSubviewToBack(sceneView)

        sceneView.delegate = self
        sceneView.showsStatistics = true

        setupFocusNode(ofType: FocusSquare.self, in: sceneView)
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

    func focusNodeChangedDisplayState(_ node: FocusNode) {
        print("Node: ")
        print(node)
        print(" changed state to: ")
        print("\(String(describing: focusNode?.displayState))")
    }
}

