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

#include <Adaptor2d_Curve2d.hxx>
#include <Approx_Curve2d.hxx>
#include <GC_MakeLine2d.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <Geom2d_Curve.hxx>
#include <Geom2dAdaptor_Curve.hxx>
#include <ShapeCustom_Curve2d.hxx>
#include <TColgp_Array1OfPnt2d.hxx>

#include <gp_Pnt2d.hxx>
#include <gp_Vec2d.hxx>
#include <gp_Dir2d.hxx>
#include <gp_Lin2d.hxx>

#include <Bnd_Box2d.hxx>
#include <BndLib_Add2dCurve.hxx>

#include <BRepMAT2d_BisectingLocus.hxx>
#include <BRepMAT2d_Explorer.hxx>
#include <BRepMAT2d_LinkTopoBilo.hxx>
#include <Bisector_Bisec.hxx>
#include <MAT_Arc.hxx>
#include <MAT_BasicElt.hxx>
#include <MAT_Graph.hxx>
#include <MAT_Node.hxx>
#include <MAT_Side.hxx>
#include <Geom2d_TrimmedCurve.hxx>
#include <Geom2dAPI_ProjectPointOnCurve.hxx>

#include <TopAbs.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>

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


// MARK: - BRepMAT2d: Medial Axis Transform (v0.24.0)

#include <BRepMAT2d_BisectingLocus.hxx>
#include <BRepMAT2d_Explorer.hxx>
#include <BRepMAT2d_LinkTopoBilo.hxx>
#include <MAT_Graph.hxx>
#include <MAT_Arc.hxx>
#include <MAT_Node.hxx>
#include <MAT_BasicElt.hxx>
#include <MAT_SequenceOfArc.hxx>
#include <MAT_SequenceOfBasicElt.hxx>
#include <Bisector_Bisec.hxx>
#include <Geom2dAPI_ProjectPointOnCurve.hxx>
#include <Geom2d_Curve.hxx>

struct OCCTMedialAxis {
    BRepMAT2d_BisectingLocus locus;
    BRepMAT2d_Explorer explorer;
    Handle(MAT_Graph) graph;
    // Cached boundary curves for distance computation
    std::vector<Handle(Geom2d_Curve)> boundaryCurves;

    // Compute distance from a 2D point to the nearest boundary curve
    double distanceToBoundary(const gp_Pnt2d& pt) const {
        double minDist = std::numeric_limits<double>::max();
        for (const auto& curve : boundaryCurves) {
            if (curve.IsNull()) continue;
            try {
                Geom2dAPI_ProjectPointOnCurve proj(pt, curve);
                if (proj.NbPoints() > 0) {
                    double d = proj.LowerDistance();
                    if (d < minDist) minDist = d;
                }
            } catch (...) {
                continue;
            }
        }
        return (minDist < std::numeric_limits<double>::max()) ? minDist : 0.0;
    }
};

OCCTMedialAxisRef OCCTMedialAxisCompute(OCCTShapeRef shape, double tolerance) {
    if (!shape) return nullptr;
    try {
        // Extract the first face from the shape
        TopExp_Explorer faceExp(shape->shape, TopAbs_FACE);
        if (!faceExp.More()) return nullptr;
        TopoDS_Face face = TopoDS::Face(faceExp.Current());

        auto ma = new OCCTMedialAxis();
        ma->explorer.Perform(face);

        ma->locus.Compute(ma->explorer, 1, MAT_Left, GeomAbs_Arc, Standard_False);
        if (!ma->locus.IsDone()) {
            delete ma;
            return nullptr;
        }

        ma->graph = ma->locus.Graph();
        if (ma->graph.IsNull() || ma->graph->NumberOfArcs() == 0) {
            delete ma;
            return nullptr;
        }

        // Cache boundary curves for distance computation
        int numContours = ma->explorer.NumberOfContours();
        for (int c = 1; c <= numContours; c++) {
            ma->explorer.Init(c);
            while (ma->explorer.More()) {
                Handle(Geom2d_Curve) curve = ma->explorer.Value();
                if (!curve.IsNull()) {
                    ma->boundaryCurves.push_back(curve);
                }
                ma->explorer.Next();
            }
        }

        return ma;
    } catch (...) {
        return nullptr;
    }
}

