import XCTest
@testable import SpartansPlaycaller

final class ReceiverMotionTests: XCTestCase {

    /// Test that .after motion preserves original side for left-aligned receiver
    func testStopMotionPreservesLeftSide() {
        let motion = ReceiverMotion.after
        let originalSide = FieldSide.left
        let finalSide = motion.finalSide(originalSide: originalSide)
        XCTAssertEqual(finalSide, .left)
    }

    /// Test that .after motion preserves original side for right-aligned receiver
    func testStopMotionPreservesRightSide() {
        let motion = ReceiverMotion.after
        let originalSide = FieldSide.right
        let finalSide = motion.finalSide(originalSide: originalSide)
        XCTAssertEqual(finalSide, .right)
    }

    /// Test that .after motion preserves center for H back
    func testStopMotionPreservesCenter() {
        let motion = ReceiverMotion.after
        let originalSide = FieldSide.center
        let finalSide = motion.finalSide(originalSide: originalSide)
        XCTAssertEqual(finalSide, .center)
    }

    /// Test that .after motion flips left to right
    func testAfterMotionFlipsLeftToRight() {
        let motion = ReceiverMotion.after
        let originalSide = FieldSide.left
        let finalSide = motion.finalSide(originalSide: originalSide)
        XCTAssertEqual(finalSide, .right)
    }

    /// Test that .after motion flips right to left
    func testAfterMotionFlipsRightToLeft() {
        let motion = ReceiverMotion.after
        let originalSide = FieldSide.right
        let finalSide = motion.finalSide(originalSide: originalSide)
        XCTAssertEqual(finalSide, .left)
    }

    /// Test that .after motion preserves center for H back
    func testAfterMotionPreservesCenter() {
        let motion = ReceiverMotion.after
        let originalSide = FieldSide.center
        let finalSide = motion.finalSide(originalSide: originalSide)
        XCTAssertEqual(finalSide, .center)
    }

    /// Test ReceiverMotion is CaseIterable (all cases present)
    func testReceiverMotionHasAllCases() {
        let allCases = ReceiverMotion.allCases
        XCTAssertEqual(allCases.count, 2)
        XCTAssertTrue(allCases.contains(.after))
        XCTAssertTrue(allCases.contains(.after))
    }

    /// Test ReceiverMotion Identifiable conformance
    func testReceiverMotionIdentifiable() {
        let motion = ReceiverMotion.after
        XCTAssertEqual(motion.id, "Stop")
        XCTAssertEqual(ReceiverMotion.after.id, "After")
    }
}
