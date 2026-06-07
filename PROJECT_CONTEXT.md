# Project context

```yaml
domain: "Football coaching / play calling"
primary_users: "Football coaches and coordinators using a custom route nomenclature system"
risk_profile: "personal project"
constraints:
  compliance: "none"
  regions_deployment: "App Store (US initially)"
tech_stack_summary: "iOS 17+ / SwiftUI / MVVM / Canvas rendering / Xcode 15+"
non_goals: "Backend services, multiplayer/networking, Android support"
success_signals: "Clean builds, correct route interpretation per nomenclature spec, visual accuracy of diagrams"

ci_runner:
  type: "github-hosted"
```

## Domain Summary

Spartans Playcaller is a native iOS app that implements a **custom football route nomenclature system** where route numbers are STATIC but their MEANING changes based on receiver field alignment (left vs right side of the ball). This is NOT standard mirrored football terminology.

The app generates play calls from named concepts, parses route digit sequences into receiver assignments, identifies known concepts from arbitrary digit input, and renders route diagrams on a Canvas.

## Core Domain Rules

- **Receivers**: X (always left), Z (always right), Y (moves by formation), A (moves by formation, always outside X or Z), H (optional RB)
- **Digit sequence**: Always X, Y, Z, A, H — 4 digits minimum, 5 with H
- **Side-aware interpretation**: Same route number produces different route meanings on left vs right (e.g., "1" = Quick Out on left, Quick Slant on right)
- **Absolute direction routes**: 3 ALWAYS breaks left, 4 ALWAYS breaks right, 7 ALWAYS angles top-left, 8 ALWAYS angles top-right — regardless of receiver side
- **Formations**: See Formations table below; all support Y Motion (None, Stop, After/Go) and Y Wheel toggle
- **Concepts**: Named combinations (Smash, Dagger, Verts, Scissors, Sail, China) that map to specific receiver-route templates per formation

## Route Nomenclature

Every route has an **absolute visual direction** (always breaks the same screen direction regardless of receiver field position) and a **side-aware semantic label** (the name changes per side because the same break is toward the sideline for one receiver and toward the center for another).

| Route | Stem | Visual Direction | LEFT Semantic | RIGHT Semantic |
|-------|------|-----------------|--------------|---------------|
| 0 | Short (30%) DOWN | Short stem into backfield, no break | Hitch | Hitch |
| 1 | Short (25%) | Always LEFT 45° | Quick Out | Quick Slant |
| 2 | Short (25%) | Always RIGHT 45° | Quick Slant | Quick Out |
| 3 | Full (100%) | Always LEFT 90° | Out | Dig/In |
| 4 | Full (100%) | Always RIGHT 90° | Dig/In | Out |
| 5 | Full (100%) | Always back-LEFT (curls downfield) | Comeback | Curl |
| 6 | Full (100%) | Always back-RIGHT (curls downfield) | Curl | Comeback |
| 7 | Full (100%) | Always top-LEFT 45° (continues upfield) | Corner | Post |
| 8 | Full (100%) | Always top-RIGHT 45° (continues upfield) | Post | Corner |
| 9 | Deep (150%) | Straight vertical, no break | Go/Fade | Go/Fade |

Routes 0 and 9: constant (same label both sides).
Routes 1–8: side-aware (label flips per side). Visual direction NEVER mirrors — always the same absolute screen direction regardless of receiver position.

## Formations

All formations support Y Motion. H (RB) is an optional 5th receiver at center in all formations.

| Formation | Family | Type | LEFT Receivers (outside→inside) | RIGHT Receivers (inside→outside) | Y Side |
|-----------|--------|------|---------------------------------|----------------------------------|--------|
| Twins | Twins | 2×2 | X (outside), A (inside) | Y (inside), Z (outside) | Right |
| Trips Left | Trips | 3×1 | A (outside), X, Y (inside) | Z (isolated) | Left |
| Trips Right | Trips | 1×3 | X (isolated) | Y (inside), Z, A (outside) | Right |
| Pro Left | Pro | 2×1 | X (outside), Y (inside/slot) | Z (isolated) | Left |
| Pro Right | Pro | 1×2 | X (isolated) | Y (inside/slot), Z (outside) | Right |

**Inviolable receiver rules:**
- X is ALWAYS on the LEFT side
- Z is ALWAYS on the RIGHT side
- Y is ALWAYS the inside receiver on its designated side
- A is outside X (Twins left) or outside Z (Trips/Pro right), depending on formation

## Y Motion

Motion picker shows three options: **None | Stop | After/Go**
- None and Stop both leave Y in its original position (combined in this table)
- After/Go sends Y to the opposite side at 2.5× its original distance from center

