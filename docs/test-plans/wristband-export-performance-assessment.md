# Performance Assessment: Epic 3.1 — Wristband Export

**Date:** 2026-06-07
**Status:** PERFORMANCE PLAN REQUIRED (lightweight — see Section 6)
**Feature:** On-device PDF generation of a 4-up wristband card sheet via PDFKit
**Engineer:** Performance Engineer

---

## 1. Performance Relevance

Wristband export is performance-sensitive in a narrow but user-visible way. It is not a hot path — it fires once per coach session before a game, not in a tight loop. However, it is **interactive-latency-sensitive**: the coach taps "Export as PDF," and the PDF must appear in the share sheet before they lose patience and tap again or assume the app froze.

The spec already codifies a 500ms ceiling (Story 3.1.3 acceptance criterion, Section 8 success metric 7). That is a hard acceptance gate, not a soft guideline. An assessment-only approach would be appropriate if performance were clearly incidental — but wristband export introduces three new cost centers that do not exist anywhere else in this app:

1. **Off-screen bitmap rendering.** The existing `DiagramRenderer` / `RouteDiagramView` stack runs on SwiftUI Canvas, which is on-screen and GPU-dispatched. The PDF path needs an off-screen rasterization step (UIGraphicsImageRenderer or CGContext-in-PDFPage) that runs synchronously on whatever thread calls it. This is a qualitatively different execution model with measurable CPU cost.

2. **Intermediate bitmap allocation.** Off-screen rendering for a card-sized diagram creates a UIImage (or CGImage) that lives in memory until PDF serialization completes. The size and lifecycle of this allocation are new to the app.

3. **PDFKit page layout and serialization.** PDFKit does compression, stream encoding, and cross-reference table construction synchronously during `dataRepresentation()`. For a document with embedded raster images this is non-trivial.

None of these are expected to be catastrophic on modern iPhones, but they have never been measured in this app. Because the spec names a hard latency target, this assessment defines a lightweight test plan so that target can be verified before the epic ships — not assumed.

**Verdict:** A test plan is required, scoped to a single XCTest performance baseline. Full load testing and percentile profiling are not warranted for a single-shot document export on a personal coaching app.

---

## 2. Critical Path Analysis

The export pipeline has five sequential steps. Each is analyzed below.

### Step 1 — Play Call State Capture (negligible)

Reading `currentPlayCall` from the view model is a struct copy. `PlayCall` contains a `Formation` enum, a `String`, an array of `RouteAssignment` structs (maximum 5 elements for 5 receivers), a `RouteConcept?` optional, and a `Bool`. Total memory is on the order of a few hundred bytes. Cost: sub-microsecond.

### Step 2 — Off-Screen Diagram Rendering (dominant cost)

This is the slowest step. The existing `DiagramRenderer` computes geometry (receiver positions, route paths, motion arcs, optional Y wheel arc) in CPU-only Swift arithmetic. That computation is fast — the Y Wheel assessment measured equivalent geometry at roughly 0.5–1ms.

The new cost is **rasterizing the Canvas draw calls into a bitmap** via `UIGraphicsImageRenderer`. SwiftUI Canvas renders to Metal GPU memory on the main render pass. Off-screen rendering with `UIGraphicsImageRenderer` runs in a CPU-backed CGContext. The drawing calls (paths, strokes, fills, text) are the same operations, but the execution environment loses the Metal acceleration benefit.

Estimated cost breakdown for one diagram render at card size (target card area ~252pt × 180pt, approximately the lower 40% of a 3.5" × 2.5" card at 72 dpi logical):

- Geometry computation (receiver positions, route paths): ~1–2ms (same as on-screen path)
- CGContext fill + stroke calls for ~8–15 paths (field lines, routes, receivers, arrows): ~3–8ms
- `UIGraphicsImageRenderer` bitmap finalization (compositing into PNG/CGImage in memory): ~2–5ms

**Estimated total for one diagram: 6–15ms.** The wide range reflects uncertainty about CGContext vs Metal performance on the target device; the lower bound assumes modern A-series chips handle this efficiently, the upper bound reflects CGContext being CPU-only without GPU batching.

