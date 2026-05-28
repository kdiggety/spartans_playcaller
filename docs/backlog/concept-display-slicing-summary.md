# Concept Display Feature: Slicing Summary

**Date:** 2026-05-28  
**Status:** Spec Complete — Ready for Design & Engineering Review

---

## Overview

Three spec documents define a unified approach to **side-specific concept display** for both Twins formations (explicit chips selection) and Trips formations (implicit Y motion re-evaluation).

---

## Spec Files

1. **`docs/superpowers/specs/TWINS-CHIPS-SELECTION-SPEC.md`**
   - Twins formation: Independent left/right concept selection via chips UI
   - Merge templates into single digit sequence on "Generate"
   - Display both concepts (or blank if no match)
   - LOE: 8–12 hours

2. **`docs/superpowers/specs/TRIPS-YMOTION-CONCEPT-DISPLAY-SPEC.md`**
   - Trips formation: Y motion triggers automatic concept re-identification
   - Y Stop keeps Y on same side; Y After/Go flip to opposite side
   - Both concepts display after motion (or blank if no match)
   - LOE: 4–6 hours (assumes Y Motion Phases 1–3 done)

3. **`docs/superpowers/specs/CONCEPT-DISPLAY-CLARIFICATIONS.md`**
   - 12 open questions answered with clear decisions
   - Unified display pattern for both formations
   - Architecture notes for implementation
   - Reference document for both engineering and design

---

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| **No fallback text** | Coaches read blank as "no match"; clearer than "—" |
| **Independent left/right** | Can select same concept on both sides (full-field plays) |
| **Display between diagram & table** | Natural flow: visual → high-level → details |
| **Re-ID on motion** | Motion is structural change; concepts must reflect new sides |
| **Chips only show available concepts** | Filter by formation and side in UI |
| **Single digit sequence from chips** | Merge left+right templates; not two separate calls |
| **Motion resets on parse** | Fresh parse = fresh motion state |

---

## Unified Display Pattern

```
Twins with Chips:
  Chips UI (left/right selection) 
  → Concept Badge Row (both concepts or blank)

Trips with Y Motion:
  Motion Picker (Stop/After/Go)
  → Concept Badge Row (re-ID'd concepts or blank)

Both:
  ConceptBadgeRow component: LEFT=[concept or blank], RIGHT=[concept or blank]
  No fallback text; blank = "not identified"
```

---

## Acceptance Criteria Summary

**Twins Chips (20 ACs across both specs):**
- AC1: Chips render in two rows (left/right)
- AC2: Independent selection per side
- AC3: Generate merges templates into digit sequence
- AC4: Badge display (no fallback text)
- AC5: Parsing identifies concepts per side
- AC6–8: Formation validation, invalid combos handled

**Trips Y Motion (10 ACs):**
- AC1: Motion picker in Trips only
- AC2–3: Y Stop keeps same side; Y After/Go flip
- AC4–5: Concept re-ID and badge display
- AC6–10: Motion reset, formation validation, Y receiver only

**Display (All scenarios):**
- No "—", no "Unknown"
- Left and right badges update independently
- Blank = not identified (semantic clarity)

---

## Implementation Roadmap

### Phase 1: Design Review (UX Designer)
- [ ] Confirm chips visual design (colors, spacing, selected/unselected states)
- [ ] Confirm concept badge row styling and placement
- [ ] Review both Twins and Trips mocks with badges

### Phase 2: Spec Review (Coach & Ken)
- [ ] Confirm Twins chips workflow and generation semantics
- [ ] Confirm Trips Y motion concept re-ID expectations
- [ ] Validate no gaps in feature scoping

### Phase 3: Engineering Review (Software Engineer)
- [ ] Align with Y Motion Implementation Plan (Phases 1–7)
- [ ] Confirm ConceptMatcher.identifyForSide() method signature
- [ ] Plan Twins chips merge algorithm
- [ ] Estimate final LOE

### Phase 4: Test Strategy (SDET + Performance Engineer)
- [ ] Define test matrix for Twins chips combinations
- [ ] Define test matrix for Trips Y motion combinations
- [ ] Performance benchmarks (badge rendering, concept matching)

### Phase 5: Implementation
- **Option A (Unified):** Single slice covering both Twins and Trips display (12–18 hours)
- **Option B (Staggered):** Twins chips first (8–12h), then Trips display (4–6h)
  - Recommended if engineering bandwidth is constrained
  - Trips relies on Y Motion Phases 1–3 (assumed done)

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Chips selection UI too cramped on small screens | Test on iPhone SE (375pt); use scrollable row if needed |
| Concept merger algorithm has edge cases (duplicate routes) | ConceptLibrary templates already validated; merge is deterministic |
| Motion breaks left-side concept; coaches confused | UX educates that blank = "concept broken by motion"; docs explain |
| Y motion + concept re-ID performance | Concept matching is O(n) templates (~20); no perf risk |

---

## Questions for Stakeholders

**For Ken (Product Authority):**
- [ ] Confirm Twins chips selection adds customer value (vs. manual digit entry)
- [ ] Confirm motion + concept re-ID workflow matches coaching intent
- [ ] Approve both slices to ship, or prioritize one first?

**For UX Designer:**
- [ ] Chips layout: single row, two rows, or scrollable?
- [ ] Badge row: chevrons ( < > ) or arrow icons or labels?
- [ ] Motion arc visual: what color/style for dashed line?

**For Coach:**
- [ ] Do you want chips UI? (faster selection vs. typing digits?)
- [ ] Does concept re-ID on Y motion make sense for audibles?
- [ ] Any edge cases I haven't covered?

---

## Files to Review

**Specifications:**
- `/docs/superpowers/specs/TWINS-CHIPS-SELECTION-SPEC.md` (coach-facing, 10 ACs, design decisions)
- `/docs/superpowers/specs/TRIPS-YMOTION-CONCEPT-DISPLAY-SPEC.md` (coach-facing, 10 ACs, design decisions)
- `/docs/superpowers/specs/CONCEPT-DISPLAY-CLARIFICATIONS.md` (technical reference, Q&A)

**Related:**
- `/docs/implementation-plans/Y-RECEIVER-MOTION-IMPLEMENTATION.md` (existing; Phases 1–7 cover display layer)
- `/SpartansPlaycaller/Services/ConceptLibrary.swift` (already has side-specific templates)
- `/PROJECT_CONTEXT.md` (domain, formations, receiver nomenclature)

---

## Next Phase: Design Consultation

Recommended: Dispatch **UX Designer** to provide:
- Visual mocks for chips UI (Twins)
- Visual mocks for concept badge row (both formations)
- Motion arc styling (Trips)
- Responsive design notes for small screens

After UX design is locked, proceed to **software-engineer** for implementation.

