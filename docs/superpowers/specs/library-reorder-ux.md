# UX Recommendation: Play Library Reorder
**Feature:** library-reorder
**Author:** ux-designer
**Date:** 2026-06-09
**Status:** Consultation complete — ready for architecture-system-design

---

## Context and Frame

This consultation builds directly on `library-edit-delete-ux.md`. The same interaction context governs both:

- The library is a sideline tool used under time pressure, potentially with gloved hands.
- Mode clarity is critical: a coach entering Select mode must understand immediately what they can do there.
- The prior UX document established Select mode as the single entry point for bulk actions. This spec extends that mode to also support drag-to-reorder.

The primary UX risk in this feature is not the drag gesture itself — drag-to-reorder is a well-understood iOS idiom. The risk is **mode ambiguity**: does combining checkboxes and drag handles in one mode confuse coaches about what Select mode is for?

---

## 1. Assessment of Combined Select + Reorder Mode

### Verdict: Proceed with combined mode, with row layout changes to minimize confusion

The combined approach is defensible and ships without a second entry point cluttering the toolbar. The cognitive load concern is real but manageable with the correct row layout and a meaningful mode label change (see section below).

### The Case For Combined Mode

**iOS Mail and Reminders are the closest analogies.** In Mail's Edit mode, every row shows a checkbox (for selection) and supports drag-reorder via a handle simultaneously. In Reminders, the same Edit mode exposes both checkboxes and drag handles together. Users who have encountered either app — which includes most iOS users — will carry that mental model to this library. Combined mode is not exotic.

**Cognitive efficiency for the coach's actual job.** Before game day, a coach's workflow is: "sort plays into game-plan order, then select a subset to export to wristband cards." These two tasks are tightly coupled. Separate modes would force the coach to (1) enter Reorder, drag into order, exit, (2) enter Select, check plays, export. Combined mode lets them do both in one session without exiting.

**There is no destructive conflict between the two gestures.** A checkbox toggle is a tap; a drag handle activation is a long-press-and-drag. These gestures are mechanically distinct. The coach cannot accidentally drag when trying to tap, or accidentally select when trying to drag, because the gesture recognizer targets are different (the handle icon vs the row body).

### The Case Against, and Why It Does Not Win

**Concern: "If both controls are visible, do coaches understand what the mode is for?"**

This is a real concern. The existing "Select" button label implies only selection. If a coach taps Select intending only to delete two plays, they will also see drag handles — controls they did not expect. This is a mild surprise, not a blocker. The resolution is the mode label, not mode separation (see recommendation below).

**Concern: "Drag and selection state could conflict."**

When a coach drags a selected row, does the selection persist, get dropped, or cause visual confusion? This is a technical question for architecture, but the UX design must specify the expectation: **selection state persists through a drag.** A checked row that is dragged to a new position stays checked. The coach should not need to re-select plays after reorganizing. The engineering assessment of `List(selection:)` + `.onMove` compatibility (TQ-1 in the spec) must confirm this behavior is achievable.

**Concern: "Two separate modes are clearer."**

A separate Reorder button creates a different problem: the toolbar now has Done, Select, Reorder, and the ellipsis menu — four controls on a phone-width nav bar. At larger Dynamic Type sizes this collapses badly. Combined mode is the correct space-preserving choice.

### Recommended Mode Label Change: "Select" to "Edit"

The spec uses "Select" as the button label. This recommendation is a must-fix before ship:

**Change the trailing toolbar button label from "Select" to "Edit".**

Rationale:
- "Edit" is the iOS HIG-preferred label for list edit modes that support multiple actions (selection, deletion, reordering). `UITableView`'s `setEditing(_:animated:)` is called the "editing state" for a reason.
- "Select" implies only picking items. "Edit" signals that the mode supports manipulation of the list structure (order, presence) as well as item selection.
- Reminders uses "Edit" for its combined mode. Calendar uses "Edit." The coach's existing iOS fluency maps "Edit" to "I can change things in this list."

The Cancel button in the trailing position should update accordingly: when Select mode is active, the trailing button currently says "Cancel." That label should remain "Cancel" for the leading Done/Cancel toolbar pair (see section 3), but the trailing button label can be removed if the leading pair makes the exit path unambiguous.

**Revised toolbar in Edit/Select mode:**

```
[ Done ]     Play Library     [ Cancel ]
```

The trailing "Cancel" displaces the "Select"/"Cancel" toggle. Done and Cancel in the leading/trailing positions is the standard iOS editing pattern (mirroring what existing edit flows like Contacts and Calendar use). There is no need for "Select" to toggle back to "Cancel" in the trailing position if Done and Cancel already anchor the top bar.

