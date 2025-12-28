# Extending OCCTSwift: Adding New OCCT Functions

This guide explains how to add new OpenCASCADE (OCCT) functions to OCCTSwift. The bridge architecture requires changes in three layers.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         Swift Layer                              │
│  Sources/OCCTSwift/Shape.swift, Wire.swift, Mesh.swift          │
│  - Public Swift API                                              │
│  - Type-safe, Swifty interface                                   │
│  - Memory management via deinit                                  │
└────────────────────────────┬────────────────────────────────────┘
                             │ calls
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Bridge Layer (C API)                        │
│  Sources/OCCTBridge/include/OCCTBridge.h                        │
│  - C function declarations                                       │
│  - Opaque handle types (OCCTShapeRef, OCCTWireRef, etc.)        │
│  - extern "C" for C++ compatibility                              │
└────────────────────────────┬────────────────────────────────────┘
                             │ implements
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Implementation Layer                          │
│  Sources/OCCTBridge/src/OCCTBridge.mm                           │
│  - Objective-C++ (.mm) for C++/ObjC interop                     │
│  - Direct OCCT C++ API calls                                     │
│  - Error handling with try/catch                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Step-by-Step: Adding a New Function

### Example: Adding `BRepGProp::VolumeProperties` (shape volume calculation)

We want to add: `shape.volume() -> Double`

---

### Step 1: Add C Function Declaration

**File:** `Sources/OCCTBridge/include/OCCTBridge.h`

Add the function declaration inside the `extern "C"` block:

```c
// MARK: - Measurements (add new section or find appropriate existing one)

/// Calculate the volume of a solid shape
/// @param shape The shape to measure
/// @return Volume in cubic units, or -1.0 if calculation fails
double OCCTShapeGetVolume(OCCTShapeRef shape);
```

**Key points:**
- Use C types only (`double`, `int32_t`, `bool`, `const char*`)
- Opaque pointer types for OCCT objects (`OCCTShapeRef`, `OCCTWireRef`)
- Return simple types; use out-parameters for complex returns
- Document with `///` comments

---

### Step 2: Implement in Objective-C++

**File:** `Sources/OCCTBridge/src/OCCTBridge.mm`

First, add the required OCCT header at the top (if not already present):

```cpp
// Near the top with other includes
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
```

Then implement the function:

```cpp
// MARK: - Measurements

double OCCTShapeGetVolume(OCCTShapeRef shape) {
    if (!shape) return -1.0;

    try {
        GProp_GProps props;
        BRepGProp::VolumeProperties(shape->shape, props);
        return props.Mass();  // "Mass" is volume for uniform density
    } catch (...) {
        return -1.0;
    }
}
```

**Key patterns:**

1. **Null check first:** `if (!shape) return ...;`

2. **Wrap in try/catch:** OCCT can throw exceptions
   ```cpp
   try {
       // OCCT calls
   } catch (...) {
       return nullptr;  // or appropriate error value
   }
   ```

3. **Access the underlying OCCT object:** `shape->shape` (see internal structs)

4. **Return new allocated objects for shapes:**
   ```cpp
   return new OCCTShape(maker.Shape());
   ```

5. **Check IsDone() for builder operations:**
   ```cpp
   maker.Build();
   if (!maker.IsDone()) return nullptr;
   ```

---

### Step 3: Add Swift Wrapper

**File:** `Sources/OCCTSwift/Shape.swift`

```swift
// MARK: - Measurements

extension Shape {
    /// Calculate the volume of this solid shape
    ///
    /// - Returns: Volume in cubic units (mm³ if modeling in mm)
    ///
    /// ## Example
    /// ```swift
    /// let box = Shape.box(width: 10, height: 10, depth: 10)
    /// print(box.volume)  // 1000.0
    /// ```
    public var volume: Double {
        let result = OCCTShapeGetVolume(handle)
        return result >= 0 ? result : 0
    }
}
```

**Key patterns:**

1. **Import OCCTBridge** at top of file (already there)

2. **Use computed properties for simple getters:**
   ```swift
   public var volume: Double { OCCTShapeGetVolume(handle) }
   ```

3. **Use methods for operations that create new shapes:**
   ```swift
   public func someOperation() -> Shape {
       let handle = OCCTSomeOperation(self.handle)
       return Shape(handle: handle!)
   }
   ```

4. **Handle arrays with withUnsafeBufferPointer:**
   ```swift
   public static func compound(_ shapes: [Shape]) -> Shape {
       let handles: [OCCTShapeRef?] = shapes.map { $0.handle }
       let handle = handles.withUnsafeBufferPointer { buffer in
           OCCTShapeCreateCompound(buffer.baseAddress, Int32(shapes.count))
       }
       return Shape(handle: handle!)
   }
   ```

5. **Add documentation with examples**

---

## Common OCCT Patterns

### Creating Primitives

```cpp
// Header
OCCTShapeRef OCCTShapeCreateWedge(double dx, double dy, double dz, double ltx);

