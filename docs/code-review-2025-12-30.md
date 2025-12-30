# OCCTSwift Code Review - 2025-12-30

## Scope

Review of commits since v0.2.0 release:
- `1d41ab2` - Fix memory management bug in sectionWiresAtZ
- `aab5483` - Add CAM operations: Wire.offset() and Shape.sectionWiresAtZ()
- `fb06cab` - Add NURBS support and fix loft compatibility checking
- `83cb193` - Address code review items for v0.2.0

## Commit Reviews

### `1d41ab2` - Memory Management Fix

**Status: Approved**

Fixed a double-free bug in `sectionWiresAtZ`:

**Problem:**
```cpp
// OCCTFreeWireArray freed both wire handles AND array container
void OCCTFreeWireArray(OCCTWireRef* wires, int32_t count) {
    for (int32_t i = 0; i < count; i++) {
        delete wires[i];  // Deletes wire handle
    }
    delete[] wires;  // Deletes array
}
```

But Swift `Wire` objects take ownership of handles and release them in `deinit`:
```swift
deinit {
    OCCTWireRelease(handle)  // Also deletes wire handle -> DOUBLE FREE
}
```

**Solution:**
Added `OCCTFreeWireArrayOnly()` that only frees the array container:
```cpp
void OCCTFreeWireArrayOnly(OCCTWireRef* wires) {
    if (!wires) return;
    delete[] wires;  // Only delete array, not wire handles
}
```

Swift now uses this:
```swift
defer { OCCTFreeWireArrayOnly(wireArray) }
```

**Assessment:** Clean, minimal fix. Correctly delegates memory management to Swift ARC.

---

### `aab5483` - CAM Operations

**Status: Approved with suggestions**

Added two CAM operations for tool path generation.

#### `Wire.offset(by:joinType:)`

**Implementation:**
```cpp
OCCTWireRef OCCTWireOffset(OCCTWireRef wire, double distance, int32_t joinType) {
    // Create planar face from wire (required for BRepOffsetAPI_MakeOffset)
    BRepBuilderAPI_MakeFace faceMaker(theWire, Standard_True);

    // Select join type
    GeomAbs_JoinType join = (joinType == 0) ? GeomAbs_Arc : GeomAbs_Intersection;

    // Create offset
    BRepOffsetAPI_MakeOffset offsetMaker(face, join);
    offsetMaker.Perform(distance);

    // Extract first wire from result
    TopExp_Explorer explorer(result, TopAbs_WIRE);
    if (explorer.More()) {
        return new OCCTWire(TopoDS::Wire(explorer.Current()));
    }
    return nullptr;
}
```

**Strengths:**
- Proper use of `BRepOffsetAPI_MakeOffset`
- Good error handling with nullptr returns
- Supports both arc and intersection join types

**Suggestion:** Only returns first wire. For complex shapes with holes, multiple wires may result. Consider returning all wires or documenting this limitation.

#### `Shape.sectionWiresAtZ(_:)`

**Implementation:**
```cpp
OCCTWireRef* OCCTShapeSectionWiresAtZ(OCCTShapeRef shape, double z, int32_t* outCount) {
    // Create horizontal cutting plane
    gp_Pln plane(gp_Pnt(0, 0, z), gp_Dir(0, 0, 1));

    // Compute section
    BRepAlgoAPI_Section section(shape->shape, plane);

    // Collect edges
    Handle(TopTools_HSequenceOfShape) edges = new TopTools_HSequenceOfShape;
    TopExp_Explorer explorer(sectionShape, TopAbs_EDGE);
    while (explorer.More()) {
        edges->Append(explorer.Current());
        explorer.Next();
    }

    // Connect edges into wires
    Handle(TopTools_HSequenceOfShape) wires = new TopTools_HSequenceOfShape;
    ShapeAnalysis_FreeBounds::ConnectEdgesToWires(edges, 1e-6, Standard_False, wires);

    // Return array of wire handles
    ...
}
```

**Strengths:**
- Uses `BRepAlgoAPI_Section` correctly
- `ShapeAnalysis_FreeBounds::ConnectEdgesToWires` properly chains loose edges
- Returns empty array (not nil) on no results - good for optional chaining

**Suggestion:** Tolerance `1e-6` is hardcoded. Could be a parameter for edge cases with imprecise geometry.

---

### `fb06cab` - NURBS Support & Loft Fix

**Status: Approved**

#### NURBS Additions

Three new NURBS curve creation methods:

1. **`Wire.nurbs(poles:weights:knots:multiplicities:degree:)`** - Full control over all NURBS parameters
2. **`Wire.nurbsUniform(poles:weights:degree:)`** - Auto-generates clamped uniform knot vector
3. **`Wire.cubicBSpline(poles:)`** - Convenience for degree-3 B-splines (most common)

