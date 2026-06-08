import XCTest
@testable import SpartansPlaycaller

final class SavedPlayCodableTests: XCTestCase {

    func testRoundTripAllFieldsPresent() throws {
        let play = SavedPlay(
            id: UUID(),
            savedAt: Date(timeIntervalSince1970: 1000),
            formationName: "Twins",
            routeDigits: "6794",
            conceptName: "Smash",
            motionLabel: "Y Stop",
            yWheelEnabled: true
        )
        let data = try JSONEncoder().encode(play)
        let decoded = try JSONDecoder().decode(SavedPlay.self, from: data)

        XCTAssertEqual(decoded.id, play.id)
        XCTAssertEqual(decoded.formationName, "Twins")
        XCTAssertEqual(decoded.routeDigits, "6794")
        XCTAssertEqual(decoded.conceptName, "Smash")
        XCTAssertEqual(decoded.motionLabel, "Y Stop")
        XCTAssertTrue(decoded.yWheelEnabled)
        XCTAssertEqual(decoded.savedAt.timeIntervalSince1970, 1000, accuracy: 0.001)
    }

    func testRoundTripNilOptionals() throws {
        let play = SavedPlay(
            id: UUID(),
            savedAt: Date(),
            formationName: "Trips Left",
            routeDigits: "2943",
            conceptName: nil,
            motionLabel: nil,
            yWheelEnabled: false
        )
        let data = try JSONEncoder().encode(play)
        let decoded = try JSONDecoder().decode(SavedPlay.self, from: data)

        XCTAssertNil(decoded.conceptName)
        XCTAssertNil(decoded.motionLabel)
        XCTAssertFalse(decoded.yWheelEnabled)
    }

    func testArrayRoundTrip() throws {
        let plays = [
            SavedPlay(id: UUID(), savedAt: Date(), formationName: "Twins", routeDigits: "6794", conceptName: nil, motionLabel: nil, yWheelEnabled: false),
            SavedPlay(id: UUID(), savedAt: Date(), formationName: "Pro Left", routeDigits: "2943", conceptName: "Dagger", motionLabel: "Y After", yWheelEnabled: false)
        ]
        let data = try JSONEncoder().encode(plays)
        let decoded = try JSONDecoder().decode([SavedPlay].self, from: data)

        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[1].conceptName, "Dagger")
        XCTAssertEqual(decoded[1].motionLabel, "Y After")
    }

    func testFromPlayCallFactory() {
        let interpreter = RouteInterpreter()
        guard case .success(let playCall) = interpreter.interpret(digits: "6794", formation: .twins) else {
            XCTFail("interpretation failed"); return
        }
        let saved = SavedPlay.from(playCall: playCall, motion: .stop, yWheelEnabled: false)

        XCTAssertEqual(saved.formationName, "Twins")
        XCTAssertEqual(saved.routeDigits, "6794")
        XCTAssertEqual(saved.motionLabel, "Y Stop")
        XCTAssertFalse(saved.yWheelEnabled)
    }

    func testFromPlayCallNilMotion() {
        let interpreter = RouteInterpreter()
        guard case .success(let playCall) = interpreter.interpret(digits: "9876", formation: .tripsLeft) else {
            XCTFail(); return
        }
        let saved = SavedPlay.from(playCall: playCall, motion: nil, yWheelEnabled: false)
        XCTAssertNil(saved.motionLabel)
    }
}
