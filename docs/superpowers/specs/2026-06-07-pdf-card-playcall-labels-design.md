# Design Spec — PDF Card Playcall Labels
**Feature ID:** pdf-card-playcall-labels
**Date:** 2026-06-07
**Author:** Architecture & System Design
**Status:** Ready for implementation
**PO Spec:** `docs/superpowers/specs/2026-06-07-pdf-card-playcall-labels-spec.md`

---

## Mental Model

Two additive changes to the CGContext-based PDF rendering pipeline. Change A collapses the three-row card header (play number row, digits row, receiver-label text row) into a single combined row and adjusts the vertical space budget in both config structs so the diagram zone expands to fill the recovered height. Change B adds one text-drawing step inside `drawReceiversCG`, after the existing fill and stroke, to render the receiver's letter centered inside its dot using the same Y-down-flip technique already present in the PDF page text helpers.

No new data flows, no new file paths, no structural changes to `ExportCard`, `DiagramConfig`, `PlayCall`, or the public API of either generator. The changes are confined to three Swift files plus a new computed property on `ExportCard` for testability.

---

## Design Decisions

### Decision 1 — Receiver label position: inside the dot

**Chosen: inside the dot, centered at the dot's center point.**

The dot diameter at both wristband and catalog card scale is `2 × receiverRadius = 8pt`. A single uppercase letter at 6pt (font size = `receiverRadius * 1.5 = 6pt`) has an em-height of approximately 4.5pt with a typical cap-height ratio of ~0.75. This fits inside the 8pt diameter with ~1.75pt clearance on each side vertically and similar horizontal clearance for X/Y/Z/A/H (all single characters, all narrow at this size).

Placing the label above the dot was considered. It was rejected because at small card scale the label and the route line drawn from the dot would visually collide, and the dot itself would become an anonymous anchor again from a distance. Inside the dot is unambiguous: the dot and its identity are a single visual unit.

**Label rect:** `CGRect(x: pos.x - r, y: pos.y - r, width: r * 2, height: r * 2)` — the same rect used for the ellipse fill and stroke. Draw the string centered in this rect using `NSTextAlignment.center`.

Confidence: high. Falsified if Ken finds the letter is not readable at print scale for the smallest card size — the fallback is shifting to above the dot with a smaller font.

---

### Decision 2 — Font size formula: `min(receiverRadius * 1.5, 8.0)`

**Chosen: `min(receiverRadius * 1.5, 8.0)`**

At `receiverRadius = 4.0` (both card scales): `4.0 * 1.5 = 6.0pt`. Capped at 8pt, so the effective size is 6pt for both card-scale configs. At `receiverRadius = 12` (standard/full scale in other contexts): `12 * 1.5 = 18pt`, which fits well in a 24pt diameter dot.

The PO spec permits the range `[receiverRadius * 1.0, receiverRadius * 1.5]`. The upper end of that range is chosen here because:
- The cap height at 6pt from a system font in a PDF context is approximately 4pt — fits inside 8pt diameter.
- At the lower end (`receiverRadius * 1.0 = 4pt`), the letter would be barely legible against print noise.
- The 8pt hard cap ensures no label exceeds 8pt regardless of config, which keeps the label subordinate to the route lines that originate from the dot.

The attributes dictionary (font + color + paragraph style) must be constructed once per `drawReceiversCG` call and reused across all receivers in that call. Constructing it per-draw call is explicitly flagged by the performance engineer as the one pattern to avoid (it multiplies Core Text attribute lookup by receiver count × card count). See Performance section.

Confidence: high for correctness; medium for visual outcome at print scale — Ken's sign-off will validate.

---

### Decision 3 — Label color: receiver stroke color at full opacity, drawn over a 0.3 alpha fill

**Chosen: receiver stroke color (same `UIColor` returned by `receiverCGColor(for:)`) at full opacity, with fill alpha raised from 0.2 to 0.3.**

Three options were analyzed:

