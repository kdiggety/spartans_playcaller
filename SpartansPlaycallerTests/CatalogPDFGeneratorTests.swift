import XCTest
import PDFKit
@testable import SpartansPlaycaller

final class CatalogPDFGeneratorTests: XCTestCase {

    let interpreter = RouteInterpreter()

    func makeCards(_ count: Int) -> [ExportCard] {
        (1...count).map { i in
            guard case .success(let pc) = interpreter.interpret(digits: "6794", formation: .twins) else {
                fatalError()
            }
            return ExportCard.from(playCall: pc, motion: nil, playNumber: i)
        }
    }

    func testNinePlaysProducesOnePage() {
        guard let data = CatalogPDFGenerator.generate(cards: makeCards(9)) else {
            XCTFail(); return
        }
        let doc = PDFDocument(data: data)
        XCTAssertEqual(doc?.pageCount, 1)
    }

    func testTenPlaysProducesTwoPages() {
        guard let data = CatalogPDFGenerator.generate(cards: makeCards(10)) else {
            XCTFail(); return
        }
        let doc = PDFDocument(data: data)
        XCTAssertEqual(doc?.pageCount, 2)
    }

    func testEighteenPlaysProducesTwoPages() {
        guard let data = CatalogPDFGenerator.generate(cards: makeCards(18)) else {
            XCTFail(); return
        }
        let doc = PDFDocument(data: data)
        XCTAssertEqual(doc?.pageCount, 2)
    }

    func testNineteenPlaysProducesThreePages() {
        guard let data = CatalogPDFGenerator.generate(cards: makeCards(19)) else {
            XCTFail(); return
        }
        let doc = PDFDocument(data: data)
        XCTAssertEqual(doc?.pageCount, 3)
    }

    func testPageIsLandscapeLetter() {
        guard let data = CatalogPDFGenerator.generate(cards: makeCards(1)) else {
            XCTFail(); return
        }
        let doc = PDFDocument(data: data)!
        let page = doc.page(at: 0)!
        let mediaBox = page.bounds(for: .mediaBox)
        XCTAssertEqual(mediaBox.width, 792, accuracy: 1)   // landscape: wider
        XCTAssertEqual(mediaBox.height, 612, accuracy: 1)
    }

    func testEmptyCardsReturnsNil() {
        XCTAssertNil(CatalogPDFGenerator.generate(cards: []))
    }

    func testGeneratedDataIsValidPDF() {
        guard let data = CatalogPDFGenerator.generate(cards: makeCards(1)) else {
            XCTFail(); return
        }
        XCTAssertEqual(data.prefix(4), Data([0x25, 0x50, 0x44, 0x46]))
    }

    func testCellOriginForFirstCell() {
        let config = CatalogCardConfig.standard()
        let origins = config.cellOrigins
        XCTAssertEqual(origins[0].x, 36, accuracy: 1)
        XCTAssertEqual(origins[0].y, 36, accuracy: 1)
    }

    func testCellOriginForSecondColumn() {
        let config = CatalogCardConfig.standard()
        XCTAssertEqual(config.cellOrigins[1].x, 278, accuracy: 1)  // 36 + 234 + 8 = 278
        XCTAssertEqual(config.cellOrigins[1].y, 36, accuracy: 1)
    }

    func testCellOriginForSecondRow() {
        let config = CatalogCardConfig.standard()
        XCTAssertEqual(config.cellOrigins[3].x, 36, accuracy: 1)
        XCTAssertEqual(config.cellOrigins[3].y, 218, accuracy: 1)   // 36 + 174 + 8 = 218
    }
}
