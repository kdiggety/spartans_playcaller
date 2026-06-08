# Play Library, Catalog & Wristband Export — Test Strategy

**Epic:** 3.1 (revised) — Play Library, Play Catalog & Wristband Export
**Date:** 2026-06-07 (updated — full scope revision)
**Author:** SDET
**Status:** PLANNING GATE ARTIFACT — required before implementation plan may be written
**Spec reference:** `docs/superpowers/specs/2026-06-07-wristband-export-spec.md`
**Design reference:** `docs/superpowers/specs/2026-06-07-wristband-export-design.md`
**Supersedes:** Original 2026-06-07 wristband-only test strategy (single-play scope)

**Revision note:** The original strategy covered single-play wristband export only (what the spec called Story 3.1 at the time). The epic now spans three stories — Story 3.0 (Play Library / Persistence), Story 3.1 (Play Catalog Export), and Story 3.2 (Wristband Export, updated to multi-play). This document replaces the prior strategy in full. All open questions from the prior strategy (OQ-1 through OQ-6) are resolved in the design spec.

---

## 1. Regression Scope

### 1.1 Risk Summary

This epic adds new model types, a persistence service, two PDF generators, new ViewModel methods, and new views. The primary regression risks are:

**Highest risk — DiagramRenderer extension for CGContext rendering (Story 3.1 and 3.2)**

The architecture spec (Option B) adds a new `draw(into:playCall:config:in:)` method to `DiagramRenderer` as an extension so that both `CatalogPDFPage` and `WristbandPDFPage` can produce vector diagram content. This is additive (no existing methods modified), but any implementation that touches `DiagramRenderer.swift` to add supporting internal state or refactor geometry helpers can silently break the 8 existing tests that directly exercise `DiagramRenderer` draw paths and arc geometry. This is the single highest regression surface in the epic.

**High risk — PlayCallerViewModel additions (Story 3.0 and 3.2)**

Three new items are added to `PlayCallerViewModel`: `canSave`, `saveCurrentPlay()`, and `canExport` / `exportCurrentPlay(mode:)` / `isExporting`. The existing 24 tests in `PlayCallerViewModelTests.swift` exercise the ViewModel's motion state management, reset behavior, and play parsing. Any new `@Published` properties or state mutations introduced for the save/export flow must not disturb the values those tests assert. Specific risks: (a) adding `isExporting` as a `@Published` property modifies the object's published property graph — if teardown does not cancel in-flight Tasks, async export state may bleed across tests; (b) `saveCurrentPlay()` calls `libraryStore.save()` — if `PlayLibraryStore` is not injected by reference (init parameter vs EnvironmentObject), tests that construct `PlayCallerViewModel()` without a store will crash rather than compile-fail.

**Medium risk — RouteInterpreter round-trip correctness (Story 3.0 and 3.1)**

`ExportCard.from(savedPlay:playNumber:interpreter:)` re-parses `routeDigits` + `formationName` to reconstruct a `PlayCall` at export time. If `RouteInterpreter.interpret()` is not fully deterministic for all digit strings and formations exercised in the library, reconstructed `PlayCall` values will diverge from what the coach saved — producing wrong diagrams on exported cards. The existing 25 `RouteInterpreterTests` do not cover the specific digit/formation combinations that will be stored in `SavedPlay` entries from real workflows. New integration tests must cover this round-trip path explicitly.

**Medium risk — applyMotion duplication (Story 3.0 design decision)**

The architecture spec recommends extracting `applyMotion` from `PlayCallerViewModel` into a static method on `PlayCall`. If the engineer does not do this extraction, two separate `applyMotion` implementations will exist. If their behavior diverges, cards will render post-motion positions that differ from the on-screen diagram. The test for `ExportCard` construction must assert the reconstructed diagram matches what the ViewModel would produce for the same `SavedPlay` data.

**Low risk — PlayLibraryStore file I/O (Story 3.0)**

Library persistence writes a JSON file to the Documents directory with `.completeFileProtection`. Any test that instantiates `PlayLibraryStore` without overriding `fileURL` will write real files to the test process's Documents directory and may leave artifacts across test runs. The store must accept a dependency-injected file URL (or a test-configured instance) to allow sandbox isolation in tests.

### 1.2 Existing Test Files That Must Remain Green

All 18 test files below are in `SpartansPlaycallerTests/`. None may regress.

| File | DiagramRenderer risk | ViewModel risk | RouteInterpreter risk |
|------|----------------------|----------------|----------------------|
| `ConceptMatcherTests.swift` | Low | Low | Low |
| `DiagramRendererWheelRenderingTests.swift` | **HIGH** — directly exercises `motionPathForPlayCall` and arc draw paths | None | None |
| `DiagramRendererYWheelTests.swift` | **HIGH** — `yWheelArcPath()` geometry asserted | None | None |
| `PlayCallerViewModelTests.swift` | None | **HIGH** — all ViewModel state including reset, motion, parse | None |
| `PlayCallFlowYWheelTests.swift` | Medium | Medium | Low |
| `PlayCallWheelToggleFlowTests.swift` | Medium | Medium | Low |
| `ReceiverMotionTests.swift` | None | Low | None |
| `ReceiverMotionWheelTests.swift` | None | None | None |
| `ReceiverMotionWheelToggleTests.swift` | None | None | None |
| `RouteDiagramViewTests.swift` | Medium — instantiates View that uses DiagramRenderer | None | None |
| `RouteDiagramYWheelTests.swift` | Medium | None | None |
| `RouteInterpreterTests.swift` | None | None | **HIGH** — core parsing correctness |
| `RouteSemanticProviderTests.swift` | None | None | None |
| `Y_WheelComprehensiveTests.swift` | **HIGH** — broad Y Wheel path coverage including render paths | None | None |
| `Y_WheelDiagramIntegrationTests.swift` | **HIGH** — integration across renderer and view | None | None |
| `Y_WheelRobustnessTests.swift` | Medium | None | None |
| `YWheelArcDiagnosticTests.swift` | **HIGH** — arc geometry assertions on path points | None | None |
| `YWheelArcVisualSpecTests.swift` | **HIGH** — visual spec assertions on arc shape | None | None |

