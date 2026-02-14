# OCCTSwift Metal Visualization API

Branch: `feature/metal-visualization`
Date: 2026-02-14

## Overview

This branch adds a complete set of OCCT wrappers for building a Metal-based CAD
viewport without any OpenGL dependency. It extracts geometry, camera math, selection,
and display configuration from OCCT and exposes them as Swift types that map directly
to Metal concepts.

**What this gives you:**

- Camera matrices in `simd_float4x4` format with Metal's [0,1] depth range
- Triangle meshes and edge wireframes ready for `MTLBuffer`
- BVH-accelerated hit testing (point, rectangle, and lasso pick)
- Sub-shape selection (pick individual faces, edges, or vertices)
- Clip plane equations for `[[clip_distance]]`
- Z-layer settings for `MTLDepthStencilDescriptor` and `setDepthBias()`
- Tessellation quality control via `DisplayDrawer`

**What this does NOT include:**

- Any Metal rendering code (that's ViewportKit's job)
- OpenGL, V3d, or AIS dependencies
- GPU pick-ID buffer (see [ViewportKit#6](https://github.com/gsdali/ViewportKit/issues/6))

## Dependency

Add OCCTSwift as a package dependency and target the `feature/metal-visualization`
branch:

```swift
.package(url: "https://github.com/gsdali/OCCTSwift.git", branch: "feature/metal-visualization")
```

All types are in the `OCCTSwift` module:

```swift
import OCCTSwift
```

---

## API Reference

### Camera

Wraps `Graphic3d_Camera`. Produces Metal-compatible projection/view matrices.

```swift
let cam = Camera()

// Position
cam.eye    = SIMD3(0, 0, 50)
cam.center = SIMD3(0, 0, 0)
cam.up     = SIMD3(0, 1, 0)

// Projection
cam.projectionType = .perspective   // or .orthographic
cam.fieldOfView    = 45.0           // degrees (perspective only)
cam.scale          = 100.0          // orthographic only
cam.zRange         = (near: 0.1, far: 1000.0)
cam.aspect         = Double(viewWidth) / Double(viewHeight)

// Matrices — column-major, [0,1] depth, ready for Metal uniform buffer
let proj: simd_float4x4 = cam.projectionMatrix
let view: simd_float4x4 = cam.viewMatrix

// Coordinate conversion
let screen = cam.project(SIMD3(5, 5, 0))      // world → screen
let world  = cam.unproject(SIMD3(0.5, 0.5, 0)) // screen → world

// Auto-frame
cam.fit(boundingBox: (min: shape.boundingBox.min,
                      max: shape.boundingBox.max))
```

**Metal mapping:**
- `projectionMatrix` / `viewMatrix` → shader uniform buffer
- Matrices use Metal's [0,1] depth range (not OpenGL's [-1,1])
- `simd_float4x4` layout matches `float4x4` in MSL

---

### PresentationMesh — Shaded Mesh Extraction

Extract triangulated meshes and edge wireframes from any `Shape`.

#### Shaded mesh (triangles + normals)

```swift
let box = Shape.box(width: 10, height: 10, depth: 10)

if let mesh = box.shadedMesh(deflection: 0.1) {
    // mesh.vertices: [SIMD3<Float>]  — vertex positions
    // mesh.normals:  [SIMD3<Float>]  — per-vertex normals
    // mesh.indices:  [UInt32]        — triangle indices (3 per tri)
    // mesh.triangleCount: Int

    // Create Metal buffers
    let vBuf = device.makeBuffer(bytes: mesh.vertices,
                                 length: mesh.vertices.count * MemoryLayout<SIMD3<Float>>.stride)
    let iBuf = device.makeBuffer(bytes: mesh.indices,
                                 length: mesh.indices.count * MemoryLayout<UInt32>.stride)
}
```

#### Edge wireframe (polylines)

```swift
if let edges = box.edgeMesh(deflection: 0.1) {
    // edges.vertices:      [SIMD3<Float>]  — all polyline vertices
    // edges.segmentStarts: [Int]           — index where each edge begins
    // edges.segmentCount:  Int

    // Draw each edge as a line strip:
    for i in 0..<edges.segmentCount {
        let start = edges.segmentStarts[i]
        let end = (i + 1 < edges.segmentCount)
            ? edges.segmentStarts[i + 1]
            : edges.vertices.count
        let count = end - start
        // encoder.drawPrimitives(type: .lineStrip, vertexStart: start, vertexCount: count)
    }
}
```

#### Drawer-controlled tessellation

Use a `DisplayDrawer` for fine-grained control over tessellation quality:

```swift
let drawer = DisplayDrawer()
drawer.deviationCoefficient = 0.0005  // finer than default
drawer.deviationAngle = 0.2           // radians

let fineMesh = sphere.shadedMesh(drawer: drawer)
let fineEdges = sphere.edgeMesh(drawer: drawer)
```

---

### Selector — BVH-Accelerated Hit Testing

Interactive picking without OpenGL. Uses OCCT's 3-level BVH for fast traversal
even on large assemblies.

#### Setup

```swift
let selector = Selector()

// Register shapes with unique IDs
selector.add(shape: boxShape, id: 1)
selector.add(shape: cylinderShape, id: 2)

// Enable sub-shape selection modes
selector.activateMode(.face, for: 1)   // pick faces on shape 1
selector.activateMode(.edge, for: 1)   // also pick edges on shape 1

// Adjust tolerance for thin geometry
selector.pixelTolerance = 4  // pixels (default 2)
```

#### Point pick (click)

```swift
let results = selector.pick(
    at: SIMD2(mouseX, mouseY),
    camera: cam,
    viewSize: SIMD2(viewWidth, viewHeight)
)

if let hit = results.first {
    hit.shapeId      // Int32 — the ID you assigned
    hit.depth         // Double — distance from camera
    hit.point         // SIMD3<Double> — world-space hit point
    hit.subShapeType  // .face, .edge, .vertex, .shape, etc.
    hit.subShapeIndex // Int32 — 1-based index within parent (0 = whole shape)
}
```

#### Rectangle pick (rubber band)

```swift
let results = selector.pick(
    rect: (min: SIMD2(x1, y1), max: SIMD2(x2, y2)),
    camera: cam,
    viewSize: SIMD2(viewWidth, viewHeight)
)
// results contains all shapes/sub-shapes intersecting the rectangle
```

#### Polygon pick (lasso)

```swift
let lasso: [SIMD2<Double>] = [
    SIMD2(100, 50),
    SIMD2(200, 100),
    SIMD2(180, 200),
    SIMD2(80, 180),
    SIMD2(100, 50),   // close the polygon
]
let results = selector.pick(
    polygon: lasso,
    camera: cam,
    viewSize: SIMD2(viewWidth, viewHeight)
)
```

#### Selection modes

| Mode | Picks | Raw value |
|------|-------|-----------|
| `.shape` | Entire shape as one entity | 0 |
| `.vertex` | Individual vertices | 1 |
| `.edge` | Individual edges | 2 |
| `.wire` | Connected edge loops | 3 |
| `.face` | Individual faces | 4 |

Multiple modes can be active simultaneously. Mode 0 (shape) is activated by
default when a shape is added.

#### Sub-shape types in results

| SubShapeType | Meaning | Raw value |
|---|---|---|
| `.compound` | Compound shape | 0 |
| `.compsolid` | Compound solid | 1 |
| `.solid` | Solid body | 2 |
| `.shell` | Shell | 3 |
| `.face` | Face | 4 |
| `.wire` | Wire | 5 |
| `.edge` | Edge | 6 |
| `.vertex` | Vertex | 7 |
| `.shape` | Generic shape | 8 |

#### Lifecycle

```swift
selector.remove(id: 1)           // remove one shape
selector.clearAll()               // remove all shapes
selector.deactivateMode(.face, for: 2)  // stop picking faces on shape 2
```

---

### ClipPlane

Wraps `Graphic3d_ClipPlane`. The equation `Ax + By + Cz + D = 0` defines a
half-space where `Ax + By + Cz + D > 0` is visible.

```swift
// Clip everything below Y=5
let plane = ClipPlane(equation: SIMD4(0, 1, 0, -5))
plane.isOn = true

// Or from normal + distance
let plane2 = ClipPlane(normal: SIMD3(0, 0, 1), distance: -10)
```

**Metal vertex shader mapping:**

```metal
vertex VertexOut main_vertex(...) {
    VertexOut out;
    out.position = ...;
    // clipPlane is SIMD4<Float> from ClipPlane.equation
    out.clipDist[0] = dot(clipPlane.xyz, worldPos.xyz) + clipPlane.w;
    return out;
}
```

#### Capping (cross-section fill)

```swift
plane.isCapping = true
plane.cappingColor = SIMD3(0.8, 0.2, 0.2)  // red cross-section
plane.hatchStyle = .diagonal45
plane.isHatchOn = true
```

Metal implementation: stencil increment on back faces, stencil decrement on
front faces, fill where stencil != 0.

#### Probing

Test geometry against clip planes on the CPU side for culling:

```swift
let state = plane.probe(point: SIMD3(0, 10, 0))  // .in, .out, or .on

let boxState = plane.probe(box: (min: SIMD3(-5, -5, -5),
                                  max: SIMD3(5, 5, 5)))
// .in = fully visible, .out = fully clipped, .on = partially clipped
```

#### Chaining (AND logic)

Combine multiple planes to create complex clipping regions:

```swift
let top = ClipPlane(equation: SIMD4(0, -1, 0, 10))    // clip above Y=10
let bottom = ClipPlane(equation: SIMD4(0, 1, 0, -2))   // clip below Y=2
top.chainNext(bottom)  // both must pass → slice between Y=2 and Y=10

top.chainLength  // 2
```

---

### ZLayerSettings

Configuration for rendering layers. Controls depth testing, polygon offset, and
render order.

```swift
let settings = ZLayerSettings()

// Depth
settings.depthTestEnabled  = true
settings.depthWriteEnabled = true
settings.clearDepth        = false  // true → loadAction: .clear

// Polygon offset (depth bias for wireframe-on-shaded)
settings.polygonOffset = ZLayerSettings.PolygonOffset(
    mode: .fill,
    factor: 1.0,   // → setDepthBias slopeScale
    units: 1.0     // → setDepthBias depthBias
)
// Or use convenience methods:
settings.setDepthOffsetPositive()  // push away from camera
settings.setDepthOffsetNegative()  // pull toward camera

// Render options
settings.isImmediate = false          // draw in normal pass order
settings.isRaytracable = true         // participate in ray tracing
settings.renderInDepthPrepass = true  // include in early-Z pass

// Culling
settings.cullingDistance = 10000.0   // cull objects farther than this
settings.cullingSize = 2.0           // cull objects smaller than 2px

// Large-scene precision
settings.origin = SIMD3(1_000_000, 0, 0)  // layer origin near camera
```

**Predefined layer IDs:**

| Layer | ID | Purpose |
|-------|---:|---------|
| `ZLayerSettings.bottomOSD` | -5 | 2D underlay |
| `ZLayerSettings.default` | 0 | Main 3D scene |
| `ZLayerSettings.top` | -2 | 3D overlay (inherits depth) |
| `ZLayerSettings.topmost` | -3 | 3D overlay (own depth) |
| `ZLayerSettings.topOSD` | -4 | 2D overlay (annotations, UI) |

---

### DisplayDrawer

Controls tessellation quality and wireframe display.

```swift
let drawer = DisplayDrawer()

// Tessellation quality
drawer.deflectionType       = .relative       // or .absolute
drawer.deviationCoefficient = 0.001           // relative to bbox (finer = smaller)
drawer.deviationAngle       = 0.35            // radians (~20°)
drawer.maximalChordialDeviation = 0.1         // for .absolute mode
drawer.autoTriangulation    = true

// Edge display
drawer.faceBoundaryDraw = true    // show face boundaries
drawer.wireDraw         = true    // show wireframe edges

// Curve discretisation
drawer.discretisation   = 30     // points per curve
drawer.isoOnTriangulation = false // iso-parameter lines
```

Use with mesh extraction:

```swift
let mesh = shape.shadedMesh(drawer: drawer)
let edges = shape.edgeMesh(drawer: drawer)
```

---

## Integration Guide for ViewportKit

### Minimum viable integration

The fastest path to interactive selection in a Metal viewport:

1. **Camera sync** — Feed your Metal camera state into an OCCTSwift `Camera`:

```swift
let occtCamera = Camera()

func updateOCCTCamera(from metalView: MTKView) {
    occtCamera.eye = myEye
    occtCamera.center = myCenter
    occtCamera.up = myUp
    occtCamera.fieldOfView = myFOV
    occtCamera.aspect = Double(metalView.drawableSize.width / metalView.drawableSize.height)
    occtCamera.zRange = (near: myNear, far: myFar)
}
```

Or go the other direction — use `Camera` as the source of truth and read its
matrices for your Metal uniform buffer:

```swift
struct Uniforms {
    var projectionMatrix: simd_float4x4
    var viewMatrix: simd_float4x4
}

var uniforms = Uniforms(
    projectionMatrix: occtCamera.projectionMatrix,
    viewMatrix: occtCamera.viewMatrix
)
```

2. **Mesh extraction** — Get vertex data for Metal buffers:

```swift
func loadShape(_ shape: Shape) -> (MTLBuffer, MTLBuffer, Int)? {
    guard let mesh = shape.shadedMesh(deflection: 0.1) else { return nil }

    // Interleave positions + normals for a single vertex buffer
    var interleaved = [Float]()
    interleaved.reserveCapacity(mesh.vertices.count * 6)
    for i in 0..<mesh.vertices.count {
        interleaved.append(contentsOf: [mesh.vertices[i].x, mesh.vertices[i].y, mesh.vertices[i].z])
        interleaved.append(contentsOf: [mesh.normals[i].x, mesh.normals[i].y, mesh.normals[i].z])
    }

    let vBuf = device.makeBuffer(bytes: interleaved,
                                  length: interleaved.count * MemoryLayout<Float>.stride,
                                  options: .storageModeShared)!
    let iBuf = device.makeBuffer(bytes: mesh.indices,
                                  length: mesh.indices.count * MemoryLayout<UInt32>.stride,
                                  options: .storageModeShared)!
    return (vBuf, iBuf, mesh.indices.count)
}
```

3. **Hit testing** — Handle clicks:

```swift
let selector = Selector()

func onShapeAdded(_ shape: Shape, id: Int32) {
    selector.add(shape: shape, id: id)
    selector.activateMode(.face, for: id)
}

func onClick(at pixel: CGPoint, in view: MTKView) {
    updateOCCTCamera(from: view)
    let size = view.drawableSize
    let results = selector.pick(
        at: SIMD2(Double(pixel.x), Double(pixel.y)),
        camera: occtCamera,
        viewSize: SIMD2(Double(size.width), Double(size.height))
    )
    if let hit = results.first {
        print("Hit shape \(hit.shapeId), face \(hit.subShapeIndex)")
        selectedShapes.insert(hit.shapeId)  // highlight in next frame
    }
}
```

### Selection state management

OCCT's `Selector` handles the picking algorithm. Selection state (which shapes
are selected, highlight, selection schemes) is managed in Swift:

