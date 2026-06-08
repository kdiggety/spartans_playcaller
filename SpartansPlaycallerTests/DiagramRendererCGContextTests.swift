import XCTest
import PDFKit
@testable import SpartansPlaycaller

final class DiagramRendererCGContextTests: XCTestCase {

    let renderer = DiagramRenderer()
    let interpreter = RouteInterpreter()

    func makePlayCall(_ digits: String, _ formation: Formation) -> PlayCall {
        guard case .success(let pc) = interpreter.interpret(digits: digits, formation: formation) else {
            fatalError("parse failed")
        }
        return pc
    }

    func renderToPDF(playCall: PlayCall) -> Data? {
        let pageRect = CGRect(x: 0, y: 0, width: 234, height: 174)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { context in
            context.beginPage()
            let cgContext = context.cgContext
            // Simulate the PDFPage flip
            cgContext.translateBy(x: 0, y: pageRect.height)
            cgContext.scaleBy(x: 1, y: -1)

            let config = DiagramConfig.catalogCardScale(for: CGSize(width: 224, height: 89))
            let drawRect = CGRect(x: 5, y: 70, width: 224, height: 89)
            DiagramRenderer().draw(into: cgContext, playCall: playCall, config: config, in: drawRect)
        }
    }

    func testDoesNotCrashForTwins() {
        let pc = makePlayCall("6794", .twins)
        let data = renderToPDF(playCall: pc)
        XCTAssertNotNil(data)
        XCTAssertFalse(data!.isEmpty)
    }

    func testDoesNotCrashForTripsLeft() {
        let pc = makePlayCall("2943", .tripsLeft)
        XCTAssertNotNil(renderToPDF(playCall: pc))
    }

    func testDoesNotCrashForTripsRight() {
        let pc = makePlayCall("8761", .tripsRight)
        XCTAssertNotNil(renderToPDF(playCall: pc))
    }

    func testDoesNotCrashForProLeft() {
        let pc = makePlayCall("6794", .proLeft)
        XCTAssertNotNil(renderToPDF(playCall: pc))
    }

    func testDoesNotCrashForProRight() {
        let pc = makePlayCall("6794", .proRight)
        XCTAssertNotNil(renderToPDF(playCall: pc))
    }

    func testDoesNotCrashWithMotion() {
        let pc = makePlayCall("2943", .tripsLeft)
        let withMotion = PlayCall.applying(.stop, yWheelEnabled: false, to: pc)
        XCTAssertNotNil(renderToPDF(playCall: withMotion))
    }

    func testDoesNotCrashWithYWheel() {
        let pc = makePlayCall("6794", .twins)
        let withWheel = PlayCall.applying(nil, yWheelEnabled: true, to: pc)
        XCTAssertNotNil(renderToPDF(playCall: withWheel))
    }

    func testWristbandConfigDoesNotCrash() {
        let pc = makePlayCall("6794", .twins)
        let pageRect = CGRect(x: 0, y: 0, width: 252, height: 180)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let data = renderer.pdfData { context in
            context.beginPage()
            let cgContext = context.cgContext
            cgContext.translateBy(x: 0, y: pageRect.height)
            cgContext.scaleBy(x: 1, y: -1)
            let config = DiagramConfig.wristbandCardScale(for: CGSize(width: 242, height: 72))
            DiagramRenderer().draw(into: cgContext, playCall: pc, config: config, in: CGRect(x: 5, y: 90, width: 242, height: 72))
        }
        XCTAssertNotNil(data)
    }
}
