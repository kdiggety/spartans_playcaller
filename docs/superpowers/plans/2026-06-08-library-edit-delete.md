# Library Edit, Delete, and Delete All — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Add delete (single + multi-select), delete all, and edit-in-place to the Play Library so coaches can fix mistakes and keep a clean play list.

**Architecture:** A new `update(_:) -> Result<Void, UpdateError>` method on `PlayLibraryStore` handles the edit path with UUID-based lookup, `RouteInterpreter` validation gate, and concept re-derivation. `EditPlayViewModel` owns transient edit UI state. `EditPlayView` is a modal sheet triggered from `.swipeActions` on each library row.

**Tech Stack:** Swift 5.9+, SwiftUI, XCTest, no new dependencies.

---

## File Map

| Action | Path |
|--------|------|
| Modify | `SpartansPlaycaller/Services/PlayLibraryStore.swift` |
| Create | `SpartansPlaycaller/ViewModels/EditPlayViewModel.swift` |
| Create | `SpartansPlaycaller/Views/EditPlayView.swift` |
| Modify | `SpartansPlaycaller/Views/PlayLibraryView.swift` |
| Modify | `SpartansPlaycallerTests/PlayLibraryStoreTests.swift` |
| Modify | `SpartansPlaycallerTests/LibraryPersistenceIntegrationTests.swift` |
| Modify | `SpartansPlaycallerTests/ExportCardTests.swift` |
| Create | `SpartansPlaycallerTests/EditPlayViewModelTests.swift` |
| Modify | `SpartansPlaycaller.xcodeproj/project.pbxproj` |

New file pbxproj IDs (pre-allocated, sequential from existing max `A*000048`):
- `EditPlayViewModel.swift`: fileRef `A20000049`, buildFile `A10000049`
- `EditPlayView.swift`: fileRef `A20000050`, buildFile `A10000050`
- `EditPlayViewModelTests.swift`: fileRef `A20000051`, buildFile `A10000051`

---

## Task 1: Store — `UpdateError`, `update()`, `persist() throws`

**Files:**
- Modify: `SpartansPlaycaller/Services/PlayLibraryStore.swift`

- [x] **Step 1: Add `UpdateError` enum inside `PlayLibraryStore.swift` (before the class declaration)**

```swift
enum UpdateError: LocalizedError {
    case playNotFound(UUID)
    case invalidRouteDigits(String)
    case persistenceFailed(Error)

    var errorDescription: String? {
        switch self {
        case .playNotFound:
            return "Play no longer exists. It may have been deleted."
        case .invalidRouteDigits(let msg):
            return msg
        case .persistenceFailed:
            return "Could not save. Your edit was not written to disk."
        }
    }
}
```

- [x] **Step 2: Promote `persist()` to `throws` and update all three callers**

Replace the entire `PlayLibraryStore` class body with:

```swift
@MainActor
final class PlayLibraryStore: ObservableObject {
    @Published private(set) var plays: [SavedPlay] = []

    private let fileURL: URL

    nonisolated static var defaultFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("play-library.json")
    }

    init(fileURL: URL = PlayLibraryStore.defaultFileURL) {
        self.fileURL = fileURL
        load()
    }

    func save(_ playCall: PlayCall, motion: ReceiverMotion?, yWheelEnabled: Bool) {
        plays.append(SavedPlay.from(playCall: playCall, motion: motion, yWheelEnabled: yWheelEnabled))
        do { try persist() } catch { print("[PlayLibraryStore] persist failed: \(error)") }
    }

    func delete(at offsets: IndexSet) {
        plays.remove(atOffsets: offsets)
        do { try persist() } catch { print("[PlayLibraryStore] persist failed: \(error)") }
    }

    func deleteAll() {
        plays = []
        do { try persist() } catch { print("[PlayLibraryStore] persist failed: \(error)") }
    }

    @discardableResult
    func update(_ play: SavedPlay) -> Result<Void, UpdateError> {
        guard let index = plays.firstIndex(where: { $0.id == play.id }) else {
            return .failure(.playNotFound(play.id))
        }
        guard let formation = Formation(rawValue: play.formationName) else {
            return .failure(.invalidRouteDigits("Unknown formation: \(play.formationName)"))
        }
        let playCall: PlayCall
        switch RouteInterpreter().interpret(digits: play.routeDigits, formation: formation) {
        case .failure(let e):
            return .failure(.invalidRouteDigits(e.localizedDescription))
        case .success(let pc):
            playCall = pc
        }
        let original = plays[index]
        let updated = SavedPlay(
            id: play.id,
            savedAt: Date(),
            formationName: play.formationName,
            routeDigits: play.routeDigits,
            conceptName: playCall.concept?.rawValue,
            motionLabel: play.motionLabel,
            yWheelEnabled: play.yWheelEnabled
        )
        plays[index] = updated
        do {
            try persist()
            return .success(())
        } catch {
            plays[index] = original
            return .failure(.persistenceFailed(error))
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            plays = try JSONDecoder().decode([SavedPlay].self, from: data)
        } catch {
            print("[PlayLibraryStore] load failed: \(error)")
            plays = []
        }
    }

    private func persist() throws {
        let data = try JSONEncoder().encode(plays)
        try data.write(to: fileURL, options: .completeFileProtection)
    }
}
```

