# Spec: Play Library — Reorder Plays

**Feature:** Library Reorder
**Status:** Open Questions Resolved — Ready for Architecture Consultation
**Author:** product-owner
**Date:** 2026-06-09
**Spec file:** `docs/superpowers/specs/library-reorder-spec.md`

---

## 1. Problem Statement

Coaches build their play library over the course of a week. The order plays appear in the library is currently determined by insertion time — the most recently saved play is always at the bottom. Before game day, a coach typically wants to arrange plays by game plan priority, formation grouping, or preferred call sequence. There is no way to do this today.

The result is that a coach who saved plays in practice-drill order must mentally re-map the list to their intended call sequence during the game. This adds cognitive load in a high-pressure environment where quick scanning is essential.

Drag-to-reorder is the standard iOS affordance for this job. It requires no new mental model, is already expected by iOS users on list screens, and maps directly to the underlying data structure (`plays: [SavedPlay]` is an ordered array whose persisted order is the display order).

---

## 2. User Stories

### Story 1 — Arrange Plays by Game Plan Priority

**As a** head coach finalizing my game plan the night before a game,
**I want to** drag plays into the order I intend to call them,
**so that** during the game I can scan my library top-to-bottom and find the next play without searching.

#### Acceptance Criteria

**AC-1.1 — Drag handle visible in Select mode:**
When the library is in Select mode, each play row displays both a checkbox (for multi-select delete/export) AND a drag handle (the standard `line.3.horizontal` reorder control). Tapping and holding the handle allows the row to be dragged up or down the list. Select mode is therefore a combined "edit list" mode that supports both selection and reorder simultaneously.

Note for UX/architecture: Whether checkboxes and drag handles can coexist in a single SwiftUI `List` mode without layout or interaction conflicts requires explicit assessment. Architecture-system-design must confirm SwiftUI `List(selection:)` + `.onMove` compatibility before the implementation plan is written. See Section 8.

**AC-1.2 — Live feedback during drag:**
While dragging, the row lifts visually and adjacent rows shift to show the insertion point. This is standard SwiftUI `.onMove` behavior; no custom animation is required.

**AC-1.3 — Order buffered during drag; persisted on Done:**
While Select mode is active, drag operations update the `plays` array in memory only. The updated order is NOT written to `play-library.json` until the user taps "Done" to exit Select mode. The list reflects the in-memory order immediately after each drag, but the on-disk order is not changed until Done is confirmed. This enables a discard path (see AC-2.3).

**AC-1.4 — Order survives app restart:**
After reordering, closing and relaunching the app shows plays in the reordered sequence. The on-disk JSON array order is canonical.

**AC-1.5 — Order preserved across feature interactions:**
After reordering, performing any subsequent edit, delete, or export does not reset the list to insertion order. The array order is the single source of truth for display order at all times.

---

### Story 2 — Enter and Exit Select Mode (Combined Selection + Reorder)

**As a** coach managing my play library,
**I want** the Select button to activate a combined "edit list" mode with both checkboxes and drag handles,
**so that** I can reorder plays and manage selections in one mode without needing a separate Reorder entry point.

#### Acceptance Criteria

**AC-2.1 — Select mode is the single entry point for reorder:**
There is no separate "Reorder" button. The existing "Select" button activates Select mode, which now exposes both checkboxes (for multi-select delete/export) and drag handles (for reorder) on every play row simultaneously. A dedicated Reorder mode no longer exists.

**AC-2.2 — Select mode entry guard:**
The Select button is visible and tappable when the library contains 1 or more plays. When the library is empty, Select is hidden or disabled.

**AC-2.3 — Done commits reorder; Cancel discards it:**
While Select mode is active, the toolbar shows "Done" and "Cancel" controls. Tapping "Done" exits Select mode, writes the current in-memory play order to disk, and returns the toolbar to its normal state. Tapping "Cancel" exits Select mode, discards any drag reordering performed during this session, restores the pre-session play order, and does NOT write to disk. Checkboxes and drag handles disappear on exit via either path.

**AC-2.4 — Drag handle disabled for single-play libraries:**
When the library contains exactly 1 play, Select mode may still be entered (to support checkbox-based delete/export), but the drag handle is non-interactive (disabled state). Reorder requires at least 2 plays.

**AC-2.5 — Normal row interactions suppressed in Select mode:**
While in Select mode, swipe actions (Delete, Edit) are not available. Tapping a row toggles its checkbox; it does not navigate to the play editor. This prevents accidental edits or deletes during selection/reordering sessions.

