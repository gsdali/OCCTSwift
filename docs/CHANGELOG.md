# OCCTSwift Changelog

## [v0.17.0] - 2026-02-14

### Mesh Import, OBJ/PLY Export, Advanced Healing, Point Classification

New capabilities for importing mesh formats, exporting to additional mesh formats, advanced shape healing utilities, and classifying points relative to solids and faces. 23 new tests across 6 suites.

#### STL Import
| Swift API | OCCT Class |
|-----------|------------|
| `Shape.loadSTL(from:)` | `StlAPI_Reader` |
| `Shape.loadSTL(fromPath:)` | `StlAPI_Reader` |
| `Shape.loadSTLRobust(from:sewingTolerance:)` | `StlAPI_Reader` + `BRepBuilderAPI_Sewing` + `ShapeFix_Shape` |
| `Shape.loadSTLRobust(fromPath:sewingTolerance:)` | `StlAPI_Reader` + `BRepBuilderAPI_Sewing` + `ShapeFix_Shape` |

#### OBJ Import/Export
| Swift API | OCCT Class |
|-----------|------------|
| `Shape.loadOBJ(from:)` | `RWObj_CafReader` |
| `Shape.loadOBJ(fromPath:)` | `RWObj_CafReader` |
| `Exporter.writeOBJ(shape:to:deflection:)` | `RWObj_CafWriter` |
| `shape.writeOBJ(to:deflection:)` | `RWObj_CafWriter` |

#### PLY Export
| Swift API | OCCT Class |
|-----------|------------|
| `Exporter.writePLY(shape:to:deflection:)` | `RWPly_CafWriter` |
| `shape.writePLY(to:deflection:)` | `RWPly_CafWriter` |

#### Advanced Shape Healing
| Swift API | OCCT Class |
|-----------|------------|
| `shape.divided(at:)` | `ShapeUpgrade_ShapeDivide` |
| `shape.directFaces()` | `ShapeCustom::DirectFaces` |
| `shape.scaledGeometry(factor:)` | `ShapeCustom::ScaleShape` |
| `shape.bsplineRestriction(...)` | `ShapeCustom::BSplineRestriction` |
| `shape.sweptToElementary()` | `ShapeCustom::SweptToElementary` |
| `shape.revolutionToElementary()` | `ShapeCustom::ConvertToRevolution` |
| `shape.convertedToBSpline()` | `ShapeCustom::ConvertToBSpline` |
| `shape.sewn(tolerance:)` | `BRepBuilderAPI_Sewing` |
| `shape.upgraded(tolerance:)` | `BRepBuilderAPI_Sewing` + `BRepBuilderAPI_MakeSolid` + `ShapeFix_Shape` |

#### Point Classification
| Swift API | OCCT Class |
|-----------|------------|
| `shape.classify(point:tolerance:)` | `BRepClass3d_SolidClassifier` |
| `face.classify(point:tolerance:)` | `BRepClass_FaceClassifier` |
| `face.classify(u:v:tolerance:)` | `BRepClass_FaceClassifier` |

#### New Types
- `GeometricContinuity` — enum for C0/C1/C2/C3 continuity levels
- `PointClassification` — enum for inside/outside/onBoundary/unknown

### Statistics
- 327 tests passing across 62 suites (23 new tests across 6 new suites)
- +1,095 lines across 5 files
- 1 commit since v0.16.0

---

## [v0.16.0] - 2026-02-14

### 2D Parametric Curves (Geom2d)

New `Curve2D` class wrapping OCCT's `Handle(Geom2d_Curve)` polymorphically. A single type represents all 2D curve subtypes with factory methods for creation, evaluation for sampling, operations for manipulation, analysis for querying, and draw methods for Metal rendering. 69 new tests across 11 suites.

#### Core Type
- `Curve2D` — final class wrapping `Handle(Geom2d_Curve)` with automatic memory management
- Properties: `domain`, `isClosed`, `isPeriodic`, `period`, `startPoint`, `endPoint`, `boundingBox`
- Evaluation: `point(at:)`, `d1(at:)`, `d2(at:)`