| Option | Description | Verdict |
|--------|-------------|---------|
| White | Draw white text inside colored dot | Rejected — at 0.2 fill alpha on white paper, a white letter would be invisible. Even at 0.5 fill alpha, white-on-color may not survive grayscale printing. |
| Same color, full opacity | Draw the receiver's color (cyan, yellow, green, orange, pink) over the translucent fill | Chosen — the letter color matches the route line color, creating a single coherent visual identity per receiver. On white paper with 0.3 alpha fill, the receiver color at full opacity is clearly legible for all five colors (none are near-white in grayscale). |
| Black | Draw black text regardless of receiver | Rejected — black inside a colored dot loses the color-coding benefit and is visually inconsistent with the route line colors. |

Fill alpha increase from 0.2 to 0.3 is the minimum increase needed to ensure the colored letter stands out from the circle boundary and does not visually merge with the white background seen through the translucent fill. The PO spec permits up to 0.5; 0.3 is conservative and leaves the route lines unobstructed. Ken's visual sign-off will confirm whether 0.3 is sufficient or needs adjustment.

**Implementation note:** The color used for the letter draw call is exactly `UIColor(cgColor: receiverCGColor(for: assignment.receiver))` — no alpha modification. The fill alpha change applies only to the `context.setFillColor(color.withAlphaComponent(0.3).cgColor)` call, replacing the current 0.2.

Confidence: medium. The main uncertainty is grayscale printing legibility for systemYellow (Y receiver). Yellow has low contrast against white in grayscale. If Ken prints a test card and Y is not legible, raise fill alpha to 0.4 or switch Y label to black — a one-line change.

---

### Decision 4 — `combinedHeaderString` as a computed property on `ExportCard`

**Chosen: add `var combinedHeaderString: String` as a computed property on `ExportCard`.**

The SDET strategy explicitly recommends this for testability (Section 5.1, "Note on combined-row string format tests"). The string format `"\(playNumber). \(formationName) \(routeDigits)"` is a pure function of three `ExportCard` fields. Placing it as a `ExportCard` property means:

- Unit tests in `PDFCardHeaderTests.swift` can call `card.combinedHeaderString` directly without triggering a full PDF render.
- Both generators (`WristbandPDFPage.drawCard` and `CatalogPDFPage.drawCard`) call the same property, eliminating duplication and the risk of the two generators drifting to different string formats.
- Future changes to the header format (e.g., adding a concept abbreviation inline) have one edit point.

The property is non-`private` (default `internal`) so it is visible to the test target via `@testable import`.

**Property definition:**
```swift
var combinedHeaderString: String {
    "\(playNumber). \(formationName) \(routeDigits)"
}
```

No trailing space, no separator between formation name and digits other than a single space. This matches the PO spec examples exactly (`"1. Twins 6794"`, `"3. Trips Right 29437"`).

Confidence: high.

---

### Decision 5 — Header row height and `diagramZoneTopY` updates

This is the most consequential arithmetic decision. The two generators have fundamentally different layout models, which must be handled separately.

#### Wristband generator: running-cursor layout

`WristbandPDFPage.drawCard` positions the diagram at the current value of the running `y` cursor after the divider. It does NOT use `config.diagramZoneTopY` to position the diagram. However, `WristbandCardConfig.diagramZoneSize.height` is computed as `cardHeight - diagramZoneTopY - cardInset - 14`, so `diagramZoneTopY` determines diagram height, not position.

**Current layout (wristband):**
- Row 1 (play number + formation): `y += 22`
- Row 2 (route digits): `y += 16`
- Row 3 (receiver labels): `y += 14`
- Subtotal for header rows 1–3: **52pt**
- Optional concept/motion: `y += 17`
- Divider: `y += 5`
- Diagram starts at running `y` (approximately 57–74pt from card top after inset)

**After change (wristband):**
- Combined header row (play number + formation + digits): `y += 22`
- Row 2 removed (saves 16pt)
- Row 3 removed (saves 14pt)
- Savings: **30pt**
- Optional concept/motion: `y += 17` (unchanged)
- Divider: `y += 5` (unchanged)
- Diagram starts approximately 27–44pt from card top after inset (30pt higher than before)

