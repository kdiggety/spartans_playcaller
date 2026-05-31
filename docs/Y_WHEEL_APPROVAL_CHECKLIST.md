# Y Wheel Feature: Approval Checklist for Ken

**Date:** 2026-05-29  
**Scope:** Y Wheel independent toggle feature + field test preparation  
**Status:** ✋ **AWAITING KEN'S REVIEW AND APPROVAL**

---

## 📋 Documents to Review (in order)

1. **`Y_WHEEL_REVIEW_SUMMARY.md`** (5 min read)
   - Overview of what's being reviewed
   - Key decisions documented
   - Questions Ken should consider
   - Approval template at bottom

2. **`Y_WHEEL_REQUIREMENTS.md`** (15 min read)
   - Complete feature specification
   - Four test scenarios (A–D) describing exact behavior
   - Formation gating rules
   - Arc geometry parameters
   - UI/display requirements

3. **`Y_WHEEL_TEST_PLAN.md`** (10 min skim, reference as needed)
   - Pre-implementation checks
   - Automated tests (unit, integration, regression)
   - Manual UI tests (22 test groups on-device)
   - Device coverage matrix
   - Test execution log (to be filled in post-implementation)

---

## ✅ Ken's Approval Steps

### Step 1: Understand the Feature
- [ ] Read `Y_WHEEL_REVIEW_SUMMARY.md` (5 min)
- [ ] Understand: Y Wheel is an **independent toggle** (not a motion option)
- [ ] Understand: Wheel is available in **all formations** (Twins, Trips, Pro)
- [ ] Understand: Motion is only available in Trips/Pro, wheel is separate

### Step 2: Review Requirements
- [ ] Read Section 2 (Formations & Gating) in `Y_WHEEL_REQUIREMENTS.md`
  - Twins: Wheel YES, Motion NO
  - Trips/Pro: Wheel YES, Motion YES
- [ ] Read Section 3 (Arc Geometry)
  - Arc depth = 22% of field height
  - Endpoint at ~55% down arc path
  - Smooth curve (not segmented)
- [ ] Read Sections 4.1–4.4 (Four Test Scenarios A–D)
  - A: Twins Left, motion none → arc LEFT
  - B: Twins Left, motion After → arc RIGHT (post-motion)
  - C: Twins Right, motion none → arc RIGHT
  - D: Twins Right, motion After → arc LEFT (post-motion)

### Step 3: Verify UI Design
- [ ] Read Section 5 (UI Requirements) in `Y_WHEEL_REQUIREMENTS.md`
- [ ] Confirm toggle placement (below motion picker) is acceptable
- [ ] Confirm "Wheel" is the correct route name
- [ ] Confirm route override behavior (shows "Wheel" when enabled, hides number)

### Step 4: Review Test Coverage
- [ ] Skim Part 1 (Pre-Implementation Checks) in `Y_WHEEL_TEST_PLAN.md`
- [ ] Skim Part 2 (Unit Tests)
- [ ] Skim Part 3 (Manual UI Tests) — 22 test groups
- [ ] Skim Part 6 (Device Coverage) — iPhone SE, Pro, iPad
- [ ] Confirm coverage is sufficient

### Step 5: Answer Key Questions
Consider your answers to these questions (from `Y_WHEEL_REVIEW_SUMMARY.md`):

1. **Twins formation:** Should Y Wheel be available in Twins (no motion)?
   - [ ] YES, wheel is independent
   - [ ] NO, only Trips/Pro

2. **Arc depth:** 22% of field height correct?
   - [ ] YES, looks right
   - [ ] NO, should be _______ %

3. **Motion + Wheel:** Arc should start from Y's post-motion position?
   - [ ] YES
   - [ ] NO, explain: _______

4. **Route name:** Is "Wheel" the right name?
   - [ ] YES
   - [ ] NO, should be _______ (Semi-Circle / Arc / Loop / other)

5. **Field test timing:** Ready for week of 2026-06-02?
   - [ ] YES, ready to test
   - [ ] NO, defer to later phase

### Step 6: Provide Approval
Choose ONE:

#### Option A: ✅ APPROVED
```
Status: APPROVED
Ready for: Immediate implementation

Clarifications/Changes: None

Signed: Ken Lewis
Date: 2026-05-29
```

#### Option B: ✏️ REVISIONS REQUESTED
```
Status: REVISIONS REQUESTED
Changes needed:
- Section 2: Twins should NOT have wheel (only Trips/Pro)
- Section 3: Arc depth should be 30% (not 22%)
- Section 5: UI toggle should be "Wheel Off" / "Wheel On" (not ON/OFF)
- Other: [list any additional changes]

Timeline: Ken will update docs and resubmit by [date]

Signed: Ken Lewis
Date: 2026-05-29
```

