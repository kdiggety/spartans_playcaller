# Y Receiver Motion Feature — Implementation Plan

**Spartans Playcaller iOS App**  
**iOS 17+, SwiftUI, MVVM**  
**Created:** 2026-05-27

---

## Executive Summary

This plan covers the design and implementation of Y receiver motion (Y Stop, Y After, Y Go) for the Spartans Playcaller iOS app. Coaches can optionally apply motion to the Y receiver post-parse, which changes Y's field side assignment and triggers re-evaluation of route concepts. The feature includes:

- **ReceiverMotion enum** (3 motion types, optional)
- **Motion state in ViewModel** (separate from PlayCall to preserve original)
- **Motion picker UI** in ReceiverAssignmentView
- **Side-flip logic** in RouteInterpreter to compute Y's final side after motion
- **Concept re-matching** when motion changes (side-specific concepts)
- **Diagram rendering** of dashed motion arcs from initial to final position
- **Concept badge display** showing left-side and right-side identified concepts
- **Formation validation** (motion only valid in Trips formations)

---

## Phased Implementation Plan

### Phase 1: Data Model — ReceiverMotion Enum & RouteAssignment Extension

**Objective:** Define ReceiverMotion type and extend RouteAssignment to carry motion state and calculated final side.

**Dependencies:** None

**Files:**
- `Models/ReceiverMotion.swift` (new)
- `Models/RouteAssignment.swift` (modify)

**Tasks:**

1. **Create `Models/ReceiverMotion.swift`**
   - Enum with cases: `.none`, `.stop`, `.after`, `.go`
   - Optional raw value for UI display ("Y Stop", "Y After", "Y Go", or "None")
   - Computed property `displayName` for coach-facing labels
   - Computed property `finalSide(initialSide:FieldSide, formation:Formation) -> FieldSide`
     - **Y Stop:** Returns `initialSide` (no change, Y stays on same side)
     - **Y After:** Returns opposite side (left ↔ right)
     - **Y Go:** Returns opposite side (left ↔ right)
     - **.none:** Returns `initialSide` (no change)
   
   **Motion Rules (from feature spec):**
   - `Y Stop`: Y stays on SAME side (for route interpretation and concept matching)
   - `Y After`: Y moves to OPPOSITE side (for route interpretation and concept matching)
   - `Y Go`: Y moves to OPPOSITE side (for route interpretation and concept matching)
   - `.none`: No motion, Y stays in base position
   
   **Note:** Y Stop keeps Y on the same side; Y After and Y Go move Y to the opposite side. This distinction is important for concept matching later.

2. **Extend `Models/RouteAssignment.swift`**
   - Add property: `motion: ReceiverMotion?` (optional, only non-nil for Y receiver)
   - Add property: `motionFinalSide: FieldSide?` (calculated from motion type + formation + initial side)
   - Add initializer helper or computed property to calculate `motionFinalSide`
   - Keep existing properties; motion is additive
   
   **Ripple impact:** None at this stage (RouteAssignment is a value type; consumers will receive updated version via ViewModel).

**Testing Surface:**
- Unit test: `ReceiverMotion.finalSide(.left, .stop)` returns `.left` (Y Stop stays same side)
- Unit test: `ReceiverMotion.finalSide(.left, .after)` returns `.right` (Y After flips to opposite)
- Unit test: `ReceiverMotion.finalSide(.left, .go)` returns `.right` (Y Go flips to opposite)
- Unit test: `ReceiverMotion.finalSide(.right, .stop)` returns `.right` (Y Stop stays same side)
- Unit test: `ReceiverMotion.finalSide(.right, .after)` returns `.left` (Y After flips to opposite)
- Unit test: `ReceiverMotion.finalSide(.right, .go)` returns `.left` (Y Go flips to opposite)
- SwiftUI Preview: Create a small mock assignment with motion and verify it renders correctly in list

**Estimated LOE:** 1–2 hours (straightforward enum + calculated property)

**Done-when:**
- `ReceiverMotion.swift` compiles and tests pass
- `RouteAssignment.swift` updated; no build errors
- `motionFinalSide` correctly computes left/right based on motion type and formation

---

### Phase 2: ViewModel Motion State Management

**Objective:** Add motion state to PlayCallerViewModel; propagate to diagram and concept matching.

**Dependencies:** Phase 1

**Files:**
- `ViewModels/PlayCallerViewModel.swift` (modify)

**Tasks:**

1. **Add Motion State Properties to PlayCallerViewModel**
   - `@Published var yMotion: ReceiverMotion = .none` — current motion selection
   - `@Published var currentPlayCallWithMotion: PlayCall?` — derived state (base PlayCall + motion applied)
   - `@Published var leftSideConcept: RouteConcept?` — re-identified concept for left-side group after motion
   - `@Published var rightSideConcept: RouteConcept?` — re-identified concept for right-side group after motion
   
   **Design Decision:** Motion is NOT stored in PlayCall; instead, it's ViewModel state that transforms the rendered PlayCall. This preserves the original parsed/generated PlayCall for reference and allows coaches to toggle motion without re-parsing.

2. **Implement `applyMotion()` Method**
   ```swift
   private func applyMotion() {
       guard let playCall = currentPlayCall else {
           currentPlayCallWithMotion = nil
           leftSideConcept = nil
           rightSideConcept = nil
           return
       }
       
       // Create new RouteAssignments with motion applied to Y
       let updatedAssignments = playCall.assignments.map { assignment -> RouteAssignment in
           if assignment.receiver == .Y && yMotion != .none {
               // Create new assignment with motion; RouteAssignment initializer
               // calculates motionFinalSide internally
               var updated = assignment
               updated.motion = yMotion
               return updated
           }
           return assignment
       }
       
       // Create derived PlayCall (concept re-evaluated below)
       currentPlayCallWithMotion = PlayCall(
           formation: playCall.formation,
           routeDigits: playCall.routeDigits,
           assignments: updatedAssignments,
           concept: playCall.concept  // Keep original concept for reference
       )
       
       // Re-match concepts for left and right sides independently
       reidentifyConceptsBySide(assignments: updatedAssignments, formation: playCall.formation)
   }
   
   private func reidentifyConceptsBySide(assignments: [RouteAssignment], formation: Formation) {
       // Use ConceptMatcher to identify concepts separately per side
       // (matcher interface changes per Phase 3)
       // Group receivers by FINAL side after motion
       let leftAssignments = assignments.filter { 
           let finalSide = $0.motionFinalSide ?? $0.side
           return finalSide == .left 
       }
       let rightAssignments = assignments.filter { 
           let finalSide = $0.motionFinalSide ?? $0.side
           return finalSide == .right 
       }
       
       leftSideConcept = interpreter.identifyForSide(.left, assignments: leftAssignments, formation: formation)
       rightSideConcept = interpreter.identifyForSide(.right, assignments: rightAssignments, formation: formation)
   }
   ```

3. **Add Motion Change Handler**
   ```swift
   func motionChanged(_ newMotion: ReceiverMotion) {
       // Only allow motion in Trips formations
       guard currentPlayCall?.formation == .tripsLeft || currentPlayCall?.formation == .tripsRight else {
           errorMessage = "Motion only available in Trips formations"
           yMotion = .none
           return
       }
       
       yMotion = newMotion
       applyMotion()
   }
   ```

4. **Validation: Enforce Trips-Only Constraint**
   - In `formationChanged()`, reset `yMotion` to `.none` if switching out of Trips
   - In `parseRouteDigits()` and `generateFromConcept()`, reset motion after generating new PlayCall

5. **Hook applyMotion() into parseRouteDigits()/generateFromConcept()**
   - After setting `currentPlayCall`, call `applyMotion()` to initialize derived state
   - This ensures `leftSideConcept` and `rightSideConcept` are always in sync

**Ripple impact:** 
- Views consume `currentPlayCallWithMotion` instead of `currentPlayCall` for rendering (diagram, assignment table)
- Views bind to `yMotion`, `leftSideConcept`, `rightSideConcept` for motion UI and concept badges
- Mock in previews: PlayCallerView needs test data with motion applied

**Testing Surface:**
- Unit test: `motionChanged(.stop)` in Trips Left formation updates `yMotion` and recalculates concepts
- Unit test: `motionChanged(.stop)` in Twins formation is rejected with error
- Unit test: `formationChanged()` from Trips Left to Twins resets `yMotion` to `.none`
- SwiftUI Preview: Show PlayCallerView with Trips Left, Smash concept, then apply Y Stop motion and verify concept badges update

