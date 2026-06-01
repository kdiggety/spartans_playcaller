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
- **Formations**: Twins (2x2), Trips Left (3 left, 1 right), Trips Right (1 left, 3 right)
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
