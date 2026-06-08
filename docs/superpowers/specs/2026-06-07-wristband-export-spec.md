# Product Spec: Epic 3.1 — Play Library, Play Catalog & Wristband Export

**Date:** 2026-06-07 (revised)
**Author:** Product Owner
**Status:** READY FOR DESIGN CONSULTATION UPDATE
**Epic Priority:** CRITICAL — blocks production deployment and coaching adoption

**Revision summary:** Scope expanded from single-play wristband-only export to full play library + two export modes (Play Catalog primary, Wristband secondary) with multi-play selection. This revision supersedes the original 2026-06-07 wristband-only spec in its entirety.

---

## 1. Problem & Value

### Problem

Spartans Playcaller can build plays, parse route digits, and render route diagrams — but a coach cannot take any of that output onto the sideline. Two gaps block game-day deployment:

**Gap 1: No play persistence.** The app shows one play at a time. When the coach changes formation or digits, the previous play is gone. There is no library, no history, and no way to collect the week's game-plan plays before exporting them. Multi-play export — which both export modes require — is impossible without a place to save plays.

**Gap 2: No export.** Even for a single play, there is no way to produce a printable physical artifact. The app is currently practice-room software: useful for building a playbook, useless at kickoff.

Football coaches communicate plays from the sideline using one of two physical formats:

- **Play catalog sheets:** Dense game-plan reference sheets (6–9 plays per 8.5"×11" page) used by coaches in the booth or on the sideline clipboard. Coaches build the week's script, export one page, and reference it during the game.
- **Wristband cards:** Laminated 3.5"×2.5" cards worn on the forearm or held on a clipboard, containing a compact set of play calls. The coach calls a number; the player reads the corresponding card and runs the play.

Without play persistence and export, the Spartans Playcaller requires a parallel manual process for both formats. That parallel process is the adoption blocker: coaches will not commit to the app if they still have to maintain a paper system.

### Value

Adding a play library and two export modes converts the app from a design tool into a **game-day system**:

- Coaches build plays during the week, save them to the in-app library, and accumulate the game-plan script without losing work between sessions.
- On the eve of game day, the coach selects the relevant plays, chooses an export mode, and prints in one action.
- **Play catalog** produces a dense reference sheet the coaching staff reads from. **Wristband** produces cut-ready lamination cards the players wear.
- The share sheet (AirPrint, Files, email, AirDrop) distributes either format digitally before printing.

This is the single highest-leverage feature set for moving from "interesting prototype" to "deployed coaching tool."

### Why Both Modes Are Critical-Path

Play catalog is the primary mode: coaches reference it throughout the game. Wristband is secondary: it serves players who need physical cards. Both are in scope for V1 because coaches need both formats to replace their paper system. A coaching staff that can only export one format still maintains a parallel paper process for the other — which means partial adoption, not full adoption.

---

## 2. Users & Context

### Primary User: Ken (Head Coach / Coordinator)

Ken builds the play call system, enters route digits, and needs to produce both reference sheets and wristbands before games. His weekly workflow:

1. Opens app during the week, builds the week's play calls one at a time.
2. Saves each play to the in-app library using a "Save Play" button.
3. Before game day, opens the library, selects the plays for the game plan (multi-select).
4. Exports in Catalog mode for sideline reference sheets (coaches read this).
5. Exports in Wristband mode for player cards (players wear these).
6. Prints both PDFs on a standard printer, cuts/laminates as appropriate, distributes.

### Secondary Users: Players and Assistant Coaches

They receive physical artifacts (wristband cards or catalog printouts). They do not use the app. Their requirements flow through legibility and information completeness — they need to read a card in under 2 seconds under sideline conditions (glare, adrenaline, limited time).

### Physical Context of Use

