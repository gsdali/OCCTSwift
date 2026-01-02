## v0.5.0 - 2026-01-02

### AAG Feature Recognition & Wire Safety

This release adds B-Rep feature recognition capabilities and improves Wire factory method safety.

### New Features

#### AAG-Based Feature Recognition

- **`AttributeAdjacencyGraph`** - Build face adjacency graph for B-Rep feature detection
  - Analyzes edge convexity between adjacent faces (concave/convex/smooth)
  - Supports pocket, boss, and through-hole detection
  - Uses concave edge connectivity for robust feature isolation

- **`Shape.pocketFaces()`** - Detect pocket floor faces using AAG analysis
  - Finds upward-facing planar faces bounded by concave edges
  - More reliable than simple Z-slicing for complex geometry
  - Returns array of `Face` objects for toolpath generation

#### RealityKit Integration

- **`Mesh.toMeshResource()`** - Convert OCCTSwift mesh to RealityKit `MeshResource`
- **`Mesh.toModelComponent()`** - Convert to RealityKit `ModelComponent` for AR/VR apps

### Breaking Changes

#### Wire Factory Methods Now Return Optionals

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

### Bug Fixes

- **Wire.polygon crash on complex geometry** - Now returns nil instead of crashing when OCCT's `BRepBuilderAPI_MakePolygon` fails (fixes #18)

### Usage Examples

```swift
// AAG Feature Recognition
let shape = try Shape.load(from: stepURL)
let aag = AAG(shape: shape)

// Find pockets
let pockets = aag.detectPockets()
for pocket in pockets {
    print("Pocket at Z=\(pocket.zLevel), depth=\(pocket.depth)")
    print("  Floor face: \(pocket.floorFaceIndex)")
    print("  Wall faces: \(pocket.wallFaceIndices)")
}

// RealityKit Integration
let mesh = shape.mesh(linearDeflection: 0.1)
if let meshResource = mesh.toMeshResource() {
    let entity = ModelEntity(mesh: meshResource)
    // Add to RealityKit scene
}
```

### Full Changelog

https://github.com/gsdali/OCCTSwift/compare/v0.4.0...v0.5.0
