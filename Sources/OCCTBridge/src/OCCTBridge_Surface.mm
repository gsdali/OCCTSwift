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
#include <GeomConvert_BSplineSurfaceToBezierSurface.hxx>
#include <GeomAPI_IntSS.hxx>
#include <GeomAPI_IntCS.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_BezierSurface.hxx>
#include <GC_MakeConicalSurface.hxx>
#include <GC_MakeCylindricalSurface.hxx>
#include <GC_MakePlane.hxx>
#include <GC_MakeTrimmedCone.hxx>
#include <GC_MakeTrimmedCylinder.hxx>
#include <GeomConvert_BSplineSurfaceKnotSplitting.hxx>
#include <GeomConvert_CompBezierSurfacesToBSplineSurface.hxx>
#include <GeomFill_Pipe.hxx>
#include <GeomFill_BSplineCurves.hxx>
#include <Adaptor3d_IsoCurve.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepTopAdaptor_TopolTool.hxx>
#include <Contap_ContAna.hxx>
#include <Contap_Contour.hxx>
#include <Contap_IType.hxx>
#include <Contap_Line.hxx>
#include <Approx_MCurvesToBSpCurve.hxx>
#include <GeomFill_Coons.hxx>
#include <GeomFill_CoonsAlgPatch.hxx>
#include <GeomFill_CorrectedFrenet.hxx>
#include <GeomFill_Curved.hxx>
#include <GeomFill_CurveAndTrihedron.hxx>
#include <GeomFill_DiscreteTrihedron.hxx>
#include <GeomFill_DraftTrihedron.hxx>
#include <GeomFill_EvolvedSection.hxx>
#include <GeomFill_Sweep.hxx>
#include <GeomFill_UniformSection.hxx>
#include <GeomInt_IntSS.hxx>
#include <IntSurf_PntOn2S.hxx>
#include <Law_Constant.hxx>
#include <GeomFill_ConstrainedFilling.hxx>
#include <GeomFill_SimpleBound.hxx>
#include <ShapeCustom_Surface.hxx>
#include <ShapeUpgrade_SplitSurfaceContinuity.hxx>
#include <TColGeom_Array2OfBezierSurface.hxx>
#include <TColStd_HSequenceOfReal.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepAdaptor_CompCurve.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <GeomLProp_SLProps.hxx>
#include <TopExp_Explorer.hxx>
#include <TopAbs.hxx>
#include <TopoDS.hxx>
#include <BRep_Tool.hxx>
#include <GeomAPI_ExtremaSurfaceSurface.hxx>

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

// MARK: - Batch Surface Evaluation (v0.29.0)

#include <GeomGridEval_Surface.hxx>

int32_t OCCTSurfaceEvaluateGrid(OCCTSurfaceRef surface,
                                 const double* uParams, int32_t uCount,
                                 const double* vParams, int32_t vCount,
                                 double* outXYZ) {
    if (!surface || surface->surface.IsNull() || !uParams || !vParams || !outXYZ
        || uCount <= 0 || vCount <= 0) return 0;
    try {
        GeomGridEval_Surface evaluator(surface->surface);

        NCollection_Array1<double> uArr(1, uCount);
        for (int32_t i = 0; i < uCount; i++) {
            uArr.SetValue(i + 1, uParams[i]);
        }
        NCollection_Array1<double> vArr(1, vCount);
        for (int32_t i = 0; i < vCount; i++) {
            vArr.SetValue(i + 1, vParams[i]);
        }

        NCollection_Array2<gp_Pnt> results = evaluator.EvaluateGrid(uArr, vArr);
        int32_t total = uCount * vCount;
        int32_t idx = 0;
        // Row-major: v (rows) varies slowest, u (cols) varies fastest
        for (int32_t iv = 1; iv <= vCount; iv++) {
            for (int32_t iu = 1; iu <= uCount; iu++) {
                const gp_Pnt& pt = results.Value(iu, iv);
                outXYZ[idx*3]   = pt.X();
                outXYZ[idx*3+1] = pt.Y();
                outXYZ[idx*3+2] = pt.Z();
                idx++;
            }
        }
        return total;
    } catch (...) {
        return 0;
    }
}

// MARK: - Curve-Surface Intersection (v0.30.0)

#include <GeomAPI_IntCS.hxx>

int32_t OCCTCurve3DIntersectSurface(OCCTCurve3DRef curve, OCCTSurfaceRef surface,
                                     OCCTCurveSurfaceIntersection* outHits, int32_t maxHits) {
    if (!curve || curve->curve.IsNull() || !surface || surface->surface.IsNull() || !outHits || maxHits <= 0) return 0;
    try {
        GeomAPI_IntCS inter(curve->curve, surface->surface);
        if (!inter.IsDone()) return 0;
        int32_t nb = inter.NbPoints();
        int32_t count = (nb < maxHits) ? nb : maxHits;
        for (int32_t i = 0; i < count; i++) {
            gp_Pnt pt = inter.Point(i + 1);
            double w, u, v;
            inter.Parameters(i + 1, u, v, w);
            outHits[i].point[0] = pt.X();
            outHits[i].point[1] = pt.Y();
            outHits[i].point[2] = pt.Z();
            outHits[i].paramCurve = w;
            outHits[i].paramU = u;
            outHits[i].paramV = v;
        }
        return count;
    } catch (...) {
        return 0;
    }
}

// MARK: - Surface-Surface Intersection (v0.30.0)

#include <GeomAPI_IntSS.hxx>

int32_t OCCTSurfaceIntersect(OCCTSurfaceRef s1, OCCTSurfaceRef s2, double tolerance,
                              OCCTCurve3DRef* outCurves, int32_t maxCurves) {
    if (!s1 || s1->surface.IsNull() || !s2 || s2->surface.IsNull() || !outCurves || maxCurves <= 0) return 0;
    try {
        GeomAPI_IntSS inter(s1->surface, s2->surface, tolerance);
        if (!inter.IsDone()) return 0;
        int32_t nb = inter.NbLines();
        int32_t count = (nb < maxCurves) ? nb : maxCurves;
        for (int32_t i = 0; i < count; i++) {
            Handle(Geom_Curve) c = inter.Line(i + 1);
            if (c.IsNull()) {
                outCurves[i] = nullptr;
            } else {
                outCurves[i] = new OCCTCurve3D(c);
            }
        }
        return count;
    } catch (...) {
        return 0;
    }
}

// MARK: - Curve-Surface Distance (v0.30.0)

#include <GeomAPI_ExtremaCurveSurface.hxx>

double OCCTCurve3DDistanceToSurface(OCCTCurve3DRef curve, OCCTSurfaceRef surface) {
    if (!curve || curve->curve.IsNull() || !surface || surface->surface.IsNull()) return -1.0;
    try {
        GeomAPI_ExtremaCurveSurface extrema(curve->curve, surface->surface);
        if (extrema.NbExtrema() == 0) return -1.0;
        return extrema.LowerDistance();
    } catch (...) {
        return -1.0;
    }
}

// MARK: - Surface to Analytical (v0.30.0)

#include <GeomConvert_SurfToAnaSurf.hxx>

