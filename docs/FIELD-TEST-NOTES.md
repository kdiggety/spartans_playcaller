# Spartans Playcaller — Field Test Notes (Week of 2026-06-02)

## Build Version
- Version: 1.2.0
- Build: 2
- Date: 2026-05-29

## Changes in This Build

### 1. Route 0 (Hitch) → Bubble/Screen Route Fix
- **What:** Route 0 is now correctly implemented as a **bubble/screen route** that goes **backward behind the line of scrimmage**
- **How to test:**
  - Select any formation, parse digits ending in 0 (e.g., "6740")
  - Verify Route 0 is displayed as a backward/lateral route in the receiver assignment table
  - Diagram should show the route going backward, not upfield

### 2. Y Wheel Motion (NEW)
- **What:** Y receiver can now execute a **Y Wheel motion** — a semi-circular arc behind the formation (X/A or Z/A) and down the sideline
- **Key difference from Y After/Go:**
  - Y Wheel stays on the **same side** (unlike Y After/Go which flips sides)
  - Route interpretation applies from Y's original side
  - Diagram shows a curved motion arc (yellow dashed line)
- **How to test:**
  - Select Trips Left or Trips Right formation
  - Generate or parse a play (e.g., Smash = "6758")
  - Tap the motion picker
  - Select **"Y Wheel"** (should appear as a 4th option alongside Stop, After, Go)
  - Verify:
    - Diagram updates with a semi-circular arc behind the formation
    - Arc curves in the correct direction (left side for Trips Left, right for Trips Right)
    - Concept remains identified (Smash should stay Smash, since Y doesn't flip sides)

### 3. Route Interpretation Refactoring (Internal)
- **What:** Route meaning logic has been refactored into a pluggable **RouteSemanticProvider** pattern
- **Impact:** No visible changes; all existing plays should behave identically
- **Why:** Enables custom routes in future phases (e.g., route modifiers, additional formations)

## Testing Focus for This Week

1. **Route 0 (Bubble/Screen)**
   - Test bubble routes in practice plays
   - Verify backward direction is correct
   - Check diagram clarity on iPhone and iPad

2. **Y Wheel Motion**
   - Test Y Wheel in Trips Left and Trips Right formations
   - Verify arc direction and diagram clarity
   - Confirm concept identification holds correctly
   - Test motion toggle (Stop ↔ After ↔ Go ↔ Wheel)
   - **Field test under pressure:** Can you quickly switch between motion types during rapid play design?

3. **Overall Responsiveness**
   - How fast is formation selection and play generation?
   - Does the UI feel snappy under real practice conditions?
   - Any lag when switching formations or applying motion?

## Feedback Channels
- Ken directly or create issue in GitHub

---

**Next Steps After Field Test:**
1. Gather feedback on Y Wheel usability and motion arc clarity
2. Validate Route 0 bubble/screen rendering
3. Plan concept display feature (Twins chips, Trips Re-ID) if UX feedback warrants
4. Consider team theming (colors + logo)
