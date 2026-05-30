import SwiftUI

/// Configuration for route diagram rendering
struct DiagramConfig {
    let fieldWidth: CGFloat
    let fieldHeight: CGFloat
    let lineOfScrimmageY: CGFloat
    let routeLength: CGFloat
    let breakLength: CGFloat
    let receiverRadius: CGFloat
    let footballSize: CGFloat
    let receiverSpacing: CGFloat
    let sideMargin: CGFloat

    static func standard(for size: CGSize) -> DiagramConfig {
        let width = size.width
        let height = size.height
        return DiagramConfig(
            fieldWidth: width,
            fieldHeight: height,
            lineOfScrimmageY: height * 0.60,
            routeLength: height * 0.25,
            breakLength: height * 0.15,
            receiverRadius: 12,
            footballSize: 10,
            receiverSpacing: width * 0.16,
            sideMargin: width * 0.08
        )
    }
}

/// Computes receiver positions and route paths for diagram rendering.
/// Routes are drawn using absolute direction rules — NOT mirrored.
struct DiagramRenderer {

    /// Compute the starting position for each receiver in a formation.
    func receiverPositions(formation: Formation, config: DiagramConfig) -> [Receiver: CGPoint] {
        var positions: [Receiver: CGPoint] = [:]
        let centerX = config.fieldWidth / 2
        let losY = config.lineOfScrimmageY

        switch formation {
        case .twins:
            // Left: X, Y (Y inside X)
            positions[.X] = CGPoint(x: centerX - config.receiverSpacing * 2, y: losY)
            positions[.Y] = CGPoint(x: centerX - config.receiverSpacing, y: losY)
            // Right: Z, A (A outside Z)
            positions[.Z] = CGPoint(x: centerX + config.receiverSpacing, y: losY)
            positions[.A] = CGPoint(x: centerX + config.receiverSpacing * 2, y: losY)

        case .tripsLeft:
            // A (outside), X, Y (inside) on left; Z isolated right
            positions[.A] = CGPoint(x: centerX - config.receiverSpacing * 2.5, y: losY)
            positions[.X] = CGPoint(x: centerX - config.receiverSpacing * 1.5, y: losY)
            positions[.Y] = CGPoint(x: centerX - config.receiverSpacing * 0.5, y: losY)
            positions[.Z] = CGPoint(x: centerX + config.receiverSpacing * 2, y: losY)

        case .tripsRight:
            // X isolated left; Y (inside), Z, A (outside) on right
            positions[.X] = CGPoint(x: centerX - config.receiverSpacing * 2, y: losY)
            positions[.Y] = CGPoint(x: centerX + config.receiverSpacing * 0.5, y: losY)
            positions[.Z] = CGPoint(x: centerX + config.receiverSpacing * 1.5, y: losY)
            positions[.A] = CGPoint(x: centerX + config.receiverSpacing * 2.5, y: losY)

        case .proLeft:
            // X far left, Y slot left, Z far right — wider spread than Trips
            positions[.X] = CGPoint(x: centerX - config.receiverSpacing * 2.8, y: losY)
            positions[.Y] = CGPoint(x: centerX - config.receiverSpacing * 0.75, y: losY)
            positions[.Z] = CGPoint(x: centerX + config.receiverSpacing * 2.8, y: losY)

        case .proRight:
            // X far left, Z far right, Y slot right — wider spread than Trips
            positions[.X] = CGPoint(x: centerX - config.receiverSpacing * 2.8, y: losY)
            positions[.Z] = CGPoint(x: centerX + config.receiverSpacing * 2.8, y: losY)
            positions[.Y] = CGPoint(x: centerX + config.receiverSpacing * 0.75, y: losY)
        }

        return positions
    }

