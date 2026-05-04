//
//  OCCTBridge_Geom2d.mm
//  OCCTSwift
//
//  Per-OCCT-module TU for the 2D geometry stack:
//
//  - Geom2d_* curve construction and conversion (line, circle, ellipse,
//    parabola, hyperbola, Bezier, BSpline, trimmed, offset)
//  - Geom2dAdaptor / Geom2dAPI / Geom2dConvert helpers
//  - Geom2dHatch (hatching) + HatchGen + Hatch_Hatcher
//  - Bisector_BisecCC / BisecPC (2D bisector curves)
//  - Geom2dGcc + GccAna (2D constraint solver)
//  - Geom2dGridEval (vectorized 2D curve sampling)
//  - gp_*2d primitives
//
//  Public C surface unchanged. No symbol changes — pure file move.
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

#include <Geom2d_Curve.hxx>
#include <Geom2dAdaptor_Curve.hxx>

#include <gp_Pnt2d.hxx>
#include <gp_Vec2d.hxx>
#include <gp_Dir2d.hxx>
#include <gp_Lin2d.hxx>

#include <Bnd_Box2d.hxx>
#include <BndLib_Add2dCurve.hxx>

#include <TopAbs.hxx>

// MARK: - Batch Curve2D Evaluation (v0.28.0)

#include <Geom2dGridEval_Curve.hxx>
#include <Geom2dGridEval.hxx>

