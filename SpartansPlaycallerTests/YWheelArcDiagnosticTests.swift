import XCTest
@testable import SpartansPlaycaller

/// Quick diagnostic to verify Y wheel arc geometry
class YWheelArcDiagnosticTests: XCTestCase {

    func testYWheelArcGeometryTripsLeft() {
        let renderer = DiagramRenderer()
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

        let (_, arcPoints, color) = renderer.yWheelArcPath(for: playCall, config: config)

        print("=== Y Wheel Arc Geometry (Trips Left) ===")
        print("Y Starting Position: (\(yPosition.x), \(yPosition.y))")
        print("Field Dimensions: width=\(config.fieldWidth), height=\(config.fieldHeight)")
        print("Route Length: \(config.routeLength), Break Length: \(config.breakLength)")
        print("")
        print("Arc Points Count: \(arcPoints.count)")
        print("Start Point: (\(arcPoints.first?.x ?? 0), \(arcPoints.first?.y ?? 0))")
        if arcPoints.count > 1 {
            print("End Point: (\(arcPoints.last?.x ?? 0), \(arcPoints.last?.y ?? 0))")
        }

        let minX = arcPoints.map(\.x).min() ?? yPosition.x
        let maxX = arcPoints.map(\.x).max() ?? yPosition.x
        let minY = arcPoints.map(\.y).min() ?? yPosition.y
        let maxY = arcPoints.map(\.y).max() ?? yPosition.y

        print("Arc X Range: [\(minX), \(maxX)] (width: \(maxX - minX))")
        print("Arc Y Range: [\(minY), \(maxY)] (depth: \(maxY - minY))")
        print("Arc Depth as % of Field: \(((maxY - minY) / config.fieldHeight) * 100)%")
        print("Arc Depth as % of Route Length: \(((maxY - minY) / config.routeLength) * 100)%")
        print("Color: \(color)")
        print("")

        // Verify key properties
        XCTAssertGreaterThanOrEqual(arcPoints.count, 10, "Arc should have smooth sampling")
        XCTAssertGreater(maxY, yPosition.y, "Arc should extend downward")
        XCTAssertLess(minX, yPosition.x, "Arc should extend to the left (for Trips Left Y)")

        let arcDepthPercent = ((maxY - minY) / config.fieldHeight) * 100
        XCTAssertGreater(arcDepthPercent, 10, "Arc should be at least 10% of field height")
        XCTAssertLess(arcDepthPercent, 40, "Arc should be less than 40% of field height")

        print("✓ All geometry checks passed")
    }

    func testYWheelArcGeometryTripsRight() {
        let renderer = DiagramRenderer()
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

        print("=== Y Wheel Arc Geometry (Trips Right) ===")
        print("Y Starting Position: (\(yPosition.x), \(yPosition.y))")

        let minX = arcPoints.map(\.x).min() ?? yPosition.x
        let maxX = arcPoints.map(\.x).max() ?? yPosition.x
        let minY = arcPoints.map(\.y).min() ?? yPosition.y
        let maxY = arcPoints.map(\.y).max() ?? yPosition.y

        print("Arc X Range: [\(minX), \(maxX)]")
        print("Arc Y Range: [\(minY), \(maxY)]")
        print("Arc extends to RIGHT: \(maxX > yPosition.x)")
        print("")

        XCTAssertGreater(maxX, yPosition.x, "Arc should extend to the right (for Trips Right Y)")
        print("✓ Trips Right geometry correct")
    }
}
