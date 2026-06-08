# PDF Card Labels — Test Strategy

**Feature:** PDF export card header restructure + receiver letter labels in diagram dots
**Date:** 2026-06-07
**Author:** SDET
**Status:** PLANNING GATE ARTIFACT
**Scope:** Two UI improvements to `WristbandPDFGenerator.swift`, `CatalogPDFGenerator.swift`, and `DiagramRenderer+CGContext.swift`

---

## 1. Change Summary

### Change A — Card Header Restructure (Wristband + Catalog)

The current header occupies three rows:

- Row 1: play number (left) + formation name (right)
- Row 2: route digits (centered, monospaced)
- Row 3: receiver label text "X  Y  Z  A" (centered, monospaced, small font)

After the change, these three rows collapse into one combined row:

- Row 1: "1. Twins 6794" (play number + space + formation name + space + route digits, single line)

Downstream rows (concept/motion, divider, diagram zone) shift upward by the vertical space previously consumed by Rows 2 and 3.

This change is applied symmetrically in both `WristbandPDFPage.drawCard(_:at:into:)` and `CatalogPDFPage.drawCard(_:at:into:)`. The `diagramZoneTopY` constant in `WristbandCardConfig` and `CatalogCardConfig` will likely change value as a direct result.

### Change B — Receiver Letter Labels Inside Diagram Dots

The `drawReceiversCG` private method in `DiagramRenderer+CGContext.swift` currently draws:

1. A filled ellipse (alpha 0.2, receiver color)
2. A stroked ellipse (receiver color, 1pt line)

After the change, a third drawing step is added per receiver:

3. The receiver letter (X, Y, Z, A, or H) centered inside the dot, rendered via CGContext using the Y-down flip technique, font size proportional to `config.receiverRadius`

This change is purely additive inside `drawReceiversCG`. No existing drawing calls are removed or reordered. The `DiagramConfig` struct gains no new fields; font sizing is derived directly from the existing `receiverRadius` property.

---

## 2. Regression Scope

### 2.1 Risk Classification

**Highest risk — `diagramZoneTopY` constant changes in both config structs**

`WristbandCardConfig.diagramZoneTopY` is currently `92.0`. `CatalogCardConfig.diagramZoneTopY` is currently `70.0`. Both values are used in the `diagramZoneSize` computed property and in the PDF page's `drawCard` layout math. If the header restructure shifts the diagram zone origin upward and neither constant is updated (or is updated incorrectly), the diagram will overlap the header text or leave a dead vertical gap. This is a pure arithmetic regression.

One existing catalog test directly asserts `CatalogCardConfig.diagramZoneTopY` indirectly through `cellOrigins` geometry. If the constant changes, the existing `testCellOriginForSecondRow` test in `CatalogPDFGeneratorTests.swift` may need its expected value updated to match the new layout. Read that test carefully before asserting — the test encodes the *current* arithmetic, not the desired post-change arithmetic.

**High risk — `drawCard` `y` accumulation logic in both page classes**

Both `WristbandPDFPage.drawCard` and `CatalogPDFPage.drawCard` accumulate a `y` offset variable by adding row heights sequentially. The restructure removes two `y +=` steps (one for the digits row, one for the receiver label row) and replaces them with a single `y +=` for the combined header row. Any off-by-one in the remaining `y` accumulation will cause the concept/motion row, divider, and diagram to render at wrong vertical positions. This is the highest-probability silent defect from this change.

**Medium risk — `drawReceiversCG` addition crashing or corrupting context state**

The new letter-drawing step inside `drawReceiversCG` uses `CGContext.saveGState()` / `restoreGState()` and a Y-down re-flip, the same technique used by all existing text drawing helpers. If the new code omits `saveGState`/`restoreGState` or applies the transform outside the save/restore block, it will corrupt the CGContext transform stack for all subsequent draw operations in the same page — routes, arrows, field lines, and other receiver dots will shift position. The existing non-crash tests will catch a hard crash but will not catch a silent transform leak producing visually wrong output.

