//
//  FocusSquare.swift
//  ARFocusSquare
//
//  Created by Emmanuel Merali on 15/12/2019.
//  See LICENSE for details
//

import SceneKit

// MARK: - Animations and Actions

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

private func setInitialPosition(node: FocusSquare.Segment) {
    let sl: Float = Float(FocusSquare.Segment.length)  // segment length
    let c: Float = Float(FocusSquare.Segment.thickness) / 2.0 // correction to align lines perfectly
    let corner = node.corner
    let alignment = node.alignment
    var x: Float, y: Float
    var position: SIMD3<Float>
    x = ((alignment == .vertical) ? sl : sl / 2 - c)
    y = ((alignment == .vertical) ? sl / 2 : sl - c)
    switch corner {
        case .topRight:
            position = SIMD3<Float>(x, y, 0)
        case .topLeft:
            position = SIMD3<Float>(-x, y, 0)
        case .bottomLeft:
            position = SIMD3<Float>(-x, -y, 0)
        case .bottomRight:
            position = SIMD3<Float>(x, -y, 0)
    }
    node.simdPosition = position
}

private extension FocusSquare {

    enum Corner {
        case topLeft // s1, s3
        case topRight // s2, s4
        case bottomRight // s6, s8
        case bottomLeft // s5, s7
    }

    enum Alignment {
        case horizontal // s1, s2, s7, s8
        case vertical // s3, s4, s5, s6
    }

    enum Direction {
        case up, down, left, right

        var reversed: Direction {
            switch self {
            case .up:   return .down
            case .down: return .up
            case .left:  return .right
            case .right: return .left
            }
        }
    }
    
    struct FPoint {
        var x: CGFloat
        var y: CGFloat
        
        init(x: Float, y: Float) {
            self.x = CGFloat(x)
            self.y = CGFloat(y)
        }
    }
    
    class Segment: SCNNode {

        // MARK: - Configuration & Initialization

        /// Thickness of the focus square lines in m.
        static let thickness: CGFloat = 0.018

        /// Length of the focus square lines in m.
        static let length: CGFloat = 0.5  // segment length

        /// Side length of the focus square segments when it is open (w.r.t. to a 1x1 square).
        static let openLength: CGFloat = 0.2

        let corner: Corner
        let alignment: Alignment
        let plane: SCNPlane

        init(name: String, corner: Corner, alignment: Alignment) {
            self.corner = corner
            self.alignment = alignment

            switch alignment {
            case .vertical:
                plane = SCNPlane(width: Segment.thickness, height: Segment.length)
            case .horizontal:
                plane = SCNPlane(width: Segment.length, height: Segment.thickness)
            }
            super.init()
            self.name = name

            let material = plane.firstMaterial!
            material.diffuse.contents = FocusSquare.primaryColor // For debug :) (corner == .topLeft) ? UIColor.black : FocusSquare.primaryColor
            material.isDoubleSided = true
            material.ambient.contents = UIColor.black
            material.lightingModel = .constant
            material.emission.contents = FocusSquare.primaryColor
            geometry = plane
            setInitialPosition(node: self)
        }

        required init?(coder aDecoder: NSCoder) {
            fatalError("\(#function) has not been implemented")
        }

        // MARK: - Animating Open/Closed

        var openDirection: Direction {
            switch (corner, alignment) {
                case (.topLeft,     .horizontal):   return .left
                case (.topLeft,     .vertical):     return .up
                case (.topRight,    .horizontal):   return .right
                case (.topRight,    .vertical):     return .up
                case (.bottomLeft,  .horizontal):   return .left
                case (.bottomLeft,  .vertical):     return .down
                case (.bottomRight, .horizontal):   return .right
                case (.bottomRight, .vertical):     return .down
            }
        }

