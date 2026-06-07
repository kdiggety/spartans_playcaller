# Wristband Export — Test Strategy

**Epic:** 3.1 — Wristband Export & Game-Day Deployment
**Date:** 2026-06-07
**Author:** SDET
**Status:** PLANNING GATE ARTIFACT — required before implementation plan may be written
**Spec reference:** `docs/superpowers/specs/2026-06-07-wristband-export-spec.md`

---

## 1. Regression Scope

### 1.1 Risk Summary

The two highest regression risks introduced by this epic are:

1. **DiagramRenderer reuse in a PDF context.** `DiagramRenderer` currently serves only SwiftUI Canvas on-screen rendering. Epic 3.1 requires producing a `CGImage` or `UIImage` from it via an off-screen `UIGraphicsImageRenderer` (or equivalent) and embedding that image in a `PDFPage`. Any change to `DiagramRenderer` to support off-screen rendering — added parameters, refactored method signatures, or split render paths — can silently break the existing on-screen Canvas calls that 18 existing tests exercise.

2. **PlayCallerViewModel state.** The export button's enabled/disabled state reads `currentPlayCall` and `currentPlayCallWithMotion`. Any new ViewModel state introduced to drive the export action sheet or share sheet must not disturb existing motion state management tests.

### 1.2 Existing Test Files That Must Remain Green

All 18 test files below are in `SpartansPlaycallerTests/`. None may regress.

| File | Tests | DiagramRenderer risk | ViewModel risk |
|------|-------|----------------------|----------------|
| `ConceptMatcherTests.swift` | 18 | Low | Low |
| `DiagramRendererWheelRenderingTests.swift` | Unknown | **HIGH** — directly exercises DiagramRenderer draw paths | None |
| `DiagramRendererYWheelTests.swift` | 2+ | **HIGH** — `yWheelArcPath()` called directly | None |
| `PlayCallerViewModelTests.swift` | 24 | None | **HIGH** — all ViewModel state |
| `PlayCallFlowYWheelTests.swift` | Unknown | Medium | Medium |
| `PlayCallWheelToggleFlowTests.swift` | Unknown | Medium | Medium |
| `ReceiverMotionTests.swift` | 11 | None | Low |
| `ReceiverMotionWheelTests.swift` | Unknown | None | None |
| `ReceiverMotionWheelToggleTests.swift` | Unknown | None | None |
| `RouteDiagramViewTests.swift` | 14+ | Medium — instantiates view that uses DiagramRenderer | None |
| `RouteDiagramYWheelTests.swift` | Unknown | Medium | None |
| `RouteInterpreterTests.swift` | 25 | None | None |
| `RouteSemanticProviderTests.swift` | Unknown | None | None |
| `Y_WheelComprehensiveTests.swift` | Unknown | **HIGH** — broad Y Wheel path coverage | None |
| `Y_WheelDiagramIntegrationTests.swift` | Unknown | **HIGH** — integration across renderer + view | None |
| `Y_WheelRobustnessTests.swift` | Unknown | Medium | None |
| `YWheelArcDiagnosticTests.swift` | Unknown | **HIGH** — arc geometry assertions | None |
| `YWheelArcVisualSpecTests.swift` | Unknown | **HIGH** — visual spec assertions on arc shape | None |

**Gate:** The full test suite (`xcodebuild test`) must pass before and after this epic lands. Software-engineer must run and report results at implementation Step 6. SDET confirms again at Step 8.

### 1.3 No UITests Target Exists

There is no `SpartansPlaycallerUITests/` directory. This epic does not introduce one. E2E automation is constrained to XCTest unit/integration tests within `SpartansPlaycallerTests/`. See Section 3.3 for the share sheet limitation.

---

## 2. Test Pyramid Balance

### 2.1 Pyramid Summary

