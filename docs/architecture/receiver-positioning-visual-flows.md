# Receiver Positioning: Visual Flows & Diagrams

Reference diagrams for the impact analysis.

---

## 1. Current Data Flow (Formation-Based Only)

```
┌──────────────┐
│  PlayCall    │
│ formation    │
│ routes       │
│ assignments  │
└───────┬──────┘
        │
        ▼
┌──────────────────────────────┐
│   ConceptMatcher             │
│   (match routes to template) │
│   INPUT: [R: RouteNumber]    │
│   OUTPUT: RouteConcept       │
│   (independent of positions) │
└──────────────┬───────────────┘
               │
        ┌──────┴──────┐
        ▼             ▼
   Concept         (No change
   Library         to concept)
        
        
┌────────────────────────────────┐
│  DiagramRenderer               │
│  receiverPositions(formation)  │
│  → [Receiver: CGPoint]         │
└────────┬──────────────┬────────┘
         │              │
         ▼              ▼
    yFinalPosition   yWheelArcPath
    (Y motion)       (Y Wheel)
         │              │
         └──────┬───────┘
                ▼
         ┌──────────────────┐
         │ RouteDiagramView │
         │ Canvas Rendering │
         └──────────────────┘
```

---

## 2. Proposed Data Flow (With Custom Positions)

```
┌──────────────────────────┐
│     PlayCall             │
│ + formation              │
│ + routes                 │
│ + assignments            │
│ + customPositions ◄──────┬─── NEW: [Receiver: CGPoint]?
└────────┬─────────────────┘
         │
         ▼
    ┌────────────────────────────────────────────┐
    │ ConceptMatcher (UNCHANGED)                 │
    │ INPUT: [R: RouteNumber]                    │
    │ OUTPUT: RouteConcept                       │
    │ (STILL independent of positions!)          │
    └────────────────────────────────────────────┘
    
    
┌──────────────────────────────────────────────────────────┐
│  DiagramRenderer                                         │
│  receiverPositions(formation, customPositions, config)  │
│  → [Receiver: CGPoint] (formation defaults + overrides) │
└────────────┬─────────────────────┬──────────────────────┘
             │                     │
             ▼                     ▼
        ┌─────────────┐    ┌────────────────┐
        │yFinalPosition    yWheelArcPath   │
        │(Y motion)    │    │(Y Wheel)     │
        │+ custom base │    │+ custom Y     │
        └────┬────────┘    └────┬─────────┘
             │                  │
             └─────────┬────────┘
                       ▼
               ┌──────────────────┐
               │ RouteDiagramView │
               │+ custom positions│
               │Canvas Rendering  │
               └──────────────────┘
```

**Key Change:** Custom positions enter at PlayCall and are threaded through rendering. Concept matching is **untouched**.

---

## 3. Y Motion Calculation Sensitivity

### With Formation Defaults (Current)

```
Twins Formation (0.5x multiplier):

Formation:
┌─────────────┬─────────────┐
│      X      │      A      │      (Left side)
└─────────────┴─────────────┘
    ●              ●
    0.5x           1.0x
   spacing        spacing
   from center

Y on right: 0.5x spacing from center

Y After/Go motion:
  baseDistance = 0.5 × spacing
  multiplier = 0.5 (Twins rule)
  finalDistance = 0.5 × spacing × 0.5 = 0.25 × spacing
  finalX = centerX - 0.25 × spacing  ◄─── Y lands here
  
  Visual:
  ┌─────────────┬─────────────┬─────────────┬─────────────┐
  │      X      │      A      │   (Y here)  │             │
  │ ●           │ ●           │    ●        │             │
  │ 0.5x        │ 1.0x        │   0.25x     │   (rest)    │
  └─────────────┴─────────────┴─────────────┴─────────────┘
                    CENTER
```

### With Custom Position (Proposed)

```
Same Twins, but coach moves Y to 1.5x spacing:

Custom Position:
  Y at 1.5x spacing from center (instead of 0.5x)

Y After/Go motion with custom base:
  baseDistance = 1.5 × spacing
  multiplier = 0.5 (Twins rule — unchanged)
  finalDistance = 1.5 × spacing × 0.5 = 0.75 × spacing
  finalX = centerX - 0.75 × spacing  ◄─── Y lands FARTHER OUT
  
  Visual:
  ┌─────────────┬─────────────┬──────────────────────────┬─────────────┐
  │      X      │      A      │ (Y after custom move)    │             │
  │ ●           │ ●           │ ●                        │             │
  │ 0.5x        │ 1.0x        │ 0.75x                    │   (rest)    │
  └─────────────┴─────────────┴──────────────────────────┴─────────────┘
                    CENTER
```

**Risk:** If refactor accidentally uses **formation spacing** instead of **custom position** for base distance, Y lands in wrong spot.

