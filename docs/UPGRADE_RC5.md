# OCCT 8.0.0 RC5 Upgrade Guide

This document covers the upgrade from OCCT 8.0.0-rc4 to 8.0.0-rc5 in OCCTSwift.

## Summary

OCCT 8.0.0-rc5 is a release candidate that refactors several core modules, introduces new analytical geometry evaluators, and improves thread safety. OCCTSwift v0.130.0 performed the initial upgrade and migration; v0.131.0 completes the new API wrapping.

## Breaking Changes from RC4 to RC5

### 1. GeomGridEval Namespace Rename

The batch grid evaluation classes were renamed:

| RC4 Name | RC5 Name |
|----------|----------|
| `GeomGridEval_Curve` | `GeomEval_RepCurveDesc` |
| `GeomGridEval_Surface` | `GeomEval_RepSurfaceDesc` |

**Migration**: Updated all bridge includes and instantiation code in `OCCTBridge.mm`.

### 2. LProp3d Module Removed

The `LProp3d` module was absorbed into `BRepLProp`:

| RC4 Header | RC5 Header |
|------------|------------|
| `LProp3d_CLProps.hxx` | `BRepLProp_CLProps.hxx` |
| `LProp3d_SLProps.hxx` | `BRepLProp_SLProps.hxx` |

**Migration**: Updated includes. The API signatures are identical.

### 3. Geom2dLProp Signature Changes

`Geom2dLProp_CLProps2d` constructor parameters changed order in some overloads.

**Migration**: Verified constructor calls match RC5 signatures.

### 4. TColGeom Deprecation Completed

`TColGeom_Array1OfCurve` and similar typedefs were removed. Use `NCollection_Array1<Handle(Geom_Curve)>` directly.

**Migration**: All bridge code already used NCollection types.

### 5. Header Reorganization

Several `.pxx` implementation headers were introduced (e.g., `GeomBndLib_InfiniteHelpers.pxx`) but are **not shipped** in the xcframework headers directory. This means `GeomBndLib_Curve`, `GeomBndLib_Curve2d`, and `GeomBndLib_Surface` cannot be compiled against from the xcframework distribution.

**Status**: GeomBndLib wrapping deferred until .pxx files are included in distribution.

## New APIs in RC5

### GeomEval Analytical Curves (v0.130.0)

New analytical curve evaluators that bypass the Geom_Curve virtual dispatch:

- **GeomEval_CircularHelixCurve** -- constant-pitch helix with D0/D1/D2 evaluation
- **GeomEval_SineWaveCurve** -- parametric sine wave with amplitude/frequency/phase

### GeomEval Analytical Surfaces (v0.130.0)

- **GeomEval_EllipsoidSurface** -- triaxial ellipsoid (a, b, c semi-axes)
- **GeomEval_HyperboloidSurface** -- one-sheet or two-sheet hyperboloid of revolution
- **GeomEval_ParaboloidSurface** -- paraboloid of revolution
- **GeomEval_CircularHelicoidSurface** -- helicoid ruled surface
- **GeomEval_HypParaboloidSurface** -- hyperbolic paraboloid (saddle surface)

### Geom2dEval Analytical 2D Curves (v0.130.0)

- **Geom2dEval_ArchimedeanSpiralCurve** -- Archimedean spiral r = a + b*theta
- **Geom2dEval_LogarithmicSpiralCurve** -- logarithmic spiral r = a * e^(b*theta)
- **Geom2dEval_CircleInvoluteCurve** -- involute of a circle
- **Geom2dEval_SineWaveCurve** -- 2D sine wave

### GeomFill_Gordon (v0.130.0)

Transfinite interpolation surface from crossing profile and guide curve networks.

### PointSetLib (v0.130.0)

Point cloud analysis utilities: centroid, inertia tensor, PCA dimensionality analysis.

### ExtremaPC (v0.130.0)

Point-to-curve distance computation with full extrema enumeration.

### Approx_BSplineApproxInterp (v0.131.0)

Constrained least-squares B-spline curve fitting with:
- Exact interpolation constraints at selected points
- Kink (C0 discontinuity) support at interpolation points
- Iterative parameter optimization (PerformOptimal)
- KKT saddle-point system solver
- Configurable parametrization (uniform/centripetal/chord-length)

### GeomEval TBezier/AHTBezier Curves and Surfaces (v0.131.0)

New generalized Bezier geometry types:

- **GeomEval_TBezierCurve** -- trigonometric Bernstein basis curves
- **GeomEval_AHTBezierCurve** -- algebraic-hyperbolic-trigonometric basis curves
- **GeomEval_TBezierSurface** -- tensor-product T-Bezier surfaces
- **GeomEval_AHTBezierSurface** -- tensor-product AHT-Bezier surfaces
- **Geom2dEval_TBezierCurve** -- 2D T-Bezier curves
- **Geom2dEval_AHTBezierCurve** -- 2D AHT-Bezier curves

These extend the standard Bezier/BSpline toolkit with mixed polynomial-trigonometric-hyperbolic basis functions, useful for representing conics, spirals, and other transcendental curves exactly.

### GeomAdaptor_TransformedCurve (v0.131.0)

Curve adaptor that applies a rigid transformation to point/derivative evaluations. Used internally by BRepAdaptor_Curve in RC5.

## Not Wrappable in RC5

### NCollection_KDTree

Template-only class (no exported symbols). Already wrapped separately via explicit instantiation in the bridge (`NCollection_KDTree<gp_Pnt, 3>`).

### GeomBndLib

New variant-based bounding box dispatchers. **Cannot compile** from the xcframework because `GeomBndLib_InfiniteHelpers.pxx` is not distributed. Will be wrappable when OCCT ships the .pxx file or restructures the includes.

## Thread Safety Improvements

RC5 introduces several thread-safety improvements:

- Reduced mutable global state in geometry evaluators
- `final` keyword on evaluation methods enables devirtualization
- Grid evaluation batch methods avoid per-call virtual dispatch overhead

## Migration Notes for Downstream Consumers

### If you use OCCTSwift as a package dependency:

1. Update your Package.swift to reference the new binary artifact URL (v0.131.0)
2. No API changes -- all existing Swift APIs are source-compatible
3. New APIs are purely additive (new static factory methods on Curve3D, Curve2D, Surface)

### If you build OCCT from source:

1. Use the `Scripts/build-occt.sh` script which targets RC5
2. Ensure `.pxx` files are included if you want GeomBndLib support
3. The xcframework in `Libraries/` is pre-built for arm64 macOS and iOS

## Version History

| Version | OCCT | Ops | Description |
|---------|------|-----|-------------|
| v0.130.0 | RC5 | 3386 | Initial RC5 upgrade + analytical geometry |
| v0.131.0 | RC5 | 3408 | Final RC5 wrapping + documentation |
