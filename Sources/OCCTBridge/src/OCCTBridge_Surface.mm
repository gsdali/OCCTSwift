//
//  OCCTBridge_Surface.mm
//  OCCTSwift
//
//  Extracted from OCCTBridge.mm — issue #99.
//
//  3D parametric surface cluster (v0.20):
//
//  - Geom_Surface construction (plane, cylinder, cone, sphere, torus,
//    surface-of-revolution, surface-of-extrusion, BSpline, Bezier,
//    rectangular-trimmed, offset)
//  - GeomConvert + GeomConvert_ApproxSurface
//  - GeomFill_Pipe (parametric pipe surface)
//  - Local properties (GeomLProp_SLProps)
//  - Adaptor (GeomAdaptor_Surface) introspection: surface type, axes,
//    UV bounds, periodic flags, degrees, knot/pole counts
//
//  OCCTSurface struct definition kept in BOTH this TU and OCCTBridge.mm
//  (identical layout, ODR-safe across TUs) — main still uses
//  surface->surface field access in projection / surface-grid eval / etc.
//
//  Public C surface unchanged. No symbol changes — pure file move.
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

// === Area-specific OCCT headers ===

#include <Geom_BezierSurface.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_ConicalSurface.hxx>
#include <Geom_Curve.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_OffsetSurface.hxx>
#include <Geom_Plane.hxx>
#include <Geom_RectangularTrimmedSurface.hxx>
#include <Geom_SphericalSurface.hxx>
#include <Geom_Surface.hxx>
#include <Geom_SurfaceOfLinearExtrusion.hxx>
#include <Geom_SurfaceOfRevolution.hxx>
#include <Geom_ToroidalSurface.hxx>

#include <GeomAbs_Shape.hxx>
#include <GeomAdaptor_Surface.hxx>
#include <GeomConvert.hxx>
#include <GeomConvert_ApproxSurface.hxx>
#include <GeomFill_Pipe.hxx>
#include <GeomLProp_SLProps.hxx>

#include <gp_Ax1.hxx>
#include <gp_Ax2.hxx>
#include <gp_Ax3.hxx>
#include <gp_Cone.hxx>
#include <gp_Cylinder.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>
#include <gp_Sphere.hxx>
#include <gp_Torus.hxx>
#include <gp_Trsf.hxx>
#include <gp_Vec.hxx>

#include <TColgp_Array2OfPnt.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColStd_Array2OfReal.hxx>

// MARK: - Surface: Parametric Surfaces (v0.20.0)
// ============================================================================

#include <Geom_Surface.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_ConicalSurface.hxx>
#include <Geom_SphericalSurface.hxx>
#include <Geom_ToroidalSurface.hxx>
#include <Geom_BezierSurface.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_RectangularTrimmedSurface.hxx>
#include <Geom_OffsetSurface.hxx>
#include <Geom_SurfaceOfLinearExtrusion.hxx>
#include <Geom_SurfaceOfRevolution.hxx>
#include <GeomFill_Pipe.hxx>
#include <GeomConvert_ApproxSurface.hxx>
#include <GeomAdaptor_Surface.hxx>
#include <BndLib_AddSurface.hxx>
#include <TColgp_Array2OfPnt.hxx>
#include <TColStd_Array2OfReal.hxx>
#include <gp_Cylinder.hxx>
#include <gp_Cone.hxx>
#include <gp_Sphere.hxx>
#include <gp_Torus.hxx>

void OCCTSurfaceRelease(OCCTSurfaceRef s) {
    delete s;
}

// Properties

void OCCTSurfaceGetDomain(OCCTSurfaceRef s,
                           double* uMin, double* uMax,
                           double* vMin, double* vMax) {
    if (!s || s->surface.IsNull() || !uMin || !uMax || !vMin || !vMax) return;
    s->surface->Bounds(*uMin, *uMax, *vMin, *vMax);
}

bool OCCTSurfaceIsUClosed(OCCTSurfaceRef s) {
    if (!s || s->surface.IsNull()) return false;
    return s->surface->IsUClosed() == Standard_True;
}

