# Library Edit and Delete — Test Strategy

**Feature:** Library Edit and Delete
**Date:** 2026-06-08
**Author:** SDET
**Status:** PLANNING GATE ARTIFACT — required before implementation plan may be written
**Spec reference:** `docs/superpowers/specs/library-edit-delete-spec.md`
**Design reference:** TBD — pending architecture-system-design output

---

## 1. Regression Scope

### 1.1 Risk Summary

This feature adds `PlayLibraryStore.update(_:at:)` (or equivalent), confirmation-guarded delete paths in the UI, a Delete All action, and an edit surface for in-place play mutation. The persistence layer and model types are shared with the export pipeline. Any change to `PlayLibraryStore`, `SavedPlay`, or the interpreter round-trip path used in `ExportCard.from(savedPlay:...)` carries regression risk across that pipeline.

**Highest risk — PlayLibraryStore mutation surface**

The store today has `save`, `delete(at:)`, and `deleteAll`. This feature adds `update(_:at:)` (index-based in-place replacement). Any incorrect array-mutation in `update` can silently corrupt `plays`, which is the source of truth for both the list view and the export pipeline. The existing `testDeleteAtOffsets` and `testLoadFromFileOnInit` tests are the key regression guards for the persistence contract.

**High risk — savedAt timestamp semantics on edit**

AC-3.4 requires that `savedAt` is updated on edit. `SavedPlay` is currently a fully immutable `struct`; all fields are `let`. An update implementation must produce a new `SavedPlay` value with the original `id` preserved and a fresh `savedAt`. Any implementation that copies the old `savedAt` (no-op) or fails to preserve the original `id` (breaks identity) will violate spec. `SavedPlayCodableTests` currently does not assert identity-preservation across a mutate-and-reload cycle — this is a gap that must be closed by new tests.

**High risk — ExportCard round-trip correctness after edit**

`ExportCard.from(savedPlay:playNumber:interpreter:)` re-parses `routeDigits` and `formationName` at export time to reconstruct a `PlayCall`. If the update path produces a `SavedPlay` with inconsistent field values (e.g., `formationName` updated but `routeDigits` not, or `conceptName` not re-derived), the exported card renders stale data. This is AC-3.8 and is not covered by any existing test. The export regression test added in Epic 3.1 (`ExportCardTests.testFromSavedPlayWithMotion`) uses a hand-constructed `SavedPlay` and does not exercise the edit-then-export path.

**Medium risk — PlayCallerViewModel reuse for edit surface (depends on OQ-1 resolution)**

If the edit surface re-uses `PlayCallerViewModel` (the likely outcome of OQ-1 resolution), the 24 existing `PlayCallerViewModelTests` are indirectly load-bearing. An edit flow that populates `PlayCallerViewModel` from a `SavedPlay` requires a new initializer path or a `populate(from:)` method. Any such addition must not break `testViewModelInitializesWithDefaultState` or the reset/motion-clearing tests.

**Medium risk — Multi-select delete interacts with Export selection state**

The spec (AC-1.2) adds a Delete button to the bottom bar in Select mode, alongside the existing Export button. Both share the same selection set. If deletion clears selection state differently than export does, or if the delete confirmation path does not restore selection cleanly on Cancel, the Export button could become active with no plays selected. This is a UI-state regression that existing tests do not cover (no UI tests exist; risk is design-level).

**Low risk — Delete All when library is empty (AC-2.1)**

The spec requires Delete All be hidden or disabled when the library is empty. `PlayLibraryStore.deleteAll()` already exists and works on an empty array without error. The risk is purely at the view-binding layer (the control must not be tappable). No new store logic is needed; the test guard is that `deleteAll()` on an empty store results in an empty store with no file-write side effects. This is covered partially by `testDeleteAll` but not the empty-on-empty case.

### 1.2 Existing Test Files That Must Remain Green

All files in `SpartansPlaycallerTests/`. The ones carrying material regression risk for this feature:

