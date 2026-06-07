# Architecture Design Spec: Epic 3.1 — Wristband Export

**Date:** 2026-06-07
**Author:** Architecture & System Design
**Status:** READY FOR IMPLEMENTATION PLAN
**Spec reference:** `docs/superpowers/specs/2026-06-07-wristband-export-spec.md`
**UX reference:** `docs/superpowers/specs/2026-06-07-wristband-export-ux-consultation.md`
**Security reference:** `docs/superpowers/specs/2026-06-07-wristband-export-security-consultation.md`
**Test strategy:** `docs/test-plans/wristband-export-test-strategy.md`
**Performance assessment:** `docs/test-plans/wristband-export-performance-assessment.md`

---

## 1. Overview

Wristband Export converts the Spartans Playcaller from a play-design tool into a game-day coaching system by producing a printable PDF wristband card from any play currently displayed on screen. When a coach taps the share button, the app captures the current play call state (formation, route digits, concept if matched, Y motion if applied, Y Wheel if enabled), generates a US Letter PDF containing a 2x2 grid of four identical wristband cards (each 3.5"x2.5" with a mini route diagram), and hands that PDF to the iOS system share sheet — enabling AirPrint, Save to Files, email, and AirDrop with zero additional infrastructure. The pipeline is entirely on-device, synchronous within a background `Task`, and leaves no persistent state behind. In V1 the exported card always represents the single currently-displayed play; multi-play selection and play persistence are out of scope and must not be conflated with this feature.

---

## 2. Architecture

### 2.1 New Components

#### `WristbandCard` (value type — struct)

**Location:** `SpartansPlaycaller/Models/WristbandCard.swift`

A pure data model representing the content of one wristband card. Constructed from a `PlayCall` by `WristbandPDFGenerator`. Holds no references to views or renderers.

```
WristbandCard {
    playNumber: Int            // V1: always 1; V2: sequential from selection order
    formationName: String      // PlayCall.formation.rawValue
    routeDigits: String        // PlayCall.routeDigits (raw digit string, e.g. "6794")
    receiverLabels: [String]   // Fixed: ["X", "Y", "Z", "A", "H"] — always 5 labels
    conceptName: String?       // PlayCall.concept?.rawValue; nil when no concept matched
    motionLabel: String?       // nil when no Y motion; "Y Stop" / "Y Go" when present
    playCall: PlayCall         // Retained for diagram rendering; not displayed as text
}
```

Invariants:
- `conceptName` is nil (never an empty string) when `PlayCall.concept == nil`
- `motionLabel` is nil (never an empty string) when no Y motion is applied
- `receiverLabels` is always the full 5-element array regardless of how many receivers the formation uses; unused positions are printed but may be visually subdued (implementation detail)
- `playCall` carries `yWheelEnabled` and any motion-applied assignments; it is the post-motion state

**Y Motion label mapping (resolved):**
- `ReceiverMotion.stop` → `"Y Stop"`
- `ReceiverMotion.after` (Go) → `"Y Go"`
- `nil` → `motionLabel = nil` (no field rendered on card)

**Play number (resolved):**
- V1: always `1`. The field is parameterizable so V2 multi-select can pass any integer. A nil/blank option is not implemented in V1 — the number `1` prints. Ken may hand-annotate a different number if needed.

#### `WristbandCardConfig` (value type — struct)

**Location:** `SpartansPlaycaller/Models/WristbandCardConfig.swift`

Layout constants for a single card. All measurements are in PDF points (1 pt = 1/72 inch). Computed once and shared across all four cells in the 4-up grid.

```
WristbandCardConfig {
    // Card outer dimensions (matching physical 3.5" x 2.5" at 72 dpi)
    cardWidth: CGFloat = 252.0    // 3.5" x 72 pt/in
    cardHeight: CGFloat = 180.0   // 2.5" x 72 pt/in

    // Internal margins
    cardInset: CGFloat = 6.0      // ~0.083" inset on all sides

    // Text zone: from top inset to divider line
    textZoneHeight: CGFloat       // cardHeight * 0.60 = 108.0 pt

    // Diagram zone: below divider, to bottom inset
    diagramZoneHeight: CGFloat    // cardHeight * 0.40 = 72.0 pt

    // Diagram zone rect (origin relative to card origin)
    diagramZoneRect: CGRect       // x=cardInset, y=textZoneHeight, width=cardWidth-2*cardInset, height=diagramZoneHeight-cardInset

    // Font sizes (points at 72 dpi — equivalent to printed pt size)
    playNumberFontSize: CGFloat = 18.0
    formationFontSize: CGFloat = 14.0
    digitsFontSize: CGFloat = 14.0
    receiverLabelFontSize: CGFloat = 9.0
    conceptFontSize: CGFloat = 12.0
    motionFontSize: CGFloat = 11.0
    notesLabelFontSize: CGFloat = 8.0
    diagramLabelFontSize: CGFloat = 8.0

    // DiagramConfig parameters for card scale
    diagramConfig: DiagramConfig   // see Section 2.1 DiagramConfig factory below
}
```

`WristbandCardConfig` exposes a single static factory:

```swift
static func cardScale() -> WristbandCardConfig
```

This is the only `WristbandCardConfig` instance used in V1. The factory encapsulates all the point-size constants so the implementing engineer has one authoritative source of truth.

#### Card-Scale `DiagramConfig` Factory

**Location:** Extension on `DiagramConfig` in `SpartansPlaycaller/Models/DiagramConfig+CardScale.swift` (new file, or added to `DiagramRenderer.swift` as a static method)

The existing `DiagramConfig.standard(for:)` is parameterized for a ~320pt tall on-screen canvas with a `receiverRadius` of 12pt. At card scale the diagram zone is approximately 240pt wide x 58pt tall (at 72 dpi for the diagram zone within `WristbandCardConfig`). Receiver dots at 12pt radius would overflow the zone.

The card-scale factory produces:

