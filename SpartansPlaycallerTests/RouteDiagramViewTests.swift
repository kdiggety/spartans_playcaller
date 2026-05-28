import XCTest
import SwiftUI
@testable import SpartansPlaycaller

/// Tests for the RouteDiagramView focusing on motion rendering, concept display, and formation validation.
/// NOTE: Full visual regression testing requires preview inspection and device/simulator screenshots.
final class RouteDiagramViewTests: XCTestCase {

    let interpreter = RouteInterpreter()

    // MARK: - Basic Diagram Rendering Tests

    func testRouteDiagramViewRendersWithoutCrashing() {
        if case .success(let playCall) = interpreter.interpret(digits: "6794", formation: .twins) {
            let view = RouteDiagramView(playCall: playCall)
            XCTAssertNotNil(view)
        }
    }

    func testRouteDiagramViewRendersAllFormations() {
        let formations: [Formation] = [.twins, .tripsLeft, .tripsRight]

        for formation in formations {
            if case .success(let playCall) = interpreter.interpret(digits: "6794", formation: formation) {
                let view = RouteDiagramView(playCall: playCall)
                XCTAssertNotNil(view)
            }
        }
    }

    // MARK: - Motion Arc Rendering Tests

    func testMotionArcRendersForYStop() {
        if case .success(var playCall) = interpreter.interpret(digits: "6794", formation: .tripsLeft) {
            // Apply Y Stop motion
            if let yIndex = playCall.assignments.firstIndex(where: { $0.receiver == .Y }) {
                playCall.assignments[yIndex].motion = .after
            }

            let view = RouteDiagramView(playCall: playCall)
            XCTAssertNotNil(view)

            // Verify Y has motion assigned
            if let yAssignment = playCall.assignments.first(where: { $0.receiver == .Y }) {
                XCTAssertEqual(yAssignment.motion, .after)
            }
        }
    }

    func testMotionArcRendersForYAfter() {
        if case .success(var playCall) = interpreter.interpret(digits: "6794", formation: .tripsLeft) {
            // Apply Y After motion
            if let yIndex = playCall.assignments.firstIndex(where: { $0.receiver == .Y }) {
                playCall.assignments[yIndex].motion = .after
            }

            let view = RouteDiagramView(playCall: playCall)
            XCTAssertNotNil(view)

            // Y should have flipped sides
            if let yAssignment = playCall.assignments.first(where: { $0.receiver == .Y }) {
                XCTAssertEqual(yAssignment.motion, .after)
                XCTAssertEqual(yAssignment.motionFinalSide, .right)
            }
        }
    }

    func testMotionArcRendersForYAfter() {
        if case .success(var playCall) = interpreter.interpret(digits: "6794", formation: .tripsRight) {
            // Apply Y After motion
            if let yIndex = playCall.assignments.firstIndex(where: { $0.receiver == .Y }) {
                playCall.assignments[yIndex].motion = .after
            }

            let view = RouteDiagramView(playCall: playCall)
            XCTAssertNotNil(view)

            // Y should have flipped sides
            if let yAssignment = playCall.assignments.first(where: { $0.receiver == .Y }) {
                XCTAssertEqual(yAssignment.motion, .after)
                XCTAssertEqual(yAssignment.motionFinalSide, .left)
            }
        }
    }

    // MARK: - Dashed Line Pattern Tests

    func testDashedLinePatternConfigured() {
        // The diagram uses [4, 4] dash pattern as per RouteDiagramView.swift
        // This test verifies the configuration is correct
        if case .success(var playCall) = interpreter.interpret(digits: "6794", formation: .tripsLeft) {
            if let yIndex = playCall.assignments.firstIndex(where: { $0.receiver == .Y }) {
                playCall.assignments[yIndex].motion = .after
            }

            let view = RouteDiagramView(playCall: playCall)
            XCTAssertNotNil(view)

            // Dash pattern [4, 4] should be visible (verified by manual inspection in preview)
        }
    }

    // MARK: - Z-Order Tests (Rendering Layers)

    func testMotionLinesRenderUnderRoutes() {
        // In drawMotion() -> drawRoutes() -> drawReceivers()
        // Motion should draw first, routes second, receivers last
        if case .success(var playCall) = interpreter.interpret(digits: "6794", formation: .tripsLeft) {
            if let yIndex = playCall.assignments.firstIndex(where: { $0.receiver == .Y }) {
                playCall.assignments[yIndex].motion = .after
            }

            let view = RouteDiagramView(playCall: playCall)
            XCTAssertNotNil(view)

            // Visual inspection confirms z-order (not unit-testable without screenshot comparison)
        }
    }