```
              E2E / UI Automation
             (0% — share sheet not automatable;
              manual smoke test replaces this layer)

          Integration Tests  (~40%)
     DiagramRenderer off-screen image generation
     PDF content verification (field values present)
     ViewModel export state (button enable/disable)
     File I/O (temp file write + cleanup)
     Error path (PDF failure → no crash)

        Unit Tests  (~60%)
   WristbandCard model: field population, nil-omission
   PDF layout math: card grid geometry, margin arithmetic
   Temp file naming: filename format validation
   Y Motion label mapping: enum → display string
   Concept nil-omission logic
```

The pyramid is unit-heavy because the PDF generator is a pure function (`PlayCall` in, `Data` out) with deterministic layout math. Integration tests cover the boundary between DiagramRenderer output and the PDF page. The E2E layer is replaced by a manual smoke test due to the UIActivityViewController constraint.

### 2.2 Unit Tests: What They Cover

**Target type: `WristbandPDFGenerator` (new service) and any `WristbandCard` model type**

| Test class | What it proves |
|-----------|----------------|
| `WristbandCardModelTests` | Given a `PlayCall` with concept nil, the card model's conceptName is nil. Given a play call with concept "Smash", conceptName == "Smash". Given Y Motion == .stop, the motionLabel is "Y Stop". Given Y Motion == nil, motionLabel is nil. |
| `WristbandCardLayoutTests` | Card grid math: four cards fit in 8.5"×11" US Letter with 0.25" margins and 0.125" gutters. Card dimensions equal 3.5"×2.5" in points (252pt × 180pt at 72dpi). No card extends beyond the printable area. |
| `WristbandFilenameTests` | Given formation "Twins" and digits "6794", the filename is "Twins-6794-wristband.pdf". Special characters in formation names are sanitized. |
| `WristbandMotionLabelTests` | `ReceiverMotion.stop` → "Y Stop". `ReceiverMotion.after` → "Y Go". `nil` → no label emitted. These are pure enum-to-string mappings; no external dependencies. |
| `WristbandPlayNumberTests` | V1: play number is always "1". Card model emits "1" regardless of `PlayCall` content. |

### 2.3 Integration Tests: What They Cover

**Target: DiagramRenderer producing an image; PDF data validity; ViewModel state**

| Test class | What it proves |
|-----------|----------------|
| `DiagramRendererOffScreenTests` | `DiagramRenderer` can produce a non-nil `UIImage` (or `CGImage`) when rendered off-screen via `UIGraphicsImageRenderer` at a card-appropriate size (e.g., 252×108pt at 2x scale for the lower 40% of the card). Existing Canvas rendering tests must still pass after any changes enabling this. |
| `WristbandPDFGeneratorIntegrationTests` | Given a valid `PlayCall`, `WristbandPDFGenerator.generate(playCall:)` returns non-nil `Data`. The returned `Data` begins with `%PDF-` (PDF magic bytes). The `Data` has length > 1000 bytes (non-trivial document). |
| `WristbandPDFContentTests` | Using `PDFKit` to re-read the generated `Data`, verify: the document has exactly 1 page; the page media box is 8.5"×11" (612×792pt); page content is non-empty. Content string extraction (where PDFKit supports it) confirms formation name and digit string appear in the document text layer. |
| `WristbandPDFYWheelTests` | Given `PlayCall.yWheelEnabled == true`, `generate(playCall:)` returns non-nil `Data` without crashing. The mini diagram image embedded in the PDF is produced from the Y Wheel arc path, not the numbered route path. (Verified by confirming the code path taken — not by pixel inspection.) |
| `WristbandPDFErrorHandlingTests` | Given a corrupt or nil rendering context (simulated via a stub/seam), `generate(playCall:)` does not throw an unhandled exception; it returns nil or throws a typed error. The ViewModel catch block can receive this error and not crash. |
| `PlayCallerViewModelExportStateTests` | Given `currentPlayCall == nil`, `canExport` (or equivalent computed property) is false. Given a valid `currentPlayCall`, `canExport` is true. Given `reset()` is called, `canExport` returns to false. These tests extend `PlayCallerViewModelTests.swift` or live in a new file. |
| `WristbandTempFileTests` | If the implementation writes a temp file before presenting the share sheet: the temp file exists on disk after `generate()`, and the file is deleted after the share sheet is dismissed (or a cleanup method is called). Verified using `FileManager.fileExists`. |

