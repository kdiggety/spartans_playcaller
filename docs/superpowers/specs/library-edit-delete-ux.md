# UX Recommendation: Library Edit and Delete
**Feature:** library-edit-delete  
**Author:** ux-designer  
**Date:** 2026-06-08  
**Status:** Consultation complete — open questions answered

---

## Context and Frame

The Play Library is a sideline tool used by a football coach under time pressure, often while a play clock is running. The interaction model must prioritize:

- **Speed of correct action** over discoverability of all features
- **Protection against catastrophic mistakes** (deleted plays with no undo)
- **Minimal mode switching** — a coach should not need three taps to reach the right surface

The library today is a modal sheet (`PlayLibraryView`) presented over `PlayCallerView`. It uses a plain `List` with `onDelete` (swipe) and a Select mode accessed via a trailing nav button. The bottom bar in Select mode currently holds one control: Export.

---

## 1. Recommended Interaction Patterns

### 1a. Delete a Single Play — Swipe Action with Confirmation

**Pattern:** Swipe left reveals a "Delete" button (`.destructive` role, red). Tapping it triggers a SwiftUI `Alert`, not dismissal. The play is only removed after the coach taps "Delete" in the alert.

The existing `onDelete` closure (line 101–103 of `PlayLibraryView.swift`) fires immediately without any guard. This is the existing gap the spec identifies. The fix is to intercept the swipe action before calling `store.delete(at:)` and insert an alert.

**Alert copy:**
- Title: "Delete Play?"
- Message: "[Formation] [RouteDigits]" — e.g., "Trips Left 6794"
- Buttons: "Delete" (`.destructive`) | "Cancel" (`.cancel`, default)

**Why confirmation is required here:** Football library plays are not trivially reconstructable — the coach would need to remember the exact digit string and formation. Notes and Mail skip confirmation because those items can be recovered or reconstructed; this library has no undo. One-tap deletion of irreplaceable data is too risky for the context.

**Implementation note for engineer:** SwiftUI's `onDelete` modifier does not natively support async confirmation. The pattern requires replacing `onDelete` with a `.swipeActions` modifier on the `ForEach` row, which allows a button with `.destructive` role to display an intermediate `Alert` state rather than performing the delete directly.

---

### 1b. Delete Selected Plays (Select Mode) — Bottom Bar Button

**Pattern:** When one or more plays are selected, a "Delete" button appears in the bottom bar alongside Export. Tapping it presents an alert with the count.

**Alert copy:**
- Title: "Delete [N] Play[s]?"
- Message: "This cannot be undone."
- Buttons: "Delete [N] Play[s]" (`.destructive`) | "Cancel" (`.cancel`, default)

The count in the confirm button is intentional: it forces the coach to register the magnitude ("Delete 8 Plays" reads differently than just "Delete"). This is not a burden — it is a one-read safety check appropriate for a permanent action.

After confirming, the library exits Select mode and returns to the list (or empty state if all plays were deleted).

**Bottom bar layout in Select mode (updated):**

```
[ Select All ]                    [ Delete N ]  [ Export N ]
```

Delete is placed to the left of Export. Export is the primary action; Delete is secondary and spatially separated. "Select All" stays on the left as today.

---

### 1c. Delete All — Toolbar Menu Item (Not a Standalone Toolbar Button)

See OQ-3 resolution below for full reasoning. The recommended placement is a `Menu` on the trailing toolbar, appearing only when the library is non-empty and Select mode is inactive.

**Menu label:** ellipsis (`...`) — standard iOS contextual menu icon

**Menu items:**
- "Delete All Plays" (`.destructive` role)

This keeps Delete All reachable in two taps from the library screen (tap menu, tap Delete All) without occupying permanent real estate. The confirmation alert that follows provides the final guard.

**Alert copy:**
- Title: "Delete All [N] Plays?"
- Message: "This cannot be undone."
- Buttons: "Delete All [N] Plays" (`.destructive`) | "Cancel" (`.cancel`, default)

---

### 1d. Edit a Play — Row Trailing Action + Dedicated Sheet

See OQ-1 resolution below for full reasoning. Each play row exposes an "Edit" trailing swipe action alongside Delete. Tapping it opens a dedicated modal sheet populated with the play's current values.