| File | Risk for this feature | Reason |
|------|-----------------------|--------|
| `PlayLibraryStoreTests.swift` | **HIGH** | Directly tests the store; update method is added here |
| `LibraryPersistenceIntegrationTests.swift` | **HIGH** | Round-trip across reinit; must survive update path |
| `SavedPlayCodableTests.swift` | **HIGH** | `SavedPlay` struct; if `update` changes field mutability, encoding/decoding must still round-trip |
| `ExportCardTests.swift` | **HIGH** | `from(savedPlay:...)` factory; edit-then-export correctness |
| `WristbandPDFGeneratorTests.swift` | Medium | Calls `ExportCard`; any change to `ExportCard` construction affects this |
| `CatalogPDFGeneratorTests.swift` | Medium | Same reason as above |
| `PlayCallerViewModelTests.swift` | Medium | If edit surface reuses ViewModel, all 24 tests must stay green |
| `RouteInterpreterTests.swift` | Low | Re-interpretation during edit validation must not regress parsing |

All other test files (`DiagramRenderer*`, `Y_Wheel*`, `ReceiverMotion*`, `ConceptMatcherTests`, `RouteSemanticProviderTests`) carry low regression risk because this feature does not touch rendering geometry or route semantic logic.

---

## 2. New Test Cases — By Acceptance Criterion

Test cases are described at the intent level. Test code is not included in this strategy document.

### Story 1 — Delete a Single Play

#### AC-1.1: Delete via swipe with confirmation

- **testDeleteViaSwiping_confirming_removesPlay**: Save two plays to a temp-URL store. Call `delete(at: IndexSet([0]))`. Assert count is 1 and the remaining play has the correct `routeDigits`. (Unit — `PlayLibraryStoreTests`)
- **testDeleteViaSwiping_confirming_persistsRemoval**: Save one play, delete it, reinitialize store from same URL. Assert `plays.isEmpty`. (Integration — `LibraryPersistenceIntegrationTests` or new file)
- **testDeleteViaSwiping_canceling_leavesPlayUnchanged**: UI-level intent — no automated test; covered by developer verification. Document as manual check.

#### AC-1.2: Delete via Select mode

- **testDeleteSelectedMultiple_removesAllSelectedPlays**: Save three plays, call `delete(at: IndexSet([0, 2]))`. Assert count is 1 and remaining play is the one at index 1. (Unit — `PlayLibraryStoreTests`)
- **testDeleteSelected_confirmationCount_matchesSelectionSize**: Behavioral assertion that the count message is correct — this is a ViewModel-level or view-level concern if a `LibraryViewModel` or similar is added. Define test when architecture spec confirms the type. (Unit — ViewModel layer, TBD)

#### AC-1.3: Persistence after single delete

- **testDeletePersistedAcrossReinit**: Save two plays, delete the first, reinit store, assert only the second play is present with matching `routeDigits` and `id`. (Integration — `LibraryPersistenceIntegrationTests`)

#### AC-1.4: Empty state after last play deleted

- **testDeleteLastPlay_storeIsEmpty**: Save one play, delete it. Assert `plays.isEmpty` and file exists (not deleted from disk — store writes empty array). (Unit — `PlayLibraryStoreTests`)
- **testDeleteLastPlay_persistedEmptyAcrossReinit**: Same setup, then reinit store. Assert `plays.isEmpty`. (Integration)

#### AC-1.5: No undo

- No automated test required. The absence of an undo action is a design constraint enforced by what is not built. Verify by inspection during SDET execution.

---

### Story 2 — Delete All

#### AC-2.1: Delete All control hidden/disabled when empty

- **testDeleteAll_alreadyEmpty_storeRemainsEmpty**: Call `deleteAll()` on a store with no plays. Assert `plays.isEmpty` and no crash. (Unit — `PlayLibraryStoreTests`)
- UI visibility of the control when empty is a manual check or SwiftUI snapshot check (out of automated scope unless ViewInspector is adopted).

#### AC-2.2: Confirmation required

- Manual/design check. Automated tests cover the outcome (`deleteAll()` result), not the confirmation dialog presentation.

#### AC-2.3: Delete All outcome — list and persistence

