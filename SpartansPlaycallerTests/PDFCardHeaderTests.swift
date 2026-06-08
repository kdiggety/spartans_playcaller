import XCTest
import PDFKit
@testable import SpartansPlaycaller

final class PDFCardHeaderTests: XCTestCase {

    let interpreter = RouteInterpreter()

    func makeCard(_ digits: String, _ formation: Formation, number: Int) -> ExportCard {
        guard case .success(let pc) = interpreter.interpret(digits: digits, formation: formation) else {
            fatalError("parse failed: \(digits) \(formation.rawValue)")
        }
        return ExportCard(
            playNumber: number,
            formationName: pc.formation.rawValue,
            routeDigits: digits,
            conceptName: nil,
            motionLabel: nil,
            yWheelEnabled: false,
            playCall: pc
        )
    }

    // MARK: - combinedHeaderString

    func testCombinedHeaderStringSingleDigitNumber() {
        let card = makeCard("6794", .twins, number: 1)
        XCTAssertEqual(card.combinedHeaderString, "1. Twins 6794")
    }

    func testCombinedHeaderStringTwoDigitNumber() {
        let card = makeCard("6794", .twins, number: 12)
        XCTAssertEqual(card.combinedHeaderString, "12. Twins 6794")
    }

    func testCombinedHeaderStringFiveDigitRoute() {
        let card = makeCard("67943", .twins, number: 3)
        XCTAssertEqual(card.combinedHeaderString, "3. Twins 67943")
    }

    func testCombinedHeaderStringMultiWordFormation() {
        let card = makeCard("2943", .tripsLeft, number: 5)
        XCTAssertEqual(card.combinedHeaderString, "5. Trips Left 2943")
    }

    // MARK: - Config constant guards

    func testWristbandDiagramZoneTopY() {
        let config = WristbandCardConfig.standard()
        XCTAssertEqual(config.diagramZoneTopY, 62.0, accuracy: 0.5)
    }

    func testCatalogDiagramZoneTopY() {
        let config = CatalogCardConfig.standard()
        XCTAssertEqual(config.diagramZoneTopY, 45.0, accuracy: 0.5)
    }

    func testWristbandDiagramZoneFitsInCard() {
        let config = WristbandCardConfig.standard()
        XCTAssertGreaterThan(config.diagramZoneSize.height, 0)
        XCTAssertLessThan(config.diagramZoneTopY + config.diagramZoneSize.height, config.cardHeight)
    }

    func testCatalogDiagramZoneFitsInCard() {
        let config = CatalogCardConfig.standard()
        XCTAssertGreaterThan(config.diagramZoneSize.height, 0)
        XCTAssertLessThan(config.diagramZoneTopY + config.diagramZoneSize.height, config.cardHeight)
    }

    // MARK: - Wristband integration (non-crash + validity)

    func testWristbandGeneratesValidPDFWithNewHeader() {
        let card = makeCard("6794", .twins, number: 1)
        guard let data = WristbandPDFGenerator.generate(cards: [card]) else {
            XCTFail("nil data"); return
        }
        let header = data.prefix(4)
        XCTAssertEqual(header, Data([0x25, 0x50, 0x44, 0x46])) // %PDF
    }

    func testWristbandFiveDigitRouteDoesNotCrash() {
        let card = makeCard("67943", .twins, number: 2)
        XCTAssertNotNil(WristbandPDFGenerator.generate(cards: [card]))
    }

    func testWristbandCardWithConceptAndMotionDoesNotCrash() {
        guard case .success(let pc) = interpreter.interpret(digits: "6794", formation: .twins) else {
            XCTFail(); return
        }
        let card = ExportCard(
            playNumber: 7,
            formationName: pc.formation.rawValue,
            routeDigits: "6794",
            conceptName: "Mesh",
            motionLabel: "Y Go",
            yWheelEnabled: false,
            playCall: pc
        )
        XCTAssertNotNil(WristbandPDFGenerator.generate(cards: [card]))
    }

    func testWristbandPageCountUnchanged() {
        let cards = [
            makeCard("6794", .twins, number: 1),
            makeCard("2943", .tripsLeft, number: 2)
        ]
        guard let data = WristbandPDFGenerator.generate(cards: cards) else {
            XCTFail(); return
        }
        XCTAssertEqual(PDFDocument(data: data)?.pageCount, 2)
    }

    // MARK: - Catalog integration (non-crash + validity)

    func testCatalogGeneratesValidPDFWithNewHeader() {
        let card = makeCard("6794", .twins, number: 1)
        guard let data = CatalogPDFGenerator.generate(cards: [card]) else {
            XCTFail("nil data"); return
        }
        let header = data.prefix(4)
        XCTAssertEqual(header, Data([0x25, 0x50, 0x44, 0x46])) // %PDF
    }

    func testCatalogFiveDigitRouteDoesNotCrash() {
        let card = makeCard("67943", .tripsRight, number: 4)
        XCTAssertNotNil(CatalogPDFGenerator.generate(cards: [card]))
    }

    func testCatalogCardWithConceptAndMotionDoesNotCrash() {
        guard case .success(let pc) = interpreter.interpret(digits: "2943", formation: .tripsLeft) else {
            XCTFail(); return
        }
        let card = ExportCard(
            playNumber: 8,
            formationName: pc.formation.rawValue,
            routeDigits: "2943",
            conceptName: "Drive",
            motionLabel: "Y Stop",
            yWheelEnabled: false,
            playCall: pc
        )
        XCTAssertNotNil(CatalogPDFGenerator.generate(cards: [card]))
    }

    func testCatalogNineCardsFitOnOnePage() {
        let cards = (1...9).map { makeCard("6794", .twins, number: $0) }
        guard let data = CatalogPDFGenerator.generate(cards: cards) else {
            XCTFail(); return
        }
        XCTAssertEqual(PDFDocument(data: data)?.pageCount, 1)
    }

    func testCatalogTenCardsNeedTwoPages() {
        let cards = (1...10).map { makeCard("6794", .twins, number: $0) }
        guard let data = CatalogPDFGenerator.generate(cards: cards) else {
            XCTFail(); return
        }
        XCTAssertEqual(PDFDocument(data: data)?.pageCount, 2)
    }
}