The diagram now starts 30pt higher, but its height is still computed from `diagramZoneTopY = 92`. The notes line is still at `origin.y + h - 14 = origin.y + 166`. There is now a ~30pt gap between the diagram bottom and the notes line.

**Resolution:** Decrease `WristbandCardConfig.diagramZoneTopY` from `92` to `62`. This reflects the new actual diagram start position (inset 8 + combined row 22 + divider 5 + 2pt divider gap + 5pt divider spacing = approximately 42pt in the no-concept case; use 62 as a conservative value that accounts for the concept/motion row). The new `diagramZoneSize.height` becomes `180 - 62 - 8 - 14 = 96pt` (up from 66pt) — giving the diagram a meaningful size increase.

Arithmetic check: 96pt height at `receiverRadius = 4` gives `lineOfScrimmageY = 96 * 0.50 = 48pt`, `routeLength = 96 * 0.35 = 33.6pt`. Routes from LOS with 33.6pt of travel fit comfortably in the diagram zone. The diagram zone was previously 66pt; 96pt is a 45% increase in usable diagram area.

**New combined header row `y` increment:** `y += 22` — keeping the same visual height as the old Row 1. This gives the combined row slightly more vertical room than Row 2 or Row 3 had individually, which is appropriate since it now carries the full play call.

#### Catalog generator: absolute-position diagram

`CatalogPDFPage.drawCard` positions the diagram at `origin.y + config.diagramZoneTopY` — an absolute offset from the card top, independent of the running `y` cursor. The running cursor draws the divider line, but the diagram ignores it.

**Current layout (catalog):**
- Row 1: `y += 16`
- Row 2: `y += 13`
- Row 3: `y += 12`
- Subtotal rows 1–3: **41pt**
- Inset: 5pt
- Running cursor before concept/motion: approximately 46pt from card top
- `diagramZoneTopY = 70` — the diagram starts at absolute 70pt

**After change (catalog):**
- Combined header row: `y += 16` (same height as old Row 1)
- Rows 2 and 3 removed (saves 13+12 = **25pt**)
- Running cursor before concept/motion: approximately 21pt from card top (inset 5 + combined row 16)
- Without updating `diagramZoneTopY`, the divider still draws at ~21–35pt but the diagram still starts at absolute 70pt — a gap of ~35–49pt of dead space.

**Resolution:** Decrease `CatalogCardConfig.diagramZoneTopY` from `70` to `45`. Arithmetic: inset(5) + combined row(16) + optional concept/motion(14) + divider(4) = 39pt in the worst case (with concept and motion). Setting `diagramZoneTopY = 45` leaves 6pt clearance between the divider bottom and the diagram top in the worst case — tight but not overlapping. In the no-concept-no-motion case: inset(5) + combined row(16) + divider(4) = 25pt before diagram start; 20pt of breathing room.

New `diagramZoneSize.height`: `174 - 45 - 5 = 124pt` (up from 99pt). This is a 25% increase in diagram area.

**Impact on existing tests:** The SDET confirmed that `testCellOriginForSecondRow` uses `cardHeight + gutter` (not `diagramZoneTopY`), so it is not affected by the `diagramZoneTopY` change. If `cardHeight` does not change (and it does not — it stays at 174pt for catalog and 180pt for wristband), no existing geometry tests need updating.

**The one test that will need a value update** is any test that directly asserts `WristbandCardConfig.diagramZoneTopY == 92` or `CatalogCardConfig.diagramZoneTopY == 70`. The SDET confirmed no such direct assertion exists in the current suite, but the new tests in `PDFCardHeaderTests.swift` will assert the post-change values.

Confidence: high for arithmetic correctness; medium for visual outcome of diagram sizing increase — Ken must confirm the larger diagram renders well at both card scales.

---

## Component Changes

### `SpartansPlaycaller/Models/ExportCard.swift`

**Change:** Add a computed property `combinedHeaderString: String` to the `ExportCard` struct body (not the extension, to keep it alongside the stored properties it computes from).

