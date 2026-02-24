# OCCTSwift

A Swift wrapper for [OpenCASCADE Technology (OCCT)](https://www.opencascade.com/) providing B-Rep solid modeling capabilities for iOS and macOS applications.

## Wrapped Operations Summary

| Category | Count | Examples |
|----------|-------|----------|
| **Primitives** | 7 | box, cylinder, cylinder(at:), sphere, cone, torus, surface |
| **Sweeps** | 7 | pipe sweep, pipeShell, pipeShellWithLaw, extrude, revolve, loft, ruled |
| **Booleans** | 3 | union (+), subtract (-), intersect (&) |
| **Modifications** | 9 | fillet, selective fillet, variable fillet, multi-edge blend, chamfer, shell, offset, draft, defeature |
| **Transforms** | 4 | translate, rotate, scale, mirror |
| **Wires** | 17 | rectangle, circle, polygon, line, arc, bspline, nurbs, path, join, offset, offset3D, interpolate, fillet2D, filletAll2D, chamfer2D, chamferAll2D |
| **Curve Analysis** | 6 | length, curveInfo, point(at:), tangent(at:), curvature(at:), curvePoint(at:) |
| **2D Curves (Curve2D)** | 55 | line, segment, circle, arc, ellipse, parabola, hyperbola, bspline, bezier, interpolate, fit, trim, offset, reverse, translate, rotate, scale, mirror, curvature, normal, inflection, intersect, project, Gcc solver, hatch, bisector, draw |
| **3D Curves (Curve3D)** | 51 | line, segment, circle, arc, ellipse, parabola, hyperbola, bspline, bezier, interpolate, fit, trim, reverse, translate, rotate, scale, mirror, length, curvature, tangent, normal, torsion, toBSpline, toBezierSegments, join, approximate, drawAdaptive, drawUniform, drawDeflection, projectedOnPlane |
| **Surfaces (Surface)** | 47 | plane, cylinder, cone, sphere, torus, extrusion, revolution, bezier, bspline, trim, offset, translate, rotate, scale, mirror, toBSpline, approximate, uIso, vIso, pipe, drawGrid, drawMesh, curvatures, projectCurve, projectCurveSegments, projectCurve3D, projectPoint, plateThrough, nlPlateDeformed, nlPlateDeformedG1 |
| **Face Analysis** | 11 | uvBounds, point(atU:v:), normal, gaussianCurvature, meanCurvature, principalCurvatures, surfaceType, area, project, allProjections, intersection |
| **Edge Analysis** | 10 | parameterBounds, curveType, point(at:), curvature, tangent, normal, centerOfCurvature, torsion, project |
| **Feature-Based** | 10 | boss, pocket, prism, drilled, split, glue, evolved, linearPattern, circularPattern |
| **Healing/Analysis** | 16 | analyze, fixed, unified, simplified, withoutSmallFaces, wire.fixed, face.fixed, divided, directFaces, scaledGeometry, bsplineRestriction, sweptToElementary, revolutionToElementary, convertedToBSpline, sewn, upgraded |
| **Measurement** | 7 | volume, surfaceArea, centerOfMass, properties, distance, minDistance, intersects |
| **Point Classification** | 3 | classify(point:) on solid, classify(point:) on face, classify(u:v:) on face |
| **Shape Proximity** | 2 | proximityFaces, selfIntersects |
| **Law Functions** | 7 | constant, linear, sCurve, interpolate, bspline, value(at:), bounds |
| **Import/Export** | 16 | STL, STEP, IGES, BREP, OBJ import; STL, STEP, IGES, BREP, OBJ, PLY export; mesh |
| **Geometry Construction** | 9 | face from wire, face with holes, solid from shell, sew, fill, plateSurface, plateCurves, plateSurfaceAdvanced, plateSurfaceMixed |
| **Bounds/Topology** | 6 | bounds, size, center, vertices, edges, faces |
| **Slicing** | 4 | sliceAtZ, sectionWiresAtZ, edgePoints, contourPoints |
| **Validation** | 2 | isValid, heal |
| **XDE/Document** | 19 | Document.load, rootNodes, AssemblyNode, colors, materials, dimensions, geomTolerances, datums |
| **2D Drawing** | 5 | project, topView, frontView, visibleEdges, hiddenEdges |
| **Camera** | 14 | eye, center, up, projectionType, fieldOfView, scale, zRange, aspect, projectionMatrix, viewMatrix, project, unproject, fit |
| **Selection** | 11 | add, remove, clear, activateMode, deactivateMode, isModeActive, pixelTolerance, pick, pickRect, pickPoly |
| **Presentation Mesh** | 2 | shadedMesh, edgeMesh |
| **Medial Axis** | 12 | compute, arcCount, nodeCount, basicElementCount, node(at:), arc(at:), nodes, arcs, minThickness, distanceToBoundary, drawArc, drawAll |
| **Topological Naming** | 12 | createLabel, recordNaming, currentShape, storedShape, namingEvolution, namingHistory, oldShape, newShape, tracedForward, tracedBackward, selectShape, resolveShape |
| **Length Dimension** | 7 | fromPoints, fromEdge, fromFaces, value, isValid, geometry, setCustomValue |
| **Radius Dimension** | 4 | fromShape, value, geometry, setCustomValue |
| **Angle Dimension** | 7 | fromEdges, fromPoints, fromFaces, value, degrees, geometry, setCustomValue |
| **Diameter Dimension** | 4 | fromShape, value, geometry, setCustomValue |
| **Text Label** | 5 | create, text, position, setHeight, getInfo |
| **Point Cloud** | 6 | create, createColored, count, bounds, points, colors |
| **Total** | **429** | |

> **Note:** OCCTSwift wraps a curated subset of OCCT. To add new functions, see [docs/EXTENDING.md](docs/EXTENDING.md).

## Features

- **B-Rep Solid Modeling**: Full boundary representation geometry
- **Boolean Operations**: Union, subtraction, intersection
- **Sweep Operations**: Pipe sweeps, extrusions, revolutions, lofts, variable-section sweeps with law functions
- **Modifications**: Fillet (uniform, selective, variable radius), chamfer, shell, offset, draft, defeaturing
- **Advanced Blends**: Variable radius fillets, multi-edge blends with individual radii
- **2D Wire Operations**: 2D fillet and chamfer on planar wires
- **2D Parametric Curves**: Full Geom2d wrapping — lines, conics, BSplines, Beziers, interpolation, operations, analysis, Gcc constraint solver, hatching, bisectors, Metal draw methods
- **3D Parametric Curves**: Full Geom wrapping — lines, circles, arcs, ellipses, BSplines, Beziers, interpolation, operations, conversion, local properties, Metal draw methods
- **Parametric Surfaces**: Analytic (plane, cylinder, cone, sphere, torus), swept (extrusion, revolution), freeform (Bezier, BSpline), pipe surfaces, operations, curvature analysis, Metal draw methods
- **3D Geometry Analysis**: Face surface properties, edge curve properties, point projection, shape proximity detection, surface intersection
- **Curve Projection**: Project 3D curves onto surfaces (2D UV result, composite segments, 3D-on-surface), project curves onto planes
- **Law Functions**: Constant, linear, S-curve, interpolated, BSpline evolution functions for variable-section sweeps
- **Feature-Based Modeling**: Boss, pocket, drilling, splitting, gluing, evolved surfaces
- **Pattern Operations**: Linear and circular arrays of shapes
- **Shape Healing**: Analysis, fixing, unification, simplification
- **Geometry Construction**: Face from wire, face with holes, sewing, solid from shell, surface filling
- **Surface Creation**: N-sided boundary filling, plate surfaces through points or curves, advanced plates with per-point constraint orders, mixed point/curve constraints
- **NLPlate Surface Deformation**: Non-linear plate solver for G0 (positional) and G0+G1 (positional + tangent) surface deformation
- **Medial Axis Transform**: Voronoi skeleton of planar faces — arc/node graph traversal, bisector curve drawing, inscribed circle radius, minimum wall thickness
- **Topological Naming**: TNaming history tracking — record primitive/generated/modify/delete evolutions, forward/backward tracing through naming graph, persistent named selections with resolve
- **Annotations & Measurements**: Length/radius/angle/diameter dimensions with geometry extraction for Metal rendering, 3D text labels, colored point clouds
- **Camera**: Graphic3d_Camera wrapping with Metal-compatible [0,1] NDC, projection/view matrices as simd_float4x4, project/unproject, fit to bounding box
- **Selection**: BVH-accelerated hit testing — point pick, rectangle pick, polygon (lasso) pick, sub-shape selection modes (vertex, edge, face)
- **Presentation Mesh**: GPU-ready triangulated mesh and edge wireframe extraction from shapes
- **Curve Interpolation**: Create smooth curves through specific points
- **Import Formats**: STL, STEP, IGES, BREP, OBJ (mesh and CAD)
- **Export Formats**: STL, STEP, IGES, BREP, OBJ, PLY (3D printing, CAD, visualization)
- **Point Classification**: Classify points as inside/outside/on boundary of solids and faces
- **Advanced Shape Healing**: Surface division, BSpline restriction, geometry scaling, surface type conversion, sewing, upgrade pipeline
- **XDE Support**: Assembly structure, part names, colors, PBR materials, GD&T (dimensions, tolerances, datums)
- **2D Drawing**: Hidden line removal, technical drawing projection
- **SceneKit Integration**: Generate meshes for visualization

## Requirements

- Swift 6.1+
- iOS 15.0+ / macOS 12.0+
- Xcode 16.0+

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/gsdali/OCCTSwift.git", from: "0.27.0")
]
```

Or in Xcode: File → Add Package Dependencies → Enter repository URL.

## Usage

### Basic Shapes

```swift
import OCCTSwift

