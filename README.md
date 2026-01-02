# OCCTSwift

A Swift wrapper for [OpenCASCADE Technology (OCCT)](https://www.opencascade.com/) providing B-Rep solid modeling capabilities for iOS and macOS applications.

## Wrapped Operations Summary

| Category | Count | Examples |
|----------|-------|----------|
| **Primitives** | 7 | box, cylinder, cylinder(at:), sphere, cone, torus |
| **Sweeps** | 5 | pipe sweep, extrude, revolve, loft, toolSweep |
| **Booleans** | 3 | union (+), subtract (-), intersect (&) |
| **Modifications** | 4 | fillet, chamfer, shell, offset |
| **Transforms** | 4 | translate, rotate, scale, mirror |
| **Wires** | 8 | rectangle, circle, polygon, line, arc, bspline, path, join |
| **Import/Export** | 4 | load (STEP), STL, STEP, mesh |
| **Bounds** | 3 | bounds, size, center |
| **Slicing** | 4 | sliceAtZ, edgeCount, edgePoints, contourPoints |
| **Validation** | 2 | isValid, heal |
| **Total** | **44** | |

> **Note:** OCCTSwift wraps a curated subset of OCCT. To add new functions, see [docs/EXTENDING.md](docs/EXTENDING.md).

## Features

- **B-Rep Solid Modeling**: Full boundary representation geometry
- **Boolean Operations**: Union, subtraction, intersection
- **Sweep Operations**: Pipe sweeps, extrusions, revolutions, lofts
- **Modifications**: Fillet, chamfer, shell, offset
- **Export Formats**: STL (3D printing), STEP (CAD interchange)
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
    .package(url: "https://github.com/gsdali/OCCTSwift.git", from: "0.5.0")
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

#### Validation
| Swift API | OCCT Class |
|-----------|------------|
| `shape.isValid` | `BRepCheck_Analyzer` |
| `shape.healed()` | `ShapeFix_Shape` |

### What's NOT Wrapped (Yet)

OCCT has thousands of classes. Some notable ones not yet exposed:

- **NURBS surfaces**: `Geom_BSplineSurface`, surface creation
- **Blend/Transition**: `BRepBlend_*` classes for complex fillets
- **Draft angles**: `BRepOffsetAPI_DraftAngle`
- **Face/Edge iteration**: Full `TopExp_Explorer` for complex topology
- **Measurement**: `BRepGProp` for volume, area, center of mass
- **2D operations**: `BRepBuilderAPI_MakeFace` from 2D regions
- **IGES import**: Only STEP is currently supported
- **Advanced healing**: `ShapeUpgrade_*`, `ShapeAnalysis_*`

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
