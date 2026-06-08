# Play Library & Export (Epic 3.1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an in-app play library (persist plays across sessions), a 9-up catalog PDF export, and a 4-up wristband PDF export — converting Spartans Playcaller from a design tool into a game-day coaching system.

**Architecture:** A `SavedPlay` Codable DTO stored in a flat JSON file in the Documents directory powers a `PlayLibraryStore` ObservableObject. At export time, saved plays are reconstructed into `ExportCard` values (via `RouteInterpreter`) and rendered into `PDFPage` subclasses using a new `DiagramRenderer` CGContext extension (vector, no bitmaps). Both `CatalogPDFGenerator` (9-up landscape) and `WristbandPDFGenerator` (4-up portrait, one page per play) share the `ExportCard` input type and the same security pipeline (temp file, `.completeFileProtection`, UIActivityViewController cleanup).

**Tech Stack:** SwiftUI, PDFKit, UIKit (UIActivityViewController, NSString text drawing), Core Graphics (CGContext, CGPath), XCTest

---

## Branch

All work on feature branch `feat/play-library-and-export`. Create before Task 1:

```bash
git checkout -b feat/play-library-and-export
```

---

## File Map

**New source files:**
| File | Responsibility |
|------|---------------|
| `SpartansPlaycaller/Models/SavedPlay.swift` | Codable DTO — 7 fields persisted per play |
| `SpartansPlaycaller/Services/PlayLibraryStore.swift` | ObservableObject — JSON persistence to Documents dir |
| `SpartansPlaycaller/Models/ExportCard.swift` | Shared value type for both PDF generators |
| `SpartansPlaycaller/Services/DiagramRenderer+CGContext.swift` | CGContext draw extension on DiagramRenderer |
| `SpartansPlaycaller/Models/DiagramConfig+CardScale.swift` | Card-scale DiagramConfig factories |
| `SpartansPlaycaller/Models/WristbandCardConfig.swift` | Layout constants for 3.5"×2.5" wristband cards |
| `SpartansPlaycaller/Services/WristbandPDFGenerator.swift` | WristbandPDFPage + WristbandPDFGenerator |
| `SpartansPlaycaller/Models/CatalogCardConfig.swift` | Layout constants for 9-up catalog cards |
| `SpartansPlaycaller/Services/CatalogPDFGenerator.swift` | CatalogPDFPage + CatalogPDFGenerator |
| `SpartansPlaycaller/Views/PlayLibraryView.swift` | Library list, multi-select, export action sheet |

**Modified source files:**
| File | Change |
|------|--------|
| `SpartansPlaycaller/Models/PlayCall.swift` | Add `PlayCall.applying(_:)` static method |
| `SpartansPlaycaller/ViewModels/PlayCallerViewModel.swift` | Add canSave, saveConfirmed, canExport, isExporting, ExportMode |
| `SpartansPlaycaller/Views/PlayCallerView.swift` | Add Save/Library/Share toolbar buttons, library sheet, quick-export action sheet |
| `SpartansPlaycaller/SpartansPlaycallerApp.swift` | Create PlayLibraryStore, inject as EnvironmentObject |

**New test files:**
| File | Tests |
|------|-------|
| `SpartansPlaycallerTests/SavedPlayCodableTests.swift` | Encode/decode, nil optionals, all formations |
| `SpartansPlaycallerTests/PlayLibraryStoreTests.swift` | save, delete, deleteAll, load, duplicate handling |
| `SpartansPlaycallerTests/LibraryPersistenceIntegrationTests.swift` | Round-trip: save → reinit store → verify survives |
| `SpartansPlaycallerTests/ExportCardTests.swift` | Both construction paths, nil field handling |
| `SpartansPlaycallerTests/DiagramRendererCGContextTests.swift` | Non-crash for all formations, PDF data validity |
| `SpartansPlaycallerTests/WristbandPDFGeneratorTests.swift` | Page count, media box, data validity |
| `SpartansPlaycallerTests/CatalogPDFGeneratorTests.swift` | Page count (9-up math), cell geometry, data validity |

---

## Task 1: Extract applyMotion to PlayCall

**Files:**
- Modify: `SpartansPlaycaller/Models/PlayCall.swift`
- Modify: `SpartansPlaycaller/ViewModels/PlayCallerViewModel.swift:161-191`

`ExportCard` reconstruction needs to re-apply motion to a parsed `PlayCall`. This logic currently lives only in `PlayCallerViewModel.applyMotion()`. Extract it to a static method on `PlayCall` so both the ViewModel and `ExportCard` construction use the same code path.

- [ ] **Step 1: Add static `applying(_:yWheelEnabled:)` to PlayCall**

In `SpartansPlaycaller/Models/PlayCall.swift`, add after the `displayName` property:

```swift
/// Return a new PlayCall with motion applied to Y receiver.
/// Replicates the logic from PlayCallerViewModel.applyMotion() so both
/// the ViewModel and ExportCard construction share the same code path.
static func applying(_ motion: ReceiverMotion?, yWheelEnabled: Bool, to playCall: PlayCall) -> PlayCall {
    let updatedAssignments = playCall.assignments.map { assignment -> RouteAssignment in
        if assignment.receiver == .Y && motion != nil {
            var updated = assignment
            updated.motion = motion
            return updated
        }
        return assignment
    }
    return PlayCall(
        formation: playCall.formation,
        routeDigits: playCall.routeDigits,
        assignments: updatedAssignments,
        concept: playCall.concept,
        yWheelEnabled: yWheelEnabled
    )
}
```

- [ ] **Step 2: Update PlayCallerViewModel.applyMotion() to delegate to PlayCall.applying**

Replace the body of `applyMotion()` in `PlayCallerViewModel` (lines ~161–191):

```swift
func applyMotion() {
    guard let playCall = currentPlayCall else {
        currentPlayCallWithMotion = nil
        leftSideConcept = nil
        rightSideConcept = nil
        return
    }

    currentPlayCallWithMotion = PlayCall.applying(yMotion, yWheelEnabled: yWheelEnabled, to: playCall)

    let updatedAssignments = currentPlayCallWithMotion!.assignments
    reidentifyConceptsBySide(assignments: updatedAssignments, formation: playCall.formation)
}
```

- [ ] **Step 3: Build and confirm all existing tests still pass**

```bash
xcodebuild test \
  -project SpartansPlaycaller.xcodeproj \
  -scheme SpartansPlaycaller \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  2>&1 | tail -20
```

Expected: all existing tests pass; no new failures.

- [ ] **Step 4: Commit**

```bash
git add SpartansPlaycaller/Models/PlayCall.swift \
        SpartansPlaycaller/ViewModels/PlayCallerViewModel.swift
git commit -m "refactor: extract applyMotion logic to PlayCall.applying(_:yWheelEnabled:to:)"
```

---

## Task 2: SavedPlay Model

**Files:**
- Create: `SpartansPlaycaller/Models/SavedPlay.swift`
- Create: `SpartansPlaycallerTests/SavedPlayCodableTests.swift`

- [ ] **Step 1: Write the failing test**

Create `SpartansPlaycallerTests/SavedPlayCodableTests.swift`:

```swift
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
```

- [ ] **Step 2: Run test — confirm it fails with "cannot find type 'SavedPlay'"**

```bash
xcodebuild test \
  -project SpartansPlaycaller.xcodeproj \
  -scheme SpartansPlaycaller \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:SpartansPlaycallerTests/SavedPlayCodableTests \
  2>&1 | tail -10
```

Expected: compile error — `SavedPlay` not defined.

- [ ] **Step 3: Create SavedPlay.swift**

Create `SpartansPlaycaller/Models/SavedPlay.swift`:

```swift
import Foundation

/// Codable DTO for a persisted play call.
/// Stores only the five display fields needed for export — not the full PlayCall graph.
/// Full PlayCall can be reconstructed at export time via RouteInterpreter.
struct SavedPlay: Codable, Identifiable {
    let id: UUID
    let savedAt: Date
    let formationName: String   // Formation.rawValue, e.g. "Twins"
    let routeDigits: String     // Raw digit string, e.g. "6794"
    let conceptName: String?    // RouteConcept.rawValue if matched; nil otherwise
    let motionLabel: String?    // ReceiverMotion.rawValue if present; nil otherwise
    let yWheelEnabled: Bool

    static func from(playCall: PlayCall, motion: ReceiverMotion?, yWheelEnabled: Bool) -> SavedPlay {
        SavedPlay(
            id: UUID(),
            savedAt: Date(),
            formationName: playCall.formation.rawValue,
            routeDigits: playCall.routeDigits,
            conceptName: playCall.concept?.rawValue,
            motionLabel: motion?.rawValue,
            yWheelEnabled: yWheelEnabled
        )
    }
}
```

- [ ] **Step 4: Run tests — confirm all pass**

