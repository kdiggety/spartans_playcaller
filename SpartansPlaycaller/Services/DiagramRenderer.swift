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
            // Left: X (outside), A (inside)
            positions[.X] = CGPoint(x: centerX - config.receiverSpacing * 2, y: losY)
            positions[.A] = CGPoint(x: centerX - config.receiverSpacing, y: losY)
            // Right: Y (inside), Z (outside)
            positions[.Y] = CGPoint(x: centerX + config.receiverSpacing, y: losY)
            positions[.Z] = CGPoint(x: centerX + config.receiverSpacing * 2, y: losY)

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
            // Hitch: short stem straight DOWN into backfield (away from LOS)
            let shortStem = CGPoint(x: startPosition.x, y: startPosition.y + stemLength * 0.3)
            return [startPosition, shortStem]

        case .one:
            // Quick Out / Quick Slant: ALWAYS breaks LEFT visually (~45° diagonal)
            // Semantic meaning varies: LEFT=quickOut, RIGHT=quickSlant
            // Matches route 2's 45° angle formula: (-breakLen * 0.7, -breakLen * 0.5)
            let shortStem = CGPoint(x: startPosition.x, y: startPosition.y - stemLength * 0.25)
            let breakPoint = CGPoint(x: shortStem.x - breakLen * 0.7, y: shortStem.y - breakLen * 0.5)
            return [startPosition, shortStem, breakPoint]

        case .two:
            // Quick Slant / Quick Out: ALWAYS breaks RIGHT visually (~45° diagonal)
            // Semantic meaning varies: LEFT=quickSlant, RIGHT=quickOut
            let shortStem = CGPoint(x: startPosition.x, y: startPosition.y - stemLength * 0.25)
            let breakPoint = CGPoint(x: shortStem.x + breakLen * 0.7, y: shortStem.y - breakLen * 0.5)
            return [startPosition, shortStem, breakPoint]

        case .three:
            // ALWAYS breaks LEFT at 90 degrees (Out route breaking left)
            let breakPoint = CGPoint(x: stemEnd.x - breakLen, y: stemEnd.y)
            return [startPosition, stemEnd, breakPoint]

        case .four:
            // ALWAYS breaks RIGHT at 90 degrees (Dig/In route breaking right)
            let breakPoint = CGPoint(x: stemEnd.x + breakLen, y: stemEnd.y)
            return [startPosition, stemEnd, breakPoint]

        case .five:
            // Comeback / Curl: ALWAYS breaks back down-LEFT
            // LEFT=Comeback (back toward sideline), RIGHT=Curl (back toward center)
            let breakPoint = CGPoint(x: stemEnd.x - breakLen * 0.4, y: stemEnd.y + breakLen * 0.5)
            return [startPosition, stemEnd, breakPoint]

        case .six:
            // Curl / Comeback: ALWAYS breaks back down-RIGHT
            // LEFT=Curl (back toward center), RIGHT=Comeback (back toward sideline)
            let breakPoint = CGPoint(x: stemEnd.x + breakLen * 0.4, y: stemEnd.y + breakLen * 0.5)
            return [startPosition, stemEnd, breakPoint]

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

    /// Compute Y wheel arc path: U-shaped loop that starts at Y, goes back, then returns.
    /// Arc geometry:
    /// - Starts at Y's position on the line of scrimmage
    /// - Curves downward and to the side (away from LOS, into the backfield)
    /// - Smooth rounded bottom (not sharp V)
    /// - Curves back upward (returning toward the LOS)
    /// - Ends at DIFFERENT X than start (tilted arc, not symmetric U)
    /// - Final segment angles ~45° back toward LOS
    /// - Arrow points back at line of scrimmage
    /// - Smooth curved path (cubic Bézier)
    ///
    /// - Parameters:
    ///   - playCall: The play call containing formation and route assignments
    ///   - config: Diagram configuration
    /// - Returns: A tuple of (path, points for arrow, color)
    func yWheelArcPath(for playCall: PlayCall, config: DiagramConfig) -> (Path, [CGPoint], Color) {
        let positions = receiverPositions(formation: playCall.formation, config: config)
        guard let initialYPosition = positions[.Y] else {
            return (Path(), [], .yellow)
        }

        let yAssignment = playCall.assignments.first { $0.receiver == .Y }
        let initialSide = yAssignment?.side ?? playCall.formation.side(for: .Y)

        // If Y has motion, compute final position after motion is applied
        let yPosition: CGPoint
        let side: FieldSide

        if let motion = yAssignment?.motion {
            let finalSide = motion.finalSide(originalSide: initialSide)
            yPosition = yFinalPosition(
                initialSide: initialSide,
                finalSide: finalSide,
                motion: motion,
                formation: playCall.formation,
                config: config
            )
            side = finalSide
        } else {
            yPosition = initialYPosition
            side = initialSide
        }

        // Determine which route to use based on Y's final side:
        // - Y on LEFT: use Route 1 (breaks LEFT at 45°, which is toward left sideline)
        // - Y on RIGHT: use Route 2 (breaks RIGHT at 45°, which is toward right sideline)
        let routeToUse: RouteNumber = (side == .left) ? .one : .two

        // Get the semantic meaning for this route on the given side
        let initialMeaning = routeToUse.meaning(on: side)

        // Create a synthetic route assignment for Y using the selected route
        let yRouteAssignment = RouteAssignment(
            receiver: .Y,
            routeNumber: routeToUse,
            side: side,
            initialMeaning: initialMeaning,
            motion: nil  // Y Wheel itself handles motion; don't apply it again
        )

        // Call routePath() to get the rendered path points
        let pathPoints = routePath(
            for: yRouteAssignment,
            startPosition: yPosition,
            side: side,
            config: config
        )

        // Invert Y coordinates vertically so the arc goes DOWN the field (toward backfield)
        // instead of UP the field (toward goal line). Mirror about yPosition.y (the LOS).
        var invertedPoints: [CGPoint] = []
        for point in pathPoints {
            let invertedY = yPosition.y + (yPosition.y - point.y)
            invertedPoints.append(CGPoint(x: point.x, y: invertedY))
        }

        // Build path from inverted points by connecting with line segments
        var path = Path()
        if invertedPoints.count >= 2 {
            path.move(to: invertedPoints[0])
            for i in 1..<invertedPoints.count {
                path.addLine(to: invertedPoints[i])
            }
        }

        return (path, invertedPoints, .yellow)
    }
}
