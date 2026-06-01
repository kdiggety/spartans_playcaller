# Y Wheel Feature Test Plan

**Date:** 2026-05-29  
**Status:** Pending Ken Review and Approval  
**Target Execution:** After implementation approval  
**Test Environment:** iOS 17+ device (iPhone 15 Pro preferred, verified on iPhone SE and iPad)

---

## Overview

This test plan validates the Y Wheel feature across all supported formations, with special focus on:
1. **Formation Definitions and Transformations:** Y is always inside receiver; formations transform with motion (After/Go)
2. **Formation Gating:** Twins available for wheel (no motion); Trips/Pro available for both motion and wheel
3. **Arc Geometry Accuracy:** Correct curves for left vs right positions; proper origin at post-motion positions
4. **Concept Matching:** Concepts match transformed formation type; wheel does NOT override concept identification
5. **UI Presence and Behavior:** Toggle visibility, route override ("Wheel" display)
6. **Visual Quality:** Smoothness, clarity, no clipping across screen sizes
7. **Motion Integration:** Arc relocates and changes direction when Y moves via After/Go

**Test Execution Strategy:**
- Unit tests (automated): Formation gating, geometry calculations, concept matching with transformed formations
- Manual UI tests (on device): Visual verification of arc direction, touch interaction, screen size coverage
- Integration tests (automated): Full play flow with wheel + motion combinations, concept matching behavior

---

## Part 1: Pre-Implementation Gating and Formation Definition Verification

These checks must pass **before** implementation begins. They verify the foundation is ready and formation definitions are correct.

### Check 1: Formation Definitions and Structure

**File:** `SpartansPlaycaller/Models/Formation.swift`

**Verification Steps:**

- [ ] **Step 1.1:** Verify Twins formation (2x2 structure)
  - Expected: `case twins = "Twins"` exists
  - Expected: Y is on the RIGHT side (inside receiver in 2x2)
  - Expected: `side(for:)` returns `.right` for Y receiver
  - Command: `grep -A 20 "case twins" /Users/klewisjr/Development/iOS/spartans_playcaller/SpartansPlaycaller/Models/Formation.swift`

- [ ] **Step 1.2:** Verify Trips Left formation (3x1 structure)
  - Expected: `case tripsLeft = "Trips Left"` exists
  - Expected: Y is on the LEFT side (inside receiver, between X and A)
  - Expected: `side(for:)` returns `.left` for Y receiver
  - Command: `grep -A 20 "case tripsLeft" /Users/klewisjr/Development/iOS/spartans_playcaller/SpartansPlaycaller/Models/Formation.swift`

- [ ] **Step 1.3:** Verify Trips Right formation (3x1 structure)
  - Expected: `case tripsRight = "Trips Right"` exists
  - Expected: Y is on the RIGHT side (inside receiver, between A and Z)
  - Expected: `side(for:)` returns `.right` for Y receiver

- [ ] **Step 1.4:** Verify Pro Left and Pro Right formations
  - Expected: Both exist with Y as inside receiver on their respective sides
  - Pro Left: Y on left; Pro Right: Y on right

**Pass Criteria:** All formations define Y as the inside receiver on the correct side.

---

### Check 2: Formation Motion Support and Transformation

**File:** `SpartansPlaycaller/Models/Formation.swift` and `SpartansPlaycaller/Models/ReceiverMotion.swift`

**Verification Steps:**

- [ ] **Step 2.1:** Read `Formation.canApplyMotion()` method
  - Expected: Returns `true` for Trips Left, Trips Right, Pro Left, Pro Right
  - Expected: Returns `false` for Twins
  - Command: `grep -A 10 "func canApplyMotion" /Users/klewisjr/Development/iOS/spartans_playcaller/SpartansPlaycaller/Models/Formation.swift`

- [ ] **Step 2.2:** Code review: Verify wheel gating is independent of motion
  - Search for: Any guard statements gating wheel availability to formations with motion
  - Red flag: `if formation.canApplyMotion() { enableWheel }` — this would prevent Twins wheel
  - Expected: Wheel gating is independent of motion gating; Twins supports wheel but not motion

- [ ] **Step 2.3:** Verify ReceiverMotion.after and .go flip sides correctly
  - Expected: `.after.finalSide(.left)` returns `.right`
  - Expected: `.after.finalSide(.right)` returns `.left`
  - Expected: `.go.finalSide(.left)` returns `.right`
  - Expected: `.go.finalSide(.right)` returns `.left`
  - Command: `grep -A 15 "func finalSide" /Users/klewisjr/Development/iOS/spartans_playcaller/SpartansPlaycaller/Models/ReceiverMotion.swift`

**Pass Criteria:** Motion correctly transforms Y's side; wheel gating independent of motion support.

---

### Check 3: Y Wheel Toggle Support

**File:** `SpartansPlaycaller/Models/ReceiverMotion.swift` and `SpartansPlaycaller/Models/PlayCall.swift`

**Verification Steps:**

- [ ] **Step 3.1:** Check if Y Wheel toggle is represented in model
  - Search: `PlayCall.swift` for `yWheelEnabled` or similar flag
  - Expected: A boolean property representing Y Wheel toggle state (ON/OFF)
  - If missing: Will be added during implementation

