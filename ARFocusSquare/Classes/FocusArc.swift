//
//  FocusArc.swift
//  ARFocusSquare
//
//  Created by Emmanuel Merali on 25/12/2019.
//

import SceneKit

// MARK: - Animations and Actions

private func pulseAction() -> SCNAction {
    let pulseOutAction = SCNAction.fadeOpacity(to: 0.4, duration: 0.7)
    let pulseInAction = SCNAction.fadeOpacity(to: 1.0, duration: 0.7)
    pulseOutAction.timingMode = .easeInEaseOut
    pulseInAction.timingMode = .easeInEaseOut

    return SCNAction.repeatForever(SCNAction.sequence([pulseOutAction, pulseInAction]))
}

private func rad(_ degree: CGFloat) -> CGFloat {
    return degree * .pi / 180
}

private func makeArc(angle: CGFloat, scale: CGFloat) -> UIBezierPath {
    let radAngle: CGFloat = rad(angle)
    let path = UIBezierPath()
    path.addArc(
        withCenter: CGPoint(x: 0, y: 0),
        radius: scale,
        startAngle: 0.0,
        endAngle: radAngle,
        clockwise: true)
    return path
}

private func makeArcGeometry(arcAngle: CGFloat, scale: CGFloat, lineWidth: CGFloat, color: UIColor) -> SCNPlane {
    let arc = makeArc(angle: arcAngle, scale: scale)
    let bounds = arc.bounds
    let frame: CGRect = CGRect(
        x: -bounds.minX + sin(rad(15)) * lineWidth,
        y: -bounds.minY,
        width: bounds.width + lineWidth / 2 + sin(rad(15)) * lineWidth,
        height: bounds.height + lineWidth / 2.0)
    let layer = CAShapeLayer()
    layer.frame = frame
    layer.path = arc.cgPath
    layer.lineWidth = lineWidth
    layer.strokeColor = color.cgColor
    layer.fillColor = UIColor.clear.cgColor
    // Display as open to start with
    layer.strokeStart = FocusArc.Arc.openFactor
    layer.strokeEnd = 1 - layer.strokeStart

    let layerMaterial = SCNMaterial()
    layerMaterial.diffuse.contents = layer
    layerMaterial.emission.contents = layer
    layerMaterial.isDoubleSided = true
    let planeGeometry = SCNPlane(
        width: frame.width / scale / 2,
        height: frame.height / scale / 2)
    planeGeometry.materials = [layerMaterial]
    return planeGeometry
}

private extension FocusArc {
    /*
    The focus pie consists of 3 arcs, which can be individually animated.
    */
    enum Quadrant {
        case left
        case bottom
        case right
    }

    class Arc: SCNNode {

        static let arcAngle: CGFloat = 112.0

        static let scale: CGFloat = 80

        static let lineWidth: CGFloat = 4.0

        static let openAngle: CGFloat = 15.0

        static let openSpringAngle: CGFloat = 24.0

        static var geometry: SCNPlane?

        static let openFactor: CGFloat = Arc.openAngle / Arc.arcAngle

        static let openSpringFactor: CGFloat = Arc.openSpringAngle / Arc.arcAngle

        var quadrant: Quadrant = .bottom
        
        private var layer: CAShapeLayer!

        private func animate(from: CGFloat, to: CGFloat, duration: TimeInterval, completionHandler block: (() -> Void)? = nil) {
            let toRatio = to / Arc.arcAngle - from
            let action = SCNAction.customAction(duration: duration) { (node, elapsed) in
                let progress: CGFloat = duration == 0.0 ? 1.0 : elapsed / CGFloat(duration)
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                self.layer.strokeStart = from + toRatio * progress
                self.layer.strokeEnd = 1 - self.layer.strokeStart
                CATransaction.commit()
            }
            action.timingMode = .easeInEaseOut
            self.runAction(action) {
                block?()
            }
        }
        
        func open(to: CGFloat, duration: TimeInterval, completionHandler block: (() -> Void)? = nil) {
            let from: CGFloat = layer.strokeStart
            self.animate(from: from, to: to, duration: duration) {
                block?()
            }
        }

        func close(duration: TimeInterval, completionHandler block: (() -> Void)? = nil) {
            let from: CGFloat = layer.strokeStart
            self.animate(from: from, to: 0.0, duration: duration) {
                block?()
            }
        }