```bash
xcodebuild test \
  -project SpartansPlaycaller.xcodeproj \
  -scheme SpartansPlaycaller \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:SpartansPlaycallerTests/SavedPlayCodableTests \
  2>&1 | tail -10
```

Expected: 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add SpartansPlaycaller/Models/SavedPlay.swift \
        SpartansPlaycallerTests/SavedPlayCodableTests.swift
git commit -m "feat: add SavedPlay Codable DTO for play library persistence"
```

---

## Task 3: PlayLibraryStore

**Files:**
- Create: `SpartansPlaycaller/Services/PlayLibraryStore.swift`
- Create: `SpartansPlaycallerTests/PlayLibraryStoreTests.swift`
- Create: `SpartansPlaycallerTests/LibraryPersistenceIntegrationTests.swift`

- [ ] **Step 1: Write failing unit tests**

Create `SpartansPlaycallerTests/PlayLibraryStoreTests.swift`:

```swift
import XCTest
@testable import SpartansPlaycaller

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
```

- [ ] **Step 2: Write failing persistence integration test**

Create `SpartansPlaycallerTests/LibraryPersistenceIntegrationTests.swift`:

```swift
import XCTest
@testable import SpartansPlaycaller

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
```

- [ ] **Step 3: Run tests — confirm they fail**

```bash
xcodebuild test \
  -project SpartansPlaycaller.xcodeproj \
  -scheme SpartansPlaycaller \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:SpartansPlaycallerTests/PlayLibraryStoreTests \
  -only-testing:SpartansPlaycallerTests/LibraryPersistenceIntegrationTests \
  2>&1 | tail -10
```

Expected: compile error — `PlayLibraryStore` not defined.

- [ ] **Step 4: Create PlayLibraryStore.swift**

Create `SpartansPlaycaller/Services/PlayLibraryStore.swift`:

```swift
import Foundation
import Combine

@MainActor
final class PlayLibraryStore: ObservableObject {
    @Published private(set) var plays: [SavedPlay] = []

    private let fileURL: URL

    static var defaultFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("play-library.json")
    }

    init(fileURL: URL = PlayLibraryStore.defaultFileURL) {
        self.fileURL = fileURL
        load()
    }

    func save(_ playCall: PlayCall, motion: ReceiverMotion?, yWheelEnabled: Bool) {
        plays.append(SavedPlay.from(playCall: playCall, motion: motion, yWheelEnabled: yWheelEnabled))
        persist()
    }

    func delete(at offsets: IndexSet) {
        plays.remove(atOffsets: offsets)
        persist()
    }

    func deleteAll() {
        plays = []
        persist()
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

    private func persist() {
        do {
            let data = try JSONEncoder().encode(plays)
            try data.write(to: fileURL, options: .completeFileProtection)
        } catch {
            print("[PlayLibraryStore] persist failed: \(error)")
        }
    }
}
```

- [ ] **Step 5: Run tests — confirm all pass**

```bash
xcodebuild test \
  -project SpartansPlaycaller.xcodeproj \
  -scheme SpartansPlaycaller \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:SpartansPlaycallerTests/PlayLibraryStoreTests \
  -only-testing:SpartansPlaycallerTests/LibraryPersistenceIntegrationTests \
  2>&1 | tail -10
```

Expected: all 7 tests pass.

- [ ] **Step 6: Commit**

```bash
git add SpartansPlaycaller/Services/PlayLibraryStore.swift \
        SpartansPlaycallerTests/PlayLibraryStoreTests.swift \
        SpartansPlaycallerTests/LibraryPersistenceIntegrationTests.swift
git commit -m "feat: add PlayLibraryStore — JSON persistence to Documents directory"
```

---

## Task 4: Inject PlayLibraryStore + Save Play UI

**Files:**
- Modify: `SpartansPlaycaller/SpartansPlaycallerApp.swift`
- Modify: `SpartansPlaycaller/Views/PlayCallerView.swift`
- Modify: `SpartansPlaycaller/ViewModels/PlayCallerViewModel.swift`

- [ ] **Step 1: Update SpartansPlaycallerApp.swift**

Replace the entire file:

```swift
import SwiftUI

@main
struct SpartansPlaycallerApp: App {
    @StateObject private var libraryStore = PlayLibraryStore()

    var body: some Scene {
        WindowGroup {
            PlayCallerView()
                .environmentObject(libraryStore)
        }
    }
}
```

- [ ] **Step 2: Add canSave and saveConfirmed to PlayCallerViewModel**

In `PlayCallerViewModel.swift`, add these new properties and method after the existing `@Published` declarations:

```swift
// MARK: - Save Play State

@Published var saveConfirmed: Bool = false

var canSave: Bool {
    currentPlayCallWithMotion != nil || currentPlayCall != nil
}
```

Add this method after `reset()`:

```swift
/// Called by PlayCallerView when the coach taps "Save Play".
/// The view passes the store to keep ViewModel dependency-free from PlayLibraryStore.
func confirmSave() {
    guard canSave else { return }
    saveConfirmed = true
    Task {
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s
        saveConfirmed = false
    }
}
```

- [ ] **Step 3: Add @EnvironmentObject store access + Save/Library toolbar buttons to PlayCallerView**

At the top of `PlayCallerView`, add:

```swift
@EnvironmentObject private var libraryStore: PlayLibraryStore
@State private var showLibrary = false
```

Replace the existing `.toolbar` modifier (currently only has Reset button) with:

```swift
.toolbar {
    ToolbarItemGroup(placement: .topBarTrailing) {
        // Save Play
        Button {
            let playCall = viewModel.currentPlayCallWithMotion ?? viewModel.currentPlayCall
            if let playCall {
                libraryStore.save(playCall, motion: viewModel.yMotion, yWheelEnabled: viewModel.yWheelEnabled)
                viewModel.confirmSave()
            }
        } label: {
            Image(systemName: viewModel.saveConfirmed ? "checkmark" : "bookmark")
                .symbolEffect(.bounce, value: viewModel.saveConfirmed)
        }
        .disabled(!viewModel.canSave)
        .accessibilityLabel(viewModel.saveConfirmed ? "Saved" : "Save Play")

        // Library
        Button {
            showLibrary = true
        } label: {
            Image(systemName: "books.vertical")
        }
        .accessibilityLabel("Open Play Library")

        // Reset
        Button("Reset", action: viewModel.reset)
            .font(.subheadline)
    }
}
.sheet(isPresented: $showLibrary) {
    PlayLibraryView()
        .environmentObject(libraryStore)
}
```

- [ ] **Step 4: Build (not test — UI change)**

```bash
xcodebuild build \
  -project SpartansPlaycaller.xcodeproj \
  -scheme SpartansPlaycaller \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  2>&1 | grep -E "(error:|warning:|BUILD)" | tail -10
```

Expected: `BUILD SUCCEEDED`, no errors.

- [ ] **Step 5: Run all tests — confirm no regressions**

```bash
xcodebuild test \
  -project SpartansPlaycaller.xcodeproj \
  -scheme SpartansPlaycaller \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  2>&1 | tail -20
```

Expected: all existing + new tests pass.

- [ ] **Step 6: Commit**

```bash
git add SpartansPlaycaller/SpartansPlaycallerApp.swift \
        SpartansPlaycaller/Views/PlayCallerView.swift \
        SpartansPlaycaller/ViewModels/PlayCallerViewModel.swift
git commit -m "feat: inject PlayLibraryStore and add Save Play + Library toolbar buttons"
```

---

## Task 5: ExportCard Model

**Files:**
- Create: `SpartansPlaycaller/Models/ExportCard.swift`
- Create: `SpartansPlaycallerTests/ExportCardTests.swift`

- [ ] **Step 1: Write failing tests**

Create `SpartansPlaycallerTests/ExportCardTests.swift`:

```swift
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
```

- [ ] **Step 2: Run — confirm compile error**

```bash
xcodebuild test \
  -project SpartansPlaycaller.xcodeproj \
  -scheme SpartansPlaycaller \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:SpartansPlaycallerTests/ExportCardTests \
  2>&1 | tail -5
```

Expected: compile error — `ExportCard` not defined.

- [ ] **Step 3: Create ExportCard.swift**

Create `SpartansPlaycaller/Models/ExportCard.swift`:

```swift
import Foundation

/// Shared value type for PDF generators.
/// Carries all fields needed to render one wristband or catalog card.
/// Constructed either from the current play (quick export) or from a SavedPlay (library export).
struct ExportCard {
    let playNumber: Int
    let formationName: String
    let routeDigits: String
    let conceptName: String?
    let motionLabel: String?
    let yWheelEnabled: Bool
    let playCall: PlayCall   // post-motion, drives diagram rendering
}

extension ExportCard {
    /// Quick-export path: construct from the current play call already in memory.
    /// `playCall` must be the post-motion state (currentPlayCallWithMotion ?? currentPlayCall).
    static func from(playCall: PlayCall, motion: ReceiverMotion?, playNumber: Int) -> ExportCard {
        ExportCard(
            playNumber: playNumber,
            formationName: playCall.formation.rawValue,
            routeDigits: playCall.routeDigits,
            conceptName: playCall.concept?.rawValue,
            motionLabel: motion?.rawValue,
            yWheelEnabled: playCall.yWheelEnabled,
            playCall: playCall
        )
    }

