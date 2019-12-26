//
//  FocusArc.swift
//  ARFocusSquare
//
//  Created by Emmanuel Merali on 25/12/2019.
//

import ARKit

// MARK: - Animations and Actions

private func pulseAction() -> SCNAction {
    let pulseOutAction = SCNAction.fadeOpacity(to: 0.4, duration: 0.7)
    let pulseInAction = SCNAction.fadeOpacity(to: 1.0, duration: 0.7)
    pulseOutAction.timingMode = .easeInEaseOut
    pulseInAction.timingMode = .easeInEaseOut

    return SCNAction.repeatForever(SCNAction.sequence([pulseOutAction, pulseInAction]))
}

private func scaleAnimation(duration: TimeInterval) -> SCNAction {
    let size = FocusArc.size
    let ts = FocusArc.size * FocusArc.onPlaneScale

    let scaleAnimationStage1 = SCNAction.scale(
        to: CGFloat(size * 1.15),
        duration: FocusArc.animationDuration * 0.25)
    scaleAnimationStage1.timingMode = .easeOut

    let scaleAnimationStage2 = SCNAction.scale(
        to: CGFloat(size * 1.15),
        duration: FocusArc.animationDuration * 0.25)
    scaleAnimationStage2.timingMode = .linear

    let scaleAnimationStage3 = SCNAction.scale(
        to: CGFloat(ts * 0.97),
        duration: FocusArc.animationDuration * 0.25)
    scaleAnimationStage3.timingMode = .easeOut

    let scaleAnimationStage4 = SCNAction.scale(
        to: CGFloat(ts),
        duration: FocusArc.animationDuration * 0.25)
    scaleAnimationStage4.timingMode = .easeInEaseOut

    return SCNAction.sequence([
        scaleAnimationStage1,
        scaleAnimationStage2,
        scaleAnimationStage3,
        scaleAnimationStage4])
}

private func animationFrame(node: SCNNode, progress: CGFloat) {
    if let layer = node.geometry?.materials.first?.diffuse.contents as? CAShapeLayer {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.strokeStart = FocusArc.Arc.factor * progress
        layer.strokeEnd = 1 - layer.strokeStart
        CATransaction.commit()
    }
}

private func openArcAnimation(duration: TimeInterval) -> SCNAction {
    let action = SCNAction.customAction(duration: duration) { (node, elapsed) in
        let percent: CGFloat = elapsed / CGFloat(duration)
        animationFrame(node: node, progress: percent)
    }
    let completion = SCNAction.customAction(duration: 0) { (node, elapsed) in
        animationFrame(node: node, progress: 1.0)
    }
    action.timingMode = .easeInEaseOut
    action.timingFunction = { (time) in return time }
    return SCNAction.sequence([action, completion])
}