One implementation note: the current code uses a single trailing `HStack` with a conditional showing either "Cancel" or "Select" plus the ellipsis menu. The ellipsis menu must be hidden in Edit mode (as it already is per the existing conditional), and the trailing slot shows only "Cancel" in Edit mode. This is consistent with the current code structure.

---

## 2. Drag Handle Design

### Icon

Use SF Symbol `line.3.horizontal` (the standard iOS reorder glyph — three horizontal lines). This is the same symbol used by Reminders, Files, and Shortcuts in their reorder modes. Coaches who have used any of those apps will recognize it immediately.

Do not use `arrow.up.arrow.down` — that reads as "sort" (an automatic sort action), not "drag to reposition."

**Color:** `.secondary` (the subdued gray tint). The handle is a structural affordance, not a content element. It should not compete visually with the play name and route digits.

**Font size:** Match the row's secondary text size — approximately `title3` or `body` weight. The handle should be clearly visible but not dominant.

### Position: Trailing Edge

Place the drag handle on the **trailing edge** of the row, after the `Spacer()`.

The current row layout is:

```
[ checkbox ]  [ play name | route digits ]  [ concept · motion ]  [ spacer ]
```

In Edit mode, the updated layout is:

```
[ checkbox ]  [ play name | route digits ]  [ concept · motion ]  [ spacer ]  [ drag handle ]
```

**Why trailing, not leading:**

- Leading is where iOS standard checkboxes live (Mail, Reminders, Files). The checkbox is already on the leading edge in Edit mode. Putting the handle there too creates a cramped pair of icons and forces a gesture disambiguation problem (did the coach mean to tap the checkbox or grab the handle?).
- SwiftUI's built-in `onMove` places the reorder control on the trailing edge. Using the same position matches the behavior coaches have already seen in Apple's own apps and avoids training a new spatial expectation.
- The row's primary content (formation name + route digits) is on the leading side. Flanking the content with checkbox (leading) and handle (trailing) creates visual balance and clear functional zones: "left side selects, right side moves."

### Touch Target

The drag handle must be at least 44x44 pt to meet the HIG minimum. The `line.3.horizontal` symbol at default image rendering is smaller than this. Pad it explicitly:

```
Image(systemName: "line.3.horizontal")
    .frame(width: 44, height: 44)
    .contentShape(Rectangle())
```

This padding is invisible but makes the handle comfortably grabbable with a gloved or sweaty finger.

### Handle as a `DragHandle` affordance

The handle icon should not respond to taps (no `.onTapGesture`). It is a visual affordance that the SwiftUI reorder machinery activates. The engineer should confirm that SwiftUI's `.onMove` on the `ForEach` produces the standard handle behavior automatically, or wire it manually if needed given the `List(selection:)` + `.onMove` interaction constraint raised in TQ-1.

---

## 3. Done / Cancel Affordance

### Recommended Toolbar Layout in Edit Mode

```
[ Cancel ]     Play Library     [ Done ]
```

Wait — this is the *inverse* of the current implementation. Let me address the tension directly.

The current code places "Done" on the **leading** side and "Cancel" (toggled from "Select") on the **trailing** side in non-select mode. For the edit mode, the spec says Done commits the reorder and Cancel discards it.

**Recommendation: Swap to Cancel-leading, Done-trailing in Edit mode, matching iOS edit sheet conventions.**

iOS HIG specifies: for editing modes (sheets, inline list editing), place the cancel/dismiss action on the leading (left) side and the commit/save action on the trailing (right) side. This is the pattern in:
- Contacts edit view: Cancel (leading), Done (trailing)
- Calendar event edit: Cancel (leading), Add/Save (trailing)
- Reminders edit: Cancel (leading), Done (trailing)
- The existing EditPlayView in this codebase (per the prior UX spec): Cancel (leading), Save (trailing)

The current library in **non-edit mode** uses "Done" on the leading side as a dismiss button for the library sheet itself. That "Done" is unrelated to any commit action — it just closes the sheet. This is already a non-standard use of the leading Done position (the HIG typically uses "Done" on the leading side of a non-editable view, not an editable one), but it is shipped and not worth changing now.

The key requirement is that in **Edit mode**, the two primary controls — commit reorder (Done) and discard reorder (Cancel) — are clearly labeled and spatially separated. The recommended layout:

