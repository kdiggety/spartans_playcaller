# Y Wheel Toggle Refactoring — Revised Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development to execute this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor Y wheel from a separate motion option to an additive toggle that works alongside Stop/After/Go motions, fix diagram arc rendering, and ship a working Y wheel feature for field testing.

**Architecture:**
- Separate motion type (Stop/After/Go/None) from wheel toggle (enabled/disabled)
- Motion determines receiver side behavior; wheel toggle adds arc rendering
- UI shows motion picker + wheel toggle checkbox
- Diagram renders base motion arc + wheel arc when both are selected
- Concept matching considers both motion and wheel state

**Tech Stack:** iOS 17+, SwiftUI, MVVM, Canvas rendering

---

## File Structure

**Modify:**
- `Models/ReceiverMotion.swift` — Split enum into motion type + wheel state
- `ViewModels/PlayCallerViewModel.swift` — Add `yWheelEnabled: Bool` property, update motion handling
- `Views/ReceiverAssignmentView.swift` — Update UI to show motion picker + wheel toggle
- `Services/DiagramRenderer.swift` — Fix arc rendering dispatch logic
- `Models/PlayCall.swift` — Add wheel state to data model if needed

**Test:**
- `Tests/ReceiverMotionTests.swift` — Verify wheel + motion combinations
- `Tests/DiagramRendererTests.swift` — Verify arc renders when wheel enabled

---

## Tasks

### Task 1: Refactor ReceiverMotion to Separate Motion Type from Wheel Toggle

**Files:**
- Modify: `SpartansPlaycaller/Models/ReceiverMotion.swift`

**Description:** Instead of `enum ReceiverMotion { case wheel }`, define motion as an enum (Stop/After/Go) and add a separate wheel property.

- [ ] **Step 1: Read current ReceiverMotion enum**

Read: `SpartansPlaycaller/Models/ReceiverMotion.swift`
Understand: Current cases (stop, after, go, wheel) and finalSide() method

- [ ] **Step 2: Write test for wheel + motion combinations**

```swift
// In SpartansPlaycallerTests/ReceiverMotionTests.swift

class ReceiverMotionWheelToggleTests: XCTestCase {
    func testAfterMotionWithWheelFlipsSide() {
        let motion = ReceiverMotion.after
        let finalSide = motion.finalSide(originalSide: .left)
        XCTAssertEqual(finalSide, .right, "After motion flips sides regardless of wheel")
    }
    
    func testStopMotionWithWheelStaysSide() {
        let motion = ReceiverMotion.stop
        let finalSide = motion.finalSide(originalSide: .left)
        XCTAssertEqual(finalSide, .left, "Stop motion keeps same side regardless of wheel")
    }
    
    func testWheelDescriptionIndependent() {
        // Wheel is now independent; just verify motion descriptions
        XCTAssertEqual(ReceiverMotion.stop.description, "Y Stop")
        XCTAssertEqual(ReceiverMotion.after.description, "Y After")
        XCTAssertEqual(ReceiverMotion.go.description, "Y Go")
    }
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `xcodebuild test -scheme SpartansPlaycaller -only-testing SpartansPlaycallerTests/ReceiverMotionWheelToggleTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "(FAILED|PASSED)"`
Expected: FAILED (wheel case will fail after refactoring)

- [ ] **Step 4: Refactor ReceiverMotion enum**

Remove `wheel` case. Keep Stop, After, Go only:

```swift
enum ReceiverMotion: Hashable {
    case stop
    case after
    case go
    
    func finalSide(originalSide: FieldSide) -> FieldSide {
        switch self {
        case .stop:
            return originalSide
        case .after, .go:
            return originalSide == .left ? .right : .left
        }
    }
    
