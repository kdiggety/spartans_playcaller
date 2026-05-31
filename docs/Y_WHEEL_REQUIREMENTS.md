# Y Wheel Feature Requirements

**Date:** 2026-05-29  
**Status:** Pending Ken Review and Approval  
**Target Build:** Field test week of 2026-06-02

---

## 1. Feature Overview

**Y Wheel** is a new receiver motion option for the Y receiver that renders as a semi-circular arc originating from Y's position and extending downfield and away from the center of the field.

**Key Distinction:**
- Y Wheel is **NOT** a motion option like Stop/After/Go — it is an **independent feature toggle** that can be applied alongside motion selections
- When Y Wheel is enabled, the **numbered route is overridden** and displays as "Wheel" instead
- Y Wheel represents a distinct play concept where Y executes a curved path (arc) rather than a traditional numbered route

**Visual Implementation:**
- A smooth cubic Bézier-sampled arc (yellow) that:
  - Starts at Y's position on the line of scrimmage (or post-motion position if motion is active)
  - Curves downward and away from the center of the field
  - Ends at a depth of ~22% of field height (approximately 55% down the arc path)
  - Has an arrow pointing back toward the line of scrimmage at the endpoint
  - Is clearly visible on all supported screen sizes

---

## 2. Formations and Gating

### Supported Formations

Y Wheel is available in the following formations:

| Formation | Y Position | Motion Available? | Wheel Available? |
|-----------|------------|--------------------|------------------|
| Twins | Left side | **No** | **Yes** |
| Trips Left | Left side (slot) | **Yes** | **Yes** |
| Trips Right | Right side (slot) | **Yes** | **Yes** |
| Pro Left | Left side (slot) | **Yes** | **Yes** |
| Pro Right | Right side (slot) | **Yes** | **Yes** |

**Important Note on Twins Formation:**
- Twins currently does **NOT** support motion (Y stays on left side)
- However, **Y Wheel MUST be available in Twins** for coaches to use wheel concepts
- This means: Twins receives Y Wheel as a **unique feature that does not require motion support**
- **Action Required:** Code review must verify that `Formation.canApplyWheel()` (or similar gate) permits Twins while `canApplyMotion()` continues to reject it

### Motion Interaction

When both motion and wheel are active:
- Y first executes the motion (Stop/After/Go) to reach a final position
- Y Wheel arc then originates from that **post-motion position**
- The arc curves away from the center in Y's final position's side
- Route interpretation uses Y's **final side** (post-motion), not original side

---

## 3. Arc Geometry Specification

### Mathematical Definition

Y Wheel uses a **cubic Bézier curve** sampled at 0.02-stride intervals (~50 points) to ensure smooth visual rendering.

#### Parameters (Baseline)

```
loopDepth      = fieldHeight × 0.22       // 22% of field height
sideOffset     = fieldWidth × 0.05        // 5% of field width
endpointFraction = 0.55                   // Endpoint at 55% of loopDepth
```

#### Curve Calculation (Left Side Example - Y starts on left)

**Start Point (P₀):**
```
x = Y_position.x
y = Y_position.y  (at line of scrimmage)
```

**Control Point 1 (P₁) — Arc bends left:**
```
x = Y_position.x - sideOffset
y = Y_position.y + loopDepth × 0.4
```

**Control Point 2 (P₂) — Deepest point of arc:**
```
x = Y_position.x - sideOffset
y = Y_position.y + loopDepth × 0.8
```

**End Point (P₃) — Arc returns toward LOS:**
```
x = Y_position.x - sideOffset × 0.3
y = Y_position.y + loopDepth × endpointFraction
```

**Cubic Bézier Formula:**
```
B(t) = (1-t)³P₀ + 3(1-t)²tP₁ + 3(1-t)t²P₂ + t³P₃

where t ∈ [0, 1], sampled every 0.02 (~50 points)
```

#### Right Side (Y starts on right)

Mirror the left-side geometry:
- Control points positioned to the **right** of Y
- Arc curves **away from center** (rightward and back)
- Endpoint slightly right of Y's starting X coordinate

### Visual Characteristics

| Aspect | Specification |
|--------|---------------|
| **Color** | Yellow (same as motion arcs) |
| **Line Width** | 3pt |
| **Arc Depth** | ~22% of field height (reasonable relative to other routes) |
| **Start Position** | Bottom center of Y's receiver circle |
| **End Position** | Offset from start X, ~22% down the field |
| **Curve Style** | Smooth U-shape (no sharp corners, no segmented appearance) |
| **Arrow** | Yellow, pointing back toward LOS at endpoint |
| **Z-Order** | Rendered after field/football/other receivers, before receiver circles/labels |

### Scaling on iPhone

Example on iPhone 17 (812px field height):
```
Arc Depth ≈ 812 × 0.22 = 178px

Comparative Scale:
  - Route length (vertical routes):  ~203px (25% of field)
  - Break length (horizontal routes): ~122px (15% of field)
  - Arc depth:                        ~178px (22% of field) ✓ proportionate
```

