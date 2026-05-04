//
//  OCCTBridge_ProjLib_NLPlate.mm
//  OCCTSwift
//
//  Extracted from OCCTBridge.mm — issue #99.
//
//  Two adjacent v0.22 / v0.23 areas that both project / fit curves onto
//  surfaces:
//
//  - ProjLib (v0.22): curve projection onto planes + general surfaces
//    (ProjLib_CompProjectedCurve / ProjectedCurve / ProjectOnPlane,
//    GeomProjLib helpers)
//  - NLPlate (v0.23): non-linear plate surfaces — point + curve
//    constraints fitted into a smooth surface (NLPlate_NLPlate +
//    GeomPlate_*)
//
//  Public C surface unchanged. No symbol changes — pure file move.
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

// === Area-specific OCCT headers ===

#include <BRepAdaptor_Curve.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>

#include <Geom_BSplineSurface.hxx>
#include <Geom_Curve.hxx>
#include <Geom_Plane.hxx>
#include <Geom_RectangularTrimmedSurface.hxx>
#include <Geom_Surface.hxx>
#include <Geom2d_Curve.hxx>

#include <GeomAbs_Shape.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <GeomAdaptor_Surface.hxx>
#include <GeomAPI_PointsToBSplineSurface.hxx>
#include <GeomAPI_ProjectPointOnSurf.hxx>
#include <GeomPlate_BuildAveragePlane.hxx>
#include <GeomPlate_BuildPlateSurface.hxx>
#include <GeomPlate_CurveConstraint.hxx>
#include <GeomPlate_MakeApprox.hxx>
#include <GeomPlate_PointConstraint.hxx>
#include <GeomPlate_Surface.hxx>
#include <GeomProjLib.hxx>

#include <NLPlate_HPG0Constraint.hxx>
#include <NLPlate_HPG1Constraint.hxx>
#include <NLPlate_NLPlate.hxx>
#include <Plate_D1.hxx>

#include <ProjLib_CompProjectedCurve.hxx>
#include <ProjLib_ProjectedCurve.hxx>
#include <ProjLib_ProjectOnPlane.hxx>

#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>
#include <gp_XY.hxx>
#include <gp_XYZ.hxx>

#include <TColgp_Array2OfPnt.hxx>

#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>

// MARK: - ProjLib: Curve Projection onto Surfaces (v0.22.0)

#include <GeomProjLib.hxx>
#include <ProjLib_CompProjectedCurve.hxx>
#include <ProjLib_ProjectedCurve.hxx>
#include <ProjLib_ProjectOnPlane.hxx>
#include <Geom_Plane.hxx>

OCCTCurve2DRef OCCTSurfaceProjectCurve2D(OCCTSurfaceRef surface,
                                          OCCTCurve3DRef curve,
                                          double tolerance) {
    if (!surface || surface->surface.IsNull()) return nullptr;
    if (!curve || curve->curve.IsNull()) return nullptr;
    try {
        Standard_Real first = curve->curve->FirstParameter();
        Standard_Real last = curve->curve->LastParameter();
        Standard_Real tol = tolerance;
        Handle(Geom2d_Curve) result = GeomProjLib::Curve2d(
            curve->curve, first, last, surface->surface, tol);
        if (result.IsNull()) return nullptr;
        return new OCCTCurve2D(result);
    } catch (...) {
        return nullptr;
    }
}

int32_t OCCTSurfaceProjectCurveSegments(OCCTSurfaceRef surface,
                                         OCCTCurve3DRef curve,
                                         double tolerance,
                                         OCCTCurve2DRef* outCurves,
                                         int32_t maxCurves) {
    if (!surface || surface->surface.IsNull()) return 0;
    if (!curve || curve->curve.IsNull()) return 0;
    if (!outCurves || maxCurves <= 0) return 0;
    try {
        Handle(GeomAdaptor_Surface) surfAdaptor =
            new GeomAdaptor_Surface(surface->surface);
        Handle(GeomAdaptor_Curve) curveAdaptor =
            new GeomAdaptor_Curve(curve->curve);

        ProjLib_CompProjectedCurve comp(tolerance, surfAdaptor, curveAdaptor);
        comp.Perform();

        int32_t nbCurves = comp.NbCurves();
        int32_t count = 0;
        for (int32_t i = 1; i <= nbCurves && count < maxCurves; i++) {
            Handle(Geom2d_Curve) c2d = comp.GetResult2dC(i);
            if (!c2d.IsNull()) {
                outCurves[count] = new OCCTCurve2D(c2d);
                count++;
            }
        }
        return count;
    } catch (...) {
        return 0;
    }
}

