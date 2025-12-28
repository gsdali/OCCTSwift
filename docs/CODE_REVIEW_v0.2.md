# OCCTSwift v0.2 Code Review

**Date:** 2025-12-29
**Reviewer:** Claude (Opus 4.5)
**Commits Reviewed:** `9169894`, `b069e9a`
**Base:** v0.1.0 (`0491ad7`)

---

## Summary

Two commits added CAM-oriented functionality (likely for PadCAM project). The changes are well-structured, follow established patterns, and are backwards compatible.

**Verdict: APPROVED** - Ready to tag as v0.2.0 after addressing minor documentation items.

---

## New Functions Added

### Commit 1: `9169894` - STEP import, bounds, cylinderAt, toolSweep

| C Function | Swift API | Purpose |
|------------|-----------|---------|
| `OCCTImportSTEP` | `Shape.load(from:)` | Import STEP files |
| `OCCTShapeGetBounds` | `shape.bounds` | Axis-aligned bounding box |
| `OCCTShapeCreateCylinderAt` | `Shape.cylinder(at:bottomZ:radius:height:)` | Positioned cylinder |
| `OCCTShapeCreateToolSweep` | `Shape.toolSweep(radius:height:from:to:)` | CAM tool movement volume |

### Commit 2: `b069e9a` - Slicing and contour extraction

| C Function | Swift API | Purpose |
|------------|-----------|---------|
| `OCCTShapeSliceAtZ` | `shape.sliceAtZ(_:)` | Cross-section at Z plane |
| `OCCTShapeGetEdgeCount` | `shape.edgeCount` | Count edges in shape |
| `OCCTShapeGetEdgePoints` | `shape.edgePoints(at:maxPoints:)` | Sample points along edge curve |
| `OCCTShapeGetContourPoints` | `shape.contourPoints(maxPoints:)` | Get edge start vertices |

---

## Code Quality: What's Good

1. **Follows bridge pattern** - All new functions properly implement:
   - C declaration in `OCCTBridge.h`
   - Obj-C++ implementation in `OCCTBridge.mm`
   - Swift wrapper in `Shape.swift`

2. **Proper error handling** - All C++ code wrapped in try/catch:
   ```cpp
   try {
       // OCCT operations
   } catch (...) {
       return nullptr;  // or 0 for counts
   }
   ```

3. **Null checks** - Entry points validate parameters:
   ```cpp
   if (!shape || !outPoints || maxPoints < 1) return 0;
   ```

4. **Clean Swift API** - Uses SIMD3 types consistently:
   ```swift
   public var bounds: (min: SIMD3<Double>, max: SIMD3<Double>)
   public var center: SIMD3<Double>
   ```

5. **Builds and tests pass** - `swift build` and `swift run OCCTTest` succeed.

---

## Minor Issues to Address

### Issue 1: `toolSweep` Implementation Approach

**Location:** `OCCTBridge.mm:153-254`

**Current approach:** Creates two cylinders + connecting extruded box, then unions them.

**Concern:** This is a geometric approximation. For a true swept solid, OCCT provides `BRepOffsetAPI_MakePipeShell` which sweeps a profile along a path.

**Impact:** Low - current approach works for CAM collision detection. The approximation is conservative (slightly larger than true swept volume).

**Recommendation:** Document this as intentional approximation in comments:
```cpp
// Note: This creates an approximation of the swept volume using
// two cylinders connected by a box. For CAM purposes, this provides
// a conservative (larger) estimate suitable for collision detection.
// A true swept solid could use BRepOffsetAPI_MakePipeShell.
```

**Action Required:** Optional - add clarifying comment.

---

### Issue 2: Edge Point Sampling Hardcoded Limit

**Location:** `OCCTBridge.mm:969`

```cpp
int32_t numPoints = std::min(maxPoints, (int32_t)20);  // Max 20 points per edge
```

**Concern:** The `20` limit is hardcoded and may truncate curves that need more points.

**Impact:** Medium for curved edges - a 90° arc with only 20 points has ~4.7° per segment.

**Recommendation:** Either:
1. Remove the `20` limit and trust `maxPoints` parameter, OR
2. Document the limit in Swift wrapper:
   ```swift
   /// Get points along an edge at the given index
   /// - Parameter maxPoints: Maximum points to return (capped at 20 internally)
   public func edgePoints(at index: Int, maxPoints: Int = 20) -> [SIMD3<Double>]
   ```

**Action Required:** Update documentation or remove hardcoded limit.

---

### Issue 3: `contourPoints` Only Gets Start Vertices

**Location:** `OCCTBridge.mm:995-1027`

**Current behavior:** Only extracts the start vertex of each edge:
```cpp
TopExp::Vertices(edge, v1, v2);
if (!v1.IsNull()) {
    // Only uses v1, ignores v2
}
```

**Concern:** For shapes with curved edges, this misses the curve geometry entirely. You get corner points only.

