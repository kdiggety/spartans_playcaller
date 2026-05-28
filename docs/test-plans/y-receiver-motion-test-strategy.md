# Y Receiver Motion Visualization — Test Strategy

**Feature:** Y receiver motion in football play diagrams. Coaches can motion Y pre-snap, and the diagram displays:
- Dashed line from Y's initial position to final position
- Solid route line from Y's final position
- Other receivers' routes as usual (solid lines, no motion)

**Motion Types:** Y Stop, Y After, Y Go

**Rendering Spec:**
- Motion lines: dashed yellow, 0.5 opacity, 1.5pt width, [6,4] dash pattern
- Route lines: solid yellow, 2.5pt width (existing)
- Z-order: motion lines drawn BEFORE routes (sit underneath)
- Labeling: Y labeled only at initial position (no motion type label on diagram)

**Document Owner:** SDET  
**Last Updated:** 2026-05-27

---

## Test Pyramid Strategy

### Scope by Layer

| Layer | Purpose | Coverage | Risk Caught |
|-------|---------|----------|-------------|
| **Unit (Models)** | Data structure correctness; motion type enum; RouteAssignment with motion fields | MotionType enum, RouteAssignment init with optional motion, PlayCall w/ motion | Null pointer crashes, invalid motion types, missing position field |
| **Unit (Geometry)** | Motion line endpoint calculations; final position resolution; compatibility with existing route path math | DiagramRenderer.motionLinePath(for:, startPos:, finalPos:, config:); edge cases (no motion, same position, invalid receiver) | Wrong endpoint calculation, math errors, coordinate system confusion |
| **Integration (Rendering)** | Canvas rendering of motion lines with correct color, opacity, width, dash pattern; motion lines before routes; label placement | RouteDiagramView renders motion lines in correct order with correct styling; no overlap artifacts | Dash pattern not visible, color wrong, opacity incorrect, Z-order violation, label duplication |
| **E2E (Diagram + UI)** | Coach selects Y motion type → PlayCall created → diagram updates → visual correctness verified | Select motion type from UI → PlayCall with motion → diagram renders correctly | UX flow broken, UI not wired to data model, diagram not refreshing, incorrect motion applied to wrong receiver |
| **Visual Regression (Snapshots)** | Capture baseline images for each motion type × formation × device orientation; detect unintended rendering drift | Y Stop, Y After, Y Go × (Twins, Trips Left, Trips Right) × (portrait, landscape, iPhone SE, iPhone Pro) | Visual regression, dash pattern rendering on different devices, opacity/color drift |

**Pyramid breakdown:**
- **Unit tests (50%):** Data model correctness, geometry calculations, null/edge case handling.
- **Integration tests (30%):** Canvas rendering, correct color/opacity/width/dash, Z-order, label placement.
- **E2E/visual tests (20%):** Full user flow, device-specific visual verification, baseline snapshots.

---

## Unit Test Scope

### 1. Data Model Tests (RouteAssignment, PlayCall)

**File:** `SpartansPlaycallerTests/Models/RouteAssignmentTests.swift`

#### 1.1 MotionType Enum
```swift
enum MotionType: String, Codable, CaseIterable {
    case yStop = "Y Stop"
    case yAfter = "Y After"
    case yGo = "Y Go"
}
```

**Tests:**
- [ ] `test_MotionType_allCasesValid` — Verify all three cases exist (yStop, yAfter, yGo)
- [ ] `test_MotionType_rawValueMapping` — Verify raw string values map correctly
- [ ] `test_MotionType_codable` — Verify enum encodes/decodes from JSON correctly

#### 1.2 RouteAssignment Extension
```swift
struct RouteAssignment: Identifiable {
    let id = UUID()
    let receiver: Receiver
    let routeNumber: RouteNumber
    let side: FieldSide
    let meaning: RouteMeaning
    
    // NEW:
    let motionType: MotionType?
    let finalPosition: Receiver?  // Receiver whose position Y motions to (e.g., .Z, .A)
}
```