```swift
var selectedShapes = Set<Int32>()

func select(_ results: [Selector.PickResult], mode: SelectionScheme) {
    switch mode {
    case .replace:
        selectedShapes = Set(results.map(\.shapeId))
    case .add:
        selectedShapes.formUnion(results.map(\.shapeId))
    case .toggle:
        for r in results {
            if selectedShapes.contains(r.shapeId) {
                selectedShapes.remove(r.shapeId)
            } else {
                selectedShapes.insert(r.shapeId)
            }
        }
    }
}
```

Highlighting is a shader uniform per draw call:

```metal
fragment float4 main_fragment(..., constant bool& isSelected [[buffer(3)]]) {
    float4 color = shadedColor;
    if (isSelected) {
        color.rgb = mix(color.rgb, float3(0.2, 0.5, 1.0), 0.4);
    }
    return color;
}
```

### Clip planes in the render pipeline

```swift
let clipPlane = ClipPlane(equation: SIMD4(0, 1, 0, -5))
clipPlane.isOn = true

// In your render pass:
var clipEq = clipPlane.equation
encoder.setVertexBytes(&clipEq, length: MemoryLayout<SIMD4<Double>>.stride, index: 4)
```

```metal
struct VertexOut {
    float4 position [[position]];
    float  clipDist [[clip_distance]] [1];
};

vertex VertexOut main_vertex(..., constant float4& clipPlane [[buffer(4)]]) {
    VertexOut out;
    out.position = uniforms.proj * uniforms.view * float4(pos, 1.0);
    out.clipDist[0] = dot(clipPlane.xyz, worldPos.xyz) + clipPlane.w;
    return out;
}
```

