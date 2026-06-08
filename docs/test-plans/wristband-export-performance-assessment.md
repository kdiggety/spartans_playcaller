# Performance Assessment: Epic 3.1 — Play Library, Play Catalog & Wristband Export

**Date:** 2026-06-07 (revised — full scope update)
**Status:** PERFORMANCE PLAN REQUIRED (lightweight — see Section 7)
**Feature:** Play library JSON persistence + multi-play PDF export via PDFKit (catalog 9-up and wristband 4-up)
**Replaces:** Original single-play wristband-only assessment
**Engineer:** Performance Engineer

---

## Revision Summary

The original assessment covered a single-play wristband export. The epic scope now covers three stories:

- **Story 3.0 — Play Library:** JSON persistence to the Documents directory; load at app launch; save after each write.
- **Story 3.1 — Play Catalog Export:** 9-up 3×3 landscape PDF; up to 9 diagrams rendered per page (vector path); multi-page for large libraries.
- **Story 3.2 — Wristband Export:** 4-up per play; one portrait page per selected play; multi-play creates N pages.

Each story introduces distinct cost centers analyzed separately below. The original rendering model (vector CGContext path via `PDFPage` subclass — "Option B") is preserved and extended.

---

## 1. Performance Relevance

All three stories touch code paths with measurable, user-visible latency.

**Story 3.0 (Library):** `PlayLibraryStore.load()` runs at app launch on every startup, making it the only export-related path that can degrade cold-start time. `PlayLibraryStore.persist()` runs after every save and delete, making it the only export path with cumulative per-action overhead.

**Story 3.1 (Catalog):** Renders up to 9 diagrams per page and N pages per export. For a 27-play export (3 pages, 27 diagrams) the rendering work is 27× the original single-diagram baseline. The 500ms target in the spec applies per-page for the catalog mode — see Section 5.

**Story 3.2 (Wristband):** Each page renders 4 copies of the same diagram. For an N-play export, the total rendering budget is N × (single-diagram cost). The spec's 500ms target applies per page.

**ExportCard construction (both export stories):** Re-parsing each `SavedPlay` via `RouteInterpreter` adds a cost center not present in the original assessment. For large selections this cost accumulates before PDF generation begins.

All four cost centers are small individually. Their interaction — specifically the ExportCard construction phase plus catalog rendering for large selections — is the only scenario that could approach or exceed the 500ms per-page spec target. That scenario warrants quantification.

**Verdict:** A lightweight test plan is required, scoped to four XCTest `measure {}` scenarios. Full load testing and multi-user throughput profiling are not warranted — this is a one-shot coaching action on a personal iOS app with one user. The test plan (Section 7) is the appropriate verification method.

---

## 2. Library Persistence Performance (Story 3.0)

### 2.1 `PlayLibraryStore.load()` — app launch path

`load()` is called synchronously during `PlayLibraryStore.init()`. The architecture spec places `PlayLibraryStore` as an `@EnvironmentObject` created at the `@main` App struct level. If `init()` blocks the main actor, it adds directly to cold-start time.

**What the work is:** JSON decode of a flat `[SavedPlay]` array from disk. Each `SavedPlay` is a struct with 7 fields (UUID, Date, three Strings, one optional String, one Bool). JSON is decoded by `JSONDecoder` into Swift value types with no custom init logic.

**File size estimate:**

| Library size | JSON size estimate | Notes |
|---|---|---|
| 50 plays | ~15–25 KB | ~300–500 bytes per `SavedPlay` entry with UUID + ISO8601 date + strings |
| 200 plays | ~60–100 KB | Upper bound for a coach who saves every play they ever build |

**Disk read cost:** NVMe flash on iPhone 12+ can read sequential blocks at well over 1 GB/s. Reading 100 KB is effectively free from an I/O perspective — under 0.1ms in all realistic cases.

**JSON decode cost:** `JSONDecoder` on an A14 or newer CPU processes approximately 50–200 MB/s of JSON input. For 100 KB of JSON (200 plays), the decode cost is under 2ms. For 25 KB (50 plays), it is under 0.5ms.

**Estimated total `load()` cost:**

| Library size | Estimated latency |
|---|---|
| 50 plays | < 1ms |
| 200 plays | < 3ms |
| 500 plays (extreme outlier) | < 8ms |