```swift
static func cardScale(for diagramZoneSize: CGSize) -> DiagramConfig {
    let width = diagramZoneSize.width
    let height = diagramZoneSize.height
    return DiagramConfig(
        fieldWidth: width,
        fieldHeight: height,
        lineOfScrimmageY: height * 0.50,   // LOS at vertical midpoint (zone is landscape)
        routeLength: height * 0.35,
        breakLength: height * 0.25,
        receiverRadius: 4.0,               // 4pt radius for legibility at card scale
        footballSize: 6.0,
        receiverSpacing: width * 0.14,
        sideMargin: width * 0.06
    )
}
```

Rationale for parameter changes from `standard()`:
- `lineOfScrimmageY` moves from 60% to 50% of height: the diagram zone is landscape (wide and shallow), so centering the LOS vertically gives equal space above and below for route paths and receiver alignment.
- `routeLength` reduced to 35% of height (was 25% of a tall canvas): preserves route visibility in a compressed vertical space.
- `breakLength` reduced to 25% of height for the same reason.
- `receiverRadius` reduced to 4pt: the UX consultation specifies approximately 4-5pt; 4pt is the floor above which dots remain visible after lamination.
- `receiverSpacing` narrowed from 16% to 14% of width: card zone is narrower in proportion to the number of receivers.
- `sideMargin` narrowed from 8% to 6% of width: consistent with narrower receiver spacing.

These parameters must be validated visually by Ken during Story 3.1.5. They are calibrated estimates, not pixel-perfect values.

#### `WristbandPDFGenerator` (struct)

**Location:** `SpartansPlaycaller/Services/WristbandPDFGenerator.swift`

The central service. Takes a `[PlayCall]` array and produces a `Data` value containing a valid PDF. Accepts an array even in V1 (which always passes a single-element array) so V2 multi-play export requires no signature change.

```swift
struct WristbandPDFGenerator {
    /// Generate a wristband PDF from one or more play calls.
    /// V1: array always contains exactly one element.
    /// V2: array contains selected plays; four cards per PDF page.
    ///
    /// Runs synchronously. Call from a background Task.
    /// Returns nil if generation fails (e.g., PDFKit returns nil data).
    static func generate(playCalls: [PlayCall]) -> Data?
}
```

Internal responsibilities (in order of execution):
1. Map each `PlayCall` to a `WristbandCard` using the Y motion and concept state already embedded in the `PlayCall`.
2. Instantiate `WristbandCardConfig.cardScale()`.
3. Compute the 4-up page layout (see Section 5).
4. For each unique `PlayCall` in the array, render one diagram image using `DiagramRenderer`'s CGContext draw method (see Section 4). In V1 this is one render call; the same image is positioned in all four cells.
5. Create a `PDFDocument`, add a single `PDFPage` subclass instance that draws all four cards.
6. Set `documentAttributes` per REQ-SEC-1.
7. Return `PDFDocument.dataRepresentation()`.

**Error boundary:** If `PDFDocument.dataRepresentation()` returns nil, `generate` returns nil. The caller (ViewModel) catches nil and presents an error alert. The generator does not throw — it returns Optional to keep the call site simple and avoid force-unwrap patterns in the ViewModel.

#### Share Coordinator (ViewModel method + View wiring)

The share coordinator is not a separate type. It lives as two additions to existing types:

- `PlayCallerViewModel.exportCurrentPlay()` — async method that dispatches PDF generation to a background `Task`, manages `isExporting` state, writes the temp file, presents `UIActivityViewController` via a UIKit bridge, and cleans up.
- `PlayCallerView` — adds the share button to `.toolbar`, observes `viewModel.isExporting` for the spinner, presents the action sheet using `.confirmationDialog`.

No separate coordinator object is warranted: the share flow is a single linear sequence with no branching state machine complex enough to justify its own type.

### 2.2 Modified Components

#### `DiagramRenderer` — new `draw(into:playCall:config:)` method

See Section 4 for the full justification. In summary: a new method is added that accepts a `CGContext` and issues Core Graphics draw calls using the existing geometry methods. The existing API surface is untouched.

#### `PlayCallerViewModel` — two additions

```swift
// Computed property — no new @Published state needed
var canExport: Bool {
    currentPlayCallWithMotion != nil || currentPlayCall != nil
}

// Export state — drives spinner and disables button during generation
@Published var isExporting: Bool = false

// Entry point called by the View's "Export as PDF" action sheet option
func exportCurrentPlay() async
```

`exportCurrentPlay()` logic:
1. Guard `canExport == true` (defensive; button should already be disabled).
2. Capture `playCall = currentPlayCallWithMotion ?? currentPlayCall` (post-motion preferred).
3. Set `isExporting = true`.
4. In a detached `Task` with `.userInitiated` priority: call `WristbandPDFGenerator.generate(playCalls: [playCall])`.
5. On return to `@MainActor`: set `isExporting = false`.
6. On nil result: set `errorMessage = "Could not generate wristband. Please try again."`. Return.
7. On success: write temp file (REQ-SEC-2, REQ-SEC-3), present `UIActivityViewController` (REQ-SEC-4).

The `reset()` method needs no modification — resetting `currentPlayCall` and `currentPlayCallWithMotion` to nil makes `canExport` false automatically.

#### `PlayCallerView` — toolbar and action sheet additions

```swift
// Toolbar: replace single ToolbarItem with ToolbarItemGroup
ToolbarItemGroup(placement: .topBarTrailing) {
    // Share button (left of Reset per UX consultation Section 2.1)
    Button {
        showExportActionSheet = true
    } label: {
        if viewModel.isExporting {
            ProgressView().controlSize(.small)
        } else {
            Image(systemName: "square.and.arrow.up")
        }
    }
    .disabled(!viewModel.canExport || viewModel.isExporting)
    .opacity(viewModel.canExport ? 1.0 : 0.35)
    .accessibilityLabel("Export wristband card")
    .accessibilityHint("Exports the current play as a printable PDF")
    .accessibilityValue(viewModel.canExport ? "" : "Unavailable — no play call loaded")

    Button("Reset", action: viewModel.reset)
        .font(.subheadline)
}

// State
@State private var showExportActionSheet = false

// confirmationDialog modifier on NavigationStack or ScrollView
.confirmationDialog(
    "Export Wristband Card",
    isPresented: $showExportActionSheet,
    titleVisibility: .visible
) {
    Button("Export as PDF") {
        Task { await viewModel.exportCurrentPlay() }
    }
    Button("Cancel", role: .cancel) { }
} message: {
    if let playCall = viewModel.currentPlayCallWithMotion ?? viewModel.currentPlayCall {
        Text(playCall.displayName)   // "Twins 6794" — resolved open question OQ-3 default
    }
}
```