### 2.4 E2E / UI Automation: What Cannot Be Automated

`UIActivityViewController` (the iOS share sheet) is a system-provided view. XCUITest cannot interact with its content — selecting "Print", "Save to Files", or "AirDrop" programmatically is not possible in the simulator or on device via XCTest. Apple's system views are not accessible to the test process.

**Consequence:** There is no automated E2E test for the complete export flow from button tap through share sheet activity selection. This is a known, platform-imposed limitation — not a test coverage gap that can be closed with additional tooling.

**What replaces the E2E layer:** A documented manual smoke test (see Section 3.4).

---

## 3. Acceptance Criteria Mapped to Tests

### Story 3.1.1: Wristband Card Format

| Acceptance Criterion | Test coverage | Test type |
|----------------------|--------------|-----------|
| Card layout matches Section 3 (fields, order, dimensions) | `WristbandCardLayoutTests` — grid geometry; `WristbandCardModelTests` — field population | Unit |
| Text legible at 18" by average vision after printing | **Not automatically testable.** Manual verification: print one card on standard inkjet at 300 dpi, review at 18". Ken confirms. | Manual (Story 3.1.5 gate) |
| Concept name appears and is visually distinct when matched | `WristbandCardModelTests` — conceptName populated when concept non-nil. Visual distinction (font weight/size/color) not assertable in unit test. | Unit (presence) + Manual (visual) |
| No Y Motion field when Y Motion is None | `WristbandMotionLabelTests` — nil motion produces nil label; label is not emitted. `WristbandPDFContentTests` — content string does not contain "Y Stop" or "Y Go" for a no-motion play. | Unit + Integration |
| Y Motion field appears when After/Go | `WristbandMotionLabelTests` — .after → "Y Go". `WristbandPDFContentTests` — content string contains "Y Go". | Unit + Integration |
| Ken confirms format matches coaching intent (sign-off AC) | **Not automatically testable.** Ken physical review required. Blocks Story 3.1.5. | Manual sign-off |

### Story 3.1.2: Export Flow UX

| Acceptance Criterion | Test coverage | Test type |
|----------------------|--------------|-----------|
| Export button visible and tappable when play call present | `PlayCallerViewModelExportStateTests` — `canExport` true. Button rendering: **Not automatable** without UITest target. | Integration (state) + Manual |
| Export button disabled when no play call | `PlayCallerViewModelExportStateTests` — `canExport` false when `currentPlayCall == nil`. | Integration |
| Action sheet title and subtitle display current play | **Not automatically testable** (action sheet is presented by UI, not ViewModel). Manual smoke test. | Manual |
| Share sheet presents with print/Files/email/AirDrop options | **Not automatically testable** (UIActivityViewController content). Manual smoke test. | Manual |
| Cancel leaves app state unchanged | `PlayCallerViewModelExportStateTests` — simulate cancel: `currentPlayCall` and motion state unchanged. | Integration |
| UX/Ken review confirms intuitive entry point | **Not automatically testable.** Stakeholder review. | Manual sign-off |

### Story 3.1.3: PDF Generation

| Acceptance Criterion | Test coverage | Test type |
|----------------------|--------------|-----------|
| `generate(playCall:)` returns non-nil `Data` for any valid `PlayCall` | `WristbandPDFGeneratorIntegrationTests` | Integration |
| PDF renders without errors in any viewer | `WristbandPDFContentTests` — document parses cleanly via `PDFDocument(data:)`, page count == 1 | Integration |
| Card displays all required fields for "Twins 6794" | `WristbandPDFContentTests` — string extraction finds formation, digits, play number | Integration |
| No concept field when concept is nil | `WristbandCardModelTests` (unit) + `WristbandPDFContentTests` (integration via string extraction) | Unit + Integration |
| "Y Stop" appears when Y Motion == .stop | `WristbandMotionLabelTests` + `WristbandPDFContentTests` | Unit + Integration |
| Y Wheel mini diagram renders Y arc path | `WristbandPDFYWheelTests` — non-nil output, correct code path; `DiagramRendererOffScreenTests` — arc image produced off-screen | Integration |
| 2×2 grid fits within printable area; four identical cards | `WristbandCardLayoutTests` — grid math; PDF page size assertion in `WristbandPDFContentTests` | Unit + Integration |
| No third-party frameworks imported | Static: code review during auditor step. Dynamic: not testable via XCTest. | Auditor (conformance) |
| Completes synchronously in ≤ 500ms on iPhone 13 | **Performance-engineer scope** — covered in performance plan, not this strategy. Noted here for traceability. | Performance gate |