- **testDeleteAll_removesAllPlays**: Save three plays, call `deleteAll()`. Assert `plays.isEmpty`. (Unit — already partially covered by `testDeleteAll` in `PlayLibraryStoreTests`, but that test saves 2 plays; extend to 3+ for completeness)
- **testDeleteAll_persistsEmptyAcrossReinit**: Save three plays, call `deleteAll()`, reinit store. Assert `plays.isEmpty`. (Integration — `LibraryPersistenceIntegrationTests`)

#### AC-2.4: Persistence after Delete All

Covered by `testDeleteAll_persistsEmptyAcrossReinit` above.

#### AC-2.5: Delete All independent of Select mode

- No automated test required. This is a UI affordance constraint. Verify by design inspection.

---

### Story 3 — Edit an Existing Play

#### AC-3.1: Edit entry point

- UI affordance; manual check. No automated test at the unit or integration layer.

#### AC-3.2: Editable fields

- **testUpdatePlay_formation_updatesFormationName**: Create a store with one play (Twins, "6794"). Call `update` with a new `SavedPlay` having formation "Trips Left". Assert `plays[0].formationName == "Trips Left"`. (Unit — `PlayLibraryStoreTests`, requires `update` method to exist)
- **testUpdatePlay_routeDigits_updatesDigits**: Same pattern, change `routeDigits`. (Unit)
- **testUpdatePlay_motionLabel_updatesLabel**: Same pattern, change `motionLabel`. (Unit)
- **testUpdatePlay_yWheelEnabled_updatesToggle**: Same pattern, toggle `yWheelEnabled`. (Unit)
- **testUpdatePlay_conceptName_derivedNotDirectInput**: After updating formation + digits, assert that `conceptName` on the resulting `SavedPlay` reflects the new combination as re-derived by `ConceptMatcher` — not a leftover stale value from the pre-edit play. (Integration — requires the `update` implementation to re-run concept matching; test verifies the result)

#### AC-3.3: Validation before save

- **testEditValidation_invalidDigits_doesNotCallUpdate**: When the edit surface has invalid route digits for the selected formation, the Save action must be blocked. This is a ViewModel-layer concern (if a dedicated `EditPlayViewModel` or `PlayCallerViewModel` reuse is confirmed). Define test cases:
  - Too few digits for formation (e.g., 3 digits for Twins which requires 4)
  - Non-digit characters
  - Empty string
  - Assert that `update` is never called and an error message is available.
  (Unit — ViewModel layer, TBD pending architecture spec)
- **testRouteInterpreter_rejectsInvalidDigitsForFormation**: Verify that `RouteInterpreter.interpret()` returns `.failure` for known invalid inputs. This covers the validation engine; the edit VM test above covers the UI flow. (Unit — can extend `RouteInterpreterTests`)

#### AC-3.4: Save updates in-place, preserves position, updates savedAt

- **testUpdatePlay_preservesPosition**: Save three plays with distinct digits. Call `update` on index 1. Assert plays[0] and plays[2] are unchanged, plays[1] has the new values. (Unit — `PlayLibraryStoreTests`)
- **testUpdatePlay_preservesOriginalID**: Call `update` with a modified `SavedPlay` that has the same `id` as the original. Assert `plays[index].id` is unchanged. (Unit)
- **testUpdatePlay_updatedSavedAtTimestamp**: Call `update`. Assert `plays[index].savedAt` is strictly greater than the `savedAt` from before the update. (Unit — requires the `update` implementation to write a fresh `Date()`; test controls time via a before/after inequality, no clock mocking required)

#### AC-3.5: Derived concept re-evaluated after save

- **testUpdatePlay_conceptReevaluated_matchingCombination**: Update a play to a formation+digit combination that maps to a known concept (e.g., Twins "6794" → Smash). Assert `plays[index].conceptName == "Smash"`. (Integration — `PlayLibraryStoreTests` or a dedicated edit integration test)
- **testUpdatePlay_conceptReevaluated_noMatchYieldsNil**: Update a play to a combination with no named concept. Assert `plays[index].conceptName == nil`. (Integration)

#### AC-3.6: Discard

- Manual check (discard path is UI navigation; no unit-testable logic unless a `discardEdit()` method is added to the ViewModel).

