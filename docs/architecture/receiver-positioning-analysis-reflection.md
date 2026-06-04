# Receiver Positioning Analysis: Self-Reflection & Validation Plan

**As per Architecture discipline:** After substantive design output, identify assumptions that could be wrong, what would invalidate the design, and suggest cheap validation steps.

---

## Analysis Assumptions (High to Medium Confidence)

### 1. Concept Matching is Position-Blind (CONFIDENCE: HIGH)

**Assumption:** ConceptMatcher and ConceptLibrary do NOT examine receiver positions; all templates are route-number-based only.

**Evidence Supporting:**
- Read ConceptMatcher.swift (line 16–40): `identify()` method takes `[Receiver: RouteNumber]` only.
- Read ConceptTemplate.swift (line 15–23): `matches()` method compares route numbers.
- Read ConceptLibrary.swift (line 39–180): All templates defined as `receiverRoutes: [Receiver: RouteNumber]` with no position data.
- Grep search: No position-related logic found in ConceptMatcher or ConceptLibrary.

**What Would Invalidate:**
- Hidden position-based matching logic in a separate file or service not examined.
- Position-aware template matching that happens elsewhere in the pipeline (e.g., in RouteDiagramView or ViewModels).

**Cheap Validation:**
- Run this grep: `grep -r "spacing\|position\|proximity" SpartansPlaycaller/Services/ConceptMatcher.swift SpartansPlaycaller/Services/ConceptLibrary.swift`
- If no results: Assumption holds. Position is not checked during concept matching.
- **Effort:** 5 minutes. Run now.

---

### 2. Y Motion Multipliers Are Straightforward (CONFIDENCE: MEDIUM)

**Assumption:** Y motion applies a formation-specific multiplier (0.5x for Twins, 2.5x for Trips, 1.5x for Pro) to the **base distance from center** to compute the motion endpoint. This multiplier is simple and doesn't depend on other receiver positions.

**Evidence Supporting:**
- Read DiagramRenderer.swift (line 172–215): `yFinalPosition()` method shows:
  ```swift
  let distanceMultiplier: CGFloat
  switch formation {
  case .twins: distanceMultiplier = 0.5
  case .tripsLeft, .tripsRight: distanceMultiplier = 2.5
  case .proLeft, .proRight: distanceMultiplier = 1.5
  }
  let finalDistance = baseDistance * distanceMultiplier
  ```
- Formation-specific; no coupling to other receiver positions.

**What Would Invalidate:**
- Motion multiplier depends on other receiver positions (e.g., "Y moves 0.5x distance to nearest tackle").
- Distance calculation uses relative spacing between receivers, not absolute position.
- Edge cases where multiplier changes based on formation variant or Y Wheel state.

**Cheap Validation:**
- Write a unit test: Custom Y at 2x normal distance, apply Twins motion (0.5x), verify endpoint is 1.0x normal (2x × 0.5x).
  ```swift
  func testYMotionMultiplierWithCustomBase() {
      let customY = CGPoint(x: centerX + 2*spacing, y: losY)
      let final = renderer.yFinalPosition(
          initialSide: .right,
          finalSide: .left,
          motion: .after,
          formation: .twins,
          customYPosition: customY,
          config: config
      )
      // Expected: centerX - 1*spacing (2*spacing × 0.5)
      XCTAssertEqual(final.x, centerX - spacing, accuracy: 1)
  }
  ```
- **Effort:** 15 minutes. Run this test; if it passes, multiplier assumption holds.

---

### 3. Y Wheel Arc Geometry Doesn't Depend on Formation Spacing (CONFIDENCE: MEDIUM)

**Assumption:** Y Wheel arc is drawn from Y's final position using a fixed geometry (curve depth, lateral offset, return angle). The arc origin moves if Y is customized, but the arc shape is independent of formation.

