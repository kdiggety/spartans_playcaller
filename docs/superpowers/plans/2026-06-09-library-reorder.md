# Play Library Reorder — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add drag-to-reorder to the Play Library so coaches can arrange plays in a custom order that persists across sessions, with in-memory buffering and a Cancel/Done commit model.

**Architecture:** Three new methods on `PlayLibraryStore` handle the reorder path: `move()` mutates in memory only, `commitReorder()` persists once on Done, and `cancelReorder(snapshot:)` restores the pre-session order without writing. `PlayLibraryView` holds a `preSessionOrder` snapshot and manages `editMode` explicitly via `@State` + `.environment`. The existing "Select" mode becomes "Edit" mode exposing both checkboxes and drag handles simultaneously.

**Tech Stack:** Swift 5.9+, SwiftUI, XCTest, no new dependencies.

---

## Branch

All work happens on `feat/library-reorder`. Create this branch from `main` before beginning.

```bash
git checkout main && git pull
git checkout -b feat/library-reorder
```

---

## Task 1 — Store: `move()`, `commitReorder()`, `cancelReorder(snapshot:)`

**Files modified:**
- `SpartansPlaycaller/Services/PlayLibraryStore.swift` — add three methods
- `SpartansPlaycallerTests/PlayLibraryStoreTests.swift` — add six new unit tests

**No new files. No pbxproj changes.**

### Step 1.1 — Write failing tests first

Add the following six tests to the bottom of the `PlayLibraryStoreTests` class (inside the existing `@MainActor final class PlayLibraryStoreTests: XCTestCase` block, before the closing `}`).

These tests will fail to compile until Step 1.2 adds the store methods. That is intentional — TDD.

```swift
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
    // Move index 0 (A) to the end. Swift Array.move semantics: toOffset=3 appends after last.
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

    // Capture on-disk order before the move
    let dataBefore = try Data(contentsOf: tempURL)
    let playsBefore = try JSONDecoder().decode([SavedPlay].self, from: dataBefore)
    let orderBefore = playsBefore.map { $0.routeDigits }

    // Move A to the end
    store.move(fromOffsets: IndexSet([0]), toOffset: 3)

    // Re-read the file — must NOT have changed
    let dataAfter = try Data(contentsOf: tempURL)
    let playsAfter = try JSONDecoder().decode([SavedPlay].self, from: dataAfter)
    let orderAfter = playsAfter.map { $0.routeDigits }

    XCTAssertEqual(orderBefore, orderAfter,
        "move() must not write to disk; on-disk order must be unchanged")
    // Confirm in-memory state DID change (otherwise the test is vacuous)
    XCTAssertNotEqual(store.plays.map { $0.routeDigits }, orderBefore,
        "move() must update the in-memory plays array")
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

    // Move A to the end, then commit
    store.move(fromOffsets: IndexSet([0]), toOffset: 3)
    store.commitReorder()

    // Verify file was written with the new order
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

    // Capture snapshot at "mode entry" time — value copy
    let snapshot = store.plays

    // Move A to the end
    store.move(fromOffsets: IndexSet([0]), toOffset: 3)
    XCTAssertEqual(store.plays[0].routeDigits, "2943", "Precondition: A moved out of position 0")

    // Cancel — restore snapshot
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

    // Read raw bytes before the session
    let dataBefore = try Data(contentsOf: tempURL)

    // Session: snapshot → move → cancel
    let snapshot = store.plays
    store.move(fromOffsets: IndexSet([0]), toOffset: 3)
    store.cancelReorder(snapshot: snapshot)

    // Read raw bytes after cancel — must be identical
    let dataAfter = try Data(contentsOf: tempURL)
    XCTAssertEqual(dataBefore, dataAfter,
        "cancelReorder must not write to disk; raw file bytes must be identical")
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

    // Moving index 1 to offset 1 (same effective position) is a no-op in Array.move semantics.
    // Swift treats toOffset as the insertion point; moving index 1 to offset 2 is also a no-op
    // (insert before index 2 means same position). We use offset 1 here.
    store.move(fromOffsets: IndexSet([1]), toOffset: 1)

    XCTAssertEqual(store.plays.map { $0.id }, idsBefore,
        "Moving to the same position must not alter the array")
}
```

