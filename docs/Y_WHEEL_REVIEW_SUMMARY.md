# Y Wheel Feature: Ken's Review Package

**Date:** 2026-05-29  
**Status:** Awaiting Ken's Approval  
**Next Step:** Ken reviews → approves/requests changes → implementation begins

---

## What You're Reviewing

Two comprehensive documents that establish the **contract** between design and implementation:

1. **`Y_WHEEL_REQUIREMENTS.md`** (9 sections)
   - Feature overview, formations & gating, arc geometry, UI, visibility
   - Four detailed test scenarios (A–D) describing exact expected behavior
   - Constraints and acceptance criteria for Ken to sign off on

2. **`Y_WHEEL_TEST_PLAN.md`** (9 parts)
   - Pre-implementation gating checks
   - Unit tests, manual UI tests, integration tests, regression tests
   - Device coverage matrix (iPhone SE, iPhone 15 Pro, iPad)
   - Execution log for tracking test results post-implementation

---

## How to Review

### For Requirements (`Y_WHEEL_REQUIREMENTS.md`):

**Read these sections first:**
1. **Section 2:** Formations and Gating — Does the table match your expectations?
   - Twins gets wheel but NOT motion
   - Trips/Pro get both motion and wheel
   
2. **Section 3:** Arc Geometry — Are the parameters correct?
   - loopDepth = 22% of field height
   - sideOffset = 5% of field width
   - Endpoint at 55% depth
   
3. **Sections 4.1–4.4:** Four Test Scenarios (A–D)
   - A: Twins Left, no motion → arc curves LEFT
   - B: Twins Left, After motion → arc curves RIGHT (Y flipped)
   - C: Twins Right, no motion → arc curves RIGHT
   - D: Twins Right, After motion → arc curves LEFT (Y flipped)
   
   **Question:** Do these four scenarios capture all the behaviors you want tested?

4. **Section 5:** UI Requirements
   - Motion picker unchanged (Trips/Pro only)
   - NEW: "Y Wheel" toggle below motion picker
   - Toggle visible in all formations (Twins, Trips, Pro)
   - Route displays as "Wheel" when enabled
   
   **Question:** Is toggle placement (below motion picker) acceptable?

5. **Section 9:** Acceptance Criteria Checklist
   - All the items Ken must verify before green-lighting implementation

**Approval Process:**
- [ ] Review all sections above
- [ ] Request any clarifications or changes
- [ ] Approve or ask for revisions
- [ ] Sign off in a comment like: "Approved per Section 9 checklist"

---

### For Test Plan (`Y_WHEEL_TEST_PLAN.md`):

**Focus areas:**

1. **Part 1: Pre-Implementation Checks** — Verify foundation is ready
   - Check Formation gating (Twins wheel, Trips/Pro motion)
   - Check ReceiverMotion.wheel case exists
   - Check route assignment can represent "Wheel"

2. **Part 2: Unit Tests** — Automated; verify logic is correct
   - Arc geometry math (Bézier curve)
   - Motion semantics (wheel stays on same side)
   - Formation gating

3. **Part 3: Manual UI Tests** — On-device verification
   - Test Groups A–F cover: presence, direction, post-motion, override, visual quality, edge cases
   - Four scenarios A–D from requirements are tested explicitly

4. **Part 4: Integration Tests** — End-to-end play flow
   - Concept matching with wheel
   - Full play call flow (formation → concept → wheel → motion)