    /// Compute the route path for a single assignment.
    /// Routes use ABSOLUTE direction rules based on the route number:
    /// - 3 ALWAYS breaks LEFT
    /// - 4 ALWAYS breaks RIGHT
    /// - 7 ALWAYS angles top-left
    /// - 8 ALWAYS angles top-right
    /// Side-awareness only affects the route MEANING label, not the drawing direction.
    /// - Parameters:
    ///   - assignment: The route assignment (contains receiver, route number, and original side).
    ///   - startPosition: The starting position for this receiver (already accounts for motion final position for Y).
    ///   - side: The field side to use for route interpretation (use motionFinalSide for receivers with motion).
    ///   - config: Diagram configuration.
    func routePath(for assignment: RouteAssignment, startPosition: CGPoint, side: FieldSide, config: DiagramConfig) -> [CGPoint] {
        let stemLength = config.routeLength
        let breakLen = config.breakLength

        // All routes start by going upfield (negative Y in screen coords)
        let stemEnd = CGPoint(x: startPosition.x, y: startPosition.y - stemLength)

        switch assignment.routeNumber {
        case .zero:
            // Hitch: short stem only
            let shortStem = CGPoint(x: startPosition.x, y: startPosition.y - stemLength * 0.3)
            return [startPosition, shortStem]

        case .one:
            // LEFT: Quick Out (break left quickly)
            // RIGHT: Quick Slant (break inward quickly)
            let shortStem = CGPoint(x: startPosition.x, y: startPosition.y - stemLength * 0.25)
            if side == .left {
                // Quick out breaks LEFT (toward sideline for left-side receiver)
                let breakPoint = CGPoint(x: shortStem.x - breakLen, y: shortStem.y)
                return [startPosition, shortStem, breakPoint]
            } else {
                // Quick slant breaks inward (toward center)
                let breakPoint = CGPoint(x: shortStem.x - breakLen * 0.7, y: shortStem.y - breakLen * 0.5)
                return [startPosition, shortStem, breakPoint]
            }

        case .two:
            // LEFT: Quick Slant (break inward)
            // RIGHT: Quick Out (break right quickly)
            let shortStem = CGPoint(x: startPosition.x, y: startPosition.y - stemLength * 0.25)
            if side == .left {
                // Quick slant breaks inward (toward center)
                let breakPoint = CGPoint(x: shortStem.x + breakLen * 0.7, y: shortStem.y - breakLen * 0.5)
                return [startPosition, shortStem, breakPoint]
            } else {
                // Quick out breaks RIGHT (toward sideline for right-side receiver)
                let breakPoint = CGPoint(x: shortStem.x + breakLen, y: shortStem.y)
                return [startPosition, shortStem, breakPoint]
            }

        case .three:
            // ALWAYS breaks LEFT at 90 degrees (Out route breaking left)
            let breakPoint = CGPoint(x: stemEnd.x - breakLen, y: stemEnd.y)
            return [startPosition, stemEnd, breakPoint]

        case .four:
            // ALWAYS breaks RIGHT at 90 degrees (Dig/In route breaking right)
            let breakPoint = CGPoint(x: stemEnd.x + breakLen, y: stemEnd.y)
            return [startPosition, stemEnd, breakPoint]

        case .five:
            // LEFT: Comeback (stem up, break back down-left)
            // RIGHT: Curl (stem up, curl back down toward center)
            if side == .left {
                let breakPoint = CGPoint(x: stemEnd.x - breakLen * 0.4, y: stemEnd.y + breakLen * 0.5)
                return [startPosition, stemEnd, breakPoint]
            } else {
                let breakPoint = CGPoint(x: stemEnd.x - breakLen * 0.3, y: stemEnd.y + breakLen * 0.4)
                return [startPosition, stemEnd, breakPoint]
            }

        case .six:
            // LEFT: Curl (stem up, curl back down toward center)
            // RIGHT: Comeback (stem up, break back down-right)
            if side == .left {
                let breakPoint = CGPoint(x: stemEnd.x + breakLen * 0.3, y: stemEnd.y + breakLen * 0.4)
                return [startPosition, stemEnd, breakPoint]
            } else {
                let breakPoint = CGPoint(x: stemEnd.x + breakLen * 0.4, y: stemEnd.y + breakLen * 0.5)
                return [startPosition, stemEnd, breakPoint]
            }

        case .seven:
            // ALWAYS angles top-left (Corner route)
            let breakPoint = CGPoint(x: stemEnd.x - breakLen * 0.7, y: stemEnd.y - breakLen * 0.7)
            return [startPosition, stemEnd, breakPoint]

        case .eight:
            // ALWAYS angles top-right (Post route)
            let breakPoint = CGPoint(x: stemEnd.x + breakLen * 0.7, y: stemEnd.y - breakLen * 0.7)
            return [startPosition, stemEnd, breakPoint]

        case .nine:
            // Straight vertical Go/Fade
            let deep = CGPoint(x: startPosition.x, y: startPosition.y - stemLength * 1.5)
            return [startPosition, deep]
        }
    }

