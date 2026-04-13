# OCCT Upgrade History

Documents breaking changes and migration steps for each OCCT version upgrade.

## Version Timeline

| OCCTSwift | OCCT Version | Date | Notes |
|-----------|-------------|------|-------|
| v0.128.0+ | 8.0.0-rc5 | Apr 2026 | Current — analytical geometry, thread safety improvements |
| v0.27.0 | 8.0.0-rc4 | Feb 2026 | 111 improvements, 4 breaking changes |
| v0.26.0 | 8.0.0-rc3 | Feb 2026 | Initial OCCT 8.0 adoption |
| v0.16.0 | 7.8.1 | Feb 2026 | Original release |

---

## RC4 to RC5

### Breaking Changes

| Change | Migration |
|--------|-----------|
| `GeomGridEval_Curve` renamed to `GeomEval_RepCurveDesc` | Updated bridge includes |
| `LProp3d` module absorbed into `BRepLProp` | Changed `LProp3d_CLProps.hxx` to `BRepLProp_CLProps.hxx` |
| `Geom2dLProp_CLProps2d` constructor parameter reordering | Verified constructor calls match RC5 signatures |
| `TColGeom_Array1OfCurve` typedefs removed | Already using `NCollection_Array1<Handle(Geom_Curve)>` |
| `.pxx` implementation headers not shipped in xcframework | `GeomBndLib` wrapping deferred |

### New APIs in RC5

- **GeomEval analytical curves**: CircularHelixCurve, SineWaveCurve
- **GeomEval analytical surfaces**: Ellipsoid, Hyperboloid, Paraboloid, Helicoid, HypParaboloid
- **Geom2dEval spirals**: Archimedean, Logarithmic, CircleInvolute, SineWave
- **GeomFill_Gordon**: Transfinite interpolation surface from crossing curve networks
- **PointSetLib**: Point cloud centroid, inertia tensor, PCA analysis
- **Approx_BSplineApproxInterp**: Constrained least-squares B-spline fitting
- **GeomEval TBezier/AHTBezier**: Trigonometric and algebraic-hyperbolic-trigonometric basis curves/surfaces
- **GeomAdaptor_TransformedCurve**: Rigid transformation adaptor for curves

### Thread Safety Improvements

- Reduced mutable global state in geometry evaluators
- `final` keyword on evaluation methods enables devirtualization
- Grid evaluation batch methods avoid per-call virtual dispatch

### Not Wrappable

- **GeomBndLib**: `.pxx` implementation headers not distributed in xcframework. Deferred until OCCT ships them.

---

## RC3 to RC4

### Breaking Changes

| Change | Migration |
|--------|-----------|
| `SelectMgr_ViewerSelector3d` removed | Replaced with `SelectMgr_ViewerSelector.hxx` |
| `TopTools_ListIteratorOfListOfShape` removed | Replaced with `TopTools_ListOfShape::Iterator` |
| `BRepExtrema_MapOfIntegerPackedMapOfInteger` removed | Migrated to `NCollection_DataMap<int, TColStd_PackedMapOfInteger>` |
| `TColStd_MapIteratorOfPackedMapOfInteger` removed | Replaced with `TColStd_PackedMapOfInteger::Iterator` |
| `RWObj_CafWriter::Perform()` signature changed | Migrated to 5-arg overload |
| `RWPly_CafWriter::Perform()` signature changed | Same fix as OBJ |

### Deprecated Typedefs

OCCT 8.0 deprecates many collection typedefs. Key replacements:

| Deprecated | Replacement |
|------------|-------------|
| `TColgp_Array1OfPnt` | `NCollection_Array1<gp_Pnt>` |
| `TColStd_Array1OfReal` | `NCollection_Array1<double>` |
| `TopTools_ListOfShape` | `NCollection_List<TopoDS_Shape>` |
| `TopTools_IndexedMapOfShape` | `NCollection_IndexedMap<TopoDS_Shape, TopTools_ShapeMapHasher>` |
| `Standard_Integer` / `Standard_Real` / `Standard_Boolean` | `int` / `double` / `bool` |

Full list of deprecated typedefs is available in the OCCT 8.0 migration scripts at `Libraries/occt-src/adm/scripts/migration_800/`.

### Performance Improvements (automatic)

- Devirtualized geometry evaluation on hot paths
- Direct array members in BSpline/Bezier (no heap indirection)
- Thread-local error handling
- Contiguous TShape child storage
- Robin Hood hash maps for internal collections

---

## Rebuilding After Upgrade

```bash
cd Libraries
rm -rf occt-src occt-build-* occt-install-*
cd ../Scripts && ./build-occt.sh
```

Build time: ~30-60 minutes. See [guides/building-occt.md](guides/building-occt.md) for details.