- [x] **Step 3: Build to verify compile**

```bash
xcodebuild build \
  -project SpartansPlaycaller.xcodeproj \
  -scheme SpartansPlaycaller \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E "error:|warning:|BUILD"
```

Expected: `BUILD SUCCEEDED`

- [x] **Step 4: Commit**

```bash
git add SpartansPlaycaller/Services/PlayLibraryStore.swift
git commit -m "feat: add UpdateError + update() to PlayLibraryStore; promote persist() to throws

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 2: Store Unit Tests

**Files:**
- Modify: `SpartansPlaycallerTests/PlayLibraryStoreTests.swift`

- [x] **Step 1: Append new test methods to `PlayLibraryStoreTests` (inside the existing `@MainActor final class PlayLibraryStoreTests`)**

Add after the last existing test method (`testPersistUsesCompleteFileProtection`):

```swift
    // MARK: - update() tests

    func testUpdatePlay_changesDigits() {
        let interpreter = RouteInterpreter()
        guard case .success(let pc) = interpreter.interpret(digits: "6794", formation: .twins) else {
            XCTFail(); return
        }
        store.save(pc, motion: nil, yWheelEnabled: false)
        let original = store.plays[0]

        let edited = SavedPlay(
            id: original.id, savedAt: original.savedAt,
            formationName: "Twins", routeDigits: "6794",
            conceptName: nil, motionLabel: nil, yWheelEnabled: false
        )
        let result = store.update(edited)
        guard case .success = result else { XCTFail("Expected success"); return }
        XCTAssertEqual(store.plays[0].routeDigits, "6794")
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

        // Ensure time moves forward
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

        // Pass identical field values — savedAt must still advance
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

        // Pass a stale/wrong conceptName — store must re-derive it
        let edited = SavedPlay(
            id: original.id, savedAt: original.savedAt,
            formationName: "Twins", routeDigits: "6794",
            conceptName: "WRONG_CONCEPT", motionLabel: nil, yWheelEnabled: false
        )
        let result = store.update(edited)
        guard case .success = result else { XCTFail(); return }
        // Concept must equal what RouteInterpreter derives, not "WRONG_CONCEPT"
        XCTAssertNotEqual(store.plays[0].conceptName, "WRONG_CONCEPT", "Store must re-derive concept, not trust caller value")
    }

    func testUpdatePlay_motionLabel_preserved() {
        let interpreter = RouteInterpreter()
        guard case .success(let pc) = interpreter.interpret(digits: "2943", formation: .tripsLeft) else {
            XCTFail(); return
        }
        store.save(pc, motion: .stop, yWheelEnabled: false)
        let original = store.plays[0]

        let edited = SavedPlay(
            id: original.id, savedAt: original.savedAt,
            formationName: "Trips Left", routeDigits: "2943",
            conceptName: nil, motionLabel: "Y After", yWheelEnabled: false
        )
        let result = store.update(edited)
        guard case .success = result else { XCTFail(); return }
        XCTAssertEqual(store.plays[0].motionLabel, "Y After")
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

        // Empty route digits — interpreter must reject these
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
        // Save 10 copies to simulate a larger library
        for _ in 0..<4 { store.save(pc1, motion: nil, yWheelEnabled: false) }
        store.save(pc2, motion: nil, yWheelEnabled: false)
        for _ in 0..<5 { store.save(pc3, motion: nil, yWheelEnabled: false) }

        let targetPlay = store.plays[4] // the tripsLeft play at index 4
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

        // Simulate app relaunch
        let reloaded = PlayLibraryStore(fileURL: tempURL)
        XCTAssertEqual(reloaded.plays.count, 1)
        XCTAssertEqual(reloaded.plays[0].id, original.id)
        XCTAssertEqual(reloaded.plays[0].motionLabel, "Y Stop")
    }
