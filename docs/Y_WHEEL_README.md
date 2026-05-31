# Y Wheel Feature: Complete Review Package

**Date:** 2026-05-31  
**Status:** ✋ Ready for Ken's Review and Approval  
**Target:** Field test implementation (week of 2026-06-02)

---

## Quick Start: What to Review

### For Ken (Product Owner / Stakeholder)

**Time commitment:** ~30 minutes total  
**Order of documents:**

1. **START HERE: `Y_WHEEL_APPROVAL_CHECKLIST.md`** (8 min)
   - Navigation guide
   - Key approval steps
   - 5 critical questions to answer
   - Approval sign-off template

2. **`Y_WHEEL_REVIEW_SUMMARY.md`** (5 min)
   - What you're reviewing and why
   - Key decisions documented
   - Happens after approval

3. **`Y_WHEEL_REQUIREMENTS.md`** (15 min deep-read)
   - Full feature spec
   - Formations and gating rules
   - Four test scenarios (A–D)
   - Arc geometry parameters
   - UI requirements
   - Acceptance criteria

4. **`Y_WHEEL_TEST_PLAN.md`** (reference as needed)
   - Skim Parts 1–2 (foundation checks)
   - Skim Part 3 (manual UI tests)
   - Skim Part 6 (device coverage)
   - Full read optional (detailed for implementation)

### For Implementation Agent (Software Engineer)

**Start after Ken approves:**

1. Read all four documents in order (full read)
2. Implement feature per task-by-task plan in test plan (Part 7)
3. Run all automated tests as you go
4. Hand off to SDET for manual UI tests when ready

### For Test Agent (SDET)

**Start after implementation is complete:**

1. Read `Y_WHEEL_TEST_PLAN.md` Part 3 (Manual UI Tests)
2. Execute all test groups (A–F) on physical devices
3. Document results in Part 8 (Test Execution Log)
4. Produce final test results report

---

## Document Index

### 📋 For Review (3 documents)

| File | Size | Purpose | Read Time |
|------|------|---------|-----------|
| **Y_WHEEL_APPROVAL_CHECKLIST.md** | 8.0K | Navigation + approval steps | 8 min |
| **Y_WHEEL_REVIEW_SUMMARY.md** | 7.4K | Overview + key decisions | 5 min |
| **Y_WHEEL_REQUIREMENTS.md** | 14K | Complete feature spec | 15 min |

### 📊 For Implementation & Testing (2 documents)

| File | Size | Purpose | Audience |
|------|------|---------|----------|
| **Y_WHEEL_TEST_PLAN.md** | 27K | Detailed test strategy | Engineers & SDET |
| **Y_WHEEL_ARC_GEOMETRY.md** | 3.8K | Arc math deep-dive | Reference for implementer |

---

## Feature Summary (TL;DR)

**What is Y Wheel?**
- New Y receiver motion that renders as a smooth semi-circular arc
- Independent toggle (not a motion option like Stop/After/Go)
- Available in all formations (Twins, Trips Left/Right, Pro Left/Right)

**Key Spec:**
- Arc starts at Y's position, curves away from center, ends ~22% downfield
- Yellow smooth curve (~50 sampled points, no sharp corners)
- Route displays as "Wheel" (overrides numbered route when enabled)
- Smooth integration with existing motion (After/Go)

**Formations & Gating:**
| Formation | Wheel | Motion |
|-----------|-------|--------|
| Twins | ✅ YES | ❌ NO |
| Trips Left/Right | ✅ YES | ✅ YES |
| Pro Left/Right | ✅ YES | ✅ YES |

**Test Scenarios (A–D):**
- A: Twins Left, no motion → arc curves left
- B: Twins Left, After motion → arc curves right (Y flipped)
- C: Twins Right, no motion → arc curves right
- D: Twins Right, After motion → arc curves left (Y flipped)

---

## Ken's Approval Gate

**Before implementation can begin, Ken must:**

1. ✅ Review requirements (Sections 1–9)
2. ✅ Review test plan (Parts 1–6)
3. ✅ Answer 5 critical questions (in Approval Checklist)
4. ✅ Provide written approval (using template in Approval Checklist)

**Approval confirms:**
- Feature scope is correct
- Test coverage is sufficient
- Arc geometry parameters are acceptable
- UI design is approved
- Field test date is acceptable

---

## Critical Questions for Ken

**Before approving, consider:**

1. **Twins wheel availability?**
   - Current: YES (wheel is independent of motion)
   - Alternative: NO (only Trips/Pro)

2. **Arc depth correct?**
   - Current: 22% of field height
   - If different: What % should it be?

3. **Motion + wheel behavior?**
   - Arc starts from Y's post-motion position?
   - Arc direction reverses when Y flips sides?

4. **Route name "Wheel" correct?**
   - Alternatives: Semi-Circle / Arc / Loop

5. **Ready for field test week of 06-02?**
   - YES, proceed
   - NO, defer to later phase

---

## After Approval: Timeline

| Step | Agent | Duration | Deliverable |
|------|-------|----------|-------------|
| 1 | Software Engineer | 3–5 days | Feature implemented + tests passing |
| 2 | SDET | 1 day | Manual UI tests executed, results logged |
| 3 | QA | 1 day | Field test build prepared, shipped |

**Target:** Release build ready by 2026-06-01 (one day before field test week)

---

## Files Ready for Review