```swift
var combinedHeaderString: String {
    "\(playNumber). \(formationName) \(routeDigits)"
}
```

**Why:** Testability seam (SDET requirement). Shared format between both generators to prevent drift.

**Ripple impact:** None. `ExportCard` is a value type with no conformances that constrain computed property additions. Existing `from(playCall:)` and `from(savedPlay:)` factory methods are unchanged.

---

### `SpartansPlaycaller/Models/WristbandCardConfig.swift`

**Change:** Update `diagramZoneTopY` from `92.0` to `62.0`. Update the comment.

**Before:**
```swift
let diagramZoneTopY: CGFloat = 92.0
```

**After:**
```swift
// Starts at y≈62pt within card (one combined header row + optional concept/motion + divider)
let diagramZoneTopY: CGFloat = 62.0
```

**Effect on `diagramZoneSize.height`:** `180 - 62 - 8 - 14 = 96pt` (was 66pt).

**Ripple impact:** `diagramZoneSize` computed property is read by `WristbandPDFPage.drawCard` to size the diagram rect. Any test that asserts a specific `diagramZoneSize.height` value must be updated. New tests in `PDFCardHeaderTests.swift` will assert the new value.

---

### `SpartansPlaycaller/Models/CatalogCardConfig.swift`

**Change:** Update `diagramZoneTopY` from `70.0` to `45.0`. Update the comment.

**Before:**
```swift
let diagramZoneTopY: CGFloat = 70.0
```

**After:**
```swift
// Starts at y≈45pt within card (one combined header row + optional concept/motion + divider)
let diagramZoneTopY: CGFloat = 45.0
```

**Effect on `diagramZoneSize.height`:** `174 - 45 - 5 = 124pt` (was 99pt).

**Ripple impact:** Same as wristband — `diagramZoneSize` consumers must be aware. `testCellOriginForSecondRow` is NOT affected (uses `cardHeight`, not `diagramZoneTopY`). New tests in `PDFCardHeaderTests.swift` will assert the new value.

---

### `SpartansPlaycaller/Services/WristbandPDFGenerator.swift` — `drawCard` method

**Changes:**
1. Replace Row 1 (two separate `drawTextLeft`/`drawTextRight` calls for play number and formation) + Row 2 (route digits) + Row 3 (receiver labels text) with a single combined row using `card.combinedHeaderString`.
2. Remove the `receiverLabels` local string computation and its draw call.
3. Remove the `digitsFontSize` monospaced draw call.
4. Keep `y += 22` for the combined row (same as old Row 1 increment).
5. Remove `y += 16` (old Row 2) and `y += 14` (old Row 3).

**New Row 1 draw call:**
```swift
// Row 1 (combined): "N. Formation Digits"
drawTextLeft(card.combinedHeaderString,
             in: CGRect(x: origin.x + inset, y: y, width: usableWidth, height: 20),
             font: UIFont.systemFont(ofSize: config.formationFontSize, weight: .semibold),
             into: context)
y += 22
```

Font choice: `formationFontSize` (14pt wristband) with `.semibold` weight, as directed by the PO spec. Monospaced font is no longer needed since column alignment to receiver labels is no longer required.

**Rows 2 and 3 are entirely removed** — no `y +=` for digits, no `y +=` for receiver labels, no `receiverLabels` string, no `receiverLabelFontSize` usage.

**`config.receiverLabelFontSize` and `config.digitsFontSize`** — these properties remain in `WristbandCardConfig` (removing them would be a broader breaking change); they simply cease to be called from `drawCard`. They may be deprecated in a future cleanup pass.

**Ripple impact:** `drawTextLeft` signature unchanged. No other callers of the removed Rows 2 and 3 draw calls exist outside `drawCard`. The `config.receiverLabelFontSize` and `config.digitsFontSize` properties are not tested directly; their removal from usage does not break any test.

---

### `SpartansPlaycaller/Services/CatalogPDFGenerator.swift` — `drawCard` method

**Identical restructure to `WristbandPDFGenerator.drawCard`**, with catalog-specific values:

**New Row 1 draw call:**
```swift
// Row 1 (combined): "N. Formation Digits"
drawTextLeft(card.combinedHeaderString,
             in: CGRect(x: origin.x + inset, y: y, width: usableWidth, height: 14),
             font: UIFont.systemFont(ofSize: config.formationFontSize, weight: .semibold),
             into: context)
y += 16
```

`formationFontSize = 10pt` at catalog scale. Row height set to 14pt (same as old Row 1 at 16pt minus 2pt, keeping things tight at catalog scale); `y += 16` matches the old Row 1 increment.

**Rows 2 and 3 removed** as in wristband.

**Diagram zone:** The diagram rect continues to use `origin.y + config.diagramZoneTopY` (now 45) as its Y origin — this is the critical difference from wristband. The running `y` cursor only drives the divider line, not the diagram start. After updating `diagramZoneTopY` to 45, the diagram immediately follows the divider in the no-concept case.

**Ripple impact:** Same as wristband. No other callers of removed draw calls.

---

### `SpartansPlaycaller/Services/DiagramRenderer+CGContext.swift` — `drawReceiversCG` method

**Change:** After the existing `context.strokeEllipse(in: rect)` call for each receiver, add a text-drawing step for the receiver letter.

**New drawing step (added inside the existing `for assignment in assignments` loop, after `strokeEllipse`):**

```swift
// Receiver letter: centered inside the dot
let label = assignment.receiver.rawValue   // "X", "Y", "Z", "A", or "H"
let fontSize = min(r * 1.5, 8.0)
let labelFont = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
let labelStyle = NSMutableParagraphStyle()
labelStyle.alignment = .center
let labelAttrs: [NSAttributedString.Key: Any] = [
    .font: labelFont,
    .foregroundColor: color,               // receiver color at full opacity
    .paragraphStyle: labelStyle
]
// Y-down re-flip: same technique as WristbandPDFPage.drawText / CatalogPDFPage.drawText
context.saveGState()
context.translateBy(x: rect.minX, y: rect.maxY)
context.scaleBy(x: 1, y: -1)
(label as NSString).draw(in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height), withAttributes: labelAttrs)
context.restoreGState()
```

The `labelAttrs` dictionary is constructed once before the `for` loop (not inside it) and reused across all receivers. Font size and style are constant within a single `drawReceiversCG` call since all receivers share the same `config.receiverRadius`. Only `color` varies per receiver, so the `labelAttrs` dictionary is reconstructed per-receiver (or the `.foregroundColor` key is updated). The cleanest approach: construct `labelAttrs` inside the loop (after `let color = ...`) so `color` is naturally included. The performance cost of reconstructing a 3-key dictionary 4–5 times per card is negligible (under 0.01ms per construction per the performance assessment); the performance concern is about constructing font objects, not attribute dictionaries. The font object is constructed once outside the loop since `fontSize` is constant.

**Revised structure:**

```swift
private func drawReceiversCG(...) {
    let r = config.receiverRadius
    let fontSize = min(r * 1.5, 8.0)
    let labelFont = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
    let labelStyle: NSMutableParagraphStyle = {
        let s = NSMutableParagraphStyle()
        s.alignment = .center
        return s
    }()

    for assignment in assignments {
        guard let pos = positions[assignment.receiver] else { continue }
        let rect = CGRect(x: pos.x - r, y: pos.y - r, width: r * 2, height: r * 2)
        let color = UIColor(cgColor: receiverCGColor(for: assignment.receiver))

        // Fill (alpha raised to 0.3 for legibility with letter overlay)
        context.setFillColor(color.withAlphaComponent(0.3).cgColor)
        context.fillEllipse(in: rect)
        // Stroke
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(1.0)
        context.strokeEllipse(in: rect)
        // Letter label
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: color,
            .paragraphStyle: labelStyle
        ]
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        (assignment.receiver.rawValue as NSString).draw(
            in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height),
            withAttributes: labelAttrs
        )
        context.restoreGState()
    }
}
```

