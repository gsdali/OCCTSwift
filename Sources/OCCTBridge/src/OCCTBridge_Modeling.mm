//
//  OCCTBridge_Modeling.mm
//  OCCTSwift
//
//  Extracted from OCCTBridge.mm — issue #99.
//
//  Drawing + Advanced Modeling + Surfaces & Curves cluster:
//
//  - 2D Drawing / HLR projection (HLRBRep_Algo + HLRToShape, generates the
//    visible / hidden / sharp / smooth / outline edge stacks)
//  - Advanced modeling (v0.8.0): pipe shells along path, draft angle,
//    thick solid offset, defeaturing, fillet variants
//  - Surfaces & Curves (v0.9.0): BSpline surface construction, surface-of-
//    revolution / extrusion, planar face from Geom_Plane, edge length /
//    abscissa parameter helpers
//
//  These three areas live in one TU because they share a common dependency
//  set (BRepBuilderAPI primitives + Geom_BSpline + gp + TColgp), and
//  splitting them three ways would force near-duplicate header includes
//  in each file.
//
//  Public C surface unchanged. No symbol changes — pure file move.
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

// === Area-specific OCCT headers ===

#include <HLRBRep_Algo.hxx>
#include <HLRBRep_HLRToShape.hxx>
#include <HLRAlgo_Projector.hxx>

#include <BRep_Builder.hxx>
#include <BRepLib_FindSurface.hxx>
#include <Geom_Plane.hxx>
#include <BRepAdaptor_CompCurve.hxx>
#include <BRepAlgoAPI_Defeaturing.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepFill.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepOffsetAPI_DraftAngle.hxx>
#include <BRepOffsetAPI_MakePipeShell.hxx>
#include <BRepOffsetAPI_MakeThickSolid.hxx>
#include <BRepFilletAPI_MakeChamfer.hxx>
#include <BRepOffsetAPI_ThruSections.hxx>
#include <BRepOffsetAPI_MakeOffsetShape.hxx>
#include <BRepOffsetAPI_MakeOffset.hxx>
#include <BRepOffset.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_TransitionMode.hxx>
#include <BRepFeat_MakeRevolutionForm.hxx>
#include <BRepFeat_MakeDPrism.hxx>
#include <BRepFeat_MakeRevol.hxx>
#include <BRepFeat_MakePipe.hxx>
#include <BRepFeat_MakePrism.hxx>
#include <BRepFeat_SplitShape.hxx>
#include <BRepAlgoAPI_Section.hxx>
#include <BRepAlgoAPI_Check.hxx>
#include <BRepAlgoAPI_BuilderAlgo.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepPrimAPI_MakePrism.hxx>
#include <BRepProj_Projection.hxx>
#include <HLRBRep_PolyAlgo.hxx>
#include <HLRBRep_PolyHLRToShape.hxx>
#include <GeomAbs_JoinType.hxx>
#include <BRepOffsetAPI_MakeEvolved.hxx>
#include <BRepBuilderAPI_MakeSolid.hxx>
#include <BRepBuilderAPI_Sewing.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepPrimAPI_MakeRevol.hxx>
#include <Geom_Circle.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <Geom_BSplineCurve.hxx>
#include <GC_MakeArcOfCircle.hxx>
#include <GeomAPI_PointsToBSpline.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <TColStd_HArray1OfBoolean.hxx>
#include <BRepBndLib.hxx>
#include <BRepAlgoAPI_Splitter.hxx>
#include <ShapeFix_Solid.hxx>
#include <Geom_BSplineCurve.hxx>
#include <GeomAPI_Interpolate.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <gp_Ax1.hxx>
#include <Bnd_Box.hxx>
#include <TopoDS_Shell.hxx>
#include <TopoDS_Solid.hxx>
#include <TColgp_Array1OfPnt2d.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <ShapeAnalysis_FreeBounds.hxx>
#include <ShapeFix_FreeBounds.hxx>
#include <gp_Pnt2d.hxx>

#include <Geom_BSplineSurface.hxx>
#include <GCPnts_AbscissaPoint.hxx>

#include <gp_Ax2.hxx>
#include <gp_Dir.hxx>
#include <gp_Pln.hxx>
#include <gp_Pnt.hxx>
#include <gp_Trsf.hxx>
#include <gp_Vec.hxx>

#include <TColgp_Array2OfPnt.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <TColStd_Array1OfReal.hxx>

#include <TopAbs.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopLoc_Location.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>

// MARK: - 2D Drawing / HLR Projection

OCCTDrawingRef OCCTDrawingCreate(OCCTShapeRef shape, double dirX, double dirY, double dirZ, OCCTProjectionType projectionType) {
    if (!shape) return nullptr;

    try {
        // Normalize direction
        gp_Dir viewDir(dirX, dirY, dirZ);

        // Create projector
        // For orthographic: simple direction projector
        // For perspective: need a focal point
        gp_Ax2 projAxis(gp_Pnt(0, 0, 0), viewDir);
        HLRAlgo_Projector projector(projAxis);

        // Create HLR algorithm
        Handle(HLRBRep_Algo) hlrAlgo = new HLRBRep_Algo();
        hlrAlgo->Add(shape->shape);
        hlrAlgo->Projector(projector);
        hlrAlgo->Update();
        hlrAlgo->Hide();

        // Extract edges
        HLRBRep_HLRToShape shapes(hlrAlgo);

        OCCTDrawing* drawing = new OCCTDrawing();
        drawing->visibleSharp = shapes.VCompound();
        drawing->visibleSmooth = shapes.Rg1LineVCompound();
        drawing->visibleOutline = shapes.OutLineVCompound();
        drawing->hiddenSharp = shapes.HCompound();
        drawing->hiddenSmooth = shapes.Rg1LineHCompound();
        drawing->hiddenOutline = shapes.OutLineHCompound();

        return drawing;
    } catch (...) {
        return nullptr;
    }
}

void OCCTDrawingRelease(OCCTDrawingRef drawing) {
    delete drawing;
}