- **Printing:** Standard inkjet or laser printer; 8.5"×11" output.
- **Catalog sheets:** Printed on plain paper; no lamination. Used by coaches on clipboard or in booth binder.
- **Wristband cards:** Cut from sheet and laminated. Consumer lamination pouches are standard. Font sizes and line weights must survive lamination.
- **Field conditions:** Cards read in sunlight at arm's length, often while moving. High contrast and adequate font size are prioritized.
- **Wristband card dimensions:** Target 3.5"×2.5" (standard wristband sleeve fit). Minimum legible font on a laminated card at arm's length: 10pt printed equivalent.
- **Catalog card dimensions:** Smaller — target 6–9 plays per 8.5"×11" page; exact size driven by the layout algorithm.

---

## 3. Story 3.0: Play Library / Persistence (Enabler)

This story is a prerequisite for both export modes. Without it, multi-play selection has nothing to select from.

### 3.0 Goal

Coaches can save the play currently displayed in PlayCallerView to an in-app library with a single tap. The library persists across app launches. Coaches can view saved plays and delete individual entries.

### 3.0 Acceptance Criteria

**Save a play:**
- Given a valid play call is displayed in PlayCallerView (formation + digits parsed, result shown), when the coach taps "Save Play", then the play is added to the library and the button provides brief visual confirmation (checkmark or brief "Saved" label).
- Given the coach taps "Save Play" for a play that is already in the library (same formation + same route digits), then the app either de-duplicates silently or prompts the coach — behavior must be consistent and predictable (recommend: save as a new entry with a timestamp, allowing duplicates; coach decides what to keep).
- Given no valid play call is displayed, when the coach looks at the PlayCallerView toolbar, then the Save Play button is disabled or absent.

**View and delete saved plays:**
- Given the coach has saved at least one play, when they navigate to the Library view (accessible from PlayCallerView or a tab), then they see a list of saved plays, each showing: formation name, route digits, concept name (if matched), and motion state (if not None).
- Given a list of saved plays, when the coach swipes left on an entry or taps a delete control, then that play is removed from the library and the list updates immediately.
- Given the library has no saved plays, when the coach views the Library, then a clear empty state is displayed (e.g., "No plays saved yet. Build a play and tap Save Play.").

**Persistence across launches:**
- Given the coach saves three plays and force-quits the app, when they relaunch the app, then all three plays are present in the Library with their formation, digits, concept, and motion state intact.
- Given the persistence mechanism is UserDefaults or a flat JSON file in the app sandbox, then no network access, CoreData, or iCloud sync is required or used.

**Domain annotations:**
- Persistence model (encode/decode PlayCall to JSON) → software-engineer
- Library list view, delete flow, empty state, Save Play button in PlayCallerView → software-engineer, ux-designer review
- Persistence correctness (encode/decode round-trip, launch survival) → sdet
- Performance: library write/read under 50ms for up to 200 saved plays → performance-engineer assessment
- Security: no PII stored; file written to app sandbox only, not shared container → security-engineer

---

## 4. Card Content Fields (Both Modes)

Each card in either export mode contains a common set of fields. The layout, font size, and card dimensions differ by mode, but the information content is the same.

### 4.1 Common Content Fields

| Field | Content | Required? |
|-------|---------|-----------|
| Play number | Sequential integer assigned in selection order (1, 2, 3…) | Yes |
| Formation | Formation name (e.g., "Twins", "Trips Right") | Yes |
| Route digits | Digit sequence (e.g., "6794") with X Y Z A H labels | Yes |
| Concept name | Named concept if one matches (e.g., "Smash"); omitted if no match | Conditional |
| Y Motion | Motion state if not None (e.g., "Y Stop", "Y Go"); omitted if None | Conditional |
| Mini diagram | Miniature route diagram rendered from DiagramRenderer | Yes |
| Notes field | One blank rule for handwritten annotation | Yes (wristband only; optional for catalog) |

**Resolved: Post-motion diagram (OQ-1 from prior spec)**

The mini diagram renders the **post-motion** receiver layout — the state after Y motion has been applied, if any. This is the state the player executes. The post-motion PlayCall (currentPlayCallWithMotion ?? currentPlayCall) drives both the diagram and the motion label field.

