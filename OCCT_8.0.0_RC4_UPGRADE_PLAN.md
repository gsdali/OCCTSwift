# OCCT 8.0.0-rc4 Upgrade Plan

## Current State

- **Main branch**: v0.26.0, built on OCCT 8.0.0-rc3
- **574 tests passing**, 106 suites, 0 failures
- **150+ OCCT classes** wrapped across 13 Swift source files
- Build script: `Scripts/build-occt.sh` (builds iOS + macOS + Simulator xcframework)

## What Changed: rc3 → rc4 (111 improvements)

### Breaking Changes We Must Handle

| Change | Impact on OCCTSwift | Action |
|--------|---------------------|--------|
| `Standard_Failure::Raise()` removed | We use `catch(...)` everywhere, never call `Raise()` | **None — verify build** |
| `Geom_*` / `Geom2d_*` classes marked `final` | We don't subclass any | **None — verify build** |
| `NCollection_Map::Seek()`/`ChangeSeek()` removed | Already absent in rc3 | **None** |
| `TColgp_*`, `TColStd_*`, `TopTools_*` typedefs deprecated | We use ~15 of these | **Fix warnings (Phase 2)** |
| `Standard_Boolean/Integer/Real` → `bool/int/double` deprecated | We use `Standard_True/False` | **Fix warnings (Phase 2)** |
| BSpline `Weights()` nullable pattern → `WeightsArray()` | Check if we call `Weights()` | **Check and fix if needed** |
| BRepMesh plugin system replaced with registry factory | We use `BRepMesh_IncrementalMesh` directly | **None — verify build** |
| UNLIT shading implicit optimization removed | We don't use visualization shading | **None** |
| `Standard_Mutex` deprecated for `std::mutex` | We don't use it | **None** |

### New APIs Available in rc4 (Future Wrapping)

| New Feature | OCCT Classes | Potential Swift API |
|-------------|-------------|---------------------|
| Robin Hood hash maps | `NCollection_FlatDataMap`, `NCollection_FlatMap` | Internal perf improvement only |
| KD-Tree spatial queries | `NCollection_KDTree` | Point cloud nearest-neighbor |
| Insertion-order maps | `NCollection_OrderedMap`, `NCollection_OrderedDataMap` | Internal use |
| Batch 2D curve evaluation | `Geom2dGridEval` package | Faster curve discretization |
| Laguerre polynomial solver | `MathPoly_Laguerre` | Root-finding utilities |
| New geometry eval (EvalD0-D3) | `Geom_Curve::EvalD0()` etc. | Faster point evaluation |
| TopoDS_TShapeDispatch | std::visit-style type dispatch | Internal perf improvement |

### Performance Improvements (Automatic)

These are internal OCCT changes that benefit us without code changes:
- Devirtualized geometry evaluation on hot paths
- Direct array members in BSpline/Bezier (no heap indirection)
- Thread-local error handling (no mutex in parallel code)
- Contiguous TShape child storage (faster topology iteration)
- Cache-friendly matrix multiplication
- Optimized atomic reference counting

---

## Upgrade Phases

### Phase 0: Build rc4 xcframework

**Branch**: `feature/occt-8.0.0-rc4` (from main)

1. Update `Scripts/build-occt.sh`: change `OCCT_RC="rc3"` → `OCCT_RC="rc4"`
2. Remove existing source and build artifacts:
   ```bash
   cd Libraries
   rm -rf occt-src occt-build-* occt-install-*
   ```
3. Run the build script:
   ```bash
   cd Scripts && ./build-occt.sh
   ```
   - Downloads OCCT 8.0.0-rc4 from GitHub tag `V8_0_0_rc4`
   - Builds for iOS arm64, iOS Simulator arm64, macOS arm64
   - Creates `Libraries/OCCT.xcframework`
   - Build time: ~30-60 minutes
4. Verify the xcframework was created with all three slices

### Phase 1: Fix compilation

1. Run `swift build` and collect errors
2. Fix any breaking API changes in `Sources/OCCTBridge/src/OCCTBridge.mm`:
   - Header renames or removals
   - Changed class constructors or method signatures
   - New `final` restrictions (unlikely to affect us)
3. Fix any Swift wrapper issues if C bridge signatures changed
4. Goal: **clean build with zero errors**

