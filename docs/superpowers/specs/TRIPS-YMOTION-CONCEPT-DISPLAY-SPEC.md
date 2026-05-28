# Trips Formation: Y Motion with Side-Specific Concept Display
## Product Specification

**Status:** Ready for Review  
**Created:** 2026-05-28  
**Owner:** Product

---

## Problem & Value

**Problem:** When Y motion is applied in Trips formations, Y's field side changes, which may break the original concept match OR create new concept matches on the opposite side. Currently, coaches can't see how motion affects concept identification — they only see the original concept badge.

**Value:**
- Coaches see **live concept re-evaluation** when they apply motion
- Understand instantly whether a motion changes the play intent or creates a new concept opportunity
- Better audible design: "Run Y After and you automatically get Scissors on the right"

**Coach Use Case:** "I'm running Trips Left Smash. If I apply Y After motion, what concept do I get on the right? Let me see it update live."

---

## Scope: What Ships in This Slice

**In scope:**
- Y motion picker (Stop, After, Go) — already implemented in Phase 4 of Y motion feature
- Automatic concept re-identification when motion is applied
- Side-specific concept display (left badge, right badge) after motion
- Display ONLY identified concepts (no fallback text)
- Trips Left and Trips Right formations

**Out of scope:**
- Twins formation concept selection with chips (separate slice)
- Motion for other receivers (only Y)
- Motion trajectory animation
- Playbook persistence
- Wristband export with motion notation

---

## Design: Concept Display with Y Motion

### 1. Base Concept → Motion Applied → Concepts Update

**Workflow:**

```
Coach in Trips Left with Smash concept (base)
         ↓
Coach taps "Y Stop" motion
         ↓
Y receiver evaluated on NEW side (after motion):
  - Y Stop: Y stays on left side → left-side concept remains Smash
  - Y After/Go: Y moves to right side → re-evaluate left and right sides
         ↓
Concept badges update:
  - Left badge: Updated left-side concept (if any)
  - Right badge: Updated right-side concept (if any)
         ↓
Coach sees both badges with new identifications
```

---

### 2. Concept Re-Identification Logic

**When Y motion is applied:**

1. **Preserve the original digit sequence** (do NOT re-parse)
2. **Flip Y's field side** based on motion type:
   - `Y Stop`: Y stays on initial side (no flip)
   - `Y After`: Y flips to opposite side
   - `Y Go`: Y flips to opposite side
3. **Re-evaluate concepts independently per side:**
   - **Left-side group**: All receivers currently on left side (after motion) → match left-side templates
   - **Right-side group**: All receivers currently on right side (after motion) → match right-side templates
4. **Store both identified concepts** in ViewModel: `leftSideConcept`, `rightSideConcept`
5. **Display both badges** (or blank if no match)

---

### 3. Example: Trips Left + Y Stop Motion

**Base Play:** Trips Left 6794 → Smash concept

```
Base Assignments:
  X=6 (left)
  Y=7 (left)
  Z=9 (right)
  A=9 (right)

Base Concepts:
  Left: X=6, Y=7 → matches Smash template ✓
  Right: Z=9, A=9 → no match
  Display: LEFT="Smash", RIGHT=[blank]
```

**After Y Stop motion:**

```
Y Stop: Y stays on LEFT side (no flip)

Motion-Applied Assignments:
  X=6 (left)
  Y=7 (left, motion=.stop, finalSide=.left)
  Z=9 (right)
  A=9 (right)

Re-Evaluated Concepts:
  Left: X=6, Y=7 → still matches Smash ✓
  Right: Z=9, A=9 → still no match
  Display: LEFT="Smash", RIGHT=[blank]
  (No change, because Y didn't flip sides)
```

---

### 4. Example: Trips Left + Y After Motion

**Base Play:** Trips Left 6794 → Smash concept

```
Base Assignments:
  X=6 (left)
  Y=7 (left)
  Z=9 (right)
  A=9 (right)

Base Concepts:
  Left: X=6, Y=7 → Smash ✓
  Right: Z=9, A=9 → no match
  Display: LEFT="Smash", RIGHT=[blank]
```

**After Y After motion:**

```
Y After: Y flips to OPPOSITE side (left → right)

Motion-Applied Assignments:
  X=6 (left, unchanged)
  Y=7 (left base, but finalSide=.right after motion)
  Z=9 (right)
  A=9 (right)

New Side-Groups:
  Left: X=6, ??? (Y moved, A not on left anymore)
    → Incomplete left group; may not match any template
  Right: Y=7, Z=9, A=9
    → Check if this group matches any right-side template

Re-Evaluated Concepts:
  Left: X=6 alone → likely no match
  Right: Y=7, Z=9, A=9 → check templates
    → If matches, display identified concept
  Display: LEFT=[blank], RIGHT=[if matched]
```

