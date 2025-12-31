//
//  OCCTBridge.h
//  OCCTSwift
//
//  Objective-C++ bridge to OpenCASCADE Technology
//

#ifndef OCCTBridge_h
#define OCCTBridge_h

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

// MARK: - Opaque Handle Types

typedef struct OCCTShape* OCCTShapeRef;
typedef struct OCCTWire* OCCTWireRef;
typedef struct OCCTMesh* OCCTMeshRef;
typedef struct OCCTFace* OCCTFaceRef;

// MARK: - Shape Creation (Primitives)

OCCTShapeRef OCCTShapeCreateBox(double width, double height, double depth);
OCCTShapeRef OCCTShapeCreateBoxAt(double x, double y, double z, double width, double height, double depth);
OCCTShapeRef OCCTShapeCreateCylinder(double radius, double height);
OCCTShapeRef OCCTShapeCreateCylinderAt(double cx, double cy, double bottomZ, double radius, double height);
OCCTShapeRef OCCTShapeCreateToolSweep(double radius, double height, double x1, double y1, double z1, double x2, double y2, double z2);
OCCTShapeRef OCCTShapeCreateSphere(double radius);
OCCTShapeRef OCCTShapeCreateCone(double bottomRadius, double topRadius, double height);
OCCTShapeRef OCCTShapeCreateTorus(double majorRadius, double minorRadius);

// MARK: - Shape Creation (Sweeps)

OCCTShapeRef OCCTShapeCreatePipeSweep(OCCTWireRef profile, OCCTWireRef path);
OCCTShapeRef OCCTShapeCreateExtrusion(OCCTWireRef profile, double dx, double dy, double dz, double length);
OCCTShapeRef OCCTShapeCreateRevolution(OCCTWireRef profile, double axisX, double axisY, double axisZ, double dirX, double dirY, double dirZ, double angle);
OCCTShapeRef OCCTShapeCreateLoft(const OCCTWireRef* profiles, int32_t count, bool solid);

// MARK: - Boolean Operations

OCCTShapeRef OCCTShapeUnion(OCCTShapeRef shape1, OCCTShapeRef shape2);
OCCTShapeRef OCCTShapeSubtract(OCCTShapeRef shape1, OCCTShapeRef shape2);
OCCTShapeRef OCCTShapeIntersect(OCCTShapeRef shape1, OCCTShapeRef shape2);

// MARK: - Modifications

OCCTShapeRef OCCTShapeFillet(OCCTShapeRef shape, double radius);
OCCTShapeRef OCCTShapeChamfer(OCCTShapeRef shape, double distance);
OCCTShapeRef OCCTShapeShell(OCCTShapeRef shape, double thickness);
OCCTShapeRef OCCTShapeOffset(OCCTShapeRef shape, double distance);

// MARK: - Transformations

OCCTShapeRef OCCTShapeTranslate(OCCTShapeRef shape, double dx, double dy, double dz);
OCCTShapeRef OCCTShapeRotate(OCCTShapeRef shape, double axisX, double axisY, double axisZ, double angle);
OCCTShapeRef OCCTShapeScale(OCCTShapeRef shape, double factor);
OCCTShapeRef OCCTShapeMirror(OCCTShapeRef shape, double originX, double originY, double originZ, double normalX, double normalY, double normalZ);

// MARK: - Compound

OCCTShapeRef OCCTShapeCreateCompound(const OCCTShapeRef* shapes, int32_t count);

// MARK: - Validation

bool OCCTShapeIsValid(OCCTShapeRef shape);
OCCTShapeRef OCCTShapeHeal(OCCTShapeRef shape);

// MARK: - Meshing

OCCTMeshRef OCCTShapeCreateMesh(OCCTShapeRef shape, double linearDeflection, double angularDeflection);

/// Enhanced mesh parameters for fine control over tessellation
typedef struct {
    double deflection;           // Linear deflection for boundary edges
    double angle;                // Angular deflection for boundary edges (radians)
    double deflectionInterior;   // Linear deflection for face interior (0 = same as deflection)
    double angleInterior;        // Angular deflection for face interior (0 = same as angle)
    double minSize;              // Minimum element size (0 = no minimum)
    bool relative;               // Use relative deflection (proportion of edge size)
    bool inParallel;             // Enable multi-threaded meshing
    bool internalVertices;       // Generate vertices inside faces
    bool controlSurfaceDeflection; // Validate surface approximation quality
    bool adjustMinSize;          // Auto-adjust minSize based on edge size
} OCCTMeshParameters;

