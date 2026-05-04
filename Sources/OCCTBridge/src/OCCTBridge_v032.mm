//
//  OCCTBridge_v032.mm
//  OCCTSwift
//
//  Extracted from OCCTBridge.mm — issue #99.
//
//  v0.32 cluster — six modeling-feature sub-sections.
//  Per-area #include directives stay inline at section boundaries.
//
//  Areas: Asymmetric Chamfer, Loft Improvements, Offset with Join Type,
//  Revolution Form Feature, Draft Prism Feature, Revolution Feature.
//
//  Public C surface unchanged. No symbol changes — pure file move.
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

// === Headers shared across multiple subsections ===

#include <gp_Ax1.hxx>
#include <gp_Ax2.hxx>
#include <gp_Dir.hxx>
#include <gp_Pln.hxx>
#include <gp_Pnt.hxx>
#include <gp_Vec.hxx>

#include <BRep_Tool.hxx>
#include <BRep_Builder.hxx>
#include <BRepFilletAPI_MakeChamfer.hxx>
#include <BRepOffsetAPI_ThruSections.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepOffsetAPI_MakeOffsetShape.hxx>
#include <BRepOffset.hxx>
#include <BRepLib_FindSurface.hxx>
#include <Geom_Plane.hxx>
#include <GeomAbs_JoinType.hxx>

#include <TopAbs.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>

// MARK: - Asymmetric Chamfer (v0.32.0)