```
Normal mode:   [ Done (dismiss) ]     Play Library     [ Edit ]  [ ... ]
Edit mode:     [ Cancel ]             Play Library     [ Done ]
```

This gives Edit mode a canonical iOS editing chrome. The "Done" in normal mode (library dismiss) and the "Done" in Edit mode (commit reorder) are different actions with the same label, which is a known source of subtle confusion — but this is the iOS-standard naming convention and coaches will have seen it in Reminders, so it is acceptable. The spatial separation (normal-mode Done is prominent and persistent; Edit-mode Done replaces both the Select button and the normal-mode Done simultaneously) disambiguates them at a glance.

### Cancel Behavior — Must Communicate Discard

The Cancel button in Edit mode must discard both reorder changes AND deselect all checkboxes. It returns the library to its pre-session state with zero writes to disk.

**This is a behavior change from the current implementation.** The current Cancel button (line 53-56 of `PlayLibraryView.swift`) exits Select mode and clears `selectedIDs` — it does not need to discard a reorder because reorder does not exist yet. Once reorder is added, Cancel must also restore the pre-session `plays` array order.

The spec captures this correctly in AC-2.3 and OQ-4. The UX-specific confirmation: **do not ask the coach to confirm cancellation.** A confirmation dialog on Cancel ("Discard reorder changes?") is disproportionate friction for a list reorder. The coach expects Cancel to be a clean escape hatch. Reordering a list is not a transaction the coach needs to review before discarding. The only case where a cancel confirmation would be warranted is if Cancel also discarded typed input — which it does not here.

### Copy Guidance

- Done button: label "Done" — not "Save" (reorder is not a save in the document sense; it is committing a list arrangement)
- Cancel button: label "Cancel" — consistent with the prior Cancel in Select mode
- No secondary copy is needed in the toolbar (e.g., no "Drag to reorder" hint text). The handles are self-explanatory for iOS users.

---

## 4. Disabled State for 1-Play Library

### Specification

When the library contains exactly 1 play, Edit mode can still be entered (the coach may need Select mode for delete or export). The drag handle is rendered in a visually muted state and does not respond to gesture.

### Visual Treatment

Use `.opacity(0.3)` on the handle icon for the disabled state — enough to communicate "this exists but is not usable right now" without removing it from the layout. This preserves row layout consistency (no row-width shift between 1-play and 2-play states) and keeps the handle discoverable ("I see this handle; as soon as I add a second play it will work").

Do not use `.hidden()` — hiding the handle in the 1-play case and showing it in the 2-play case causes a row width change that looks like a bug rather than a state transition.

Do not use a popover or tooltip to explain the disabled state. The handle is already a niche affordance; adding explanation scaffolding for the edge case where it cannot be used adds complexity with negligible benefit. If coaches repeatedly request explanation, a short-run onboarding tooltip is a post-ship option.

### Accessibility

The disabled handle must have an accessibility label that communicates its state:

```
.accessibilityLabel("Reorder")
.accessibilityHint("Reordering requires at least 2 plays")
.accessibilityValue(store.plays.count == 1 ? "Not available" : "")
```

This ensures a VoiceOver user understands why the handle does not respond, rather than encountering silent non-interaction.

---

## 5. Transition Animations

### Enter Edit Mode (Select button tapped)

The checkboxes and drag handles should animate in together. The recommended approach matches what SwiftUI already does for its built-in edit mode: a leading-edge slide-in for the checkboxes and a trailing-edge slide-in (or fade) for the drag handles.

Because the drag handles are custom UI (not the built-in SwiftUI reorder control, given the `List(selection:)` + `.onMove` TQ-1 constraint), the handles need an explicit animation:

```
.transition(.opacity.combined(with: .move(edge: .trailing)))
```

A short duration (0.2–0.25 seconds, matching the standard iOS spring curve) is appropriate. Fast enough to feel responsive; slow enough for the coach to see what appeared.

The row layout shift (content column narrows slightly to accommodate the trailing handle) should also animate within the same transition. If the row uses a fixed `HStack` with a `Spacer`, the spacer absorbs the width change without a visible shift — no special animation needed for the content.

**Swipe action availability:** Swipe actions are already suppressed in Select/Edit mode (lines 161-174 of `PlayLibraryView.swift` guard `!isSelectMode`). No additional animation work is needed for this.

### Exit Edit Mode (Done or Cancel tapped)

On Done: handles and checkboxes should animate out with the same transition in reverse (fade + trailing-edge slide out). The list should reflect the committed order without any visual shuffle — the coach already saw the list in its new order during the drag session.

