# Performance Assessment: PDF Card Labels — Receiver Letter Labels and Header Restructure

**Date:** 2026-06-07
**Status:** PERFORMANCE PLAN NOT REQUIRED
**Feature:** PDF card rendering improvements — receiver letter labels inside dots; card header text restructure
**Author:** Performance Engineer

---

## 1. What the Change Does

Two modifications to the existing `CGContext`-based PDF card rendering pipeline:

**Header restructure:** Removes 3 text draw calls (Row 1 formation, Row 2 digits, Row 3 receiver labels as a combined row) and replaces them with 1 combined text draw call. Net change per card: -2 `NSString.draw(in:withAttributes:)` calls.

**Receiver letter labels:** After drawing each receiver dot (an existing filled circle), draws the receiver's letter (X/Y/Z/A/H) inside the dot using `NSString.draw(in:withAttributes:)` with a `CGContextSaveGState` / `CGContextRestoreGState` + scale flip. Adds 4–5 text draw calls per card (one per receiver).

Net additional draw calls per card: approximately +2 to +3 text draws (4–5 additions minus 2 removals).

---

## 2. Why a Performance Plan Is Not Required

### 2.1 Absolute cost of the additions

Each `NSString.draw(in:withAttributes:)` call at card scale (roughly 30×30pt for a letter inside a receiver dot) involves:

- Core Text attribute lookup from a pre-constructed attributes dictionary — under 0.01ms.
- Glyph shaping and rasterization of a single character at a small point size — under 0.1ms.
- Two `CGContext` state save/restore pairs (`CGContextSaveGState` / `CGContextRestoreGState`) — trivial stack operations, under 0.01ms each.

Conservatively, each labeled receiver adds 0.1–0.2ms to per-card rendering time. For 5 receivers, this is 0.5–1ms per card.

### 2.2 Budget context from the existing assessment

The prior performance assessment (`wristband-export-performance-assessment.md`) established the following baselines and gates:

- Expected CGContext draw cost per card: **3–8ms** (Section 3 of that assessment, referenced as "single diagram render").
- Per-card text draw calls already present: 6+ (play call digits, formation label, motion label, concept label, etc.).
- Hard gate for a 9-play catalog page: **< 500ms total**, with expected performance of 70–200ms — providing 2.5× to 7× margin.
- Hard gate per wristband page: **< 500ms**, with expected performance of 15–60ms.

Adding 0.5–1ms per card increases card rendering time by roughly 6–12% in the pessimistic case. For a 9-play catalog page at the pessimistic baseline (192ms from the prior assessment), the addition contributes approximately 5–9ms — a total increase of under 5%. The hard gate margin is not materially affected.

### 2.3 Largest realistic batch

At 50 plays (largest realistic selection, treated as an extreme outlier in the prior assessment), the additional cost is:
- 50 cards × 1ms per card = 50ms total added cost.
- This falls within the existing "very large selection" tier (1–3s expected, spinner shown), adding under 5% to the pessimistic upper bound.

No user-visible change in behavior. No new loading tier required.

### 2.4 Memory

The additions use no new allocations beyond the transient `NSAttributedString` attributes dictionary, which is stack-local and immediately released. CGContext state save/restore does not allocate heap memory. The memory profile established in the prior assessment (peak under 2MB for any scenario) is unchanged.

### 2.5 Thread model

The change is purely within the `draw(with:to:context:)` callback, which already runs in a background `Task.detached`. No main-thread impact.

---

## 3. Risk Factors

**Very large batches (100+ plays).** At 100 cards, the addition is approximately 100ms at the pessimistic ceiling. This remains within the "show a spinner" UX tier and does not cross any hard gate. It is not a concern at realistic coaching usage volumes (game plans typically contain 15–30 plays).

**Text attribute dictionary construction per draw call.** If the attributes dictionary (font, color, paragraph style, alignment) is re-constructed on every `NSString.draw` call rather than cached, the overhead multiplies by the number of draw calls per export. This is the one pattern worth confirming in implementation review. The fix — construct the attributes dictionary once and reuse it across all receiver label draws on a card — is trivial and eliminates the concern entirely.

**Non-ASCII characters.** The change draws only X, Y, Z, A, H — five ASCII capital letters with no ligatures, combining marks, or bidirectional complexity. Core Text shaping cost for these characters is at the floor of what Core Text can produce.

---

## 4. Re-Assessment Triggers

This "not needed" decision should be revisited if any of the following occur:

1. **Typical export batch size grows beyond 100 plays.** At that scale the cumulative addition (~100ms) becomes the dominant variable cost within a single export. Trigger: coach feedback that large exports feel slower, or usage data showing common batch sizes above 100.

2. **Receiver label draws are expanded to include multi-character strings, images, or custom fonts.** The current change draws single ASCII characters in a system font. Any change to a custom font (loading a font file adds I/O), emoji, or multi-character abbreviation changes the Core Text cost model. Trigger: any change to the character set or font family used for receiver labels.

3. **Additional per-receiver draw operations are added** (e.g., route label, coverage assignment, alignment indicator). Each additional element per receiver multiplies by 4–5 receivers per card and then by card count. Trigger: spec addition of any per-receiver text or graphic beyond the letter label.

4. **Card count per page increases.** Current layout: 4 (wristband) and 9 (catalog). If a "mini" mode with 16+ cards per page is added, per-card overhead aggregates more rapidly within a single `draw()` call. Trigger: any new layout with more than 9 cards per PDF page.

---

## 5. Decision

**Performance plan is not required.** The change adds 2–3 net text draw calls per card within an already CPU-bound pipeline that has substantial margin against all established hard gates. The added latency at maximum realistic batch size is under 50ms total — invisible to users under a spinner. No new measurement, profiling, or load testing is warranted for this change.

The one implementation-quality note worth flagging in code review: confirm the receiver label attributes dictionary is constructed once per card render, not once per draw call.