These are negligible relative to app cold-start time (typically 500ms–2s for a SwiftUI app on first launch). Library load will not be a measurable contributor to launch latency at any realistic library size.

**Thread model assessment:** The architecture spec shows `PlayLibraryStore` is `@MainActor` with `load()` called in `init()`. For the file sizes and decode costs above, synchronous main-thread load is acceptable — the work is too fast to cause a frame drop or visible delay. If the library ever grows beyond 500 entries (unlikely for a football playbook), this should be revisited. **No change required for V1.**

**Recommendation: Keep synchronous `load()` as designed.** Async load would add complexity (loading state, empty-library flash before data appears) for no user-perceptible benefit at realistic library sizes.

### 2.2 `PlayLibraryStore.persist()` — write path (per save/delete)

`persist()` is called after every `save` and `delete`. It JSON-encodes the full `plays` array and writes to disk.

**What the work is:** `JSONEncoder` encoding of `[SavedPlay]` + `Data.write(to:options:)` with `.completeFileProtection`. File protection adds a key derivation step before the kernel write, but on A14+ chips this is hardware-accelerated and adds under 1ms.

**Cost estimate:**

| Library size | Encode cost | Write cost | Total per-save overhead |
|---|---|---|---|
| 50 plays | < 0.5ms | < 1ms | < 2ms |
| 200 plays | < 2ms | < 1ms | < 3ms |

At these latencies, synchronous write on the main actor is acceptable. The coach taps "Save Play" and receives a brief visual confirmation — the 2–3ms write completes well within the confirmation animation frame, so the write is invisible.

**Is async write warranted?** The architecture spec suggests in-memory cache with background persist. For V1, this is over-engineering: the write cost is under the threshold where users can perceive it. The pattern "update `plays` in-memory immediately, write in background" adds concurrency complexity (read-after-write ordering, failure handling) with no observable user benefit.

**Recommendation: Synchronous write is acceptable for V1.** The `@MainActor` isolation already serializes all writes, preventing concurrent access bugs. If future profiling shows `persist()` contributing measurable latency (unlikely unless library grows above 500 entries), move to async write at that point. Do not add async complexity speculatively.

**Caching note:** Since `PlayLibraryStore.plays` is an `@Published` `[SavedPlay]` array held in memory, the "in-memory cache" is the store itself. SwiftUI reads `plays` from memory; disk is only consulted at launch. The architecture already has the right shape without an additional cache layer.

### 2.3 Library performance target

Spec success metric 11 states: library read/write < 50ms for up to 200 plays.

Based on the analysis above, expected performance is:
- **Load (200 plays): < 3ms** — 16× below the 50ms target.
- **Write per save (200 plays): < 3ms** — 16× below the 50ms target.

The 50ms target is appropriately conservative and will be satisfied without any special optimization.

---

## 3. ExportCard Construction Overhead

Before either generator runs, each `SavedPlay` must be converted to an `ExportCard` via `RouteInterpreter.interpret()`. This path is the second cost center added by the expanded scope.

### 3.1 What the work is

For each selected play:
1. Recover `Formation` from `rawValue` string — O(1) enum lookup.
2. `PlayCallParser.parse(digits:formation:)` — iterates over 4 or 5 characters, performs enum lookups and struct construction. Pure arithmetic; zero I/O; zero heap allocation beyond the `[RouteAssignment]` result (5 elements maximum).
3. `ConceptMatcher.identify(assignments:formation:)` — pattern-matching against a concept library. This is the heaviest sub-step: it iterates over concept definitions and compares route number sequences.
4. Motion re-application if `motionLabel` is non-nil — calls geometry methods on `DiagramRenderer` that do simple arithmetic.

**Estimated cost per play:** The source code confirms `PlayCallParser.parse()` is O(N) on a 4–5 character string — effectively O(1). `ConceptMatcher.identify()` complexity is proportional to the number of defined concepts and the length of each concept's route pattern. Without access to `ConceptLibrary.swift` internals, conservatively estimate 0.5–3ms per play (the wide range reflects uncertainty about the concept library size).

**Combined estimate (parse + concept match + motion reconstruction):** 1–5ms per play.

