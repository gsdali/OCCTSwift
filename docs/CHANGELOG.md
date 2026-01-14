# OCCTSwift Changelog

## [v0.9.0] - 2026-01-14

### Added

#### Curve Analysis
Comprehensive curve geometry analysis for wires using OCCT's BRepAdaptor_CompCurve.

- **`CurveInfo`** struct - Comprehensive curve information
  - `length` - Total curve length
  - `isClosed` - Whether the curve forms a closed loop
  - `isPeriodic` - Whether the curve is periodic
  - `startPoint` / `endPoint` - Curve endpoints

- **`CurvePoint`** struct - Point on curve with differential geometry
  - `position` - 3D position on curve
  - `tangent` - Unit tangent vector
  - `curvature` - Curvature value (1/radius)
  - `normal` - Principal normal (when curvature > 0)

- **Wire extensions for curve analysis**
  - `length: Double?` - Total length of wire
  - `curveInfo: CurveInfo?` - Complete curve information
  - `point(at:) -> SIMD3<Double>?` - Point at normalized parameter (0-1)
  - `tangent(at:) -> SIMD3<Double>?` - Unit tangent at parameter
  - `curvature(at:) -> Double?` - Curvature at parameter
  - `curvePoint(at:) -> CurvePoint?` - Full differential geometry data

- **Wire 3D offset**
  - `offset3D(distance:direction:) -> Wire?` - Translate wire in 3D space

#### Surface Creation
Freeform surface creation for complex geometry.

- **B-spline surfaces**
  - `Shape.surface(poles:uDegree:vDegree:)` - Create B-spline surface from control point grid

- **Ruled surfaces**
  - `Shape.ruled(profile1:profile2:)` - Create ruled surface between two wires

- **Shell with open faces**
  - `Shape.shelled(thickness:openFaces:)` - Create hollow solid with specific faces left open

**C Bridge Functions:**
```c
// Curve Analysis
typedef struct { double length; bool isClosed, isPeriodic; double startX, startY, startZ, endX, endY, endZ; bool isValid; } OCCTCurveInfo;
typedef struct { double posX, posY, posZ, tanX, tanY, tanZ; double curvature; double normX, normY, normZ; bool hasNormal, isValid; } OCCTCurvePoint;

OCCTCurveInfo OCCTWireGetCurveInfo(OCCTWireRef wire);
double OCCTWireGetLength(OCCTWireRef wire);
bool OCCTWireGetPointAt(OCCTWireRef wire, double param, double* x, double* y, double* z);
bool OCCTWireGetTangentAt(OCCTWireRef wire, double param, double* tx, double* ty, double* tz);
double OCCTWireGetCurvatureAt(OCCTWireRef wire, double param);
OCCTCurvePoint OCCTWireGetCurvePointAt(OCCTWireRef wire, double param);
OCCTWireRef OCCTWireOffset3D(OCCTWireRef wire, double distance, double dirX, double dirY, double dirZ);

// Surface Creation
OCCTShapeRef OCCTShapeCreateBSplineSurface(const double* poles, int32_t uCount, int32_t vCount, int32_t uDegree, int32_t vDegree);
OCCTShapeRef OCCTShapeCreateRuled(OCCTWireRef wire1, OCCTWireRef wire2);
OCCTShapeRef OCCTShapeShellWithOpenFaces(OCCTShapeRef shape, double thickness, const int32_t* openFaceIndices, int32_t faceCount);
```

### Tests Added
- Wire length calculation (2 tests)
- Wire curve info for circles and lines (2 tests)
- Point, tangent, and curvature at parameter (4 tests)
- Curve point with full derivatives (1 test)
- Wire 3D offset (1 test)
- B-spline surface creation (1 test)
- Ruled surface between circles (1 test)
- Shell with open faces (2 tests)

---

## [v0.8.0] - 2026-01-14

### Added

#### Advanced Modeling
Manufacturing-ready modeling operations for selective edge/face modifications and advanced sweeps.

- **Selective Fillet** - Apply fillets to specific edges instead of all edges
  - `filleted(edges:radius:)` - Uniform radius on selected edges
  - `filleted(edges:startRadius:endRadius:)` - Linear radius interpolation along edges

- **Draft Angles** - Add mold release draft to faces
  - `drafted(faces:direction:angle:neutralPlane:)` - Manufacturing draft for injection molding/casting

- **Defeaturing** - Remove features by deleting faces
  - `withoutFeatures(faces:)` - Remove faces and heal the geometry

- **Advanced Pipe Sweep** - Enhanced sweep with orientation control
  - `pipeShell(spine:profile:mode:solid:)` - Create pipes with sweep modes:
    - `.frenet` - Standard Frenet trihedron
    - `.correctedFrenet` - Avoids twisting at inflection points
    - `.fixed(binormal:)` - Constant profile orientation
    - `.auxiliary(spine:)` - Twist controlled by secondary curve

- **`PipeSweepMode`** enum - Sweep orientation control

- **Edge/Face index properties** - Edge and Face objects now track their index within the parent shape
  - `Edge.index: Int` - Index for selective operations
  - `Face.index: Int` - Index for selective operations