#### AC-3.7: Persistence of edit across relaunch

- **testUpdatePlay_persistsAcrossReinit**: Save one play, call `update` with changed digits, reinit store from same URL. Assert `plays[0].routeDigits` matches the updated value. (Integration — `LibraryPersistenceIntegrationTests`)
- **testUpdatePlay_originalNotPresent_afterReinit**: Same setup. Assert the pre-edit `routeDigits` value is NOT present in `plays[0]`. (Integration)

#### AC-3.8: Export consistency after edit

- **testEditThenExport_cardReflectsUpdatedValues**: Save a play (Twins, "6794"). Update it (Trips Left, "2943", motion: stop). Call `ExportCard.from(savedPlay:playNumber:interpreter:)` on the updated `SavedPlay`. Assert `card.formationName == "Trips Left"`, `card.routeDigits == "2943"`, `card.motionLabel == "Y Stop"`. (Integration — `ExportCardTests`)
- **testEditThenExport_preEditValuesNotPresent**: Same setup. Assert `card.formationName != "Twins"` and `card.routeDigits != "6794"`. (Integration — guards against stale data being sourced from a cached or pre-edit value)
- **testEditThenExport_conceptReflectsNewCombination**: Update a play such that the new formation+digits match a known concept. Assert `card.conceptName` equals the expected concept name, not the pre-edit value. (Integration)

---

## 3. Test Pyramid Balance

### Recommendation

| Layer | Scope | Volume | Rationale |
|-------|-------|--------|-----------|
| Unit — `PlayLibraryStore` | `update`, `delete(at:)`, `deleteAll` on temp-URL stores | ~15 tests | The store is the only durable mutation surface. Every behavioral contract (position preservation, id preservation, timestamp update, empty-state outcomes) must be verified here before any integration layer is tested. |
| Unit — Validation engine | `RouteInterpreter` rejection of invalid inputs; ViewModel error-state when digits are invalid | ~5 tests | Validation is pure logic; testing it at the unit layer is cheaper and faster than testing it through an edit surface. |
| Unit — `SavedPlay` codability | Ensure the struct round-trips cleanly when a `conceptName` changes on update | ~3 tests | Extend `SavedPlayCodableTests` rather than add a new file. |
| Integration — Persistence round-trip | Edit + reinit, multi-play delete + reinit, delete-all + reinit | ~6 tests | Validates that `persist()` + `load()` survive each new mutation path; these are the highest-value tests in the feature because they catch the class of bug where in-memory state is correct but the file is not updated. |
| Integration — Export after edit | `ExportCard.from(savedPlay:...)` produces correct values after an update | ~3 tests | AC-3.8 is the highest-risk cross-layer concern. Testing it at the integration layer (no UI required) gives direct coverage without the cost of E2E. |
| UI / E2E | None automated | 0 | No XCUITest or ViewInspector infrastructure exists in this project. The feature does not require a new UI testing layer. Manual verification covers confirmation dialogs, swipe gesture discoverability, and empty-state rendering. |

**Summary:** ~32 new tests, all unit or integration. No new UI automation layer. This balance matches the project's existing pattern (the entire test suite is unit + integration; no XCUITest files exist).

---

## 4. Test Environment Prerequisites

