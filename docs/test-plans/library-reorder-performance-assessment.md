# Performance Assessment: Library Reorder

**Feature:** library-reorder
**Date:** 2026-06-09
**Author:** performance-engineer
**Verdict:** Perf testing NOT required. Re-assess if triggers below are met.

---

## 1. What This Feature Changes

The feature adds one new mutation path to `PlayLibraryStore`:

- **Move play** — calls `plays.move(fromOffsets:toOffset:)` to reposition one `SavedPlay` in the in-memory array, then calls `persist()` once when the user taps "Done" to exit Select mode.

It also introduces two new state-management concerns in the view layer:

- **Pre-session snapshot** — `PlayLibraryStore` (or the view model) holds a copy of the `plays` array at the moment Select mode is entered, so that Cancel can restore it without a disk read.
- **Buffered in-memory reorder** — drag operations mutate the `plays` array in memory only; `persist()` is deferred until Done. Cancel discards memory state and restores the snapshot.

No new network I/O, no background queue, no new secondary data structure beyond the snapshot copy. The store is `@MainActor`-isolated; all mutations run on the main thread.

---

## 2. Payload and Memory Analysis

`SavedPlay` is a 7-field flat struct: `UUID` (16 bytes raw / 36 chars encoded), `Date` (8 bytes), four short `String` fields (formation name, routeDigits, conceptName, motionLabel — max ~30 chars combined), and one `Bool`. There are no embedded arrays, images, or variable-length blobs. The schema is fixed; no field can grow without a model change.

### 2a. Pre-Session Snapshot Cost

The snapshot is a value-type copy of `[SavedPlay]` — Swift array copy-on-write semantics mean the copy is nearly free until a mutation occurs. At first drag, copy-on-write triggers a full array copy.

| Library size | Approximate in-memory footprint per copy |
|---|---|
| 10 plays (light user) | ~5 KB |
| 50 plays (typical) | ~25 KB |
| 200 plays (extreme) | ~100 KB |

Holding two copies simultaneously (live array + snapshot) doubles this: roughly 10 KB at 10 plays, 50 KB at 50 plays, 200 KB at 200 plays. At the extreme end of 200 plays, 200 KB of heap pressure is below the threshold of any observable concern on any supported iPhone — iOS terminates background apps in the 50–150 MB range; a 200 KB spike is three orders of magnitude below that ceiling. No memory concern at any realistic library size.

### 2b. JSON Encode and Disk Write on Done

`persist()` is the same call used today for save, delete, and edit. It encodes the full array and writes it synchronously to the Documents directory with `.completeFileProtection`.

| Scenario | Encoded JSON estimate | Expected write latency (iPhone 8+, >20 MB/s) |
|---|---|---|
| 50 plays (typical) | ~20 KB | < 2 ms |
| 200 plays (extreme) | ~80 KB | < 5 ms |

A single `persist()` call at 200 plays completes well inside the 16 ms frame budget and is undetectable to the user. This is identical to the cost already accepted in the library-edit-delete feature — reorder introduces no new I/O surface.

Critically, per AC-1.3 and AC-2.3, `persist()` is called **once per Select mode session** (on Done), not once per drag operation. If the user performs 10 drag operations and taps Done, there is exactly one file write. This is a deliberate and correct design choice that eliminates any I/O-per-move concern entirely.

Cancel path produces **zero disk writes** — the snapshot is restored in memory and no `persist()` call is made. This is strictly cheaper than Done.

---

## 3. Animation and List Re-render

### 3a. In-session drag animation (`.onMove`)

SwiftUI's `.onMove` modifier on a `ForEach` drives the drag affordance using the system list row reorder machinery. The visual lift-and-shift animation runs at the compositor layer — it does not re-execute SwiftUI's `body` for every frame of the drag. Rows adjacent to the dragged item shift position through a transform, not a full re-layout. This is the standard framework path used by iOS Settings, Reminders, and Contacts — it is optimized for exactly this use case.

The per-move callback (`plays.move(fromOffsets:toOffset:)`) is `O(n)` in array size. At 200 elements, this is a memory move of at most 200 pointer-width values — sub-microsecond on any ARM chip. SwiftUI then diffs the `Identifiable` list by UUID, finds one insertion and one removal, and applies a positional update. At 200 rows this diff is also sub-millisecond.

