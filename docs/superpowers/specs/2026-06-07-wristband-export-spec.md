# Product Spec: Epic 3.1 — Wristband Export & Game-Day Deployment

**Date:** 2026-06-07
**Author:** Product Owner
**Status:** READY FOR DESIGN CONSULTATION
**Epic Priority:** CRITICAL — blocks production deployment and coaching adoption

---

## 1. Problem & Value

### Problem

Spartans Playcaller can build plays, parse route digits, and render route diagrams — but a coach cannot take any of that output onto the sideline. There is no way to export a play in a physical format usable during a game. The app is currently practice-room software: useful for building a playbook, useless at kickoff.

Football coaches communicate plays from the sideline using **wristband cards** — laminated 3"×2" cards worn on the forearm or held on a clipboard, containing a compact grid of play calls. The coach calls a number; the player reads the corresponding card entry and runs the play. Wristbands are the last-mile delivery mechanism between the digital playbook and the field.

Without wristband export, the Spartans Playcaller cannot replace (or even supplement) a paper playbook. Every practice where the app is used requires a parallel manual wristband process. That manual process is the adoption blocker: coaches will not commit to the app if they still have to maintain a paper system in parallel.

### Value

Wristband export converts the app from a design tool into a **game-day system**:

- Coaches build plays in the app, export wristband PDFs, print and laminate — one workflow, no parallel process.
- Each exported card carries exactly the information a player needs: formation, concept, digit sequence, and a miniature route diagram.
- The share sheet integration (AirDrop, email, Files) means cards can be distributed digitally before printing — useful for coaching staff coordination.

This is the single highest-leverage feature for moving from "interesting prototype" to "deployed coaching tool."

### Why It Is Critical-Path

Without this epic, every other feature improvement (Empty formation, Concept Discovery, Motion Diagram Clarity) ships into a dead end. Coaches evaluate the app by whether it helps them on game day. Until wristband export exists, the honest answer is: it does not. Adoption cannot happen without it.

---

## 2. Users & Context

### Primary User: Ken (Head Coach / Coordinator)

Ken builds the play call system, enters route digits, and needs to produce wristbands for players and assistant coaches before games. His workflow:

1. Opens app during the week, builds the week's play calls.
2. Before game day, selects the current play, exports a wristband PDF.
3. Prints on a standard printer (8.5"×11" sheet), cuts cards to size, laminates.
4. Distributes to players; cards are worn on the forearm or tucked into a wristband sleeve.

### Secondary Users: Players and Assistant Coaches

They receive physical wristband cards. They do not use the app. Their requirements flow through card legibility and information completeness — they need to read a card in under 2 seconds under sideline conditions (glare, adrenaline, limited time).

### Physical Context of Use

- **Printing:** Standard inkjet or laser printer; 8.5"×11" output; cards are cut from the sheet.
- **Lamination:** Consumer lamination pouches (common in coaching contexts). The laminate adds a thin gloss layer — line weights and font sizes that look fine on screen may become illegible after lamination at small sizes.
- **Field conditions:** Cards are read in sunlight, held at arm's length, often while moving. High contrast and large font are prioritized over information density.
- **Card dimensions:** Target 3.5"×2.5" (standard card size, fits standard wristband sleeve). Minimum legible font on a laminated card at arm's length: 10pt printed equivalent.

---

## 3. Wristband Card Format (Story 3.1.1 Resolution)

### 3.1a Content Fields

Each card contains exactly the following fields, in priority order:

| Field | Content | Required? |
|-------|---------|-----------|
| Play number | Sequential integer assigned by coach at print time (1, 2, 3…) | Yes |
| Formation | Formation name (e.g., "Twins", "Trips Right") | Yes |
| Route digits | Digit sequence (e.g., "6794") with X Y Z A H labels | Yes |
| Concept name | Named concept if one matches (e.g., "Smash"); omitted if no match | Conditional |
| Y Motion | Motion state if not None (e.g., "Y Stop", "Y Go"); omitted if None | Conditional |
| Mini diagram | Miniature route diagram rendered from DiagramRenderer output | Yes |
| Notes field | One blank line for handwritten annotation | Optional (print-time) |

**Rationale for field decisions:**

- Play number is the sideline communication primitive — the coach calls "seven," the player looks at card 7. Without a number, the card has no call-side identity.
- Formation + digits together constitute the complete play call. Neither alone is sufficient.
- Concept name is a coaching shorthand that aids player recognition and recall. It appears when matched; the card is still complete without it.
- Y Motion is critical when present — running a play without knowing Y's motion instruction is a football error, not just a display gap.
- Mini diagram gives the player spatial confirmation of their route. Text alone is insufficient for new or complex plays.
- Notes field allows coaches to hand-annotate printed cards with game-specific reads or opponent-specific instructions. It requires only a blank space.

