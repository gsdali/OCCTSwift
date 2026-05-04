//
//  OCCTBridge_MAT2d_TNaming.mm
//  OCCTSwift
//
//  Extracted from OCCTBridge.mm — issue #99.
//
//  Two unrelated v0.24 / v0.25 areas bundled together because each is
//  small and self-contained:
//
//  - BRepMAT2d (v0.24): 2D medial axis transform — extract bisecting
//    loci of polygon faces (BRepMAT2d_Explorer + BRepMAT2d_BisectingLocus
//    + BRepMAT2d_LinkTopoBilo, MAT_Graph traversal)
//  - TNaming (v0.25): topological naming history — track how shapes
//    evolve through modeling operations (TNaming_Builder / NamedShape /
//    Selector / Iterator)
//
//  Public C surface unchanged. No symbol changes — pure file move.
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

// === Area-specific OCCT headers ===

#include <BRepMAT2d_BisectingLocus.hxx>
#include <BRepMAT2d_Explorer.hxx>
#include <BRepMAT2d_LinkTopoBilo.hxx>

#include <Bisector_Bisec.hxx>
#include <MAT_Arc.hxx>
#include <MAT_BasicElt.hxx>
#include <MAT_Graph.hxx>
#include <MAT_Node.hxx>
#include <MAT_Side.hxx>

#include <Geom2d_Curve.hxx>
#include <Geom2d_TrimmedCurve.hxx>
#include <Geom2dAPI_ProjectPointOnCurve.hxx>

#include <TNaming_Builder.hxx>
#include <TNaming_Iterator.hxx>
#include <TNaming_NamedShape.hxx>
#include <TNaming_NewShapeIterator.hxx>
#include <TNaming_OldShapeIterator.hxx>
#include <TNaming_Selector.hxx>
#include <TNaming_Tool.hxx>
#include <TDF_Data.hxx>
#include <TDF_Label.hxx>
#include <TDF_LabelMap.hxx>

#include <gp_Pnt2d.hxx>

#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>

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


// MARK: - TNaming: Topological Naming History (v0.25.0)

#include <TNaming_Builder.hxx>
#include <TNaming_NamedShape.hxx>
#include <TNaming_Selector.hxx>
#include <TNaming_Iterator.hxx>
#include <TNaming_NewShapeIterator.hxx>
#include <TNaming_OldShapeIterator.hxx>
#include <TNaming_Tool.hxx>
#include <TDF_Label.hxx>
#include <TDF_LabelMap.hxx>
#include <TDF_Data.hxx>

int64_t OCCTDocumentCreateLabel(OCCTDocumentRef doc, int64_t parentLabelId) {
    if (!doc || doc->doc.IsNull()) return -1;
    try {
        TDF_Label parentLabel;
        if (parentLabelId < 0) {
            // Create under document root
            parentLabel = doc->doc->Main();
        } else {
            parentLabel = doc->getLabel(parentLabelId);
            if (parentLabel.IsNull()) return -1;
        }
        TDF_Label newLabel = parentLabel.NewChild();
        return doc->registerLabel(newLabel);
    } catch (...) {
        return -1;
    }
}

bool OCCTDocumentNamingRecord(OCCTDocumentRef doc, int64_t labelId,
                               OCCTNamingEvolution evolution,
                               OCCTShapeRef oldShape, OCCTShapeRef newShape) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;

        TNaming_Builder builder(label);
        switch (evolution) {
            case OCCTNamingPrimitive:
                if (!newShape) return false;
                builder.Generated(newShape->shape);
                break;
            case OCCTNamingGenerated:
                if (!oldShape || !newShape) return false;
                builder.Generated(oldShape->shape, newShape->shape);
                break;
            case OCCTNamingModify:
                if (!oldShape || !newShape) return false;
                builder.Modify(oldShape->shape, newShape->shape);
                break;
            case OCCTNamingDelete:
                if (!oldShape) return false;
                builder.Delete(oldShape->shape);
                break;
            case OCCTNamingSelected:
                if (!oldShape || !newShape) return false;
                builder.Select(newShape->shape, oldShape->shape);
                break;
            default:
                return false;
        }
        return true;
    } catch (...) {
        return false;
    }
}

OCCTShapeRef OCCTDocumentNamingGetCurrentShape(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return nullptr;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return nullptr;

        Handle(TNaming_NamedShape) ns;
        if (!label.FindAttribute(TNaming_NamedShape::GetID(), ns)) return nullptr;
        if (ns.IsNull() || ns->IsEmpty()) return nullptr;

        TopoDS_Shape current = TNaming_Tool::CurrentShape(ns);
        if (current.IsNull()) return nullptr;

        return new OCCTShape(current);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTDocumentNamingGetShape(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return nullptr;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return nullptr;

        Handle(TNaming_NamedShape) ns;
        if (!label.FindAttribute(TNaming_NamedShape::GetID(), ns)) return nullptr;
        if (ns.IsNull() || ns->IsEmpty()) return nullptr;

        TopoDS_Shape shape = TNaming_Tool::GetShape(ns);
        if (shape.IsNull()) return nullptr;

        return new OCCTShape(shape);
    } catch (...) {
        return nullptr;
    }
}

int32_t OCCTDocumentNamingHistoryCount(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return 0;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return 0;

        Handle(TNaming_NamedShape) ns;
        if (!label.FindAttribute(TNaming_NamedShape::GetID(), ns)) return 0;

        int32_t count = 0;
        for (TNaming_Iterator it(ns); it.More(); it.Next()) {
            count++;
        }
        return count;
    } catch (...) {
        return 0;
    }
}

