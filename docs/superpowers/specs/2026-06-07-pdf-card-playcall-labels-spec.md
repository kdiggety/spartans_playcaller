# PDF Card — Playcall Header + Diagram Receiver Labels

**Feature ID:** pdf-card-playcall-labels
**Date:** 2026-06-07
**Author:** Product Owner
**Status:** Ready for implementation

---

## Problem

Coach tested the wristband and catalog PDF export and found two gaps that block game-day usability:

1. The play call (formation + route string together) does not appear on the card in a readable, at-a-glance form. The current split layout (formation right-aligned, digits on a separate row) forces the coach to mentally assemble the play call during a game when every second counts.
2. The route diagram dots are anonymous — no receiver letters are rendered inside or beside the circles. A coach looking at the diagram alone cannot identify which dot is X, Y, Z, A, or H without cross-referencing the text rows above.

---

## User Story

As a coach reading a wristband or catalog card on the sideline, I want to see the full play call (formation + digits) as a single string on the card header, and I want receiver letters on the diagram dots, so I can read any card correctly in under two seconds without looking back and forth between the header and diagram.

---

## Scope

### In scope

- **Change 1 — Card header restructure** (both generators): replace the three-row formation / digits / receiver-label block with a single combined row showing `"<number>. <FormationName> <Digits>"` (e.g., `"1. Twins 6794"`). Remove the standalone receiver-label text row (Row 3 in the current layout) entirely.
- **Change 2 — Diagram receiver labels** (`DiagramRenderer+CGContext.swift`): inside `drawReceiversCG`, draw the receiver's letter (X, Y, Z, A, or H) centered on or immediately above the receiver dot for every rendered assignment.

### Out of scope

- Any change to the on-screen (Canvas) route diagram in the main app UI — labels are PDF-only in this slice.
- Changes to the Notes line, concept/motion row, divider, or diagram zone sizing.
- Font or color system changes beyond what is required to make labels legible at the existing `receiverRadius` sizes (4 pt wristband / catalog scale).
- H receiver label special-casing beyond rendering it identically to X/Y/Z/A when present.
- Any new export format or layout mode.

---

## Acceptance Criteria

### Group A — Card header (WristbandPDFGenerator + CatalogPDFGenerator)

**AC-1.** The combined header row renders the string `"<playNumber>. <formationName> <routeDigits>"` (e.g., `"1. Twins 6794"`) left-aligned on the card, starting at the same top-inset position currently occupied by Row 1.

**AC-2.** The separate route-digits row (current Row 2) and the separate receiver-label text row (current Row 3 — the `"X    Y    Z    A"` string) are removed from both generators. No vestigial whitespace gap remains in their place; the concept/motion row (if present) and the divider follow immediately after the combined header row.

**AC-3.** For a 5-digit play (H receiver present), the combined row correctly shows all five digits, e.g., `"3. Trips Right 29437"`. The H digit is not truncated or omitted.

**AC-4.** For a play with no concept and no motion, the card header is exactly one row (AC-1 string), followed immediately by the divider and then the diagram zone.

**AC-5.** For a play with a concept or motion label (or both), the concept/motion row renders on the row directly below the combined header row, with no empty row between them. Layout matches the current behavior of Row 4 for those fields.

**AC-6.** The change applies identically to both `WristbandPDFGenerator.drawCard` and `CatalogPDFGenerator.drawCard`. No visual inconsistency between the two formats.

### Group B — Diagram receiver letter labels (DiagramRenderer+CGContext)