**Realistic outcome:**
- Trips Left has left-side Smash template (X=6, Y=7, A=4)
- After Y moves right, left group is broken (only X=6 left)
- Right side (Y=7, Z=9, A=9) might match a Trips-compatible template, or not
- Coaches see left badge disappear; right badge may appear with new concept

---

### 5. Display Rule: No Fallback Text

**Rule:** If a concept doesn't match after motion, the badge is **blank** — no "—", no "Unknown", no "No match".

**Example: Y After motion breaks left-side Smash**

```
Before motion:
  LEFT: "✓ Smash"
  RIGHT: [blank]

After Y After motion:
  LEFT: [blank]        ← Smash broken; nothing displays
  RIGHT: [blank or identified concept]
```

**Why?** Coaches read blank as "no known concept on this side" — cleaner than fallback text.

---

### 6. Diagram Rendering: Motion Arc + Badge Update

**Visual feedback when coach applies motion:**

```
1. Route diagram: Motion arc appears (dashed line showing Y's path)
2. Y row in receiver table: Shows "LEFT → RIGHT" or final side indicator
3. Concept badges: INSTANTLY update to new identifications
4. Coach sees: "Oh, Y After motion breaks Smash on left but creates something on right"
```

**Animation:** Badges update instantly (no delay). Motion arc renders smoothly.

---

## Acceptance Criteria

### AC1: Y Motion Picker Available in Trips Formations
- **Given** Trips Left or Trips Right formation selected
- **When** receiver assignment view is displayed
- **Then** "Y MOTION" section appears with buttons: [None] [Stop] [After] [Go]
- **And** [None] is pre-selected by default
- **Given** Twins formation selected
- **When** receiver assignment view is displayed
- **Then** Y MOTION section is hidden or disabled
- **Test:** SwiftUI Preview shows motion picker in Trips, hidden in Twins

### AC2: Y Stop Motion Keeps Y on Same Side
- **Given** Trips Left with Y motion = .none (base)
- **When** coach taps [Stop] motion
- **Then** Y's finalSide remains on left side
- **And** left-side concept re-identification uses Y on left
- **And** right-side concept remains unchanged
- **Test:** Unit test verifies `motion.finalSide(.left, .tripsLeft) == .left`

### AC3: Y After/Go Motion Flips Y to Opposite Side
- **Given** Trips Left with Y motion = .none (base)
- **When** coach taps [After] or [Go] motion
- **Then** Y's finalSide flips to right side
- **And** left-side receivers are re-evaluated WITHOUT Y
- **And** right-side receivers are re-evaluated WITH Y
- **Test:** Unit test verifies `motion.finalSide(.left, .tripsLeft) == .right` for .after and .go

### AC4: Concept Re-Identification After Motion
- **Given** Trips Left 6794 with base concept Smash
- **When** coach applies Y Stop motion
- **Then** concepts are re-identified per side:
  - Left: X=6, Y=7, A=? → check against left-side templates
  - Right: Z=9, A=9 → check against right-side templates
- **And** `leftSideConcept` and `rightSideConcept` properties are updated
- **Test:** Integration test: Parse, apply motion, verify concept re-ID matches expected templates

### AC5: Concept Badge Display After Motion
- **Given** Trips Left play with Y motion applied
- **When** route result is displayed
- **Then** Concept Badge Row shows:
  - Left badge: Concept name if identified after motion; [blank if not]
  - Right badge: Concept name if identified after motion; [blank if not]
- **And** No "—" or "Unknown" text appears
- **And** Badges update instantly when motion is applied
- **Test:** Visual test: Apply Y Stop, then Y After; verify badges update without delay

### AC6: Motion Breaks Original Concept (No Fallback)
- **Given** Trips Left Smash (X=6, Y=7 on left)
- **When** Y After motion is applied (Y flips to right)
- **Then** left-side group is incomplete (X=6 alone)
- **And** left badge displays [blank] — NOT "Smash" or "—"
- **And** right badge shows new concept if identified, [blank] otherwise
- **Test:** Integration test: Apply Y After to Smash; verify left badge disappears

### AC7: Y Motion Resets on Formation Change
- **Given** Trips Left with Y motion = .stop
- **When** formation is changed to Twins
- **Then** Y motion is reset to .none
- **And** motion picker is hidden
- **And** concept display returns to single-concept or chips mode
- **Test:** Formation change event resets motion; UI updates

### AC8: Motion Persists Through Parse Changes
- **Given** Trips Left with Y motion = .after
- **When** coach enters new digits (e.g., "6794" → "5738")
- **Then** Y motion is preserved (remains .after)
- **And** concepts are re-identified for new digits with motion still applied
- **Test:** Parse new digits; verify motion state is preserved

### AC9: Y Motion Only on Y Receiver
- **Given** Y motion picker active
- **When** coach selects a motion option
- **Then** motion is applied ONLY to Y receiver
- **And** X, Z, A receivers are unaffected by motion
- **And** Motion affects Y's side interpretation, not its route number
- **Test:** Verify motion is not applied to other receivers; motion doesn't change route meanings

