//
//  FocusNode.swift
//  ARFocusSquare
//
//  Created by Emmanuel Merali on 15/12/2019.
//  See LICENSE for details
//

import ARKit

internal extension ARSCNView {
	/// Center of the view
	var screenCenter: CGPoint {
		let bounds = self.bounds
		return CGPoint(x: bounds.midX, y: bounds.midY)
	}

    func getEstimatedPlanes(from point: CGPoint, for alignment: ARRaycastQuery.TargetAlignment = .any) -> [ARRaycastResult]? {
        if let query = raycastQuery(from: point, allowing: .estimatedPlane, alignment: alignment) {
            return session.raycast(query)
        }
        return nil
    }
}

internal extension float4x4 {
    /**
    Treats matrix as a (right-hand column-major convention) transform matrix
    and factors out the translation component of the transform.
    */
    var translation: SIMD3<Float> {
        get {
            let translation = columns.3
            return SIMD3<Float>(translation.x, translation.y, translation.z)
        }
        set(newValue) {
            columns.3 = SIMD4<Float>(newValue.x, newValue.y, newValue.z, columns.3.w)
        }
    }

    /**
    Factors out the orientation component of the transform.
    */
    var orientation: simd_quatf {
        return simd_quaternion(self)
    }
}

public protocol FocusNodeDelegate {
    var focusNode: FocusNode? { get set }

    func setupFocusNode(ofType type: FocusNode.Type, in view: ARSCNView) -> FocusNode
    func focusNode(_ node: FocusNode, changedDisplayState state: FocusNode.DisplayState)
}

public extension FocusNodeDelegate {
    func setupFocusNode(ofType type: FocusNode.Type, in sceneView: ARSCNView) -> FocusNode {
        let focusNode: FocusNode = type.init()
        focusNode.sceneView = sceneView
        focusNode.delegate = self
        sceneView.scene.rootNode.addChildNode(focusNode)
        return focusNode
    }
    func focusNode(_ node: FocusNode, changedDisplayState state: FocusNode.DisplayState) {}
}

/**
An `SCNNode` which is used to provide uses with visual cues about the status of ARKit world tracking.
- Tag: FocusSquare
*/
open class FocusNode: SCNNode {

	weak public var sceneView: ARSCNView?

    public var updateQueue: DispatchQueue?

    public var delegate: FocusNodeDelegate?
    
	// MARK: - Types
    public enum DisplayState: Equatable {
        case initializing
        case billboard
        case offPlane
        case onPlane(newPlane: Bool)
    }

	private enum DetectionState: Equatable {
		case initializing
		case detecting(raycastResult: ARRaycastResult, camera: ARCamera?)
	}

    /// The primary node that controls the position of other `FocusSquare` nodes.
    public let positioningNode = SCNNode()

	// MARK: - Properties

    /// Indicates if the square is currently changing its orientation when the camera is pointing downwards.
    private var isChangingOrientation: Bool = false
    
    /// Indicates if the camera is currently pointing towards the floor.
    private var isPointingDownwards: Bool = true
    
	/// The focus square's most recent positions.
	private var recentFocusNodePositions: [SIMD3<Float>] = []

	/// Previously visited plane anchors.
	private var anchorsOfVisitedPlanes: Set<ARAnchor> = []

    /// A counter for managing orientation updates of the focus square.
    private var counterToNextOrientationUpdate: Int = 0
    
    private var displayState: DisplayState = .initializing {
        didSet {
            guard displayState != oldValue else { return }

            switch displayState {
                case .initializing, .billboard, .offPlane:
                    displayStateChanged(displayState)
                case let .onPlane(newPlane: newPlane):
                    displayStateChanged(displayState, newPlane: newPlane)
            }
        }
    }

    private var detectionState: DetectionState = .initializing {
        didSet {
            guard detectionState != oldValue else { return }

            switch detectionState {
                case .initializing:
                    displayAsBillboard()
                case let .detecting(raycastResult, camera):
                    if let planeAnchor = raycastResult.anchor as? ARPlaneAnchor {
                        displayAsOnPlane(for: raycastResult, planeAnchor: planeAnchor, camera: camera)
                    } else {
                        displayAsOffPlane(for: raycastResult, camera: camera)
                    }
            }
        }
    }

    // MARK: - Initialization
	required public override init() {
		super.init()

		// Always render focus square on top of other content.
		self.displayOnTop(true)
        self.opacity = 1.0
        
		addChildNode(self.positioningNode)

		// Start the focus square as a billboard.
		self.displayAsBillboard()
	}

	required public init?(coder aDecoder: NSCoder) {
		fatalError("\(#function) has not been implemented")
	}

	// MARK: Appearance

    public func displayStateChanged(_ state: FocusNode.DisplayState, newPlane: Bool = false) {
        if let delegate = delegate {
            if (!Thread.isMainThread) {
                DispatchQueue.main.async {
                    delegate.focusNode(self, changedDisplayState: state)
                }
            }
            else {
                delegate.focusNode(self, changedDisplayState: state)
            }
        }
        displayOnTop(true)
    }
    
	/// Hides the focus square.
	public func hide() {
		guard action(forKey: "hide") == nil else { return }

		displayOnTop(false)
		runAction(.fadeOut(duration: 0.5), forKey: "hide")
	}

	/// Unhides the focus square.
	public func unhide() {
		guard action(forKey: "unhide") == nil else { return }

		displayOnTop(true)
		runAction(.fadeIn(duration: 0.5), forKey: "unhide")
	}

