# OCCTSwift

A comprehensive Swift wrapper for [OpenCASCADE Technology (OCCT)](https://www.opencascade.com/) 8.0.0 beta1, providing B-Rep solid modeling for macOS and iOS. v1.0.0 will pin to OCCT 8.0.0 GA on May 7, 2026.

**4,269 wrapped operations** | **3,383 tests** | **1,176 suites** | macOS arm64 / iOS arm64

## Quick Start

### Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/gsdali/OCCTSwift.git", from: "0.128.0")
]
```

### Usage

```swift
import OCCTSwift

// Primitives
let box = Shape.box(width: 10, height: 5, depth: 3)
let cylinder = Shape.cylinder(radius: 2, height: 10)

// Boolean operations
let result = box - cylinder      // subtract
let combined = box + cylinder    // union
let common = box & cylinder      // intersect

// Modifications
let filleted = result.filleted(radius: 0.5)
let shelled = filleted.shelled(thickness: -0.3)

// Export
try Exporter.writeSTEP(shape: shelled, to: stepURL)
try Exporter.writeSTL(shape: shelled, to: stlURL, deflection: 0.05)
```

## Ecosystem

OCCTSwift is part of a family of packages:

| Package | Description |
|---------|-------------|
| **OCCTSwift** (this repo) | Core Swift wrapper for OCCT — shapes, curves, surfaces, import/export, OCAF |
| [OCCTSwiftViewport](https://github.com/gsdali/OCCTSwiftViewport) | Metal-based 3D viewport component for CAD applications |
| [OCCTSwiftScripts](https://github.com/gsdali/OCCTSwiftScripts) | Script harness for rapid parametric geometry iteration |
| [OCCTMCP](https://github.com/gsdali/OCCTMCP) | MCP server exposing CAD modeling to AI tools via Model Context Protocol |

## What's Wrapped

OCCTSwift provides method-level coverage of all user-facing OCCT classes. Key areas:

| Category | Operations | Highlights |
|----------|-----------|------------|
| Primitives & Sweeps | 36 | box, cylinder, sphere, cone, torus, wedge, pipe, extrude, revolve, loft, thru-sections |
| Booleans | 13 | union, subtract, intersect, section, split, cells builder, defeaturing |
| Modifications | 33 | fillet (uniform/variable/evolving), chamfer, shell, offset, draft |
| Wires & Edges | 56 | rectangle, circle, polygon, arc, BSpline, NURBS, helix, fillet2D, chamfer2D |
| 2D Curves | 97 | full Geom2d — lines, conics, BSplines, Bezier, Gcc constraint solver, hatching |
| 3D Curves | 84 | full Geom — lines, conics, BSplines, Bezier, interpolation, projection, evaluation |
| Surfaces | 86 | analytic, swept, freeform, plate, NLPlate, curvature, projection, trimming |
| Face / Edge Analysis | 54 | UV queries, normals, curvature, projection, classification, primary axis, surface type predicates |
| Feature-Based | 36 | boss, pocket, drill, split, pattern, rib, revolution, draft prism |
| Healing & Analysis | 69 | fix, unify, simplify, NURBS convert, sew, wire/face/shell repair |
| Measurement | 38 | volume, area, distance, inertia, point classification, proximity, revolution/symmetry axes |
| Import/Export | 19 | STEP, IGES, STL, OBJ, PLY, BREP, GLTF/GLB, DXF |
| XDE/OCAF | 200+ | assembly, colors, materials, GD&T (32 dimension types + 16 tolerance types, read + write), annotations, transactions, undo/redo, STEP AP242 round-trip |
| Math & Solvers | 50+ | root finding, BFGS, PSO, SVD, Gauss, Jacobi, constraint callbacks |
| Colors & Materials | 63 | Quantity_Color, sRGB/Lab/HLS, PBR materials, named colors |
| Geometry Factories | 90+ | GC/GCE2d/gce factories, convert to BSpline, analytical recognition |
| Drawings & Dimensions | 32 | HLR projection, visible/hidden/outline edges, linear/radial/diameter/angular dimensions, centrelines, auto-centreline from revolution axes, DXF R12 writer |
| Thread Features | 22 | ThreadForm (ISO-68/Unified), ThreadSpec parser (M5x0.8, 1/4-20 UNC), truncated 60° V-profile, multi-start, runout styles, Shape.threadedHole, Shape.threadedShaft |
| Sheet Metal | 3 | `SheetMetal.Flange` + `Bend` + `Builder.build` — declarative flange-and-bend composition via extrude + union + fillet |

For the full operation-by-operation mapping to OCCT classes, see [docs/API_REFERENCE.md](docs/API_REFERENCE.md).

## Examples

### Sweep a Profile Along a Path

```swift
let profile = Wire.rectangle(width: 5, height: 3)
let path = Wire.arc(center: .zero, radius: 50, startAngle: 0, endAngle: .pi / 2)
let swept = Shape.sweep(profile: profile, along: path)
```

### XDE Document with Assembly Structure

```swift
let doc = try Document.load(from: stepURL)

