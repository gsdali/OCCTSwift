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
#include <BRepAdaptor_Curve2d.hxx>
#include <FairCurve_AnalysisCode.hxx>
#include <FairCurve_Batten.hxx>
#include <FairCurve_MinimalVariation.hxx>
#include <BRepBuilderAPI_MakeEdge2d.hxx>
#include <GC_MakeLine2d.hxx>
#include <GccEnt_Position.hxx>
#include <Geom2d_AxisPlacement.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <Geom2d_CartesianPoint.hxx>
#include <Geom2d_Curve.hxx>
#include <Geom2d_Direction.hxx>
#include <Geom2d_Point.hxx>
#include <Geom2d_Transformation.hxx>
#include <Geom2d_VectorWithMagnitude.hxx>
#include <LProp_CIType.hxx>
#include <LProp_CurAndInf.hxx>
#include <Geom2dAdaptor_Curve.hxx>
#include <Geom2dGcc_Circ2d2TanRad.hxx>
#include <Geom2dGcc_Circ2d3Tan.hxx>
#include <Geom2dGcc_Circ2dTanCen.hxx>
#include <Geom2dGcc_Lin2d2Tan.hxx>
#include <Geom2dGcc_QualifiedCurve.hxx>
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

// MARK: - Gcc Constraint Solver (v0.16)
// MARK: - Gcc Constraint Solver

static GccEnt_Position toGccPosition(int32_t q) {
    switch (q) {
        case 1: return GccEnt_enclosing;
        case 2: return GccEnt_enclosed;
        case 3: return GccEnt_outside;
        default: return GccEnt_unqualified;
    }
}

static Geom2dGcc_QualifiedCurve makeQualifiedCurve(OCCTCurve2DRef c, int32_t q) {
    Geom2dAdaptor_Curve adaptor(c->curve);
    return Geom2dGcc_QualifiedCurve(adaptor, toGccPosition(q));
}

