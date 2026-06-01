# Y Wheel Automated Test Suite — Execution Mapping

**Date:** 2026-05-31  
**Status:** Test suite created (pre-implementation)  
**Test Coverage:** Comprehensive automated tests covering all scenarios A–H and edge cases

---

## Overview

This document maps the automated test suite to the Y Wheel test plan scenarios defined in `docs/Y_WHEEL_TEST_PLAN.md`. All tests are implemented and ready for execution once the Y Wheel feature is implemented.

## Test Files

| File | Purpose | Tests |
|------|---------|-------|
| `Y_WheelComprehensiveTests.swift` | Unit tests for geometry, state management, and all 8 scenarios | 45+ tests |
| `Y_WheelDiagramIntegrationTests.swift` | Integration tests for diagram rendering and formation/motion interactions | 25+ tests |
| `Y_WheelRobustnessTests.swift` | Edge case, robustness, and stress tests | 30+ tests |

**Total Automated Tests:** 100+ test cases

---

## Test Plan Scenario Mapping

### Pre-Implementation Checks (Part 1)

| Check | Mapped to Tests |
|-------|-----------------|
| Check 0: General Principles | Verified in test setup; all formations follow principles |
| Check 1: Formation Definitions | `testAllFormationsSupportWheel()` |
| Check 2: Formation Motion Support | `testMotionSupportedForAllFormations()` |
| Check 3: Y Wheel Toggle Support | `testYWheelToggleCanBeEnabled()`, `testYWheelToggleCanBeDisabled()` |
| Check 4: Concept Matching | Test plan notes wheel doesn't affect matching; no override logic needed |

---

## Scenario A–H Coverage

### Scenario A: Twins, Y Motion NONE

| Test | File | Maps to |
|------|------|---------|
| `testScenarioA_TwinsNoMotion()` | Y_WheelComprehensiveTests | A1–A8 (Twins base formation) |
| `testArcCurvesRightOnRightSide()` | Y_WheelComprehensiveTests | A12 (Arc curves right) |
| `testWheelArcRendersInTwins()` | Y_WheelDiagramIntegrationTests | A3, A9–A10 (Diagram rendering) |

**Test Plan Steps Covered:**
- ✅ A1: Select Formation → Twins
- ✅ A2–A8: Wheel toggle and arc visibility
- ✅ A9–A14: Arc verification and route override

---

### Scenario B: Twins, Y Motion AFTER/GO

| Test | File | Maps to |
|------|------|---------|
| `testScenarioB_TwinsAfterMotion()` | Y_WheelComprehensiveTests | B (2x2 → 3x1 transformation) |
| `testTwinsWithAfterMotionAndWheel()` | Y_WheelComprehensiveTests | C1 (Twins + After motion) |
| `testTwinsMotionArcUpdates()` | Y_WheelDiagramIntegrationTests | C1.3–C1.8 (Arc relocation & direction reversal) |

**Test Plan Steps Covered:**
- ✅ C1.1: Twins, Motion None, Wheel ON → Arc right
- ✅ C1.3: Change Motion → After
- ✅ C1.4–C1.7: Arc relocates, direction reverses, formation transforms

---

### Scenario C: Trips Left, Y Motion NONE

| Test | File | Maps to |
|------|------|---------|
| `testScenarioC_TripsLeftNoMotion()` | Y_WheelComprehensiveTests | A2 (Trips Left base) |
| `testArcCurvesLeftOnLeftSide()` | Y_WheelComprehensiveTests | A12 (Arc curves left) |
| `testWheelArcRendersInTripsLeft()` | Y_WheelDiagramIntegrationTests | A2.3–A2.12 |

**Test Plan Steps Covered:**
- ✅ A2.1: Select Formation → Trips Left
- ✅ A2.8–A2.12: Arc curves left, formation remains 3x1

---

### Scenario D: Trips Left, Y Motion AFTER

| Test | File | Maps to |
|------|------|---------|
| `testScenarioD_TripsLeftAfterMotion()` | Y_WheelComprehensiveTests | D (3x1 → 2x2 transformation) |
| `testTripsLeftWithAfterMotionAndWheel()` | Y_WheelComprehensiveTests | C3 (Trips Left + After) |
| `testTripsLeftMotionArcUpdates()` | Y_WheelDiagramIntegrationTests | C3.3–C3.7 (Arc relocation & direction) |