- [ ] **Step 3.2:** Check for motion picker UI that allows wheel independent of motion
  - Search: `ReceiverAssignmentView.swift` or `PlayCallerView.swift`
  - Verify: Y Wheel toggle appears separately from motion picker
  - Verify: No logic that gates wheel based on motion selection

**Pass Criteria:** Y Wheel is represented as independent toggle in model and UI layer.

---

### Check 4: Concept Matching with Formation Transformations

**File:** `SpartansPlaycaller/Models/ConceptMatcher.swift` and relevant test files

**Verification Steps:**

- [ ] **Step 4.1:** Understand concept matching logic
  - Review: How concepts are identified based on formation type
  - Expected: Concepts should match against the current formation type (after any transformations)
  - Command: `grep -A 20 "identify" /Users/klewisjr/Development/iOS/spartans_playcaller/SpartansPlaycaller/Models/ConceptMatcher.swift | head -30`

- [ ] **Step 4.2:** Verify formation type is determined after motion is applied
  - Expected: When Y Motion After/Go is active, formation type changes before concept matching
  - Example: Twins + Y After/Go → concept matching uses 3x1 (not 2x2)
  - Example: Trips Left + Y After/Go → concept matching uses 2x2 (not 3x1)

- [ ] **Step 4.3:** Verify Y Wheel doesn't affect concept matching
  - Expected: Y Wheel toggle does not change which formation type is used for concept matching
  - Expected: Concept matching behavior is identical whether wheel is ON or OFF
  - The wheel only affects visual display, not concept identification

**Pass Criteria:** Concept matching uses transformed formation type; wheel toggle doesn't affect matching.

---

## Part 2: Unit Tests (Automated)

These tests verify internal logic and should be included in the implementation.

### Unit Test 2.1: Formation Gating

**Test File:** `SpartansPlaycallerTests/FormationWheelGatingTests.swift` (new)

```swift
// Step 1: Create test file if it doesn't exist

class FormationWheelGatingTests: XCTestCase {
    
    // Test: All formations allow wheel
    func testAllFormationsSupportWheel() {
        let formations: [Formation] = [.twins, .tripsLeft, .tripsRight, .proLeft, .proRight]
        for formation in formations {
            // After implementation, verify each formation returns true for canApplyWheel()
            // XCTAssertTrue(formation.canApplyWheel(), "\\(formation) should support Y Wheel")
            print("Formation \(formation.rawValue) supports wheel: TBD")
        }
    }
    
    // Test: Only Trips and Pro support motion
    func testMotionGatingUnchanged() {
        XCTAssertFalse(Formation.twins.canApplyMotion())
        XCTAssertTrue(Formation.tripsLeft.canApplyMotion())
        XCTAssertTrue(Formation.tripsRight.canApplyMotion())
        XCTAssertTrue(Formation.proLeft.canApplyMotion())
        XCTAssertTrue(Formation.proRight.canApplyMotion())
    }
}
```

**Execution:**
- [ ] Run test: `xcodebuild test -scheme SpartansPlaycaller -only-testing SpartansPlaycallerTests/FormationWheelGatingTests 2>&1 | tail -5`
- [ ] Expected: All tests PASSED

**Pass Criteria:** Twins allows wheel; motion gating unchanged.

---

### Unit Test 2.2: ReceiverMotion Wheel Semantics

**Test File:** `SpartansPlaycallerTests/ReceiverMotionWheelTests.swift` (exists)

```swift
class ReceiverMotionWheelTests: XCTestCase {
    
    func testYWheelStaysSameSide() {
        XCTAssertEqual(ReceiverMotion.wheel.finalSide(originalSide: .left), .left)
        XCTAssertEqual(ReceiverMotion.wheel.finalSide(originalSide: .right), .right)
    }
    
    func testYWheelDescription() {
        XCTAssertEqual(ReceiverMotion.wheel.description, "Y Wheel")
    }
    
    func testYWheelDifferencesFromAfter() {
        let wheelFinal = ReceiverMotion.wheel.finalSide(originalSide: .left)
        let afterFinal = ReceiverMotion.after.finalSide(originalSide: .left)
        
        XCTAssertEqual(wheelFinal, .left, "Wheel stays on left")
        XCTAssertEqual(afterFinal, .right, "After flips to right")
        XCTAssertNotEqual(wheelFinal, afterFinal, "Wheel and After are semantically different")
    }
}
```

**Execution:**
- [ ] Run test: `xcodebuild test -scheme SpartansPlaycaller -only-testing SpartansPlaycallerTests/ReceiverMotionWheelTests 2>&1 | tail -5`
- [ ] Expected: All tests PASSED

**Pass Criteria:** Wheel motion stays on same side; semantically distinct from After/Go.

---

### Unit Test 2.3: Arc Geometry

**Test File:** `SpartansPlaycallerTests/YWheelArcVisualSpecTests.swift` (exists)

These tests verify the Bézier curve math and rendering.

**Key Tests (should all pass after implementation):**

