# Project Process Rules — Spartans Playcaller

This file documents process decisions and constraints specific to the Spartans Playcaller project. Updates here take precedence over generic workflows in `CLAUDE.md`.

---

## Visual and Spatial Features: Design and Iteration Strategy

### Problem Statement

AI agents have fundamental limitations when asked to design or iterate on **spatial geometry, 3D layouts, visual aesthetics, and route diagrams**. This limitation surfaces as:

- Agents struggle to extract precise parameters from verbal + visual descriptions
- Iterative feedback converges slowly (5+ rounds with diminishing returns)
- Agent interpretations diverge from Ken's spatial intent despite clear mockups
- Extended iteration cycles block feature shipping without improving output quality

**Example:** Y Wheel arc feature required multiple implementation cycles to approach (but not perfectly match) Ken's spatial intent. Agent-generated control points, sampling density, and endpoint angles diverged from reference mockups.

### Root Cause

This is a **tool capability limit**, not:
- Ken's communication clarity (he provided verbal descriptions + visual mockups)
- Process failure (iteration was structured and well-documented)
- Insufficient test coverage (tests passed; visual match was the bottleneck)

Agents can follow procedural steps and mathematical algorithms. Spatial reasoning—inferring 3D relationships, curvature, perspective, and directional intent from visual input—is outside their reliable capability envelope.

### Recommended Strategy

**For any visual or spatial feature:**

#### 1. Front-Load Spatial Definition (Spec Phase)

- **If Ken has a reference implementation:** Use it. Agent copy-from-reference > agent design-from-scratch.
- **If Ken has sketches/mockups:** Include them, but expect they'll need interpretation support.
- **If Ken describes verbally:** Provide both a written spec AND a visual mockup. One without the other is insufficient.

#### 2. Accept Early Compromise (Scope Gate)

Before starting implementation, agree: "Is perfect visual/spatial match required for ship, or is 'good enough + backlog refinement' acceptable?"

**Why:** Pursuing perfection on spatial details risks unbounded iteration.

#### 3. Use Iteration Signals (Decision Gates)

- **Green signal:** Feedback prompts code changes in the correct direction
- **Yellow signal:** Feedback produces orthogonal changes or no visible progress
- **Red signal:** After 3 rounds with no convergence → accept compromise or escalate

**Timing:** Assess signal after each iteration cycle (typically 1–2 hours of agent work).

#### 4. Require Ken's Visual Sign-Off (Acceptance Criterion)

Add to acceptance criteria:
> "Feature functions correctly (unit/integration tests pass) AND Ken confirms visual output matches design intent (or acceptable compromise)"

#### 5. Document the Compromise (Backlog Entry)

If you accept "good enough for now," create a backlog entry documenting what could improve and triggers for re-assessment.

### Decision Tree

```
Start: New spatial/visual feature required?
├─→ Does Ken have reference code? YES → Copy/adapt
├─→ Ken have sketch/mockup? YES → Include, plan 1-3 iterations
├─→ After Round 1: On right track? YES → Continue
├─→ After Round 2: Still converging? YES → Continue Round 3
├─→ After Round 3: Acceptable? YES → Ship + backlog
└─→ NO → Escalate (Ken reference code or defer)
```

---

## Related Norms From Kit

- **Artifact validation:** Features with visual components require Ken's sign-off on appearance
- **Practical solutioning:** Accept smallest reversible step (working feature + backlog) over unbounded iteration
- **Accountability:** Own the compromise; document it clearly for future retrospectives

---

## Scrum Master Guidance

When facilitating retros on spatial features:

1. Normalize the limitation: "Agents have trouble with spatial geometry; this isn't a process failure."
2. Celebrate the pragmatism: "We shipped a working feature rather than iterate endlessly."
3. Flag the backlog: "We documented the compromise; we can refine later if needed."
4. Plan for the next visual feature: Use this decision tree earlier to avoid repeated surprises.