**AC-7.** For every `RouteAssignment` in `drawReceiversCG`, a single letter (the `Receiver` enum's display string: `"X"`, `"Y"`, `"Z"`, `"A"`, or `"H"`) is drawn centered within the receiver's circle at the dot's center position.

**AC-8.** The letter color is white (or sufficiently contrasting against the receiver's fill color) so it is legible when printed in grayscale. The fill alpha of the circle may be increased from `0.2` to up to `0.5` if needed for legibility, provided routes drawn from the dot remain visually unobstructed.

**AC-9.** The label font size is scaled relative to `config.receiverRadius` such that the letter fits inside the circle without clipping at all valid `DiagramConfig` sizes (wristband scale `receiverRadius: 4.0`, catalog scale `receiverRadius: 4.0`, standard scale `receiverRadius: 12`). A font size of `receiverRadius * 1.2` is the baseline; implementer may adjust within `[receiverRadius * 1.0, receiverRadius * 1.5]` for best fit.

**AC-10.** The label uses the same UIKit text-flip technique already present in the PDF generators (`context.translateBy` + `context.scaleBy(x:1, y:-1)`) so the letter renders right-side-up in the Y-down CGContext used during PDF export.

**AC-11.** The label is drawn after the circle fill and stroke, so it renders on top of the dot, not behind it.

**AC-12.** The Y receiver label still renders at the receiver's initial (pre-motion) dot position when Y Motion is None or Stop. When Y After/Go motion is active, the label appears at the final post-motion position (i.e., the position the route starts from, consistent with how `drawRoutesCG` handles Y motion). If Y Wheel is enabled, the label renders at the same position the wheel arc originates from.

### Group C — No regression

**AC-13.** All existing unit tests (`ExportCardTests`, `WristbandPDFGeneratorTests` if present, `CatalogPDFGeneratorTests` if present, `DiagramRendererTests` if present) pass without modification to test expectations — unless a test directly asserts the old Row 2/Row 3 layout strings, in which case the test must be updated to assert the new combined-row format.

**AC-14.** A Twins 4-digit play and a Trips 5-digit play each produce a non-nil `Data` result from both `WristbandPDFGenerator.generate` and `CatalogPDFGenerator.generate` after the changes.

---

## Roles

| Role | Involvement |
|---|---|
| software-engineer | Implement header restructure in both generators; implement receiver labels in `DiagramRenderer+CGContext.swift` |
| sdet | Validate acceptance criteria; write or update unit tests for header row format and label presence; produce test results report |
| performance-engineer | Assessment — confirm no measurable regression in PDF generation time for a 9-card catalog page |
| ux-designer | Not required — Ken is the end user and will visually sign off |
| security-engineer | Not required — no new data handling, no credential surfaces; lightweight confirmation that no metadata changes were introduced |

---

## Key Implementation Notes (for software-engineer)

These are constraints derived from reading the existing code, not suggestions to discard.

**Header row vertical budget:** Removing Rows 2 and 3 recovers approximately 28–30 pt of vertical space on the wristband card and 25 pt on the catalog card. The diagram zone must NOT be moved or resized to fill this gap — it is anchored by `config.diagramZoneSize.height` and `config.diagramZoneTopY` (catalog) or the running `y` cursor (wristband). Use the recovered space to give the combined header row a slightly larger font if desired, but do not change `diagramZoneSize`.

**Font for combined row:** Use the existing `formationFontSize` weight (`.semibold`) for the full combined string. Monospaced font is no longer needed for the header since digits are no longer column-aligned to receiver labels.

**Receiver label drawing — Y-down context:** `drawReceiversCG` receives a context already flipped to Y-down by the calling `PDFPage.draw`. The existing `drawText` helpers in each PDF page class re-flip locally. `drawReceiversCG` is a method on `DiagramRenderer` and does not have access to those helpers. Implement the re-flip inline within `drawReceiversCG` using `context.saveGState / translateBy / scaleBy / restoreGState` — the same pattern used in `drawText` in both generator files.

**Receiver enum display strings:** Confirm the string value for each `Receiver` case (`"X"`, `"Y"`, `"Z"`, `"A"`, `"H"`) matches what `receiverCGColor(for:)` maps over — they are the same enum cases. No new model changes are needed.

**Ripple impact:** The removal of Row 3 text in both generators may affect any snapshot or visual regression tests that assert pixel-level card output. Check `SpartansPlaycallerTests/` for any such tests and update expected values. The `ExportCard` model struct itself is unchanged.

---

## Definition of Done

- AC-1 through AC-14 verified.
- Ken visually confirms a sample wristband PDF and a sample catalog PDF in Simulator or device: playcall string readable in header, letters visible on dots.
- Test results report written to `docs/test-plans/pdf-card-playcall-labels-test-results.md`.
- Backlog entry updated: this item moved to Completed with shipped date.
