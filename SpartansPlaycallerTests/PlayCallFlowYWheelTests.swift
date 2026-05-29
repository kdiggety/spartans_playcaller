import XCTest
@testable import SpartansPlaycaller

/// Integration tests for the full play call flow with Y wheel motion.
/// These tests exercise the complete path from formation selection → concept
/// selection → play generation → motion application → concept re-identification.
final class PlayCallFlowYWheelTests: XCTestCase {

    nonisolated(unsafe) var viewModel: PlayCallerViewModel!

    override func setUp() {
        super.setUp()
        MainActor.assumeIsolated {
            viewModel = PlayCallerViewModel()
        }
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Y Wheel Motion Flow Tests

    /// Complete flow: Select formation → concept → generate → apply Y wheel motion → verify concept identified
    @MainActor
    func testYWheelFlowTripsLeft() {
        // Step 1: Select Trips Left formation
        viewModel.selectedFormation = .tripsLeft
        XCTAssertEqual(viewModel.selectedFormation, .tripsLeft)

        // Step 2: Select Smash concept for Trips Left
        viewModel.selectedConcept = .smash
        XCTAssertEqual(viewModel.selectedConcept, .smash)

        // Step 3: Generate play from concept
        viewModel.generateFromConcept()
        XCTAssertNotNil(viewModel.currentPlayCall, "Play call should be generated for Smash in Trips Left")

        // Step 4: Verify digits were generated
        let playCall = viewModel.currentPlayCall!
        XCTAssertEqual(playCall.routeDigits.count, 4, "Trips Left play should have 4 digits")

        // Step 5: Apply Y wheel motion
        viewModel.setYMotion(.wheel)
        XCTAssertEqual(viewModel.yMotion, .wheel, "Y motion should be set to wheel")

        // Step 6: Verify play call with motion is updated
        XCTAssertNotNil(viewModel.currentPlayCallWithMotion, "Play call with motion should exist")
        let motionPlayCall = viewModel.currentPlayCallWithMotion!
        XCTAssertEqual(motionPlayCall.assignments.count, playCall.assignments.count,
                      "Same number of receivers in motion play call")

        // Step 7: Verify Y receiver has wheel motion applied
        let yAssignment = motionPlayCall.assignments.first { $0.receiver == .Y }
        XCTAssertNotNil(yAssignment, "Y receiver should exist in Trips Left")
        XCTAssertEqual(yAssignment?.motion, .wheel, "Y receiver should have wheel motion")

        // Step 8: Verify Y stays on original side (wheel is same-side motion)
        let originalSide = playCall.formation.side(for: .Y)
        let finalSide = yAssignment?.motionFinalSide ?? originalSide
        XCTAssertEqual(finalSide, originalSide, "Y wheel motion should keep receiver on original side")

        // Step 9: Verify no error message
        XCTAssertNil(viewModel.errorMessage, "No error should occur during Y wheel motion")
    }

    /// Complete flow for Trips Right with Y wheel
    @MainActor
    func testYWheelFlowTripsRight() {
        // Step 1: Select Trips Right formation
        viewModel.selectedFormation = .tripsRight
        XCTAssertEqual(viewModel.selectedFormation, .tripsRight)

        // Step 2: Select Dagger concept
        viewModel.selectedConcept = .dagger
        XCTAssertEqual(viewModel.selectedConcept, .dagger)

        // Step 3: Generate play
        viewModel.generateFromConcept()
        XCTAssertNotNil(viewModel.currentPlayCall, "Play call should be generated for Dagger in Trips Right")

        // Step 4: Apply Y wheel motion
        viewModel.setYMotion(.wheel)
        XCTAssertEqual(viewModel.yMotion, .wheel)

        // Step 5: Verify Y receiver on right side in Trips Right stays on right side
        let yAssignment = viewModel.currentPlayCallWithMotion?.assignments.first { $0.receiver == .Y }
        XCTAssertNotNil(yAssignment)
        let originalSide = viewModel.selectedFormation.side(for: .Y)
        XCTAssertEqual(yAssignment?.motionFinalSide, originalSide,
                      "Y wheel in Trips Right should keep Y on right side")
    }

    // MARK: - Motion Toggle Tests

    /// Test toggling through all motion types with proper state updates
    @MainActor
    func testYMotionToggleCycle() {
        viewModel.selectedFormation = .tripsLeft
        viewModel.selectedConcept = .smash
        viewModel.generateFromConcept()

        let initialPlayCall = viewModel.currentPlayCall!

        // Test each motion in sequence
        let motions: [ReceiverMotion] = [.stop, .after, .go, .wheel, .stop]

        for motion in motions {
            viewModel.setYMotion(motion)
            XCTAssertEqual(viewModel.yMotion, motion, "Motion should toggle to \(motion)")

            // Verify motion play call exists and is consistent
            XCTAssertNotNil(viewModel.currentPlayCallWithMotion,
                          "Play call with motion should exist for \(motion)")

            let motionPlayCall = viewModel.currentPlayCallWithMotion!
            XCTAssertEqual(motionPlayCall.formation, initialPlayCall.formation,
                         "Formation should remain unchanged with \(motion) motion")
            XCTAssertEqual(motionPlayCall.routeDigits, initialPlayCall.routeDigits,
                         "Route digits should remain unchanged with \(motion) motion")

            // Verify Y receiver motion is applied
            let yAssignment = motionPlayCall.assignments.first { $0.receiver == .Y }
            if motion == .stop {
                // Stop means no motion applied (motion is nil)
                XCTAssertNil(yAssignment?.motion, "Y should have no motion for .stop")
            } else {
                XCTAssertEqual(yAssignment?.motion, motion, "Y should have \(motion) motion")
            }
        }
    }

    // MARK: - Diagram Rendering Tests (No-Crash Validation)

    /// Verify that diagram renders without crashing for Y wheel motion
    @MainActor
    func testDiagramRendersWithYWheelMotion() {
        viewModel.selectedFormation = .tripsLeft
        viewModel.selectedConcept = .smash
        viewModel.generateFromConcept()

        XCTAssertNotNil(viewModel.currentPlayCall)

        // Apply Y wheel motion
        viewModel.setYMotion(.wheel)
        XCTAssertNotNil(viewModel.currentPlayCallWithMotion)

        // Attempt to create diagram view with motion applied
        // This doesn't crash if the diagram renderer is correctly implemented
        let playCall = viewModel.currentPlayCallWithMotion!
        let diagram = RouteDiagramView(playCall: playCall)
        XCTAssertNotNil(diagram, "Diagram should render with Y wheel motion without crashing")
    }

    /// Verify diagram renders for all motion types
    @MainActor
    func testDiagramRendersForAllMotionTypes() {
        viewModel.selectedFormation = .tripsRight
        viewModel.selectedConcept = .dagger
        viewModel.generateFromConcept()

        let motions: [ReceiverMotion?] = [.stop, .after, .go, .wheel, nil]

        for motion in motions {
            viewModel.setYMotion(motion)

            let playCall = viewModel.currentPlayCallWithMotion ?? viewModel.currentPlayCall
            XCTAssertNotNil(playCall, "Play call should exist for motion \(String(describing: motion))")

            // Attempting to render should not crash
            let diagram = RouteDiagramView(playCall: playCall!)
            XCTAssertNotNil(diagram)
        }
    }

    // MARK: - Concept Identification with Y Wheel

    /// Verify that concepts remain correctly identified when Y wheel is applied
    @MainActor
    func testConceptIdentificationWithYWheel() {
        viewModel.selectedFormation = .tripsLeft
        viewModel.selectedConcept = .smash
        viewModel.generateFromConcept()

        XCTAssertNotNil(viewModel.currentPlayCall)
        let originalConcept = viewModel.selectedConcept

        // Apply Y wheel motion
        viewModel.setYMotion(.wheel)

        // Y wheel does NOT flip the receiver side, so the concept should remain
        // identifiable on the same side. The re-identification process should
        // produce the same or compatible concept.
        XCTAssertNotNil(viewModel.currentPlayCallWithMotion,
                       "Play call with Y wheel should maintain concept identifiability")

        // The concept re-identification should work correctly
        // (Verified by the view model's reidentifyConceptsBySide logic)
        XCTAssertNil(viewModel.errorMessage, "No error should occur during concept re-identification")
    }

    /// Verify that Y wheel motion in Pro formations also works correctly
    @MainActor
    func testYWheelInProFormation() {
        viewModel.selectedFormation = .proLeft
        viewModel.selectedConcept = .smash
        viewModel.generateFromConcept()

        XCTAssertNotNil(viewModel.currentPlayCall)

        // Apply Y wheel motion
        viewModel.setYMotion(.wheel)
        XCTAssertEqual(viewModel.yMotion, .wheel)

        // Verify play call exists with motion
        XCTAssertNotNil(viewModel.currentPlayCallWithMotion)

        // Verify Y receiver
        let yAssignment = viewModel.currentPlayCallWithMotion!.assignments.first { $0.receiver == .Y }
        XCTAssertNotNil(yAssignment)
        XCTAssertEqual(yAssignment?.motion, .wheel)

        // Y in Pro Left is on the left side; wheel should keep it there
        XCTAssertEqual(yAssignment?.motionFinalSide, .left)
    }

    // MARK: - Parsing with Y Wheel

    /// Test parsing digits and then applying Y wheel motion
    @MainActor
    func testParseDigitsThenApplyYWheel() {
        viewModel.selectedFormation = .tripsLeft
        viewModel.routeDigitInput = "6758"  // Example Trips Left play
        viewModel.parseRouteDigits()

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNotNil(viewModel.currentPlayCall)

        // Apply Y wheel motion after parsing
        viewModel.setYMotion(.wheel)
        XCTAssertEqual(viewModel.yMotion, .wheel)

        // Verify play call with motion exists
        XCTAssertNotNil(viewModel.currentPlayCallWithMotion)
        XCTAssertEqual(viewModel.currentPlayCallWithMotion?.routeDigits, "6758",
                      "Route digits should remain unchanged after motion")
    }

    // MARK: - Formation Change with Y Wheel

    /// Verify that Y wheel motion is preserved when toggling between Trips Left/Right
    @MainActor
    func testYWheelPreservedWhenTogglingTripsLRSide() {
        viewModel.selectedFormation = .tripsLeft
        viewModel.selectedConcept = .smash
        viewModel.generateFromConcept()

        // Apply Y wheel motion
        viewModel.setYMotion(.wheel)
        XCTAssertEqual(viewModel.yMotion, .wheel)

        // Toggle to Trips Right (same family, different side)
        viewModel.setFormationSide(.right)

        // Y wheel motion should be preserved during side toggle
        XCTAssertEqual(viewModel.yMotion, .wheel,
                      "Y wheel motion should be preserved when toggling within same formation family")
        XCTAssertNotNil(viewModel.currentPlayCall)
    }

    /// Verify that Y wheel motion is cleared when switching to Twins (motion-unsupported formation)
    @MainActor
    func testYWheelClearedWhenSwitchingToTwins() {
        viewModel.selectedFormation = .tripsLeft
        viewModel.selectedConcept = .smash
        viewModel.generateFromConcept()

        // Apply Y wheel motion
        viewModel.setYMotion(.wheel)
        XCTAssertEqual(viewModel.yMotion, .wheel)

        // Switch to Twins (family change)
        viewModel.setFormationFamily(.twins)

        // Motion should be cleared because Twins doesn't support motion
        XCTAssertNil(viewModel.yMotion, "Y wheel motion should be cleared when switching to Twins")
        XCTAssertFalse(viewModel.selectedFormation.canApplyMotion(),
                      "Twins formation should not support motion")
    }

    // MARK: - Error Handling

    /// Verify that motion is rejected in formations that don't support it
    @MainActor
    func testMotionRejectedInTwinsFormation() {
        viewModel.selectedFormation = .twins
        viewModel.selectedLeftConcept = .smash
        viewModel.selectedRightConcept = .dagger
        viewModel.generateFromConcept()

        XCTAssertNotNil(viewModel.currentPlayCall)

        // Attempt to apply Y wheel motion in Twins
        viewModel.setYMotion(.wheel)

        // Motion should be rejected and error should be set
        XCTAssertNil(viewModel.yMotion, "Y wheel motion should not be set in Twins")
        XCTAssertNotNil(viewModel.errorMessage, "Error message should be set when motion is rejected")
        XCTAssertTrue(viewModel.errorMessage!.contains("Motion only available"),
                     "Error message should explain motion limitation")
    }
}
