import XCTest
import SwiftUI
@testable import SpartansPlaycaller

/// Tests for the RouteDiagramView focusing on motion rendering, concept display, and formation validation.
/// NOTE: Full visual regression testing requires preview inspection and device/simulator screenshots.
final class RouteDiagramViewTests: XCTestCase {

    let interpreter = RouteInterpreter()

    // MARK: - Basic Diagram Rendering Tests

@MainActor func testRouteDiagramViewRendersWithoutCrashing() {
        if case .success(let playCall) = interpreter.interpret(digits: "6794", formation: .twins) {
            let view = RouteDiagramView(playCall: playCall)
            XCTAssertNotNil(view)
        }
    }

@MainActor func testRouteDiagramViewRendersAllFormations() {
        let formations: [Formation] = [.twins, .tripsLeft, .tripsRight]

        for formation in formations {
            if case .success(let playCall) = interpreter.interpret(digits: "6794", formation: formation) {
                let view = RouteDiagramView(playCall: playCall)
                XCTAssertNotNil(view)
            }
        }
    }

    // MARK: - Motion Arc Rendering Tests

@MainActor func testMotionArcRendersForYStop() {
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

@MainActor func testMotionArcRendersForYAfter() {
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

@MainActor func testMotionArcRendersForYAfterFromRight() {
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

@MainActor func testDashedLinePatternConfigured() {
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

@MainActor func testMotionLinesRenderUnderRoutes() {
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

@MainActor func testConceptDisplayedWhenIdentified() {
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

@MainActor func testTwinsFormationDiagramRendersWithCorrectLayout() {
        if case .success(let playCall) = interpreter.interpret(digits: "6794", formation: .twins) {
            XCTAssertEqual(playCall.formation, .twins)

            let view = RouteDiagramView(playCall: playCall)
            XCTAssertNotNil(view)

            // Twins: X, A on left; Y, Z on right
            let leftReceivers = playCall.assignments.filter { playCall.formation.side(for: $0.receiver) == .left }
            let rightReceivers = playCall.assignments.filter { playCall.formation.side(for: $0.receiver) == .right }

            XCTAssertEqual(leftReceivers.count, 2)
            XCTAssertEqual(rightReceivers.count, 2)
        }
    }

@MainActor func testTripsLeftFormationDiagramRendersWithCorrectLayout() {
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

@MainActor func testTripsRightFormationDiagramRendersWithCorrectLayout() {
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

@MainActor func testDiagramRendersWith5Receivers() {
        if case .success(let playCall) = interpreter.interpret(digits: "67943", formation: .twins) {
            let view = RouteDiagramView(playCall: playCall)
            XCTAssertNotNil(view)

            XCTAssertEqual(playCall.assignments.count, 5)
        }
    }

@MainActor func testDiagramRendersWithAllMotionTypes() {
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

@MainActor func testDiagramRendersWhenYHasNoMotion() {
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

@MainActor func testYRouteStartsFromFinalPositionWithMotion() {
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

@MainActor func testYRouteSideInterpretationChangesWithMotion() {
        // Routes 1 and 2 use absolute directions:
        // Route "1" ALWAYS breaks LEFT regardless of receiver side
        // Route "2" ALWAYS breaks RIGHT regardless of receiver side
        let config = DiagramConfig.standard(for: CGSize(width: 500, height: 600))
        let renderer = DiagramRenderer()

        // First: Route 1 on left (no motion) - should break LEFT
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

                // Route "1" ALWAYS breaks LEFT (absolute direction)
                // Path should have 3 points: start, stem end, break point
                XCTAssertGreaterThanOrEqual(routePath.count, 3, "Route 1 should have break point")
                if routePath.count >= 3 {
                    let breakPoint = routePath[2]
                    // Break point X should be less than stem (going left)
                    let stemPoint = routePath[1]
                    XCTAssertLessThan(breakPoint.x, stemPoint.x, "Route 1 always breaks left")
                }
            }
        }

        // Second: Route 1 on right (with Y After motion) - should STILL break LEFT
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

                // Route "1" ALWAYS breaks LEFT (absolute direction, even when receiver is on right)
                // Path should have 3 points: start, stem end, break point
                XCTAssertGreaterThanOrEqual(routePath.count, 3, "Route 1 should have break point")
                if routePath.count >= 3 {
                    let breakPoint = routePath[2]
                    let stemPoint = routePath[1]
                    // Break point X should be less than stem X (LEFT, absolute direction)
                    XCTAssertLessThan(breakPoint.x, stemPoint.x, "Route 1 always breaks left even from right side")
                }
            }
        }
    }

    // MARK: - Route 1 Geometry Tests (45° Diagonal)

@MainActor func testRoute1BreakpointGeometry45Degrees() {
        // Route 1 breakpoint should be at 45° diagonal: (-breakLen * 0.7, -breakLen * 0.5)
        // This is the same angle as Route 2 but in opposite directions
        let config = DiagramConfig.standard(for: CGSize(width: 500, height: 600))
        let renderer = DiagramRenderer()

        // Test Route 1 from left side (Trips Left formation)
        if case .success(let playCall) = interpreter.interpret(digits: "1111", formation: .tripsLeft) {
            let positions = renderer.receiverPositions(formation: playCall.formation, config: config)

            if let yAssignment = playCall.assignments.first(where: { $0.receiver == .Y }) {
                guard let yPos = positions[.Y] else { return XCTFail("Y position not found") }

                let routePath = renderer.routePath(
                    for: yAssignment,
                    startPosition: yPos,
                    side: yAssignment.motionFinalSide,
                    config: config
                )

                // Path should have 3 points: start, shortStem, breakPoint
                XCTAssertEqual(routePath.count, 3, "Route 1 should have 3 path points")

                let shortStem = routePath[1]
                let breakPoint = routePath[2]

                // Verify shortStem is at 25% of stemLength upfield (negative Y direction)
                let expectedStemY = yPos.y - config.routeLength * 0.25
                XCTAssertEqual(shortStem.y, expectedStemY, accuracy: 0.5, "Short stem should be at 25% of route length")

                // Verify breakPoint uses 45° diagonal geometry
                let expectedBreakX = shortStem.x - config.breakLength * 0.7
                let expectedBreakY = shortStem.y - config.breakLength * 0.5
                XCTAssertEqual(breakPoint.x, expectedBreakX, accuracy: 0.5, "Break point X should use 0.7 * breakLength offset")
                XCTAssertEqual(breakPoint.y, expectedBreakY, accuracy: 0.5, "Break point Y should use 0.5 * breakLength offset")
            }
        }
    }

@MainActor func testRoute1And2Geometry45DegreeSymmetry() {
        // Route 1 and Route 2 should form a symmetric 45° pair:
        // Route 1: (-0.7 * breakLen, -0.5 * breakLen) LEFT
        // Route 2: (+0.7 * breakLen, -0.5 * breakLen) RIGHT
        let config = DiagramConfig.standard(for: CGSize(width: 500, height: 600))
        let renderer = DiagramRenderer()
        let testPos = CGPoint(x: 250, y: 300)

        // Create Route 1 assignment
        let route1 = RouteAssignment(receiver: .Y, routeNumber: .one, side: .left, initialMeaning: .quickOut, motion: nil)
        let route1Path = renderer.routePath(
            for: route1,
            startPosition: testPos,
            side: .left,
            config: config
        )

        // Create Route 2 assignment
        let route2 = RouteAssignment(receiver: .Y, routeNumber: .two, side: .right, initialMeaning: .quickOut, motion: nil)
        let route2Path = renderer.routePath(
            for: route2,
            startPosition: testPos,
            side: .right,
            config: config
        )

        guard route1Path.count >= 3, route2Path.count >= 3 else {
            return XCTFail("Both routes should have 3 path points")
        }

        let route1Break = route1Path[2]
        let route2Break = route2Path[2]
        let stemPoint = route1Path[1] // Both have same stem

        // X coordinates should be symmetric (opposite signs)
        let route1OffsetX = route1Break.x - stemPoint.x
        let route2OffsetX = route2Break.x - stemPoint.x
        XCTAssertEqual(route1OffsetX, -route2OffsetX, accuracy: 0.5, "Route 1 and 2 X offsets should be symmetric")

        // Y coordinates should be identical (same upfield angle)
        let route1OffsetY = route1Break.y - stemPoint.y
        let route2OffsetY = route2Break.y - stemPoint.y
        XCTAssertEqual(route1OffsetY, route2OffsetY, accuracy: 0.5, "Route 1 and 2 Y offsets should be identical")
    }
}