On Cancel: same animation for handles and checkboxes disappearing. Additionally, if the coach dragged any rows during the session, the list will visually return to the pre-session order. This is a potentially jarring jump — rows snapping back to their original positions. To soften this, wrap the array restoration in `withAnimation(.easeInOut(duration: 0.3))` in the Cancel handler. This produces a short animated re-sort that communicates "these changes were discarded" rather than a confusing instantaneous reset.

### Toolbar Transition

The normal-mode toolbar (Done-dismiss + Edit + ellipsis) should swap to the Edit-mode toolbar (Cancel + Done-commit) with a standard `.transition(.opacity)`. SwiftUI `toolbar` content does not natively animate transitions, but the replace is fast enough (< 1 frame) that no explicit animation is needed. If Xcode's SwiftUI toolbar produces a visible flash, wrap the `isSelectMode` toggle in `withAnimation(.easeInOut(duration: 0.15))`.

---

## 6. Alternative Considered: Separate Reorder Button

The spec's Option A — a dedicated "Reorder" button in the toolbar — was considered before Ken resolved OQ-1 in favor of combined mode. For completeness, here is the UX assessment of that alternative and the reason combined mode is the right choice.

### What Option A Would Look Like

A "Reorder" button in the trailing toolbar alongside "Select" (and the ellipsis menu) would enter a mode where only drag handles are visible — no checkboxes. Exit would be via Done and Cancel with the same commit/discard semantics. Select mode would remain as-is, with only checkboxes and no drag handles.

### Why Option A Was the Right Question

The instinct behind Option A is sound: separate modes mean unambiguous affordances. When you are in Reorder mode, every interaction is about ordering. When you are in Select mode, every interaction is about picking. No mental overlap.

If the coach population were entirely novice iOS users unfamiliar with Mail or Reminders, Option A would carry more weight. Separate modes reduce the cognitive demand of "what does this interface want from me right now?"

### Why Combined Mode is Still Correct Here

**Toolbar overcrowding.** Adding "Reorder" produces:

```
[ Done (dismiss) ]    Play Library    [ Select ] [ Reorder ] [ ... ]
```

Three trailing items at base Dynamic Type sizes. At `accessibility4` or `accessibility5`, this collapses into an overflow menu or wraps unpredictably. The toolbar is already at capacity.

**Workflow coupling.** As established in Section 1, a coach's pre-game workflow combines ordering and selection. Forcing mode exits between these tasks adds friction to the most common real-world usage pattern.

**iOS precedent covers this combination.** Mail, Reminders, Files, and Shortcuts all use combined edit modes for exactly this reason. Coaches using iOS daily will carry that pattern here.

**The actual UX risk in Option A** is that it would require maintaining two separate mode states (isReorderMode, isSelectMode) with explicit guards to prevent simultaneous activation, and the spec's OQ-2 (selection cleared on mode transition) would need to be re-opened. More state, more edge cases, more potential for coaching-time failure.

**Verdict:** Combined mode is correct. The mode label change from "Select" to "Edit" (Section 1) and the trailing placement of drag handles (Section 2) are the design moves that make it work.

---

## 7. Row Layout Wireframe (Edit Mode)

This is the updated `PlayLibraryRow` layout in Edit mode with a checked play:

```
Normal mode (single play row):
┌─────────────────────────────────────────────────────────────┐
│   Trips Left  6794                                          │
│   Mesh · Stop                                               │
└─────────────────────────────────────────────────────────────┘

Edit mode (unchecked play):
┌─────────────────────────────────────────────────────────────┐
│ ○  Trips Left  6794                             ≡           │
│    Mesh · Stop                                              │
└─────────────────────────────────────────────────────────────┘

Edit mode (checked play):
┌─────────────────────────────────────────────────────────────┐
│ ●  Trips Left  6794                             ≡           │
│    Mesh · Stop                                              │
└─────────────────────────────────────────────────────────────┘

Edit mode (single-play library — handle disabled):
┌─────────────────────────────────────────────────────────────┐
│ ○  Trips Left  6794                            [≡]          │
│    Mesh · Stop                            (faded, ~30%)     │
└─────────────────────────────────────────────────────────────┘
```

Where `○` = `circle` (unselected), `●` = `checkmark.circle.fill` (selected), `≡` = `line.3.horizontal` (drag handle).

The content column (formation + digits + secondary labels) does not change width between modes. The `Spacer()` in the `HStack` absorbs the trailing handle's addition without shifting play names.

---

## 8. Full Select/Edit Mode Toolbar Wireframe