**Low risk — Pro formations with no A receiver**

`proLeft` and `proRight` assign `.A` and `.H` to `.center` side. `DiagramRenderer.receiverPositions` does not include `.A` or `.H` in the returned dictionary for Pro formations. `drawReceiversCG` guards with `guard let pos = positions[assignment.receiver]` — so a Pro play's assignments for `.A` or `.H` will be silently skipped. This behavior exists today and must not change. The new letter-drawing code runs inside the same guard scope; if the letter-drawing code is accidentally placed outside the guard, it will crash on a nil position lookup.

**Low risk — 5-digit plays (H receiver)**

The existing `drawReceiversCG` loop iterates over `assignments`, which includes `.H` only when the route digits string has 5 characters. The `.H` case is handled by `receiverCGColor` (returns `UIColor.systemPink`). The letter "H" must be drawn when `.H` is present. This is covered by the existing "does not crash" test coverage but is worth a dedicated test case in the new strategy.

### 2.2 Existing Test Files That Must Remain Green

All tests in `SpartansPlaycallerTests/` must pass before and after this change. The highest-risk existing files for this specific change are:

| File | Risk from this change |
|------|-----------------------|
| `WristbandPDFGeneratorTests.swift` | Medium — page count, media box, and magic bytes tests will still pass even if header layout is broken, because they do not assert on text content or vertical coordinates. No changes needed IF page structure is unchanged. |
| `CatalogPDFGeneratorTests.swift` | Medium — same as wristband. The `testCellOriginForSecondRow` assertion at `y == 218` encodes pre-change `diagramZoneTopY` indirectly through the grid math (the grid math uses `cardHeight` + `gutter`, not `diagramZoneTopY`, so this test is not directly affected by the `diagramZoneTopY` change). Confirm before concluding no update is needed. |
| `DiagramRendererCGContextTests.swift` | High — all 8 non-crash tests exercise the full `draw()` pipeline including `drawReceiversCG`. If the new letter-drawing code corrupts context state, these tests may still not crash (PDF rendering is lenient), but the new letter tests added by this strategy will catch the regression. |
| All `YWheel*` and `DiagramRenderer*` test files | Low — these exercise path geometry and arc math, which `drawReceiversCG` does not touch. Risk is limited to context state corruption from the label drawing code leaking out of `saveGState`/`restoreGState`. |

### 2.3 Tests That Need Updates After Implementation

**`CatalogPDFGeneratorTests.swift` — `testCellOriginForSecondRow`**

This test asserts `config.cellOrigins[3].y == 218`. The origin is computed as `margin + 1 * rowStride` where `rowStride = cardHeight + gutter = 174 + 8 = 182`, giving `36 + 182 = 218`. This test does NOT depend on `diagramZoneTopY` — it uses `cardHeight` which is not changing. No update needed IF `cardHeight` stays at 174pt.

However: if the implementation changes `cardHeight` to accommodate the header restructure (to give the diagram more vertical space now that the header is smaller), then `testCellOriginForSecondRow` and `testCellOriginForSecondColumn` must be updated with recalculated values.

**Action for implementing engineer:** confirm whether `cardHeight` changes. If it does, update the three geometry tests in `CatalogPDFGeneratorTests.swift` before running the suite, or the suite will fail immediately on pre-existing tests.

**`WristbandPDFGeneratorTests.swift`**

None of the 5 existing tests assert on `diagramZoneTopY` or card-interior layout. No update is required unless `cardWidth`, `cardHeight`, `pageWidth`, or `pageHeight` change.

---

## 3. Test Pyramid Balance

