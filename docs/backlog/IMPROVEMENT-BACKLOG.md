# Spartans Playcaller — Comprehensive Improvement Backlog

**Last Updated:** 2026-05-29  
**Audit Status:** Complete (architecture, software-engineer, sdet, ux-designer, technical-researcher)

---

## Executive Summary

This backlog consolidates findings from a **multi-agent audit** of the Spartans Playcaller codebase across five disciplines:

- **Architecture**: Formation system design, route interpretation, concept library structure
- **Software Engineering**: Code quality, technical debt, maintainability
- **SDET**: Test coverage gaps, regression risks, quality gates
- **UX Design**: Coach productivity, play creation flow, wristband export
- **Technical Research**: Y wheel motion, custom routes, formation expansion

The backlog is organized into three pillars aligned with your improvement priorities:

1. **Route/Display Cleanup** — Technical debt and code quality improvements
2. **Broader Feature Coverage** — New formations and custom routes
3. **Coach Productivity** — UX/feature improvements for faster play creation and game-day deployment

**Key Findings:**
- **Wristband export is missing** — blocks game-day deployment; critical for adoption
- **Concept library is hardcoded/imperative** — adds friction when expanding formations
- **Route interpretation lacks extensibility** — blocks custom routes without major refactoring
- **Test coverage is solid for Y motion** (92 tests) but foundational domain logic (routes, concepts, formations) has gaps
- **Empty formation is the next high-ROI formation** to add (low effort, high coaching value)

---

## Epic Organization

### Pillar 1: Route/Display Cleanup

**Goal:** Improve code quality, reduce technical debt, and prepare architecture for growth.

#### Epic 1.1: Extract Route Interpretation Into Strategy Pattern
**Priority:** HIGH  
**Estimated Effort:** 6–8 hours  
**Status:** Pending  
**Trigger:** Before adding custom routes (Y wheel, custom breaks)

**Problem Statement:**
The side-aware route meaning system is embedded in `RouteNumber.meaning(on:)` as a switch statement (27 cases for 9 routes × 3 sides). Adding custom routes requires editing RouteNumber enum and switch logic. Absolute direction routes (3, 4, 7, 8) use a separate logic path, creating maintenance burden.

**Stories:**

- **1.1.1: Define RouteSemanticProvider protocol**
  - Create a pluggable protocol for route interpretation strategies
  - Separate "side-aware" routes (1, 2, 5, 6) from "absolute direction" routes (3, 4, 7, 8)
  - Implement as: `protocol RouteSemanticProvider { func meaning(on: FieldSide) → RouteMeaning }`
  - Acceptance Criteria:
    - Protocol compiles with no errors
    - Existing 9 route numbers have implementations
    - Tests pass for all route × side permutations (30 cases)

- **1.1.2: Refactor RouteNumber to delegate to strategy**
  - Update `RouteNumber.meaning(on:)` to dispatch through RouteSemanticProvider
  - Verify no behavioral change (all tests green)
  - Document integration point for custom routes
  - Acceptance Criteria:
    - RouteNumber.meaning() delegates to provider
    - All 30 route × side permutation tests pass
    - No test changes needed (behavior identical)

- **1.1.3: Document custom route integration**
  - Write architecture note: how to add a new custom route using the strategy pattern
  - Example: Y wheel short-break implementation
  - Acceptance Criteria:
    - Documentation is clear enough for a coach to understand route interpretation model
    - Example code compiles and passes tests

**Success Metrics:**
- Route interpretation logic is extensible without modifying RouteNumber enum
- Adding a new custom route requires <2 hours
- All tests pass; no regressions

---

#### Epic 1.2: Migrate ConceptLibrary to Data-Driven Templates
**Priority:** HIGH  
**Estimated Effort:** 8–10 hours  
**Status:** Pending  
**Trigger:** After Pro formation family stabilizes; before adding 3rd formation family

**Problem Statement:**
All 21 concept templates are hand-coded in `ConceptLibrary.buildTemplates()` as imperative `append()` calls (214 lines). Adding Pro Left/Right required 66-line diffs with repeated boilerplate. No way to validate that all formations have all concepts or to load templates from config.

**Stories:**

