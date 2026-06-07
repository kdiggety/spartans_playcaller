# UX Consultation: Epic 3.1 — Wristband Export

**Date:** 2026-06-07
**Author:** UX Designer
**Status:** READY FOR ARCHITECTURE REVIEW
**Source spec:** `docs/superpowers/specs/2026-06-07-wristband-export-spec.md`

---

## Scope of this consultation

This document covers: wristband card layout (Section 1), export entry point (Section 2), export action sheet and share flow (Section 3), V2 multi-select UX consideration (Section 4), accessibility requirements (Section 5), and open questions for Ken (Section 6).

The consultation is grounded in:
- The product spec (Epic 3.1, committed 2026-06-07)
- The current `PlayCallerView.swift` toolbar and result section structure
- Physical laminated-card constraints described in the spec (3.5" × 2.5", arm's-length readability, lamination glare)
- Existing receiver label convention ("X  Y  Z  A  H") already visible in the digit input section

---

## 1. Wristband Card Layout

### 1.1 Design constraints summary

A 3.5" × 2.5" card is approximately the size of a standard business card (landscape). At 300 dpi that is 1050 × 750 pixels. After a 0.25" margin on all sides the usable area is 3.0" × 2.0" (900 × 600 px). Lamination tends to reduce apparent contrast slightly and can soften hairline strokes — this reinforces using heavier font weights (medium/semibold at a minimum) and avoiding thin-stroke icons.

The card must be readable by a player at arm's length (~18 inches), in sunlight, with adrenaline. That is functionally equivalent to reading a printed business card held at normal distance: doable, but only if the primary fields are large and uncluttered.

### 1.2 Field priority and vertical order

Cards are held landscape. The hierarchy below flows top-to-bottom within the card, with the diagram taking the lower portion.

| Zone | Content | Why this position |
|------|---------|-------------------|
| Top-left corner | Play number (bold, large) | First thing a player's eye finds — this is what the coach called on the sideline |
| Top-right corner | Formation name | Immediately paired with the number; confirms context |
| Second row, left-aligned | Route digits with receiver labels | The play call proper; must be large and spaced |
| Third row, left-aligned (conditional) | Concept name (if matched) | Shorthand recognition — blank row if absent; do not use a placeholder |
| Third row, right-aligned (conditional) | Y Motion label (if not None) | Paired alongside concept or on its own row if concept absent |
| Lower 40% of card | Mini route diagram | Spatial confirmation; placed below text so text reads cleanly first |
| Bottom strip (optional at print time) | Notes line (single hairline rule) | Space for coach annotation; non-printing visual guide only |

Rationale for route digits on their own full row: the digit sequence plus its five receiver labels ("X  Y  Z  A  H") is the most information-dense field and needs the most horizontal space. Compressing it into a half-row would force a smaller font. The spec's 12pt floor for digits is achievable on a full row but not on a half row alongside another field.

### 1.3 Font size guidance

These are minimum printed point sizes. At 300 dpi, 1pt = 4.17 px. All sizes below are floor values — larger is better whenever space permits.

| Field | Min pt size | Weight | Notes |
|-------|-------------|--------|-------|
| Play number | 18pt | Bold | Cornerstone identifier; the largest element on the card |
| Formation name | 14pt | Semibold | Must read clearly at top of card |
| Route digits | 14pt | Medium or Semibold, monospaced | Match the app's existing `.system(.title2, design: .monospaced)` register |
| Receiver labels (X Y Z A H) | 9pt | Regular | Secondary; below the digit string |
| Concept name | 12pt | Semibold | Should be visually distinct from formation — use a capsule/badge style matching the app's `ConceptBadge` |
| Y Motion label | 11pt | Regular or Medium | Lower priority than concept; right-aligned in the same row |
| Notes line label ("Notes:") | 8pt | Regular | Minimal ink; the line itself is more important than the label |
| Diagram labels (receiver dots) | 8pt | Regular | Minimum for legibility inside the diagram; do not go below 8pt |

Lamination risk: fonts below 9pt may bleed slightly after lamination on a consumer laminator. The 8pt floor for receiver dot labels is the absolute minimum; if the diagram area is large enough to use 9pt, prefer it.

### 1.4 Mini diagram placement and sizing

The diagram occupies the lower 40% of the usable card area. At 3.0" × 2.0" usable, that is a 3.0" × 0.8" diagram area (landscape). This is narrow but workable because the diagram only needs to show receiver alignment and route breaks — it does not need to show field context (yard lines, end zones).

Placement rationale: Text at top, diagram at bottom is the conventional football wristband card pattern. Players scan text first (formation and digits), then use the diagram for spatial confirmation. Reversing this order (diagram on top) would cause the player's eye to enter at the most abstract element.

Diagram rendering note for the engineer: at the card's small footprint, the `DiagramConfig.standard()` proportions designed for a 320pt tall on-screen view will need recalculation. The diagram zone is roughly 216pt × 58pt at 72dpi (or proportionally larger at 300dpi). The `receiverRadius` should drop to approximately 4–5pt at print scale; route lines should be 1pt minimum weight (2pt preferred for lamination). `DiagramRenderer` will need a `DiagramConfig` factory method or override parameters for the card context rather than reusing `standard()` without modification.

### 1.5 Density trade-offs

The spec's content set (play number, formation, digits, concept, motion, diagram, notes) is achievable on a 3.5" × 2.5" card at readable sizes, but only if:

1. Concept and Y Motion do not each get their own full row. They share one row (concept left, motion right). When only one is present, it takes the full row. When neither is present, the row is absent (no empty whitespace from a placeholder).

2. The notes "field" is a single ruled line at the card's bottom edge, not a box. A box consumes height; a line adds almost none.

3. The mini diagram does not attempt to render at on-screen proportions. It must use a compressed `DiagramConfig` — a wide, shallow bounding box rather than the tall vertical canvas used on-screen.

Dropping the diagram to preserve text legibility is the wrong trade-off: the diagram is a required field per the spec, and it is the only element that gives a player spatial confirmation when reading an unfamiliar play. If density becomes an issue during implementation, the first thing to cut is the notes line (make it opt-in at print time), not the diagram.

### 1.6 ASCII card mockup

The mockup below represents the 3.5" × 2.5" card face at landscape orientation. Each character line approximates a real-world row of content. Boxes represent zones, not literal borders (the card likely has a thin border or a cut line, not a filled box).

```
+-------------------------------------------+
|  #1                    Twins              |
|                                           |
|  6   7   9   4                            |
|  X   Y   Z   A                            |
|                                           |
|  Smash                        Y Go        |
|                                           |
| - - - - - - - - - - - - - - - - - - - - -|
|                                           |
|   X  A  [ball]  Y  Z                      |
|   |   \         |   /                     |
|   v    \        v  /                      |
|   v     \       v /                       |
|                                           |
+-------------------------------------------+
|  Notes: _________________________________  |
+-------------------------------------------+
```

Key observations from the mockup:
- Play number (`#1`) is top-left, large — matches the spec's 14pt bold floor (recommend 18pt)
- Formation (`Twins`) is top-right — paired visually with play number on the same row
- Digit row uses monospaced spacing so each digit aligns above its receiver label
- Concept and motion share a row; neither dominates
- Diagram is a wide-shallow band occupying the lower 40%
- Notes line is the last element — a single rule, not a box
- A thin horizontal divider separates the text zone from the diagram zone (optional print aid for cutting guides, but also helps players separate "what to do" from "where to go")

---

## 2. Export Entry Point

### 2.1 Recommended placement

Add the share icon button to the navigation bar trailing area, placed to the **left** of the existing "Reset" button. This yields the trailing toolbar item order: `[Share] [Reset]`.

Rationale for left-of-Reset placement: "Reset" is a destructive action (clears state). "Share" is an additive action (produces an artifact). In iOS convention, the most-used non-destructive action lives closest to the leading edge of the trailing cluster. Placing Share before Reset also separates them visually, reducing the chance a coach tapping Share accidentally taps Reset instead.

The existing toolbar code is:

```swift
ToolbarItem(placement: .topBarTrailing) {
    Button("Reset", action: viewModel.reset)
        .font(.subheadline)
}
```

This becomes two `ToolbarItem` entries in a `ToolbarItemGroup` or two sequential `ToolbarItem` blocks. The share button uses `Image(systemName: "square.and.arrow.up")` — no label text, matching the iOS idiom for share.

### 2.2 Button states

| App state | Button appearance | Interaction |
|-----------|-------------------|-------------|
| No play call (initial state, post-reset) | Icon at reduced opacity (approximately 0.35), not tappable | Disabled |
| Valid play call showing | Icon at full opacity | Enabled — tapping triggers action sheet |
| PDF generation in progress | Icon replaced with `ProgressView` (small spinner) | Non-interactive during generation |

The disabled state must not be hidden — the button should remain visually present but clearly inactive. A coach who sees only a Reset button when no play is loaded and no Share button at all would expect Share to appear only after a play resolves; showing a disabled Share button from the start correctly sets the expectation that sharing is a feature of the current screen.

**Disabled state implementation note:** Use `.disabled(viewModel.currentPlayCall == nil && viewModel.currentPlayCallWithMotion == nil)` with `.opacity(isExportable ? 1.0 : 0.35)`. The `PlayCallerView` already evaluates `viewModel.currentPlayCallWithMotion ?? viewModel.currentPlayCall` to decide whether to show the result section — the export button uses the identical condition.

### 2.3 Icon choice

SF Symbol `square.and.arrow.up` is the correct choice — it is the iOS system share idiom, universally recognized by iOS users, and its meaning is not ambiguous in this context (there is no other "sharing" action in the app). No label is needed; the icon is self-explanatory in the context of a navigation bar.

Do not use a custom export icon or a printer icon (`printer`) — a printer icon would imply the action goes directly to print, which is incorrect (it goes to a share sheet where print is one of many options). The share arrow is the right semantic.

### 2.4 Toolbar button vs. inline result section

The spec notes this correctly: the export is a document-level action, not a field-level action. An inline button embedded in the result section (e.g., a "Share" button below the diagram) would imply the action operates on the diagram specifically, which is a narrower scope than "export the complete play as a wristband card." The toolbar placement unambiguously signals document-level scope.

An alternative considered: a context menu on the play header (`Text(playCall.displayName)`). This is a valid pattern for power users but is invisible on first use — no affordance signals that the text is long-pressable. The toolbar share button is the primary affordance; a context menu could be added as a secondary path in V2 if Ken requests it.

---

## 3. Export Action Sheet and Share Flow

### 3.1 Action sheet vs. direct share sheet

The spec specifies a two-step flow: action sheet first, then the system share sheet. This consultation endorses that approach but documents the trade-off clearly so Ken can make an informed decision if he wants to simplify.

**Two-step (spec recommendation):**
1. Tap Share button
2. Action sheet appears: title "Export Wristband Card", subtitle "[Formation] [Digits]", options "Export as PDF" and "Cancel"
3. Tap "Export as PDF"
4. PDF generates
5. UIActivityViewController presents

**One-step (direct to share sheet):**
1. Tap Share button
2. PDF generates immediately
3. UIActivityViewController presents

The two-step flow adds a confirmation moment: the coach sees the play name in the action sheet subtitle before committing. Given that V1 exports exactly one play with no undo (once the share sheet appears the PDF is already generated), the confirmation is useful for a sideline context where the coach may have bumped the share button accidentally. The extra tap cost is one tap. Recommendation: keep the two-step flow for V1.

### 3.2 Action sheet content specification

```
Title:   Export Wristband Card
Message: [Formation rawValue] [routeDigits]
         (Example: "Twins 6794")

Option 1: Export as PDF    [system default style, not destructive]
Option 2: Cancel           [cancel role — appears at bottom, separated]
```

Note: the message line uses `playCall.displayName` which already computes `"\(formation.rawValue) \(routeDigits)"`. This is exactly the confirmation text the coach needs — it names the play they are about to export.

If a concept matched, consider appending the concept name: "Twins 6794 · Smash". This is a nice-to-have (see Section 6, Open Question 3). It adds specificity without adding cognitive load.

### 3.3 Share sheet configuration

`UIActivityViewController` should be initialized with:
- `activityItems`: the generated `Data` wrapped as a `URL` to a temp file named `[FormationName]-[Digits]-wristband.pdf` (e.g., `Twins-6794-wristband.pdf`)
- `applicationActivities`: `nil` (no custom activities needed for V1)

The subject/title used by activities that send it (Mail, Messages) comes from the filename when a URL is passed rather than raw `Data`. Using a descriptive filename ensures email subjects and AirDrop previews read as "Twins-6794-wristband.pdf" rather than an opaque UUID. This is meaningful to coaching staff receiving the file.

**Why a temp file URL rather than raw Data:** `UIActivityViewController` handles raw `Data` but the share sheet title/subject for mail and messages pulls from the `UTTypeReference` — with raw data there is no filename. A temp `URL` gives the system a filename to use. The temp file should be written to `FileManager.default.temporaryDirectory` and is ephemeral — no persistence needed.

### 3.4 Loading state during PDF generation

PDF generation should complete in under 500ms per the spec's performance floor. However, the UI must not appear to freeze even for 300ms. Recommended pattern:

1. Coach taps "Export as PDF" in the action sheet.
2. Action sheet dismisses.
3. The share toolbar button shows a small `ProgressView` in place of the icon (or the icon becomes non-interactive with an activity indicator overlaid).
4. PDF generation runs (on a background queue if possible; main-actor return as spec requires for simplicity in V1).
5. UIActivityViewController presents.

This avoids a dead UI window between action sheet dismissal and share sheet appearance. If generation always completes under 200ms in practice the spinner may flash briefly — that is acceptable; it is better than an unresponsive screen.

---

## 4. Multi-Select UX Consideration (V2)

This is a forward-compatibility note, not a V1 requirement. Architecture should not close off these paths.

Multi-select export requires a play library screen that does not exist today. The UX implications are:

- A "Playbook" tab or modal presents a list of saved plays (each shown as a compact play name row: formation + digits + concept badge).
- Each row has a checkbox or multi-select toggle.
- A "Export Selected" button appears in the toolbar when one or more plays are selected.
- Play numbers are assigned in selection order (first selected = card 1, etc.) or by drag-reorder.
- The same PDF generator produces a grid — 4 plays per page, pages as needed.

What the architecture must not assume in V1:
- That a wristband card always carries play number "1". The number field must be parameterizable (even if V1 always passes 1).
- That the PDF always has exactly one logical page. The page layout logic must support a variable number of cards even if V1 only ever passes one play.
- That the PDF generator is tightly coupled to `PlayCallerView`. It should live in `Services/WristbandPDFGenerator.swift` (as the spec specifies) and accept a `[PlayCall]` array, not a single `PlayCall`. V1 passes `[currentPlay]`; V2 passes the selected set.

---

## 5. Accessibility

### 5.1 VoiceOver label for the export button

The share icon button has no visible text label. Its VoiceOver accessibility label must be set explicitly:

- **Enabled state:** `accessibilityLabel("Export wristband card")`
- **Hint (optional but recommended):** `accessibilityHint("Exports the current play as a printable PDF")`

Do not rely on SwiftUI's automatic label inference for an `Image`-only button — it will read the SF Symbol name ("square and arrow up button") rather than a meaningful description.

### 5.2 Disabled state description

When the button is disabled:

- `accessibilityLabel("Export wristband card")` — same label so the user knows what the button is
- `accessibilityValue("Unavailable — no play call loaded")` — describes why it is disabled
- The button should **not** be removed from the accessibility tree when disabled. A VoiceOver user scanning the navigation bar should encounter the button, hear its label, and hear its unavailability reason. Hiding it entirely would leave them unable to discover the feature exists.

SwiftUI's `.disabled(true)` modifier will add the `UIAccessibilityTraitNotEnabled` trait automatically. The `accessibilityValue` with the reason is additive to that, not a replacement.

### 5.3 Action sheet accessibility

The iOS action sheet (`confirmationDialog` in SwiftUI, which maps to `UIAlertController` with `.actionSheet` style) is fully accessible by default — VoiceOver reads the title, message, and each option. No custom work needed.

The subtitle (play name) in the action sheet message will be read by VoiceOver as part of the dialog. This is the correct behavior — it gives a VoiceOver user the same confirmation a sighted user sees.

### 5.4 PDF content accessibility

PDFs generated via PDFKit are print-destined artifacts and are not expected to be screen-reader accessible. The primary accessible surface is the share flow, not the PDF content. This is acceptable — the printed physical card serves players and coaches in a physical context; the accessibility requirement is on the app interaction, not the artifact.

If Ken ever wants accessible PDF output (for use on iPad by players with visual impairments), that is a V2 tagged-PDF concern and should be added to the backlog when requested.

### 5.5 Dynamic Type

The wristband card PDF renders at fixed print sizes, so Dynamic Type does not apply to the PDF output. The export button and action sheet are native iOS controls and respond to Dynamic Type automatically. No custom handling needed.

### 5.6 Reduce Motion

The action sheet and share sheet are both system controls with no custom animation. The loading spinner state (Section 3.4) should respect `UIAccessibility.isReduceMotionEnabled` — if reduce motion is on, skip the spinner and show a non-animated indicator instead (e.g., a filled circle or simply keep the icon grayed). This is a should-fix, not a must-fix.

---

## 6. Open Questions for Ken

These require Ken's answer before implementation can begin. Questions 1 and 2 are blocking (they affect the PDF generator's data inputs). Question 3 is a preference question that can be answered at any point before Story 3.1.4.

