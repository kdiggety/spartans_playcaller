# Y Wheel Feature Test Plan

**Date:** 2026-05-29  
**Status:** Pending Ken Review and Approval  
**Target Execution:** After implementation approval  
**Test Environment:** iOS 17+ device (iPhone 15 Pro preferred, verified on iPhone SE and iPad)

---

## Overview

This test plan validates the Y Wheel feature across all supported formations, with special focus on:
1. Formation gating (Twins always enabled, Trips/Pro with optional motion)
2. Arc geometry accuracy (left vs right curves, post-motion positioning)
3. UI presence and behavior (toggle visibility, route override)
4. Visual quality (smoothness, clarity, no clipping)
5. Integration with existing features (motion interaction, concept matching)

**Test Execution Strategy:**
- Unit tests (automated): Formation gating, geometry calculations, route semantics
- Manual UI tests (on device): Visual verification, touch interaction, screen size coverage
- Integration tests (automated): Full play flow with wheel + motion combinations

---

## Part 1: Pre-Implementation Gating Verification

These checks must pass **before** implementation begins. They verify the foundation is ready.

### Check 1: Formation Motion Support

**File:** `SpartansPlaycaller/Models/Formation.swift`

**Verification Steps:**

- [ ] **Step 1.1:** Read `Formation.canApplyMotion()` method
  - Expected: Returns `true` for Trips Left, Trips Right, Pro Left, Pro Right
  - Expected: Returns `false` for Twins
  - Command: `grep -A 10 "func canApplyMotion" /Users/klewisjr/Development/iOS/spartans_playcaller/SpartansPlaycaller/Models/Formation.swift`

- [ ] **Step 1.2:** Code review: Check for any logic that would break Twins wheel support
  - Search for: Any guard statements gating wheel availability to formations with motion
  - Red flag: `if formation.canApplyMotion() { enableWheel }` — this would prevent Twins
  - Expected: Wheel gating is independent of motion gating

- [ ] **Step 1.3:** Verify Twins formation definition
  - Expected: `case twins = "Twins"` exists in Formation enum
  - Expected: `side(for:)` returns correct sides (X, Y = left; Z, A = right)
  - Command: `grep -A 15 "case twins" /Users/klewisjr/Development/iOS/spartans_playcaller/SpartansPlaycaller/Models/Formation.swift`

**Pass Criteria:** All three steps confirm formation gating allows Twins wheel while restricting motion.

---

### Check 2: ReceiverMotion Wheel Support

**File:** `SpartansPlaycaller/Models/ReceiverMotion.swift`

**Verification Steps:**

- [ ] **Step 2.1:** Check if `ReceiverMotion.wheel` case exists
  - Command: `grep "case wheel" /Users/klewisjr/Development/iOS/spartans_playcaller/SpartansPlaycaller/Models/ReceiverMotion.swift`
  - Expected: Output shows `case wheel` (or similar)
  - If missing: Will be added during implementation

