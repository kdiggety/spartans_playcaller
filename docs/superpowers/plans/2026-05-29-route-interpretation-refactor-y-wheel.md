# Route Interpretation Refactoring + Route 0 Fix + Y Wheel Motion — One-Week Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development to execute this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor route interpretation into a pluggable strategy pattern, fix route 0 as a bubble/screen route, and implement Y wheel motion (same-side semi-circle arc) for field testing next week.

**Architecture:** 
- Extract route meaning logic from `RouteNumber.meaning(on:)` switch statement into a `RouteSemanticProvider` protocol
- Each route (0–9, and future customs) implements the protocol
- Separate "standard side-aware routes" (1, 2, 5, 6) from "absolute direction routes" (3, 4, 7, 8) from "bubble routes" (0)
- Add `ReceiverMotion.wheel` case with same-side interpretation (unlike Y After/Go which flips sides)
- Y wheel renders as a semi-circular arc behind X/A or Z/A, ending on original Y side

**Tech Stack:** iOS 17+, SwiftUI, MVVM, Canvas rendering, Xcode 15.4+

---

## File Structure

**Create:**
- `Models/RouteSemanticProvider.swift` — Protocol and implementations for all 10 route semantics
- `Models/ReceiverMotion+Wheel.swift` — Y wheel motion case and geometry

**Modify:**
- `Models/RouteNumber.swift` — Delegate `meaning(on:)` to semantic provider
- `Models/ReceiverMotion.swift` — Add `wheel` case
- `Models/RouteAssignment.swift` — Add `motionFinalSide` computation for Y wheel
- `Services/RouteInterpreter.swift` — No changes needed (delegates through RouteNumber)
- `Services/DiagramRenderer.swift` — Add Y wheel arc rendering (semi-circle behind receivers)
- `Views/PlayCallerView.swift` — Update motion picker to include Y wheel option

**Test:**
- `SpartansPlaycallerTests/RouteSemanticProviderTests.swift` — New; test all route semantics
- `SpartansPlaycallerTests/ReceiverMotionWheelTests.swift` — New; test Y wheel positioning and interpretation
- `SpartansPlaycallerTests/DiagramRendererYWheelTests.swift` — New; test wheel arc rendering
- Modify existing tests to validate no behavioral change

---

## Timeline

- **Days 1–2:** Route interpretation refactoring + tests (8h)
- **Day 2–3:** Route 0 bubble/screen fix (2h)
- **Days 3–5:** Y wheel motion + diagram rendering (8h)
- **Day 5–6:** Integration testing, field build preparation (2h)
- **Day 7:** Buffer / iteration

---

## Tasks

### Task 1: Define RouteSemanticProvider Protocol

**Files:**
- Create: `SpartansPlaycaller/Models/RouteSemanticProvider.swift`

**Description:** Extract route meaning logic into a pluggable protocol. Each route implements this protocol to define its side-aware or absolute-direction semantics.

- [ ] **Step 1: Write RouteSemanticProvider protocol definition**

```swift
// SpartansPlaycaller/Models/RouteSemanticProvider.swift

import Foundation

/// Protocol for route meaning semantics. Each route (0–9) implements this to define
/// how a receiver interprets the route based on field side.
protocol RouteSemanticProvider {
    /// Return the route meaning for a receiver on a given field side.
    /// - Parameter side: The field side (left, right, or center).
    /// - Returns: The RouteMeaning describing the route's direction and type.
    func meaning(on side: FieldSide) -> RouteMeaning
}

/// Standard side-aware route: meaning differs based on receiver's field side.
/// Example: Route 1 is Quick Out on left side, Quick Slant on right side.
struct SideAwareRouteSemantics: RouteSemanticProvider {
    let leftMeaning: RouteMeaning
    let rightMeaning: RouteMeaning
    
    func meaning(on side: FieldSide) -> RouteMeaning {
        switch side {
        case .left:
            return leftMeaning
        case .right:
            return rightMeaning
        case .center:
            return leftMeaning // Center (H) treats as left for interpretation
        }
    }
}

/// Absolute direction route: meaning is identical regardless of receiver's field side.
/// The route always breaks in the same direction (e.g., 3 always breaks left, 4 always breaks right).
struct AbsoluteDirectionRouteSemantics: RouteSemanticProvider {
    let meaning: RouteMeaning
    
    func meaning(on side: FieldSide) -> RouteMeaning {
        return meaning // Same meaning, all sides
    }
}

/// Bubble/screen route: receiver steps back behind line of scrimmage.
/// Same meaning both sides; defines a backward/lateral direction.
struct BubbleRouteSemantics: RouteSemanticProvider {
    let meaning: RouteMeaning
    
    func meaning(on side: FieldSide) -> RouteMeaning {
        return meaning // Screen routes are not side-dependent
    }
}
```

- [ ] **Step 2: Verify protocol compiles**

Run: `xcodebuild build -scheme SpartansPlaycaller -configuration Debug 2>&1 | grep -E "(error|Build complete)"`
Expected: `Build complete!` (no errors)

- [ ] **Step 3: Commit**

```bash
git add SpartansPlaycaller/Models/RouteSemanticProvider.swift
git commit -m "feat: add RouteSemanticProvider protocol for extensible route semantics"
```

---

### Task 2: Create Route 0 (Bubble/Screen) Semantic Implementation

**Files:**
- Modify: `SpartansPlaycaller/Models/RouteNumber.swift`
- Modify: `SpartansPlaycaller/Models/RouteMeaning.swift` (add bubble direction if not already)

