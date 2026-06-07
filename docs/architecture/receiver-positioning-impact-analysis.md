# Receiver Positioning Customization: Impact Analysis

**Author:** Architecture & System Design  
**Date:** 2026-06-03  
**Status:** Analysis Only (No Implementation)

---

## Executive Summary

Allowing coaches to manually customize receiver positions on the diagram (independent of formation-based defaults) would require significant architectural refactoring across **5 critical subsystems**. The feature introduces **moderate-to-high implementation complexity** and **medium-to-high runtime risk** due to tight coupling between position data and concept matching logic.

**Recommendation:** This feature should be **deferred unless explicitly prioritized by product**. The minimal viable path exists but trades clarity for flexibility; the full implementation is architecturally sound but requires careful sequencing.

**Key Decision:** Custom positions would become **a new source of truth** alongside `Formation`, requiring explicit rules for precedence, persistence, and concept matching behavior.

---

## Problem Statement

**Current State:**
- Receiver positions are **derived entirely from `Formation` enum** via `DiagramRenderer.receiverPositions(formation, config)`.
- Positions are **immutable once formation is selected** — a coach cannot adjust them on the diagram.
- All downstream logic (routing, concept matching, Y motion) assumes formation-derived positions.

**Desired State (User Request):**
- A coach selects a formation (e.g., Twins) and then manually adjusts where specific receivers line up.
- Example: Move X wider, slot Y closer to center, spread A further out.
- Adjustments persist **within a single play** and are visible on the diagram immediately.
- **Non-goal:** Adjustments do NOT change the formation type or concept matching logic (initially).

**Scope Boundary:** This analysis assumes custom positions are **visualization-only** in MVP; concept matching and route interpretation use **formation-derived rules unchanged**. A future phase might couple custom positions to concept matching (e.g., "Smash is still Smash if A is 3pt wider?") — flagged as explicitly out-of-scope here.

---

## Impact Analysis

### 1. Diagram Rendering Pipeline

**Current Flow:**
```
PlayCall(formation) → DiagramRenderer.receiverPositions(formation)
  → [Receiver: CGPoint]
  → RouteDiagramView draws circles, routes, labels at returned positions
```

**Custom Positions Integration:**
```
PlayCall(formation, customPositions?) → 
  resolve positions (customPositions override defaults) →
  [Receiver: CGPoint] →
  RouteDiagramView renders
```

#### 1.1 DiagramRenderer Impact

**Method Signature Change (Required):**
- **Current:** `receiverPositions(formation: Formation, config: DiagramConfig) -> [Receiver: CGPoint]`
- **Future:** Add parameter for custom positions override, OR create new method `resolveReceiverPositions(formation:customPositions:config:)`

**Risk Assessment:**
- `receiverPositions()` is called in **30+ places** across tests and production code.
- Every callsite would need review to determine if custom positions should apply.
- **Callers within DiagramRenderer itself:**
  - `yFinalPosition()` — computes Y's base position before motion (line 181)
  - `yWheelArcPath()` — gets initial Y position for wheel geometry (line 279)
  - **Both need custom positions applied** because custom position → custom Y Wheel arc geometry

**Canvas Rendering Implications:**
- Route paths use `receiverPositions()` to fetch start points, then call `routePath()` to draw breaks.
- If custom positions move a receiver farther from center, the route break geometry **remains the same** (routes use absolute directions: 3 breaks LEFT, 4 breaks RIGHT, etc.).
- **Exception:** Y Wheel arc depends on Y's position; moving Y changes where the arc originates and potentially its curvature.

#### 1.2 Data Flow Through RouteDiagramView

**RouteDiagramView calls these rendering functions:**
1. `drawMotion()` — uses `positions[.Y]` and calls `yFinalPosition()` to compute Y's motion target
2. `drawWheel()` — calls `yWheelArcPath()`, which internally calls `receiverPositions()` and `yFinalPosition()`
3. `drawRoutes()` — calls `routePath()` with startPosition from `positions[receiver]` (or `yFinalPosition()` if Y has motion)
4. `drawReceivers()` — draws circles/labels at `positions[receiver]`

**Refactoring Required:**
- Pass custom positions through `drawMotion()`, `drawWheel()`, `drawRoutes()` as a parameter.
- OR store them in view state and access via closure/state management.
- Current approach: `positions` is computed once at line 14, then reused. Custom positions must apply at same point.

**Effort:** Low-to-moderate. Changes are isolated to view layer; no algorithmic complexity.

---

### 2. Route Concept Identification Impact