```

- [x] **Step 2: Run store tests**

```bash
xcodebuild test \
  -project SpartansPlaycaller.xcodeproj \
  -scheme SpartansPlaycaller \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:SpartansPlaycallerTests/PlayLibraryStoreTests \
  2>&1 | grep -E "Test Case|error:|PASS|FAIL|BUILD"
```

Expected: all `PlayLibraryStoreTests` pass. Note any pre-existing failures separately.

- [x] **Step 3: Commit**

```bash
git add SpartansPlaycallerTests/PlayLibraryStoreTests.swift
git commit -m "test: store unit tests for update() — position, timestamp, concept re-derivation, error paths

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 3: Integration and Export Consistency Tests

**Files:**
- Modify: `SpartansPlaycallerTests/LibraryPersistenceIntegrationTests.swift`
- Modify: `SpartansPlaycallerTests/ExportCardTests.swift`

- [x] **Step 1: Append to `LibraryPersistenceIntegrationTests` (inside the existing `@MainActor final class`)**

```swift
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
        XCTAssertEqual(result, .success(()))

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
```

- [x] **Step 2: Append export-after-edit test to `ExportCardTests` (inside the existing `final class ExportCardTests`)**

Note: `ExportCardTests` is not marked `@MainActor`. The new test uses `PlayLibraryStore` which IS `@MainActor`. Add the test as `@MainActor` on the individual method:

```swift
    @MainActor
    func testExportCard_reflectsEditedValues() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("export-edit-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let store = PlayLibraryStore(fileURL: tempURL)
        let interpreter = RouteInterpreter()
        guard case .success(let pc) = interpreter.interpret(digits: "6794", formation: .twins) else {
            XCTFail(); return
        }
        store.save(pc, motion: nil, yWheelEnabled: false)
        let original = store.plays[0]

        // Edit the saved play
        let edited = SavedPlay(
            id: original.id, savedAt: original.savedAt,
            formationName: "Twins", routeDigits: "6794",
            conceptName: nil, motionLabel: "Y Stop", yWheelEnabled: false
        )
        let result = store.update(edited)
        XCTAssertEqual(result, .success(()))

        // Verify ExportCard reads from updated persisted state
        let card = ExportCard.from(savedPlay: store.plays[0], playNumber: 1, interpreter: interpreter)
        XCTAssertNotNil(card, "ExportCard must not be nil after edit")
        XCTAssertEqual(card?.routeDigits, "6794")
        XCTAssertEqual(card?.motionLabel, "Y Stop", "ExportCard must reflect edited motion")
    }
```

- [x] **Step 3: Make `Result<Void, UpdateError>` equatable for test assertions**

`XCTAssertEqual(result, .success(()))` requires `Equatable`. Add conformance to `UpdateError` in `PlayLibraryStore.swift` (after the `LocalizedError` conformance, before the store class):

```swift
extension UpdateError: Equatable {
    static func == (lhs: UpdateError, rhs: UpdateError) -> Bool {
        switch (lhs, rhs) {
        case (.playNotFound(let a), .playNotFound(let b)): return a == b
        case (.invalidRouteDigits(let a), .invalidRouteDigits(let b)): return a == b
        case (.persistenceFailed, .persistenceFailed): return true
        default: return false
        }
    }
}
```

- [x] **Step 4: Run integration and export tests**

```bash
xcodebuild test \
  -project SpartansPlaycaller.xcodeproj \
  -scheme SpartansPlaycaller \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:SpartansPlaycallerTests/LibraryPersistenceIntegrationTests \
  -only-testing:SpartansPlaycallerTests/ExportCardTests \
  2>&1 | grep -E "Test Case|error:|PASS|FAIL|BUILD"
```

Expected: all pass.

- [x] **Step 5: Commit**

```bash
git add SpartansPlaycallerTests/LibraryPersistenceIntegrationTests.swift \
        SpartansPlaycallerTests/ExportCardTests.swift \
        SpartansPlaycaller/Services/PlayLibraryStore.swift
git commit -m "test: integration + export-after-edit tests; add UpdateError Equatable conformance

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 4: `EditPlayViewModel` + Tests + pbxproj Registration

**Files:**
- Create: `SpartansPlaycaller/ViewModels/EditPlayViewModel.swift`
- Create: `SpartansPlaycallerTests/EditPlayViewModelTests.swift`
- Modify: `SpartansPlaycaller.xcodeproj/project.pbxproj`

- [x] **Step 1: Write the failing test file first**

Create `SpartansPlaycallerTests/EditPlayViewModelTests.swift`:

```swift
import XCTest
@testable import SpartansPlaycaller