| Formation | Motion | Resulting Layout | Concept Logic |
|-----------|--------|-----------------|---------------|
| Twins | None / Stop | X, A left \| Y, Z right | Twins matching |
| Twins | After/Go | Y, X, A left \| Z right (3×1-like) | Evaluate each side independently — NOT native Trips Left (Y lands outside X, reversed from Trips ordering) |
| Trips Left | None / Stop | A, X, Y left \| Z right | Trips Left matching |
| Trips Left | After/Go | A, X left \| Y, Z right (2×2-like) | Evaluate each side independently — NOT native Twins (A is outside left, not X) |
| Trips Right | None / Stop | X left \| Y, Z, A right | Trips Right matching |
| Trips Right | After/Go | X, Y left \| Z, A right (2×2-like) | Evaluate each side independently — NOT native Twins (Y is inside left, not A) |
| Pro Left | None / Stop | X, Y left \| Z right | Pro Left matching |
| Pro Left | After/Go | X left \| Y, Z right (1×2-like) | Evaluate each side independently — NOT native Pro Right (Y lands at 2.5× distance, not Pro Right slot) |
| Pro Right | None / Stop | X left \| Y, Z right | Pro Right matching |
| Pro Right | After/Go | X, Y left \| Z right (2×1-like) | Evaluate each side independently — NOT native Pro Left (Y lands at 2.5× distance, not Pro Left slot) |

**Key principle:** Y After/Go relocates Y at 2.5× its original distance from center on the opposite side.
This changes receiver count per side but does NOT replicate native formation alignments.
Concept matching after motion always evaluates each side independently based on actual receivers present — never map a post-motion layout to a native formation type.

## Y Wheel

Y Wheel is an independent toggle that works with any motion (None, Stop, After/Go).
When enabled: Y's numbered route is hidden and replaced with a smooth U-shaped arc that curves away from the LOS toward Y's final side.

**Arc direction rule:** Arc always curves toward Y's FINAL side (after motion is applied).

| Formation | Motion | Y Final Side | Wheel Arc Direction |
|-----------|--------|-------------|---------------------|
| Twins | None / Stop | Right | Curves RIGHT (away from center, toward right sideline) |
| Twins | After/Go | Left | Curves LEFT (away from center, toward left sideline) |
| Trips Left | None / Stop | Left | Curves LEFT |
| Trips Left | After/Go | Right | Curves RIGHT |
| Trips Right | None / Stop | Right | Curves RIGHT |
| Trips Right | After/Go | Left | Curves LEFT |
| Pro Left | None / Stop | Left | Curves LEFT |
| Pro Left | After/Go | Right | Curves RIGHT |
| Pro Right | None / Stop | Right | Curves RIGHT |
| Pro Right | After/Go | Left | Curves LEFT |