For the 4-up grid, the diagram is rendered **once** and embedded four times as the same image — it is not rendered four times. This keeps rendering cost constant regardless of grid size.

### Step 3 — PDF Page Layout (low cost)

PDFKit layout involves computing bounding boxes and text frames for the card fields: play number (1 text element), formation name, route digits string, optional concept name, optional Y motion label. These are simple `NSAttributedString` draws into a CGContext. Cost: well under 5ms. Text layout for 6–7 short strings is the least expensive step after state capture.

### Step 4 — PDF Serialization (moderate, often overlooked)

`PDFDocument.dataRepresentation()` encodes the PDF byte stream, including embedded image data for the diagram bitmap. The diagram at card resolution will be a UIImage of roughly 252 × 180 logical points. At 2× screen scale (Retina), that is 504 × 360 pixels = ~181K pixels × 4 bytes = ~725 KB uncompressed. PDFKit embeds this as a JPEG or deflate-compressed stream, which adds ~5–15ms of compression time on the CPU.

For a 1× export (PDF logical coordinates, no scale factor), the bitmap is smaller (~45K pixels, ~180 KB), and compression is negligible. The implementation choice of scale factor for the embedded diagram image is consequential here — see Section 5.

### Step 5 — Temp File Write (fast, I/O-bound)

Writing ~200–500 KB of PDF bytes to a `FileManager.temporaryDirectory` path on a modern iPhone's NVMe flash takes 1–5ms. This is I/O-bound, not CPU-bound, and is not a limiting factor.

### Total Expected Latency

| Step | Expected Range | Notes |
|------|---------------|-------|
| State capture | < 0.1ms | Struct copy |
| Off-screen diagram render | 6–15ms | Dominant cost; CGContext-based |
| PDF page layout + text | 1–5ms | NSAttributedString text draws |
| PDF serialization + compression | 5–15ms | Depends on embedded image size |
| Temp file write | 1–5ms | NVMe flash, sequential write |
| **Total** | **13–40ms** | On iPhone 12 or newer |

The 40ms upper bound is pessimistic — it assumes large embedded bitmap and slow CGContext. The 13ms lower bound assumes a vector-path PDF page with a modestly sized embedded diagram. Both are well under the 500ms spec target, which provides ample margin. The spec target appears achievable without heroic optimization.

**Key uncertainty:** If the implementation renders the diagram at full-screen scale (e.g., `UIScreen.main.scale` = 3 for iPhone 15 Pro) rather than at the card's logical point size, bitmap dimensions grow by 9× and compression cost could push toward 80–120ms. This is avoidable with the right implementation choice (see Section 5).

---

## 3. Latency Targets

These targets are calibrated for the coaching context: a single user, one-shot export, no retry loops, no server round-trips.

| Category | Threshold | Rationale |
|----------|-----------|-----------|
| Invisible (no indicator needed) | < 200ms | Coach perceives as instant. Share sheet appears before they consciously wait. |
| Progress indicator required | 200ms – 1000ms | Noticeable delay; coach needs feedback that work is happening. |
| Unacceptable | > 1000ms | Coach will assume the app froze. Error-report risk. Trust in the tool is damaged. |
| Hard gate (spec target) | < 500ms on iPhone 13 or newer | Spec § 8 success metric 7 and Story 3.1.3 acceptance criteria. |

Based on the critical path analysis in Section 2, expected generation time is 13–40ms, placing it firmly in the "invisible" category on any supported device (iPhone 12+, iOS 17+). The 500ms gate is conservative by at least 10×. This is the right call for a spec target — it protects against unexpectedly slow implementation paths (off-thread dispatch overhead, large image buffers) without imposing an unnecessarily tight constraint.

---

## 4. Memory Impact

### Intermediate Bitmap During Rendering

The off-screen diagram rendering step allocates a bitmap buffer in `UIGraphicsImageRenderer`. Size depends on render dimensions and scale factor.

**At card logical size (252pt × 180pt):**

