import XCTest
@testable import SpartansPlaycaller

class Route0BubbleTests: XCTestCase {
    func testRoute0IsHitchLeftSide() {
        let semantics = BubbleRouteSemantics(meaning: .hitch)
        let meaning = semantics.meaning(on: .left)

        XCTAssertEqual(meaning, .hitch, "Route 0 should be hitch on left side")
    }

    func testRoute0IsHitchRightSide() {
        let semantics = BubbleRouteSemantics(meaning: .hitch)
        let meaning = semantics.meaning(on: .right)

        XCTAssertEqual(meaning, .hitch, "Route 0 should be hitch on right side")
    }

    func testRoute0IsHitchCenterSide() {
        let semantics = BubbleRouteSemantics(meaning: .hitch)
        let meaning = semantics.meaning(on: .center)

        XCTAssertEqual(meaning, .hitch, "Route 0 should be hitch on center (H receiver)")
    }
}

class RouteSemanticProviderComprehensiveTests: XCTestCase {
    // Route 1: Quick Out (left) / Quick Slant (right)
    func testRoute1LeftSide() {
        let semantics = SideAwareRouteSemantics(leftMeaning: .quickOut, rightMeaning: .quickSlant)
        let meaning = semantics.meaning(on: .left)
        XCTAssertEqual(meaning, .quickOut, "Route 1 left = Quick Out")
    }

    func testRoute1RightSide() {
        let semantics = SideAwareRouteSemantics(leftMeaning: .quickOut, rightMeaning: .quickSlant)
        let meaning = semantics.meaning(on: .right)
        XCTAssertEqual(meaning, .quickSlant, "Route 1 right = Quick Slant")
    }

    // Route 2: Quick Slant (left) / Quick Out (right)
    func testRoute2LeftSide() {
        let semantics = SideAwareRouteSemantics(leftMeaning: .quickSlant, rightMeaning: .quickOut)
        let meaning = semantics.meaning(on: .left)
        XCTAssertEqual(meaning, .quickSlant, "Route 2 left = Quick Slant")
    }

    func testRoute2RightSide() {
        let semantics = SideAwareRouteSemantics(leftMeaning: .quickSlant, rightMeaning: .quickOut)
        let meaning = semantics.meaning(on: .right)
        XCTAssertEqual(meaning, .quickOut, "Route 2 right = Quick Out")
    }

    // Route 3: Always breaks left (visual: LEFT 90°), side-aware semantics
    func testRoute3LeftSide() {
        let semantics = SideAwareRouteSemantics(leftMeaning: .out, rightMeaning: .digIn)
        let meaning = semantics.meaning(on: .left)
        XCTAssertEqual(meaning, .out, "Route 3 left = Out")
    }

    func testRoute3RightSide() {
        let semantics = SideAwareRouteSemantics(leftMeaning: .out, rightMeaning: .digIn)
        let meaning = semantics.meaning(on: .right)
        XCTAssertEqual(meaning, .digIn, "Route 3 right = Dig/In")
    }

    // Route 4: Always breaks right (visual: RIGHT 90°), side-aware semantics
    func testRoute4LeftSide() {
        let semantics = SideAwareRouteSemantics(leftMeaning: .digIn, rightMeaning: .out)
        let meaning = semantics.meaning(on: .left)
        XCTAssertEqual(meaning, .digIn, "Route 4 left = Dig/In")
    }

    func testRoute4RightSide() {
        let semantics = SideAwareRouteSemantics(leftMeaning: .digIn, rightMeaning: .out)
        let meaning = semantics.meaning(on: .right)
        XCTAssertEqual(meaning, .out, "Route 4 right = Out")
    }

    // Route 5: Comeback (left) / Curl (right)
    func testRoute5LeftSide() {
        let semantics = SideAwareRouteSemantics(leftMeaning: .comeback, rightMeaning: .curl)
        let meaning = semantics.meaning(on: .left)
        XCTAssertEqual(meaning, .comeback, "Route 5 left = Comeback")
    }

    func testRoute5RightSide() {
        let semantics = SideAwareRouteSemantics(leftMeaning: .comeback, rightMeaning: .curl)
        let meaning = semantics.meaning(on: .right)
        XCTAssertEqual(meaning, .curl, "Route 5 right = Curl")
    }

    // Route 6: Curl (left) / Comeback (right)
    func testRoute6LeftSide() {
        let semantics = SideAwareRouteSemantics(leftMeaning: .curl, rightMeaning: .comeback)
        let meaning = semantics.meaning(on: .left)
        XCTAssertEqual(meaning, .curl, "Route 6 left = Curl")
    }

    func testRoute6RightSide() {
        let semantics = SideAwareRouteSemantics(leftMeaning: .curl, rightMeaning: .comeback)
        let meaning = semantics.meaning(on: .right)
        XCTAssertEqual(meaning, .comeback, "Route 6 right = Comeback")
    }

    // Route 7: Always angles top-left (visual: top-LEFT 45°), side-aware semantics
    func testRoute7LeftSide() {
        let semantics = SideAwareRouteSemantics(leftMeaning: .corner, rightMeaning: .post)
        let meaning = semantics.meaning(on: .left)
        XCTAssertEqual(meaning, .corner, "Route 7 left = Corner")
    }

    func testRoute7RightSide() {
        let semantics = SideAwareRouteSemantics(leftMeaning: .corner, rightMeaning: .post)
        let meaning = semantics.meaning(on: .right)
        XCTAssertEqual(meaning, .post, "Route 7 right = Post")
    }

    // Route 8: Always angles top-right (visual: top-RIGHT 45°), side-aware semantics
    func testRoute8LeftSide() {
        let semantics = SideAwareRouteSemantics(leftMeaning: .post, rightMeaning: .corner)
        let meaning = semantics.meaning(on: .left)
        XCTAssertEqual(meaning, .post, "Route 8 left = Post")
    }

    func testRoute8RightSide() {
        let semantics = SideAwareRouteSemantics(leftMeaning: .post, rightMeaning: .corner)
        let meaning = semantics.meaning(on: .right)
        XCTAssertEqual(meaning, .corner, "Route 8 right = Corner")
    }

    // Route 9: Go/Fade (same both sides)
    func testRoute9LeftSide() {
        let semantics = SideAwareRouteSemantics(leftMeaning: .goFade, rightMeaning: .goFade)
        let meaning = semantics.meaning(on: .left)
        XCTAssertEqual(meaning, .goFade, "Route 9 left = Go/Fade")
    }

    func testRoute9RightSide() {
        let semantics = SideAwareRouteSemantics(leftMeaning: .goFade, rightMeaning: .goFade)
        let meaning = semantics.meaning(on: .right)
        XCTAssertEqual(meaning, .goFade, "Route 9 right = Go/Fade")
    }
}
