# Upgrading OCCTSwift to OCCT 8.0

## Current Status

**v0.27.0** — Built on OCCT **8.0.0-rc4** (released 2026-02-25)

### Upgrade History

| Version | OCCT Version | Date | Notes |
|---------|-------------|------|-------|
| v0.27.0 | 8.0.0-rc4 | 2026-02-25 | 111 improvements, 4 breaking changes fixed |
| v0.26.0 | 8.0.0-rc3 | 2026-02-22 | Initial OCCT 8.0 adoption |
| v0.16.0 | 7.8.1 | 2026-02-14 | Original release |

## Breaking Changes Fixed in rc3 → rc4

| Change | Impact | Fix |
|--------|--------|-----|
| `SelectMgr_ViewerSelector3d` removed | Used in headless selector subclass | Replaced include with `SelectMgr_ViewerSelector.hxx` |
| `TopTools_ListIteratorOfListOfShape` removed | Used for adjacent face iteration | Replaced with `TopTools_ListOfShape::Iterator` |
| `BRepExtrema_MapOfIntegerPackedMapOfInteger` removed | Used in shape proximity | Migrated to `NCollection_DataMap<int, TColStd_PackedMapOfInteger>` |
| `TColStd_MapIteratorOfPackedMapOfInteger` removed | Used in proximity iteration | Replaced with `TColStd_PackedMapOfInteger::Iterator` |
| `RWObj_CafWriter::Perform()` signature changed | OBJ export broken | Migrated to 5-arg overload with `GetFreeShapes()` root labels |
| `RWPly_CafWriter::Perform()` signature changed | PLY export broken | Same fix as OBJ |

## Deprecated Typedefs (Suppressed)

OCCT 8.0.0 deprecates many collection typedefs in favor of direct `NCollection` template usage. These are currently **suppressed via pragma** in `OCCTBridge.mm`. The old typedefs still function correctly — they are just `typedef` aliases for the `NCollection` types.

Full migration is tracked for a future release. When migrating, replace:

### Collection Headers
| Deprecated | Replacement |
|------------|-------------|
| `TColgp_Array1OfPnt` | `NCollection_Array1<gp_Pnt>` |
| `TColgp_Array2OfPnt` | `NCollection_Array2<gp_Pnt>` |
| `TColgp_Array1OfPnt2d` | `NCollection_Array1<gp_Pnt2d>` |
| `TColgp_HArray1OfPnt` | `NCollection_HArray1<gp_Pnt>` |
| `TColgp_HArray1OfPnt2d` | `NCollection_HArray1<gp_Pnt2d>` |
| `TColStd_Array1OfReal` | `NCollection_Array1<double>` |
| `TColStd_Array1OfInteger` | `NCollection_Array1<int>` |
| `TColStd_Array2OfReal` | `NCollection_Array2<double>` |
| `TColStd_HArray1OfReal` | `NCollection_HArray1<double>` |
| `TopTools_ListOfShape` | `NCollection_List<TopoDS_Shape>` |
| `TopTools_HSequenceOfShape` | `NCollection_HSequence<TopoDS_Shape>` |
| `TopTools_IndexedMapOfShape` | `NCollection_IndexedMap<TopoDS_Shape, TopTools_ShapeMapHasher>` |
| `TopTools_IndexedDataMapOfShapeListOfShape` | `NCollection_IndexedDataMap<TopoDS_Shape, NCollection_List<TopoDS_Shape>, TopTools_ShapeMapHasher>` |
| `TopTools_SequenceOfShape` | `NCollection_Sequence<TopoDS_Shape>` |
| `TDF_LabelSequence` | `NCollection_Sequence<TDF_Label>` |
| `TDF_LabelMap` | `NCollection_Map<TDF_Label>` |
| `TColGeom2d_SequenceOfCurve` | `NCollection_Sequence<Handle(Geom2d_Curve)>` |

### Graphic Headers
| Deprecated | Replacement |
|------------|-------------|
| `Graphic3d_Mat4` | `NCollection_Mat4<float>` |
| `Graphic3d_Mat4d` | `NCollection_Mat4<double>` |
| `Graphic3d_Vec3` | `NCollection_Vec3<float>` |
| `Graphic3d_Vec4` | `NCollection_Vec4<float>` |

### Primitive Types
| Deprecated | Replacement |
|------------|-------------|
| `Standard_Integer` | `int` |
| `Standard_Real` | `double` |
| `Standard_Boolean` | `bool` |
| `Standard_True` | `true` |
| `Standard_False` | `false` |

### MAT Types
| Deprecated | Replacement |
|------------|-------------|
| `MAT_SequenceOfArc` | `NCollection_Sequence<Handle(MAT_Arc)>` |
| `MAT_SequenceOfBasicElt` | `NCollection_Sequence<Handle(MAT_BasicElt)>` |

## Known Behavioral Changes in rc4

- **Polygon (lasso) pick**: `InitPolylineSelectingVolume` produces different selection results in headless mode. Point pick and rectangle pick work correctly. Polygon pick tests are disabled pending investigation.

## Performance Improvements from rc4

These are internal OCCT changes that benefit OCCTSwift automatically:

- Devirtualized geometry evaluation on hot paths (BSpline, Bezier, analytic surfaces)
- Direct array members in BSpline/Bezier (no heap indirection)
- Thread-local error handling (no mutex contention in parallel code)
- Contiguous TShape child storage (faster topology iteration)
- Cache-friendly matrix multiplication
- Optimized atomic reference counting
- Robin Hood hash maps for internal collections

## New APIs Available in rc4 (Future Wrapping)

| Feature | OCCT Classes | Potential Swift API |
|---------|-------------|---------------------|
| KD-Tree spatial queries | `NCollection_KDTree` | Point cloud nearest-neighbor |
| Batch 2D curve evaluation | `Geom2dGridEval` | Faster curve discretization |
| Fast geometry eval | `Geom_Curve::EvalD0()` etc. | Faster point evaluation |
| Insertion-order maps | `NCollection_OrderedMap` | Internal use |

## Build Instructions

```bash
# Remove old OCCT build artifacts
cd Libraries
rm -rf occt-src occt-build-* occt-install-*

# Build OCCT 8.0.0-rc4 for iOS/macOS
cd Scripts && ./build-occt.sh
```

The build script downloads from GitHub tag `V8_0_0_rc4`, builds for iOS arm64, iOS Simulator arm64, macOS arm64, and creates `Libraries/OCCT.xcframework`.

Build time: ~30-60 minutes depending on hardware.

## Migration Scripts

OCCT 8.0.0-rc4 includes migration scripts at `Libraries/occt-src/adm/scripts/migration_800/` that can automate some of the typedef replacements. These can be used when performing the full NCollection migration.

## When to Update to 8.0.0 Final

1. Wait for 8.0.0 stable release
2. Update `OCCT_RC=""` (clear the RC suffix) in `Scripts/build-occt.sh`
3. Full rebuild and test
4. Merge to main and tag release