**Row swipe layout:**

```
[ swipe left reveals: ]   [ Edit (blue) ]  [ Delete (red) ]
```

Edit is on the outer position (tapped first when swiping partially), Delete is inner (requires a fuller swipe or deliberate second tap). This matches the Mail convention where Archive/Edit is more accessible than Delete.

---

## 2. Open Questions — Answered

### OQ-1: Edit Surface Pattern

**Recommendation: Dedicated modal sheet, not navigation to PlayCallerView.**

Rationale:

1. `PlayCallerView` is a full `NavigationStack` with its own toolbar, title, and state. Loading an existing play into it would require the ViewModel to accept pre-seeded values and then surface a "Save Edit" vs "Save New" distinction that does not exist today. The surface was designed for play creation, not amendment.

2. Navigating away from the library sheet to `PlayCallerView` breaks the modal flow — the coach loses their place in the library and the back-navigation intent becomes ambiguous ("am I going back to the library or discarding the edit?").

3. A sheet with the title "Edit Play" and a clear "Save" / "Cancel" affordance matches the iOS convention for in-place record editing (Contacts, Calendar events, Reminders). Coaches on competing apps (Hudl, XOS) will recognize this pattern.

4. Implementation risk is real but bounded: the sheet needs the same four inputs (formation picker, route digit field, motion picker, Y Wheel toggle) plus a Submit button. These are all self-contained SwiftUI controls. The ViewModel can be adapted or a lightweight edit-specific ViewModel created.

**What to avoid:** Do not push an embedded view inside the existing library sheet navigation. Sheets on top of sheets (two levels deep) are confusing and hard to dismiss cleanly. The edit sheet should be a single-level `.sheet()` presented from the library.

---

### OQ-2: Swipe Confirmation Necessity

**Recommendation: Confirmation alert is required for single-play swipe delete.**

Already addressed in section 1a. The key signal: this data has no undo and is not easily reconstructed. The swipe gesture alone is not a sufficient guard for permanent deletion of plays a coach may have carefully curated.

Additional supporting context: the coach's hands are gloved in cold weather or sweaty on a hot day. Accidental swipe completion is a realistic failure mode, not an edge case.

The friction added by a single confirmation tap is small relative to the cost of losing a play before a critical possession. This can be revisited after adoption data shows whether coaches feel the prompt is bothersome.

---

### OQ-3: Delete All Placement

**Recommendation: Contextual menu in the trailing toolbar, NOT a persistent toolbar button.**

Against a persistent toolbar button:
- "Delete All" is a low-frequency, high-risk action. Giving it permanent toolbar real estate alongside everyday controls (Done, Select) creates accidental-tap risk and visual noise.
- The toolbar is already occupied with Done (leading) and Select/Cancel (trailing). Adding a third trailing item creates crowding, especially at Dynamic Type sizes.

Against Select mode as the only path:
- The spec explicitly requires Delete All to be reachable without entering Select mode (AC-2.5). This is correct — "Select All then Delete" is the wrong UX for a coach who just wants to wipe the slate. It requires four taps where two should suffice.

For the Menu approach:
- A `Menu` button (ellipsis or a named "More" label) is the iOS-native solution for low-frequency, contextual library-level actions. It is discoverable (coaches who want more options tap the ellipsis) without cluttering the default state.
- The Menu can be extended later without breaking the toolbar layout (e.g., if "Sort Library" or "Rename" are added in future slices).

**Toolbar layout (non-select mode):**

```
[ Done ]              Play Library              [ Select ]  [ ... ]
```

The `...` Menu button is hidden when the library is empty (the only item in it would be Delete All, which is disabled when empty; hiding the button avoids a visible-but-dead control).

---

### OQ-4: Position Preservation on Edit

**Recommendation: Preserve position (index-based update), not append-to-end.**

For a sideline library, play order is often intentional — coaches organize by formation family, game-plan sequence, or down-and-distance group. Appending an edited play to the end breaks that arrangement silently, which erodes trust in the tool. The coach opens the library expecting "Trips Left 6794" to be in slot 3 and it is now at the bottom.

