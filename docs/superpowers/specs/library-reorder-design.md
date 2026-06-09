# Design Spec: Play Library Reorder

**Feature:** Library Reorder
**Author:** architecture-system-design
**Date:** 2026-06-09
**Status:** Complete — ready for implementation plan
**Spec reference:** `docs/superpowers/specs/library-reorder-spec.md`
**UX reference:** `docs/superpowers/specs/library-reorder-ux.md`
**Test strategy:** `docs/test-plans/library-reorder-test-strategy.md`
**Performance assessment:** `docs/test-plans/library-reorder-performance-assessment.md`

---

## Mental Model

The existing `PlayLibraryView` has two UI states: Normal mode and Select mode. This feature extends Select mode — renaming it "Edit mode" — to add drag-to-reorder alongside the existing checkboxes. The sole new data concern is a **pre-session snapshot** that makes Cancel a true discard path. Everything else is additive wiring: one new method on `PlayLibraryStore`, one new `@State` property in `PlayLibraryView` (the snapshot), and drag-handle markup in `PlayLibraryRow`.

No new type is introduced. No ViewModel layer is added. The store owns all persistent state; the view owns all transient UI state including the snapshot.

---

## 1. TQ-1 Resolution: `List(selection:)` + `.onMove` Coexistence

### Question

Can SwiftUI `List(selection: $selectedIDs)` and `.onMove` on the same `ForEach` be active simultaneously without conflict or suppression of either capability?

### Finding (confidence: high)

Yes, with one important behavioral nuance. On iOS 16+, `List` supports a multi-selection binding AND `.onMove` on the same `ForEach` simultaneously. Apple's own frameworks (Reminders, Shortcuts) use this combination. The `editMode` environment variable governs whether the list is in its editing state; when `editMode` is `.active`, the SwiftUI list machinery exposes both the selection circles and the reorder handle.

The nuance: `.onMove` on a `ForEach` inside a `List` requires that the list is in edit mode (`\.editMode == .active`). Without edit mode being active, `.onMove` has no effect — the handles do not appear. SwiftUI's default behavior when using `List(selection: $someBinding)` does NOT automatically set edit mode — the selection binding alone is not sufficient to activate the reorder handles.

**Current code gap:** `PlayLibraryView.playList` (line 149) uses `List(selection: isSelectMode ? $selectedIDs : .constant(Set<UUID>()))`. This activates multi-selection rendering but does NOT set `\.editMode` to `.active`. The drag handles from `.onMove` will not appear without explicitly setting edit mode. This is the root cause of the interaction constraint the spec flagged.

### Resolution

Manage `editMode` explicitly via an `@State` binding injected with `.environment(\.editMode, $editMode)` on the `List`. When Edit mode is entered, set `editMode = EditMode.active`. When exiting (Done or Cancel), set `editMode = EditMode.inactive`.

Do NOT use `EditButton` — it toggles the mode globally and creates a second independent path for mode entry/exit that bypasses the snapshot lifecycle.

**Behavior matrix once `editMode` is set to `.active`:**

| Gesture target | Result |
|---|---|
| Tap on checkbox area (row body / leading circle) | Toggles `selectedIDs` — standard selection behavior |
| Long-press-and-drag on reorder handle (trailing icon) | Activates drag, fires `.onMove` callback |
| Tap on reorder handle | No action — the handle has no tap gesture; it is a visual affordance for the drag recognizer |
| Swipe on row | Suppressed — `.swipeActions` is already guarded by `!isSelectMode` in the current code |

**Selection state across a drag (UX requirement from `library-reorder-ux.md` Section 1):** SwiftUI preserves `selectedIDs` across a `.onMove` reorder because `selectedIDs` is a `Set<UUID>` — it tracks by identity, not by position. When a row moves from index 2 to index 0, its UUID remains in `selectedIDs`. Selection does not clear on drag. No workaround needed.

**Interaction with `List(selection:)` binding:** The `selection` binding and `editMode` are independent mechanisms in SwiftUI. Setting `editMode = .active` does not clear or reset the selection binding. Both can be live simultaneously. Test case UI-10 in the test strategy directly validates this at execution time.

### Implementation directive

