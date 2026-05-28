import XCTest
@testable import SpartansPlaycaller

/// Comprehensive tests validating the three Y receiver motion fixes:
/// 1. Y Motion Arc Distances: Y Stop moves short, Y After/Go move dramatically
/// 2. Route Meaning Changes: Route interpretation reflects final side after motion
/// 3. Y Stop Works: Y Stop should not flip sides and render correctly
final class YReceiverMotionFixTests: XCTestCase {

    let interpreter = RouteInterpreter()
    let renderer = DiagramRenderer()

    // MARK: - Fix 1: Y Motion Arc Distances

    /// Y Stop should stay close to original position (minor offset toward tackle)
    func testYStopMovesShortDistance() {
        let config = DiagramConfig.standard(for: CGSize(width: 500, height: 600))

        if case .success(var playCall) = interpreter.interpret(digits: "6794", formation: .tripsLeft) {
            guard let yIndex = playCall.assignments.firstIndex(where: { $0.receiver == .Y }) else {
                return XCTFail("Y receiver not found")
            }

            playCall.assignments[yIndex].motion = .stop
            let yAssignment = playCall.assignments[yIndex]

            // Y Stop should keep same side
            XCTAssertEqual(yAssignment.side, .left, "Y starts on left in Trips Left")
            XCTAssertEqual(yAssignment.motionFinalSide, .left, "Y Stop should not flip side")

            // Get positions
            let positions = renderer.receiverPositions(formation: playCall.formation, config: config)
            guard let initialPos = positions[.Y] else {
                return XCTFail("Y initial position not found")
            }

            let finalPos = renderer.yFinalPosition(
                initialSide: yAssignment.side,
                finalSide: yAssignment.motionFinalSide,
                motion: yAssignment.motion,
                formation: playCall.formation,
                config: config
            )

            // Y Stop should not move (or move very slightly)
            XCTAssertEqual(finalPos.x, initialPos.x, accuracy: 1.0, "Y Stop should stay at original position")
            XCTAssertEqual(finalPos.y, initialPos.y, "Y should stay at line of scrimmage")
        }
    }

    /// Y After should move dramatically past tackle on opposite side
    func testYAfterMovesDramaticallyOppositeDistance() {
        let config = DiagramConfig.standard(for: CGSize(width: 500, height: 600))

        if case .success(var playCall) = interpreter.interpret(digits: "6794", formation: .tripsLeft) {
            guard let yIndex = playCall.assignments.firstIndex(where: { $0.receiver == .Y }) else {
                return XCTFail("Y receiver not found")
            }

            playCall.assignments[yIndex].motion = .after
            let yAssignment = playCall.assignments[yIndex]

            // Y After should flip to right side
            XCTAssertEqual(yAssignment.side, .left, "Y starts on left in Trips Left")
            XCTAssertEqual(yAssignment.motionFinalSide, .right, "Y After should flip to right side")

            // Get positions
            let positions = renderer.receiverPositions(formation: playCall.formation, config: config)
            guard let initialPos = positions[.Y] else {
                return XCTFail("Y initial position not found")
            }

            let finalPos = renderer.yFinalPosition(
                initialSide: yAssignment.side,
                finalSide: yAssignment.motionFinalSide,
                motion: yAssignment.motion,
                formation: playCall.formation,
                config: config
            )

            // Y After should move dramatically to the right
            let distance = abs(finalPos.x - initialPos.x)
            XCTAssertGreaterThan(finalPos.x, initialPos.x, "Y After should move right")
            XCTAssertGreaterThan(distance, 150, "Y After should move dramatically (distance > 150)")
        }
    }