- **Temp file URL isolation**: Every test that instantiates `PlayLibraryStore` must supply a `UUID()`-namespaced temp URL (pattern: `FileManager.default.temporaryDirectory.appendingPathComponent("test-\(UUID()).json")`). This is the established pattern in `PlayLibraryStoreTests` and `LibraryPersistenceIntegrationTests` and must be followed in all new test files.
- **`@MainActor` annotation**: Any test class that calls methods on `PlayLibraryStore` or any `@MainActor`-isolated type added by this feature (e.g., `EditPlayViewModel`) must be annotated `@MainActor` at the class level. This is a hard project rule documented in `.claude/rules/project-process.md`. SDET must verify this annotation on all generated test files before accepting implementation as complete.
- **`tearDown` cleanup**: Every test class that creates a temp file URL must delete the file in `tearDown` via `try? FileManager.default.removeItem(at: tempURL)`. Failure to do so accumulates temp files in the simulator and can interfere with subsequent runs.
- **Simulator target**: iOS 17.0+ simulator. Tests exercise file I/O via `FileManager`; the `.completeFileProtection` write option is accepted on simulator (does not fail) but the protection attribute is not enforced. This is a known and documented limitation in `testPersistUsesCompleteFileProtection` — no new tests need to work around it.
- **Xcode project registration**: Any new test file must be registered in `SpartansPlaycaller.xcodeproj/project.pbxproj` before running `xcodebuild test`. Writing a file to disk without registration causes it to be silently excluded from the test run. This is a project process rule; SDET must verify registration as part of the verification gate.
- **No network or background queue dependencies**: `PlayLibraryStore` is synchronous on `@MainActor`; no `XCTestExpectation` or `await` is needed for store-level unit tests. If the edit surface ViewModel introduces async validation (e.g., route parsing on a background actor), test cases for that layer will require `async/await` test methods or `XCTestExpectation`.
- **Disk space**: Before running `xcodebuild test` and before `git push`, verify disk space per the project process rule. DerivedData from a full build can consume several GB.

---

## 5. Acceptance Criteria Mapping

| AC ID | Test Case Name | Test Type | File |
|-------|---------------|-----------|------|
| AC-1.1 (swipe confirm) | `testDeleteViaSwiping_confirming_removesPlay` | Unit | `PlayLibraryStoreTests` |
| AC-1.1 (persistence) | `testDeleteViaSwiping_confirming_persistsRemoval` | Integration | `LibraryPersistenceIntegrationTests` |
| AC-1.1 (cancel) | Manual verification | Manual | — |
| AC-1.2 (multi-select delete) | `testDeleteSelectedMultiple_removesAllSelectedPlays` | Unit | `PlayLibraryStoreTests` |
| AC-1.2 (count in confirmation) | `testDeleteSelected_confirmationCount_matchesSelectionSize` | Unit | ViewModel layer (TBD) |
| AC-1.3 (persistence) | `testDeletePersistedAcrossReinit` | Integration | `LibraryPersistenceIntegrationTests` |
| AC-1.4 (empty state) | `testDeleteLastPlay_storeIsEmpty` | Unit | `PlayLibraryStoreTests` |
| AC-1.4 (persistence) | `testDeleteLastPlay_persistedEmptyAcrossReinit` | Integration | `LibraryPersistenceIntegrationTests` |
| AC-1.5 (no undo) | Inspection — no undo method added | Design | — |
| AC-2.1 (control disabled) | `testDeleteAll_alreadyEmpty_storeRemainsEmpty` | Unit | `PlayLibraryStoreTests` |
| AC-2.1 (UI visibility) | Manual verification | Manual | — |
| AC-2.2 (confirmation) | Manual verification | Manual | — |
| AC-2.3 (removes all) | `testDeleteAll_removesAllPlays` (extend existing) | Unit | `PlayLibraryStoreTests` |
| AC-2.3 (persistence) | `testDeleteAll_persistsEmptyAcrossReinit` | Integration | `LibraryPersistenceIntegrationTests` |
| AC-2.4 | Covered by `testDeleteAll_persistsEmptyAcrossReinit` | Integration | `LibraryPersistenceIntegrationTests` |
| AC-2.5 | Design inspection | Design | — |
| AC-3.1 | Manual verification | Manual | — |
| AC-3.2 (formation) | `testUpdatePlay_formation_updatesFormationName` | Unit | `PlayLibraryStoreTests` |
| AC-3.2 (digits) | `testUpdatePlay_routeDigits_updatesDigits` | Unit | `PlayLibraryStoreTests` |
| AC-3.2 (motion) | `testUpdatePlay_motionLabel_updatesLabel` | Unit | `PlayLibraryStoreTests` |
| AC-3.2 (wheel toggle) | `testUpdatePlay_yWheelEnabled_updatesToggle` | Unit | `PlayLibraryStoreTests` |
| AC-3.2 (concept not direct) | `testUpdatePlay_conceptName_derivedNotDirectInput` | Integration | `PlayLibraryStoreTests` |
| AC-3.3 (invalid digits blocked) | `testEditValidation_invalidDigits_doesNotCallUpdate` | Unit | ViewModel layer (TBD) |
| AC-3.3 (interpreter rejects) | `testRouteInterpreter_rejectsInvalidDigitsForFormation` | Unit | `RouteInterpreterTests` (extend) |
| AC-3.4 (position preserved) | `testUpdatePlay_preservesPosition` | Unit | `PlayLibraryStoreTests` |
| AC-3.4 (id preserved) | `testUpdatePlay_preservesOriginalID` | Unit | `PlayLibraryStoreTests` |
| AC-3.4 (savedAt updated) | `testUpdatePlay_updatedSavedAtTimestamp` | Unit | `PlayLibraryStoreTests` |
| AC-3.5 (concept match) | `testUpdatePlay_conceptReevaluated_matchingCombination` | Integration | `PlayLibraryStoreTests` |
| AC-3.5 (concept nil) | `testUpdatePlay_conceptReevaluated_noMatchYieldsNil` | Integration | `PlayLibraryStoreTests` |
| AC-3.6 (discard) | Manual verification | Manual | — |
| AC-3.7 (persistence) | `testUpdatePlay_persistsAcrossReinit` | Integration | `LibraryPersistenceIntegrationTests` |
| AC-3.7 (original absent) | `testUpdatePlay_originalNotPresent_afterReinit` | Integration | `LibraryPersistenceIntegrationTests` |
| AC-3.8 (export reflects edit) | `testEditThenExport_cardReflectsUpdatedValues` | Integration | `ExportCardTests` |
| AC-3.8 (stale values absent) | `testEditThenExport_preEditValuesNotPresent` | Integration | `ExportCardTests` |
| AC-3.8 (concept in export) | `testEditThenExport_conceptReflectsNewCombination` | Integration | `ExportCardTests` |

