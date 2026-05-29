import XCTest
@testable import SpartansPlaycaller

class DiagramRendererYWheelTests: XCTestCase {
    let renderer = DiagramRenderer()
    let interpreter = RouteInterpreter()

    func testYWheelArcPathTripsLeft() {
        // Y starts at left slot, wheels semi-circle behind X/A
        guard case .success(let playCall) = interpreter.interpret(digits: "6794", formation: .tripsLeft) else {
            XCTFail("Failed to interpret play call")
            return
        }

        // Y wheel should produce an arc path from Y's start position,
        // looping behind the formation, ending lower (down the sideline)
        let config = DiagramConfig.standard(for: CGSize(width: 300, height: 400))
        let (path, _) = renderer.yWheelArcPath(for: playCall, config: config)

        // Arc should not be nil
        XCTAssertNotNil(path, "Y wheel arc should be rendered")
    }

    func testYWheelArcPathTripsRight() {
        guard case .success(let playCall) = interpreter.interpret(digits: "6794", formation: .tripsRight) else {
            XCTFail("Failed to interpret play call")
            return
        }

        let config = DiagramConfig.standard(for: CGSize(width: 300, height: 400))
        let (path, _) = renderer.yWheelArcPath(for: playCall, config: config)
        XCTAssertNotNil(path, "Y wheel arc should be rendered on right side")
    }
}
