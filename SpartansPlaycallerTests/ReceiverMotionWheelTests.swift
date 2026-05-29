import XCTest
@testable import SpartansPlaycaller

class ReceiverMotionWheelTests: XCTestCase {
    func testYWheelLeftSideStayLeft() {
        let motion = ReceiverMotion.wheel
        let finalSide = motion.finalSide(originalSide: .left)

        XCTAssertEqual(finalSide, .left, "Y wheel from left side should stay left (semi-circle behind formation)")
    }

    func testYWheelRightSideStayRight() {
        let motion = ReceiverMotion.wheel
        let finalSide = motion.finalSide(originalSide: .right)

        XCTAssertEqual(finalSide, .right, "Y wheel from right side should stay right")
    }

    func testYWheelDescription() {
        let motion = ReceiverMotion.wheel
        XCTAssertEqual(motion.rawValue, "Y Wheel", "Y wheel should have descriptive name")
    }
}
