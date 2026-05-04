//
//  OCCTBridge_v029.mm
//  OCCTSwift
//
//  Extracted from OCCTBridge.mm — issue #99.
//
//  v0.29 cluster — fifteen sub-sections of additive operations grouped
//  together because each is small (~10-50 lines) and self-contained.
//  Per-area #include directives stay inline at section boundaries to
//  match the original layout.
//
//  Areas: Wedge primitive, NURBS conversion, Fast sewing, Normal
//  projection, Batch Curve3D + Surface evaluation, Wire explorer,
//  Half-space, Polynomial solvers, Sub-shape replacement, Periodic
//  shapes, Hatch patterns, Draft from shape, Curve planarity check,
//  Revolution feature.
//
//  Public C surface unchanged. No symbol changes — pure file move.
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

// === Headers shared across multiple subsections ===

#include <gp_Ax2.hxx>
#include <gp_Dir.hxx>
#include <gp_Dir2d.hxx>
#include <gp_Lin2d.hxx>
#include <gp_Pnt.hxx>
#include <gp_Pnt2d.hxx>
#include <gp_Vec2d.hxx>
#include <gp_XYZ.hxx>

#include <Geom2d_Curve.hxx>
#include <Geom_Curve.hxx>
#include <Geom_Surface.hxx>
#include <Geom_Plane.hxx>

#include <BRepAdaptor_Curve.hxx>
#include <BRepFeat_MakeRevol.hxx>
#include <GCPnts_TangentialDeflection.hxx>

#include <TopAbs.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>

// MARK: - Wedge Primitive (v0.29.0)

#include <BRepPrimAPI_MakeWedge.hxx>