**Draw order:** Fill → Stroke → Label. The label is drawn last (on top of the filled and stroked circle), satisfying AC-11.

**Y receiver position:** `drawReceiversCG` receives `positions` from `receiverPositions(formation:config:)`, which returns the initial (pre-motion) position for all receivers. The motion path and final position are handled by `drawMotionCG` and `drawRoutesCG`. To draw the Y label at the post-motion position (as required by AC-12 for After/Go motion), `drawReceiversCG` must compute the Y final position when Y motion is active, identical to how `drawRoutesCG` handles it. This requires passing `playCall` (or at minimum `assignments` with motion data) into the position calculation.

**Implementation decision for AC-12:** `drawReceiversCG` already receives `assignments`, which contains `assignment.motion` and `assignment.motionFinalSide`. The `yFinalPosition` private method is available on `DiagramRenderer`. When `assignment.receiver == .Y` and `assignment.motion != nil`, override `pos` with the Y final position before computing `rect`. The Y initial position dot is not drawn separately (the motion arc already shows the Y receiver's trajectory). This keeps `drawReceiversCG` consistent with the visual intent.

When Y Wheel is enabled, the Y receiver dot is still drawn at the initial position (the wheel arc replaces the route), but the label should render at the wheel arc origin — which is the initial Y position, the same as `positions[.Y]`. No special casing needed.

**Ripple impact:** `drawReceiversCG` is private and called only from `draw(into:playCall:config:in:)`. The outer `draw` method signature does not change. No external callers are affected. The fill alpha increase (0.2 → 0.3) affects all rendered route diagrams in PDF output — this is a deliberate visual improvement, not a regression.

**Structural note on Y motion position for the label:** The current `drawReceiversCG` signature is `(context:assignments:positions:config:)`. To support AC-12, it needs access to `formation` and `playCall` or at minimum `formation` and the Y assignment's motion. The simplest approach is to add `formation: Formation` and `playCall: PlayCall` parameters to `drawReceiversCG` to mirror what `drawRoutesCG` already accepts. Alternatively, pass the full `playCall` since the outer `draw` method already has it. The implementing engineer must update both the signature and the call site in `draw(into:playCall:config:in:)`.

---

## New File: `SpartansPlaycaller/Models/ExportCard.swift` — `combinedHeaderString`

Placed in the struct body, before the `extension ExportCard` block:

```swift
/// The combined play call header string used in PDF card rendering.
/// Format: "N. FormationName DigitsString" — e.g., "1. Twins 6794"
var combinedHeaderString: String {
    "\(playNumber). \(formationName) \(routeDigits)"
}
```

---

## Security Involvement Summary

Source: `docs/test-plans/pdf-card-labels-security-involvement.md`

The security engineer assessed this change as **rendering-layer only** with no new trust boundaries, data flows, network surface, or permission requests. Both changes operate exclusively on data already audited in Epic 3.1 (`ExportCard` fields are coach-authored plain text; `Receiver.rawValue` is a compiler-enumerated fixed set of five single characters).

**Security engagement level:** Light across all phases.

**Post-implementation review:** Lightweight grep-level verification that:
1. `document.documentAttributes` in both generators still sets only `titleAttribute` (REQ-SEC-1 unchanged).
2. No new `String` interpolation from user-controlled fields was added beyond what already existed.
3. `Receiver.rawValue` (or a fixed literal) is the sole data source for the new label draw calls.

No active attack probes are required. Expected outcome: PASS.

**Escalation triggers** (not expected): would upgrade to full review if `formationName` or `routeDigits` were embedded in a filename, metadata attribute, or file path — none of which apply here.

---

## Performance Baseline

Source: `docs/test-plans/pdf-card-labels-performance-assessment.md`

**Performance plan: not required.** The change adds 2–3 net text draw calls per card (`-2` from header collapse, `+4–5` from receiver letters). Each `NSString.draw` call at card scale takes under 0.1–0.2ms; five labels add under 1ms per card.

Against established hard gates (9-card catalog page < 500ms; expected 70–200ms), the addition contributes 5–9ms — under 5% of the pessimistic baseline. Well within margin.

**One implementation-quality note from the performance engineer:** Construct the `UIFont` object once per `drawReceiversCG` call (outside the per-receiver loop), not once per draw call. The font object is shared across all receivers since `fontSize` is constant within a call. This is reflected in the component change above.

**Re-assessment triggers:** batch sizes > 100 plays, multi-character labels, custom fonts, or > 9 cards per page. None apply to this change.

---

## Test Strategy Summary

Source: `docs/test-plans/pdf-card-labels-test-strategy.md`

### New test files

**`SpartansPlaycallerTests/PDFCardHeaderTests.swift`** — `XCTestCase`, no `@MainActor`:
- Unit tests for `ExportCard.combinedHeaderString` format (4 cases: single-digit number, two-digit number, 5-digit route, multi-word formation name)
- Unit tests asserting `WristbandCardConfig.standard().diagramZoneTopY == 62` and `CatalogCardConfig.standard().diagramZoneTopY == 45` (regression guards for the config constants changed by this spec)
- Unit tests asserting `diagramZoneSize.height > 0` and fits within card bounds for both configs
- Integration tests (non-crash + magic bytes + page count) for both generators with the new header layout, including concept/motion combinations

**`SpartansPlaycallerTests/DiagramRendererReceiverLabelTests.swift`** — `XCTestCase`, no `@MainActor`:
- Integration tests (non-crash + non-nil Data) for all 5 formations, 5-digit play, Y Wheel, motion, and combined motion+Y Wheel
- Magic bytes validity check
- `testContextStateAfterDrawReceiversIsIntact` — explicitly validates that `drawReceiversCG`'s `saveGState`/`restoreGState` does not leak a corrupt transform onto the outer context

### Existing tests requiring updates

**`CatalogPDFGeneratorTests.swift`:** No update required IF `cardHeight` stays at 174pt (confirmed: this spec does not change `cardHeight`). The `testCellOriginForSecondRow` test uses `cardHeight + gutter`, not `diagramZoneTopY`, so it is unaffected.

**`WristbandPDFGeneratorTests.swift`:** No update required. None of the 5 existing tests assert on header layout, `diagramZoneTopY`, or card-interior geometry.

**`DiagramRendererCGContextTests.swift`:** No update required. All 8 tests assert non-crash and non-empty data, which remains valid after Change B.

### SDET recommendation implemented

`ExportCard.combinedHeaderString` is added as a computed property (Decision 4). This enables the four `testCombinedHeaderStringFormat*` unit tests to call the property directly rather than requiring a full PDF render to verify string format.

### Visual sign-off items (automated tests cannot cover)

The following require Ken's eyes on a rendered PDF before the feature is declared complete:

1. Combined header row text is legible and not clipped at both card sizes
2. Receiver letter (X/Y/Z/A/H) is centered inside the dot at both card scales
3. Letter font size (6pt) is readable at wristband card scale (3.5" × 2.5" printed)
4. Letter font size is readable at catalog card scale (234pt × 174pt card)
5. Letter color (receiver color at full opacity over 0.3 alpha fill) has sufficient contrast, including grayscale printing — particularly the Y receiver in yellow
6. Diagram zone vertical position is correct after header shift (no header/diagram overlap, no dead gap, diagram visually larger)
7. Concept/motion row is correctly positioned below the combined header row with no empty row between them
8. Notes rule line at card bottom still renders at correct position after wristband header shift
9. Y Wheel arc renders correctly after receiver label addition (no visual interference)
10. Motion post-position "Y" label renders at the correct post-motion dot position

---

## Acceptance Criteria

Reproduced from PO spec for implementation reference.

### Group A — Card header

**AC-1.** Combined row `"<playNumber>. <formationName> <routeDigits>"` renders left-aligned at top of card.

**AC-2.** Rows 2 (route digits) and 3 (receiver label text) removed from both generators. No dead vertical gap.

**AC-3.** 5-digit play shows all five digits in the combined row (e.g., `"3. Trips Right 29437"`).

**AC-4.** No-concept, no-motion card has exactly one header row followed immediately by divider and diagram.

**AC-5.** Concept/motion row renders directly below combined header row with no empty row between.

**AC-6.** Change applies identically to both `WristbandPDFGenerator.drawCard` and `CatalogPDFGenerator.drawCard`.

### Group B — Diagram receiver letter labels

**AC-7.** Every `RouteAssignment` in `drawReceiversCG` renders its receiver letter centered in the dot.

**AC-8.** Letter color is legible in grayscale printing. Fill alpha is 0.3. Letter color is the receiver's stroke color at full opacity.

**AC-9.** Font size is `min(receiverRadius * 1.5, 8.0)` — 6pt at both card-scale configs, up to 18pt at standard full scale.

**AC-10.** Label uses Y-down flip (`saveGState` / `translateBy` / `scaleBy(x:1,y:-1)` / `restoreGState`) inline in `drawReceiversCG`.

**AC-11.** Label is drawn after fill and stroke (renders on top of dot).

**AC-12.** Y receiver label renders at post-motion position when Y After/Go motion is active. Renders at initial position for None/Stop and Y Wheel cases.

### Group C — No regression

**AC-13.** All existing tests pass. Tests that assert old Row 2/3 string formats are updated to assert the new combined format.

**AC-14.** Twins 4-digit and Trips 5-digit plays each produce non-nil `Data` from both generators.

---

## Visual Sign-Off Requirement

Ken must open a generated PDF in Preview (macOS) or Files (iOS) at 100% zoom or higher and confirm the 10 items listed in the Test Strategy section. This sign-off is required before the feature is declared complete — automated tests verify structural validity and non-crash; they do not verify visual correctness.

**Specific items requiring printed card confirmation (not simulator):** items 3 (wristband print legibility) and 4 (catalog print legibility). All other sign-off items can be confirmed in Preview at 100% zoom on macOS.

---

## Decisions, Non-Goals, and Next Steps

**Decisions made here:**
- Receiver label: inside dot, centered, receiver color at full opacity, font size `min(r*1.5, 8.0)`
- Fill alpha: raised from 0.2 to 0.3
- Combined header row: uses `ExportCard.combinedHeaderString`, rendered with `formationFontSize` / `.semibold`
- `WristbandCardConfig.diagramZoneTopY`: 92 → 62 (diagram grows from 66pt to 96pt tall)
- `CatalogCardConfig.diagramZoneTopY`: 70 → 45 (diagram grows from 99pt to 124pt tall)
- `cardHeight` for both configs: unchanged

**Non-goals:**
- On-screen Canvas diagram labels (PDF-only in this slice)
- Changes to notes line, concept/motion row structure, divider, or page layout beyond the header restructure
- Font or color system changes beyond what this spec specifies
- H receiver special-casing beyond identical treatment to X/Y/Z/A

**Hardest trade-off:** The diagram zone height increase (96pt and 124pt) is a side effect of the `diagramZoneTopY` changes, not a primary goal. It improves the PDF product but has not been visually validated. If Ken finds the larger diagram zone makes routes too long or the diagram looks unbalanced, the fix is to increase `diagramZoneTopY` back toward the original value — a one-line config change.

**What would invalidate this design:** If the Y receiver letter must render at the initial position even when motion is active (i.e., show where Y started, not where the route begins), AC-12 as written is wrong and `drawReceiversCG` should not compute the final position. This interpretation should be confirmed with Ken before implementation — the PO spec says "the position the route starts from, consistent with how `drawRoutesCG` handles Y motion," which is the final position, but visual confirmation is cleaner than spec-reading.

**Cheap validation before implementation:** Generate the current PDF (before changes) with the wristband generator, measure the card header text height in Preview, and confirm the arithmetic in this spec matches the actual rendered positions. Takes under 5 minutes and removes any ambiguity about running-cursor vs absolute-position in the wristband generator.

**Next step:** Implementation by `software-engineer`, guided by this spec and the PO spec. Test file creation guided by `docs/test-plans/pdf-card-labels-test-strategy.md`.
