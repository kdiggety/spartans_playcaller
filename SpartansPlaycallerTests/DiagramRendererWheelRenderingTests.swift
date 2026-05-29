import XCTest
@testable import SpartansPlaycaller

class DiagramRendererWheelRenderingTests: XCTestCase {
    let renderer = DiagramRenderer()

    func testWheelArcRendersWhenWheelEnabledWithAfterMotion() {
        let playCall = PlayCall(
            formation: .tripsLeft,
            routeDigits: "6794",
            assignments: [],
            concept: nil,
            yWheelEnabled: true
        )

        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))
        let result = renderer.motionPathForPlayCall(for: playCall, config: config)
        XCTAssertNotNil(result, "Should render arc for wheel enabled")
    }

    func testWheelArcRendersWithoutMotion() {
        let playCall = PlayCall(
            formation: .tripsLeft,
            routeDigits: "6794",
            assignments: [],
            concept: nil,
            yWheelEnabled: true
        )

        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))
        let result = renderer.motionPathForPlayCall(for: playCall, config: config)
        XCTAssertNotNil(result, "Should render arc for wheel alone")
    }
}