### Story 3.1.4: Export UI in PlayCallerView

| Acceptance Criterion | Test coverage | Test type |
|----------------------|--------------|-----------|
| Share icon button appears in trailing nav bar position | **Not automatable** (no UITest target). Manual smoke test. | Manual |
| `isEnabled == false` when both play call properties are nil | `PlayCallerViewModelExportStateTests` | Integration |
| Tapping export button presents action sheet (not push/modal) | **Not automatable.** Manual smoke test. | Manual |
| `UIActivityViewController` presented with correct filename | **Not automatable** (system VC). Manual smoke test: confirm filename "Twins-6794-wristband.pdf" in share sheet. | Manual |
| AirPrint dialog appears when Print selected | **Requires physical device with AirPrint-compatible printer.** Not testable in simulator. | Manual (device) |
| PDF saved to Files when Save to Files selected | **Not automatable.** Manual smoke test on device. | Manual |
| Play call state unchanged after dismiss | `PlayCallerViewModelExportStateTests` — cancel simulation | Integration |
| Error alert presented on PDF generation failure; no crash | `WristbandPDFErrorHandlingTests` — ViewModel catch verified in unit/integration test | Integration |

### Story 3.1.5: Coach Field Validation

All acceptance criteria in Story 3.1.5 are field-validation criteria: physical print, outdoor lighting, lamination, practice use. None are automatable. All require Ken's manual sign-off. This story cannot be closed by automated tests — it requires a physical wristband card produced from a real export, printed and used in a practice or walk-through session.

**SDET role in Story 3.1.5:** Produce `docs/test-plans/wristband-export-test-results.md` after automated tests pass, documenting which ACs are automated-verified and which require Ken's sign-off. The results report is the SDET's done-when for Step 8.

---

## 4. Test Environment Prerequisites

### 4.1 Automated Tests (Unit + Integration)

- **Xcode 15.0 or later** — PDFKit APIs used in PDF generation are available in iOS 11+; the project targets iOS 17+, which is fully supported in Xcode 15 simulators.
- **Any iPhone simulator** — PDF generation, `UIGraphicsImageRenderer`, and `PDFKit` all function correctly in the simulator. No physical device required for unit or integration test execution.
- **No network access required** — The entire feature is on-device. Tests must not depend on network reachability.
- **Run command:** `xcodebuild test -scheme SpartansPlaycaller -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.5'` (or current scheme/simulator name).
- **No third-party test dependencies** — all tests use XCTest from Xcode's standard toolchain.

### 4.2 Manual Smoke Test (Export Flow)

- **iPhone simulator or physical device** — The share sheet can be triggered in the simulator; however, activities like Print and Save to Files require a physical device for full validation.
- **AirPrint testing** — Requires a physical iPhone running iOS 17+ and an AirPrint-compatible printer on the same network. This test is out of scope for CI and is a one-time manual validation for Story 3.1.5 acceptance.

### 4.3 Physical Print Validation (Story 3.1.5 Only)

- Standard inkjet or laser printer capable of 300 dpi output.
- 8.5"×11" US Letter paper.
- Consumer lamination pouch (optional, for legibility-after-lamination check).
- No CI environment can replicate this — it is a coaching-domain acceptance test performed by Ken.

---

## 5. Pre-Existing Test Infrastructure Caveats

### 5.1 No UITest Target

