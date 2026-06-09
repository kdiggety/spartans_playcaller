# Library Reorder — Test Strategy

**Feature:** Library Reorder
**Date:** 2026-06-09
**Author:** SDET
**Status:** PLANNING GATE ARTIFACT — required before implementation plan may be written
**Spec reference:** `docs/superpowers/specs/library-reorder-spec.md`
**Design reference:** TBD — pending architecture-system-design output (TQ-1 must be resolved before UI-layer implementation plan is finalized)

---

## 1. Regression Scope

### 1.1 Risk Summary

This feature adds a `move` method to `PlayLibraryStore`, a pre-session snapshot mechanism for the Cancel discard path, and expands Select mode in `PlayLibraryView` to simultaneously expose checkboxes and drag handles. The store's `plays: [SavedPlay]` array is the single source of truth for display order and for export card numbering. Any mutation to that array, or any change to how it is persisted or reloaded, carries regression risk across both the library view and the entire PDF export pipeline.

**Highest risk — PlayLibraryStore move + buffered persist**

The new `move` method must mutate the in-memory `plays` array without writing to disk. The persist-on-Done path then writes. The Cancel path must silently restore the pre-session snapshot without a write. This is a new persistence timing pattern: today, every mutation (`save`, `delete`, `update`) writes immediately. Introducing a deferred write creates the possibility of snapshot-restoration bugs, missed-persist bugs, or over-eager persists. The existing `testLoadFromFileOnInit` and the full set of `LibraryPersistenceIntegrationTests` are the primary guards against regressions here.

**High risk — Export play numbering**

`PlayLibraryView.triggerExport` builds `ExportCard` objects by enumerating `selectedPlays`, which is `store.plays.filter { selectedIDs.contains($0.id) }`. The play numbers printed on exported cards (1, 2, 3…) are `i + 1` from that enumeration. Because `selectedPlays` preserves the order of `store.plays`, reorder correctness flows through to export numbering without any new code — but it also means a reorder bug (wrong final array order, or a persist bug that leaves the on-disk order unchanged) will silently produce incorrectly numbered export cards. This is AC-3.1 and must have an integration test.

**High risk — Cancel path: snapshot must not persist**

The Cancel discard path is the most failure-prone new behavior. The store must hold a snapshot of `plays` at Select mode entry time and restore it on Cancel without calling `persist()`. A snapshot that is taken at the wrong moment (after a drag rather than at mode entry), released too early, or applied with an erroneous `persist()` call will either silently corrupt the on-disk order or fail to restore the in-memory order. This class of bug is invisible to any test that does not exercise the full cycle: save initial order → enter Select → drag → Cancel → reinit and verify on-disk order was NOT changed.

**Medium risk — Order preserved across subsequent edits and deletes**

AC-1.5 states that performing any subsequent edit, delete, or export does not reset list order to insertion order. Today, `delete(at:)` and `update(_:)` operate on the `plays` array by index or by UUID lookup, both of which are order-preserving. The risk is that a future change to the move method or a refactor of `plays` initialization could reintroduce insertion-time ordering. The integration tests for reorder + delete and reorder + update are the regression guard for this class of bug.

**Low risk — Existing selection and export paths**

The selection pipeline (`selectedIDs`, `selectedPlays`, `triggerExport`) is not structurally changed by this feature — the implementation adds drag handle visibility and mode state, but `selectedPlays` still filters `store.plays` in array order. The export regression tests from prior features (`ExportCardTests`, `WristbandPDFGeneratorTests`, `CatalogPDFGeneratorTests`) remain the guards for the export pipeline.

### 1.2 Existing Test Files That Must Remain Green

All files in `SpartansPlaycallerTests/`. The ones carrying material regression risk for this feature:

| File | Risk for this feature | Reason |
|------|-----------------------|--------|
| `PlayLibraryStoreTests.swift` | **HIGH** | New move method and snapshot/restore logic lives here |
| `LibraryPersistenceIntegrationTests.swift` | **HIGH** | Round-trip across reinit; must survive move + deferred persist; Cancel must leave file unchanged |
| `ExportCardTests.swift` | **HIGH** | Export order correctness after reorder (AC-3.1) |
| `WristbandPDFGeneratorTests.swift` | Medium | Calls `ExportCard`; any change to ordering or card construction affects this |
| `CatalogPDFGeneratorTests.swift` | Medium | Same reason as above |
| `SavedPlayCodableTests.swift` | Low | `SavedPlay` struct is not changed; round-trip must still work |
| `PlayCallerViewModelTests.swift` | Low | ViewModel is not changed by this feature; guard against accidental coupling |

