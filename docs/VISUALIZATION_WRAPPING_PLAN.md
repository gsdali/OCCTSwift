# OCCT Visualization Wrapping Plan for Metal on Apple Silicon

Status: Planning
Date: 2026-02-14
Target: ViewportKit integration via OCCTSwift

## Overview

This document describes a phased plan for wrapping OCCT's visualization and
selection infrastructure for use with a Metal-based viewport on Apple Silicon.
The goal is to get interactive selection (click-to-pick face/edge/vertex,
rubber-band, lasso) working with full hardware acceleration, without pulling
in OCCT's OpenGL rendering stack.

## Key Architectural Decision

OCCT's visualization splits into three layers. Only two are worth wrapping:

| Layer | GL Dependent? | Wrap? | Rationale |
|-------|:---:|:---:|-----------|
| Data extraction (StdPrs, Prs3d_Drawer, Graphic3d_ArrayOfPrimitives) | No | Yes | Better vertex data than current BRepMesh path |
| Selection (SelectMgr, Select3D, StdSelect) | No | Yes | Solves interactivity; 3-level BVH; sub-shape modes |
| Rendering (OpenGl_*, Graphic3d_GraphicDriver, V3d) | Yes | No | Metal replaces this entirely |

**Proof of decoupling**: OCCT ships `IVtkOCC_ViewerSelector`, which drives
SelectMgr from a VTK camera using only `Graphic3d_Camera` (pure math, no GL).
The same pattern works for Metal.

## Dependency Graph

```
                    +---------------------------+
                    |   Graphic3d_Camera        |  <- Phase 1
                    |   [0,1] depth, matrices   |
                    +-----------+---------------+
                                |
              +-----------------+-----------------+
              |                 |                 |
              v                 v                 v
     +------------+   +--------------+   +------------------+
     | Prs3d_     |   | SelectMgr_   |   | Graphic3d_       |
     | Drawer     |   | Frustum      |   | ClipPlane        |
     | (display   |   | Builder      |   | (plane eqs,      |  <- Phase 2
     |  attribs)  |   | (pixel->3D)  |   |  culling tests)  |
     +-----+------+   +------+-------+   +------------------+
           |                  |
           v                  v
  +----------------+   +---------------------------+
  | StdPrs_        |   | SelectMgr_                |
  | ShadedShape    |   | ViewerSelector            |
  | WFShape        |   | SelectionManager          |  <- Phase 3
  | (-> vertex     |   | (3-level BVH traversal)   |
  |  data for      |   +------------+--------------+
  |  Metal)        |                |
  +----------------+                v
                    +---------------------------+
                    | StdSelect_                |
                    | BRepSelectionTool         |
                    | (shape -> sensitives)     |  <- Phase 4
                    |                           |
                    | Select3D_Sensitive*       |
                    | (BVH leaf entities)       |
                    +---------------------------+
```

---

## Phase 1: Camera and Foundations

### What

Wrap `Graphic3d_Camera` as a standalone type that produces Metal-compatible
view/projection matrices.

### Why First

Everything else depends on it. Selection needs it for frustum building. Metal
needs it for shader uniforms. It validates the data-extraction approach before
committing to heavier wrapping.

### Key Facts

- `Graphic3d_Camera` has zero GL dependencies. It computes matrices from
  eye/center/up/FOV/aspect/near/far using pure math.
- Calling `SetZeroToOneDepth(true)` switches from OpenGL's [-1,1] NDC depth
  to Metal's [0,1] range.
- `OrientationMatrixF()` and `ProjectionMatrixF()` return `NCollection_Mat4<float>`
  (16 floats, column-major) -- same layout as `simd_float4x4`.
- `Graphic3d_CameraLerp` provides smooth camera interpolation.

### Methods to Wrap

- `SetEye/Center/Up`, `SetProjectionType`, `SetFOVy`, `SetZRange`, `SetAspect`
- `ProjectionMatrixF()`, `OrientationMatrixF()` -> `simd_float4x4`
- `Project()` / `UnProject()` -- world <-> screen coordinate conversion
- `FitMinMax()` / `ZFitAll()` -- auto-framing helpers

### Bridge API Shape