        private func makeSizeAction(growFrom: CGFloat, to: CGFloat, duration: TimeInterval) -> SCNAction {
            let sizeAction = SCNAction.customAction(duration: duration) { (node, elapsed) in
                guard let node = node as? Segment else { return }
                let percent: CGFloat = duration == 0.0 ? 1.0 : elapsed / CGFloat(duration)
                let offset = (to - growFrom) * percent
                let newSize = growFrom + offset
                if node.alignment == .horizontal {
                    node.plane.width = newSize
                } else {
                    node.plane.height = newSize
                }
            }
            return sizeAction
        }
        
        private func offset(withOffset offset: Float, for direction: Direction) -> FPoint {
            switch direction {
            case .left:     return FPoint(x: -offset, y: 0.0)
            case .right:    return FPoint(x: offset, y: 0.0)
            case .up:       return FPoint(x: 0.0, y: offset)
            case .down:     return FPoint(x: 0.0, y: -offset)
            }
        }

        func open(duration: TimeInterval) {
            guard action(forKey: "segment") == nil else { return }
            let oldLength = alignment == .horizontal ? plane.width : plane.height
            let offset = oldLength / 2 - Segment.openLength / 2
            let moveByOffset = self.offset(withOffset:Float(offset), for:openDirection)
            let moveAction = SCNAction.moveBy(x: moveByOffset.x, y: moveByOffset.y, z: 0.0, duration: duration)
            let sizeAction = makeSizeAction(growFrom: oldLength, to: Segment.openLength, duration: duration)
            let actions = SCNAction.group([moveAction, sizeAction])
            self.runAction(actions, forKey: "segment")
        }

        func close(duration: TimeInterval) {
            guard action(forKey: "segment") == nil else { return }
            let oldLength = alignment == .horizontal ? plane.width : plane.height
            let offset = Segment.length / 2 - oldLength / 2
            let moveByOffset = self.offset(withOffset:Float(offset), for:openDirection.reversed)
            let moveAction = SCNAction.moveBy(x: moveByOffset.x, y: moveByOffset.y, z: 0.0, duration: duration)
            let sizeAction = makeSizeAction(growFrom: oldLength, to: Segment.length, duration: duration)
            let actions = SCNAction.group([moveAction, sizeAction])
            self.runAction(actions, forKey: "segment")
        }
    }
}
/// This example class is taken almost entirely from Apple's own examples.
/// I have simply moved some things around to keep only what's necessary
///
/// An `SCNNode` which is used to provide uses with visual cues about the status of ARKit world tracking.
/// - Tag: FocusSquare
open class FocusSquare: SCNNode, FocusIndicatorNode {
    // MARK: - Configuration Properties

    /// Original size of the focus square in meters.
    public static let size: Float = 0.17

	/// Scale factor for the focus square when it is closed, w.r.t. the original size.
	static let scaleForClosedSquare: Float = 0.97

	static var primaryColor = #colorLiteral(red: 1, green: 0.8, blue: 0, alpha: 1)

	/// Color of the focus square fill.
	static var fillColor = #colorLiteral(red: 1, green: 0.9254901961, blue: 0.4117647059, alpha: 1)

    /// The queue on which all operations are done
    private var updateQueue: DispatchQueue!
    
	/// Indicates whether the segments of the focus square are disconnected.
	private var isOpen = false

    static var animationDuration: TimeInterval = 0.7
    
    /// Indicates if the square is currently being animated for opening or closing.
    private var isAnimating = false
    
	/// List of the segments in the focus square.
	private var segments: [FocusSquare.Segment] = []

    private lazy var fillPlane: SCNNode = {
        let correctionFactor = FocusSquare.Segment.thickness / 2 // correction to align lines perfectly
        let length = CGFloat(1.0 - correctionFactor * 3)

        let plane = SCNPlane(width: length, height: length)
        let node = SCNNode(geometry: plane)
        node.name = "fillPlane"
        node.opacity = 0.0

        let material = plane.firstMaterial!
        material.diffuse.contents = FocusSquare.fillColor
        material.isDoubleSided = true
        material.ambient.contents = UIColor.black
        material.lightingModel = .constant
        material.emission.contents = FocusSquare.fillColor

        return node
    }()

