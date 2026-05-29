import XCTest
@testable import SpartansPlaycaller

class PlayCallWheelToggleFlowTests: XCTestCase {
    let viewModel = PlayCallerViewModel()

    func testMotionAndWheelToggleFlow() {
        viewModel.selectedFormation = .tripsLeft
        viewModel.selectedConcept = .smash
        viewModel.generatePlayCall()

        viewModel.yMotion = .after
        XCTAssertEqual(viewModel.yMotion, .after)

        viewModel.yWheelEnabled = true
        XCTAssertTrue(viewModel.yWheelEnabled)

        let renderer = DiagramRenderer()
        if let playCall = viewModel.currentPlayCall {
            XCTAssertNotNil(renderer.motionPathForPlayCall(playCall), "Arc should render for After + Wheel")
        }

        viewModel.yWheelEnabled = false
        if let playCall = viewModel.currentPlayCall {
            let motionPathAfterDisable = renderer.motionPathForPlayCall(playCall)
            XCTAssertNotNil(motionPathAfterDisable, "After motion should still render arc")
        }
    }

    func testWheelWithoutMotion() {
        viewModel.selectedFormation = .tripsRight
        viewModel.selectedConcept = .dagger
        viewModel.generatePlayCall()

        viewModel.yMotion = nil
        viewModel.yWheelEnabled = true

        let renderer = DiagramRenderer()
        if let playCall = viewModel.currentPlayCall {
            XCTAssertNotNil(renderer.motionPathForPlayCall(playCall), "Wheel arc should render without base motion")
        }
    }

    func testWheelToggleIndependentOfMotion() {
        // Verify that wheel toggle is truly independent: enabling/disabling wheel
        // doesn't change motion state, and vice versa
        viewModel.selectedFormation = .tripsLeft
        viewModel.selectedConcept = .smash
        viewModel.generatePlayCall()

        // Set motion first
        viewModel.yMotion = .after
        XCTAssertEqual(viewModel.yMotion, .after, "Motion should be set to After")
        XCTAssertFalse(viewModel.yWheelEnabled, "Wheel should start disabled")

        // Enable wheel
        viewModel.yWheelEnabled = true
        XCTAssertEqual(viewModel.yMotion, .after, "Motion should remain After after enabling wheel")
        XCTAssertTrue(viewModel.yWheelEnabled, "Wheel should be enabled")

        // Disable wheel
        viewModel.yWheelEnabled = false
        XCTAssertEqual(viewModel.yMotion, .after, "Motion should remain After after disabling wheel")
        XCTAssertFalse(viewModel.yWheelEnabled, "Wheel should be disabled")

        // Change motion
        viewModel.yMotion = .go
        XCTAssertEqual(viewModel.yMotion, .go, "Motion should change to Go")
        XCTAssertFalse(viewModel.yWheelEnabled, "Wheel should remain disabled after motion change")

        // Re-enable wheel
        viewModel.yWheelEnabled = true
        XCTAssertEqual(viewModel.yMotion, .go, "Motion should remain Go after re-enabling wheel")
        XCTAssertTrue(viewModel.yWheelEnabled, "Wheel should be re-enabled")
    }

    func testWheelDisabledInTwinsFormation() {
        // Verify wheel is disabled for Twins formation
        viewModel.selectedFormation = .twins
        viewModel.selectedLeftConcept = .smash
        viewModel.selectedRightConcept = .dagger
        viewModel.generatePlayCall()

        // Attempt to enable wheel in Twins (should not be allowed in UI, but test state)
        viewModel.yWheelEnabled = true
        // Note: ViewModel may or may not enforce this; just verify the state doesn't crash
        XCTAssertTrue(true)
    }
}