### Z-layer render pass setup

```swift
func configureRenderPass(for layer: ZLayerSettings) -> MTLRenderPassDescriptor {
    let desc = MTLRenderPassDescriptor()

    if layer.clearDepth {
        desc.depthAttachment.loadAction = .clear
    } else {
        desc.depthAttachment.loadAction = .load
    }

    return desc
}

func configureDepthStencil(for layer: ZLayerSettings) -> MTLDepthStencilState {
    let desc = MTLDepthStencilDescriptor()
    desc.isDepthWriteEnabled = layer.depthWriteEnabled
    desc.depthCompareFunction = layer.depthTestEnabled ? .less : .always
    return device.makeDepthStencilState(descriptor: desc)!
}

func configureEncoder(_ encoder: MTLRenderCommandEncoder, for layer: ZLayerSettings) {
    let offset = layer.polygonOffset
    if offset.mode != .off {
        encoder.setDepthBias(Float(offset.units), slopeScale: Float(offset.factor), clamp: 0)
    }
}
```

---

## Test Coverage

232 tests total, including these suites for the new APIs:

| Suite | Tests | What it covers |
|-------|------:|----------------|
| Camera Tests | 6 | Default state, matrices, project/unproject roundtrip, ortho mode, fit bbox |
| Presentation Mesh Tests | 4 | Box mesh (12 tris), cylinder mesh, box edges (12 segments), sphere edges |
| Selector Tests | 6 | Point pick hit/miss, multiple shapes, remove, rectangle pick, clear |
| Selector Sub-Shape Modes | 7 | Default mode, activate/deactivate, face pick, edge pick, pixel tolerance, shape pick |
| Polyline Pick | 4 | Polygon hit, polygon miss, too few points, triangular polygon |
| Drawer Mesh Extraction | 4 | Default drawer mesh, edge mesh, finer deviation, absolute deflection |
| Display Drawer | 10 | All properties: deviation, angle, chordial, deflection type, auto-tri, iso, discretisation, boundaries, wire |
| Clip Plane | 15 | Equation, reversed, enable, capping, color, hatch, probe point/box, chain, clear chain |
| Z-Layer Settings | 13 | Depth test/write, clear depth, polygon offset, immediate, raytracable, culling, origin, predefined IDs |

