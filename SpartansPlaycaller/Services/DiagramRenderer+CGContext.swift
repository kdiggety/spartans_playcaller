import UIKit
import CoreGraphics

extension DiagramRenderer {

    /// Draw the full route diagram into an arbitrary CGContext.
    /// The context must be in screen coordinates (Y-down from top) — both CatalogPDFPage
    /// and WristbandPDFPage flip the context before calling this method.
    /// `rect` is the bounding box in the context's coordinate system.
    /// `config` must be built from `rect.size` (fieldWidth = rect.width, fieldHeight = rect.height).
    func draw(into context: CGContext, playCall: PlayCall, config: DiagramConfig, in rect: CGRect) {
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.minY)

        let positions = receiverPositions(formation: playCall.formation, config: config)

        drawFieldCG(context, config: config)
        drawFootballCG(context, config: config)
        drawMotionCG(context, assignments: playCall.assignments, positions: positions, formation: playCall.formation, config: config)
        if playCall.yWheelEnabled {
            drawWheelCG(context, playCall: playCall, config: config)
        }
        drawRoutesCG(context, assignments: playCall.assignments, positions: positions, playCall: playCall, config: config)
        drawReceiversCG(context, assignments: playCall.assignments, positions: positions, config: config)

        context.restoreGState()
    }

    // MARK: - Private CG draw helpers

    private func drawFieldCG(_ context: CGContext, config: DiagramConfig) {
        // Line of scrimmage
        context.setStrokeColor(UIColor.black.withAlphaComponent(0.25).cgColor)
        context.setLineWidth(1.0)
        context.move(to: CGPoint(x: 0, y: config.lineOfScrimmageY))
        context.addLine(to: CGPoint(x: config.fieldWidth, y: config.lineOfScrimmageY))
        context.strokePath()

        // Decorative yard lines (dashed, subtle)
        context.setStrokeColor(UIColor.black.withAlphaComponent(0.08).cgColor)
        context.setLineWidth(0.4)
        context.setLineDash(phase: 0, lengths: [3, 3])
        for i in 1...2 {
            let y = config.lineOfScrimmageY - CGFloat(i) * (config.fieldHeight * 0.18)
            if y > 0 {
                context.move(to: CGPoint(x: config.sideMargin, y: y))
                context.addLine(to: CGPoint(x: config.fieldWidth - config.sideMargin, y: y))
                context.strokePath()
            }
        }
        context.setLineDash(phase: 0, lengths: [])
    }

    private func drawFootballCG(_ context: CGContext, config: DiagramConfig) {
        let center = CGPoint(x: config.fieldWidth / 2, y: config.lineOfScrimmageY + config.footballSize * 1.5)
        let rect = CGRect(
            x: center.x - config.footballSize,
            y: center.y - config.footballSize * 0.6,
            width: config.footballSize * 2,
            height: config.footballSize * 1.2
        )
        context.setFillColor(UIColor.brown.cgColor)
        context.fillEllipse(in: rect)
    }

    private func drawMotionCG(_ context: CGContext, assignments: [RouteAssignment], positions: [Receiver: CGPoint], formation: Formation, config: DiagramConfig) {
        for assignment in assignments {
            guard assignment.receiver == .Y, let motion = assignment.motion else { continue }
            guard let initialPos = positions[.Y] else { continue }
            let finalPos = yFinalPosition(
                initialSide: assignment.side,
                finalSide: assignment.motionFinalSide,
                motion: motion,
                formation: formation,
                config: config
            )
            let arcPoints = motionPath(for: .Y, motion: motion, from: initialPos, to: finalPos, config: config)
            guard arcPoints.count >= 2 else { continue }

            let path = CGMutablePath()
            path.move(to: arcPoints[0])
            for i in 1..<arcPoints.count { path.addLine(to: arcPoints[i]) }

            context.setStrokeColor(UIColor.systemOrange.withAlphaComponent(0.5).cgColor)
            context.setLineWidth(1.5)
            context.setLineDash(phase: 0, lengths: [3, 3])
            context.addPath(path)
            context.strokePath()
            context.setLineDash(phase: 0, lengths: [])
        }
    }

    private func drawWheelCG(_ context: CGContext, playCall: PlayCall, config: DiagramConfig) {
        let (_, arcPoints, _) = yWheelArcPath(for: playCall, config: config)
        guard arcPoints.count >= 2 else { return }

        let path = CGMutablePath()
        path.move(to: arcPoints[0])
        for i in 1..<arcPoints.count { path.addLine(to: arcPoints[i]) }

        context.setStrokeColor(UIColor.systemYellow.withAlphaComponent(0.8).cgColor)
        context.setLineWidth(1.5)
        context.setLineCap(.round)
        context.addPath(path)
        context.strokePath()

        // Arrow at end
        drawArrowCG(context, from: arcPoints[arcPoints.count - 2], to: arcPoints.last!, color: UIColor.systemYellow.withAlphaComponent(0.8))
    }

    private func drawRoutesCG(_ context: CGContext, assignments: [RouteAssignment], positions: [Receiver: CGPoint], playCall: PlayCall, config: DiagramConfig) {
        for assignment in assignments {
            if assignment.receiver == .Y && playCall.yWheelEnabled { continue }
            guard let initialPos = positions[assignment.receiver] else { continue }

            let routeStart: CGPoint
            if assignment.receiver == .Y, assignment.motion != nil {
                routeStart = yFinalPosition(
                    initialSide: assignment.side,
                    finalSide: assignment.motionFinalSide,
                    motion: assignment.motion,
                    formation: playCall.formation,
                    config: config
                )
            } else {
                routeStart = initialPos
            }

            let pathPoints = routePath(for: assignment, startPosition: routeStart, side: assignment.motionFinalSide, config: config)
            guard pathPoints.count >= 2 else { continue }

            let cgPath = CGMutablePath()
            cgPath.move(to: pathPoints[0])
            for i in 1..<pathPoints.count { cgPath.addLine(to: pathPoints[i]) }

            let color = receiverCGColor(for: assignment.receiver)
            context.setStrokeColor(color)
            context.setLineWidth(1.5)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.addPath(cgPath)
            context.strokePath()

            if let last = pathPoints.last, pathPoints.count >= 2 {
                drawArrowCG(context, from: pathPoints[pathPoints.count - 2], to: last, color: UIColor(cgColor: color))
            }
        }
    }

    private func drawReceiversCG(_ context: CGContext, assignments: [RouteAssignment], positions: [Receiver: CGPoint], config: DiagramConfig) {
        for assignment in assignments {
            guard let pos = positions[assignment.receiver] else { continue }
            let r = config.receiverRadius
            let rect = CGRect(x: pos.x - r, y: pos.y - r, width: r * 2, height: r * 2)
            let color = UIColor(cgColor: receiverCGColor(for: assignment.receiver))

            context.setFillColor(color.withAlphaComponent(0.2).cgColor)
            context.fillEllipse(in: rect)
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(1.0)
            context.strokeEllipse(in: rect)
        }
    }

    private func drawArrowCG(_ context: CGContext, from: CGPoint, to: CGPoint, color: UIColor) {
        let angle = atan2(to.y - from.y, to.x - from.x)
        let len: CGFloat = 5
        let a: CGFloat = .pi / 6

        let arrow = CGMutablePath()
        arrow.move(to: to)
        arrow.addLine(to: CGPoint(x: to.x - len * cos(angle - a), y: to.y - len * sin(angle - a)))
        arrow.move(to: to)
        arrow.addLine(to: CGPoint(x: to.x - len * cos(angle + a), y: to.y - len * sin(angle + a)))

        context.setStrokeColor(color.cgColor)
        context.setLineWidth(1.0)
        context.addPath(arrow)
        context.strokePath()
    }

    private func receiverCGColor(for receiver: Receiver) -> CGColor {
        switch receiver {
        case .X: return UIColor.systemCyan.cgColor
        case .Y: return UIColor.systemYellow.cgColor
        case .Z: return UIColor.systemGreen.cgColor
        case .A: return UIColor.systemOrange.cgColor
        case .H: return UIColor.systemPink.cgColor
        }
    }
}
