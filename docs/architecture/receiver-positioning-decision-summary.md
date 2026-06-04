# Receiver Positioning Customization: Decision Summary

**Question:** Should coaches be able to manually adjust receiver positions on the diagram?

**Answer:** **Yes, it's technically feasible. But validate coaching demand first.**

---

## The Ask

Coaches want to move receiver circles on the diagram (e.g., wider X, slot Y closer) **without changing the formation type or route meanings.** This is purely a **visual diagram adjustment** feature.

---

## Core Findings

### 1. Concept Matching Is Independent of Positions

**Key Discovery:** ConceptMatcher does NOT look at positions. It only examines route numbers.

- Template: `Smash = X(route 6) + A(route 7)` — no position constraint.
- If coach moves A wider, "Smash" is still identified because it's still route 6 + 7.
- **Implication:** Custom positions have **zero impact** on concept identification logic.

**Consequence:** This feature is **purely cosmetic**. A coach adjusting positions should understand they're not changing what route concept is being called.

### 2. Y Motion and Y Wheel Will Be Affected

**Y Motion Example:**
```
Twins formation (0.5x multiplier):
- Default Y position: centerX + 0.5×spacing
- Coach moves Y wider: centerX + 1.5×spacing
- With After motion: Y lands at (centerX - 0.75×spacing) instead of (centerX - 0.25×spacing)
```

Y motion endpoint **depends on the custom base position**, so calculation logic must be updated. **Risk is medium** — requires careful refactoring of `yFinalPosition()` to apply multiplier to custom distance, not formation distance.

Y Wheel arc origin point changes, but geometry algorithm remains the same. **Low risk.**

### 3. Five Subsystems Are Affected

| Subsystem | Impact | Code Changes |
|-----------|--------|--------------|
| DiagramRenderer | Core — positions are computed here | 3 methods must accept custom positions |
| RouteDiagramView | High — passes positions through all drawing | Thread custom positions through 4 draw functions |
| PlayCall Model | Medium — must store custom positions | Add optional field; serialization |
| Y Motion | High — base distance calculation | Refactor yFinalPosition() |
| Y Wheel | Medium — arc origin | Pass custom positions through |

### 4. Everything Else Is Untouched

- **ConceptMatcher:** No changes (positions ignored)
- **ConceptLibrary:** No changes (route-number-based templates)
- **PlayCallParser:** No changes (parses digits, not positions)
- **RouteInterpreter:** No changes (interprets by side, not position)
- **Route Paths:** No changes (breaks are absolute directions; custom start position doesn't change route geometry)

**This isolation is a major advantage.** Core domain logic is untouched; feature is localized to rendering layer.

---

## Effort Estimate

### Option A: Minimal Viable Product (MVP)
- Custom positions are **visual only** — no concept matching changes.
- Coach can drag receiver circles; positions persist in the play.
- **Effort:** 14 hours
- **Scope:** Data model change, renderer refactoring, UI gesture handling, testing.

### Option B: Full Implementation
- All of MVP, plus:
- Position-aware Y motion calculations (base distance updates correctly).
- Undo/history for position changes.
- Reset-to-defaults UI button.
- Professional documentation.
- **Effort:** 34 hours
- **Scope:** Adds ~20 hours of polish and operational support.

---

## Risk Assessment

| Risk | Level | Mitigation |
|------|-------|-----------|
| Y motion endpoint calculation error | MEDIUM | Explicit test cases for each formation (Twins 0.5x, Trips 2.5x, Pro 1.5x) |
| Coach confusion: "Doesn't moving A change the concept?" | MEDIUM-HIGH | Documentation + UI tooltip: "Custom positions are visual only" |
| Test coverage gaps in custom position paths | MEDIUM | 10–15 new test cases; parameterize Y motion tests |
| Backward compatibility (old plays without custom positions) | LOW | Optional field; old plays load with defaults automatically |
| Code path skew (custom vs. formation paths diverge) | MEDIUM | Regular code review; keep paths parallel and symmetrical |

---

## The Decision Tree

```
┌─ Do coaches explicitly ask for this feature?
│  ├─ YES → Proceed to Option A (MVP) validation
│  └─ NO → STOP. Insufficient demand. Keep current system (formation-based).
│
├─ If proceeding: Does product accept "visual only" scope?
│  ├─ YES → Implement Option A (14 hours)
│  └─ NO → Must design concept v2 (position-aware matching) first [MAJOR work]
│
└─ If Option A complete: Do coaches want undo/history/reset?
   ├─ YES → Proceed to Option B (full implementation)
   └─ NO → Keep Option A. Defer full implementation until demand arises.
```

---

## Recommendation for Ken

**Current Status:** No implementation. This is a design analysis only.

**Next Step:** **Talk to coaches.** Ask directly:
- "Would you want to adjust where receivers line up on the diagram?"
- "How often would you use this vs. just changing the formation?"
- "If you moved receiver A wider, would you expect that to change the concept name?"

**If Yes → Demand is strong:**
1. Plan Option A (MVP) as a feature story (14 hours; low risk).
2. Include in next backlog slice after current commitments are complete.
3. Test the gesture UX with a coach during implementation.

**If No → Not a priority:**
1. Close the idea. Current formation-based system is clean and sufficient.
2. Document this decision (already done here).
3. Revisit only if coaching feedback changes.

---

## Architecture Benefit

This feature, if implemented with care, would **not degrade** the system design. Here's why:

- **Positions remain render-time only.** PlayCall stores custom positions, but they don't affect domain logic (routing, concept matching).
- **Concept matching stays position-blind.** Good separation of concerns.
- **Two code paths are parallel, not divergent.** Formation defaults and custom overrides follow the same flow.
- **No new dependencies introduced.** Custom positions don't pull in new services or libraries.

**Conclusion:** The system is **architected well enough** to support this feature without major refactoring. If demand justifies it, the cost/risk is acceptable.

---

## Detailed Analysis Files

For deeper reading:
- **[receiver-positioning-impact-analysis.md](receiver-positioning-impact-analysis.md)** — Full impact analysis across 5 subsystems.
- **[receiver-positioning-dependency-matrix.md](receiver-positioning-dependency-matrix.md)** — Call chains, test matrix, serialization details.

---

## Key Quote from Analysis

> "The feature sits at the intersection of visual affordance (coach wants to adjust diagram) and semantic concerns (does position affect concept meaning?). A minimal MVP (14 hours) is justified only if coaching feedback confirms strong demand."

---

## Bottom Line

| Aspect | Rating | Notes |
|--------|--------|-------|
| **Technical Feasibility** | ✅ HIGH | No blockers; sound architecture supports it |
| **Implementation Complexity** | 🟡 MEDIUM | 14–34 hours; requires Y motion care |
| **Coaching Value** | ❓ UNKNOWN | Validate demand first |
| **Risk** | 🟡 MEDIUM | Manageable with good testing |
| **Maintenance Burden** | 🟡 MEDIUM | Two code paths to maintain |
| **Backward Compatibility** | ✅ HIGH | Optional field; no breaking changes |

**Recommendation:** **Feasible and low-risk MVP path exists. Validate demand before committing resources.**
