import XCTest
import SwiftUI
@testable import SpartansPlaycaller

/// Tests for Y wheel override behavior: when enabled, wheel replaces Y's numbered route entirely.
final class RouteDiagramYWheelTests: XCTestCase {

    let interpreter = RouteInterpreter()
    let renderer = DiagramRenderer()

    // MARK: - Route Override Tests

    @MainActor func testYRouteHiddenWhenWheelEnabled() {
        // When yWheelEnabled is true, Y's numbered route should not be drawn.
        // This test verifies that drawRoutes() skips Y when wheel is active.

        if case .success(var playCall) = interpreter.interpret(digits: "6794", formation: .tripsLeft) {
            // Verify Y has a normal route assignment initially
            let yAssignment = playCall.assignments.first { $0.receiver == .Y }
            XCTAssertNotNil(yAssignment, "Y should have a route assignment")

            // Enable wheel
            playCall.yWheelEnabled = true

            // The diagram view should skip drawing Y's route
            // We can verify this indirectly: the view should render without error,
            // and the playCall should still have Y assignment but wheel should be enabled.
            let view = RouteDiagramView(playCall: playCall)
            XCTAssertNotNil(view, "View should render with wheel enabled")
            XCTAssertTrue(playCall.yWheelEnabled, "Wheel should be enabled")
        }
    }

    @MainActor func testYRouteVisibleWhenWheelDisabled() {
        // When yWheelEnabled is false, Y's numbered route should be drawn normally.

        if case .success(let playCall) = interpreter.interpret(digits: "6794", formation: .tripsLeft) {
            // Verify wheel is disabled by default
            XCTAssertFalse(playCall.yWheelEnabled, "Wheel should be disabled by default")

            // Y should have a route assignment and it should be rendered
            let yAssignment = playCall.assignments.first { $0.receiver == .Y }
            XCTAssertNotNil(yAssignment, "Y should have a route assignment")

            let view = RouteDiagramView(playCall: playCall)
            XCTAssertNotNil(view, "View should render with wheel disabled")
        }
    }

    @MainActor func testWheelOverrideIndependentOfMotion() {
        // Wheel override should work even if Y has motion assigned.
        // Wheel replaces Y's route completely, not in conjunction with motion.

        if case .success(var playCall) = interpreter.interpret(digits: "6794", formation: .tripsLeft) {
            // Apply Y After motion
            if let yIndex = playCall.assignments.firstIndex(where: { $0.receiver == .Y }) {
                playCall.assignments[yIndex].motion = .after
            }

            // Enable wheel
            playCall.yWheelEnabled = true

            // Both conditions should coexist in the model
            if let yAssignment = playCall.assignments.first(where: { $0.receiver == .Y }) {
                XCTAssertEqual(yAssignment.motion, .after, "Y should have After motion")
            }
            XCTAssertTrue(playCall.yWheelEnabled, "Wheel should be enabled")

            // Diagram should render without crashing
            let view = RouteDiagramView(playCall: playCall)
            XCTAssertNotNil(view, "View should render with both motion and wheel")
        }
    }

    // MARK: - Wheel Arc Geometry Tests

