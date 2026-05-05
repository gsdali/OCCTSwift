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
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepGProp.hxx>
#include <IntCurvesFace_Intersector.hxx>
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
#include <Geom_SurfaceOfRevolution.hxx>
#include <Geom_SurfaceOfLinearExtrusion.hxx>
#include <GProp_PrincipalProps.hxx>
#include <BRepExtrema_DistShapeShape.hxx>
#include <BRepExtrema_ExtCC.hxx>
#include <BRepExtrema_ExtCF.hxx>
#include <BRepExtrema_ExtFF.hxx>
#include <BRepExtrema_ExtPC.hxx>
#include <BRepExtrema_ExtPF.hxx>
#include <BRepExtrema_Poly.hxx>
#include <BRepExtrema_SelfIntersection.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepOffset_Analyse.hxx>
#include <BRepOffset_Interval.hxx>
#include <ChFiDS_TypeOfConcavity.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <gp_Cylinder.hxx>
#include <gp_Cone.hxx>
#include <gp_Sphere.hxx>
#include <gp_Torus.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_BezierSurface.hxx>
#include <Geom_BSplineCurve.hxx>
#include <GeomConvert_BSplineSurfaceToBezierSurface.hxx>
#include <GeomConvert_BSplineCurveKnotSplitting.hxx>

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

// MARK: - Memory Management

// MARK: - Shape Conversion

OCCTShapeRef OCCTShapeFromWire(OCCTWireRef wireRef) {
    if (!wireRef) return nullptr;
    return new OCCTShape(wireRef->wire);
}

OCCTShapeRef OCCTShapeFromFace(OCCTFaceRef faceRef) {
    if (!faceRef) return nullptr;
    return new OCCTShape(faceRef->face);
}

OCCTFaceRef OCCTFaceFromShape(OCCTShapeRef shape) {
    if (!shape) return nullptr;
    try {
        if (shape->shape.IsNull()) return nullptr;
        if (shape->shape.ShapeType() != TopAbs_FACE) return nullptr;
        return new OCCTFace(TopoDS::Face(shape->shape));
    } catch (...) { return nullptr; }
}

OCCTWireRef OCCTWireFromShape(OCCTShapeRef shape) {
    if (!shape) return nullptr;
    try {
        if (shape->shape.IsNull()) return nullptr;
        if (shape->shape.ShapeType() != TopAbs_WIRE) return nullptr;
        return new OCCTWire(TopoDS::Wire(shape->shape));
    } catch (...) { return nullptr; }
}

void OCCTShapeRelease(OCCTShapeRef shape) {
    delete shape;
}

void OCCTWireRelease(OCCTWireRef wire) {
    delete wire;
}

void OCCTMeshRelease(OCCTMeshRef mesh) {
    delete mesh;
}

// MARK: - Shape Axis Extraction (v0.137)

static bool axesCoincide(const OCCTShapeAxis& a, double ox, double oy, double oz,
                          double dx, double dy, double dz, double tol) {
    gp_Dir d1(a.directionX, a.directionY, a.directionZ);
    gp_Dir d2(dx, dy, dz);
    // Direction parallel (either same or opposite)
    if (fabs(fabs(d1.Dot(d2)) - 1.0) > tol) return false;
    // Origin-to-origin vector parallel to direction (i.e. same line)
    gp_Vec sep(ox - a.originX, oy - a.originY, oz - a.originZ);
    if (sep.Magnitude() < tol) return true;
    gp_Vec axisVec(d1.X(), d1.Y(), d1.Z());
    gp_Vec cross = sep.Crossed(axisVec);
    return cross.Magnitude() < tol;
}

