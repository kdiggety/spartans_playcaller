import XCTest
@testable import SpartansPlaycaller

final class ReceiverMotionTests: XCTestCase {

    /// Test that .stop motion preserves original side for left-aligned receiver
    func testStopMotionPreservesLeftSide() {
        let motion = ReceiverMotion.stop
        let originalSide = FieldSide.left
        let finalSide = motion.finalSide(originalSide: originalSide)
        XCTAssertEqual(finalSide, .left)
    }

    /// Test that .stop motion preserves original side for right-aligned receiver
    func testStopMotionPreservesRightSide() {
        let motion = ReceiverMotion.stop
        let originalSide = FieldSide.right
        let finalSide = motion.finalSide(originalSide: originalSide)
        XCTAssertEqual(finalSide, .right)
    }

    /// Test that .stop motion preserves center for H back
    func testStopMotionPreservesCenter() {
        let motion = ReceiverMotion.stop
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

    /// Test that .go motion flips left to right
    func testGoMotionFlipsLeftToRight() {
        let motion = ReceiverMotion.go
        let originalSide = FieldSide.left
        let finalSide = motion.finalSide(originalSide: originalSide)
        XCTAssertEqual(finalSide, .right)
    }

    /// Test that .go motion flips right to left
    func testGoMotionFlipsRightToLeft() {
        let motion = ReceiverMotion.go
        let originalSide = FieldSide.right
        let finalSide = motion.finalSide(originalSide: originalSide)
        XCTAssertEqual(finalSide, .left)
    }

    /// Test that .go motion preserves center for H back
    func testGoMotionPreservesCenter() {
        let motion = ReceiverMotion.go
        let originalSide = FieldSide.center
        let finalSide = motion.finalSide(originalSide: originalSide)
        XCTAssertEqual(finalSide, .center)
    }

    /// Test ReceiverMotion is CaseIterable (all cases present)
    func testReceiverMotionHasAllCases() {
        let allCases = ReceiverMotion.allCases
        XCTAssertEqual(allCases.count, 3)
        XCTAssertTrue(allCases.contains(.stop))
        XCTAssertTrue(allCases.contains(.after))
        XCTAssertTrue(allCases.contains(.go))
    }

    /// Test ReceiverMotion Identifiable conformance
    func testReceiverMotionIdentifiable() {
        let motion = ReceiverMotion.stop
        XCTAssertEqual(motion.id, "Stop")
        XCTAssertEqual(ReceiverMotion.after.id, "After")
        XCTAssertEqual(ReceiverMotion.go.id, "Go")
    }
}