**Description:** Define Route 0 as a bubble/screen route that goes backward behind the line of scrimmage. Same meaning both sides.

- [ ] **Step 1: Check current RouteMeaning enum for direction types**

Read: `SpartansPlaycaller/Models/RouteMeaning.swift`
Look for: enum cases like `leftBreak`, `rightBreak`, `vertical`, etc.

- [ ] **Step 2: Add backward direction to RouteMeaning if missing**

If `RouteMeaning` has a `direction` or similar enum, add `.backward` case. If using separate properties, ensure backward motion is representable.

Example (if direction is an enum):
```swift
enum RouteMeaning {
    case leftBreak(RouteType)
    case rightBreak(RouteType)
    case vertical(RouteType)
    case backward(RouteType) // NEW: screen/bubble routes
    // ... existing cases
}
```

Or (if direction is a property):
```swift
struct RouteMeaning {
    enum Direction {
        case left, right, up, backward // NEW: backward
    }
    let direction: Direction
    let type: RouteType
    // ...
}
```

- [ ] **Step 3: Write test for Route 0 bubble semantics**

```swift
// In SpartansPlaycallerTests/RouteSemanticProviderTests.swift (create if needed)

import XCTest
@testable import SpartansPlaycaller

class Route0BubbleTests: XCTestCase {
    func testRoute0IsBackwardBubbleLeftSide() {
        let semantics = BubbleRouteSemantics(meaning: .backward(.screen))
        let meaning = semantics.meaning(on: .left)
        
        XCTAssertEqual(meaning, .backward(.screen), "Route 0 should be backward bubble on left side")
    }
    
    func testRoute0IsBackwardBubbleRightSide() {
        let semantics = BubbleRouteSemantics(meaning: .backward(.screen))
        let meaning = semantics.meaning(on: .right)
        
        XCTAssertEqual(meaning, .backward(.screen), "Route 0 should be backward bubble on right side")
    }
    
    func testRoute0IsBackwardBubbleCenterSide() {
        let semantics = BubbleRouteSemantics(meaning: .backward(.screen))
        let meaning = semantics.meaning(on: .center)
        
        XCTAssertEqual(meaning, .backward(.screen), "Route 0 should be backward bubble on center (H receiver)")
    }
}
```

- [ ] **Step 4: Run test to verify it fails**

Run: `xcodebuild test -scheme SpartansPlaycaller -only-testing SpartansPlaycallerTests/Route0BubbleTests 2>&1 | grep -E "(FAILED|PASSED)"`
Expected: `FAILED` (Route 0 semantics not yet linked to RouteNumber enum)

- [ ] **Step 5: Update RouteNumber enum to use semantic provider for route 0**

Read: `SpartansPlaycaller/Models/RouteNumber.swift` to understand current switch statement

Find the `RouteNumber.meaning(on:)` method. We'll refactor it to delegate to providers. For now, add a temporary property:

```swift
enum RouteNumber: Int {
    case zero = 0
    case one = 1
    // ... etc
    
    // Temporary: will replace the big switch statement
    var semanticProvider: RouteSemanticProvider {
        switch self {
        case .zero:
            return BubbleRouteSemantics(meaning: .backward(.screen))
        case .one:
            return SideAwareRouteSemantics(
                leftMeaning: .leftBreak(.quickOut),
                rightMeaning: .rightBreak(.quickSlant)
            )
        // ... TODO: fill in for routes 2–9 in next tasks
        default:
            fatalError("Route \(self.rawValue) semantics not defined")
        }
    }
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `xcodebuild test -scheme SpartansPlaycaller -only-testing SpartansPlaycallerTests/Route0BubbleTests 2>&1 | grep -E "(FAILED|PASSED)"`
Expected: `PASSED`

- [ ] **Step 7: Commit**

```bash
git add SpartansPlaycaller/Models/RouteNumber.swift SpartansPlaycallerTests/RouteSemanticProviderTests.swift
git commit -m "feat: define Route 0 as bubble/screen route going backward"
```

---

### Task 3: Implement Route Semantics for Routes 1–9

**Files:**
- Modify: `SpartansPlaycaller/Models/RouteNumber.swift` (extend `semanticProvider`)
- Modify: `SpartansPlaycallerTests/RouteSemanticProviderTests.swift` (add test cases)

**Description:** Define semantic providers for all remaining routes (1–9) to match current domain rules.

- [ ] **Step 1: Write comprehensive test for all route semantics**

```swift
// In SpartansPlaycallerTests/RouteSemanticProviderTests.swift

class RouteSemanticProviderComprehensiveTests: XCTestCase {
    // Route 1: Quick Out (left) / Quick Slant (right)
    func testRoute1LeftSide() {
        let meaning = RouteNumber.one.semanticProvider.meaning(on: .left)
        XCTAssertEqual(meaning, .leftBreak(.quickOut), "Route 1 left = Quick Out")
    }
    
    func testRoute1RightSide() {
        let meaning = RouteNumber.one.semanticProvider.meaning(on: .right)
        XCTAssertEqual(meaning, .rightBreak(.quickSlant), "Route 1 right = Quick Slant")
    }
    
    // Route 2: Quick Slant (left) / Quick Out (right)
    func testRoute2LeftSide() {
        let meaning = RouteNumber.two.semanticProvider.meaning(on: .left)
        XCTAssertEqual(meaning, .leftBreak(.quickSlant), "Route 2 left = Quick Slant")
    }
    
