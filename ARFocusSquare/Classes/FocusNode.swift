//
//  FocusNode.swift
//  ARFocusSquare
//
//  Created by Emmanuel Merali on 15/12/2019.
//  See LICENSE for details
//

import ARKit
import IFGExtensions

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

/// Methods you can implement to respond to a change of state of the focus node
///
/// Implement this protocol to work with a focus node and adapt the UI to the
/// status of world tracking.
///
/// # Topics
/// ---
/// # Respond to state change
/// ````
/// func focusNodeChangedDisplayState(_ node: FocusNode)
/// ````
public protocol FocusNodeDelegate: class {
    /// Provide information when the world tracking state changes
    /// - parameters:
    ///     - node: the focus node
    ///
    /// Implement this methiod to respond to changes to the world tracking state
    func focusNodeChangedDisplayState(_ node: FocusNode)
}

public extension FocusNodeDelegate {
    /// - Tag: focusNodeChangedDisplay
    func focusNodeChangedDisplayState(_ node: FocusNode) {}
}

/// This protocol adopts the `FocusNodeDelegate` protocol.
/// It defines a required instance variable and provides a default method
/// to create and configure a focus node.
///
/// Adopt this protocol to work with a focus node
///
/// # Topics
/// ---
/// # Create a focus node
/// ````
/// @discardableResult
/// func setupFocusNode(ofType type: FocusNode.Type, in sceneView: ARSCNView) -> FocusNode
/// ````
public protocol FocusNodePresenter: FocusNodeDelegate {
    var focusNode: FocusNode? { get set }

    /// Default implementation of a method to create and configure a focus node
    /// - parameters:
    ///     - ofType: the focus node type (any subclass of FocusNode)
    ///     - in: the ARSCNView with which to associate the focus node
    /// - Returns:
    ///     FocusNode: A focus node associated with and displayed by the view.
    ///     The delegate of the focus node is the caller.
    ///
    /// Implement this methiod to respond to changes to the world tracking state
    @discardableResult
    func setupFocusNode(ofType type: FocusNode.Type, in sceneView: ARSCNView) -> FocusNode
}

public extension FocusNodePresenter {
    @discardableResult
    func setupFocusNode(ofType type: FocusNode.Type, in sceneView: ARSCNView) -> FocusNode {
        focusNode = type.init()
        focusNode!.sceneView = sceneView
        focusNode!.delegate = self
        sceneView.scene.rootNode.addChildNode(focusNode!)
        return focusNode!
    }
}

/// - Tag: FocusNode
/// An `SCNNode` which is used to provide uses with visual cues about the status of ARKit world tracking.
///
/// # Topics
/// ---
/// # Create a focus node
/// ````
/// init()
/// ````
/// Creates a FocusNode object
/// ````
/// init?(coder aDecoder: NSCoder)
/// ````
/// Creates a FocusNode object from an archive
///
/// ---
/// # Manage the visual apprearence of the node
/// ````
/// func initGeometry()
/// ````
/// Override in subclasses. Creates the visual geometry of the node.
/// ````
/// func set(hidden: Bool, animated: Bool)
/// ````
/// Show or hide the node with or without animation``
///````
/// func hide()
/// ````
/// Hide the focus node. Can be overriden in subclasses.
/// ````
/// func unhide()
/// ````
/// Show the focus node. Can be overriden in subclasses.
/// ````
/// func displayOnTop(_ isOnTop: Bool)
/// ````
/// Ensure that the focus node is displayed on top of all other geometry. Can be overriden in subclasses.
///
/// ---
/// # Responding to world mapping state change
/// ````
/// func displayStateChanged(_ state: FocusNode.DisplayState, newPlane: Bool = false)
/// ````
/// Override in subclasses to respond to changes in world mapping state change
/// ````
/// func updateFocusNode(from point: CGPoint? = nil)
/// ````
/// Called by the session delegate to update the focus node with each new frame
open class FocusNode: SCNNode {

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

    open class var animationDuration: TimeInterval { 0.35 }
    
    @IBOutlet
	public weak var sceneView: ARSCNView?

    @IBOutlet
    public weak var delegate: AnyObject?

    public var updateQueue: DispatchQueue?

    /// The primary node that controls the position of other `FocusSquare` nodes.
    public let positioningNode = SCNNode()

    override open var isHidden: Bool {
        didSet {
            guard isHidden != oldValue, !isChangingVisibility else { return }
            switch isHidden {
                case true:
                    hide(animated: false)
                default:
                    unhide(animated: false)
            }
        }
    }

	// MARK: - Properties
    /// Indicates if the square is currently changing its orientation when the camera is pointing downwards.
    private var isChangingVisibility: Bool = false
    
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
    
    private(set) public var displayState: DisplayState = .initializing {
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

    // MARK: - Private methods
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
        self.setPosition(with: raycastResult, camera)
        displayState = .onPlane(newPlane: !anchorsOfVisitedPlanes.contains(planeAnchor))
        anchorsOfVisitedPlanes.insert(planeAnchor)
	}

    private func setPosition(with raycastResult: ARRaycastResult, _ camera: ARCamera?) {
        let position = raycastResult.worldTransform.translation
        recentFocusNodePositions.append(position)
        updateTransform(for: raycastResult, camera: camera)
    }

	// MARK: - Positioning and orientation
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

    /// Hides the focus square.
    open func hide(animated: Bool) {
        let duration = animated ? type(of: self).animationDuration : 0.0
        guard action(forKey: "hide") == nil else { return }
        self.isChangingVisibility = true
        runAction(.fadeOut(duration: duration), forKey: "hide") {
            self.displayOnTop(false)
            self.isHidden = true
            self.isChangingVisibility = false
        }
    }

    /// Unhides the focus square.
    open func unhide(animated: Bool) {
        let duration = animated ? type(of: self).animationDuration : 0.0
        guard action(forKey: "unhide") == nil else { return }
        self.isChangingVisibility = true
        displayOnTop(true)
        self.isHidden = false
        self.opacity = 0.0
        runAction(.fadeIn(duration: duration), forKey: "unhide") {
           self.isChangingVisibility = false
       }
    }

    // MARK: - Public methods
    public func set(hidden: Bool, animated: Bool) {
        guard hidden != isHidden, !isChangingVisibility else {
            return
        }
        switch hidden {
            case true:
                hide(animated: animated)
            default:
                unhide(animated: animated)
        }
    }

    /// Update the state of the FocusNode depending on the detection of planes.
    ///
    /// This method shoould be called periodacally, typically from `renderer:updateAtTime:`
    ///
    /// - Parameters:
    ///     - point: coordinates of the point on the screen at which to estimate the planes
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
    
    /// Sets the rendering order of the `positioningNode` to show on top or under other scene content.
    open func displayOnTop(_ isOnTop: Bool) {
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

    // MARK: Appearance
    open func displayStateChanged(_ state: FocusNode.DisplayState, newPlane: Bool = false) {
        if let delegate = delegate as? FocusNodeDelegate {
            if (!Thread.isMainThread) {
                DispatchQueue.main.async {
                    delegate.focusNodeChangedDisplayState(self)
                }
            }
            else {
                delegate.focusNodeChangedDisplayState(self)
            }
        }
        displayOnTop(true)
    }

    // MARK: - Initialization
    open func initGeometry() {
        self.opacity = 1.0
        addChildNode(self.positioningNode)
        // Start the focus square as a billboard.
        self.displayAsBillboard()
        // Always render focus square on top of other content.
        self.displayOnTop(true)
    }
    
    required public override init() {
        super.init()
        initGeometry()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initGeometry()
    }
}