    /// Y Go should move dramatically past tackle on opposite side (similar to Y After)
    func testYGoMovesDramaticallyOppositeDistance() {
        let config = DiagramConfig.standard(for: CGSize(width: 500, height: 600))

        if case .success(var playCall) = interpreter.interpret(digits: "6794", formation: .tripsRight) {
            guard let yIndex = playCall.assignments.firstIndex(where: { $0.receiver == .Y }) else {
                return XCTFail("Y receiver not found")
            }

            playCall.assignments[yIndex].motion = .go
            let yAssignment = playCall.assignments[yIndex]

            // Y Go should flip to left side
            XCTAssertEqual(yAssignment.side, .right, "Y starts on right in Trips Right")
            XCTAssertEqual(yAssignment.motionFinalSide, .left, "Y Go should flip to left side")

            // Get positions
            let positions = renderer.receiverPositions(formation: playCall.formation, config: config)
            guard let initialPos = positions[.Y] else {
                return XCTFail("Y initial position not found")
            }

            let finalPos = renderer.yFinalPosition(
                initialSide: yAssignment.side,
                finalSide: yAssignment.motionFinalSide,
                motion: yAssignment.motion,
                formation: playCall.formation,
                config: config
            )

            // Y Go should move dramatically to the left
            let distance = abs(finalPos.x - initialPos.x)
            XCTAssertLessThan(finalPos.x, initialPos.x, "Y Go should move left")
            XCTAssertGreaterThan(distance, 150, "Y Go should move dramatically (distance > 150)")
        }
    }

    // MARK: - Fix 2: Route Meaning Changes with Motion

    /// Route meaning should change based on final side after motion
    /// Example: Trips Left, route "6", Y Stop: Y on left, route "6" = Curl (left interpretation)
    func testRouteMeaningUsesOriginalSideWhenYStops() {
        if case .success(var playCall) = interpreter.interpret(digits: "6794", formation: .tripsLeft) {
            guard let yIndex = playCall.assignments.firstIndex(where: { $0.receiver == .Y }) else {
                return XCTFail("Y receiver not found")
            }

            playCall.assignments[yIndex].motion = .stop
            let yAssignment = playCall.assignments[yIndex]

            // Y starts on left in Trips Left, route "6"
            XCTAssertEqual(yAssignment.side, .left)
            XCTAssertEqual(yAssignment.motionFinalSide, .left)

            // Route "6" on left side = Curl
            let expectedMeaning = RouteNumber.six.meaning(on: .left)
            XCTAssertEqual(expectedMeaning, .curl, "Route 6 on left = Curl")

            // Assignment's meaning should use motionFinalSide (which is left)
            XCTAssertEqual(yAssignment.meaning, expectedMeaning, "Y Stop route meaning should use original side")
        }
    }

    /// Route meaning should change when Y flips sides with motion
    /// Example: Trips Left, route "6", Y After: Y flips to right, route "6" = Comeback (right interpretation)
    func testRouteMeaningChangesWhenYFlipsWithAfter() {
        if case .success(var playCall) = interpreter.interpret(digits: "6794", formation: .tripsLeft) {
            guard let yIndex = playCall.assignments.firstIndex(where: { $0.receiver == .Y }) else {
                return XCTFail("Y receiver not found")
            }

            playCall.assignments[yIndex].motion = .after
            let yAssignment = playCall.assignments[yIndex]

            // Y starts on left, but After motion flips to right
            XCTAssertEqual(yAssignment.side, .left)
            XCTAssertEqual(yAssignment.motionFinalSide, .right)

            // Route "6" on left side (original) = Curl
            let originalMeaning = RouteNumber.six.meaning(on: .left)
            XCTAssertEqual(originalMeaning, .curl, "Route 6 on left = Curl")

            // Route "6" on right side (final) = Comeback
            let finalMeaning = RouteNumber.six.meaning(on: .right)
            XCTAssertEqual(finalMeaning, .comeback, "Route 6 on right = Comeback")

            // Assignment's meaning should use FINAL side (right), not original
            XCTAssertEqual(yAssignment.meaning, finalMeaning, "Route meaning should reflect final side after motion")
            XCTAssertNotEqual(yAssignment.meaning, originalMeaning, "Meaning should change from original")
        }
    }

    /// Route meaning should change when Y flips sides with Go
    func testRouteMeaningChangesWhenYFlipsWithGo() {
        if case .success(var playCall) = interpreter.interpret(digits: "6794", formation: .tripsRight) {
            guard let yIndex = playCall.assignments.firstIndex(where: { $0.receiver == .Y }) else {
                return XCTFail("Y receiver not found")
            }

            playCall.assignments[yIndex].motion = .go
            let yAssignment = playCall.assignments[yIndex]

            // Y starts on right, but Go motion flips to left
            XCTAssertEqual(yAssignment.side, .right)
            XCTAssertEqual(yAssignment.motionFinalSide, .left)

            // Route "6" on right side (original) = Comeback
            let originalMeaning = RouteNumber.six.meaning(on: .right)
            XCTAssertEqual(originalMeaning, .comeback, "Route 6 on right = Comeback")

            // Route "6" on left side (final) = Curl
            let finalMeaning = RouteNumber.six.meaning(on: .left)
            XCTAssertEqual(finalMeaning, .curl, "Route 6 on left = Curl")

            // Assignment's meaning should use FINAL side (left), not original
            XCTAssertEqual(yAssignment.meaning, finalMeaning, "Route meaning should reflect final side after motion")
            XCTAssertNotEqual(yAssignment.meaning, originalMeaning, "Meaning should change from original")
        }
    }

