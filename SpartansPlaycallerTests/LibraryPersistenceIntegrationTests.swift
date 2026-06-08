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
}