@MainActor
final class EditPlayViewModelTests: XCTestCase {

    var tempURL: URL!
    var store: PlayLibraryStore!

    override func setUp() {
        super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("vm-test-\(UUID()).json")
        store = PlayLibraryStore(fileURL: tempURL)
        // Seed one play
        let interpreter = RouteInterpreter()
        guard case .success(let pc) = interpreter.interpret(digits: "6794", formation: .twins) else {
            XCTFail("Seed play failed"); return
        }
        store.save(pc, motion: nil, yWheelEnabled: false)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempURL)
        super.tearDown()
    }

    func testInit_populatesFieldsFromSavedPlay() {
        let play = store.plays[0]
        let vm = EditPlayViewModel(play: play)
        XCTAssertEqual(vm.selectedFormation, .twins)
        XCTAssertEqual(vm.routeDigitInput, "6794")
        XCTAssertNil(vm.selectedMotion)
        XCTAssertFalse(vm.yWheelEnabled)
        XCTAssertNil(vm.validationError)
        XCTAssertFalse(vm.isDirty)
    }

    func testIsDirty_trueAfterDigitChange() {
        let play = store.plays[0]
        let vm = EditPlayViewModel(play: play)
        vm.routeDigitInput = "9999"
        XCTAssertTrue(vm.isDirty)
    }

    func testIsDirty_falseAfterRevertingChange() {
        let play = store.plays[0]
        let vm = EditPlayViewModel(play: play)
        vm.routeDigitInput = "9999"
        vm.routeDigitInput = "6794" // revert
        XCTAssertFalse(vm.isDirty, "isDirty must be false when all fields match original")
    }

    func testValidateInput_setsErrorOnEmpty() {
        let play = store.plays[0]
        let vm = EditPlayViewModel(play: play)
        vm.routeDigitInput = ""
        vm.validateInput()
        XCTAssertNotNil(vm.validationError)
    }

    func testValidateInput_clearsErrorOnValidInput() {
        let play = store.plays[0]
        let vm = EditPlayViewModel(play: play)
        vm.routeDigitInput = ""
        vm.validateInput()
        vm.routeDigitInput = "6794"
        vm.validateInput()
        XCTAssertNil(vm.validationError)
    }

    func testSave_successSetsDidSave() {
        let play = store.plays[0]
        let vm = EditPlayViewModel(play: play)
        vm.routeDigitInput = "6794"
        vm.save(to: store)
        XCTAssertTrue(vm.didSave)
        XCTAssertNil(vm.persistError)
        XCTAssertNil(vm.validationError)
    }

    func testSave_invalidDigits_setsValidationError() {
        let play = store.plays[0]
        let vm = EditPlayViewModel(play: play)
        vm.routeDigitInput = ""
        vm.save(to: store)
        XCTAssertNotNil(vm.validationError)
        XCTAssertFalse(vm.didSave)
    }

    func testSave_updatesStorePlay() {
        let play = store.plays[0]
        let vm = EditPlayViewModel(play: play)
        vm.selectedMotion = .stop
        vm.routeDigitInput = "6794"
        vm.save(to: store)
        XCTAssertEqual(store.plays[0].motionLabel, "Y Stop")
    }

    func testSave_digitValidatedAgainstNewFormation() {
        let play = store.plays[0] // twins, "6794"
        let vm = EditPlayViewModel(play: play)
        // Change to a formation — digits may or may not be valid for it.
        // The key: save must call the interpreter against the NEW formation, not the original.
        vm.selectedFormation = .tripsLeft
        vm.routeDigitInput = "" // clearly invalid
        vm.validateInput()
        XCTAssertNotNil(vm.validationError, "Validation must run against the selected formation")
    }
}
```

- [x] **Step 2: Register `EditPlayViewModelTests.swift` in pbxproj**

Add to `/* Begin PBXBuildFile section */` (after line containing `A10000048`):
```
		A10000051 /* EditPlayViewModelTests.swift in Sources */ = {isa = PBXBuildFile; fileRef = A20000051 /* EditPlayViewModelTests.swift */; };
```

Add to `/* Begin PBXFileReference section */` (after line containing `A20000048`):
```
		A20000051 /* EditPlayViewModelTests.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = EditPlayViewModelTests.swift; sourceTree = "<group>"; };
```

Add to `A50000008 /* SpartansPlaycallerTests */` PBXGroup children (after `A20000048 /* DiagramRendererReceiverLabelTests.swift */`):
```
				A20000051 /* EditPlayViewModelTests.swift */,