| Selection size | ExportCard construction total |
|---|---|
| 9 plays (1 catalog page) | 9–45ms |
| 27 plays (3 catalog pages) | 27–135ms |
| 50 plays (large selection) | 50–250ms |

### 3.2 Parallelism opportunity

`RouteInterpreter` is a pure function (no shared mutable state, reads only immutable concept definitions). Each `ExportCard.from(savedPlay:...)` call is independent. The architecture spec specifies that the entire export pipeline (card construction + generation) runs in a detached background `Task` — this keeps the main thread free but does not parallelize the card construction itself.

For V1, sequential construction is fine: even at the pessimistic 250ms for 50 plays, this occurs entirely on a background task with a spinner visible. The spec targets for catalog are "< 1s for 1–3 pages" and "< 3s for large libraries," which leaves room for sequential construction at 50 plays.

If construction overhead exceeds 500ms in practice (observable on older supported devices like iPhone 12 at thermal throttle), the fix is `withTaskGroup` to fan out card construction in parallel — but that optimization should be driven by a measured baseline, not speculation.

**Recommendation: Sequential ExportCard construction in V1.** Add a comment in the implementation marking the parallelization point if needed in V2.

---

## 4. Catalog Generation at Scale (Story 3.1)

### 4.1 Single diagram render — carried forward from original assessment

The original assessment established the rendering cost for one diagram at card scale using vector CGContext paths (Option B):

| Step | Expected range |
|---|---|
| Geometry computation (receiver positions, route paths, Bezier arc if Y motion) | 1–2ms |
| CGContext draw calls (paths, strokes, fills, text for one card) | 3–8ms |
| PDFKit page finalization overhead per page | 2–5ms |
| **Total per diagram** | **6–15ms** |

The Y Wheel arc adds one Bezier path via `motionPath()` which samples 21 points (`stride(from: 0, through: 1, by: 0.05)`). This is trivial arithmetic — under 0.1ms additional cost. The original "worst-case geometry" designation for Y Wheel remains valid but the absolute cost is negligible.

### 4.2 9-up catalog: 9 diagrams per page

The catalog `CatalogPDFPage` renders 9 cards in a single `draw(with:to:context:)` call. Each card's diagram is drawn via `DiagramRenderer.draw(into:playCall:config:in:)`. The 9 draws are sequential within a single CGContext pass.

**Rendering cost for one catalog page (9 plays):**

| Scenario | Diagram rendering | PDF page finalization | ExportCard construction | Page total |
|---|---|---|---|---|
| Optimistic (9 simple plays, no Y motion) | 9 × 6ms = 54ms | 5ms | 9ms | **~68ms** |
| Expected (9 plays, mixed motion) | 9 × 10ms = 90ms | 8ms | 22ms | **~120ms** |
| Pessimistic (9 complex plays, all Y Wheel) | 9 × 15ms = 135ms | 12ms | 45ms | **~192ms** |

All three scenarios are under the 500ms per-page target. The 500ms target provides 2.6× margin even under pessimistic assumptions for a single page. **The 9-up catalog layout is within budget.**

Note: ExportCard construction for 9 plays is included in the "page total" above assuming the construction happens before the generator runs. The construction for a 9-play single-page export is only ~9–45ms total.

### 4.3 Multi-page catalog: 20-play and 27-play exports

For a 20-play export: `ceil(20/9) = 3 pages` (9 plays on pages 1 and 2; 2 plays on page 3).

**Total ExportCard construction (20 plays, sequential):** 20–100ms.

**Total PDF generation (3 pages):**
- Pages 1 and 2: 9 plays each — 54–135ms per page.
- Page 3: 2 plays — 12–30ms.
- Total PDF generation: 120–300ms.

**End-to-end for 20-play export:** 140–400ms on a modern device. This is within the "< 1s, show spinner" range for 1–3 pages defined in Section 5.

For a 27-play export (3 full pages, 27 plays):
- ExportCard construction: 27–135ms.
- PDF generation: 3 × (54–135ms) = 162–405ms.
- **End-to-end: 189–540ms** — the pessimistic upper bound touches 540ms, which is over 500ms but within the "< 1s, show spinner" window. No optimization is required; the spinner provides the necessary UX feedback.

### 4.4 Are diagrams rendered sequentially or in parallel?

