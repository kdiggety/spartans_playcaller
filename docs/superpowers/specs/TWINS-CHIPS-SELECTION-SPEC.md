# Twins Formation Side-Specific Concept Selection
## Product Specification

**Status:** Ready for Review  
**Created:** 2026-05-28  
**Owner:** Product

---

## Problem & Value

**Problem:** In Twins formations, the left and right sides run *different concepts* because receivers on each side are different (left side = X, Y; right side = Z, A). Currently, coaches select one concept for the entire play, which doesn't reflect the true left/right split.

**Value:** 
- Coaches can now design plays where left and right sides run completely different concepts (e.g., left runs *Smash*, right runs *Scissors*).
- Clearer play design that matches actual game intent on field.
- Faster playcalling: one tap per side instead of memorizing digit sequences.

**Coach Use Case:** "I want left receivers running a smash concept and right receivers running a scissors concept, all in one play call."

---

## Scope: What Ships in This Slice

**In scope:**
- Twins formation concept selection using chips UI (left and right side independent selection)
- Display identified concepts (left chip area, right chip area) when they match
- No fallback text ("—", "Unknown") when no concept matches
- Generate play call with both concepts applied to same digit sequence
- Parsing: display matched concepts per side even if only one side matches

**Out of scope:**
- Trips formations + Y motion concept display (separate slice)
- Audible calls per side (future)
- Persistent concept selection / playbook saving (future)
- Drag/drop concept editor (future)

---

## Design Decisions

### 1. Chips UI Layout (Coach-Facing)

**Location:** In the concept selection area (replacing or alongside the current concept picker)

**Visual Layout:**
```
┌─ Concept Selection ──────────────────────┐
│                                          │
│ Left Side Concepts                       │
│ ◉ Smash    ○ Dagger    ○ Scissors ○ Sail │
│                                          │
│ Right Side Concepts                      │
│ ○ Smash    ○ Dagger    ◉ Scissors ○ Sail │
│                                          │
└──────────────────────────────────────────┘
```

**Chip Behavior:**
- Each chip is tappable
- Only one concept selected per side (radio-button logic)
- Chips are labeled with concept name (Smash, Dagger, Scissors, Sail, China, Verts)
- When a chip is selected, it fills (circle icon ◉) and shows the concept name

**Why chips instead of dropdowns?**
- Faster visual scanning for coaches
- Tap-friendly on small screens
- Shows all options at once (faster decision-making)
- Matches modern mobile app patterns

---

### 2. Constraint: Independent Left & Right Selection

**Constraint:** Left and right sides are selected *independently* — both sides can have the SAME concept selected.

**Example Plays:**
- Left = Smash, Right = Smash (entire play is Smash-Smash)
- Left = Smash, Right = Scissors (mixed concept)
- Left = Dagger, Right = Dagger (entire play is Dagger-Dagger)

**Rationale:** Coaches often run the same concept on both sides. Forcing different concepts would be unnecessary and confusing.

---

### 3. Generation & Play Call Behavior

**When coach taps "Generate Play Call":**

The app creates a single digit sequence by **combining the templates for both selected concepts**.

**Algorithm:**
1. Look up the template for left-side concept in Twins formation
2. Look up the template for right-side concept in Twins formation
3. Merge the digit assignments: left-side routes (X, Y) from left template + right-side routes (Z, A) from right template
4. Create a single 4-digit sequence and PlayCall
5. Generate button creates play with `leftSideConcept` and `rightSideConcept` both set for display

**Example:**
- Coach selects: Left = Smash, Right = Scissors
- Smash template (Twins Left): X=6, Y=7
- Scissors template (Twins Right): Z=7, A=8
- **Generated digit sequence:** 6778 (X=6, Y=7, Z=7, A=8)
- **Generated PlayCall:** formation=Twins, routeDigits="6778", leftConcept=Smash, rightConcept=Scissors

**What displays after generation?**
- Route diagram with all 4 receivers and routes
- Receiver assignment table showing all 4 assignments
- **Concept badge row:** Shows "Smash" on left, "Scissors" on right (two separate badges)

---

### 4. Display Semantics: "No Fallback Text"

**Rule:** If a concept doesn't match on a side, **nothing displays** for that side — no "—", no "Unknown".

**Example 1: Parse "6778" in Twins**
```
Generated: Left = Smash, Right = Scissors
Both concepts identified.
Display:
  Left Badge: ✓ Smash
  Right Badge: ✓ Scissors
```

**Example 2: Coach manually enters "6794" in Twins (mismatched template)**
```
Parsed: X=6, Y=7, Z=9, A=4
Left side (X=6, Y=7): Matches Smash template → Smash
Right side (Z=9, A=4): Does NOT match any template → nil
Display:
  Left Badge: ✓ Smash
  Right Badge: [blank — no display]
```

