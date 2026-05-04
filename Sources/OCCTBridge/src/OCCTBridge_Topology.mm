//
//  OCCTBridge_Topology.mm
//  OCCTSwift
//
//  Per-OCCT-module TU for topology traversal + classification:
//
//  - TopExp_*, TopTools_*, TopoDS_*, TopAbs_*
//  - BRepTools_WireExplorer (ordered wire-edge iteration)
//  - BRepTools_ReShape (sub-shape replacement / removal)
//  - BRepClass / BRepClass3d (point-in-shape classification)
//  - BRepBndLib + Bnd_OBB (oriented bounding box)
//  - ShapeAnalysis_ShapeContents (sub-shape census)
//  - BRepLib_FindSurface (planar surface from edge group)
//  - BRepGProp helpers when not delegated to Properties
//
//  Public C surface unchanged. No symbol changes — pure file move.
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

#include <BRep_Tool.hxx>
#include <BRep_Builder.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_Copy.hxx>
#include <BRepClass_FaceClassifier.hxx>
#include <BRepClass3d_SolidClassifier.hxx>
#include <BRepGProp.hxx>
#include <BRepLib_FindSurface.hxx>
#include <BRepTools_ReShape.hxx>
#include <BRepTools_WireExplorer.hxx>

#include <Bnd_Box.hxx>
#include <Bnd_OBB.hxx>

#include <Geom_Plane.hxx>

#include <GCPnts_TangentialDeflection.hxx>
#include <GProp_GProps.hxx>

#include <ShapeAnalysis_ShapeContents.hxx>
#include <ShapeAnalysis_Wire.hxx>
#include <ShapeExtend_WireData.hxx>

#include <gp_Ax1.hxx>
#include <gp_Dir.hxx>
#include <gp_Pln.hxx>
#include <gp_Pnt.hxx>
#include <gp_XYZ.hxx>

#include <TopAbs.hxx>
#include <TopAbs_State.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>

#include <algorithm>

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

// MARK: - Shape Contents (v0.30.0)

#include <ShapeAnalysis_ShapeContents.hxx>

OCCTShapeContents OCCTShapeGetContents(OCCTShapeRef shape) {
    OCCTShapeContents result = {};
    if (!shape) return result;
    try {
        ShapeAnalysis_ShapeContents contents;
        contents.Perform(shape->shape);
        result.nbSolids = contents.NbSolids();
        result.nbShells = contents.NbShells();
        result.nbFaces = contents.NbFaces();
        result.nbWires = contents.NbWires();
        result.nbEdges = contents.NbEdges();
        result.nbVertices = contents.NbVertices();
        result.nbFreeEdges = contents.NbFreeEdges();
        result.nbFreeWires = contents.NbFreeWires();
        result.nbFreeFaces = contents.NbFreeFaces();
        return result;
    } catch (...) {
        return result;
    }
}

// MARK: - Edge Analysis (v0.30.0)

#include <ShapeAnalysis_Edge.hxx>

bool OCCTEdgeHasCurve3D(OCCTShapeRef edge) {
    if (!edge) return false;
    try {
        if (edge->shape.ShapeType() != TopAbs_EDGE) return false;
        ShapeAnalysis_Edge analyzer;
        return analyzer.HasCurve3d(TopoDS::Edge(edge->shape));
    } catch (...) {
        return false;
    }
}

bool OCCTEdgeIsClosed3D(OCCTShapeRef edge) {
    if (!edge) return false;
    try {
        if (edge->shape.ShapeType() != TopAbs_EDGE) return false;
        ShapeAnalysis_Edge analyzer;
        return analyzer.IsClosed3d(TopoDS::Edge(edge->shape));
    } catch (...) {
        return false;
    }
}

bool OCCTEdgeIsSeam(OCCTShapeRef edge, OCCTShapeRef face) {
    if (!edge || !face) return false;
    try {
        if (edge->shape.ShapeType() != TopAbs_EDGE) return false;
        if (face->shape.ShapeType() != TopAbs_FACE) return false;
        ShapeAnalysis_Edge analyzer;
        return analyzer.IsSeam(TopoDS::Edge(edge->shape), TopoDS::Face(face->shape));
    } catch (...) {
        return false;
    }
}

// MARK: - Find Surface (v0.30.0)

#include <BRepLib_FindSurface.hxx>