Within a single `PDFPage.draw(with:to:context:)` call, all card rendering is sequential — PDFKit provides one `CGContext` and calls `draw()` once per page. Parallelizing within a single page is not feasible without creating multiple sub-contexts and compositing them, which would add complexity with no measurable benefit at 9 diagrams.

**Across pages,** each `PDFPage` subclass instance is added to the `PDFDocument` before `dataRepresentation()` is called. PDFKit renders pages lazily during serialization — it is not parallelizable through the public API.

**Verdict: Sequential rendering is the correct architecture for V1.** Parallelism at the page level is not possible via PDFKit's public API. Parallelism within a page is not warranted. The background `Task.detached` dispatch is the correct concurrency boundary.

---

## 5. Memory Analysis

### 5.1 Catalog mode — vector (no bitmaps)

The architecture decision (Option B — vector PDFPage subclasses) means there are no intermediate bitmap allocations. The `CatalogPDFPage.draw(with:to:context:)` method issues `CGContext` path draws directly — no `UIGraphicsImageRenderer`, no `UIImage`, no CGImage.

**Memory cost per catalog page:** The `CGContext` provided by PDFKit is managed by PDFKit itself. The draw calls add path data (a series of `CGPoint` values) to the context. For 9 diagrams with approximately 20 path points each (receiver positions, route breaks, motion arcs):
- Path data: 9 cards × ~20 points × 16 bytes per CGPoint ≈ 2.9 KB. Negligible.
- Per-page `CatalogPDFPage` object: stores up to 9 `ExportCard` structs. Each `ExportCard` holds a `PlayCall` plus String fields — approximately 1–2 KB per card. Total per page: ~10–18 KB.
- `PDFDocument` in-memory representation before serialization: accumulates `PDFPage` references, not rendered pixel data. Memory grows O(N) in the number of pages, not O(pixels).

**Peak memory for a 50-play catalog export (6 pages):**
- 6 `CatalogPDFPage` objects with 9 `ExportCard` structs each: ~60–108 KB of struct data.
- `PDFDocument.dataRepresentation()` allocates the serialized byte stream: a 50-play catalog will have ~50–200 KB of PDF output (vector paths compress well). Peak allocation during serialization is approximately equal to the output size.
- **Total peak memory: under 1 MB.** This is negligible on any supported device.

### 5.2 Wristband mode — vector (no bitmaps)

Same analysis applies. Each wristband page draws 4 copies of one diagram. No bitmaps are allocated. Memory per page is dominated by the `WristbandPDFPage` object holding one `ExportCard` (drawn four times).

**Peak memory for a 10-play wristband export (10 pages):**
- 10 `WristbandPDFPage` objects: ~10–20 KB of struct data.
- Serialized PDF output: ~100–400 KB (wristband cards have more text fields per page than catalog).
- **Total peak memory: well under 1 MB.**

### 5.3 Bitmap risk

The original assessment identified "rendering diagram at full-screen scale factor (3×)" as the primary memory risk — producing 12 MB intermediate bitmaps. This risk is eliminated by the vector rendering decision (Option B). No `UIGraphicsImageRenderer` is used in the PDF pipeline. The risk is now moot and does not need mitigation.

**Verdict: No caching, no pooling, no memory limit required.** The vector approach eliminates the memory problem at its source. Peak additional memory for any export scenario covered by this epic is under 2 MB.

---

## 6. Updated Latency Targets

The original assessment had a single target (< 500ms for one play). The expanded scope requires a tiered structure that accounts for multi-page generation time and UX expectations for a deliberate "generate my game plan" action.

| Scenario | Selection range | Expected latency | UX response | Notes |
|---|---|---|---|---|
| Quick export (1 play, either mode) | 1 play | 15–60ms | No spinner; appears instant | Share sheet opens before conscious wait |
| Small catalog (1 page) | 1–9 plays | 70–200ms | No spinner required; brief overlay acceptable | Within "invisible" threshold |
| Medium catalog or short wristband | 10–18 plays (catalog: 2 pages; wristband: 10–18 pages) | 200ms–1s | Spinner required | Coach sees feedback; no freeze impression |
| Large catalog (3 pages) | 19–27 plays | 200ms–1s | Spinner required | 3 full pages; pessimistic end near 600ms; spinner covers the gap |
| Very large selection | 27+ plays | 1–3s | Spinner with "Generating…" label | Coach made a deliberate all-plays export; wait is expected |
| Library load at launch | 50–200 plays | < 3ms | Silent | Below perception threshold; no indicator needed |
| Library write per save | Any library size | < 3ms | Visual confirmation animation | Write completes within animation frame |

