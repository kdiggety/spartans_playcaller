# Architecture Design Spec: Epic 3.1 — Play Library, Play Catalog & Wristband Export

**Date:** 2026-06-07 (revised — full scope update)
**Author:** Architecture & System Design
**Status:** READY FOR IMPLEMENTATION PLAN
**Spec reference:** `docs/superpowers/specs/2026-06-07-wristband-export-spec.md`
**UX reference:** `docs/superpowers/specs/2026-06-07-wristband-export-ux-consultation.md`
**Security reference:** `docs/superpowers/specs/2026-06-07-wristband-export-security-consultation.md`
**Test strategy:** `docs/test-plans/wristband-export-test-strategy.md`
**Performance assessment:** `docs/test-plans/wristband-export-performance-assessment.md`

**Revision note:** This document supersedes the original 2026-06-07 wristband-only spec in full. The original spec's wristband pipeline decisions, security requirements (REQ-SEC-1 through REQ-SEC-4), and vector-rendering approach (Option B) are preserved and extended here. The scope now covers three stories: Story 3.0 (Play Library / Persistence), Story 3.1 (Play Catalog Export), and Story 3.2 (Wristband Export). Open questions NQ-1 and NQ-2 from the revised product spec are resolved here by Ken's confirmation: **9-up (3×3) landscape**.

---

## 1. Overview

This epic converts Spartans Playcaller from a design-time tool into a game-day coaching system by adding three capabilities:

**Story 3.0 — Play Library.** Coaches save plays during the week to an in-app library that persists across launches as a flat JSON file in the app sandbox. No CoreData, no iCloud. A lightweight Codable DTO (`SavedPlay`) wraps the display fields needed for export without requiring full `PlayCall` Codable conformance.

**Story 3.1 — Play Catalog Export.** From the library, coaches select plays and export a dense landscape PDF: 9 plays per page in a 3×3 grid (Ken confirmed), one or more pages depending on selection size. Coaches print this on plain paper and use it as a sideline reference sheet.

**Story 3.2 — Wristband Export.** From the library, coaches select plays and export cut-ready lamination cards: 4 identical copies of each play per portrait page, one page per play. Players wear these cards on their forearms.

Both export modes share a common data model (`ExportCard`), a common mini-diagram rendering seam (`DiagramRenderer.draw(into:playCall:config:in:)`), and the same security/temp-file pipeline. The export entry points support both a quick single-play path (no library required) and a multi-play library path. Multi-select is V1; play ordering and drag-reorder are V2.

### Mental model

The data flows in one direction: the coach builds a play in `PlayCallerViewModel` → saves it to `PlayLibraryStore` (which persists to JSON) → opens `PlayLibraryView` → selects plays → triggers an export → `CatalogPDFGenerator` or `WristbandPDFGenerator` renders `ExportCard` values into a PDF → `UIActivityViewController` delivers the PDF. No state flows backward from export into the library or play-caller. Export is a pure read operation on library data.

---

## 2. New Component: PlayLibrary

### 2.1 Codable feasibility assessment

Before deciding between a `SavedPlay` DTO and full `PlayCall` Codable conformance, we must assess whether `PlayCall` and its dependencies are Codable.

**Type inventory:**

| Type | Kind | Codable feasibility |
|------|------|-------------------|
| `PlayCall` | struct | Has `let id = UUID()` (auto-synthesized OK), references enum and struct types below |
| `Formation` | `String` raw-value enum | Trivially Codable — raw value synthesis |
| `RouteAssignment` | struct | Has `let id = UUID()` (OK), references enums below |
| `Receiver` | enum (assumed String raw value) | Trivially Codable |
| `RouteNumber` | `Int` raw-value enum | Trivially Codable |
| `FieldSide` | `String` raw-value enum | Trivially Codable |
| `RouteMeaning` | enum (assumed String raw value) | Trivially Codable |
| `ReceiverMotion` | `String` raw-value enum (`stop`, `after`, `go`) | Trivially Codable |
| `RouteConcept` | `String` raw-value enum | Trivially Codable |

**Assessment:** No closures, no non-Codable computed-only storage. All types are raw-value enums or simple structs. Making `PlayCall` itself `Codable` is technically feasible and would require adding `Codable` conformance to `RouteAssignment` (which carries `initialMeaning: RouteMeaning` — needs `RouteMeaning` to be Codable) and confirming `Receiver` and `RouteMeaning` carry raw values. This is low-risk invasive work touching four model files.

**Architectural decision: Use `SavedPlay` DTO instead of making `PlayCall` Codable.**

Rationale:

1. `PlayCall` carries behavioral data (`yWheelEnabled`, the full `assignments` array with `motionFinalSide` computed properties) that is needed at display time but not at persistence time. Encoding the full computed graph is wasteful.
2. Cards at export time need only five display fields (formation name, digit string, concept name, motion label, Y Wheel flag). A DTO captures exactly these.
3. Avoiding Codable conformance on `PlayCall` keeps the model layer free of persistence concerns — a clean boundary.
4. If full `PlayCall` reconstruction is ever needed (e.g., re-editing a saved play), the digit string + formation name stored in `SavedPlay` can be re-parsed via the existing `RouteInterpreter`. This round-trip path works because `routeDigits` is the source of truth.

**Downside (owned):** Diagram rendering at export time requires re-running `PlayCallParser`/`RouteInterpreter` from the saved digit string. This adds ~5–15ms per play at export time — well within the 500ms budget. The alternative (caching a pre-rendered diagram as PNG data in `SavedPlay`) is feasible but premature: PNG data per play would significantly increase library file size (tens of KB per play vs. a few hundred bytes per JSON record), and the performance budget is not threatened.

### 2.2 `SavedPlay` — value type (struct)

**Location:** `SpartansPlaycaller/Models/SavedPlay.swift`

```swift
struct SavedPlay: Codable, Identifiable {
    let id: UUID                    // Stable identity for SwiftUI List and deletion
    let savedAt: Date               // For display ordering (newest-last in V1)
    let formationName: String       // Formation.rawValue — e.g., "Twins"
    let routeDigits: String         // Raw digit string — e.g., "6794"
    let conceptName: String?        // RouteConcept.rawValue if matched; nil otherwise
    let motionLabel: String?        // "Y Stop", "Y After", or "Y Go" if motion present; nil otherwise
    let yWheelEnabled: Bool         // Whether Y Wheel was active
}
```

**Construction from `PlayCall` + ViewModel state:**

```swift
extension SavedPlay {
    static func from(
        playCall: PlayCall,
        motion: ReceiverMotion?,
        yWheelEnabled: Bool
    ) -> SavedPlay {
        SavedPlay(
            id: UUID(),
            savedAt: Date(),
            formationName: playCall.formation.rawValue,
            routeDigits: playCall.routeDigits,
            conceptName: playCall.concept?.rawValue,
            motionLabel: motion?.rawValue,   // ReceiverMotion.rawValue = "Y Stop" / "Y After" / "Y Go"
            yWheelEnabled: yWheelEnabled
        )
    }
}
```