// Create primitives
let box = Shape.box(width: 10, height: 5, depth: 3)
let cylinder = Shape.cylinder(radius: 2, height: 10)
let sphere = Shape.sphere(radius: 5)

// Boolean operations
let result = box - cylinder  // Subtract cylinder from box
let combined = box + sphere  // Union
```

### Sweep Operations

```swift
// Create a rail profile and sweep along a path
let railProfile = Wire.polygon([
    SIMD2(0, 0),
    SIMD2(2.5, 0),
    SIMD2(2.5, 1),
    SIMD2(1.5, 1),
    SIMD2(1.5, 8),
    SIMD2(0, 8)
], closed: true)

let trackPath = Wire.arc(
    center: SIMD3(0, 0, 0),
    radius: 450,
    startAngle: 0,
    endAngle: .pi / 4
)

let rail = Shape.sweep(profile: railProfile, along: trackPath)
```

### Export

```swift
// Export for 3D printing
try Exporter.writeSTL(shape: rail, to: stlURL, deflection: 0.05)

// Export for CAD software
try Exporter.writeSTEP(shape: rail, to: stepURL)
```

### SceneKit Integration

```swift
import SceneKit

let mesh = shape.mesh(linearDeflection: 0.1)
let geometry = mesh.sceneKitGeometry()
let node = SCNNode(geometry: geometry)
```

### XDE Document Support (v0.6.0)

Load STEP files with assembly structure, part names, colors, and PBR materials:

```swift
// Load STEP file with full metadata
let doc = try Document.load(from: stepURL)