OCCTSurfaceRef OCCTShapeFindSurface(OCCTShapeRef shape, double tolerance) {
    if (!shape) return nullptr;
    try {
        BRepLib_FindSurface finder(shape->shape, tolerance);
        if (!finder.Found()) return nullptr;
        Handle(Geom_Surface) surf = finder.Surface();
        if (surf.IsNull()) return nullptr;
        return new OCCTSurface(surf);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Contiguous Edges (v0.30.0)

#include <BRepOffsetAPI_FindContigousEdges.hxx>

int32_t OCCTShapeFindContiguousEdges(OCCTShapeRef shape, double tolerance) {
    if (!shape) return 0;
    try {
        BRepOffsetAPI_FindContigousEdges finder(tolerance);
        finder.Add(shape->shape);
        finder.Perform();
        return finder.NbContigousEdges();
    } catch (...) {
        return 0;
    }
}

// MARK: - Point Classification (v0.17.0)

#include <BRepClass3d_SolidClassifier.hxx>
#include <BRepClass_FaceClassifier.hxx>
#include <TopAbs_State.hxx>

static int32_t mapTopAbsState(TopAbs_State state) {
    switch (state) {
        case TopAbs_IN:      return 0;
        case TopAbs_OUT:     return 1;
        case TopAbs_ON:      return 2;
        case TopAbs_UNKNOWN: return 3;
        default:             return 3;
    }
}

OCCTTopAbsState OCCTClassifyPointInSolid(OCCTShapeRef solid,
                                          double px, double py, double pz,
                                          double tolerance) {
    if (!solid) return 3; // UNKNOWN

    try {
        BRepClass3d_SolidClassifier classifier(solid->shape, gp_Pnt(px, py, pz), tolerance);
        return mapTopAbsState(classifier.State());
    } catch (...) {
        return 3; // UNKNOWN
    }
}

OCCTTopAbsState OCCTClassifyPointOnFace(OCCTFaceRef face,
                                         double px, double py, double pz,
                                         double tolerance) {
    if (!face) return 3; // UNKNOWN

    try {
        BRepClass_FaceClassifier classifier(face->face, gp_Pnt(px, py, pz), tolerance);
        return mapTopAbsState(classifier.State());
    } catch (...) {
        return 3; // UNKNOWN
    }
}

OCCTTopAbsState OCCTClassifyPointOnFaceUV(OCCTFaceRef face,
                                           double u, double v,
                                           double tolerance) {
    if (!face) return 3; // UNKNOWN

    try {
        BRepClass_FaceClassifier classifier(face->face, gp_Pnt2d(u, v), tolerance);
        return mapTopAbsState(classifier.State());
    } catch (...) {
        return 3; // UNKNOWN
    }
}


// MARK: - Wire Analysis (v0.37.0)

#include <ShapeAnalysis_Wire.hxx>
#include <ShapeExtend_WireData.hxx>

bool OCCTWireAnalyze(OCCTWireRef wire, double tolerance, OCCTWireAnalysisResult* result) {
    if (!wire || !result) return false;
    try {
        // Create a dummy planar face for wire analysis
        TopoDS_Face face;
        ShapeAnalysis_Wire analyzer;
        analyzer.Load(wire->wire);
        analyzer.SetPrecision(tolerance);

        result->edgeCount = analyzer.NbEdges();
        // CheckClosed returns true when there IS a problem, so negate it
        result->isClosed = wire->wire.Closed() || !analyzer.CheckClosed(tolerance);
        result->hasSmallEdges = analyzer.CheckSmall(tolerance);
        result->hasGaps3d = analyzer.CheckGaps3d();
        result->hasSelfIntersection = analyzer.CheckSelfIntersection();
        result->isOrdered = !analyzer.CheckOrder();
        result->minDistance3d = analyzer.MinDistance3d();
        result->maxDistance3d = analyzer.MaxDistance3d();
        return true;
    } catch (...) {
        return false;
    }
}

// MARK: - Oriented Bounding Box (v0.38.0)

#include <Bnd_OBB.hxx>
#include <BRepBndLib.hxx>

bool OCCTShapeOrientedBoundingBox(OCCTShapeRef shape, bool optimal, OCCTOrientedBoundingBox* result) {
    if (!shape || !result) return false;
    try {
        Bnd_OBB obb;
        BRepBndLib::AddOBB(shape->shape, obb, true, optimal, true);
        if (obb.IsVoid()) return false;

        gp_XYZ center = obb.Center();
        result->centerX = center.X();
        result->centerY = center.Y();
        result->centerZ = center.Z();

        gp_XYZ xDir = obb.XDirection();
        result->xDirX = xDir.X(); result->xDirY = xDir.Y(); result->xDirZ = xDir.Z();
        gp_XYZ yDir = obb.YDirection();
        result->yDirX = yDir.X(); result->yDirY = yDir.Y(); result->yDirZ = yDir.Z();
        gp_XYZ zDir = obb.ZDirection();
        result->zDirX = zDir.X(); result->zDirY = zDir.Y(); result->zDirZ = zDir.Z();

        result->halfX = obb.XHSize();
        result->halfY = obb.YHSize();
        result->halfZ = obb.ZHSize();
        return true;
    } catch (...) {
        return false;
    }
}

double OCCTOrientedBoundingBoxVolume(const OCCTOrientedBoundingBox* result) {
    if (!result) return 0.0;
    return 8.0 * result->halfX * result->halfY * result->halfZ;
}

void OCCTOrientedBoundingBoxCorners(const OCCTOrientedBoundingBox* result, double* outCorners) {
    if (!result || !outCorners) return;
    gp_XYZ center(result->centerX, result->centerY, result->centerZ);
    gp_XYZ xDir(result->xDirX, result->xDirY, result->xDirZ);
    gp_XYZ yDir(result->yDirX, result->yDirY, result->yDirZ);
    gp_XYZ zDir(result->zDirX, result->zDirY, result->zDirZ);
    gp_XYZ hx = xDir * result->halfX;
    gp_XYZ hy = yDir * result->halfY;
    gp_XYZ hz = zDir * result->halfZ;

    // 8 corners: all combinations of +/- half-sizes
    int idx = 0;
    for (int sx = -1; sx <= 1; sx += 2) {
        for (int sy = -1; sy <= 1; sy += 2) {
            for (int sz = -1; sz <= 1; sz += 2) {
                gp_XYZ corner = center;
                corner += hx * sx;
                corner += hy * sy;
                corner += hz * sz;
                outCorners[idx++] = corner.X();
                outCorners[idx++] = corner.Y();
                outCorners[idx++] = corner.Z();
            }
        }
    }
}

// MARK: - Deep Shape Copy (v0.38.0)

#include <BRepBuilderAPI_Copy.hxx>

OCCTShapeRef OCCTShapeCopy(OCCTShapeRef shape, bool copyGeom, bool copyMesh) {
    if (!shape) return nullptr;
    try {
        BRepBuilderAPI_Copy copier(shape->shape, copyGeom, copyMesh);
        if (!copier.IsDone()) return nullptr;
        TopoDS_Shape result = copier.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Sub-Shape Extraction (v0.38.0)

#include <TopExp_Explorer.hxx>

int32_t OCCTShapeGetSolidCount(OCCTShapeRef shape) {
    if (!shape) return 0;
    int32_t count = 0;
    for (TopExp_Explorer exp(shape->shape, TopAbs_SOLID); exp.More(); exp.Next()) {
        count++;
    }
    return count;
}

int32_t OCCTShapeGetSolids(OCCTShapeRef shape, OCCTShapeRef* outSolids, int32_t maxCount) {
    if (!shape || !outSolids || maxCount <= 0) return 0;
    int32_t count = 0;
    for (TopExp_Explorer exp(shape->shape, TopAbs_SOLID); exp.More() && count < maxCount; exp.Next()) {
        outSolids[count++] = new OCCTShape(exp.Current());
    }
    return count;
}

int32_t OCCTShapeGetShellCount(OCCTShapeRef shape) {
    if (!shape) return 0;
    int32_t count = 0;
    for (TopExp_Explorer exp(shape->shape, TopAbs_SHELL); exp.More(); exp.Next()) {
        count++;
    }
    return count;
}

int32_t OCCTShapeGetShells(OCCTShapeRef shape, OCCTShapeRef* outShells, int32_t maxCount) {
    if (!shape || !outShells || maxCount <= 0) return 0;
    int32_t count = 0;
    for (TopExp_Explorer exp(shape->shape, TopAbs_SHELL); exp.More() && count < maxCount; exp.Next()) {
        outShells[count++] = new OCCTShape(exp.Current());
    }
    return count;
}

int32_t OCCTShapeGetWireCount(OCCTShapeRef shape) {
    if (!shape) return 0;
    int32_t count = 0;
    for (TopExp_Explorer exp(shape->shape, TopAbs_WIRE); exp.More(); exp.Next()) {
        count++;
    }
    return count;
}

int32_t OCCTShapeGetWires(OCCTShapeRef shape, OCCTShapeRef* outWires, int32_t maxCount) {
    if (!shape || !outWires || maxCount <= 0) return 0;
    int32_t count = 0;
    for (TopExp_Explorer exp(shape->shape, TopAbs_WIRE); exp.More() && count < maxCount; exp.Next()) {
        outWires[count++] = new OCCTShape(exp.Current());
    }
    return count;
}