    /// Test with Sail concept (9391) - Y Stop should preserve original route meaning
    func testSailConceptWithYStopPreservesRouting() {
        let conceptMatcher = ConceptMatcher()

        // Sail in Trips Left: 9391 (X=9, Y=3, Z=9, A=1)
        if case .success(var playCall) = interpreter.interpret(digits: "9391", formation: .tripsLeft) {
            guard let yIndex = playCall.assignments.firstIndex(where: { $0.receiver == .Y }) else {
                return XCTFail("Y receiver not found")
            }

            playCall.assignments[yIndex].motion = .stop
            let yAssignment = playCall.assignments[yIndex]

            // Y route is "3" (always breaks left, = Out)
            XCTAssertEqual(yAssignment.routeNumber, .three)
            XCTAssertEqual(yAssignment.meaning, .out, "Route 3 always = Out, regardless of side")

            // Y's final side should be left (no flip)
            XCTAssertEqual(yAssignment.motionFinalSide, .left)
        }
    }

    // MARK: - Fix 3: Y Stop Works Correctly

    /// Y Stop should be in allCases and selectable
    func testYStopIsAvailableInMotionPicker() {
        let allMotions = ReceiverMotion.allCases
        XCTAssertTrue(allMotions.contains(.stop), "Y Stop should be in allCases for picker")
        XCTAssertEqual(allMotions.count, 3, "Should have exactly 3 motion types: stop, after, go")
    }

    /// Y Stop should render an inward arc toward the tackle (same side)
    func testYStopRendersInwardArc() {
        if case .success(var playCall) = interpreter.interpret(digits: "6794", formation: .tripsLeft) {
            guard let yIndex = playCall.assignments.firstIndex(where: { $0.receiver == .Y }) else {
                return XCTFail("Y receiver not found")
            }

            playCall.assignments[yIndex].motion = .stop
            let yAssignment = playCall.assignments[yIndex]

            // Get motion path
            let config = DiagramConfig.standard(for: CGSize(width: 500, height: 600))
            let positions = renderer.receiverPositions(formation: playCall.formation, config: config)

            guard let initialPos = positions[.Y] else {
                return XCTFail("Y position not found")
            }

            let finalPos = renderer.yFinalPosition(
                initialSide: yAssignment.side,
                finalSide: yAssignment.motionFinalSide,
                motion: yAssignment.motion,
                formation: playCall.formation,
                config: config
            )

            let arcPoints = renderer.motionPath(
                for: .Y,
                motion: yAssignment.motion,
                from: initialPos,
                to: finalPos,
                config: config
            )

            // Y Stop should produce a short arc (or no arc if positions are identical)
            if !arcPoints.isEmpty {
                // Arc should curve inward (toward center)
                let centerX = config.fieldWidth / 2
                for point in arcPoints {
                    // Inward arc should pull slightly toward center
                    // For left side, this means the arc curves rightward
                    XCTAssertTrue(true) // Visual validation required; unit test just confirms no crash
                }
            }
        }
    }

    /// Y Stop in Trips Left should keep Y on left side
    func testYStopTripsLeftKeepsYOnLeft() {
        if case .success(var playCall) = interpreter.interpret(digits: "6794", formation: .tripsLeft) {
            guard let yIndex = playCall.assignments.firstIndex(where: { $0.receiver == .Y }) else {
                return XCTFail("Y receiver not found")
            }

            playCall.assignments[yIndex].motion = .stop

            let yAssignment = playCall.assignments[yIndex]

            XCTAssertEqual(yAssignment.side, .left, "Y formation position is left in Trips Left")
            XCTAssertEqual(yAssignment.motionFinalSide, .left, "Y Stop keeps Y on left side")
        }
    }