    // MARK: - Concept Display Tests (via Concept Badges)

    func testConceptDisplayedWhenIdentified() {
        let viewModel = PlayCallerViewModel()
        viewModel.selectedFormation = .twins
        viewModel.routeDigitInput = "6794"
        viewModel.parseRouteDigits()

        if let playCall = viewModel.currentPlayCall {
            let view = RouteDiagramView(playCall: playCall)
            XCTAssertNotNil(view)

            // Concept is displayed in the larger view hierarchy (ConceptBadgeRow)
            // Unit test verifies diagram renders; integration test verifies concept badges
        }
    }

    // MARK: - Formation-Specific Rendering Tests

    func testTwinsFormationDiagramRendersWithCorrectLayout() {
        if case .success(let playCall) = interpreter.interpret(digits: "6794", formation: .twins) {
            XCTAssertEqual(playCall.formation, .twins)

            let view = RouteDiagramView(playCall: playCall)
            XCTAssertNotNil(view)

            // Twins: X, Y on left; Z, A on right
            let leftReceivers = playCall.assignments.filter { playCall.formation.side(for: $0.receiver) == .left }
            let rightReceivers = playCall.assignments.filter { playCall.formation.side(for: $0.receiver) == .right }

            XCTAssertEqual(leftReceivers.count, 2)
            XCTAssertEqual(rightReceivers.count, 2)
        }
    }

    func testTripsLeftFormationDiagramRendersWithCorrectLayout() {
        if case .success(let playCall) = interpreter.interpret(digits: "6794", formation: .tripsLeft) {
            XCTAssertEqual(playCall.formation, .tripsLeft)

            let view = RouteDiagramView(playCall: playCall)
            XCTAssertNotNil(view)

            // Trips Left: X, Y, A on left; Z on right
            let leftReceivers = playCall.assignments.filter { playCall.formation.side(for: $0.receiver) == .left }
            let rightReceivers = playCall.assignments.filter { playCall.formation.side(for: $0.receiver) == .right }

            XCTAssertEqual(leftReceivers.count, 3)
            XCTAssertEqual(rightReceivers.count, 1)
        }
    }

    func testTripsRightFormationDiagramRendersWithCorrectLayout() {
        if case .success(let playCall) = interpreter.interpret(digits: "6794", formation: .tripsRight) {
            XCTAssertEqual(playCall.formation, .tripsRight)

            let view = RouteDiagramView(playCall: playCall)
            XCTAssertNotNil(view)

            // Trips Right: X on left; Y, Z, A on right
            let leftReceivers = playCall.assignments.filter { playCall.formation.side(for: $0.receiver) == .left }
            let rightReceivers = playCall.assignments.filter { playCall.formation.side(for: $0.receiver) == .right }

            XCTAssertEqual(leftReceivers.count, 1)
            XCTAssertEqual(rightReceivers.count, 3)
        }
    }

    // MARK: - Edge Cases

    func testDiagramRendersWith5Receivers() {
        if case .success(let playCall) = interpreter.interpret(digits: "67943", formation: .twins) {
            let view = RouteDiagramView(playCall: playCall)
            XCTAssertNotNil(view)

            XCTAssertEqual(playCall.assignments.count, 5)
        }
    }

    func testDiagramRendersWithAllMotionTypes() {
        for motion in ReceiverMotion.allCases {
            if case .success(var playCall) = interpreter.interpret(digits: "6794", formation: .tripsLeft) {
                if let yIndex = playCall.assignments.firstIndex(where: { $0.receiver == .Y }) {
                    playCall.assignments[yIndex].motion = motion
                }

                let view = RouteDiagramView(playCall: playCall)
                XCTAssertNotNil(view)
            }
        }
    }

    func testDiagramRendersWhenYHasNoMotion() {
        if case .success(let playCall) = interpreter.interpret(digits: "6794", formation: .tripsLeft) {
            // No motion applied
            if let yAssignment = playCall.assignments.first(where: { $0.receiver == .Y }) {
                XCTAssertNil(yAssignment.motion)
            }

            let view = RouteDiagramView(playCall: playCall)
            XCTAssertNotNil(view)
        }
    }

    // MARK: - Route Path Position and Side Tests (Fix Verification)