All rendering, route interpretation, and motion tests (`DiagramRenderer*`, `Y_Wheel*`, `ReceiverMotion*`, `ConceptMatcher*`, `RouteSemanticProvider*`, `RouteInterpreter*`) carry negligible regression risk; this feature does not touch geometry or route logic.

---

## 2. Test Pyramid Balance

| Layer | Scope | Target volume | Rationale |
|-------|-------|---------------|-----------|
| Unit — `PlayLibraryStore` | `move` correctness, snapshot/restore, edge cases (single play, same-position, first↔last) | ~12 tests | The store is the only durable mutation surface. Every behavioral contract for the new move method must be proven here before integration tests are written. |
| Unit — Mode state guard | `move` no-op when called outside Select mode (if the architecture spec exposes this guard at the store layer); or equivalent boundary test defined once architecture spec clarifies the snapshot API | ~2 tests | Prevents rogue calls from corrupting order outside of a Select session. |
| Integration — Persistence round-trip | Move + Done + reinit (order persisted), Move + Cancel + reinit (on-disk order unchanged), move + delete (order stable), move + export (export card order matches library order) | ~8 tests | Highest-value tests in the feature. Catch the class of bug where in-memory state is correct but the file is not updated (or is incorrectly updated on Cancel). |
| UI / E2E | None automated | 0 | No XCUITest infrastructure exists and none is being added. Manual checks cover drag gesture discoverability, drag handle visual appearance, mode transition animation, and single-play handle disabled state. |

**Total estimated automated tests:** ~22 new (unit + integration), plus the full existing suite as regression guard.

---

## 3. Unit Tests — Store Layer

All store-layer tests belong in `PlayLibraryStoreTests.swift`. All require `@MainActor` at the class level (existing annotation already present). Each test instantiates `PlayLibraryStore` with a UUID-namespaced temp URL and deletes the file in `tearDown`.

The exact method signature(s) for move and snapshot operations will be defined by architecture-system-design. The test intent below is written against behavior, not a specific API, to remain valid regardless of whether the architecture chooses `move(fromOffsets: IndexSet, toOffset: Int)` (the SwiftUI `.onMove` callback signature), a simpler `move(from: Int, to: Int)` pair, or a model-level wrapper.

### 3.1 Core Move Behavior

**testMove_shiftsMidsectionPlay**
- Setup: save three plays with distinct, identifiable route digits (A at index 0, B at index 1, C at index 2).
- Action: move B from index 1 to index 0 (prepend).
- Assert: `plays` order is [B, A, C]. UUIDs at each position match expected plays.

**testMove_firstToLast**
- Setup: three plays A, B, C.
- Action: move A (index 0) to last position.
- Assert: order is [B, C, A].

**testMove_lastToFirst**
- Setup: three plays A, B, C.
- Action: move C (index 2) to first position.
- Assert: order is [C, A, B].

**testMove_samePosition_noChange**
- Setup: three plays A, B, C.
- Action: move B (index 1) to index 1 (or equivalent no-op call).
- Assert: `plays` order is [A, B, C] — no mutation. Play UUIDs and order unchanged.

**testMove_singlePlay_noChange**
- Setup: one play.
- Action: attempt a move (from 0 to 0, or any valid call with a single element).
- Assert: `plays` still has one element, UUID unchanged. No crash.

**testMove_twoPlays_swapOrder**
- Setup: save two plays A, B.
- Action: move A to position 1 (or B to position 0).
- Assert: order is [B, A].

**testMove_doesNotPersistImmediately**
- Setup: save three plays. Read on-disk JSON to capture the initial persisted order (the array of `routeDigits` in file order).
- Action: call the move method for a reorder.
- Assert: re-read the file immediately after the move call. The on-disk `routeDigits` order must match the pre-move order — the move must not have written to disk.
- Note: This test directly validates AC-1.3. It reads raw `Data(contentsOf: tempURL)` and decodes it, bypassing the store's in-memory state.