OCCTShapeRef OCCTShapeCreateWedge(double dx, double dy, double dz, double ltx) {
    try {
        BRepPrimAPI_MakeWedge maker(dx, dy, dz, ltx);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateWedgeAdvanced(double dx, double dy, double dz,
                                           double xmin, double zmin, double xmax, double zmax) {
    try {
        BRepPrimAPI_MakeWedge maker(dx, dy, dz, xmin, zmin, xmax, zmax);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateWedgeOriented(
    double originX, double originY, double originZ,
    double dirX, double dirY, double dirZ,
    double dx, double dy, double dz, double ltx) {
    try {
        gp_Ax2 axis(gp_Pnt(originX, originY, originZ), gp_Dir(dirX, dirY, dirZ));
        BRepPrimAPI_MakeWedge maker(axis, dx, dy, dz, ltx);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - NURBS Conversion (v0.29.0)

#include <BRepBuilderAPI_NurbsConvert.hxx>

OCCTShapeRef OCCTShapeConvertToNURBS(OCCTShapeRef shape) {
    if (!shape) return nullptr;
    try {
        BRepBuilderAPI_NurbsConvert converter(shape->shape);
        if (!converter.IsDone()) return nullptr;
        return new OCCTShape(converter.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Fast Sewing (v0.29.0)

#include <BRepBuilderAPI_FastSewing.hxx>

OCCTShapeRef OCCTShapeFastSewn(OCCTShapeRef shape, double tolerance) {
    if (!shape) return nullptr;
    try {
        BRepBuilderAPI_FastSewing sewer(tolerance);
        sewer.Add(shape->shape);
        sewer.Perform();
        return new OCCTShape(sewer.GetResult());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Normal Projection (v0.29.0)

#include <BRepOffsetAPI_NormalProjection.hxx>

OCCTShapeRef OCCTShapeNormalProjection(OCCTShapeRef wireOrEdge, OCCTShapeRef surface,
                                        double tol3d, double tol2d, int maxDegree, int maxSeg) {
    if (!wireOrEdge || !surface) return nullptr;
    try {
        BRepOffsetAPI_NormalProjection proj(surface->shape);
        proj.Add(wireOrEdge->shape);
        proj.SetParams(tol3d, tol2d, GeomAbs_C2, maxDegree, maxSeg);
        proj.Build();
        if (!proj.IsDone()) return nullptr;
        return new OCCTShape(proj.Projection());
    } catch (...) {
        return nullptr;
    }
}

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

// MARK: - Wire Explorer (v0.29.0)

#include <BRepTools_WireExplorer.hxx>

int32_t OCCTWireExplorerEdgeCount(OCCTWireRef wire) {
    if (!wire) return 0;
    try {
        int32_t count = 0;
        for (BRepTools_WireExplorer exp(wire->wire); exp.More(); exp.Next()) {
            count++;
        }
        return count;
    } catch (...) {
        return 0;
    }
}

bool OCCTWireExplorerGetEdge(OCCTWireRef wire, int32_t index,
                              double* outPoints, int32_t maxPoints, int32_t* outPointCount) {
    if (!wire || !outPoints || !outPointCount || maxPoints <= 0 || index < 0) return false;
    try {
        int32_t current = 0;
        for (BRepTools_WireExplorer exp(wire->wire); exp.More(); exp.Next()) {
            if (current == index) {
                TopoDS_Edge edge = exp.Current();
                BRepAdaptor_Curve curve(edge);
                GCPnts_TangentialDeflection discretizer(curve, 0.01, 0.1);
                int32_t numPoints = std::min(discretizer.NbPoints(), maxPoints);
                for (int32_t i = 0; i < numPoints; i++) {
                    gp_Pnt pt = discretizer.Value(i + 1);
                    outPoints[i*3]   = pt.X();
                    outPoints[i*3+1] = pt.Y();
                    outPoints[i*3+2] = pt.Z();
                }
                *outPointCount = numPoints;
                return true;
            }
            current++;
        }
        return false;
    } catch (...) {
        return false;
    }
}

int32_t OCCTWireExplorerGetEdgePointCount(OCCTWireRef wire, int32_t index) {
    if (!wire || index < 0) return 0;
    try {
        int32_t current = 0;
        for (BRepTools_WireExplorer exp(wire->wire); exp.More(); exp.Next()) {
            if (current == index) {
                TopoDS_Edge edge = exp.Current();
                BRepAdaptor_Curve curve(edge);
                GCPnts_TangentialDeflection discretizer(curve, 0.01, 0.1);
                return discretizer.NbPoints();
            }
            current++;
        }
        return 0;
    } catch (...) {
        return 0;
    }
}

// MARK: - Half-Space (v0.29.0)

#include <BRepPrimAPI_MakeHalfSpace.hxx>

OCCTShapeRef OCCTShapeCreateHalfSpace(OCCTShapeRef faceShape, double refX, double refY, double refZ) {
    if (!faceShape) return nullptr;
    try {
        // Extract first face from the shape
        TopExp_Explorer exp(faceShape->shape, TopAbs_FACE);
        if (!exp.More()) return nullptr;
        TopoDS_Face face = TopoDS::Face(exp.Current());

        gp_Pnt refPt(refX, refY, refZ);
        BRepPrimAPI_MakeHalfSpace maker(face, refPt);
        return new OCCTShape(maker.Solid());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Polynomial Solvers (v0.29.0)

#include <math_DirectPolynomialRoots.hxx>
#include <algorithm>

OCCTPolynomialRoots OCCTSolveQuadratic(double a, double b, double c) {
    OCCTPolynomialRoots result;
    result.count = 0;
    result.roots[0] = result.roots[1] = result.roots[2] = result.roots[3] = 0.0;
    try {
        math_DirectPolynomialRoots solver(a, b, c);
        if (!solver.IsDone()) return result;
        result.count = std::min(solver.NbSolutions(), 4);
        for (int i = 0; i < result.count; i++) {
            result.roots[i] = solver.Value(i + 1);
        }
        std::sort(result.roots, result.roots + result.count);
    } catch (...) {}
    return result;
}

OCCTPolynomialRoots OCCTSolveCubic(double a, double b, double c, double d) {
    OCCTPolynomialRoots result;
    result.count = 0;
    result.roots[0] = result.roots[1] = result.roots[2] = result.roots[3] = 0.0;
    try {
        math_DirectPolynomialRoots solver(a, b, c, d);
        if (!solver.IsDone()) return result;
        result.count = std::min(solver.NbSolutions(), 4);
        for (int i = 0; i < result.count; i++) {
            result.roots[i] = solver.Value(i + 1);
        }
        std::sort(result.roots, result.roots + result.count);
    } catch (...) {}
    return result;
}

OCCTPolynomialRoots OCCTSolveQuartic(double a, double b, double c, double d, double e) {
    OCCTPolynomialRoots result;
    result.count = 0;
    result.roots[0] = result.roots[1] = result.roots[2] = result.roots[3] = 0.0;
    try {
        math_DirectPolynomialRoots solver(a, b, c, d, e);
        if (!solver.IsDone()) return result;
        result.count = std::min(solver.NbSolutions(), 4);
        for (int i = 0; i < result.count; i++) {
            result.roots[i] = solver.Value(i + 1);
        }
        std::sort(result.roots, result.roots + result.count);
    } catch (...) {}
    return result;
}

// MARK: - Sub-Shape Replacement (v0.29.0)

#include <BRepTools_ReShape.hxx>

OCCTShapeRef OCCTShapeReplaceSubShape(OCCTShapeRef shape, OCCTShapeRef oldSub, OCCTShapeRef newSub) {
    if (!shape || !oldSub || !newSub) return nullptr;
    try {
        Handle(BRepTools_ReShape) reshaper = new BRepTools_ReShape();
        reshaper->Replace(oldSub->shape, newSub->shape);
        TopoDS_Shape result = reshaper->Apply(shape->shape);
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeRemoveSubShape(OCCTShapeRef shape, OCCTShapeRef subToRemove) {
    if (!shape || !subToRemove) return nullptr;
    try {
        Handle(BRepTools_ReShape) reshaper = new BRepTools_ReShape();
        reshaper->Remove(subToRemove->shape);
        TopoDS_Shape result = reshaper->Apply(shape->shape);
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Periodic Shapes (v0.29.0)

#include <BOPAlgo_MakePeriodic.hxx>

OCCTShapeRef OCCTShapeMakePeriodic(OCCTShapeRef shape,
                                    bool xPeriodic, double xPeriod,
                                    bool yPeriodic, double yPeriod,
                                    bool zPeriodic, double zPeriod) {
    if (!shape) return nullptr;
    try {
        BOPAlgo_MakePeriodic maker;
        maker.SetShape(shape->shape);
        if (xPeriodic) maker.MakeXPeriodic(true, xPeriod);
        if (yPeriodic) maker.MakeYPeriodic(true, yPeriod);
        if (zPeriodic) maker.MakeZPeriodic(true, zPeriod);
        maker.Perform();
        if (maker.HasErrors()) return nullptr;
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeRepeat(OCCTShapeRef shape,
                              bool xPeriodic, double xPeriod,
                              bool yPeriodic, double yPeriod,
                              bool zPeriodic, double zPeriod,
                              int32_t xTimes, int32_t yTimes, int32_t zTimes) {
    if (!shape) return nullptr;
    try {
        BOPAlgo_MakePeriodic maker;
        maker.SetShape(shape->shape);
        if (xPeriodic) maker.MakeXPeriodic(true, xPeriod);
        if (yPeriodic) maker.MakeYPeriodic(true, yPeriod);
        if (zPeriodic) maker.MakeZPeriodic(true, zPeriod);
        maker.Perform();
        if (maker.HasErrors()) return nullptr;

        // Now repeat in each direction
        if (xPeriodic && xTimes > 0) maker.XRepeat(xTimes);
        if (yPeriodic && yTimes > 0) maker.YRepeat(yTimes);
        if (zPeriodic && zTimes > 0) maker.ZRepeat(zTimes);

        return new OCCTShape(maker.RepeatedShape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Hatch Patterns (v0.29.0)

#include <Hatch_Hatcher.hxx>

int32_t OCCTHatchLines(const double* boundaryXY, int32_t boundaryCount,
                        double dirX, double dirY, double spacing, double offset,
                        double* outSegments, int32_t maxSegments) {
    if (!boundaryXY || boundaryCount < 3 || !outSegments || maxSegments <= 0 || spacing <= 0.0)
        return 0;
    try {
        double tolerance = 1.0e-7;
        // Use unoriented mode so intervals are always finite
        Hatch_Hatcher hatcher(tolerance, false);

        // Compute perpendicular direction for hatch lines
        double dirLen = std::sqrt(dirX * dirX + dirY * dirY);
        if (dirLen < 1.0e-12) return 0;
        double ndx = dirX / dirLen;
        double ndy = dirY / dirLen;
        // Perpendicular: rotate 90 degrees
        double perpX = -ndy;
        double perpY = ndx;

        // Compute bounding range along perpendicular direction
        double minDist = 1.0e30, maxDist = -1.0e30;
        for (int32_t i = 0; i < boundaryCount; i++) {
            double px = boundaryXY[i * 2];
            double py = boundaryXY[i * 2 + 1];
            double dist = px * perpX + py * perpY;
            if (dist < minDist) minDist = dist;
            if (dist > maxDist) maxDist = dist;
        }

        // Add hatch lines using direction + distance form
        gp_Dir2d hatchDir(ndx, ndy);
        double startDist = std::floor((minDist - offset) / spacing) * spacing + offset;
        for (double dist = startDist; dist <= maxDist; dist += spacing) {
            hatcher.AddLine(hatchDir, dist);
        }

        // Trim hatch lines with boundary segments
        for (int32_t i = 0; i < boundaryCount; i++) {
            int32_t j = (i + 1) % boundaryCount;
            gp_Pnt2d p1(boundaryXY[i * 2], boundaryXY[i * 2 + 1]);
            gp_Pnt2d p2(boundaryXY[j * 2], boundaryXY[j * 2 + 1]);
            hatcher.Trim(p1, p2);
        }

        // Extract hatch segments
        int32_t segCount = 0;
        for (int lineIdx = 1; lineIdx <= hatcher.NbLines(); lineIdx++) {
            for (int intIdx = 1; intIdx <= hatcher.NbIntervals(lineIdx); intIdx++) {
                if (segCount >= maxSegments) break;
                double startParam = hatcher.Start(lineIdx, intIdx);
                double endParam = hatcher.End(lineIdx, intIdx);
                // Convert parameter back to point using the line equation
                const gp_Lin2d& line = hatcher.Line(lineIdx);
                gp_Pnt2d pt1 = line.Location().Translated(gp_Vec2d(line.Direction()) * startParam);
                gp_Pnt2d pt2 = line.Location().Translated(gp_Vec2d(line.Direction()) * endParam);
                outSegments[segCount * 4]     = pt1.X();
                outSegments[segCount * 4 + 1] = pt1.Y();
                outSegments[segCount * 4 + 2] = pt2.X();
                outSegments[segCount * 4 + 3] = pt2.Y();
                segCount++;
            }
        }
        return segCount;
    } catch (...) {
        return 0;
    }
}

// MARK: - Draft from Shape (v0.29.0)

#include <BRepOffsetAPI_MakeDraft.hxx>

OCCTShapeRef OCCTShapeMakeDraft(OCCTShapeRef shape, double dirX, double dirY, double dirZ,
                                 double angle, double lengthMax) {
    if (!shape) return nullptr;
    try {
        gp_Dir dir(dirX, dirY, dirZ);
        BRepOffsetAPI_MakeDraft maker(shape->shape, dir, angle);
        maker.Perform(lengthMax);
        if (!maker.IsDone()) return nullptr;
        return new OCCTShape(maker.Shell());
    } catch (...) {
        return nullptr;
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

// MARK: - Revolution Feature (v0.29.0)
// NOTE: BRepFeat_MakeRevol is skipped. It requires identifying the correct sketch face
// from the profile shape, which is highly context-dependent and cannot be reliably
// automated in a generic C bridge. Use OCCTShapeCreateRevolution (sweep) + boolean
// operations instead.

