import XCTest
@testable import SpartansPlaycaller

@MainActor
final class LibraryPersistenceIntegrationTests: XCTestCase {

    func testThreePlaysRoundTripAcrossReinit() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("integration-library-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let interpreter = RouteInterpreter()
        let store1 = PlayLibraryStore(fileURL: tempURL)

        let cases: [(String, Formation, ReceiverMotion?)] = [
            ("6794", .twins, nil),
            ("2943", .tripsLeft, .stop),
            ("8761", .proRight, .after)
        ]

        for (digits, formation, motion) in cases {
            guard case .success(let pc) = interpreter.interpret(digits: digits, formation: formation) else {
                XCTFail("parse failed for \(digits)"); continue
            }
            store1.save(pc, motion: motion, yWheelEnabled: false)
        }
        XCTAssertEqual(store1.plays.count, 3)

        // Reinit — simulates app relaunch
        let store2 = PlayLibraryStore(fileURL: tempURL)
        XCTAssertEqual(store2.plays.count, 3)
        XCTAssertEqual(store2.plays[0].routeDigits, "6794")
        XCTAssertNil(store2.plays[0].motionLabel)
        XCTAssertEqual(store2.plays[1].routeDigits, "2943")
        XCTAssertEqual(store2.plays[1].motionLabel, "Y Stop")
        XCTAssertEqual(store2.plays[2].motionLabel, "Y After")
    }

    func testUpdatePlay_roundTripAcrossReinit() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("update-integration-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let interpreter = RouteInterpreter()
        let store1 = PlayLibraryStore(fileURL: tempURL)
        guard case .success(let pc) = interpreter.interpret(digits: "6794", formation: .twins) else {
            XCTFail(); return
        }
        store1.save(pc, motion: nil, yWheelEnabled: false)
        let original = store1.plays[0]

        let edited = SavedPlay(
            id: original.id, savedAt: original.savedAt,
            formationName: "Twins", routeDigits: "6794",
            conceptName: nil, motionLabel: "Y Stop", yWheelEnabled: true
        )
        let result = store1.update(edited)
        if case .failure(let err) = result { XCTFail("update failed: \(err)") }

        let store2 = PlayLibraryStore(fileURL: tempURL)
        XCTAssertEqual(store2.plays.count, 1)
        XCTAssertEqual(store2.plays[0].id, original.id)
        XCTAssertEqual(store2.plays[0].motionLabel, "Y Stop")
        XCTAssertTrue(store2.plays[0].yWheelEnabled)
    }

    func testMultiDelete_persistsAcrossReinit() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("multidelete-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let interpreter = RouteInterpreter()
        let store1 = PlayLibraryStore(fileURL: tempURL)
        guard case .success(let pc1) = interpreter.interpret(digits: "6794", formation: .twins),
              case .success(let pc2) = interpreter.interpret(digits: "2943", formation: .tripsLeft),
              case .success(let pc3) = interpreter.interpret(digits: "8761", formation: .proRight) else {
            XCTFail(); return
        }
        store1.save(pc1, motion: nil, yWheelEnabled: false)
        store1.save(pc2, motion: nil, yWheelEnabled: false)
        store1.save(pc3, motion: nil, yWheelEnabled: false)
        store1.delete(at: IndexSet([0, 2]))

        let store2 = PlayLibraryStore(fileURL: tempURL)
        XCTAssertEqual(store2.plays.count, 1)
        XCTAssertEqual(store2.plays[0].routeDigits, "2943")
    }
}