**PlayLibraryRow** renders only text fields derived from `SavedPlay`. There is no Canvas, no async image load, no expensive layout in each row. The per-row render cost is negligible. Even a full list re-render at 200 rows involves nothing more than 200 text label measurements — this will not produce a dropped frame on any device running iOS 17.

### 3b. Mode-entry and mode-exit transitions

Entering Select mode triggers a SwiftUI state change that inserts drag handles and checkboxes into every visible row. On a 200-row list, the number of simultaneously visible rows is constrained by the screen viewport (typically 8–12 rows on an iPhone). SwiftUI only renders rows in the visible window (`List` uses lazy loading). Mode entry re-renders only the visible rows, not all 200. No concern.

### 3c. Rapid drag sequences

If a user drags multiple plays in quick succession without tapping Done, each drag triggers one `plays.move()` call (O(n)) and one SwiftUI diff. These are independent, sequential operations — there is no accumulation of deferred work. No concern at any realistic library size or interaction speed.

---

## 4. Risk Rating

**Low — no meaningful performance risk at any realistic library size.**

Summary of why:

| Concern | Verdict | Reasoning |
|---|---|---|
| Pre-session snapshot memory | Not a concern | ~200 KB max; three orders of magnitude below OS pressure threshold |
| Per-move array mutation | Not a concern | O(n) over n <= 200; sub-microsecond |
| Per-move list diff | Not a concern | UUID diff over <= 200 items; sub-millisecond |
| Drag animation smoothness | Not a concern | Compositor-layer transform; lazy viewport rendering |
| Disk write on Done | Not a concern | One write per session; identical to existing persist() cost |
| Cancel path I/O | Not a concern | Zero writes; memory-only restore |
| Mode-entry re-render | Not a concern | Only visible rows re-render; lazy list |

The only architectural risk in the spec is TQ-1 (SwiftUI `List(selection:)` + `.onMove` coexistence). This is a **correctness and interaction fidelity** concern, not a performance concern. Architecture-system-design owns the resolution.

One pattern to avoid during implementation: calling `persist()` inside the `.onMove` callback rather than deferring it to Done. The spec is explicit that persistence is deferred to Done (AC-1.3), but if an implementer inadvertently wires `persist()` per-drag, it converts a single write into potentially dozens of writes in one session. This is the only implementation path that could introduce noticeable I/O load, and it is already excluded by the spec's AC-1.3 design. SDET should verify this during test execution by confirming that file modification time does not change during a multi-drag Select mode session.

---

## 5. Re-Assessment Triggers

Revisit this assessment if any of the following conditions are met:

1. **`persist()` is called per drag operation rather than per Done.** The spec explicitly buffers writes to Done. If a future design change, feature addition, or implementation error introduces per-move persistence, cumulative I/O cost becomes meaningful at 10+ moves per session. Measure with Instruments File Activity on device.

2. **Library size ceiling rises above ~500 plays.** The spec states 50–200 as the realistic range. Import, iCloud sync, or team-sharing features that push counts into the thousands would change both the snapshot memory analysis and the `persist()` latency estimate.

3. **`SavedPlay` schema expands to variable-length or embedded fields.** Any addition of free-text coach notes, diagram images, or video attachments would invalidate the per-record size estimates and grow the snapshot footprint non-linearly.

4. **PlayLibraryRow render cost increases substantially.** If a future feature adds async image loading, Canvas diagram rendering, or complex layout to each row, the cost of a full list re-render during mode transitions would need to be re-evaluated.

5. **iCloud sync is introduced.** The spec explicitly excludes sync, but if added, `data.write(to:, options: .completeFileProtection)` interacts with the iCloud conflict-resolution layer and the deferred-write model may require reconsideration.

6. **Minimum supported device drops below iPhone 8.** The write latency and animation estimates above are anchored on iPhone 8 (A11 Bionic, ~2017). If an older A9/A10 device were targeted, the animation smoothness at 200 rows should be validated on device.

---

## 6. Verdict

**Perf testing not required for this feature slice.**

The reorder feature introduces one buffered `O(n)` array move, one pre-session value-type snapshot (~200 KB at extreme size), SwiftUI's standard compositor-layer drag animation over a lazy-loaded list, and a single `persist()` call per session (identical to the existing write path). None of these operations approach user-perceptible latency or memory pressure at any realistic library size.

The one implementation pattern that would invalidate this verdict — calling `persist()` inside the `.onMove` callback — is explicitly excluded by AC-1.3. SDET should add a file-modification-time check to confirm this is correctly implemented.

Re-assess if any trigger in Section 5 is met.