bool OCCTSurfaceIsVClosed(OCCTSurfaceRef s) {
    if (!s || s->surface.IsNull()) return false;
    return s->surface->IsVClosed() == Standard_True;
}

bool OCCTSurfaceIsUPeriodic(OCCTSurfaceRef s) {
    if (!s || s->surface.IsNull()) return false;
    return s->surface->IsUPeriodic() == Standard_True;
}

bool OCCTSurfaceIsVPeriodic(OCCTSurfaceRef s) {
    if (!s || s->surface.IsNull()) return false;
    return s->surface->IsVPeriodic() == Standard_True;
}

double OCCTSurfaceGetUPeriod(OCCTSurfaceRef s) {
    if (!s || s->surface.IsNull() || !s->surface->IsUPeriodic()) return 0.0;
    return s->surface->UPeriod();
}

double OCCTSurfaceGetVPeriod(OCCTSurfaceRef s) {
    if (!s || s->surface.IsNull() || !s->surface->IsVPeriodic()) return 0.0;
    return s->surface->VPeriod();
}

// Evaluation

void OCCTSurfaceGetPoint(OCCTSurfaceRef s, double u, double v,
                          double* x, double* y, double* z) {
    if (!s || s->surface.IsNull() || !x || !y || !z) return;
    gp_Pnt p;
    s->surface->D0(u, v, p);
    *x = p.X(); *y = p.Y(); *z = p.Z();
}

void OCCTSurfaceD1(OCCTSurfaceRef s, double u, double v,
                    double* px, double* py, double* pz,
                    double* dux, double* duy, double* duz,
                    double* dvx, double* dvy, double* dvz) {
    if (!s || s->surface.IsNull() ||
        !px || !py || !pz || !dux || !duy || !duz || !dvx || !dvy || !dvz) return;
    gp_Pnt p;
    gp_Vec du, dv;
    s->surface->D1(u, v, p, du, dv);
    *px = p.X(); *py = p.Y(); *pz = p.Z();
    *dux = du.X(); *duy = du.Y(); *duz = du.Z();
    *dvx = dv.X(); *dvy = dv.Y(); *dvz = dv.Z();
}

void OCCTSurfaceD2(OCCTSurfaceRef s, double u, double v,
                    double* px, double* py, double* pz,
                    double* d1ux, double* d1uy, double* d1uz,
                    double* d1vx, double* d1vy, double* d1vz,
                    double* d2ux, double* d2uy, double* d2uz,
                    double* d2vx, double* d2vy, double* d2vz,
                    double* d2uvx, double* d2uvy, double* d2uvz) {
    if (!s || s->surface.IsNull() ||
        !px || !py || !pz ||
        !d1ux || !d1uy || !d1uz || !d1vx || !d1vy || !d1vz ||
        !d2ux || !d2uy || !d2uz || !d2vx || !d2vy || !d2vz ||
        !d2uvx || !d2uvy || !d2uvz) return;
    gp_Pnt p;
    gp_Vec d1u, d1v, d2u, d2v, d2uv;
    s->surface->D2(u, v, p, d1u, d1v, d2u, d2v, d2uv);
    *px = p.X(); *py = p.Y(); *pz = p.Z();
    *d1ux = d1u.X(); *d1uy = d1u.Y(); *d1uz = d1u.Z();
    *d1vx = d1v.X(); *d1vy = d1v.Y(); *d1vz = d1v.Z();
    *d2ux = d2u.X(); *d2uy = d2u.Y(); *d2uz = d2u.Z();
    *d2vx = d2v.X(); *d2vy = d2v.Y(); *d2vz = d2v.Z();
    *d2uvx = d2uv.X(); *d2uvy = d2uv.Y(); *d2uvz = d2uv.Z();
}