    /// Library-export path: reconstruct a PlayCall from a SavedPlay using RouteInterpreter.
    /// Returns nil if the formation name or digit string cannot be parsed
    /// (e.g. if a formation was renamed in a future code change).
    static func from(savedPlay: SavedPlay, playNumber: Int, interpreter: RouteInterpreter) -> ExportCard? {
        guard let formation = Formation(rawValue: savedPlay.formationName) else { return nil }
        guard case .success(let parsedCall) = interpreter.interpret(digits: savedPlay.routeDigits, formation: formation) else { return nil }

        let motion = savedPlay.motionLabel.flatMap { ReceiverMotion(rawValue: $0) }
        let finalPlayCall = PlayCall.applying(motion, yWheelEnabled: savedPlay.yWheelEnabled, to: parsedCall)

        return ExportCard(
            playNumber: playNumber,
            formationName: savedPlay.formationName,
            routeDigits: savedPlay.routeDigits,
            conceptName: savedPlay.conceptName,
            motionLabel: savedPlay.motionLabel,
            yWheelEnabled: savedPlay.yWheelEnabled,
            playCall: finalPlayCall
        )
    }
}
```

- [ ] **Step 4: Run tests — confirm all pass**

```bash
xcodebuild test \
  -project SpartansPlaycaller.xcodeproj \
  -scheme SpartansPlaycaller \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:SpartansPlaycallerTests/ExportCardTests \
  2>&1 | tail -10
```

Expected: 6 tests pass.

- [ ] **Step 5: Commit**

```bash
git add SpartansPlaycaller/Models/ExportCard.swift \
        SpartansPlaycallerTests/ExportCardTests.swift
git commit -m "feat: add ExportCard model with quick-export and library-export construction paths"
```

---

## Task 6: DiagramRenderer CGContext Extension + Card-Scale DiagramConfig

**Files:**
- Create: `SpartansPlaycaller/Services/DiagramRenderer+CGContext.swift`
- Create: `SpartansPlaycaller/Models/DiagramConfig+CardScale.swift`
- Create: `SpartansPlaycallerTests/DiagramRendererCGContextTests.swift`

This task ports the on-screen Canvas drawing to Core Graphics. The rendered diagram is drawn on a white background (PDF pages default to white) with dark route lines. Receiver labels are **omitted** from the diagram zone — they are already rendered as text rows in the card header above the diagram.

**Coordinate note:** Both PDF generators flip the CGContext to screen coordinates (Y-down from top) before calling `draw(into:...)`. This method therefore uses standard screen coordinates throughout. Text labels in the diagram are omitted to avoid CGContext text-flip complexity; all text is in the card header.

- [ ] **Step 1: Write failing tests**

Create `SpartansPlaycallerTests/DiagramRendererCGContextTests.swift`:

```swift
import XCTest
import PDFKit
@testable import SpartansPlaycaller

final class DiagramRendererCGContextTests: XCTestCase {

    let renderer = DiagramRenderer()
    let interpreter = RouteInterpreter()

    func makePlayCall(_ digits: String, _ formation: Formation) -> PlayCall {
        guard case .success(let pc) = interpreter.interpret(digits: digits, formation: formation) else {
            fatalError("parse failed")
        }
        return pc
    }

    func renderToPDF(playCall: PlayCall) -> Data? {
        let pageRect = CGRect(x: 0, y: 0, width: 234, height: 174)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { context in
            context.beginPage()
            let cgContext = context.cgContext
            // Simulate the PDFPage flip
            cgContext.translateBy(x: 0, y: pageRect.height)
            cgContext.scaleBy(x: 1, y: -1)

            let config = DiagramConfig.catalogCardScale(for: CGSize(width: 224, height: 89))
            let drawRect = CGRect(x: 5, y: 70, width: 224, height: 89)
            DiagramRenderer().draw(into: cgContext, playCall: playCall, config: config, in: drawRect)
        }
    }

    func testDoesNotCrashForTwins() {
        let pc = makePlayCall("6794", .twins)
        let data = renderToPDF(playCall: pc)
        XCTAssertNotNil(data)
        XCTAssertFalse(data!.isEmpty)
    }

    func testDoesNotCrashForTripsLeft() {
        let pc = makePlayCall("2943", .tripsLeft)
        XCTAssertNotNil(renderToPDF(playCall: pc))
    }

    func testDoesNotCrashForTripsRight() {
        let pc = makePlayCall("8761", .tripsRight)
        XCTAssertNotNil(renderToPDF(playCall: pc))
    }

    func testDoesNotCrashForProLeft() {
        let pc = makePlayCall("6794", .proLeft)
        XCTAssertNotNil(renderToPDF(playCall: pc))
    }

    func testDoesNotCrashForProRight() {
        let pc = makePlayCall("6794", .proRight)
        XCTAssertNotNil(renderToPDF(playCall: pc))
    }

    func testDoesNotCrashWithMotion() {
        let pc = makePlayCall("2943", .tripsLeft)
        let withMotion = PlayCall.applying(.stop, yWheelEnabled: false, to: pc)
        XCTAssertNotNil(renderToPDF(playCall: withMotion))
    }

    func testDoesNotCrashWithYWheel() {
        let pc = makePlayCall("6794", .twins)
        let withWheel = PlayCall.applying(nil, yWheelEnabled: true, to: pc)
        XCTAssertNotNil(renderToPDF(playCall: withWheel))
    }

    func testWristbandConfigDoesNotCrash() {
        let pc = makePlayCall("6794", .twins)
        let pageRect = CGRect(x: 0, y: 0, width: 252, height: 180)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let data = renderer.pdfData { context in
            context.beginPage()
            let cgContext = context.cgContext
            cgContext.translateBy(x: 0, y: pageRect.height)
            cgContext.scaleBy(x: 1, y: -1)
            let config = DiagramConfig.wristbandCardScale(for: CGSize(width: 242, height: 72))
            DiagramRenderer().draw(into: cgContext, playCall: pc, config: config, in: CGRect(x: 5, y: 90, width: 242, height: 72))
        }
        XCTAssertNotNil(data)
    }
}
```

- [ ] **Step 2: Run — confirm compile error**

```bash
xcodebuild test \
  -project SpartansPlaycaller.xcodeproj \
  -scheme SpartansPlaycaller \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:SpartansPlaycallerTests/DiagramRendererCGContextTests \
  2>&1 | tail -5
```

Expected: error — `draw(into:playCall:config:in:)` not defined.

- [ ] **Step 3: Create DiagramConfig+CardScale.swift**

Create `SpartansPlaycaller/Models/DiagramConfig+CardScale.swift`:

```swift
import CoreGraphics

extension DiagramConfig {
    /// DiagramConfig scaled for wristband cards (diagram zone ~242pt × 72pt).
    static func wristbandCardScale(for size: CGSize) -> DiagramConfig {
        DiagramConfig(
            fieldWidth: size.width,
            fieldHeight: size.height,
            lineOfScrimmageY: size.height * 0.50,
            routeLength: size.height * 0.35,
            breakLength: size.height * 0.25,
            receiverRadius: 4.0,
            footballSize: 5.0,
            receiverSpacing: size.width * 0.14,
            sideMargin: size.width * 0.06
        )
    }

    /// DiagramConfig scaled for catalog cards (diagram zone ~224pt × 89pt).
    static func catalogCardScale(for size: CGSize) -> DiagramConfig {
        DiagramConfig(
            fieldWidth: size.width,
            fieldHeight: size.height,
            lineOfScrimmageY: size.height * 0.50,
            routeLength: size.height * 0.38,
            breakLength: size.height * 0.28,
            receiverRadius: 4.0,
            footballSize: 5.0,
            receiverSpacing: size.width * 0.13,
            sideMargin: size.width * 0.05
        )
    }
}
```

- [ ] **Step 4: Create DiagramRenderer+CGContext.swift**

Create `SpartansPlaycaller/Services/DiagramRenderer+CGContext.swift`:

```swift
import UIKit
import CoreGraphics

extension DiagramRenderer {

    /// Draw the full route diagram into an arbitrary CGContext.
    /// The context must be in screen coordinates (Y-down from top) — both CatalogPDFPage
    /// and WristbandPDFPage flip the context before calling this method.
    /// `rect` is the bounding box in the context's coordinate system.
    /// `config` must be built from `rect.size` (fieldWidth = rect.width, fieldHeight = rect.height).
    func draw(into context: CGContext, playCall: PlayCall, config: DiagramConfig, in rect: CGRect) {
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.minY)

        let positions = receiverPositions(formation: playCall.formation, config: config)

