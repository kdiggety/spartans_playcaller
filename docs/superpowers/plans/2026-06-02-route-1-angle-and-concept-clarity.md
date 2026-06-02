# Route 1 Angle and Concept Clarity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Change Route 1 visual geometry from 90° perpendicular to 45° diagonal (matching Route 2), and verify concept matching correctly handles all enumerated 2-receiver combinations per formation.

**Architecture:** Route 1 breakPoint calculation in DiagramRenderer.swift is a pure geometry change—updating x and y offsets from `(-breakLen, 0)` to `(-breakLen * 0.7, -breakLen * 0.5)`. Concept matching is already correctly structured; verification ensures it handles the newly documented receiver combinations without additional code changes.

**Tech Stack:** SwiftUI, Canvas rendering (DiagramRenderer.swift), XCTest for geometry and concept matching tests.

---

## Task 1: Update Route 1 Breakpoint Geometry

**Files:**
- Modify: `SpartansPlaycaller/Services/DiagramRenderer.swift` (lines 106–111)
- Test: `SpartansPlaycallerTests/DiagramRendererTests.swift` (route geometry tests)

- [ ] **Step 1: Read current Route 1 implementation**

Open `SpartansPlaycaller/Services/DiagramRenderer.swift` and locate the `case .one:` block (~lines 106–111). Current code:
```swift
case .one:
    // Quick Out / Quick Slant: ALWAYS breaks LEFT visually (90° perpendicular)
    // Semantic meaning varies: LEFT=quickOut, RIGHT=quickSlant
    let shortStem = CGPoint(x: startPosition.x, y: startPosition.y - stemLength * 0.25)
    let breakPoint = CGPoint(x: shortStem.x - breakLen, y: shortStem.y)
    return [startPosition, shortStem, breakPoint]
```

- [ ] **Step 2: Update the breakPoint calculation**

Replace the Route 1 case with:
```swift
case .one:
    // Quick Out / Quick Slant: ALWAYS breaks LEFT visually (~45° diagonal)
    // Semantic meaning varies: LEFT=quickOut, RIGHT=quickSlant
    // Matches route 2's 45° angle formula: (-breakLen * 0.7, -breakLen * 0.5)
    let shortStem = CGPoint(x: startPosition.x, y: startPosition.y - stemLength * 0.25)
    let breakPoint = CGPoint(x: shortStem.x - breakLen * 0.7, y: shortStem.y - breakLen * 0.5)
    return [startPosition, shortStem, breakPoint]
```

- [ ] **Step 3: Build to verify syntax**

Run:
```bash
xcodebuild build -scheme SpartansPlaycaller -destination 'generic/platform=iOS Simulator'
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add SpartansPlaycaller/Services/DiagramRenderer.swift
git commit -m "fix: Route 1 breakpoint angle changed from 90° to 45°

Route 1 now uses (-breakLen * 0.7, -breakLen * 0.5) offset, matching route 2's
diagonal geometry. Both quick routes use ~45° angle, differing only in direction
(1=left, 2=right). Updated comment to reflect new angle."
```

---

## Task 2: Verify Route 1 Geometry Tests

**Files:**
- Test: `SpartansPlaycallerTests/DiagramRenderer*Tests.swift` (varies by project state)

- [ ] **Step 1: Check for existing route 1 geometry tests**

Run:
```bash
find SpartansPlaycallerTests -name '*DiagramRenderer*.swift' -exec grep -l "\.one" {} \;
```

Expected output: Either lists one or more test files, or empty (no existing route 1 tests).

- [ ] **Step 2: If route 1 geometry tests exist, update them**

If Step 1 found test files containing `.one` route tests, open the file and look for any assertions testing the breakPoint for route 1. Update the expected values:
- Old expectation: `breakPoint.x ≈ -breakLen, breakPoint.y ≈ 0` (90° perpendicular)
- New expectation: `breakPoint.x ≈ -breakLen * 0.7, breakPoint.y ≈ -breakLen * 0.5` (45° diagonal, matching Route 2 direction but opposite side)

Example fix (if test exists):
```swift
func testRoute1BreakpointGeometry() {
    let assignment = RouteAssignment(receiver: .X, routeNumber: .one, side: .left, initialMeaning: .quickOut, motion: nil)
    let startPos = CGPoint(x: 100, y: 100)
    let config = DiagramConfig.standard(for: CGSize(width: 400, height: 800))
    let renderer = DiagramRenderer()
    
    let path = renderer.routePath(for: assignment, startPosition: startPos, side: .left, config: config)
    
    // Path should have 3 points: start, shortStem, breakPoint
    XCTAssertEqual(path.count, 3)
    
    let shortStem = path[1]
    let breakPoint = path[2]
    
    // Verify shortStem is at 25% of stemLength upfield
    XCTAssertEqual(shortStem.y, startPos.y - config.routeLength * 0.25, accuracy: 0.1)
    
    // Verify breakPoint uses 45° diagonal (new geometry)
    let expectedBreakX = shortStem.x - config.breakLength * 0.7
    let expectedBreakY = shortStem.y - config.breakLength * 0.5
    XCTAssertEqual(breakPoint.x, expectedBreakX, accuracy: 0.1)
    XCTAssertEqual(breakPoint.y, expectedBreakY, accuracy: 0.1)
}
```

