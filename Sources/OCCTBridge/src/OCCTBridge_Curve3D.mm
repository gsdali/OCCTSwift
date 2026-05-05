//
//  OCCTBridge_Curve3D.mm
//  OCCTSwift
//
//  Extracted from OCCTBridge.mm — issue #99.
//
//  3D parametric curve cluster (v0.19):
//
//  - Geom_Curve construction (line, circle, ellipse, hyperbola, parabola,
//    Bezier, BSpline, trimmed, offset)
//  - GC makers (segment, circle, arc-of-circle)
//  - Conversion (Bezier <-> BSpline, composite-curve to BSpline,
//    GeomConvert_ApproxCurve)
//  - Sampling (UniformAbscissa, UniformDeflection, TangentialDeflection)
//  - Interpolation + fitting (Geom_BSpline through points)
//  - Local properties (GeomLProp_CLProps)
//  - Tangent / curvature evaluation
//
//  Defines `struct OCCTCurve3D` locally; the matching definition in
//  OCCTBridge.mm has identical layout (ODR-safe across TUs).
//
//  Public C surface unchanged. No symbol changes — pure file move.
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

// === Area-specific OCCT headers ===

#include <Approx_Curve3d.hxx>
#include <Approx_CurveOnSurface.hxx>
#include <Approx_CurvilinearParameter.hxx>
#include <CPnts_UniformDeflection.hxx>
#include <BRep_Tool.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepLib.hxx>
#include <Geom2dAdaptor_Curve.hxx>
#include <GeomAdaptor_Surface.hxx>

#include <GC_MakeArcOfCircle.hxx>
#include <GC_MakeArcOfEllipse.hxx>
#include <GC_MakeArcOfHyperbola.hxx>
#include <GC_MakeArcOfParabola.hxx>
#include <GC_MakeCircle.hxx>
#include <GC_MakeEllipse.hxx>
#include <GC_MakeHyperbola.hxx>
#include <GC_MakeSegment.hxx>
#include <ShapeCustom_Curve.hxx>
#include <ShapeUpgrade_SplitCurve3d.hxx>
#include <TColGeom_HArray1OfCurve.hxx>
#include <TColStd_HSequenceOfReal.hxx>
#include <gp_Hypr.hxx>
#include <gp_Parab.hxx>

#include <GCPnts_TangentialDeflection.hxx>
#include <GCPnts_UniformAbscissa.hxx>
#include <GCPnts_UniformDeflection.hxx>

#include <Geom_BezierCurve.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Curve.hxx>
#include <Geom_Ellipse.hxx>
#include <Geom_Hyperbola.hxx>
#include <Geom_Line.hxx>
#include <Geom_OffsetCurve.hxx>
#include <Geom_Parabola.hxx>
#include <Geom_TrimmedCurve.hxx>

#include <GeomAbs_Shape.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <GeomAPI_Interpolate.hxx>
#include <GeomAPI_PointsToBSpline.hxx>
#include <GeomConvert.hxx>
#include <GeomConvert_ApproxCurve.hxx>
#include <GeomConvert_BSplineCurveToBezierCurve.hxx>
#include <GeomConvert_CompCurveToBSplineCurve.hxx>
#include <GeomLProp_CLProps.hxx>

#include <gp_Ax1.hxx>
#include <gp_Ax2.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>
#include <gp_Trsf.hxx>
#include <gp_Vec.hxx>

#include <TColgp_Array1OfPnt.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColStd_HArray1OfBoolean.hxx>

// MARK: - Curve3D: 3D Parametric Curves (v0.19.0)

#include <Geom_Curve.hxx>
#include <Geom_Line.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Ellipse.hxx>
#include <Geom_Parabola.hxx>
#include <Geom_Hyperbola.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_BezierCurve.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <Geom_OffsetCurve.hxx>
#include <GC_MakeSegment.hxx>
#include <GC_MakeArcOfCircle.hxx>
#include <GC_MakeCircle.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <GeomAPI_Interpolate.hxx>
#include <GeomConvert.hxx>
#include <GeomConvert_BSplineCurveToBezierCurve.hxx>
#include <GeomConvert_CompCurveToBSplineCurve.hxx>
#include <GeomConvert_ApproxCurve.hxx>
#include <GCPnts_TangentialDeflection.hxx>
#include <GCPnts_UniformAbscissa.hxx>
#include <GCPnts_UniformDeflection.hxx>
#include <Bnd_Box.hxx>
#include <BndLib_Add3dCurve.hxx>
#include <CPnts_AbscissaPoint.hxx>
#include <TColgp_HArray1OfPnt.hxx>

void OCCTCurve3DRelease(OCCTCurve3DRef c) {
    delete c;
}

OCCTCurve3DRef OCCTEdgeGetCurve3D(OCCTEdgeRef edge) {
    if (!edge) return nullptr;
    try {
        BRepLib::BuildCurves3d(edge->edge);
        Standard_Real first, last;
        Handle(Geom_Curve) curve = BRep_Tool::Curve(edge->edge, first, last);
        if (curve.IsNull()) return nullptr;
        // Return the raw curve so consumers can DownCast to Geom_Circle /
        // Geom_Line / etc. for typed-property extraction. The edge's
        // parameter range stays available via Edge.parameterBounds.
        return new OCCTCurve3D(curve);
    } catch (...) {
        return nullptr;
    }
}

// Properties

void OCCTCurve3DGetDomain(OCCTCurve3DRef c, double* first, double* last) {
    if (!c || c->curve.IsNull() || !first || !last) return;
    *first = c->curve->FirstParameter();
    *last = c->curve->LastParameter();
}

bool OCCTCurve3DIsClosed(OCCTCurve3DRef c) {
    if (!c || c->curve.IsNull()) return false;
    return c->curve->IsClosed() == Standard_True;
}

bool OCCTCurve3DIsPeriodic(OCCTCurve3DRef c) {
    if (!c || c->curve.IsNull()) return false;
    return c->curve->IsPeriodic() == Standard_True;
}

double OCCTCurve3DGetPeriod(OCCTCurve3DRef c) {
    if (!c || c->curve.IsNull()) return 0.0;
    if (!c->curve->IsPeriodic()) return 0.0;
    return c->curve->Period();
}

// Evaluation

void OCCTCurve3DGetPoint(OCCTCurve3DRef c, double u,
                         double* x, double* y, double* z) {
    if (!c || c->curve.IsNull() || !x || !y || !z) return;
    gp_Pnt p = c->curve->Value(u);
    *x = p.X(); *y = p.Y(); *z = p.Z();
}

void OCCTCurve3DD1(OCCTCurve3DRef c, double u,
                   double* px, double* py, double* pz,
                   double* vx, double* vy, double* vz) {
    if (!c || c->curve.IsNull() || !px || !py || !pz || !vx || !vy || !vz) return;
    gp_Pnt p; gp_Vec v;
    c->curve->D1(u, p, v);
    *px = p.X(); *py = p.Y(); *pz = p.Z();
    *vx = v.X(); *vy = v.Y(); *vz = v.Z();
}