| Scale Factor | Pixel Dimensions | ARGB8 Buffer Size |
|-------------|-----------------|------------------|
| 1× (PDF logical) | 252 × 180 | ~175 KB |
| 2× (Retina) | 504 × 360 | ~700 KB |
| 3× (iPhone 15 Pro) | 756 × 540 | ~1.6 MB |

The buffer exists only during the rendering call and is released when `UIGraphicsImageRenderer.image()` returns — the resulting `UIImage` retains a ~700 KB backing store at 2× scale, released after PDF serialization completes.

**At full-screen scale (for context, NOT recommended):** On a 393pt × 852pt screen (iPhone 15) at 3× scale, a full-screen UIImage would be 1179 × 2556 pixels = ~12 MB. Embedding that in a PDF is unnecessary for a card-sized diagram and is the most common avoidable mistake in this type of off-screen render.

**Verdict: No caching needed.** The diagram is rendered once per export tap. There is no render loop, no repeated allocation, and the allocations are released within the same synchronous export call. Peak additional memory per export is under 2 MB at 3× scale — negligible on a device with 4–8 GB RAM. No LRU cache, no image pool, no pre-warm strategy is warranted in V1.

**Caching re-assessment trigger:** If a future version exports multiple plays in a batch (8+ cards as specified as V2 out-of-scope in spec § 6), revisit whether rendered bitmaps should be pre-computed on a background thread with a size cap.

---

## 5. Recommendations for Implementation

These are concrete directives for the software-engineer implementing `WristbandPDFGenerator`.

### 5.1 Thread Model

Run PDF generation on a **background queue**, return the `Data` to the main actor via `async/await`. The main thread must not block — even at the 13ms lower bound, blocking the main thread prevents the spinner from appearing and can cause frame drops.

Recommended pattern:

```swift
func generate(playCall: PlayCall) async throws -> Data {
    return try await Task.detached(priority: .userInitiated) {
        // all rendering and PDF construction here
    }.value
}
```

Call site on `@MainActor`:
- Show a progress indicator immediately on tap (before dispatch).
- Await the result.
- Dismiss the indicator and present `UIActivityViewController`.

### 5.2 Progress Indicator

**Show a progress indicator.** Even though the expected latency is 13–40ms and the coach will barely see it, there are three reasons to show one anyway:

1. The operation is visibly asynchronous (dispatch to background queue). Without an indicator, the coach cannot distinguish "still generating" from "tapped and nothing happened."
2. An older device (iPhone 12, the minimum supported) may take longer, especially if under thermal throttling. The indicator costs nothing and provides a safety net.
3. The coach workflow is high-stakes (game day). They must trust that tapping the button did something.

Use a simple `.overlay` with a `ProgressView` on the export button, or a modal activity sheet. Duration is short enough that an indeterminate spinner suffices — no progress percentage needed.

### 5.3 Off-Screen Render Scale Factor

Render the diagram bitmap at **1× or 2× scale, targeting the card's logical point dimensions**, not the screen's scale factor.

The card diagram occupies roughly the lower 40% of a 3.5" × 2.5" card, which at 72 dpi (PDF logical units) is approximately 252pt × 72pt. At 2× that is 504 × 144 pixels. This is sufficient for a vector-quality-comparable PDF embed at print DPI when PDFKit places it in the page coordinate system.

Do NOT use `UIScreen.main.scale` as the render scale for the bitmap. This produces unnecessarily large buffers (1.5–3× more memory, 2–5× more compression time) with no visible quality benefit on the printed card.

Concrete implementation guidance:

```swift
let diagramSize = CGSize(width: 252, height: 108) // card width × 40% height in points
let renderer = UIGraphicsImageRenderer(size: diagramSize,
    format: {
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 2.0  // explicit 2x; do not use .automatic (which uses screen scale)
        return fmt
    }())
```

### 5.4 Rendering Approach Decision

Architecture consultation (Step 3) should resolve whether to use `UIGraphicsImageRenderer` (produce a UIImage, embed in PDF) or `PDFPage` subclass with direct `CGContext` draws. From a performance standpoint:

- `UIGraphicsImageRenderer` + embedded image: simpler, slightly higher memory (bitmap buffer), compatible with any draw implementation that uses CGContext paths.
- `PDFPage` + direct CGContext draws: produces a vector PDF (no embedded raster), lower file size, higher quality at any zoom. Requires adapting the DiagramRenderer draw calls to accept a generic `CGContext` rather than SwiftUI's `GraphicsContext`.

**Performance recommendation:** The direct CGContext (vector PDF) path is preferred if architecture approves the draw-call adaptation. It eliminates the intermediate bitmap entirely, reducing memory allocation and compression cost. The resulting PDF is also scalable at any print DPI — important for the print quality acceptance criteria (spec § 3.1b: 300 dpi minimum equivalent).

If the embedded image approach is chosen, use 2× scale as specified in 5.3 above.

### 5.5 No Pre-Generation or Background Pre-Warm

Do not pre-generate the PDF speculatively when the play call changes. Export is a deliberate coach action; speculative generation wastes CPU and battery for plays the coach never exports. Generate only when "Export as PDF" is selected.

---

## 6. Test Plan

### 6.1 Objective

Verify that `WristbandPDFGenerator.generate(playCall:)` completes within the spec's 500ms target on a representative device, and that no obvious memory regression occurs during a single export.

### 6.2 Test Method

Use XCTest's built-in `measure {}` block, which runs the closure 10 times and reports mean and standard deviation. This is appropriate for a one-shot operation with low variability.

**Test file:** `SpartansPlaycallerTests/Services/WristbandPDFGeneratorTests.swift`

```swift
import XCTest
@testable import SpartansPlaycaller
import PDFKit

final class WristbandPDFGeneratorPerformanceTests: XCTestCase {

    // Representative play call: Twins formation, complex digit string, matched concept,
    // Y motion present, Y Wheel disabled. This exercises the longest rendering path
    // without Y Wheel (which is a separate draw call tested separately if needed).
    private var representativePlayCall: PlayCall {
        // Construct via PlayCallParser or directly — mirrors a real Twins Smash call
        // formation: .twins, routeDigits: "6794", concept: .smash, yWheelEnabled: false
        // Exact construction depends on PlayCallParser API; SDET should use the same
        // factory helper as other test files to avoid duplication.
        fatalError("Replace with actual PlayCall construction using test helpers")
    }

    func testPDFGenerationMeetsLatencyTarget() throws {
        let playCall = representativePlayCall
        var generatedData: Data?

        measure {
            // WristbandPDFGenerator.generate() must be synchronous for this test,
            // OR the async variant wrapped with XCTestExpectation if async.
            generatedData = WristbandPDFGenerator.generate(playCall: playCall)
        }

        // Verify output is valid (non-nil, non-empty, valid PDF header)
        let data = try XCTUnwrap(generatedData)
        XCTAssertGreaterThan(data.count, 1024, "PDF must be at least 1KB")
        XCTAssertTrue(data.starts(with: [0x25, 0x50, 0x44, 0x46]), // %PDF
                      "Output must begin with PDF magic bytes")
    }
}
```

**Baseline expectation:** The `measure {}` block will fail if mean execution time exceeds the `maxMetrics` threshold. Set the baseline via:

```
Edit scheme → Test → Performance → Set Baseline
```

After first successful run, set the baseline in Xcode to the measured mean. Accept the baseline. CI will catch regressions automatically.

**Explicit acceptance gate:** Mean execution time must be < 500ms on an iPhone 12 or newer running iOS 17+. The SDET should record the measured mean from the first baseline run in the test results report.

### 6.3 Test Scenarios

| Scenario | Rationale | Pass Criterion |
|----------|-----------|----------------|
| Twins + 4-digit string + concept match | Representative common case | < 500ms mean |
| Trips + concept nil + Y Motion present | Tests motion-adjusted diagram layout | < 500ms mean |
| Twins + Y Wheel enabled | Tests Y Wheel draw path in off-screen context | < 500ms mean |
| Output is a valid PDF with 4 cards | Correctness — distinct from latency | PDF opens; 4 identical cards visible |

Y Wheel scenario is important because `yWheelArcPath()` does Bézier sampling; in an off-screen context this is CPU-only, making it the worst-case geometry computation.

