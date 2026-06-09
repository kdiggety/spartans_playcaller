# Spec: Play Library — Delete, Delete All, and Edit

**Feature:** Library Edit and Delete  
**Status:** Draft  
**Author:** product-owner  
**Date:** 2026-06-08  
**Spec file:** `docs/superpowers/specs/library-edit-delete-spec.md`

---

## 1. Problem Statement

The Play Library allows coaches to save plays, but once a play is saved it is locked. Coaches cannot:

- Remove a single play that was saved by mistake, is obsolete, or duplicated.
- Clear the entire library before a new game or practice session.
- Fix a play whose formation, route digits, or motion was entered incorrectly without deleting it and re-saving from scratch.

The result is a library that accumulates errors and stale entries with no remediation path. On game day, a cluttered or incorrect library erodes trust in the tool.

Swipe-to-delete exists today but is undiscoverable on first use and has no confirmation guard. Delete All and Edit do not exist at all.

---

## 2. User Stories

### Story 1 — Delete a Single Play

**As a** coach reviewing my play library before game day,  
**I want to** delete a single play I no longer need,  
**so that** my library stays clean and only contains plays I intend to call.

#### Acceptance Criteria

**AC-1.1 — Delete via swipe (existing, add confirmation):**  
When a coach swipes left on a play row, a "Delete" action is revealed. Tapping it presents a confirmation prompt naming the play (formation + route digits). Confirming removes the play from the list and from persisted storage. Canceling leaves the play unchanged.

**AC-1.2 — Delete via Select mode:**  
When one or more plays are selected in Select mode, a "Delete" button is visible in the bottom bar alongside the existing Export button. Tapping "Delete" presents a confirmation prompt stating the count (e.g., "Delete 2 plays?"). Confirming removes all selected plays from the list and from persisted storage. Canceling returns to Select mode with the same selection intact.

**AC-1.3 — Persistence:**  
After deletion, the removed play does not reappear when the app is backgrounded and relaunched.

**AC-1.4 — Empty state:**  
If the last play is deleted, the library transitions to the empty state ("No plays saved yet.").

**AC-1.5 — No undo:**  
There is no undo. The confirmation prompt in AC-1.1 and AC-1.2 is the only guard. (Undo is an explicit non-goal of this slice; see Section 5.)

---

### Story 2 — Delete All Plays

**As a** coach starting preparation for a new opponent,  
**I want to** clear all saved plays with a single action,  
**so that** I can start fresh without deleting plays one at a time.

#### Acceptance Criteria

**AC-2.1 — Delete All control:**  
A "Delete All" or "Clear Library" control is accessible from the Play Library screen when the library is not empty. It must not be reachable when the library is already empty (disabled or hidden).

**AC-2.2 — Confirmation required:**  
Tapping "Delete All" presents a destructive confirmation prompt that states the number of plays that will be removed (e.g., "Delete all 12 plays? This cannot be undone."). The confirm action is visually marked as destructive. A "Cancel" action is present and defaults to cancel.

**AC-2.3 — Outcome:**  
Confirming removes all plays from the list and from persisted storage. The screen transitions to the empty state.

**AC-2.4 — Persistence:**  
After Delete All, no plays are present on next app launch.

**AC-2.5 — Independence from Select mode:**  
Delete All is accessible without entering Select mode. It is a separate, clearly labeled action (not "Select All + Delete").

---

### Story 3 — Edit an Existing Play

**As a** coach who noticed a route digit typo in a saved play,  
**I want to** correct the play's formation, route digits, or motion without deleting and re-creating it,  
**so that** I can fix mistakes quickly and preserve the play's position in my library.

#### Acceptance Criteria

**AC-3.1 — Edit entry point:**  
Each play row in the library provides an affordance to enter edit mode for that play (e.g., a button, tap action, or swipe action distinct from Delete).

**AC-3.2 — Editable fields:**  
The edit surface allows the coach to change:
- Formation (any valid formation)
- Route digit string
- Motion (None, Stop, After/Go — or none if formation does not support it)
- Y Wheel toggle

Concept name is derived automatically from the new route digits and formation combination; it is not a direct input.

**AC-3.3 — Validation before save:**  
The edited play cannot be saved if the route digit string is invalid for the selected formation (same validation rules as the play creation flow). An error message is shown describing the problem.

**AC-3.4 — Save outcome:**  
Saving a valid edit updates the play in-place. The play retains its original position in the library list. The `savedAt` timestamp is updated to reflect the edit time.