**UIActivityViewController presentation:** SwiftUI has no native wrapper for `UIActivityViewController`. Use `UIApplication.shared.connectedScenes` to find the active `UIWindowScene` and present from its `rootViewController`. This is the standard UIKit bridge pattern for this class.

---

## 3. Data Flow

The full pipeline from coach tap to share sheet, with component boundaries:

```
1. [PlayCallerView] Coach taps share icon in nav bar trailing area
        |
        v
2. [PlayCallerView] .confirmationDialog presents action sheet
   Title: "Export Wristband Card"
   Message: viewModel.currentPlayCallWithMotion?.displayName ?? viewModel.currentPlayCall?.displayName
        |
        v (coach taps "Export as PDF")
3. [PlayCallerView] Task { await viewModel.exportCurrentPlay() }
        |
        v
4. [PlayCallerViewModel] Captures playCall = currentPlayCallWithMotion ?? currentPlayCall
   Sets isExporting = true (View immediately shows spinner on share button)
        |
        v (dispatched to background Task, .userInitiated priority)
5. [WristbandPDFGenerator] generate(playCalls: [playCall])
   5a. Maps PlayCall → WristbandCard (motion labels, concept name, play number)
   5b. Instantiates WristbandCardConfig.cardScale()
   5c. Calls DiagramRenderer.draw(into:playCall:config:) → diagram drawn into PDF CGContext
   5d. Draws text fields (play number, formation, digits, concept, motion) into CGContext
   5e. PDFDocument.dataRepresentation() → Data
        |
        v (returns Data to @MainActor)
6. [PlayCallerViewModel] isExporting = false
   Writes Data to FileManager.temporaryDirectory/[UUID]-[formation]-[digits]-wristband.pdf
   with .completeFileProtection option (REQ-SEC-2, REQ-SEC-3)
        |
        v
7. [PlayCallerViewModel] Sets documentAttributes on PDFDocument (REQ-SEC-1)
   NOTE: attributes are set before dataRepresentation() in Step 5e, not here —
         this annotation clarifies the intent; see Section 7 for exact placement.
        |
        v
8. [PlayCallerViewModel] Presents UIActivityViewController(activityItems: [tempFileURL])
   completionWithItemsHandler: { try? FileManager.default.removeItem(at: tempURL) } (REQ-SEC-4)
        |
        v
9. [iOS System] UIActivityViewController handles: AirPrint / Save to Files / Email / AirDrop
        |
        v
10. [PlayCallerViewModel] completionHandler fires → temp file deleted
    isExporting remains false; app state is unchanged
```

**Data objects crossing component boundaries:**
- Step 4→5: `PlayCall` struct (value type, copied)
- Step 5→6: `Data` value (PDF bytes)
- Step 6→8: `URL` to temp file (passed by value)
- No play-caller state is mutated by the export pipeline. `currentPlayCall`, `currentPlayCallWithMotion`, formation, digits — all unchanged after export completes.

---

## 4. DiagramRenderer Reuse Strategy

### Decision: Option B — PDFPage subclass with direct CGContext draw calls (vector path)

**Rationale:**

The existing `DiagramRenderer` is a pure geometry struct — its methods compute `[CGPoint]` arrays and `Path` values but perform no rendering themselves. All actual drawing occurs in `RouteDiagramView` via SwiftUI `Canvas`. This means `DiagramRenderer` already has a clean separation between geometry computation and render context.

The relevant question is therefore not "can we reuse the exact draw logic" — the draw logic lives in the view, not in `DiagramRenderer`. The question is: "what is the least disruptive way to produce an equivalent rendered diagram in a PDF context?"

**Option A (UIGraphicsImageRenderer + embedded bitmap):**
- Requires a new CGContext-based draw implementation regardless — the SwiftUI Canvas draw calls in `RouteDiagramView` are not callable from a `UIGraphicsImageRenderer` context.
- Produces a raster image embedded in the PDF. At 2x scale the bitmap is ~504x144px for the diagram zone, which PDFKit serializes as a compressed image stream. The image is finite-resolution — if the coach zooms the PDF in Preview before printing, it will show pixelation (though not at normal viewing distances).
- The performance assessment's 300 dpi print quality goal is met at 2x scale (72 dpi logical × 2 = 144 effective dpi in the PDF, below 300 dpi print standard). To reach 300 dpi equivalent the scale factor would need to be ~4.17x, increasing bitmap size and compression cost.
- Simpler implementation path for the engineer writing the PDF page draw code, but the quality ceiling is lower.

**Option B (PDFPage subclass + direct CGContext):**
- Also requires new CGContext-based draw code — the same implementation effort as Option A.
- Produces a true vector PDF: every route line, receiver dot, and arc is a scalable `CGPath`. The PDF renders at full printer DPI regardless of zoom or print scale. This directly satisfies the spec's "300 dpi minimum equivalent" requirement without any bitmap resolution arithmetic.
- Eliminates the intermediate bitmap allocation entirely (~700KB at 2x, per performance assessment Section 4). No bitmap means no compression cost — the CGPath streams serialize faster.
- The SDET's note that `PDFPage.string` extraction fails for Core Graphics text is a known limitation already documented in the test strategy (Section 5.5). The prescribed mitigation is geometry-based assertions in `WristbandPDFContentTests`. This is not a blocking concern — the assertions remain valid and the test coverage is equivalent.
- No change to `RouteDiagramView` or its existing Canvas draw path. The new CGContext code lives only in `WristbandPDFGenerator` and a `DiagramRenderer` extension.