The project has no `SpartansPlaycallerUITests/` target. The E2E automation gap documented in Section 2.4 is a structural consequence of this, not a gap introduced by this epic. If a UITest target is added in a future epic, the manual smoke tests in this strategy would be candidates for automation (button enabled/disabled state, action sheet title, at minimum).

### 5.2 Shallow `@MainActor` Test Pattern

Existing tests in `PlayCallerViewModelTests.swift` use `nonisolated(unsafe) var viewModel` initialized inside `MainActor.assumeIsolated`. New ViewModel tests for export state must follow this existing pattern to avoid Swift concurrency isolation violations. The pattern is workable but brittle — any test that accidentally calls a `@MainActor` method from a non-isolated context will produce a runtime assertion, not a compile error.

### 5.3 Visual Assertion Gap

Several existing test files (e.g., `YWheelArcVisualSpecTests.swift`, `YWheelArcDiagnosticTests.swift`) contain geometric assertions on path points rather than pixel-level rendering assertions. The same approach applies here: PDF content tests use `PDFKit`'s text extraction and page geometry APIs to assert content presence, not pixel comparison. Pixel-level legibility is not assertable via XCTest — it requires human visual review (Section 3.4, Story 3.1.5).

### 5.4 DiagramRenderer Off-Screen Rendering Seam

`DiagramRenderer` does not currently expose a method to produce a `UIImage` or `CGImage`. Depending on the architecture decision (Step 3), new API surface on `DiagramRenderer` (or an adapter type in `Services/`) will be needed. This new surface is the primary regression risk for existing DiagramRenderer tests. The test strategy for `DiagramRendererOffScreenTests` must be written after the architecture decision resolves the rendering strategy (Canvas-to-image vs direct `CGContext` in `PDFPage`).

Until the architecture decision is made, `DiagramRendererOffScreenTests` is a placeholder with `[TBD: rendering strategy]`. The test class must be created; its assertions are filled in during implementation Step 6.

### 5.5 PDFKit Text Extraction Reliability

`PDFPage.string` (text extraction) is reliable for text drawn via PDFKit's `draw(with:to:)` text methods. If the PDF generator draws text via Core Graphics directly (rather than PDFKit text APIs), `PDFPage.string` may return nil or incomplete content. In that case, the integration test falls back to asserting `Data` validity and page geometry only, and formation/digits presence is verified via the manual smoke test. This limitation is noted here so it is not treated as a test failure if string extraction returns nil — it is a PDFKit behavior boundary.

---

## 6. Browser Matrix

**Not applicable.** Spartans Playcaller is a native iOS application (SwiftUI, iOS 17+). There is no web layer, no browser rendering, and no cross-browser compatibility concern. This section exists to explicitly confirm the inapplicability, as required by the test strategy template.

**Platform matrix** for this epic is: iPhone running iOS 17+, tested via Xcode simulator (iPhone 15 or current) for automated tests, and physical iPhone for AirPrint validation in Story 3.1.5.

---

## 7. Manual Smoke Test Charter

Because the E2E share sheet flow cannot be automated, the following manual smoke test must be executed by SDET (or Ken) before `docs/test-plans/wristband-export-test-results.md` is written.

**Precondition:** App built and installed on simulator or device. At least one formation selected and route digits entered to produce a valid play call.

| Step | Action | Expected result |
|------|--------|----------------|
| 1 | Launch app; do not enter any play call | Export button visible in nav bar; button is grayed out / non-interactive |
| 2 | Enter "Twins" + "6794"; tap Parse | Play call displayed; export button becomes interactive |
| 3 | Tap export button | Action sheet appears titled "Export Wristband Card" with subtitle "Twins 6794" |
| 4 | Tap "Cancel" | Action sheet dismisses; play call still displayed; no file created |
| 5 | Tap export button again; tap "Export as PDF" | Share sheet appears; "Print" and "Save to Files" are among the available activities |
| 6 | From share sheet, tap "Save to Files" | Files location picker appears; saving produces a file named "Twins-6794-wristband.pdf" |
| 7 | Open the saved PDF in Files | PDF opens; 1 page visible; 2×2 grid of four identical cards; formation "Twins", digits visible; mini diagram present in each card |
| 8 | Repeat steps 2–7 with a play call that has Y Motion applied (e.g., Trips Left + Y After) | Card shows "Y Go" in motion field; mini diagram shows post-motion position |
| 9 | Repeat with a play call that has Y Wheel enabled | Mini diagram shows Y Wheel arc path |
| 10 | (Device only) Tap Print in share sheet | AirPrint dialog appears; print to any available printer; physical card examined for legibility at 18" |