### AC10: No Invalid Motion States
- **Given** Twins formation
- **When** user somehow attempts to set Y motion (UI should prevent)
- **Then** error message appears: "Motion only available in Trips formations"
- **And** motion is reset to .none
- **And** state remains consistent
- **Test:** Unit test verifies guard in `motionChanged()` method

---

## Display Semantics

### Concept Badge Row Layout

```
┌─────────────────────────────────────────────────┐
│ ← SMASH                   DAGGER →              │  ← Both concepts, left/right separated
│ (or blank if not identified)                    │
└─────────────────────────────────────────────────┘
```

**States:**

| State | Left Badge | Right Badge | Notes |
|-------|-----------|------------|-------|
| Base Smash, no motion | Smash | [blank] | Left-side only |
| Base Smash, Y Stop | Smash | [blank] | Y stays left; no change |
| Base Smash, Y After | [blank] | [concept?] | Y moves right; left breaks |
| Base Sail, Y Go | [blank] | [concept?] | Same as Y After (both flip) |
| No concepts match | [blank] | [blank] | No badges shown at all |

---

## Roles & Dependencies

| Role | Task |
|------|------|
| **UX Designer** | Finalize motion arc visual style; confirm badge row placement and styling |
| **Software Engineer (iOS)** | Implement motion re-identification logic; integrate with ConceptMatcher |
| **SDET** | Regression tests for motion + concept re-ID combinations (all formations, motion types) |
| **Performance Engineer** | Verify no jank when tapping motion buttons or rendering motion arcs |
| **Security Engineer** | Validate motion state doesn't introduce injection vectors (already covered) |

---

## Out of Scope

**Twins Chips Selection:** Separate feature. Uses same badge display pattern but with explicit left/right selection UI instead of motion-triggered re-ID.

**Y Motion Animation:** Dashed arc renders instantly; not animated in this slice.

**Motion for Other Receivers:** Only Y motion. Future expansion could add motion for X, Z, A.

**Playbook Persistence:** Coaches can't save motion selections to playbooks yet.

---

## Success Metrics

- **Coaches understand concept changes when applying motion in <2 seconds**
- **All motion + concept combinations render without errors**
- **Concept badges update instantly (no lag)**
- **No regressions in existing Trips workflows**
- **Unit + integration test coverage ≥90% for motion logic**

---

## Key Differences from Twins Chips Selection

| Feature | Twins Chips | Trips Y Motion |
|---------|-----------|----------------|
| **Selection** | Explicit left/right chips | Implicit motion button |
| **Concepts** | Both selected upfront | Re-evaluated when motion changes |
| **Badge Update** | When chips selected | When motion applied |
| **Formation** | Twins only | Trips Left/Right only |
| **Y Receiver** | Optional H receiver | Required Y receiver |
| **Digit Sequence** | Generated from templates | Parsed or entered manually |

---

## Implementation Notes

**New/Modified Components:**
- `Models/ReceiverMotion.swift` — enum with finalSide() logic (already exists from Phase 1)
- `ViewModels/PlayCallerViewModel.swift` — add leftSideConcept, rightSideConcept, applyMotion() (Phases 2–3)
- `Services/ConceptMatcher.swift` — add identifyForSide() method (Phase 3)
- `Views/MotionPickerView.swift` — motion UI (Phase 4)
- `Views/RouteDiagramView.swift` — motion arc rendering (Phase 5)
- `Views/ConceptBadgeRow.swift` — display component (Phase 6)
- `ViewModels/PlayCallerViewModel.swift` — formation validation (Phase 7)

**Relationship to Y Motion Implementation Plan:**
This spec describes **Phases 2–6 output** (concept re-ID + display) from the Y Motion Implementation Plan. Phases 1–7 are prerequisites; Phase 8 is the integration test suite.

---

## Timeline

**Estimated LOE:** 4–6 hours  
(Assuming Y Motion Phases 1–3 are already implemented; this spec covers the display/integration layer)

**Breakdown:**
- Motion picker UI: 1.5–2 hours (Phase 4, already designed)
- Diagram motion arc rendering: 2–3 hours (Phase 5)
- Concept badge row: 1–1.5 hours (Phase 6)
- Validation: 0.5 hours (Phase 7)

**Recommended:** 1–2 days at steady pace, running in parallel with Twins chips slice.

---

## Review Checklist

- [ ] Coach confirms motion + concept re-ID value prop
- [ ] UX designer confirms badge row styling and motion arc visuals
- [ ] All ACs are testable and cover motion + concept combinations
- [ ] Parsing behavior handles all formation/motion states
- [ ] Concept matcher correctly filters by side after motion
- [ ] Error handling prevents invalid motion states
- [ ] No regressions in existing concept identification (without motion)