**C Bridge Functions:**
```c
// Selective Fillet
OCCTShapeRef OCCTShapeFilletEdges(OCCTShapeRef shape, const int32_t* edgeIndices, int32_t edgeCount, double radius);
OCCTShapeRef OCCTShapeFilletEdgesLinear(OCCTShapeRef shape, const int32_t* edgeIndices, int32_t edgeCount, double startRadius, double endRadius);

// Draft Angle
OCCTShapeRef OCCTShapeDraft(OCCTShapeRef shape, const int32_t* faceIndices, int32_t faceCount, double dirX, double dirY, double dirZ, double angle, double planeX, double planeY, double planeZ, double planeNx, double planeNy, double planeNz);

// Defeaturing
OCCTShapeRef OCCTShapeRemoveFeatures(OCCTShapeRef shape, const int32_t* faceIndices, int32_t faceCount);

// Advanced Pipe Sweep
OCCTShapeRef OCCTShapeCreatePipeShell(OCCTWireRef spine, OCCTWireRef profile, OCCTPipeMode mode, bool solid);
OCCTShapeRef OCCTShapeCreatePipeShellWithBinormal(OCCTWireRef spine, OCCTWireRef profile, double bnX, double bnY, double bnZ, bool solid);
OCCTShapeRef OCCTShapeCreatePipeShellWithAuxSpine(OCCTWireRef spine, OCCTWireRef profile, OCCTWireRef auxSpine, bool solid);
```

### Tests Added
- Selective fillet on specific edges (3 tests)
- Edge and Face index tracking (2 tests)
- Draft angle on vertical faces (1 test)
- Defeaturing (1 test)
- Pipe shell with various modes (4 tests)

---

## [v0.7.0] - 2026-01-14

### Added

#### Measurement & Analysis
Essential CAD/CAM analysis tools using OCCT's BRepGProp and BRepExtrema modules.

- **`ShapeProperties`** struct - Global properties of a shape
  - `volume` - Volume in cubic units
  - `surfaceArea` - Surface area in square units
  - `mass` - Mass with density applied
  - `centerOfMass` - Center of mass as SIMD3<Double>
  - `momentOfInertia` - Inertia tensor as simd_double3x3

- **`DistanceResult`** struct - Distance measurement result
  - `distance` - Minimum distance between shapes
  - `pointOnShape1` / `pointOnShape2` - Closest points
  - `solutionCount` - Number of distance solutions

- **Shape extensions for mass properties**
  - `volume: Double?` - Get shape volume
  - `surfaceArea: Double?` - Get surface area
  - `centerOfMass: SIMD3<Double>?` - Get center of mass
  - `properties(density:) -> ShapeProperties?` - Full mass properties with density

- **Shape extensions for distance measurement**
  - `distance(to:deflection:) -> DistanceResult?` - Full distance analysis
  - `minDistance(to:) -> Double?` - Minimum distance between shapes
  - `intersects(_:tolerance:) -> Bool` - Check if shapes intersect/touch

- **Shape extensions for vertex iteration**
  - `vertexCount: Int` - Number of unique vertices
  - `vertices() -> [SIMD3<Double>]` - All vertex positions
  - `vertex(at:) -> SIMD3<Double>?` - Vertex at index

**C Bridge Functions:**
```c
// Mass Properties (BRepGProp)
typedef struct {
    double volume, surfaceArea, mass;
    double centerX, centerY, centerZ;
    double ixx, ixy, ixz, iyx, iyy, iyz, izx, izy, izz;
    bool isValid;
} OCCTShapeProperties;

OCCTShapeProperties OCCTShapeGetProperties(OCCTShapeRef shape, double density);
double OCCTShapeGetVolume(OCCTShapeRef shape);
double OCCTShapeGetSurfaceArea(OCCTShapeRef shape);
bool OCCTShapeGetCenterOfMass(OCCTShapeRef shape, double* outX, double* outY, double* outZ);

// Distance (BRepExtrema_DistShapeShape)
typedef struct {
    double distance;
    double p1x, p1y, p1z, p2x, p2y, p2z;
    int32_t solutionCount;
    bool isValid;
} OCCTDistanceResult;

OCCTDistanceResult OCCTShapeDistance(OCCTShapeRef shape1, OCCTShapeRef shape2, double deflection);
bool OCCTShapeIntersects(OCCTShapeRef shape1, OCCTShapeRef shape2, double tolerance);

// Vertex Iteration
int32_t OCCTShapeGetVertexCount(OCCTShapeRef shape);
bool OCCTShapeGetVertexAt(OCCTShapeRef shape, int32_t index, double* outX, double* outY, double* outZ);
int32_t OCCTShapeGetVertices(OCCTShapeRef shape, double* outVertices);
```

### Tests Added
- Volume calculation for box, sphere, cylinder (3 tests)
- Surface area calculation for box, sphere (2 tests)
- Center of mass for box, sphere, cylinder (3 tests)
- Full properties with density (1 test)
- Distance between separated shapes (1 test)
- Distance between touching shapes (1 test)
- Intersection detection (3 tests)
- Vertex count for box (1 test)
- Vertex enumeration (1 test)
- Vertex access by index (1 test)
- Invalid shape handling (1 test)

---

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