Index-based update is the correct semantic. The `savedAt` timestamp update is appropriate for display purposes (last-modified recency) but should not be used as a sort key unless sorting by recency is explicitly added in a future slice.

---

## 3. iOS HIG Alignment

| Pattern | HIG Alignment | Notes |
|---------|---------------|-------|
| Swipe-to-delete with `.destructive` button | Matches HIG "Swipe actions in lists" | `.swipeActions` is the current preferred API over `onDelete` |
| Confirmation alert before destructive action | Matches HIG "Alerts" — use for high-consequence, irreversible actions | Required here; optional for easily undoable actions |
| `.destructive` button role in alerts | Correct — renders red, communicates finality | |
| Defaulting "Cancel" to the cancel role | Matches HIG — non-destructive option must be easy to reach | |
| Modal sheet for Edit | Matches HIG "Modality" — present modally when an action requires focused attention and completion before returning | |
| "Cancel" + "Save" in edit sheet header | Matches HIG pattern for editing sheets (Cancel leading, Save/Done trailing) | |
| Menu for low-frequency actions | Matches HIG "Menus" — surface contextual options without cluttering primary chrome | |

One HIG tension to acknowledge: the HIG notes that action sheets (`.confirmationDialog`) are preferred over alerts for choices with more than two options, while alerts are preferred for single yes/no decisions. All confirmation dialogs in this feature are binary (Delete / Cancel), so `Alert` is the correct choice — not `confirmationDialog`, which the existing export flow uses correctly for a three-option choice.

---

## 4. Accessibility Considerations

### Destructive Button Styling
- All Delete buttons must use `.role(.destructive)` in SwiftUI. This applies the system red color automatically in both light and dark mode, meeting WCAG contrast requirements without custom color values.
- Do not suppress the red color for aesthetic reasons. On a coaching sideline app, high-contrast destructive signaling is a safety feature.

### Confirmation Dialog Focus Order
- When an Alert appears, VoiceOver focus moves to the alert automatically. The Cancel button should be listed first (or be the default action) so that a coach using Switch Control or VoiceOver can dismiss without accidentally confirming a delete.
- SwiftUI's `Alert` with `.cancel` role on the Cancel button handles this correctly by default.

### VoiceOver Labels — Row Actions
- The swipe-to-delete action must have an explicit accessibility label: `"Delete [Formation] [RouteDigits]"` — not just "Delete". This identifies which play is being deleted for a coach using VoiceOver.
- The edit swipe action label: `"Edit [Formation] [RouteDigits]"`.
- Both labels should be set via `.accessibilityLabel()` on the swipe action button.

### Edit Sheet Accessibility
- The edit sheet's Save button must be disabled (and its accessibility state communicated) when the digit input is invalid. Use `.accessibilityHint("Route digits are invalid")` when disabled so VoiceOver users understand why they cannot proceed.
- Formation picker, motion picker, and Y Wheel toggle should all retain their existing accessibility patterns from `PlayCallerView` — no new patterns needed.

### Select Mode Delete Button
- The bottom bar Delete button in Select mode must reflect its state: when zero items are selected, it is disabled. VoiceOver should announce `"Delete, dimmed"` automatically if the button uses the standard SwiftUI disabled state.

### Minimum Touch Target
- The Edit button in the swipe action and the Delete button must meet the 44x44 pt minimum touch target. SwiftUI `.swipeActions` handles this by default with standard button sizing.

---

## 5. Edge Cases

### Empty State After Delete All
The existing empty state view (`emptyState` computed property, lines 73–86 of `PlayLibraryView.swift`) is already implemented and reads: "No plays saved yet." with a supporting instruction. After Delete All, this view should appear immediately.

One copy adjustment recommended: after Delete All, the supporting text "Build a play and tap the bookmark button to save it here." remains accurate and helpful. No separate post-delete empty state copy is needed.

The `...` menu button should disappear or become hidden when the library transitions to empty (since Delete All is its only item). Alternatively, keep the button visible but disable and hide it — the simpler implementation is to bind its display to `!store.plays.isEmpty`.

### Cancel from Edit with Unsaved Changes