**Example 3: Neither side matches**
```
Parsed: X=1, Y=1, Z=1, A=1 (not a real concept)
Left side (X=1, Y=1): No match → nil
Right side (Z=1, A=1): No match → nil
Display:
  Concept Badge Row: [hidden or minimal display]
  (or shows: "No concepts identified" in light gray)
```

**Why no fallback text?**
- Coaches want to see what's identified; blank = "not a known concept"
- Avoids confusion of "—" meaning "not matched" vs. "intentionally left blank"
- Cleaner, less cluttered UI

---

### 5. Chips Selection → Display Pipeline

**Workflow: Coach selects concepts and generates play**

```
Coach selects Left=Smash, Right=Scissors
         ↓
Coach taps "Generate"
         ↓
Merge templates: X=6, Y=7, Z=5, A=8
         ↓
Create PlayCall with routeDigits="6758"
         ↓
Store leftSideConcept=Smash, rightSideConcept=Scissors in ViewModel
         ↓
Display:
  - Route Diagram (all 4 receivers, all routes)
  - Receiver Assignments Table (X=6, Y=7, Z=5, A=8)
  - Concept Badge Row (left="Smash", right="Scissors")
```

---

### 6. Parsing: Side-Specific Concept Detection

**When coach manually enters digits (e.g., "6778") or parses:**

1. Parser interprets digits to receiver assignments (X, Y, Z, A)
2. **Concept Matcher** independently identifies concepts for left and right sides:
   - Left side: Filter assignments to X, Y (left-side receivers) → try to match left-side templates
   - Right side: Filter assignments to Z, A (right-side receivers) → try to match right-side templates
3. Store identified concepts in ViewModel: `leftSideConcept`, `rightSideConcept`
4. Display both badges (or blank if no match)

**Implementation:** Concept Matcher has new method `identifyForSide(side: FieldSide, assignments: [RouteAssignment]) -> RouteConcept?` that filters templates by side and formation.

---

## Acceptance Criteria

### AC1: Chips UI Renders Correctly
- **Given** Twins formation selected
- **When** Concept selection area is displayed
- **Then** Two rows of chips appear:
  - Row 1: "Left Side Concepts" with chips for [Smash, Dagger, Scissors, Sail, China, Verts]
  - Row 2: "Right Side Concepts" with chips for [Smash, Dagger, Scissors, Sail, China, Verts]
- **And** Each chip shows concept name and is tappable
- **And** Selected chip shows filled circle (◉); unselected shows empty (○)
- **Test:** SwiftUI Preview renders correctly on iPhone SE (375pt width) without truncation

### AC2: Independent Left/Right Selection
- **Given** chips UI displayed
- **When** coach taps "Smash" on left side
- **Then** left-side Smash chip fills (◉)
- **And** right-side remains unchanged
- **When** coach then taps "Scissors" on right side
- **Then** left-side Smash stays filled; right-side Scissors fills
- **And** both selections are independent and simultaneous
- **Test:** Unit test verifies state separation (`leftSideConceptSelection`, `rightSideConceptSelection`)

### AC3: Generate Play Call with Both Concepts
- **Given** chips UI with Left=Smash, Right=Scissors selected
- **When** coach taps "Generate"
- **Then** Smash template (X=6, Y=7) + Scissors template (Z=7, A=8) are merged
- **And** digit sequence generated is "6778" (X=6, Y=7, Z=7, A=8)
- **And** PlayCall created with `leftSideConcept=Smash`, `rightSideConcept=Scissors`
- **And** route diagram renders all 4 receivers with assigned routes
- **Test:** Integration test: Generate from Left=Dagger + Right=Verts; verify digit sequence matches expected templates

### AC4: Concept Badge Display (No Fallback Text)
- **Given** PlayCall with identified concepts (either from chips selection or parsing)
- **When** route result is displayed
- **Then** Concept Badge Row shows:
  - Left side: Concept name if identified; [blank/nothing if not]
  - Right side: Concept name if identified; [blank/nothing if not]
- **And** No "—" or "Unknown" text appears
- **And** Only identified concepts render (e.g., if left=Smash, right=nil, only Smash badge shows)
- **Test:** Visual test with various parse results; verify no fallback text in any state

### AC5: Parsing Identifies Concepts Per Side
- **Given** coach manually enters digits (or generates from chips)
- **When** digit sequence is parsed into assignments
- **Then** Concept Matcher identifies concepts separately per side:
  - Left side filter: X, Y receivers only
  - Right side filter: Z, A receivers only
- **And** `leftSideConcept` and `rightSideConcept` are set independently
- **Test:** Parse "6794" in Twins; identify left-side concept (if matches), right-side concept (if matches); verify both are queried independently

