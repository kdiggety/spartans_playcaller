import XCTest
@testable import SpartansPlaycaller

class ReceiverMotionWheelToggleTests: XCTestCase {
    func testAfterMotionWithWheelFlipsSide() {
        let motion = ReceiverMotion.after
        let finalSide = motion.finalSide(originalSide: .left)
        XCTAssertEqual(finalSide, .right, "After motion flips sides regardless of wheel")
    }

    func testStopMotionWithWheelStaysSide() {
        let motion = ReceiverMotion.stop
        let finalSide = motion.finalSide(originalSide: .left)
        XCTAssertEqual(finalSide, .left, "Stop motion keeps same side regardless of wheel")
    }

    func testWheelDescriptionIndependent() {
        XCTAssertEqual(ReceiverMotion.stop.description, "Y Stop")
        XCTAssertEqual(ReceiverMotion.after.description, "Y After")
        XCTAssertEqual(ReceiverMotion.go.description, "Y Go")
    }
}