**Performance engineer alignment:** The performance assessment explicitly recommends the vector path (Section 5.4): "The direct CGContext (vector PDF) path is preferred if architecture approves the draw-call adaptation. It eliminates the intermediate bitmap entirely, reducing memory allocation and compression cost."

**Selected approach: Option B.**

### What changes in `DiagramRenderer`

A new method is added. No existing methods are modified or removed. All 18 existing test files remain unaffected because no existing API surface changes.

```swift
extension DiagramRenderer {
    /// Draw the full route diagram into an arbitrary CGContext.
    /// Used by WristbandPDFGenerator to produce vector diagram content
    /// inside a PDFPage subclass. The CGContext is provided by PDFKit's
    /// draw(with:to:) callback.
    ///
    /// - Parameters:
    ///   - context: The CGContext to draw into (from PDFKit or UIGraphicsImageRenderer).
    ///   - playCall: The play call to render (should be post-motion state).
    ///   - config: A DiagramConfig scaled for the card diagram zone.
    ///   - rect: The bounding rect in the context's coordinate system to draw within.
    func draw(into context: CGContext, playCall: PlayCall, config: DiagramConfig, in rect: CGRect)
}
```

This method replicates the drawing logic from `RouteDiagramView`'s `Canvas` block using Core Graphics primitives (`CGContext.addPath`, `CGContext.strokePath`, `CGContext.fillEllipse`, `CGContext.setStrokeColor`, etc.). It uses `DiagramRenderer`'s existing geometry methods (`receiverPositions`, `routePath`, `motionPath`, `yWheelArcPath`) to compute all coordinates, then issues CGContext draw calls.

**Text labels in the diagram (receiver dots labeled X/Y/Z/A/H):** Use `NSAttributedString` drawn via `CTFramesetter` or `NSString.draw(in:withAttributes:)` in the CGContext. This is the standard Core Graphics text pattern. These labels will NOT appear in `PDFPage.string` extraction (per SDET caveat in test strategy Section 5.5) — they are Core Graphics text primitives, not PDFKit text objects. The test strategy already accounts for this with geometry-based assertions.

**Regression protection:** `DiagramRendererOffScreenTests.swift` (new test file per SDET Section 8) will call `DiagramRenderer.draw(into:playCall:config:in:)` with a `UIGraphicsImageRenderer`-backed context to verify the method produces non-crashing output. Existing tests in `DiagramRendererWheelRenderingTests.swift`, `DiagramRendererYWheelTests.swift`, and all Y Wheel test files remain untouched.

### What the `WristbandPDFPage` subclass does

```swift
final class WristbandPDFPage: PDFPage {
    let cards: [WristbandCard]
    let config: WristbandCardConfig
    let cardOrigins: [CGPoint]    // precomputed from page layout (Section 5)

    override func draw(with box: PDFDisplayBox, to context: CGContext) {
        super.draw(with: box, to: context)
        // Flip coordinate system (PDF origin is bottom-left; CG draws top-left)
        let mediaBox = bounds(for: box)
        context.translateBy(x: 0, y: mediaBox.height)
        context.scaleBy(x: 1, y: -1)

        for (i, card) in cards.enumerated() {
            drawCard(card, origin: cardOrigins[i], into: context)
        }
    }

    private func drawCard(_ card: WristbardCard, origin: CGPoint, into context: CGContext) {
        // 1. Draw card border (thin stroke rect)
        // 2. Draw text fields (play number, formation, digits, labels, concept, motion)
        // 3. Draw horizontal divider between text zone and diagram zone
        // 4. Draw mini diagram via DiagramRenderer.draw(into:playCall:config:in:)
        // 5. Draw notes rule line at card bottom
    }
}
```

**Coordinate system note:** PDFKit's `draw(with:to:)` provides a CGContext in PDF coordinate space (origin bottom-left, Y increases upward). The diagram renderer and layout math use screen coordinates (origin top-left, Y increases downward). The single coordinate flip (`translateBy` + `scaleBy`) at the start of `draw(with:to:)` converts the entire context to screen-style coordinates, so all subsequent draw calls use the same coordinate system as `DiagramRenderer`.

---

## 5. PDF Layout (4-Up Grid)

### Page dimensions

US Letter portrait: 612pt x 792pt (8.5" x 11" at 72pt/inch).

**Rationale for portrait over landscape:** A 2x2 grid of 3.5"x2.5" cards fits cleanly on both orientations, but portrait is the standard print orientation for coaches printing a single sheet. Portrait also ensures the iOS print dialog defaults to the expected orientation without the coach needing to rotate.

### Grid layout algorithm

```
Page margin (all sides): 0.25" = 18pt
Gutter between cards (horizontal and vertical): 0.125" = 9pt

Card width:  3.5" = 252pt
Card height: 2.5" = 180pt

Total width used:  2 * 252 + 1 * 9 + 2 * 18 = 549pt  (fits in 612pt)
Total height used: 2 * 180 + 1 * 9 + 2 * 18 = 405pt  (fits in 792pt)

Horizontal centering offset: (612 - 549) / 2 = 31.5pt
Vertical centering offset:   (792 - 405) / 2 = 193.5pt
(centering places the grid visually centered on the page, with more blank space above and below)
```

**Card origins (top-left corner of each card, in screen coordinates after coordinate flip):**

```
Cell [0,0] — top-left card:
    x = 31.5 + 18 = 49.5pt
    y = 193.5 + 18 = 211.5pt

Cell [0,1] — top-right card:
    x = 49.5 + 252 + 9 = 310.5pt
    y = 211.5pt

Cell [1,0] — bottom-left card:
    x = 49.5pt
    y = 211.5 + 180 + 9 = 400.5pt

Cell [1,1] — bottom-right card:
    x = 310.5pt
    y = 400.5pt
```