// Traverse assembly tree
for node in doc.rootNodes {
    print("Part: \(node.name ?? "unnamed")")
    if let color = node.color {
        print("  Color: RGB(\(color.red), \(color.green), \(color.blue))")
    }
    if let shape = node.shape {
        let mesh = shape.mesh(linearDeflection: 0.1)
        // render...
    }
}

// Or get flat list with colors
for (shape, color) in doc.shapesWithColors() {
    let geometry = shape.mesh().sceneKitGeometry()
    // apply color...
}

// Use PBR materials for RealityKit
for (shape, material) in doc.shapesWithMaterials() {
    if let mat = material {
        print("Metallic: \(mat.metallic), Roughness: \(mat.roughness)")
    }
}
```

### 2D Parametric Curves (v0.16.0)

Create, evaluate, manipulate, and discretize 2D curves for Metal rendering:

```swift
// Create curves
let circle = Curve2D.circle(center: .zero, radius: 10)!
let segment = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 5))!
let arc = Curve2D.arcOfCircle(center: .zero, radius: 5,
                               startAngle: 0, endAngle: .pi / 2)!

// BSpline interpolation through points
let spline = Curve2D.interpolate(through: [
    SIMD2(0, 0), SIMD2(3, 5), SIMD2(7, 2), SIMD2(10, 8)
])!

// Evaluate
let pt = circle.point(at: 0)           // SIMD2<Double>
let (p, tangent) = circle.d1(at: 0)    // point + tangent vector
let k = circle.curvature(at: 0)        // 1/radius

// Operations (all return new curves)
let trimmed = circle.trimmed(from: 0, to: .pi)!
let offset = segment.offset(by: 2.0)!
let rotated = segment.rotated(around: .zero, angle: .pi / 4)!

// Discretize for Metal rendering
let polyline = circle.drawAdaptive()    // [SIMD2<Double>]
let uniform = spline.drawUniform(pointCount: 100)

// Analysis
let hits = circle.intersections(with: segment)
let proj = circle.project(point: SIMD2(15, 0))

// Gcc constraint solver — circle tangent to curve through center
let solutions = Curve2DGcc.circlesTangentWithCenter(
    circle, .unqualified, center: SIMD2(20, 0)
)

// Hatching
let hatchLines = Curve2DGcc.hatch(
    boundaries: [seg1, seg2, seg3, seg4],
    origin: .zero, direction: SIMD2(1, 0), spacing: 2.0
)
```

### 3D Parametric Curves (v0.19.0)

Create, evaluate, and discretize 3D curves for Metal rendering:

```swift
// Create curves
let segment = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 5, 3))!
let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 10)!
let arc = Curve3D.arcOfCircle(start: SIMD3(1, 0, 0),
                               interior: SIMD3(0, 1, 0),
                               end: SIMD3(-1, 0, 0))!

// BSpline interpolation through 3D points
let spline = Curve3D.interpolate(points: [
    SIMD3(0, 0, 0), SIMD3(3, 5, 1), SIMD3(7, 2, 4), SIMD3(10, 8, 2)
])!

// Evaluate
let pt = circle.point(at: 0)                    // SIMD3<Double>
let (p, tangent) = circle.d1(at: 0)             // point + tangent vector
let k = circle.curvature(at: 0)                 // 1/radius