**Hard gates (from spec success metric 11):**
- Catalog PDF generation: < 500ms for 9 plays on iPhone 13.
- Wristband PDF generation: < 500ms per page on iPhone 13.
- Library read/write: < 50ms for up to 200 plays.

All hard gates are expected to be met with margin. The < 500ms per-page gate applies to single-page generation — the wristband page-per-play model means each 4-up page must complete in under 500ms individually, which the analysis confirms (15–60ms per page typical).

**What is NOT a hard gate:** Total end-to-end time for a 27-play export. The spec does not define a total-export ceiling beyond "< 3s for large libraries." An observable 1–2 second wait with a spinner is acceptable and expected for a deliberate game-plan export action.

---

## 7. Test Plan

### 7.1 Objective

Verify that:
1. `CatalogPDFGenerator.generate(cards:)` meets the 500ms per-page target for a full 9-play page.
2. Multi-page catalog generation for 27 plays completes within the 1s spinner threshold.
3. `WristbandPDFGenerator.generate(cards:)` meets the 500ms per-page target for a 10-play selection.
4. `PlayLibraryStore.load()` completes in under 50ms for a 50-play library.

### 7.2 Test Method

XCTest `measure {}` block (10 iterations; reports mean and standard deviation). Appropriate for one-shot operations with low variability. Four scenarios are required.

**Test file:** `SpartansPlaycallerTests/Services/ExportPerformanceTests.swift`

All scenarios use representative, realistic `SavedPlay` and `ExportCard` data — not minimal stubs. The play set should include mixed formations (Twins, Trips Right, Pro Left), a mix of concept matches and no-concept plays, and at least one play with Y motion and one with Y Wheel enabled.

### 7.3 Scenario 1: Catalog — 9-play single page

Measures `CatalogPDFGenerator.generate(cards:)` with exactly 9 `ExportCard` values. This directly tests the spec's stated hard gate (< 500ms for 9 plays on iPhone 13).

```swift
func testCatalogGeneration_9Plays_SinglePage() throws {
    let cards = ExportCardFixtures.ninePlayMixed  // 9 mixed ExportCard values with pre-constructed PlayCall
    var result: Data?

    measure {
        result = CatalogPDFGenerator.generate(cards: cards)
    }

    let data = try XCTUnwrap(result, "Generator must return non-nil Data")
    XCTAssertGreaterThan(data.count, 1024)
    XCTAssertTrue(data.starts(with: [0x25, 0x50, 0x44, 0x46])) // %PDF
    // Verify exactly 1 page
    let doc = try XCTUnwrap(PDFDocument(data: data))
    XCTAssertEqual(doc.pageCount, 1)
}
// Acceptance gate: mean < 500ms on physical device (iPhone 12 or newer, Release config)
```

### 7.4 Scenario 2: Catalog — 27-play three-page export

Measures `CatalogPDFGenerator.generate(cards:)` with 27 `ExportCard` values (3 full 9-up pages). Tests total generation time for the "3 pages" threshold in the latency target table.

```swift
func testCatalogGeneration_27Plays_ThreePages() throws {
    let cards = ExportCardFixtures.twentySevenPlayMixed
    var result: Data?

    measure {
        result = CatalogPDFGenerator.generate(cards: cards)
    }

    let data = try XCTUnwrap(result)
    let doc = try XCTUnwrap(PDFDocument(data: data))
    XCTAssertEqual(doc.pageCount, 3)
}
// Acceptance gate: mean < 1500ms on physical device (3x the single-page target; spinner is shown)
// A mean above 3000ms is a performance regression requiring investigation.
```

### 7.5 Scenario 3: Wristband — 10-play, 10-page export

Measures `WristbandPDFGenerator.generate(cards:)` for 10 plays (10 pages). The per-page target is < 500ms, so 10 pages should complete in under 5s total. In practice, vector rendering overhead scales linearly, so 10 pages at 15–60ms per page = 150–600ms total.

