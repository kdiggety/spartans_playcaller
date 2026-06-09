# Design Spec: Play Library Edit, Delete, and Delete All

**Feature:** library-edit-delete  
**Status:** Draft  
**Author:** architecture-system-design  
**Date:** 2026-06-08  
**Spec reference:** `docs/superpowers/specs/library-edit-delete-spec.md`  
**UX reference:** `docs/superpowers/specs/library-edit-delete-ux.md`  
**Test strategy:** `docs/test-plans/library-edit-delete-test-strategy.md`  
**Performance assessment:** `docs/test-plans/library-edit-delete-performance-assessment.md`  

---

## Mental Model

The Play Library is a single source of truth: one `@MainActor`-isolated class (`PlayLibraryStore`) owns an in-memory `[SavedPlay]` array that is always reflected in `play-library.json`. Every mutation — save, delete, or edit — flows through the store and terminates in `persist()`. This feature adds two new mutation paths (edit-in-place, guarded delete) while preserving that invariant. The edit path introduces one new actor: `EditPlayViewModel`, a lightweight `@MainActor` class that manages transient UI state for the sheet and calls the new `update(_:)` store method when the coach confirms a valid edit. Nothing moves off the main thread; no new concurrency surface is introduced.

---

## 1. Store Layer Changes (`PlayLibraryStore`)

### 1.1 New Method: `update(_:)`

**Signature:**

```swift
func update(_ play: SavedPlay) throws(UpdateError)
```

or, using `Result` to avoid `throws` if the codebase prefers that style:

```swift
@discardableResult
func update(_ play: SavedPlay) -> Result<Void, UpdateError>
```

The `Result`-returning form is recommended because the caller (`EditPlayViewModel.save()`) must surface the error to the UI and the `throws` form requires a `do/catch` at the call site that adds boilerplate with no additional clarity. Either form is acceptable; the implementation must be consistent across callers.

**Associated error type:**

```swift
enum UpdateError: LocalizedError {
    case playNotFound(UUID)
    case invalidRouteDigits(String)       // RouteInterpreter rejection message
    case persistenceFailed(Error)
}
```

`LocalizedError` conformance on `UpdateError` means SwiftUI's `Alert` can display `error.localizedDescription` without formatting in the view layer.

### 1.2 Semantics

The method performs the following steps in order. No step is skipped.

**Step 1 — UUID-based index resolution.**  
The method receives a `SavedPlay` value (by value, not an index). It searches `plays` for the element whose `id` matches `play.id`:

```
guard let index = plays.firstIndex(where: { $0.id == play.id }) else {
    return .failure(.playNotFound(play.id))
}
```

This is the only safe lookup strategy. The edit sheet may have been open while another operation (e.g., a rapid second save from `PlayCallerView`) appended an item and shifted indices. UUID lookup at save time — not at sheet open time — guarantees the correct element is targeted regardless of index drift.

**Step 2 — Validation gate.**  
Before any mutation, the method calls `RouteInterpreter.interpret(digits:formation:)` on the edited `routeDigits` and `formationName`. It must resolve `formationName` back to a `Formation` enum value. If `Formation(rawValue: play.formationName)` returns `nil` (formation string is corrupted or unrecognized), treat this as a validation failure.

```
guard let formation = Formation(rawValue: play.formationName) else {
    return .failure(.invalidRouteDigits("Unknown formation: \(play.formationName)"))
}
switch RouteInterpreter().interpret(digits: play.routeDigits, formation: formation) {
case .failure(let e): return .failure(.invalidRouteDigits(e.localizedDescription))
case .success(let playCall): /* proceed with playCall for concept re-derivation */
}
```

This gate is the store's second line of defense. The UI layer (see Section 2) enforces validation before allowing a Save tap; the store enforces it again regardless of caller. This matches the security check requirement (Security Check 1) and means the contract holds even if `update()` is called from a future code path that bypasses the UI.

**Step 3 — Concept re-derivation.**  
The `RouteInterpreter.interpret()` call in Step 2 returns a `PlayCall` carrying the newly matched `concept`. Use `playCall.concept?.rawValue` as the `conceptName` for the updated `SavedPlay`. Do not copy `conceptName` from the incoming `play` value — it reflects pre-edit state.