### AC6: Chips Selection Only in Twins
- **Given** Twins formation selected
- **When** concept selection area is displayed
- **Then** chips UI appears
- **Given** formation changes to Trips Left or Trips Right
- **When** formation is updated
- **Then** chips UI is hidden OR replaced with single-concept picker (TBD by UX designer)
- **Test:** Formation change hides chips UI for non-Twins formations

### AC7: Invalid Concept Selection Prevented
- **Given** chips UI displayed
- **When** coach selects a combination (e.g., Left=Smash, Right=Scissors)
- **And** those templates exist in ConceptLibrary
- **When** "Generate" is tapped
- **Then** digit sequence is successfully generated (no error)
- **Given** coach manually enters digits that don't match templates on both sides
- **When** digit sequence is parsed
- **Then** identified concepts reflect what matches (left and right independently)
- **And** No error is displayed if one or both sides don't match
- **Test:** Integration test: Parse invalid digit sequences; verify graceful fallback to partial identification

### AC8: Formation Validation (Chips Only in Twins)
- **Given** current formation is Twins
- **When** chips UI is active
- **And** formation is changed to Trips Left
- **Then** chips UI is disabled or hidden
- **And** motion picker appears instead (if implementing Y motion concurrently)
- **Test:** Formation change event disables/hides chips UI per formation

---

## Roles & Dependencies

| Role | Task |
|------|------|
| **UX Designer** | Finalize chip visual design (colors, spacing, selected/unselected states); confirm layout for concept badge row |
| **Software Engineer (iOS)** | Implement chips selection logic, concept merger algorithm, badge display; integrate with ViewModel |
| **SDET** | Write regression tests for chips selection, parsing, and concept identification per side |
| **Performance Engineer** | Verify no jank when tapping chips or rendering badges; confirm diagram renders efficiently |
| **Security Engineer** | Validate no injection vectors in manually entered digit sequences (already covered, but confirm) |

---

## Out of Scope Notes

**Trips + Y Motion:** Separate feature slice. Will use the same `leftSideConcept` / `rightSideConcept` display pattern but with motion re-evaluation.

**Playbook Persistence:** Not part of this slice. Chips selection is session-only (until Save Playbook feature ships).

**Audible Calls:** Future enhancement. Coaches might send different calls to left/right groups with motion. Out of scope for this slice.

---

## Questions for Clarification (Answered Above)

1. **"What should the chips UI look like?"** → Two rows of tappable concept chips per side (AC1)
2. **"Can both sides have the SAME concept?"** → Yes, independent selection (AC2)
3. **"When user selects left=Smash and right=Scissors, what happens?"** → Generate merges templates, creates single digit sequence with both concepts stored (AC3)
4. **"Parsing: left matches, right doesn't. What displays?"** → Only left badge shows; right is blank (AC4, AC5)
5. **"What if neither side matches?"** → No concept badges displayed; play shows only digit assignments (AC4)

---

## Success Metrics

- **Coaches can generate plays with independent left/right concepts in <5 taps**
- **All identified concepts display correctly (no fallback text)**
- **Chips selection works on iPhone SE (smallest target screen)**
- **No regressions in existing parse/diagram/generation workflows**
- **Unit + integration test coverage ≥90% for new code**

---

## Implementation Notes

**Files to create/modify:**
- `Models/TwinsSideSelection.swift` (new) — left/right concept selections
- `ViewModels/PlayCallerViewModel.swift` (modify) — add left/right concept state
- `Views/ConceptChipsSelectionView.swift` (new) — chips UI component
- `Views/ConceptBadgeRow.swift` (new) — display identified concepts
- `Services/ConceptMatcher.swift` (modify) — add `identifyForSide()` method
- `Services/ConceptTemplateResolver.swift` (new) — merge left+right templates for generation

**Test files:**
- `SpartansPlaycallerTests/TwinsConcepctSelectionTests.swift`
- `SpartansPlaycallerTests/ConceptBadgeTests.swift`

---

## Timeline

**Estimated LOE:** 8–12 hours  
**Breakdown:**
- Chips UI component: 2–3 hours
- Concept merger algorithm: 1.5–2 hours
- ViewModel state + parsing integration: 2–3 hours
- Concept Badge Row display: 1–1.5 hours
- Tests + preview refinement: 1.5–2 hours

**Recommended:** 2–3 days at steady pace, or 1 day with pair programming.

---

## Review Checklist

- [ ] UX designer confirms chips layout and visual design
- [ ] Coach confirms value prop and use case
- [ ] All ACs are testable and measurable
- [ ] No dependencies on unshipped features (Y motion is separate slice)
- [ ] Parsing behavior is clearly defined and matches existing semantics
- [ ] Concept merger algorithm handles all combinations without errors