#### Primitive Curves
| Swift API | OCCT Class |
|-----------|------------|
| `Curve2D.line(through:direction:)` | `Geom2d_Line` |
| `Curve2D.segment(from:to:)` | `GCE2d_MakeSegment` |
| `Curve2D.circle(center:radius:)` | `Geom2d_Circle` |
| `Curve2D.arcOfCircle(center:radius:startAngle:endAngle:)` | `GCE2d_MakeArcOfCircle` |
| `Curve2D.arcThrough(_:_:_:)` | `GCE2d_MakeArcOfCircle` |
| `Curve2D.ellipse(center:majorRadius:minorRadius:rotation:)` | `GCE2d_MakeEllipse` |
| `Curve2D.arcOfEllipse(...)` | `GCE2d_MakeArcOfEllipse` |
| `Curve2D.parabola(focus:direction:focalLength:)` | `Geom2d_Parabola` |
| `Curve2D.hyperbola(center:majorRadius:minorRadius:rotation:)` | `Geom2d_Hyperbola` |
| `Curve2D.arcOfHyperbola(...)` | `Geom2d_TrimmedCurve` + `Geom2d_Hyperbola` |
| `Curve2D.arcOfParabola(...)` | `Geom2d_TrimmedCurve` + `Geom2d_Parabola` |

#### BSpline & Bezier
| Swift API | OCCT Class |
|-----------|------------|
| `Curve2D.bspline(poles:weights:knots:multiplicities:degree:)` | `Geom2d_BSplineCurve` |
| `Curve2D.bezier(poles:weights:)` | `Geom2d_BezierCurve` |
| `Curve2D.interpolate(through:closed:tolerance:)` | `Geom2dAPI_Interpolate` |
| `Curve2D.interpolate(through:startTangent:endTangent:tolerance:)` | `Geom2dAPI_Interpolate` |
| `Curve2D.fit(through:minDegree:maxDegree:tolerance:)` | `Geom2dAPI_PointsToBSpline` |
- Pole queries: `poleCount`, `poles`, `degree`

#### Draw Methods (Metal Discretization)
Discretize curves to `[SIMD2<Double>]` polylines for GPU rendering:
- `drawAdaptive(angularDeflection:chordalDeflection:maxPoints:)` — `GCPnts_TangentialDeflection`
- `drawUniform(pointCount:)` — `GCPnts_UniformAbscissa`
- `drawDeflection(deflection:maxPoints:)` — `GCPnts_UniformDeflection`

#### Operations
| Swift API | OCCT Class |
|-----------|------------|
| `trimmed(from:to:)` | `Geom2d_TrimmedCurve` |
| `offset(by:)` | `Geom2d_OffsetCurve` |
| `reversed()` | `Geom2d_Curve::Reversed()` |
| `translated(by:)` | `gp_Trsf2d` |
| `rotated(around:angle:)` | `gp_Trsf2d` |
| `scaled(from:factor:)` | `gp_Trsf2d` |
| `mirrored(acrossLine:direction:)` | `gp_Trsf2d` |
| `mirrored(acrossPoint:)` | `gp_Trsf2d` |
| `length` / `length(from:to:)` | `GCPnts_AbscissaPoint` |

#### Local Properties (Geom2dLProp)
| Swift API | OCCT Class |
|-----------|------------|
| `curvature(at:)` | `Geom2dLProp_CLProps2d` |
| `normal(at:)` | `Geom2dLProp_CLProps2d` |
| `tangentDirection(at:)` | `Geom2dLProp_CLProps2d` |
| `centerOfCurvature(at:)` | `Geom2dLProp_CLProps2d` |
| `inflectionPoints()` | `Geom2dLProp_CurAndInf2d` |
| `curvatureExtrema()` | `Geom2dLProp_CurAndInf2d` |
| `allSpecialPoints()` | `Geom2dLProp_CurAndInf2d` |

#### Analysis
| Swift API | OCCT Class |
|-----------|------------|
| `intersections(with:tolerance:)` | `Geom2dAPI_InterCurveCurve` |
| `selfIntersections(tolerance:)` | `Geom2dAPI_InterCurveCurve` |
| `project(point:)` | `Geom2dAPI_ProjectPointOnCurve` |
| `allProjections(of:)` | `Geom2dAPI_ProjectPointOnCurve` |
| `minDistance(to:)` | `Geom2dAPI_ExtremaCurveCurve` |
| `allExtrema(with:)` | `Geom2dAPI_ExtremaCurveCurve` |