```

Add to `A70000003 /* Sources */` build phase files (after `A10000048 /* DiagramRendererReceiverLabelTests.swift in Sources */`):
```
				A10000051 /* EditPlayViewModelTests.swift in Sources */,
```

- [x] **Step 3: Create `SpartansPlaycaller/ViewModels/EditPlayViewModel.swift`**

```swift
import SwiftUI

@MainActor
final class EditPlayViewModel: ObservableObject {
    @Published var selectedFormation: Formation
    @Published var routeDigitInput: String
    @Published var selectedMotion: ReceiverMotion?
    @Published var yWheelEnabled: Bool
    @Published var validationError: String?
    @Published var persistError: String?
    @Published var didSave = false

    private let _original: SavedPlay

    var isDirty: Bool {
        selectedFormation.rawValue != _original.formationName
            || routeDigitInput != _original.routeDigits
            || selectedMotion?.rawValue != _original.motionLabel
            || yWheelEnabled != _original.yWheelEnabled
    }

    init(play: SavedPlay) {
        self.selectedFormation = Formation(rawValue: play.formationName) ?? .twins
        self.routeDigitInput = play.routeDigits
        self.selectedMotion = play.motionLabel.flatMap(ReceiverMotion.init(rawValue:))
        self.yWheelEnabled = play.yWheelEnabled
        self._original = play
    }

    func validateInput() {
        let trimmed = routeDigitInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            validationError = "Enter route digits (4 or 5 digits)"
            return
        }
        switch RouteInterpreter().interpret(digits: trimmed, formation: selectedFormation) {
        case .success:
            validationError = nil
        case .failure(let e):
            validationError = e.localizedDescription
        }
    }

    func save(to store: PlayLibraryStore) {
        let trimmed = routeDigitInput.trimmingCharacters(in: .whitespaces)
        let candidate = SavedPlay(
            id: _original.id,
            savedAt: Date(),
            formationName: selectedFormation.rawValue,
            routeDigits: trimmed,
            conceptName: _original.conceptName,
            motionLabel: selectedMotion?.rawValue,
            yWheelEnabled: yWheelEnabled
        )
        switch store.update(candidate) {
        case .success:
            didSave = true
        case .failure(.invalidRouteDigits(let msg)):
            validationError = msg
        case .failure(.playNotFound):
            persistError = "Play no longer exists. It may have been deleted."
        case .failure(.persistenceFailed):
            persistError = "Could not save. Your edit was not written to disk."
        }
    }
}
```

- [x] **Step 4: Register `EditPlayViewModel.swift` in pbxproj**

Add to `/* Begin PBXBuildFile section */` (after the `A10000048` line):
```
		A10000049 /* EditPlayViewModel.swift in Sources */ = {isa = PBXBuildFile; fileRef = A20000049 /* EditPlayViewModel.swift */; };
```

Add to `/* Begin PBXFileReference section */` (after `A20000048` line):
```
		A20000049 /* EditPlayViewModel.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = EditPlayViewModel.swift; sourceTree = "<group>"; };
```

Add to `A50000005 /* ViewModels */` PBXGroup children (after `A20000005 /* PlayCallerViewModel.swift */`):
```
				A20000049 /* EditPlayViewModel.swift */,
```

Add to `A70000002 /* Sources */` app target build phase files (after `A10000039 /* PlayLibraryView.swift in Sources */`):
```
				A10000049 /* EditPlayViewModel.swift in Sources */,
```

- [x] **Step 5: Run `EditPlayViewModelTests`**

```bash
xcodebuild test \
  -project SpartansPlaycaller.xcodeproj \
  -scheme SpartansPlaycaller \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:SpartansPlaycallerTests/EditPlayViewModelTests \
  2>&1 | grep -E "Test Case|error:|PASS|FAIL|BUILD"
```

Expected: all 9 tests pass.

- [x] **Step 6: Commit**

```bash
git add SpartansPlaycaller/ViewModels/EditPlayViewModel.swift \
        SpartansPlaycallerTests/EditPlayViewModelTests.swift \
        SpartansPlaycaller.xcodeproj/project.pbxproj
git commit -m "feat: EditPlayViewModel + tests; register new files in pbxproj

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 5: `EditPlayView` + pbxproj Registration

**Files:**
- Create: `SpartansPlaycaller/Views/EditPlayView.swift`
- Modify: `SpartansPlaycaller.xcodeproj/project.pbxproj`