### 6.4 Memory Assertions

Memory assertions in XCTest are available via `XCTMemoryMetric` in `measureWithMetrics`:

```swift
func testPDFGenerationMemoryImpact() throws {
    let playCall = representativePlayCall

    measureWithMetrics([XCTMemoryMetric()]) {
        _ = WristbandPDFGenerator.generate(playCall: playCall)
    }
    // Baseline memory delta should be < 5MB per generate() call.
    // Set baseline after first run; regression gate fires automatically.
}
```

**Baseline expectation:** Peak memory delta per generate() call should be under 5MB. Based on Section 4 analysis, expected peak is under 2MB (bitmap buffer + PDF byte stream). The 5MB ceiling provides 2.5× headroom for overhead without being so loose it fails to catch a rasterize-at-3x bug.

### 6.5 Environment and Prerequisites

- **Device:** iPhone 12 or newer (minimum supported for this spec's latency target). Tests run on simulator are informative but not binding — simulator lacks Jetsam pressure and has different memory characteristics. SDET should run the performance baseline on a physical device once.
- **OS:** iOS 17+
- **Preconditions:** No other heavy processes running during measurement. Run in Release configuration (not Debug) for performance baselines — Swift debug overhead can add 2–5× latency.
- **Simulator note:** Use simulator for iteration and CI; use physical device for the acceptance gate run that records the official baseline.

### 6.6 Automation Gate

Add the performance tests to the existing test target. They run on every CI build. Xcode Performance baseline files (`.xcbaseline`) should be committed to the repository alongside the test file so CI has a reference point.

If CI is simulator-only (no physical device runner), document the simulator baseline separately and note it is not the acceptance gate measurement — the acceptance gate requires at least one physical device run by SDET before the epic can be declared complete.

---

## 7. Summary and Decision

Wristband export PDF generation is performance-sensitive by the spec's own stated 500ms hard gate. The critical path analysis predicts actual latency of 13–40ms on supported devices, providing substantial margin. Memory impact is bounded at under 2MB per export and requires no caching strategy.

A full load-test plan is not warranted — this is a one-shot interactive action on a personal coaching app with one user. The lightweight XCTest `measure {}` baseline (Section 6) is the appropriate verification method.

**Key implementation risks that could push latency toward or beyond 500ms:**

1. Rendering diagram at full-screen scale factor (3×) instead of card logical size — produces a 12 MB intermediate bitmap and potentially 100ms+ compression time.
2. Running PDF generation synchronously on the main thread without a background queue — this would not affect measured generation time but would cause the UI to freeze, making the latency experientially worse than the number suggests.
3. Rendering the diagram four times (once per card cell) instead of once — would multiply rendering cost by 4, potentially pushing toward 60–160ms even in the optimistic case.

All three risks are mitigated by following Section 5.

---

## Re-Assessment Triggers

This plan should be revisited if any of the following occur:

1. **V2 multi-play batch export ships.** Exporting 8+ plays requires rendering 8+ diagrams. Latency becomes O(N) and a background pre-render strategy becomes warranted. Trigger: batch export feature enters spec.

2. **Performance baseline fails CI.** If the XCTest baseline is exceeded by >20% on simulator CI, investigate before treating as a flake. Trigger: two consecutive CI failures on the performance test.

3. **Diagram rendering complexity grows significantly.** If DiagramRenderer gains animation, shader effects, or per-frame geometry, the off-screen rendering assumption changes. Trigger: any non-path/non-stroke draw operation added to RouteDiagramView.

4. **App adopts background processing entitlement.** If the app gains background refresh, PDF pre-generation in the background becomes feasible and desirable. Trigger: background entitlement added to project.

---

**Performance Engineer sign-off:** Assessment and test plan complete.
**Planning gate status:** READY — this file satisfies the performance gate requirement for Epic 3.1.
**Next step for orchestrator:** Confirm both `wristband-export-performance-assessment.md` and `wristband-export-test-strategy.md` exist in `docs/test-plans/` before proceeding to writing-plans (Step 5).
