import XCTest
@testable import SpartansPlaycaller

/// Robustness and edge case tests for Y Wheel feature.
/// Tests verify:
/// - Arc rendering quality (smoothness, clarity)
/// - Edge case handling (rapid toggles, formation switching)
/// - Responsiveness and consistency
/// - No crashes or visual artifacts under stress conditions
class Y_WheelRobustnessTests: XCTestCase {

    // MARK: - Test Setup

    let renderer = DiagramRenderer()
    let interpreter = RouteInterpreter()

    // MARK: - Edge Case: Rapid Wheel Toggle

    /// Test that wheel can be toggled off/on repeatedly without issues
    func testRapidWheelToggle() {
        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))

        let playCall = createPlayCall(formation: .twins, yWheelEnabled: true)

        // Rapidly toggle wheel on and off 10 times
        for i in 0..<10 {
            let toggleOn = (i % 2 == 0)
            let playCall = createPlayCall(formation: .twins, yWheelEnabled: toggleOn)

            // Should not crash
            let (_, points, _) = renderer.yWheelArcPath(for: playCall, config: config)
            XCTAssertGreater(points.count, 0, "Arc should render on iteration \(i)")

            // Verify toggle state
            if toggleOn {
                XCTAssertTrue(playCall.yWheelEnabled)
            } else {
                XCTAssertFalse(playCall.yWheelEnabled)
            }
        }
    }

    /// Test that wheel toggle state is responsive
    func testWheelToggleResponsiveness() {
        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))

        // Create play call with wheel on
        var playCall = createPlayCall(formation: .twins, yWheelEnabled: true)
        let startTime = Date()

        // Compute arc
        let (_, points, _) = renderer.yWheelArcPath(for: playCall, config: config)

        let elapsed = Date().timeIntervalSince(startTime)

        // Arc computation should be fast (<100ms for responsiveness)
        XCTAssertLess(elapsed, 0.1, "Arc computation should be responsive (<100ms)")
        XCTAssertGreater(points.count, 0)
    }

    // MARK: - Edge Case: Motion Changes with Wheel Enabled

    /// Test switching motion from None to After while wheel is enabled
    func testMotionChangeWhileWheelEnabled() {
        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))

        // Start with no motion
        let playCallNoMotion = createPlayCall(formation: .twins, yWheelEnabled: true, motion: nil)
        let (_, pointsNoMotion, _) = renderer.yWheelArcPath(for: playCallNoMotion, config: config)
        XCTAssertGreater(pointsNoMotion.count, 0)

        // Switch to After motion
        let playCallAfter = createPlayCall(formation: .twins, yWheelEnabled: true, motion: .after)
        let (_, pointsAfter, _) = renderer.yWheelArcPath(for: playCallAfter, config: config)
        XCTAssertGreater(pointsAfter.count, 0)

        // Both should have valid arcs
        XCTAssertEqual(pointsNoMotion.count, pointsAfter.count)
    }

    /// Test all motion types (None, Stop, After, Go) with wheel enabled
    func testAllMotionTypesWithWheel() {
        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))

        let motions: [ReceiverMotion?] = [nil, .stop, .after, .go]

        for motion in motions {
            let playCall = createPlayCall(formation: .twins, yWheelEnabled: true, motion: motion)
            let (_, points, _) = renderer.yWheelArcPath(for: playCall, config: config)

            XCTAssertGreater(points.count, 0, "Arc should render with motion: \(motion?.rawValue ?? "nil")")
            XCTAssertTrue(playCall.yWheelEnabled)
        }
    }

    // MARK: - Edge Case: Formation Switching with Wheel + Motion

    /// Test rapid formation switching with wheel enabled
    func testRapidFormationSwitchingWithWheel() {
        let formations: [Formation] = [.twins, .tripsLeft, .tripsRight, .proLeft, .proRight]
        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))

        // Cycle through formations multiple times
        for cycle in 0..<3 {
            for formation in formations {
                let playCall = createPlayCall(formation: formation, yWheelEnabled: true)
                let (_, points, _) = renderer.yWheelArcPath(for: playCall, config: config)

                XCTAssertGreater(points.count, 0, "Arc should render for \(formation.rawValue) in cycle \(cycle)")
                XCTAssertTrue(playCall.yWheelEnabled)
            }
        }
    }

    /// Test formation switching with wheel + motion enabled
    func testFormationSwitchWithWheelAndMotion() {
        let formations: [Formation] = [.twins, .tripsLeft, .tripsRight, .proLeft, .proRight]
        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))

        for formation in formations {
            let playCall = createPlayCall(formation: formation, yWheelEnabled: true, motion: .after)
            let (_, points, _) = renderer.yWheelArcPath(for: playCall, config: config)

            XCTAssertGreater(points.count, 0, "Arc should render for \(formation.rawValue) with After motion")
            XCTAssertTrue(playCall.yWheelEnabled)

            if let yAssignment = playCall.assignments.first(where: { $0.receiver == .Y }) {
                XCTAssertEqual(yAssignment.motion, .after)
            }
        }
    }

    // MARK: - Visual Quality: Arc Smoothness

    /// Test that arc has sufficient points for smooth rendering
    func testArcHasSufficientPointsForSmoothness() {
        let playCall = createPlayCall(formation: .twins, yWheelEnabled: true)
        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))

        let (_, points, _) = renderer.yWheelArcPath(for: playCall, config: config)

        // Should have at least 30 points (50 sampled points at 0.02 stride = 50 points)
        XCTAssertGreaterThanOrEqual(points.count, 30, "Arc should have sufficient points for smooth curve")
    }

    /// Test that consecutive arc points don't have large jumps
    func testArcSegmentsAreSmall() {
        let playCall = createPlayCall(formation: .twins, yWheelEnabled: true)
        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))

        let (_, points, _) = renderer.yWheelArcPath(for: playCall, config: config)

        var maxSegmentLength: CGFloat = 0
        for i in 1..<points.count {
            let distance = hypot(points[i].x - points[i-1].x, points[i].y - points[i-1].y)
            maxSegmentLength = max(maxSegmentLength, distance)
        }

        // Each segment should be small (smooth curve)
        XCTAssertLess(maxSegmentLength, 10, "Arc segments should be small for smooth appearance")
    }

    /// Test arc smoothness across all formations
    func testArcSmoothnessAcrossAllFormations() {
        let formations: [Formation] = [.twins, .tripsLeft, .tripsRight, .proLeft, .proRight]
        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))

        for formation in formations {
            let playCall = createPlayCall(formation: formation, yWheelEnabled: true)
            let (_, points, _) = renderer.yWheelArcPath(for: playCall, config: config)

            XCTAssertGreaterThanOrEqual(points.count, 30, "Arc should have sufficient points for \(formation.rawValue)")

            // Verify smoothness
            var maxSegment: CGFloat = 0
            for i in 1..<points.count {
                let distance = hypot(points[i].x - points[i-1].x, points[i].y - points[i-1].y)
                maxSegment = max(maxSegment, distance)
            }

            XCTAssertLess(maxSegment, 10, "Arc should be smooth for \(formation.rawValue)")
        }
    }

    // MARK: - Visual Quality: Arc Consistency

    /// Test that arc rendering is deterministic (same input = same output)
    func testArcRenderingIsDeterministic() {
        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))

        let playCall = createPlayCall(formation: .twins, yWheelEnabled: true)

        // Compute arc twice
        let (_, points1, color1) = renderer.yWheelArcPath(for: playCall, config: config)
        let (_, points2, color2) = renderer.yWheelArcPath(for: playCall, config: config)

        // Should be identical
        XCTAssertEqual(points1.count, points2.count, "Arc should have same point count")
        XCTAssertEqual(color1, color2, "Arc should have same color")

        // Points should be very close (floating point precision)
        for i in 0..<points1.count {
            XCTAssertEqual(points1[i].x, points2[i].x, accuracy: 0.01, "Point \(i) X should match")
            XCTAssertEqual(points1[i].y, points2[i].y, accuracy: 0.01, "Point \(i) Y should match")
        }
    }

    // MARK: - Field Boundary: Arc Doesn't Clip

    /// Test that arc stays within field boundaries on all screen sizes
    func testArcDoesNotClipOnSmallScreen() {
        let playCall = createPlayCall(formation: .twins, yWheelEnabled: true)
        let smallConfig = DiagramConfig.standard(for: CGSize(width: 320, height: 568))

        let (_, points, _) = renderer.yWheelArcPath(for: playCall, config: smallConfig)

        // Verify no points extend outside field
        for (index, point) in points.enumerated() {
            XCTAssertGreaterThanOrEqual(point.x, 0, "Point \(index) should not extend left of field")
            XCTAssertLessThanOrEqual(point.x, 320, "Point \(index) should not extend right of field")
            XCTAssertGreaterThanOrEqual(point.y, 0, "Point \(index) should not extend above field")
            XCTAssertLessThanOrEqual(point.y, 568, "Point \(index) should not extend below field")
        }
    }

    /// Test that arc stays within field boundaries on large screen
    func testArcDoesNotClipOnLargeScreen() {
        let playCall = createPlayCall(formation: .twins, yWheelEnabled: true)
        let largeConfig = DiagramConfig.standard(for: CGSize(width: 1024, height: 1366))

        let (_, points, _) = renderer.yWheelArcPath(for: playCall, config: largeConfig)

        // Verify no points extend outside field
        for (index, point) in points.enumerated() {
            XCTAssertGreaterThanOrEqual(point.x, 0, "Point \(index) should not extend left of field")
            XCTAssertLessThanOrEqual(point.x, 1024, "Point \(index) should not extend right of field")
            XCTAssertGreaterThanOrEqual(point.y, 0, "Point \(index) should not extend above field")
            XCTAssertLessThanOrEqual(point.y, 1366, "Point \(index) should not extend below field")
        }
    }

    /// Test that arc on all formations doesn't clip on any screen size
    func testNoClippingAcrossScreenSizes() {
        let formations: [Formation] = [.twins, .tripsLeft, .tripsRight, .proLeft, .proRight]
        let screenSizes: [(CGSize, String)] = [
            (CGSize(width: 320, height: 568), "iPhone SE"),
            (CGSize(width: 393, height: 852), "iPhone 15 Pro"),
            (CGSize(width: 1024, height: 1366), "iPad")
        ]

        for formation in formations {
            for (size, name) in screenSizes {
                let playCall = createPlayCall(formation: formation, yWheelEnabled: true)
                let config = DiagramConfig.standard(for: size)

                let (_, points, _) = renderer.yWheelArcPath(for: playCall, config: config)

                // Verify no clipping
                for point in points {
                    XCTAssertGreaterThanOrEqual(point.x, 0, "Arc should not clip left on \(name) in \(formation.rawValue)")
                    XCTAssertLessThanOrEqual(point.x, size.width, "Arc should not clip right on \(name) in \(formation.rawValue)")
                    XCTAssertGreaterThanOrEqual(point.y, 0, "Arc should not clip top on \(name) in \(formation.rawValue)")
                    XCTAssertLessThanOrEqual(point.y, size.height, "Arc should not clip bottom on \(name) in \(formation.rawValue)")
                }
            }
        }
    }

    // MARK: - Stress Test: Complex Scenarios

    /// Test a complex sequence of operations that could stress the system
    func testComplexOperationSequence() {
        let formations: [Formation] = [.twins, .tripsLeft, .tripsRight, .proLeft, .proRight]
        let motions: [ReceiverMotion?] = [nil, .stop, .after, .go]
        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))

        // Run through combinations
        var operationCount = 0
        for formation in formations {
            for motion in motions {
                for wheelEnabled in [true, false] {
                    let playCall = createPlayCall(formation: formation, yWheelEnabled: wheelEnabled, motion: motion)

                    if wheelEnabled {
                        let (_, points, _) = renderer.yWheelArcPath(for: playCall, config: config)
                        XCTAssertGreater(points.count, 0, "Operation \(operationCount) should render successfully")
                    }

                    operationCount += 1
                }
            }
        }

        XCTAssertGreater(operationCount, 0, "Should complete all operations")
    }

    /// Test that arc doesn't break with extreme screen sizes
    func testArcWithExtremeScreenSizes() {
        let extremeSizes: [(CGSize, String)] = [
            (CGSize(width: 280, height: 450), "Small phone"),
            (CGSize(width: 1200, height: 1600), "Large tablet")
        ]

        let playCall = createPlayCall(formation: .twins, yWheelEnabled: true)

        for (size, name) in extremeSizes {
            let config = DiagramConfig.standard(for: size)
            let (_, points, _) = renderer.yWheelArcPath(for: playCall, config: config)

            XCTAssertGreater(points.count, 0, "Arc should render on \(name)")

            // Verify stays in bounds
            for point in points {
                XCTAssertGreaterThanOrEqual(point.x, 0, "Arc should be within bounds on \(name)")
                XCTAssertLessThanOrEqual(point.x, size.width, "Arc should be within bounds on \(name)")
            }
        }
    }

    // MARK: - Consistency: Wheel State Preservation

    /// Test that wheel state is independent of formation
    func testWheelStatePreservedAcrossFormations() {
        let formations: [Formation] = [.twins, .tripsLeft, .tripsRight, .proLeft, .proRight]

        // Create play calls with wheel on
        for formation in formations {
            let playCall = createPlayCall(formation: formation, yWheelEnabled: true)
            XCTAssertTrue(playCall.yWheelEnabled, "Wheel should be on for \(formation.rawValue)")
        }

        // Create play calls with wheel off
        for formation in formations {
            let playCall = createPlayCall(formation: formation, yWheelEnabled: false)
            XCTAssertFalse(playCall.yWheelEnabled, "Wheel should be off for \(formation.rawValue)")
        }
    }

    /// Test that wheel state is independent of motion
    func testWheelStatePreservedAcrossMotions() {
        let motions: [ReceiverMotion?] = [nil, .stop, .after, .go]

        // Wheel on with all motion types
        for motion in motions {
            let playCall = createPlayCall(formation: .twins, yWheelEnabled: true, motion: motion)
            XCTAssertTrue(playCall.yWheelEnabled, "Wheel should be on with motion \(motion?.rawValue ?? "nil")")
        }

        // Wheel off with all motion types
        for motion in motions {
            let playCall = createPlayCall(formation: .twins, yWheelEnabled: false, motion: motion)
            XCTAssertFalse(playCall.yWheelEnabled, "Wheel should be off with motion \(motion?.rawValue ?? "nil")")
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