Run all tests:

```bash
swift test
```

---

## Branch Details

```
Branch: feature/metal-visualization
Base:   main

Commits:
  c97e84d  Add polyline (lasso) pick and Drawer-aware mesh extraction
  ed05d2d  Add sub-shape selection modes and display drawer wrapper
  9458920  Add ClipPlane and ZLayerSettings wrappers (Phases 5-6)
  a651591  Add Metal visualization wrappers: Camera, PresentationMesh, Selector

Files changed: 9 files, +3,438 lines
  Sources/OCCTBridge/include/OCCTBridge.h   +246
  Sources/OCCTBridge/src/OCCTBridge.mm      +1,224
  Sources/OCCTSwift/Camera.swift            +145  (new)
  Sources/OCCTSwift/ClipPlane.swift         +166  (new)
  Sources/OCCTSwift/DisplayDrawer.swift     +102  (new)
  Sources/OCCTSwift/PresentationMesh.swift  +185  (new)
  Sources/OCCTSwift/Selector.swift          +227  (new)
  Sources/OCCTSwift/ZLayerSettings.swift    +184  (new)
  Tests/OCCTSwiftTests/ShapeTests.swift     +959
```

---

## Related

- [VISUALIZATION_WRAPPING_PLAN.md](VISUALIZATION_WRAPPING_PLAN.md) — Full architectural plan with OCCT class analysis
- [ViewportKit#6](https://github.com/gsdali/ViewportKit/issues/6) — GPU-accelerated pick-ID buffer (Phase 4, Metal-side)