- **1.2.1: Define ConceptDefinition data model**
  - Create a `ConceptDefinition` struct: `(concept, formations, receiverRoutes(formation) → [Receiver: RouteNumber])`
  - Separate concept definition from template instantiation
  - Acceptance Criteria:
    - ConceptDefinition compiles
    - Can represent Smash, Dagger, Verts, Scissors, Sail, China with one definition each
    - No duplication across formation contexts

- **1.2.2: Implement template generator**
  - Write a `ConceptLibrary.generateTemplates(from definitions)` function
  - Replace `buildTemplates()` imperative code with data-driven loader
  - Reduce `buildTemplates()` to <50 lines
  - Acceptance Criteria:
    - Generated templates are identical to original (bit-for-bit if possible)
    - All 92 existing tests pass
    - Template count and content verified

- **1.2.3: Add template validation**
  - Implement coverage check: all (concept, formation) pairs have a template, or explicitly marked unavailable
  - Warn if a formation-concept combo is missing unexpectedly
  - Add unit tests for template completeness
  - Acceptance Criteria:
    - Coverage validation passes for all 5 formations × 6 concepts
    - Tests catch if a template is accidentally removed
    - Documentation lists which concepts are available per formation

**Success Metrics:**
- Adding a new formation requires adding 1–2 lines per concept (instead of 8+ boilerplate lines)
- Template coverage is automatically verified
- Config-driven extensibility is in place for future "custom concepts" feature

---

#### Epic 1.3: Unify Concept Matching with TemplateQuery DSL
**Priority:** MEDIUM  
**Estimated Effort:** 4–6 hours  
**Status:** Pending  
**Trigger:** When adding 3rd formation family or new concept query patterns

**Problem Statement:**
`FormationContext` enum conflates formation specification with side filtering. `ConceptMatcher.identify()` has special-case logic for Twins, and `identifyForSide()` duplicates filtering. No composable query pattern.

**Stories:**

- **1.3.1: Define TemplateQuery DSL**
  - Create a `TemplateQuery` struct: `(formation: Formation, side: FieldSide?, concept: RouteConcept?)`
  - Add `ConceptLibrary.templates(matching query)` method
  - Support composable queries (e.g., "all templates for left side across all formations")
  - Acceptance Criteria:
    - Query API is simpler than current special-cased identify() logic
    - Can express: "all concepts in Trips Left", "all left-side templates", "all templates matching concept"
    - No special-case matcher code needed

- **1.3.2: Refactor ConceptMatcher to use TemplateQuery**
  - Replace `identify()` special-case logic with composed queries
  - Remove FormationContext enum or repurpose it
  - Acceptance Criteria:
    - ConceptMatcher.identify() uses queries internally
    - All 92 tests pass
    - Code is simpler (fewer branches, no special cases)

**Success Metrics:**
- New formation families can be added without special-casing the matcher
- Query logic is testable independently of identify()

---

#### Epic 1.4: Implement Route Interpretation Regression Suite
**Priority:** HIGH  
**Estimated Effort:** 1 day  
**Status:** Pending  
**Trigger:** Before expanding formations or custom routes

**Problem Statement:**
RouteInterpreter is partially tested. Missing comprehensive permutation coverage: all 10 route numbers × 3 field sides (30 cases), absolute direction invariants, cross-formation consistency, invalid route rejection, edge cases.

**Stories:**

- **1.4.1: Add RouteNumberInterpretationTests**
  - Unit tests for `RouteNumber.meaning(on:)` covering all 30 route × side permutations
  - Verify absolute direction routes (3, 4, 7, 8) ignore side and always break in named direction
  - Test invalid route digits (10+) rejection and error handling
  - Acceptance Criteria:
    - 25+ parameterized tests, zero skips
    - All 30 permutations explicitly asserted
    - Absolute direction routes verified with invariants
    - 100% green, zero flakes

- **1.4.2: Add FormationConfigurationTests**
  - Unit tests for `Formation.side(for receiver)` and `alignmentOrder` across all 5 formations
  - Verify no receiver appears on multiple sides
  - Test Pro formation specifics (5-receiver subset)
  - Acceptance Criteria:
    - 15+ tests covering all formation × receiver combinations
    - Receiver uniqueness verified per side
    - Pro formation alignment validated

**Success Metrics:**
- Route interpretation is protected by regression tests
- Adding new formations auto-requires test updates (good gate)

---

