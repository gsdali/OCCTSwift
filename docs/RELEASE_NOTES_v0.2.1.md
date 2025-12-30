## v0.2.1 - 2025-12-30

### Bug Fixes

- **Fixed crash in `sectionWiresAtZ`** - Resolved double-free memory management issue where Swift ARC and C++ were both trying to release wire handles. Added `OCCTFreeWireArrayOnly()` to properly delegate memory ownership to Swift.

### New Features

#### CAM Operations

- **`Wire.offset(by:joinType:)`** - Offset planar wires by a distance for tool compensation
  - Positive distance = outward offset
  - Negative distance = inward offset
  - Supports `.arc` (rounded) and `.intersection` (sharp) corner joins

- **`Shape.sectionWiresAtZ(_:)`** - Extract closed wire contours from a Z-level section
  - Returns chained wires suitable for CAM toolpath generation
  - Works with `Wire.offset()` for safety boundary calculation

#### NURBS Curves

- **`Wire.nurbs(poles:weights:knots:multiplicities:degree:)`** - Full NURBS curve with complete parameter control

- **`Wire.nurbsUniform(poles:weights:degree:)`** - Simplified NURBS with auto-generated clamped uniform knot vector

- **`Wire.cubicBSpline(poles:)`** - Convenience method for cubic (degree 3) B-splines

### Improvements

- Loft operation now calls `CheckCompatibility(true)` to prevent twisted surfaces when profiles have different edge counts or orientations

- Improved documentation for `toolSweep`, `edgePoints`, and `contourPoints`

### Usage Examples

```swift
// CAM: Tool compensation
let modelContour = Wire.rectangle(width: 40, height: 30)
if let toolPath = modelContour.offset(by: 3.0) {  // 3mm tool radius
    // toolPath is where tool center should travel
}

// CAM: Z-level slicing
let model = try Shape.importSTEP(from: url)
let contours = model.sectionWiresAtZ(5.0)
for contour in contours {
    if let offsetContour = contour.offset(by: toolRadius) {
        // Generate toolpath from offsetContour
    }
}

// NURBS: Smooth transition curve
let transitionPath = Wire.cubicBSpline(poles: [
    SIMD3(0, 0, 0),
    SIMD3(20, 0, 0),
    SIMD3(40, 10, 0),
    SIMD3(60, 30, 0)
])
```

### Full Changelog

https://github.com/gsdali/OCCTSwift/compare/v0.2.0...v0.2.1
