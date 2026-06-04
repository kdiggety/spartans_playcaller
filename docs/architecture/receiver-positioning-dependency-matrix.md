# Receiver Positioning: System Dependency Matrix

**Quick Reference:** What breaks if positions become customizable?

---

## Subsystem Dependency Grid

| Subsystem | Current Dependency on Positions | Impact of Custom Positions | Code Changes Required | Risk Level | Effort |
|-----------|--------------------------------|--------------------------|----------------------|-----------|--------|
| **PlayCall Model** | None (stores formation + routes only) | Must store custom positions as optional field | Add `customPositions: [Receiver: CGPoint]?` | LOW | 1 hour |
| **ConceptMatcher** | None (matches on route numbers only) | None — positions ignored | None | NONE | 0 hours |
| **ConceptLibrary** | None (templates are route-based) | None | None | NONE | 0 hours |
| **PlayCallParser** | None (parses digits to assignments) | None | None | NONE | 0 hours |
| **RouteInterpreter** | None (interprets routes by side) | None | None | NONE | 0 hours |
| **RouteAssignment** | None (stores receiver, route, side) | None | None | NONE | 0 hours |
| **DiagramRenderer.receiverPositions()** | **Core:** returns formation-derived positions | **Central:** must apply custom overrides | Modify signature to accept custom positions; add override logic | MEDIUM | 2 hours |
| **DiagramRenderer.yFinalPosition()** | **High:** uses base position to compute motion endpoint | **High:** base distance calculation depends on custom position | Accept custom positions, apply before multiplier math | MEDIUM | 2 hours |
| **DiagramRenderer.yWheelArcPath()** | **High:** uses Y's position for arc origin | **High:** arc geometry depends on Y position | Pass custom positions through; apply same override | MEDIUM | 2 hours |
| **RouteDiagramView** | **High:** calls receiverPositions() to get positions; passes to drawing functions | **High:** must thread custom positions through all draw calls | Modify drawMotion(), drawWheel(), drawRoutes(), drawReceivers() to accept custom positions | MEDIUM | 3 hours |
| **Gesture/UI Layer** | None (doesn't exist yet) | **Core:** must capture drag events and store adjusted positions | New: pan gesture detection on receiver circles, position capture, validation | MEDIUM | 4 hours |
| **Play Persistence** | None assumed (formation + routes serialized) | **Medium:** custom positions must serialize/deserialize | Add customPositions to PlayCall encoder/decoder (JSON or Codable) | LOW | 2 hours |
| **Tests** | Moderate (many tests call receiverPositions directly) | **Medium:** must validate custom position paths | Parameterize position tests; add custom position test cases (10–15 new) | MEDIUM | 5 hours |

---

## Call Chain Analysis

### Primary Path: Diagram Rendering

```
RouteDiagramView.body
  ├─ receiverPositions(formation) ← ENTRY POINT FOR CUSTOM POSITIONS
  │  (captures formation defaults, applies customPositions overrides)
  │
  ├─ drawField()          [uses fieldWidth/height, LOS — no position dependency]
  ├─ drawFootball()       [uses center position, formation-independent]
  ├─ drawMotion()
  │  ├─ positions[.Y]     [uses formation-derived or custom Y position]
  │  └─ yFinalPosition()  [MUST ACCEPT CUSTOM POSITIONS]
  │     └─ receiverPositions() [internal call — MUST ALSO APPLY CUSTOM]
  │
  ├─ drawWheel()
  │  └─ yWheelArcPath()   [MUST ACCEPT CUSTOM POSITIONS]
  │     ├─ receiverPositions() [internal call — MUST APPLY CUSTOM]
  │     └─ yFinalPosition() [MUST ACCEPT CUSTOM POSITIONS]
  │
  ├─ drawRoutes()
  │  ├─ positions[receiver] [uses custom or formation position]
  │  ├─ yFinalPosition() [if Y has motion — MUST ACCEPT CUSTOM]
  │  └─ routePath()     [starts at receiver position, uses ABSOLUTE directions]
  │
  └─ drawReceivers()
     └─ positions[receiver] [circles and labels]
```

**Refactoring Strategy:**
1. Compute `positions` **once** at top level, applying custom overrides.
2. Pass through to all draw functions.
3. For internal DiagramRenderer calls (yFinalPosition, yWheelArcPath), add custom positions parameter.

---

## Isolated Systems (No Change Required)

These subsystems are **completely independent** of receiver positions. No code changes needed.

### Route Interpretation
- **Function:** Parse digit to route meaning (e.g., route 1 on left = "Quick Out").
- **Inputs:** RouteNumber, FieldSide
- **No dependency:** Position, Formation geometry, spacing.
- **Why:** Route meaning is semantic (name label), not positional.

### Concept Matching
- **Function:** Identify known concepts from receiver route combinations.
- **Inputs:** [Receiver: RouteNumber], Formation
- **No dependency:** Position, spacing, formation-specific spacing rules.
- **Why:** Concepts are defined by route numbers only. No "Smash only if spacing is nominal" logic exists.

### Route Path Drawing (routePath)
- **Function:** Draw absolute-direction route breaks (3 LEFT, 4 RIGHT, 7 corner, 8 post).
- **Inputs:** RouteNumber, startPosition
- **Position dependency:** START POSITION ONLY. Break geometry is route-absolute, not position-aware.
- **Custom position impact:** None. Moving receiver wider doesn't change route 3's leftward break; it just starts from a different X.

---

## Y Motion Multiplier Sensitivity

**Critical Calculation Point:** `yFinalPosition()`

Custom positions change the **base distance** from center, which affects motion endpoint:

```swift
let baseDistance = abs(yBasePos.x - centerX)
let distanceMultiplier: CGFloat  // 0.5x (Twins), 1.5x (Pro), 2.5x (Trips)
let finalDistance = baseDistance * distanceMultiplier
let finalX = (finalSide == .right) ? centerX + finalDistance : centerX - finalDistance
```

**Scenario:**
```
Twins formation (0.5x multiplier):
- Formation default: Y at (centerX + 0.5×spacing, losY)
  → baseDistance = 0.5×spacing
  → finalDistance = 0.5×spacing × 0.5 = 0.25×spacing
  → Y After/Go lands at (centerX - 0.25×spacing)

- Coach customizes Y to (centerX + 1.5×spacing, losY)
  → baseDistance = 1.5×spacing
  → finalDistance = 1.5×spacing × 0.5 = 0.75×spacing
  → Y After/Go lands at (centerX - 0.75×spacing)  ← NEW ENDPOINT
```

**Risk:** If refactor accidentally uses **formation spacing multiplier** instead of **custom base distance**, Y lands in wrong spot.

**Mitigation:** Explicit test for each formation:
```swift
func testYAfterWithCustomBasePosition_Twins() {
    let customY = CGPoint(x: centerX + 1.5*spacing, y: losY)
    let finalPos = renderer.yFinalPosition(
        initialSide: .right,
        finalSide: .left,
        motion: .after,
        formation: .twins,
        customYPosition: customY,  // NEW PARAMETER
        config: config
    )
    XCTAssertEqual(finalPos.x, centerX - 0.75*spacing, accuracy: 1)  // 0.5x custom base
}
```

---

## Y Wheel Arc Geometry Sensitivity

Custom Y position affects **arc origin only**, not geometry algorithm:

```swift
let initialYPosition = customY ?? formation.defaultY(config)

// Arc is drawn from initialYPosition downfield and back
// Geometry is unchanged; only origin moves
```

**Impact:**
- Moving Y wider → arc is farther from center → visually offset, but shape is same.
- Moving Y narrower → arc closer to center.
- No mathematical risk; purely visual.

---

## Serialization Impact

### PlayCall Encoding (Before)
```json
{
  "id": "uuid-...",
  "formation": "Twins",
  "routeDigits": "6794",
  "assignments": [...],
  "concept": "Smash",
  "yWheelEnabled": false
}
```

### PlayCall Encoding (After)
```json
{
  "id": "uuid-...",
  "formation": "Twins",
  "routeDigits": "6794",
  "assignments": [...],
  "concept": "Smash",
  "yWheelEnabled": false,
  "customPositions": {
    "X": { "x": 150.5, "y": 200 },
    "Y": { "x": 325, "y": 200 },
    "Z": { "x": 420, "y": 200 },
    "A": { "x": 260, "y": 200 }
  }
}
```

**Backward Compatibility:**
- Old play files: `customPositions` field absent → `customPositions = nil` (or empty dict) → use formation defaults.
- New play files: `customPositions` field present → apply overrides.
- **No migration needed.** Optional field is forward/backward compatible.

---

## Test Coverage Summary

### Existing Tests (No Changes Required)

- **ConceptMatcherTests:** All pass unchanged (positions are irrelevant).
- **PlayCallParserTests:** All pass unchanged (positions are irrelevant).
- **RouteInterpreterTests:** All pass unchanged.
- **FormationTests:** All pass unchanged.

### New Tests (Custom Position Paths)

| Test Name | Category | Formation(s) | Coverage |
|-----------|----------|-------------|----------|
| `testReceiverPositionsWithCustom` | DiagramRenderer | All | Basic override logic |
| `testYFinalPositionWithCustomBase_Twins` | Y Motion | Twins | Base distance calc with 0.5x |
| `testYFinalPositionWithCustomBase_TripsLeft` | Y Motion | Trips Left | Base distance calc with 2.5x |
| `testYFinalPositionWithCustomBase_Pro` | Y Motion | Pro | Base distance calc with 1.5x |
| `testYWheelArcWithCustomY` | Y Wheel | All | Arc origin changes |
| `testYWheelArcWithCustomYAndMotion` | Y Wheel + Motion | All | Combined geometry |
| `testRoutePathWithCustomStart` | Route Drawing | All | Route breaks unchanged from custom start |
| `testDiagramViewThreadsCustomPositions` | Integration | All | Custom positions flow through view |
| `testPlayCallSerializesCustomPositions` | Persistence | All | Save/load with custom positions |
| `testPlayCallLoadsWithoutCustomPositions` | Backward Compat | All | Old plays load correctly |

**Estimated New Test Count:** 10–15 test cases (50–100 lines each).

---

## Change Frequency Analysis

**After implementation, these files require ongoing maintenance:**

| File | Reason | Maintenance Burden |
|------|--------|-------------------|
| PlayCall.swift | Core data structure | Medium (any change to position data affects serialization) |
| DiagramRenderer.swift | Position computation | Medium (two more parameters to track) |
| RouteDiagramView.swift | Position threading | Low-Medium (straightforward parameter passing) |
| UI Gesture Layer | Position capture | Medium (gesture handling is notoriously finicky) |
| Test files | Custom position paths | Medium (each formation-specific test needs custom variant) |

---

## Decision Framework

**Should we implement custom positions?**

| Question | Answer | Implication |
|----------|--------|------------|
| Is it on the critical path to MVP? | No | Defer unless explicitly requested |
| Do coaches ask for it? | Unknown (validate!) | Don't implement without user feedback |
| Is it technically sound? | Yes | Can be done; no architectural blocker |
| How much work? | 14–34 hours | Moderate effort; reasonable ROI if demand confirmed |
| How risky? | Medium (Y motion/Wheel) | Testable; risk is manageable with good test coverage |
| How maintainable? | Medium (two code paths) | Acceptable if documented well |

**Recommendation:** **Validate demand first.** If coaches repeatedly ask "can I adjust where receivers line up?" then Option A (MVP) is justified. Otherwise, the current formation-based system is cleaner and sufficient.

---

## Quick Implementation Checklist (Option A / MVP)

- [ ] Add `customPositions: [Receiver: CGPoint]?` to PlayCall
- [ ] Modify `receiverPositions(formation:config:)` → `receiverPositions(formation:customPositions:config:)` (or overload)
- [ ] Update `yFinalPosition()` to accept custom positions parameter
- [ ] Update `yWheelArcPath()` to accept custom positions parameter
- [ ] Thread custom positions through RouteDiagramView draw functions
- [ ] Add pan gesture handler to RouteDiagramView to capture position drags
- [ ] Add serialization for customPositions in PlayCall encoder/decoder
- [ ] Write 10–15 test cases covering custom position paths
- [ ] Verify all existing tests pass with formation-default positions
- [ ] Add documentation: "Custom positions are visual only; they do not affect concept matching"
- [ ] Release as minor feature (no breaking changes)