**V1 behavior:** All four cells render the same `WristbandCard`. The card is computed once from the single `PlayCall` in the array; the same `WristbandCard` value is passed to `drawCard` four times with different origin points. The diagram is drawn by calling `DiagramRenderer.draw(into:...)` once per cell (four total calls). Because the diagram is vector paths written directly into the PDF context, there is no bitmap to cache — each draw call is fast (geometry computation + path stroking) and produces identical vector content at each cell position.

**V2 compatibility:** The layout algorithm takes `[WristbandCard]` as input. When the array contains more than 4 elements, the generator adds additional PDF pages, filling each page with 4 cards. The card origins array is computed per-page. No V2-specific implementation is required in V1 — only that the generator function signature accepts `[PlayCall]` (already specified) and that the layout function is written as a loop over pages, not as a hardcoded 4-position array.

### Card internal layout

Within each card rect (origin at card top-left, size 252pt x 180pt):

```
Inset on all sides: 6pt

Row 1 — Play number + Formation name (y: inset = 6pt, height: ~22pt)
  Play number: left-aligned at (inset, inset), font 18pt bold
  Formation name: right-aligned at (cardWidth - inset, inset), font 14pt semibold

Row 2 — Route digits (y: ~30pt, height: ~20pt)
  Monospaced digit string, left-aligned at (inset, 30pt), font 14pt medium

Row 3 — Receiver labels (y: ~52pt, height: ~14pt)
  "X   Y   Z   A   H", monospaced, left-aligned at (inset, 52pt), font 9pt regular
  Spacing matches digit column widths above

Row 4 — Concept + Y Motion (y: ~68pt, height: ~18pt, conditional)
  Concept name: left-aligned at (inset, 68pt), font 12pt semibold — omitted if nil
  Y Motion label: right-aligned at (cardWidth - inset, 68pt), font 11pt — omitted if nil
  If both nil: this row is absent (no blank space reserved)

Divider line (y: ~90pt)
  Thin horizontal rule at 40% of card height (0.5pt stroke weight)
  Spans full card width minus insets

Diagram zone (y: 90pt to 168pt, height: ~78pt)
  CGRect(x: inset, y: 90pt, width: cardWidth - 2*inset, height: 78pt - inset)
  DiagramRenderer.draw(into:playCall:config:in:) called with this rect

Notes line (y: ~170pt — 10pt from bottom)
  Single hairline rule across full card width minus insets
  "Notes:" label at 8pt, left-aligned, 2pt above the rule
```

**Note on row 4 spacing:** When concept and/or motion are absent, rows below do not reflow — the divider and diagram zone maintain their fixed y positions. Only the conditional row's text is omitted; the vertical rhythm is preserved. This avoids layout recalculation and ensures the diagram always occupies a predictable zone.

### Cut guides

The spec's 0.25" page margin and 0.125" gutter mean the grid sits flush with simple cut lines. The implementation should draw a thin (0.25pt) cut guide line at the vertical center of the gutter (between cards) and at the horizontal center of the gutter. These are cosmetic printer aids, not part of the card content. Cut guide lines are drawn outside the card rect, within the gutter space.

---

## 6. State Isolation Strategy

This is an iOS app with no IaC or multi-environment concern. This section documents state isolation in the coaching-workflow sense: how the export pipeline interacts with (or more precisely, does not interact with) the play-caller state.

**Export state is fully isolated from play-caller state:**

1. `WristbandPDFGenerator.generate(playCalls:)` is a pure function — it takes value-type inputs (`[PlayCall]`) and returns `Data?`. It holds no mutable state, writes no properties, and touches no `@Published` values. It cannot corrupt ViewModel state regardless of where it is called from.

2. The only state mutation during an export is `isExporting: Bool` in `PlayCallerViewModel`. This property is read only by the View (to show/hide the spinner and disable the button) and is reset to `false` on both success and failure paths. It does not affect `currentPlayCall`, `currentPlayCallWithMotion`, `selectedFormation`, or any other play-caller state.

3. The temp file written to `FileManager.temporaryDirectory` is ephemeral and scoped to the share sheet session. It is deleted in `UIActivityViewController.completionWithItemsHandler` regardless of whether the coach completed a share action or cancelled. If PDF generation fails before the share sheet is presented, the temp file is deleted in the error-handling path using a `defer` block. No PDF file persists to the Documents directory, iCloud, or any user-visible location.

4. Play persistence (saving a play to a database or file for later recall) is explicitly out of scope for Epic 3.1. The export pipeline never writes to the app's persistent storage. The `PlayCall` struct is used only as the data source for PDF rendering; its fields are read but never modified.

5. Cancellation: if the coach taps Cancel in the `confirmationDialog`, `exportCurrentPlay()` is never called — no `Task` is dispatched, no state changes beyond `showExportActionSheet = false`. If the coach cancels the share sheet after PDF generation, the completion handler fires and deletes the temp file. `isExporting` is already `false` at this point (set before `UIActivityViewController` is presented).

**Fire-and-forget semantics:** `exportCurrentPlay()` is `async` and is called from the View with `Task { await viewModel.exportCurrentPlay() }`. The Task is not retained or cancelled by the View. If the coach navigates away (impossible in V1 as the app is single-view) or the app backgrounded during the 13-40ms generation window, the Task completes normally — there is no meaningful race condition at this time scale.

---

## 7. Security Requirements (from consultation)

These four requirements are non-negotiable implementation constraints for the software-engineer. Each maps to a verification step in the security consultation (Section 6 of the security doc).

### REQ-SEC-1: Strip PDF document metadata

When creating the `PDFDocument`, set `documentAttributes` to include only the title attribute. Set title to the play's display name for usability in Files app and email subject lines. Do not set author, creator, subject, or keywords attributes.

```swift
pdfDocument.documentAttributes = [
    PDFDocumentAttribute.titleAttribute: playCall.displayName   // e.g., "Twins 6794"
]
```

**Placement:** Set immediately after `PDFDocument` is instantiated, before adding the page. `documentAttributes` must be set before calling `dataRepresentation()`.

**Verification:** Open generated PDF with `mdls` on macOS and confirm Author/Creator/Subject fields are absent. Title should match the play's display name.

### REQ-SEC-2: Write temp file to `temporaryDirectory`

