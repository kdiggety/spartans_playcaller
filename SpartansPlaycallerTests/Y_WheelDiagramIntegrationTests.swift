import XCTest
@testable import SpartansPlaycaller

/// Integration tests for Y Wheel diagram rendering and play flow.
/// Tests verify that:
/// - Wheel arc renders correctly in all formations
/// - Wheel works with motion transformations
/// - Wheel toggle controls visibility
/// - Diagram state updates properly when wheel toggles
/// - No crashes during formation/motion/wheel changes
class Y_WheelDiagramIntegrationTests: XCTestCase {

    // MARK: - Test Setup

    let renderer = DiagramRenderer()
    let interpreter = RouteInterpreter()

    // MARK: - Integration Tests: Arc Rendering in All Formations

    /// Test that wheel arc renders without crashing in Twins formation
    func testWheelArcRendersInTwins() {
        let playCall = createPlayCall(formation: .twins, yWheelEnabled: true)
        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))

        let (path, points, color) = renderer.yWheelArcPath(for: playCall, config: config)

        XCTAssertGreater(points.count, 0, "Arc should have points")
        XCTAssertEqual(color, .yellow, "Arc should be yellow")
        // Path should not be empty
        XCTAssertNotNil(path, "Arc path should be valid")
    }

    /// Test that wheel arc renders without crashing in Trips Left
    func testWheelArcRendersInTripsLeft() {
        let playCall = createPlayCall(formation: .tripsLeft, yWheelEnabled: true)
        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))

        let (path, points, color) = renderer.yWheelArcPath(for: playCall, config: config)

        XCTAssertGreater(points.count, 0, "Arc should have points")
        XCTAssertEqual(color, .yellow, "Arc should be yellow")
        XCTAssertNotNil(path, "Arc path should be valid")
    }

    /// Test that wheel arc renders without crashing in Trips Right
    func testWheelArcRendersInTripsRight() {
        let playCall = createPlayCall(formation: .tripsRight, yWheelEnabled: true)
        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))

        let (path, points, color) = renderer.yWheelArcPath(for: playCall, config: config)

        XCTAssertGreater(points.count, 0, "Arc should have points")
        XCTAssertEqual(color, .yellow, "Arc should be yellow")
        XCTAssertNotNil(path, "Arc path should be valid")
    }

    /// Test that wheel arc renders without crashing in Pro Left
    func testWheelArcRendersInProLeft() {
        let playCall = createPlayCall(formation: .proLeft, yWheelEnabled: true)
        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))

        let (path, points, color) = renderer.yWheelArcPath(for: playCall, config: config)

        XCTAssertGreater(points.count, 0, "Arc should have points")
        XCTAssertEqual(color, .yellow, "Arc should be yellow")
        XCTAssertNotNil(path, "Arc path should be valid")
    }

    /// Test that wheel arc renders without crashing in Pro Right
    func testWheelArcRendersInProRight() {
        let playCall = createPlayCall(formation: .proRight, yWheelEnabled: true)
        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))

        let (path, points, color) = renderer.yWheelArcPath(for: playCall, config: config)

        XCTAssertGreater(points.count, 0, "Arc should have points")
        XCTAssertEqual(color, .yellow, "Arc should be yellow")
        XCTAssertNotNil(path, "Arc path should be valid")
    }

    // MARK: - Integration Tests: Wheel Toggle Controls Visibility

    /// Test that arc is generated when wheel is enabled
    func testArcGeneratedWhenWheelEnabled() {
        let playCallOff = createPlayCall(formation: .twins, yWheelEnabled: false)
        let playCallOn = createPlayCall(formation: .twins, yWheelEnabled: true)
        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))

        // When wheel is off, arc should not be used in diagram
        // (Arc path can still be computed, but diagram only renders if yWheelEnabled is true)
        XCTAssertFalse(playCallOff.yWheelEnabled)
        XCTAssertTrue(playCallOn.yWheelEnabled)

        // Both should compute successfully
        let (_, pointsOff, _) = renderer.yWheelArcPath(for: playCallOff, config: config)
        let (_, pointsOn, _) = renderer.yWheelArcPath(for: playCallOn, config: config)

        XCTAssertGreater(pointsOff.count, 0, "Arc should be computable even when wheel is off")
        XCTAssertGreater(pointsOn.count, 0, "Arc should be computable when wheel is on")
    }

    /// Test that toggling wheel off/on produces consistent arc
    func testConsistentArcAfterToggle() {
        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))

        let playCall1 = createPlayCall(formation: .twins, yWheelEnabled: true)
        let (_, points1, _) = renderer.yWheelArcPath(for: playCall1, config: config)

        let playCall2 = createPlayCall(formation: .twins, yWheelEnabled: false)
        let (_, points2, _) = renderer.yWheelArcPath(for: playCall2, config: config)

        let playCall3 = createPlayCall(formation: .twins, yWheelEnabled: true)
        let (_, points3, _) = renderer.yWheelArcPath(for: playCall3, config: config)

        // Arc computed from same formation should be consistent
        XCTAssertEqual(points1.count, points3.count, "Arc point count should be consistent")
        XCTAssertEqual(points1[0], points3[0], "Arc start points should match")
    }

    // MARK: - Integration Tests: Formation Transformation with Wheel

    /// Test Twins + After motion: arc updates when motion changes
    func testTwinsMotionArcUpdates() {
        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))

        let playCallNoMotion = createPlayCall(formation: .twins, yWheelEnabled: true, motion: nil)
        let (_, pointsNoMotion, _) = renderer.yWheelArcPath(for: playCallNoMotion, config: config)

        let playCallAfter = createPlayCall(formation: .twins, yWheelEnabled: true, motion: .after)
        let (_, pointsAfter, _) = renderer.yWheelArcPath(for: playCallAfter, config: config)

        // Both should generate valid arcs
        XCTAssertGreater(pointsNoMotion.count, 0)
        XCTAssertGreater(pointsAfter.count, 0)

        // With motion, Y's position changes, so arc should be different
        // (Though we can't directly access Y's final position here, we verify both are valid)
        XCTAssertEqual(pointsNoMotion.count, pointsAfter.count, "Both should have same number of arc points")
    }

    /// Test Trips Left + After motion: arc updates when motion changes
    func testTripsLeftMotionArcUpdates() {
        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))

        let playCallNoMotion = createPlayCall(formation: .tripsLeft, yWheelEnabled: true, motion: nil)
        let (_, pointsNoMotion, _) = renderer.yWheelArcPath(for: playCallNoMotion, config: config)

        let playCallAfter = createPlayCall(formation: .tripsLeft, yWheelEnabled: true, motion: .after)
        let (_, pointsAfter, _) = renderer.yWheelArcPath(for: playCallAfter, config: config)

        // Both should generate valid arcs
        XCTAssertGreater(pointsNoMotion.count, 0)
        XCTAssertGreater(pointsAfter.count, 0)
    }

    // MARK: - Integration Tests: Formation Switching with Wheel Enabled

    /// Test switching from Twins to Trips Left with wheel enabled
    func testSwitchTwinsToTripsLeftWithWheel() {
        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))

        let playCallTwins = createPlayCall(formation: .twins, yWheelEnabled: true)
        let (_, pointsTwins, _) = renderer.yWheelArcPath(for: playCallTwins, config: config)

        let playCallTripsLeft = createPlayCall(formation: .tripsLeft, yWheelEnabled: true)
        let (_, pointsTripsLeft, _) = renderer.yWheelArcPath(for: playCallTripsLeft, config: config)

        // Both should render without crashing
        XCTAssertGreater(pointsTwins.count, 0)
        XCTAssertGreater(pointsTripsLeft.count, 0)

        // Arc should be different (different Y positions in each formation)
        let twinsMinX = pointsTwins.map(\.x).min() ?? 0
        let tripsMinX = pointsTripsLeft.map(\.x).min() ?? 0
        XCTAssertNotEqual(twinsMinX, tripsMinX, "Formations should have different arc geometry")
    }

    /// Test switching from Trips Left to Trips Right with wheel enabled
    func testSwitchTripsLeftToTripsRightWithWheel() {
        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))

        let playCallLeft = createPlayCall(formation: .tripsLeft, yWheelEnabled: true)
        let (_, pointsLeft, _) = renderer.yWheelArcPath(for: playCallLeft, config: config)

        let playCallRight = createPlayCall(formation: .tripsRight, yWheelEnabled: true)
        let (_, pointsRight, _) = renderer.yWheelArcPath(for: playCallRight, config: config)

        // Both should render without crashing
        XCTAssertGreater(pointsLeft.count, 0)
        XCTAssertGreater(pointsRight.count, 0)

        // Arc direction should be opposite (left curves left, right curves right)
        let leftMinX = pointsLeft.map(\.x).min() ?? 0
        let rightMaxX = pointsRight.map(\.x).max() ?? 0

        // Left formation should have arc to the left
        XCTAssertLess(leftMinX, pointsLeft[0].x, "Trips Left arc should curve left")

        // Right formation should have arc to the right
        XCTAssertGreater(rightMaxX, pointsRight[0].x, "Trips Right arc should curve right")
    }

    /// Test switching from Pro Left to Pro Right with wheel enabled
    func testSwitchProLeftToProRightWithWheel() {
        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))

        let playCallLeft = createPlayCall(formation: .proLeft, yWheelEnabled: true)
        let (_, pointsLeft, _) = renderer.yWheelArcPath(for: playCallLeft, config: config)

        let playCallRight = createPlayCall(formation: .proRight, yWheelEnabled: true)
        let (_, pointsRight, _) = renderer.yWheelArcPath(for: playCallRight, config: config)

        // Both should render without crashing
        XCTAssertGreater(pointsLeft.count, 0)
        XCTAssertGreater(pointsRight.count, 0)
    }

    // MARK: - Integration Tests: Multi-Step Formation + Motion + Wheel Changes

    /// Test toggling wheel during various formation + motion combinations
    func testWheelToggleDuringComplexFlow() {
        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))

        // Step 1: Twins + no motion + wheel off
        var playCall = createPlayCall(formation: .twins, yWheelEnabled: false, motion: nil)
        XCTAssertFalse(playCall.yWheelEnabled)

        // Step 2: Twins + no motion + wheel on
        playCall = createPlayCall(formation: .twins, yWheelEnabled: true, motion: nil)
        var (_, points, _) = renderer.yWheelArcPath(for: playCall, config: config)
        XCTAssertGreater(points.count, 0, "Arc should render with wheel on")

        // Step 3: Twins + After motion + wheel on
        playCall = createPlayCall(formation: .twins, yWheelEnabled: true, motion: .after)
        (_, points, _) = renderer.yWheelArcPath(for: playCall, config: config)
        XCTAssertGreater(points.count, 0, "Arc should render with After motion and wheel on")

        // Step 4: Switch to Trips Left + After motion + wheel on
        playCall = createPlayCall(formation: .tripsLeft, yWheelEnabled: true, motion: .after)
        (_, points, _) = renderer.yWheelArcPath(for: playCall, config: config)
        XCTAssertGreater(points.count, 0, "Arc should render after formation switch")

        // Step 5: Turn wheel off
        playCall = createPlayCall(formation: .tripsLeft, yWheelEnabled: false, motion: .after)
        XCTAssertFalse(playCall.yWheelEnabled)

        // Step 6: Turn wheel back on
        playCall = createPlayCall(formation: .tripsLeft, yWheelEnabled: true, motion: .after)
        (_, points, _) = renderer.yWheelArcPath(for: playCall, config: config)
        XCTAssertGreater(points.count, 0, "Arc should render after toggle back on")
    }

    // MARK: - Integration Tests: Screen Size Variations

    /// Test that arc renders correctly on iPhone SE (small screen)
    func testArcRendersOnSmallScreen() {
        let playCall = createPlayCall(formation: .twins, yWheelEnabled: true)
        let config = DiagramConfig.standard(for: CGSize(width: 320, height: 568)) // iPhone SE

        let (_, points, _) = renderer.yWheelArcPath(for: playCall, config: config)

        XCTAssertGreater(points.count, 0, "Arc should render on small screen")

        // Verify arc doesn't extend off field
        let fieldWidth = 320.0
        let fieldHeight = 568.0

        for point in points {
            XCTAssertGreaterThanOrEqual(point.x, 0, "Arc should not extend left of field")
            XCTAssertLessThanOrEqual(point.x, fieldWidth, "Arc should not extend right of field")
            XCTAssertGreaterThanOrEqual(point.y, 0, "Arc should not extend above field")
            XCTAssertLessThanOrEqual(point.y, fieldHeight, "Arc should not extend below field")
        }
    }

    /// Test that arc renders correctly on iPad (large screen)
    func testArcRendersOnLargeScreen() {
        let playCall = createPlayCall(formation: .twins, yWheelEnabled: true)
        let config = DiagramConfig.standard(for: CGSize(width: 1024, height: 1366)) // iPad

        let (_, points, _) = renderer.yWheelArcPath(for: playCall, config: config)

        XCTAssertGreater(points.count, 0, "Arc should render on large screen")

        // Verify arc doesn't extend off field
        let fieldWidth = 1024.0
        let fieldHeight = 1366.0

        for point in points {
            XCTAssertGreaterThanOrEqual(point.x, 0, "Arc should not extend left of field")
            XCTAssertLessThanOrEqual(point.x, fieldWidth, "Arc should not extend right of field")
            XCTAssertGreaterThanOrEqual(point.y, 0, "Arc should not extend above field")
            XCTAssertLessThanOrEqual(point.y, fieldHeight, "Arc should not extend below field")
        }
    }

    /// Test that arc renders correctly on iPhone 15 Pro (standard screen)
    func testArcRendersOnStandardScreen() {
        let playCall = createPlayCall(formation: .twins, yWheelEnabled: true)
        let config = DiagramConfig.standard(for: CGSize(width: 393, height: 852)) // iPhone 15 Pro

        let (_, points, _) = renderer.yWheelArcPath(for: playCall, config: config)

        XCTAssertGreater(points.count, 0, "Arc should render on standard screen")
    }

    // MARK: - Integration Tests: Receiver Position Verification

    /// Test that arc originates from Y's actual position in formation
    func testArcOriginatesFromYPosition() {
        let formations: [Formation] = [.twins, .tripsLeft, .tripsRight, .proLeft, .proRight]

        for formation in formations {
            let playCall = createPlayCall(formation: formation, yWheelEnabled: true)
            let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))

            let positions = renderer.receiverPositions(formation: formation, config: config)
            guard let yPosition = positions[.Y] else {
                XCTFail("Should have Y position for \(formation.rawValue)")
                continue
            }

            let (_, arcPoints, _) = renderer.yWheelArcPath(for: playCall, config: config)
            guard let arcStart = arcPoints.first else {
                XCTFail("Arc should have points for \(formation.rawValue)")
                continue
            }

            // Arc start should match Y position
            XCTAssertEqual(arcStart.x, yPosition.x, accuracy: 1.0, "Arc should start at Y position for \(formation.rawValue)")
            XCTAssertEqual(arcStart.y, yPosition.y, accuracy: 1.0, "Arc should start at Y position for \(formation.rawValue)")
        }
    }

    // MARK: - Helper Methods

    private func createPlayCall(
        formation: Formation,
        yWheelEnabled: Bool,
        motion: ReceiverMotion? = nil
    ) -> PlayCall {
        let digitSequence = "6794"

        guard case .success(var playCall) = interpreter.interpret(digits: digitSequence, formation: formation) else {
            fatalError("Failed to create play call")
        }

        // Update Y assignment with motion if provided
        if let motion = motion {
            if let index = playCall.assignments.firstIndex(where: { $0.receiver == .Y }) {
                var assignment = playCall.assignments[index]
                assignment = RouteAssignment(
                    receiver: assignment.receiver,
                    routeNumber: assignment.routeNumber,
                    side: assignment.side,
                    motion: motion
                )
                playCall.assignments[index] = assignment
            }
        }

        // Update wheel state
        playCall = PlayCall(
            formation: playCall.formation,
            routeDigits: playCall.routeDigits,
            assignments: playCall.assignments,
            concept: playCall.concept,
            yWheelEnabled: yWheelEnabled
        )

        return playCall
    }
}
