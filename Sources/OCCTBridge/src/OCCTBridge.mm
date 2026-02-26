//
//  OCCTBridge.mm
//  OCCTSwift
//
//  Objective-C++ implementation bridging to OpenCASCADE
//

#import "../include/OCCTBridge.h"

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

// MARK: - Internal Structures

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

OCCTShapeRef OCCTShapeCreateCone(double bottomRadius, double topRadius, double height) {
    try {
        BRepPrimAPI_MakeCone maker(bottomRadius, topRadius, height);
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

// MARK: - Meshing

OCCTMeshRef OCCTShapeCreateMesh(OCCTShapeRef shape, double linearDeflection, double angularDeflection) {
    if (!shape) return nullptr;

    OCCTMesh* mesh = nullptr;
    try {
        // Generate mesh
        BRepMesh_IncrementalMesh mesher(shape->shape, linearDeflection, Standard_False, angularDeflection);
        mesher.Perform();

        mesh = new OCCTMesh();

        // Extract triangles from all faces
        TopExp_Explorer explorer(shape->shape, TopAbs_FACE);
        int32_t faceIndex = 0;

        while (explorer.More()) {
            TopoDS_Face face = TopoDS::Face(explorer.Current());
            TopLoc_Location location;
            Handle(Poly_Triangulation) triangulation = BRep_Tool::Triangulation(face, location);

            if (!triangulation.IsNull()) {
                gp_Trsf transformation = location.Transformation();
                Standard_Integer baseIndex = static_cast<Standard_Integer>(mesh->vertices.size() / 3);

                // Add vertices and normals
                for (Standard_Integer i = 1; i <= triangulation->NbNodes(); i++) {
                    gp_Pnt point = triangulation->Node(i).Transformed(transformation);
                    mesh->vertices.push_back(static_cast<float>(point.X()));
                    mesh->vertices.push_back(static_cast<float>(point.Y()));
                    mesh->vertices.push_back(static_cast<float>(point.Z()));

                    // Use normals if available
                    if (triangulation->HasNormals()) {
                        gp_Dir normal = triangulation->Normal(i);
                        mesh->normals.push_back(static_cast<float>(normal.X()));
                        mesh->normals.push_back(static_cast<float>(normal.Y()));
                        mesh->normals.push_back(static_cast<float>(normal.Z()));
                    } else {
                        // Default normal (will be computed later if needed)
                        mesh->normals.push_back(0.0f);
                        mesh->normals.push_back(0.0f);
                        mesh->normals.push_back(1.0f);
                    }
                }

                // Add triangles with face index and per-triangle normals
                for (Standard_Integer i = 1; i <= triangulation->NbTriangles(); i++) {
                    const Poly_Triangle& triangle = triangulation->Triangle(i);
                    Standard_Integer n1, n2, n3;
                    triangle.Get(n1, n2, n3);

                    // Handle face orientation
                    if (face.Orientation() == TopAbs_REVERSED) {
                        std::swap(n2, n3);
                    }

                    mesh->indices.push_back(baseIndex + n1 - 1);
                    mesh->indices.push_back(baseIndex + n2 - 1);
                    mesh->indices.push_back(baseIndex + n3 - 1);

                    // Store face index for this triangle
                    mesh->faceIndices.push_back(faceIndex);

                    // Compute triangle normal
                    gp_Pnt p1 = triangulation->Node(n1).Transformed(transformation);
                    gp_Pnt p2 = triangulation->Node(n2).Transformed(transformation);
                    gp_Pnt p3 = triangulation->Node(n3).Transformed(transformation);
                    gp_Vec v1(p1, p2);
                    gp_Vec v2(p1, p3);
                    gp_Vec triNormal = v1.Crossed(v2);
                    if (triNormal.Magnitude() > 1e-10) {
                        triNormal.Normalize();
                    }
                    mesh->triangleNormals.push_back(static_cast<float>(triNormal.X()));
                    mesh->triangleNormals.push_back(static_cast<float>(triNormal.Y()));
                    mesh->triangleNormals.push_back(static_cast<float>(triNormal.Z()));
                }
            }

            faceIndex++;
            explorer.Next();
        }

        return mesh;
    } catch (...) {
        delete mesh;
        return nullptr;
    }
}

// MARK: - Enhanced Mesh Parameters

OCCTMeshParameters OCCTMeshParametersDefault(void) {
    OCCTMeshParameters params;
    params.deflection = 0.1;
    params.angle = 0.5;  // ~30 degrees
    params.deflectionInterior = 0.0;  // Use deflection
    params.angleInterior = 0.0;  // Use angle
    params.minSize = 0.0;  // No minimum
    params.relative = false;
    params.inParallel = true;
    params.internalVertices = true;
    params.controlSurfaceDeflection = true;
    params.adjustMinSize = false;
    return params;
}

OCCTMeshRef OCCTShapeCreateMeshWithParams(OCCTShapeRef shape, OCCTMeshParameters params) {
    if (!shape) return nullptr;

    OCCTMesh* mesh = nullptr;
    try {
        // Configure IMeshTools_Parameters
        IMeshTools_Parameters meshParams;
        meshParams.Deflection = params.deflection;
        meshParams.Angle = params.angle;
        meshParams.DeflectionInterior = params.deflectionInterior > 0 ? params.deflectionInterior : params.deflection;
        meshParams.AngleInterior = params.angleInterior > 0 ? params.angleInterior : params.angle;
        meshParams.MinSize = params.minSize;
        meshParams.Relative = params.relative ? Standard_True : Standard_False;
        meshParams.InParallel = params.inParallel ? Standard_True : Standard_False;
        meshParams.InternalVerticesMode = params.internalVertices ? Standard_True : Standard_False;
        meshParams.ControlSurfaceDeflection = params.controlSurfaceDeflection ? Standard_True : Standard_False;
        meshParams.AdjustMinSize = params.adjustMinSize ? Standard_True : Standard_False;

        // Generate mesh with enhanced parameters
        BRepMesh_IncrementalMesh mesher(shape->shape, meshParams);
        mesher.Perform();

        mesh = new OCCTMesh();

        // Extract triangles from all faces (same as OCCTShapeCreateMesh)
        TopExp_Explorer explorer(shape->shape, TopAbs_FACE);
        int32_t faceIndex = 0;

        while (explorer.More()) {
            TopoDS_Face face = TopoDS::Face(explorer.Current());
            TopLoc_Location location;
            Handle(Poly_Triangulation) triangulation = BRep_Tool::Triangulation(face, location);

            if (!triangulation.IsNull()) {
                gp_Trsf transformation = location.Transformation();
                Standard_Integer baseIndex = static_cast<Standard_Integer>(mesh->vertices.size() / 3);

                for (Standard_Integer i = 1; i <= triangulation->NbNodes(); i++) {
                    gp_Pnt point = triangulation->Node(i).Transformed(transformation);
                    mesh->vertices.push_back(static_cast<float>(point.X()));
                    mesh->vertices.push_back(static_cast<float>(point.Y()));
                    mesh->vertices.push_back(static_cast<float>(point.Z()));

                    if (triangulation->HasNormals()) {
                        gp_Dir normal = triangulation->Normal(i);
                        mesh->normals.push_back(static_cast<float>(normal.X()));
                        mesh->normals.push_back(static_cast<float>(normal.Y()));
                        mesh->normals.push_back(static_cast<float>(normal.Z()));
                    } else {
                        mesh->normals.push_back(0.0f);
                        mesh->normals.push_back(0.0f);
                        mesh->normals.push_back(1.0f);
                    }
                }

                for (Standard_Integer i = 1; i <= triangulation->NbTriangles(); i++) {
                    const Poly_Triangle& triangle = triangulation->Triangle(i);
                    Standard_Integer n1, n2, n3;
                    triangle.Get(n1, n2, n3);

                    if (face.Orientation() == TopAbs_REVERSED) {
                        std::swap(n2, n3);
                    }

                    mesh->indices.push_back(baseIndex + n1 - 1);
                    mesh->indices.push_back(baseIndex + n2 - 1);
                    mesh->indices.push_back(baseIndex + n3 - 1);

                    mesh->faceIndices.push_back(faceIndex);

                    gp_Pnt p1 = triangulation->Node(n1).Transformed(transformation);
                    gp_Pnt p2 = triangulation->Node(n2).Transformed(transformation);
                    gp_Pnt p3 = triangulation->Node(n3).Transformed(transformation);
                    gp_Vec v1(p1, p2);
                    gp_Vec v2(p1, p3);
                    gp_Vec triNormal = v1.Crossed(v2);
                    if (triNormal.Magnitude() > 1e-10) {
                        triNormal.Normalize();
                    }
                    mesh->triangleNormals.push_back(static_cast<float>(triNormal.X()));
                    mesh->triangleNormals.push_back(static_cast<float>(triNormal.Y()));
                    mesh->triangleNormals.push_back(static_cast<float>(triNormal.Z()));
                }
            }

            faceIndex++;
            explorer.Next();
        }

        return mesh;
    } catch (...) {
        delete mesh;
        return nullptr;
    }
}

// MARK: - Edge Discretization

void OCCTShapeBuildCurves3d(OCCTShapeRef shape) {
    if (!shape) return;
    try {
        BRepLib::BuildCurves3d(shape->shape);
    } catch (...) {}
}

int32_t OCCTShapeGetEdgePolyline(OCCTShapeRef shape, int32_t edgeIndex, double deflection, double* outPoints, int32_t maxPoints) {
    if (!shape || !outPoints || maxPoints < 2 || edgeIndex < 0) return -1;

    try {
        // Use IndexedMap to match OCCTShapeGetTotalEdgeCount ordering
        TopTools_IndexedMapOfShape edgeMap;
        TopExp::MapShapes(shape->shape, TopAbs_EDGE, edgeMap);

        if (edgeIndex >= edgeMap.Extent()) return -1;

        TopoDS_Edge edge = TopoDS::Edge(edgeMap(edgeIndex + 1));  // OCCT is 1-based

        // Skip degenerate edges (zero-length, e.g. poles of spheres)
        if (BRep_Tool::Degenerated(edge)) return -1;

        // Try primary path: BRepAdaptor_Curve + TangentialDeflection
        try {
            BRepAdaptor_Curve curve(edge);
            GCPnts_TangentialDeflection discretizer(curve, deflection, 0.1);

            if (discretizer.NbPoints() >= 2) {
                int32_t numPoints = std::min(discretizer.NbPoints(), maxPoints);
                for (int32_t i = 0; i < numPoints; i++) {
                    gp_Pnt pt = discretizer.Value(i + 1);
                    outPoints[i * 3 + 0] = pt.X();
                    outPoints[i * 3 + 1] = pt.Y();
                    outPoints[i * 3 + 2] = pt.Z();
                }
                return numPoints;
            }
        } catch (...) {
            // BRepAdaptor_Curve failed — fall through to pcurve fallback
        }

        // Fallback: evaluate pcurve on parent surface
        // Find a face that owns this edge and use its pcurve + surface
        TopTools_IndexedDataMapOfShapeListOfShape edgeFaceMap;
        TopExp::MapShapesAndAncestors(shape->shape, TopAbs_EDGE, TopAbs_FACE, edgeFaceMap);

        int32_t mapIndex = edgeFaceMap.FindIndex(edge);
        if (mapIndex > 0) {
            const TopTools_ListOfShape& faces = edgeFaceMap(mapIndex);
            if (!faces.IsEmpty()) {
                TopoDS_Face face = TopoDS::Face(faces.First());
                Standard_Real first, last;
                Handle(Geom2d_Curve) pcurve = BRep_Tool::CurveOnSurface(edge, face, first, last);
                if (!pcurve.IsNull()) {
                    Handle(Geom_Surface) surface = BRep_Tool::Surface(face);
                    if (!surface.IsNull()) {
                        int32_t numPoints = std::min(maxPoints, (int32_t)50);
                        if (numPoints < 2) numPoints = 2;
                        for (int32_t i = 0; i < numPoints; i++) {
                            double t = (numPoints == 1) ? first : first + (last - first) * i / (numPoints - 1);
                            gp_Pnt2d uv = pcurve->Value(t);
                            gp_Pnt pt;
                            surface->D0(uv.X(), uv.Y(), pt);
                            outPoints[i * 3 + 0] = pt.X();
                            outPoints[i * 3 + 1] = pt.Y();
                            outPoints[i * 3 + 2] = pt.Z();
                        }
                        return numPoints;
                    }
                }
            }
        }

        return -1;
    } catch (...) {
        return -1;
    }
}

// MARK: - Direct Triangle Access

int32_t OCCTMeshGetTrianglesWithFaces(OCCTMeshRef mesh, OCCTTriangle* outTriangles) {
    if (!mesh || !outTriangles) return 0;

    try {
        int32_t triCount = static_cast<int32_t>(mesh->indices.size() / 3);

        for (int32_t i = 0; i < triCount; i++) {
            outTriangles[i].v1 = mesh->indices[i * 3 + 0];
            outTriangles[i].v2 = mesh->indices[i * 3 + 1];
            outTriangles[i].v3 = mesh->indices[i * 3 + 2];

            // Face index (-1 if not available)
            if (i < static_cast<int32_t>(mesh->faceIndices.size())) {
                outTriangles[i].faceIndex = mesh->faceIndices[i];
            } else {
                outTriangles[i].faceIndex = -1;
            }

            // Triangle normal
            if (i * 3 + 2 < static_cast<int32_t>(mesh->triangleNormals.size())) {
                outTriangles[i].nx = mesh->triangleNormals[i * 3 + 0];
                outTriangles[i].ny = mesh->triangleNormals[i * 3 + 1];
                outTriangles[i].nz = mesh->triangleNormals[i * 3 + 2];
            } else {
                outTriangles[i].nx = 0.0f;
                outTriangles[i].ny = 0.0f;
                outTriangles[i].nz = 1.0f;
            }
        }

        return triCount;
    } catch (...) {
        return 0;
    }
}

// MARK: - Mesh to Shape Conversion

OCCTShapeRef OCCTMeshToShape(OCCTMeshRef mesh) {
    if (!mesh || mesh->indices.empty()) return nullptr;

    try {
        // Use sewing to create a shell from triangles
        BRepBuilderAPI_Sewing sewing(1e-6);  // Tolerance for edge merging

        int32_t triCount = static_cast<int32_t>(mesh->indices.size() / 3);

        for (int32_t i = 0; i < triCount; i++) {
            uint32_t i1 = mesh->indices[i * 3 + 0];
            uint32_t i2 = mesh->indices[i * 3 + 1];
            uint32_t i3 = mesh->indices[i * 3 + 2];

            gp_Pnt p1(mesh->vertices[i1 * 3 + 0], mesh->vertices[i1 * 3 + 1], mesh->vertices[i1 * 3 + 2]);
            gp_Pnt p2(mesh->vertices[i2 * 3 + 0], mesh->vertices[i2 * 3 + 1], mesh->vertices[i2 * 3 + 2]);
            gp_Pnt p3(mesh->vertices[i3 * 3 + 0], mesh->vertices[i3 * 3 + 1], mesh->vertices[i3 * 3 + 2]);

            // Skip degenerate triangles
            if (p1.Distance(p2) < 1e-9 || p2.Distance(p3) < 1e-9 || p3.Distance(p1) < 1e-9) {
                continue;
            }

            // Create edges
            TopoDS_Edge e1 = BRepBuilderAPI_MakeEdge(p1, p2);
            TopoDS_Edge e2 = BRepBuilderAPI_MakeEdge(p2, p3);
            TopoDS_Edge e3 = BRepBuilderAPI_MakeEdge(p3, p1);

            // Create wire from edges
            BRepBuilderAPI_MakeWire wireMaker;
            wireMaker.Add(e1);
            wireMaker.Add(e2);
            wireMaker.Add(e3);
            if (!wireMaker.IsDone()) continue;

            // Create face from wire
            BRepBuilderAPI_MakeFace faceMaker(wireMaker.Wire());
            if (!faceMaker.IsDone()) continue;

            sewing.Add(faceMaker.Face());
        }

        sewing.Perform();

        TopoDS_Shape sewedShape = sewing.SewedShape();
        if (sewedShape.IsNull()) return nullptr;

        return new OCCTShape(sewedShape);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Mesh Booleans (via B-Rep Roundtrip)

OCCTMeshRef OCCTMeshUnion(OCCTMeshRef mesh1, OCCTMeshRef mesh2, double deflection) {
    if (!mesh1 || !mesh2) return nullptr;

    try {
        // Convert meshes to shapes
        OCCTShapeRef shape1 = OCCTMeshToShape(mesh1);
        OCCTShapeRef shape2 = OCCTMeshToShape(mesh2);
        if (!shape1 || !shape2) {
            OCCTShapeRelease(shape1);
            OCCTShapeRelease(shape2);
            return nullptr;
        }

        // Perform boolean union
        OCCTShapeRef result = OCCTShapeUnion(shape1, shape2);
        OCCTShapeRelease(shape1);
        OCCTShapeRelease(shape2);

        if (!result) return nullptr;

        // Re-mesh the result
        OCCTMeshRef resultMesh = OCCTShapeCreateMesh(result, deflection, 0.5);
        OCCTShapeRelease(result);

        return resultMesh;
    } catch (...) {
        return nullptr;
    }
}

OCCTMeshRef OCCTMeshSubtract(OCCTMeshRef mesh1, OCCTMeshRef mesh2, double deflection) {
    if (!mesh1 || !mesh2) return nullptr;

    try {
        // Convert meshes to shapes
        OCCTShapeRef shape1 = OCCTMeshToShape(mesh1);
        OCCTShapeRef shape2 = OCCTMeshToShape(mesh2);
        if (!shape1 || !shape2) {
            OCCTShapeRelease(shape1);
            OCCTShapeRelease(shape2);
            return nullptr;
        }

        // Perform boolean subtraction
        OCCTShapeRef result = OCCTShapeSubtract(shape1, shape2);
        OCCTShapeRelease(shape1);
        OCCTShapeRelease(shape2);

        if (!result) return nullptr;

        // Re-mesh the result
        OCCTMeshRef resultMesh = OCCTShapeCreateMesh(result, deflection, 0.5);
        OCCTShapeRelease(result);

        return resultMesh;
    } catch (...) {
        return nullptr;
    }
}

OCCTMeshRef OCCTMeshIntersect(OCCTMeshRef mesh1, OCCTMeshRef mesh2, double deflection) {
    if (!mesh1 || !mesh2) return nullptr;

    try {
        // Convert meshes to shapes
        OCCTShapeRef shape1 = OCCTMeshToShape(mesh1);
        OCCTShapeRef shape2 = OCCTMeshToShape(mesh2);
        if (!shape1 || !shape2) {
            OCCTShapeRelease(shape1);
            OCCTShapeRelease(shape2);
            return nullptr;
        }

        // Perform boolean intersection
        OCCTShapeRef result = OCCTShapeIntersect(shape1, shape2);
        OCCTShapeRelease(shape1);
        OCCTShapeRelease(shape2);

        if (!result) return nullptr;

        // Re-mesh the result
        OCCTMeshRef resultMesh = OCCTShapeCreateMesh(result, deflection, 0.5);
        OCCTShapeRelease(result);

        return resultMesh;
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Memory Management

// MARK: - Shape Conversion

OCCTShapeRef OCCTShapeFromWire(OCCTWireRef wireRef) {
    if (!wireRef) return nullptr;
    return new OCCTShape(wireRef->wire);
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

// MARK: - Mesh Access

int32_t OCCTMeshGetVertexCount(OCCTMeshRef mesh) {
    if (!mesh) return 0;
    return static_cast<int32_t>(mesh->vertices.size() / 3);
}

int32_t OCCTMeshGetTriangleCount(OCCTMeshRef mesh) {
    if (!mesh) return 0;
    return static_cast<int32_t>(mesh->indices.size() / 3);
}

void OCCTMeshGetVertices(OCCTMeshRef mesh, float* outVertices) {
    if (!mesh || !outVertices) return;
    std::copy(mesh->vertices.begin(), mesh->vertices.end(), outVertices);
}

void OCCTMeshGetNormals(OCCTMeshRef mesh, float* outNormals) {
    if (!mesh || !outNormals) return;
    std::copy(mesh->normals.begin(), mesh->normals.end(), outNormals);
}

void OCCTMeshGetIndices(OCCTMeshRef mesh, uint32_t* outIndices) {
    if (!mesh || !outIndices) return;
    std::copy(mesh->indices.begin(), mesh->indices.end(), outIndices);
}

// MARK: - Export

bool OCCTExportSTL(OCCTShapeRef shape, const char* path, double deflection) {
    if (!shape || !path) return false;

    try {
        // Mesh the shape first
        BRepMesh_IncrementalMesh mesher(shape->shape, deflection);
        mesher.Perform();

        StlAPI_Writer writer;
        writer.ASCIIMode() = Standard_False; // Binary STL for smaller files
        return writer.Write(shape->shape, path);
    } catch (...) {
        return false;
    }
}

bool OCCTExportSTLWithMode(OCCTShapeRef shape, const char* path, double deflection, bool ascii) {
    if (!shape || !path) return false;

    try {
        BRepMesh_IncrementalMesh mesher(shape->shape, deflection);
        mesher.Perform();

        StlAPI_Writer writer;
        writer.ASCIIMode() = ascii ? Standard_True : Standard_False;
        return writer.Write(shape->shape, path);
    } catch (...) {
        return false;
    }
}

bool OCCTExportSTEP(OCCTShapeRef shape, const char* path) {
    if (!shape || !path) return false;

    try {
        // Use a scoped block to ensure all OCCT objects are destroyed before return
        bool success = false;
        {
            STEPControl_Writer writer;
            Interface_Static::SetCVal("write.step.schema", "AP214");

            IFSelect_ReturnStatus status = writer.Transfer(shape->shape, STEPControl_AsIs);
            if (status != IFSelect_RetDone) {
                return false;
            }

            status = writer.Write(path);
            success = (status == IFSelect_RetDone);

            // Writer goes out of scope here and is automatically destroyed
        }
        return success;
    } catch (...) {
        return false;
    }
}

bool OCCTExportSTEPWithName(OCCTShapeRef shape, const char* path, const char* name) {
    if (!shape || !path) return false;

    try {
        // Use a scoped block to ensure all OCCT objects are destroyed before return
        bool success = false;
        {
            STEPControl_Writer writer;
            Interface_Static::SetCVal("write.step.schema", "AP214");
            if (name) {
                Interface_Static::SetCVal("write.step.product.name", name);
            }

            IFSelect_ReturnStatus status = writer.Transfer(shape->shape, STEPControl_AsIs);
            if (status != IFSelect_RetDone) {
                return false;
            }

            status = writer.Write(path);
            success = (status == IFSelect_RetDone);

            // Writer goes out of scope here and is automatically destroyed
        }
        return success;
    } catch (...) {
        return false;
    }
}

// MARK: - Import

OCCTShapeRef OCCTImportSTEP(const char* path) {
    if (!path) return nullptr;

    try {
        STEPControl_Reader reader;
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

// MARK: - Robust STEP Import

int OCCTShapeGetType(OCCTShapeRef shape) {
    if (!shape) return -1;
    return static_cast<int>(shape->shape.ShapeType());
}

bool OCCTShapeIsValidSolid(OCCTShapeRef shape) {
    if (!shape) return false;
    try {
        if (shape->shape.ShapeType() != TopAbs_SOLID) return false;
        BRepCheck_Analyzer analyzer(shape->shape);
        return analyzer.IsValid();
    } catch (...) {
        return false;
    }
}

OCCTShapeRef OCCTImportSTEPRobust(const char* path) {
    if (!path) return nullptr;

    try {
        STEPControl_Reader reader;

        // Configure reader for better precision handling
        Interface_Static::SetIVal("read.precision.mode", 0);
        Interface_Static::SetRVal("read.maxprecision.val", 0.1);
        Interface_Static::SetIVal("read.surfacecurve.mode", 3);
        Interface_Static::SetIVal("read.step.product.mode", 1);

        IFSelect_ReturnStatus status = reader.ReadFile(path);
        if (status != IFSelect_RetDone) return nullptr;

        if (reader.TransferRoots() == 0) return nullptr;

        TopoDS_Shape shape = reader.OneShape();
        if (shape.IsNull()) return nullptr;

        TopAbs_ShapeEnum shapeType = shape.ShapeType();

        // If already a solid, just apply healing
        if (shapeType == TopAbs_SOLID) {
            ShapeFix_Shape fixer(shape);
            fixer.Perform();
            TopoDS_Shape fixed = fixer.Shape();
            return new OCCTShape(fixed.IsNull() ? shape : fixed);
        }

        // Try sewing and solid creation for non-solids
        if (shapeType == TopAbs_COMPOUND || shapeType == TopAbs_SHELL ||
            shapeType == TopAbs_FACE) {

            // Sew disconnected faces/shells
            BRepBuilderAPI_Sewing sewing(1.0e-4);
            sewing.SetNonManifoldMode(Standard_False);
            sewing.Add(shape);
            sewing.Perform();
            TopoDS_Shape sewedShape = sewing.SewedShape();
            if (sewedShape.IsNull()) sewedShape = shape;

            // Try to create solid from shell
            TopoDS_Shape resultShape = sewedShape;
            if (sewedShape.ShapeType() != TopAbs_SOLID) {
                TopExp_Explorer shellExp(sewedShape, TopAbs_SHELL);
                if (shellExp.More()) {
                    BRepBuilderAPI_MakeSolid makeSolid(TopoDS::Shell(shellExp.Current()));
                    if (makeSolid.IsDone()) {
                        resultShape = makeSolid.Solid();
                    }
                }
            }

            // Apply shape healing
            ShapeFix_Shape fixer(resultShape);
            fixer.Perform();
            TopoDS_Shape fixed = fixer.Shape();
            return new OCCTShape(fixed.IsNull() ? resultShape : fixed);
        }

        // Fallback: just heal whatever we got
        ShapeFix_Shape fixer(shape);
        fixer.Perform();
        TopoDS_Shape fixed = fixer.Shape();
        return new OCCTShape(fixed.IsNull() ? shape : fixed);

    } catch (...) {
        return nullptr;
    }
}

OCCTSTEPImportResult OCCTImportSTEPWithDiagnostics(const char* path) {
    OCCTSTEPImportResult result = {nullptr, -1, -1, false, false, false};
    if (!path) return result;

    try {
        STEPControl_Reader reader;

        // Configure reader
        Interface_Static::SetIVal("read.precision.mode", 0);
        Interface_Static::SetRVal("read.maxprecision.val", 0.1);
        Interface_Static::SetIVal("read.surfacecurve.mode", 3);
        Interface_Static::SetIVal("read.step.product.mode", 1);

        if (reader.ReadFile(path) != IFSelect_RetDone) return result;
        if (reader.TransferRoots() == 0) return result;

        TopoDS_Shape shape = reader.OneShape();
        if (shape.IsNull()) return result;

        result.originalType = static_cast<int>(shape.ShapeType());

        // Process non-solids
        if (shape.ShapeType() != TopAbs_SOLID) {
            // Try sewing
            BRepBuilderAPI_Sewing sewing(1.0e-4);
            sewing.SetNonManifoldMode(Standard_False);
            sewing.Add(shape);
            sewing.Perform();
            TopoDS_Shape sewedShape = sewing.SewedShape();
            if (!sewedShape.IsNull() && !sewedShape.IsSame(shape)) {
                shape = sewedShape;
                result.sewingApplied = true;
            }

            // Try solid creation
            if (shape.ShapeType() != TopAbs_SOLID) {
                TopExp_Explorer shellExp(shape, TopAbs_SHELL);
                if (shellExp.More()) {
                    BRepBuilderAPI_MakeSolid makeSolid(TopoDS::Shell(shellExp.Current()));
                    if (makeSolid.IsDone()) {
                        shape = makeSolid.Solid();
                        result.solidCreated = true;
                    }
                }
            }
        }

        // Apply shape healing
        ShapeFix_Shape fixer(shape);
        fixer.Perform();
        TopoDS_Shape fixed = fixer.Shape();
        if (!fixed.IsNull()) {
            shape = fixed;
            result.healingApplied = true;
        }

        result.shape = new OCCTShape(shape);
        result.resultType = static_cast<int>(shape.ShapeType());
        return result;

    } catch (...) {
        return result;
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

// MARK: - XDE/XCAF Document Support (v0.6.0)

OCCTDocumentRef OCCTDocumentCreate(void) {
    OCCTDocument* document = nullptr;
    try {
        document = new OCCTDocument();

        // Create a new document
        document->app->NewDocument("MDTV-XCAF", document->doc);

        if (document->doc.IsNull()) {
            delete document;
            return nullptr;
        }

        // Get the tools
        document->shapeTool = XCAFDoc_DocumentTool::ShapeTool(document->doc->Main());
        document->colorTool = XCAFDoc_DocumentTool::ColorTool(document->doc->Main());
        document->materialTool = XCAFDoc_DocumentTool::VisMaterialTool(document->doc->Main());

        return document;
    } catch (...) {
        delete document;
        return nullptr;
    }
}

OCCTDocumentRef OCCTDocumentLoadSTEP(const char* path) {
    if (!path) return nullptr;

    OCCTDocument* document = nullptr;
    try {
        document = new OCCTDocument();

        // Create a new document
        document->app->NewDocument("MDTV-XCAF", document->doc);

        if (document->doc.IsNull()) {
            delete document;
            return nullptr;
        }

        // Configure the reader
        STEPCAFControl_Reader reader;
        reader.SetColorMode(Standard_True);
        reader.SetNameMode(Standard_True);
        reader.SetLayerMode(Standard_True);
        reader.SetPropsMode(Standard_True);
        reader.SetMatMode(Standard_True);  // Enable material reading

        // Read the file
        IFSelect_ReturnStatus status = reader.ReadFile(path);
        if (status != IFSelect_RetDone) {
            delete document;
            return nullptr;
        }

        // Transfer to document
        if (!reader.Transfer(document->doc)) {
            delete document;
            return nullptr;
        }

        // Get the tools
        document->shapeTool = XCAFDoc_DocumentTool::ShapeTool(document->doc->Main());
        document->colorTool = XCAFDoc_DocumentTool::ColorTool(document->doc->Main());
        document->materialTool = XCAFDoc_DocumentTool::VisMaterialTool(document->doc->Main());

        return document;
    } catch (...) {
        delete document;
        return nullptr;
    }
}

bool OCCTDocumentWriteSTEP(OCCTDocumentRef doc, const char* path) {
    if (!doc || !path) return false;

    try {
        STEPCAFControl_Writer writer;
        writer.SetColorMode(Standard_True);
        writer.SetNameMode(Standard_True);
        writer.SetLayerMode(Standard_True);
        writer.SetPropsMode(Standard_True);
        writer.SetMaterialMode(Standard_True);  // Enable material writing

        if (!writer.Transfer(doc->doc, STEPControl_AsIs)) {
            return false;
        }

        IFSelect_ReturnStatus status = writer.Write(path);
        return status == IFSelect_RetDone;
    } catch (...) {
        return false;
    }
}

void OCCTDocumentRelease(OCCTDocumentRef doc) {
    if (!doc) return;

    try {
        if (!doc->doc.IsNull()) {
            doc->app->Close(doc->doc);
        }
    } catch (...) {
        // Ignore cleanup errors
    }

    delete doc;
}

// MARK: - XDE Assembly Traversal

int32_t OCCTDocumentGetRootCount(OCCTDocumentRef doc) {
    if (!doc || doc->shapeTool.IsNull()) return 0;

    try {
        TDF_LabelSequence roots;
        doc->shapeTool->GetFreeShapes(roots);
        return static_cast<int32_t>(roots.Length());
    } catch (...) {
        return 0;
    }
}

int64_t OCCTDocumentGetRootLabelId(OCCTDocumentRef doc, int32_t index) {
    if (!doc || doc->shapeTool.IsNull() || index < 0) return -1;

    try {
        TDF_LabelSequence roots;
        doc->shapeTool->GetFreeShapes(roots);

        if (index >= roots.Length()) return -1;

        TDF_Label label = roots.Value(index + 1);  // OCCT is 1-based
        return doc->registerLabel(label);
    } catch (...) {
        return -1;
    }
}

const char* OCCTDocumentGetLabelName(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc) return nullptr;

    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return nullptr;

        Handle(TDataStd_Name) nameAttr;
        if (label.FindAttribute(TDataStd_Name::GetID(), nameAttr)) {
            TCollection_ExtendedString name = nameAttr->Get();
            TCollection_AsciiString asciiName(name);

            // Allocate and copy the string (caller must free with OCCTStringFree)
            char* result = new char[asciiName.Length() + 1];
            std::strcpy(result, asciiName.ToCString());
            return result;
        }

        return nullptr;
    } catch (...) {
        return nullptr;
    }
}

bool OCCTDocumentIsAssembly(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->shapeTool.IsNull()) return false;

    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;

        return doc->shapeTool->IsAssembly(label);
    } catch (...) {
        return false;
    }
}

bool OCCTDocumentIsReference(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->shapeTool.IsNull()) return false;

    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;

        return doc->shapeTool->IsReference(label);
    } catch (...) {
        return false;
    }
}

int32_t OCCTDocumentGetChildCount(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->shapeTool.IsNull()) return 0;

    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return 0;

        TDF_LabelSequence components;
        doc->shapeTool->GetComponents(label, components);
        return static_cast<int32_t>(components.Length());
    } catch (...) {
        return 0;
    }
}

int64_t OCCTDocumentGetChildLabelId(OCCTDocumentRef doc, int64_t parentLabelId, int32_t index) {
    if (!doc || doc->shapeTool.IsNull() || index < 0) return -1;

    try {
        TDF_Label parentLabel = doc->getLabel(parentLabelId);
        if (parentLabel.IsNull()) return -1;

        TDF_LabelSequence components;
        doc->shapeTool->GetComponents(parentLabel, components);

        if (index >= components.Length()) return -1;

        TDF_Label childLabel = components.Value(index + 1);  // OCCT is 1-based
        return doc->registerLabel(childLabel);
    } catch (...) {
        return -1;
    }
}

int64_t OCCTDocumentGetReferredLabelId(OCCTDocumentRef doc, int64_t refLabelId) {
    if (!doc || doc->shapeTool.IsNull()) return -1;

    try {
        TDF_Label refLabel = doc->getLabel(refLabelId);
        if (refLabel.IsNull()) return -1;

        TDF_Label referredLabel;
        if (!doc->shapeTool->GetReferredShape(refLabel, referredLabel)) {
            return -1;
        }

        return doc->registerLabel(referredLabel);
    } catch (...) {
        return -1;
    }
}

OCCTShapeRef OCCTDocumentGetShape(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->shapeTool.IsNull()) return nullptr;

    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return nullptr;

        TopoDS_Shape shape = doc->shapeTool->GetShape(label);
        if (shape.IsNull()) return nullptr;

        return new OCCTShape(shape);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTDocumentGetShapeWithLocation(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->shapeTool.IsNull()) return nullptr;

    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return nullptr;

        // Get shape with accumulated location
        TopoDS_Shape shape;

        // If it's a reference, get the referred shape with location
        if (doc->shapeTool->IsReference(label)) {
            TDF_Label referredLabel;
            if (doc->shapeTool->GetReferredShape(label, referredLabel)) {
                shape = doc->shapeTool->GetShape(referredLabel);
                // Apply location from reference
                TopLoc_Location loc = doc->shapeTool->GetLocation(label);
                shape.Location(loc);
            }
        } else {
            shape = doc->shapeTool->GetShape(label);
        }

        if (shape.IsNull()) return nullptr;

        return new OCCTShape(shape);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - XDE Transforms

void OCCTDocumentGetLocation(OCCTDocumentRef doc, int64_t labelId, float* outMatrix16) {
    if (!doc || !outMatrix16) return;

    // Initialize to identity matrix (column-major)
    for (int i = 0; i < 16; i++) {
        outMatrix16[i] = (i % 5 == 0) ? 1.0f : 0.0f;
    }

    if (doc->shapeTool.IsNull()) return;

    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return;

        TopLoc_Location loc = doc->shapeTool->GetLocation(label);
        if (loc.IsIdentity()) return;

        gp_Trsf trsf = loc.Transformation();

        // Extract rotation/scale part (3x3)
        for (int row = 0; row < 3; row++) {
            for (int col = 0; col < 3; col++) {
                outMatrix16[col * 4 + row] = static_cast<float>(trsf.Value(row + 1, col + 1));
            }
        }

        // Extract translation
        outMatrix16[12] = static_cast<float>(trsf.TranslationPart().X());
        outMatrix16[13] = static_cast<float>(trsf.TranslationPart().Y());
        outMatrix16[14] = static_cast<float>(trsf.TranslationPart().Z());
        outMatrix16[15] = 1.0f;
    } catch (...) {
        // Keep identity matrix on error
    }
}

// MARK: - XDE Colors

OCCTColor OCCTDocumentGetLabelColor(OCCTDocumentRef doc, int64_t labelId, OCCTColorType colorType) {
    OCCTColor result = {0, 0, 0, 1.0, false};

    if (!doc || doc->colorTool.IsNull()) return result;

    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return result;

        Quantity_ColorRGBA color;
        XCAFDoc_ColorType xcafType;

        switch (colorType) {
            case OCCTColorTypeSurface:
                xcafType = XCAFDoc_ColorSurf;
                break;
            case OCCTColorTypeCurve:
                xcafType = XCAFDoc_ColorCurv;
                break;
            default:
                xcafType = XCAFDoc_ColorGen;
                break;
        }

        // Try to get color from this label
        if (doc->colorTool->GetColor(label, xcafType, color)) {
            result.r = color.GetRGB().Red();
            result.g = color.GetRGB().Green();
            result.b = color.GetRGB().Blue();
            result.a = color.Alpha();
            result.isSet = true;
            return result;
        }

        // If this is a reference, try to get color from referred shape
        if (doc->shapeTool->IsReference(label)) {
            TDF_Label referredLabel;
            if (doc->shapeTool->GetReferredShape(label, referredLabel)) {
                if (doc->colorTool->GetColor(referredLabel, xcafType, color)) {
                    result.r = color.GetRGB().Red();
                    result.g = color.GetRGB().Green();
                    result.b = color.GetRGB().Blue();
                    result.a = color.Alpha();
                    result.isSet = true;
                }
            }
        }

        return result;
    } catch (...) {
        return result;
    }
}

void OCCTDocumentSetLabelColor(OCCTDocumentRef doc, int64_t labelId, OCCTColorType colorType, double r, double g, double b) {
    if (!doc || doc->colorTool.IsNull()) return;

    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return;

        Quantity_Color color(r, g, b, Quantity_TOC_RGB);
        XCAFDoc_ColorType xcafType;

        switch (colorType) {
            case OCCTColorTypeSurface:
                xcafType = XCAFDoc_ColorSurf;
                break;
            case OCCTColorTypeCurve:
                xcafType = XCAFDoc_ColorCurv;
                break;
            default:
                xcafType = XCAFDoc_ColorGen;
                break;
        }

        doc->colorTool->SetColor(label, color, xcafType);
    } catch (...) {
        // Ignore errors
    }
}