```swift
// In PlayLibraryView:
@State private var editMode: EditMode = .inactive

// On the List in playList:
List(selection: isSelectMode ? $selectedIDs : .constant(Set<UUID>())) {
    ForEach(store.plays) { play in
        // ...row content...
    }
    .onMove { offsets, destination in
        store.move(fromOffsets: offsets, toOffset: destination)
    }
}
.environment(\.editMode, $editMode)

// When entering Edit mode:
isSelectMode = true
editMode = .active

// When exiting Edit mode (Done or Cancel):
isSelectMode = false
editMode = .inactive
```

The `editMode` state variable must transition in lockstep with `isSelectMode`. They are always set together. There is no state where one is true and the other is false.

---

## 2. State Machine

### States

| State name | `isSelectMode` | `editMode` | `preSessionSnapshot` |
|---|---|---|---|
| Normal | `false` | `.inactive` | `nil` (or irrelevant) |
| Edit (was Select) | `true` | `.active` | `[SavedPlay]` value copy taken on entry |

There are exactly two states. The only valid transitions are:

```
Normal  --[ Edit button tapped ]-→  Edit mode
Edit    --[ Done tapped        ]-→  Normal  (persist called, snapshot discarded)
Edit    --[ Cancel tapped      ]-→  Normal  (plays restored from snapshot, no persist)
```

No intermediate states. No separate Reorder mode. No distinction between "selected something" and "not selected anything" at the mode level.

### Normal mode

- Toolbar: `[ Done (dismiss) ]` leading, `[ Edit ][ ... ]` trailing
- Rows: standard display, swipe actions active
- Selection binding: `.constant(Set<UUID>())` — List ignores taps for selection
- `editMode`: `.inactive` — drag handles invisible

### Edit mode (was Select mode)

- Toolbar: `[ Cancel ]` leading, `[ Done (commit) ]` trailing; bottom bar with Select All / Delete / Export
- Rows: checkbox (leading) + content + drag handle (trailing); swipe actions suppressed
- Selection binding: `$selectedIDs` — taps toggle selection
- `editMode`: `.active` — drag handles visible and interactive

---

## 3. Store API

### New method: `move(fromOffsets:toOffset:)`

```swift
func move(fromOffsets offsets: IndexSet, toOffset destination: Int) {
    plays.move(fromOffsets: offsets, toOffset: destination)
    // Note: NO persist() call here. Persist is deferred to commitReorder().
}
```

**Signature rationale:** The SwiftUI `.onMove` callback delivers `(IndexSet, Int)` — `fromOffsets: IndexSet, toOffset: Int`. Using this exact signature at the store layer means the view can pass the callback arguments directly to the store without any translation. This is the same pattern as `delete(at:)` using `IndexSet` to match SwiftUI's `.onDelete` callback signature.

**No persist on move:** This is the fundamental behavioral change from the existing store pattern. Every other mutating method (`save`, `delete`, `deleteAll`, `update`) calls `persist()` immediately. `move` does not. This is correct by design (AC-1.3) and must be documented in a comment in the implementation.

### New method: `commitReorder()`

```swift
func commitReorder() {
    do { try persist() } catch { print("[PlayLibraryStore] commitReorder persist failed: \(error)") }
}
```

Called by the view when the user taps Done. This is the only place `persist()` is invoked for the reorder path. The name is explicit — it is not a general-purpose save; it is specifically the commit of a reorder session.

**Why not inline `persist()` in the Done handler?** Calling `store.persist()` directly from the view would require making `persist()` internal or public. It is currently private. Exposing a named commit API is cleaner and testable: the test for "Done persists the reordered array" calls `store.commitReorder()` directly without needing view logic.

### No `beginReorder()` or `cancelReorder()` on the store

The snapshot for Cancel does not live in the store. See Section 4. The store API surface for this feature is exactly two methods: `move(fromOffsets:toOffset:)` and `commitReorder()`.

**Updated store API summary:**

| Method | Persists immediately? | Used by |
|---|---|---|
| `save(_:motion:yWheelEnabled:)` | Yes | Play builder |
| `delete(at:)` | Yes | Swipe delete, multi-select delete |
| `deleteAll()` | Yes | Delete all confirmation |
| `update(_:)` | Yes | Edit play flow |
| `move(fromOffsets:toOffset:)` | No | `.onMove` callback in Edit mode |
| `commitReorder()` | Yes | Done button in Edit mode |