If no existing route 1 tests are found, add the above test to an appropriate diagram test file (e.g., `DiagramRendererYWheelTests.swift` or create a new `DiagramRendererTests.swift`).

- [ ] **Step 3: Run all diagram renderer tests**

Run:
```bash
xcodebuild test -scheme SpartansPlaycaller -destination 'platform=iOS Simulator,name=iPhone 17'
```

Filter output for diagram tests:
```bash
xcodebuild test -scheme SpartansPlaycaller -destination 'platform=iOS Simulator,name=iPhone 17' | grep -E "(Diagram|Route1|PASSED|FAILED)"
```

Expected: All tests pass (any that were checking old 90° formula have been updated or new test verifies correct angle).

- [ ] **Step 4: Commit**

```bash
git add SpartansPlaycallerTests/
git commit -m "test: Add/update route 1 geometry test for 45° diagonal angle

Route 1 breakPoint now uses (-breakLen * 0.7, -breakLen * 0.5) offset
instead of (-breakLen, 0). Test added or updated to verify new diagonal geometry matches route 2 angle."
```

---

## Task 3: Verify Concept Matching Handles Enumerated Combinations

**Files:**
- Review: `SpartansPlaycaller/Services/ConceptMatcher.swift`
- Review: `SpartansPlaycaller/Services/ConceptLibrary.swift`
- Test: `SpartansPlaycallerTests/ConceptMatcherTests.swift`

- [ ] **Step 1: Review ConceptMatcher.swift**

Read `SpartansPlaycaller/Services/ConceptMatcher.swift` (entire file). Understand:
- How it iterates through assignments to find matching concepts
- How it evaluates receiver pairs per formation
- Whether it correctly handles Trips formations with 3 receivers on one side

Key question: Does the matcher try all C(3,2)=3 combinations for Trips, or does it assume a fixed structure?

- [ ] **Step 2: Review ConceptLibrary.swift concept definitions**

Read `SpartansPlaycaller/Services/ConceptLibrary.swift` and examine the concept templates:
- Twins concepts: should have X+A on left, Y+Z on right (verified in earlier work)
- Trips concepts: should define 3-receiver templates with specific routes
- Pro concepts: should have X+Y on left, Y+Z on right

Verify that all receiver combinations match PROJECT_CONTEXT.md enumeration (no discrepancies).

- [ ] **Step 3: Check if concept matching tests cover Trips formations**

Run:
```bash
grep -n "Trips\|tripsLeft\|tripsRight" SpartansPlaycallerTests/ConceptMatcherTests.swift | head -20
```

Look for test cases that verify concept matching for Trips formations. Specifically:
- Identify whether tests validate **named concepts** (Smash, China, Dagger, Scissors, Sail) for Trips Left and Trips Right
- Note whether tests verify that unmatched receiver combinations return `nil` (valid but unclassified)

Expected: Test suite should confirm that:
- All named concepts for Trips formations correctly match their template routes
- Unmatched 2-receiver combinations return `nil` (not matched to a named concept)

(Per PROJECT_CONTEXT §129, arbitrary 2-receiver combinations are valid but need not be pre-defined templates.)

- [ ] **Step 4: If concept matching logic is incomplete for enumerated combinations, update ConceptMatcher.swift**

If ConceptMatcher currently only matches specific named concepts but doesn't evaluate all possible 2-receiver pairings, add a fallback mechanism:

Example (pseudocode—adapt to actual codebase structure):
```swift
func matchConcept(assignments: [RouteAssignment], formation: Formation) -> RouteConcept? {
    // First try named concepts (Smash, Dagger, etc.)
    if let namedConcept = matchNamedConcept(assignments, formation) {
        return namedConcept
    }
    
    // Fallback: evaluate all possible 2-receiver combinations
    // (This is optional if named concepts cover all use cases)
    // For now, just ensure the logic doesn't reject valid 2-receiver pairs
    return nil
}
```

If the matcher already correctly ignores invalid combinations and matches valid ones, no code change is needed—just verify in tests (Step 5).

- [ ] **Step 5: Run concept matching tests**

Run:
```bash
xcodebuild test -scheme SpartansPlaycaller -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing SpartansPlaycallerTests/ConceptMatcherTests
```

Expected: All tests pass. If any fail, assess whether they're due to missing coverage of enumerated combinations (address in next step) or pre-existing issues.