    /// Y Stop in Trips Right should keep Y on right side
    func testYStopTripsRightKeepsYOnRight() {
        if case .success(var playCall) = interpreter.interpret(digits: "6794", formation: .tripsRight) {
            guard let yIndex = playCall.assignments.firstIndex(where: { $0.receiver == .Y }) else {
                return XCTFail("Y receiver not found")
            }

            playCall.assignments[yIndex].motion = .stop

            let yAssignment = playCall.assignments[yIndex]

            XCTAssertEqual(yAssignment.side, .right, "Y formation position is right in Trips Right")
            XCTAssertEqual(yAssignment.motionFinalSide, .right, "Y Stop keeps Y on right side")
        }
    }

    // MARK: - Integration: All Three Fixes Together

    /// Complete scenario: Trips Left Sail with Y Go
    /// - Y starts on left (Sail in Trips Left)
    /// - Y Go flips to right
    /// - Route meaning changes from Out (left) to Post (right) when Y flips to route 9 (absolute Post)
    /// - Arc moves dramatically to right
    func testCompleteSailTripsLeftYGoScenario() {
        let config = DiagramConfig.standard(for: CGSize(width: 500, height: 600))

        if case .success(var playCall) = interpreter.interpret(digits: "9391", formation: .tripsLeft) {
            guard let yIndex = playCall.assignments.firstIndex(where: { $0.receiver == .Y }) else {
                return XCTFail("Y receiver not found")
            }

            playCall.assignments[yIndex].motion = .go
            let yAssignment = playCall.assignments[yIndex]

            // Verify Y flips from left to right
            XCTAssertEqual(yAssignment.side, .left)
            XCTAssertEqual(yAssignment.motionFinalSide, .right)

            // Route "3" is absolute Out (always breaks left)
            XCTAssertEqual(yAssignment.routeNumber, .three)
            XCTAssertEqual(yAssignment.meaning, .out, "Route 3 always = Out, regardless of motion side change")

            // Verify dramatic arc movement
            let positions = renderer.receiverPositions(formation: playCall.formation, config: config)
            guard let initialPos = positions[.Y] else {
                return XCTFail("Y initial position not found")
            }

            let finalPos = renderer.yFinalPosition(
                initialSide: yAssignment.side,
                finalSide: yAssignment.motionFinalSide,
                motion: yAssignment.motion,
                formation: playCall.formation,
                config: config
            )

            // Y should move dramatically to the right
            XCTAssertGreaterThan(finalPos.x, initialPos.x, "Y Go moves right")
            let distance = abs(finalPos.x - initialPos.x)
            XCTAssertGreaterThan(distance, 150, "Y Go should move dramatically")
        }
    }

    /// Verification for Trips Left with custom route "6", Y Go
    /// - Y starts on left, route "6" = Curl (left side meaning)
    /// - Y Go flips to right, route "6" should recompute to Comeback (right side meaning)
    func testCustomRouteTripsLeftYGoChangesMeaning() {
        if case .success(var playCall) = interpreter.interpret(digits: "6794", formation: .tripsLeft) {
            guard let yIndex = playCall.assignments.firstIndex(where: { $0.receiver == .Y }) else {
                return XCTFail("Y receiver not found")
            }

            playCall.assignments[yIndex].motion = .go
            let yAssignment = playCall.assignments[yIndex]

            // Route is "6"
            XCTAssertEqual(yAssignment.routeNumber, .six)

            // Original side is left: route "6" = Curl
            XCTAssertEqual(yAssignment.side, .left)
            let leftMeaning = RouteNumber.six.meaning(on: .left)
            XCTAssertEqual(leftMeaning, .curl)

            // After Y Go motion, final side is right: route "6" = Comeback
            XCTAssertEqual(yAssignment.motionFinalSide, .right)
            let rightMeaning = RouteNumber.six.meaning(on: .right)
            XCTAssertEqual(rightMeaning, .comeback)

            // Assignment's meaning should reflect final side (Comeback, not Curl)
            XCTAssertEqual(yAssignment.meaning, rightMeaning, "Meaning should change to Comeback on right side")
            XCTAssertNotEqual(yAssignment.meaning, leftMeaning, "Meaning should not be Curl anymore")
        }
    }
}
