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
            lineOfScrimmageY: height * 0.75,
            routeLength: height * 0.25,
            breakLength: height * 0.15,
            receiverRadius: 12,
            footballSize: 10,
            receiverSpacing: width * 0.12,
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
    func routePath(for assignment: RouteAssignment, startPosition: CGPoint, config: DiagramConfig) -> [CGPoint] {
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
            if assignment.side == .left {
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
            if assignment.side == .left {
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
            if assignment.side == .left {
                let breakPoint = CGPoint(x: stemEnd.x - breakLen * 0.4, y: stemEnd.y + breakLen * 0.5)
                return [startPosition, stemEnd, breakPoint]
            } else {
                let breakPoint = CGPoint(x: stemEnd.x - breakLen * 0.3, y: stemEnd.y + breakLen * 0.4)
                return [startPosition, stemEnd, breakPoint]
            }

        case .six:
            // LEFT: Curl (stem up, curl back down toward center)
            // RIGHT: Comeback (stem up, break back down-right)
            if assignment.side == .left {
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
}