```swift
func testWristbandGeneration_10Plays_10Pages() throws {
    let cards = ExportCardFixtures.tenPlayMixed
    var result: Data?

    measure {
        result = WristbandPDFGenerator.generate(cards: cards)
    }

    let data = try XCTUnwrap(result)
    let doc = try XCTUnwrap(PDFDocument(data: data))
    XCTAssertEqual(doc.pageCount, 10)
}
// Acceptance gate: mean < 1000ms on physical device (10 pages × 100ms pessimistic per page)
// Per-page mean is implicitly < 100ms if total mean is < 1000ms.
```

### 7.6 Scenario 4: Library load — 50-play cold start

Measures `PlayLibraryStore.load()` with a pre-populated `play-library.json` file containing 50 `SavedPlay` entries written to a temporary location. Tests the app-launch-path performance target.

```swift
func testLibraryLoad_50Plays() throws {
    // Pre-generate a 50-play JSON fixture and write to a temp path before measure block
    let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("perf-test-library.json")
    let testPlays = SavedPlayFixtures.fiftyPlays
    let data = try JSONEncoder().encode(testPlays)
    try data.write(to: tempURL)

    measure {
        guard let loadedData = try? Data(contentsOf: tempURL),
              let _ = try? JSONDecoder().decode([SavedPlay].self, from: loadedData)
        else { XCTFail("Load failed"); return }
    }

    try? FileManager.default.removeItem(at: tempURL)
}
// Acceptance gate: mean < 50ms on physical device (spec target)
// Expected mean: < 3ms. A mean above 10ms indicates something unexpected.
```

### 7.7 Test fixtures: ExportCardFixtures

The test target needs a `ExportCardFixtures` helper that constructs representative `ExportCard` values with pre-built `PlayCall` objects (bypassing `RouteInterpreter` to isolate PDF generation cost from card construction cost). The library load test uses a separate `SavedPlayFixtures` helper that generates realistic `SavedPlay` JSON without touching the PDF pipeline.

To measure ExportCard construction overhead independently (not required for acceptance gate, but useful for regression detection):

```swift
func testExportCardConstruction_9Plays() throws {
    let plays = SavedPlayFixtures.ninePlays
    let interpreter = RouteInterpreter()

    measure {
        let cards = plays.compactMap { savedPlay in
            ExportCard.from(savedPlay: savedPlay, playNumber: 1, interpreter: interpreter)
        }
        XCTAssertEqual(cards.count, 9)
    }
}
// Informational baseline: expected mean < 50ms. No hard gate — this
// feeds into the overall export latency, not a user-facing action on its own.
```

### 7.8 Baseline procedure

1. Run each `measure {}` test once in Debug configuration to confirm no crashes. The Debug numbers are informational only.
2. Switch to Release configuration (`Product → Scheme → Edit Scheme → Run → Build Configuration: Release`).
3. Run on a physical iPhone 12 or newer. Confirm no other apps are running heavy foreground processes.
4. After the first successful run set the Xcode performance baseline via `Edit → Performance Test Baselines → Save As Baseline`.
5. Commit the `.xcbaseline` files to the repository alongside the test file.
6. CI runs on simulator — simulator baselines are informational but not the acceptance gate. The acceptance gate requires a physical device run by SDET before the epic is declared complete.

### 7.9 Memory assertions

The vector rendering decision eliminates the primary memory risk from the original assessment. Memory assertions are added for regression detection, not because the current design is expected to be problematic.

```swift
func testCatalogGeneration_9Plays_MemoryImpact() throws {
    let cards = ExportCardFixtures.ninePlayMixed

    measureWithMetrics([XCTMemoryMetric()]) {
        _ = CatalogPDFGenerator.generate(cards: cards)
    }
    // Baseline expectation: peak memory delta < 5MB per generate() call.
    // Expected: < 1MB given vector-only rendering.
}
```

### 7.10 Pass/fail criteria

| Test | Hard gate | Trigger for investigation |
|---|---|---|
| Catalog 9-play | Mean < 500ms on device | Mean > 400ms (approaching gate with < 25% margin) |
| Catalog 27-play | Mean < 1500ms on device | Mean > 1200ms |
| Wristband 10-play | Mean < 1000ms on device | Mean > 800ms |
| Library load 50-play | Mean < 50ms on device | Mean > 20ms |
| Memory (catalog 9-play) | Peak delta < 5MB | Any delta > 2MB (suggests bitmap allocation leaked in) |