int32_t OCCTCurve2DEvaluateGrid(OCCTCurve2DRef curve,
                                 const double* params, int32_t paramCount,
                                 double* outXY) {
    if (!curve || curve->curve.IsNull() || !params || !outXY || paramCount <= 0) return 0;
    try {
        Geom2dGridEval_Curve evaluator(curve->curve);

        NCollection_Array1<double> paramArr(1, paramCount);
        for (int32_t i = 0; i < paramCount; i++) {
            paramArr.SetValue(i + 1, params[i]);
        }

        NCollection_Array1<gp_Pnt2d> results = evaluator.EvaluateGrid(paramArr);
        int32_t n = results.Size();
        for (int32_t i = 0; i < n; i++) {
            const gp_Pnt2d& pt = results.Value(i + 1);
            outXY[i*2]   = pt.X();
            outXY[i*2+1] = pt.Y();
        }
        return n;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTCurve2DEvaluateGridD1(OCCTCurve2DRef curve,
                                   const double* params, int32_t paramCount,
                                   double* outXY, double* outDXDY) {
    if (!curve || curve->curve.IsNull() || !params || !outXY || !outDXDY || paramCount <= 0) return 0;
    try {
        Geom2dGridEval_Curve evaluator(curve->curve);

        NCollection_Array1<double> paramArr(1, paramCount);
        for (int32_t i = 0; i < paramCount; i++) {
            paramArr.SetValue(i + 1, params[i]);
        }

        NCollection_Array1<Geom2dGridEval::CurveD1> results = evaluator.EvaluateGridD1(paramArr);
        int32_t n = results.Size();
        for (int32_t i = 0; i < n; i++) {
            const Geom2dGridEval::CurveD1& r = results.Value(i + 1);
            outXY[i*2]     = r.Point.X();
            outXY[i*2+1]   = r.Point.Y();
            outDXDY[i*2]   = r.D1.X();
            outDXDY[i*2+1] = r.D1.Y();
        }
        return n;
    } catch (...) {
        return 0;
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

// MARK: - Hatching

#include <Geom2dHatch_Hatcher.hxx>
#include <Geom2dHatch_Intersector.hxx>
#include <HatchGen_Domain.hxx>

int32_t OCCTCurve2DHatch(const OCCTCurve2DRef* boundaries, int32_t boundaryCount,
                         double originX, double originY,
                         double dirX, double dirY,
                         double spacing, double tolerance,
                         double* outXY, int32_t maxPoints) {
    if (!boundaries || boundaryCount <= 0 || !outXY || maxPoints <= 0 || spacing <= 0) return 0;
    try {
        Geom2dHatch_Intersector intersector(tolerance, tolerance);
        Geom2dHatch_Hatcher hatcher(intersector, tolerance, tolerance);

        // Add boundary elements
        for (int32_t i = 0; i < boundaryCount; i++) {
            if (!boundaries[i] || boundaries[i]->curve.IsNull()) continue;
            Geom2dAdaptor_Curve adaptor(boundaries[i]->curve);
            hatcher.AddElement(adaptor, TopAbs_FORWARD);
        }

        // Compute bounding box for hatch range
        Bnd_Box2d box;
        for (int32_t i = 0; i < boundaryCount; i++) {
            if (!boundaries[i] || boundaries[i]->curve.IsNull()) continue;
            BndLib_Add2dCurve::Add(boundaries[i]->curve, 0.0, box);
        }
        if (box.IsVoid()) return 0;

        double xMin, yMin, xMax, yMax;
        box.Get(xMin, yMin, xMax, yMax);
        double diag = sqrt((xMax - xMin) * (xMax - xMin) + (yMax - yMin) * (yMax - yMin));
        if (diag < tolerance) return 0;

        gp_Dir2d dir(dirX, dirY);
        gp_Dir2d perp(-dirY, dirX);
        gp_Pnt2d origin(originX, originY);

        // Compute perpendicular extent
        double minPerp = 1e100, maxPerp = -1e100;
        double corners[4][2] = {{xMin, yMin}, {xMax, yMin}, {xMax, yMax}, {xMin, yMax}};
        for (int i = 0; i < 4; i++) {
            double dx = corners[i][0] - originX;
            double dy = corners[i][1] - originY;
            double proj = dx * perp.X() + dy * perp.Y();
            if (proj < minPerp) minPerp = proj;
            if (proj > maxPerp) maxPerp = proj;
        }

        // Add hatch lines
        int nLines = (int)((maxPerp - minPerp) / spacing) + 2;
        std::vector<int> hatchIndices;
        for (int i = 0; i < nLines; i++) {
            double offset = minPerp + i * spacing;
            gp_Pnt2d p(originX + perp.X() * offset, originY + perp.Y() * offset);
            gp_Lin2d line(p, dir);
            Geom2dAdaptor_Curve lineAdaptor(new Geom2d_Line(line));
            int idx = hatcher.AddHatching(lineAdaptor);
            hatchIndices.push_back(idx);
        }

        hatcher.Trim();
        hatcher.ComputeDomains();

        // Extract hatch segments
        int32_t pointIdx = 0;
        for (int idx : hatchIndices) {
            if (!hatcher.IsDone(idx)) continue;
            int nDomains = hatcher.NbDomains(idx);
            for (int d = 1; d <= nDomains; d++) {
                HatchGen_Domain domain = hatcher.Domain(idx, d);
                if (!domain.HasFirstPoint() || !domain.HasSecondPoint()) continue;
                double u1 = domain.FirstPoint().Parameter();
                double u2 = domain.SecondPoint().Parameter();
                // Get the hatch line curve
                const Geom2dAdaptor_Curve& hatchCurve = hatcher.HatchingCurve(idx);
                gp_Pnt2d p1 = hatchCurve.Value(u1);
                gp_Pnt2d p2 = hatchCurve.Value(u2);
                if (pointIdx + 4 > maxPoints * 2) break;
                outXY[pointIdx++] = p1.X();
                outXY[pointIdx++] = p1.Y();
                outXY[pointIdx++] = p2.X();
                outXY[pointIdx++] = p2.Y();
            }
        }
        return pointIdx / 4; // Each segment = 2 points = 4 doubles
    } catch (...) {
        return 0;
    }
}

// MARK: - Bisector

#include <Bisector_BisecCC.hxx>
#include <Bisector_BisecPC.hxx>

OCCTCurve2DRef OCCTCurve2DBisectorCC(OCCTCurve2DRef c1, OCCTCurve2DRef c2,
                                     double originX, double originY, bool side) {
    if (!c1 || c1->curve.IsNull() || !c2 || c2->curve.IsNull()) return nullptr;
    try {
        Handle(Bisector_BisecCC) bisector = new Bisector_BisecCC();
        gp_Pnt2d origin(originX, originY);
        double s = side ? 1.0 : -1.0;
        bisector->Perform(c1->curve, c2->curve, s, s, origin);
        if (bisector->IsEmpty()) return nullptr;
        // Return as Geom2d_Curve (Bisector_BisecCC inherits from Geom2d_Curve)
        Handle(Geom2d_Curve) result = bisector;
        return new OCCTCurve2D(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve2DRef OCCTCurve2DBisectorPC(double px, double py, OCCTCurve2DRef curve,
                                     double originX, double originY, bool side) {
    if (!curve || curve->curve.IsNull()) return nullptr;
    try {
        Handle(Bisector_BisecPC) bisector = new Bisector_BisecPC();
        gp_Pnt2d point(px, py);
        bisector->Perform(curve->curve, point, side ? 1.0 : -1.0);
        if (bisector->IsEmpty()) return nullptr;
        Handle(Geom2d_Curve) result = bisector;
        return new OCCTCurve2D(result);
    } catch (...) {
        return nullptr;
    }
}