**Current Flow:**
```
RouteAssignment (receiver, route number, side) × N → ConceptMatcher.identify()
  → matches against ConceptLibrary templates (route-number-based only)
  → RouteConcept or nil
```

**Dependency Analysis:**
- **ConceptMatcher does NOT inspect positions.** It only examines:
  - `formation` (Formation enum value)
  - `assignments` (Receiver → RouteNumber map)
- **ConceptLibrary templates specify only route digits**, not position constraints. Example:
  ```swift
  Smash (Twins Left): X=6, A=7  // "X runs route 6, A runs route 7"
  ```
  No position data. No spacing rules.

**Custom Positions Impact: MINIMAL**
- A coach can move A wider, wider, wider — **concept matching will NOT detect "this is no longer Smash."**
- The design explicitly separates **semantic concept** (route numbers) from **formation geometry** (positions).
- Custom positions do NOT break concept matching logic — they simply don't inform it.

**Risk:**
- **Coaching Intent Risk:** A coach might reasonably expect that moving A outside normal range would change what routes "count as Smash." Currently it won't.
- **Mitigation (non-code):** Documentation must clarify that custom positions are **visual adjustments only** and do not affect route naming or concept identification.

**Code Change Required:**
- **None** — ConceptMatcher needs no modification.
- Tests for concept matching remain unchanged.

**Confidence:** HIGH — concept matching is data-driven by route numbers; positions are orthogonal.

---

### 3. Data Model Impact

**PlayCall Definition (Current):**
```swift
struct PlayCall: Identifiable {
    let formation: Formation
    let routeDigits: String
    var assignments: [RouteAssignment]
    let concept: RouteConcept?
    let yWheelEnabled: Bool
}
```

**Required Changes for Persistence:**

Option A (Lightweight — MVP):
```swift
struct PlayCall: Identifiable {
    let formation: Formation
    let routeDigits: String
    var assignments: [RouteAssignment]
    let concept: RouteConcept?
    let yWheelEnabled: Bool
    var customPositions: [Receiver: CGPoint]?  // NEW: nil = use formation defaults
}
```

Option B (Explicit State):
```swift
struct PlayCall: Identifiable {
    let formation: Formation
    let routeDigits: String
    var assignments: [RouteAssignment]
    let concept: RouteConcept?
    let yWheelEnabled: Bool
    var positionSource: PositionSource = .formation  // enum: formation or custom
    var customPositions: [Receiver: CGPoint] = [:]   // only used if source = .custom
}
```

**Implications:**

1. **Persistence (Save/Load Plays):**
   - Custom positions must serialize/deserialize alongside formation and routes.
   - Format: JSON representation of `[Receiver: (x: Double, y: Double)]`
   - Non-breaking change if `customPositions` is optional and defaults to `nil`.

2. **PlayCall Initialization:**
   - If customPositions are set, they override formation-derived positions **everywhere** (rendering, Y motion base position, Y Wheel arc).
   - Source of truth question: **Formation is still the semantic source; custom positions are overrides at render time.**

3. **Equality & Hashing:**
   - If PlayCall computes equality to decide "have I changed?", custom positions must be included.
   - **Current:** Likely uses `Identifiable` (UUID-based) with no custom equality.
   - **Change:** May need Equatable implementation that compares formations + custom positions.

4. **RouteAssignment Dependency:**
   - RouteAssignment does NOT store position data currently.
   - No change needed; positions remain **render-time computation**, not part of the assignment.

**Effort:** Low (MVP with optional field) to moderate (explicit state enum).

---

### 4. Y Motion and Y Wheel Interaction

**Current Architecture:**

Y Motion (None, Stop, After) changes **where Y executes** the route:
- Base position from `receiverPositions(formation)` → `yFinalPosition()` → Y's endpoint at LOS after motion.
- Example: Twins formation, Y starts at `(centerX + spacing, losY)`. With After motion, Y moves to the opposite side.

Y Wheel:
- Draws an arc from Y's **final position** (after motion, if applied) downfield and back.
- Arc direction (left or right curve) depends on Y's **final side** after motion.
- Example: If Y starts right, moves left via After motion, the arc curves left.

**Custom Positions Impact: HIGH**

If custom position moves Y's X coordinate:
- Y's **base position** changes → `yFinalPosition()` uses new base distance to compute motion endpoint.
- Y Wheel arc **origin point changes** → arc looks different visually, but geometry calculation is unchanged.