- [ ] `testYWheelArcStartsAtYPosition` — Arc begins at Y's position
- [ ] `testYWheelArcCurvesDownwardOnLeftSide` — Arc curves left and back
- [ ] `testYWheelArcCurvesDownwardOnRightSide` — Arc curves right and back
- [ ] `testYWheelArcReturnsUpwardTowardLOS` — Arc has return segment
- [ ] `testYWheelArcEndpointIsPartiallyBack` — Endpoint at ~55% depth
- [ ] `testYWheelArcScaleIsReasonable` — Depth is 10–40% of field
- [ ] `testYWheelArcUsesYellowColor` — Color is yellow
- [ ] `testYWheelArcPathIsSmooth` — ~50 sampled points, no sharp corners
- [ ] `testYWheelArcOnProLeft` — Works in Pro Left
- [ ] `testYWheelArcOnProRight` — Works in Pro Right

**Execution:**
- [ ] Run test: `xcodebuild test -scheme SpartansPlaycaller -only-testing SpartansPlaycallerTests/YWheelArcVisualSpecTests 2>&1 | tail -10`
- [ ] Expected: All 10 tests PASSED

**Pass Criteria:** Arc geometry is mathematically correct and visually smooth.

---

## Part 3: Manual UI Tests (On Device)

These tests require a running app on iPhone/iPad and manual verification.

### Test Group A: UI Presence and Formation-Specific Behavior

**Setup:**
- Build and run app on iPhone 15 Pro (or target device)
- Pre-select any play that uses Y receiver (e.g., "6794" for Smash concept)

**Test A1: Twins (2x2, no motion)**

