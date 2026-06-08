import XCTest
@testable import SpartansPlaycaller

final class ExportCardTests: XCTestCase {

    let interpreter = RouteInterpreter()

    func testFromPlayCallQuickPath() {
        guard case .success(let pc) = interpreter.interpret(digits: "6794", formation: .twins) else {
            XCTFail(); return
        }
        let card = ExportCard.from(playCall: pc, motion: nil, playNumber: 1)

        XCTAssertEqual(card.playNumber, 1)
        XCTAssertEqual(card.formationName, "Twins")
        XCTAssertEqual(card.routeDigits, "6794")
        XCTAssertNil(card.motionLabel)
        XCTAssertFalse(card.yWheelEnabled)
    }

    func testFromPlayCallWithMotion() {
        guard case .success(let pc) = interpreter.interpret(digits: "6794", formation: .twins) else {
            XCTFail(); return
        }
        let postMotion = PlayCall.applying(.stop, yWheelEnabled: false, to: pc)
        let card = ExportCard.from(playCall: postMotion, motion: .stop, playNumber: 2)

        XCTAssertEqual(card.playNumber, 2)
        XCTAssertEqual(card.motionLabel, "Y Stop")
    }

    func testFromSavedPlayLibraryPath() {
        let saved = SavedPlay(
            id: UUID(),
            savedAt: Date(),
            formationName: "Twins",
            routeDigits: "6794",
            conceptName: nil,
            motionLabel: nil,
            yWheelEnabled: false
        )
        let card = ExportCard.from(savedPlay: saved, playNumber: 1, interpreter: interpreter)

        XCTAssertNotNil(card)
        XCTAssertEqual(card?.formationName, "Twins")
        XCTAssertEqual(card?.routeDigits, "6794")
        XCTAssertEqual(card?.playNumber, 1)
    }

    func testFromSavedPlayWithMotion() {
        let saved = SavedPlay(
            id: UUID(),
            savedAt: Date(),
            formationName: "Trips Left",
            routeDigits: "2943",
            conceptName: nil,
            motionLabel: "Y Stop",
            yWheelEnabled: false
        )
        let card = ExportCard.from(savedPlay: saved, playNumber: 3, interpreter: interpreter)

        XCTAssertNotNil(card)
        XCTAssertEqual(card?.motionLabel, "Y Stop")
        XCTAssertEqual(card?.playNumber, 3)
    }

    func testFromSavedPlayInvalidFormationReturnsNil() {
        let saved = SavedPlay(
            id: UUID(),
            savedAt: Date(),
            formationName: "NOT_A_FORMATION",
            routeDigits: "6794",
            conceptName: nil,
            motionLabel: nil,
            yWheelEnabled: false
        )
        let card = ExportCard.from(savedPlay: saved, playNumber: 1, interpreter: interpreter)
        XCTAssertNil(card)
    }

    func testFromSavedPlayConceptNamePreserved() {
        let saved = SavedPlay(
            id: UUID(),
            savedAt: Date(),
            formationName: "Twins",
            routeDigits: "6794",
            conceptName: "Smash",
            motionLabel: nil,
            yWheelEnabled: false
        )
        let card = ExportCard.from(savedPlay: saved, playNumber: 1, interpreter: interpreter)
        XCTAssertEqual(card?.conceptName, "Smash")
    }
}