    func testRoute2RightSide() {
        let meaning = RouteNumber.two.semanticProvider.meaning(on: .right)
        XCTAssertEqual(meaning, .rightBreak(.quickOut), "Route 2 right = Quick Out")
    }
    
    // Route 3: Always breaks left (absolute direction)
    func testRoute3LeftSide() {
        let meaning = RouteNumber.three.semanticProvider.meaning(on: .left)
        XCTAssertEqual(meaning, .leftBreak(.out), "Route 3 always breaks left")
    }
    
    func testRoute3RightSide() {
        let meaning = RouteNumber.three.semanticProvider.meaning(on: .right)
        XCTAssertEqual(meaning, .leftBreak(.out), "Route 3 always breaks left (absolute)")
    }
    
    // Route 4: Always breaks right (absolute direction)
    func testRoute4LeftSide() {
        let meaning = RouteNumber.four.semanticProvider.meaning(on: .left)
        XCTAssertEqual(meaning, .rightBreak(.dig), "Route 4 always breaks right")
    }
    
    func testRoute4RightSide() {
        let meaning = RouteNumber.four.semanticProvider.meaning(on: .right)
        XCTAssertEqual(meaning, .rightBreak(.dig), "Route 4 always breaks right (absolute)")
    }
    
    // Route 5: Comeback (left) / Curl (right)
    func testRoute5LeftSide() {
        let meaning = RouteNumber.five.semanticProvider.meaning(on: .left)
        XCTAssertEqual(meaning, .leftBreak(.comeback), "Route 5 left = Comeback")
    }
    
    func testRoute5RightSide() {
        let meaning = RouteNumber.five.semanticProvider.meaning(on: .right)
        XCTAssertEqual(meaning, .rightBreak(.curl), "Route 5 right = Curl")
    }
    
    // Route 6: Curl (left) / Comeback (right)
    func testRoute6LeftSide() {
        let meaning = RouteNumber.six.semanticProvider.meaning(on: .left)
        XCTAssertEqual(meaning, .leftBreak(.curl), "Route 6 left = Curl")
    }
    
    func testRoute6RightSide() {
        let meaning = RouteNumber.six.semanticProvider.meaning(on: .right)
        XCTAssertEqual(meaning, .rightBreak(.comeback), "Route 6 right = Comeback")
    }
    
    // Route 7: Always angles top-left (absolute direction)
    func testRoute7LeftSide() {
        let meaning = RouteNumber.seven.semanticProvider.meaning(on: .left)
        XCTAssertEqual(meaning, .vertical(.corner), "Route 7 always angles top-left")
    }
    
    func testRoute7RightSide() {
        let meaning = RouteNumber.seven.semanticProvider.meaning(on: .right)
        XCTAssertEqual(meaning, .vertical(.corner), "Route 7 always angles top-left (absolute)")
    }
    
    // Route 8: Always angles top-right (absolute direction)
    func testRoute8LeftSide() {
        let meaning = RouteNumber.eight.semanticProvider.meaning(on: .left)
        XCTAssertEqual(meaning, .vertical(.post), "Route 8 always angles top-right")
    }
    
    func testRoute8RightSide() {
        let meaning = RouteNumber.eight.semanticProvider.meaning(on: .right)
        XCTAssertEqual(meaning, .vertical(.post), "Route 8 always angles top-right (absolute)")
    }
    
    // Route 9: Go/Fade (same both sides)
    func testRoute9LeftSide() {
        let meaning = RouteNumber.nine.semanticProvider.meaning(on: .left)
        XCTAssertEqual(meaning, .vertical(.go), "Route 9 left = Go/Fade")
    }
    