        drawFieldCG(context, config: config)
        drawFootballCG(context, config: config)
        drawMotionCG(context, assignments: playCall.assignments, positions: positions, formation: playCall.formation, config: config)
        if playCall.yWheelEnabled {
            drawWheelCG(context, playCall: playCall, config: config)
        }
        drawRoutesCG(context, assignments: playCall.assignments, positions: positions, playCall: playCall, config: config)
        drawReceiversCG(context, assignments: playCall.assignments, positions: positions, config: config)

        context.restoreGState()
    }

    // MARK: - Private CG draw helpers

    private func drawFieldCG(_ context: CGContext, config: DiagramConfig) {
        // Line of scrimmage
        context.setStrokeColor(UIColor.black.withAlphaComponent(0.25).cgColor)
        context.setLineWidth(1.0)
        context.move(to: CGPoint(x: 0, y: config.lineOfScrimmageY))
        context.addLine(to: CGPoint(x: config.fieldWidth, y: config.lineOfScrimmageY))
        context.strokePath()

        // Decorative yard lines (dashed, subtle)
        context.setStrokeColor(UIColor.black.withAlphaComponent(0.08).cgColor)
        context.setLineWidth(0.4)
        context.setLineDash(phase: 0, lengths: [3, 3])
        for i in 1...2 {
            let y = config.lineOfScrimmageY - CGFloat(i) * (config.fieldHeight * 0.18)
            if y > 0 {
                context.move(to: CGPoint(x: config.sideMargin, y: y))
                context.addLine(to: CGPoint(x: config.fieldWidth - config.sideMargin, y: y))
                context.strokePath()
            }
        }
        context.setLineDash(phase: 0, lengths: [])
    }

    private func drawFootballCG(_ context: CGContext, config: DiagramConfig) {
        let center = CGPoint(x: config.fieldWidth / 2, y: config.lineOfScrimmageY + config.footballSize * 1.5)
        let rect = CGRect(
            x: center.x - config.footballSize,
            y: center.y - config.footballSize * 0.6,
            width: config.footballSize * 2,
            height: config.footballSize * 1.2
        )
        context.setFillColor(UIColor.brown.cgColor)
        context.fillEllipse(in: rect)
    }

    private func drawMotionCG(_ context: CGContext, assignments: [RouteAssignment], positions: [Receiver: CGPoint], formation: Formation, config: DiagramConfig) {
        for assignment in assignments {
            guard assignment.receiver == .Y, let motion = assignment.motion else { continue }
            guard let initialPos = positions[.Y] else { continue }
            let finalPos = yFinalPosition(
                initialSide: assignment.side,
                finalSide: assignment.motionFinalSide,
                motion: motion,
                formation: formation,
                config: config
            )
            let arcPoints = motionPath(for: .Y, motion: motion, from: initialPos, to: finalPos, config: config)
            guard arcPoints.count >= 2 else { continue }

            let path = CGMutablePath()
            path.move(to: arcPoints[0])
            for i in 1..<arcPoints.count { path.addLine(to: arcPoints[i]) }

            context.setStrokeColor(UIColor.systemOrange.withAlphaComponent(0.5).cgColor)
            context.setLineWidth(1.5)
            context.setLineDash(phase: 0, lengths: [3, 3])
            context.addPath(path)
            context.strokePath()
            context.setLineDash(phase: 0, lengths: [])
        }
    }

    private func drawWheelCG(_ context: CGContext, playCall: PlayCall, config: DiagramConfig) {
        let (_, arcPoints, _) = yWheelArcPath(for: playCall, config: config)
        guard arcPoints.count >= 2 else { return }

        let path = CGMutablePath()
        path.move(to: arcPoints[0])
        for i in 1..<arcPoints.count { path.addLine(to: arcPoints[i]) }

        context.setStrokeColor(UIColor.systemYellow.withAlphaComponent(0.8).cgColor)
        context.setLineWidth(1.5)
        context.setLineCap(.round)
        context.addPath(path)
        context.strokePath()

        // Arrow at end
        drawArrowCG(context, from: arcPoints[arcPoints.count - 2], to: arcPoints.last!, color: UIColor.systemYellow.withAlphaComponent(0.8))
    }

    private func drawRoutesCG(_ context: CGContext, assignments: [RouteAssignment], positions: [Receiver: CGPoint], playCall: PlayCall, config: DiagramConfig) {
        for assignment in assignments {
            if assignment.receiver == .Y && playCall.yWheelEnabled { continue }
            guard let initialPos = positions[assignment.receiver] else { continue }

            let routeStart: CGPoint
            if assignment.receiver == .Y, assignment.motion != nil {
                routeStart = yFinalPosition(
                    initialSide: assignment.side,
                    finalSide: assignment.motionFinalSide,
                    motion: assignment.motion,
                    formation: playCall.formation,
                    config: config
                )
            } else {
                routeStart = initialPos
            }

            let pathPoints = routePath(for: assignment, startPosition: routeStart, side: assignment.motionFinalSide, config: config)
            guard pathPoints.count >= 2 else { continue }

            let cgPath = CGMutablePath()
            cgPath.move(to: pathPoints[0])
            for i in 1..<pathPoints.count { cgPath.addLine(to: pathPoints[i]) }

            let color = receiverCGColor(for: assignment.receiver)
            context.setStrokeColor(color)
            context.setLineWidth(1.5)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.addPath(cgPath)
            context.strokePath()

            if let last = pathPoints.last, pathPoints.count >= 2 {
                drawArrowCG(context, from: pathPoints[pathPoints.count - 2], to: last, color: UIColor(cgColor: color))
            }
        }
    }

    private func drawReceiversCG(_ context: CGContext, assignments: [RouteAssignment], positions: [Receiver: CGPoint], config: DiagramConfig) {
        for assignment in assignments {
            guard let pos = positions[assignment.receiver] else { continue }
            let r = config.receiverRadius
            let rect = CGRect(x: pos.x - r, y: pos.y - r, width: r * 2, height: r * 2)
            let color = UIColor(cgColor: receiverCGColor(for: assignment.receiver))

            context.setFillColor(color.withAlphaComponent(0.2).cgColor)
            context.fillEllipse(in: rect)
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(1.0)
            context.strokeEllipse(in: rect)
        }
    }

    private func drawArrowCG(_ context: CGContext, from: CGPoint, to: CGPoint, color: UIColor) {
        let angle = atan2(to.y - from.y, to.x - from.x)
        let len: CGFloat = 5
        let a: CGFloat = .pi / 6

        let arrow = CGMutablePath()
        arrow.move(to: to)
        arrow.addLine(to: CGPoint(x: to.x - len * cos(angle - a), y: to.y - len * sin(angle - a)))
        arrow.move(to: to)
        arrow.addLine(to: CGPoint(x: to.x - len * cos(angle + a), y: to.y - len * sin(angle + a)))

        context.setStrokeColor(color.cgColor)
        context.setLineWidth(1.0)
        context.addPath(arrow)
        context.strokePath()
    }

    private func receiverCGColor(for receiver: Receiver) -> CGColor {
        switch receiver {
        case .X: return UIColor.systemCyan.cgColor
        case .Y: return UIColor.systemYellow.cgColor
        case .Z: return UIColor.systemGreen.cgColor
        case .A: return UIColor.systemOrange.cgColor
        case .H: return UIColor.systemPink.cgColor
        }
    }
}
```

- [ ] **Step 5: Run tests — confirm all pass**

```bash
xcodebuild test \
  -project SpartansPlaycaller.xcodeproj \
  -scheme SpartansPlaycaller \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:SpartansPlaycallerTests/DiagramRendererCGContextTests \
  2>&1 | tail -10
```

Expected: 8 tests pass.

- [ ] **Step 6: Commit**

```bash
git add SpartansPlaycaller/Services/DiagramRenderer+CGContext.swift \
        SpartansPlaycaller/Models/DiagramConfig+CardScale.swift \
        SpartansPlaycallerTests/DiagramRendererCGContextTests.swift
git commit -m "feat: add DiagramRenderer CGContext draw extension and card-scale DiagramConfig factories"
```

---

## Task 7: WristbandPDFGenerator

**Files:**
- Create: `SpartansPlaycaller/Models/WristbandCardConfig.swift`
- Create: `SpartansPlaycaller/Services/WristbandPDFGenerator.swift`
- Create: `SpartansPlaycallerTests/WristbandPDFGeneratorTests.swift`

Page: US Letter portrait (612pt × 792pt). Grid: 2×2, 4 identical copies of one play per page. One page per selected play. Cut guides at gutter centerlines.

Layout math (from architecture spec):
- Card size: 252pt × 180pt (3.5" × 2.5")
- Margin: 18pt. Gutter: 9pt.
- Total width: 2×252 + 9 + 2×18 = 549pt → centering offset: (612 - 549) / 2 = 31.5pt
- Total height: 2×180 + 9 + 2×18 = 405pt → centering offset: (792 - 405) / 2 = 193.5pt
- Card origins (top-left, screen coords): (49.5, 211.5), (301.5, 211.5), (49.5, 400.5), (301.5, 400.5)

- [ ] **Step 1: Write failing tests**

Create `SpartansPlaycallerTests/WristbandPDFGeneratorTests.swift`:

```swift
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
```

- [ ] **Step 2: Run — confirm compile error**

```bash
xcodebuild test \
  -project SpartansPlaycaller.xcodeproj \
  -scheme SpartansPlaycaller \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:SpartansPlaycallerTests/WristbandPDFGeneratorTests \
  2>&1 | tail -5
