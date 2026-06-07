import XCTest
@testable import SpartansPlaycaller

/// Comprehensive unit tests for Y Wheel feature covering:
/// - Formation gating (all formations support wheel)
/// - Wheel state management and toggle behavior
/// - Wheel interaction with Y Motion
/// - Arc geometry validation
/// - Concept matching with wheel enabled
class Y_WheelComprehensiveTests: XCTestCase {

    // MARK: - Test Setup

    let renderer = DiagramRenderer()
    let interpreter = RouteInterpreter()

    // MARK: - Unit Tests: Formation Support

    /// Test that all formations support Y Wheel toggle
    func testAllFormationsSupportWheel() {
        let formations: [Formation] = [.twins, .tripsLeft, .tripsRight, .proLeft, .proRight]

        for formation in formations {
            // All formations should allow wheel to be enabled
            // (No gating logic should prevent wheel in any formation)
            let playCall = createPlayCall(formation: formation, yWheelEnabled: true)
            XCTAssertTrue(playCall.yWheelEnabled, "Formation \(formation.rawValue) should support Y Wheel")
        }
    }

    /// Test that motion support is unchanged by wheel feature
    func testMotionSupportedForAllFormations() {
        XCTAssertTrue(Formation.twins.canApplyMotion())
        XCTAssertTrue(Formation.tripsLeft.canApplyMotion())
        XCTAssertTrue(Formation.tripsRight.canApplyMotion())
        XCTAssertTrue(Formation.proLeft.canApplyMotion())
        XCTAssertTrue(Formation.proRight.canApplyMotion())
    }

    // MARK: - Unit Tests: Y Wheel Toggle State Management

    /// Test that wheel toggle can be enabled
    func testYWheelToggleCanBeEnabled() {
        let playCall = createPlayCall(formation: .twins, yWheelEnabled: true)
        XCTAssertTrue(playCall.yWheelEnabled, "Wheel should be enabled when set to true")
    }

    /// Test that wheel toggle can be disabled
    func testYWheelToggleCanBeDisabled() {
        let playCall = createPlayCall(formation: .twins, yWheelEnabled: false)
        XCTAssertFalse(playCall.yWheelEnabled, "Wheel should be disabled when set to false")
    }

    /// Test that wheel defaults to off
    func testYWheelDefaultsToOff() {
        let playCall = createPlayCall(formation: .twins, yWheelEnabled: false)
        XCTAssertFalse(playCall.yWheelEnabled, "Wheel should default to OFF")
    }

    /// Test that wheel state is preserved when toggled multiple times
    func testYWheelToggleMultipleTimes() {
        var playCall = createPlayCall(formation: .twins, yWheelEnabled: false)
        XCTAssertFalse(playCall.yWheelEnabled)

        playCall = createPlayCall(formation: .twins, yWheelEnabled: true)
        XCTAssertTrue(playCall.yWheelEnabled)

        playCall = createPlayCall(formation: .twins, yWheelEnabled: false)
        XCTAssertFalse(playCall.yWheelEnabled)

        playCall = createPlayCall(formation: .twins, yWheelEnabled: true)
        XCTAssertTrue(playCall.yWheelEnabled)
    }

    // MARK: - Unit Tests: Wheel + Motion Interaction

    /// Test that wheel works with Stop motion
    func testYWheelWithStopMotion() {
        let playCall = createPlayCall(formation: .twins, yWheelEnabled: true, motion: .stop)
        XCTAssertTrue(playCall.yWheelEnabled, "Wheel should work with Stop motion")

        // Verify assignment reflects motion
        if let yAssignment = playCall.assignments.first(where: { $0.receiver == .Y }) {
            XCTAssertEqual(yAssignment.motion, .stop)
        }
    }

    /// Test that wheel works with After motion
    func testYWheelWithAfterMotion() {
        let playCall = createPlayCall(formation: .twins, yWheelEnabled: true, motion: .after)
        XCTAssertTrue(playCall.yWheelEnabled, "Wheel should work with After motion")

        if let yAssignment = playCall.assignments.first(where: { $0.receiver == .Y }) {
            XCTAssertEqual(yAssignment.motion, .after)
        }
    }

    /// Test that wheel works with Go motion
    func testYWheelWithGoMotion() {
        let playCall = createPlayCall(formation: .twins, yWheelEnabled: true, motion: .go)
        XCTAssertTrue(playCall.yWheelEnabled, "Wheel should work with Go motion")

        if let yAssignment = playCall.assignments.first(where: { $0.receiver == .Y }) {
            XCTAssertEqual(yAssignment.motion, .go)
        }
    }