int32_t OCCTGccCircle2d3Tan(OCCTCurve2DRef c1, int32_t q1,
                            OCCTCurve2DRef c2, int32_t q2,
                            OCCTCurve2DRef c3, int32_t q3,
                            double tolerance,
                            OCCTGccCircleSolution* out, int32_t max) {
    if (!c1 || !c2 || !c3 || !out || max <= 0) return 0;
    if (c1->curve.IsNull() || c2->curve.IsNull() || c3->curve.IsNull()) return 0;
    try {
        Geom2dGcc_QualifiedCurve qc1 = makeQualifiedCurve(c1, q1);
        Geom2dGcc_QualifiedCurve qc2 = makeQualifiedCurve(c2, q2);
        Geom2dGcc_QualifiedCurve qc3 = makeQualifiedCurve(c3, q3);
        Geom2dGcc_Circ2d3Tan solver(qc1, qc2, qc3, tolerance, 0, 0, 0);
        if (!solver.IsDone()) return 0;
        int32_t n = std::min((int32_t)solver.NbSolutions(), max);
        for (int32_t i = 0; i < n; i++) {
            gp_Circ2d circ = solver.ThisSolution(i + 1);
            out[i].cx = circ.Location().X();
            out[i].cy = circ.Location().Y();
            out[i].radius = circ.Radius();
            GccEnt_Position qq1, qq2, qq3;
            solver.WhichQualifier(i + 1, qq1, qq2, qq3);
            out[i].qualifier = (int32_t)qq1;
        }
        return n;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTGccCircle2d2TanPt(OCCTCurve2DRef c1, int32_t q1,
                              OCCTCurve2DRef c2, int32_t q2,
                              double px, double py,
                              double tolerance,
                              OCCTGccCircleSolution* out, int32_t max) {
    if (!c1 || !c2 || !out || max <= 0) return 0;
    if (c1->curve.IsNull() || c2->curve.IsNull()) return 0;
    try {
        Geom2dGcc_QualifiedCurve qc1 = makeQualifiedCurve(c1, q1);
        Geom2dGcc_QualifiedCurve qc2 = makeQualifiedCurve(c2, q2);
        Handle(Geom2d_CartesianPoint) point = new Geom2d_CartesianPoint(px, py);
        Geom2dGcc_Circ2d3Tan solver(qc1, qc2, point, tolerance, 0, 0);
        if (!solver.IsDone()) return 0;
        int32_t n = std::min((int32_t)solver.NbSolutions(), max);
        for (int32_t i = 0; i < n; i++) {
            gp_Circ2d circ = solver.ThisSolution(i + 1);
            out[i].cx = circ.Location().X();
            out[i].cy = circ.Location().Y();
            out[i].radius = circ.Radius();
            out[i].qualifier = 0;
        }
        return n;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTGccCircle2dTanCen(OCCTCurve2DRef curve, int32_t qualifier,
                              double cx, double cy, double tolerance,
                              OCCTGccCircleSolution* out, int32_t max) {
    if (!curve || curve->curve.IsNull() || !out || max <= 0) return 0;
    try {
        Geom2dGcc_QualifiedCurve qc = makeQualifiedCurve(curve, qualifier);
        Handle(Geom2d_CartesianPoint) center = new Geom2d_CartesianPoint(cx, cy);
        Geom2dGcc_Circ2dTanCen solver(qc, center, tolerance);
        if (!solver.IsDone()) return 0;
        int32_t n = std::min((int32_t)solver.NbSolutions(), max);
        for (int32_t i = 0; i < n; i++) {
            gp_Circ2d circ = solver.ThisSolution(i + 1);
            out[i].cx = circ.Location().X();
            out[i].cy = circ.Location().Y();
            out[i].radius = circ.Radius();
            out[i].qualifier = 0;
        }
        return n;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTGccCircle2d2TanRad(OCCTCurve2DRef c1, int32_t q1,
                               OCCTCurve2DRef c2, int32_t q2,
                               double radius, double tolerance,
                               OCCTGccCircleSolution* out, int32_t max) {
    if (!c1 || !c2 || !out || max <= 0) return 0;
    if (c1->curve.IsNull() || c2->curve.IsNull()) return 0;
    if (radius <= 0) return 0;
    try {
        Geom2dGcc_QualifiedCurve qc1 = makeQualifiedCurve(c1, q1);
        Geom2dGcc_QualifiedCurve qc2 = makeQualifiedCurve(c2, q2);
        Geom2dGcc_Circ2d2TanRad solver(qc1, qc2, radius, tolerance);
        if (!solver.IsDone()) return 0;
        int32_t n = std::min((int32_t)solver.NbSolutions(), max);
        for (int32_t i = 0; i < n; i++) {
            gp_Circ2d circ = solver.ThisSolution(i + 1);
            out[i].cx = circ.Location().X();
            out[i].cy = circ.Location().Y();
            out[i].radius = circ.Radius();
            out[i].qualifier = 0;
        }
        return n;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTGccCircle2dTanPtRad(OCCTCurve2DRef curve, int32_t qualifier,
                                double px, double py,
                                double radius, double tolerance,
                                OCCTGccCircleSolution* out, int32_t max) {
    if (!curve || curve->curve.IsNull() || !out || max <= 0) return 0;
    if (radius <= 0) return 0;
    try {
        Geom2dGcc_QualifiedCurve qc = makeQualifiedCurve(curve, qualifier);
        Handle(Geom2d_CartesianPoint) point = new Geom2d_CartesianPoint(px, py);
        Geom2dGcc_Circ2d2TanRad solver(qc, point, radius, tolerance);
        if (!solver.IsDone()) return 0;
        int32_t n = std::min((int32_t)solver.NbSolutions(), max);
        for (int32_t i = 0; i < n; i++) {
            gp_Circ2d circ = solver.ThisSolution(i + 1);
            out[i].cx = circ.Location().X();
            out[i].cy = circ.Location().Y();
            out[i].radius = circ.Radius();
            out[i].qualifier = 0;
        }
        return n;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTGccCircle2d2PtRad(double p1x, double p1y, double p2x, double p2y,
                              double radius, double tolerance,
                              OCCTGccCircleSolution* out, int32_t max) {
    if (!out || max <= 0 || radius <= 0) return 0;
    try {
        Handle(Geom2d_CartesianPoint) pt1 = new Geom2d_CartesianPoint(p1x, p1y);
        Handle(Geom2d_CartesianPoint) pt2 = new Geom2d_CartesianPoint(p2x, p2y);
        Geom2dGcc_Circ2d2TanRad solver(pt1, pt2, radius, tolerance);
        if (!solver.IsDone()) return 0;
        int32_t n = std::min((int32_t)solver.NbSolutions(), max);
        for (int32_t i = 0; i < n; i++) {
            gp_Circ2d circ = solver.ThisSolution(i + 1);
            out[i].cx = circ.Location().X();
            out[i].cy = circ.Location().Y();
            out[i].radius = circ.Radius();
            out[i].qualifier = 0;
        }
        return n;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTGccCircle2d3Pt(double p1x, double p1y, double p2x, double p2y,
                           double p3x, double p3y, double tolerance,
                           OCCTGccCircleSolution* out, int32_t max) {
    if (!out || max <= 0) return 0;
    try {
        Handle(Geom2d_CartesianPoint) pt1 = new Geom2d_CartesianPoint(p1x, p1y);
        Handle(Geom2d_CartesianPoint) pt2 = new Geom2d_CartesianPoint(p2x, p2y);
        Handle(Geom2d_CartesianPoint) pt3 = new Geom2d_CartesianPoint(p3x, p3y);
        Geom2dGcc_Circ2d3Tan solver(pt1, pt2, pt3, tolerance);
        if (!solver.IsDone()) return 0;
        int32_t n = std::min((int32_t)solver.NbSolutions(), max);
        for (int32_t i = 0; i < n; i++) {
            gp_Circ2d circ = solver.ThisSolution(i + 1);
            out[i].cx = circ.Location().X();
            out[i].cy = circ.Location().Y();
            out[i].radius = circ.Radius();
            out[i].qualifier = 0;
        }
        return n;
    } catch (...) {
        return 0;
    }
}

// Gcc Line Construction

int32_t OCCTGccLine2d2Tan(OCCTCurve2DRef c1, int32_t q1,
                          OCCTCurve2DRef c2, int32_t q2,
                          double tolerance,
                          OCCTGccLineSolution* out, int32_t max) {
    if (!c1 || !c2 || !out || max <= 0) return 0;
    if (c1->curve.IsNull() || c2->curve.IsNull()) return 0;
    try {
        Geom2dGcc_QualifiedCurve qc1 = makeQualifiedCurve(c1, q1);
        Geom2dGcc_QualifiedCurve qc2 = makeQualifiedCurve(c2, q2);
        Geom2dGcc_Lin2d2Tan solver(qc1, qc2, tolerance);
        if (!solver.IsDone()) return 0;
        int32_t n = std::min((int32_t)solver.NbSolutions(), max);
        for (int32_t i = 0; i < n; i++) {
            gp_Lin2d lin = solver.ThisSolution(i + 1);
            out[i].px = lin.Location().X();
            out[i].py = lin.Location().Y();
            out[i].dx = lin.Direction().X();
            out[i].dy = lin.Direction().Y();
            out[i].qualifier = 0;
        }
        return n;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTGccLine2dTanPt(OCCTCurve2DRef curve, int32_t qualifier,
                           double px, double py, double tolerance,
                           OCCTGccLineSolution* out, int32_t max) {
    if (!curve || curve->curve.IsNull() || !out || max <= 0) return 0;
    try {
        Geom2dGcc_QualifiedCurve qc = makeQualifiedCurve(curve, qualifier);
        gp_Pnt2d point(px, py);
        Geom2dGcc_Lin2d2Tan solver(qc, point, tolerance);
        if (!solver.IsDone()) return 0;
        int32_t n = std::min((int32_t)solver.NbSolutions(), max);
        for (int32_t i = 0; i < n; i++) {
            gp_Lin2d lin = solver.ThisSolution(i + 1);
            out[i].px = lin.Location().X();
            out[i].py = lin.Location().Y();
            out[i].dx = lin.Direction().X();
            out[i].dy = lin.Direction().Y();
            out[i].qualifier = 0;
        }
        return n;
    } catch (...) {
        return 0;
    }
}

// MARK: - 2D Geometry Completions: GccAna / Geom2dGcc / IntAna2d / Extrema 2D / GeomLProp / Bisector_BisecAna (v0.53)
// MARK: - v0.53.0: 2D Geometry Completions
// ============================================================================

#include <GccAna_Pnt2dBisec.hxx>
#include <GccAna_Lin2dBisec.hxx>
#include <GccAna_LinPnt2dBisec.hxx>
#include <GccAna_Circ2dBisec.hxx>
#include <GccAna_CircLin2dBisec.hxx>
#include <GccAna_CircPnt2dBisec.hxx>
#include <GccAna_Lin2dTanPar.hxx>
#include <GccAna_Lin2dTanPer.hxx>
#include <GccAna_Lin2dTanObl.hxx>
#include <GccAna_Circ2d2TanOn.hxx>
#include <GccAna_Circ2dTanOnRad.hxx>
#include <GccInt_Bisec.hxx>
#include <GccInt_IType.hxx>
#include <GccInt_BCirc.hxx>
#include <GccInt_BLine.hxx>
#include <GccInt_BElips.hxx>
#include <GccInt_BHyper.hxx>
#include <GccInt_BParab.hxx>
#include <Geom2dGcc_Circ2d2TanOn.hxx>
#include <Geom2dGcc_Circ2dTanOnRad.hxx>
#include <Geom2dGcc_Lin2dTanObl.hxx>
#include <IntAna2d_AnaIntersection.hxx>
#include <IntAna2d_IntPoint.hxx>
#include <Extrema_ExtElC2d.hxx>
#include <Extrema_ExtPElC2d.hxx>
#include <Extrema_ExtCC2d.hxx>
#include <Extrema_POnCurv2d.hxx>
#include <GeomLProp_CurAndInf2d.hxx>
#include <LProp_CurAndInf.hxx>
#include <LProp_CIType.hxx>
#include <Bisector_BisecAna.hxx>
#include <GeomAbs_JoinType.hxx>
#include <gp_Elips2d.hxx>
#include <gp_Parab2d.hxx>
#include <gp_Hypr2d.hxx>
#include <Geom2d_CartesianPoint.hxx>
#include <GccEnt_QualifiedLin.hxx>
#include <GccEnt_QualifiedCirc.hxx>

// Helper to extract bisector solution from GccInt_Bisec
static void extractBisecSolution(const Handle(GccInt_Bisec)& bisec, OCCTBisecSolution* out) {
    GccInt_IType type = bisec->ArcType();
    switch (type) {
        case GccInt_Lin: {
            gp_Lin2d lin = bisec->Line();
            out->type = OCCTBisecTypeLine;
            out->px = lin.Location().X();
            out->py = lin.Location().Y();
            out->dx = lin.Direction().X();
            out->dy = lin.Direction().Y();
            out->radius = 0;
            break;
        }
        case GccInt_Cir: {
            gp_Circ2d circ = bisec->Circle();
            out->type = OCCTBisecTypeCircle;
            out->px = circ.Location().X();
            out->py = circ.Location().Y();
            out->dx = 0; out->dy = 0;
            out->radius = circ.Radius();
            break;
        }
        case GccInt_Ell: {
            gp_Elips2d ell = bisec->Ellipse();
            out->type = OCCTBisecTypeEllipse;
            out->px = ell.Location().X();
            out->py = ell.Location().Y();
            out->dx = ell.MajorRadius();
            out->dy = ell.MinorRadius();
            out->radius = 0;
            break;
        }
        case GccInt_Hpr: {
            gp_Hypr2d hyp = bisec->Hyperbola();
            out->type = OCCTBisecTypeHyperbola;
            out->px = hyp.Location().X();
            out->py = hyp.Location().Y();
            out->dx = hyp.MajorRadius();
            out->dy = hyp.MinorRadius();
            out->radius = 0;
            break;
        }
        case GccInt_Par: {
            gp_Parab2d par = bisec->Parabola();
            out->type = OCCTBisecTypeParabola;
            out->px = par.Location().X();
            out->py = par.Location().Y();
            out->dx = par.Focal();
            out->dy = 0;
            out->radius = 0;
            break;
        }
        default: {
            out->type = OCCTBisecTypePoint;
            out->px = 0; out->py = 0;
            out->dx = 0; out->dy = 0;
            out->radius = 0;
            break;
        }
    }
}

// --- GccAna_Pnt2dBisec ---
bool OCCTGccAnaPnt2dBisec(double p1x, double p1y, double p2x, double p2y,
                          double* outPx, double* outPy, double* outDx, double* outDy) {
    try {
        GccAna_Pnt2dBisec bisec(gp_Pnt2d(p1x, p1y), gp_Pnt2d(p2x, p2y));
        if (!bisec.HasSolution()) return false;
        gp_Lin2d line = bisec.ThisSolution();
        *outPx = line.Location().X();
        *outPy = line.Location().Y();
        *outDx = line.Direction().X();
        *outDy = line.Direction().Y();
        return true;
    } catch (...) { return false; }
}

// --- GccAna_Lin2dBisec ---
int32_t OCCTGccAnaLin2dBisec(double l1px, double l1py, double l1dx, double l1dy,
                             double l2px, double l2py, double l2dx, double l2dy,
                             OCCTGccLineSolution* out, int32_t max) {
    try {
        gp_Lin2d l1(gp_Pnt2d(l1px, l1py), gp_Dir2d(l1dx, l1dy));
        gp_Lin2d l2(gp_Pnt2d(l2px, l2py), gp_Dir2d(l2dx, l2dy));
        GccAna_Lin2dBisec bisec(l1, l2);
        if (!bisec.IsDone()) return 0;
        int32_t nb = std::min((int32_t)bisec.NbSolutions(), max);
        for (int32_t i = 0; i < nb; i++) {
            gp_Lin2d sol = bisec.ThisSolution(i + 1);
            out[i].px = sol.Location().X();
            out[i].py = sol.Location().Y();
            out[i].dx = sol.Direction().X();
            out[i].dy = sol.Direction().Y();
            out[i].qualifier = 0;
        }
        return nb;
    } catch (...) { return 0; }
}

// --- GccAna_LinPnt2dBisec ---
bool OCCTGccAnaLinPnt2dBisec(double lpx, double lpy, double ldx, double ldy,
                             double px, double py,
                             OCCTBisecSolution* out) {
    try {
        gp_Lin2d line(gp_Pnt2d(lpx, lpy), gp_Dir2d(ldx, ldy));
        GccAna_LinPnt2dBisec bisec(line, gp_Pnt2d(px, py));
        if (!bisec.IsDone()) return false;
        Handle(GccInt_Bisec) sol = bisec.ThisSolution();
        extractBisecSolution(sol, out);
        return true;
    } catch (...) { return false; }
}

// --- GccAna_Circ2dBisec ---
int32_t OCCTGccAnaCirc2dBisec(double c1x, double c1y, double c1r,
                              double c2x, double c2y, double c2r,
                              OCCTBisecSolution* out, int32_t max) {
    try {
        gp_Circ2d circ1(gp_Ax22d(gp_Pnt2d(c1x, c1y), gp_Dir2d(1, 0)), c1r);
        gp_Circ2d circ2(gp_Ax22d(gp_Pnt2d(c2x, c2y), gp_Dir2d(1, 0)), c2r);
        GccAna_Circ2dBisec bisec(circ1, circ2);
        if (!bisec.IsDone()) return 0;
        int32_t nb = std::min((int32_t)bisec.NbSolutions(), max);
        for (int32_t i = 0; i < nb; i++) {
            Handle(GccInt_Bisec) sol = bisec.ThisSolution(i + 1);
            extractBisecSolution(sol, &out[i]);
        }
        return nb;
    } catch (...) { return 0; }
}

// --- GccAna_CircLin2dBisec ---
int32_t OCCTGccAnaCircLin2dBisec(double cx, double cy, double cr,
                                 double lpx, double lpy, double ldx, double ldy,
                                 OCCTBisecSolution* out, int32_t max) {
    try {
        gp_Circ2d circ(gp_Ax22d(gp_Pnt2d(cx, cy), gp_Dir2d(1, 0)), cr);
        gp_Lin2d line(gp_Pnt2d(lpx, lpy), gp_Dir2d(ldx, ldy));
        GccAna_CircLin2dBisec bisec(circ, line);
        if (!bisec.IsDone()) return 0;
        int32_t nb = std::min((int32_t)bisec.NbSolutions(), max);
        for (int32_t i = 0; i < nb; i++) {
            Handle(GccInt_Bisec) sol = bisec.ThisSolution(i + 1);
            extractBisecSolution(sol, &out[i]);
        }
        return nb;
    } catch (...) { return 0; }
}

// --- GccAna_CircPnt2dBisec ---
int32_t OCCTGccAnaCircPnt2dBisec(double cx, double cy, double cr,
                                 double px, double py,
                                 OCCTBisecSolution* out, int32_t max) {
    try {
        gp_Circ2d circ(gp_Ax22d(gp_Pnt2d(cx, cy), gp_Dir2d(1, 0)), cr);
        GccAna_CircPnt2dBisec bisec(circ, gp_Pnt2d(px, py));
        if (!bisec.IsDone()) return 0;
        int32_t nb = std::min((int32_t)bisec.NbSolutions(), max);
        for (int32_t i = 0; i < nb; i++) {
            Handle(GccInt_Bisec) sol = bisec.ThisSolution(i + 1);
            extractBisecSolution(sol, &out[i]);
        }
        return nb;
    } catch (...) { return 0; }
}

// --- GccAna_Lin2dTanPar (point version) ---
int32_t OCCTGccAnaLin2dTanParPt(double px, double py,
                                double lpx, double lpy, double ldx, double ldy,
                                OCCTGccLineSolution* out, int32_t max) {
    try {
        gp_Pnt2d pt(px, py);
        gp_Lin2d ref(gp_Pnt2d(lpx, lpy), gp_Dir2d(ldx, ldy));
        GccAna_Lin2dTanPar solver(pt, ref);
        if (!solver.IsDone()) return 0;
        int32_t nb = std::min((int32_t)solver.NbSolutions(), max);
        for (int32_t i = 0; i < nb; i++) {
            gp_Lin2d sol = solver.ThisSolution(i + 1);
            out[i].px = sol.Location().X();
            out[i].py = sol.Location().Y();
            out[i].dx = sol.Direction().X();
            out[i].dy = sol.Direction().Y();
            out[i].qualifier = 0;
        }
        return nb;
    } catch (...) { return 0; }
}

// --- GccAna_Lin2dTanPar (circle version) ---
int32_t OCCTGccAnaLin2dTanParCirc(double cx, double cy, double cr, int32_t qualifier,
                                  double lpx, double lpy, double ldx, double ldy,
                                  OCCTGccLineSolution* out, int32_t max) {
    try {
        gp_Circ2d circ(gp_Ax22d(gp_Pnt2d(cx, cy), gp_Dir2d(1, 0)), cr);
        gp_Lin2d ref(gp_Pnt2d(lpx, lpy), gp_Dir2d(ldx, ldy));
        GccEnt_QualifiedCirc qc(circ, toGccPosition(qualifier));
        GccAna_Lin2dTanPar solver(qc, ref);
        if (!solver.IsDone()) return 0;
        int32_t nb = std::min((int32_t)solver.NbSolutions(), max);
        for (int32_t i = 0; i < nb; i++) {
            gp_Lin2d sol = solver.ThisSolution(i + 1);
            out[i].px = sol.Location().X();
            out[i].py = sol.Location().Y();
            out[i].dx = sol.Direction().X();
            out[i].dy = sol.Direction().Y();
            GccEnt_Position pos;
            solver.WhichQualifier(i + 1, pos);
            out[i].qualifier = (int32_t)pos;
        }
        return nb;
    } catch (...) { return 0; }
}

// --- GccAna_Lin2dTanPer (point + line version) ---
int32_t OCCTGccAnaLin2dTanPerPtLin(double px, double py,
                                   double lpx, double lpy, double ldx, double ldy,
                                   OCCTGccLineSolution* out, int32_t max) {
    try {
        gp_Pnt2d pt(px, py);
        gp_Lin2d ref(gp_Pnt2d(lpx, lpy), gp_Dir2d(ldx, ldy));
        GccAna_Lin2dTanPer solver(pt, ref);
        if (!solver.IsDone()) return 0;
        int32_t nb = std::min((int32_t)solver.NbSolutions(), max);
        for (int32_t i = 0; i < nb; i++) {
            gp_Lin2d sol = solver.ThisSolution(i + 1);
            out[i].px = sol.Location().X();
            out[i].py = sol.Location().Y();
            out[i].dx = sol.Direction().X();
            out[i].dy = sol.Direction().Y();
            out[i].qualifier = 0;
        }
        return nb;
    } catch (...) { return 0; }
}

// --- GccAna_Lin2dTanPer (circle + line version) ---
int32_t OCCTGccAnaLin2dTanPerCircLin(double cx, double cy, double cr, int32_t qualifier,
                                     double lpx, double lpy, double ldx, double ldy,
                                     OCCTGccLineSolution* out, int32_t max) {
    try {
        gp_Circ2d circ(gp_Ax22d(gp_Pnt2d(cx, cy), gp_Dir2d(1, 0)), cr);
        gp_Lin2d ref(gp_Pnt2d(lpx, lpy), gp_Dir2d(ldx, ldy));
        GccEnt_QualifiedCirc qc(circ, toGccPosition(qualifier));
        GccAna_Lin2dTanPer solver(qc, ref);
        if (!solver.IsDone()) return 0;
        int32_t nb = std::min((int32_t)solver.NbSolutions(), max);
        for (int32_t i = 0; i < nb; i++) {
            gp_Lin2d sol = solver.ThisSolution(i + 1);
            out[i].px = sol.Location().X();
            out[i].py = sol.Location().Y();
            out[i].dx = sol.Direction().X();
            out[i].dy = sol.Direction().Y();
            GccEnt_Position pos;
            solver.WhichQualifier(i + 1, pos);
            out[i].qualifier = (int32_t)pos;
        }
        return nb;
    } catch (...) { return 0; }
}

// --- GccAna_Lin2dTanObl (point version) ---
int32_t OCCTGccAnaLin2dTanOblPt(double px, double py,
                                double lpx, double lpy, double ldx, double ldy,
                                double angle,
                                OCCTGccLineSolution* out, int32_t max) {
    try {
        gp_Pnt2d pt(px, py);
        gp_Lin2d ref(gp_Pnt2d(lpx, lpy), gp_Dir2d(ldx, ldy));
        GccAna_Lin2dTanObl solver(pt, ref, angle);
        if (!solver.IsDone()) return 0;
        int32_t nb = std::min((int32_t)solver.NbSolutions(), max);
        for (int32_t i = 0; i < nb; i++) {
            gp_Lin2d sol = solver.ThisSolution(i + 1);
            out[i].px = sol.Location().X();
            out[i].py = sol.Location().Y();
            out[i].dx = sol.Direction().X();
            out[i].dy = sol.Direction().Y();
            out[i].qualifier = 0;
        }
        return nb;
    } catch (...) { return 0; }
}

// --- Geom2dGcc_Lin2dTanObl ---
int32_t OCCTGeom2dGccLin2dTanObl(OCCTCurve2DRef curve, int32_t qualifier,
                                 double lpx, double lpy, double ldx, double ldy,
                                 double tolerance, double angle,
                                 OCCTGccLineSolution* out, int32_t max) {
    try {
        Geom2dAdaptor_Curve adaptor(curve->curve);
        Geom2dGcc_QualifiedCurve qc(adaptor, toGccPosition(qualifier));
        gp_Lin2d ref(gp_Pnt2d(lpx, lpy), gp_Dir2d(ldx, ldy));
        Geom2dGcc_Lin2dTanObl solver(qc, ref, tolerance, angle);
        if (!solver.IsDone()) return 0;
        int32_t nb = std::min((int32_t)solver.NbSolutions(), max);
        for (int32_t i = 0; i < nb; i++) {
            gp_Lin2d sol = solver.ThisSolution(i + 1);
            out[i].px = sol.Location().X();
            out[i].py = sol.Location().Y();
            out[i].dx = sol.Direction().X();
            out[i].dy = sol.Direction().Y();
            GccEnt_Position pos;
            solver.WhichQualifier(i + 1, pos);
            out[i].qualifier = (int32_t)pos;
        }
        return nb;
    } catch (...) { return 0; }
}

// --- GccAna_Circ2d2TanOn (2 qualified lines, center on line) ---
int32_t OCCTGccAnaCirc2d2TanOnLinLin(double l1px, double l1py, double l1dx, double l1dy, int32_t q1,
                                     double l2px, double l2py, double l2dx, double l2dy, int32_t q2,
                                     double onPx, double onPy, double onDx, double onDy,
                                     double tolerance,
                                     OCCTGccCircleSolution* out, int32_t max) {
    try {
        gp_Lin2d l1(gp_Pnt2d(l1px, l1py), gp_Dir2d(l1dx, l1dy));
        gp_Lin2d l2(gp_Pnt2d(l2px, l2py), gp_Dir2d(l2dx, l2dy));
        gp_Lin2d onLine(gp_Pnt2d(onPx, onPy), gp_Dir2d(onDx, onDy));
        GccEnt_QualifiedLin ql1(l1, toGccPosition(q1));
        GccEnt_QualifiedLin ql2(l2, toGccPosition(q2));
        GccAna_Circ2d2TanOn solver(ql1, ql2, onLine, tolerance);
        if (!solver.IsDone()) return 0;
        int32_t nb = std::min((int32_t)solver.NbSolutions(), max);
        for (int32_t i = 0; i < nb; i++) {
            gp_Circ2d sol = solver.ThisSolution(i + 1);
            out[i].cx = sol.Location().X();
            out[i].cy = sol.Location().Y();
            out[i].radius = sol.Radius();
            out[i].qualifier = 0;
        }
        return nb;
    } catch (...) { return 0; }
}

// --- GccAna_Circ2dTanOnRad (qualified line, center on line, given radius) ---
int32_t OCCTGccAnaCirc2dTanOnRadLin(double lpx, double lpy, double ldx, double ldy, int32_t qualifier,
                                    double onPx, double onPy, double onDx, double onDy,
                                    double radius, double tolerance,
                                    OCCTGccCircleSolution* out, int32_t max) {
    try {
        gp_Lin2d l1(gp_Pnt2d(lpx, lpy), gp_Dir2d(ldx, ldy));
        gp_Lin2d onLine(gp_Pnt2d(onPx, onPy), gp_Dir2d(onDx, onDy));
        GccEnt_QualifiedLin ql1(l1, toGccPosition(qualifier));
        GccAna_Circ2dTanOnRad solver(ql1, onLine, radius, tolerance);
        if (!solver.IsDone()) return 0;
        int32_t nb = std::min((int32_t)solver.NbSolutions(), max);
        for (int32_t i = 0; i < nb; i++) {
            gp_Circ2d sol = solver.ThisSolution(i + 1);
            out[i].cx = sol.Location().X();
            out[i].cy = sol.Location().Y();
            out[i].radius = sol.Radius();
            out[i].qualifier = 0;
        }
        return nb;
    } catch (...) { return 0; }
}

// --- Geom2dGcc_Circ2d2TanOn ---
int32_t OCCTGeom2dGccCirc2d2TanOn(OCCTCurve2DRef c1, int32_t q1,
                                  OCCTCurve2DRef c2, int32_t q2,
                                  OCCTCurve2DRef onCurve,
                                  double tolerance,
                                  double initParam1, double initParam2, double initParamOn,
                                  OCCTGccCircleSolution* out, int32_t max) {
    try {
        Geom2dAdaptor_Curve ac1(c1->curve), ac2(c2->curve), aon(onCurve->curve);
        Geom2dGcc_QualifiedCurve qc1(ac1, toGccPosition(q1));
        Geom2dGcc_QualifiedCurve qc2(ac2, toGccPosition(q2));
        Geom2dGcc_Circ2d2TanOn solver(qc1, qc2, aon, tolerance, initParam1, initParam2, initParamOn);
        if (!solver.IsDone()) return 0;
        int32_t nb = std::min((int32_t)solver.NbSolutions(), max);
        for (int32_t i = 0; i < nb; i++) {
            gp_Circ2d sol = solver.ThisSolution(i + 1);
            out[i].cx = sol.Location().X();
            out[i].cy = sol.Location().Y();
            out[i].radius = sol.Radius();
            out[i].qualifier = 0;
        }
        return nb;
    } catch (...) { return 0; }
}

// --- Geom2dGcc_Circ2dTanOnRad ---
int32_t OCCTGeom2dGccCirc2dTanOnRad(OCCTCurve2DRef curve, int32_t qualifier,
                                    OCCTCurve2DRef onCurve,
                                    double radius, double tolerance,
                                    OCCTGccCircleSolution* out, int32_t max) {
    try {
        Geom2dAdaptor_Curve ac(curve->curve), aon(onCurve->curve);
        Geom2dGcc_QualifiedCurve qc(ac, toGccPosition(qualifier));
        Geom2dGcc_Circ2dTanOnRad solver(qc, aon, radius, tolerance);
        if (!solver.IsDone()) return 0;
        int32_t nb = std::min((int32_t)solver.NbSolutions(), max);
        for (int32_t i = 0; i < nb; i++) {
            gp_Circ2d sol = solver.ThisSolution(i + 1);
            out[i].cx = sol.Location().X();
            out[i].cy = sol.Location().Y();
            out[i].radius = sol.Radius();
            out[i].qualifier = 0;
        }
        return nb;
    } catch (...) { return 0; }
}

// --- IntAna2d_AnaIntersection: Line-Line ---
int32_t OCCTIntAna2dLinLin(double l1px, double l1py, double l1dx, double l1dy,
                           double l2px, double l2py, double l2dx, double l2dy,
                           OCCTIntAna2dPoint* out, int32_t max) {
    try {
        gp_Lin2d l1(gp_Pnt2d(l1px, l1py), gp_Dir2d(l1dx, l1dy));
        gp_Lin2d l2(gp_Pnt2d(l2px, l2py), gp_Dir2d(l2dx, l2dy));
        IntAna2d_AnaIntersection inter(l1, l2);
        if (!inter.IsDone() || inter.IsEmpty()) return 0;
        int32_t nb = std::min((int32_t)inter.NbPoints(), max);
        for (int32_t i = 0; i < nb; i++) {
            const IntAna2d_IntPoint& pt = inter.Point(i + 1);
            out[i].x = pt.Value().X();
            out[i].y = pt.Value().Y();
            out[i].param1 = pt.ParamOnFirst();
            out[i].param2 = pt.ParamOnSecond();
        }
        return nb;
    } catch (...) { return 0; }
}

// --- IntAna2d_AnaIntersection: Line-Circle ---
int32_t OCCTIntAna2dLinCirc(double lpx, double lpy, double ldx, double ldy,
                            double cx, double cy, double cr,
                            OCCTIntAna2dPoint* out, int32_t max) {
    try {
        gp_Lin2d line(gp_Pnt2d(lpx, lpy), gp_Dir2d(ldx, ldy));
        gp_Circ2d circ(gp_Ax22d(gp_Pnt2d(cx, cy), gp_Dir2d(1, 0)), cr);
        IntAna2d_AnaIntersection inter(line, circ);
        if (!inter.IsDone() || inter.IsEmpty()) return 0;
        int32_t nb = std::min((int32_t)inter.NbPoints(), max);
        for (int32_t i = 0; i < nb; i++) {
            const IntAna2d_IntPoint& pt = inter.Point(i + 1);
            out[i].x = pt.Value().X();
            out[i].y = pt.Value().Y();
            out[i].param1 = pt.ParamOnFirst();
            out[i].param2 = pt.ParamOnSecond();
        }
        return nb;
    } catch (...) { return 0; }
}

// --- IntAna2d_AnaIntersection: Circle-Circle ---
int32_t OCCTIntAna2dCircCirc(double c1x, double c1y, double c1r,
                             double c2x, double c2y, double c2r,
                             OCCTIntAna2dPoint* out, int32_t max) {
    try {
        gp_Circ2d circ1(gp_Ax22d(gp_Pnt2d(c1x, c1y), gp_Dir2d(1, 0)), c1r);
        gp_Circ2d circ2(gp_Ax22d(gp_Pnt2d(c2x, c2y), gp_Dir2d(1, 0)), c2r);
        IntAna2d_AnaIntersection inter(circ1, circ2);
        if (!inter.IsDone() || inter.IsEmpty()) return 0;
        int32_t nb = std::min((int32_t)inter.NbPoints(), max);
        for (int32_t i = 0; i < nb; i++) {
            const IntAna2d_IntPoint& pt = inter.Point(i + 1);
            out[i].x = pt.Value().X();
            out[i].y = pt.Value().Y();
            out[i].param1 = pt.ParamOnFirst();
            out[i].param2 = pt.ParamOnSecond();
        }
        return nb;
    } catch (...) { return 0; }
}

// --- Extrema_ExtElC2d: Line-Line ---
int32_t OCCTExtremaExtElC2dLinLin(double l1px, double l1py, double l1dx, double l1dy,
                                  double l2px, double l2py, double l2dx, double l2dy,
                                  double tolerance,
                                  bool* outIsParallel,
                                  OCCTExtrema2dResult* out, int32_t max) {
    try {
        gp_Lin2d l1(gp_Pnt2d(l1px, l1py), gp_Dir2d(l1dx, l1dy));
        gp_Lin2d l2(gp_Pnt2d(l2px, l2py), gp_Dir2d(l2dx, l2dy));
        Extrema_ExtElC2d ext(l1, l2, tolerance);
        if (!ext.IsDone()) return -1;
        *outIsParallel = ext.IsParallel();
        if (ext.IsParallel()) {
            if (max >= 1) {
                out[0].squareDistance = ext.SquareDistance(1);
                out[0].param1 = 0; out[0].param2 = 0;
                out[0].p1x = l1px; out[0].p1y = l1py;
                out[0].p2x = l2px; out[0].p2y = l2py;
                return 1;
            }
            return 0;
        }
        int32_t nb = std::min((int32_t)ext.NbExt(), max);
        for (int32_t i = 0; i < nb; i++) {
            out[i].squareDistance = ext.SquareDistance(i + 1);
            Extrema_POnCurv2d p1, p2;
            ext.Points(i + 1, p1, p2);
            out[i].param1 = p1.Parameter();
            out[i].param2 = p2.Parameter();
            out[i].p1x = p1.Value().X();
            out[i].p1y = p1.Value().Y();
            out[i].p2x = p2.Value().X();
            out[i].p2y = p2.Value().Y();
        }
        return nb;
    } catch (...) { return -1; }
}

// --- Extrema_ExtElC2d: Line-Circle ---
int32_t OCCTExtremaExtElC2dLinCirc(double lpx, double lpy, double ldx, double ldy,
                                   double cx, double cy, double cr,
                                   double tolerance,
                                   OCCTExtrema2dResult* out, int32_t max) {
    try {
        gp_Lin2d line(gp_Pnt2d(lpx, lpy), gp_Dir2d(ldx, ldy));
        gp_Circ2d circ(gp_Ax22d(gp_Pnt2d(cx, cy), gp_Dir2d(1, 0)), cr);
        Extrema_ExtElC2d ext(line, circ, tolerance);
        if (!ext.IsDone()) return -1;
        int32_t nb = std::min((int32_t)ext.NbExt(), max);
        for (int32_t i = 0; i < nb; i++) {
            out[i].squareDistance = ext.SquareDistance(i + 1);
            Extrema_POnCurv2d p1, p2;
            ext.Points(i + 1, p1, p2);
            out[i].param1 = p1.Parameter();
            out[i].param2 = p2.Parameter();
            out[i].p1x = p1.Value().X();
            out[i].p1y = p1.Value().Y();
            out[i].p2x = p2.Value().X();
            out[i].p2y = p2.Value().Y();
        }
        return nb;
    } catch (...) { return -1; }
}

// --- Extrema_ExtPElC2d: Point-Circle ---
int32_t OCCTExtremaExtPElC2dCirc(double px, double py,
                                 double cx, double cy, double cr,
                                 double tolerance,
                                 OCCTExtrema2dResult* out, int32_t max) {
    try {
        gp_Pnt2d pt(px, py);
        gp_Circ2d circ(gp_Ax22d(gp_Pnt2d(cx, cy), gp_Dir2d(1, 0)), cr);
        Extrema_ExtPElC2d ext(pt, circ, tolerance, 0, 2 * M_PI);
        if (!ext.IsDone()) return -1;
        int32_t nb = std::min((int32_t)ext.NbExt(), max);
        for (int32_t i = 0; i < nb; i++) {
            out[i].squareDistance = ext.SquareDistance(i + 1);
            Extrema_POnCurv2d pc = ext.Point(i + 1);
            out[i].param1 = 0;
            out[i].param2 = pc.Parameter();
            out[i].p1x = px; out[i].p1y = py;
            out[i].p2x = pc.Value().X();
            out[i].p2y = pc.Value().Y();
        }
        return nb;
    } catch (...) { return -1; }
}

// --- Extrema_ExtPElC2d: Point-Line ---
int32_t OCCTExtremaExtPElC2dLin(double px, double py,
                                double lpx, double lpy, double ldx, double ldy,
                                double tolerance,
                                OCCTExtrema2dResult* out, int32_t max) {
    try {
        gp_Pnt2d pt(px, py);
        gp_Lin2d line(gp_Pnt2d(lpx, lpy), gp_Dir2d(ldx, ldy));
        Extrema_ExtPElC2d ext(pt, line, tolerance, -1e10, 1e10);
        if (!ext.IsDone()) return -1;
        int32_t nb = std::min((int32_t)ext.NbExt(), max);
        for (int32_t i = 0; i < nb; i++) {
            out[i].squareDistance = ext.SquareDistance(i + 1);
            Extrema_POnCurv2d pc = ext.Point(i + 1);
            out[i].param1 = 0;
            out[i].param2 = pc.Parameter();
            out[i].p1x = px; out[i].p1y = py;
            out[i].p2x = pc.Value().X();
            out[i].p2y = pc.Value().Y();
        }
        return nb;
    } catch (...) { return -1; }
}

// --- Extrema_ExtCC2d ---
int32_t OCCTExtremaExtCC2d(OCCTCurve2DRef c1, double first1, double last1,
                           OCCTCurve2DRef c2, double first2, double last2,
                           OCCTExtrema2dResult* out, int32_t max) {
    try {
        Geom2dAdaptor_Curve ac1(c1->curve, first1, last1);
        Geom2dAdaptor_Curve ac2(c2->curve, first2, last2);
        Extrema_ExtCC2d ext(ac1, ac2);
        if (!ext.IsDone()) return -1;
        int32_t nb = std::min((int32_t)ext.NbExt(), max);
        for (int32_t i = 0; i < nb; i++) {
            out[i].squareDistance = ext.SquareDistance(i + 1);
            Extrema_POnCurv2d p1, p2;
            ext.Points(i + 1, p1, p2);
            out[i].param1 = p1.Parameter();
            out[i].param2 = p2.Parameter();
            out[i].p1x = p1.Value().X();
            out[i].p1y = p1.Value().Y();
            out[i].p2x = p2.Value().X();
            out[i].p2y = p2.Value().Y();
        }
        return nb;
    } catch (...) { return -1; }
}

// --- GeomLProp_CurAndInf2d (was Geom2dLProp_NumericCurInf2d in RC4) ---
int32_t OCCTGeom2dLPropCurExt(OCCTCurve2DRef curve,
                              OCCTCurInfPoint* out, int32_t max) {
    try {
        GeomLProp_CurAndInf2d solver;
        solver.PerformCurExt(curve->curve);
        if (!solver.IsDone()) return 0;
        int32_t nb = std::min((int32_t)solver.NbPoints(), max);
        for (int32_t i = 0; i < nb; i++) {
            out[i].parameter = solver.Parameter(i + 1);
            LProp_CIType t = solver.Type(i + 1);
            if (t == LProp_MinCur) out[i].type = 0;
            else if (t == LProp_MaxCur) out[i].type = 1;
            else out[i].type = 2;
        }
        return nb;
    } catch (...) { return 0; }
}

int32_t OCCTGeom2dLPropCurInf(OCCTCurve2DRef curve,
                              OCCTCurInfPoint* out, int32_t max) {
    try {
        GeomLProp_CurAndInf2d solver;
        solver.PerformInf(curve->curve);
        if (!solver.IsDone()) return 0;
        int32_t nb = std::min((int32_t)solver.NbPoints(), max);
        for (int32_t i = 0; i < nb; i++) {
            out[i].parameter = solver.Parameter(i + 1);
            out[i].type = 2;
        }
        return nb;
    } catch (...) { return 0; }
}

// --- Bisector_BisecAna ---
OCCTCurve2DRef _Nullable OCCTBisectorBisecAnaCurveCurve(
    OCCTCurve2DRef curve1, OCCTCurve2DRef curve2,
    double px, double py,
    double v1x, double v1y, double v2x, double v2y,
    double sense, double tolerance) {
    try {
        Handle(Bisector_BisecAna) bisec = new Bisector_BisecAna();
        bisec->Perform(curve1->curve, curve2->curve,
                       gp_Pnt2d(px, py), gp_Vec2d(v1x, v1y), gp_Vec2d(v2x, v2y),
                       sense, GeomAbs_Arc, tolerance);
        Handle(Geom2d_Curve) result = bisec->Geom2dCurve();
        if (result.IsNull()) return nullptr;
        auto* ref = new OCCTCurve2D();
        ref->curve = result;
        return ref;
    } catch (...) { return nullptr; }
}

OCCTCurve2DRef _Nullable OCCTBisectorBisecAnaCurvePoint(
    OCCTCurve2DRef curve,
    double ptx, double pty,
    double px, double py,
    double v1x, double v1y, double v2x, double v2y,
    double sense, double tolerance) {
    try {
        Handle(Geom2d_Point) geomPt = new Geom2d_CartesianPoint(gp_Pnt2d(ptx, pty));
        Handle(Bisector_BisecAna) bisec = new Bisector_BisecAna();
        bisec->Perform(curve->curve, geomPt,
                       gp_Pnt2d(px, py), gp_Vec2d(v1x, v1y), gp_Vec2d(v2x, v2y),
                       sense, tolerance);
        Handle(Geom2d_Curve) result = bisec->Geom2dCurve();
        if (result.IsNull()) return nullptr;
        auto* ref = new OCCTCurve2D();
        ref->curve = result;
        return ref;
    } catch (...) { return nullptr; }
}

OCCTCurve2DRef _Nullable OCCTBisectorBisecAnaPointPoint(
    double pt1x, double pt1y,
    double pt2x, double pt2y,
    double px, double py,
    double v1x, double v1y, double v2x, double v2y,
    double sense, double tolerance) {
    try {
        Handle(Geom2d_Point) p1 = new Geom2d_CartesianPoint(gp_Pnt2d(pt1x, pt1y));
        Handle(Geom2d_Point) p2 = new Geom2d_CartesianPoint(gp_Pnt2d(pt2x, pt2y));
        Handle(Bisector_BisecAna) bisec = new Bisector_BisecAna();
        bisec->Perform(p1, p2,
                       gp_Pnt2d(px, py), gp_Vec2d(v1x, v1y), gp_Vec2d(v2x, v2y),
                       sense, tolerance);
        Handle(Geom2d_Curve) result = bisec->Geom2dCurve();
        if (result.IsNull()) return nullptr;
        auto* ref = new OCCTCurve2D();
        ref->curve = result;
        return ref;
    } catch (...) { return nullptr; }
}

// MARK: - BRepAdaptor_Curve2d Edge PCurves (v0.61)
// MARK: - BRepAdaptor_Curve2d (v0.61.0)

bool OCCTEdgePCurveParams(OCCTShapeRef edge, OCCTShapeRef face,
    double* outFirst, double* outLast) {
    if (!edge || !face || !outFirst || !outLast) return false;
    try {
        if (edge->shape.ShapeType() != TopAbs_EDGE) return false;
        if (face->shape.ShapeType() != TopAbs_FACE) return false;
        TopoDS_Edge e = TopoDS::Edge(edge->shape);
        TopoDS_Face f = TopoDS::Face(face->shape);
        BRepAdaptor_Curve2d adaptor(e, f);
        *outFirst = adaptor.FirstParameter();
        *outLast = adaptor.LastParameter();
        return true;
    } catch (...) { return false; }
}

bool OCCTEdgePCurveValue(OCCTShapeRef edge, OCCTShapeRef face, double t,
    double* outU, double* outV) {
    if (!edge || !face || !outU || !outV) return false;
    try {
        if (edge->shape.ShapeType() != TopAbs_EDGE) return false;
        if (face->shape.ShapeType() != TopAbs_FACE) return false;
        TopoDS_Edge e = TopoDS::Edge(edge->shape);
        TopoDS_Face f = TopoDS::Face(face->shape);
        BRepAdaptor_Curve2d adaptor(e, f);
        gp_Pnt2d pt = adaptor.Value(t);
        *outU = pt.X();
        *outV = pt.Y();
        return true;
    } catch (...) { return false; }
}

// MARK: - BRepBuilderAPI_MakeEdge2d (v0.62)
// --- BRepBuilderAPI_MakeEdge2d ---

OCCTShapeRef _Nullable OCCTMakeEdge2dFromPoints(double x1, double y1, double x2, double y2) {
    try {
        BRepBuilderAPI_MakeEdge2d me(gp_Pnt2d(x1, y1), gp_Pnt2d(x2, y2));
        if (!me.IsDone()) return nullptr;
        return new OCCTShape(me.Edge());
    } catch (...) { return nullptr; }
}

OCCTShapeRef _Nullable OCCTMakeEdge2dFromCircle(
    double cx, double cy, double dx, double dy,
    double radius, double p1, double p2) {
    try {
        gp_Circ2d circ(gp_Ax2d(gp_Pnt2d(cx, cy), gp_Dir2d(dx, dy)), radius);
        BRepBuilderAPI_MakeEdge2d me(circ, p1, p2);
        if (!me.IsDone()) return nullptr;
        return new OCCTShape(me.Edge());
    } catch (...) { return nullptr; }
}

OCCTShapeRef _Nullable OCCTMakeEdge2dFromLine(
    double ox, double oy, double dx, double dy,
    double p1, double p2) {
    try {
        Handle(Geom2d_Line) line = new Geom2d_Line(gp_Pnt2d(ox, oy), gp_Dir2d(dx, dy));
        BRepBuilderAPI_MakeEdge2d me(line, p1, p2);
        if (!me.IsDone()) return nullptr;
        return new OCCTShape(me.Edge());
    } catch (...) { return nullptr; }
}

// MARK: - Geom2d Point2D (v0.64)
// --- Point2D (Geom2d_CartesianPoint) ---

struct OCCTPoint2D {
    Handle(Geom2d_CartesianPoint) point;
    OCCTPoint2D(const Handle(Geom2d_CartesianPoint)& p) : point(p) {}
};

OCCTPoint2DRef _Nullable OCCTPoint2DCreate(double x, double y) {
    try {
        return new OCCTPoint2D(new Geom2d_CartesianPoint(x, y));
    } catch (...) { return nullptr; }
}

void OCCTPoint2DRelease(OCCTPoint2DRef _Nonnull ref) { delete ref; }

double OCCTPoint2DGetX(OCCTPoint2DRef _Nonnull ref) { return ref->point->X(); }
double OCCTPoint2DGetY(OCCTPoint2DRef _Nonnull ref) { return ref->point->Y(); }

void OCCTPoint2DSetCoords(OCCTPoint2DRef _Nonnull ref, double x, double y) {
    ref->point->SetCoord(x, y);
}

double OCCTPoint2DDistance(OCCTPoint2DRef _Nonnull ref, OCCTPoint2DRef _Nonnull other) {
    return ref->point->Distance(other->point);
}

double OCCTPoint2DSquareDistance(OCCTPoint2DRef _Nonnull ref, OCCTPoint2DRef _Nonnull other) {
    return ref->point->SquareDistance(other->point);
}

OCCTPoint2DRef _Nullable OCCTPoint2DTranslated(OCCTPoint2DRef _Nonnull ref, double dx, double dy) {
    try {
        gp_Trsf2d trsf;
        trsf.SetTranslation(gp_Vec2d(dx, dy));
        Handle(Geom2d_Geometry) g = ref->point->Transformed(trsf);
        Handle(Geom2d_CartesianPoint) p = Handle(Geom2d_CartesianPoint)::DownCast(g);
        if (p.IsNull()) return nullptr;
        return new OCCTPoint2D(p);
    } catch (...) { return nullptr; }
}

OCCTPoint2DRef _Nullable OCCTPoint2DRotated(OCCTPoint2DRef _Nonnull ref,
    double cx, double cy, double angle) {
    try {
        gp_Trsf2d trsf;
        trsf.SetRotation(gp_Pnt2d(cx, cy), angle);
        Handle(Geom2d_Geometry) g = ref->point->Transformed(trsf);
        Handle(Geom2d_CartesianPoint) p = Handle(Geom2d_CartesianPoint)::DownCast(g);
        if (p.IsNull()) return nullptr;
        return new OCCTPoint2D(p);
    } catch (...) { return nullptr; }
}

OCCTPoint2DRef _Nullable OCCTPoint2DScaled(OCCTPoint2DRef _Nonnull ref,
    double cx, double cy, double factor) {
    try {
        gp_Trsf2d trsf;
        trsf.SetScale(gp_Pnt2d(cx, cy), factor);
        Handle(Geom2d_Geometry) g = ref->point->Transformed(trsf);
        Handle(Geom2d_CartesianPoint) p = Handle(Geom2d_CartesianPoint)::DownCast(g);
        if (p.IsNull()) return nullptr;
        return new OCCTPoint2D(p);
    } catch (...) { return nullptr; }
}

OCCTPoint2DRef _Nullable OCCTPoint2DMirroredPoint(OCCTPoint2DRef _Nonnull ref,
    double px, double py) {
    try {
        gp_Trsf2d trsf;
        trsf.SetMirror(gp_Pnt2d(px, py));
        Handle(Geom2d_Geometry) g = ref->point->Transformed(trsf);
        Handle(Geom2d_CartesianPoint) p = Handle(Geom2d_CartesianPoint)::DownCast(g);
        if (p.IsNull()) return nullptr;
        return new OCCTPoint2D(p);
    } catch (...) { return nullptr; }
}

OCCTPoint2DRef _Nullable OCCTPoint2DMirroredAxis(OCCTPoint2DRef _Nonnull ref,
    double ox, double oy, double dx, double dy) {
    try {
        gp_Trsf2d trsf;
        trsf.SetMirror(gp_Ax2d(gp_Pnt2d(ox, oy), gp_Dir2d(dx, dy)));
        Handle(Geom2d_Geometry) g = ref->point->Transformed(trsf);
        Handle(Geom2d_CartesianPoint) p = Handle(Geom2d_CartesianPoint)::DownCast(g);
        if (p.IsNull()) return nullptr;
        return new OCCTPoint2D(p);
    } catch (...) { return nullptr; }
}

double OCCTPoint2DDistanceToCurve(OCCTPoint2DRef _Nonnull ref, OCCTCurve2DRef _Nonnull curve) {
    try {
        Geom2dAPI_ProjectPointOnCurve proj(ref->point->Pnt2d(), curve->curve);
        if (proj.NbPoints() == 0) return -1.0;
        return proj.LowerDistance();
    } catch (...) { return -1.0; }
}

OCCTPoint2DRef _Nullable OCCTPoint2DTransformed(OCCTPoint2DRef _Nonnull ref,
    OCCTTransform2DRef _Nonnull trsf);

// MARK: - Geom2d Transform2D (v0.64)
// --- Transform2D (Geom2d_Transformation) ---

struct OCCTTransform2D {
    Handle(Geom2d_Transformation) transform;
    OCCTTransform2D(const Handle(Geom2d_Transformation)& t) : transform(t) {}
};

OCCTTransform2DRef _Nullable OCCTTransform2DCreateIdentity(void) {
    try {
        return new OCCTTransform2D(new Geom2d_Transformation());
    } catch (...) { return nullptr; }
}

void OCCTTransform2DRelease(OCCTTransform2DRef _Nonnull ref) { delete ref; }

OCCTTransform2DRef _Nullable OCCTTransform2DCreateTranslation(double dx, double dy) {
    try {
        gp_Trsf2d trsf;
        trsf.SetTranslation(gp_Vec2d(dx, dy));
        return new OCCTTransform2D(new Geom2d_Transformation(trsf));
    } catch (...) { return nullptr; }
}

OCCTTransform2DRef _Nullable OCCTTransform2DCreateRotation(double cx, double cy, double angle) {
    try {
        gp_Trsf2d trsf;
        trsf.SetRotation(gp_Pnt2d(cx, cy), angle);
        return new OCCTTransform2D(new Geom2d_Transformation(trsf));
    } catch (...) { return nullptr; }
}

OCCTTransform2DRef _Nullable OCCTTransform2DCreateScale(double cx, double cy, double factor) {
    try {
        gp_Trsf2d trsf;
        trsf.SetScale(gp_Pnt2d(cx, cy), factor);
        return new OCCTTransform2D(new Geom2d_Transformation(trsf));
    } catch (...) { return nullptr; }
}

OCCTTransform2DRef _Nullable OCCTTransform2DCreateMirrorPoint(double px, double py) {
    try {
        gp_Trsf2d trsf;
        trsf.SetMirror(gp_Pnt2d(px, py));
        return new OCCTTransform2D(new Geom2d_Transformation(trsf));
    } catch (...) { return nullptr; }
}

OCCTTransform2DRef _Nullable OCCTTransform2DCreateMirrorAxis(double ox, double oy,
    double dx, double dy) {
    try {
        gp_Trsf2d trsf;
        trsf.SetMirror(gp_Ax2d(gp_Pnt2d(ox, oy), gp_Dir2d(dx, dy)));
        return new OCCTTransform2D(new Geom2d_Transformation(trsf));
    } catch (...) { return nullptr; }
}

OCCTTransform2DRef _Nullable OCCTTransform2DInverted(OCCTTransform2DRef _Nonnull ref) {
    try {
        Handle(Geom2d_Transformation) inv =
            Handle(Geom2d_Transformation)::DownCast(ref->transform->Inverted());
        if (inv.IsNull()) return nullptr;
        return new OCCTTransform2D(inv);
    } catch (...) { return nullptr; }
}

OCCTTransform2DRef _Nullable OCCTTransform2DComposed(OCCTTransform2DRef _Nonnull ref,
    OCCTTransform2DRef _Nonnull other) {
    try {
        Handle(Geom2d_Transformation) composed =
            Handle(Geom2d_Transformation)::DownCast(ref->transform->Multiplied(other->transform));
        if (composed.IsNull()) return nullptr;
        return new OCCTTransform2D(composed);
    } catch (...) { return nullptr; }
}

OCCTTransform2DRef _Nullable OCCTTransform2DPowered(OCCTTransform2DRef _Nonnull ref, int32_t n) {
    try {
        Handle(Geom2d_Transformation) powered =
            Handle(Geom2d_Transformation)::DownCast(ref->transform->Powered(n));
        if (powered.IsNull()) return nullptr;
        return new OCCTTransform2D(powered);
    } catch (...) { return nullptr; }
}

void OCCTTransform2DApply(OCCTTransform2DRef _Nonnull ref, double* _Nonnull x, double* _Nonnull y) {
    try {
        ref->transform->Trsf2d().Transforms(*x, *y);
    } catch (...) {}
}

double OCCTTransform2DScaleFactor(OCCTTransform2DRef _Nonnull ref) {
    return ref->transform->ScaleFactor();
}

bool OCCTTransform2DIsNegative(OCCTTransform2DRef _Nonnull ref) {
    return ref->transform->IsNegative();
}

void OCCTTransform2DGetValues(OCCTTransform2DRef _Nonnull ref,
    double* _Nonnull a11, double* _Nonnull a12, double* _Nonnull a13,
    double* _Nonnull a21, double* _Nonnull a22, double* _Nonnull a23) {
    try {
        *a11 = ref->transform->Value(1, 1);
        *a12 = ref->transform->Value(1, 2);
        *a13 = ref->transform->Value(1, 3);
        *a21 = ref->transform->Value(2, 1);
        *a22 = ref->transform->Value(2, 2);
        *a23 = ref->transform->Value(2, 3);
    } catch (...) {}
}

OCCTCurve2DRef _Nullable OCCTTransform2DApplyToCurve(OCCTTransform2DRef _Nonnull ref,
    OCCTCurve2DRef _Nonnull curve) {
    try {
        Handle(Geom2d_Curve) copy = Handle(Geom2d_Curve)::DownCast(curve->curve->Copy());
        if (copy.IsNull()) return nullptr;
        copy->Transform(ref->transform->Trsf2d());
        return new OCCTCurve2D(copy);
    } catch (...) { return nullptr; }
}

// Now implement the forward-declared Point2D + Transform2D function
OCCTPoint2DRef _Nullable OCCTPoint2DTransformed(OCCTPoint2DRef _Nonnull ref,
    OCCTTransform2DRef _Nonnull trsf) {
    try {
        Handle(Geom2d_Geometry) g = ref->point->Transformed(trsf->transform->Trsf2d());
        Handle(Geom2d_CartesianPoint) p = Handle(Geom2d_CartesianPoint)::DownCast(g);
        if (p.IsNull()) return nullptr;
        return new OCCTPoint2D(p);
    } catch (...) { return nullptr; }
}

// MARK: - Geom2d AxisPlacement2D (v0.64)
// --- AxisPlacement2D (Geom2d_AxisPlacement) ---

struct OCCTAxisPlacement2D {
    Handle(Geom2d_AxisPlacement) axis;
    OCCTAxisPlacement2D(const Handle(Geom2d_AxisPlacement)& a) : axis(a) {}
};

OCCTAxisPlacement2DRef _Nullable OCCTAxisPlacement2DCreate(double ox, double oy,
    double dx, double dy) {
    try {
        return new OCCTAxisPlacement2D(
            new Geom2d_AxisPlacement(gp_Pnt2d(ox, oy), gp_Dir2d(dx, dy)));
    } catch (...) { return nullptr; }
}

void OCCTAxisPlacement2DRelease(OCCTAxisPlacement2DRef _Nonnull ref) { delete ref; }

void OCCTAxisPlacement2DGetOrigin(OCCTAxisPlacement2DRef _Nonnull ref,
    double* _Nonnull x, double* _Nonnull y) {
    gp_Pnt2d loc = ref->axis->Location();
    *x = loc.X();
    *y = loc.Y();
}

void OCCTAxisPlacement2DGetDirection(OCCTAxisPlacement2DRef _Nonnull ref,
    double* _Nonnull x, double* _Nonnull y) {
    gp_Dir2d dir = ref->axis->Direction();
    *x = dir.X();
    *y = dir.Y();
}

OCCTAxisPlacement2DRef _Nullable OCCTAxisPlacement2DReversed(OCCTAxisPlacement2DRef _Nonnull ref) {
    try {
        Handle(Geom2d_AxisPlacement) copy =
            Handle(Geom2d_AxisPlacement)::DownCast(ref->axis->Copy());
        if (copy.IsNull()) return nullptr;
        copy->Reverse();
        return new OCCTAxisPlacement2D(copy);
    } catch (...) { return nullptr; }
}

double OCCTAxisPlacement2DAngle(OCCTAxisPlacement2DRef _Nonnull ref,
    OCCTAxisPlacement2DRef _Nonnull other) {
    return ref->axis->Angle(other->axis);
}

// MARK: - Vector2D / Direction2D Utilities (v0.64)
// --- Vector2D utilities ---

double OCCTVector2DAngle(double ax, double ay, double bx, double by) {
    try {
        gp_Vec2d a(ax, ay), b(bx, by);
        return a.Angle(b);
    } catch (...) { return 0.0; }
}

double OCCTVector2DCross(double ax, double ay, double bx, double by) {
    return ax * by - ay * bx;
}

double OCCTVector2DDot(double ax, double ay, double bx, double by) {
    return ax * bx + ay * by;
}

double OCCTVector2DMagnitude(double x, double y) {
    return sqrt(x * x + y * y);
}

void OCCTVector2DNormalize(double* _Nonnull x, double* _Nonnull y) {
    double mag = sqrt((*x) * (*x) + (*y) * (*y));
    if (mag > 1e-15) { *x /= mag; *y /= mag; }
}

// --- Direction2D utilities ---

void OCCTDirection2DNormalize(double* _Nonnull x, double* _Nonnull y) {
    try {
        gp_Dir2d d(*x, *y);
        *x = d.X();
        *y = d.Y();
    } catch (...) {}
}

double OCCTDirection2DAngle(double ax, double ay, double bx, double by) {
    try {
        gp_Dir2d a(ax, ay), b(bx, by);
        return a.Angle(b);
    } catch (...) { return 0.0; }
}

double OCCTDirection2DCross(double ax, double ay, double bx, double by) {
    try {
        gp_Dir2d a(ax, ay), b(bx, by);
        return a.Crossed(b);
    } catch (...) { return 0.0; }
}


// MARK: - LProp_AnalyticCurInf (v0.64)

int32_t OCCTLPropAnalyticCurInf(int32_t curveType, double first, double last,
    double* _Nonnull outParams, int32_t* _Nonnull outTypes, int32_t maxResults) {
    try {
        // Inline implementation matching OCCT LProp_AnalyticCurInf::Perform.
        // Only ellipses have curvature extrema among analytic curves.
        // Line: zero curvature, Circle: constant curvature, Parabola/Hyperbola: monotonic curvature.
        LProp_CurAndInf result;
        GeomAbs_CurveType ct = (GeomAbs_CurveType)curveType;
        if (ct == GeomAbs_Ellipse) {
            // Ellipse curvature extrema at multiples of PI/2
            // At 0, PI: max curvature (min radius vertex on minor axis)
            // At PI/2, 3PI/2: min curvature (max radius vertex on major axis)
            double PI2 = M_PI / 2.0;
            for (int k = 0; k < 4; k++) {
                double param = k * PI2;
                if (param >= first && param <= last) {
                    bool isMin = (k == 1 || k == 3);
                    result.AddExtCur(param, isMin);
                }
            }
        }
        // All other analytic curve types: no curvature extrema to report.
        int32_t count = std::min((int32_t)result.NbPoints(), maxResults);
        for (int32_t i = 0; i < count; i++) {
            outParams[i] = result.Parameter(i + 1);
            LProp_CIType t = result.Type(i + 1);
            switch (t) {
                case LProp_Inflection: outTypes[i] = 0; break;
                case LProp_MinCur: outTypes[i] = 1; break;
                case LProp_MaxCur: outTypes[i] = 2; break;
            }
        }
        return count;
    } catch (...) { return 0; }
}

// MARK: - Curve2D ↔ Point2D Integration (v0.64)
// --- Curve2D ↔ Point2D integration ---

OCCTPoint2DRef _Nullable OCCTCurve2DPointAt(OCCTCurve2DRef _Nonnull curve, double t) {
    try {
        gp_Pnt2d pt;
        curve->curve->D0(t, pt);
        return new OCCTPoint2D(new Geom2d_CartesianPoint(pt));
    } catch (...) { return nullptr; }
}

OCCTCurve2DRef _Nullable OCCTCurve2DSegmentFromPoints(OCCTPoint2DRef _Nonnull p1,
    OCCTPoint2DRef _Nonnull p2) {
    try {
        Handle(Geom2d_Line) line = new Geom2d_Line(p1->point->Pnt2d(),
            gp_Dir2d(p2->point->X() - p1->point->X(), p2->point->Y() - p1->point->Y()));
        double dist = p1->point->Pnt2d().Distance(p2->point->Pnt2d());
        Handle(Geom2d_TrimmedCurve) seg = new Geom2d_TrimmedCurve(line, 0.0, dist);
        return new OCCTCurve2D(seg);
    } catch (...) { return nullptr; }
}

double OCCTCurve2DProjectPoint2D(OCCTCurve2DRef _Nonnull curve, OCCTPoint2DRef _Nonnull point,
    double* _Nonnull outDistance) {
    try {
        Geom2dAPI_ProjectPointOnCurve proj(point->point->Pnt2d(), curve->curve);
        if (proj.NbPoints() == 0) { *outDistance = -1.0; return 0.0; }
        *outDistance = proj.LowerDistance();
        return proj.LowerDistanceParameter();
    } catch (...) { *outDistance = -1.0; return 0.0; }
}

// MARK: - FairCurve Batten / MinimalVariation (v0.67)
// --- FairCurve_Batten ---

OCCTCurve2DRef _Nullable OCCTFairCurveBatten(double p1x, double p1y, double p2x, double p2y,
    double height, double slope, double angle1, double angle2,
    int32_t constraintOrder1, int32_t constraintOrder2, bool freeSliding,
    int32_t* _Nonnull outCode) {
    try {
        gp_Pnt2d P1(p1x, p1y);
        gp_Pnt2d P2(p2x, p2y);
        FairCurve_Batten batten(P1, P2, height, slope);
        batten.SetAngle1(angle1);
        batten.SetAngle2(angle2);
        batten.SetConstraintOrder1(constraintOrder1);
        batten.SetConstraintOrder2(constraintOrder2);
        batten.SetFreeSliding(freeSliding);

        FairCurve_AnalysisCode code;
        bool ok = batten.Compute(code, 50, 1.0e-3);
        *outCode = (int32_t)code;
        if (!ok) return nullptr;

        Handle(Geom2d_BSplineCurve) bspline = batten.Curve();
        if (bspline.IsNull()) return nullptr;

        // Convert to Geom2d_Curve handle
        Handle(Geom2d_Curve) curve = bspline;
        auto ref = new OCCTCurve2D();
        ref->curve = curve;
        return ref;
    } catch (...) { *outCode = -1; return nullptr; }
}

// --- FairCurve_MinimalVariation ---

OCCTCurve2DRef _Nullable OCCTFairCurveMinimalVariation(double p1x, double p1y, double p2x, double p2y,
    double height, double slope, double angle1, double angle2,
    int32_t constraintOrder1, int32_t constraintOrder2, bool freeSliding,
    double physicalRatio, double curvature1, double curvature2,
    int32_t* _Nonnull outCode) {
    try {
        gp_Pnt2d P1(p1x, p1y);
        gp_Pnt2d P2(p2x, p2y);
        FairCurve_MinimalVariation mv(P1, P2, height, slope, physicalRatio);
        mv.SetAngle1(angle1);
        mv.SetAngle2(angle2);
        mv.SetConstraintOrder1(constraintOrder1);
        mv.SetConstraintOrder2(constraintOrder2);
        mv.SetFreeSliding(freeSliding);
        if (constraintOrder1 >= 2) mv.SetCurvature1(curvature1);
        if (constraintOrder2 >= 2) mv.SetCurvature2(curvature2);

        FairCurve_AnalysisCode code;
        bool ok = mv.Compute(code, 50, 1.0e-3);
        *outCode = (int32_t)code;
        if (!ok) return nullptr;

        Handle(Geom2d_BSplineCurve) bspline = mv.Curve();
        if (bspline.IsNull()) return nullptr;

        Handle(Geom2d_Curve) curve = bspline;
        auto ref = new OCCTCurve2D();
        ref->curve = curve;
        return ref;
    } catch (...) { *outCode = -1; return nullptr; }
}