**Step 4 — Produce updated `SavedPlay`.**  
Construct a replacement value preserving the original `id` and updating `savedAt` to `Date()`:

```
let updated = SavedPlay(
    id: play.id,                          // identity preserved
    savedAt: Date(),                      // timestamp updated (AC-3.4)
    formationName: play.formationName,    // from Formation enum rawValue
    routeDigits: play.routeDigits,        // validated in Step 2
    conceptName: playCall.concept?.rawValue,  // re-derived in Step 3
    motionLabel: play.motionLabel,        // ReceiverMotion.rawValue (closed enum)
    yWheelEnabled: play.yWheelEnabled
)
```

Only `routeDigits` is freeform user input. `formationName` must originate from `Formation.rawValue` (closed enum) and `motionLabel` from `ReceiverMotion.rawValue` (closed enum). The edit view must enforce these sources; the store trusts them because the UI layer uses the enum pickers.

**Step 5 — Array mutation.**  
Replace in-place at the resolved index:

```
plays[index] = updated
```

This is an O(1) operation. The `@Published` property wrapper triggers a `willSet`/`didSet` notification that drives SwiftUI list diffing.

**Step 6 — Persist.**  
Call `persist()`. If `persist()` throws, do not silently swallow the error. Return `.failure(.persistenceFailed(error))` so the caller can surface it to the UI.

**Current behavior:** `persist()` is private and swallows its own error via `print`. For the edit path, the caller needs to know whether the write succeeded. Options:

- Make `persist()` throw (propagate to callers) — clean but requires updating `save()` and `delete()` callers too.
- Introduce a `persistReturning() -> Error?` variant used only by `update()` — avoids touching existing callers.

**Recommendation:** Promote `persist()` to `throws` and update all call sites (`save()`, `delete(at:)`, `deleteAll()`) to propagate or log the error consistently. This is a small LOE change that closes the silent-failure gap identified by both security-engineer and the SDET strategy. The existing callers can log and continue (no behavior change for them); `update()` can additionally return the error to the UI. If this scope feels too broad for this slice, the targeted `persistReturning()` variant is acceptable with a backlog entry to promote `persist()` to `throws` in a later pass.

### 1.3 `savedAt` Update Policy

`savedAt` is always updated to `Date()` when `update()` is called, even if all other fields are identical to the original (the no-field-change case). This is required by AC-3.4 and confirmed by the SDET test strategy (see `testUpdatePlay_noFieldChanges_stillUpdatedSavedAt`). The timestamp communicates "last modified" rather than "created", and the spec does not use `savedAt` as a sort key, so updating it is safe.

### 1.4 `SavedPlay` Struct Mutability

`SavedPlay` is currently a fully immutable struct (`all let`). The `update()` method does not require changing field mutability — it produces a new `SavedPlay` value. No field on `SavedPlay` needs to change to `var`. The struct's `Codable` conformance is unaffected.

---

## 2. View Layer Design

### 2.1 `EditPlayViewModel`

A new dedicated `@MainActor final class EditPlayViewModel: ObservableObject` is required. Reusing `PlayCallerViewModel` is explicitly rejected (see Section 5). The edit ViewModel is lightweight and single-purpose.

**State:**

```
@Published var selectedFormation: Formation          // mutable; initialized from SavedPlay
@Published var routeDigitInput: String               // mutable; initialized from SavedPlay
@Published var selectedMotion: ReceiverMotion?       // mutable; nil if motionLabel was nil
@Published var yWheelEnabled: Bool                   // mutable; initialized from SavedPlay
@Published var validationError: String?              // nil when input is valid
@Published var persistError: String?                 // nil unless last save failed
var isDirty: Bool                                    // computed or tracked; drives Cancel prompt
```

`isDirty` tracks whether any field differs from the original `SavedPlay` loaded at init. It is used to decide whether to show the "Discard Changes?" confirmation when the coach taps Cancel. Compute `isDirty` as a comparison against stored original values (four fields: formation, digits, motion, wheel) rather than a flag that fires on any `@Published` change, because a coach who changes a field and then changes it back should not see the discard prompt.

**Initialization:**