```c
typedef struct OCCTCamera* OCCTCameraRef;

OCCTCameraRef OCCTCameraCreate(void);
void OCCTCameraRelease(OCCTCameraRef camera);

void OCCTCameraSetEye(OCCTCameraRef, double x, double y, double z);
void OCCTCameraSetCenter(OCCTCameraRef, double x, double y, double z);
void OCCTCameraSetUp(OCCTCameraRef, double x, double y, double z);
void OCCTCameraSetFOVy(OCCTCameraRef, double fov);
void OCCTCameraSetZRange(OCCTCameraRef, double zNear, double zFar);
void OCCTCameraSetAspect(OCCTCameraRef, double aspect);
void OCCTCameraSetProjectionType(OCCTCameraRef, int32_t type); // 0=ortho, 1=perspective

// Returns 16 floats (column-major 4x4), caller provides buffer
void OCCTCameraGetProjectionMatrix(OCCTCameraRef, float* out16);
void OCCTCameraGetViewMatrix(OCCTCameraRef, float* out16);

// World <-> screen conversion
bool OCCTCameraProject(OCCTCameraRef, double wx, double wy, double wz,
                       double* sx, double* sy, double* sz);
bool OCCTCameraUnProject(OCCTCameraRef, double sx, double sy, double sz,
                         double* wx, double* wy, double* wz);

// Auto-framing
void OCCTCameraFitBounds(OCCTCameraRef, double xMin, double yMin, double zMin,
                         double xMax, double yMax, double zMax);
```

### Swift API Shape

```swift
public final class Camera: @unchecked Sendable {
    internal let handle: OCCTCameraRef

    public var eye: SIMD3<Double>
    public var center: SIMD3<Double>
    public var up: SIMD3<Double>
    public var fov: Double
    public var nearPlane: Double
    public var farPlane: Double
    public var aspect: Double
    public var projectionType: ProjectionType

    public var projectionMatrix: simd_float4x4 { get }
    public var viewMatrix: simd_float4x4 { get }

    public func project(_ worldPoint: SIMD3<Double>) -> SIMD3<Double>?
    public func unproject(_ screenPoint: SIMD3<Double>) -> SIMD3<Double>?
    public func fitTo(_ bounds: (min: SIMD3<Double>, max: SIMD3<Double>))
}
```

### Apple Silicon Consideration

Float matrices go directly into a Metal uniform buffer via `.storageModeShared`.
Zero copy from OCCT math to GPU.

### Complexity

Low. Self-contained class, no dependencies beyond gp_Pnt/gp_Dir/NCollection_Mat4.

---

## Phase 2: Enhanced Vertex Data Extraction (StdPrs)

### What

Wrap `StdPrs_ShadedShape::FillTriangles()` and `StdPrs_WFShape::AddAllEdges()`
to produce Metal-ready vertex buffers. Also wrap `Prs3d_Drawer` for display
attribute control.

### Why Second

The current `Mesh` type tessellates via `BRepMesh_IncrementalMesh` then
manually walks faces to build vertex arrays. The StdPrs path does the same
tessellation but also produces:

- Interleaved vertex layout (position + normal + UV in one buffer) that maps
  directly to `MTLVertexDescriptor`
- Edge polylines classified by type (free/boundary/shared) via `Prs3d_Drawer`
- Face boundary lines that exactly match the tessellation (`FillFaceBoundaries`)
- Correct separation of closed vs open solids for backface culling optimization

### Key Classes

**Graphic3d_ArrayOfPrimitives / Graphic3d_Buffer**

Stores interleaved vertex data CPU-side with zero GL dependency:

| OCCT Attribute | OCCT Data Type | Metal Equivalent |
|---|---|---|
| `Graphic3d_TOA_POS` | `VEC3` (float) | `MTLVertexFormat.float3` |
| `Graphic3d_TOA_NORM` | `VEC3` (float) | `MTLVertexFormat.float3` |
| `Graphic3d_TOA_UV` | `VEC2` (float) | `MTLVertexFormat.float2` |
| `Graphic3d_TOA_COLOR` | `VEC4UB` (4 bytes) | `MTLVertexFormat.uchar4Normalized` |

Index data supports both 16-bit and 32-bit (`MTLIndexType.uint16` / `.uint32`).

**Prs3d_Drawer**

Pure data container controlling tessellation and display:
- Deflection parameters (chordal deviation, angular)
- Isoline counts (U/V)
- Aspect objects: `WireAspect`, `ShadingAspect`, `FreeBoundaryAspect`, etc.
- Linked drawer pattern (child -> parent fallback for unset values)

### Data Extraction Pipeline

```
TopoDS_Shape
    |
    v
BRepMesh_IncrementalMesh(shape, deflection)      // triangulate
    |
    v
StdPrs_ShadedShape::FillTriangles(shape)         // interleaved triangles
StdPrs_WFShape::AddAllEdges(shape, drawer)        // classified edge polylines
StdPrs_ShadedShape::FillFaceBoundaries(shape)     // face boundary lines
    |
    v
Graphic3d_Buffer::Data()                          // raw bytes, stride-based
Graphic3d_IndexBuffer::Data()                      // raw index bytes
    |
    v
MTLDevice.makeBuffer(bytesNoCopy:...)             // zero-copy on Apple Silicon
```