```
/Users/klewisjr/Development/iOS/spartans_playcaller/docs/

Y Wheel Review Package:
  ├── Y_WHEEL_APPROVAL_CHECKLIST.md     ← Start here (Ken)
  ├── Y_WHEEL_REVIEW_SUMMARY.md         ← Navigation guide
  ├── Y_WHEEL_REQUIREMENTS.md           ← Full spec (15 min read)
  ├── Y_WHEEL_TEST_PLAN.md              ← Test strategy (reference)
  └── Y_WHEEL_ARC_GEOMETRY.md           ← Geometry reference

Supporting Documentation:
  ├── Y_WHEEL_README.md                 ← You are here
  ├── docs/backlog/y-wheel-issues.md    ← Previous issues (resolved)
  └── docs/superpowers/plans/2026-05-29-route-interpretation-refactor-y-wheel.md ← Earlier plan
```

---

## FAQ: Before Ken Reviews

### Q: Do I need to read all documents?

**A:** Depends on your role:
- **Ken (Product):** Read Checklist + Summary + Requirements (~30 min)
- **Engineer (Implementation):** Read all documents (~2 hours)
- **SDET (Testing):** Read Test Plan Part 3 + 6 (~1 hour)

### Q: Can I approve conditionally?

**A:** No. Approval must be explicit:
- ✅ APPROVED (proceed immediately)
- ✏️ REVISIONS REQUESTED (specify what needs to change)
- 📅 DEFER (document why and when to revisit)

### Q: What if I disagree with the spec?

**A:** Request revisions. Sections to edit:
1. Req § 2 — Formations/gating
2. Req § 3 — Arc geometry
3. Req § 4 — Test scenarios
4. Req § 5 — UI design

Revised docs will be resubmitted for approval.

### Q: What if the arc looks wrong visually?

**A:** That's the point of field testing. Approve the current spec, implement it, test on-device, and iterate in next phase if needed.

### Q: Can we start implementing before approval?

**A:** No. Approval is a gate. This ensures:
- Ken's expectations are clear
- Test plan is correct before implementing
- No wasted effort on wrong feature
- Timeline is achievable

### Q: What about the existing `Y_WHEEL_ARC_GEOMETRY.md`?

**A:** That was from earlier design work. Use it as reference for arc math, but the **requirements doc** (`Y_WHEEL_REQUIREMENTS.md`) is the authority.

---

## Next Actions

### For Ken

1. Open `Y_WHEEL_APPROVAL_CHECKLIST.md`
2. Follow Steps 1–6
3. Answer 5 critical questions
4. Provide approval sign-off (using template)

### For Orchestrator

1. Await Ken's approval response
2. Once approved, dispatch **software-engineer** subagent
3. Provide all 4 documents
4. Implement feature
5. Run automated tests
6. Dispatch **SDET** for manual testing
7. Verify release build

### For Software Engineer

(After approval)

1. Read all documents
2. Implement task-by-task per test plan
3. Run unit/integration tests as you go
4. Commit incrementally
5. Hand off to SDET when ready

### For SDET

(After implementation)

1. Read test plan Part 3
2. Execute manual UI tests on devices
3. Document results in Part 8
4. Produce test results report

---

## Success Criteria (at each gate)

### Gate 1: Approval ✋
- [ ] Ken has reviewed all 3 documents
- [ ] Ken has answered 5 questions
- [ ] Ken has provided written approval
- [ ] All requirements are clear (no ambiguities)

### Gate 2: Implementation 🔨
- [ ] All automated tests pass
- [ ] Code compiles without warnings
- [ ] No regressions in existing features
- [ ] Feature matches requirements exactly

### Gate 3: Manual Testing 📱
- [ ] All manual test groups (A–F) pass on iPhone 15 Pro
- [ ] Arc doesn't clip on iPhone SE or iPad
- [ ] Rotation works correctly
- [ ] No visual artifacts or jank

### Gate 4: Field Test 🏈
- [ ] Release build created
- [ ] Build ships for week of 2026-06-02
- [ ] Ken can test on device
- [ ] Feedback collected for next phase

---

## Support & Questions

**If Ken has questions during review:**
- Add to `Y_WHEEL_REVIEW_SUMMARY.md` § "Questions for Ken"
- Request clarification from orchestrator
- Orchestrator updates docs and resubmits

**If engineer has questions during implementation:**
- Raise in code/PR comments
- Orchestrator clarifies or escalates to Ken
- Continue implementation

**If SDET finds test failures:**
- Dispatch software-engineer to fix
- Re-run tests until all pass
- Document root cause in test results report

---

## Document Versions

| Document | Version | Date | Status |
|----------|---------|------|--------|
| Approval Checklist | 1.0 | 2026-05-31 | ✋ Awaiting approval |
| Review Summary | 1.0 | 2026-05-31 | ✋ Awaiting approval |
| Requirements | 1.0 | 2026-05-31 | ✋ Awaiting approval |
| Test Plan | 1.0 | 2026-05-31 | ✋ Awaiting approval |
| Arc Geometry Ref | 1.0 | 2026-05-29 | ✅ Reference |

---

## Summary

**3 documents are ready for Ken's review:**
1. Y_WHEEL_APPROVAL_CHECKLIST.md — navigation
2. Y_WHEEL_REQUIREMENTS.md — full spec
3. Y_WHEEL_TEST_PLAN.md — test strategy

**Ken's task:** Review, answer 5 questions, provide written approval.

**Timeline after approval:** ~5 days to release build.

**Field test:** Week of 2026-06-02.

---

**Status:** ✋ **AWAITING KEN'S REVIEW AND APPROVAL**

**Next step:** Ken opens `Y_WHEEL_APPROVAL_CHECKLIST.md` and follows the approval steps.

