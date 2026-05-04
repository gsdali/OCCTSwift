//
//  OCCTBridge_v033_v038.mm
//  OCCTSwift
//
//  Extracted from OCCTBridge.mm — issue #99.
//
//  v0.33 + v0.38 cluster — ten sub-sections. The v0.33 sections sit
//  AFTER the v0.37 cluster in the original file (chronologically out
//  of order); they are extracted alongside the v0.38 sections that
//  immediately follow.
//
//  Per-area #include directives stay inline at section boundaries.
//
//  v0.33 areas: Evolved Shape Advanced, Pipe Shell with Transition
//  Mode, Face from Surface with UV Bounds, Edges to Faces.
//
//  v0.38 areas: Oriented Bounding Box, Deep Shape Copy, Sub-Shape
//  Extraction, Fuse and Blend, Multi-Edge Evolving Fillet, Per-Face
//  Variable Offset.
//
//  Public C surface unchanged. No symbol changes — pure file move.
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

// === Headers shared across multiple subsections ===

#include <gp_Ax1.hxx>
#include <gp_Ax2.hxx>
#include <gp_Ax3.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>
#include <gp_Vec.hxx>

#include <Geom_Curve.hxx>
#include <Geom_Surface.hxx>

#include <BRep_Tool.hxx>
#include <BRep_Builder.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepBuilderAPI_Copy.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepOffsetAPI_MakeEvolved.hxx>
#include <BRepOffsetAPI_MakePipeShell.hxx>
#include <GeomAbs_JoinType.hxx>
#include <gp_XYZ.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <TColgp_Array1OfPnt2d.hxx>
#include <gp_Pnt2d.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepOffsetAPI_MakeOffsetShape.hxx>
#include <BRepOffset.hxx>

#include <TopAbs.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>

// MARK: - Evolved Shape Advanced (v0.33.0)