**Estimated LOE:** 2–3 hours (state coordination, concept re-matching integration)

**Done-when:**
- `yMotion`, `currentPlayCallWithMotion`, `leftSideConcept`, `rightSideConcept` properties exist and compile
- `motionChanged()` handler works correctly
- Formation validation prevents invalid states
- Concepts re-identify when motion is applied (integration with Phase 3 code)

---

### Phase 3: Route Interpreter & Concept Matcher Updates

**Objective:** Extend RouteInterpreter and ConceptMatcher to handle side-aware concept identification after motion.

**Dependencies:** Phase 1, Phase 2 (partial)

**Files:**
- `Services/RouteInterpreter.swift` (modify)
- `Services/ConceptMatcher.swift` (modify)

**Tasks:**

1. **Extend RouteInterpreter with Side-Specific Identification**
   - Add new method: `identifyForSide(_ side: FieldSide, assignments: [RouteAssignment], formation: Formation) -> RouteConcept?`
   - This method filters assignments to only those on the requested side and matches concepts independently
   - Existing `identify()` remains for full-play concept matching (backward compatible)
   
   ```swift
   func identifyForSide(_ side: FieldSide, assignments: [RouteAssignment], formation: Formation) -> RouteConcept? {
       let sideAssignments = assignments.filter { 
           // Use final side if motion is applied; otherwise use base side
           let finalSide = $0.motionFinalSide ?? $0.side
           return finalSide == side
       }
       return matcher.identifyForSide(side, assignments: sideAssignments, formation: formation)
   }
   ```

2. **Extend ConceptMatcher with Side-Aware Matching**
   - Add new method: `identifyForSide(_ side: FieldSide, assignments: [RouteAssignment], formation: Formation) -> RouteConcept?`
   - Filter templates by formation AND side (use `FormationContext.conceptSide`)
   - Only match templates whose `formationContext` matches both the formation AND the side
   - Example: If side == .left and formation == .tripsLeft, only match templates with formationContext == .tripsLeft
   
   ```swift
   func identifyForSide(_ side: FieldSide, assignments: [RouteAssignment], formation: Formation) -> RouteConcept? {
       let routeMap = Dictionary(
           uniqueKeysWithValues: assignments.map { 
               ($0.receiver, $0.routeNumber) 
           }
       )
       
       let matchingTemplate = library.templates.first { template in
           // Match formation AND side context
           template.formationContext.matches(formation: formation) &&
           template.formationContext.conceptSide == side &&
           template.matches(assignments: routeMap)
       }
       
       return matchingTemplate?.concept
   }
   ```

3. **Y Final-Side Resolution in Interpretation**
   - RouteInterpreter creates RouteAssignments with base side (existing behavior)
   - Motion is ViewModel state, not part of interpretation:
     1. RouteInterpreter returns assignments with Y at base side
     2. ViewModel applies motion to assignments in `applyMotion()` (Phase 2)
     3. ViewModel computes final side using `motion.finalSide(initialSide: baseSide, formation: formation)`
     4. ViewModel stores final side in RouteAssignment.motionFinalSide for concept re-matching
   
   **Separation of concerns:**
   - RouteInterpreter: Parse routes, assign base sides (independent of motion)
   - ViewModel: Manage motion state, compute final sides, re-identify concepts (motion is display/analysis concern)
   - ConceptMatcher: Match templates to side-grouped receivers (agnostic to motion origin)

4. **Update RouteAssignment Creation in PlayCallParser**
   - Ensure RouteAssignment is initialized with `motion: nil` (will be set by ViewModel later)
   - No changes to parser logic; parser remains side-agnostic

**Ripple impact:**
- ConceptMatcher.identifyForSide() is called from ViewModel.reidentifyConceptsBySide()
- Existing identify() method is used for original concept identification (unchanged)
- Templates in ConceptLibrary already have FormationContext with side info; no library changes needed

**Testing Surface:**
- Unit test: `identifyForSide(.left, assignments: [tripsLeftAssignments], formation: .tripsLeft)` matches tripsLeft templates only
- Unit test: `identifyForSide(.right, assignments: [tripsLeftAssignments], formation: .tripsLeft)` returns nil (no right-side concept)
- Unit test: When Y moves to right side via Y Stop motion in Trips Left, right-side concept is identified for Y's new side
- Integration test: Parse "Trips Left 6794" → identify Smash on left; apply Y Stop motion → re-identify left and right concepts

**Estimated LOE:** 1.5–2 hours (mostly filtering and delegation; ConceptMatcher logic is already structured for this)

**Done-when:**
- `RouteInterpreter.identifyForSide()` exists and routes to ConceptMatcher
- `ConceptMatcher.identifyForSide()` correctly filters by side and formation
- Unit tests pass for all formation/side combinations
- Integration test shows concept re-identification after motion

---

### Phase 4: Motion UI — Motion Picker in ReceiverAssignmentView

**Objective:** Add motion picker UI allowing coaches to select Y motion (Stop, After, Go) post-parse.

**Dependencies:** Phase 1, Phase 2, Phase 3

**Files:**
- `Views/ReceiverAssignmentView.swift` (modify)
- `Views/MotionPickerView.swift` (new, optional sub-component)

**Tasks:**

1. **Update ReceiverAssignmentView Signature**
   - Change signature from `let assignments: [RouteAssignment]` to:
     ```swift
     let assignments: [RouteAssignment]
     @Binding var selectedMotion: ReceiverMotion
     let onMotionChange: (ReceiverMotion) -> Void
     let isMotionEnabled: Bool  // true in Trips formations only
     ```

2. **Add Motion Row Above/Within Assignment Table**
   - Add a section header row: "Y MOTION" (only displayed if isMotionEnabled == true)
   - Add a segmented picker or button group: ".none", ".stop", ".after", ".go"
   - Bind to `selectedMotion`
   - Call `onMotionChange()` when user selects
   - Disable picker if isMotionEnabled == false
   - Example UI:
     ```
     ┌─────────────────────────────┐
     │ Y MOTION                    │
     │ [None] [Stop] [After] [Go] │
     └─────────────────────────────┘
     ┌─────────────────────────────┐
     │ WR  #  Side   Route          │
     │ X   6  Left   Curl           │
     │ Y   7  Left*  Corner (→Right)│  * indicates motion applied
     │ Z   9  Right  Go             │
     │ A   9  Right  Go             │
     └─────────────────────────────┘
     ```

