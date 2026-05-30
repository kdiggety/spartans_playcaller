# Y Wheel Arc Issues Backlog

## Issue #1: Arc Rendering — CURRENT FOCUS
**Status:** Diagnosis in progress

**Symptom:**
- Arc doesn't look smooth/curved
- May be rendering as line segments instead of smooth curve
- May be using wrong line width or stroke style
- Geometry might be correct but visual rendering is poor

**Root Cause (Suspected):**
- `yWheelArcPath()` creates a Path with `addCurve()` (should render smoothly)
- But the sampled points (`pathPoints`) are only used for arrow placement, not for drawing the arc itself
- The arc should be visually smooth because SwiftUI's `addCurve()` renders Bézier curves natively
- Possible issues: stroke style (line width, cap, join), opacity, or Z-order

**Expected Behavior:**
- Arc should appear as a single continuous smooth curve
- Similar visual quality to route arrows (which use sampled points + line segments)
- Yellow color with 0.7 opacity
- 3pt line width with round caps and joins

**Investigation Steps:**
1. Verify `addCurve()` is being called correctly
2. Check stroke style parameters (lineWidth, lineCap, lineJoin)
3. Verify opacity and color application
4. Compare visual rendering with motion arc (which uses sampled points + line segments)
5. Check if arc is actually being drawn (Z-order, clipping, or rendering pipeline issue)

**Files to Review:**
- `RouteDiagramView.drawWheel()` — stroke call
- `DiagramRenderer.yWheelArcPath()` — path generation
- `Y_WHEEL_ARC_GEOMETRY.md` — specification

---

## Issue #2: Motion None Visibility
**Status:** Backlog

**Symptom:**
- Y wheel arc only shows when Y Motion (Stop/After/Go) is selected
- Arc should display even when no motion is selected

**Root Cause (Suspected):**
- `drawWheel()` may be gated on motion state
- Or: arc rendering is only triggered for certain receiver assignments

**Expected Behavior:**
- Arc should always display when `yWheelEnabled` is true
- Visible regardless of whether Y has a motion assigned
- Consistent availability across all play calls using Y receiver

**Investigation Steps:**
1. Check `drawWheel()` gate conditions in RouteDiagramView
2. Verify Y assignment is created even without motion
3. Confirm `yWheelArcPath()` handles no-motion case

**Files to Review:**
- `RouteDiagramView.drawWheel()` — gate conditions
- `PlayCall` model — Y assignment creation
- `DiagramRenderer.yWheelArcPath()` — motion dependency

---

## Issue #3: Post-Motion Start Point
**Status:** Backlog

**Symptom:**
- When Y After/Go motion is selected, Y moves to a final position
- Wheel arc currently starts from original Y position, not post-motion position
- Arc should originate from Y's final side-flipped position when After/Go is active

**Root Cause:**
- `yWheelArcPath()` always uses Y's initial position from `receiverPositions()`
- Does not account for motion's effect on Y's position
- Motion changes Y's side (left ↔ right), which affects arc direction

**Expected Behavior:**
- If Y has After/Go motion: arc starts from Y's final position after motion completes
- If Y has Stop motion or no motion: arc starts from Y's initial position
- Arc direction reverses when Y's side changes due to motion

**Investigation Steps:**
1. Get Y's motion from play call
2. Calculate Y's post-motion position (if motion is After/Go)
3. Use post-motion position and side for arc geometry
4. Verify arc direction reverses with side flip

**Files to Review:**
- `DiagramRenderer.yWheelArcPath()` — motion handling
- `DiagramRenderer.yFinalPosition()` — post-motion position calculation
- `PlayCall` model — motion state tracking