int32_t OCCTShapeRevolutionAxes(OCCTShapeRef shape, double tolerance,
                                 OCCTShapeAxis* outAxes, int32_t maxAxes) {
    if (!shape || !outAxes || maxAxes <= 0) return -1;
    try {
        std::vector<OCCTShapeAxis> collected;
        for (TopExp_Explorer ex(shape->shape, TopAbs_FACE); ex.More(); ex.Next()) {
            TopoDS_Face face = TopoDS::Face(ex.Current());
            BRepAdaptor_Surface adaptor(face);
            gp_Ax1 axis;
            int kind = 0;
            try {
                switch (adaptor.GetType()) {
                    case GeomAbs_Cylinder: axis = adaptor.Cylinder().Axis(); kind = 1; break;
                    case GeomAbs_Cone:     axis = adaptor.Cone().Axis();     kind = 2; break;
                    case GeomAbs_Sphere: {
                        gp_Sphere s = adaptor.Sphere();
                        axis = gp_Ax1(s.Location(), s.Position().Direction());
                        kind = 3;
                        break;
                    }
                    case GeomAbs_Torus: axis = adaptor.Torus().Axis(); kind = 4; break;
                    case GeomAbs_SurfaceOfRevolution: {
                        Handle(Geom_Surface) surf = BRep_Tool::Surface(face);
                        Handle(Geom_SurfaceOfRevolution) rev = Handle(Geom_SurfaceOfRevolution)::DownCast(surf);
                        if (rev.IsNull()) continue;
                        axis = rev->Axis();
                        kind = 5;
                        break;
                    }
                    default: continue;
                }
            } catch (...) { continue; }
            const gp_Pnt& p = axis.Location();
            const gp_Dir& d = axis.Direction();
            bool dup = false;
            for (const auto& existing : collected) {
                if (axesCoincide(existing, p.X(), p.Y(), p.Z(), d.X(), d.Y(), d.Z(), tolerance)) {
                    dup = true;
                    break;
                }
            }
            if (dup) continue;
            OCCTShapeAxis a;
            a.originX = p.X(); a.originY = p.Y(); a.originZ = p.Z();
            a.directionX = d.X(); a.directionY = d.Y(); a.directionZ = d.Z();
            a.extentMin = 0; a.extentMax = 0; a.hasExtent = false;
            a.kind = kind;
            collected.push_back(a);
        }
        int32_t count = std::min((int32_t)collected.size(), maxAxes);
        for (int32_t i = 0; i < count; i++) outAxes[i] = collected[i];
        return (int32_t)collected.size();
    } catch (...) {
        return -1;
    }
}

int32_t OCCTShapeSymmetryAxes(OCCTShapeRef shape, double fractionalTolerance,
                               OCCTShapeAxis* outAxes, int32_t maxAxes) {
    if (!shape || !outAxes || maxAxes <= 0) return -1;
    try {
        GProp_GProps props;
        BRepGProp::VolumeProperties(shape->shape, props);
        gp_Pnt cm = props.CentreOfMass();
        GProp_PrincipalProps pp = props.PrincipalProperties();
        double Ix, Iy, Iz;
        pp.Moments(Ix, Iy, Iz);
        gp_Vec v1 = pp.FirstAxisOfInertia();
        gp_Vec v2 = pp.SecondAxisOfInertia();
        gp_Vec v3 = pp.ThirdAxisOfInertia();
        double moments[3] = { Ix, Iy, Iz };
        gp_Vec axes[3] = { v1, v2, v3 };
        double maxM = std::max({ Ix, Iy, Iz });
        std::vector<OCCTShapeAxis> collected;
        if (pp.HasSymmetryPoint()) {
            // Spherical — add all three principal axes (all equal).
            for (int i = 0; i < 3; i++) {
                OCCTShapeAxis a;
                a.originX = cm.X(); a.originY = cm.Y(); a.originZ = cm.Z();
                a.directionX = axes[i].X(); a.directionY = axes[i].Y(); a.directionZ = axes[i].Z();
                a.extentMin = 0; a.extentMax = 0; a.hasExtent = false; a.kind = 7;
                collected.push_back(a);
            }
        } else if (pp.HasSymmetryAxis()) {
            // Rotational — the unique (different) moment's axis IS the symmetry axis.
            int uniqueIdx = 0;
            for (int i = 0; i < 3; i++) {
                int j = (i + 1) % 3, k = (i + 2) % 3;
                if (fabs(moments[j] - moments[k]) < fractionalTolerance * maxM &&
                    fabs(moments[i] - moments[j]) > fractionalTolerance * maxM) {
                    uniqueIdx = i;
                    break;
                }
            }
            OCCTShapeAxis a;
            a.originX = cm.X(); a.originY = cm.Y(); a.originZ = cm.Z();
            a.directionX = axes[uniqueIdx].X();
            a.directionY = axes[uniqueIdx].Y();
            a.directionZ = axes[uniqueIdx].Z();
            a.extentMin = 0; a.extentMax = 0; a.hasExtent = false; a.kind = 7;
            collected.push_back(a);
        }
        int32_t count = std::min((int32_t)collected.size(), maxAxes);
        for (int32_t i = 0; i < count; i++) outAxes[i] = collected[i];
        return (int32_t)collected.size();
    } catch (...) {
        return -1;
    }
}

