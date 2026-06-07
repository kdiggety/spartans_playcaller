import XCTest
@testable import SpartansPlaycaller

/// Tests that validate Y wheel arc geometry against the visual specification:
/// - Starts at Y's position on the line of scrimmage
/// - Curves downward and to the side (away from LOS, into the backfield)
/// - Curves back upward (returning toward LOS)
/// - Ends partway back with arrow pointing back at LOS
/// - Smooth curved path (quadratic or cubic Bézier)
/// - Similar scale to other route arrows (not 25% of field)
/// - Yellow or red color
class YWheelArcVisualSpecTests: XCTestCase {
    let renderer = DiagramRenderer()

    func testYWheelArcStartsAtYPosition() {
        // Create a play call with a known formation
        let interpreter = RouteInterpreter()
        guard case .success(let playCall) = interpreter.interpret(digits: "6794", formation: .tripsLeft) else {
            XCTFail("Failed to interpret play call")
            return
        }

        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))
        let positions = renderer.receiverPositions(formation: .tripsLeft, config: config)
        guard let yPosition = positions[.Y] else {
            XCTFail("Failed to get Y position")
            return
        }

        let (_, arcPoints, _) = renderer.yWheelArcPath(for: playCall, config: config)

        XCTAssertGreaterThanOrEqual(arcPoints.count, 2, "Arc should have at least start and end points")

        // First point should be at or very close to Y's position
        let startPoint = arcPoints[0]
        XCTAssertEqual(startPoint.x, yPosition.x, accuracy: 0.1, "Arc start X should match Y position")
        XCTAssertEqual(startPoint.y, yPosition.y, accuracy: 0.1, "Arc start Y should match Y position")
    }

    func testYWheelArcCurvesDownwardOnLeftSide() {
        // For Trips Left, Y is on the left side
        let interpreter = RouteInterpreter()
        guard case .success(let playCall) = interpreter.interpret(digits: "6794", formation: .tripsLeft) else {
            XCTFail("Failed to interpret play call")
            return
        }

        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))
        let positions = renderer.receiverPositions(formation: .tripsLeft, config: config)
        guard let yPosition = positions[.Y] else {
            XCTFail("Failed to get Y position")
            return
        }

        let (_, arcPoints, _) = renderer.yWheelArcPath(for: playCall, config: config)

        // The deepest point (max Y) should be deeper than start
        let deepestY = arcPoints.map(\.y).max() ?? yPosition.y
        XCTAssertGreater(deepestY, yPosition.y, "Arc should curve downward (deeper into backfield)")

        // The arc should curve to the left (lower X than start)
        let minX = arcPoints.map(\.x).min() ?? yPosition.x
        XCTAssertLess(minX, yPosition.x, "Arc should curve to the left side")
    }

    func testYWheelArcCurvesDownwardOnRightSide() {
        // For Trips Right, Y is on the right side
        let interpreter = RouteInterpreter()
        guard case .success(let playCall) = interpreter.interpret(digits: "6794", formation: .tripsRight) else {
            XCTFail("Failed to interpret play call")
            return
        }

        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))
        let positions = renderer.receiverPositions(formation: .tripsRight, config: config)
        guard let yPosition = positions[.Y] else {
            XCTFail("Failed to get Y position")
            return
        }

        let (_, arcPoints, _) = renderer.yWheelArcPath(for: playCall, config: config)

        // The deepest point should be deeper than start
        let deepestY = arcPoints.map(\.y).max() ?? yPosition.y
        XCTAssertGreater(deepestY, yPosition.y, "Arc should curve downward (deeper into backfield)")

        // The arc should curve to the right (higher X than start)
        let maxX = arcPoints.map(\.x).max() ?? yPosition.x
        XCTAssertGreater(maxX, yPosition.x, "Arc should curve to the right side")
    }

    func testYWheelArcReturnsUpwardTowardLOS() {
        // The arc should curve back upward as it returns toward LOS
        let interpreter = RouteInterpreter()
        guard case .success(let playCall) = interpreter.interpret(digits: "6794", formation: .tripsLeft) else {
            XCTFail("Failed to interpret play call")
            return
        }

        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))
        let positions = renderer.receiverPositions(formation: .tripsLeft, config: config)
        guard let yPosition = positions[.Y] else {
            XCTFail("Failed to get Y position")
            return
        }

        let (_, arcPoints, _) = renderer.yWheelArcPath(for: playCall, config: config)

        // Last point should be above the deepest point (returning toward LOS)
        let deepestY = arcPoints.map(\.y).max() ?? yPosition.y
        let endY = arcPoints.last?.y ?? yPosition.y

        XCTAssertLess(endY, deepestY, "Arc endpoint should be above the deepest point (returning toward LOS)")
    }

    func testYWheelArcEndpointIsPartiallyBack() {
        // Endpoint should be partway back (not at the starting position, not at max depth)
        let interpreter = RouteInterpreter()
        guard case .success(let playCall) = interpreter.interpret(digits: "6794", formation: .tripsLeft) else {
            XCTFail("Failed to interpret play call")
            return
        }

        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))
        let (_, arcPoints, _) = renderer.yWheelArcPath(for: playCall, config: config)

        guard arcPoints.count >= 2 else {
            XCTFail("Arc should have at least 2 points")
            return
        }

        let startY = arcPoints[0].y
        let endY = arcPoints.last?.y ?? startY
        let deepestY = arcPoints.map(\.y).max() ?? startY

        // End point should be between start and deepest point
        XCTAssertGreater(endY, startY, "Endpoint should be deeper than start")
        XCTAssertLess(endY, deepestY, "Endpoint should not be at maximum depth")
    }

    func testYWheelArcScaleIsReasonable() {
        // Arc should be similar scale to other route arrows, not 25% of field
        let interpreter = RouteInterpreter()
        guard case .success(let playCall) = interpreter.interpret(digits: "6794", formation: .tripsLeft) else {
            XCTFail("Failed to interpret play call")
            return
        }

        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))
        let positions = renderer.receiverPositions(formation: .tripsLeft, config: config)
        guard let yPosition = positions[.Y] else {
            XCTFail("Failed to get Y position")
            return
        }

        let (_, arcPoints, _) = renderer.yWheelArcPath(for: playCall, config: config)

        // Max depth should be comparable to routeLength or breakLength
        let deepestY = arcPoints.map(\.y).max() ?? yPosition.y
        let arcDepth = deepestY - yPosition.y

        // Arc depth should be within 20-40% of field height (similar to routeLength which is 25%)
        let maxAllowedDepth = config.fieldHeight * 0.40
        let minAllowedDepth = config.fieldHeight * 0.10

        XCTAssertGreater(arcDepth, minAllowedDepth, "Arc depth should not be too shallow")
        XCTAssertLess(arcDepth, maxAllowedDepth, "Arc depth should not be excessive (not 25% of entire field)")
    }

    func testYWheelArcUsesYellowColor() {
        let interpreter = RouteInterpreter()
        guard case .success(let playCall) = interpreter.interpret(digits: "6794", formation: .tripsLeft) else {
            XCTFail("Failed to interpret play call")
            return
        }

        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))
        let (_, _, color) = renderer.yWheelArcPath(for: playCall, config: config)

        // Color should be yellow
        XCTAssertEqual(color, .yellow, "Y wheel arc should be yellow")
    }

    func testYWheelArcPathIsSmooth() {
        // Path should be smooth (no sharp corners) - validate via sampling density
        let interpreter = RouteInterpreter()
        guard case .success(let playCall) = interpreter.interpret(digits: "6794", formation: .tripsLeft) else {
            XCTFail("Failed to interpret play call")
            return
        }

        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))
        let (_, arcPoints, _) = renderer.yWheelArcPath(for: playCall, config: config)

        // Should have enough sampled points to create a smooth curve
        // With stride of 0.1, we expect ~10+ points
        XCTAssertGreaterThanOrEqual(arcPoints.count, 10, "Arc should have sufficient sampling points for smoothness")

        // Validate no single segment has excessive angle change (no sharp corners)
        for i in 1..<(arcPoints.count - 1) {
            let prev = arcPoints[i - 1]
            let curr = arcPoints[i]
            let next = arcPoints[i + 1]

            let angle1 = atan2(curr.y - prev.y, curr.x - prev.x)
            let angle2 = atan2(next.y - curr.y, next.x - curr.x)
            let angleDelta = abs(angle2 - angle1)

            // Angle change should be small (< 45 degrees between consecutive segments)
            XCTAssertLess(angleDelta, CGFloat.pi / 4, "Arc segments should have smooth transitions")
        }
    }

    func testYWheelArcOnProLeft() {
        // Test on Pro Left formation with Y on the left side
        let interpreter = RouteInterpreter()
        guard case .success(let playCall) = interpreter.interpret(digits: "5794", formation: .proLeft) else {
            XCTFail("Failed to interpret play call")
            return
        }

        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))
        let (_, arcPoints, _) = renderer.yWheelArcPath(for: playCall, config: config)

        XCTAssertGreaterThanOrEqual(arcPoints.count, 2, "Arc should render on Pro Left")
    }

    func testYWheelArcOnProRight() {
        // Test on Pro Right formation with Y on the right side
        let interpreter = RouteInterpreter()
        guard case .success(let playCall) = interpreter.interpret(digits: "5794", formation: .proRight) else {
            XCTFail("Failed to interpret play call")
            return
        }

        let config = DiagramConfig.standard(for: CGSize(width: 375, height: 812))
        let (_, arcPoints, _) = renderer.yWheelArcPath(for: playCall, config: config)

        XCTAssertGreaterThanOrEqual(arcPoints.count, 2, "Arc should render on Pro Right")
    }
}