    var description: String {
        switch self {
        case .stop:
            return "Y Stop"
        case .after:
            return "Y After"
        case .go:
            return "Y Go"
        }
    }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `xcodebuild test -scheme SpartansPlaycaller -only-testing SpartansPlaycallerTests/ReceiverMotionWheelToggleTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "(FAILED|PASSED)"`
Expected: PASSED

- [ ] **Step 6: Verify app builds**

Run: `xcodebuild build -scheme SpartansPlaycaller -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "(error|Build complete)"`
Expected: `Build complete!` (compilation errors in UI code expected — we'll fix next)

- [ ] **Step 7: Commit**

```bash
git add SpartansPlaycaller/Models/ReceiverMotion.swift SpartansPlaycallerTests/ReceiverMotionWheelToggleTests.swift
git commit -m "refactor: separate ReceiverMotion enum (remove wheel case, keep Stop/After/Go only)"
```

---

### Task 2: Add yWheelEnabled Property to PlayCallerViewModel

**Files:**
- Modify: `SpartansPlaycaller/ViewModels/PlayCallerViewModel.swift`

**Description:** Add a `yWheelEnabled: Bool` property to track wheel toggle state separately from motion.

- [ ] **Step 1: Read current ViewModel**

Read: `SpartansPlaycaller/ViewModels/PlayCallerViewModel.swift`
Understand: Current `selectedMotion`, how it's used, where it's published

- [ ] **Step 2: Add yWheelEnabled property**

Add after `selectedMotion` property:

```swift
@Published var selectedMotion: ReceiverMotion? = nil
@Published var yWheelEnabled: Bool = false  // NEW: wheel toggle, independent of motion
```

- [ ] **Step 3: Update playCall computed property**

The playCall should pass both motion and wheel state:

```swift
var playCall: PlayCall {
    let assignment = PlayCallParser.parse(digitSequence, in: selectedFormation)
    var call = PlayCall(
        formation: selectedFormation,
        digitSequence: digitSequence,
        receiverAssignments: assignment,
        selectedConcept: selectedConcept,
        yReceiverMotion: selectedMotion,
        yWheelEnabled: yWheelEnabled  // NEW: pass wheel state
    )
    return call
}
```

(Note: PlayCall model may need update in next task)

- [ ] **Step 4: Update motion reset logic**

Ensure wheel toggle is reset appropriately when formation changes:

```swift
func formationChanged() {
    selectedFormation = newFormation
    selectedMotion = nil
    yWheelEnabled = false  // Reset wheel when formation changes
    // ... rest of logic
}
```

- [ ] **Step 5: Verify app builds**

Run: `xcodebuild build -scheme SpartansPlaycaller -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "(error|Build complete)"`
Expected: Build succeeds (UI still needs fixing)

- [ ] **Step 6: Commit**

```bash
git add SpartansPlaycaller/ViewModels/PlayCallerViewModel.swift
git commit -m "feat: add yWheelEnabled property to ViewModel (independent of motion)"
```

---

### Task 3: Update PlayCall Model to Include Wheel State

**Files:**
- Modify: `SpartansPlaycaller/Models/PlayCall.swift`

**Description:** Add `yWheelEnabled` parameter to PlayCall struct so diagram renderer can access wheel state.

- [ ] **Step 1: Read current PlayCall struct**

Read: `SpartansPlaycaller/Models/PlayCall.swift`
Understand: Current properties, init signature

- [ ] **Step 2: Add yWheelEnabled property**

```swift
struct PlayCall {
    let formation: Formation
    let digitSequence: String
    let receiverAssignments: [Receiver: RouteAssignment]
    let selectedConcept: RouteConcept?
    let yReceiverMotion: ReceiverMotion?
    let yWheelEnabled: Bool  // NEW: wheel toggle state
    
    init(
        formation: Formation,
        digitSequence: String,
        receiverAssignments: [Receiver: RouteAssignment],
        selectedConcept: RouteConcept?,
        yReceiverMotion: ReceiverMotion?,
        yWheelEnabled: Bool = false  // Default false
    ) {
        self.formation = formation
        self.digitSequence = digitSequence
        self.receiverAssignments = receiverAssignments
        self.selectedConcept = selectedConcept
        self.yReceiverMotion = yReceiverMotion
        self.yWheelEnabled = yWheelEnabled
    }
}
```

- [ ] **Step 3: Verify app builds**

Run: `xcodebuild build -scheme SpartansPlaycaller -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "(error|Build complete)"`
Expected: `Build complete!`

- [ ] **Step 4: Commit**

```bash
git add SpartansPlaycaller/Models/PlayCall.swift
git commit -m "feat: add yWheelEnabled property to PlayCall struct"
```

---

### Task 4: Fix DiagramRenderer Arc Rendering

**Files:**
- Modify: `SpartansPlaycaller/Services/DiagramRenderer.swift`

**Description:** Fix the motionPath() dispatch logic to render wheel arc when yWheelEnabled is true, regardless of motion selection.

- [ ] **Step 1: Read current motionPath() logic**

Read: `SpartansPlaycaller/Services/DiagramRenderer.swift`
Find: `motionPath()` method, `yMotionPath()`, `yWheelArcPath()`
Understand: How it currently dispatches based on motion case

- [ ] **Step 2: Write test for wheel arc rendering**

```swift
// In SpartansPlaycallerTests/DiagramRendererTests.swift

class DiagramRendererWheelRenderingTests: XCTestCase {
    let renderer = DiagramRenderer()
    
    func testWheelArcRendersWhenWheelEnabledWithAfterMotion() {
        let playCall = PlayCall(
            formation: .tripsLeft,
            digitSequence: "6794",
            selectedConcept: nil,
            yReceiverMotion: .after,
            yWheelEnabled: true  // Wheel + After
        )
        
        let (path, _) = renderer.motionPath(for: playCall) ?? (Path(), .clear)
        XCTAssertNotNil(renderer.motionPath(for: playCall), "Should render arc for wheel + motion")
    }
    
    func testWheelArcRendersWithoutMotion() {
        let playCall = PlayCall(
            formation: .tripsLeft,
            digitSequence: "6794",
            selectedConcept: nil,
            yReceiverMotion: nil,  // No motion, just wheel
            yWheelEnabled: true
        )
        
        let (path, _) = renderer.motionPath(for: playCall) ?? (Path(), .clear)
        XCTAssertNotNil(renderer.motionPath(for: playCall), "Should render arc for wheel alone")
    }
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `xcodebuild test -scheme SpartansPlaycaller -only-testing SpartansPlaycallerTests/DiagramRendererWheelRenderingTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "(FAILED|PASSED)"`
Expected: FAILED (logic not yet updated)

- [ ] **Step 4: Fix motionPath() to handle wheel + motion**

Replace the motionPath() logic:

```swift
func motionPath(for playCall: PlayCall) -> (Path, Color)? {
    // If wheel is enabled, always render wheel arc
    if playCall.yWheelEnabled {
        return yWheelArcPath(for: playCall)
    }
    
    // Otherwise, render base motion arc if motion is selected
    guard let motion = playCall.yReceiverMotion else {
        return nil
    }
    
    switch motion {
    case .stop:
        return nil  // No arc for Y Stop
    case .after, .go:
        return yMotionPath(for: playCall)
    }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `xcodebuild test -scheme SpartansPlaycaller -only-testing SpartansPlaycallerTests/DiagramRendererWheelRenderingTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "(FAILED|PASSED)"`
Expected: PASSED

- [ ] **Step 6: Verify app builds**

Run: `xcodebuild build -scheme SpartansPlaycaller -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "(error|Build complete)"`
Expected: `Build complete!`

- [ ] **Step 7: Commit**

```bash
git add SpartansPlaycaller/Services/DiagramRenderer.swift SpartansPlaycallerTests/DiagramRendererWheelRenderingTests.swift
git commit -m "fix: update motionPath() to render wheel arc when yWheelEnabled is true"
```

---

### Task 5: Update UI to Show Motion Picker + Wheel Toggle

**Files:**
- Modify: `SpartansPlaycaller/Views/ReceiverAssignmentView.swift`

**Description:** Replace the 4-option motion picker (Stop|After|Go|Wheel) with a 3-option picker (Stop|After|Go) + a wheel toggle checkbox.

- [ ] **Step 1: Read current motion picker UI**

Read: `SpartansPlaycaller/Views/ReceiverAssignmentView.swift`
Find: Motion picker code (Picker or Segmented control showing Stop|After|Go|Wheel)

- [ ] **Step 2: Write test for UI state**

```swift
// In SpartansPlaycallerTests/PlayCallerViewTests.swift (if exists) or create new file

class MotionPickerUITests: XCTestCase {
    func testMotionPickerShowsThreeOptions() {
        // This is an integration test; verify motion picker shows Stop, After, Go
        let viewModel = PlayCallerViewModel()
        viewModel.selectedFormation = .tripsLeft
        
        // Motion should be Stop, After, or Go (not Wheel)
        XCTAssertNil(viewModel.selectedMotion)  // Initial state
        
        viewModel.selectedMotion = .stop
        XCTAssertEqual(viewModel.selectedMotion, .stop)
    }
    
    func testWheelToggleIndependentOfMotion() {
        let viewModel = PlayCallerViewModel()
        viewModel.selectedFormation = .tripsLeft
        viewModel.selectedMotion = .after
        viewModel.yWheelEnabled = true
        
        XCTAssertEqual(viewModel.selectedMotion, .after)
        XCTAssertTrue(viewModel.yWheelEnabled)
    }
}
```

- [ ] **Step 3: Replace motion picker**

Find the existing picker code and replace:

```swift
// OLD (remove):
Picker("Y Motion", selection: $viewModel.selectedMotion) {
    Text("Stop").tag(ReceiverMotion?.stop)
    Text("After").tag(ReceiverMotion?.after)
    Text("Go").tag(ReceiverMotion?.go)
    Text("Wheel").tag(ReceiverMotion?.wheel)  // REMOVE
}

// NEW (replace with):
VStack {
    Picker("Y Motion", selection: $viewModel.selectedMotion) {
        Text("None").tag(ReceiverMotion?.none)  // or nil
        Text("Stop").tag(ReceiverMotion?.stop)
        Text("After").tag(ReceiverMotion?.after)
        Text("Go").tag(ReceiverMotion?.go)
    }
    
    Toggle("Y Wheel", isOn: $viewModel.yWheelEnabled)
        .disabled(viewModel.selectedFormation == .twins)  // Wheel only in Trips/Pro
}
```

- [ ] **Step 4: Verify UI shows correctly**

Run the app in simulator:
- [ ] Motion picker shows: None | Stop | After | Go
- [ ] Wheel toggle appears below motion picker
- [ ] Wheel toggle is disabled in Twins formation
- [ ] Wheel toggle is enabled in Trips/Pro formations

- [ ] **Step 5: Verify app builds**

Run: `xcodebuild build -scheme SpartansPlaycaller -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "(error|Build complete)"`
Expected: `Build complete!`

- [ ] **Step 6: Commit**

```bash
git add SpartansPlaycaller/Views/ReceiverAssignmentView.swift SpartansPlaycallerTests/PlayCallerViewTests.swift
git commit -m "ui: replace motion picker Wheel option with independent toggle"
```

---

### Task 6: Update Concept Matching for Wheel State

**Files:**
- Modify: `SpartansPlaycaller/Services/ConceptMatcher.swift`

**Description:** Ensure concept matching considers wheel state (concept should remain valid when wheel is added to motion).

- [ ] **Step 1: Read ConceptMatcher identify() logic**

Read: `SpartansPlaycaller/Services/ConceptMatcher.swift`
Understand: How it identifies concepts based on motion

- [ ] **Step 2: Write test for wheel + concept**

```swift
// In SpartansPlaycallerTests/ConceptMatcherTests.swift

func testConceptRemainValidWhenWheelAdded() {
    // Setup: Trips Left, Smash concept
    let playCall = PlayCall(
        formation: .tripsLeft,
        digitSequence: "6758",
        selectedConcept: .smash,
        yReceiverMotion: nil,
        yWheelEnabled: false
    )
    
    var identified = ConceptMatcher.identify(playCall)
    XCTAssertEqual(identified.left, .smash, "Smash identified initially")
    
    // Add wheel toggle
    var wheelPlayCall = playCall
    wheelPlayCall.yWheelEnabled = true
    
    identified = ConceptMatcher.identify(wheelPlayCall)
    XCTAssertEqual(identified.left, .smash, "Smash still identified with wheel enabled")
}
```

- [ ] **Step 3: Run test to verify it passes**

Run: `xcodebuild test -scheme SpartansPlaycaller -only-testing SpartansPlaycallerTests/ConceptMatcherTests::testConceptRemainValidWhenWheelAdded -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "(FAILED|PASSED)"`
Expected: PASSED (identify() should ignore wheel state, just use motion)

- [ ] **Step 4: Verify identify() doesn't depend on wheel state**

Read ConceptMatcher.identify() — it should only use `yReceiverMotion`, not `yWheelEnabled`:

```swift
func identify(_ playCall: PlayCall) -> (left: RouteConcept?, right: RouteConcept?) {
    // Wheel state doesn't affect concept identification
    // Only motion type (Stop/After/Go) affects side interpretation
    // ... existing logic unchanged
}
```

If identify() already works correctly (doesn't reference wheel), no changes needed.

- [ ] **Step 5: Verify app builds**

Run: `xcodebuild build -scheme SpartansPlaycaller -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "(error|Build complete)"`
Expected: `Build complete!`

- [ ] **Step 6: Commit**

```bash
git add SpartansPlaycallerTests/ConceptMatcherTests.swift
git commit -m "test: verify concept matching handles wheel toggle correctly"
```

---

### Task 7: End-to-End Test — Wheel Toggle + Diagram Arc

**Files:**
- Create: `SpartansPlaycallerTests/PlayCallWheelToggleFlowTests.swift`

**Description:** Integration test verifying the complete flow: motion picker + wheel toggle → diagram renders arc.

- [ ] **Step 1: Write end-to-end test**

```swift
// In SpartansPlaycallerTests/PlayCallWheelToggleFlowTests.swift

import XCTest
@testable import SpartansPlaycaller

class PlayCallWheelToggleFlowTests: XCTestCase {
    let viewModel = PlayCallerViewModel()
    
    func testMotionAndWheelToggleFlow() {
        // Setup
        viewModel.selectedFormation = .tripsLeft
        viewModel.selectedLeftConcept = .smash
        viewModel.generatePlayCall()
        
        // Step 1: Select After motion
        viewModel.selectedMotion = .after
        XCTAssertEqual(viewModel.selectedMotion, .after)
        
        // Step 2: Enable wheel
        viewModel.yWheelEnabled = true
        XCTAssertTrue(viewModel.yWheelEnabled)
        
        // Step 3: Verify diagram can render (arc should be present)
        let renderer = DiagramRenderer()
        let (motionPath, color) = renderer.motionPath(for: viewModel.playCall) ?? (Path(), .clear)
        XCTAssertNotNil(renderer.motionPath(for: viewModel.playCall), "Arc should render for After + Wheel")
        
        // Step 4: Disable wheel
        viewModel.yWheelEnabled = false
        
        // Step 5: Verify arc is still rendered (After motion should have its own arc)
        let motionPathAfterDisable = renderer.motionPath(for: viewModel.playCall)
        XCTAssertNotNil(motionPathAfterDisable, "After motion should still render arc")
    }
    
    func testWheelWithoutMotion() {
        viewModel.selectedFormation = .tripsRight
        viewModel.selectedLeftConcept = .dagger
        viewModel.generatePlayCall()
        
        // No motion selected, just wheel
        viewModel.selectedMotion = nil
        viewModel.yWheelEnabled = true
        
        // Wheel arc should render alone
        let renderer = DiagramRenderer()
        let (motionPath, _) = renderer.motionPath(for: viewModel.playCall) ?? (Path(), .clear)
        XCTAssertNotNil(renderer.motionPath(for: viewModel.playCall), "Wheel arc should render without base motion")
    }
}
```

- [ ] **Step 2: Run test to verify it passes**

Run: `xcodebuild test -scheme SpartansPlaycaller -only-testing SpartansPlaycallerTests/PlayCallWheelToggleFlowTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "(FAILED|PASSED)"`
Expected: All tests PASSED

- [ ] **Step 3: Verify app builds**

Run: `xcodebuild build -scheme SpartansPlaycaller -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "(error|Build complete)"`
Expected: `Build complete!`

- [ ] **Step 4: Manual verification in simulator**

Run the app on simulator:
- [ ] Select Trips Left formation
- [ ] Select Smash concept
- [ ] Verify diagram shows Y in left slot
- [ ] Select After motion
- [ ] Verify diagram shows Y After arc
- [ ] Enable wheel toggle
- [ ] Verify diagram shows Y wheel arc (semicircle behind formation)
- [ ] Disable wheel toggle
- [ ] Verify diagram returns to Y After arc

- [ ] **Step 5: Commit**

```bash
git add SpartansPlaycallerTests/PlayCallWheelToggleFlowTests.swift
git commit -m "test: add end-to-end wheel toggle + diagram rendering tests"
```

---

### Task 8: Version Bump and Field Test Notes Update

**Files:**
- Modify: Version in `SpartansPlaycaller.xcodeproj/project.pbxproj`
- Modify: `docs/FIELD-TEST-NOTES.md`

**Description:** Update version and document the wheel toggle behavior for field testing.

- [ ] **Step 1: Bump version**

Update version to `1.2.1` (incremental fix from 1.2.0):

```
MARKETING_VERSION = 1.2.1
CURRENT_PROJECT_VERSION = 3
```

- [ ] **Step 2: Update field test notes**

Replace Y Wheel section in `docs/FIELD-TEST-NOTES.md`:

```markdown
### 2. Y Wheel Motion (REVISED)
- **What:** Y receiver can now execute a **Y Wheel motion** — a semi-circular arc behind the formation (X/A or Z/A) and down the sideline
- **Key behavior:**
  - Y Wheel is a **toggle** that works WITH Stop/After/Go motions
  - Y Stop + Y Wheel = Y stops on same side WITH wheel arc
  - Y After + Y Wheel = Y flips sides WITH wheel arc
  - Y Wheel alone (no motion selected) = wheel arc only
- **How to test:**
  - Select Trips Left or Trips Right formation
  - Generate or parse a play (e.g., Smash = "6758")
  - Motion picker shows: None | Stop | After | Go (3 options, no Wheel option)
  - Wheel toggle checkbox appears below motion picker
  - Select a motion (e.g., After)
  - Enable the "Y Wheel" toggle
  - Verify:
    - Diagram shows Y motion arc (After = Y flips to right)
    - PLUS wheel arc (semicircle behind formation)
    - Both arcs visible together
  - Toggle wheel off/on to see arc appear/disappear

### Route 0 (Bubble/Screen) — Unchanged
[existing content]
```

- [ ] **Step 3: Verify app builds**

Run: `xcodebuild build -scheme SpartansPlaycaller -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "(error|Build complete)"`
Expected: `Build complete!`

- [ ] **Step 4: Commit**

```bash
git add SpartansPlaycaller.xcodeproj/project.pbxproj docs/FIELD-TEST-NOTES.md
git commit -m "docs: update version to 1.2.1 and document wheel toggle behavior"
```

---

## Summary

**Total Tasks:** 8  
**Estimated Timeline:** 2–3 days  
**Commits:** 8 atomic commits

**What Changes:**
1. ReceiverMotion: Remove wheel case, keep Stop/After/Go
2. ViewModel: Add yWheelEnabled toggle property
3. PlayCall: Add yWheelEnabled state
4. DiagramRenderer: Fix arc rendering when wheel enabled
5. UI: Replace Wheel option with toggle checkbox
6. Concept matching: Verify unchanged (no changes needed)
7. Integration tests: Validate complete flow
8. Version bump and docs

**Field Testing Ready:** Y wheel toggle working alongside motion options, arc renders in diagram, ready for coach feedback.
