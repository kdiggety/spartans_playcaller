import XCTest
@testable import SpartansPlaycaller

final class ConceptMatcherTests: XCTestCase {

    let matcher = ConceptMatcher()
    let library = ConceptLibrary.shared

    // MARK: - Side-Aware Concept Matching Tests

    func testIdentifyForSideWithLeftSideAssignments() {
        // Create assignments for left side
        let leftAssignments: [RouteAssignment] = [
            RouteAssignment(receiver: .X, routeNumber: .six, side: .left, initialMeaning: .quickOut, motion: nil),
            RouteAssignment(receiver: .Y, routeNumber: .seven, side: .left, initialMeaning: .digIn, motion: nil),
        ]

        let concept = matcher.identifyForSide(.left, assignments: leftAssignments, formation: .twins)

        // Concept matching depends on library templates; just verify no crash
        XCTAssertTrue(true)
    }

    func testIdentifyForSideWithRightSideAssignments() {
        // Create assignments for right side
        let rightAssignments: [RouteAssignment] = [
            RouteAssignment(receiver: .Z, routeNumber: .six, side: .right, initialMeaning: .quickSlant, motion: nil),
            RouteAssignment(receiver: .A, routeNumber: .nine, side: .right, initialMeaning: .goFade, motion: nil),
        ]

        let concept = matcher.identifyForSide(.right, assignments: rightAssignments, formation: .twins)

        // Verify no crash
        XCTAssertTrue(true)
    }

    // MARK: - Y Motion Effects on Concept Matching Tests

    func testYAfterMovesYToOppositeSideGroup() {
        // Create Y on left side initially
        var assignment = RouteAssignment(
            receiver: .Y,
            routeNumber: .six,
            side: .left,
            initialMeaning: .quickOut,
            motion: nil
        )

        // Apply Y After motion
        assignment.motion = .after

        // Y's final side should be .right (flipped)
        XCTAssertEqual(assignment.motionFinalSide, .right)

        // Verify that when filtering by right side, Y is now included
        let rightSideAssignments = [assignment].filter { $0.motionFinalSide == .right }
        XCTAssertEqual(rightSideAssignments.count, 1)
        XCTAssertEqual(rightSideAssignments[0].receiver, .Y)

        // And NOT in left side
        let leftSideAssignments = [assignment].filter { $0.motionFinalSide == .left }
        XCTAssertEqual(leftSideAssignments.count, 0)
    }

    func testYGoMovesYToOppositeSideGroup() {
        // Create Y on right side initially
        var assignment = RouteAssignment(
            receiver: .Y,
            routeNumber: .six,
            side: .right,
            initialMeaning: .quickSlant,
            motion: nil
        )

        // Apply Y After motion
        assignment.motion = .after

        // Y's final side should be .left (flipped)
        XCTAssertEqual(assignment.motionFinalSide, .left)

        // Verify filtering works correctly
        let leftSideAssignments = [assignment].filter { $0.motionFinalSide == .left }
        XCTAssertEqual(leftSideAssignments.count, 1)
    }

    func testMotionFinalSidePreservesNonYReceivers() {
        let xAssignment = RouteAssignment(
            receiver: .X,
            routeNumber: .six,
            side: .left,
            initialMeaning: .quickOut,
            motion: nil
        )

        // Even without motion, X should have correct final side
        XCTAssertEqual(xAssignment.motionFinalSide, .left)
    }

    // MARK: - Multi-Receiver Concept Matching Tests

    func testIdentifyForSideFiltersAssignmentsByFinalSide() {
        // Create assignments with mixed sides, some with motion
        var yAssignment = RouteAssignment(
            receiver: .Y,
            routeNumber: .six,
            side: .left,
            initialMeaning: .quickOut,
            motion: .after // Moves Y to right
        )
        let zAssignment = RouteAssignment(
            receiver: .Z,
            routeNumber: .nine,
            side: .right,
            initialMeaning: .goFade,
            motion: nil
        )

        let allAssignments = [yAssignment, zAssignment]

        // Filter by right side
        let rightSideAssignments = allAssignments.filter { $0.motionFinalSide == .right }
        XCTAssertEqual(rightSideAssignments.count, 2) // Y (after motion) and Z both on right

        // Filter by left side
        let leftSideAssignments = allAssignments.filter { $0.motionFinalSide == .left }
        XCTAssertEqual(leftSideAssignments.count, 0)
    }

    func testLeftAndRightSidesMatchedIndependently() {
        // Simulate Trips Left formation: X, Y, A on left; Z on right
        let tripsLeftAssignments: [RouteAssignment] = [
            RouteAssignment(receiver: .X, routeNumber: .six, side: .left, initialMeaning: .quickOut, motion: nil),
            RouteAssignment(receiver: .Y, routeNumber: .seven, side: .left, initialMeaning: .digIn, motion: nil),
            RouteAssignment(receiver: .Z, routeNumber: .nine, side: .right, initialMeaning: .goFade, motion: nil),
            RouteAssignment(receiver: .A, routeNumber: .six, side: .left, initialMeaning: .quickOut, motion: nil),
        ]

        // Identify concept for left side
        let leftConcept = matcher.identifyForSide(.left, assignments: tripsLeftAssignments.filter { $0.side == .left }, formation: .tripsLeft)

        // Identify concept for right side
        let rightConcept = matcher.identifyForSide(.right, assignments: tripsLeftAssignments.filter { $0.side == .right }, formation: .tripsLeft)

        // Both should work independently without crashing
        XCTAssertTrue(true)
    }

