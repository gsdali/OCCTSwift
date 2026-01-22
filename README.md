# OCCTSwift

A Swift wrapper for [OpenCASCADE Technology (OCCT)](https://www.opencascade.com/) providing B-Rep solid modeling capabilities for iOS and macOS applications.

## Wrapped Operations Summary

| Category | Count | Examples |
|----------|-------|----------|
| **Primitives** | 7 | box, cylinder, cylinder(at:), sphere, cone, torus, surface |
| **Sweeps** | 6 | pipe sweep, pipeShell, extrude, revolve, loft, ruled |
| **Booleans** | 3 | union (+), subtract (-), intersect (&) |
| **Modifications** | 7 | fillet, selective fillet, chamfer, shell, offset, draft, defeature |
| **Transforms** | 4 | translate, rotate, scale, mirror |
| **Wires** | 13 | rectangle, circle, polygon, line, arc, bspline, nurbs, path, join, offset, offset3D, interpolate |
| **Curve Analysis** | 6 | length, curveInfo, point(at:), tangent(at:), curvature(at:), curvePoint(at:) |
| **Feature-Based** | 10 | boss, pocket, prism, drilled, split, glue, evolved, linearPattern, circularPattern |
| **Healing/Analysis** | 7 | analyze, fixed, unified, simplified, withoutSmallFaces, wire.fixed, face.fixed |
| **Measurement** | 7 | volume, surfaceArea, centerOfMass, properties, distance, minDistance, intersects |
| **Import/Export** | 10 | STEP, IGES, BREP import; STL, STEP, IGES, BREP export; mesh |
| **Geometry Construction** | 4 | face from wire, face with holes, solid from shell, sew |
| **Bounds/Topology** | 6 | bounds, size, center, vertices, edges, faces |
| **Slicing** | 4 | sliceAtZ, sectionWiresAtZ, edgePoints, contourPoints |
| **Validation** | 2 | isValid, heal |
| **XDE/Document** | 10 | Document.load, rootNodes, AssemblyNode, colors, materials |
| **2D Drawing** | 5 | project, topView, frontView, visibleEdges, hiddenEdges |
| **Total** | **111** | |

> **Note:** OCCTSwift wraps a curated subset of OCCT. To add new functions, see [docs/EXTENDING.md](docs/EXTENDING.md).

## Features

- **B-Rep Solid Modeling**: Full boundary representation geometry
- **Boolean Operations**: Union, subtraction, intersection
- **Sweep Operations**: Pipe sweeps, extrusions, revolutions, lofts
- **Modifications**: Fillet, chamfer, shell, offset, draft, defeaturing
- **Feature-Based Modeling**: Boss, pocket, drilling, splitting, gluing, evolved surfaces
- **Pattern Operations**: Linear and circular arrays of shapes
- **Shape Healing**: Analysis, fixing, unification, simplification
- **Geometry Construction**: Face from wire, face with holes, sewing, solid from shell
- **Curve Interpolation**: Create smooth curves through specific points
- **Import Formats**: STEP, IGES, BREP (OCCT native)
- **Export Formats**: STL (3D printing), STEP, IGES, BREP (CAD interchange)
- **XDE Support**: Assembly structure, part names, colors, PBR materials
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
    .package(url: "https://github.com/gsdali/OCCTSwift.git", from: "0.13.0")
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
│   ├── OCCTSwift/        # Swift API (public interface)
│   │   ├── Shape.swift   # 3D solid shapes
│   │   ├── Wire.swift    # 2D profiles and 3D paths
│   │   ├── Mesh.swift    # Triangulated mesh data
│   │   └── Exporter.swift# STL/STEP export
│   └── OCCTBridge/       # Objective-C++ bridge to OCCT
└── Libraries/
    └── OCCT.xcframework  # Pre-built OCCT libraries
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

#### Import
| Swift API | OCCT Class |
|-----------|------------|
| `Shape.load(from:)` | `STEPControl_Reader` |
| `Shape.loadRobust(from:)` | `STEPControl_Reader` + `ShapeFix_*` |
| `Shape.loadIGES(from:)` | `IGESControl_Reader` |
| `Shape.loadIGESRobust(from:)` | `IGESControl_Reader` + `ShapeFix_*` |
| `Shape.loadBREP(from:)` | `BRepTools::Read` |

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

#### Validation
| Swift API | OCCT Class |
|-----------|------------|
| `shape.isValid` | `BRepCheck_Analyzer` |
| `shape.healed()` | `ShapeFix_Shape` |

### What's NOT Wrapped (Yet)

OCCT has thousands of classes. Some notable ones not yet exposed:

- **Blend/Transition**: `BRepBlend_*` classes for complex variable-radius fillets
- **Pockets with Islands**: Multi-contour pocket features
- **Offset surfaces**: `BRepOffsetAPI_MakeOffsetSurface`
- **OBJ import/export**: Returns mesh data rather than B-Rep geometry

> **Note:** Many previously missing features have been added in recent versions:
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

## License

This wrapper is MIT licensed. OpenCASCADE Technology is licensed under LGPL-2.1.

## Acknowledgments

- [OpenCASCADE](https://www.opencascade.com/) for the geometry kernel
- Inspired by CAD Assistant's iOS implementation