**Pass condition:** All steps produce the expected result without app crash, hang, or missing content.

**Failure handling:** Any step failure is filed as a defect with the step number, actual result, and a screenshot. Software-engineer is dispatched to fix before SDET re-runs.

---

## 8. Test Files to Create

The following new test files must be created under `SpartansPlaycallerTests/` during implementation:

| File | Layer | Priority |
|------|-------|----------|
| `WristbandCardModelTests.swift` | Unit | P0 — covers card content model |
| `WristbandCardLayoutTests.swift` | Unit | P0 — covers grid geometry |
| `WristbandMotionLabelTests.swift` | Unit | P0 — covers Y Motion label mapping |
| `WristbandFilenameTests.swift` | Unit | P1 — covers filename format |
| `WristbandPlayNumberTests.swift` | Unit | P1 — covers V1 play number default |
| `WristbandPDFGeneratorIntegrationTests.swift` | Integration | P0 — covers generate() returns valid PDF |
| `WristbandPDFContentTests.swift` | Integration | P0 — covers field presence via PDFKit |
| `WristbandPDFYWheelTests.swift` | Integration | P0 — covers Y Wheel path in PDF |
| `WristbandPDFErrorHandlingTests.swift` | Integration | P1 — covers failure → no crash |
| `DiagramRendererOffScreenTests.swift` | Integration | P0 — covers off-screen image generation; assertions [TBD until architecture decision] |
| `PlayCallerViewModelExportStateTests.swift` | Integration | P0 — covers canExport state transitions |
| `WristbandTempFileTests.swift` | Integration | P1 — covers temp file lifecycle (only if implementation uses temp files) |

P0 tests block merge. P1 tests are required before the epic is declared complete but may trail implementation by one cycle if P0 suite is passing and P1 scope is confirmed low-risk.

---

## 9. Done-When for SDET Step 8

SDET's step is not complete until **all** of the following are true:

1. All P0 and P1 test files listed in Section 8 exist on disk and pass (`xcodebuild test` exits 0).
2. All 18 pre-existing test files in Section 1.2 still pass (no regressions).
3. Manual smoke test charter (Section 7) has been executed; all steps passed or defects filed.
4. `docs/test-plans/wristband-export-test-results.md` exists and documents: automated test count, pass/fail status, which ACs are automated-verified, which require Ken's manual sign-off, and which open defects (if any) exist.

---

## 10. Open Questions Affecting Test Design

These mirror open questions from the product spec (Section 9) and affect test content if resolved differently from the spec's recommendations.

| # | Question | Test impact if resolved differently |
|---|----------|-------------------------------------|
| 1 | Post-motion vs pre-motion diagram on card | `WristbandPDFYWheelTests` and `WristbandPDFContentTests` must use correct `PlayCall` object. If pre-motion is chosen, `DiagramRendererOffScreenTests` uses base formation positions. |
| 2 | 4-up grid vs single-card page | `WristbandCardLayoutTests` grid math changes entirely. Currently written for 2×2 grid. |
| 3 | Motion label format ("Y Stop"/"Y Go" vs full rawValue) | `WristbandMotionLabelTests` asserts against the agreed label strings. |
| 4 | Play number: "1", blank, or omitted | `WristbandPlayNumberTests` asserts the agreed behavior. |
| 5 | Team branding on card | If added, `WristbandCardModelTests` gains a branding field test. If omitted, no change. |
| 6 | US Letter vs A4 page size | `WristbandCardLayoutTests` page dimension assertions must match the agreed page size. |

These questions must be resolved before P0 test files are written. The answers are Ken's, per the spec's open questions section.
