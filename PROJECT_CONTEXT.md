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