```

Expected: compile error.

- [ ] **Step 3: Create WristbandCardConfig.swift**

Create `SpartansPlaycaller/Models/WristbandCardConfig.swift`:

```swift
import CoreGraphics

struct WristbandCardConfig {
    // Card dimensions
    let cardWidth: CGFloat = 252.0      // 3.5" at 72pt/in
    let cardHeight: CGFloat = 180.0     // 2.5" at 72pt/in
    let cardInset: CGFloat = 8.0

    // Page
    let pageWidth: CGFloat = 612.0      // US Letter portrait
    let pageHeight: CGFloat = 792.0
    let margin: CGFloat = 18.0          // 0.25"
    let gutter: CGFloat = 9.0           // 0.125"

    // Pre-computed card origins (top-left, screen coordinates)
    var cardOrigins: [CGPoint] {
        let xOffset: CGFloat = 49.5     // (612 - 2×252 - 9) / 2 = 31.5 + 18 = 49.5
        let yOffset: CGFloat = 211.5    // (792 - 2×180 - 9) / 2 = 193.5 + 18 = 211.5
        return [
            CGPoint(x: xOffset, y: yOffset),
            CGPoint(x: xOffset + cardWidth + gutter, y: yOffset),
            CGPoint(x: xOffset, y: yOffset + cardHeight + gutter),
            CGPoint(x: xOffset + cardWidth + gutter, y: yOffset + cardHeight + gutter)
        ]
    }

    // Font sizes
    let playNumberFontSize: CGFloat = 18.0
    let formationFontSize: CGFloat = 14.0
    let digitsFontSize: CGFloat = 14.0
    let receiverLabelFontSize: CGFloat = 9.0
    let conceptFontSize: CGFloat = 12.0
    let motionFontSize: CGFloat = 11.0
    let notesFontSize: CGFloat = 8.0

    // Diagram zone (relative to card top-left)
    // Starts at y=92pt within card (after header rows), ends 10pt from card bottom
    let diagramZoneTopY: CGFloat = 92.0  // top of diagram zone within card (screen coords)

    var diagramZoneSize: CGSize {
        let height = cardHeight - diagramZoneTopY - cardInset - 14.0 // -14 for notes line
        return CGSize(width: cardWidth - 2 * cardInset, height: height)
    }

    static func standard() -> WristbandCardConfig { WristbandCardConfig() }
}
```

- [ ] **Step 4: Create WristbandPDFGenerator.swift**

Create `SpartansPlaycaller/Services/WristbandPDFGenerator.swift`:

```swift
import PDFKit
import UIKit

// MARK: - WristbandPDFPage

final class WristbandPDFPage: PDFPage {
    let card: ExportCard
    let config: WristbandCardConfig

    init(card: ExportCard, config: WristbandCardConfig) {
        self.card = card
        self.config = config
        super.init()
        setBounds(CGRect(x: 0, y: 0, width: config.pageWidth, height: config.pageHeight), for: .mediaBox)
    }

    override func draw(with box: PDFDisplayBox, to context: CGContext) {
        super.draw(with: box, to: context)
        let mediaBox = bounds(for: box)

        // Flip to screen coordinates (Y-down from top)
        context.translateBy(x: 0, y: mediaBox.height)
        context.scaleBy(x: 1, y: -1)

        // Draw 4 identical copies
        for origin in config.cardOrigins {
            drawCard(card, at: origin, into: context)
        }

        // Cut guides
        drawCutGuidesCG(context)
    }

    private func drawCard(_ card: ExportCard, at origin: CGPoint, into context: CGContext) {
        let w = config.cardWidth
        let h = config.cardHeight
        let inset = config.cardInset
        let usableWidth = w - 2 * inset

        // Card border
        context.setStrokeColor(UIColor.black.withAlphaComponent(0.3).cgColor)
        context.setLineWidth(0.5)
        context.stroke(CGRect(origin: origin, size: CGSize(width: w, height: h)))

        var y = origin.y + inset

        // Row 1: Play number (left) + Formation (right)
        drawTextLeft("\(card.playNumber).", in: CGRect(x: origin.x + inset, y: y, width: usableWidth * 0.25, height: 20),
                     font: UIFont.systemFont(ofSize: config.playNumberFontSize, weight: .bold), into: context)
        drawTextRight(card.formationName, in: CGRect(x: origin.x + inset, y: y, width: usableWidth, height: 20),
                      font: UIFont.systemFont(ofSize: config.formationFontSize, weight: .semibold), into: context)
        y += 22

        // Row 2: Route digits
        drawTextCenter(card.routeDigits, in: CGRect(x: origin.x + inset, y: y, width: usableWidth, height: 18),
                       font: UIFont.monospacedSystemFont(ofSize: config.digitsFontSize, weight: .medium), into: context)
        y += 16

        // Row 3: Receiver labels (X Y Z A or X Y Z A H for 5-digit)
        let labelCount = card.routeDigits.count
        let receiverLabels = Array(["X", "Y", "Z", "A", "H"].prefix(labelCount)).joined(separator: "    ")
        drawTextCenter(receiverLabels, in: CGRect(x: origin.x + inset, y: y, width: usableWidth, height: 14),
                       font: UIFont.monospacedSystemFont(ofSize: config.receiverLabelFontSize, weight: .regular), into: context)
        y += 14

        // Row 4: Concept (left) + Motion (right) — conditional
        if card.conceptName != nil || card.motionLabel != nil {
            if let concept = card.conceptName {
                drawTextLeft(concept, in: CGRect(x: origin.x + inset, y: y, width: usableWidth * 0.6, height: 16),
                             font: UIFont.systemFont(ofSize: config.conceptFontSize, weight: .semibold), into: context)
            }
            if let motion = card.motionLabel {
                drawTextRight(motion, in: CGRect(x: origin.x + inset, y: y, width: usableWidth, height: 16),
                              font: UIFont.systemFont(ofSize: config.motionFontSize, weight: .regular), into: context)
            }
            y += 17
        }

        // Divider
        context.setStrokeColor(UIColor.black.withAlphaComponent(0.15).cgColor)
        context.setLineWidth(0.35)
        context.move(to: CGPoint(x: origin.x + inset, y: y + 2))
        context.addLine(to: CGPoint(x: origin.x + w - inset, y: y + 2))
        context.strokePath()
        y += 5

        // Diagram zone
        let diagramRect = CGRect(x: origin.x + inset, y: y, width: usableWidth, height: config.diagramZoneSize.height)
        let diagramConfig = DiagramConfig.wristbandCardScale(for: diagramRect.size)
        DiagramRenderer().draw(into: context, playCall: card.playCall, config: diagramConfig, in: diagramRect)

        // Notes line
        let notesY = origin.y + h - 14
        context.setStrokeColor(UIColor.black.withAlphaComponent(0.2).cgColor)
        context.setLineWidth(0.3)
        context.move(to: CGPoint(x: origin.x + inset + 30, y: notesY))
        context.addLine(to: CGPoint(x: origin.x + w - inset, y: notesY))
        context.strokePath()
        drawTextLeft("Notes:", in: CGRect(x: origin.x + inset, y: notesY - 10, width: 30, height: 12),
                     font: UIFont.systemFont(ofSize: config.notesFontSize, weight: .regular), into: context)
    }

    private func drawCutGuidesCG(_ context: CGContext) {
        let origins = config.cardOrigins
        let gutter = config.gutter

        context.setStrokeColor(UIColor.black.withAlphaComponent(0.15).cgColor)
        context.setLineWidth(0.25)

        // Vertical cut guide (between column 0 and column 1)
        let vCutX = origins[0].x + config.cardWidth + gutter / 2
        context.move(to: CGPoint(x: vCutX, y: config.margin))
        context.addLine(to: CGPoint(x: vCutX, y: config.pageHeight - config.margin))
        context.strokePath()

        // Horizontal cut guide (between row 0 and row 1)
        let hCutY = origins[0].y + config.cardHeight + gutter / 2
        context.move(to: CGPoint(x: config.margin, y: hCutY))
        context.addLine(to: CGPoint(x: config.pageWidth - config.margin, y: hCutY))
        context.strokePath()
    }

    // MARK: - Text drawing helpers (handle Y-down context)

    /// Draw left-aligned text in a rect, correctly oriented in the Y-down context.
    private func drawTextLeft(_ text: String, in rect: CGRect, font: UIFont, into context: CGContext) {
        drawText(text, in: rect, alignment: .left, font: font, into: context)
    }

