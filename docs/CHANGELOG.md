# OCCTSwift Changelog

## [v0.6.0] - 2026-01-14

### Added

#### XDE/XCAF Document Support
Full Extended Data Exchange (XDE) support for importing/exporting STEP files with assembly structure, part names, colors, and PBR materials.

- **`Document`** class - Load and write STEP files with full metadata
  - `Document.load(from:)` - Load STEP with assembly structure, names, colors, materials
  - `Document.write(to:)` - Export preserving all metadata
  - `rootNodes` - Access top-level assembly nodes
  - `allShapes()` - Get flat list of all shapes
  - `shapesWithColors()` - Get shapes with associated colors
  - `shapesWithMaterials()` - Get shapes with PBR materials

- **`AssemblyNode`** class - Represents a node in the assembly tree
  - `name` - Part name from CAD software
  - `isAssembly` / `isReference` - Node type queries
  - `transform` - 4x4 transform matrix (simd_float4x4)
  - `color` - Assigned color (if any)
  - `material` - PBR material (if available)
  - `children` - Child nodes for assemblies
  - `shape` - Geometry with transform applied

- **`Color`** struct - RGBA color representation
  - RGB components (0.0-1.0)
  - CGColor conversion (when CoreGraphics available)
  - Predefined colors (black, white, red, green, blue, gray, clear)

- **`Material`** struct - PBR material properties
  - `baseColor` - Albedo color
  - `metallic` - Metallic factor (0.0-1.0)
  - `roughness` - Roughness factor (0.0-1.0)
  - `emissive` - Emissive color
  - `transparency` - Transparency factor
  - Predefined materials (polishedMetal, brushedMetal, plastic, rubber, glass)

#### 2D Drawing / HLR Projection
Create 2D technical drawings from 3D shapes using Hidden Line Removal (HLR).

- **`Drawing`** class - 2D projection of 3D geometry
  - `Drawing.project(_:direction:type:)` - Create projection
  - `Drawing.topView(of:)` / `frontView` / `sideView` / `isometricView` - Standard views
  - `edges(ofType:)` - Get visible, hidden, or outline edges
  - `visibleEdges` / `hiddenEdges` / `outlineEdges` - Convenience accessors

> **Note:** DXF export is not included. The `Drawing` class provides edge geometry that can be exported using third-party DXF libraries. See the README for guidance.

**C Bridge Functions:**
```c
// Document lifecycle
OCCTDocumentRef OCCTDocumentCreate(void);
OCCTDocumentRef OCCTDocumentLoadSTEP(const char* path);
bool OCCTDocumentWriteSTEP(OCCTDocumentRef doc, const char* path);
void OCCTDocumentRelease(OCCTDocumentRef doc);

// Assembly traversal
int32_t OCCTDocumentGetRootCount(OCCTDocumentRef doc);
int64_t OCCTDocumentGetRootLabelId(OCCTDocumentRef doc, int32_t index);
const char* OCCTDocumentGetLabelName(OCCTDocumentRef doc, int64_t labelId);
bool OCCTDocumentIsAssembly(OCCTDocumentRef doc, int64_t labelId);
bool OCCTDocumentIsReference(OCCTDocumentRef doc, int64_t labelId);
int32_t OCCTDocumentGetChildCount(OCCTDocumentRef doc, int64_t labelId);
int64_t OCCTDocumentGetChildLabelId(OCCTDocumentRef doc, int64_t parentLabelId, int32_t index);
OCCTShapeRef OCCTDocumentGetShape(OCCTDocumentRef doc, int64_t labelId);
OCCTShapeRef OCCTDocumentGetShapeWithLocation(OCCTDocumentRef doc, int64_t labelId);

// Colors and Materials
OCCTColor OCCTDocumentGetLabelColor(OCCTDocumentRef doc, int64_t labelId, OCCTColorType colorType);
void OCCTDocumentSetLabelColor(OCCTDocumentRef doc, int64_t labelId, OCCTColorType colorType, double r, double g, double b);
OCCTMaterial OCCTDocumentGetLabelMaterial(OCCTDocumentRef doc, int64_t labelId);
void OCCTDocumentSetLabelMaterial(OCCTDocumentRef doc, int64_t labelId, OCCTMaterial material);

// 2D Drawing / HLR Projection
OCCTDrawingRef OCCTDrawingCreate(OCCTShapeRef shape, double dirX, double dirY, double dirZ, OCCTProjectionType type);
OCCTShapeRef OCCTDrawingGetEdges(OCCTDrawingRef drawing, OCCTEdgeType edgeType);
void OCCTDrawingRelease(OCCTDrawingRef drawing);
```

