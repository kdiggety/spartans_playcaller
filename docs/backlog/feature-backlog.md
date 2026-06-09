# Feature Backlog

Deferred feature work, manual verification items, and post-ship refinements. Items here have a trigger condition describing when they become actionable.

---

## Library Reorder — Manual UI Verification

**Added:** 2026-06-09
**Trigger:** When Ken tests the feat/library-reorder branch on a physical device or simulator with interactive input

The following 10 manual UI checks from the library-reorder spec could not be verified in the automated agentic build environment (drag gestures require interactive simulator session). They must be verified by Ken or a team member before the feature is considered fully accepted.

### Checks to execute

| Check | AC | Description |
|-------|----|-------------|
| UI-1 | AC-1.1 | Enter Edit mode — drag handles (`≡` icon, trailing edge) appear alongside checkboxes (leading), no layout overlap |
| UI-2 | AC-1.2 | Drag a play to a new position — row lifts visually, adjacent rows shift to show insertion point |
| UI-3 | AC-2.1 | No separate "Reorder" button exists — "Edit" is the single entry point |
| UI-4 | AC-2.2 | With empty library, "Edit" button is disabled/not tappable |
| UI-5 | AC-2.3 Done | Tap Done — reordered order persists after app restart; toolbar returns to Normal mode |
| UI-6 | AC-2.3 Cancel | Tap Cancel — order reverts to pre-session state with visible animation; no disk write |
| UI-7 | AC-2.4 | With 1 play, drag handle shows at 30% opacity; long-press does not initiate drag |
| UI-8 | AC-2.5 | In Edit mode, swipe actions do not appear; row tap toggles checkbox only |
| UI-9 | AC-1.3 live | Background-kill app after drag but before Done; relaunch shows pre-session order |
| UI-10 | TQ-1 | Checked plays stay checked after dragging a different row; further drags work |

Document outcomes in `docs/test-plans/library-reorder-test-results.md` under the Manual Verification section.