// Operations (all return new curves)
let trimmed = circle.trimmed(from: 0, to: .pi)!
let translated = segment.translated(by: SIMD3(1, 2, 3))!

// Discretize for Metal rendering
let polyline = circle.drawAdaptive()             // [SIMD3<Double>]
let uniform = spline.drawUniform(pointCount: 100)
```

### Parametric Surfaces (v0.20.0)

Create and evaluate parametric surfaces:

```swift
// Analytic surfaces
let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))!
let sphere = Surface.sphere(center: .zero, radius: 5)!
let cyl = Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: 3)!

// BSpline surface
let bspline = Surface.bspline(poles: controlPointGrid, ...)

// Evaluate
let pt = sphere.point(atU: 0.5, v: 0.5)         // SIMD3<Double>
let n = sphere.normal(atU: 0.5, v: 0.5)         // surface normal
let K = sphere.gaussianCurvature(atU: 0.5, v: 0.5)  // 1/r^2

// Iso curves
let meridian = sphere.uIso(at: 0)               // Curve3D

// Draw for Metal rendering
let gridLines = sphere.drawGrid(uLineCount: 10, vLineCount: 10)
let meshGrid = sphere.drawMesh(uCount: 20, vCount: 20)
```

### 3D Geometry Analysis (v0.18.0)

Analyze face surfaces, edge curves, and detect proximity:

```swift
let box = Shape.box(width: 10, height: 10, depth: 10)!

// Face surface properties
let face = box.faces()[0]
let normal = face.normal(atU: 0.5, v: 0.5)      // surface normal
let K = face.gaussianCurvature(atU: 0.5, v: 0.5)
let area = face.area()

// Edge curve properties
let edge = box.edges()[0]
let tangent = edge.tangent(at: 0.5)              // tangent direction
let curvature = edge.curvature(at: 0.5)

// Point projection
let proj = face.project(point: SIMD3(15, 5, 5))  // closest point on face
let edgeProj = edge.project(point: SIMD3(5, 5, 5))

// Shape proximity
let nearby = box.proximityFaces(with: otherShape, tolerance: 0.1)
let selfCheck = box.selfIntersects
```

### 2D Technical Drawings (v0.6.0)

Create 2D projections with hidden line removal:

```swift
// Create orthographic top view
let topView = Drawing.project(shape, direction: SIMD3(0, 0, 1))

// Get visible and hidden edges
let visibleEdges = topView?.visibleEdges
let hiddenEdges = topView?.hiddenEdges

// Standard views
let front = Drawing.frontView(of: shape)
let side = Drawing.sideView(of: shape)
let iso = Drawing.isometricView(of: shape)
```

#### Exporting to DXF

OCCTSwift provides the 2D projected edges but does not include DXF export. To export to DXF:

1. Get edges from the `Drawing` as `Shape` objects
2. Extract edge points using `shape.allEdgePolylines(deflection:)`
3. Write to DXF using a third-party library like:
   - [EZDXF](https://github.com/mozman/ezdxf) (Python, can be called via PythonKit)
   - [dxf-rs](https://github.com/IxMilia/dxf-rs) (Rust, can be wrapped)
   - FreeCAD's [dxf.cpp](https://github.com/FreeCAD/FreeCAD/tree/main/src/Mod/Import/App/dxf) (BSD-3-Clause, can be adapted)

## Architecture

```
OCCTSwift/
├── Sources/
│   ├── OCCTSwift/           # Swift API (public interface)
│   │   ├── Shape.swift      # 3D solid shapes + boolean + modifications
│   │   ├── Wire.swift       # 2D profiles and 3D paths
│   │   ├── Face.swift       # Face surface analysis + projection
│   │   ├── Edge.swift       # Edge curve analysis + projection
│   │   ├── Curve2D.swift    # 2D parametric curves (Geom2d)
│   │   ├── Curve3D.swift    # 3D parametric curves (Geom)
│   │   ├── Surface.swift    # Parametric surfaces (Geom)
│   │   ├── LawFunction.swift# Evolution functions for sweeps
│   │   ├── Document.swift   # XDE assembly + GD&T + TNaming
│   │   ├── MedialAxis.swift # Medial axis / Voronoi skeleton
│   │   ├── Annotation.swift # Dimensions, text labels, point clouds
│   │   ├── Mesh.swift       # Triangulated mesh data
│   │   └── Exporter.swift   # Multi-format export
│   └── OCCTBridge/          # Objective-C++ bridge to OCCT
└── Libraries/
    └── OCCT.xcframework     # Pre-built OCCT libraries