```swift
let tempDir = FileManager.default.temporaryDirectory
let filename = "\(UUID().uuidString)-\(sanitizedFormation)-\(digits)-wristband.pdf"
let tempURL = tempDir.appendingPathComponent(filename)
```

Use a `UUID` prefix to avoid collisions between concurrent exports (unlikely in V1 but correct practice). The filename after the UUID prefix uses the human-readable formation+digits string for share sheet display.

**Sanitization of formation name:** Replace spaces with hyphens; strip characters outside `[A-Za-z0-9\-]`. Example: "Trips Right" → "Trips-Right".

### REQ-SEC-3: Apply file protection to temp file write

```swift
try data.write(to: tempURL, options: .completeFileProtection)
```

Do not use `.atomic` alone or bare `write(to:)` without options. `.completeFileProtection` encrypts the file when the device is locked; since the file exists only during an active user session, this protection is always satisfiable and costs nothing.

### REQ-SEC-4: Delete temp file in share sheet completion handler

```swift
let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
activityVC.completionWithItemsHandler = { _, _, _, _ in
    try? FileManager.default.removeItem(at: tempURL)
}
```

Additionally, if `data.write(to:options:)` succeeds but the share sheet is never presented (error in UIKit bridge), delete the temp file in the error path:

```swift
guard let windowScene = ... else {
    try? FileManager.default.removeItem(at: tempURL)
    errorMessage = "Could not present share sheet. Please try again."
    return
}
```

A `defer` block in `exportCurrentPlay()` keyed on whether `UIActivityViewController` was successfully presented is an acceptable implementation pattern:

```swift
var shareSheetPresented = false
defer {
    if !shareSheetPresented {
        try? FileManager.default.removeItem(at: tempURL)
    }
}
// ... present share sheet ...
shareSheetPresented = true
```

---

## 8. Performance Constraints (from assessment)

These are binding implementation constraints, not guidelines.

| Constraint | Value | Source |
|-----------|-------|--------|
| Total PDF generation latency (hard gate) | < 500ms on iPhone 13 or newer | Spec § 8 success metric 7; Story 3.1.3 AC |
| Expected actual latency | 13–40ms on iPhone 12+ | Performance assessment Section 2 |
| Background queue | Required — dispatch via `Task.detached(priority: .userInitiated)` | Performance assessment Section 5.1 |
| Diagram render scale | 2.0 (explicit, not `UIScreen.main.scale`) | Performance assessment Section 5.3 |
| Diagram render count | Once per unique PlayCall; embed result N times | Performance assessment Section 7 (risk item 3) |
| Peak memory per export | < 2MB expected; < 5MB hard ceiling | Performance assessment Section 4, 6.4 |
| Pre-generation / speculative generation | Prohibited — generate only on "Export as PDF" tap | Performance assessment Section 5.5 |

**Thread model:**

```swift
// In PlayCallerViewModel.exportCurrentPlay()
isExporting = true
let data: Data? = await Task.detached(priority: .userInitiated) {
    WristbandPDFGenerator.generate(playCalls: [playCall])
}.value
isExporting = false
```

The `@MainActor` isolation of `PlayCallerViewModel` means the `await` returns to the main actor automatically. No explicit `MainActor.run` wrapper is needed.

**Scale factor clarification for Option B (vector path):** Because Option B draws directly into the PDFKit `CGContext` (vector paths, no bitmap), the "render at 2x scale" directive from the performance assessment does not apply to the diagram rendering itself — vector paths are resolution-independent. The 2x scale recommendation was specific to Option A's `UIGraphicsImageRenderer` bitmap. If Option A is ever revisited, the 2x constraint applies.

**Performance test:** `WristbandPDFGeneratorPerformanceTests.swift` must include an XCTest `measure {}` block as specified in the performance assessment (Section 6.2). The baseline must be committed as an `.xcbaseline` file alongside the test. The acceptance gate (physical device, Release configuration) must be run by the SDET before the epic is declared complete.

---

## 9. Open Questions Resolved

The following open questions from the product spec (Section 9) and consultations are resolved with recommended defaults. Questions that require Ken's explicit confirmation before Story 3.1.3 begins are marked **BLOCKING — CONFIRM WITH KEN**.

### OQ-1: Post-motion vs pre-motion diagram (BLOCKING — CONFIRM WITH KEN)

**Recommended default:** Post-motion (use `currentPlayCallWithMotion ?? currentPlayCall`).

**Rationale:** A player running a play needs to know where they line up and route from after motion completes, not where they started. The post-motion state is already available in the ViewModel as `currentPlayCallWithMotion`. The UX consultation (Section 2.1) confirms this recommendation. The diagram on the card must match what the player will execute.

**Impact if confirmed:** `WristbandPDFGenerator` receives `currentPlayCallWithMotion ?? currentPlayCall`. `WristbandPDFYWheelTests` and `DiagramRendererOffScreenTests` are written against the post-motion `PlayCall`.

**Impact if reversed (pre-motion chosen):** `WristbandPDFGenerator` receives `currentPlayCall` only. Test fixtures change. Architecture does not change — the same pipeline handles either input.

**Architectural note:** The generator accepts a `PlayCall` value type. The motion state (whether Y motion was applied) is already embedded in the `PlayCall`'s `assignments` array by `applyMotion()`. The generator does not need to know which ViewModel property was used — it processes whatever `PlayCall` is passed.

### OQ-2: 4-up 2x2 grid vs single-card page (BLOCKING — CONFIRM WITH KEN)

**Recommended default:** 4-up 2x2 grid.

**Rationale:** Coaches need multiple copies of a card (one per player at the position, one for the coaching staff binder). Four identical cards per sheet with two cuts is a significantly better coaching workflow than printing four separate sheets. The spec recommends the grid; the UX consultation endorses it.

**This spec is written for the 4-up grid.** If Ken selects single-card, the page layout in Section 5 changes entirely (one card centered on the page, no grid math needed), and `WristbandCardLayoutTests` must be rewritten. The generator and card model are unaffected.