### Apple Silicon Win

With unified memory, allocate a `.storageModeShared` `MTLBuffer`, get its
`contents()` pointer, and have OCCT write vertex data directly into GPU-visible
memory. No intermediate `[Float]` array, no `Data` copy. For a 10M triangle
assembly this eliminates ~240MB of redundant copies.

### Complexity

Medium. The interleaved buffer layout needs a mapping layer to
`MTLVertexDescriptor`. The data itself is `memcpy`-ready bytes.

---

## Phase 3: SelectMgr Core (High-Value Target)

### What

Wrap the selection algorithm: `SelectMgr_ViewerSelector`,
`SelectMgr_SelectionManager`, `SelectMgr_SelectableObject`,
`SelectMgr_EntityOwner`, plus `StdSelect_BRepSelectionTool` for
shape-to-sensitive decomposition.

### Why This Is the Highest-Value Target

It gives you:
- **Point picking** (click -> face/edge/vertex)
- **Rectangle selection** (rubber band -> set of entities)
- **Polyline selection** (lasso -> set of entities)
- **3-level BVH acceleration** (fast even on million-triangle assemblies)
- **Sub-shape decomposition** (mode 0=object, 4=face, 2=edge, 1=vertex)
- **Priority-based resolution** (vertex > edge > face when overlapping)
- **Persistent BVH** (doesn't rebuild when camera moves, only when geometry changes)

### How It Works Without OpenGL

The entire selection pipeline is geometry/math only. What `Pick()` extracts
from `V3d_View`:

| Data Needed | Source | OCCT Type |
|---|---|---|
| Eye, center, up | Your Metal camera | `Graphic3d_Camera` |
| Projection type, FOV | Your Metal camera | `Graphic3d_Camera` |
| Near/far, aspect | Your Metal camera | `Graphic3d_Camera` |
| Window width/height | Your Metal viewport | Integer pair |
| Mouse coordinates | User input | Integer pair |
| Clip planes | Optional | `Graphic3d_ClipPlane` |

The frustum building chain (all pure math):

```
Graphic3d_Camera (Phase 1)
    |
    v
SelectMgr_FrustumBuilder (camera + window size)
    |
    v
SelectMgr_RectangularFrustum (frustum vertices from camera + pixel coords)
    |
    v
SelectMgr_SelectingVolumeManager (delegates Overlaps* calls)
    |
    v
SelectMgr_ViewerSelector::TraverseSensitives() (3-level BVH walk)
```

### The BVH Architecture

Three levels, all using Separating Axis Theorem (SAT) overlap tests:

**Level 1 -- Object BVH** (`SelectMgr_SelectableObjectSet`):
Built from AABBs of all registered selectable objects. Skips entire objects
whose bounding boxes don't overlap the selection frustum.

**Level 2 -- Entity BVH** (`SelectMgr_SensitiveEntitySet`):
Per-object BVH over all sensitive entities (faces, edges, vertices).
Determines which individual sensitives might be hit.

**Level 3 -- Sub-Entity BVH** (inside `Select3D_SensitiveSet` subclasses):
For complex entities (triangulated faces with thousands of triangles).
Internal BVH over sub-element bounding boxes.

Key design: **the frustum is transformed, not the entities.** BVH structures
persist across camera moves. Only geometry changes trigger rebuilds.

### Shape-to-Sensitive Mapping (StdSelect_BRepSelectionTool)

| Shape Type | Sensitive Entity | Notes |
|---|---|---|
| VERTEX | `Select3D_SensitivePoint` | Single point |
| EDGE (line) | `Select3D_SensitiveSegment` | Line segment |
| EDGE (circle) | `Select3D_SensitiveCircle` | Analytic circle test |
| EDGE (general) | `Select3D_SensitiveCurve` | BVH over polyline segments |
| FACE (sphere) | `Select3D_SensitiveSphere` | Analytic sphere test |
| FACE (cylinder) | `Select3D_SensitiveCylinder` | Analytic cylinder test |
| FACE (general) | `Select3D_SensitiveTriangulation` | BVH over triangles |
| WIRE | `Select3D_SensitiveWire` | Groups edge entities |
| SOLID | Multiple face entities | Recursive decomposition |

### Implementation Approach

Subclass `SelectMgr_ViewerSelector` (following `IVtkOCC_ViewerSelector` pattern):

```cpp
class OCCTMetalSelector : public SelectMgr_ViewerSelector {
public:
    void Pick(int x, int y,
              const Handle(Graphic3d_Camera)& cam,
              int viewW, int viewH) {
        mySelectingVolumeMgr.SetCamera(cam);
        mySelectingVolumeMgr.SetWindowSize(viewW, viewH);
        mySelectingVolumeMgr.InitPointSelectingVolume(x, y);
        mySelectingVolumeMgr.BuildSelectingVolume();
        TraverseSensitives();
    }

    void PickBox(int x1, int y1, int x2, int y2,
                 const Handle(Graphic3d_Camera)& cam,
                 int viewW, int viewH) {
        mySelectingVolumeMgr.SetCamera(cam);
        mySelectingVolumeMgr.SetWindowSize(viewW, viewH);
        mySelectingVolumeMgr.InitBoxSelectingVolume(
            gp_Pnt(x1, y1, 0), gp_Pnt(x2, y2, 0));
        mySelectingVolumeMgr.BuildSelectingVolume();
        TraverseSensitives();
    }
};
```

Also need a concrete `SelectMgr_SelectableObject` subclass:

```cpp
class OCCTSelectableShape : public SelectMgr_SelectableObject {
    TopoDS_Shape myShape;
public:
    void ComputeSelection(const Handle(SelectMgr_Selection)& sel,
                          const Standard_Integer mode) override {
        StdSelect_BRepSelectionTool::Load(
            sel, this, myShape,
            TopAbsModeMap(mode),  // 0=shape, 1=vertex, 2=edge, 4=face
            myDeflection, myDeviationAngle);
    }
    // Compute() for presentation -- left empty, never called
    void Compute(const Handle(PrsMgr_PresentationManager)&,
                 const Handle(Prs3d_Presentation)&,
                 const Standard_Integer) override {}
};
```

**Note on PrsMgr inheritance**: `SelectMgr_SelectableObject` inherits from
`PrsMgr_PresentableObject`. This drags in presentation infrastructure at the
type level but you never call `Compute()` and don't need a
`PrsMgr_PresentationManager`. The presentation members remain unused.

### Bridge API Shape

```c
typedef struct OCCTSelector* OCCTSelectorRef;

OCCTSelectorRef OCCTSelectorCreate(void);
void OCCTSelectorRelease(OCCTSelectorRef);

// Register shapes for selection
int32_t OCCTSelectorAddShape(OCCTSelectorRef, OCCTShapeRef, int32_t shapeId);
void OCCTSelectorRemoveShape(OCCTSelectorRef, int32_t shapeId);

// Activate selection modes (0=shape, 1=vertex, 2=edge, 3=wire, 4=face)
void OCCTSelectorActivateMode(OCCTSelectorRef, int32_t shapeId, int32_t mode);
void OCCTSelectorDeactivateMode(OCCTSelectorRef, int32_t shapeId, int32_t mode);

// Update after geometry changes
void OCCTSelectorUpdate(OCCTSelectorRef, int32_t shapeId);

// Pick operations (require Phase 1 camera)
int32_t OCCTSelectorPick(OCCTSelectorRef, int32_t px, int32_t py,
                         OCCTCameraRef, int32_t viewW, int32_t viewH);
int32_t OCCTSelectorPickBox(OCCTSelectorRef,
                            int32_t x1, int32_t y1, int32_t x2, int32_t y2,
                            OCCTCameraRef, int32_t viewW, int32_t viewH);
int32_t OCCTSelectorPickPoly(OCCTSelectorRef,
                             const int32_t* polyXY, int32_t pointCount,
                             OCCTCameraRef, int32_t viewW, int32_t viewH);

// Read results (ranked by depth/priority, 1-based)
int32_t OCCTSelectorNbPicked(OCCTSelectorRef);
int32_t OCCTSelectorPickedShapeId(OCCTSelectorRef, int32_t rank);
int32_t OCCTSelectorPickedSubShapeType(OCCTSelectorRef, int32_t rank);
int32_t OCCTSelectorPickedSubShapeIndex(OCCTSelectorRef, int32_t rank);
void    OCCTSelectorPickedPoint(OCCTSelectorRef, int32_t rank, double* outXYZ);
double  OCCTSelectorPickedDepth(OCCTSelectorRef, int32_t rank);

// Pixel tolerance for picking near edges/vertices
void OCCTSelectorSetPixelTolerance(OCCTSelectorRef, int32_t tolerance);
```

### Swift API Shape

```swift
public final class Selector: @unchecked Sendable {
    internal let handle: OCCTSelectorRef

    public func add(_ shape: Shape, id: Int)
    public func remove(id: Int)

    public func activateMode(_ mode: SelectionMode, for shapeId: Int)
    public func deactivateMode(_ mode: SelectionMode, for shapeId: Int)

    public func pick(
        at pixel: SIMD2<Int>,
        camera: Camera,
        viewSize: SIMD2<Int>
    ) -> [PickResult]

    public func pick(
        rect: (min: SIMD2<Int>, max: SIMD2<Int>),
        camera: Camera,
        viewSize: SIMD2<Int>
    ) -> [PickResult]

    public func pick(
        polygon: [SIMD2<Int>],
        camera: Camera,
        viewSize: SIMD2<Int>
    ) -> [PickResult]

    public var pixelTolerance: Int
}

public enum SelectionMode: Int32 {
    case shape = 0
    case vertex = 1
    case edge = 2
    case wire = 3
    case face = 4
}

public struct PickResult: Sendable {
    public let shapeId: Int
    public let subShapeType: SelectionMode
    public let subShapeIndex: Int
    public let point: SIMD3<Double>
    public let depth: Double
}
```

### Complexity

High. The main challenges:
1. `SelectMgr_SelectableObject` inheritance from `PrsMgr_PresentableObject`
   (structural coupling, manageable by leaving presentation methods empty)
2. Memory management of selectable objects (must outlive selection results)
3. Mode activation/deactivation lifecycle
4. BVH thread pool configuration for background builds

### Apple Silicon Consideration

The BVH traversal is CPU-bound. Apple Silicon big cores handle this well for
interactive rates. For massive assemblies (100K+ parts):
- `SelectMgr_BVHThreadPool` supports background BVH builds
- BVH persists across frames (frustum is transformed, not entities)
- Consider dispatching BVH builds to performance cores via GCD

---

## Phase 4: GPU-Accelerated Selection (Hybrid)

### What

Complement OCCT's CPU selection with GPU-based picking via Metal's TBDR
imageblock architecture.

### Why After Phase 3

Phase 3 gives you correct, full-featured selection. Phase 4 optimizes the
hot path (single-click picking) using hardware while keeping OCCT SelectMgr
for complex operations.

### Technique: Imageblock Pick ID Buffer

During the main render pass, the fragment shader writes both color AND a
pick ID into an imageblock:

```metal
struct FragmentOut {
    float4 color  [[color(0)]];
    uint   pickId [[color(1)]];  // R32Uint attachment
};

fragment FragmentOut fragmentShader(...,
    constant uint& objectId [[buffer(2)]],
    constant uint& faceIndex [[buffer(3)]]) {
    FragmentOut out;
    out.color = shadedColor;
    out.pickId = objectId | (faceIndex << 16);
    return out;
}
```

On Apple Silicon TBDR, the pick ID attachment lives in tile memory and only
writes to DRAM for pixels you actually read. For a single click, you read
back 1 pixel. Cost: effectively zero.

### When to Use Which Technique

| Operation | GPU Pick (Phase 4) | OCCT SelectMgr (Phase 3) |
|---|---|---|
| Single click -> face | Instant (1px readback) | Backup / validation |
| Single click -> edge/vertex | Needs edge rendering pass | Native support via modes |
| Rubber-band select | Cast rays for region | Native rectangle pick |
| Lasso select | Not practical | Native polyline pick |
| Through-selection (X-ray) | Metal ray tracing (all hits) | Not directly supported |
| Precise UV on surface | N/A | Use existing `raycast()` |

### Metal Ray Tracing for Through-Selection (M3+ Hardware)

Build acceleration structures from mesh data for through-selection and AO:

```
MTLAccelerationStructure (built from mesh vertex/index buffers)
    |
    v  on click, dispatch compute kernel
Intersection query: ray from camera through click point
    |
    v
All hits returned (not just front-most)
    |
    v
Map primitive index -> Triangle.faceIndex -> B-Rep face
```

Hardware ray tracing on M3/A17 Pro+. Software fallback on M1/M2 (functional
but slower).

### Complexity

Medium for the imageblock approach. High for Metal ray tracing integration.

---

## Phase 5: Clipping and Section Views

### What

Wrap `Graphic3d_ClipPlane` and implement capping (cross-section fill) in Metal.

### Clip Plane Data

Pure math, no GL deps:
- Plane equation: `Ax + By + Cz + D = 0` (`Graphic3d_Vec4d`)
- Culling tests: `ProbePoint()`, `ProbeBox()`, `ProbeBoxHalfspace()`
- Plane chains: logical AND combinations for complex clipping regions
- Capping appearance: material, texture, hatch style

### Metal Implementation

**Clipping**: Use `[[clip_distance]]` in the vertex shader. Apple Silicon
supports up to 8 hardware-accelerated clip distances.

```metal
struct VertexOut {
    float4 position [[position]];
    float  clipDist [[clip_distance]] [1];  // up to 8
};

vertex VertexOut vertexShader(...) {
    VertexOut out;
    out.position = ...;
    out.clipDist[0] = dot(clipPlane.xyz, worldPos.xyz) + clipPlane.w;
    return out;
}
```

**Capping** (cross-section fill): Stencil buffer technique:
1. Render back faces with stencil increment
2. Render front faces with stencil decrement
3. Fill where stencil != 0 with capping material

### Complexity

Medium for clipping (straightforward plane math + vertex shader output).
High for capping with correct materials and edge rendering.

---

## Phase 6: Z-Layers and Display Management

### What

Wrap `Graphic3d_ZLayerSettings` for render ordering. Build a scene graph
tracking per-object visibility, highlight state, and display mode.

### Predefined Layers

```
Graphic3d_ZLayerId_BotOSD   = -5  // 2D underlay
Graphic3d_ZLayerId_Default  =  0  // main 3D scene
Graphic3d_ZLayerId_Top      = -2  // 3D overlay (inherits depth)
Graphic3d_ZLayerId_Topmost  = -3  // 3D overlay (independent depth)
Graphic3d_ZLayerId_TopOSD   = -4  // 2D overlay (annotations, UI)
```

### Metal Mapping

| Layer Concept | Metal Implementation |
|---|---|
| Layer ordering | Multiple render passes or ordered draw call submission |
| `ToClearDepth()` | `loadAction = .clear` on depth attachment |
| `ToEnableDepthTest/Write` | `MTLDepthStencilDescriptor` per layer |
| `PolygonOffset` | `setDepthBias()` on render encoder |
| Per-layer lights | Different uniform buffers per layer |
| OSD layers | 2D overlay pass with orthographic projection |

### Complexity

Medium. Mostly render pass organization and state management.

---

## Future Phases (Post-Core)

### Indirect Command Buffers for Large Assemblies

GPU-driven visibility culling. A compute kernel tests each object's bounding
box against the frustum and encodes draw commands into an ICB. The CPU
submits the ICB and waits. Eliminates the CPU bottleneck for assemblies with
thousands of parts.

Requires: Apple A12+ / Mac2 family for GPU-encoded ICBs.

### Mesh Shaders (M3+ Native)

Per-meshlet frustum culling, normal cone backface culling, and adaptive
tessellation in a single render pass. Pre-split geometry into meshlets
(64 vertices, 126 primitives each). Object shader culls meshlets, mesh
shader generates visible geometry.

Requires: Apple8+ (A17 Pro / M3) for native hardware acceleration.
Emulated on M1/M2 via Apple7.

### MetalFX Temporal Upscaling

Render at 50-75% resolution during orbit/pan/zoom. MetalFX accumulates
sub-pixel samples across frames. Motion vectors from camera transform are
trivial for rigid CAD geometry. At rest, temporal accumulation converges to
a progressively refined image.

### Argument Buffers / Bindless Resources

Single bind point for all assembly materials. Combined with ICBs, the GPU
culling kernel can reference any material/mesh combination without CPU
rebinding. Metal 3 eliminated the need for `MTLArgumentEncoder`.

### Order-Independent Transparency (TBDR Imageblocks)

Multi-layer alpha blending in tile memory for ghost/X-ray CAD views.
Tile shader sorts and composites transparency layers entirely in tile
memory. No per-pixel linked lists in system memory.

---

## Apple Silicon Hardware Acceleration Summary

| Metal Feature | Phase | Benefit for CAD |
|---|---|---|
| Unified memory (`.storageModeShared`) | 2 | Zero-copy OCCT tessellation -> GPU vertex buffers |
| TBDR imageblocks | 4 | Free pick-ID buffer as byproduct of rendering |
| `[[clip_distance]]` | 5 | Hardware-accelerated section planes (up to 8) |
| Indirect Command Buffers | Future | GPU-driven culling for large assemblies |
| Mesh shaders (M3+) | Future | Per-meshlet culling, adaptive tessellation |
| Metal ray tracing (M3+ HW) | 4 | Through-selection, AO, shadows |
| MetalFX temporal upscaling | Future | Reduced resolution during interaction |
| Argument buffers / bindless | Future | Single bind for all assembly materials |

---

## Recommended Implementation Order

The fastest path to interactive selection:

**Start with Phase 1 + Phase 3 together.** Camera wrapping is small and
selection depends on it. Once Camera exists, you can feed SelectMgr the
matrices from your Metal view and get pick results back immediately. This
gets click-to-select-face working with the existing Metal viewport.

**Phase 2 in parallel** if bandwidth allows. The improved vertex extraction
pays off for render quality but does not block selection.

**Phase 4 after you have a working viewport.** The GPU pick optimization
only matters once you're rendering to Metal and can add the pick-ID
attachment.

**Phases 5-6** as needed for production CAD viewport features.

---

## Evaluated Alternative: V3d on Metal (Full AIS/V3d Stack)

We evaluated whether to wrap V3d and have it render via Metal for a "purer"
OCCT experience where the full AIS stack works out of the box. Three options
were considered.

### Option A: Write a Metal Graphic3d_GraphicDriver

To run V3d on Metal natively, you implement a Metal rendering backend by
subclassing OCCT's abstract graphics interfaces:

| Abstract Class | Methods | OpenGL Impl Reference |
|---|---|---|
| `Graphic3d_GraphicDriver` | ~15 | ~1,500 lines |
| `Graphic3d_CView` (`OpenGl_View`) | ~30+ incl. `Redraw()` | ~3,000 lines |
| `Graphic3d_CStructure` (`OpenGl_Structure`) | ~10 | ~800 lines |
| `Graphic3d_CGroup` (`OpenGl_Group`) | ~10 | ~1,200 lines |
| Shader manager | compilation/linking | ~4,000 lines + all GLSL |
| FBO, VBO, textures, fonts, state | various | ~5,000+ lines |

Total: ~20,000-30,000 lines of Metal rendering code replacing OpenGL, plus
porting all GLSL shaders to Metal Shading Language. OCCT's ray tracer is
another ~10,000 lines of GLSL compute shaders.

The fundamental problem is OCCT's rendering is designed around OpenGL's state
machine model (bind texture, set uniform, draw, bind next texture...). Metal
uses pre-compiled pipeline states, command buffers, and render pass descriptors.
It is not a 1:1 translation -- it is a full reimplementation.

No one has done this for any non-GL backend. Not Metal, not Vulkan. The
D3DHost driver in OCCT is just an interop layer that still renders via OpenGL
into a shared GL/D3D surface.

**Verdict**: Multi-person-year project. Not practical for our scope.

### Option B: Use OCCT's OpenGL Driver on macOS (Deprecated but Functional)

Apple deprecated OpenGL in 2018 but it still functions on macOS. The system
translates GL calls to Metal internally. OCCT's `OpenGl_GraphicDriver` works
today:

```cpp
Handle(Aspect_DisplayConnection) display = new Aspect_DisplayConnection();
Handle(OpenGl_GraphicDriver) driver = new OpenGl_GraphicDriver(display);
Handle(V3d_Viewer) viewer = new V3d_Viewer(driver);
Handle(V3d_View) view = new V3d_View(viewer);
// attach to NSOpenGLView, render via AIS_InteractiveContext
```

This gives the full AIS experience: highlighting, selection, display modes,
dimensions, everything.

**Limitations**:
- macOS only (no iOS -- OpenGL ES on iOS is also deprecated and more limited)
- Stuck at OpenGL 4.1 (Apple's last supported version, from 2010)
- Performance ceiling from Apple's GL-to-Metal translation layer
- No access to Apple Silicon features (mesh shaders, ray tracing, MetalFX,
  TBDR imageblocks, indirect command buffers)
- Will eventually be removed from macOS

**Verdict**: Works today. Useful as a development/validation reference during
Phase 3 to verify SelectMgr wrapping produces identical pick results to the
full AIS stack. Not a production path.

### Option C: Extract Data + Render with Metal (This Plan)

Use OCCT for what it is uniquely good at (geometry kernel, selection math,
tessellation, shape analysis) and render with Metal directly:

```
OCCT side (C++):            Metal side (Swift):
  Graphic3d_Camera      ->    simd_float4x4 uniforms
  StdPrs vertex data    ->    MTLBuffer (zero-copy on Apple Silicon)
  SelectMgr picking     ->    PickResult structs
  Prs3d_Drawer attrs    ->    Pipeline state config
                               TBDR imageblock pick IDs
                               Mesh shaders, ICBs, MetalFX
                               Highlighting via shader uniforms
```

### What Full AIS/V3d Buys vs What It Costs

| Feature | Full AIS/V3d (Option B) | Extract + Metal (Option C) |
|---|---|---|
| Click-to-pick face/edge/vertex | `MoveTo()` | SelectMgr directly (same algorithm) |
| Rubber-band / lasso selection | `Select()` | SelectMgr directly (same algorithm) |
| Highlight on hover | Automatic (GL shading) | ~10 lines: set uniform per object |
| Selection schemes (Add/Replace/XOR) | `AIS_InteractiveContext::Select()` | ~20 lines of Swift on `Set<Int>` |
| Display modes (wireframe/shaded) | `SetDisplayMode()` | Render pass config in Metal |
| Transparency | GL alpha blending | OIT via TBDR imageblocks (better) |
| Clipping planes | `V3d_View::AddClipPlane()` | `[[clip_distance]]` (hardware, 8 planes) |
| Dimensions/annotations | `PrsDim_*` classes | SwiftUI/Metal (more flexible) |
| iOS support | **No** | **Yes** |
| Apple Silicon GPU features | **No** | **Full access** |
| Mesh shaders, MetalFX, RT | **No** | **Yes** |
| Large assembly perf | GL translation overhead | GPU-driven pipeline (ICBs) |

The selection algorithm -- the complex, high-value part -- is identical in
both paths. It is the same `SelectMgr_ViewerSelector::TraverseSensitives()`
running the same 3-level BVH. The difference is only what feeds it camera
data and what you do with the results.

### Decision

**Option C (extract + Metal) for production.** The things AIS automates
(highlighting, selection state, display modes) are genuinely trivial in Swift
compared to the selection algorithm itself, which we get either way via
SelectMgr.

**Option B (OpenGL V3d) as a validation tool** during development. Stand up a
simple NSOpenGLView with full AIS to verify SelectMgr wrapping produces the
same pick results. Discard when Phase 3 is validated.

---

## Why AIS Is Not Wrapped Directly

AIS_InteractiveContext does not implement selection -- it delegates to
SelectMgr, which does all the actual work. AIS bundles three concerns:

1. **Presentation** (via `PrsMgr_PresentationManager`) -- display in GL viewer
2. **Selection** (via `SelectMgr_SelectionManager` + `SelectMgr_ViewerSelector`)
3. **State management** -- selected set, highlight, filters, selection schemes

What `AIS_InteractiveContext::MoveTo()` actually does:

```
MoveTo(pixelX, pixelY, view)
  -> myMainSel->Pick(x, y, view)      // SelectMgr does all the real work
  -> highlight the detected owner       // needs PrsMgr + GL structures
```

AIS has hard dependencies on the GL stack:

| AIS Feature | Hard Dependency | Issue |
|---|---|---|
| Constructor | `V3d_Viewer` | Cannot create without an OCCT GL viewer |
| `MoveTo()` / `Select()` | `V3d_View` parameter | Needs an active GL view |
| Highlighting | `PrsMgr_PresentationManager` | Modifies GL display structures |
| `Display()` / `Erase()` | `Graphic3d_Structure` | Scene graph tied to GL driver |
| `AIS_InteractiveObject` | Inherits both display + selection | Cannot separate |

**What AIS provides on top of SelectMgr that we reimplement in Swift:**

| AIS Feature | Swift Replacement |
|---|---|
| Selection schemes (Replace, Add, XOR) | ~20 lines of Swift logic on `Set<Int>` |
| Selected object tracking | `Set<Int>` of selected shape IDs |
| Highlighting on hover/select | Metal shader uniform (highlight flag per object) |
| Filter chains | `SelectMgr_Filter` works without AIS |
| Pixel tolerance | `SelectMgr_ViewerSelector::SetPixelTolerance()` |
| Selection mode activation | `SelectMgr_SelectionManager::Activate()` directly |

The selection algorithm (BVH construction, frustum intersection, sensitive
entity decomposition, depth sorting, priority resolution) is entirely in
SelectMgr. Since we have our own Metal viewer, we wrap SelectMgr directly.

## Other OCCT Classes Not Being Wrapped

| Class | Reason |
|---|---|
| `V3d_Viewer` / `V3d_View` | OpenGL viewport management; Metal replaces this (see evaluation above) |
| `Graphic3d_GraphicDriver` / `OpenGl_*` | Full OpenGL rendering stack; not reimplementing for Metal (see evaluation above) |
| `PrsMgr_PresentationManager` | Manages display of presentations via GL structures; not needed for data extraction |
| `Graphic3d_Structure` / `Graphic3d_CStructure` | Scene graph nodes tied to GL driver; we build our own Metal scene graph |
| `MeshVS_Mesh` | Dedicated mesh visualization object for OCCT viewer; we render meshes directly |
| `PrsDim_*` / `DsgPrs_*` | Dimension/annotation rendering via OCCT viewer; implement in Metal/SwiftUI instead |

---

## References

- OCCT Visualization User Guide: https://dev.opencascade.org/doc/overview/html/occt_user_guides__visualization.html
- IVtkOCC_ViewerSelector source (proof of GL-free selection): `src/Visualization/TKIVtk/IVtkOCC/`
- WWDC22 "Transform your geometry with Metal mesh shaders"
- WWDC22 "Go bindless with Metal 3"
- WWDC22 "Boost performance with MetalFX Upscaling"
- WWDC19 "Modern Rendering with Metal" (ICBs)
- Apple "Tailor your apps for Apple GPUs and TBDR"
- Apple "Implementing Order-Independent Transparency with Image Blocks"
- Metal Feature Set Tables: https://developer.apple.com/metal/Metal-Feature-Set-Tables.pdf