---

### Story 3 — Reorder Does Not Break Export

**As a** coach who has arranged plays in a specific order for a game plan,
**I want** PDF exports to reflect the same order I see in the library,
**so that** the wristband cards and catalog match my call sequence without me having to re-sort them mentally.

#### Acceptance Criteria

**AC-3.1 — Export respects library order:**
When plays are selected and exported (Catalog PDF or Wristband Cards), the plays appear in the exported PDF in the same order they appear in the library list at the time of export. The play number printed on each card (1, 2, 3…) corresponds to the library order, not insertion order.

**AC-3.2 — No ordering side effect from export:**
Triggering an export does not alter the stored play order. The `plays` array is read, not mutated, during export.

---

## 3. Out of Scope

This slice does not include:

- **Automatic sort options** — sorting by formation, concept, date saved, or any other field is not in scope. Manual drag order is the only ordering mechanism in this slice. A "Sort by" feature is a candidate for a future backlog item.
- **Alphabetical or numerical auto-sort** — no automatic ordering of any kind.
- **Separate Reorder mode** — there is no dedicated Reorder mode. Reorder is part of Select mode (Ken resolved OQ-1 in favor of combined mode).
- **Undo for reorder** — dragging a row to the wrong position can be corrected by dragging it back. No undo stack.
- **Per-group or section reordering** — the library has no sections in this slice; all reordering is flat-list.
- **Reorder during export** — plays cannot be reordered while an export is in progress.
- **iCloud sync or cross-device order consistency** — order is local only.
- **Duplicate detection on reorder** — moving a play does not trigger any duplicate check.

---

## 4. Interaction Design Notes (for UX consultation)

These are framing observations, not final decisions. UX-designer should validate:

**Mode toggle placement (resolved):** There is no separate Reorder button. Select mode is the single entry point for both selection and reorder. The toolbar remains: `Done` (leading, visible in Select mode to commit changes), `Cancel` (exits without persisting reorder), and `Select/Cancel` (trailing, in normal mode). UX-designer should confirm the Done/Cancel affordance layout does not conflict with the existing toolbar — this is an open UX design task.

**Drag handle vs full-row drag:** Standard iOS convention is a dedicated drag handle on the trailing or leading edge (three-line icon) that activates in edit mode. Full-row dragging conflicts with swipe gestures already on these rows. A mode-isolated drag handle (visible only in Select mode) is the correct approach. UX-designer should specify handle position (leading vs trailing) relative to the checkbox.

**Mode transition animation:** When transitioning into Select mode, drag handles and checkboxes should animate in together (standard SwiftUI edit mode behavior handles the drag handle animation). Swipe action indicators should not be visible while Select mode is active.

---

## 5. Open Questions

**OQ-1 — Reorder entry point: RESOLVED**
Decision: Drag handles appear in Select mode. Select mode is a combined "edit list" mode that activates both checkboxes and drag handles simultaneously. There is no separate Reorder button or Reorder mode.
Implication: UX-designer must assess the combined row layout (checkbox + content + drag handle). Architecture-system-design must assess SwiftUI `List(selection:)` + `.onMove` coexistence (see open technical question below).

**OQ-2 — Selection cleared on mode transition: NOT APPLICABLE**
There is no mode transition from Select to Reorder — they are the same mode. This question is moot given OQ-1's resolution.

**OQ-3 — 1-play state for reorder control: RESOLVED**
Decision: When the library contains exactly 1 play, the drag handle is present in Select mode but rendered non-interactive (disabled). Reorder UI is discoverable even with a single play; it simply cannot be activated until a second play is added.

**OQ-4 — Persist timing: RESOLVED**
Decision: Order is buffered in memory during Select mode. The `plays` array is written to disk only when the user taps "Done" to exit Select mode. Tapping "Cancel" discards all drag operations performed during that Select mode session and restores the pre-session order. This enables a deliberate discard path. Implementation note: `PlayLibraryStore` must hold a snapshot of the pre-session order when Select mode is entered, so Cancel can restore it without reading from disk.

---

### Open Technical Question (for architecture-system-design)

**TQ-1 — SwiftUI `List(selection:)` + `.onMove` compatibility:**
SwiftUI's `List` with a multi-selection binding (`List(selection: $selectedIDs)`) and `.onMove` on the same `ForEach` have known interaction constraints. The question is whether both can be active simultaneously in Select mode, or whether the implementation must deactivate the selection binding while a drag is in progress (or vice versa). Architecture-system-design must verify the exact SwiftUI API behavior on the target iOS version before the implementation plan is written. This is the primary technical risk in this spec.