void OCCTMedialAxisRelease(OCCTMedialAxisRef ma) {
    delete ma;
}

int32_t OCCTMedialAxisGetArcCount(OCCTMedialAxisRef ma) {
    if (!ma || ma->graph.IsNull()) return 0;
    return (int32_t)ma->graph->NumberOfArcs();
}

int32_t OCCTMedialAxisGetNodeCount(OCCTMedialAxisRef ma) {
    if (!ma || ma->graph.IsNull()) return 0;
    return (int32_t)ma->graph->NumberOfNodes();
}

bool OCCTMedialAxisGetNode(OCCTMedialAxisRef ma, int32_t index, OCCTMedialAxisNode* outNode) {
    if (!ma || !outNode || ma->graph.IsNull()) return false;
    if (index < 1 || index > ma->graph->NumberOfNodes()) return false;
    try {
        Handle(MAT_Node) node = ma->graph->Node(index);
        if (node.IsNull()) return false;

        gp_Pnt2d pt = ma->locus.GeomElt(node);
        outNode->index = index;
        outNode->x = pt.X();
        outNode->y = pt.Y();
        // Compute distance from node to nearest boundary curve
        outNode->distance = ma->distanceToBoundary(pt);
        outNode->isPending = node->PendingNode();
        outNode->isOnBoundary = node->OnBasicElt();
        return true;
    } catch (...) {
        return false;
    }
}

bool OCCTMedialAxisGetArc(OCCTMedialAxisRef ma, int32_t index, OCCTMedialAxisArc* outArc) {
    if (!ma || !outArc || ma->graph.IsNull()) return false;
    if (index < 1 || index > ma->graph->NumberOfArcs()) return false;
    try {
        Handle(MAT_Arc) arc = ma->graph->Arc(index);
        if (arc.IsNull()) return false;

        outArc->index = arc->Index();
        outArc->geomIndex = arc->GeomIndex();
        outArc->firstNodeIndex = arc->FirstNode()->Index();
        outArc->secondNodeIndex = arc->SecondNode()->Index();
        outArc->firstEltIndex = arc->FirstElement()->Index();
        outArc->secondEltIndex = arc->SecondElement()->Index();
        return true;
    } catch (...) {
        return false;
    }
}

