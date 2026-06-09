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

---

## Swift `@MainActor` Isolation in Test Files

**Rule:** Any `XCTestCase` class that instantiates or calls methods on an `@MainActor`-isolated type must be annotated `@MainActor` at the class level.

**`@MainActor`-isolated types in this codebase:**
- `PlayLibraryStore` (`@MainActor final class`)
- `PlayCallerViewModel` (`@MainActor final class`)
- Any `ObservableObject` with `@MainActor`-isolated `@Published` mutations

**Correct pattern:**
```swift
@MainActor
final class PlayLibraryStoreTests: XCTestCase {
    var store: PlayLibraryStore!
    override func setUp() {
        super.setUp()
        store = PlayLibraryStore(fileURL: tempURL)
    }
    func testSave() {
        store.save(playCall, motion: nil, yWheelEnabled: false) // safe
        XCTAssertEqual(store.plays.count, 1)
    }
}
```

**Why it matters:** Without `@MainActor`, Swift concurrency produces compile-time isolation errors when calling actor-isolated methods. Discovered during Epic 3.1 — two generated test files required `@MainActor` annotation that the software-engineer agent omitted. The SDET agent should verify this pattern when reviewing generated test files for any new `ObservableObject` service or ViewModel.

---

## Xcode project.pbxproj Registration Rule

**Rule:** When a software-engineer agent creates any new Swift source or test file, it must also register that file in `SpartansPlaycaller.xcodeproj/project.pbxproj`. Writing a file to disk is not sufficient — Xcode requires explicit `PBXBuildFile`, `PBXFileReference`, `PBXGroup`, and `PBXSourcesBuildPhase` entries for the file to be compiled and executed.

**A task is not complete until `xcodebuild test` compiles without errors attributable to the new file.** The "Run tests" step in every implementation task serves as the verification gate.

**SDET role:** If SDET discovers unregistered files during verification, flag this as an implementing-agent gap (not a silent corrective action) and add the entries before proceeding. Document the gap in the test results report.

**Why it matters:** Discovered in both Epic 3.1 (source files) and the pdf-card-labels feature (test files). In both cases, files existed on disk but were absent from the project build phase, causing the tests to be silently excluded from the test run.

---

## Disk Space Pre-flight Check

**Rule:** Before executing `git push` or triggering a large Xcode build, verify available disk space is sufficient. If disk usage exceeds ~90% (`df -h .` shows less than ~10% free), halt and surface a warning before proceeding. Do not attempt to push or build through near-full disk conditions.

**Periodic cleanup commands** to keep disk healthy:
```bash
xcrun simctl delete unavailable          # removes old simulator runtimes
rm -rf ~/Library/Developer/Xcode/DerivedData  # frees several GB of build artifacts
```

**Why it matters:** Discovered during pdf-card-labels feature — disk at 97% caused `git push` to fail mid-delivery, requiring Ken to manually free space. DerivedData and simulator runtimes accumulate silently and the condition is invisible until a write fails.

---

## SourceKit Diagnostics Are Not Authoritative

SourceKit (the IDE-level Swift analyzer) fires false-positive diagnostics in this project after every agent file edit. These must NOT be treated as compilation errors or used to justify code changes.

**Policy:**
- SourceKit output is informational only. Do not fix, suppress, or document SourceKit-only warnings unless confirmed by `xcodebuild`.
- The authoritative gate for Swift compilation and test correctness is `xcodebuild build` / `xcodebuild test`.
- If a SourceKit diagnostic and `xcodebuild` disagree, `xcodebuild` is correct.
- Treat SourceKit false positives as "confirmed via xcodebuild (clean)" — not as open issues.

**Why it matters:** Documented across multiple features (most acute in library-edit-delete). SourceKit noise causes repeated re-evaluation of the same known-false pattern, consuming session attention without producing signal.