**Build verification after tests are added (will show compile errors — expected):**
```bash
xcodebuild build -project SpartansPlaycaller.xcodeproj -scheme SpartansPlaycaller -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD"
```

### Step 1.2 — Implement the three store methods

Add the following three methods to `SpartansPlaycaller/Services/PlayLibraryStore.swift`, after the `update(_:)` method and before the `private func load()` line:

```swift
// MARK: - Reorder

func move(fromOffsets offsets: IndexSet, toOffset destination: Int) {
    plays.move(fromOffsets: offsets, toOffset: destination)
    // NOTE: No persist() call here — deferred to commitReorder().
    // This is intentional: the in-memory array reflects the current drag state;
    // the on-disk file is only updated when the user taps Done (AC-1.3).
}

func commitReorder() {
    do { try persist() } catch { print("[PlayLibraryStore] commitReorder persist failed: \(error)") }
}

func cancelReorder(snapshot: [SavedPlay]) {
    guard !snapshot.isEmpty || plays.isEmpty else {
        assertionFailure("[PlayLibraryStore] cancelReorder called with empty snapshot but plays is non-empty — snapshot not initialized on mode entry")
        return
    }
    plays = snapshot
    // NOTE: No persist() call here — snapshot restore must never write to disk (AC-2.3).
}
```

**Build and run tests:**
```bash
xcodebuild build -project SpartansPlaycaller.xcodeproj -scheme SpartansPlaycaller -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD"
xcodebuild test -project SpartansPlaycaller.xcodeproj -scheme SpartansPlaycaller -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -30
```

All six new tests must pass. All pre-existing tests must remain green.

### Step 1.3 — Commit

```bash
git add SpartansPlaycaller/Services/PlayLibraryStore.swift
git add SpartansPlaycallerTests/PlayLibraryStoreTests.swift
git commit -m "feat: PlayLibraryStore move/commitReorder/cancelReorder with TDD unit tests

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

- [ ] Tests written (Step 1.1)
- [ ] Store methods implemented (Step 1.2)
- [ ] Build passes, all tests green (Step 1.2)
- [ ] Committed (Step 1.3)

---

## Task 2 — Integration Tests: Persistence Round-Trips

**Files modified:**
- `SpartansPlaycallerTests/LibraryPersistenceIntegrationTests.swift` — add three new integration tests

**No new files. No pbxproj changes.**

Add the following three integration tests to the bottom of the existing `LibraryPersistenceIntegrationTests` class (before the closing `}`):

```swift
// MARK: - Reorder persistence round-trips

func testReorder_commitPersistsAcrossReinit() throws {
    let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-\(UUID()).json")
    defer { try? FileManager.default.removeItem(at: tempURL) }

    let interpreter = RouteInterpreter()
    let store1 = PlayLibraryStore(fileURL: tempURL)
    guard case .success(let pcA) = interpreter.interpret(digits: "6794", formation: .twins),
          case .success(let pcB) = interpreter.interpret(digits: "2943", formation: .tripsLeft),
          case .success(let pcC) = interpreter.interpret(digits: "8761", formation: .proRight) else {
        XCTFail(); return
    }
    store1.save(pcA, motion: nil, yWheelEnabled: false)
    store1.save(pcB, motion: nil, yWheelEnabled: false)
    store1.save(pcC, motion: nil, yWheelEnabled: false)

    // Reorder: move A (index 0) to the end, then commit
    store1.move(fromOffsets: IndexSet([0]), toOffset: 3)
    store1.commitReorder()

    // Reinit — simulates app relaunch (AC-1.4)
    let store2 = PlayLibraryStore(fileURL: tempURL)
    XCTAssertEqual(store2.plays.count, 3)
    XCTAssertEqual(store2.plays[0].routeDigits, "2943", "B must be first after reinit")
    XCTAssertEqual(store2.plays[1].routeDigits, "8761", "C must be second after reinit")
    XCTAssertEqual(store2.plays[2].routeDigits, "6794", "A must be last after reinit")
}