**Total automated tests:** ~32 (unit + integration)
**Manual checks:** 7 (confirmation dialogs, swipe cancel, discard, UI control visibility, AC-2.5, AC-3.1, AC-1.5 absence verification)

---

## 6. Edge Cases

### 6.1 Empty Library

- `deleteAll()` on an empty store must not crash and must produce an empty array. Test: `testDeleteAll_alreadyEmpty_storeRemainsEmpty`.
- `delete(at: IndexSet([0]))` on an empty store will crash with an out-of-bounds access unless the calling layer guards the action. This is a design-level gate (the swipe action should not be available on an empty list), but a defensive store test is recommended: `testDeleteAtOffsets_emptyStore_crashGuard` — call `delete(at:)` with an empty `IndexSet` and assert nothing changes. Calling with a non-empty `IndexSet` on an empty store is undefined; document as a caller precondition, not a store postcondition.

### 6.2 Single-Item Library

- Delete the only play: covered by `testDeleteLastPlay_storeIsEmpty` and `testDeleteLastPlay_persistedEmptyAcrossReinit`.
- Edit the only play: covered by `testUpdatePlay_preservesPosition` (degenerate case: one play at index 0).

### 6.3 Concurrent Edit and Delete (Not applicable in this slice)

`PlayLibraryStore` is `@MainActor`-isolated. All mutations are serialized on the main actor. There is no concurrent mutation risk within the app's current architecture. No concurrency-specific test is needed. If a background sync feature is introduced in a future slice, this assessment must be revisited.

### 6.4 Cancel Flows

- Cancel on swipe-delete confirmation: play must be present with unchanged values. Manual check; no unit-testable logic (the cancellation does not call `delete(at:)` at all).
- Cancel on Delete All confirmation: plays must be unchanged. Manual check; same reasoning.
- Cancel on multi-select delete: selection must be intact, no plays removed. Manual check.
- Discard on edit: play must be unchanged. Manual check; the ViewModel's dirty-state management is the implementation concern. If a `hasUnsavedChanges` property is added to the edit ViewModel, add a unit test: `testDiscardEdit_doesNotCallUpdate`.

### 6.5 Edit with No Changes