### OQ-3: Motion label format

**Resolved:** `"Y Stop"` and `"Y Go"`.

**Rationale:** Short labels fit the card's text zone at 11pt. `ReceiverMotion.stop` maps to `"Y Stop"`; `ReceiverMotion.after` (the "Go" motion) maps to `"Y Go"`. No other motion states exist in V1. `WristbandMotionLabelTests` asserts these exact strings.

**Action sheet message with concept name (UX consultation OQ-3):** The action sheet message will display `playCall.displayName` (formation + digits only, e.g. `"Twins 6794"`) without appending the concept name. This is the simpler implementation and matches the spec exactly. If Ken wants concept name in the confirmation, it is a one-line change — no architectural impact. Treat this as a V2 copy refinement.

### OQ-4: Play number value

**Resolved:** Always `1` in V1.

**Rationale:** There is no play history; a fixed number is better than a blank field because it shows the coach what play number rendering looks like (useful for V2 multi-select) and avoids a nil-rendering code path. The spec notes coaches may hand-annotate. `WristbandPlayNumberTests` asserts the value is `1`.

### OQ-5: Team branding / team name on card

**Resolved:** Not included in V1.

**Rationale:** The spec lists this as "not required for V1 game-day use; flag as V2 enhancement unless Ken requests it." No branding field appears in `WristbandCard`. If Ken requests it before Story 3.1.3, add a `teamName: String?` field to `WristbandCard` and a top-center label to the card layout — no architectural change required.

### OQ-6: Page size (US Letter vs A4)

**Resolved:** US Letter (8.5"x11" = 612pt x 792pt).

**Rationale:** The spec assumes a US school/coaching context. US Letter is the target. If the app is adopted internationally, a `pageSize` parameter can be added to `WristbandCardConfig` in V2. The card dimensions (3.5"x2.5") fit within both US Letter and A4 in a 2x2 grid, so the card content is unaffected — only the page margins shift.

---

## 10. Out of Scope (V1)

The following items must not be implemented in Epic 3.1. Any request to add these during implementation should be redirected to the backlog.

| Item | Reason / Expected Home |
|------|----------------------|
| Multi-select export of multiple plays | Requires play persistence (separate epic). V2 of export. |
| Play persistence / play history | Distinct feature; no data model exists. |
| Per-card single-page PDF layout | V2 density option. 4-up grid is V1. |
| Cloud sync of plays or PDFs | No backend; explicitly excluded from project non-goals. |
| PDF password protection | No compliance requirement; adds friction. |
| Batch export of 8+ plays | Requires multi-select; V2. |
| Watch / iPad layout optimization | iPhone target only for V1. |
| Team branding / logo | V2 UX enhancement. |
| In-app print preview | V2 feature; the share sheet's AirPrint preview serves this need. |
| Accessible (tagged) PDF for screen readers | V2 concern; print-destined artifact. |
| Concept name in action sheet confirmation message | V2 copy refinement (OQ-3 above). |
| Custom share sheet activities | V2; standard system activities cover all stated needs. |

---

## 11. Risks and Mitigations

### Risk 1: Diagram legibility at card scale (HIGH probability, MEDIUM impact)

`DiagramRenderer` was designed for a 320pt tall canvas. At card scale the diagram zone is ~240pt x 58pt. Receiver dots, route arrow heads, and the Y Wheel arc path may be too small to read after lamination.

**Mitigation:** The card-scale `DiagramConfig` factory (Section 2.1) establishes explicit parameters calibrated for the card zone. The notes line is the first element to cut if space is needed. The UX consultation establishes 4pt as the minimum dot radius. Story 3.1.5 requires Ken's physical sign-off on a laminated printed card — this is the definitive legibility gate. If Ken identifies illegibility, the parameters in `WristbandCardConfig` and `DiagramConfig+CardScale` are the only things that need adjustment; the architecture does not change.

**Validation (cheap):** Before Story 3.1.5 field test, render one card to PDF and open in Preview at 100% zoom. Confirm dot radius and route paths are visually distinct.

### Risk 2: Toolbar crowding on iPhone SE (LOW probability, LOW impact)

On the 375pt-wide iPhone SE, two trailing toolbar items (share icon + "Reset" text) may be tight. The share button uses icon only (`Image(systemName:)`), which minimizes width.

**Mitigation:** Engineer verifies on SE simulator during Story 3.1.4. If buttons overlap, convert "Reset" to an icon (`arrow.counterclockwise`) with an accessibility label. This is a one-line change.

### Risk 3: `UIActivityViewController` UIKit bridge pattern (MEDIUM probability, LOW impact)

SwiftUI has no native wrapper for `UIActivityViewController`. The UIKit bridge (finding `UIWindowScene` → `rootViewController` → `present`) is standard iOS boilerplate but fragile to scene lifecycle edge cases (e.g., app in background during rare race).

**Mitigation:** The engineer should find the `keyWindow` from `UIApplication.shared.connectedScenes` using the established pattern from Apple's developer documentation. This is a V1 single-scene app with no multi-window support, so scene lifecycle complexity is minimal. If the scene lookup fails (returns nil), the error path cleans up the temp file (REQ-SEC-4 error branch) and shows an error alert.

### Risk 4: `PDFPage.string` returning nil in content tests (KNOWN — mitigated by test strategy)

The SDET identified that text drawn via Core Graphics (Option B) does not appear in `PDFPage.string` extraction. `WristbandPDFContentTests` must use geometry-based assertions (page count, media box size, data validity) rather than string extraction for text field verification. Formation and digits presence is verified via the manual smoke test.

**This is a test strategy constraint, not an architectural risk.** The engineer writing `WristbandPDFContentTests` must follow the SDET test strategy Section 5.5 guidance.

### Risk 5: Async/await and `@MainActor` test isolation (LOW probability, LOW impact)

The SDET test strategy (Section 5.2) notes that the shallow `@MainActor` test pattern in existing ViewModel tests is brittle. New export state tests (`PlayCallerViewModelExportStateTests`) must follow the same `nonisolated(unsafe) var viewModel` + `MainActor.assumeIsolated` pattern.

