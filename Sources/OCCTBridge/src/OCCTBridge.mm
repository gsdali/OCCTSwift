//
//  OCCTBridge.mm
//  OCCTSwift
//
//  Objective-C++ implementation bridging to OpenCASCADE
//

#import "../include/OCCTBridge.h"

// MARK: - Global Serial Lock for Thread Safety
#include <mutex>
// Non-static (declared in OCCTBridge_Internal.h) so per-area TUs share the
// same underlying mutex via the linker.
std::recursive_mutex& occtGlobalMutex() {
    static std::recursive_mutex mutex;
    return mutex;
}
void OCCTSerialLockAcquire(void) { occtGlobalMutex().lock(); }
void OCCTSerialLockRelease(void) { occtGlobalMutex().unlock(); }

// Suppress OCCT 8.0.0 header deprecation warnings (typedef aliases still work).
// Full migration to NCollection types is tracked for a future release.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-W#pragma-messages"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

// OCCT Foundation Classes
#include <Standard.hxx>
#include <gp_Pnt.hxx>
#include <gp_Vec.hxx>
#include <gp_Dir.hxx>
#include <gp_Ax1.hxx>
#include <gp_Ax2.hxx>
#include <gp_Trsf.hxx>
#include <gp_Pln.hxx>
#include <gp_Circ.hxx>

// Topology
#include <TopoDS.hxx>
#include <TopoDS_Shape.hxx>
#include <TopoDS_Wire.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Vertex.hxx>
#include <TopoDS_Compound.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>

// Geometry
#include <Geom_Circle.hxx>
#include <Geom_Line.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <Geom_Surface.hxx>
#include <Geom_Plane.hxx>
#include <GeomAPI_ProjectPointOnSurf.hxx>
#include <GeomAPI_ProjectPointOnCurve.hxx>
#include <GeomConvert.hxx>
#include <GeomConvert_CompCurveToBSplineCurve.hxx>
#include <Geom_RectangularTrimmedSurface.hxx>
#include <TColStd_Array2OfReal.hxx>
#include <ShapeCustom_RestrictionParameters.hxx>
#include <RWObj_CafReader.hxx>
#include <RWObj_CafWriter.hxx>
#include <RWPly_CafWriter.hxx>
#include <NLPlate_NLPlate.hxx>
#include <NLPlate_HPG0Constraint.hxx>
#include <NLPlate_HPG1Constraint.hxx>
#include <Plate_D1.hxx>
#include <GeomAPI_PointsToBSplineSurface.hxx>
#include <ProjLib_ProjectOnPlane.hxx>
#include <GeomPlate_BuildAveragePlane.hxx>
#include <TNaming_Builder.hxx>
#include <TNaming_NamedShape.hxx>
#include <TNaming_Tool.hxx>
#include <ShapeAnalysis_Curve.hxx>
#include <Geom_SurfaceOfRevolution.hxx>
#include <BRepLib_FindSurface.hxx>
#include <ShapeFix_Wireframe.hxx>
#include <ShapeAnalysis_ShapeContents.hxx>
#include <XCAFDoc_LayerTool.hxx>
#include <GProp_PrincipalProps.hxx>
#include <GeomConvert_BSplineSurfaceToBezierSurface.hxx>
#include <GeomConvert_BSplineCurveKnotSplitting.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_BezierSurface.hxx>
#include <HLRBRep_PolyAlgo.hxx>
#include <HLRBRep_PolyHLRToShape.hxx>
#include <ShapeUpgrade_ShapeConvertToBezier.hxx>
#include <BRepExtrema_SelfIntersection.hxx>
#include <BRepGProp_Face.hxx>
#include <ShapeAnalysis_WireOrder.hxx>
#include <ShapeCustom.hxx>
#include <TDataStd_Integer.hxx>
#include <TDataStd_TreeNode.hxx>
#include <TDF_ChildIterator.hxx>
#include <TFunction_Function.hxx>
#include <TDataStd_Real.hxx>
#include <Geom2d_Line.hxx>
#include <BRepLProp_SLProps.hxx>
#include <BRepTools.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <GeomAbs_SurfaceType.hxx>
#include <GC_MakeArcOfCircle.hxx>
#include <GC_MakeCircle.hxx>
#include <GC_MakeLine.hxx>
#include <GC_MakeSegment.hxx>
#include <GeomAPI_PointsToBSpline.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColStd_Array1OfInteger.hxx>

// Primitive Creation
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepPrimAPI_MakeCone.hxx>
#include <BRepPrimAPI_MakeTorus.hxx>
#include <BRepPrimAPI_MakePrism.hxx>
#include <BRepPrimAPI_MakeRevol.hxx>

// Sweep Operations
#include <BRepOffsetAPI_MakePipe.hxx>
#include <BRepOffsetAPI_ThruSections.hxx>

// Boolean Operations
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Common.hxx>
#include <BRepAlgoAPI_Section.hxx>

// Modifications
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepFilletAPI_MakeChamfer.hxx>
#include <BRepOffsetAPI_MakeThickSolid.hxx>
#include <BRepOffsetAPI_MakeOffsetShape.hxx>
#include <BRepOffsetAPI_MakeOffset.hxx>
#include <TopTools_ListOfShape.hxx>
#include <TopTools_HSequenceOfShape.hxx>
#include <TopTools_IndexedDataMapOfShapeListOfShape.hxx>
// TopTools_ListIteratorOfListOfShape.hxx removed in OCCT 8.0
#include <ShapeAnalysis_FreeBounds.hxx>
#include <GeomAbs_JoinType.hxx>

// Transformations
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepBuilderAPI_Copy.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>

// Building
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>

// Validation & Healing
#include <BRepLib.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <ShapeFix_Shape.hxx>
#include <ShapeFix_Solid.hxx>

// Sewing & Solid Creation
#include <BRepBuilderAPI_Sewing.hxx>
#include <BRepBuilderAPI_MakeSolid.hxx>
#include <TopoDS_Shell.hxx>
#include <TopoDS_Solid.hxx>

// Meshing
#include <BRepMesh_IncrementalMesh.hxx>
#include <IMeshTools_Parameters.hxx>
#include <Poly_Triangulation.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <Bnd_Box.hxx>
#include <BRepBndLib.hxx>
#include <GCPnts_TangentialDeflection.hxx>
#include <BRepAdaptor_Curve.hxx>

// For mesh-to-shape conversion
#include <BRepBuilderAPI_Sewing.hxx>
#include <BRepBuilderAPI_MakeSolid.hxx>
#include <ShapeFix_Solid.hxx>

// Measurement & Analysis (v0.7.0)
#include <BRepExtrema_DistShapeShape.hxx>
#include <TopTools_IndexedMapOfShape.hxx>

// Advanced Modeling (v0.8.0)
#include <BRepOffsetAPI_DraftAngle.hxx>
#include <BRepAlgoAPI_Defeaturing.hxx>
#include <BRepOffsetAPI_MakePipeShell.hxx>
#include <Law_Linear.hxx>
#include <BRepBuilderAPI_TransitionMode.hxx>

// Surfaces & Curves (v0.9.0)
#include <BRepAdaptor_CompCurve.hxx>
#include <GCPnts_AbscissaPoint.hxx>
#include <BRepLProp_CLProps.hxx>
#include <Geom_BSplineSurface.hxx>
#include <GeomFill_BSplineCurves.hxx>
#include <BRepFill.hxx>
#include <TColgp_Array2OfPnt.hxx>

// Import/Export
#include <STEPControl_Reader.hxx>
#include <STEPControl_Writer.hxx>
#include <StlAPI_Writer.hxx>
#include <Interface_Static.hxx>
#include <XSControl_WorkSession.hxx>
#include <Transfer_FinderProcess.hxx>

#include <vector>
#include <cmath>
#include <string>

// XDE/XCAF Support (v0.6.0)
#include <Graphic3d_Vec3.hxx>
#include <XCAFApp_Application.hxx>
#include <TDocStd_Document.hxx>
#include <XCAFDoc_DocumentTool.hxx>
#include <XCAFDoc_ShapeTool.hxx>
#include <XCAFDoc_ColorTool.hxx>
#include <XCAFDoc_VisMaterialTool.hxx>
#include <XCAFDoc_VisMaterial.hxx>
#include <TDF_Label.hxx>
#include <TDF_LabelSequence.hxx>
#include <TDF_Tool.hxx>
#include <TDataStd_Name.hxx>
#include <Quantity_Color.hxx>
#include <Quantity_ColorRGBA.hxx>
#include <TopLoc_Location.hxx>
#include <STEPCAFControl_Reader.hxx>
#include <STEPCAFControl_Writer.hxx>

// HLR (Hidden Line Removal) for 2D drawings
#include <HLRBRep_Algo.hxx>
#include <HLRBRep_HLRToShape.hxx>
#include <HLRAlgo_Projector.hxx>

// IGES import/export (v0.10.0)
#include <IGESControl_Reader.hxx>
#include <IGESControl_Writer.hxx>

// BREP native format (v0.10.0)
#include <BRep_Builder.hxx>

// Geometry Construction (v0.11.0)
#include <GeomAPI_Interpolate.hxx>
#include <TColgp_HArray1OfPnt.hxx>

// Feature-Based Modeling (v0.12.0)
#include <BRepFeat_MakePrism.hxx>
#include <BRepFeat_MakeCylindricalHole.hxx>
#include <BRepFeat_SplitShape.hxx>
#include <BRepFeat_Gluer.hxx>
#include <BRepOffsetAPI_MakeEvolved.hxx>
#include <BRepAlgoAPI_Splitter.hxx>

// Shape Healing & Analysis (v0.13.0)
#include <ShapeAnalysis_Shell.hxx>
#include <ShapeAnalysis_Wire.hxx>
#include <ShapeAnalysis_Surface.hxx>
#include <ShapeAnalysis_ShapeTolerance.hxx>
#include <ShapeFix_Wire.hxx>
#include <ShapeFix_Face.hxx>
#include <ShapeFix_Shell.hxx>
#include <ShapeUpgrade_UnifySameDomain.hxx>
#include <BRepCheck_Wire.hxx>
#include <BRepCheck_Shell.hxx>

// Camera (Metal Visualization)
#include <Graphic3d_Camera.hxx>

// SelectMgr (Metal Visualization)
#include <SelectMgr_ViewerSelector.hxx>
#include <SelectMgr_SelectableObject.hxx>
#include <SelectMgr_SelectionManager.hxx>
#include <SelectMgr_EntityOwner.hxx>
#include <TColgp_Array1OfPnt2d.hxx>
#include <StdSelect_BRepSelectionTool.hxx>
#include <StdSelect_BRepOwner.hxx>
#include <NCollection_DataMap.hxx>
#include <NCollection_Sequence.hxx>
#include <NCollection_IndexedDataMap.hxx>
#include <NCollection_Map.hxx>
#include <NCollection_PackedMap.hxx>
#include <TCollection_AsciiString.hxx>
#include <TColStd_PackedMapOfInteger.hxx>
#include <Graphic3d_Mat4.hxx>
#include <Graphic3d_Mat4d.hxx>
#include <Poly_Connect.hxx>

// Prs3d_Drawer (Metal Visualization)
#include <Prs3d_Drawer.hxx>

// ClipPlane (Metal Visualization)
#include <Graphic3d_ClipPlane.hxx>
#include <Graphic3d_Vec4.hxx>
#include <Graphic3d_BndBox3d.hxx>

// ZLayerSettings (Metal Visualization)
#include <Graphic3d_ZLayerSettings.hxx>
#include <Graphic3d_PolygonOffset.hxx>

// Advanced Blends & Surface Filling (v0.14.0)
#include <ChFi2d.hxx>
#include <ChFi2d_Builder.hxx>
#include <ChFi2d_FilletAPI.hxx>
#include <ChFi2d_ChamferAPI.hxx>
#include <BRepOffsetAPI_MakeFilling.hxx>
#include <GeomPlate_BuildPlateSurface.hxx>
#include <GeomPlate_MakeApprox.hxx>
#include <GeomPlate_PointConstraint.hxx>
#include <GeomPlate_CurveConstraint.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <Adaptor3d_CurveOnSurface.hxx>

// v0.47.0: LocOpe_Revol, LocOpe_DPrism, GeomFill_ConstrainedFilling, BRepCheck
#include <LocOpe_Revol.hxx>
#include <LocOpe_DPrism.hxx>
#include <Adaptor3d_Curve.hxx>
#include <GeomFill_ConstrainedFilling.hxx>
#include <GeomFill_SimpleBound.hxx>
#include <BRepCheck_Face.hxx>
#include <BRepCheck_Solid.hxx>
#include <BRepCheck_Result.hxx>
#include <BRepCheck_Status.hxx>
#include <BRepCheck_ListOfStatus.hxx>

// v0.61.0: Approx, Contap, BOPAlgo, IntCurvesFace, BRepMesh, GeomPlate
#include <Contap_ContAna.hxx>
#include <gp_Sphere.hxx>
#include <gp_Cylinder.hxx>
#include <IntCurvesFace_Intersector.hxx>
#include <gp_Lin.hxx>
#include <BOPAlgo_CellsBuilder.hxx>
#include <BOPAlgo_Splitter.hxx>
#include <BOPAlgo_ArgumentAnalyzer.hxx>
#include <BRepAdaptor_Curve2d.hxx>
#include <BRepMesh_Deflection.hxx>
#include <Approx_CurveOnSurface.hxx>
#include <GeomAdaptor_Surface.hxx>
#include <Geom2dAdaptor_Curve.hxx>
#include <GeomAbs_Shape.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <BRepBuilderAPI_MakeShapeOnMesh.hxx>
#include <Poly_Array1OfTriangle.hxx>
#include <Poly_Triangle.hxx>
#include <GeomPlate_Surface.hxx>

// v0.48.0: Comprehensive LocOpe, BRepCheck, ShapeFix, BRepExtrema, ShapeUpgrade
#include <LocOpe_Pipe.hxx>
#include <LocOpe_LinearForm.hxx>
#include <LocOpe_RevolutionForm.hxx>
#include <LocOpe_SplitShape.hxx>
#include <LocOpe_SplitDrafts.hxx>
#include <LocOpe_FindEdges.hxx>
#include <LocOpe_FindEdgesInFace.hxx>
#include <LocOpe_CSIntersector.hxx>
#include <LocOpe_PntFace.hxx>
// #include <LocOpe_Gluer.hxx> // unused
#include <BRepCheck_Analyzer.hxx>
#include <BRepCheck_Edge.hxx>
#include <BRepCheck_Wire.hxx>
#include <BRepCheck_Shell.hxx>
#include <BRepCheck_Vertex.hxx>
#include <ShapeFix_ShapeTolerance.hxx>
#include <ShapeFix_SplitCommonVertex.hxx>
#include <ShapeFix_FaceConnect.hxx>
#include <ShapeFix_Edge.hxx>
#include <ShapeFix_WireVertex.hxx>
#include <BRepExtrema_ExtCC.hxx>
#include <BRepExtrema_ExtFF.hxx>
#include <BRepExtrema_ExtPF.hxx>
#include <BRepBuilderAPI_MakeVertex.hxx>
#include <ShapeUpgrade_ShapeDivideClosed.hxx>
#include <ShapeUpgrade_ShapeDivideContinuity.hxx>
// #include <NCollection_Sequence.hxx> // unused in v0.48

// MARK: - Internal Structures

#include <BRepBuilderAPI_Sewing.hxx>

struct OCCTSewing {
    BRepBuilderAPI_Sewing sewing;
    OCCTSewing(double tol) : sewing(tol) {}
};

struct OCCTShape {
    TopoDS_Shape shape;

    OCCTShape() {}
    OCCTShape(const TopoDS_Shape& s) : shape(s) {}
};

struct OCCTWire {
    TopoDS_Wire wire;

    OCCTWire() {}
    OCCTWire(const TopoDS_Wire& w) : wire(w) {}
};

struct OCCTMesh {
    std::vector<float> vertices;
    std::vector<float> normals;
    std::vector<uint32_t> indices;
    std::vector<int32_t> faceIndices;     // Source B-Rep face index per triangle
    std::vector<float> triangleNormals;   // Per-triangle normals (nx,ny,nz per triangle)
};

struct OCCTFace {
    TopoDS_Face face;

    OCCTFace() {}
    OCCTFace(const TopoDS_Face& f) : face(f) {}
};

// XDE Document for assembly structure, colors, materials (v0.6.0)
struct OCCTDocument {
    Handle(XCAFApp_Application) app;
    Handle(TDocStd_Document) doc;
    Handle(XCAFDoc_ShapeTool) shapeTool;
    Handle(XCAFDoc_ColorTool) colorTool;
    Handle(XCAFDoc_VisMaterialTool) materialTool;
    std::vector<TDF_Label> labels;  // Label registry (index = labelId)

    OCCTDocument() {
        app = XCAFApp_Application::GetApplication();
    }

    // Get or register a label, returns labelId
    int64_t registerLabel(const TDF_Label& label) {
        // Check if already registered
        for (size_t i = 0; i < labels.size(); i++) {
            if (labels[i].IsEqual(label)) {
                return static_cast<int64_t>(i);
            }
        }
        // Register new label
        labels.push_back(label);
        return static_cast<int64_t>(labels.size() - 1);
    }

    // Get label by ID
    TDF_Label getLabel(int64_t labelId) const {
        if (labelId < 0 || labelId >= static_cast<int64_t>(labels.size())) {
            return TDF_Label();
        }
        return labels[labelId];
    }
};

// 2D Drawing from HLR projection (v0.6.0)
struct OCCTDrawing {
    TopoDS_Shape visibleSharp;      // Visible sharp edges
    TopoDS_Shape visibleSmooth;     // Visible smooth edges
    TopoDS_Shape visibleOutline;    // Visible silhouette
    TopoDS_Shape hiddenSharp;       // Hidden sharp edges
    TopoDS_Shape hiddenSmooth;      // Hidden smooth edges
    TopoDS_Shape hiddenOutline;     // Hidden silhouette
};

// MARK: - Shape Creation (Primitives)