        init(name: String, quadrant: Quadrant) {
            super.init()
            self.quadrant = quadrant
            if Arc.geometry == nil {
                let geometry = makeArcGeometry(
                    arcAngle: Arc.arcAngle,
                    scale: Arc.scale,
                    lineWidth: Arc.lineWidth,
                    color: FocusArc.primaryColor)
                Arc.geometry = geometry
            }
            let geometry = Arc.geometry!
            self.layer = geometry.materials.first?.diffuse.contents as? CAShapeLayer
            let size = CGSize(width: geometry.width, height: geometry.height)
            let pivot = SCNMatrix4MakeTranslation(
                -Float(size.height - size.width / 2),
                -Float(size.height / 2.0),
                0)
            var zAngle: CGFloat = -Arc.arcAngle / 2.0 - 90
            switch quadrant {
            case .left:
                zAngle -= Arc.arcAngle
            case .right:
                zAngle += Arc.arcAngle
            default:
                break
            }
            self.geometry = geometry
            self.pivot = pivot
            self.eulerAngles.z = Float(rad(zAngle))
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}
/// This example class is taken almost entirely from Apple's own examples.
/// I have simply moved some things around to keep only what's necessary
///
/// An `SCNNode` which is used to provide uses with visual cues about the status of ARKit world tracking.
/// - Tag: FocusArc
open class FocusArc: SCNNode, FocusIndicatorNode {

    // MARK: - Configuration Properties

    /// Original size of the focus square in meters.
    public static let size: Float = 0.17

    /// Radius of the base of the cone in respect to the radius of the focus node
    static let coneBottomRadiusRatio: Float = 0.1

    /// Height of the cone in respect to the diamater of the focus node
    static let coneHeightRatio: Float = 0.2

    /// Scale factor for the focus square when it is closed, w.r.t. the original size.
    static let onPlaneScale: Float = 0.97

    /// Duration of the open/close animation
    static var primaryColor = #colorLiteral(red: 0.1764705926, green: 0.4980392158, blue: 0.7568627596, alpha: 1)

    /// Color of the focus square fill.
    static var fillColor = #colorLiteral(red: 0.2392156869, green: 0.6745098233, blue: 0.9686274529, alpha: 1)

    static var animationDuration: TimeInterval = 0.7
    
    /// The queue on which all operations are done
    private var updateQueue: DispatchQueue!
    
    /// Indicates whether the segments of the focus square are disconnected.
    private var isOpen = true

    /// Indicates if the square is currently being animated for opening or closing.
    private var isAnimating = false
    
    /// List of the segments in the focus square.
    private var arcs: [FocusArc.Arc] = []
    
    private lazy var cone: SCNNode = {
        let coneMaterial = SCNMaterial()
        coneMaterial.diffuse.contents = FocusArc.primaryColor
        let coneGeometry = SCNCone(
            topRadius: 0.0,
            bottomRadius: CGFloat(FocusArc.coneBottomRadiusRatio),
            height: CGFloat(FocusArc.coneHeightRatio))
        coneGeometry.materials = [coneMaterial]
        let cone = SCNNode()
        cone.name = "cone"
        cone.geometry = coneGeometry
        cone.pivot = SCNMatrix4MakeTranslation(0.0, FocusArc.coneHeightRatio / 2.0, 0.0)
        cone.eulerAngles.x = -.pi / 2.0

        return cone
    }()

    private lazy var fillPlane: SCNNode = {
        let length = FocusArc.Arc.scale * CGFloat(FocusArc.onPlaneScale)
        let path = UIBezierPath(ovalIn: CGRect(
            x: FocusArc.Arc.lineWidth / 2, y: FocusArc.Arc.lineWidth / 2,
            width: length - FocusArc.Arc.lineWidth,
            height: length - FocusArc.Arc.lineWidth))

        let layer = CAShapeLayer()
        layer.frame = CGRect(x: 0, y: 0, width: length, height: length)
        layer.path = path.cgPath
        layer.lineWidth = 1
        layer.strokeColor = FocusArc.fillColor.cgColor
        layer.fillColor = FocusArc.fillColor.cgColor
        let material = SCNMaterial()
        material.diffuse.contents = layer
        material.isDoubleSided = true
        let plane = SCNPlane(width: 1.0, height: 1.0)
        plane.materials = [material]
        let node = SCNNode(geometry: plane)
        node.name = "fillPlane"
        node.opacity = 0.0

        return node
    }()

    private func scaleAnimation(duration: TimeInterval) -> SCNAction {
        let size = FocusArc.size
        let ts = size * FocusArc.onPlaneScale

        let scaleAnimationStage1 = SCNAction.scale(
            to: CGFloat(size * 1.15),
            duration: duration * 0.25)
        scaleAnimationStage1.timingMode = .easeOut

        let scaleAnimationStage2 = SCNAction.scale(
            to: CGFloat(size * 1.15),
            duration: duration * 0.25)
        scaleAnimationStage2.timingMode = .linear

        let scaleAnimationStage3 = SCNAction.scale(
            to: CGFloat(ts * 0.97),
            duration: duration * 0.25)
        scaleAnimationStage3.timingMode = .easeOut

        let scaleAnimationStage4 = SCNAction.scale(
            to: CGFloat(ts),
            duration: duration * 0.25)
        scaleAnimationStage4.timingMode = .easeInEaseOut

        return SCNAction.sequence([
            scaleAnimationStage1,
            scaleAnimationStage2,
            scaleAnimationStage3,
            scaleAnimationStage4])
    }