bool OCCTSurfaceGetNormal(OCCTSurfaceRef s, double u, double v,
                           double* nx, double* ny, double* nz) {
    if (!s || s->surface.IsNull() || !nx || !ny || !nz) return false;
    try {
        GeomLProp_SLProps props(s->surface, u, v, 1, Precision::Confusion());
        if (!props.IsNormalDefined()) return false;
        gp_Dir n = props.Normal();
        *nx = n.X(); *ny = n.Y(); *nz = n.Z();
        return true;
    } catch (...) {
        return false;
    }
}

// Analytic Surfaces

OCCTSurfaceRef OCCTSurfaceCreatePlane(double px, double py, double pz,
                                       double nx, double ny, double nz) {
    try {
        gp_Pnt origin(px, py, pz);
        gp_Dir normal(nx, ny, nz);
        Handle(Geom_Plane) plane = new Geom_Plane(origin, normal);
        return new OCCTSurface(plane);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceCreateCylinder(double px, double py, double pz,
                                          double dx, double dy, double dz,
                                          double radius) {
    try {
        if (radius <= 0) return nullptr;
        gp_Pnt origin(px, py, pz);
        gp_Dir dir(dx, dy, dz);
        gp_Ax3 axis(origin, dir);
        Handle(Geom_CylindricalSurface) cyl = new Geom_CylindricalSurface(axis, radius);
        return new OCCTSurface(cyl);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceCreateCone(double px, double py, double pz,
                                      double dx, double dy, double dz,
                                      double radius, double semiAngle) {
    try {
        if (radius < 0) return nullptr;
        gp_Pnt origin(px, py, pz);
        gp_Dir dir(dx, dy, dz);
        gp_Ax3 axis(origin, dir);
        Handle(Geom_ConicalSurface) cone = new Geom_ConicalSurface(axis, semiAngle, radius);
        return new OCCTSurface(cone);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceCreateSphere(double cx, double cy, double cz,
                                        double radius) {
    try {
        if (radius <= 0) return nullptr;
        gp_Pnt center(cx, cy, cz);
        gp_Ax3 axis(center, gp::DZ());
        Handle(Geom_SphericalSurface) sphere = new Geom_SphericalSurface(axis, radius);
        return new OCCTSurface(sphere);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceCreateTorus(double px, double py, double pz,
                                       double dx, double dy, double dz,
                                       double majorRadius, double minorRadius) {
    try {
        if (majorRadius <= 0 || minorRadius <= 0 || minorRadius >= majorRadius)
            return nullptr;
        gp_Pnt origin(px, py, pz);
        gp_Dir dir(dx, dy, dz);
        gp_Ax3 axis(origin, dir);
        Handle(Geom_ToroidalSurface) torus = new Geom_ToroidalSurface(axis, majorRadius, minorRadius);
        return new OCCTSurface(torus);
    } catch (...) {
        return nullptr;
    }
}

// Swept Surfaces

OCCTSurfaceRef OCCTSurfaceCreateExtrusion(OCCTCurve3DRef profile,
                                           double dx, double dy, double dz) {
    if (!profile || profile->curve.IsNull()) return nullptr;
    try {
        gp_Dir dir(dx, dy, dz);
        Handle(Geom_SurfaceOfLinearExtrusion) ext =
            new Geom_SurfaceOfLinearExtrusion(profile->curve, dir);
        return new OCCTSurface(ext);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceCreateRevolution(OCCTCurve3DRef meridian,
                                            double px, double py, double pz,
                                            double dx, double dy, double dz) {
    if (!meridian || meridian->curve.IsNull()) return nullptr;
    try {
        gp_Pnt origin(px, py, pz);
        gp_Dir dir(dx, dy, dz);
        gp_Ax1 axis(origin, dir);
        Handle(Geom_SurfaceOfRevolution) rev =
            new Geom_SurfaceOfRevolution(meridian->curve, axis);
        return new OCCTSurface(rev);
    } catch (...) {
        return nullptr;
    }
}

// Freeform Surfaces

OCCTSurfaceRef OCCTSurfaceCreateBezier(const double* poles,
                                        int32_t uCount, int32_t vCount,
                                        const double* weights) {
    if (!poles || uCount < 2 || vCount < 2) return nullptr;
    try {
        TColgp_Array2OfPnt poleArray(1, uCount, 1, vCount);
        for (int32_t i = 0; i < uCount; i++) {
            for (int32_t j = 0; j < vCount; j++) {
                int idx = (i * vCount + j) * 3;
                poleArray.SetValue(i + 1, j + 1,
                    gp_Pnt(poles[idx], poles[idx+1], poles[idx+2]));
            }
        }
        Handle(Geom_BezierSurface) bez;
        if (weights) {
            TColStd_Array2OfReal wArr(1, uCount, 1, vCount);
            for (int32_t i = 0; i < uCount; i++) {
                for (int32_t j = 0; j < vCount; j++) {
                    wArr.SetValue(i + 1, j + 1, weights[i * vCount + j]);
                }
            }
            bez = new Geom_BezierSurface(poleArray, wArr);
        } else {
            bez = new Geom_BezierSurface(poleArray);
        }
        return new OCCTSurface(bez);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceCreateBSpline(const double* poles,
                                         int32_t uPoleCount, int32_t vPoleCount,
                                         const double* weights,
                                         const double* uKnots, int32_t uKnotCount,
                                         const double* vKnots, int32_t vKnotCount,
                                         const int32_t* uMults, const int32_t* vMults,
                                         int32_t uDegree, int32_t vDegree) {
    if (!poles || !uKnots || !vKnots || !uMults || !vMults) return nullptr;
    if (uPoleCount < 2 || vPoleCount < 2 || uKnotCount < 2 || vKnotCount < 2) return nullptr;
    try {
        TColgp_Array2OfPnt poleArray(1, uPoleCount, 1, vPoleCount);
        for (int32_t i = 0; i < uPoleCount; i++) {
            for (int32_t j = 0; j < vPoleCount; j++) {
                int idx = (i * vPoleCount + j) * 3;
                poleArray.SetValue(i + 1, j + 1,
                    gp_Pnt(poles[idx], poles[idx+1], poles[idx+2]));
            }
        }

        TColStd_Array1OfReal uKnotArr(1, uKnotCount);
        for (int32_t i = 0; i < uKnotCount; i++) uKnotArr.SetValue(i + 1, uKnots[i]);
        TColStd_Array1OfReal vKnotArr(1, vKnotCount);
        for (int32_t i = 0; i < vKnotCount; i++) vKnotArr.SetValue(i + 1, vKnots[i]);

        TColStd_Array1OfInteger uMultArr(1, uKnotCount);
        for (int32_t i = 0; i < uKnotCount; i++) uMultArr.SetValue(i + 1, uMults[i]);
        TColStd_Array1OfInteger vMultArr(1, vKnotCount);
        for (int32_t i = 0; i < vKnotCount; i++) vMultArr.SetValue(i + 1, vMults[i]);

        Handle(Geom_BSplineSurface) bsp;
        if (weights) {
            TColStd_Array2OfReal wArr(1, uPoleCount, 1, vPoleCount);
            for (int32_t i = 0; i < uPoleCount; i++) {
                for (int32_t j = 0; j < vPoleCount; j++) {
                    wArr.SetValue(i + 1, j + 1, weights[i * vPoleCount + j]);
                }
            }
            bsp = new Geom_BSplineSurface(poleArray, wArr,
                uKnotArr, vKnotArr, uMultArr, vMultArr, uDegree, vDegree);
        } else {
            bsp = new Geom_BSplineSurface(poleArray,
                uKnotArr, vKnotArr, uMultArr, vMultArr, uDegree, vDegree);
        }
        return new OCCTSurface(bsp);
    } catch (...) {
        return nullptr;
    }
}

// Operations

OCCTSurfaceRef OCCTSurfaceTrim(OCCTSurfaceRef s,
                                double u1, double u2, double v1, double v2) {
    if (!s || s->surface.IsNull()) return nullptr;
    try {
        Handle(Geom_RectangularTrimmedSurface) trimmed =
            new Geom_RectangularTrimmedSurface(s->surface, u1, u2, v1, v2);
        return new OCCTSurface(trimmed);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceOffset(OCCTSurfaceRef s, double distance) {
    if (!s || s->surface.IsNull()) return nullptr;
    try {
        Handle(Geom_OffsetSurface) offset =
            new Geom_OffsetSurface(s->surface, distance);
        return new OCCTSurface(offset);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceTranslate(OCCTSurfaceRef s,
                                     double dx, double dy, double dz) {
    if (!s || s->surface.IsNull()) return nullptr;
    try {
        Handle(Geom_Surface) copy = Handle(Geom_Surface)::DownCast(s->surface->Copy());
        gp_Trsf trsf;
        trsf.SetTranslation(gp_Vec(dx, dy, dz));
        copy->Transform(trsf);
        return new OCCTSurface(copy);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceRotate(OCCTSurfaceRef s,
                                  double axOx, double axOy, double axOz,
                                  double axDx, double axDy, double axDz,
                                  double angle) {
    if (!s || s->surface.IsNull()) return nullptr;
    try {
        Handle(Geom_Surface) copy = Handle(Geom_Surface)::DownCast(s->surface->Copy());
        gp_Trsf trsf;
        trsf.SetRotation(gp_Ax1(gp_Pnt(axOx, axOy, axOz), gp_Dir(axDx, axDy, axDz)), angle);
        copy->Transform(trsf);
        return new OCCTSurface(copy);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceScale(OCCTSurfaceRef s,
                                 double cx, double cy, double cz, double factor) {
    if (!s || s->surface.IsNull()) return nullptr;
    try {
        Handle(Geom_Surface) copy = Handle(Geom_Surface)::DownCast(s->surface->Copy());
        gp_Trsf trsf;
        trsf.SetScale(gp_Pnt(cx, cy, cz), factor);
        copy->Transform(trsf);
        return new OCCTSurface(copy);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceMirrorPlane(OCCTSurfaceRef s,
                                       double px, double py, double pz,
                                       double nx, double ny, double nz) {
    if (!s || s->surface.IsNull()) return nullptr;
    try {
        Handle(Geom_Surface) copy = Handle(Geom_Surface)::DownCast(s->surface->Copy());
        gp_Trsf trsf;
        trsf.SetMirror(gp_Ax2(gp_Pnt(px, py, pz), gp_Dir(nx, ny, nz)));
        copy->Transform(trsf);
        return new OCCTSurface(copy);
    } catch (...) {
        return nullptr;
    }
}

// Conversion

OCCTSurfaceRef OCCTSurfaceToBSpline(OCCTSurfaceRef s) {
    if (!s || s->surface.IsNull()) return nullptr;
    try {
        Handle(Geom_BSplineSurface) bsp = GeomConvert::SurfaceToBSplineSurface(s->surface);
        if (bsp.IsNull()) return nullptr;
        return new OCCTSurface(bsp);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceApproximate(OCCTSurfaceRef s, double tolerance,
                                       int32_t continuity, int32_t maxSegments,
                                       int32_t maxDegree) {
    if (!s || s->surface.IsNull()) return nullptr;
    try {
        GeomAbs_Shape cont = GeomAbs_C2;
        switch (continuity) {
            case 0: cont = GeomAbs_C0; break;
            case 1: cont = GeomAbs_C1; break;
            case 2: cont = GeomAbs_C2; break;
            case 3: cont = GeomAbs_C3; break;
        }
        GeomConvert_ApproxSurface approx(s->surface, tolerance,
                                          cont, cont, maxDegree, maxDegree, maxSegments, 0);
        if (!approx.HasResult()) return nullptr;
        return new OCCTSurface(approx.Surface());
    } catch (...) {
        return nullptr;
    }
}

// Iso Curves

OCCTCurve3DRef OCCTSurfaceUIso(OCCTSurfaceRef s, double u) {
    if (!s || s->surface.IsNull()) return nullptr;
    try {
        Handle(Geom_Curve) iso = s->surface->UIso(u);
        if (iso.IsNull()) return nullptr;
        return new OCCTCurve3D(iso);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTSurfaceVIso(OCCTSurfaceRef s, double v) {
    if (!s || s->surface.IsNull()) return nullptr;
    try {
        Handle(Geom_Curve) iso = s->surface->VIso(v);
        if (iso.IsNull()) return nullptr;
        return new OCCTCurve3D(iso);
    } catch (...) {
        return nullptr;
    }
}

// Pipe Surface

OCCTSurfaceRef OCCTSurfaceCreatePipe(OCCTCurve3DRef path, double radius) {
    if (!path || path->curve.IsNull() || radius <= 0) return nullptr;
    try {
        GeomFill_Pipe pipe(path->curve, radius);
        pipe.Perform(Standard_True, Standard_False);
        Handle(Geom_Surface) result = pipe.Surface();
        if (result.IsNull()) return nullptr;
        return new OCCTSurface(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceCreatePipeWithSection(OCCTCurve3DRef path,
                                                 OCCTCurve3DRef section) {
    if (!path || path->curve.IsNull() || !section || section->curve.IsNull())
        return nullptr;
    try {
        GeomFill_Pipe pipe(path->curve, section->curve);
        pipe.Perform(Standard_True, Standard_False);
        Handle(Geom_Surface) result = pipe.Surface();
        if (result.IsNull()) return nullptr;
        return new OCCTSurface(result);
    } catch (...) {
        return nullptr;
    }
}

// Draw Methods

int32_t OCCTSurfaceDrawGrid(OCCTSurfaceRef s,
                             int32_t uCount, int32_t vCount,
                             int32_t pointsPerLine,
                             double* outXYZ, int32_t maxPoints,
                             int32_t* outLineLengths, int32_t maxLines) {
    if (!s || s->surface.IsNull() || !outXYZ || !outLineLengths ||
        maxPoints <= 0 || maxLines <= 0) return 0;
    try {
        double uMin, uMax, vMin, vMax;
        s->surface->Bounds(uMin, uMax, vMin, vMax);

        // Clamp infinite bounds
        if (uMin < -1e6) uMin = -100;
        if (uMax >  1e6) uMax = 100;
        if (vMin < -1e6) vMin = -100;
        if (vMax >  1e6) vMax = 100;

        int32_t totalPoints = 0;
        int32_t lineIdx = 0;

        // U-iso lines (constant U, varying V)
        for (int32_t i = 0; i < uCount && lineIdx < maxLines; i++) {
            double u = uMin + (uMax - uMin) * i / (uCount > 1 ? (uCount - 1) : 1);
            int32_t ptsInLine = 0;
            for (int32_t j = 0; j < pointsPerLine && totalPoints < maxPoints; j++) {
                double v = vMin + (vMax - vMin) * j / (pointsPerLine > 1 ? (pointsPerLine - 1) : 1);
                gp_Pnt p;
                s->surface->D0(u, v, p);
                outXYZ[totalPoints * 3]     = p.X();
                outXYZ[totalPoints * 3 + 1] = p.Y();
                outXYZ[totalPoints * 3 + 2] = p.Z();
                totalPoints++;
                ptsInLine++;
            }
            outLineLengths[lineIdx++] = ptsInLine;
        }

        // V-iso lines (constant V, varying U)
        for (int32_t j = 0; j < vCount && lineIdx < maxLines; j++) {
            double v = vMin + (vMax - vMin) * j / (vCount > 1 ? (vCount - 1) : 1);
            int32_t ptsInLine = 0;
            for (int32_t i = 0; i < pointsPerLine && totalPoints < maxPoints; i++) {
                double u = uMin + (uMax - uMin) * i / (pointsPerLine > 1 ? (pointsPerLine - 1) : 1);
                gp_Pnt p;
                s->surface->D0(u, v, p);
                outXYZ[totalPoints * 3]     = p.X();
                outXYZ[totalPoints * 3 + 1] = p.Y();
                outXYZ[totalPoints * 3 + 2] = p.Z();
                totalPoints++;
                ptsInLine++;
            }
            outLineLengths[lineIdx++] = ptsInLine;
        }

        return totalPoints;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTSurfaceDrawMesh(OCCTSurfaceRef s,
                             int32_t uCount, int32_t vCount,
                             double* outXYZ) {
    if (!s || s->surface.IsNull() || !outXYZ || uCount < 2 || vCount < 2) return 0;
    try {
        double uMin, uMax, vMin, vMax;
        s->surface->Bounds(uMin, uMax, vMin, vMax);

        // Clamp infinite bounds
        if (uMin < -1e6) uMin = -100;
        if (uMax >  1e6) uMax = 100;
        if (vMin < -1e6) vMin = -100;
        if (vMax >  1e6) vMax = 100;

        int32_t idx = 0;
        for (int32_t i = 0; i < uCount; i++) {
            double u = uMin + (uMax - uMin) * i / (uCount - 1);
            for (int32_t j = 0; j < vCount; j++) {
                double v = vMin + (vMax - vMin) * j / (vCount - 1);
                gp_Pnt p;
                s->surface->D0(u, v, p);
                outXYZ[idx * 3]     = p.X();
                outXYZ[idx * 3 + 1] = p.Y();
                outXYZ[idx * 3 + 2] = p.Z();
                idx++;
            }
        }
        return idx;
    } catch (...) {
        return 0;
    }
}

// Local Properties

double OCCTSurfaceGetGaussianCurvature(OCCTSurfaceRef s, double u, double v) {
    if (!s || s->surface.IsNull()) return 0.0;
    try {
        GeomLProp_SLProps props(s->surface, u, v, 2, Precision::Confusion());
        if (!props.IsCurvatureDefined()) return 0.0;
        return props.GaussianCurvature();
    } catch (...) {
        return 0.0;
    }
}

double OCCTSurfaceGetMeanCurvature(OCCTSurfaceRef s, double u, double v) {
    if (!s || s->surface.IsNull()) return 0.0;
    try {
        GeomLProp_SLProps props(s->surface, u, v, 2, Precision::Confusion());
        if (!props.IsCurvatureDefined()) return 0.0;
        return props.MeanCurvature();
    } catch (...) {
        return 0.0;
    }
}

bool OCCTSurfaceGetPrincipalCurvatures(OCCTSurfaceRef s, double u, double v,
                                        double* kMin, double* kMax,
                                        double* d1x, double* d1y, double* d1z,
                                        double* d2x, double* d2y, double* d2z) {
    if (!s || s->surface.IsNull() || !kMin || !kMax ||
        !d1x || !d1y || !d1z || !d2x || !d2y || !d2z) return false;
    try {
        GeomLProp_SLProps props(s->surface, u, v, 2, Precision::Confusion());
        if (!props.IsCurvatureDefined()) return false;
        *kMin = props.MinCurvature();
        *kMax = props.MaxCurvature();
        gp_Dir dir1, dir2;
        props.CurvatureDirections(dir1, dir2);
        *d1x = dir1.X(); *d1y = dir1.Y(); *d1z = dir1.Z();
        *d2x = dir2.X(); *d2y = dir2.Y(); *d2z = dir2.Z();
        return true;
    } catch (...) {
        return false;
    }
}

// Bounding Box

bool OCCTSurfaceGetBoundingBox(OCCTSurfaceRef s,
                                double* xMin, double* yMin, double* zMin,
                                double* xMax, double* yMax, double* zMax) {
    if (!s || s->surface.IsNull() || !xMin || !yMin || !zMin || !xMax || !yMax || !zMax)
        return false;
    try {
        GeomAdaptor_Surface adaptor(s->surface);
        Bnd_Box box;
        BndLib_AddSurface::Add(adaptor, 0.01, box);
        if (box.IsVoid()) return false;
        box.Get(*xMin, *yMin, *zMin, *xMax, *yMax, *zMax);
        return true;
    } catch (...) {
        return false;
    }
}

// BSpline Queries

int32_t OCCTSurfaceGetUPoleCount(OCCTSurfaceRef s) {
    if (!s || s->surface.IsNull()) return 0;
    Handle(Geom_BSplineSurface) bsp = Handle(Geom_BSplineSurface)::DownCast(s->surface);
    if (bsp.IsNull()) {
        Handle(Geom_BezierSurface) bez = Handle(Geom_BezierSurface)::DownCast(s->surface);
        if (!bez.IsNull()) return bez->NbUPoles();
        return 0;
    }
    return bsp->NbUPoles();
}

int32_t OCCTSurfaceGetVPoleCount(OCCTSurfaceRef s) {
    if (!s || s->surface.IsNull()) return 0;
    Handle(Geom_BSplineSurface) bsp = Handle(Geom_BSplineSurface)::DownCast(s->surface);
    if (bsp.IsNull()) {
        Handle(Geom_BezierSurface) bez = Handle(Geom_BezierSurface)::DownCast(s->surface);
        if (!bez.IsNull()) return bez->NbVPoles();
        return 0;
    }
    return bsp->NbVPoles();
}

int32_t OCCTSurfaceGetPoles(OCCTSurfaceRef s, double* outXYZ) {
    if (!s || s->surface.IsNull() || !outXYZ) return 0;
    try {
        Handle(Geom_BSplineSurface) bsp = Handle(Geom_BSplineSurface)::DownCast(s->surface);
        Handle(Geom_BezierSurface) bez = Handle(Geom_BezierSurface)::DownCast(s->surface);

        int uCount = 0, vCount = 0;
        if (!bsp.IsNull()) {
            uCount = bsp->NbUPoles();
            vCount = bsp->NbVPoles();
            int idx = 0;
            for (int i = 1; i <= uCount; i++) {
                for (int j = 1; j <= vCount; j++) {
                    gp_Pnt p = bsp->Pole(i, j);
                    outXYZ[idx*3]     = p.X();
                    outXYZ[idx*3 + 1] = p.Y();
                    outXYZ[idx*3 + 2] = p.Z();
                    idx++;
                }
            }
            return idx;
        } else if (!bez.IsNull()) {
            uCount = bez->NbUPoles();
            vCount = bez->NbVPoles();
            int idx = 0;
            for (int i = 1; i <= uCount; i++) {
                for (int j = 1; j <= vCount; j++) {
                    gp_Pnt p = bez->Pole(i, j);
                    outXYZ[idx*3]     = p.X();
                    outXYZ[idx*3 + 1] = p.Y();
                    outXYZ[idx*3 + 2] = p.Z();
                    idx++;
                }
            }
            return idx;
        }
        return 0;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTSurfaceGetUDegree(OCCTSurfaceRef s) {
    if (!s || s->surface.IsNull()) return 0;
    Handle(Geom_BSplineSurface) bsp = Handle(Geom_BSplineSurface)::DownCast(s->surface);
    if (bsp.IsNull()) {
        Handle(Geom_BezierSurface) bez = Handle(Geom_BezierSurface)::DownCast(s->surface);
        if (!bez.IsNull()) return bez->UDegree();
        return 0;
    }
    return bsp->UDegree();
}

int32_t OCCTSurfaceGetVDegree(OCCTSurfaceRef s) {
    if (!s || s->surface.IsNull()) return 0;
    Handle(Geom_BSplineSurface) bsp = Handle(Geom_BSplineSurface)::DownCast(s->surface);
    if (bsp.IsNull()) {
        Handle(Geom_BezierSurface) bez = Handle(Geom_BezierSurface)::DownCast(s->surface);
        if (!bez.IsNull()) return bez->VDegree();
        return 0;
    }
    return bsp->VDegree();
}

