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

#include <BRep_Tool.hxx>
#include <BRepLib.hxx>

#include <GC_MakeArcOfCircle.hxx>
#include <GC_MakeCircle.hxx>
#include <GC_MakeSegment.hxx>

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