---

## 4. Snapshot Strategy

### Decision: snapshot lives in `PlayLibraryView` as `@State`

**Option A: snapshot in `PlayLibraryStore`** via `beginReorder()` / `cancelReorder()` / `commitReorder()` methods.

**Option B: snapshot in `PlayLibraryView`** as `@State private var preSessionSnapshot: [SavedPlay] = []`.

**Recommendation: Option B (view-owned snapshot). Confidence: high.**

**Rationale:**

The snapshot is transient UI state — it exists to support a Cancel gesture and is meaningless outside of an active Edit mode session. It is not a durable data concern; it is not needed across app restarts; it does not affect any other consumer of the store. Placing it in the store would require the store to model a "session in progress" concept, making `plays` carry two different meanings depending on whether a reorder session is active. That conflation would make the store harder to reason about and harder to test in isolation.

The view is the correct home for transient UI session state. The pattern is standard: `@State private var previousValue = someDefaultValue` held until a gesture cycle completes.

**Testability:** SDET noted this as a concern. The store's `move` and `commitReorder` methods remain fully unit-testable in isolation. The snapshot restore behavior — "does Cancel restore the pre-session order?" — is tested by calling these store methods in sequence in a unit test and asserting the result. The test does not need to instantiate a view. SDET's test cases `testCancel_restoresPreSessionOrder` and `testCancel_doesNotWriteToDisk` are written against the store's observable state, which is correct regardless of where the snapshot variable lives.

**Security note (from security involvement assessment):** The snapshot must be a value copy, not a reference. `[SavedPlay]` is an array of value-type structs — a simple assignment (`preSessionSnapshot = store.plays`) produces a deep copy via Swift's copy-on-write semantics. The implementing agent must use direct assignment, not a computed property or closure that re-reads the live array.

### Snapshot lifecycle

```
Edit mode entered:
    preSessionSnapshot = store.plays   // value copy; taken exactly once

Drag operation:
    store.move(fromOffsets:toOffset:)   // mutates store.plays in memory
    // preSessionSnapshot is NOT touched

Done tapped:
    store.commitReorder()               // writes store.plays (post-reorder) to disk
    preSessionSnapshot = []            // or any sentinel; snapshot is now stale/unused
    isSelectMode = false
    editMode = .inactive

Cancel tapped:
    withAnimation(.easeInOut(duration: 0.3)) {
        store.plays = preSessionSnapshot   // restore in-memory order (animated)
    }
    // Note: requires store.plays to be settable. See Section 6.
    preSessionSnapshot = []
    isSelectMode = false
    editMode = .inactive
    selectedIDs = []
```

### Store `plays` writability for Cancel restore

The current store declares `@Published private(set) var plays: [SavedPlay]`. The `private(set)` restricts writes to within the store's own methods. To allow the view to restore the snapshot directly, one of two approaches is needed:

**Option B1:** Add a `cancelReorder(snapshot: [SavedPlay])` method to the store that accepts the snapshot and sets `plays = snapshot` without calling `persist()`.

**Option B2:** Change `plays` to `@Published var plays: [SavedPlay]` (remove `private(set)`), allowing the view to set it directly.

**Recommendation: Option B1 — add `cancelReorder(snapshot:)`.** Exposing `plays` as publicly writable is too broad; any part of the codebase could mutate the canonical play list without going through the store's controlled mutation paths. A named method preserves the store's role as the single point of mutation, makes the Cancel path testable (SDET can call `store.cancelReorder(snapshot:)` directly), and documents intent clearly.

**Updated store API (final):**

| Method | Persists? | Notes |
|---|---|---|
| `save(_:motion:yWheelEnabled:)` | Yes | Unchanged |
| `delete(at:)` | Yes | Unchanged |
| `deleteAll()` | Yes | Unchanged |
| `update(_:)` | Yes | Unchanged |
| `move(fromOffsets:toOffset:)` | No | New; matches `.onMove` callback signature |
| `commitReorder()` | Yes | New; called by Done |
| `cancelReorder(snapshot: [SavedPlay])` | No | New; restores snapshot, no disk write |