	/// Displays the focus square parallel to the camera plane.
	private func displayAsBillboard() {
		simdTransform = matrix_identity_float4x4
		eulerAngles.x = .pi / 2
		simdPosition = SIMD3<Float>(0, 0, -0.8)
        displayState = .billboard
	}

	/// Called when a surface has been detected.
	private func displayAsOffPlane(for raycastResult: ARRaycastResult, camera: ARCamera?) {
        self.setPosition(with: raycastResult, camera)
        displayState = .offPlane
	}

	/// Called when a plane has been detected.
	private func displayAsOnPlane(for raycastResult: ARRaycastResult, planeAnchor: ARPlaneAnchor, camera: ARCamera?) {
		anchorsOfVisitedPlanes.insert(planeAnchor)
        self.setPosition(with: raycastResult, camera)
        displayState = .onPlane(newPlane: !anchorsOfVisitedPlanes.contains(planeAnchor))
	}

    private func setPosition(with raycastResult: ARRaycastResult, _ camera: ARCamera?) {
        let position = raycastResult.worldTransform.translation
        recentFocusNodePositions.append(position)
        updateTransform(for: raycastResult, camera: camera)
    }

	// MARK: Helper Methods

    // - Tag: Set3DOrientation
    private func updateOrientation(basedOn raycastResult: ARRaycastResult) {
        self.simdOrientation = raycastResult.worldTransform.orientation
    }
    
	/// Update the transform of the focus square to be aligned with the camera.
    private func updateTransform(for raycastResult: ARRaycastResult, camera: ARCamera?) {
		// Average using several most recent positions.
		recentFocusNodePositions = Array(recentFocusNodePositions.suffix(10))

		// Move to average of recent positions to avoid jitter.
		let average = recentFocusNodePositions.reduce(
			SIMD3<Float>(repeating: 0), { $0 + $1 }) / Float(recentFocusNodePositions.count)
		self.simdPosition = average
        self.simdScale = [1.0, 1.0, 1.0] * scaleBasedOnDistance(camera: camera)

		// Correct y rotation of camera square.
		guard let camera = camera else { return }
		let tilt = abs(camera.eulerAngles.x)
        let threshold: Float = .pi / 2 * 0.75
        
        if tilt > threshold {
            if !isChangingOrientation {
                let yaw = atan2f(camera.transform.columns.0.x, camera.transform.columns.1.x)
                
                isChangingOrientation = true
                SCNTransaction.begin()
                SCNTransaction.completionBlock = {
                    self.isChangingOrientation = false
                    self.isPointingDownwards = true
                }
                SCNTransaction.animationDuration = isPointingDownwards ? 0.0 : 0.5
                self.simdOrientation = simd_quatf(angle: yaw, axis: [0, 1, 0])
                SCNTransaction.commit()
            }
        } else {
            // Update orientation only twice per second to avoid jitter.
            if counterToNextOrientationUpdate == 30 || isPointingDownwards {
                counterToNextOrientationUpdate = 0
                isPointingDownwards = false
                
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.5
                updateOrientation(basedOn: raycastResult)
                SCNTransaction.commit()
            }
            
            counterToNextOrientationUpdate += 1
        }
	}

	/**
	Reduce visual size change with distance by scaling up when close and down when far away.

	These adjustments result in a scale of 1.0x for a distance of 0.7 m or less
	(estimated distance when looking at a table), and a scale of 1.2x
	for a distance 1.5 m distance (estimated distance when looking at the floor).
	*/
	private func scaleBasedOnDistance(camera: ARCamera?) -> Float {
		guard let camera = camera else { return 1.0 }

		let distanceFromCamera = simd_length(simdWorldPosition - camera.transform.translation)
		if distanceFromCamera < 0.7 {
			return distanceFromCamera / 0.7
		} else {
			return 0.25 * distanceFromCamera + 0.825
		}
	}

	/// Sets the rendering order of the `positioningNode` to show on top or under other scene content.
	public func displayOnTop(_ isOnTop: Bool) {
		// Recursivley traverses the node's children to update the rendering order depending on the `isOnTop` parameter.
		func updateRenderOrder(for node: SCNNode) {
			node.renderingOrder = isOnTop ? 2 : 0

			for material in node.geometry?.materials ?? [] {
				material.readsFromDepthBuffer = !isOnTop
			}

			for child in node.childNodes {
				updateRenderOrder(for: child)
			}
		}

		updateRenderOrder(for: self.positioningNode)
	}

    // MARK: Public methods
    /** Update the state of the FocusNode depending on the detection of planes
    - Parameters:
     - point: coordinates of the point on the screen at which to estimate the planes
    */
    public func updateFocusNode(from point: CGPoint? = nil) {
        guard let view = self.sceneView else {
            return
        }
        if point == nil, !Thread.isMainThread {
            DispatchQueue.main.async {
                self.updateFocusNode()
            }
            return
        }
        func updateNode(_ view: ARSCNView, _ point: CGPoint) {
            // Perform hit testing only when ARKit tracking is in a good state.
            if let camera = view.session.currentFrame?.camera,
               case .normal = camera.trackingState,
               let result = view.getEstimatedPlanes(from: point)?.first {
                self.detectionState = .detecting(raycastResult: result, camera: camera)
                view.scene.rootNode.addChildNode(self)
            }
            else {
                self.detectionState = .initializing
                view.pointOfView?.addChildNode(self)
            }
        }
        let screenPoint = point ?? view.screenCenter
        if (updateQueue == nil && Thread.isMainThread) {
            updateNode(view, screenPoint)
        }
        else {
            let queue = updateQueue ?? DispatchQueue.main
            queue.async {
                updateNode(view, screenPoint)
            }
        }
	}
}