#### Epic 1.5: Localization & String Constants
**Priority:** MEDIUM  
**Estimated Effort:** 4–6 hours  
**Status:** Pending  
**Trigger:** Before international expansion or string consistency issues emerge

**Problem Statement:**
30+ hardcoded strings scattered across Views and ViewModel ("FORMATION", "CONCEPT", "Motion only available in Trips formations", error messages). No single source of truth; localization blocks.

**Stories:**

- **1.5.1: Define LocalizedStrings struct**
  - Create `struct LocalizedStrings` with all UI text and error messages
  - Organize by feature: formation, concepts, motion, errors, labels
  - Acceptance Criteria:
    - All hardcoded strings identified and replaced
    - Strings are organized logically (not a flat list)
    - No strings remain hardcoded in Views or ViewModel

- **1.5.2: Prepare .strings file structure**
  - Create `Localizable.strings` for base language (English)
  - Structure matches LocalizedStrings struct
  - Document process for App Store localization
  - Acceptance Criteria:
    - .strings file is valid and parses
    - All strings in LocalizedStrings are in .strings file
    - Documentation for translators included

**Success Metrics:**
- All user-facing text is in one place
- Localization to new languages requires only .strings file, no code changes

---

### Pillar 2: Broader Feature Coverage

**Goal:** Expand formations, add custom routes, and support advanced play design.

#### Epic 2.1: Add Empty Formation
**Priority:** HIGH  
**Estimated Effort:** 8–12 hours  
**Status:** Pending  
**Trigger:** Now (highest ROI next step per research)

**Problem Statement:**
Empty (all 4 eligible receivers wide; H removed) is the most prolific pass formation in modern football. Essential for spread offenses, RPOs, short-yardage plays. Current app supports Twins, Trips L/R, Pro L/R only.

**Stories:**

- **2.1.1: Define Empty Formation case and alignment**
  - Add `Formation.empty` enum case
  - Define `alignmentOrder` and `side(for:)` logic: X far left, Y slot-left, Z slot-right, A far right
  - Test alignment against route interpreter (no changes needed to interpreter)
  - Acceptance Criteria:
    - Formation compiles and integrates with existing code
    - Alignment matches modern football Empty spacing (4-wide)
    - `canApplyMotion()` returns true (allows Y motion)

- **2.1.2: Define Empty-specific concepts**
  - Identify and define 6–8 signature Empty concepts: Stick, Double Slant, Dig Cross, High-Low, Smash Spread, Verticals, Four Verts, etc.
  - Map each concept to receiver-route templates
  - Validate with coaches on concept familiarity
  - Acceptance Criteria:
    - 6–8 concepts defined and added to ConceptLibrary
    - Each concept has valid routes for all 4 receivers
    - Concept names match coaching terminology

- **2.1.3: Test Empty formation end-to-end**
  - Create PlayCallFlowTests covering Empty: select formation → parse digits → identify concepts → apply motion → render diagram
  - Verify all receivers assigned correctly
  - Test Y motion in Empty context (should work, spacing allows motion)
  - Acceptance Criteria:
    - 10+ E2E tests covering Empty scenarios
    - All receiver positions verified in diagram
    - Y motion works (Y After/Go in Empty)

**Success Metrics:**
- Coaches can generate plays in Empty formation
- Concept matching works correctly for Empty
- Motion works in Empty context

---

#### Epic 2.2: Add Route Modifiers (Step, Read, Option)
**Priority:** MEDIUM  
**Estimated Effort:** 12–16 hours  
**Status:** Pending  
**Trigger:** After coaches request variants (delay routes, read-based adjustments)

**Problem Statement:**
Coaches often need route variations: delayed breaks (step before cutting), read-based adjustments (adjust on coverage), option routes (two-route choice). Current 0–9 system doesn't express these nuances.

**Stories:**

- **2.2.1: Define route modifier model**
  - Create `enum RouteModifier { case step(Int), read(String), option(RouteNumber) }`
  - Extend `RouteNumber` to support modifiers: `RouteWithModifier` type
  - Document modifier semantics: `.step` = delay X steps before cutting, `.read` = adjust based on coverage, `.option` = receiver's choice
  - Acceptance Criteria:
    - RouteModifier enum compiles
    - Can express "2.step" (Quick Slant with 1-step delay)
    - Modifier semantics documented clearly