for node in doc.rootNodes {
    print("Part: \(node.name ?? "unnamed")")
    if let color = node.color {
        print("  Color: \(color.red), \(color.green), \(color.blue)")
    }
    if let shape = node.shape {
        let mesh = shape.mesh(linearDeflection: 0.1)
        // render with Metal, SceneKit, RealityKit...
    }
}
```

### Parametric Curves for Metal Rendering

```swift
let curve = Curve3D.interpolate(points: [
    SIMD3(0, 0, 0), SIMD3(5, 10, 0), SIMD3(10, 0, 5)
])!
let points = curve.drawAdaptive(curvatureDeflection: 0.1)
// Feed to Metal vertex buffer
```

### GLTF Export

```swift
try Exporter.writeGLTF(shape: model, to: gltfURL)
try Exporter.writeGLB(shape: model, to: glbURL)
```

## Architecture

```
Sources/OCCTSwift/          Swift public API
Sources/OCCTBridge/include/ C function declarations (OCCTBridge.h)
Sources/OCCTBridge/src/     Objective-C++ implementations (OCCTBridge.mm)
Libraries/OCCT.xcframework  Pre-built OCCT 8.0.0-beta1 static library (arm64)
Tests/OCCTSwiftTests/       All tests (Swift Testing framework)
```

Three-layer design: **Swift API** -> **C bridge** (Objective-C++) -> **OCCT C++**

Each OCCT object is managed via opaque handle types with release-on-deinit. See [docs/architecture/overview.md](docs/architecture/overview.md) for details.

## Requirements

- Swift 6.1+
- macOS 12.0+ (arm64) / iOS 15.0+ (arm64)
- Xcode 16.0+

## Building OCCT from Source

The pre-built xcframework is included. To rebuild from source:

```bash
./Scripts/build-occt.sh
```

See [docs/guides/building-occt.md](docs/guides/building-occt.md) for details.

## Documentation

| Document | Description |
|----------|-------------|
| [Architecture Overview](docs/architecture/overview.md) | Three-layer design, memory management, conventions |
| [Adding Features](docs/guides/adding-features.md) | How to wrap new OCCT operations |
| [OCCT Concepts](docs/guides/occt-concepts.md) | B-Rep topology, handles, shapes primer |
| [API Reference](docs/API_REFERENCE.md) | Full operation-by-operation mapping to OCCT classes |
| [Thread Safety](docs/thread-safety.md) | OCCTSerial mutex, parallel execution notes |
| [Naming Conventions](docs/naming-conventions.md) | Bridge and Swift naming patterns |
| [OCCT Upgrades](docs/occt-upgrades.md) | Breaking changes and migration for each OCCT version |
| [Wrapping Status](docs/occtswift-wrapping-gaps.md) | What's wrapped, what's not, and why |
| [Changelog](docs/CHANGELOG.md) | Release history |

## Known Issues

- **Parallel SEGV**: OCCT has thread-safety issues with global state (IGES reader/writer, `Interface_Static`). Running 1000+ tests concurrently crashes ~100% of the time. Individual suites pass reliably. Tracked upstream at [Open-Cascade-SAS/OCCT#1179](https://github.com/Open-Cascade-SAS/OCCT/issues/1179).

## License

LGPL-2.1. OpenCASCADE Technology is licensed under LGPL-2.1.

## Acknowledgments

- [OpenCASCADE](https://www.opencascade.com/) for the geometry kernel