private func closeArcAnimation(duration: TimeInterval) -> SCNAction {
    let action = SCNAction.customAction(duration: duration) { (node, elapsed) in
        let percent: CGFloat = 1 - elapsed / CGFloat(duration)
        animationFrame(node: node, progress: percent)
    }
    let completion = SCNAction.customAction(duration: 0) { (node, elapsed) in
        animationFrame(node: node, progress: 0.0)
    }
    action.timingMode = .easeInEaseOut
    action.timingFunction = { (time) in return time }
    return SCNAction.sequence([action, completion])
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

    let layerMaterial = SCNMaterial()
    layerMaterial.diffuse.contents = layer
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

        static var geometry: SCNGeometry?

        static var pivot: SCNMatrix4?
        
        static let maxOpenAngle: CGFloat = 15.0

        static var factor: CGFloat = Arc.maxOpenAngle / Arc.arcAngle

        let quadrant: Quadrant
                
        init(name: String, quadrant: Quadrant) {
            self.quadrant = quadrant
            super.init()
            let geometry = makeArcGeometry(
                arcAngle: Arc.arcAngle,
                scale: Arc.scale,
                lineWidth: Arc.lineWidth,
                color: FocusArc.primaryColor)
            let size = CGSize(width: geometry.width, height: geometry.height)
            let pivot = SCNMatrix4MakeTranslation(
                -Float(size.height - size.width / 2),
                -Float(size.height / 2.0),
                0)
            var zAngle: CGFloat = 90 - Arc.arcAngle / 2.0
            switch quadrant {
            case .left:
                zAngle += Arc.arcAngle
            case .right:
                zAngle -= Arc.arcAngle
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
open class FocusArc: FocusNode {

    // MARK: - Configuration Properties

    /// Original size of the focus square in meters.
    static let size: Float = 0.17

    /// Radius of the base of the cone in respect to the radius of the focus node
    static let coneBottomRadiusRatio: Float = 0.1

    /// Height of the cone in respect to the diamater of the focus node
    static let coneHeightRatio: Float = 0.2

    /// Scale factor for the focus square when it is closed, w.r.t. the original size.
    static let onPlaneScale: Float = 0.97

    /// Duration of the open/close animation
    override open class var animationDuration: TimeInterval { 0.7 }

    static var primaryColor = #colorLiteral(red: 0.1764705926, green: 0.4980392158, blue: 0.7568627596, alpha: 1)

    /// Color of the focus square fill.
    static var fillColor = #colorLiteral(red: 0.2392156869, green: 0.6745098233, blue: 0.9686274529, alpha: 1)

    /// Indicates whether the segments of the focus square are disconnected.
    private var isOpen = false

    /// Indicates if the square is currently being animated for opening or closing.
    private var isAnimating = false
    
    /// List of the segments in the focus square.
    private var arcs: [FocusArc.Arc] = []
    
    private var cone: SCNNode = SCNNode()

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
        node.eulerAngles.x = -.pi
        node.name = "fillPlane"
        node.opacity = 0.0

        return node
    }()

    private func animateOffPlaneState() {
        // Open animation
        guard !isOpen, !isAnimating else { return }
        isOpen = true
        isAnimating = true

        var animation1 = false
        var animation2 = false
        
        let duration: TimeInterval = FocusArc.animationDuration / 4
        let arcAnimation = openArcAnimation(duration: duration)
        let opacityAnimation = SCNAction.fadeIn(duration: duration)
        opacityAnimation.timingMode = .easeOut
        opacityAnimation.timingFunction = { (time) in return time }
        let scaleAnimation = SCNAction.scale(to: CGFloat(FocusArc.size), duration: duration)
        scaleAnimation.timingMode = .easeOut
        scaleAnimation.timingFunction = { (time) in return time }
        let actions = SCNAction.group([opacityAnimation, scaleAnimation])
        positioningNode.runAction(actions) {
            self.positioningNode.runAction(pulseAction(), forKey: "pulse")
            // This is a safe operation because `SCNTransaction`'s completion block is called back on the main thread.
            guard animation2 else {
                animation1 = true
                return
            }
            self.isAnimating = false
        }
        guard arcs.count > 0 else {
            animation2 = true
            return
        }
        for arc in arcs {
            arc.runAction(arcAnimation) {
                guard animation1 else {
                    animation2 = true
                    return
                }
                self.isAnimating = false
            }
        }
    }

    private func animateOnPlaneState(newPlane: Bool = false) {
        guard isOpen, !isAnimating else { return }
        isOpen = false
        isAnimating = true

        positioningNode.removeAction(forKey: "pulse")
        positioningNode.opacity = 1.0

        let duration: TimeInterval = FocusArc.animationDuration
        let opacityAnimation = SCNAction.fadeOpacity(to: 0.99, duration: duration / 2.0)
        opacityAnimation.timingMode = .easeOut
        opacityAnimation.timingFunction = { (time) in return time }
        let actions = SCNAction.group([scaleAnimation(duration: duration), opacityAnimation])
        positioningNode.runAction(actions)
        let waitAnimation = SCNAction.wait(duration: duration / 2.0)
        self.runAction(waitAnimation) {
            let arcAnimation = closeArcAnimation(duration: duration / 4.0)
            for arc in self.arcs {
                arc.runAction(arcAnimation) {
                    self.isAnimating = false
                }
            }
        }
        
        if newPlane {
            let waitAction = SCNAction.wait(duration: FocusArc.animationDuration * 0.75)
            let fadeInAction = SCNAction.fadeOpacity(to: 0.25, duration: FocusArc.animationDuration * 0.125)
            let fadeOutAction = SCNAction.fadeOpacity(to: 0.0, duration: FocusArc.animationDuration * 0.125)
            fillPlane.runAction(SCNAction.sequence([waitAction, fadeInAction, fadeOutAction]))
        }
    }

    private func createConeNode() {
        let coneMaterial = SCNMaterial()
        coneMaterial.diffuse.contents = FocusArc.primaryColor
        let coneGeometry = SCNCone(
            topRadius: 0.0,
            bottomRadius: CGFloat(FocusArc.coneBottomRadiusRatio),
            height: CGFloat(FocusArc.coneHeightRatio))
        coneGeometry.materials = [coneMaterial]
        cone.geometry = coneGeometry
        cone.pivot = SCNMatrix4MakeTranslation(0.0, FocusArc.coneHeightRatio / 2.0, 0.0)
        cone.eulerAngles.x = Float(rad(90))
    }
    
    // MARK: Appearance
    open override func displayStateChanged(_ state: FocusNode.DisplayState, newPlane: Bool = false) {
        super.displayStateChanged(state, newPlane: newPlane)
        switch state {
            case .initializing, .billboard:
                animateOffPlaneState()
            case .offPlane:
                animateOffPlaneState()
            case .onPlane:
                animateOnPlaneState(newPlane: newPlane)
        }
    }

    // MARK: - Initialization
    open override func initGeometry() {
        super.initGeometry()
        let a1 = Arc(name: "a1", quadrant: .left)
        let a2 = Arc(name: "a2", quadrant: .bottom)
        let a3 = Arc(name: "a3", quadrant: .right)
        arcs = [a1, a2, a3]

        for arc in arcs {
            positioningNode.addChildNode(arc)
            arc.runAction(openArcAnimation(duration: 0))
        }

        createConeNode()
        positioningNode.addChildNode(cone)

        positioningNode.addChildNode(fillPlane)
        positioningNode.eulerAngles.x = .pi / 2 // Horizontal
        positioningNode.simdScale = SIMD3<Float>(repeating: FocusArc.size * FocusArc.onPlaneScale)
    }
}