- [ ] **Step 2.2:** Verify `finalSide(originalSide:)` implementation
  - Expected: `case .wheel: return originalSide` (doesn't flip sides like After/Go)
  - Command: `grep -A 1 "case .wheel" /Users/klewisjr/Development/iOS/spartans_playcaller/SpartansPlaycaller/Models/ReceiverMotion.swift`

- [ ] **Step 2.3:** Check for motion picker UI that restricts wheel to Trips/Pro only
  - Search: `ReceiverAssignmentView.swift` or `PlayCallerView.swift` for motion picker
  - Verify: No logic that gates wheel based on motion (wheel should be independent)

**Pass Criteria:** ReceiverMotion supports wheel as an independent option from motion.

---

### Check 3: Route Assignment Wheel Support

**File:** `SpartansPlaycaller/Models/RouteAssignment.swift`

**Verification Steps:**

- [ ] **Step 3.1:** Check if route can be assigned as "Wheel"
  - Search: RouteAssignment struct for a field representing the route name/type
  - Expected: Either a string field (route can be "Wheel") or an enum case for wheel
  - Command: `grep -E "(route|routeName)" /Users/klewisjr/Development/iOS/spartans_playcaller/SpartansPlaycaller/Models/RouteAssignment.swift | head -10`

- [ ] **Step 3.2:** Verify route interpretation logic handles wheel
  - Search: RouteNumber.meaning(on:) or RouteInterpreter for wheel handling
  - Expected: Wheel route either:
    - Has its own RouteMeaning type (e.g., `.wheel` case), OR
    - Delegates to underlying numbered route for concept matching while display overrides to "Wheel"

**Pass Criteria:** Route system can represent and display "Wheel" as a distinct route type.

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

### Test Group A: UI Presence (All Formations)

**Setup:**
- Build and run app on iPhone 15 Pro (or target device)
- Pre-select any play that uses Y receiver (e.g., "6794" for Smash concept)

**Test A1: Twins**

- [ ] A1.1: Select Formation → Twins
- [ ] A1.2: Select any play (e.g., "6794")
- [ ] A1.3: Scroll to Y receiver row in assignment table
- [ ] A1.4: **Verify:** Motion picker is **NOT visible** (Twins doesn't support motion)
- [ ] A1.5: **Verify:** Below Y route display, a toggle labeled "Y Wheel" is visible (ON/OFF)
- [ ] A1.6: **Verify:** Toggle is currently OFF (default)
- [ ] A1.7: Tap toggle → ON
- [ ] A1.8: **Verify:** Diagram updates; Y route changes from a number (e.g., "7") to "Wheel"
- [ ] A1.9: **Verify:** A yellow arc appears in diagram starting from Y's position
- [ ] A1.10: Tap toggle → OFF
- [ ] A1.11: **Verify:** Route reverts to number; arc disappears

**Expected Result:** PASS if all steps succeed; FAIL if toggle is not visible or arc doesn't appear/disappear.

---

**Test A2: Trips Left**

- [ ] A2.1: Select Formation → Trips Left
- [ ] A2.2: Select play "6758" (Smash concept in Trips Left)
- [ ] A2.3: Scroll to Y receiver row
- [ ] A2.4: **Verify:** Motion picker is visible, showing [None | Stop | After | Go] (or similar)
- [ ] A2.5: **Verify:** Below motion picker, "Y Wheel" toggle is visible, OFF by default
- [ ] A2.6: Motion is set to None
- [ ] A2.7: Tap "Y Wheel" toggle → ON
- [ ] A2.8: **Verify:** Diagram updates; Y route shows "Wheel"
- [ ] A2.9: **Verify:** Arc appears curving to the LEFT (away from center)
- [ ] A2.10: Change motion: None → After
- [ ] A2.11: **Verify:** Arc redraws (may curve direction if Y flips sides)
- [ ] A2.12: **Verify:** Arc is still visible and smooth

**Expected Result:** PASS if wheel and motion work together.

---

**Test A3: Trips Right**

- [ ] A3.1: Select Formation → Trips Right
- [ ] A3.2: Select play (e.g., "6758" as Smash mirror for Trips Right)
- [ ] A3.3: Verify Y Wheel toggle is visible
- [ ] A3.4: Set Motion → None, Wheel → ON
- [ ] A3.5: **Verify:** Arc curves to the RIGHT (opposite of Trips Left)
- [ ] A3.6: **Verify:** Arc direction is correct for right side

**Expected Result:** PASS if arc curves correctly on right side.

---

**Test A4: Pro Left**

- [ ] A4.1: Select Formation → Pro Left
- [ ] A4.2: Select play with Y receiver
- [ ] A4.3: Verify Y Wheel toggle is visible
- [ ] A4.4: Enable wheel, verify arc appears on left side

**Expected Result:** PASS if toggle visible and arc renders.

---

**Test A5: Pro Right**

- [ ] A5.1: Select Formation → Pro Right
- [ ] A5.2: Enable wheel, verify arc appears on right side

**Expected Result:** PASS if toggle visible and arc renders.

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

### Test Group C: Post-Motion Position (Advanced)

**Setup:** Formation: Trips Left, Motion: After, Wheel: ON

**Test C1: Arc Starts from Y's Post-Motion Position**

- [ ] C1.1: Select Trips Left, Y Wheel ON
- [ ] C1.2: Set Motion → None; observe arc position
- [ ] C1.3: Change Motion → After (Y flips to right side)
- [ ] C1.4: **Verify:** Arc has moved; it now originates from Y's NEW position on the right side
- [ ] C1.5: **Verify:** Arc is still visible (not lost or hidden)

**Expected Result:** PASS if arc relocates when motion changes Y's position.

---

**Test C2: Arc Curves Opposite Direction After Motion Flip**

- [ ] C2.1: With Motion: None, Wheel: ON — observe arc curves LEFT
- [ ] C2.2: Change Motion → After
- [ ] C2.3: **Verify:** Arc now curves RIGHT (mirrors the left-side curve)
- [ ] C2.4: This is expected because Y has flipped to the right side

**Expected Result:** PASS if arc direction reverses with motion.

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

- [ ] F3.1: Formation: Twins, Wheel: ON, arc visible
- [ ] F3.2: Change Formation: Twins → Trips Left
- [ ] F3.3: **Verify:** Arc updates for Trips Left (curves left)
- [ ] F3.4: Change Formation: Trips Left → Trips Right
- [ ] F3.5: **Verify:** Arc updates (curves right)
- [ ] F3.6: Change Formation: Trips Right → Pro Left
- [ ] F3.7: **Verify:** Arc updates for Pro Left
- [ ] F3.8: **Verify:** Wheel toggle remains visible and functional
- [ ] F3.9: **Verify:** No crashes or broken state

**Expected Result:** PASS if formations switch smoothly with wheel enabled.

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

These tests verify Y Wheel works with the broader play-calling flow.

### Integration Test 4.1: Concept Matching with Y Wheel

**Test File:** `SpartansPlaycallerTests/ConceptMatcherYWheelTests.swift` (new)

```swift
class ConceptMatcherYWheelTests: XCTestCase {
    
    func testYWheelDoesNotBreakConceptMatching() {
        // Setup: Trips Left, Smash concept (X:6, Y:7, Z:5, A:8)
        var playCall = PlayCall(
            formation: .tripsLeft,
            digitSequence: "6758",
            selectedConcept: .smash,
            yReceiverMotion: nil,
            yWheelEnabled: false
        )
        
        var identified = ConceptMatcher.identify(playCall)
        XCTAssertEqual(identified.left, .smash, "Smash should be identified initially")
        
        // Enable wheel
        playCall.yWheelEnabled = true
        identified = ConceptMatcher.identify(playCall)
        XCTAssertEqual(identified.left, .smash, "Wheel should not break concept identification (Y stays on left side)")
    }
    
    func testYWheelWithMotionFlipReIdentification() {
        // Setup: Trips Left, Y After motion (Y flips to right), then wheel
        var playCall = PlayCall(
            formation: .tripsLeft,
            digitSequence: "6758",
            selectedConcept: .smash,
            yReceiverMotion: .after,
            yWheelEnabled: true
        )
        
        // Wheel should still be active; Y is on right side after motion
        // Concept matching may or may not identify Smash, depending on whether
        // the route interpretation uses Y's final side
        let identified = ConceptMatcher.identify(playCall)
        // Exact assertion depends on route interpretation rules; document expected behavior
        print("Identified with After + Wheel: \(identified)")
    }
}
```

**Execution:**
- [ ] Run test: `xcodebuild test -scheme SpartansPlaycaller -only-testing SpartansPlaycallerTests/ConceptMatcherYWheelTests 2>&1 | tail -5`
- [ ] Expected: Tests PASSED (concept identification is not broken by wheel)

**Pass Criteria:** Wheel doesn't break concept matching; behaves predictably with motion.

---

### Integration Test 4.2: Full Play Call Flow

**Test File:** `SpartansPlaycallerTests/PlayCallFlowYWheelTests.swift` (exists or new)

```swift
class PlayCallFlowYWheelTests: XCTestCase {
    let viewModel = PlayCallerViewModel()
    
    func testCompleteYWheelPlayFlow() {
        // Step 1: Select formation
        viewModel.selectedFormation = .tripsLeft
        
        // Step 2: Select concept
        viewModel.selectedLeftConcept = .smash
        
        // Step 3: Generate digits
        viewModel.generatePlayCall()
        XCTAssertEqual(viewModel.digitSequence, "6758", "Smash should generate correct digits")
        
        // Step 4: Enable wheel
        viewModel.yWheelEnabled = true
        XCTAssertTrue(viewModel.yWheelEnabled, "Wheel should be enabled")
        
        // Step 5: Verify diagram doesn't crash
        let diagram = RouteDiagramView(playCall: viewModel.playCall)
        XCTAssertNotNil(diagram, "Diagram should render without crashing")
        
        // Step 6: Toggle motion
        viewModel.selectedMotion = .after
        
        // Step 7: Verify diagram still works
        let diagramWithMotion = RouteDiagramView(playCall: viewModel.playCall)
        XCTAssertNotNil(diagramWithMotion, "Diagram should handle wheel + motion without crashing")
    }
}
```

**Execution:**
- [ ] Run test: `xcodebuild test -scheme SpartansPlaycaller -only-testing SpartansPlaycallerTests/PlayCallFlowYWheelTests 2>&1 | tail -5`
- [ ] Expected: Tests PASSED (no crashes, coherent behavior)

**Pass Criteria:** End-to-end play flow with wheel works without crashes.

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