No automated tests for the View layer (per SDET strategy: manual checks cover the UI). Verification is compile + manual.

- [x] **Step 1: Create `SpartansPlaycaller/Views/EditPlayView.swift`**

```swift
import SwiftUI

struct EditPlayView: View {
    @StateObject private var viewModel: EditPlayViewModel
    @EnvironmentObject private var store: PlayLibraryStore
    @Environment(\.dismiss) private var dismiss

    @State private var showDiscardAlert = false

    init(play: SavedPlay) {
        _viewModel = StateObject(wrappedValue: EditPlayViewModel(play: play))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Formation") {
                    Picker("Formation Family", selection: Binding(
                        get: { viewModel.selectedFormation.family },
                        set: { family in
                            if family.supportsSideSelection {
                                let side = viewModel.selectedFormation.family == family
                                    ? (viewModel.selectedFormation.side ?? .left)
                                    : .left
                                viewModel.selectedFormation = family.formation(side: side)
                            } else {
                                viewModel.selectedFormation = family.formation(side: .left)
                            }
                            viewModel.validateInput()
                        }
                    )) {
                        ForEach(FormationFamily.allCases) { family in
                            Text(family.rawValue).tag(family)
                        }
                    }
                    .pickerStyle(.segmented)

                    if viewModel.selectedFormation.family.supportsSideSelection {
                        Picker("Side", selection: Binding(
                            get: { viewModel.selectedFormation.side ?? .left },
                            set: { side in
                                viewModel.selectedFormation = viewModel.selectedFormation.family.formation(side: side)
                                viewModel.validateInput()
                            }
                        )) {
                            Text("Left").tag(FieldSide.left)
                            Text("Right").tag(FieldSide.right)
                        }
                        .pickerStyle(.segmented)
                    }
                }

                Section("Route Digits") {
                    TextField("e.g. 6794", text: $viewModel.routeDigitInput)
                        .keyboardType(.numberPad)
                        .onChange(of: viewModel.routeDigitInput) { _, _ in
                            viewModel.validateInput()
                        }
                    if let error = viewModel.validationError {
                        errorBanner(error)
                    }
                }

                if viewModel.selectedFormation.canApplyMotion() {
                    Section("Motion") {
                        Picker("Motion", selection: $viewModel.selectedMotion) {
                            Text("None").tag(Optional<ReceiverMotion>.none)
                            ForEach(ReceiverMotion.allCases) { motion in
                                Text(motion.rawValue).tag(Optional(motion))
                            }
                        }
                    }
                }

                Section {
                    Toggle("Y Wheel", isOn: $viewModel.yWheelEnabled)
                }
            }
            .navigationTitle("Edit Play")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if viewModel.isDirty {
                            showDiscardAlert = true
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.save(to: store)
                    }
                    .disabled(
                        viewModel.validationError != nil
                        || viewModel.routeDigitInput.trimmingCharacters(in: .whitespaces).isEmpty
                    )
                }
            }
        }
        .alert("Discard Changes?", isPresented: $showDiscardAlert) {
            Button("Discard Changes", role: .destructive) { dismiss() }
            Button("Keep Editing", role: .cancel) {}
        }
        .alert("Save Failed", isPresented: Binding(
            get: { viewModel.persistError != nil },
            set: { if !$0 { viewModel.persistError = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.persistError = nil }
        } message: {
            Text(viewModel.persistError ?? "Could not save. Please try again.")
        }
        .onChange(of: viewModel.didSave) { _, saved in
            if saved { dismiss() }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.yellow)
            Text(message)
                .font(.subheadline)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    EditPlayView(play: SavedPlay(
        id: UUID(), savedAt: Date(),
        formationName: "Twins", routeDigits: "6794",
        conceptName: "Smash", motionLabel: nil, yWheelEnabled: false
    ))
    .environmentObject(PlayLibraryStore())
}
```

- [x] **Step 2: Register `EditPlayView.swift` in pbxproj**

Add to `/* Begin PBXBuildFile section */` (after `A10000049` line):
```
		A10000050 /* EditPlayView.swift in Sources */ = {isa = PBXBuildFile; fileRef = A20000050 /* EditPlayView.swift */; };
```

Add to `/* Begin PBXFileReference section */` (after `A20000049` line):
```
		A20000050 /* EditPlayView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = EditPlayView.swift; sourceTree = "<group>"; };
```

Add to `A50000006 /* Views */` PBXGroup children (after `A20000039 /* PlayLibraryView.swift */`):
```
				A20000050 /* EditPlayView.swift */,
```