func testReorder_cancelDoesNotPersistAcrossReinit() throws {
    let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-\(UUID()).json")
    defer { try? FileManager.default.removeItem(at: tempURL) }

    let interpreter = RouteInterpreter()
    let store1 = PlayLibraryStore(fileURL: tempURL)
    guard case .success(let pcA) = interpreter.interpret(digits: "6794", formation: .twins),
          case .success(let pcB) = interpreter.interpret(digits: "2943", formation: .tripsLeft),
          case .success(let pcC) = interpreter.interpret(digits: "8761", formation: .proRight) else {
        XCTFail(); return
    }
    store1.save(pcA, motion: nil, yWheelEnabled: false)
    store1.save(pcB, motion: nil, yWheelEnabled: false)
    store1.save(pcC, motion: nil, yWheelEnabled: false)

    // Session: snapshot → move A to end → cancel
    let snapshot = store1.plays
    store1.move(fromOffsets: IndexSet([0]), toOffset: 3)
    store1.cancelReorder(snapshot: snapshot)

    // Reinit — on-disk order must be the original insertion order (AC-2.3 Cancel path)
    let store2 = PlayLibraryStore(fileURL: tempURL)
    XCTAssertEqual(store2.plays.count, 3)
    XCTAssertEqual(store2.plays[0].routeDigits, "6794", "A must be first — cancel must not persist")
    XCTAssertEqual(store2.plays[1].routeDigits, "2943", "B must be second")
    XCTAssertEqual(store2.plays[2].routeDigits, "8761", "C must be third")
}

func testReorderThenDelete_preservesRelativeOrder() throws {
    let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-\(UUID()).json")
    defer { try? FileManager.default.removeItem(at: tempURL) }

    let interpreter = RouteInterpreter()
    let store1 = PlayLibraryStore(fileURL: tempURL)
    guard case .success(let pcA) = interpreter.interpret(digits: "6794", formation: .twins),
          case .success(let pcB) = interpreter.interpret(digits: "2943", formation: .tripsLeft),
          case .success(let pcC) = interpreter.interpret(digits: "8761", formation: .proRight) else {
        XCTFail(); return
    }
    store1.save(pcA, motion: nil, yWheelEnabled: false)
    store1.save(pcB, motion: nil, yWheelEnabled: false)
    store1.save(pcC, motion: nil, yWheelEnabled: false)

    // Reorder: move A (index 0) to end → [B, C, A], then commit
    store1.move(fromOffsets: IndexSet([0]), toOffset: 3)
    store1.commitReorder()
    // Order is now [B(2943), C(8761), A(6794)]

    // Delete the middle play (C at index 1)
    store1.delete(at: IndexSet([1]))
    // Remaining order: [B(2943), A(6794)]

    // Reinit — verify relative order is preserved (AC-1.5)
    let store2 = PlayLibraryStore(fileURL: tempURL)
    XCTAssertEqual(store2.plays.count, 2)
    XCTAssertEqual(store2.plays[0].routeDigits, "2943", "B must remain first")
    XCTAssertEqual(store2.plays[1].routeDigits, "6794", "A must remain second")
}
```

**Build and run tests:**
```bash
xcodebuild build -project SpartansPlaycaller.xcodeproj -scheme SpartansPlaycaller -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD"
xcodebuild test -project SpartansPlaycaller.xcodeproj -scheme SpartansPlaycaller -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -30
```

All three new integration tests must pass. All pre-existing tests must remain green.

### Commit

```bash
git add SpartansPlaycallerTests/LibraryPersistenceIntegrationTests.swift
git commit -m "test: reorder persistence integration tests (commit, cancel, delete)

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