**AC-3.5 — Derived concept re-evaluated:**  
After saving, the displayed concept name (if any) reflects the updated formation and route digits. If the new combination matches a named concept it is shown; otherwise the concept field is blank.

**AC-3.6 — Discard:**  
The coach can discard edits and return to the library without changing the saved play. The discard path is always accessible while in the edit surface.

**AC-3.7 — Persistence:**  
The updated play is reflected in persisted storage immediately after save. A subsequent app launch shows the edited version, not the original.

**AC-3.8 — Export consistency:**  
A play edited and then selected for PDF export produces output that reflects the edited formation, digits, motion, and derived concept — not the pre-edit values.

---

## 3. Out of Scope

This slice does not include:

- **Undo / restore deleted plays** — no undo stack, no recycle bin, no soft delete.
- **Reordering plays** — drag-to-reorder is a separate backlog item.
- **Duplicate / copy a play** — creating a copy as a starting point for a new play is not part of this slice.
- **Bulk edit** — editing multiple plays simultaneously is not in scope.
- **Play naming / labels** — adding a free-text coach note or custom name field to a play is not in scope.
- **iCloud sync or conflict resolution** — persistence remains local-only JSON.
- **Export of edited plays during the edit surface** — export is only available from the main library list.
- **Formation validation beyond route digit parsing** — no additional cross-field constraints beyond what the existing interpreter enforces.

---

## 4. Open Questions

**OQ-1 — Edit surface pattern:**  
Should editing load the play's values into the existing PlayCaller screen (navigating away from the library) or open a dedicated modal/sheet? The existing PlayCaller screen is the canonical input surface and already handles formation + digit + motion + wheel; re-using it reduces implementation risk and avoids a divergent input path. However it implies a navigation pattern change. Decision should be confirmed before architecture design begins.

**OQ-2 — Delete confirmation granularity:**  
For single-play delete via swipe, is a confirmation prompt necessary, or is swipe gesture sufficient as the guard (matching iOS Notes/Mail convention)? A confirmation prompt reduces accidental deletes but adds friction. Recommendation: require confirmation for now (library is not easily reconstructible); revisit after adoption feedback.

**OQ-3 — "Delete All" placement:**  
Where should Delete All live — toolbar button, Settings/contextual menu, or only within Select mode as a "Select All then Delete" flow? Keeping it in a menu reduces accidental activation but makes it less discoverable. Surfacing it explicitly in the toolbar (disabled when empty) is clearer for a small-list coaching tool. Architecture-system-design and UX should weigh in.

**OQ-4 — Position preservation on edit:**  
"Retains its original position" (AC-3.4) is the stated behavior. Confirm with Ken whether position-preservation is required or whether appending the edited play to the end is acceptable. Position preservation requires an index-based update rather than delete+append.

---

## 5. Success Metrics

- A coach can delete a mistakenly saved play without restarting the app or manually editing JSON.
- A coach can clear the library and start fresh in under 5 seconds.
- A coach can fix a route digit typo in a saved play without losing the play's position in the list.
- Zero cases of deleted plays reappearing after app relaunch.
- Zero cases of an edited play exporting stale (pre-edit) data.

---

## 6. Roles

| Role | Involvement | Notes |
|------|-------------|-------|
| product-owner | Spec author; AC owner | This document |
| software-engineer | Implementation | Store update method, edit surface, delete confirmations, UI wiring |
| sdet | Test strategy + execution | AC coverage for all delete paths, edit validation, persistence, export consistency; edge cases: last play deleted, invalid edit digits, discard with unsaved changes |
| performance-engineer | Assessment | Library is local JSON; no server round-trips. Assess whether list reload after edit/delete has any observable latency at realistic library sizes (50–200 plays). |
| security-engineer | Involvement assessment + review | Persisted data is local JSON written with `.completeFileProtection`. Assess whether edit path introduces any new data-handling risks (e.g., unvalidated input written to disk). |
| architecture-system-design | Design spec | `PlayLibraryStore.update(_:)` method design; edit surface navigation pattern; confirm OQ-1 and OQ-3 |
| ux-designer | Consultation | Confirmation dialog patterns, edit surface UX, Delete All discoverability, swipe vs explicit button conventions on iOS |
| scrum-master | Retrospective | After shipping; capture process learnings |

---

## Security Engineer Involvement Assessment

**Date:** 2026-06-08
**Author:** security-engineer
**Feature:** Play Library — Delete, Delete All, and Edit

---

### Threat Surface