**Test Plan Steps Covered:**
- ✅ C3.1: Trips Left, Wheel ON, Motion None → Arc left
- ✅ C3.3: Change Motion → After
- ✅ C3.4–C3.7: Arc relocates to right, direction reverses, formation transforms

---

### Scenario E: Pro Left, Y Motion NONE

| Test | File | Maps to |
|------|------|---------|
| `testScenarioE_ProLeftNoMotion()` | Y_WheelComprehensiveTests | A4 (Pro Left base) |
| `testArcOnProLeftFormation()` | Y_WheelComprehensiveTests | A4.6 (Arc curves left) |
| `testWheelArcRendersInProLeft()` | Y_WheelDiagramIntegrationTests | A4.1–A4.7 |

**Test Plan Steps Covered:**
- ✅ A4.1: Select Formation → Pro Left
- ✅ A4.5: Set Motion → None, Wheel → ON
- ✅ A4.6–A4.7: Arc appears on left, formation is 2x1

---

### Scenario F: Pro Left, Y Motion AFTER

| Test | File | Maps to |
|------|------|---------|
| `testScenarioF_ProLeftAfterMotion()` | Y_WheelComprehensiveTests | F (2x1 → 1x2 transformation) |
| `testProFormationsWithMotionAndWheel()` | Y_WheelComprehensiveTests | F (Pro + After/Go) |

**Test Plan Steps Covered:**
- ✅ C5.1: Pro Left, Wheel ON, Motion None → Arc left
- ✅ C5.3: Change Motion → After
- ✅ C5.4–C5.7: Arc relocates to right, direction reverses, 2-receiver side flips

---

### Scenario G: Pro Right, Y Motion NONE

| Test | File | Maps to |
|------|------|---------|
| `testScenarioG_ProRightNoMotion()` | Y_WheelComprehensiveTests | A5 (Pro Right base) |
| `testArcOnProRightFormation()` | Y_WheelComprehensiveTests | A5.6 (Arc curves right) |
| `testWheelArcRendersInProRight()` | Y_WheelDiagramIntegrationTests | A5.1–A5.7 |

**Test Plan Steps Covered:**
- ✅ A5.1: Select Formation → Pro Right
- ✅ A5.5: Set Motion → None, Wheel → ON
- ✅ A5.6–A5.7: Arc appears on right, formation is 1x2

---

### Scenario H: Pro Right, Y Motion AFTER

| Test | File | Maps to |
|------|------|---------|
| `testScenarioH_ProRightAfterMotion()` | Y_WheelComprehensiveTests | H (1x2 → 2x1 transformation) |
| `testProFormationsWithMotionAndWheel()` | Y_WheelComprehensiveTests | H (Pro + After/Go) |

**Test Plan Steps Covered:**
- ✅ C6.1: Pro Right, Wheel ON, Motion None → Arc right
- ✅ C6.3: Change Motion → After
- ✅ C6.4–C6.7: Arc relocates to left, direction reverses, 2-receiver side flips

---

## Unit Test Coverage (Part 2)

### Unit Test 2.1: Formation Gating

| Test | File |
|------|------|
| `testAllFormationsSupportWheel()` | Y_WheelComprehensiveTests |
| `testMotionSupportedForAllFormations()` | Y_WheelComprehensiveTests |

**Coverage:**
- ✅ All formations allow wheel (Twins, Trips Left/Right, Pro Left/Right)
- ✅ Motion support unchanged

---

### Unit Test 2.2: ReceiverMotion Wheel Semantics

| Test | File |
|------|------|
| `testYWheelWithStopMotion()` | Y_WheelComprehensiveTests |
| `testYWheelWithAfterMotion()` | Y_WheelComprehensiveTests |
| `testYWheelWithGoMotion()` | Y_WheelComprehensiveTests |
| `testYWheelWithoutMotion()` | Y_WheelComprehensiveTests |

**Coverage:**
- ✅ Wheel works with Stop motion
- ✅ Wheel works with After motion
- ✅ Wheel works with Go motion
- ✅ Wheel works independently of motion

---

### Unit Test 2.3: Arc Geometry