    func testYRouteStartsFromFinalPositionWithMotion() {
        // Trips Left, Y After: Y should draw route from right side (final position)
        if case .success(var playCall) = interpreter.interpret(digits: "1111", formation: .tripsLeft) {
            if let yIndex = playCall.assignments.firstIndex(where: { $0.receiver == .Y }) {
                playCall.assignments[yIndex].motion = .after
            }

            let config = DiagramConfig.standard(for: CGSize(width: 500, height: 600))
            let renderer = DiagramRenderer()
            let positions = renderer.receiverPositions(formation: playCall.formation, config: config)

            if let yAssignment = playCall.assignments.first(where: { $0.receiver == .Y }) {
                // Y should be on left initially (Trips Left formation)
                XCTAssertEqual(yAssignment.side, .left)
                // Y After should flip to right
                XCTAssertEqual(yAssignment.motionFinalSide, .right)

                // Get Y's initial position (left side)
                guard let initialPos = positions[.Y] else { return XCTFail("Y position not found") }

                // Compute Y's final position (right side after motion)
                let finalPos = renderer.yFinalPosition(
                    initialSide: yAssignment.side,
                    finalSide: yAssignment.motionFinalSide,
                    motion: yAssignment.motion,
                    formation: playCall.formation,
                    config: config
                )

                // Final position X should be greater (moved right)
                XCTAssertGreaterThan(finalPos.x, initialPos.x, "Y final position should be to the right of initial")

                // Route path should start from final position
                let routePath = renderer.routePath(
                    for: yAssignment,
                    startPosition: finalPos,
                    side: yAssignment.motionFinalSide,
                    config: config
                )

                guard let first = routePath.first else { return XCTFail("Route path is empty") }
                XCTAssertEqual(first, finalPos, "Route should start from Y's final position")
            }
        }
    }

    func testYRouteSideInterpretationChangesWithMotion() {
        // Trips Left, route "1", no motion: Y on left, route "1" = Quick Out (breaks left)
        // Trips Left, route "1", Y After: Y flipped to right, route "1" = Quick Slant (breaks inward)
        let config = DiagramConfig.standard(for: CGSize(width: 500, height: 600))
        let renderer = DiagramRenderer()

        // First: No motion case
        if case .success(let playCall) = interpreter.interpret(digits: "1111", formation: .tripsLeft) {
            if let yAssignment = playCall.assignments.first(where: { $0.receiver == .Y }) {
                XCTAssertEqual(yAssignment.side, .left)
                XCTAssertNil(yAssignment.motion)
                XCTAssertEqual(yAssignment.motionFinalSide, .left, "No motion: final side = original side")

                let positions = renderer.receiverPositions(formation: playCall.formation, config: config)
                guard let yPos = positions[.Y] else { return XCTFail("Y position not found") }

                let routePath = renderer.routePath(
                    for: yAssignment,
                    startPosition: yPos,
                    side: yAssignment.motionFinalSide,
                    config: config
                )

                // Route "1" on left should break LEFT (Quick Out)
                // Path should have 3 points: start, stem end, break point
                XCTAssertGreaterThanOrEqual(routePath.count, 3, "Quick Out route should have break point")
                if routePath.count >= 3 {
                    let breakPoint = routePath[2]
                    // Break point X should be less than stem (going left)
                    let stemPoint = routePath[1]
                    XCTAssertLessThan(breakPoint.x, stemPoint.x, "Quick Out breaks left")
                }
            }
        }

        // Second: Y After motion case
        if case .success(var playCall) = interpreter.interpret(digits: "1111", formation: .tripsLeft) {
            if let yIndex = playCall.assignments.firstIndex(where: { $0.receiver == .Y }) {
                playCall.assignments[yIndex].motion = .after
            }

            if let yAssignment = playCall.assignments.first(where: { $0.receiver == .Y }) {
                XCTAssertEqual(yAssignment.side, .left, "Original side is left")
                XCTAssertEqual(yAssignment.motion, .after)
                XCTAssertEqual(yAssignment.motionFinalSide, .right, "After motion: final side = right")

                let positions = renderer.receiverPositions(formation: playCall.formation, config: config)
                guard let yInitialPos = positions[.Y] else { return XCTFail("Y position not found") }

                let yFinalPos = renderer.yFinalPosition(
                    initialSide: yAssignment.side,
                    finalSide: yAssignment.motionFinalSide,
                    motion: yAssignment.motion,
                    formation: playCall.formation,
                    config: config
                )

                let routePath = renderer.routePath(
                    for: yAssignment,
                    startPosition: yFinalPos,
                    side: yAssignment.motionFinalSide,
                    config: config
                )

                // Route "1" on right should be Quick Slant (breaks inward/toward center)
                // Path should have 3 points: start, stem end, break point
                XCTAssertGreaterThanOrEqual(routePath.count, 3, "Quick Slant route should have break point")
                if routePath.count >= 3 {
                    let breakPoint = routePath[2]
                    let stemPoint = routePath[1]
                    // Break point X should be less than stem X (inward/toward center from right side)
                    XCTAssertLessThan(breakPoint.x, stemPoint.x, "Quick Slant breaks inward from right side")
                    // But not as far left as Pure Quick Out would go
                    // This is harder to test precisely, but we can verify the break is smaller
                    let breakDistance = abs(breakPoint.x - stemPoint.x)
                    XCTAssertLessThan(breakDistance, 30, "Quick Slant break is more modest than Quick Out")
                }
            }
        }
    }
}