// MARK: - XDE Materials (PBR)

OCCTMaterial OCCTDocumentGetLabelMaterial(OCCTDocumentRef doc, int64_t labelId) {
    OCCTMaterial result = {{0, 0, 0, 1.0, false}, 0.0, 0.5, {0, 0, 0, 1.0, false}, 0.0, false};

    if (!doc || doc->materialTool.IsNull()) return result;

    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return result;

        // Get shape to find material
        TopoDS_Shape shape = doc->shapeTool->GetShape(label);
        if (shape.IsNull()) {
            // Try from reference
            if (doc->shapeTool->IsReference(label)) {
                TDF_Label referredLabel;
                if (doc->shapeTool->GetReferredShape(label, referredLabel)) {
                    shape = doc->shapeTool->GetShape(referredLabel);
                }
            }
        }

        if (shape.IsNull()) return result;

        // Try to get material from shape
        Handle(XCAFDoc_VisMaterial) visMat = doc->materialTool->GetShapeMaterial(shape);
        if (visMat.IsNull()) return result;

        result.isSet = true;

        // Get PBR properties if available
        if (visMat->HasPbrMaterial()) {
            XCAFDoc_VisMaterialPBR pbr = visMat->PbrMaterial();

            // Base color
            Quantity_ColorRGBA baseColor = pbr.BaseColor;
            result.baseColor.r = baseColor.GetRGB().Red();
            result.baseColor.g = baseColor.GetRGB().Green();
            result.baseColor.b = baseColor.GetRGB().Blue();
            result.baseColor.a = baseColor.Alpha();
            result.baseColor.isSet = true;

            // Metallic and roughness
            result.metallic = pbr.Metallic;
            result.roughness = pbr.Roughness;

            // Emissive (Graphic3d_Vec3)
            result.emissive.r = pbr.EmissiveFactor.x();
            result.emissive.g = pbr.EmissiveFactor.y();
            result.emissive.b = pbr.EmissiveFactor.z();
            result.emissive.a = 1.0;
            result.emissive.isSet = true;
        } else if (visMat->HasCommonMaterial()) {
            // Fall back to common material
            XCAFDoc_VisMaterialCommon common = visMat->CommonMaterial();

            result.baseColor.r = common.DiffuseColor.Red();
            result.baseColor.g = common.DiffuseColor.Green();
            result.baseColor.b = common.DiffuseColor.Blue();
            result.baseColor.a = 1.0 - common.Transparency;
            result.baseColor.isSet = true;

            result.transparency = common.Transparency;

            // Estimate roughness from shininess
            result.roughness = 1.0 - (common.Shininess / 100.0);
        }

        return result;
    } catch (...) {
        return result;
    }
}

void OCCTDocumentSetLabelMaterial(OCCTDocumentRef doc, int64_t labelId, OCCTMaterial material) {
    if (!doc || doc->materialTool.IsNull() || !material.isSet) return;

    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return;

        TopoDS_Shape shape = doc->shapeTool->GetShape(label);
        if (shape.IsNull()) return;

        // Create new material
        Handle(XCAFDoc_VisMaterial) visMat = new XCAFDoc_VisMaterial();

        // Set PBR properties
        XCAFDoc_VisMaterialPBR pbr;
        pbr.BaseColor = Quantity_ColorRGBA(
            Quantity_Color(material.baseColor.r, material.baseColor.g, material.baseColor.b, Quantity_TOC_RGB),
            static_cast<float>(material.baseColor.a)
        );
        pbr.Metallic = static_cast<Standard_ShortReal>(material.metallic);
        pbr.Roughness = static_cast<Standard_ShortReal>(material.roughness);
        pbr.EmissiveFactor = Graphic3d_Vec3(
            static_cast<float>(material.emissive.r),
            static_cast<float>(material.emissive.g),
            static_cast<float>(material.emissive.b)
        );

        visMat->SetPbrMaterial(pbr);

        // Add material and bind to shape
        TDF_Label matLabel = doc->materialTool->AddMaterial(visMat, TCollection_AsciiString("Material"));
        doc->materialTool->SetShapeMaterial(shape, matLabel);
    } catch (...) {
        // Ignore errors
    }
}

// MARK: - XDE Utility

void OCCTStringFree(const char* str) {
    delete[] str;
}

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

// MARK: - Surfaces & Curves (v0.9.0)

OCCTCurveInfo OCCTWireGetCurveInfo(OCCTWireRef wire) {
    OCCTCurveInfo result = {};
    result.isValid = false;
    if (!wire) return result;

    try {
        BRepAdaptor_CompCurve curve(wire->wire);

        // Get length
        result.length = GCPnts_AbscissaPoint::Length(curve);

        // Get closed/periodic status
        result.isClosed = curve.IsClosed();
        result.isPeriodic = curve.IsPeriodic();

        // Get start point
        Standard_Real first = curve.FirstParameter();
        Standard_Real last = curve.LastParameter();
        gp_Pnt startPt = curve.Value(first);
        gp_Pnt endPt = curve.Value(last);

        result.startX = startPt.X();
        result.startY = startPt.Y();
        result.startZ = startPt.Z();
        result.endX = endPt.X();
        result.endY = endPt.Y();
        result.endZ = endPt.Z();

        result.isValid = true;
        return result;
    } catch (...) {
        return result;
    }
}

double OCCTWireGetLength(OCCTWireRef wire) {
    if (!wire) return -1.0;

    try {
        BRepAdaptor_CompCurve curve(wire->wire);
        return GCPnts_AbscissaPoint::Length(curve);
    } catch (...) {
        return -1.0;
    }
}

bool OCCTWireGetPointAt(OCCTWireRef wire, double param, double* x, double* y, double* z) {
    if (!wire || !x || !y || !z) return false;

    try {
        BRepAdaptor_CompCurve curve(wire->wire);
        Standard_Real first = curve.FirstParameter();
        Standard_Real last = curve.LastParameter();

        // Map normalized parameter [0,1] to actual parameter range
        Standard_Real actualParam = first + param * (last - first);

        gp_Pnt pt = curve.Value(actualParam);
        *x = pt.X();
        *y = pt.Y();
        *z = pt.Z();
        return true;
    } catch (...) {
        return false;
    }
}

bool OCCTWireGetTangentAt(OCCTWireRef wire, double param, double* tx, double* ty, double* tz) {
    if (!wire || !tx || !ty || !tz) return false;

    try {
        BRepAdaptor_CompCurve curve(wire->wire);
        Standard_Real first = curve.FirstParameter();
        Standard_Real last = curve.LastParameter();

        // Map normalized parameter [0,1] to actual parameter range
        Standard_Real actualParam = first + param * (last - first);

        gp_Pnt pt;
        gp_Vec tangent;
        curve.D1(actualParam, pt, tangent);

        // Normalize the tangent
        if (tangent.Magnitude() > 1e-10) {
            tangent.Normalize();
        }

        *tx = tangent.X();
        *ty = tangent.Y();
        *tz = tangent.Z();
        return true;
    } catch (...) {
        return false;
    }
}

double OCCTWireGetCurvatureAt(OCCTWireRef wire, double param) {
    if (!wire) return -1.0;

    try {
        BRepAdaptor_CompCurve curve(wire->wire);
        Standard_Real first = curve.FirstParameter();
        Standard_Real last = curve.LastParameter();

        // Map normalized parameter [0,1] to actual parameter range
        Standard_Real actualParam = first + param * (last - first);

        // Get first and second derivatives
        gp_Pnt pt;
        gp_Vec d1, d2;
        curve.D2(actualParam, pt, d1, d2);

        // Curvature formula: κ = |d1 × d2| / |d1|³
        gp_Vec cross = d1.Crossed(d2);
        double d1Mag = d1.Magnitude();
        if (d1Mag < 1e-10) return 0.0;

        return cross.Magnitude() / (d1Mag * d1Mag * d1Mag);
    } catch (...) {
        return -1.0;
    }
}