OCCTCurve3DRef OCCTSurfaceProjectCurve3D(OCCTSurfaceRef surface,
                                          OCCTCurve3DRef curve) {
    if (!surface || surface->surface.IsNull()) return nullptr;
    if (!curve || curve->curve.IsNull()) return nullptr;
    try {
        Handle(Geom_Curve) result = GeomProjLib::Project(
            curve->curve, surface->surface);
        if (result.IsNull()) return nullptr;
        return new OCCTCurve3D(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DProjectOnPlane(OCCTCurve3DRef curve,
                                          double oX, double oY, double oZ,
                                          double nX, double nY, double nZ,
                                          double dX, double dY, double dZ) {
    if (!curve || curve->curve.IsNull()) return nullptr;
    try {
        gp_Pnt origin(oX, oY, oZ);
        gp_Dir normal(nX, nY, nZ);
        gp_Dir direction(dX, dY, dZ);
        Handle(Geom_Plane) plane = new Geom_Plane(origin, normal);

        Handle(Geom_Curve) result = GeomProjLib::ProjectOnPlane(
            curve->curve, plane, direction, Standard_True);
        if (result.IsNull()) return nullptr;
        return new OCCTCurve3D(result);
    } catch (...) {
        return nullptr;
    }
}

bool OCCTSurfaceProjectPoint(OCCTSurfaceRef surface,
                              double px, double py, double pz,
                              double* u, double* v, double* distance) {
    if (!surface || surface->surface.IsNull()) return false;
    if (!u || !v || !distance) return false;
    try {
        GeomAPI_ProjectPointOnSurf proj(gp_Pnt(px, py, pz), surface->surface);
        if (!proj.IsDone() || proj.NbPoints() == 0) return false;
        proj.LowerDistanceParameters(*u, *v);
        *distance = proj.LowerDistance();
        return true;
    } catch (...) {
        return false;
    }
}


// MARK: - NLPlate: Advanced Plate Surfaces (v0.23.0)

#include <NLPlate_NLPlate.hxx>
#include <NLPlate_HPG0Constraint.hxx>
#include <NLPlate_HPG1Constraint.hxx>
#include <NLPlate_HPG0G1Constraint.hxx>
#include <Plate_D1.hxx>
#include <GeomPlate_BuildAveragePlane.hxx>
#include <GeomAPI_PointsToBSplineSurface.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>

OCCTShapeRef OCCTShapePlatePointsAdvanced(const double* points, int32_t pointCount,
                                           const int32_t* orders, int32_t degree,
                                           int32_t nbPtsOnCur, int32_t nbIter,
                                           double tolerance) {
    if (!points || pointCount < 3 || !orders) return nullptr;
    try {
        GeomPlate_BuildPlateSurface plateBuilder(degree, nbPtsOnCur, nbIter);

        for (int32_t i = 0; i < pointCount; i++) {
            gp_Pnt pt(points[i*3], points[i*3+1], points[i*3+2]);
            int32_t order = orders[i];
            if (order < 0) order = 0;
            if (order > 2) order = 2;
            Handle(GeomPlate_PointConstraint) constraint =
                new GeomPlate_PointConstraint(pt, order);
            plateBuilder.Add(constraint);
        }

        plateBuilder.Perform();
        if (!plateBuilder.IsDone()) return nullptr;

        Handle(GeomPlate_Surface) plateSurface = plateBuilder.Surface();
        if (plateSurface.IsNull()) return nullptr;

        GeomPlate_MakeApprox approx(plateSurface, tolerance, 1, 8, tolerance * 10, 0);
        Handle(Geom_BSplineSurface) bsplineSurf = approx.Surface();
        if (bsplineSurf.IsNull()) return nullptr;

        BRepBuilderAPI_MakeFace makeFace(bsplineSurf, tolerance);
        if (!makeFace.IsDone()) return nullptr;

        return new OCCTShape(makeFace.Face());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapePlateMixed(const double* points, const int32_t* pointOrders,
                                  int32_t pointCount,
                                  const OCCTWireRef* curves, const int32_t* curveOrders,
                                  int32_t curveCount,
                                  int32_t degree, double tolerance) {
    if (pointCount < 1 && curveCount < 1) return nullptr;
    try {
        GeomPlate_BuildPlateSurface plateBuilder(degree, 15, 2);

        // Add point constraints
        if (points && pointOrders) {
            for (int32_t i = 0; i < pointCount; i++) {
                gp_Pnt pt(points[i*3], points[i*3+1], points[i*3+2]);
                int32_t order = pointOrders[i];
                if (order < 0) order = 0;
                if (order > 2) order = 2;
                Handle(GeomPlate_PointConstraint) constraint =
                    new GeomPlate_PointConstraint(pt, order);
                plateBuilder.Add(constraint);
            }
        }

        // Add curve constraints
        if (curves && curveOrders) {
            for (int32_t i = 0; i < curveCount; i++) {
                if (!curves[i]) continue;
                int32_t order = curveOrders[i];
                if (order < 0) order = 0;
                if (order > 2) order = 2;

                for (TopExp_Explorer exp(curves[i]->wire, TopAbs_EDGE); exp.More(); exp.Next()) {
                    TopoDS_Edge edge = TopoDS::Edge(exp.Current());
                    BRepAdaptor_Curve adaptor(edge);
                    Handle(Adaptor3d_Curve) curve = new BRepAdaptor_Curve(adaptor);
                    Handle(GeomPlate_CurveConstraint) constraint =
                        new GeomPlate_CurveConstraint(curve, order);
                    plateBuilder.Add(constraint);
                }
            }
        }

        plateBuilder.Perform();
        if (!plateBuilder.IsDone()) return nullptr;

        Handle(GeomPlate_Surface) plateSurface = plateBuilder.Surface();
        if (plateSurface.IsNull()) return nullptr;

        GeomPlate_MakeApprox approx(plateSurface, tolerance, 1, 8, tolerance * 10, 0);
        Handle(Geom_BSplineSurface) bsplineSurf = approx.Surface();
        if (bsplineSurf.IsNull()) return nullptr;

        BRepBuilderAPI_MakeFace makeFace(bsplineSurf, tolerance);
        if (!makeFace.IsDone()) return nullptr;

        return new OCCTShape(makeFace.Face());
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfacePlateThrough(const double* points, int32_t pointCount,
                                        int32_t degree, double tolerance) {
    if (!points || pointCount < 3) return nullptr;
    try {
        GeomPlate_BuildPlateSurface plateBuilder(degree, 15, 2);

        for (int32_t i = 0; i < pointCount; i++) {
            gp_Pnt pt(points[i*3], points[i*3+1], points[i*3+2]);
            Handle(GeomPlate_PointConstraint) constraint =
                new GeomPlate_PointConstraint(pt, 0);
            plateBuilder.Add(constraint);
        }

        plateBuilder.Perform();
        if (!plateBuilder.IsDone()) return nullptr;

        Handle(GeomPlate_Surface) plateSurface = plateBuilder.Surface();
        if (plateSurface.IsNull()) return nullptr;

        GeomPlate_MakeApprox approx(plateSurface, tolerance, 1, 8, tolerance * 10, 0);
        Handle(Geom_BSplineSurface) bsplineSurf = approx.Surface();
        if (bsplineSurf.IsNull()) return nullptr;

        return new OCCTSurface(bsplineSurf);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceNLPlateG0(OCCTSurfaceRef initialSurface,
                                     const double* constraints, int32_t constraintCount,
                                     int32_t maxIter, double tolerance) {
    if (!initialSurface || initialSurface->surface.IsNull()) return nullptr;
    if (!constraints || constraintCount < 1) return nullptr;
    try {
        // NLPlate needs a bounded surface; if infinite, create a trimmed version
        Standard_Real u1, u2, v1, v2;
        initialSurface->surface->Bounds(u1, u2, v1, v2);

        Handle(Geom_Surface) workSurface = initialSurface->surface;
        bool needsTrim = Precision::IsNegativeInfinite(u1) || Precision::IsPositiveInfinite(u2) ||
                         Precision::IsNegativeInfinite(v1) || Precision::IsPositiveInfinite(v2);

        if (needsTrim) {
            // Find bounds from constraint points
            double minU = 1e30, maxU = -1e30, minV = 1e30, maxV = -1e30;
            for (int32_t i = 0; i < constraintCount; i++) {
                double cu = constraints[i * 5 + 0];
                double cv = constraints[i * 5 + 1];
                minU = std::min(minU, cu); maxU = std::max(maxU, cu);
                minV = std::min(minV, cv); maxV = std::max(maxV, cv);
            }
            // Extend domain beyond constraints
            double padU = std::max(10.0, (maxU - minU) * 0.5);
            double padV = std::max(10.0, (maxV - minV) * 0.5);
            u1 = minU - padU; u2 = maxU + padU;
            v1 = minV - padV; v2 = maxV + padV;

            workSurface = new Geom_RectangularTrimmedSurface(initialSurface->surface, u1, u2, v1, v2);
        }

        NLPlate_NLPlate solver(workSurface);

        for (int32_t i = 0; i < constraintCount; i++) {
            double u = constraints[i * 5 + 0];
            double v = constraints[i * 5 + 1];
            double tx = constraints[i * 5 + 2];
            double ty = constraints[i * 5 + 3];
            double tz = constraints[i * 5 + 4];

            gp_XY uv(u, v);
            gp_XYZ target(tx, ty, tz);
            Handle(NLPlate_HPG0Constraint) g0 = new NLPlate_HPG0Constraint(uv, target);
            solver.Load(g0);
        }

        solver.Solve2(maxIter);
        if (!solver.IsDone()) return nullptr;

        // Get working domain
        if (!needsTrim) {
            workSurface->Bounds(u1, u2, v1, v2);
            if (Precision::IsNegativeInfinite(u1)) u1 = -100.0;
            if (Precision::IsPositiveInfinite(u2)) u2 = 100.0;
            if (Precision::IsNegativeInfinite(v1)) v1 = -100.0;
            if (Precision::IsPositiveInfinite(v2)) v2 = 100.0;
        }

        // Sample the deformed surface and create BSpline approximation
        int nuPts = 20, nvPts = 20;
        TColgp_Array2OfPnt poles(1, nuPts, 1, nvPts);
        for (int iu = 1; iu <= nuPts; iu++) {
            double pu = u1 + (u2 - u1) * (iu - 1) / (nuPts - 1);
            for (int iv = 1; iv <= nvPts; iv++) {
                double pv = v1 + (v2 - v1) * (iv - 1) / (nvPts - 1);
                gp_XY uv(pu, pv);
                gp_XYZ disp = solver.Evaluate(uv);
                gp_Pnt origPt;
                workSurface->D0(pu, pv, origPt);
                gp_Pnt newPt(origPt.X() + disp.X(), origPt.Y() + disp.Y(), origPt.Z() + disp.Z());
                poles(iu, iv) = newPt;
            }
        }

        GeomAPI_PointsToBSplineSurface approx;
        approx.Init(poles, 3, 8, GeomAbs_C2, tolerance);
        Handle(Geom_BSplineSurface) result = approx.Surface();
        if (result.IsNull()) return nullptr;

        return new OCCTSurface(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceNLPlateG1(OCCTSurfaceRef initialSurface,
                                     const double* constraints, int32_t constraintCount,
                                     int32_t maxIter, double tolerance) {
    if (!initialSurface || initialSurface->surface.IsNull()) return nullptr;
    if (!constraints || constraintCount < 1) return nullptr;
    try {
        // NLPlate needs bounded surface
        Standard_Real u1, u2, v1, v2;
        initialSurface->surface->Bounds(u1, u2, v1, v2);

        Handle(Geom_Surface) workSurface = initialSurface->surface;
        bool needsTrim = Precision::IsNegativeInfinite(u1) || Precision::IsPositiveInfinite(u2) ||
                         Precision::IsNegativeInfinite(v1) || Precision::IsPositiveInfinite(v2);

        if (needsTrim) {
            double minU = 1e30, maxU = -1e30, minV = 1e30, maxV = -1e30;
            for (int32_t i = 0; i < constraintCount; i++) {
                double cu = constraints[i * 11 + 0];
                double cv = constraints[i * 11 + 1];
                minU = std::min(minU, cu); maxU = std::max(maxU, cu);
                minV = std::min(minV, cv); maxV = std::max(maxV, cv);
            }
            double padU = std::max(10.0, (maxU - minU) * 0.5);
            double padV = std::max(10.0, (maxV - minV) * 0.5);
            u1 = minU - padU; u2 = maxU + padU;
            v1 = minV - padV; v2 = maxV + padV;

            workSurface = new Geom_RectangularTrimmedSurface(initialSurface->surface, u1, u2, v1, v2);
        }

        NLPlate_NLPlate solver(workSurface);

        // constraints: flat (u, v, targetX, targetY, targetZ, d1uX, d1uY, d1uZ, d1vX, d1vY, d1vZ)
        for (int32_t i = 0; i < constraintCount; i++) {
            double u = constraints[i * 11 + 0];
            double v = constraints[i * 11 + 1];
            double tx = constraints[i * 11 + 2];
            double ty = constraints[i * 11 + 3];
            double tz = constraints[i * 11 + 4];
            double d1ux = constraints[i * 11 + 5];
            double d1uy = constraints[i * 11 + 6];
            double d1uz = constraints[i * 11 + 7];
            double d1vx = constraints[i * 11 + 8];
            double d1vy = constraints[i * 11 + 9];
            double d1vz = constraints[i * 11 + 10];

            gp_XY uv(u, v);
            gp_XYZ target(tx, ty, tz);
            gp_XYZ du(d1ux, d1uy, d1uz);
            gp_XYZ dv(d1vx, d1vy, d1vz);
            Plate_D1 d1(du, dv);
            Handle(NLPlate_HPG0G1Constraint) g0g1 = new NLPlate_HPG0G1Constraint(uv, target, d1);
            solver.Load(g0g1);
        }

        solver.Solve2(maxIter);
        if (!solver.IsDone()) return nullptr;

        if (!needsTrim) {
            workSurface->Bounds(u1, u2, v1, v2);
            if (Precision::IsNegativeInfinite(u1)) u1 = -100.0;
            if (Precision::IsPositiveInfinite(u2)) u2 = 100.0;
            if (Precision::IsNegativeInfinite(v1)) v1 = -100.0;
            if (Precision::IsPositiveInfinite(v2)) v2 = 100.0;
        }

        int nuPts = 20, nvPts = 20;
        TColgp_Array2OfPnt poles(1, nuPts, 1, nvPts);
        for (int iu = 1; iu <= nuPts; iu++) {
            double pu = u1 + (u2 - u1) * (iu - 1) / (nuPts - 1);
            for (int iv = 1; iv <= nvPts; iv++) {
                double pv = v1 + (v2 - v1) * (iv - 1) / (nvPts - 1);
                gp_XY uv(pu, pv);
                gp_XYZ disp = solver.Evaluate(uv);
                gp_Pnt origPt;
                workSurface->D0(pu, pv, origPt);
                gp_Pnt newPt(origPt.X() + disp.X(), origPt.Y() + disp.Y(), origPt.Z() + disp.Z());
                poles(iu, iv) = newPt;
            }
        }

        GeomAPI_PointsToBSplineSurface approx;
        approx.Init(poles, 3, 8, GeomAbs_C2, tolerance);
        Handle(Geom_BSplineSurface) result = approx.Surface();
        if (result.IsNull()) return nullptr;

        return new OCCTSurface(result);
    } catch (...) {
        return nullptr;
    }
}