3. **Visual Feedback for Motion Application**
   - When motion is applied to Y, highlight Y's row or add a badge (e.g., "→ Right" indicator)
   - Update Y's side column to show both base and final side: "Left → Right" or just final side with asterisk
   - Update meaning if final side changes the route interpretation (e.g., if Y's route number is 1, meaning changes from Quick Out to Quick Slant)

4. **Handle Motion Disable/Enable on Formation Change**
   - When formation changes away from Trips: disable motion picker, reset `selectedMotion` to `.none`
   - When formation changes to Trips: enable motion picker

**Ripple impact:**
- PlayCallerView must pass motion state and handler to ReceiverAssignmentView
- ReceiverAssignmentView needs access to current formation to determine isMotionEnabled

**Testing Surface:**
- SwiftUI Preview: ReceiverAssignmentView with Trips Left formation, motion enabled, showing Y motion picker
- SwiftUI Preview: ReceiverAssignmentView with Twins formation, motion disabled
- Interaction test: Tapping "Stop" motion updates selectedMotion and calls onMotionChange callback
- Visual test: Y's row highlights or shows side indicator when motion is applied

**Estimated LOE:** 1.5–2 hours (UI layout, state binding, preview refinement)

**Done-when:**
- Motion picker UI renders correctly in Trips formations
- Motion picker is disabled in Twins formation
- Selecting motion calls onMotionChange handler
- Y's side/meaning updates when motion is applied
- SwiftUI Preview shows correct behavior

---

### Phase 5: Diagram Rendering — Motion Arcs

**Objective:** Extend DiagramRenderer and RouteDiagramView to draw dashed motion lines from Y's initial position to final position.

**Dependencies:** Phase 1, Phase 2, Phase 3, Phase 4

**Files:**
- `Services/DiagramRenderer.swift` (modify)
- `Views/RouteDiagramView.swift` (modify)

**Tasks:**

1. **Add Motion Path Computation in DiagramRenderer**
   - New method: `motionPath(for receiver: Receiver, initialSide: FieldSide, finalSide: FieldSide, initialPosition: CGPoint, finalPosition: CGPoint, motion: ReceiverMotion, config: DiagramConfig) -> [CGPoint]`
   - Returns a smooth arc or path from initialPosition to finalPosition
   - Arc geometry depends on motion type:
     - `Y Stop`: Arc curves inward (convex toward field center) — Y stays same side, position shift only
     - `Y After`: Arc curves outward (convex away from field center) — Y moves to opposite side
     - `Y Go`: Arc curves outward (convex away from field center) — Y moves to opposite side
   - Use quadratic Bézier curves for smooth arcs
   - **Side-change note:** Y Stop does NOT change side (stays same-side receiver group). Y After/Go DO change sides (move to opposite side group).
   
   ```swift
   func motionPath(for receiver: Receiver, motion: ReceiverMotion, from: CGPoint, to: CGPoint, config: DiagramConfig) -> [CGPoint] {
       guard motion != .none else { return [] }
       
       // Compute control point for arc curvature
       let midX = (from.x + to.x) / 2
       let midY = (from.y + to.y) / 2
       let distance = hypot(to.x - from.x, to.y - from.y)
       let controlDistance = distance * 0.3  // Arc depth
       let centerX = config.fieldWidth / 2
       
       let controlPoint: CGPoint
       switch motion {
       case .stop:
           // Curve inward (toward field center) — Y stays same side
           let inwardDir = (midX > centerX) ? -1 : 1
           controlPoint = CGPoint(x: midX + CGFloat(inwardDir) * controlDistance, y: midY - controlDistance)
       case .after, .go:
           // Curve outward (away from field center) — Y moves to opposite side
           let outwardDir = (midX > centerX) ? 1 : -1
           controlPoint = CGPoint(x: midX + CGFloat(outwardDir) * controlDistance, y: midY - controlDistance)
       case .none:
           return []
       }
       
       // Sample points along quadratic Bézier curve
       var pathPoints: [CGPoint] = []
       for t in stride(from: CGFloat(0), through: CGFloat(1), by: 0.1) {
           let point = quadraticBezier(p0: from, c: controlPoint, p1: to, t: t)
           pathPoints.append(point)
       }
       return pathPoints
   }
   
   private func quadraticBezier(p0: CGPoint, c: CGPoint, p1: CGPoint, t: CGFloat) -> CGPoint {
       let mt = 1 - t
       return CGPoint(
           x: mt * mt * p0.x + 2 * mt * t * c.x + t * t * p1.x,
           y: mt * mt * p0.y + 2 * mt * t * c.y + t * t * p1.y
       )
   }
   ```

2. **Compute Y's Final Position**
   - Y's final position depends on final side but stays at same Y coordinate (line of scrimmage)
   - If Y flips from left to right: position shifts horizontally based on receiver alignment in formation
   - Use `receiverPositions()` or add new method `yFinalPosition(…)` to compute final position
   
   ```swift
   func yFinalPosition(initialSide: FieldSide, finalSide: FieldSide, formation: Formation, config: DiagramConfig) -> CGPoint {
       let centerX = config.fieldWidth / 2
       let losY = config.lineOfScrimmageY
       
       // Get Y's position for final side in this formation
       var finalPos = receiverPositions(formation: formation, config: config)[.Y]!
       
       // If final side is opposite of initial, mirror position
       if initialSide != finalSide && finalSide != .center {
           let distance = abs(finalPos.x - centerX)
           finalPos.x = (finalSide == .right) ? centerX + distance : centerX - distance
       }
       
       return finalPos
   }
   ```
   
   **Alternative Approach (simpler):** Keep Y's final visual position fixed to its base alignment; only draw the motion arc to indicate the motion was applied. The side flips logically (for concept matching) but not visually in the diagram. This is valid if coaches understand motion semantically.

3. **Modify RouteDiagramView to Draw Motion**
   - In `drawRoutes()` or new `drawMotion()` method, before drawing route paths:
     - For each assignment with motion applied:
       - Get initial and final positions
       - Call `motionPath(…)` to get arc points
       - Draw dashed stroke (dash: [4, 4])
       - Use lighter color (e.g., `.yellow.opacity(0.5)` for Y) to distinguish from route lines
   - Z-order: Draw motion arcs BEFORE route paths so routes are on top
   
   ```swift
   private func drawMotion(context: inout GraphicsContext, config: DiagramConfig, positions: [Receiver: CGPoint]) {
       for assignment in playCall.assignments {
           guard assignment.receiver == .Y, assignment.motion != .none else { continue }
           guard let initialPos = positions[.Y] else { continue }
           
           let finalPos = renderer.yFinalPosition(
               initialSide: assignment.side,
               finalSide: assignment.motionFinalSide ?? assignment.side,
               formation: playCall.formation,
               config: config
           )
           
           let arcPoints = renderer.motionPath(
               for: .Y,
               motion: assignment.motion,
               from: initialPos,
               to: finalPos,
               config: config
           )
           
           guard arcPoints.count >= 2 else { continue }
           
           let motionPath = Path { path in
               path.move(to: arcPoints[0])
               for i in 1..<arcPoints.count {
                   path.addLine(to: arcPoints[i])
               }
           }
           
           context.stroke(
               motionPath,
               with: .color(.yellow.opacity(0.5)),
               style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [4, 4])
           )
       }
   }
   ```

4. **Update Canvas Drawing Order in RouteDiagramView**
   - Call `drawMotion()` BEFORE `drawRoutes()`
   - Ensure motion arcs appear behind route paths

**Ripple impact:**
- RouteDiagramView receives PlayCall with motion-applied assignments
- DiagramRenderer needs to compute final positions; may need formation context added to signature

**Testing Surface:**
- Unit test: `motionPath(motion: .stop, from: leftPos, to: rightPos)` returns arc curving outward
- Unit test: `motionPath(motion: .go, from: leftPos, to: rightPos)` returns arc curving inward
- SwiftUI Preview: RouteDiagramView with Trips Left Smash, Y Stop motion applied — verify dashed arc appears from Y initial to Y final
- Preview: Y After motion applied — verify no motion arc drawn (only row indicator changes)

**Estimated LOE:** 2–3 hours (Bézier curve math, geometry computation, Canvas rendering)

**Done-when:**
- DiagramRenderer computes motion arcs correctly
- Motion arcs render as dashed lines in Canvas
- Z-order is correct (motion behind routes)
- Y's final position is computed based on motion type and formation
- Previews show motion arcs rendering correctly

---

### Phase 6: Concept Badge Row — Side-Specific Concept Display

**Objective:** Create ConceptBadgeRow component displaying left and right-side identified concepts below diagram.

**Dependencies:** Phase 2, Phase 3, Phase 4, Phase 5

**Files:**
- `Views/ConceptBadgeRow.swift` (new)
- `Views/PlayCallerView.swift` (modify)

**Tasks:**

1. **Create ConceptBadgeRow Component**
   - Component signature:
     ```swift
     struct ConceptBadgeRow: View {
         let leftConcept: RouteConcept?
         let rightConcept: RouteConcept?
         let hasMotion: Bool  // true if any motion applied
         
         var body: some View { … }
     }
     ```
   - Layout: Chevron icon | Space | Left concept badge | Space | Right concept badge | Space | Chevron icon
   - Left chevron: `<`; right chevron: `>`
   - Concept badges: Green background with checkmark and concept name (reuse existing ConceptBadge if possible)
   - Handle nil concepts: Display "—" or "No match" placeholder
   - When both are nil (no concepts identified): Show "No side-specific concepts identified"
   - When motion applied: Add visual indicator (e.g., "Motion Applied" label or indicator icon)
   
   ```swift
   struct ConceptBadgeRow: View {
       let leftConcept: RouteConcept?
       let rightConcept: RouteConcept?
       let hasMotion: Bool
       
       var body: some View {
           VStack(spacing: 12) {
               if leftConcept == nil && rightConcept == nil && !hasMotion {
                   Text("No concepts identified")
                       .font(.subheadline)
                       .foregroundStyle(.tertiary)
               } else {
                   HStack(spacing: 16) {
                       // Left chevron
                       Text("<")
                           .font(.title2.bold())
                           .foregroundStyle(.secondary)
                       
                       // Left concept
                       if let concept = leftConcept {
                           ConceptBadge(concept: concept)
                               .frame(maxWidth: .infinity)
                       } else {
                           Text("—")
                               .font(.subheadline)
                               .foregroundStyle(.tertiary)
                               .frame(maxWidth: .infinity)
                       }
                       
                       // Right concept
                       if let concept = rightConcept {
                           ConceptBadge(concept: concept)
                               .frame(maxWidth: .infinity)
                       } else {
                           Text("—")
                               .font(.subheadline)
                               .foregroundStyle(.tertiary)
                               .frame(maxWidth: .infinity)
                       }
                       
                       // Right chevron
                       Text(">")
                           .font(.title2.bold())
                           .foregroundStyle(.secondary)
                   }
                   
                   if hasMotion {
                       Text("Motion Applied")
                           .font(.caption)
                           .foregroundStyle(.orange)
                   }
               }
           }
           .padding()
           .frame(maxWidth: .infinity)
           .background(Color(.systemGray6))
           .clipShape(RoundedRectangle(cornerRadius: 12))
       }
   }
   ```

2. **Integrate ConceptBadgeRow into PlayCallerView**
   - In `resultSection()`, after RouteDiagramView and before ReceiverAssignmentView, add:
     ```swift
     ConceptBadgeRow(
         leftConcept: viewModel.leftSideConcept,
         rightConcept: viewModel.rightSideConcept,
         hasMotion: viewModel.yMotion != .none
     )
     ```
   - Bind to ViewModel's `leftSideConcept` and `rightSideConcept` properties
   - Update badge whenever motion changes (automatic via @Published)

3. **Handle Empty States**
   - If only left concept is identified: display left badge, right shows "—"
   - If only right concept is identified: display right badge, left shows "—"
   - If neither: show "No concepts identified" message
   - If motion applied but no concepts matched: show "Motion Applied" with both badges showing "—"

**Ripple impact:**
- PlayCallerView must pass `leftSideConcept`, `rightSideConcept`, and `yMotion` to ConceptBadgeRow
- Component is reactive to ViewModel state changes

**Testing Surface:**
- SwiftUI Preview: ConceptBadgeRow with both concepts identified
- SwiftUI Preview: ConceptBadgeRow with only left concept
- SwiftUI Preview: ConceptBadgeRow with neither concept
- SwiftUI Preview: ConceptBadgeRow with motion applied
- Interaction test: Applying Y motion updates badge row reactively

**Estimated LOE:** 1–1.5 hours (UI layout, state binding, preview refinement)

**Done-when:**
- ConceptBadgeRow renders correctly with all combinations of concepts
- Component updates reactively when ViewModel state changes
- Badges display correctly; nil concepts show placeholder
- PlayCallerView integrates ConceptBadgeRow without errors

---

### Phase 7: Formation Validation — Model & ViewModel

**Objective:** Enforce motion-only-in-Trips constraint at model and ViewModel level.

**Dependencies:** Phase 1, Phase 2

**Files:**
- `Models/RouteAssignment.swift` (modify — add validation)
- `ViewModels/PlayCallerViewModel.swift` (already partial in Phase 2)

**Tasks:**

1. **Add Validator Method to Formation Enum**
   - Add method: `canApplyMotion() -> Bool`
     ```swift
     func canApplyMotion() -> Bool {
         switch self {
         case .tripsLeft, .tripsRight: return true
         case .twins: return false
         }
     }
     ```

2. **Add Validation Guard in RouteAssignment**
   - When motion is assigned to a RouteAssignment, validate via computed property:
     ```swift
     var isValidMotionApplication: Bool {
         if motion == nil { return true }
         // Motion only valid on Y receiver
         guard receiver == .Y else { return false }
         // Caller must ensure formation allows motion (checked in ViewModel)
         return true
     }
     ```

3. **Enforce Validation in ViewModel** (already done in Phase 2 `motionChanged()`)
   - Check `currentPlayCall?.formation.canApplyMotion() == true` before allowing motion selection
   - Display error: "Motion only available in Trips formations"
   - Reset motion to `.none` when formation changes away from Trips

4. **Add Validation Error to ViewModel**
   - If user attempts motion in invalid formation, set `errorMessage` and animate error banner
   - No state change; motion stays `.none`

**Ripple impact:**
- PlayCallerView displays validation error in error banner (already exists)
- ReceiverAssignmentView disables motion picker (already done in Phase 4)

**Testing Surface:**
- Unit test: `Formation.tripsLeft.canApplyMotion() == true`
- Unit test: `Formation.twins.canApplyMotion() == false`
- Unit test: `motionChanged(.stop)` in Twins formation sets error message and resets motion
- Integration test: Switch formation Trips Left → Twins; motion resets and error banner appears

**Estimated LOE:** 0.5 hours (simple guard clauses and error messages)

**Done-when:**
- `Formation.canApplyMotion()` method exists and returns correct values
- ViewModel rejects motion in invalid formations
- Error message displays; motion resets
- Formation change resets motion to `.none`

---

### Phase 8: Integration Testing & End-to-End Verification

**Objective:** Verify all phases work together; test representative user workflows.

**Dependencies:** Phases 1–7 (all code complete)

**Files:**
- `Tests/SpartansPlaycallerTests/` (new or modify existing)

**Tasks:**

1. **Integration Test: Parse + Motion + Concept Re-Identification**
   - Input: "Trips Left 6794"
   - Parse: Identify Smash concept on left side
   - Apply Y Stop motion: Y moves from left to right
   - Verify: leftSideConcept = Smash, rightSideConcept = nil (or another concept if matched)
   - Verify: currentPlayCallWithMotion shows Y with motionFinalSide = .right

2. **Integration Test: Formation Change Resets Motion**
   - Start: Trips Left formation, Y motion = .stop
   - Change formation to Twins
   - Verify: yMotion resets to .none, error message set (or silent reset)
   - Verify: motion picker disabled in UI

3. **Integration Test: Diagram Rendering with Motion**
   - Setup: Trips Left, Smash, Y Stop motion
   - Verify: RouteDiagramView renders motion arc from Y initial to Y final
   - Verify: Arc is dashed, lighter color
   - Verify: Z-order correct (motion behind routes)

4. **Integration Test: Concept Badge Row Updates**
   - Setup: Trips Left, Smash, motion = .none
   - Verify: ConceptBadgeRow shows left = Smash, right = nil
   - Apply Y Stop motion
   - Verify: ConceptBadgeRow updates reactively to new concepts
   - Verify: "Motion Applied" indicator visible

5. **SwiftUI Preview Tests**
   - Create preview with Trips Right formation, Sail concept
   - Apply each motion type (Stop, After, Go) and verify diagram updates
   - Verify all UI components render without crashes

**Testing Surface:**
- Integration tests can use mocked DiagramRenderer and ConceptMatcher
- SwiftUI Previews can be run in Xcode Preview Canvas
- No E2E tests needed (personal project, no backend)

**Estimated LOE:** 2–3 hours (integration test setup, preview refinement, debugging)

**Done-when:**
- All integration tests pass
- SwiftUI Previews render correctly for all formation/motion combinations
- No warnings or errors in Xcode build
- Diagram rendering matches expected arc and z-order
- Concept badges update reactively

---

## ViewModel State Management Design (Detailed)

### State Flow Diagram

```
PlayCallerView
    ↓
PlayCallerViewModel
    ├── @Published var selectedFormation: Formation
    ├── @Published var selectedConcept: RouteConcept?
    ├── @Published var routeDigitInput: String
    ├── @Published var currentPlayCall: PlayCall?        (original parse result)
    ├── @Published var yMotion: ReceiverMotion = .none   (NEW: motion selection)
    ├── @Published var currentPlayCallWithMotion: PlayCall?  (NEW: derived state)
    ├── @Published var leftSideConcept: RouteConcept?    (NEW: re-identified)
    ├── @Published var rightSideConcept: RouteConcept?   (NEW: re-identified)
    └── @Published var errorMessage: String?
    
    Views consume:
    - RouteDiagramView uses currentPlayCallWithMotion (with motion-applied assignments)
    - ReceiverAssignmentView uses currentPlayCallWithMotion
    - ConceptBadgeRow uses leftSideConcept, rightSideConcept, yMotion
```

### State Transitions

**Workflow 1: Parse digits, then apply motion**
1. User enters "6794" in Trips Left formation
2. `parseRouteDigits()` called
3. Parser interprets → `currentPlayCall` set (Y on left side)
4. `applyMotion()` called → `currentPlayCallWithMotion` = `currentPlayCall` (motion = .none)
5. Concepts identified for left/right independently
6. UI renders diagram with original concept

**Workflow 2: User applies Y Stop motion**
1. Coach taps "Stop" in motion picker
2. `motionChanged(.stop)` called
3. Guard: `canApplyMotion()` check passes
4. `yMotion` = `.stop`
5. `applyMotion()` called:
   - Creates new RouteAssignments with Y.motionFinalSide = .right
   - Sets `currentPlayCallWithMotion` with updated assignments
   - Calls `reidentifyConceptsBySide()`
6. ConceptMatcher identifies concepts for new sides
7. `leftSideConcept` and `rightSideConcept` updated
8. UI re-renders diagram with motion arc, new concept badges

**Workflow 3: User changes formation while motion applied**
1. Coach selects Twins formation
2. `formationChanged()` called
3. Guard: `currentPlayCall?.formation.canApplyMotion()` check FAILS
4. `yMotion` reset to `.none`
5. `currentPlayCallWithMotion` resets to `currentPlayCall` (no motion)
6. `applyMotion()` called (motion = .none, no-op)
7. Concepts re-identified for new formation
8. Motion picker disabled in UI

### Why Separate currentPlayCall and currentPlayCallWithMotion?

1. **Preserves Original:** Coaches can toggle motion on/off without re-parsing
2. **Decouples Motion:** Motion is ViewModel concern, not persistent model
3. **Atomic Concept Re-ID:** When motion changes, only concepts are re-evaluated (routes stay same)
4. **Clear Semantics:** "Current" play is the parsed/generated one; "WithMotion" is the rendered variant

### Why Side-Specific Concepts?

In Trips formations, coaches may identify different concepts per side of the field:
- **Trips Left + Y Stop:** Y stays on left side. Concept matching uses left side receivers (X, Y, A).
- **Trips Left + Y After/Go:** Y moves to right side. Left side receivers (X, A) are evaluated separately from right side (Y, Z).
- **Display:** Two badges show what's running on each side, making offensive intent clearer.
- **Future:** Coaches might send audibles per-side ("Run Sail on left, Y moves right for Smash").

---

## Motion UI Flow & Wireframe

### ReceiverAssignmentView with Motion Picker

```
┌────────────────────────────────────────┐
│         Y MOTION (Trips Only)          │  ← Header, shown only in Trips
├────────────────────────────────────────┤
│ [None]  [Stop]  [After]  [Go]         │  ← Segmented picker
│   ◯      ◯       ◯       ◯             │     User taps to select
├────────────────────────────────────────┤
│ Receiver Assignments                   │
├────────────────────────────────────────┤
│ WR  #   Side        Route              │
├────────────────────────────────────────┤
│ X   6   Left        Curl               │
│ Y   7   Left→Right* Corner (→Comeback?)│  ← Shows motion, final side
│ Z   9   Right       Go                 │
│ A   9   Right       Go                 │
└────────────────────────────────────────┘
```

**Pseudocode: Y Row Rendering with Motion**

```swift
HStack {
    Text("Y")  // Receiver
        .font(.monospaced)
    
    Text("7")  // Route number
    
    // Side column: Show base and final sides
    VStack(alignment: .center, spacing: 2) {
        Text(assignment.side.rawValue.capitalized)  // "Left"
        if let finalSide = assignment.motionFinalSide, finalSide != assignment.side {
            Text("→ \(finalSide.rawValue.capitalized)")  // "→ Right"
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }
    
    // Meaning: Show after motion side-flip
    let finalSide = assignment.motionFinalSide ?? assignment.side
    let meaning = assignment.routeNumber.meaning(on: finalSide)
    Text(meaning.rawValue)
}
```

### Interaction Flow

```
Coach in Trips Left formation with Smash concept
                ↓
        [Motion Picker]
              ↓
        Coach taps "Stop"
              ↓
        ViewModel.motionChanged(.stop)
              ↓
        Y flips to right side
              ↓
        Concepts re-identified (left, right)
              ↓
        Diagram updates with motion arc
        Concept badges update
        Y row shows "Left → Right" with updated meaning
              ↓
        Coach sees new concept identification
```

---

## Concept Matching Refactor (Detailed)

### Current Behavior (Before Motion)

```swift
// ConceptMatcher.identify(assignments, formation)
// Matches FULL play concept across all receivers
let routeMap = Dictionary(uniqueKeysWithValues: assignments.map { ($0.receiver, $0.routeNumber) })
let template = library.templates.first { 
    $0.formationContext.matches(formation) && 
    $0.matches(assignments: routeMap) 
}
return template?.concept
```

**Example:** Trips Left 6794 → Smash (if X=6, Y=7 match template)

### New Behavior (With Motion)

```swift
// Split into left/right sides AFTER motion applied
let leftAssignments = assignments.filter { 
    ($0.motionFinalSide == .left) || 
    ($0.motionFinalSide == nil && $0.side == .left)
}
let rightAssignments = assignments.filter { 
    ($0.motionFinalSide == .right) || 
    ($0.motionFinalSide == nil && $0.side == .right)
}

// Identify concepts independently per side
leftConcept = matcher.identifyForSide(.left, assignments: leftAssignments, formation)
rightConcept = matcher.identifyForSide(.right, assignments: rightAssignments, formation)
```

**Example:** Trips Left 6794 + Y Stop
- Base assignment: X=6(.left), Y=7(.left, motionFinalSide=.left), Z=9(.right), A=9(.right)
- After motion: Y stays on left side (Y Stop does NOT change side)
- Left group: X=6, Y=7, A=9 → match tripsLeft.conceptSide templates → Smash (if routes match)
- Right group: Z=9 → match tripsRight templates (Z route 9 alone) → nil (no concept match)

**Example:** Trips Left 6794 + Y After
- Base assignment: X=6(.left), Y=7(.left, motionFinalSide=.right), Z=9(.right), A=9(.right)
- After motion: Y moves to right side (Y After changes side)
- Left group: X=6, A=9 → match tripsLeft.conceptSide templates → Smash (if routes match)
- Right group: Y=7, Z=9 → match tripsRight templates (Y=7, Z=9) → Comeback (if template exists)

### ConceptMatcher.identifyForSide() Signature

```swift
func identifyForSide(
    _ side: FieldSide,
    assignments: [RouteAssignment],
    formation: Formation
) -> RouteConcept? {
    // Filter templates:
    // 1. Formation matches (tripsLeft, tripsRight, etc.)
    // 2. FormationContext.conceptSide matches requested side
    // 3. Template routes match the filtered assignments
    
    let routeMap = Dictionary(uniqueKeysWithValues: assignments.map { ($0.receiver, $0.routeNumber) })
    
    let matchingTemplate = library.templates.first { template in
        template.formationContext.matches(formation: formation) &&
        template.formationContext.conceptSide == side &&
        template.matches(assignments: routeMap)
    }
    
    return matchingTemplate?.concept
}
```

### Template Filtering Example

**Library templates (relevant):**
```swift
ConceptTemplate(concept: .smash, formationContext: .tripsLeft, receiverRoutes: [.X: .six, .Y: .seven, .A: .four])
ConceptTemplate(concept: .smash, formationContext: .tripsRight, receiverRoutes: [.Z: .five, .Y: .eight, .A: .one])
```

**Call:** `identifyForSide(.left, [X=6, Y=7], formation: .tripsLeft)`
- Template 1: formationContext = .tripsLeft, conceptSide = .left ✓
- Template 1: X=6, Y=7 match required routes ✓ but A is missing
- No match (template requires A route)

**Call:** `identifyForSide(.right, [Y=7, Z=9, A=9], formation: .tripsLeft)` (after Y Stop motion in Trips Left)
- No templates match because this is called on Trips Left formation with conceptSide = .right
- Result: nil (correct; Trips Left doesn't have right-side concept templates)

---

## Diagram Rendering Changes (Detailed)

### Motion Arc Geometry

**Y Stop Motion (Stays Same Side)**
```
Initial: Y on left          Final: Y on left
(shift position)            (after motion)

    X            Z             X*           Z
     |           |              |           |
     Y           A         →    Y'          A
                            (slight inward arc)
```

Arc curves **inward** (toward field center) to visualize Y staying on same side but adjusting position.

**Y After Motion (Move to Opposite Side)**
```
Initial: Y on left          Final: Y on right
(after motion)              (after motion)

    X            Z             X            Z
     |           |              |           |
     Y           A         →    Y'           A
                            (wide outward arc)
```

Arc curves **outward** (away from field center) to visualize Y crossing field to opposite side.

**Y Go Motion (Strip to Opposite Side)**
```
Initial: Y on left          Final: Y on right
(after motion)              (after motion)

    X            Z             X            Z
     |           |              |           |
     Y           A         →    Y'           A
                            (wide outward arc)
```

Arc curves **outward** (away from field center) to visualize Y stripping across field to opposite side.

### Z-Order in Canvas

```swift
func drawCanvas(context: inout GraphicsContext) {
    // 1. Draw field (lines, yard markers)
    drawField(…)
    
    // 2. Draw football
    drawFootball(…)
    
    // 3. Draw motion arcs (dashed, behind everything)
    drawMotion(…)  // NEW
    
    // 4. Draw route paths (solid lines)
    drawRoutes(…)
    
    // 5. Draw receiver circles and labels (on top)
    drawReceivers(…)
}
```

### Implementation Pseudocode

```swift
extension DiagramRenderer {
    
    func motionPath(
        for receiver: Receiver,
        motion: ReceiverMotion,
        from: CGPoint,
        to: CGPoint,
        config: DiagramConfig
    ) -> [CGPoint] {
        guard motion != .none else { return [] }
        guard from != to else { return [] }  // No motion if same position
        
        // Compute arc control point
        let midX = (from.x + to.x) / 2
        let midY = (from.y + to.y) / 2
        let distance = hypot(to.x - from.x, to.y - from.y)
        let arcDepth = distance * 0.25  // Moderate arc curve
        
        let controlPoint: CGPoint
        let centerX = config.fieldWidth / 2
        switch motion {
        case .stop:
            // Arc inward (convex toward center) — Y stays same side
            let inwardDirection = (midX > centerX) ? -1 : 1
            controlPoint = CGPoint(x: midX + CGFloat(inwardDirection) * arcDepth, y: midY - arcDepth * 0.5)
            
        case .after, .go:
            // Arc outward (convex away from center) — Y moves to opposite side
            let outwardDirection = (midX > centerX) ? 1 : -1
            controlPoint = CGPoint(x: midX + CGFloat(outwardDirection) * arcDepth, y: midY - arcDepth * 0.5)
            
        case .none:
            return []
        }
        
        // Sample quadratic Bézier curve
        var pathPoints: [CGPoint] = []
        for t in stride(from: CGFloat(0), through: CGFloat(1), by: 0.05) {
            let point = quadraticBezier(p0: from, control: controlPoint, p1: to, t: t)
            pathPoints.append(point)
        }
        return pathPoints
    }
    
    private func quadraticBezier(p0: CGPoint, control: CGPoint, p1: CGPoint, t: CGFloat) -> CGPoint {
        let mt = 1 - t
        let mt2 = mt * mt
        let t2 = t * t
        return CGPoint(
            x: mt2 * p0.x + 2 * mt * t * control.x + t2 * p1.x,
            y: mt2 * p0.y + 2 * mt * t * control.y + t2 * p1.y
        )
    }
}

extension RouteDiagramView {
    
    private func drawMotion(context: inout GraphicsContext, config: DiagramConfig, positions: [Receiver: CGPoint]) {
        for assignment in playCall.assignments {
            guard assignment.receiver == .Y else { continue }
            guard let motion = assignment.motion, motion != .none else { continue }
            guard let initialPos = positions[.Y] else { continue }
            
            // Compute Y's final position after motion
            let finalPos = renderer.computeYFinalPosition(
                initialSide: assignment.side,
                finalSide: assignment.motionFinalSide ?? assignment.side,
                formation: playCall.formation,
                config: config
            )
            
            // Get motion arc
            let arcPoints = renderer.motionPath(
                for: .Y,
                motion: motion,
                from: initialPos,
                to: finalPos,
                config: config
            )
            
            guard arcPoints.count >= 2 else { continue }
            
            // Draw dashed arc
            let motionPath = Path { path in
                path.move(to: arcPoints[0])
                for i in 1..<arcPoints.count {
                    path.addLine(to: arcPoints[i])
                }
            }
            
            context.stroke(
                motionPath,
                with: .color(.yellow.opacity(0.4)),
                style: StrokeStyle(
                    lineWidth: 2.5,
                    lineCap: .round,
                    lineJoin: .round,
                    dash: [4, 4]  // Dashed
                )
            )
            
            // Optional: Add arrowhead at final position
            if let lastPoint = arcPoints.last, arcPoints.count >= 2 {
                let prevPoint = arcPoints[arcPoints.count - 2]
                drawArrow(context: &context, from: prevPoint, to: lastPoint, color: .yellow.opacity(0.4))
            }
        }
    }
}
```

---

## Formation Validation Strategy

### Validation Layers

1. **Model Layer (RouteAssignment)**
   - Computed property `isValidMotionApplication: Bool`
   - Validates that motion (if present) is only on Y receiver
   - Formation validation happens at ViewModel layer (motion is ViewModel state)

2. **ViewModel Layer (PlayCallerViewModel)**
   - Check `Formation.canApplyMotion()` before allowing motion selection
   - Reset motion when formation changes away from Trips
   - Set error message if user attempts invalid motion

3. **View Layer (ReceiverAssignmentView)**
   - Disable motion picker UI when `!formation.canApplyMotion()`
   - Gray out buttons or hide picker entirely

### Error Handling

**Scenario 1: User in Trips Left, applies Y Stop, then switches to Twins**
```
Current state: yMotion = .stop, formation = .tripsLeft
User taps Twins in formation picker
→ formationChanged() called
→ Guard: currentPlayCall?.formation.canApplyMotion() == false
→ yMotion reset to .none
→ errorMessage = nil (silent reset, or brief toast: "Motion not available in Twins")
→ UI: motion picker disabled, state synced
```

**Scenario 2: User attempts to set motion in Twins formation**
```
User selects Twins formation
→ formationChanged() calls updateAvailableConcepts()
→ yMotion = .none by default (or explicit reset)
→ ReceiverAssignmentView disables motion picker
User somehow tries to set yMotion (shouldn't happen with UI disabled)
→ motionChanged(.stop) called
→ Guard: !currentPlayCall?.formation.canApplyMotion() → fails
→ errorMessage = "Motion only available in Trips formations"
→ yMotion stays .none
→ Error banner displays
```

### Prevention vs. Recovery

- **Prevention (Preferred):** Motion picker disabled in UI for non-Trips formations
- **Recovery:** Error message and state reset if motion somehow set in invalid formation

---

## Estimated LOE Summary

| Phase | Task | LOE | Cumulative |
|-------|------|-----|-----------|
| 1 | ReceiverMotion enum, RouteAssignment extend | 1–2 hrs | 1–2 hrs |
| 2 | ViewModel motion state, applyMotion(), concept re-ID | 2–3 hrs | 3–5 hrs |
| 3 | RouteInterpreter/ConceptMatcher side-aware matching | 1.5–2 hrs | 4.5–7 hrs |
| 4 | Motion picker UI in ReceiverAssignmentView | 1.5–2 hrs | 6–9 hrs |
| 5 | Diagram motion arc rendering, DiagramRenderer | 2–3 hrs | 8–12 hrs |
| 6 | ConceptBadgeRow component, PlayCallerView integration | 1–1.5 hrs | 9–13.5 hrs |
| 7 | Formation validation (model, ViewModel, View) | 0.5 hrs | 9.5–14 hrs |
| 8 | Integration testing, preview verification | 2–3 hrs | 11.5–17 hrs |
| | **TOTAL** | | **11.5–17 hrs** |

**Recommended timeline:** 3–4 days at steady pace, or 1–2 days intensive with pair programming.

---

## iOS-Specific Gotchas & Solutions

### SwiftUI Canvas Limitations

**Problem:** Canvas rendering is immediate-mode; complex drawings can be slow.
**Solution:** 
- Keep motion arc sampling coarse (0.05 stride between points) initially; optimize if perf issues arise
- Pre-compute arc points in DiagramRenderer (not in Canvas draw method)
- Consider caching receiver positions/motion paths if motion selection changes frequently

**Preview Canvas Limitations:**
- Previews in Xcode may not render Canvas exactly as runtime
- Test on actual device/simulator to verify arc rendering
- If Preview crashes, simplify test data (fewer routes, simpler formation)

### State Binding Quirks

**Problem:** @Published properties and @Binding in SwiftUI can cause re-render loops if not careful.
**Solution:**
- Avoid binding to derived properties; use separate @Published for derived state (currentPlayCallWithMotion, leftSideConcept, rightSideConcept)
- Never mutate published arrays/objects in-place; create new instances (RouteAssignment value type helps here)
- Use `.onChange()` to trigger recomputation when dependencies change, not in view body

**Example:**
```swift
// ✓ Good: onChange triggers recompute
@Published var yMotion: ReceiverMotion = .none

// In some method:
.onChange(of: yMotion) { _, newValue in
    applyMotion()
}

// ✗ Bad: recomputing in body causes loops
var body: some View {
    VStack {
        let newConcept = reidentifyConcept()  // ← Don't do this in body!
    }
}
```

### Performance Considerations

**Route Path Computation:**
- RouteNumber.meaning() is a switch statement (fast)
- Bézier curve sampling: 20 points per motion arc (negligible)
- Receiver position lookup: O(1) dictionary (fast)

**Concept Re-Matching:**
- ConceptMatcher filters templates (linear scan, ~20 templates)
- Only triggered on motion change, not every render
- No performance concerns for this project scope

**Canvas Rendering:**
- Drawing motion arc: one stroke per Y receiver (1 object per canvas)
- Drawing routes: 4 strokes per route (4 receivers)
- Total objects: <15 per diagram (well within Canvas capacity)

**Summary:** No anticipated performance issues; monitor with Instruments if adding many more features.

---

## Testing Hooks & Preview Checkpoints

### Unit Tests (Phase 1–3)

**File:** `Tests/SpartansPlaycallerTests/ReceiverMotionTests.swift`

```swift
import XCTest
@testable import SpartansPlaycaller

class ReceiverMotionTests: XCTestCase {
    
    func testFinalSideYStopStaysSameSide() {
        let motion = ReceiverMotion.stop
        let finalSide = motion.finalSide(initialSide: .left, formation: .tripsLeft)
        XCTAssertEqual(finalSide, .left)  // Y Stop: stays on same side
    }
    
    func testFinalSideYStopRightStaysSameRight() {
        let motion = ReceiverMotion.stop
        let finalSide = motion.finalSide(initialSide: .right, formation: .tripsRight)
        XCTAssertEqual(finalSide, .right)  // Y Stop: stays on same side
    }
    
    func testFinalSideYAfterFlipsToOppositeSide() {
        let motion = ReceiverMotion.after
        let finalSide = motion.finalSide(initialSide: .left, formation: .tripsLeft)
        XCTAssertEqual(finalSide, .right)  // Y After: flips to opposite side
    }
    
    func testFinalSideYAfterFromRightFlipsToLeft() {
        let motion = ReceiverMotion.after
        let finalSide = motion.finalSide(initialSide: .right, formation: .tripsRight)
        XCTAssertEqual(finalSide, .left)  // Y After: flips to opposite side
    }
    
    func testYGoMotionFlipsToOppositeSide() {
        let motion = ReceiverMotion.go
        let finalSide = motion.finalSide(initialSide: .left, formation: .tripsLeft)
        XCTAssertEqual(finalSide, .right)  // Y Go: moves to opposite side
    }
    
    func testYGoFromRightFlipsToLeft() {
        let motion = ReceiverMotion.go
        let finalSide = motion.finalSide(initialSide: .right, formation: .tripsRight)
        XCTAssertEqual(finalSide, .left)  // Y Go: moves to opposite side
    }
}

class ConceptMatcherSideTests: XCTestCase {
    
    func testIdentifyForLeftSideTripsLeft() {
        let matcher = ConceptMatcher()
        let assignments = [
            RouteAssignment(receiver: .X, routeNumber: .six, side: .left, meaning: .curl),
            RouteAssignment(receiver: .Y, routeNumber: .seven, side: .left, meaning: .corner),
            RouteAssignment(receiver: .A, routeNumber: .four, side: .left, meaning: .digIn)
        ]
        let concept = matcher.identifyForSide(.left, assignments: assignments, formation: .tripsLeft)
        XCTAssertEqual(concept, .smash)
    }
    
    func testIdentifyForRightSideTripsLeftReturnsNil() {
        let matcher = ConceptMatcher()
        let assignments = [
            RouteAssignment(receiver: .Z, routeNumber: .nine, side: .right, meaning: .goFade)
        ]
        let concept = matcher.identifyForSide(.right, assignments: assignments, formation: .tripsLeft)
        XCTAssertNil(concept)  // Trips Left has no right-side concepts
    }
}

class PlayCallerViewModelMotionTests: XCTestCase {
    
    func testMotionChangeInTripsLeftSucceeds() {
        let vm = PlayCallerViewModel()
        vm.selectedFormation = .tripsLeft
        vm.routeDigitInput = "6794"
        vm.parseRouteDigits()
        
        XCTAssertNotNil(vm.currentPlayCall)
        
        vm.motionChanged(.stop)
        
        XCTAssertEqual(vm.yMotion, .stop)
        XCTAssertNil(vm.errorMessage)
    }
    
    func testMotionChangeInTwinsIsRejected() {
        let vm = PlayCallerViewModel()
        vm.selectedFormation = .twins
        vm.routeDigitInput = "6794"
        vm.parseRouteDigits()
        
        vm.motionChanged(.stop)
        
        XCTAssertEqual(vm.yMotion, .none)
        XCTAssertNotNil(vm.errorMessage)
    }
    
    func testFormationChangeResetsMotion() {
        let vm = PlayCallerViewModel()
        vm.selectedFormation = .tripsLeft
        vm.routeDigitInput = "6794"
        vm.parseRouteDigits()
        vm.motionChanged(.stop)
        
        XCTAssertEqual(vm.yMotion, .stop)
        
        vm.selectedFormation = .twins
        vm.formationChanged()
        
        XCTAssertEqual(vm.yMotion, .none)
    }
}
```

### SwiftUI Preview Checkpoints

**File:** `SpartansPlaycaller/Views/PreviewContent/MotionPreviewData.swift` (new)

```swift
#if DEBUG

import SwiftUI

struct MotionPreviewData {
    
    static let tripsLeftSmashPlayCall = PlayCall(
        formation: .tripsLeft,
        routeDigits: "6794",
        assignments: [
            RouteAssignment(receiver: .X, routeNumber: .six, side: .left, meaning: .curl),
            RouteAssignment(receiver: .Y, routeNumber: .seven, side: .left, meaning: .corner),
            RouteAssignment(receiver: .Z, routeNumber: .nine, side: .right, meaning: .goFade),
            RouteAssignment(receiver: .A, routeNumber: .four, side: .left, meaning: .digIn)
        ],
        concept: .smash
    )
    
    static let tripsLeftSmashWithYStopMotion = {
        var playCall = tripsLeftSmashPlayCall
        var assignments = playCall.assignments
        if let yIndex = assignments.firstIndex(where: { $0.receiver == .Y }) {
            var yAssignment = assignments[yIndex]
            yAssignment.motion = .stop
            yAssignment.motionFinalSide = .right
            assignments[yIndex] = yAssignment
        }
        playCall.assignments = assignments
        return playCall
    }()
}

#endif
```

**Preview in RouteDiagramView.swift:**

```swift
#Preview("Trips Left Smash with Y Stop Motion") {
    RouteDiagramView(playCall: MotionPreviewData.tripsLeftSmashWithYStopMotion)
        .frame(height: 320)
        .padding()
}

#Preview("Trips Left Smash without Motion") {
    RouteDiagramView(playCall: MotionPreviewData.tripsLeftSmashPlayCall)
        .frame(height: 320)
        .padding()
}
```

**Preview in ReceiverAssignmentView.swift:**

```swift
#Preview("With Motion Picker (Trips Left)") {
    @State var motion = ReceiverMotion.none
    return ReceiverAssignmentView(
        assignments: MotionPreviewData.tripsLeftSmashPlayCall.assignments,
        selectedMotion: $motion,
        onMotionChange: { _ in },
        isMotionEnabled: true
    )
}

#Preview("Without Motion Picker (Twins)") {
    @State var motion = ReceiverMotion.none
    return ReceiverAssignmentView(
        assignments: MotionPreviewData.twins2794PlayCall.assignments,
        selectedMotion: $motion,
        onMotionChange: { _ in },
        isMotionEnabled: false
    )
}
```

**Preview in ConceptBadgeRow.swift:**

```swift
#Preview("Both Concepts Identified") {
    ConceptBadgeRow(
        leftConcept: .smash,
        rightConcept: .dagger,
        hasMotion: true
    )
}

#Preview("Left Concept Only") {
    ConceptBadgeRow(
        leftConcept: .smash,
        rightConcept: nil,
        hasMotion: false
    )
}

#Preview("No Concepts") {
    ConceptBadgeRow(
        leftConcept: nil,
        rightConcept: nil,
        hasMotion: false
    )
}
```

---

## Implementation Sequence (Recommended Order)

**Rationale:** Data model → ViewModel state → Services → UI; test incrementally.

1. **Phase 1:** ReceiverMotion enum, RouteAssignment extend (0.5 day)
   - Unblocks all other phases; provides compile-time types
   
2. **Phase 2:** ViewModel motion state (0.5 day)
   - Establishes state flow; allows testing with mocks
   
3. **Phase 3:** RouteInterpreter/ConceptMatcher side-aware matching (0.5 day)
   - Core business logic; needed for concept re-ID
   
4. **Phase 4:** Motion picker UI (0.25 day)
   - Coach-facing interaction; can test against mocked ViewModel
   
5. **Phase 5:** Diagram motion arc rendering (0.5 day)
   - Visual feedback; test in Previews
   
6. **Phase 6:** ConceptBadgeRow component (0.25 day)
   - Display layer; straightforward integration
   
7. **Phase 7:** Formation validation (0.1 day)
   - Guards already sketched in Phase 2
   
8. **Phase 8:** Integration testing & E2E verification (0.5 day)
   - Tie everything together; catch integration issues

**Total:** 3–4 days elapsed time at normal pace.

---

## File-by-File Changes Summary

### New Files

| File | Purpose |
|------|---------|
| `Models/ReceiverMotion.swift` | Enum + motion logic |
| `Views/ConceptBadgeRow.swift` | Component for side-specific concepts |
| `Tests/SpartansPlaycallerTests/ReceiverMotionTests.swift` | Unit tests for motion |
| `Tests/SpartansPlaycallerTests/ConceptMatcherSideTests.swift` | Unit tests for side-aware matching |
| `Views/PreviewContent/MotionPreviewData.swift` | Preview test data |

### Modified Files

| File | Changes |
|------|---------|
| `Models/RouteAssignment.swift` | Add `motion` and `motionFinalSide` properties |
| `ViewModels/PlayCallerViewModel.swift` | Add `yMotion`, `currentPlayCallWithMotion`, `leftSideConcept`, `rightSideConcept`; add `motionChanged()`, `applyMotion()`, `reidentifyConceptsBySide()` |
| `Services/RouteInterpreter.swift` | Add `identifyForSide()` method |
| `Services/ConceptMatcher.swift` | Add `identifyForSide()` method |
| `Services/DiagramRenderer.swift` | Add `motionPath()` and `yFinalPosition()` methods |
| `Views/RouteDiagramView.swift` | Add `drawMotion()` call; update drawing order |
| `Views/ReceiverAssignmentView.swift` | Add motion picker UI; update row rendering for motion feedback |
| `Views/PlayCallerView.swift` | Integrate `ConceptBadgeRow`; pass motion state to child views |

---

## Verification Checklist (Before Merge)

- [ ] All .swift files compile without errors or warnings
- [ ] Unit tests pass for ReceiverMotion, ConceptMatcher, ViewModel
- [ ] SwiftUI Previews render without crashes (Trips Left, Trips Right, Twins formations)
- [ ] Manual testing: Parse Trips Left 6794, apply Y Stop motion, verify diagram updates
- [ ] Manual testing: Switch formation to Twins, verify motion resets and picker disables
- [ ] Manual testing: Apply Y After motion, verify no motion arc drawn (only row indicator)
- [ ] Manual testing: Verify concept badges update when motion applied
- [ ] Code review: All new properties have clear purpose; no orphaned code
- [ ] Performance: No jank or stuttering when applying motion
- [ ] Accessibility: Motion picker is keyboard-accessible; motion feedback is clear

---

## Future Enhancements (Out of Scope)

- Motion for other receivers (not just Y)
- Motion trajectory animations (animate Y moving from initial to final position)
- Audible calls per side (coaches send different calls to left/right groups with motion)
- Undo/redo for motion state
- Persistence of motion selections (save to playbook)
- Wristband export with motion notation

---

## Appendix: Sample Code Snippets

### ReceiverMotion.swift (Complete)

```swift
import Foundation

/// Receiver motion types for Y receiver in Trips formations.
enum ReceiverMotion: String, CaseIterable, Identifiable {
    case none = "None"
    case stop = "Stop"
    case after = "After"
    case go = "Go"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .stop: return "Y Stop"
        case .after: return "Y After"
        case .go: return "Y Go"
        }
    }
    
    /// Compute Y's final field side after motion is applied.
    /// Only valid for Y receiver in Trips formations.
    func finalSide(initialSide: FieldSide, formation: Formation) -> FieldSide {
        switch self {
        case .none:
            // No motion; Y stays on initial side
            return initialSide
            
        case .stop:
            // Y Stop: Y stays on SAME side (no side change)
            return initialSide
            
        case .after:
            // Y After: Y moves to OPPOSITE side
            switch initialSide {
            case .left: return .right
            case .right: return .left
            case .center: return initialSide  // Shouldn't happen; Y not on center
            }
            
        case .go:
            // Y Go: Y moves to OPPOSITE side
            switch initialSide {
            case .left: return .right
            case .right: return .left
            case .center: return initialSide  // Shouldn't happen; Y not on center
            }
        }
    }
}
```

### RouteAssignment Extension

```swift
struct RouteAssignment: Identifiable {
    let id = UUID()
    let receiver: Receiver
    let routeNumber: RouteNumber
    let side: FieldSide
    let meaning: RouteMeaning
    var motion: ReceiverMotion? = nil  // NEW
    
    var motionFinalSide: FieldSide? {
        guard motion != nil else { return nil }
        return motion?.finalSide(initialSide: side, formation: /* need formation here */)
    }
    
    // ... rest of implementation
}

// Note: motionFinalSide calculation requires formation context.
// Better approach: pass formation to init or compute in ViewModel.
```

**Better approach:** Pass formation when creating assignments:

```swift
struct RouteAssignment: Identifiable {
    let id = UUID()
    let receiver: Receiver
    let routeNumber: RouteNumber
    let side: FieldSide
    let meaning: RouteMeaning
    var motion: ReceiverMotion? = nil
    let formation: Formation?  // Optional; set when motion is applied
    
    var motionFinalSide: FieldSide? {
        guard motion != nil, let formation = formation else { return nil }
        return motion?.finalSide(initialSide: side, formation: formation)
    }
}
```

Or compute in ViewModel (cleaner):

```swift
// In ViewModel.applyMotion():
let updatedAssignments = playCall.assignments.map { assignment -> RouteAssignment in
    if assignment.receiver == .Y && yMotion != .none {
        var updated = assignment
        updated.motion = yMotion
        // Compute final side here
        let finalSide = yMotion.finalSide(initialSide: assignment.side, formation: playCall.formation)
        // Store it (need to extend RouteAssignment)
        return updated
    }
    return assignment
}
```

---

## Glossary

| Term | Definition |
|------|------------|
| **Motion** | Optional adjustment to Y receiver's position/side after play is parsed |
| **Y Stop** | Y receiver stays on SAME side (for route interpretation and concept matching) |
| **Y After** | Y receiver moves to OPPOSITE side (for route interpretation and concept matching) |
| **Y Go** | Y receiver moves to OPPOSITE side (for route interpretation and concept matching) |
| **Field Side** | left, right, or center of the field relative to the ball |
| **Final Side** | Y's field side AFTER motion is applied (may differ from base side) |
| **Concept** | Named combination of receiver routes (e.g., Smash, Dagger) |
| **Side-Specific Concept** | Concept identified for one field side group only (e.g., left-side Smash after Y Stop motion) |
| **Formation Validation** | Check that motion is only used in valid formations (Trips Left/Right) |
| **Motion Arc** | Dashed path drawn in diagram showing Y's movement from initial to final position |
| **Receiver Position** | X, Y coordinate of receiver on the field diagram |
| **Route Path** | Sequence of line segments showing receiver's running route |

---

**End of Implementation Plan**