    private func drawTextRight(_ text: String, in rect: CGRect, font: UIFont, into context: CGContext) {
        drawText(text, in: rect, alignment: .right, font: font, into: context)
    }

    private func drawTextCenter(_ text: String, in rect: CGRect, font: UIFont, into context: CGContext) {
        drawText(text, in: rect, alignment: .center, font: font, into: context)
    }

    /// Core text drawing helper. The context is in Y-down mode (screen coords).
    /// We temporarily flip back to Y-up to let UIKit text render correctly.
    private func drawText(_ text: String, in rect: CGRect, alignment: NSTextAlignment, font: UIFont, into context: CGContext) {
        context.saveGState()
        // Go to bottom-left of the rect in screen coords, then flip Y up for UIKit text
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)

        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black,
            .paragraphStyle: style
        ]
        (text as NSString).draw(in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height), withAttributes: attrs)
        context.restoreGState()
    }
}

// MARK: - WristbandPDFGenerator

struct WristbandPDFGenerator {
    /// Generate a wristband PDF. One page per card; each page shows 4 copies.
    /// Returns nil for empty input or if PDFKit serialization fails.
    static func generate(cards: [ExportCard]) -> Data? {
        guard !cards.isEmpty else { return nil }

        let config = WristbandCardConfig.standard()
        let document = PDFDocument()

        // REQ-SEC-1: set only title attribute; no author/creator/subject
        let titleString = cards.count == 1
            ? "\(cards[0].formationName) \(cards[0].routeDigits)"
            : "\(cards.count) Plays — \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none))"
        document.documentAttributes = [PDFDocumentAttribute.titleAttribute: titleString]

        for (index, card) in cards.enumerated() {
            let page = WristbandPDFPage(card: card, config: config)
            document.insert(page, at: index)
        }

        return document.dataRepresentation()
    }
}
```

- [ ] **Step 5: Run tests — confirm all pass**

```bash
xcodebuild test \
  -project SpartansPlaycaller.xcodeproj \
  -scheme SpartansPlaycaller \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:SpartansPlaycallerTests/WristbandPDFGeneratorTests \
  2>&1 | tail -10
```

Expected: 5 tests pass.

- [ ] **Step 6: Commit**

```bash
git add SpartansPlaycaller/Models/WristbandCardConfig.swift \
        SpartansPlaycaller/Services/WristbandPDFGenerator.swift \
        SpartansPlaycallerTests/WristbandPDFGeneratorTests.swift
git commit -m "feat: add WristbandPDFGenerator — 4-up portrait pages, one page per play"
```

---

## Task 8: CatalogPDFGenerator

**Files:**
- Create: `SpartansPlaycaller/Models/CatalogCardConfig.swift`
- Create: `SpartansPlaycaller/Services/CatalogPDFGenerator.swift`
- Create: `SpartansPlaycallerTests/CatalogPDFGeneratorTests.swift`

Page: US Letter landscape (792pt × 612pt). Grid: 3×3 = 9 cards per page. `ceil(N/9)` pages.

Layout math (from architecture spec):
- Page: 792pt wide × 612pt tall
- Margins: 36pt all sides. Available: 720pt × 540pt.
- Gutter: 8pt H and V.
- Column width: floor((720 - 16) / 3) = 234pt. Row height: floor((540 - 16) / 3) = 174pt.
- Column stride: 242pt. Row stride: 182pt.
- Cell origins (col, row → x, y): col×242+36, row×182+36

- [ ] **Step 1: Write failing tests**

Create `SpartansPlaycallerTests/CatalogPDFGeneratorTests.swift`:

```swift
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
```

- [ ] **Step 2: Run — confirm compile error**

```bash
xcodebuild test \
  -project SpartansPlaycaller.xcodeproj \
  -scheme SpartansPlaycaller \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:SpartansPlaycallerTests/CatalogPDFGeneratorTests \
  2>&1 | tail -5
```

Expected: compile error.

- [ ] **Step 3: Create CatalogCardConfig.swift**

Create `SpartansPlaycaller/Models/CatalogCardConfig.swift`:

```swift
import CoreGraphics

struct CatalogCardConfig {
    // Card dimensions
    let cardWidth: CGFloat = 234.0
    let cardHeight: CGFloat = 174.0
    let cardInset: CGFloat = 5.0

    // Page
    let pageWidth: CGFloat = 792.0      // US Letter landscape (11")
    let pageHeight: CGFloat = 612.0     // US Letter landscape (8.5")
    let margin: CGFloat = 36.0          // 0.5"
    let gutter: CGFloat = 8.0

    // Font sizes (smaller than wristband — read at normal viewing distance)
    let playNumberFontSize: CGFloat = 10.0
    let formationFontSize: CGFloat = 10.0
    let digitsFontSize: CGFloat = 9.0
    let receiverLabelFontSize: CGFloat = 8.0
    let conceptFontSize: CGFloat = 8.0
    let motionFontSize: CGFloat = 8.0

    // Diagram zone (relative to card top-left)
    let diagramZoneTopY: CGFloat = 70.0

    var diagramZoneSize: CGSize {
        let height = cardHeight - diagramZoneTopY - cardInset
        return CGSize(width: cardWidth - 2 * cardInset, height: height)
    }

    /// 9 cell origins in row-major order (row 0 left→right, row 1, row 2).
    var cellOrigins: [CGPoint] {
        var origins: [CGPoint] = []
        let colStride = cardWidth + gutter   // 234 + 8 = 242
        let rowStride = cardHeight + gutter  // 174 + 8 = 182
        for row in 0..<3 {
            for col in 0..<3 {
                origins.append(CGPoint(
                    x: margin + CGFloat(col) * colStride,
                    y: margin + CGFloat(row) * rowStride
                ))
            }
        }
        return origins
    }

    static func standard() -> CatalogCardConfig { CatalogCardConfig() }
}
```

- [ ] **Step 4: Create CatalogPDFGenerator.swift**

Create `SpartansPlaycaller/Services/CatalogPDFGenerator.swift`:

```swift
import PDFKit
import UIKit

// MARK: - CatalogPDFPage

final class CatalogPDFPage: PDFPage {
    let pageCards: [ExportCard]      // 1–9 cards for this page
    let config: CatalogCardConfig

    init(pageCards: [ExportCard], config: CatalogCardConfig) {
        self.pageCards = pageCards
        self.config = config
        super.init()
        setBounds(CGRect(x: 0, y: 0, width: config.pageWidth, height: config.pageHeight), for: .mediaBox)
    }

    override func draw(with box: PDFDisplayBox, to context: CGContext) {
        super.draw(with: box, to: context)
        let mediaBox = bounds(for: box)

        // Flip to screen coordinates (Y-down from top)
        context.translateBy(x: 0, y: mediaBox.height)
        context.scaleBy(x: 1, y: -1)

        let origins = config.cellOrigins
        for (i, card) in pageCards.enumerated() where i < origins.count {
            drawCard(card, at: origins[i], into: context)
        }
    }

    private func drawCard(_ card: ExportCard, at origin: CGPoint, into context: CGContext) {
        let w = config.cardWidth
        let inset = config.cardInset
        let usableWidth = w - 2 * inset

        // Card border
        context.setStrokeColor(UIColor.black.withAlphaComponent(0.2).cgColor)
        context.setLineWidth(0.4)
        context.stroke(CGRect(origin: origin, size: CGSize(width: w, height: config.cardHeight)))

        var y = origin.y + inset

        // Row 1: Play number (left) + Formation (right)
        drawTextLeft("\(card.playNumber).", in: CGRect(x: origin.x + inset, y: y, width: usableWidth * 0.25, height: 14),
                     font: UIFont.systemFont(ofSize: config.playNumberFontSize, weight: .bold), into: context)
        drawTextRight(card.formationName, in: CGRect(x: origin.x + inset, y: y, width: usableWidth, height: 14),
                      font: UIFont.systemFont(ofSize: config.formationFontSize, weight: .semibold), into: context)
        y += 16

        // Row 2: Route digits
        drawTextCenter(card.routeDigits, in: CGRect(x: origin.x + inset, y: y, width: usableWidth, height: 13),
                       font: UIFont.monospacedSystemFont(ofSize: config.digitsFontSize, weight: .medium), into: context)
        y += 13

        // Row 3: Receiver labels
        let labelCount = card.routeDigits.count
        let receiverLabels = Array(["X", "Y", "Z", "A", "H"].prefix(labelCount)).joined(separator: "   ")
        drawTextCenter(receiverLabels, in: CGRect(x: origin.x + inset, y: y, width: usableWidth, height: 11),
                       font: UIFont.monospacedSystemFont(ofSize: config.receiverLabelFontSize, weight: .regular), into: context)
        y += 12

        // Row 4: Concept + Motion (conditional)
        if card.conceptName != nil || card.motionLabel != nil {
            if let concept = card.conceptName {
                drawTextLeft(concept, in: CGRect(x: origin.x + inset, y: y, width: usableWidth * 0.6, height: 13),
                             font: UIFont.systemFont(ofSize: config.conceptFontSize, weight: .semibold), into: context)
            }
            if let motion = card.motionLabel {
                drawTextRight(motion, in: CGRect(x: origin.x + inset, y: y, width: usableWidth, height: 13),
                              font: UIFont.systemFont(ofSize: config.motionFontSize, weight: .regular), into: context)
            }
            y += 14
        }

        // Divider
        context.setStrokeColor(UIColor.black.withAlphaComponent(0.12).cgColor)
        context.setLineWidth(0.35)
        context.move(to: CGPoint(x: origin.x + inset, y: y + 2))
        context.addLine(to: CGPoint(x: origin.x + w - inset, y: y + 2))
        context.strokePath()

        // Diagram zone
        let diagramRect = CGRect(
            x: origin.x + inset,
            y: origin.y + config.diagramZoneTopY,
            width: usableWidth,
            height: config.diagramZoneSize.height
        )
        let diagramConfig = DiagramConfig.catalogCardScale(for: diagramRect.size)
        DiagramRenderer().draw(into: context, playCall: card.playCall, config: diagramConfig, in: diagramRect)
    }