| Test | File |
|------|------|
| `testArcStartsAtYPosition()` | Y_WheelComprehensiveTests |
| `testArcCurvesLeftOnLeftSide()` | Y_WheelComprehensiveTests |
| `testArcCurvesRightOnRightSide()` | Y_WheelComprehensiveTests |
| `testArcHasProperDepth()` | Y_WheelComprehensiveTests |
| `testArcEndpointDifferentXThanStart()` | Y_WheelComprehensiveTests |
| `testArcIsSmoothCurve()` | Y_WheelComprehensiveTests |
| `testArcReturnsTowardLOS()` | Y_WheelComprehensiveTests |
| `testArcColorIsYellow()` | Y_WheelComprehensiveTests |

**Coverage:**
- ✅ Arc starts at Y position
- ✅ Arc curves correct direction (left/right)
- ✅ Arc has reasonable depth
- ✅ Arc endpoint different X than start (tilted)
- ✅ Arc is smooth (no sharp corners)
- ✅ Arc returns toward LOS
- ✅ Arc color is yellow

---

## Integration Test Coverage (Part 4)

### Integration Test 4.1: Concept Matching with Transformed Formations

**Note:** Concept matching is NOT tested here; the test plan notes that wheel doesn't affect matching and matching uses transformed formation type. This is handled by existing concept matcher tests.

---

### Integration Test 4.2: Formation Transformation and Visual Updates

| Test | File |
|------|------|
| `testWheelArcRendersInTwins()` | Y_WheelDiagramIntegrationTests |
| `testWheelArcRendersInTripsLeft()` | Y_WheelDiagramIntegrationTests |
| `testWheelArcRendersInTripsRight()` | Y_WheelDiagramIntegrationTests |
| `testWheelArcRendersInProLeft()` | Y_WheelDiagramIntegrationTests |
| `testWheelArcRendersInProRight()` | Y_WheelDiagramIntegrationTests |
| `testTwinsMotionArcUpdates()` | Y_WheelDiagramIntegrationTests |
| `testTripsLeftMotionArcUpdates()` | Y_WheelDiagramIntegrationTests |

**Coverage:**
- ✅ Arc renders in all formations
- ✅ Arc updates when motion changes
- ✅ No crashes during transformations

---

## Edge Case & Robustness Testing (Part 5, 6)

### Test Group F: Edge Cases and Robustness

| Test Plan | Mapped to Tests |
|-----------|-----------------|
| F1: Toggle ON/OFF multiple times | `testRapidWheelToggle()` |
| F2: Switch motion while wheel ON | `testMotionChangeWhileWheelEnabled()`, `testAllMotionTypesWithWheel()` |
| F3: Switch formations while wheel ON | `testRapidFormationSwitchingWithWheel()` |
| F4: Rotate device | Implicitly covered by screen size tests |
| F5: Toggle wheel during transformation | `testWheelToggleDuringComplexFlow()` |
| F6: Switch between all formations | `testRapidFormationSwitchingWithWheel()`, `testFormationSwitchWithWheelAndMotion()` |

**Coverage:**
- ✅ Rapid wheel toggle (10x)
- ✅ Motion changes with wheel enabled
- ✅ Formation switching with wheel enabled
- ✅ Formation switching with wheel + motion enabled
- ✅ Complex multi-step operations

---

### Test Group E: Visual Quality and Rendering

| Test Plan | Mapped to Tests |
|-----------|-----------------|
| E1: Arc smoothness | `testArcIsSmoothCurve()`, `testArcSmoothnessAcrossAllFormations()` |
| E2: Arc smoothness at zoom | `testArcHasSufficientPointsForSmoothness()`, `testArcSegmentsAreSmall()` |
| E3: Arc color | `testArcColorIsYellow()` |
| E4: Arc no clipping at edges | `testArcDoesNotClipOnSmallScreen()`, `testArcDoesNotClipOnLargeScreen()`, `testNoClippingAcrossScreenSizes()` |
| E5: Arrow visibility | Not tested (arrow is drawn in `drawArrow()` method; verified via E2E testing) |

**Coverage:**
- ✅ Arc is smooth (50+ points at 0.02 stride)
- ✅ Consecutive segments are small (<10px)
- ✅ Arc color is yellow
- ✅ Arc doesn't clip on iPhone SE, iPhone 15 Pro, or iPad

---