- [ ] Three integration tests written and passing
- [ ] All pre-existing tests green
- [ ] Committed

---

## Task 3 — `PlayLibraryView`: Edit Mode, Drag Handles, Snapshot, Toolbar

**Files modified:**
- `SpartansPlaycaller/Views/PlayLibraryView.swift`

**No new files. No pbxproj changes. No automated tests (UI layer — manual verification only, see Task 4).**

### Step 3.1 — Add new `@State` properties

In `PlayLibraryView`, add two new state properties after the existing `@State private var isSelectMode = false` line:

**Old:**
```swift
@State private var isSelectMode = false
@State private var selectedIDs: Set<UUID> = []
```

**New:**
```swift
@State private var isSelectMode = false
@State private var editMode: EditMode = .inactive
@State private var preSessionOrder: [SavedPlay] = []
@State private var selectedIDs: Set<UUID> = []
```

### Step 3.2 — Add mode transition helpers

Add three private helper methods to `PlayLibraryView`, after the existing `presentShareSheet` method:

```swift
// MARK: - Edit mode lifecycle

private func enterEditMode() {
    preSessionOrder = store.plays   // value copy — captured exactly once at mode entry
    withAnimation(.easeInOut(duration: 0.15)) {
        isSelectMode = true
        editMode = .active
    }
}

private func commitEdit() {
    store.commitReorder()
    preSessionOrder = []
    withAnimation(.easeInOut(duration: 0.15)) {
        isSelectMode = false
        editMode = .inactive
        selectedIDs = []
    }
}

private func cancelEdit() {
    store.cancelReorder(snapshot: preSessionOrder)
    preSessionOrder = []
    withAnimation(.easeInOut(duration: 0.3)) {
        isSelectMode = false
        editMode = .inactive
        selectedIDs = []
    }
}
```

The Cancel animation uses a longer duration (0.3 s) than enter/exit (0.15 s) so coaches see rows animate back to their pre-session positions, communicating "these changes were discarded" rather than an instant confusing reset (UX spec Section 5).

### Step 3.3 — Update `playList` computed property

Replace the entire `private var playList: some View` body with the following:

**Old `playList`:**
```swift
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
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if !isSelectMode {
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
        }
    }
    .listStyle(.plain)
}
```

**New `playList`:**
```swift
private var playList: some View {
    List(selection: isSelectMode ? $selectedIDs : .constant(Set<UUID>())) {
        ForEach(store.plays) { play in
            PlayLibraryRow(
                play: play,
                isSelectMode: isSelectMode,
                isSelected: selectedIDs.contains(play.id),
                dragHandleEnabled: store.plays.count > 1
            ) {
                if isSelectMode {
                    if selectedIDs.contains(play.id) {
                        selectedIDs.remove(play.id)
                    } else {
                        selectedIDs.insert(play.id)
                    }
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if !isSelectMode {
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
        }
        .onMove { offsets, destination in
            store.move(fromOffsets: offsets, toOffset: destination)
        }
    }
    .listStyle(.plain)
    .environment(\.editMode, $editMode)
}
```

Key changes:
- Added `dragHandleEnabled: store.plays.count > 1` parameter to `PlayLibraryRow` (see Step 3.5 for the updated row struct)
- Added `.onMove` on `ForEach` — fires `store.move()` which is in-memory only
- Added `.environment(\.editMode, $editMode)` on the `List` — activates SwiftUI drag handles when `editMode == .active`

### Step 3.4 — Update the toolbar

Replace the entire `.toolbar { ... }` block with the following:

**Old toolbar:**
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