    private func animateOpen(completionHandler block: (() -> Void)? = nil) {
        // Open animation
        guard !isOpen, !isAnimating else { block?(); return }
        isOpen = true
        isAnimating = true

        // Open animation
        let duration: TimeInterval = FocusArc.animationDuration / 4
        let opacityAnimation = SCNAction.fadeIn(duration: duration)
        opacityAnimation.timingMode = .easeOut
        let scaleAnimation = SCNAction.scale(to: CGFloat(FocusArc.size), duration: duration)
        scaleAnimation.timingMode = .easeOut
        let actions = SCNAction.group([opacityAnimation, scaleAnimation])
        self.runAction(actions) {
            self.updateQueue.async {
                block?()
                self.isAnimating = false
            }
        }
        self.arcs[0].open(to: FocusArc.Arc.openAngle, duration: duration / 4.0)
    }
    
    private func animateClose(newPlane: Bool = false) {
        guard isOpen, !isAnimating else { return }
        isOpen = false
        isAnimating = true

        self.removeAction(forKey: "pulse")
        self.opacity = 1.0

        let duration: TimeInterval = FocusArc.animationDuration
        // Opacity animation
        let opacityAnimation = SCNAction.fadeOpacity(to: 0.99, duration: duration / 2.0)
        opacityAnimation.timingMode = .easeOut
        // Scale animation
        let scalingAnimation = scaleAnimation(duration: duration)
        // Opacity and scale animations will run concurrently
        let actions = SCNAction.group([scalingAnimation, opacityAnimation])
        self.runAction(actions) {
            self.updateQueue.async {
                self.isAnimating = false
            }
        }

        // Wait for a bit then animate the arcs
        self.arcs[0].open(to: FocusArc.Arc.openSpringAngle, duration: duration / 2.0) {
            self.arcs[0].close(duration: duration / 4.0)
        }
        
        if newPlane {
            let waitAction = SCNAction.wait(duration: FocusArc.animationDuration * 0.75)
            let fadeInAction = SCNAction.fadeOpacity(to: 0.25, duration: FocusArc.animationDuration * 0.125)
            let fadeOutAction = SCNAction.fadeOpacity(to: 0.0, duration: FocusArc.animationDuration * 0.125)
            fillPlane.runAction(SCNAction.sequence([waitAction, fadeInAction, fadeOutAction]))
        }
    }

    private func showAsBillboard() {
        animateOpen() {
            if self.action(forKey: "pulse") == nil {
                self.runAction(pulseAction(), forKey: "pulse")
            }
        }
    }
    
    private func showAsOffPlane() {
        animateOpen() {
            if self.action(forKey: "pulse") != nil {
                self.removeAction(forKey: "pulse")
                self.opacity = 1.0
            }
        }
    }
    
    private func showAsOnNewPlane() {
        animateClose(newPlane: true)
    }
    
    private func showAsOnPlane() {
        animateClose(newPlane: false)
    }
    
    private func createConeNode() -> SCNNode {
        let coneMaterial = SCNMaterial()
        coneMaterial.diffuse.contents = FocusArc.primaryColor
        let coneGeometry = SCNCone(
            topRadius: 0.0,
            bottomRadius: CGFloat(FocusArc.coneBottomRadiusRatio),
            height: CGFloat(FocusArc.coneHeightRatio))
        coneGeometry.materials = [coneMaterial]
        let cone = SCNNode()
        cone.geometry = coneGeometry
        cone.pivot = SCNMatrix4MakeTranslation(0.0, FocusArc.coneHeightRatio / 2.0, 0.0)
        cone.eulerAngles.x = -Float(rad(90))
        return cone
    }
    
    // MARK: Appearance
    open var displayState: FocusNode.DisplayState = .initializing {
        didSet {
            switch displayState {
                case .initializing, .billboard:
                    showAsBillboard()
                case .offPlane:
                    showAsOffPlane()
                case .onNewPlane:
                    showAsOnNewPlane()
                case .onPlane:
                    showAsOnPlane()
            }
        }
    }

    // MARK: - Initialization
    open func setupGeometry(updateQueue: DispatchQueue) {
        self.updateQueue = updateQueue
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let a1 = Arc(name: "a1", quadrant: .left)
            let a2 = Arc(name: "a2", quadrant: .bottom)
            let a3 = Arc(name: "a3", quadrant: .right)
            self.arcs = [a1, a2, a3]

            for arc in self.arcs {
                self.addChildNode(arc)
            }

            // Cleanup. The geometry is only shared by the arcs
            // of that node, not with any future arcs...
            Arc.geometry = nil
            self.isOpen = true
            self.addChildNode(self.cone)
            self.addChildNode(self.fillPlane)
        }
    }
}