This feature operates entirely within a single-user local iOS app with no networking, no accounts, no backend, and no inter-process communication. The persisted asset is `play-library.json` in the app's Documents directory, written with `.completeFileProtection` (encrypted at rest when the device is locked).

The edit path is the only surface that introduces meaningful new risk: it accepts user-supplied strings (formation name, route digits, motion label) and writes them to disk. Delete operations mutate existing data destructively but do not accept freeform user input and do not expand the attack surface beyond what `save()` already exposes.

**Threat vectors worth examining:**

1. **Unvalidated edit input written to persisted JSON (data integrity)**
   Route digits and formation name are stored as raw strings in `SavedPlay`. On save, they are re-serialized via `JSONEncoder` without re-running them through `RouteInterpreter.interpret()`. If the edit path bypasses the existing parser gate, a malformed or arbitrarily long string could be persisted and later cause a crash or bad output at export time.

2. **Index/ID confusion during in-place update (TOCTOU-lite)**
   `PlayLibraryStore.delete(at:)` operates on `IndexSet` (array position). If the edit surface holds a copy of a play by array index and the user simultaneously triggers another operation (rapid taps, background save), the store could delete or overwrite the wrong play. Swift's `@MainActor` isolation on `PlayLibraryStore` serializes all mutations through the main actor, which eliminates the classic data-race form of this issue — but the UI must pass a stable identity (UUID), not an index, to the update method.

3. **Overly large or adversarially crafted JSON surviving persist**
   Not a realistic external-attacker scenario here, but a coach could paste a very long string into the route digit field. The existing parser imposes length and character constraints (4–5 decimal digits); the edit path must route through the same parser, not a looser path.

4. **Export of stale/corrupt data after a partially failed edit**
   AC-3.8 requires that export reflects edited values. If `persist()` fails silently (as it does today — the error is only `print`-ed), the in-memory state and on-disk state diverge. On next launch the "edited" play reverts. This is a data-integrity failure visible to coaches on game day, not a confidentiality breach, but it is worth surfacing.

5. **No undo + irreversible delete (availability)**
   The spec explicitly declines undo. The confirmation guard is the only protection against accidental data loss. The risk is proportional: a coach losing a saved play is inconvenient, not catastrophic (plays can be re-entered). Confirmation UI must not be bypassable via rapid-tap or double-trigger.

**Attacker model assumption:** Single-user personal device; no remote adversary, no multi-user isolation requirements. Relevant adversaries are: (a) bugs that corrupt data, (b) UI patterns that allow accidental irreversible operations. External threat actors are not in scope.

---

### Risk Rating

**Overall: Low**

| Vector | Likelihood | Impact | Net |
|--------|-----------|--------|-----|
| Unvalidated edit input persisted to disk | Low (parser exists; risk is bypassing it) | Low (local JSON; no injection surface) | Low |
| Wrong-play mutation via index confusion | Low (@MainActor serializes mutations) | Low-Medium (data loss for one play) | Low |
| Accidental Delete All (no confirmation bypass) | Medium (fat finger; high-friction action) | Low-Medium (all plays lost; no undo) | Low-Medium |
| persist() silent failure causing state diverge | Low-Medium (existing pattern already has this gap) | Low (data reverts on relaunch; no corruption) | Low |

No finding rises above Low in this context. The personal-project risk profile and absence of networking, accounts, or sensitive data classify this feature as a low-security-surface change.

---

### Security Involvement Assessment

```
## Security Involvement Assessment

**Risk surface:** Local-only iOS app; edit path accepts user-supplied strings that
are serialized to an on-device JSON file protected with .completeFileProtection.
No network, no accounts, no inter-process exposure.

| Phase                       | Engagement level | Rationale                                                                 |
|-----------------------------|-----------------|---------------------------------------------------------------------------|
| Design                      | Light           | No new trust boundaries or auth surfaces introduced                       |
| Plan review (Step 5.5)      | Targeted        | One specific check: verify edit path routes through RouteInterpreter      |
| Implementation support      | Unlikely        | Low complexity; no crypto, session, or IAM decisions                      |
| Post-implementation review  | Light           | Static review of update() method + one targeted active check              |

**Escalation triggers:**
- Edit surface accepts freeform text fields NOT routed through RouteInterpreter
- Store update method is added without UUID-based lookup (uses array index instead)
- persist() failure is promoted to a thrown/returned error (changes silent-fail behavior)
- Feature scope expands to include iCloud sync, sharing, or any networking
```

---

### Specific Checks for Plan Review (Step 5.5)

