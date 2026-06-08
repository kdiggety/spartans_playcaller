# PDF Card Playcall Labels — Retrospective

**Date:** 2026-06-08
**Feature:** PDF card header restructure + receiver letter labels (`pdf-card-playcall-labels`, PR #5)
**Workflow:** Feature Addition template (full end-to-end)
**Status:** SHIPPED

---

## Executive Summary

The feature shipped on 2026-06-08 with 29 new tests, zero new failures, a clean security plan review, and a clean security active verification. The full Feature Addition workflow was followed without skipping any gate. Two operational issues surfaced: test files not registered in `project.pbxproj` (a pattern now seen in two consecutive sprints) and disk exhaustion that blocked `git push` mid-feature. Visual sign-off from Ken remains pending — automated tests cannot verify visual correctness of PDF card output.

---

## What Went Well

### 1. Full Workflow Followed Without Shortcuts

Every step of the Feature Addition template executed in order: PO spec, specialist consultations, architecture design, planning gate (test strategy + performance assessment on disk before planning), security plan review, implementation, SDET verification, security active verification, PR merge, and retrospective. No gate was skipped.

### 2. Test Pyramid Balanced and Targeted

29 new tests structured deliberately: unit tests for `combinedHeaderString` and config constants (isolation), integration tests for both PDF generators and diagram renderer (structural correctness), and one context-integrity test validating the `saveGState`/`restoreGState` pattern. Zero new failures against a baseline of 9 pre-existing failures unchanged.

### 3. Security-by-Design Held

Light engagement scoped correctly — both plan review and active verification returned clean. REQ-SEC-1 through REQ-SEC-5 from Epic 3.1 remained intact. No false positives.

---

## What Could Improve

### Issue 1: Test Files Not Registered in project.pbxproj — Recurring Pattern

**What happened:** Both new test files (`PDFCardHeaderTests.swift` and `DiagramRendererReceiverLabelTests.swift`) were placed on disk but not registered in `project.pbxproj`. SDET discovered this during Step 7 and added `PBXBuildFile`, `PBXFileReference`, `PBXGroup`, and `PBXSourcesBuildPhase` entries.

**Pattern recognition:** Second consecutive sprint with this issue. Epic 3.1 had build failures from source files in `project.pbxproj` that didn't exist on disk (different direction, same gap). The implementing agent consistently treats "file exists on disk" as equivalent to "file is part of the build."

**Root cause:** No Xcode-specific norm distinguishes disk placement from project file registration.

**Action item (scope: project):** Added to `.claude/rules/project-process.md` — see "Xcode project.pbxproj Registration Rule" section.

---

### Issue 2: Disk Exhaustion Blocked `git push` During Task 6

**What happened:** During Task 6, `git push` failed because disk usage was ~97%. Required Ken to manually free space before the push could complete.

**Root cause:** No pre-flight disk check in the workflow. DerivedData and simulator runtimes accumulate silently.

**Action item (scope: project):** Added to `.claude/rules/project-process.md` — see "Disk Space Pre-flight Check" section.

---

### Issue 3: Visual Sign-Off as a Structural Open Item

**What happened:** 10 of 22 acceptance criteria are pending Ken's visual sign-off. Feature was merged before visual confirmation.

**This is not a new problem** — `project-process.md` already documents the visual features strategy. The ambiguity is whether "merged to main pending visual sign-off" counts as "shipped."

**Action item (scope: project):** Deferred to Ken for wording. Suggested policy: merge is permitted when automated tests pass + security is clean + pending sign-offs are logged as a backlog entry. Ken's visual confirmation closes the backlog item.

---

## Action Items Summary

| # | Action Item | Scope | Status |
|---|-------------|-------|--------|
| 1 | Xcode `project.pbxproj` registration rule | `scope: project` | Applied — `.claude/rules/project-process.md` |
| 2 | Disk space pre-flight check before push/build | `scope: project` | Applied — `.claude/rules/project-process.md` |
| 3 | Visual sign-off policy: clarify merge vs. ship definition | `scope: project` | Deferred — Ken approves wording |

---

## Lessons for Future Features

1. **"File exists" ≠ "file is in the build."** Every new Swift file requires explicit `project.pbxproj` registration. Treat this as part of task completion.
2. **Two occurrences makes a pattern.** `.pbxproj` gaps appeared in Epic 3.1 and again here — a norm was overdue.
3. **Disk health is operational infrastructure.** Near-full disk is as blocking as a compile error.
4. **Light security engagement works when the baseline is solid.** Proportionate review prevented overhead without missing risks.
5. **The planning gate continues to hold value.** Both test strategy and performance assessment on disk before planning — gate working as intended.

---

**Feature Status:** SHIPPED (automated verification complete; visual sign-off pending)
**New tests:** 29 pass, 0 fail
**Pre-existing failures:** 9 (unchanged baseline from Epic 3.1)
**Security verdict:** PASS (plan review + active verification)
**Action items:** 3 logged (2 project-scope applied immediately, 1 project-scope deferred to Ken)
**Facilitator:** Scrum Master
**Date:** 2026-06-08