/// Create mesh with enhanced parameters
OCCTMeshRef OCCTShapeCreateMeshWithParams(OCCTShapeRef shape, OCCTMeshParameters params);

/// Get default mesh parameters
OCCTMeshParameters OCCTMeshParametersDefault(void);

// MARK: - Edge Discretization

/// Get discretized edge as polyline points
/// @param shape The shape containing edges
/// @param edgeIndex Index of the edge (0-based)
/// @param deflection Linear deflection for discretization
/// @param outPoints Output array for points [x,y,z,...] (caller allocates)
/// @param maxPoints Maximum points to return
/// @return Number of points written, or -1 on error
int32_t OCCTShapeGetEdgePolyline(OCCTShapeRef shape, int32_t edgeIndex, double deflection, double* outPoints, int32_t maxPoints);

// MARK: - Triangle Access

/// Triangle data with face reference
typedef struct {
    uint32_t v1, v2, v3;    // Vertex indices
    int32_t faceIndex;       // Source B-Rep face index (-1 if unknown)
    float nx, ny, nz;        // Triangle normal
} OCCTTriangle;

/// Get triangles with face association and normals
/// @param mesh The mesh to query
/// @param outTriangles Output array (caller allocates with triangleCount elements)
/// @return Number of triangles written
int32_t OCCTMeshGetTrianglesWithFaces(OCCTMeshRef mesh, OCCTTriangle* outTriangles);

// MARK: - Mesh to Shape Conversion

/// Convert a mesh (triangulation) to a B-Rep shape (compound of faces)
/// @param mesh The mesh to convert
/// @return Shape containing triangulated faces, or NULL on failure
OCCTShapeRef OCCTMeshToShape(OCCTMeshRef mesh);

// MARK: - Mesh Booleans (via B-Rep roundtrip)

/// Perform boolean union on two meshes
/// @param mesh1 First mesh
/// @param mesh2 Second mesh
/// @param deflection Deflection for re-meshing result
/// @return Result mesh, or NULL on failure
OCCTMeshRef OCCTMeshUnion(OCCTMeshRef mesh1, OCCTMeshRef mesh2, double deflection);

/// Perform boolean subtraction on two meshes (mesh1 - mesh2)
OCCTMeshRef OCCTMeshSubtract(OCCTMeshRef mesh1, OCCTMeshRef mesh2, double deflection);

/// Perform boolean intersection on two meshes
OCCTMeshRef OCCTMeshIntersect(OCCTMeshRef mesh1, OCCTMeshRef mesh2, double deflection);

// MARK: - Memory Management

void OCCTShapeRelease(OCCTShapeRef shape);
void OCCTWireRelease(OCCTWireRef wire);
void OCCTMeshRelease(OCCTMeshRef mesh);

// MARK: - Wire Creation (2D Profiles)

OCCTWireRef OCCTWireCreateRectangle(double width, double height);
OCCTWireRef OCCTWireCreateCircle(double radius);
OCCTWireRef OCCTWireCreatePolygon(const double* points, int32_t pointCount, bool closed);
OCCTWireRef OCCTWireCreateFromPoints3D(const double* points, int32_t pointCount, bool closed);

// MARK: - Wire Creation (3D Paths)

OCCTWireRef OCCTWireCreateLine(double x1, double y1, double z1, double x2, double y2, double z2);
OCCTWireRef OCCTWireCreateArc(double centerX, double centerY, double centerZ, double radius, double startAngle, double endAngle, double normalX, double normalY, double normalZ);
OCCTWireRef OCCTWireCreateBSpline(const double* controlPoints, int32_t pointCount);
OCCTWireRef OCCTWireJoin(const OCCTWireRef* wires, int32_t count);

// MARK: - NURBS Curve Creation