**Evidence Supporting:**
- Read DiagramRenderer.swift (line 278–349): `yWheelArcPath()` method.
  - Gets Y's initial position (line 279).
  - Computes Y's final position if motion is present (line 291–304).
  - Calls `routePath()` for the arc geometry (line 324–329).
  - Inverts Y coordinates (line 334–337).
- The arc is drawn as inverted routes (1 or 2), not custom geometry.

**What Would Invalidate:**
- Arc geometry is parametrized by Y's distance from center (e.g., curve depth = 30% of distance).
- Arc must "snap to grid" or adjust based on neighboring receivers.
- Y Wheel has special behavior when custom positions overlap or are very close.

**Cheap Validation:**
- Write a visual test: Draw Y Wheel with Y at default position, then at 2x position. Verify both arcs are same shape, just at different origins.
- Capture screenshot PDFs and inspect visually.
- **Effort:** 20 minutes. No assertions needed; visual inspection is sufficient.

---

### 4. Route Paths Don't Depend on Receiver Spacing (CONFIDENCE: HIGH)

**Assumption:** Route breaks are absolute directions (route 3 = LEFT, route 4 = RIGHT, etc.) and don't depend on receiver position. Moving a receiver wider doesn't change the route shape; it just shifts the start point.

**Evidence Supporting:**
- Read DiagramRenderer.swift (line 81–158): `routePath()` method shows all routes use fixed geometry:
  ```swift
  case .three:
      let breakPoint = CGPoint(x: stemEnd.x - breakLen, y: stemEnd.y)  // Always left
  case .four:
      let breakPoint = CGPoint(x: stemEnd.x + breakLen, y: stemEnd.y)  // Always right
  ```
- Break distances are absolute (`breakLen` constant), not relative.

**What Would Invalidate:**
- Route breaks are context-aware (e.g., "route 3 breaks 90° toward nearest sideline").
- Break distance depends on receiver distance from center.
- Special behavior for receivers near edges.

**Cheap Validation:**
- Existing tests already cover this: grep for `testRoutePathAbsoluteDirection` or similar.
- If tests pass with custom positions applied, this assumption holds.
- **Effort:** 5 minutes. Review existing route path tests.

---

### 5. Custom Positions Can Be Stored as Optional Field (CONFIDENCE: HIGH)

**Assumption:** Adding an optional `customPositions: [Receiver: CGPoint]?` to PlayCall is backward compatible. Old plays without this field load correctly as `nil`, and new plays with custom positions serialize/deserialize without issue.

