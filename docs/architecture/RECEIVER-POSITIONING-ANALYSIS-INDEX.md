# Receiver Positioning Customization: Complete Analysis Index

**Feature Request:** Allow coaches to manually adjust receiver positions on the diagram (independent of formation).

**Analysis Status:** Complete. No implementation. Ready for decision.

**Analysis Date:** 2026-06-03

---

## Quick Start

**TL;DR:** Feasible. 14–34 hours effort. Medium risk (Y motion requires care). **Validate coaching demand first.**

**For a quick decision, read these in order:**
1. **[receiver-positioning-decision-summary.md](receiver-positioning-decision-summary.md)** — 3 min read, decision framework
2. **[receiver-positioning-visual-flows.md](receiver-positioning-visual-flows.md)** — Diagrams and flows (5 min)
3. If questions remain: **[receiver-positioning-impact-analysis.md](receiver-positioning-impact-analysis.md)** — Deep dive (20 min)

---

## Documents in This Analysis

### 1. Decision Summary (START HERE)
**File:** [receiver-positioning-decision-summary.md](receiver-positioning-decision-summary.md)

**Length:** 2 pages (concise)

**Contains:**
- The ask (what coaches want)
- Core findings (5 key insights)
- Effort estimates (14 vs. 34 hours)
- Risk assessment summary
- Decision tree ("should we do this?")
- Bottom-line recommendation

**Audience:** Ken, product stakeholders. "Do we build this?"

**Read if:** You need to decide whether to prioritize this feature.

---

### 2. Visual Flows & Diagrams
**File:** [receiver-positioning-visual-flows.md](receiver-positioning-visual-flows.md)

**Length:** 4 pages (visual)