**testMoveMultipleTimes_inMemoryStateReflectsLastMove**
- Setup: three plays A, B, C. Perform two successive moves: move A to last (result [B, C, A]), then move B to last (result [C, A, B]).
- Assert: `store.plays` order is [C, A, B] after both moves.

### 3.2 Snapshot / Done / Cancel Path

The architecture spec will define the API for entering/exiting Select mode at the store layer. The following tests are written against the observable behavior; once the API is known the test code will map to the correct call site. If snapshot/restore is managed entirely at the ViewModel or View layer (rather than the store), the unit tests for snapshot/restore belong in the corresponding ViewModel test file — this is a TBD pending architecture-system-design resolution.

**testCancel_restoresPreSessionOrder**
- Setup: save three plays A, B, C. Capture the initial `plays` array (or the order by UUID).
- Action: simulate Select mode entry (take snapshot), call move (B to first → [B, A, C]), then call cancel (restore snapshot).
- Assert: `store.plays` order matches the pre-session capture [A, B, C].

**testCancel_doesNotWriteToDisk**
- Setup: same as `testMove_doesNotPersistImmediately` — read the initial on-disk file content before the session.
- Action: enter Select mode, move a play, cancel.
- Assert: re-read the file after cancel. On-disk content must match the pre-session file content byte-for-byte (or at minimum, the decoded `routeDigits` order must match). No write occurred.