OCCTShapeRef OCCTShapeChamferTwoDistances(OCCTShapeRef shape,
                                           const int32_t* edgeIndices,
                                           const int32_t* faceIndices,
                                           const double* dist1,
                                           const double* dist2,
                                           int32_t count) {
    if (!shape || !edgeIndices || !faceIndices || !dist1 || !dist2 || count <= 0) return nullptr;
    try {
        BRepFilletAPI_MakeChamfer chamfer(shape->shape);
        TopTools_IndexedMapOfShape edgeMap, faceMap;
        TopExp::MapShapes(shape->shape, TopAbs_EDGE, edgeMap);
        TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);

        for (int32_t i = 0; i < count; i++) {
            int32_t ei = edgeIndices[i] + 1;  // 0-based to 1-based
            int32_t fi = faceIndices[i] + 1;
            if (ei < 1 || ei > edgeMap.Extent()) return nullptr;
            if (fi < 1 || fi > faceMap.Extent()) return nullptr;
            chamfer.Add(dist1[i], dist2[i],
                        TopoDS::Edge(edgeMap(ei)),
                        TopoDS::Face(faceMap(fi)));
        }
        chamfer.Build();
        if (!chamfer.IsDone()) return nullptr;
        return new OCCTShape(chamfer.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeChamferDistAngle(OCCTShapeRef shape,
                                        const int32_t* edgeIndices,
                                        const int32_t* faceIndices,
                                        const double* distances,
                                        const double* anglesDeg,
                                        int32_t count) {
    if (!shape || !edgeIndices || !faceIndices || !distances || !anglesDeg || count <= 0) return nullptr;
    try {
        BRepFilletAPI_MakeChamfer chamfer(shape->shape);
        TopTools_IndexedMapOfShape edgeMap, faceMap;
        TopExp::MapShapes(shape->shape, TopAbs_EDGE, edgeMap);
        TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);

        for (int32_t i = 0; i < count; i++) {
            int32_t ei = edgeIndices[i] + 1;
            int32_t fi = faceIndices[i] + 1;
            if (ei < 1 || ei > edgeMap.Extent()) return nullptr;
            if (fi < 1 || fi > faceMap.Extent()) return nullptr;
            double angleRad = anglesDeg[i] * M_PI / 180.0;
            chamfer.AddDA(distances[i], angleRad,
                          TopoDS::Edge(edgeMap(ei)),
                          TopoDS::Face(faceMap(fi)));
        }
        chamfer.Build();
        if (!chamfer.IsDone()) return nullptr;
        return new OCCTShape(chamfer.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Loft Improvements (v0.32.0)

OCCTShapeRef OCCTShapeCreateLoftAdvanced(const OCCTWireRef* profiles, int32_t profileCount,
                                          bool solid, bool ruled,
                                          double firstVertexX, double firstVertexY, double firstVertexZ,
                                          double lastVertexX, double lastVertexY, double lastVertexZ) {
    if (!profiles || profileCount < 1) return nullptr;
    try {
        BRepOffsetAPI_ThruSections maker(solid, ruled);
        maker.CheckCompatibility(Standard_True);

        // Add first vertex if specified (NaN check)
        if (firstVertexX == firstVertexX) {  // not NaN
            BRepBuilderAPI_MakeVertex mv(gp_Pnt(firstVertexX, firstVertexY, firstVertexZ));
            maker.AddVertex(TopoDS::Vertex(mv.Shape()));
        }

        for (int32_t i = 0; i < profileCount; i++) {
            if (profiles[i]) {
                maker.AddWire(profiles[i]->wire);
            }
        }

        // Add last vertex if specified
        if (lastVertexX == lastVertexX) {  // not NaN
            BRepBuilderAPI_MakeVertex mv(gp_Pnt(lastVertexX, lastVertexY, lastVertexZ));
            maker.AddVertex(TopoDS::Vertex(mv.Shape()));
        }

        maker.Build();
        if (!maker.IsDone()) return nullptr;
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Offset with Join Type (v0.32.0)

OCCTShapeRef OCCTShapeOffsetByJoin(OCCTShapeRef shape, double distance,
                                    double tolerance, int32_t joinType,
                                    bool removeInternalEdges) {
    if (!shape) return nullptr;
    try {
        BRepOffsetAPI_MakeOffsetShape offsetter;
        GeomAbs_JoinType join = GeomAbs_Arc;
        if (joinType == 1) join = GeomAbs_Tangent;
        else if (joinType == 2) join = GeomAbs_Intersection;
        offsetter.PerformByJoin(shape->shape, distance, tolerance,
                                BRepOffset_Skin, false, false, join, removeInternalEdges);
        if (!offsetter.IsDone()) return nullptr;
        return new OCCTShape(offsetter.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Revolution Form Feature (v0.32.0)

#include <BRepFeat_MakeRevolutionForm.hxx>

OCCTShapeRef OCCTShapeAddRevolutionForm(OCCTShapeRef shape, OCCTWireRef profile,
                                         double axOX, double axOY, double axOZ,
                                         double axDX, double axDY, double axDZ,
                                         double height1, double height2,
                                         bool fuse) {
    if (!shape || !profile) return nullptr;
    try {
        BRepLib_FindSurface finder(profile->wire);
        if (!finder.Found()) return nullptr;
        Handle(Geom_Plane) plane = Handle(Geom_Plane)::DownCast(finder.Surface());
        if (plane.IsNull()) return nullptr;
        gp_Ax1 axis(gp_Pnt(axOX, axOY, axOZ), gp_Dir(axDX, axDY, axDZ));
        bool sliding = true;
        BRepFeat_MakeRevolutionForm maker(shape->shape, profile->wire, plane, axis,
                                           height1, height2, fuse ? 1 : 0, sliding);
        maker.Perform();
        if (!maker.IsDone()) return nullptr;
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Draft Prism Feature (v0.32.0)

#include <BRepFeat_MakeDPrism.hxx>

OCCTShapeRef OCCTShapeDraftPrism(OCCTShapeRef shape, int32_t profileFace,
                                  OCCTWireRef profile, double angleDeg,
                                  double height, bool fuse) {
    if (!shape || !profile) return nullptr;
    try {
        TopTools_IndexedMapOfShape faceMap;
        TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);
        int32_t fi = profileFace + 1;
        if (fi < 1 || fi > faceMap.Extent()) return nullptr;
        TopoDS_Face sketchFace = TopoDS::Face(faceMap(fi));

        // Create profile face from wire
        BRepBuilderAPI_MakeFace makeFace(profile->wire, true);
        if (!makeFace.IsDone()) return nullptr;
        TopoDS_Face pbase = makeFace.Face();

        double angleRad = angleDeg * M_PI / 180.0;
        BRepFeat_MakeDPrism maker(shape->shape, pbase, sketchFace, angleRad,
                                   fuse ? 1 : 0, Standard_True);
        maker.Perform(height);
        if (!maker.IsDone()) return nullptr;
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeDraftPrismThruAll(OCCTShapeRef shape, int32_t profileFace,
                                         OCCTWireRef profile, double angleDeg,
                                         bool fuse) {
    if (!shape || !profile) return nullptr;
    try {
        TopTools_IndexedMapOfShape faceMap;
        TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);
        int32_t fi = profileFace + 1;
        if (fi < 1 || fi > faceMap.Extent()) return nullptr;
        TopoDS_Face sketchFace = TopoDS::Face(faceMap(fi));

        BRepBuilderAPI_MakeFace makeFace(profile->wire, true);
        if (!makeFace.IsDone()) return nullptr;
        TopoDS_Face pbase = makeFace.Face();

        double angleRad = angleDeg * M_PI / 180.0;
        BRepFeat_MakeDPrism maker(shape->shape, pbase, sketchFace, angleRad,
                                   fuse ? 1 : 0, Standard_True);
        maker.PerformThruAll();
        if (!maker.IsDone()) return nullptr;
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Revolution Feature (v0.32.0)

#include <BRepFeat_MakeRevol.hxx>

OCCTShapeRef OCCTShapeRevolFeature(OCCTShapeRef shape, int32_t profileFace,
                                    OCCTWireRef profile,
                                    double axOX, double axOY, double axOZ,
                                    double axDX, double axDY, double axDZ,
                                    double angleDeg, bool fuse) {
    if (!shape || !profile) return nullptr;
    try {
        TopTools_IndexedMapOfShape faceMap;
        TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);
        int32_t fi = profileFace + 1;
        if (fi < 1 || fi > faceMap.Extent()) return nullptr;
        TopoDS_Face sketchFace = TopoDS::Face(faceMap(fi));

        BRepBuilderAPI_MakeFace makeFace(profile->wire, true);
        if (!makeFace.IsDone()) return nullptr;
        TopoDS_Face pbase = makeFace.Face();

        gp_Ax1 axis(gp_Pnt(axOX, axOY, axOZ), gp_Dir(axDX, axDY, axDZ));
        double angleRad = angleDeg * M_PI / 180.0;

        BRepFeat_MakeRevol maker(shape->shape, pbase, sketchFace, axis,
                                  fuse ? 1 : 0, Standard_True);
        maker.Perform(angleRad);
        if (!maker.IsDone()) return nullptr;
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeRevolFeatureThruAll(OCCTShapeRef shape, int32_t profileFace,
                                           OCCTWireRef profile,
                                           double axOX, double axOY, double axOZ,
                                           double axDX, double axDY, double axDZ,
                                           bool fuse) {
    if (!shape || !profile) return nullptr;
    try {
        TopTools_IndexedMapOfShape faceMap;
        TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);
        int32_t fi = profileFace + 1;
        if (fi < 1 || fi > faceMap.Extent()) return nullptr;
        TopoDS_Face sketchFace = TopoDS::Face(faceMap(fi));

        BRepBuilderAPI_MakeFace makeFace(profile->wire, true);
        if (!makeFace.IsDone()) return nullptr;
        TopoDS_Face pbase = makeFace.Face();

        gp_Ax1 axis(gp_Pnt(axOX, axOY, axOZ), gp_Dir(axDX, axDY, axDZ));

        BRepFeat_MakeRevol maker(shape->shape, pbase, sketchFace, axis,
                                  fuse ? 1 : 0, Standard_True);
        maker.PerformThruAll();
        if (!maker.IsDone()) return nullptr;
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