Rationale: A player reading a card needs to know where they line up after motion completes, not where they started. The pre-motion state is a coaching-internal detail; the card is a player-execution artifact.

**Y Motion label mapping (resolved):**
- ReceiverMotion.stop → "Y Stop"
- ReceiverMotion.after (Go) → "Y Go"
- nil → no field rendered (no blank label, no dash)

**Play number assignment:**
- Play numbers are assigned sequentially based on the coach's selection order in the export flow (1 for the first selected play, 2 for the second, etc.).
- This requires multi-select to be in place before play numbers can be assigned — which is why Story 3.0 (library) is a prerequisite.

---

## 5. Story 3.1: Play Catalog Export (Primary Mode)

### 5.1 Goal

Produce a dense, game-plan reference sheet PDF with multiple plays per page. Coaches print this on plain paper and reference it from the sideline or booth. This is the primary export mode.

### 5.2 Catalog Format

- **Page:** US Letter 8.5"×11", landscape orientation (wider than tall, giving more horizontal real estate for a row of cards).
- **Density target:** 6–9 plays per page. The layout algorithm must achieve at least 6 plays per page on a single landscape sheet.
- **Recommended layout:** 3 columns × 2 rows = 6 plays per page (conservative, readable). An alternate 3×3 grid (9 plays per page) is the stretch target — Ken confirms which density to ship based on legibility review.
- **Card approximate size at 6-up (3×2):** The 8.5"×11" landscape sheet in points is 792pt wide × 612pt tall. With 18pt margins and 9pt gutters: card width ≈ (792 - 36 - 18) / 3 ≈ 246pt (3.4"); card height ≈ (612 - 36 - 9) / 2 ≈ 283pt (3.9"). These are larger than wristband cards — more space per play, smaller font than wristband is unnecessary; font stays legible.
- **Card approximate size at 9-up (3×3):** card width ≈ 246pt; card height ≈ (612 - 36 - 18) / 3 ≈ 186pt (2.6"). Comparable to wristband card height. Legibility must be validated by Ken.
- **Font sizes (catalog, 6-up as baseline):** Play number 16pt bold; formation 13pt semibold; digits 13pt medium; receiver labels 9pt; concept 11pt semibold; motion 10pt; diagram occupies lower 40% of card.
- **Printing intent:** Plain paper, no lamination required. Coaches do not cut the sheet — they reference it whole.
- **No cut guides needed** (catalog is read whole, not cut into individual cards).

### 5.3 Story 3.1 Acceptance Criteria

**PDF structure:**
- Given a selection of N plays, when Catalog export is triggered, then the generated PDF contains ceil(N/6) pages (for 6-up layout), each page being US Letter landscape.
- Given a generated catalog PDF, when opened in any PDF viewer, then it renders without errors or missing content.

**Card content:**
- Given a play with formation "Twins" and digits "6794", when the catalog PDF is generated, then the card displays: play number (sequential), "Twins", "6 7 9 4" with X Y Z A labels, the mini route diagram, and (if matched) the concept name.
- Given a play with concept nil, when the PDF is generated, then no concept field appears — no blank label.
- Given a play with Y Motion = .stop, when the PDF is generated, then "Y Stop" appears on the card.
- Given a play with Y Motion = nil, when the PDF is generated, then no Y Motion field appears.
- Given Y Wheel is enabled for a play, when the PDF is generated, then the mini diagram renders Y's route as the wheel arc.

**Density and layout:**
- Given 6 plays selected, when Catalog export generates a PDF, then all 6 plays appear on a single landscape page with no overflow to a second page.
- Given 7 plays selected, when Catalog export generates a PDF, then 6 plays appear on page 1 and 1 play appears on page 2.
- Given Ken reviews the physical printout at the chosen density (6-up or 9-up), then Ken confirms the information is legible without magnification and the format is usable on the sideline. (Sign-off AC — blocks Story 3.3.)

**Domain annotations:**
- PDF generation, catalog layout algorithm → software-engineer
- Density and legibility validation (printed artifact) → product owner (Ken sign-off)
- Automated layout geometry assertions (card count, page count, media box) → sdet
- PDF generation latency (<500ms for 9 plays on iPhone 13) → performance-engineer

---

## 6. Story 3.2: Wristband Export (Secondary Mode)

### 6.1 Goal

Produce cut-ready lamination cards for players. Each page contains 4 copies of the same play (2×2 grid) at wristband card size (3.5"×2.5"), so the coach makes two cuts and has four identical cards — one for each player at the position, plus staff copies.

When multiple plays are selected in wristband mode, the PDF contains one page per play (each page has 4 copies of that single play). The coach prints the set of pages and cuts each sheet separately.

### 6.2 Wristband Format

- **Page:** US Letter 8.5"×11", portrait orientation.
- **Grid:** 4-up 2×2 grid — 4 identical copies of the same play per page.
- **Card size:** 3.5"×2.5" (252pt×180pt at 72pt/inch).
- **Page margins:** 0.25" (18pt); gutter between cards: 0.125" (9pt).
- **Cut guides:** Thin hairline rule (0.25pt) at vertical and horizontal gutter centers — print aids for cutting.
- **Font sizes:** Play number 18pt bold; formation 14pt semibold; digits 14pt medium; receiver labels 9pt; concept 12pt semibold; motion 11pt; diagram occupies lower 40% of card area; notes rule at 8pt label.
- **Notes field:** One blank rule with "Notes:" label — for handwritten annotations. Present on wristband cards; optional on catalog cards.
- **Printing intent:** Plain paper, then consumer lamination pouches. Font sizes and line weights must survive lamination gloss.

### 6.3 Multi-Play Wristband Behavior

- 1 play selected → 1 PDF page (4 copies of that play).
- 3 plays selected → 3 PDF pages (4 copies of play 1 on page 1; 4 copies of play 2 on page 2; 4 copies of play 3 on page 3).
- Play numbers on each page are sequential from the coach's selection order.

### 6.4 Story 3.2 Acceptance Criteria

**PDF structure:**
- Given N plays selected in Wristband mode, when the PDF is generated, then the PDF contains exactly N pages.
- Given any single page of the wristband PDF, when opened in a PDF viewer, then it displays 4 identical cards in a 2×2 grid on a US Letter portrait page.
- Given the PDF is printed at 300 dpi on an 8.5"×11" sheet, then the 2×2 card grid fits within the printable area with 0.25" margins, and two cuts along the gutter hairlines produce four cards of the correct 3.5"×2.5" size.

**Card content:** (same as Catalog — see Section 5.3 card content criteria; they apply equally.)

**Physical validation:**
- Given Ken prints a generated wristband PDF on a standard inkjet printer, cuts along the hairlines, and laminates the cards, then all text is legible at 18" by a person with average vision.
- Given Ken reviews the complete wristband card layout, when comparing it to his existing manual wristband format, then Ken confirms the information is complete and the format is usable without modification. (Sign-off AC — blocks Story 3.3.)

**Domain annotations:**
- PDF generation, wristband layout (4-up per-play pages) → software-engineer
- E2E: button → action sheet → mode selection → PDF → share sheet → print → physical card → legibility → sdet (automated) + product owner (physical validation)
- PDF generation latency for N-page wristband (<500ms per page on iPhone 13) → performance-engineer
- File protection, temp file cleanup, metadata stripping → security-engineer

---

## 7. Story 3.3: Coach Field Validation (was 3.1.5)

### 7.1 Goal

Validate both exported formats in real-world use conditions before declaring the epic complete.

### 7.2 Acceptance Criteria

- Given catalog PDFs generated from a real game-plan set (6–9 plays), when Ken prints on a standard inkjet printer, then the reference sheet is legible and usable as a sideline reference without modification.
- Given wristband PDFs generated from the same play set, when Ken prints, cuts, and laminates, then the physical cards are cut-ready, correctly dimensioned, and legible in outdoor lighting without magnification.
- Given Ken reviews both exported formats against his existing manual workflows, then Ken confirms: (a) catalog replaces or improves on his paper reference sheet, (b) wristband replaces or improves on his manual laminate cards.
- Given Ken uses both formats in a practice session, then play calls are executed correctly using the cards — no confusion from missing or ambiguous information.
- Given any critical legibility or format issues identified by Ken, then those issues are either fixed before the epic is closed or documented in the backlog with clear priority and a trigger condition.
- Given Ken signs off on both formats, when this AC is confirmed, then the epic is declared complete and "Completed" status is recorded in the backlog.

**Domain:** Coach field validation → product owner (Ken). Format iterations → software-engineer. Backlog updates → product owner.

---

## 8. Export Flow (Multi-Select)

The export flow applies to both Catalog and Wristband modes. The mode choice happens at the end, after play selection.

### 8.1 Step-by-Step Flow

1. **Save plays to library (during prep):** Coach builds plays in PlayCallerView during the week. Each play is saved to the library via the "Save Play" button before moving to the next play.

2. **Enter export flow:** Coach taps the Export button in PlayCallerView or from the Library view. Both entry points are acceptable; the Library view entry is preferred because it shows the coach all available plays before selection.

3. **Multi-select plays:** Coach sees a list of saved plays with multi-select enabled. Options:
   - "Select All" toggle
   - Individual play checkboxes
   - Selection count shown in the export button label (e.g., "Export 4 Plays")

4. **Choose export mode:** After selection is confirmed, the coach chooses Catalog or Wristband via an action sheet or segmented control:
   - "Play Catalog — dense reference sheet"
   - "Wristband Cards — lamination-ready 3.5"×2.5" cards"
   - "Cancel"

5. **PDF generated and share sheet presented:** The app generates the PDF for the chosen mode and presents UIActivityViewController (AirPrint, Save to Files, email, AirDrop).

### 8.2 Export Entry Points

**From PlayCallerView (quick export):** A share icon button in the navigation bar trailing area. Tapping opens the export flow directly. The current play is pre-selected if it has been saved to the library; if it has not been saved, the app prompts: "Save this play to the library first, or export the library directly." This prevents exporting unsaved work accidentally.

**From Library view:** A toolbar Export button opens the same multi-select flow against the full library.

### 8.3 Export Button States

- Export button is **disabled** when the library is empty (no plays saved yet).
- Export button shows selection count once the coach begins selecting plays.
- Export button changes to a spinner during PDF generation.
- PDF generation is dispatched off the main thread; UI remains responsive.

### 8.4 Story 3.1 and 3.2 UI Acceptance Criteria (Export Flow)

- Given the library has at least one saved play, when the coach taps Export, then a multi-select play list is presented.
- Given the coach selects 0 plays and taps the export button, then the button is disabled (cannot trigger generation with zero selection).
- Given the coach taps "Select All", then all plays in the library are selected and the count updates.
- Given the coach taps a selected play, then it is deselected and the count decrements.
- Given the coach confirms selection and is presented with mode options, when they choose "Play Catalog", then the catalog PDF is generated and the share sheet is presented.
- Given the coach chooses "Wristband Cards", then the wristband PDF (one page per selected play) is generated and the share sheet is presented.
- Given the coach taps Cancel at the mode selection step, then no PDF is generated and the app returns to the selection screen.
- Given an error occurs during PDF generation, then an alert is presented with a user-readable message ("Could not generate PDF. Please try again.") — the app does not crash.
- Given the share sheet is dismissed by the coach (Cancel), then any temporary file is cleaned up and app state is unchanged.

**Domain annotations:**
- Multi-select list view, Select All, mode action sheet, button states → software-engineer, ux-designer review
- Accessibility: selection state announced via VoiceOver, button disabled states, action sheet accessibility → ux-designer
- E2E export flow (select → mode → generate → share sheet → cancel → state unchanged) → sdet
- Share sheet error path and temp file cleanup → security-engineer

---

## 9. Out of Scope (V1)

The following are explicitly excluded from this epic. Scope creep toward these items should be redirected to the backlog.

| Out-of-Scope Item | Reason / Expected Home |
|-------------------|----------------------|
| iCloud sync of play library | No backend; explicitly excluded from project non-goals. |
| Cloud storage of PDFs | No backend. |
| Android or web export | iOS-only project. |
| QR code on card linking to digital play | Requires backend. |
| Custom card branding / team logo | Future UX enhancement; not blocking game-day use. |
| PDF password protection | No compliance requirement; adds friction. |
| Concept name in action sheet confirmation | V2 copy refinement. |
| Watch / iPad layout optimization | iPhone target only for V1. |
| Per-card single-page PDF layout | V2 density option; both grid formats cover V1 needs. |
| Accessible (tagged) PDF for screen readers | V2; print-destined artifact. |
| In-app print preview | V2; AirPrint preview in share sheet satisfies the need. |
| Custom share sheet activities | V2; system activities cover all stated needs. |
| Play editing in library | V2; saves are immutable in V1. Edit = delete + rebuild. |
| Play ordering / drag-reorder in library | V2; export order follows save order or selection order. |
| Team branding header on cards | V2 UX enhancement. |
| Play number persistence across exports | V2; numbers are assigned at export time. |

---

## 10. Stories Summary

| Story | Title | Priority | Prerequisite |
|-------|-------|----------|-------------|
| 3.0 | Play Library / Persistence | Required enabler | None |
| 3.1 | Play Catalog Export | Primary export | 3.0 |
| 3.2 | Wristband Export | Secondary export | 3.0 |
| 3.3 | Coach Field Validation | Sign-off gate | 3.1, 3.2 |

**Note on numbering:** The original backlog's "Epic 3.2: Concept Discovery" is a separate epic and is not affected by this numbering. These stories are sub-stories within Epic 3.1 (the wristband/export epic), not a new top-level epic.

---

## 11. Roles

| Role | Involvement | Phase |
|------|-------------|-------|
| Product Owner | Spec, acceptance sign-off, coach validation (Story 3.3), backlog update | Steps 1, 13 |
| UX Designer | Library list view, multi-select flow, mode selection, Save Play button placement, accessibility on all new controls | Step 2 consultation, Step 6 review |
| Software Engineer | PlayLibrary persistence model, Save Play button, Library view, multi-select export flow, CatalogPDFGenerator, WristbandPDFGenerator, PlayCallerView wiring, UIActivityViewController | Step 6 implementation |
| SDET | Test strategy update, test plan covering: library encode/decode round-trip, launch persistence, multi-select state, catalog layout geometry, wristband layout geometry, export E2E flow, share sheet cancel, error path | Steps 4, 8 |
| Performance Engineer | Library read/write latency (up to 200 plays), catalog PDF generation latency (<500ms for 9 plays), wristband PDF generation latency (<500ms per page), memory impact of multi-page PDF | Steps 4, 9 |
| Security Engineer | Involvement assessment: on-device only, no network, no credentials; sandbox file write; PDF metadata stripping; temp file cleanup; library file protection | Steps 2, 10 |
| Architecture / System Design | Review PlayLibrary persistence layer placement; CatalogPDFGenerator vs WristbandPDFGenerator decomposition; shared PDFCard model; multi-page layout algorithm; DiagramRenderer reuse for both generators | Step 3 |
| Auditor | Conformance review: spec AC vs shipped artifact | Step 11 |

---

## 12. Success Metrics

The epic is complete when all of the following are observable:

1. **Build gate:** Project compiles without errors or warnings introduced by this epic; all existing tests continue to pass.
2. **Library reachable:** Save Play button appears in PlayCallerView when a valid play call is displayed; Library view is accessible and lists saved plays.
3. **Persistence confirmed:** Plays saved in one session are present after force-quit and relaunch.
4. **Catalog export reachable:** Export flow is accessible from PlayCallerView and/or Library view; Catalog mode produces a landscape PDF with 6–9 plays per page.
5. **Wristband export reachable:** Wristband mode produces a portrait PDF with 4 copies of each selected play on separate pages.
6. **PDF correctness (both modes):** All required fields present on each card (play number, formation, route digits, concept when matched, Y Motion when not None, mini diagram). Verified by SDET automated geometry assertions and manual visual inspection.
7. **Print fidelity (catalog):** Catalog sheet printed on plain paper is legible and usable as a sideline reference — confirmed by Ken.
8. **Print fidelity (wristband):** Wristband PDF printed at 300 dpi, cut along hairlines, and laminated produces 3.5"×2.5" cards with text readable at 18" — confirmed by Ken.
9. **Coach sign-off:** Ken confirms in Story 3.3 that both exported formats are usable on game day — coaching-workflow correct, not just technically correct.
10. **Share sheet coverage:** AirPrint, Save to Files, and email available via system share sheet for both modes.
11. **Performance floor:** Catalog PDF generation (<500ms for 9 plays on iPhone 13); wristband PDF generation (<500ms per page); library read/write (<50ms for up to 200 plays).
12. **No regressions:** All pre-existing SDET test results remain passing after this epic lands.

---

## 13. Open Questions (New)

The following open questions arise from the revised scope. Prior blocking questions OQ-1 and OQ-2 from the original spec are resolved below.

**Previously-blocking questions — now resolved:**

| # | Question | Resolution |
|---|----------|-----------|
| OQ-1 | Post-motion vs pre-motion diagram | **Post-motion.** Both catalog and wristband cards render the post-motion receiver layout. See Section 4.1. |
| OQ-2 | 4-up 2×2 grid vs single-card page for wristband | **4-up 2×2 grid per play, one page per play.** Multi-play wristband = multiple pages, one grid per play. See Section 6.3. |

**New open questions:**

| # | Question | Impact | Status | Recommended Default |
|---|----------|--------|--------|-------------------|
| NQ-1 | **Catalog density: 6-up (3×2) or 9-up (3×3)?** Confirm which density to ship. 6-up is more legible; 9-up fits more plays per page. | Determines font sizes, card dimensions, and page algorithm for catalog generator. | Open — recommend 6-up for V1 with 9-up as a V2 option; confirm with Ken. | 6-up |
| NQ-2 | **Catalog orientation: landscape or portrait?** Landscape (11"×8.5") gives wider cards in a 3-column layout; portrait (8.5"×11") gives taller cards. | Determines page dimensions for catalog PDF. | Open — recommend landscape for 3-column density; confirm with Ken. | Landscape |
| NQ-3 | **Library entry point in app navigation:** Should the Library be a modal sheet (accessed from a toolbar button in PlayCallerView), a second tab in a TabView, or a navigation push? | Determines structural change to app navigation. Architecture consultation must weigh in. | Open — recommend modal sheet accessed from a "Library" toolbar button to avoid TabView structural change in V1; confirm with Ken and UX designer. | Modal sheet |
| NQ-4 | **Save Play duplicate handling:** If the coach saves the same formation + digits combination twice, should the app (a) save as a new entry, (b) silently de-duplicate, or (c) prompt the coach? | Affects library data model and save logic. | Open — recommend save as new entry (timestamps differentiate; coach curates); confirm with Ken. | New entry |
| NQ-5 | **Catalog notes field:** Should catalog cards include a notes rule (like wristband), or omit it to maximize diagram and text space? | Affects catalog card layout and diagram zone height. | Open — recommend omit for catalog (space is tight; catalog is a read-only reference), include for wristband only; confirm with Ken. | Omit for catalog |
| NQ-6 | **Export from PlayCallerView with unsaved play:** If the coach taps Export in PlayCallerView but the current play has not been saved to the library, should the app (a) prompt to save first, (b) auto-save and include in selection, or (c) allow exporting the current play without saving? | Affects export entry point behavior. | Open — recommend (a) prompt to save or navigate to Library; confirm with Ken. | Prompt |

**NQ-1 and NQ-2 are BLOCKING for architecture and catalog PDF generation design. All others can be resolved during Step 3 architecture consultation.**

---

## Appendix A: Key Code Touchpoints

Implementation will interact with or create these files:

**Existing (read/modified):**
- `SpartansPlaycaller/Views/PlayCallerView.swift` — Save Play button, Export button, library entry point
- `SpartansPlaycaller/ViewModels/PlayCallerViewModel.swift` — canSave, saveCurrentPlay(), canExport, exportCurrentPlay()
- `SpartansPlaycaller/Models/PlayCall.swift` — must be Codable for library persistence; current struct is not Codable
- `SpartansPlaycaller/Services/DiagramRenderer.swift` — reuse for PDF context rendering (both generators)

**New (created):**
- `SpartansPlaycaller/Models/PlayLibraryEntry.swift` — Codable wrapper around PlayCall with save timestamp
- `SpartansPlaycaller/Services/PlayLibrary.swift` — persistence service (JSON encode/decode to app sandbox)
- `SpartansPlaycaller/Views/PlayLibraryView.swift` — library list view with multi-select and delete
- `SpartansPlaycaller/Models/ExportCard.swift` — shared value type for both generators (replaces WristbandCard)
- `SpartansPlaycaller/Models/ExportCardConfig.swift` — layout constants per mode (catalog variant and wristband variant)
- `SpartansPlaycaller/Services/CatalogPDFGenerator.swift` — catalog mode PDF generation
- `SpartansPlaycaller/Services/WristbandPDFGenerator.swift` — wristband mode PDF generation (updated from V1 single-play assumption)
- `SpartansPlaycaller/Models/DiagramConfig+CardScale.swift` — card-scale DiagramConfig factory (shared by both generators)

**Architectural note:** The existing architecture design doc (`2026-06-07-wristband-export-design.md`) specifies the wristband PDF pipeline in detail. Its core decisions (PDFKit, vector CGContext rendering via Option B, security requirements REQ-SEC-1 through REQ-SEC-4, coordinate system flip, WristbandCardConfig layout math) remain valid for the wristband mode and should be preserved. The architecture doc must be updated to cover: (a) PlayLibrary persistence layer, (b) CatalogPDFGenerator decomposition, (c) shared ExportCard model replacing WristbandCard, (d) catalog page layout algorithm, and (e) Library navigation entry point.

---

## Appendix B: Constraint Restatement

- **PDF:** PDFKit only. No third-party PDF dependencies.
- **Persistence:** UserDefaults or flat JSON file in app sandbox. No CoreData. No iCloud sync in V1.
- **Network:** None. All functionality is on-device.
- **iOS target:** iOS 17+.
- **Page size:** US Letter (8.5"×11"). Catalog: landscape. Wristband: portrait.
- **PlayCall Codable requirement:** PlayCall and all its dependent types (Formation, RouteAssignment, RouteNumber, RouteConcept, ReceiverMotion, etc.) must be made Codable to support JSON library persistence. This is a new requirement relative to the original spec and is the primary new technical risk. Architecture consultation must assess scope of Codable conformance work.

---

## Appendix C: Architecture Design Doc Status

The existing architecture design doc at `docs/superpowers/specs/2026-06-07-wristband-export-design.md` was written for the original single-play wristband-only scope. It remains valid as the wristband mode design and should not be discarded. The architecture agent must produce an **updated or supplemental design spec** covering the new scope additions (library, catalog mode, multi-select flow). The existing doc's wristband pipeline, security requirements, and coordinate system design carry forward unchanged.
