//
//  FocusPlane.swift
//  ARFocusSquare
//
//  Created by Emmanuel Merali on 15/12/2019.
//  See LICENSE for details
//

import ARKit
import QuartzCore

/// A simple example subclass of FocusNode which shows whether the plane is
/// tracking on a known surface or estimating.
open class FocusPlane: FocusNode {

    /// Original size of the focus square in meters.
    static let size: Float = 0.17

    /// Thickness of the focus square lines in meters.
    static let thickness: Float = 0.018

	/// Color of the focus square fill when estimating position.
	static let offColor = #colorLiteral(red: 0.7450980544, green: 0.1568627506, blue: 0.07450980693, alpha: 1)

    /// Color of the focus square fill when at known position.
	static let onColor = #colorLiteral(red: 0.3411764801, green: 0.6235294342, blue: 0.1686274558, alpha: 1)

    private lazy var fillPlane: SCNNode = {
        let plane = SCNPlane(width: 1.0, height: 1.0)
        let node = SCNNode(geometry: plane)
        node.name = "fillPlane"
        node.opacity = 0.5

        let material = plane.firstMaterial!
        material.diffuse.contents = FocusPlane.offColor
        material.isDoubleSided = true
        material.ambient.contents = UIColor.black
        material.lightingModel = .constant
        material.emission.contents = FocusPlane.offColor

        return node
    }()

    // MARK: Appearance
    open override func displayStateChanged(_ state: FocusNode.DisplayState, newPlane: Bool = false) {
        super.displayStateChanged(state, newPlane: newPlane)
        switch state {
            case .initializing, .billboard, .offPlane:
                self.fillPlane.geometry?.firstMaterial?.diffuse.contents = FocusPlane.offColor
                self.fillPlane.geometry?.firstMaterial?.emission.contents = FocusPlane.offColor
            case .onPlane:
                self.fillPlane.geometry?.firstMaterial?.diffuse.contents = FocusPlane.onColor
                self.fillPlane.geometry?.firstMaterial?.emission.contents = FocusPlane.onColor
        }
    }

    // MARK: - Initialization
    open override func initGeometry() {
        super.initGeometry()
        self.addChildNode(fillPlane)
        displaySize = FocusPlane.size
    }
}