int32_t OCCTShapeAllDistanceSolutions(OCCTShapeRef shape1, OCCTShapeRef shape2,
                                       OCCTDistanceSolution* outSolutions, int32_t maxSolutions) {
    if (!shape1 || !shape2 || !outSolutions || maxSolutions <= 0) return -1;
    try {
        BRepExtrema_DistShapeShape dist(shape1->shape, shape2->shape);
        if (!dist.IsDone()) return -1;

        int32_t nbSol = dist.NbSolution();
        int32_t count = std::min(nbSol, maxSolutions);

        for (int32_t i = 0; i < count; i++) {
            gp_Pnt p1 = dist.PointOnShape1(i + 1);
            gp_Pnt p2 = dist.PointOnShape2(i + 1);
            outSolutions[i].point1X = p1.X();
            outSolutions[i].point1Y = p1.Y();
            outSolutions[i].point1Z = p1.Z();
            outSolutions[i].point2X = p2.X();
            outSolutions[i].point2Y = p2.Y();
            outSolutions[i].point2Z = p2.Z();
            outSolutions[i].distance = dist.Value();
        }
        return nbSol;
    } catch (...) {
        return -1;
    }
}

int32_t OCCTShapeIsInnerDistance(OCCTShapeRef shape1, OCCTShapeRef shape2) {
    if (!shape1 || !shape2) return -1;
    try {
        BRepExtrema_DistShapeShape dist(shape1->shape, shape2->shape);
        if (!dist.IsDone()) return -1;
        return dist.InnerSolution() ? 1 : 0;
    } catch (...) {
        return -1;
    }
}

bool OCCTShapeDistanceSolutionDetail(OCCTShapeRef shape1, OCCTShapeRef shape2,
    int32_t solutionIndex, OCCTDistanceSolutionDetail* outDetail) {
    if (!shape1 || !shape2 || !outDetail) return false;
    try {
        BRepExtrema_DistShapeShape dist(shape1->shape, shape2->shape);
        if (!dist.IsDone()) return false;
        int idx = solutionIndex + 1; // OCCT is 1-based
        if (idx < 1 || idx > dist.NbSolution()) return false;

        memset(outDetail, 0, sizeof(OCCTDistanceSolutionDetail));

        // Support types: BRepExtrema_IsVertex=0, BRepExtrema_IsOnEdge=1, BRepExtrema_IsInFace=2
        outDetail->supportType1 = (int32_t)dist.SupportTypeShape1(idx);
        outDetail->supportType2 = (int32_t)dist.SupportTypeShape2(idx);

        // Edge parameters
        if (outDetail->supportType1 == 1) { // IsOnEdge
            double t = 0;
            dist.ParOnEdgeS1(idx, t);
            outDetail->paramEdge1 = t;
        }
        if (outDetail->supportType2 == 1) {
            double t = 0;
            dist.ParOnEdgeS2(idx, t);
            outDetail->paramEdge2 = t;
        }

        // Face parameters
        if (outDetail->supportType1 == 2) { // IsInFace
            double u = 0, v = 0;
            dist.ParOnFaceS1(idx, u, v);
            outDetail->paramFaceU1 = u;
            outDetail->paramFaceV1 = v;
        }
        if (outDetail->supportType2 == 2) {
            double u = 0, v = 0;
            dist.ParOnFaceS2(idx, u, v);
            outDetail->paramFaceU2 = u;
            outDetail->paramFaceV2 = v;
        }
        return true;
    } catch (...) { return false; }
}

int32_t OCCTSurfaceBSplineToBezierPatches(OCCTSurfaceRef surface,
                                           OCCTSurfaceRef* outPatches, int32_t maxPatches,
                                           int32_t* outNbUPatches, int32_t* outNbVPatches) {
    if (!surface || !outPatches || !outNbUPatches || !outNbVPatches || maxPatches <= 0) return -1;
    try {
        Handle(Geom_BSplineSurface) bspline = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
        if (bspline.IsNull()) return -1;

        GeomConvert_BSplineSurfaceToBezierSurface conv(bspline);
        int32_t nbU = conv.NbUPatches();
        int32_t nbV = conv.NbVPatches();
        *outNbUPatches = nbU;
        *outNbVPatches = nbV;

        int32_t total = nbU * nbV;
        int32_t count = std::min(total, maxPatches);

        int32_t idx = 0;
        for (int32_t u = 1; u <= nbU && idx < count; u++) {
            for (int32_t v = 1; v <= nbV && idx < count; v++) {
                Handle(Geom_BezierSurface) patch = conv.Patch(u, v);
                if (!patch.IsNull()) {
                    outPatches[idx] = new OCCTSurface(patch);
                } else {
                    outPatches[idx] = nullptr;
                }
                idx++;
            }
        }
        return total;
    } catch (...) {
        return -1;
    }
}

