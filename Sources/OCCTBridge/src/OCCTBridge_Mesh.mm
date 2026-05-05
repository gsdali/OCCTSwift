//
//  OCCTBridge_Mesh.mm
//  OCCTSwift
//
//  Extracted from OCCTBridge.mm — issue #99.
//
//  Mesh / Wire / Curve cluster: triangulation generation, mesh parameter
//  tuning, edge discretization, direct triangle access, mesh-to-shape
//  conversion, mesh booleans, mesh access getters, plus 2D/3D wire creation
//  and NURBS curve creation. The block lives together because wire and
//  curve creation share dependencies with mesh-to-shape conversion in
//  several entry points, and splitting them would force header duplication
//  for marginal benefit.
//
//  Public C surface unchanged. No symbol changes — pure file move.
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

// === Area-specific OCCT headers ===

#include <BRepBndLib.hxx>
#include <BRepLib_PointCloudShape.hxx>
#include <BRepLib_ToolTriangulatedShape.hxx>
#include <BRepMesh_Deflection.hxx>
#include <BRepMesh_ShapeTool.hxx>
#include <ShapeConstruct_MakeTriangulation.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRep_Tool.hxx>
#include <BRep_Builder.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_Sewing.hxx>
#include <BRepLib.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <GC_MakeArcOfCircle.hxx>
#include <GCPnts_TangentialDeflection.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_Circle.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <GeomAPI_PointsToBSpline.hxx>
#include <gp_Ax2.hxx>
#include <gp_Circ.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>
#include <gp_Pnt2d.hxx>
#include <gp_Trsf.hxx>
#include <gp_Vec.hxx>
#include <Poly_Triangle.hxx>
#include <ShapeFix_Shape.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TopAbs.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopLoc_Location.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <TopTools_IndexedDataMapOfShapeListOfShape.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>

#include <algorithm>
#include <cmath>
#include <memory>

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

OCCTMeshRef OCCTMeshCreateFromArrays(
    const float* vertices,
    uint32_t vertexCount,
    const float* normals,
    const uint32_t* indices,
    uint32_t indexCount
) {
    if (!vertices || !indices) return nullptr;
    if (vertexCount == 0 || indexCount == 0) return nullptr;
    if (indexCount % 3 != 0) return nullptr;

    // Validate all indices are within range.
    for (uint32_t i = 0; i < indexCount; ++i) {
        if (indices[i] >= vertexCount) return nullptr;
    }

    try {
        std::unique_ptr<OCCTMesh> mesh(new OCCTMesh());

        // Vertices: copy 3 floats per vertex.
        mesh->vertices.assign(vertices, vertices + (size_t)vertexCount * 3);

        // Indices: copy as-is.
        mesh->indices.assign(indices, indices + indexCount);

        const uint32_t triangleCount = indexCount / 3;

        // Per-triangle normals (always computed — match the existing internal contract).
        mesh->triangleNormals.resize((size_t)triangleCount * 3, 0.0f);
        for (uint32_t t = 0; t < triangleCount; ++t) {
            const uint32_t i0 = indices[t * 3 + 0];
            const uint32_t i1 = indices[t * 3 + 1];
            const uint32_t i2 = indices[t * 3 + 2];

            const float* p0 = &vertices[i0 * 3];
            const float* p1 = &vertices[i1 * 3];
            const float* p2 = &vertices[i2 * 3];

            const float ax = p1[0] - p0[0], ay = p1[1] - p0[1], az = p1[2] - p0[2];
            const float bx = p2[0] - p0[0], by = p2[1] - p0[1], bz = p2[2] - p0[2];
            float nx = ay * bz - az * by;
            float ny = az * bx - ax * bz;
            float nz = ax * by - ay * bx;
            const float len = std::sqrt(nx * nx + ny * ny + nz * nz);
            if (len > 0.0f) {
                nx /= len; ny /= len; nz /= len;
            }
            mesh->triangleNormals[t * 3 + 0] = nx;
            mesh->triangleNormals[t * 3 + 1] = ny;
            mesh->triangleNormals[t * 3 + 2] = nz;
        }

        // Per-vertex normals: copy if provided, otherwise compute by averaging
        // adjacent triangle normals (smooth shading default).
        mesh->normals.resize((size_t)vertexCount * 3, 0.0f);
        if (normals) {
            std::copy(normals, normals + (size_t)vertexCount * 3, mesh->normals.begin());
        } else {
            for (uint32_t t = 0; t < triangleCount; ++t) {
                const float nx = mesh->triangleNormals[t * 3 + 0];
                const float ny = mesh->triangleNormals[t * 3 + 1];
                const float nz = mesh->triangleNormals[t * 3 + 2];
                for (int k = 0; k < 3; ++k) {
                    const uint32_t vi = indices[t * 3 + k];
                    mesh->normals[vi * 3 + 0] += nx;
                    mesh->normals[vi * 3 + 1] += ny;
                    mesh->normals[vi * 3 + 2] += nz;
                }
            }
            // Renormalize per-vertex accumulators.
            for (uint32_t v = 0; v < vertexCount; ++v) {
                float* n = &mesh->normals[v * 3];
                const float len = std::sqrt(n[0] * n[0] + n[1] * n[1] + n[2] * n[2]);
                if (len > 0.0f) {
                    n[0] /= len; n[1] /= len; n[2] /= len;
                }
            }
        }

        // No B-Rep source for these triangles.
        mesh->faceIndices.assign((size_t)triangleCount, -1);

        return mesh.release();
    } catch (...) {
        return nullptr;
    }
}