**Impact:** Low for CAM use case where slices are typically simple polygons. Higher impact if used for curved contours.

**Recommendation:** Document the limitation:
```swift
/// Get all contour points from the shape's edges.
///
/// Note: This returns edge START vertices only, not intermediate curve points.
/// For curved edges, use `edgePoints(at:maxPoints:)` to get curve samples.
///
/// This is suitable for simple polygon contours from Z-plane slices.
public func contourPoints(maxPoints: Int = 1000) -> [SIMD3<Double>]
```

**Action Required:** Add documentation clarifying behavior.

---

### Issue 4: README Not Updated

**Location:** `README.md`

**Current state:** README still shows v0.1.0 function count (34 operations).

**Required updates:**

1. Update the summary table:
```markdown
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
```

2. Add new sections to API Reference for:
   - Import
   - Bounds
   - Slicing/Contours
   - CAM operations

**Action Required:** Update README.md before tagging v0.2.0.

---

### Issue 5: No v0.2.0 Tag

**Current state:** Only `v0.1.0` tag exists.

**Required:**
```bash
git tag -a v0.2.0 -m "v0.2.0 - Add STEP import, bounds, slicing, and CAM functions

New features:
- STEP file import: Shape.load(from:)
- Bounding box: shape.bounds, size, center
- Z-plane slicing: shape.sliceAtZ(_:)
- Contour extraction: edgeCount, edgePoints, contourPoints
- CAM support: cylinder(at:), toolSweep()

Total wrapped operations: 44 (was 34)"

git push origin v0.2.0
```

**Action Required:** Create and push tag after README update.

---

## Files Changed

```
Sources/OCCTBridge/include/OCCTBridge.h  |  17 +++
Sources/OCCTBridge/src/OCCTBridge.mm     | 247 ++++++++++++++++++++++++++++
Sources/OCCTSwift/Shape.swift            | 118 +++++++++++++++
```

---

## OCCT Classes Used in New Code

| New Function | OCCT Classes |
|--------------|--------------|
| `OCCTImportSTEP` | `STEPControl_Reader` |
| `OCCTShapeGetBounds` | `Bnd_Box`, `BRepBndLib` |
| `OCCTShapeCreateCylinderAt` | `BRepPrimAPI_MakeCylinder`, `gp_Ax2` |
| `OCCTShapeCreateToolSweep` | `BRepPrimAPI_MakeCylinder`, `BRepAlgoAPI_Fuse`, `BRepPrimAPI_MakePrism` |
| `OCCTShapeSliceAtZ` | `BRepAlgoAPI_Section`, `gp_Pln` |
| `OCCTShapeGetEdgeCount` | `TopExp_Explorer` |
| `OCCTShapeGetEdgePoints` | `BRep_Tool::Curve`, `Geom_Curve` |
| `OCCTShapeGetContourPoints` | `TopExp::Vertices`, `BRep_Tool::Pnt` |

---

## Backwards Compatibility

**Status: FULLY COMPATIBLE**

- No existing functions modified
- No signatures changed
- RailwayCAD will work without changes
- New functions are additive only

---

## Test Coverage

**Current:** `OCCTTest/main.swift` does not test new functions.

**Recommended additions:**
```swift
// Test STEP import
print("7. STEP import...")
// Need a test STEP file

// Test bounds
print("8. Bounding box...")
let box = Shape.box(width: 10, height: 20, depth: 30)
let bounds = box.bounds
print("   - Bounds: \(bounds.min) to \(bounds.max)")
print("   - Size: \(box.size)")
print("   - Center: \(box.center)")

// Test slicing
print("9. Z-plane slicing...")
let slice = box.sliceAtZ(10.0)
print("   - Slice edges: \(slice?.edgeCount ?? 0)")

// Test toolSweep
print("10. Tool sweep...")
let sweep = Shape.toolSweep(
    radius: 3.0,
    height: 10.0,
    from: SIMD3(0, 0, 0),
    to: SIMD3(50, 0, 0)
)
print("   - Tool sweep: \(sweep.isValid ? "valid" : "invalid")")
```

---

## Checklist Before v0.2.0 Release

- [ ] Add clarifying comment to `toolSweep` implementation (optional)
- [ ] Document 20-point limit in `edgePoints` or remove limit
- [ ] Document `contourPoints` returns start vertices only
- [ ] Update README.md with new operations table
- [ ] Update README.md API reference with new sections
- [ ] Add test coverage for new functions (optional)
- [ ] Create and push v0.2.0 tag

---

## For Future Claude Sessions

When continuing work on OCCTSwift:

1. **Read this file first** to understand recent changes
2. **Check git log** for any commits after this review
3. **Run `swift run OCCTTest`** to verify everything works
4. **Update EXTENDING.md** if adding new OCCT classes

The codebase is in good shape. The bridge pattern is well-established and easy to extend.
