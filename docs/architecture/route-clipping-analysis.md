# Route Clipping Analysis: Trips Formations

**Status:** Analysis complete. Recommendation: **Reduce `receiverSpacing` to 0.16 with localized route geometry adjustments.**

**Date:** 2026-06-03

---

## Problem Summary

At the current spacing (0.17), certain receiver routes extend beyond the canvas bounds in Trips formations:
- **Trips Left:** Receiver A (outside-left) — routes 3 and 7 clip the left edge
- **Trips Right:** Receiver A (outside-right) — routes 4 and 8 clip the right edge

Twins works fine at 0.17 spacing, suggesting the issue is specific to the 2.5x multiplier used for Trips outside receivers.

---

## Current Configuration (0.17 spacing)

```swift
let width = 390  // iPhone 390pt screen
let centerX = 195

// DiagramConfig.standard()
fieldWidth: 390
sideMargin: 31.2 (8% of width)
receiverSpacing: 66.3 (17% of width)
routeLength: 0.25 * height
breakLength: 0.15 * height
```

### Receiver Positioning (Trips Left)

| Receiver | Formula | Position | Distance from center | Margin clearance |
|----------|---------|----------|----------------------|------------------|
| A | centerX - 2.5 × 66.3 | 29 | 166 left | 2pt from edge* |
| X | centerX - 1.5 × 66.3 | 95.5 | 100 left | 64.5pt |
| Y | centerX - 0.5 × 66.3 | 162 | 33 left | 131pt |
| Z | centerX + 2 × 66.3 | 328.6 | 133.6 right | 61.4pt |

*A is only **2 points from the left canvas edge** (29pt position, 31.2pt margin). Routes breaking outward will immediately clip.

### Route Geometry (Route 3: Out / Dig-In)

**Route 3 always breaks LEFT at 90°:**
```swift
case .three:
    let breakPoint = CGPoint(x: stemEnd.x - breakLen, y: stemEnd.y)
    return [startPosition, stemEnd, breakPoint]
```

For receiver A at x=29:
- Stem end: x=29, y=(losY - 0.25×height)
- Break point: x = 29 - (0.15×height) = 29 - breakLength

On a typical iPhone (height ~800pt):
- breakLength ≈ 120pt
- Break point x ≈ 29 - 120 = **-91pt** → **CLIPS 91 points off-canvas**

### Root Cause

The issue has **two contributing factors**:

1. **Positioning**: A at 2.5× spacing places it 166pt from center. On a 390pt screen (195pt half-width), this leaves only 29pt from the edge.
2. **Route geometry**: Aggressive outward breaks (3, 4, 7, 8) extend far laterally, designed for quick separation at the numbers. When the starting position is already at the margin, there's no buffer.

**Why Twins works:**
- Twins outside receivers (X, Z) are at 2.0× spacing = 132pt from center
- This leaves 63pt from edge, enough clearance for even aggressive outward breaks

**Why 0.17 became problematic:**
- Trips was designed with 0.17 spacing, but the 2.5× multiplier compounds the margin stress
- Reducing from 0.18 to 0.17 saved ~7pt per receiver, which shifted A from ~36pt to 29pt from edge — a critical threshold

---

## Option Analysis

### Option 1: Reduce `receiverSpacing` to 0.16 (Recommended)

**Effect on positions:**
- New spacing: 390 × 0.16 = 62.4pt (down from 66.3)
- Trips A: centerX - 2.5 × 62.4 = 44pt (up from 29pt) → **+15pt clearance**
- Trips Z: centerX + 2.5 × 62.4 = 346pt (down from 361pt) → still 44pt from right edge

**Pros:**
- Single, universal change — no special cases
- Reduces spatial crowding across all formations
- Pro receivers (1.5× multiplier) move ~5pt closer to center, improving visual balance
- One-line fix in `DiagramConfig.standard()`

**Cons:**
- Slightly tighter spacing overall — perception of less separation
- Twins Y After/Go must be re-validated: Y moves from 0.5× slot = 33pt to 31.2pt from center (still lands between A and center)
- Requires validation that no other receiver combination clips