### Tests Added
- Color creation and predefined colors (3 tests)
- Material creation and clamping (3 tests)
- Drawing projection and edge extraction (4 tests)
- Document creation (1 test)

---

## [v0.5.0] - 2026-01-02

### Added

#### AAG-Based Feature Recognition
- **`AttributeAdjacencyGraph`** - Build face adjacency graph for B-Rep feature detection
  - Analyzes edge convexity between adjacent faces
  - Supports pocket, boss, and through-hole detection
  - Uses concave edge connectivity for robust feature isolation

- **`Shape.pocketFaces()`** - Detect pocket floor faces using AAG analysis
  - Finds upward-facing planar faces bounded by concave edges
  - More reliable than simple Z-slicing for complex geometry
  - Returns array of `Face` objects for toolpath generation

- **`Mesh.toMeshResource()`** - Convert to RealityKit `MeshResource` (iOS/macOS)
- **`Mesh.toModelComponent()`** - Convert to RealityKit `ModelComponent`

**C Bridge Functions:**
```c
OCCTAAGRef OCCTShapeCreateAAG(OCCTShapeRef shape);
OCCTFaceRef* OCCTAAGGetPocketFaces(OCCTAAGRef aag, int32_t* outCount);
void OCCTAAGRelease(OCCTAAGRef aag);
```

### Changed

#### Wire Factory Methods Now Return Optionals (Breaking Change)

All Wire factory methods now return `Wire?` instead of `Wire`, allowing graceful handling of invalid inputs:

| Method | Returns nil when |
|--------|-----------------|
| `rectangle(width:height:)` | width or height ≤ 0 |
| `circle(radius:)` | radius ≤ 0 |
| `polygon(_:closed:)` | fewer than 2 points |
| `line(from:to:)` | start equals end |
| `arc(center:radius:...)` | radius ≤ 0 |
| `path(from:to:bulge:)` | invalid geometry |
| `join(_:)` | empty array or OCCT failure |
| `bspline(controlPoints:)` | too few control points |
| `nurbs(...)` | invalid parameters |

**Migration:**
```swift
// Before (v0.4.0)
let rect = Wire.rectangle(width: 10, height: 5)
let solid = Shape.extrude(profile: rect, direction: [0,0,1], length: 10)

// After (v0.5.0)
guard let rect = Wire.rectangle(width: 10, height: 5) else {
    // Handle invalid dimensions
    return
}
let solid = Shape.extrude(profile: rect, direction: [0,0,1], length: 10)
```

### Fixed
- **Wire.polygon crash on complex geometry** - Now returns nil instead of crashing when OCCT's `BRepBuilderAPI_MakePolygon` fails (#18)

### Tests Added
- `polygonTooFewPoints` - Verify nil return for insufficient points
- `lineDegenerate` - Verify nil return for zero-length line
- `arcZeroRadius` - Verify nil return for invalid arc
- `rectangleZeroDimension` - Verify nil return for zero-size rectangle

---

## [v0.4.0] - 2025-12-31

**Major upgrade to OCCT 8.0.0-rc3**

### Added