**Question 1 (Blocking — affects card rendering):**
Should the wristband card display the post-motion receiver state (Y in its final position after Y After/Go) or the pre-motion base formation?

The spec recommends post-motion, and that is the right default: a player needs to know where they line up after motion, not where they started. However, the app currently maintains both `currentPlayCall` (base) and `currentPlayCallWithMotion` (with motion applied) as separate objects. The PDF generator needs to know which to use. If post-motion is confirmed, the generator always receives `currentPlayCallWithMotion ?? currentPlayCall`.

**Question 2 (Blocking — affects PDF page layout):**
Should V1 produce four identical copies of the current play in a 2×2 grid per page (print four, cut once), or a single centered card per page (print one, no cutting)?

The spec recommends the 2×2 grid. The UX rationale for the grid: coaches typically need multiple copies of a card (one per player at the position, one for the coaching staff binder). Printing four at once in one action with a single cut is significantly more convenient than printing four separate sheets. The single-card option has a lower implementation cost but produces a less useful artifact. Recommendation: confirm the grid, but this is Ken's call on workflow.

**Question 3 (Non-blocking — action sheet copy):**
Should the action sheet message line include the concept name when one matched?

Current spec text: `"[Formation] [Digits]"` — example: `"Twins 6794"`.
Alternative: `"[Formation] [Digits] · [Concept]"` — example: `"Twins 6794 · Smash"`.