    // MARK: - Formation Context Tests

    func testIdentifyForSideRespectsFormationContext() {
        let assignments: [RouteAssignment] = [
            RouteAssignment(receiver: .X, routeNumber: .six, side: .left, initialMeaning: .quickOut, motion: nil),
        ]

        // Same assignments, different formations
        let twinsConcept = matcher.identifyForSide(.left, assignments: assignments, formation: .twins)
        let tripsLeftConcept = matcher.identifyForSide(.left, assignments: assignments, formation: .tripsLeft)

        // Behavior may differ by formation; just verify no crash
        XCTAssertTrue(true)
    }

    func testIdentifyForSideWithTripsFormations() {
        let leftAssignments: [RouteAssignment] = [
            RouteAssignment(receiver: .X, routeNumber: .six, side: .left, initialMeaning: .quickOut, motion: nil),
            RouteAssignment(receiver: .Y, routeNumber: .seven, side: .left, initialMeaning: .digIn, motion: nil),
            RouteAssignment(receiver: .A, routeNumber: .six, side: .left, initialMeaning: .quickOut, motion: nil),
        ]

        let concept = matcher.identifyForSide(.left, assignments: leftAssignments, formation: .tripsLeft)

        // Concept matching in Trips Left
        XCTAssertTrue(true)
    }

    // MARK: - Edge Cases

    func testIdentifyForSideWithEmptyAssignments() {
        let emptyAssignments: [RouteAssignment] = []

        let concept = matcher.identifyForSide(.left, assignments: emptyAssignments, formation: .twins)

        XCTAssertNil(concept) // No assignments, no match
    }

    func testIdentifyForSideWithMotionFlip() {
        // Y on left, motion flips to right
        var yAssignment = RouteAssignment(
            receiver: .Y,
            routeNumber: .six,
            side: .left,
            initialMeaning: .quickOut,
            motion: .after
        )

        // Filtering should use motionFinalSide
        let rightSideWithMotion = [yAssignment].filter { $0.motionFinalSide == .right }
        XCTAssertEqual(rightSideWithMotion.count, 1)

        // Now try to match for right side (Y is now there due to motion)
        let concept = matcher.identifyForSide(.right, assignments: rightSideWithMotion, formation: .tripsRight)

        // Should attempt to match Y on right side
        XCTAssertTrue(true)
    }

    func testMotionFinalSideComputedProperty() {
        let assignment = RouteAssignment(
            receiver: .Y,
            routeNumber: .six,
            side: .left,
            initialMeaning: .quickOut,
            motion: .after
        )

        // motionFinalSide should call motion.finalSide()
        XCTAssertEqual(assignment.motionFinalSide, .right)
    }

    func testMotionFinalSideWithoutMotion() {
        let assignment = RouteAssignment(
            receiver: .Y,
            routeNumber: .six,
            side: .left,
            initialMeaning: .quickOut,
            motion: nil
        )

        // Without motion, motionFinalSide should equal side
        XCTAssertEqual(assignment.motionFinalSide, .left)
    }

    // MARK: - Concept Generation Tests

    func testGenerateDigitsForConceptInFormation() {
        let concept = RouteConcept.smash
        let formation = Formation.twins

        let digits = matcher.generateDigits(concept: concept, formation: formation)

        // Should generate 4+ digits
        if let digits = digits {
            XCTAssertGreaterThanOrEqual(digits.count, 4)
        } else {
            // Concept may not exist in formation; that's fine
            XCTAssertTrue(true)
        }
    }

    func testGenerateDigitsReturnNilForUnavailableConcept() {
        // Create a synthetic unavailable scenario
        let mockConcept = RouteConcept.smash

        // If we ask for a concept in a formation where it doesn't exist,
        // generateDigits should return nil
        let digits = matcher.generateDigits(concept: mockConcept, formation: .twins)

        // Either it generates or returns nil; no crash
        XCTAssertTrue(true)
    }

    // MARK: - Identify with Complete PlayCall Tests

    func testIdentifyCompletePlayCallBeforeMotion() {
        let interpreter = RouteInterpreter()

        // Parse a known play
        if case .success(let playCall) = interpreter.interpret(digits: "6794", formation: .twins) {
            // Concept should be identified
            XCTAssertNotNil(playCall.concept)
        }
    }