    /// Compute Y's final position after motion is applied.
    /// Y's final position depends on motion type and final side:
    /// - **stop**: Y stays close to its original position (same side, minor offset toward tackle)
    /// - **after**: Y moves dramatically to opposite side, well past the tackle
    ///
    /// - Parameters:
    ///   - initialSide: The side Y aligns on in the formation
    ///   - finalSide: The side Y ends up on after motion (from motion.finalSide logic)
    ///   - motion: The motion type (determines endpoint distance)
    ///   - formation: The formation context (affects tackle position)
    ///   - config: Diagram configuration
    /// - Returns: The final X position for Y at the line of scrimmage
    func yFinalPosition(
        initialSide: FieldSide,
        finalSide: FieldSide,
        motion: ReceiverMotion?,
        formation: Formation,
        config: DiagramConfig
    ) -> CGPoint {
        let centerX = config.fieldWidth / 2
        let losY = config.lineOfScrimmageY
        let basePositions = receiverPositions(formation: formation, config: config)

        guard let yBasePos = basePositions[.Y] else { return CGPoint(x: centerX, y: losY) }

        // If no motion or final side is the same as initial, return base position
        if motion == nil || initialSide == finalSide {
            return yBasePos
        }

        // Motion-based endpoint calculation for side changes
        guard let motion = motion, initialSide != finalSide else {
            return yBasePos
        }

        let baseDistance = abs(yBasePos.x - centerX)

        // Y After/Go: moves dramatically past tackle on opposite side
        // Double the distance for dramatic effect
        let dramaticDistance = baseDistance * 2.5
        let finalX = (finalSide == .right) ? centerX + dramaticDistance : centerX - dramaticDistance
        return CGPoint(x: finalX, y: losY)
    }

    /// Compute a smooth arc path from initial to final position for motion visualization.
    /// Arc geometry depends on motion type:
    /// - Y Stop: Arc curves inward (convex toward field center) — Y stays same side
    /// - Y After: Arc curves outward (convex away from field center) — Y moves to opposite side
    func motionPath(
        for receiver: Receiver,
        motion: ReceiverMotion?,
        from: CGPoint,
        to: CGPoint,
        config: DiagramConfig
    ) -> [CGPoint] {
        guard let motion = motion else { return [] }
        guard from != to else { return [] }

        // Compute control point for arc curvature
        let midX = (from.x + to.x) / 2
        let midY = (from.y + to.y) / 2
        let distance = hypot(to.x - from.x, to.y - from.y)
        let arcDepth = distance * 0.25

        let centerX = config.fieldWidth / 2

        // Curve outward (away from field center) — Y moves to opposite side
        let outwardDir = (midX > centerX) ? 1.0 : -1.0
        let controlPoint = CGPoint(x: midX + outwardDir * arcDepth, y: midY - arcDepth * 0.5)

        // Sample points along quadratic Bézier curve
        var pathPoints: [CGPoint] = []
        for t in stride(from: CGFloat(0), through: CGFloat(1), by: 0.05) {
            let point = quadraticBezier(p0: from, control: controlPoint, p1: to, t: t)
            pathPoints.append(point)
        }
        return pathPoints
    }