// Implementation
OCCTShapeRef OCCTShapeCreateWedge(double dx, double dy, double dz, double ltx) {
    try {
        BRepPrimAPI_MakeWedge maker(dx, dy, dz, ltx);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}
```

### Boolean Operations

```cpp
OCCTShapeRef OCCTShapeSection(OCCTShapeRef shape1, OCCTShapeRef shape2) {
    if (!shape1 || !shape2) return nullptr;
    try {
        BRepAlgoAPI_Section sectioner(shape1->shape, shape2->shape);
        sectioner.Build();
        if (!sectioner.IsDone()) return nullptr;
        return new OCCTShape(sectioner.Shape());
    } catch (...) {
        return nullptr;
    }
}
```

### Iterating Over Topology

```cpp
// Count faces in a shape
int32_t OCCTShapeCountFaces(OCCTShapeRef shape) {
    if (!shape) return 0;
    try {
        int32_t count = 0;
        TopExp_Explorer explorer(shape->shape, TopAbs_FACE);
        while (explorer.More()) {
            count++;
            explorer.Next();
        }
        return count;
    } catch (...) {
        return 0;
    }
}
```

### Working with Arrays (Input)

```cpp
// Header - arrays passed as pointer + count
OCCTShapeRef OCCTShapeCreateLoft(const OCCTWireRef* profiles, int32_t count, bool solid);

// Implementation
OCCTShapeRef OCCTShapeCreateLoft(const OCCTWireRef* profiles, int32_t count, bool solid) {
    if (!profiles || count < 2) return nullptr;
    try {
        BRepOffsetAPI_ThruSections maker(solid);
        for (int32_t i = 0; i < count; i++) {
            if (profiles[i]) {
                maker.AddWire(profiles[i]->wire);
            }
        }
        maker.Build();
        if (!maker.IsDone()) return nullptr;
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}
```

### Working with Arrays (Output)

```cpp
// Header - caller provides buffer
void OCCTMeshGetVertices(OCCTMeshRef mesh, float* outVertices);

// Implementation
void OCCTMeshGetVertices(OCCTMeshRef mesh, float* outVertices) {
    if (!mesh || !outVertices) return;
    std::copy(mesh->vertices.begin(), mesh->vertices.end(), outVertices);
}

// Swift usage - allocate buffer first
let count = OCCTMeshGetVertexCount(meshHandle)
var vertices = [Float](repeating: 0, count: Int(count) * 3)
vertices.withUnsafeMutableBufferPointer { buffer in
    OCCTMeshGetVertices(meshHandle, buffer.baseAddress)
}
```

---

## Internal Structures

The bridge uses opaque structs to wrap OCCT objects:

```cpp
// In OCCTBridge.mm

struct OCCTShape {
    TopoDS_Shape shape;
    OCCTShape() {}
    OCCTShape(const TopoDS_Shape& s) : shape(s) {}
};

struct OCCTWire {
    TopoDS_Wire wire;
    OCCTWire() {}
    OCCTWire(const TopoDS_Wire& w) : wire(w) {}
};

struct OCCTMesh {
    std::vector<float> vertices;
    std::vector<float> normals;
    std::vector<uint32_t> indices;
};
```

**Swift sees these as opaque pointers:**
```c
typedef struct OCCTShape* OCCTShapeRef;
typedef struct OCCTWire* OCCTWireRef;
typedef struct OCCTMesh* OCCTMeshRef;
```

---

## Memory Management

### Allocation
New objects are allocated with `new`:
```cpp
return new OCCTShape(maker.Shape());
```

### Deallocation
Release functions delete the objects:
```cpp
void OCCTShapeRelease(OCCTShapeRef shape) {
    delete shape;
}
```

### Swift Integration
Swift classes call release in `deinit`:
```swift
public final class Shape {
    internal let handle: OCCTShapeRef

    deinit {
        OCCTShapeRelease(handle)
    }
}
```

---

## Testing New Functions

Add tests in `Sources/OCCTTest/main.swift`:

```swift
// Test volume calculation
let box = Shape.box(width: 10, height: 10, depth: 10)
let volume = box.volume
assert(abs(volume - 1000.0) < 0.001, "Volume should be 1000")
print("✓ Volume calculation: \(volume)")
```

Run with:
```bash
swift run OCCTTest
```

---

## OCCT Class Reference

Common OCCT classes you might wrap:

| Category | OCCT Class | Purpose |
|----------|------------|---------|
| Primitives | `BRepPrimAPI_MakeWedge` | Wedge/ramp shape |
| Primitives | `BRepPrimAPI_MakeHalfSpace` | Half-space solid |
| Booleans | `BRepAlgoAPI_Section` | Intersection curves |
| Booleans | `BRepAlgoAPI_Splitter` | Split by tools |
| Features | `BRepOffsetAPI_DraftAngle` | Add draft to faces |
| Features | `BRepFeat_MakePrism` | Boss/pocket features |
| Measurement | `BRepGProp::VolumeProperties` | Volume, center of mass |
| Measurement | `BRepGProp::SurfaceProperties` | Surface area |
| Topology | `TopExp_Explorer` | Iterate faces/edges/vertices |
| Import | `STEPControl_Reader` | Read STEP files |
| Import | `IGESControl_Reader` | Read IGES files |
| Healing | `ShapeUpgrade_UnifySameDomain` | Simplify topology |

---

## Debugging Tips

1. **Print OCCT errors:** Add `Standard_Failure::Caught()` handling
   ```cpp
   } catch (Standard_Failure& e) {
       printf("OCCT Error: %s\n", e.GetMessageString());
       return nullptr;
   }
   ```

2. **Visualize shapes:** Export to STL and view in a 3D viewer

3. **Check shape validity:**
   ```cpp
   BRepCheck_Analyzer analyzer(shape);
   if (!analyzer.IsValid()) { /* handle error */ }
   ```

4. **Use Xcode debugger:** Set breakpoints in .mm file, inspect OCCT objects
