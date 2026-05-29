# Concept Display Architecture: Clarifications & Decisions

**Date:** 2026-05-28  
**Purpose:** Answer open questions from original Y Motion Implementation Plan; define unified display pattern for both Twins and Trips formations.

---

## Question 1: Show concepts ONLY when they match. No fallback text.

**Decision:** CONFIRMED ✓

- When a concept matches on a side, display the badge with concept name
- When no concept matches, display **nothing** — blank space, no "—", no "Unknown"
- If both sides fail to match, the entire Concept Badge Row may be hidden or show "No concepts identified" in light gray

**Implementation:**
```swift
// In ConceptBadgeRow.swift
if let concept = leftSideConcept {
    ConceptBadge(concept: concept)  // Display badge
} else {
    // Display nothing — empty space or omit from layout
}

// Not:
Text(leftSideConcept?.rawValue ?? "—")  // ❌ Don't do this
```

**Rationale:** 
- Coaches are familiar with "no match = blank" from manual play calling
- Reduces UI clutter; blank is unambiguous ("not a known concept")
- Prevents confusion of "—" being mistaken for a partial concept

---

## Question 2: For Trips + Y motion, should original concept badge disappear when motion breaks it?

**Decision:** YES, original concept disappears; new ones may appear.

**Workflow:**

```
Base State (Trips Left Smash):
  Display: LEFT="Smash", RIGHT=[blank]

User taps Y After motion:
  Left-side concept breaks (Y moved out)
  Display: LEFT=[blank], RIGHT=[if matched after re-ID]

User taps Y Stop motion:
  Left-side concept may remain or change
  Display: Updated based on new left-side group
```

