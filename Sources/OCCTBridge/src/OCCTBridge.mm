//
//  OCCTBridge.mm
//  OCCTSwift
//
//  Objective-C++ implementation bridging to OpenCASCADE
//

#import "../include/OCCTBridge.h"

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

    try {
        // Generate mesh
        BRepMesh_IncrementalMesh mesher(shape->shape, linearDeflection, Standard_False, angularDeflection);
        mesher.Perform();

        auto mesh = new OCCTMesh();

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

        auto mesh = new OCCTMesh();

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
        return nullptr;
    }
}

// MARK: - Edge Discretization

int32_t OCCTShapeGetEdgePolyline(OCCTShapeRef shape, int32_t edgeIndex, double deflection, double* outPoints, int32_t maxPoints) {
    if (!shape || !outPoints || maxPoints < 2) return -1;

    try {
        // Find the edge at the given index
        TopExp_Explorer explorer(shape->shape, TopAbs_EDGE);
        int32_t currentIndex = 0;
        while (explorer.More() && currentIndex < edgeIndex) {
            currentIndex++;
            explorer.Next();
        }

        if (!explorer.More()) return -1;

        TopoDS_Edge edge = TopoDS::Edge(explorer.Current());

        // Use BRepAdaptor_Curve for edge geometry
        BRepAdaptor_Curve curve(edge);

        // Use GCPnts_TangentialDeflection for adaptive discretization
        GCPnts_TangentialDeflection discretizer(curve, deflection, 0.1);  // deflection, angular

        if (discretizer.NbPoints() < 2) return -1;

        int32_t numPoints = std::min(discretizer.NbPoints(), maxPoints);
        for (int32_t i = 0; i < numPoints; i++) {
            gp_Pnt pt = discretizer.Value(i + 1);  // 1-indexed
            outPoints[i * 3 + 0] = pt.X();
            outPoints[i * 3 + 1] = pt.Y();
            outPoints[i * 3 + 2] = pt.Z();
        }

        return numPoints;
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
    if (!shape || !outPoints || maxPoints < 2) return 0;

    try {
        // Find the edge at the given index
        TopExp_Explorer explorer(shape->shape, TopAbs_EDGE);
        int32_t currentIndex = 0;
        while (explorer.More() && currentIndex < edgeIndex) {
            currentIndex++;
            explorer.Next();
        }

        if (!explorer.More()) return 0;

        TopoDS_Edge edge = TopoDS::Edge(explorer.Current());

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
    if (!edge) return;
    
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
            double t = first + (last - first) * i / (count - 1);
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
    if (!edge) return;
    
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
#include <TopTools_ListIteratorOfListOfShape.hxx>

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
        
        TopTools_ListIteratorOfListOfShape it(faces);
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
    try {
        OCCTDocument* document = new OCCTDocument();

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
        return nullptr;
    }
}

OCCTDocumentRef OCCTDocumentLoadSTEP(const char* path) {
    if (!path) return nullptr;

    try {
        OCCTDocument* document = new OCCTDocument();

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