#### Conversion
| Swift API | OCCT Class |
|-----------|------------|
| `toBSpline(tolerance:)` | `Geom2dConvert::CurveToBSplineCurve` |
| `toBezierSegments()` | `Geom2dConvert_BSplineCurveToBezierCurve` |
| `Curve2D.join(_:tolerance:)` | `Geom2dConvert_CompCurveToBSplineCurve` |
| `approximated(tolerance:continuity:maxDegree:maxSegments:)` | `Geom2dConvert_ApproxCurve` |
| `splitIndicesAtDiscontinuities(continuity:)` | `Geom2dConvert_BSplineCurveKnotSplitting` |
| `toArcsAndSegments(tolerance:angleTolerance:)` | `Geom2dConvert_ApproxArcsSegments` |

#### Constraint Solver (Geom2dGcc)
`Curve2DGcc` namespace with geometric constraint solvers:
| Swift API | OCCT Class |
|-----------|------------|
| `circlesTangentTo(_:_:_:...)` | `Geom2dGcc_Circ2d3Tan` |
| `circlesTangentToTwoCurvesAndPoint(...)` | `Geom2dGcc_Circ2d3Tan` |
| `circlesTangentWithCenter(_:_:center:...)` | `Geom2dGcc_Circ2dTanCen` |
| `circlesTangentToTwoCurves(_:_:_:_:radius:...)` | `Geom2dGcc_Circ2d2TanRad` |
| `circlesTangentToPointWithRadius(_:_:point:radius:...)` | `Geom2dGcc_Circ2d2TanRad` |
| `circlesThroughTwoPoints(_:_:radius:...)` | `Geom2dGcc_Circ2d2TanRad` |
| `circleThroughThreePoints(_:_:_:...)` | `Geom2dGcc_Circ2d3Tan` |
| `linesTangentTo(_:_:_:_:...)` | `Geom2dGcc_Lin2d2Tan` |
| `linesTangentToPoint(_:_:point:...)` | `Geom2dGcc_Lin2d2Tan` |

#### Hatching & Bisector
| Swift API | OCCT Class |
|-----------|------------|
| `Curve2DGcc.hatch(boundaries:origin:direction:spacing:...)` | `Geom2dHatch_Hatcher` |
| `bisector(with:origin:side:)` | `Bisector_BisecCC` |
| `bisector(withPoint:origin:side:)` | `Bisector_BisecPC` |

#### Result Types
- `Curve2DIntersection` — intersection point, parameters on both curves
- `Curve2DProjection` — projected point, parameter, distance
- `Curve2DExtremaResult` — closest points on two curves with parameters
- `Curve2DSpecialPoint` — inflection/min/max curvature with parameter
- `Curve2DCircleSolution` — center, radius, qualifier from Gcc solver
- `Curve2DLineSolution` — point, direction, qualifier from Gcc solver
- `Curve2DHatchSegment` — start/end points of hatch line segment

### Statistics
- 304 tests passing across 56 suites (69 new tests across 11 new suites)
- 1 new Swift source file (`Curve2D.swift`), +2,878 lines across 4 files
- 2 commits since v0.15.0

---

## [v0.15.0] - 2026-02-14

### Metal Visualization Wrappers

Six new Swift types providing GPU-friendly geometry extraction, camera math, and interactive picking from OCCT — without depending on OCCT's OpenGL rendering layer. Designed for Metal viewports (e.g. ViewportKit). Closes #32.

#### Camera
- `Camera` — wraps `Graphic3d_Camera` with Metal-compatible [0,1] depth range
- Produces `simd_float4x4` projection and view matrices directly usable by Metal shaders
- Project/unproject between world and screen coordinates
- Auto-frame geometry with `fit(boundingBox:)`
- Perspective and orthographic projection modes

#### PresentationMesh (Geometry Extraction)
- `Shape.shadedMesh(deflection:)` — indexed triangle mesh with per-vertex normals for Metal vertex buffers
- `Shape.edgeMesh(deflection:)` — edge wireframe polylines with segment boundaries
- `Shape.shadedMesh(drawer:)` / `Shape.edgeMesh(drawer:)` — drawer-controlled tessellation quality

#### Selector (Hit Testing)
- `Selector` — BVH-accelerated picking without OpenGL
- Point pick, rectangle pick, and polygon (lasso) pick
- Sub-shape selection modes: `.shape`, `.face`, `.edge`, `.vertex`, `.wire`
- Configurable pixel tolerance
- Returns hit depth, 3D point, sub-shape type and index

#### ClipPlane
- `ClipPlane` — wraps `Graphic3d_ClipPlane` for Metal `[[clip_distance]]`
- Plane equation get/set, reversed equation for back-face clipping
- Capping with color and hatch patterns
- Probe points and bounding boxes against half-space
- AND-chain multiple planes