    private func keyFrameBasedScaleAnimation(duration: TimeInterval) -> SCNAction {
        let size = FocusSquare.size
        let ts = size * FocusSquare.scaleForClosedSquare

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
        let scaleAnimation = SCNAction.scale(to: CGFloat(FocusSquare.size), duration: duration)
        scaleAnimation.timingMode = .easeOut
        let actions = SCNAction.group([opacityAnimation, scaleAnimation])
        self.runAction(actions) {
            self.updateQueue.async {
                self.runAction(pulseAction(), forKey: "pulse")
                self.isAnimating = false
            }
        }
		for segment in segments {
            segment.open(duration: duration)
		}
	}

	private func animateOnPlaneState(newPlane: Bool = false) {
        guard isOpen, !isAnimating else { return }
        isOpen = false
        isAnimating = true

        self.removeAction(forKey: "pulse")
        self.opacity = 1.0

        let duration: TimeInterval = FocusSquare.animationDuration

        let opacityAnimation = SCNAction.fadeOpacity(to: 0.99, duration: duration / 2.0)
        opacityAnimation.timingMode = .easeOut
        // Scale animation
        let scalingAnimation = keyFrameBasedScaleAnimation(duration: duration)
        // Opacity and scale animations will run concurrently
        let actions = SCNAction.group([scalingAnimation, opacityAnimation])
        self.runAction(actions) {
            self.updateQueue.async {
                self.isAnimating = false
            }
        }

        // Wait for a bit then animate the segments
        let waitAnimation = SCNAction.wait(duration: duration / 2.0)
        self.runAction(waitAnimation) {
            for segment in self.segments {
                segment.close(duration: duration / 4.0)
            }
        }
        
		if newPlane {
			let waitAction = SCNAction.wait(duration: FocusSquare.animationDuration * 0.75)
			let fadeInAction = SCNAction.fadeOpacity(to: 0.25, duration: FocusSquare.animationDuration * 0.125)
			let fadeOutAction = SCNAction.fadeOpacity(to: 0.0, duration: FocusSquare.animationDuration * 0.125)
			fillPlane.runAction(SCNAction.sequence([waitAction, fadeInAction, fadeOutAction]))

			let flashSquareAction = flashAnimation(duration: FocusSquare.animationDuration * 0.25)
			for segment in segments {
				segment.runAction(.sequence([waitAction, flashSquareAction]))
			}
		}
	}
    
    // MARK: Appearance
    open var displayState: FocusNode.DisplayState = .initializing {
        didSet {
            switch displayState {
                case .initializing, .billboard:
                    animateOffPlaneState()
                case .offPlane:
                    animateOffPlaneState()
                case .onNewPlane:
                    animateOnPlaneState(newPlane: true)
                case .onPlane:
                    animateOnPlaneState(newPlane: false)
            }
        }
    }

    // MARK: - Initialization
    open func setupGeometry(updateQueue: DispatchQueue) {
        /*
         The focus square consists of eight segments as follows, which can be individually animated.
         
             s1  s2
             _   _
         s3 |     | s4
         
         s5 |     | s6
             -   -
             s7  s8
         */
        self.updateQueue = updateQueue
        let s1 = Segment(name: "s1", corner: .topLeft, alignment: .horizontal)
        let s2 = Segment(name: "s2", corner: .topRight, alignment: .horizontal)
        let s3 = Segment(name: "s3", corner: .topLeft, alignment: .vertical)
        let s4 = Segment(name: "s4", corner: .topRight, alignment: .vertical)
        let s5 = Segment(name: "s5", corner: .bottomLeft, alignment: .vertical)
        let s6 = Segment(name: "s6", corner: .bottomRight, alignment: .vertical)
        let s7 = Segment(name: "s7", corner: .bottomLeft, alignment: .horizontal)
        let s8 = Segment(name: "s8", corner: .bottomRight, alignment: .horizontal)
        segments = [s1, s2, s3, s4, s5, s6, s7, s8]

        for segment in segments {
            self.addChildNode(segment)
            segment.open(duration: 0)
        }
        self.isOpen = true
        self.addChildNode(fillPlane)
    }
}