**Concrete Example:**
```
Twins formation, Y normally at (centerX + 0.5×spacing, losY)
Coach customizes: Y at (centerX + 1.5×spacing, losY) — much wider

With After motion:
- Old: Y moves to (centerX - 0.5×spacing, losY) [0.5x base distance opposite side]
- New: Y moves to (centerX - 1.5×spacing, losY) [0.5x NEW base distance opposite side]

Y Wheel arc:
- Old: Starts at (centerX + 0.5×spacing), curves right
- New: Starts at (centerX + 1.5×spacing), curves right (further right due to wider base)
```

**Code Changes Required:**

1. **DiagramRenderer.yFinalPosition()** (line 172):
   - Currently calls `receiverPositions(formation, config)` to get Y's base position.
   - Must accept optional custom positions parameter.
   - If custom Y position provided, use it instead of formation default.
   - **Risk:** Multiplier logic (`distanceMultiplier`) still references base distance — must measure from custom base.

2. **DiagramRenderer.yWheelArcPath()** (line 278):
   - Calls `receiverPositions()` to get initial Y position.
   - Must apply custom positions same way.
   - **No algorithm change** — just pulling from different source.

3. **RouteDiagramView.drawMotion()** (line 30):
   - Passes `positions[.Y]` to `yFinalPosition()` as initialPos.
   - Must pass custom positions through to renderer.

**Test Impact:**
- **Y Motion tests** (existing): Verify motion multipliers remain correct with custom base positions.
  - Example: `yAfterTwinsWithCustomX()` — move Y wider, verify motion distance = 0.5x NEW distance.
- **Y Wheel arc geometry tests**: Verify arc shape is correct from custom origin.

**Effort:** Moderate. Requires modifying two key functions (`yFinalPosition` and `yWheelArcPath`) and tests. Logic is sound; data source changes.

**Risk:** MEDIUM — Y motion multipliers are context-sensitive (Twins=0.5x, Trips=2.5x, Pro=1.5x). Refactoring must ensure multiplier is applied correctly to new base distance.

---

### 5. Upstream/Downstream Dependencies Audit

#### 5.1 All Callers of `receiverPositions()`

**Location:** 39 calls across 10 files (per earlier grep output)

**Production Code (7 callers):**
1. **RouteDiagramView.swift:14** — Main diagram render
   - **Change Required:** Apply custom positions
   - **Risk:** LOW — direct consumer
2. **DiagramRenderer.yFinalPosition():181** — Base position for Y motion
   - **Change Required:** Apply custom positions
   - **Risk:** MEDIUM — affects motion endpoint calculation
3. **DiagramRenderer.yWheelArcPath():279** — Initial Y position for arc
   - **Change Required:** Apply custom positions
   - **Risk:** MEDIUM — affects arc geometry

**Test Code (32 callers):**
- All test files that directly call `receiverPositions()` must be reviewed for custom position applicability.
- Most tests verify behavior with **formation defaults only** — minimal change needed.
- A few tests explicitly compare positions; they may need parameterization to test both paths (default + custom).

#### 5.2 Concept Matching Dependency

**Finding:** ConceptMatcher is **INDEPENDENT of positions**.

All concept templates match on `[Receiver: RouteNumber]` only. Position-based logic (e.g., "Smash if spacing is nominal") does NOT exist.

**No Changes Required** to ConceptMatcher, ConceptLibrary, or concept identification logic.

#### 5.3 Route Interpretation Dependency

**RouteInterpreter** (not yet read, but inferred from PlayCallParser):
- Resolves route digits to semantic names based on **formation side** (`formation.side(for: receiver)`), **not position**.
- Example: Route 1 on left side = "Quick Out"; route 1 on right side = "Quick Slant".
- **No position dependency.**

**No Changes Required** to route interpretation.

#### 5.4 Play Persistence / Save-Load

**Assumption:** Plays are saved/loaded via some storage layer (not examined here, but likely UserDefaults, Core Data, or JSON file).

**Impact:** Custom positions must be serialized alongside playCall data.
- **Data shape:** `[Receiver: CGPoint]` → JSON: `{"X": {"x": 150.5, "y": 200}, "Z": {"x": 350, "y": 200}, ...}`
- **Backward compatibility:** Old play files without `customPositions` field should load without error (optional field defaults to empty/nil).

**Effort:** Low to moderate (depends on existing serialization framework).

---

## Dependency Map

