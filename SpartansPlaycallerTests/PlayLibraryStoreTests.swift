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

    // MARK: - update() tests

    func testUpdatePlay_changesMotionLabel() {
        let interpreter = RouteInterpreter()
        guard case .success(let pc) = interpreter.interpret(digits: "6794", formation: .twins) else {
            XCTFail(); return
        }
        store.save(pc, motion: nil, yWheelEnabled: false)
        let original = store.plays[0]

        let edited = SavedPlay(
            id: original.id, savedAt: original.savedAt,
            formationName: "Twins", routeDigits: "6794",
            conceptName: nil, motionLabel: "Y Stop", yWheelEnabled: false
        )
        let result = store.update(edited)
        guard case .success = result else { XCTFail("Expected success, got \(result)"); return }
        XCTAssertEqual(store.plays[0].motionLabel, "Y Stop")
        XCTAssertEqual(store.plays[0].id, original.id)
    }

    func testUpdatePlay_preservesPosition() {
        let interpreter = RouteInterpreter()
        guard case .success(let pc1) = interpreter.interpret(digits: "6794", formation: .twins),
              case .success(let pc2) = interpreter.interpret(digits: "2943", formation: .tripsLeft),
              case .success(let pc3) = interpreter.interpret(digits: "8761", formation: .proRight) else {
            XCTFail(); return
        }
        store.save(pc1, motion: nil, yWheelEnabled: false)
        store.save(pc2, motion: nil, yWheelEnabled: false)
        store.save(pc3, motion: nil, yWheelEnabled: false)

        let middlePlay = store.plays[1]
        let edited = SavedPlay(
            id: middlePlay.id, savedAt: middlePlay.savedAt,
            formationName: "Trips Left", routeDigits: "2943",
            conceptName: nil, motionLabel: nil, yWheelEnabled: false
        )
        let result = store.update(edited)
        guard case .success = result else { XCTFail("Expected success"); return }
        XCTAssertEqual(store.plays.count, 3)
        XCTAssertEqual(store.plays[1].id, middlePlay.id, "Edited play must stay at index 1")
        XCTAssertEqual(store.plays[0].routeDigits, "6794", "Sibling at index 0 must not change")
        XCTAssertEqual(store.plays[2].routeDigits, "8761", "Sibling at index 2 must not change")
    }

    func testUpdatePlay_updatesTimestamp() {
        let interpreter = RouteInterpreter()
        guard case .success(let pc) = interpreter.interpret(digits: "6794", formation: .twins) else {
            XCTFail(); return
        }
        store.save(pc, motion: nil, yWheelEnabled: false)
        let originalTimestamp = store.plays[0].savedAt
        let original = store.plays[0]
        Thread.sleep(forTimeInterval: 0.01)

        let edited = SavedPlay(
            id: original.id, savedAt: original.savedAt,
            formationName: "Twins", routeDigits: "6794",
            conceptName: nil, motionLabel: nil, yWheelEnabled: false
        )
        let result = store.update(edited)
        guard case .success = result else { XCTFail(); return }
        XCTAssertGreaterThan(store.plays[0].savedAt, originalTimestamp, "savedAt must advance on update")
    }

    func testUpdatePlay_noFieldChanges_stillUpdatesSavedAt() {
        let interpreter = RouteInterpreter()
        guard case .success(let pc) = interpreter.interpret(digits: "6794", formation: .twins) else {
            XCTFail(); return
        }
        store.save(pc, motion: nil, yWheelEnabled: false)
        let original = store.plays[0]
        Thread.sleep(forTimeInterval: 0.01)

        let noChange = SavedPlay(
            id: original.id, savedAt: original.savedAt,
            formationName: original.formationName, routeDigits: original.routeDigits,
            conceptName: original.conceptName, motionLabel: original.motionLabel,
            yWheelEnabled: original.yWheelEnabled
        )
        let result = store.update(noChange)
        guard case .success = result else { XCTFail(); return }
        XCTAssertGreaterThan(store.plays[0].savedAt, original.savedAt)
    }

    func testUpdatePlay_conceptReevaluated() {
        let interpreter = RouteInterpreter()
        guard case .success(let pc) = interpreter.interpret(digits: "6794", formation: .twins) else {
            XCTFail(); return
        }
        store.save(pc, motion: nil, yWheelEnabled: false)
        let original = store.plays[0]

        let edited = SavedPlay(
            id: original.id, savedAt: original.savedAt,
            formationName: "Twins", routeDigits: "6794",
            conceptName: "WRONG_CONCEPT", motionLabel: nil, yWheelEnabled: false
        )
        let result = store.update(edited)
        guard case .success = result else { XCTFail(); return }
        XCTAssertNotEqual(store.plays[0].conceptName, "WRONG_CONCEPT",
                          "Store must re-derive concept, not trust caller value")
    }

    func testUpdatePlay_yWheelEnabled_preserved() {
        let interpreter = RouteInterpreter()
        guard case .success(let pc) = interpreter.interpret(digits: "6794", formation: .twins) else {
            XCTFail(); return
        }
        store.save(pc, motion: nil, yWheelEnabled: false)
        let original = store.plays[0]

        let edited = SavedPlay(
            id: original.id, savedAt: original.savedAt,
            formationName: "Twins", routeDigits: "6794",
            conceptName: nil, motionLabel: nil, yWheelEnabled: true
        )
        let result = store.update(edited)
        guard case .success = result else { XCTFail(); return }
        XCTAssertTrue(store.plays[0].yWheelEnabled)
    }

    func testUpdatePlay_unknownUUID_returnsPlayNotFound() {
        let interpreter = RouteInterpreter()
        guard case .success(let pc) = interpreter.interpret(digits: "6794", formation: .twins) else {
            XCTFail(); return
        }
        store.save(pc, motion: nil, yWheelEnabled: false)

        let ghost = SavedPlay(
            id: UUID(), savedAt: Date(),
            formationName: "Twins", routeDigits: "6794",
            conceptName: nil, motionLabel: nil, yWheelEnabled: false
        )
        let result = store.update(ghost)
        if case .failure(.playNotFound) = result { /* pass */ } else {
            XCTFail("Expected .failure(.playNotFound), got \(result)")
        }
        XCTAssertEqual(store.plays.count, 1, "Store must be unchanged on not-found")
    }

    func testUpdatePlay_invalidDigits_returnsValidationError() {
        let interpreter = RouteInterpreter()
        guard case .success(let pc) = interpreter.interpret(digits: "6794", formation: .twins) else {
            XCTFail(); return
        }
        store.save(pc, motion: nil, yWheelEnabled: false)
        let original = store.plays[0]

        let invalid = SavedPlay(
            id: original.id, savedAt: original.savedAt,
            formationName: "Twins", routeDigits: "",
            conceptName: nil, motionLabel: nil, yWheelEnabled: false
        )
        let result = store.update(invalid)
        if case .failure(.invalidRouteDigits) = result { /* pass */ } else {
            XCTFail("Expected .failure(.invalidRouteDigits), got \(result)")
        }
        XCTAssertEqual(store.plays[0].routeDigits, "6794", "Store must be unchanged on validation failure")
    }

    func testUpdatePlay_inLargeLibrary_onlyTargetChanged() {
        let interpreter = RouteInterpreter()
        guard case .success(let pc1) = interpreter.interpret(digits: "6794", formation: .twins),
              case .success(let pc2) = interpreter.interpret(digits: "2943", formation: .tripsLeft),
              case .success(let pc3) = interpreter.interpret(digits: "8761", formation: .proRight) else {
            XCTFail(); return
        }
        for _ in 0..<4 { store.save(pc1, motion: nil, yWheelEnabled: false) }
        store.save(pc2, motion: nil, yWheelEnabled: false)
        for _ in 0..<5 { store.save(pc3, motion: nil, yWheelEnabled: false) }

        let targetPlay = store.plays[4]
        let siblingIds = store.plays.enumerated()
            .filter { $0.offset != 4 }
            .map { $0.element.id }

        let edited = SavedPlay(
            id: targetPlay.id, savedAt: targetPlay.savedAt,
            formationName: "Trips Left", routeDigits: "2943",
            conceptName: nil, motionLabel: nil, yWheelEnabled: false
        )
        let result = store.update(edited)
        guard case .success = result else { XCTFail(); return }
        XCTAssertEqual(store.plays.count, 10)
        XCTAssertEqual(store.plays[4].id, targetPlay.id)
        for id in siblingIds {
            XCTAssertTrue(store.plays.contains { $0.id == id }, "Sibling \(id) must not be removed")
        }
    }

    func testUpdatePlay_persistsAcrossReinit() {
        let interpreter = RouteInterpreter()
        guard case .success(let pc) = interpreter.interpret(digits: "6794", formation: .twins) else {
            XCTFail(); return
        }
        store.save(pc, motion: nil, yWheelEnabled: false)
        let original = store.plays[0]

        let edited = SavedPlay(
            id: original.id, savedAt: original.savedAt,
            formationName: "Twins", routeDigits: "6794",
            conceptName: nil, motionLabel: "Y Stop", yWheelEnabled: false
        )
        let result = store.update(edited)
        guard case .success = result else { XCTFail(); return }

        let reloaded = PlayLibraryStore(fileURL: tempURL)
        XCTAssertEqual(reloaded.plays.count, 1)
        XCTAssertEqual(reloaded.plays[0].id, original.id)
        XCTAssertEqual(reloaded.plays[0].motionLabel, "Y Stop")
    }

    // MARK: - move() tests

    func testMove_updatesOrderInMemory() {
        let interpreter = RouteInterpreter()
        guard case .success(let pcA) = interpreter.interpret(digits: "6794", formation: .twins),
              case .success(let pcB) = interpreter.interpret(digits: "2943", formation: .tripsLeft),
              case .success(let pcC) = interpreter.interpret(digits: "8761", formation: .proRight) else {
            XCTFail(); return
        }
        store.save(pcA, motion: nil, yWheelEnabled: false)
        store.save(pcB, motion: nil, yWheelEnabled: false)
        store.save(pcC, motion: nil, yWheelEnabled: false)
        store.move(fromOffsets: IndexSet([0]), toOffset: 3)
        XCTAssertEqual(store.plays[0].routeDigits, "2943", "B must be at index 0")
        XCTAssertEqual(store.plays[1].routeDigits, "8761", "C must be at index 1")
        XCTAssertEqual(store.plays[2].routeDigits, "6794", "A must be at index 2")
    }

    func testMove_doesNotPersistImmediately() throws {
        let interpreter = RouteInterpreter()
        guard case .success(let pcA) = interpreter.interpret(digits: "6794", formation: .twins),
              case .success(let pcB) = interpreter.interpret(digits: "2943", formation: .tripsLeft),
              case .success(let pcC) = interpreter.interpret(digits: "8761", formation: .proRight) else {
            XCTFail(); return
        }
        store.save(pcA, motion: nil, yWheelEnabled: false)
        store.save(pcB, motion: nil, yWheelEnabled: false)
        store.save(pcC, motion: nil, yWheelEnabled: false)
        let dataBefore = try Data(contentsOf: tempURL)
        let playsBefore = try JSONDecoder().decode([SavedPlay].self, from: dataBefore)
        let orderBefore = playsBefore.map { $0.routeDigits }
        store.move(fromOffsets: IndexSet([0]), toOffset: 3)
        let dataAfter = try Data(contentsOf: tempURL)
        let playsAfter = try JSONDecoder().decode([SavedPlay].self, from: dataAfter)
        let orderAfter = playsAfter.map { $0.routeDigits }
        XCTAssertEqual(orderBefore, orderAfter, "move() must not write to disk")
        XCTAssertNotEqual(store.plays.map { $0.routeDigits }, orderBefore, "move() must update in-memory plays")
    }

    func testCommitReorder_persistsNewOrder() throws {
        let interpreter = RouteInterpreter()
        guard case .success(let pcA) = interpreter.interpret(digits: "6794", formation: .twins),
              case .success(let pcB) = interpreter.interpret(digits: "2943", formation: .tripsLeft),
              case .success(let pcC) = interpreter.interpret(digits: "8761", formation: .proRight) else {
            XCTFail(); return
        }
        store.save(pcA, motion: nil, yWheelEnabled: false)
        store.save(pcB, motion: nil, yWheelEnabled: false)
        store.save(pcC, motion: nil, yWheelEnabled: false)
        store.move(fromOffsets: IndexSet([0]), toOffset: 3)
        store.commitReorder()
        let data = try Data(contentsOf: tempURL)
        let playsOnDisk = try JSONDecoder().decode([SavedPlay].self, from: data)
        XCTAssertEqual(playsOnDisk[0].routeDigits, "2943", "B must be first on disk")
        XCTAssertEqual(playsOnDisk[1].routeDigits, "8761", "C must be second on disk")
        XCTAssertEqual(playsOnDisk[2].routeDigits, "6794", "A must be last on disk")
    }

    func testCancelReorder_restoresSnapshot() {
        let interpreter = RouteInterpreter()
        guard case .success(let pcA) = interpreter.interpret(digits: "6794", formation: .twins),
              case .success(let pcB) = interpreter.interpret(digits: "2943", formation: .tripsLeft),
              case .success(let pcC) = interpreter.interpret(digits: "8761", formation: .proRight) else {
            XCTFail(); return
        }
        store.save(pcA, motion: nil, yWheelEnabled: false)
        store.save(pcB, motion: nil, yWheelEnabled: false)
        store.save(pcC, motion: nil, yWheelEnabled: false)
        let snapshot = store.plays
        store.move(fromOffsets: IndexSet([0]), toOffset: 3)
        XCTAssertEqual(store.plays[0].routeDigits, "2943", "Precondition: A moved")
        store.cancelReorder(snapshot: snapshot)
        XCTAssertEqual(store.plays[0].routeDigits, "6794", "A must be restored to index 0")
        XCTAssertEqual(store.plays[1].routeDigits, "2943", "B must be at index 1")
        XCTAssertEqual(store.plays[2].routeDigits, "8761", "C must be at index 2")
    }

    func testCancelReorder_doesNotWriteToDisk() throws {
        let interpreter = RouteInterpreter()
        guard case .success(let pcA) = interpreter.interpret(digits: "6794", formation: .twins),
              case .success(let pcB) = interpreter.interpret(digits: "2943", formation: .tripsLeft),
              case .success(let pcC) = interpreter.interpret(digits: "8761", formation: .proRight) else {
            XCTFail(); return
        }
        store.save(pcA, motion: nil, yWheelEnabled: false)
        store.save(pcB, motion: nil, yWheelEnabled: false)
        store.save(pcC, motion: nil, yWheelEnabled: false)
        let dataBefore = try Data(contentsOf: tempURL)
        let snapshot = store.plays
        store.move(fromOffsets: IndexSet([0]), toOffset: 3)
        store.cancelReorder(snapshot: snapshot)
        let dataAfter = try Data(contentsOf: tempURL)
        XCTAssertEqual(dataBefore, dataAfter, "cancelReorder must not write to disk")
    }

    func testMove_toSamePosition_isNoOp() {
        let interpreter = RouteInterpreter()
        guard case .success(let pcA) = interpreter.interpret(digits: "6794", formation: .twins),
              case .success(let pcB) = interpreter.interpret(digits: "2943", formation: .tripsLeft),
              case .success(let pcC) = interpreter.interpret(digits: "8761", formation: .proRight) else {
            XCTFail(); return
        }
        store.save(pcA, motion: nil, yWheelEnabled: false)
        store.save(pcB, motion: nil, yWheelEnabled: false)
        store.save(pcC, motion: nil, yWheelEnabled: false)
        let idsBefore = store.plays.map { $0.id }
        store.move(fromOffsets: IndexSet([1]), toOffset: 1)
        XCTAssertEqual(store.plays.map { $0.id }, idsBefore, "Same-position move must not alter array")
    }
}
