# Y Wheel Feature Requirements

**Date:** 2026-05-29  
**Status:** Pending Ken Review and Approval  
**Target Build:** Field test week of 2026-06-02

---

## 0. Formation Definitions and Transformations

### General Principles (Foundation)

These principles apply consistently across all formations (Twins, Trips, Pro):

1. **Y is always the inside receiver on its designated side**
2. **X is always on the left**
3. **Z is always on the right**

### Core Formation Definitions

**Twins Formation (2x2 structure):**
- Left side: X (outside), A (inside)
- Right side: Y (inside), Z (outside)
- **Supports Y motion (After/Go) which transforms to 3x1 formation**

**Trips Formation (3x1 structure):**
- 3 receivers on one side, 1 receiver on the other
- A is always on the outside; X/Z in the middle; Y on the inside
- **Trips Left:** A (outside), X (middle), Y (inside) on left; Z alone on right
- **Trips Right:** X alone on left; Y (inside), Z (middle), A (outside) on right
- Motion support (After/Go) available

**Pro Formation (2x1 structure):**
- 2 receivers on one side, 1 receiver on the other
- X, Y, Z only (A does NOT appear in Pro)
- **Pro Left:** X (outside), Y (inside) on left; Z alone on right — 2x1 formation
- **Pro Right:** X alone on left; Y (inside), Z (outside) on right — 1x2 formation
- Motion support (After/Go) available

### Twins Y Motion After/Go Special Case

When Y Motion After/Go is applied to Twins formation:
- Y flips to the opposite side, creating a 3x1 formation
- **Important:** The resulting receiver ordering is a special case, but does **NOT** affect diagram rendering or arc behavior
- Arc direction and geometry are determined by Y's final position (post-motion), not receiver ordering

### Formation Transformations with Y Motion (After/Go)

When Y Motion is applied as **After** or **Go**, Y flips sides, transforming the formation:

| Original Formation | Y Motion | Transformed Formation | Example |
|-------------------|----------|----------------------|---------|
| Twins (2x2) | After/Go | Trips (3x1) | 2 on right → 1 on right; Y moves to left creating 3 on left, 1 on right |
| Trips Left (3x1) | After/Go | Twins (2x2) | Y moves to right, pairing with Z, creating 2 on each side |
| Trips Right (3x1) | After/Go | Twins (2x2) | Y moves to left, pairing with X, creating 2 on each side |
| Pro Left (2x1) | After/Go | Twins (2x2) | Y moves to right, creating 2 on each side |
| Pro Right (1x2) | After/Go | Twins (2x2) | Y moves to left, creating 2 on each side |

### Concept Matching and Transformed Formations

**Critical Rule:** Concepts are identified against the **transformed formation type**, not the original formation type.

- When Twins becomes 3x1 via Y After/Go: concepts match as **3x1 formation**
- When Trips becomes 2x2 via Y After/Go: concepts match as **2x2 formation**
- **Y Wheel does NOT override concept matching** — it displays the arc regardless of the underlying route, but concept identification uses the transformed formation type

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

| Formation | Motion Available? | Wheel Available? | Note |
|-----------|-------------------|------------------|------|
| Twins | **Yes** | **Yes** | 2x2; Y motion (After/Go) transforms to 3x1 |
| Trips Left | **Yes** | **Yes** | 3x1 |
| Trips Right | **Yes** | **Yes** | 3x1 |
| Pro Left | **Yes** | **Yes** | 2x1 |
| Pro Right | **Yes** | **Yes** | 1x2 |

**Important Notes:**
- **All formations support Y Wheel independently of motion**
- **Code Review Gate:** `Formation.canApplyMotion()` returns `true` for all formations; `canApplyWheel()` returns `true` for all formations

### Motion Interaction

When both motion and wheel are active (possible in all formations that support motion: Twins, Trips, Pro):
- Y first executes the motion (Stop/After/Go) to reach a final position
- Y Wheel arc originates from Y's **post-motion position**
- The arc curves away from the center in Y's **final position**
- Route interpretation uses Y's **final side** (post-motion) for concept matching
- Arc direction reverses when Y flips sides (e.g., left-curving arc becomes right-curving arc)

---

## 3. Arc Geometry Specification

### Arc Behavior Consistency

**Key Principle:** Arc direction and behavior are consistent regardless of special case receiver positioning (e.g., Twins Y Motion After/Go). The arc:
- Curves away from the center of the field in Y's final position
- Points back at the LOS at the endpoint in all scenarios
- Originates from Y's post-motion position (if motion is active)
- Maintains the same visual depth and proportions across all formations

### Mathematical Definition

Y Wheel uses a **cubic Bézier curve** sampled at 0.02-stride intervals (~50 points) to ensure smooth visual rendering.

#### Parameters (Baseline)

```
loopDepth      = fieldHeight × 0.25       // 25% of field height
sideOffset     = fieldWidth × 0.30        // 30% of field width
endpointFraction = 0.55                   // Endpoint at 55% of loopDepth
```

