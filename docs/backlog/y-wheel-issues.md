# Y Wheel Arc Issues Backlog

## Issue #1: Arc Rendering — FIXED
**Status:** ✅ RESOLVED in commit 2b105ae

**Root Cause:**
- Arc was using SwiftUI's native `addCurve()` to render a single cubic Bézier curve
- While mathematically correct, this approach provided less control over visual quality
- Comparison with motion arc (which used line segments connecting sampled points) showed
  the line-segment approach provided consistently smoother visual rendering

**Solution Implemented:**
- Changed from native `addCurve()` to dense sampled points with line segments
- Increased sampling density from 0.1 stride (11 points) to 0.02 stride (~50 points)
- Now uses same rendering approach as motion arc for visual consistency
- Dense sampling ensures line segments appear as a smooth curve

**Changes Made:**
- `DiagramRenderer.yWheelArcPath()`:
  - Changed sampling stride from 0.1 to 0.02 (5x more dense)
  - Replaced `path.addCurve()` with point-by-point `path.addLine()`
  - Ensures exact endpoint is always added
- Created `docs/backlog/y-wheel-issues.md` for tracking remaining issues

**Verification:**
- Build succeeds (no errors/warnings)
- All tests pass:
  - YWheelArcVisualSpecTests (10 tests) ✅
  - DiagramRendererYWheelTests ✅
  - RouteDiagramYWheelTests ✅
- Arc now renders as smooth, visually polished U-shaped curve

**Visual Impact:**
- Arc appears as single continuous smooth curve (not segmented)
- Consistent visual quality with other route elements
- Y location selector now works smoothly without visual artifacts

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