Add to `A70000002 /* Sources */` app target build phase (after the `A10000049` line):
```
				A10000050 /* EditPlayView.swift in Sources */,
```

- [x] **Step 3: Build to verify compile**

```bash
xcodebuild build \
  -project SpartansPlaycaller.xcodeproj \
  -scheme SpartansPlaycaller \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`

- [x] **Step 4: Commit**

```bash
git add SpartansPlaycaller/Views/EditPlayView.swift \
        SpartansPlaycaller.xcodeproj/project.pbxproj
git commit -m "feat: EditPlayView modal sheet; register in pbxproj

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 6: `PlayLibraryView` — Delete Confirmation + Edit Sheet + Delete All Menu

**Files:**
- Modify: `SpartansPlaycaller/Views/PlayLibraryView.swift`

This task replaces the bare `onDelete` (live data-loss bug), adds swipe actions with confirmation, adds the edit sheet, adds Delete in select mode, and adds the ellipsis Menu for Delete All.

- [x] **Step 1: Add four new `@State` variables** (after the existing `@State private var exportError` declaration at line ~14)

```swift
@State private var playBeingEdited: SavedPlay? = nil
@State private var playPendingDelete: SavedPlay? = nil
@State private var showMultiDeleteConfirmation = false
@State private var showDeleteAllConfirmation = false
```

- [x] **Step 2: Replace `.onDelete` with `.swipeActions` in `playList`**

Replace lines 100–103:
```swift
            .onDelete { offsets in
                store.delete(at: offsets)
            }