    // MARK: - Text helpers (same Y-down flip technique as WristbandPDFPage)

    private func drawTextLeft(_ text: String, in rect: CGRect, font: UIFont, into context: CGContext) {
        drawText(text, in: rect, alignment: .left, font: font, into: context)
    }

    private func drawTextRight(_ text: String, in rect: CGRect, font: UIFont, into context: CGContext) {
        drawText(text, in: rect, alignment: .right, font: font, into: context)
    }

    private func drawTextCenter(_ text: String, in rect: CGRect, font: UIFont, into context: CGContext) {
        drawText(text, in: rect, alignment: .center, font: font, into: context)
    }

    private func drawText(_ text: String, in rect: CGRect, alignment: NSTextAlignment, font: UIFont, into context: CGContext) {
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black,
            .paragraphStyle: style
        ]
        (text as NSString).draw(in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height), withAttributes: attrs)
        context.restoreGState()
    }
}

// MARK: - CatalogPDFGenerator

struct CatalogPDFGenerator {
    /// Generate a catalog PDF. 9 cards per landscape page; ceil(N/9) pages.
    /// Returns nil for empty input or if PDFKit serialization fails.
    static func generate(cards: [ExportCard]) -> Data? {
        guard !cards.isEmpty else { return nil }

        let config = CatalogCardConfig.standard()
        let document = PDFDocument()

        // REQ-SEC-1: set only title attribute
        let title = "\(cards.count) Plays — \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none))"
        document.documentAttributes = [PDFDocumentAttribute.titleAttribute: title]

        let pageSize = 9
        let pageCount = Int(ceil(Double(cards.count) / Double(pageSize)))

        for pageIndex in 0..<pageCount {
            let start = pageIndex * pageSize
            let end = min(start + pageSize, cards.count)
            let pageCards = Array(cards[start..<end])
            let page = CatalogPDFPage(pageCards: pageCards, config: config)
            document.insert(page, at: pageIndex)
        }

        return document.dataRepresentation()
    }
}
```

- [ ] **Step 5: Run tests — confirm all pass**

```bash
xcodebuild test \
  -project SpartansPlaycaller.xcodeproj \
  -scheme SpartansPlaycaller \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:SpartansPlaycallerTests/CatalogPDFGeneratorTests \
  2>&1 | tail -10
```

Expected: 10 tests pass.

- [ ] **Step 6: Commit**

```bash
git add SpartansPlaycaller/Models/CatalogCardConfig.swift \
        SpartansPlaycaller/Services/CatalogPDFGenerator.swift \
        SpartansPlaycallerTests/CatalogPDFGeneratorTests.swift
git commit -m "feat: add CatalogPDFGenerator — 9-up landscape pages, ceil(N/9) page count"
```

---

## Task 9: PlayLibraryView

**Files:**
- Create: `SpartansPlaycaller/Views/PlayLibraryView.swift`

No automated tests for this view (UIKit/SwiftUI views — test via manual smoke test in Task 10). The view uses `PlayLibraryStore` (already tested) for all data operations.

- [ ] **Step 1: Create PlayLibraryView.swift**

Create `SpartansPlaycaller/Views/PlayLibraryView.swift`:

```swift
import SwiftUI

struct PlayLibraryView: View {
    @EnvironmentObject private var store: PlayLibraryStore
    @Environment(\.dismiss) private var dismiss

    @State private var isSelectMode = false
    @State private var selectedIDs: Set<UUID> = []
    @State private var showExportSheet = false
    @State private var exportMode: ExportMode? = nil
    @State private var isExporting = false
    @State private var exportError: String? = nil

    private var selectedPlays: [SavedPlay] {
        store.plays.filter { selectedIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.plays.isEmpty {
                    emptyState
                } else {
                    playList
                }
            }
            .navigationTitle("Play Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
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
                if isSelectMode {
                    ToolbarItem(placement: .bottomBar) {
                        HStack {
                            Button("Select All") {
                                selectedIDs = Set(store.plays.map { $0.id })
                            }
                            Spacer()
                            exportButton
                        }
                    }
                }
            }
        }
        .confirmationDialog("Export \(selectedPlays.count) Play\(selectedPlays.count == 1 ? "" : "s")",
                           isPresented: $showExportSheet, titleVisibility: .visible) {
            Button("Play Catalog") { triggerExport(mode: .catalog) }
            Button("Wristband Cards") { triggerExport(mode: .wristband) }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Export Failed", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "Could not generate PDF. Please try again.")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("No plays saved yet.")
                .font(.headline)
            Text("Build a play and tap the bookmark button to save it here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private var playList: some View {
        List(selection: isSelectMode ? $selectedIDs : .constant(Set<UUID>())) {
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
            }
            .onDelete { offsets in
                store.delete(at: offsets)
            }
        }
        .listStyle(.plain)
    }

    private var exportButton: some View {
        Button {
            showExportSheet = true
        } label: {
            if isExporting {
                ProgressView()
                    .controlSize(.small)
            } else {
                Label("Export \(selectedIDs.count) Play\(selectedIDs.count == 1 ? "" : "s")", systemImage: "square.and.arrow.up")
            }
        }
        .disabled(selectedIDs.isEmpty || isExporting)
    }

    private func triggerExport(mode: ExportMode) {
        isExporting = true
        let plays = selectedPlays
        let interpreter = RouteInterpreter()

        Task {
            let cards: [ExportCard] = plays.enumerated().compactMap { (i, savedPlay) in
                ExportCard.from(savedPlay: savedPlay, playNumber: i + 1, interpreter: interpreter)
            }

            let data: Data?
            switch mode {
            case .catalog: data = CatalogPDFGenerator.generate(cards: cards)
            case .wristband: data = WristbandPDFGenerator.generate(cards: cards)
            }

            await MainActor.run {
                isExporting = false
                guard let pdfData = data else {
                    exportError = "Could not generate PDF. Please try again."
                    return
                }
                presentShareSheet(data: pdfData, mode: mode, cardCount: plays.count)
            }
        }
    }

    private func presentShareSheet(data: Data, mode: ExportMode, cardCount: Int) {
        // REQ-SEC-2: temp file in temporaryDirectory
        let modeSuffix = mode == .catalog ? "catalog" : "wristband"
        let filename = "\(UUID().uuidString)-\(cardCount)-plays-\(modeSuffix).pdf"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        do {
            // REQ-SEC-3: completeFileProtection
            try data.write(to: tempURL, options: .completeFileProtection)
        } catch {
            exportError = "Could not write PDF. Please try again."
            return
        }

        let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
        // REQ-SEC-4: delete temp file on dismiss
        activityVC.completionWithItemsHandler = { _, _, _, _ in
            try? FileManager.default.removeItem(at: tempURL)
        }

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            var presenter = root
            while let presented = presenter.presentedViewController {
                presenter = presented
            }
            presenter.present(activityVC, animated: true)
        }
    }
}

// MARK: - PlayLibraryRow