---

## 5. Persist Strategy

**One rule:** `persist()` is called exactly once per Edit mode session — in `commitReorder()`, on the Done path. It is never called on the Cancel path. It is never called inside the `.onMove` callback.

This maps cleanly to `PlayLibraryStore`'s existing private `persist()` method, which `commitReorder()` calls exactly as `save`, `delete`, and `update` do.

**Error handling:** `commitReorder()` follows the same error-suppression pattern as `delete` and `save` (print to console, no throw). The rationale: a persist failure here is not different from a persist failure in any other operation. The user's in-memory order is correct; only the on-disk state is stale. This is a non-destructive failure. Surfacing an error alert to the user at "Done" tap time is disproportionate for a list reorder. Align with existing store behavior.

If a future slice adds user-visible error handling to the store uniformly, this method should be updated at that time.

---

## 6. View Changes

### 6a. Toolbar restructure

**Normal mode (unchanged except "Select" → "Edit"):**
```
Leading:  [ Done ]                   (dismiss library sheet — unchanged)
Trailing: [ Edit ] [ ... ]           ("Select" renamed to "Edit")
```

**Edit mode (restructured):**
```
Leading:  [ Cancel ]                 (discard + exit)
Trailing: [ Done ]                   (commit + exit)
Bottom:   [ Select All ] [ Delete N ] [ Export N ]
```

The current code (lines 52–63 of `PlayLibraryView.swift`) puts both Cancel and Select in the trailing HStack conditionally. The Edit mode redesign moves Cancel to the leading position and Done to the trailing position, matching iOS HIG for editing modes. The `[ Done ]` button that currently dismisses the library sheet must be hidden in Edit mode (leading slot is taken by Cancel).

**Implementation note:** The existing leading `ToolbarItem` renders `Button("Done") { dismiss() }`. In Edit mode, this slot must instead show `Button("Cancel") { cancelEdit() }`. The simplest approach is to make the leading button conditional on `isSelectMode`, swapping between dismiss-Done and cancel-Cancel. If SwiftUI's toolbar animation produces a flash on this swap, wrap the `isSelectMode` toggle in `withAnimation(.easeInOut(duration: 0.15))`.

### 6b. `editMode` state and wiring

Add to `PlayLibraryView`:

```swift
@State private var editMode: EditMode = .inactive
@State private var preSessionSnapshot: [SavedPlay] = []
```

Apply to the `List`:

```swift
.environment(\.editMode, $editMode)
```

Add `.onMove` to the `ForEach`:

```swift
.onMove { offsets, destination in
    store.move(fromOffsets: offsets, toOffset: destination)
}
```

### 6c. Enter/exit Edit mode handlers

```swift
private func enterEditMode() {
    preSessionSnapshot = store.plays   // value copy
    withAnimation(.easeInOut(duration: 0.15)) {
        isSelectMode = true
        editMode = .active
    }
}

private func commitEdit() {
    store.commitReorder()
    preSessionSnapshot = []
    withAnimation(.easeInOut(duration: 0.15)) {
        isSelectMode = false
        editMode = .inactive
        selectedIDs = []
    }
}

private func cancelEdit() {
    store.cancelReorder(snapshot: preSessionSnapshot)
    preSessionSnapshot = []
    withAnimation(.easeInOut(duration: 0.3)) {
        isSelectMode = false
        editMode = .inactive
        selectedIDs = []
    }
}
```

The Cancel animation uses a longer duration (0.3 s) than enter/exit (0.15 s) so the coach sees rows animate back to their pre-session positions, communicating "these changes were discarded" rather than a confusing instant reset. This is the UX requirement from `library-reorder-ux.md` Section 3.

### 6d. Drag handle in `PlayLibraryRow`

`PlayLibraryRow` does not need to render the drag handle explicitly. When `editMode` is `.active` and `.onMove` is present on the `ForEach`, SwiftUI automatically displays the system reorder control (three-line icon, trailing edge) for each row. This is the standard SwiftUI mechanism.

However, the UX spec requires:

1. The handle uses `.secondary` color (the system default handle satisfies this).
2. The handle has a 44x44 pt touch target (the system handle satisfies this by default).
3. The handle is disabled (visually muted at 30% opacity) when the library contains exactly 1 play (AC-2.4).