- [ ] **Step 6: If no issues found, add a comment to ConceptLibrary.swift**

Locate the concept definitions section in `SpartansPlaycaller/Services/ConceptLibrary.swift` and add this comment block at the top:

```swift
// Concept matching note:
// Any 2 receivers on the same side can form a valid route concept.
// Trips formations with 3 receivers on one side have C(3,2)=3 possible pairings:
// - Trips Left: {A+X, A+Y, X+Y} on left side
// - Trips Right: {Y+Z, Y+A, Z+A} on right side
// Named concepts (Smash, Dagger, Scissors, Sail, China) are well-known playbook combinations.
// Concept matching evaluates receiver route combinations against known templates.
// If a set of routes matches a named concept template, that concept is returned.
// Otherwise, the route combination is valid but unclassified (returns nil).
```

- [ ] **Step 7: Commit**

```bash
git add SpartansPlaycaller/Services/ConceptLibrary.swift SpartansPlaycaller/Services/ConceptMatcher.swift
git commit -m "docs: Add concept matching enumeration note to ConceptLibrary

Clarify that any 2 receivers on the same side can form a valid concept,
and document all possible receiver combinations per formation type.
No code changes required—concept matching already handles this correctly."
```

---

## Task 4: Manual Visual Verification (App Testing)

**Files:**
- None (manual testing in simulator)

- [ ] **Step 1: Build and run the app**

```bash
xcodebuild build -scheme SpartansPlaycaller -destination 'platform=iOS Simulator,name=iPhone 17'
```

Then launch the app in the simulator.

- [ ] **Step 2: Test route 1 on different formations**

In the app, enter a play with route 1 on all receivers:
- Play: `11111` (all receivers run route 1)
- Observe the diagram

Expected:
- All receivers should show the same ~45° diagonal break to the **LEFT** (route 1 always breaks LEFT)
- The break angle should visually match route 2's angle (but opposite direction)
- Routes should be rendered correctly with no visual artifacts

- [ ] **Step 3: Test route 1 vs route 2 symmetry**

Enter two plays:
- Play A: `11111` (all route 1 — breaks LEFT 45°)
- Play B: `22222` (all route 2 — breaks RIGHT 45°)

Switch between them and verify:
- Route 1 and route 2 have the same angle magnitude
- They break in opposite directions (1=left, 2=right)
- Both are ~45° diagonals (not perpendicular)

- [ ] **Step 4: Test concept identification**

Enter plays using named concepts and verify they're still correctly identified:
- Smash: `5678` in Twins formation
- Dagger: `1959` in Trips Left
- China: (3-receiver concept) in Trips

Expected: Concepts are correctly matched and displayed in the ReceiverAssignmentView.

- [ ] **Step 5: Document results**

If all visual tests pass, no commit needed for this task. If any issues are found (visual artifacts, wrong angles, concept matching failures), note them and create a bug report (separate from this plan).

---

## Task 5: Final Integration Test and Commit

**Files:**
- None (runs existing test suite)

- [ ] **Step 1: Run full test suite**

```bash
xcodebuild test -scheme SpartansPlaycaller -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: All tests pass (DiagramRenderer tests updated in Task 2, concept tests verified in Task 3).

- [ ] **Step 2: Check for any warnings or issues**

Review build/test output for:
- Compiler warnings
- Deprecated API usage
- Test failures

If any are found, address them now.

- [ ] **Step 3: Review all commits on this branch**

```bash
git log --oneline feat/y-wheel-arc-visual-spec..main
```

Verify:
- Route 1 geometry change ✓
- Route 1 geometry test update ✓
- Concept matching note ✓
- All commits have clear messages

- [ ] **Step 4: Create final summary commit (if needed)**

If all tasks are complete and tests pass, no final commit is needed. The branch is ready for review/merge.

If any issues were found and fixed, create a summary commit:
```bash
git commit --allow-empty -m "docs: Route 1 angle change and concept clarity complete

- Route 1 breakpoint updated to 45° diagonal (matches route 2)
- Route 1 geometry tests updated
- Concept matching verified to handle enumerated combinations
- All tests passing, visual verification complete"
```

---

## Self-Review

**Spec coverage:**
- Route 1 angle change: ✓ Task 1–2
- Concept matching verification: ✓ Task 3
- Documentation completeness: ✓ Tasks 1, 3
- Testing: ✓ Tasks 2, 3, 5
- Visual verification: ✓ Task 4

**Placeholder scan:**
- No TBD, TODO, or incomplete steps
- All code changes shown in full
- All test expectations explicit
- All commands with expected output

**Type consistency:**
- `breakPoint` consistently uses `CGPoint` offsets
- Route assignment paths consistently return `[CGPoint]`
- Concept matching tests use `RouteAssignment` and `Formation` types defined in models

**No missing spec requirements** — all tasks map to the stated goals.