**New toolbar:**
```swift
.toolbar {
    ToolbarItem(placement: .topBarLeading) {
        if isSelectMode {
            // Edit mode: Cancel discards reorder + exits
            Button("Cancel") { cancelEdit() }
        } else {
            // Normal mode: Done dismisses the library sheet
            Button("Done") { dismiss() }
        }
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
                // Edit mode: Done commits reorder + exits
                Button("Done") { commitEdit() }
            } else {
                // Normal mode: Edit enters combined select + reorder mode
                Button("Edit") { enterEditMode() }
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

Key changes:
- Leading `ToolbarItem`: conditionally shows Cancel (Edit mode, calls `cancelEdit()`) or Done (Normal mode, calls `dismiss()`)
- Trailing "Select" button renamed to "Edit"; tap calls `enterEditMode()` instead of setting `isSelectMode = true` directly
- Trailing in Edit mode: "Done" button that calls `commitEdit()` (was "Cancel" that only cleared selection)
- Bottom bar is unchanged

### Step 3.5 — Update `PlayLibraryRow` to accept and render the drag handle

Replace the entire `private struct PlayLibraryRow` definition with:

```swift
private struct PlayLibraryRow: View {
    let play: SavedPlay
    let isSelectMode: Bool
    let isSelected: Bool
    let dragHandleEnabled: Bool
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
                if isSelectMode {
                    Image(systemName: "line.3.horizontal")
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        .opacity(dragHandleEnabled ? 1.0 : 0.3)
                        .allowsHitTesting(dragHandleEnabled)
                        .accessibilityLabel("Reorder \(play.formationName) \(play.routeDigits)")
                        .accessibilityHint(dragHandleEnabled ? "" : "Reordering requires at least 2 plays")
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
    }
}
```

Key changes from original:
- Added `dragHandleEnabled: Bool` parameter
- Added drag handle `Image(systemName: "line.3.horizontal")` in the trailing position, visible only when `isSelectMode` is `true`
- Handle uses `.opacity(dragHandleEnabled ? 1.0 : 0.3)` and `.allowsHitTesting(dragHandleEnabled)` for the 1-play disabled state (UX spec Section 4 must-fix)
- 44×44 pt touch target via `.frame(width: 44, height: 44).contentShape(Rectangle())`
- Accessibility label and hint (UX spec Section 4 should-fix)

Note: The custom drag handle icon is decorative — it communicates affordance to the user. The actual drag initiation is handled by SwiftUI's `.onMove` machinery activated via `.environment(\.editMode, $editMode)`. When `editMode` is `.active`, SwiftUI renders its own drag recognizer on the trailing edge. The custom icon appears alongside SwiftUI's system drag recognizer area. On iOS 17+, `.onMove` with `editMode = .active` activates long-press-and-drag on the trailing reorder zone; the custom icon in the row aligns visually with that zone.

### Step 3.6 — Build verification

```bash
xcodebuild build -project SpartansPlaycaller.xcodeproj -scheme SpartansPlaycaller -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD"
```

Build must succeed with zero errors. Warnings about SwiftUI previews or deprecations are acceptable; errors are not.

### Step 3.7 — Commit

```bash
git add SpartansPlaycaller/Views/PlayLibraryView.swift
git commit -m "feat: PlayLibraryView Edit mode with drag handles, snapshot, and Cancel/Done toolbar

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

- [ ] State properties added (Step 3.1)
- [ ] Mode transition helpers added (Step 3.2)
- [ ] `playList` updated with `.onMove` and `.environment(\.editMode, $editMode)` (Step 3.3)
- [ ] Toolbar restructured: Cancel leading / Done trailing in Edit mode; "Select" → "Edit" (Step 3.4)
- [ ] `PlayLibraryRow` updated with `dragHandleEnabled` parameter and drag handle icon (Step 3.5)
- [ ] Build passes (Step 3.6)
- [ ] Committed (Step 3.7)

---

## Task 4 — Full Test Suite, Push, and Test Results

### Step 4.1 — Disk space pre-flight