bool OCCTDocumentNamingGetHistoryEntry(OCCTDocumentRef doc, int64_t labelId,
                                        int32_t index, OCCTNamingHistoryEntry* outEntry) {
    if (!doc || !outEntry || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;

        Handle(TNaming_NamedShape) ns;
        if (!label.FindAttribute(TNaming_NamedShape::GetID(), ns)) return false;

        int32_t i = 0;
        for (TNaming_Iterator it(ns); it.More(); it.Next(), i++) {
            if (i == index) {
                TNaming_Evolution evo = it.Evolution();
                outEntry->hasOldShape = !it.OldShape().IsNull();
                outEntry->hasNewShape = !it.NewShape().IsNull();
                outEntry->isModification = it.IsModification();
                switch (evo) {
                    case TNaming_PRIMITIVE: outEntry->evolution = OCCTNamingPrimitive; break;
                    case TNaming_GENERATED: outEntry->evolution = OCCTNamingGenerated; break;
                    case TNaming_MODIFY: outEntry->evolution = OCCTNamingModify; break;
                    case TNaming_DELETE: outEntry->evolution = OCCTNamingDelete; break;
                    case TNaming_SELECTED: outEntry->evolution = OCCTNamingSelected; break;
                    default: outEntry->evolution = OCCTNamingPrimitive; break;
                }
                return true;
            }
        }
        return false;
    } catch (...) {
        return false;
    }
}

OCCTShapeRef OCCTDocumentNamingGetOldShape(OCCTDocumentRef doc, int64_t labelId, int32_t index) {
    if (!doc || doc->doc.IsNull()) return nullptr;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return nullptr;

        Handle(TNaming_NamedShape) ns;
        if (!label.FindAttribute(TNaming_NamedShape::GetID(), ns)) return nullptr;

        int32_t i = 0;
        for (TNaming_Iterator it(ns); it.More(); it.Next(), i++) {
            if (i == index) {
                TopoDS_Shape old = it.OldShape();
                if (old.IsNull()) return nullptr;
                return new OCCTShape(old);
            }
        }
        return nullptr;
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTDocumentNamingGetNewShape(OCCTDocumentRef doc, int64_t labelId, int32_t index) {
    if (!doc || doc->doc.IsNull()) return nullptr;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return nullptr;

        Handle(TNaming_NamedShape) ns;
        if (!label.FindAttribute(TNaming_NamedShape::GetID(), ns)) return nullptr;

        int32_t i = 0;
        for (TNaming_Iterator it(ns); it.More(); it.Next(), i++) {
            if (i == index) {
                TopoDS_Shape nw = it.NewShape();
                if (nw.IsNull()) return nullptr;
                return new OCCTShape(nw);
            }
        }
        return nullptr;
    } catch (...) {
        return nullptr;
    }
}

int32_t OCCTDocumentNamingTraceForward(OCCTDocumentRef doc, int64_t accessLabelId,
                                        OCCTShapeRef shape,
                                        OCCTShapeRef* outShapes, int32_t maxCount) {
    if (!doc || !shape || !outShapes || doc->doc.IsNull()) return 0;
    try {
        TDF_Label access = doc->getLabel(accessLabelId);
        if (access.IsNull()) return 0;

        int32_t count = 0;
        for (TNaming_NewShapeIterator it(shape->shape, access);
             it.More() && count < maxCount; it.Next()) {
            TopoDS_Shape s = it.Shape();
            if (!s.IsNull()) {
                outShapes[count] = new OCCTShape(s);
                count++;
            }
        }
        return count;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTDocumentNamingTraceBackward(OCCTDocumentRef doc, int64_t accessLabelId,
                                         OCCTShapeRef shape,
                                         OCCTShapeRef* outShapes, int32_t maxCount) {
    if (!doc || !shape || !outShapes || doc->doc.IsNull()) return 0;
    try {
        TDF_Label access = doc->getLabel(accessLabelId);
        if (access.IsNull()) return 0;

        int32_t count = 0;
        for (TNaming_OldShapeIterator it(shape->shape, access);
             it.More() && count < maxCount; it.Next()) {
            TopoDS_Shape s = it.Shape();
            if (!s.IsNull()) {
                outShapes[count] = new OCCTShape(s);
                count++;
            }
        }
        return count;
    } catch (...) {
        return 0;
    }
}

bool OCCTDocumentNamingSelect(OCCTDocumentRef doc, int64_t labelId,
                               OCCTShapeRef selection, OCCTShapeRef context) {
    if (!doc || !selection || !context || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;

        TNaming_Selector selector(label);
        return selector.Select(selection->shape, context->shape);
    } catch (...) {
        return false;
    }
}

OCCTShapeRef OCCTDocumentNamingResolve(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return nullptr;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return nullptr;

        TNaming_Selector selector(label);
        TDF_LabelMap valid;
        if (!selector.Solve(valid)) return nullptr;

        Handle(TNaming_NamedShape) ns = selector.NamedShape();
        if (ns.IsNull() || ns->IsEmpty()) return nullptr;

        TopoDS_Shape shape = TNaming_Tool::CurrentShape(ns);
        if (shape.IsNull()) return nullptr;

        return new OCCTShape(shape);
    } catch (...) {
        return nullptr;
    }
}

int32_t OCCTDocumentNamingGetEvolution(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return -1;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return -1;

        Handle(TNaming_NamedShape) ns;
        if (!label.FindAttribute(TNaming_NamedShape::GetID(), ns)) return -1;

        switch (ns->Evolution()) {
            case TNaming_PRIMITIVE: return OCCTNamingPrimitive;
            case TNaming_GENERATED: return OCCTNamingGenerated;
            case TNaming_MODIFY: return OCCTNamingModify;
            case TNaming_DELETE: return OCCTNamingDelete;
            case TNaming_SELECTED: return OCCTNamingSelected;
            default: return -1;
        }
    } catch (...) {
        return -1;
    }
}


// ============================================================