- **2.2.2: Update parser to handle modifiers**
  - Extend PlayCallParser to recognize `digit.modifier` syntax (e.g., `6.step`, `4.read`)
  - Add validation: modifier must be valid for the route
  - Error handling for invalid combinations (e.g., `.step` on stationary routes like Hitch)
  - Acceptance Criteria:
    - Parser accepts "6341.step" and interprets as "X:6 Y:3 Z:4.step A:1"
    - Parser rejects invalid modifiers with clear error
    - Tests cover all valid/invalid modifier combinations

- **2.2.3: Update route interpreter and diagram**
  - Extend `RouteInterpreter` to apply modifier semantics (timing, read annotations)
  - Update `DiagramRenderer` to label routes with modifiers (e.g., "4.read" shown as "Dig (Read)" on diagram)
  - Acceptance Criteria:
    - Diagram shows modifier labels (`.step`, `.read`, `.option` icons)
    - Route meaning is unchanged; modifier is metadata
    - All tests pass

**Success Metrics:**
- Coaches can express delayed and adjusted routes without new route numbers
- Diagram clearly shows route variants
- Modifiers enable custom-route design without complexity explosion

---

#### Epic 2.3: Research and Plan Y Wheel Motion
**Priority:** MEDIUM  
**Estimated Effort:** 16–24 hours (research + planning)  
**Status:** Pending  
**Trigger:** After Empty formation ships and coaches request advanced motion

**Problem Statement:**
Y Wheel is an advanced receiver motion (curved arc, often perimeter route, end position defines route interpretation). Unlike Y Stop/After/Go (side-flip), Wheel breaks the side-aware interpretation model. High complexity, medium coaching value.

**Stories:**

- **2.3.1: Research Y Wheel semantics with coaches**
  - Interview 3–5 coaches on Y Wheel usage: formations, route pairings, endpoint positions
  - Document wheel-motion mechanics and integration constraints
  - Validate whether wheel routes should be "side-agnostic" (ignore receiver origin) or "position-based" (route depends on final position)
  - Acceptance Criteria:
    - 5+ wheel concepts documented (e.g., "Wheel Go", "Wheel Slant", "Wheel Corner")
    - Coaching feedback confirms interpretation semantics
    - Uncertainty on exact behavior documented for engineering

- **2.3.2: Design wheel motion architecture**
  - Propose changes to `RouteInterpreter` for wheel-aware interpretation
  - Design diagram rendering for circular arcs (current Bézier curves may not suffice)
  - Document concept matching implications (will wheel concepts be matchable, or require explicit selection?)
  - Acceptance Criteria:
    - Architecture document written and reviewed by architecture-system-design agent
    - Trade-offs documented (e.g., "concept matching disabled for wheel motions")
    - Implementation plan drafted

- **2.3.3: Plan wheel formation support**
  - Define which formations support Y Wheel: Trips, Pro, Empty (spacing-dependent)
  - Update `Formation.canApplyMotion(type)` to return motion-type-specific booleans
  - Acceptance Criteria:
    - Formation constraints documented
    - Implementation plan includes unit tests for motion applicability

**Success Metrics:**
- Coaching requirements for Y Wheel are understood and validated
- Architecture design is approved before implementation
- Implementation plan is detailed and ready for engineering

---

#### Epic 2.4: Expand to Pro Formation-Specific Concepts
**Priority:** MEDIUM  
**Estimated Effort:** 6–8 hours  
**Status:** Pending  
**Trigger:** Before shipping any Pro formation feature

**Problem Statement:**
Pro Left/Right formations were recently added to the codebase (Pro Left, Pro Right). Current concepts (Smash, Dagger, etc.) are defined for Pro, but Pro-specific variations aren't yet documented or fully tested.

**Stories:**

- **2.4.1: Define Pro-specific concept variations**
  - Document Pro-specific versions of existing concepts (e.g., "Pro Smash", "Pro Scissors", "Pro Sail")
  - Identify 2–3 Pro-only concepts that don't work in other formations
  - Validate with coaches
  - Acceptance Criteria:
    - 6–8 Pro concepts defined with receiver-route mappings
    - Concepts are distinct from Twins/Trips versions or clearly documented as identical
    - Coach feedback confirms value

