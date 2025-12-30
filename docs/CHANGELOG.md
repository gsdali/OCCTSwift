# OCCTSwift Changelog

## [v0.2.1] - 2025-12-30

### Fixed
- **Memory management bug in `sectionWiresAtZ`** - Fixed double-free crash where Swift ARC and C++ were both releasing wire handles. Added `OCCTFreeWireArrayOnly()` for proper memory ownership delegation.

### Added

#### CAM Operations
- `Wire.offset(by:joinType:)` - Offset planar wires for tool compensation
- `Shape.sectionWiresAtZ(_:)` - Extract closed wire contours from Z-level sections

#### NURBS Curve Support

Full NURBS (Non-Uniform Rational B-Spline) curve creation with complete control over curve parameters.

**C Bridge Functions (`OCCTBridge.h/mm`):**

```c
// Full NURBS with all parameters
OCCTWireRef OCCTWireCreateNURBS(
    const double* poles,        // Control points [x,y,z] triplets
    int32_t poleCount,          // Number of control points
    const double* weights,      // Weight per pole (NULL for uniform)
    const double* knots,        // Knot values
    int32_t knotCount,          // Number of distinct knots
    const int32_t* multiplicities, // Multiplicity per knot (NULL for all 1s)
    int32_t degree              // Curve degree (1=linear, 2=quadratic, 3=cubic)
);

// Simplified: auto-generates clamped uniform knot vector
OCCTWireRef OCCTWireCreateNURBSUniform(
    const double* poles,
    int32_t poleCount,
    const double* weights,      // NULL for non-rational B-spline
    int32_t degree
);

// Convenience: cubic B-spline (degree 3, uniform weights)
OCCTWireRef OCCTWireCreateCubicBSpline(
    const double* poles,
    int32_t poleCount           // Minimum 4 for cubic
);
```

**Swift API (`Wire.swift`):**

```swift
// Full NURBS control
static func nurbs(
    poles: [SIMD3<Double>],
    weights: [Double]? = nil,
    knots: [Double],
    multiplicities: [Int32]? = nil,
    degree: Int32
) -> Wire?

// Simplified with auto-generated knots
static func nurbsUniform(
    poles: [SIMD3<Double>],
    weights: [Double]? = nil,
    degree: Int32
) -> Wire?

// Cubic B-spline shorthand
static func cubicBSpline(poles: [SIMD3<Double>]) -> Wire?
```

**Implementation Details:**
- Uses OCCT `Geom_BSplineCurve` for exact curve representation
- Clamped uniform knots: first/last knot multiplicity = degree + 1
- Supports rational curves (weights ≠ 1) for exact conic sections
- Can represent circles, ellipses, and other conics exactly

**Example Usage:**

```swift
// Cubic B-spline for transition curve
let transitionPath = Wire.cubicBSpline(poles: [
    SIMD3(0, 0, 0),
    SIMD3(20, 0, 0),
    SIMD3(40, 5, 0),
    SIMD3(60, 15, 0),
    SIMD3(80, 30, 0)
])

// Rational quadratic for exact quarter circle
let quarterCircle = Wire.nurbs(
    poles: [
        SIMD3(1, 0, 0),
        SIMD3(1, 1, 0),
        SIMD3(0, 1, 0)
    ],
    weights: [1.0, 0.7071, 1.0],  // sqrt(2)/2
    knots: [0.0, 1.0],
    multiplicities: [3, 3],
    degree: 2
)
```

### Tests Added
- `Create cubic B-spline` - Basic cubic curve creation
- `Create NURBS with uniform knots` - Quadratic uniform B-spline
- `Create weighted NURBS (rational curve)` - Rational curve with weights
- `Create full NURBS with explicit knots` - Complete parameter control
- `NURBS validation - too few poles` - Error handling
- `Sweep profile along NURBS path` - Integration with sweep operations

### Technical Notes

**Knot Vector for Clamped Uniform B-Spline:**
- For n control points and degree p:
- Total knots (with multiplicity) = n + p + 1
- First knot: value 0, multiplicity p+1
- Last knot: value 1, multiplicity p+1
- Interior knots: uniformly distributed, multiplicity 1

**OCCT Classes Used:**
- `Geom_BSplineCurve` - Core B-spline geometry
- `TColgp_Array1OfPnt` - Control point array
- `TColStd_Array1OfReal` - Weights and knots
- `TColStd_Array1OfInteger` - Multiplicities
- `BRepBuilderAPI_MakeEdge` - Edge from curve
- `BRepBuilderAPI_MakeWire` - Wire from edge

### Improved
- Loft operation now calls `CheckCompatibility(true)` to prevent twisted surfaces

---

## [v0.2.0] - 2025-12-29

### Added
- STEP import (`Shape.importSTEP`)
- Shape bounds (`Shape.bounds`)
- Shape slicing (`Shape.sliceAtZ`)
- Contour extraction (`Shape.contourPoints`, `Shape.edgePoints`)
- Tool sweep for CAM (`Shape.toolSweep`)
- Cylinder at point (`Shape.cylinderAt`)

---

## [v0.1.0] - Initial Release
- Basic primitives (box, cylinder, sphere, cone, torus)
- Boolean operations (union, subtract, intersect)
- Transformations (translate, rotate, scale, mirror)
- Wire creation (rectangle, circle, polygon, line, arc, B-spline)
- Sweep operations (extrude, revolve, pipe sweep, loft)
- Mesh generation with triangulation
- STL and STEP export/import
- Shape validation and healing
