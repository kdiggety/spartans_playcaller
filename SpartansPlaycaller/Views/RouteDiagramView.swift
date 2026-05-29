import SwiftUI

/// Canvas-based route diagram renderer.
/// Draws the field, receivers at their formation positions, and route paths.
struct RouteDiagramView: View {
    let playCall: PlayCall

    private let renderer = DiagramRenderer()

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let config = DiagramConfig.standard(for: size)
                let positions = renderer.receiverPositions(formation: playCall.formation, config: config)

                drawField(context: &context, config: config, size: size)
                drawFootball(context: &context, config: config)
                drawMotion(context: &context, config: config, positions: positions)
                drawRoutes(context: &context, config: config, positions: positions)
                drawReceivers(context: &context, config: config, positions: positions)
            }
        }
        .background(Color(white: 0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Drawing Methods

    private func drawMotion(context: inout GraphicsContext, config: DiagramConfig, positions: [Receiver: CGPoint]) {
        for assignment in playCall.assignments {
            guard assignment.receiver == .Y else { continue }
            guard let motion = assignment.motion else { continue }
            guard let initialPos = positions[.Y] else { continue }

            // Compute Y's final position after motion
            let finalPos = renderer.yFinalPosition(
                initialSide: assignment.side,
                finalSide: assignment.motionFinalSide,
                motion: motion,
                formation: playCall.formation,
                config: config
            )

            // Get motion arc
            let arcPoints = renderer.motionPath(
                for: .Y,
                motion: motion,
                from: initialPos,
                to: finalPos,
                config: config
            )

            guard arcPoints.count >= 2 else { continue }

            // Draw dashed arc
            let motionPath = Path { path in
                path.move(to: arcPoints[0])
                for i in 1..<arcPoints.count {
                    path.addLine(to: arcPoints[i])
                }
            }

            context.stroke(
                motionPath,
                with: .color(.yellow.opacity(0.4)),
                style: StrokeStyle(
                    lineWidth: 2.5,
                    lineCap: .round,
                    lineJoin: .round,
                    dash: [4, 4]
                )
            )
        }
    }

    private func drawField(context: inout GraphicsContext, config: DiagramConfig, size: CGSize) {
        // Line of scrimmage
        let losPath = Path { path in
            path.move(to: CGPoint(x: 0, y: config.lineOfScrimmageY))
            path.addLine(to: CGPoint(x: config.fieldWidth, y: config.lineOfScrimmageY))
        }
        context.stroke(losPath, with: .color(.white.opacity(0.3)), lineWidth: 1.5)

        // Yard lines (decorative)
        for i in 1...3 {
            let y = config.lineOfScrimmageY - CGFloat(i) * (config.fieldHeight * 0.15)
            if y > 0 {
                let yardLine = Path { path in
                    path.move(to: CGPoint(x: config.sideMargin, y: y))
                    path.addLine(to: CGPoint(x: config.fieldWidth - config.sideMargin, y: y))
                }
                context.stroke(yardLine, with: .color(.white.opacity(0.1)), style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
            }
        }
    }

    private func drawFootball(context: inout GraphicsContext, config: DiagramConfig) {
        let center = CGPoint(x: config.fieldWidth / 2, y: config.lineOfScrimmageY + 20)
        let footballRect = CGRect(
            x: center.x - config.footballSize,
            y: center.y - config.footballSize * 0.6,
            width: config.footballSize * 2,
            height: config.footballSize * 1.2
        )
        let footballPath = Path(ellipseIn: footballRect)
        context.fill(footballPath, with: .color(.brown))
        context.stroke(footballPath, with: .color(.white.opacity(0.6)), lineWidth: 1)
    }

    private func drawRoutes(context: inout GraphicsContext, config: DiagramConfig, positions: [Receiver: CGPoint]) {
        for assignment in playCall.assignments {
            guard let initialPos = positions[assignment.receiver] else { continue }

            // For Y receiver with motion, compute the final position; otherwise use initial position
            let routeStartPos: CGPoint
            if assignment.receiver == .Y, assignment.motion != nil {
                routeStartPos = renderer.yFinalPosition(
                    initialSide: assignment.side,
                    finalSide: assignment.motionFinalSide,
                    motion: assignment.motion,
                    formation: playCall.formation,
                    config: config
                )
            } else {
                routeStartPos = initialPos
            }

            // Use the final side (which accounts for motion) for route interpretation
            let pathPoints = renderer.routePath(
                for: assignment,
                startPosition: routeStartPos,
                side: assignment.motionFinalSide,
                config: config
            )

            guard pathPoints.count >= 2 else { continue }

            let routePath = Path { path in
                path.move(to: pathPoints[0])
                for i in 1..<pathPoints.count {
                    path.addLine(to: pathPoints[i])
                }
            }

            let color = routeColor(for: assignment.receiver)
            context.stroke(routePath, with: .color(color), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

            // Arrow at end of route
            if let last = pathPoints.last, pathPoints.count >= 2 {
                let prev = pathPoints[pathPoints.count - 2]
                drawArrow(context: &context, from: prev, to: last, color: color)
            }
        }
    }

    private func drawReceivers(context: inout GraphicsContext, config: DiagramConfig, positions: [Receiver: CGPoint]) {
        for assignment in playCall.assignments {
            guard let pos = positions[assignment.receiver] else { continue }

            // Receiver circle
            let circle = Path(ellipseIn: CGRect(
                x: pos.x - config.receiverRadius,
                y: pos.y - config.receiverRadius,
                width: config.receiverRadius * 2,
                height: config.receiverRadius * 2
            ))

            let color = routeColor(for: assignment.receiver)
            context.fill(circle, with: .color(color.opacity(0.2)))
            context.stroke(circle, with: .color(color), lineWidth: 2)

            // Label: "X (6)"
            let label = "\(assignment.receiver.rawValue) (\(assignment.routeNumber.rawValue))"
            let text = Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            context.draw(text, at: CGPoint(x: pos.x, y: pos.y + config.receiverRadius + 12))
        }
    }

    private func drawArrow(context: inout GraphicsContext, from: CGPoint, to: CGPoint, color: Color) {
        let angle = atan2(to.y - from.y, to.x - from.x)
        let arrowLength: CGFloat = 8
        let arrowAngle: CGFloat = .pi / 6

        let arrow = Path { path in
            path.move(to: to)
            path.addLine(to: CGPoint(
                x: to.x - arrowLength * cos(angle - arrowAngle),
                y: to.y - arrowLength * sin(angle - arrowAngle)
            ))
            path.move(to: to)
            path.addLine(to: CGPoint(
                x: to.x - arrowLength * cos(angle + arrowAngle),
                y: to.y - arrowLength * sin(angle + arrowAngle)
            ))
        }

        context.stroke(arrow, with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round))
    }

    private func routeColor(for receiver: Receiver) -> Color {
        switch receiver {
        case .X: return .cyan
        case .Y: return .yellow
        case .Z: return .green
        case .A: return .orange
        case .H: return .pink
        }
    }
}