/// Create a NURBS curve with full control over all parameters
/// @param poles Control points as [x,y,z] triplets (count = poleCount * 3)
/// @param poleCount Number of control points
/// @param weights Weight for each control point (count = poleCount, NULL for uniform weights)
/// @param knots Knot values (count = knotCount)
/// @param knotCount Number of distinct knot values
/// @param multiplicities Multiplicity of each knot (count = knotCount, NULL for all 1s)
/// @param degree Curve degree (1=linear, 2=quadratic, 3=cubic, etc.)
OCCTWireRef OCCTWireCreateNURBS(
    const double* poles,
    int32_t poleCount,
    const double* weights,
    const double* knots,
    int32_t knotCount,
    const int32_t* multiplicities,
    int32_t degree
);

/// Create a NURBS curve with uniform knots (clamped, uniform parameterization)
/// @param poles Control points as [x,y,z] triplets (count = poleCount * 3)
/// @param poleCount Number of control points
/// @param weights Weight for each control point (NULL for uniform weights = non-rational B-spline)
/// @param degree Curve degree (1=linear, 2=quadratic, 3=cubic)
OCCTWireRef OCCTWireCreateNURBSUniform(
    const double* poles,
    int32_t poleCount,
    const double* weights,
    int32_t degree
);

/// Create a clamped cubic B-spline through given control points (non-rational)
/// @param poles Control points as [x,y,z] triplets
/// @param poleCount Number of control points (minimum 4 for cubic)
OCCTWireRef OCCTWireCreateCubicBSpline(const double* poles, int32_t poleCount);

// MARK: - Mesh Access

int32_t OCCTMeshGetVertexCount(OCCTMeshRef mesh);
int32_t OCCTMeshGetTriangleCount(OCCTMeshRef mesh);
void OCCTMeshGetVertices(OCCTMeshRef mesh, float* outVertices);
void OCCTMeshGetNormals(OCCTMeshRef mesh, float* outNormals);
void OCCTMeshGetIndices(OCCTMeshRef mesh, uint32_t* outIndices);

// MARK: - Export

bool OCCTExportSTL(OCCTShapeRef shape, const char* path, double deflection);
bool OCCTExportSTEP(OCCTShapeRef shape, const char* path);
bool OCCTExportSTEPWithName(OCCTShapeRef shape, const char* path, const char* name);

// MARK: - Import

OCCTShapeRef OCCTImportSTEP(const char* path);

// MARK: - Robust STEP Import

/// Import result structure with diagnostics
typedef struct {
    OCCTShapeRef shape;
    int originalType;   // TopAbs_ShapeEnum: 0=Compound, 1=CompSolid, 2=Solid, 3=Shell, 4=Face, etc.
    int resultType;     // Type after processing
    bool sewingApplied;
    bool solidCreated;
    bool healingApplied;
} OCCTSTEPImportResult;

/// Import STEP file with robust handling: sewing, solid creation, and shape healing
OCCTShapeRef OCCTImportSTEPRobust(const char* path);

/// Import STEP file with diagnostic information
OCCTSTEPImportResult OCCTImportSTEPWithDiagnostics(const char* path);

/// Get shape type (TopAbs_ShapeEnum value)
int OCCTShapeGetType(OCCTShapeRef shape);

/// Check if shape is a valid closed solid
bool OCCTShapeIsValidSolid(OCCTShapeRef shape);

// MARK: - Bounds

void OCCTShapeGetBounds(OCCTShapeRef shape, double* minX, double* minY, double* minZ, double* maxX, double* maxY, double* maxZ);

// MARK: - Slicing

OCCTShapeRef OCCTShapeSliceAtZ(OCCTShapeRef shape, double z);
int32_t OCCTShapeGetEdgeCount(OCCTShapeRef shape);
int32_t OCCTShapeGetEdgePoints(OCCTShapeRef shape, int32_t edgeIndex, double* outPoints, int32_t maxPoints);
int32_t OCCTShapeGetContourPoints(OCCTShapeRef shape, double* outPoints, int32_t maxPoints);

// MARK: - CAM Operations