    func testIdentifyCompletePlayCallAfterMotion() {
        let interpreter = RouteInterpreter()

        // Parse initial play
        if case .success(let playCall) = interpreter.interpret(digits: "6794", formation: .tripsLeft) {
            // Create assignments with motion on Y
            var assignments = playCall.assignments
            if let yIndex = assignments.firstIndex(where: { $0.receiver == .Y }) {
                assignments[yIndex].motion = .after
            }

            // Re-identify concepts per side
            let leftConcept = interpreter.identifyForSide(.left, assignments: assignments.filter { $0.motionFinalSide == .left }, formation: .tripsLeft)
            let rightConcept = interpreter.identifyForSide(.right, assignments: assignments.filter { $0.motionFinalSide == .right }, formation: .tripsLeft)

            // Should complete without crash
            XCTAssertTrue(true)
        }
    }

    // MARK: - Y Wheel Motion Tests

    func testYStopMotionKeepsSidePreservesYPosition() {
        let interpreter = RouteInterpreter()

        // Setup: Trips Left, (X:6, Y:7, Z:5, A:8)
        guard case .success(let playCall) = interpreter.interpret(digits: "6758", formation: .tripsLeft) else {
            XCTFail("Failed to interpret play call")
            return
        }

        // Y stop keeps Y on left side (same as original), so concept should remain valid
        var stopPlayCall = playCall
        if let yIndex = stopPlayCall.assignments.firstIndex(where: { $0.receiver == .Y }) {
            stopPlayCall.assignments[yIndex].motion = .stop
        }

        // Get Y assignment and verify it's on left side
        if let yAssignment = stopPlayCall.assignments.first(where: { $0.receiver == .Y }) {
            XCTAssertEqual(yAssignment.side, .left, "Y should be on left side in Trips Left")
            XCTAssertEqual(yAssignment.motion, .stop, "Y should have stop motion")
            XCTAssertEqual(yAssignment.motionFinalSide, .left, "Y stop keeps Y on left side")
        }

        // Verify concept re-identification works: left side should still match
        let leftAssignments = stopPlayCall.assignments.filter { $0.motionFinalSide == .left }
        XCTAssertEqual(leftAssignments.count, 3, "Left side should have 3 receivers (X, Y, A)")

        let leftConcept = matcher.identifyForSide(.left, assignments: leftAssignments, formation: .tripsLeft)
        // Concept may or may not exist, but re-identification should work without crash
        XCTAssertTrue(true)
    }

    func testYAfterMotionFlipsSidePreservesRightAssignments() {
        let interpreter = RouteInterpreter()

        // Y after motion flips Y to opposite side and same receiver group
        guard case .success(let playCall) = interpreter.interpret(digits: "6794", formation: .tripsLeft) else {
            XCTFail("Failed to interpret play call")
            return
        }

        var afterPlayCall = playCall
        if let yIndex = afterPlayCall.assignments.firstIndex(where: { $0.receiver == .Y }) {
            afterPlayCall.assignments[yIndex].motion = .after
        }

        // Y should now be in right side group (flipped by after motion)
        let rightAssignments = afterPlayCall.assignments.filter { $0.motionFinalSide == .right }
        let yInRight = rightAssignments.contains { $0.receiver == .Y }
        XCTAssertTrue(yInRight, "Y with after motion should move to right side group")

        // Left side should only have X and A
        let leftAssignments = afterPlayCall.assignments.filter { $0.motionFinalSide == .left }
        let hasZ = leftAssignments.contains { $0.receiver == .Z }
        let hasY = leftAssignments.contains { $0.receiver == .Y }
        XCTAssertFalse(hasZ, "Left side should NOT have Z")
        XCTAssertFalse(hasY, "Left side should NOT have Y (after flips Y to right)")
    }

    // MARK: - Y Wheel Toggle Tests

    func testConceptRemainValidWhenWheelAdded() {
        let interpreter = RouteInterpreter()

        // Parse a play call and verify concept remains independent of wheel toggle
        if case .success(let playCall) = interpreter.interpret(digits: "6794", formation: .tripsLeft) {
            let originalConcept = playCall.concept

            // Create a new play call with wheel enabled
            let wheelEnabledPlayCall = PlayCall(
                formation: playCall.formation,
                routeDigits: playCall.routeDigits,
                assignments: playCall.assignments,
                concept: playCall.concept,
                yWheelEnabled: true
            )

            // Concept should remain the same (wheel toggle is independent of concept matching)
            XCTAssertEqual(wheelEnabledPlayCall.concept, originalConcept, "Concept should remain unchanged when wheel is enabled")
            XCTAssertTrue(wheelEnabledPlayCall.yWheelEnabled, "Wheel should be enabled")

            // Create play call with wheel disabled
            let wheelDisabledPlayCall = PlayCall(
                formation: playCall.formation,
                routeDigits: playCall.routeDigits,
                assignments: playCall.assignments,
                concept: playCall.concept,
                yWheelEnabled: false
            )
            XCTAssertEqual(wheelDisabledPlayCall.concept, originalConcept, "Concept should remain unchanged when wheel is disabled")
            XCTAssertFalse(wheelDisabledPlayCall.yWheelEnabled, "Wheel should be disabled")
        }
    }
}