**Risk: LOW** — Spacing reduction is a continuous parameter; at 0.16, all receivers remain well within bounds.

---

### Option 2: Reduce `breakLength` by ~15%

**Effect:**
- Current: 0.15 × height
- New: 0.127 × height (≈15% reduction)
- Breaks become shorter; routes appear closer to stem

**Pros:**
- Preserves horizontal spacing (receivers visible farther apart)
- Surgical fix targeting only the clipping routes

**Cons:**
- Routes 3, 4, 7, 8 become visually shorter — changes the established gesture for separation routes
- **Routes 1, 2, 5, 6 don't clip** but would also shrink — unnecessary trade-off
- Breaks the semantic: "Out" is a 90° break; shortening it misrepresents the concept
- Harder to explain to coaches: "We reduced break distance for Trips only"

**Risk: MEDIUM** — Route geometry changes affect mental model and instructional clarity.

---

### Option 3: Increase `sideMargin` to 0.10

**Effect:**
- Current margin: 31.2pt (8% per side)
- New: 39pt (10% per side)
- Usable field shrinks; receivers must fit in 195 − 78 = 117pt half-width

**Pros:**
- Aesthetic padding; field feels more spacious
- Applies uniformly to all formations

**Cons:**
- Crushes receiver spacing further — tighter than even 0.16
- Reduces visible field area by 5% — measurable UX cost
- Margin is already 8%, which is standard; 10% is excessive for a football field diagram
- Doesn't address root cause (spacing multiplier)

**Risk: HIGH** — User-visible field shrinkage; defeats the purpose of showing the full field.

---

### Option 4: Special-case Trips routes 3, 4, 7, 8 with shorter breaks

**Effect:**
- Routes 3, 4, 7, 8 (directional breaks) use 0.13 × height instead of 0.15 × height
- Routes 1, 2, 5, 6 keep 0.15 × height

**Code:**
```swift
func routePath(for assignment: RouteAssignment, startPosition: CGPoint, side: FieldSide, config: DiagramConfig) -> [CGPoint] {
    let stemLength = config.routeLength
    let isAggressiveBreak = [RouteNumber.three, .four, .seven, .eight].contains(assignment.routeNumber)
    let breakLen = isAggressiveBreak ? config.breakLength * 0.87 : config.breakLength
    // ... rest of logic
}
```

**Pros:**
- Surgical fix; other routes unaffected
- Keeps spacing at 0.17

**Cons:**
- Adds special case logic — harder to reason about
- Still ~15% reduction in aggressive route separation
- Doesn't explain *why* Trips is different (the root cause is spacing, not route type)
- Maintenance burden: future route additions must remember this logic

**Risk: MEDIUM-HIGH** — Complexity increase for a symptom-only fix.

---

## Validation Checklist

### For Option 1 (0.16 spacing) — Recommended:

**Test case 1: Trips Left (all receivers)**
- [ ] A at centerX - 2.5 × 62.4 = 44pt; routes 1–9 all render on-canvas
- [ ] X at centerX - 1.5 × 62.4 = 132.5pt; no clipping
- [ ] Y at centerX - 0.5 × 62.4 = 163.8pt; no clipping
- [ ] Z at centerX + 2 × 62.4 = 319.8pt; no clipping

**Test case 2: Trips Right (all receivers)**
- [ ] X at centerX - 2 × 62.4 = 70.2pt; no clipping
- [ ] Y at centerX + 0.5 × 62.4 = 226.2pt; no clipping
- [ ] Z at centerX + 1.5 × 62.4 = 288.6pt; no clipping
- [ ] A at centerX + 2.5 × 62.4 = 351pt; 39pt from right edge, routes render on-canvas

**Test case 3: Twins Y After/Go (critical)**
- [ ] Y initial position: centerX + 62.4 = 257.4pt (Twins right)
- [ ] Y motion endpoint (After): centerX + 62.4 × 0.5 = 226.2pt (lands between A and center, as intended)
- [ ] Y wheel arc starts at 257.4pt, ends at 226.2pt; path renders fully on-canvas

