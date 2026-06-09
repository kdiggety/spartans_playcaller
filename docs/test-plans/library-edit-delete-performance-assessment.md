# Performance Assessment: Library Edit and Delete

**Feature:** library-edit-delete  
**Date:** 2026-06-08  
**Author:** performance-engineer  
**Verdict:** Perf testing NOT required. Re-assess if triggers below are met.

---

## 1. What This Feature Changes

The feature adds three mutation paths to `PlayLibraryStore`:

- **Delete single / delete multi-select** — removes one or more `SavedPlay` values from the in-memory `[SavedPlay]` array and calls `persist()`.
- **Delete All** — replaces the entire array with `[]` and calls `persist()`.
- **Edit in-place** — updates a single `SavedPlay` at a known index (a new `update(_:)` method will be required) and calls `persist()`.

All three paths terminate in the same `persist()` function: `JSONEncoder().encode(plays)` followed by `data.write(to:, options: .completeFileProtection)`. No network I/O, no background queue, no secondary data structure. The store is `@MainActor`-isolated; mutations block the main thread until the file write completes.

---

## 2. Payload Size Analysis

`SavedPlay` is a minimal DTO: 7 fields, all `String` / `UUID` / `Bool` / `Date`. No embedded arrays, no nested objects, no binary blobs.

| Scenario | Minified JSON | Swift JSONEncoder estimate |
|---|---|---|
| Single play (max-length fields) | ~205 bytes | ~400 bytes |
| 50 plays | ~10 KB | ~20 KB |
| 200 plays | ~40 KB | ~80 KB |

Field breakdown for a worst-case single play: UUID (36 chars) + ISO8601 date (~25 chars) + formation name (max "Trips Right", 11 chars) + routeDigits (max 5 chars) + conceptName (max "Scissors", 8 chars) + motionLabel (max "After/Go", 8 chars) + yWheelEnabled (4-5 chars). There is no growth path for an individual record — the schema is fixed.

At 200 plays, the entire library encodes and writes to disk as roughly 80 KB. On any iPhone 8 or newer (which covers iOS 17 targets), sequential write throughput to the app's Documents directory exceeds 20 MB/s. The expected write latency for 80 KB is under 5 ms. This is well inside the 16 ms main-thread budget per frame and undetectable to the user in any of the three mutation paths.

---

## 3. Per-Operation Analysis

### 3a. Delete single (swipe or select mode)

`plays.remove(atOffsets:)` is O(n) where n is array size. At 200 items this is a trivial in-memory operation (~microseconds). The subsequent `persist()` rewrites the full array — this is the same "full rewrite" pattern already used by the existing `save()` and `delete(at:)` methods. No regression vs existing behavior; same code path. SwiftUI's `List` with a `ForEach` on `Identifiable` items handles a single-item removal via a diff-and-animate pass over the index set. This is the standard framework-provided path and runs within one frame at any library size plausible for this use case.

### 3b. Delete All

`plays = []` followed by `persist()`. Encoding an empty array produces a 2-byte payload (`[]`). This is the fastest possible persist call in the codebase — strictly faster than any other mutation. No concern.

### 3c. Edit in-place

The anticipated `update(_:at:)` implementation will do an index-based array replacement (`plays[index] = updatedPlay`) followed by `persist()`. This is structurally identical to delete-then-save but without the array shrink. Array is the same length; encoded payload is the same size. Latency profile is identical to a delete — sub-5 ms at 200 plays.

The edit surface requires re-parsing route digits through `RouteInterpreter` to reconstruct assignments and re-derive the concept name. This is a CPU-only operation (no I/O), already exercised on every keystroke in the existing PlayCaller input flow. It is not a new cost introduced by edit; it is the same interpreter invocation already known to be fast enough for real-time input.

### 3d. List re-render after mutation

`PlayLibraryView` uses `ForEach(store.plays)` inside a `List`. Removing one item triggers a SwiftUI diffing pass over the `plays` array, which produces a single animated deletion. At 200 items this is a purely CPU-bound diff over 200 `UUID` comparisons — sub-millisecond. The list rows (`PlayLibraryRow`) contain only text labels derived from `SavedPlay` fields — no Canvas rendering, no image loading, no async work. Re-render cost is bounded by the number of rows that change, which is 1 for a single delete and 0 (empty state) for Delete All.

---

## 4. Risk Rating

**Low.**

Rationale:
- No server round-trips. All operations are local.
- Payload is small and structurally bounded; no field can grow without a model change.
- Mutations all converge on the same `persist()` path already in production use.
- The most expensive path (full JSON encode + file write of 200 plays) completes in well under one frame on the minimum supported hardware.
- List re-render is a standard SwiftUI diff on a short, text-only list.
- The feature adds no new algorithmic complexity — O(n) in-memory array operations over n <= ~200 items.

The primary correctness risk (edited play exporting stale pre-edit data) is a data-integrity concern, not a performance concern, and is owned by SDET via AC-3.8.

---

## 5. Thresholds — If Tested

No dedicated perf tests are warranted. If the architecture-system-design decision for OQ-1 results in a navigation pattern that triggers route re-parsing on every list appearance (e.g., if the edit surface dismisses and the library view reconstructs all rows), that would be worth a targeted profiler run. The threshold to investigate would be any list re-render that causes a visible stutter (dropped frame) at 50+ plays. Measure with Instruments Time Profiler on device, not simulator.

---

## 6. Re-Assessment Triggers

Revisit this assessment if any of the following conditions are met:

1. **Library size ceiling rises above ~500 plays.** The spec states 50–200 as the realistic range. If backlog items introduce import, sync, or team-sharing of play libraries that could push counts into the thousands, encode/write latency should be measured on-device.

2. **`SavedPlay` schema expands to include variable-length or embedded fields.** If a future feature adds a free-text coach note, an embedded diagram snapshot, or an image attachment to `SavedPlay`, per-record size grows and the payload analysis above is invalidated.

3. **`persist()` is called in a tight loop.** If a future bulk-import or reorder feature calls `persist()` once per item rather than once at the end of the operation, the cumulative I/O cost becomes meaningful.

4. **The edit surface drives real-time `persist()` calls on keystroke.** The current design saves only on explicit "Save" confirmation. If that changes to auto-save on every field change, this assessment is invalid.

5. **iCloud sync is introduced.** The spec explicitly excludes sync, but if it is added, `data.write(to:, options: .completeFileProtection)` interacts with the iCloud conflict-resolution layer and latency characteristics change entirely.

---

## 7. Verdict

**Perf testing not required for this feature slice.**

The feature operates on a local JSON file of at most ~80 KB, using in-memory array mutations and the same synchronous write path already in production. No operation approaches user-perceptible latency at any realistic library size. The architectural risk to monitor is whether OQ-1 resolution introduces unintended re-parsing on list appearance — if so, a single profiler run in Instruments is sufficient to confirm or dismiss the concern.

Re-assess if any trigger in Section 6 is met.