---

## 4. System Isolation: What Doesn't Change

```
┌─────────────────────────────────────────┐
│ DOMAIN LAYER (UNTOUCHED)                │
├─────────────────────────────────────────┤
│                                         │
│  ┌──────────────────────┐               │
│  │ ConceptLibrary       │               │
│  │ (route-based only)   │               │
│  └──────────────────────┘               │
│                                         │
│  ┌──────────────────────┐               │
│  │ PlayCallParser       │               │
│  │ (digits → meaning)   │               │
│  └──────────────────────┘               │
│                                         │
│  ┌──────────────────────┐               │
│  │ RouteInterpreter     │               │
│  │ (side → label)       │               │
│  └──────────────────────┘               │
│                                         │
└─────────────────────────────────────────┘
           (NO CHANGES)
           
┌─────────────────────────────────────────┐
│ RENDERING LAYER (CUSTOM POSITIONS HERE) │
├─────────────────────────────────────────┤
│                                         │
│  ┌──────────────────────────────────┐   │
│  │ DiagramRenderer                  │   │
│  │ + custom position override logic │   │
│  └──────────────────────────────────┘   │
│                                         │
│  ┌──────────────────────────────────┐   │
│  │ RouteDiagramView                 │   │
│  │ + gesture handling for drag      │   │
│  └──────────────────────────────────┘   │
│                                         │
└─────────────────────────────────────────┘
        (CHANGES HERE ONLY)
```

**Key Insight:** Custom positions are a **render-time concern**. Domain logic (concepts, routes, meanings) is untouched.

---

## 5. Concept Matching Stays Blind to Positions

```
Concept Matching: Two Routes on Same Side

Example: Smash concept = X(Curl) + A(Corner) in Twins Left

Current Template (Route-Based):
┌──────────────────────────────────────┐
│ ConceptTemplate                      │
│ ├─ concept: .smash                   │
│ ├─ formation: .twinsLeft              │
│ └─ receiverRoutes: [.X: .six,         │
│                     .A: .seven]       │
└──────────────────────────────────────┘
                 INPUT
                   ▲
                   │
        [.X: .six, .A: .seven]
        (route numbers only)
                   │
         ┌─────────┴──────────┐
         │ ConceptMatcher     │
         │ MATCH? YES         │
         └────────┬───────────┘
                  │
                  ▼
           RouteConcept.smash


What is NOT checked:
  ✗ Is X at default position?
  ✗ Is A at default position?
  ✗ Is spacing nominal?
  ✗ Are they within 3 yards?
  
Result: Coach moves A 3× wider.
  A is STILL running route 7 (corner).
  X is STILL running route 6 (curl).
  Smash is STILL identified.
```

**Implication:** Custom positions have **zero semantic impact**. This is a feature you must clearly communicate to coaches.

---

## 6. Test Coverage: Before and After

### Before (Current Tests)

```
PlayCall
  ├─ test_parseFormation
  ├─ test_parseRouteDigits
  └─ test_identifyConceptSmash

DiagramRenderer
  ├─ test_receiverPositionsForTwins
  ├─ test_receiverPositionsForTripsLeft
  ├─ test_yMotionAfterTwins
  ├─ test_yWheelArcTripsLeft
  └─ test_routePathAbsoluteDirection

RouteDiagramView
  ├─ test_renderRoutes
  ├─ test_drawMotionArc
  └─ test_drawWheelArc

ConceptMatcher
  ├─ test_identifySmash
  └─ test_identifyDagger
```

### After (With Custom Positions)

```
PlayCall
  ├─ [UNCHANGED] test_parseFormation
  ├─ [UNCHANGED] test_parseRouteDigits
  ├─ [UNCHANGED] test_identifyConceptSmash
  ├─ [NEW] test_customPositionsSerialize
  └─ [NEW] test_oldPlaysLoadWithoutCustomPositions

DiagramRenderer
  ├─ [CHANGED] test_receiverPositionsForTwins_withCustom
  ├─ [UNCHANGED] test_receiverPositionsForTripsLeft
  ├─ [NEW] test_yMotionAfterTwins_withCustomBase
  ├─ [NEW] test_yMotionAfterTripsLeft_withCustomBase
  ├─ [NEW] test_yWheelArcWithCustomY
  ├─ [UNCHANGED] test_routePathAbsoluteDirection
  └─ [NEW] test_yFinalPositionCustomMultiplier

RouteDiagramView
  ├─ [NEW] test_gestureCapturesPosition
  ├─ [CHANGED] test_renderRoutes_withCustom
  ├─ [UNCHANGED] test_drawMotionArc
  └─ [UNCHANGED] test_drawWheelArc

ConceptMatcher
  ├─ [UNCHANGED] test_identifySmash
  ├─ [UNCHANGED] test_identifySmashWithCustomPosition
  └─ [UNCHANGED] test_identifyDagger
```