- [ ] A1.1: Select Formation → Twins
- [ ] A1.2: Select any play (e.g., "6794")
- [ ] A1.3: Scroll to Y receiver row in assignment table
- [ ] A1.4: **Verify:** Motion picker is **NOT visible** (Twins doesn't support motion)
- [ ] A1.5: **Verify:** Below Y route display, a toggle labeled "Y Wheel" is visible (ON/OFF)
- [ ] A1.6: **Verify:** Toggle is currently OFF (default); Y shows numbered route
- [ ] A1.7: **Verify:** Y is on the RIGHT side of formation diagram (inside receiver in 2x2)
- [ ] A1.8: Tap toggle → ON
- [ ] A1.9: **Verify:** Diagram updates; Y route changes from a number to "Wheel"
- [ ] A1.10: **Verify:** A yellow arc appears starting from Y's position (right side)
- [ ] A1.11: **Verify:** Arc curves RIGHT (away from center of field)
- [ ] A1.12: Tap toggle → OFF
- [ ] A1.13: **Verify:** Route reverts to number; arc disappears

**Expected Result:** PASS if all steps succeed; formation remains 2x2; arc curves right.

---

**Test A2: Trips Left (3x1, no motion)**

- [ ] A2.1: Select Formation → Trips Left
- [ ] A2.2: Select play "6758" (Smash concept in Trips Left)
- [ ] A2.3: Scroll to Y receiver row
- [ ] A2.4: **Verify:** Motion picker is visible, showing [None | Stop | After | Go] (or similar)
- [ ] A2.5: **Verify:** Below motion picker, "Y Wheel" toggle is visible, OFF by default
- [ ] A2.6: **Verify:** Motion is set to None (no transformation)
- [ ] A2.7: **Verify:** Y is on the LEFT side of formation diagram (inside receiver in 3x1)
- [ ] A2.8: Tap "Y Wheel" toggle → ON
- [ ] A2.9: **Verify:** Diagram updates; Y route shows "Wheel"
- [ ] A2.10: **Verify:** Arc appears curving to the LEFT (away from center)
- [ ] A2.11: **Verify:** Formation remains 3x1 (no transformation)
- [ ] A2.12: **Verify:** Arc is smooth and clearly visible

**Expected Result:** PASS if wheel displays correctly; formation remains 3x1; arc curves left.

---

**Test A3: Trips Right (3x1, no motion)**

- [ ] A3.1: Select Formation → Trips Right
- [ ] A3.2: Select play with Y receiver (e.g., "6758")
- [ ] A3.3: **Verify:** Y is on the RIGHT side of formation diagram (inside receiver in 3x1)
- [ ] A3.4: Set Motion → None, Wheel → ON
- [ ] A3.5: **Verify:** Arc curves to the RIGHT (away from center)
- [ ] A3.6: **Verify:** Formation remains 3x1 (no transformation)
- [ ] A3.7: **Verify:** Arc direction is correct for right-side Y

**Expected Result:** PASS if arc curves correctly on right side; formation remains 3x1.

---

**Test A4: Pro Left (3x1, no motion)**

- [ ] A4.1: Select Formation → Pro Left
- [ ] A4.2: Select play with Y receiver
- [ ] A4.3: **Verify:** Y is on the LEFT side
- [ ] A4.4: Set Wheel → ON
- [ ] A4.5: **Verify:** Arc appears curving LEFT on left side

**Expected Result:** PASS if toggle visible and arc renders on left.

---

**Test A5: Pro Right (3x1, no motion)**

- [ ] A5.1: Select Formation → Pro Right
- [ ] A5.2: **Verify:** Y is on the RIGHT side
- [ ] A5.3: Set Wheel → ON
- [ ] A5.4: **Verify:** Arc appears curving RIGHT on right side

**Expected Result:** PASS if toggle visible and arc renders on right.

---

### Test Group B: Arc Direction and Geometry (Detailed)

**Setup:** Formation: Trips Left, Motion: None, Wheel: ON

**Test B1: Arc Curves Left (Away from Center)**

- [ ] B1.1: Enable Y Wheel in Trips Left
- [ ] B1.2: **Verify in diagram:** Arc curves from Y's position to the **left**
- [ ] B1.3: **Verify:** Arc does NOT curve toward the center of field (Z side)
- [ ] B1.4: **Verify:** Arc bends away from the center

**Expected Result:** PASS if arc direction is clearly left.

---

**Test B2: Arc Starts at Bottom of Y Circle**

- [ ] B2.1: In diagram, identify Y receiver position (should have a circle or dot)
- [ ] B2.2: **Verify:** Arc begins at the bottom edge of Y's circle (at LOS)
- [ ] B2.3: Arc does NOT start above or below Y's position

**Expected Result:** PASS if arc origin is at Y's bottom.

---

**Test B3: Arc Start and End X-Coordinates Are Different (Tilted Arc)**

- [ ] B3.1: Trace the arc from start to end visually
- [ ] B3.2: **Verify:** Arc endpoint X-coordinate is **different** from start X (tilted, not vertical)
- [ ] B3.3: Endpoint should be to the left of start (on left-side formation)

**Expected Result:** PASS if arc is tilted.

---

**Test B4: Arc Endpoint Angles Back Toward LOS (~45°)**

- [ ] B4.1: Look at the final segment of the arc (last ~20px)
- [ ] B4.2: **Verify:** Arc is angling back toward the line of scrimmage (not perpendicular)
- [ ] B4.3: Angle should be approximately 45° (diagonal, not sharp vertical)

**Expected Result:** PASS if endpoint angle is reasonable (~45°).

---

**Test B5: Arc Depth Is Reasonable (~22% of Field)**

- [ ] B5.1: Estimate arc depth (how far down the field it extends)
- [ ] B5.2: Compare to field height visually
- [ ] B5.3: **Verify:** Arc extends roughly 20–25% of field height down

**Expected Result:** PASS if arc depth is not too shallow or too deep.

---

### Test Group C: Formation Transformation with Y Motion (After/Go)

**Test C1: Twins + After Motion (transforms 2x2 → 3x1)**

- [ ] C1.1: Select Formation → Twins, Wheel ON
- [ ] C1.2: Observe: Arc curves RIGHT (Y on right, 2x2 formation)
- [ ] C1.3: Change Motion → After (Y flips to left)
- [ ] C1.4: **Verify:** Arc has relocated to Y's NEW position on the LEFT side
- [ ] C1.5: **Verify:** Arc now curves LEFT (away from center in new position)
- [ ] C1.6: **Verify:** Formation has visually transformed from 2x2 to 3x1 (3 on left, 1 on right)
- [ ] C1.7: **Verify:** Arc is still visible and smooth

**Expected Result:** PASS if arc relocates, direction reverses, and formation transforms to 3x1.

---

**Test C2: Twins + Go Motion (transforms 2x2 → 3x1)**

- [ ] C2.1: Select Formation → Twins, Wheel ON
- [ ] C2.2: Change Motion → Go (Y flips to left, similar to After)
- [ ] C2.3: **Verify:** Arc curves LEFT (Y on left side after motion)
- [ ] C2.4: **Verify:** Formation transforms to 3x1 (3 on left, 1 on right)

**Expected Result:** PASS if Go motion transforms formation similarly to After.

---

**Test C3: Trips Left + After Motion (transforms 3x1 → 2x2)**

- [ ] C3.1: Select Formation → Trips Left, Wheel ON, Motion: None
- [ ] C3.2: Observe: Arc curves LEFT (Y on left, 3x1 formation)
- [ ] C3.3: Change Motion → After (Y flips to right)
- [ ] C3.4: **Verify:** Arc has relocated to Y's NEW position on the RIGHT side
- [ ] C3.5: **Verify:** Arc now curves RIGHT (away from center in new position)
- [ ] C3.6: **Verify:** Formation has visually transformed from 3x1 to 2x2 (2 on each side)
- [ ] C3.7: **Verify:** Arc is still visible and smooth

**Expected Result:** PASS if arc relocates, direction reverses, and formation transforms to 2x2.

---

**Test C4: Trips Right + After Motion (transforms 3x1 → 2x2)**

- [ ] C4.1: Select Formation → Trips Right, Wheel ON, Motion: None
- [ ] C4.2: Observe: Arc curves RIGHT (Y on right, 3x1 formation)
- [ ] C4.3: Change Motion → After (Y flips to left)
- [ ] C4.4: **Verify:** Arc curves LEFT (Y on left side after motion)
- [ ] C4.5: **Verify:** Formation transforms to 2x2 (2 on each side)

**Expected Result:** PASS if arc direction reverses and formation transforms to 2x2.

---

### Test Group D: Route Override and Display

**Setup:** Formation: Twins, Wheel: varies, a play with Y route (e.g., "6794")

**Test D1: Route Override (Wheel OFF)**

- [ ] D1.1: Enable Twins, parse or select play "6794"
- [ ] D1.2: Wheel → OFF
- [ ] D1.3: In assignment table (Y row), **verify:** Route shows the actual number (e.g., "7")
- [ ] D1.4: In diagram, **verify:** A route graphic for route 7 is visible (numbered route arrow/line)

**Expected Result:** PASS if numbered route is displayed.

---

**Test D2: Route Override (Wheel ON)**

- [ ] D2.1: Same setup as D1
- [ ] D2.2: Wheel → ON
- [ ] D2.3: In assignment table (Y row), **verify:** Route now shows "Wheel" (not "7")
- [ ] D2.4: In diagram, **verify:** The numbered route graphic disappears; only arc is shown
- [ ] D2.5: Arc is clearly visible and unmistakable from other routes

**Expected Result:** PASS if route changes from number to "Wheel" and diagram updates.

---

### Test Group E: Visual Quality and Rendering

**Setup:** Formation: Trips Left, Wheel: ON

**Test E1: Arc Smoothness**

- [ ] E1.1: Examine the arc in the diagram closely
- [ ] E1.2: **Verify:** Arc is smooth and curved (not segmented or jagged)
- [ ] E1.3: No visible straight-line segments or corners
- [ ] E1.4: Arc should appear as a single continuous curve

**Expected Result:** PASS if arc is smooth.

---

**Test E2: Arc Smoothness at Different Zoom Levels**

- [ ] E2.1: If app supports pinch-zoom on diagram, zoom in on arc
- [ ] E2.2: **Verify:** Arc remains smooth at high magnification
- [ ] E2.3: No visible line segments or pixelation

**Expected Result:** PASS if arc scales smoothly.

---

**Test E3: Arc Color**

- [ ] E3.1: **Verify:** Arc color is yellow (consistent with motion arcs)
- [ ] E3.2: Yellow is consistent with other route/motion graphics
- [ ] E3.3: Color is not faded or hard to see

**Expected Result:** PASS if color is correct and visible.

---

**Test E4: Arc Does Not Clip at Edges**

- [ ] E4.1: Run app on iPhone SE (4.7" smallest expected screen)
- [ ] E4.2: Enable Trips Left, Wheel ON
- [ ] E4.3: **Verify:** Arc is fully visible, not cut off at any edge
- [ ] E4.4: Left edge: arc curves left but doesn't extend beyond screen
- [ ] E4.5: Bottom edge: arc extends down but doesn't clip at bottom of field
- [ ] E4.6: Right edge: arc doesn't clip on right side

- [ ] E4.7: Run app on iPad (12.9" largest expected screen)
- [ ] E4.8: **Verify:** Arc is visible and proportionate on large screen (not too small)

**Expected Result:** PASS on both iPhone SE and iPad without clipping.

---

**Test E5: Arrow Visibility at Endpoint**

- [ ] E5.1: Examine the endpoint of the arc
- [ ] E5.2: **Verify:** An arrow is visible pointing back toward the LOS
- [ ] E5.3: Arrow color is consistent with arc (yellow)
- [ ] E5.4: Arrow is clearly distinguishable

**Expected Result:** PASS if arrow is visible and pointing correctly.

---

### Test Group F: Edge Cases and Robustness

**Test F1: Toggle Wheel ON/OFF Multiple Times**

- [ ] F1.1: Formation: Twins, Motion: None, Wheel: OFF
- [ ] F1.2: Tap toggle: OFF → ON (arc appears)
- [ ] F1.3: Tap toggle: ON → OFF (arc disappears)
- [ ] F1.4: Tap toggle: OFF → ON (arc reappears)
- [ ] F1.5: Repeat 3–4 times
- [ ] F1.6: **Verify:** Each toggle is responsive; arc consistently appears/disappears
- [ ] F1.7: **Verify:** No lag, freeze, or visual artifacts

**Expected Result:** PASS if toggle is responsive and consistent.

---

**Test F2: Switch Y Motion While Wheel is ON**

- [ ] F2.1: Formation: Trips Left, Wheel: ON, Motion: None
- [ ] F2.2: Arc is visible on left side
- [ ] F2.3: Change Motion: None → After
- [ ] F2.4: **Verify:** Arc updates (relocates and possibly changes direction)
- [ ] F2.5: Change Motion: After → Go
- [ ] F2.6: **Verify:** Arc updates correctly
- [ ] F2.7: Change Motion: Go → Stop
- [ ] F2.8: **Verify:** Arc updates correctly
- [ ] F2.9: **Verify:** No crashes or visual corruption

**Expected Result:** PASS if arc updates smoothly for all motion changes.

---

**Test F3: Switch Formations While Wheel is ON**

- [ ] F3.1: Formation: Twins, Wheel: ON, arc visible, Motion: None
- [ ] F3.2: Change Formation: Twins → Trips Left
- [ ] F3.3: **Verify:** Arc updates for Trips Left (curves left)
- [ ] F3.4: Change Formation: Trips Left → Trips Right
- [ ] F3.5: **Verify:** Arc updates (curves right)
- [ ] F3.6: Change Formation: Trips Right → Pro Left
- [ ] F3.7: **Verify:** Arc updates for Pro Left (curves left)
- [ ] F3.8: **Verify:** Wheel toggle remains visible and functional
- [ ] F3.9: **Verify:** No crashes or broken state

**Expected Result:** PASS if formations switch smoothly with wheel enabled.

---

**Test F5: Toggle Y Wheel During Formation Transformation**

- [ ] F5.1: Formation: Trips Left, Motion: None, Wheel: OFF
- [ ] F5.2: Change Motion: None → After (formation transforms to 2x2, Y moves to right)
- [ ] F5.3: **Verify:** Y has moved to right side; formation visually changed
- [ ] F5.4: Enable Wheel: OFF → ON
- [ ] F5.5: **Verify:** Arc appears on right side (at transformed position)
- [ ] F5.6: Disable Wheel: ON → OFF
- [ ] F5.7: **Verify:** Arc disappears; route shows numbered form
- [ ] F5.8: Change Motion: After → None (Y returns to left, formation transforms back to 3x1)
- [ ] F5.9: Enable Wheel: OFF → ON
- [ ] F5.10: **Verify:** Arc now curves left (at original position after motion removed)

**Expected Result:** PASS if wheel toggle works correctly through formation transformations.

---

**Test F6: Switch Between Formations With and Without Motion Support**

- [ ] F6.1: Formation: Twins (no motion support), Wheel: ON, Motion: none (grayed out)
- [ ] F6.2: Change Formation: Twins → Trips Left (motion supported)
- [ ] F6.3: **Verify:** Motion picker appears and becomes active
- [ ] F6.4: **Verify:** Wheel toggle still visible and functional
- [ ] F6.5: Enable Motion: After
- [ ] F6.6: **Verify:** Arc relocates to Y's new position (left→right transformation)
- [ ] F6.7: Change Formation: Trips Left → Twins (motion not supported)
- [ ] F6.8: **Verify:** Motion picker disappears
- [ ] F6.9: **Verify:** Wheel toggle remains enabled and arc visible

**Expected Result:** PASS if UI adapts correctly when switching formations with different motion support.

---

**Test F4: Rotate Device Between Portrait and Landscape**

- [ ] F4.1: Formation: Twins, Wheel: ON, arc visible in portrait
- [ ] F4.2: Rotate device to landscape
- [ ] F4.3: **Verify:** Arc is still visible in landscape
- [ ] F4.4: **Verify:** Arc proportions are correct (not stretched or distorted)
- [ ] F4.5: **Verify:** No clipping at new screen edges
- [ ] F4.6: Rotate back to portrait
- [ ] F4.7: **Verify:** Arc returns to portrait proportions correctly

**Expected Result:** PASS if arc respects device orientation.

---

## Part 4: Integration Tests (Automated)

These tests verify Y Wheel works with the broader play-calling flow and concept matching with formation transformations.

### Integration Test 4.1: Concept Matching with Transformed Formations

**Test File:** `SpartansPlaycallerTests/ConceptMatcherTransformationTests.swift` (new)

```swift
class ConceptMatcherTransformationTests: XCTestCase {
    
    func testTwinsWithoutMotionMatches2x2Concept() {
        // Setup: Twins, Smash concept (2x2), no motion, wheel enabled
        var playCall = PlayCall(
            formation: .twins,
            digitSequence: "6758",
            selectedConcept: .smash,
            yReceiverMotion: nil,
            yWheelEnabled: true
        )
        
        let identified = ConceptMatcher.identify(playCall)
        // Smash should match as 2x2 concept (formation unchanged)
        XCTAssertTrue(identified.concept == .smash || identified.concept == .matched_2x2,
                      "Twins without motion should match 2x2 concepts")
    }
    
    func testTwinsWithAfterMotionMatches3x1Concept() {
        // Setup: Twins (2x2) + After motion → transforms to 3x1, wheel enabled
        var playCall = PlayCall(
            formation: .twins,
            digitSequence: "6758",
            selectedConcept: .smash,
            yReceiverMotion: .after,
            yWheelEnabled: true
        )
        
        // After motion transforms Twins from 2x2 to 3x1
        // Concepts should match against the TRANSFORMED 3x1 formation
        let identified = ConceptMatcher.identify(playCall)
        XCTAssertTrue(identified.formation == .tripsLike_3x1 || identified.concept == .matched_3x1,
                      "Twins with After motion should match 3x1 concepts (transformed)")
    }
    
    func testTripsLeftWithoutMotionMatches3x1Concept() {
        // Setup: Trips Left, Smash concept (3x1), no motion, wheel enabled
        var playCall = PlayCall(
            formation: .tripsLeft,
            digitSequence: "6758",
            selectedConcept: .smash,
            yReceiverMotion: nil,
            yWheelEnabled: true
        )
        
        let identified = ConceptMatcher.identify(playCall)
        XCTAssertTrue(identified.concept == .smash || identified.concept == .matched_3x1,
                      "Trips Left without motion should match 3x1 concepts")
    }
    
    func testTripsLeftWithAfterMotionMatches2x2Concept() {
        // Setup: Trips Left (3x1) + After motion → transforms to 2x2, wheel enabled
        var playCall = PlayCall(
            formation: .tripsLeft,
            digitSequence: "6758",
            selectedConcept: .smash,
            yReceiverMotion: .after,
            yWheelEnabled: true
        )
        
        // After motion transforms Trips Left from 3x1 to 2x2
        // Concepts should match against the TRANSFORMED 2x2 formation
        let identified = ConceptMatcher.identify(playCall)
        XCTAssertTrue(identified.formation == .twins_2x2 || identified.concept == .matched_2x2,
                      "Trips Left with After motion should match 2x2 concepts (transformed)")
    }
    
    func testYWheelDoesNotAffectConceptMatching() {
        // Setup: Trips Left, no motion, same concept with wheel OFF and ON
        let wheelOff = PlayCall(
            formation: .tripsLeft,
            digitSequence: "6758",
            selectedConcept: .smash,
            yReceiverMotion: nil,
            yWheelEnabled: false
        )
        
        let wheelOn = PlayCall(
            formation: .tripsLeft,
            digitSequence: "6758",
            selectedConcept: .smash,
            yReceiverMotion: nil,
            yWheelEnabled: true
        )
        
        let identifiedOff = ConceptMatcher.identify(wheelOff)
        let identifiedOn = ConceptMatcher.identify(wheelOn)
        
        // Concept matching should be identical whether wheel is ON or OFF
        XCTAssertEqual(identifiedOff.concept, identifiedOn.concept,
                       "Y Wheel should not affect concept identification")
    }
}
```

**Execution:**
- [ ] Run test: `xcodebuild test -scheme SpartansPlaycaller -only-testing SpartansPlaycallerTests/ConceptMatcherTransformationTests 2>&1 | tail -10`
- [ ] Expected: All tests PASSED

**Pass Criteria:** 
- Concepts match transformed formation type (not original formation)
- Wheel toggle does not affect concept matching
- Formation transformations are reflected in concept identification

---

### Integration Test 4.2: Formation Transformation and Visual Updates

**Test File:** `SpartansPlaycallerTests/PlayCallFlowYWheelTests.swift` (exists or new)

```swift
class PlayCallFlowYWheelTests: XCTestCase {
    let viewModel = PlayCallerViewModel()
    
    func testTwinsWithMotionTransformation() {
        // Step 1: Select Twins formation
        viewModel.selectedFormation = .twins
        
        // Step 2: Enable Y Wheel
        viewModel.yWheelEnabled = true
        XCTAssertTrue(viewModel.yWheelEnabled, "Wheel should be enabled")
        
        // Step 3: Verify diagram shows arc on right side (Y on right in 2x2)
        let diagramNoMotion = RouteDiagramView(playCall: viewModel.playCall)
        XCTAssertNotNil(diagramNoMotion, "Diagram should render without crashing")
        
        // Step 4: Apply After motion (Y flips to left, formation transforms to 3x1)
        viewModel.selectedMotion = .after
        
        // Step 5: Verify diagram updates with arc on left side and formation transformed
        let diagramWithMotion = RouteDiagramView(playCall: viewModel.playCall)
        XCTAssertNotNil(diagramWithMotion, "Diagram should handle transformation without crashing")
        
        // Step 6: Verify Y position changed and arc direction reversed
        let yPositionAfterMotion = viewModel.playCall.yReceiver.position(in: viewModel.selectedFormation)
        XCTAssertEqual(yPositionAfterMotion, .left, "Y should be on left side after After motion")
    }
    
    func testTripsLeftWithMotionTransformation() {
        // Step 1: Select Trips Left formation
        viewModel.selectedFormation = .tripsLeft
        
        // Step 2: Enable Y Wheel
        viewModel.yWheelEnabled = true
        
        // Step 3: Verify arc curves left (Y on left in 3x1)
        let diagramNoMotion = RouteDiagramView(playCall: viewModel.playCall)
        XCTAssertNotNil(diagramNoMotion, "Diagram should render without crashing")
        
        // Step 4: Apply After motion (Y flips to right, formation transforms to 2x2)
        viewModel.selectedMotion = .after
        
        // Step 5: Verify diagram updates with arc on right side
        let diagramWithMotion = RouteDiagramView(playCall: viewModel.playCall)
        XCTAssertNotNil(diagramWithMotion, "Diagram should handle transformation without crashing")
        
        // Step 6: Verify Y position changed
        let yPositionAfterMotion = viewModel.playCall.yReceiver.position(in: viewModel.selectedFormation)
        XCTAssertEqual(yPositionAfterMotion, .right, "Y should be on right side after After motion")
    }
    
    func testYWheelToggleWithTransformedFormation() {
        // Setup: Trips Left with After motion (transformed to 2x2)
        viewModel.selectedFormation = .tripsLeft
        viewModel.selectedMotion = .after
        
        // Toggle wheel off and on
        viewModel.yWheelEnabled = false
        var diagram = RouteDiagramView(playCall: viewModel.playCall)
        XCTAssertNotNil(diagram, "Diagram should render with wheel OFF")
        
        viewModel.yWheelEnabled = true
        diagram = RouteDiagramView(playCall: viewModel.playCall)
        XCTAssertNotNil(diagram, "Diagram should render with wheel ON after transformation")
        
        // Verify no crashes and consistent behavior
        XCTAssertTrue(viewModel.yWheelEnabled, "Wheel toggle should persist")
    }
}
```

**Execution:**
- [ ] Run test: `xcodebuild test -scheme SpartansPlaycaller -only-testing SpartansPlaycallerTests/PlayCallFlowYWheelTests 2>&1 | tail -10`
- [ ] Expected: Tests PASSED (no crashes, transformations handled correctly)

**Pass Criteria:** 
- Formation transformations update arc position and direction
- Y position changes correctly with motion
- Wheel toggle works with transformed formations
- No crashes during visual updates

---

## Part 5: Regression Testing

### Regression Test 5.1: Existing Routes Still Work

**Test File:** Use existing `SpartansPlaycallerTests/RouteInterpreterTests.swift`

**Verification:**
- [ ] Run test: `xcodebuild test -scheme SpartansPlaycaller -only-testing SpartansPlaycallerTests/RouteInterpreterTests 2>&1 | tail -5`
- [ ] Expected: All tests PASSED (no behavioral changes to routes 1–9)

**Pass Criteria:** No regressions in existing route system.

---

### Regression Test 5.2: Existing Motion Still Works

**Test File:** Use existing motion tests (e.g., `YReceiverMotionTests.swift`)

**Verification:**
- [ ] Run test: `xcodebuild test -scheme SpartansPlaycaller -only-testing SpartansPlaycallerTests/YReceiverMotionTests 2>&1 | tail -5`
- [ ] Expected: All tests PASSED (motion stops, flips, etc. unchanged)

**Pass Criteria:** No regressions in motion system.

---

### Regression Test 5.3: Concept Library Still Works

**Test File:** Use existing `ConceptLibraryTests.swift` or `ConceptMatcherTests.swift`

**Verification:**
- [ ] Run test: `xcodebuild test -scheme SpartansPlaycaller -only-testing SpartansPlaycallerTests/ConceptLibraryTests 2>&1 | tail -5`
- [ ] Expected: All tests PASSED (existing concepts unchanged)

**Pass Criteria:** No regressions in concept system.

---

## Part 6: Device Coverage Matrix

### Screen Size Testing

| Device | Screen Size | Status | Notes |
|--------|------------|--------|-------|
| iPhone SE | 4.7" | Must test | Smallest expected screen |
| iPhone 15 Pro | 6.7" | Primary | Target device |
| iPad | 12.9" | Must test | Largest expected screen |

**Test Steps for Each Device:**
1. Build and run app
2. Enable Y Wheel in each formation
3. Verify arc is visible and not clipped
4. Verify toggle is accessible and responsive
5. Verify rotation works (if applicable)

**Pass Criteria:** Arc renders correctly on all three screen sizes without clipping.

---

## Part 7: Field Test Acceptance Checklist

After all manual tests pass, Ken should verify:

- [ ] All four scenarios (A–D) work as expected
- [ ] Arc direction is correct for each formation
- [ ] Arc is smooth and visually polished
- [ ] Arc doesn't clip on any screen size
- [ ] Motion and wheel work together without conflicts
- [ ] UI is intuitive (toggle placement, visibility)
- [ ] Route display correctly shows "Wheel"
- [ ] No crashes or visual artifacts
- [ ] Ready for field testing week of 2026-06-02

---

## Part 8: Test Execution Log

**To be completed by testing agent after implementation:**

| Test | Result | Notes | Date |
|------|--------|-------|------|
| Test A1: Twins | [ ] PASS / [ ] FAIL |  | __ |
| Test A2: Trips Left | [ ] PASS / [ ] FAIL |  | __ |
| Test A3: Trips Right | [ ] PASS / [ ] FAIL |  | __ |
| Test A4: Pro Left | [ ] PASS / [ ] FAIL |  | __ |
| Test A5: Pro Right | [ ] PASS / [ ] FAIL |  | __ |
| Test B1–B5: Arc Geometry | [ ] PASS / [ ] FAIL |  | __ |
| Test C1–C2: Post-Motion | [ ] PASS / [ ] FAIL |  | __ |
| Test D1–D2: Route Override | [ ] PASS / [ ] FAIL |  | __ |
| Test E1–E5: Visual Quality | [ ] PASS / [ ] FAIL |  | __ |
| Test F1–F4: Edge Cases | [ ] PASS / [ ] FAIL |  | __ |
| Integration Tests | [ ] PASS / [ ] FAIL |  | __ |
| Regression Tests | [ ] PASS / [ ] FAIL |  | __ |
| Device Coverage | [ ] PASS / [ ] FAIL |  | __ |

---

## Part 9: Known Risks and Mitigations

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Arc clips on small screens | Medium | Visual defect | Test on iPhone SE before field test |
| Motion + wheel interaction breaks | Medium | Feature unusable | Automated integration tests required |
| Arc not smooth (segmented) | Low | Visual polish | Verify sampling density (0.02 stride, ~50 points) |
| Concept matching breaks with wheel | Low | Concept ID fails | Automated concept matcher tests |
| Route override doesn't apply | Medium | Confusion (shows number, not "Wheel") | Manual test D1–D2 before field test |

---

## Summary

**Total Manual Tests:** 22 test groups (A–F)  
**Total Automated Tests:** 4 test suites  
**Regression Tests:** 3 existing test suites  
**Screen Sizes Tested:** 3 (iPhone SE, iPhone 15 Pro, iPad)  
**Estimated Test Execution Time:** 2–3 hours (with automation)  

**Before Implementation, Ken Must Approve:**
1. All requirements in `Y_WHEEL_REQUIREMENTS.md`
2. All test coverage in this plan
3. Formation gating logic (Twins wheel, Trips/Pro motion+wheel)
4. Arc geometry parameters

**After Implementation, Testing Agent Must Execute:**
1. All automated unit + integration tests
2. All manual UI tests (one device minimum: iPhone 15 Pro)
3. All regression tests
4. Device coverage (iPhone SE, iPad minimum for clip testing)
5. Completion of execution log above

---

## Revision History

| Date | Change | Status |
|------|--------|--------|
| 2026-05-29 | Initial test plan draft | Pending Ken Review |