This is the most nuanced edge case. Two sub-cases:

**Sub-case A: No changes made.** Coach opened Edit, changed nothing, tapped Cancel. Dismiss the sheet immediately. No prompt needed — there is nothing to lose.

**Sub-case B: Changes made, tapped Cancel.** Present a confirmation action sheet:
- Title: "Discard Changes?"
- Buttons: "Discard Changes" (`.destructive`) | "Keep Editing" (`.cancel`)

Do not use "Cancel" as the label for the dismissal option — "Keep Editing" is more specific and less ambiguous than "Cancel" when the parent button is already labeled "Cancel."

**Detecting changes:** Compare the current edit-surface state against the original `SavedPlay` values on Cancel tap. If all four fields match the original, dismiss without prompt. If any field differs, show the confirmation.

**Implementation note:** The edit ViewModel should track an `isDirty` flag initialized to false, set to true on any field change. This avoids expensive equality comparisons on tap.

### Invalid Digits on Save Attempt
If the coach taps Save with an invalid digit string (e.g., wrong count for the formation), the existing error banner pattern from `PlayCallerView` (`errorBanner(_ message:)`, lines 279–290) should be used directly in the edit sheet. Same visual treatment, same language. No new error pattern is needed.

The Save button may remain enabled (let the coach attempt and see the error inline) rather than disabling it reactively as the coach types. This matches the existing play creation flow, where the error only appears after input, not on each keystroke.

### Deleting the Only Remaining Play via Swipe
If there is one play and the coach swipes to delete it, the flow is: swipe -> Delete button appears -> tap Delete -> alert appears -> "Delete" confirmed -> list transitions to empty state.

The transition should be immediate (no animation delay). SwiftUI's `List` with `withAnimation` wrapping the store deletion will handle this naturally.

### Select All then Delete
A coach could tap Select, Select All, then Delete. This is a valid path to Delete All that does not need to be blocked. The resulting alert should say "Delete 12 Plays?" (using the count) — same pattern as any multi-select delete. This path runs through AC-1.2, not AC-2.2, but the user experience is equivalent.

---

## 6. Flows and Wireframes

### Edit Sheet — States and Flow

```
┌─────────────────────────────────────────────┐
│  Cancel          Edit Play          Save     │  <- Nav bar
├─────────────────────────────────────────────┤
│                                             │
│  FORMATION                                  │
│  [ Trips ] [ Twins ] [ Pro ] [ Tight ]      │  <- Segmented picker (formation family)
│  [ Left  ] [       Right        ]           │  <- Side picker (if applicable)
│                                             │
│  ROUTE DIGITS                               │
│  ┌──────────┐                               │
│  │  6 7 9 4 │   X  Y  Z  A  H              │  <- Monospaced text field + hint
│  └──────────┘                               │
│                                             │
│  ┌─────────────────────────────────────────┐│
│  │  X  6  Left    Curl                     ││  <- Read-only assignment preview
│  │  Y  7  Right   Post                     ││     (derived, not editable)
│  │  Z  9  Left    Fade                     ││
│  │  A  4  Right   Drag                     ││
│  └─────────────────────────────────────────┘│
│                                             │
│  MOTION                                     │
│  [ None ] [ Stop ] [ After/Go ]             │  <- Only if formation supports it
│                                             │
│  Y Wheel  ●────────────────────○            │  <- Toggle
│                                             │
└─────────────────────────────────────────────┘

STATE: Invalid digits entered
┌─────────────────────────────────────────────┐
│  ⚠️  Invalid route digits for Trips Left    │  <- Error banner (existing pattern)
│      Expected 4 digits, got 3.              │
└─────────────────────────────────────────────┘
  Save button: still tappable; error shows after attempt
  OR: Save button disabled with hint text (simpler, preferred)

STATE: No changes (isDirty = false)
  Cancel tap -> immediate dismiss, no prompt

STATE: Changes made (isDirty = true)
  Cancel tap -> Action Sheet:
  "Discard Changes?" / "Keep Editing" / "Discard Changes [destructive]"
```

---

### Delete Single Play — Swipe Flow

