//
//  FocusSquare.swift
//  ARFocusSquare
//
//  Created by Emmanuel Merali on 15/12/2019.
//  See LICENSE for details
//

import ARKit

// MARK: - Animations and Actions

private func pulseAction() -> SCNAction {
    let pulseOutAction = SCNAction.fadeOpacity(to: 0.4, duration: 0.5)
    let pulseInAction = SCNAction.fadeOpacity(to: 1.0, duration: 0.5)
    pulseOutAction.timingMode = .easeInEaseOut
    pulseInAction.timingMode = .easeInEaseOut

    return SCNAction.repeatForever(SCNAction.sequence([pulseOutAction, pulseInAction]))
}

private func flashAnimation(duration: TimeInterval) -> SCNAction {
    let action = SCNAction.customAction(duration: duration) { (node, elapsedTime) -> Void in
        // animate color from HSB 48/100/100 to 48/30/100 and back
        let elapsedTimePercentage = elapsedTime / CGFloat(duration)
        let saturation = 2.8 * (elapsedTimePercentage - 0.5) * (elapsedTimePercentage - 0.5) + 0.3
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

    let size = FocusSquare.size
    let ts = FocusSquare.size * FocusSquare.scaleForClosedSquare
    let values = [size, size * 1.15, size * 1.15, ts * 0.97, ts]
    let keyTimes: [NSNumber] = [0.00, 0.25, 0.50, 0.75, 1.00]
    let timingFunctions = [easeOut, linear, easeOut, easeInOut]

    scaleAnimation.values = values
    scaleAnimation.keyTimes = keyTimes
    scaleAnimation.timingFunctions = timingFunctions
    scaleAnimation.duration = FocusSquare.animationDuration

    return scaleAnimation
}

private extension FocusSquare {
    /*
    The focus square consists of eight segments as follows, which can be individually animated.

        s1  s2
        _   _
    s3 |     | s4

    s5 |     | s6
        -   -
        s7  s8
    */
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
            material.diffuse.contents = FocusSquare.primaryColor
            material.isDoubleSided = true
            material.ambient.contents = UIColor.black
            material.lightingModel = .constant
            material.emission.contents = FocusSquare.primaryColor
            geometry = plane
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

        func open() {
            if alignment == .horizontal {
                plane.width = Segment.openLength
            } else {
                plane.height = Segment.openLength
            }

            let offset = Segment.length / 2 - Segment.openLength / 2
            updatePosition(withOffset: Float(offset), for: openDirection)
        }

        func close() {
            let oldLength: CGFloat
            if alignment == .horizontal {
                oldLength = plane.width
                plane.width = Segment.length
            } else {
                oldLength = plane.height
                plane.height = Segment.length
            }

            let offset = Segment.length / 2 - oldLength / 2
            updatePosition(withOffset: Float(offset), for: openDirection.reversed)
        }

        private func updatePosition(withOffset offset: Float, for direction: Direction) {
            switch direction {
            case .left:     position.x -= offset
            case .right:    position.x += offset
            case .up:       position.y -= offset
            case .down:     position.y += offset
            }
        }

    }
}
/// This example class is taken almost entirely from Apple's own examples.
/// I have simply moved some things around to keep only what's necessary
///
/// An `SCNNode` which is used to provide uses with visual cues about the status of ARKit world tracking.
/// - Tag: FocusSquare
open class FocusSquare: FocusNode {

	// MARK: - Configuration Properties

	/// Original size of the focus square in meters.
	static let size: Float = 0.17

	/// Thickness of the focus square lines in meters.
	static let thickness: Float = 0.018

	/// Scale factor for the focus square when it is closed, w.r.t. the original size.
	static let scaleForClosedSquare: Float = 0.97

	/// Side length of the focus square segments when it is open (w.r.t. to a 1x1 square).
	static let sideLengthForOpenSegments: CGFloat = 0.2

	/// Duration of the open/close animation
    override open class var animationDuration: TimeInterval { 0.7 }

	static var primaryColor = #colorLiteral(red: 1, green: 0.8, blue: 0, alpha: 1)

	/// Color of the focus square fill.
	static var fillColor = #colorLiteral(red: 1, green: 0.9254901961, blue: 0.4117647059, alpha: 1)

	/// Indicates whether the segments of the focus square are disconnected.
	private var isOpen = false

    /// Indicates if the square is currently being animated for opening or closing.
    private var isAnimating = false
    
	/// List of the segments in the focus square.
	private var segments: [FocusSquare.Segment] = []