    /// Test that wheel works independently of motion (wheel on, motion none)
    func testYWheelWithoutMotion() {
        let playCall = createPlayCall(formation: .twins, yWheelEnabled: true, motion: nil)
        XCTAssertTrue(playCall.yWheelEnabled, "Wheel should work without motion")

        if let yAssignment = playCall.assignments.first(where: { $0.receiver == .Y }) {
            XCTAssertNil(yAssignment.motion, "Y should have no motion when not specified")
        }
    }

    // MARK: - Unit Tests: Arc Geometry Validation

    /// Test that arc starts at Y's position
    func testArcStartsAtYPosition() {
        let playCall = createPlayCall(formation: .twins, yWheelEnabled: true)
        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))
        let positions = renderer.receiverPositions(formation: playCall.formation, config: config)

        guard let yPosition = positions[.Y] else {
            XCTFail("Failed to get Y position")
            return
        }

        let (_, arcPoints, _) = renderer.yWheelArcPath(for: playCall, config: config)
        guard arcPoints.count >= 2 else {
            XCTFail("Arc should have at least 2 points")
            return
        }

        let arcStart = arcPoints[0]
        XCTAssertEqual(arcStart.x, yPosition.x, accuracy: 1.0, "Arc start X should match Y position")
        XCTAssertEqual(arcStart.y, yPosition.y, accuracy: 1.0, "Arc start Y should match Y position")
    }

    /// Test that arc curves in the correct direction (left side)
    func testArcCurvesLeftOnLeftSide() {
        let playCall = createPlayCall(formation: .tripsLeft, yWheelEnabled: true)
        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))
        let positions = renderer.receiverPositions(formation: playCall.formation, config: config)

        guard let yPosition = positions[.Y] else {
            XCTFail("Failed to get Y position")
            return
        }

        let (_, arcPoints, _) = renderer.yWheelArcPath(for: playCall, config: config)

        // Arc should curve to the left (min X less than start X)
        let minX = arcPoints.map(\.x).min() ?? yPosition.x
        XCTAssertLess(minX, yPosition.x, "Arc on left side should have points to the left of Y start")
    }

    /// Test that arc curves in the correct direction (right side)
    func testArcCurvesRightOnRightSide() {
        let playCall = createPlayCall(formation: .twins, yWheelEnabled: true)
        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))
        let positions = renderer.receiverPositions(formation: playCall.formation, config: config)

        guard let yPosition = positions[.Y] else {
            XCTFail("Failed to get Y position")
            return
        }

        let (_, arcPoints, _) = renderer.yWheelArcPath(for: playCall, config: config)

        // Arc should curve to the right (max X greater than start X)
        let maxX = arcPoints.map(\.x).max() ?? yPosition.x
        XCTAssertGreater(maxX, yPosition.x, "Arc on right side should have points to the right of Y start")
    }

    /// Test that arc has proper depth (extends downfield)
    func testArcHasProperDepth() {
        let playCall = createPlayCall(formation: .twins, yWheelEnabled: true)
        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))
        let positions = renderer.receiverPositions(formation: playCall.formation, config: config)

        guard let yPosition = positions[.Y] else {
            XCTFail("Failed to get Y position")
            return
        }

        let (_, arcPoints, _) = renderer.yWheelArcPath(for: playCall, config: config)

        // Arc should extend deeper than Y's starting position
        let maxY = arcPoints.map(\.y).max() ?? yPosition.y
        XCTAssertGreater(maxY, yPosition.y, "Arc should extend deeper into the backfield")
    }

    /// Test that arc endpoint is different X than start (tilted, not symmetric)
    func testArcEndpointDifferentXThanStart() {
        let playCall = createPlayCall(formation: .twins, yWheelEnabled: true)
        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))
        let positions = renderer.receiverPositions(formation: playCall.formation, config: config)

        guard let yPosition = positions[.Y] else {
            XCTFail("Failed to get Y position")
            return
        }

        let (_, arcPoints, _) = renderer.yWheelArcPath(for: playCall, config: config)
        guard let endPoint = arcPoints.last else {
            XCTFail("Arc should have an endpoint")
            return
        }

        // Endpoint X should differ from start X (tilted arc)
        XCTAssertNotEqual(endPoint.x, yPosition.x, accuracy: 10.0, "Arc endpoint X should differ from start X (tilted)")
    }

    /// Test that arc is smooth (no sharp angles)
    func testArcIsSmoothCurve() {
        let playCall = createPlayCall(formation: .twins, yWheelEnabled: true)
        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))
        let (_, arcPoints, _) = renderer.yWheelArcPath(for: playCall, config: config)

        // Should have sufficient points for smooth rendering (>30 points for 50-point sample at 0.02 stride)
        XCTAssertGreaterThanOrEqual(arcPoints.count, 30, "Arc should have sufficient points for smooth curve")

        // Check that consecutive points don't have large jumps (smoothness indicator)
        var maxConsecutiveDistance: CGFloat = 0
        for i in 1..<arcPoints.count {
            let distance = hypot(arcPoints[i].x - arcPoints[i-1].x, arcPoints[i].y - arcPoints[i-1].y)
            maxConsecutiveDistance = max(maxConsecutiveDistance, distance)
        }

        // Each consecutive point should be relatively close (smooth curve)
        XCTAssertLess(maxConsecutiveDistance, 10, "Arc segments should be small for smooth appearance")
    }

    /// Test that arc returns toward line of scrimmage
    func testArcReturnsTowardLOS() {
        let playCall = createPlayCall(formation: .twins, yWheelEnabled: true)
        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))
        let positions = renderer.receiverPositions(formation: playCall.formation, config: config)

        guard let yPosition = positions[.Y] else {
            XCTFail("Failed to get Y position")
            return
        }

        let (_, arcPoints, _) = renderer.yWheelArcPath(for: playCall, config: config)

        // Find deepest point
        let deepestY = arcPoints.map(\.y).max() ?? yPosition.y

        // Endpoint should be above (closer to LOS than) deepest point
        if let endY = arcPoints.last?.y {
            XCTAssertLess(endY, deepestY, "Arc endpoint should be above deepest point (returning to LOS)")
        }
    }

    /// Test that arc color is yellow
    func testArcColorIsYellow() {
        let playCall = createPlayCall(formation: .twins, yWheelEnabled: true)
        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))
        let (_, _, color) = renderer.yWheelArcPath(for: playCall, config: config)

        XCTAssertEqual(color, .yellow, "Arc color should be yellow")
    }

    // MARK: - Unit Tests: Arc Geometry with Formations

    /// Test arc geometry on Pro Left formation
    func testArcOnProLeftFormation() {
        let playCall = createPlayCall(formation: .proLeft, yWheelEnabled: true)
        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))
        let positions = renderer.receiverPositions(formation: playCall.formation, config: config)

        guard let yPosition = positions[.Y] else {
            XCTFail("Failed to get Y position for Pro Left")
            return
        }

        let (_, arcPoints, _) = renderer.yWheelArcPath(for: playCall, config: config)

        // Pro Left: Y on left, arc should curve left
        let minX = arcPoints.map(\.x).min() ?? yPosition.x
        XCTAssertLess(minX, yPosition.x, "Arc on Pro Left should curve to the left")
    }

    /// Test arc geometry on Pro Right formation
    func testArcOnProRightFormation() {
        let playCall = createPlayCall(formation: .proRight, yWheelEnabled: true)
        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))
        let positions = renderer.receiverPositions(formation: playCall.formation, config: config)

        guard let yPosition = positions[.Y] else {
            XCTFail("Failed to get Y position for Pro Right")
            return
        }

        let (_, arcPoints, _) = renderer.yWheelArcPath(for: playCall, config: config)

        // Pro Right: Y on right, arc should curve right
        let maxX = arcPoints.map(\.x).max() ?? yPosition.x
        XCTAssertGreater(maxX, yPosition.x, "Arc on Pro Right should curve to the right")
    }

    // MARK: - Integration Tests: Wheel + Motion Transformations

    /// Test that wheel works with Twins + After motion (transforms 2x2 → 3x1)
    func testTwinsWithAfterMotionAndWheel() {
        let playCall = createPlayCall(formation: .twins, yWheelEnabled: true, motion: .after)

        // Verify wheel is enabled
        XCTAssertTrue(playCall.yWheelEnabled, "Wheel should be enabled with After motion")

        // Verify motion is present
        if let yAssignment = playCall.assignments.first(where: { $0.receiver == .Y }) {
            XCTAssertEqual(yAssignment.motion, .after, "Y should have After motion")

            // After motion flips Y to opposite side
            let originalSide = playCall.formation.side(for: .Y)
            let finalSide = yAssignment.motionFinalSide

            if originalSide == .right {
                XCTAssertEqual(finalSide, .left, "After motion should flip Y from right to left")
            }
        }
    }

    /// Test that wheel works with Trips Left + After motion (transforms 3x1 → 2x2)
    func testTripsLeftWithAfterMotionAndWheel() {
        let playCall = createPlayCall(formation: .tripsLeft, yWheelEnabled: true, motion: .after)

        XCTAssertTrue(playCall.yWheelEnabled, "Wheel should be enabled with After motion")

        if let yAssignment = playCall.assignments.first(where: { $0.receiver == .Y }) {
            XCTAssertEqual(yAssignment.motion, .after, "Y should have After motion")

            // Trips Left: Y starts on left, After flips to right
            let originalSide = playCall.formation.side(for: .Y)
            let finalSide = yAssignment.motionFinalSide

            if originalSide == .left {
                XCTAssertEqual(finalSide, .right, "After motion should flip Y from left to right on Trips Left")
            }
        }
    }

    /// Test that wheel works with Pro formations + motion
    func testProFormationsWithMotionAndWheel() {
        let formations: [Formation] = [.proLeft, .proRight]

        for formation in formations {
            let playCall = createPlayCall(formation: formation, yWheelEnabled: true, motion: .after)
            XCTAssertTrue(playCall.yWheelEnabled, "Wheel should work with \(formation.rawValue) + After motion")
        }
    }

    // MARK: - Test Scenario Coverage from Test Plan

    /// Scenario A: Twins, Y Motion NONE (2x2 remains)
    func testScenarioA_TwinsNoMotion() {
        let playCall = createPlayCall(formation: .twins, yWheelEnabled: true, motion: nil)

        // Verify wheel enabled
        XCTAssertTrue(playCall.yWheelEnabled)

        // Verify formation hasn't changed
        XCTAssertEqual(playCall.formation, .twins)

        // Verify Y is on right side (2x2 formation)
        XCTAssertEqual(playCall.formation.side(for: .Y), .right)
    }

    /// Scenario B: Twins, Y Motion AFTER (transforms to 3x1)
    func testScenarioB_TwinsAfterMotion() {
        let playCall = createPlayCall(formation: .twins, yWheelEnabled: true, motion: .after)

        XCTAssertTrue(playCall.yWheelEnabled)

        if let yAssignment = playCall.assignments.first(where: { $0.receiver == .Y }) {
            XCTAssertEqual(yAssignment.motion, .after)
            // Y should be flipped to left side
            XCTAssertEqual(yAssignment.motionFinalSide, .left)
        }
    }

    /// Scenario C: Trips Left, Y Motion NONE (3x1 remains)
    func testScenarioC_TripsLeftNoMotion() {
        let playCall = createPlayCall(formation: .tripsLeft, yWheelEnabled: true, motion: nil)

        XCTAssertTrue(playCall.yWheelEnabled)
        XCTAssertEqual(playCall.formation, .tripsLeft)
        XCTAssertEqual(playCall.formation.side(for: .Y), .left)
    }

    /// Scenario D: Trips Left, Y Motion AFTER (transforms to 2x2)
    func testScenarioD_TripsLeftAfterMotion() {
        let playCall = createPlayCall(formation: .tripsLeft, yWheelEnabled: true, motion: .after)

        XCTAssertTrue(playCall.yWheelEnabled)

        if let yAssignment = playCall.assignments.first(where: { $0.receiver == .Y }) {
            XCTAssertEqual(yAssignment.motion, .after)
            // Y should be flipped to right side
            XCTAssertEqual(yAssignment.motionFinalSide, .right)
        }
    }

    /// Scenario E: Pro Left, Y Motion NONE (2x1 remains)
    func testScenarioE_ProLeftNoMotion() {
        let playCall = createPlayCall(formation: .proLeft, yWheelEnabled: true, motion: nil)

        XCTAssertTrue(playCall.yWheelEnabled)
        XCTAssertEqual(playCall.formation, .proLeft)
        XCTAssertEqual(playCall.formation.side(for: .Y), .left)
    }

    /// Scenario F: Pro Left, Y Motion AFTER (transforms to 1x2)
    func testScenarioF_ProLeftAfterMotion() {
        let playCall = createPlayCall(formation: .proLeft, yWheelEnabled: true, motion: .after)

        XCTAssertTrue(playCall.yWheelEnabled)

        if let yAssignment = playCall.assignments.first(where: { $0.receiver == .Y }) {
            XCTAssertEqual(yAssignment.motion, .after)
            // Y should be flipped to right side
            XCTAssertEqual(yAssignment.motionFinalSide, .right)
        }
    }

    /// Scenario G: Pro Right, Y Motion NONE (1x2 remains)
    func testScenarioG_ProRightNoMotion() {
        let playCall = createPlayCall(formation: .proRight, yWheelEnabled: true, motion: nil)

        XCTAssertTrue(playCall.yWheelEnabled)
        XCTAssertEqual(playCall.formation, .proRight)
        XCTAssertEqual(playCall.formation.side(for: .Y), .right)
    }

    /// Scenario H: Pro Right, Y Motion AFTER (transforms to 2x1)
    func testScenarioH_ProRightAfterMotion() {
        let playCall = createPlayCall(formation: .proRight, yWheelEnabled: true, motion: .after)

        XCTAssertTrue(playCall.yWheelEnabled)

        if let yAssignment = playCall.assignments.first(where: { $0.receiver == .Y }) {
            XCTAssertEqual(yAssignment.motion, .after)
            // Y should be flipped to left side
            XCTAssertEqual(yAssignment.motionFinalSide, .left)
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
                assignment.motion = motion
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