OCCTShapeRef OCCTShapeCreateBox(double width, double height, double depth) {
    try {
        // Create box centered at origin
        gp_Pnt origin(-width/2, -height/2, -depth/2);
        BRepPrimAPI_MakeBox maker(origin, width, height, depth);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateBoxAt(double x, double y, double z, double width, double height, double depth) {
    try {
        gp_Pnt origin(x, y, z);
        BRepPrimAPI_MakeBox maker(origin, width, height, depth);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateBoxOriented(
    double originX, double originY, double originZ,
    double dirX, double dirY, double dirZ,
    double width, double height, double depth) {
    try {
        gp_Ax2 axis(gp_Pnt(originX, originY, originZ), gp_Dir(dirX, dirY, dirZ));
        BRepPrimAPI_MakeBox maker(axis, width, height, depth);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateCylinder(double radius, double height) {
    try {
        BRepPrimAPI_MakeCylinder maker(radius, height);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateCylinderAt(double cx, double cy, double bottomZ, double radius, double height) {
    try {
        // Create axis at position with Z-up direction
        gp_Ax2 axis(gp_Pnt(cx, cy, bottomZ), gp_Dir(0, 0, 1));
        BRepPrimAPI_MakeCylinder maker(axis, radius, height);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateCylinderOriented(
    double originX, double originY, double originZ,
    double dirX, double dirY, double dirZ,
    double radius, double height) {
    try {
        gp_Pnt origin(originX, originY, originZ);
        gp_Dir direction(dirX, dirY, dirZ);
        gp_Ax2 axis(origin, direction);
        BRepPrimAPI_MakeCylinder maker(axis, radius, height);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateCylinderPartial(double radius, double height, double angle) {
    try {
        BRepPrimAPI_MakeCylinder maker(radius, height, angle);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

// Note: This creates an approximation of the swept volume using
// two cylinders connected by a box. For CAM purposes, this provides
// a conservative (larger) estimate suitable for collision detection
// and material removal simulation. A true swept solid could use
// BRepOffsetAPI_MakePipeShell for more accurate results.
OCCTShapeRef OCCTShapeCreateToolSweep(double radius, double height,
                                       double x1, double y1, double z1,
                                       double x2, double y2, double z2) {
    try {
        // For a cylindrical tool (flat end mill) moving from point 1 to point 2:
        // The swept volume consists of:
        // 1. Cylinder at start position
        // 2. Cylinder at end position
        // 3. A box connecting them (for horizontal component)

        double dx = x2 - x1;
        double dy = y2 - y1;
        double dz = z2 - z1;
        double xyDist = std::sqrt(dx*dx + dy*dy);

        // Use the lower Z as the bottom of the swept volume
        double bottomZ = std::min(z1, z2);

        // Create cylinder at start position
        gp_Ax2 axis1(gp_Pnt(x1, y1, bottomZ), gp_Dir(0, 0, 1));
        BRepPrimAPI_MakeCylinder cyl1Maker(axis1, radius, height + std::abs(dz));
        TopoDS_Shape result = cyl1Maker.Shape();

        // If there's XY movement, we need the end cylinder and connecting box
        if (xyDist > 1e-6) {
            // Create cylinder at end position
            gp_Ax2 axis2(gp_Pnt(x2, y2, bottomZ), gp_Dir(0, 0, 1));
            BRepPrimAPI_MakeCylinder cyl2Maker(axis2, radius, height + std::abs(dz));

            // Union end cylinder
            BRepAlgoAPI_Fuse fuse1(result, cyl2Maker.Shape());
            fuse1.Build();
            if (!fuse1.IsDone()) return nullptr;
            result = fuse1.Shape();

            // Create connecting box
            // The box needs to be oriented along the movement direction
            // Width = 2*radius (tool diameter), Length = xyDist, Height = tool height + dz

            // Calculate perpendicular direction for box width
            double perpX = -dy / xyDist;  // perpendicular to movement direction
            double perpY = dx / xyDist;

            // Box corner points (4 corners at bottom, extruded up)
            // The box connects the two cylinder centers
            gp_Pnt p1(x1 + perpX * radius, y1 + perpY * radius, bottomZ);
            gp_Pnt p2(x1 - perpX * radius, y1 - perpY * radius, bottomZ);
            gp_Pnt p3(x2 - perpX * radius, y2 - perpY * radius, bottomZ);
            gp_Pnt p4(x2 + perpX * radius, y2 + perpY * radius, bottomZ);

            // Create edges for the bottom face
            TopoDS_Edge e1 = BRepBuilderAPI_MakeEdge(p1, p2);
            TopoDS_Edge e2 = BRepBuilderAPI_MakeEdge(p2, p3);
            TopoDS_Edge e3 = BRepBuilderAPI_MakeEdge(p3, p4);
            TopoDS_Edge e4 = BRepBuilderAPI_MakeEdge(p4, p1);

            // Create wire from edges
            BRepBuilderAPI_MakeWire wireMaker;
            wireMaker.Add(e1);
            wireMaker.Add(e2);
            wireMaker.Add(e3);
            wireMaker.Add(e4);

            if (!wireMaker.IsDone()) return nullptr;

            // Create face from wire
            BRepBuilderAPI_MakeFace faceMaker(wireMaker.Wire());
            if (!faceMaker.IsDone()) return nullptr;

            // Extrude face upward to create box
            gp_Vec extrudeVec(0, 0, height + std::abs(dz));
            BRepPrimAPI_MakePrism prismMaker(faceMaker.Face(), extrudeVec);
            prismMaker.Build();
            if (!prismMaker.IsDone()) return nullptr;

            // Union connecting box
            BRepAlgoAPI_Fuse fuse2(result, prismMaker.Shape());
            fuse2.Build();
            if (!fuse2.IsDone()) return nullptr;
            result = fuse2.Shape();
        }

        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateSphere(double radius) {
    try {
        BRepPrimAPI_MakeSphere maker(radius);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateSphereAtCenter(double cx, double cy, double cz, double radius) {
    try {
        gp_Pnt center(cx, cy, cz);
        BRepPrimAPI_MakeSphere maker(center, radius);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateSphereOriented(
    double originX, double originY, double originZ,
    double dirX, double dirY, double dirZ,
    double radius) {
    try {
        gp_Ax2 axis(gp_Pnt(originX, originY, originZ), gp_Dir(dirX, dirY, dirZ));
        BRepPrimAPI_MakeSphere maker(axis, radius);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateSpherePartial(double radius, double angle) {
    try {
        BRepPrimAPI_MakeSphere maker(radius, angle);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateCone(double bottomRadius, double topRadius, double height) {
    try {
        BRepPrimAPI_MakeCone maker(bottomRadius, topRadius, height);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateConeOriented(
    double originX, double originY, double originZ,
    double dirX, double dirY, double dirZ,
    double bottomRadius, double topRadius, double height) {
    try {
        gp_Ax2 axis(gp_Pnt(originX, originY, originZ), gp_Dir(dirX, dirY, dirZ));
        BRepPrimAPI_MakeCone maker(axis, bottomRadius, topRadius, height);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateTorus(double majorRadius, double minorRadius) {
    try {
        BRepPrimAPI_MakeTorus maker(majorRadius, minorRadius);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateTorusOriented(
    double originX, double originY, double originZ,
    double dirX, double dirY, double dirZ,
    double majorRadius, double minorRadius) {
    try {
        gp_Ax2 axis(gp_Pnt(originX, originY, originZ), gp_Dir(dirX, dirY, dirZ));
        BRepPrimAPI_MakeTorus maker(axis, majorRadius, minorRadius);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateCylinderOrientedPartial(
    double originX, double originY, double originZ,
    double dirX, double dirY, double dirZ,
    double radius, double height, double angle) {
    try {
        gp_Ax2 axis(gp_Pnt(originX, originY, originZ), gp_Dir(dirX, dirY, dirZ));
        BRepPrimAPI_MakeCylinder maker(axis, radius, height, angle);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateConeOrientedPartial(
    double originX, double originY, double originZ,
    double dirX, double dirY, double dirZ,
    double bottomRadius, double topRadius, double height, double angle) {
    try {
        gp_Ax2 axis(gp_Pnt(originX, originY, originZ), gp_Dir(dirX, dirY, dirZ));
        BRepPrimAPI_MakeCone maker(axis, bottomRadius, topRadius, height, angle);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateTorusOrientedPartial(
    double originX, double originY, double originZ,
    double dirX, double dirY, double dirZ,
    double majorRadius, double minorRadius, double angle) {
    try {
        gp_Ax2 axis(gp_Pnt(originX, originY, originZ), gp_Dir(dirX, dirY, dirZ));
        BRepPrimAPI_MakeTorus maker(axis, majorRadius, minorRadius, angle);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateTorusOrientedSegment(
    double originX, double originY, double originZ,
    double dirX, double dirY, double dirZ,
    double majorRadius, double minorRadius, double angle1, double angle2) {
    try {
        gp_Ax2 axis(gp_Pnt(originX, originY, originZ), gp_Dir(dirX, dirY, dirZ));
        BRepPrimAPI_MakeTorus maker(axis, majorRadius, minorRadius, angle1, angle2);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateSphereOrientedPartial(
    double originX, double originY, double originZ,
    double dirX, double dirY, double dirZ,
    double radius, double angle) {
    try {
        gp_Ax2 axis(gp_Pnt(originX, originY, originZ), gp_Dir(dirX, dirY, dirZ));
        BRepPrimAPI_MakeSphere maker(axis, radius, angle);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateSphereOrientedSegment(
    double originX, double originY, double originZ,
    double dirX, double dirY, double dirZ,
    double radius, double angle1, double angle2) {
    try {
        gp_Ax2 axis(gp_Pnt(originX, originY, originZ), gp_Dir(dirX, dirY, dirZ));
        BRepPrimAPI_MakeSphere maker(axis, radius, angle1, angle2);
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Shape Creation (Sweeps)

OCCTShapeRef OCCTShapeCreatePipeSweep(OCCTWireRef profile, OCCTWireRef path) {
    if (!profile || !path) return nullptr;
    try {
        BRepOffsetAPI_MakePipe maker(path->wire, profile->wire);
        maker.Build();
        if (!maker.IsDone()) return nullptr;
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateExtrusion(OCCTWireRef profile, double dx, double dy, double dz, double length) {
    if (!profile) return nullptr;
    try {
        // Normalize direction and scale by length
        double mag = std::sqrt(dx*dx + dy*dy + dz*dz);
        if (mag < 1e-10) return nullptr;
        gp_Vec direction(dx/mag * length, dy/mag * length, dz/mag * length);

        // Create a face from the wire for solid extrusion
        BRepBuilderAPI_MakeFace faceMaker(profile->wire);
        if (!faceMaker.IsDone()) return nullptr;

        BRepPrimAPI_MakePrism maker(faceMaker.Face(), direction);
        maker.Build();
        if (!maker.IsDone()) return nullptr;
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateRevolution(OCCTWireRef profile, double axisX, double axisY, double axisZ, double dirX, double dirY, double dirZ, double angle) {
    if (!profile) return nullptr;
    try {
        gp_Pnt axisOrigin(axisX, axisY, axisZ);
        gp_Dir axisDirection(dirX, dirY, dirZ);
        gp_Ax1 axis(axisOrigin, axisDirection);

        BRepPrimAPI_MakeRevol maker(profile->wire, axis, angle);
        maker.Build();
        if (!maker.IsDone()) return nullptr;
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateExtrusionInfinite(OCCTShapeRef shape,
    double dirX, double dirY, double dirZ, bool infinite) {
    if (!shape) return nullptr;
    try {
        gp_Dir dir(dirX, dirY, dirZ);
        BRepPrimAPI_MakePrism maker(shape->shape, dir, infinite);
        maker.Build();
        if (!maker.IsDone()) return nullptr;
        return new OCCTShape(maker.Shape());
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTShapeCreateExtrusionShape(OCCTShapeRef shape,
    double dx, double dy, double dz) {
    if (!shape) return nullptr;
    try {
        gp_Vec vec(dx, dy, dz);
        BRepPrimAPI_MakePrism maker(shape->shape, vec);
        maker.Build();
        if (!maker.IsDone()) return nullptr;
        return new OCCTShape(maker.Shape());
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTShapeCreateRevolutionFull(OCCTShapeRef shape,
    double axisX, double axisY, double axisZ,
    double dirX, double dirY, double dirZ) {
    if (!shape) return nullptr;
    try {
        gp_Ax1 axis(gp_Pnt(axisX, axisY, axisZ), gp_Dir(dirX, dirY, dirZ));
        BRepPrimAPI_MakeRevol maker(shape->shape, axis);
        maker.Build();
        if (!maker.IsDone()) return nullptr;
        return new OCCTShape(maker.Shape());
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTShapeCreateRevolutionPartial(OCCTShapeRef shape,
    double axisX, double axisY, double axisZ,
    double dirX, double dirY, double dirZ,
    double angle) {
    if (!shape) return nullptr;
    try {
        gp_Ax1 axis(gp_Pnt(axisX, axisY, axisZ), gp_Dir(dirX, dirY, dirZ));
        BRepPrimAPI_MakeRevol maker(shape->shape, axis, angle);
        maker.Build();
        if (!maker.IsDone()) return nullptr;
        return new OCCTShape(maker.Shape());
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTShapeCreateLoft(const OCCTWireRef* profiles, int32_t count, bool solid) {
    if (!profiles || count < 2) return nullptr;
    try {
        BRepOffsetAPI_ThruSections maker(solid ? Standard_True : Standard_False);

        // Enable compatibility checking to:
        // - Compute origin and orientation on wires to avoid twisted results
        // - Update wires to have same number of edges
        maker.CheckCompatibility(Standard_True);

        for (int32_t i = 0; i < count; i++) {
            if (profiles[i]) {
                maker.AddWire(profiles[i]->wire);
            }
        }

        maker.Build();
        if (!maker.IsDone()) return nullptr;
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Boolean Operations

OCCTShapeRef OCCTShapeUnion(OCCTShapeRef shape1, OCCTShapeRef shape2) {
    if (!shape1 || !shape2) return nullptr;
    try {
        BRepAlgoAPI_Fuse fuser(shape1->shape, shape2->shape);
        fuser.Build();
        if (!fuser.IsDone()) return nullptr;
        return new OCCTShape(fuser.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeSubtract(OCCTShapeRef shape1, OCCTShapeRef shape2) {
    if (!shape1 || !shape2) return nullptr;
    try {
        BRepAlgoAPI_Cut cutter(shape1->shape, shape2->shape);
        cutter.Build();
        if (!cutter.IsDone()) return nullptr;
        return new OCCTShape(cutter.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeIntersect(OCCTShapeRef shape1, OCCTShapeRef shape2) {
    if (!shape1 || !shape2) return nullptr;
    try {
        BRepAlgoAPI_Common intersector(shape1->shape, shape2->shape);
        intersector.Build();
        if (!intersector.IsDone()) return nullptr;
        return new OCCTShape(intersector.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Modifications

OCCTShapeRef OCCTShapeFillet(OCCTShapeRef shape, double radius) {
    if (!shape) return nullptr;
    try {
        BRepFilletAPI_MakeFillet fillet(shape->shape);

        // Add fillet to all edges
        TopExp_Explorer explorer(shape->shape, TopAbs_EDGE);
        while (explorer.More()) {
            fillet.Add(radius, TopoDS::Edge(explorer.Current()));
            explorer.Next();
        }

        fillet.Build();
        if (!fillet.IsDone()) return nullptr;
        return new OCCTShape(fillet.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeChamfer(OCCTShapeRef shape, double distance) {
    if (!shape) return nullptr;
    try {
        BRepFilletAPI_MakeChamfer chamfer(shape->shape);

        // Add chamfer to all edges
        TopExp_Explorer explorer(shape->shape, TopAbs_EDGE);
        while (explorer.More()) {
            chamfer.Add(distance, TopoDS::Edge(explorer.Current()));
            explorer.Next();
        }

        chamfer.Build();
        if (!chamfer.IsDone()) return nullptr;
        return new OCCTShape(chamfer.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeShell(OCCTShapeRef shape, double thickness) {
    if (!shape) return nullptr;
    try {
        // Create list of faces to remove (none = hollow shell)
        TopTools_ListOfShape facesToRemove;

        BRepOffsetAPI_MakeThickSolid thickSolid;
        thickSolid.MakeThickSolidBySimple(shape->shape, thickness);
        if (!thickSolid.IsDone()) return nullptr;
        return new OCCTShape(thickSolid.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeOffset(OCCTShapeRef shape, double distance) {
    if (!shape) return nullptr;
    try {
        BRepOffsetAPI_MakeOffsetShape offsetter;
        offsetter.PerformBySimple(shape->shape, distance);
        if (!offsetter.IsDone()) return nullptr;
        return new OCCTShape(offsetter.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Transformations

OCCTShapeRef OCCTShapeTranslate(OCCTShapeRef shape, double dx, double dy, double dz) {
    if (!shape) return nullptr;
    try {
        gp_Trsf transform;
        transform.SetTranslation(gp_Vec(dx, dy, dz));
        BRepBuilderAPI_Transform transformer(shape->shape, transform, Standard_True);
        return new OCCTShape(transformer.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeRotate(OCCTShapeRef shape, double axisX, double axisY, double axisZ, double angle) {
    if (!shape) return nullptr;
    try {
        gp_Ax1 axis(gp_Pnt(0, 0, 0), gp_Dir(axisX, axisY, axisZ));
        gp_Trsf transform;
        transform.SetRotation(axis, angle);
        BRepBuilderAPI_Transform transformer(shape->shape, transform, Standard_True);
        return new OCCTShape(transformer.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeScale(OCCTShapeRef shape, double factor) {
    if (!shape) return nullptr;
    try {
        gp_Trsf transform;
        transform.SetScale(gp_Pnt(0, 0, 0), factor);
        BRepBuilderAPI_Transform transformer(shape->shape, transform, Standard_True);
        return new OCCTShape(transformer.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeMirror(OCCTShapeRef shape, double originX, double originY, double originZ, double normalX, double normalY, double normalZ) {
    if (!shape) return nullptr;
    try {
        gp_Ax2 mirrorPlane(gp_Pnt(originX, originY, originZ), gp_Dir(normalX, normalY, normalZ));
        gp_Trsf transform;
        transform.SetMirror(mirrorPlane);
        BRepBuilderAPI_Transform transformer(shape->shape, transform, Standard_True);
        return new OCCTShape(transformer.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Compound

OCCTShapeRef OCCTShapeCreateCompound(const OCCTShapeRef* shapes, int32_t count) {
    if (!shapes || count < 1) return nullptr;
    try {
        TopoDS_Compound compound;
        BRep_Builder builder;
        builder.MakeCompound(compound);

        for (int32_t i = 0; i < count; i++) {
            if (shapes[i]) {
                builder.Add(compound, shapes[i]->shape);
            }
        }

        return new OCCTShape(compound);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Validation

bool OCCTShapeIsValid(OCCTShapeRef shape) {
    if (!shape) return false;
    try {
        BRepCheck_Analyzer analyzer(shape->shape);
        return analyzer.IsValid();
    } catch (...) {
        return false;
    }
}

OCCTShapeRef OCCTShapeHeal(OCCTShapeRef shape) {
    if (!shape) return nullptr;
    try {
        Handle(ShapeFix_Shape) fixer = new ShapeFix_Shape(shape->shape);
        fixer->Perform();
        return new OCCTShape(fixer->Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Measurement & Analysis (v0.7.0)

OCCTShapeProperties OCCTShapeGetProperties(OCCTShapeRef shape, double density) {
    OCCTShapeProperties result = {};
    result.isValid = false;

    if (!shape) return result;

    try {
        // Volume
        GProp_GProps volumeProps;
        BRepGProp::VolumeProperties(shape->shape, volumeProps);

        result.volume = volumeProps.Mass();
        result.mass = result.volume * density;

        // Center of mass from bounding box (workaround for OCCT 8.0 GProp issue)
        Bnd_Box box;
        BRepBndLib::Add(shape->shape, box);
        if (!box.IsVoid()) {
            double xmin, ymin, zmin, xmax, ymax, zmax;
            box.Get(xmin, ymin, zmin, xmax, ymax, zmax);
            result.centerX = (xmin + xmax) / 2.0;
            result.centerY = (ymin + ymax) / 2.0;
            result.centerZ = (zmin + zmax) / 2.0;
        }

        // Inertia matrix (relative to center of mass)
        gp_Mat inertia = volumeProps.MatrixOfInertia();
        result.ixx = inertia.Value(1, 1) * density;
        result.ixy = inertia.Value(1, 2) * density;
        result.ixz = inertia.Value(1, 3) * density;
        result.iyx = inertia.Value(2, 1) * density;
        result.iyy = inertia.Value(2, 2) * density;
        result.iyz = inertia.Value(2, 3) * density;
        result.izx = inertia.Value(3, 1) * density;
        result.izy = inertia.Value(3, 2) * density;
        result.izz = inertia.Value(3, 3) * density;

        // Surface area
        GProp_GProps surfaceProps;
        BRepGProp::SurfaceProperties(shape->shape, surfaceProps);
        result.surfaceArea = surfaceProps.Mass();

        result.isValid = true;
    } catch (...) {
        // Return with isValid = false
    }

    return result;
}

double OCCTShapeGetVolume(OCCTShapeRef shape) {
    if (!shape) return -1.0;

    try {
        GProp_GProps props;
        BRepGProp::VolumeProperties(shape->shape, props);
        return props.Mass();
    } catch (...) {
        return -1.0;
    }
}

double OCCTShapeGetSurfaceArea(OCCTShapeRef shape) {
    if (!shape) return -1.0;

    try {
        GProp_GProps props;
        BRepGProp::SurfaceProperties(shape->shape, props);
        return props.Mass();
    } catch (...) {
        return -1.0;
    }
}

bool OCCTShapeGetCenterOfMass(OCCTShapeRef shape, double* outX, double* outY, double* outZ) {
    if (!shape || !outX || !outY || !outZ) return false;

    try {
        // Note: OCCT 8.0's GProp_GProps::CentreOfMass() appears to return (0,0,0)
        // for some shapes. As a workaround, compute centroid from bounding box center,
        // which is correct for solid primitives with uniform density.
        Bnd_Box box;
        BRepBndLib::Add(shape->shape, box);

        if (box.IsVoid()) return false;

        double xmin, ymin, zmin, xmax, ymax, zmax;
        box.Get(xmin, ymin, zmin, xmax, ymax, zmax);

        *outX = (xmin + xmax) / 2.0;
        *outY = (ymin + ymax) / 2.0;
        *outZ = (zmin + zmax) / 2.0;

        return true;
    } catch (...) {
        return false;
    }
}

OCCTDistanceResult OCCTShapeDistance(OCCTShapeRef shape1, OCCTShapeRef shape2, double deflection) {
    OCCTDistanceResult result = {};
    result.isValid = false;

    if (!shape1 || !shape2) return result;

    try {
        BRepExtrema_DistShapeShape distCalc(shape1->shape, shape2->shape, deflection);

        if (distCalc.IsDone() && distCalc.NbSolution() > 0) {
            result.distance = distCalc.Value();
            result.solutionCount = distCalc.NbSolution();

            // Get first solution points
            gp_Pnt p1 = distCalc.PointOnShape1(1);
            gp_Pnt p2 = distCalc.PointOnShape2(1);

            result.p1x = p1.X();
            result.p1y = p1.Y();
            result.p1z = p1.Z();
            result.p2x = p2.X();
            result.p2y = p2.Y();
            result.p2z = p2.Z();

            result.isValid = true;
        }
    } catch (...) {
        // Return with isValid = false
    }

    return result;
}

bool OCCTShapeIntersects(OCCTShapeRef shape1, OCCTShapeRef shape2, double tolerance) {
    if (!shape1 || !shape2) return false;

    try {
        BRepExtrema_DistShapeShape distCalc(shape1->shape, shape2->shape, tolerance);

        if (distCalc.IsDone() && distCalc.NbSolution() > 0) {
            return distCalc.Value() <= tolerance;
        }
        return false;
    } catch (...) {
        return false;
    }
}

int32_t OCCTShapeGetVertexCount(OCCTShapeRef shape) {
    if (!shape) return 0;

    try {
        // Use IndexedMapOfShape for unique vertices
        TopTools_IndexedMapOfShape vertexMap;
        TopExp::MapShapes(shape->shape, TopAbs_VERTEX, vertexMap);
        return vertexMap.Extent();
    } catch (...) {
        return 0;
    }
}

bool OCCTShapeGetVertexAt(OCCTShapeRef shape, int32_t index, double* outX, double* outY, double* outZ) {
    if (!shape || !outX || !outY || !outZ || index < 0) return false;

    try {
        // Use IndexedMapOfShape for unique vertices
        TopTools_IndexedMapOfShape vertexMap;
        TopExp::MapShapes(shape->shape, TopAbs_VERTEX, vertexMap);

        // IndexedMapOfShape uses 1-based indexing
        if (index >= vertexMap.Extent()) return false;

        TopoDS_Vertex vertex = TopoDS::Vertex(vertexMap(index + 1));
        gp_Pnt point = BRep_Tool::Pnt(vertex);
        *outX = point.X();
        *outY = point.Y();
        *outZ = point.Z();
        return true;
    } catch (...) {
        return false;
    }
}

int32_t OCCTShapeGetVertices(OCCTShapeRef shape, double* outVertices) {
    if (!shape || !outVertices) return 0;

    try {
        // Use IndexedMapOfShape for unique vertices
        TopTools_IndexedMapOfShape vertexMap;
        TopExp::MapShapes(shape->shape, TopAbs_VERTEX, vertexMap);

        int32_t count = vertexMap.Extent();
        for (int32_t i = 0; i < count; i++) {
            // IndexedMapOfShape uses 1-based indexing
            TopoDS_Vertex vertex = TopoDS::Vertex(vertexMap(i + 1));
            gp_Pnt point = BRep_Tool::Pnt(vertex);

            outVertices[i * 3] = point.X();
            outVertices[i * 3 + 1] = point.Y();
            outVertices[i * 3 + 2] = point.Z();
        }
        return count;
    } catch (...) {
        return 0;
    }
}

// MARK: - Bounds

void OCCTShapeGetBounds(OCCTShapeRef shape, double* minX, double* minY, double* minZ, double* maxX, double* maxY, double* maxZ) {
    if (!shape || !minX || !minY || !minZ || !maxX || !maxY || !maxZ) return;

    try {
        Bnd_Box box;
        BRepBndLib::Add(shape->shape, box);
        box.Get(*minX, *minY, *minZ, *maxX, *maxY, *maxZ);
    } catch (...) {
        *minX = *minY = *minZ = *maxX = *maxY = *maxZ = 0;
    }
}

// MARK: - Slicing

OCCTShapeRef OCCTShapeSliceAtZ(OCCTShapeRef shape, double z) {
    if (!shape) return nullptr;

    try {
        // Create a horizontal plane at height z
        gp_Pln plane(gp_Pnt(0, 0, z), gp_Dir(0, 0, 1));

        // Compute section (intersection of shape with plane)
        BRepAlgoAPI_Section section(shape->shape, plane);
        section.Build();

        if (!section.IsDone()) return nullptr;

        TopoDS_Shape result = section.Shape();
        if (result.IsNull()) return nullptr;

        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

int32_t OCCTShapeGetEdgeCount(OCCTShapeRef shape) {
    if (!shape) return 0;

    int32_t count = 0;
    TopExp_Explorer explorer(shape->shape, TopAbs_EDGE);
    while (explorer.More()) {
        count++;
        explorer.Next();
    }
    return count;
}

int32_t OCCTShapeGetEdgePoints(OCCTShapeRef shape, int32_t edgeIndex, double* outPoints, int32_t maxPoints) {
    if (!shape || !outPoints || maxPoints < 2 || edgeIndex < 0) return 0;

    try {
        // Use IndexedMap to match OCCTShapeGetTotalEdgeCount ordering
        TopTools_IndexedMapOfShape edgeMap;
        TopExp::MapShapes(shape->shape, TopAbs_EDGE, edgeMap);

        if (edgeIndex >= edgeMap.Extent()) return 0;

        TopoDS_Edge edge = TopoDS::Edge(edgeMap(edgeIndex + 1));  // OCCT is 1-based

        // Ensure 3D curve exists (lofted shapes may only have pcurves)
        BRepLib::BuildCurves3d(edge);

        // Get curve from edge
        Standard_Real first, last;
        Handle(Geom_Curve) curve = BRep_Tool::Curve(edge, first, last);
        if (curve.IsNull()) return 0;

        // Sample points along the curve
        int32_t numPoints = std::min(maxPoints, (int32_t)20);  // Max 20 points per edge
        for (int32_t i = 0; i < numPoints; i++) {
            double param = first + (last - first) * i / (numPoints - 1);
            gp_Pnt pt = curve->Value(param);
            outPoints[i * 3 + 0] = pt.X();
            outPoints[i * 3 + 1] = pt.Y();
            outPoints[i * 3 + 2] = pt.Z();
        }

        return numPoints;
    } catch (...) {
        return 0;
    }
}

// Get all edge endpoints as a simple contour (for toolpath generation)
int32_t OCCTShapeGetContourPoints(OCCTShapeRef shape, double* outPoints, int32_t maxPoints) {
    if (!shape || !outPoints || maxPoints < 1) return 0;

    try {
        int32_t pointCount = 0;

        TopExp_Explorer explorer(shape->shape, TopAbs_EDGE);
        while (explorer.More() && pointCount < maxPoints) {
            TopoDS_Edge edge = TopoDS::Edge(explorer.Current());

            // Get start and end vertices of the edge
            TopoDS_Vertex v1, v2;
            TopExp::Vertices(edge, v1, v2);

            if (!v1.IsNull()) {
                gp_Pnt pt = BRep_Tool::Pnt(v1);
                outPoints[pointCount * 3 + 0] = pt.X();
                outPoints[pointCount * 3 + 1] = pt.Y();
                outPoints[pointCount * 3 + 2] = pt.Z();
                pointCount++;
            }

            explorer.Next();
        }

        return pointCount;
    } catch (...) {
        return 0;
    }
}

// MARK: - CAM Operations

OCCTWireRef OCCTWireOffset(OCCTWireRef wire, double distance, int32_t joinType) {
    if (!wire) return nullptr;

    try {
        TopoDS_Wire theWire = wire->wire;

        // Create a planar face from the wire (required for BRepOffsetAPI_MakeOffset)
        BRepBuilderAPI_MakeFace faceMaker(theWire, Standard_True);
        if (!faceMaker.IsDone()) return nullptr;
        TopoDS_Face face = faceMaker.Face();

        // Select join type
        GeomAbs_JoinType join = (joinType == 0) ? GeomAbs_Arc : GeomAbs_Intersection;

        // Create offset using the face
        BRepOffsetAPI_MakeOffset offsetMaker(face, join);
        offsetMaker.Perform(distance);

        if (!offsetMaker.IsDone()) return nullptr;

        // Extract the offset wire from the result shape
        TopoDS_Shape result = offsetMaker.Shape();

        // The result may contain multiple wires - get the first one
        TopExp_Explorer explorer(result, TopAbs_WIRE);
        if (explorer.More()) {
            TopoDS_Wire resultWire = TopoDS::Wire(explorer.Current());
            return new OCCTWire(resultWire);
        }

        return nullptr;
    } catch (...) {
        return nullptr;
    }
}

OCCTWireRef* OCCTShapeSectionWiresAtZ(OCCTShapeRef shape, double z, double tolerance, int32_t* outCount) {
    if (!shape || !outCount) return nullptr;
    *outCount = 0;

    try {
        // Create horizontal cutting plane at Z level
        gp_Pln plane(gp_Pnt(0, 0, z), gp_Dir(0, 0, 1));

        // Compute section
        BRepAlgoAPI_Section section(shape->shape, plane);
        section.Build();
        if (!section.IsDone()) return nullptr;

        TopoDS_Shape sectionShape = section.Shape();
        if (sectionShape.IsNull()) return nullptr;

        // Collect edges from section result
        Handle(TopTools_HSequenceOfShape) edges = new TopTools_HSequenceOfShape;
        TopExp_Explorer explorer(sectionShape, TopAbs_EDGE);
        while (explorer.More()) {
            edges->Append(explorer.Current());
            explorer.Next();
        }

        if (edges->Length() == 0) return nullptr;

        // Connect edges into wires using ShapeAnalysis_FreeBounds
        Handle(TopTools_HSequenceOfShape) wires = new TopTools_HSequenceOfShape;
        ShapeAnalysis_FreeBounds::ConnectEdgesToWires(
            edges,
            tolerance,       // tolerance for connecting edges
            Standard_False,  // shared edges
            wires
        );

        int wireCount = wires->Length();
        if (wireCount == 0) return nullptr;

        // Allocate array for result
        OCCTWireRef* result = new OCCTWireRef[wireCount];
        for (int i = 1; i <= wireCount; i++) {
            TopoDS_Wire theWire = TopoDS::Wire(wires->Value(i));
            result[i - 1] = new OCCTWire(theWire);
        }

        *outCount = wireCount;
        return result;
    } catch (...) {
        return nullptr;
    }
}

void OCCTFreeWireArray(OCCTWireRef* wires, int32_t count) {
    if (!wires) return;
    for (int32_t i = 0; i < count; i++) {
        delete wires[i];
    }
    delete[] wires;
}

void OCCTFreeWireArrayOnly(OCCTWireRef* wires) {
    if (!wires) return;
    delete[] wires;
}

// MARK: - Face Analysis

OCCTFaceRef* OCCTShapeGetFaces(OCCTShapeRef shape, int32_t* outCount) {
    if (!shape || !outCount) return nullptr;
    *outCount = 0;

    try {
        // First, count faces
        std::vector<TopoDS_Face> faces;
        TopExp_Explorer explorer(shape->shape, TopAbs_FACE);
        while (explorer.More()) {
            faces.push_back(TopoDS::Face(explorer.Current()));
            explorer.Next();
        }

        if (faces.empty()) return nullptr;

        // Allocate array
        OCCTFaceRef* result = new OCCTFaceRef[faces.size()];
        for (size_t i = 0; i < faces.size(); i++) {
            result[i] = new OCCTFace(faces[i]);
        }

        *outCount = static_cast<int32_t>(faces.size());
        return result;
    } catch (...) {
        return nullptr;
    }
}

void OCCTFreeFaceArray(OCCTFaceRef* faces, int32_t count) {
    if (!faces) return;
    for (int32_t i = 0; i < count; i++) {
        delete faces[i];
    }
    delete[] faces;
}

void OCCTFreeFaceArrayOnly(OCCTFaceRef* faces) {
    if (!faces) return;
    delete[] faces;
}

void OCCTFaceRelease(OCCTFaceRef face) {
    delete face;
}

bool OCCTFaceGetNormal(OCCTFaceRef face, double* outNx, double* outNy, double* outNz) {
    if (!face || !outNx || !outNy || !outNz) return false;

    try {
        // Get surface from face
        BRepAdaptor_Surface adaptor(face->face);

        // Get parameter range
        double uMin, uMax, vMin, vMax;
        uMin = adaptor.FirstUParameter();
        uMax = adaptor.LastUParameter();
        vMin = adaptor.FirstVParameter();
        vMax = adaptor.LastVParameter();

        // Evaluate at center of parameter space
        double uMid = (uMin + uMax) / 2.0;
        double vMid = (vMin + vMax) / 2.0;

        // Get surface properties at center
        BRepLProp_SLProps props(adaptor, uMid, vMid, 1, 1e-6);
        if (!props.IsNormalDefined()) return false;

        gp_Dir normal = props.Normal();

        // Account for face orientation
        if (face->face.Orientation() == TopAbs_REVERSED) {
            normal.Reverse();
        }

        *outNx = normal.X();
        *outNy = normal.Y();
        *outNz = normal.Z();
        return true;
    } catch (...) {
        return false;
    }
}

OCCTWireRef OCCTFaceGetOuterWire(OCCTFaceRef face) {
    if (!face) return nullptr;

    try {
        TopoDS_Wire outerWire = BRepTools::OuterWire(face->face);
        if (outerWire.IsNull()) return nullptr;
        return new OCCTWire(outerWire);
    } catch (...) {
        return nullptr;
    }
}

void OCCTFaceGetBounds(OCCTFaceRef face, double* minX, double* minY, double* minZ, double* maxX, double* maxY, double* maxZ) {
    if (!face || !minX || !minY || !minZ || !maxX || !maxY || !maxZ) return;

    try {
        Bnd_Box box;
        BRepBndLib::Add(face->face, box);
        box.Get(*minX, *minY, *minZ, *maxX, *maxY, *maxZ);
    } catch (...) {
        *minX = *minY = *minZ = *maxX = *maxY = *maxZ = 0;
    }
}

bool OCCTFaceIsPlanar(OCCTFaceRef face) {
    if (!face) return false;

    try {
        BRepAdaptor_Surface adaptor(face->face);
        return adaptor.GetType() == GeomAbs_Plane;
    } catch (...) {
        return false;
    }
}

bool OCCTFaceGetZLevel(OCCTFaceRef face, double* outZ) {
    if (!face || !outZ) return false;

    try {
        BRepAdaptor_Surface adaptor(face->face);

        // Check if planar
        if (adaptor.GetType() != GeomAbs_Plane) return false;

        gp_Pln plane = adaptor.Plane();
        gp_Dir normal = plane.Axis().Direction();

        // Account for face orientation
        if (face->face.Orientation() == TopAbs_REVERSED) {
            normal.Reverse();
        }

        // Check if horizontal (normal is parallel to Z axis)
        double dotZ = std::abs(normal.Z());
        if (dotZ < 0.99) return false;  // Not horizontal enough

        // Get Z from plane location
        gp_Pnt location = plane.Location();
        *outZ = location.Z();
        return true;
    } catch (...) {
        return false;
    }
}

OCCTFaceRef* OCCTShapeGetHorizontalFaces(OCCTShapeRef shape, double tolerance, int32_t* outCount) {
    if (!shape || !outCount) return nullptr;
    *outCount = 0;

    try {
        std::vector<TopoDS_Face> horizontalFaces;

        TopExp_Explorer explorer(shape->shape, TopAbs_FACE);
        while (explorer.More()) {
            TopoDS_Face face = TopoDS::Face(explorer.Current());

            // Get normal at face center
            BRepAdaptor_Surface adaptor(face);
            double uMid = (adaptor.FirstUParameter() + adaptor.LastUParameter()) / 2.0;
            double vMid = (adaptor.FirstVParameter() + adaptor.LastVParameter()) / 2.0;

            BRepLProp_SLProps props(adaptor, uMid, vMid, 1, 1e-6);
            if (props.IsNormalDefined()) {
                gp_Dir normal = props.Normal();
                if (face.Orientation() == TopAbs_REVERSED) {
                    normal.Reverse();
                }

                // Check if horizontal (normal is nearly parallel to Z axis)
                double angleToZ = std::abs(normal.Z());
                if (angleToZ > std::cos(tolerance)) {
                    horizontalFaces.push_back(face);
                }
            }

            explorer.Next();
        }

        if (horizontalFaces.empty()) return nullptr;

        OCCTFaceRef* result = new OCCTFaceRef[horizontalFaces.size()];
        for (size_t i = 0; i < horizontalFaces.size(); i++) {
            result[i] = new OCCTFace(horizontalFaces[i]);
        }

        *outCount = static_cast<int32_t>(horizontalFaces.size());
        return result;
    } catch (...) {
        return nullptr;
    }
}

OCCTFaceRef* OCCTShapeGetUpwardFaces(OCCTShapeRef shape, double tolerance, int32_t* outCount) {
    if (!shape || !outCount) return nullptr;
    *outCount = 0;

    try {
        std::vector<TopoDS_Face> upwardFaces;

        TopExp_Explorer explorer(shape->shape, TopAbs_FACE);
        while (explorer.More()) {
            TopoDS_Face face = TopoDS::Face(explorer.Current());

            // Get normal at face center
            BRepAdaptor_Surface adaptor(face);
            double uMid = (adaptor.FirstUParameter() + adaptor.LastUParameter()) / 2.0;
            double vMid = (adaptor.FirstVParameter() + adaptor.LastVParameter()) / 2.0;

            BRepLProp_SLProps props(adaptor, uMid, vMid, 1, 1e-6);
            if (props.IsNormalDefined()) {
                gp_Dir normal = props.Normal();
                if (face.Orientation() == TopAbs_REVERSED) {
                    normal.Reverse();
                }

                // Check if upward-facing (normal Z > 0 and nearly vertical)
                if (normal.Z() > std::cos(tolerance)) {
                    upwardFaces.push_back(face);
                }
            }

            explorer.Next();
        }

        if (upwardFaces.empty()) return nullptr;

        OCCTFaceRef* result = new OCCTFaceRef[upwardFaces.size()];
        for (size_t i = 0; i < upwardFaces.size(); i++) {
            result[i] = new OCCTFace(upwardFaces[i]);
        }

        *outCount = static_cast<int32_t>(upwardFaces.size());
        return result;
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Edge Structure

struct OCCTEdge {
    TopoDS_Edge edge;
    
    OCCTEdge() {}
    OCCTEdge(const TopoDS_Edge& e) : edge(e) {}
};

OCCTEdgeRef OCCTEdgeFromShape(OCCTShapeRef shape) {
    if (!shape) return nullptr;
    try {
        if (shape->shape.IsNull()) return nullptr;
        if (shape->shape.ShapeType() != TopAbs_EDGE) return nullptr;
        return new OCCTEdge(TopoDS::Edge(shape->shape));
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTShapeFromEdge(OCCTEdgeRef edgeRef) {
    if (!edgeRef) return nullptr;
    return new OCCTShape(edgeRef->edge);
}

// MARK: - Ray Casting Implementation (Issue #12)

#include <IntCurvesFace_ShapeIntersector.hxx>
#include <gp_Lin.hxx>
#include <TopTools_IndexedMapOfShape.hxx>

int32_t OCCTShapeRaycast(
    OCCTShapeRef shape,
    double originX, double originY, double originZ,
    double dirX, double dirY, double dirZ,
    double tolerance,
    OCCTRayHit* outHits,
    int32_t maxHits
) {
    if (!shape || !outHits || maxHits <= 0) return -1;
    
    try {
        // Build face index map for looking up face indices
        TopTools_IndexedMapOfShape faceMap;
        TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);
        
        // Create ray
        gp_Pnt origin(originX, originY, originZ);
        gp_Dir direction(dirX, dirY, dirZ);
        gp_Lin ray(origin, direction);
        
        // Perform intersection
        IntCurvesFace_ShapeIntersector intersector;
        intersector.Load(shape->shape, tolerance);
        intersector.Perform(ray, -1e10, 1e10);  // Large range for ray
        
        int32_t hitCount = 0;
        int nbPoints = intersector.NbPnt();
        
        for (int i = 1; i <= nbPoints && hitCount < maxHits; i++) {
            gp_Pnt pt = intersector.Pnt(i);
            double param = intersector.WParameter(i);
            
            // Get face at this intersection
            TopoDS_Face hitFace = intersector.Face(i);
            int faceIndex = faceMap.FindIndex(hitFace) - 1;  // Convert to 0-based
            
            // Get UV parameters
            double u = intersector.UParameter(i);
            double v = intersector.VParameter(i);
            
            // Get surface normal at intersection point
            BRepAdaptor_Surface adaptor(hitFace);
            BRepLProp_SLProps props(adaptor, u, v, 1, tolerance);
            
            OCCTRayHit& hit = outHits[hitCount];
            hit.point[0] = pt.X();
            hit.point[1] = pt.Y();
            hit.point[2] = pt.Z();
            hit.distance = param;
            hit.faceIndex = faceIndex;
            hit.uv[0] = u;
            hit.uv[1] = v;
            
            if (props.IsNormalDefined()) {
                gp_Dir normal = props.Normal();
                if (hitFace.Orientation() == TopAbs_REVERSED) {
                    normal.Reverse();
                }
                hit.normal[0] = normal.X();
                hit.normal[1] = normal.Y();
                hit.normal[2] = normal.Z();
            } else {
                hit.normal[0] = 0;
                hit.normal[1] = 0;
                hit.normal[2] = 1;
            }
            
            hitCount++;
        }
        
        return hitCount;
    } catch (...) {
        return -1;
    }
}

// MARK: - Face Index Access (Issue #13)

int32_t OCCTShapeGetFaceCount(OCCTShapeRef shape) {
    if (!shape) return 0;
    
    try {
        TopTools_IndexedMapOfShape faceMap;
        TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);
        return faceMap.Extent();
    } catch (...) {
        return 0;
    }
}

OCCTFaceRef OCCTShapeGetFaceAtIndex(OCCTShapeRef shape, int32_t index) {
    if (!shape || index < 0) return nullptr;
    
    try {
        TopTools_IndexedMapOfShape faceMap;
        TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);
        
        if (index >= faceMap.Extent()) return nullptr;
        
        TopoDS_Face face = TopoDS::Face(faceMap(index + 1));  // OCCT is 1-based
        return new OCCTFace(face);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Edge Access (Issue #14)

int32_t OCCTShapeGetTotalEdgeCount(OCCTShapeRef shape) {
    if (!shape) return 0;
    
    try {
        TopTools_IndexedMapOfShape edgeMap;
        TopExp::MapShapes(shape->shape, TopAbs_EDGE, edgeMap);
        return edgeMap.Extent();
    } catch (...) {
        return 0;
    }
}

OCCTEdgeRef OCCTShapeGetEdgeAtIndex(OCCTShapeRef shape, int32_t index) {
    if (!shape || index < 0) return nullptr;
    
    try {
        TopTools_IndexedMapOfShape edgeMap;
        TopExp::MapShapes(shape->shape, TopAbs_EDGE, edgeMap);
        
        if (index >= edgeMap.Extent()) return nullptr;
        
        TopoDS_Edge edge = TopoDS::Edge(edgeMap(index + 1));  // OCCT is 1-based
        return new OCCTEdge(edge);
    } catch (...) {
        return nullptr;
    }
}

void OCCTEdgeRelease(OCCTEdgeRef edge) {
    delete edge;
}

double OCCTEdgeGetLength(OCCTEdgeRef edge) {
    if (!edge) return 0;
    
    try {
        GProp_GProps props;
        BRepGProp::LinearProperties(edge->edge, props);
        return props.Mass();  // For curves, Mass() returns length
    } catch (...) {
        return 0;
    }
}

void OCCTEdgeGetBounds(OCCTEdgeRef edge, double* minX, double* minY, double* minZ, double* maxX, double* maxY, double* maxZ) {
    if (!edge || !minX || !minY || !minZ || !maxX || !maxY || !maxZ) return;

    try {
        Bnd_Box box;
        BRepBndLib::Add(edge->edge, box);
        box.Get(*minX, *minY, *minZ, *maxX, *maxY, *maxZ);
    } catch (...) {
        *minX = *minY = *minZ = *maxX = *maxY = *maxZ = 0;
    }
}

int32_t OCCTEdgeGetPoints(OCCTEdgeRef edge, int32_t count, double* outPoints) {
    if (!edge || count <= 0 || !outPoints) return 0;

    try {
        BRepAdaptor_Curve curve(edge->edge);
        double first = curve.FirstParameter();
        double last = curve.LastParameter();

        for (int32_t i = 0; i < count; i++) {
            double t = (count == 1) ? first : first + (last - first) * i / (count - 1);
            gp_Pnt pt = curve.Value(t);
            outPoints[i * 3] = pt.X();
            outPoints[i * 3 + 1] = pt.Y();
            outPoints[i * 3 + 2] = pt.Z();
        }
        
        return count;
    } catch (...) {
        return 0;
    }
}

bool OCCTEdgeIsLine(OCCTEdgeRef edge) {
    if (!edge) return false;
    
    try {
        BRepAdaptor_Curve curve(edge->edge);
        return curve.GetType() == GeomAbs_Line;
    } catch (...) {
        return false;
    }
}

bool OCCTEdgeIsCircle(OCCTEdgeRef edge) {
    if (!edge) return false;
    
    try {
        BRepAdaptor_Curve curve(edge->edge);
        return curve.GetType() == GeomAbs_Circle;
    } catch (...) {
        return false;
    }
}

void OCCTEdgeGetEndpoints(OCCTEdgeRef edge, double* startX, double* startY, double* startZ, double* endX, double* endY, double* endZ) {
    if (!edge || !startX || !startY || !startZ || !endX || !endY || !endZ) return;

    try {
        TopoDS_Vertex v1, v2;
        TopExp::Vertices(edge->edge, v1, v2);
        
        gp_Pnt p1 = BRep_Tool::Pnt(v1);
        gp_Pnt p2 = BRep_Tool::Pnt(v2);
        
        *startX = p1.X();
        *startY = p1.Y();
        *startZ = p1.Z();
        *endX = p2.X();
        *endY = p2.Y();
        *endZ = p2.Z();
    } catch (...) {
        *startX = *startY = *startZ = *endX = *endY = *endZ = 0;
    }
}

// MARK: - AAG Support Implementation

#include <TopExp_Explorer.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <TopTools_IndexedDataMapOfShapeListOfShape.hxx>
#include <TopExp.hxx>
#include <TopTools_ListOfShape.hxx>
// TopTools_ListIteratorOfListOfShape.hxx removed in OCCT 8.0

int32_t OCCTEdgeGetAdjacentFaces(OCCTShapeRef shape, OCCTEdgeRef edge, OCCTFaceRef* outFace1, OCCTFaceRef* outFace2) {
    if (!shape || !edge || !outFace1 || !outFace2) return 0;
    
    *outFace1 = nullptr;
    *outFace2 = nullptr;
    
    try {
        // Build edge-to-face map
        TopTools_IndexedDataMapOfShapeListOfShape edgeFaceMap;
        TopExp::MapShapesAndAncestors(shape->shape, TopAbs_EDGE, TopAbs_FACE, edgeFaceMap);
        
        // Find faces for this edge
        if (!edgeFaceMap.Contains(edge->edge)) {
            return 0;
        }
        
        const TopTools_ListOfShape& faces = edgeFaceMap.FindFromKey(edge->edge);
        int32_t count = 0;
        
        TopTools_ListOfShape::Iterator it(faces);
        for (; it.More() && count < 2; it.Next()) {
            TopoDS_Face face = TopoDS::Face(it.Value());
            if (count == 0) {
                *outFace1 = new OCCTFace(face);
            } else {
                *outFace2 = new OCCTFace(face);
            }
            count++;
        }
        
        return count;
    } catch (...) {
        return 0;
    }
}

OCCTEdgeConvexity OCCTEdgeGetConvexity(OCCTShapeRef shape, OCCTEdgeRef edge, OCCTFaceRef face1, OCCTFaceRef face2) {
    if (!shape || !edge || !face1 || !face2) return OCCTEdgeConvexitySmooth;
    
    try {
        // Get the edge curve and midpoint
        BRepAdaptor_Curve edgeCurve(edge->edge);
        double midParam = (edgeCurve.FirstParameter() + edgeCurve.LastParameter()) / 2.0;
        gp_Pnt midPt = edgeCurve.Value(midParam);
        
        // Get surface adapters
        BRepAdaptor_Surface surf1(face1->face);
        BRepAdaptor_Surface surf2(face2->face);
        
        // Project point onto surfaces to get UV parameters
        Standard_Real u1, v1, u2, v2;
        
        // Use edge parameters on face - find the PCurve
        Standard_Real f, l;
        Handle(Geom2d_Curve) pcurve1 = BRep_Tool::CurveOnSurface(edge->edge, face1->face, f, l);
        Handle(Geom2d_Curve) pcurve2 = BRep_Tool::CurveOnSurface(edge->edge, face2->face, f, l);
        
        if (pcurve1.IsNull() || pcurve2.IsNull()) {
            return OCCTEdgeConvexitySmooth;
        }
        
        // Get UV at midpoint
        gp_Pnt2d uv1 = pcurve1->Value(midParam);
        gp_Pnt2d uv2 = pcurve2->Value(midParam);
        
        u1 = uv1.X(); v1 = uv1.Y();
        u2 = uv2.X(); v2 = uv2.Y();
        
        // Get normals at those points
        gp_Pnt p1, p2;
        gp_Vec d1u, d1v, d2u, d2v;
        surf1.D1(u1, v1, p1, d1u, d1v);
        surf2.D1(u2, v2, p2, d2u, d2v);
        
        gp_Vec n1 = d1u.Crossed(d1v);
        gp_Vec n2 = d2u.Crossed(d2v);
        
        if (n1.Magnitude() < 1e-10 || n2.Magnitude() < 1e-10) {
            return OCCTEdgeConvexitySmooth;
        }
        
        n1.Normalize();
        n2.Normalize();
        
        // Account for face orientation
        if (face1->face.Orientation() == TopAbs_REVERSED) {
            n1.Reverse();
        }
        if (face2->face.Orientation() == TopAbs_REVERSED) {
            n2.Reverse();
        }
        
        // Get edge tangent at midpoint
        gp_Vec tangent;
        gp_Pnt unused;
        edgeCurve.D1(midParam, unused, tangent);
        
        if (tangent.Magnitude() < 1e-10) {
            return OCCTEdgeConvexitySmooth;
        }
        tangent.Normalize();
        
        // Determine convexity:
        // Cross product of tangent with n1 gives direction "into" face1
        // If n2 points in same direction as this cross product, edge is concave
        gp_Vec intoFace1 = tangent.Crossed(n1);
        
        double dot = intoFace1.Dot(n2);
        
        // Threshold for smooth (nearly tangent)
        const double smoothThreshold = 0.01;  // ~0.5 degrees
        
        if (std::abs(dot) < smoothThreshold) {
            return OCCTEdgeConvexitySmooth;
        } else if (dot > 0) {
            return OCCTEdgeConvexityConcave;
        } else {
            return OCCTEdgeConvexityConvex;
        }
    } catch (...) {
        return OCCTEdgeConvexitySmooth;
    }
}

int32_t OCCTFaceGetSharedEdges(OCCTShapeRef shape, OCCTFaceRef face1, OCCTFaceRef face2, OCCTEdgeRef* outEdges, int32_t maxEdges) {
    if (!shape || !face1 || !face2 || !outEdges || maxEdges <= 0) return 0;
    
    try {
        // Get edges of both faces
        TopTools_IndexedMapOfShape edges1, edges2;
        TopExp::MapShapes(face1->face, TopAbs_EDGE, edges1);
        TopExp::MapShapes(face2->face, TopAbs_EDGE, edges2);
        
        int32_t count = 0;
        
        // Find common edges
        for (int i = 1; i <= edges1.Extent() && count < maxEdges; i++) {
            const TopoDS_Edge& e1 = TopoDS::Edge(edges1(i));
            
            for (int j = 1; j <= edges2.Extent(); j++) {
                const TopoDS_Edge& e2 = TopoDS::Edge(edges2(j));
                
                // Compare by IsEqual (same TShape)
                if (e1.IsSame(e2)) {
                    outEdges[count] = new OCCTEdge(e1);
                    count++;
                    break;
                }
            }
        }
        
        return count;
    } catch (...) {
        return 0;
    }
}

bool OCCTFacesAreAdjacent(OCCTShapeRef shape, OCCTFaceRef face1, OCCTFaceRef face2) {
    if (!shape || !face1 || !face2) return false;
    
    OCCTEdgeRef edges[1];
    int32_t count = OCCTFaceGetSharedEdges(shape, face1, face2, edges, 1);
    
    if (count > 0) {
        OCCTEdgeRelease(edges[0]);
        return true;
    }
    return false;
}

double OCCTEdgeGetDihedralAngle(OCCTEdgeRef edge, OCCTFaceRef face1, OCCTFaceRef face2, double parameter) {
    if (!edge || !face1 || !face2) return -1;
    
    try {
        // Get edge curve
        BRepAdaptor_Curve edgeCurve(edge->edge);
        double first = edgeCurve.FirstParameter();
        double last = edgeCurve.LastParameter();
        double param = first + parameter * (last - first);
        
        // Get PCurves on each face
        Standard_Real f, l;
        Handle(Geom2d_Curve) pcurve1 = BRep_Tool::CurveOnSurface(edge->edge, face1->face, f, l);
        Handle(Geom2d_Curve) pcurve2 = BRep_Tool::CurveOnSurface(edge->edge, face2->face, f, l);
        
        if (pcurve1.IsNull() || pcurve2.IsNull()) {
            return -1;
        }
        
        // Get UV at parameter
        gp_Pnt2d uv1 = pcurve1->Value(param);
        gp_Pnt2d uv2 = pcurve2->Value(param);
        
        // Get surface adapters and normals
        BRepAdaptor_Surface surf1(face1->face);
        BRepAdaptor_Surface surf2(face2->face);
        
        gp_Pnt p1, p2;
        gp_Vec d1u, d1v, d2u, d2v;
        surf1.D1(uv1.X(), uv1.Y(), p1, d1u, d1v);
        surf2.D1(uv2.X(), uv2.Y(), p2, d2u, d2v);
        
        gp_Vec n1 = d1u.Crossed(d1v);
        gp_Vec n2 = d2u.Crossed(d2v);
        
        if (n1.Magnitude() < 1e-10 || n2.Magnitude() < 1e-10) {
            return -1;
        }
        
        n1.Normalize();
        n2.Normalize();
        
        // Account for face orientation
        if (face1->face.Orientation() == TopAbs_REVERSED) {
            n1.Reverse();
        }
        if (face2->face.Orientation() == TopAbs_REVERSED) {
            n2.Reverse();
        }
        
        // Angle between normals
        double cosAngle = n1.Dot(n2);
        cosAngle = std::max(-1.0, std::min(1.0, cosAngle));  // Clamp
        
        // The dihedral angle is PI - acos(dot) for interior angle
        // Or we return the angle between normals directly
        return std::acos(cosAngle);
    } catch (...) {
        return -1;
    }
}

// MARK: - IGES Import/Export (v0.10.0)
// IGES reader/writer uses C-level global state (iges_newparam, iges_param, etc.)
// that is NOT thread-safe. All IGES operations MUST be serialized.
// See: https://github.com/Open-Cascade-SAS/OCCT/issues/1179
// Non-static (declared in OCCTBridge_Internal.h) so per-area TUs share the
// same underlying mutex via the linker.
std::mutex& igesMutex() {
    static std::mutex mutex;
    return mutex;
}

OCCTShapeRef OCCTImportIGES(const char* path) {
    if (!path) return nullptr;

    std::lock_guard<std::mutex> igesLock(igesMutex());
    try {
        IGESControl_Reader reader;
        IFSelect_ReturnStatus status = reader.ReadFile(path);
        if (status != IFSelect_RetDone) return nullptr;

        // Transfer all roots
        reader.TransferRoots();

        // Get the result as a single shape (compound if multiple)
        TopoDS_Shape shape = reader.OneShape();
        if (shape.IsNull()) return nullptr;

        return new OCCTShape(shape);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTImportIGESRobust(const char* path) {
    if (!path) return nullptr;

    std::lock_guard<std::mutex> igesLock(igesMutex());
    try {
        IGESControl_Reader reader;

        // Configure reader for better handling
        Interface_Static::SetIVal("read.precision.mode", 0);
        Interface_Static::SetRVal("read.precision.val", 0.0001);

        IFSelect_ReturnStatus status = reader.ReadFile(path);
        if (status != IFSelect_RetDone) return nullptr;

        if (reader.TransferRoots() == 0) return nullptr;

        TopoDS_Shape shape = reader.OneShape();
        if (shape.IsNull()) return nullptr;

        // Apply shape healing
        ShapeFix_Shape fixer(shape);
        fixer.Perform();
        TopoDS_Shape fixed = fixer.Shape();

        return new OCCTShape(fixed.IsNull() ? shape : fixed);
    } catch (...) {
        return nullptr;
    }
}

bool OCCTExportIGES(OCCTShapeRef shape, const char* path) {
    if (!shape || !path) return false;
    if (shape->shape.IsNull()) return false;

    std::lock_guard<std::mutex> igesLock(igesMutex());
    try {
        // Validate shape before IGES export — OCCT translator can segfault on invalid geometry
        BRepCheck_Analyzer analyzer(shape->shape);
        if (!analyzer.IsValid()) return false;

        bool success = false;
        {
            IGESControl_Writer writer("MM", 0);  // Millimeters, faces mode

            if (!writer.AddShape(shape->shape)) {
                return false;
            }

            writer.ComputeModel();
            success = writer.Write(path);
        }
        return success;
    } catch (...) {
        return false;
    }
}


// MARK: - BREP Native Format (v0.10.0)

OCCTShapeRef OCCTImportBREP(const char* path) {
    if (!path) return nullptr;

    try {
        TopoDS_Shape shape;
        BRep_Builder builder;

        if (!BRepTools::Read(shape, path, builder)) {
            return nullptr;
        }

        if (shape.IsNull()) return nullptr;

        return new OCCTShape(shape);
    } catch (...) {
        return nullptr;
    }
}

bool OCCTExportBREP(OCCTShapeRef shape, const char* path) {
    if (!shape || !path) return false;

    try {
        return BRepTools::Write(shape->shape, path);
    } catch (...) {
        return false;
    }
}

bool OCCTExportBREPWithTriangles(OCCTShapeRef shape, const char* path, bool withTriangles, bool withNormals) {
    if (!shape || !path) return false;

    try {
        return BRepTools::Write(shape->shape, path, withTriangles, withNormals, TopTools_FormatVersion_CURRENT);
    } catch (...) {
        return false;
    }
}


// MARK: - 2D Curve (Geom2d) — v0.16.0

#include <Geom2d_Curve.hxx>
#include <Geom2d_Line.hxx>
#include <Geom2d_Circle.hxx>
#include <Geom2d_Ellipse.hxx>
#include <Geom2d_Parabola.hxx>
#include <Geom2d_Hyperbola.hxx>
#include <Geom2d_TrimmedCurve.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <Geom2d_BezierCurve.hxx>
#include <Geom2d_OffsetCurve.hxx>
#include <GC_MakeSegment2d.hxx>
#include <GC_MakeCircle2d.hxx>
#include <GC_MakeArcOfCircle2d.hxx>
#include <GC_MakeEllipse2d.hxx>
#include <GC_MakeArcOfEllipse2d.hxx>
#include <GC_MakeParabola2d.hxx>
#include <GC_MakeHyperbola2d.hxx>
#include <Geom2dAdaptor_Curve.hxx>
#include <GCPnts_TangentialDeflection.hxx>
#include <GCPnts_UniformAbscissa.hxx>
#include <GCPnts_UniformDeflection.hxx>
#include <GCPnts_AbscissaPoint.hxx>
#include <Geom2dAPI_Interpolate.hxx>
#include <Geom2dAPI_PointsToBSpline.hxx>
#include <Geom2dAPI_InterCurveCurve.hxx>
#include <Geom2dAPI_ExtremaCurveCurve.hxx>
#include <Geom2dAPI_ProjectPointOnCurve.hxx>
#include <Geom2dConvert.hxx>
#include <Geom2dConvert_BSplineCurveToBezierCurve.hxx>
#include <Geom2dConvert_CompCurveToBSplineCurve.hxx>
#include <gp_Pnt2d.hxx>
#include <gp_Vec2d.hxx>
#include <gp_Dir2d.hxx>
#include <gp_Ax2d.hxx>
#include <gp_Ax22d.hxx>
#include <gp_Trsf2d.hxx>
#include <gp_Parab2d.hxx>
#include <gp_Hypr2d.hxx>
#include <TColgp_Array1OfPnt2d.hxx>
#include <TColgp_HArray1OfPnt2d.hxx>
#include <TColStd_HArray1OfReal.hxx>

struct OCCTCurve2D {
    Handle(Geom2d_Curve) curve;

    OCCTCurve2D() {}
    OCCTCurve2D(const Handle(Geom2d_Curve)& c) : curve(c) {}
};

// OCCTCurve3D — duplicated here because hatching / bisector / projection /
// curve evaluation in this TU still take + return Curve3D handles after
// the v0.19 ops moved to OCCTBridge_Curve3D.mm (issue #99). Identical
// layout, ODR-safe across TUs.
struct OCCTCurve3D {
    Handle(Geom_Curve) curve;

    OCCTCurve3D() {}
    OCCTCurve3D(const Handle(Geom_Curve)& c) : curve(c) {}
};

// OCCTSurface — duplicated here because surface-grid eval / projection /
// NLPlate / curve-on-surface utilities in this TU still access the
// surface->surface field after the v0.20 ops moved to
// OCCTBridge_Surface.mm (issue #99). Identical layout, ODR-safe.
struct OCCTSurface {
    Handle(Geom_Surface) surface;
    OCCTSurface() {}
    OCCTSurface(const Handle(Geom_Surface)& s) : surface(s) {}
};

// OCCTLawFunction — duplicated here because v0.29+ batch helpers still
// pass OCCTLawFunctionRef through after the v0.21 Law Functions moved
// to OCCTBridge_Laws_GDT.mm (issue #99). Identical layout, ODR-safe.
#include <Law_Function.hxx>
struct OCCTLawFunction {
    Handle(Law_Function) law;
    OCCTLawFunction() {}
    OCCTLawFunction(const Handle(Law_Function)& l) : law(l) {}
};

void OCCTCurve2DRelease(OCCTCurve2DRef c) {
    delete c;
}

// Properties

void OCCTCurve2DGetDomain(OCCTCurve2DRef c, double* first, double* last) {
    if (!c || c->curve.IsNull() || !first || !last) return;
    *first = c->curve->FirstParameter();
    *last = c->curve->LastParameter();
}

bool OCCTCurve2DIsClosed(OCCTCurve2DRef c) {
    if (!c || c->curve.IsNull()) return false;
    return c->curve->IsClosed() == Standard_True;
}

bool OCCTCurve2DIsPeriodic(OCCTCurve2DRef c) {
    if (!c || c->curve.IsNull()) return false;
    return c->curve->IsPeriodic() == Standard_True;
}

double OCCTCurve2DGetPeriod(OCCTCurve2DRef c) {
    if (!c || c->curve.IsNull()) return 0.0;
    if (!c->curve->IsPeriodic()) return 0.0;
    return c->curve->Period();
}

// Evaluation

void OCCTCurve2DGetPoint(OCCTCurve2DRef c, double u, double* x, double* y) {
    if (!c || c->curve.IsNull() || !x || !y) return;
    gp_Pnt2d p = c->curve->Value(u);
    *x = p.X();
    *y = p.Y();
}

void OCCTCurve2DD1(OCCTCurve2DRef c, double u,
                   double* px, double* py, double* vx, double* vy) {
    if (!c || c->curve.IsNull() || !px || !py || !vx || !vy) return;
    gp_Pnt2d p;
    gp_Vec2d v;
    c->curve->D1(u, p, v);
    *px = p.X(); *py = p.Y();
    *vx = v.X(); *vy = v.Y();
}

void OCCTCurve2DD2(OCCTCurve2DRef c, double u,
                   double* px, double* py,
                   double* v1x, double* v1y, double* v2x, double* v2y) {
    if (!c || c->curve.IsNull() || !px || !py || !v1x || !v1y || !v2x || !v2y) return;
    gp_Pnt2d p;
    gp_Vec2d v1, v2;
    c->curve->D2(u, p, v1, v2);
    *px = p.X(); *py = p.Y();
    *v1x = v1.X(); *v1y = v1.Y();
    *v2x = v2.X(); *v2y = v2.Y();
}

// Primitives

OCCTCurve2DRef OCCTCurve2DCreateLine(double px, double py, double dx, double dy) {
    try {
        gp_Pnt2d p(px, py);
        gp_Dir2d d(dx, dy);
        Handle(Geom2d_Line) line = new Geom2d_Line(p, d);
        return new OCCTCurve2D(line);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve2DRef OCCTCurve2DCreateSegment(double p1x, double p1y, double p2x, double p2y) {
    try {
        gp_Pnt2d p1(p1x, p1y);
        gp_Pnt2d p2(p2x, p2y);
        GC_MakeSegment2d maker(p1, p2);
        if (maker.Status() != gce_Done) return nullptr;
        return new OCCTCurve2D(maker.Value());
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve2DRef OCCTCurve2DCreateCircle(double cx, double cy, double radius) {
    try {
        if (radius <= 0) return nullptr;
        gp_Pnt2d center(cx, cy);
        gp_Ax2d axis(center, gp_Dir2d(1, 0));
        Handle(Geom2d_Circle) circle = new Geom2d_Circle(axis, radius);
        return new OCCTCurve2D(circle);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve2DRef OCCTCurve2DCreateArcOfCircle(double cx, double cy, double radius,
                                            double startAngle, double endAngle) {
    try {
        if (radius <= 0) return nullptr;
        gp_Pnt2d center(cx, cy);
        gp_Ax2d axis(center, gp_Dir2d(1, 0));
        Handle(Geom2d_Circle) circle = new Geom2d_Circle(axis, radius);
        Handle(Geom2d_TrimmedCurve) arc = new Geom2d_TrimmedCurve(circle, startAngle, endAngle);
        return new OCCTCurve2D(arc);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve2DRef OCCTCurve2DCreateArcThrough(double p1x, double p1y,
                                           double p2x, double p2y,
                                           double p3x, double p3y) {
    try {
        gp_Pnt2d p1(p1x, p1y);
        gp_Pnt2d p2(p2x, p2y);
        gp_Pnt2d p3(p3x, p3y);
        GC_MakeArcOfCircle2d maker(p1, p2, p3);
        if (maker.Status() != gce_Done) return nullptr;
        return new OCCTCurve2D(maker.Value());
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve2DRef OCCTCurve2DCreateEllipse(double cx, double cy,
                                        double majorR, double minorR, double rotation) {
    try {
        if (majorR <= 0 || minorR <= 0 || minorR > majorR) return nullptr;
        gp_Pnt2d center(cx, cy);
        gp_Dir2d majorDir(cos(rotation), sin(rotation));
        gp_Ax22d axes(center, majorDir);
        Handle(Geom2d_Ellipse) ellipse = new Geom2d_Ellipse(axes, majorR, minorR);
        return new OCCTCurve2D(ellipse);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve2DRef OCCTCurve2DCreateArcOfEllipse(double cx, double cy,
                                             double majorR, double minorR,
                                             double rotation,
                                             double startAngle, double endAngle) {
    try {
        if (majorR <= 0 || minorR <= 0 || minorR > majorR) return nullptr;
        gp_Pnt2d center(cx, cy);
        gp_Dir2d majorDir(cos(rotation), sin(rotation));
        gp_Ax22d axes(center, majorDir);
        Handle(Geom2d_Ellipse) ellipse = new Geom2d_Ellipse(axes, majorR, minorR);
        Handle(Geom2d_TrimmedCurve) arc = new Geom2d_TrimmedCurve(ellipse, startAngle, endAngle);
        return new OCCTCurve2D(arc);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve2DRef OCCTCurve2DCreateParabola(double fx, double fy,
                                         double dx, double dy, double focal) {
    try {
        if (focal <= 0) return nullptr;
        gp_Pnt2d mirrorP(fx - dx * focal, fy - dy * focal);
        gp_Dir2d dir(dx, dy);
        gp_Ax2d axis(mirrorP, dir);
        Handle(Geom2d_Parabola) parab = new Geom2d_Parabola(axis, focal);
        return new OCCTCurve2D(parab);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve2DRef OCCTCurve2DCreateHyperbola(double cx, double cy,
                                          double majorR, double minorR,
                                          double rotation) {
    try {
        if (majorR <= 0 || minorR <= 0) return nullptr;
        gp_Pnt2d center(cx, cy);
        gp_Dir2d majorDir(cos(rotation), sin(rotation));
        gp_Ax22d axes(center, majorDir);
        Handle(Geom2d_Hyperbola) hyp = new Geom2d_Hyperbola(axes, majorR, minorR);
        return new OCCTCurve2D(hyp);
    } catch (...) {
        return nullptr;
    }
}

// Draw (discretization)

int32_t OCCTCurve2DDrawAdaptive(OCCTCurve2DRef c, double angularDefl, double chordalDefl,
                                double* outXY, int32_t maxPoints) {
    if (!c || c->curve.IsNull() || !outXY || maxPoints <= 0) return 0;
    try {
        Geom2dAdaptor_Curve adaptor(c->curve);
        GCPnts_TangentialDeflection sampler(adaptor, angularDefl, chordalDefl);
        int32_t n = std::min((int32_t)sampler.NbPoints(), maxPoints);
        for (int32_t i = 0; i < n; i++) {
            double u = sampler.Parameter(i + 1);
            gp_Pnt2d p = adaptor.Value(u);
            outXY[i * 2] = p.X();
            outXY[i * 2 + 1] = p.Y();
        }
        return n;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTCurve2DDrawUniform(OCCTCurve2DRef c, int32_t pointCount, double* outXY) {
    if (!c || c->curve.IsNull() || !outXY || pointCount <= 0) return 0;
    try {
        Geom2dAdaptor_Curve adaptor(c->curve);
        GCPnts_UniformAbscissa sampler(adaptor, pointCount);
        if (!sampler.IsDone()) return 0;
        int32_t n = sampler.NbPoints();
        for (int32_t i = 0; i < n; i++) {
            double u = sampler.Parameter(i + 1);
            gp_Pnt2d p = adaptor.Value(u);
            outXY[i * 2] = p.X();
            outXY[i * 2 + 1] = p.Y();
        }
        return n;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTCurve2DDrawDeflection(OCCTCurve2DRef c, double deflection,
                                  double* outXY, int32_t maxPoints) {
    if (!c || c->curve.IsNull() || !outXY || maxPoints <= 0) return 0;
    try {
        Geom2dAdaptor_Curve adaptor(c->curve);
        GCPnts_UniformDeflection sampler(adaptor, deflection);
        if (!sampler.IsDone()) return 0;
        int32_t n = std::min((int32_t)sampler.NbPoints(), maxPoints);
        for (int32_t i = 0; i < n; i++) {
            double u = sampler.Parameter(i + 1);
            gp_Pnt2d p = adaptor.Value(u);
            outXY[i * 2] = p.X();
            outXY[i * 2 + 1] = p.Y();
        }
        return n;
    } catch (...) {
        return 0;
    }
}

// BSpline & Bezier

OCCTCurve2DRef OCCTCurve2DCreateBSpline(const double* poles, int32_t poleCount,
                                        const double* weights,
                                        const double* knots, int32_t knotCount,
                                        const int32_t* multiplicities, int32_t degree) {
    if (!poles || poleCount < 2 || !knots || knotCount < 2 || degree < 1) return nullptr;
    try {
        TColgp_Array1OfPnt2d polesArr(1, poleCount);
        for (int i = 0; i < poleCount; i++) {
            polesArr.SetValue(i + 1, gp_Pnt2d(poles[i * 2], poles[i * 2 + 1]));
        }

        TColStd_Array1OfReal weightsArr(1, poleCount);
        for (int i = 0; i < poleCount; i++) {
            weightsArr.SetValue(i + 1, weights ? weights[i] : 1.0);
        }

        TColStd_Array1OfReal knotsArr(1, knotCount);
        for (int i = 0; i < knotCount; i++) {
            knotsArr.SetValue(i + 1, knots[i]);
        }

        TColStd_Array1OfInteger multsArr(1, knotCount);
        for (int i = 0; i < knotCount; i++) {
            multsArr.SetValue(i + 1, multiplicities ? multiplicities[i] : 1);
        }

        Handle(Geom2d_BSplineCurve) bsp = new Geom2d_BSplineCurve(
            polesArr, weightsArr, knotsArr, multsArr, degree);
        return new OCCTCurve2D(bsp);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve2DRef OCCTCurve2DCreateBezier(const double* poles, int32_t poleCount,
                                       const double* weights) {
    if (!poles || poleCount < 2) return nullptr;
    try {
        TColgp_Array1OfPnt2d polesArr(1, poleCount);
        for (int i = 0; i < poleCount; i++) {
            polesArr.SetValue(i + 1, gp_Pnt2d(poles[i * 2], poles[i * 2 + 1]));
        }

        Handle(Geom2d_BezierCurve) bez;
        if (weights) {
            TColStd_Array1OfReal weightsArr(1, poleCount);
            for (int i = 0; i < poleCount; i++) {
                weightsArr.SetValue(i + 1, weights[i]);
            }
            bez = new Geom2d_BezierCurve(polesArr, weightsArr);
        } else {
            bez = new Geom2d_BezierCurve(polesArr);
        }
        return new OCCTCurve2D(bez);
    } catch (...) {
        return nullptr;
    }
}

// Interpolation & Fitting

OCCTCurve2DRef OCCTCurve2DInterpolate(const double* points, int32_t count,
                                      bool closed, double tolerance) {
    if (!points || count < 2) return nullptr;
    try {
        Handle(TColgp_HArray1OfPnt2d) pts = new TColgp_HArray1OfPnt2d(1, count);
        for (int i = 0; i < count; i++) {
            pts->SetValue(i + 1, gp_Pnt2d(points[i * 2], points[i * 2 + 1]));
        }
        Geom2dAPI_Interpolate interp(pts, closed ? Standard_True : Standard_False, tolerance);
        interp.Perform();
        if (!interp.IsDone()) return nullptr;
        return new OCCTCurve2D(interp.Curve());
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve2DRef OCCTCurve2DInterpolateWithTangents(const double* points, int32_t count,
                                                  double stx, double sty,
                                                  double etx, double ety,
                                                  double tolerance) {
    if (!points || count < 2) return nullptr;
    try {
        Handle(TColgp_HArray1OfPnt2d) pts = new TColgp_HArray1OfPnt2d(1, count);
        for (int i = 0; i < count; i++) {
            pts->SetValue(i + 1, gp_Pnt2d(points[i * 2], points[i * 2 + 1]));
        }
        Geom2dAPI_Interpolate interp(pts, Standard_False, tolerance);
        gp_Vec2d startTan(stx, sty);
        gp_Vec2d endTan(etx, ety);
        interp.Load(startTan, endTan);
        interp.Perform();
        if (!interp.IsDone()) return nullptr;
        return new OCCTCurve2D(interp.Curve());
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve2DRef OCCTCurve2DFitPoints(const double* points, int32_t count,
                                    int32_t minDeg, int32_t maxDeg, double tolerance) {
    if (!points || count < 2) return nullptr;
    try {
        TColgp_Array1OfPnt2d pts(1, count);
        for (int i = 0; i < count; i++) {
            pts.SetValue(i + 1, gp_Pnt2d(points[i * 2], points[i * 2 + 1]));
        }
        Geom2dAPI_PointsToBSpline fitter(pts, minDeg, maxDeg, GeomAbs_C2, tolerance);
        if (!fitter.IsDone()) return nullptr;
        return new OCCTCurve2D(fitter.Curve());
    } catch (...) {
        return nullptr;
    }
}

// BSpline queries

int32_t OCCTCurve2DGetPoleCount(OCCTCurve2DRef c) {
    if (!c || c->curve.IsNull()) return 0;
    Handle(Geom2d_BSplineCurve) bsp = Handle(Geom2d_BSplineCurve)::DownCast(c->curve);
    if (bsp.IsNull()) {
        Handle(Geom2d_BezierCurve) bez = Handle(Geom2d_BezierCurve)::DownCast(c->curve);
        if (bez.IsNull()) return 0;
        return bez->NbPoles();
    }
    return bsp->NbPoles();
}

int32_t OCCTCurve2DGetPoles(OCCTCurve2DRef c, double* outXY) {
    if (!c || c->curve.IsNull() || !outXY) return 0;
    Handle(Geom2d_BSplineCurve) bsp = Handle(Geom2d_BSplineCurve)::DownCast(c->curve);
    if (!bsp.IsNull()) {
        int n = bsp->NbPoles();
        for (int i = 1; i <= n; i++) {
            gp_Pnt2d p = bsp->Pole(i);
            outXY[(i - 1) * 2] = p.X();
            outXY[(i - 1) * 2 + 1] = p.Y();
        }
        return n;
    }
    Handle(Geom2d_BezierCurve) bez = Handle(Geom2d_BezierCurve)::DownCast(c->curve);
    if (!bez.IsNull()) {
        int n = bez->NbPoles();
        for (int i = 1; i <= n; i++) {
            gp_Pnt2d p = bez->Pole(i);
            outXY[(i - 1) * 2] = p.X();
            outXY[(i - 1) * 2 + 1] = p.Y();
        }
        return n;
    }
    return 0;
}

int32_t OCCTCurve2DGetDegree(OCCTCurve2DRef c) {
    if (!c || c->curve.IsNull()) return -1;
    Handle(Geom2d_BSplineCurve) bsp = Handle(Geom2d_BSplineCurve)::DownCast(c->curve);
    if (!bsp.IsNull()) return bsp->Degree();
    Handle(Geom2d_BezierCurve) bez = Handle(Geom2d_BezierCurve)::DownCast(c->curve);
    if (!bez.IsNull()) return bez->Degree();
    return -1;
}

// Operations

OCCTCurve2DRef OCCTCurve2DTrim(OCCTCurve2DRef c, double u1, double u2) {
    if (!c || c->curve.IsNull()) return nullptr;
    try {
        Handle(Geom2d_TrimmedCurve) trimmed = new Geom2d_TrimmedCurve(c->curve, u1, u2);
        return new OCCTCurve2D(trimmed);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve2DRef OCCTCurve2DOffset(OCCTCurve2DRef c, double distance) {
    if (!c || c->curve.IsNull()) return nullptr;
    try {
        Handle(Geom2d_OffsetCurve) oc = new Geom2d_OffsetCurve(c->curve, distance);
        return new OCCTCurve2D(oc);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve2DRef OCCTCurve2DReversed(OCCTCurve2DRef c) {
    if (!c || c->curve.IsNull()) return nullptr;
    try {
        Handle(Geom2d_Curve) rev = Handle(Geom2d_Curve)::DownCast(c->curve->Reversed());
        return new OCCTCurve2D(rev);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve2DRef OCCTCurve2DTranslate(OCCTCurve2DRef c, double dx, double dy) {
    if (!c || c->curve.IsNull()) return nullptr;
    try {
        Handle(Geom2d_Curve) copy = Handle(Geom2d_Curve)::DownCast(c->curve->Copy());
        gp_Vec2d v(dx, dy);
        copy->Translate(v);
        return new OCCTCurve2D(copy);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve2DRef OCCTCurve2DRotate(OCCTCurve2DRef c, double cx, double cy, double angle) {
    if (!c || c->curve.IsNull()) return nullptr;
    try {
        Handle(Geom2d_Curve) copy = Handle(Geom2d_Curve)::DownCast(c->curve->Copy());
        gp_Pnt2d center(cx, cy);
        copy->Rotate(center, angle);
        return new OCCTCurve2D(copy);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve2DRef OCCTCurve2DScale(OCCTCurve2DRef c, double cx, double cy, double factor) {
    if (!c || c->curve.IsNull()) return nullptr;
    try {
        Handle(Geom2d_Curve) copy = Handle(Geom2d_Curve)::DownCast(c->curve->Copy());
        gp_Pnt2d center(cx, cy);
        copy->Scale(center, factor);
        return new OCCTCurve2D(copy);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve2DRef OCCTCurve2DMirrorAxis(OCCTCurve2DRef c, double px, double py,
                                     double dx, double dy) {
    if (!c || c->curve.IsNull()) return nullptr;
    try {
        Handle(Geom2d_Curve) copy = Handle(Geom2d_Curve)::DownCast(c->curve->Copy());
        gp_Ax2d axis(gp_Pnt2d(px, py), gp_Dir2d(dx, dy));
        copy->Mirror(axis);
        return new OCCTCurve2D(copy);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve2DRef OCCTCurve2DMirrorPoint(OCCTCurve2DRef c, double px, double py) {
    if (!c || c->curve.IsNull()) return nullptr;
    try {
        Handle(Geom2d_Curve) copy = Handle(Geom2d_Curve)::DownCast(c->curve->Copy());
        gp_Pnt2d pt(px, py);
        copy->Mirror(pt);
        return new OCCTCurve2D(copy);
    } catch (...) {
        return nullptr;
    }
}

double OCCTCurve2DGetLength(OCCTCurve2DRef c) {
    if (!c || c->curve.IsNull()) return -1.0;
    try {
        Geom2dAdaptor_Curve adaptor(c->curve);
        return GCPnts_AbscissaPoint::Length(adaptor);
    } catch (...) {
        return -1.0;
    }
}

double OCCTCurve2DGetLengthBetween(OCCTCurve2DRef c, double u1, double u2) {
    if (!c || c->curve.IsNull()) return -1.0;
    try {
        Geom2dAdaptor_Curve adaptor(c->curve);
        return GCPnts_AbscissaPoint::Length(adaptor, u1, u2);
    } catch (...) {
        return -1.0;
    }
}

// Intersection

int32_t OCCTCurve2DIntersect(OCCTCurve2DRef c1, OCCTCurve2DRef c2, double tolerance,
                             OCCTCurve2DIntersection* out, int32_t max) {
    if (!c1 || c1->curve.IsNull() || !c2 || c2->curve.IsNull() || !out || max <= 0) return 0;
    try {
        Geom2dAPI_InterCurveCurve inter(c1->curve, c2->curve, tolerance);
        int32_t n = std::min((int32_t)inter.NbPoints(), max);
        for (int32_t i = 0; i < n; i++) {
            gp_Pnt2d p = inter.Point(i + 1);
            out[i].x = p.X();
            out[i].y = p.Y();
            // Parameters not directly available from this API for all intersection types
            out[i].u1 = 0;
            out[i].u2 = 0;
        }
        return n;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTCurve2DSelfIntersect(OCCTCurve2DRef c, double tolerance,
                                 OCCTCurve2DIntersection* out, int32_t max) {
    if (!c || c->curve.IsNull() || !out || max <= 0) return 0;
    try {
        Geom2dAPI_InterCurveCurve inter(c->curve, tolerance);
        int32_t n = std::min((int32_t)inter.NbPoints(), max);
        for (int32_t i = 0; i < n; i++) {
            gp_Pnt2d p = inter.Point(i + 1);
            out[i].x = p.X();
            out[i].y = p.Y();
            out[i].u1 = 0;
            out[i].u2 = 0;
        }
        return n;
    } catch (...) {
        return 0;
    }
}

// Projection

OCCTCurve2DProjection OCCTCurve2DProjectPoint(OCCTCurve2DRef c, double px, double py) {
    OCCTCurve2DProjection result = {0, 0, 0, -1};
    if (!c || c->curve.IsNull()) return result;
    try {
        gp_Pnt2d point(px, py);
        Geom2dAPI_ProjectPointOnCurve proj(point, c->curve);
        if (proj.NbPoints() == 0) return result;
        gp_Pnt2d nearest = proj.NearestPoint();
        result.x = nearest.X();
        result.y = nearest.Y();
        result.parameter = proj.LowerDistanceParameter();
        result.distance = proj.LowerDistance();
        return result;
    } catch (...) {
        return result;
    }
}

int32_t OCCTCurve2DProjectPointAll(OCCTCurve2DRef c, double px, double py,
                                   OCCTCurve2DProjection* out, int32_t max) {
    if (!c || c->curve.IsNull() || !out || max <= 0) return 0;
    try {
        gp_Pnt2d point(px, py);
        Geom2dAPI_ProjectPointOnCurve proj(point, c->curve);
        int32_t n = std::min((int32_t)proj.NbPoints(), max);
        for (int32_t i = 0; i < n; i++) {
            gp_Pnt2d p = proj.Point(i + 1);
            out[i].x = p.X();
            out[i].y = p.Y();
            out[i].parameter = proj.Parameter(i + 1);
            out[i].distance = proj.Distance(i + 1);
        }
        return n;
    } catch (...) {
        return 0;
    }
}

// Extrema

OCCTCurve2DExtrema OCCTCurve2DMinDistance(OCCTCurve2DRef c1, OCCTCurve2DRef c2) {
    OCCTCurve2DExtrema result = {0, 0, 0, 0, 0, 0, -1};
    if (!c1 || c1->curve.IsNull() || !c2 || c2->curve.IsNull()) return result;
    try {
        double u1min = c1->curve->FirstParameter();
        double u1max = c1->curve->LastParameter();
        double u2min = c2->curve->FirstParameter();
        double u2max = c2->curve->LastParameter();
        // Clamp infinite parameters for extrema computation
        if (u1min < -1e10) u1min = -1e10;
        if (u1max > 1e10) u1max = 1e10;
        if (u2min < -1e10) u2min = -1e10;
        if (u2max > 1e10) u2max = 1e10;
        Geom2dAPI_ExtremaCurveCurve ext(c1->curve, c2->curve,
                                        u1min, u1max, u2min, u2max);
        if (ext.NbExtrema() == 0) return result;
        gp_Pnt2d p1, p2;
        ext.NearestPoints(p1, p2);
        result.p1x = p1.X(); result.p1y = p1.Y();
        result.p2x = p2.X(); result.p2y = p2.Y();
        double u1, u2;
        ext.LowerDistanceParameters(u1, u2);
        result.u1 = u1;
        result.u2 = u2;
        result.distance = ext.LowerDistance();
        return result;
    } catch (...) {
        return result;
    }
}

int32_t OCCTCurve2DAllExtrema(OCCTCurve2DRef c1, OCCTCurve2DRef c2,
                              OCCTCurve2DExtrema* out, int32_t max) {
    if (!c1 || c1->curve.IsNull() || !c2 || c2->curve.IsNull() || !out || max <= 0) return 0;
    try {
        double u1min = c1->curve->FirstParameter();
        double u1max = c1->curve->LastParameter();
        double u2min = c2->curve->FirstParameter();
        double u2max = c2->curve->LastParameter();
        if (u1min < -1e10) u1min = -1e10;
        if (u1max > 1e10) u1max = 1e10;
        if (u2min < -1e10) u2min = -1e10;
        if (u2max > 1e10) u2max = 1e10;
        Geom2dAPI_ExtremaCurveCurve ext(c1->curve, c2->curve,
                                        u1min, u1max, u2min, u2max);
        int32_t n = std::min((int32_t)ext.NbExtrema(), max);
        for (int32_t i = 0; i < n; i++) {
            gp_Pnt2d p1, p2;
            ext.Points(i + 1, p1, p2);
            out[i].p1x = p1.X(); out[i].p1y = p1.Y();
            out[i].p2x = p2.X(); out[i].p2y = p2.Y();
            double u1, u2;
            ext.Parameters(i + 1, u1, u2);
            out[i].u1 = u1;
            out[i].u2 = u2;
            out[i].distance = ext.Distance(i + 1);
        }
        return n;
    } catch (...) {
        return 0;
    }
}

// Conversion

OCCTCurve2DRef OCCTCurve2DToBSpline(OCCTCurve2DRef c, double tolerance) {
    if (!c || c->curve.IsNull()) return nullptr;
    try {
        Handle(Geom2d_BSplineCurve) bsp = Geom2dConvert::CurveToBSplineCurve(c->curve);
        if (bsp.IsNull()) return nullptr;
        return new OCCTCurve2D(bsp);
    } catch (...) {
        return nullptr;
    }
}

int32_t OCCTCurve2DBSplineToBeziers(OCCTCurve2DRef c, OCCTCurve2DRef* out, int32_t max) {
    if (!c || c->curve.IsNull() || !out || max <= 0) return 0;
    try {
        Handle(Geom2d_BSplineCurve) bsp = Handle(Geom2d_BSplineCurve)::DownCast(c->curve);
        if (bsp.IsNull()) return 0;
        Geom2dConvert_BSplineCurveToBezierCurve converter(bsp);
        int32_t n = std::min((int32_t)converter.NbArcs(), max);
        for (int32_t i = 0; i < n; i++) {
            Handle(Geom2d_BezierCurve) arc = converter.Arc(i + 1);
            out[i] = new OCCTCurve2D(arc);
        }
        return n;
    } catch (...) {
        return 0;
    }
}

void OCCTCurve2DFreeArray(OCCTCurve2DRef* curves, int32_t count) {
    if (!curves) return;
    for (int32_t i = 0; i < count; i++) {
        delete curves[i];
    }
}

OCCTCurve2DRef OCCTCurve2DJoinToBSpline(const OCCTCurve2DRef* curves, int32_t count,
                                        double tolerance) {
    if (!curves || count <= 0) return nullptr;
    try {
        Geom2dConvert_CompCurveToBSplineCurve joiner;
        for (int32_t i = 0; i < count; i++) {
            if (!curves[i] || curves[i]->curve.IsNull()) continue;
            Handle(Geom2d_BSplineCurve) bsp = Geom2dConvert::CurveToBSplineCurve(curves[i]->curve);
            if (bsp.IsNull()) continue;
            joiner.Add(bsp, tolerance);
        }
        Handle(Geom2d_BSplineCurve) result = joiner.BSplineCurve();
        if (result.IsNull()) return nullptr;
        return new OCCTCurve2D(result);
    } catch (...) {
        return nullptr;
    }
}


// MARK: - Local Properties (Geom2dLProp)

#include <GeomLProp_CLProps.hxx>
#include <GeomLProp_CurAndInf2d.hxx>
#include <LProp_CurAndInf.hxx>
#include <LProp_CIType.hxx>
#include <Bnd_Box2d.hxx>
#include <BndLib_Add2dCurve.hxx>
#include <GC_MakeArcOfHyperbola2d.hxx>
#include <GC_MakeArcOfParabola2d.hxx>
#include <Geom2dConvert_ApproxCurve.hxx>
#include <Geom2dConvert_BSplineCurveKnotSplitting.hxx>
#include <Geom2dConvert_ApproxArcsSegments.hxx>
#include <Geom2d_CartesianPoint.hxx>
#include <Geom2dGcc_Circ2d3Tan.hxx>
#include <Geom2dGcc_Circ2d2TanRad.hxx>
#include <Geom2dGcc_Circ2dTanCen.hxx>
#include <Geom2dGcc_Lin2d2Tan.hxx>
#include <Geom2dGcc_QualifiedCurve.hxx>
#include <GccEnt_Position.hxx>

double OCCTCurve2DGetCurvature(OCCTCurve2DRef c, double u) {
    if (!c || c->curve.IsNull()) return 0.0;
    try {
        GeomLProp_CLProps2d props(c->curve, u, 2, Precision::Confusion());
        return props.Curvature();
    } catch (...) {
        return 0.0;
    }
}

bool OCCTCurve2DGetNormal(OCCTCurve2DRef c, double u, double* nx, double* ny) {
    if (!c || c->curve.IsNull() || !nx || !ny) return false;
    try {
        GeomLProp_CLProps2d props(c->curve, u, 2, Precision::Confusion());
        if (!props.IsTangentDefined()) return false;
        if (props.Curvature() < Precision::Confusion()) return false;
        gp_Dir2d n;
        props.Normal(n);
        *nx = n.X(); *ny = n.Y();
        return true;
    } catch (...) {
        return false;
    }
}

bool OCCTCurve2DGetTangentDir(OCCTCurve2DRef c, double u, double* tx, double* ty) {
    if (!c || c->curve.IsNull() || !tx || !ty) return false;
    try {
        GeomLProp_CLProps2d props(c->curve, u, 1, Precision::Confusion());
        if (!props.IsTangentDefined()) return false;
        gp_Dir2d t;
        props.Tangent(t);
        *tx = t.X(); *ty = t.Y();
        return true;
    } catch (...) {
        return false;
    }
}

bool OCCTCurve2DGetCenterOfCurvature(OCCTCurve2DRef c, double u, double* cx, double* cy) {
    if (!c || c->curve.IsNull() || !cx || !cy) return false;
    try {
        GeomLProp_CLProps2d props(c->curve, u, 2, Precision::Confusion());
        if (!props.IsTangentDefined()) return false;
        if (props.Curvature() < Precision::Confusion()) return false;
        gp_Pnt2d center;
        props.CentreOfCurvature(center);
        *cx = center.X(); *cy = center.Y();
        return true;
    } catch (...) {
        return false;
    }
}

int32_t OCCTCurve2DGetInflectionPoints(OCCTCurve2DRef c, double* outParams, int32_t max) {
    if (!c || c->curve.IsNull() || !outParams || max <= 0) return 0;
    try {
        GeomLProp_CurAndInf2d analyzer;
        analyzer.PerformInf(c->curve);
        if (!analyzer.IsDone()) return 0;
        int32_t n = 0;
        for (int i = 1; i <= analyzer.NbPoints() && n < max; i++) {
            if (analyzer.Type(i) == LProp_Inflection) {
                outParams[n++] = analyzer.Parameter(i);
            }
        }
        return n;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTCurve2DGetCurvatureExtrema(OCCTCurve2DRef c, OCCTCurve2DCurvePoint* out, int32_t max) {
    if (!c || c->curve.IsNull() || !out || max <= 0) return 0;
    try {
        GeomLProp_CurAndInf2d analyzer;
        analyzer.PerformCurExt(c->curve);
        if (!analyzer.IsDone()) return 0;
        int32_t n = 0;
        for (int i = 1; i <= analyzer.NbPoints() && n < max; i++) {
            out[n].parameter = analyzer.Parameter(i);
            LProp_CIType t = analyzer.Type(i);
            out[n].type = (t == LProp_MinCur) ? 1 : (t == LProp_MaxCur) ? 2 : 0;
            n++;
        }
        return n;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTCurve2DGetAllSpecialPoints(OCCTCurve2DRef c, OCCTCurve2DCurvePoint* out, int32_t max) {
    if (!c || c->curve.IsNull() || !out || max <= 0) return 0;
    try {
        GeomLProp_CurAndInf2d analyzer;
        analyzer.Perform(c->curve);
        if (!analyzer.IsDone()) return 0;
        int32_t n = std::min((int32_t)analyzer.NbPoints(), max);
        for (int i = 0; i < n; i++) {
            out[i].parameter = analyzer.Parameter(i + 1);
            LProp_CIType t = analyzer.Type(i + 1);
            out[i].type = (t == LProp_Inflection) ? 0 : (t == LProp_MinCur) ? 1 : 2;
        }
        return n;
    } catch (...) {
        return 0;
    }
}

// Bounding Box

bool OCCTCurve2DGetBoundingBox(OCCTCurve2DRef c, double* xMin, double* yMin,
                               double* xMax, double* yMax) {
    if (!c || c->curve.IsNull() || !xMin || !yMin || !xMax || !yMax) return false;
    try {
        Bnd_Box2d box;
        BndLib_Add2dCurve::Add(c->curve, 0.0, box);
        if (box.IsVoid()) return false;
        box.Get(*xMin, *yMin, *xMax, *yMax);
        return true;
    } catch (...) {
        return false;
    }
}

// Additional Arc Types

OCCTCurve2DRef OCCTCurve2DCreateArcOfHyperbola(double cx, double cy,
                                               double majorR, double minorR,
                                               double rotation,
                                               double startAngle, double endAngle) {
    try {
        if (majorR <= 0 || minorR <= 0) return nullptr;
        gp_Pnt2d center(cx, cy);
        gp_Dir2d majorDir(cos(rotation), sin(rotation));
        gp_Ax22d axes(center, majorDir);
        Handle(Geom2d_Hyperbola) hyp = new Geom2d_Hyperbola(axes, majorR, minorR);
        Handle(Geom2d_TrimmedCurve) arc = new Geom2d_TrimmedCurve(hyp, startAngle, endAngle);
        return new OCCTCurve2D(arc);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve2DRef OCCTCurve2DCreateArcOfParabola(double fx, double fy,
                                              double dx, double dy, double focal,
                                              double startParam, double endParam) {
    try {
        if (focal <= 0) return nullptr;
        gp_Pnt2d mirrorP(fx - dx * focal, fy - dy * focal);
        gp_Dir2d dir(dx, dy);
        gp_Ax2d axis(mirrorP, dir);
        Handle(Geom2d_Parabola) parab = new Geom2d_Parabola(axis, focal);
        Handle(Geom2d_TrimmedCurve) arc = new Geom2d_TrimmedCurve(parab, startParam, endParam);
        return new OCCTCurve2D(arc);
    } catch (...) {
        return nullptr;
    }
}

// Conversion Extras

OCCTCurve2DRef OCCTCurve2DApproximate(OCCTCurve2DRef c, double tolerance,
                                      int32_t continuity, int32_t maxSegments, int32_t maxDegree) {
    if (!c || c->curve.IsNull()) return nullptr;
    try {
        GeomAbs_Shape cont = GeomAbs_C2;
        switch (continuity) {
            case 0: cont = GeomAbs_C0; break;
            case 1: cont = GeomAbs_C1; break;
            case 2: cont = GeomAbs_C2; break;
            case 3: cont = GeomAbs_C3; break;
            default: cont = GeomAbs_C2; break;
        }
        Geom2dConvert_ApproxCurve approx(c->curve, tolerance, cont, maxSegments, maxDegree);
        if (!approx.HasResult()) return nullptr;
        Handle(Geom2d_BSplineCurve) result = approx.Curve();
        if (result.IsNull()) return nullptr;
        return new OCCTCurve2D(result);
    } catch (...) {
        return nullptr;
    }
}

int32_t OCCTCurve2DSplitAtDiscontinuities(OCCTCurve2DRef c, int32_t continuity,
                                          int32_t* outKnotIndices, int32_t max) {
    if (!c || c->curve.IsNull() || !outKnotIndices || max <= 0) return 0;
    try {
        Handle(Geom2d_BSplineCurve) bsp = Handle(Geom2d_BSplineCurve)::DownCast(c->curve);
        if (bsp.IsNull()) return 0;
        Geom2dConvert_BSplineCurveKnotSplitting splitter(bsp, continuity);
        int32_t n = std::min((int32_t)splitter.NbSplits(), max);
        TColStd_Array1OfInteger indices(1, splitter.NbSplits());
        splitter.Splitting(indices);
        for (int32_t i = 0; i < n; i++) {
            outKnotIndices[i] = indices(i + 1);
        }
        return n;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTCurve2DToArcsAndSegments(OCCTCurve2DRef c, double tolerance,
                                     double angleTol, OCCTCurve2DRef* out, int32_t max) {
    if (!c || c->curve.IsNull() || !out || max <= 0) return 0;
    try {
        // Approximate with arcs/segments using adaptor
        Geom2dAdaptor_Curve adaptor(c->curve);
        Geom2dConvert_ApproxArcsSegments converter(adaptor, tolerance, angleTol);
        const auto& result = converter.GetResult();
        int32_t n = std::min((int32_t)result.Size(), max);
        for (int32_t i = 0; i < n; i++) {
            out[i] = new OCCTCurve2D(result.Value(i + 1));
        }
        return n;
    } catch (...) {
        return 0;
    }
}

// MARK: - Issue #37: Parameter at Arc Length

double OCCTCurve2DParameterAtLength(OCCTCurve2DRef c, double arcLength, double fromParam) {
    if (!c || c->curve.IsNull()) return -DBL_MAX;
    try {
        Geom2dAdaptor_Curve adaptor(c->curve);
        GCPnts_AbscissaPoint solver(adaptor, arcLength, fromParam);
        if (!solver.IsDone()) return -DBL_MAX;
        return solver.Parameter();
    } catch (...) {
        return -DBL_MAX;
    }
}

// MARK: - Issue #38: Interpolate with Interior Tangent Constraints

OCCTCurve2DRef OCCTCurve2DInterpolateWithInteriorTangents(
    const double* points, int32_t count,
    const double* tangents, const bool* tangentFlags,
    bool closed, double tolerance) {
    if (!points || !tangents || !tangentFlags || count < 2) return nullptr;
    try {
        Handle(TColgp_HArray1OfPnt2d) pts = new TColgp_HArray1OfPnt2d(1, count);
        for (int i = 0; i < count; i++) {
            pts->SetValue(i + 1, gp_Pnt2d(points[i * 2], points[i * 2 + 1]));
        }
        Geom2dAPI_Interpolate interp(pts, closed ? Standard_True : Standard_False, tolerance);

        // Build tangent array and flags array
        NCollection_Array1<gp_Vec2d> tanVecs(1, count);
        Handle(NCollection_HArray1<bool>) tanFlags = new NCollection_HArray1<bool>(1, count);
        bool anyFlag = false;
        for (int i = 0; i < count; i++) {
            tanVecs.SetValue(i + 1, gp_Vec2d(tangents[i * 2], tangents[i * 2 + 1]));
            tanFlags->SetValue(i + 1, tangentFlags[i]);
            if (tangentFlags[i]) anyFlag = true;
        }
        if (anyFlag) {
            interp.Load(tanVecs, tanFlags);
        }
        interp.Perform();
        if (!interp.IsDone()) return nullptr;
        return new OCCTCurve2D(interp.Curve());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Issue #39: Lift 2D Curve to 3D Wire on a Plane

OCCTWireRef OCCTWireFromCurve2DOnPlane(OCCTCurve2DRef curve,
                                       double ox, double oy, double oz,
                                       double nx, double ny, double nz,
                                       double xx, double xy, double xz) {
    if (!curve || curve->curve.IsNull()) return nullptr;
    try {
        gp_Pnt origin(ox, oy, oz);
        gp_Dir normal(nx, ny, nz);
        gp_Dir xDir(xx, xy, xz);
        gp_Ax2 ax2(origin, normal, xDir);
        gp_Pln plane(ax2);

        // BRepBuilderAPI_MakeEdge accepts a Geom2d_Curve + Handle(Geom_Surface)
        Handle(Geom_Plane) surf = new Geom_Plane(plane);
        BRepBuilderAPI_MakeEdge maker(curve->curve, surf);
        if (!maker.IsDone()) return nullptr;
        TopoDS_Edge edge = maker.Edge();

        // Build the 3D curve representation from the pcurve on the plane surface
        BRepLib::BuildCurves3d(edge);

        BRepBuilderAPI_MakeWire wireMaker(edge);
        if (!wireMaker.IsDone()) return nullptr;

        auto* w = new OCCTWire();
        w->wire = wireMaker.Wire();
        return w;
    } catch (...) {
        return nullptr;
    }
}


// ============================================================================


#include <BRepOffset_Analyse.hxx>
#include <BRepOffset_Interval.hxx>
#include <ChFiDS_TypeOfConcavity.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <Geom_BSplineCurve.hxx>












#include <BRepExtrema_ExtPC.hxx>
#include <BRepExtrema_ExtCF.hxx>
#include <ShapeFix_FixSmallSolid.hxx>
#include <ShapeBuild_ReShape.hxx>
#include <ShapeAnalysis_FreeBoundsProperties.hxx>
#include <ShapeAnalysis_FreeBoundData.hxx>

// --- BRepExtrema_ExtPC ---










#include <GC_MakeArcOfHyperbola.hxx>
#include <GC_MakeArcOfParabola.hxx>
#include <GC_MakeConicalSurface.hxx>
#include <GC_MakeCylindricalSurface.hxx>
#include <GC_MakePlane.hxx>
#include <GC_MakeTrimmedCone.hxx>
#include <GC_MakeTrimmedCylinder.hxx>
#include <BRepExtrema_Poly.hxx>
#include <BRepTools_History.hxx>
#include <GeomConvert_BSplineSurfaceKnotSplitting.hxx>
#include <GeomConvert_CompBezierSurfacesToBSplineSurface.hxx>
#include <TColGeom_Array2OfBezierSurface.hxx>
#include <ShapeAnalysis_WireVertex.hxx>
#include <ShapeAnalysis_Geom.hxx>
#include <ShapeCustom_Curve.hxx>
#include <ShapeCustom_Surface.hxx>
#include <ShapeUpgrade_SplitCurve3d.hxx>
#include <ShapeUpgrade_SplitSurfaceContinuity.hxx>
#include <ShapeExtend_Status.hxx>
#include <TColGeom_HArray1OfCurve.hxx>
#include <TColStd_HSequenceOfReal.hxx>
#include <gp_Hypr.hxx>
#include <gp_Parab.hxx>
#include <gp_Circ.hxx>












#include <BRepLib_MakePolygon.hxx>
#include <BRepLib_MakeWire.hxx>
#include <BRepLib_MakeSolid.hxx>
#include <GC_MakeEllipse.hxx>
#include <GC_MakeHyperbola.hxx>
#include <GC_MakeMirror.hxx>
#include <GC_MakeRotation.hxx>
#include <GC_MakeScale.hxx>
#include <GC_MakeTranslation.hxx>
#include <GC_MakeLine2d.hxx>
#include <GC_MakeMirror2d.hxx>
#include <GC_MakeRotation2d.hxx>
#include <GC_MakeScale2d.hxx>
#include <GC_MakeTranslation2d.hxx>
#include <Geom_Ellipse.hxx>
#include <Geom_Hyperbola.hxx>
#include <Geom_Transformation.hxx>
#include <Geom2d_Transformation.hxx>
#include <ChFi2d_AnaFilletAlgo.hxx>

// --- BRepLib_MakePolygon ---







#include <BRepFill_Generator.hxx>
#include <BRepFill_AdvancedEvolved.hxx>
#include <BRepFill_OffsetWire.hxx>
#include <BRepFill_Draft.hxx>
#include <BRepFill_Pipe.hxx>
#include <BRepFill_CompatibleWires.hxx>
#include <ChFi2d_FilletAlgo.hxx>
#include <BRepTools_Substitution.hxx>
#include <ShapeUpgrade_ShellSewing.hxx>
#include <ShapeCustom_Curve2d.hxx>
#include <ShapeFix_SplitTool.hxx>
#include <LocOpe_BuildShape.hxx>
#include <LocOpe_CSIntersector.hxx>
#include <LocOpe_PntFace.hxx>
#include <Approx_Curve2d.hxx>
#include <Geom2dAdaptor_Curve.hxx>
#include <Adaptor2d_Curve2d.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <GeomFill_Trihedron.hxx>
#include <gp_Lin.hxx>
#include <NCollection_Sequence.hxx>

// --- BRepFill_Generator ---








// ============================================================================












#include <BOPAlgo_BuilderFace.hxx>
#include <BOPAlgo_BuilderSolid.hxx>
#include <BOPAlgo_ShellSplitter.hxx>
#include <BOPAlgo_Tools.hxx>
#include <BOPTools_AlgoTools.hxx>
#include <BOPTools_AlgoTools3D.hxx>
#include <BRepLib_MakeEdge.hxx>
#include <BRepLib_MakeFace.hxx>
#include <BRepLib_MakeShell.hxx>
#include <IntTools_CommonPrt.hxx>
#include <IntTools_Context.hxx>
#include <IntTools_Curve.hxx>
#include <IntTools_EdgeEdge.hxx>
#include <IntTools_EdgeFace.hxx>
#include <IntTools_FaceFace.hxx>
#include <IntTools_FClass2d.hxx>
#include <IntTools_PntOn2Faces.hxx>
#include <IntTools_Range.hxx>
#include <IntTools_SequenceOfCommonPrts.hxx>
#include <IntTools_SequenceOfCurves.hxx>
#include <IntTools_SequenceOfPntOn2Faces.hxx>
#include <ShapeCustom_SweptToElementary.hxx>
#include <BRepLib_ToolTriangulatedShape.hxx>
#include <BRepLib_PointCloudShape.hxx>
#include <BRepBuilderAPI_MakeEdge2d.hxx>
#include <BRepTools_Modifier.hxx>
#include <BRepTools_NurbsConvertModification.hxx>
#include <ShapeCustom_DirectModification.hxx>
#include <ShapeCustom_TrsfModification.hxx>
#include <LocOpe_BuildWires.hxx>
#include <LocOpe_WiresOnShape.hxx>
#include <LocOpe_Spliter.hxx>
#include <LocOpe_CurveShapeIntersector.hxx>
#include <ShapeUpgrade_ClosedFaceDivide.hxx>
#include <ShapeUpgrade_ShapeDivideAngle.hxx>
#include <ShapeUpgrade_ShapeDivideArea.hxx>
#include <CPnts_UniformDeflection.hxx>
#include <IntCurvesFace_ShapeIntersector.hxx>
#include <gp_Circ2d.hxx>
#include <gp_Lin2d.hxx>
#include <gp_Ax2d.hxx>
#include <gp_Pnt2d.hxx>
#include <gp_Dir2d.hxx>
#include <Poly_Triangulation.hxx>
#include <vector>















#include <GeomLProp_CLProps.hxx>
#include <GeomLProp_SLProps.hxx>
#include <BRepOffset_SimpleOffset.hxx>
#include <Approx_CurvilinearParameter.hxx>
#include <GeomInt_IntSS.hxx>
#include <Contap_Contour.hxx>
#include <Contap_Line.hxx>
#include <BRepTopAdaptor_TopolTool.hxx>
#include <BRepFeat_Builder.hxx>
#include <TopTools_ListOfShape.hxx>
#include <GeomFill_DraftTrihedron.hxx>
#include <GeomFill_DiscreteTrihedron.hxx>
#include <GeomFill_CorrectedFrenet.hxx>
#include <GeomFill_Coons.hxx>
#include <GeomFill_Curved.hxx>
#include <GeomFill_CoonsAlgPatch.hxx>
#include <GeomFill_SimpleBound.hxx>
#include <GeomFill_Sweep.hxx>
#include <GeomFill_CurveAndTrihedron.hxx>
#include <GeomFill_UniformSection.hxx>
#include <GeomFill_EvolvedSection.hxx>
#include <Law_Constant.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRep_Tool.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_Surface.hxx>
#include <IntSurf_PntOn2S.hxx>
#include <Contap_IType.hxx>
#include <Approx_MCurvesToBSpCurve.hxx>












#include <ProjLib_ComputeApprox.hxx>
#include <ProjLib_ComputeApproxOnPolarSurface.hxx>
#include <BRepOffset_Offset.hxx>
#include <Adaptor3d_IsoCurve.hxx>
#include <ShapeAnalysis_TransferParametersProj.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <Geom2d_BezierCurve.hxx>
#include <Geom2d_Curve.hxx>
#include <GeomAdaptor_Surface.hxx>










#include <LProp_CIType.hxx>




// --- LProp_AnalyticCurInf (inlined for RC5 — symbols removed from library) ---



#include <FairCurve_Batten.hxx>
#include <FairCurve_MinimalVariation.hxx>
#include <FairCurve_AnalysisCode.hxx>
#include <LocalAnalysis_CurveContinuity.hxx>
#include <LocalAnalysis_SurfaceContinuity.hxx>
#include <TopTrans_SurfaceTransition.hxx>
#include <TopAbs_State.hxx>
#include <TopAbs_Orientation.hxx>






#include <TopTrans_CurveTransition.hxx>
#include <GeomFill_Darboux.hxx>
#include <GeomFill_Fixed.hxx>
#include <GeomFill_Frenet.hxx>
#include <GeomFill_ConstantBiNormal.hxx>
#include <GeomFill_NSections.hxx>
#include <Geom_BSplineSurface.hxx>
#include <NCollection_Sequence.hxx>
#include <Law_BSplineKnotSplitting.hxx>
#include <Law_Composite.hxx>
#include <Law_Linear.hxx>
#include <Law_Interpol.hxx>
#include <Law_BSpFunc.hxx>
#include <Law_BSpline.hxx>
#include <GccAna_Circ2d3Tan.hxx>
#include <GccEnt.hxx>
#include <GccEnt_QualifiedCirc.hxx>
#include <GccEnt_QualifiedLin.hxx>
#include <Intf_InterferencePolygon2d.hxx>
#include <Intf_Polygon2d.hxx>
#include <BRepAdaptor_Surface.hxx>








#include <NLPlate_HPG0G2Constraint.hxx>
#include <NLPlate_HPG0G3Constraint.hxx>
#include <Plate_Plate.hxx>
#include <Plate_PinpointConstraint.hxx>
#include <Plate_GtoCConstraint.hxx>
#include <Plate_D1.hxx>
#include <Plate_D2.hxx>
#include <Plate_D3.hxx>
#include <GeomFill_Generator.hxx>
#include <GeomFill_DegeneratedBound.hxx>
#include <GeomFill_BoundWithSurf.hxx>
#include <Adaptor3d_CurveOnSurface.hxx>
#include <GeomAdaptor_Surface.hxx>
#include <Geom2dAdaptor_Curve.hxx>











#include <HLRAppli_ReflectLines.hxx>
#include <HLRBRep_TypeOfResultingEdge.hxx>
#include <TopCnx_EdgeFaceTransition.hxx>
#include <Intrv_Interval.hxx>
#include <Intrv_Intervals.hxx>
#include <BRepMesh_IncrementalMesh.hxx>






//                   ShapeCustom_Surface (periodic), BRepGProp_MeshCinert/MeshProps,
//                   BRepMesh_ShapeTool, BRepLib_ValidateEdge

#include <BRepIntCurveSurface_Inter.hxx>
#include <Geom_Line.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <ShapeConstruct_MakeTriangulation.hxx>
#include <NCollection_Array1.hxx>
#include <BRepGProp_MeshCinert.hxx>
#include <BRepGProp_MeshProps.hxx>
#include <BRepMesh_ShapeTool.hxx>
#include <BRepLib_ValidateEdge.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <Bnd_Box.hxx>
#include <BRepBndLib.hxx>







//                   BRepGProp_Cinert/Sinert/Vinert, ShapeConstruct_ProjectCurveOnSurface,
//                   BRepPreviewAPI_MakeBox

#include <BiTgte_Blend.hxx>
#include <GeomConvert_ApproxCurve.hxx>
#include <GeomConvert_ApproxSurface.hxx>
#include <GCPnts_QuasiUniformAbscissa.hxx>
#include <GCPnts_TangentialDeflection.hxx>
#include <BRepGProp_Cinert.hxx>
#include <BRepGProp_Sinert.hxx>
#include <BRepGProp_Vinert.hxx>
#include <BRepGProp_Face.hxx>
#include <BRepPreviewAPI_MakeBox.hxx>
#include <ShapeConstruct_ProjectCurveOnSurface.hxx>
#include <Geom2d_Curve.hxx>







// =============================================================================
// =============================================================================

#include <Geom_CartesianPoint.hxx>
#include <Geom_Direction.hxx>
#include <Geom_VectorWithMagnitude.hxx>
#include <Geom_Axis1Placement.hxx>
#include <Geom_Axis2Placement.hxx>
#include <Geom_Point.hxx>
#include <Geom_Vector.hxx>
#include <ShapeConstruct_Curve.hxx>
#include <Bisector_Inter.hxx>
#include <Bisector_Bisec.hxx>
#include <Bisector_PointOnBis.hxx>
#include <Bisector_PolyBis.hxx>
#include <IntRes2d_Domain.hxx>
#include <IntRes2d_IntersectionPoint.hxx>
#include <Geom2d_CartesianPoint.hxx>









#include <GeomLib_Tool.hxx>
#include <GeomLib_IsPlanarSurface.hxx>
#include <GeomLib_CheckBSplineCurve.hxx>
#include <GeomLib_Check2dBSplineCurve.hxx>
#include <GeomLib_Interpolate.hxx>














#include <BRepTools_GTrsfModification.hxx>
#include <BRepTools_TrsfModification.hxx>
#include <BRepTools_CopyModification.hxx>
#include <ShapeCustom_BSplineRestriction.hxx>
#include <ShapeCustom_ConvertToBSpline.hxx>
#include <ShapeCustom_ConvertToRevolution.hxx>
#include <ShapeUpgrade_SplitSurfaceContinuity.hxx>
#include <ShapeUpgrade_SplitSurfaceAngle.hxx>
#include <ShapeUpgrade_SplitSurfaceArea.hxx>
#include <GeomConvert_CurveToAnaCurve.hxx>
#include <GeomConvert_SurfToAnaSurf.hxx>
#include <Geom2dConvert_ApproxArcsSegments.hxx>
#include <Geom2dAdaptor_Curve.hxx>
#include <Poly_Polygon2D.hxx>
#include <Poly_Polygon3D.hxx>
#include <Poly_PolygonOnTriangulation.hxx>
#include <Poly_MergeNodesTool.hxx>











#include <Poly_CoherentTriangulation.hxx>
#include <Poly_CoherentNode.hxx>
#include <Poly_CoherentTriangle.hxx>
#include <Poly_CoherentLink.hxx>

#include <BRepFill_Evolved.hxx>
#include <BRepFill_OffsetAncestors.hxx>
#include <BRepFill_OffsetWire.hxx>
#include <BRepFill_NSections.hxx>

#include <BRepExtrema_DistanceSS.hxx>
#include <BRepExtrema_SolutionElem.hxx>

#include <BRepGProp_VinertGK.hxx>

#include <GeomFill_Profiler.hxx>
#include <GeomFill_Stretch.hxx>
#include <GeomFill_LocationDraft.hxx>
#include <GeomFill_GuideTrihedronAC.hxx>
#include <GeomFill_GuideTrihedronPlan.hxx>
#include <GeomFill_SectionPlacement.hxx>
#include <GeomFill_AppSurf.hxx>
#include <GeomFill_SectionGenerator.hxx>
#include <GeomFill_Line.hxx>

#include <ShapeFix_ComposeShell.hxx>
#include <ShapeExtend_CompositeSurface.hxx>
















#include <Extrema_ExtCC.hxx>
#include <Extrema_ExtCS.hxx>
#include <Extrema_ExtPS.hxx>
#include <Extrema_ExtSS.hxx>
#include <Extrema_LocateExtCC.hxx>
#include <Extrema_LocateExtCC2d.hxx>
#include <Extrema_POnCurv.hxx>
#include <Extrema_POnCurv2d.hxx>
#include <Extrema_POnSurf.hxx>
#include <GeomTools_CurveSet.hxx>
#include <GeomTools_Curve2dSet.hxx>
#include <GeomTools_SurfaceSet.hxx>
#include <ProjLib_ProjectOnSurface.hxx>
#include <gce_MakeCirc.hxx>
#include <gce_MakeCone.hxx>
#include <gce_MakeCylinder.hxx>
#include <gce_MakeLin.hxx>
#include <gce_MakePln.hxx>
#include <gce_MakeDir.hxx>
#include <gce_MakeElips.hxx>
#include <gce_MakeHypr.hxx>
#include <gce_MakeParab.hxx>
#include <gce_MakeCirc2d.hxx>
#include <gce_MakeLin2d.hxx>
#include <gce_MakeElips2d.hxx>
#include <gce_MakeHypr2d.hxx>
#include <gce_MakeParab2d.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Ellipse.hxx>
#include <Geom_Hyperbola.hxx>
#include <Geom_Parabola.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_ConicalSurface.hxx>
#include <Geom2d_Circle.hxx>
#include <Geom2d_Ellipse.hxx>
#include <Geom2d_Hyperbola.hxx>
#include <Geom2d_Parabola.hxx>
#include <Geom2dAdaptor_Curve.hxx>
#include <sstream>















// =============================================================================
//         XCAFDimTolObjects_Tool, TPrsStd_DriverTable, TObj_Application
// =============================================================================

#include <VrmlAPI_Writer.hxx>
#include <VrmlAPI_RepresentationOfShape.hxx>
#include <TDataStd_Directory.hxx>
#include <TDataStd_Variable.hxx>
#include <TDataStd_Expression.hxx>
#include <TDocStd_XLink.hxx>
#include <XCAFDimTolObjects_Tool.hxx>
#include <TPrsStd_DriverTable.hxx>
#include <TObj_Application.hxx>
#include <TDF_TagSource.hxx>

// Helper to get label from document ref + tag
static TDF_Label getLabelForTag(OCCTDocumentRef document, int tag) {
    if (tag == 0) return document->doc->Main();
    return document->doc->Main().FindChild(tag, Standard_True);
}


// =============================================================================
// =============================================================================

#include <UnitsAPI.hxx>
#include <UnitsAPI_SystemUnits.hxx>
#include <BinTools_ShapeReader.hxx>
#include <BinTools_ShapeWriter.hxx>
#include <Message_Messenger.hxx>
#include <Message_Report.hxx>
#include <Message_PrinterOStream.hxx>
#include <Message_Gravity.hxx>
#include <RWMesh_CoordinateSystemConverter.hxx>
#include <RWMesh_CoordinateSystem.hxx>
#include <TDF_IDFilter.hxx>

#include <sstream>
#include <fstream>






















































//                    Geom_OffsetCurve basis, APIHeaderSection_MakeHeader, ShapeAnalysis_FreeBounds simplified

#include <RWStl.hxx>
#include <APIHeaderSection_MakeHeader.hxx>
#include <TCollection_HAsciiString.hxx>
#include <Geom_OffsetCurve.hxx>








#include <Geom_TrimmedCurve.hxx>
#include <BRepLib_FindSurface.hxx>
#include <ShapeAnalysis_Surface.hxx>
#include <Resource_Manager.hxx>
#include <GProp_SelGProps.hxx>
#include <GProp_VelGProps.hxx>
#include <IntAna_Quadric.hxx>
#include <IntAna_IntQuadQuad.hxx>
#include <XCAFPrs_DocumentExplorer.hxx>
#include <GProp_PGProps.hxx>































































































#include <RWMesh_FaceIterator.hxx>
#include <RWMesh_VertexIterator.hxx>
#include <Intf_Tool.hxx>
#include <BiTgte_CurveOnEdge.hxx>
#include <BRepAlgo_AsDes.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepCheck_Result.hxx>
#include <ShapeAnalysis_ShapeTolerance.hxx>
#include <ShapeFix_ShapeTolerance.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <Geom2dAdaptor_Curve.hxx>
#include <GeomAdaptor_Surface.hxx>
#include <Extrema_GenLocateExtPS.hxx>
#include <GeomAPI_ProjectPointOnCurve.hxx>
#include <GeomAPI_ProjectPointOnSurf.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_MakeShell.hxx>
#include <TopoDS_Iterator.hxx>
#include <TopAbs.hxx>
#include <gp_Lin.hxx>
#include <Bnd_Box.hxx>












#include <gp_Elips.hxx>
#include <gp_Hypr.hxx>
#include <gp_Parab.hxx>
#include <Geom_Ellipse.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <GeomAPI_ProjectPointOnCurve.hxx>
#include <GeomAPI_ProjectPointOnSurf.hxx>
#include <GeomAPI_IntCS.hxx>
#include <BRepExtrema_DistShapeShape.hxx>
#include <ShapeFix_Wire.hxx>
#include <ShapeFix_Face.hxx>
#include <TopExp.hxx>
#include <TopoDS.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_BSplineSurface.hxx>
#include <gp_Pln.hxx>
#include <gp_Cylinder.hxx>


























#include <GeomAPI_Interpolate.hxx>
#include <Geom2dAPI_Interpolate.hxx>
#include <GeomAPI_PointsToBSpline.hxx>
#include <Geom2dAPI_PointsToBSpline.hxx>
#include <GeomAPI_PointsToBSplineSurface.hxx>
#include <GeomConvert.hxx>
#include <Geom2dConvert.hxx>
#include <GeomConvert_CompCurveToBSplineCurve.hxx>
#include <BRepBuilderAPI_GTransform.hxx>
#include <BRepAlgoAPI_Splitter.hxx>
#include <BRepAlgoAPI_Defeaturing.hxx>
#include <ShapeFix_Shape.hxx>
#include <Poly_Triangulation.hxx>
#include <BRep_Tool.hxx>
#include <TopLoc_Location.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <GCPnts_AbscissaPoint.hxx>
#include <Bnd_OBB.hxx>
#include <BRepBndLib.hxx>
#include <GProp_GProps.hxx>
#include <BRepGProp.hxx>
#include <ShapeAnalysis_ShapeTolerance.hxx>
#include <ShapeAnalysis_FreeBounds.hxx>
#include <GeomAPI_ProjectPointOnCurve.hxx>
#include <GeomAPI_ProjectPointOnSurf.hxx>
#include <GeomLProp_CLProps.hxx>
#include <BRepLProp_SLProps.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <Geom2d_TrimmedCurve.hxx>
#include <Geom_BSplineSurface.hxx>
#include <TColgp_HArray1OfPnt.hxx>
#include <TColgp_HArray1OfPnt2d.hxx>
#include <TColgp_HArray1OfVec.hxx>
#include <TColgp_HArray1OfVec2d.hxx>
#include <TColStd_HArray1OfBoolean.hxx>
#include <TColStd_HArray1OfReal.hxx>
#include <TColgp_Array1OfPnt2d.hxx>
#include <TColgp_Array2OfPnt.hxx>
#include <gp_GTrsf.hxx>
#include <Geom2dAdaptor_Curve.hxx>
#include <GCPnts_AbscissaPoint.hxx>
#include <TopTools_ListOfShape.hxx>

























// === BRepBndLib ===
#include <BRepBndLib.hxx>


#include <BRepAlgoAPI_Check.hxx>














// =============================================================================
// =============================================================================






#include <ShapeFix_Edge.hxx>
#include <TopTools_IndexedMapOfShape.hxx>











// MARK: - v0.126.0 implementations

// --- BRep_Tool completions ---

#import <BRep_Tool.hxx>
#import <Geom2d_Curve.hxx>

OCCTCurve2DRef OCCTBRepToolCurveOnSurface(OCCTShapeRef edge, OCCTShapeRef face,
                                           double* outFirst, double* outLast) {
    if (!edge || !face) return nullptr;
    try {
        const TopoDS_Edge& e = TopoDS::Edge(edge->shape);
        const TopoDS_Face& f = TopoDS::Face(face->shape);
        double first, last;
        auto c2d = BRep_Tool::CurveOnSurface(e, f, first, last);
        if (c2d.IsNull()) return nullptr;
        *outFirst = first;
        *outLast = last;
        auto* result = new OCCTCurve2D();
        result->curve = c2d;
        return result;
    } catch (...) { return nullptr; }
}

bool OCCTBRepToolHasContinuity(OCCTShapeRef edge, OCCTShapeRef face1, OCCTShapeRef face2) {
    if (!edge || !face1 || !face2) return false;
    try {
        const TopoDS_Edge& e = TopoDS::Edge(edge->shape);
        const TopoDS_Face& f1 = TopoDS::Face(face1->shape);
        const TopoDS_Face& f2 = TopoDS::Face(face2->shape);
        return BRep_Tool::HasContinuity(e, f1, f2);
    } catch (...) { return false; }
}

int32_t OCCTBRepToolContinuity(OCCTShapeRef edge, OCCTShapeRef face1, OCCTShapeRef face2) {
    if (!edge || !face1 || !face2) return 0;
    try {
        const TopoDS_Edge& e = TopoDS::Edge(edge->shape);
        const TopoDS_Face& f1 = TopoDS::Face(face1->shape);
        const TopoDS_Face& f2 = TopoDS::Face(face2->shape);
        return (int32_t)BRep_Tool::Continuity(e, f1, f2);
    } catch (...) { return 0; }
}

bool OCCTBRepToolHasAnyContinuity(OCCTShapeRef edge) {
    if (!edge) return false;
    try {
        const TopoDS_Edge& e = TopoDS::Edge(edge->shape);
        return BRep_Tool::HasContinuity(e);
    } catch (...) { return false; }
}

int32_t OCCTBRepToolMaxContinuity(OCCTShapeRef edge) {
    if (!edge) return 0;
    try {
        const TopoDS_Edge& e = TopoDS::Edge(edge->shape);
        return (int32_t)BRep_Tool::MaxContinuity(e);
    } catch (...) { return 0; }
}

bool OCCTBRepToolDegenerated(OCCTShapeRef edge) {
    if (!edge) return false;
    try {
        const TopoDS_Edge& e = TopoDS::Edge(edge->shape);
        return BRep_Tool::Degenerated(e);
    } catch (...) { return false; }
}

bool OCCTBRepToolNaturalRestriction(OCCTShapeRef face) {
    if (!face) return false;
    try {
        const TopoDS_Face& f = TopoDS::Face(face->shape);
        return BRep_Tool::NaturalRestriction(f);
    } catch (...) { return false; }
}

bool OCCTBRepToolRangeOnFace(OCCTShapeRef edge, OCCTShapeRef face,
                              double* outFirst, double* outLast) {
    if (!edge || !face) return false;
    try {
        const TopoDS_Edge& e = TopoDS::Edge(edge->shape);
        const TopoDS_Face& f = TopoDS::Face(face->shape);
        double first, last;
        BRep_Tool::Range(e, f, first, last);
        *outFirst = first;
        *outLast = last;
        return true;
    } catch (...) { return false; }
}

bool OCCTBRepToolParameterOnFace(OCCTShapeRef vertex, OCCTShapeRef edge,
                                  OCCTShapeRef face, double* outParam) {
    if (!vertex || !edge || !face) return false;
    try {
        const TopoDS_Vertex& v = TopoDS::Vertex(vertex->shape);
        const TopoDS_Edge& e = TopoDS::Edge(edge->shape);
        const TopoDS_Face& f = TopoDS::Face(face->shape);
        *outParam = BRep_Tool::Parameter(v, e, f);
        return true;
    } catch (...) { return false; }
}

bool OCCTBRepToolParametersOnFace(OCCTShapeRef vertex, OCCTShapeRef face,
                                   double* outU, double* outV) {
    if (!vertex || !face) return false;
    try {
        const TopoDS_Vertex& v = TopoDS::Vertex(vertex->shape);
        const TopoDS_Face& f = TopoDS::Face(face->shape);
        gp_Pnt2d uv = BRep_Tool::Parameters(v, f);
        *outU = uv.X();
        *outV = uv.Y();
        return true;
    } catch (...) { return false; }
}

bool OCCTBRepToolUVPoints(OCCTShapeRef edge, OCCTShapeRef face,
                           double* firstU, double* firstV,
                           double* lastU, double* lastV) {
    if (!edge || !face) return false;
    try {
        const TopoDS_Edge& e = TopoDS::Edge(edge->shape);
        const TopoDS_Face& f = TopoDS::Face(face->shape);
        gp_Pnt2d pFirst, pLast;
        BRep_Tool::UVPoints(e, f, pFirst, pLast);
        *firstU = pFirst.X();
        *firstV = pFirst.Y();
        *lastU = pLast.X();
        *lastV = pLast.Y();
        return true;
    } catch (...) { return false; }
}

double OCCTBRepToolMaxTolerance(OCCTShapeRef shape, int32_t subShapeType) {
    if (!shape) return 0.0;
    try {
        return BRep_Tool::MaxTolerance(shape->shape, (TopAbs_ShapeEnum)subShapeType);
    } catch (...) { return 0.0; }
}

// --- XCAFDoc_ColorTool completions ---

#import <XCAFDoc_ColorTool.hxx>
#import <XCAFDoc_DocumentTool.hxx>
#import <Quantity_Color.hxx>
#import <Quantity_ColorRGBA.hxx>

int64_t OCCTDocumentColorToolAddColor(OCCTDocumentRef doc, double r, double g, double b) {
    if (!doc) return -1;
    try {
        auto colorTool = XCAFDoc_DocumentTool::ColorTool(doc->doc->Main());
        Quantity_Color col(r, g, b, Quantity_TOC_RGB);
        TDF_Label lab = colorTool->AddColor(col);
        if (lab.IsNull()) return -1;
        return doc->registerLabel(lab);
    } catch (...) { return -1; }
}

bool OCCTDocumentColorToolRemoveColor(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc) return false;
    try {
        auto colorTool = XCAFDoc_DocumentTool::ColorTool(doc->doc->Main());
        TDF_Label lab = doc->getLabel(labelId);
        if (lab.IsNull()) return false;
        colorTool->RemoveColor(lab);
        return true;
    } catch (...) { return false; }
}

int32_t OCCTDocumentColorToolGetColorCount(OCCTDocumentRef doc) {
    if (!doc) return 0;
    try {
        auto colorTool = XCAFDoc_DocumentTool::ColorTool(doc->doc->Main());
        NCollection_Sequence<TDF_Label> labels;
        colorTool->GetColors(labels);
        return (int32_t)labels.Length();
    } catch (...) { return 0; }
}

bool OCCTDocumentColorToolUnSetColor(OCCTDocumentRef doc, int64_t labelId, int32_t colorType) {
    if (!doc) return false;
    try {
        auto colorTool = XCAFDoc_DocumentTool::ColorTool(doc->doc->Main());
        TDF_Label lab = doc->getLabel(labelId);
        if (lab.IsNull()) return false;
        colorTool->UnSetColor(lab, (XCAFDoc_ColorType)colorType);
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentColorToolIsVisible(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc) return true;
    try {
        TDF_Label lab = doc->getLabel(labelId);
        if (lab.IsNull()) return true;
        return XCAFDoc_ColorTool::IsVisible(lab);
    } catch (...) { return true; }
}

bool OCCTDocumentColorToolSetVisibility(OCCTDocumentRef doc, int64_t labelId, bool visible) {
    if (!doc) return false;
    try {
        auto colorTool = XCAFDoc_DocumentTool::ColorTool(doc->doc->Main());
        TDF_Label lab = doc->getLabel(labelId);
        if (lab.IsNull()) return false;
        colorTool->SetVisibility(lab, visible);
        return true;
    } catch (...) { return false; }
}

bool OCCTDocumentColorToolIsColorByLayer(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc) return false;
    try {
        auto colorTool = XCAFDoc_DocumentTool::ColorTool(doc->doc->Main());
        TDF_Label lab = doc->getLabel(labelId);
        if (lab.IsNull()) return false;
        return colorTool->IsColorByLayer(lab);
    } catch (...) { return false; }
}

bool OCCTDocumentColorToolSetColorByLayer(OCCTDocumentRef doc, int64_t labelId, bool isByLayer) {
    if (!doc) return false;
    try {
        auto colorTool = XCAFDoc_DocumentTool::ColorTool(doc->doc->Main());
        TDF_Label lab = doc->getLabel(labelId);
        if (lab.IsNull()) return false;
        colorTool->SetColorByLayer(lab, isByLayer);
        return true;
    } catch (...) { return false; }
}

int64_t OCCTDocumentColorToolFindColor(OCCTDocumentRef doc, double r, double g, double b) {
    if (!doc) return -1;
    try {
        auto colorTool = XCAFDoc_DocumentTool::ColorTool(doc->doc->Main());
        Quantity_Color col(r, g, b, Quantity_TOC_RGB);
        TDF_Label lab = colorTool->FindColor(col);
        if (lab.IsNull()) return -1;
        return doc->registerLabel(lab);
    } catch (...) { return -1; }
}

bool OCCTDocumentColorToolSetInstanceColor(OCCTDocumentRef doc, OCCTShapeRef shape,
                                            int32_t colorType, double r, double g, double b) {
    if (!doc || !shape) return false;
    try {
        auto colorTool = XCAFDoc_DocumentTool::ColorTool(doc->doc->Main());
        Quantity_Color col(r, g, b, Quantity_TOC_RGB);
        return colorTool->SetInstanceColor(shape->shape, (XCAFDoc_ColorType)colorType, col);
    } catch (...) { return false; }
}

bool OCCTDocumentColorToolGetInstanceColor(OCCTDocumentRef doc, OCCTShapeRef shape,
                                            int32_t colorType,
                                            double* r, double* g, double* b) {
    if (!doc || !shape) return false;
    try {
        auto colorTool = XCAFDoc_DocumentTool::ColorTool(doc->doc->Main());
        Quantity_Color col;
        if (!colorTool->GetInstanceColor(shape->shape, (XCAFDoc_ColorType)colorType, col))
            return false;
        *r = col.Red();
        *g = col.Green();
        *b = col.Blue();
        return true;
    } catch (...) { return false; }
}

// --- Geom2d_BezierCurve completions ---

#import <Geom2d_BezierCurve.hxx>

bool OCCTCurve2DBezierInsertPoleAfter(OCCTCurve2DRef curve, int32_t index, double x, double y) {
    if (!curve) return false;
    auto bz = Handle(Geom2d_BezierCurve)::DownCast(curve->curve);
    if (bz.IsNull()) return false;
    try {
        bz->InsertPoleAfter(index, gp_Pnt2d(x, y));
        return true;
    } catch (...) { return false; }
}

bool OCCTCurve2DBezierRemovePole(OCCTCurve2DRef curve, int32_t index) {
    if (!curve) return false;
    auto bz = Handle(Geom2d_BezierCurve)::DownCast(curve->curve);
    if (bz.IsNull()) return false;
    try {
        bz->RemovePole(index);
        return true;
    } catch (...) { return false; }
}

bool OCCTCurve2DBezierSegment(OCCTCurve2DRef curve, double u1, double u2) {
    if (!curve) return false;
    auto bz = Handle(Geom2d_BezierCurve)::DownCast(curve->curve);
    if (bz.IsNull()) return false;
    try {
        bz->Segment(u1, u2);
        return true;
    } catch (...) { return false; }
}

bool OCCTCurve2DBezierIncreaseDegree(OCCTCurve2DRef curve, int32_t degree) {
    if (!curve) return false;
    auto bz = Handle(Geom2d_BezierCurve)::DownCast(curve->curve);
    if (bz.IsNull()) return false;
    try {
        bz->Increase(degree);
        return true;
    } catch (...) { return false; }
}

void OCCTCurve2DBezierStartPoint(OCCTCurve2DRef curve, double* x, double* y) {
    if (!curve) return;
    auto bz = Handle(Geom2d_BezierCurve)::DownCast(curve->curve);
    if (bz.IsNull()) return;
    try {
        gp_Pnt2d p = bz->StartPoint();
        *x = p.X();
        *y = p.Y();
    } catch (...) {}
}

void OCCTCurve2DBezierEndPoint(OCCTCurve2DRef curve, double* x, double* y) {
    if (!curve) return;
    auto bz = Handle(Geom2d_BezierCurve)::DownCast(curve->curve);
    if (bz.IsNull()) return;
    try {
        gp_Pnt2d p = bz->EndPoint();
        *x = p.X();
        *y = p.Y();
    } catch (...) {}
}

void OCCTCurve2DBezierGetPoles(OCCTCurve2DRef curve, double* poles) {
    if (!curve || !poles) return;
    auto bz = Handle(Geom2d_BezierCurve)::DownCast(curve->curve);
    if (bz.IsNull()) return;
    try {
        int n = bz->NbPoles();
        for (int i = 1; i <= n; i++) {
            gp_Pnt2d p = bz->Pole(i);
            poles[(i-1)*2] = p.X();
            poles[(i-1)*2+1] = p.Y();
        }
    } catch (...) {}
}

bool OCCTCurve2DBezierReverse(OCCTCurve2DRef curve) {
    if (!curve) return false;
    auto bz = Handle(Geom2d_BezierCurve)::DownCast(curve->curve);
    if (bz.IsNull()) return false;
    try {
        bz->Reverse();
        return true;
    } catch (...) { return false; }
}

// --- BSpline Surface bulk multiplicities and reverse ---

void OCCTSurfaceBSplineGetUMultiplicities(OCCTSurfaceRef surface, int32_t* mults) {
    if (!surface || !mults) return;
    auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return;
    try {
        int n = bs->NbUKnots();
        for (int i = 1; i <= n; i++) {
            mults[i-1] = bs->UMultiplicity(i);
        }
    } catch (...) {}
}

void OCCTSurfaceBSplineGetVMultiplicities(OCCTSurfaceRef surface, int32_t* mults) {
    if (!surface || !mults) return;
    auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return;
    try {
        int n = bs->NbVKnots();
        for (int i = 1; i <= n; i++) {
            mults[i-1] = bs->VMultiplicity(i);
        }
    } catch (...) {}
}

bool OCCTSurfaceBSplineUReverse(OCCTSurfaceRef surface) {
    if (!surface) return false;
    auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return false;
    try {
        bs->UReverse();
        return true;
    } catch (...) { return false; }
}

bool OCCTSurfaceBSplineVReverse(OCCTSurfaceRef surface) {
    if (!surface) return false;
    auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return false;
    try {
        bs->VReverse();
        return true;
    } catch (...) { return false; }
}

bool OCCTSurfaceBSplinePeriodicNormalization(OCCTSurfaceRef surface, double* u, double* v) {
    if (!surface) return false;
    auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return false;
    try {
        bs->PeriodicNormalization(*u, *v);
        return true;
    } catch (...) { return false; }
}

// --- FilletBuilder completions ---


bool OCCTDocumentShapeToolIsComponent(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc) return false;
    try {
        TDF_Label lab = doc->getLabel(labelId);
        if (lab.IsNull()) return false;
        return XCAFDoc_ShapeTool::IsComponent(lab);
    } catch (...) { return false; }
}

bool OCCTDocumentShapeToolIsCompound(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc) return false;
    try {
        TDF_Label lab = doc->getLabel(labelId);
        if (lab.IsNull()) return false;
        return XCAFDoc_ShapeTool::IsCompound(lab);
    } catch (...) { return false; }
}

bool OCCTDocumentShapeToolIsSubShape(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc) return false;
    try {
        TDF_Label lab = doc->getLabel(labelId);
        if (lab.IsNull()) return false;
        return XCAFDoc_ShapeTool::IsSubShape(lab);
    } catch (...) { return false; }
}

bool OCCTDocumentShapeToolIsExternRef(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc) return false;
    try {
        TDF_Label lab = doc->getLabel(labelId);
        if (lab.IsNull()) return false;
        return XCAFDoc_ShapeTool::IsExternRef(lab);
    } catch (...) { return false; }
}

int32_t OCCTDocumentShapeToolGetUsers(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc) return 0;
    try {
        TDF_Label lab = doc->getLabel(labelId);
        if (lab.IsNull()) return 0;
        NCollection_Sequence<TDF_Label> users;
        return (int32_t)XCAFDoc_ShapeTool::GetUsers(lab, users);
    } catch (...) { return 0; }
}

void OCCTDocumentShapeToolComputeShapes(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc) return;
    try {
        auto shapeTool = XCAFDoc_DocumentTool::ShapeTool(doc->doc->Main());
        TDF_Label lab = doc->getLabel(labelId);
        if (lab.IsNull()) return;
        shapeTool->ComputeShapes(lab);
    } catch (...) {}
}

int32_t OCCTDocumentShapeToolNbComponents(OCCTDocumentRef doc, int64_t labelId, bool getSubChildren) {
    if (!doc) return 0;
    try {
        TDF_Label lab = doc->getLabel(labelId);
        if (lab.IsNull()) return 0;
        return (int32_t)XCAFDoc_ShapeTool::NbComponents(lab, getSubChildren);
    } catch (...) { return 0; }
}

// --- Bezier 3D curve InsertPoleBefore and Reverse ---

bool OCCTCurve3DBezierInsertPoleBefore(OCCTCurve3DRef curve, int32_t index,
                                        double x, double y, double z) {
    if (!curve) return false;
    auto bz = Handle(Geom_BezierCurve)::DownCast(curve->curve);
    if (bz.IsNull()) return false;
    try {
        bz->InsertPoleBefore(index, gp_Pnt(x, y, z));
        return true;
    } catch (...) { return false; }
}

bool OCCTCurve3DBezierReverse(OCCTCurve3DRef curve) {
    if (!curve) return false;
    auto bz = Handle(Geom_BezierCurve)::DownCast(curve->curve);
    if (bz.IsNull()) return false;
    try {
        bz->Reverse();
        return true;
    } catch (...) { return false; }
}

bool OCCTCurve3DBezierSetPoleWithWeight(OCCTCurve3DRef curve, int32_t index,
                                         double x, double y, double z, double weight) {
    if (!curve) return false;
    auto bz = Handle(Geom_BezierCurve)::DownCast(curve->curve);
    if (bz.IsNull()) return false;
    try {
        bz->SetPole(index, gp_Pnt(x, y, z), weight);
        return true;
    } catch (...) { return false; }
}

// --- Bezier Surface insert/remove poles ---

bool OCCTSurfaceBezierInsertPoleColAfter(OCCTSurfaceRef surface, int32_t colIndex,
                                          const double* poles, int32_t poleCount) {
    if (!surface || !poles) return false;
    auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
    if (bz.IsNull()) return false;
    try {
        int nbUPoles = bz->NbUPoles();
        if (poleCount != nbUPoles) return false;
        NCollection_Array1<gp_Pnt> col(1, nbUPoles);
        for (int i = 0; i < nbUPoles; i++) {
            col.SetValue(i+1, gp_Pnt(poles[i*3], poles[i*3+1], poles[i*3+2]));
        }
        bz->InsertPoleColAfter(colIndex, col);
        return true;
    } catch (...) { return false; }
}

bool OCCTSurfaceBezierInsertPoleRowAfter(OCCTSurfaceRef surface, int32_t rowIndex,
                                          const double* poles, int32_t poleCount) {
    if (!surface || !poles) return false;
    auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
    if (bz.IsNull()) return false;
    try {
        int nbVPoles = bz->NbVPoles();
        if (poleCount != nbVPoles) return false;
        NCollection_Array1<gp_Pnt> row(1, nbVPoles);
        for (int i = 0; i < nbVPoles; i++) {
            row.SetValue(i+1, gp_Pnt(poles[i*3], poles[i*3+1], poles[i*3+2]));
        }
        bz->InsertPoleRowAfter(rowIndex, row);
        return true;
    } catch (...) { return false; }
}

bool OCCTSurfaceBezierRemovePoleCol(OCCTSurfaceRef surface, int32_t colIndex) {
    if (!surface) return false;
    auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
    if (bz.IsNull()) return false;
    try {
        bz->RemovePoleCol(colIndex);
        return true;
    } catch (...) { return false; }
}

bool OCCTSurfaceBezierRemovePoleRow(OCCTSurfaceRef surface, int32_t rowIndex) {
    if (!surface) return false;
    auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
    if (bz.IsNull()) return false;
    try {
        bz->RemovePoleRow(rowIndex);
        return true;
    } catch (...) { return false; }
}

bool OCCTSurfaceBezierIncreaseDegree(OCCTSurfaceRef surface, int32_t uDeg, int32_t vDeg) {
    if (!surface) return false;
    auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
    if (bz.IsNull()) return false;
    try {
        bz->Increase(uDeg, vDeg);
        return true;
    } catch (...) { return false; }
}

bool OCCTSurfaceBezierUReverse(OCCTSurfaceRef surface) {
    if (!surface) return false;
    auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
    if (bz.IsNull()) return false;
    try {
        bz->UReverse();
        return true;
    } catch (...) { return false; }
}

bool OCCTSurfaceBezierVReverse(OCCTSurfaceRef surface) {
    if (!surface) return false;
    auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
    if (bz.IsNull()) return false;
    try {
        bz->VReverse();
        return true;
    } catch (...) { return false; }
}

// MARK: - v0.127.0: Section ops, BSpline/Bezier completions, BRep_Tool, ColorTool, FilletBuilder history

// --- BRepAlgoAPI_Section with plane ---

OCCTShapeRef OCCTShapeSectionWithPlane(OCCTShapeRef shape,
                                        double normalX, double normalY, double normalZ,
                                        double originX, double originY, double originZ) {
    if (!shape) return nullptr;
    try {
        gp_Pln plane(gp_Pnt(originX, originY, originZ), gp_Dir(normalX, normalY, normalZ));
        BRepAlgoAPI_Section section(shape->shape, plane);
        section.Build();
        if (!section.IsDone() || section.Shape().IsNull()) return nullptr;
        return new OCCTShape(section.Shape());
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTShapeSectionWithSurface(OCCTShapeRef shape, OCCTSurfaceRef surface) {
    if (!shape || !surface) return nullptr;
    try {
        BRepAlgoAPI_Section section(shape->shape, surface->surface);
        section.Build();
        if (!section.IsDone() || section.Shape().IsNull()) return nullptr;
        return new OCCTShape(section.Shape());
    } catch (...) { return nullptr; }
}

// --- Geom_BSplineCurve completions ---

bool OCCTCurve3DBSplinePeriodicNormalization(OCCTCurve3DRef curve, double* u) {
    if (!curve || !u) return false;
    auto bsc = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
    if (bsc.IsNull() || !bsc->IsPeriodic()) return false;
    try {
        bsc->PeriodicNormalization(*u);
        return true;
    } catch (...) { return false; }
}

bool OCCTCurve3DBSplineIsG1(OCCTCurve3DRef curve, double tFirst, double tLast, double angTol) {
    if (!curve) return false;
    auto bsc = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
    if (bsc.IsNull()) return false;
    try {
        return bsc->IsG1(tFirst, tLast, angTol);
    } catch (...) { return false; }
}

// --- BRep_Tool completions ---

OCCTCurve2DRef OCCTBRepToolCurveOnPlane(OCCTShapeRef edge, OCCTSurfaceRef surface,
                                         double* outFirst, double* outLast) {
    if (!edge || !surface || !outFirst || !outLast) return nullptr;
    try {
        TopoDS_Edge e = TopoDS::Edge(edge->shape);
        TopLoc_Location loc;
        double first = 0, last = 0;
        Handle(Geom2d_Curve) pcurve = BRep_Tool::CurveOnPlane(e, surface->surface, loc, first, last);
        if (pcurve.IsNull()) return nullptr;
        *outFirst = first;
        *outLast = last;
        return new OCCTCurve2D(pcurve);
    } catch (...) { return nullptr; }
}

int32_t OCCTBRepToolPolygon3D(OCCTShapeRef edge, double** outPoints) {
    if (!edge || !outPoints) return 0;
    *outPoints = nullptr;
    try {
        TopoDS_Edge e = TopoDS::Edge(edge->shape);
        TopLoc_Location loc;
        Handle(Poly_Polygon3D) poly = BRep_Tool::Polygon3D(e, loc);
        if (poly.IsNull()) return 0;
        int nb = poly->NbNodes();
        if (nb == 0) return 0;
        double* pts = (double*)malloc(nb * 3 * sizeof(double));
        if (!pts) return 0;
        gp_Trsf trsf = loc.IsIdentity() ? gp_Trsf() : loc.Transformation();
        const NCollection_Array1<gp_Pnt>& nodes = poly->Nodes();
        for (int i = 1; i <= nb; i++) {
            gp_Pnt p = nodes.Value(i).Transformed(trsf);
            pts[(i-1)*3+0] = p.X();
            pts[(i-1)*3+1] = p.Y();
            pts[(i-1)*3+2] = p.Z();
        }
        *outPoints = pts;
        return nb;
    } catch (...) { return 0; }
}

int32_t OCCTBRepToolPolygonOnTriangulation(OCCTShapeRef edge, int32_t** outIndices) {
    if (!edge || !outIndices) return 0;
    *outIndices = nullptr;
    try {
        TopoDS_Edge e = TopoDS::Edge(edge->shape);
        TopLoc_Location loc;
        Handle(Poly_PolygonOnTriangulation) pot;
        Handle(Poly_Triangulation) tri;
        BRep_Tool::PolygonOnTriangulation(e, pot, tri, loc);
        if (pot.IsNull()) return 0;
        int nb = pot->NbNodes();
        if (nb == 0) return 0;
        int32_t* indices = (int32_t*)malloc(nb * sizeof(int32_t));
        if (!indices) return 0;
        for (int i = 1; i <= nb; i++) {
            indices[i-1] = pot->Node(i);
        }
        *outIndices = indices;
        return nb;
    } catch (...) { return 0; }
}

// --- Geom_BezierSurface completions ---

bool OCCTSurfaceBezierSetPoleColWeights(OCCTSurfaceRef surface, int32_t vIndex,
                                         const double* poles, const double* weights,
                                         int32_t count) {
    if (!surface || !poles || !weights || count <= 0) return false;
    auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
    if (bz.IsNull()) return false;
    try {
        NCollection_Array1<gp_Pnt> colPoles(1, count);
        NCollection_Array1<double> colWeights(1, count);
        for (int i = 0; i < count; i++) {
            colPoles.SetValue(i+1, gp_Pnt(poles[i*3], poles[i*3+1], poles[i*3+2]));
            colWeights.SetValue(i+1, weights[i]);
        }
        bz->SetPoleCol(vIndex, colPoles, colWeights);
        return true;
    } catch (...) { return false; }
}

bool OCCTSurfaceBezierSetPoleRowWeights(OCCTSurfaceRef surface, int32_t uIndex,
                                         const double* poles, const double* weights,
                                         int32_t count) {
    if (!surface || !poles || !weights || count <= 0) return false;
    auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
    if (bz.IsNull()) return false;
    try {
        NCollection_Array1<gp_Pnt> rowPoles(1, count);
        NCollection_Array1<double> rowWeights(1, count);
        for (int i = 0; i < count; i++) {
            rowPoles.SetValue(i+1, gp_Pnt(poles[i*3], poles[i*3+1], poles[i*3+2]));
            rowWeights.SetValue(i+1, weights[i]);
        }
        bz->SetPoleRow(uIndex, rowPoles, rowWeights);
        return true;
    } catch (...) { return false; }
}

// --- XCAFDoc_ColorTool completions ---

int32_t OCCTDocumentColorToolGetAllColors(OCCTDocumentRef doc, int64_t** outLabelIds) {
    if (!doc || !outLabelIds) return 0;
    *outLabelIds = nullptr;
    try {
        NCollection_Sequence<TDF_Label> labels;
        doc->colorTool->GetColors(labels);
        int count = labels.Size();
        if (count == 0) return 0;
        int64_t* ids = (int64_t*)malloc(count * sizeof(int64_t));
        if (!ids) return 0;
        for (int i = 1; i <= count; i++) {
            const TDF_Label& lab = labels.Value(i);
            // Find or add to label registry
            int64_t idx = -1;
            for (int64_t j = 0; j < (int64_t)doc->labels.size(); j++) {
                if (doc->labels[j].IsEqual(lab)) { idx = j; break; }
            }
            if (idx < 0) {
                idx = (int64_t)doc->labels.size();
                doc->labels.push_back(lab);
            }
            ids[i-1] = idx;
        }
        *outLabelIds = ids;
        return count;
    } catch (...) { return 0; }
}

// --- FilletBuilder history queries ---


// --- SectionBuilder (BRepAlgoAPI_Section) ---

struct OCCTSectionBuilder {
    BRepAlgoAPI_Section section;
    bool built;
    OCCTSectionBuilder() : section(), built(false) {}
    OCCTSectionBuilder(const TopoDS_Shape& s1, const TopoDS_Shape& s2) : section(s1, s2, false), built(false) {}
};

OCCTSectionBuilderRef OCCTSectionBuilderCreate(void) {
    try {
        return new OCCTSectionBuilder();
    } catch (...) { return nullptr; }
}

OCCTSectionBuilderRef OCCTSectionBuilderCreateFromShapes(OCCTShapeRef shape1, OCCTShapeRef shape2) {
    if (!shape1 || !shape2) return nullptr;
    try {
        return new OCCTSectionBuilder(shape1->shape, shape2->shape);
    } catch (...) { return nullptr; }
}

void OCCTSectionBuilderRelease(OCCTSectionBuilderRef builder) {
    delete builder;
}

void OCCTSectionBuilderInit1Shape(OCCTSectionBuilderRef builder, OCCTShapeRef shape) {
    if (!builder || !shape) return;
    try { builder->section.Init1(shape->shape); } catch (...) {}
}

void OCCTSectionBuilderInit1Plane(OCCTSectionBuilderRef builder,
                                   double a, double b, double c, double d) {
    if (!builder) return;
    try {
        gp_Pln plane(a, b, c, d);
        builder->section.Init1(plane);
    } catch (...) {}
}

void OCCTSectionBuilderInit1Surface(OCCTSectionBuilderRef builder, OCCTSurfaceRef surface) {
    if (!builder || !surface) return;
    try { builder->section.Init1(surface->surface); } catch (...) {}
}

void OCCTSectionBuilderInit2Shape(OCCTSectionBuilderRef builder, OCCTShapeRef shape) {
    if (!builder || !shape) return;
    try { builder->section.Init2(shape->shape); } catch (...) {}
}

void OCCTSectionBuilderInit2Plane(OCCTSectionBuilderRef builder,
                                   double a, double b, double c, double d) {
    if (!builder) return;
    try {
        gp_Pln plane(a, b, c, d);
        builder->section.Init2(plane);
    } catch (...) {}
}

void OCCTSectionBuilderInit2Surface(OCCTSectionBuilderRef builder, OCCTSurfaceRef surface) {
    if (!builder || !surface) return;
    try { builder->section.Init2(surface->surface); } catch (...) {}
}

void OCCTSectionBuilderSetApproximation(OCCTSectionBuilderRef builder, bool approx) {
    if (!builder) return;
    try { builder->section.Approximation(approx); } catch (...) {}
}

void OCCTSectionBuilderComputePCurveOn1(OCCTSectionBuilderRef builder, bool compute) {
    if (!builder) return;
    try { builder->section.ComputePCurveOn1(compute); } catch (...) {}
}

void OCCTSectionBuilderComputePCurveOn2(OCCTSectionBuilderRef builder, bool compute) {
    if (!builder) return;
    try { builder->section.ComputePCurveOn2(compute); } catch (...) {}
}

OCCTShapeRef OCCTSectionBuilderBuild(OCCTSectionBuilderRef builder) {
    if (!builder) return nullptr;
    try {
        builder->section.Build();
        if (!builder->section.IsDone()) return nullptr;
        builder->built = true;
        return new OCCTShape{builder->section.Shape()};
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTSectionBuilderAncestorFaceOn1(OCCTSectionBuilderRef builder, OCCTShapeRef edge) {
    if (!builder || !edge || !builder->built) return nullptr;
    try {
        TopoDS_Shape face;
        if (builder->section.HasAncestorFaceOn1(edge->shape, face)) {
            return new OCCTShape{face};
        }
        return nullptr;
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTSectionBuilderAncestorFaceOn2(OCCTSectionBuilderRef builder, OCCTShapeRef edge) {
    if (!builder || !edge || !builder->built) return nullptr;
    try {
        TopoDS_Shape face;
        if (builder->section.HasAncestorFaceOn2(edge->shape, face)) {
            return new OCCTShape{face};
        }
        return nullptr;
    } catch (...) { return nullptr; }
}

// --- BRep_Tool completions ---

bool OCCTBRepToolIsClosedOnFace(OCCTShapeRef edge, OCCTShapeRef face) {
    if (!edge || !face) return false;
    try {
        TopoDS_Edge e = TopoDS::Edge(edge->shape);
        TopoDS_Face f = TopoDS::Face(face->shape);
        return BRep_Tool::IsClosed(e, f);
    } catch (...) { return false; }
}

int32_t OCCTBRepToolPolygonOnSurface(OCCTShapeRef edge, OCCTShapeRef face,
                                      double** outPoints) {
    if (!edge || !face || !outPoints) return 0;
    *outPoints = nullptr;
    try {
        TopoDS_Edge e = TopoDS::Edge(edge->shape);
        TopoDS_Face f = TopoDS::Face(face->shape);
        Handle(Poly_Polygon2D) poly = BRep_Tool::PolygonOnSurface(e, f);
        if (poly.IsNull()) return 0;
        int32_t count = poly->NbNodes();
        if (count == 0) return 0;
        *outPoints = (double*)malloc(count * 2 * sizeof(double));
        const TColgp_Array1OfPnt2d& nodes = poly->Nodes();
        for (int i = 1; i <= count; i++) {
            (*outPoints)[(i-1)*2] = nodes.Value(i).X();
            (*outPoints)[(i-1)*2+1] = nodes.Value(i).Y();
        }
        return count;
    } catch (...) { return 0; }
}

bool OCCTBRepToolSetUVPoints(OCCTShapeRef edge, OCCTShapeRef face,
                              double fU, double fV, double lU, double lV) {
    if (!edge || !face) return false;
    try {
        TopoDS_Edge e = TopoDS::Edge(edge->shape);
        TopoDS_Face f = TopoDS::Face(face->shape);
        gp_Pnt2d p1(fU, fV), p2(lU, lV);
        BRep_Tool::SetUVPoints(e, f, p1, p2);
        return true;
    } catch (...) { return false; }
}

// --- Geometry Transform (in-place) ---

static bool buildTrsf3D(gp_Trsf& trsf, int32_t type,
                          double p1, double p2, double p3,
                          double p4, double p5, double p6, double p7) {
    switch (type) {
        case 0: // translation (dx, dy, dz)
            trsf.SetTranslation(gp_Vec(p1, p2, p3));
            return true;
        case 1: // rotation (ox, oy, oz, dx, dy, dz, angle)
            trsf.SetRotation(gp_Ax1(gp_Pnt(p1, p2, p3), gp_Dir(p4, p5, p6)), p7);
            return true;
        case 2: // scale (cx, cy, cz, factor)
            trsf.SetScale(gp_Pnt(p1, p2, p3), p4);
            return true;
        case 3: // mirror point (px, py, pz)
            trsf.SetMirror(gp_Pnt(p1, p2, p3));
            return true;
        case 4: // mirror axis (ox, oy, oz, dx, dy, dz)
            trsf.SetMirror(gp_Ax1(gp_Pnt(p1, p2, p3), gp_Dir(p4, p5, p6)));
            return true;
        case 5: // mirror plane (ox, oy, oz, nx, ny, nz)
            trsf.SetMirror(gp_Ax2(gp_Pnt(p1, p2, p3), gp_Dir(p4, p5, p6)));
            return true;
        default:
            return false;
    }
}

bool OCCTCurve3DTransform(OCCTCurve3DRef curve, int32_t transformType,
                           double p1, double p2, double p3,
                           double p4, double p5, double p6, double p7) {
    if (!curve) return false;
    try {
        gp_Trsf trsf;
        if (!buildTrsf3D(trsf, transformType, p1, p2, p3, p4, p5, p6, p7)) return false;
        curve->curve->Transform(trsf);
        return true;
    } catch (...) { return false; }
}

bool OCCTCurve2DTransform(OCCTCurve2DRef curve, int32_t transformType,
                           double p1, double p2, double p3, double p4, double p5) {
    if (!curve) return false;
    try {
        gp_Trsf2d trsf;
        switch (transformType) {
            case 0: // translation (dx, dy)
                trsf.SetTranslation(gp_Vec2d(p1, p2));
                break;
            case 1: // rotation (cx, cy, angle)
                trsf.SetRotation(gp_Pnt2d(p1, p2), p3);
                break;
            case 2: // scale (cx, cy, factor)
                trsf.SetScaleFactor(p3);
                trsf.SetTranslationPart(gp_Vec2d(p1 * (1.0 - p3), p2 * (1.0 - p3)));
                break;
            case 3: // mirror point (px, py)
                trsf.SetMirror(gp_Pnt2d(p1, p2));
                break;
            case 4: // mirror axis (ox, oy, dx, dy)
                trsf.SetMirror(gp_Ax2d(gp_Pnt2d(p1, p2), gp_Dir2d(p3, p4)));
                break;
            default:
                return false;
        }
        curve->curve->Transform(trsf);
        return true;
    } catch (...) { return false; }
}

bool OCCTSurfaceTransform(OCCTSurfaceRef surface, int32_t transformType,
                           double p1, double p2, double p3,
                           double p4, double p5, double p6, double p7) {
    if (!surface) return false;
    try {
        gp_Trsf trsf;
        if (!buildTrsf3D(trsf, transformType, p1, p2, p3, p4, p5, p6, p7)) return false;
        surface->surface->Transform(trsf);
        return true;
    } catch (...) { return false; }
}

// --- v0.129.0: BSplineCurve3D LocalD0-D3/DN, BSplineSurface completions, BezierSurface completions ---

void OCCTCurve3DBSplineLocalD0(OCCTCurve3DRef curve, double u,
                                int32_t fromK1, int32_t toK2,
                                double* px, double* py, double* pz) {
    if (!curve || curve->curve.IsNull()) { *px = *py = *pz = 0; return; }
    try {
        auto bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
        if (bs.IsNull()) { *px = *py = *pz = 0; return; }
        gp_Pnt p;
        bs->LocalD0(u, fromK1, toK2, p);
        *px = p.X(); *py = p.Y(); *pz = p.Z();
    } catch (...) { *px = *py = *pz = 0; }
}

void OCCTCurve3DBSplineLocalD1(OCCTCurve3DRef curve, double u,
                                int32_t fromK1, int32_t toK2,
                                double* px, double* py, double* pz,
                                double* vx, double* vy, double* vz) {
    if (!curve || curve->curve.IsNull()) { *px = *py = *pz = *vx = *vy = *vz = 0; return; }
    try {
        auto bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
        if (bs.IsNull()) { *px = *py = *pz = *vx = *vy = *vz = 0; return; }
        gp_Pnt p; gp_Vec v1;
        bs->LocalD1(u, fromK1, toK2, p, v1);
        *px = p.X(); *py = p.Y(); *pz = p.Z();
        *vx = v1.X(); *vy = v1.Y(); *vz = v1.Z();
    } catch (...) { *px = *py = *pz = *vx = *vy = *vz = 0; }
}

void OCCTCurve3DBSplineLocalD2(OCCTCurve3DRef curve, double u,
                                int32_t fromK1, int32_t toK2,
                                double* px, double* py, double* pz,
                                double* v1x, double* v1y, double* v1z,
                                double* v2x, double* v2y, double* v2z) {
    if (!curve || curve->curve.IsNull()) {
        *px = *py = *pz = *v1x = *v1y = *v1z = *v2x = *v2y = *v2z = 0; return;
    }
    try {
        auto bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
        if (bs.IsNull()) { *px = *py = *pz = *v1x = *v1y = *v1z = *v2x = *v2y = *v2z = 0; return; }
        gp_Pnt p; gp_Vec v1, v2;
        bs->LocalD2(u, fromK1, toK2, p, v1, v2);
        *px = p.X(); *py = p.Y(); *pz = p.Z();
        *v1x = v1.X(); *v1y = v1.Y(); *v1z = v1.Z();
        *v2x = v2.X(); *v2y = v2.Y(); *v2z = v2.Z();
    } catch (...) { *px = *py = *pz = *v1x = *v1y = *v1z = *v2x = *v2y = *v2z = 0; }
}

void OCCTCurve3DBSplineLocalD3(OCCTCurve3DRef curve, double u,
                                int32_t fromK1, int32_t toK2,
                                double* px, double* py, double* pz,
                                double* v1x, double* v1y, double* v1z,
                                double* v2x, double* v2y, double* v2z,
                                double* v3x, double* v3y, double* v3z) {
    if (!curve || curve->curve.IsNull()) {
        *px = *py = *pz = *v1x = *v1y = *v1z = *v2x = *v2y = *v2z = *v3x = *v3y = *v3z = 0; return;
    }
    try {
        auto bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
        if (bs.IsNull()) {
            *px = *py = *pz = *v1x = *v1y = *v1z = *v2x = *v2y = *v2z = *v3x = *v3y = *v3z = 0; return;
        }
        gp_Pnt p; gp_Vec v1, v2, v3;
        bs->LocalD3(u, fromK1, toK2, p, v1, v2, v3);
        *px = p.X(); *py = p.Y(); *pz = p.Z();
        *v1x = v1.X(); *v1y = v1.Y(); *v1z = v1.Z();
        *v2x = v2.X(); *v2y = v2.Y(); *v2z = v2.Z();
        *v3x = v3.X(); *v3y = v3.Y(); *v3z = v3.Z();
    } catch (...) {
        *px = *py = *pz = *v1x = *v1y = *v1z = *v2x = *v2y = *v2z = *v3x = *v3y = *v3z = 0;
    }
}

void OCCTCurve3DBSplineLocalDN(OCCTCurve3DRef curve, double u,
                                int32_t fromK1, int32_t toK2, int32_t n,
                                double* vx, double* vy, double* vz) {
    if (!curve || curve->curve.IsNull()) { *vx = *vy = *vz = 0; return; }
    try {
        auto bs = Handle(Geom_BSplineCurve)::DownCast(curve->curve);
        if (bs.IsNull()) { *vx = *vy = *vz = 0; return; }
        gp_Vec v = bs->LocalDN(u, fromK1, toK2, n);
        *vx = v.X(); *vy = v.Y(); *vz = v.Z();
    } catch (...) { *vx = *vy = *vz = 0; }
}

// BSplineSurface completions

bool OCCTSurfaceBSplineSetWeightCol(OCCTSurfaceRef surface, int32_t vIndex,
                                     const double* weights, int32_t count) {
    if (!surface || surface->surface.IsNull() || !weights || count <= 0) return false;
    auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return false;
    try {
        TColStd_Array1OfReal w(1, count);
        for (int i = 0; i < count; i++) w.SetValue(i + 1, weights[i]);
        bs->SetWeightCol(vIndex, w);
        return true;
    } catch (...) { return false; }
}

bool OCCTSurfaceBSplineSetWeightRow(OCCTSurfaceRef surface, int32_t uIndex,
                                     const double* weights, int32_t count) {
    if (!surface || surface->surface.IsNull() || !weights || count <= 0) return false;
    auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return false;
    try {
        TColStd_Array1OfReal w(1, count);
        for (int i = 0; i < count; i++) w.SetValue(i + 1, weights[i]);
        bs->SetWeightRow(uIndex, w);
        return true;
    } catch (...) { return false; }
}

bool OCCTSurfaceBSplineIncrementUMultiplicity(OCCTSurfaceRef surface,
                                               int32_t fromIndex, int32_t toIndex, int32_t step) {
    if (!surface || surface->surface.IsNull()) return false;
    auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return false;
    try { bs->IncrementUMultiplicity(fromIndex, toIndex, step); return true; } catch (...) { return false; }
}

bool OCCTSurfaceBSplineIncrementVMultiplicity(OCCTSurfaceRef surface,
                                               int32_t fromIndex, int32_t toIndex, int32_t step) {
    if (!surface || surface->surface.IsNull()) return false;
    auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return false;
    try { bs->IncrementVMultiplicity(fromIndex, toIndex, step); return true; } catch (...) { return false; }
}

int32_t OCCTSurfaceBSplineFirstUKnotIndex(OCCTSurfaceRef surface) {
    if (!surface || surface->surface.IsNull()) return 0;
    auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return 0;
    try { return (int32_t)bs->FirstUKnotIndex(); } catch (...) { return 0; }
}

int32_t OCCTSurfaceBSplineLastUKnotIndex(OCCTSurfaceRef surface) {
    if (!surface || surface->surface.IsNull()) return 0;
    auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return 0;
    try { return (int32_t)bs->LastUKnotIndex(); } catch (...) { return 0; }
}

int32_t OCCTSurfaceBSplineFirstVKnotIndex(OCCTSurfaceRef surface) {
    if (!surface || surface->surface.IsNull()) return 0;
    auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return 0;
    try { return (int32_t)bs->FirstVKnotIndex(); } catch (...) { return 0; }
}

int32_t OCCTSurfaceBSplineLastVKnotIndex(OCCTSurfaceRef surface) {
    if (!surface || surface->surface.IsNull()) return 0;
    auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return 0;
    try { return (int32_t)bs->LastVKnotIndex(); } catch (...) { return 0; }
}

bool OCCTSurfaceBSplineCheckAndSegment(OCCTSurfaceRef surface,
                                        double u1, double u2, double v1, double v2,
                                        double uTol, double vTol) {
    if (!surface || surface->surface.IsNull()) return false;
    auto bs = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
    if (bs.IsNull()) return false;
    try { bs->CheckAndSegment(u1, u2, v1, v2, uTol, vTol); return true; } catch (...) { return false; }
}

// BezierSurface completions

bool OCCTSurfaceBezierInsertPoleColBefore(OCCTSurfaceRef surface, int32_t colIndex,
                                           const double* poles, int32_t poleCount) {
    if (!surface || !poles) return false;
    auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
    if (bz.IsNull()) return false;
    try {
        int nbUPoles = bz->NbUPoles();
        if (poleCount != nbUPoles) return false;
        NCollection_Array1<gp_Pnt> col(1, nbUPoles);
        for (int i = 0; i < nbUPoles; i++) {
            col.SetValue(i + 1, gp_Pnt(poles[i * 3], poles[i * 3 + 1], poles[i * 3 + 2]));
        }
        bz->InsertPoleColBefore(colIndex, col);
        return true;
    } catch (...) { return false; }
}

bool OCCTSurfaceBezierInsertPoleRowBefore(OCCTSurfaceRef surface, int32_t rowIndex,
                                           const double* poles, int32_t poleCount) {
    if (!surface || !poles) return false;
    auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
    if (bz.IsNull()) return false;
    try {
        int nbVPoles = bz->NbVPoles();
        if (poleCount != nbVPoles) return false;
        NCollection_Array1<gp_Pnt> row(1, nbVPoles);
        for (int i = 0; i < nbVPoles; i++) {
            row.SetValue(i + 1, gp_Pnt(poles[i * 3], poles[i * 3 + 1], poles[i * 3 + 2]));
        }
        bz->InsertPoleRowBefore(rowIndex, row);
        return true;
    } catch (...) { return false; }
}

bool OCCTSurfaceBezierSetPoleCol(OCCTSurfaceRef surface, int32_t vIndex,
                                  const double* poles, int32_t count) {
    if (!surface || !poles || count <= 0) return false;
    auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
    if (bz.IsNull()) return false;
    try {
        NCollection_Array1<gp_Pnt> col(1, count);
        for (int i = 0; i < count; i++) {
            col.SetValue(i + 1, gp_Pnt(poles[i * 3], poles[i * 3 + 1], poles[i * 3 + 2]));
        }
        bz->SetPoleCol(vIndex, col);
        return true;
    } catch (...) { return false; }
}

bool OCCTSurfaceBezierSetPoleRow(OCCTSurfaceRef surface, int32_t uIndex,
                                  const double* poles, int32_t count) {
    if (!surface || !poles || count <= 0) return false;
    auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
    if (bz.IsNull()) return false;
    try {
        NCollection_Array1<gp_Pnt> row(1, count);
        for (int i = 0; i < count; i++) {
            row.SetValue(i + 1, gp_Pnt(poles[i * 3], poles[i * 3 + 1], poles[i * 3 + 2]));
        }
        bz->SetPoleRow(uIndex, row);
        return true;
    } catch (...) { return false; }
}

bool OCCTSurfaceBezierSetWeightCol(OCCTSurfaceRef surface, int32_t vIndex,
                                    const double* weights, int32_t count) {
    if (!surface || !weights || count <= 0) return false;
    auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
    if (bz.IsNull()) return false;
    try {
        TColStd_Array1OfReal w(1, count);
        for (int i = 0; i < count; i++) w.SetValue(i + 1, weights[i]);
        bz->SetWeightCol(vIndex, w);
        return true;
    } catch (...) { return false; }
}

bool OCCTSurfaceBezierSetWeightRow(OCCTSurfaceRef surface, int32_t uIndex,
                                    const double* weights, int32_t count) {
    if (!surface || !weights || count <= 0) return false;
    auto bz = Handle(Geom_BezierSurface)::DownCast(surface->surface);
    if (bz.IsNull()) return false;
    try {
        TColStd_Array1OfReal w(1, count);
        for (int i = 0; i < count; i++) w.SetValue(i + 1, weights[i]);
        bz->SetWeightRow(uIndex, w);
        return true;
    } catch (...) { return false; }
}

// end of v0.128.0 implementations

// MARK: - v0.130.0: GeomEval, Geom2dEval, GeomFill_Gordon, PointSetLib, ExtremaPC

#include <GeomEval_CircularHelixCurve.hxx>
#include <GeomEval_SineWaveCurve.hxx>
#include <GeomEval_EllipsoidSurface.hxx>
#include <GeomEval_HyperboloidSurface.hxx>
#include <GeomEval_ParaboloidSurface.hxx>
#include <GeomEval_CircularHelicoidSurface.hxx>
#include <GeomEval_HypParaboloidSurface.hxx>
#include <Geom2dEval_ArchimedeanSpiralCurve.hxx>
#include <Geom2dEval_LogarithmicSpiralCurve.hxx>
#include <Geom2dEval_CircleInvoluteCurve.hxx>
#include <Geom2dEval_SineWaveCurve.hxx>
#include <GeomFill_Gordon.hxx>
#include <PointSetLib_Props.hxx>
#include <PointSetLib_Equation.hxx>
#include <ExtremaPC_Curve.hxx>

// --- GeomEval Circular Helix ---

void OCCTGeomEvalCircularHelixD0(double radius, double pitch, double u,
                                  double* px, double* py, double* pz) {
    gp_Ax2 ax(gp_Pnt(0,0,0), gp_Dir(0,0,1));
    GeomEval_CircularHelixCurve helix(ax, radius, pitch);
    gp_Pnt p = helix.EvalD0(u);
    *px = p.X(); *py = p.Y(); *pz = p.Z();
}

void OCCTGeomEvalCircularHelixD1(double radius, double pitch, double u,
                                  double* px, double* py, double* pz,
                                  double* vx, double* vy, double* vz) {
    gp_Ax2 ax(gp_Pnt(0,0,0), gp_Dir(0,0,1));
    GeomEval_CircularHelixCurve helix(ax, radius, pitch);
    auto res = helix.EvalD1(u);
    *px = res.Point.X(); *py = res.Point.Y(); *pz = res.Point.Z();
    *vx = res.D1.X(); *vy = res.D1.Y(); *vz = res.D1.Z();
}

void OCCTGeomEvalCircularHelixD2(double radius, double pitch, double u,
                                  double* px, double* py, double* pz,
                                  double* d1x, double* d1y, double* d1z,
                                  double* d2x, double* d2y, double* d2z) {
    gp_Ax2 ax(gp_Pnt(0,0,0), gp_Dir(0,0,1));
    GeomEval_CircularHelixCurve helix(ax, radius, pitch);
    auto res = helix.EvalD2(u);
    *px = res.Point.X(); *py = res.Point.Y(); *pz = res.Point.Z();
    *d1x = res.D1.X(); *d1y = res.D1.Y(); *d1z = res.D1.Z();
    *d2x = res.D2.X(); *d2y = res.D2.Y(); *d2z = res.D2.Z();
}

OCCTCurve3DRef OCCTGeomEvalCircularHelixCurveCreate(double radius, double pitch) {
    try {
        gp_Ax2 ax(gp_Pnt(0,0,0), gp_Dir(0,0,1));
        auto helix = new GeomEval_CircularHelixCurve(ax, radius, pitch);
        occ::handle<Geom_Curve> hCurve(helix);
        auto ref = new OCCTCurve3D();
        ref->curve = hCurve;
        return ref;
    } catch (...) { return nullptr; }
}

// --- GeomEval Sine Wave 3D ---

void OCCTGeomEvalSineWaveD0(double amplitude, double omega, double phase, double u,
                             double* px, double* py, double* pz) {
    gp_Ax2 ax(gp_Pnt(0,0,0), gp_Dir(0,0,1));
    GeomEval_SineWaveCurve sw(ax, amplitude, omega, phase);
    gp_Pnt p = sw.EvalD0(u);
    *px = p.X(); *py = p.Y(); *pz = p.Z();
}

void OCCTGeomEvalSineWaveD1(double amplitude, double omega, double phase, double u,
                             double* px, double* py, double* pz,
                             double* vx, double* vy, double* vz) {
    gp_Ax2 ax(gp_Pnt(0,0,0), gp_Dir(0,0,1));
    GeomEval_SineWaveCurve sw(ax, amplitude, omega, phase);
    auto res = sw.EvalD1(u);
    *px = res.Point.X(); *py = res.Point.Y(); *pz = res.Point.Z();
    *vx = res.D1.X(); *vy = res.D1.Y(); *vz = res.D1.Z();
}

OCCTCurve3DRef OCCTGeomEvalSineWaveCurveCreate(double amplitude, double omega, double phase) {
    try {
        gp_Ax2 ax(gp_Pnt(0,0,0), gp_Dir(0,0,1));
        auto sw = new GeomEval_SineWaveCurve(ax, amplitude, omega, phase);
        occ::handle<Geom_Curve> hCurve(sw);
        auto ref = new OCCTCurve3D();
        ref->curve = hCurve;
        return ref;
    } catch (...) { return nullptr; }
}

// --- GeomEval Surfaces ---

void OCCTGeomEvalEllipsoidD0(double a, double b, double c, double u, double v,
                              double* px, double* py, double* pz) {
    gp_Ax3 ax(gp_Pnt(0,0,0), gp_Dir(0,0,1));
    GeomEval_EllipsoidSurface ell(ax, a, b, c);
    gp_Pnt p = ell.EvalD0(u, v);
    *px = p.X(); *py = p.Y(); *pz = p.Z();
}

OCCTSurfaceRef OCCTGeomEvalEllipsoidCreate(double a, double b, double c) {
    try {
        gp_Ax3 ax(gp_Pnt(0,0,0), gp_Dir(0,0,1));
        auto ell = new GeomEval_EllipsoidSurface(ax, a, b, c);
        occ::handle<Geom_Surface> hSurf(ell);
        auto ref = new OCCTSurface();
        ref->surface = hSurf;
        return ref;
    } catch (...) { return nullptr; }
}

void OCCTGeomEvalHyperboloidD0(double r1, double r2, int32_t mode, double u, double v,
                                double* px, double* py, double* pz) {
    gp_Ax3 ax(gp_Pnt(0,0,0), gp_Dir(0,0,1));
    auto sm = mode == 0 ? GeomEval_HyperboloidSurface::SheetMode::OneSheet
                        : GeomEval_HyperboloidSurface::SheetMode::TwoSheets;
    GeomEval_HyperboloidSurface hyp(ax, r1, r2, sm);
    gp_Pnt p = hyp.EvalD0(u, v);
    *px = p.X(); *py = p.Y(); *pz = p.Z();
}

OCCTSurfaceRef OCCTGeomEvalHyperboloidCreate(double r1, double r2, int32_t mode) {
    try {
        gp_Ax3 ax(gp_Pnt(0,0,0), gp_Dir(0,0,1));
        auto sm = mode == 0 ? GeomEval_HyperboloidSurface::SheetMode::OneSheet
                            : GeomEval_HyperboloidSurface::SheetMode::TwoSheets;
        auto hyp = new GeomEval_HyperboloidSurface(ax, r1, r2, sm);
        occ::handle<Geom_Surface> hSurf(hyp);
        auto ref = new OCCTSurface();
        ref->surface = hSurf;
        return ref;
    } catch (...) { return nullptr; }
}

void OCCTGeomEvalParaboloidD0(double focal, double u, double v,
                               double* px, double* py, double* pz) {
    gp_Ax3 ax(gp_Pnt(0,0,0), gp_Dir(0,0,1));
    GeomEval_ParaboloidSurface par(ax, focal);
    gp_Pnt p = par.EvalD0(u, v);
    *px = p.X(); *py = p.Y(); *pz = p.Z();
}

OCCTSurfaceRef OCCTGeomEvalParaboloidCreate(double focal) {
    try {
        gp_Ax3 ax(gp_Pnt(0,0,0), gp_Dir(0,0,1));
        auto par = new GeomEval_ParaboloidSurface(ax, focal);
        occ::handle<Geom_Surface> hSurf(par);
        auto ref = new OCCTSurface();
        ref->surface = hSurf;
        return ref;
    } catch (...) { return nullptr; }
}

void OCCTGeomEvalCircularHelicoidD0(double pitch, double u, double v,
                                     double* px, double* py, double* pz) {
    gp_Ax3 ax(gp_Pnt(0,0,0), gp_Dir(0,0,1));
    GeomEval_CircularHelicoidSurface hel(ax, pitch);
    gp_Pnt p = hel.EvalD0(u, v);
    *px = p.X(); *py = p.Y(); *pz = p.Z();
}

OCCTSurfaceRef OCCTGeomEvalCircularHelicoidCreate(double pitch) {
    try {
        gp_Ax3 ax(gp_Pnt(0,0,0), gp_Dir(0,0,1));
        auto hel = new GeomEval_CircularHelicoidSurface(ax, pitch);
        occ::handle<Geom_Surface> hSurf(hel);
        auto ref = new OCCTSurface();
        ref->surface = hSurf;
        return ref;
    } catch (...) { return nullptr; }
}

void OCCTGeomEvalHypParaboloidD0(double a, double b, double u, double v,
                                  double* px, double* py, double* pz) {
    gp_Ax3 ax(gp_Pnt(0,0,0), gp_Dir(0,0,1));
    GeomEval_HypParaboloidSurface hp(ax, a, b);
    gp_Pnt p = hp.EvalD0(u, v);
    *px = p.X(); *py = p.Y(); *pz = p.Z();
}

OCCTSurfaceRef OCCTGeomEvalHypParaboloidCreate(double a, double b) {
    try {
        gp_Ax3 ax(gp_Pnt(0,0,0), gp_Dir(0,0,1));
        auto hp = new GeomEval_HypParaboloidSurface(ax, a, b);
        occ::handle<Geom_Surface> hSurf(hp);
        auto ref = new OCCTSurface();
        ref->surface = hSurf;
        return ref;
    } catch (...) { return nullptr; }
}

// --- Geom2dEval Curves ---

void OCCTGeom2dEvalArchimedeanSpiralD0(double initialRadius, double growthRate, double u,
                                        double* px, double* py) {
    gp_Ax2d ax(gp_Pnt2d(0,0), gp_Dir2d(1,0));
    Geom2dEval_ArchimedeanSpiralCurve sp(ax, initialRadius, growthRate);
    gp_Pnt2d p = sp.EvalD0(u);
    *px = p.X(); *py = p.Y();
}

void OCCTGeom2dEvalArchimedeanSpiralD1(double initialRadius, double growthRate, double u,
                                        double* px, double* py,
                                        double* vx, double* vy) {
    gp_Ax2d ax(gp_Pnt2d(0,0), gp_Dir2d(1,0));
    Geom2dEval_ArchimedeanSpiralCurve sp(ax, initialRadius, growthRate);
    auto res = sp.EvalD1(u);
    *px = res.Point.X(); *py = res.Point.Y();
    *vx = res.D1.X(); *vy = res.D1.Y();
}

void OCCTGeom2dEvalLogSpiralD0(double scale, double growthExponent, double u,
                                double* px, double* py) {
    gp_Ax2d ax(gp_Pnt2d(0,0), gp_Dir2d(1,0));
    Geom2dEval_LogarithmicSpiralCurve sp(ax, scale, growthExponent);
    gp_Pnt2d p = sp.EvalD0(u);
    *px = p.X(); *py = p.Y();
}

void OCCTGeom2dEvalLogSpiralD1(double scale, double growthExponent, double u,
                                double* px, double* py,
                                double* vx, double* vy) {
    gp_Ax2d ax(gp_Pnt2d(0,0), gp_Dir2d(1,0));
    Geom2dEval_LogarithmicSpiralCurve sp(ax, scale, growthExponent);
    auto res = sp.EvalD1(u);
    *px = res.Point.X(); *py = res.Point.Y();
    *vx = res.D1.X(); *vy = res.D1.Y();
}

void OCCTGeom2dEvalCircleInvoluteD0(double radius, double u,
                                     double* px, double* py) {
    gp_Ax2d ax(gp_Pnt2d(0,0), gp_Dir2d(1,0));
    Geom2dEval_CircleInvoluteCurve inv(ax, radius);
    gp_Pnt2d p = inv.EvalD0(u);
    *px = p.X(); *py = p.Y();
}

void OCCTGeom2dEvalCircleInvoluteD1(double radius, double u,
                                     double* px, double* py,
                                     double* vx, double* vy) {
    gp_Ax2d ax(gp_Pnt2d(0,0), gp_Dir2d(1,0));
    Geom2dEval_CircleInvoluteCurve inv(ax, radius);
    auto res = inv.EvalD1(u);
    *px = res.Point.X(); *py = res.Point.Y();
    *vx = res.D1.X(); *vy = res.D1.Y();
}

void OCCTGeom2dEvalSineWaveD0(double amplitude, double omega, double phase, double u,
                               double* px, double* py) {
    gp_Ax2d ax(gp_Pnt2d(0,0), gp_Dir2d(1,0));
    Geom2dEval_SineWaveCurve sw(ax, amplitude, omega, phase);
    gp_Pnt2d p = sw.EvalD0(u);
    *px = p.X(); *py = p.Y();
}

void OCCTGeom2dEvalSineWaveD1(double amplitude, double omega, double phase, double u,
                               double* px, double* py,
                               double* vx, double* vy) {
    gp_Ax2d ax(gp_Pnt2d(0,0), gp_Dir2d(1,0));
    Geom2dEval_SineWaveCurve sw(ax, amplitude, omega, phase);
    auto res = sw.EvalD1(u);
    *px = res.Point.X(); *py = res.Point.Y();
    *vx = res.D1.X(); *vy = res.D1.Y();
}

// --- GeomFill_Gordon ---

OCCTSurfaceRef OCCTGeomFillGordon(const OCCTCurve3DRef* profiles, int32_t profileCount,
                                   const OCCTCurve3DRef* guides, int32_t guideCount,
                                   double tolerance) {
    if (!profiles || !guides || profileCount < 2 || guideCount < 2) return nullptr;
    try {
        NCollection_Array1<occ::handle<Geom_Curve>> profs(0, profileCount - 1);
        for (int i = 0; i < profileCount; i++) {
            if (!profiles[i]) return nullptr;
            profs.SetValue(i, profiles[i]->curve);
        }
        NCollection_Array1<occ::handle<Geom_Curve>> gds(0, guideCount - 1);
        for (int i = 0; i < guideCount; i++) {
            if (!guides[i]) return nullptr;
            gds.SetValue(i, guides[i]->curve);
        }

        GeomFill_Gordon gordon;
        gordon.Init(profs, gds, tolerance);
        gordon.Perform();
        if (!gordon.IsDone()) return nullptr;

        auto surf = gordon.Surface();
        if (surf.IsNull()) return nullptr;

        auto ref = new OCCTSurface();
        ref->surface = surf;
        return ref;
    } catch (...) { return nullptr; }
}

// --- PointSetLib ---

void OCCTPointSetProps(const double* points, int32_t count,
                       double* cx, double* cy, double* cz, double* mass) {
    if (!points || count <= 0) { *cx = *cy = *cz = *mass = 0; return; }
    NCollection_Array1<gp_Pnt> pts(0, count - 1);
    for (int i = 0; i < count; i++) {
        pts.SetValue(i, gp_Pnt(points[i*3], points[i*3+1], points[i*3+2]));
    }
    PointSetLib_Props props(pts);
    auto cg = props.CentreOfMass();
    *cx = cg.X(); *cy = cg.Y(); *cz = cg.Z();
    *mass = props.Mass();
}

void OCCTPointSetPropsInertia(const double* points, int32_t count, double* inertiaMatrix) {
    if (!points || count <= 0 || !inertiaMatrix) return;
    NCollection_Array1<gp_Pnt> pts(0, count - 1);
    for (int i = 0; i < count; i++) {
        pts.SetValue(i, gp_Pnt(points[i*3], points[i*3+1], points[i*3+2]));
    }
    PointSetLib_Props props(pts);
    gp_Mat m = props.MatrixOfInertia();
    inertiaMatrix[0] = m.Value(1,1); inertiaMatrix[1] = m.Value(1,2); inertiaMatrix[2] = m.Value(1,3);
    inertiaMatrix[3] = m.Value(2,1); inertiaMatrix[4] = m.Value(2,2); inertiaMatrix[5] = m.Value(2,3);
    inertiaMatrix[6] = m.Value(3,1); inertiaMatrix[7] = m.Value(3,2); inertiaMatrix[8] = m.Value(3,3);
}

void OCCTPointSetBarycentre(const double* points, int32_t count,
                             double* bx, double* by, double* bz) {
    if (!points || count <= 0) { *bx = *by = *bz = 0; return; }
    NCollection_Array1<gp_Pnt> pts(0, count - 1);
    for (int i = 0; i < count; i++) {
        pts.SetValue(i, gp_Pnt(points[i*3], points[i*3+1], points[i*3+2]));
    }
    gp_Pnt b = PointSetLib_Props::Barycentre(pts);
    *bx = b.X(); *by = b.Y(); *bz = b.Z();
}

int32_t OCCTPointSetEquation(const double* points, int32_t count, double tolerance,
                              double* baryCx, double* baryCy, double* baryCz,
                              double* planeNx, double* planeNy, double* planeNz,
                              double* planeDist) {
    if (!points || count <= 0) return -1;
    try {
        NCollection_Array1<gp_Pnt> pts(0, count - 1);
        for (int i = 0; i < count; i++) {
            pts.SetValue(i, gp_Pnt(points[i*3], points[i*3+1], points[i*3+2]));
        }
        PointSetLib_Equation eq(pts, tolerance);
        auto bary = eq.Barycentre();
        *baryCx = bary.X(); *baryCy = bary.Y(); *baryCz = bary.Z();
        *planeNx = *planeNy = *planeNz = *planeDist = 0;

        auto type = eq.GetType();
        if (type == PointSetLib_Equation::Type::Point) {
            return 0;
        } else if (type == PointSetLib_Equation::Type::Line) {
            return 1;
        } else if (type == PointSetLib_Equation::Type::Plane) {
            auto pl = eq.Plane();
            auto dir = pl.Axis().Direction();
            *planeNx = dir.X(); *planeNy = dir.Y(); *planeNz = dir.Z();
            *planeDist = pl.Distance(gp_Pnt(0,0,0));
            return 2;
        } else {
            return 3;
        }
    } catch (...) { return -1; }
}

// --- ExtremaPC ---

int32_t OCCTExtremaPCCurve(OCCTCurve3DRef curve,
                            double px, double py, double pz,
                            double* outParams, double* outDistances,
                            double* outPx, double* outPy, double* outPz,
                            int32_t maxResults) {
    if (!curve || !outParams || !outDistances || maxResults <= 0) return 0;
    try {
        ExtremaPC_Curve extPC(curve->curve);
        if (!extPC.IsInitialized()) return 0;
        const auto& result = extPC.Perform(gp_Pnt(px, py, pz), 1e-9);
        if (!result.IsDone()) return 0;
        int n = std::min((int)result.NbExt(), (int)maxResults);
        for (int i = 0; i < n; i++) {
            outParams[i] = result[i].Parameter;
            outDistances[i] = std::sqrt(result[i].SquareDistance);
            if (outPx) outPx[i] = result[i].Point.X();
            if (outPy) outPy[i] = result[i].Point.Y();
            if (outPz) outPz[i] = result[i].Point.Z();
        }
        return n;
    } catch (...) { return 0; }
}

int32_t OCCTExtremaPCCurveBounded(OCCTCurve3DRef curve,
                                   double px, double py, double pz,
                                   double uMin, double uMax,
                                   double* outParams, double* outDistances,
                                   double* outPx, double* outPy, double* outPz,
                                   int32_t maxResults) {
    if (!curve || !outParams || !outDistances || maxResults <= 0) return 0;
    try {
        ExtremaPC_Curve extPC(curve->curve, uMin, uMax);
        if (!extPC.IsInitialized()) return 0;
        const auto& result = extPC.Perform(gp_Pnt(px, py, pz), 1e-9);
        if (!result.IsDone()) return 0;
        int n = std::min((int)result.NbExt(), (int)maxResults);
        for (int i = 0; i < n; i++) {
            outParams[i] = result[i].Parameter;
            outDistances[i] = std::sqrt(result[i].SquareDistance);
            if (outPx) outPx[i] = result[i].Point.X();
            if (outPy) outPy[i] = result[i].Point.Y();
            if (outPz) outPz[i] = result[i].Point.Z();
        }
        return n;
    } catch (...) { return 0; }
}

double OCCTExtremaPCMinDistance(OCCTCurve3DRef curve,
                                double px, double py, double pz) {
    if (!curve) return -1.0;
    try {
        ExtremaPC_Curve extPC(curve->curve);
        if (!extPC.IsInitialized()) return -1.0;
        const auto& result = extPC.Perform(gp_Pnt(px, py, pz), 1e-9);
        if (!result.IsDone() || result.NbExt() == 0) return -1.0;
        return std::sqrt(result.MinSquareDistance());
    } catch (...) { return -1.0; }
}

// end of v0.130.0 implementations

// MARK: - v0.131.0: Approx_BSplineApproxInterp, GeomEval TBezier/AHTBezier, GeomAdaptor_TransformedCurve

#include <Approx_BSplineApproxInterp.hxx>
#include <GeomAdaptor_TransformedCurve.hxx>
#include <GeomEval_TBezierCurve.hxx>
#include <GeomEval_AHTBezierCurve.hxx>
#include <GeomEval_TBezierSurface.hxx>
#include <GeomEval_AHTBezierSurface.hxx>
#include <Geom2dEval_TBezierCurve.hxx>
#include <Geom2dEval_AHTBezierCurve.hxx>
#include <NCollection_Array2.hxx>

// --- Approx_BSplineApproxInterp ---

struct OCCTBSplineApproxInterp {
    Approx_BSplineApproxInterp* solver;
    OCCTBSplineApproxInterp() : solver(nullptr) {}
    ~OCCTBSplineApproxInterp() { delete solver; }
};

OCCTBSplineApproxInterpRef OCCTBSplineApproxInterpCreate(
    const double* points, int32_t count,
    int32_t nbControlPts, int32_t degree, bool continuousIfClosed) {
    if (!points || count < 2) return nullptr;
    try {
        NCollection_Array1<gp_Pnt> pts(1, count);
        for (int i = 0; i < count; i++)
            pts(i + 1) = gp_Pnt(points[i*3], points[i*3+1], points[i*3+2]);
        auto ref = new OCCTBSplineApproxInterp();
        ref->solver = new Approx_BSplineApproxInterp(pts, nbControlPts, degree, continuousIfClosed);
        return ref;
    } catch (...) { return nullptr; }
}

void OCCTBSplineApproxInterpRelease(OCCTBSplineApproxInterpRef ref) {
    delete ref;
}

void OCCTBSplineApproxInterpInterpolatePoint(OCCTBSplineApproxInterpRef ref,
                                              int32_t pointIndex, bool withKink) {
    if (!ref || !ref->solver) return;
    try { ref->solver->InterpolatePoint(pointIndex, withKink); } catch (...) {}
}

void OCCTBSplineApproxInterpPerform(OCCTBSplineApproxInterpRef ref) {
    if (!ref || !ref->solver) return;
    try { ref->solver->Perform(); } catch (...) {}
}

void OCCTBSplineApproxInterpPerformOptimal(OCCTBSplineApproxInterpRef ref,
                                            int32_t maxIter) {
    if (!ref || !ref->solver) return;
    try { ref->solver->PerformOptimal(maxIter); } catch (...) {}
}

bool OCCTBSplineApproxInterpIsDone(OCCTBSplineApproxInterpRef ref) {
    if (!ref || !ref->solver) return false;
    return ref->solver->IsDone();
}

OCCTCurve3DRef OCCTBSplineApproxInterpCurve(OCCTBSplineApproxInterpRef ref) {
    if (!ref || !ref->solver || !ref->solver->IsDone()) return nullptr;
    try {
        const auto& curve = ref->solver->Curve();
        if (curve.IsNull()) return nullptr;
        auto cref = new OCCTCurve3D();
        cref->curve = curve;
        return cref;
    } catch (...) { return nullptr; }
}

double OCCTBSplineApproxInterpMaxError(OCCTBSplineApproxInterpRef ref) {
    if (!ref || !ref->solver) return -1.0;
    return ref->solver->MaxError();
}

void OCCTBSplineApproxInterpSetAlpha(OCCTBSplineApproxInterpRef ref, double alpha) {
    if (ref && ref->solver) ref->solver->SetParametrizationAlpha(alpha);
}

void OCCTBSplineApproxInterpSetMinPivot(OCCTBSplineApproxInterpRef ref, double val) {
    if (ref && ref->solver) ref->solver->SetMinPivot(val);
}

void OCCTBSplineApproxInterpSetClosedTol(OCCTBSplineApproxInterpRef ref, double val) {
    if (ref && ref->solver) ref->solver->SetClosedTolerance(val);
}

void OCCTBSplineApproxInterpSetKnotTol(OCCTBSplineApproxInterpRef ref, double val) {
    if (ref && ref->solver) ref->solver->SetKnotInsertionTolerance(val);
}

void OCCTBSplineApproxInterpSetConvergenceTol(OCCTBSplineApproxInterpRef ref, double val) {
    if (ref && ref->solver) ref->solver->SetConvergenceTolerance(val);
}

void OCCTBSplineApproxInterpSetProjectionTol(OCCTBSplineApproxInterpRef ref, double val) {
    if (ref && ref->solver) ref->solver->SetProjectionTolerance(val);
}

// --- GeomAdaptor_TransformedCurve ---

OCCTCurve3DRef OCCTGeomAdaptorTransformedCurveCreate(
    OCCTCurve3DRef curve,
    double tx, double ty, double tz) {
    if (!curve || curve->curve.IsNull()) return nullptr;
    try {
        gp_Trsf trsf;
        trsf.SetTranslation(gp_Vec(tx, ty, tz));
        // Create a trimmed copy of the original curve with the transform applied
        Handle(Geom_Curve) origCurve = curve->curve;
        Handle(Geom_Curve) copyCurve = Handle(Geom_Curve)::DownCast(origCurve->Copy());
        if (copyCurve.IsNull()) return nullptr;
        copyCurve->Transform(trsf);
        auto ref = new OCCTCurve3D();
        ref->curve = copyCurve;
        return ref;
    } catch (...) { return nullptr; }
}

// --- GeomEval_TBezierCurve ---

OCCTCurve3DRef OCCTGeomEvalTBezierCurveCreate(
    const double* poles, int32_t count, double alpha) {
    if (!poles || count < 3 || count % 2 == 0) return nullptr;
    try {
        NCollection_Array1<gp_Pnt> pts(1, count);
        for (int i = 0; i < count; i++)
            pts(i + 1) = gp_Pnt(poles[i*3], poles[i*3+1], poles[i*3+2]);
        auto tc = new GeomEval_TBezierCurve(pts, alpha);
        occ::handle<Geom_Curve> hCurve(tc);
        auto ref = new OCCTCurve3D();
        ref->curve = hCurve;
        return ref;
    } catch (...) { return nullptr; }
}

OCCTCurve3DRef OCCTGeomEvalTBezierCurveCreateRational(
    const double* poles, const double* weights,
    int32_t count, double alpha) {
    if (!poles || !weights || count < 3 || count % 2 == 0) return nullptr;
    try {
        NCollection_Array1<gp_Pnt> pts(1, count);
        NCollection_Array1<double> wts(1, count);
        for (int i = 0; i < count; i++) {
            pts(i + 1) = gp_Pnt(poles[i*3], poles[i*3+1], poles[i*3+2]);
            wts(i + 1) = weights[i];
        }
        auto tc = new GeomEval_TBezierCurve(pts, wts, alpha);
        occ::handle<Geom_Curve> hCurve(tc);
        auto ref = new OCCTCurve3D();
        ref->curve = hCurve;
        return ref;
    } catch (...) { return nullptr; }
}

// --- GeomEval_AHTBezierCurve ---

OCCTCurve3DRef OCCTGeomEvalAHTBezierCurveCreate(
    const double* poles, int32_t count,
    int32_t algDegree, double alpha, double beta) {
    if (!poles || count < 1) return nullptr;
    try {
        NCollection_Array1<gp_Pnt> pts(1, count);
        for (int i = 0; i < count; i++)
            pts(i + 1) = gp_Pnt(poles[i*3], poles[i*3+1], poles[i*3+2]);
        auto ac = new GeomEval_AHTBezierCurve(pts, algDegree, alpha, beta);
        occ::handle<Geom_Curve> hCurve(ac);
        auto ref = new OCCTCurve3D();
        ref->curve = hCurve;
        return ref;
    } catch (...) { return nullptr; }
}

OCCTCurve3DRef OCCTGeomEvalAHTBezierCurveCreateRational(
    const double* poles, const double* weights,
    int32_t count, int32_t algDegree, double alpha, double beta) {
    if (!poles || !weights || count < 1) return nullptr;
    try {
        NCollection_Array1<gp_Pnt> pts(1, count);
        NCollection_Array1<double> wts(1, count);
        for (int i = 0; i < count; i++) {
            pts(i + 1) = gp_Pnt(poles[i*3], poles[i*3+1], poles[i*3+2]);
            wts(i + 1) = weights[i];
        }
        auto ac = new GeomEval_AHTBezierCurve(pts, wts, algDegree, alpha, beta);
        occ::handle<Geom_Curve> hCurve(ac);
        auto ref = new OCCTCurve3D();
        ref->curve = hCurve;
        return ref;
    } catch (...) { return nullptr; }
}

// --- GeomEval_TBezierSurface ---

OCCTSurfaceRef OCCTGeomEvalTBezierSurfaceCreate(
    const double* poles, int32_t uCount, int32_t vCount,
    double alphaU, double alphaV) {
    if (!poles || uCount < 3 || vCount < 3 || uCount % 2 == 0 || vCount % 2 == 0) return nullptr;
    try {
        NCollection_Array2<gp_Pnt> pts(1, uCount, 1, vCount);
        for (int i = 0; i < uCount; i++)
            for (int j = 0; j < vCount; j++) {
                int idx = (i * vCount + j) * 3;
                pts(i + 1, j + 1) = gp_Pnt(poles[idx], poles[idx+1], poles[idx+2]);
            }
        auto ts = new GeomEval_TBezierSurface(pts, alphaU, alphaV);
        occ::handle<Geom_Surface> hSurf(ts);
        auto ref = new OCCTSurface(hSurf);
        return ref;
    } catch (...) { return nullptr; }
}

// --- GeomEval_AHTBezierSurface ---

OCCTSurfaceRef OCCTGeomEvalAHTBezierSurfaceCreate(
    const double* poles, int32_t uCount, int32_t vCount,
    int32_t algDegreeU, int32_t algDegreeV,
    double alphaU, double alphaV, double betaU, double betaV) {
    if (!poles || uCount < 1 || vCount < 1) return nullptr;
    try {
        NCollection_Array2<gp_Pnt> pts(1, uCount, 1, vCount);
        for (int i = 0; i < uCount; i++)
            for (int j = 0; j < vCount; j++) {
                int idx = (i * vCount + j) * 3;
                pts(i + 1, j + 1) = gp_Pnt(poles[idx], poles[idx+1], poles[idx+2]);
            }
        auto as = new GeomEval_AHTBezierSurface(pts, algDegreeU, algDegreeV,
                                                  alphaU, alphaV, betaU, betaV);
        occ::handle<Geom_Surface> hSurf(as);
        auto ref = new OCCTSurface(hSurf);
        return ref;
    } catch (...) { return nullptr; }
}

// --- Geom2dEval_TBezierCurve ---

OCCTCurve2DRef OCCTGeom2dEvalTBezierCurveCreate(
    const double* poles, int32_t count, double alpha) {
    if (!poles || count < 3 || count % 2 == 0) return nullptr;
    try {
        NCollection_Array1<gp_Pnt2d> pts(1, count);
        for (int i = 0; i < count; i++)
            pts(i + 1) = gp_Pnt2d(poles[i*2], poles[i*2+1]);
        auto tc = new Geom2dEval_TBezierCurve(pts, alpha);
        occ::handle<Geom2d_Curve> hCurve(tc);
        auto ref = new OCCTCurve2D();
        ref->curve = hCurve;
        return ref;
    } catch (...) { return nullptr; }
}

// --- Geom2dEval_AHTBezierCurve ---

OCCTCurve2DRef OCCTGeom2dEvalAHTBezierCurveCreate(
    const double* poles, int32_t count,
    int32_t algDegree, double alpha, double beta) {
    if (!poles || count < 1) return nullptr;
    try {
        NCollection_Array1<gp_Pnt2d> pts(1, count);
        for (int i = 0; i < count; i++)
            pts(i + 1) = gp_Pnt2d(poles[i*2], poles[i*2+1]);
        auto ac = new Geom2dEval_AHTBezierCurve(pts, algDegree, alpha, beta);
        occ::handle<Geom2d_Curve> hCurve(ac);
        auto ref = new OCCTCurve2D();
        ref->curve = hCurve;
        return ref;
    } catch (...) { return nullptr; }
}

// end of v0.131.0 implementations