```
Normal mode (library non-empty):
┌─────────────────────────────────────────────────────────────┐
│ Done          Play Library                 Edit  [...]      │
└─────────────────────────────────────────────────────────────┘

Edit mode (nothing selected, no drags yet):
┌─────────────────────────────────────────────────────────────┐
│ Cancel        Play Library                         Done     │
├─────────────────────────────────────────────────────────────┤
│                    (bottom bar)                             │
│ Select All         Delete (dimmed)          Export (dimmed) │
└─────────────────────────────────────────────────────────────┘

Edit mode (2 plays selected):
┌─────────────────────────────────────────────────────────────┐
│ Cancel        Play Library                         Done     │
├─────────────────────────────────────────────────────────────┤
│                    (bottom bar)                             │
│ Select All           Delete 2                   Export 2   │
└─────────────────────────────────────────────────────────────┘
```

Done and Cancel in the top bar are independent of the bottom bar Delete/Export state. A coach can drag to reorder (affecting Done/Cancel persistence) without selecting anything (keeping Delete and Export dimmed). Or they can select plays to export without dragging anything. Or both. The controls are composable.

---

## 9. Must-Fix vs. Should-Fix vs. Nice-to-Have

### Must-Fix (required before ship)

- Button label "Select" must change to "Edit" to accurately describe the combined mode.
- Cancel in Edit mode must restore pre-session play order (not just clear checkboxes). Pre-session snapshot in `PlayLibraryStore` is required.
- Drag handle must be on the trailing edge (not leading), visually separated from the checkbox.
- Drag handle must meet 44x44 pt touch target minimum.
- Disabled handle must be visually muted (`.opacity(0.3)`) for 1-play library — not hidden.
- Cancel animation must use `withAnimation` when restoring pre-session order, so the coach sees a discard transition rather than a confusing instant reset.
- Toolbar layout in Edit mode must be Cancel (leading) / Done (trailing) — matching iOS editing conventions.

### Should-Fix (strongly recommended)

- VoiceOver label for the drag handle: `"Reorder [Formation] [RouteDigits]"` to identify which row is being moved.
- VoiceOver hint for the disabled handle: "Reordering requires at least 2 plays" so VoiceOver users understand the constraint.
- Handle enter/exit animation (`transition(.opacity.combined(with: .move(edge: .trailing)))`) for a polished mode transition — not required for correctness but prevents jarring appearance.

### Nice-to-Have (post-ship, backlog)

- Haptic feedback when a drag is released and the row settles into its new position (`.impactOccurred()` on `UIImpactFeedbackGenerator`). On a noisy sideline, haptic confirmation reinforces "that move stuck."
- "Reorder" accessibility action on each row (an accessibility custom action that lets VoiceOver users move a row up or down without the drag gesture, per HIG accessibility guidance for list reorder).
- A brief subtitle or empty-state tooltip the first time a coach enters Edit mode: "Drag to reorder" shown once and never again. This is purely onboarding sugar.

---

## 10. Assumptions and Research Risks

**Assumption worth challenging:** The recommendation that combined mode is clear rests on the assumption that this coach population has used iOS Mail or Reminders and carries the "Edit mode does both" mental model. If the coach audience skews heavily toward Android switchers or low-iOS-fluency users, a brief onboarding tooltip on first Edit mode entry would close the gap without requiring mode separation. This is a nice-to-have, not a must-fix, because the Edit label change and trailing handle position already communicate the affordances at a glance.

**Unknown requiring architecture confirmation (TQ-1):** Whether SwiftUI `List(selection:)` + `.onMove` can be active simultaneously without forcing a workaround (e.g., disabling the selection binding during a drag, then re-enabling on drop) is unresolved. If architecture determines they cannot coexist without a workaround, the UX impact is: selection state may flicker or temporarily clear during a drag. If this occurs, the engineer must restore selection state on drop completion, and the UX recommendation is to make that restoration invisible (no animation of checkbox state changes during or after a drag). The coach should never see a checked play become unchecked because they dragged it.

**Unknown about Cancel with mixed changes:** If a coach both selects plays AND reorders the list during one Edit session, then taps Cancel — the expected behavior is: all selections cleared, list order restored. This is the spec's stated behavior (AC-2.3) and requires no additional UX treatment. The only nuance: if the coach has already tapped "Export 2" and the export sheet is showing, they are inside the export flow, not the Edit/Cancel flow. Architecture should confirm whether the export sheet can be presented while Edit mode is still active and how dismissing the export sheet interacts with the still-active Edit mode.