---

## 6. Success Metrics

- A coach can drag a play from position 8 to position 2 in under 10 seconds.
- After relaunching the app, plays appear in the order the coach arranged them — not insertion order.
- PDF exports render plays in the same left-to-right / top-to-bottom sequence as the library list.
- Entering and exiting Select mode does not alter any play's data. Canceling Select mode restores the pre-session play order with zero writes to disk.
- Zero reported cases of reorder being silently lost between sessions.

---

## 7. Roles

| Role | Involvement | Notes |
|------|-------------|-------|
| product-owner | Spec author; AC owner | This document |
| ux-designer | Consultation | Combined Select mode row layout (checkbox + content + drag handle); handle position (leading vs trailing); Done/Cancel toolbar affordance; mode transition animations |
| architecture-system-design | Design spec | `PlayLibraryStore.move(fromOffsets:toOffset:)` method design; pre-session order snapshot for Cancel discard; mode state machine (Normal / Select); TQ-1: SwiftUI `List(selection:)` + `.onMove` compatibility assessment |
| software-engineer | Implementation | Store `move` method; pre-session snapshot; buffered persist on Done; Cancel discard; drag handle wiring; drag handle disabled state for 1-play library; toolbar Done/Cancel updates |
| sdet | Test strategy + execution | AC coverage for: drag persistence, mode exclusion, export order, empty/single-play guard, mode exit, interaction with edit/delete; edge cases: drag to same position, rapid mode switches |
| performance-engineer | Assessment | `move(fromOffsets:toOffset:)` is O(n) on a local array; assess whether list re-render after move has observable latency at realistic library sizes (50–200 plays) and whether per-move persist adds perceptible delay |
| security-engineer | Involvement assessment + review | Reorder does not accept user-supplied freeform input and does not change play content — only array position. Assess whether move path introduces any new data-handling risks beyond what the existing store already exposes. |
| scrum-master | Retrospective | After shipping; capture process learnings |

---

## 8. Dependencies and Integration Notes

**Depends on:** The just-shipped edit/delete feature (library-edit-delete-spec.md). The `PlayLibraryView` and `PlayLibraryStore` structures it introduced are the base this feature extends.

**Store change required:** `PlayLibraryStore` needs a `move(fromOffsets: IndexSet, toOffset: Int)` method that calls `plays.move(fromOffsets:toOffset:)` and then `persist()`. This follows the exact same pattern as `delete(at:)` and is low-risk to implement.

**SwiftUI List constraint (open technical question TQ-1):** SwiftUI's `List` with a multi-selection binding (`List(selection: $selectedIDs)`) and `.onMove` on the same `ForEach` have known interaction constraints. Because Ken's decision is to combine both in Select mode, architecture-system-design must determine whether this is directly supported or requires a workaround (e.g., temporarily suspending the selection binding during a drag gesture). The `isSelectMode` state machine replaces the prior `isSelectMode` / `isReorderMode` pair — there is only one non-normal mode now. Architecture-system-design must resolve TQ-1 before the implementation plan is written.

**Export play numbering:** `PlayLibraryView.triggerExport` currently numbers cards with `enumerated()` over `selectedPlays`, which is filtered from `store.plays` (maintaining array order). No change to export numbering logic is required if array order is preserved correctly — this is a verification point, not a new implementation requirement.

---

## 9. Security Involvement Assessment

**Assessed by:** security-engineer
**Date:** 2026-06-09

### Threat surface

This feature is entirely local: no network calls, no inter-process communication, no user-supplied freeform text is introduced by reorder. The operation is a positional mutation of an already-trusted in-memory array, written to a sandboxed app-container file via the existing persist path. The attack surface introduced by this feature is negligible relative to what the store already exposes.

### Finding 1 — Injection risk: None

**Assessment:** No new injection surface. Severity: N/A.

Reorder operates on `IndexSet` (integer offsets into the `plays` array). `Array.move(fromOffsets:toOffset:)` is a Foundation method that operates on validated integer indices — it does not parse or interpret user-supplied strings. The play content (`formationName`, `routeDigits`, `conceptName`, etc.) is carried through unchanged; reorder does not touch field values. No new string parsing, JSON construction from user input, or format interpretation is introduced.