**Invariants:**
- `conceptName` is nil (never empty string) when no concept matched.
- `motionLabel` is nil (never empty string) when no motion was applied. The raw value of `ReceiverMotion` is already the display label ("Y Stop", "Y After", "Y Go"), so no mapping is needed on read.
- `routeDigits` is the canonical digit string as entered/generated; it is sufficient to reconstruct a `PlayCall` via `RouteInterpreter` at export time.

**Motion label note:** The previous spec used "Y Go" for `ReceiverMotion.after`. Reading the actual `ReceiverMotion` source reveals three cases: `.stop` (rawValue "Y Stop"), `.after` (rawValue "Y After"), and `.go` (rawValue "Y Go"). The `SavedPlay` stores `motion?.rawValue` directly, so display labels are exactly "Y Stop", "Y After", and "Y Go" — matching the raw values.

**Duplicate handling (resolved per spec NQ-4 default):** Each save creates a new `SavedPlay` with a new UUID. If the coach saves the same formation+digits combination twice, two entries appear in the library. The coach decides which to keep. No de-duplication logic is implemented in V1.

### 2.3 `PlayLibraryStore` — service (class)

**Location:** `SpartansPlaycaller/Services/PlayLibraryStore.swift`

```swift
@MainActor
final class PlayLibraryStore: ObservableObject {
    @Published private(set) var plays: [SavedPlay] = []

    private let fileURL: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("play-library.json")
    }()

    init() {
        load()
    }

    func save(_ playCall: PlayCall, motion: ReceiverMotion?, yWheelEnabled: Bool)
    func delete(at offsets: IndexSet)
    func deleteAll()

    private func load()
    private func persist()
}
```

**Persistence detail:**

- `load()` reads `play-library.json` from the Documents directory, decodes `[SavedPlay]` with `JSONDecoder`, and sets `plays`. If the file does not exist, `plays` remains empty (not an error). If decoding fails, log the error and set `plays = []` — do not crash.
- `persist()` encodes `plays` to JSON with `JSONEncoder` and writes to `fileURL` with `.completeFileProtection` (REQ-SEC-5). This is called after every `save` and `delete` operation. Since `plays` never exceeds a few hundred entries and each entry is ~200 bytes, total file size is under 50KB — write latency is negligible.
- `save(_:motion:yWheelEnabled:)` appends a new `SavedPlay` (constructed via `SavedPlay.from(...)`) to `plays` and calls `persist()`.
- `delete(at:)` removes entries at the given `IndexSet` and calls `persist()`.
- `deleteAll()` sets `plays = []` and calls `persist()`.

**Persistence location — Documents directory (intentional):** The spec's Appendix B notes the Documents directory is user-visible in the Files app. This is intentional: coaches may want to back up or copy their library. If this creates operational issues (e.g., library shows up as a clutter item), the alternative is the Application Support directory (`applicationSupportDirectory`). Architecture's recommendation is Documents for V1 as specified; the engineer can escalate if Ken wants to change this.

**Injection:** `PlayLibraryStore` is injected as an `@EnvironmentObject` into the SwiftUI view hierarchy at the root level (in the App struct), so both `PlayCallerView` and `PlayLibraryView` can access the same store instance.

**State isolation:** `PlayLibraryStore` state is fully independent of `PlayCallerViewModel` state. A `save` call on the store does not modify any ViewModel state. A `reset()` on the ViewModel does not affect the store. The only coupling is through the `save` action in `PlayCallerViewModel.saveCurrentPlay()`, which reads ViewModel state and delegates to the store — a one-directional dependency.

---

## 3. New Component: ExportCard (data model)

**Location:** `SpartansPlaycaller/Models/ExportCard.swift`

`ExportCard` replaces the previous spec's `WristbandCard`. It is the shared value type used by both `CatalogPDFGenerator` and `WristbandPDFGenerator`. It is constructed at export time from a `SavedPlay` (library path) or from the current `PlayCall` (quick-export path).

```swift
struct ExportCard {
    let playNumber: Int             // 1-based index in selection order
    let formationName: String       // e.g., "Twins"
    let routeDigits: String         // e.g., "6794"
    let conceptName: String?        // nil when no concept matched
    let motionLabel: String?        // "Y Stop" / "Y After" / "Y Go" / nil
    let yWheelEnabled: Bool
    let playCall: PlayCall          // Reconstructed at export time for diagram rendering
}
```

**Construction paths:**

Path A (from `SavedPlay` in library export):
```swift
extension ExportCard {
    static func from(
        savedPlay: SavedPlay,
        playNumber: Int,
        interpreter: RouteInterpreter
    ) -> ExportCard? {
        // 1. Recover Formation from rawValue
        guard let formation = Formation(rawValue: savedPlay.formationName) else { return nil }
        // 2. Re-parse digit string to get assignments + concept
        guard case .success(let playCall) = interpreter.interpret(
            digits: savedPlay.routeDigits,
            formation: formation
        ) else { return nil }
        // 3. Re-apply motion if present (only .stop changes diagram; .after/.go do too)
        var finalPlayCall = playCall
        if let motionLabel = savedPlay.motionLabel,
           let motion = ReceiverMotion(rawValue: motionLabel) {
            // Re-run applyMotion logic to get the post-motion PlayCall
            finalPlayCall = applyMotion(motion, to: playCall)
        }
        // 4. Apply yWheelEnabled flag
        finalPlayCall = PlayCall(
            formation: finalPlayCall.formation,
            routeDigits: finalPlayCall.routeDigits,
            assignments: finalPlayCall.assignments,
            concept: finalPlayCall.concept,
            yWheelEnabled: savedPlay.yWheelEnabled
        )
        return ExportCard(
            playNumber: playNumber,
            formationName: savedPlay.formationName,
            routeDigits: savedPlay.routeDigits,
            conceptName: savedPlay.conceptName,
            motionLabel: savedPlay.motionLabel,
            yWheelEnabled: savedPlay.yWheelEnabled,
            playCall: finalPlayCall
        )
    }
}
```

Path B (from current `PlayCall` in quick export):
```swift
extension ExportCard {
    static func from(playCall: PlayCall, motion: ReceiverMotion?, playNumber: Int) -> ExportCard {
        ExportCard(
            playNumber: playNumber,
            formationName: playCall.formation.rawValue,
            routeDigits: playCall.routeDigits,
            conceptName: playCall.concept?.rawValue,
            motionLabel: motion?.rawValue,
            yWheelEnabled: playCall.yWheelEnabled,
            playCall: playCall  // already post-motion if currentPlayCallWithMotion was used
        )
    }
}
```