int32_t OCCTMedialAxisDrawArc(OCCTMedialAxisRef ma, int32_t arcIndex,
                               double* outXY, int32_t maxPoints) {
    if (!ma || !outXY || maxPoints < 2 || ma->graph.IsNull()) return 0;
    if (arcIndex < 1 || arcIndex > ma->graph->NumberOfArcs()) return 0;
    try {
        Handle(MAT_Arc) arc = ma->graph->Arc(arcIndex);
        if (arc.IsNull()) return 0;

        Standard_Boolean reverse = Standard_False;
        Bisector_Bisec bisec = ma->locus.GeomBis(arc, reverse);
        Handle(Geom2d_TrimmedCurve) trimmed = bisec.Value();
        if (trimmed.IsNull()) return 0;

        double u0 = trimmed->FirstParameter();
        double u1 = trimmed->LastParameter();

        // Clamp infinite parameters
        if (Precision::IsNegativeInfinite(u0)) u0 = -1000.0;
        if (Precision::IsPositiveInfinite(u1)) u1 = 1000.0;

        // Get node positions as fallback endpoints
        gp_Pnt2d firstPt = ma->locus.GeomElt(arc->FirstNode());
        gp_Pnt2d lastPt = ma->locus.GeomElt(arc->SecondNode());

        int32_t numPoints = maxPoints;
        for (int32_t i = 0; i < numPoints; i++) {
            double t = (numPoints > 1) ? (double)i / (numPoints - 1) : 0.0;
            double u = u0 + t * (u1 - u0);
            try {
                gp_Pnt2d pt;
                trimmed->D0(u, pt);
                outXY[i * 2 + 0] = pt.X();
                outXY[i * 2 + 1] = pt.Y();
            } catch (...) {
                // Fallback: interpolate between node positions
                double tx = firstPt.X() + t * (lastPt.X() - firstPt.X());
                double ty = firstPt.Y() + t * (lastPt.Y() - firstPt.Y());
                outXY[i * 2 + 0] = tx;
                outXY[i * 2 + 1] = ty;
            }
        }
        return numPoints;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTMedialAxisDrawAll(OCCTMedialAxisRef ma,
                               double* outXY, int32_t maxPoints,
                               int32_t* lineStarts, int32_t* lineLengths, int32_t maxLines) {
    if (!ma || !outXY || !lineStarts || !lineLengths || ma->graph.IsNull()) return 0;
    int32_t arcCount = (int32_t)ma->graph->NumberOfArcs();
    if (arcCount == 0) return 0;

    int32_t pointsPerArc = maxPoints / std::max(arcCount, (int32_t)1);
    if (pointsPerArc < 2) pointsPerArc = 2;

    int32_t totalPoints = 0;
    int32_t lineCount = 0;

    for (int32_t i = 1; i <= arcCount && lineCount < maxLines; i++) {
        int32_t remaining = maxPoints - totalPoints;
        int32_t pts = std::min(pointsPerArc, remaining);
        if (pts < 2) break;

        int32_t drawn = OCCTMedialAxisDrawArc(ma, i, outXY + totalPoints * 2, pts);
        if (drawn > 0) {
            lineStarts[lineCount] = totalPoints;
            lineLengths[lineCount] = drawn;
            lineCount++;
            totalPoints += drawn;
        }
    }
    return totalPoints;
}

double OCCTMedialAxisDistanceOnArc(OCCTMedialAxisRef ma, int32_t arcIndex, double t) {
    if (!ma || ma->graph.IsNull()) return -1.0;
    if (arcIndex < 1 || arcIndex > ma->graph->NumberOfArcs()) return -1.0;
    try {
        Handle(MAT_Arc) arc = ma->graph->Arc(arcIndex);
        if (arc.IsNull()) return -1.0;

        // Compute boundary distances at both endpoints
        gp_Pnt2d pt1 = ma->locus.GeomElt(arc->FirstNode());
        gp_Pnt2d pt2 = ma->locus.GeomElt(arc->SecondNode());
        double d1 = ma->distanceToBoundary(pt1);
        double d2 = ma->distanceToBoundary(pt2);

        // Linear interpolation between node distances
        t = std::max(0.0, std::min(1.0, t));
        return d1 + t * (d2 - d1);
    } catch (...) {
        return -1.0;
    }
}

double OCCTMedialAxisMinThickness(OCCTMedialAxisRef ma) {
    if (!ma || ma->graph.IsNull()) return -1.0;
    try {
        double minDist = std::numeric_limits<double>::max();
        int32_t nodeCount = (int32_t)ma->graph->NumberOfNodes();
        for (int32_t i = 1; i <= nodeCount; i++) {
            Handle(MAT_Node) node = ma->graph->Node(i);
            if (!node.IsNull() && !node->Infinite()) {
                gp_Pnt2d pt = ma->locus.GeomElt(node);
                double d = ma->distanceToBoundary(pt);
                if (d > 0 && d < minDist) minDist = d;
            }
        }
        return (minDist < std::numeric_limits<double>::max()) ? minDist : -1.0;
    } catch (...) {
        return -1.0;
    }
}

int32_t OCCTMedialAxisGetBasicEltCount(OCCTMedialAxisRef ma) {
    if (!ma || ma->graph.IsNull()) return 0;
    return (int32_t)ma->graph->NumberOfBasicElts();
}



// MARK: - GC_MakeLine2d (v0.51)
// --- GC_MakeLine2d ---

OCCTCurve2DRef _Nullable OCCTCurve2DMakeLineThroughPoints(double p1x, double p1y,
    double p2x, double p2y) {
    try {
        GC_MakeLine2d ml(gp_Pnt2d(p1x, p1y), gp_Pnt2d(p2x, p2y));
        if (!ml.IsDone()) return nullptr;
        auto* curve = new OCCTCurve2D();
        curve->curve = ml.Value();
        return curve;
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve2DRef _Nullable OCCTCurve2DMakeLineParallel(double px, double py,
    double dx, double dy, double distance) {
    try {
        gp_Lin2d lin(gp_Pnt2d(px, py), gp_Dir2d(dx, dy));
        GC_MakeLine2d ml(lin, distance);
        if (!ml.IsDone()) return nullptr;
        auto* curve = new OCCTCurve2D();
        curve->curve = ml.Value();
        return curve;
    } catch (...) {
        return nullptr;
    }
}

// MARK: - ShapeCustom_Curve2d (v0.52)
// --- ShapeCustom_Curve2d ---

bool OCCTCurve2DIsLinear(OCCTCurve2DRef curve2D, double tolerance, double* deviation) {
    if (!curve2D || !deviation) return false;
    try {
        Handle(Geom2d_BSplineCurve) bsp = Handle(Geom2d_BSplineCurve)::DownCast(curve2D->curve);
        if (bsp.IsNull()) return false;
        TColgp_Array1OfPnt2d poles(1, bsp->NbPoles());
        for (int i = 1; i <= bsp->NbPoles(); i++) {
            poles(i) = bsp->Pole(i);
        }
        return ShapeCustom_Curve2d::IsLinear(poles, tolerance, *deviation);
    } catch (...) {
        return false;
    }
}

OCCTCurve2DRef _Nullable OCCTCurve2DConvertToLine(OCCTCurve2DRef curve2D,
    double first, double last, double tolerance,
    double* newFirst, double* newLast, double* deviation) {
    if (!curve2D || !newFirst || !newLast || !deviation) return nullptr;
    try {
        Handle(Geom2d_Line) line = ShapeCustom_Curve2d::ConvertToLine2d(
            curve2D->curve, first, last, tolerance, *newFirst, *newLast, *deviation);
        if (line.IsNull()) return nullptr;
        auto* result = new OCCTCurve2D();
        result->curve = line;
        return result;
    } catch (...) {
        return nullptr;
    }
}

bool OCCTCurve2DSimplifyBSpline(OCCTCurve2DRef curve2D, double tolerance) {
    if (!curve2D) return false;
    try {
        Handle(Geom2d_BSplineCurve) bsp = Handle(Geom2d_BSplineCurve)::DownCast(curve2D->curve);
        if (bsp.IsNull()) return false;
        return ShapeCustom_Curve2d::SimplifyBSpline2d(bsp, tolerance);
    } catch (...) {
        return false;
    }
}

// MARK: - Approx_Curve2d (v0.52)
// --- Approx_Curve2d ---

OCCTCurve2DRef _Nullable OCCTApproxCurve2d(OCCTCurve2DRef curve2D,
    double first, double last, double tolU, double tolV,
    int32_t maxDegree, int32_t maxSegments) {
    if (!curve2D) return nullptr;
    try {
        Handle(Adaptor2d_Curve2d) adaptor = new Geom2dAdaptor_Curve(curve2D->curve, first, last);
        Approx_Curve2d approx(adaptor, first, last, tolU, tolV, GeomAbs_C2, maxDegree, maxSegments);
        if (!approx.IsDone() || !approx.HasResult()) return nullptr;
        Handle(Geom2d_BSplineCurve) bsp = approx.Curve();
        if (bsp.IsNull()) return nullptr;
        auto* result = new OCCTCurve2D();
        result->curve = bsp;
        return result;
    } catch (...) {
        return nullptr;
    }
}