**Contains:**
- Data flow diagrams (current vs. proposed)
- Y motion sensitivity analysis with diagrams
- System isolation map (what doesn't change)
- Concept matching remains blind to positions
- Test coverage matrix (before/after)
- Effort breakdown by subsystem
- Risk heat map
- Architecture comparison

**Audience:** Engineers, architects. "How does this fit?"

**Read if:** You prefer visual explanations or need to understand the technical flow.

---

### 3. Full Impact Analysis
**File:** [receiver-positioning-impact-analysis.md](receiver-positioning-impact-analysis.md)

**Length:** 10 pages (comprehensive)

**Contains:**
- Problem statement with scope boundaries
- Detailed impact on 5 subsystems:
  - Diagram rendering pipeline
  - Route concept identification
  - Data model implications
  - Y motion and Y Wheel interaction
  - Upstream/downstream dependencies
- Dependency map with call chains
- Risk assessment by category
- Recommended approach (MVP vs. full)
- Validation & testing plan
- Architecture recommendations

**Audience:** Implementing engineers, technical leads. "What exactly breaks?"

**Read if:** You're doing the implementation or need to understand all edge cases.

---

### 4. Dependency Matrix (QUICK REFERENCE)
**File:** [receiver-positioning-dependency-matrix.md](receiver-positioning-dependency-matrix.md)

**Length:** 5 pages (reference)

**Contains:**
- Subsystem dependency grid (table)
- Call chain analysis with ASCII flowchart
- Isolated systems (no changes needed)
- Y motion multiplier sensitivity with code
- Y Wheel arc geometry sensitivity
- Serialization format (before/after JSON)
- Backward compatibility notes
- Test coverage summary table
- Change frequency analysis
- Implementation checklist (Option A)

**Audience:** Code reviewers, test planners. "What needs testing?"

**Read if:** You're reviewing the implementation or planning test coverage.

---

## Key Findings Summary

### Finding 1: Concept Matching Is Independent (CONFIDENCE: HIGH)

**ConceptMatcher does not inspect positions.** Templates match on route numbers only:
```swift
Smash = X(route 6) + A(route 7)  // No position constraint
```

**Implication:** Coaches moving receivers won't affect concept identification. **This must be documented clearly.**

---

### Finding 2: Five Subsystems Are Affected (CONFIDENCE: HIGH)

| Subsystem | Impact | Changes |
|-----------|--------|---------|
| PlayCall Model | Store custom positions | Add optional field |
| DiagramRenderer | Apply custom overrides | 3 methods updated |
| RouteDiagramView | Thread positions through | 4 draw functions updated |
| Y Motion | Base distance changes | yFinalPosition() refactored |
| Y Wheel | Arc origin shifts | Custom positions threaded |
| ConceptMatcher | **NONE** | **No changes** |
| ConceptLibrary | **NONE** | **No changes** |
| PlayCallParser | **NONE** | **No changes** |
| RouteInterpreter | **NONE** | **No changes** |

**Implication:** Feature is localized to rendering; domain logic is untouched. **This is a strength.**

---

### Finding 3: Y Motion Requires Careful Refactoring (CONFIDENCE: HIGH)

Custom position changes the base distance used by motion multiplier:

```swift
Twins: finalDistance = customBaseDistance × 0.5  // Not formation base
Trips: finalDistance = customBaseDistance × 2.5
Pro:   finalDistance = customBaseDistance × 1.5
```

**Implication:** Refactor is straightforward but error-prone. **Explicit test cases per formation required.**

---

### Finding 4: Effort Estimate: 14–34 Hours (CONFIDENCE: HIGH)

| Option | Scope | Hours |
|--------|-------|-------|
| **Option A (MVP)** | Custom positions visual only; coach drags receivers | 14 |
| **Option B (Full)** | MVP + undo/history + position-aware concepts | 34 |

**Implication:** MVP is justifiable if demand is strong. Full implementation is polish; defer unless explicitly requested.

---

### Finding 5: Risk Is Medium, Manageable (CONFIDENCE: MEDIUM)

| Risk | Level | Mitigation |
|------|-------|-----------|
| Y motion endpoint error | MEDIUM | Explicit tests for each formation |
| Coach confusion | MEDIUM-HIGH | Documentation + UI tooltip |
| Test coverage gaps | MEDIUM | 10–15 new test cases |
| Code path skew | MEDIUM | Regular review; keep parallel |

**Implication:** Risks are knowable and testable. **No architectural blockers.**

---

## Decision Framework

**Question:** Should we implement custom receiver positioning?

**Answer:** Depends on coaching demand and product prioritization.

```
1. Do coaches explicitly ask for this?
   └─ NO  → STOP. Close the idea. Current system is fine.
   └─ YES → Continue.

2. Can we accept "visual only" scope (no concept matching changes yet)?
   └─ NO  → Must design concept v2 first (major work). Not now.
   └─ YES → Continue.

3. Is 14-hour MVP justifiable in current backlog?
   └─ NO  → DEFER. Revisit next planning cycle.
   └─ YES → Implement Option A.

4. After MVP ships, do coaches want undo/history?
   └─ NO  → DONE. Keep Option A.
   └─ YES → Plan Option B for future cycle.
```

---

## Recommended Reading Order

### For Ken (Feature Decision)
1. This index (2 min)
2. Decision summary (3 min)
3. Decision tree (1 min)
→ Ready to decide.

### For Product Manager
1. This index (2 min)
2. Decision summary (3 min)
3. Visual flows (5 min)
4. Effort breakdown (2 min)
→ Ready to estimate backlog impact.

### For Lead Engineer (Implementation Planning)
1. This index (2 min)
2. Decision summary (3 min)
3. Visual flows (5 min)
4. Impact analysis (15 min)
5. Dependency matrix (5 min)
→ Ready to plan sprints and test strategy.

### For QA/Test Lead
1. Dependency matrix → Test coverage summary (3 min)
2. Impact analysis → Validation & testing plan (5 min)
3. Visual flows → Test coverage matrix (3 min)
→ Ready to write test plan.

### For Code Reviewer (During Implementation)
1. Dependency matrix (5 min)
2. Visual flows (5 min)
3. Impact analysis → Highest-risk assumptions (3 min)
→ Ready to review PRs.

---

## Key Decisions Already Made

These are embedded in the analysis. No further decision needed:

1. **Custom positions are render-time only** (not domain-level).
   - Rationale: Separates concerns; keeps concept matching clean.

2. **Concept matching stays position-blind** (MVP scope).
   - Rationale: Simpler initial scope; can add position awareness later if needed.

3. **Data model change: optional field in PlayCall** (not an enum switch).
   - Rationale: Backward compatible; old plays load correctly.

4. **Y motion multipliers apply to custom base distance** (not formation base).
   - Rationale: Correct semantics; Y lands where expected.

5. **Positions are per-play, not per-formation** (when formation changes, custom positions persist unless manually reset).
   - Rationale: Coaches may want to try same custom layout in different formations.

All decisions are documented in the Impact Analysis with rationale.

---

## Open Questions for Ken

Before committing to implementation, validate:

1. **Do coaches ask for this?** Have you heard direct requests for position customization?
2. **How often used?** Would coaches use this once per play, or rarely?
3. **Scope acceptance:** If positions don't affect concepts, is that OK with coaches?
4. **Timing:** Is this a next-cycle priority, or a future-cycle "nice-to-have"?
5. **Mobile UX:** Dragging receiver circles on small screen — is the gesture intuitive enough?

---

## Next Steps (If Approved)

### Step 1: Validate Demand (1–2 days)
- Interview 3–5 coaches: "Would you want to adjust positions on the diagram?"
- Record feedback and use cases.
- Update decision summary with findings.

### Step 2: Design Gesture UX (1 day)
- Wireframe: how coach drags, where feedback is shown, how to reset.
- Validate with coach (pairing session).
- Finalize UX spec.

### Step 3: Plan Implementation (1 day)
- Assign work items.
- Schedule reviews (architecture, implementation, test).
- Commit to timeline.

### Step 4: Implement Option A (2–3 days)
- Break into 3 stories: (1) data model, (2) rendering, (3) gesture UX.
- Daily check-ins on Y motion multiplier logic.
- Code review at each PR.

### Step 5: Test & Validate (1–2 days)
- Run full test suite.
- Manual E2E with coach.
- Performance check (gesture responsiveness on iPad).

### Step 6: Release (1 day)
- Merge to main.
- Deploy to App Store.
- Monitor for issues.

**Total Timeline:** ~1–2 weeks from approval to shipping Option A.

---

## Appendix: File Locations

All analysis files are in:
```
docs/architecture/
├── RECEIVER-POSITIONING-ANALYSIS-INDEX.md        (this file)
├── receiver-positioning-decision-summary.md       (decision)
├── receiver-positioning-impact-analysis.md        (deep dive)
├── receiver-positioning-dependency-matrix.md      (reference)
└── receiver-positioning-visual-flows.md           (diagrams)
```

Source code will be modified (if approved):
```
SpartansPlaycaller/
├── Models/PlayCall.swift                          (add customPositions field)
├── Services/DiagramRenderer.swift                 (position override logic)
└── Views/RouteDiagramView.swift                   (gesture handling)
```

Test files will be added:
```
SpartansPlaycallerTests/
├── ReceiverPositioningTests.swift                 (new)
├── YMotionCustomPositionTests.swift               (new)
└── [existing tests updated for custom paths]
```

---

## Document Version History

| Version | Date | Author | Status |
|---------|------|--------|--------|
| 1.0 | 2026-06-03 | Architecture & System Design | Complete. Ready for decision. |

---

## Questions?

- **For decision rationale:** See [receiver-positioning-decision-summary.md](receiver-positioning-decision-summary.md)
- **For technical details:** See [receiver-positioning-impact-analysis.md](receiver-positioning-impact-analysis.md)
- **For test planning:** See [receiver-positioning-dependency-matrix.md](receiver-positioning-dependency-matrix.md)
- **For visuals:** See [receiver-positioning-visual-flows.md](receiver-positioning-visual-flows.md)

---

## Bottom Line

| Aspect | Rating | Notes |
|--------|--------|-------|
| **Technically Feasible** | ✅ YES | No blockers. Architecture supports it. |
| **Implementation Effort** | 🟡 MEDIUM | 14 hours MVP, 34 hours full. Justifiable if demand is strong. |
| **Risk Level** | 🟡 MEDIUM | Y motion requires care. Risks are manageable with good testing. |
| **Coaching Value** | ❓ UNKNOWN | Validate demand before committing. |
| **System Impact** | ✅ LOW | Feature is localized. No core domain changes. |

**Recommendation:** **Validate coaching demand. If demand is strong, implement Option A (MVP) next cycle.**
