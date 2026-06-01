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
| 1 | Short (25%) | Always LEFT 90° | Quick Out | Quick Slant |
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
When enabled: Y's numbered route is hidden and replaced with a smooth U-shaped arc.

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

## Architecture

```
SpartansPlaycaller/
├── Models/          # Enums and value types (Formation, Receiver, RouteNumber, etc.)
├── Services/        # Business logic (Parser, ConceptLibrary, ConceptMatcher, DiagramRenderer)
├── ViewModels/      # MVVM view models
└── Views/           # SwiftUI views including Canvas route diagram
```

## Future Expansion (architected for, not yet implemented)

- Additional formations and motion
- Protection schemes and run concepts
- Wristband generation
- PDF playbook export
- Animated route playback
- AirPlay coaching mode
- Drag/drop route editing