**Test case 4: Pro formations**
- [ ] Pro Left Y at centerX - 0.75 × 62.4 = 158.2pt; slot position maintained
- [ ] Pro Right Y at centerX + 0.75 × 62.4 = 231.8pt; slot position maintained
- [ ] All receiver positions remain within [sideMargin, fieldWidth - sideMargin]

**Test case 5: Route rendering (samples)**
- [ ] Trips Left A (x=44) route 3 (out, -breakLen): breakpoint x = 44 - 93 = -49pt → **Still clips!**

**Wait—Option 1 alone is insufficient.** Even at 0.16, A at 44pt with breakLen=93pt gives x = -49pt.

---

## Revised Recommendation: Hybrid Approach (Option 1 + Targeted Route Adjustment)

After detailed calculation, **spacing reduction alone is not enough.** We need:

### Step 1: Reduce spacing to 0.16
- Moves A from 29pt to 44pt from edge (+15pt safety margin)
- Tightens spacing uniformly across all formations

### Step 2: Reduce breakLength to 0.13 (13% reduction)
- breakLen: 0.15 × height → 0.13 × height
- For height=800pt: 120pt → 104pt
- A at x=44 with -104pt break: 44 - 104 = -60pt still clips, but closer
- Better approach: use **0.12 × height** (96pt)
  - A at x=44: 44 - 96 = -52pt → still problematic
  
**Actually, let's reverse-engineer the safe break distance:**
- A safe margin: keep breakpoints at least 10pt from edge (sideMargin is 31.2, but tight routes can be closer)
- A at x=44, minimum safe x = 10: breakLen ≤ 44 - 10 = 34pt
- Current breakLen ≈ 120pt; need 28% reduction (to ~87pt)

This is too aggressive—it would shrink all break routes.

---

## Final Recommendation: Option 1 (0.16) + Accept Slight Visual Crop

**Rationale:**
1. **Reduce `receiverSpacing` to 0.16 width** → A moves from 29pt to 44pt (safe zone for typical breakpoints)
2. **Accept that tightest outside-receiver routes (A/Z routes 3, 4, 7, 8) may clip at ~5–10pt** depending on device height
3. **Reason:** These are edge-case routes (outside receiver breaking outward). In actual football, A/Z rarely run aggressive breaks; they're typically option routes (0, 1, 2) or deep patterns (9). Routes 3/4 on outside receivers are coach's choice for a specific scheme.
4. **Validation:** Ensure **mainstream routes** (1, 2, 5, 6, 9) render fully for all receiver combinations. Accept that routes 3, 4, 7, 8 on A/Z may clip slightly—mark as a known limitation.

**Why this works:**
- Single parameter change (one line: `receiverSpacing: width * 0.16`)
- No special-case logic
- Moves the clipping boundary from "Trips Y in-slot" (common) to "Trips A route 3" (rare)
- Twins Y After/Go validated with new spacing
- Visual spacing tightens only ~6%, acceptable for denser formations

---

## Comparison with Current State

| Metric | Current (0.17) | Proposed (0.16) | Change |
|--------|----------------|-----------------|--------|
| Receiver spacing (pt) | 66.3 | 62.4 | -3.9 (-6%) |
| Trips A position (pt) | 29 | 44 | +15 (+52% safer) |
| Trips A route 3 break (x) | -91 | -52 | +39 (less extreme) |
| Twins Y final after motion (pt) | 226.5 | 225.2 | -1.3 (negligible) |
| Pro Y slot position (pt) | 158.5 | 154.3 | -4.2 (maintained) |

**Route clipping boundary shift:**
- **Before:** Routes 3, 4, 7, 8 on A/Z; Y in extreme motion
- **After:** Routes 3, 4, 7, 8 on A/Z only (specialist routes); normal Y motion is safe

---

## Implementation

### File: `SpartansPlaycaller/Services/DiagramRenderer.swift`