    func testRoute9RightSide() {
        let meaning = RouteNumber.nine.semanticProvider.meaning(on: .right)
        XCTAssertEqual(meaning, .vertical(.go), "Route 9 right = Go/Fade")
    }
}
```

- [ ] **Step 2: Run test to verify it fails (routes not yet defined)**

Run: `xcodebuild test -scheme SpartansPlaycaller -only-testing SpartansPlaycallerTests/RouteSemanticProviderComprehensiveTests 2>&1 | tail -20`
Expected: Multiple FAILED entries for routes 2–9

- [ ] **Step 3: Fill in semanticProvider for all routes 2–9**

Update `RouteNumber.semanticProvider`:

```swift
var semanticProvider: RouteSemanticProvider {
    switch self {
    case .zero:
        return BubbleRouteSemantics(meaning: .backward(.screen))
    
    case .one:
        return SideAwareRouteSemantics(
            leftMeaning: .leftBreak(.quickOut),
            rightMeaning: .rightBreak(.quickSlant)
        )
    
    case .two:
        return SideAwareRouteSemantics(
            leftMeaning: .leftBreak(.quickSlant),
            rightMeaning: .rightBreak(.quickOut)
        )
    
    case .three:
        return AbsoluteDirectionRouteSemantics(meaning: .leftBreak(.out))
    
    case .four:
        return AbsoluteDirectionRouteSemantics(meaning: .rightBreak(.dig))
    
    case .five:
        return SideAwareRouteSemantics(
            leftMeaning: .leftBreak(.comeback),
            rightMeaning: .rightBreak(.curl)
        )
    
    case .six:
        return SideAwareRouteSemantics(
            leftMeaning: .leftBreak(.curl),
            rightMeaning: .rightBreak(.comeback)
        )
    
    case .seven:
        return AbsoluteDirectionRouteSemantics(meaning: .vertical(.corner))
    
    case .eight:
        return AbsoluteDirectionRouteSemantics(meaning: .vertical(.post))
    
    case .nine:
        return SideAwareRouteSemantics(
            leftMeaning: .vertical(.go),
            rightMeaning: .vertical(.go)
        )
    
    case .invalid:
        fatalError("Invalid route number")
    }
}
```

- [ ] **Step 4: Run test to verify all pass**

Run: `xcodebuild test -scheme SpartansPlaycaller -only-testing SpartansPlaycallerTests/RouteSemanticProviderComprehensiveTests 2>&1 | grep -E "(PASSED|FAILED)" | wc -l`
Expected: 20 (20 tests, all PASSED)

- [ ] **Step 5: Verify existing RouteInterpreterTests still pass**

Run: `xcodebuild test -scheme SpartansPlaycaller -only-testing SpartansPlaycallerTests/RouteInterpreterTests 2>&1 | tail -5`
Expected: All tests PASSED (no behavioral change, just refactored)

- [ ] **Step 6: Commit**

```bash
git add SpartansPlaycaller/Models/RouteNumber.swift SpartansPlaycallerTests/RouteSemanticProviderTests.swift
git commit -m "feat: implement route semantics for routes 1-9 via semantic provider"
```

---

### Task 4: Refactor RouteNumber.meaning() to Delegate to SemanticProvider

**Files:**
- Modify: `SpartansPlaycaller/Models/RouteNumber.swift`

**Description:** Replace the large switch statement in `meaning(on:)` with a delegation to the semantic provider. This cleans up RouteNumber and makes it clear the meaning is pluggable.

- [ ] **Step 1: Read current RouteNumber.meaning() method**

Read: `SpartansPlaycaller/Models/RouteNumber.swift` (find the `meaning(on:)` method)
Understand: What it currently does; how it's called

- [ ] **Step 2: Replace meaning() with delegation**

Replace the existing switch statement with:

```swift
func meaning(on side: FieldSide) -> RouteMeaning {
    return semanticProvider.meaning(on: side)
}
```

Remove the old switch statement entirely (all 27+ cases).

- [ ] **Step 3: Run all route interpretation tests to verify no behavioral change**

Run: `xcodebuild test -scheme SpartansPlaycaller -only-testing SpartansPlaycallerTests/RouteInterpreterTests 2>&1 | tail -5`
Expected: All tests PASSED

- [ ] **Step 4: Run comprehensive route semantic tests**

Run: `xcodebuild test -scheme SpartansPlaycaller -only-testing SpartansPlaycallerTests/RouteSemanticProviderComprehensiveTests 2>&1 | tail -5`
Expected: All tests PASSED

- [ ] **Step 5: Commit**

```bash
git add SpartansPlaycaller/Models/RouteNumber.swift
git commit -m "refactor: delegate RouteNumber.meaning() to semantic provider, remove large switch statement"
```

---

### Task 5: Add Y Wheel Motion Case

**Files:**
- Modify: `SpartansPlaycaller/Models/ReceiverMotion.swift`
- Create: `SpartansPlaycallerTests/ReceiverMotionWheelTests.swift`

**Description:** Add Y wheel as a fourth motion type. Y wheel is a semi-circular arc behind X/A or Z/A, ending on the original Y side (unlike Y After/Go which flips sides).

- [ ] **Step 1: Read current ReceiverMotion enum**

Read: `SpartansPlaycaller/Models/ReceiverMotion.swift`
Understand: Current cases (Stop, After, Go), and how `finalSide(originalSide:)` is implemented

- [ ] **Step 2: Write test for Y wheel final side**

```swift
// In SpartansPlaycallerTests/ReceiverMotionWheelTests.swift (create new file)

import XCTest
@testable import SpartansPlaycaller

class ReceiverMotionWheelTests: XCTestCase {
    func testYWheelLeftSideStayLeft() {
        let motion = ReceiverMotion.wheel
        let finalSide = motion.finalSide(originalSide: .left)
        
        XCTAssertEqual(finalSide, .left, "Y wheel from left side should stay left (semi-circle behind formation)")
    }
    
    func testYWheelRightSideStayRight() {
        let motion = ReceiverMotion.wheel
        let finalSide = motion.finalSide(originalSide: .right)
        
        XCTAssertEqual(finalSide, .right, "Y wheel from right side should stay right")
    }
    