For the disabled state: SwiftUI does not provide a native per-row "disable only the reorder handle" affordance. The system handle is either present (when `.onMove` exists) or absent. The `.onMove` callback will simply be a no-op for a single-element array — you cannot drag a lone element anywhere. The visual treatment can be achieved by conditionally applying `.onMove` only when `store.plays.count > 1`.

When the library has exactly 1 play, omit the `.onMove` modifier entirely. The handle disappears. When the library has 2+ plays, apply `.onMove`. This approach matches the UX goal of "non-interactive" for the 1-play case, but via absence rather than 30% opacity.

**Deviation from UX spec:** The UX spec recommends showing the handle at 30% opacity (not hidden) to preserve discoverability. This requires a custom handle view rather than relying on SwiftUI's system handle. Given the complexity of replacing the system handle with a custom view and the marginal discoverability benefit for a 1-play edge case, the recommendation is:

- **Ship:** Omit `.onMove` (and thus the handle) when `store.plays.count <= 1`. The handle is absent, not faded. This is simpler and does not require a custom row implementation.
- **Backlog:** If coach feedback indicates confusion about the handle appearing "only after I add a second play," implement the custom trailing handle with 30% opacity for the 1-play state.

This is a scope trade-off. The 1-play-library case is a rare edge state (any coach who opens the library to manage plays likely has at least 2). Correctness (no crash, no gesture conflict) is guaranteed by the simpler approach. The UX discoverability concern is low-probability.

**If the UX requirement is non-negotiable (must-ship at 30% opacity):** Add a `showDragHandle: Bool` and `handleEnabled: Bool` parameter to `PlayLibraryRow`. In Edit mode, always show the handle; when `store.plays.count == 1`, render it with `.opacity(0.3)` and `.allowsHitTesting(false)`. The system `.onMove` handles actual drag initiation separately. The custom trailing icon becomes purely decorative in the 1-play case. This requires the `.onMove` to always be present but the store's `move` method is a no-op for a 1-element array (Swift's `Array.move(fromOffsets:toOffset:)` with `fromOffsets = [0]` and `toOffset = 0` is safe — it is a no-op).

**Decision required before implementation:** Ken or the implementing agent must pick one approach. The recommendation is the simpler path (absent handle for 1-play). If the UX faded-handle is required, use the custom trailing icon approach described above.

### 6e. Accessibility

Add to the drag handle (whether system or custom):

```swift
.accessibilityLabel("Reorder \(play.formationName) \(play.routeDigits)")
.accessibilityHint(store.plays.count == 1 ? "Reordering requires at least 2 plays" : "")
```

If using the system handle (system `.onMove`), SwiftUI provides default accessibility for reorder. Custom label requires `.accessibilityElement(children: .combine)` on the row or explicit label on the handle view.

---

## 7. Component Map

### Files that change

| File | Change type | What changes |
|---|---|---|
| `SpartansPlaycaller/Services/PlayLibraryStore.swift` | Modified | Add `move(fromOffsets:toOffset:)`, `commitReorder()`, `cancelReorder(snapshot:)` |
| `SpartansPlaycaller/Views/PlayLibraryView.swift` | Modified | Add `editMode` + `preSessionSnapshot` state; restructure toolbar (Cancel leading, Done trailing in Edit mode); rename "Select" → "Edit"; add `.onMove` to `ForEach`; add `enterEditMode()`, `commitEdit()`, `cancelEdit()` handlers; wire `editMode` to `List`; add `PlayLibraryRow` handle visibility logic |

### Files that do NOT change

| File | Reason |
|---|---|
| `SpartansPlaycaller/Models/SavedPlay.swift` | No schema change; `SavedPlay` struct is unchanged |
| `SpartansPlaycaller/Services/CatalogPDFGenerator.swift` | Reads `ExportCard` array, not `store.plays` directly; no change needed |
| `SpartansPlaycaller/Services/WristbandPDFGenerator.swift` | Same reason |
| `SpartansPlaycaller/Views/EditPlayView.swift` | Edit flow is unchanged; `EditPlayView` is accessed via `playBeingEdited` sheet which is still available in Normal mode |
| Any export or route interpreter file | Not touched by this feature |