**Arc geometry:**
- Starts at the bottom of Y's circle (post-motion position)
- Curves downfield (away from LOS) at ~30% field width lateral offset
- Smooth U-shape with ~25% field height loop depth
- Returns toward LOS at ~45° angle (endpoint tilted, not symmetric)
- Arrow at endpoint points back toward LOS
- Solid yellow line (distinct from motion's dashed yellow arc)

**Concept matching with Y Wheel:**
- Trips formations only: evaluates the other two receivers' route combinations
- Twins and Pro: Y Wheel does not apply concept matching logic
- Y Wheel classification is secondary to standard route identification

## Route Concepts

**Principle:** Any 2 receivers on the same side can form a route concept by combining their individual routes. Named concepts (Smash, Dagger, etc.) are well-known combinations from the playbook; arbitrary 2-receiver combinations are also valid.

### Possible 2-Receiver Combinations by Formation

**Twins (2×2, one pairing per side):**
- Left side: X + A (1 combination)
- Right side: Y + Z (1 combination)

**Trips Left (3×1, three pairings on the left):**
- A + X, A + Y, X + Y (any pair from {A, X, Y})
- Right: Z (isolated, no pairing)

**Trips Right (1×3, three pairings on the right):**
- Left: X (isolated, no pairing)
- Y + Z, Y + A, Z + A (any pair from {Y, Z, A})

**Pro Left (2×1, one pairing on the left):**
- Left side: X + Y (1 combination)
- Right: Z (isolated, no pairing)

**Pro Right (1×2, one pairing on the right):**
- Left: X (isolated, no pairing)
- Right side: Y + Z (1 combination)

### Named Concepts in the Playbook

| Concept | Structure | Twins Left | Twins Right | Trips Left | Trips Right | Pro Left | Pro Right |
|---------|-----------|-----------|-----------|-----------|-----------|---------|-----------|
| **Smash** | X/Z + Y/A (Curl + Corner) | X(Curl) + A(Corner) | Y(Corner) + Z(Curl) | X(Curl) + Y(Corner) [+A(Dig/In)] | Y(Corner) + Z(Curl) [+A(Q.Slant)] | X(Curl) + Y(Corner) | Y(Corner) + Z(Curl) |
| **Dagger** | X/Z + Y/A (Dig/In + Go) | X(Dig/In) + A(Go) | Y(Go) + Z(Dig/In) | X(Q.Out) + Y(Go) [+A(Dig/In)] | Z(Q.Out) + Y(Go) [+A(Dig/In)] | X(Dig/In) + Y(Go) | Y(Go) + Z(Dig/In) |
| **Scissors** | X/Z + Y/A (Post + Corner) | X(Post) + A(Corner) | Y(Corner) + Z(Post) | X(Post) + Y(Corner) [+A(Curl)] | Y(Corner) + Z(Post) [+A(Curl)] | X(Post) + Y(Corner) | Y(Corner) + Z(Post) |
| **Sail** | X/Z + Y/A (Go + Out) | X(Go) + A(Out) | Y(Out) + Z(Go) | X(Go) + Y(Out) [+A(Q.Slant)] | Z(Go) + Y(Out) [+A(Q.Slant)] | X(Go) + Y(Out) | Y(Out) + Z(Go) |
| **China** | Trips 3-receiver (Smash variant) | — | — | X(Curl) + Y(Corner) + A(Curl) | Y(Corner) + Z(Curl) + A(Curl) | — | — |

**Note:** Route semantic names (Curl, Corner, Go, etc.) are side-resolved per the Route Nomenclature table—the route digit is constant, but the name label flips for side-aware routes (1–8). Square brackets `[+A(·)]` indicate third-receiver routes in Trips formations (concept matching for Trips evaluates all three receivers; for non-Trips, only the primary pairing is matched).

## Architecture

```
SpartansPlaycaller/
├── Models/          # Enums and value types (Formation, Receiver, RouteNumber, etc.)
├── Services/        # Business logic (Parser, ConceptLibrary, ConceptMatcher, DiagramRenderer)
├── ViewModels/      # MVVM view models
└── Views/           # SwiftUI views including Canvas route diagram
```

## Completed Features

**Y Wheel Arc & Formation Spacing (2026-06-07):** Y Wheel toggle renders smooth U-shaped arc curving toward Y's final side. Formation receiver spacing tuned (0.16w) for visual balance and Y motion separation. Y After/Go multipliers: Twins 0.5x, Trips 2.5x, Pro 1.5x. All tests passing (92 Y motion tests, 18 diagram tests).

See: `docs/retrospectives/2026-06-07-y-wheel-spacing-retro.md`

---

## Future Expansion & Roadmap

### Immediate (Next 2 Weeks) — CRITICAL & HIGH ROI

**1. Wristband Export (Epic 3.1) — CRITICAL for game-day deployment**
- Multi-select plays from app
- Export to PDF (single-page grid or per-card format)
- Print or share via email/Files app
- Unblocks production deployment and coaching adoption
- Effort: 20–24 hours
- **Status:** Ready to spec

**2. Empty Formation (Epic 2.1) — Highest ROI formation**
- Modern 4-wide pass formation (X far left, Y slot-left, Z slot-right, A far right)
- Enable 6–8 Empty-specific concepts (Stick, Double Slant, Dig Cross, etc.)
- Support Y motion in Empty (spacing allows)
- Effort: 8–12 hours
- **Status:** Ready to implement

**3. Twins Chips UI (Epic 3.6) — Feature design complete**
- Independent concept selection for left and right sides
- Coach validation + implementation
- Allows mixed concepts (e.g., Smash left + Scissors right)
- Effort: 8–12 hours
- **Status:** Design spec exists; ready for validation

### Near-term (Weeks 3–4)

**4. Route Interpretation Strategy (Epic 1.1)**
- Extract side-aware route logic into pluggable protocol
- Unblocks custom routes and future extensibility
- Effort: 6–8 hours

**5. Route Interpretation Regression Tests (Epic 1.4)**
- Comprehensive test coverage: all 30 route × side permutations
- Protects against regressions when adding formations
- Effort: 1 day

### Medium-term (Month 2)

**6. ConceptLibrary Data Migration (Epic 1.2)**
- Migrate 214 lines of hardcoded templates to data-driven format
- Reduces friction when adding new formations
- Effort: 8–10 hours

**7. Motion Diagram Clarity (Epic 3.3)**
- Label motion arcs, highlight Y final position
- Improve readability for high-motion plays
- Effort: 8–10 hours

**8. Concept Discovery & Learning (Epic 3.2)**
- Add concept glossary modal with descriptions
- Formation context hints on selection change
- First-launch onboarding tour
- Effort: 12–16 hours

### Later (Month 2+)

- Pro Concepts validation
- Route Modifiers (step, read, option variants)
- Y Wheel motion research & planning
- TemplateQuery DSL (composition pattern for concept queries)
- Receiver table UX (responsive cards on small screens)
- Error feedback expansion
- Localization & string constants

---

## Known Limitations & Process Notes

**Agent Spatial Reasoning:** AI agents have limited ability to interpret spatial geometry from verbal + visual descriptions. Visual/spatial features may require extended iteration or accept early compromise. See `.claude/rules/project-process.md` § Visual and Spatial Features for decision tree.

---

## Reference

- **Comprehensive backlog:** `docs/backlog/IMPROVEMENT-BACKLOG.md` (all epics, stories, AC, effort estimates)
- **Process guide:** `.claude/rules/project-process.md` (visual features strategy, iteration signals)
- **Retrospective & learnings:** `docs/retrospectives/2026-06-07-y-wheel-spacing-retro.md` (Y Wheel findings, action items)