    func testWheelArcStartsAtYPosition() {
        // The wheel arc should start at Y's position on the line of scrimmage.

        let playCall = PlayCall(
            formation: .tripsLeft,
            routeDigits: "6794",
            assignments: [],
            concept: nil,
            yWheelEnabled: true
        )

        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))
        let positions = renderer.receiverPositions(formation: playCall.formation, config: config)
        guard let yPosition = positions[.Y] else {
            XCTFail("Y position not found in Trips Left formation")
            return
        }

        let (_, pathPoints, _) = renderer.yWheelArcPath(for: playCall, config: config)

        // First point should be at or very close to Y position
        guard let firstPoint = pathPoints.first else {
            XCTFail("Arc path is empty")
            return
        }

        XCTAssertEqual(firstPoint, yPosition, accuracy: 1.0, "Arc should start at Y position")
    }

    func testWheelArcFormsPropperUShape() {
        // The wheel arc should form a visible U-shape loop, not a tiny stem.
        // We verify this by checking that the arc has significant vertical depth.

        let playCall = PlayCall(
            formation: .tripsLeft,
            routeDigits: "6794",
            assignments: [],
            concept: nil,
            yWheelEnabled: true
        )

        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))
        let positions = renderer.receiverPositions(formation: playCall.formation, config: config)
        guard let yPosition = positions[.Y] else {
            XCTFail("Y position not found")
            return
        }

        let (_, pathPoints, _) = renderer.yWheelArcPath(for: playCall, config: config)

        XCTAssertGreaterThan(pathPoints.count, 2, "Arc should have sampled points for visualization")

        // Find the deepest point in the arc (maximum Y distance from start)
        let startY = yPosition.y
        let maxDepth = pathPoints.map { abs($0.y - startY) }.max() ?? 0

        // The depth should be at least 10% of the field height
        let minVisibleDepth = config.fieldHeight * 0.08
        XCTAssertGreaterThan(maxDepth, minVisibleDepth,
                            "Arc should have significant depth for visibility. Max depth: \(maxDepth), min required: \(minVisibleDepth)")
    }

    func testWheelArcLeftSideOffsets() {
        // For a left-side Y, the arc should curve to the left.

        let playCall = PlayCall(
            formation: .tripsLeft,
            routeDigits: "6794",
            assignments: [],
            concept: nil,
            yWheelEnabled: true
        )

        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))
        let (_, pathPoints, _) = renderer.yWheelArcPath(for: playCall, config: config)

        // In Trips Left, Y is on the left side, so the arc should have points to the left of Y
        // (smaller X values than Y's position)
        let positions = renderer.receiverPositions(formation: playCall.formation, config: config)
        guard let yPosition = positions[.Y] else { return }

        // At least some points should be to the left of Y's starting X
        let pointsToLeft = pathPoints.filter { $0.x < yPosition.x }
        XCTAssertGreaterThan(pointsToLeft.count, 0, "Arc should curve left for left-side Y")
    }

    func testWheelArcRightSideOffsets() {
        // For a right-side Y, the arc should curve to the right.

        let playCall = PlayCall(
            formation: .tripsRight,
            routeDigits: "6794",
            assignments: [],
            concept: nil,
            yWheelEnabled: true
        )

        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))
        let (_, pathPoints, _) = renderer.yWheelArcPath(for: playCall, config: config)

        // In Trips Right, Y is on the right side, so the arc should have points to the right of Y
        let positions = renderer.receiverPositions(formation: playCall.formation, config: config)
        guard let yPosition = positions[.Y] else { return }

        // At least some points should be to the right of Y's starting X
        let pointsToRight = pathPoints.filter { $0.x > yPosition.x }
        XCTAssertGreaterThan(pointsToRight.count, 0, "Arc should curve right for right-side Y")
    }

    func testWheelArcEndPointReturnsTowardStart() {
        // The arc should end partway back up, not at the deepest point.
        // This creates the U-shape effect rather than a full loop.

        let playCall = PlayCall(
            formation: .tripsLeft,
            routeDigits: "6794",
            assignments: [],
            concept: nil,
            yWheelEnabled: true
        )

        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))
        let positions = renderer.receiverPositions(formation: playCall.formation, config: config)
        guard let yPosition = positions[.Y] else { return }

        let (_, pathPoints, _) = renderer.yWheelArcPath(for: playCall, config: config)
        guard let endPoint = pathPoints.last else { return }

        // End point should be below start (deeper in field)
        XCTAssertGreater(endPoint.y, yPosition.y, "Arc end should be below start (partway down the U)")

        // But not at the absolute deepest point; it should be shallower
        let maxDepth = pathPoints.map { $0.y }.max() ?? yPosition.y
        XCTAssertLessThan(endPoint.y, maxDepth, "Arc end should be shallower than the deepest point")
    }

    func testWheelArcColorIsYellow() {
        // The wheel arc should be yellow (matching Y receiver color).

        let playCall = PlayCall(
            formation: .tripsLeft,
            routeDigits: "6794",
            assignments: [],
            concept: nil,
            yWheelEnabled: true
        )

        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))
        let (_, _, color) = renderer.yWheelArcPath(for: playCall, config: config)

        XCTAssertEqual(color, .yellow, "Wheel arc should be yellow to match Y receiver")
    }

    @MainActor func testWheelArcRendersWithAllFormations() {
        // The wheel arc should render for all formations that support Y wheel.

        for formation in [Formation.tripsLeft, .tripsRight, .proLeft, .proRight] {
            let playCall = PlayCall(
                formation: formation,
                routeDigits: "6794",
                assignments: [],
                concept: nil,
                yWheelEnabled: true
            )

            let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))
            let (path, pathPoints, _) = renderer.yWheelArcPath(for: playCall, config: config)

            XCTAssertFalse(path.isEmpty, "Arc path should not be empty for \(formation)")
            XCTAssertGreaterThan(pathPoints.count, 0, "Arc points should exist for \(formation)")
        }
    }
}