**Invariants:**
- `conceptName` is nil (never empty) when no concept matched.
- `motionLabel` is nil (never empty) when no motion was applied.
- `playCall` is always the post-motion state — the diagram renders the execution state, not the pre-snap alignment.
- `playNumber` is 1-based and reflects the order in which plays were selected in the export flow.

**Diagram reconstruction note:** Re-parsing via `RouteInterpreter` at export time takes ~5–15ms per play. For 9 plays on one page this is 45–135ms — within budget. The interpreter is a pure function (no shared mutable state), so it is safe to call from a background task. The engineer does not need to cache or pre-warm the interpreter.

**`applyMotion` helper:** The static helper `applyMotion(_:to:)` in the `ExportCard` extension replicates the logic in `PlayCallerViewModel.applyMotion()`. This logic should be extracted into a free function or a method on `PlayCall` to avoid duplication. Preferred location: a static method on `PlayCall` (`PlayCall.applying(_ motion: ReceiverMotion?) -> PlayCall`). This is a refactor the implementing engineer should make as part of Story 3.0 to keep the motion application logic in one place. If the refactor is out of scope, the duplication is acceptable in V1 with a backlog note.

---

## 4. Catalog PDF Generator (new — Story 3.1)

### 4.1 Layout: 9-up, 3×3, landscape (Ken confirmed)

**Page dimensions:** US Letter landscape — 792pt wide × 612pt tall (11" × 8.5" at 72pt/inch).