#### ZLayerSettings
- `ZLayerSettings` — wraps `Graphic3d_ZLayerSettings` for render layer ordering
- Depth test/write control, polygon offset (`setDepthBias`)
- Culling distance/size, origin offset
- Predefined layer IDs (default, top, topmost, bottomOSD, topOSD)

#### DisplayDrawer
- `DisplayDrawer` — wraps `Prs3d_Drawer` for tessellation quality control
- Deviation coefficient/angle, deflection type (relative/absolute)
- Wire draw, face boundary draw, iso-on-triangulation toggles
- Discretisation control

### Documentation
- Added [`docs/METAL_VISUALIZATION_API.md`](METAL_VISUALIZATION_API.md) with full API reference and Metal integration examples

### Statistics
- 235 tests passing across 45 suites (69 new tests across 9 new suites)
- 6 new Swift source files, +4,065 lines
- 6 commits since v0.14.0

---

## [v0.14.0] - 2026-02-14

### Breaking Changes — Safe Optional Returns

All Shape and Mesh creation methods now return optionals instead of force-unwrapping. This eliminates crashes when OCCT operations fail (e.g. invalid geometry, degenerate inputs) and replaces the previous `try`-prefixed safe variants which have been removed. Closes #30.

**26 methods changed from non-optional to optional return types:**

| Category | Methods |
|----------|---------|
| Primitives | `box(width:height:depth:)`, `box(origin:...)`, `cylinder(radius:height:)`, `cylinder(at:...)`, `sphere(radius:)`, `cone(...)`, `torus(...)`, `toolSweep(...)` |
| Sweeps | `sweep(profile:along:)`, `extrude(...)`, `revolve(...)`, `loft(...)` |
| Booleans | `union(with:)`, `subtracting(_:)`, `intersection(with:)` |
| Modifications | `filleted(radius:)`, `chamfered(distance:)`, `shelled(thickness:)`, `offset(by:)` |
| Transforms | `translated(by:)`, `rotated(axis:angle:)`, `scaled(by:)`, `mirrored(...)` |
| Compound | `compound(_:)` |
| Validation | `healed()` |
| Meshing | `mesh(linearDeflection:angularDeflection:)`, `mesh(parameters:)` |
| Operators | `+` (`Shape?`), `-` (`Shape?`), `&` (`Shape?`) |

**15 `try`-prefixed methods removed** (the base methods are now safe):
`tryBox`, `tryCylinder`, `trySphere`, `tryCone`, `tryTorus`, `tryUnion`, `trySubtracting`, `tryIntersection`, `tryFilleted`, `tryChamfered`, `tryShelled`, `tryOffset`, `tryTranslated`, `tryRotated`, `tryScaled`, `tryMirrored`

#### Migration Guide

**Simple case — add `!` or `guard let`:**
```swift
// Before:
let box = Shape.box(width: 10, height: 5, depth: 3)
let mesh = box.mesh(linearDeflection: 0.1)

// After (force-unwrap when you know inputs are valid):
let box = Shape.box(width: 10, height: 5, depth: 3)!
let mesh = box.mesh(linearDeflection: 0.1)!

// After (graceful handling):
guard let box = Shape.box(width: 10, height: 5, depth: 3) else { return }
guard let mesh = box.mesh(linearDeflection: 0.1) else { return }
```

**Chained operations:**
```swift
// Before:
let result = Shape.box(width: 10, height: 10, depth: 10)
    .translated(by: SIMD3(5, 0, 0))
    .filleted(radius: 1.0)

// After:
let result = Shape.box(width: 10, height: 10, depth: 10)!
    .translated(by: SIMD3(5, 0, 0))!
    .filleted(radius: 1.0)
```

**Boolean operators:**
```swift
// Before:
let union = box + sphere

// After:
let union = (box + sphere)!
// or:
let union = box.union(with: sphere)!
```

**Replacing try-prefixed methods:**
```swift
// Before:
let box = Shape.tryBox(width: w, height: h, depth: d)
let result = shape.tryFilleted(radius: r)

// After (identical behavior):
let box = Shape.box(width: w, height: h, depth: d)
let result = shape.filleted(radius: r)
```

### Added

#### Shape.fromWire(_:) — Wire to Shape Conversion
Convert a Wire to a Shape to access edge extraction methods without creating solid geometry. Closes #31.