- **2.4.2: Add Pro concepts to ConceptLibrary**
  - Add Pro-specific templates to library
  - Verify ConceptLibrary concept coverage for Pro formations
  - Test end-to-end: select Pro Left → choose concept → verify diagram
  - Acceptance Criteria:
    - All Pro concepts defined and queryable
    - ConceptMatcher identifies concepts correctly in Pro formations
    - Tests pass for Pro formation plays

**Success Metrics:**
- Pro formations are fully functional and match Trips/Twins feature parity
- Coaches can use Pro formations as effectively as Trips

---

### Pillar 3: Coach Productivity & Game-Day Deployment

**Goal:** Enable faster play creation, better UX, and game-day wristband export.

#### Epic 3.1: Wristband Export & Game-Day Deployment
**Priority:** CRITICAL (blocking adoption)  
**Estimated Effort:** 20–24 hours  
**Status:** Pending  
**Trigger:** Now (prerequisite for production deployment)

**Problem Statement:**
Coaches need to export plays in a wristband-ready format (laminated cards worn on arm during games). Without this, the app is a practice-only tool. Wristband export is the difference between "interesting coaching tool" and "deployable game-day system."

**Stories:**

- **3.1.1: Define wristband card format**
  - Survey 2–3 coaches on typical wristband content
  - Document card format: formation, concept name, digit sequence, mini route diagram, notes space
  - Choose format: PDF (printable), image (shareable), or app-specific format
  - Acceptance Criteria:
    - Wristband format document approved by coaches and Ken
    - Layout matches coaching terminology and spacing constraints
    - Card fits on typical wristband (3–4" × 2–3")

- **3.1.2: Design export flow**
  - UX for selecting multiple plays and exporting
  - Options: single-page PDF grid, per-card PDF, or email/iCloud share
  - Integration with Photos app or Files app for easy sharing
  - Acceptance Criteria:
    - Wireframes/mockups for export flow designed
    - Coach feedback confirms usability
    - Integration points identified (print, share, save)

- **3.1.3: Implement PDF generation**
  - Choose or integrate PDF library (PDFKit for iOS)
  - Implement wristband card rendering: formation, concept, digits, mini diagram
  - Add diagrams to PDF (use existing `DiagramRenderer` or adapt for PDF context)
  - Acceptance Criteria:
    - PDF compiles without errors
    - Cards render with correct formatting and spacing
    - Diagrams are legible on small cards

- **3.1.4: Add export UI to PlayCallerView**
  - Add "Export" button or action menu
  - Allow multi-select of plays or export current play
  - Display share/save options (print, email, Files)
  - Acceptance Criteria:
    - UI is accessible and intuitive
    - Export works end-to-end (select plays → generate PDF → share)
    - Coach can print or email wristbands without leaving app

- **3.1.5: Test with coaches**
  - Provide exported wristbands to 2–3 coaches
  - Gather feedback: card legibility, format fit, information completeness
  - Iterate on card design if needed
  - Acceptance Criteria:
    - Coaches successfully use wristbands in practice setting
    - Card format is approved by coaches
    - Feedback indicates feature is game-ready

**Success Metrics:**
- Coaches can generate and print wristbands from app
- Wristband cards are legible and contain necessary information
- Feature unblocks game-day deployment

---

#### Epic 3.2: Concept Discovery & Learning (Guided Onboarding)
**Priority:** HIGH  
**Estimated Effort:** 12–16 hours  
**Status:** Pending  
**Trigger:** Before broader coach adoption

**Problem Statement:**
New coaches struggle with concept discovery. Available concepts are shown as horizontal chips with no descriptions. Coaches don't know what each concept means or why they might choose it. Switching formations clears concept selection without explanation.

**Stories:**

- **3.2.1: Add concept glossary modal**
  - Tap a concept name → modal shows:
    - Concept name and description
    - Receiver roles and route pairings
    - Thumbnail route diagram
    - Coaching notes (when to use, why)
  - Acceptance Criteria:
    - Modal is accessible from concept chips and from a "Glossary" button
    - All 6 concepts have descriptions and thumbnails
    - Content is accurate and coaching-focused

