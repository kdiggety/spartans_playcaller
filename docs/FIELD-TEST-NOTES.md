# Spartans Playcaller — Field Test Notes (Week of 2026-06-02)

## Build Version
- Version: 1.2.1
- Build: 3
- Date: 2026-05-29

## Changes in This Build

### 1. Route 0 (Hitch) → Bubble/Screen Route Fix
- **What:** Route 0 is now correctly implemented as a **bubble/screen route** that goes **backward behind the line of scrimmage**
- **How to test:**
  - Select any formation, parse digits ending in 0 (e.g., "6740")
  - Verify Route 0 is displayed as a backward/lateral route in the receiver assignment table
  - Diagram should show the route going backward, not upfield

### 2. Y Wheel Motion (REVISED)
- **What:** Y receiver can now execute a **Y Wheel motion** — a semi-circular arc behind the formation (X/A or Z/A) and down the sideline
- **Key behavior:**
  - Y Wheel is a **toggle** that works WITH Stop/After/Go motions
  - Y Stop + Y Wheel = Y stops on same side WITH wheel arc
  - Y After + Y Wheel = Y flips sides WITH wheel arc
  - Y Wheel alone (no motion selected) = wheel arc only
- **How to test:**
  - Select Trips Left or Trips Right formation
  - Generate or parse a play (e.g., Smash = "6758")
  - Motion picker shows: None | Stop | After | Go (3 options, no Wheel option)
  - Wheel toggle checkbox appears below motion picker
  - Select a motion (e.g., After)
  - Enable the "Y Wheel" toggle
  - Verify:
    - Diagram shows Y motion arc (After = Y flips to right)
    - PLUS wheel arc (semicircle behind formation)
    - Both arcs visible together
  - Toggle wheel off/on to see arc appear/disappear

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
   - Enable/disable wheel toggle independently from motion selection
   - Test all combinations: No Motion + Wheel, Stop + Wheel, After + Wheel, Go + Wheel
   - Confirm concept identification remains stable regardless of wheel state
   - **Field test under pressure:** Can you quickly toggle the wheel on/off during rapid play design?

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