OCCTShapeRef OCCTShapeCreateEvolvedAdvanced(OCCTShapeRef spine, OCCTWireRef profile,
                                             int32_t joinType, bool axeProf,
                                             bool solid, bool volume,
                                             double tolerance) {
    if (!spine || !profile) return nullptr;
    try {
        GeomAbs_JoinType join = GeomAbs_Arc;
        if (joinType == 1) join = GeomAbs_Tangent;
        else if (joinType == 2) join = GeomAbs_Intersection;
        BRepOffsetAPI_MakeEvolved evolved(spine->shape, profile->wire, join,
                                           axeProf, solid, false, tolerance, volume, false);
        if (!evolved.IsDone()) return nullptr;
        TopoDS_Shape result = evolved.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Pipe Shell with Transition Mode (v0.33.0)

#include <BRepBuilderAPI_TransitionMode.hxx>

OCCTShapeRef OCCTShapeCreatePipeShellWithTransition(OCCTWireRef spine, OCCTWireRef profile,
                                                     int32_t mode, int32_t transitionMode,
                                                     bool solid) {
    if (!spine || !profile) return nullptr;
    try {
        BRepOffsetAPI_MakePipeShell pipeShell(spine->wire);
        // Set sweep mode
        if (mode == 1) {
            pipeShell.SetMode(Standard_True);   // Corrected Frenet
        } else {
            pipeShell.SetMode(Standard_False);  // Frenet
        }
        // Set transition mode
        if (transitionMode == 1) {
            pipeShell.SetTransitionMode(BRepBuilderAPI_RightCorner);
        } else if (transitionMode == 2) {
            pipeShell.SetTransitionMode(BRepBuilderAPI_RoundCorner);
        } else {
            pipeShell.SetTransitionMode(BRepBuilderAPI_Transformed);
        }
        pipeShell.Add(profile->wire);
        pipeShell.SetIsBuildHistory(false); // avoid SEGV on closed spine+profile (OCCT bug)
        pipeShell.Build();
        if (!pipeShell.IsDone()) return nullptr;
        TopoDS_Shape result = pipeShell.Shape();
        if (solid) {
            pipeShell.MakeSolid();
            if (pipeShell.IsDone()) {
                result = pipeShell.Shape();
            }
        }
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Face from Surface with UV Bounds (v0.33.0)

OCCTShapeRef OCCTShapeCreateFaceFromSurface(OCCTSurfaceRef surface,
                                             double uMin, double uMax,
                                             double vMin, double vMax,
                                             double tolerance) {
    if (!surface || surface->surface.IsNull()) return nullptr;
    try {
        BRepBuilderAPI_MakeFace maker(surface->surface, uMin, uMax, vMin, vMax, tolerance);
        if (!maker.IsDone()) return nullptr;
        return new OCCTShape(maker.Face());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Edges to Faces (v0.33.0)

OCCTShapeRef OCCTShapeEdgesToFaces(OCCTShapeRef compound, bool isOnlyPlane) {
    if (!compound) return nullptr;
    try {
        // Collect all edges from the input shape
        TopTools_ListOfShape edgeList;
        TopExp_Explorer explorer(compound->shape, TopAbs_EDGE);
        while (explorer.More()) {
            edgeList.Append(explorer.Current());
            explorer.Next();
        }
        if (edgeList.IsEmpty()) return nullptr;

        // Build wires from edges, then faces from wires
        BRep_Builder builder;
        TopoDS_Compound result;
        builder.MakeCompound(result);

        // Try to build wires and faces
        TopTools_ListOfShape remainingEdges;
        remainingEdges.Assign(edgeList);
        bool anyFace = false;

        while (!remainingEdges.IsEmpty()) {
            BRepBuilderAPI_MakeWire wireBuilder;
            // Try adding edges to the wire
            bool added = true;
            while (added && !remainingEdges.IsEmpty()) {
                added = false;
                TopTools_ListIteratorOfListOfShape it(remainingEdges);
                while (it.More()) {
                    wireBuilder.Add(TopoDS::Edge(it.Value()));
                    if (wireBuilder.Error() == BRepBuilderAPI_WireDone) {
                        added = true;
                        remainingEdges.Remove(it);
                    } else {
                        wireBuilder = BRepBuilderAPI_MakeWire(wireBuilder.Wire());
                        it.Next();
                    }
                }
            }
            if (wireBuilder.IsDone()) {
                TopoDS_Wire wire = wireBuilder.Wire();
                BRepBuilderAPI_MakeFace faceBuilder(wire, isOnlyPlane);
                if (faceBuilder.IsDone()) {
                    builder.Add(result, faceBuilder.Face());
                    anyFace = true;
                }
            }
            if (!added && !remainingEdges.IsEmpty()) {
                // Can't connect more edges; start a new wire with first remaining
                TopTools_ListIteratorOfListOfShape it(remainingEdges);
                if (it.More()) {
                    remainingEdges.Remove(it);
                }
            }
        }

        if (!anyFace) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
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

// MARK: - Fuse and Blend (v0.38.0)

OCCTShapeRef OCCTShapeFuseAndBlend(OCCTShapeRef shape1, OCCTShapeRef shape2, double radius) {
    if (!shape1 || !shape2 || radius <= 0) return nullptr;
    try {
        // Step 1: Fuse
        BRepAlgoAPI_Fuse fuse(shape1->shape, shape2->shape);
        if (!fuse.IsDone()) return nullptr;

        // Step 2: Find intersection edges (edges generated/modified by the boolean)
        TopTools_ListOfShape generatedEdges;
        // Collect edges from the fuse that were generated from faces of either input
        for (TopExp_Explorer exp(shape1->shape, TopAbs_FACE); exp.More(); exp.Next()) {
            const TopTools_ListOfShape& gen = fuse.Generated(exp.Current());
            for (TopTools_ListIteratorOfListOfShape it(gen); it.More(); it.Next()) {
                if (it.Value().ShapeType() == TopAbs_EDGE) {
                    generatedEdges.Append(it.Value());
                }
            }
        }
        for (TopExp_Explorer exp(shape2->shape, TopAbs_FACE); exp.More(); exp.Next()) {
            const TopTools_ListOfShape& gen = fuse.Generated(exp.Current());
            for (TopTools_ListIteratorOfListOfShape it(gen); it.More(); it.Next()) {
                if (it.Value().ShapeType() == TopAbs_EDGE) {
                    generatedEdges.Append(it.Value());
                }
            }
        }

        // Also collect section edges (edges at the intersection of the two shapes)
        const TopoDS_Shape& fuseResult = fuse.Shape();

        // Use SectionEdges() to get the intersection edges
        const TopTools_ListOfShape& sectionEdges = fuse.SectionEdges();

        // Step 3: Fillet those edges
        BRepFilletAPI_MakeFillet fillet(fuseResult);
        // Add section edges
        for (TopTools_ListIteratorOfListOfShape it(sectionEdges); it.More(); it.Next()) {
            if (it.Value().ShapeType() == TopAbs_EDGE) {
                fillet.Add(radius, TopoDS::Edge(it.Value()));
            }
        }
        // Add generated edges
        for (TopTools_ListIteratorOfListOfShape it(generatedEdges); it.More(); it.Next()) {
            fillet.Add(radius, TopoDS::Edge(it.Value()));
        }

        if (fillet.NbContours() == 0) {
            // No edges to fillet — just return the fuse result
            return new OCCTShape(fuseResult);
        }

        fillet.Build();
        if (!fillet.IsDone()) return nullptr;
        return new OCCTShape(fillet.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCutAndBlend(OCCTShapeRef shape1, OCCTShapeRef shape2, double radius) {
    if (!shape1 || !shape2 || radius <= 0) return nullptr;
    try {
        // Step 1: Cut
        BRepAlgoAPI_Cut cut(shape1->shape, shape2->shape);
        if (!cut.IsDone()) return nullptr;

        const TopoDS_Shape& cutResult = cut.Shape();
        const TopTools_ListOfShape& sectionEdges = cut.SectionEdges();

        // Collect generated edges from faces
        TopTools_ListOfShape generatedEdges;
        for (TopExp_Explorer exp(shape1->shape, TopAbs_FACE); exp.More(); exp.Next()) {
            const TopTools_ListOfShape& gen = cut.Generated(exp.Current());
            for (TopTools_ListIteratorOfListOfShape it(gen); it.More(); it.Next()) {
                if (it.Value().ShapeType() == TopAbs_EDGE) {
                    generatedEdges.Append(it.Value());
                }
            }
        }
        for (TopExp_Explorer exp(shape2->shape, TopAbs_FACE); exp.More(); exp.Next()) {
            const TopTools_ListOfShape& gen = cut.Generated(exp.Current());
            for (TopTools_ListIteratorOfListOfShape it(gen); it.More(); it.Next()) {
                if (it.Value().ShapeType() == TopAbs_EDGE) {
                    generatedEdges.Append(it.Value());
                }
            }
        }

        // Step 2: Fillet
        BRepFilletAPI_MakeFillet fillet(cutResult);
        for (TopTools_ListIteratorOfListOfShape it(sectionEdges); it.More(); it.Next()) {
            if (it.Value().ShapeType() == TopAbs_EDGE) {
                fillet.Add(radius, TopoDS::Edge(it.Value()));
            }
        }
        for (TopTools_ListIteratorOfListOfShape it(generatedEdges); it.More(); it.Next()) {
            fillet.Add(radius, TopoDS::Edge(it.Value()));
        }

        if (fillet.NbContours() == 0) {
            return new OCCTShape(cutResult);
        }

        fillet.Build();
        if (!fillet.IsDone()) return nullptr;
        return new OCCTShape(fillet.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Multi-Edge Evolving Fillet (v0.38.0)

OCCTShapeRef OCCTShapeFilletEvolving(OCCTShapeRef shape,
                                      const int32_t* edgeIndices, int32_t edgeCount,
                                      const OCCTFilletRadiusPoint* radiusPoints,
                                      const int32_t* pointCounts) {
    if (!shape || !edgeIndices || edgeCount <= 0 || !radiusPoints || !pointCounts) return nullptr;
    try {
        TopTools_IndexedMapOfShape edgeMap;
        TopExp::MapShapes(shape->shape, TopAbs_EDGE, edgeMap);

        BRepFilletAPI_MakeFillet fillet(shape->shape);

        int rpOffset = 0;
        for (int32_t i = 0; i < edgeCount; i++) {
            int32_t edgeIdx = edgeIndices[i];
            if (edgeIdx < 1 || edgeIdx > edgeMap.Extent()) return nullptr;
            const TopoDS_Edge& edge = TopoDS::Edge(edgeMap(edgeIdx));

            fillet.Add(edge);
            int contourIndex = fillet.NbContours();

            int32_t nPts = pointCounts[i];
            if (nPts >= 2) {
                // Build array of (parameter, radius) pairs
                TColgp_Array1OfPnt2d UandR(1, nPts);
                for (int32_t j = 0; j < nPts; j++) {
                    UandR.SetValue(j + 1, gp_Pnt2d(radiusPoints[rpOffset + j].parameter,
                                                     radiusPoints[rpOffset + j].radius));
                }
                fillet.SetRadius(UandR, contourIndex, 1);
            } else if (nPts == 1) {
                fillet.SetRadius(radiusPoints[rpOffset].radius, contourIndex, 1);
            }
            rpOffset += nPts;
        }

        fillet.Build();
        if (!fillet.IsDone()) return nullptr;
        return new OCCTShape(fillet.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Per-Face Variable Offset (v0.38.0)

#include <BRepOffset_MakeOffset.hxx>

OCCTShapeRef OCCTShapeOffsetPerFace(OCCTShapeRef shape, double defaultOffset,
                                     const int32_t* faceIndices, const double* faceOffsets,
                                     int32_t faceCount, double tolerance, int32_t joinType) {
    if (!shape) return nullptr;
    try {
        TopTools_IndexedMapOfShape faceMap;
        TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);

        GeomAbs_JoinType jt = GeomAbs_Arc;
        if (joinType == 1) jt = GeomAbs_Tangent;
        else if (joinType == 2) jt = GeomAbs_Intersection;

        BRepOffset_MakeOffset offset;
        offset.Initialize(shape->shape, defaultOffset, tolerance,
                          BRepOffset_Skin, false, false, jt);

        for (int32_t i = 0; i < faceCount; i++) {
            int32_t idx = faceIndices[i];
            if (idx < 1 || idx > faceMap.Extent()) continue;
            const TopoDS_Face& face = TopoDS::Face(faceMap(idx));
            offset.SetOffsetOnFace(face, faceOffsets[i]);
        }

        offset.MakeOffsetShape();
        if (!offset.IsDone()) return nullptr;
        TopoDS_Shape result = offset.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