The implementation plan must satisfy all of the following before implementation begins. Any plan that does not address these items should be revised first.

**Check 1 — Validation gate on the edit path (Critical)**
The plan must show that `PlayLibraryStore.update(_:)` (or equivalent) calls `RouteInterpreter.interpret(digits:formation:)` on the edited route digit string and rejects the update — returning an error to the UI — if parsing fails. It is not acceptable for the plan to write `SavedPlay` fields directly from unvalidated UI state. The same validation enforced by AC-3.3 must be enforced at the store layer as a second gate, not only in the view layer.

**Check 2 — UUID-based identity for update and delete (Important)**
The plan must use `SavedPlay.id` (UUID) as the key for locating a play to update or delete. Passing an array index across the async boundary between a selected-play view and the store is unsafe even under `@MainActor` if the list can be mutated between selection and confirmation (e.g., background Save triggered from the play caller screen). The plan should show `update(id: UUID, with: SavedPlayEdit)` or equivalent — not `update(at: IndexSet)`.

**Check 3 — Confirmation guards not bypassable (Important)**
The plan must wire confirmation dialogs (`.confirmationDialog` or `.alert` with destructive role) to the store mutation. The plan must not show a pattern where the deletion fires immediately and the dialog is displayed asynchronously afterward. iOS `confirmationDialog` is modal and serializes correctly; verify the plan uses this pattern rather than a custom imperative approach that could race.

**Check 4 — Error surfaced to the user on persist failure (Minor)**
Today `persist()` swallows errors with `print`. The plan should surface a persistence failure to the coach (e.g., brief error banner) so they know the edit did not survive. Not a security issue per se, but prevents silent data loss that erodes trust in the tool on game day. If the plan explicitly defers this, it must add a backlog entry.

**Check 5 — No new file path exposure**
The plan must not introduce a second file URL or file path derived from user input (e.g., per-play files named after formation strings). The single `play-library.json` path is controlled by the app; a user-input-derived filename would be a path-traversal risk even in a local context. Confirm the plan uses the existing `fileURL`.

---

### Post-Implementation Verification Scope

Given the Low overall rating, active verification is scoped to targeted checks rather than a full attack suite. The post-implementation security review should cover:

**Static code review (required)**

- Confirm `PlayLibraryStore.update(_:)` calls `RouteInterpreter.interpret()` before writing to `plays[]`.
- Confirm the update method signature uses UUID, not IndexSet.
- Confirm the `persist()` call inside `update()` is present and not skipped on the success path.
- Confirm `formationName` written to `SavedPlay` is sourced from `Formation.rawValue` (a closed enum), not from free text input.
- Confirm `motionLabel` written to `SavedPlay` is sourced from `ReceiverMotion.rawValue` (a closed enum), not from free text input. Only `routeDigits` is freeform; it must be the only field that passes through the parser gate.

**Active verification (targeted — 3 checks)**

1. **Invalid-digit persistence probe:** With the app running, navigate to edit a play, enter an invalid route digit string (e.g., "AAAA", "99999", empty string, 500-character string), and attempt to save. Confirm: (a) the UI shows a validation error, (b) `play-library.json` is NOT updated with the invalid value. Verify by reading the file after the attempt.

2. **Rapid-delete double-tap probe:** In Select mode, select one play, tap Delete, and immediately tap the confirmation button twice in rapid succession (simulating a double-tap). Confirm only one play is removed, not two, and the app does not crash or leave the list in an inconsistent state.

3. **Edit-then-export consistency check:** Edit a saved play (change formation and digits to a valid alternative). Export it to PDF. Open the PDF and confirm the rendered play reflects the edited values, not the original. This validates AC-3.8 and confirms the export path reads from updated persisted state.

**Out of scope for this feature's verification:**
- Auth bypass (no auth surface)
- IDOR / cross-user access (single-user, no accounts)
- SQL/command injection (no database, no shell execution)
- Network interception (no networking)

---

### Residual Risk After Fixes

After the plan-review checks pass and active verification completes:

- **Silent persist failure** remains a low residual risk until the error surfacing improvement is implemented. This is a data-availability issue, not a confidentiality or integrity breach. Acceptable residual for this slice; backlog entry required if deferred.
- **No undo for delete** is an explicit product decision (AC-1.5). The confirmation guard is proportionate for this app's use case and user profile. Residual data-loss risk is accepted.
- **No multi-device or iCloud conflict risk** because the feature is explicitly scoped to local-only storage. If iCloud sync is added in a future slice, security-engineer must be re-engaged as an escalation trigger fires.