    /// Quadratic Bézier curve interpolation.
    private func quadraticBezier(p0: CGPoint, control: CGPoint, p1: CGPoint, t: CGFloat) -> CGPoint {
        let mt = 1 - t
        let mt2 = mt * mt
        let t2 = t * t
        return CGPoint(
            x: mt2 * p0.x + 2 * mt * t * control.x + t2 * p1.x,
            y: mt2 * p0.y + 2 * mt * t * control.y + t2 * p1.y
        )
    }

    /// Dispatch to appropriate motion rendering based on yWheelEnabled and motion state.
    /// If wheel is enabled, always render wheel arc.
    /// Otherwise, render base motion arc if motion is selected.
    ///
    /// - Parameters:
    ///   - playCall: The play call containing formation, motion, and wheel state
    ///   - config: Diagram configuration
    /// - Returns: A tuple of (path, color) or nil if no motion/wheel to render
    func motionPathForPlayCall(for playCall: PlayCall, config: DiagramConfig) -> (Path, Color)? {
        // If wheel is enabled, always render wheel arc
        if playCall.yWheelEnabled {
            return yWheelArcPath(for: playCall, config: config)
        }

        // Otherwise, no motion/wheel to render (the receiver motion arcs are drawn separately in the view)
        return nil
    }

    /// Compute Y wheel arc path: semi-circular motion behind formation, same-side exit.
    /// Y wheel is a semi-circle arc that goes:
    /// 1. Back (away from LOS) half the field width
    /// 2. Down the sideline (away from center)
    /// 3. Arc curves behind X/A receivers
    ///
    /// - Parameters:
    ///   - playCall: The play call containing formation and route assignments
    ///   - config: Diagram configuration
    /// - Returns: A tuple of (path, color) where path is a SwiftUI Path and color is the stroke color (yellow)
    func yWheelArcPath(for playCall: PlayCall, config: DiagramConfig) -> (Path, Color) {
        let positions = receiverPositions(formation: playCall.formation, config: config)
        guard let yPosition = positions[.Y] else {
            // Y not in formation (shouldn't happen, but handle gracefully)
            return (Path(), .yellow)
        }

        let yAssignment = playCall.assignments.first { $0.receiver == .Y }
        let side = yAssignment?.side ?? playCall.formation.side(for: .Y)

        var path = Path()
        path.move(to: yPosition)

        // Create U-shaped loop: starts at Y, goes back (away from LOS), then curves back toward LOS
        let loopDepth = config.fieldHeight * 0.12  // How far back the U goes
        let sideOffset = config.fieldWidth * 0.04  // Slight offset to side for the curve

        let controlPoint1: CGPoint
        let controlPoint2: CGPoint
        let endPoint: CGPoint

        if side == .left {
            // Left-side Y wheel: U-shape that stays on left side
            controlPoint1 = CGPoint(
                x: yPosition.x - sideOffset,
                y: yPosition.y + loopDepth
            )
            controlPoint2 = CGPoint(
                x: yPosition.x - sideOffset,
                y: yPosition.y + loopDepth
            )
            endPoint = CGPoint(
                x: yPosition.x,
                y: yPosition.y
            )
        } else {
            // Right-side Y wheel: U-shape that stays on right side
            controlPoint1 = CGPoint(
                x: yPosition.x + sideOffset,
                y: yPosition.y + loopDepth
            )
            controlPoint2 = CGPoint(
                x: yPosition.x + sideOffset,
                y: yPosition.y + loopDepth
            )
            endPoint = CGPoint(
                x: yPosition.x,
                y: yPosition.y
            )
        }

        // Draw cubic Bézier curve for U-shaped loop
        path.addCurve(
            to: endPoint,
            control1: controlPoint1,
            control2: controlPoint2
        )

        return (path, .yellow)
    }
}