```

## API Reference

### Currently Wrapped OCCT Functions

OCCTSwift wraps a **subset** of OCCT's functionality. The bridge layer (`OCCTBridge`) exposes these specific operations:

#### Shape Creation (Primitives)
| Swift API | OCCT Class |
|-----------|------------|
| `Shape.box()` | `BRepPrimAPI_MakeBox` |
| `Shape.cylinder()` | `BRepPrimAPI_MakeCylinder` |
| `Shape.sphere()` | `BRepPrimAPI_MakeSphere` |
| `Shape.cone()` | `BRepPrimAPI_MakeCone` |
| `Shape.torus()` | `BRepPrimAPI_MakeTorus` |

#### Sweep Operations
| Swift API | OCCT Class |
|-----------|------------|
| `Shape.sweep(profile:along:)` | `BRepOffsetAPI_MakePipe` |
| `Shape.extrude(profile:direction:length:)` | `BRepPrimAPI_MakePrism` |
| `Shape.revolve(profile:axisOrigin:axisDirection:angle:)` | `BRepPrimAPI_MakeRevol` |
| `Shape.loft(profiles:solid:)` | `BRepOffsetAPI_ThruSections` |

#### Boolean Operations
| Swift API | OCCT Class |
|-----------|------------|
| `shape1 + shape2` / `shape1.union(with:)` | `BRepAlgoAPI_Fuse` |
| `shape1 - shape2` / `shape1.subtracting(_:)` | `BRepAlgoAPI_Cut` |
| `shape1 & shape2` / `shape1.intersection(with:)` | `BRepAlgoAPI_Common` |

#### Modifications
| Swift API | OCCT Class |
|-----------|------------|
| `shape.filleted(radius:)` | `BRepFilletAPI_MakeFillet` |
| `shape.chamfered(distance:)` | `BRepFilletAPI_MakeChamfer` |
| `shape.shelled(thickness:)` | `BRepOffsetAPI_MakeThickSolid` |
| `shape.offset(by:)` | `BRepOffsetAPI_MakeOffsetShape` |

#### Transformations
| Swift API | OCCT Class |
|-----------|------------|
| `shape.translated(by:)` | `BRepBuilderAPI_Transform` + `gp_Trsf` |
| `shape.rotated(axis:angle:)` | `BRepBuilderAPI_Transform` + `gp_Trsf` |
| `shape.scaled(by:)` | `BRepBuilderAPI_Transform` + `gp_Trsf` |
| `shape.mirrored(planeNormal:planeOrigin:)` | `BRepBuilderAPI_Transform` + `gp_Trsf` |

#### Wire/Curve Creation
| Swift API | OCCT Class |
|-----------|------------|
| `Wire.rectangle()` | `BRepBuilderAPI_MakeWire` + `GC_MakeSegment` |
| `Wire.circle()` | `BRepBuilderAPI_MakeEdge` + `gp_Circ` |
| `Wire.polygon(_:closed:)` | `BRepBuilderAPI_MakeWire` + edges |
| `Wire.line(from:to:)` | `BRepBuilderAPI_MakeEdge` + `GC_MakeSegment` |
| `Wire.arc(center:radius:...)` | `BRepBuilderAPI_MakeEdge` + `GC_MakeArcOfCircle` |
| `Wire.bspline(_:)` | `BRepBuilderAPI_MakeEdge` + `Geom_BSplineCurve` |
| `Wire.join(_:)` | `BRepBuilderAPI_MakeWire` |

#### 2D Parametric Curves
| Swift API | OCCT Class |
|-----------|------------|
| `Curve2D.segment(from:to:)` | `GCE2d_MakeSegment` |
| `Curve2D.circle(center:radius:)` | `Geom2d_Circle` |
| `Curve2D.ellipse(...)` | `GCE2d_MakeEllipse` |
| `Curve2D.bspline(...)` | `Geom2d_BSplineCurve` |
| `Curve2D.interpolate(through:)` | `Geom2dAPI_Interpolate` |
| `curve.curvature(at:)` | `Geom2dLProp_CLProps2d` |
| `curve.intersections(with:)` | `Geom2dAPI_InterCurveCurve` |
| `curve.drawAdaptive()` | `GCPnts_TangentialDeflection` |
| `Curve2DGcc.circlesTangentWithCenter(...)` | `Geom2dGcc_Circ2dTanCen` |
| `Curve2DGcc.hatch(boundaries:...)` | `Geom2dHatch_Hatcher` |

#### 3D Parametric Curves (v0.19.0)
| Swift API | OCCT Class |
|-----------|------------|
| `Curve3D.line(through:direction:)` | `Geom_Line` |
| `Curve3D.segment(from:to:)` | `GC_MakeSegment` |
| `Curve3D.circle(center:normal:radius:)` | `Geom_Circle` |
| `Curve3D.arcOfCircle(start:interior:end:)` | `GC_MakeArcOfCircle` |
| `Curve3D.ellipse(...)` | `Geom_Ellipse` |
| `Curve3D.bspline(...)` | `Geom_BSplineCurve` |
| `Curve3D.interpolate(points:...)` | `GeomAPI_Interpolate` |
| `curve.drawAdaptive()` | `GCPnts_TangentialDeflection` |
| `curve.curvature(at:)` | `GeomLProp_CLProps` |
| `Curve3D.join(_:)` | `GeomConvert::ConcatG1` |

#### Parametric Surfaces (v0.20.0)
| Swift API | OCCT Class |
|-----------|------------|
| `Surface.plane(origin:normal:)` | `Geom_Plane` |
| `Surface.cylinder(origin:axis:radius:)` | `Geom_CylindricalSurface` |
| `Surface.sphere(center:radius:)` | `Geom_SphericalSurface` |
| `Surface.bspline(...)` | `Geom_BSplineSurface` |
| `Surface.extrusion(profile:direction:)` | `Geom_SurfaceOfLinearExtrusion` |
| `Surface.revolution(...)` | `Geom_SurfaceOfRevolution` |
| `Surface.pipe(path:radius:)` | `GeomFill_Pipe` |
| `surface.uIso(at:)` / `surface.vIso(at:)` | `Geom_Surface::UIso/VIso` |
| `surface.drawGrid(...)` / `surface.drawMesh(...)` | Grid/mesh discretization |
| `surface.gaussianCurvature(atU:v:)` | `GeomLProp_SLProps` |

#### Face Surface Analysis (v0.18.0)
| Swift API | OCCT Class |
|-----------|------------|
| `face.uvBounds` | `BRepTools::UVBounds` |
| `face.point(atU:v:)` / `face.normal(atU:v:)` | `GeomLProp_SLProps` |
| `face.gaussianCurvature(atU:v:)` / `face.meanCurvature(atU:v:)` | `GeomLProp_SLProps` |
| `face.principalCurvatures(atU:v:)` | `GeomLProp_SLProps` |
| `face.surfaceType` / `face.area(tolerance:)` | `GeomAdaptor_Surface` / `BRepGProp` |
| `face.project(point:)` / `face.allProjections(of:)` | `GeomAPI_ProjectPointOnSurf` |
| `face.intersection(with:tolerance:)` | `BRepAlgoAPI_Section` |

#### Edge Curve Analysis (v0.18.0)
| Swift API | OCCT Class |
|-----------|------------|
| `edge.parameterBounds` / `edge.curveType` | `BRep_Tool` / `GeomAdaptor_Curve` |
| `edge.point(at:)` / `edge.tangent(at:)` / `edge.normal(at:)` | `GeomLProp_CLProps` |
| `edge.curvature(at:)` / `edge.centerOfCurvature(at:)` / `edge.torsion(at:)` | `GeomLProp_CLProps` |
| `edge.project(point:)` | `GeomAPI_ProjectPointOnCurve` |

#### Shape Proximity (v0.18.0)
| Swift API | OCCT Class |
|-----------|------------|
| `shape.proximityFaces(with:tolerance:)` | `BRepExtrema_ShapeProximity` |
| `shape.selfIntersects` | `BOPAlgo_CheckerSI` |

#### Law Functions (v0.21.0)
| Swift API | OCCT Class |
|-----------|------------|
| `LawFunction.constant(_:from:to:)` | `Law_Constant` |
| `LawFunction.linear(from:to:parameterRange:)` | `Law_Linear` |
| `LawFunction.sCurve(from:to:parameterRange:)` | `Law_S` |
| `LawFunction.interpolate(points:periodic:)` | `Law_Interpol` |
| `LawFunction.bspline(...)` | `Law_BSpline` |
| `Shape.pipeShellWithLaw(spine:profile:law:solid:)` | `BRepOffsetAPI_MakePipeShell` |

#### Curve Projection (v0.22.0)
| Swift API | OCCT Class |
|-----------|------------|
| `surface.projectCurve(_:tolerance:)` → `Curve2D?` | `GeomProjLib::Curve2d` |
| `surface.projectCurveSegments(_:tolerance:)` → `[Curve2D]` | `ProjLib_CompProjectedCurve` |
| `surface.projectCurve3D(_:)` → `Curve3D?` | `GeomProjLib::Project` |
| `surface.projectPoint(_:)` → `SurfaceProjection?` | `GeomAPI_ProjectPointOnSurf` |
| `curve.projectedOnPlane(origin:normal:direction:)` → `Curve3D?` | `GeomProjLib::ProjectOnPlane` |

#### XDE GD&T (v0.21.0)
| Swift API | OCCT Class |
|-----------|------------|
| `document.dimensionCount` / `document.dimension(at:)` | `XCAFDimTolObjects_DimensionObject` |
| `document.geomToleranceCount` / `document.geomTolerance(at:)` | `XCAFDimTolObjects_GeomToleranceObject` |
| `document.datumCount` / `document.datum(at:)` | `XCAFDimTolObjects_DatumObject` |

#### Topological Naming (v0.25.0)
| Swift API | OCCT Class |
|-----------|------------|
| `document.createLabel(parent:)` | `TDF_TagSource::NewTag` |
| `document.recordNaming(on:evolution:oldShape:newShape:)` | `TNaming_Builder` |
| `document.currentShape(on:)` | `TNaming_Tool::CurrentShape` |
| `document.storedShape(on:)` | `TNaming_Tool::GetShape` |
| `document.namingEvolution(on:)` | `TNaming_NamedShape::Evolution` |
| `document.namingHistory(on:)` | `TNaming_Iterator` |
| `document.tracedForward(from:scope:)` | `TNaming_NewShapeIterator` |
| `document.tracedBackward(from:scope:)` | `TNaming_OldShapeIterator` |
| `document.selectShape(_:context:on:)` | `TNaming_Selector::Select` |
| `document.resolveShape(on:)` | `TNaming_Selector::Solve` |

#### Annotations & Measurements (v0.26.0)
| Swift API | OCCT Class |
|-----------|------------|
| `LengthDimension(from:to:)` | `PrsDim_LengthDimension` |
| `LengthDimension(edge:)` | `PrsDim_LengthDimension` |
| `LengthDimension(face1:face2:)` | `PrsDim_LengthDimension` |
| `RadiusDimension(shape:)` | `PrsDim_RadiusDimension` |
| `AngleDimension(edge1:edge2:)` | `PrsDim_AngleDimension` |
| `AngleDimension(first:vertex:second:)` | `PrsDim_AngleDimension` |
| `AngleDimension(face1:face2:)` | `PrsDim_AngleDimension` |
| `DiameterDimension(shape:)` | `PrsDim_DiameterDimension` |
| `TextLabel(text:position:)` | `AIS_TextLabel` |
| `PointCloud(points:)` / `PointCloud(points:colors:)` | `AIS_PointCloud` |
| `dimension.geometry` → `DimensionGeometry` | Extracted line segments + text position for Metal |

#### Import
| Swift API | OCCT Class |
|-----------|------------|
| `Shape.load(from:)` | `STEPControl_Reader` |
| `Shape.loadRobust(from:)` | `STEPControl_Reader` + `ShapeFix_*` |
| `Shape.loadIGES(from:)` | `IGESControl_Reader` |
| `Shape.loadIGESRobust(from:)` | `IGESControl_Reader` + `ShapeFix_*` |
| `Shape.loadBREP(from:)` | `BRepTools::Read` |
| `Shape.loadSTL(from:)` | `StlAPI_Reader` |
| `Shape.loadSTLRobust(from:)` | `StlAPI_Reader` + `BRepBuilderAPI_Sewing` + `ShapeFix_Shape` |
| `Shape.loadOBJ(from:)` | `RWObj_CafReader` |

#### Geometry Construction
| Swift API | OCCT Class |
|-----------|------------|
| `Shape.face(from:)` | `BRepBuilderAPI_MakeFace` |
| `Shape.face(outer:holes:)` | `BRepBuilderAPI_MakeFace` |
| `Shape.solid(from:)` | `BRepBuilderAPI_MakeSolid` |
| `Shape.sew(shapes:tolerance:)` | `BRepBuilderAPI_Sewing` |
| `Wire.interpolate(through:)` | `GeomAPI_Interpolate` |

#### Bounds
| Swift API | OCCT Class |
|-----------|------------|
| `shape.bounds` | `Bnd_Box`, `BRepBndLib` |
| `shape.size` | (computed from bounds) |
| `shape.center` | (computed from bounds) |

#### Slicing & Contours
| Swift API | OCCT Class |
|-----------|------------|
| `shape.sliceAtZ(_:)` | `BRepAlgoAPI_Section`, `gp_Pln` |
| `shape.edgeCount` | `TopExp_Explorer` |
| `shape.edgePoints(at:maxPoints:)` | `BRep_Tool::Curve`, `Geom_Curve` |
| `shape.contourPoints(maxPoints:)` | `TopExp::Vertices`, `BRep_Tool::Pnt` |

#### CAM Operations
| Swift API | OCCT Class |
|-----------|------------|
| `Shape.cylinder(at:bottomZ:radius:height:)` | `BRepPrimAPI_MakeCylinder`, `gp_Ax2` |
| `Shape.toolSweep(radius:height:from:to:)` | `BRepPrimAPI_MakeCylinder`, `BRepAlgoAPI_Fuse`, `BRepPrimAPI_MakePrism` |

#### Meshing & Export
| Swift API | OCCT Class |
|-----------|------------|
| `shape.mesh(linearDeflection:angularDeflection:)` | `BRepMesh_IncrementalMesh` |
| `shape.writeSTL(to:deflection:)` | `StlAPI_Writer` |
| `shape.writeSTEP(to:)` | `STEPControl_Writer` |
| `shape.writeIGES(to:)` | `IGESControl_Writer` |
| `shape.writeBREP(to:)` | `BRepTools::Write` |
| `shape.writeOBJ(to:deflection:)` | `RWObj_CafWriter` |
| `shape.writePLY(to:deflection:)` | `RWPly_CafWriter` |

#### Validation
| Swift API | OCCT Class |
|-----------|------------|
| `shape.isValid` | `BRepCheck_Analyzer` |
| `shape.healed()` | `ShapeFix_Shape` |

### What's NOT Wrapped (Yet)

OCCT has thousands of classes. Some notable ones not yet exposed:

- **Pockets with Islands**: Multi-contour pocket features

> **Note:** Many previously missing features have been added in recent versions:
> - v0.27.0: **OCCT 8.0.0-rc4 upgrade** — 111 internal improvements, performance gains, deprecation fixes
> - v0.26.0: Annotations & measurements — length/radius/angle/diameter dimensions, text labels, point clouds
> - v0.25.0: Topological naming — record/trace naming history, persistent named selections
> - v0.24.0: Medial axis transform — Voronoi skeleton, arc/node graph, bisector curves, wall thickness
> - v0.23.0: NLPlate — advanced plate surfaces, non-linear G0/G1 surface deformation
> - v0.22.0: Curve projection onto surfaces — 2D UV projection, composite segments, 3D-on-surface, plane projection
> - v0.21.0: Law functions, variable-section sweeps, XDE GD&T (dimensions, tolerances, datums)
> - v0.20.0: Full parametric surface wrapping — analytic, swept, freeform, pipe, draw methods, curvature
> - v0.19.0: Full 3D parametric curve wrapping — primitives, BSplines, operations, conversion, draw methods
> - v0.18.0: 3D geometry analysis — face surface properties, edge curve queries, point projection, proximity
> - v0.17.0: STL/OBJ import, OBJ/PLY export, advanced shape healing, point classification
> - v0.16.0: Full Geom2d wrapping — 2D parametric curves with evaluation, operations, analysis, Gcc solver, hatching, bisectors
> - v0.14.0: Variable radius fillets, multi-edge blends, 2D fillet/chamfer, surface filling, plate surfaces
> - v0.13.0: Shape analysis, fixing, unification, simplification
> - v0.12.0: Boss, pocket, drilling, shape splitting, gluing, evolved surfaces, pattern operations
> - v0.11.0: Face from wire, sewing operations, solid from shell, curve interpolation
> - v0.10.0: IGES import/export, BREP native format
> - v0.9.0: B-spline surfaces, ruled surfaces, curve analysis
> - v0.8.0: Draft angles, selective fillet, defeaturing, pipe shell modes
> - v0.7.0: Volume, surface area, distance measurement, center of mass

### Adding New OCCT Functions

To wrap additional OCCT functionality, you need to modify three files:

1. **`Sources/OCCTBridge/include/OCCTBridge.h`** - Add C function declaration
2. **`Sources/OCCTBridge/src/OCCTBridge.mm`** - Implement using OCCT C++ API
3. **`Sources/OCCTSwift/Shape.swift`** (or Wire.swift) - Add Swift wrapper

**See [docs/EXTENDING.md](docs/EXTENDING.md) for the complete guide** with:
- Step-by-step walkthrough with example
- Common OCCT patterns (primitives, booleans, topology iteration)
- Memory management details
- Internal struct documentation
- Debugging tips

## Building OCCT

See `Scripts/build-occt.sh` for instructions on building OCCT for iOS/macOS.

## Roadmap

### Current Status: v0.27.0

OCCTSwift now wraps **429 OCCT operations** across 36 categories with 574 tests across 106 suites.

Built on **OCCT 8.0.0-rc4**.

### Coming Soon: Demo App ([#25](https://github.com/gsdali/OCCTSwift/issues/25))

An interactive playground app with CadQuery-inspired scripting:

```javascript
// Text-based modeling input
result = Workplane("XY")
    .box(10, 20, 5)
    .faces(">Z")
    .hole(3)
    .fillet(1)
```

**Features:**
- JavaScriptCore interpreter (built into iOS/macOS)
- ViewportKit 3D visualization
- CadQuery-compatible syntax
- Example library

See [docs/DEMO_APP_PROPOSAL.md](docs/DEMO_APP_PROPOSAL.md) for details.

### Open Issues

| Issue | Description |
|-------|-------------|
| [#2](https://github.com/gsdali/OCCTSwift/issues/2) | CAM: Wire offsetting |
| [#3](https://github.com/gsdali/OCCTSwift/issues/3) | CAM: Coordinate systems |
| [#4](https://github.com/gsdali/OCCTSwift/issues/4) | CAM: Swept tool solids |
| [#25](https://github.com/gsdali/OCCTSwift/issues/25) | Demo App: Playground with scripting |

## License

This wrapper is LGPL-2.1 licensed. OpenCASCADE Technology is licensed under LGPL-2.1.

## Acknowledgments

- [OpenCASCADE](https://www.opencascade.com/) for the geometry kernel
- Inspired by CAD Assistant's iOS implementation