**Mitigation:** The implementing engineer must read the existing `PlayCallerViewModelTests.swift` test pattern before writing new export state tests. Deviation from the existing pattern will produce runtime assertions, not compile errors.

---

## 12. Roles

| Role | Contribution to this design | Phase |
|------|----------------------------|-------|
| Product Owner | Problem definition, card content specification (Section 3 of spec), acceptance criteria, open question ownership | Step 1 |
| UX Designer | Card layout hierarchy, font size floors, toolbar placement, button states, accessibility requirements, action sheet content | Step 2 consultation |
| Security Engineer | Threat surface analysis, REQ-SEC-1 through REQ-SEC-4, temp file handling patterns, share sheet behavior assessment, involvement assessment | Step 2 consultation |
| SDET | Regression risk identification, test pyramid, DiagramRenderer off-screen rendering seam, PDFPage.string limitation, test file list, manual smoke test charter | Step 2 consultation, Step 4 |
| Performance Engineer | Critical path latency analysis, thread model requirements, scale factor constraint, memory impact assessment, performance test plan | Step 2 consultation, Step 4 |
| Architecture & System Design | Component design, Option A/B trade-off resolution, data flow pipeline, coordinate system handling, page layout algorithm, state isolation, open question resolution, this document | Step 3 |
| Software Engineer | `WristbandPDFGenerator`, `WristbandCard`, `WristbandCardConfig`, `DiagramConfig+CardScale`, `WristbandPDFPage`, `DiagramRenderer` extension, ViewModel additions, View toolbar and action sheet wiring | Step 6 |

---

## Self-Review Notes

The following were checked before finalizing this spec:

**TBD/TODO placeholders:** None. All sections that were marked "[TBD until architecture decision]" in the test strategy (specifically `DiagramRendererOffScreenTests` assertions) are now resolved by the Option B decision. The test file must assert: non-crashing output from `DiagramRenderer.draw(into:playCall:config:in:)` called with a `UIGraphicsImageRenderer`-backed context. No pixel assertions needed.

**Internal contradictions checked:**
- "Render once, embed four times" (performance assessment) vs "draw four times via vector paths" (Option B): these are consistent. Vector paths are drawn four times (one draw call per cell) but each is a fast CGContext path stroke — no bitmap allocation or compression. "Render once, embed four times" was a directive for Option A's bitmap; under Option B the equivalent guidance is "compute geometry once and call `draw(into:)` per cell." The implementation engineer should note this distinction.
- "Diagram zone is 40% of card height": 40% of 180pt = 72pt. Section 2.1 states `diagramZoneHeight = 72.0pt`. The vertical layout in Section 5 places the divider at y=90pt and diagram zone below. 180-90=90pt for the diagram zone, but 6pt bottom inset reduces usable height to 84pt. This is ~47% of card height, not 40%. Resolution: the divider y position should be `cardHeight * 0.50 = 90pt` (50%), with the diagram zone being the lower 50% minus insets. The UX consultation says "lower 40%" which is a target from the content density analysis, not a hard layout rule. The diagram zone rect should be maximized below the text content rows. The implementing engineer should finalize the divider y position based on actual text row heights and ensure the diagram zone is at least 60pt tall (the minimum for readable route paths at card scale). The "40%" figure in the spec is a minimum floor, not an exact split. **This is an implementation detail the engineer resolves during Story 3.1.3 — the architecture does not prescribe it to the point.**
- `WristbandCard.receiverLabels` is always `["X", "Y", "Z", "A", "H"]` (5 elements). The H receiver only appears in 5-digit routes. For 4-digit routes (4 receivers), the H label still prints but corresponds to a receiver with no route assignment. The visual treatment (subdued/grayed H when no H assignment exists) is an implementation detail for the engineer — it does not affect the data model. The data model always carries all 5 labels; the render layer decides how to present unused ones.

**Ambiguous requirements resolved:**
- The spec says "play number at minimum 14pt bold" (Section 3.1b) but the UX consultation says "18pt bold" (Section 1.3). This spec adopts **18pt** as the implementation target — the UX consultation provides the higher-resolution guidance for readability after lamination, and 18pt is the stricter floor.
- The spec says "0.25" bleed margins" in Section 3.1b. In standard print terminology, "bleed" refers to content that extends to the edge of the cut line. The spec's intent is a 0.25" page margin (distance from paper edge to nearest card edge), not a print bleed in the typographic sense. This spec uses 0.25" page margin throughout.

**Hardest trade-off driven by which requirement:** The Option B decision (vector PDFPage over raster bitmap) is driven by the spec's print quality requirement ("300 dpi minimum equivalent" in Section 3.1b). A 2x-scale raster embed produces ~144 effective dpi in the PDF, below the 300 dpi floor. Vector paths are DPI-independent and satisfy the requirement unconditionally. This trade-off forces a new `DiagramRenderer` CGContext draw method — additional implementation work relative to Option A, but unavoidable if the print quality requirement is taken literally.

**What would invalidate this design:**
- If PDFKit's `PDFPage` override mechanism is unavailable or broken on a specific iOS 17.x point release (unlikely but possible with Apple framework regressions). Mitigation: fall back to `UIGraphicsImageRenderer` + embedded image (Option A) with an explicit 4x scale factor to meet 300 dpi.
- If `DiagramRenderer.draw(into:playCall:config:in:)` produces visually incorrect output in the PDF coordinate system (despite the coordinate flip) for a specific formation or motion combination. Mitigation: validate all formations and Y Wheel in `DiagramRendererOffScreenTests` before merge.

**Cheap validation:** Before Story 3.1.3 implementation begins, write a standalone Swift playground or CLI tool that instantiates `WristbandPDFPage` with hardcoded test data, calls `PDFDocument.dataRepresentation()`, and writes the PDF to disk. Open in Preview. Confirm the coordinate system flip is correct and the 4-up grid positions are visually accurate. This 30-minute exercise catches 90% of layout bugs before any integration with the ViewModel or View.