### Phase 2: Fix warnings and verify tests

1. Run `swift build` and review deprecation warnings for:
   - `TColgp_Array1OfPnt` → `NCollection_Array1<gp_Pnt>`
   - `TColgp_Array2OfPnt` → `NCollection_Array2<gp_Pnt>`
   - `TColgp_HArray1OfPnt` → `Handle(NCollection_HArray1<gp_Pnt>)`
   - `TColgp_Array1OfPnt2d` → `NCollection_Array1<gp_Pnt2d>`
   - `TColgp_HArray1OfPnt2d` → `Handle(NCollection_HArray1<gp_Pnt2d>)`
   - `TColStd_Array1OfReal` → `NCollection_Array1<double>`
   - `TColStd_Array1OfInteger` → `NCollection_Array1<int>`
   - `TopTools_ListOfShape` → `NCollection_List<TopoDS_Shape>`
   - `TopTools_HSequenceOfShape` → `Handle(NCollection_HSequence<TopoDS_Shape>)`
   - `TopTools_IndexedMapOfShape` → `NCollection_IndexedMap<TopoDS_Shape>`
   - `TopTools_IndexedDataMapOfShapeListOfShape` → `NCollection_IndexedDataMap<TopoDS_Shape, NCollection_List<TopoDS_Shape>>`
   - `Standard_True` → `true`, `Standard_False` → `false`
2. Check and fix `Weights()` → `WeightsArray()` if the nullable pattern changed
3. Run full test suite: `swift test`
4. Goal: **574+ tests passing, zero warnings**

### Phase 3: Integration testing

1. Push branch to remote
2. Test with OCCTSwiftViewport project:
   - Update OCCTSwift dependency to point at `feature/occt-8.0.0-rc4` branch
   - Build and run the viewport app
   - Verify 3D rendering, shape operations, mesh extraction all work
3. If issues found, fix on the branch

### Phase 4: Merge and release

1. Create PR from `feature/occt-8.0.0-rc4` → `main`
2. Review the diff
3. Merge
4. Tag release (version TBD — likely v0.27.0 or v1.0.0)
5. Create GitHub release with notes on OCCT 8.0.0-rc4 upgrade

### Phase 5: Wrap new rc4 features (future work, post-merge)

Lower priority — new Swift APIs for rc4-specific capabilities:
- `NCollection_KDTree` → spatial queries for point clouds
- Batch geometry evaluation via `Geom2dGridEval` if it enables faster operations
- Any new algorithm improvements worth exposing

### Phase 6: Deprecation cleanup (future work, post-merge)

Full modernization pass:
- Replace all remaining `Standard_True/False` with `true/false`
- Replace all `TColStd_*` / `TColgp_*` / `TopTools_*` with `NCollection_*<T>`
- Remove any deprecated API usage
- Run OCCT migration scripts if available in rc4

---

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Build script fails on rc4 | Low | Script is proven for rc3, rc4 is same build system |
| Compilation errors in OCCTBridge.mm | Medium | Most breaking changes don't affect our API surface |
| Test failures from behavior changes | Low | Our tests are robust, OCCT is backwards-compatible on algorithms |
| Viewport app regression | Medium | Test early with real rendering workload |
| BSpline/Bezier Weights() breakage | Medium | Check all `Weights()` calls, migrate to `WeightsArray()` |

## Files That Will Change

- `Scripts/build-occt.sh` — version bump rc3 → rc4
- `Libraries/OCCT.xcframework/` — rebuilt from rc4 source
- `Sources/OCCTBridge/src/OCCTBridge.mm` — deprecation fixes, any API migration
- `Sources/OCCTBridge/include/OCCTBridge.h` — if any C bridge signatures change
- `Tests/OCCTSwiftTests/ShapeTests.swift` — if any test expectations change
- `README.md` — version update for OCCT 8.0.0-rc4

## References

- OCCT 8.0.0-rc4 discussion: https://github.com/Open-Cascade-SAS/OCCT/discussions/1097
- OCCT GitHub releases: https://github.com/Open-Cascade-SAS/OCCT/releases
- Migration scripts (in rc4 source): `adm/scripts/migration_800/`
- Build script: `Scripts/build-occt.sh`
