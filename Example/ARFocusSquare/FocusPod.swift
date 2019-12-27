//
//  FocusPod.swift
//  ARFocusSquare_Example
//
//  Created by Emmanuel Merali on 18/12/2019.
//  Copyright © 2019 CocoaPods. All rights reserved.
//

import ARKit
import ARFocusSquare

private func pulseAction() -> SCNAction {
    let pulseOutAction = SCNAction.fadeOpacity(to: 0.4, duration: 0.5)
    let pulseInAction = SCNAction.fadeOpacity(to: 1.0, duration: 0.5)
    pulseOutAction.timingMode = .easeInEaseOut
    pulseInAction.timingMode = .easeInEaseOut

    return SCNAction.repeatForever(SCNAction.sequence([pulseOutAction, pulseInAction]))
}

private func flashAnimation(duration: TimeInterval) -> SCNAction {
    let action = SCNAction.customAction(duration: duration) { (node, elapsed) -> Void in
        // animate color from HSB 48/100/100 to 48/30/100 and back
        let percent: CGFloat = duration == 0.0 ? 1.0 : elapsed / CGFloat(duration)
        let saturation = 2.8 * (percent - 0.5) * (percent - 0.5) + 0.3
        if let material = node.geometry?.firstMaterial {
            material.diffuse.contents = UIColor(hue: 0.1333, saturation: saturation, brightness: 1.0, alpha: 1.0)
        }
    }
    return action
}

private func scaleAnimation(for keyPath: String) -> CAKeyframeAnimation {
    let scaleAnimation = CAKeyframeAnimation(keyPath: keyPath)

    let easeOut = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
    let easeInOut = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
    let linear = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)

    let size = FocusPod.size
    let ts = FocusPod.size * FocusPod.scaleForOnPlane
    let values = [size, size * 1.15, size * 1.15, ts * 0.97, ts]
    let keyTimes: [NSNumber] = [0.00, 0.25, 0.50, 0.75, 1.00]
    let timingFunctions = [easeOut, linear, easeOut, easeInOut]

    scaleAnimation.values = values
    scaleAnimation.keyTimes = keyTimes
    scaleAnimation.timingFunctions = timingFunctions
    scaleAnimation.duration = FocusPod.animationDuration

    return scaleAnimation
}

class FocusPod: FocusNode {
    /// Original size of the focus square in meters.
    static let size: Float = 0.4

    /// Scale factor for the focus square when it is closed, w.r.t. the original size.
    static let scaleForOnPlane: Float = 0.8

    /// Duration of the open/close animation
    override open class var animationDuration: TimeInterval { 0.7 }

    static var baseColor = #colorLiteral(red: 0.3098039329, green: 0.2039215714, blue: 0.03921568766, alpha: 1)

    static var primaryColor = #colorLiteral(red: 1, green: 0.8, blue: 0, alpha: 1)

    static var sidesColor = #colorLiteral(red: 0.3411764801, green: 0.6235294342, blue: 0.1686274558, alpha: 1)

    private var pyramid = SCNNode()
    
    /// Indicates whether the segments of the focus square are disconnected.
    private var isOpen = false

    /// Indicates if the square is currently being animated for opening or closing.
    private var isAnimating = false
    
    private func keyFrameBasedScaleAnimation(duration: TimeInterval) -> SCNAction {
        let size = displaySize * displayScale
        let ts = size * FocusPod.scaleForOnPlane

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

    private func animateOffPlaneState() {
        // Open animation
        guard !isOpen, !isAnimating else { return }
        isOpen = true
        isAnimating = true

        // Open animation
        let duration: TimeInterval = FocusSquare.animationDuration / 4
        let opacityAnimation = SCNAction.fadeIn(duration: duration)
        opacityAnimation.timingMode = .easeOut
        let scaleAnimation = SCNAction.scale(to: CGFloat(displaySize * displayScale), duration: duration)
        scaleAnimation.timingMode = .easeOut
        let actions = SCNAction.group([opacityAnimation, scaleAnimation])
        self.runAction(actions) {
            self.runAction(pulseAction(), forKey: "pulse")
            // This is a safe operation because `SCNTransaction`'s completion block is called back on the main thread.
            self.isAnimating = false
        }
    }
    
    private func animateOnPlaneState(newPlane: Bool = false) {
        guard isOpen, !isAnimating else { return }
        isOpen = false
        isAnimating = true

        self.removeAction(forKey: "pulse")
        self.opacity = 1.0

        let duration: TimeInterval = FocusArc.animationDuration

        let opacityAnimation = SCNAction.fadeOpacity(to: 0.99, duration: duration / 2.0)
        opacityAnimation.timingMode = .easeOut
        // Scale animation
        let scalingAnimation = keyFrameBasedScaleAnimation(duration: duration)
        // Opacity and scale animations will run concurrently
        let actions = SCNAction.group([scalingAnimation, opacityAnimation])
        self.runAction(actions) {
            self.isAnimating = false
        }
    }
    
    private func makeMaterial(from color: UIColor) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.emission.contents = color
        material.isDoubleSided = true
        material.lightingModel = .physicallyBased
        return material
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
        let geometry = SCNPyramid(width: CGFloat(FocusPod.size),
                                  height: CGFloat(FocusPod.size) * 0.707,
                                  length: CGFloat(FocusPod.size))
        let materials: [SCNMaterial] = [
            makeMaterial(from: FocusPod.baseColor),
            makeMaterial(from: FocusPod.sidesColor),
            makeMaterial(from: FocusPod.primaryColor),
            makeMaterial(from: FocusPod.sidesColor),
            makeMaterial(from: FocusPod.sidesColor)
        ]
        geometry.materials = materials
        pyramid.geometry = geometry
        pyramid.pivot = SCNMatrix4MakeTranslation(0.0, -FocusPod.size * 0.707 / 2.0, 0.0)
        pyramid.eulerAngles.x = .pi / 2
        self.addChildNode(pyramid)
        displaySize = FocusPod.size * FocusPod.scaleForOnPlane
    }
}