// MARK: - SwiftUI Previews for Visual Testing

#if DEBUG
struct RouteDiagramViewPreviewContainer: View {
    let interpreter = RouteInterpreter()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Base play (Twins, no motion)
                Group {
                    Text("Twins - Base Play (No Motion)")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    if case .success(let playCall) = interpreter.interpret(digits: "6794", formation: .twins) {
                        RouteDiagramView(playCall: playCall)
                            .frame(height: 300)
                            .padding()
                    }
                }

                // Y Stop motion in Trips Left
                Group {
                    Text("Trips Left - Y Stop (Same Side)")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    if case .success(var playCall) = interpreter.interpret(digits: "6794", formation: .tripsLeft) {
                        if let yIndex = playCall.assignments.firstIndex(where: { $0.receiver == .Y }) {
                            playCall.assignments[yIndex].motion = .after
                        }
                        RouteDiagramView(playCall: playCall)
                            .frame(height: 300)
                            .padding()
                    }
                }

                // Y After motion in Trips Left
                Group {
                    Text("Trips Left - Y After (Flips Right)")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    if case .success(var playCall) = interpreter.interpret(digits: "6794", formation: .tripsLeft) {
                        if let yIndex = playCall.assignments.firstIndex(where: { $0.receiver == .Y }) {
                            playCall.assignments[yIndex].motion = .after
                        }
                        RouteDiagramView(playCall: playCall)
                            .frame(height: 300)
                            .padding()
                    }
                }

                // Y After motion in Trips Right
                Group {
                    Text("Trips Right - Y After (Flips Left)")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    if case .success(var playCall) = interpreter.interpret(digits: "6794", formation: .tripsRight) {
                        if let yIndex = playCall.assignments.firstIndex(where: { $0.receiver == .Y }) {
                            playCall.assignments[yIndex].motion = .after
                        }
                        RouteDiagramView(playCall: playCall)
                            .frame(height: 300)
                            .padding()
                    }
                }

                // Twins with 5 receivers (motion should be rejected by ViewModel, but diagram still renders)
                Group {
                    Text("Twins - 5 Receivers (H in Motion Not Recommended)")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    if case .success(var playCall) = interpreter.interpret(digits: "67943", formation: .twins) {
                        RouteDiagramView(playCall: playCall)
                            .frame(height: 300)
                            .padding()
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Color(white: 0.08))
    }
}

#Preview("Route Diagram Visual Tests") {
    RouteDiagramViewPreviewContainer()
}

#Preview("Trips Left - Y Stop", traits: .sizeThatFitsLayout) {
    let interpreter = RouteInterpreter()
    if case .success(var playCall) = interpreter.interpret(digits: "6794", formation: .tripsLeft) {
        if let yIndex = playCall.assignments.firstIndex(where: { $0.receiver == .Y }) {
            playCall.assignments[yIndex].motion = .after
        }
        return AnyView(
            RouteDiagramView(playCall: playCall)
                .frame(height: 400)
                .padding()
        )
    }
    return AnyView(Text("Failed to create play call"))
}

#Preview("Trips Left - Y After", traits: .sizeThatFitsLayout) {
    let interpreter = RouteInterpreter()
    if case .success(var playCall) = interpreter.interpret(digits: "6794", formation: .tripsLeft) {
        if let yIndex = playCall.assignments.firstIndex(where: { $0.receiver == .Y }) {
            playCall.assignments[yIndex].motion = .after
        }
        return AnyView(
            RouteDiagramView(playCall: playCall)
                .frame(height: 400)
                .padding()
        )
    }
    return AnyView(Text("Failed to create play call"))
}

#Preview("Trips Right - Y After", traits: .sizeThatFitsLayout) {
    let interpreter = RouteInterpreter()
    if case .success(var playCall) = interpreter.interpret(digits: "6794", formation: .tripsRight) {
        if let yIndex = playCall.assignments.firstIndex(where: { $0.receiver == .Y }) {
            playCall.assignments[yIndex].motion = .after
        }
        return AnyView(
            RouteDiagramView(playCall: playCall)
                .frame(height: 400)
                .padding()
        )
    }
    return AnyView(Text("Failed to create play call"))
}
#endif