OCCTSurfaceRef OCCTSurfaceToAnalytical(OCCTSurfaceRef surface, double tolerance) {
    if (!surface || surface->surface.IsNull()) return nullptr;
    try {
        GeomConvert_SurfToAnaSurf converter(surface->surface);
        Handle(Geom_Surface) result = converter.ConvertToAnalytical(tolerance);
        if (result.IsNull()) return nullptr;
        // If the result is the same handle, it was already analytical or couldn't convert
        if (result == surface->surface) return nullptr;
        return new OCCTSurface(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Canonical Recognition (v0.30.0)

#include <ShapeAnalysis_CanonicalRecognition.hxx>
#include <gp_Elips.hxx>

OCCTCanonicalForm OCCTShapeRecognizeCanonical(OCCTShapeRef shape, double tolerance) {
    OCCTCanonicalForm result = {};
    if (!shape) return result;
    try {
        ShapeAnalysis_CanonicalRecognition recog(shape->shape);
        gp_Pln pln;
        if (recog.IsPlane(tolerance, pln)) {
            result.type = 1;
            result.origin[0] = pln.Location().X();
            result.origin[1] = pln.Location().Y();
            result.origin[2] = pln.Location().Z();
            result.direction[0] = pln.Axis().Direction().X();
            result.direction[1] = pln.Axis().Direction().Y();
            result.direction[2] = pln.Axis().Direction().Z();
            result.gap = recog.GetGap();
            return result;
        }
        gp_Cylinder cyl;
        if (recog.IsCylinder(tolerance, cyl)) {
            result.type = 2;
            result.origin[0] = cyl.Location().X();
            result.origin[1] = cyl.Location().Y();
            result.origin[2] = cyl.Location().Z();
            result.direction[0] = cyl.Axis().Direction().X();
            result.direction[1] = cyl.Axis().Direction().Y();
            result.direction[2] = cyl.Axis().Direction().Z();
            result.radius = cyl.Radius();
            result.gap = recog.GetGap();
            return result;
        }
        gp_Cone cone;
        if (recog.IsCone(tolerance, cone)) {
            result.type = 3;
            result.origin[0] = cone.Location().X();
            result.origin[1] = cone.Location().Y();
            result.origin[2] = cone.Location().Z();
            result.direction[0] = cone.Axis().Direction().X();
            result.direction[1] = cone.Axis().Direction().Y();
            result.direction[2] = cone.Axis().Direction().Z();
            result.radius = cone.RefRadius();
            result.radius2 = cone.SemiAngle();
            result.gap = recog.GetGap();
            return result;
        }
        gp_Sphere sph;
        if (recog.IsSphere(tolerance, sph)) {
            result.type = 4;
            result.origin[0] = sph.Location().X();
            result.origin[1] = sph.Location().Y();
            result.origin[2] = sph.Location().Z();
            result.direction[0] = sph.Position().Direction().X();
            result.direction[1] = sph.Position().Direction().Y();
            result.direction[2] = sph.Position().Direction().Z();
            result.radius = sph.Radius();
            result.gap = recog.GetGap();
            return result;
        }
        gp_Lin lin;
        if (recog.IsLine(tolerance, lin)) {
            result.type = 5;
            result.origin[0] = lin.Location().X();
            result.origin[1] = lin.Location().Y();
            result.origin[2] = lin.Location().Z();
            result.direction[0] = lin.Direction().X();
            result.direction[1] = lin.Direction().Y();
            result.direction[2] = lin.Direction().Z();
            result.gap = recog.GetGap();
            return result;
        }
        gp_Circ circ;
        if (recog.IsCircle(tolerance, circ)) {
            result.type = 6;
            result.origin[0] = circ.Location().X();
            result.origin[1] = circ.Location().Y();
            result.origin[2] = circ.Location().Z();
            result.direction[0] = circ.Axis().Direction().X();
            result.direction[1] = circ.Axis().Direction().Y();
            result.direction[2] = circ.Axis().Direction().Z();
            result.radius = circ.Radius();
            result.gap = recog.GetGap();
            return result;
        }
        gp_Elips elips;
        if (recog.IsEllipse(tolerance, elips)) {
            result.type = 7;
            result.origin[0] = elips.Location().X();
            result.origin[1] = elips.Location().Y();
            result.origin[2] = elips.Location().Z();
            result.direction[0] = elips.Axis().Direction().X();
            result.direction[1] = elips.Axis().Direction().Y();
            result.direction[2] = elips.Axis().Direction().Z();
            result.radius = elips.MajorRadius();
            result.radius2 = elips.MinorRadius();
            result.gap = recog.GetGap();
            return result;
        }
        return result;
    } catch (...) {
        return result;
    }
}

// MARK: - Bezier Surface Fill (v0.31.0)

#include <GeomFill_BezierCurves.hxx>
#include <GeomFill_FillingStyle.hxx>
#include <Geom_BezierCurve.hxx>
#include <Geom_BezierSurface.hxx>

OCCTSurfaceRef OCCTSurfaceBezierFill4(OCCTCurve3DRef c1, OCCTCurve3DRef c2,
                                        OCCTCurve3DRef c3, OCCTCurve3DRef c4,
                                        int32_t fillStyle) {
    if (!c1 || c1->curve.IsNull() ||
        !c2 || c2->curve.IsNull() ||
        !c3 || c3->curve.IsNull() ||
        !c4 || c4->curve.IsNull()) return nullptr;
    try {
        Handle(Geom_BezierCurve) bc1 = Handle(Geom_BezierCurve)::DownCast(c1->curve);
        Handle(Geom_BezierCurve) bc2 = Handle(Geom_BezierCurve)::DownCast(c2->curve);
        Handle(Geom_BezierCurve) bc3 = Handle(Geom_BezierCurve)::DownCast(c3->curve);
        Handle(Geom_BezierCurve) bc4 = Handle(Geom_BezierCurve)::DownCast(c4->curve);
        if (bc1.IsNull() || bc2.IsNull() || bc3.IsNull() || bc4.IsNull()) return nullptr;
        GeomFill_FillingStyle style = GeomFill_StretchStyle;
        if (fillStyle == 1) style = GeomFill_CoonsStyle;
        else if (fillStyle == 2) style = GeomFill_CurvedStyle;
        GeomFill_BezierCurves filler(bc1, bc2, bc3, bc4, style);
        Handle(Geom_BezierSurface) surf = filler.Surface();
        if (surf.IsNull()) return nullptr;
        return new OCCTSurface(surf);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceBezierFill2(OCCTCurve3DRef c1, OCCTCurve3DRef c2,
                                        int32_t fillStyle) {
    if (!c1 || c1->curve.IsNull() ||
        !c2 || c2->curve.IsNull()) return nullptr;
    try {
        Handle(Geom_BezierCurve) bc1 = Handle(Geom_BezierCurve)::DownCast(c1->curve);
        Handle(Geom_BezierCurve) bc2 = Handle(Geom_BezierCurve)::DownCast(c2->curve);
        if (bc1.IsNull() || bc2.IsNull()) return nullptr;
        GeomFill_FillingStyle style = GeomFill_StretchStyle;
        if (fillStyle == 1) style = GeomFill_CoonsStyle;
        else if (fillStyle == 2) style = GeomFill_CurvedStyle;
        GeomFill_BezierCurves filler(bc1, bc2, style);
        Handle(Geom_BezierSurface) surf = filler.Surface();
        if (surf.IsNull()) return nullptr;
        return new OCCTSurface(surf);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Surface-Surface Intersection (v0.35.0)

#include <GeomAPI_IntSS.hxx>

int32_t OCCTSurfaceSurfaceIntersect(OCCTSurfaceRef surface1, OCCTSurfaceRef surface2,
                                     double tolerance,
                                     OCCTCurve3DRef* outCurves, int32_t maxCurves) {
    if (!surface1 || !surface2 || !outCurves || maxCurves < 1) return 0;
    if (surface1->surface.IsNull() || surface2->surface.IsNull()) return 0;
    try {
        GeomAPI_IntSS intersector(surface1->surface, surface2->surface, tolerance);
        if (!intersector.IsDone()) return 0;
        int32_t nbLines = intersector.NbLines();
        int32_t count = std::min(nbLines, maxCurves);
        for (int32_t i = 0; i < count; ++i) {
            Handle(Geom_Curve) curve = intersector.Line(i + 1); // 1-based
            if (curve.IsNull()) {
                outCurves[i] = nullptr;
            } else {
                outCurves[i] = new OCCTCurve3D(curve);
            }
        }
        return count;
    } catch (...) {
        return 0;
    }
}

// MARK: - Curve-Surface Intersection (v0.35.0)

#include <GeomAPI_IntCS.hxx>

int32_t OCCTCurveSurfaceIntersect(OCCTCurve3DRef curve, OCCTSurfaceRef surface,
                                   OCCTCurveSurfacePoint* outPoints, int32_t maxPoints) {
    if (!curve || !surface || !outPoints || maxPoints < 1) return 0;
    if (curve->curve.IsNull() || surface->surface.IsNull()) return 0;
    try {
        GeomAPI_IntCS intersector(curve->curve, surface->surface);
        if (!intersector.IsDone()) return 0;
        int32_t nbPoints = intersector.NbPoints();
        int32_t count = std::min(nbPoints, maxPoints);
        for (int32_t i = 0; i < count; ++i) {
            gp_Pnt pt = intersector.Point(i + 1);
            double u, v, w;
            intersector.Parameters(i + 1, u, v, w);
            outPoints[i].x = pt.X();
            outPoints[i].y = pt.Y();
            outPoints[i].z = pt.Z();
            outPoints[i].u = u;
            outPoints[i].v = v;
            outPoints[i].w = w;
        }
        return count;
    } catch (...) {
        return 0;
    }
}

// MARK: - Surface to Bezier Patches (v0.36.0)

#include <GeomConvert_BSplineSurfaceToBezierSurface.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_BezierSurface.hxx>

int32_t OCCTSurfaceToBezierPatches(OCCTSurfaceRef surface,
                                    OCCTSurfaceRef* outPatches, int32_t maxPatches) {
    if (!surface || !outPatches || maxPatches < 1) return 0;
    if (surface->surface.IsNull()) return 0;
    try {
        // First convert to BSpline if needed
        Handle(Geom_BSplineSurface) bspline = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
        if (bspline.IsNull()) {
            // Try approximate conversion
            Handle(Geom_Surface) surf = surface->surface;
            // Use ShapeConstruct to convert
            bspline = GeomConvert::SurfaceToBSplineSurface(surf);
            if (bspline.IsNull()) return 0;
        }
        GeomConvert_BSplineSurfaceToBezierSurface converter(bspline);
        int32_t nbU = converter.NbUPatches();
        int32_t nbV = converter.NbVPatches();
        int32_t total = nbU * nbV;
        int32_t count = std::min(total, maxPatches);
        int32_t idx = 0;
        for (int32_t i = 1; i <= nbU && idx < count; ++i) {
            for (int32_t j = 1; j <= nbV && idx < count; ++j) {
                Handle(Geom_BezierSurface) patch = converter.Patch(i, j);
                if (!patch.IsNull()) {
                    outPatches[idx] = new OCCTSurface(patch);
                    idx++;
                } else {
                    outPatches[idx] = nullptr;
                    idx++;
                }
            }
        }
        return idx;
    } catch (...) {
        return 0;
    }
}

// MARK: - Surface Singularity Analysis (v0.37.0)

#include <ShapeAnalysis_Surface.hxx>

int32_t OCCTSurfaceSingularityCount(OCCTSurfaceRef surface, double tolerance) {
    if (!surface || surface->surface.IsNull()) return 0;
    try {
        ShapeAnalysis_Surface analyzer(surface->surface);
        return analyzer.NbSingularities(tolerance);
    } catch (...) {
        return 0;
    }
}

bool OCCTSurfaceIsDegenerated(OCCTSurfaceRef surface, double x, double y, double z, double tolerance) {
    if (!surface || surface->surface.IsNull()) return false;
    try {
        ShapeAnalysis_Surface analyzer(surface->surface);
        gp_Pnt point(x, y, z);
        return analyzer.IsDegenerated(point, tolerance);
    } catch (...) {
        return false;
    }
}


static Handle(Geom_BSplineCurve) toBSplineCurve(const Handle(Geom_Curve)& curve) {
    Handle(Geom_BSplineCurve) bsc = Handle(Geom_BSplineCurve)::DownCast(curve);
    if (!bsc.IsNull()) {
        // Re-convert to ensure consistent parameterization
        return GeomConvert::CurveToBSplineCurve(curve, Convert_QuasiAngular);
    }
    // Convert any Geom_Curve to BSpline
    return GeomConvert::CurveToBSplineCurve(curve, Convert_QuasiAngular);
}

OCCTSurfaceRef OCCTSurfaceFillBSpline2Curves(OCCTCurve3DRef curve1, OCCTCurve3DRef curve2,
                                               int32_t fillStyle) {
    if (!curve1 || !curve2) return nullptr;
    try {
        Handle(Geom_BSplineCurve) c1 = toBSplineCurve(curve1->curve);
        Handle(Geom_BSplineCurve) c2 = toBSplineCurve(curve2->curve);
        if (c1.IsNull() || c2.IsNull()) return nullptr;

        GeomFill_FillingStyle style = GeomFill_StretchStyle;
        if (fillStyle == 1) style = GeomFill_CoonsStyle;
        else if (fillStyle == 2) style = GeomFill_CurvedStyle;

        GeomFill_BSplineCurves filler(c1, c2, style);
        Handle(Geom_BSplineSurface) surf = filler.Surface();
        if (surf.IsNull()) return nullptr;
        return new OCCTSurface(surf);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceFillBSpline4Curves(OCCTCurve3DRef c1, OCCTCurve3DRef c2,
                                               OCCTCurve3DRef c3, OCCTCurve3DRef c4,
                                               int32_t fillStyle) {
    if (!c1 || !c2 || !c3 || !c4) return nullptr;
    try {
        Handle(Geom_BSplineCurve) bc1 = toBSplineCurve(c1->curve);
        Handle(Geom_BSplineCurve) bc2 = toBSplineCurve(c2->curve);
        Handle(Geom_BSplineCurve) bc3 = toBSplineCurve(c3->curve);
        Handle(Geom_BSplineCurve) bc4 = toBSplineCurve(c4->curve);
        if (bc1.IsNull() || bc2.IsNull() || bc3.IsNull() || bc4.IsNull()) return nullptr;

        GeomFill_FillingStyle style = GeomFill_StretchStyle;
        if (fillStyle == 1) style = GeomFill_CoonsStyle;
        else if (fillStyle == 2) style = GeomFill_CurvedStyle;

        GeomFill_BSplineCurves filler(bc1, bc2, bc3, bc4, style);
        Handle(Geom_BSplineSurface) surf = filler.Surface();
        if (surf.IsNull()) return nullptr;
        return new OCCTSurface(surf);
    } catch (...) {
        return nullptr;
    }
}
// MARK: - v0.44.0: Surface Extrema, Curve-on-Surface Check, Ellipse Arc, Edge Connect, Bezier Convert

#include <GeomAPI_ExtremaSurfaceSurface.hxx>
#include <BRepLib_CheckCurveOnSurface.hxx>
#include <GC_MakeArcOfEllipse.hxx>
#include <gp_Elips.hxx>
#include <ShapeFix_EdgeConnect.hxx>
#include <ShapeUpgrade_ShapeConvertToBezier.hxx>
// v0.45.0
#include <BRepFill_Filling.hxx>
#include <GeomAbs_Shape.hxx>
#include <BRepExtrema_SelfIntersection.hxx>
#include <BRepGProp_Face.hxx>
#include <ShapeAnalysis_WireOrder.hxx>

int32_t OCCTSurfaceExtrema(OCCTSurfaceRef s1, OCCTSurfaceRef s2,
                            double u1Min, double u1Max, double v1Min, double v1Max,
                            double u2Min, double u2Max, double v2Min, double v2Max,
                            OCCTSurfaceExtremaResult* outResult) {
    if (!s1 || !s2 || !outResult) return 0;
    try {
        GeomAPI_ExtremaSurfaceSurface extrema(
            s1->surface, s2->surface,
            u1Min, u1Max, v1Min, v1Max,
            u2Min, u2Max, v2Min, v2Max);

        int32_t nb = extrema.NbExtrema();
        if (nb <= 0) return 0;

        outResult->distance = extrema.LowerDistance();
        gp_Pnt p1, p2;
        extrema.NearestPoints(p1, p2);
        outResult->p1X = p1.X(); outResult->p1Y = p1.Y(); outResult->p1Z = p1.Z();
        outResult->p2X = p2.X(); outResult->p2Y = p2.Y(); outResult->p2Z = p2.Z();
        extrema.LowerDistanceParameters(outResult->u1, outResult->v1,
                                         outResult->u2, outResult->v2);
        return nb;
    } catch (...) {
        return 0;
    }
}

bool OCCTShapeCheckCurveOnSurface(OCCTShapeRef shape, double* outMaxDist, double* outMaxParam) {
    if (!shape || !outMaxDist || !outMaxParam) return false;
    try {
        double globalMaxDist = 0;
        double globalMaxParam = 0;
        bool anyChecked = false;

        for (TopExp_Explorer fExp(shape->shape, TopAbs_FACE); fExp.More(); fExp.Next()) {
            TopoDS_Face face = TopoDS::Face(fExp.Current());
            for (TopExp_Explorer eExp(face, TopAbs_EDGE); eExp.More(); eExp.Next()) {
                TopoDS_Edge edge = TopoDS::Edge(eExp.Current());
                double f, l;
                Handle(Geom2d_Curve) pcurve = BRep_Tool::CurveOnSurface(edge, face, f, l);
                if (pcurve.IsNull()) continue;

                BRepLib_CheckCurveOnSurface checker(edge, face);
                checker.Perform();
                if (checker.IsDone()) {
                    double dist = checker.MaxDistance();
                    if (dist > globalMaxDist) {
                        globalMaxDist = dist;
                        globalMaxParam = checker.MaxParameter();
                    }
                    anyChecked = true;
                }
            }
        }

        *outMaxDist = globalMaxDist;
        *outMaxParam = globalMaxParam;
        return anyChecked;
    } catch (...) {
        return false;
    }
}

// MARK: - GeomFill_ConstrainedFilling (v0.47)
// --- GeomFill_ConstrainedFilling ---

OCCTShapeRef OCCTGeomFillConstrained(OCCTEdgeRef edge1, OCCTEdgeRef edge2,
                                      OCCTEdgeRef edge3, OCCTEdgeRef edge4,
                                      int32_t maxDeg, int32_t maxSeg) {
    if (!edge1 || !edge2 || !edge3) return nullptr;
    try {
        // Extract curves from edges
        auto getCurve = [](const TopoDS_Edge& edge) -> Handle(Geom_TrimmedCurve) {
            double first, last;
            Handle(Geom_Curve) curve = BRep_Tool::Curve(edge, first, last);
            if (curve.IsNull()) return nullptr;
            return new Geom_TrimmedCurve(curve, first, last);
        };

        Handle(Geom_TrimmedCurve) c1 = getCurve(edge1->edge);
        Handle(Geom_TrimmedCurve) c2 = getCurve(edge2->edge);
        Handle(Geom_TrimmedCurve) c3 = getCurve(edge3->edge);
        if (c1.IsNull() || c2.IsNull() || c3.IsNull()) return nullptr;

        Handle(GeomFill_SimpleBound) b1 = new GeomFill_SimpleBound(
            new GeomAdaptor_Curve(c1), 1e-4, 1e-4);
        Handle(GeomFill_SimpleBound) b2 = new GeomFill_SimpleBound(
            new GeomAdaptor_Curve(c2), 1e-4, 1e-4);
        Handle(GeomFill_SimpleBound) b3 = new GeomFill_SimpleBound(
            new GeomAdaptor_Curve(c3), 1e-4, 1e-4);

        GeomFill_ConstrainedFilling filler(maxDeg, maxSeg);

        if (edge4) {
            Handle(Geom_TrimmedCurve) c4 = getCurve(edge4->edge);
            if (c4.IsNull()) return nullptr;
            Handle(GeomFill_SimpleBound) b4 = new GeomFill_SimpleBound(
                new GeomAdaptor_Curve(c4), 1e-4, 1e-4);
            filler.Init(b1, b2, b3, b4);
        } else {
            filler.Init(b1, b2, b3);
        }

        Handle(Geom_BSplineSurface) surface = filler.Surface();
        if (surface.IsNull()) return nullptr;

        // Build a face from the surface
        BRepBuilderAPI_MakeFace faceMaker(surface, 1e-6);
        if (!faceMaker.IsDone()) return nullptr;
        return new OCCTShape(faceMaker.Shape());
    } catch (...) {
        return nullptr;
    }
}

bool OCCTGeomFillConstrainedInfo(OCCTShapeRef face, OCCTConstrainedFillingInfo* info) {
    if (!face || !info) return false;
    try {
        // Extract the BSpline surface from the face
        for (TopExp_Explorer exp(face->shape, TopAbs_FACE); exp.More(); exp.Next()) {
            TopoDS_Face f = TopoDS::Face(exp.Current());
            Handle(Geom_Surface) surf = BRep_Tool::Surface(f);
            Handle(Geom_BSplineSurface) bspline = Handle(Geom_BSplineSurface)::DownCast(surf);
            if (!bspline.IsNull()) {
                info->isValid = true;
                info->uDegree = bspline->UDegree();
                info->vDegree = bspline->VDegree();
                info->uPoles = bspline->NbUPoles();
                info->vPoles = bspline->NbVPoles();
                return true;
            }
        }
        info->isValid = false;
        return false;
    } catch (...) {
        return false;
    }
}

// MARK: - Surface Value-of-UV / Next-Value-of-UV (v0.49)
// --- ShapeAnalysis_Surface expansion ---

OCCTSurfaceUVResult OCCTSurfaceValueOfUV(OCCTSurfaceRef surface,
    double px, double py, double pz, double precision) {
    OCCTSurfaceUVResult result = {};
    if (!surface) return result;
    try {
        Handle(ShapeAnalysis_Surface) sa = new ShapeAnalysis_Surface(surface->surface);
        gp_Pnt2d uv = sa->ValueOfUV(gp_Pnt(px, py, pz), precision);
        result.u = uv.X();
        result.v = uv.Y();
        result.gap = sa->Gap();
        return result;
    } catch (...) {
        return result;
    }
}

OCCTSurfaceUVResult OCCTSurfaceNextValueOfUV(OCCTSurfaceRef surface,
    double prevU, double prevV, double px, double py, double pz, double precision) {
    OCCTSurfaceUVResult result = {};
    if (!surface) return result;
    try {
        Handle(ShapeAnalysis_Surface) sa = new ShapeAnalysis_Surface(surface->surface);
        gp_Pnt2d uv = sa->NextValueOfUV(gp_Pnt2d(prevU, prevV), gp_Pnt(px, py, pz), precision);
        result.u = uv.X();
        result.v = uv.Y();
        result.gap = sa->Gap();
        return result;
    } catch (...) {
        return result;
    }
}

// MARK: - Surface Makers from Axis/Points/Normal (v0.50)
OCCTSurfaceRef OCCTSurfaceConicalFromAxis(
    double axisX, double axisY, double axisZ,
    double dirX, double dirY, double dirZ,
    double semiAngle, double radius) {
    try {
        gp_Ax2 ax(gp_Pnt(axisX, axisY, axisZ), gp_Dir(dirX, dirY, dirZ));
        GC_MakeConicalSurface maker(ax, semiAngle, radius);
        if (!maker.IsDone()) return nullptr;
        Handle(Geom_ConicalSurface) surf = maker.Value();
        if (surf.IsNull()) return nullptr;
        auto* ref = new OCCTSurface();
        ref->surface = surf;
        return ref;
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceConicalFromPointsRadii(
    double p1x, double p1y, double p1z,
    double p2x, double p2y, double p2z,
    double r1, double r2) {
    try {
        GC_MakeConicalSurface maker(gp_Pnt(p1x, p1y, p1z), gp_Pnt(p2x, p2y, p2z), r1, r2);
        if (!maker.IsDone()) return nullptr;
        Handle(Geom_ConicalSurface) surf = maker.Value();
        if (surf.IsNull()) return nullptr;
        auto* ref = new OCCTSurface();
        ref->surface = surf;
        return ref;
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceCylindricalFromAxis(
    double axisX, double axisY, double axisZ,
    double dirX, double dirY, double dirZ,
    double radius) {
    try {
        gp_Ax2 ax(gp_Pnt(axisX, axisY, axisZ), gp_Dir(dirX, dirY, dirZ));
        GC_MakeCylindricalSurface maker(ax, radius);
        if (!maker.IsDone()) return nullptr;
        Handle(Geom_CylindricalSurface) surf = maker.Value();
        if (surf.IsNull()) return nullptr;
        auto* ref = new OCCTSurface();
        ref->surface = surf;
        return ref;
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceCylindricalFromPoints(
    double p1x, double p1y, double p1z,
    double p2x, double p2y, double p2z,
    double p3x, double p3y, double p3z) {
    try {
        GC_MakeCylindricalSurface maker(
            gp_Pnt(p1x, p1y, p1z), gp_Pnt(p2x, p2y, p2z), gp_Pnt(p3x, p3y, p3z));
        if (!maker.IsDone()) return nullptr;
        Handle(Geom_CylindricalSurface) surf = maker.Value();
        if (surf.IsNull()) return nullptr;
        auto* ref = new OCCTSurface();
        ref->surface = surf;
        return ref;
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfacePlaneFromPoints(
    double p1x, double p1y, double p1z,
    double p2x, double p2y, double p2z,
    double p3x, double p3y, double p3z) {
    try {
        GC_MakePlane maker(gp_Pnt(p1x, p1y, p1z), gp_Pnt(p2x, p2y, p2z), gp_Pnt(p3x, p3y, p3z));
        if (!maker.IsDone()) return nullptr;
        Handle(Geom_Plane) plane = maker.Value();
        if (plane.IsNull()) return nullptr;
        auto* ref = new OCCTSurface();
        ref->surface = plane;
        return ref;
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfacePlaneFromPointNormal(
    double px, double py, double pz,
    double nx, double ny, double nz) {
    try {
        GC_MakePlane maker(gp_Pnt(px, py, pz), gp_Dir(nx, ny, nz));
        if (!maker.IsDone()) return nullptr;
        Handle(Geom_Plane) plane = maker.Value();
        if (plane.IsNull()) return nullptr;
        auto* ref = new OCCTSurface();
        ref->surface = plane;
        return ref;
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceTrimmedCone(
    double p1x, double p1y, double p1z,
    double p2x, double p2y, double p2z,
    double r1, double r2) {
    try {
        GC_MakeTrimmedCone maker(gp_Pnt(p1x, p1y, p1z), gp_Pnt(p2x, p2y, p2z), r1, r2);
        if (!maker.IsDone()) return nullptr;
        Handle(Geom_RectangularTrimmedSurface) surf = maker.Value();
        if (surf.IsNull()) return nullptr;
        auto* ref = new OCCTSurface();
        ref->surface = surf;
        return ref;
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceTrimmedCylinder(
    double axisX, double axisY, double axisZ,
    double dirX, double dirY, double dirZ,
    double radius, double height) {
    try {
        gp_Ax1 ax(gp_Pnt(axisX, axisY, axisZ), gp_Dir(dirX, dirY, dirZ));
        GC_MakeTrimmedCylinder maker(ax, radius, height);
        if (!maker.IsDone()) return nullptr;
        Handle(Geom_RectangularTrimmedSurface) surf = maker.Value();
        if (surf.IsNull()) return nullptr;
        auto* ref = new OCCTSurface();
        ref->surface = surf;
        return ref;
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Surface KnotSplitting / JoinBezierPatches (v0.50)
OCCTSurfaceKnotSplitResult OCCTSurfaceKnotSplitting(OCCTSurfaceRef surface,
    int32_t uContinuity, int32_t vContinuity) {
    OCCTSurfaceKnotSplitResult result = {};
    if (!surface) return result;
    try {
        Handle(Geom_BSplineSurface) bsurf = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
        if (bsurf.IsNull()) return result;
        GeomConvert_BSplineSurfaceKnotSplitting splitter(bsurf, uContinuity, vContinuity);
        result.nbUSplits = splitter.NbUSplits();
        result.nbVSplits = splitter.NbVSplits();
    } catch (...) {}
    return result;
}

OCCTSurfaceRef OCCTSurfaceJoinBezierPatches(
    const OCCTSurfaceRef* patches, int32_t nRows, int32_t nCols) {
    if (!patches || nRows <= 0 || nCols <= 0) return nullptr;
    try {
        TColGeom_Array2OfBezierSurface bezArray(1, nRows, 1, nCols);
        for (int32_t r = 0; r < nRows; r++) {
            for (int32_t c = 0; c < nCols; c++) {
                auto* sref = patches[r * nCols + c];
                if (!sref) return nullptr;
                Handle(Geom_BezierSurface) bez = Handle(Geom_BezierSurface)::DownCast(sref->surface);
                if (bez.IsNull()) return nullptr;
                bezArray.SetValue(r + 1, c + 1, bez);
            }
        }
        GeomConvert_CompBezierSurfacesToBSplineSurface conv(bezArray);
        if (!conv.IsDone()) return nullptr;
        Handle(Geom_BSplineSurface) bsurf = new Geom_BSplineSurface(
            conv.Poles()->Array2(),
            conv.UKnots()->Array1(), conv.VKnots()->Array1(),
            conv.UMultiplicities()->Array1(), conv.VMultiplicities()->Array1(),
            conv.UDegree(), conv.VDegree());
        if (bsurf.IsNull()) return nullptr;
        auto* ref = new OCCTSurface();
        ref->surface = bsurf;
        return ref;
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Surface ConvertToAnalytical (v0.50)
OCCTSurfaceAnalyticalResult OCCTSurfaceConvertToAnalytical(OCCTSurfaceRef surface, double tolerance) {
    OCCTSurfaceAnalyticalResult result = {};
    if (!surface) return result;
    try {
        ShapeCustom_Surface sc(surface->surface);
        Handle(Geom_Surface) recognized = sc.ConvertToAnalytical(tolerance, Standard_False);
        if (!recognized.IsNull()) {
            auto* ref = new OCCTSurface();
            ref->surface = recognized;
            result.surface = ref;
            result.gap = sc.Gap();
        }
    } catch (...) {}
    return result;
}

// MARK: - Surface SplitByContinuity (v0.50)
OCCTSurfaceContinuitySplitResult OCCTSurfaceSplitByContinuity(OCCTSurfaceRef surface,
    int32_t criterion, double tolerance) {
    OCCTSurfaceContinuitySplitResult result = {};
    if (!surface) return result;
    try {
        Handle(Geom_BSplineSurface) bsurf = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
        if (bsurf.IsNull()) return result;

        Handle(ShapeUpgrade_SplitSurfaceContinuity) splitter = new ShapeUpgrade_SplitSurfaceContinuity();
        splitter->Init(bsurf);
        GeomAbs_Shape cont = GeomAbs_C0;
        if (criterion == 1) cont = GeomAbs_C1;
        else if (criterion == 2) cont = GeomAbs_C2;
        else if (criterion >= 3) cont = GeomAbs_C3;
        splitter->SetCriterion(cont);
        splitter->SetTolerance(tolerance);
        splitter->Perform();

        result.isOk = splitter->Status(ShapeExtend_OK);
        result.wasSplit = splitter->Status(ShapeExtend_DONE1);

        const Handle(TColStd_HSequenceOfReal)& uVals = splitter->USplitValues();
        const Handle(TColStd_HSequenceOfReal)& vVals = splitter->VSplitValues();
        result.nUSplits = uVals.IsNull() ? 0 : uVals->Length();
        result.nVSplits = vVals.IsNull() ? 0 : vVals->Length();
    } catch (...) {}
    return result;
}

// MARK: - Contap Contour Analysis (v0.61)
// MARK: - Contap — Contour Analysis (v0.61.0)

int32_t OCCTContapSphereDir(double cx, double cy, double cz, double radius,
    double dirX, double dirY, double dirZ,
    int32_t* outType, double* outData) {
    if (!outType || !outData) return -1;
    try {
        gp_Sphere sphere(gp_Ax3(gp_Pnt(cx, cy, cz), gp_Dir(0, 0, 1)), radius);
        gp_Dir viewDir(dirX, dirY, dirZ);
        Contap_ContAna contAna;
        contAna.Perform(sphere, viewDir);
        if (!contAna.IsDone()) return -1;
        int32_t nb = contAna.NbContours();
        if (nb > 0) {
            GeomAbs_CurveType ctype = contAna.TypeContour();
            if (ctype == GeomAbs_Circle) {
                *outType = 1; // circle
                gp_Circ circ = contAna.Circle();
                gp_Pnt center = circ.Location();
                outData[0] = center.X();
                outData[1] = center.Y();
                outData[2] = center.Z();
                outData[3] = circ.Radius();
            } else if (ctype == GeomAbs_Line) {
                *outType = 0; // line
                gp_Lin line = contAna.Line(1);
                gp_Pnt loc = line.Location();
                gp_Dir dir = line.Direction();
                outData[0] = loc.X(); outData[1] = loc.Y(); outData[2] = loc.Z();
                outData[3] = dir.X(); outData[4] = dir.Y(); outData[5] = dir.Z();
            } else {
                *outType = 2; // walking/other
            }
        }
        return nb;
    } catch (...) { return -1; }
}

int32_t OCCTContapCylinderDir(double px, double py, double pz,
    double axX, double axY, double axZ, double radius,
    double dirX, double dirY, double dirZ,
    int32_t* outType, double* outData) {
    if (!outType || !outData) return -1;
    try {
        gp_Cylinder cyl(gp_Ax3(gp_Pnt(px, py, pz), gp_Dir(axX, axY, axZ)), radius);
        gp_Dir viewDir(dirX, dirY, dirZ);
        Contap_ContAna contAna;
        contAna.Perform(cyl, viewDir);
        if (!contAna.IsDone()) return -1;
        int32_t nb = contAna.NbContours();
        if (nb > 0) {
            GeomAbs_CurveType ctype = contAna.TypeContour();
            if (ctype == GeomAbs_Line) {
                *outType = 0; // line
                // Return first line
                gp_Lin line = contAna.Line(1);
                gp_Pnt loc = line.Location();
                gp_Dir dir = line.Direction();
                outData[0] = loc.X(); outData[1] = loc.Y(); outData[2] = loc.Z();
                outData[3] = dir.X(); outData[4] = dir.Y(); outData[5] = dir.Z();
            } else if (ctype == GeomAbs_Circle) {
                *outType = 1; // circle
                gp_Circ circ = contAna.Circle();
                gp_Pnt center = circ.Location();
                outData[0] = center.X(); outData[1] = center.Y(); outData[2] = center.Z();
                outData[3] = circ.Radius();
            } else {
                *outType = 2;
            }
        }
        return nb;
    } catch (...) { return -1; }
}

int32_t OCCTContapSphereEye(double cx, double cy, double cz, double radius,
    double eyeX, double eyeY, double eyeZ,
    int32_t* outType, double* outData) {
    if (!outType || !outData) return -1;
    try {
        gp_Sphere sphere(gp_Ax3(gp_Pnt(cx, cy, cz), gp_Dir(0, 0, 1)), radius);
        gp_Pnt eye(eyeX, eyeY, eyeZ);
        Contap_ContAna contAna;
        contAna.Perform(sphere, eye);
        if (!contAna.IsDone()) return -1;
        int32_t nb = contAna.NbContours();
        if (nb > 0) {
            GeomAbs_CurveType ctype = contAna.TypeContour();
            if (ctype == GeomAbs_Circle) {
                *outType = 1;
                gp_Circ circ = contAna.Circle();
                gp_Pnt center = circ.Location();
                outData[0] = center.X(); outData[1] = center.Y(); outData[2] = center.Z();
                outData[3] = circ.Radius();
            } else if (ctype == GeomAbs_Line) {
                *outType = 0;
                gp_Lin line = contAna.Line(1);
                gp_Pnt loc = line.Location();
                gp_Dir dir = line.Direction();
                outData[0] = loc.X(); outData[1] = loc.Y(); outData[2] = loc.Z();
                outData[3] = dir.X(); outData[4] = dir.Y(); outData[5] = dir.Z();
            } else {
                *outType = 2;
            }
        }
        return nb;
    } catch (...) { return -1; }
}

// MARK: - GeomInt_IntSS (v0.63)
// --- GeomInt_IntSS ---

struct OCCTGeomIntSS {
    GeomInt_IntSS intss;
    bool valid;
};

OCCTGeomIntSSRef _Nullable OCCTGeomIntSSCreate(OCCTShapeRef face1, OCCTShapeRef face2, double tolerance) {
    if (!face1 || !face2) return nullptr;
    try {
        TopoDS_Face f1 = TopoDS::Face(face1->shape);
        TopoDS_Face f2 = TopoDS::Face(face2->shape);
        Handle(Geom_Surface) s1 = BRep_Tool::Surface(f1);
        Handle(Geom_Surface) s2 = BRep_Tool::Surface(f2);
        if (s1.IsNull() || s2.IsNull()) return nullptr;
        auto* ref = new OCCTGeomIntSS();
        ref->intss.Perform(s1, s2, tolerance, true, false, false);
        ref->valid = ref->intss.IsDone();
        return ref;
    } catch (...) { return nullptr; }
}

int OCCTGeomIntSSLineCount(OCCTGeomIntSSRef ref) {
    if (!ref) return 0;
    auto* r = static_cast<OCCTGeomIntSS*>(ref);
    if (!r->valid) return 0;
    return r->intss.NbLines();
}

OCCTShapeRef _Nullable OCCTGeomIntSSLine(OCCTGeomIntSSRef ref, int index) {
    if (!ref) return nullptr;
    auto* r = static_cast<OCCTGeomIntSS*>(ref);
    if (!r->valid || index < 1 || index > r->intss.NbLines()) return nullptr;
    try {
        Handle(Geom_Curve) curve = r->intss.Line(index);
        if (curve.IsNull()) return nullptr;
        BRepBuilderAPI_MakeEdge me(curve);
        if (!me.IsDone()) return nullptr;
        return new OCCTShape(me.Edge());
    } catch (...) { return nullptr; }
}

int OCCTGeomIntSSPointCount(OCCTGeomIntSSRef ref) {
    if (!ref) return 0;
    auto* r = static_cast<OCCTGeomIntSS*>(ref);
    if (!r->valid) return 0;
    return r->intss.NbPoints();
}

void OCCTGeomIntSSPoint(OCCTGeomIntSSRef ref, int index, double* x, double* y, double* z) {
    if (!ref || !x || !y || !z) return;
    auto* r = static_cast<OCCTGeomIntSS*>(ref);
    if (!r->valid || index < 1 || index > r->intss.NbPoints()) return;
    try {
        gp_Pnt pt = r->intss.Point(index);
        *x = pt.X(); *y = pt.Y(); *z = pt.Z();
    } catch (...) {}
}

void OCCTGeomIntSSRelease(OCCTGeomIntSSRef ref) {
    if (ref) delete static_cast<OCCTGeomIntSS*>(ref);
}

// MARK: - Contap_Contour (v0.63)
// --- Contap_Contour ---

struct OCCTContapContour {
    Contap_Contour contour;
    bool valid;
    bool empty;
};

OCCTContapContourRef _Nullable OCCTContapContourDirection(OCCTShapeRef faceShape,
    double dx, double dy, double dz) {
    if (!faceShape) return nullptr;
    try {
        TopoDS_Face face = TopoDS::Face(faceShape->shape);
        Handle(BRepAdaptor_Surface) surf = new BRepAdaptor_Surface(face);
        Handle(BRepTopAdaptor_TopolTool) tool = new BRepTopAdaptor_TopolTool(surf);
        auto* ref = new OCCTContapContour();
        ref->contour.Init(gp_Vec(dx, dy, dz));
        ref->contour.Perform(surf, tool);
        ref->valid = ref->contour.IsDone();
        ref->empty = ref->contour.IsEmpty();
        return ref;
    } catch (...) { return nullptr; }
}

OCCTContapContourRef _Nullable OCCTContapContourEye(OCCTShapeRef faceShape,
    double ex, double ey, double ez) {
    if (!faceShape) return nullptr;
    try {
        TopoDS_Face face = TopoDS::Face(faceShape->shape);
        Handle(BRepAdaptor_Surface) surf = new BRepAdaptor_Surface(face);
        Handle(BRepTopAdaptor_TopolTool) tool = new BRepTopAdaptor_TopolTool(surf);
        auto* ref = new OCCTContapContour();
        ref->contour.Init(gp_Pnt(ex, ey, ez));
        ref->contour.Perform(surf, tool);
        ref->valid = ref->contour.IsDone();
        ref->empty = ref->contour.IsEmpty();
        return ref;
    } catch (...) { return nullptr; }
}

int OCCTContapContourLineCount(OCCTContapContourRef ref) {
    if (!ref) return 0;
    auto* r = static_cast<OCCTContapContour*>(ref);
    if (!r->valid || r->empty) return 0;
    return r->contour.NbLines();
}

int OCCTContapContourLinePointCount(OCCTContapContourRef ref, int lineIndex) {
    if (!ref) return 0;
    auto* r = static_cast<OCCTContapContour*>(ref);
    if (!r->valid || r->empty) return 0;
    if (lineIndex < 1 || lineIndex > r->contour.NbLines()) return 0;
    try {
        return r->contour.Line(lineIndex).NbPnts();
    } catch (...) { return 0; }
}

void OCCTContapContourLinePoint(OCCTContapContourRef ref, int lineIndex, int pointIndex,
    double* x, double* y, double* z) {
    if (!ref || !x || !y || !z) return;
    auto* r = static_cast<OCCTContapContour*>(ref);
    if (!r->valid || r->empty) return;
    try {
        const Contap_Line& line = r->contour.Line(lineIndex);
        if (pointIndex < 1 || pointIndex > line.NbPnts()) return;
        gp_Pnt pt = line.Point(pointIndex).Value();
        *x = pt.X(); *y = pt.Y(); *z = pt.Z();
    } catch (...) {}
}

int OCCTContapContourLineType(OCCTContapContourRef ref, int lineIndex) {
    if (!ref) return -1;
    auto* r = static_cast<OCCTContapContour*>(ref);
    if (!r->valid || r->empty) return -1;
    if (lineIndex < 1 || lineIndex > r->contour.NbLines()) return -1;
    try {
        Contap_IType t = r->contour.Line(lineIndex).TypeContour();
        return static_cast<int>(t);
    } catch (...) { return -1; }
}

void OCCTContapContourRelease(OCCTContapContourRef ref) {
    if (ref) delete static_cast<OCCTContapContour*>(ref);
}

// MARK: - GeomFill Trihedron Laws + Coons/Curved Filling Poles (v0.63)
// --- GeomFill Trihedron Laws ---

static OCCTTrihedronFrame makeEmptyFrame() {
    return {0,0,0, 0,0,0, 0,0,0};
}

OCCTTrihedronFrame OCCTGeomFillDraftTrihedron(OCCTShapeRef edgeShape, double param,
    double biNormalX, double biNormalY, double biNormalZ, double angle) {
    if (!edgeShape) return makeEmptyFrame();
    try {
        TopoDS_Edge edge = TopoDS::Edge(edgeShape->shape);
        Handle(BRepAdaptor_Curve) adaptor = new BRepAdaptor_Curve(edge);
        GeomFill_DraftTrihedron draft(gp_Vec(biNormalX, biNormalY, biNormalZ), angle);
        draft.SetCurve(adaptor);
        gp_Vec tangent, normal, binormal;
        if (!draft.D0(param, tangent, normal, binormal)) return makeEmptyFrame();
        return {tangent.X(), tangent.Y(), tangent.Z(),
                normal.X(), normal.Y(), normal.Z(),
                binormal.X(), binormal.Y(), binormal.Z()};
    } catch (...) { return makeEmptyFrame(); }
}

OCCTTrihedronFrame OCCTGeomFillDiscreteTrihedron(OCCTShapeRef edgeShape, double param) {
    if (!edgeShape) return makeEmptyFrame();
    try {
        TopoDS_Edge edge = TopoDS::Edge(edgeShape->shape);
        Handle(BRepAdaptor_Curve) adaptor = new BRepAdaptor_Curve(edge);
        GeomFill_DiscreteTrihedron discrete;
        discrete.SetCurve(adaptor);
        gp_Vec tangent, normal, binormal;
        if (!discrete.D0(param, tangent, normal, binormal)) return makeEmptyFrame();
        return {tangent.X(), tangent.Y(), tangent.Z(),
                normal.X(), normal.Y(), normal.Z(),
                binormal.X(), binormal.Y(), binormal.Z()};
    } catch (...) { return makeEmptyFrame(); }
}

OCCTTrihedronFrame OCCTGeomFillCorrectedFrenet(OCCTShapeRef edgeShape, double param) {
    if (!edgeShape) return makeEmptyFrame();
    try {
        TopoDS_Edge edge = TopoDS::Edge(edgeShape->shape);
        Handle(BRepAdaptor_Curve) adaptor = new BRepAdaptor_Curve(edge);
        GeomFill_CorrectedFrenet corrected;
        corrected.SetCurve(adaptor);
        gp_Vec tangent, normal, binormal;
        if (!corrected.D0(param, tangent, normal, binormal)) return makeEmptyFrame();
        return {tangent.X(), tangent.Y(), tangent.Z(),
                normal.X(), normal.Y(), normal.Z(),
                binormal.X(), binormal.Y(), binormal.Z()};
    } catch (...) { return makeEmptyFrame(); }
}

// --- GeomFill_Coons / GeomFill_Curved ---

// Helper: extract poles from GeomFill_Filling into flat array
// Returns actual pole count (nbU * nbV), outPoints must be pre-sized
static int extractFillingPoles(GeomFill_Filling& filling, double* outPoints, int maxPoints) {
    int nbU = filling.NbUPoles();
    int nbV = filling.NbVPoles();
    int total = nbU * nbV;
    if (total > maxPoints) total = maxPoints;
    NCollection_Array2<gp_Pnt> poles(1, nbU, 1, nbV);
    filling.Poles(poles);
    int idx = 0;
    for (int i = 1; i <= nbU && idx < maxPoints; i++) {
        for (int j = 1; j <= nbV && idx < maxPoints; j++) {
            gp_Pnt pt = poles(i, j);
            outPoints[idx*3]     = pt.X();
            outPoints[idx*3 + 1] = pt.Y();
            outPoints[idx*3 + 2] = pt.Z();
            idx++;
        }
    }
    return total;
}

int OCCTGeomFillCoonsPoles(
    const double* b1, const double* b2, const double* b3, const double* b4,
    int pointsPerSide, double* outPoints, int maxPoints,
    int* outNbU, int* outNbV) {
    if (!b1 || !b2 || !b3 || !b4 || !outPoints || pointsPerSide < 2) return 0;
    try {
        NCollection_Array1<gp_Pnt> P1(1, pointsPerSide), P2(1, pointsPerSide),
                                    P3(1, pointsPerSide), P4(1, pointsPerSide);
        for (int i = 0; i < pointsPerSide; i++) {
            P1(i+1) = gp_Pnt(b1[i*3], b1[i*3+1], b1[i*3+2]);
            P2(i+1) = gp_Pnt(b2[i*3], b2[i*3+1], b2[i*3+2]);
            P3(i+1) = gp_Pnt(b3[i*3], b3[i*3+1], b3[i*3+2]);
            P4(i+1) = gp_Pnt(b4[i*3], b4[i*3+1], b4[i*3+2]);
        }
        GeomFill_Coons coons(P1, P2, P3, P4);
        if (outNbU) *outNbU = coons.NbUPoles();
        if (outNbV) *outNbV = coons.NbVPoles();
        return extractFillingPoles(coons, outPoints, maxPoints);
    } catch (...) { return 0; }
}

int OCCTGeomFillCurvedPoles(
    const double* b1, const double* b2, const double* b3, const double* b4,
    int pointsPerSide, double* outPoints, int maxPoints,
    int* outNbU, int* outNbV) {
    if (!b1 || !b2 || !b3 || !b4 || !outPoints || pointsPerSide < 2) return 0;
    try {
        NCollection_Array1<gp_Pnt> P1(1, pointsPerSide), P2(1, pointsPerSide),
                                    P3(1, pointsPerSide), P4(1, pointsPerSide);
        for (int i = 0; i < pointsPerSide; i++) {
            P1(i+1) = gp_Pnt(b1[i*3], b1[i*3+1], b1[i*3+2]);
            P2(i+1) = gp_Pnt(b2[i*3], b2[i*3+1], b2[i*3+2]);
            P3(i+1) = gp_Pnt(b3[i*3], b3[i*3+1], b3[i*3+2]);
            P4(i+1) = gp_Pnt(b4[i*3], b4[i*3+1], b4[i*3+2]);
        }
        GeomFill_Curved curved(P1, P2, P3, P4);
        if (outNbU) *outNbU = curved.NbUPoles();
        if (outNbV) *outNbV = curved.NbVPoles();
        return extractFillingPoles(curved, outPoints, maxPoints);
    } catch (...) { return 0; }
}

// MARK: - GeomFill_CoonsAlgPatch (v0.63)
// --- GeomFill_CoonsAlgPatch ---

void OCCTGeomFillCoonsAlgPatchEval(
    OCCTShapeRef edge1, OCCTShapeRef edge2, OCCTShapeRef edge3, OCCTShapeRef edge4,
    int evalU, int evalV, double* outPoints) {
    if (!edge1 || !edge2 || !edge3 || !edge4 || !outPoints) return;
    try {
        auto makeAdaptor = [](OCCTShapeRef e) -> Handle(GeomAdaptor_Curve) {
            TopoDS_Edge edge = TopoDS::Edge(e->shape);
            double f, l;
            Handle(Geom_Curve) curve = BRep_Tool::Curve(edge, f, l);
            return new GeomAdaptor_Curve(curve, f, l);
        };
        Handle(GeomAdaptor_Curve) ac1 = makeAdaptor(edge1);
        Handle(GeomAdaptor_Curve) ac2 = makeAdaptor(edge2);
        Handle(GeomAdaptor_Curve) ac3 = makeAdaptor(edge3);
        Handle(GeomAdaptor_Curve) ac4 = makeAdaptor(edge4);

        Handle(GeomFill_SimpleBound) b1 = new GeomFill_SimpleBound(ac1, 1e-3, 1e-3);
        Handle(GeomFill_SimpleBound) b2 = new GeomFill_SimpleBound(ac2, 1e-3, 1e-3);
        Handle(GeomFill_SimpleBound) b3 = new GeomFill_SimpleBound(ac3, 1e-3, 1e-3);
        Handle(GeomFill_SimpleBound) b4 = new GeomFill_SimpleBound(ac4, 1e-3, 1e-3);

        GeomFill_CoonsAlgPatch patch(b1, b2, b3, b4);
        for (int i = 0; i < evalU; i++) {
            for (int j = 0; j < evalV; j++) {
                double u = (evalU > 1) ? (double)i / (evalU - 1) : 0.5;
                double v = (evalV > 1) ? (double)j / (evalV - 1) : 0.5;
                gp_Pnt pt = patch.Value(u, v);
                int idx = (i * evalV + j) * 3;
                outPoints[idx]     = pt.X();
                outPoints[idx + 1] = pt.Y();
                outPoints[idx + 2] = pt.Z();
            }
        }
    } catch (...) {}
}

// MARK: - GeomFill_Sweep (v0.63)
// --- GeomFill_Sweep ---

OCCTShapeRef _Nullable OCCTGeomFillSweep(OCCTShapeRef pathEdge, OCCTShapeRef sectionEdge) {
    if (!pathEdge || !sectionEdge) return nullptr;
    try {
        // Path curve
        TopoDS_Edge path = TopoDS::Edge(pathEdge->shape);
        double pf, pl;
        Handle(Geom_Curve) pathCurve = BRep_Tool::Curve(path, pf, pl);
        if (pathCurve.IsNull()) return nullptr;
        Handle(GeomAdaptor_Curve) pathAdaptor = new GeomAdaptor_Curve(pathCurve, pf, pl);

        // Section curve
        TopoDS_Edge section = TopoDS::Edge(sectionEdge->shape);
        double sf, sl;
        Handle(Geom_Curve) sectionCurve = BRep_Tool::Curve(section, sf, sl);
        if (sectionCurve.IsNull()) return nullptr;

        // Trihedron + location
        Handle(GeomFill_CorrectedFrenet) trihedron = new GeomFill_CorrectedFrenet();
        Handle(GeomFill_CurveAndTrihedron) location = new GeomFill_CurveAndTrihedron(trihedron);
        location->SetCurve(pathAdaptor);

        // Section law
        Handle(GeomFill_UniformSection) sectionLaw = new GeomFill_UniformSection(sectionCurve);

        // Sweep
        GeomFill_Sweep sweep(location);
        sweep.Build(sectionLaw, GeomFill_Location, GeomAbs_C2, 10, 50);
        if (!sweep.IsDone()) return nullptr;

        Handle(Geom_Surface) surface = sweep.Surface();
        if (surface.IsNull()) return nullptr;

        BRepBuilderAPI_MakeFace mf(surface, 1e-6);
        if (!mf.IsDone()) return nullptr;
        return new OCCTShape(mf.Face());
    } catch (...) { return nullptr; }
}

// MARK: - GeomFill_EvolvedSection (v0.63)
// --- GeomFill_EvolvedSection ---

OCCTEvolvedSectionInfo OCCTGeomFillEvolvedSectionInfo(OCCTShapeRef edgeShape) {
    OCCTEvolvedSectionInfo result = {0, 0, 0, false};
    if (!edgeShape) return result;
    try {
        TopoDS_Edge edge = TopoDS::Edge(edgeShape->shape);
        double f, l;
        Handle(Geom_Curve) curve = BRep_Tool::Curve(edge, f, l);
        if (curve.IsNull()) return result;

        Handle(Law_Constant) law = new Law_Constant();
        law->Set(1.0, 0.0, 1.0);
        GeomFill_EvolvedSection evolved(curve, law);

        int nbPoles, nbKnots, degree;
        evolved.SectionShape(nbPoles, nbKnots, degree);
        result.nbPoles = nbPoles;
        result.nbKnots = nbKnots;
        result.degree = degree;
        result.isRational = evolved.IsRational();
    } catch (...) {}
    return result;
}

// MARK: - Adaptor3d_IsoCurve (v0.64)
// --- Adaptor3d_IsoCurve ---

void OCCTAdaptor3dIsoCurveEval(OCCTShapeRef faceShape, int isoType, double param,
    int evalCount, double* outPoints) {
    if (!faceShape || !outPoints || evalCount < 1) return;
    try {
        TopoDS_Face face = TopoDS::Face(faceShape->shape);
        Handle(Geom_Surface) surface = BRep_Tool::Surface(face);
        if (surface.IsNull()) return;
        Handle(GeomAdaptor_Surface) surfAdaptor = new GeomAdaptor_Surface(surface);

        GeomAbs_IsoType type = (isoType == 0) ? GeomAbs_IsoU : GeomAbs_IsoV;
        Adaptor3d_IsoCurve iso(surfAdaptor, type, param);

        double first = iso.FirstParameter();
        double last = iso.LastParameter();
        // Clamp infinite parameters
        if (first < -1e6) first = -1e6;
        if (last > 1e6) last = 1e6;

        for (int i = 0; i < evalCount; i++) {
            double t = (evalCount > 1) ? first + (last - first) * i / (evalCount - 1) : first;
            gp_Pnt pt;
            iso.D0(t, pt);
            outPoints[i*3]     = pt.X();
            outPoints[i*3 + 1] = pt.Y();
            outPoints[i*3 + 2] = pt.Z();
        }
    } catch (...) {}
}

OCCTShapeRef _Nullable OCCTAdaptor3dIsoCurveEdge(OCCTShapeRef faceShape, int isoType,
    double param, double p1, double p2) {
    if (!faceShape) return nullptr;
    try {
        TopoDS_Face face = TopoDS::Face(faceShape->shape);
        Handle(Geom_Surface) surface = BRep_Tool::Surface(face);
        if (surface.IsNull()) return nullptr;

        // Create iso-curve as a Geom_Curve
        Handle(Geom_Curve) isoCurve;
        if (isoType == 0) {
            isoCurve = surface->UIso(param);
        } else {
            isoCurve = surface->VIso(param);
        }
        if (isoCurve.IsNull()) return nullptr;

        BRepBuilderAPI_MakeEdge me(isoCurve, p1, p2);
        if (!me.IsDone()) return nullptr;
        return new OCCTShape(me.Edge());
    } catch (...) { return nullptr; }
}