OCCTShapeRef OCCTDrawingGetEdges(OCCTDrawingRef drawing, OCCTEdgeType edgeType) {
    if (!drawing) return nullptr;

    try {
        TopoDS_Shape result;
        BRep_Builder builder;
        TopoDS_Compound compound;
        builder.MakeCompound(compound);

        switch (edgeType) {
            case OCCTEdgeTypeVisible:
                if (!drawing->visibleSharp.IsNull()) {
                    builder.Add(compound, drawing->visibleSharp);
                }
                if (!drawing->visibleSmooth.IsNull()) {
                    builder.Add(compound, drawing->visibleSmooth);
                }
                if (!drawing->visibleOutline.IsNull()) {
                    builder.Add(compound, drawing->visibleOutline);
                }
                break;

            case OCCTEdgeTypeHidden:
                if (!drawing->hiddenSharp.IsNull()) {
                    builder.Add(compound, drawing->hiddenSharp);
                }
                if (!drawing->hiddenSmooth.IsNull()) {
                    builder.Add(compound, drawing->hiddenSmooth);
                }
                if (!drawing->hiddenOutline.IsNull()) {
                    builder.Add(compound, drawing->hiddenOutline);
                }
                break;

            case OCCTEdgeTypeOutline:
                if (!drawing->visibleOutline.IsNull()) {
                    builder.Add(compound, drawing->visibleOutline);
                }
                if (!drawing->hiddenOutline.IsNull()) {
                    builder.Add(compound, drawing->hiddenOutline);
                }
                break;
        }

        if (compound.IsNull()) return nullptr;

        return new OCCTShape(compound);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Advanced Modeling (v0.8.0)

OCCTShapeRef OCCTShapeFilletEdges(OCCTShapeRef shape, const int32_t* edgeIndices,
                                   int32_t edgeCount, double radius) {
    if (!shape || !edgeIndices || edgeCount <= 0 || radius <= 0) return nullptr;

    try {
        BRepFilletAPI_MakeFillet fillet(shape->shape);

        // Build edge index map for lookup
        TopTools_IndexedMapOfShape edgeMap;
        TopExp::MapShapes(shape->shape, TopAbs_EDGE, edgeMap);

        for (int32_t i = 0; i < edgeCount; i++) {
            int32_t idx = edgeIndices[i];
            if (idx >= 0 && idx < edgeMap.Extent()) {
                TopoDS_Edge edge = TopoDS::Edge(edgeMap(idx + 1));  // OCCT is 1-based
                fillet.Add(radius, edge);
            }
        }

        fillet.Build();
        if (!fillet.IsDone()) return nullptr;

        return new OCCTShape(fillet.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeFilletEdgesLinear(OCCTShapeRef shape, const int32_t* edgeIndices,
                                         int32_t edgeCount, double startRadius, double endRadius) {
    if (!shape || !edgeIndices || edgeCount <= 0) return nullptr;
    if (startRadius <= 0 || endRadius <= 0) return nullptr;

    try {
        BRepFilletAPI_MakeFillet fillet(shape->shape);

        // Build edge index map for lookup
        TopTools_IndexedMapOfShape edgeMap;
        TopExp::MapShapes(shape->shape, TopAbs_EDGE, edgeMap);

        for (int32_t i = 0; i < edgeCount; i++) {
            int32_t idx = edgeIndices[i];
            if (idx >= 0 && idx < edgeMap.Extent()) {
                TopoDS_Edge edge = TopoDS::Edge(edgeMap(idx + 1));  // OCCT is 1-based
                // Add edge with variable radius
                fillet.Add(edge);
                // Set radius variation along the edge
                int contourIndex = fillet.NbContours();
                fillet.SetRadius(startRadius, endRadius, contourIndex, 1);
            }
        }

        fillet.Build();
        if (!fillet.IsDone()) return nullptr;

        return new OCCTShape(fillet.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeDraft(OCCTShapeRef shape, const int32_t* faceIndices, int32_t faceCount,
                            double dirX, double dirY, double dirZ, double angle,
                            double planeX, double planeY, double planeZ,
                            double planeNx, double planeNy, double planeNz) {
    if (!shape || !faceIndices || faceCount <= 0) return nullptr;

    try {
        // Pull direction (typically vertical for mold release)
        gp_Dir pullDir(dirX, dirY, dirZ);

        // Neutral plane - where draft angle is measured from
        gp_Pnt planePoint(planeX, planeY, planeZ);
        gp_Dir planeNormal(planeNx, planeNy, planeNz);
        gp_Pln neutralPlane(planePoint, planeNormal);

        BRepOffsetAPI_DraftAngle draft(shape->shape);

        // Build face index map
        TopTools_IndexedMapOfShape faceMap;
        TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);

        for (int32_t i = 0; i < faceCount; i++) {
            int32_t idx = faceIndices[i];
            if (idx >= 0 && idx < faceMap.Extent()) {
                TopoDS_Face face = TopoDS::Face(faceMap(idx + 1));
                draft.Add(face, pullDir, angle, neutralPlane);
            }
        }

        draft.Build();
        if (!draft.IsDone()) return nullptr;

        return new OCCTShape(draft.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeRemoveFeatures(OCCTShapeRef shape, const int32_t* faceIndices, int32_t faceCount) {
    if (!shape || !faceIndices || faceCount <= 0) return nullptr;

    try {
        BRepAlgoAPI_Defeaturing defeature;
        defeature.SetShape(shape->shape);

        // Build face index map
        TopTools_IndexedMapOfShape faceMap;
        TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);

        for (int32_t i = 0; i < faceCount; i++) {
            int32_t idx = faceIndices[i];
            if (idx >= 0 && idx < faceMap.Extent()) {
                TopoDS_Face face = TopoDS::Face(faceMap(idx + 1));
                defeature.AddFaceToRemove(face);
            }
        }

        defeature.Build();
        if (!defeature.IsDone()) return nullptr;

        return new OCCTShape(defeature.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreatePipeShell(OCCTWireRef spine, OCCTWireRef profile,
                                       OCCTPipeMode mode, bool solid) {
    if (!spine || !profile) return nullptr;

    try {
        BRepOffsetAPI_MakePipeShell pipeShell(spine->wire);

        // Set sweep mode
        switch (mode) {
            case OCCTPipeModeFrenet:
                pipeShell.SetMode(Standard_False);  // Frenet
                break;
            case OCCTPipeModeCorrectedFrenet:
                pipeShell.SetMode(Standard_True);   // Corrected Frenet
                break;
            case OCCTPipeModeFixedBinormal:
            case OCCTPipeModeAuxiliary:
                // These modes require additional parameters
                // Use dedicated functions for them
                pipeShell.SetMode(Standard_False);
                break;
        }

        // Add profile
        pipeShell.Add(profile->wire);

        // Build the shell
        pipeShell.SetIsBuildHistory(false); // avoid SEGV on closed spine+profile (OCCT bug)
        pipeShell.Build();
        if (!pipeShell.IsDone()) return nullptr;

        TopoDS_Shape result = pipeShell.Shape();

        // Make solid if requested
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

OCCTShapeRef OCCTShapeCreatePipeShellWithBinormal(OCCTWireRef spine, OCCTWireRef profile,
                                                   double bnX, double bnY, double bnZ, bool solid) {
    if (!spine || !profile) return nullptr;

    try {
        BRepOffsetAPI_MakePipeShell pipeShell(spine->wire);

        // Set fixed binormal direction
        gp_Dir binormal(bnX, bnY, bnZ);
        pipeShell.SetMode(binormal);

        // Add profile
        pipeShell.Add(profile->wire);

        // Build the shell
        pipeShell.SetIsBuildHistory(false); // avoid SEGV on closed spine+profile (OCCT bug)
        pipeShell.Build();
        if (!pipeShell.IsDone()) return nullptr;

        TopoDS_Shape result = pipeShell.Shape();

        // Make solid if requested
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

OCCTShapeRef OCCTShapeCreatePipeShellWithAuxSpine(OCCTWireRef spine, OCCTWireRef profile,
                                                   OCCTWireRef auxSpine, bool solid) {
    if (!spine || !profile || !auxSpine) return nullptr;

    try {
        BRepOffsetAPI_MakePipeShell pipeShell(spine->wire);

        // Set auxiliary spine for twist control
        pipeShell.SetMode(auxSpine->wire, Standard_False);  // curvilinear equivalence = false

        // Add profile
        pipeShell.Add(profile->wire);

        // Build the shell
        pipeShell.SetIsBuildHistory(false); // avoid SEGV on closed spine+profile (OCCT bug)
        pipeShell.Build();
        if (!pipeShell.IsDone()) return nullptr;

        TopoDS_Shape result = pipeShell.Shape();

        // Make solid if requested
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

// MARK: - Surface Construction (v0.9.0)

OCCTShapeRef OCCTShapeCreateBSplineSurface(const double* poles, int32_t uCount, int32_t vCount,
                                            int32_t uDegree, int32_t vDegree) {
    if (!poles || uCount < 2 || vCount < 2) return nullptr;
    if (uDegree < 1 || vDegree < 1) return nullptr;
    if (uCount < uDegree + 1 || vCount < vDegree + 1) return nullptr;

    try {
        // Create 2D array of control points (1-indexed for OCCT)
        TColgp_Array2OfPnt polesArray(1, uCount, 1, vCount);

        for (int32_t u = 0; u < uCount; u++) {
            for (int32_t v = 0; v < vCount; v++) {
                int32_t idx = (u * vCount + v) * 3;
                polesArray.SetValue(u + 1, v + 1, gp_Pnt(poles[idx], poles[idx + 1], poles[idx + 2]));
            }
        }

        // Create uniform clamped knot vectors
        int32_t uKnotCount = uCount - uDegree + 1;
        int32_t vKnotCount = vCount - vDegree + 1;

        TColStd_Array1OfReal uKnots(1, uKnotCount);
        TColStd_Array1OfReal vKnots(1, vKnotCount);
        TColStd_Array1OfInteger uMults(1, uKnotCount);
        TColStd_Array1OfInteger vMults(1, vKnotCount);

        // Uniform knot values
        for (int32_t i = 1; i <= uKnotCount; i++) {
            uKnots.SetValue(i, (double)(i - 1) / (uKnotCount - 1));
            uMults.SetValue(i, (i == 1 || i == uKnotCount) ? uDegree + 1 : 1);
        }
        for (int32_t i = 1; i <= vKnotCount; i++) {
            vKnots.SetValue(i, (double)(i - 1) / (vKnotCount - 1));
            vMults.SetValue(i, (i == 1 || i == vKnotCount) ? vDegree + 1 : 1);
        }

        // Create B-spline surface
        Handle(Geom_BSplineSurface) surface = new Geom_BSplineSurface(
            polesArray,
            uKnots, vKnots,
            uMults, vMults,
            uDegree, vDegree
        );

        if (surface.IsNull()) return nullptr;

        // Create face from surface
        BRepBuilderAPI_MakeFace faceMaker(surface, 1e-6);
        if (!faceMaker.IsDone()) return nullptr;

        return new OCCTShape(faceMaker.Face());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateRuled(OCCTWireRef wire1, OCCTWireRef wire2) {
    if (!wire1 || !wire2) return nullptr;

    try {
        // Use BRepFill::Face to create a ruled surface between two edges/wires
        TopoDS_Shape result = BRepFill::Shell(wire1->wire, wire2->wire);

        if (result.IsNull()) return nullptr;

        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeShellWithOpenFaces(OCCTShapeRef shape, double thickness,
                                          const int32_t* openFaceIndices, int32_t faceCount) {
    if (!shape || !openFaceIndices || faceCount < 1) return nullptr;

    try {
        // Get indexed map of faces
        TopTools_IndexedMapOfShape faceMap;
        TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);

        // Build list of faces to remove (open faces)
        TopTools_ListOfShape facesToRemove;
        for (int32_t i = 0; i < faceCount; i++) {
            int32_t idx = openFaceIndices[i];
            if (idx >= 0 && idx < faceMap.Extent()) {
                facesToRemove.Append(faceMap(idx + 1));  // 1-based indexing
            }
        }

        if (facesToRemove.IsEmpty()) return nullptr;

        // Create thick solid (shell) with open faces
        BRepOffsetAPI_MakeThickSolid thickSolid;
        thickSolid.MakeThickSolidByJoin(shape->shape, facesToRemove, thickness, 1e-6);

        if (!thickSolid.IsDone()) return nullptr;

        return new OCCTShape(thickSolid.Shape());
    } catch (...) {
        return nullptr;
    }
}


// MARK: - Helix Curves (v0.28.0)

#include <HelixBRep_BuilderHelix.hxx>

OCCTWireRef OCCTWireCreateHelix(double originX, double originY, double originZ,
                                 double axisX, double axisY, double axisZ,
                                 double radius, double pitch, double turns,
                                 bool clockwise) {
    try {
        gp_Pnt origin(originX, originY, originZ);
        gp_Dir dir(axisX, axisY, axisZ);
        if (!clockwise) dir.Reverse();
        gp_Ax3 axis(origin, dir);

        double diameter = radius * 2.0;

        NCollection_Array1<double> pitchArr(1, 1);
        pitchArr.SetValue(1, pitch);
        NCollection_Array1<double> nbTurnsArr(1, 1);
        nbTurnsArr.SetValue(1, turns);

        HelixBRep_BuilderHelix builder;
        builder.SetParameters(axis, diameter, pitchArr, nbTurnsArr);
        builder.Perform();

        if (builder.ErrorStatus() != 0) return nullptr;

        const TopoDS_Shape& shape = builder.Shape();
        if (shape.IsNull()) return nullptr;

        return new OCCTWire(TopoDS::Wire(shape));
    } catch (...) {
        return nullptr;
    }
}

OCCTWireRef OCCTWireCreateHelixTapered(double originX, double originY, double originZ,
                                        double axisX, double axisY, double axisZ,
                                        double startRadius, double endRadius,
                                        double pitch, double turns,
                                        bool clockwise) {
    try {
        gp_Pnt origin(originX, originY, originZ);
        gp_Dir dir(axisX, axisY, axisZ);
        if (!clockwise) dir.Reverse();
        gp_Ax3 axis(origin, dir);

        double startDiam = startRadius * 2.0;
        double endDiam = endRadius * 2.0;

        NCollection_Array1<double> pitchArr(1, 1);
        pitchArr.SetValue(1, pitch);
        NCollection_Array1<double> nbTurnsArr(1, 1);
        nbTurnsArr.SetValue(1, turns);

        HelixBRep_BuilderHelix builder;
        builder.SetParameters(axis, startDiam, endDiam, pitchArr, nbTurnsArr);
        builder.Perform();

        if (builder.ErrorStatus() != 0) return nullptr;

        const TopoDS_Shape& shape = builder.Shape();
        if (shape.IsNull()) return nullptr;

        return new OCCTWire(TopoDS::Wire(shape));
    } catch (...) {
        return nullptr;
    }
}
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

// MARK: - Non-Uniform Transform (v0.30.0)

#include <BRepBuilderAPI_GTransform.hxx>
#include <gp_GTrsf.hxx>
#include <gp_Mat.hxx>

OCCTShapeRef OCCTShapeNonUniformScale(OCCTShapeRef shape, double sx, double sy, double sz) {
    if (!shape) return nullptr;
    try {
        gp_GTrsf gtrsf;
        gtrsf.SetVectorialPart(gp_Mat(sx, 0, 0, 0, sy, 0, 0, 0, sz));
        BRepBuilderAPI_GTransform builder(shape->shape, gtrsf, true);
        if (!builder.IsDone()) return nullptr;
        return new OCCTShape(builder.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Make Shell (v0.30.0)

#include <BRepBuilderAPI_MakeShell.hxx>

OCCTShapeRef OCCTShapeCreateShellFromSurface(OCCTSurfaceRef surface) {
    if (!surface || surface->surface.IsNull()) return nullptr;
    try {
        BRepBuilderAPI_MakeShell builder(surface->surface);
        if (!builder.IsDone()) return nullptr;
        return new OCCTShape(builder.Shell());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Make Vertex (v0.30.0)

#include <BRepBuilderAPI_MakeVertex.hxx>

OCCTShapeRef OCCTShapeCreateVertex(double x, double y, double z) {
    try {
        BRepBuilderAPI_MakeVertex builder(gp_Pnt(x, y, z));
        if (!builder.IsDone()) return nullptr;
        return new OCCTShape(builder.Vertex());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Simple Offset (v0.30.0)

#include <BRepOffset_MakeSimpleOffset.hxx>

OCCTShapeRef OCCTShapeSimpleOffset(OCCTShapeRef shape, double offsetValue) {
    if (!shape) return nullptr;
    try {
        BRepOffset_MakeSimpleOffset builder(shape->shape, offsetValue);
        builder.SetBuildSolidFlag(true);
        builder.Perform();
        if (!builder.IsDone()) return nullptr;
        return new OCCTShape(builder.GetResultShape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Middle Path (v0.30.0)

#include <BRepOffsetAPI_MiddlePath.hxx>

OCCTShapeRef OCCTShapeMiddlePath(OCCTShapeRef shape, OCCTShapeRef startShape, OCCTShapeRef endShape) {
    if (!shape || !startShape || !endShape) return nullptr;
    try {
        BRepOffsetAPI_MiddlePath builder(shape->shape, startShape->shape, endShape->shape);
        builder.Build();
        if (!builder.IsDone()) return nullptr;
        return new OCCTShape(builder.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Fuse Edges (v0.30.0)

#include <BRepLib_FuseEdges.hxx>

OCCTShapeRef OCCTShapeFuseEdges(OCCTShapeRef shape) {
    if (!shape) return nullptr;
    try {
        BRepLib_FuseEdges fuser(shape->shape);
        fuser.Perform();
        return new OCCTShape(fuser.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Maker Volume (v0.30.0)

#include <BOPAlgo_MakerVolume.hxx>

OCCTShapeRef OCCTShapeMakeVolume(OCCTShapeRef* shapes, int32_t count) {
    if (!shapes || count <= 0) return nullptr;
    try {
        BOPAlgo_MakerVolume maker;
        for (int32_t i = 0; i < count; i++) {
            if (!shapes[i]) return nullptr;
            maker.AddArgument(shapes[i]->shape);
        }
        maker.Perform();
        if (maker.HasErrors()) return nullptr;
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Make Connected (v0.30.0)

#include <BOPAlgo_MakeConnected.hxx>

OCCTShapeRef OCCTShapeMakeConnected(OCCTShapeRef* shapes, int32_t count) {
    if (!shapes || count <= 0) return nullptr;
    try {
        BOPAlgo_MakeConnected maker;
        for (int32_t i = 0; i < count; i++) {
            if (!shapes[i]) return nullptr;
            maker.AddArgument(shapes[i]->shape);
        }
        maker.Perform();
        if (maker.HasErrors()) return nullptr;
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Quilt Faces (v0.31.0)

#include <BRepTools_Quilt.hxx>

OCCTShapeRef OCCTShapeQuilt(OCCTShapeRef* shapes, int32_t count) {
    if (!shapes || count <= 0) return nullptr;
    try {
        BRepTools_Quilt quilt;
        for (int32_t i = 0; i < count; i++) {
            if (!shapes[i]) return nullptr;
            quilt.Add(shapes[i]->shape);
        }
        TopoDS_Shape result = quilt.Shells();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Revolution from Curve (v0.31.0)

#include <BRepPrimAPI_MakeRevolution.hxx>

OCCTShapeRef OCCTShapeCreateRevolutionFromCurve(OCCTCurve3DRef meridian,
                                                 double axOX, double axOY, double axOZ,
                                                 double axDX, double axDY, double axDZ,
                                                 double angle) {
    if (!meridian || meridian->curve.IsNull()) return nullptr;
    try {
        gp_Ax2 axes(gp_Pnt(axOX, axOY, axOZ), gp_Dir(axDX, axDY, axDZ));
        BRepPrimAPI_MakeRevolution maker(axes, meridian->curve, angle);
        maker.Build();
        if (!maker.IsDone()) return nullptr;
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Linear Rib Feature (v0.31.0)

#include <BRepFeat_MakeLinearForm.hxx>

OCCTShapeRef OCCTShapeAddLinearRib(OCCTShapeRef shape, OCCTWireRef profile,
                                    double dirX, double dirY, double dirZ,
                                    double dir1X, double dir1Y, double dir1Z,
                                    bool fuse) {
    if (!shape || !profile) return nullptr;
    try {
        BRepLib_FindSurface finder(profile->wire);
        if (!finder.Found()) return nullptr;
        Handle(Geom_Plane) plane = Handle(Geom_Plane)::DownCast(finder.Surface());
        if (plane.IsNull()) return nullptr;
        gp_Vec dir(dirX, dirY, dirZ);
        gp_Vec dir1(dir1X, dir1Y, dir1Z);
        BRepFeat_MakeLinearForm maker(shape->shape, profile->wire, plane, dir, dir1,
                                       fuse ? 1 : 0, false);
        maker.Perform();
        if (!maker.IsDone()) return nullptr;
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

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

// MARK: - Shape-to-Shape Section (v0.34.0)

#include <BRepAlgoAPI_Section.hxx>

OCCTShapeRef OCCTShapeSection(OCCTShapeRef shape1, OCCTShapeRef shape2) {
    if (!shape1 || !shape2) return nullptr;
    try {
        BRepAlgoAPI_Section section(shape1->shape, shape2->shape, Standard_False);
        section.ComputePCurveOn1(Standard_True);
        section.Approximation(Standard_True);
        section.Build();
        if (!section.IsDone()) return nullptr;
        TopoDS_Shape result = section.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Boolean Pre-Validation (v0.34.0)

#include <BRepAlgoAPI_Check.hxx>

bool OCCTShapeBooleanCheck(OCCTShapeRef shape1, OCCTShapeRef shape2) {
    if (!shape1) return false;
    try {
        if (shape2) {
            BRepAlgoAPI_Check checker(shape1->shape, shape2->shape);
            return checker.IsValid();
        } else {
            BRepAlgoAPI_Check checker(shape1->shape);
            return checker.IsValid();
        }
    } catch (...) {
        return false;
    }
}

// MARK: - Split Shape by Wire (v0.34.0)

#include <BRepFeat_SplitShape.hxx>

OCCTShapeRef OCCTShapeSplitByWire(OCCTShapeRef shape, OCCTWireRef wire, int32_t faceIndex) {
    if (!shape || !wire) return nullptr;
    try {
        TopTools_IndexedMapOfShape faceMap;
        TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);
        int32_t idx = faceIndex + 1; // Convert 0-based to 1-based
        if (idx < 1 || idx > faceMap.Extent()) return nullptr;
        TopoDS_Face face = TopoDS::Face(faceMap(idx));
        BRepFeat_SplitShape splitter(shape->shape);
        splitter.Add(wire->wire, face);
        splitter.Build();
        if (!splitter.IsDone()) return nullptr;
        TopoDS_Shape result = splitter.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Multi-Tool Boolean Fuse (v0.34.0)

#include <BRepAlgoAPI_BuilderAlgo.hxx>

OCCTShapeRef OCCTShapeFuseMulti(const OCCTShapeRef* shapes, int32_t count) {
    if (!shapes || count < 2) return nullptr;
    try {
        TopTools_ListOfShape arguments;
        for (int32_t i = 0; i < count; ++i) {
            if (!shapes[i]) return nullptr;
            arguments.Append(shapes[i]->shape);
        }
        BRepAlgoAPI_BuilderAlgo builder;
        builder.SetArguments(arguments);
        builder.SetRunParallel(Standard_True);
        builder.Build();
        if (!builder.IsDone()) return nullptr;
        TopoDS_Shape result = builder.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Multi-Offset Wire (v0.35.0)

#include <BRepOffsetAPI_MakeOffset.hxx>

int32_t OCCTWireMultiOffset(OCCTShapeRef face, const double* offsets, int32_t count,
                             int32_t joinType, OCCTWireRef* outWires, int32_t maxWires) {
    if (!face || !offsets || count < 1 || !outWires || maxWires < 1) return 0;
    try {
        // Extract the face from the shape
        TopTools_IndexedMapOfShape faceMap;
        TopExp::MapShapes(face->shape, TopAbs_FACE, faceMap);
        if (faceMap.Extent() < 1) return 0;
        TopoDS_Face topoFace = TopoDS::Face(faceMap(1));

        GeomAbs_JoinType join = GeomAbs_Arc;
        if (joinType == 1) join = GeomAbs_Tangent;
        else if (joinType == 2) join = GeomAbs_Intersection;

        BRepOffsetAPI_MakeOffset offsetMaker(topoFace, join);

        int32_t totalWires = 0;
        for (int32_t i = 0; i < count && totalWires < maxWires; ++i) {
            offsetMaker.Perform(offsets[i]);
            if (!offsetMaker.IsDone()) continue;
            TopoDS_Shape result = offsetMaker.Shape();
            // Extract wires from the result
            TopExp_Explorer wireExp(result, TopAbs_WIRE);
            while (wireExp.More() && totalWires < maxWires) {
                outWires[totalWires] = new OCCTWire(TopoDS::Wire(wireExp.Current()));
                totalWires++;
                wireExp.Next();
            }
        }
        return totalWires;
    } catch (...) {
        return 0;
    }
}

// MARK: - Cylindrical Projection (v0.35.0)

#include <BRepProj_Projection.hxx>

OCCTShapeRef OCCTShapeProjectWire(OCCTShapeRef wire, OCCTShapeRef shape,
                                   double dirX, double dirY, double dirZ) {
    if (!wire || !shape) return nullptr;
    try {
        gp_Dir direction(dirX, dirY, dirZ);
        BRepProj_Projection projection(wire->shape, shape->shape, direction);
        if (!projection.IsDone()) return nullptr;
        TopoDS_Compound result = projection.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Conical Projection (v0.36.0)

OCCTShapeRef OCCTShapeProjectWireConical(OCCTShapeRef wire, OCCTShapeRef shape,
                                          double eyeX, double eyeY, double eyeZ) {
    if (!wire || !shape) return nullptr;
    try {
        gp_Pnt eye(eyeX, eyeY, eyeZ);
        BRepProj_Projection projection(wire->shape, shape->shape, eye);
        if (!projection.IsDone()) return nullptr;
        TopoDS_Compound result = projection.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Boolean with Modified Shapes (v0.36.0)

#include <BRepAlgoAPI_Fuse.hxx>

int32_t OCCTShapeFuseWithHistory(OCCTShapeRef shape1, OCCTShapeRef shape2,
                                  OCCTShapeRef* outModified, int32_t maxModified) {
    if (!shape1 || !shape2 || !outModified || maxModified < 1) return -1;
    try {
        BRepAlgoAPI_Fuse fuse(shape1->shape, shape2->shape);
        if (!fuse.IsDone()) return -1;
        // Collect modified shapes from shape1's faces
        int32_t count = 0;
        TopExp_Explorer explorer(shape1->shape, TopAbs_FACE);
        while (explorer.More() && count < maxModified) {
            const TopTools_ListOfShape& modified = fuse.Modified(explorer.Current());
            TopTools_ListIteratorOfListOfShape it(modified);
            while (it.More() && count < maxModified) {
                outModified[count] = new OCCTShape(it.Value());
                count++;
                it.Next();
            }
            explorer.Next();
        }
        return count;
    } catch (...) {
        return -1;
    }
}

// MARK: - Thick Solid / Hollowing (v0.37.0)

#include <BRepOffsetAPI_MakeThickSolid.hxx>

OCCTShapeRef OCCTShapeMakeThickSolid(OCCTShapeRef shape, const int32_t* faceIndices,
                                      int32_t faceCount, double offset, double tolerance,
                                      int32_t joinType) {
    if (!shape || !faceIndices || faceCount < 1) return nullptr;
    try {
        TopTools_IndexedMapOfShape faceMap;
        TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);

        TopTools_ListOfShape closingFaces;
        for (int32_t i = 0; i < faceCount; ++i) {
            int32_t idx = faceIndices[i] + 1; // 0-based to 1-based
            if (idx < 1 || idx > faceMap.Extent()) return nullptr;
            closingFaces.Append(faceMap(idx));
        }

        GeomAbs_JoinType join = GeomAbs_Arc;
        if (joinType == 1) join = GeomAbs_Tangent;
        else if (joinType == 2) join = GeomAbs_Intersection;

        BRepOffsetAPI_MakeThickSolid maker;
        maker.MakeThickSolidByJoin(shape->shape, closingFaces, offset, tolerance,
                                    BRepOffset_Skin, false, false, join);
        maker.Build();
        if (!maker.IsDone()) return nullptr;
        TopoDS_Shape result = maker.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Shell from Surface (v0.37.0)

#include <BRepBuilderAPI_MakeShell.hxx>

OCCTShapeRef OCCTShapeMakeShell(OCCTSurfaceRef surface,
                                 double uMin, double uMax,
                                 double vMin, double vMax) {
    if (!surface || surface->surface.IsNull()) return nullptr;
    try {
        BRepBuilderAPI_MakeShell maker(surface->surface, uMin, uMax, vMin, vMax);
        if (!maker.IsDone()) return nullptr;
        TopoDS_Shell shell = maker.Shell();
        if (shell.IsNull()) return nullptr;
        return new OCCTShape(shell);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Multi-Tool Boolean Common (v0.37.0)

#include <BRepAlgoAPI_Common.hxx>

OCCTShapeRef OCCTShapeCommonMulti(const OCCTShapeRef* shapes, int32_t count) {
    if (!shapes || count < 2) return nullptr;
    try {
        // Start with the common of first two shapes, then iteratively intersect with rest
        for (int32_t i = 0; i < count; ++i) {
            if (!shapes[i]) return nullptr;
        }
        TopoDS_Shape result = shapes[0]->shape;
        for (int32_t i = 1; i < count; ++i) {
            BRepAlgoAPI_Common common(result, shapes[i]->shape);
            if (!common.IsDone()) return nullptr;
            result = common.Shape();
            if (result.IsNull()) return nullptr;
        }
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

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

OCCTDrawingRef OCCTDrawingCreatePoly(OCCTShapeRef shape,
                                      double dirX, double dirY, double dirZ,
                                      int32_t projectionType, double deflection) {
    if (!shape) return nullptr;
    try {
        // Ensure the shape has a triangulation
        BRepMesh_IncrementalMesh mesh(shape->shape, deflection);

        gp_Dir viewDir(dirX, dirY, dirZ);
        gp_Ax2 projAxis(gp_Pnt(0, 0, 0), viewDir);
        HLRAlgo_Projector projector(projAxis);

        Handle(HLRBRep_PolyAlgo) polyAlgo = new HLRBRep_PolyAlgo();
        polyAlgo->Projector(projector);
        polyAlgo->Load(shape->shape);
        polyAlgo->Update();

        HLRBRep_PolyHLRToShape shapes;
        shapes.Update(polyAlgo);

        OCCTDrawing* drawing = new OCCTDrawing();
        drawing->visibleSharp = shapes.VCompound();
        drawing->visibleSmooth = shapes.Rg1LineVCompound();
        drawing->visibleOutline = shapes.OutLineVCompound();
        drawing->hiddenSharp = shapes.HCompound();
        drawing->hiddenSmooth = shapes.Rg1LineHCompound();
        drawing->hiddenOutline = shapes.OutLineHCompound();

        return drawing;
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapePipeFeature(OCCTShapeRef shape, int32_t profileFaceIndex,
                                   int32_t sketchFaceIndex, OCCTWireRef spine,
                                   int32_t fuse) {
    if (!shape || !spine) return nullptr;
    try {
        TopTools_IndexedMapOfShape faceMap;
        TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);

        int32_t profIdx = profileFaceIndex + 1;
        int32_t sketchIdx = sketchFaceIndex + 1;
        if (profIdx < 1 || profIdx > faceMap.Extent()) return nullptr;
        if (sketchIdx < 1 || sketchIdx > faceMap.Extent()) return nullptr;

        TopoDS_Face profileFace = TopoDS::Face(faceMap(profIdx));
        TopoDS_Face sketchFace = TopoDS::Face(faceMap(sketchIdx));

        BRepFeat_MakePipe maker(shape->shape, profileFace, sketchFace,
                                 spine->wire, fuse, true);
        maker.Perform();
        if (!maker.IsDone()) return nullptr;

        TopoDS_Shape result = maker.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapePipeFeatureFromProfile(OCCTShapeRef baseShape, OCCTShapeRef profileShape,
                                              int32_t sketchFaceIndex, OCCTWireRef spine,
                                              int32_t fuse) {
    if (!baseShape || !profileShape || !spine) return nullptr;
    try {
        TopTools_IndexedMapOfShape faceMap;
        TopExp::MapShapes(baseShape->shape, TopAbs_FACE, faceMap);

        int32_t sketchIdx = sketchFaceIndex + 1;
        if (sketchIdx < 1 || sketchIdx > faceMap.Extent()) return nullptr;

        TopoDS_Face sketchFace = TopoDS::Face(faceMap(sketchIdx));

        BRepFeat_MakePipe maker(baseShape->shape, profileShape->shape, sketchFace,
                                 spine->wire, fuse, true);
        maker.Perform();
        if (!maker.IsDone()) return nullptr;

        TopoDS_Shape result = maker.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeExtrudeSemiInfinite(OCCTShapeRef profile,
                                           double dirX, double dirY, double dirZ,
                                           bool semiInfinite) {
    if (!profile) return nullptr;
    try {
        gp_Dir dir(dirX, dirY, dirZ);
        BRepPrimAPI_MakePrism maker(profile->shape, dir,
                                     !semiInfinite);
        maker.Build();
        if (!maker.IsDone()) return nullptr;
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapePrismUntilFace(OCCTShapeRef baseShape, OCCTShapeRef profileShape,
                                      int32_t sketchFaceIndex,
                                      double dirX, double dirY, double dirZ,
                                      int32_t fuse, int32_t untilFaceIndex) {
    if (!baseShape || !profileShape) return nullptr;
    try {
        TopTools_IndexedMapOfShape faceMap;
        TopExp::MapShapes(baseShape->shape, TopAbs_FACE, faceMap);

        int32_t sketchIdx = sketchFaceIndex + 1;
        if (sketchIdx < 1 || sketchIdx > faceMap.Extent()) return nullptr;

        TopoDS_Face sketchFace = TopoDS::Face(faceMap(sketchIdx));
        gp_Dir dir(dirX, dirY, dirZ);

        BRepFeat_MakePrism maker(baseShape->shape, profileShape->shape,
                                  sketchFace, dir, fuse, true);

        if (untilFaceIndex < 0) {
            // Thru-all
            maker.PerformThruAll();
        } else {
            int32_t untilIdx = untilFaceIndex + 1;
            if (untilIdx < 1 || untilIdx > faceMap.Extent()) return nullptr;
            TopoDS_Face untilFace = TopoDS::Face(faceMap(untilIdx));
            maker.Perform(untilFace);
        }

        if (!maker.IsDone()) return nullptr;
        TopoDS_Shape result = maker.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}
// MARK: - Geometry Construction (v0.11.0)

OCCTShapeRef OCCTShapeCreateFaceFromWire(OCCTWireRef wire, bool planar) {
    if (!wire) return nullptr;

    try {
        BRepBuilderAPI_MakeFace makeFace(wire->wire, planar);
        if (!makeFace.IsDone()) {
            return nullptr;
        }

        TopoDS_Face face = makeFace.Face();
        if (face.IsNull()) return nullptr;

        return new OCCTShape(face);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateFaceWithHoles(OCCTWireRef outer, const OCCTWireRef* holes, int32_t holeCount) {
    if (!outer) return nullptr;

    try {
        // First create face from outer wire
        BRepBuilderAPI_MakeFace makeFace(outer->wire, true);  // planar
        if (!makeFace.IsDone()) {
            return nullptr;
        }

        // Add holes (inner wires)
        for (int32_t i = 0; i < holeCount; i++) {
            if (holes[i]) {
                // Inner wires must be reversed to represent holes
                TopoDS_Wire reversed = TopoDS::Wire(holes[i]->wire.Reversed());
                makeFace.Add(reversed);
            }
        }

        if (!makeFace.IsDone()) {
            return nullptr;
        }

        TopoDS_Face face = makeFace.Face();
        if (face.IsNull()) return nullptr;

        return new OCCTShape(face);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateSolidFromShell(OCCTShapeRef shell) {
    if (!shell) return nullptr;

    try {
        // Extract shell from shape
        TopoDS_Shell topoShell;
        if (shell->shape.ShapeType() == TopAbs_SHELL) {
            topoShell = TopoDS::Shell(shell->shape);
        } else {
            // Try to find a shell in the shape
            TopExp_Explorer exp(shell->shape, TopAbs_SHELL);
            if (exp.More()) {
                topoShell = TopoDS::Shell(exp.Current());
            } else {
                return nullptr;
            }
        }

        BRepBuilderAPI_MakeSolid makeSolid(topoShell);
        if (!makeSolid.IsDone()) {
            return nullptr;
        }

        TopoDS_Solid solid = makeSolid.Solid();
        if (solid.IsNull()) return nullptr;

        // Optionally fix the solid orientation
        ShapeFix_Solid fixer(solid);
        fixer.Perform();
        TopoDS_Shape fixedShape = fixer.Solid();
        if (fixedShape.IsNull() || fixedShape.ShapeType() != TopAbs_SOLID) {
            return new OCCTShape(solid);  // Return original if fix failed
        }

        return new OCCTShape(TopoDS::Solid(fixedShape));
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeSew(const OCCTShapeRef* shapes, int32_t count, double tolerance) {
    if (!shapes || count < 1) return nullptr;

    try {
        BRepBuilderAPI_Sewing sewing(tolerance);

        for (int32_t i = 0; i < count; i++) {
            if (shapes[i]) {
                sewing.Add(shapes[i]->shape);
            }
        }

        sewing.Perform();
        TopoDS_Shape sewn = sewing.SewedShape();

        if (sewn.IsNull()) return nullptr;

        // Try to make a solid if we got a closed shell
        if (sewn.ShapeType() == TopAbs_SHELL) {
            TopoDS_Shell shell = TopoDS::Shell(sewn);
            if (shell.Closed()) {
                BRepBuilderAPI_MakeSolid makeSolid(shell);
                if (makeSolid.IsDone()) {
                    return new OCCTShape(makeSolid.Solid());
                }
            }
        }

        return new OCCTShape(sewn);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeSewTwo(OCCTShapeRef shape1, OCCTShapeRef shape2, double tolerance) {
    if (!shape1 || !shape2) return nullptr;

    OCCTShapeRef shapes[2] = { shape1, shape2 };
    return OCCTShapeSew(shapes, 2, tolerance);
}

OCCTWireRef OCCTWireInterpolate(const double* points, int32_t count, bool closed, double tolerance) {
    if (!points || count < 2) return nullptr;

    try {
        // Build array of points
        Handle(TColgp_HArray1OfPnt) hPoints = new TColgp_HArray1OfPnt(1, count);
        for (int32_t i = 0; i < count; i++) {
            hPoints->SetValue(i + 1, gp_Pnt(points[i*3], points[i*3+1], points[i*3+2]));
        }

        // Create interpolator
        GeomAPI_Interpolate interpolator(hPoints, closed, tolerance);
        interpolator.Perform();

        if (!interpolator.IsDone()) {
            return nullptr;
        }

        Handle(Geom_BSplineCurve) curve = interpolator.Curve();
        if (curve.IsNull()) return nullptr;

        // Create edge from curve
        BRepBuilderAPI_MakeEdge makeEdge(curve);
        if (!makeEdge.IsDone()) return nullptr;

        // Create wire from edge
        BRepBuilderAPI_MakeWire makeWire(makeEdge.Edge());
        if (!makeWire.IsDone()) return nullptr;

        return new OCCTWire(makeWire.Wire());
    } catch (...) {
        return nullptr;
    }
}

OCCTWireRef OCCTWireInterpolateWithTangents(const double* points, int32_t count,
                                             double startTanX, double startTanY, double startTanZ,
                                             double endTanX, double endTanY, double endTanZ,
                                             double tolerance) {
    if (!points || count < 2) return nullptr;

    try {
        // Build array of points
        Handle(TColgp_HArray1OfPnt) hPoints = new TColgp_HArray1OfPnt(1, count);
        for (int32_t i = 0; i < count; i++) {
            hPoints->SetValue(i + 1, gp_Pnt(points[i*3], points[i*3+1], points[i*3+2]));
        }

        // Create interpolator (not closed since we have tangent constraints)
        GeomAPI_Interpolate interpolator(hPoints, Standard_False, tolerance);

        // Set tangent constraints
        gp_Vec startTangent(startTanX, startTanY, startTanZ);
        gp_Vec endTangent(endTanX, endTanY, endTanZ);
        interpolator.Load(startTangent, endTangent);

        interpolator.Perform();

        if (!interpolator.IsDone()) {
            return nullptr;
        }

        Handle(Geom_BSplineCurve) curve = interpolator.Curve();
        if (curve.IsNull()) return nullptr;

        // Create edge from curve
        BRepBuilderAPI_MakeEdge makeEdge(curve);
        if (!makeEdge.IsDone()) return nullptr;

        // Create wire from edge
        BRepBuilderAPI_MakeWire makeWire(makeEdge.Edge());
        if (!makeWire.IsDone()) return nullptr;

        return new OCCTWire(makeWire.Wire());
    } catch (...) {
        return nullptr;
    }
}


// MARK: - Feature-Based Modeling (v0.12.0)

OCCTShapeRef OCCTShapePrism(OCCTShapeRef shape, OCCTWireRef profile,
                            double dirX, double dirY, double dirZ,
                            double height, bool fuse) {
    if (!shape || !profile) return nullptr;

    try {
        // Create face from profile wire
        BRepBuilderAPI_MakeFace makeFace(profile->wire, true);
        if (!makeFace.IsDone()) return nullptr;
        TopoDS_Face profileFace = makeFace.Face();

        // Create the prism direction
        gp_Vec dir(dirX, dirY, dirZ);
        dir.Normalize();
        dir.Scale(height);

        // Create the prism shape (extrusion of the profile)
        BRepPrimAPI_MakePrism makePrism(profileFace, dir);
        if (!makePrism.IsDone()) return nullptr;
        TopoDS_Shape prismShape = makePrism.Shape();

        // Fuse or cut with base shape
        TopoDS_Shape result;
        if (fuse) {
            BRepAlgoAPI_Fuse fuseOp(shape->shape, prismShape);
            if (!fuseOp.IsDone()) return nullptr;
            result = fuseOp.Shape();
        } else {
            BRepAlgoAPI_Cut cutOp(shape->shape, prismShape);
            if (!cutOp.IsDone()) return nullptr;
            result = cutOp.Shape();
        }

        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeDrillHole(OCCTShapeRef shape,
                                 double posX, double posY, double posZ,
                                 double dirX, double dirY, double dirZ,
                                 double radius, double depth) {
    if (!shape || radius <= 0) return nullptr;

    try {
        gp_Vec direction(dirX, dirY, dirZ);
        double dirLen = direction.Magnitude();
        if (dirLen < 1e-10) return nullptr;
        direction.Normalize();

        // Determine depth - if depth is 0 or negative, make it through the shape
        double actualDepth = depth;
        if (actualDepth <= 0) {
            // Calculate shape extent for through hole
            Bnd_Box bounds;
            BRepBndLib::Add(shape->shape, bounds);
            double xmin, ymin, zmin, xmax, ymax, zmax;
            bounds.Get(xmin, ymin, zmin, xmax, ymax, zmax);
            double diagonal = std::sqrt((xmax-xmin)*(xmax-xmin) +
                                        (ymax-ymin)*(ymax-ymin) +
                                        (zmax-zmin)*(zmax-zmin));
            actualDepth = diagonal * 2;  // Make sure it goes through
        }

        // Calculate the bottom of the hole (endpoint of drill)
        double bottomX = posX + direction.X() * actualDepth;
        double bottomY = posY + direction.Y() * actualDepth;
        double bottomZ = posZ + direction.Z() * actualDepth;

        // Create cylinder using OCCTShapeCreateCylinderAt pattern
        // The cylinder's base is at the "bottom" of the hole, extending upward
        OCCTShapeRef cylRef = OCCTShapeCreateCylinderAt(bottomX, bottomY, bottomZ, radius, actualDepth);
        if (!cylRef) return nullptr;

        // Subtract using the existing working function
        OCCTShapeRef result = OCCTShapeSubtract(shape, cylRef);
        OCCTShapeRelease(cylRef);

        return result;
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef* OCCTShapeSplit(OCCTShapeRef shape, OCCTShapeRef tool, int32_t* outCount) {
    if (!shape || !tool || !outCount) return nullptr;
    *outCount = 0;

    try {
        // Use BRepAlgoAPI_Splitter for general splitting
        BRepAlgoAPI_Splitter splitter;

        // Set arguments (shapes to be split)
        TopTools_ListOfShape arguments;
        arguments.Append(shape->shape);
        splitter.SetArguments(arguments);

        // Set tools (cutting shapes)
        TopTools_ListOfShape tools;
        tools.Append(tool->shape);
        splitter.SetTools(tools);

        // Perform split
        splitter.Build();
        if (!splitter.IsDone()) return nullptr;

        TopoDS_Shape result = splitter.Shape();
        if (result.IsNull()) return nullptr;

        // Extract solids from result
        std::vector<TopoDS_Shape> solids;
        for (TopExp_Explorer exp(result, TopAbs_SOLID); exp.More(); exp.Next()) {
            solids.push_back(exp.Current());
        }

        // If no solids, try shells
        if (solids.empty()) {
            for (TopExp_Explorer exp(result, TopAbs_SHELL); exp.More(); exp.Next()) {
                solids.push_back(exp.Current());
            }
        }

        // If still nothing, return the whole result as one shape
        if (solids.empty()) {
            solids.push_back(result);
        }

        // Allocate array
        *outCount = static_cast<int32_t>(solids.size());
        OCCTShapeRef* shapes = new OCCTShapeRef[*outCount];
        for (int32_t i = 0; i < *outCount; i++) {
            shapes[i] = new OCCTShape(solids[i]);
        }

        return shapes;
    } catch (...) {
        *outCount = 0;
        return nullptr;
    }
}

OCCTShapeRef* OCCTShapeSplitByPlane(OCCTShapeRef shape,
                                     double planeX, double planeY, double planeZ,
                                     double normalX, double normalY, double normalZ,
                                     int32_t* outCount) {
    if (!shape || !outCount) return nullptr;
    *outCount = 0;

    try {
        // Create plane
        gp_Pnt pnt(planeX, planeY, planeZ);
        gp_Dir normal(normalX, normalY, normalZ);
        gp_Pln plane(pnt, normal);

        // Create a large face from the plane for cutting
        // Get shape bounds to size the cutting plane
        Bnd_Box bounds;
        BRepBndLib::Add(shape->shape, bounds);
        double xmin, ymin, zmin, xmax, ymax, zmax;
        bounds.Get(xmin, ymin, zmin, xmax, ymax, zmax);
        double size = std::sqrt((xmax-xmin)*(xmax-xmin) +
                                (ymax-ymin)*(ymax-ymin) +
                                (zmax-zmin)*(zmax-zmin)) * 2;

        BRepBuilderAPI_MakeFace makeFace(plane, -size, size, -size, size);
        if (!makeFace.IsDone()) return nullptr;
        TopoDS_Shape planeFace = makeFace.Face();

        // Use splitter
        BRepAlgoAPI_Splitter splitter;

        TopTools_ListOfShape arguments;
        arguments.Append(shape->shape);
        splitter.SetArguments(arguments);

        TopTools_ListOfShape tools;
        tools.Append(planeFace);
        splitter.SetTools(tools);

        splitter.Build();
        if (!splitter.IsDone()) return nullptr;

        TopoDS_Shape result = splitter.Shape();
        if (result.IsNull()) return nullptr;

        // Extract solids from result
        std::vector<TopoDS_Shape> solids;
        for (TopExp_Explorer exp(result, TopAbs_SOLID); exp.More(); exp.Next()) {
            solids.push_back(exp.Current());
        }

        if (solids.empty()) {
            for (TopExp_Explorer exp(result, TopAbs_SHELL); exp.More(); exp.Next()) {
                solids.push_back(exp.Current());
            }
        }

        if (solids.empty()) {
            solids.push_back(result);
        }

        *outCount = static_cast<int32_t>(solids.size());
        OCCTShapeRef* shapes = new OCCTShapeRef[*outCount];
        for (int32_t i = 0; i < *outCount; i++) {
            shapes[i] = new OCCTShape(solids[i]);
        }

        return shapes;
    } catch (...) {
        *outCount = 0;
        return nullptr;
    }
}

void OCCTFreeShapeArray(OCCTShapeRef* shapes, int32_t count) {
    if (!shapes) return;
    for (int32_t i = 0; i < count; i++) {
        delete shapes[i];
    }
    delete[] shapes;
}

void OCCTFreeShapeArrayOnly(OCCTShapeRef* shapes) {
    if (!shapes) return;
    delete[] shapes;
}

OCCTShapeRef OCCTShapeGlue(OCCTShapeRef shape1, OCCTShapeRef shape2, double tolerance) {
    if (!shape1 || !shape2) return nullptr;

    try {
        // Use BRepAlgoAPI_Fuse with glue option for coincident faces
        BRepAlgoAPI_Fuse fuse;
        fuse.SetGlue(BOPAlgo_GlueShift);  // Enable gluing mode
        fuse.SetFuzzyValue(tolerance);

        TopTools_ListOfShape args;
        args.Append(shape1->shape);
        args.Append(shape2->shape);
        fuse.SetArguments(args);

        fuse.Build();
        if (!fuse.IsDone()) {
            // Fallback to regular fuse
            BRepAlgoAPI_Fuse regularFuse(shape1->shape, shape2->shape);
            if (!regularFuse.IsDone()) return nullptr;
            return new OCCTShape(regularFuse.Shape());
        }

        TopoDS_Shape result = fuse.Shape();
        if (result.IsNull()) return nullptr;

        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateEvolved(OCCTWireRef spine, OCCTWireRef profile) {
    if (!spine || !profile) return nullptr;

    try {
        BRepOffsetAPI_MakeEvolved evolved(spine->wire, profile->wire);
        if (!evolved.IsDone()) return nullptr;

        TopoDS_Shape result = evolved.Shape();
        if (result.IsNull()) return nullptr;

        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeLinearPattern(OCCTShapeRef shape,
                                     double dirX, double dirY, double dirZ,
                                     double spacing, int32_t count) {
    if (!shape || count < 1) return nullptr;

    try {
        BRep_Builder builder;
        TopoDS_Compound compound;
        builder.MakeCompound(compound);

        gp_Vec direction(dirX, dirY, dirZ);
        direction.Normalize();

        for (int32_t i = 0; i < count; i++) {
            gp_Trsf transform;
            transform.SetTranslation(direction * (spacing * i));

            BRepBuilderAPI_Transform xform(shape->shape, transform, true);
            if (xform.IsDone()) {
                builder.Add(compound, xform.Shape());
            }
        }

        return new OCCTShape(compound);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCircularPattern(OCCTShapeRef shape,
                                       double axisX, double axisY, double axisZ,
                                       double axisDirX, double axisDirY, double axisDirZ,
                                       int32_t count, double angle) {
    if (!shape || count < 1) return nullptr;

    try {
        BRep_Builder builder;
        TopoDS_Compound compound;
        builder.MakeCompound(compound);

        gp_Pnt axisPoint(axisX, axisY, axisZ);
        gp_Dir axisDir(axisDirX, axisDirY, axisDirZ);
        gp_Ax1 axis(axisPoint, axisDir);

        // If angle is 0, use full circle
        double totalAngle = (angle == 0) ? (2.0 * M_PI) : angle;
        double stepAngle = totalAngle / count;

        for (int32_t i = 0; i < count; i++) {
            gp_Trsf transform;
            transform.SetRotation(axis, stepAngle * i);

            BRepBuilderAPI_Transform xform(shape->shape, transform, true);
            if (xform.IsDone()) {
                builder.Add(compound, xform.Shape());
            }
        }

        return new OCCTShape(compound);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Wire Creation (2D Profiles)

OCCTWireRef OCCTWireCreateRectangle(double width, double height) {
    try {
        double hw = width / 2;
        double hh = height / 2;

        gp_Pnt p1(-hw, -hh, 0);
        gp_Pnt p2( hw, -hh, 0);
        gp_Pnt p3( hw,  hh, 0);
        gp_Pnt p4(-hw,  hh, 0);

        TopoDS_Edge e1 = BRepBuilderAPI_MakeEdge(p1, p2);
        TopoDS_Edge e2 = BRepBuilderAPI_MakeEdge(p2, p3);
        TopoDS_Edge e3 = BRepBuilderAPI_MakeEdge(p3, p4);
        TopoDS_Edge e4 = BRepBuilderAPI_MakeEdge(p4, p1);

        BRepBuilderAPI_MakeWire wireMaker;
        wireMaker.Add(e1);
        wireMaker.Add(e2);
        wireMaker.Add(e3);
        wireMaker.Add(e4);

        return new OCCTWire(wireMaker.Wire());
    } catch (...) {
        return nullptr;
    }
}

OCCTWireRef OCCTWireCreateCircle(double radius) {
    try {
        gp_Circ circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), radius);
        TopoDS_Edge edge = BRepBuilderAPI_MakeEdge(circle);
        BRepBuilderAPI_MakeWire wireMaker(edge);
        return new OCCTWire(wireMaker.Wire());
    } catch (...) {
        return nullptr;
    }
}

OCCTWireRef OCCTWireCreateCircleEx(double radius,
    double ox, double oy, double oz,
    double nx, double ny, double nz) {
    try {
        gp_Circ circle(gp_Ax2(gp_Pnt(ox, oy, oz), gp_Dir(nx, ny, nz)), radius);
        TopoDS_Edge edge = BRepBuilderAPI_MakeEdge(circle);
        BRepBuilderAPI_MakeWire wireMaker(edge);
        return new OCCTWire(wireMaker.Wire());
    } catch (...) {
        return nullptr;
    }
}

OCCTWireRef OCCTWireCreatePolygon(const double* points, int32_t pointCount, bool closed) {
    if (!points || pointCount < 2) return nullptr;

    try {
        BRepBuilderAPI_MakeWire wireMaker;

        for (int32_t i = 0; i < pointCount - 1; i++) {
            gp_Pnt p1(points[i * 2], points[i * 2 + 1], 0);
            gp_Pnt p2(points[(i + 1) * 2], points[(i + 1) * 2 + 1], 0);
            TopoDS_Edge edge = BRepBuilderAPI_MakeEdge(p1, p2);
            wireMaker.Add(edge);
        }

        if (closed && pointCount > 2) {
            gp_Pnt pLast(points[(pointCount - 1) * 2], points[(pointCount - 1) * 2 + 1], 0);
            gp_Pnt pFirst(points[0], points[1], 0);
            TopoDS_Edge edge = BRepBuilderAPI_MakeEdge(pLast, pFirst);
            wireMaker.Add(edge);
        }

        return new OCCTWire(wireMaker.Wire());
    } catch (...) {
        return nullptr;
    }
}

OCCTWireRef OCCTWireCreateFromPoints3D(const double* points, int32_t pointCount, bool closed) {
    if (!points || pointCount < 2) return nullptr;

    try {
        BRepBuilderAPI_MakeWire wireMaker;

        for (int32_t i = 0; i < pointCount - 1; i++) {
            gp_Pnt p1(points[i * 3], points[i * 3 + 1], points[i * 3 + 2]);
            gp_Pnt p2(points[(i + 1) * 3], points[(i + 1) * 3 + 1], points[(i + 1) * 3 + 2]);
            TopoDS_Edge edge = BRepBuilderAPI_MakeEdge(p1, p2);
            wireMaker.Add(edge);
        }

        if (closed && pointCount > 2) {
            gp_Pnt pLast(points[(pointCount - 1) * 3], points[(pointCount - 1) * 3 + 1], points[(pointCount - 1) * 3 + 2]);
            gp_Pnt pFirst(points[0], points[1], points[2]);
            TopoDS_Edge edge = BRepBuilderAPI_MakeEdge(pLast, pFirst);
            wireMaker.Add(edge);
        }

        return new OCCTWire(wireMaker.Wire());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Wire Creation (3D Paths)

OCCTWireRef OCCTWireCreateLine(double x1, double y1, double z1, double x2, double y2, double z2) {
    try {
        gp_Pnt p1(x1, y1, z1);
        gp_Pnt p2(x2, y2, z2);
        TopoDS_Edge edge = BRepBuilderAPI_MakeEdge(p1, p2);
        BRepBuilderAPI_MakeWire wireMaker(edge);
        return new OCCTWire(wireMaker.Wire());
    } catch (...) {
        return nullptr;
    }
}

OCCTWireRef OCCTWireCreateArc(double centerX, double centerY, double centerZ, double radius, double startAngle, double endAngle, double normalX, double normalY, double normalZ) {
    try {
        gp_Pnt center(centerX, centerY, centerZ);
        gp_Dir normal(normalX, normalY, normalZ);
        gp_Ax2 axis(center, normal);

        gp_Circ circle(axis, radius);

        // Create arc from angles
        Handle(Geom_Circle) geomCircle = new Geom_Circle(circle);
        Handle(Geom_TrimmedCurve) arc = new Geom_TrimmedCurve(geomCircle, startAngle, endAngle);

        TopoDS_Edge edge = BRepBuilderAPI_MakeEdge(arc);
        BRepBuilderAPI_MakeWire wireMaker(edge);
        return new OCCTWire(wireMaker.Wire());
    } catch (...) {
        return nullptr;
    }
}

OCCTWireRef OCCTWireCreateArcThroughPoints(double sx, double sy, double sz,
                                            double mx, double my, double mz,
                                            double ex, double ey, double ez) {
    try {
        gp_Pnt p1(sx, sy, sz);
        gp_Pnt p2(mx, my, mz);
        gp_Pnt p3(ex, ey, ez);
        GC_MakeArcOfCircle maker(p1, p2, p3);
        if (!maker.IsDone()) return nullptr;
        Handle(Geom_TrimmedCurve) arc = maker.Value();
        TopoDS_Edge edge = BRepBuilderAPI_MakeEdge(arc);
        BRepBuilderAPI_MakeWire wireMaker(edge);
        return new OCCTWire(wireMaker.Wire());
    } catch (...) {
        return nullptr;
    }
}

OCCTWireRef OCCTWireCreateBSpline(const double* controlPoints, int32_t pointCount) {
    if (!controlPoints || pointCount < 2) return nullptr;

    try {
        TColgp_Array1OfPnt points(1, pointCount);
        for (int32_t i = 0; i < pointCount; i++) {
            points.SetValue(i + 1, gp_Pnt(
                controlPoints[i * 3],
                controlPoints[i * 3 + 1],
                controlPoints[i * 3 + 2]
            ));
        }

        GeomAPI_PointsToBSpline fitter(points);
        if (!fitter.IsDone()) return nullptr;

        Handle(Geom_BSplineCurve) curve = fitter.Curve();
        TopoDS_Edge edge = BRepBuilderAPI_MakeEdge(curve);
        BRepBuilderAPI_MakeWire wireMaker(edge);
        return new OCCTWire(wireMaker.Wire());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - NURBS Curve Creation

OCCTWireRef OCCTWireCreateNURBS(
    const double* poles,
    int32_t poleCount,
    const double* weights,
    const double* knots,
    int32_t knotCount,
    const int32_t* multiplicities,
    int32_t degree
) {
    if (!poles || poleCount < 2 || !knots || knotCount < 2 || degree < 1) return nullptr;

    try {
        // Create control points array (1-indexed in OCCT)
        TColgp_Array1OfPnt polesArray(1, poleCount);
        for (int32_t i = 0; i < poleCount; i++) {
            polesArray.SetValue(i + 1, gp_Pnt(
                poles[i * 3],
                poles[i * 3 + 1],
                poles[i * 3 + 2]
            ));
        }

        // Create weights array
        TColStd_Array1OfReal weightsArray(1, poleCount);
        for (int32_t i = 0; i < poleCount; i++) {
            weightsArray.SetValue(i + 1, weights ? weights[i] : 1.0);
        }

        // Create knots array
        TColStd_Array1OfReal knotsArray(1, knotCount);
        for (int32_t i = 0; i < knotCount; i++) {
            knotsArray.SetValue(i + 1, knots[i]);
        }

        // Create multiplicities array
        TColStd_Array1OfInteger multsArray(1, knotCount);
        for (int32_t i = 0; i < knotCount; i++) {
            multsArray.SetValue(i + 1, multiplicities ? multiplicities[i] : 1);
        }

        // Create the B-spline curve
        Handle(Geom_BSplineCurve) curve = new Geom_BSplineCurve(
            polesArray,
            weightsArray,
            knotsArray,
            multsArray,
            degree
        );

        TopoDS_Edge edge = BRepBuilderAPI_MakeEdge(curve);
        BRepBuilderAPI_MakeWire wireMaker(edge);
        return new OCCTWire(wireMaker.Wire());
    } catch (...) {
        return nullptr;
    }
}

OCCTWireRef OCCTWireCreateNURBSUniform(
    const double* poles,
    int32_t poleCount,
    const double* weights,
    int32_t degree
) {
    if (!poles || poleCount < 2 || degree < 1) return nullptr;
    if (poleCount < degree + 1) return nullptr;  // Need at least degree+1 control points

    try {
        // Create control points array
        TColgp_Array1OfPnt polesArray(1, poleCount);
        for (int32_t i = 0; i < poleCount; i++) {
            polesArray.SetValue(i + 1, gp_Pnt(
                poles[i * 3],
                poles[i * 3 + 1],
                poles[i * 3 + 2]
            ));
        }

        // Create weights array
        TColStd_Array1OfReal weightsArray(1, poleCount);
        for (int32_t i = 0; i < poleCount; i++) {
            weightsArray.SetValue(i + 1, weights ? weights[i] : 1.0);
        }

        // For clamped uniform B-spline:
        // - First and last knots have multiplicity = degree + 1
        // - Interior knots have multiplicity = 1
        // - Number of interior knots = poleCount - degree - 1
        // - Total distinct knots = interior + 2 (for start and end)
        int32_t interiorKnots = poleCount - degree - 1;
        int32_t knotCount = interiorKnots + 2;

        TColStd_Array1OfReal knotsArray(1, knotCount);
        TColStd_Array1OfInteger multsArray(1, knotCount);

        // Start knot at 0 with multiplicity degree+1
        knotsArray.SetValue(1, 0.0);
        multsArray.SetValue(1, degree + 1);

        // Interior knots uniformly distributed
        for (int32_t i = 0; i < interiorKnots; i++) {
            knotsArray.SetValue(i + 2, (double)(i + 1) / (double)(interiorKnots + 1));
            multsArray.SetValue(i + 2, 1);
        }

        // End knot at 1 with multiplicity degree+1
        knotsArray.SetValue(knotCount, 1.0);
        multsArray.SetValue(knotCount, degree + 1);

        // Create the B-spline curve
        Handle(Geom_BSplineCurve) curve = new Geom_BSplineCurve(
            polesArray,
            weightsArray,
            knotsArray,
            multsArray,
            degree
        );

        TopoDS_Edge edge = BRepBuilderAPI_MakeEdge(curve);
        BRepBuilderAPI_MakeWire wireMaker(edge);
        return new OCCTWire(wireMaker.Wire());
    } catch (...) {
        return nullptr;
    }
}

OCCTWireRef OCCTWireCreateCubicBSpline(const double* poles, int32_t poleCount) {
    // Cubic B-spline with uniform weights (non-rational)
    return OCCTWireCreateNURBSUniform(poles, poleCount, nullptr, 3);
}

OCCTWireRef OCCTWireJoin(const OCCTWireRef* wires, int32_t count) {
    if (!wires || count < 1) return nullptr;

    try {
        BRepBuilderAPI_MakeWire wireMaker;

        for (int32_t i = 0; i < count; i++) {
            if (wires[i]) {
                wireMaker.Add(wires[i]->wire);
            }
        }

        if (!wireMaker.IsDone()) return nullptr;
        return new OCCTWire(wireMaker.Wire());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Law Functions (v0.21.0)
// ============================================================================

#include <Law_Function.hxx>
#include <Law_Constant.hxx>
#include <Law_Linear.hxx>
#include <Law_S.hxx>
#include <Law_Interpol.hxx>
#include <Law_BSpline.hxx>
#include <Law_BSpFunc.hxx>
#include <TColgp_Array1OfPnt2d.hxx>

struct OCCTLawFunction {
    Handle(Law_Function) law;
    OCCTLawFunction() {}
    OCCTLawFunction(const Handle(Law_Function)& l) : law(l) {}
};

void OCCTLawFunctionRelease(OCCTLawFunctionRef l) {
    delete l;
}

double OCCTLawFunctionValue(OCCTLawFunctionRef l, double param) {
    if (!l || l->law.IsNull()) return 0.0;
    try {
        return l->law->Value(param);
    } catch (...) {
        return 0.0;
    }
}

void OCCTLawFunctionBounds(OCCTLawFunctionRef l, double* first, double* last) {
    if (!l || l->law.IsNull() || !first || !last) return;
    try {
        l->law->Bounds(*first, *last);
    } catch (...) {
        *first = 0;
        *last = 0;
    }
}

OCCTLawFunctionRef OCCTLawCreateConstant(double value, double first, double last) {
    try {
        Handle(Law_Constant) law = new Law_Constant();
        law->Set(value, first, last);
        return new OCCTLawFunction(law);
    } catch (...) {
        return nullptr;
    }
}

OCCTLawFunctionRef OCCTLawCreateLinear(double first, double startVal,
                                        double last, double endVal) {
    try {
        Handle(Law_Linear) law = new Law_Linear();
        law->Set(first, startVal, last, endVal);
        return new OCCTLawFunction(law);
    } catch (...) {
        return nullptr;
    }
}

OCCTLawFunctionRef OCCTLawCreateS(double first, double startVal,
                                   double last, double endVal) {
    try {
        Handle(Law_S) law = new Law_S();
        law->Set(first, startVal, last, endVal);
        return new OCCTLawFunction(law);
    } catch (...) {
        return nullptr;
    }
}

OCCTLawFunctionRef OCCTLawCreateInterpolate(const double* paramValues,
                                             int32_t count, bool periodic) {
    if (!paramValues || count < 2) return nullptr;
    try {
        TColgp_Array1OfPnt2d pts(1, count);
        for (int32_t i = 0; i < count; i++) {
            pts.SetValue(i + 1, gp_Pnt2d(paramValues[i * 2], paramValues[i * 2 + 1]));
        }
        Handle(Law_Interpol) law = new Law_Interpol();
        law->Set(pts, periodic ? Standard_True : Standard_False);
        return new OCCTLawFunction(law);
    } catch (...) {
        return nullptr;
    }
}

OCCTLawFunctionRef OCCTLawCreateBSpline(const double* poles, int32_t poleCount,
                                         const double* knots, int32_t knotCount,
                                         const int32_t* multiplicities,
                                         int32_t degree) {
    if (!poles || !knots || !multiplicities || poleCount < 2 || knotCount < 2)
        return nullptr;
    try {
        TColStd_Array1OfReal poleArr(1, poleCount);
        for (int32_t i = 0; i < poleCount; i++) poleArr.SetValue(i + 1, poles[i]);

        TColStd_Array1OfReal knotArr(1, knotCount);
        for (int32_t i = 0; i < knotCount; i++) knotArr.SetValue(i + 1, knots[i]);

        TColStd_Array1OfInteger multArr(1, knotCount);
        for (int32_t i = 0; i < knotCount; i++) multArr.SetValue(i + 1, multiplicities[i]);

        Handle(Law_BSpline) bsp = new Law_BSpline(poleArr, knotArr, multArr, degree);
        Handle(Law_BSpFunc) law = new Law_BSpFunc(bsp, knots[0], knots[knotCount - 1]);
        return new OCCTLawFunction(law);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreatePipeShellWithLaw(OCCTWireRef spine,
                                              OCCTWireRef profile,
                                              OCCTLawFunctionRef law,
                                              bool solid) {
    if (!spine || !profile || !law || law->law.IsNull()) return nullptr;
    try {
        BRepOffsetAPI_MakePipeShell pipeShell(spine->wire);
        pipeShell.SetMode(Standard_False); // Frenet
        pipeShell.SetLaw(profile->wire, law->law, Standard_False, Standard_False);
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

// ============================================================================
// MARK: - Surface Intersection (v0.18.0)

OCCTShapeRef OCCTFaceIntersect(OCCTFaceRef face1, OCCTFaceRef face2,
                                double tolerance) {
    if (!face1 || !face2) return nullptr;

    try {
        BRepAlgoAPI_Section section(face1->face, face2->face, Standard_False);
        section.Approximation(Standard_True);
        section.ComputePCurveOn1(Standard_True);
        section.ComputePCurveOn2(Standard_True);
        section.SetFuzzyValue(tolerance);
        section.Build();

        if (!section.IsDone()) return nullptr;

        TopoDS_Shape result = section.Shape();
        if (result.IsNull()) return nullptr;

        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTWireRef OCCTWireOffset3D(OCCTWireRef wire, double distance, double dirX, double dirY, double dirZ) {
    if (!wire) return nullptr;

    try {
        // Create translation vector
        gp_Vec offset(dirX, dirY, dirZ);
        if (offset.Magnitude() > 1e-10) {
            offset.Normalize();
        }
        offset.Multiply(distance);

        // Create transformation
        gp_Trsf transform;
        transform.SetTranslation(offset);

        // Apply transformation
        BRepBuilderAPI_Transform transformer(wire->wire, transform, Standard_True);
        if (!transformer.IsDone()) return nullptr;

        TopoDS_Shape result = transformer.Shape();
        if (result.ShapeType() != TopAbs_WIRE) return nullptr;

        return new OCCTWire(TopoDS::Wire(result));
    } catch (...) {
        return nullptr;
    }
}
// MARK: - v0.42.0: Solid Construction, Fast Polygon, 2D Fillet, Point Cloud Analysis

#include <BRepBuilderAPI_MakeSolid.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepFilletAPI_MakeFillet2d.hxx>
#include <GProp_PEquation.hxx>
#include <TColgp_Array1OfPnt.hxx>

OCCTShapeRef OCCTSolidFromShells(OCCTShapeRef* shells, int32_t count) {
    if (!shells || count <= 0) return nullptr;
    try {
        // Get the first shell
        TopExp_Explorer exp(shells[0]->shape, TopAbs_SHELL);
        if (!exp.More()) return nullptr;
        TopoDS_Shell firstShell = TopoDS::Shell(exp.Current());

        BRepBuilderAPI_MakeSolid maker(firstShell);

        // Add additional shells (cavities)
        for (int32_t i = 1; i < count; i++) {
            if (!shells[i]) continue;
            TopExp_Explorer exp2(shells[i]->shape, TopAbs_SHELL);
            if (exp2.More()) {
                maker.Add(TopoDS::Shell(exp2.Current()));
            }
        }

        if (!maker.IsDone()) return nullptr;
        return new OCCTShape(maker.Solid());
    } catch (...) {
        return nullptr;
    }
}

OCCTWireRef OCCTWireCreateFastPolygon(const double* coords, int32_t pointCount, bool closed) {
    if (!coords || pointCount < 2) return nullptr;
    try {
        BRepBuilderAPI_MakePolygon poly;
        for (int32_t i = 0; i < pointCount; i++) {
            poly.Add(gp_Pnt(coords[i*3], coords[i*3+1], coords[i*3+2]));
        }
        if (closed) poly.Close();
        if (!poly.IsDone()) return nullptr;
        return new OCCTWire(poly.Wire());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTFace2DFillet(OCCTShapeRef shape, const int32_t* vertexIndices,
                               const double* radii, int32_t count) {
    if (!shape || !vertexIndices || !radii || count <= 0) return nullptr;
    try {
        // Get face from shape
        TopExp_Explorer faceExp(shape->shape, TopAbs_FACE);
        if (!faceExp.More()) return nullptr;
        TopoDS_Face face = TopoDS::Face(faceExp.Current());

        BRepFilletAPI_MakeFillet2d fillet(face);

        TopTools_IndexedMapOfShape vertMap;
        TopExp::MapShapes(face, TopAbs_VERTEX, vertMap);

        for (int32_t i = 0; i < count; i++) {
            int32_t idx = vertexIndices[i] + 1; // Convert to 1-based
            if (idx < 1 || idx > vertMap.Extent()) continue;
            fillet.AddFillet(TopoDS::Vertex(vertMap(idx)), radii[i]);
        }

        fillet.Build();
        if (!fillet.IsDone()) return nullptr;
        return new OCCTShape(fillet.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTFace2DChamfer(OCCTShapeRef shape,
                                const int32_t* edge1Indices, const int32_t* edge2Indices,
                                const double* distances, int32_t count) {
    if (!shape || !edge1Indices || !edge2Indices || !distances || count <= 0) return nullptr;
    try {
        TopExp_Explorer faceExp(shape->shape, TopAbs_FACE);
        if (!faceExp.More()) return nullptr;
        TopoDS_Face face = TopoDS::Face(faceExp.Current());

        BRepFilletAPI_MakeFillet2d chamfer(face);

        TopTools_IndexedMapOfShape edgeMap;
        TopExp::MapShapes(face, TopAbs_EDGE, edgeMap);

        for (int32_t i = 0; i < count; i++) {
            int32_t idx1 = edge1Indices[i] + 1;
            int32_t idx2 = edge2Indices[i] + 1;
            if (idx1 < 1 || idx1 > edgeMap.Extent()) continue;
            if (idx2 < 1 || idx2 > edgeMap.Extent()) continue;
            chamfer.AddChamfer(TopoDS::Edge(edgeMap(idx1)),
                               TopoDS::Edge(edgeMap(idx2)),
                               distances[i], distances[i]);
        }

        chamfer.Build();
        if (!chamfer.IsDone()) return nullptr;
        return new OCCTShape(chamfer.Shape());
    } catch (...) {
        return nullptr;
    }
}