```swift
let path = Wire.circle(radius: 10)!
let shape = Shape.fromWire(path)!
let polylines = shape.allEdgePolylines()  // wireframe rendering
```

#### Variable Radius Fillet
Apply fillets with varying radius along an edge.

- **`shape.filletedVariable(edgeIndex:radiusProfile:)`** - Variable radius fillet
  - `radiusProfile` - Array of (parameter, radius) pairs
  - Parameters normalized 0.0 (start) to 1.0 (end)

```swift
// Fillet varying from 1mm to 3mm along edge
let filleted = shape.filletedVariable(
    edgeIndex: 0,
    radiusProfile: [(0.0, 1.0), (1.0, 3.0)]
)

// Bulging fillet: 1mm at ends, 4mm in middle
let bulge = shape.filletedVariable(
    edgeIndex: 0,
    radiusProfile: [(0.0, 1.0), (0.5, 4.0), (1.0, 1.0)]
)
```

#### Multi-Edge Blend
Apply fillets to multiple edges with individual radii.

- **`shape.blendedEdges(_:)`** - Fillet multiple edges with different radii

```swift
let blended = shape.blendedEdges([
    (0, 1.0),  // Edge 0: 1mm fillet
    (1, 2.0),  // Edge 1: 2mm fillet
    (2, 0.5)   // Edge 2: 0.5mm fillet
])
```

#### 2D Wire Fillet
Round corners on planar wires.

- **`wire.filleted2D(vertexIndex:radius:)`** - Fillet single vertex
- **`wire.filletedAll2D(radius:)`** - Fillet all vertices

```swift
let rect = Wire.rectangle(width: 10, height: 5)

// Fillet one corner
let oneCorner = rect?.filleted2D(vertexIndex: 0, radius: 1.0)

// Rounded rectangle
let rounded = rect?.filletedAll2D(radius: 1.0)
```

#### 2D Wire Chamfer
Cut corners on planar wires.

- **`wire.chamfered2D(vertexIndex:distance1:distance2:)`** - Chamfer single vertex
- **`wire.chamferedAll2D(distance:)`** - Chamfer all vertices

```swift
let rect = Wire.rectangle(width: 10, height: 5)

// Asymmetric chamfer
let chamfered = rect?.chamfered2D(vertexIndex: 0, distance1: 1.0, distance2: 2.0)

// Chamfer all corners
let allChamfered = rect?.chamferedAll2D(distance: 1.0)
```

#### Surface Filling
Create surfaces constrained by boundaries.

- **`SurfaceContinuity`** enum - `.c0`, `.g1`, `.g2`
- **`FillingParameters`** struct - Control filling operation
- **`Shape.fill(boundaries:parameters:)`** - Fill N-sided boundary

```swift
let params = FillingParameters(continuity: .g1, tolerance: 1e-4)
let surface = Shape.fill(boundaries: [closedWire], parameters: params)
```

#### Plate Surfaces
Create surfaces through points or along curves.

- **`Shape.plateSurface(through:tolerance:)`** - Surface through points
- **`Shape.plateSurface(constrainedBy:continuity:tolerance:)`** - Surface along curves

```swift
// Surface through scattered points
let surface = Shape.plateSurface(through: [
    SIMD3(0, 0, 0),
    SIMD3(10, 0, 1),
    SIMD3(10, 10, 2),
    SIMD3(0, 10, 1),
    SIMD3(5, 5, 3)  // Raised center
], tolerance: 0.01)
```

### Fixed