```
Library list (normal state):
┌─────────────────────────────────────────────┐
│  Trips Left  6794                           │
│  Mesh · Stop                               │
├─────────────────────────────────────────────┤
│  Pro Right   5321                           │
│                                             │
└─────────────────────────────────────────────┘

After partial swipe left on row 1:
┌─────────────────────────────────────────────┐
│  Trips Left  6794           │ Edit │ Delete │  <- Edit (blue) | Delete (red)
│  Mesh · Stop               │      │        │
└─────────────────────────────────────────────┘

After tapping Delete:
┌─────────────────────────────┐
│  Delete Play?               │
│  Trips Left 6794            │  <- Names the specific play
│                             │
│  [    Cancel    ]           │  <- Default focus (cancel role)
│  [    Delete    ]           │  <- Destructive (red)
└─────────────────────────────┘
```

---

### Delete All — Menu Flow

```
Toolbar (non-select, library non-empty):
[ Done ]     Play Library     [ Select ]  [ ... ]

Tap [...]:
┌───────────────────────┐
│  Delete All Plays     │  <- Red (destructive)
└───────────────────────┘

Tap "Delete All Plays":
┌──────────────────────────────────────┐
│  Delete All 12 Plays?                │
│  This cannot be undone.              │
│                                      │
│  [          Cancel          ]        │  <- Default (cancel role)
│  [   Delete All 12 Plays   ]        │  <- Destructive (red)
└──────────────────────────────────────┘
```

---

### Select Mode — Updated Bottom Bar

```
Bottom bar with 2 plays selected:
┌─────────────────────────────────────────────┐
│ Select All      [ Delete 2 ]  [ Export 2 ]  │
└─────────────────────────────────────────────┘

Tap "Delete 2":
┌──────────────────────────────────────┐
│  Delete 2 Plays?                     │
│  This cannot be undone.              │
│                                      │
│  [        Cancel        ]            │
│  [    Delete 2 Plays    ]            │
└──────────────────────────────────────┘
```

---

## 7. Must-Fix vs. Should-Fix vs. Nice-to-Have

### Must-Fix (required before ship)
- Swipe delete must have a confirmation alert. Current `onDelete` fires immediately — this is a data-loss risk.
- Edit must be a dedicated sheet, not navigation into PlayCallerView.
- Discard-with-changes prompt is required. Silent discard of edits is a data-integrity failure.
- Delete button in Select mode must be disabled when zero items are selected.

### Should-Fix (strongly recommended)
- `isDirty` tracking in the edit ViewModel to avoid spurious "Discard Changes?" prompts when nothing changed.
- VoiceOver labels on swipe actions naming the specific play being deleted or edited.
- Hide the `...` menu when the library is empty (or disable it) to avoid a visible-but-useless affordance.

### Nice-to-Have (post-ship, backlog)
- Assignment preview in the edit sheet (showing derived routes as the coach types) — improves confidence that the edit produces the intended play, but the coach can verify in the main PlayCaller screen after saving.
- Haptic feedback on successful delete (`.notificationOccurred(.success)` or `.warning` on destructive confirm) — reinforces completion on a noisy sideline.
- Subtle animation when a row is removed from the list after delete.

---

## 8. Assumptions and Research Risks

**Assumption worth challenging:** The recommendation that coaches will accept a confirmation tap before deletion is based on the principle that plays are not easily reconstructable. If field observation shows coaches find the double-tap annoying and rarely make accidental deletes (perhaps because swipe-to-delete is already rare enough), the confirmation for single-play delete could be removed in a v2. The export flow's `confirmationDialog` was kept frictionless because export is reversible; delete is not.

**Unknown:** Whether the coach uses the library in Select mode or primarily through individual row actions. If Select mode is the dominant pattern (coaches bulk-manage after practice), the bottom bar layout carries more weight than the swipe actions. If swipe is primary, swipe UX carries more weight. Observing usage patterns after ship would answer this.

**Assumption about position preservation:** The recommendation to preserve list position assumes coaches curate order intentionally. If logs or observation reveal coaches do not care about order (they scroll to find plays by recognition, not position), append-to-end simplifies the store update method with no user-visible cost. This is low-risk to implement correctly upfront; flag for data collection post-ship.