#### Robust STEP Import
- **`Shape.loadRobust(from:)`** - Import STEP files with automatic repair
  - Sews disconnected faces into connected geometry
  - Converts shells to valid closed solids
  - Applies shape healing for geometry issues
  - Recommended for files from external CAD systems

- **`Shape.loadWithDiagnostics(from:)`** - Import with processing information
  - Returns `ImportResult` with shape and diagnostic flags
  - Shows what processing was applied (sewing, solid creation, healing)
  - Useful for debugging import issues

- **`Shape.shapeType`** - Get topological type (Solid, Shell, Face, etc.)
- **`Shape.isValidSolid`** - Check if shape is a valid closed solid

**C Bridge Functions:**
```c
OCCTShapeRef OCCTImportSTEPRobust(const char* path);
OCCTSTEPImportResult OCCTImportSTEPWithDiagnostics(const char* path);
int OCCTShapeGetType(OCCTShapeRef shape);
bool OCCTShapeIsValidSolid(OCCTShapeRef shape);
```

### Changed
- **Upgraded OpenCASCADE to 8.0.0-rc3** (from 7.8.1)
- Build script now uses GitHub for RC releases

### Fixed
- **STEP export segfault at program exit** - The crash during static destruction (OCCT bug #33656) is now fixed
  - All STEP exports exit cleanly with code 0
  - No more crash after exporting complex geometry like slab track

### Technical Details
- OCCT 8.0 includes RTTI reorganization (GitHub issue #146)
- Standard C++ `type_info` replaces custom OCCT RTTI system
- Math functions modernized to use C++ standard library
- Performance improvements in threading and BSpline computation

### Migration Notes
- No API changes required - drop-in replacement for v0.3.0
- XCFramework size: 546MB (iOS: 196MB, Simulator: 175MB, macOS: 175MB)

---

## [v0.3.0] - 2025-12-31

Final release based on OCCT 7.8.1.

### Added

#### Face Analysis for CAM Pocket Detection
- **New `Face` class** - Represents a bounded surface from a solid shape
  - `normal` - Get normal vector at face center
  - `outerWire` - Extract boundary wire for toolpath generation
  - `bounds` - Bounding box of face
  - `isPlanar` - Check if face is flat
  - `zLevel` - Get Z coordinate of horizontal planar face
  - `isHorizontal(tolerance:)` - Check if normal points up/down
  - `isUpwardFacing(tolerance:)` - Check if normal points up (pocket floor)

- **Shape extensions for face extraction**
  - `faces()` - Get all faces from solid
  - `horizontalFaces(tolerance:)` - Get horizontal faces only
  - `upwardFaces(tolerance:)` - Get upward-facing faces (pocket floors)
  - `facesByZLevel(tolerance:)` - Group faces by Z for multi-level pockets

**C Bridge Functions:**
```c
OCCTFaceRef* OCCTShapeGetFaces(OCCTShapeRef shape, int32_t* outCount);
OCCTFaceRef* OCCTShapeGetHorizontalFaces(OCCTShapeRef shape, double tolerance, int32_t* outCount);
OCCTFaceRef* OCCTShapeGetUpwardFaces(OCCTShapeRef shape, double tolerance, int32_t* outCount);
bool OCCTFaceGetNormal(OCCTFaceRef face, double* outNx, double* outNy, double* outNz);
OCCTWireRef OCCTFaceGetOuterWire(OCCTFaceRef face);
void OCCTFaceGetBounds(OCCTFaceRef face, double* minX, ...);
bool OCCTFaceIsPlanar(OCCTFaceRef face);
bool OCCTFaceGetZLevel(OCCTFaceRef face, double* outZ);
```

**Use Case:** Detects pockets in solid models that wire-based Z-slicing cannot find.

### Changed
- Simplified STEP export to use stack-allocated writer (internal cleanup)

### Known Issues (Fixed in v0.4.0)
- ~~STEP export of complex geometry crashes at program exit~~ - Fixed by upgrading to OCCT 8.0

---

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