**testDone_persistsReorderedArray**
- Setup: save three plays A, B, C.
- Action: enter Select mode (take snapshot), move A to last ([B, C, A]), commit Done.
- Assert: `store.plays` order is [B, C, A]. Read and decode the file directly — assert the on-disk `routeDigits` order matches [B's digits, C's digits, A's digits].

**testDone_afterNoMoves_persistsUnchangedOrder**
- Setup: save three plays. Enter Select mode, do NOT move anything, commit Done.
- Assert: `store.plays` order is unchanged. On-disk order matches original.

**testCancel_afterNoMoves_noSideEffects**
- Setup: save three plays. Enter Select mode, do NOT move anything, cancel.
- Assert: `store.plays` order is unchanged. On-disk order matches original. No additional write to disk occurred (file modification date must not advance — or detect via a second read and comparison).

### 3.3 Interaction With Delete

**testDeleteAfterMove_preservesReorderedPositions**
- Setup: save four plays A, B, C, D. Move D to index 0 → [D, A, B, C]. Then delete index 1 (which is now A).
- Assert: `store.plays` order is [D, B, C]. The reordered position of D at index 0 is preserved; delete operates on the post-move array.
- Note: This is a unit-level version of the AC-1.5 contract. The integration version (with reinit) is in Section 4.

---

## 4. Integration Tests — Persistence Round-Trip

Integration tests verify that the on-disk representation survives a reinit cycle correctly for each code path. All tests belong in `LibraryPersistenceIntegrationTests.swift` or a new `LibraryReorderIntegrationTests.swift` file (register in `project.pbxproj` if new). All require `@MainActor`.

**testReorderDone_persistsAcrossReinit**
- Setup: `store1` saves three plays A, B, C. Enter Select mode on `store1`, move A to last, commit Done.
- Reinit: create `store2` at the same temp URL.
- Assert: `store2.plays` order is [B, C, A]. Specific `routeDigits` values at each index match expected plays. This is the primary AC-1.4 test.

**testReorderCancel_onDiskOrderUnchangedAcrossReinit**
- Setup: `store1` saves three plays A, B, C. Enter Select mode, move A to last, cancel.
- Reinit: create `store2` at the same temp URL.
- Assert: `store2.plays` order is [A, B, C]. The on-disk order reflects the pre-session state, not the cancelled in-session state.

**testReorderThenDelete_persistsAcrossReinit**
- Setup: `store1` saves four plays A, B, C, D. Move D to index 0, commit Done → [D, A, B, C]. Then delete index 2 (C).
- Reinit: create `store2`.
- Assert: `store2.plays` order is [D, A, B] with matching `routeDigits`. This validates AC-1.5 (order preserved after delete) at the persistence layer.

**testReorderThenUpdate_persistsAcrossReinit**
- Setup: `store1` saves three plays A, B, C. Move C to index 0, commit Done → [C, A, B]. Update B's `motionLabel`.
- Reinit: create `store2`.
- Assert: `store2.plays` order is [C, A, B]. `store2.plays[2].motionLabel` reflects the updated value. This validates that `update(_:)` does not reset to insertion order.

**testMultipleReorderSessions_latestDoneWins**
- Setup: `store1` saves three plays A, B, C. Session 1: move A to last ([B, C, A]), commit Done. Session 2: move B to last ([C, A, B]), commit Done.
- Reinit: create `store2`.
- Assert: `store2.plays` order is [C, A, B] — the second Done's result is persisted, not the first.

**testReorderThenExport_exportOrderMatchesLibraryOrder**
- Setup: `store1` saves three plays A, B, C. Move A to last, commit Done → [B, C, A].
- Build `ExportCard` objects the same way `PlayLibraryView.triggerExport` does: filter all three play IDs, enumerate in `store.plays` order, assign `playNumber = i + 1`.
- Assert: the first card has `playNumber == 1` and `routeDigits` matching B; the second card has `playNumber == 2` and digits matching C; the third card has `playNumber == 3` and digits matching A.
- Note: This validates AC-3.1. It tests the ordering contract at the layer where play numbers are assigned, not at the PDF rendering layer. Belongs in `ExportCardTests.swift` or the new reorder integration test file.

**testReorderThenExport_exportDoesNotAlterStoredOrder**
- Setup: `store1` saves three plays A, B, C. Move A to last, commit Done → [B, C, A]. Build `ExportCard` objects (read-only operation).
- Assert: after the export build, `store1.plays` order is still [B, C, A]. `selectedPlays` filtering did not mutate `store.plays`. This validates AC-3.2.

---

## 5. UI Layer — Manual Checks

No XCUITest infrastructure exists and none is being added. The following behavioral checks must be performed manually during SDET execution. Document outcomes (pass/fail/observation) in the test results report.

| Check ID | AC | Description |
|----------|----|-------------|
| UI-1 | AC-1.1 | In Select mode, each row shows both a checkbox and a drag handle (`line.3.horizontal` icon). Both are visible simultaneously without layout overlap. |
| UI-2 | AC-1.2 | Drag a row; it lifts visually, adjacent rows shift to show insertion point. Standard SwiftUI `.onMove` animation. No custom animation required; verify it works. |
| UI-3 | AC-2.1 | The Select button entry point for reorder is the existing Select button — no separate Reorder button exists anywhere in the library UI. |
| UI-4 | AC-2.2 | When library is empty, Select button is hidden or visibly disabled. |
| UI-5 | AC-2.3 (Done) | Tapping Done exits Select mode; toolbar returns to normal state (Done/Cancel controls disappear, Select returns). Reordered order persists after relaunch. |
| UI-6 | AC-2.3 (Cancel) | Tapping Cancel exits Select mode; toolbar returns to normal state. List order reverts to the pre-session order in real time (no relaunch needed to observe the revert). |
| UI-7 | AC-2.4 | With exactly 1 play in the library, enter Select mode. Drag handle is visible but non-interactive (disabled state — does not initiate a drag). |
| UI-8 | AC-2.5 | While in Select mode, swiping a row does not reveal Delete or Edit swipe actions. Tapping a row toggles its checkbox; does not open the play editor. |
| UI-9 | AC-1.3 (live) | After dragging a play to a new position but before tapping Done, close the app (background kill) and relaunch. The library should display the pre-session order, not the in-session drag order. Confirms that the in-memory buffer is not incidentally persisted by app termination. |
| UI-10 | TQ-1 (coexistence) | In Select mode with multiple plays selected (checkboxes active), drag a row. Verify neither operation clobbers the other: the selection set is preserved after the drag, and the drag handle remains functional while a row is selected. This is the manual validation of the architecture's TQ-1 resolution. |

---

## 6. Regression Scope — Existing Tests That Must Pass

The command `xcodebuild test -scheme SpartansPlaycaller -destination 'platform=iOS Simulator,name=iPhone 16'` must complete with zero failures across all pre-existing test files before the reorder feature is merged. The files below are specifically called out because they share surfaces changed by this feature:

- `PlayLibraryStoreTests.swift` — all existing tests (save, delete, update, codability) must be unaffected
- `LibraryPersistenceIntegrationTests.swift` — all three existing round-trip tests
- `ExportCardTests.swift` — export card construction from `SavedPlay` must not change
- `WristbandPDFGeneratorTests.swift` and `CatalogPDFGeneratorTests.swift` — PDF layout tests must be unaffected
- `EditPlayViewModelTests.swift` — edit flow ViewModel tests must be unaffected (no accidental coupling to reorder state)

---

## 7. `@MainActor` Requirements

`PlayLibraryStore` is `@MainActor final class`. Every test class that instantiates or calls methods on `PlayLibraryStore` must be annotated `@MainActor` at the class level.

If the architecture spec introduces a `LibraryViewModel` or `ReorderViewModel` (or any `ObservableObject` that drives Select mode state), those types will also be `@MainActor`-isolated. Any test class that instantiates them must carry the same `@MainActor` annotation.

This is a project process rule (`.claude/rules/project-process.md`). SDET must verify the annotation on all new test files before accepting implementation as complete. Missing `@MainActor` produces compile-time isolation errors that are caught at build time, not at runtime — but only if the file is registered in `project.pbxproj` (see Section 9).

**Correct pattern (matches existing `PlayLibraryStoreTests.swift`):**
```swift
@MainActor
final class LibraryReorderStoreTests: XCTestCase {
    var tempURL: URL!
    var store: PlayLibraryStore!

    override func setUp() {
        super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("reorder-\(UUID()).json")
        store = PlayLibraryStore(fileURL: tempURL)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempURL)
        super.tearDown()
    }
}
```

---

## 8. Acceptance Criteria Coverage Map

| AC ID | Description | Test Case(s) | Type | File |
|-------|-------------|-------------|------|------|
| AC-1.1 | Drag handle visible in Select mode | UI-1 (manual) | Manual | — |
| AC-1.2 | Live feedback during drag | UI-2 (manual) | Manual | — |
| AC-1.3 | Order buffered; not persisted until Done | `testMove_doesNotPersistImmediately` | Unit | `PlayLibraryStoreTests` |
| AC-1.3 | Cancel reverts in-memory order | `testCancel_restoresPreSessionOrder` | Unit | `PlayLibraryStoreTests` |
| AC-1.3 | Cancel does not write to disk | `testCancel_doesNotWriteToDisk` | Unit | `PlayLibraryStoreTests` |
| AC-1.4 | Order survives app restart | `testReorderDone_persistsAcrossReinit` | Integration | `LibraryPersistenceIntegrationTests` |
| AC-1.5 | Order preserved after delete | `testDeleteAfterMove_preservesReorderedPositions` | Unit | `PlayLibraryStoreTests` |
| AC-1.5 | Order preserved after delete (persistence) | `testReorderThenDelete_persistsAcrossReinit` | Integration | `LibraryPersistenceIntegrationTests` |
| AC-1.5 | Order preserved after update (persistence) | `testReorderThenUpdate_persistsAcrossReinit` | Integration | `LibraryPersistenceIntegrationTests` |
| AC-2.1 | Select is single entry point; no Reorder button | UI-3 (manual) | Manual | — |
| AC-2.2 | Select disabled/hidden when library empty | UI-4 (manual) | Manual | — |
| AC-2.3 | Done commits order and exits mode | `testDone_persistsReorderedArray`; UI-5 (manual) | Unit + Manual | `PlayLibraryStoreTests` |
| AC-2.3 | Cancel discards and exits mode | `testCancel_restoresPreSessionOrder`; `testCancel_doesNotWriteToDisk`; UI-6 (manual) | Unit + Manual | `PlayLibraryStoreTests` |
| AC-2.3 | Cancel after no moves — no side effect | `testCancel_afterNoMoves_noSideEffects` | Unit | `PlayLibraryStoreTests` |
| AC-2.3 | Done after no moves — no corruption | `testDone_afterNoMoves_persistsUnchangedOrder` | Unit | `PlayLibraryStoreTests` |
| AC-2.4 | Drag handle non-interactive for 1-play library | UI-7 (manual) | Manual | — |
| AC-2.5 | Swipe actions suppressed in Select mode | UI-8 (manual) | Manual | — |
| AC-3.1 | Export order matches library order | `testReorderThenExport_exportOrderMatchesLibraryOrder` | Integration | `ExportCardTests` or `LibraryReorderIntegrationTests` |
| AC-3.2 | Export does not alter stored order | `testReorderThenExport_exportDoesNotAlterStoredOrder` | Integration | `ExportCardTests` or `LibraryReorderIntegrationTests` |
| TQ-1 | Checkbox + drag handle coexist in Select mode | UI-10 (manual) | Manual | — |

**Total automated tests:** ~22 new (unit + integration)
**Manual checks:** 10 (UI-1 through UI-10)

---

## 9. Test Environment Prerequisites

**Temp file URL isolation:** Every test class that instantiates `PlayLibraryStore` must supply a `UUID()`-namespaced temp URL. Pattern: `FileManager.default.temporaryDirectory.appendingPathComponent("reorder-\(UUID()).json")`. This is the established project pattern and must not be varied.

**`tearDown` cleanup:** Every test class that creates a temp URL must delete the file in `tearDown` via `try? FileManager.default.removeItem(at: tempURL)`. Failure accumulates temp files in the simulator and can interfere with subsequent runs.

**`project.pbxproj` registration:** Any new test file must be registered in `SpartansPlaycaller.xcodeproj/project.pbxproj` before running `xcodebuild test`. Unregistered files are silently excluded from the test run — they will not fail the build, and their tests will never execute. This is a project process rule. SDET must verify registration by confirming each new test class's name appears in `xcodebuild test` output.

**Simulator target:** iOS 17.0+ simulator. The `.completeFileProtection` write attribute is accepted on simulator but not enforced — consistent with the existing project pattern noted in `testPersistUsesCompleteFileProtection`.

**No async test infrastructure needed:** `PlayLibraryStore` is synchronous on `@MainActor`; no `XCTestExpectation` or `async/await` is needed for store-level unit tests. If the architecture spec introduces a `LibraryViewModel` with async Select mode entry/exit, those tests may require `async` test methods — this will be resolved when the architecture spec is produced.

**Disk space:** Before `xcodebuild test` and before `git push`, verify available disk per the project process rule (`df -h .`). If disk exceeds ~90% usage, halt and surface the warning. DerivedData and simulator runtimes accumulate silently.

---

## 10. Open Architecture Dependencies

The following test definitions are conditional pending architecture-system-design resolution:

| Open question | Affected test cases | Unblocking condition |
|---------------|---------------------|----------------------|
| TQ-1: SwiftUI `List(selection:)` + `.onMove` coexistence | UI-10 (manual check scope may expand if a workaround is required); potential ViewModel-layer unit tests if the architecture adds selection-suspension logic | Architecture spec confirms whether both are directly composable or require an intermediary state machine |
| Snapshot API placement: store-level vs ViewModel-level | `testCancel_restoresPreSessionOrder`, `testCancel_doesNotWriteToDisk`, `testDone_persistsReorderedArray` — these are written against the store layer; if snapshot/restore lives in a ViewModel, tests move to the ViewModel test file | Architecture spec defines which type owns the snapshot |
| Whether `move` is exposed as `move(fromOffsets: IndexSet, toOffset: Int)` or a simpler `move(from: Int, to: Int)` | Test code (IndexSet construction vs integer arguments) | Architecture spec defines the method signature |
| Whether `LibraryViewModel` or similar type is introduced | If introduced, add `@MainActor` ViewModel-layer tests for: Select mode entry guard (library count ≥ 1), mode state transitions, snapshot lifecycle | Architecture spec confirms or denies a ViewModel type |

These TBDs do not block writing or executing the store-layer unit tests or the persistence integration tests. Those tests can be written and run as soon as the store's `move` method and snapshot/restore mechanism exist, regardless of TQ-1 resolution or ViewModel introduction.

---

## 11. SDET Execution Verification Gate

At Step 7 (Feature Addition template), SDET execution is not complete until all of the following are true:

1. All ~22 new automated tests pass with `xcodebuild test -scheme SpartansPlaycaller -destination 'platform=iOS Simulator,name=iPhone 16'`.
2. All pre-existing test files remain green — zero regressions across the full suite.
3. All new test files are registered in `project.pbxproj` and their class names appear in `xcodebuild test` console output (no silent exclusions).
4. All new test classes that instantiate `PlayLibraryStore` or any `@MainActor` type carry the `@MainActor` class annotation.
5. All 10 manual checks (UI-1 through UI-10) are executed and outcomes documented in the test results report.
6. Test results written to `docs/test-plans/library-reorder-test-results.md`.

If any automated test fails, dispatch software-engineer to fix before declaring the feature complete. If any manual check reveals a defect, file a backlog item with reproduction steps and determine whether it is merge-blocking before proceeding.