### 3.1b Physical Constraints

- **Card dimensions:** 3.5"×2.5" per card (targeting standard wristband sleeve fit)
- **Grid layout (default):** 4 cards per 8.5"×11" page in a 2×2 grid, with 0.25" bleed margins and 0.125" gutter between cards. This yields four complete cards per printed sheet, requiring a single cut down the center of each axis.
- **Font size floor:** Formation name and route digits at minimum 12pt; play number at minimum 14pt bold; receiver labels at minimum 8pt. Mini diagram occupies the lower 40% of the card area.
- **Legibility standard:** Card content must be readable by a person with average vision at 18" distance without magnification, after printing at standard printer DPI (300 dpi minimum equivalent).

### 3.1c Format Decision: PDF via PDFKit

**Decision:** PDF output rendered via iOS PDFKit. No third-party dependencies.

**Rationale:**

- PDFKit is available natively on iOS 11+ (well within iOS 17+ target); no additional dependencies, no App Store review concerns about third-party frameworks.
- PDF is the correct format for print-destined output: resolution-independent vector rendering, standard print dialog support via AirPrint, universally openable via Files app, email, and iCloud.
- Images (PNG/JPEG) are an alternative but lose resolution independence — a photo shared to a print shop renders at screen resolution, which is insufficient for clean small-text output.
- App-specific formats (playbook files) are a v2 concern for playbook persistence; they do not address the immediate print-and-laminate need.

**Rejected alternatives:**

- PNG/JPEG: lossy, resolution-bound, inappropriate for print with fine text.
- App-specific format: does not solve the physical card problem; adds a custom serialization layer with no near-term payoff.

### 3.1d Card Density

**V1 scope: 4-up grid (2×2) on a single 8.5"×11" page.**

The grid produces a single PDF page per export action. The coach prints the sheet, makes two cuts, and has four cards. This is the simplest workflow: one tap, one print, four cards.

**V2 (out of scope for this spec):** Per-card single-page PDF for coaches who want full-bleed cards at larger sizes, or multi-sheet grid exports of 8+ plays.

---

## 4. Export Flow (Story 3.1.2 Resolution)

### 4.1 V1 Scope: Export Current Play Only

V1 exports the single play currently displayed in `PlayCallerView`. Multi-select from a play history list is a v2 concern and is explicitly out of scope (see Section 6). The current play is always defined and immediately available — this keeps the export path zero-friction.

**Rationale for single-play-first:** There is no persistent play history in the app today. Multi-select requires a play list, which requires play persistence, which is a distinct feature. Attempting to scope multi-select into this epic conflates two separate problems. Shipping single-play export unblocks the coaching workflow; play history is a separate backlog item.

### 4.2 Export Entry Point

A share icon button (`square.and.arrow.up`) is added to the navigation bar trailing area in `PlayCallerView`, adjacent to the existing "Reset" button.

- The button is **disabled** when no valid play call is currently displayed (i.e., `currentPlayCall == nil`).
- The button is **enabled** whenever a play call result is showing — formation, digits, and diagram are all available.
- Tapping the button opens the export action sheet (see 4.3).

**Why toolbar, not inline:** The export action is a document-level action (export this play), not a field-level action. Toolbar placement signals document-level scope, consistent with iOS convention. It also avoids cluttering the result section, which coaches scan visually.

### 4.3 Export Action Sheet

On tap of the export button, the app presents a standard iOS action sheet with the following options:

1. **Export as PDF** — generates the wristband card PDF and presents the system share sheet (`UIActivityViewController`). This covers: AirPrint (print directly to a compatible printer), save to Files, send via email, AirDrop to another device.
2. **Cancel** — dismisses the sheet.