/// Offset a planar wire by a distance (positive = outward, negative = inward)
/// @param wire The wire to offset (must be planar)
/// @param distance Offset distance (positive = outward, negative = inward)
/// @param joinType Join type: 0 = arc (round corners), 1 = intersection (sharp corners)
/// @return Offset wire, or NULL on failure
OCCTWireRef OCCTWireOffset(OCCTWireRef wire, double distance, int32_t joinType);

/// Get closed wires from a shape section at Z level
/// @param shape The shape to section
/// @param z The Z level to section at
/// @param tolerance Tolerance for connecting edges into wires (use 1e-6 for default)
/// @param outCount Output: number of wires returned
/// @return Array of wire references, or NULL on failure. Caller must free with OCCTFreeWireArray.
OCCTWireRef* OCCTShapeSectionWiresAtZ(OCCTShapeRef shape, double z, double tolerance, int32_t* outCount);

/// Free an array of wires returned by OCCTShapeSectionWiresAtZ (frees wires AND array)
/// @param wires Array of wire references
/// @param count Number of wires in the array
void OCCTFreeWireArray(OCCTWireRef* wires, int32_t count);

/// Free only the array container, not the wires - use when Swift takes ownership of wire handles
/// @param wires Array of wire references
void OCCTFreeWireArrayOnly(OCCTWireRef* wires);

// MARK: - Face Analysis (for solid-based CAM)

/// Get all faces from a shape
/// @param shape The shape to extract faces from
/// @param outCount Output: number of faces returned
/// @return Array of face references, or NULL on failure. Caller must free with OCCTFreeFaceArray.
OCCTFaceRef* OCCTShapeGetFaces(OCCTShapeRef shape, int32_t* outCount);

/// Free an array of faces (frees faces AND array)
/// @param faces Array of face references
/// @param count Number of faces in the array
void OCCTFreeFaceArray(OCCTFaceRef* faces, int32_t count);

/// Free only the face array container, not the faces - use when Swift takes ownership
/// @param faces Array of face references
void OCCTFreeFaceArrayOnly(OCCTFaceRef* faces);

/// Release a single face
void OCCTFaceRelease(OCCTFaceRef face);

/// Get the normal vector at the center of a face
/// @param face The face to get normal from
/// @param outNx, outNy, outNz Output: normal vector components
/// @return true if successful, false if normal could not be computed
bool OCCTFaceGetNormal(OCCTFaceRef face, double* outNx, double* outNy, double* outNz);

/// Get the outer wire (boundary) of a face
/// @param face The face to get outer wire from
/// @return Wire reference, or NULL on failure. Caller must release with OCCTWireRelease.
OCCTWireRef OCCTFaceGetOuterWire(OCCTFaceRef face);

/// Get the bounding box of a face
/// @param face The face to get bounds from
void OCCTFaceGetBounds(OCCTFaceRef face, double* minX, double* minY, double* minZ, double* maxX, double* maxY, double* maxZ);

/// Check if a face is planar (flat)
/// @param face The face to check
/// @return true if the face is planar
bool OCCTFaceIsPlanar(OCCTFaceRef face);

/// Get the Z level of a horizontal planar face
/// @param face The face to get Z from
/// @param outZ Output: Z coordinate of the face plane
/// @return true if face is horizontal and Z was computed, false otherwise
bool OCCTFaceGetZLevel(OCCTFaceRef face, double* outZ);

/// Get horizontal faces from a shape (faces with normals pointing up or down)
/// @param shape The shape to search
/// @param tolerance Angle tolerance in radians (e.g., 0.01 for ~0.5 degrees)
/// @param outCount Output: number of faces returned
/// @return Array of face references for horizontal faces only
OCCTFaceRef* OCCTShapeGetHorizontalFaces(OCCTShapeRef shape, double tolerance, int32_t* outCount);

/// Get upward-facing horizontal faces (potential pocket floors)
/// @param shape The shape to search
/// @param tolerance Angle tolerance in radians
/// @param outCount Output: number of faces returned
/// @return Array of face references for upward-facing horizontal faces
OCCTFaceRef* OCCTShapeGetUpwardFaces(OCCTShapeRef shape, double tolerance, int32_t* outCount);

#ifdef __cplusplus
}
#endif

#endif /* OCCTBridge_h */