**Evidence Supporting:**
- PlayCall is Codable (inferred from architecture).
- Optional fields are a Swift standard pattern.
- No existing code depends on positions coming from Formation only (they're computed locally each render).

**What Would Invalidate:**
- PlayCall is manually serialized (not Codable), requiring custom encoding logic.
- Some code assumes positions are always derivable from Formation.
- Persistence layer doesn't support optional fields.

**Cheap Validation:**
- Check if PlayCall conforms to Codable: `grep "struct PlayCall.*Codable" SpartansPlaycaller/Models/PlayCall.swift`
- Check serialization tests: `grep -l "PlayCall.*encode\|decode" SpartansPlaycallerTests/*.swift`
- If Codable is used, add a field and run existing serialization tests. They should pass unchanged.
- **Effort:** 10 minutes.

---

### 6. Gesture UX (Dragging Receiver Circles) Is Feasible (CONFIDENCE: MEDIUM)

**Assumption:** SwiftUI Canvas-based views can capture pan gestures on receiver circles. The gesture recognition doesn't conflict with existing touch handling for other UI elements.

**Evidence Supporting:**
- RouteDiagramView uses Canvas (line 12).
- Canvas supports graphics context drawing but gesture interaction is limited.
- Workaround: Overlay gesture detection on Canvas, or wrap Canvas in a GeometryReader with gesture modifiers.

**What Would Invalidate:**
- Canvas doesn't support hit testing for drawn elements (true; Canvas is draw-only).
- Existing gesture handlers conflict with new pan detection.
- iPad Apple Pencil input requires special handling not available in current setup.

**Cheap Validation:**
- Prototype: Add a simple pan gesture on top of RouteDiagramView and log drag events.
  ```swift
  Canvas { ... }
    .gesture(DragGesture().onChanged { ... })
  ```
- Test on both iPhone and iPad simulator.
- **Effort:** 30 minutes. This is a known pattern; should work.

---

## Highest-Risk Assumptions (Medium-Low Confidence)

### Risk 1: Y Motion Multiplier Application with Custom Base

**Assumption:** When Y is at a custom position (e.g., 1.5x spacing), the motion endpoint calculation uses **custom baseDistance**, not formation base distance.

**Rationale:** Correct semantics — Y should move proportionally from its actual position, not from formation position.

**Why Risky:** Easy to accidentally use formation spacing in the calculation.

**Validation:**
- Code review: Line-by-line check of `yFinalPosition()` refactor.
- Unit tests: One test per formation (Twins, TripsLeft, TripsRight, ProLeft, ProRight).
- Integration test: Y motion + custom position in diagram view.
- **Effort:** 2 hours (code review + tests).

---

### Risk 2: Concept Matching Expectations

**Assumption:** Coaches understand that moving a receiver wider doesn't change what concept is called.

**Rationale:** Concepts are defined by route numbers, not positions. This is correct but non-obvious.

**Why Risky:** Coaching UX confusion. Coach expects "if I move A way out, Smash should change."

**Validation:**
- User research: Show coaches a diagram with custom position and ask "is this still Smash?"
- Documentation: Draft a coach-facing explanation of how concepts work.
- UI affordance: Tooltip or help text explaining concept matching is position-blind.
- **Effort:** 1–2 hours.

---

### Risk 3: Test Coverage of Y Motion Variants

**Assumption:** 5 formations × 3 motion types × (formation default + custom position) = 30 test cases is sufficient.

**Rationale:** Covers main paths; edge cases are rare.

**Why Risky:** Some formation+motion combinations might have unexpected behavior (e.g., Pro After/Go + custom Y).

**Validation:**
- Combinatorial test: Generate all 30 cases, run against golden values.
- Visual spot checks: Screenshots of Y motion + Y Wheel with custom positions.
- **Effort:** 3–4 hours.

---

## Assumptions That Could Be Invalidated By Shipping

### Assumption 1: Coaches Actually Want This

**Risk:** Ship the feature and discover coaches don't use it because the UX is awkward or the use case is rare.

**Mitigation:**
- Pre-validation (recommended): Talk to 3–5 coaches before implementation.
- Post-launch monitoring: Track feature usage (how many plays have custom positions).
- If usage is <5%, consider removing the feature in a future release.

---

### Assumption 2: Custom Positions Don't Introduce Performance Regressions

**Risk:** Checking and applying custom positions on every render frame causes a noticeable slowdown.

**Mitigation:**
- Performance test: Profile diagram rendering with and without custom positions.
- Measure frame rate (should stay 60 FPS on iPad).
- If regression detected, optimize (e.g., cache position overrides).

---

### Assumption 3: Gesture UX on iPad Is Intuitive

**Risk:** Dragging receiver circles on a small iPad screen is fiddly and frustrating.

**Mitigation:**
- Test with coaches on actual devices (iPhone + iPad).
- Adjust gesture sensitivity if needed (larger touch zones, snap-to-grid).
- Gather feedback and iterate before shipping.

---

## Cheap Validation Steps (Run Immediately)

If you want to validate this analysis without full implementation:

### Step 1: Concept Matching Independence (5 min)
```bash
# Verify ConceptMatcher doesn't reference positions
grep -E "position|spacing|proximity|distance" SpartansPlaycaller/Services/ConceptMatcher.swift SpartansPlaycaller/Services/ConceptLibrary.swift
# Expected: No results (or only in comments)
```

### Step 2: Serialization Pattern (5 min)
```bash
# Check if PlayCall uses Codable
grep -A 5 "struct PlayCall" SpartansPlaycaller/Models/PlayCall.swift | grep -i codable
# Expected: PlayCall is Identifiable and likely Codable-compatible
```

### Step 3: Y Motion Logic (10 min)
- Open DiagramRenderer.swift, jump to `yFinalPosition()` (line 172).
- Manually trace through the calculation with a custom base position.
- Verify multiplier is applied correctly.

### Step 4: Route Path Independence (5 min)
```bash
# Check if routePath depends on receiver spacing
grep -A 30 "func routePath" SpartansPlaycaller/Services/DiagramRenderer.swift | grep -E "spacing|distance|position|center"
# Expected: Only startPosition and config are used
```

### Step 5: Coach Feedback (30 min)
- Ask Ken: "Have you heard coaches ask for position customization directly?"
- If yes: Proceed with implementation planning.
- If no: Defer unless demand emerges.

---

## Residual Uncertainty

After this analysis, the following remain uncertain:

1. **Coaching demand is unknown.** Validate with interviews.
2. **iPad gesture UX is unproven.** Prototype and test.
3. **Performance impact is untested.** Profile after implementation.
4. **Full test coverage will be refined** during implementation (10–15 tests is estimate; actual may be 8–20).

**These are normal and acceptable for a design analysis.** They inform the next phase (validation, prototyping, implementation) but don't block a "go/no-go" decision on feasibility.

---

## Confidence Summary

| Area | Confidence | Why | Validation Effort |
|------|-----------|-----|-------------------|
| **Concept matching is position-blind** | HIGH | Code evidence clear | 5 min (grep) |
| **Y motion multipliers are straightforward** | MEDIUM | Logic is simple but riskier in practice | 15 min (test) |
| **Y Wheel geometry is position-independent** | MEDIUM | Shape doesn't change, origin does | 20 min (visual) |
| **Route paths don't depend on spacing** | HIGH | Absolute directions confirmed | 5 min (review) |
| **Optional field serialization is backward compatible** | HIGH | Swift standard pattern | 10 min (check) |
| **Gesture UX is feasible** | MEDIUM | Canvas has limitations; workaround likely | 30 min (prototype) |
| **Coaching demand is real** | UNKNOWN | Not validated | 30 min (interviews) |
| **Test coverage is sufficient** | MEDIUM | 10–15 cases planned; refinement needed | Ongoing |

---

## Recommendations for Validation

### Before Decision (Mandatory)

1. **Confirm coaching demand:** Ask coaches directly. Allocate 1 day.
2. **Validate assumption #1 (Concept Matching):** Run grep (5 min). Verifies core claim.
3. **Check serialization pattern:** Ensure PlayCall can accept optional field (10 min).

### Before Implementation (Recommended)

4. **Y Motion logic review:** Walk through `yFinalPosition()` with custom base (15 min).
5. **Route path test:** Verify existing tests pass (10 min).
6. **Gesture prototype:** Simple pan detection on Canvas (30 min).
7. **Coach feedback on "visual only" scope:** Confirm this limitation is acceptable (30 min interview).

### During Implementation (Required)

8. **Y motion unit tests:** One per formation (2 hours).
9. **Performance profile:** Diagram rendering with and without custom positions (1 hour).
10. **iPad gesture testing:** Real device, not simulator (1 hour).
11. **Full regression tests:** All existing tests pass (1 hour).

---

## Summary

**This analysis is grounded in code evidence for core findings** (concept matching, data model, Y motion logic). **Remaining uncertainties are well-understood and testable.** A 1-day validation sprint can de-risk the feature; implementation can proceed with confidence if validation passes.

**Recommendation: Validate coaching demand (high priority) and run the cheap validation steps above (5 min total). If both pass, plan Option A (MVP) implementation.**