**Gate:** The full test suite (`xcodebuild test`) must pass before and after this epic lands. Software-engineer runs and reports results at implementation Step 6. SDET confirms again at Step 8.

### 1.3 New Regression Risks From PlayCallerViewModel Changes

The following new risks are introduced by ViewModel changes in this epic that did not exist in the prior strategy:

| New ViewModel surface | What it can break | Mitigation |
|----------------------|------------------|-----------|
| `canSave: Bool` computed property | If it reads `currentPlayCall` differently from how `canExport` reads it, a save in `PlayCallerView` will behave inconsistently with export. | Unit test both `canSave` and `canExport` against the same play states. |
| `saveCurrentPlay()` calling `libraryStore.save()` | If `libraryStore` is nil or not injected in test setup, tests that call `saveCurrentPlay()` will crash at runtime rather than failing cleanly. | Inject a mock `PlayLibraryStore` (or a test-configured real store using a temp file URL) in all new ViewModel tests. |
| `isExporting: @Published Bool` | Async export Task left in-flight at `tearDown()` can mutate `isExporting` after the test ends, causing false positives in subsequent tests. | Tests that trigger `exportCurrentPlay()` must await the Task's completion before asserting and must cancel on `tearDown()`. |
| `saveConfirmed: @Published Bool` | Transient state reset after 1.5s via `Task.sleep`. Tests must not assert on `saveConfirmed` without controlling time (or simulating the reset manually). | Test `saveCurrentPlay()` only for its library-side effects (entry added to store) and the immediate `saveConfirmed = true` state — not the reset after delay. |

### 1.4 No UITests Target

There is no `SpartansPlaycallerUITests/` directory. This epic does not introduce one. E2E automation is constrained to XCTest unit/integration tests within `SpartansPlaycallerTests/`. The share sheet limitation documented in the original strategy carries forward unchanged. See Section 3.3.

---

## 2. Test Pyramid (Updated for All Three Stories)

### 2.1 Pyramid Summary

```
                    E2E / UI Automation
                   (0% — share sheet not automatable;
                    manual smoke test replaces this layer)

              Integration Tests  (~35%)
         SavedPlay -> ExportCard pipeline (with live RouteInterpreter)
         Library persistence: write temp dir, reinit store, verify survival
         PDF data validity (PDFKit page count, media box, data non-nil)
         Catalog page count for N plays (1, 9, 10)
         Wristband page count for N plays (1, 3, N)
         Temp file write and cleanup (both generators)
         ViewModel export state (canExport, isExporting transitions)
         ViewModel save state (canSave, saveCurrentPlay side effects)
         Error path: PDF failure -> no crash

               Unit Tests  (~65%)
          SavedPlay Codable round-trip (encode -> decode, all fields, nil fields)
          PlayLibraryStore: save, load, delete, reinit
          PlayLibraryStore duplicate handling (two identical saves -> two entries)
          ExportCard field population: concept nil/non-nil, motion nil/non-nil
          ExportCard construction from SavedPlay (with stub interpreter)
          CatalogPDFGenerator page count: ceil(N/9) for N in {1, 9, 10, 18, 19}
          CatalogCardConfig geometry: cell dimensions, origins, gutter math
          WristbandPDFGenerator page count: N plays -> N pages (1, 3)
          WristbandCardConfig geometry: card dimensions, grid origins, margin math
          Y Motion label mapping: ReceiverMotion rawValue -> motionLabel stored
          Filename format: sanitized formation/digit string
```

The pyramid is unit-heavy because the three new core types (`SavedPlay`, `PlayLibraryStore`, `ExportCard`) are deterministic value-type operations (encode/decode, pure construction logic, arithmetic). Integration tests are needed where a live system boundary is crossed: the file system for persistence, the `RouteInterpreter` for card reconstruction, and `PDFKit` for document structure verification.

### 2.2 Story 3.0 Unit Test Coverage

**Target: `SavedPlay`, `PlayLibraryStore`**

#### SavedPlayCodableTests

These are pure encode/decode round-trip tests. No file system. No network.

| Test case | What it asserts |
|-----------|----------------|
| All fields populated | `SavedPlay` encodes to JSON and decodes back with identical values for all seven fields (`id`, `savedAt`, `formationName`, `routeDigits`, `conceptName`, `motionLabel`, `yWheelEnabled`). Decoded `id` == original `id`. |
| Optional fields nil | `conceptName` nil encodes and decodes as JSON null; decoded value is nil (never empty string). `motionLabel` nil same. |
| `yWheelEnabled` false | Encodes and decodes without defaulting to true. |
| `savedAt` precision | Date round-trips through JSON encoding with no loss of second-level precision (use ISO8601 encoder or default double-seconds encoder; assert decoded date within 1 second of original). |
| Array of SavedPlay | `[SavedPlay]` encodes and decodes; order is preserved; count is preserved. |
| Unknown future field (forward compat) | Decode a JSON string with an extra unknown key; assert it does not throw and all known fields decode correctly. (Tests `JSONDecoder` with `.ignoreUnknownKeys` or confirms synthesis behavior.) |

#### PlayLibraryStoreUnitTests

These tests inject a temp file URL to avoid writing to the real Documents directory.