- A coach opens the edit surface, makes no changes, and taps Save. The `update` call should be a no-op equivalent: the play replaces itself with identical field values except `savedAt`. Test: `testUpdatePlay_noFieldChanges_stillUpdatedSavedAt` — assert that `savedAt` advances even when all other fields are identical. This guards against an optimization that skips `persist()` when fields look unchanged (which would be incorrect per AC-3.4).

### 6.6 Edit Produces Digit String Valid for New Formation but Invalid for Original

The edit surface allows changing formation and digits independently. A digit string valid for Trips Right (5 digits with H) may not be valid for Twins (4 digits minimum). If formation is changed before digits, or if digits are not revalidated after a formation change on the edit surface, a stale validation pass could allow a save that produces a `SavedPlay` whose `routeDigits` cannot be re-parsed at export time. Test: `testEditValidation_digitValidatedAgainstNewFormation_notOriginal` — set up an edit scenario where old formation would accept the old digits, but new formation rejects them, and assert the edit is blocked. (Unit — ViewModel layer, TBD)

### 6.7 Update Index Out of Bounds

The `update(_:at:)` method (or equivalent) will take an array index. If the index is out of bounds (e.g., stale index from a deleted play), the store must not crash. Test: `testUpdatePlay_outOfBoundsIndex_noOp` — if the implementation chooses to be defensive, verify no crash and no mutation. If the design spec chooses to treat this as a caller precondition (assert/fatalError), document it as such. Either way, the behavior must be specified and one test written to capture it.

### 6.8 Large Library (Boundary Condition)

The spec cites 50–200 plays as a realistic library size. No bulk-performance test is needed at this layer (that belongs to the performance assessment). However, a correctness test with a larger fixture is useful: `testUpdatePlay_inLargeLibrary_onlyTargetPlayChanged` — create a store with 50 plays (using a loop with distinct digit strings), update index 25, assert indices 0–24 and 26–49 are unchanged and index 25 has the new values. This catches any `update` implementation that inadvertently affects siblings (e.g., a bug in filter-then-reassign vs index-based mutation).

---

## 7. Open Architecture Dependencies

The following test case definitions are marked TBD pending resolution of spec open questions and the architecture-system-design output:

| Open question | Blocked test cases | Unblocking condition |
|---------------|--------------------|----------------------|
| OQ-1: Edit surface pattern (reuse PlayCallerViewModel vs new EditPlayViewModel) | `testEditValidation_*`, `testDiscardEdit_doesNotCallUpdate`, `testEditValidation_digitValidatedAgainstNewFormation_notOriginal`, `testDeleteSelected_confirmationCount_*` | Architecture spec resolves OQ-1 and names the ViewModel type |
| OQ-4: Position preservation confirmed vs end-of-list append | `testUpdatePlay_preservesPosition` — if append is chosen, this test inverts | Architecture spec or Ken confirms AC-3.4 intent |
| Architecture spec: does `update` run concept re-matching inside the store or in the caller? | `testUpdatePlay_conceptName_derivedNotDirectInput`, `testUpdatePlay_conceptReevaluated_*` | Architecture spec specifies where concept re-evaluation lives |

These TBDs do not block writing the non-ViewModel tests. The store-layer tests (`PlayLibraryStoreTests`) and persistence integration tests (`LibraryPersistenceIntegrationTests`) can be written and run as soon as `PlayLibraryStore.update(_:at:)` exists, regardless of OQ-1 resolution.

---

## 8. SDET Execution Verification Gate

At Step 7 (Feature Addition template), the SDET execution is not complete until:

1. All ~32 automated tests pass with `xcodebuild test -scheme SpartansPlaycaller -destination 'platform=iOS Simulator,name=iPhone 16'`.
2. All existing 27 test files remain green (zero regressions).
3. All new test files are registered in `project.pbxproj` and confirmed compiled by the test run (no silent exclusions).
4. All new test classes that instantiate `PlayLibraryStore` or any `@MainActor` type carry the `@MainActor` class annotation.
5. Manual checks (7 items listed in Section 5) are verified by SDET and outcomes documented in the test results report.
6. Test results written to `docs/test-plans/library-edit-delete-test-results.md`.