The action sheet is presented with a title: "Export Wristband Card" and a message: "[Formation] [Digits]" (the current play's display name), so the coach confirms they are exporting the intended play.

**Why share sheet instead of a custom save flow:** `UIActivityViewController` gives the coach every standard output option (print, Files, email, AirDrop, Messages) without the app implementing any of them. It is the correct iOS primitive for document sharing and requires no additional infrastructure.

### 4.4 Play Number Assignment

Because V1 has no persistent play history, the play number on the card is assigned automatically as "1" for single-play exports. The coach can annotate with a handwritten number in the notes field, or the V2 multi-select feature will assign sequential numbers. This is documented as a known limitation of V1 scope.

### 4.5 State at Export Time

The exported card captures the current state including Y Motion and Y Wheel state. If the play has Y After/Go applied, the card reflects that. The mini diagram renders the post-motion receiver positions. This ensures the card matches exactly what the coach sees on screen.

---

## 5. Stories with Acceptance Criteria

### Story 3.1.1: Define Wristband Card Format

**Goal:** Establish and document the canonical card layout so implementation has a precise target.

This spec serves as the format definition. The coach survey requirement (original story) is satisfied by Ken as primary coach and product owner — the format above is the approved output of that consultation.

**Acceptance Criteria:**

- Given this spec exists and is committed, when implementation begins, then the card layout (fields, order, physical dimensions) matches Section 3 of this document without interpretation ambiguity.
- Given a printed card at 3.5"×2.5", when viewed at 18" by a person with average vision, then all text fields (formation name, route digits, play number, concept name if present, Y Motion if present) are legible without magnification.
- Given any play call with a matched concept (e.g., Smash on Twins), when the card is rendered, then the concept name appears on the card and is visually distinct from the formation name and digits.
- Given a play call with Y Motion set to None, when the card is rendered, then no Y Motion field appears (no empty label, no dash).
- Given a play call with Y Motion set to After/Go, when the card is rendered, then "Y Go" (or equivalent short label) appears on the card.
- Given Ken reviews a printed card from a real export, then Ken confirms the format matches coaching intent and the card would be usable on game day. (Sign-off AC — blocks Story 3.1.5.)

---

### Story 3.1.2: Design Export Flow

**Goal:** Specify and validate the UX before implementation so no rework occurs at the UI layer.

**Acceptance Criteria:**

- Given `PlayCallerView` has a valid play call displayed, when the coach looks at the navigation bar, then an export button (share icon) is visible and tappable.
- Given no play call is displayed (app just opened, or after reset), when the coach looks at the navigation bar, then the export button is visible but disabled (grayed out, non-interactive).
- Given the coach taps the export button, when the action sheet appears, then it displays the title "Export Wristband Card" and the current play's display name (formation + digits).
- Given the coach selects "Export as PDF" in the action sheet, when the PDF is generated, then the iOS share sheet appears with print, Files, email, and AirDrop as available activities.
- Given the coach selects "Cancel" in the action sheet, when the sheet dismisses, then the app state is unchanged (play call still displayed, no file generated).
- Given a UX designer reviews the flow (or Ken reviews wireframes/prototype), then the entry point and action sheet are confirmed as intuitive and non-disruptive to the play-building workflow.

---

### Story 3.1.3: Implement PDF Generation

**Goal:** Produce a correctly formatted, printable PDF using PDFKit.

**Acceptance Criteria:**

- Given any valid `PlayCall` object, when `WristbandPDFGenerator.generate(playCall:)` is called, then it returns a non-nil `Data` value representing a valid PDF.
- Given a generated PDF, when opened in any PDF viewer (Files app, Preview on macOS), then the document renders without errors or missing content.
- Given a play call with formation "Twins" and digits "6794", when the PDF is generated, then the card displays: play number "1", formation "Twins", digits "6 7 9 4" (with X Y Z A labels), the mini route diagram, and (if matched) the concept name.
- Given a play call where concept is nil (no match), when the PDF is generated, then no concept name field appears on the card — no blank label, no dash.
- Given a play call with Y Motion = `.stop`, when the PDF is generated, then "Y Stop" appears on the card in the motion field.
- Given a play call with Y Wheel enabled, when the PDF is generated, then the mini diagram renders Y's route as the wheel arc, not a numbered route path.
- Given a generated PDF, when printed at 300 dpi on an 8.5"×11" sheet, then the 2×2 card grid fits within the printable area with 0.25" margins, and all four cards are identical (V1 single-play export repeats the card four times to fill the sheet).
- Given the PDF generation call, when it completes, then no third-party frameworks are imported — only `PDFKit`, `SwiftUI`, `UIKit`, and `Foundation`.
- Given a call to `WristbandPDFGenerator.generate(playCall:)`, when execution completes, then it returns synchronously on the main actor (or is properly async-annotated) without blocking the UI for more than 500ms on an iPhone 13 or later.

**Domain:** PDF/rendering → software-engineer. Print layout validation → sdet.

---

### Story 3.1.4: Add Export UI to PlayCallerView

**Goal:** Wire the export button and action sheet into `PlayCallerView` with correct enable/disable behavior.

**Acceptance Criteria:**

- Given `PlayCallerView` is loaded, when the navigation bar renders, then a share icon button appears at the trailing position, adjacent to "Reset".
- Given `viewModel.currentPlayCall == nil` and `viewModel.currentPlayCallWithMotion == nil`, when the toolbar renders, then the export button has `isEnabled == false` (visually disabled).
- Given a valid play call is present, when the export button is tapped, then an action sheet is presented (not a navigation push, not a modal sheet) with options "Export as PDF" and "Cancel".
- Given "Export as PDF" is selected, when `WristbandPDFGenerator.generate(playCall:)` completes, then `UIActivityViewController` is presented with the PDF data and a default filename of `"[FormationName]-[Digits]-wristband.pdf"`.
- Given the share sheet is presented, when the coach selects Print, then AirPrint dialog appears with the wristband PDF loaded.
- Given the share sheet is presented, when the coach selects Save to Files, then the PDF is saved to the user's selected Files location.
- Given the coach dismisses the share sheet (cancel), when the view returns to `PlayCallerView`, then the play call state is unchanged.
- Given an error occurs during PDF generation, when the error is caught, then an alert is presented with a user-readable message ("Could not generate wristband. Please try again.") — the app does not crash.

**Domain:** UI wiring → software-engineer. Accessibility (button label, disabled state VoiceOver) → ux-designer review. End-to-end share sheet flow → sdet.

---

### Story 3.1.5: Test with Coaches

**Goal:** Validate the exported card in real-world use conditions (print, laminate, sideline) before declaring the epic complete.

**Acceptance Criteria:**

- Given a PDF generated from a real play call, when Ken prints it on a standard inkjet printer (or sends to a print shop), then the physical cards are cut-ready with correct dimensions and bleed.
- Given a printed and laminated card, when Ken reads it under typical outdoor lighting conditions, then all text fields are legible without magnification.
- Given Ken reviews the complete card layout, when comparing it to his existing manual wristband format, then Ken confirms the information is complete and the format is usable without modification.
- Given the exported card, when Ken uses it in a practice session, then play calls are executed correctly using the card — no confusion from missing or ambiguous information.
- Given post-practice feedback, when Ken identifies any critical legibility or format issues, then those issues are either fixed before the epic is closed or documented in the backlog with clear priority and a trigger condition.
- Given Ken signs off on the format, when this AC is confirmed, then the epic is declared complete and "Completed" status is recorded in the backlog.

**Domain:** Coach field validation → product owner (Ken). Any format iteration → software-engineer. Backlog updates → product owner.

---

## 6. Out of Scope

The following are explicitly excluded from Epic 3.1. Anything below that appears in conversations during implementation should be added to the backlog, not to this epic.

| Out-of-Scope Item | Reason / Expected Home |
|-------------------|----------------------|
| Multi-select from a play history list | Requires persistent play storage (separate epic). V2 of export. |
| Play history / playbook persistence | Distinct feature; no data model exists today. |
| Per-card single-page PDF layout | V2 density option. 2×2 grid covers the V1 use case. |
| Cloud sync of plays or PDFs | Explicitly excluded from project non-goals (no backend). |
| Android or web export | Not in scope for iOS-only project. |
| QR code on card linking to digital play | Requires backend; out of scope. |
| Play number managed by the app | Requires play history. V1 defaults to "1". |
| Custom card branding / team logo | Future UX enhancement; not blocking game-day use. |
| PDF password protection | No compliance requirement; adds friction for coaches. |
| Batch export of 8+ plays in one action | Requires multi-select; V2. |
| Watch / iPad optimization | iOS iPhone target only for V1. |

---

## 7. Roles

| Role | Involvement | Phase |
|------|-------------|-------|
| Product Owner | Spec, acceptance sign-off, coach validation (Story 3.1.5), backlog update | Steps 1, 13 |
| UX Designer | Export flow review, accessibility check on toolbar button and action sheet | Step 2 consultation, Step 6 review |
| Software Engineer | PDF generation (`WristbandPDFGenerator`), `PlayCallerView` toolbar and action sheet, `UIActivityViewController` wiring | Step 6 implementation |
| SDET | Test strategy, test plan, E2E validation of export flow (button enabled/disabled, action sheet, share sheet), PDF content validation, test results report | Steps 4, 8 |
| Performance Engineer | PDF generation latency assessment (<500ms target on iPhone 13), memory impact of PDFKit rendering with Canvas-based diagram | Steps 4, 9 |
| Security Engineer | Involvement assessment: PDFKit is on-device only, no credentials, no network; lightweight review. Confirm no PII leakage in PDF metadata. | Steps 2, 10 |
| Architecture / System Design | Review `WristbandPDFGenerator` placement in project structure (Services/ vs new layer); confirm DiagramRenderer reuse or adaptation strategy for PDF context | Step 3 |
| Auditor | Conformance review: spec AC vs shipped artifact | Step 11 |

---

## 8. Success Metrics

The epic is complete when all of the following are observable:

1. **Build gate:** Project compiles without errors or warnings introduced by this epic; all existing tests continue to pass.
2. **Export reachable:** The export button appears in `PlayCallerView` when a play call is displayed; it is disabled when no play call is present.
3. **PDF correctness:** A generated PDF contains all required card fields (play number, formation, route digits, concept name when matched, Y Motion when not None, mini diagram). Verified by SDET automated content check and manual visual inspection.
4. **Print fidelity:** A card printed at 300 dpi on 8.5"×11" produces four legible wristband cards after two cuts, with text readable at 18" by a person with average vision.
5. **Coach sign-off:** Ken confirms in Story 3.1.5 that the exported card is usable on game day — not just technically correct, but coaching-workflow correct.
6. **Share sheet coverage:** At minimum AirPrint, Save to Files, and email are available and functional via the system share sheet.
7. **Performance floor:** PDF generation completes in under 500ms on an iPhone 13 or later (measured by performance-engineer assessment or automated benchmark).
8. **No regressions:** All pre-existing SDET test results remain passing after this epic lands.

---

## 9. Open Questions

These require Ken's input before or during implementation. Items marked **BLOCKING** must be resolved before Story 3.1.3 begins.

| # | Question | Impact | Status |
|---|----------|--------|--------|
| 1 | **BLOCKING:** Should the mini diagram on the card render the post-motion receiver layout (with Y in its final position) or the pre-motion base formation? | Determines which `PlayCall` object (base vs `currentPlayCallWithMotion`) drives the diagram. | Open — recommend post-motion as default; confirm with Ken. |
| 2 | **BLOCKING:** Should the card repeat four times to fill the 2×2 grid (simplest V1), or should V1 produce a single-card page (one card centered on the sheet) and the grid be V2? | Single-card is easier to implement; grid is more useful for printing. This spec recommends grid (4 copies of the same card), but Ken should confirm. | Open — spec recommends 4-up grid; confirm with Ken. |
| 3 | What label should the motion field use? Options: "Y Stop", "Y Go", "Y After/Go", or the full `ReceiverMotion.rawValue`. Short labels are better for card space. | Affects PDF rendering text. | Open — recommend "Y Stop" / "Y Go"; confirm with Ken. |
| 4 | Should the play number on V1 cards be "1" (fixed default), blank (coach writes in), or omitted entirely? | Determines whether the number field appears on V1 cards. | Open — recommend blank/omitted for V1 since no play history exists; confirm with Ken. |
| 5 | Is there a team name, season, or branding element that should appear on cards (e.g., "Spartans" header)? | Optional but affects card layout space allocation. | Open — not required for V1 game-day use; flag as V2 enhancement unless Ken requests it. |
| 6 | What is the target printer? If a specific printer model is known (e.g., a school printer with known DPI), the PDF page size and margin assumptions can be confirmed. | Affects whether 8.5"×11" US Letter is the right page size (vs A4 for international use). | Open — assuming US Letter; confirm with Ken. |

---

## Appendix A: Key Code Touchpoints

Implementation will interact with these existing files:

- `/SpartansPlaycaller/Views/PlayCallerView.swift` — toolbar button addition, action sheet presentation, share sheet presentation
- `/SpartansPlaycaller/ViewModels/PlayCallerViewModel.swift` — read `currentPlayCall` and `currentPlayCallWithMotion` for export state
- `/SpartansPlaycaller/Models/PlayCall.swift` — primary data model passed to PDF generator
- `/SpartansPlaycaller/Services/DiagramRenderer.swift` — reuse or adapt for off-screen Canvas rendering in PDF context
- New: `/SpartansPlaycaller/Services/WristbandPDFGenerator.swift` — PDF generation service (new file, placed in Services/)

`DiagramRenderer` uses SwiftUI Canvas for on-screen rendering. PDF context rendering with PDFKit will require either: (a) rendering the Canvas to an off-screen `UIGraphicsImageRenderer` and embedding the resulting image in the PDF, or (b) re-implementing the draw calls using `CGContext` directly in a `PDFPage` subclass. Architecture consultation (Step 3) should resolve this before implementation.

---

## Appendix B: Non-Goal Restatement

This epic does not implement play persistence, play history, a playbook management screen, cloud storage, or any backend. It takes the currently-displayed play, wraps it in a printable card, and hands it to the iOS share sheet. Scope creep toward "playbook management" should be redirected to a future epic.