## Screen Size Coverage Matrix (Part 6)

| Device | Screen Size | Mapped to Tests |
|--------|------------|-----------------|
| iPhone SE | 4.7" (320×568) | `testArcRendersOnSmallScreen()`, `testArcDoesNotClipOnSmallScreen()` |
| iPhone 15 Pro | 6.7" (393×852) | `testArcRendersOnStandardScreen()` |
| iPad | 12.9" (1024×1366) | `testArcRendersOnLargeScreen()`, `testArcDoesNotClipOnLargeScreen()` |

**Coverage:**
- ✅ Arc renders on all screen sizes
- ✅ No clipping on any screen size
- ✅ Arc proportions are correct

---

## Test Execution Checklist

### Pre-Implementation (Before Implementation Starts)

- [ ] Review test files and verify all test scenarios are covered
- [ ] Verify test files compile without errors
- [ ] Confirm RouteAssignment has `motion` property
- [ ] Confirm PlayCall has `yWheelEnabled` property
- [ ] Confirm ReceiverMotion enum supports `.wheel` case
- [ ] Confirm DiagramRenderer has `yWheelArcPath()` method

### Post-Implementation (After Feature Code is Written)

- [ ] Run Y_WheelComprehensiveTests: `xcodebuild test -only-testing "SpartansPlaycallerTests/Y_WheelComprehensiveTests"`
- [ ] Run Y_WheelDiagramIntegrationTests: `xcodebuild test -only-testing "SpartansPlaycallerTests/Y_WheelDiagramIntegrationTests"`
- [ ] Run Y_WheelRobustnessTests: `xcodebuild test -only-testing "SpartansPlaycallerTests/Y_WheelRobustnessTests"`
- [ ] Confirm all tests PASS (0 failures)
- [ ] Document results in `docs/test-plans/Y_WHEEL_TEST_RESULTS.md`

### Manual Testing (On Device)

- [ ] Test A1–A5: Base formations (Twins, Trips Left/Right, Pro Left/Right) with Wheel ON
- [ ] Test C1–C6: Motion transformations with Wheel ON
- [ ] Test E1–E5: Visual quality (smoothness, color, clipping)
- [ ] Test F1–F6: Edge cases (rapid toggle, motion changes, formation switching)
- [ ] Device coverage: iPhone SE, iPhone 15 Pro, iPad

---

## Test Execution Log

To be completed by testing agent after implementation.

| Test Suite | Status | Pass Count | Fail Count | Notes |
|------------|--------|-----------|-----------|-------|
| Y_WheelComprehensiveTests | TBD | — | — | 45+ unit tests |
| Y_WheelDiagramIntegrationTests | TBD | — | — | 25+ integration tests |
| Y_WheelRobustnessTests | TBD | — | — | 30+ edge case tests |

---

## Summary

**Total Automated Tests Implemented:** 100+

**Coverage Areas:**
- ✅ All 8 scenarios (A–H) from test plan
- ✅ Formation gating (5 formations)
- ✅ Motion interaction (None, Stop, After, Go)
- ✅ Arc geometry (start, direction, depth, smoothness, endpoint, color)
- ✅ Wheel toggle state management (on/off, preservation)
- ✅ Formation switching (all 10 transitions)
- ✅ Edge cases (rapid toggles, complex flows, extreme screen sizes)
- ✅ Screen size coverage (iPhone SE to iPad)
- ✅ Visual quality (smoothness, no clipping, consistent rendering)
- ✅ Robustness (stress tests, consistency, determinism)

**Known Limitations:**

- Manual UI tests (A1–A5, B1–B5, C1–C6, D1–D2, E1–E5, F1–F6) require a real device and are documented in the test plan but not automated in this suite
- Arrow rendering verification is implicitly covered by `drawArrow()` testing in E2E/manual tests
- Device orientation rotation (F4) is implicitly covered by different screen sizes but not explicitly tested

**Next Steps:**

1. Implement Y Wheel feature in codebase
2. Run automated test suite
3. Fix any failing tests (likely pre-implementation expected failures)
4. Execute manual UI tests on physical device
5. Document results and complete test execution log

---

## Revision History

| Date | Change | Status |
|------|--------|--------|
| 2026-05-31 | Test suite created (100+ automated tests) | Ready for implementation |