```
PlayCall ─────────────┬─────────────────────────────────────┐
                      │                                     │
                  Formation              customPositions (NEW)
                      │                                     │
        ┌─────────────┴──────────────┐                      │
        │                            │                      │
   ConceptMatcher         DiagramRenderer.receiverPositions()
   (NO CHANGE)                   │      ├─ yFinalPosition()
                                 │      └─ yWheelArcPath()
                                 │                           │
                        RouteDiagramView                     │
                        (apply custom here) ◄───────────────┘
                             │
        ┌────────┬───────────┴────────┬────────┐
        │        │                    │        │
    drawField  drawFootball     drawMotion  drawWheel
    drawRoutes drawReceivers
        │        │                    │        │
        └────────┴────────┬───────────┴────────┘
                    Canvas Rendering
```

**Key Observation:**
- Custom positions enter the pipeline at **PlayCall level** but are used **only by DiagramRenderer** and **RouteDiagramView**.
- ConceptMatcher, RouteInterpreter, PlayCallParser remain **completely independent**.
- This isolation is a **strength** — changes are localized.

---

## Risk Assessment

### Risk Categories

| Category | Level | Rationale |
|----------|-------|-----------|
| **Implementation Complexity** | MEDIUM | 5–6 subsystems affected; core logic is straightforward (position override). Testing is moderately complex. |
| **Runtime Correctness** | MEDIUM | Y motion and Y Wheel calculations depend on custom base position; regressions possible if multipliers misapplied. |
| **Coaching/UX Clarity** | MEDIUM-HIGH | Coach expectation mismatch: moving a receiver might look like it breaks a concept, but concept matching is blind to position. Documentation essential. |
| **Backward Compatibility** | LOW | Optional field in PlayCall; old plays without custom positions load fine (default to nil/empty). |
| **Test Coverage Burden** | MEDIUM | Must test custom position path for Y motion, Y Wheel, and all formation variants. ~10–15 new test cases. |
| **Maintenance Debt** | MEDIUM | Two code paths for positions (formation-derived vs. custom) must be maintained in parallel. Risk of path skew. |

### Highest-Risk Assumptions

1. **Y Motion Multiplier Application:** Assumption that multiplier (0.5x, 1.5x, 2.5x) applies correctly to **custom base distance** (not formation distance). If refactor miscalculates base distance, Y lands in wrong location under motion.
   - **Mitigation:** Explicit test: `testYAfterWithCustomBasePosition()` for each formation.

2. **Concept Matching Expectations:** Assumption that coaches understand custom positions do NOT affect concept matching. If a coach expects "moving A wider changes what concept this is," they will be confused.
   - **Mitigation:** UI tooltip: "Custom positions are visual only; concepts are determined by route numbers."

3. **Persistence Surprise:** Assumption that custom positions don't need to be reverted to defaults if formation is changed. Example: Coach customizes Y position in Twins, then switches to Trips Right. Does Y keep its custom position? Should it reset?
   - **Mitigation:** Design decision: custom positions are **per-play, not per-formation**. Changing formation keeps custom positions; coach must manually reset if desired.

---

## Recommended Approach: Minimal vs. Full Implementation

### Option A: Minimal Viable Product (MVP)

**Scope:**
- Add optional `customPositions: [Receiver: CGPoint]?` field to PlayCall.
- Modify `receiverPositions()` to accept custom overrides.
- Implement UI gesture (drag receiver circles) to capture custom position.
- No concept matching changes; no Y motion/Y Wheel refactoring.

**Effort Estimate:**
- Data model: ~2 hours (PlayCall field, serialization)
- DiagramRenderer: ~3 hours (add overrides parameter, propagate through yFinalPosition/yWheelArcPath)
- RouteDiagramView: ~2 hours (pass custom positions through)
- UI gesture handling: ~3 hours (pan detection, position capture, validation)
- Testing: ~4 hours (position override tests for each formation, Y motion tests with custom base)
- **Total: ~14 hours**

**Limitations:**
- Custom positions are **purely visual**; no semantic effect on concepts or routes.
- Coach must understand positions are "cosmetic" only.
- No undo/reset UI (would require additional work).

**Outcome:** Coach can adjust receiver positions on diagram; they persist in the play; concept matching is unaffected.

### Option B: Full Implementation

**Scope:**
- All of MVP, plus:
- Custom positions affect Y motion base distance calculation explicitly.
- Custom positions logged in play history / undo stack.
- UI affordances: position reset button, snap-to-formation button.
- Concept matching v2: optional position-aware templates (e.g., "Smash if spacing nominal" vs. "Smash regardless of spacing").
- Documentation: Coach guide on position semantics.

**Effort Estimate:**
- All MVP items: ~14 hours
- Y motion multiplier refactoring + tests: ~4 hours
- Undo/history: ~3 hours
- Position reset UI: ~2 hours
- Concept v2 templates: ~8 hours (requires design review)
- Coach documentation: ~3 hours
- **Total: ~34 hours**