    private lazy var fillPlane: SCNNode = {
        let correctionFactor = FocusSquare.thickness / 2 // correction to align lines perfectly
        let length = CGFloat(1.0 - FocusSquare.thickness * 2 + correctionFactor)

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

	private func animateOffPlaneState() {
		// Open animation
        guard !isOpen, !isAnimating else { return }
		isOpen = true
        isAnimating = true

        // Open animation
        SCNTransaction.begin()
		SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeOut)
		SCNTransaction.animationDuration = FocusSquare.animationDuration / 4
		positioningNode.opacity = 1.0
		for segment in segments {
			segment.open()
		}
		SCNTransaction.completionBlock = {
			self.positioningNode.runAction(pulseAction(), forKey: "pulse")
			// This is a safe operation because `SCNTransaction`'s completion block is called back on the main thread.
			self.isAnimating = false
		}
		SCNTransaction.commit()
		// Add a scale/bounce animation.
		SCNTransaction.begin()
		SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeOut)
		SCNTransaction.animationDuration = FocusSquare.animationDuration / 4
		positioningNode.simdScale = SIMD3<Float>(repeating: FocusSquare.size)
		SCNTransaction.commit()
	}

	private func animateOnPlaneState(newPlane: Bool = false) {
        guard isOpen, !isAnimating else { return }
        isOpen = false
        isAnimating = true

		positioningNode.removeAction(forKey: "pulse")
		positioningNode.opacity = 1.0

		// Close animation
		SCNTransaction.begin()
		SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeOut)
		SCNTransaction.animationDuration = FocusSquare.animationDuration / 2
		positioningNode.opacity = 0.99
		SCNTransaction.completionBlock = {
			SCNTransaction.begin()
			SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeOut)
			SCNTransaction.animationDuration = FocusSquare.animationDuration / 4
			for segment in self.segments {
				segment.close()
			}
			SCNTransaction.completionBlock = {
				self.isAnimating = false
			}
			SCNTransaction.commit()
		}
		SCNTransaction.commit()

		// Scale/bounce animation
		positioningNode.addAnimation(scaleAnimation(for: "transform.scale.x"), forKey: "transform.scale.x")
		positioningNode.addAnimation(scaleAnimation(for: "transform.scale.y"), forKey: "transform.scale.y")
		positioningNode.addAnimation(scaleAnimation(for: "transform.scale.z"), forKey: "transform.scale.z")

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
        /*
         The focus square consists of eight segments as follows, which can be individually animated.
         
             s1  s2
             _   _
         s3 |     | s4
         
         s5 |     | s6
             -   -
             s7  s8
         */
        let s1 = Segment(name: "s1", corner: .topLeft, alignment: .horizontal)
        let s2 = Segment(name: "s2", corner: .topRight, alignment: .horizontal)
        let s3 = Segment(name: "s3", corner: .topLeft, alignment: .vertical)
        let s4 = Segment(name: "s4", corner: .topRight, alignment: .vertical)
        let s5 = Segment(name: "s5", corner: .bottomLeft, alignment: .vertical)
        let s6 = Segment(name: "s6", corner: .bottomRight, alignment: .vertical)
        let s7 = Segment(name: "s7", corner: .bottomLeft, alignment: .horizontal)
        let s8 = Segment(name: "s8", corner: .bottomRight, alignment: .horizontal)
        segments = [s1, s2, s3, s4, s5, s6, s7, s8]

        let sl: Float = 0.5  // segment length
        let c: Float = FocusSquare.thickness / 2 // correction to align lines perfectly
        s1.simdPosition += SIMD3<Float>(-(sl / 2 - c), -(sl - c), 0)
        s2.simdPosition += SIMD3<Float>(sl / 2 - c, -(sl - c), 0)
        s3.simdPosition += SIMD3<Float>(-sl, -sl / 2, 0)
        s4.simdPosition += SIMD3<Float>(sl, -sl / 2, 0)
        s5.simdPosition += SIMD3<Float>(-sl, sl / 2, 0)
        s6.simdPosition += SIMD3<Float>(sl, sl / 2, 0)
        s7.simdPosition += SIMD3<Float>(-(sl / 2 - c), sl - c, 0)
        s8.simdPosition += SIMD3<Float>(sl / 2 - c, sl - c, 0)

        for segment in segments {
            positioningNode.addChildNode(segment)
//            segment.open()
        }
        positioningNode.addChildNode(fillPlane)
        positioningNode.eulerAngles.x = .pi / 2 // Horizontal
        positioningNode.simdScale = SIMD3<Float>(repeating: FocusSquare.size * FocusSquare.scaleForClosedSquare)
    }
}
