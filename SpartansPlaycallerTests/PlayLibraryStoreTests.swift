import XCTest
@testable import SpartansPlaycaller

@MainActor
final class PlayLibraryStoreTests: XCTestCase {

    var tempURL: URL!
    var store: PlayLibraryStore!

    override func setUp() {
        super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-library-\(UUID()).json")
        store = PlayLibraryStore(fileURL: tempURL)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempURL)
        super.tearDown()
    }

    func testSaveAddsToPlays() {
        let interpreter = RouteInterpreter()
        guard case .success(let playCall) = interpreter.interpret(digits: "6794", formation: .twins) else {
            XCTFail(); return
        }
        store.save(playCall, motion: nil, yWheelEnabled: false)
        XCTAssertEqual(store.plays.count, 1)
        XCTAssertEqual(store.plays[0].routeDigits, "6794")
        XCTAssertEqual(store.plays[0].formationName, "Twins")
    }

    func testSaveAllowsDuplicates() {
        let interpreter = RouteInterpreter()
        guard case .success(let playCall) = interpreter.interpret(digits: "6794", formation: .twins) else {
            XCTFail(); return
        }
        store.save(playCall, motion: nil, yWheelEnabled: false)
        store.save(playCall, motion: nil, yWheelEnabled: false)
        XCTAssertEqual(store.plays.count, 2)
    }

    func testDeleteAtOffsets() {
        let interpreter = RouteInterpreter()
        guard case .success(let pc1) = interpreter.interpret(digits: "6794", formation: .twins),
              case .success(let pc2) = interpreter.interpret(digits: "2943", formation: .tripsLeft) else {
            XCTFail(); return
        }
        store.save(pc1, motion: nil, yWheelEnabled: false)
        store.save(pc2, motion: nil, yWheelEnabled: false)
        XCTAssertEqual(store.plays.count, 2)

        store.delete(at: IndexSet([0]))
        XCTAssertEqual(store.plays.count, 1)
        XCTAssertEqual(store.plays[0].routeDigits, "2943")
    }

    func testDeleteAll() {
        let interpreter = RouteInterpreter()
        guard case .success(let playCall) = interpreter.interpret(digits: "6794", formation: .twins) else {
            XCTFail(); return
        }
        store.save(playCall, motion: nil, yWheelEnabled: false)
        store.save(playCall, motion: nil, yWheelEnabled: false)
        store.deleteAll()
        XCTAssertTrue(store.plays.isEmpty)
    }

    func testLoadFromFileOnInit() throws {
        let interpreter = RouteInterpreter()
        guard case .success(let playCall) = interpreter.interpret(digits: "6794", formation: .twins) else {
            XCTFail(); return
        }
        store.save(playCall, motion: .stop, yWheelEnabled: false)
        XCTAssertEqual(store.plays.count, 1)

        // Create new store instance pointing at same file
        let store2 = PlayLibraryStore(fileURL: tempURL)
        XCTAssertEqual(store2.plays.count, 1)
        XCTAssertEqual(store2.plays[0].routeDigits, "6794")
        XCTAssertEqual(store2.plays[0].motionLabel, "Y Stop")
    }

    func testEmptyFileOnInit() {
        // Store with a URL that has no file yet — should start empty, not crash
        let emptyURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("nonexistent-\(UUID()).json")
        let emptyStore = PlayLibraryStore(fileURL: emptyURL)
        XCTAssertTrue(emptyStore.plays.isEmpty)
        try? FileManager.default.removeItem(at: emptyURL)
    }

    func testPersistUsesCompleteFileProtection() throws {
        let interpreter = RouteInterpreter()
        guard case .success(let playCall) = interpreter.interpret(digits: "6794", formation: .twins) else {
            XCTFail(); return
        }
        store.save(playCall, motion: nil, yWheelEnabled: false)
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempURL.path))
        // Verify file exists and is readable (protection attribute only verifiable on device, not simulator)
        let data = try Data(contentsOf: tempURL)
        XCTAssertFalse(data.isEmpty)
    }
}