```swift
init(play: SavedPlay) {
    // Resolve Formation from rawValue; fall back to .twins if unrecognized
    self.selectedFormation = Formation(rawValue: play.formationName) ?? .twins
    self.routeDigitInput = play.routeDigits
    self.selectedMotion = play.motionLabel.flatMap(ReceiverMotion.init(rawValue:))
    self.yWheelEnabled = play.yWheelEnabled
    self._original = play  // stored for isDirty comparison and UUID passthrough
}
```

**`save(to store:)` method:**

1. Construct a candidate `SavedPlay` from current field values. `formationName` is `selectedFormation.rawValue`. `motionLabel` is `selectedMotion?.rawValue`. `routeDigits` is `routeDigitInput.trimmingCharacters(in: .whitespaces)`. Preserve the original `id`; set `savedAt` to `Date()` (though `update()` in the store will also stamp `Date()` — the store's stamp is the canonical one).
2. Call `store.update(candidate)`.
3. On `.failure(.invalidRouteDigits(let msg))`: set `validationError = msg`. Do not dismiss.
4. On `.failure(.playNotFound)`: set `persistError = "Play no longer exists. It may have been deleted."`. This is a defensive path — should not occur in normal use.
5. On `.failure(.persistenceFailed)`: set `persistError = "Could not save. Your edit was not written to disk."`.
6. On `.success`: signal the sheet to dismiss (via a `@Published var didSave = false` boolean or a `PassthroughSubject<Void, Never>` that the view observes).

**`validateInput()` method (called on formation or digit change, and before Save tap):**

Runs `RouteInterpreter().interpret(digits: routeDigitInput, formation: selectedFormation)` synchronously and sets `validationError` to the error description on failure, or `nil` on success. This provides live feedback as the coach types, matching the existing `PlayCallerView` pattern.

**Formation-change semantics:**

When `selectedFormation` changes in the edit sheet, call `validateInput()` to re-evaluate whether the current `routeDigitInput` is valid for the new formation. Do not clear `routeDigitInput` automatically — the coach may be changing the formation to match their existing digit string. If the new formation invalidates the existing digits, `validationError` will show. The coach can then fix the digits.

### 2.2 `EditPlayView` Sheet

A new SwiftUI `View` struct. It is presented as a `.sheet()` from `PlayLibraryView`, not as a navigation push.

**Structure:**

```
NavigationStack {
    Form {
        Section("Formation") { ... formation pickers (family + side) }
        Section("Route Digits") { ... TextField + live error ... }
        Section("Motion") { ... motion picker, shown when formation supports it }
        Section { ... Y Wheel Toggle }
    }
    .navigationTitle("Edit Play")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { ... } }
        ToolbarItem(placement: .confirmationAction) { Button("Save") { ... } }
    }
}
```

**Error display:**

Validation errors (`viewModel.validationError`) surface using the same error banner pattern as `PlayCallerView` (`errorBanner(_ message:)`, lines 279–290 of `PlayCallerView`). Do not introduce a second error display pattern. The banner appears inline in the form above the route digits field.

Persistence errors (`viewModel.persistError`) surface as a separate `.alert()` with title "Save Failed" so they are not confused with validation errors (which the coach can correct by changing inputs). Persistence errors require the coach to acknowledge and retry or cancel.

**Save button state:**

The Save button is enabled when `viewModel.validationError == nil` and `routeDigitInput` is non-empty. It is disabled (greyed out) otherwise. This matches the UX recommendation and provides faster feedback than waiting for a tap to reveal the error.

**Cancel behavior:**

- `isDirty == false`: dismiss immediately, no prompt.
- `isDirty == true`: present a SwiftUI `Alert` (not `confirmationDialog`, per UX guidance — this is a binary choice):
  - Title: "Discard Changes?"
  - Buttons: "Discard Changes" (`.destructive`) | "Keep Editing" (`.cancel`)

### 2.3 `PlayLibraryView` Changes

**Replace `onDelete` with `.swipeActions`:**

The existing `.onDelete { offsets in store.delete(at: offsets) }` on the `ForEach` fires immediately with no guard. Replace it with a `.swipeActions(edge: .trailing)` modifier on each row. Trailing actions (right edge swipe) expose two buttons in order: Edit (blue, outer), Delete (red, inner). The Delete button does not call the store — it sets a state variable to trigger an Alert.

Delete confirmation state lives in `PlayLibraryView` (not in the row):

```swift
@State private var playPendingDelete: SavedPlay? = nil
```

When the Delete swipe button is tapped, set `playPendingDelete = play`. An `.alert(item: $playPendingDelete)` modifier triggers the confirmation dialog. Confirming calls `store.delete(at:)` by UUID lookup (see below). Canceling sets `playPendingDelete = nil`.

**UUID-based delete from swipe:**

The store's existing `delete(at: IndexSet)` method is index-based. For swipe-delete from the new `.swipeActions` path, look up the index by UUID before calling delete:

```swift
if let index = store.plays.firstIndex(where: { $0.id == play.id }) {
    store.delete(at: IndexSet([index]))
}
```

This is a view-layer pattern consistent with UUID-based identity. An alternative — adding a `delete(id: UUID)` method to the store — is cleaner but is a minor scope addition. Either is acceptable; document the choice in the implementation notes.

**Edit entry point from swipe:**

The Edit swipe button sets:

```swift
@State private var playBeingEdited: SavedPlay? = nil
```

Setting `playBeingEdited = play` triggers a `.sheet(item: $playBeingEdited)` that presents `EditPlayView(play: play, store: store)`.

**Delete in Select mode:**

The Select mode bottom bar currently shows `[ Select All ]` and `[ Export N ]`. Add `[ Delete N ]` between them, per the UX bottom bar layout. The Delete button is disabled when `selectedIDs.isEmpty`. Tapping it sets:

```swift
@State private var showMultiDeleteConfirmation: Bool = false
```

The alert presents "Delete N Play(s)?" with count. Confirming calls a new helper that looks up indices for all selected UUIDs and calls `store.delete(at: IndexSet(...))`. After deletion, exit Select mode and clear `selectedIDs`.

**Toolbar Menu for Delete All:**

Add a second trailing toolbar item: a `Menu` using `Label("More", systemImage: "ellipsis")` (or `Image(systemName: "ellipsis")` if label-only is preferred). This item is hidden when `store.plays.isEmpty` or when `isSelectMode == true`. The menu contains one item: "Delete All Plays" with `.destructive` role. Tapping it sets:

```swift
@State private var showDeleteAllConfirmation: Bool = false
```

The alert presents "Delete All N Plays? This cannot be undone." Confirming calls `store.deleteAll()`. After deletion, hide the menu (driven by `store.plays.isEmpty` binding).

**Toolbar layout in non-select mode (updated):**

```
[ Done ]    Play Library    [ Select ] [ ... ]
```

The `...` menu appears as the second trailing item. With two trailing items, test at Dynamic Type XXL that the layout does not clip the title.

---

## 3. Navigation and State Flow

### 3.1 Edit Sheet Trigger and Dismissal

The edit sheet is triggered by the Edit swipe action on a `PlayLibraryRow`. `PlayLibraryView` owns `@State private var playBeingEdited: SavedPlay?`. Setting this non-nil presents the sheet; setting it nil (or the sheet's intrinsic dismiss) closes it.

`EditPlayView` receives the `SavedPlay` by value (a snapshot at the moment of tap) and the `PlayLibraryStore` as a parameter (or via `@EnvironmentObject`). The store environment object is already available in `PlayLibraryView`'s environment.

Dismissal happens in two cases:
1. The coach taps Cancel with `isDirty == false` — `EditPlayView` calls `dismiss()` directly.
2. The coach confirms "Discard Changes" — same.
3. The coach taps Save and `viewModel.save(to:)` returns `.success` — the view observes `viewModel.didSave` and calls `dismiss()`.

### 3.2 State Ownership

**`PlayLibraryView` owns all library-level interaction state:**

| State variable | Type | Purpose |
|---|---|---|
| `isSelectMode` | `Bool` | Already exists |
| `selectedIDs` | `Set<UUID>` | Already exists |
| `playBeingEdited` | `SavedPlay?` | New: triggers edit sheet |
| `playPendingDelete` | `SavedPlay?` | New: triggers single-delete alert |
| `showMultiDeleteConfirmation` | `Bool` | New: triggers multi-select delete alert |
| `showDeleteAllConfirmation` | `Bool` | New: triggers delete-all alert |

**`EditPlayViewModel` owns all edit-in-progress state.** No edit state leaks into `PlayLibraryView`. `PlayLibraryView` only knows that an edit is "in progress" by checking `playBeingEdited != nil`.

**`PlayLibraryStore` owns persisted truth.** After a successful edit, `store.plays[index]` reflects the updated value and `PlayLibraryView`'s `ForEach(store.plays)` re-renders automatically via `@Published`.

### 3.3 Cancel vs Save

| Coach action | `isDirty` | Result |
|---|---|---|
| Open edit, tap Cancel | false | Immediate dismiss. Store unchanged. |
| Open edit, change a field, tap Cancel | true | "Discard Changes?" alert. "Discard": dismiss, store unchanged. "Keep Editing": return to sheet. |
| Open edit, change a field, tap Save (valid input) | true | Validation passes. Store updated. Sheet dismissed. |
| Open edit, change a field, tap Save (invalid input) | true | Validation error shown inline. Sheet stays open. |
| Open edit, change a field back to original, tap Cancel | false | Immediate dismiss. `isDirty` is computed comparison, not a set flag. |

The last row is important: a coach who opens Edit, changes formation from Twins to Pro Right, then changes it back to Twins should not see the discard prompt. `isDirty` must be a comparison against `_original`, not a boolean set on any change.

---

## 4. Data Flow Diagram

### 4.1 Edit Path

```
Coach taps Edit on a PlayLibraryRow
        │
        ▼
PlayLibraryView sets playBeingEdited = play (SavedPlay snapshot by value)
        │
        ▼
.sheet(item: $playBeingEdited) presents EditPlayView(play:, store:)
        │
        ▼
EditPlayViewModel init(play:)
  - selectedFormation = Formation(rawValue: play.formationName) ?? .twins
  - routeDigitInput = play.routeDigits
  - selectedMotion = ReceiverMotion(rawValue: play.motionLabel)
  - yWheelEnabled = play.yWheelEnabled
  - _original = play (for isDirty, UUID passthrough)
        │
        ▼
Coach edits fields (formation picker, digit field, motion picker, wheel toggle)
        │
        ▼ (on each digit/formation change)
EditPlayViewModel.validateInput()
  → RouteInterpreter.interpret(digits:, formation:)
  → sets validationError (nil = valid, String = error message)
        │
        ▼
Coach taps Save (button enabled only when validationError == nil)
        │
        ▼
EditPlayViewModel.save(to: store)
  1. Construct candidate SavedPlay(id: original.id, savedAt: Date(), ...)
  2. store.update(candidate)
        │
        ├── Step 1: UUID lookup → plays.firstIndex(where: { $0.id == candidate.id })
        │     └── not found → .failure(.playNotFound) → persistError shown, sheet stays
        │
        ├── Step 2: Validation → RouteInterpreter.interpret(digits:, formation:)
        │     └── failure → .failure(.invalidRouteDigits) → validationError shown, sheet stays
        │
        ├── Step 3: Concept re-derivation from playCall.concept
        │
        ├── Step 4: Build updated = SavedPlay(id: original.id, savedAt: Date(), ..., conceptName: re-derived)
        │
        ├── Step 5: plays[index] = updated  (@Published triggers list re-render)
        │
        └── Step 6: persist()
              ├── success → return .success
              └── failure → return .failure(.persistenceFailed)
        │
        ▼ (on .success)
viewModel.didSave = true
EditPlayView observes didSave → dismiss()
PlayLibraryView receives didSet on playBeingEdited → nil
List re-renders from store.plays (now reflects updated play at same position)
```

### 4.2 Swipe Delete Path

```
Coach swipes left on a PlayLibraryRow
        │
        ▼
.swipeActions reveals [ Edit (blue) ] [ Delete (red) ]
        │ (coach taps Delete)
        ▼
PlayLibraryView.playPendingDelete = play
        │
        ▼
.alert(item: $playPendingDelete) presents:
  "Delete Play?"
  "[Formation] [RouteDigits]"
  [ Cancel ]  [ Delete (destructive) ]
        │
        ├── Cancel → playPendingDelete = nil, list unchanged
        └── Delete confirmed →
              look up index: plays.firstIndex(where: { $0.id == play.id })
              store.delete(at: IndexSet([index]))
              persist()
              playPendingDelete = nil
              List re-renders (row removed, animation via withAnimation)
```

### 4.3 Delete All Path

```
Coach taps [...] in toolbar
        │
        ▼
Menu shows: "Delete All Plays" (destructive)
        │ (coach taps item)
        ▼
PlayLibraryView.showDeleteAllConfirmation = true
        │
        ▼
.alert presents:
  "Delete All N Plays?"
  "This cannot be undone."
  [ Cancel ]  [ Delete All N Plays (destructive) ]
        │
        ├── Cancel → showDeleteAllConfirmation = false, store unchanged
        └── Delete confirmed →
              store.deleteAll()
              plays = []
              persist()
              List transitions to emptyState view
              [...] toolbar button hidden (store.plays.isEmpty)
```

---

## 5. Alternatives Considered and Rejected

**Edit surface: reuse `PlayCallerView` instead of a dedicated `EditPlayView`.**  
Rejected because `PlayCallerView` is a full `NavigationStack` designed for play creation, not amendment. Seeding its `PlayCallerViewModel` with pre-existing values would require distinguishing "create new" from "save edit" in a ViewModel that has no such concept, and navigating away from the library sheet breaks modal flow. A dedicated sheet matches the iOS Contacts/Calendar pattern and keeps the two concerns cleanly separated. (UX OQ-1)

**Edit surface: reuse `PlayCallerViewModel` inside a new sheet instead of a new `EditPlayViewModel`.**  
Rejected because `PlayCallerViewModel` carries 24 existing tests and complex formation-family-change logic (Twins chip sync, motion-clearing rules, concept re-identification, `saveConfirmed` animation state) that is not relevant to editing a persisted play. Injecting "edit mode" behavior into it risks subtle regression across those 24 tests and muddies the single responsibility. A new `EditPlayViewModel` with a focused, testable interface is lower risk and simpler to verify.

**Delete All placement: standalone persistent toolbar button.**  
Rejected because a permanent "Delete All" button at rest in the toolbar occupies real estate and creates accidental-tap risk alongside everyday controls. A `Menu` (ellipsis) is the iOS-native solution for low-frequency, high-consequence library-level actions and can be extended in future slices without toolbar redesign. (UX OQ-3)

**Position preservation on edit: append-to-end instead of in-place update.**  
Rejected because coaches organize library plays intentionally by formation family, game-plan sequence, or down-and-distance. Silently moving a corrected play to the end of the list after an edit erodes trust in the tool. `plays[index] = updated` is no more complex to implement and satisfies AC-3.4 without qualification. (UX OQ-4)

**UUID-based store lookup: pass index from the view instead.**  
Rejected by security-engineer (Check 2). Passing an array index from the edit sheet to the store is unsafe because the index captured at sheet-open time can drift if any other mutation (a background save, a rapid delete) occurs before the coach taps Save. UUID lookup at save time is a one-liner guard that eliminates this TOCTOU-lite risk. (Security Check 2)

**`persist()` remaining a private void function that swallows errors.**  
Rejected for the edit path by both the security assessment and the SDET strategy. On game day a silent persist failure leaves the coach with an edit that appears saved but reverts on next launch — the worst form of invisible data loss. The `update()` method must be able to propagate persist failures to the UI. The simplest fix is promoting `persist()` to `throws`; the scoped alternative (`persistReturning()`) is acceptable if the broader change is deferred.

**Delete All: accessible only via Select All + Delete in Select mode.**  
Rejected by PO spec (AC-2.5). Select All + Delete requires four taps and implies Select mode as a prerequisite for a distinct action. The spec explicitly requires Delete All to be reachable without entering Select mode.

---

## 6. Residual Risks

### 6.1 Row Re-evaluation on Sheet Dismiss (Performance Watch-Point)

The performance assessment flags one conditional risk: if the `EditPlayView` sheet dismisses and `PlayLibraryView` reconstructs all rows (e.g., because a state change triggers a full view body re-evaluation), and each row re-invokes `RouteInterpreter.interpret()` synchronously, the dismiss animation could stutter at 50+ plays. Under the current `PlayLibraryRow` implementation, rows display only stored `SavedPlay` fields (no interpreter calls at render time), so this risk does not exist today. It becomes a risk only if the row renderer is later enhanced to show derived data (e.g., an assignment preview). Verify with Instruments Time Profiler on device after implementation if the row renderer is changed. Threshold: any dropped frame at 50+ plays in the library.

Trigger to re-assess: `PlayLibraryRow` begins calling `RouteInterpreter` or any non-trivial CPU-bound code during body evaluation.

### 6.2 Silent `persist()` Failure (Data Integrity)

As designed, `persist()` currently swallows errors silently. This spec requires the `update()` path to surface persist failures to the UI. If the implementation defers the broader `persist() throws` promotion and uses the `persistReturning()` scoped approach, the existing `save()`, `delete(at:)`, and `deleteAll()` paths continue to silently swallow errors. This is an accepted residual for this slice and must produce a backlog entry (`docs/backlog/`) with trigger condition: "Promote `persist()` to `throws` across all `PlayLibraryStore` mutation methods." The security-engineer post-implementation review will verify the `update()` path surfaces errors even if the broader promotion is deferred.

### 6.3 SDET TBD Items Pending This Spec

The test strategy identified test cases blocked on architecture decisions. This spec resolves all open questions:

| SDET TBD | Resolution from this spec |
|---|---|
| OQ-1: Edit ViewModel type | `EditPlayViewModel` (new type, not `PlayCallerViewModel`) |
| OQ-4: Position preservation | Index-based update; `testUpdatePlay_preservesPosition` asserts in-place |
| Concept re-evaluation location | Inside `PlayLibraryStore.update()` (Step 3 of the store method semantics) |

Tests blocked on these items are now unblocked. Specifically: `testEditValidation_*`, `testDiscardEdit_doesNotCallUpdate`, `testEditValidation_digitValidatedAgainstNewFormation_notOriginal`, `testDeleteSelected_confirmationCount_*`, `testUpdatePlay_preservesPosition`, `testUpdatePlay_conceptName_derivedNotDirectInput`, `testUpdatePlay_conceptReevaluated_*`.

### 6.4 Two-Level Sheet Risk

The UX recommendation explicitly flags sheets-on-sheets as a navigation anti-pattern to avoid. The design as specified is a single-level sheet: `PlayLibraryView` (a sheet presented from `PlayCallerView`) presents `EditPlayView` (a sheet presented from `PlayLibraryView`). This is technically two levels of modal presentation. On iOS 16.4+ this is supported and stable; on older targets it requires testing for dismiss gesture conflicts. The minimum deployment target is iOS 17.0+, so this is not a concern in practice. Verify that the `EditPlayView` dismiss gesture does not dismiss `PlayLibraryView` simultaneously.

---

## 7. Implementation Task List

The following is an ordered list of implementation units. This is not a full implementation plan (that is the responsibility of the writing-plans step); it is a sequencing guide for the implementing agent.

**Unit 1 — `PlayLibraryStore.update(_:)`**  
Add the `UpdateError` enum and the `update(_:) -> Result<Void, UpdateError>` method to `PlayLibraryStore`. Includes UUID lookup, `RouteInterpreter` validation gate, concept re-derivation, `SavedPlay` construction, array mutation, and persist. This unit is a prerequisite for all other units and for all store-layer tests.

**Unit 2 — `persist()` error propagation**  
Promote `persist()` to `throws` and thread the error into `update()`'s return value. Update `save()`, `delete(at:)`, and `deleteAll()` to either propagate or continue swallowing (with a logged note). The store-layer contract for `update()` depends on this unit.

**Unit 3 — Store-layer unit tests**  
New tests in `PlayLibraryStoreTests` covering `update()`: position preservation, UUID preservation, `savedAt` update, field updates (formation, digits, motion, wheel), concept re-evaluation (match and nil), out-of-bounds UUID guard, large-library correctness. These can be written and run independently of the view layer. Approximately 15 tests.

**Unit 4 — Persistence integration tests**  
New tests in `LibraryPersistenceIntegrationTests` covering the edit-then-reinit round-trip, the export-after-edit path (`ExportCardTests`), and the multi-delete persistence path. Approximately 9 tests.

**Unit 5 — `EditPlayViewModel`**  
New `@MainActor final class EditPlayViewModel`. Includes `init(play:)`, `validateInput()`, `save(to:)`, `isDirty` computation, `didSave` signal, `validationError`, and `persistError`. `@MainActor` class annotation required (project process rule). ViewModel-layer unit tests: `testEditValidation_*`, `testDiscardEdit_doesNotCallUpdate`, `testEditValidation_digitValidatedAgainstNewFormation_notOriginal`.

**Unit 6 — `EditPlayView`**  
New SwiftUI `View` struct. Navigation sheet with formation pickers, route digit field, motion picker, Y Wheel toggle, Save/Cancel toolbar buttons, validation error banner (reuse `errorBanner` pattern from `PlayCallerView`), persist error alert, and Cancel-with-changes alert. No automated tests (UI layer, per test strategy). Manual check items from the SDET strategy apply here.

**Unit 7 — `PlayLibraryView` changes**  
Replace `.onDelete` with `.swipeActions` on `PlayLibraryRow`. Add `playBeingEdited`, `playPendingDelete`, `showMultiDeleteConfirmation`, `showDeleteAllConfirmation` state. Add Edit sheet presentation, delete confirmation alerts, Delete button in Select mode bottom bar, and ellipsis `Menu` in toolbar. Register all state changes per SwiftUI binding patterns. Accessibility labels on swipe actions (project norm).

**Unit 8 — Register new files in `project.pbxproj`**  
`EditPlayViewModel.swift` and `EditPlayView.swift` (and any new test files) must be registered in `SpartansPlaycaller.xcodeproj/project.pbxproj` before `xcodebuild test` is run. This is a hard project process rule documented in `.claude/rules/project-process.md`. Verify by running `xcodebuild test` and confirming zero "file not found" or "unresolved identifier" errors attributable to new files.

**Suggested file locations:**

- `SpartansPlaycaller/ViewModels/EditPlayViewModel.swift`
- `SpartansPlaycaller/Views/EditPlayView.swift`
- `SpartansPlaycallerTests/EditPlayViewModelTests.swift`

---

## 8. Security Involvement Checkpoints

Per the security-engineer involvement assessment, the following specific checks apply to this implementation:

- **Plan review (Step 5.5, before implementation):** Verify that the implementation plan shows `update()` calling `RouteInterpreter.interpret()` before writing to `plays[]`, uses UUID-based identity, surfaces persist failures, does not introduce a user-input-derived file path, and wires confirmation dialogs as modal guards before deletion fires.
- **Post-implementation (Step 9):** Static code review of `update()` method + three targeted active checks: invalid-digit persistence probe, rapid-delete double-tap probe, edit-then-export consistency check. Results at `docs/test-plans/library-edit-delete-security-review.md`.

---

## Hardest Trade-Off and Validation

**Hardest trade-off driven by this spec:** Making `persist()` propagate errors to the `update()` caller (rather than continuing to swallow them) required deciding whether to promote `persist()` globally across all callers or only on the new `update()` path. A global promotion is cleaner and closes a known data-integrity gap, but it widens scope and requires touching three existing callers. The scoped `persistReturning()` approach carries minimal regression risk but adds a code smell and leaves the existing callers silently broken. This spec recommends the global promotion but accepts the scoped approach with a backlog entry if the implementing agent judges the scope too broad.

**What would invalidate this design:** If the library is extended to support iCloud sync, the `@MainActor`-only mutation model and synchronous file write pattern in `PlayLibraryStore` become a bottleneck. At that point, UUID-based identity (already specified here) remains correct, but the persist path needs a background actor and the `update()` return type likely needs to become `async throws`. The design is forward-compatible in identity semantics but not in concurrency model.

**One cheap validation:** Before implementation begins, manually verify that `Formation(rawValue:)` and `ReceiverMotion(rawValue:)` are the only paths used to initialize formation and motion in `SavedPlay.from(playCall:motion:)`. Reading `SavedPlay.swift` (already done) confirms this. Any future code path that writes a `SavedPlay.formationName` from free text rather than a closed enum raw value must go through the interpreter gate — this assumption underpins the security threat model for the edit path.
