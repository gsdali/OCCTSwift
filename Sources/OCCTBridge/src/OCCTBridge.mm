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
#include <TopoDS_Compound.hxx>
#include <TopExp_Explorer.hxx>

// Geometry
#include <Geom_Circle.hxx>
#include <Geom_Line.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <Geom2d_Line.hxx>
#include <GC_MakeArcOfCircle.hxx>
#include <GC_MakeCircle.hxx>
#include <GC_MakeLine.hxx>
#include <GC_MakeSegment.hxx>
#include <GeomAPI_PointsToBSpline.hxx>
#include <TColgp_Array1OfPnt.hxx>

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

// Modifications
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepFilletAPI_MakeChamfer.hxx>
#include <BRepOffsetAPI_MakeThickSolid.hxx>
#include <BRepOffsetAPI_MakeOffsetShape.hxx>
#include <TopTools_ListOfShape.hxx>

// Transformations
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>

// Building
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>

// Validation & Healing
#include <BRepCheck_Analyzer.hxx>
#include <ShapeFix_Shape.hxx>

// Meshing
#include <BRepMesh_IncrementalMesh.hxx>
#include <Poly_Triangulation.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>

// Export
#include <STEPControl_Writer.hxx>
#include <StlAPI_Writer.hxx>
#include <Interface_Static.hxx>

#include <vector>
#include <cmath>

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

                // Add triangles
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
                }
            }

            explorer.Next();
        }

        return mesh;
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
        STEPControl_Writer writer;
        Interface_Static::SetCVal("write.step.schema", "AP214");

        IFSelect_ReturnStatus status = writer.Transfer(shape->shape, STEPControl_AsIs);
        if (status != IFSelect_RetDone) return false;

        status = writer.Write(path);
        return status == IFSelect_RetDone;
    } catch (...) {
        return false;
    }
}

bool OCCTExportSTEPWithName(OCCTShapeRef shape, const char* path, const char* name) {
    if (!shape || !path) return false;

    try {
        STEPControl_Writer writer;
        Interface_Static::SetCVal("write.step.schema", "AP214");
        if (name) {
            Interface_Static::SetCVal("write.step.product.name", name);
        }

        IFSelect_ReturnStatus status = writer.Transfer(shape->shape, STEPControl_AsIs);
        if (status != IFSelect_RetDone) return false;

        status = writer.Write(path);
        return status == IFSelect_RetDone;
    } catch (...) {
        return false;
    }
}