// MARK: - BRepMesh_Deflection (v0.61)
// MARK: - BRepMesh_Deflection (v0.61.0)

double OCCTComputeAbsoluteDeflection(OCCTShapeRef shape, double relativeDeflection, double maxShapeSize) {
    if (!shape) return -1.0;
    try {
        return BRepMesh_Deflection::ComputeAbsoluteDeflection(shape->shape, relativeDeflection, maxShapeSize);
    } catch (...) { return -1.0; }
}

bool OCCTDeflectionIsConsistent(double current, double required, bool allowDecrease, double ratio) {
    try {
        return BRepMesh_Deflection::IsConsistent(current, required, allowDecrease, ratio);
    } catch (...) { return false; }
}

// MARK: - BRepLib_ToolTriangulatedShape Compute Normals (v0.62)
// --- BRepLib_ToolTriangulatedShape ---

bool OCCTBRepLibComputeNormals(OCCTShapeRef shape) {
    if (!shape) return false;
    try {
        bool computedAny = false;
        TopExp_Explorer exp(shape->shape, TopAbs_FACE);
        for (; exp.More(); exp.Next()) {
            TopoDS_Face face = TopoDS::Face(exp.Current());
            TopLoc_Location loc;
            Handle(Poly_Triangulation) tri = BRep_Tool::Triangulation(face, loc);
            if (!tri.IsNull()) {
                BRepLib_ToolTriangulatedShape::ComputeNormals(face, tri);
                computedAny = true;
            }
        }
        return computedAny;
    } catch (...) { return false; }
}

// MARK: - BRepLib_PointCloudShape (v0.62)
// --- BRepLib_PointCloudShape ---

class OCCTPointCloudCollector : public BRepLib_PointCloudShape {
public:
    OCCTPointCloudCollector(const TopoDS_Shape& s) : BRepLib_PointCloudShape(s, 0.0) {}
    std::vector<gp_Pnt> pts;
    std::vector<gp_Vec> norms;
protected:
    void addPoint(const gp_Pnt& thePoint,
                  const gp_Vec& theNorm,
                  const gp_Pnt2d& /*theUV*/,
                  const TopoDS_Shape& /*theFace*/) override {
        pts.push_back(thePoint);
        norms.push_back(theNorm);
    }
};

static bool copyPointCloudResults(OCCTPointCloudCollector& pcs,
    double* _Nullable * _Nonnull outPoints,
    double* _Nullable * _Nonnull outNormals,
    int32_t* outCount) {
    int32_t n = (int32_t)pcs.pts.size();
    if (n == 0) { *outCount = 0; *outPoints = nullptr; *outNormals = nullptr; return false; }
    *outCount = n;
    *outPoints = (double*)malloc(n * 3 * sizeof(double));
    *outNormals = (double*)malloc(n * 3 * sizeof(double));
    for (int32_t i = 0; i < n; i++) {
        (*outPoints)[i*3]   = pcs.pts[i].X();
        (*outPoints)[i*3+1] = pcs.pts[i].Y();
        (*outPoints)[i*3+2] = pcs.pts[i].Z();
        (*outNormals)[i*3]   = pcs.norms[i].X();
        (*outNormals)[i*3+1] = pcs.norms[i].Y();
        (*outNormals)[i*3+2] = pcs.norms[i].Z();
    }
    return true;
}