#### Option C: 📅 DEFER
```
Status: DEFER
Reasoning: Focus on other priorities first
Deferred to: Phase [X], estimated [date]

Core features to proceed with now: [list what moves forward]
Deferred features for later: [list what's deferred]

Signed: Ken Lewis
Date: 2026-05-29
```

---

## 📌 Summary of Specifications

| Item | Specification | Section |
|------|---------------|---------|
| **Formations** | Twins, Trips Left/Right, Pro Left/Right | Req § 2 |
| **Wheel Availability** | All formations | Req § 2 |
| **Motion Availability** | Trips/Pro only | Req § 2 |
| **Wheel Interaction** | Independent of motion (can use both) | Req § 1 |
| **Arc Depth** | 22% of field height | Req § 3 |
| **Arc Appearance** | Smooth U-curve, yellow, ~50 sampled points | Req § 3 |
| **Route Display** | "Wheel" (overrides numbered route) | Req § 5 |
| **UI Control** | Toggle below motion picker | Req § 5 |
| **Test Scenarios** | 4 scenarios (left/right × motion/no-motion) | Req § 4 |
| **Device Coverage** | iPhone SE, iPhone 15 Pro, iPad | Test § 6 |
| **Field Test Date** | Week of 2026-06-02 | Test § 1 |

---

## 🚀 What Happens After Approval

1. **Ken approves** documents (Section 6 above)
2. **Software engineer** begins implementation (reads documents, implements feature)
3. **Automated tests** run as part of implementation (unit, integration, regression)
4. **SDET** executes manual UI tests on-device (Test Groups A–F)
5. **Test results** documented in test plan execution log (Test § 8)
6. **Release build** created for field testing
7. **Build shipped** for field test week of 2026-06-02

---

## 📂 File Locations

All documents are in: `/Users/klewisjr/Development/iOS/spartans_playcaller/docs/`

- **`Y_WHEEL_REVIEW_SUMMARY.md`** — Start here (navigation guide)
- **`Y_WHEEL_REQUIREMENTS.md`** — Full requirements spec
- **`Y_WHEEL_TEST_PLAN.md`** — Complete test strategy
- **`Y_WHEEL_ARC_GEOMETRY.md`** — Previous geometry deep-dive (reference)
- **`Y_WHEEL_APPROVAL_CHECKLIST.md`** — This file

---

## 🎯 Definition of "Approved"

**Approved means:**
- [ ] Ken has reviewed Requirements (Sections 1–9)
- [ ] Ken has reviewed Test Plan (Parts 1–6)
- [ ] Ken has answered Key Questions (5 questions above)
- [ ] Ken has chosen an Approval option (A, B, or C)
- [ ] Ken has signed off with date
- [ ] All requirements are in writing (this document or requirements doc)
- [ ] No ambiguities remain (or they're explicitly documented as "TBD")

**NOT approved means:**
- Ken's approval is conditional ("let me see mock-ups first")
- Requirements have unresolved questions
- Test plan is incomplete
- Approval is verbal-only (must be in writing)

---

## ❓ If You Have Questions

**During Review:**
1. Add question to `Y_WHEEL_REVIEW_SUMMARY.md` Section "Questions for Ken"
2. Request clarification from software engineer
3. Update requirements/test plan as needed
4. Return to approval step

**During Implementation:**
1. Software engineer will raise any ambiguities
2. Ken clarifies in real-time
3. Implementation adjusts if needed
4. Test plan updated if scope changes

**During Testing:**
1. SDET may discover implementation gaps
2. Return to implementing agent to fix
3. Re-test until all pass
4. Document in test execution log

---

## 📝 Approval Sign-Off Template

When ready to approve, please respond with:

```
========================================
Y WHEEL FEATURE: KEN'S APPROVAL
========================================

Status: ✅ APPROVED

Documents reviewed:
  ✅ Y_WHEEL_REVIEW_SUMMARY.md
  ✅ Y_WHEEL_REQUIREMENTS.md
  ✅ Y_WHEEL_TEST_PLAN.md

Key decisions confirmed:
  ✅ Twins gets wheel (independent)
  ✅ Arc depth: 22% of field
  ✅ Scenarios A–D are correct
  ✅ UI: toggle below motion picker
  ✅ Field test: week of 2026-06-02

Ready for implementation: YES

Signed: Ken Lewis
Date: [today's date]
========================================
```

---

## 🔄 After Approval

Once Ken approves, the orchestrator will:

1. Dispatch **software-engineer** subagent
2. Provide this document + requirements + test plan
3. Implement feature task-by-task per detailed plan
4. Run all automated tests
5. Dispatch **SDET** for manual UI tests
6. Verify release build for field testing

---

**Status:** ✋ **AWAITING KEN'S APPROVAL**

**Next Action:** Ken reviews documents above, answers key questions, provides approval sign-off.