### New test files (to be registered in `project.pbxproj`)

| File | Contents |
|---|---|
| `SpartansPlaycallerTests/LibraryReorderStoreTests.swift` | ~14 unit tests for `move`, `commitReorder`, `cancelReorder` (see SDET test strategy Section 3) |
| `SpartansPlaycallerTests/LibraryReorderIntegrationTests.swift` | ~8 integration tests for persistence round-trip (see SDET test strategy Section 4) |

The SDET test strategy places snapshot/restore tests in `PlayLibraryStoreTests.swift` (Section 3.2). Given that the snapshot API is now confirmed to live on the store (`cancelReorder(snapshot:)`), these tests belong in a new `LibraryReorderStoreTests.swift` to keep test files focused rather than growing the existing store test file. SDET may alternatively append to `PlayLibraryStoreTests.swift` — either is acceptable, but a new file requires `project.pbxproj` registration.

---

## 8. Risk Log

### Risk 1 — `editMode` / `List(selection:)` interaction on older iOS versions

**Severity:** Medium. **Confidence in mitigation:** High.

The combination of `List(selection:)` + `environment(\.editMode, $editMode)` + `.onMove` is tested and supported on iOS 16+. The project targets iOS 17.0+ (per the simulator target in the test strategy). No concern on the target OS.

Residual: if the minimum deployment target is ever lowered below iOS 16, this combination must be re-tested. Document this in the implementation comments.

### Risk 2 — Selection state visibility during drag (SwiftUI rendering)

**Severity:** Low. **Confidence in mitigation:** Medium.

The UX spec requires that selection state (checked rows) is preserved visibly through a drag and after a drag completes. The architecture assessment is that `selectedIDs: Set<UUID>` survives a drag because it tracks by UUID identity, not by position. However, SwiftUI's rendering of the selection circle during an active drag (mid-air) is framework-controlled and may or may not show the checkbox on the dragged row while it is lifted. This is a cosmetic concern, not a correctness concern. Manual check UI-10 in the test strategy covers this.

If SwiftUI suppresses the selection circle on the dragged row mid-flight (the row is lifted as a "ghost"), this is acceptable behavior — the selection is preserved in state and reappears when the row lands. No workaround needed unless Ken flags it as unacceptable after visual review.

### Risk 3 — Export sheet while Edit mode is active

**Severity:** Low. **Confidence in mitigation:** High.

The UX spec (Section 10, "Unknown about Cancel with mixed changes") raises the question of what happens if a coach taps Export in the bottom bar, the share sheet presents, they dismiss the share sheet, and then they tap Cancel. The export path (`triggerExport`) is read-only — it does not mutate `store.plays`. After the share sheet dismisses, the view is still in Edit mode (since the export sheet is a sheet presentation over the library, not a mode exit). The coach can then tap Done (commit reorder) or Cancel (discard reorder) normally. No special handling needed. The export sheet dismissal does not interact with `isSelectMode`, `editMode`, or `preSessionSnapshot`.

### Risk 4 — `commitReorder()` called when no moves occurred (no-op persist)

**Severity:** Negligible. **Confidence in mitigation:** High.

If the coach enters Edit mode, does nothing, and taps Done, `commitReorder()` calls `persist()` — writing the unchanged `plays` array to disk. This is a redundant write. It is harmless (same file content, same encryption, same atomic write path) but slightly wasteful. SDET test `testDone_afterNoMoves_persistsUnchangedOrder` confirms this is safe. No optimization needed for this slice.

### Risk 5 — `cancelReorder(snapshot:)` called with an empty snapshot (guard needed)

**Severity:** Low. **Confidence in mitigation:** High.

If through a bug the view calls `cancelReorder(snapshot: [])` (e.g., `preSessionSnapshot` was never set because `enterEditMode()` was not called before `cancelEdit()`), the store would replace `plays` with an empty array — data loss. The implementing agent must guard against this:

```swift
func cancelReorder(snapshot: [SavedPlay]) {
    guard !snapshot.isEmpty || plays.isEmpty else {
        assertionFailure("[PlayLibraryStore] cancelReorder called with empty snapshot but plays is non-empty — snapshot not initialized")
        return
    }
    plays = snapshot
    // No persist() call
}
```