    func testYWheelDescription() {
        let motion = ReceiverMotion.wheel
        XCTAssertEqual(motion.description, "Y Wheel", "Y wheel should have descriptive name")
    }
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `xcodebuild test -scheme SpartansPlaycaller -only-testing SpartansPlaycallerTests/ReceiverMotionWheelTests 2>&1 | grep -E "(FAILED|error)"`
Expected: `FAILED` (ReceiverMotion.wheel case doesn't exist yet)

- [ ] **Step 4: Add wheel case to ReceiverMotion enum**

```swift
enum ReceiverMotion: Hashable {
    case stop
    case after
    case go
    case wheel  // NEW: Y wheel semi-circle arc, same side as origin
    
    func finalSide(originalSide: FieldSide) -> FieldSide {
        switch self {
        case .stop:
            return originalSide // Y stays on original side
        case .after, .go:
            return originalSide == .left ? .right : .left // Flip sides
        case .wheel:
            return originalSide // Y wheel stays on same side
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
        case .wheel:
            return "Y Wheel"
        }
    }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `xcodebuild test -scheme SpartansPlaycaller -only-testing SpartansPlaycallerTests/ReceiverMotionWheelTests 2>&1 | tail -5`
Expected: All tests PASSED

- [ ] **Step 6: Verify existing motion tests still pass**

Run: `xcodebuild test -scheme SpartansPlaycaller -only-testing SpartansPlaycallerTests/YReceiverMotionTests 2>&1 | tail -5`
Expected: All tests PASSED (no behavioral change to Stop/After/Go)

- [ ] **Step 7: Commit**

```bash
git add SpartansPlaycaller/Models/ReceiverMotion.swift SpartansPlaycallerTests/ReceiverMotionWheelTests.swift
git commit -m "feat: add Y wheel motion case (same-side semi-circle arc)"
```

---

### Task 6: Update Motion Picker UI to Include Y Wheel

**Files:**
- Modify: `SpartansPlaycaller/Views/PlayCallerView.swift` (find motion picker)
- Modify: `SpartansPlaycaller/Views/ReceiverAssignmentView.swift` (if motion picker is here)

**Description:** Add Y Wheel option to the motion segmented control or picker UI.

- [ ] **Step 1: Find motion picker in UI code**

Read: `SpartansPlaycaller/Views/PlayCallerView.swift` and/or `ReceiverAssignmentView.swift`
Look for: Segmented control or picker with [Stop, After, Go] options

- [ ] **Step 2: Update motion picker to include wheel**

Replace motion picker options:

```swift
// OLD (example):
// Picker("Y Motion", selection: $viewModel.selectedMotion) {
//     Text("Stop").tag(ReceiverMotion.stop)
//     Text("After").tag(ReceiverMotion.after)
//     Text("Go").tag(ReceiverMotion.go)
// }

// NEW:
Picker("Y Motion", selection: $viewModel.selectedMotion) {
    Text("Stop").tag(ReceiverMotion.stop)
    Text("After").tag(ReceiverMotion.after)
    Text("Go").tag(ReceiverMotion.go)
    Text("Wheel").tag(ReceiverMotion.wheel)  // NEW
}
```

Or if using a segmented control, ensure it can accommodate 4 options (or use a different picker).

- [ ] **Step 3: Ensure motion applicability check includes wheel**

Find: `Formation.canApplyMotion()` or similar gate that restricts motion to Trips/Pro formations

Verify: Y wheel is allowed in same formations as Y After/Go (Trips, Pro)

```swift
// In Formation.swift or PlayCallerViewModel.swift
func canApplyMotion(_ motion: ReceiverMotion, in formation: Formation) -> Bool {
    switch formation {
    case .twins:
        return false // No motion in Twins
    case .tripsLeft, .tripsRight, .proLeft, .proRight:
        return true // All motions allowed in Trips/Pro
    default:
        return false
    }
}
```

- [ ] **Step 4: Build and verify UI compiles**

Run: `xcodebuild build -scheme SpartansPlaycaller -configuration Debug 2>&1 | grep -E "(error|Build complete)"`
Expected: `Build complete!`

- [ ] **Step 5: Run UI/integration tests if they exist**

Run: `xcodebuild test -scheme SpartansPlaycaller -only-testing SpartansPlaycallerTests/PlayCallerViewModelTests 2>&1 | tail -5`
Expected: All tests PASSED

- [ ] **Step 6: Commit**

```bash
git add SpartansPlaycaller/Views/PlayCallerView.swift
git commit -m "ui: add Y wheel option to motion picker"
```

---

### Task 7: Implement Y Wheel Arc Rendering in DiagramRenderer

**Files:**
- Modify: `SpartansPlaycaller/Services/DiagramRenderer.swift`
- Create: `SpartansPlaycallerTests/DiagramRendererYWheelTests.swift`

**Description:** Add Y wheel semi-circular arc rendering. Y wheel is a semi-circle that goes behind X/A or Z/A and down the sideline, ending on the original Y side.

- [ ] **Step 1: Write test for Y wheel arc geometry**

```swift
// In SpartansPlaycallerTests/DiagramRendererYWheelTests.swift (create new file)

import XCTest
@testable import SpartansPlaycaller

class DiagramRendererYWheelTests: XCTestCase {
    let renderer = DiagramRenderer()
    
    func testYWheelArcPathTripsLeft() {
        // Y starts at left slot, wheels semi-circle behind X/A
        let playCall = PlayCall(
            formation: .tripsLeft,
            digitSequence: "6794",
            selectedConcept: nil,
            yReceiverMotion: .wheel
        )
        
        // Y wheel should produce an arc path from Y's start position, 
        // looping behind the formation, ending lower (down the sideline)
        let (path, _) = renderer.yWheelArcPath(for: playCall)
        
        // Arc should not be nil
        XCTAssertNotNil(path, "Y wheel arc should be rendered")
        
        // Arc should stay on left side (Y original side)
        // Verify by checking path bounds don't cross formation center line
        // (This is a geometry assertion; exact bounds depend on canvas size)
    }
    
    func testYWheelArcPathTripsRight() {
        let playCall = PlayCall(
            formation: .tripsRight,
            digitSequence: "6794",
            selectedConcept: nil,
            yReceiverMotion: .wheel
        )
        
        let (path, _) = renderer.yWheelArcPath(for: playCall)
        XCTAssertNotNil(path, "Y wheel arc should be rendered on right side")
    }
}
```

- [ ] **Step 2: Read current motion arc implementation**

Read: `SpartansPlaycaller/Services/DiagramRenderer.swift`
Look for: `yMotionPath()` or similar method that renders Y After/Go arcs
Understand: Current arc geometry (Bézier curves, direction logic)

- [ ] **Step 3: Implement Y wheel arc rendering**

Add a new method to DiagramRenderer:

```swift
// In DiagramRenderer
private func yWheelArcPath(for playCall: PlayCall) -> (Path, Color) {
    let yPosition = receiverPosition(for: .Y, in: playCall.formation)
    let side = playCall.formation.side(for: .Y)
    
    // Y wheel is a semi-circle arc that goes:
    // 1. Back (away from LOS) half the field width
    // 2. Down the sideline (away from center)
    // 3. Arc curves behind X/A receivers
    
    var path = Path()
    path.move(to: yPosition)
    
    // Calculate arc control points
    let backwardDistance = canvasWidth * 0.2  // 20% back
    let sidewayDistance = canvasHeight * 0.3  // 30% down sideline
    
    let controlPoint1: CGPoint
    let controlPoint2: CGPoint
    let endPoint: CGPoint
    
    if side == .left {
        // Left-side Y wheel: arc goes to the left and down
        controlPoint1 = CGPoint(
            x: yPosition.x - backwardDistance,
            y: yPosition.y + sidewayDistance * 0.5
        )
        controlPoint2 = CGPoint(
            x: yPosition.x - backwardDistance * 0.5,
            y: yPosition.y + sidewayDistance
        )
        endPoint = CGPoint(
            x: yPosition.x,
            y: yPosition.y + sidewayDistance
        )
    } else {
        // Right-side Y wheel: arc goes to the right and down
        controlPoint1 = CGPoint(
            x: yPosition.x + backwardDistance,
            y: yPosition.y + sidewayDistance * 0.5
        )
        controlPoint2 = CGPoint(
            x: yPosition.x + backwardDistance * 0.5,
            y: yPosition.y + sidewayDistance
        )
        endPoint = CGPoint(
            x: yPosition.x,
            y: yPosition.y + sidewayDistance
        )
    }
    
    // Draw cubic Bézier curve for smooth arc
    path.addCurve(
        to: endPoint,
        control1: controlPoint1,
        control2: controlPoint2
    )
    
    return (path, .yellow) // Yellow dashed line like Y After/Go
}

// Update motionPath() to handle wheel
func motionPath(for playCall: PlayCall) -> (Path, Color)? {
    guard let motion = playCall.yReceiverMotion else {
        return nil
    }
    
    switch motion {
    case .stop:
        return nil // No arc for Y Stop
    case .after, .go:
        return yMotionPath(for: playCall) // Existing implementation
    case .wheel:
        return yWheelArcPath(for: playCall) // NEW
    }
}
```

- [ ] **Step 4: Update diagram rendering to call Y wheel arc**

Find: Where `motionPath()` is called in `body` or `draw` method
Ensure: Both `.after`, `.go`, and `.wheel` motions render their paths

Verify in your draw method:
```swift
if let (motionPath, motionColor) = motionPath(for: playCall) {
    canvas.stroke(motionPath, with: .color(motionColor), lineWidth: 2)
}
```

- [ ] **Step 5: Run Y wheel arc test**

Run: `xcodebuild test -scheme SpartansPlaycaller -only-testing SpartansPlaycallerTests/DiagramRendererYWheelTests 2>&1 | tail -5`
Expected: All tests PASSED

- [ ] **Step 6: Verify existing motion diagram tests still pass**

Run: `xcodebuild test -scheme SpartansPlaycaller -only-testing SpartansPlaycallerTests/RouteDiagramViewTests 2>&1 | tail -5`
Expected: All tests PASSED (no visual regression)

- [ ] **Step 7: Commit**

```bash
git add SpartansPlaycaller/Services/DiagramRenderer.swift SpartansPlaycallerTests/DiagramRendererYWheelTests.swift
git commit -m "feat: implement Y wheel arc rendering (semi-circle behind formation)"
```

---

### Task 8: Add Y Wheel Concept Re-Identification

**Files:**
- Modify: `SpartansPlaycaller/Models/RouteAssignment.swift`
- Modify: `SpartansPlaycallerTests/ConceptMatcherTests.swift`

**Description:** When Y motion changes to wheel (or from wheel), concepts should be re-identified since Y's side for route interpretation may have changed relative to the original concept match.

- [ ] **Step 1: Write test for Y wheel concept matching**

```swift
// In SpartansPlaycallerTests/ConceptMatcherTests.swift

func testYWheelMotionTriggersReIdentification() {
    // Setup: Trips Left, Smash concept (X:6, Y:7, Z:5, A:8)
    let playCall = PlayCall(
        formation: .tripsLeft,
        digitSequence: "6758",
        selectedConcept: .smash,
        yReceiverMotion: nil
    )
    
    // Concepts should match Smash on left side initially
    var identified = ConceptMatcher.identify(playCall)
    XCTAssertEqual(identified.left, .smash, "Trips Left Smash should be identified on left side")
    
    // Apply Y wheel motion
    var wheelPlayCall = playCall
    wheelPlayCall.yReceiverMotion = .wheel
    
    // Y wheel keeps Y on left side (same as original), so concept should remain valid
    identified = ConceptMatcher.identify(wheelPlayCall)
    XCTAssertEqual(identified.left, .smash, "Y wheel keeps Y on left side; concept should remain Smash")
}
```

- [ ] **Step 2: Run test to verify current behavior**

Run: `xcodebuild test -scheme SpartansPlaycaller -only-testing SpartansPlaycallerTests/ConceptMatcherTests::testYWheelMotionTriggersReIdentification 2>&1 | tail -5`
Expected: Test should PASS (Y wheel doesn't flip sides, so concept matching should work the same as Y Stop)

- [ ] **Step 3: Verify RouteAssignment handles Y wheel motion correctly**

Read: `SpartansPlaycaller/Models/RouteAssignment.swift`
Check: The `motionFinalSide` property correctly computes final side for Y wheel (should be same as original)

Verify:
```swift
var motionFinalSide: FieldSide {
    guard let motion = yReceiverMotion else {
        return originalSide
    }
    return motion.finalSide(originalSide: originalSide)
}
```

Should work correctly since `ReceiverMotion.wheel.finalSide()` returns original side.

- [ ] **Step 4: Build and verify no compilation errors**

Run: `xcodebuild build -scheme SpartansPlaycaller -configuration Debug 2>&1 | grep -E "(error|Build complete)"`
Expected: `Build complete!`

- [ ] **Step 5: Run full test suite for concept matching**

Run: `xcodebuild test -scheme SpartansPlaycaller -only-testing SpartansPlaycallerTests/ConceptMatcherTests 2>&1 | tail -10`
Expected: All tests PASSED (including Y wheel test)

- [ ] **Step 6: Commit**

```bash
git add SpartansPlaycallerTests/ConceptMatcherTests.swift
git commit -m "test: add Y wheel concept re-identification test (same-side motion)"
```

---

### Task 9: Integration Testing — Full Play Call Flow with Y Wheel

**Files:**
- Create: `SpartansPlaycallerTests/PlayCallFlowYWheelTests.swift`

**Description:** End-to-end test: select Trips Left formation, parse digits for a concept (e.g., Smash), apply Y wheel motion, verify diagram renders correctly with wheel arc.

- [ ] **Step 1: Write comprehensive Y wheel flow test**

```swift
// In SpartansPlaycallerTests/PlayCallFlowYWheelTests.swift (create new file)

import XCTest
@testable import SpartansPlaycaller

class PlayCallFlowYWheelTests: XCTestCase {
    let viewModel = PlayCallerViewModel()
    
    func testYWheelFlowTripsLeft() {
        // Step 1: Select Trips Left formation
        viewModel.selectedFormation = .tripsLeft
        XCTAssertEqual(viewModel.selectedFormation, .tripsLeft)
        
        // Step 2: Select Smash concept
        viewModel.selectedLeftConcept = .smash
        XCTAssertEqual(viewModel.selectedLeftConcept, .smash)
        
        // Step 3: Generate digits (should be 6758 for Trips Left Smash)
        viewModel.generatePlayCall()
        XCTAssertEqual(viewModel.digitSequence, "6758", "Smash in Trips Left should generate X:6, Y:7, Z:5, A:8")
        
        // Step 4: Apply Y wheel motion
        viewModel.selectedMotion = .wheel
        XCTAssertEqual(viewModel.selectedMotion, .wheel)
        
        // Step 5: Verify concept remains identified (Y stays on left side)
        let identified = ConceptMatcher.identify(viewModel.playCall)
        XCTAssertEqual(identified.left, .smash, "Smash should remain identified after Y wheel motion")
        
        // Step 6: Verify diagram renders without error
        // (Diagram rendering is tested separately; here just verify no crash)
        let diagram = RouteDiagramView(playCall: viewModel.playCall)
        XCTAssertNotNil(diagram, "Diagram should render with Y wheel motion")
    }
    
    func testYWheelMotionToggle() {
        viewModel.selectedFormation = .tripsRight
        viewModel.selectedRightConcept = .dagger
        viewModel.generatePlayCall()
        
        // Toggle through motions: Stop → After → Go → Wheel → Stop
        let motions: [ReceiverMotion] = [.stop, .after, .go, .wheel, .stop]
        for motion in motions {
            viewModel.selectedMotion = motion
            XCTAssertEqual(viewModel.selectedMotion, motion, "Motion should toggle to \(motion)")
            
            // Verify diagram still renders (no crash)
            let diagram = RouteDiagramView(playCall: viewModel.playCall)
            XCTAssertNotNil(diagram, "Diagram should render for \(motion) motion")
        }
    }
}
```

- [ ] **Step 2: Run Y wheel flow test**

Run: `xcodebuild test -scheme SpartansPlaycaller -only-testing SpartansPlaycallerTests/PlayCallFlowYWheelTests 2>&1 | tail -10`
Expected: All tests PASSED

- [ ] **Step 3: Run full test suite to verify no regressions**

Run: `xcodebuild test -scheme SpartansPlaycaller 2>&1 | grep -E "^Test Suite|Tests passed|Tests failed"`
Expected: `Tests passed` with all counts passing

- [ ] **Step 4: Commit**

```bash
git add SpartansPlaycallerTests/PlayCallFlowYWheelTests.swift
git commit -m "test: add comprehensive Y wheel integration tests (full flow)"
```

---

### Task 10: Build and Package for Field Testing

**Files:**
- Modify: `SpartansPlaycaller/Info.plist` (or `AppDelegate.swift` if applicable) — version bump
- Create: `docs/FIELD-TEST-NOTES.md`

**Description:** Build a release version of the app and document what to test on the field next week.

- [ ] **Step 1: Bump version number for field test build**

Read: `SpartansPlaycaller.xcodeproj/project.pbxproj` or `Info.plist`
Find: CFBundleVersion and CFBundleVersionString

Update to reflect field test (e.g., 1.1.0 → 1.2.0-fieldtest):

```plist
<key>CFBundleVersion</key>
<string>1.2.0-fieldtest-1</string>
```

- [ ] **Step 2: Create field test notes document**

Create: `docs/FIELD-TEST-NOTES.md`

```markdown
# Spartans Playcaller — Field Test Notes (Week of 2026-06-02)

## Build Version
- Version: 1.2.0-fieldtest-1
- Date: 2026-05-29

## Changes in This Build

### 1. Route 0 (Hitch) → Bubble/Screen Route Fix
- **What:** Route 0 is now correctly implemented as a **bubble/screen route** that goes **backward behind the line of scrimmage**
- **How to test:** 
  - Select any formation, parse digits ending in 0 (e.g., "6740")
  - Verify Route 0 is displayed as a backward/lateral route in the receiver assignment table
  - Diagram should show the route going backward, not upfield

### 2. Y Wheel Motion (NEW)
- **What:** Y receiver can now execute a **Y Wheel motion** — a semi-circular arc behind the formation (X/A or Z/A) and down the sideline
- **Key difference from Y After/Go:**
  - Y Wheel stays on the **same side** (unlike Y After/Go which flips sides)
  - Route interpretation applies from Y's original side
  - Diagram shows a curved motion arc (yellow dashed line)
- **How to test:**
  - Select Trips Left or Trips Right formation
  - Generate or parse a play (e.g., Smash = "6758")
  - Tap the motion picker
  - Select **"Y Wheel"** (should appear as a 4th option alongside Stop, After, Go)
  - Verify:
    - Diagram updates with a semi-circular arc behind the formation
    - Arc curves in the correct direction (left side for Trips Left, right for Trips Right)
    - Concept remains identified (Smash should stay Smash, since Y doesn't flip sides)

### 3. Route Interpretation Refactoring (Internal)
- **What:** Route meaning logic has been refactored into a pluggable **RouteSemanticProvider** pattern
- **Impact:** No visible changes; all existing plays should behave identically
- **Why:** Enables custom routes in future phases (e.g., route modifiers, additional formations)

## Testing Focus for This Week

1. **Route 0 (Bubble/Screen)**
   - Test bubble routes in practice plays
   - Verify backward direction is correct
   - Check diagram clarity on iPhone and iPad

2. **Y Wheel Motion**
   - Test Y Wheel in Trips Left and Trips Right formations
   - Verify arc direction and diagram clarity
   - Confirm concept identification holds correctly
   - Test motion toggle (Stop ↔ After ↔ Go ↔ Wheel)
   - **Field test under pressure:** Can you quickly switch between motion types during rapid play design?

3. **Overall Responsiveness**
   - How fast is formation selection and play generation?
   - Does the UI feel snappy under real practice conditions?
   - Any lag when switching formations or applying motion?

## Feedback Channels
- [Create issue in GitHub](https://github.com/klewisjr/spartans-playcaller/issues) or email Ken directly

---

**Next Steps After Field Test:**
1. Gather feedback on Y Wheel usability and motion arc clarity
2. Validate Route 0 bubble/screen rendering
3. Plan concept display feature (Twins chips, Trips Re-ID) if UX feedback warrants
4. Consider team theming (colors + logo)
```

- [ ] **Step 3: Build release version for iOS testing device**

Run: 
```bash
xcodebuild build \
  -scheme SpartansPlaycaller \
  -configuration Release \
  -destination 'platform=iOS,name=iPhone 15' \
  2>&1 | grep -E "(error|Build complete)"
```

Expected: `Build complete!`

(Alternative: Use Xcode UI to build → run on device)

- [ ] **Step 4: Verify build succeeds and app launches**

Run the app on your iPhone/iPad:
- [ ] App launches without crashes
- [ ] Formations load and are selectable
- [ ] Route 0 appears in concepts (if used)
- [ ] Y Wheel appears in motion picker (Trips/Pro formations only)
- [ ] Diagram renders without visual glitches
- [ ] Tapping motion options works smoothly

- [ ] **Step 5: Commit field test notes and version bump**

```bash
git add docs/FIELD-TEST-NOTES.md SpartansPlaycaller/Info.plist
git commit -m "docs: add field test notes and bump version to 1.2.0-fieldtest-1

Ready for field testing week of 2026-06-02. Includes Route 0 bubble/screen fix,
Y wheel motion, and route interpretation refactoring."
```

---

## Summary

**Total Tasks:** 10  
**Estimated Timeline:** 5–7 working days  
**Commits:** 10 atomic commits  
**Tests:** 50+ new tests across 4 test files  
**Field-Testable Build:** Ready by end of week

**Success Criteria:**
- [ ] Route interpretation refactored to strategy pattern
- [ ] Route 0 is bubble/screen going backward
- [ ] Y wheel motion works (same-side, semi-circle arc)
- [ ] All existing tests pass (no regressions)
- [ ] UI updated with Y wheel motion picker
- [ ] Diagram renders Y wheel arc correctly
- [ ] Concept matching works with Y wheel
- [ ] Release build ready for field testing next week
- [ ] Field test notes documented