---

## 4. Four Test Scenarios - Detailed Behavior

### Scenario A: Twins LEFT, Y Motion NONE

**Setup:**
- Formation: Twins
- Y starts: Left side
- Motion: None (no selection made)
- Wheel: Enabled

**Expected Arc Behavior:**
- **Arc Direction:** Curves LEFT (away from center of field)
- **Arc Start:** Bottom of Y's receiver circle (on line of scrimmage)
- **Arc X-coordinate:** Arc deviates LEFT, endpoint X-coordinate is **different** (more left) than start X
- **Arc End:** ~22% down the field, angled back toward LOS at ~45°
- **Route Display:** Assignment table shows "Wheel" (not a numbered route)
- **Concept Status:** If matched to a concept, concept identification **persists** (Y hasn't moved)

**Verification Points:**
- Arc is visible in diagram
- Arc is the correct color (yellow)
- Arc shape is smooth U-curve (not angular)
- Arrow points back at LOS
- No visual clipping at field edges

---

### Scenario B: Twins LEFT, Y Motion AFTER/GO

**Setup:**
- Formation: Twins
- Y original side: Left
- Motion: After or Go (flips Y to right side)
- Wheel: Enabled

**Expected Arc Behavior:**
- **Y Post-Motion Position:** Y has moved from left to right side (motion flips sides)
- **Arc Start:** Originates from Y's NEW position (right side)
- **Arc Direction:** Curves RIGHT (away from center, which is now on Y's right in final position)
- **Arc Start/End X-coords:** Different (tilted arc on right side of field)
- **Arc End:** ~22% down the field, angled back toward LOS at ~45°
- **Route Display:** "Wheel" (route interpretation uses Y's final side for route number, but wheel overrides it)
- **Concept Status:** If original concept relied on Y's left-side interpretation, concept is **not re-identified** (wheel overrides route meaning)

**Verification Points:**
- Arc originates from Y's **post-motion position**, not original left position
- Arc curves in the direction of Y's final side
- Motion and wheel work together without conflicts
- Route shows "Wheel" regardless of underlying route number

---

### Scenario C: Twins RIGHT, Y Motion NONE

**Setup:**
- Formation: Twins
- Y starts: Right side (in 2x2 Twins formation, Y is on the left naturally, so this would require receiver reassignment logic — verify with Ken if Twins has right-aligned variant)
- **Clarification Needed:** Does Twins Left / Twins Right exist as distinct formations, or is Twins always 2x2 with Y on left? Assuming YES for this scenario (either via Twins Right variant or misalignment).
- Motion: None
- Wheel: Enabled

**Expected Arc Behavior:**
- **Arc Direction:** Curves RIGHT (away from center)
- **Arc Start:** Bottom of Y's receiver circle
- **Arc End:** ~22% down field, endpoint X-coordinate is **different** (more right) than start
- **Endpoint Angle:** ~45° back toward LOS
- **Route Display:** "Wheel"
- **Concept Status:** Persists (Y hasn't moved)

**Verification Points:**
- Arc direction mirrors Scenario A (opposite side)
- All other visual properties consistent
- No regressions in Scenario A when switching sides

---

### Scenario D: Twins RIGHT, Y Motion AFTER/GO

**Setup:**
- Formation: Twins (right-aligned variant, pending clarification)
- Y original side: Right
- Motion: After/Go (flips Y to left)
- Wheel: Enabled

**Expected Arc Behavior:**
- **Y Post-Motion Position:** Y has flipped to left side
- **Arc Start:** Originates from Y's new position (left side)
- **Arc Direction:** Curves LEFT
- **Arc Start/End X-coords:** Different (tilted arc on left side)
- **Endpoint Angle:** ~45° back toward LOS
- **Route Display:** "Wheel"
- **Concept Status:** Wheel overrides route interpretation

**Verification Points:**
- Motion and wheel integrate correctly
- Arc originates from post-motion position
- Consistent with Scenario B (opposite side)

---

## 5. UI Requirements

### Motion Picker Enhancement

**Current State (Trips/Pro formations only):**
- Segmented control or picker showing: `None | Stop | After/Go`
- Visible in assignment table for Y receiver row

**Y Wheel Integration (all supporting formations):**
- Motion picker remains unchanged: `None | Stop | After/Go` (only in Trips/Pro)
- **Below** motion picker, a **separate toggle** appears: `Y Wheel` with ON/OFF switch
- Toggle is available in:
  - Twins (no motion available, but wheel available)
  - Trips Left, Trips Right (motion and wheel both available)
  - Pro Left, Pro Right (motion and wheel both available)

**Behavior:**
- Toggle defaults to OFF
- When OFF: Y shows its regular numbered route, no arc
- When ON: Y shows "Wheel" as route, arc is rendered
- Motion and wheel are independent: you can have (Motion: After, Wheel: ON) or (Motion: None, Wheel: ON)

### Route Display Override

**Assignment Table (Y Row):**
- With Wheel OFF: Shows numbered route (e.g., "7" for route 7)
- With Wheel ON: Shows "Wheel" (not the route number)

**Diagram:**
- With Wheel ON: Arc is rendered; numbered route graphic is **not** displayed
- With Wheel OFF: Numbered route graphic is displayed; no arc

---

## 6. Arc Visibility and Rendering Requirements

### Screen Size Coverage

Y Wheel arc **MUST** be tested and verified on:
- iPhone 15 Pro (6.7" standard)
- iPhone SE (4.7" smallest)
- iPad (12.9" largest)

**Pass Criteria:**
- Arc is clearly visible (not too small to see)
- Arc does not extend beyond field boundaries
- Arc does not clip at any edge (left, right, top, bottom)
- Arc color and thickness are consistent across devices

### Visual Clarity

- Arc **MUST** be distinguishable from:
  - Other receiver routes (standard 1–9)
  - Motion arcs (After/Go)
  - Field markings (yard lines, hashes)
  - Receiver position circles

- Arc **MUST** appear as a single smooth curve (not segmented or jittery)

### Z-Order (Layering)

Rendering order (back to front):
1. Field (grass, yard lines, hashes)
2. Football (line of scrimmage marker)
3. **Y Wheel Arc** (if enabled)
4. Other receiver routes (1–9)
5. Motion arcs (Stop/After/Go)
6. Receiver position circles
7. Receiver labels (X, Y, Z, A, H)

---

## 7. Implementation Constraints

### Code Review Gates

Before implementation begins, the following must be verified:

1. **Formation Gating:**
   - [ ] Verify `Formation.canApplyMotion()` returns `true` for: Trips Left, Trips Right, Pro Left, Pro Right
   - [ ] Verify `Formation.canApplyMotion()` returns `false` for: Twins
   - [ ] Code review: Ensure no changes to motion gating will accidentally break Twins wheel support

2. **Receiver Model:**
   - [ ] Check: `ReceiverMotion` enum supports `.wheel` case
   - [ ] Check: `ReceiverMotion.wheel.finalSide()` returns the same side as original (unlike `.after`/`.go`)

3. **Route Assignment:**
   - [ ] Verify: Route assignment can be "Wheel" (distinct from route numbers 0–9)
   - [ ] Verify: When wheel is active, route interpretation still works (for concept matching)

4. **Diagram Rendering:**
   - [ ] Verify: `DiagramRenderer` has `yWheelArcPath()` method
   - [ ] Verify: Arc rendering delegates to `drawWheel()` in RouteDiagramView or equivalent
   - [ ] Verify: Arc respects Y's post-motion position if motion is active

---

## 8. Known Issues and Backlog Items

### Resolved (as of 2026-05-29)

- ✅ Arc rendering quality — Fixed via dense sampling (0.02 stride, ~50 points)
- ✅ Smooth curve appearance — Verified in YWheelArcVisualSpecTests

### Pending Verification

- [ ] **Twins Formation Support:** Confirm that code can gate motion (`false`) while allowing wheel (`true`)
- [ ] **Post-Motion Arc Start:** When Y has After/Go motion enabled alongside wheel, verify arc starts from Y's **final position**, not original position
- [ ] **No-Motion Visibility:** Verify wheel arc displays even when Y motion is set to "None" (not After/Go)
- [ ] **Screen Edge Clipping:** Verify arc doesn't clip on all supported screen sizes (iPhone SE to iPad)

---

## 9. Acceptance Criteria (Ken Review Checklist)

Before implementation, Ken must confirm:

- [ ] Arc geometry specification is correct (loopDepth, sideOffset, endpointFraction, sampling)
- [ ] All four scenarios (A–D) describe the intended behavior accurately
- [ ] UI placement (toggle below motion picker) is acceptable
- [ ] "Wheel" route name is acceptable (not "Semi-Circle," "Arc," "Loop," etc.)
- [ ] Field test scope is reasonable (Twins, Trips, Pro formations)
- [ ] Test plan coverage (Scenario A–D + edge cases) is sufficient
- [ ] Any additional requirements or clarifications are documented

---

## 10. Success Metrics (Post-Implementation)

After implementation and testing:

1. **Functional:** All four scenarios work as specified
2. **Visual:** Arc is smooth, visible, and doesn't clip on any screen size
3. **Responsive:** Motion and wheel toggle work together without lag
4. **Robust:** No regressions in existing route or motion rendering
5. **Testable:** All scenarios can be verified without needing physical football field
6. **Field-Ready:** Build is packaged and documented for week-of-06-02 field test

---

## Revision History

| Date | Change | Status |
|------|--------|--------|
| 2026-05-29 | Initial requirements draft | Pending Ken Review |