int32_t OCCTCurve3DBSplineKnotSplits(OCCTCurve3DRef curve3D, int32_t continuityOrder,
                                       double* outParams, int32_t maxParams) {
    if (!curve3D || !outParams || maxParams <= 0) return -1;
    try {
        Handle(Geom_BSplineCurve) bspline = Handle(Geom_BSplineCurve)::DownCast(curve3D->curve);
        if (bspline.IsNull()) return -1;

        GeomConvert_BSplineCurveKnotSplitting splitter(bspline, continuityOrder);
        int32_t nbSplits = splitter.NbSplits();
        int32_t count = std::min(nbSplits, maxParams);

        for (int32_t i = 0; i < count; i++) {
            int32_t knotIndex = splitter.SplitValue(i + 1);
            outParams[i] = bspline->Knot(knotIndex);
        }
        return nbSplits;
    } catch (...) {
        return -1;
    }
}

OCCTSurfaceRef OCCTShapeFindSurfaceEx(OCCTShapeRef shape, double tolerance,
                                       bool onlyPlane, bool* outFound) {
    if (!shape || !outFound) return nullptr;
    try {
        BRepLib_FindSurface finder(shape->shape, tolerance, onlyPlane);
        *outFound = finder.Found();
        if (!finder.Found()) return nullptr;

        Handle(Geom_Surface) surf = finder.Surface();
        if (surf.IsNull()) return nullptr;

        return new OCCTSurface(surf);
    } catch (...) {
        *outFound = false;
        return nullptr;
    }
}

// MARK: - v0.41.0: Shape Surgery, Plane Detection, Geometry Conversion

#include <BRepTools_ReShape.hxx>
#include <BRepBuilderAPI_FindPlane.hxx>
#include <Geom_Plane.hxx>
#include <ShapeUpgrade_ShapeDivideClosedEdges.hxx>
#include <ShapeCustom.hxx>
#include <BRepAlgo_FaceRestrictor.hxx>