- **3.2.2: Add formation context hints**
  - When switching formation, show tip: "5 concepts available in Trips Left"
  - Highlight available concepts for new formation
  - Explain why concept was cleared (if selected concept unavailable in new formation)
  - Acceptance Criteria:
    - Hints appear on formation change
    - Messages are helpful and non-patronizing
    - Coach can dismiss hints (no forced onboarding)

- **3.2.3: Create onboarding tour (first launch)**
  - Walk new coach through app: select formation → choose concept → view diagram → parse digits
  - Provide skip option for experienced coaches
  - Link to glossary and help
  - Acceptance Criteria:
    - Tour covers all major app features
    - Can be skipped at any step
    - Tutorial is clear and takes <2 minutes

- **3.2.4: Add concept search/filter (optional)**
  - If concept library grows beyond ~10, add search by name or description
  - Filter by route type (e.g., "high-low reads") or formation
  - Acceptance Criteria:
    - Search is intuitive (tap "search", type concept name)
    - Results are relevant and fast

**Success Metrics:**
- First-time coaches can generate a valid play without referring to external docs
- Concept discovery time is reduced
- Coach learning curve is smoother

---

#### Epic 3.3: Motion Diagram Clarity (High-Motion Formations)
**Priority:** HIGH  
**Estimated Effort:** 8–10 hours  
**Status:** Pending  
**Trigger:** Before shipping extensive Y motion feature

**Problem Statement:**
When Y receiver has motion (Y After/Go), the diagram is visually dense. Motion arc (dashed yellow), original position, final position, and route path overlap. Coaches can't quickly distinguish Y's pre-snap setup, motion, and final position.

**Stories:**

- **3.3.1: Add motion type label on arc**
  - Label motion arc with motion type ("Y After", "Y Stop", "Y Go")
  - Use icon or text label
  - Position label so it doesn't obscure route paths
  - Acceptance Criteria:
    - Arc labels are visible and readable
    - Label appears even on small screens (iPhone SE 375pt)
    - Tests verify label positioning doesn't overlap routes

- **3.3.2: Highlight Y final position**
  - Y's final position circle has distinctive style: thicker stroke, glow, or unique color
  - Distinguish from original position (lighter, dashed, or faded)
  - Acceptance Criteria:
    - Final position is visually distinct from original
    - Coaches can quickly identify Y's starting and ending position

- **3.3.3: Add motion legend inset (optional)**
  - Small legend on diagram showing: "Y (yellow) After → right side"
  - Visible only when motion is applied
  - Acceptance Criteria:
    - Legend is optional, unobtrusive
    - Coach can tap to dismiss if not needed

- **3.3.4: Test on small screens**
  - Verify diagram is readable on iPhone SE (375pt width)
  - Dash pattern visibility and label spacing validated
  - Acceptance Criteria:
    - All diagram elements fit without truncation
    - Labels, dashes, and receiver positions are legible
    - Tests pass on all target devices

**Success Metrics:**
- Coaches correctly read Y motion from diagram without re-reading assignment table
- Diagram remains clear even with multiple moving receivers
- Small-screen users (iPhone SE) have equivalent experience

---

#### Epic 3.4: Receiver Assignment Table Usability (Small Screens)
**Priority:** MEDIUM  
**Estimated Effort:** 6–8 hours  
**Status:** Pending  
**Trigger:** After wristband export and motion clarity (lower priority)