OCCTCurvePoint OCCTWireGetCurvePointAt(OCCTWireRef wire, double param) {
    OCCTCurvePoint result = {};
    result.isValid = false;
    result.hasNormal = false;
    if (!wire) return result;

    try {
        BRepAdaptor_CompCurve curve(wire->wire);
        Standard_Real first = curve.FirstParameter();
        Standard_Real last = curve.LastParameter();

        // Map normalized parameter [0,1] to actual parameter range
        Standard_Real actualParam = first + param * (last - first);

        // Get position and derivatives
        gp_Pnt pt;
        gp_Vec d1, d2;
        curve.D2(actualParam, pt, d1, d2);

        result.posX = pt.X();
        result.posY = pt.Y();
        result.posZ = pt.Z();

        // Normalize tangent (d1)
        double d1Mag = d1.Magnitude();
        if (d1Mag > 1e-10) {
            gp_Vec tangent = d1.Divided(d1Mag);
            result.tanX = tangent.X();
            result.tanY = tangent.Y();
            result.tanZ = tangent.Z();

            // Compute curvature: κ = |d1 × d2| / |d1|³
            gp_Vec cross = d1.Crossed(d2);
            result.curvature = cross.Magnitude() / (d1Mag * d1Mag * d1Mag);

            // Compute principal normal if curvature is non-zero
            // Normal = (d1 × d2) × d1, normalized, pointing toward center of curvature
            if (result.curvature > 1e-10) {
                // Principal normal is perpendicular to tangent, in the osculating plane
                // N = (T' - (T' · T)T) / |T' - (T' · T)T|
                // For arc-length parameterization, T' is already perpendicular to T
                // For general parameterization, we use: N = d2 - (d2 · T)T, normalized
                gp_Vec T(result.tanX, result.tanY, result.tanZ);
                double d2DotT = d2.Dot(T);
                gp_Vec normalDir = d2 - T.Multiplied(d2DotT);
                double normalMag = normalDir.Magnitude();
                if (normalMag > 1e-10) {
                    normalDir.Divide(normalMag);
                    result.normX = normalDir.X();
                    result.normY = normalDir.Y();
                    result.normZ = normalDir.Z();
                    result.hasNormal = true;
                }
            }
        } else {
            result.tanX = result.tanY = result.tanZ = 0.0;
            result.curvature = 0.0;
        }

        result.isValid = true;
        return result;
    } catch (...) {
        return result;
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


// MARK: - IGES Import/Export (v0.10.0)

OCCTShapeRef OCCTImportIGES(const char* path) {
    if (!path) return nullptr;

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

    try {
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

// MARK: - Shape Healing & Analysis (v0.13.0)

OCCTShapeAnalysisResult OCCTShapeAnalyze(OCCTShapeRef shape, double tolerance) {
    OCCTShapeAnalysisResult result = {0, 0, 0, 0, 0, 0, false, false};
    if (!shape) return result;

    try {
        // Use BRepCheck_Analyzer for comprehensive validation
        BRepCheck_Analyzer analyzer(shape->shape, true);
        result.hasInvalidTopology = !analyzer.IsValid();

        // Count small edges using ShapeAnalysis_ShapeTolerance
        ShapeAnalysis_ShapeTolerance shapeTol;

        // Count free edges and faces (topology analysis)
        int freeEdges = 0;
        int freeFaces = 0;
        int smallEdges = 0;
        int smallFaces = 0;
        int gaps = 0;

        // Analyze shells for free faces and closure
        for (TopExp_Explorer shellExp(shape->shape, TopAbs_SHELL); shellExp.More(); shellExp.Next()) {
            TopoDS_Shell shell = TopoDS::Shell(shellExp.Current());
            ShapeAnalysis_Shell shellAnalysis;
            shellAnalysis.LoadShells(shell);

            // Check for free faces
            if (shellAnalysis.HasFreeEdges()) {
                // Count free edges in shell
                TopoDS_Compound freeEdgesCompound = shellAnalysis.FreeEdges();
                for (TopExp_Explorer edgeExp(freeEdgesCompound, TopAbs_EDGE); edgeExp.More(); edgeExp.Next()) {
                    freeEdges++;
                }
            }
        }

        // Analyze edges for small size
        for (TopExp_Explorer edgeExp(shape->shape, TopAbs_EDGE); edgeExp.More(); edgeExp.Next()) {
            TopoDS_Edge edge = TopoDS::Edge(edgeExp.Current());

            // Get edge length
            GProp_GProps props;
            BRepGProp::LinearProperties(edge, props);
            double length = props.Mass();

            if (length < tolerance) {
                smallEdges++;
            }
        }

        // Analyze faces for small size
        for (TopExp_Explorer faceExp(shape->shape, TopAbs_FACE); faceExp.More(); faceExp.Next()) {
            TopoDS_Face face = TopoDS::Face(faceExp.Current());

            // Get face area
            GProp_GProps props;
            BRepGProp::SurfaceProperties(face, props);
            double area = props.Mass();

            if (area < tolerance * tolerance) {
                smallFaces++;
            }
        }

        // Analyze wires for gaps
        for (TopExp_Explorer wireExp(shape->shape, TopAbs_WIRE); wireExp.More(); wireExp.Next()) {
            TopoDS_Wire wire = TopoDS::Wire(wireExp.Current());

            // Find a face containing this wire for context
            TopoDS_Face face;
            for (TopExp_Explorer faceExp(shape->shape, TopAbs_FACE); faceExp.More(); faceExp.Next()) {
                TopoDS_Face testFace = TopoDS::Face(faceExp.Current());
                for (TopExp_Explorer innerWireExp(testFace, TopAbs_WIRE); innerWireExp.More(); innerWireExp.Next()) {
                    if (innerWireExp.Current().IsSame(wire)) {
                        face = testFace;
                        break;
                    }
                }
                if (!face.IsNull()) break;
            }

            if (!face.IsNull()) {
                ShapeAnalysis_Wire wireAnalysis(wire, face, tolerance);
                gaps += wireAnalysis.CheckGaps3d();
            }
        }

        result.smallEdgeCount = smallEdges;
        result.smallFaceCount = smallFaces;
        result.gapCount = gaps;
        result.selfIntersectionCount = 0;  // Would require more expensive computation
        result.freeEdgeCount = freeEdges;
        result.freeFaceCount = freeFaces;
        result.isValid = true;

        return result;
    } catch (...) {
        return result;
    }
}

OCCTWireRef OCCTWireFix(OCCTWireRef wire, double tolerance) {
    if (!wire) return nullptr;

    try {
        // Create a planar face for wire fixing context
        BRepBuilderAPI_MakeFace makeFace(wire->wire, true);
        if (!makeFace.IsDone()) {
            // Try without planar check
            makeFace = BRepBuilderAPI_MakeFace(wire->wire, false);
            if (!makeFace.IsDone()) return nullptr;
        }
        TopoDS_Face face = makeFace.Face();

        // Fix the wire
        Handle(ShapeFix_Wire) fixer = new ShapeFix_Wire(wire->wire, face, tolerance);
        fixer->SetPrecision(tolerance);

        // Enable all fixing modes
        fixer->FixReorderMode() = 1;
        fixer->FixConnectedMode() = 1;
        fixer->FixEdgeCurvesMode() = 1;
        fixer->FixDegeneratedMode() = 1;
        fixer->FixSelfIntersectionMode() = 1;
        fixer->FixLackingMode() = 1;
        fixer->FixGaps3dMode() = 1;

        if (!fixer->Perform()) {
            // Fixing failed, return original
            return new OCCTWire(wire->wire);
        }

        TopoDS_Wire fixedWire = fixer->Wire();
        if (fixedWire.IsNull()) return nullptr;

        return new OCCTWire(fixedWire);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTFaceFix(OCCTFaceRef face, double tolerance) {
    if (!face) return nullptr;

    try {
        Handle(ShapeFix_Face) fixer = new ShapeFix_Face(face->face);
        fixer->SetPrecision(tolerance);

        // Enable fixing modes
        fixer->FixWireMode() = 1;
        fixer->FixOrientationMode() = 1;
        fixer->FixAddNaturalBoundMode() = 1;
        fixer->FixMissingSeamMode() = 1;
        fixer->FixSmallAreaWireMode() = 1;

        if (!fixer->Perform()) {
            // Fixing failed, return original
            return new OCCTShape(face->face);
        }

        TopoDS_Face fixedFace = fixer->Face();
        if (fixedFace.IsNull()) return nullptr;

        return new OCCTShape(fixedFace);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeFixDetailed(OCCTShapeRef shape, double tolerance,
                                   bool fixSolid, bool fixShell,
                                   bool fixFace, bool fixWire) {
    if (!shape) return nullptr;

    try {
        Handle(ShapeFix_Shape) fixer = new ShapeFix_Shape(shape->shape);
        fixer->SetPrecision(tolerance);

        // ShapeFix_Shape automatically fixes all sub-shapes
        // The individual mode flags control specific fixing operations
        fixer->FixSolidMode() = fixSolid ? 1 : 0;

        // Perform the fix
        if (!fixer->Perform()) {
            // Fixing might still produce a result even if Perform returns false
        }

        TopoDS_Shape fixedShape = fixer->Shape();
        if (fixedShape.IsNull()) {
            return new OCCTShape(shape->shape);  // Return original if fix failed
        }

        return new OCCTShape(fixedShape);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeUnifySameDomain(OCCTShapeRef shape,
                                       bool unifyEdges, bool unifyFaces,
                                       bool concatBSplines) {
    if (!shape) return nullptr;

    try {
        ShapeUpgrade_UnifySameDomain unifier(shape->shape, unifyEdges, unifyFaces, concatBSplines);
        unifier.Build();

        TopoDS_Shape result = unifier.Shape();
        if (result.IsNull()) return nullptr;

        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeRemoveSmallFaces(OCCTShapeRef shape, double minArea) {
    if (!shape || minArea <= 0) return nullptr;

    try {
        // Collect faces to remove
        TopTools_ListOfShape facesToRemove;

        for (TopExp_Explorer exp(shape->shape, TopAbs_FACE); exp.More(); exp.Next()) {
            TopoDS_Face face = TopoDS::Face(exp.Current());

            GProp_GProps props;
            BRepGProp::SurfaceProperties(face, props);
            double area = props.Mass();

            if (area < minArea) {
                facesToRemove.Append(face);
            }
        }

        if (facesToRemove.IsEmpty()) {
            // No faces to remove
            return new OCCTShape(shape->shape);
        }

        // Use defeaturing to remove small faces
        BRepAlgoAPI_Defeaturing defeaturer;
        defeaturer.SetShape(shape->shape);
        defeaturer.AddFacesToRemove(facesToRemove);
        defeaturer.Build();

        if (!defeaturer.IsDone()) {
            return nullptr;
        }

        TopoDS_Shape result = defeaturer.Shape();
        if (result.IsNull()) return nullptr;

        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeSimplify(OCCTShapeRef shape, double tolerance) {
    if (!shape) return nullptr;

    try {
        // First unify same domain
        ShapeUpgrade_UnifySameDomain unifier(shape->shape, true, true, true);
        unifier.Build();
        TopoDS_Shape unified = unifier.Shape();

        // Then heal the shape
        Handle(ShapeFix_Shape) fixer = new ShapeFix_Shape(unified);
        fixer->SetPrecision(tolerance);
        fixer->Perform();
        TopoDS_Shape result = fixer->Shape();

        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Advanced Blends & Surface Filling (v0.14.0)

OCCTShapeRef OCCTShapeFilletVariable(OCCTShapeRef shape, int32_t edgeIndex,
                                      const double* radii, const double* params, int32_t count) {
    if (!shape || !radii || !params || count < 2 || edgeIndex < 0) return nullptr;

    try {
        // Get the edge at the specified index
        TopTools_IndexedMapOfShape edgeMap;
        TopExp::MapShapes(shape->shape, TopAbs_EDGE, edgeMap);

        if (edgeIndex >= edgeMap.Extent()) return nullptr;

        TopoDS_Edge edge = TopoDS::Edge(edgeMap(edgeIndex + 1));  // OCCT uses 1-based indexing

        // Create fillet maker
        BRepFilletAPI_MakeFillet fillet(shape->shape);

        // Add edge with variable radius
        fillet.Add(edge);

        // Get the edge length for parameter mapping
        double first, last;
        Handle(Geom_Curve) curve = BRep_Tool::Curve(edge, first, last);
        if (curve.IsNull()) return nullptr;

        // Set radius at each parameter point
        for (int32_t i = 0; i < count; i++) {
            double param = first + params[i] * (last - first);  // Map 0-1 to curve parameter range
            fillet.SetRadius(radii[i], param, 1);  // 1 is the contour index
        }

        fillet.Build();
        if (!fillet.IsDone()) return nullptr;

        TopoDS_Shape result = fillet.Shape();
        if (result.IsNull()) return nullptr;

        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTWireRef OCCTWireFillet2D(OCCTWireRef wire, int32_t vertexIndex, double radius) {
    if (!wire || radius <= 0 || vertexIndex < 0) return nullptr;

    try {
        // Create a face from the wire for 2D operations
        BRepBuilderAPI_MakeFace makeFace(wire->wire, true);
        if (!makeFace.IsDone()) return nullptr;
        TopoDS_Face face = makeFace.Face();

        // Get vertex at index
        TopTools_IndexedMapOfShape vertexMap;
        TopExp::MapShapes(wire->wire, TopAbs_VERTEX, vertexMap);

        if (vertexIndex >= vertexMap.Extent()) return nullptr;

        TopoDS_Vertex vertex = TopoDS::Vertex(vertexMap(vertexIndex + 1));

        // Use ChFi2d_Builder for 2D fillet on face
        ChFi2d_Builder fillet2d(face);
        TopoDS_Edge filletEdge = fillet2d.AddFillet(vertex, radius);

        if (filletEdge.IsNull()) return nullptr;
        if (fillet2d.Status() != ChFi2d_IsDone) return nullptr;

        // Get the modified face and extract its outer wire
        TopoDS_Face resultFace = TopoDS::Face(fillet2d.Result());
        if (resultFace.IsNull()) return nullptr;

        TopoDS_Wire outerWire = BRepTools::OuterWire(resultFace);
        if (outerWire.IsNull()) return nullptr;

        return new OCCTWire(outerWire);
    } catch (...) {
        return nullptr;
    }
}

OCCTWireRef OCCTWireFilletAll2D(OCCTWireRef wire, double radius) {
    if (!wire || radius <= 0) return nullptr;

    try {
        // Create a face from the wire
        BRepBuilderAPI_MakeFace makeFace(wire->wire, true);
        if (!makeFace.IsDone()) return nullptr;
        TopoDS_Face face = makeFace.Face();

        // Get all vertices
        TopTools_IndexedMapOfShape vertexMap;
        TopExp::MapShapes(wire->wire, TopAbs_VERTEX, vertexMap);

        if (vertexMap.Extent() < 2) return nullptr;

        // Use ChFi2d_Builder to fillet all vertices
        ChFi2d_Builder fillet2d(face);

        // Add fillet to each vertex
        for (int v = 1; v <= vertexMap.Extent(); v++) {
            TopoDS_Vertex vertex = TopoDS::Vertex(vertexMap(v));
            fillet2d.AddFillet(vertex, radius);
        }

        if (fillet2d.Status() != ChFi2d_IsDone) {
            // Some vertices might not be fillettable; return original
            return new OCCTWire(wire->wire);
        }

        // Get the modified face and extract its outer wire
        TopoDS_Face resultFace = TopoDS::Face(fillet2d.Result());
        if (resultFace.IsNull()) return nullptr;

        TopoDS_Wire outerWire = BRepTools::OuterWire(resultFace);
        if (outerWire.IsNull()) return nullptr;

        return new OCCTWire(outerWire);
    } catch (...) {
        return nullptr;
    }
}

OCCTWireRef OCCTWireChamfer2D(OCCTWireRef wire, int32_t vertexIndex, double dist1, double dist2) {
    if (!wire || dist1 <= 0 || dist2 <= 0 || vertexIndex < 0) return nullptr;

    try {
        // Create face from wire
        BRepBuilderAPI_MakeFace makeFace(wire->wire, true);
        if (!makeFace.IsDone()) return nullptr;
        TopoDS_Face face = makeFace.Face();

        // Get edges and vertices
        TopTools_IndexedMapOfShape edgeMap;
        TopExp::MapShapes(wire->wire, TopAbs_EDGE, edgeMap);

        TopTools_IndexedMapOfShape vertexMap;
        TopExp::MapShapes(wire->wire, TopAbs_VERTEX, vertexMap);

        if (vertexIndex >= vertexMap.Extent()) return nullptr;

        TopoDS_Vertex vertex = TopoDS::Vertex(vertexMap(vertexIndex + 1));

        // Find edges sharing this vertex
        TopoDS_Edge edge1, edge2;
        for (int i = 1; i <= edgeMap.Extent(); i++) {
            TopoDS_Edge edge = TopoDS::Edge(edgeMap(i));
            TopoDS_Vertex v1, v2;
            TopExp::Vertices(edge, v1, v2);
            if (v1.IsSame(vertex) || v2.IsSame(vertex)) {
                if (edge1.IsNull()) {
                    edge1 = edge;
                } else {
                    edge2 = edge;
                    break;
                }
            }
        }

        if (edge1.IsNull() || edge2.IsNull()) return nullptr;

        // Use ChFi2d_Builder for 2D chamfer
        ChFi2d_Builder chamfer2d(face);
        TopoDS_Edge chamferEdge = chamfer2d.AddChamfer(edge1, edge2, dist1, dist2);

        if (chamferEdge.IsNull()) return nullptr;
        if (chamfer2d.Status() != ChFi2d_IsDone) return nullptr;

        // Get the modified face and extract its outer wire
        TopoDS_Face resultFace = TopoDS::Face(chamfer2d.Result());
        if (resultFace.IsNull()) return nullptr;

        TopoDS_Wire outerWire = BRepTools::OuterWire(resultFace);
        if (outerWire.IsNull()) return nullptr;

        return new OCCTWire(outerWire);
    } catch (...) {
        return nullptr;
    }
}

OCCTWireRef OCCTWireChamferAll2D(OCCTWireRef wire, double distance) {
    if (!wire || distance <= 0) return nullptr;

    try {
        // Create face from wire
        BRepBuilderAPI_MakeFace makeFace(wire->wire, true);
        if (!makeFace.IsDone()) return nullptr;
        TopoDS_Face face = makeFace.Face();

        // Get edges and vertices
        TopTools_IndexedMapOfShape edgeMap;
        TopExp::MapShapes(wire->wire, TopAbs_EDGE, edgeMap);

        if (edgeMap.Extent() < 2) return nullptr;

        // Use ChFi2d_Builder for 2D chamfers
        ChFi2d_Builder chamfer2d(face);

        // For each pair of adjacent edges, add chamfer
        // We need to find adjacent edge pairs
        for (int i = 1; i <= edgeMap.Extent(); i++) {
            TopoDS_Edge edge1 = TopoDS::Edge(edgeMap(i));
            int nextIdx = (i % edgeMap.Extent()) + 1;
            TopoDS_Edge edge2 = TopoDS::Edge(edgeMap(nextIdx));

            // Check if edges share a vertex
            TopoDS_Vertex v1_1, v1_2, v2_1, v2_2;
            TopExp::Vertices(edge1, v1_1, v1_2);
            TopExp::Vertices(edge2, v2_1, v2_2);

            bool sharesVertex = v1_1.IsSame(v2_1) || v1_1.IsSame(v2_2) ||
                               v1_2.IsSame(v2_1) || v1_2.IsSame(v2_2);

            if (sharesVertex) {
                chamfer2d.AddChamfer(edge1, edge2, distance, distance);
            }
        }

        if (chamfer2d.Status() != ChFi2d_IsDone) {
            // Some edges might not be chamferable; return original
            return new OCCTWire(wire->wire);
        }

        // Get the modified face and extract its outer wire
        TopoDS_Face resultFace = TopoDS::Face(chamfer2d.Result());
        if (resultFace.IsNull()) return nullptr;

        TopoDS_Wire outerWire = BRepTools::OuterWire(resultFace);
        if (outerWire.IsNull()) return nullptr;

        return new OCCTWire(outerWire);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeBlendEdges(OCCTShapeRef shape,
                                  const int32_t* edgeIndices, const double* radii, int32_t count) {
    if (!shape || !edgeIndices || !radii || count < 1) return nullptr;

    try {
        // Get all edges from shape
        TopTools_IndexedMapOfShape edgeMap;
        TopExp::MapShapes(shape->shape, TopAbs_EDGE, edgeMap);

        // Create fillet maker
        BRepFilletAPI_MakeFillet fillet(shape->shape);

        // Add each edge with its radius
        for (int32_t i = 0; i < count; i++) {
            int32_t idx = edgeIndices[i];
            if (idx < 0 || idx >= edgeMap.Extent()) continue;

            TopoDS_Edge edge = TopoDS::Edge(edgeMap(idx + 1));
            fillet.Add(radii[i], edge);
        }

        fillet.Build();
        if (!fillet.IsDone()) return nullptr;

        TopoDS_Shape result = fillet.Shape();
        if (result.IsNull()) return nullptr;

        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeFill(const OCCTWireRef* boundaries, int32_t wireCount,
                            OCCTFillingParams params) {
    if (!boundaries || wireCount < 1) return nullptr;

    try {
        // Create filling operation
        BRepOffsetAPI_MakeFilling filling(
            params.maxDegree > 0 ? params.maxDegree : 8,
            params.maxSegments > 0 ? params.maxSegments : 9,
            1,  // Number of iterations
            false,  // Anisotropie
            params.tolerance > 0 ? params.tolerance : 1e-4,
            params.tolerance > 0 ? params.tolerance : 1e-3,
            static_cast<GeomAbs_Shape>(params.continuity)  // Continuity
        );

        // Add boundary constraints
        for (int32_t i = 0; i < wireCount; i++) {
            if (!boundaries[i]) continue;

            // Add each edge from the wire as a constraint
            for (TopExp_Explorer exp(boundaries[i]->wire, TopAbs_EDGE); exp.More(); exp.Next()) {
                TopoDS_Edge edge = TopoDS::Edge(exp.Current());
                filling.Add(edge, static_cast<GeomAbs_Shape>(params.continuity));
            }
        }

        filling.Build();
        if (!filling.IsDone()) return nullptr;

        TopoDS_Shape result = filling.Shape();
        if (result.IsNull()) return nullptr;

        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapePlatePoints(const double* points, int32_t pointCount, double tolerance) {
    if (!points || pointCount < 3 || tolerance <= 0) return nullptr;

    try {
        // Create plate surface builder
        GeomPlate_BuildPlateSurface plateBuilder(3, 15, 2);  // degree, nbPtsOnCur, nbIter

        // Add point constraints
        for (int32_t i = 0; i < pointCount; i++) {
            gp_Pnt pt(points[i*3], points[i*3+1], points[i*3+2]);
            Handle(GeomPlate_PointConstraint) constraint =
                new GeomPlate_PointConstraint(pt, 0);  // 0 = order (just pass through)
            plateBuilder.Add(constraint);
        }

        // Perform the computation
        plateBuilder.Perform();
        if (!plateBuilder.IsDone()) return nullptr;

        // Get the plate surface
        Handle(GeomPlate_Surface) plateSurface = plateBuilder.Surface();
        if (plateSurface.IsNull()) return nullptr;

        // Approximate with B-spline surface
        GeomPlate_MakeApprox approx(plateSurface, tolerance, 1, 8, tolerance * 10, 0);
        Handle(Geom_BSplineSurface) bsplineSurf = approx.Surface();
        if (bsplineSurf.IsNull()) return nullptr;

        // Create face from surface
        BRepBuilderAPI_MakeFace makeFace(bsplineSurf, tolerance);
        if (!makeFace.IsDone()) return nullptr;

        return new OCCTShape(makeFace.Face());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapePlateCurves(const OCCTWireRef* curves, int32_t curveCount,
                                   int32_t continuity, double tolerance) {
    if (!curves || curveCount < 1 || tolerance <= 0) return nullptr;

    try {
        // Create plate surface builder
        GeomPlate_BuildPlateSurface plateBuilder(3, 15, 2);

        // Add curve constraints from each wire
        for (int32_t i = 0; i < curveCount; i++) {
            if (!curves[i]) continue;

            for (TopExp_Explorer exp(curves[i]->wire, TopAbs_EDGE); exp.More(); exp.Next()) {
                TopoDS_Edge edge = TopoDS::Edge(exp.Current());

                // Create adaptor for edge
                BRepAdaptor_Curve adaptor(edge);
                Handle(Adaptor3d_Curve) curve = new BRepAdaptor_Curve(adaptor);

                Handle(GeomPlate_CurveConstraint) constraint =
                    new GeomPlate_CurveConstraint(curve, continuity);
                plateBuilder.Add(constraint);
            }
        }

        // Perform computation
        plateBuilder.Perform();
        if (!plateBuilder.IsDone()) return nullptr;

        // Get and approximate surface
        Handle(GeomPlate_Surface) plateSurface = plateBuilder.Surface();
        if (plateSurface.IsNull()) return nullptr;

        GeomPlate_MakeApprox approx(plateSurface, tolerance, 1, 8, tolerance * 10, 0);
        Handle(Geom_BSplineSurface) bsplineSurf = approx.Surface();
        if (bsplineSurf.IsNull()) return nullptr;

        BRepBuilderAPI_MakeFace makeFace(bsplineSurf, tolerance);
        if (!makeFace.IsDone()) return nullptr;

        return new OCCTShape(makeFace.Face());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Camera Implementation

struct OCCTCamera {
    Handle(Graphic3d_Camera) camera;

    OCCTCamera() {
        camera = new Graphic3d_Camera();
        camera->SetZeroToOneDepth(Standard_True);
    }
};

OCCTCameraRef OCCTCameraCreate(void) {
    try {
        return new OCCTCamera();
    } catch (...) {
        return nullptr;
    }
}

void OCCTCameraDestroy(OCCTCameraRef cam) {
    delete cam;
}

void OCCTCameraSetEye(OCCTCameraRef cam, double x, double y, double z) {
    if (!cam) return;
    cam->camera->SetEye(gp_Pnt(x, y, z));
}

void OCCTCameraGetEye(OCCTCameraRef cam, double* x, double* y, double* z) {
    if (!cam || !x || !y || !z) return;
    gp_Pnt eye = cam->camera->Eye();
    *x = eye.X(); *y = eye.Y(); *z = eye.Z();
}

void OCCTCameraSetCenter(OCCTCameraRef cam, double x, double y, double z) {
    if (!cam) return;
    cam->camera->SetCenter(gp_Pnt(x, y, z));
}

void OCCTCameraGetCenter(OCCTCameraRef cam, double* x, double* y, double* z) {
    if (!cam || !x || !y || !z) return;
    gp_Pnt center = cam->camera->Center();
    *x = center.X(); *y = center.Y(); *z = center.Z();
}

void OCCTCameraSetUp(OCCTCameraRef cam, double x, double y, double z) {
    if (!cam) return;
    cam->camera->SetUp(gp_Dir(x, y, z));
}

void OCCTCameraGetUp(OCCTCameraRef cam, double* x, double* y, double* z) {
    if (!cam || !x || !y || !z) return;
    gp_Dir up = cam->camera->Up();
    *x = up.X(); *y = up.Y(); *z = up.Z();
}

void OCCTCameraSetProjectionType(OCCTCameraRef cam, int type) {
    if (!cam) return;
    cam->camera->SetProjectionType(
        type == 1 ? Graphic3d_Camera::Projection_Orthographic
                  : Graphic3d_Camera::Projection_Perspective
    );
}

int OCCTCameraGetProjectionType(OCCTCameraRef cam) {
    if (!cam) return 0;
    return cam->camera->ProjectionType() == Graphic3d_Camera::Projection_Orthographic ? 1 : 0;
}

void OCCTCameraSetFOV(OCCTCameraRef cam, double degrees) {
    if (!cam) return;
    cam->camera->SetFOVy(degrees);
}

double OCCTCameraGetFOV(OCCTCameraRef cam) {
    if (!cam) return 45.0;
    return cam->camera->FOVy();
}

void OCCTCameraSetScale(OCCTCameraRef cam, double scale) {
    if (!cam) return;
    cam->camera->SetScale(scale);
}

double OCCTCameraGetScale(OCCTCameraRef cam) {
    if (!cam) return 1.0;
    return cam->camera->Scale();
}

void OCCTCameraSetZRange(OCCTCameraRef cam, double zNear, double zFar) {
    if (!cam) return;
    cam->camera->SetZRange(zNear, zFar);
}

void OCCTCameraGetZRange(OCCTCameraRef cam, double* zNear, double* zFar) {
    if (!cam || !zNear || !zFar) return;
    *zNear = cam->camera->ZNear();
    *zFar = cam->camera->ZFar();
}

void OCCTCameraSetAspect(OCCTCameraRef cam, double aspect) {
    if (!cam) return;
    cam->camera->SetAspect(aspect);
}

double OCCTCameraGetAspect(OCCTCameraRef cam) {
    if (!cam) return 1.0;
    return cam->camera->Aspect();
}

void OCCTCameraGetProjectionMatrix(OCCTCameraRef cam, float* out16) {
    if (!cam || !out16) return;
    const Graphic3d_Mat4& mat = cam->camera->ProjectionMatrixF();
    for (int i = 0; i < 4; i++)
        for (int j = 0; j < 4; j++)
            out16[j * 4 + i] = mat.GetValue(i, j);
}

void OCCTCameraGetViewMatrix(OCCTCameraRef cam, float* out16) {
    if (!cam || !out16) return;
    const Graphic3d_Mat4& mat = cam->camera->OrientationMatrixF();
    for (int i = 0; i < 4; i++)
        for (int j = 0; j < 4; j++)
            out16[j * 4 + i] = mat.GetValue(i, j);
}

void OCCTCameraProject(OCCTCameraRef cam, double wX, double wY, double wZ,
                       double* sX, double* sY, double* sZ) {
    if (!cam || !sX || !sY || !sZ) return;
    try {
        gp_Pnt projected = cam->camera->Project(gp_Pnt(wX, wY, wZ));
        *sX = projected.X(); *sY = projected.Y(); *sZ = projected.Z();
    } catch (...) {
        *sX = *sY = *sZ = 0;
    }
}

void OCCTCameraUnproject(OCCTCameraRef cam, double sX, double sY, double sZ,
                         double* wX, double* wY, double* wZ) {
    if (!cam || !wX || !wY || !wZ) return;
    try {
        gp_Pnt unprojected = cam->camera->UnProject(gp_Pnt(sX, sY, sZ));
        *wX = unprojected.X(); *wY = unprojected.Y(); *wZ = unprojected.Z();
    } catch (...) {
        *wX = *wY = *wZ = 0;
    }
}

void OCCTCameraFitBBox(OCCTCameraRef cam, double xMin, double yMin, double zMin,
                       double xMax, double yMax, double zMax) {
    if (!cam) return;
    try {
        Bnd_Box bbox;
        bbox.Update(xMin, yMin, zMin, xMax, yMax, zMax);
        cam->camera->FitMinMax(bbox, 0.01, false);
    } catch (...) {}
}

// MARK: - Presentation Mesh Implementation

bool OCCTShapeGetShadedMesh(OCCTShapeRef shape, double deflection, OCCTShadedMeshData* out) {
    if (!shape || !out) return false;

    out->vertices = nullptr;
    out->vertexCount = 0;
    out->indices = nullptr;
    out->triangleCount = 0;

    try {
        BRepMesh_IncrementalMesh mesher(shape->shape, deflection);
        mesher.Perform();

        // First pass: count vertices and triangles
        int32_t totalVerts = 0;
        int32_t totalTris = 0;

        for (TopExp_Explorer faceExp(shape->shape, TopAbs_FACE); faceExp.More(); faceExp.Next()) {
            TopoDS_Face face = TopoDS::Face(faceExp.Current());
            TopLoc_Location loc;
            Handle(Poly_Triangulation) tri = BRep_Tool::Triangulation(face, loc);
            if (tri.IsNull()) continue;
            totalVerts += tri->NbNodes();
            totalTris += tri->NbTriangles();
        }

        if (totalVerts == 0 || totalTris == 0) return false;

        // Allocate buffers: interleaved position + normal (6 floats per vertex)
        out->vertices = (float*)malloc(totalVerts * 6 * sizeof(float));
        out->indices = (int32_t*)malloc(totalTris * 3 * sizeof(int32_t));
        if (!out->vertices || !out->indices) {
            free(out->vertices); free(out->indices);
            out->vertices = nullptr; out->indices = nullptr;
            return false;
        }

        int32_t vertexOffset = 0;
        int32_t triOffset = 0;

        for (TopExp_Explorer faceExp(shape->shape, TopAbs_FACE); faceExp.More(); faceExp.Next()) {
            TopoDS_Face face = TopoDS::Face(faceExp.Current());
            TopLoc_Location loc;
            Handle(Poly_Triangulation) tri = BRep_Tool::Triangulation(face, loc);
            if (tri.IsNull()) continue;

            gp_Trsf transform;
            if (!loc.IsIdentity()) {
                transform = loc.Transformation();
            }

            bool reversed = (face.Orientation() == TopAbs_REVERSED);
            bool hasNormals = tri->HasNormals();

            // Write vertex positions and normals
            for (int i = 1; i <= tri->NbNodes(); i++) {
                gp_Pnt node = tri->Node(i);
                if (!loc.IsIdentity()) node.Transform(transform);

                float* vPtr = out->vertices + (vertexOffset + i - 1) * 6;
                vPtr[0] = (float)node.X();
                vPtr[1] = (float)node.Y();
                vPtr[2] = (float)node.Z();

                if (hasNormals) {
                    gp_Dir normal = tri->Normal(i);
                    if (!loc.IsIdentity()) normal.Transform(transform);
                    if (reversed) normal.Reverse();
                    vPtr[3] = (float)normal.X();
                    vPtr[4] = (float)normal.Y();
                    vPtr[5] = (float)normal.Z();
                } else {
                    vPtr[3] = 0; vPtr[4] = 0; vPtr[5] = 0;
                }
            }

            // Compute normals from triangles if not available
            if (!hasNormals) {
                for (int i = 1; i <= tri->NbTriangles(); i++) {
                    int n1, n2, n3;
                    tri->Triangle(i).Get(n1, n2, n3);
                    if (reversed) std::swap(n2, n3);

                    gp_Pnt p1 = tri->Node(n1), p2 = tri->Node(n2), p3 = tri->Node(n3);
                    if (!loc.IsIdentity()) {
                        p1.Transform(transform); p2.Transform(transform); p3.Transform(transform);
                    }

                    gp_Vec v1(p1, p2), v2(p1, p3);
                    gp_Vec fn = v1.Crossed(v2);
                    double mag = fn.Magnitude();
                    if (mag > 1e-10) {
                        fn.Divide(mag);
                        for (int idx : {n1, n2, n3}) {
                            float* nPtr = out->vertices + (vertexOffset + idx - 1) * 6 + 3;
                            nPtr[0] += (float)fn.X();
                            nPtr[1] += (float)fn.Y();
                            nPtr[2] += (float)fn.Z();
                        }
                    }
                }
                // Normalize accumulated normals
                for (int i = 0; i < tri->NbNodes(); i++) {
                    float* nPtr = out->vertices + (vertexOffset + i) * 6 + 3;
                    float len = sqrtf(nPtr[0]*nPtr[0] + nPtr[1]*nPtr[1] + nPtr[2]*nPtr[2]);
                    if (len > 1e-6f) {
                        nPtr[0] /= len; nPtr[1] /= len; nPtr[2] /= len;
                    }
                }
            }

            // Triangle indices
            for (int i = 1; i <= tri->NbTriangles(); i++) {
                int n1, n2, n3;
                tri->Triangle(i).Get(n1, n2, n3);
                if (reversed) std::swap(n2, n3);

                int32_t* tPtr = out->indices + triOffset * 3;
                tPtr[0] = vertexOffset + n1 - 1;
                tPtr[1] = vertexOffset + n2 - 1;
                tPtr[2] = vertexOffset + n3 - 1;
                triOffset++;
            }

            vertexOffset += tri->NbNodes();
        }

        out->vertexCount = totalVerts;
        out->triangleCount = totalTris;
        return true;
    } catch (...) {
        free(out->vertices); free(out->indices);
        out->vertices = nullptr; out->indices = nullptr;
        out->vertexCount = 0; out->triangleCount = 0;
        return false;
    }
}

void OCCTShadedMeshDataFree(OCCTShadedMeshData* data) {
    if (!data) return;
    free(data->vertices);
    free(data->indices);
    data->vertices = nullptr;
    data->indices = nullptr;
    data->vertexCount = 0;
    data->triangleCount = 0;
}

bool OCCTShapeGetEdgeMesh(OCCTShapeRef shape, double deflection, OCCTEdgeMeshData* out) {
    if (!shape || !out) return false;

    out->vertices = nullptr;
    out->vertexCount = 0;
    out->segmentStarts = nullptr;
    out->segmentCount = 0;

    try {
        BRepMesh_IncrementalMesh mesher(shape->shape, deflection);
        mesher.Perform();

        std::vector<float> allVerts;
        std::vector<int32_t> segStarts;

        // Use indexed map to get unique edges (TopExp_Explorer visits each edge
        // once per adjacent face, causing duplicates)
        TopTools_IndexedMapOfShape edgeMap;
        TopExp::MapShapes(shape->shape, TopAbs_EDGE, edgeMap);

        for (int ei = 1; ei <= edgeMap.Extent(); ei++) {
            TopoDS_Edge edge = TopoDS::Edge(edgeMap(ei));
            bool foundPolyline = false;

            // Try PolygonOnTriangulation first
            for (TopExp_Explorer faceExp(shape->shape, TopAbs_FACE); faceExp.More(); faceExp.Next()) {
                TopoDS_Face face = TopoDS::Face(faceExp.Current());
                TopLoc_Location loc;
                Handle(Poly_Triangulation) tri = BRep_Tool::Triangulation(face, loc);
                if (tri.IsNull()) continue;

                Handle(Poly_PolygonOnTriangulation) polyOnTri;
                TopLoc_Location edgeLoc;
                polyOnTri = BRep_Tool::PolygonOnTriangulation(edge, tri, edgeLoc);
                if (polyOnTri.IsNull()) continue;

                gp_Trsf transform;
                if (!loc.IsIdentity()) transform = loc.Transformation();

                const TColStd_Array1OfInteger& nodeIndices = polyOnTri->Nodes();
                if (nodeIndices.Length() < 2) continue;

                segStarts.push_back((int32_t)(allVerts.size() / 3));

                for (int i = nodeIndices.Lower(); i <= nodeIndices.Upper(); i++) {
                    gp_Pnt pt = tri->Node(nodeIndices(i));
                    if (!loc.IsIdentity()) pt.Transform(transform);
                    allVerts.push_back((float)pt.X());
                    allVerts.push_back((float)pt.Y());
                    allVerts.push_back((float)pt.Z());
                }

                foundPolyline = true;
                break;
            }

            if (!foundPolyline) {
                // Try Polygon3D
                TopLoc_Location loc;
                Handle(Poly_Polygon3D) poly3d = BRep_Tool::Polygon3D(edge, loc);
                if (!poly3d.IsNull() && poly3d->NbNodes() >= 2) {
                    gp_Trsf transform;
                    if (!loc.IsIdentity()) transform = loc.Transformation();

                    segStarts.push_back((int32_t)(allVerts.size() / 3));

                    for (int i = 1; i <= poly3d->NbNodes(); i++) {
                        gp_Pnt pt = poly3d->Nodes().Value(i);
                        if (!loc.IsIdentity()) pt.Transform(transform);
                        allVerts.push_back((float)pt.X());
                        allVerts.push_back((float)pt.Y());
                        allVerts.push_back((float)pt.Z());
                    }
                } else {
                    // Fall back to curve discretization
                    try {
                        BRepAdaptor_Curve curve(edge);
                        GCPnts_TangentialDeflection disc(curve, deflection, 0.1);
                        if (disc.NbPoints() >= 2) {
                            segStarts.push_back((int32_t)(allVerts.size() / 3));
                            for (int i = 1; i <= disc.NbPoints(); i++) {
                                gp_Pnt pt = disc.Value(i);
                                allVerts.push_back((float)pt.X());
                                allVerts.push_back((float)pt.Y());
                                allVerts.push_back((float)pt.Z());
                            }
                        }
                    } catch (...) {}
                }
            }
        }

        if (allVerts.empty()) return false;

        int32_t vertCount = (int32_t)(allVerts.size() / 3);
        int32_t segCount = (int32_t)segStarts.size();

        out->vertices = (float*)malloc(allVerts.size() * sizeof(float));
        out->segmentStarts = (int32_t*)malloc((segCount + 1) * sizeof(int32_t));
        if (!out->vertices || !out->segmentStarts) {
            free(out->vertices); free(out->segmentStarts);
            out->vertices = nullptr; out->segmentStarts = nullptr;
            return false;
        }

        memcpy(out->vertices, allVerts.data(), allVerts.size() * sizeof(float));
        memcpy(out->segmentStarts, segStarts.data(), segCount * sizeof(int32_t));
        out->segmentStarts[segCount] = vertCount; // sentinel

        out->vertexCount = vertCount;
        out->segmentCount = segCount;
        return true;
    } catch (...) {
        free(out->vertices); free(out->segmentStarts);
        out->vertices = nullptr; out->segmentStarts = nullptr;
        out->vertexCount = 0; out->segmentCount = 0;
        return false;
    }
}

void OCCTEdgeMeshDataFree(OCCTEdgeMeshData* data) {
    if (!data) return;
    free(data->vertices);
    free(data->segmentStarts);
    data->vertices = nullptr;
    data->segmentStarts = nullptr;
    data->vertexCount = 0;
    data->segmentCount = 0;
}

// MARK: - Selector Implementation

// Map selection mode integers to TopAbs_ShapeEnum:
// 0=SHAPE, 1=VERTEX, 2=EDGE, 3=WIRE, 4=FACE
static TopAbs_ShapeEnum OCCTModeToShapeEnum(Standard_Integer mode) {
    switch (mode) {
        case 1: return TopAbs_VERTEX;
        case 2: return TopAbs_EDGE;
        case 3: return TopAbs_WIRE;
        case 4: return TopAbs_FACE;
        default: return TopAbs_SHAPE;
    }
}

class OCCTBRepSelectable : public SelectMgr_SelectableObject {
    DEFINE_STANDARD_RTTI_INLINE(OCCTBRepSelectable, SelectMgr_SelectableObject)
public:
    OCCTBRepSelectable(const TopoDS_Shape& shape) : myShape(shape) {}

    const TopoDS_Shape& Shape() const { return myShape; }

private:
    void Compute(const Handle(PrsMgr_PresentationManager)&,
                 const Handle(Prs3d_Presentation)&,
                 const Standard_Integer) override {}

    void ComputeSelection(const Handle(SelectMgr_Selection)& sel,
                          const Standard_Integer mode) override {
        TopAbs_ShapeEnum type = OCCTModeToShapeEnum(mode);
        StdSelect_BRepSelectionTool::Load(sel, this, myShape,
                                          type, 0.05, 0.5, Standard_True);
    }

    TopoDS_Shape myShape;
};

// Subclass to expose the protected TraverseSensitives method so we can
// pick with a camera directly, bypassing the V3d_View requirement.
class OCCTHeadlessSelector : public SelectMgr_ViewerSelector {
    DEFINE_STANDARD_RTTI_INLINE(OCCTHeadlessSelector, SelectMgr_ViewerSelector)
public:
    OCCTHeadlessSelector() : SelectMgr_ViewerSelector() {}

    void PickPoint(double pixelX, double pixelY,
                   const Handle(Graphic3d_Camera)& cam,
                   int width, int height) {
        SelectMgr_SelectingVolumeManager& mgr = GetManager();
        mgr.InitPointSelectingVolume(gp_Pnt2d(pixelX, pixelY));
        mgr.SetCamera(cam);
        mgr.SetWindowSize(width, height);
        mgr.SetPixelTolerance(PixelTolerance());
        mgr.BuildSelectingVolume();
        TraverseSensitives();
    }

    void PickBox(double xMin, double yMin, double xMax, double yMax,
                 const Handle(Graphic3d_Camera)& cam,
                 int width, int height) {
        SelectMgr_SelectingVolumeManager& mgr = GetManager();
        mgr.InitBoxSelectingVolume(gp_Pnt2d(xMin, yMin), gp_Pnt2d(xMax, yMax));
        mgr.SetCamera(cam);
        mgr.SetWindowSize(width, height);
        mgr.SetPixelTolerance(PixelTolerance());
        mgr.BuildSelectingVolume();
        TraverseSensitives();
    }

    void PickPoly(const TColgp_Array1OfPnt2d& polyPoints,
                  const Handle(Graphic3d_Camera)& cam,
                  int width, int height) {
        SelectMgr_SelectingVolumeManager& mgr = GetManager();
        mgr.InitPolylineSelectingVolume(polyPoints);
        mgr.SetCamera(cam);
        mgr.SetWindowSize(width, height);
        mgr.SetPixelTolerance(PixelTolerance());
        mgr.BuildSelectingVolume();
        TraverseSensitives();
    }
};

struct OCCTSelector {
    Handle(OCCTHeadlessSelector) selector;
    Handle(SelectMgr_SelectionManager) selMgr;
    NCollection_DataMap<int32_t, Handle(OCCTBRepSelectable)> objects;

    OCCTSelector() {
        selector = new OCCTHeadlessSelector();
        selMgr = new SelectMgr_SelectionManager(selector);
    }
};

OCCTSelectorRef OCCTSelectorCreate(void) {
    try {
        return new OCCTSelector();
    } catch (...) {
        return nullptr;
    }
}

void OCCTSelectorDestroy(OCCTSelectorRef sel) {
    delete sel;
}

bool OCCTSelectorAddShape(OCCTSelectorRef sel, OCCTShapeRef shape, int32_t shapeId) {
    if (!sel || !shape) return false;
    try {
        if (sel->objects.IsBound(shapeId)) {
            Handle(OCCTBRepSelectable) old = sel->objects.Find(shapeId);
            sel->selMgr->Remove(old);
            sel->objects.UnBind(shapeId);
        }

        Handle(OCCTBRepSelectable) selectable = new OCCTBRepSelectable(shape->shape);
        sel->objects.Bind(shapeId, selectable);
        // Load and activate mode 0 (whole shape) by default
        sel->selMgr->Load(selectable, 0);
        sel->selMgr->Activate(selectable, 0);
        return true;
    } catch (...) {
        return false;
    }
}

bool OCCTSelectorRemoveShape(OCCTSelectorRef sel, int32_t shapeId) {
    if (!sel) return false;
    try {
        if (!sel->objects.IsBound(shapeId)) return false;
        Handle(OCCTBRepSelectable) obj = sel->objects.Find(shapeId);
        sel->selMgr->Remove(obj);
        sel->objects.UnBind(shapeId);
        return true;
    } catch (...) {
        return false;
    }
}

void OCCTSelectorClear(OCCTSelectorRef sel) {
    if (!sel) return;
    try {
        for (NCollection_DataMap<int32_t, Handle(OCCTBRepSelectable)>::Iterator it(sel->objects);
             it.More(); it.Next()) {
            sel->selMgr->Remove(it.Value());
        }
        sel->objects.Clear();
    } catch (...) {}
}

void OCCTSelectorActivateMode(OCCTSelectorRef sel, int32_t shapeId, int32_t mode) {
    if (!sel || !sel->objects.IsBound(shapeId)) return;
    try {
        Handle(OCCTBRepSelectable) obj = sel->objects.Find(shapeId);
        sel->selMgr->Activate(obj, mode);
    } catch (...) {}
}

void OCCTSelectorDeactivateMode(OCCTSelectorRef sel, int32_t shapeId, int32_t mode) {
    if (!sel || !sel->objects.IsBound(shapeId)) return;
    try {
        Handle(OCCTBRepSelectable) obj = sel->objects.Find(shapeId);
        sel->selMgr->Deactivate(obj, mode);
    } catch (...) {}
}

bool OCCTSelectorIsModeActive(OCCTSelectorRef sel, int32_t shapeId, int32_t mode) {
    if (!sel || !sel->objects.IsBound(shapeId)) return false;
    try {
        Handle(OCCTBRepSelectable) obj = sel->objects.Find(shapeId);
        return sel->selMgr->IsActivated(obj, mode) == Standard_True;
    } catch (...) {
        return false;
    }
}

void OCCTSelectorSetPixelTolerance(OCCTSelectorRef sel, int32_t tolerance) {
    if (!sel) return;
    sel->selector->SetPixelTolerance(tolerance);
}

int32_t OCCTSelectorGetPixelTolerance(OCCTSelectorRef sel) {
    if (!sel) return 2;
    Standard_Integer custom = sel->selector->CustomPixelTolerance();
    return custom >= 0 ? custom : 2;
}

static int32_t OCCTSelectorCollectResults(OCCTSelectorRef sel, OCCTPickResult* out, int32_t maxResults) {
    int32_t count = 0;
    for (int i = 1; i <= sel->selector->NbPicked() && count < maxResults; i++) {
        Handle(SelectMgr_EntityOwner) owner = sel->selector->Picked(i);
        if (owner.IsNull()) continue;

        Handle(OCCTBRepSelectable) selectable =
            Handle(OCCTBRepSelectable)::DownCast(owner->Selectable());
        if (selectable.IsNull()) continue;

        int32_t foundId = -1;
        for (NCollection_DataMap<int32_t, Handle(OCCTBRepSelectable)>::Iterator it(sel->objects);
             it.More(); it.Next()) {
            if (it.Value() == selectable) {
                foundId = it.Key();
                break;
            }
        }
        if (foundId < 0) continue;

        const SelectMgr_SortCriterion& criterion = sel->selector->PickedData(i);

        out[count].shapeId = foundId;
        out[count].depth = criterion.Depth;
        out[count].pointX = criterion.Point.X();
        out[count].pointY = criterion.Point.Y();
        out[count].pointZ = criterion.Point.Z();

        // Extract sub-shape information from BRepOwner
        out[count].subShapeType = static_cast<int32_t>(TopAbs_SHAPE);
        out[count].subShapeIndex = 0;

        Handle(StdSelect_BRepOwner) brepOwner =
            Handle(StdSelect_BRepOwner)::DownCast(owner);
        if (!brepOwner.IsNull() && brepOwner->HasShape()) {
            const TopoDS_Shape& subShape = brepOwner->Shape();
            out[count].subShapeType = static_cast<int32_t>(subShape.ShapeType());

            // Find 1-based index of sub-shape within parent shape
            if (brepOwner->ComesFromDecomposition()) {
                TopTools_IndexedMapOfShape map;
                TopExp::MapShapes(selectable->Shape(), subShape.ShapeType(), map);
                int idx = map.FindIndex(subShape);
                out[count].subShapeIndex = (idx > 0) ? idx : 0;
            }
        }

        count++;
    }
    return count;
}

int32_t OCCTSelectorPick(OCCTSelectorRef sel, OCCTCameraRef cam,
                         double viewW, double viewH,
                         double pixelX, double pixelY,
                         OCCTPickResult* out, int32_t maxResults) {
    if (!sel || !cam || !out || maxResults <= 0) return 0;
    try {
        Handle(Graphic3d_Camera) pickCam = new Graphic3d_Camera(*cam->camera);
        pickCam->SetAspect(viewW / viewH);

        sel->selector->PickPoint(pixelX, pixelY, pickCam,
                                 (int)viewW, (int)viewH);

        return OCCTSelectorCollectResults(sel, out, maxResults);
    } catch (...) {
        return 0;
    }
}

int32_t OCCTSelectorPickRect(OCCTSelectorRef sel, OCCTCameraRef cam,
                             double viewW, double viewH,
                             double xMin, double yMin, double xMax, double yMax,
                             OCCTPickResult* out, int32_t maxResults) {
    if (!sel || !cam || !out || maxResults <= 0) return 0;
    try {
        Handle(Graphic3d_Camera) pickCam = new Graphic3d_Camera(*cam->camera);
        pickCam->SetAspect(viewW / viewH);

        sel->selector->PickBox(xMin, yMin, xMax, yMax, pickCam,
                               (int)viewW, (int)viewH);

        return OCCTSelectorCollectResults(sel, out, maxResults);
    } catch (...) {
        return 0;
    }
}

int32_t OCCTSelectorPickPoly(OCCTSelectorRef sel, OCCTCameraRef cam,
                             double viewW, double viewH,
                             const double* polyXY, int32_t pointCount,
                             OCCTPickResult* out, int32_t maxResults) {
    if (!sel || !cam || !out || !polyXY || pointCount < 3 || maxResults <= 0) return 0;
    try {
        Handle(Graphic3d_Camera) pickCam = new Graphic3d_Camera(*cam->camera);
        pickCam->SetAspect(viewW / viewH);

        TColgp_Array1OfPnt2d polyPoints(1, pointCount);
        for (int i = 0; i < pointCount; i++) {
            polyPoints.SetValue(i + 1, gp_Pnt2d(polyXY[i * 2], polyXY[i * 2 + 1]));
        }

        sel->selector->PickPoly(polyPoints, pickCam, (int)viewW, (int)viewH);

        return OCCTSelectorCollectResults(sel, out, maxResults);
    } catch (...) {
        return 0;
    }
}

// MARK: - Display Drawer Implementation

struct OCCTDrawer {
    Handle(Prs3d_Drawer) drawer;
    OCCTDrawer() {
        drawer = new Prs3d_Drawer();
    }
};

OCCTDrawerRef OCCTDrawerCreate(void) {
    try {
        return new OCCTDrawer();
    } catch (...) {
        return nullptr;
    }
}

void OCCTDrawerDestroy(OCCTDrawerRef d) {
    delete d;
}

void OCCTDrawerSetDeviationCoefficient(OCCTDrawerRef d, double coeff) {
    if (!d) return;
    try { d->drawer->SetDeviationCoefficient(coeff); } catch (...) {}
}

double OCCTDrawerGetDeviationCoefficient(OCCTDrawerRef d) {
    if (!d) return 0.001;
    try { return d->drawer->DeviationCoefficient(); } catch (...) { return 0.001; }
}

void OCCTDrawerSetDeviationAngle(OCCTDrawerRef d, double angle) {
    if (!d) return;
    try { d->drawer->SetDeviationAngle(angle); } catch (...) {}
}

double OCCTDrawerGetDeviationAngle(OCCTDrawerRef d) {
    if (!d) return 20.0 * M_PI / 180.0;
    try { return d->drawer->DeviationAngle(); } catch (...) { return 20.0 * M_PI / 180.0; }
}

void OCCTDrawerSetMaximalChordialDeviation(OCCTDrawerRef d, double deviation) {
    if (!d) return;
    try { d->drawer->SetMaximalChordialDeviation(deviation); } catch (...) {}
}

double OCCTDrawerGetMaximalChordialDeviation(OCCTDrawerRef d) {
    if (!d) return 0.1;
    try { return d->drawer->MaximalChordialDeviation(); } catch (...) { return 0.1; }
}

void OCCTDrawerSetTypeOfDeflection(OCCTDrawerRef d, int32_t type) {
    if (!d) return;
    try { d->drawer->SetTypeOfDeflection(type == 1 ? Aspect_TOD_ABSOLUTE : Aspect_TOD_RELATIVE); } catch (...) {}
}

int32_t OCCTDrawerGetTypeOfDeflection(OCCTDrawerRef d) {
    if (!d) return 0;
    try { return d->drawer->TypeOfDeflection() == Aspect_TOD_ABSOLUTE ? 1 : 0; } catch (...) { return 0; }
}

void OCCTDrawerSetAutoTriangulation(OCCTDrawerRef d, bool on) {
    if (!d) return;
    try { d->drawer->SetAutoTriangulation(on ? Standard_True : Standard_False); } catch (...) {}
}

bool OCCTDrawerGetAutoTriangulation(OCCTDrawerRef d) {
    if (!d) return true;
    try { return d->drawer->IsAutoTriangulation() == Standard_True; } catch (...) { return true; }
}

void OCCTDrawerSetIsoOnTriangulation(OCCTDrawerRef d, bool on) {
    if (!d) return;
    try { d->drawer->SetIsoOnTriangulation(on ? Standard_True : Standard_False); } catch (...) {}
}

bool OCCTDrawerGetIsoOnTriangulation(OCCTDrawerRef d) {
    if (!d) return false;
    try { return d->drawer->IsoOnTriangulation() == Standard_True; } catch (...) { return false; }
}

void OCCTDrawerSetDiscretisation(OCCTDrawerRef d, int32_t value) {
    if (!d) return;
    try { d->drawer->SetDiscretisation(value); } catch (...) {}
}

int32_t OCCTDrawerGetDiscretisation(OCCTDrawerRef d) {
    if (!d) return 30;
    try { return d->drawer->Discretisation(); } catch (...) { return 30; }
}

void OCCTDrawerSetFaceBoundaryDraw(OCCTDrawerRef d, bool on) {
    if (!d) return;
    try { d->drawer->SetFaceBoundaryDraw(on ? Standard_True : Standard_False); } catch (...) {}
}

bool OCCTDrawerGetFaceBoundaryDraw(OCCTDrawerRef d) {
    if (!d) return false;
    try { return d->drawer->FaceBoundaryDraw() == Standard_True; } catch (...) { return false; }
}

void OCCTDrawerSetWireDraw(OCCTDrawerRef d, bool on) {
    if (!d) return;
    try { d->drawer->SetWireDraw(on ? Standard_True : Standard_False); } catch (...) {}
}

bool OCCTDrawerGetWireDraw(OCCTDrawerRef d) {
    if (!d) return true;
    try { return d->drawer->WireDraw() == Standard_True; } catch (...) { return true; }
}

// MARK: - Drawer-Aware Mesh Extraction

static double OCCTDrawerGetEffectiveDeflection(OCCTDrawerRef drawer) {
    if (!drawer) return 0.1;
    if (drawer->drawer->TypeOfDeflection() == Aspect_TOD_RELATIVE) {
        return drawer->drawer->DeviationCoefficient();
    } else {
        return drawer->drawer->MaximalChordialDeviation();
    }
}

bool OCCTShapeGetShadedMeshWithDrawer(OCCTShapeRef shape, OCCTDrawerRef drawer, OCCTShadedMeshData* out) {
    if (!shape || !drawer || !out) return false;
    double deflection = OCCTDrawerGetEffectiveDeflection(drawer);
    double angle = drawer->drawer->DeviationAngle();

    out->vertices = nullptr;
    out->vertexCount = 0;
    out->indices = nullptr;
    out->triangleCount = 0;

    try {
        BRepMesh_IncrementalMesh mesher(shape->shape, deflection, Standard_False, angle);
        mesher.Perform();

        return OCCTShapeGetShadedMesh(shape, deflection, out);
    } catch (...) {
        return false;
    }
}

bool OCCTShapeGetEdgeMeshWithDrawer(OCCTShapeRef shape, OCCTDrawerRef drawer, OCCTEdgeMeshData* out) {
    if (!shape || !drawer || !out) return false;
    double deflection = OCCTDrawerGetEffectiveDeflection(drawer);
    double angle = drawer->drawer->DeviationAngle();

    out->vertices = nullptr;
    out->vertexCount = 0;
    out->segmentStarts = nullptr;
    out->segmentCount = 0;

    try {
        BRepMesh_IncrementalMesh mesher(shape->shape, deflection, Standard_False, angle);
        mesher.Perform();

        return OCCTShapeGetEdgeMesh(shape, deflection, out);
    } catch (...) {
        return false;
    }
}

// MARK: - Clip Plane Implementation

struct OCCTClipPlane {
    Handle(Graphic3d_ClipPlane) plane;
};

OCCTClipPlaneRef OCCTClipPlaneCreate(double a, double b, double c, double d) {
    try {
        auto* cp = new OCCTClipPlane();
        cp->plane = new Graphic3d_ClipPlane(Graphic3d_Vec4d(a, b, c, d));
        return cp;
    } catch (...) {
        return nullptr;
    }
}

void OCCTClipPlaneDestroy(OCCTClipPlaneRef plane) {
    delete plane;
}

void OCCTClipPlaneSetEquation(OCCTClipPlaneRef plane, double a, double b, double c, double d) {
    if (!plane) return;
    try { plane->plane->SetEquation(Graphic3d_Vec4d(a, b, c, d)); } catch (...) {}
}

void OCCTClipPlaneGetEquation(OCCTClipPlaneRef plane, double* a, double* b, double* c, double* d) {
    if (!plane || !a || !b || !c || !d) return;
    try {
        const Graphic3d_Vec4d& eq = plane->plane->GetEquation();
        *a = eq.x();
        *b = eq.y();
        *c = eq.z();
        *d = eq.w();
    } catch (...) {}
}

void OCCTClipPlaneGetReversedEquation(OCCTClipPlaneRef plane, double* a, double* b, double* c, double* d) {
    if (!plane || !a || !b || !c || !d) return;
    try {
        const Graphic3d_Vec4d& eq = plane->plane->ReversedEquation();
        *a = eq.x();
        *b = eq.y();
        *c = eq.z();
        *d = eq.w();
    } catch (...) {}
}

void OCCTClipPlaneSetOn(OCCTClipPlaneRef plane, bool on) {
    if (!plane) return;
    try { plane->plane->SetOn(on ? Standard_True : Standard_False); } catch (...) {}
}

bool OCCTClipPlaneIsOn(OCCTClipPlaneRef plane) {
    if (!plane) return false;
    try { return plane->plane->IsOn() == Standard_True; } catch (...) { return false; }
}

void OCCTClipPlaneSetCapping(OCCTClipPlaneRef plane, bool on) {
    if (!plane) return;
    try { plane->plane->SetCapping(on ? Standard_True : Standard_False); } catch (...) {}
}

bool OCCTClipPlaneIsCapping(OCCTClipPlaneRef plane) {
    if (!plane) return false;
    try { return plane->plane->IsCapping() == Standard_True; } catch (...) { return false; }
}

void OCCTClipPlaneSetCappingColor(OCCTClipPlaneRef plane, double r, double g, double b) {
    if (!plane) return;
    try { plane->plane->SetCappingColor(Quantity_Color(r, g, b, Quantity_TOC_RGB)); } catch (...) {}
}

void OCCTClipPlaneGetCappingColor(OCCTClipPlaneRef plane, double* r, double* g, double* b) {
    if (!plane || !r || !g || !b) return;
    try {
        // Read InteriorColor directly from the aspect, matching what SetCappingColor writes.
        // CappingColor() may return the material color if material type != MATERIAL_ASPECT.
        Quantity_Color color = plane->plane->CappingAspect()->InteriorColor();
        *r = color.Red();
        *g = color.Green();
        *b = color.Blue();
    } catch (...) {}
}

void OCCTClipPlaneSetCappingHatch(OCCTClipPlaneRef plane, int32_t style) {
    if (!plane) return;
    try { plane->plane->SetCappingHatch(static_cast<Aspect_HatchStyle>(style)); } catch (...) {}
}

int32_t OCCTClipPlaneGetCappingHatch(OCCTClipPlaneRef plane) {
    if (!plane) return 0;
    try { return static_cast<int32_t>(plane->plane->CappingHatch()); } catch (...) { return 0; }
}

void OCCTClipPlaneSetCappingHatchOn(OCCTClipPlaneRef plane, bool on) {
    if (!plane) return;
    try {
        if (on) {
            plane->plane->SetCappingHatchOn();
        } else {
            plane->plane->SetCappingHatchOff();
        }
    } catch (...) {}
}

bool OCCTClipPlaneIsCappingHatchOn(OCCTClipPlaneRef plane) {
    if (!plane) return false;
    try { return plane->plane->IsHatchOn() == Standard_True; } catch (...) { return false; }
}

int32_t OCCTClipPlaneProbePoint(OCCTClipPlaneRef plane, double x, double y, double z) {
    if (!plane) return 0;
    try {
        Graphic3d_Vec4d pt(x, y, z, 1.0);
        Graphic3d_ClipState worst = Graphic3d_ClipState_In;
        for (Handle(Graphic3d_ClipPlane) p = plane->plane; !p.IsNull(); p = p->ChainNextPlane()) {
            Graphic3d_ClipState state = p->ProbePointHalfspace(pt);
            if (state == Graphic3d_ClipState_Out) {
                return static_cast<int32_t>(Graphic3d_ClipState_Out);
            }
            if (state == Graphic3d_ClipState_On) {
                worst = Graphic3d_ClipState_On;
            }
        }
        return static_cast<int32_t>(worst);
    } catch (...) { return 0; }
}

int32_t OCCTClipPlaneProbeBox(OCCTClipPlaneRef plane,
                               double xMin, double yMin, double zMin,
                               double xMax, double yMax, double zMax) {
    if (!plane) return 0;
    try {
        Graphic3d_BndBox3d box;
        box.Add(Graphic3d_Vec3d(xMin, yMin, zMin));
        box.Add(Graphic3d_Vec3d(xMax, yMax, zMax));
        Graphic3d_ClipState worst = Graphic3d_ClipState_In;
        for (Handle(Graphic3d_ClipPlane) p = plane->plane; !p.IsNull(); p = p->ChainNextPlane()) {
            Graphic3d_ClipState state = p->ProbeBoxHalfspace(box);
            if (state == Graphic3d_ClipState_Out) {
                return static_cast<int32_t>(Graphic3d_ClipState_Out);
            }
            if (state == Graphic3d_ClipState_On) {
                worst = Graphic3d_ClipState_On;
            }
        }
        return static_cast<int32_t>(worst);
    } catch (...) { return 0; }
}

void OCCTClipPlaneSetChainNext(OCCTClipPlaneRef plane, OCCTClipPlaneRef next) {
    if (!plane) return;
    try {
        if (next) {
            plane->plane->SetChainNextPlane(next->plane);
        } else {
            plane->plane->SetChainNextPlane(Handle(Graphic3d_ClipPlane)());
        }
    } catch (...) {}
}

int32_t OCCTClipPlaneChainLength(OCCTClipPlaneRef plane) {
    if (!plane) return 0;
    try { return plane->plane->NbChainNextPlanes(); } catch (...) { return 0; }
}

// MARK: - Z-Layer Settings Implementation

struct OCCTZLayerSettings {
    Graphic3d_ZLayerSettings settings;
};

OCCTZLayerSettingsRef OCCTZLayerSettingsCreate(void) {
    try {
        return new OCCTZLayerSettings();
    } catch (...) {
        return nullptr;
    }
}

void OCCTZLayerSettingsDestroy(OCCTZLayerSettingsRef s) {
    delete s;
}

void OCCTZLayerSettingsSetName(OCCTZLayerSettingsRef s, const char* name) {
    if (!s || !name) return;
    try { s->settings.SetName(TCollection_AsciiString(name)); } catch (...) {}
}

void OCCTZLayerSettingsSetDepthTest(OCCTZLayerSettingsRef s, bool on) {
    if (!s) return;
    try { s->settings.SetEnableDepthTest(on ? Standard_True : Standard_False); } catch (...) {}
}

bool OCCTZLayerSettingsGetDepthTest(OCCTZLayerSettingsRef s) {
    if (!s) return true;
    try { return s->settings.ToEnableDepthTest() == Standard_True; } catch (...) { return true; }
}

void OCCTZLayerSettingsSetDepthWrite(OCCTZLayerSettingsRef s, bool on) {
    if (!s) return;
    try { s->settings.SetEnableDepthWrite(on ? Standard_True : Standard_False); } catch (...) {}
}

bool OCCTZLayerSettingsGetDepthWrite(OCCTZLayerSettingsRef s) {
    if (!s) return true;
    try { return s->settings.ToEnableDepthWrite() == Standard_True; } catch (...) { return true; }
}

void OCCTZLayerSettingsSetClearDepth(OCCTZLayerSettingsRef s, bool on) {
    if (!s) return;
    try { s->settings.SetClearDepth(on ? Standard_True : Standard_False); } catch (...) {}
}

bool OCCTZLayerSettingsGetClearDepth(OCCTZLayerSettingsRef s) {
    if (!s) return true;
    try { return s->settings.ToClearDepth() == Standard_True; } catch (...) { return true; }
}

void OCCTZLayerSettingsSetPolygonOffset(OCCTZLayerSettingsRef s, int32_t mode, float factor, float units) {
    if (!s) return;
    try {
        Graphic3d_PolygonOffset offset;
        offset.Mode = static_cast<Aspect_PolygonOffsetMode>(mode);
        offset.Factor = factor;
        offset.Units = units;
        s->settings.SetPolygonOffset(offset);
    } catch (...) {}
}

void OCCTZLayerSettingsGetPolygonOffset(OCCTZLayerSettingsRef s, int32_t* mode, float* factor, float* units) {
    if (!s || !mode || !factor || !units) return;
    try {
        const Graphic3d_PolygonOffset& offset = s->settings.PolygonOffset();
        *mode = static_cast<int32_t>(offset.Mode);
        *factor = offset.Factor;
        *units = offset.Units;
    } catch (...) {}
}

void OCCTZLayerSettingsSetDepthOffsetPositive(OCCTZLayerSettingsRef s) {
    if (!s) return;
    try { s->settings.SetDepthOffsetPositive(); } catch (...) {}
}

void OCCTZLayerSettingsSetDepthOffsetNegative(OCCTZLayerSettingsRef s) {
    if (!s) return;
    try { s->settings.SetDepthOffsetNegative(); } catch (...) {}
}

void OCCTZLayerSettingsSetImmediate(OCCTZLayerSettingsRef s, bool on) {
    if (!s) return;
    try { s->settings.SetImmediate(on ? Standard_True : Standard_False); } catch (...) {}
}

bool OCCTZLayerSettingsGetImmediate(OCCTZLayerSettingsRef s) {
    if (!s) return false;
    try { return s->settings.IsImmediate() == Standard_True; } catch (...) { return false; }
}

void OCCTZLayerSettingsSetRaytracable(OCCTZLayerSettingsRef s, bool on) {
    if (!s) return;
    try { s->settings.SetRaytracable(on ? Standard_True : Standard_False); } catch (...) {}
}

bool OCCTZLayerSettingsGetRaytracable(OCCTZLayerSettingsRef s) {
    if (!s) return true;
    try { return s->settings.IsRaytracable() == Standard_True; } catch (...) { return true; }
}

void OCCTZLayerSettingsSetEnvironmentTexture(OCCTZLayerSettingsRef s, bool on) {
    if (!s) return;
    try { s->settings.SetEnvironmentTexture(on ? Standard_True : Standard_False); } catch (...) {}
}

bool OCCTZLayerSettingsGetEnvironmentTexture(OCCTZLayerSettingsRef s) {
    if (!s) return true;
    try { return s->settings.UseEnvironmentTexture() == Standard_True; } catch (...) { return true; }
}

void OCCTZLayerSettingsSetRenderInDepthPrepass(OCCTZLayerSettingsRef s, bool on) {
    if (!s) return;
    try { s->settings.SetRenderInDepthPrepass(on ? Standard_True : Standard_False); } catch (...) {}
}

bool OCCTZLayerSettingsGetRenderInDepthPrepass(OCCTZLayerSettingsRef s) {
    if (!s) return true;
    try { return s->settings.ToRenderInDepthPrepass() == Standard_True; } catch (...) { return true; }
}

void OCCTZLayerSettingsSetCullingDistance(OCCTZLayerSettingsRef s, double distance) {
    if (!s) return;
    try { s->settings.SetCullingDistance(distance); } catch (...) {}
}

double OCCTZLayerSettingsGetCullingDistance(OCCTZLayerSettingsRef s) {
    if (!s) return 0.0;
    try { return s->settings.CullingDistance(); } catch (...) { return 0.0; }
}

void OCCTZLayerSettingsSetCullingSize(OCCTZLayerSettingsRef s, double size) {
    if (!s) return;
    try { s->settings.SetCullingSize(size); } catch (...) {}
}

double OCCTZLayerSettingsGetCullingSize(OCCTZLayerSettingsRef s) {
    if (!s) return 0.0;
    try { return s->settings.CullingSize(); } catch (...) { return 0.0; }
}

void OCCTZLayerSettingsSetOrigin(OCCTZLayerSettingsRef s, double x, double y, double z) {
    if (!s) return;
    try { s->settings.SetOrigin(gp_XYZ(x, y, z)); } catch (...) {}
}

void OCCTZLayerSettingsGetOrigin(OCCTZLayerSettingsRef s, double* x, double* y, double* z) {
    if (!s || !x || !y || !z) return;
    try {
        const gp_XYZ& origin = s->settings.Origin();
        *x = origin.X();
        *y = origin.Y();
        *z = origin.Z();
    } catch (...) {}
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
#include <GCE2d_MakeSegment.hxx>
#include <GCE2d_MakeCircle.hxx>
#include <GCE2d_MakeArcOfCircle.hxx>
#include <GCE2d_MakeEllipse.hxx>
#include <GCE2d_MakeArcOfEllipse.hxx>
#include <GCE2d_MakeParabola.hxx>
#include <GCE2d_MakeHyperbola.hxx>
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
        GCE2d_MakeSegment maker(p1, p2);
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
        GCE2d_MakeArcOfCircle maker(p1, p2, p3);
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

#include <Geom2dLProp_CLProps2d.hxx>
#include <Geom2dLProp_CurAndInf2d.hxx>
#include <LProp_CurAndInf.hxx>
#include <LProp_CIType.hxx>
#include <Bnd_Box2d.hxx>
#include <BndLib_Add2dCurve.hxx>
#include <GCE2d_MakeArcOfHyperbola.hxx>
#include <GCE2d_MakeArcOfParabola.hxx>
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
        Geom2dLProp_CLProps2d props(c->curve, u, 2, Precision::Confusion());
        return props.Curvature();
    } catch (...) {
        return 0.0;
    }
}

bool OCCTCurve2DGetNormal(OCCTCurve2DRef c, double u, double* nx, double* ny) {
    if (!c || c->curve.IsNull() || !nx || !ny) return false;
    try {
        Geom2dLProp_CLProps2d props(c->curve, u, 2, Precision::Confusion());
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
        Geom2dLProp_CLProps2d props(c->curve, u, 1, Precision::Confusion());
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
        Geom2dLProp_CLProps2d props(c->curve, u, 2, Precision::Confusion());
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
        Geom2dLProp_CurAndInf2d analyzer;
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
        Geom2dLProp_CurAndInf2d analyzer;
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
        Geom2dLProp_CurAndInf2d analyzer;
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


// MARK: - STL Import (v0.17.0)

#include <StlAPI_Reader.hxx>

OCCTShapeRef OCCTImportSTL(const char* path) {
    if (!path) return nullptr;

    try {
        TopoDS_Shape shape;
        StlAPI_Reader reader;
        if (!reader.Read(shape, path)) return nullptr;
        if (shape.IsNull()) return nullptr;
        return new OCCTShape(shape);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTImportSTLRobust(const char* path, double sewingTolerance) {
    if (!path) return nullptr;

    try {
        TopoDS_Shape shape;
        StlAPI_Reader reader;
        if (!reader.Read(shape, path)) return nullptr;
        if (shape.IsNull()) return nullptr;

        // Sew disconnected faces
        BRepBuilderAPI_Sewing sewing(sewingTolerance);
        sewing.Add(shape);
        sewing.Perform();
        TopoDS_Shape sewedShape = sewing.SewedShape();
        if (sewedShape.IsNull()) sewedShape = shape;

        // Try to create solid from shell
        TopoDS_Shape resultShape = sewedShape;
        if (sewedShape.ShapeType() != TopAbs_SOLID) {
            TopExp_Explorer shellExp(sewedShape, TopAbs_SHELL);
            if (shellExp.More()) {
                BRepBuilderAPI_MakeSolid makeSolid(TopoDS::Shell(shellExp.Current()));
                if (makeSolid.IsDone()) {
                    resultShape = makeSolid.Solid();
                }
            }
        }

        // Apply shape healing
        ShapeFix_Shape fixer(resultShape);
        fixer.Perform();
        TopoDS_Shape fixed = fixer.Shape();
        return new OCCTShape(fixed.IsNull() ? resultShape : fixed);
    } catch (...) {
        return nullptr;
    }
}


// MARK: - OBJ Import/Export (v0.17.0)

#include <RWObj_CafReader.hxx>
#include <RWObj_CafWriter.hxx>
#include <TDocStd_Document.hxx>
#include <XCAFApp_Application.hxx>
#include <XCAFDoc_DocumentTool.hxx>
#include <Message_ProgressRange.hxx>

OCCTShapeRef OCCTImportOBJ(const char* path) {
    if (!path) return nullptr;

    try {
        // Use RWObj_CafReader for OBJ import
        RWObj_CafReader objReader;

        // Create an XDE document
        Handle(TDocStd_Document) doc;
        Handle(XCAFApp_Application) app = XCAFApp_Application::GetApplication();
        app->NewDocument("MDTV-XCAF", doc);

        objReader.SetDocument(doc);
        TCollection_AsciiString filePath(path);
        if (!objReader.Perform(filePath, Message_ProgressRange())) return nullptr;

        // Extract shape from document
        Handle(XCAFDoc_ShapeTool) shapeTool = XCAFDoc_DocumentTool::ShapeTool(doc->Main());
        TopoDS_Shape shape = shapeTool->GetOneShape();
        if (shape.IsNull()) return nullptr;

        // Close document
        app->Close(doc);

        return new OCCTShape(shape);
    } catch (...) {
        return nullptr;
    }
}

bool OCCTExportOBJ(OCCTShapeRef shape, const char* path, double deflection) {
    if (!shape || !path) return false;

    try {
        // Tessellate the shape first
        BRepMesh_IncrementalMesh mesher(shape->shape, deflection);
        mesher.Perform();

        // Create an XDE document
        Handle(TDocStd_Document) doc;
        Handle(XCAFApp_Application) app = XCAFApp_Application::GetApplication();
        app->NewDocument("MDTV-XCAF", doc);

        Handle(XCAFDoc_ShapeTool) shapeTool = XCAFDoc_DocumentTool::ShapeTool(doc->Main());
        shapeTool->AddShape(shape->shape);

        // Write OBJ
        RWObj_CafWriter writer(path);
        NCollection_Sequence<TDF_Label> rootLabels;
        TDF_LabelSequence freeShapes;
        shapeTool->GetFreeShapes(freeShapes);
        for (int i = 1; i <= freeShapes.Length(); ++i) {
            rootLabels.Append(freeShapes.Value(i));
        }
        NCollection_IndexedDataMap<TCollection_AsciiString, TCollection_AsciiString> fileInfo;
        bool success = writer.Perform(doc, rootLabels, nullptr, fileInfo, Message_ProgressRange());

        app->Close(doc);
        return success;
    } catch (...) {
        return false;
    }
}


// MARK: - PLY Export (v0.17.0)

#include <RWPly_CafWriter.hxx>

bool OCCTExportPLY(OCCTShapeRef shape, const char* path, double deflection) {
    if (!shape || !path) return false;

    try {
        // Tessellate the shape first
        BRepMesh_IncrementalMesh mesher(shape->shape, deflection);
        mesher.Perform();

        // Create an XDE document
        Handle(TDocStd_Document) doc;
        Handle(XCAFApp_Application) app = XCAFApp_Application::GetApplication();
        app->NewDocument("MDTV-XCAF", doc);

        Handle(XCAFDoc_ShapeTool) shapeTool = XCAFDoc_DocumentTool::ShapeTool(doc->Main());
        shapeTool->AddShape(shape->shape);

        // Write PLY
        RWPly_CafWriter writer(path);
        writer.SetNormals(true);
        NCollection_Sequence<TDF_Label> rootLabels;
        TDF_LabelSequence freeShapes;
        shapeTool->GetFreeShapes(freeShapes);
        for (int i = 1; i <= freeShapes.Length(); ++i) {
            rootLabels.Append(freeShapes.Value(i));
        }
        NCollection_IndexedDataMap<TCollection_AsciiString, TCollection_AsciiString> fileInfo;
        bool success = writer.Perform(doc, rootLabels, nullptr, fileInfo, Message_ProgressRange());

        app->Close(doc);
        return success;
    } catch (...) {
        return false;
    }
}


// MARK: - Advanced Healing (v0.17.0)

#include <ShapeUpgrade_ShapeDivide.hxx>
#include <ShapeUpgrade_ShapeDivideContinuity.hxx>
#include <ShapeCustom.hxx>
#include <ShapeCustom_RestrictionParameters.hxx>

OCCTShapeRef OCCTShapeDivide(OCCTShapeRef shape, int32_t continuity) {
    if (!shape) return nullptr;

    try {
        // Map continuity: 0=C0, 1=C1, 2=C2, 3=C3
        GeomAbs_Shape cont;
        switch (continuity) {
            case 0:  cont = GeomAbs_C0; break;
            case 1:  cont = GeomAbs_C1; break;
            case 2:  cont = GeomAbs_C2; break;
            case 3:  cont = GeomAbs_C3; break;
            default: cont = GeomAbs_C1; break;
        }

        ShapeUpgrade_ShapeDivideContinuity divider(shape->shape);
        divider.SetBoundaryCriterion(cont);
        divider.SetPCurveCriterion(cont);
        divider.SetSurfaceCriterion(cont);
        divider.SetSurfaceSegmentMode(Standard_True);
        if (!divider.Perform()) return nullptr;

        TopoDS_Shape result = divider.Result();
        if (result.IsNull()) return nullptr;

        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeDirectFaces(OCCTShapeRef shape) {
    if (!shape) return nullptr;

    try {
        TopoDS_Shape result = ShapeCustom::DirectFaces(shape->shape);
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeScaleGeometry(OCCTShapeRef shape, double factor) {
    if (!shape) return nullptr;

    try {
        TopoDS_Shape result = ShapeCustom::ScaleShape(shape->shape, factor);
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeBSplineRestriction(OCCTShapeRef shape,
                                          double surfaceTol, double curveTol,
                                          int32_t maxDegree, int32_t maxSegments) {
    if (!shape) return nullptr;

    try {
        // Static method signature:
        // BSplineRestriction(shape, Tol3d, Tol2d, MaxDegree, MaxNbSegment,
        //                    Continuity3d, Continuity2d, Degree, Rational, aParameters)
        Handle(ShapeCustom_RestrictionParameters) params = new ShapeCustom_RestrictionParameters();
        TopoDS_Shape result = ShapeCustom::BSplineRestriction(
            shape->shape,
            surfaceTol,
            curveTol,
            maxDegree,
            maxSegments,
            GeomAbs_C1,       // Continuity3d
            GeomAbs_C1,       // Continuity2d
            Standard_True,     // Degree priority
            Standard_True,     // Rational
            params
        );
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeSweptToElementary(OCCTShapeRef shape) {
    if (!shape) return nullptr;

    try {
        TopoDS_Shape result = ShapeCustom::SweptToElementary(shape->shape);
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeRevolutionToElementary(OCCTShapeRef shape) {
    if (!shape) return nullptr;

    try {
        TopoDS_Shape result = ShapeCustom::ConvertToRevolution(shape->shape);
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeConvertToBSpline(OCCTShapeRef shape) {
    if (!shape) return nullptr;

    try {
        // ConvertToBSpline(shape, extrMode, revolMode, offsetMode, planeMode)
        TopoDS_Shape result = ShapeCustom::ConvertToBSpline(
            shape->shape,
            Standard_True,   // Convert extrusion surfaces
            Standard_True,   // Convert revolution surfaces
            Standard_True,   // Convert offset surfaces
            Standard_False   // Don't convert planes
        );
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeSewSingle(OCCTShapeRef shape, double tolerance) {
    if (!shape) return nullptr;

    try {
        BRepBuilderAPI_Sewing sewing(tolerance);
        sewing.Add(shape->shape);
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

OCCTShapeRef OCCTShapeUpgrade(OCCTShapeRef shape, double tolerance) {
    if (!shape) return nullptr;

    try {
        // Step 1: Sew
        BRepBuilderAPI_Sewing sewing(tolerance);
        sewing.Add(shape->shape);
        sewing.Perform();
        TopoDS_Shape sewedShape = sewing.SewedShape();
        if (sewedShape.IsNull()) sewedShape = shape->shape;

        // Step 2: Try to create solid from shell
        TopoDS_Shape resultShape = sewedShape;
        if (sewedShape.ShapeType() != TopAbs_SOLID) {
            TopExp_Explorer shellExp(sewedShape, TopAbs_SHELL);
            if (shellExp.More()) {
                BRepBuilderAPI_MakeSolid makeSolid(TopoDS::Shell(shellExp.Current()));
                if (makeSolid.IsDone()) {
                    resultShape = makeSolid.Solid();
                }
            }
        }

        // Step 3: Apply shape healing
        ShapeFix_Shape fixer(resultShape);
        fixer.Perform();
        TopoDS_Shape fixed = fixer.Shape();
        return new OCCTShape(fixed.IsNull() ? resultShape : fixed);
    } catch (...) {
        return nullptr;
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


// MARK: - Face Surface Properties (v0.18.0)

#include <GeomLProp_SLProps.hxx>
#include <BRepGProp.hxx>

bool OCCTFaceGetUVBounds(OCCTFaceRef face,
                         double* uMin, double* uMax,
                         double* vMin, double* vMax) {
    if (!face || !uMin || !uMax || !vMin || !vMax) return false;

    try {
        BRepTools::UVBounds(face->face, *uMin, *uMax, *vMin, *vMax);
        return true;
    } catch (...) {
        return false;
    }
}

bool OCCTFaceEvaluateAtUV(OCCTFaceRef face, double u, double v,
                          double* px, double* py, double* pz) {
    if (!face || !px || !py || !pz) return false;

    try {
        Handle(Geom_Surface) surface = BRep_Tool::Surface(face->face);
        if (surface.IsNull()) return false;

        gp_Pnt pnt;
        surface->D0(u, v, pnt);
        *px = pnt.X();
        *py = pnt.Y();
        *pz = pnt.Z();
        return true;
    } catch (...) {
        return false;
    }
}

bool OCCTFaceGetNormalAtUV(OCCTFaceRef face, double u, double v,
                           double* nx, double* ny, double* nz) {
    if (!face || !nx || !ny || !nz) return false;

    try {
        Handle(Geom_Surface) surface = BRep_Tool::Surface(face->face);
        if (surface.IsNull()) return false;

        GeomLProp_SLProps props(surface, u, v, 1, Precision::Confusion());
        if (!props.IsNormalDefined()) return false;

        gp_Dir normal = props.Normal();
        // Reverse if face orientation is reversed
        if (face->face.Orientation() == TopAbs_REVERSED) {
            normal.Reverse();
        }
        *nx = normal.X();
        *ny = normal.Y();
        *nz = normal.Z();
        return true;
    } catch (...) {
        return false;
    }
}

bool OCCTFaceGetGaussianCurvature(OCCTFaceRef face, double u, double v,
                                   double* curvature) {
    if (!face || !curvature) return false;

    try {
        Handle(Geom_Surface) surface = BRep_Tool::Surface(face->face);
        if (surface.IsNull()) return false;

        GeomLProp_SLProps props(surface, u, v, 2, Precision::Confusion());
        if (!props.IsCurvatureDefined()) return false;

        *curvature = props.GaussianCurvature();
        return true;
    } catch (...) {
        return false;
    }
}

bool OCCTFaceGetMeanCurvature(OCCTFaceRef face, double u, double v,
                               double* curvature) {
    if (!face || !curvature) return false;

    try {
        Handle(Geom_Surface) surface = BRep_Tool::Surface(face->face);
        if (surface.IsNull()) return false;

        GeomLProp_SLProps props(surface, u, v, 2, Precision::Confusion());
        if (!props.IsCurvatureDefined()) return false;

        *curvature = props.MeanCurvature();
        return true;
    } catch (...) {
        return false;
    }
}

bool OCCTFaceGetPrincipalCurvatures(OCCTFaceRef face, double u, double v,
                                     double* k1, double* k2,
                                     double* d1x, double* d1y, double* d1z,
                                     double* d2x, double* d2y, double* d2z) {
    if (!face || !k1 || !k2 || !d1x || !d1y || !d1z || !d2x || !d2y || !d2z)
        return false;

    try {
        Handle(Geom_Surface) surface = BRep_Tool::Surface(face->face);
        if (surface.IsNull()) return false;

        GeomLProp_SLProps props(surface, u, v, 2, Precision::Confusion());
        if (!props.IsCurvatureDefined()) return false;

        *k1 = props.MinCurvature();
        *k2 = props.MaxCurvature();

        gp_Dir dir1, dir2;
        props.CurvatureDirections(dir1, dir2);
        *d1x = dir1.X(); *d1y = dir1.Y(); *d1z = dir1.Z();
        *d2x = dir2.X(); *d2y = dir2.Y(); *d2z = dir2.Z();
        return true;
    } catch (...) {
        return false;
    }
}

int32_t OCCTFaceGetSurfaceType(OCCTFaceRef face) {
    if (!face) return 10; // Other

    try {
        BRepAdaptor_Surface adaptor(face->face);
        switch (adaptor.GetType()) {
            case GeomAbs_Plane:              return 0;
            case GeomAbs_Cylinder:           return 1;
            case GeomAbs_Cone:               return 2;
            case GeomAbs_Sphere:             return 3;
            case GeomAbs_Torus:              return 4;
            case GeomAbs_BezierSurface:      return 5;
            case GeomAbs_BSplineSurface:     return 6;
            case GeomAbs_SurfaceOfRevolution:return 7;
            case GeomAbs_SurfaceOfExtrusion: return 8;
            case GeomAbs_OffsetSurface:      return 9;
            default:                         return 10;
        }
    } catch (...) {
        return 10;
    }
}

double OCCTFaceGetArea(OCCTFaceRef face, double tolerance) {
    if (!face) return -1.0;

    try {
        GProp_GProps props;
        BRepGProp::SurfaceProperties(face->face, props, tolerance);
        return props.Mass();
    } catch (...) {
        return -1.0;
    }
}


// MARK: - Edge 3D Curve Properties (v0.18.0)

#include <GeomLProp_CLProps.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <GeomAbs_CurveType.hxx>

bool OCCTEdgeGetParameterBounds(OCCTEdgeRef edge, double* first, double* last) {
    if (!edge || !first || !last) return false;

    try {
        Standard_Real f, l;
        Handle(Geom_Curve) curve = BRep_Tool::Curve(edge->edge, f, l);
        if (curve.IsNull()) return false;

        *first = f;
        *last = l;
        return true;
    } catch (...) {
        return false;
    }
}

bool OCCTEdgeGetCurvature3D(OCCTEdgeRef edge, double param, double* curvature) {
    if (!edge || !curvature) return false;

    try {
        Standard_Real f, l;
        Handle(Geom_Curve) curve = BRep_Tool::Curve(edge->edge, f, l);
        if (curve.IsNull()) return false;

        GeomLProp_CLProps props(curve, 2, Precision::Confusion());
        props.SetParameter(param);
        if (!props.IsTangentDefined()) return false;

        *curvature = props.Curvature();
        return true;
    } catch (...) {
        return false;
    }
}

bool OCCTEdgeGetTangent3D(OCCTEdgeRef edge, double param,
                           double* tx, double* ty, double* tz) {
    if (!edge || !tx || !ty || !tz) return false;

    try {
        Standard_Real f, l;
        Handle(Geom_Curve) curve = BRep_Tool::Curve(edge->edge, f, l);
        if (curve.IsNull()) return false;

        GeomLProp_CLProps props(curve, 1, Precision::Confusion());
        props.SetParameter(param);
        if (!props.IsTangentDefined()) return false;

        gp_Dir dir;
        props.Tangent(dir);
        *tx = dir.X();
        *ty = dir.Y();
        *tz = dir.Z();
        return true;
    } catch (...) {
        return false;
    }
}

bool OCCTEdgeGetNormal3D(OCCTEdgeRef edge, double param,
                          double* nx, double* ny, double* nz) {
    if (!edge || !nx || !ny || !nz) return false;

    try {
        Standard_Real f, l;
        Handle(Geom_Curve) curve = BRep_Tool::Curve(edge->edge, f, l);
        if (curve.IsNull()) return false;

        GeomLProp_CLProps props(curve, 2, Precision::Confusion());
        props.SetParameter(param);
        if (!props.IsTangentDefined()) return false;

        gp_Dir dir;
        props.Normal(dir);
        *nx = dir.X();
        *ny = dir.Y();
        *nz = dir.Z();
        return true;
    } catch (...) {
        return false;
    }
}

bool OCCTEdgeGetCenterOfCurvature3D(OCCTEdgeRef edge, double param,
                                     double* cx, double* cy, double* cz) {
    if (!edge || !cx || !cy || !cz) return false;

    try {
        Standard_Real f, l;
        Handle(Geom_Curve) curve = BRep_Tool::Curve(edge->edge, f, l);
        if (curve.IsNull()) return false;

        GeomLProp_CLProps props(curve, 2, Precision::Confusion());
        props.SetParameter(param);
        if (!props.IsTangentDefined()) return false;

        if (props.Curvature() < Precision::Confusion()) return false;

        gp_Pnt center;
        props.CentreOfCurvature(center);
        *cx = center.X();
        *cy = center.Y();
        *cz = center.Z();
        return true;
    } catch (...) {
        return false;
    }
}

bool OCCTEdgeGetTorsion(OCCTEdgeRef edge, double param, double* torsion) {
    if (!edge || !torsion) return false;

    try {
        Standard_Real f, l;
        Handle(Geom_Curve) curve = BRep_Tool::Curve(edge->edge, f, l);
        if (curve.IsNull()) return false;

        // Need 3rd derivative for torsion
        gp_Pnt pnt;
        gp_Vec d1, d2, d3;
        curve->D3(param, pnt, d1, d2, d3);

        // Torsion = (d1 x d2) . d3 / |d1 x d2|^2
        gp_Vec cross = d1.Crossed(d2);
        double crossMag2 = cross.SquareMagnitude();
        if (crossMag2 < Precision::Confusion()) {
            *torsion = 0.0;
            return true;
        }
        *torsion = cross.Dot(d3) / crossMag2;
        return true;
    } catch (...) {
        return false;
    }
}

bool OCCTEdgeGetPointAtParam(OCCTEdgeRef edge, double param,
                              double* px, double* py, double* pz) {
    if (!edge || !px || !py || !pz) return false;

    try {
        Standard_Real f, l;
        Handle(Geom_Curve) curve = BRep_Tool::Curve(edge->edge, f, l);
        if (curve.IsNull()) return false;

        gp_Pnt pnt;
        curve->D0(param, pnt);
        *px = pnt.X();
        *py = pnt.Y();
        *pz = pnt.Z();
        return true;
    } catch (...) {
        return false;
    }
}

int32_t OCCTEdgeGetCurveType(OCCTEdgeRef edge) {
    if (!edge) return 8; // Other

    try {
        BRepAdaptor_Curve adaptor(edge->edge);
        switch (adaptor.GetType()) {
            case GeomAbs_Line:       return 0;
            case GeomAbs_Circle:     return 1;
            case GeomAbs_Ellipse:    return 2;
            case GeomAbs_Hyperbola:  return 3;
            case GeomAbs_Parabola:   return 4;
            case GeomAbs_BezierCurve:return 5;
            case GeomAbs_BSplineCurve:return 6;
            case GeomAbs_OffsetCurve:return 7;
            default:                 return 8;
        }
    } catch (...) {
        return 8;
    }
}


// MARK: - Point Projection (v0.18.0)

#include <GeomAPI_ProjectPointOnSurf.hxx>
#include <GeomAPI_ProjectPointOnCurve.hxx>

OCCTSurfaceProjectionResult OCCTFaceProjectPoint(OCCTFaceRef face,
                                                  double px, double py, double pz) {
    OCCTSurfaceProjectionResult result = {};
    result.isValid = false;
    if (!face) return result;

    try {
        Handle(Geom_Surface) surface = BRep_Tool::Surface(face->face);
        if (surface.IsNull()) return result;

        double uMin, uMax, vMin, vMax;
        BRepTools::UVBounds(face->face, uMin, uMax, vMin, vMax);

        GeomAPI_ProjectPointOnSurf proj(gp_Pnt(px, py, pz), surface,
                                         uMin, uMax, vMin, vMax,
                                         Precision::Confusion());
        if (proj.NbPoints() == 0) return result;

        gp_Pnt nearest = proj.NearestPoint();
        result.px = nearest.X();
        result.py = nearest.Y();
        result.pz = nearest.Z();
        proj.LowerDistanceParameters(result.u, result.v);
        result.distance = proj.LowerDistance();
        result.isValid = true;
        return result;
    } catch (...) {
        return result;
    }
}

int32_t OCCTFaceProjectPointAll(OCCTFaceRef face,
                                 double px, double py, double pz,
                                 OCCTSurfaceProjectionResult* results,
                                 int32_t maxResults) {
    if (!face || !results || maxResults <= 0) return 0;

    try {
        Handle(Geom_Surface) surface = BRep_Tool::Surface(face->face);
        if (surface.IsNull()) return 0;

        double uMin, uMax, vMin, vMax;
        BRepTools::UVBounds(face->face, uMin, uMax, vMin, vMax);

        GeomAPI_ProjectPointOnSurf proj(gp_Pnt(px, py, pz), surface,
                                         uMin, uMax, vMin, vMax,
                                         Precision::Confusion());

        int32_t count = std::min((int32_t)proj.NbPoints(), maxResults);
        for (int32_t i = 0; i < count; i++) {
            gp_Pnt pnt = proj.Point(i + 1);
            results[i].px = pnt.X();
            results[i].py = pnt.Y();
            results[i].pz = pnt.Z();
            proj.Parameters(i + 1, results[i].u, results[i].v);
            results[i].distance = proj.Distance(i + 1);
            results[i].isValid = true;
        }
        return count;
    } catch (...) {
        return 0;
    }
}

OCCTCurveProjectionResult OCCTEdgeProjectPoint(OCCTEdgeRef edge,
                                                double px, double py, double pz) {
    OCCTCurveProjectionResult result = {};
    result.isValid = false;
    if (!edge) return result;

    try {
        Standard_Real first, last;
        Handle(Geom_Curve) curve = BRep_Tool::Curve(edge->edge, first, last);
        if (curve.IsNull()) return result;

        GeomAPI_ProjectPointOnCurve proj(gp_Pnt(px, py, pz), curve, first, last);
        if (proj.NbPoints() == 0) return result;

        gp_Pnt nearest = proj.NearestPoint();
        result.px = nearest.X();
        result.py = nearest.Y();
        result.pz = nearest.Z();
        result.parameter = proj.LowerDistanceParameter();
        result.distance = proj.LowerDistance();
        result.isValid = true;
        return result;
    } catch (...) {
        return result;
    }
}


// MARK: - Shape Proximity (v0.18.0)

#include <BRepExtrema_ShapeProximity.hxx>
#include <BRepExtrema_OverlapTool.hxx>

int32_t OCCTShapeProximity(OCCTShapeRef shape1, OCCTShapeRef shape2,
                            double tolerance,
                            OCCTFaceProximityPair* outPairs,
                            int32_t maxPairs) {
    if (!shape1 || !shape2 || !outPairs || maxPairs <= 0) return 0;

    try {
        // BRepExtrema_ShapeProximity requires triangulated shapes
        BRepMesh_IncrementalMesh mesh1(shape1->shape, 0.1);
        BRepMesh_IncrementalMesh mesh2(shape2->shape, 0.1);

        BRepExtrema_ShapeProximity prox(shape1->shape, shape2->shape, (Standard_Real)tolerance);
        prox.Perform();

        if (!prox.IsDone()) return 0;

        // Get overlapping face indices
        const auto& overlaps1 = prox.OverlapSubShapes1();
        int32_t count = 0;

        for (NCollection_DataMap<int, TColStd_PackedMapOfInteger>::Iterator it(overlaps1);
             it.More() && count < maxPairs; it.Next()) {
            int32_t face1Idx = (int32_t)it.Key();
            const TColStd_PackedMapOfInteger& face2Set = it.Value();
            for (TColStd_PackedMapOfInteger::Iterator it2(face2Set);
                 it2.More() && count < maxPairs; it2.Next()) {
                outPairs[count].face1Index = face1Idx;
                outPairs[count].face2Index = (int32_t)it2.Key();
                count++;
            }
        }
        return count;
    } catch (...) {
        return 0;
    }
}

#include <BOPAlgo_CheckerSI.hxx>
#include <BOPAlgo_Alerts.hxx>

bool OCCTShapeSelfIntersects(OCCTShapeRef shape) {
    if (!shape) return false;

    try {
        BOPAlgo_CheckerSI checker;
        TopTools_ListOfShape shapes;
        shapes.Append(shape->shape);
        checker.SetArguments(shapes);
        checker.Perform();
        return checker.HasErrors();
    } catch (...) {
        return false;
    }
}


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


// MARK: - Curve3D: 3D Parametric Curves (v0.19.0)

#include <Geom_Curve.hxx>
#include <Geom_Line.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Ellipse.hxx>
#include <Geom_Parabola.hxx>
#include <Geom_Hyperbola.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_BezierCurve.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <Geom_OffsetCurve.hxx>
#include <GC_MakeSegment.hxx>
#include <GC_MakeArcOfCircle.hxx>
#include <GC_MakeCircle.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <GeomAPI_Interpolate.hxx>
#include <GeomConvert.hxx>
#include <GeomConvert_BSplineCurveToBezierCurve.hxx>
#include <GeomConvert_CompCurveToBSplineCurve.hxx>
#include <GeomConvert_ApproxCurve.hxx>
#include <GCPnts_TangentialDeflection.hxx>
#include <GCPnts_UniformAbscissa.hxx>
#include <GCPnts_UniformDeflection.hxx>
#include <Bnd_Box.hxx>
#include <BndLib_Add3dCurve.hxx>
#include <CPnts_AbscissaPoint.hxx>
#include <TColgp_HArray1OfPnt.hxx>

struct OCCTCurve3D {
    Handle(Geom_Curve) curve;

    OCCTCurve3D() {}
    OCCTCurve3D(const Handle(Geom_Curve)& c) : curve(c) {}
};

void OCCTCurve3DRelease(OCCTCurve3DRef c) {
    delete c;
}

// Properties

void OCCTCurve3DGetDomain(OCCTCurve3DRef c, double* first, double* last) {
    if (!c || c->curve.IsNull() || !first || !last) return;
    *first = c->curve->FirstParameter();
    *last = c->curve->LastParameter();
}

bool OCCTCurve3DIsClosed(OCCTCurve3DRef c) {
    if (!c || c->curve.IsNull()) return false;
    return c->curve->IsClosed() == Standard_True;
}

bool OCCTCurve3DIsPeriodic(OCCTCurve3DRef c) {
    if (!c || c->curve.IsNull()) return false;
    return c->curve->IsPeriodic() == Standard_True;
}

double OCCTCurve3DGetPeriod(OCCTCurve3DRef c) {
    if (!c || c->curve.IsNull()) return 0.0;
    if (!c->curve->IsPeriodic()) return 0.0;
    return c->curve->Period();
}

// Evaluation

void OCCTCurve3DGetPoint(OCCTCurve3DRef c, double u,
                         double* x, double* y, double* z) {
    if (!c || c->curve.IsNull() || !x || !y || !z) return;
    gp_Pnt p = c->curve->Value(u);
    *x = p.X(); *y = p.Y(); *z = p.Z();
}

void OCCTCurve3DD1(OCCTCurve3DRef c, double u,
                   double* px, double* py, double* pz,
                   double* vx, double* vy, double* vz) {
    if (!c || c->curve.IsNull() || !px || !py || !pz || !vx || !vy || !vz) return;
    gp_Pnt p; gp_Vec v;
    c->curve->D1(u, p, v);
    *px = p.X(); *py = p.Y(); *pz = p.Z();
    *vx = v.X(); *vy = v.Y(); *vz = v.Z();
}

void OCCTCurve3DD2(OCCTCurve3DRef c, double u,
                   double* px, double* py, double* pz,
                   double* v1x, double* v1y, double* v1z,
                   double* v2x, double* v2y, double* v2z) {
    if (!c || c->curve.IsNull() || !px || !py || !pz ||
        !v1x || !v1y || !v1z || !v2x || !v2y || !v2z) return;
    gp_Pnt p; gp_Vec v1, v2;
    c->curve->D2(u, p, v1, v2);
    *px = p.X(); *py = p.Y(); *pz = p.Z();
    *v1x = v1.X(); *v1y = v1.Y(); *v1z = v1.Z();
    *v2x = v2.X(); *v2y = v2.Y(); *v2z = v2.Z();
}

// Primitive Curves

OCCTCurve3DRef OCCTCurve3DCreateLine(double px, double py, double pz,
                                      double dx, double dy, double dz) {
    try {
        gp_Pnt origin(px, py, pz);
        gp_Dir dir(dx, dy, dz);
        Handle(Geom_Line) line = new Geom_Line(origin, dir);
        return new OCCTCurve3D(line);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DCreateSegment(double p1x, double p1y, double p1z,
                                         double p2x, double p2y, double p2z) {
    try {
        gp_Pnt pt1(p1x, p1y, p1z);
        gp_Pnt pt2(p2x, p2y, p2z);
        if (pt1.Distance(pt2) < Precision::Confusion()) return nullptr;
        GC_MakeSegment maker(pt1, pt2);
        if (!maker.IsDone()) return nullptr;
        return new OCCTCurve3D(maker.Value());
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DCreateCircle(double cx, double cy, double cz,
                                        double nx, double ny, double nz,
                                        double radius) {
    try {
        if (radius <= 0) return nullptr;
        gp_Pnt center(cx, cy, cz);
        gp_Dir normal(nx, ny, nz);
        gp_Ax2 axis(center, normal);
        Handle(Geom_Circle) circle = new Geom_Circle(axis, radius);
        return new OCCTCurve3D(circle);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DCreateArcOfCircle(double p1x, double p1y, double p1z,
                                             double p2x, double p2y, double p2z,
                                             double p3x, double p3y, double p3z) {
    try {
        GC_MakeArcOfCircle maker(gp_Pnt(p1x, p1y, p1z),
                                  gp_Pnt(p2x, p2y, p2z),
                                  gp_Pnt(p3x, p3y, p3z));
        if (!maker.IsDone()) return nullptr;
        return new OCCTCurve3D(maker.Value());
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DCreateArc3Points(double p1x, double p1y, double p1z,
                                            double pmx, double pmy, double pmz,
                                            double p2x, double p2y, double p2z) {
    try {
        GC_MakeArcOfCircle maker(gp_Pnt(p1x, p1y, p1z),
                                  gp_Pnt(pmx, pmy, pmz),
                                  gp_Pnt(p2x, p2y, p2z));
        if (!maker.IsDone()) return nullptr;
        return new OCCTCurve3D(maker.Value());
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DCreateEllipse(double cx, double cy, double cz,
                                         double nx, double ny, double nz,
                                         double majorR, double minorR) {
    try {
        if (majorR <= 0 || minorR <= 0 || minorR > majorR) return nullptr;
        gp_Ax2 axis(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz));
        Handle(Geom_Ellipse) ellipse = new Geom_Ellipse(axis, majorR, minorR);
        return new OCCTCurve3D(ellipse);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DCreateParabola(double cx, double cy, double cz,
                                          double nx, double ny, double nz,
                                          double focal) {
    try {
        if (focal <= 0) return nullptr;
        gp_Ax2 axis(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz));
        Handle(Geom_Parabola) parabola = new Geom_Parabola(axis, focal);
        return new OCCTCurve3D(parabola);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DCreateHyperbola(double cx, double cy, double cz,
                                           double nx, double ny, double nz,
                                           double majorR, double minorR) {
    try {
        if (majorR <= 0 || minorR <= 0) return nullptr;
        gp_Ax2 axis(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz));
        Handle(Geom_Hyperbola) hyp = new Geom_Hyperbola(axis, majorR, minorR);
        return new OCCTCurve3D(hyp);
    } catch (...) {
        return nullptr;
    }
}

// BSpline / Bezier / Interpolation

OCCTCurve3DRef OCCTCurve3DCreateBSpline(const double* poles, int32_t poleCount,
                                         const double* weights,
                                         const double* knots, int32_t knotCount,
                                         const int32_t* multiplicities, int32_t degree) {
    try {
        if (!poles || poleCount < 2 || !knots || knotCount < 2 || !multiplicities || degree < 1)
            return nullptr;

        TColgp_Array1OfPnt pArr(1, poleCount);
        for (int i = 0; i < poleCount; i++)
            pArr.SetValue(i + 1, gp_Pnt(poles[i*3], poles[i*3+1], poles[i*3+2]));

        TColStd_Array1OfReal kArr(1, knotCount);
        for (int i = 0; i < knotCount; i++)
            kArr.SetValue(i + 1, knots[i]);

        TColStd_Array1OfInteger mArr(1, knotCount);
        for (int i = 0; i < knotCount; i++)
            mArr.SetValue(i + 1, multiplicities[i]);

        Handle(Geom_BSplineCurve) bsp;
        if (weights) {
            TColStd_Array1OfReal wArr(1, poleCount);
            for (int i = 0; i < poleCount; i++)
                wArr.SetValue(i + 1, weights[i]);
            bsp = new Geom_BSplineCurve(pArr, wArr, kArr, mArr, degree);
        } else {
            bsp = new Geom_BSplineCurve(pArr, kArr, mArr, degree);
        }
        return new OCCTCurve3D(bsp);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DCreateBezier(const double* poles, int32_t poleCount,
                                        const double* weights) {
    try {
        if (!poles || poleCount < 2) return nullptr;

        TColgp_Array1OfPnt pArr(1, poleCount);
        for (int i = 0; i < poleCount; i++)
            pArr.SetValue(i + 1, gp_Pnt(poles[i*3], poles[i*3+1], poles[i*3+2]));

        Handle(Geom_BezierCurve) bez;
        if (weights) {
            TColStd_Array1OfReal wArr(1, poleCount);
            for (int i = 0; i < poleCount; i++)
                wArr.SetValue(i + 1, weights[i]);
            bez = new Geom_BezierCurve(pArr, wArr);
        } else {
            bez = new Geom_BezierCurve(pArr);
        }
        return new OCCTCurve3D(bez);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DInterpolate(const double* points, int32_t count,
                                       bool closed, double tolerance) {
    try {
        if (!points || count < 2) return nullptr;

        Handle(TColgp_HArray1OfPnt) pts = new TColgp_HArray1OfPnt(1, count);
        for (int i = 0; i < count; i++)
            pts->SetValue(i + 1, gp_Pnt(points[i*3], points[i*3+1], points[i*3+2]));

        GeomAPI_Interpolate interp(pts, closed ? Standard_True : Standard_False, tolerance);
        interp.Perform();
        if (!interp.IsDone()) return nullptr;

        return new OCCTCurve3D(interp.Curve());
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DInterpolateWithTangents(const double* points, int32_t count,
                                                   double stx, double sty, double stz,
                                                   double etx, double ety, double etz,
                                                   double tolerance) {
    try {
        if (!points || count < 2) return nullptr;

        Handle(TColgp_HArray1OfPnt) pts = new TColgp_HArray1OfPnt(1, count);
        for (int i = 0; i < count; i++)
            pts->SetValue(i + 1, gp_Pnt(points[i*3], points[i*3+1], points[i*3+2]));

        GeomAPI_Interpolate interp(pts, Standard_False, tolerance);
        gp_Vec startTan(stx, sty, stz);
        gp_Vec endTan(etx, ety, etz);
        interp.Load(startTan, endTan);
        interp.Perform();
        if (!interp.IsDone()) return nullptr;

        return new OCCTCurve3D(interp.Curve());
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DFitPoints(const double* points, int32_t count,
                                     int32_t minDeg, int32_t maxDeg, double tolerance) {
    try {
        if (!points || count < 2) return nullptr;

        TColgp_Array1OfPnt pArr(1, count);
        for (int i = 0; i < count; i++)
            pArr.SetValue(i + 1, gp_Pnt(points[i*3], points[i*3+1], points[i*3+2]));

        GeomAPI_PointsToBSpline fitter(pArr, minDeg, maxDeg,
                                        GeomAbs_C2, tolerance);
        if (!fitter.IsDone()) return nullptr;

        return new OCCTCurve3D(fitter.Curve());
    } catch (...) {
        return nullptr;
    }
}

// BSpline queries

int32_t OCCTCurve3DGetPoleCount(OCCTCurve3DRef c) {
    if (!c || c->curve.IsNull()) return 0;
    try {
        Handle(Geom_BSplineCurve) bsp = Handle(Geom_BSplineCurve)::DownCast(c->curve);
        if (!bsp.IsNull()) return bsp->NbPoles();
        Handle(Geom_BezierCurve) bez = Handle(Geom_BezierCurve)::DownCast(c->curve);
        if (!bez.IsNull()) return bez->NbPoles();
        return 0;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTCurve3DGetPoles(OCCTCurve3DRef c, double* outXYZ) {
    if (!c || c->curve.IsNull() || !outXYZ) return 0;
    try {
        Handle(Geom_BSplineCurve) bsp = Handle(Geom_BSplineCurve)::DownCast(c->curve);
        if (!bsp.IsNull()) {
            int n = bsp->NbPoles();
            for (int i = 1; i <= n; i++) {
                gp_Pnt p = bsp->Pole(i);
                outXYZ[(i-1)*3] = p.X();
                outXYZ[(i-1)*3+1] = p.Y();
                outXYZ[(i-1)*3+2] = p.Z();
            }
            return n;
        }
        Handle(Geom_BezierCurve) bez = Handle(Geom_BezierCurve)::DownCast(c->curve);
        if (!bez.IsNull()) {
            int n = bez->NbPoles();
            for (int i = 1; i <= n; i++) {
                gp_Pnt p = bez->Pole(i);
                outXYZ[(i-1)*3] = p.X();
                outXYZ[(i-1)*3+1] = p.Y();
                outXYZ[(i-1)*3+2] = p.Z();
            }
            return n;
        }
        return 0;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTCurve3DGetDegree(OCCTCurve3DRef c) {
    if (!c || c->curve.IsNull()) return -1;
    try {
        Handle(Geom_BSplineCurve) bsp = Handle(Geom_BSplineCurve)::DownCast(c->curve);
        if (!bsp.IsNull()) return bsp->Degree();
        Handle(Geom_BezierCurve) bez = Handle(Geom_BezierCurve)::DownCast(c->curve);
        if (!bez.IsNull()) return bez->Degree();
        return -1;
    } catch (...) {
        return -1;
    }
}

// Operations

OCCTCurve3DRef OCCTCurve3DTrim(OCCTCurve3DRef c, double u1, double u2) {
    if (!c || c->curve.IsNull()) return nullptr;
    try {
        Handle(Geom_TrimmedCurve) trimmed = new Geom_TrimmedCurve(c->curve, u1, u2);
        return new OCCTCurve3D(trimmed);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DReversed(OCCTCurve3DRef c) {
    if (!c || c->curve.IsNull()) return nullptr;
    try {
        Handle(Geom_Curve) rev = Handle(Geom_Curve)::DownCast(c->curve->Reversed());
        if (rev.IsNull()) return nullptr;
        return new OCCTCurve3D(rev);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DTranslate(OCCTCurve3DRef c, double dx, double dy, double dz) {
    if (!c || c->curve.IsNull()) return nullptr;
    try {
        Handle(Geom_Curve) copy = Handle(Geom_Curve)::DownCast(c->curve->Copy());
        gp_Trsf t;
        t.SetTranslation(gp_Vec(dx, dy, dz));
        copy->Transform(t);
        return new OCCTCurve3D(copy);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DRotate(OCCTCurve3DRef c,
                                  double axisOx, double axisOy, double axisOz,
                                  double axisDx, double axisDy, double axisDz,
                                  double angle) {
    if (!c || c->curve.IsNull()) return nullptr;
    try {
        Handle(Geom_Curve) copy = Handle(Geom_Curve)::DownCast(c->curve->Copy());
        gp_Ax1 axis(gp_Pnt(axisOx, axisOy, axisOz), gp_Dir(axisDx, axisDy, axisDz));
        gp_Trsf t;
        t.SetRotation(axis, angle);
        copy->Transform(t);
        return new OCCTCurve3D(copy);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DScale(OCCTCurve3DRef c,
                                 double cx, double cy, double cz, double factor) {
    if (!c || c->curve.IsNull()) return nullptr;
    try {
        Handle(Geom_Curve) copy = Handle(Geom_Curve)::DownCast(c->curve->Copy());
        gp_Trsf t;
        t.SetScale(gp_Pnt(cx, cy, cz), factor);
        copy->Transform(t);
        return new OCCTCurve3D(copy);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DMirrorPoint(OCCTCurve3DRef c,
                                       double px, double py, double pz) {
    if (!c || c->curve.IsNull()) return nullptr;
    try {
        Handle(Geom_Curve) copy = Handle(Geom_Curve)::DownCast(c->curve->Copy());
        gp_Trsf t;
        t.SetMirror(gp_Pnt(px, py, pz));
        copy->Transform(t);
        return new OCCTCurve3D(copy);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DMirrorAxis(OCCTCurve3DRef c,
                                      double px, double py, double pz,
                                      double dx, double dy, double dz) {
    if (!c || c->curve.IsNull()) return nullptr;
    try {
        Handle(Geom_Curve) copy = Handle(Geom_Curve)::DownCast(c->curve->Copy());
        gp_Ax1 axis(gp_Pnt(px, py, pz), gp_Dir(dx, dy, dz));
        gp_Trsf t;
        t.SetMirror(axis);
        copy->Transform(t);
        return new OCCTCurve3D(copy);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DMirrorPlane(OCCTCurve3DRef c,
                                       double px, double py, double pz,
                                       double nx, double ny, double nz) {
    if (!c || c->curve.IsNull()) return nullptr;
    try {
        Handle(Geom_Curve) copy = Handle(Geom_Curve)::DownCast(c->curve->Copy());
        gp_Ax2 plane(gp_Pnt(px, py, pz), gp_Dir(nx, ny, nz));
        gp_Trsf t;
        t.SetMirror(plane);
        copy->Transform(t);
        return new OCCTCurve3D(copy);
    } catch (...) {
        return nullptr;
    }
}

double OCCTCurve3DGetLength(OCCTCurve3DRef c) {
    if (!c || c->curve.IsNull()) return -1.0;
    try {
        GeomAdaptor_Curve adaptor(c->curve);
        return CPnts_AbscissaPoint::Length(adaptor);
    } catch (...) {
        return -1.0;
    }
}

double OCCTCurve3DGetLengthBetween(OCCTCurve3DRef c, double u1, double u2) {
    if (!c || c->curve.IsNull()) return -1.0;
    try {
        GeomAdaptor_Curve adaptor(c->curve);
        return CPnts_AbscissaPoint::Length(adaptor, u1, u2);
    } catch (...) {
        return -1.0;
    }
}

// Conversion (GeomConvert)

OCCTCurve3DRef OCCTCurve3DToBSpline(OCCTCurve3DRef c) {
    if (!c || c->curve.IsNull()) return nullptr;
    try {
        Handle(Geom_BSplineCurve) bsp = GeomConvert::CurveToBSplineCurve(c->curve);
        if (bsp.IsNull()) return nullptr;
        return new OCCTCurve3D(bsp);
    } catch (...) {
        return nullptr;
    }
}

int32_t OCCTCurve3DBSplineToBeziers(OCCTCurve3DRef c,
                                     OCCTCurve3DRef* out, int32_t max) {
    if (!c || c->curve.IsNull() || !out || max <= 0) return 0;
    try {
        Handle(Geom_BSplineCurve) bsp = Handle(Geom_BSplineCurve)::DownCast(c->curve);
        if (bsp.IsNull()) {
            bsp = GeomConvert::CurveToBSplineCurve(c->curve);
            if (bsp.IsNull()) return 0;
        }

        GeomConvert_BSplineCurveToBezierCurve converter(bsp);
        int32_t n = std::min((int32_t)converter.NbArcs(), max);
        for (int32_t i = 0; i < n; i++) {
            Handle(Geom_BezierCurve) arc = converter.Arc(i + 1);
            out[i] = new OCCTCurve3D(arc);
        }
        return n;
    } catch (...) {
        return 0;
    }
}

void OCCTCurve3DFreeArray(OCCTCurve3DRef* curves, int32_t count) {
    if (!curves) return;
    for (int32_t i = 0; i < count; i++) {
        delete curves[i];
        curves[i] = nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DJoinToBSpline(const OCCTCurve3DRef* curves, int32_t count,
                                         double tolerance) {
    if (!curves || count < 1) return nullptr;
    try {
        if (!curves[0] || curves[0]->curve.IsNull()) return nullptr;

        Handle(Geom_BSplineCurve) first = GeomConvert::CurveToBSplineCurve(curves[0]->curve);
        if (first.IsNull()) return nullptr;

        GeomConvert_CompCurveToBSplineCurve joiner(first);
        for (int32_t i = 1; i < count; i++) {
            if (!curves[i] || curves[i]->curve.IsNull()) continue;
            Handle(Geom_BSplineCurve) bsp = GeomConvert::CurveToBSplineCurve(curves[i]->curve);
            if (!bsp.IsNull()) {
                joiner.Add(bsp, tolerance);
            }
        }
        return new OCCTCurve3D(joiner.BSplineCurve());
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DApproximate(OCCTCurve3DRef c, double tolerance,
                                       int32_t continuity, int32_t maxSegments,
                                       int32_t maxDegree) {
    if (!c || c->curve.IsNull()) return nullptr;
    try {
        GeomAbs_Shape cont = GeomAbs_C2;
        switch (continuity) {
            case 0: cont = GeomAbs_C0; break;
            case 1: cont = GeomAbs_C1; break;
            case 2: cont = GeomAbs_C2; break;
            case 3: cont = GeomAbs_C3; break;
        }

        GeomConvert_ApproxCurve approx(c->curve, tolerance, cont, maxSegments, maxDegree);
        if (!approx.IsDone()) return nullptr;

        return new OCCTCurve3D(approx.Curve());
    } catch (...) {
        return nullptr;
    }
}

// Draw Methods

int32_t OCCTCurve3DDrawAdaptive(OCCTCurve3DRef c,
                                 double angularDefl, double chordalDefl,
                                 double* outXYZ, int32_t maxPoints) {
    if (!c || c->curve.IsNull() || !outXYZ || maxPoints <= 0) return 0;
    try {
        GeomAdaptor_Curve adaptor(c->curve);
        GCPnts_TangentialDeflection sampler(adaptor, angularDefl, chordalDefl);
        int32_t n = std::min((int32_t)sampler.NbPoints(), maxPoints);
        for (int32_t i = 0; i < n; i++) {
            gp_Pnt p = sampler.Value(i + 1);
            outXYZ[i*3] = p.X();
            outXYZ[i*3+1] = p.Y();
            outXYZ[i*3+2] = p.Z();
        }
        return n;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTCurve3DDrawUniform(OCCTCurve3DRef c,
                                int32_t pointCount, double* outXYZ) {
    if (!c || c->curve.IsNull() || !outXYZ || pointCount <= 0) return 0;
    try {
        GeomAdaptor_Curve adaptor(c->curve);
        GCPnts_UniformAbscissa sampler(adaptor, pointCount);
        if (!sampler.IsDone()) return 0;
        int32_t n = sampler.NbPoints();
        for (int32_t i = 0; i < n; i++) {
            double u = sampler.Parameter(i + 1);
            gp_Pnt p = adaptor.Value(u);
            outXYZ[i*3] = p.X();
            outXYZ[i*3+1] = p.Y();
            outXYZ[i*3+2] = p.Z();
        }
        return n;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTCurve3DDrawDeflection(OCCTCurve3DRef c, double deflection,
                                   double* outXYZ, int32_t maxPoints) {
    if (!c || c->curve.IsNull() || !outXYZ || maxPoints <= 0) return 0;
    try {
        GeomAdaptor_Curve adaptor(c->curve);
        GCPnts_UniformDeflection sampler(adaptor, deflection);
        if (!sampler.IsDone()) return 0;
        int32_t n = std::min((int32_t)sampler.NbPoints(), maxPoints);
        for (int32_t i = 0; i < n; i++) {
            gp_Pnt p = sampler.Value(i + 1);
            outXYZ[i*3] = p.X();
            outXYZ[i*3+1] = p.Y();
            outXYZ[i*3+2] = p.Z();
        }
        return n;
    } catch (...) {
        return 0;
    }
}

// Local Properties

double OCCTCurve3DGetCurvature(OCCTCurve3DRef c, double u) {
    if (!c || c->curve.IsNull()) return 0.0;
    try {
        GeomLProp_CLProps props(c->curve, 2, Precision::Confusion());
        props.SetParameter(u);
        if (!props.IsTangentDefined()) return 0.0;
        return props.Curvature();
    } catch (...) {
        return 0.0;
    }
}

bool OCCTCurve3DGetTangent(OCCTCurve3DRef c, double u,
                            double* tx, double* ty, double* tz) {
    if (!c || c->curve.IsNull() || !tx || !ty || !tz) return false;
    try {
        GeomLProp_CLProps props(c->curve, 1, Precision::Confusion());
        props.SetParameter(u);
        if (!props.IsTangentDefined()) return false;
        gp_Dir dir;
        props.Tangent(dir);
        *tx = dir.X(); *ty = dir.Y(); *tz = dir.Z();
        return true;
    } catch (...) {
        return false;
    }
}

bool OCCTCurve3DGetNormal(OCCTCurve3DRef c, double u,
                           double* nx, double* ny, double* nz) {
    if (!c || c->curve.IsNull() || !nx || !ny || !nz) return false;
    try {
        GeomLProp_CLProps props(c->curve, 2, Precision::Confusion());
        props.SetParameter(u);
        if (!props.IsTangentDefined()) return false;
        gp_Dir dir;
        props.Normal(dir);
        *nx = dir.X(); *ny = dir.Y(); *nz = dir.Z();
        return true;
    } catch (...) {
        return false;
    }
}

bool OCCTCurve3DGetCenterOfCurvature(OCCTCurve3DRef c, double u,
                                      double* cx, double* cy, double* cz) {
    if (!c || c->curve.IsNull() || !cx || !cy || !cz) return false;
    try {
        GeomLProp_CLProps props(c->curve, 2, Precision::Confusion());
        props.SetParameter(u);
        if (!props.IsTangentDefined()) return false;
        if (props.Curvature() < Precision::Confusion()) return false;
        gp_Pnt center;
        props.CentreOfCurvature(center);
        *cx = center.X(); *cy = center.Y(); *cz = center.Z();
        return true;
    } catch (...) {
        return false;
    }
}

double OCCTCurve3DGetTorsion(OCCTCurve3DRef c, double u) {
    if (!c || c->curve.IsNull()) return 0.0;
    try {
        gp_Pnt pnt;
        gp_Vec d1, d2, d3;
        c->curve->D3(u, pnt, d1, d2, d3);

        gp_Vec cross = d1.Crossed(d2);
        double crossMag2 = cross.SquareMagnitude();
        if (crossMag2 < Precision::Confusion()) return 0.0;
        return cross.Dot(d3) / crossMag2;
    } catch (...) {
        return 0.0;
    }
}

// Bounding Box

bool OCCTCurve3DGetBoundingBox(OCCTCurve3DRef c,
                                double* xMin, double* yMin, double* zMin,
                                double* xMax, double* yMax, double* zMax) {
    if (!c || c->curve.IsNull() || !xMin || !yMin || !zMin || !xMax || !yMax || !zMax)
        return false;
    try {
        GeomAdaptor_Curve adaptor(c->curve);
        Bnd_Box box;
        BndLib_Add3dCurve::Add(adaptor, 0.01, box);
        if (box.IsVoid()) return false;
        box.Get(*xMin, *yMin, *zMin, *xMax, *yMax, *zMax);
        return true;
    } catch (...) {
        return false;
    }
}

// ============================================================================
// MARK: - Surface: Parametric Surfaces (v0.20.0)
// ============================================================================

#include <Geom_Surface.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_ConicalSurface.hxx>
#include <Geom_SphericalSurface.hxx>
#include <Geom_ToroidalSurface.hxx>
#include <Geom_BezierSurface.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_RectangularTrimmedSurface.hxx>
#include <Geom_OffsetSurface.hxx>
#include <Geom_SurfaceOfLinearExtrusion.hxx>
#include <Geom_SurfaceOfRevolution.hxx>
#include <GeomFill_Pipe.hxx>
#include <GeomConvert_ApproxSurface.hxx>
#include <GeomAdaptor_Surface.hxx>
#include <BndLib_AddSurface.hxx>
#include <TColgp_Array2OfPnt.hxx>
#include <TColStd_Array2OfReal.hxx>
#include <gp_Cylinder.hxx>
#include <gp_Cone.hxx>
#include <gp_Sphere.hxx>
#include <gp_Torus.hxx>

struct OCCTSurface {
    Handle(Geom_Surface) surface;
    OCCTSurface() {}
    OCCTSurface(const Handle(Geom_Surface)& s) : surface(s) {}
};

void OCCTSurfaceRelease(OCCTSurfaceRef s) {
    delete s;
}

// Properties

void OCCTSurfaceGetDomain(OCCTSurfaceRef s,
                           double* uMin, double* uMax,
                           double* vMin, double* vMax) {
    if (!s || s->surface.IsNull() || !uMin || !uMax || !vMin || !vMax) return;
    s->surface->Bounds(*uMin, *uMax, *vMin, *vMax);
}

bool OCCTSurfaceIsUClosed(OCCTSurfaceRef s) {
    if (!s || s->surface.IsNull()) return false;
    return s->surface->IsUClosed() == Standard_True;
}

bool OCCTSurfaceIsVClosed(OCCTSurfaceRef s) {
    if (!s || s->surface.IsNull()) return false;
    return s->surface->IsVClosed() == Standard_True;
}

bool OCCTSurfaceIsUPeriodic(OCCTSurfaceRef s) {
    if (!s || s->surface.IsNull()) return false;
    return s->surface->IsUPeriodic() == Standard_True;
}

bool OCCTSurfaceIsVPeriodic(OCCTSurfaceRef s) {
    if (!s || s->surface.IsNull()) return false;
    return s->surface->IsVPeriodic() == Standard_True;
}

double OCCTSurfaceGetUPeriod(OCCTSurfaceRef s) {
    if (!s || s->surface.IsNull() || !s->surface->IsUPeriodic()) return 0.0;
    return s->surface->UPeriod();
}

double OCCTSurfaceGetVPeriod(OCCTSurfaceRef s) {
    if (!s || s->surface.IsNull() || !s->surface->IsVPeriodic()) return 0.0;
    return s->surface->VPeriod();
}

// Evaluation

void OCCTSurfaceGetPoint(OCCTSurfaceRef s, double u, double v,
                          double* x, double* y, double* z) {
    if (!s || s->surface.IsNull() || !x || !y || !z) return;
    gp_Pnt p;
    s->surface->D0(u, v, p);
    *x = p.X(); *y = p.Y(); *z = p.Z();
}

void OCCTSurfaceD1(OCCTSurfaceRef s, double u, double v,
                    double* px, double* py, double* pz,
                    double* dux, double* duy, double* duz,
                    double* dvx, double* dvy, double* dvz) {
    if (!s || s->surface.IsNull() ||
        !px || !py || !pz || !dux || !duy || !duz || !dvx || !dvy || !dvz) return;
    gp_Pnt p;
    gp_Vec du, dv;
    s->surface->D1(u, v, p, du, dv);
    *px = p.X(); *py = p.Y(); *pz = p.Z();
    *dux = du.X(); *duy = du.Y(); *duz = du.Z();
    *dvx = dv.X(); *dvy = dv.Y(); *dvz = dv.Z();
}

void OCCTSurfaceD2(OCCTSurfaceRef s, double u, double v,
                    double* px, double* py, double* pz,
                    double* d1ux, double* d1uy, double* d1uz,
                    double* d1vx, double* d1vy, double* d1vz,
                    double* d2ux, double* d2uy, double* d2uz,
                    double* d2vx, double* d2vy, double* d2vz,
                    double* d2uvx, double* d2uvy, double* d2uvz) {
    if (!s || s->surface.IsNull() ||
        !px || !py || !pz ||
        !d1ux || !d1uy || !d1uz || !d1vx || !d1vy || !d1vz ||
        !d2ux || !d2uy || !d2uz || !d2vx || !d2vy || !d2vz ||
        !d2uvx || !d2uvy || !d2uvz) return;
    gp_Pnt p;
    gp_Vec d1u, d1v, d2u, d2v, d2uv;
    s->surface->D2(u, v, p, d1u, d1v, d2u, d2v, d2uv);
    *px = p.X(); *py = p.Y(); *pz = p.Z();
    *d1ux = d1u.X(); *d1uy = d1u.Y(); *d1uz = d1u.Z();
    *d1vx = d1v.X(); *d1vy = d1v.Y(); *d1vz = d1v.Z();
    *d2ux = d2u.X(); *d2uy = d2u.Y(); *d2uz = d2u.Z();
    *d2vx = d2v.X(); *d2vy = d2v.Y(); *d2vz = d2v.Z();
    *d2uvx = d2uv.X(); *d2uvy = d2uv.Y(); *d2uvz = d2uv.Z();
}

bool OCCTSurfaceGetNormal(OCCTSurfaceRef s, double u, double v,
                           double* nx, double* ny, double* nz) {
    if (!s || s->surface.IsNull() || !nx || !ny || !nz) return false;
    try {
        GeomLProp_SLProps props(s->surface, u, v, 1, Precision::Confusion());
        if (!props.IsNormalDefined()) return false;
        gp_Dir n = props.Normal();
        *nx = n.X(); *ny = n.Y(); *nz = n.Z();
        return true;
    } catch (...) {
        return false;
    }
}

// Analytic Surfaces

OCCTSurfaceRef OCCTSurfaceCreatePlane(double px, double py, double pz,
                                       double nx, double ny, double nz) {
    try {
        gp_Pnt origin(px, py, pz);
        gp_Dir normal(nx, ny, nz);
        Handle(Geom_Plane) plane = new Geom_Plane(origin, normal);
        return new OCCTSurface(plane);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceCreateCylinder(double px, double py, double pz,
                                          double dx, double dy, double dz,
                                          double radius) {
    try {
        if (radius <= 0) return nullptr;
        gp_Pnt origin(px, py, pz);
        gp_Dir dir(dx, dy, dz);
        gp_Ax3 axis(origin, dir);
        Handle(Geom_CylindricalSurface) cyl = new Geom_CylindricalSurface(axis, radius);
        return new OCCTSurface(cyl);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceCreateCone(double px, double py, double pz,
                                      double dx, double dy, double dz,
                                      double radius, double semiAngle) {
    try {
        if (radius < 0) return nullptr;
        gp_Pnt origin(px, py, pz);
        gp_Dir dir(dx, dy, dz);
        gp_Ax3 axis(origin, dir);
        Handle(Geom_ConicalSurface) cone = new Geom_ConicalSurface(axis, semiAngle, radius);
        return new OCCTSurface(cone);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceCreateSphere(double cx, double cy, double cz,
                                        double radius) {
    try {
        if (radius <= 0) return nullptr;
        gp_Pnt center(cx, cy, cz);
        gp_Ax3 axis(center, gp::DZ());
        Handle(Geom_SphericalSurface) sphere = new Geom_SphericalSurface(axis, radius);
        return new OCCTSurface(sphere);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceCreateTorus(double px, double py, double pz,
                                       double dx, double dy, double dz,
                                       double majorRadius, double minorRadius) {
    try {
        if (majorRadius <= 0 || minorRadius <= 0 || minorRadius >= majorRadius)
            return nullptr;
        gp_Pnt origin(px, py, pz);
        gp_Dir dir(dx, dy, dz);
        gp_Ax3 axis(origin, dir);
        Handle(Geom_ToroidalSurface) torus = new Geom_ToroidalSurface(axis, majorRadius, minorRadius);
        return new OCCTSurface(torus);
    } catch (...) {
        return nullptr;
    }
}

// Swept Surfaces

OCCTSurfaceRef OCCTSurfaceCreateExtrusion(OCCTCurve3DRef profile,
                                           double dx, double dy, double dz) {
    if (!profile || profile->curve.IsNull()) return nullptr;
    try {
        gp_Dir dir(dx, dy, dz);
        Handle(Geom_SurfaceOfLinearExtrusion) ext =
            new Geom_SurfaceOfLinearExtrusion(profile->curve, dir);
        return new OCCTSurface(ext);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceCreateRevolution(OCCTCurve3DRef meridian,
                                            double px, double py, double pz,
                                            double dx, double dy, double dz) {
    if (!meridian || meridian->curve.IsNull()) return nullptr;
    try {
        gp_Pnt origin(px, py, pz);
        gp_Dir dir(dx, dy, dz);
        gp_Ax1 axis(origin, dir);
        Handle(Geom_SurfaceOfRevolution) rev =
            new Geom_SurfaceOfRevolution(meridian->curve, axis);
        return new OCCTSurface(rev);
    } catch (...) {
        return nullptr;
    }
}

// Freeform Surfaces

OCCTSurfaceRef OCCTSurfaceCreateBezier(const double* poles,
                                        int32_t uCount, int32_t vCount,
                                        const double* weights) {
    if (!poles || uCount < 2 || vCount < 2) return nullptr;
    try {
        TColgp_Array2OfPnt poleArray(1, uCount, 1, vCount);
        for (int32_t i = 0; i < uCount; i++) {
            for (int32_t j = 0; j < vCount; j++) {
                int idx = (i * vCount + j) * 3;
                poleArray.SetValue(i + 1, j + 1,
                    gp_Pnt(poles[idx], poles[idx+1], poles[idx+2]));
            }
        }
        Handle(Geom_BezierSurface) bez;
        if (weights) {
            TColStd_Array2OfReal wArr(1, uCount, 1, vCount);
            for (int32_t i = 0; i < uCount; i++) {
                for (int32_t j = 0; j < vCount; j++) {
                    wArr.SetValue(i + 1, j + 1, weights[i * vCount + j]);
                }
            }
            bez = new Geom_BezierSurface(poleArray, wArr);
        } else {
            bez = new Geom_BezierSurface(poleArray);
        }
        return new OCCTSurface(bez);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceCreateBSpline(const double* poles,
                                         int32_t uPoleCount, int32_t vPoleCount,
                                         const double* weights,
                                         const double* uKnots, int32_t uKnotCount,
                                         const double* vKnots, int32_t vKnotCount,
                                         const int32_t* uMults, const int32_t* vMults,
                                         int32_t uDegree, int32_t vDegree) {
    if (!poles || !uKnots || !vKnots || !uMults || !vMults) return nullptr;
    if (uPoleCount < 2 || vPoleCount < 2 || uKnotCount < 2 || vKnotCount < 2) return nullptr;
    try {
        TColgp_Array2OfPnt poleArray(1, uPoleCount, 1, vPoleCount);
        for (int32_t i = 0; i < uPoleCount; i++) {
            for (int32_t j = 0; j < vPoleCount; j++) {
                int idx = (i * vPoleCount + j) * 3;
                poleArray.SetValue(i + 1, j + 1,
                    gp_Pnt(poles[idx], poles[idx+1], poles[idx+2]));
            }
        }

        TColStd_Array1OfReal uKnotArr(1, uKnotCount);
        for (int32_t i = 0; i < uKnotCount; i++) uKnotArr.SetValue(i + 1, uKnots[i]);
        TColStd_Array1OfReal vKnotArr(1, vKnotCount);
        for (int32_t i = 0; i < vKnotCount; i++) vKnotArr.SetValue(i + 1, vKnots[i]);

        TColStd_Array1OfInteger uMultArr(1, uKnotCount);
        for (int32_t i = 0; i < uKnotCount; i++) uMultArr.SetValue(i + 1, uMults[i]);
        TColStd_Array1OfInteger vMultArr(1, vKnotCount);
        for (int32_t i = 0; i < vKnotCount; i++) vMultArr.SetValue(i + 1, vMults[i]);

        Handle(Geom_BSplineSurface) bsp;
        if (weights) {
            TColStd_Array2OfReal wArr(1, uPoleCount, 1, vPoleCount);
            for (int32_t i = 0; i < uPoleCount; i++) {
                for (int32_t j = 0; j < vPoleCount; j++) {
                    wArr.SetValue(i + 1, j + 1, weights[i * vPoleCount + j]);
                }
            }
            bsp = new Geom_BSplineSurface(poleArray, wArr,
                uKnotArr, vKnotArr, uMultArr, vMultArr, uDegree, vDegree);
        } else {
            bsp = new Geom_BSplineSurface(poleArray,
                uKnotArr, vKnotArr, uMultArr, vMultArr, uDegree, vDegree);
        }
        return new OCCTSurface(bsp);
    } catch (...) {
        return nullptr;
    }
}

// Operations

OCCTSurfaceRef OCCTSurfaceTrim(OCCTSurfaceRef s,
                                double u1, double u2, double v1, double v2) {
    if (!s || s->surface.IsNull()) return nullptr;
    try {
        Handle(Geom_RectangularTrimmedSurface) trimmed =
            new Geom_RectangularTrimmedSurface(s->surface, u1, u2, v1, v2);
        return new OCCTSurface(trimmed);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceOffset(OCCTSurfaceRef s, double distance) {
    if (!s || s->surface.IsNull()) return nullptr;
    try {
        Handle(Geom_OffsetSurface) offset =
            new Geom_OffsetSurface(s->surface, distance);
        return new OCCTSurface(offset);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceTranslate(OCCTSurfaceRef s,
                                     double dx, double dy, double dz) {
    if (!s || s->surface.IsNull()) return nullptr;
    try {
        Handle(Geom_Surface) copy = Handle(Geom_Surface)::DownCast(s->surface->Copy());
        gp_Trsf trsf;
        trsf.SetTranslation(gp_Vec(dx, dy, dz));
        copy->Transform(trsf);
        return new OCCTSurface(copy);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceRotate(OCCTSurfaceRef s,
                                  double axOx, double axOy, double axOz,
                                  double axDx, double axDy, double axDz,
                                  double angle) {
    if (!s || s->surface.IsNull()) return nullptr;
    try {
        Handle(Geom_Surface) copy = Handle(Geom_Surface)::DownCast(s->surface->Copy());
        gp_Trsf trsf;
        trsf.SetRotation(gp_Ax1(gp_Pnt(axOx, axOy, axOz), gp_Dir(axDx, axDy, axDz)), angle);
        copy->Transform(trsf);
        return new OCCTSurface(copy);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceScale(OCCTSurfaceRef s,
                                 double cx, double cy, double cz, double factor) {
    if (!s || s->surface.IsNull()) return nullptr;
    try {
        Handle(Geom_Surface) copy = Handle(Geom_Surface)::DownCast(s->surface->Copy());
        gp_Trsf trsf;
        trsf.SetScale(gp_Pnt(cx, cy, cz), factor);
        copy->Transform(trsf);
        return new OCCTSurface(copy);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceMirrorPlane(OCCTSurfaceRef s,
                                       double px, double py, double pz,
                                       double nx, double ny, double nz) {
    if (!s || s->surface.IsNull()) return nullptr;
    try {
        Handle(Geom_Surface) copy = Handle(Geom_Surface)::DownCast(s->surface->Copy());
        gp_Trsf trsf;
        trsf.SetMirror(gp_Ax2(gp_Pnt(px, py, pz), gp_Dir(nx, ny, nz)));
        copy->Transform(trsf);
        return new OCCTSurface(copy);
    } catch (...) {
        return nullptr;
    }
}

// Conversion

OCCTSurfaceRef OCCTSurfaceToBSpline(OCCTSurfaceRef s) {
    if (!s || s->surface.IsNull()) return nullptr;
    try {
        Handle(Geom_BSplineSurface) bsp = GeomConvert::SurfaceToBSplineSurface(s->surface);
        if (bsp.IsNull()) return nullptr;
        return new OCCTSurface(bsp);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceApproximate(OCCTSurfaceRef s, double tolerance,
                                       int32_t continuity, int32_t maxSegments,
                                       int32_t maxDegree) {
    if (!s || s->surface.IsNull()) return nullptr;
    try {
        GeomAbs_Shape cont = GeomAbs_C2;
        switch (continuity) {
            case 0: cont = GeomAbs_C0; break;
            case 1: cont = GeomAbs_C1; break;
            case 2: cont = GeomAbs_C2; break;
            case 3: cont = GeomAbs_C3; break;
        }
        GeomConvert_ApproxSurface approx(s->surface, tolerance,
                                          cont, cont, maxDegree, maxDegree, maxSegments, 0);
        if (!approx.HasResult()) return nullptr;
        return new OCCTSurface(approx.Surface());
    } catch (...) {
        return nullptr;
    }
}

// Iso Curves

OCCTCurve3DRef OCCTSurfaceUIso(OCCTSurfaceRef s, double u) {
    if (!s || s->surface.IsNull()) return nullptr;
    try {
        Handle(Geom_Curve) iso = s->surface->UIso(u);
        if (iso.IsNull()) return nullptr;
        return new OCCTCurve3D(iso);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTSurfaceVIso(OCCTSurfaceRef s, double v) {
    if (!s || s->surface.IsNull()) return nullptr;
    try {
        Handle(Geom_Curve) iso = s->surface->VIso(v);
        if (iso.IsNull()) return nullptr;
        return new OCCTCurve3D(iso);
    } catch (...) {
        return nullptr;
    }
}

// Pipe Surface

OCCTSurfaceRef OCCTSurfaceCreatePipe(OCCTCurve3DRef path, double radius) {
    if (!path || path->curve.IsNull() || radius <= 0) return nullptr;
    try {
        GeomFill_Pipe pipe(path->curve, radius);
        pipe.Perform(Standard_True, Standard_False);
        Handle(Geom_Surface) result = pipe.Surface();
        if (result.IsNull()) return nullptr;
        return new OCCTSurface(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceCreatePipeWithSection(OCCTCurve3DRef path,
                                                 OCCTCurve3DRef section) {
    if (!path || path->curve.IsNull() || !section || section->curve.IsNull())
        return nullptr;
    try {
        GeomFill_Pipe pipe(path->curve, section->curve);
        pipe.Perform(Standard_True, Standard_False);
        Handle(Geom_Surface) result = pipe.Surface();
        if (result.IsNull()) return nullptr;
        return new OCCTSurface(result);
    } catch (...) {
        return nullptr;
    }
}

// Draw Methods

int32_t OCCTSurfaceDrawGrid(OCCTSurfaceRef s,
                             int32_t uCount, int32_t vCount,
                             int32_t pointsPerLine,
                             double* outXYZ, int32_t maxPoints,
                             int32_t* outLineLengths, int32_t maxLines) {
    if (!s || s->surface.IsNull() || !outXYZ || !outLineLengths ||
        maxPoints <= 0 || maxLines <= 0) return 0;
    try {
        double uMin, uMax, vMin, vMax;
        s->surface->Bounds(uMin, uMax, vMin, vMax);

        // Clamp infinite bounds
        if (uMin < -1e6) uMin = -100;
        if (uMax >  1e6) uMax = 100;
        if (vMin < -1e6) vMin = -100;
        if (vMax >  1e6) vMax = 100;

        int32_t totalPoints = 0;
        int32_t lineIdx = 0;

        // U-iso lines (constant U, varying V)
        for (int32_t i = 0; i < uCount && lineIdx < maxLines; i++) {
            double u = uMin + (uMax - uMin) * i / (uCount > 1 ? (uCount - 1) : 1);
            int32_t ptsInLine = 0;
            for (int32_t j = 0; j < pointsPerLine && totalPoints < maxPoints; j++) {
                double v = vMin + (vMax - vMin) * j / (pointsPerLine > 1 ? (pointsPerLine - 1) : 1);
                gp_Pnt p;
                s->surface->D0(u, v, p);
                outXYZ[totalPoints * 3]     = p.X();
                outXYZ[totalPoints * 3 + 1] = p.Y();
                outXYZ[totalPoints * 3 + 2] = p.Z();
                totalPoints++;
                ptsInLine++;
            }
            outLineLengths[lineIdx++] = ptsInLine;
        }

        // V-iso lines (constant V, varying U)
        for (int32_t j = 0; j < vCount && lineIdx < maxLines; j++) {
            double v = vMin + (vMax - vMin) * j / (vCount > 1 ? (vCount - 1) : 1);
            int32_t ptsInLine = 0;
            for (int32_t i = 0; i < pointsPerLine && totalPoints < maxPoints; i++) {
                double u = uMin + (uMax - uMin) * i / (pointsPerLine > 1 ? (pointsPerLine - 1) : 1);
                gp_Pnt p;
                s->surface->D0(u, v, p);
                outXYZ[totalPoints * 3]     = p.X();
                outXYZ[totalPoints * 3 + 1] = p.Y();
                outXYZ[totalPoints * 3 + 2] = p.Z();
                totalPoints++;
                ptsInLine++;
            }
            outLineLengths[lineIdx++] = ptsInLine;
        }

        return totalPoints;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTSurfaceDrawMesh(OCCTSurfaceRef s,
                             int32_t uCount, int32_t vCount,
                             double* outXYZ) {
    if (!s || s->surface.IsNull() || !outXYZ || uCount < 2 || vCount < 2) return 0;
    try {
        double uMin, uMax, vMin, vMax;
        s->surface->Bounds(uMin, uMax, vMin, vMax);

        // Clamp infinite bounds
        if (uMin < -1e6) uMin = -100;
        if (uMax >  1e6) uMax = 100;
        if (vMin < -1e6) vMin = -100;
        if (vMax >  1e6) vMax = 100;

        int32_t idx = 0;
        for (int32_t i = 0; i < uCount; i++) {
            double u = uMin + (uMax - uMin) * i / (uCount - 1);
            for (int32_t j = 0; j < vCount; j++) {
                double v = vMin + (vMax - vMin) * j / (vCount - 1);
                gp_Pnt p;
                s->surface->D0(u, v, p);
                outXYZ[idx * 3]     = p.X();
                outXYZ[idx * 3 + 1] = p.Y();
                outXYZ[idx * 3 + 2] = p.Z();
                idx++;
            }
        }
        return idx;
    } catch (...) {
        return 0;
    }
}

// Local Properties

double OCCTSurfaceGetGaussianCurvature(OCCTSurfaceRef s, double u, double v) {
    if (!s || s->surface.IsNull()) return 0.0;
    try {
        GeomLProp_SLProps props(s->surface, u, v, 2, Precision::Confusion());
        if (!props.IsCurvatureDefined()) return 0.0;
        return props.GaussianCurvature();
    } catch (...) {
        return 0.0;
    }
}

double OCCTSurfaceGetMeanCurvature(OCCTSurfaceRef s, double u, double v) {
    if (!s || s->surface.IsNull()) return 0.0;
    try {
        GeomLProp_SLProps props(s->surface, u, v, 2, Precision::Confusion());
        if (!props.IsCurvatureDefined()) return 0.0;
        return props.MeanCurvature();
    } catch (...) {
        return 0.0;
    }
}

bool OCCTSurfaceGetPrincipalCurvatures(OCCTSurfaceRef s, double u, double v,
                                        double* kMin, double* kMax,
                                        double* d1x, double* d1y, double* d1z,
                                        double* d2x, double* d2y, double* d2z) {
    if (!s || s->surface.IsNull() || !kMin || !kMax ||
        !d1x || !d1y || !d1z || !d2x || !d2y || !d2z) return false;
    try {
        GeomLProp_SLProps props(s->surface, u, v, 2, Precision::Confusion());
        if (!props.IsCurvatureDefined()) return false;
        *kMin = props.MinCurvature();
        *kMax = props.MaxCurvature();
        gp_Dir dir1, dir2;
        props.CurvatureDirections(dir1, dir2);
        *d1x = dir1.X(); *d1y = dir1.Y(); *d1z = dir1.Z();
        *d2x = dir2.X(); *d2y = dir2.Y(); *d2z = dir2.Z();
        return true;
    } catch (...) {
        return false;
    }
}

// Bounding Box

bool OCCTSurfaceGetBoundingBox(OCCTSurfaceRef s,
                                double* xMin, double* yMin, double* zMin,
                                double* xMax, double* yMax, double* zMax) {
    if (!s || s->surface.IsNull() || !xMin || !yMin || !zMin || !xMax || !yMax || !zMax)
        return false;
    try {
        GeomAdaptor_Surface adaptor(s->surface);
        Bnd_Box box;
        BndLib_AddSurface::Add(adaptor, 0.01, box);
        if (box.IsVoid()) return false;
        box.Get(*xMin, *yMin, *zMin, *xMax, *yMax, *zMax);
        return true;
    } catch (...) {
        return false;
    }
}

// BSpline Queries

int32_t OCCTSurfaceGetUPoleCount(OCCTSurfaceRef s) {
    if (!s || s->surface.IsNull()) return 0;
    Handle(Geom_BSplineSurface) bsp = Handle(Geom_BSplineSurface)::DownCast(s->surface);
    if (bsp.IsNull()) {
        Handle(Geom_BezierSurface) bez = Handle(Geom_BezierSurface)::DownCast(s->surface);
        if (!bez.IsNull()) return bez->NbUPoles();
        return 0;
    }
    return bsp->NbUPoles();
}

int32_t OCCTSurfaceGetVPoleCount(OCCTSurfaceRef s) {
    if (!s || s->surface.IsNull()) return 0;
    Handle(Geom_BSplineSurface) bsp = Handle(Geom_BSplineSurface)::DownCast(s->surface);
    if (bsp.IsNull()) {
        Handle(Geom_BezierSurface) bez = Handle(Geom_BezierSurface)::DownCast(s->surface);
        if (!bez.IsNull()) return bez->NbVPoles();
        return 0;
    }
    return bsp->NbVPoles();
}

int32_t OCCTSurfaceGetPoles(OCCTSurfaceRef s, double* outXYZ) {
    if (!s || s->surface.IsNull() || !outXYZ) return 0;
    try {
        Handle(Geom_BSplineSurface) bsp = Handle(Geom_BSplineSurface)::DownCast(s->surface);
        Handle(Geom_BezierSurface) bez = Handle(Geom_BezierSurface)::DownCast(s->surface);

        int uCount = 0, vCount = 0;
        if (!bsp.IsNull()) {
            uCount = bsp->NbUPoles();
            vCount = bsp->NbVPoles();
            int idx = 0;
            for (int i = 1; i <= uCount; i++) {
                for (int j = 1; j <= vCount; j++) {
                    gp_Pnt p = bsp->Pole(i, j);
                    outXYZ[idx*3]     = p.X();
                    outXYZ[idx*3 + 1] = p.Y();
                    outXYZ[idx*3 + 2] = p.Z();
                    idx++;
                }
            }
            return idx;
        } else if (!bez.IsNull()) {
            uCount = bez->NbUPoles();
            vCount = bez->NbVPoles();
            int idx = 0;
            for (int i = 1; i <= uCount; i++) {
                for (int j = 1; j <= vCount; j++) {
                    gp_Pnt p = bez->Pole(i, j);
                    outXYZ[idx*3]     = p.X();
                    outXYZ[idx*3 + 1] = p.Y();
                    outXYZ[idx*3 + 2] = p.Z();
                    idx++;
                }
            }
            return idx;
        }
        return 0;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTSurfaceGetUDegree(OCCTSurfaceRef s) {
    if (!s || s->surface.IsNull()) return 0;
    Handle(Geom_BSplineSurface) bsp = Handle(Geom_BSplineSurface)::DownCast(s->surface);
    if (bsp.IsNull()) {
        Handle(Geom_BezierSurface) bez = Handle(Geom_BezierSurface)::DownCast(s->surface);
        if (!bez.IsNull()) return bez->UDegree();
        return 0;
    }
    return bsp->UDegree();
}

int32_t OCCTSurfaceGetVDegree(OCCTSurfaceRef s) {
    if (!s || s->surface.IsNull()) return 0;
    Handle(Geom_BSplineSurface) bsp = Handle(Geom_BSplineSurface)::DownCast(s->surface);
    if (bsp.IsNull()) {
        Handle(Geom_BezierSurface) bez = Handle(Geom_BezierSurface)::DownCast(s->surface);
        if (!bez.IsNull()) return bez->VDegree();
        return 0;
    }
    return bsp->VDegree();
}

// ============================================================================
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
// MARK: - XDE GD&T / Dimension Tolerance (v0.21.0)
// ============================================================================

#include <XCAFDoc_DimTolTool.hxx>
#include <XCAFDoc_Dimension.hxx>
#include <XCAFDoc_GeomTolerance.hxx>
#include <XCAFDoc_Datum.hxx>
#include <XCAFDimTolObjects_DimensionObject.hxx>
#include <XCAFDimTolObjects_GeomToleranceObject.hxx>
#include <XCAFDimTolObjects_DatumObject.hxx>

int32_t OCCTDocumentGetDimensionCount(OCCTDocumentRef doc) {
    if (!doc || doc->doc.IsNull()) return 0;
    try {
        Handle(XCAFDoc_DimTolTool) dimTolTool =
            XCAFDoc_DimTolTool::Set(doc->doc->Main());
        TDF_LabelSequence labels;
        dimTolTool->GetDimensionLabels(labels);
        return (int32_t)labels.Length();
    } catch (...) {
        return 0;
    }
}

int32_t OCCTDocumentGetGeomToleranceCount(OCCTDocumentRef doc) {
    if (!doc || doc->doc.IsNull()) return 0;
    try {
        Handle(XCAFDoc_DimTolTool) dimTolTool =
            XCAFDoc_DimTolTool::Set(doc->doc->Main());
        TDF_LabelSequence labels;
        dimTolTool->GetGeomToleranceLabels(labels);
        return (int32_t)labels.Length();
    } catch (...) {
        return 0;
    }
}

int32_t OCCTDocumentGetDatumCount(OCCTDocumentRef doc) {
    if (!doc || doc->doc.IsNull()) return 0;
    try {
        Handle(XCAFDoc_DimTolTool) dimTolTool =
            XCAFDoc_DimTolTool::Set(doc->doc->Main());
        TDF_LabelSequence labels;
        dimTolTool->GetDatumLabels(labels);
        return (int32_t)labels.Length();
    } catch (...) {
        return 0;
    }
}

OCCTDimensionInfo OCCTDocumentGetDimensionInfo(OCCTDocumentRef doc, int32_t index) {
    OCCTDimensionInfo info = {};
    info.isValid = false;
    if (!doc || doc->doc.IsNull()) return info;
    try {
        Handle(XCAFDoc_DimTolTool) dimTolTool =
            XCAFDoc_DimTolTool::Set(doc->doc->Main());
        TDF_LabelSequence labels;
        dimTolTool->GetDimensionLabels(labels);
        if (index < 0 || index >= (int32_t)labels.Length()) return info;

        TDF_Label label = labels.Value(index + 1);
        Handle(XCAFDoc_Dimension) dimAttr;
        if (!label.FindAttribute(XCAFDoc_Dimension::GetID(), dimAttr)) return info;

        Handle(XCAFDimTolObjects_DimensionObject) dimObj = dimAttr->GetObject();
        if (dimObj.IsNull()) return info;

        info.type = (int32_t)dimObj->GetType();
        Handle(TColStd_HArray1OfReal) vals = dimObj->GetValues();
        if (!vals.IsNull() && vals->Length() > 0) {
            info.value = vals->Value(vals->Lower());
        }
        info.lowerTol = dimObj->GetLowerTolValue();
        info.upperTol = dimObj->GetUpperTolValue();
        info.isValid = true;
        return info;
    } catch (...) {
        return info;
    }
}

OCCTGeomToleranceInfo OCCTDocumentGetGeomToleranceInfo(OCCTDocumentRef doc, int32_t index) {
    OCCTGeomToleranceInfo info = {};
    info.isValid = false;
    if (!doc || doc->doc.IsNull()) return info;
    try {
        Handle(XCAFDoc_DimTolTool) dimTolTool =
            XCAFDoc_DimTolTool::Set(doc->doc->Main());
        TDF_LabelSequence labels;
        dimTolTool->GetGeomToleranceLabels(labels);
        if (index < 0 || index >= (int32_t)labels.Length()) return info;

        TDF_Label label = labels.Value(index + 1);
        Handle(XCAFDoc_GeomTolerance) tolAttr;
        if (!label.FindAttribute(XCAFDoc_GeomTolerance::GetID(), tolAttr)) return info;

        Handle(XCAFDimTolObjects_GeomToleranceObject) tolObj = tolAttr->GetObject();
        if (tolObj.IsNull()) return info;

        info.type = (int32_t)tolObj->GetType();
        info.value = tolObj->GetValue();
        info.isValid = true;
        return info;
    } catch (...) {
        return info;
    }
}

OCCTDatumInfo OCCTDocumentGetDatumInfo(OCCTDocumentRef doc, int32_t index) {
    OCCTDatumInfo info = {};
    info.isValid = false;
    memset(info.name, 0, sizeof(info.name));
    if (!doc || doc->doc.IsNull()) return info;
    try {
        Handle(XCAFDoc_DimTolTool) dimTolTool =
            XCAFDoc_DimTolTool::Set(doc->doc->Main());
        TDF_LabelSequence labels;
        dimTolTool->GetDatumLabels(labels);
        if (index < 0 || index >= (int32_t)labels.Length()) return info;

        TDF_Label label = labels.Value(index + 1);
        Handle(XCAFDoc_Datum) datumAttr;
        if (!label.FindAttribute(XCAFDoc_Datum::GetID(), datumAttr)) return info;

        Handle(XCAFDimTolObjects_DatumObject) datumObj = datumAttr->GetObject();
        if (datumObj.IsNull()) return info;

        Handle(TCollection_HAsciiString) hName = datumObj->GetName();
        if (!hName.IsNull() && hName->Length() > 0) {
            strncpy(info.name, hName->String().ToCString(),
                    std::min((int)sizeof(info.name) - 1, hName->Length()));
        }
        info.isValid = true;
        return info;
    } catch (...) {
        return info;
    }
}


// MARK: - ProjLib: Curve Projection onto Surfaces (v0.22.0)

#include <GeomProjLib.hxx>
#include <ProjLib_CompProjectedCurve.hxx>
#include <ProjLib_ProjectedCurve.hxx>
#include <ProjLib_ProjectOnPlane.hxx>
#include <Geom_Plane.hxx>

OCCTCurve2DRef OCCTSurfaceProjectCurve2D(OCCTSurfaceRef surface,
                                          OCCTCurve3DRef curve,
                                          double tolerance) {
    if (!surface || surface->surface.IsNull()) return nullptr;
    if (!curve || curve->curve.IsNull()) return nullptr;
    try {
        Standard_Real first = curve->curve->FirstParameter();
        Standard_Real last = curve->curve->LastParameter();
        Standard_Real tol = tolerance;
        Handle(Geom2d_Curve) result = GeomProjLib::Curve2d(
            curve->curve, first, last, surface->surface, tol);
        if (result.IsNull()) return nullptr;
        return new OCCTCurve2D(result);
    } catch (...) {
        return nullptr;
    }
}

int32_t OCCTSurfaceProjectCurveSegments(OCCTSurfaceRef surface,
                                         OCCTCurve3DRef curve,
                                         double tolerance,
                                         OCCTCurve2DRef* outCurves,
                                         int32_t maxCurves) {
    if (!surface || surface->surface.IsNull()) return 0;
    if (!curve || curve->curve.IsNull()) return 0;
    if (!outCurves || maxCurves <= 0) return 0;
    try {
        Handle(GeomAdaptor_Surface) surfAdaptor =
            new GeomAdaptor_Surface(surface->surface);
        Handle(GeomAdaptor_Curve) curveAdaptor =
            new GeomAdaptor_Curve(curve->curve);

        ProjLib_CompProjectedCurve comp(tolerance, surfAdaptor, curveAdaptor);
        comp.Perform();

        int32_t nbCurves = comp.NbCurves();
        int32_t count = 0;
        for (int32_t i = 1; i <= nbCurves && count < maxCurves; i++) {
            Handle(Geom2d_Curve) c2d = comp.GetResult2dC(i);
            if (!c2d.IsNull()) {
                outCurves[count] = new OCCTCurve2D(c2d);
                count++;
            }
        }
        return count;
    } catch (...) {
        return 0;
    }
}

OCCTCurve3DRef OCCTSurfaceProjectCurve3D(OCCTSurfaceRef surface,
                                          OCCTCurve3DRef curve) {
    if (!surface || surface->surface.IsNull()) return nullptr;
    if (!curve || curve->curve.IsNull()) return nullptr;
    try {
        Handle(Geom_Curve) result = GeomProjLib::Project(
            curve->curve, surface->surface);
        if (result.IsNull()) return nullptr;
        return new OCCTCurve3D(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve3DRef OCCTCurve3DProjectOnPlane(OCCTCurve3DRef curve,
                                          double oX, double oY, double oZ,
                                          double nX, double nY, double nZ,
                                          double dX, double dY, double dZ) {
    if (!curve || curve->curve.IsNull()) return nullptr;
    try {
        gp_Pnt origin(oX, oY, oZ);
        gp_Dir normal(nX, nY, nZ);
        gp_Dir direction(dX, dY, dZ);
        Handle(Geom_Plane) plane = new Geom_Plane(origin, normal);

        Handle(Geom_Curve) result = GeomProjLib::ProjectOnPlane(
            curve->curve, plane, direction, Standard_True);
        if (result.IsNull()) return nullptr;
        return new OCCTCurve3D(result);
    } catch (...) {
        return nullptr;
    }
}

bool OCCTSurfaceProjectPoint(OCCTSurfaceRef surface,
                              double px, double py, double pz,
                              double* u, double* v, double* distance) {
    if (!surface || surface->surface.IsNull()) return false;
    if (!u || !v || !distance) return false;
    try {
        GeomAPI_ProjectPointOnSurf proj(gp_Pnt(px, py, pz), surface->surface);
        if (!proj.IsDone() || proj.NbPoints() == 0) return false;
        proj.LowerDistanceParameters(*u, *v);
        *distance = proj.LowerDistance();
        return true;
    } catch (...) {
        return false;
    }
}


// MARK: - NLPlate: Advanced Plate Surfaces (v0.23.0)

#include <NLPlate_NLPlate.hxx>
#include <NLPlate_HPG0Constraint.hxx>
#include <NLPlate_HPG1Constraint.hxx>
#include <NLPlate_HPG0G1Constraint.hxx>
#include <Plate_D1.hxx>
#include <GeomPlate_BuildAveragePlane.hxx>
#include <GeomAPI_PointsToBSplineSurface.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>

OCCTShapeRef OCCTShapePlatePointsAdvanced(const double* points, int32_t pointCount,
                                           const int32_t* orders, int32_t degree,
                                           int32_t nbPtsOnCur, int32_t nbIter,
                                           double tolerance) {
    if (!points || pointCount < 3 || !orders) return nullptr;
    try {
        GeomPlate_BuildPlateSurface plateBuilder(degree, nbPtsOnCur, nbIter);

        for (int32_t i = 0; i < pointCount; i++) {
            gp_Pnt pt(points[i*3], points[i*3+1], points[i*3+2]);
            int32_t order = orders[i];
            if (order < 0) order = 0;
            if (order > 2) order = 2;
            Handle(GeomPlate_PointConstraint) constraint =
                new GeomPlate_PointConstraint(pt, order);
            plateBuilder.Add(constraint);
        }

        plateBuilder.Perform();
        if (!plateBuilder.IsDone()) return nullptr;

        Handle(GeomPlate_Surface) plateSurface = plateBuilder.Surface();
        if (plateSurface.IsNull()) return nullptr;

        GeomPlate_MakeApprox approx(plateSurface, tolerance, 1, 8, tolerance * 10, 0);
        Handle(Geom_BSplineSurface) bsplineSurf = approx.Surface();
        if (bsplineSurf.IsNull()) return nullptr;

        BRepBuilderAPI_MakeFace makeFace(bsplineSurf, tolerance);
        if (!makeFace.IsDone()) return nullptr;

        return new OCCTShape(makeFace.Face());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapePlateMixed(const double* points, const int32_t* pointOrders,
                                  int32_t pointCount,
                                  const OCCTWireRef* curves, const int32_t* curveOrders,
                                  int32_t curveCount,
                                  int32_t degree, double tolerance) {
    if (pointCount < 1 && curveCount < 1) return nullptr;
    try {
        GeomPlate_BuildPlateSurface plateBuilder(degree, 15, 2);

        // Add point constraints
        if (points && pointOrders) {
            for (int32_t i = 0; i < pointCount; i++) {
                gp_Pnt pt(points[i*3], points[i*3+1], points[i*3+2]);
                int32_t order = pointOrders[i];
                if (order < 0) order = 0;
                if (order > 2) order = 2;
                Handle(GeomPlate_PointConstraint) constraint =
                    new GeomPlate_PointConstraint(pt, order);
                plateBuilder.Add(constraint);
            }
        }

        // Add curve constraints
        if (curves && curveOrders) {
            for (int32_t i = 0; i < curveCount; i++) {
                if (!curves[i]) continue;
                int32_t order = curveOrders[i];
                if (order < 0) order = 0;
                if (order > 2) order = 2;

                for (TopExp_Explorer exp(curves[i]->wire, TopAbs_EDGE); exp.More(); exp.Next()) {
                    TopoDS_Edge edge = TopoDS::Edge(exp.Current());
                    BRepAdaptor_Curve adaptor(edge);
                    Handle(Adaptor3d_Curve) curve = new BRepAdaptor_Curve(adaptor);
                    Handle(GeomPlate_CurveConstraint) constraint =
                        new GeomPlate_CurveConstraint(curve, order);
                    plateBuilder.Add(constraint);
                }
            }
        }

        plateBuilder.Perform();
        if (!plateBuilder.IsDone()) return nullptr;

        Handle(GeomPlate_Surface) plateSurface = plateBuilder.Surface();
        if (plateSurface.IsNull()) return nullptr;

        GeomPlate_MakeApprox approx(plateSurface, tolerance, 1, 8, tolerance * 10, 0);
        Handle(Geom_BSplineSurface) bsplineSurf = approx.Surface();
        if (bsplineSurf.IsNull()) return nullptr;

        BRepBuilderAPI_MakeFace makeFace(bsplineSurf, tolerance);
        if (!makeFace.IsDone()) return nullptr;

        return new OCCTShape(makeFace.Face());
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfacePlateThrough(const double* points, int32_t pointCount,
                                        int32_t degree, double tolerance) {
    if (!points || pointCount < 3) return nullptr;
    try {
        GeomPlate_BuildPlateSurface plateBuilder(degree, 15, 2);

        for (int32_t i = 0; i < pointCount; i++) {
            gp_Pnt pt(points[i*3], points[i*3+1], points[i*3+2]);
            Handle(GeomPlate_PointConstraint) constraint =
                new GeomPlate_PointConstraint(pt, 0);
            plateBuilder.Add(constraint);
        }

        plateBuilder.Perform();
        if (!plateBuilder.IsDone()) return nullptr;

        Handle(GeomPlate_Surface) plateSurface = plateBuilder.Surface();
        if (plateSurface.IsNull()) return nullptr;

        GeomPlate_MakeApprox approx(plateSurface, tolerance, 1, 8, tolerance * 10, 0);
        Handle(Geom_BSplineSurface) bsplineSurf = approx.Surface();
        if (bsplineSurf.IsNull()) return nullptr;

        return new OCCTSurface(bsplineSurf);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceNLPlateG0(OCCTSurfaceRef initialSurface,
                                     const double* constraints, int32_t constraintCount,
                                     int32_t maxIter, double tolerance) {
    if (!initialSurface || initialSurface->surface.IsNull()) return nullptr;
    if (!constraints || constraintCount < 1) return nullptr;
    try {
        // NLPlate needs a bounded surface; if infinite, create a trimmed version
        Standard_Real u1, u2, v1, v2;
        initialSurface->surface->Bounds(u1, u2, v1, v2);

        Handle(Geom_Surface) workSurface = initialSurface->surface;
        bool needsTrim = Precision::IsNegativeInfinite(u1) || Precision::IsPositiveInfinite(u2) ||
                         Precision::IsNegativeInfinite(v1) || Precision::IsPositiveInfinite(v2);

        if (needsTrim) {
            // Find bounds from constraint points
            double minU = 1e30, maxU = -1e30, minV = 1e30, maxV = -1e30;
            for (int32_t i = 0; i < constraintCount; i++) {
                double cu = constraints[i * 5 + 0];
                double cv = constraints[i * 5 + 1];
                minU = std::min(minU, cu); maxU = std::max(maxU, cu);
                minV = std::min(minV, cv); maxV = std::max(maxV, cv);
            }
            // Extend domain beyond constraints
            double padU = std::max(10.0, (maxU - minU) * 0.5);
            double padV = std::max(10.0, (maxV - minV) * 0.5);
            u1 = minU - padU; u2 = maxU + padU;
            v1 = minV - padV; v2 = maxV + padV;

            workSurface = new Geom_RectangularTrimmedSurface(initialSurface->surface, u1, u2, v1, v2);
        }

        NLPlate_NLPlate solver(workSurface);

        for (int32_t i = 0; i < constraintCount; i++) {
            double u = constraints[i * 5 + 0];
            double v = constraints[i * 5 + 1];
            double tx = constraints[i * 5 + 2];
            double ty = constraints[i * 5 + 3];
            double tz = constraints[i * 5 + 4];

            gp_XY uv(u, v);
            gp_XYZ target(tx, ty, tz);
            Handle(NLPlate_HPG0Constraint) g0 = new NLPlate_HPG0Constraint(uv, target);
            solver.Load(g0);
        }

        solver.Solve2(maxIter);
        if (!solver.IsDone()) return nullptr;

        // Get working domain
        if (!needsTrim) {
            workSurface->Bounds(u1, u2, v1, v2);
            if (Precision::IsNegativeInfinite(u1)) u1 = -100.0;
            if (Precision::IsPositiveInfinite(u2)) u2 = 100.0;
            if (Precision::IsNegativeInfinite(v1)) v1 = -100.0;
            if (Precision::IsPositiveInfinite(v2)) v2 = 100.0;
        }

        // Sample the deformed surface and create BSpline approximation
        int nuPts = 20, nvPts = 20;
        TColgp_Array2OfPnt poles(1, nuPts, 1, nvPts);
        for (int iu = 1; iu <= nuPts; iu++) {
            double pu = u1 + (u2 - u1) * (iu - 1) / (nuPts - 1);
            for (int iv = 1; iv <= nvPts; iv++) {
                double pv = v1 + (v2 - v1) * (iv - 1) / (nvPts - 1);
                gp_XY uv(pu, pv);
                gp_XYZ disp = solver.Evaluate(uv);
                gp_Pnt origPt;
                workSurface->D0(pu, pv, origPt);
                gp_Pnt newPt(origPt.X() + disp.X(), origPt.Y() + disp.Y(), origPt.Z() + disp.Z());
                poles(iu, iv) = newPt;
            }
        }

        GeomAPI_PointsToBSplineSurface approx;
        approx.Init(poles, 3, 8, GeomAbs_C2, tolerance);
        Handle(Geom_BSplineSurface) result = approx.Surface();
        if (result.IsNull()) return nullptr;

        return new OCCTSurface(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceNLPlateG1(OCCTSurfaceRef initialSurface,
                                     const double* constraints, int32_t constraintCount,
                                     int32_t maxIter, double tolerance) {
    if (!initialSurface || initialSurface->surface.IsNull()) return nullptr;
    if (!constraints || constraintCount < 1) return nullptr;
    try {
        // NLPlate needs bounded surface
        Standard_Real u1, u2, v1, v2;
        initialSurface->surface->Bounds(u1, u2, v1, v2);

        Handle(Geom_Surface) workSurface = initialSurface->surface;
        bool needsTrim = Precision::IsNegativeInfinite(u1) || Precision::IsPositiveInfinite(u2) ||
                         Precision::IsNegativeInfinite(v1) || Precision::IsPositiveInfinite(v2);

        if (needsTrim) {
            double minU = 1e30, maxU = -1e30, minV = 1e30, maxV = -1e30;
            for (int32_t i = 0; i < constraintCount; i++) {
                double cu = constraints[i * 11 + 0];
                double cv = constraints[i * 11 + 1];
                minU = std::min(minU, cu); maxU = std::max(maxU, cu);
                minV = std::min(minV, cv); maxV = std::max(maxV, cv);
            }
            double padU = std::max(10.0, (maxU - minU) * 0.5);
            double padV = std::max(10.0, (maxV - minV) * 0.5);
            u1 = minU - padU; u2 = maxU + padU;
            v1 = minV - padV; v2 = maxV + padV;

            workSurface = new Geom_RectangularTrimmedSurface(initialSurface->surface, u1, u2, v1, v2);
        }

        NLPlate_NLPlate solver(workSurface);

        // constraints: flat (u, v, targetX, targetY, targetZ, d1uX, d1uY, d1uZ, d1vX, d1vY, d1vZ)
        for (int32_t i = 0; i < constraintCount; i++) {
            double u = constraints[i * 11 + 0];
            double v = constraints[i * 11 + 1];
            double tx = constraints[i * 11 + 2];
            double ty = constraints[i * 11 + 3];
            double tz = constraints[i * 11 + 4];
            double d1ux = constraints[i * 11 + 5];
            double d1uy = constraints[i * 11 + 6];
            double d1uz = constraints[i * 11 + 7];
            double d1vx = constraints[i * 11 + 8];
            double d1vy = constraints[i * 11 + 9];
            double d1vz = constraints[i * 11 + 10];

            gp_XY uv(u, v);
            gp_XYZ target(tx, ty, tz);
            gp_XYZ du(d1ux, d1uy, d1uz);
            gp_XYZ dv(d1vx, d1vy, d1vz);
            Plate_D1 d1(du, dv);
            Handle(NLPlate_HPG0G1Constraint) g0g1 = new NLPlate_HPG0G1Constraint(uv, target, d1);
            solver.Load(g0g1);
        }

        solver.Solve2(maxIter);
        if (!solver.IsDone()) return nullptr;

        if (!needsTrim) {
            workSurface->Bounds(u1, u2, v1, v2);
            if (Precision::IsNegativeInfinite(u1)) u1 = -100.0;
            if (Precision::IsPositiveInfinite(u2)) u2 = 100.0;
            if (Precision::IsNegativeInfinite(v1)) v1 = -100.0;
            if (Precision::IsPositiveInfinite(v2)) v2 = 100.0;
        }

        int nuPts = 20, nvPts = 20;
        TColgp_Array2OfPnt poles(1, nuPts, 1, nvPts);
        for (int iu = 1; iu <= nuPts; iu++) {
            double pu = u1 + (u2 - u1) * (iu - 1) / (nuPts - 1);
            for (int iv = 1; iv <= nvPts; iv++) {
                double pv = v1 + (v2 - v1) * (iv - 1) / (nvPts - 1);
                gp_XY uv(pu, pv);
                gp_XYZ disp = solver.Evaluate(uv);
                gp_Pnt origPt;
                workSurface->D0(pu, pv, origPt);
                gp_Pnt newPt(origPt.X() + disp.X(), origPt.Y() + disp.Y(), origPt.Z() + disp.Z());
                poles(iu, iv) = newPt;
            }
        }

        GeomAPI_PointsToBSplineSurface approx;
        approx.Init(poles, 3, 8, GeomAbs_C2, tolerance);
        Handle(Geom_BSplineSurface) result = approx.Surface();
        if (result.IsNull()) return nullptr;

        return new OCCTSurface(result);
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
// MARK: - AIS Annotations & Measurements (v0.26.0)
// ============================================================

#include <PrsDim_LengthDimension.hxx>
#include <PrsDim_RadiusDimension.hxx>
#include <PrsDim_AngleDimension.hxx>
#include <PrsDim_DiameterDimension.hxx>
#include <PrsDim_Dimension.hxx>
#include <AIS_TextLabel.hxx>
#include <TCollection_ExtendedString.hxx>
#include <TCollection_AsciiString.hxx>

struct OCCTDimension {
    Handle(PrsDim_Dimension) dim;
    int kind; // OCCTDimensionKind
};

struct OCCTTextLabel {
    Handle(AIS_TextLabel) label;
};

struct OCCTPointCloud {
    std::vector<double> coords;  // xyz triplets
    std::vector<float> colors;   // rgb triplets (empty if uncolored)
    int32_t count;
    double minBound[3];
    double maxBound[3];
};

// Helper: compute a plane containing the line from p1 to p2
static gp_Pln computePlaneForPoints(const gp_Pnt& p1, const gp_Pnt& p2) {
    gp_Vec lineDir(p1, p2);
    if (lineDir.Magnitude() < 1e-10) {
        return gp_Pln(p1, gp::DZ());
    }
    gp_Vec up(0, 0, 1);
    if (lineDir.IsParallel(up, 1e-6)) {
        up = gp_Vec(0, 1, 0);
    }
    gp_Vec normal = lineDir.Crossed(up);
    return gp_Pln(p1, gp_Dir(normal));
}

// --- Dimension creation ---

OCCTDimensionRef OCCTDimensionCreateLengthFromPoints(
    double p1x, double p1y, double p1z,
    double p2x, double p2y, double p2z)
{
    try {
        gp_Pnt p1(p1x, p1y, p1z);
        gp_Pnt p2(p2x, p2y, p2z);
        gp_Pln plane = computePlaneForPoints(p1, p2);
        Handle(PrsDim_LengthDimension) dim = new PrsDim_LengthDimension(p1, p2, plane);
        auto* result = new OCCTDimension();
        result->dim = dim;
        result->kind = OCCTDimensionKindLength;
        return result;
    } catch (...) {
        return nullptr;
    }
}

OCCTDimensionRef OCCTDimensionCreateLengthFromEdge(OCCTShapeRef edge) {
    if (!edge) return nullptr;
    try {
        TopoDS_Shape& shape = edge->shape;
        if (shape.ShapeType() != TopAbs_EDGE) return nullptr;
        TopoDS_Edge e = TopoDS::Edge(shape);

        // Get vertices for plane computation
        TopoDS_Vertex v1, v2;
        TopExp::Vertices(e, v1, v2);
        if (v1.IsNull() || v2.IsNull()) return nullptr;
        gp_Pnt p1 = BRep_Tool::Pnt(v1);
        gp_Pnt p2 = BRep_Tool::Pnt(v2);
        gp_Pln plane = computePlaneForPoints(p1, p2);

        Handle(PrsDim_LengthDimension) dim = new PrsDim_LengthDimension(e, plane);
        auto* result = new OCCTDimension();
        result->dim = dim;
        result->kind = OCCTDimensionKindLength;
        return result;
    } catch (...) {
        return nullptr;
    }
}

OCCTDimensionRef OCCTDimensionCreateLengthFromFaces(
    OCCTShapeRef face1, OCCTShapeRef face2)
{
    if (!face1 || !face2) return nullptr;
    try {
        TopoDS_Shape& s1 = face1->shape;
        TopoDS_Shape& s2 = face2->shape;
        if (s1.ShapeType() != TopAbs_FACE || s2.ShapeType() != TopAbs_FACE) return nullptr;
        TopoDS_Face f1 = TopoDS::Face(s1);
        TopoDS_Face f2 = TopoDS::Face(s2);

        Handle(PrsDim_LengthDimension) dim = new PrsDim_LengthDimension(f1, f2);
        auto* result = new OCCTDimension();
        result->dim = dim;
        result->kind = OCCTDimensionKindLength;
        return result;
    } catch (...) {
        return nullptr;
    }
}

OCCTDimensionRef OCCTDimensionCreateRadiusFromShape(OCCTShapeRef shape) {
    if (!shape) return nullptr;
    try {
        Handle(PrsDim_RadiusDimension) dim = new PrsDim_RadiusDimension(shape->shape);
        auto* result = new OCCTDimension();
        result->dim = dim;
        result->kind = OCCTDimensionKindRadius;
        return result;
    } catch (...) {
        return nullptr;
    }
}

OCCTDimensionRef OCCTDimensionCreateAngleFromEdges(
    OCCTShapeRef edge1, OCCTShapeRef edge2)
{
    if (!edge1 || !edge2) return nullptr;
    try {
        TopoDS_Shape& s1 = edge1->shape;
        TopoDS_Shape& s2 = edge2->shape;
        if (s1.ShapeType() != TopAbs_EDGE || s2.ShapeType() != TopAbs_EDGE) return nullptr;
        TopoDS_Edge e1 = TopoDS::Edge(s1);
        TopoDS_Edge e2 = TopoDS::Edge(s2);

        Handle(PrsDim_AngleDimension) dim = new PrsDim_AngleDimension(e1, e2);
        auto* result = new OCCTDimension();
        result->dim = dim;
        result->kind = OCCTDimensionKindAngle;
        return result;
    } catch (...) {
        return nullptr;
    }
}

OCCTDimensionRef OCCTDimensionCreateAngleFromPoints(
    double p1x, double p1y, double p1z,
    double cx, double cy, double cz,
    double p2x, double p2y, double p2z)
{
    try {
        gp_Pnt p1(p1x, p1y, p1z);
        gp_Pnt center(cx, cy, cz);
        gp_Pnt p2(p2x, p2y, p2z);

        Handle(PrsDim_AngleDimension) dim = new PrsDim_AngleDimension(p1, center, p2);
        auto* result = new OCCTDimension();
        result->dim = dim;
        result->kind = OCCTDimensionKindAngle;
        return result;
    } catch (...) {
        return nullptr;
    }
}

OCCTDimensionRef OCCTDimensionCreateAngleFromFaces(
    OCCTShapeRef face1, OCCTShapeRef face2)
{
    if (!face1 || !face2) return nullptr;
    try {
        TopoDS_Shape& s1 = face1->shape;
        TopoDS_Shape& s2 = face2->shape;
        if (s1.ShapeType() != TopAbs_FACE || s2.ShapeType() != TopAbs_FACE) return nullptr;
        TopoDS_Face f1 = TopoDS::Face(s1);
        TopoDS_Face f2 = TopoDS::Face(s2);

        Handle(PrsDim_AngleDimension) dim = new PrsDim_AngleDimension(f1, f2);
        auto* result = new OCCTDimension();
        result->dim = dim;
        result->kind = OCCTDimensionKindAngle;
        return result;
    } catch (...) {
        return nullptr;
    }
}

OCCTDimensionRef OCCTDimensionCreateDiameterFromShape(OCCTShapeRef shape) {
    if (!shape) return nullptr;
    try {
        Handle(PrsDim_DiameterDimension) dim = new PrsDim_DiameterDimension(shape->shape);
        auto* result = new OCCTDimension();
        result->dim = dim;
        result->kind = OCCTDimensionKindDiameter;
        return result;
    } catch (...) {
        return nullptr;
    }
}

// --- Dimension common functions ---

void OCCTDimensionRelease(OCCTDimensionRef dim) {
    delete dim;
}

double OCCTDimensionGetValue(OCCTDimensionRef dim) {
    if (!dim || dim->dim.IsNull()) return 0.0;
    try {
        return dim->dim->GetValue();
    } catch (...) {
        return 0.0;
    }
}

bool OCCTDimensionGetGeometry(OCCTDimensionRef dim, OCCTDimensionGeometry* out) {
    if (!dim || !out || dim->dim.IsNull()) return false;
    try {
        memset(out, 0, sizeof(OCCTDimensionGeometry));
        out->kind = dim->kind;
        out->value = dim->dim->GetValue();
        out->isValid = dim->dim->IsValid();

        switch (dim->kind) {
            case OCCTDimensionKindLength: {
                Handle(PrsDim_LengthDimension) ld =
                    Handle(PrsDim_LengthDimension)::DownCast(dim->dim);
                if (ld.IsNull()) return false;
                gp_Pnt fp = ld->FirstPoint();
                gp_Pnt sp = ld->SecondPoint();
                out->firstPoint[0] = fp.X(); out->firstPoint[1] = fp.Y(); out->firstPoint[2] = fp.Z();
                out->secondPoint[0] = sp.X(); out->secondPoint[1] = sp.Y(); out->secondPoint[2] = sp.Z();
                gp_Pnt mid((fp.X()+sp.X())/2, (fp.Y()+sp.Y())/2, (fp.Z()+sp.Z())/2);
                out->textPosition[0] = mid.X(); out->textPosition[1] = mid.Y(); out->textPosition[2] = mid.Z();
                break;
            }
            case OCCTDimensionKindRadius: {
                Handle(PrsDim_RadiusDimension) rd =
                    Handle(PrsDim_RadiusDimension)::DownCast(dim->dim);
                if (rd.IsNull()) return false;
                gp_Circ circ = rd->Circle();
                gp_Pnt center = circ.Location();
                gp_Pnt anchor = rd->AnchorPoint();
                out->firstPoint[0] = anchor.X(); out->firstPoint[1] = anchor.Y(); out->firstPoint[2] = anchor.Z();
                out->centerPoint[0] = center.X(); out->centerPoint[1] = center.Y(); out->centerPoint[2] = center.Z();
                gp_Dir axis = circ.Axis().Direction();
                out->circleNormal[0] = axis.X(); out->circleNormal[1] = axis.Y(); out->circleNormal[2] = axis.Z();
                out->circleRadius = circ.Radius();
                gp_Pnt mid((center.X()+anchor.X())/2, (center.Y()+anchor.Y())/2, (center.Z()+anchor.Z())/2);
                out->textPosition[0] = mid.X(); out->textPosition[1] = mid.Y(); out->textPosition[2] = mid.Z();
                break;
            }
            case OCCTDimensionKindAngle: {
                Handle(PrsDim_AngleDimension) ad =
                    Handle(PrsDim_AngleDimension)::DownCast(dim->dim);
                if (ad.IsNull()) return false;
                gp_Pnt fp = ad->FirstPoint();
                gp_Pnt sp = ad->SecondPoint();
                gp_Pnt cp = ad->CenterPoint();
                out->firstPoint[0] = fp.X(); out->firstPoint[1] = fp.Y(); out->firstPoint[2] = fp.Z();
                out->secondPoint[0] = sp.X(); out->secondPoint[1] = sp.Y(); out->secondPoint[2] = sp.Z();
                out->centerPoint[0] = cp.X(); out->centerPoint[1] = cp.Y(); out->centerPoint[2] = cp.Z();
                // Text position on arc bisector
                gp_Vec v1(cp, fp); gp_Vec v2(cp, sp);
                if (v1.Magnitude() > 1e-10 && v2.Magnitude() > 1e-10) {
                    v1.Normalize(); v2.Normalize();
                    gp_Vec bisector = v1 + v2;
                    if (bisector.Magnitude() > 1e-10) {
                        bisector.Normalize();
                        double dist = fp.Distance(cp) * 0.7;
                        gp_Pnt textPt = cp.Translated(bisector * dist);
                        out->textPosition[0] = textPt.X(); out->textPosition[1] = textPt.Y(); out->textPosition[2] = textPt.Z();
                    }
                }
                break;
            }
            case OCCTDimensionKindDiameter: {
                Handle(PrsDim_DiameterDimension) dd =
                    Handle(PrsDim_DiameterDimension)::DownCast(dim->dim);
                if (dd.IsNull()) return false;
                gp_Circ circ = dd->Circle();
                gp_Pnt center = circ.Location();
                gp_Pnt anchor = dd->AnchorPoint();
                // Diameter line: from anchor through center to opposite side
                gp_Vec toAnchor(center, anchor);
                gp_Pnt opposite = center.Translated(-toAnchor);
                out->firstPoint[0] = anchor.X(); out->firstPoint[1] = anchor.Y(); out->firstPoint[2] = anchor.Z();
                out->secondPoint[0] = opposite.X(); out->secondPoint[1] = opposite.Y(); out->secondPoint[2] = opposite.Z();
                out->centerPoint[0] = center.X(); out->centerPoint[1] = center.Y(); out->centerPoint[2] = center.Z();
                gp_Dir axis = circ.Axis().Direction();
                out->circleNormal[0] = axis.X(); out->circleNormal[1] = axis.Y(); out->circleNormal[2] = axis.Z();
                out->circleRadius = circ.Radius();
                out->textPosition[0] = center.X(); out->textPosition[1] = center.Y(); out->textPosition[2] = center.Z();
                break;
            }
        }
        return true;
    } catch (...) {
        return false;
    }
}

void OCCTDimensionSetCustomValue(OCCTDimensionRef dim, double value) {
    if (!dim || dim->dim.IsNull()) return;
    try {
        dim->dim->SetCustomValue(value);
    } catch (...) {}
}

bool OCCTDimensionIsValid(OCCTDimensionRef dim) {
    if (!dim || dim->dim.IsNull()) return false;
    try {
        return dim->dim->IsValid();
    } catch (...) {
        return false;
    }
}

int32_t OCCTDimensionGetKind(OCCTDimensionRef dim) {
    if (!dim) return -1;
    return dim->kind;
}

// --- Text Label ---

OCCTTextLabelRef OCCTTextLabelCreate(const char* text, double x, double y, double z) {
    if (!text) return nullptr;
    try {
        Handle(AIS_TextLabel) label = new AIS_TextLabel();
        label->SetText(TCollection_ExtendedString(text, Standard_True));
        label->SetPosition(gp_Pnt(x, y, z));
        auto* result = new OCCTTextLabel();
        result->label = label;
        return result;
    } catch (...) {
        return nullptr;
    }
}

void OCCTTextLabelRelease(OCCTTextLabelRef label) {
    delete label;
}

void OCCTTextLabelSetText(OCCTTextLabelRef label, const char* text) {
    if (!label || !text || label->label.IsNull()) return;
    try {
        label->label->SetText(TCollection_ExtendedString(text, Standard_True));
    } catch (...) {}
}

void OCCTTextLabelSetPosition(OCCTTextLabelRef label, double x, double y, double z) {
    if (!label || label->label.IsNull()) return;
    try {
        label->label->SetPosition(gp_Pnt(x, y, z));
    } catch (...) {}
}

void OCCTTextLabelSetHeight(OCCTTextLabelRef label, double height) {
    if (!label || label->label.IsNull()) return;
    try {
        label->label->SetHeight(height);
    } catch (...) {}
}

bool OCCTTextLabelGetInfo(OCCTTextLabelRef label, OCCTTextLabelInfo* out) {
    if (!label || !out || label->label.IsNull()) return false;
    try {
        memset(out, 0, sizeof(OCCTTextLabelInfo));
        gp_Pnt pos = label->label->Position();
        out->position[0] = pos.X();
        out->position[1] = pos.Y();
        out->position[2] = pos.Z();

        // Get text as UTF-8
        TCollection_ExtendedString extStr = label->label->Text();
        TCollection_AsciiString ascii(extStr);
        strncpy(out->text, ascii.ToCString(), 255);
        out->text[255] = '\0';

        out->height = 12.0; // Default height
        return true;
    } catch (...) {
        return false;
    }
}

// --- Point Cloud ---

static void computePointCloudBounds(OCCTPointCloud* cloud) {
    if (cloud->count == 0) {
        memset(cloud->minBound, 0, sizeof(cloud->minBound));
        memset(cloud->maxBound, 0, sizeof(cloud->maxBound));
        return;
    }
    cloud->minBound[0] = cloud->maxBound[0] = cloud->coords[0];
    cloud->minBound[1] = cloud->maxBound[1] = cloud->coords[1];
    cloud->minBound[2] = cloud->maxBound[2] = cloud->coords[2];
    for (int32_t i = 1; i < cloud->count; ++i) {
        int idx = i * 3;
        for (int j = 0; j < 3; ++j) {
            if (cloud->coords[idx + j] < cloud->minBound[j]) cloud->minBound[j] = cloud->coords[idx + j];
            if (cloud->coords[idx + j] > cloud->maxBound[j]) cloud->maxBound[j] = cloud->coords[idx + j];
        }
    }
}

OCCTPointCloudRef OCCTPointCloudCreate(const double* coords, int32_t count) {
    if (!coords || count <= 0) return nullptr;
    try {
        auto* cloud = new OCCTPointCloud();
        cloud->count = count;
        cloud->coords.assign(coords, coords + count * 3);
        computePointCloudBounds(cloud);
        return cloud;
    } catch (...) {
        return nullptr;
    }
}

OCCTPointCloudRef OCCTPointCloudCreateColored(const double* coords,
                                               const float* colors,
                                               int32_t count)
{
    if (!coords || !colors || count <= 0) return nullptr;
    try {
        auto* cloud = new OCCTPointCloud();
        cloud->count = count;
        cloud->coords.assign(coords, coords + count * 3);
        cloud->colors.assign(colors, colors + count * 3);
        computePointCloudBounds(cloud);
        return cloud;
    } catch (...) {
        return nullptr;
    }
}

void OCCTPointCloudRelease(OCCTPointCloudRef cloud) {
    delete cloud;
}

int32_t OCCTPointCloudGetCount(OCCTPointCloudRef cloud) {
    if (!cloud) return 0;
    return cloud->count;
}

bool OCCTPointCloudGetBounds(OCCTPointCloudRef cloud, double* outMinXYZ, double* outMaxXYZ) {
    if (!cloud || !outMinXYZ || !outMaxXYZ || cloud->count == 0) return false;
    memcpy(outMinXYZ, cloud->minBound, 3 * sizeof(double));
    memcpy(outMaxXYZ, cloud->maxBound, 3 * sizeof(double));
    return true;
}

int32_t OCCTPointCloudGetPoints(OCCTPointCloudRef cloud, double* outCoords, int32_t maxCount) {
    if (!cloud || !outCoords || maxCount <= 0) return 0;
    int32_t n = std::min(maxCount, cloud->count);
    memcpy(outCoords, cloud->coords.data(), n * 3 * sizeof(double));
    return n;
}

int32_t OCCTPointCloudGetColors(OCCTPointCloudRef cloud, float* outColors, int32_t maxCount) {
    if (!cloud || !outColors || maxCount <= 0 || cloud->colors.empty()) return 0;
    int32_t n = std::min(maxCount, cloud->count);
    memcpy(outColors, cloud->colors.data(), n * 3 * sizeof(float));
    return n;
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

// MARK: - KD-Tree Spatial Queries (v0.28.0)

#include <NCollection_KDTree.hxx>

struct OCCTKDTree {
    NCollection_KDTree<gp_Pnt, 3> tree;
    std::vector<gp_Pnt> points;
};

OCCTKDTreeRef OCCTKDTreeBuild(const double* coords, int32_t count) {
    if (!coords || count <= 0) return nullptr;
    try {
        auto* kd = new OCCTKDTree();
        kd->points.resize(count);
        for (int32_t i = 0; i < count; i++) {
            kd->points[i] = gp_Pnt(coords[i*3], coords[i*3+1], coords[i*3+2]);
        }
        kd->tree.Build(kd->points.data(), (size_t)count);
        return kd;
    } catch (...) {
        return nullptr;
    }
}

void OCCTKDTreeRelease(OCCTKDTreeRef tree) {
    delete tree;
}

int32_t OCCTKDTreeNearestPoint(OCCTKDTreeRef tree,
                                double qx, double qy, double qz,
                                double* outDistance) {
    if (!tree || tree->tree.IsEmpty()) return -1;
    try {
        gp_Pnt query(qx, qy, qz);
        double sqDist = 0;
        size_t idx = tree->tree.NearestPoint(query, sqDist);
        if (outDistance) *outDistance = std::sqrt(sqDist);
        return (int32_t)(idx - 1); // OCCT uses 1-based → convert to 0-based
    } catch (...) {
        return -1;
    }
}

int32_t OCCTKDTreeKNearest(OCCTKDTreeRef tree,
                            double qx, double qy, double qz,
                            int32_t k,
                            int32_t* outIndices,
                            double* outSqDistances) {
    if (!tree || !outIndices || k <= 0 || tree->tree.IsEmpty()) return 0;
    try {
        gp_Pnt query(qx, qy, qz);
        NCollection_Array1<size_t> indices(1, k);
        NCollection_Array1<double> distances(1, k);
        size_t found = tree->tree.KNearestPoints(query, (size_t)k, indices, distances);

        int32_t n = (int32_t)found;
        for (int32_t i = 0; i < n; i++) {
            outIndices[i] = (int32_t)(indices.Value(i + 1) - 1); // 1-based → 0-based
        }
        if (outSqDistances) {
            for (int32_t i = 0; i < n; i++) {
                outSqDistances[i] = distances.Value(i + 1);
            }
        }
        return n;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTKDTreeRangeSearch(OCCTKDTreeRef tree,
                               double qx, double qy, double qz,
                               double radius,
                               int32_t* outIndices, int32_t maxResults) {
    if (!tree || !outIndices || maxResults <= 0 || tree->tree.IsEmpty()) return 0;
    try {
        gp_Pnt query(qx, qy, qz);
        auto results = tree->tree.RangeSearch(query, radius);

        int32_t n = std::min((int32_t)results.Size(), maxResults);
        for (int32_t i = 0; i < n; i++) {
            outIndices[i] = (int32_t)(results[i] - 1); // 1-based → 0-based
        }
        return n;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTKDTreeBoxSearch(OCCTKDTreeRef tree,
                             double minX, double minY, double minZ,
                             double maxX, double maxY, double maxZ,
                             int32_t* outIndices, int32_t maxResults) {
    if (!tree || !outIndices || maxResults <= 0 || tree->tree.IsEmpty()) return 0;
    try {
        gp_Pnt minPt(minX, minY, minZ);
        gp_Pnt maxPt(maxX, maxY, maxZ);
        auto results = tree->tree.BoxSearch(minPt, maxPt);

        int32_t n = std::min((int32_t)results.Size(), maxResults);
        for (int32_t i = 0; i < n; i++) {
            outIndices[i] = (int32_t)(results[i] - 1); // 1-based → 0-based
        }
        return n;
    } catch (...) {
        return 0;
    }
}

// MARK: - STEP Optimization (v0.28.0)

#include <StepTidy_DuplicateCleaner.hxx>

bool OCCTStepTidyOptimize(const char* inputPath, const char* outputPath) {
    if (!inputPath || !outputPath) return false;
    try {
        STEPControl_Reader reader;
        if (reader.ReadFile(inputPath) != IFSelect_RetDone) return false;

        // Run tidy on the work session before transferring
        Handle(XSControl_WorkSession) ws = reader.WS();
        StepTidy_DuplicateCleaner cleaner(ws);
        cleaner.Perform();

        // Now transfer and write
        reader.TransferRoots();

        STEPControl_Writer writer;
        for (int i = 1; i <= reader.NbShapes(); i++) {
            writer.Transfer(reader.Shape(i), STEPControl_AsIs);
        }
        return writer.Write(outputPath) == IFSelect_RetDone;
    } catch (...) {
        return false;
    }
}

// MARK: - Batch Curve2D Evaluation (v0.28.0)

#include <Geom2dGridEval_Curve.hxx>
#include <Geom2dGridEval.hxx>

int32_t OCCTCurve2DEvaluateGrid(OCCTCurve2DRef curve,
                                 const double* params, int32_t paramCount,
                                 double* outXY) {
    if (!curve || curve->curve.IsNull() || !params || !outXY || paramCount <= 0) return 0;
    try {
        Geom2dGridEval_Curve evaluator;
        evaluator.Initialize(curve->curve);
        if (!evaluator.IsInitialized()) return 0;

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
        Geom2dGridEval_Curve evaluator;
        evaluator.Initialize(curve->curve);
        if (!evaluator.IsInitialized()) return 0;

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

// MARK: - NURBS Conversion (v0.29.0)

#include <BRepBuilderAPI_NurbsConvert.hxx>

OCCTShapeRef OCCTShapeConvertToNURBS(OCCTShapeRef shape) {
    if (!shape) return nullptr;
    try {
        BRepBuilderAPI_NurbsConvert converter(shape->shape);
        if (!converter.IsDone()) return nullptr;
        return new OCCTShape(converter.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Fast Sewing (v0.29.0)

#include <BRepBuilderAPI_FastSewing.hxx>

OCCTShapeRef OCCTShapeFastSewn(OCCTShapeRef shape, double tolerance) {
    if (!shape) return nullptr;
    try {
        BRepBuilderAPI_FastSewing sewer(tolerance);
        sewer.Add(shape->shape);
        sewer.Perform();
        return new OCCTShape(sewer.GetResult());
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

// MARK: - Batch Curve3D Evaluation (v0.29.0)

#include <GeomGridEval_Curve.hxx>
#include <GeomGridEval.hxx>

int32_t OCCTCurve3DEvaluateGrid(OCCTCurve3DRef curve, const double* params, int32_t paramCount,
                                 double* outXYZ) {
    if (!curve || curve->curve.IsNull() || !params || !outXYZ || paramCount <= 0) return 0;
    try {
        GeomGridEval_Curve evaluator;
        evaluator.Initialize(curve->curve);
        if (!evaluator.IsInitialized()) return 0;

        NCollection_Array1<double> paramArr(1, paramCount);
        for (int32_t i = 0; i < paramCount; i++) {
            paramArr.SetValue(i + 1, params[i]);
        }

        NCollection_Array1<gp_Pnt> results = evaluator.EvaluateGrid(paramArr);
        int32_t n = results.Size();
        for (int32_t i = 0; i < n; i++) {
            const gp_Pnt& pt = results.Value(i + 1);
            outXYZ[i*3]   = pt.X();
            outXYZ[i*3+1] = pt.Y();
            outXYZ[i*3+2] = pt.Z();
        }
        return n;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTCurve3DEvaluateGridD1(OCCTCurve3DRef curve, const double* params, int32_t paramCount,
                                   double* outXYZ, double* outDXDYDZ) {
    if (!curve || curve->curve.IsNull() || !params || !outXYZ || !outDXDYDZ || paramCount <= 0) return 0;
    try {
        GeomGridEval_Curve evaluator;
        evaluator.Initialize(curve->curve);
        if (!evaluator.IsInitialized()) return 0;

        NCollection_Array1<double> paramArr(1, paramCount);
        for (int32_t i = 0; i < paramCount; i++) {
            paramArr.SetValue(i + 1, params[i]);
        }

        NCollection_Array1<GeomGridEval::CurveD1> results = evaluator.EvaluateGridD1(paramArr);
        int32_t n = results.Size();
        for (int32_t i = 0; i < n; i++) {
            const GeomGridEval::CurveD1& r = results.Value(i + 1);
            outXYZ[i*3]     = r.Point.X();
            outXYZ[i*3+1]   = r.Point.Y();
            outXYZ[i*3+2]   = r.Point.Z();
            outDXDYDZ[i*3]   = r.D1.X();
            outDXDYDZ[i*3+1] = r.D1.Y();
            outDXDYDZ[i*3+2] = r.D1.Z();
        }
        return n;
    } catch (...) {
        return 0;
    }
}

// MARK: - Batch Surface Evaluation (v0.29.0)

#include <GeomGridEval_Surface.hxx>

int32_t OCCTSurfaceEvaluateGrid(OCCTSurfaceRef surface,
                                 const double* uParams, int32_t uCount,
                                 const double* vParams, int32_t vCount,
                                 double* outXYZ) {
    if (!surface || surface->surface.IsNull() || !uParams || !vParams || !outXYZ
        || uCount <= 0 || vCount <= 0) return 0;
    try {
        GeomGridEval_Surface evaluator;
        evaluator.Initialize(surface->surface);
        if (!evaluator.IsInitialized()) return 0;

        NCollection_Array1<double> uArr(1, uCount);
        for (int32_t i = 0; i < uCount; i++) {
            uArr.SetValue(i + 1, uParams[i]);
        }
        NCollection_Array1<double> vArr(1, vCount);
        for (int32_t i = 0; i < vCount; i++) {
            vArr.SetValue(i + 1, vParams[i]);
        }

        NCollection_Array2<gp_Pnt> results = evaluator.EvaluateGrid(uArr, vArr);
        int32_t total = uCount * vCount;
        int32_t idx = 0;
        // Row-major: v (rows) varies slowest, u (cols) varies fastest
        for (int32_t iv = 1; iv <= vCount; iv++) {
            for (int32_t iu = 1; iu <= uCount; iu++) {
                const gp_Pnt& pt = results.Value(iu, iv);
                outXYZ[idx*3]   = pt.X();
                outXYZ[idx*3+1] = pt.Y();
                outXYZ[idx*3+2] = pt.Z();
                idx++;
            }
        }
        return total;
    } catch (...) {
        return 0;
    }
}

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

// MARK: - Polynomial Solvers (v0.29.0)

#include <math_DirectPolynomialRoots.hxx>
#include <algorithm>

OCCTPolynomialRoots OCCTSolveQuadratic(double a, double b, double c) {
    OCCTPolynomialRoots result;
    result.count = 0;
    result.roots[0] = result.roots[1] = result.roots[2] = result.roots[3] = 0.0;
    try {
        math_DirectPolynomialRoots solver(a, b, c);
        if (!solver.IsDone()) return result;
        result.count = std::min(solver.NbSolutions(), 4);
        for (int i = 0; i < result.count; i++) {
            result.roots[i] = solver.Value(i + 1);
        }
        std::sort(result.roots, result.roots + result.count);
    } catch (...) {}
    return result;
}

OCCTPolynomialRoots OCCTSolveCubic(double a, double b, double c, double d) {
    OCCTPolynomialRoots result;
    result.count = 0;
    result.roots[0] = result.roots[1] = result.roots[2] = result.roots[3] = 0.0;
    try {
        math_DirectPolynomialRoots solver(a, b, c, d);
        if (!solver.IsDone()) return result;
        result.count = std::min(solver.NbSolutions(), 4);
        for (int i = 0; i < result.count; i++) {
            result.roots[i] = solver.Value(i + 1);
        }
        std::sort(result.roots, result.roots + result.count);
    } catch (...) {}
    return result;
}

OCCTPolynomialRoots OCCTSolveQuartic(double a, double b, double c, double d, double e) {
    OCCTPolynomialRoots result;
    result.count = 0;
    result.roots[0] = result.roots[1] = result.roots[2] = result.roots[3] = 0.0;
    try {
        math_DirectPolynomialRoots solver(a, b, c, d, e);
        if (!solver.IsDone()) return result;
        result.count = std::min(solver.NbSolutions(), 4);
        for (int i = 0; i < result.count; i++) {
            result.roots[i] = solver.Value(i + 1);
        }
        std::sort(result.roots, result.roots + result.count);
    } catch (...) {}
    return result;
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

// MARK: - Curve Planarity Check (v0.29.0)

#include <ShapeAnalysis_Curve.hxx>

bool OCCTCurve3DIsPlanar(OCCTCurve3DRef curve, double tolerance,
                          double* outNX, double* outNY, double* outNZ) {
    if (!curve || curve->curve.IsNull()) return false;
    try {
        ShapeAnalysis_Curve analyzer;
        gp_XYZ normal;
        bool result = analyzer.IsPlanar(curve->curve, normal, tolerance);
        if (result) {
            if (outNX) *outNX = normal.X();
            if (outNY) *outNY = normal.Y();
            if (outNZ) *outNZ = normal.Z();
            return true;
        }
        return false;
    } catch (...) {
        return false;
    }
}

// MARK: - Revolution Feature (v0.29.0)
// NOTE: BRepFeat_MakeRevol is skipped. It requires identifying the correct sketch face
// from the profile shape, which is highly context-dependent and cannot be reliably
// automated in a generic C bridge. Use OCCTShapeCreateRevolution (sweep) + boolean
// operations instead.

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

// MARK: - Curve-Curve Extrema (v0.30.0)

#include <GeomAPI_ExtremaCurveCurve.hxx>

double OCCTCurve3DMinDistanceToCurve(OCCTCurve3DRef c1, OCCTCurve3DRef c2) {
    if (!c1 || c1->curve.IsNull() || !c2 || c2->curve.IsNull()) return -1.0;
    try {
        GeomAPI_ExtremaCurveCurve extrema(c1->curve, c2->curve);
        if (extrema.NbExtrema() == 0) return -1.0;
        return extrema.LowerDistance();
    } catch (...) {
        return -1.0;
    }
}

int32_t OCCTCurve3DExtrema(OCCTCurve3DRef c1, OCCTCurve3DRef c2, OCCTCurveExtrema* outExtrema, int32_t maxCount) {
    if (!c1 || c1->curve.IsNull() || !c2 || c2->curve.IsNull() || !outExtrema || maxCount <= 0) return 0;
    try {
        GeomAPI_ExtremaCurveCurve extrema(c1->curve, c2->curve);
        int32_t nb = extrema.NbExtrema();
        int32_t count = (nb < maxCount) ? nb : maxCount;
        for (int32_t i = 0; i < count; i++) {
            gp_Pnt p1, p2;
            extrema.Points(i + 1, p1, p2);
            double u1, u2;
            extrema.Parameters(i + 1, u1, u2);
            outExtrema[i].distance = extrema.Distance(i + 1);
            outExtrema[i].point1[0] = p1.X();
            outExtrema[i].point1[1] = p1.Y();
            outExtrema[i].point1[2] = p1.Z();
            outExtrema[i].point2[0] = p2.X();
            outExtrema[i].point2[1] = p2.Y();
            outExtrema[i].point2[2] = p2.Z();
            outExtrema[i].param1 = u1;
            outExtrema[i].param2 = u2;
        }
        return count;
    } catch (...) {
        return 0;
    }
}

// MARK: - Curve-Surface Intersection (v0.30.0)

#include <GeomAPI_IntCS.hxx>

int32_t OCCTCurve3DIntersectSurface(OCCTCurve3DRef curve, OCCTSurfaceRef surface,
                                     OCCTCurveSurfaceIntersection* outHits, int32_t maxHits) {
    if (!curve || curve->curve.IsNull() || !surface || surface->surface.IsNull() || !outHits || maxHits <= 0) return 0;
    try {
        GeomAPI_IntCS inter(curve->curve, surface->surface);
        if (!inter.IsDone()) return 0;
        int32_t nb = inter.NbPoints();
        int32_t count = (nb < maxHits) ? nb : maxHits;
        for (int32_t i = 0; i < count; i++) {
            gp_Pnt pt = inter.Point(i + 1);
            double w, u, v;
            inter.Parameters(i + 1, u, v, w);
            outHits[i].point[0] = pt.X();
            outHits[i].point[1] = pt.Y();
            outHits[i].point[2] = pt.Z();
            outHits[i].paramCurve = w;
            outHits[i].paramU = u;
            outHits[i].paramV = v;
        }
        return count;
    } catch (...) {
        return 0;
    }
}

// MARK: - Surface-Surface Intersection (v0.30.0)

#include <GeomAPI_IntSS.hxx>

int32_t OCCTSurfaceIntersect(OCCTSurfaceRef s1, OCCTSurfaceRef s2, double tolerance,
                              OCCTCurve3DRef* outCurves, int32_t maxCurves) {
    if (!s1 || s1->surface.IsNull() || !s2 || s2->surface.IsNull() || !outCurves || maxCurves <= 0) return 0;
    try {
        GeomAPI_IntSS inter(s1->surface, s2->surface, tolerance);
        if (!inter.IsDone()) return 0;
        int32_t nb = inter.NbLines();
        int32_t count = (nb < maxCurves) ? nb : maxCurves;
        for (int32_t i = 0; i < count; i++) {
            Handle(Geom_Curve) c = inter.Line(i + 1);
            if (c.IsNull()) {
                outCurves[i] = nullptr;
            } else {
                outCurves[i] = new OCCTCurve3D(c);
            }
        }
        return count;
    } catch (...) {
        return 0;
    }
}

// MARK: - Curve-Surface Distance (v0.30.0)

#include <GeomAPI_ExtremaCurveSurface.hxx>

double OCCTCurve3DDistanceToSurface(OCCTCurve3DRef curve, OCCTSurfaceRef surface) {
    if (!curve || curve->curve.IsNull() || !surface || surface->surface.IsNull()) return -1.0;
    try {
        GeomAPI_ExtremaCurveSurface extrema(curve->curve, surface->surface);
        if (extrema.NbExtrema() == 0) return -1.0;
        return extrema.LowerDistance();
    } catch (...) {
        return -1.0;
    }
}

// MARK: - Curve to Analytical (v0.30.0)

#include <GeomConvert_CurveToAnaCurve.hxx>

OCCTCurve3DRef OCCTCurve3DToAnalytical(OCCTCurve3DRef curve, double tolerance) {
    if (!curve || curve->curve.IsNull()) return nullptr;
    try {
        GeomConvert_CurveToAnaCurve converter(curve->curve);
        Handle(Geom_Curve) result;
        double newFirst, newLast;
        bool ok = converter.ConvertToAnalytical(tolerance, result,
                                                 curve->curve->FirstParameter(),
                                                 curve->curve->LastParameter(),
                                                 newFirst, newLast);
        if (!ok || result.IsNull()) return nullptr;
        return new OCCTCurve3D(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Surface to Analytical (v0.30.0)

#include <GeomConvert_SurfToAnaSurf.hxx>

OCCTSurfaceRef OCCTSurfaceToAnalytical(OCCTSurfaceRef surface, double tolerance) {
    if (!surface || surface->surface.IsNull()) return nullptr;
    try {
        GeomConvert_SurfToAnaSurf converter(surface->surface);
        Handle(Geom_Surface) result = converter.ConvertToAnalytical(tolerance);
        if (result.IsNull()) return nullptr;
        // If the result is the same handle, it was already analytical or couldn't convert
        if (result == surface->surface) return nullptr;
        return new OCCTSurface(result);
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

// MARK: - Canonical Recognition (v0.30.0)

#include <ShapeAnalysis_CanonicalRecognition.hxx>
#include <gp_Elips.hxx>

OCCTCanonicalForm OCCTShapeRecognizeCanonical(OCCTShapeRef shape, double tolerance) {
    OCCTCanonicalForm result = {};
    if (!shape) return result;
    try {
        ShapeAnalysis_CanonicalRecognition recog(shape->shape);
        gp_Pln pln;
        if (recog.IsPlane(tolerance, pln)) {
            result.type = 1;
            result.origin[0] = pln.Location().X();
            result.origin[1] = pln.Location().Y();
            result.origin[2] = pln.Location().Z();
            result.direction[0] = pln.Axis().Direction().X();
            result.direction[1] = pln.Axis().Direction().Y();
            result.direction[2] = pln.Axis().Direction().Z();
            result.gap = recog.GetGap();
            return result;
        }
        gp_Cylinder cyl;
        if (recog.IsCylinder(tolerance, cyl)) {
            result.type = 2;
            result.origin[0] = cyl.Location().X();
            result.origin[1] = cyl.Location().Y();
            result.origin[2] = cyl.Location().Z();
            result.direction[0] = cyl.Axis().Direction().X();
            result.direction[1] = cyl.Axis().Direction().Y();
            result.direction[2] = cyl.Axis().Direction().Z();
            result.radius = cyl.Radius();
            result.gap = recog.GetGap();
            return result;
        }
        gp_Cone cone;
        if (recog.IsCone(tolerance, cone)) {
            result.type = 3;
            result.origin[0] = cone.Location().X();
            result.origin[1] = cone.Location().Y();
            result.origin[2] = cone.Location().Z();
            result.direction[0] = cone.Axis().Direction().X();
            result.direction[1] = cone.Axis().Direction().Y();
            result.direction[2] = cone.Axis().Direction().Z();
            result.radius = cone.RefRadius();
            result.radius2 = cone.SemiAngle();
            result.gap = recog.GetGap();
            return result;
        }
        gp_Sphere sph;
        if (recog.IsSphere(tolerance, sph)) {
            result.type = 4;
            result.origin[0] = sph.Location().X();
            result.origin[1] = sph.Location().Y();
            result.origin[2] = sph.Location().Z();
            result.direction[0] = sph.Position().Direction().X();
            result.direction[1] = sph.Position().Direction().Y();
            result.direction[2] = sph.Position().Direction().Z();
            result.radius = sph.Radius();
            result.gap = recog.GetGap();
            return result;
        }
        gp_Lin lin;
        if (recog.IsLine(tolerance, lin)) {
            result.type = 5;
            result.origin[0] = lin.Location().X();
            result.origin[1] = lin.Location().Y();
            result.origin[2] = lin.Location().Z();
            result.direction[0] = lin.Direction().X();
            result.direction[1] = lin.Direction().Y();
            result.direction[2] = lin.Direction().Z();
            result.gap = recog.GetGap();
            return result;
        }
        gp_Circ circ;
        if (recog.IsCircle(tolerance, circ)) {
            result.type = 6;
            result.origin[0] = circ.Location().X();
            result.origin[1] = circ.Location().Y();
            result.origin[2] = circ.Location().Z();
            result.direction[0] = circ.Axis().Direction().X();
            result.direction[1] = circ.Axis().Direction().Y();
            result.direction[2] = circ.Axis().Direction().Z();
            result.radius = circ.Radius();
            result.gap = recog.GetGap();
            return result;
        }
        gp_Elips elips;
        if (recog.IsEllipse(tolerance, elips)) {
            result.type = 7;
            result.origin[0] = elips.Location().X();
            result.origin[1] = elips.Location().Y();
            result.origin[2] = elips.Location().Z();
            result.direction[0] = elips.Axis().Direction().X();
            result.direction[1] = elips.Axis().Direction().Y();
            result.direction[2] = elips.Axis().Direction().Z();
            result.radius = elips.MajorRadius();
            result.radius2 = elips.MinorRadius();
            result.gap = recog.GetGap();
            return result;
        }
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

// MARK: - Shape Fix Wireframe (v0.30.0)

#include <ShapeFix_Wireframe.hxx>

OCCTShapeRef OCCTShapeFixWireframe(OCCTShapeRef shape, double tolerance) {
    if (!shape) return nullptr;
    try {
        Handle(ShapeFix_Wireframe) fixer = new ShapeFix_Wireframe(shape->shape);
        fixer->SetPrecision(tolerance);
        fixer->FixSmallEdges();
        fixer->FixWireGaps();
        TopoDS_Shape result = fixer->Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Remove Internal Wires (v0.30.0)

#include <ShapeUpgrade_RemoveInternalWires.hxx>

OCCTShapeRef OCCTShapeRemoveInternalWires(OCCTShapeRef shape, double minArea) {
    if (!shape) return nullptr;
    try {
        Handle(ShapeUpgrade_RemoveInternalWires) remover = new ShapeUpgrade_RemoveInternalWires(shape->shape);
        remover->MinArea() = minArea;
        remover->Perform();
        TopoDS_Shape result = remover->GetResult();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Document Length Unit (v0.30.0)

#include <XCAFDoc_LengthUnit.hxx>

bool OCCTDocumentGetLengthUnit(OCCTDocumentRef doc, double* unitScale, char* unitName, int32_t maxNameLen) {
    if (!doc || doc->doc.IsNull() || !unitScale) return false;
    try {
        TDF_Label rootLabel = doc->doc->Main().Root();
        Handle(XCAFDoc_LengthUnit) luAttr;
        if (!rootLabel.FindAttribute(XCAFDoc_LengthUnit::GetID(), luAttr)) {
            // Try the main label
            TDF_Label mainLabel = doc->doc->Main();
            if (!mainLabel.FindAttribute(XCAFDoc_LengthUnit::GetID(), luAttr)) {
                return false;
            }
        }
        *unitScale = luAttr->GetUnitValue();
        if (unitName && maxNameLen > 0) {
            TCollection_AsciiString name = luAttr->GetUnitName();
            int len = name.Length();
            if (len >= maxNameLen) len = maxNameLen - 1;
            for (int i = 0; i < len; i++) {
                unitName[i] = name.Value(i + 1);
            }
            unitName[len] = '\0';
        }
        return true;
    } catch (...) {
        return false;
    }
}

// MARK: - Quasi-Uniform Curve Sampling (v0.31.0)

#include <GCPnts_QuasiUniformAbscissa.hxx>

int32_t OCCTCurve3DQuasiUniformAbscissa(OCCTCurve3DRef curve, int32_t nbPoints, double* outParams) {
    if (!curve || curve->curve.IsNull() || !outParams || nbPoints <= 0) return 0;
    try {
        GeomAdaptor_Curve adaptor(curve->curve);
        GCPnts_QuasiUniformAbscissa sampler(adaptor, nbPoints);
        if (!sampler.IsDone()) return 0;
        int32_t n = sampler.NbPoints();
        for (int32_t i = 0; i < n; i++) {
            outParams[i] = sampler.Parameter(i + 1);
        }
        return n;
    } catch (...) {
        return 0;
    }
}

// MARK: - Quasi-Uniform Deflection Sampling (v0.31.0)

#include <GCPnts_QuasiUniformDeflection.hxx>

int32_t OCCTCurve3DQuasiUniformDeflection(OCCTCurve3DRef curve, double deflection, double* outXYZ, int32_t maxPoints) {
    if (!curve || curve->curve.IsNull() || !outXYZ || maxPoints <= 0) return 0;
    try {
        GeomAdaptor_Curve adaptor(curve->curve);
        GCPnts_QuasiUniformDeflection sampler(adaptor, deflection);
        if (!sampler.IsDone()) return 0;
        int32_t n = std::min((int32_t)sampler.NbPoints(), maxPoints);
        for (int32_t i = 0; i < n; i++) {
            gp_Pnt p = sampler.Value(i + 1);
            outXYZ[i*3] = p.X();
            outXYZ[i*3+1] = p.Y();
            outXYZ[i*3+2] = p.Z();
        }
        return n;
    } catch (...) {
        return 0;
    }
}

// MARK: - Bezier Surface Fill (v0.31.0)

#include <GeomFill_BezierCurves.hxx>
#include <GeomFill_FillingStyle.hxx>
#include <Geom_BezierCurve.hxx>
#include <Geom_BezierSurface.hxx>

OCCTSurfaceRef OCCTSurfaceBezierFill4(OCCTCurve3DRef c1, OCCTCurve3DRef c2,
                                        OCCTCurve3DRef c3, OCCTCurve3DRef c4,
                                        int32_t fillStyle) {
    if (!c1 || c1->curve.IsNull() ||
        !c2 || c2->curve.IsNull() ||
        !c3 || c3->curve.IsNull() ||
        !c4 || c4->curve.IsNull()) return nullptr;
    try {
        Handle(Geom_BezierCurve) bc1 = Handle(Geom_BezierCurve)::DownCast(c1->curve);
        Handle(Geom_BezierCurve) bc2 = Handle(Geom_BezierCurve)::DownCast(c2->curve);
        Handle(Geom_BezierCurve) bc3 = Handle(Geom_BezierCurve)::DownCast(c3->curve);
        Handle(Geom_BezierCurve) bc4 = Handle(Geom_BezierCurve)::DownCast(c4->curve);
        if (bc1.IsNull() || bc2.IsNull() || bc3.IsNull() || bc4.IsNull()) return nullptr;
        GeomFill_FillingStyle style = GeomFill_StretchStyle;
        if (fillStyle == 1) style = GeomFill_CoonsStyle;
        else if (fillStyle == 2) style = GeomFill_CurvedStyle;
        GeomFill_BezierCurves filler(bc1, bc2, bc3, bc4, style);
        Handle(Geom_BezierSurface) surf = filler.Surface();
        if (surf.IsNull()) return nullptr;
        return new OCCTSurface(surf);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceBezierFill2(OCCTCurve3DRef c1, OCCTCurve3DRef c2,
                                        int32_t fillStyle) {
    if (!c1 || c1->curve.IsNull() ||
        !c2 || c2->curve.IsNull()) return nullptr;
    try {
        Handle(Geom_BezierCurve) bc1 = Handle(Geom_BezierCurve)::DownCast(c1->curve);
        Handle(Geom_BezierCurve) bc2 = Handle(Geom_BezierCurve)::DownCast(c2->curve);
        if (bc1.IsNull() || bc2.IsNull()) return nullptr;
        GeomFill_FillingStyle style = GeomFill_StretchStyle;
        if (fillStyle == 1) style = GeomFill_CoonsStyle;
        else if (fillStyle == 2) style = GeomFill_CurvedStyle;
        GeomFill_BezierCurves filler(bc1, bc2, style);
        Handle(Geom_BezierSurface) surf = filler.Surface();
        if (surf.IsNull()) return nullptr;
        return new OCCTSurface(surf);
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

// MARK: - Fix Small Faces (v0.31.0)

#include <ShapeFix_FixSmallFace.hxx>

OCCTShapeRef OCCTShapeFixSmallFaces(OCCTShapeRef shape, double tolerance) {
    if (!shape) return nullptr;
    try {
        Handle(ShapeFix_FixSmallFace) fixer = new ShapeFix_FixSmallFace();
        fixer->Init(shape->shape);
        fixer->SetPrecision(tolerance);
        fixer->Perform();
        TopoDS_Shape result = fixer->Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Remove Locations (v0.31.0)

#include <ShapeUpgrade_RemoveLocations.hxx>

OCCTShapeRef OCCTShapeRemoveLocations(OCCTShapeRef shape) {
    if (!shape) return nullptr;
    try {
        ShapeUpgrade_RemoveLocations remover;
        remover.Remove(shape->shape);
        TopoDS_Shape result = remover.GetResult();
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

// MARK: - Document Layers (v0.31.0)

#include <XCAFDoc_LayerTool.hxx>

int32_t OCCTDocumentGetLayerCount(OCCTDocumentRef doc) {
    if (!doc || doc->doc.IsNull()) return 0;
    try {
        Handle(XCAFDoc_LayerTool) layerTool = XCAFDoc_LayerTool::Set(doc->doc->Main());
        if (layerTool.IsNull()) return 0;
        TDF_LabelSequence labels;
        layerTool->GetLayerLabels(labels);
        return (int32_t)labels.Length();
    } catch (...) {
        return 0;
    }
}

bool OCCTDocumentGetLayerName(OCCTDocumentRef doc, int32_t index, char* outName, int32_t maxLen) {
    if (!doc || doc->doc.IsNull() || !outName || maxLen <= 0) return false;
    try {
        Handle(XCAFDoc_LayerTool) layerTool = XCAFDoc_LayerTool::Set(doc->doc->Main());
        if (layerTool.IsNull()) return false;
        TDF_LabelSequence labels;
        layerTool->GetLayerLabels(labels);
        if (index < 0 || index >= labels.Length()) return false;
        TDF_Label label = labels.Value(index + 1);
        TCollection_ExtendedString name;
        if (!layerTool->GetLayer(label, name)) return false;
        // Convert ExtendedString to ASCII
        TCollection_AsciiString ascii(name);
        int32_t len = ascii.Length();
        if (len >= maxLen) len = maxLen - 1;
        for (int32_t i = 0; i < len; i++) {
            outName[i] = ascii.Value(i + 1);
        }
        outName[len] = '\0';
        return true;
    } catch (...) {
        return false;
    }
}

// MARK: - Document Materials (v0.31.0)

#include <XCAFDoc_MaterialTool.hxx>
#include <TCollection_HAsciiString.hxx>

int32_t OCCTDocumentGetMaterialCount(OCCTDocumentRef doc) {
    if (!doc || doc->doc.IsNull()) return 0;
    try {
        Handle(XCAFDoc_MaterialTool) matTool = XCAFDoc_MaterialTool::Set(doc->doc->Main());
        if (matTool.IsNull()) return 0;
        TDF_LabelSequence labels;
        matTool->GetMaterialLabels(labels);
        return (int32_t)labels.Length();
    } catch (...) {
        return 0;
    }
}

bool OCCTDocumentGetMaterialInfo(OCCTDocumentRef doc, int32_t index, OCCTMaterialInfo* outInfo) {
    if (!doc || doc->doc.IsNull() || !outInfo) return false;
    try {
        Handle(XCAFDoc_MaterialTool) matTool = XCAFDoc_MaterialTool::Set(doc->doc->Main());
        if (matTool.IsNull()) return false;
        TDF_LabelSequence labels;
        matTool->GetMaterialLabels(labels);
        if (index < 0 || index >= labels.Length()) return false;
        TDF_Label label = labels.Value(index + 1);
        Handle(TCollection_HAsciiString) hName, hDesc, hDensName, hDensValType;
        double density = 0.0;
        matTool->GetMaterial(label, hName, hDesc, density, hDensName, hDensValType);
        memset(outInfo, 0, sizeof(OCCTMaterialInfo));
        if (!hName.IsNull()) {
            TCollection_AsciiString name = hName->String();
            int32_t len = std::min((int32_t)name.Length(), (int32_t)(sizeof(outInfo->name) - 1));
            for (int32_t i = 0; i < len; i++) {
                outInfo->name[i] = name.Value(i + 1);
            }
        }
        if (!hDesc.IsNull()) {
            TCollection_AsciiString desc = hDesc->String();
            int32_t len = std::min((int32_t)desc.Length(), (int32_t)(sizeof(outInfo->description) - 1));
            for (int32_t i = 0; i < len; i++) {
                outInfo->description[i] = desc.Value(i + 1);
            }
        }
        outInfo->density = density;
        return true;
    } catch (...) {
        return false;
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

// MARK: - Split Shape by Angle (v0.34.0)

#include <ShapeUpgrade_ShapeDivideAngle.hxx>

OCCTShapeRef OCCTShapeSplitByAngle(OCCTShapeRef shape, double maxAngleDegrees) {
    if (!shape) return nullptr;
    try {
        double maxAngleRadians = maxAngleDegrees * M_PI / 180.0;
        ShapeUpgrade_ShapeDivideAngle divider(maxAngleRadians, shape->shape);
        if (!divider.Perform()) return nullptr;
        TopoDS_Shape result = divider.Result();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Drop Small Edges (v0.34.0)

OCCTShapeRef OCCTShapeDropSmallEdges(OCCTShapeRef shape, double tolerance) {
    if (!shape) return nullptr;
    try {
        Handle(ShapeFix_Wireframe) wireframe = new ShapeFix_Wireframe(shape->shape);
        wireframe->SetPrecision(tolerance);
        wireframe->ModeDropSmallEdges() = true;
        wireframe->FixSmallEdges();
        TopoDS_Shape result = wireframe->Shape();
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