```bash
df -h .
```

If disk is above 90% used, halt. Clean DerivedData and unavailable simulators:
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData
xcrun simctl delete unavailable
```

### Step 4.2 — Full test suite

```bash
xcodebuild test -project SpartansPlaycaller.xcodeproj -scheme SpartansPlaycaller -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -30
```

All tests must pass:
- 6 new unit tests in `PlayLibraryStoreTests`
- 3 new integration tests in `LibraryPersistenceIntegrationTests`
- All pre-existing tests unchanged and green

If any test fails, fix it before proceeding. Do not skip or comment out failing tests.

### Step 4.3 — Push branch

```bash
git push -u origin feat/library-reorder
```

### Step 4.4 — Update plan checkboxes

Mark all task checkboxes above as `[x]` in this file. Commit:

```bash
git add docs/superpowers/plans/2026-06-09-library-reorder.md
git commit -m "docs: mark library-reorder plan tasks complete

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
git push
```

### Step 4.5 — Write test results report

Write the test results to `docs/test-plans/library-reorder-test-results.md`. The report must include:
- Pass/fail count for automated tests
- Simulator target used
- Any pre-existing failures (if any — document separately from new failures)
- All 10 manual check outcomes (UI-1 through UI-10) — document each as Pass / Fail / Observation
- Date and author

The 10 manual checks are defined in the Manual Verification Checklist below. SDET must execute all 10 before the results file is considered complete. An incomplete results file is not acceptable — each check must have a documented outcome.

- [ ] Disk space verified (Step 4.1)
- [ ] Full test suite passes (Step 4.2)
- [ ] Branch pushed (Step 4.3)
- [ ] Plan checkboxes updated and committed (Step 4.4)
- [ ] Test results written to `docs/test-plans/library-reorder-test-results.md` (Step 4.5)

---

## Acceptance Criteria Coverage

| AC | Description | Test / Verification |
|----|-------------|---------------------|
| AC-1.1 | Drag handle visible in Edit mode | UI-1 (manual) |
| AC-1.2 | Live feedback during drag | UI-2 (manual) |
| AC-1.3 | Order buffered; not written until Done | `testMove_doesNotPersistImmediately`, `testCancelReorder_doesNotWriteToDisk` |
| AC-1.4 | Order survives app restart | `testReorder_commitPersistsAcrossReinit` |
| AC-1.5 | Order preserved after subsequent edits/deletes | `testReorderThenDelete_preservesRelativeOrder` |
| AC-2.1 | Edit is single entry point; no separate Reorder button | UI-3 (manual) |
| AC-2.2 | Edit disabled/hidden when library empty | UI-4 (manual) |
| AC-2.3 Done | Commits reorder to disk; exits mode | `testCommitReorder_persistsNewOrder`; UI-5 (manual) |
| AC-2.3 Cancel | Restores pre-session order; no disk write | `testCancelReorder_restoresSnapshot`, `testCancelReorder_doesNotWriteToDisk`, `testReorder_cancelDoesNotPersistAcrossReinit`; UI-6 (manual) |
| AC-2.4 | Drag handle non-interactive for 1-play library | `PlayLibraryRow.dragHandleEnabled` opacity + `allowsHitTesting`; UI-7 (manual) |
| AC-2.5 | Swipe actions suppressed in Edit mode | Existing `!isSelectMode` guard preserved; UI-8 (manual) |
| AC-3.1 | Export order matches library order | `testReorderThenDelete_preservesRelativeOrder` (order preserved); UI-9, UI-10 (manual) |
| AC-3.2 | Export does not alter stored order | `triggerExport` is read-only; no store mutations; verified by existing `ExportCardTests` |

---

## Manual Verification Checklist

These checks must be performed on a simulator or device running the built app. Document each outcome in `docs/test-plans/library-reorder-test-results.md`.

- [ ] **UI-1 (AC-1.1):** Enter Edit mode — drag handles (`≡` icon, trailing edge) appear at the trailing edge of each row. Both checkboxes (leading) and drag handles (trailing) are visible simultaneously without layout overlap.
- [ ] **UI-2 (AC-1.2):** Drag a play to a new position — row lifts visually, adjacent rows shift to show the insertion point. Standard SwiftUI `.onMove` animation fires.
- [ ] **UI-5 (AC-2.3 Done):** Tap Done — reordered order persists after app restart. Toolbar returns to Normal mode (Cancel/Done replace Edit/Done; "Edit" button reappears).
- [ ] **UI-6 (AC-2.3 Cancel):** Tap Cancel — order reverts to pre-session state in real time (animated revert visible, no restart needed). No disk write occurred.
- [ ] **UI-3 (AC-2.1):** There is no separate "Reorder" button anywhere in the library UI. "Edit" is the single entry point.
- [ ] **UI-4 (AC-2.2):** With an empty library, the "Edit" button is disabled (grayed out or not tappable).
- [ ] **UI-7 (AC-2.4):** With exactly 1 play in the library, enter Edit mode. Drag handle is visible at 30% opacity and does not initiate a drag when long-pressed.
- [ ] **UI-8 (AC-2.5):** While in Edit mode, swipe a row — no Delete or Edit swipe actions appear. Tapping a row toggles its checkbox; it does not open the play editor.
- [ ] **UI-9 (AC-1.3 live):** After dragging a play to a new position but before tapping Done, background-kill the app and relaunch. The library displays the pre-session order, not the in-session drag order (in-memory buffer not incidentally persisted).
- [ ] **UI-10 (TQ-1):** In Edit mode with multiple plays checked (checkboxes active), drag a different row. After the drag: (a) the previously-checked plays remain checked, and (b) the drag handle is still functional for further drags. Selection and drag do not clobber each other.

---

## Self-Review Notes

**Invariants relied on:**
- `PlayLibraryStore` is `@MainActor final class` — all `plays` mutations are serialized on the main actor, eliminating concurrent-write races on the snapshot.
- `[SavedPlay]` is an array of `struct` (value types) — `preSessionOrder = store.plays` produces a deep copy via Swift copy-on-write. Subsequent `store.move()` calls do not mutate `preSessionOrder`.
- `plays` is `@Published private(set)` — `cancelReorder(snapshot:)` sets `plays = snapshot` from within the store's own method, satisfying the access control.
- The `guard !snapshot.isEmpty || plays.isEmpty` in `cancelReorder` prevents an empty-snapshot bug from wiping a non-empty library.

**What could confuse a newcomer:**
- The custom drag handle icon in `PlayLibraryRow` is decorative only; the actual drag gesture is owned by SwiftUI's `.onMove` machinery. The system's drag zone and the custom icon visually align on the trailing edge, but they are separate mechanisms.
- `editMode = .active` is required for `.onMove` handles to appear — the `List(selection:)` binding alone does not activate drag handles. Both `isSelectMode` and `editMode` must be set together in all three handlers.
- `commitEdit()` calls `store.commitReorder()` (which calls `persist()`) before resetting `editMode`. The order matters: if `editMode` were reset first, a re-render could briefly show Normal mode UI while the persist was still in flight.

**Speculative risk (low):**
- SwiftUI's system drag handle and the custom `line.3.horizontal` icon may visually stack on iOS 17 (custom icon + system handle in the same trailing zone). If the system handle renders as a separate element rather than at the position of the custom icon, the trailing edge may appear crowded. Manual check UI-1 will reveal this. Mitigation: hide the custom icon when `editMode == .active` and rely solely on the system handle; or always show the custom icon and suppress the system handle by removing `.onMove` (requires custom drag gesture — significantly more complex). The plan as written uses both simultaneously. If UI-1 reveals a crowding issue, the fix is to remove the custom icon and rely on the system handle for both the visual affordance and the drag gesture.