**Tests:**
- [ ] `test_RouteAssignment_withoutMotion` — Create assignment with motionType=nil, finalPosition=nil; verify no crash, label unchanged
- [ ] `test_RouteAssignment_withMotion_yStop` — Create Y assignment with motionType=.yStop, finalPosition=.Z; verify stored correctly
- [ ] `test_RouteAssignment_withMotion_yAfter` — Create Y assignment with motionType=.yAfter, finalPosition=.A; verify stored correctly
- [ ] `test_RouteAssignment_withMotion_yGo` — Create Y assignment with motionType=.yGo, finalPosition=.A; verify stored correctly
- [ ] `test_RouteAssignment_motionOnNonYReceiver` — Attempt motion on X receiver; verify motionType is ignored or rejected per design decision
- [ ] `test_RouteAssignment_finalPositionNil_motionTypeNotNil` — Set motionType=.yStop but finalPosition=nil; verify defensive handling (edge case to guard against)

#### 1.3 PlayCall Integration
**Tests:**
- [ ] `test_PlayCall_withMotion_displayName` — Create PlayCall with Y motion; verify displayName is correct and doesn't leak motion type (e.g., "Twins 6794", not "Twins 6794 (Y Stop)")
- [ ] `test_PlayCall_multipleMotions_ifApplicable` — [TBD: confirm if only one Y can motion] If multiple motions allowed, verify PlayCall stores all correctly

---

### 2. Geometry Calculation Tests (DiagramRenderer Motion Endpoints)

**File:** `SpartansPlaycallerTests/Services/DiagramRendererMotionTests.swift`

#### 2.1 Motion Line Endpoint Calculation

Add method to DiagramRenderer:
```swift
func motionLinePath(
    for assignment: RouteAssignment,
    from startPosition: CGPoint,
    to finalPosition: CGPoint,
    config: DiagramConfig
) -> [CGPoint]
```