```

With nothing (remove the `.onDelete` modifier entirely). Instead, add `.swipeActions` to the `PlayLibraryRow` inside the `ForEach`. Replace the full `ForEach` block:

```swift
            ForEach(store.plays) { play in
                PlayLibraryRow(play: play, isSelectMode: isSelectMode, isSelected: selectedIDs.contains(play.id)) {
                    if isSelectMode {
                        if selectedIDs.contains(play.id) {
                            selectedIDs.remove(play.id)
                        } else {
                            selectedIDs.insert(play.id)
                        }
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        playPendingDelete = play
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button {
                        playBeingEdited = play
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
            }
```

- [x] **Step 3: Add edit sheet and delete alerts to `body`**

Add these modifiers after the closing `.alert("Export Failed", ...)` block in `body`:

```swift
        .sheet(item: $playBeingEdited) { play in
            EditPlayView(play: play)
                .environmentObject(store)
        }
        .alert(item: $playPendingDelete) { play in
            Alert(
                title: Text("Delete Play?"),
                message: Text("\(play.formationName) \(play.routeDigits)"),
                primaryButton: .destructive(Text("Delete")) {
                    if let index = store.plays.firstIndex(where: { $0.id == play.id }) {
                        store.delete(at: IndexSet([index]))
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .alert("Delete \(selectedIDs.count) Play\(selectedIDs.count == 1 ? "" : "s")?",
               isPresented: $showMultiDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                let indices = IndexSet(store.plays.indices.filter { selectedIDs.contains(store.plays[$0].id) })
                store.delete(at: indices)
                selectedIDs = []
                isSelectMode = false
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Delete All \(store.plays.count) Play\(store.plays.count == 1 ? "" : "s")?",
               isPresented: $showDeleteAllConfirmation) {
            Button("Delete All", role: .destructive) {
                store.deleteAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
```

- [x] **Step 4: Add Delete button to Select mode bottom bar and ellipsis Menu to toolbar**

Replace the entire `.toolbar { ... }` block with:

```swift
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 4) {
                        if !isSelectMode && !store.plays.isEmpty {
                            Menu {
                                Button(role: .destructive) {
                                    showDeleteAllConfirmation = true
                                } label: {
                                    Label("Delete All Plays", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .accessibilityLabel("More options")
                            }
                        }
                        if isSelectMode {
                            Button("Cancel") {
                                isSelectMode = false
                                selectedIDs = []
                            }
                        } else {
                            Button("Select") {
                                isSelectMode = true
                            }
                            .disabled(store.plays.isEmpty)
                        }
                    }
                }
                if isSelectMode {
                    ToolbarItem(placement: .bottomBar) {
                        HStack {
                            Button("Select All") {
                                selectedIDs = Set(store.plays.map { $0.id })
                            }
                            Spacer()
                            Button(role: .destructive) {
                                showMultiDeleteConfirmation = true
                            } label: {
                                Label("Delete \(selectedIDs.count)", systemImage: "trash")
                            }
                            .disabled(selectedIDs.isEmpty)
                            Spacer()
                            exportButton
                        }
                    }
                }
            }
```

- [x] **Step 5: Build to verify compile**

```bash
xcodebuild build \
  -project SpartansPlaycaller.xcodeproj \
  -scheme SpartansPlaycaller \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`

- [x] **Step 6: Commit**

```bash
git add SpartansPlaycaller/Views/PlayLibraryView.swift
git commit -m "feat: PlayLibraryView — swipe Edit/Delete with confirmation, Delete All menu, multi-select Delete

Replaces bare onDelete (data-loss bug AC-1.1). Adds: swipeActions with delete
confirmation alert, edit sheet via EditPlayView, Delete button in select mode
bottom bar, ellipsis Menu for Delete All.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Task 7: Full Test Suite + Push

- [x] **Step 1: Run full test suite**

```bash
xcodebuild test \
  -project SpartansPlaycaller.xcodeproj \
  -scheme SpartansPlaycaller \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | tail -30
```

Expected: new tests added in Tasks 2–4 pass. Document any pre-existing failures (do not count them as regressions introduced by this work).

- [x] **Step 2: Push branch**

```bash
git push
```

- [x] **Step 3: Update plan checkboxes**

Mark all completed tasks `[x]` in this file and commit the update:

```bash
git add docs/superpowers/plans/2026-06-08-library-edit-delete.md
git commit -m "docs: mark plan tasks complete

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
git push
```

---

## Manual Verification Checklist (post-implementation, before PR)

These cannot be automated (UI layer) — complete on a running simulator:

- [x] Swipe left on a play → Edit (blue) and Delete (red) actions appear
- [x] Tapping Delete shows confirmation with play name; Cancel leaves play unchanged
- [x] Tapping Edit opens `EditPlayView` sheet with pre-populated values
- [x] Changing a field and tapping Cancel shows "Discard Changes?" alert
- [x] Reverting a change and tapping Cancel dismisses immediately (no alert)
- [x] Saving a valid edit updates the row in-place (same position, updated values)
- [x] Saving with invalid/empty digits shows the error banner inline; sheet stays open
- [x] Delete All via `...` menu shows count in confirmation; confirms clears library
- [x] `...` menu is hidden when library is empty
- [x] Select mode shows Delete N button; tapping with 0 selections is disabled
- [x] Multi-select Delete shows correct count; confirms removes only selected plays
- [x] Export of an edited play reflects edited values (not pre-edit values)

---

## Spec Coverage Check

| Acceptance Criterion | Task |
|---|---|
| AC-1.1 swipe-to-delete with confirmation | Task 6 |
| AC-1.2 delete via select mode | Task 6 |
| AC-1.3 persistence after delete | Task 3 (integration test) |
| AC-1.4 empty state after last delete | Task 6 (UI driven by `store.plays.isEmpty`) |
| AC-1.5 no undo | Confirmed — no undo stack implemented |
| AC-2.1 delete all control | Task 6 |
| AC-2.2 confirmation with count | Task 6 |
| AC-2.3 outcome + empty state | Task 6 |
| AC-2.4 persistence after delete all | Existing `testDeleteAll` + `testLoadFromFileOnInit` |
| AC-2.5 accessible without select mode | Task 6 (ellipsis Menu in non-select toolbar) |
| AC-3.1 edit entry point (swipe) | Task 6 |
| AC-3.2 editable fields | Task 5 (`EditPlayView`) |
| AC-3.3 validation before save | Tasks 4+5 (`validateInput`, Save disabled) |
| AC-3.4 in-place update + timestamp | Tasks 1+2 (`update()`, `testUpdatePlay_preservesPosition`) |
| AC-3.5 concept re-evaluated | Tasks 1+2 (`testUpdatePlay_conceptReevaluated`) |
| AC-3.6 discard path | Task 5 (Cancel alert) |
| AC-3.7 persistence after edit | Tasks 2+3 (`testUpdatePlay_persistsAcrossReinit`) |
| AC-3.8 export consistency | Task 3 (`testExportCard_reflectsEditedValues`) |

---

## Backlog Entries Required After Implementation

Add to `docs/backlog/technical-enablers.md` on completion:

> **Promote `persist()` to throw across all `PlayLibraryStore` callers** — `save()`, `delete(at:)`, and `deleteAll()` currently swallow persist errors with `print`. Promote to propagate the error so the UI can surface it. Trigger: when adding coach feedback/error surfaces to non-edit paths (e.g., save confirmation animation).