void OCCTCurve3DD2(OCCTCurve3DRef c, double u,
                   double* px, double* py, double* pz,
                   double* v1x, double* v1y, double* v1z,
                   double* v2x, double* v2y, double* v2z) {
    if (!c || c->curve.IsNull() || !px || !py || !pz ||
        !v1x || !v1y || !v1z || !v2x || !v2y || !v2z) return;
    gp_Pnt p; gp_Vec v1, v2;
    c->curve->D2(u, p, v1, v2);
    *px = p.X(); *py = p.Y(); *pz = p.Z();
    *v1x = v1.X(); *v1y = v1.Y(); *v1z = v1.Z();
    *v2x = v2.X(); *v2y = v2.Y(); *v2z = v2.Z();
}

// Primitive Curves

OCCTCurve3DRef OCCTCurve3DCreateLine(double px, double py, double pz,
                                      double dx, double dy, double dz) {
    try {
        gp_Pnt origin(px, py, pz);
        gp_Dir dir(dx, dy, dz);
        Handle(Geom_Line) line = new Geom_Line(origin, dir);
        return new OCCTCurve3D(line);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DCreateSegment(double p1x, double p1y, double p1z,
                                         double p2x, double p2y, double p2z) {
    try {
        gp_Pnt pt1(p1x, p1y, p1z);
        gp_Pnt pt2(p2x, p2y, p2z);
        if (pt1.Distance(pt2) < Precision::Confusion()) return nullptr;
        GC_MakeSegment maker(pt1, pt2);
        if (!maker.IsDone()) return nullptr;
        return new OCCTCurve3D(maker.Value());
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DCreateCircle(double cx, double cy, double cz,
                                        double nx, double ny, double nz,
                                        double radius) {
    try {
        if (radius <= 0) return nullptr;
        gp_Pnt center(cx, cy, cz);
        gp_Dir normal(nx, ny, nz);
        gp_Ax2 axis(center, normal);
        Handle(Geom_Circle) circle = new Geom_Circle(axis, radius);
        return new OCCTCurve3D(circle);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DCreateArcOfCircle(double p1x, double p1y, double p1z,
                                             double p2x, double p2y, double p2z,
                                             double p3x, double p3y, double p3z) {
    try {
        GC_MakeArcOfCircle maker(gp_Pnt(p1x, p1y, p1z),
                                  gp_Pnt(p2x, p2y, p2z),
                                  gp_Pnt(p3x, p3y, p3z));
        if (!maker.IsDone()) return nullptr;
        return new OCCTCurve3D(maker.Value());
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DCreateArc3Points(double p1x, double p1y, double p1z,
                                            double pmx, double pmy, double pmz,
                                            double p2x, double p2y, double p2z) {
    try {
        GC_MakeArcOfCircle maker(gp_Pnt(p1x, p1y, p1z),
                                  gp_Pnt(pmx, pmy, pmz),
                                  gp_Pnt(p2x, p2y, p2z));
        if (!maker.IsDone()) return nullptr;
        return new OCCTCurve3D(maker.Value());
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DCreateEllipse(double cx, double cy, double cz,
                                         double nx, double ny, double nz,
                                         double majorR, double minorR) {
    try {
        if (majorR <= 0 || minorR <= 0 || minorR > majorR) return nullptr;
        gp_Ax2 axis(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz));
        Handle(Geom_Ellipse) ellipse = new Geom_Ellipse(axis, majorR, minorR);
        return new OCCTCurve3D(ellipse);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DCreateParabola(double cx, double cy, double cz,
                                          double nx, double ny, double nz,
                                          double focal) {
    try {
        if (focal <= 0) return nullptr;
        gp_Ax2 axis(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz));
        Handle(Geom_Parabola) parabola = new Geom_Parabola(axis, focal);
        return new OCCTCurve3D(parabola);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DCreateHyperbola(double cx, double cy, double cz,
                                           double nx, double ny, double nz,
                                           double majorR, double minorR) {
    try {
        if (majorR <= 0 || minorR <= 0) return nullptr;
        gp_Ax2 axis(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz));
        Handle(Geom_Hyperbola) hyp = new Geom_Hyperbola(axis, majorR, minorR);
        return new OCCTCurve3D(hyp);
    } catch (...) {
        return nullptr;
    }
}

// BSpline / Bezier / Interpolation

OCCTCurve3DRef OCCTCurve3DCreateBSpline(const double* poles, int32_t poleCount,
                                         const double* weights,
                                         const double* knots, int32_t knotCount,
                                         const int32_t* multiplicities, int32_t degree) {
    try {
        if (!poles || poleCount < 2 || !knots || knotCount < 2 || !multiplicities || degree < 1)
            return nullptr;

        TColgp_Array1OfPnt pArr(1, poleCount);
        for (int i = 0; i < poleCount; i++)
            pArr.SetValue(i + 1, gp_Pnt(poles[i*3], poles[i*3+1], poles[i*3+2]));

        TColStd_Array1OfReal kArr(1, knotCount);
        for (int i = 0; i < knotCount; i++)
            kArr.SetValue(i + 1, knots[i]);

        TColStd_Array1OfInteger mArr(1, knotCount);
        for (int i = 0; i < knotCount; i++)
            mArr.SetValue(i + 1, multiplicities[i]);

        Handle(Geom_BSplineCurve) bsp;
        if (weights) {
            TColStd_Array1OfReal wArr(1, poleCount);
            for (int i = 0; i < poleCount; i++)
                wArr.SetValue(i + 1, weights[i]);
            bsp = new Geom_BSplineCurve(pArr, wArr, kArr, mArr, degree);
        } else {
            bsp = new Geom_BSplineCurve(pArr, kArr, mArr, degree);
        }
        return new OCCTCurve3D(bsp);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DCreateBezier(const double* poles, int32_t poleCount,
                                        const double* weights) {
    try {
        if (!poles || poleCount < 2) return nullptr;

        TColgp_Array1OfPnt pArr(1, poleCount);
        for (int i = 0; i < poleCount; i++)
            pArr.SetValue(i + 1, gp_Pnt(poles[i*3], poles[i*3+1], poles[i*3+2]));

        Handle(Geom_BezierCurve) bez;
        if (weights) {
            TColStd_Array1OfReal wArr(1, poleCount);
            for (int i = 0; i < poleCount; i++)
                wArr.SetValue(i + 1, weights[i]);
            bez = new Geom_BezierCurve(pArr, wArr);
        } else {
            bez = new Geom_BezierCurve(pArr);
        }
        return new OCCTCurve3D(bez);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DInterpolate(const double* points, int32_t count,
                                       bool closed, double tolerance) {
    try {
        if (!points || count < 2) return nullptr;

        Handle(TColgp_HArray1OfPnt) pts = new TColgp_HArray1OfPnt(1, count);
        for (int i = 0; i < count; i++)
            pts->SetValue(i + 1, gp_Pnt(points[i*3], points[i*3+1], points[i*3+2]));

        GeomAPI_Interpolate interp(pts, closed ? Standard_True : Standard_False, tolerance);
        interp.Perform();
        if (!interp.IsDone()) return nullptr;

        return new OCCTCurve3D(interp.Curve());
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DInterpolateWithTangents(const double* points, int32_t count,
                                                   double stx, double sty, double stz,
                                                   double etx, double ety, double etz,
                                                   double tolerance) {
    try {
        if (!points || count < 2) return nullptr;

        Handle(TColgp_HArray1OfPnt) pts = new TColgp_HArray1OfPnt(1, count);
        for (int i = 0; i < count; i++)
            pts->SetValue(i + 1, gp_Pnt(points[i*3], points[i*3+1], points[i*3+2]));

        GeomAPI_Interpolate interp(pts, Standard_False, tolerance);
        gp_Vec startTan(stx, sty, stz);
        gp_Vec endTan(etx, ety, etz);
        interp.Load(startTan, endTan);
        interp.Perform();
        if (!interp.IsDone()) return nullptr;

        return new OCCTCurve3D(interp.Curve());
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DFitPoints(const double* points, int32_t count,
                                     int32_t minDeg, int32_t maxDeg, double tolerance) {
    try {
        if (!points || count < 2) return nullptr;

        TColgp_Array1OfPnt pArr(1, count);
        for (int i = 0; i < count; i++)
            pArr.SetValue(i + 1, gp_Pnt(points[i*3], points[i*3+1], points[i*3+2]));

        GeomAPI_PointsToBSpline fitter(pArr, minDeg, maxDeg,
                                        GeomAbs_C2, tolerance);
        if (!fitter.IsDone()) return nullptr;

        return new OCCTCurve3D(fitter.Curve());
    } catch (...) {
        return nullptr;
    }
}

// BSpline queries

int32_t OCCTCurve3DGetPoleCount(OCCTCurve3DRef c) {
    if (!c || c->curve.IsNull()) return 0;
    try {
        Handle(Geom_BSplineCurve) bsp = Handle(Geom_BSplineCurve)::DownCast(c->curve);
        if (!bsp.IsNull()) return bsp->NbPoles();
        Handle(Geom_BezierCurve) bez = Handle(Geom_BezierCurve)::DownCast(c->curve);
        if (!bez.IsNull()) return bez->NbPoles();
        return 0;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTCurve3DGetPoles(OCCTCurve3DRef c, double* outXYZ) {
    if (!c || c->curve.IsNull() || !outXYZ) return 0;
    try {
        Handle(Geom_BSplineCurve) bsp = Handle(Geom_BSplineCurve)::DownCast(c->curve);
        if (!bsp.IsNull()) {
            int n = bsp->NbPoles();
            for (int i = 1; i <= n; i++) {
                gp_Pnt p = bsp->Pole(i);
                outXYZ[(i-1)*3] = p.X();
                outXYZ[(i-1)*3+1] = p.Y();
                outXYZ[(i-1)*3+2] = p.Z();
            }
            return n;
        }
        Handle(Geom_BezierCurve) bez = Handle(Geom_BezierCurve)::DownCast(c->curve);
        if (!bez.IsNull()) {
            int n = bez->NbPoles();
            for (int i = 1; i <= n; i++) {
                gp_Pnt p = bez->Pole(i);
                outXYZ[(i-1)*3] = p.X();
                outXYZ[(i-1)*3+1] = p.Y();
                outXYZ[(i-1)*3+2] = p.Z();
            }
            return n;
        }
        return 0;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTCurve3DGetDegree(OCCTCurve3DRef c) {
    if (!c || c->curve.IsNull()) return -1;
    try {
        Handle(Geom_BSplineCurve) bsp = Handle(Geom_BSplineCurve)::DownCast(c->curve);
        if (!bsp.IsNull()) return bsp->Degree();
        Handle(Geom_BezierCurve) bez = Handle(Geom_BezierCurve)::DownCast(c->curve);
        if (!bez.IsNull()) return bez->Degree();
        return -1;
    } catch (...) {
        return -1;
    }
}

// Operations

OCCTCurve3DRef OCCTCurve3DTrim(OCCTCurve3DRef c, double u1, double u2) {
    if (!c || c->curve.IsNull()) return nullptr;
    try {
        Handle(Geom_TrimmedCurve) trimmed = new Geom_TrimmedCurve(c->curve, u1, u2);
        return new OCCTCurve3D(trimmed);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DReversed(OCCTCurve3DRef c) {
    if (!c || c->curve.IsNull()) return nullptr;
    try {
        Handle(Geom_Curve) rev = Handle(Geom_Curve)::DownCast(c->curve->Reversed());
        if (rev.IsNull()) return nullptr;
        return new OCCTCurve3D(rev);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DTranslate(OCCTCurve3DRef c, double dx, double dy, double dz) {
    if (!c || c->curve.IsNull()) return nullptr;
    try {
        Handle(Geom_Curve) copy = Handle(Geom_Curve)::DownCast(c->curve->Copy());
        gp_Trsf t;
        t.SetTranslation(gp_Vec(dx, dy, dz));
        copy->Transform(t);
        return new OCCTCurve3D(copy);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DRotate(OCCTCurve3DRef c,
                                  double axisOx, double axisOy, double axisOz,
                                  double axisDx, double axisDy, double axisDz,
                                  double angle) {
    if (!c || c->curve.IsNull()) return nullptr;
    try {
        Handle(Geom_Curve) copy = Handle(Geom_Curve)::DownCast(c->curve->Copy());
        gp_Ax1 axis(gp_Pnt(axisOx, axisOy, axisOz), gp_Dir(axisDx, axisDy, axisDz));
        gp_Trsf t;
        t.SetRotation(axis, angle);
        copy->Transform(t);
        return new OCCTCurve3D(copy);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DScale(OCCTCurve3DRef c,
                                 double cx, double cy, double cz, double factor) {
    if (!c || c->curve.IsNull()) return nullptr;
    try {
        Handle(Geom_Curve) copy = Handle(Geom_Curve)::DownCast(c->curve->Copy());
        gp_Trsf t;
        t.SetScale(gp_Pnt(cx, cy, cz), factor);
        copy->Transform(t);
        return new OCCTCurve3D(copy);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DMirrorPoint(OCCTCurve3DRef c,
                                       double px, double py, double pz) {
    if (!c || c->curve.IsNull()) return nullptr;
    try {
        Handle(Geom_Curve) copy = Handle(Geom_Curve)::DownCast(c->curve->Copy());
        gp_Trsf t;
        t.SetMirror(gp_Pnt(px, py, pz));
        copy->Transform(t);
        return new OCCTCurve3D(copy);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DMirrorAxis(OCCTCurve3DRef c,
                                      double px, double py, double pz,
                                      double dx, double dy, double dz) {
    if (!c || c->curve.IsNull()) return nullptr;
    try {
        Handle(Geom_Curve) copy = Handle(Geom_Curve)::DownCast(c->curve->Copy());
        gp_Ax1 axis(gp_Pnt(px, py, pz), gp_Dir(dx, dy, dz));
        gp_Trsf t;
        t.SetMirror(axis);
        copy->Transform(t);
        return new OCCTCurve3D(copy);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DMirrorPlane(OCCTCurve3DRef c,
                                       double px, double py, double pz,
                                       double nx, double ny, double nz) {
    if (!c || c->curve.IsNull()) return nullptr;
    try {
        Handle(Geom_Curve) copy = Handle(Geom_Curve)::DownCast(c->curve->Copy());
        gp_Ax2 plane(gp_Pnt(px, py, pz), gp_Dir(nx, ny, nz));
        gp_Trsf t;
        t.SetMirror(plane);
        copy->Transform(t);
        return new OCCTCurve3D(copy);
    } catch (...) {
        return nullptr;
    }
}

double OCCTCurve3DGetLength(OCCTCurve3DRef c) {
    if (!c || c->curve.IsNull()) return -1.0;
    try {
        GeomAdaptor_Curve adaptor(c->curve);
        return CPnts_AbscissaPoint::Length(adaptor);
    } catch (...) {
        return -1.0;
    }
}

double OCCTCurve3DGetLengthBetween(OCCTCurve3DRef c, double u1, double u2) {
    if (!c || c->curve.IsNull()) return -1.0;
    try {
        GeomAdaptor_Curve adaptor(c->curve);
        return CPnts_AbscissaPoint::Length(adaptor, u1, u2);
    } catch (...) {
        return -1.0;
    }
}

// Conversion (GeomConvert)

OCCTCurve3DRef OCCTCurve3DToBSpline(OCCTCurve3DRef c) {
    if (!c || c->curve.IsNull()) return nullptr;
    try {
        Handle(Geom_BSplineCurve) bsp = GeomConvert::CurveToBSplineCurve(c->curve);
        if (bsp.IsNull()) return nullptr;
        return new OCCTCurve3D(bsp);
    } catch (...) {
        return nullptr;
    }
}

int32_t OCCTCurve3DBSplineToBeziers(OCCTCurve3DRef c,
                                     OCCTCurve3DRef* out, int32_t max) {
    if (!c || c->curve.IsNull() || !out || max <= 0) return 0;
    try {
        Handle(Geom_BSplineCurve) bsp = Handle(Geom_BSplineCurve)::DownCast(c->curve);
        if (bsp.IsNull()) {
            bsp = GeomConvert::CurveToBSplineCurve(c->curve);
            if (bsp.IsNull()) return 0;
        }

        GeomConvert_BSplineCurveToBezierCurve converter(bsp);
        int32_t n = std::min((int32_t)converter.NbArcs(), max);
        for (int32_t i = 0; i < n; i++) {
            Handle(Geom_BezierCurve) arc = converter.Arc(i + 1);
            out[i] = new OCCTCurve3D(arc);
        }
        return n;
    } catch (...) {
        return 0;
    }
}

void OCCTCurve3DFreeArray(OCCTCurve3DRef* curves, int32_t count) {
    if (!curves) return;
    for (int32_t i = 0; i < count; i++) {
        delete curves[i];
        curves[i] = nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DJoinToBSpline(const OCCTCurve3DRef* curves, int32_t count,
                                         double tolerance) {
    if (!curves || count < 1) return nullptr;
    try {
        if (!curves[0] || curves[0]->curve.IsNull()) return nullptr;

        Handle(Geom_BSplineCurve) first = GeomConvert::CurveToBSplineCurve(curves[0]->curve);
        if (first.IsNull()) return nullptr;

        GeomConvert_CompCurveToBSplineCurve joiner(first);
        for (int32_t i = 1; i < count; i++) {
            if (!curves[i] || curves[i]->curve.IsNull()) continue;
            Handle(Geom_BSplineCurve) bsp = GeomConvert::CurveToBSplineCurve(curves[i]->curve);
            if (!bsp.IsNull()) {
                joiner.Add(bsp, tolerance);
            }
        }
        return new OCCTCurve3D(joiner.BSplineCurve());
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DApproximate(OCCTCurve3DRef c, double tolerance,
                                       int32_t continuity, int32_t maxSegments,
                                       int32_t maxDegree) {
    if (!c || c->curve.IsNull()) return nullptr;
    try {
        GeomAbs_Shape cont = GeomAbs_C2;
        switch (continuity) {
            case 0: cont = GeomAbs_C0; break;
            case 1: cont = GeomAbs_C1; break;
            case 2: cont = GeomAbs_C2; break;
            case 3: cont = GeomAbs_C3; break;
        }

        GeomConvert_ApproxCurve approx(c->curve, tolerance, cont, maxSegments, maxDegree);
        if (!approx.IsDone()) return nullptr;

        return new OCCTCurve3D(approx.Curve());
    } catch (...) {
        return nullptr;
    }
}

// Draw Methods

int32_t OCCTCurve3DDrawAdaptive(OCCTCurve3DRef c,
                                 double angularDefl, double chordalDefl,
                                 double* outXYZ, int32_t maxPoints) {
    if (!c || c->curve.IsNull() || !outXYZ || maxPoints <= 0) return 0;
    try {
        GeomAdaptor_Curve adaptor(c->curve);
        GCPnts_TangentialDeflection sampler(adaptor, angularDefl, chordalDefl);
        int32_t n = std::min((int32_t)sampler.NbPoints(), maxPoints);
        for (int32_t i = 0; i < n; i++) {
            gp_Pnt p = sampler.Value(i + 1);
            outXYZ[i*3] = p.X();
            outXYZ[i*3+1] = p.Y();
            outXYZ[i*3+2] = p.Z();
        }
        return n;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTCurve3DDrawUniform(OCCTCurve3DRef c,
                                int32_t pointCount, double* outXYZ) {
    if (!c || c->curve.IsNull() || !outXYZ || pointCount <= 0) return 0;
    try {
        GeomAdaptor_Curve adaptor(c->curve);
        GCPnts_UniformAbscissa sampler(adaptor, pointCount);
        if (!sampler.IsDone()) return 0;
        int32_t n = sampler.NbPoints();
        for (int32_t i = 0; i < n; i++) {
            double u = sampler.Parameter(i + 1);
            gp_Pnt p = adaptor.Value(u);
            outXYZ[i*3] = p.X();
            outXYZ[i*3+1] = p.Y();
            outXYZ[i*3+2] = p.Z();
        }
        return n;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTCurve3DDrawDeflection(OCCTCurve3DRef c, double deflection,
                                   double* outXYZ, int32_t maxPoints) {
    if (!c || c->curve.IsNull() || !outXYZ || maxPoints <= 0) return 0;
    try {
        GeomAdaptor_Curve adaptor(c->curve);
        GCPnts_UniformDeflection sampler(adaptor, deflection);
        if (!sampler.IsDone()) return 0;
        int32_t n = std::min((int32_t)sampler.NbPoints(), maxPoints);
        for (int32_t i = 0; i < n; i++) {
            gp_Pnt p = sampler.Value(i + 1);
            outXYZ[i*3] = p.X();
            outXYZ[i*3+1] = p.Y();
            outXYZ[i*3+2] = p.Z();
        }
        return n;
    } catch (...) {
        return 0;
    }
}

// Local Properties

double OCCTCurve3DGetCurvature(OCCTCurve3DRef c, double u) {
    if (!c || c->curve.IsNull()) return 0.0;
    try {
        GeomLProp_CLProps props(c->curve, 2, Precision::Confusion());
        props.SetParameter(u);
        if (!props.IsTangentDefined()) return 0.0;
        return props.Curvature();
    } catch (...) {
        return 0.0;
    }
}

bool OCCTCurve3DGetTangent(OCCTCurve3DRef c, double u,
                            double* tx, double* ty, double* tz) {
    if (!c || c->curve.IsNull() || !tx || !ty || !tz) return false;
    try {
        GeomLProp_CLProps props(c->curve, 1, Precision::Confusion());
        props.SetParameter(u);
        if (!props.IsTangentDefined()) return false;
        gp_Dir dir;
        props.Tangent(dir);
        *tx = dir.X(); *ty = dir.Y(); *tz = dir.Z();
        return true;
    } catch (...) {
        return false;
    }
}

bool OCCTCurve3DGetNormal(OCCTCurve3DRef c, double u,
                           double* nx, double* ny, double* nz) {
    if (!c || c->curve.IsNull() || !nx || !ny || !nz) return false;
    try {
        GeomLProp_CLProps props(c->curve, 2, Precision::Confusion());
        props.SetParameter(u);
        if (!props.IsTangentDefined()) return false;
        gp_Dir dir;
        props.Normal(dir);
        *nx = dir.X(); *ny = dir.Y(); *nz = dir.Z();
        return true;
    } catch (...) {
        return false;
    }
}

bool OCCTCurve3DGetCenterOfCurvature(OCCTCurve3DRef c, double u,
                                      double* cx, double* cy, double* cz) {
    if (!c || c->curve.IsNull() || !cx || !cy || !cz) return false;
    try {
        GeomLProp_CLProps props(c->curve, 2, Precision::Confusion());
        props.SetParameter(u);
        if (!props.IsTangentDefined()) return false;
        if (props.Curvature() < Precision::Confusion()) return false;
        gp_Pnt center;
        props.CentreOfCurvature(center);
        *cx = center.X(); *cy = center.Y(); *cz = center.Z();
        return true;
    } catch (...) {
        return false;
    }
}

double OCCTCurve3DGetTorsion(OCCTCurve3DRef c, double u) {
    if (!c || c->curve.IsNull()) return 0.0;
    try {
        gp_Pnt pnt;
        gp_Vec d1, d2, d3;
        c->curve->D3(u, pnt, d1, d2, d3);

        gp_Vec cross = d1.Crossed(d2);
        double crossMag2 = cross.SquareMagnitude();
        if (crossMag2 < Precision::Confusion()) return 0.0;
        return cross.Dot(d3) / crossMag2;
    } catch (...) {
        return 0.0;
    }
}

// Bounding Box

bool OCCTCurve3DGetBoundingBox(OCCTCurve3DRef c,
                                double* xMin, double* yMin, double* zMin,
                                double* xMax, double* yMax, double* zMax) {
    if (!c || c->curve.IsNull() || !xMin || !yMin || !zMin || !xMax || !yMax || !zMax)
        return false;
    try {
        GeomAdaptor_Curve adaptor(c->curve);
        Bnd_Box box;
        BndLib_Add3dCurve::Add(adaptor, 0.01, box);
        if (box.IsVoid()) return false;
        box.Get(*xMin, *yMin, *zMin, *xMax, *yMax, *zMax);
        return true;
    } catch (...) {
        return false;
    }
}

// ============================================================================
// MARK: - Batch Curve3D Evaluation (v0.29.0)

#include <GeomGridEval_Curve.hxx>
#include <GeomGridEval.hxx>

int32_t OCCTCurve3DEvaluateGrid(OCCTCurve3DRef curve, const double* params, int32_t paramCount,
                                 double* outXYZ) {
    if (!curve || curve->curve.IsNull() || !params || !outXYZ || paramCount <= 0) return 0;
    try {
        GeomGridEval_Curve evaluator(curve->curve);

        NCollection_Array1<double> paramArr(1, paramCount);
        for (int32_t i = 0; i < paramCount; i++) {
            paramArr.SetValue(i + 1, params[i]);
        }

        NCollection_Array1<gp_Pnt> results = evaluator.EvaluateGrid(paramArr);
        int32_t n = results.Size();
        for (int32_t i = 0; i < n; i++) {
            const gp_Pnt& pt = results.Value(i + 1);
            outXYZ[i*3]   = pt.X();
            outXYZ[i*3+1] = pt.Y();
            outXYZ[i*3+2] = pt.Z();
        }
        return n;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTCurve3DEvaluateGridD1(OCCTCurve3DRef curve, const double* params, int32_t paramCount,
                                   double* outXYZ, double* outDXDYDZ) {
    if (!curve || curve->curve.IsNull() || !params || !outXYZ || !outDXDYDZ || paramCount <= 0) return 0;
    try {
        GeomGridEval_Curve evaluator(curve->curve);

        NCollection_Array1<double> paramArr(1, paramCount);
        for (int32_t i = 0; i < paramCount; i++) {
            paramArr.SetValue(i + 1, params[i]);
        }

        NCollection_Array1<GeomGridEval::CurveD1> results = evaluator.EvaluateGridD1(paramArr);
        int32_t n = results.Size();
        for (int32_t i = 0; i < n; i++) {
            const GeomGridEval::CurveD1& r = results.Value(i + 1);
            outXYZ[i*3]     = r.Point.X();
            outXYZ[i*3+1]   = r.Point.Y();
            outXYZ[i*3+2]   = r.Point.Z();
            outDXDYDZ[i*3]   = r.D1.X();
            outDXDYDZ[i*3+1] = r.D1.Y();
            outDXDYDZ[i*3+2] = r.D1.Z();
        }
        return n;
    } catch (...) {
        return 0;
    }
}

// MARK: - Curve Planarity Check (v0.29.0)

#include <ShapeAnalysis_Curve.hxx>

bool OCCTCurve3DIsPlanar(OCCTCurve3DRef curve, double tolerance,
                          double* outNX, double* outNY, double* outNZ) {
    if (!curve || curve->curve.IsNull()) return false;
    try {
        ShapeAnalysis_Curve analyzer;
        gp_XYZ normal;
        bool result = analyzer.IsPlanar(curve->curve, normal, tolerance);
        if (result) {
            if (outNX) *outNX = normal.X();
            if (outNY) *outNY = normal.Y();
            if (outNZ) *outNZ = normal.Z();
            return true;
        }
        return false;
    } catch (...) {
        return false;
    }
}

// MARK: - Curve-Curve Extrema (v0.30.0)

#include <GeomAPI_ExtremaCurveCurve.hxx>

double OCCTCurve3DMinDistanceToCurve(OCCTCurve3DRef c1, OCCTCurve3DRef c2) {
    if (!c1 || c1->curve.IsNull() || !c2 || c2->curve.IsNull()) return -1.0;
    try {
        GeomAPI_ExtremaCurveCurve extrema(c1->curve, c2->curve);
        if (extrema.NbExtrema() == 0) return -1.0;
        return extrema.LowerDistance();
    } catch (...) {
        return -1.0;
    }
}

int32_t OCCTCurve3DExtrema(OCCTCurve3DRef c1, OCCTCurve3DRef c2, OCCTCurveExtrema* outExtrema, int32_t maxCount) {
    if (!c1 || c1->curve.IsNull() || !c2 || c2->curve.IsNull() || !outExtrema || maxCount <= 0) return 0;
    try {
        GeomAPI_ExtremaCurveCurve extrema(c1->curve, c2->curve);
        int32_t nb = extrema.NbExtrema();
        int32_t count = (nb < maxCount) ? nb : maxCount;
        for (int32_t i = 0; i < count; i++) {
            gp_Pnt p1, p2;
            extrema.Points(i + 1, p1, p2);
            double u1, u2;
            extrema.Parameters(i + 1, u1, u2);
            outExtrema[i].distance = extrema.Distance(i + 1);
            outExtrema[i].point1[0] = p1.X();
            outExtrema[i].point1[1] = p1.Y();
            outExtrema[i].point1[2] = p1.Z();
            outExtrema[i].point2[0] = p2.X();
            outExtrema[i].point2[1] = p2.Y();
            outExtrema[i].point2[2] = p2.Z();
            outExtrema[i].param1 = u1;
            outExtrema[i].param2 = u2;
        }
        return count;
    } catch (...) {
        return 0;
    }
}

// MARK: - Curve to Analytical (v0.30.0)

#include <GeomConvert_CurveToAnaCurve.hxx>

OCCTCurve3DRef OCCTCurve3DToAnalytical(OCCTCurve3DRef curve, double tolerance) {
    if (!curve || curve->curve.IsNull()) return nullptr;
    try {
        GeomConvert_CurveToAnaCurve converter(curve->curve);
        Handle(Geom_Curve) result;
        double newFirst, newLast;
        bool ok = converter.ConvertToAnalytical(tolerance, result,
                                                 curve->curve->FirstParameter(),
                                                 curve->curve->LastParameter(),
                                                 newFirst, newLast);
        if (!ok || result.IsNull()) return nullptr;
        return new OCCTCurve3D(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Quasi-Uniform Curve Sampling (v0.31.0)

#include <GCPnts_QuasiUniformAbscissa.hxx>

int32_t OCCTCurve3DQuasiUniformAbscissa(OCCTCurve3DRef curve, int32_t nbPoints, double* outParams) {
    if (!curve || curve->curve.IsNull() || !outParams || nbPoints <= 0) return 0;
    try {
        GeomAdaptor_Curve adaptor(curve->curve);
        GCPnts_QuasiUniformAbscissa sampler(adaptor, nbPoints);
        if (!sampler.IsDone()) return 0;
        int32_t n = sampler.NbPoints();
        for (int32_t i = 0; i < n; i++) {
            outParams[i] = sampler.Parameter(i + 1);
        }
        return n;
    } catch (...) {
        return 0;
    }
}

// MARK: - Quasi-Uniform Deflection Sampling (v0.31.0)

#include <GCPnts_QuasiUniformDeflection.hxx>

int32_t OCCTCurve3DQuasiUniformDeflection(OCCTCurve3DRef curve, double deflection, double* outXYZ, int32_t maxPoints) {
    if (!curve || curve->curve.IsNull() || !outXYZ || maxPoints <= 0) return 0;
    try {
        GeomAdaptor_Curve adaptor(curve->curve);
        GCPnts_QuasiUniformDeflection sampler(adaptor, deflection);
        if (!sampler.IsDone()) return 0;
        int32_t n = std::min((int32_t)sampler.NbPoints(), maxPoints);
        for (int32_t i = 0; i < n; i++) {
            gp_Pnt p = sampler.Value(i + 1);
            outXYZ[i*3] = p.X();
            outXYZ[i*3+1] = p.Y();
            outXYZ[i*3+2] = p.Z();
        }
        return n;
    } catch (...) {
        return 0;
    }
}

OCCTCurve3DRef OCCTCurve3DArcOfEllipse(double centerX, double centerY, double centerZ,
                                         double normalX, double normalY, double normalZ,
                                         double majorRadius, double minorRadius,
                                         double angle1, double angle2, bool sense) {
    try {
        gp_Ax2 ax(gp_Pnt(centerX, centerY, centerZ), gp_Dir(normalX, normalY, normalZ));
        gp_Elips elips(ax, majorRadius, minorRadius);
        GC_MakeArcOfEllipse maker(elips, angle1, angle2, sense);
        if (!maker.IsDone()) return nullptr;
        return new OCCTCurve3D(maker.Value());
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DArcOfEllipsePoints(double centerX, double centerY, double centerZ,
                                               double normalX, double normalY, double normalZ,
                                               double majorRadius, double minorRadius,
                                               double p1X, double p1Y, double p1Z,
                                               double p2X, double p2Y, double p2Z, bool sense) {
    try {
        gp_Ax2 ax(gp_Pnt(centerX, centerY, centerZ), gp_Dir(normalX, normalY, normalZ));
        gp_Elips elips(ax, majorRadius, minorRadius);
        GC_MakeArcOfEllipse maker(elips, gp_Pnt(p1X, p1Y, p1Z), gp_Pnt(p2X, p2Y, p2Z), sense);
        if (!maker.IsDone()) return nullptr;
        return new OCCTCurve3D(maker.Value());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Approx_Curve3d (v0.46)
OCCTCurve3DRef OCCTEdgeApproxCurve(OCCTEdgeRef edge, double tolerance,
                                     int32_t maxSegments, int32_t maxDegree) {
    if (!edge) return nullptr;
    try {
        BRepAdaptor_Curve adaptorCurve(edge->edge);
        Approx_Curve3d approx(new BRepAdaptor_Curve(adaptorCurve),
                               tolerance, GeomAbs_C2, maxSegments, maxDegree);
        if (!approx.IsDone() && !approx.HasResult()) return nullptr;
        auto bspline = approx.Curve();
        if (bspline.IsNull()) return nullptr;
        return new OCCTCurve3D(bspline);
    } catch (...) {
        return nullptr;
    }
}

bool OCCTEdgeApproxCurveInfo(OCCTEdgeRef edge, double tolerance,
                              int32_t maxSegments, int32_t maxDegree,
                              double* outMaxError, int32_t* outDegree, int32_t* outNbPoles) {
    if (!edge || !outMaxError || !outDegree || !outNbPoles) return false;
    try {
        BRepAdaptor_Curve adaptorCurve(edge->edge);
        Approx_Curve3d approx(new BRepAdaptor_Curve(adaptorCurve),
                               tolerance, GeomAbs_C2, maxSegments, maxDegree);
        if (!approx.IsDone() && !approx.HasResult()) return false;
        *outMaxError = approx.MaxError();
        auto bspline = approx.Curve();
        if (bspline.IsNull()) return false;
        *outDegree = bspline->Degree();
        *outNbPoles = bspline->NbPoles();
        return true;
    } catch (...) {
        return false;
    }
}

// MARK: - GeomConvert_CompCurveToBSplineCurve Join (v0.49)
// --- GeomConvert_CompCurveToBSplineCurve ---

OCCTCurve3DRef OCCTCurve3DJoinCurves(const OCCTCurve3DRef* curves, int32_t count, double tolerance) {
    if (!curves || count < 1) return nullptr;
    try {
        // First curve initializes the joiner
        Handle(Geom_BoundedCurve) first = Handle(Geom_BoundedCurve)::DownCast(curves[0]->curve);
        if (first.IsNull()) return nullptr;

        GeomConvert_CompCurveToBSplineCurve joiner(first);

        for (int i = 1; i < count; i++) {
            if (!curves[i]) return nullptr;
            Handle(Geom_BoundedCurve) bc = Handle(Geom_BoundedCurve)::DownCast(curves[i]->curve);
            if (bc.IsNull()) return nullptr;
            if (!joiner.Add(bc, tolerance)) return nullptr;
        }

        Handle(Geom_BSplineCurve) bsp = joiner.BSplineCurve();
        if (bsp.IsNull()) return nullptr;

        auto* result = new OCCTCurve3D();
        result->curve = bsp;
        return result;
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Curve3D Projection / Validate / Sample (v0.49)
// --- ShapeAnalysis_Curve expansion ---

OCCTCurveProjectResult OCCTCurve3DProjectPoint(OCCTCurve3DRef curve,
    double px, double py, double pz, double precision) {
    OCCTCurveProjectResult result = {};
    if (!curve) return result;
    try {
        ShapeAnalysis_Curve sac;
        gp_Pnt proj;
        double param;
        double dist = sac.Project(curve->curve, gp_Pnt(px, py, pz), precision, proj, param);
        result.distance = dist;
        result.parameter = param;
        result.projX = proj.X();
        result.projY = proj.Y();
        result.projZ = proj.Z();
        return result;
    } catch (...) {
        return result;
    }
}

OCCTCurveValidateRangeResult OCCTCurve3DValidateRange(OCCTCurve3DRef curve,
    double first, double last, double precision) {
    OCCTCurveValidateRangeResult result = {};
    result.first = first;
    result.last = last;
    result.wasAdjusted = false;
    if (!curve) return result;
    try {
        ShapeAnalysis_Curve sac;
        double f = first, l = last;
        bool adjusted = sac.ValidateRange(curve->curve, f, l, precision);
        result.first = f;
        result.last = l;
        result.wasAdjusted = adjusted;
        return result;
    } catch (...) {
        return result;
    }
}

int32_t OCCTCurve3DGetSamplePoints3D(OCCTCurve3DRef curve, double first, double last,
    double* outXYZ, int32_t maxPoints) {
    if (!curve || !outXYZ || maxPoints <= 0) return 0;
    try {
        ShapeAnalysis_Curve sac;
        NCollection_Sequence<gp_Pnt> pts;
        if (!sac.GetSamplePoints(curve->curve, first, last, pts)) return 0;

        int32_t count = std::min((int32_t)pts.Length(), maxPoints);
        for (int32_t i = 0; i < count; i++) {
            const gp_Pnt& p = pts.Value(i + 1); // 1-indexed
            outXYZ[i * 3]     = p.X();
            outXYZ[i * 3 + 1] = p.Y();
            outXYZ[i * 3 + 2] = p.Z();
        }
        return count;
    } catch (...) {
        return 0;
    }
}

// MARK: - GC ArcOfHyperbola / ArcOfParabola (v0.50)
OCCTCurve3DRef OCCTCurve3DArcOfHyperbola(
    double majorRadius, double minorRadius,
    double axisX, double axisY, double axisZ,
    double dirX, double dirY, double dirZ,
    double alpha1, double alpha2, bool sense) {
    try {
        gp_Ax2 ax(gp_Pnt(axisX, axisY, axisZ), gp_Dir(dirX, dirY, dirZ));
        gp_Hypr hypr(ax, majorRadius, minorRadius);
        GC_MakeArcOfHyperbola maker(hypr, alpha1, alpha2, sense ? Standard_True : Standard_False);
        if (!maker.IsDone()) return nullptr;
        Handle(Geom_TrimmedCurve) arc = maker.Value();
        if (arc.IsNull()) return nullptr;
        auto* ref = new OCCTCurve3D();
        ref->curve = arc;
        return ref;
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DArcOfParabola(
    double focalDistance,
    double axisX, double axisY, double axisZ,
    double dirX, double dirY, double dirZ,
    double alpha1, double alpha2, bool sense) {
    try {
        gp_Ax2 ax(gp_Pnt(axisX, axisY, axisZ), gp_Dir(dirX, dirY, dirZ));
        gp_Parab parab(ax, focalDistance);
        GC_MakeArcOfParabola maker(parab, alpha1, alpha2, sense ? Standard_True : Standard_False);
        if (!maker.IsDone()) return nullptr;
        Handle(Geom_TrimmedCurve) arc = maker.Value();
        if (arc.IsNull()) return nullptr;
        auto* ref = new OCCTCurve3D();
        ref->curve = arc;
        return ref;
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Curve3D ConvertToPeriodic / SplitAt (v0.50)
OCCTCurve3DRef OCCTCurve3DConvertToPeriodic(OCCTCurve3DRef curve) {
    if (!curve) return nullptr;
    try {
        ShapeCustom_Curve scc(curve->curve);
        Handle(Geom_Curve) periodic = scc.ConvertToPeriodic(Standard_False);
        if (periodic.IsNull()) return nullptr;
        auto* ref = new OCCTCurve3D();
        ref->curve = periodic;
        return ref;
    } catch (...) {
        return nullptr;
    }
}

bool OCCTCurve3DSplitAt(OCCTCurve3DRef curve, double splitParam,
    OCCTCurve3DRef* outCurve1, OCCTCurve3DRef* outCurve2) {
    if (!curve || !outCurve1 || !outCurve2) return false;
    *outCurve1 = nullptr;
    *outCurve2 = nullptr;
    try {
        Handle(Geom_Curve) c = curve->curve;
        double first = c->FirstParameter();
        double last = c->LastParameter();
        if (splitParam <= first || splitParam >= last) return false;

        Handle(ShapeUpgrade_SplitCurve3d) splitter = new ShapeUpgrade_SplitCurve3d();
        splitter->Init(c, first, last);
        Handle(TColStd_HSequenceOfReal) splitVals = new TColStd_HSequenceOfReal();
        splitVals->Append(splitParam);
        splitter->SetSplitValues(splitVals);
        splitter->Perform(Standard_True);

        Handle(TColGeom_HArray1OfCurve) curves = splitter->GetCurves();
        if (curves.IsNull() || curves->Length() < 2) return false;

        auto* ref1 = new OCCTCurve3D();
        ref1->curve = curves->Value(1);
        *outCurve1 = ref1;

        auto* ref2 = new OCCTCurve3D();
        ref2->curve = curves->Value(2);
        *outCurve2 = ref2;
        return true;
    } catch (...) {
        return false;
    }
}

// MARK: - GC MakeEllipse / MakeHyperbola (v0.51)
// --- GC_MakeEllipse ---

OCCTCurve3DRef _Nullable OCCTCurve3DMakeEllipse(double cx, double cy, double cz,
    double dx, double dy, double dz, double majorRadius, double minorRadius) {
    try {
        gp_Ax2 ax(gp_Pnt(cx, cy, cz), gp_Dir(dx, dy, dz));
        GC_MakeEllipse me(ax, majorRadius, minorRadius);
        if (!me.IsDone()) return nullptr;
        auto* curve = new OCCTCurve3D();
        curve->curve = me.Value();
        return curve;
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef _Nullable OCCTCurve3DMakeEllipseThreePoints(
    double s1x, double s1y, double s1z,
    double s2x, double s2y, double s2z,
    double centerX, double centerY, double centerZ) {
    try {
        GC_MakeEllipse me(gp_Pnt(s1x, s1y, s1z), gp_Pnt(s2x, s2y, s2z),
                          gp_Pnt(centerX, centerY, centerZ));
        if (!me.IsDone()) return nullptr;
        auto* curve = new OCCTCurve3D();
        curve->curve = me.Value();
        return curve;
    } catch (...) {
        return nullptr;
    }
}

// --- GC_MakeHyperbola ---

OCCTCurve3DRef _Nullable OCCTCurve3DMakeHyperbola(double cx, double cy, double cz,
    double dx, double dy, double dz, double majorRadius, double minorRadius) {
    try {
        gp_Ax2 ax(gp_Pnt(cx, cy, cz), gp_Dir(dx, dy, dz));
        GC_MakeHyperbola mh(ax, majorRadius, minorRadius);
        if (!mh.IsDone()) return nullptr;
        auto* curve = new OCCTCurve3D();
        curve->curve = mh.Value();
        return curve;
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef _Nullable OCCTCurve3DMakeHyperbolaThreePoints(
    double s1x, double s1y, double s1z,
    double s2x, double s2y, double s2z,
    double centerX, double centerY, double centerZ) {
    try {
        GC_MakeHyperbola mh(gp_Pnt(s1x, s1y, s1z), gp_Pnt(s2x, s2y, s2z),
                            gp_Pnt(centerX, centerY, centerZ));
        if (!mh.IsDone()) return nullptr;
        auto* curve = new OCCTCurve3D();
        curve->curve = mh.Value();
        return curve;
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Approx_CurveOnSurface (v0.61)
// MARK: - Approx_CurveOnSurface (v0.61.0)

OCCTShapeRef OCCTApproxCurveOnSurface(OCCTShapeRef edge, OCCTShapeRef face,
    double tolerance, int32_t maxSegments, int32_t maxDegree) {
    if (!edge || !face) return nullptr;
    try {
        if (edge->shape.ShapeType() != TopAbs_EDGE) return nullptr;
        if (face->shape.ShapeType() != TopAbs_FACE) return nullptr;
        TopoDS_Edge e = TopoDS::Edge(edge->shape);
        TopoDS_Face f = TopoDS::Face(face->shape);

        // Get PCurve and surface
        double first, last;
        Handle(Geom2d_Curve) pcurve = BRep_Tool::CurveOnSurface(e, f, first, last);
        if (pcurve.IsNull()) return nullptr;

        Handle(Geom_Surface) surface = BRep_Tool::Surface(f);
        if (surface.IsNull()) return nullptr;

        Handle(Geom2dAdaptor_Curve) curveAdaptor = new Geom2dAdaptor_Curve(pcurve, first, last);
        Handle(GeomAdaptor_Surface) surfAdaptor = new GeomAdaptor_Surface(surface);

        Approx_CurveOnSurface approx(curveAdaptor, surfAdaptor, first, last, tolerance);
        approx.Perform(maxSegments, maxDegree, GeomAbs_C2);

        if (!approx.IsDone() || !approx.HasResult()) return nullptr;
        Handle(Geom_BSplineCurve) curve3d = approx.Curve3d();
        if (curve3d.IsNull()) return nullptr;

        BRepBuilderAPI_MakeEdge edgeMaker(curve3d);
        if (!edgeMaker.IsDone()) return nullptr;
        return new OCCTShape(edgeMaker.Edge());
    } catch (...) { return nullptr; }
}

// MARK: - CPnts_UniformDeflection (v0.62)
// --- CPnts_UniformDeflection ---

bool OCCTCPntsUniformDeflection(OCCTShapeRef shape, double deflection,
    double* _Nullable * _Nonnull outParams,
    double* _Nullable * _Nonnull outPoints,
    int32_t* outCount) {
    if (!shape) return false;
    try {
        TopoDS_Edge edge = TopoDS::Edge(shape->shape);
        BRepAdaptor_Curve bac(edge);
        CPnts_UniformDeflection ud(bac, deflection, 1e-7, true);
        std::vector<double> params;
        std::vector<gp_Pnt> pts;
        while (ud.More()) {
            double p = ud.Value();
            params.push_back(p);
            pts.push_back(bac.Value(p));
            ud.Next();
        }
        int32_t n = (int32_t)params.size();
        *outCount = n;
        if (n == 0) { *outParams = nullptr; *outPoints = nullptr; return false; }
        *outParams = (double*)malloc(n * sizeof(double));
        *outPoints = (double*)malloc(n * 3 * sizeof(double));
        for (int32_t i = 0; i < n; i++) {
            (*outParams)[i] = params[i];
            (*outPoints)[i*3]   = pts[i].X();
            (*outPoints)[i*3+1] = pts[i].Y();
            (*outPoints)[i*3+2] = pts[i].Z();
        }
        return true;
    } catch (...) { return false; }
}

bool OCCTCPntsUniformDeflectionRange(OCCTShapeRef shape, double deflection,
    double u1, double u2,
    double* _Nullable * _Nonnull outParams,
    double* _Nullable * _Nonnull outPoints,
    int32_t* outCount) {
    if (!shape) return false;
    try {
        TopoDS_Edge edge = TopoDS::Edge(shape->shape);
        BRepAdaptor_Curve bac(edge);
        CPnts_UniformDeflection ud(bac, deflection, u1, u2, 1e-7, true);
        std::vector<double> params;
        std::vector<gp_Pnt> pts;
        while (ud.More()) {
            double p = ud.Value();
            params.push_back(p);
            pts.push_back(bac.Value(p));
            ud.Next();
        }
        int32_t n = (int32_t)params.size();
        *outCount = n;
        if (n == 0) { *outParams = nullptr; *outPoints = nullptr; return false; }
        *outParams = (double*)malloc(n * sizeof(double));
        *outPoints = (double*)malloc(n * 3 * sizeof(double));
        for (int32_t i = 0; i < n; i++) {
            (*outParams)[i] = params[i];
            (*outPoints)[i*3]   = pts[i].X();
            (*outPoints)[i*3+1] = pts[i].Y();
            (*outPoints)[i*3+2] = pts[i].Z();
        }
        return true;
    } catch (...) { return false; }
}

// MARK: - Approx_CurvilinearParameter (v0.63)
// --- Approx_CurvilinearParameter ---

OCCTShapeRef _Nullable OCCTApproxCurvilinearParameter(OCCTShapeRef edgeShape,
    double tolerance, int maxDegree, int maxSegments) {
    if (!edgeShape) return nullptr;
    try {
        TopoDS_Edge edge = TopoDS::Edge(edgeShape->shape);
        Handle(BRepAdaptor_Curve) adaptor = new BRepAdaptor_Curve(edge);
        Approx_CurvilinearParameter approx(adaptor, tolerance, GeomAbs_C1, maxDegree, maxSegments);
        if (!approx.IsDone() || !approx.HasResult()) return nullptr;
        Handle(Geom_BSplineCurve) curve = approx.Curve3d();
        if (curve.IsNull()) return nullptr;
        BRepBuilderAPI_MakeEdge me(curve);
        if (!me.IsDone()) return nullptr;
        return new OCCTShape(me.Edge());
    } catch (...) { return nullptr; }
}