**Implementation quality:**
- Proper validation (`poles.count >= degree + 1`)
- Clean handling of optional weights/multiplicities
- Good documentation with examples

#### Loft Compatibility Fix

Added `CheckCompatibility(Standard_True)` to `BRepOffsetAPI_ThruSections`:

```cpp
BRepOffsetAPI_ThruSections maker(solid ? Standard_True : Standard_False);
maker.CheckCompatibility(Standard_True);  // NEW: prevents twisted surfaces
for (int32_t i = 0; i < count; i++) {
    maker.AddWire(profiles[i]->wire);
}
maker.Build();
```

**Important note from commit message:**
> Loft still creates B-spline surfaces that can extend beyond input profiles. For exact dimensions, use extrude-and-union instead.

This matches findings from PC sleeper geometry work - loft is not suitable for dimensionally accurate prismatic shapes.

---

### `83cb193` - Code Review Items

**Status: Approved**

Documentation improvements:
- Clarified `toolSweep` approximation approach
- Documented `edgePoints` 20-point internal cap
- Documented `contourPoints` returns start vertices only
- Updated README operations table (34 → 44 operations)

---

## Suggested Improvements

### Priority 1 (Should fix before release)

None - current code is release-ready.

### Priority 2 (Nice to have)

1. **Wire.offset returns only first wire**
   - Current: Returns first wire from offset result
   - Issue: Complex shapes with holes produce multiple wires
   - Suggestion: Either return array of wires, or document limitation

   ```swift
   // Option A: Return all wires
   public func offsetAll(by distance: Double, joinType: JoinType = .arc) -> [Wire]

   // Option B: Document current behavior
   /// - Note: For wires with holes, only the outer contour is returned.
   ```

2. **Hardcoded tolerance in sectionWiresAtZ**
   - Current: `1e-6` hardcoded
   - Suggestion: Add optional tolerance parameter

   ```swift
   public func sectionWiresAtZ(_ z: Double, tolerance: Double = 1e-6) -> [Wire]
   ```

### Priority 3 (Future consideration)

- Add `Wire.offsetAll()` that returns all resulting wires for complex profiles
- Add documentation explaining when to use loft vs extrude-union

---

## Release Recommendation

**Recommendation: Yes, release as v0.2.1**

Rationale:
1. Memory management fix (`1d41ab2`) is a critical bug fix
2. CAM operations are complete and tested
3. NURBS support adds significant capability
4. All new code has proper error handling and documentation
5. No breaking API changes

The Priority 2 suggestions are enhancements, not blockers. They can be addressed in a future v0.2.2 or v0.3.0.

**Suggested release notes:**

```markdown
## v0.2.1 - 2025-12-30

### Bug Fixes
- Fixed double-free crash in `sectionWiresAtZ` (memory management)

### New Features
- **CAM Operations**
  - `Wire.offset(by:joinType:)` - Offset planar wires for tool compensation
  - `Shape.sectionWiresAtZ(_:)` - Get closed wires from Z-level sections

- **NURBS Curves**
  - `Wire.nurbs(poles:weights:knots:multiplicities:degree:)` - Full NURBS control
  - `Wire.nurbsUniform(poles:weights:degree:)` - Simplified with auto knot vector
  - `Wire.cubicBSpline(poles:)` - Convenience for cubic B-splines

### Improvements
- Loft now calls `CheckCompatibility(true)` to prevent twisted surfaces
- Improved documentation for CAM operations
```

---

## Test Coverage

Current tests cover basic operations. Suggested additional tests for new features:

```swift
// Wire offset tests
func testOffsetRectangle() {
    let rect = Wire.rectangle(width: 20, height: 10)
    let offset = rect.offset(by: 2.0)
    XCTAssertNotNil(offset)
    // Verify dimensions increased by 2*offset
}

func testOffsetInward() {
    let rect = Wire.rectangle(width: 20, height: 10)
    let offset = rect.offset(by: -2.0)
    XCTAssertNotNil(offset)
    // Verify dimensions decreased
}

// Section wires tests
func testSectionWiresAtZ() {
    let box = Shape.box(width: 10, height: 10, depth: 10)
    let wires = box.sectionWiresAtZ(5.0)
    XCTAssertEqual(wires.count, 1)  // One rectangular contour
}

// NURBS tests
func testCubicBSpline() {
    let poles = [
        SIMD3(0, 0, 0),
        SIMD3(10, 5, 0),
        SIMD3(20, 0, 0),
        SIMD3(30, 5, 0)
    ]
    let spline = Wire.cubicBSpline(poles: poles)
    XCTAssertNotNil(spline)
}
```

---

*Review completed: 2025-12-30*
*Reviewer: Claude (via RailwayCAD project)*