bool OCCTBRepLibPointCloudByTriangulation(OCCTShapeRef shape,
    double* _Nullable * _Nonnull outPoints,
    double* _Nullable * _Nonnull outNormals,
    int32_t* outCount) {
    if (!shape) return false;
    try {
        OCCTPointCloudCollector pcs(shape->shape);
        if (!pcs.GeneratePointsByTriangulation()) return false;
        return copyPointCloudResults(pcs, outPoints, outNormals, outCount);
    } catch (...) { return false; }
}

bool OCCTBRepLibPointCloudByDensity(OCCTShapeRef shape, double density,
    double* _Nullable * _Nonnull outPoints,
    double* _Nullable * _Nonnull outNormals,
    int32_t* outCount) {
    if (!shape) return false;
    try {
        OCCTPointCloudCollector pcs(shape->shape);
        if (!pcs.GeneratePointsByDensity(density)) return false;
        return copyPointCloudResults(pcs, outPoints, outNormals, outCount);
    } catch (...) { return false; }
}

// MARK: - ShapeConstruct_MakeTriangulation (v0.74)
// --- ShapeConstruct_MakeTriangulation ---

OCCTShapeRef _Nullable OCCTShapeConstructTriangulationFromPoints(
    const double* _Nonnull coords, int32_t pointCount) {
    if (pointCount < 3) return nullptr;
    try {
        NCollection_Array1<gp_Pnt> points(1, pointCount);
        for (int32_t i = 0; i < pointCount; i++) {
            points.SetValue(i + 1, gp_Pnt(coords[i*3], coords[i*3+1], coords[i*3+2]));
        }
        ShapeConstruct_MakeTriangulation maker(points);
        maker.Build();
        if (!maker.IsDone()) return nullptr;
        TopoDS_Shape result = maker.Shape();
        if (result.IsNull()) return nullptr;
        auto* ref = new OCCTShape();
        ref->shape = result;
        return ref;
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef _Nullable OCCTShapeConstructTriangulationFromWire(OCCTWireRef _Nonnull wire) {
    if (!wire) return nullptr;
    try {
        ShapeConstruct_MakeTriangulation maker(wire->wire);
        maker.Build();
        if (!maker.IsDone()) return nullptr;
        TopoDS_Shape result = maker.Shape();
        if (result.IsNull()) return nullptr;
        auto* ref = new OCCTShape();
        ref->shape = result;
        return ref;
    } catch (...) {
        return nullptr;
    }
}

// MARK: - BRepMesh_ShapeTool (v0.74)
// --- BRepMesh_ShapeTool ---

double OCCTMeshShapeToolMaxFaceTolerance(OCCTFaceRef _Nonnull face) {
    if (!face) return 0;
    try {
        return BRepMesh_ShapeTool::MaxFaceTolerance(TopoDS::Face(face->face));
    } catch (...) {
        return 0;
    }
}

double OCCTMeshShapeToolBoxMaxDimension(OCCTShapeRef _Nonnull shape) {
    if (!shape) return 0;
    try {
        Bnd_Box bbox;
        BRepBndLib::Add(shape->shape, bbox);
        double maxDim = 0;
        BRepMesh_ShapeTool::BoxMaxDimension(bbox, maxDim);
        return maxDim;
    } catch (...) {
        return 0;
    }
}

OCCTUVPointsResult OCCTMeshShapeToolUVPoints(OCCTEdgeRef _Nonnull edge, OCCTFaceRef _Nonnull face) {
    OCCTUVPointsResult result = {};
    if (!edge || !face) return result;
    try {
        gp_Pnt2d uv1, uv2;
        result.success = BRepMesh_ShapeTool::UVPoints(
            TopoDS::Edge(edge->edge), TopoDS::Face(face->face), uv1, uv2);
        if (result.success) {
            result.u1 = uv1.X(); result.v1 = uv1.Y();
            result.u2 = uv2.X(); result.v2 = uv2.Y();
        }
    } catch (...) {}
    return result;
}