---

## 8. Implementation Guidance (updated)

### 8.1 Thread model — unchanged

Both generators must be called from a background `Task.detached(priority: .userInitiated)`. The entire export pipeline — ExportCard construction and PDF generation — belongs in the background task, not just the generator call.

```swift
func exportPlays(_ selectedPlays: [SavedPlay], mode: ExportMode) async throws -> Data {
    return try await Task.detached(priority: .userInitiated) {
        // Step 1: Construct ExportCards (RouteInterpreter is safe off-main — pure function)
        let interpreter = RouteInterpreter()
        let cards = selectedPlays.enumerated().compactMap { (i, play) in
            ExportCard.from(savedPlay: play, playNumber: i + 1, interpreter: interpreter)
        }
        guard !cards.isEmpty else { throw ExportError.noValidCards }

        // Step 2: Generate PDF
        switch mode {
        case .catalog:
            guard let data = CatalogPDFGenerator.generate(cards: cards) else {
                throw ExportError.generationFailed
            }
            return data
        case .wristband:
            guard let data = WristbandPDFGenerator.generate(cards: cards) else {
                throw ExportError.generationFailed
            }
            return data
        }
    }.value
}
```

### 8.2 Spinner visibility threshold

Based on the latency targets in Section 6:

- Show the spinner **immediately on format confirmation** (before the background task dispatches). Even for a 9-play export that completes in 70–200ms, showing the spinner is the correct behavior — it confirms the coach's tap registered and prevents double-tapping.
- Use an indeterminate `ProgressView`. No percentage indicator is needed: the operation is sub-second for realistic game-plan sizes and the user does not benefit from "47% complete."
- Dismiss the spinner when the background task returns to the main actor, before presenting `UIActivityViewController`.

### 8.3 ExportCard construction failure handling

If any `SavedPlay` fails to produce an `ExportCard` (e.g., a formation rawValue that no longer maps to a known `Formation` enum case after a future code change), the `compactMap` in 8.1 silently drops that card. Log the failure. If cards drop occurs, the export should proceed with the remaining cards rather than failing the entire operation — and a brief non-blocking notice ("1 play could not be loaded and was skipped") should appear.

### 8.4 Library `persist()` — write location note

`persist()` must use `.completeFileProtection` on the write option (REQ-SEC-5 from architecture spec). This is enforced by the security requirements and does not meaningfully affect write latency on A14+ hardware.

### 8.5 Do not pre-generate PDFs speculatively

No PDF pre-generation when the coach enters the library view or selects plays. Speculative generation wastes CPU, battery, and memory for exports the coach may cancel or not trigger at all. Generate only after the coach confirms format selection. This was stated in the original assessment and remains correct with the expanded scope.

---

## 9. Risks Carried Forward and Updated

### Risk 1 (updated): Bitmap leak — LOW probability, HIGH impact

The vector rendering path (Option B) eliminates all planned bitmap allocations. However, if a future code change adds `UIGraphicsImageRenderer` or `UIImage` anywhere in the `draw(with:to:context:)` path (e.g., to embed a team logo or rasterize a font), the memory and compression cost grows significantly. The XCTMemoryMetric assertion in Section 7.9 is the detection mechanism — a baseline > 2MB per generate() call signals a bitmap allocation has been introduced.

**Mitigation:** The memory test baseline is the canary. Any delta > 2MB triggers investigation before merge.

### Risk 2 (new): ExportCard construction failure for corrupted library entries

If `SavedPlay.formationName` contains a rawValue that no longer maps to a `Formation` case, `ExportCard.from(savedPlay:...)` returns nil. For a 9-play export where 2 plays fail construction, the coach receives a 7-play catalog without clear feedback on what was dropped.

**Mitigation:** Log each construction failure with the `SavedPlay.id` and `formationName` that failed. Surface a count to the coach ("2 plays skipped — library may need cleanup"). This is a correctness concern more than a performance concern, but it appears here because silent nil-compactMap is the pattern the architecture specifies and its failure mode needs documentation.

### Risk 3 (carried forward, updated): Large library export latency above comfort threshold