**Why?** 
- Motion is a STRUCTURAL change (Y's side flips), not a visual adjustment
- If motion breaks a concept, showing the old badge would be misleading
- Blank = "concept not identified on this side" is the correct semantic

**Caveat:** If Y Stop is applied (Y stays same side), the original concept likely persists. This is correct behavior.

---

## Question 3: Parsing behavior with side-specific matching

**Decision:** Always query BOTH sides independently, even if only one matches.

**Algorithm for Parsing:**

```
Parse "6794" in Trips Left:

1. Interpret digits → X=6, Y=7, Z=9, A=9
2. Calculate base side for each receiver (per formation)
   X=6 (left), Y=7 (left), Z=9 (right), A=9 (right)
3. Apply motion if any (e.g., Y After → Y moves to right)
4. Group by final side:
   Left: [X=6]
   Right: [Y=7, Z=9, A=9]
5. Identify concepts per side:
   Left: ConceptMatcher.identifyForSide(.left, [X=6], formation=.tripsLeft) → nil
   Right: ConceptMatcher.identifyForSide(.right, [Y=7, Z=9, A=9], formation=.tripsLeft) → nil (wrong side)
6. Store:
   leftSideConcept = nil
   rightSideConcept = nil
7. Display:
   LEFT=[blank]
   RIGHT=[blank]
```

**Key Point:** ConceptMatcher.identifyForSide() filters templates by BOTH formation AND side. Querying Trips Left with right-side receivers doesn't match Trips Right templates.

---

## Question 4: Concept Display Location (Diagram vs. Assignments Table)

**Decision:** Between diagram and assignments table.

**Visual Layout (PlayCallerView):**

```
┌────────────────────────────────────┐
│       ROUTE DIAGRAM (Canvas)       │
│     (4 receivers, all routes)      │
└────────────────────────────────────┘

┌────────────────────────────────────┐
│   CONCEPT BADGE ROW (NEW)          │
│  ← SMASH        SCISSORS →         │
│  (left concept) (right concept)    │
└────────────────────────────────────┘

┌────────────────────────────────────┐
│    RECEIVER ASSIGNMENTS TABLE      │
│  WR  #   Side   Route              │
│  X   6   Left   Curl               │
│  Y   7   Right  Corner             │
│  ...                               │
└────────────────────────────────────┘
```

**Why this placement?**
- Diagram gives coaches visual context (all 4 receivers, routes)
- Badges answer the semantic question: "What concepts are running?"
- Assignments table shows low-level details (if needed)
- Natural reading order: visual → high-level → details

---

## Question 5: Twins Chips Selection → Digits Merge Algorithm

**Decision:** Chips selection → Merge templates → Generate single digit sequence.

**Algorithm:**

```
Input: Left chip = Smash, Right chip = Scissors (in Twins formation)

1. Look up template for Smash in Twins Left:
   { X: .six, Y: .seven }

2. Look up template for Scissors in Twins Right:
   { Z: .seven, A: .eight }

3. Merge receiver → route mappings:
   Combined: { X: .six, Y: .seven, Z: .seven, A: .eight }

4. Create digit sequence:
   routeDigits = "6778" (reading X, Y, Z, A order)

5. Create PlayCall:
   PlayCall(
     formation: .twins,
     routeDigits: "6778",
     assignments: [X=6, Y=7, Z=7, A=8],
     leftSideConcept: .smash,
     rightSideConcept: .scissors
   )

6. Store concepts in ViewModel for display:
   leftSideConcept = .smash
   rightSideConcept = .scissors

7. Display:
   Concept Badge Row: LEFT="Smash", RIGHT="Scissors"
```

**Validation:**
- Both templates must exist in ConceptLibrary
- Merged sequence is always 4 digits (Twins always has X, Y, Z, A)
- If a side's chip is "None" or unselected, skip that side's template merge (future: allow partial selection)

---

## Question 6: Can Same Concept Appear on Both Sides?

**Decision:** YES, allowed in both Twins and Trips.

**Example: Twins Smash-Smash**
```
Left chip: Smash (X=6, Y=7)
Right chip: Smash (Z=5, A=8)
Merged: { X: .six, Y: .seven, Z: .five, A: .eight }
routeDigits = "6758"
Display: LEFT="Smash", RIGHT="Smash"
```

**Why allow?**
- Coaches often send same concept to both sides (runs full-field Smash)
- Simpler than enforcing uniqueness
- ConceptLibrary already has both left-side and right-side Smash templates

---

## Question 7: What if Chips Selection Doesn't Have a Template?

**Decision:** Error message or prevent selection of unavailable combinations.

**Approach (preferred):** Chips should only show concepts that exist for that side in the current formation.

**Example: Twins formation**
```
Left chips: [Smash, Dagger, Scissors, Sail, China, Verts]
  (only those with Twins Left templates)
Right chips: [Smash, Dagger, Scissors, Sail, China, Verts]
  (only those with Twins Right templates)

If a concept doesn't exist for Twins Left, don't show it in left chips.
```

**Fallback:** If user manually creates an invalid combo (shouldn't happen with UI constraints), error message: "Concept not available in this formation for this side."

---

## Question 8: Re-Identification Trigger (When is identifyForSide() called?)

**Decision:** Called automatically whenever:

1. **PlayCall is parsed or generated** (ViewModel.parseRouteDigits() or generateFromConcept())
2. **Y motion is applied or changed** (ViewModel.motionChanged())
3. **Formation changes** (ViewModel.formationChanged())
4. **Chips selection changes** (ViewModel.tappedConceptChip(side:concept:))

**Implementation:**

```swift
// In PlayCallerViewModel
@Published var currentPlayCall: PlayCall?
@Published var yMotion: ReceiverMotion = .none
@Published var leftSideConcept: RouteConcept?
@Published var rightSideConcept: RouteConcept?

// Helper method
private func reidentifyConceptsBySide() {
    guard let playCall = currentPlayCall else { 
        leftSideConcept = nil
        rightSideConcept = nil
        return 
    }
    
    // Apply motion if any
    let assignments = applyMotionToAssignments(playCall.assignments)
    
    // Group by final side and identify
    leftSideConcept = interpreter.identifyForSide(.left, assignments: assignments, formation: playCall.formation)
    rightSideConcept = interpreter.identifyForSide(.right, assignments: assignments, formation: playCall.formation)
}

// Called from:
func parseRouteDigits() {
    currentPlayCall = parser.parse(...)
    reidentifyConceptsBySide()
}

func motionChanged(_ motion: ReceiverMotion) {
    yMotion = motion
    reidentifyConceptsBySide()
}

func formationChanged() {
    // Reset motion if needed, then re-ID
    if !selectedFormation.canApplyMotion() { yMotion = .none }
    reidentifyConceptsBySide()
}
```

---

## Question 9: Concept Library: Does It Need Side Annotations?

**Decision:** YES, templates already have FormationContext with side info; no changes needed.

**Current structure:**
```swift
ConceptTemplate(
    concept: .smash,
    formationContext: .twinsLeft,  // Already specifies the side!
    receiverRoutes: [.X: .six, .Y: .seven]
)
```

**FormationContext already encodes:**
- Formation (.twins, .tripsLeft, .tripsRight, etc.)
- Side implicitly (twinsLeft = left side of Twins, twinsRight = right side)

**No action needed** — ConceptMatcher.identifyForSide() uses existing structure.

---

## Question 10: Fallback When Parsing Digits with Y Motion Already Applied

**Decision:** Re-parse without preserving motion; motion resets to .none.

**Workflow:**
```
User in Trips Left with Y After motion applied
User enters new digit sequence "5738"
→ parseRouteDigits() called
→ yMotion reset to .none (fresh parse)
→ New assignments parsed
→ reidentifyConceptsBySide() called (motion = .none)
→ Concepts identified for base sides

Alternative: Preserve motion state across parse?
  ✗ Confusing — user expects fresh parse
  ✗ Ambiguous if new routes break existing motion
```

**Implementation:**
```swift
func parseRouteDigits() {
    guard !routeDigitInput.isEmpty else { return }
    
    yMotion = .none  // Reset motion on fresh parse
    currentPlayCall = parser.parse(routeDigitInput, formation: selectedFormation)
    reidentifyConceptsBySide()
}
```

---

## Question 11: Concept Badge Row Component: Signature

**Decision:** Stateless component that receives concepts and motion state.

```swift
struct ConceptBadgeRow: View {
    let leftConcept: RouteConcept?
    let rightConcept: RouteConcept?
    let hasMotion: Bool  // For optional "Motion Applied" indicator
    
    var body: some View {
        VStack(spacing: 12) {
            if leftConcept != nil || rightConcept != nil {
                HStack(spacing: 16) {
                    // Left chevron
                    Text("<").font(.title2.bold()).foregroundStyle(.secondary)
                    
                    // Left badge or blank
                    if let concept = leftConcept {
                        ConceptBadge(concept: concept)
                    } else {
                        Spacer()  // Blank space, not text placeholder
                    }
                    
                    // Right badge or blank
                    if let concept = rightConcept {
                        ConceptBadge(concept: concept)
                    } else {
                        Spacer()
                    }
                    
                    // Right chevron
                    Text(">").font(.title2.bold()).foregroundStyle(.secondary)
                }
                
                if hasMotion {
                    Text("Motion Applied").font(.caption).foregroundStyle(.orange)
                }
            } else {
                Text("No concepts identified")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
```

---

## Question 12: Should Concept Display Be Hidden in Twins Chips Mode?

**Decision:** NO, show badges in both modes.

**Display Consistency:**
```
Twins with Chips Selection:
  - Show chips for manual selection
  - Show badges to confirm what was selected/parsed

Twins without Chips (fallback):
  - Show badges only (no chips)

Trips with Y Motion:
  - Show motion picker
  - Show badges (re-identified after motion)
```

**Rationale:** Badges are the output; chips are the input. Both can coexist.

---

## Summary: Unified Concept Display Pattern

| Scenario | Selection | Display |
|----------|-----------|---------|
| Twins + chips selection | Left/Right chips UI | Concept badges (left, right) |
| Twins + manual parse | Digit input | Concept badges (left, right) |
| Trips + base parse | Digit input | Concept badges (left, right) |
| Trips + Y motion applied | Motion picker | Concept badges (re-ID'd left, right) + motion arc |
| No matches | — | No badges (blank or "No concepts" text) |

**Key Principle:** Always show identified concepts when they exist; never show fallback text.

---

## Files Affected

**New:**
- `docs/superpowers/specs/TWINS-CHIPS-SELECTION-SPEC.md`
- `docs/superpowers/specs/TRIPS-YMOTION-CONCEPT-DISPLAY-SPEC.md`
- `docs/superpowers/specs/CONCEPT-DISPLAY-CLARIFICATIONS.md` (this file)

**Modified (from Y Motion Implementation Plan):**
- Phases 2–6 now target unified left/right concept display for both Twins and Trips
- Phase 3: ConceptMatcher.identifyForSide() method remains the same
- Phase 6: ConceptBadgeRow now serves both Twins and Trips display patterns

**No changes to:**
- Phase 1: ReceiverMotion enum
- Phase 4: Motion picker UI (already designed)
- Phase 5: Diagram motion arc rendering
- Phase 7: Formation validation

---

## Next Steps

1. **UX Designer** confirms badge row styling and layout with both Twins and Trips mocks
2. **Software Engineer** aligns Y Motion Implementation Plan Phases 2–6 with these specs
3. **SDET** updates test cases to cover Twins chips + Trips motion combinations
4. **Create implementation plan** merging Y Motion Implementation Plan with Twins Chips plan
5. **Dispatch software-engineer** for implementation (single unified slice covering both)