```
                E2E / UI Automation
               (0% — PDF visual content not automatable via XCTest;
                manual sign-off replaces this layer for visual AC)

          Integration Tests  (~40%)
     PDF magic bytes + page count via PDFKit (both generators)
     Non-crash rendering with new combined header row
     Non-crash rendering with receiver letter labels in all formations
     Context state integrity: diagram renders correctly after drawReceiversCG
     5-digit play (H receiver) with letter label
     Motion + Y Wheel combinations still render

           Unit Tests  (~60%)
      Combined header row string format: "N. Formation Digits"
      diagramZoneTopY value after header restructure
      diagramZoneSize.height after diagramZoneTopY change
      Receiver label font size formula (proportional to receiverRadius)
      No `y` accumulation for removed digit row (y delta matches combined header height)
      No `y` accumulation for removed receiver label row
      Pro formation receiver label skip (no crash, no assertion on skipped receivers)
```

The pyramid is unit-heavy because the most likely defects (wrong `y` offset arithmetic, wrong `diagramZoneTopY` constant, wrong combined-row string format) are deterministic arithmetic and string composition bugs. Integration tests are needed at the PDF rendering boundary to verify that no crash and no context state corruption occurred — defects that unit tests on pure value logic cannot detect.

---

## 4. Question Answers

### Q1: Which existing tests need to be updated and why?

**`CatalogPDFGeneratorTests.swift` — conditional**

The three geometry tests (`testCellOriginForSecondColumn`, `testCellOriginForSecondRow`, `testCellOriginForFirstCell`) assert constants from `CatalogCardConfig`. They will need updating only if `cardHeight` changes. If `cardHeight` stays at 174pt, they are stable.

The `diagramZoneTopY`-based tests do not exist in the current suite — only the grid origin tests exist, and those use `cardHeight + gutter`, not `diagramZoneTopY`. No test currently asserts the value of `diagramZoneTopY` in either config struct. This is a gap.

**`WristbandPDFGeneratorTests.swift` — no update needed**

None of the 5 existing wristband tests assert any value that changes with the header restructure (they only check page count, media box dimensions, nil behavior, and PDF magic bytes).

**`DiagramRendererCGContextTests.swift` — no update needed**

All 8 tests assert non-crash and non-empty data. They remain valid after Change B. The new tests added by this strategy extend coverage rather than replacing existing tests.

### Q2: What new tests should be added for the header restructure?

See Section 5.1 for the full test table. Summary:

- Combined header row string composition: assert `"\(playNumber). \(formationName) \(routeDigits)"` format for normal and edge cases (single-digit number, multi-word formation name, 5-digit route string)
- `diagramZoneTopY` regression guard: assert the new constant value in both config structs after the change is applied
- `diagramZoneSize.height` regression guard: assert the computed height is positive and fits within card bounds
- PDF non-crash with new header layout: one new test per generator asserting non-nil data with the new code path (extends rather than replaces existing tests)
- Concept/motion row is still present and positioned correctly below the new combined header (non-crash test with concept + motion populated)
- `y` offset regression: if the generator exposes any testable seam for the card-internal layout (unlikely given the current architecture), test it; otherwise this is covered by the non-crash + visual sign-off tests

### Q3: What new tests should be added for the diagram receiver labels?

See Section 5.2 for the full test table. Summary:

- Non-crash for all 5 formations, verifying the letter-drawing step does not crash or corrupt context state
- All 4 required receivers (X, Y, Z, A) produce valid output in a 4-digit play
- The 5th receiver (H) produces valid output in a 5-digit play
- Pro formations: A and H receivers are absent from positions dictionary; no crash; no assertion failure
- Y Wheel enabled: receiver dots + labels still render (Y Wheel draw path does not interfere with drawReceiversCG)
- Motion applied: Y receiver position is at post-motion location; label "Y" renders at that position
- Context state integrity: after `drawReceiversCG` completes, subsequent draw calls (routes, arrows) are not displaced (verified by non-crash of full `draw()` pipeline, since a displaced context would likely produce an obviously wrong diagram on manual inspection)

### Q4: What is NOT testable and should be flagged for Ken's visual sign-off?

See Section 6 for the full list. Summary:

- Whether the combined header row is visually legible and not clipped by the card boundary
- Whether the receiver letter (X/Y/Z/A/H) is centered correctly inside the dot at the chosen font size
- Whether the font size proportional to `receiverRadius` is readable at card scale (both wristband 3.5x2.5" and catalog smaller card)
- Whether the combined header row layout feels balanced and proportional (not too sparse or crowded)
- Whether the diagram zone vertical position is correct after the header shift (not overlapping header text, not leaving excessive dead space)
- Whether letter color (white, black, or receiver color) has sufficient contrast against the filled dot background

---

## 5. New Tests to Create

### 5.1 Header Restructure Tests

**File:** `SpartansPlaycallerTests/PDFCardHeaderTests.swift`
**Class:** `PDFCardHeaderTests` (plain `XCTestCase`, no `@MainActor` — exercises only config structs and string formatting, no `@MainActor`-isolated types)

| Test | What it asserts | Type |
|------|----------------|------|
| `testCombinedHeaderStringFormatSingleDigitNumber` | `"1. Twins 6794"` — play number 1, formation "Twins", digits "6794" | Unit |
| `testCombinedHeaderStringFormatTwoDigitNumber` | `"12. Trips Left 2943"` — play number 12, multi-word formation | Unit |
| `testCombinedHeaderStringFormatFiveDigitRoute` | `"3. Twins 67941"` — 5-digit route string produces correct combined row | Unit |
| `testCombinedHeaderStringFormatProFormation` | `"2. Pro Right 6794"` — formation name with space and direction | Unit |
| `testWristbandDiagramZoneTopYIsPositive` | `WristbandCardConfig.standard().diagramZoneTopY > 0` | Unit |
| `testWristbandDiagramZoneTopYFitsInCard` | `WristbandCardConfig.standard().diagramZoneTopY < WristbandCardConfig.standard().cardHeight` | Unit |
| `testWristbandDiagramZoneHeightIsPositive` | `WristbandCardConfig.standard().diagramZoneSize.height > 0` | Unit |
| `testWristbandDiagramZoneFitsInCard` | `diagramZoneTopY + diagramZoneSize.height + cardInset + 14 <= cardHeight` (the full card interior is not overflowed) | Unit |
| `testCatalogDiagramZoneTopYIsPositive` | `CatalogCardConfig.standard().diagramZoneTopY > 0` | Unit |
| `testCatalogDiagramZoneTopYFitsInCard` | `CatalogCardConfig.standard().diagramZoneTopY < CatalogCardConfig.standard().cardHeight` | Unit |
| `testCatalogDiagramZoneHeightIsPositive` | `CatalogCardConfig.standard().diagramZoneSize.height > 0` | Unit |
| `testCatalogDiagramZoneFitsInCard` | `diagramZoneTopY + diagramZoneSize.height + cardInset <= cardHeight` | Unit |
| `testWristbandPDFGeneratesAfterHeaderRestructure` | `WristbandPDFGenerator.generate(cards: [oneCard])` returns non-nil; `PDFDocument(data:)` non-nil; `pageCount == 1` | Integration |
| `testCatalogPDFGeneratesAfterHeaderRestructure` | `CatalogPDFGenerator.generate(cards: [oneCard])` returns non-nil; `pageCount == 1` | Integration |
| `testWristbandPDFWithConceptAndMotionDoesNotCrash` | A card with `conceptName != nil` and `motionLabel != nil` generates a non-nil, non-empty wristband PDF | Integration |
| `testCatalogPDFWithConceptAndMotionDoesNotCrash` | Same for catalog | Integration |
| `testWristbandHeaderRestructureDoesNotChangePageCount` | 3 cards -> 3 pages (same as existing `testThreeCardsProducesThreePages`, run again to confirm restructure did not break pagination) | Integration |
| `testCatalogHeaderRestructureDoesNotChangePageCount` | 10 cards -> 2 pages (same as existing `testTenPlaysProducesTwoPages`, run again as regression) | Integration |

**Note on combined-row string format tests:** `WristbandPDFGenerator` and `CatalogPDFGenerator` currently embed the row text composition inline in `drawCard`. If the implementation extracts this to a named function or computed property on `ExportCard`, the unit tests can call it directly. If it remains inline in the draw method (a private method on a private class), the tests can only verify the string format through a helper method tested in isolation, or via a test-visible method added specifically for testability. The implementing engineer should expose either a static helper function or a `combinedHeaderString` computed property on `ExportCard` so these unit tests remain at the unit level rather than requiring full PDF rendering.

**If no seam is exposed:** Tests `testCombinedHeaderStringFormat*` are folded into the integration-level PDF render tests (generate a PDF with a known card and verify non-nil — the string format is then verified only by Ken's visual sign-off). The strategy prefers the seam approach but documents the fallback.

### 5.2 Receiver Letter Label Tests

**File:** `SpartansPlaycallerTests/DiagramRendererReceiverLabelTests.swift`
**Class:** `DiagramRendererReceiverLabelTests` (plain `XCTestCase`, no `@MainActor` — `DiagramRenderer` is a plain struct with no actor isolation)

The test setup uses the same `UIGraphicsPDFRenderer` helper pattern already established in `DiagramRendererCGContextTests.swift`.

| Test | What it asserts | Type |
|------|----------------|------|
| `testReceiverLabelsDoNotCrashTwins` | Full render with `.twins` + "6794" completes, returns non-nil Data, non-empty | Integration |
| `testReceiverLabelsDoNotCrashTripsLeft` | Full render with `.tripsLeft` + "2943" completes, non-nil | Integration |
| `testReceiverLabelsDoNotCrashTripsRight` | Full render with `.tripsRight` + "8761" completes, non-nil | Integration |
| `testReceiverLabelsDoNotCrashProLeft` | Full render with `.proLeft` + "6794" completes, non-nil | Integration |
| `testReceiverLabelsDoNotCrashProRight` | Full render with `.proRight` + "6794" completes, non-nil | Integration |
| `testReceiverLabelsDoNotCrashFiveDigitPlay` | Full render with `.twins` + "67941" (5-digit, includes H) completes, non-nil | Integration |
| `testReceiverLabelsDoNotCrashWithYWheelEnabled` | `PlayCall.applying(nil, yWheelEnabled: true, to: pc)` where `pc` is Twins/6794; full render, non-nil | Integration |
| `testReceiverLabelsDoNotCrashWithMotionApplied` | `PlayCall.applying(.stop, yWheelEnabled: false, to: pc)` where `pc` is TripsLeft/2943; full render, non-nil | Integration |
| `testReceiverLabelsDoNotCrashWithMotionAndYWheel` | Motion + Y Wheel combined; full render, non-nil | Integration |
| `testReceiverLabelsPDFIsMagicBytesValid` | First 4 bytes of rendered Data == `[0x25, 0x50, 0x44, 0x46]` (%PDF) | Integration |
| `testReceiverLabelsDoNotCrashWristbandConfig` | Uses `DiagramConfig.wristbandCardScale(for:)` (the smaller config); full render, non-nil | Integration |
| `testContextStateAfterDrawReceiversIsIntact` | After a full `draw(into:playCall:config:in:)` call, the PDF renders without throwing and produces a valid (non-empty) document — validates that `drawReceiversCG` does not leak a corrupt transform onto the outer context | Integration |

**Design note — `testContextStateAfterDrawReceiversIsIntact`:** This test is structurally identical to the non-crash tests. Its purpose is to make the intent explicit in the test name so a future reader understands why the test exists (context state safety, not just "does it work"). If a context state leak occurs, the PDF output is likely to be corrupted (zero-size drawing bounds or misaligned paths), which may manifest as an empty Data or a PDF with zero-area content. This test provides a hook for investigation if a future refactor introduces a state leak.

**Why not assert pixel content?** XCTest provides no API for asserting specific pixel values or text presence within a CGContext-rendered bitmap without a snapshot testing library (not in scope per project norms). The non-crash and magic bytes checks are the maximum automated verification achievable within XCTest constraints. Visual correctness is delegated to Ken's sign-off (Section 6).

**DiagramConfig factory method note:** The existing `DiagramRendererCGContextTests.swift` uses `DiagramConfig.catalogCardScale(for:)` and `DiagramConfig.wristbandCardScale(for:)`. These must continue to exist after Change B. If the implementation renames or removes these factory methods, all existing `DiagramRendererCGContextTests` tests will fail at compile time — a breaking change that must be fixed before merge.

---

## 6. Not Testable via XCTest — Visual Sign-Off Required

The following acceptance criteria cannot be verified by automated tests using XCTest. Each requires Ken's eyes on a rendered PDF.

| Item | Why not automatable | Sign-off required |
|------|---------------------|-------------------|
| Combined header row text is legible and not clipped | PDF text content cannot be extracted via PDFKit without `PDFPage.string` which requires accessibility content; core text layout within a card is not exposed as a queryable structure | Ken |
| Combined header row is visually balanced (not crowded, appropriate spacing before concept/motion row) | Subjective layout quality; no automated metric | Ken |
| Receiver letter (X/Y/Z/A/H) is centered inside the dot | Pixel-level centering of a CGContext-drawn string cannot be asserted without snapshot testing | Ken |
| Receiver letter font size is readable at wristband card scale (3.5" x 2.5" printed) | Legibility at print scale is a physical measurement; no simulator equivalent | Ken (printed card) |
| Receiver letter font size is readable at catalog card scale (smaller card, 234x174pt) | Same as above; catalog cards are smaller than wristband | Ken (printed card) |
| Receiver letter color has sufficient contrast against the translucent dot fill | Color contrast requires pixel sampling; not available in XCTest without snapshot library | Ken |
| Diagram zone vertical position is correct after header shift (no header/diagram overlap, no dead gap) | Vertical position of drawn elements within a PDF page is not queryable via PDFKit | Ken |
| Notes rule line at card bottom still renders at correct position after header shift | Same as above | Ken |
| Y Wheel arc renders correctly after receiver label addition (no visual interference) | Visual positioning | Ken |
| Motion post-position "Y" label renders at the correct post-motion dot position | Position of drawn text within CGContext not queryable | Ken |

**Sign-off process:** Ken must open the generated PDF in a PDF viewer (Preview on macOS or Files on iOS), zoom to 100% or higher, and confirm each item listed above before the feature is declared complete. This is not optional — the automated tests establish that the PDF is structurally valid and does not crash; they do not establish that it is correct.

---

## 7. Acceptance Criteria Mapping

| Acceptance Criterion | Test(s) | Type |
|---------------------|---------|------|
| Combined row "N. Formation Digits" replaces three rows | `testCombinedHeaderStringFormat*` (if seam exposed) | Unit |
| Wristband PDF still produces correct page count after restructure | `testWristbandHeaderRestructureDoesNotChangePageCount` + existing `testThreeCardsProducesThreePages` | Integration |
| Catalog PDF still produces correct page count after restructure | `testCatalogHeaderRestructureDoesNotChangePageCount` + existing `testTenPlaysProducesTwoPages` | Integration |
| Both generators produce valid PDFs (non-nil, magic bytes valid) | `testWristbandPDFGeneratesAfterHeaderRestructure`, `testCatalogPDFGeneratesAfterHeaderRestructure` | Integration |
| `diagramZoneTopY` and `diagramZoneSize.height` are consistent with card interior | `testWristband/CatalogDiagramZone*` geometry tests | Unit |
| No crash for all formations with receiver labels | `testReceiverLabelsDoNotCrash*` (8 formation/configuration tests) | Integration |
| H receiver label rendered correctly in 5-digit play | `testReceiverLabelsDoNotCrashFiveDigitPlay` | Integration |
| Context state not corrupted by new letter-drawing code | `testContextStateAfterDrawReceiversIsIntact` | Integration |
| Y Wheel and motion combinations still render with labels | `testReceiverLabelsDoNotCrashWithYWheelEnabled`, `testReceiverLabelsDoNotCrashWithMotionApplied`, `testReceiverLabelsDoNotCrashWithMotionAndYWheel` | Integration |
| Visual correctness of combined header row | Ken sign-off | Manual |
| Visual correctness of receiver letters centered in dots | Ken sign-off | Manual |
| Legibility at print scale for both card sizes | Ken sign-off (printed card) | Manual |

---

## 8. Environment Prerequisites

- **Xcode 15 or later.** All APIs used (PDFKit, UIGraphicsPDFRenderer, CGContext, NSString drawing) are available in iOS 17+ simulators under Xcode 15+.
- **Any iPhone simulator.** No physical device required for automated tests. Physical device required for print legibility sign-off (Ken's manual step only).
- **No third-party test dependencies.** XCTest only, consistent with project norms.
- **No `@MainActor` annotation required** on either new test class. `WristbandPDFGenerator` and `CatalogPDFGenerator` are plain structs. `DiagramRenderer` is a plain struct. Neither `PlayLibraryStore` nor `PlayCallerViewModel` is exercised in these tests.
- **`ExportCard.from(playCall:motion:playNumber:)` must be accessible** from the test target (`@testable import SpartansPlaycaller`). It is currently a non-private `static func` on `ExportCard` — no change needed.
- **`DiagramConfig.wristbandCardScale(for:)` and `DiagramConfig.catalogCardScale(for:)` factory methods must not be renamed or removed.** Both are used in existing and new tests.
- **Run command:** `xcodebuild test -scheme SpartansPlaycaller -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.5'` (or current simulator/OS pair in the project's CI config). The same command used for all prior test runs.

---

## 9. Platform Matrix

Not applicable. Spartans Playcaller is a native iOS application. There is no browser layer, no cross-platform matrix, and no web rendering concern. Automated tests run on Xcode iPhone simulator. Manual sign-off requires a PDF viewer that renders CGContext-drawn content faithfully — Preview on macOS is sufficient.

---

## 10. Flake Risk Assessment

**Low flake risk overall.** All new tests are deterministic:

- String formatting is pure function on struct fields — no timing, no randomness.
- Config arithmetic is compile-time-constant struct properties — no runtime variance.
- PDF rendering via `UIGraphicsPDFRenderer` and `PDFKit` is synchronous and deterministic given the same input.
- No network calls, no file system access, no async state in any new test.
- No `sleep` or `XCTestExpectation` required.

The only potential for unexpected failure is a platform API change in `NSString.draw(in:withAttributes:)` behavior between simulator OS versions, which is not a concern for a minor point release. These tests are stable by construction.

---

## 11. Done-When Criteria for SDET Step 8

The SDET step for this feature is not complete until all of the following are true:

1. `SpartansPlaycallerTests/PDFCardHeaderTests.swift` exists, compiles, and all tests pass.
2. `SpartansPlaycallerTests/DiagramRendererReceiverLabelTests.swift` exists, compiles, and all tests pass.
3. All pre-existing tests pass without modification — or, if `cardHeight` changed in either config struct, the three geometry tests in `CatalogPDFGeneratorTests.swift` have been updated with correct values and still pass.
4. `xcodebuild test -scheme SpartansPlaycaller` exits 0 with no test failures.
5. Ken has confirmed visual sign-off on the items listed in Section 6.
6. `docs/test-plans/pdf-card-labels-test-results.md` exists and documents: total test count, pass/fail per class, which ACs are automated-verified, and which require Ken's sign-off with their sign-off status.

Step 8 is not satisfied by "tests passed during implementation." The SDET executes the full suite independently and produces the results file.