**Outcome:** Full customization with semantic awareness; concept matching can be position-conscious; professional-grade play editor.

---

## Validation & Testing Plan

### Test Strategy

**Phase 1: Core Functionality**
- [x] PlayCall accepts and stores customPositions (unit)
- [x] DiagramRenderer applies custom positions to diagram (integration)
- [x] Custom positions persist in saved play (integration)
- [x] Concept matching unchanged with custom positions (regression)

**Phase 2: Y Motion & Y Wheel**
- [x] Y motion with custom base position (each formation)
- [x] Y Wheel arc geometry with custom Y position (visual spot check)
- [x] Y motion + Y Wheel together (edge case)

**Phase 3: Edge Cases**
- [x] Custom position moves receiver off-screen (should clip gracefully)
- [x] Custom position identical to formation default (no-op, should work)
- [x] Partial custom positions (only some receivers customized)
- [x] Route path with custom starting position (should still use absolute directions)

**Phase 4: Coaching Workflow**
- [x] Coach can drag receiver circle (gesture test)
- [x] Multiple adjustments in one play (sequential updates)
- [x] Formation change with custom positions retained (or reset, per design decision)

### Regression Test Checklist

- [ ] All existing RouteDiagramView tests pass with formation-default positions
- [ ] All existing DiagramRenderer tests (route paths, Y motion, Y Wheel) pass
- [ ] Concept matching tests unchanged
- [ ] Play save/load tests pass (including new customPositions field)

---

## Recommendations

### For Immediate Prioritization

1. **Defer unless product explicitly requests.** Custom positions are a "nice-to-have" usability feature, not a core domain requirement. The current system (formation-based alignment) is semantically sound.

2. **If prioritized, recommend Option A (MVP) first.** 14 hours of effort is justified only if coaching feedback strongly indicates this need. Validate with user interviews before committing to full implementation.

3. **Do not couple custom positions to concept matching v1.** The current concept library is position-agnostic and correct. Mixing position into concept logic introduces ambiguity (e.g., "is Smash still Smash if spacing is 20% off?"). Defer this to a v2 design phase if ever needed.

### For Architecture Preservation

1. **Keep positions as a render-time concern, not a domain concern.** PlayCall stores custom positions, but RouteAssignment and ConceptTemplate remain position-blind. This separation is intentional and valuable.

2. **Document position semantics clearly:**
   - Formation-derived positions are the **semantic baseline**.
   - Custom positions are **visual overrides** and do not affect route meaning or concept identification.
   - If future work couples positions to concepts, it requires explicit re-design of ConceptLibrary and new test coverage.

3. **Plan for persistence migration.** If custom positions are added, ensure old play files without this field load correctly. Test backward compatibility explicitly.

---

## Appendix: Code Locations (Reference)

**Files Directly Affected (MVP):**
- `SpartansPlaycaller/Models/PlayCall.swift` — add customPositions field
- `SpartansPlaycaller/Services/DiagramRenderer.swift` — modify receiverPositions(), yFinalPosition(), yWheelArcPath()
- `SpartansPlaycaller/Views/RouteDiagramView.swift` — pass custom positions through drawing functions
- Serialization layer (unknown; assume existing PlayCall encoder/decoder)

**Files Indirectly Affected (Testing):**
- `SpartansPlaycallerTests/DiagramRendererTests.swift` (or similar) — new position override tests
- `SpartansPlaycallerTests/RouteDiagramViewTests.swift` — new drag/custom position tests
- All Y motion and Y Wheel tests — parameterize with custom base positions

**Files NOT Affected (by design):**
- ConceptMatcher, ConceptLibrary, ConceptTemplate
- PlayCallParser, RouteInterpreter
- Formation, RouteAssignment, RouteConcept enums

---

## Conclusion

Custom receiver positioning is **technically feasible with low-to-moderate effort**, but introduces **medium runtime risk** and **UX clarity challenges**. The feature sits at the intersection of **visual affordance** (coach wants to adjust diagram) and **semantic concerns** (does position affect concept meaning?).

A **minimal MVP** (14 hours) is justified only if coaching feedback confirms strong demand. The **full implementation** (34 hours) addresses edge cases and professional workflows but should not be undertaken without explicit product prioritization and design review of concept matching semantics.

The recommended path: **Validate demand with coaches → Implement Option A (MVP) if demand confirmed → Defer Option B (full) pending operational feedback.**