OCCTShapeRef OCCTShapeRemoveSubShapes(OCCTShapeRef shape, OCCTShapeRef* subShapes, int32_t count) {
    if (!shape || !subShapes || count <= 0) return nullptr;
    try {
        Handle(BRepTools_ReShape) reshaper = new BRepTools_ReShape();
        for (int32_t i = 0; i < count; i++) {
            if (subShapes[i]) {
                reshaper->Remove(subShapes[i]->shape);
            }
        }
        TopoDS_Shape result = reshaper->Apply(shape->shape);
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeReplaceSubShapes(OCCTShapeRef shape,
                                        OCCTShapeRef* oldShapes, OCCTShapeRef* newShapes,
                                        int32_t count) {
    if (!shape || !oldShapes || !newShapes || count <= 0) return nullptr;
    try {
        Handle(BRepTools_ReShape) reshaper = new BRepTools_ReShape();
        for (int32_t i = 0; i < count; i++) {
            if (oldShapes[i] && newShapes[i]) {
                reshaper->Replace(oldShapes[i]->shape, newShapes[i]->shape);
            }
        }
        TopoDS_Shape result = reshaper->Apply(shape->shape);
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

bool OCCTShapeFindPlane(OCCTShapeRef shape, double tolerance,
                         double* outNormalX, double* outNormalY, double* outNormalZ,
                         double* outOriginX, double* outOriginY, double* outOriginZ) {
    if (!shape || !outNormalX || !outNormalY || !outNormalZ ||
        !outOriginX || !outOriginY || !outOriginZ) return false;
    try {
        BRepBuilderAPI_FindPlane finder(shape->shape, tolerance);
        if (!finder.Found()) return false;

        Handle(Geom_Plane) plane = finder.Plane();
        if (plane.IsNull()) return false;

        gp_Pln pln = plane->Pln();
        gp_Dir norm = pln.Axis().Direction();
        gp_Pnt loc = pln.Location();

        *outNormalX = norm.X();
        *outNormalY = norm.Y();
        *outNormalZ = norm.Z();
        *outOriginX = loc.X();
        *outOriginY = loc.Y();
        *outOriginZ = loc.Z();

        return true;
    } catch (...) {
        return false;
    }
}
// MARK: - Sub-Shape Extraction (fixes #36)

int32_t OCCTShapeGetSubShapeCount(OCCTShapeRef shape, int32_t type) {
    if (!shape) return 0;
    try {
        TopTools_IndexedMapOfShape map;
        TopExp::MapShapes(shape->shape, static_cast<TopAbs_ShapeEnum>(type), map);
        return map.Extent();
    } catch (...) {
        return 0;
    }
}

OCCTShapeRef OCCTShapeGetSubShapeByTypeIndex(OCCTShapeRef shape, int32_t type, int32_t index) {
    if (!shape || index < 0) return nullptr;
    try {
        TopTools_IndexedMapOfShape map;
        TopExp::MapShapes(shape->shape, static_cast<TopAbs_ShapeEnum>(type), map);
        if (index >= map.Extent()) return nullptr;
        return new OCCTShape(map(index + 1)); // OCCT uses 1-based indexing
    } catch (...) {
        return nullptr;
    }
}


// MARK: - BRepExtrema_SelfIntersection (v0.45)
OCCTSelfIntersectionResult OCCTShapeSelfIntersection(OCCTShapeRef shape, double tolerance,
                                                      double meshDeflection) {
    OCCTSelfIntersectionResult result = {0, false};
    if (!shape) return result;
    try {
        // Ensure the shape is meshed
        BRepMesh_IncrementalMesh mesh(shape->shape, meshDeflection);

        BRepExtrema_SelfIntersection selfInt(shape->shape, tolerance);
        selfInt.Perform();

        result.isDone = selfInt.IsDone();
        if (result.isDone) {
            result.overlapCount = (int32_t)selfInt.OverlapElements().Size();
        }
        return result;
    } catch (...) {
        return result;
    }
}

// MARK: - BRepOffset_Analyse Edge Concavity (v0.46)
int32_t OCCTShapeAnalyzeEdgeConcavity(OCCTShapeRef shape, double angle,
                                       OCCTEdgeConcavity* outEdgeTypes, int32_t maxEntries) {
    if (!shape || !outEdgeTypes || maxEntries <= 0) return -1;
    try {
        BRepOffset_Analyse analyser(shape->shape, angle);
        if (!analyser.IsDone()) return -1;

        int32_t count = 0;
        for (TopExp_Explorer exp(shape->shape, TopAbs_EDGE); exp.More() && count < maxEntries; exp.Next()) {
            TopoDS_Edge edge = TopoDS::Edge(exp.Current());
            const auto& intervals = analyser.Type(edge);
            // Use the first interval's type for the overall edge classification
            for (auto it = intervals.begin(); it != intervals.end(); ++it) {
                OCCTConcavityType type;
                if (it->Type() == ChFiDS_Convex) type = OCCTConcavityConvex;
                else if (it->Type() == ChFiDS_Concave) type = OCCTConcavityConcave;
                else type = OCCTConcavityTangent;
                outEdgeTypes[count].type = type;
                count++;
                break; // One classification per edge
            }
        }
        return count;
    } catch (...) {
        return -1;
    }
}

int32_t OCCTShapeCountEdgeConcavity(OCCTShapeRef shape, double angle, int32_t type) {
    if (!shape) return -1;
    try {
        BRepOffset_Analyse analyser(shape->shape, angle);
        if (!analyser.IsDone()) return -1;

        ChFiDS_TypeOfConcavity targetType;
        if (type == 0) targetType = ChFiDS_Convex;
        else if (type == 1) targetType = ChFiDS_Concave;
        else targetType = ChFiDS_Tangential;

        int32_t count = 0;
        for (TopExp_Explorer exp(shape->shape, TopAbs_EDGE); exp.More(); exp.Next()) {
            TopoDS_Edge edge = TopoDS::Edge(exp.Current());
            const auto& intervals = analyser.Type(edge);
            for (auto it = intervals.begin(); it != intervals.end(); ++it) {
                if (it->Type() == targetType) {
                    count++;
                    break;
                }
            }
        }
        return count;
    } catch (...) {
        return -1;
    }
}

// MARK: - BRepExtrema Ext CC/PF/FF (v0.48)
OCCTEdgeEdgeExtremaResult OCCTBRepExtremaExtCC(OCCTShapeRef shape1, int32_t edgeIndex1,
                                                OCCTShapeRef shape2, int32_t edgeIndex2) {
    OCCTEdgeEdgeExtremaResult result = {};
    if (!shape1 || !shape2) return result;
    try {
        // Find edges
        TopoDS_Edge e1, e2;
        int idx = 0;
        for (TopExp_Explorer exp(shape1->shape, TopAbs_EDGE); exp.More(); exp.Next()) {
            if (idx == edgeIndex1) { e1 = TopoDS::Edge(exp.Current()); break; }
            idx++;
        }
        idx = 0;
        for (TopExp_Explorer exp(shape2->shape, TopAbs_EDGE); exp.More(); exp.Next()) {
            if (idx == edgeIndex2) { e2 = TopoDS::Edge(exp.Current()); break; }
            idx++;
        }
        if (e1.IsNull() || e2.IsNull()) return result;

        BRepExtrema_ExtCC extCC(e1, e2);
        if (!extCC.IsDone()) return result;

        result.isParallel = extCC.IsParallel();
        if (result.isParallel) {
            result.solutionCount = 0;
            return result;
        }
        result.solutionCount = extCC.NbExt();

        if (result.solutionCount >= 1 && !result.isParallel) {
            result.distance = sqrt(extCC.SquareDistance(1));
            result.paramOnE1 = extCC.ParameterOnE1(1);
            result.paramOnE2 = extCC.ParameterOnE2(1);
            gp_Pnt p1 = extCC.PointOnE1(1);
            gp_Pnt p2 = extCC.PointOnE2(1);
            result.pt1x = p1.X(); result.pt1y = p1.Y(); result.pt1z = p1.Z();
            result.pt2x = p2.X(); result.pt2y = p2.Y(); result.pt2z = p2.Z();
        }
        return result;
    } catch (...) {
        return result;
    }
}

OCCTEdgeEdgeExtremaResult OCCTBRepExtremaExtCCEdges(OCCTShapeRef edge1, OCCTShapeRef edge2) {
    OCCTEdgeEdgeExtremaResult result = {};
    if (!edge1 || !edge2) return result;
    try {
        TopoDS_Edge e1, e2;
        if (edge1->shape.ShapeType() == TopAbs_EDGE) {
            e1 = TopoDS::Edge(edge1->shape);
        } else {
            for (TopExp_Explorer exp(edge1->shape, TopAbs_EDGE); exp.More(); exp.Next()) {
                e1 = TopoDS::Edge(exp.Current()); break;
            }
        }
        if (edge2->shape.ShapeType() == TopAbs_EDGE) {
            e2 = TopoDS::Edge(edge2->shape);
        } else {
            for (TopExp_Explorer exp(edge2->shape, TopAbs_EDGE); exp.More(); exp.Next()) {
                e2 = TopoDS::Edge(exp.Current()); break;
            }
        }
        if (e1.IsNull() || e2.IsNull()) return result;

        BRepExtrema_ExtCC extCC(e1, e2);
        if (!extCC.IsDone()) return result;

        result.isParallel = extCC.IsParallel();
        if (result.isParallel) {
            result.solutionCount = 0;
            return result;
        }
        result.solutionCount = extCC.NbExt();

        if (result.solutionCount >= 1 && !result.isParallel) {
            result.distance = sqrt(extCC.SquareDistance(1));
            result.paramOnE1 = extCC.ParameterOnE1(1);
            result.paramOnE2 = extCC.ParameterOnE2(1);
            gp_Pnt p1 = extCC.PointOnE1(1);
            gp_Pnt p2 = extCC.PointOnE2(1);
            result.pt1x = p1.X(); result.pt1y = p1.Y(); result.pt1z = p1.Z();
            result.pt2x = p2.X(); result.pt2y = p2.Y(); result.pt2z = p2.Z();
        }
        return result;
    } catch (...) {
        return result;
    }
}

OCCTPointFaceExtremaResult OCCTBRepExtremaExtPF(double px, double py, double pz,
                                                 OCCTShapeRef shape, int32_t faceIndex) {
    OCCTPointFaceExtremaResult result = {};
    if (!shape) return result;
    try {
        // Find face
        TopoDS_Face face;
        int idx = 0;
        for (TopExp_Explorer exp(shape->shape, TopAbs_FACE); exp.More(); exp.Next()) {
            if (idx == faceIndex) { face = TopoDS::Face(exp.Current()); break; }
            idx++;
        }
        if (face.IsNull()) return result;

        TopoDS_Vertex vertex = BRepBuilderAPI_MakeVertex(gp_Pnt(px, py, pz));
        BRepExtrema_ExtPF extPF(vertex, face);
        if (!extPF.IsDone()) return result;

        result.solutionCount = extPF.NbExt();
        if (result.solutionCount >= 1) {
            result.distance = sqrt(extPF.SquareDistance(1));
            gp_Pnt pt = extPF.Point(1);
            result.ptx = pt.X(); result.pty = pt.Y(); result.ptz = pt.Z();
            extPF.Parameter(1, result.u, result.v);
        }
        return result;
    } catch (...) {
        return result;
    }
}

OCCTFaceFaceExtremaResult OCCTBRepExtremaExtFF(OCCTShapeRef shape1, int32_t faceIndex1,
                                                OCCTShapeRef shape2, int32_t faceIndex2) {
    OCCTFaceFaceExtremaResult result = {};
    if (!shape1 || !shape2) return result;
    try {
        // Find faces
        TopoDS_Face f1, f2;
        int idx = 0;
        for (TopExp_Explorer exp(shape1->shape, TopAbs_FACE); exp.More(); exp.Next()) {
            if (idx == faceIndex1) { f1 = TopoDS::Face(exp.Current()); break; }
            idx++;
        }
        idx = 0;
        for (TopExp_Explorer exp(shape2->shape, TopAbs_FACE); exp.More(); exp.Next()) {
            if (idx == faceIndex2) { f2 = TopoDS::Face(exp.Current()); break; }
            idx++;
        }
        if (f1.IsNull() || f2.IsNull()) return result;

        BRepExtrema_ExtFF extFF(f1, f2);
        if (!extFF.IsDone()) return result;

        result.solutionCount = extFF.NbExt();
        if (result.solutionCount >= 1) {
            result.distance = sqrt(extFF.SquareDistance(1));
            extFF.ParameterOnFace1(1, result.u1, result.v1);
            extFF.ParameterOnFace2(1, result.u2, result.v2);
            gp_Pnt p1 = extFF.PointOnFace1(1);
            gp_Pnt p2 = extFF.PointOnFace2(1);
            result.pt1x = p1.X(); result.pt1y = p1.Y(); result.pt1z = p1.Z();
            result.pt2x = p2.X(); result.pt2y = p2.Y(); result.pt2z = p2.Z();
        }
        return result;
    } catch (...) {
        return result;
    }
}

// MARK: - BRepExtrema Ext PC/CF (v0.49)
OCCTPointEdgeExtremaResult OCCTBRepExtremaExtPC(double px, double py, double pz,
                                                 OCCTShapeRef shape, int32_t edgeIndex) {
    OCCTPointEdgeExtremaResult result = {};
    if (!shape) return result;
    try {
        TopoDS_Edge edge;
        int idx = 0;
        for (TopExp_Explorer exp(shape->shape, TopAbs_EDGE); exp.More(); exp.Next()) {
            if (idx == edgeIndex) { edge = TopoDS::Edge(exp.Current()); break; }
            idx++;
        }
        if (edge.IsNull()) return result;

        TopoDS_Vertex vertex = BRepBuilderAPI_MakeVertex(gp_Pnt(px, py, pz));
        BRepExtrema_ExtPC ext(vertex, edge);
        if (!ext.IsDone()) return result;

        result.solutionCount = ext.NbExt();
        if (result.solutionCount >= 1) {
            // Find minimum distance
            double minDist2 = ext.SquareDistance(1);
            int minIdx = 1;
            for (int i = 2; i <= ext.NbExt(); i++) {
                if (ext.SquareDistance(i) < minDist2) {
                    minDist2 = ext.SquareDistance(i);
                    minIdx = i;
                }
            }
            result.distance = sqrt(minDist2);
            result.parameter = ext.Parameter(minIdx);
            gp_Pnt pt = ext.Point(minIdx);
            result.ptx = pt.X(); result.pty = pt.Y(); result.ptz = pt.Z();
        }
        return result;
    } catch (...) {
        return result;
    }
}
// --- BRepExtrema_ExtCF ---

OCCTEdgeFaceExtremaResult OCCTBRepExtremaExtCF(OCCTShapeRef shape1, int32_t edgeIndex,
                                                OCCTShapeRef shape2, int32_t faceIndex) {
    OCCTEdgeFaceExtremaResult result = {};
    if (!shape1 || !shape2) return result;
    try {
        TopoDS_Edge edge;
        int idx = 0;
        for (TopExp_Explorer exp(shape1->shape, TopAbs_EDGE); exp.More(); exp.Next()) {
            if (idx == edgeIndex) { edge = TopoDS::Edge(exp.Current()); break; }
            idx++;
        }
        if (edge.IsNull()) return result;

        TopoDS_Face face;
        idx = 0;
        for (TopExp_Explorer exp(shape2->shape, TopAbs_FACE); exp.More(); exp.Next()) {
            if (idx == faceIndex) { face = TopoDS::Face(exp.Current()); break; }
            idx++;
        }
        if (face.IsNull()) return result;

        BRepExtrema_ExtCF ext(edge, face);
        if (!ext.IsDone()) return result;

        result.isParallel = ext.IsParallel();
        if (result.isParallel) {
            result.solutionCount = 0;
            return result;
        }

        result.solutionCount = ext.NbExt();
        if (result.solutionCount >= 1) {
            // Find minimum distance
            double minDist2 = ext.SquareDistance(1);
            int minIdx = 1;
            for (int i = 2; i <= ext.NbExt(); i++) {
                if (ext.SquareDistance(i) < minDist2) {
                    minDist2 = ext.SquareDistance(i);
                    minIdx = i;
                }
            }
            result.distance = sqrt(minDist2);
            result.paramOnEdge = ext.ParameterOnEdge(minIdx);
            ext.ParameterOnFace(minIdx, result.uOnFace, result.vOnFace);
            gp_Pnt pe = ext.PointOnEdge(minIdx);
            result.edgePtx = pe.X(); result.edgePty = pe.Y(); result.edgePtz = pe.Z();
            gp_Pnt pf = ext.PointOnFace(minIdx);
            result.facePtx = pf.X(); result.facePty = pf.Y(); result.facePtz = pf.Z();
        }
        return result;
    } catch (...) {
        return result;
    }
}

// MARK: - BRepExtrema_Poly Distance (v0.50)
OCCTPolyDistanceResult OCCTShapePolyhedralDistance(OCCTShapeRef shape1, OCCTShapeRef shape2) {
    OCCTPolyDistanceResult result = {};
    if (!shape1 || !shape2) return result;
    try {
        gp_Pnt p1, p2;
        Standard_Real dist;
        Standard_Boolean ok = BRepExtrema_Poly::Distance(
            shape1->shape, shape2->shape, p1, p2, dist);
        if (ok) {
            result.success = true;
            result.distance = dist;
            result.p1x = p1.X(); result.p1y = p1.Y(); result.p1z = p1.Z();
            result.p2x = p2.X(); result.p2y = p2.Y(); result.p2z = p2.Z();
        }
    } catch (...) {}
    return result;
}

// MARK: - IntCurvesFace Curve-Face Intersection (v0.61)
// MARK: - IntCurvesFace — Curve-Face Intersection (v0.61.0)

int32_t OCCTIntersectLineFace(OCCTShapeRef face,
    double origX, double origY, double origZ,
    double dirX, double dirY, double dirZ,
    double pInf, double pSup,
    double* outPoints, double* outParams, int32_t maxPts) {
    if (!face || !outPoints || !outParams || maxPts <= 0) return 0;
    try {
        if (face->shape.ShapeType() != TopAbs_FACE) return 0;
        TopoDS_Face f = TopoDS::Face(face->shape);
        IntCurvesFace_Intersector intersector(f, 1e-6);
        gp_Lin line(gp_Pnt(origX, origY, origZ), gp_Dir(dirX, dirY, dirZ));
        intersector.Perform(line, pInf, pSup);
        if (!intersector.IsDone()) return 0;
        int32_t nb = std::min((int32_t)intersector.NbPnt(), maxPts);
        for (int32_t i = 0; i < nb; i++) {
            gp_Pnt pt = intersector.Pnt(i + 1);
            outPoints[i * 3] = pt.X();
            outPoints[i * 3 + 1] = pt.Y();
            outPoints[i * 3 + 2] = pt.Z();
            outParams[i] = intersector.WParameter(i + 1);
        }
        return nb;
    } catch (...) { return 0; }
}