**Tests:**
- [ ] `test_motionLinePath_yStop_tripleLeft` — Y starts at Trips Left position, motions to X position (tight to tackle); verify endpoint matches X's start position
- [ ] `test_motionLinePath_yAfter_tripsLeft` — Y starts at Trips Left position, motions to opposite side (e.g., Z position); verify endpoint calculation correct
- [ ] `test_motionLinePath_yGo_tripsRight` — Y starts at Trips Right position, motions away without setting; verify end position is calculated correctly (e.g., one spacing unit in motion direction)
- [ ] `test_motionLinePath_sameStartEnd` — Y starts and ends at same position; verify path returns [startPos] or [startPos, startPos] (defensive test—shouldn't happen but guard against it)
- [ ] `test_motionLinePath_nilFinalPosition` — finalPosition is nil; verify method returns empty path or start position only, no crash
- [ ] `test_motionLinePath_receiverNotInFormation` — finalPosition receiver doesn't exist in formation (e.g., H in Twins with no H); verify defensive handling

#### 2.2 Existing Route Path Unaffected

**Tests:**
- [ ] `test_routePath_existingBehavior_X` — X route (no motion) renders as before, endpoint unchanged
- [ ] `test_routePath_existingBehavior_Z` — Z route (no motion) renders as before, endpoint unchanged
- [ ] `test_routePath_existingBehavior_YWithoutMotion` — Y route without motion (motionType=nil) renders as before

---

### 3. Edge Case & Validation Tests

**File:** `SpartansPlaycallerTests/EdgeCases/MotionEdgeCasesTests.swift`

**Tests:**
- [ ] `test_Y_motionDisabled_inTwins` — [TBD: confirm if Twins supports motion] If Twins doesn't support Y motion, verify motionType is forced to nil or UI prevents selection
- [ ] `test_Y_motionDisabled_inTripsLeft` — [TBD] If any formation disallows motion, test that motionType is rejected
- [ ] `test_motionToInvalidReceiver` — Attempt Y motion to H (if H not on field); verify rejected or handled gracefully
- [ ] `test_routeDigits_unchanged_afterMotion` — Y motion should not change the raw route digit; verify routeDigits string is unchanged
- [ ] `test_side_awareness_unchanged_afterMotion` — Y side (left/right in formation) should not change; verify side field is unchanged

---

## Integration Test Scope

### 1. Canvas Rendering Tests (RouteDiagramView + DiagramRenderer Motion)

**File:** `SpartansPlaycallerTests/Views/RouteDiagramViewMotionTests.swift`

#### 1.1 Motion Line Rendering: Style & Color

**Setup:**
```swift
let config = DiagramConfig.standard(for: CGSize(width: 350, height: 600))
let positions = renderer.receiverPositions(formation: .tripsLeft, config: config)
let yAssignment = RouteAssignment(
    receiver: .Y,
    routeNumber: .six,
    side: .left,
    meaning: RouteMeaning.curl,
    motionType: .yStop,
    finalPosition: .X
)
```

**Tests:**
- [ ] `test_motionLine_color_yellow` — Motion line drawn in yellow (Color.yellow or correct hex); verify via GraphicsContext color inspection or snapshot
- [ ] `test_motionLine_opacity_half` — Motion line opacity is 0.5 (not opaque, not transparent); verify via color.opacity(0.5)
- [ ] `test_motionLine_width_correct` — Motion line width is 1.5pt; verify via StrokeStyle(lineWidth: 1.5)
- [ ] `test_motionLine_dashPattern_6_4` — Dash pattern is [6, 4] (6 on, 4 off); verify via StrokeStyle(dash: [6, 4])
- [ ] `test_motionLine_strokeStyle_cap` — Dash pattern visible (not hidden by line cap/join); verify dash pattern not obscured by .round caps

#### 1.2 Motion Line Z-Order: Before Routes

**Tests:**
- [ ] `test_motionLine_drawn_before_route` — Motion line is drawn BEFORE route line in Canvas draw order; verify by drawing order inspection or screenshot (motion line should be visible under route, not on top)
- [ ] `test_motionLine_not_obscured_by_route` — When motion and route overlap, motion dashes are visible through/under the solid route line

#### 1.3 Label Placement

**Tests:**
- [ ] `test_yLabel_atInitialPosition_only` — Y labeled only at start position (where Y sits pre-snap), not at final position
- [ ] `test_yLabel_notDuplicated` — Only one Y label appears in diagram, not two (one at start, one at end)
- [ ] `test_yLabel_noMotionType` — Label is "Y (6)" not "Y (6) Stop" or "Y Stop (6)"; motion type does not appear on diagram
- [ ] `test_otherReceiverLabels_unchanged` — X, Z, A labels unchanged (drawn at their positions as before)

#### 1.4 Receiver Circles & Arrows

**Tests:**
- [ ] `test_receiverCircle_initialPosition_correct` — Y's receiver circle drawn at initial position, not final position
- [ ] `test_routeArrow_endPosition_correct` — Route arrow at end of solid route (final position endpoint), not at motion line endpoint
- [ ] `test_motionLine_noArrow` — Motion line has no arrow at its endpoint (only route line has arrow)

#### 1.5 Full Diagram Rendering (All Receivers)

**Tests:**
- [ ] `test_fiveReceiverDiagram_Y_Stop_Trips_Left` — All five receivers (if H present) render without overlap; X, Z, A routes normal; Y motion + route correct
- [ ] `test_fourReceiverDiagram_Y_Stop_noH` — All four receivers (X, Y, Z, A) render without overlap; Y motion + route correct
- [ ] `test_fiveReceiverDiagram_Y_Go_Trips_Right` — All receivers render; Y motion without setting placement correct; no route overlap

---

### 2. Model → Diagram Data Flow

**File:** `SpartansPlaycallerTests/Integration/MotionDataFlowTests.swift`

**Tests:**
- [ ] `test_playcall_to_diagram_yStop` — PlayCall with Y Stop motion flows to RouteDiagramView; positions are computed correctly
- [ ] `test_playcall_to_diagram_yAfter` — PlayCall with Y After motion flows correctly
- [ ] `test_playcall_to_diagram_yGo` — PlayCall with Y Go motion flows correctly
- [ ] `test_diagram_refresh_after_motion_change` — Change Y's motionType in PlayCall; RouteDiagramView re-renders with new motion endpoint

---

## E2E & Visual Test Scope

### 1. User Flow: Select Motion → Diagram Updates

**File:** `SpartansPlaycallerTests/E2E/MotionUIFlowTests.swift`

**Test Environment:** Xcode UI tests (XCTest) on simulator

**Preconditions:**
- App launched
- User has selected a formation (Twins, Trips Left, Trips Right)
- Route digits entered or concept selected (e.g., "6794" or "Smash")

**Test Cases:**

#### 1.1 Y Motion Selection UI
- [ ] `test_Y_motionButton_visible_in_UI` — Tap on Y receiver in ReceiverAssignmentView → motion options appear (Y Stop, Y After, Y Go, None)
- [ ] `test_Y_motionButton_only_for_Y` — Other receivers (X, Z, A, H) do not show motion options (or show disabled/grayed out)
- [ ] `test_select_Y_Stop_motion` — Select "Y Stop" → PlayCall updates with motionType=.yStop, finalPosition=X
- [ ] `test_select_Y_After_motion` — Select "Y After" → PlayCall updates with motionType=.yAfter, finalPosition updated (TBD: Z or A depending on formation)
- [ ] `test_select_Y_Go_motion` — Select "Y Go" → PlayCall updates with motionType=.yGo, finalPosition updated

#### 1.2 Diagram Reflects UI Selection
- [ ] `test_diagram_updates_after_yStop_selected` — Select Y Stop in UI → diagram immediately shows dashed motion line from Y to X, solid route from X position onward
- [ ] `test_diagram_updates_after_yAfter_selected` — Select Y After → diagram shows motion to opposite side receiver
- [ ] `test_diagram_clears_motion_when_deselected` — Select "None" after choosing Y Stop → motion line disappears from diagram
- [ ] `test_diagram_persistence_after_viewUpdate` — Rotate device or dismiss/reopen view → motion line persists in diagram

#### 1.3 Formation-Specific Motion Rules
- [ ] `test_Y_motion_Trips_Left` — In Trips Left, Y motion options and diagram render correctly
- [ ] `test_Y_motion_Trips_Right` — In Trips Right, Y motion options and diagram render correctly
- [ ] `test_Y_motion_Twins_disabled_or_valid` — [TBD] In Twins, confirm if Y motion is supported; if yes, test it; if no, test that UI disables the option

---

### 2. Visual Regression Tests (Snapshots)

**File:** `SpartansPlaycallerTests/Snapshots/MotionVisualRegressionTests.swift`

**Tool:** FBSnapshotTestCase or SnapshotTesting library

**Test Matrix:**

| Motion Type | Formation | Device | Orientation | Baseline File |
|-------------|-----------|--------|-------------|---------------|
| Y Stop | Twins | iPhone 15 (390×844) | Portrait | y-stop-twins-iphone15-portrait.png |
| Y Stop | Twins | iPhone SE (375×667) | Portrait | y-stop-twins-iphonese-portrait.png |
| Y Stop | Trips Left | iPhone 15 | Portrait | y-stop-trips-left-iphone15-portrait.png |
| Y Stop | Trips Right | iPhone 15 | Portrait | y-stop-trips-right-iphone15-portrait.png |
| Y After | Twins | iPhone 15 | Portrait | y-after-twins-iphone15-portrait.png |
| Y After | Trips Left | iPhone 15 | Portrait | y-after-trips-left-iphone15-portrait.png |
| Y After | Trips Right | iPhone 15 | Portrait | y-after-trips-right-iphone15-portrait.png |
| Y Go | Twins | iPhone 15 | Portrait | y-go-twins-iphone15-portrait.png |
| Y Go | Trips Left | iPhone 15 | Portrait | y-go-trips-left-iphone15-portrait.png |
| Y Go | Trips Right | iPhone 15 | Portrait | y-go-trips-right-iphone15-portrait.png |
| None (baseline, no motion) | Twins | iPhone 15 | Portrait | no-motion-twins-iphone15-portrait.png |
| None (baseline, no motion) | Trips Left | iPhone 15 | Portrait | no-motion-trips-left-iphone15-portrait.png |

**Total Snapshot Tests:** ~15 (3 motion types × 3 formations + 3 baselines + iPhone SE validation)

**Test Cases:**
```swift
// Pseudo-code for one test
func test_Y_Stop_Trips_Left_iPhone15_Portrait() {
    let playCall = PlayCall(
        formation: .tripsLeft,
        routeDigits: "6794",
        assignments: [
            RouteAssignment(receiver: .X, routeNumber: .six, side: .left, meaning: .curl, motionType: nil, finalPosition: nil),
            RouteAssignment(receiver: .Y, routeNumber: .seven, side: .left, meaning: .corner, motionType: .yStop, finalPosition: .X),
            RouteAssignment(receiver: .Z, routeNumber: .nine, side: .right, meaning: .go, motionType: nil, finalPosition: nil),
            RouteAssignment(receiver: .A, routeNumber: .four, side: .left, meaning: .dig, motionType: nil, finalPosition: nil),
        ],
        concept: nil
    )
    let view = RouteDiagramView(playCall: playCall)
    assertSnapshot(matching: view, as: .image(traits: .iPhone15_portrait))
}
```

**Snapshot Strategy:**
- Baselines stored in `SpartansPlaycallerTests/Snapshots/ReferenceImages/`
- First run generates baselines (with `-record` flag or automatic first-run)
- Subsequent runs compare pixel-perfect; any drift fails the test
- Review policy: **If a snapshot fails, human review required before updating baseline.** Changes are only acceptable if they are intentional (e.g., styling update, bug fix in rendering).

---

## Visual Correctness Acceptance Criteria (Mapped to Tests)

| Acceptance Criterion | Unit Test | Integration Test | E2E/Visual Test | Notes |
|---------------------|-----------|-----------------|-----------------|-------|
| RouteAssignment + PlayCall support motionType and finalPosition | RouteAssignmentTests.swift | — | — | Data structure validation |
| DiagramRenderer correctly calculates final position endpoint for Y Stop / Y After | DiagramRendererMotionTests.swift | — | — | Geometry validation |
| RouteDiagramView renders motion line with correct color, opacity, dash pattern, and width | — | RouteDiagramViewMotionTests.swift (1.1) | — | Canvas rendering |
| Motion lines render BEFORE routes (visual test: motion not visible on top of route) | — | RouteDiagramViewMotionTests.swift (1.2) | MotionUIFlowTests.swift (1.2) | Z-order validation |
| Y label appears only at initial position, not final position | — | RouteDiagramViewMotionTests.swift (1.3) | MotionUIFlowTests.swift (1.2) | Label placement |
| All five receivers' routes render without overlap when Y has motion | — | RouteDiagramViewMotionTests.swift (1.5) | MotionVisualRegressionTests.swift | No rendering artifacts |
| Dashes are visible on iOS devices (visual test at minimum canvas size, iPhone SE) | — | RouteDiagramViewMotionTests.swift (1.1) | MotionVisualRegressionTests.swift | Device-specific rendering |
| Concept library correctly stores / returns motions (if concepts include motion type) | [TBD: ConceptLibrary tests] | [TBD] | — | If motion is part of concept templates |
| Play call parser correctly parses motion notation (if parser is extended for motion) | [TBD: PlayCallParser tests] | [TBD] | — | If motion is persisted in digit notation |

---

## Performance Testing Approach

### Scope & Rationale

**Question:** Does adding dashed motion lines impact Canvas rendering performance?

**Answer:** Yes, dashing adds rendering complexity. However, for a single dashed line per motion (one Y at a time), impact is negligible on modern iOS devices. We test to verify:
1. No frame drops when Y motion is active
2. Low-end devices (iPhone SE) maintain 60 FPS during diagram render
3. Memory footprint does not increase significantly

**Out of scope:** Load testing dozens of diagrams simultaneously, stress tests with 10+ motions, or performance under constrained OS memory (background app). These are architectural limits, not regression risks for this feature.

### Test Plan

**File:** `SpartansPlaycallerTests/Performance/MotionRenderingPerformanceTests.swift`

**Environment:**
- Xcode Instruments (Core Animation, System Trace)
- Simulator: iPhone SE (3rd gen, A15 Bionic, 3GB RAM) — lowest-spec device
- Device: iPhone 15 (A17 Pro) — typical modern device
- Baseline: existing RouteDiagramView rendering without motion (no-motion baseline)

**Metrics:**
- **Frame render time:** Time for Canvas to draw one frame with motion line
- **FPS stability:** Frame rate consistency (target: 60 FPS, acceptable: >50 FPS)
- **Memory delta:** Memory increase when motion line is rendered vs. baseline (acceptable: <5 MB)

**Test Cases:**

#### 1. Single Motion Line Render Time
```swift
func test_Y_Stop_motionRender_frameTime_iPhone_SE() {
    // Measure time to draw diagram with Y Stop motion
    let playCall = /* PlayCall with Y Stop */
    let view = RouteDiagramView(playCall: playCall)
    
    // Measure 30 frames
    measure {
        _ = view.body  // Force render
    }
    
    // Assert avg frame time < 16.67ms (60 FPS) on iPhone SE
}
```

#### 2. FPS Stability During Animation (e.g., diagram refresh on motion change)
```swift
func test_motionChange_maintains_60fps() {
    // Change Y's motionType and observe frame rate
    // Use XCTest's -measure or CADisplayLink to track FPS
}
```

#### 3. Memory Baseline
```swift
func test_motionRendering_memoryDelta() {
    // Capture memory before and after rendering motion
    // Assert delta < 5 MB
}
```

### Performance Thresholds

| Device | Metric | Acceptable | Fail Threshold |
|--------|--------|-----------|-----------------|
| iPhone SE | Avg frame render time | < 16.67 ms (60 FPS) | > 20 ms (50 FPS) |
| iPhone SE | Memory delta | < 5 MB | > 10 MB |
| iPhone 15 | Avg frame render time | < 16.67 ms (60 FPS) | > 20 ms (50 FPS) |
| iPhone 15 | Memory delta | < 2 MB | > 5 MB |

**If performance test fails:** Investigate whether dashing is the cause (compare motion line render time vs. solid line). If dashing is the bottleneck, consider:
- Using solid line with different color/pattern in non-optimized paths
- Caching the motion line path to avoid recalculation every frame
- Rendering at lower resolution on low-end devices (e.g., half DPI on iPhone SE)

---

## Test Environment Prerequisites

### Simulator Configuration

**Required Simulators:**
- iPhone 15 (latest, 390×844) — primary test device
- iPhone SE (3rd gen, 375×667) — low-end validation, dash visibility check
- iPad Air (5th gen, 1024×1366) — optional, landscape rendering

**OS Versions:**
- iOS 17 (app baseline)
- iOS 18 (future compatibility, if available)

**Xcode Version:** 15.0 or later (required for iOS 17 Canvas API)

### Device Testing (Optional, Recommended for Final Verification)

**Physical Devices:**
- iPhone 15 or iPhone 14 (for snapshot & visual baseline)
- iPhone SE (for low-end dash visibility validation)

**Display Requirements:**
- Minimum screen size: 375×667 (iPhone SE)
- Dash pattern must be visible at minimum size (dashes of 6pt on, 4pt off)

### Test Data & Fixtures

**PlayCall Fixtures (Swift code, not fixtures files):**
```swift
extension PlayCall {
    static var yStopTripsLeft: PlayCall {
        PlayCall(
            formation: .tripsLeft,
            routeDigits: "6794",
            assignments: [
                RouteAssignment(receiver: .X, routeNumber: .six, side: .left, meaning: .curl, motionType: nil, finalPosition: nil),
                RouteAssignment(receiver: .Y, routeNumber: .seven, side: .left, meaning: .corner, motionType: .yStop, finalPosition: .X),
                RouteAssignment(receiver: .Z, routeNumber: .nine, side: .right, meaning: .go, motionType: nil, finalPosition: nil),
                RouteAssignment(receiver: .A, routeNumber: .four, side: .left, meaning: .dig, motionType: nil, finalPosition: nil),
            ],
            concept: nil
        )
    }
    // ... similar fixtures for yAfter, yGo, other formations
}
```

### Testing Framework & Tools

**Unit & Integration Tests:**
- **Framework:** XCTest (native to Xcode, no external dependencies)
- **Mocking:** None required (all tests work with real objects; no external services)
- **Snapshot Testing:** FBSnapshotTestCase (Pod) or Swift Package Manager equivalent (SnapshotTesting)
  - Add to `Podfile`: `pod 'FBSnapshotTestCase'` (or use SPM)

**E2E Tests:**
- **Framework:** XCTest UI tests (XCUITest)
- **No external dependencies required**

**Performance Tests:**
- **Framework:** XCTest's `-measure` block and Core Animation Instruments
- **Instruments:** Xcode Instruments (built-in); use "Core Animation" and "System Trace" templates

### CI/CD Pipeline Prerequisites

**GitHub Actions (Assume github-hosted runner):**
```yaml
- name: Run unit tests
  run: xcodebuild test -scheme SpartansPlaycaller -destination 'generic/platform=iOS Simulator,name=iPhone 15'

- name: Run UI tests
  run: xcodebuild test -scheme SpartansPlaycallerUITests -destination 'generic/platform=iOS Simulator,name=iPhone 15'

- name: Run snapshot tests
  run: xcodebuild test -scheme SpartansPlaycaller -destination 'generic/platform=iOS Simulator,name=iPhone 15' TEST_SESSION=snapshot
```

**Environment Variables:**
- `TEST_SESSION`: Set to `snapshot` for snapshot tests (first run: `-record`, subsequent: compare mode)
- `TEST_DEVICE`: Target simulator/device name (default: iPhone 15)

---

## Snapshot Test Management

### First-Time Setup

1. Create `SpartansPlaycallerTests/Snapshots/ReferenceImages/` directory
2. Run snapshot tests with `-record` flag to generate baselines:
   ```bash
   xcodebuild test -scheme SpartansPlaycaller -destination 'generic/platform=iOS Simulator,name=iPhone 15' -environmentVariables FBSNAPSHOTTEST_RECORD=YES
   ```
3. Review all generated baseline images in `ReferenceImages/` directory
4. Commit baselines to git (they are the source of truth)

### Ongoing Maintenance

**When a snapshot fails:**
1. Inspect the diff image (test output shows side-by-side comparison)
2. If the diff is **intentional** (e.g., styling change, bug fix):
   - Re-run with `-record` flag to update the baseline
   - Commit the new baseline
3. If the diff is **unintentional** (regression):
   - Revert the code change OR
   - File a bug and fix the rendering code
   - Re-run test (without -record); should pass after fix

**When adding new motion types or formations:**
1. Add new test case (e.g., `test_Y_Go_NewFormation_...`)
2. Run with `-record` to generate baseline
3. Review baseline image
4. Commit baseline

---

## Risk & Residual Gaps

### Known Unknowns (TBD)

- **Motion in Concept Templates:** Does ConceptLibrary include motion definitions? If yes, ConceptLibrary tests and integration tests needed.
- **Motion Notation Parsing:** Does PlayCallParser support motion notation (e.g., "6794M" for motion, or separate UI input)? If yes, parser tests and integration needed.
- **Multi-Receiver Motion:** Can multiple receivers motion simultaneously? Or only Y? Current strategy assumes single Y. If multiple allowed, expand matrix tests.
- **Formation Motion Rules:** Do all formations support all motion types? Current strategy assumes Trips Left/Right support all; Twins support TBD. Confirm and adjust acceptance criteria.
- **Landscape Rendering:** Diagram rendering in landscape mode. Current strategy focuses on portrait. Add landscape snapshot if landscape mode is supported.

### Gaps & Deferred Items

| Gap | Rationale | Defer Trigger |
|-----|-----------|----------------|
| Load test: 10+ motions on screen simultaneously | Architectural limit; not a regression risk for single Y motion | Add to tech debt backlog if multi-receiver motion is planned |
| Cross-platform (Android) snapshot tests | Out of scope per PROJECT_CONTEXT (iOS only) | Never; not applicable |
| Performance under OS memory pressure | Requires specific test environment setup; low customer risk | Add to tech debt if app scales to many diagrams in memory |
| Advanced accessibility tests (VoiceOver, dynamic type) | Motion feature is visual; no UX text/labels that require dynamic sizing | Add to backlog when accessibility is prioritized |

---

## Acceptance Test Checklist

Before declaring the Y receiver motion feature complete, verify:

### Data & Model Layer
- [ ] MotionType enum defined and tested
- [ ] RouteAssignment extended with motionType and finalPosition fields
- [ ] PlayCall supports RouteAssignments with motion
- [ ] Edge cases: nil motion, same start/end, invalid receiver — handled gracefully

### Geometry & Rendering Layer
- [ ] DiagramRenderer.motionLinePath() calculates correct endpoints for Y Stop / Y After / Y Go
- [ ] Motion line color is yellow (correct hex value)
- [ ] Motion line opacity is 0.5
- [ ] Motion line width is 1.5pt
- [ ] Dash pattern is [6, 4]
- [ ] Motion lines drawn BEFORE routes (Z-order correct)
- [ ] Motion lines visible (not obscured by routes)

### Visual Layer (Canvas & UI)
- [ ] RouteDiagramView renders motion lines correctly for all motion types
- [ ] Y receiver circle at initial position (not final)
- [ ] Y label at initial position only; no motion type label
- [ ] Route arrow at final endpoint (not at motion endpoint)
- [ ] All five receivers' routes render without overlap or artifacts

### User Interface & Flow
- [ ] UI allows selecting Y motion (Y Stop, Y After, Y Go, None)
- [ ] Motion selection disabled/grayed for non-Y receivers
- [ ] Selecting motion updates PlayCall
- [ ] Diagram updates immediately after motion selection
- [ ] Motion persists after view updates (rotation, dismiss/reopen)

### Visual Regression & Device Coverage
- [ ] Snapshot baselines captured for all motion types × formations
- [ ] Snapshots generated on iPhone 15 and iPhone SE
- [ ] Dash pattern visible on iPhone SE (low-end device)
- [ ] No unintended visual drift detected in snapshot tests

### Performance
- [ ] Motion render time < 16.67ms (60 FPS) on iPhone SE
- [ ] Memory delta < 5 MB (iPhone SE) / < 2 MB (iPhone 15)
- [ ] Frame rate stable (no dropped frames during motion change)

### Documentation
- [ ] Test strategy document complete and comprehensive
- [ ] Test files created with placeholders and implementation comments
- [ ] Fixtures and helper methods documented in test code

---

## Test Execution & Reporting

### Running Tests Locally

```bash
# Unit & integration tests (all at once)
xcodebuild test -scheme SpartansPlaycaller -destination 'generic/platform=iOS Simulator,name=iPhone 15'

# Unit tests only
xcodebuild test -scheme SpartansPlaycaller -destination 'generic/platform=iOS Simulator,name=iPhone 15' -only-testing SpartansPlaycallerTests/Models/ -only-testing SpartansPlaycallerTests/Services/

# UI tests only
xcodebuild test -scheme SpartansPlaycallerUITests -destination 'generic/platform=iOS Simulator,name=iPhone 15'

# Snapshot tests (first run: capture baselines)
xcodebuild test -scheme SpartansPlaycaller -destination 'generic/platform=iOS Simulator,name=iPhone 15' -environmentVariables FBSNAPSHOTTEST_RECORD=YES

# Snapshot tests (subsequent runs: compare)
xcodebuild test -scheme SpartansPlaycaller -destination 'generic/platform=iOS Simulator,name=iPhone 15'

# Performance tests
xcodebuild test -scheme SpartansPlaycaller -destination 'generic/platform=iOS Simulator,name=iPhone SE' -only-testing SpartansPlaycallerTests/Performance/
```

### Test Results Reporting

After implementation, results are reported in `docs/test-plans/y-receiver-motion-test-results.md`:
- Pass/fail count by layer (unit, integration, E2E, snapshot, perf)
- Failure details (assertion, stack trace, device/orientation if applicable)
- Coverage metrics (line coverage, assertion coverage)
- Performance results (frame time, memory delta, FPS)
- Snapshot comparison images (before/after for any failures)

---

## Related & Future Work

- **Multi-receiver motion:** If Y, X, or other receivers can motion, expand matrix and test accordingly
- **Motion in playbook export:** If PDF export includes motion notation, add export validation tests
- **Animated motion preview:** If motion is animated (e.g., dashed line animates from start to end), add animation timing and flake-resistance tests
- **Motion in concepts:** If ConceptLibrary includes named motions (e.g., "Y Stop" as part of a concept), add concept-parsing tests
- **Accessibility for motion:** If non-sighted users need to understand motion, add VoiceOver tests and motion description text

---

## Revision History

| Date | Author | Changes |
|------|--------|---------|
| 2026-05-27 | SDET | Initial strategy document created |