5. **Part 6: Device Coverage**
   - iPhone SE (4.7"), iPhone 15 Pro (6.7"), iPad (12.9")
   - Focus: No clipping, arc visible at all sizes

**Review Checklist:**
- [ ] Is test coverage sufficient for the four scenarios A–D?
- [ ] Is device coverage (SE, Pro, iPad) reasonable?
- [ ] Are edge cases (toggle multiple times, switch formations, rotate device) comprehensive?
- [ ] Approve or request additional test cases

---

## If You Have Questions or Changes

1. **Clarification needed on requirements?**
   - Edit `Y_WHEEL_REQUIREMENTS.md` Section X
   - Re-read to ensure it matches your mental model

2. **Different test scenarios?**
   - Add to Sections 4.1–4.4 of requirements
   - Add corresponding manual tests to Part 3 of test plan

3. **Different formation gating?**
   - E.g., "Twins should NOT have wheel" or "All formations should support motion"
   - Edit Section 2 (Formations and Gating)
   - Implement agent will adjust accordingly

4. **Different arc geometry?**
   - E.g., "Arc should be deeper" or "sideOffset should be 10%, not 5%"
   - Edit Section 3 (Arc Geometry)
   - Update unit test in Part 2 correspondingly

---

## What Happens After Approval

1. **Software engineer** (implementation agent) reads both documents
2. Implements Y Wheel feature task-by-task per plan
3. Runs all automated tests (Parts 2, 4, 5)
4. Hands off to SDET for manual UI tests (Part 3, Part 6)
5. SDET executes on-device tests and produces test results report
6. Final build ready for field testing week of 2026-06-02

---

## Key Decisions Documented Here

| Decision | Location | Rationale |
|----------|----------|-----------|
| Twins gets wheel (no motion) | Req § 2, Test § 2.1 | Wheel is independent feature; Twins should have it |
| Wheel is independent toggle (not motion option) | Req § 1 | Coaches can use wheel regardless of motion selection |
| Arc is 22% field depth | Req § 3 | Balanced between other routes (15–25% range) |
| Four scenarios (A–D) cover all cases | Req § 4 | Left/right × motion-none/motion-active = 4 combos |
| UI: toggle below motion picker | Req § 5 | Clear, grouped control placement |
| Route displays as "Wheel" (not "Wheel Arc" or similar) | Req § 5 | Matches coach terminology |
| Field test on iPhone SE, Pro, iPad | Test § 6 | Covers smallest, primary, largest screens |

---

## Files Ready for Review

```
/Users/klewisjr/Development/iOS/spartans_playcaller/docs/
├── Y_WHEEL_REQUIREMENTS.md          ← START HERE
├── Y_WHEEL_TEST_PLAN.md             ← Then review this
└── Y_WHEEL_REVIEW_SUMMARY.md        ← You are here
```

---

## Next Steps (Ken Decides)

**Option A: Approve as-is**
- Documents are ready for implementation
- Software engineer begins work immediately
- No revisions needed

**Option B: Request clarifications/changes**
- Specify which sections need revision
- Updated documents re-submitted for approval
- Implementation begins after approval

**Option C: Defer specific scenarios or features**
- Document deferred items in backlog
- Move forward with core Y Wheel features
- Plan deferred features for future phase

---

## Questions for Ken

Before approving, consider:

1. **Twins formation:** Should Y Wheel be available in Twins even though motion is not?
   - Current spec: YES (wheel is independent)
   - Alternative: NO (only Trips/Pro get wheel)

2. **Arc depth:** 22% of field height — does this look right visually?
   - Current spec: loopDepth = fieldHeight × 0.22
   - If field is 812px, arc extends ~178px down
   - Matches YouTube mockup or different?

3. **Motion + Wheel behavior:** When Y has After motion AND Wheel enabled:
   - Arc should start from Y's **post-motion position**, right?
   - Arc direction reverses when Y flips sides?

4. **Route name:** Is "Wheel" the right display name?
   - Alternatives: "Semi-Circle," "Arc," "Loop"
   - Current spec uses "Wheel" (matches coach terminology)

5. **Field test scope:** Ready to test Y Wheel in field practice week of 06-02?
   - Or defer to later phase?

---

## Approval Template

When ready, Ken can respond with:

```
✅ **APPROVED per Y_WHEEL_REQUIREMENTS.md and Y_WHEEL_TEST_PLAN.md**

Status: Ready for Implementation

Clarifications / Changes:
(None, or list any revisions)

Field Test Date: Week of 2026-06-02 ✓

Signed: Ken Lewis, 2026-05-29
```

---

**Created:** 2026-05-29  
**Status:** Awaiting Ken's Review and Approval