**Problem Statement:**
ReceiverAssignmentView is a dense 5-column table (WR #, Side, Route, Motion). On iPhone SE (375pt), columns compress and text truncates. Coaches need to scan routes quickly; table layout requires left-to-right reading and is inefficient on small screens.

**Stories:**

- **3.4.1: Design card-based layout for small screens**
  - Replace table with cards on screens <600pt width
  - Each receiver card shows: WR name + #, Side, Route, Motion indicator
  - Single card per receiver, vertically stacked
  - Acceptance Criteria:
    - Card layout is responsive (table on iPad, cards on iPhone)
    - Information density is reduced but complete
    - Y receiver is visually distinct (highlight for motion applicability)

- **3.4.2: Refactor motion picker placement**
  - Move motion picker out of table (currently in Y row)
  - Place as a separate section above table/cards
  - Label clearly: "Y Motion (Trips/Pro only)"
  - Acceptance Criteria:
    - Motion picker doesn't clutter receiver table
    - Motion is still easy to find and adjust
    - Y receiver highlights when motion is applicable

- **3.4.3: Add receiver grouping/sections (optional)**
  - Group receivers by formation-dependent role (e.g., "Wide Receivers", "Slot", "RB")
  - Help coaches understand formation-specific responsibilities
  - Acceptance Criteria:
    - Grouping is optional, additive
    - Labels are accurate per formation

**Success Metrics:**
- iPhone SE users can quickly scan receiver assignments
- Motion controls are uncluttered
- iPad users still get a dense, efficient table view

---

#### Epic 3.5: Error Feedback and Input Validation
**Priority:** MEDIUM  
**Estimated Effort:** 4–6 hours  
**Status:** Pending  
**Trigger:** After core features (wristband, motion clarity) ship

**Problem Statement:**
Error messages are generic. When a coach enters invalid digits or selects incompatible concepts, feedback is "Cannot generate from X / Y" without context. Coaches don't know if it's format, formation incompatibility, or a concept issue.

**Stories:**

- **3.5.1: Expand error messages with actionable hints**
  - Example: `"Smash + Scissors invalid in Twins: check concept combo"` (instead of generic message)
  - Include formation constraints if concept is unavailable
  - Acceptance Criteria:
    - All common error cases have clear, actionable messages
    - Error messages match coaching domain language
    - Tests verify error message content

- **3.5.2: Add real-time digit validation**
  - As coach enters digits, show inline prompt if <4 digits: "Digits: 4 minimum"
  - Disable "Generate" button until valid input
  - Acceptance Criteria:
    - Validation is non-blocking (user can still type)
    - Prompt updates dynamically as user types
    - Generate button is disabled for invalid input

- **3.5.3: Add "why did this fail?" help**
  - Help icon next to error messages
  - Tap to expand explanation (e.g., "Verts not available in Twins; try Smash or Scissors")
  - Link to concept glossary if needed
  - Acceptance Criteria:
    - Help is accessible and non-intrusive
    - Explanations are clear and coaching-focused

**Success Metrics:**
- Coaches understand why a play didn't generate
- Error recovery time is reduced
- Coaches feel supported, not frustrated

---

#### Epic 3.6: Twins Concept Selection (Chips UI) — Feature Validation
**Priority:** MEDIUM  
**Estimated Effort:** 8–12 hours (design validation + implementation)  
**Status:** Partially Designed (spec exists, implementation pending)  
**Trigger:** Now (spec complete, ready for validation and implementation)

**Problem Statement:**
Twins formation now allows independent concept selection for left and right sides (per `TWINS-CHIPS-SELECTION-SPEC.md`). The feature is designed but not yet implemented. UX risk: coaches may not understand that both sides can run different plays, or chips UI may be confusing.

**Stories:**

- **3.6.1: Design validation with coaches**
  - Show Twins chips mockups to 1–2 coaches
  - Ask them to select left=Smash, right=Scissors, and generate
  - Observe whether they understand left/right independence
  - Gather feedback on chips layout and clarity
  - Acceptance Criteria:
    - Coaches understand left/right independent selection
    - Chips layout is intuitive (no confusion about 2 rows)
    - Mental model aligns with design intent

- **3.6.2: Implement chips UI component**
  - Create `ConceptChipsView` or `SideConceptSelector` component
  - Display left/right concepts in two rows
  - Allow independent selection per side
  - Acceptance Criteria:
    - Component compiles and integrates into PlayCallerView
    - Selection state is tracked independently per side
    - Generate merges left+right concepts into digit sequence

- **3.6.3: Test end-to-end Twins concept flow**
  - Select different concepts on left and right
  - Verify digit sequence merges correctly
  - Verify concept badge display (both concepts show on diagram, or blank if no match)
  - Test parsing and concept re-identification when digits are manually entered
  - Acceptance Criteria:
    - All 20 ACs from spec are satisfied
    - Tests cover independent selection, merge, and re-identification
    - No regressions in Twins formation

**Success Metrics:**
- Coaches can select different concepts on left and right
- Generated digit sequence is correct
- Feature ships with coach validation and approval

---

## Backlog Summary Table

| Epic | Pillar | Priority | Effort | Status | Trigger |
|------|--------|----------|--------|--------|---------|
| 1.1: Route Interpretation Strategy | Cleanup | HIGH | 6–8h | Pending | Before custom routes |
| 1.2: ConceptLibrary Data Migration | Cleanup | HIGH | 8–10h | Pending | After Pro stabilizes |
| 1.3: TemplateQuery DSL | Cleanup | MEDIUM | 4–6h | Pending | On 3rd formation |
| 1.4: Route Interpretation Tests | Cleanup | HIGH | 1d | Pending | Before expansion |
| 1.5: Localization & Strings | Cleanup | MEDIUM | 4–6h | Pending | Before i18n |
| 2.1: Empty Formation | Coverage | HIGH | 8–12h | Pending | Now |
| 2.2: Route Modifiers | Coverage | MEDIUM | 12–16h | Pending | On coach request |
| 2.3: Y Wheel Research & Planning | Coverage | MEDIUM | 16–24h | Pending | After Empty ships |
| 2.4: Pro Concepts | Coverage | MEDIUM | 6–8h | Pending | Now |
| 3.1: Wristband Export | Productivity | **CRITICAL** | 20–24h | Pending | Now |
| 3.2: Concept Discovery & Learning | Productivity | HIGH | 12–16h | Pending | Before adoption |
| 3.3: Motion Diagram Clarity | Productivity | HIGH | 8–10h | Pending | Before Y motion ships |
| 3.4: Receiver Table UX | Productivity | MEDIUM | 6–8h | Pending | Post-wristband |
| 3.5: Error Feedback | Productivity | MEDIUM | 4–6h | Pending | Post-core features |
| 3.6: Twins Chips UI | Productivity | MEDIUM | 8–12h | Pending | Now |

---

## Recommended Roadmap (Priority Order)

### Immediate (Next 2 Weeks)
1. **3.1: Wristband Export** — Unblocks production deployment; critical for adoption
2. **2.1: Empty Formation** — Highest ROI formation; enables modern offense plays
3. **3.6: Twins Chips UI** — Feature design is done; implement and validate

### Near-term (Weeks 3–4)
4. **1.1: Route Interpretation Strategy** — Unblocks custom routes
5. **1.4: Route Interpretation Tests** — Protects against regressions

### Medium-term (Month 2)
6. **1.2: ConceptLibrary Data Migration** — Reduces friction for future formations
7. **3.3: Motion Diagram Clarity** — Improves Y motion usability
8. **3.2: Concept Discovery** — Reduces learning curve for new coaches

### Later (Month 2+)
9. **2.4: Pro Concepts** — Validates Pro formations feature-complete
10. **2.2: Route Modifiers** — On coach request for delayed/read routes
11. **2.3: Y Wheel Research** — After Empty validates formation expansion approach
12. **1.3: TemplateQuery DSL** — When adding 3rd formation family
13. **3.4, 3.5: UX Polish** — After core features ship

---

## Success Criteria (Overall Backlog)

- [ ] Wristband export enables game-day deployment (coaches can print/share plays)
- [ ] Empty formation is available and feature-complete (all concepts, Y motion works)
- [ ] Twins chips UI is validated with coaches and shipped
- [ ] Route interpretation is extensible (custom routes can be added without major refactoring)
- [ ] Test coverage for foundational domain logic (routes, concepts, formations) is comprehensive
- [ ] Concept discovery and learning support are in place (new coaches ramp quickly)
- [ ] Motion diagram is clear and unambiguous (coaches correctly read Y position and motion)
- [ ] Code quality is improved (reduced technical debt, maintainability improved)

---

## Notes

- **Wristband Export is CRITICAL.** Without it, the app is a practice tool, not a game-day system. This should be your first priority after current feature work.
- **Empty Formation is the next high-ROI feature.** Low complexity, high coaching value, enables modern offense plays.
- **Refactoring (1.1, 1.2) unblocks future growth.** Invest in architecture early to reduce friction when adding custom routes and formations.
- **Coach feedback is essential.** Validate Twins chips UI, concept discovery, and wristband format with real coaches before shipping.
- **Y Wheel is high-complexity.** Defer until after Empty formation ships; requires architectural decisions on route interpretation.

---

**Backlog Compiled By:** Multi-Agent Audit (2026-05-29)  
**Reviewed By:** Architecture, Software Engineer, SDET, UX Designer, Technical Researcher  
**Next Review:** After wristband export and Empty formation ship