| Test case | What it asserts |
|-----------|----------------|
| Empty on first init (no file) | When `fileURL` points to a nonexistent file, `plays` is empty after init. No error or crash. |
| Save appends entry | After `save(playCall:motion:yWheelEnabled:)`, `plays.count == 1`. Entry's `formationName` and `routeDigits` match the input. |
| Multiple saves | Three saves produce `plays.count == 3` in insertion order. |
| Duplicate save (same formation + digits) | Calling `save()` twice with the same inputs produces `plays.count == 2` — each has a distinct `id` and `savedAt`. No de-duplication. |
| Delete at offsets | After three saves, `delete(at: IndexSet(integer: 1))` produces `plays.count == 2`; the correct entry is removed. |
| Delete all | `deleteAll()` sets `plays` to empty; no error. |
| Persist and reinit | After `save()`, construct a new `PlayLibraryStore` instance with the same `fileURL`; assert `plays.count == 1` and the entry's fields match. This is the persistence-across-reinit test. |
| Corrupt file graceful recovery | Write a non-JSON string to `fileURL`; init the store; assert `plays == []` and no crash (decode failure handled gracefully). |
| File protection applied | After `save()`, assert `FileManager.default.attributesOfItem(atPath: fileURL.path)[.protectionKey]` equals `.completeFileProtection` (debug build only; may be skipped in simulator where file protection is not enforced — mark with conditional skip). |

### 2.3 Story 3.1 Unit Test Coverage

**Target: `CatalogPDFGenerator`, `CatalogCardConfig`**

#### CatalogPageCountTests

These are pure arithmetic tests. No file I/O, no PDF rendering.

| Test case | N plays | Expected page count |
|-----------|---------|-------------------|
| Minimum: single play | 1 | 1 |
| Exactly fills one page | 9 | 1 |
| One play overflows to page 2 | 10 | 2 |
| Exactly fills two pages | 18 | 2 |
| One play on third page | 19 | 3 |

The generator uses `ceil(N / 9)`. The test asserts this formula against the above values by examining the `PDFDocument.pageCount` of the generated output (or by testing a pure `pageCount(for:)` static helper if the generator exposes one).

#### CatalogCellGeometryTests

Validates the layout math from the architecture spec against explicit expected values.

| Assertion | Expected value | Derivation |
|-----------|---------------|-----------|
| Cell width | 234pt | (720 - 16) / 3 = 234.67 -> floor to 234 |
| Cell height | 174pt | (540 - 16) / 3 = 174.67 -> floor to 174 |
| Column stride | 242pt | 234 + 8 (gutter) |
| Row stride | 182pt | 174 + 8 (gutter) |
| Cell (0,0) origin | (36, 36) | top-left margin |
| Cell (0,1) origin | (278, 36) | 36 + 242 |
| Cell (0,2) origin | (520, 36) | 36 + 484 |
| Cell (1,0) origin | (36, 218) | 36 + 182 |
| Cell (2,2) origin | (520, 400) | 36 + 484 x, 36 + 364 y |

These assertions verify the `CatalogCardConfig` constants directly and serve as a regression guard against accidental edits to the config.

#### CatalogFilenameTests

| Test case | Input | Expected filename segment |
|-----------|-------|--------------------------|
| Single play | 1 card | `"1-plays-catalog"` (or formation+digits variant if single-play path uses that) |
| Multi play | 9 cards | `"9-plays-catalog"` |
| UUID prefix present | Any | Filename begins with a valid UUID string |

### 2.4 Story 3.2 Unit Test Coverage

**Target: `WristbandPDFGenerator`, `WristbandCardConfig`**

#### WristbandPageCountTests

| Test case | N plays | Expected page count |
|-----------|---------|-------------------|
| Single play | 1 | 1 |
| Three plays | 3 | 3 |
| N plays (parameterized) | N | N |

The wristband generator maps 1 `ExportCard` to 1 `PDFPage`. The formula is `N`. Test confirms this for N = 1 and N = 3.

#### WristbandCellGeometryTests

Validates the layout math from the architecture spec.

| Assertion | Expected value | Derivation |
|-----------|---------------|-----------|
| Card width | 252pt | 3.5" at 72pt/inch |
| Card height | 180pt | 2.5" at 72pt/inch |
| Page width | 612pt | 8.5" landscape — actually portrait for wristband: 612pt wide |
| Page height | 792pt | 11" portrait |
| Total card grid width | 549pt | 2×252 + 9 + 2×18 |
| Horizontal centering offset | 31.5pt | (612 - 549) / 2 |
| Card (0,0) origin | (49.5, 211.5) | per design spec |
| Card (1,0) origin | (49.5, 400.5) | per design spec |
| Card (0,1) origin | (310.5, 211.5) | per design spec |
| Cut guide vertical X | midpoint between col 0 and col 1 | (49.5 + 252 + 310.5) / 2 or per gutter center |

#### ExportCardFieldTests

These test `ExportCard` field population from both construction paths. No file I/O; use hardcoded inputs.

| Test case | What it asserts |
|-----------|----------------|
| `conceptName` non-nil | When `SavedPlay.conceptName` is "Smash", `ExportCard.conceptName == "Smash"`. |
| `conceptName` nil | When `SavedPlay.conceptName` is nil, `ExportCard.conceptName` is nil (not empty string). |
| `motionLabel` "Y Stop" | When `SavedPlay.motionLabel` is "Y Stop", `ExportCard.motionLabel == "Y Stop"`. |
| `motionLabel` "Y After" | When `SavedPlay.motionLabel` is "Y After", `ExportCard.motionLabel == "Y After"`. |
| `motionLabel` "Y Go" | When `SavedPlay.motionLabel` is "Y Go", `ExportCard.motionLabel == "Y Go"`. |
| `motionLabel` nil | When `SavedPlay.motionLabel` is nil, `ExportCard.motionLabel` is nil (never empty string, never "None"). |
| `playNumber` assigned correctly | `ExportCard.playNumber` reflects the 1-based index passed to the constructor (first selected play is 1, second is 2). |
| `yWheelEnabled` propagated | When `SavedPlay.yWheelEnabled == true`, `ExportCard.yWheelEnabled == true`. |
| `formationName` propagated | `ExportCard.formationName` matches `SavedPlay.formationName`. |
| `routeDigits` propagated | `ExportCard.routeDigits` matches `SavedPlay.routeDigits`. |

#### WristbandMotionLabelTests (carried forward, updated)

These were in the prior strategy and remain valid, but now test the `SavedPlay.motionLabel` store-at-save path rather than a direct enum-to-string mapping:

| Test case | ReceiverMotion input | Expected `SavedPlay.motionLabel` |
|-----------|---------------------|--------------------------------|
| `.stop` | `.stop` | `"Y Stop"` (rawValue) |
| `.after` | `.after` | `"Y After"` (rawValue — corrected from prior spec's "Y Go" assumption) |
| `.go` | `.go` | `"Y Go"` (rawValue) |
| `nil` | `nil` | `nil` |

**Note:** The design spec corrects the prior strategy's misidentification of `ReceiverMotion.after` as mapping to "Y Go". The raw value of `.after` is `"Y After"`, not `"Y Go"`. `.go` raw value is `"Y Go"`. Tests and assertions must use the correct strings.

### 2.5 Integration Test Coverage (All Stories)

#### SavedPlayToExportCardPipelineTests

Full pipeline test: `SavedPlay` -> `ExportCard.from(savedPlay:playNumber:interpreter:)` using a live `RouteInterpreter`. Validates that the round-trip parse is deterministic and produces a non-nil `ExportCard` for all formation/digit combinations that will appear in real game-plan exports.

| Test case | Input | Expected outcome |
|-----------|-------|-----------------|
| Twins + "6794" | Valid digits, Twins formation | Non-nil `ExportCard`; `playCall.formation == .twins`; `playCall.assignments.count == 4` |
| Trips Left + "6794" + motion "Y Stop" | Valid digits, motion applied | `ExportCard.motionLabel == "Y Stop"`; reconstructed `playCall` has Y motion applied (post-motion positions match on-screen diagram) |
| Play with `yWheelEnabled == true` | | `ExportCard.yWheelEnabled == true`; `playCall.yWheelEnabled == true` |
| Unknown formation rawValue | "FutureFormation" | `ExportCard.from()` returns nil; no crash |
| Invalid digit string | "9999" (or any string that `RouteInterpreter` rejects) | `ExportCard.from()` returns nil; no crash |
| Concept nil in SavedPlay | | `ExportCard.conceptName == nil` |
| Concept non-nil in SavedPlay | "Smash" | `ExportCard.conceptName == "Smash"` |

#### LibraryPersistenceIntegrationTests

Uses a temp directory as the library file URL. Tests the full save-to-disk and reload cycle.

| Test case | What it asserts |
|-----------|----------------|
| Write and reinit | Save 3 plays, reinit `PlayLibraryStore` with same temp file URL, assert `plays.count == 3` and all fields match. |
| Delete persists | Save 3 plays, delete 1, reinit, assert `plays.count == 2`. |
| Empty library file persists | `deleteAll()`, reinit, assert `plays.count == 0`. |
| File survives second reinit | Three successive reinits without modification; plays count unchanged. |

#### CatalogPDFStructureTests

Uses `PDFKit` to verify the generated `Data` is a valid PDF document with the expected page structure.

| Test case | N input cards | Assertions |
|-----------|--------------|-----------|
| 1 play | 1 `ExportCard` | `PDFDocument(data:)` non-nil; `pageCount == 1`; page 0 `bounds(for: .mediaBox)` == CGRect(x:0, y:0, width:792, height:612) (landscape US Letter) |
| 9 plays | 9 `ExportCard` values | `pageCount == 1` |
| 10 plays | 10 `ExportCard` values | `pageCount == 2` |
| Data begins with PDF header | Any | First 4 bytes of `Data` == `%PDF` (ASCII 37, 80, 68, 70) |
| Non-nil for valid input | 1 valid `ExportCard` | Return value is non-nil |
| Nil for empty array | 0 `ExportCard` values | Returns nil or returns a document with 0 pages (document spec behavior — confirm and assert consistently) |

#### WristbandPDFStructureTests

Mirrors `CatalogPDFStructureTests` for wristband.

| Test case | N input cards | Assertions |
|-----------|--------------|-----------|
| 1 play | 1 `ExportCard` | `pageCount == 1`; page 0 media box == CGRect(x:0, y:0, width:612, height:792) (portrait US Letter) |
| 3 plays | 3 `ExportCard` values | `pageCount == 3` |
| Data begins with PDF header | Any | First 4 bytes `%PDF` |

#### TempFileLifecycleTests

Tests that the temp file is created at the expected location and deleted after the share sheet completion handler fires.

| Test case | What it asserts |
|-----------|----------------|
| File created on disk | After `generate()` writes the temp file, `FileManager.fileExists(atPath:)` returns true. |
| File deleted after cleanup | After invoking the cleanup closure (simulating share sheet dismissal), `FileManager.fileExists(atPath:)` returns false. |
| Filename contains UUID | Temp file name begins with a UUID-format string (matches `/^[0-9A-F-]{36}-/i`). |
| File in temp directory | `tempURL.path` has prefix `NSTemporaryDirectory()`. |
| File protection on temp file | `FileManager.default.attributesOfItem(atPath:)[.protectionKey]` equals `.completeFileProtection` (conditional on physical device; skip in simulator). |

#### DiagramRendererCGContextTests

Tests the new `draw(into:playCall:config:in:)` extension method on `DiagramRenderer`. This is the highest-risk regression surface — the test establishes a baseline for the method's behavior before and after any internal refactors.

| Test case | What it asserts |
|-----------|----------------|
| Does not crash for standard PlayCall | Calling `draw(into:playCall:config:in:)` with a standard non-nil CGContext completes without throwing or crashing. |
| Does not crash with Y Wheel enabled | Same as above with `playCall.yWheelEnabled == true`. |
| Does not crash with motion applied | Same with a post-motion `PlayCall` (assignments have `motionFinalSide` applied). |
| Compatible with existing render paths | After the extension exists, all existing `DiagramRendererWheelRenderingTests` and `DiagramRendererYWheelTests` still pass. (This is validated by running the full suite; it is not a separate assertion within this class.) |

For the CGContext, create one via `UIGraphicsImageRenderer(size:)` and extract the context, or create a `CGBitmapContext` directly. The test asserts non-crash behavior; pixel output is not asserted (visual correctness is Ken's manual sign-off in Story 3.3).

#### PlayCallerViewModelSaveExportStateTests

| Test case | What it asserts |
|-----------|----------------|
| `canSave` false when `currentPlayCall == nil` | At init, `canSave == false`. |
| `canSave` true after successful parse | After `parseRouteDigits()` with valid input, `canSave == true`. |
| `canSave` false after `reset()` | After `reset()`, `canSave == false`. |
| `saveCurrentPlay()` adds entry to store | With a mock/temp store, call `saveCurrentPlay()`; assert `store.plays.count == 1`. |
| `saveCurrentPlay()` no-op when `canSave == false` | Call `saveCurrentPlay()` with no active play; assert `store.plays.count == 0`. |
| `canExport` false when `currentPlayCall == nil` | At init, `canExport == false`. |
| `canExport` true after valid parse | After parsing, `canExport == true`. |
| `canExport` false after `reset()` | After `reset()`, `canExport == false`. |
| `isExporting` transitions | Starts false; set to true during export Task; returns to false after Task completes (await with timeout). |
| Export does not modify `currentPlayCall` | After `exportCurrentPlay()` completes, `currentPlayCall` is unchanged. |
| Export does not modify library store | `exportCurrentPlay()` (quick-export path) does not call `libraryStore.save()`. |

### 2.6 E2E / UI Automation: What Cannot Be Automated

`UIActivityViewController` (the iOS share sheet) is a system-provided view controller. XCUITest cannot interact with its content — selecting "Print", "Save to Files", or "AirDrop" programmatically is not possible in the simulator or on device via XCTest. Apple's system views are not accessible to the test process.

**What replaces the E2E layer:** A documented manual smoke test (see Section 7). The manual smoke test now covers both export modes.

---

## 3. Acceptance Criteria Mapped to Tests

### Story 3.0: Play Library / Persistence

| Acceptance Criterion | Test | Type |
|---------------------|------|------|
| Tapping "Save Play" adds play to library with visual confirmation | `PlayCallerViewModelSaveExportStateTests` — `saveCurrentPlay()` side effects. Visual confirmation (`saveConfirmed` flag): unit. Button appearance: manual smoke. | Integration + Manual |
| Duplicate save creates a new entry (not de-duplicated) | `PlayLibraryStoreUnitTests` — duplicate save test | Unit |
| Save Play button disabled when no valid play call | `PlayCallerViewModelSaveExportStateTests` — `canSave == false` | Integration |
| Library shows list of saved plays (formation, digits, concept, motion) | `ExportCardFieldTests` — field population. View rendering: manual smoke. | Unit + Manual |
| Swipe-to-delete removes entry and list updates immediately | `PlayLibraryStoreUnitTests` — delete test. View update: manual smoke. | Unit + Manual |
| Empty state shown when library has no saved plays | Manual smoke test. | Manual |
| Three plays survive force-quit and relaunch | `LibraryPersistenceIntegrationTests` — write and reinit test | Integration |
| No network access, CoreData, or iCloud sync | Static: code review (no import CloudKit, no CoreData stack). Auditor conformance. | Auditor |
| Persistence uses UserDefaults or flat JSON in app sandbox | `LibraryPersistenceIntegrationTests` — file URL verified in sandbox. Code review. | Integration + Auditor |

### Story 3.1: Play Catalog Export

| Acceptance Criterion | Test | Type |
|---------------------|------|------|
| N plays produces ceil(N/9) pages, each landscape US Letter | `CatalogPageCountTests` (unit arithmetic) + `CatalogPDFStructureTests` (PDFKit verification) | Unit + Integration |
| Generated PDF renders without errors in any viewer | `CatalogPDFStructureTests` — `PDFDocument(data:)` non-nil, pageCount >= 1 | Integration |
| Card shows: play number, formation, digits with labels, concept (if matched) | `ExportCardFieldTests` — field population. `CatalogPDFStructureTests` — data valid. String extraction if available. | Unit + Integration |
| Concept nil -> no concept field (no blank label) | `ExportCardFieldTests` — nil propagation | Unit |
| Y Motion == .stop -> "Y Stop" on card | `WristbandMotionLabelTests` (rawValue test) + `ExportCardFieldTests` | Unit |
| Y Motion == nil -> no motion field | `ExportCardFieldTests` — nil propagation | Unit |
| Y Wheel enabled -> mini diagram renders wheel arc | `DiagramRendererCGContextTests` — no crash with yWheelEnabled; visual correctness: manual | Integration + Manual |
| 6 plays on one landscape page, 7 plays on two pages | `CatalogPageCountTests` (also covers 6/7 boundary, not just 9/10 boundary — note: spec uses 6-up example in AC; architecture uses 9-up. Test 9-up: 9 -> 1 page, 10 -> 2 pages) | Unit + Integration |
| Ken confirms legibility on printed sheet | **Not automatable.** Story 3.3 sign-off. | Manual (Story 3.3) |
| Library has >= 1 play -> Export button enabled | `PlayCallerViewModelSaveExportStateTests` — `canExport` gated on play presence. View state: manual smoke. | Integration + Manual |
| 0 plays selected -> export button disabled | Manual smoke test (multi-select view state). ViewModel guard: `canExport` false when no selection. | Manual |
| Select All selects all plays; count updates | Manual smoke test. | Manual |
| Deselecting a play decrements count | Manual smoke test. | Manual |
| Choosing "Play Catalog" -> catalog PDF + share sheet | Manual smoke test (share sheet not automatable). | Manual |
| Cancel at mode selection -> no PDF generated, return to selection | `PlayCallerViewModelSaveExportStateTests` — cancel simulation; `isExporting == false`. | Integration |
| PDF generation error -> alert, no crash | `WristbandPDFErrorHandlingTests` (reused for catalog path) — nil generate() + no crash | Integration |
| Share sheet dismiss -> temp file cleaned up | `TempFileLifecycleTests` | Integration |

**Note on AC "6 plays on one page, 7 plays on two pages":** The product spec's Story 3.1 AC uses 6-up language. The architecture spec resolves to 9-up. The test implementation must use the 9-up formula (9 -> 1 page, 10 -> 2 pages) per the architecture decision. If Ken changes to 6-up during Story 3.3, only `CatalogCardConfig` constants and `CatalogPageCountTests` values change — the test class structure remains the same.

### Story 3.2: Wristband Export

| Acceptance Criterion | Test | Type |
|---------------------|------|------|
| N plays -> N PDF pages | `WristbandPageCountTests` (unit) + `WristbandPDFStructureTests` (integration) | Unit + Integration |
| Each page shows 4 identical cards in 2x2 grid on portrait US Letter | `WristbandCellGeometryTests` (grid math) + `WristbandPDFStructureTests` (media box) | Unit + Integration |
| 2x2 grid fits in printable area; two cuts produce 3.5x2.5 cards | `WristbandCellGeometryTests` — total grid width/height < page size minus margins | Unit |
| Card content same as catalog (all fields) | `ExportCardFieldTests` — shared ExportCard model for both modes | Unit |
| Print at 300 dpi, cut, laminate -> legible at 18" | **Not automatable.** Story 3.3 sign-off. | Manual (Story 3.3) |
| Ken confirms wristband format matches coaching intent | **Not automatable.** Story 3.3 sign-off. | Manual (Story 3.3) |
| PDF generation error -> alert, no crash | `WristbandPDFErrorHandlingTests` | Integration |
| Share sheet dismiss -> temp file cleaned up | `TempFileLifecycleTests` | Integration |
| File protection on temp file write | `TempFileLifecycleTests` — protection key assertion (device-conditional) | Integration |

### Story 3.3: Coach Field Validation

All Story 3.3 acceptance criteria are field-validation criteria: physical print, outdoor lighting, lamination, practice use. None are automatable. All require Ken's sign-off. This story cannot be closed by automated tests.

**SDET role in Story 3.3:** Confirm all automated tests pass and write `docs/test-plans/wristband-export-test-results.md` documenting which ACs are automated-verified and which require Ken's sign-off. The results report is the SDET done-when for Step 8.

---

## 4. New Test Files to Create

The following test files must be created under `SpartansPlaycallerTests/`. Files that correspond to prior strategy stubs are noted.

| File | Class name | Layer | Priority | Notes |
|------|-----------|-------|----------|-------|
| `SavedPlayCodableTests.swift` | `SavedPlayCodableTests` | Unit | P0 | New — covers Story 3.0 DTO round-trip |
| `PlayLibraryStoreUnitTests.swift` | `PlayLibraryStoreUnitTests` | Unit | P0 | New — save, load, delete, reinit, duplicate, corrupt file |
| `ExportCardFieldTests.swift` | `ExportCardFieldTests` | Unit | P0 | New — field population for both construction paths; covers all nil/non-nil permutations |
| `CatalogPageCountTests.swift` | `CatalogPageCountTests` | Unit | P0 | New — page count arithmetic for 9-up layout |
| `CatalogCellGeometryTests.swift` | `CatalogCellGeometryTests` | Unit | P0 | New — all 9 cell origins, card width/height, gutter math |
| `WristbandPageCountTests.swift` | `WristbandPageCountTests` | Unit | P0 | New — N plays -> N pages |
| `WristbandCellGeometryTests.swift` | `WristbandCellGeometryTests` | Unit | P0 | Replaces `WristbandCardLayoutTests` from prior strategy; same geometry scope, updated for current spec |
| `WristbandMotionLabelTests.swift` | `WristbandMotionLabelTests` | Unit | P0 | Carried forward; corrected `.after` -> "Y After" (was incorrectly "Y Go") |
| `CatalogFilenameTests.swift` | `CatalogFilenameTests` | Unit | P1 | New — temp filename format for catalog export |
| `WristbandFilenameTests.swift` | `WristbandFilenameTests` | Unit | P1 | Carried forward from prior strategy |
| `SavedPlayToExportCardPipelineTests.swift` | `SavedPlayToExportCardPipelineTests` | Integration | P0 | New — full pipeline with live RouteInterpreter; key round-trip correctness gate |
| `LibraryPersistenceIntegrationTests.swift` | `LibraryPersistenceIntegrationTests` | Integration | P0 | New — write/reinit/delete persistence cycle using temp directory |
| `CatalogPDFStructureTests.swift` | `CatalogPDFStructureTests` | Integration | P0 | New — PDFKit page count, media box, data validity for catalog |
| `WristbandPDFStructureTests.swift` | `WristbandPDFStructureTests` | Integration | P0 | Replaces `WristbandPDFGeneratorIntegrationTests` + `WristbandPDFContentTests` from prior strategy; unified under new ExportCard API |
| `DiagramRendererCGContextTests.swift` | `DiagramRendererCGContextTests` | Integration | P0 | Replaces `DiagramRendererOffScreenTests` from prior strategy; now covers the CGContext draw path (not UIImage/off-screen image path) as per architecture Option B decision |
| `TempFileLifecycleTests.swift` | `TempFileLifecycleTests` | Integration | P0 | Carried forward from prior strategy; now covers both catalog and wristband temp files |
| `PlayCallerViewModelSaveExportStateTests.swift` | `PlayCallerViewModelSaveExportStateTests` | Integration | P0 | Replaces `PlayCallerViewModelExportStateTests` from prior strategy; now also covers canSave and saveCurrentPlay |
| `WristbandPDFErrorHandlingTests.swift` | `WristbandPDFErrorHandlingTests` | Integration | P1 | Carried forward; now covers both catalog and wristband error paths via a shared test class or separate cases |
| `WristbandPDFYWheelTests.swift` | `WristbandPDFYWheelTests` | Integration | P1 | Carried forward; Y Wheel in wristband PDF; add parallel `CatalogPDFYWheelTests` case or extend same file |

**P0 = merge-blocking.** All P0 tests must pass before the feature branch is merged to main.

**P1 = required before epic close.** P1 tests must exist and pass before Story 3.3 sign-off. They may trail the P0 commit by one implementation cycle if P0 suite is green and P1 scope is confirmed low-risk.

**Files from the prior strategy that are NOT carried forward (superseded):**

- `WristbandCardModelTests.swift` — superseded by `ExportCardFieldTests.swift` (ExportCard replaces WristbandCard)
- `WristbandPlayNumberTests.swift` — absorbed into `ExportCardFieldTests.swift` (playNumber is now tested there)
- `DiagramRendererOffScreenTests.swift` — superseded by `DiagramRendererCGContextTests.swift` (architecture resolved to Option B, not off-screen UIImage rendering)

---

## 5. Test Environment Prerequisites (Updated)

### 5.1 Automated Tests (Unit + Integration)

- **Xcode 15.0 or later.** PDFKit and all Core Graphics APIs used in PDF generation are available in iOS 17+ and function in Xcode 15+ simulators.
- **Any iPhone simulator** for running unit and integration tests. No physical device required for P0 or P1 automated tests.
- **No network access required.** All functionality is on-device. Tests must not depend on reachability.
- **Temp directory for persistence tests.** `PlayLibraryStore` must accept an injectable `fileURL` parameter (or a factory that can be overridden in test targets) so that persistence tests write to `FileManager.default.temporaryDirectory` rather than the real Documents directory. Preferred approach: init-parameter injection (`init(fileURL: URL = PlayLibraryStore.defaultFileURL)`). The implementing engineer must make this seam available before `LibraryPersistenceIntegrationTests` can be written.
- **Run command:** `xcodebuild test -scheme SpartansPlaycaller -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.5'` (or current simulator/OS as appropriate for the project's CI config).
- **No third-party test dependencies.** All tests use XCTest from Xcode's standard toolchain.
- **@MainActor pattern.** New ViewModel tests must follow the existing pattern from `PlayCallerViewModelTests.swift`: `nonisolated(unsafe) var viewModel` initialized inside `MainActor.assumeIsolated { }`. Tests that trigger async operations must use `await` with a timeout or use `XCTestExpectation` to avoid hanging.

### 5.2 File Protection Assertions

`FileManager.attributesOfItem(atPath:)[.protectionKey]` returns meaningful values only on a physical device where the iOS file protection subsystem is active. In the simulator, the protection key is present but the value is not `.complete` — it reflects macOS file semantics. Tests that assert `.completeFileProtection` must be conditionally skipped in the simulator:

```swift
#if !targetEnvironment(simulator)
// assert protection key
#endif
```

Flag these with a comment explaining the skip. They are verified manually or via CI on a physical device if one is configured.

### 5.3 Manual Smoke Test (Export Flow)

- **iPhone simulator or physical device.** The share sheet is presented in the simulator; however, Print and Save to Files require a physical device for full activity coverage.
- **AirPrint validation.** Physical iPhone running iOS 17+ and an AirPrint-compatible printer on the same network. One-time manual test for Story 3.3 acceptance. Out of scope for CI.

### 5.4 Physical Print Validation (Story 3.3 Only)

- Standard inkjet or laser printer capable of 300 dpi output.
- 8.5" x 11" US Letter paper.
- Consumer lamination pouch (for wristband legibility-after-lamination check).
- No CI environment can replicate this. It is a coaching-domain acceptance test performed by Ken.

---

## 6. Platform Matrix

**Not applicable.** Spartans Playcaller is a native iOS application (SwiftUI, iOS 17+). There is no web layer, no browser rendering, and no cross-browser compatibility concern.

**Platform matrix for this epic:** iPhone running iOS 17+. Automated tests run on Xcode simulator (iPhone 15 or current). AirPrint validation requires physical iPhone. No iPad or macOS targets are in scope for V1.

---

## 7. Manual Smoke Test Charter (Updated — Both Export Modes)

Because the E2E share sheet flow cannot be automated, the following manual smoke test must be executed before `docs/test-plans/wristband-export-test-results.md` is written. The test now covers both export modes and the library persistence flow.

**Precondition:** App built and installed on simulator or device. App is in initial state (no saved plays).

### Part A: Library Persistence

| Step | Action | Expected result |
|------|--------|----------------|
| A1 | Launch app. Observe PlayCallerView toolbar. | Save Play button is disabled or absent (no valid play call). Library button is present. |
| A2 | Enter "Twins" + "6794"; tap Parse. | Play call displayed. Save Play button becomes enabled. |
| A3 | Tap Save Play. | Brief visual confirmation (checkmark or "Saved"). |
| A4 | Open Library view. | Library shows 1 entry: "Twins / 6794". |
| A5 | Return to PlayCallerView. Enter "Trips Left" + "1234"; tap Parse. Tap Save Play. | Second play saved. |
| A6 | Enter "Twins" + "6794" again; tap Save Play. | Library now has 3 entries including duplicate (two "Twins / 6794" entries — no de-duplication). |
| A7 | Swipe left on one entry; tap Delete. | Entry removed. Library now shows 2 entries. |
| A8 | Force-quit the app (swipe up in app switcher). Relaunch. | Both remaining plays are present in the Library. Persistence confirmed. |

### Part B: Play Catalog Export

| Step | Action | Expected result |
|------|--------|----------------|
| B1 | From Library view, tap Select. Select all plays. Tap Export. | Format action sheet appears: "Play Catalog", "Wristband Cards", "Cancel". |
| B2 | Tap "Play Catalog". | Spinner appears briefly. Share sheet presented. |
| B3 | In share sheet, tap "Save to Files". Save the file. | File named something like `"UUID-2-plays-catalog.pdf"` saved. |
| B4 | Open the saved PDF. | PDF shows 1 landscape page (2 plays < 9-up threshold). Each play card visible. Play numbers 1 and 2 present. Formation names visible. Route digits visible. Mini diagrams present. |
| B5 | Verify cards with concept: save a play with a concept (e.g., a formation+digits combo that matches "Smash"). Export catalog. | Concept name appears on that card. |
| B6 | Verify concept nil: the other card (no concept match) shows no blank concept label. | No blank label. |
| B7 | Tap Cancel in format action sheet. | Share sheet does not appear. App returns to selection. |

### Part C: Wristband Export

| Step | Action | Expected result |
|------|--------|----------------|
| C1 | From Library view, select 2 plays. Tap Export. Tap "Wristband Cards". | Share sheet presented. |
| C2 | Save the file to Files. | File saved with name containing "wristband". |
| C3 | Open the PDF. | PDF has 2 pages (1 per play). Each page is portrait US Letter. Each page shows a 2x2 grid of 4 identical cards. |
| C4 | Inspect card fields. | Play number, formation, route digits, and mini diagram present on each card. Notes rule visible at card bottom. |
| C5 | Verify Y Motion: save a play with motion applied. Export wristband. | "Y Stop", "Y After", or "Y Go" appears on the card. Post-motion diagram shown. |
| C6 | Verify Y Motion nil: card with no motion shows no blank label in motion field. | No blank label. |
| C7 | Verify Y Wheel: save a play with Y Wheel enabled. Export wristband. | Mini diagram shows wheel arc path. |

### Part D: Quick Export Path (from PlayCallerView)

| Step | Action | Expected result |
|------|--------|----------------|
| D1 | In PlayCallerView with a valid play call, tap the share icon in the nav bar. | Action sheet appears: "Export Current Play" (and optionally "Save Play First"), "Cancel". |
| D2 | Tap "Export Current Play". Tap "Play Catalog". | Share sheet presented. Catalog PDF with 1 play generated. |
| D3 | Tap Cancel in mode action sheet. | No PDF generated. App state unchanged. |

### Part E: Error and Edge Cases

| Step | Action | Expected result |
|------|--------|----------------|
| E1 | Empty library: from Library view, tap Export button. | Export button is disabled (cannot tap with empty library). |
| E2 | Simulate export failure (if a test seam exists). | Alert "Could not generate PDF. Please try again." App does not crash. |

**Pass condition:** All steps produce the expected result without app crash, hang, or missing content.

**Failure handling:** Any step failure is filed as a defect with the step number, actual result, and a screenshot or screen recording. Software-engineer is dispatched to fix before SDET re-runs the failed step.

---

## 8. Open Questions Affecting Test Design

The following questions from the product spec and design spec are unresolved at the time of this strategy and affect specific test content if resolved differently from the documented defaults.

| # | Question | Default assumed in this strategy | Test impact if resolved differently |
|---|----------|----------------------------------|-------------------------------------|
| OQ-A | **6-up vs 9-up catalog density:** The architecture spec resolves to 9-up per Ken's confirmation. If Ken reverses to 6-up during Story 3.3 review, `CatalogPageCountTests` and `CatalogCellGeometryTests` must be updated with 6-up math (6 per page, 3x2 grid). | **9-up (resolved)** | `CatalogPageCountTests` page count formula changes from `ceil(N/9)` to `ceil(N/6)`. `CatalogCellGeometryTests` cell dimensions change. No structural change to test classes. |
| OQ-B | **`PlayLibraryStore` injection pattern (init param vs EnvironmentObject):** Architecture recommends init-param injection for testability. If the engineer chooses EnvironmentObject, tests that construct `PlayCallerViewModel` without the environment chain will either require `@EnvironmentObject` setup in tests (messy) or the ViewModel will not have access to the store in test context. | **Init-param injection** | If EnvironmentObject: every `PlayCallerViewModelSaveExportStateTests` test setUp must inject the store via `environmentObject()` or a mock — significantly more boilerplate. |
| OQ-C | **`applyMotion` extraction to `PlayCall` static method:** If the engineer does not extract this and instead duplicates the logic in `ExportCard`, the divergence risk materializes as a silent diagram mismatch. | **Extracted (recommended)** | If not extracted: `SavedPlayToExportCardPipelineTests` must include a cross-comparison test: generate a diagram from both the ViewModel path and the ExportCard path for the same play and confirm they produce identical `PlayCall` state. |
| OQ-D | **Export button enabled state when library is empty (catalog/wristband export paths):** Spec says disabled. If the implementation shows the button but presents an empty state on tap instead of disabling, the `PlayCallerViewModelSaveExportStateTests` assertion for `canExport == false with empty library` is still valid at the model level; the visual state test becomes manual. | **Disabled** | Model test unchanged. Manual smoke E1 step verifies view behavior. |
| OQ-E | **Quick-export path (Path A) single-play catalog behavior:** Path A generates a catalog with 1 play on 1 page. The `CatalogPageCountTests` already cover N=1 -> 1 page. If the quick-export path uses a different code path than the library export path, a separate integration test is needed to confirm both converge on the same generator. | **Same generator** | If different code paths: add `QuickExportCatalogIntegrationTests` and `QuickExportWristbandIntegrationTests` to verify quick-export PDFs have the same structure as library-export PDFs for N=1. |

---

## 9. Done-When for SDET Step 8

SDET's step is not complete until all of the following are true:

1. All P0 test files listed in Section 4 exist on disk and pass (`xcodebuild test` exits 0).
2. All P1 test files listed in Section 4 exist on disk and pass.
3. All 18 pre-existing test files in Section 1.2 still pass — no regressions.
4. Manual smoke test charter (Section 7) has been executed; all steps passed or defects filed with step number, actual result, and screenshot.
5. `docs/test-plans/wristband-export-test-results.md` exists and documents: total automated test count, pass/fail status per class, which ACs are automated-verified, which ACs require Ken's manual sign-off (Story 3.3), and any open defects with priority and assigned owner.

Step 8 is not satisfied by "tests passed during implementation." The formal SDET dispatch must execute the full test suite independently and produce the results report file.