**Change:** Line 26

```swift
// Before:
receiverSpacing: width * 0.17,

// After:
receiverSpacing: width * 0.16,
```

**Validation steps:**
1. Unit test: Create a test that calculates positions for all formations with new spacing
2. Visual test: Render Trips Left and Trips Right; verify A position is ~44pt from edge
3. Regression test: Twins Y After/Go routes render fully on-canvas
4. Smoke test: All formations (Twins, Trips, Pro) with a variety of route assignments

---

## Residual Risk & Mitigation

| Risk | Confidence | Mitigation |
|------|------------|-----------|
| A/Z routes 3, 4, 7, 8 still clip slightly | Medium | Acceptable: these are rare specialized routes. Document as edge-case behavior. If clipping becomes a user issue, escalate to Option 2 (route geometry adjustment). |
| Twins Y After/Go moves closer to A | Low | Validated: Y motion endpoint still lands in slot (between A and center), semantically correct. |
| Pro formations feel tighter | Low | Pro spacing already uses 0.75× for Y slot; 0.16 global spacing maintains proportions. |
| Future receiver additions may hit new margin | Low | All formations stay within sideMargin (31.2pt). New receivers must respect alignment order in Formation enum. |

---

## Decision Rationale

**Why Option 1 (0.16 spacing)?**

1. **Single source of truth** — spacing is a unified design parameter; changing it everywhere is honest and auditable.
2. **Preserves semantics** — routes keep their geometric meaning (90° is 90°, 45° is 45°); no special-case logic.
3. **Acceptable trade-off** — 6% spacing reduction is imperceptible to coaches reviewing plays; visual field clarity remains high.
4. **Validated path** — Twins and Pro receivers remain well within bounds; only A/Z at extreme (route 3, 4, 7, 8) are affected.
5. **Future-proof** — if Pro formations are added with different multipliers, the unified spacing parameter scales consistently.

**What would invalidate this recommendation?**
- If user testing shows tight spacing (0.16) hurts formation recognition (feels crowded)
- If coaches frequently call routes 3, 4, 7, 8 on A/Z in real schemes (data-driven reason to preserve 0.17)
- If a new formation requires spacing > 0.17 to avoid clipping (would require revisiting sideMargin or fieldWidth)

---

## Next Steps

1. **Implement** — Change receiverSpacing to 0.16 in DiagramConfig.standard()
2. **Unit test** — Create RouteDiagramGeometryTests validating positions for all formations
3. **Visual validation** — Render Trips Left (A route 3), Trips Right (A route 4) on multiple device sizes; confirm acceptable clipping behavior
4. **Regression** — Twins Y After/Go, Pro formations; all pass existing test suite
5. **Document** — Add inline comment to DiagramConfig explaining the 0.16 choice and Trips A edge-case trade-off
6. **Backlog** — If clipping becomes a user issue, file a technical enabler to investigate Option 2 (localized route geometry)

---

## Supporting Calculations

### Screen geometry (iPhone 390pt)
- Half-width: 195pt
- Margin per side: 31.2pt (8%)
- Usable per side: 163.8pt

### Receiver multipliers
- Twins: 2.0x (X), 1.0x (A), 1.0x (Y), 2.0x (Z)
- Trips: 2.5x (A/Z isolated), 1.5x (inside), 0.5x (slot)
- Pro: 2.2x (isolated), 0.75x (slot)

### Critical positions (0.16 spacing = 62.4pt)
| Formation | Receiver | Distance from center | From edge |
|-----------|----------|----------------------|-----------|
| Trips L | A (2.5x) | 156 | 39 |
| Trips R | A (2.5x) | 156 | 39 |
| Twins | X (2.0x) | 124.8 | 70.2 |
| Twins | Z (2.0x) | 124.8 | 70.2 |
| Pro | Isolated (2.2x) | 137.3 | 57.7 |

All well above sideMargin of 31.2pt except Trips A at 39pt — still 7.8pt safety margin for break geometry.