- Edge polylines missing on lofted shapes and some extrusion edges (#29)

### Other

- Added GNU LGPL v2.1 license with OCCT LGPL exception

### Statistics
- 166 tests passing across 36 suites

---

## Demo App - OCCTSwiftDemo (2026-01-22, updated 2026-01-23)

A companion demo app has been created to showcase OCCTSwift capabilities:

- **Repository**: `~/Projects/OCCTSwiftDemo`
- **Status**: Phase 1 complete, iOS device testing in progress
- **Features**:
  - CadQuery-inspired JavaScript scripting via JavaScriptCore
  - ViewportKit 3D visualization with camera controls
  - Platform-adaptive UI (macOS HSplitView, iPad 3-column, iPhone TabView)
  - Example library with presets
  - Live model properties (volume, area, face/edge counts)
  - Safe operation handling (uses optional-returning methods to prevent crashes)

See [DEMO_APP_PROPOSAL.md](DEMO_APP_PROPOSAL.md) for details and roadmap.

---

## [v0.13.0] - 2026-01-22

### Added

#### Shape Analysis
Comprehensive diagnostics for identifying geometry problems.

- **`ShapeAnalysisResult`** struct - Analysis result with problem counts
  - `smallEdgeCount` - Edges smaller than tolerance
  - `smallFaceCount` - Faces smaller than tolerance
  - `gapCount` - Gaps between edges/faces
  - `selfIntersectionCount` - Self-intersections detected
  - `freeEdgeCount` - Unconnected edges
  - `freeFaceCount` - Free faces (unclosed shell)
  - `hasInvalidTopology` - Whether topology is invalid
  - `totalProblems` - Total count of all issues
  - `isHealthy` - Whether shape appears problem-free

- **`shape.analyze(tolerance:)`** - Analyze shape for problems

**Use Cases:**
- Diagnosing imported geometry
- Pre-flight checks before operations
- Quality assurance for CAD models

#### Shape Fixing
Repair geometry problems automatically.

- **`shape.fixed(tolerance:fixSolid:fixShell:fixFace:fixWire:)`** - Fix with control
- **`wire.fixed(tolerance:)`** - Fix wire problems (gaps, ordering)
- **`face.fixed(tolerance:)`** - Fix face problems (orientation, seams)

**Use Cases:**
- Repairing imported geometry
- Preparing models for boolean operations
- Cleaning up manually constructed shapes

#### Shape Unification
Simplify topology after boolean operations.

- **`shape.unified(unifyEdges:unifyFaces:concatBSplines:)`** - Merge same-domain geometry
- **`shape.withoutSmallFaces(minArea:)`** - Remove faces below area threshold
- **`shape.simplified(tolerance:)`** - Combine unification and healing

**Use Cases:**
- Cleaning up boolean results
- Reducing face/edge count
- Preparing models for meshing

**C Bridge Functions:**
```c
// Analysis result structure
typedef struct {
    int32_t smallEdgeCount;
    int32_t smallFaceCount;
    int32_t gapCount;
    int32_t selfIntersectionCount;
    int32_t freeEdgeCount;
    int32_t freeFaceCount;
    bool hasInvalidTopology;
    bool isValid;
} OCCTShapeAnalysisResult;

OCCTShapeAnalysisResult OCCTShapeAnalyze(OCCTShapeRef shape, double tolerance);

// Fixing
OCCTWireRef OCCTWireFix(OCCTWireRef wire, double tolerance);
OCCTShapeRef OCCTFaceFix(OCCTFaceRef face, double tolerance);
OCCTShapeRef OCCTShapeFixDetailed(OCCTShapeRef shape, double tolerance,
                                   bool fixSolid, bool fixShell,
                                   bool fixFace, bool fixWire);

// Unification
OCCTShapeRef OCCTShapeUnifySameDomain(OCCTShapeRef shape,
                                       bool unifyEdges, bool unifyFaces,
                                       bool concatBSplines);
OCCTShapeRef OCCTShapeRemoveSmallFaces(OCCTShapeRef shape, double minArea);
OCCTShapeRef OCCTShapeSimplify(OCCTShapeRef shape, double tolerance);
```

### Tests Added
- Shape analysis (valid box, small features, properties) (3 tests)
- Shape fixing (healthy shape, selective modes, heal compatibility) (3 tests)
- Shape unification (boolean result, edge-only, simplify) (3 tests)
- Wire fixing (rectangle, circle) (2 tests)
- Face fixing (face from wire) (1 test)

---

## [v0.12.0] - 2026-01-22

### Added

#### Feature-Based Modeling
Manufacturing-oriented operations for adding features to existing solids.

- **Prismatic Features**
  - `withPrism(profile:direction:height:fuse:)` - Add or cut prismatic features
  - `withBoss(profile:direction:height:)` - Add boss (protrusion) to shape
  - `withPocket(profile:direction:depth:)` - Create pocket (depression) in shape

- **Drilling Operations**
  - `drilled(at:direction:radius:depth:)` - Create cylindrical holes in any direction
    - Supports blind holes (specified depth)
    - Supports through holes (depth = 0)

**Use Cases:**
- Adding mounting bosses to enclosures
- Creating pockets for component mounting
- Drilling mounting holes at arbitrary angles
- Feature-based CAD modeling workflows

#### Shape Splitting
Divide shapes using planes or cutting tools.

- `split(atPlane:normal:)` - Split shape by infinite plane
- `split(by:)` - Split shape using another shape as cutting tool

Returns array of resulting solid pieces.

**Use Cases:**
- Dividing parts for manufacturing constraints
- Creating sectional views
- Analyzing internal geometry

#### Gluing Operations
Efficiently combine coincident shapes.

- `Shape.glue(_:_:tolerance:)` - Glue two shapes with shared faces

Unlike boolean union, gluing assumes shapes share coincident faces and runs faster.

#### Evolved Surfaces
Create surfaces by sweeping profiles along spines.

- `Shape.evolved(spine:profile:)` - Create evolved surface/shell

The profile is swept along the spine maintaining its orientation relative to the spine.

#### Pattern Operations
Create arrays of shapes in linear or circular patterns.

- `linearPattern(direction:spacing:count:)` - Create linear array of shapes
- `circularPattern(axisPoint:axisDirection:count:angle:)` - Create circular array
  - `angle = 0` distributes shapes evenly around 360°
  - Non-zero angle specifies total angular span

**Use Cases:**
- Bolt hole patterns
- Repeated features (fins, slots, teeth)
- Array of components on PCB

**C Bridge Functions:**
```c
// Prismatic Features
OCCTShapeRef OCCTShapePrism(OCCTShapeRef shape, OCCTWireRef profile,
                            double dirX, double dirY, double dirZ,
                            double height, bool fuse);

// Drilling
OCCTShapeRef OCCTShapeDrillHole(OCCTShapeRef shape,
                                 double posX, double posY, double posZ,
                                 double dirX, double dirY, double dirZ,
                                 double radius, double depth);

// Splitting
OCCTShapeRef* OCCTShapeSplit(OCCTShapeRef shape, OCCTShapeRef tool, int32_t* outCount);
OCCTShapeRef* OCCTShapeSplitByPlane(OCCTShapeRef shape,
                                     double planeX, double planeY, double planeZ,
                                     double normalX, double normalY, double normalZ,
                                     int32_t* outCount);
void OCCTFreeShapeArray(OCCTShapeRef* shapes, int32_t count);
void OCCTFreeShapeArrayOnly(OCCTShapeRef* shapes);

// Gluing
OCCTShapeRef OCCTShapeGlue(OCCTShapeRef shape1, OCCTShapeRef shape2, double tolerance);

// Evolved
OCCTShapeRef OCCTShapeCreateEvolved(OCCTWireRef spine, OCCTWireRef profile);

// Patterns
OCCTShapeRef OCCTShapeLinearPattern(OCCTShapeRef shape,
                                     double dirX, double dirY, double dirZ,
                                     double spacing, int32_t count);
OCCTShapeRef OCCTShapeCircularPattern(OCCTShapeRef shape,
                                       double axisX, double axisY, double axisZ,
                                       double axisDirX, double axisDirY, double axisDirZ,
                                       int32_t count, double angle);
```

### Tests Added
- Prismatic features (boss and pocket) (2 tests)
- Drilling (blind hole, through hole, multiple holes) (3 tests)
- Shape splitting (horizontal plane, diagonal plane, shape tool) (3 tests)
- Gluing (2 tests)
- Evolved surfaces (1 test)
- Pattern operations (linear, circular, partial circular) (3 tests)

---

## [v0.11.0] - 2026-01-22

### Added

#### Face Creation
Build faces from wires for custom geometry construction.

- **Face from Wire**
  - `Shape.face(from:planar:)` - Create planar face from closed wire
  - `Shape.face(outer:holes:)` - Create face with holes (outer wire + inner wires)

**Use Cases:**
- Building custom geometry from scratch
- Creating faces with cutouts (e.g., mounting plates with holes)
- Preparing profiles for extrusion

#### Solid from Shell
Convert shells into solids.

- `Shape.solid(from:)` - Create solid from closed shell (useful after sewing operations)

#### Sewing Operations
Connect disconnected faces into shells or solids.

- **Static Methods**
  - `Shape.sew(shapes:tolerance:)` - Sew multiple shapes into connected geometry
  - `Shape.sew(_:with:tolerance:)` - Sew two shapes together

- **Instance Methods**
  - `shape.sewn(with:tolerance:)` - Sew this shape with another

**Use Cases:**
- Repairing imported geometry with gaps
- Combining separately created faces
- Building watertight solids from face collections

#### Curve Interpolation
Create smooth curves that pass through specific points.

- `Wire.interpolate(through:closed:tolerance:)` - Interpolate curve through points
- `Wire.interpolate(through:startTangent:endTangent:tolerance:)` - With tangent constraints

Unlike B-splines where control points influence but don't lie on the curve,
interpolated curves pass exactly through all specified points.

**Use Cases:**
- Creating toolpaths through waypoints
- Generating smooth transitions between specific positions
- Fitting curves to measured/surveyed data

**C Bridge Functions:**
```c
// Face creation
OCCTShapeRef OCCTShapeCreateFaceFromWire(OCCTWireRef wire, bool planar);
OCCTShapeRef OCCTShapeCreateFaceWithHoles(OCCTWireRef outer, const OCCTWireRef* holes, int32_t holeCount);

// Solid from shell
OCCTShapeRef OCCTShapeCreateSolidFromShell(OCCTShapeRef shell);

// Sewing
OCCTShapeRef OCCTShapeSew(const OCCTShapeRef* shapes, int32_t count, double tolerance);
OCCTShapeRef OCCTShapeSewTwo(OCCTShapeRef shape1, OCCTShapeRef shape2, double tolerance);

// Interpolation
OCCTWireRef OCCTWireInterpolate(const double* points, int32_t count, bool closed, double tolerance);
OCCTWireRef OCCTWireInterpolateWithTangents(const double* points, int32_t count,
                                             double startTanX, double startTanY, double startTanZ,
                                             double endTanX, double endTanY, double endTanZ,
                                             double tolerance);
```

### Tests Added
- Face from wire (rectangular and circular) (2 tests)
- Face with holes (single and multiple) (2 tests)
- Face extrusion to solid (1 test)
- Sewing operations (3 tests)
- Solid from shell (2 tests)
- Curve interpolation (6 tests)

---

## [v0.10.0] - 2026-01-22

### Added

#### IGES Import/Export
Support for IGES (Initial Graphics Exchange Specification), a legacy CAD format commonly used in manufacturing and older CAD systems.

- **IGES Import**
  - `Shape.loadIGES(from:)` - Import IGES file from URL
  - `Shape.loadIGES(fromPath:)` - Import IGES file from path string
  - `Shape.loadIGESRobust(from:)` - Import with automatic shape healing (sewing, solid conversion)

- **IGES Export**
  - `Exporter.writeIGES(shape:to:)` - Export shape to IGES file
  - `Exporter.igesData(shape:)` - Export shape to IGES and return as Data

- **Shape convenience methods**
  - `shape.writeIGES(to:)` - Export this shape to IGES
  - `shape.igesData()` - Get IGES data for this shape

**Use Cases:**
- Legacy CAD system compatibility
- CNC machines with IGES-only post processors
- Exchanging data with older software

#### BREP Native Format
OCCT's native B-Rep format for exact geometry with full precision.

- **BREP Import**
  - `Shape.loadBREP(from:)` - Import BREP file from URL
  - `Shape.loadBREP(fromPath:)` - Import BREP file from path string

- **BREP Export**
  - `Exporter.writeBREP(shape:to:withTriangles:withNormals:)` - Export shape to BREP
    - `withTriangles` (default: true) - Include triangulation data for faster visualization
    - `withNormals` (default: false) - Include normals with triangulation
  - `Exporter.brepData(shape:withTriangles:withNormals:)` - Export to BREP as Data

- **Shape convenience methods**
  - `shape.writeBREP(to:withTriangles:withNormals:)` - Export this shape to BREP
  - `shape.brepData(withTriangles:withNormals:)` - Get BREP data for this shape

**Use Cases:**
- Fast caching of intermediate geometry results
- Debugging geometry issues
- Archiving exact geometry for later processing
- Full precision preservation (no format conversion losses)

**C Bridge Functions:**
```c
// IGES Import/Export
OCCTShapeRef OCCTImportIGES(const char* path);
OCCTShapeRef OCCTImportIGESRobust(const char* path);
bool OCCTExportIGES(OCCTShapeRef shape, const char* path);

// BREP Native Format
OCCTShapeRef OCCTImportBREP(const char* path);
bool OCCTExportBREP(OCCTShapeRef shape, const char* path);
bool OCCTExportBREPWithTriangles(OCCTShapeRef shape, const char* path, bool withTriangles, bool withNormals);
```

### Tests Added
- IGES export and roundtrip (3 tests)
- BREP export and roundtrip with triangulation options (5 tests)

---

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