Residual: The existing `update(_:)` path re-interprets `routeDigits` through `RouteInterpreter`; reorder does not call that path, so no regression there.

### Finding 2 — Cancel snapshot integrity: Low concern, design already correct

**Assessment:** The spec's design (snapshot captured on Select mode entry, restored on Cancel without a disk read) is the correct approach. Severity: Low / informational.

The risk to assess here is snapshot divergence — a scenario where the in-memory snapshot becomes inconsistent with the in-memory `plays` array during a Select session (e.g., a concurrent write mutating `plays` while Select mode is active). Because the store is `@MainActor`-isolated, all mutations to `plays` are serialized on the main actor. There is no concurrent write path in the current codebase (`save`, `delete`, `deleteAll`, `update` are all `@MainActor`). This eliminates the race condition class entirely under the current architecture.

**Implementation requirement:** The snapshot must be captured as a value copy (`var snapshot = store.plays`), not a reference, so that subsequent in-session drag moves do not mutate the snapshot. Swift arrays are value types — a simple assignment produces a copy — but the implementing agent must not capture the snapshot via a computed property or lazy reference that would re-read the live array.

**Verification point:** Confirm in post-implementation review that the snapshot variable is assigned exactly once (on Select mode entry) and is never reassigned during drag operations.

### Finding 3 — Persist-on-Done atomicity: Existing path, no new concern

**Assessment:** No new risk introduced. Severity: N/A.

The persist path (`JSONEncoder().encode` + `Data.write(to:options:.completeFileProtection)`) is unchanged from existing `save`, `delete`, and `update` operations. `.completeFileProtection` provides iOS data-at-rest encryption; the single `Data.write` call is an atomic file replacement on iOS (the OS writes to a temporary location and renames). A crash between Done tap and write completion would leave the file in its pre-reorder state (the existing on-disk order), which is the correct safe-fail behavior — the user would lose the reorder session but not any play data.

No new partial-write risk. The spec correctly defers disk writes to Done, meaning mid-session crashes also produce no corruption.

### Finding 4 — Export order: No integrity risk

**Assessment:** No risk. Severity: N/A.

`triggerExport` reads `store.plays` and does not mutate it (AC-3.2 is correct by design). The `enumerated()` approach over the filtered selection preserves array order without copying or reinterpreting data. Reorder does not change this path.

### Finding 5 — No new secrets, entitlements, or permission requests

**Assessment:** Reorder requires no new capabilities, entitlements, or file-system paths. The feature stays entirely within the existing document-directory sandbox. No concern.

---

## Security Involvement Assessment

**Risk surface:** Local iOS app; reorder is an integer-index array mutation on a sandboxed file already protected by `.completeFileProtection`. No network, no auth, no new user-supplied freeform input. The primary integrity question is snapshot fidelity on Cancel, which is fully handled by Swift's value-type semantics and `@MainActor` isolation.

| Phase | Engagement level | Rationale |
|-------|-----------------|-----------|
| Design consultation | Complete (this document) | Assessed; no open security design questions. |
| Plan review | Light | One targeted check: confirm the Cancel snapshot is captured as a value copy, not a reference, and is assigned once on mode entry. Flag if the implementation plan proposes a disk-read on Cancel instead of snapshot restore. |
| Implementation support | Not needed (on-demand only) | No ambiguous security decisions are anticipated during implementation. Available if the implementing agent raises a question about state machine transitions or file writes. |
| Post-implementation verification | Light | One verification task: confirm snapshot assignment is a value copy (code review); confirm no disk write occurs on the Cancel path (unit test assertion or log check). No active attack simulation needed — there is no exploitable surface. |

**Escalation triggers:**
- If architecture introduces any out-of-process communication (e.g., widget extension reading the same `play-library.json`) — reassess for concurrent-write races and file-lock concerns.
- If the Cancel path is implemented with a disk read instead of a snapshot restore — escalate to verify no window exists where a partial write could be read back.
- If a future slice adds network sync of the library — this assessment does not cover that surface; full security engagement required at that time.

**Residual risk after this feature ships:** Effectively zero for the reorder slice in isolation. The only open risk class for the store as a whole remains what existed before this feature: `play-library.json` is not encrypted at the application layer (it relies on iOS data-at-rest encryption), meaning a device with Full Disk Access bypassed or a backup extracted without encryption would expose play data in plaintext JSON. This is pre-existing and out of scope for this slice.
