# Spartans Playcaller

A native iOS app for generating football play calls, rendering route diagrams, and identifying route concepts using a custom nomenclature system.

## What It Does

- **Play Call Generator** — Select a formation and concept, get the route digits, receiver assignments, and a visual diagram
- **Play Call Parser** — Enter route digits manually, see each receiver's interpreted route with side-aware meaning
- **Concept Identification** — Automatically matches digit patterns against known concept templates

## The Nomenclature System

This app implements a **non-standard** route numbering system where:

1. Route numbers (0-9) are **static** — they don't change
2. The **meaning** of each number changes based on which side of the ball the receiver is aligned on
3. Some routes have **absolute directions** (3 always breaks left, 4 always breaks right) regardless of side

This distinction is the core logic of the application.

### Route Tree

| # | Left Side | Right Side |
|---|-----------|------------|
| 0 | Hitch | Hitch |
| 1 | Quick Out | Quick Slant |
| 2 | Quick Slant | Quick Out |
| 3 | Out (breaks LEFT) | Out (breaks LEFT) |
| 4 | Dig/In (breaks RIGHT) | Dig/In (breaks RIGHT) |
| 5 | Comeback | Curl |
| 6 | Curl | Comeback |
| 7 | Corner (angles top-left) | Corner (angles top-left) |
| 8 | Post (angles top-right) | Post (angles top-right) |
| 9 | Go/Fade | Go/Fade |

### Formations

| Formation | Left Side | Right Side |
|-----------|-----------|------------|
| Twins | X, Y | Z, A |
| Trips Left | A, X, Y | Z |
| Trips Right | X | Y, Z, A |

### Digit Sequence

Always: **X, Y, Z, A** (4 digits) or **X, Y, Z, A, H** (5 digits)

Example: `6794` in Twins = X runs Curl, Y runs Corner, Z runs Go, A runs Dig

## Requirements

- iOS 17.0+
- Xcode 15.4+
- Swift 5.9+

## Building

Open `SpartansPlaycaller.xcodeproj` in Xcode and build (Cmd+B). No external dependencies.

## Architecture

MVVM with clear separation of concerns:

```
SpartansPlaycaller/
├── Models/          # Formation, Receiver, RouteNumber, RouteMeaning, PlayCall, etc.
├── Services/        # PlayCallParser, ConceptLibrary, ConceptMatcher, RouteInterpreter, DiagramRenderer
├── ViewModels/      # PlayCallerViewModel
└── Views/           # PlayCallerView, RouteDiagramView, ReceiverAssignmentView
```

## Concepts Supported

| Concept | Twins Left | Twins Right | Trips Left | Trips Right |
|---------|-----------|-------------|------------|-------------|
| Smash | X=6, Y=7 | Z=5, A=8 | X=6, Y=7, A=4 | Z=5, Y=8, A=1 |
| Dagger | X=4, Y=9 | Z=3, A=9 | — | Z=3, Y=9, A=2 |
| Verts | X=9, Y=9 | Z=9, A=9 | — | — |
| Scissors | X=8, Y=7 | Z=7, A=8 | — | Z=7, Y=8, A=5 |
| Sail | X=9, Y=3 | Z=9, A=4 | X=9, Y=3, A=1 | Z=9, Y=4, A=1 |
| China | — | — | X=6, Y=7, A=6 | Z=5, Y=8, A=5 |
