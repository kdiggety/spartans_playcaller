---

# Test Results — Library Edit, Delete, and Delete All

**Date:** 2026-06-09
**Branch merged to main:** `feat/library-edit-delete`
**Build:** `BUILD SUCCEEDED`

## Summary

| Category | Count |
|----------|-------|
| Total tests run | 56 (approx) |
| New tests added this feature | 22 |
| Passed | 47 |
| Failed | 9 |
| New failures (regressions) | 0 |
| Pre-existing failures | 9 |

## New Tests Added (22)

**`PlayLibraryStoreTests`** — 10 new `update()` tests:
- `testUpdatePlay_changesDigits`
- `testUpdatePlay_preservesPosition`
- `testUpdatePlay_updatesTimestamp`
- `testUpdatePlay_noFieldChanges_stillUpdatesSavedAt`
- `testUpdatePlay_conceptReevaluated`
- `testUpdatePlay_motionLabel_preserved`
- `testUpdatePlay_yWheelEnabled_preserved`
- `testUpdatePlay_unknownUUID_returnsPlayNotFound`
- `testUpdatePlay_invalidDigits_returnsValidationError`
- `testUpdatePlay_inLargeLibrary_onlyTargetChanged`
- `testUpdatePlay_persistsAcrossReinit`

**`LibraryPersistenceIntegrationTests`** — 2 new:
- `testUpdatePlay_roundTripAcrossReinit`
- `testMultiDelete_persistsAcrossReinit`

**`ExportCardTests`** — 1 new:
- `testExportCard_reflectsEditedValues`

**`EditPlayViewModelTests`** — 9 new (all passing):
- `testInit_populatesFieldsFromSavedPlay`
- `testIsDirty_trueAfterDigitChange`
- `testIsDirty_falseAfterRevertingChange`
- `testValidateInput_setsErrorOnEmpty`
- `testValidateInput_clearsErrorOnValidInput`
- `testSave_successSetsDidSave`
- `testSave_invalidDigits_setsValidationError`
- `testSave_updatesStorePlay`
- `testValidateInput_usesCurrentFormation`
- `testSave_playNotFound_setsPersistError`

## Pre-Existing Failures (9 — unchanged from baseline on main)

These failures existed before this feature and are not regressions:

- `ConceptMatcherTests.testIdentifyCompletePlayCallBeforeMotion`
- `PlayCallerViewModelTests.testGenerateFromConceptProducesPlayCallAndResetsMotion`
- `PlayCallerViewModelTests.testMotionRejectionErrorMessageForTwinsFormation`
- `PlayCallerViewModelTests.testSetYMotionRejectededInTwinsFormation`
- `RouteInterpreterTests.testMotionStopDoesNotChangeSide`
- `ReceiverMotionTests.testReceiverMotionHasAllCases`
- `ReceiverMotionTests.testReceiverMotionIdentifiable`
- `ReceiverMotionTests.testStopMotionPreservesLeftSide`
- `ReceiverMotionTests.testStopMotionPreservesRightSide`

## Manual Verification Checklist

UI layer verification (not automatable) — to be completed on simulator:

- [ ] Swipe left on a play → Edit (blue) and Delete (red) actions appear
- [ ] Tapping Delete shows confirmation with play name; Cancel leaves play unchanged
- [ ] Tapping Edit opens `EditPlayView` sheet with pre-populated values
- [ ] Changing a field and tapping Cancel shows "Discard Changes?" alert
- [ ] Reverting a change and tapping Cancel dismisses immediately (no alert)
- [ ] Saving a valid edit updates the row in-place (same position, updated values)
- [ ] Saving with invalid/empty digits shows the error banner inline; sheet stays open
- [ ] Delete All via `...` menu shows count in confirmation; confirms clears library
- [ ] `...` menu is hidden when library is empty
- [ ] Select mode shows Delete N button; tapping with 0 selections is disabled
- [ ] Multi-select Delete shows correct count; confirms removes only selected plays
- [ ] Export of an edited play reflects edited values