**Margins:** 36pt (0.5") on all sides.

**Available area:** 792 − 72 = 720pt wide; 612 − 72 = 540pt tall.

**Grid:** 3 columns × 3 rows.

**Gutter between cells:** 8pt horizontal and vertical.

**Cell size calculation:**
- Column width: (720 − 2 × 8) / 3 = (720 − 16) / 3 = 234.67pt → floor to **234pt** (total used: 234×3 + 8×2 = 718pt, leaving 2pt of rounding slack absorbed by centering)
- Row height: (540 − 2 × 8) / 3 = (540 − 16) / 3 = 174.67pt → floor to **174pt** (total used: 174×3 + 8×2 = 538pt, leaving 2pt absorbed by centering)
- Effective card dimensions: **234pt × 174pt** (approx. 3.25" × 2.42")

**Cell origins (top-left of each cell, in screen coordinates after coordinate flip):**

The grid starts at x=36, y=36 (top-left margin). Column stride = 234 + 8 = 242pt. Row stride = 174 + 8 = 182pt.

| Cell (row, col) | X origin | Y origin |
|-----------------|---------|---------|
| (0,0) | 36pt | 36pt |
| (0,1) | 278pt | 36pt |
| (0,2) | 520pt | 36pt |
| (1,0) | 36pt | 218pt |
| (1,1) | 278pt | 218pt |
| (1,2) | 520pt | 218pt |
| (2,0) | 36pt | 400pt |
| (2,1) | 278pt | 400pt |
| (2,2) | 520pt | 400pt |

**Internal card padding:** 5pt on all sides (tighter than wristband to preserve diagram space at the smaller card size).

**Page count:** `ceil(selectedPlays.count / 9)`. For 9 plays → 1 page. For 10 plays → 2 pages (first page has 9, second has 1). The generator must not crash or leave blank-card artifacts for partial last pages — empty cells simply are not drawn.

### 4.2 Catalog card content layout

Within each cell (234pt × 174pt, padding 5pt on all sides; usable area 224pt × 164pt):

```
Row 1 — Play number + Formation (y: 5pt, height: ~16pt)
  Play number: left-aligned, 10pt bold
  Formation name: right-aligned, 10pt semibold

Row 2 — Route digits (y: ~23pt, height: ~14pt)
  Monospaced digit string, 9pt medium

Row 3 — Receiver labels (y: ~39pt, height: ~11pt)
  "X  Y  Z  A  H" (or subset for 4-digit plays), 8pt regular, monospaced

Row 4 — Concept + Motion (y: ~52pt, height: ~13pt, conditional)
  Concept name: left-aligned, 8pt semibold — omitted if nil
  Motion label: right-aligned, 8pt regular — omitted if nil
  If both nil: row absent (no blank space)

Divider (y: ~67pt)
  0.35pt hairline across usable width

Diagram zone (y: ~70pt to ~159pt, height: ~89pt)
  CGRect(x: 5pt, y: 70pt, width: 224pt, height: 89pt)
  DiagramRenderer.draw(into:playCall:config:in:) called here

(No notes line on catalog cards — omitted per spec NQ-5 default resolution)
```

**Font size rationale:** Catalog cards are smaller than wristband cards (174pt tall vs. 180pt tall for wristband, but 9-up vs. 4-up means much smaller per-card area). Fonts are reduced to 8–10pt to fit the required fields. These are printed sizes — at 300 dpi, 8pt is ~33 pixels, legible on a plain-paper printout held at normal reading distance. Catalog sheets are not laminated and are read at normal viewing distance (clipboard or tabletop), not arm's length like wristband cards, so the smaller font floor is acceptable.

### 4.3 `CatalogCardConfig` — value type (struct)

**Location:** `SpartansPlaycaller/Models/CatalogCardConfig.swift`

Analogous to the wristband `WristbandCardConfig`. Holds all layout constants for a 9-up catalog card.

```swift
struct CatalogCardConfig {
    let cardWidth: CGFloat = 234.0
    let cardHeight: CGFloat = 174.0
    let cardInset: CGFloat = 5.0
    let playNumberFontSize: CGFloat = 10.0
    let formationFontSize: CGFloat = 10.0
    let digitsFontSize: CGFloat = 9.0
    let receiverLabelFontSize: CGFloat = 8.0
    let conceptFontSize: CGFloat = 8.0
    let motionFontSize: CGFloat = 8.0
    let diagramZoneY: CGFloat = 70.0      // top of diagram zone within card
    let dividerY: CGFloat = 67.0
    let diagramLabelFontSize: CGFloat = 7.0

    static func standard() -> CatalogCardConfig { CatalogCardConfig() }
}
```

### 4.4 `CatalogPDFGenerator` — struct

**Location:** `SpartansPlaycaller/Services/CatalogPDFGenerator.swift`

```swift
struct CatalogPDFGenerator {
    /// Generate a catalog PDF from an ordered array of ExportCards.
    /// Returns nil if PDFKit returns nil data (internal PDFKit failure).
    /// Runs synchronously. Call from a background Task.
    static func generate(cards: [ExportCard]) -> Data?
}
```

Internal responsibilities:
1. Partition `cards` into pages of 9 (`cards.chunks(ofCount: 9)` or a manual stride).
2. For each page, instantiate a `CatalogPDFPage` subclass with the card slice, config, and precomputed cell origins.
3. Create a `PDFDocument`, set `documentAttributes` per REQ-SEC-1.
4. Add all pages to the document.
5. Return `PDFDocument.dataRepresentation()`.

### 4.5 `CatalogPDFPage` — PDFPage subclass

```swift
final class CatalogPDFPage: PDFPage {
    let cards: [ExportCard]         // 1–9 cards for this page
    let config: CatalogCardConfig
    let cellOrigins: [CGPoint]      // 9 origins; indices 0–8 map to grid positions

    override func draw(with box: PDFDisplayBox, to context: CGContext) {
        super.draw(with: box, to: context)
        // Flip coordinate system (PDF origin is bottom-left → screen-style top-left)
        let mediaBox = bounds(for: box)
        context.translateBy(x: 0, y: mediaBox.height)
        context.scaleBy(x: 1, y: -1)

        for (i, card) in cards.enumerated() {
            drawCard(card, origin: cellOrigins[i], into: context)
        }
    }

    private func drawCard(_ card: ExportCard, origin: CGPoint, into context: CGContext)
}
```

**Page media box:** Set to 792pt × 612pt (landscape US Letter).

**No cut guides on catalog pages.** Coaches read the catalog sheet whole; it is not cut. The cell borders (thin stroke around each card) serve as visual separators and do not require cut guides.

---

## 5. Wristband PDF Generator (updated — Story 3.2)

The wristband generator from the original spec is preserved with two changes: (a) it now accepts `[ExportCard]` instead of `[PlayCall]`, and (b) it supports multi-play export (one page per card, not one page total).

### 5.1 `WristbandCardConfig` — value type (struct)

**Location:** `SpartansPlaycaller/Models/WristbandCardConfig.swift`

Preserved from the original spec. No changes needed. (See original spec Section 2.1 for full constant table.)

**Card dimensions:** 252pt × 180pt (3.5" × 2.5" at 72pt/inch).

**Page:** US Letter portrait — 612pt × 792pt.

**Grid:** 2×2 — 4 identical copies of the same `ExportCard` per page.

**Grid layout math (preserved):**
- Margin: 18pt. Gutter: 9pt.
- Total width used: 2×252 + 9 + 2×18 = 549pt (fits 612pt). Centering offset: 31.5pt.
- Total height used: 2×180 + 9 + 2×18 = 405pt (fits 792pt). Centering offset: 193.5pt.
- Card origins (screen coords): (49.5, 211.5), (310.5, 211.5), (49.5, 400.5), (310.5, 400.5).

### 5.2 `WristbandPDFGenerator` — struct (updated signature)

**Location:** `SpartansPlaycaller/Services/WristbandPDFGenerator.swift`

```swift
struct WristbandPDFGenerator {
    /// Generate a wristband PDF from an ordered array of ExportCards.
    /// One PDF page per ExportCard; each page contains 4 identical copies.
    /// Runs synchronously. Call from a background Task.
    /// Returns nil if generation fails.
    static func generate(cards: [ExportCard]) -> Data?
}
```

**Multi-play behavior:**
- N cards → N PDF pages.
- Each page is a `WristbandPDFPage` subclass instance containing 4 copies of the same card.
- The page count matches the card count; no grid-packing across plays.
- `ExportCard.playNumber` appears on each card — sequential from the selection order in the export flow.

**Cut guides:** Thin hairline (0.25pt) at vertical and horizontal gutter center lines, drawn outside card borders within the gutter space. These are printing aids for physical card separation.

**Notes line:** One blank hairline rule with "Notes:" label at 8pt, at the card bottom edge. Present on wristband cards; absent on catalog cards.

**Wristband card internal layout:** Preserved from original spec Section 5. Uses `WristbandCardConfig` font sizes: play number 18pt bold, formation 14pt semibold, digits 14pt medium, receiver labels 9pt, concept 12pt semibold, motion 11pt, diagram ~40% of card area, notes rule at bottom.

---

## 6. DiagramRenderer Reuse Strategy

**Decision: Option B — PDFPage subclass with direct CGContext draw calls (vector path). Preserved from original spec.**

This decision is unchanged. The rationale:
- Vector paths produce resolution-independent output satisfying the 300 dpi print quality requirement unconditionally.
- `DiagramRenderer` already separates geometry computation from rendering context, so adding a CGContext draw method requires only a new extension, not refactoring of existing methods.
- The same `DiagramRenderer.draw(into:playCall:config:in:)` method serves both catalog and wristband generators — only the `DiagramConfig` parameters differ (reflecting the different diagram zone sizes).

### 6.1 What changes in `DiagramRenderer`

One new method added as an extension. No existing methods are modified.

```swift
extension DiagramRenderer {
    /// Draw the full route diagram into an arbitrary CGContext.
    /// Used by both CatalogPDFGenerator and WristbandPDFGenerator to produce
    /// vector diagram content inside PDFPage subclasses.
    ///
    /// - Parameters:
    ///   - context: The CGContext to draw into (from PDFKit's draw(with:to:) callback).
    ///   - playCall: The play call to render (must be the post-motion state).
    ///   - config: A DiagramConfig scaled for the specific card diagram zone.
    ///   - rect: The bounding rect in the context's coordinate system to draw within.
    func draw(into context: CGContext, playCall: PlayCall, config: DiagramConfig, in rect: CGRect)
}
```

The method uses `DiagramRenderer`'s existing geometry methods (`receiverPositions`, `routePath`, `motionPath`, `yWheelArcPath`) for all coordinate computation, then issues Core Graphics draw calls (`CGContext.addPath`, `CGContext.strokePath`, `CGContext.fillEllipse`, etc.).

### 6.2 Card-scale `DiagramConfig` factories

**Location:** `SpartansPlaycaller/Models/DiagramConfig+CardScale.swift`

Two factory methods — one per export mode:

```swift
extension DiagramConfig {
    /// DiagramConfig for wristband cards (diagram zone ~240pt × 72pt).
    static func wristbandCardScale(for diagramZoneSize: CGSize) -> DiagramConfig

    /// DiagramConfig for catalog cards (diagram zone ~224pt × 89pt).
    static func catalogCardScale(for diagramZoneSize: CGSize) -> DiagramConfig
}
```

**Wristband parameters** (preserved from original spec, Section 2.1):
- `lineOfScrimmageY: height * 0.50`
- `routeLength: height * 0.35`
- `breakLength: height * 0.25`
- `receiverRadius: 4.0`
- `footballSize: 6.0`
- `receiverSpacing: width * 0.14`
- `sideMargin: width * 0.06`

**Catalog parameters** (new — diagram zone is wider/taller than wristband zone proportionally):
- `lineOfScrimmageY: height * 0.50`
- `routeLength: height * 0.38`   (slightly more vertical room in the taller catalog zone)
- `breakLength: height * 0.28`
- `receiverRadius: 4.0`           (same minimum — lamination risk does not apply to plain paper, but 4pt is still a legibility floor)
- `footballSize: 6.0`
- `receiverSpacing: width * 0.13`  (catalog zone is wider relative to card; tighter spacing keeps receivers within frame)
- `sideMargin: width * 0.05`

Both parameter sets require Ken's visual sign-off during Story 3.3 (field validation). They are calibrated estimates based on zone dimensions, not pixel-tested values.

### 6.3 Coordinate system handling

**Preserved from original spec.** Both `CatalogPDFPage` and `WristbandPDFPage` flip the coordinate system at the start of their `draw(with:to:)` override:

```swift
context.translateBy(x: 0, y: mediaBox.height)
context.scaleBy(x: 1, y: -1)
```

This converts the PDF coordinate system (origin bottom-left, Y upward) to screen-style coordinates (origin top-left, Y downward), so all subsequent draw calls and `DiagramRenderer` geometry use consistent coordinates.

---

## 7. Export Flow (Dual Path)

Two export entry points coexist in V1. They converge on the same PDF generators.

### Path A — Quick Export (single play, no library)

1. Coach has a valid play call showing in `PlayCallerView` (formation + digits parsed, result section visible).
2. Coach taps the share icon in the nav bar trailing area.
3. The export action sheet appears. **If the current play has not been saved to the library:** the action sheet presents two primary options — "Export Current Play" (without saving) and "Save Play First" — plus Cancel. **If the current play is already in the library:** the action sheet presents "Export Current Play" directly.
4. On "Export Current Play": coach chooses mode (Catalog or Wristband).
5. `ExportCard.from(playCall:motion:playNumber:)` is called with `currentPlayCallWithMotion ?? currentPlayCall` and the ViewModel's `yMotion` state.
6. The appropriate generator is called (`CatalogPDFGenerator.generate(cards: [card])` or `WristbandPDFGenerator.generate(cards: [card])`).
7. `UIActivityViewController` is presented.

**NQ-6 resolution (export from PlayCallerView with unsaved play):** Path A allows exporting the current play without saving it to the library first. The action sheet communicates this clearly so the coach understands the play will not persist. This is the more permissive choice over "prompt to save first" — it respects a coach who wants a one-off quick export without accumulating library entries. The spec's recommended default was "prompt," but allowing export without saving is architecturally simpler and removes friction for the quick-export use case Ken confirmed is needed.

### Path B — Library Export (multi-play)

1. Coach taps "Save Play" in `PlayCallerView` (or builds multiple plays during the week, saving each).
2. Coach opens `PlayLibraryView` (accessible via a "Library" toolbar button in `PlayCallerView` — modal sheet presentation, per NQ-3 default).
3. Library view shows saved plays in a SwiftUI `List` with multi-select. "Select" toolbar button enables multi-select mode.
4. Coach selects plays (checkboxes, Select All button). Export button shows selection count ("Export 4 Plays").
5. Coach taps Export → format action sheet appears: "Play Catalog", "Wristband Cards", "Cancel".
6. On format selection:
   - For each selected `SavedPlay`, `ExportCard.from(savedPlay:playNumber:interpreter:)` is called in order.
   - The appropriate generator receives the `[ExportCard]` array.
   - PDF is generated on a background `Task`.
7. `UIActivityViewController` is presented.

**Selection ordering:** Plays are numbered in the order they are selected, not the order they appear in the list. If "Select All" is used, the order follows the list order (which is insertion order — newest last in V1).

**NQ-3 resolution (library entry point):** Modal sheet from a "Library" toolbar button in `PlayCallerView`. This avoids structural navigation changes in V1 (no `TabView`). The library is an accessory view, not a primary destination; the play-builder remains the main screen.

---

## 8. New View: PlayLibraryView

**Location:** `SpartansPlaycaller/Views/PlayLibraryView.swift`

**Navigation:** Presented as a modal sheet from `PlayCallerView`.

**Content:**
- SwiftUI `List` over `PlayLibraryStore.plays`, ordered by `savedAt` ascending (oldest first, newest last — coach builds the week's plays in order).
- Each row: formation name + route digits + concept name (if present) + motion label (if present). A compact one-line layout.
- **Empty state:** When `plays` is empty, a centered message: "No plays saved yet.\nBuild a play and tap Save Play."
- **Swipe-to-delete:** `.onDelete` modifier on the `ForEach` within the `List`; calls `store.delete(at:)`.
- **Multi-select mode:** Triggered by a "Select" `ToolbarItem`. When active, each row shows a checkmark or checkbox. The toolbar item label changes to "Done" to exit multi-select.
- **Export toolbar button:** In the toolbar when multi-select is active. Disabled when no plays are selected. Label: "Export \(selectedCount) Play\(selectedCount == 1 ? "" : "s")".
- **Export action sheet:** On Export button tap — "Play Catalog", "Wristband Cards", "Cancel".
- **Format selection → PDF generation spinner:** After format is chosen, button becomes non-interactive; a `ProgressView` replaces or overlays the Export label during generation.
- **Error handling:** On nil PDF result, dismiss spinner and present an alert: "Could not generate PDF. Please try again."

**UX note (NQ-5 resolved — catalog notes field omitted):** The catalog card layout does not include a notes rule. Space is tight at 9-up density; the notes line is a wristband-specific feature for player annotation on a physical card. Coaches reference catalog sheets but do not annotate individual cards.

---

## 9. ViewModel Changes

### 9.1 `PlayCallerViewModel` additions

```swift
// Already injected at init — add this dependency
private let libraryStore: PlayLibraryStore   // injected via environment or init parameter

// New computed property
var canSave: Bool {
    currentPlayCall != nil || currentPlayCallWithMotion != nil
}

// New method
func saveCurrentPlay() {
    guard let playCall = currentPlayCallWithMotion ?? currentPlayCall else { return }
    libraryStore.save(playCall, motion: yMotion, yWheelEnabled: yWheelEnabled)
    // Optional: brief UI confirmation (see SaveConfirmationState below)
}

// Export state additions (carried over from original spec)
@Published var isExporting: Bool = false
var canExport: Bool {
    currentPlayCallWithMotion != nil || currentPlayCall != nil
}
func exportCurrentPlay(mode: ExportMode) async
```

**`ExportMode` enum:**
```swift
enum ExportMode {
    case catalog
    case wristband
}
```

**`saveCurrentPlay()` confirmation:** The spec requires "brief visual confirmation (checkmark or brief 'Saved' label)." Implementation pattern: add a transient `@Published var saveConfirmed: Bool = false` property; set to `true` in `saveCurrentPlay()`, then reset to `false` after 1.5 seconds using a `Task.sleep`. The View shows a checkmark overlay or button label change while `saveConfirmed` is true.

**`PlayLibraryStore` injection:** The store is constructed once in the `@main` App struct and injected as an `@EnvironmentObject`. `PlayCallerViewModel` accesses it via `@EnvironmentObject` or as an init parameter. The architect recommends init-parameter injection for testability — the ViewModel can be constructed with a mock store in unit tests without environment setup.

### 9.2 `PlayLibraryViewModel` (selection state)

**Location:** Embedded as a private `@State` or a separate `@StateObject` class within `PlayLibraryView`, not a top-level ViewModel file.

Manages:
- `selectedIDs: Set<UUID>` — selected `SavedPlay` IDs in multi-select mode.
- `isInMultiSelectMode: Bool`
- `selectedPlays: [SavedPlay]` — computed from `selectedIDs` in `store.plays` order.
- `exportButtonEnabled: Bool` — `!selectedIDs.isEmpty`.

Because selection state is local to `PlayLibraryView` and never needs to outlive the sheet, embedding it as `@State` (or a simple `@StateObject`) in the view is appropriate. A top-level ViewModel class is not warranted.

---

## 10. Security Requirements

### Original requirements (carried forward unchanged)

#### REQ-SEC-1: Strip PDF document metadata

When creating any `PDFDocument` (catalog or wristband), set `documentAttributes` to include only the title attribute.

```swift
pdfDocument.documentAttributes = [
    PDFDocumentAttribute.titleAttribute: "\(formationName) \(routeDigits)"
]
```

For multi-play PDFs, the title can be: `"\(cards.count) Plays — \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none))"`. Do not set author, creator, subject, or keyword attributes.

**Verification:** `mdls` or `exiftool` on generated PDF confirms Author/Creator fields are absent. Title matches expected string.

#### REQ-SEC-2: Write temp file to `temporaryDirectory`

```swift
let tempDir = FileManager.default.temporaryDirectory
let filename = "\(UUID().uuidString)-\(sanitizedName)-\(mode).pdf"
let tempURL = tempDir.appendingPathComponent(filename)
```

For multi-play exports, `sanitizedName` can be `"\(cards.count)-plays"`. UUID prefix prevents collisions.

**Verification:** Assert temp URL begins with `NSTemporaryDirectory()` in development.

#### REQ-SEC-3: Apply file protection to temp file write

```swift
try data.write(to: tempURL, options: .completeFileProtection)
```

**Verification:** `FileManager.default.attributesOfItem(atPath:)[.protectionKey]` confirms `.complete` in a debug build.

#### REQ-SEC-4: Delete temp file in share sheet completion handler

```swift
activityVC.completionWithItemsHandler = { _, _, _, _ in
    try? FileManager.default.removeItem(at: tempURL)
}
```

Error path: if share sheet is never presented, delete temp file via `defer` block (see original spec Section 7 for the `shareSheetPresented` defer pattern — carry forward unchanged).

**Verification:** Confirm file does not exist at `tempURL` after share sheet dismissal.

### New requirement

#### REQ-SEC-5: Apply file protection to library JSON write

```swift
try encoder.encode(plays).write(to: fileURL, options: .completeFileProtection)
```

The library JSON file lives in the Documents directory (user-visible). File protection ensures it is encrypted at rest when the device is locked. This is consistent with the temp file protection and costs nothing.

**Verification:** `FileManager.default.attributesOfItem(atPath: fileURL.path)[.protectionKey]` confirms `.complete` in a debug build.

---

## 11. Performance Constraints

Carried forward from the original performance assessment, with additions for catalog and multi-play scenarios.

| Constraint | Value | Notes |
|-----------|-------|-------|
| Single diagram render | 13–40ms on iPhone 12+ | Per performance assessment |
| Catalog: 9 diagrams per page | 117–360ms | Within 500ms budget |
| Wristband: 1 play (4 diagram draws) | 52–160ms | 4 vector draw calls, no bitmap allocation |
| N-play wristband (N pages) | N × 13–40ms per diagram | Scales linearly; budget applies per page |
| Library read at init | <10ms for 200 entries | JSON decode of ~40KB is negligible |
| Library write per save/delete | <5ms | JSON encode + file write of ~40KB |
| Background dispatch | Required — `Task.detached(priority: .userInitiated)` | Both generators called from background Task |
| Main actor return | Automatic via `@MainActor` ViewModel | No explicit `MainActor.run` needed |
| Peak memory (catalog, 9 plays) | <5MB | Vector paths, no bitmap allocation |
| Peak memory (wristband, N plays) | <2MB per page rendered | Page-at-a-time generation; no full-document in-memory |
| Pre-generation / speculative generation | Prohibited | Generate only when coach confirms format |

**Large library consideration:** For libraries of 20–50 plays, `ExportCard` construction (parsing digit strings via `RouteInterpreter`) takes 100–750ms total. This is within the observable-but-acceptable range (less than 1 second for a 50-play selection). For V1, this is acceptable given the expected library size (10–20 plays per game plan). The implementing engineer should dispatch the entire export pipeline (card construction + generation) to the background Task — not just the PDF generation step — to keep the main thread free during card reconstruction.

---

## 12. State Isolation Strategy

This section documents how the three store/state domains interact without corrupting each other.

**Three state domains:**
1. `PlayCallerViewModel` — play builder state (formation, digits, parsed PlayCall, motion state).
2. `PlayLibraryStore` — persisted play library (array of `SavedPlay`).
3. Export pipeline — transient, in-flight PDF generation state.

**Isolation rules:**

- `PlayLibraryStore` is read-only from the export pipeline. Export reads `plays` but never modifies the store.
- `PlayCallerViewModel` is read-only from the save flow. `saveCurrentPlay()` reads ViewModel state and writes to the store; the store does not write back to the ViewModel.
- Export is a pure function: `CatalogPDFGenerator.generate(cards:)` and `WristbandPDFGenerator.generate(cards:)` take value types and return `Data?`. No shared mutable state. No `@Published` side effects.
- The only export-related state mutation in the ViewModel is `isExporting: Bool` — used only to show/hide the spinner and disable the button during generation. It does not affect `currentPlayCall`, `currentPlayCallWithMotion`, or any library state.
- Temp file lifecycle: created in background Task, passed to `UIActivityViewController`, deleted in completion handler regardless of action/cancel. No PDF file persists beyond the share sheet session.
- Library file lifecycle: written on every save/delete, read only at app init. No in-flight reads during export (the `plays` array is already in memory).
- `PlayCallerViewModel.reset()` clears play-builder state only; it does not touch the library store.

**Concurrency:** `PlayLibraryStore` is `@MainActor`. All mutations (`save`, `delete`, `deleteAll`, `persist`) run on the main actor, so no concurrent write conflicts are possible. The export pipeline reads `store.plays` once on the main actor (to build the `[SavedPlay]` array for export), then runs entirely in a detached background Task with value-type copies.

---

## 13. Data Flow

```
PATH A (Quick Export — no library):

1. [PlayCallerView] Coach taps share icon
        |
        v
2. [PlayCallerView] Export action sheet: "Export Current Play" / "Save Play First" / Cancel
        |
        v (coach taps "Export Current Play")
3. [PlayCallerView] Format action sheet: "Play Catalog" / "Wristband Cards" / Cancel
        |
        v (coach selects format)
4. [PlayCallerViewModel] Captures postMotionPlay = currentPlayCallWithMotion ?? currentPlayCall
   isExporting = true
        |
        v (detached background Task)
5. ExportCard.from(playCall: postMotionPlay, motion: yMotion, playNumber: 1)
        |
        v
6. CatalogPDFGenerator.generate(cards: [card]) OR WristbandPDFGenerator.generate(cards: [card])
   → Data?
        |
        v (return to @MainActor)
7. [PlayCallerViewModel] isExporting = false
   Write temp file with .completeFileProtection (REQ-SEC-2, REQ-SEC-3)
   Present UIActivityViewController
   completionHandler: delete temp file (REQ-SEC-4)

---

PATH B (Library Export — multi-play):

1. [PlayLibraryView] Coach selects plays, taps Export
        |
        v
2. [PlayLibraryView] Format action sheet: "Play Catalog" / "Wristband Cards" / Cancel
        |
        v (coach selects format)
3. [PlayLibraryView/ViewModel] isExporting = true
        |
        v (detached background Task)
4. For each selectedPlay (in selection order):
   ExportCard.from(savedPlay: play, playNumber: i, interpreter: RouteInterpreter())
   → [ExportCard]
        |
        v
5. CatalogPDFGenerator.generate(cards: exportCards) OR WristbandPDFGenerator.generate(cards: exportCards)
   → Data?
        |
        v (return to @MainActor)
6. isExporting = false
   Write temp file (REQ-SEC-2, REQ-SEC-3)
   Present UIActivityViewController
   completionHandler: delete temp file (REQ-SEC-4)
```

---

## 14. Open Questions

The following open questions from the product spec are now resolved. No blocking items remain for implementation planning.

| Question | Resolution | Source |
|----------|-----------|--------|
| NQ-1: Catalog density 6-up or 9-up? | **9-up (3×3)** | Ken confirmed |
| NQ-2: Catalog orientation landscape or portrait? | **Landscape** | Ken confirmed |
| NQ-3: Library entry point (modal sheet / tab / push)? | **Modal sheet** from "Library" toolbar button in `PlayCallerView` | Spec default; avoids TabView structural change |
| NQ-4: Duplicate play save handling? | **Save as new entry** — timestamps differentiate | Spec default |
| NQ-5: Catalog notes field? | **Omitted** — space is tight; catalog is a reference artifact | Spec default |
| NQ-6: Export from PlayCallerView with unsaved play? | **Allow export without saving** — action sheet communicates play won't persist | Architecture decision (less friction than forcing save) |
| OQ-1 (original): Post-motion vs pre-motion diagram? | **Post-motion** | Resolved in original spec; carried forward |
| OQ-2 (original): 4-up grid or single-card page? | **4-up 2×2 grid** | Resolved in original spec; carried forward |
| OQ-3 (original): Motion label format? | **"Y Stop" / "Y After" / "Y Go"** (ReceiverMotion.rawValue) | Resolved — raw values match display labels exactly |

**`PlayLibraryStore` injection pattern** is the only remaining design-level decision left to the implementing engineer: init parameter injection (recommended for testability) vs. `@EnvironmentObject` access (simpler wiring). Either is correct; the engineer should decide based on existing test patterns.

---

## 15. Risks and Mitigations

### Risk 1: Diagram legibility at catalog card scale (HIGH probability, MEDIUM impact)

Catalog cards are 234pt × 174pt — smaller than wristband cards — with a diagram zone of ~224pt × 89pt. Receiver dots at 4pt radius, route lines at 1pt stroke weight, and compressed vertical space may produce a diagram that is hard to read on a printed catalog sheet.

**Mitigation:** `DiagramConfig.catalogCardScale()` parameters are tunable independently of the wristband config. The implementing engineer should produce a one-page test PDF with real plays before implementing the full catalog generator. Ken's visual sign-off during Story 3.3 is the definitive legibility gate for catalog density. If the 9-up layout proves unreadable, the cell dimensions can shift to 6-up (3×2) without changing the generator's architecture — only `CatalogCardConfig` constants change.

**Validation (cheap):** Write a test that renders a `CatalogPDFPage` with 9 hardcoded `ExportCard` values, writes the PDF to the simulator's Documents directory, and opens it in Preview at 100% zoom. Confirm receiver dots and route breaks are visually distinct.

### Risk 2: `ExportCard` construction failure for corrupted `SavedPlay` entries (LOW probability, LOW impact)

If a saved `formationName` or `routeDigits` value does not parse (e.g., due to a future code change that removes a formation), `ExportCard.from(savedPlay:...)` returns nil. The export flow must handle this gracefully.

**Mitigation:** In the export pipeline, filter out nil `ExportCard` values before passing the array to the generator. If any cards failed to construct, log the failure and show a warning in the action sheet message: "X plays could not be loaded and will be skipped." Do not crash.

### Risk 3: Large library export latency (LOW probability, MEDIUM impact)

For 50 selected plays, card construction + diagram rendering may take 750ms–2s total — above the 500ms target. This is unlikely in practice (typical game-plan scripts are 10–20 plays) but possible.

**Mitigation:** The 500ms budget applies per page, not per export. For multi-page catalog exports, the constraint is "each page renders in <500ms" — which is satisfied at 9 plays/page. For the total generation time, a 2-second wait with a spinner is acceptable UX for a deliberate "export my game plan" action. No architectural change is needed; the background Task dispatch ensures the UI stays responsive during long generation.

### Risk 4: Toolbar crowding and `PlayCallerView` modifications (MEDIUM probability, LOW impact)

Adding a "Save Play" button and a "Library" button to the `PlayCallerView` toolbar alongside the existing "Share" and "Reset" buttons may cause layout crowding on iPhone SE (375pt width).

**Mitigation:** Use icon-only buttons throughout the toolbar trailing area. Recommended icons: `square.and.arrow.up` (share/export), `bookmark.fill` (save play), `books.vertical` (library), `arrow.counterclockwise` (reset). Four icon-only buttons in the trailing area fit within 375pt. Verify on SE simulator before merge.

### Risk 5: `PDFPage.string` returning nil in content tests (KNOWN — mitigated by test strategy)

Preserved from original spec. Text drawn via Core Graphics does not appear in `PDFPage.string` extraction. Both `CatalogPDFContentTests` and `WristbandPDFContentTests` must use geometry-based assertions (page count, media box dimensions, data validity). String extraction is not a valid test approach for vector-rendered PDFs.

### Risk 6: `applyMotion` logic duplication (LOW probability, LOW impact)

The motion application logic currently lives in `PlayCallerViewModel.applyMotion()`. `ExportCard.from(savedPlay:...)` needs to replicate this to reconstruct the post-motion `PlayCall`. If the two implementations diverge, catalog/wristband cards may render differently from the on-screen diagram.

**Mitigation:** Extract motion application to a static method on `PlayCall` (recommended in Section 3) during Story 3.0 implementation. Both the ViewModel and `ExportCard` construction then call the same code path. This is a low-complexity refactor that eliminates the divergence risk permanently.

---

## 16. Roles

| Role | Contribution | Phase |
|------|-------------|-------|
| Product Owner | Problem definition, acceptance criteria, Ken confirmation of NQ-1 and NQ-2 (9-up landscape), Story 3.3 field validation sign-off, backlog update | Steps 1, 13 |
| UX Designer | Library list view layout, Save Play button placement, multi-select flow, Export action sheet wording, accessibility on all new controls, modal sheet navigation | Step 2 consultation, Step 6 review |
| Security Engineer | REQ-SEC-1 through REQ-SEC-5, involvement assessment, post-implementation verification (metadata audit, file protection confirmation, temp file cleanup) | Steps 2, 10 |
| SDET | Test strategy update for library persistence, multi-select state, catalog layout geometry assertions, wristband layout geometry assertions, export E2E flow, share sheet cancel path, error path | Steps 4, 8 |
| Performance Engineer | Library read/write latency assessment, catalog PDF generation latency, wristband multi-page latency, ExportCard construction latency for large selections | Steps 4, 9 |
| Architecture & System Design | This document — component boundaries, `SavedPlay` DTO decision, `ExportCard` construction paths, dual export flow, state isolation, risk identification | Step 3 |
| Software Engineer | `SavedPlay`, `PlayLibraryStore`, `ExportCard`, `CatalogCardConfig`, `CatalogPDFGenerator`, `CatalogPDFPage`, updated `WristbandPDFGenerator`, `DiagramConfig+CardScale` additions, `PlayLibraryView`, `PlayCallerViewModel` additions, toolbar wiring | Step 6 |
| Auditor | Conformance review: spec AC vs shipped artifact, security requirements verified, test results reviewed | Step 11 |

---

## Self-Review Notes

**TBD/TODO check:** None. All sections that were open in the product spec (NQ-1 through NQ-6) are resolved. No placeholder text or deferred decisions remain.

**Internal contradictions checked:**

1. **`ReceiverMotion` cases:** The original spec referenced only `.stop` and `.after` (mapping to "Y Stop" and "Y Go"). The actual `ReceiverMotion.swift` defines three cases: `.stop` (rawValue "Y Stop"), `.after` (rawValue "Y After"), `.go` (rawValue "Y Go"). This spec stores `motion?.rawValue` directly in `SavedPlay.motionLabel`, so the three possible values are "Y Stop", "Y After", and "Y Go" — consistent with the source. The product spec's card content table shows "Y Stop" and "Y Go" as examples; "Y After" is also a valid label and will appear on cards when applicable.

2. **Catalog page dimensions:** 9-up landscape. The spec's NQ-1/NQ-2 are resolved as "9-up, landscape." The layout math in Section 4.1 produces 234pt × 174pt cells — smaller than wristband cards (252pt × 180pt) but with less whitespace overhead (tighter gutter and inset). The font sizes (8–10pt) are below the wristband minimums (9–18pt) — this is appropriate because catalog sheets are read at normal viewing distance, not arm's length.

3. **`WristbandPDFGenerator` signature change:** The original spec's generator accepted `[PlayCall]`. This spec updates it to accept `[ExportCard]`. This is a breaking change to the interface but no other code currently calls this generator (it is new). The implementing engineer should define `WristbandPDFGenerator.generate(cards:)` from the start — not implement the original `generate(playCalls:)` and then update it.

4. **Temp file naming for multi-play exports:** The original REQ-SEC-2 specified a human-readable filename including formation and digits. For multi-play exports, there is no single formation/digits pair. Resolution (in Section 10): use `"\(cards.count)-plays"` as the human-readable segment. Example: `"A1B2C3D4-9-plays-catalog.pdf"`.

5. **`applyMotion` in `ExportCard.from(savedPlay:...)`:** The pseudocode in Section 3 calls `applyMotion(motion, to: playCall)` as a free function. This function does not exist yet. The implementing engineer must either (a) extract the motion logic from `PlayCallerViewModel` into a static `PlayCall` method (recommended), or (b) duplicate the logic inline in `ExportCard` with a backlog comment. The spec recommends (a) — document the decision explicitly in the implementation plan.

**Hardest trade-off driven by which requirement:** The `SavedPlay` DTO decision (Section 2.1) is driven by the boundary integrity requirement: keeping persistence concerns out of the `PlayCall` model. Making `PlayCall` Codable is technically feasible but blends concerns — the model layer gains a persistence responsibility that belongs to the service layer. The DTO approach is stricter but requires re-parsing at export time. The extra 5–15ms per play at export time is the price, and the performance budget comfortably absorbs it.

**What would invalidate this design:**

- If `RouteInterpreter.interpret()` is not deterministic (same digits + formation always produce the same assignments), then `ExportCard` reconstruction from `SavedPlay` would be unreliable. Confidence: HIGH that it is deterministic — it is a pure function over digit strings and enum inputs.
- If Apple's PDFKit `PDFPage` subclass draw mechanism produces different results between iOS 17 point releases (unlikely but possible with framework regressions). Fallback: `UIGraphicsImageRenderer` + embedded bitmap at 4x scale (Option A from original spec). Flag this only if PDFKit regression is observed.
- If Ken's legibility review of the 9-up catalog layout determines the font sizes (8–10pt) are too small for sideline use. In that case, fall back to 6-up (3×2) — changes only `CatalogCardConfig` constants and the page count formula; the generator architecture is unaffected.

**Cheap validation for catalog layout:** Before implementing the full generator, write a test that constructs a `CatalogPDFPage` with 9 hardcoded `ExportCard` values (all fields populated, including Y Wheel), writes the PDF to the simulator Documents directory, and visually inspects in Preview at 100% zoom. This 30–60 minute exercise catches the majority of coordinate-flip, cell-positioning, and font-size bugs before integration with the ViewModel and library.
