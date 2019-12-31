//
//  FocusNode.swift
//  ARFocusSquare
//
//  Created by Emmanuel Merali on 15/12/2019.
//  See LICENSE for details
//

import ARKit
import IFGExtensions

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
    ///     - state: the new display state
    ///
    /// Implement this methiod to respond to changes to the world tracking state
    func focusNodeChangedDisplayState(_ node: FocusNode, state: FocusNode.DisplayState)
}

public extension FocusNodeDelegate {
    /// Provide information when the world tracking state changes
    /// - parameters:
    ///     - node: the focus node
    ///     - state: the new display state
    ///
    /// Implement this methiod to respond to changes to the world tracking state
//    func focusNodeChangedDisplayState(_ node: FocusNode, state: FocusNode.DisplayState) {}
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
    func setupFocusNode(ofType type: FocusIndicatorNode.Type, in sceneView: ARSCNView) -> FocusNode {
        let visualFocusNode = type.init()
        focusNode = FocusNode(content: visualFocusNode)
        focusNode!.sceneView = sceneView
        focusNode!.delegate = self
        sceneView.scene.rootNode.addChildNode(focusNode!)
        return focusNode!
    }
}

// MARK: - FocusIndicatorNode protocol
@objc
public protocol FocusIndicatorNode where Self: SCNNode {
    /// The initial size in meters
    /// - returns
    ///     a Float representing the initial apprent size
    static var size: Float { get }
    
    /// It is set by the focus node to allow the indicator to update its appearence
    ///
    /// - parameters:
    ///     - state: the display state
    ///
    /// Implement didSet{} to respond to changes to the world tracking state
    /// For instance:
    /// ````
    /// var displayState: FocusNode.DisplayState = .initializing {
    ///     didSet {
    ///         switch state {
    ///         case .initializing, .billboard:
    ///                 showAsBillboard()
    ///             case .offPlane:
    ///                 showAsOffPlane()
    ///             case .onNewPlane:
    ///                 showAsOnNewPlane()
    ///             case .onPlane:
    ///                 showAsOnPlane()
    ///         }
    ///     }
    /// }
    ///````
    var displayState: FocusNode.DisplayState { get set }

    /// Setup the geometry of the focus indicator.
    ///
    /// It is called by the focus node to tell the focus indicator to create its visual appearence.
    /// For instance, adding sub nodes or loading from a URL
    ///
    ///  - attention
    /// `setupGeometry` should not be called directly.
    ///
    func setupGeometry(updateQueue: DispatchQueue)
}

