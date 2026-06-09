# Library Reorder — Test Results

**Date:** 2026-06-09
**Branch:** feat/library-reorder
**Simulator:** iPhone 17, iOS 26.3 (26.3.1 - 23D8133)
**Author:** SDET Agent

---

## Automated Test Results

**Total tests run:** 227
**Passed:** 218
**Failed:** 9 (all pre-existing — see section below)
**New regressions introduced by this feature:** 0

### New Tests (library-reorder)

All 9 new tests introduced by this feature pass.

| Test | File | Result |
|------|------|--------|
| testMove_updatesOrderInMemory | PlayLibraryStoreTests | PASS |
| testMove_doesNotPersistImmediately | PlayLibraryStoreTests | PASS |
| testCommitReorder_persistsNewOrder | PlayLibraryStoreTests | PASS |
| testCancelReorder_restoresSnapshot | PlayLibraryStoreTests | PASS |
| testCancelReorder_doesNotWriteToDisk | PlayLibraryStoreTests | PASS |
| testMove_toSamePosition_isNoOp | PlayLibraryStoreTests | PASS |
| testReorder_commitPersistsAcrossReinit | LibraryPersistenceIntegrationTests | PASS |
| testReorder_cancelDoesNotPersistAcrossReinit | LibraryPersistenceIntegrationTests | PASS |
| testReorderThenDelete_preservesRelativeOrder | LibraryPersistenceIntegrationTests | PASS |

### Pre-existing Failures (not regressions)

These 9 tests fail identically on `main` before any library-reorder changes. Verified by running the full test suite on `main` and confirming the exact same 9 tests fail. The feature branch introduces zero new failures.

| Test | File |
|------|------|
| testGenerateFromConceptProducesPlayCallAndResetsMotion | PlayCallerViewModelTests |
| testMotionRejectionErrorMessageForTwinsFormation | PlayCallerViewModelTests |
| testSetYMotionRejectededInTwinsFormation | PlayCallerViewModelTests |
| testIdentifyCompletePlayCallBeforeMotion | ConceptMatcherTests |
| testReceiverMotionHasAllCases | ReceiverMotionTests |
| testReceiverMotionIdentifiable | ReceiverMotionTests |
| testStopMotionPreservesLeftSide | ReceiverMotionTests |
| testStopMotionPreservesRightSide | ReceiverMotionTests |
| testMotionStopDoesNotChangeSide | RouteInterpreterTests |

None of these files were modified by the library-reorder feature. Files changed on this branch: `PlayLibraryStore.swift`, `PlayLibraryView.swift`, `PlayLibraryStoreTests.swift`, `LibraryPersistenceIntegrationTests.swift`.

---

## Manual Verification Checklist

The following UI checks require a running simulator or device. They are documented as **NOT VERIFIED — requires manual testing on simulator** because automated `xcodebuild test` does not exercise interactive SwiftUI drag gestures.

| Check | AC | Status | Notes |
|-------|----|--------|-------|
| UI-1: Drag handles visible in Edit mode | AC-1.1 | NOT VERIFIED | Requires manual test |
| UI-2: Live drag feedback (lift + shift animation) | AC-1.2 | NOT VERIFIED | Requires manual test |
| UI-3: No separate Reorder button — Edit is single entry point | AC-2.1 | NOT VERIFIED | Requires manual test |
| UI-4: Edit button disabled with empty library | AC-2.2 | NOT VERIFIED | Requires manual test |
| UI-5: Done commits reorder; persists after restart | AC-2.3 Done | NOT VERIFIED | Requires manual test |
| UI-6: Cancel reverts order (animated); no disk write | AC-2.3 Cancel | NOT VERIFIED | Requires manual test |
| UI-7: 1-play library — handle 30% opacity, non-draggable | AC-2.4 | NOT VERIFIED | Requires manual test |
| UI-8: Swipe actions suppressed in Edit mode | AC-2.5 | NOT VERIFIED | Requires manual test |
| UI-9: Background-kill before Done — relaunch shows pre-session order | AC-1.3 live | NOT VERIFIED | Requires manual test |
| UI-10: Checked plays remain checked after drag; further drags work | TQ-1 | NOT VERIFIED | Requires manual test |

Manual UI verification (UI-1 through UI-10) is deferred to user testing session per project process for interactive SwiftUI features. The acceptance criteria covered by these checks all have corresponding automated unit or integration test coverage for the logic path (see AC Coverage table in the plan). The UI checks verify the rendering and gesture-interaction layer that xcodebuild cannot exercise headlessly.

A known speculative risk is noted in the plan: SwiftUI's system drag handle and the custom `line.3.horizontal` icon may visually stack on iOS 17+ (custom icon + system handle in the same trailing zone). UI-1 is specifically designed to surface this if it materializes.

---

## Notes

- Disk was at 98% capacity at test execution time (12 GB free on 460 GB volume). Cleanup commands (`rm -rf DerivedData`, `xcrun simctl delete unavailable`) were blocked by sandbox permissions. Tests ran successfully within the available headroom. Ken should run the cleanup commands manually before the next large build session.
- SourceKit diagnostics ("No such module UIKit/XCTest") throughout the session are false positives per project process policy. `xcodebuild BUILD SUCCEEDED` is the authoritative gate.
- Pre-existing failures (9 tests) are tracked as a backlog item. They are not regressions from this feature and were present on `main` before this branch was created.