The concept name is the coaching shorthand that coaches and players actually use to refer to a play. Including it makes the confirmation line read like the play is actually called on the field. This is a low-cost copy change with no engineering impact. Recommend including it when matched; omit it (not blank — just absent) when no concept matched.

---

## Assumptions and risks

**Assumption that may be wrong:** This consultation assumes the notes line is always printed (i.e., it appears on every card as an empty rule). If Ken does not want printed annotation space by default, the notes line should become a user preference or a per-export option. The current design includes it unconditionally because the spec lists it as "Optional (print-time)" which implies it appears but is blank — if it meant "user can opt in to include it," a toggle in the action sheet or a Settings flag is needed.

**Risk — diagram legibility at card scale:** The `DiagramRenderer` was designed for a 320pt tall on-screen canvas. Scaling it to a ~60pt tall card zone will require deliberate re-parameterization, not just a `CGAffineTransform` scale. Receiver dots that are 12pt radius on screen become ~2.5pt radius at card scale — invisible after lamination. The architecture consultation should explicitly address this scaling problem. If the diagram cannot be made legible at card scale without significant re-work, a fallback of omitting the diagram and noting it as a V1 limitation is preferable to shipping an unreadable diagram.

**Risk — toolbar crowding on small devices:** On an iPhone SE (375pt width), the navigation bar trailing area with two buttons ("Reset" text + share icon) is narrow. This consultation recommends the share icon use `Image(systemName:)` only (no label) to minimize width. If Reset is also icon-only (e.g., `arrow.counterclockwise`), both buttons fit cleanly. If Reset stays as a text label "Reset", the two items will still fit on SE but with tight spacing. The engineer should verify on an SE simulator. A must-fix if buttons overlap; a should-fix if spacing is merely tight.

---

## Acceptance criteria traceability (Story 3.1.2)

The spec's Story 3.1.2 acceptance criteria are mapped to sections of this consultation:

| AC | Section covering it |
|----|---------------------|
| Export button visible when valid play showing | Section 2.2 (button states) |
| Export button visible but disabled when no play | Section 2.2 (disabled state) |
| Action sheet title "Export Wristband Card" + play name | Section 3.2 |
| "Export as PDF" triggers share sheet | Section 3.3 |
| "Cancel" dismisses without side effects | Section 3.1 (two-step flow rationale) |
| UX designer review confirms intuitive, non-disruptive | This document |
| VoiceOver label and disabled state description | Section 5.1, 5.2 |
