import XCTest
import PDFKit
@testable import SpartansPlaycaller

final class DiagramRendererReceiverLabelTests: XCTestCase {

    let interpreter = RouteInterpreter()

    func renderToPDF(playCall: PlayCall, config: DiagramConfig? = nil) -> Data? {
        let pageRect = CGRect(x: 0, y: 0, width: 252, height: 180)
        let r = UIGraphicsPDFRenderer(bounds: pageRect)
        return r.pdfData { ctx in
            ctx.beginPage()
            let cgCtx = ctx.cgContext
            cgCtx.translateBy(x: 0, y: pageRect.height)
            cgCtx.scaleBy(x: 1, y: -1)
            let cfg = config ?? DiagramConfig.wristbandCardScale(for: CGSize(width: 236, height: 96))
            DiagramRenderer().draw(into: cgCtx, playCall: playCall, config: cfg,
                                   in: CGRect(x: 8, y: 62, width: 236, height: 96))
        }
    }

    func playCall(_ digits: String, _ formation: Formation) -> PlayCall {
        guard case .success(let pc) = interpreter.interpret(digits: digits, formation: formation) else {
            fatalError("parse failed: \(digits)")
        }
        return pc
    }

    func testDoesNotCrashTwins() {
        XCTAssertNotNil(renderToPDF(playCall: playCall("6794", .twins)))
    }

    func testDoesNotCrashTripsLeft() {
        XCTAssertNotNil(renderToPDF(playCall: playCall("2943", .tripsLeft)))
    }

    func testDoesNotCrashTripsRight() {
        XCTAssertNotNil(renderToPDF(playCall: playCall("8761", .tripsRight)))
    }

    func testDoesNotCrashProLeft() {
        XCTAssertNotNil(renderToPDF(playCall: playCall("6794", .proLeft)))
    }

    func testDoesNotCrashProRight() {
        XCTAssertNotNil(renderToPDF(playCall: playCall("6794", .proRight)))
    }

    func testDoesNotCrashFiveDigitPlay() {
        // H receiver included
        XCTAssertNotNil(renderToPDF(playCall: playCall("67943", .twins)))
    }

    func testDoesNotCrashWithStopMotion() {
        let pc = PlayCall.applying(.stop, yWheelEnabled: false, to: playCall("6794", .twins))
        XCTAssertNotNil(renderToPDF(playCall: pc))
    }

    func testDoesNotCrashWithAfterMotion() {
        let pc = PlayCall.applying(.after, yWheelEnabled: false, to: playCall("6794", .twins))
        XCTAssertNotNil(renderToPDF(playCall: pc))
    }

    func testDoesNotCrashWithGoMotion() {
        let pc = PlayCall.applying(.go, yWheelEnabled: false, to: playCall("2943", .tripsLeft))
        XCTAssertNotNil(renderToPDF(playCall: pc))
    }

    func testDoesNotCrashWithYWheel() {
        let pc = PlayCall.applying(nil, yWheelEnabled: true, to: playCall("6794", .twins))
        XCTAssertNotNil(renderToPDF(playCall: pc))
    }

    func testDoesNotCrashCatalogConfig() {
        let cfg = DiagramConfig.catalogCardScale(for: CGSize(width: 224, height: 124))
        XCTAssertNotNil(renderToPDF(playCall: playCall("6794", .twins), config: cfg))
    }

    func testOutputIsValidPDF() {
        guard let data = renderToPDF(playCall: playCall("6794", .twins)) else {
            XCTFail("nil data"); return
        }
        XCTAssertFalse(data.isEmpty)
        XCTAssertEqual(data.prefix(4), Data([0x25, 0x50, 0x44, 0x46])) // %PDF
    }

    func testContextStateIntegrityAfterDraw() {
        // Verifies that saveGState/restoreGState inside drawReceiversCG
        // does not leak a corrupt transform onto callers' context.
        let pc = playCall("6794", .twins)
        let pageRect = CGRect(x: 0, y: 0, width: 252, height: 180)
        var transformBeforeDraw: CGAffineTransform = .identity
        var transformAfterDraw: CGAffineTransform = .identity
        let _ = UIGraphicsPDFRenderer(bounds: pageRect).pdfData { ctx in
            ctx.beginPage()
            let cgCtx = ctx.cgContext
            cgCtx.translateBy(x: 0, y: pageRect.height)
            cgCtx.scaleBy(x: 1, y: -1)
            transformBeforeDraw = cgCtx.ctm
            let cfg = DiagramConfig.wristbandCardScale(for: CGSize(width: 236, height: 96))
            DiagramRenderer().draw(into: cgCtx, playCall: pc, config: cfg,
                                   in: CGRect(x: 8, y: 62, width: 236, height: 96))
            transformAfterDraw = cgCtx.ctm
        }
        XCTAssertEqual(transformBeforeDraw.a, transformAfterDraw.a, accuracy: 0.001)
        XCTAssertEqual(transformBeforeDraw.d, transformAfterDraw.d, accuracy: 0.001)
        XCTAssertEqual(transformBeforeDraw.tx, transformAfterDraw.tx, accuracy: 0.001)
        XCTAssertEqual(transformBeforeDraw.ty, transformAfterDraw.ty, accuracy: 0.001)
    }
}