For 50 selected plays (extreme outlier — a coach selecting their entire multi-week library for one game-day export), pessimistic ExportCard construction is 250ms and PDF generation for 6 catalog pages is 405ms — a total of ~655ms. With a spinner and "Generating…" label visible, this is acceptable.

**Mitigation:** The background task dispatch and spinner cover this case. If real-world measurement exceeds 3s for a 50-play export, parallelize ExportCard construction with `withTaskGroup` as a follow-on optimization. Measure before optimizing.

### Risk 4 (new): `PlayLibraryStore.load()` on the main actor without guard

If a future refactor moves library load to a path that runs after `WindowGroup` layout is computed — for example, deferring it to first app activation rather than init — the latency profile changes. The current synchronous-in-init pattern is safe at expected file sizes. If the app gains iCloud sync (out-of-scope V1), this must be revisited.

**Re-assessment trigger:** Any change that moves `load()` off the synchronous init path, or any addition of network I/O to the load path.

---

## 10. Re-Assessment Triggers

This document should be revisited if any of the following occur:

1. **Typical game-plan selection exceeds 30 plays.** If coaches routinely export 30+ plays per game, the "very large selection" latency tier becomes the common case, and parallelizing ExportCard construction becomes warranted. Trigger: usage observation or coach feedback indicating wait times feel excessive.

2. **Performance baseline fails CI by > 20% for two consecutive runs.** Treat as a real regression, not a flake. Trigger: two consecutive CI failures on any performance test scenario.

3. **Bitmap allocation appears in the export pipeline.** If XCTMemoryMetric baseline exceeds 2MB per generate() call. Trigger: memory test baseline failure.

4. **DiagramRenderer gains non-path draw operations.** Shaders, CALayer compositing, or async draw would change the CGContext cost model significantly. Trigger: any non-path, non-stroke, non-fill operation added to `DiagramRenderer`.

5. **App gains background processing entitlement.** Pre-generation during background refresh becomes feasible and desirable. Trigger: background entitlement added to project entitlements file.

6. **Library file grows above 500 entries.** At that scale, synchronous main-actor load may contribute observable cold-start delay. Trigger: library entry count metric (if instrumented) consistently above 500 in production.

7. **Play reordering (V2) ships.** Drag-reorder implies frequent sequential `persist()` calls as the coach drags. A debounced or coalesced write strategy may be warranted. Trigger: play reordering feature enters spec.

---

## Summary and Decision

All three stories are performance-sensitive within specific, bounded scenarios. The critical path analysis predicts all hard gates (< 500ms per catalog page for 9 plays; < 500ms per wristband page; < 50ms library I/O) will be satisfied with comfortable margin under expected usage conditions. The vector rendering architecture eliminates the largest memory risk from the original assessment.

**Key findings:**

- Library load and persist are both < 3ms at 200 plays — 16× inside the 50ms spec target. No threading change required.
- ExportCard construction adds 1–5ms per play — well within budget at realistic game-plan sizes (9–27 plays).
- Single catalog page (9 plays): expected 70–200ms — comfortably inside the 500ms gate.
- Three-page catalog (27 plays): expected 200ms–600ms — inside the 1s spinner window.
- 10-play wristband (10 pages): expected 150–600ms — inside the 1s spinner window per total export, trivially inside the 500ms per-page gate.
- Memory: under 2MB for all scenarios due to vector-only rendering.

**Implementation risks that could push performance outside targets:**

1. Running ExportCard construction or PDF generation on the main actor — causes visible freeze regardless of raw latency. Mitigated by background `Task.detached` dispatch.
2. Bitmap allocation introduced in `draw(with:to:context:)` — increases memory by 10–50× and compression cost by 5–20×. Detected by XCTMemoryMetric baseline.
3. Calling `RouteInterpreter` on the main actor for large selections — keeps main actor blocked during card construction. Mitigated by dispatching the full pipeline (construction + generation) to the background task.

All three risks are mitigated by following Section 8.

**Planning gate status:** READY — this file satisfies the performance gate requirement for the revised Epic 3.1 scope (Stories 3.0, 3.1, and 3.2).

**Next step for orchestrator:** Confirm both `wristband-export-performance-assessment.md` (this file, revised) and the SDET test strategy file exist in `docs/test-plans/` before proceeding to writing-plans (Step 5).