**Summary:**
- ConceptMatcher tests: ALL UNCHANGED (positions don't matter)
- DiagramRenderer tests: 3–4 new cases for custom positions + Y motion multipliers
- RouteDiagramView tests: 1–2 new cases for gesture handling
- **Total:** ~10–15 new test cases (not 50+ regression tests)

---

## 7. Implementation Effort Breakdown (Option A / MVP)

```
PlayCall Data Model
├─ Add customPositions: [Receiver: CGPoint]? field      [30 min]
├─ Serialization (Codable)                              [1 hour]
└─ Test: save/load with and without field               [30 min]
SUBTOTAL: 2 hours

DiagramRenderer
├─ receiverPositions() signature change                 [30 min]
├─ Override logic (apply custom over defaults)          [1 hour]
├─ yFinalPosition() refactor (custom base distance)     [1.5 hours]
├─ yWheelArcPath() refactor (custom Y position)         [1 hour]
├─ Tests: Y motion × 3 formations + Y Wheel × 3        [2 hours]
└─ Verify all existing tests pass                       [30 min]
SUBTOTAL: 6.5 hours

RouteDiagramView
├─ Thread customPositions through draw calls            [1 hour]
├─ Verify positions apply in rendering                  [30 min]
└─ Test: diagram renders custom positions               [30 min]
SUBTOTAL: 2 hours

UI Gesture Layer
├─ Pan gesture on receiver circles                      [2 hours]
├─ Position capture and bounds validation               [1.5 hours]
├─ Snap-to-grid (nice-to-have)                          [1 hour optional]
└─ Test: drag receiver, verify position updates         [30 min]
SUBTOTAL: 4-5 hours

Integration & Testing
├─ Manual E2E: drag, save, load                         [1 hour]
├─ Regression: all existing tests                       [30 min]
└─ Documentation & decision log                         [30 min]
SUBTOTAL: 2 hours

TOTAL: 14-15 hours
```

---

## 8. Risk Heat Map

```
                     LOW              MED              HIGH
                     │                │                │
Concept Matching     ●────────────────────────────────  (ZERO RISK)
Route Interpretation ●────────────────────────────────  (ZERO RISK)
Test Coverage        ●──────────────●─────────────────  (MED RISK)
Y Wheel Geometry     ●──────────────●─────────────────  (MED RISK)
Y Motion Multiplier  ●──────────────●─────────────────  (MEDIUM RISK)
Code Path Skew       ●──────────────●─────────────────  (MEDIUM RISK)
Coaching Clarity     ●──────────────────────●─────────  (MEDIUM-HIGH)
Persistence          ●──────────────────────────────    (LOW RISK)
Backward Compat      ●──────────────────────────────    (LOW RISK)

Overall: MEDIUM RISK, MANAGEABLE with good testing.
```

---

## 9. Decision Checklist

Before implementing custom positions, confirm:

```
□ Coaching demand validated (ask coaches directly)
□ Product accepts "visual only" scope (no concept matching changes yet)
□ Test plan approved (10–15 new tests)
□ Y motion multiplier logic reviewed (Twins 0.5x, Pro 1.5x, Trips 2.5x)
□ Gesture UX designed (how coaches will interact)
□ Serialization strategy approved (custom positions in PlayCall JSON)
□ Documentation drafted ("Custom positions are visual adjustments only")
□ Backward compatibility tested (old plays load correctly)
□ Risk mitigation (specific tests for Y motion custom base)
□ Effort estimate reviewed (14 hours for MVP)
```

All green? **Proceed to Option A. Implement MVP.**

---

## 10. Architecture Comparison

### Current System (Formation-Derived Positions)
```
Pros:
✅ Clean semantic model (formation = receivers + positions)
✅ No custom state to track
✅ Concept matching is position-blind (correct)
✅ All positions always valid (can't drag off screen)

Cons:
❌ Coaches can't adjust positions on diagram
❌ Less flexible for non-standard alignments
```

### With Custom Positions (Option A/MVP)
```
Pros:
✅ Coaches can adjust positions visually
✅ Positions still meaningful (overrides formation, doesn't change concept)
✅ Feature is isolated to render layer
✅ Backward compatible (optional field)

Cons:
❌ Two code paths (formation + custom)
❌ Coaches might expect positions to affect concepts
❌ Requires careful Y motion refactoring
❌ More state to test
```

### With Custom Positions + Concept Matching (Option B/Full)
```
Pros:
✅ All of Option A
✅ Concept templates can be position-aware (future)
✅ Professional play editor workflow

Cons:
❌ Significantly more complexity (34 hours vs. 14)
❌ Concept matching design must be revisited
❌ More surface area for bugs
```

**Recommendation:** Start with Option A. Add Option B only if coaches demand it.