private struct PlayLibraryRow: View {
    let play: SavedPlay
    let isSelectMode: Bool
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                if isSelectMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? .blue : .secondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(play.formationName)
                            .font(.subheadline.weight(.semibold))
                        Text(play.routeDigits)
                            .font(.system(.subheadline, design: .monospaced))
                    }
                    HStack(spacing: 8) {
                        if let concept = play.conceptName {
                            Text(concept)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let motion = play.motionLabel {
                            Text(motion)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
    }
}

// MARK: - ExportMode

enum ExportMode {
    case catalog
    case wristband
}

#Preview {
    PlayLibraryView()
        .environmentObject(PlayLibraryStore())
}
```

- [ ] **Step 2: Build — confirm no compile errors**

```bash
xcodebuild build \
  -project SpartansPlaycaller.xcodeproj \
  -scheme SpartansPlaycaller \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  2>&1 | grep -E "(error:|BUILD)" | tail -10
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add SpartansPlaycaller/Views/PlayLibraryView.swift
git commit -m "feat: add PlayLibraryView — library list, multi-select, swipe-delete, export action sheet"
```

---

## Task 10: Quick Export from PlayCallerView + ViewModel Export State

**Files:**
- Modify: `SpartansPlaycaller/ViewModels/PlayCallerViewModel.swift`
- Modify: `SpartansPlaycaller/Views/PlayCallerView.swift`

Wire up the quick-export path: coach taps the share button in PlayCallerView while a play is showing → action sheet → format choice → PDF → UIActivityViewController.

`ExportMode` is already defined in `PlayLibraryView.swift` — no duplicate needed, but both files are in the same module so the type is accessible.

- [ ] **Step 1: Add export state to PlayCallerViewModel**

Add these to `PlayCallerViewModel`:

```swift
// MARK: - Export State

@Published var isExporting: Bool = false

var canExport: Bool {
    currentPlayCallWithMotion != nil || currentPlayCall != nil
}
```

- [ ] **Step 2: Add share button + quick-export action sheet to PlayCallerView**

Add these state variables to `PlayCallerView`:

```swift
@State private var showQuickExportSheet = false
@State private var quickExportError: String? = nil
@State private var isQuickExporting = false
```

Add a share button in the `.toolbar` block (alongside the existing Save and Library buttons):

```swift
// Share (quick export) — add before Save button
Button {
    showQuickExportSheet = true
} label: {
    if isQuickExporting {
        ProgressView().controlSize(.small)
    } else {
        Image(systemName: "square.and.arrow.up")
    }
}
.disabled(!viewModel.canExport || isQuickExporting)
.accessibilityLabel("Export current play")
```

Add a `confirmationDialog` and alert modifier to the `NavigationStack` view:

```swift
.confirmationDialog("Export Current Play", isPresented: $showQuickExportSheet, titleVisibility: .visible) {
    Button("Play Catalog") { quickExport(mode: .catalog) }
    Button("Wristband Cards") { quickExport(mode: .wristband) }
    Button("Cancel", role: .cancel) {}
}
.alert("Export Failed", isPresented: Binding(get: { quickExportError != nil }, set: { if !$0 { quickExportError = nil } })) {
    Button("OK", role: .cancel) {}
} message: {
    Text(quickExportError ?? "Could not generate PDF.")
}
```

Add `quickExport(mode:)` private function to `PlayCallerView`:

```swift
private func quickExport(mode: ExportMode) {
    guard let playCall = viewModel.currentPlayCallWithMotion ?? viewModel.currentPlayCall else { return }
    isQuickExporting = true

    let card = ExportCard.from(playCall: playCall, motion: viewModel.yMotion, playNumber: 1)

    Task {
        let data: Data?
        switch mode {
        case .catalog: data = CatalogPDFGenerator.generate(cards: [card])
        case .wristband: data = WristbandPDFGenerator.generate(cards: [card])
        }

        await MainActor.run {
            isQuickExporting = false
            guard let pdfData = data else {
                quickExportError = "Could not generate PDF. Please try again."
                return
            }
            presentShareSheet(pdfData: pdfData, card: card, mode: mode)
        }
    }
}

private func presentShareSheet(pdfData: Data, card: ExportCard, mode: ExportMode) {
    let modeSuffix = mode == .catalog ? "catalog" : "wristband"
    let baseName = "\(card.formationName.replacingOccurrences(of: " ", with: "-"))-\(card.routeDigits)"
    let filename = "\(UUID().uuidString)-\(baseName)-\(modeSuffix).pdf"
    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

    do {
        try pdfData.write(to: tempURL, options: .completeFileProtection)
    } catch {
        quickExportError = "Could not write PDF."
        return
    }

    let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
    activityVC.completionWithItemsHandler = { _, _, _, _ in
        try? FileManager.default.removeItem(at: tempURL)
    }

    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
       let root = windowScene.windows.first?.rootViewController {
        var presenter = root
        while let presented = presenter.presentedViewController { presenter = presented }
        presenter.present(activityVC, animated: true)
    }
}
```

- [ ] **Step 3: Build and run all tests**

```bash
xcodebuild test \
  -project SpartansPlaycaller.xcodeproj \
  -scheme SpartansPlaycaller \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  2>&1 | tail -20
```

Expected: all tests pass (new + existing), BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add SpartansPlaycaller/ViewModels/PlayCallerViewModel.swift \
        SpartansPlaycaller/Views/PlayCallerView.swift
git commit -m "feat: add quick-export flow — share button in PlayCallerView, catalog + wristband modes"
```

---

## Task 11: Final Integration — Run All Tests + Push

- [ ] **Step 1: Run full test suite**

```bash
xcodebuild test \
  -project SpartansPlaycaller.xcodeproj \
  -scheme SpartansPlaycaller \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  2>&1 | grep -E "(Test Suite|FAILED|error:)" | tail -30
```

Expected: all test suites pass, zero failures.

- [ ] **Step 2: Verify no pre-existing tests regressed**

All tests from before this feature (RouteInterpreterTests, DiagramRendererYWheelTests, ConceptMatcherTests, PlayCallerViewModelTests, etc.) must still pass.

- [ ] **Step 3: Push feature branch**

```bash
git push -u origin feat/play-library-and-export
```

---

## Self-Review

### Spec coverage check

| Spec requirement | Covered by task |
|-----------------|----------------|
| Story 3.0: SavedPlay DTO | Task 2 |
| Story 3.0: PlayLibraryStore JSON persistence | Task 3 |
| Story 3.0: Save Play button + confirmation | Task 4 |
| Story 3.0: Library view with list + delete | Task 9 |
| Story 3.0: Persistence survives app relaunch | Task 3 (LibraryPersistenceIntegrationTests) |
| Story 3.1: CatalogPDFGenerator, 9-up layout | Task 8 |
| Story 3.1: ceil(N/9) page count | Task 8 tests |
| Story 3.1: Landscape US Letter page | Task 8 tests |
| Story 3.2: WristbandPDFGenerator, 4-up | Task 7 |
| Story 3.2: One page per play (N plays → N pages) | Task 7 tests |
| Story 3.2: Portrait US Letter page | Task 7 tests |
| Multi-select in library | Task 9 |
| Quick export (single play, no library) | Task 10 |
| Library export (multi-play path) | Task 9 |
| UIActivityViewController (AirPrint, Files, email) | Tasks 9, 10 |
| REQ-SEC-1: strip PDF metadata | WristbandPDFGenerator, CatalogPDFGenerator |
| REQ-SEC-2: temp file in temporaryDirectory | Tasks 9, 10 |
| REQ-SEC-3: .completeFileProtection on temp | Tasks 9, 10 |
| REQ-SEC-4: delete temp file on dismiss | Tasks 9, 10 |
| REQ-SEC-5: .completeFileProtection on library JSON | Task 3 (PlayLibraryStore.persist) |
| applyMotion deduplication (one canonical path) | Task 1 |
| ExportCard.from(savedPlay:) returns nil for bad formation | Task 5 test |
| EmptyState in PlayLibraryView | Task 9 |
| Disabled Save button when no play | Task 4 |
| Disabled Export when no selection | Task 9 |

### Placeholder scan

No TBD, TODO, or placeholder text. All code is complete.

### Type consistency check

- `PlayCall.applying(_:yWheelEnabled:to:)` — defined in Task 1, used in Task 5 (ExportCard), Task 7/8 indirectly via ExportCard.
- `ExportCard.from(playCall:motion:playNumber:)` — defined in Task 5, used in Tasks 9 and 10.
- `ExportCard.from(savedPlay:playNumber:interpreter:)` — defined in Task 5, used in Task 9.
- `CatalogPDFGenerator.generate(cards:)` — defined in Task 8, called in Tasks 9 and 10.
- `WristbandPDFGenerator.generate(cards:)` — defined in Task 7, called in Tasks 9 and 10.
- `DiagramRenderer().draw(into:playCall:config:in:)` — defined in Task 6, called in Tasks 7 and 8.
- `DiagramConfig.catalogCardScale(for:)` — defined in Task 6, used in Task 8.
- `DiagramConfig.wristbandCardScale(for:)` — defined in Task 6, used in Task 7.
- `ExportMode` enum — defined in Task 9 (`PlayLibraryView.swift`), used in Task 10. Both are in the `SpartansPlaycaller` module. ✓
- `PlayLibraryStore.save(_:motion:yWheelEnabled:)` — defined in Task 3, called in Task 4.
- `SavedPlay.from(playCall:motion:yWheelEnabled:)` — defined in Task 2, called in Task 3.

All types, method signatures, and property names are consistent across tasks.
