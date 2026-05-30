# Y Wheel Arc Geometry Implementation

## Visual Specification

The Y wheel arc should render as a smooth U-shaped path that:
1. **Starts** at Y's position on the line of scrimmage
2. **Curves downward and to the side** (away from LOS, into the backfield)
3. **Curves back upward** (returning toward the LOS)
4. **Ends partway back** (not at start, not at max depth) with arrow pointing back at LOS
5. Is a **smooth curved path** (cubic Bézier, no sharp corners)
6. Has **reasonable scale** (20-30% of field height, similar to other route arrows)
7. **Colors**: Yellow

## Geometric Parameters

The arc uses a cubic Bézier curve with the following parameters:

```
loopDepth = fieldHeight * 0.22        // 22% of field height
sideOffset = fieldWidth * 0.05        // 5% of field width
endpointFraction = 0.55               // Endpoint 55% of the way down
```

## Curve Definition (Left Side Example)

For Y on the left side:

```
Start Point (P₀):
  x: Y_position.x
  y: Y_position.y

Control Point 1 (P₁):
  x: Y_position.x - sideOffset
  y: Y_position.y + loopDepth * 0.4

Control Point 2 (P₂):
  x: Y_position.x - sideOffset
  y: Y_position.y + loopDepth * 0.8

End Point (P₃):
  x: Y_position.x - sideOffset * 0.3
  y: Y_position.y + loopDepth * endpointFraction
```

## Cubic Bézier Curve Formula

The arc is sampled using the cubic Bézier formula:

```
B(t) = (1-t)³P₀ + 3(1-t)²tP₁ + 3(1-t)t²P₂ + t³P₃

where t ∈ [0, 1], sampled every 0.1 for smooth rendering
```

This produces 11 sample points along the curve:
- Point 0: t=0.0 (start)
- Points 1-10: t=0.1, 0.2, ..., 1.0
- Last point: t=1.0 (end)

## Behavior by Field Side

### Left Side (Trips Left, Pro Left Y Position)
- Arc curves **left and back**
- Control points: positioned left of Y
- Endpoint: slightly left of Y's starting X position

### Right Side (Trips Right, Pro Right Y Position)
- Arc curves **right and back**
- Control points: positioned right of Y
- Endpoint: slightly right of Y's starting X position

## Arc Depth Analysis

With the parameters above:

```
Arc Depth = loopDepth = 0.22 * fieldHeight

On iPhone 17 (812px height):
  Arc Depth ≈ 178px ≈ 22% of field

Comparison:
  routeLength = 25% of field ≈ 203px
  breakLength = 15% of field ≈ 122px
  Arc Depth ≈ between breakLength and routeLength (reasonable scale)
```

## Key Improvements from Previous Version

| Aspect | Previous | Current |
|--------|----------|---------|
| Arc Depth | 15% of field | 22% of field (more visible) |
| Side Offset | 6% of width | 5% of width (tighter) |
| Curve Type | U-shaped with control points | Proper cubic Bézier |
| Endpoint Y | 50% down | 55% down (more proportionate) |
| Endpoint X | Centered on Y | Offset toward side (more dynamic) |
| Bezier Formula | Incorrect (6-term) | Correct cubic (4-term) |

## Testing

See `YWheelArcVisualSpecTests.swift` for comprehensive validation:

1. **testYWheelArcStartsAtYPosition** — Verifies arc begins at Y
2. **testYWheelArcCurvesDownwardOnLeftSide** — Validates left-side geometry
3. **testYWheelArcCurvesDownwardOnRightSide** — Validates right-side geometry
4. **testYWheelArcReturnsUpwardTowardLOS** — Confirms upward return curve
5. **testYWheelArcEndpointIsPartiallyBack** — Checks endpoint position
6. **testYWheelArcScaleIsReasonable** — Validates depth is 10-40% of field
7. **testYWheelArcUsesYellowColor** — Confirms color
8. **testYWheelArcPathIsSmooth** — Validates smooth sampling without sharp corners
9. **testYWheelArcOnProLeft** — Tests Pro Left formation
10. **testYWheelArcOnProRight** — Tests Pro Right formation

## Diagram Rendering

In `RouteDiagramView.swift`, the arc is:
- Drawn using `Canvas.stroke()` with 3pt yellow line
- Sampled points provided for arrow placement
- Arrow drawn at endpoint pointing back toward LOS
- Appears after field and football, before routes and receivers (proper Z-order)
