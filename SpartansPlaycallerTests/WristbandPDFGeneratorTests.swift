import XCTest
import PDFKit
@testable import SpartansPlaycaller

final class WristbandPDFGeneratorTests: XCTestCase {

    let interpreter = RouteInterpreter()

    func makeCard(_ digits: String, _ formation: Formation, number: Int) -> ExportCard {
        guard case .success(let pc) = interpreter.interpret(digits: digits, formation: formation) else {
            fatalError()
        }
        return ExportCard.from(playCall: pc, motion: nil, playNumber: number)
    }

    func testOneCardProducesOnePagePDF() {
        let cards = [makeCard("6794", .twins, number: 1)]
        guard let data = WristbandPDFGenerator.generate(cards: cards) else {
            XCTFail("generator returned nil"); return
        }
        let doc = PDFDocument(data: data)
        XCTAssertNotNil(doc)
        XCTAssertEqual(doc?.pageCount, 1)
    }

    func testThreeCardsProducesThreePages() {
        let cards = [
            makeCard("6794", .twins, number: 1),
            makeCard("2943", .tripsLeft, number: 2),
            makeCard("8761", .proRight, number: 3)
        ]
        guard let data = WristbandPDFGenerator.generate(cards: cards) else {
            XCTFail(); return
        }
        let doc = PDFDocument(data: data)
        XCTAssertEqual(doc?.pageCount, 3)
    }

    func testPageIsPortraitLetter() {
        let cards = [makeCard("6794", .twins, number: 1)]
        guard let data = WristbandPDFGenerator.generate(cards: cards) else {
            XCTFail(); return
        }
        let doc = PDFDocument(data: data)!
        let page = doc.page(at: 0)!
        let mediaBox = page.bounds(for: .mediaBox)
        XCTAssertEqual(mediaBox.width, 612, accuracy: 1)
        XCTAssertEqual(mediaBox.height, 792, accuracy: 1)
    }

    func testEmptyCardsReturnsNil() {
        let data = WristbandPDFGenerator.generate(cards: [])
        XCTAssertNil(data)
    }

    func testGeneratedDataIsValidPDF() {
        let cards = [makeCard("6794", .twins, number: 1)]
        guard let data = WristbandPDFGenerator.generate(cards: cards) else {
            XCTFail(); return
        }
        // PDF magic bytes: %PDF
        let header = data.prefix(4)
        XCTAssertEqual(header, Data([0x25, 0x50, 0x44, 0x46]))
    }
}