// MARK: - FocusNode
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
/// Show or hide the node with or without animation
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
    @objc
    public enum DisplayState: Int, CustomStringConvertible {
        case initializing
        case billboard
        case offPlane
        case onNewPlane
        case onPlane

        public var description: String {
            switch self {
                case .initializing: return "Initializing"
                case .billboard: return "Billboard"
                case .offPlane: return "Off plane"
                case .onNewPlane: return "On new plane"
                case .onPlane: return "On plane"
            }
        }
    }

    private enum DetectionState: Equatable {
        case initializing
        case detecting(raycastResult: ARRaycastResult, camera: ARCamera?)
    }

    // MARK: - Variables needed for operation
    @IBOutlet
	public weak var sceneView: ARSCNView?

    @IBOutlet
    /// The node that will conatin the geometry of the focus node
    public var contentNode: FocusIndicatorNode? {
        didSet {
            guard contentNode !== oldValue, self.isInitialized else { return }
            oldValue?.removeFromParentNode()
            if contentNode != nil {
                self.intializeContentNode()
            }
        }
    }
    
    @IBOutlet
    public weak var delegate: AnyObject?

    public var animationDuration: TimeInterval = 0.35
    
    /// The queue on which all operations are done
    public var updateQueue: DispatchQueue = DispatchQueue.global(qos: .userInitiated)

    public var displayScale: Float = 1.0 {
        didSet {
            self.simdScale = SIMD3<Float>(repeating: displayScale)
        }
    }
    
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

	// MARK: - Private Properties
    /// Set to true when initialisation completed
    private var isInitialized: Bool = false
    
    /// Indicates if the square is currently changing its orientation when the camera is pointing downwards.
    private var isChangingVisibility: Bool = false
    
    /// Indicates if the square is currently changing its orientation when the camera is pointing downwards.
    private var isChangingOrientation: Bool = false
    
    /// Indicates if the camera is currently pointing towards the floor.
    private var isPointingDownwards: Bool = true
    
	/// The focus square's most recent positions.
	private var recentPositions: [SIMD3<Float>] = []

	/// Previously visited plane anchors.
	private var anchorsOfVisitedPlanes: Set<ARAnchor> = []

    /// A counter for managing orientation updates of the focus square.
    private var counterToNextOrientationUpdate: Int = 0
    
    private var detectionState: DetectionState = .initializing {
        didSet {
            guard isInitialized else { return }
            switch detectionState {
                case .initializing:
                    displayAsBillboard()
                case let .detecting(raycastResult, camera):
                    guard detectionState != oldValue else { return }
                    if let planeAnchor = raycastResult.anchor as? ARPlaneAnchor {
                        displayAsOnPlane(for: raycastResult, planeAnchor: planeAnchor, camera: camera)
                    } else {
                        displayAsOffPlane(for: raycastResult, camera: camera)
                    }
            }
        }
    }

    private(set) public var displayState: DisplayState = .initializing {
        didSet {
            displayStateChanged(displayState, oldValue)
        }
    }

    // MARK: - Private methods
    private func intializeContentNode() {
        if let contentNode = contentNode {
            contentNode.setupGeometry(updateQueue: self.updateQueue)
            contentNode.simdScale = SIMD3<Float>(repeating: type(of: contentNode).size)
            self.addChildNode(contentNode)
        }
    }
    
    private func initialize() {
        // Dispatching on the main queue to have time
        // to setup things like updateQueue...
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.updateQueue.async { [unowned self] in
                self.intializeContentNode()
                self.isInitialized = true
                self.displayAsBillboard()
                // Always render focus square on top of other content.
                self.displayOnTop(true)
            }
        }
    }
    
	/// Displays the focus square parallel to the camera plane.
	private func displayAsBillboard() {
		simdTransform = matrix_identity_float4x4
        self.simdScale = SIMD3<Float>(repeating: 1.0)
        // Rotate the node 0° to face the camera
        contentNode?.eulerAngles.x = 0.0
        self.displayScale = 1.0
		simdPosition = SIMD3<Float>(0, 0, -0.8)
        recentPositions.removeAll()
        displayState = .billboard
	}

	/// Called when a surface has been detected.
	private func displayAsOffPlane(for raycastResult: ARRaycastResult, camera: ARCamera?) {
        // Rotate the node -90° to be perpendicular to the plan
        contentNode?.eulerAngles.x = -.pi / 2
        self.updateTransform(with: raycastResult, camera)
        displayState = .offPlane
	}

	/// Called when a plane has been detected.
	private func displayAsOnPlane(for raycastResult: ARRaycastResult, planeAnchor: ARPlaneAnchor, camera: ARCamera?) {
        // Rotate the node -90° to be perpendicular to the plan
        contentNode?.eulerAngles.x = -.pi / 2
        self.updateTransform(with: raycastResult, camera)
        displayState = anchorsOfVisitedPlanes.contains(planeAnchor) ? .onPlane : .onNewPlane
        anchorsOfVisitedPlanes.insert(planeAnchor)
	}

    private func updateTransform(with raycastResult: ARRaycastResult, _ camera: ARCamera?) {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.0
        // Update the world position
        updatePosition(with: raycastResult)
        // Update the visual scale
        updateDistanceBasedScale(camera: camera)
        // Update the orientation
        updateOrientation(for: raycastResult, camera: camera)
        SCNTransaction.commit()
    }

    private func updatePosition(with raycastResult: ARRaycastResult) {
        let position = raycastResult.worldTransform.translation
        recentPositions.append(position)
        // Average using several most recent positions.
        recentPositions = Array(recentPositions.suffix(10))
        // Move to average of recent positions to avoid jitter.
        let average = recentPositions.reduce(
            SIMD3<Float>(repeating: 0), { $0 + $1 }) / Float(recentPositions.count)
        self.simdPosition = average
    }

    /**
    Reduce visual size change with distance by scaling up when close and down when far away.
    These adjustments result in a scale of 1.0x for a distance of 0.7 m or less
    (estimated distance when looking at a table), and a scale of 1.2x
    for a distance 1.5 m distance (estimated distance when looking at the floor).
    */
    private func updateDistanceBasedScale(camera: ARCamera?) {
        var newDisplayScale: Float = 1.0
        if let camera = camera {
            let distanceFromCamera = simd_length(simdWorldPosition - camera.transform.translation)
            if distanceFromCamera < 0.7 {
                newDisplayScale = distanceFromCamera / 0.7
            } else {
                newDisplayScale = 0.25 * distanceFromCamera + 0.825
            }
        }
        self.displayScale = newDisplayScale
    }

	// MARK: - Positioning and orientation
	/// Update the transform of the focus square to be aligned with the camera.
    private func updateOrientation(for raycastResult: ARRaycastResult, camera: ARCamera?) {

		// Correct y rotation of camera square.
		guard let camera = camera else { return }
		let tilt = abs(camera.eulerAngles.x)
        // ~67.5 degrees, looking down or up
        let threshold: Float = .pi / 2 * 0.75
        
        if tilt > threshold {
            if !isChangingOrientation {
                let yaw = atan2f(camera.transform.columns.0.x, camera.transform.columns.1.x)

                isChangingOrientation = true
                let simdOrientation = simd_quatf(angle: yaw, axis: [0, 1, 0])
                SCNTransaction.begin()
                SCNTransaction.completionBlock = { [weak self] in
                    self?.isChangingOrientation = false
                    self?.isPointingDownwards = true
                }
                SCNTransaction.animationDuration = isPointingDownwards ? 0.0 : 0.5
                self.simdOrientation = simdOrientation
                SCNTransaction.commit()
            }
        } else {
            // Update orientation only twice per second to avoid jitter.
            if counterToNextOrientationUpdate == 15 || isPointingDownwards {
                counterToNextOrientationUpdate = 0
                isPointingDownwards = false
                
                let simdOrientation = raycastResult.worldTransform.orientation
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.5
                self.simdOrientation = simdOrientation
                SCNTransaction.commit()
            }
            
            counterToNextOrientationUpdate += 1
        }
	}

    // MARK: Appearance
    private func displayStateChanged(_ state: FocusNode.DisplayState, _ previousState: FocusNode.DisplayState) {
        contentNode?.displayState = state
        guard state != previousState else { return }
        if let delegate = delegate as? FocusNodeDelegate {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                delegate.focusNodeChangedDisplayState(self, state: state)
            }
        }
        displayOnTop(true)
    }

    /// Sets the rendering order of the `node` to show on top or under other scene content.
    private func displayOnTop(_ isOnTop: Bool) {
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

        updateRenderOrder(for: self)
    }

    /// Hides the focus node.
    private func hide(animated: Bool) {
        let duration = animated ? self.animationDuration : 0.0
        guard action(forKey: "hide") == nil else { return }
        removeAction(forKey: "unhide")
        runAction(.fadeOut(duration: duration), forKey: "hide") {
            self.displayOnTop(false)
            self.isHidden = true
        }
    }

    /// Unhides the focus node.
    private func unhide(animated: Bool) {
        let duration = animated ? self.animationDuration : 0.0
        guard action(forKey: "unhide") == nil else { return }
        removeAction(forKey: "hide")
        runAction(.fadeIn(duration: duration), forKey: "unhide")
        displayOnTop(true)
        self.isHidden = false
        self.opacity = 0.0
    }

    // MARK: - Public methods
    public func set(hidden: Bool, animated: Bool) {
        guard hidden != isHidden, !isChangingVisibility else { return }
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
        guard isInitialized else { return }
        guard let view = self.sceneView else {
            self.detectionState = .initializing
            return
        }
        if point == nil, !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.updateFocusNode()
            }
            return
        }
        let screenPoint = point ?? view.screenCenter
        updateQueue.async { [unowned self] in
            if let camera = view.session.currentFrame?.camera,
               case .normal = camera.trackingState,
               let result = view.getEstimatedPlanes(from: screenPoint)?.first {
                self.detectionState = .detecting(raycastResult: result, camera: camera)
                guard self.parent !== view.scene.rootNode else { return }
                view.scene.rootNode.addChildNode(self)
            }
            else {
                self.detectionState = .initializing
                guard self.parent !== view.pointOfView else { return }
                view.pointOfView?.addChildNode(self)
            }
        }
    }
    
    required public init(content node: FocusIndicatorNode) {
        super.init()
        self.contentNode = node
        self.initialize()
    }
    
    required public override init() {
        super.init()
        self.initialize()
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