This turns a potential data-loss bug into a no-op (in production, `assertionFailure` is a no-op; in debug, it surfaces the programming error). The view architecture makes this case unlikely — `preSessionSnapshot` is set at `enterEditMode()` entry and the snapshot is passed to `cancelReorder()` in `cancelEdit()` — but defensive coding here costs nothing.

### Risk 6 — Toolbar layout at large Dynamic Type sizes

**Severity:** Low. **Confidence in mitigation:** Medium.

Normal mode has three trailing items: `[ Edit ] [ ... ]`. At very large Dynamic Type sizes, these items may wrap or truncate. This is a pre-existing concern that worsens only marginally with the rename from "Select" to "Edit" (similar character count). Edit mode reduces to `[ Cancel ]` leading and `[ Done ]` trailing — two items, maximum space — so Edit mode is safer than Normal mode at large sizes. Manual observation at `accessibility5` Dynamic Type during SDET execution covers this.

---

## 9. Non-Goals (confirmed from spec)

- No separate Reorder mode or Reorder toolbar button
- No undo stack for reorder
- No automatic sort by any field
- No reorder during an in-progress export
- No iCloud sync; order is local only
- No per-group or section reordering

---

## 10. Open Decisions

| Decision | Options | Recommendation | Owner |
|---|---|---|---|
| 1-play handle: absent vs faded | Absent (omit `.onMove` when count ≤ 1) vs faded (custom trailing icon with 30% opacity, `.allowsHitTesting(false)`) | Absent — simpler, ship faster; add faded-handle to backlog | Ken / implementing agent |
| Test file placement: new file vs append to existing | New `LibraryReorderStoreTests.swift` vs append to `PlayLibraryStoreTests.swift` | New file for separation; either is acceptable | SDET / implementing agent |

---

## 11. Implementation Checklist (for software-engineer)

This is a sequence guide, not a plan file. The implementation plan (`docs/superpowers/plans/`) is the authoritative task list.

1. Add `move(fromOffsets:toOffset:)`, `commitReorder()`, and `cancelReorder(snapshot:)` to `PlayLibraryStore.swift`. Confirm `persist()` remains `private` and is NOT called from `move`.
2. Register new test files in `project.pbxproj`. Write and pass store unit tests before touching the view.
3. Add `editMode` and `preSessionSnapshot` state to `PlayLibraryView`.
4. Refactor toolbar: rename "Select" → "Edit"; restructure leading/trailing for Edit mode (Cancel leading, Done trailing).
5. Add `.environment(\.editMode, $editMode)` to the `List`.
6. Add `.onMove` to the `ForEach`, conditioned on `store.plays.count > 1` (or always present if faded-handle approach is chosen).
7. Wire `enterEditMode()`, `commitEdit()`, `cancelEdit()` to the toolbar buttons.
8. Add drag handle accessibility labels.
9. Run full test suite to confirm zero regressions.

---

## 12. Validation Steps

**Cheapest validation before implementation begins:** In a SwiftUI Playground or a scratch `View`, confirm that `List(selection: $ids)` + `.environment(\.editMode, $editMode)` + `ForEach { }.onMove { }` simultaneously shows selection circles and reorder handles when `editMode = .active`. This takes 10 minutes and eliminates TQ-1 uncertainty at the source.

**Hardest trade-off in this design:** The decision to defer `persist()` to Done (rather than per-move) is the right call for correctness and performance, but it creates a new invariant — "the store can be in a state where `plays` in memory differs from `plays` on disk" — that does not exist for any other operation today. The Cancel restore path depends on this invariant being maintained correctly. The test cases `testMove_doesNotPersistImmediately` and `testCancel_doesNotWriteToDisk` are the primary guards. If either fails, the deferred-persist invariant is broken and the feature is unsafe to ship.

**What would invalidate this design:** If Apple changes `List(selection:)` + `editMode` interaction semantics in a future iOS version in a way that forces the selection binding to deactivate when `editMode` is `.active`. This is unlikely but possible. The workaround would be to manage the visual edit affordances (checkboxes, drag handles) entirely with custom UI rather than relying on the system `List` edit mode. That is significantly more implementation work and would require a design revision.