**Rationale:**
- sideOffset ~30% ensures arc has noticeable horizontal deviation
- loopDepth ~25% provides reasonable depth without extending too far
- endpointFraction 0.55 ensures arc returns toward LOS before endpoint

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

Example on iPhone 15 Pro (812px field height):
```
Arc Depth ≈ 812 × 0.25 = 203px
Side Offset ≈ 390px × 0.30 ≈ 117px

Comparative Scale:
  - Route length (vertical routes):   ~203px (25% of field) ✓ arc matches
  - Break length (horizontal routes):  ~117px (30% of field width) ✓ reasonable offset
  - Arc depth:                         ~203px (25% of field) ✓ proportionate to routes
  
Visual Balance: Arc depth equals route length, creating visual consistency across play diagrams.
```

---

## 4. Four Test Scenarios - Detailed Behavior

### Scenario A: Twins, Y Motion NONE (2x2 formation remains)

**Setup:**
- Formation: Twins (2x2 structure)
- Y position: Right side (inside receiver)
- Motion: None
- Wheel: Enabled

**Expected Arc Behavior:**
- **Formation Type:** Remains 2x2 (no transformation)
- **Arc Direction:** Curves RIGHT (away from center of field)
- **Arc Start:** Bottom of Y's receiver circle (on line of scrimmage)
- **Arc X-coordinate:** Arc deviates RIGHT, endpoint X-coordinate is **different** (more right) than start X
- **Arc End:** ~25% down the field, angled back toward LOS at ~45°
- **Route Display:** Assignment table shows "Wheel" (not a numbered route)
- **Concept Status:** Concepts match as **2x2 formation** (formation hasn't changed)

**Verification Points:**
- Arc is visible in diagram
- Arc curves away from center (right side)
- Arc is the correct color (yellow)
- Arc shape is smooth U-curve (not angular)
- Arrow points back at LOS
- No visual clipping at field edges

---

### Scenario B: Twins, Y Motion AFTER/GO (transforms to 3x1)

**Setup:**
- Formation: Twins (originally 2x2)
- Y position before motion: Right side
- Motion: After or Go
- Wheel: Enabled

**Expected Arc Behavior:**
- **Formation Type:** Transforms from 2x2 to **3x1** (Y flips to left, creating 3 on left, 1 on right)
- **Y Post-Motion Position:** Y moves from right to left side (now inside on left)
- **Arc Start:** Originates from Y's **new position on left side**
- **Arc Direction:** Curves LEFT (away from center, in Y's new position)
- **Arc Start/End X-coords:** Different (tilted arc on left side of field)
- **Arc End:** ~25% down the field, angled back toward LOS at ~45°
- **Route Display:** "Wheel" (motion and wheel work together)
- **Concept Status:** Concepts match as **3x1 formation** (formation has transformed)

**Verification Points:**
- Arc originates from Y's **post-motion position** (left side), not original right position
- Arc curves left (away from center in new position)
- Formation transformation is reflected in concept matching
- Motion and wheel work together without conflicts
- Route shows "Wheel" regardless of underlying route number

---

### Scenario C: Trips Left, Y Motion NONE (3x1 formation remains)

**Setup:**
- Formation: Trips Left (3x1 structure)
- Y position: Left side (inside receiver, between A and X)
- Receivers: A (outside), X (middle), Y (inside) on left; Z alone on right
- Motion: None
- Wheel: Enabled

**Expected Arc Behavior:**
- **Formation Type:** Remains 3x1 (no transformation)
- **Arc Direction:** Curves LEFT (away from center of field)
- **Arc Start:** Bottom of Y's receiver circle (on line of scrimmage)
- **Arc X-coordinate:** Arc deviates LEFT, endpoint X-coordinate is **different** (more left) than start X
- **Arc End:** ~25% down the field, angled back toward LOS at ~45°
- **Route Display:** Assignment table shows "Wheel"
- **Concept Status:** Concepts match as **3x1 formation** (formation hasn't changed)

**Verification Points:**
- Arc is visible in diagram
- Arc curves away from center (left side)
- Arc is the correct color (yellow)
- Arc shape is smooth U-curve (not angular)
- Arrow points back at LOS
- No visual clipping at field edges

---

### Scenario D: Trips Left, Y Motion AFTER/GO (transforms to 2x2)

**Setup:**
- Formation: Trips Left (originally 3x1)
- Y position before motion: Left side (inside receiver, between A and X)
- Motion: After or Go
- Wheel: Enabled

**Expected Arc Behavior:**
- **Formation Type:** Transforms from 3x1 to **2x2** (Y flips to right, creating 2 on each side)
- **Y Post-Motion Position:** Y moves from left to right side (now inside on right, paired with Z)
- **Special Case Note:** Resulting receiver arrangement is a special case formation (Y most inside on right), but **does NOT affect diagram rendering or arc behavior**
- **Arc Start:** Originates from Y's **new position on right side**
- **Arc Direction:** Curves RIGHT (away from center, in Y's new position)
- **Arc Start/End X-coords:** Different (tilted arc on right side of field)
- **Arc End:** ~25% down the field, angled back toward LOS at ~45°
- **Route Display:** "Wheel"
- **Concept Status:** Concepts match as **2x2 formation** (formation has transformed)

**Verification Points:**
- Arc originates from Y's **post-motion position** (right side), not original left position
- Arc curves right (away from center in new position)
- Formation transformation is reflected in concept matching
- Motion and wheel work together without conflicts
- Arc direction reverses from Scenario C (opposite side)
- Special case receiver positioning does not affect arc rendering

---

## 5. Concept Matching Behavior

### How Y Wheel Interacts with Concept Matching

**Critical Principle:** Y Wheel **does NOT override concept matching**. Concepts are identified based on the transformed formation type, not the wheel toggle.

### Concept Matching Rules

1. **Formation Transformation First:**
   - If Y Motion (After/Go) is active, formation type changes (e.g., Twins 2x2 → 3x1 Trips)
   - Concept matching uses the **transformed** formation type

2. **Y Wheel Toggle:**
   - Wheel ON/OFF affects only the **visual display** (arc instead of numbered route)
   - Wheel does NOT change concept identification
   - Wheel does NOT change formation type
   - Underlying route (and concept matching) persists regardless of wheel state

### Examples

**Example 1: Twins, Y Motion NONE, Y Wheel ON**
- Formation: Twins (2x2)
- Y Motion: None (no transformation)
- Concepts match as: **2x2 formation**
- Visual: Y shows "Wheel" arc (not a numbered route)
- Concept identification: Unchanged by wheel toggle

**Example 2: Twins, Y Motion AFTER, Y Wheel ON**
- Formation: Twins (transforms to 3x1)
- Y Motion: After (Y flips to left)
- Concepts match as: **3x1 formation** (transformed)
- Visual: Y shows "Wheel" arc originating from left side
- Concept identification: Uses transformed 3x1 formation

**Example 3: Trips Left, Y Motion AFTER, Y Wheel ON**
- Formation: Trips Left (transforms to 2x2)
- Y Motion: After (Y flips to right)
- Concepts match as: **2x2 formation** (transformed)
- Visual: Y shows "Wheel" arc originating from right side
- Concept identification: Uses transformed 2x2 formation

---

## 6. UI Requirements

### Motion Picker Enhancement

**Current State (all formations support motion):**
- Segmented control or picker showing: `None | Stop | After/Go`
- Visible in assignment table for Y receiver row
- Available for: Twins, Trips Left, Trips Right, Pro Left, Pro Right

**Y Wheel Integration (all formations):**
- Motion picker: `None | Stop | After/Go` available for all formations
- **Below** motion picker, a **separate toggle** appears: `Y Wheel` with ON/OFF switch
- Toggle is available in:
  - Twins (motion available; wheel available independently)
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

## 7. Arc Visibility and Rendering Requirements

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

## 8. Implementation Constraints

### Code Review Gates

Before implementation begins, the following must be verified:

1. **Formation Gating:**
   - [ ] Verify `Formation.canApplyMotion()` returns `true` for: Twins, Trips Left, Trips Right, Pro Left, Pro Right
   - [ ] Verify `Formation.canApplyWheel()` returns `true` for: Twins, Trips Left, Trips Right, Pro Left, Pro Right
   - [ ] Code review: Ensure all formations support both motion and wheel independently

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

## 9. Known Issues and Backlog Items

### Resolved (as of 2026-05-29)

- ✅ Arc rendering quality — Fixed via dense sampling (0.02 stride, ~50 points)
- ✅ Smooth curve appearance — Verified in YWheelArcVisualSpecTests

### Pending Verification

- [ ] **Twins Formation Motion Support:** Confirm that Twins supports motion (After/Go) and correctly transforms to 3x1 formation
- [ ] **Post-Motion Arc Start:** When Y has After/Go motion enabled alongside wheel, verify arc starts from Y's **final position**, not original position
- [ ] **Motion Picker Presence:** Verify motion picker appears for Twins and all other formations
- [ ] **Screen Edge Clipping:** Verify arc doesn't clip on all supported screen sizes (iPhone SE to iPad)

---

## 10. Acceptance Criteria (Ken Review Checklist)

Before implementation, Ken must confirm:

- [ ] Arc geometry specification is correct (loopDepth, sideOffset, endpointFraction, sampling)
- [ ] All four scenarios (A–D) describe the intended behavior accurately
- [ ] UI placement (toggle below motion picker) is acceptable
- [ ] "Wheel" route name is acceptable (not "Semi-Circle," "Arc," "Loop," etc.)
- [ ] Field test scope is reasonable (Twins, Trips, Pro formations)
- [ ] Test plan coverage (Scenario A–D + edge cases) is sufficient
- [ ] Any additional requirements or clarifications are documented

---

## 11. Success Metrics (Post-Implementation)

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

