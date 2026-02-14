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

// MARK: - Measurement & Analysis (v0.7.0)

/// Mass properties result structure
typedef struct {
    double volume;           // Cubic units
    double surfaceArea;      // Square units
    double mass;             // With density applied
    double centerX, centerY, centerZ;  // Center of mass
    double ixx, ixy, ixz;    // Inertia tensor row 1
    double iyx, iyy, iyz;    // Inertia tensor row 2
    double izx, izy, izz;    // Inertia tensor row 3
    bool isValid;
} OCCTShapeProperties;

/// Get full mass properties of a shape
/// @param shape The shape to analyze
/// @param density Density for mass calculation (use 1.0 for volume-only calculations)
/// @return Properties structure with isValid indicating success
OCCTShapeProperties OCCTShapeGetProperties(OCCTShapeRef shape, double density);

/// Get volume of a shape (convenience function)
/// @param shape The shape to measure
/// @return Volume in cubic units, or -1.0 on error
double OCCTShapeGetVolume(OCCTShapeRef shape);

/// Get surface area of a shape (convenience function)
/// @param shape The shape to measure
/// @return Surface area in square units, or -1.0 on error
double OCCTShapeGetSurfaceArea(OCCTShapeRef shape);

/// Get center of mass of a shape (convenience function)
/// @param shape The shape to analyze
/// @param outX, outY, outZ Output: center of mass coordinates
/// @return true on success, false on error
bool OCCTShapeGetCenterOfMass(OCCTShapeRef shape, double* outX, double* outY, double* outZ);

/// Distance measurement result structure
typedef struct {
    double distance;         // Minimum distance between shapes
    double p1x, p1y, p1z;    // Closest point on shape1
    double p2x, p2y, p2z;    // Closest point on shape2
    int32_t solutionCount;   // Number of solutions found
    bool isValid;
} OCCTDistanceResult;

/// Compute minimum distance between two shapes
/// @param shape1 First shape
/// @param shape2 Second shape
/// @param deflection Deflection tolerance for curved geometry (use 1e-6 for default)
/// @return Distance result with isValid indicating success
OCCTDistanceResult OCCTShapeDistance(OCCTShapeRef shape1, OCCTShapeRef shape2, double deflection);

/// Check if two shapes intersect (overlap in space)
/// @param shape1 First shape
/// @param shape2 Second shape
/// @param tolerance Tolerance for intersection test
/// @return true if shapes intersect or touch, false otherwise
bool OCCTShapeIntersects(OCCTShapeRef shape1, OCCTShapeRef shape2, double tolerance);

/// Get total number of vertices in a shape
int32_t OCCTShapeGetVertexCount(OCCTShapeRef shape);

/// Get vertex coordinates at index
/// @param shape The shape containing vertices
/// @param index Vertex index (0-based)
/// @param outX, outY, outZ Output: vertex coordinates
/// @return true on success, false if index out of bounds
bool OCCTShapeGetVertexAt(OCCTShapeRef shape, int32_t index, double* outX, double* outY, double* outZ);

/// Get all vertices as an array
/// @param shape The shape containing vertices
/// @param outVertices Output array for vertices [x,y,z,...] (caller allocates vertexCount*3 doubles)
/// @return Number of vertices written
int32_t OCCTShapeGetVertices(OCCTShapeRef shape, double* outVertices);

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

// MARK: - Shape Conversion

OCCTShapeRef OCCTShapeFromWire(OCCTWireRef wireRef);

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

// MARK: - Ray Casting & Selection (Issues #12, #13, #14)

/// Ray hit result structure
typedef struct {
    double point[3];        // 3D intersection point
    double normal[3];       // Surface normal at hit
    int32_t faceIndex;      // Index of hit face
    double distance;        // Distance from ray origin
    double uv[2];           // UV parameters on surface
} OCCTRayHit;

/// Cast ray against shape and return all intersections
/// @param shape The shape to test against
/// @param originX, originY, originZ Ray origin
/// @param dirX, dirY, dirZ Ray direction (will be normalized)
/// @param tolerance Intersection tolerance
/// @param outHits Output array for hits (caller allocates)
/// @param maxHits Maximum number of hits to return
/// @return Number of hits found, or -1 on error
int32_t OCCTShapeRaycast(
    OCCTShapeRef shape,
    double originX, double originY, double originZ,
    double dirX, double dirY, double dirZ,
    double tolerance,
    OCCTRayHit* outHits,
    int32_t maxHits
);

/// Get total number of faces in a shape
int32_t OCCTShapeGetFaceCount(OCCTShapeRef shape);

/// Get face by index (0-based)
/// @param shape The shape containing faces
/// @param index Face index (0-based)
/// @return Face reference, or NULL if index out of bounds
OCCTFaceRef OCCTShapeGetFaceAtIndex(OCCTShapeRef shape, int32_t index);

// MARK: - Edge Access (Issue #14)

typedef struct OCCTEdge* OCCTEdgeRef;

/// Get total number of edges in a shape
int32_t OCCTShapeGetTotalEdgeCount(OCCTShapeRef shape);

/// Get edge by index (0-based)
/// @param shape The shape containing edges
/// @param index Edge index (0-based)
/// @return Edge reference, or NULL if index out of bounds. Caller must release.
OCCTEdgeRef OCCTShapeGetEdgeAtIndex(OCCTShapeRef shape, int32_t index);

/// Release an edge reference
void OCCTEdgeRelease(OCCTEdgeRef edge);

/// Get edge length
double OCCTEdgeGetLength(OCCTEdgeRef edge);

/// Get edge bounding box
void OCCTEdgeGetBounds(OCCTEdgeRef edge, double* minX, double* minY, double* minZ, double* maxX, double* maxY, double* maxZ);

/// Get points along edge curve
/// @param edge The edge to sample
/// @param count Number of points to generate
/// @param outPoints Output array [x,y,z,...] (caller allocates count*3 doubles)
/// @return Actual number of points written
int32_t OCCTEdgeGetPoints(OCCTEdgeRef edge, int32_t count, double* outPoints);

/// Check if edge is a line
bool OCCTEdgeIsLine(OCCTEdgeRef edge);

/// Check if edge is a circle/arc
bool OCCTEdgeIsCircle(OCCTEdgeRef edge);

/// Get start and end vertices of edge
void OCCTEdgeGetEndpoints(OCCTEdgeRef edge, double* startX, double* startY, double* startZ, double* endX, double* endY, double* endZ);


// MARK: - Attributed Adjacency Graph (AAG) Support

/// Edge convexity type for AAG
typedef enum {
    OCCTEdgeConvexityConcave = -1,  // Interior angle > 180° (pocket-like)
    OCCTEdgeConvexitySmooth = 0,    // Tangent faces (180°)
    OCCTEdgeConvexityConvex = 1     // Interior angle < 180° (fillet-like)
} OCCTEdgeConvexity;

/// Get the two faces adjacent to an edge within a shape
/// @param shape The shape containing the edge and faces
/// @param edge The edge to query
/// @param outFace1 Output: first adjacent face (caller must release)
/// @param outFace2 Output: second adjacent face (caller must release), may be NULL for boundary edges
/// @return Number of adjacent faces (0, 1, or 2)
int32_t OCCTEdgeGetAdjacentFaces(OCCTShapeRef shape, OCCTEdgeRef edge, OCCTFaceRef* outFace1, OCCTFaceRef* outFace2);

/// Determine the convexity of an edge between two faces
/// @param shape The shape containing the geometry
/// @param edge The shared edge
/// @param face1 First adjacent face
/// @param face2 Second adjacent face
/// @return Convexity type (concave, smooth, or convex)
OCCTEdgeConvexity OCCTEdgeGetConvexity(OCCTShapeRef shape, OCCTEdgeRef edge, OCCTFaceRef face1, OCCTFaceRef face2);

/// Get all edges shared between two faces
/// @param shape The shape containing the faces
/// @param face1 First face
/// @param face2 Second face  
/// @param outEdges Output array for shared edges (caller allocates)
/// @param maxEdges Maximum number of edges to return
/// @return Number of shared edges found
int32_t OCCTFaceGetSharedEdges(OCCTShapeRef shape, OCCTFaceRef face1, OCCTFaceRef face2, OCCTEdgeRef* outEdges, int32_t maxEdges);

/// Check if two faces are adjacent (share at least one edge)
bool OCCTFacesAreAdjacent(OCCTShapeRef shape, OCCTFaceRef face1, OCCTFaceRef face2);

/// Get the dihedral angle between two adjacent faces at their shared edge
/// @param edge The shared edge
/// @param face1 First face
/// @param face2 Second face
/// @param parameter Parameter along edge (0.0 to 1.0) where to measure angle
/// @return Dihedral angle in radians (0 to 2*PI), or -1 on error
double OCCTEdgeGetDihedralAngle(OCCTEdgeRef edge, OCCTFaceRef face1, OCCTFaceRef face2, double parameter);


// MARK: - XDE/XCAF Document Support (v0.6.0)

/// Opaque handle for XDE document
typedef struct OCCTDocument* OCCTDocumentRef;

/// Create a new empty XDE document
OCCTDocumentRef OCCTDocumentCreate(void);

/// Load STEP file into XDE document with assembly structure, names, colors, materials
/// @param path Path to STEP file
/// @return Document reference, or NULL on failure
OCCTDocumentRef OCCTDocumentLoadSTEP(const char* path);

/// Write document to STEP file (preserves assembly structure, colors, materials)
/// @param doc Document to write
/// @param path Output file path
/// @return true on success
bool OCCTDocumentWriteSTEP(OCCTDocumentRef doc, const char* path);

/// Release document and all internal resources
void OCCTDocumentRelease(OCCTDocumentRef doc);

// MARK: - XDE Assembly Traversal

/// Get number of root (top-level/free) shapes in document
int32_t OCCTDocumentGetRootCount(OCCTDocumentRef doc);

/// Get label ID for root shape at index
/// @param doc Document
/// @param index Root index (0-based)
/// @return Label ID, or -1 if index out of bounds
int64_t OCCTDocumentGetRootLabelId(OCCTDocumentRef doc, int32_t index);

/// Get name for a label
/// @param doc Document
/// @param labelId Label identifier
/// @return Name string (caller must free with OCCTStringFree), or NULL if no name
const char* OCCTDocumentGetLabelName(OCCTDocumentRef doc, int64_t labelId);

/// Check if label represents an assembly (has components)
bool OCCTDocumentIsAssembly(OCCTDocumentRef doc, int64_t labelId);

/// Check if label is a reference (instance of another shape)
bool OCCTDocumentIsReference(OCCTDocumentRef doc, int64_t labelId);

/// Get number of child components for an assembly label
int32_t OCCTDocumentGetChildCount(OCCTDocumentRef doc, int64_t labelId);

/// Get child label ID at index
/// @param doc Document
/// @param parentLabelId Parent assembly label
/// @param index Child index (0-based)
/// @return Child label ID, or -1 if index out of bounds
int64_t OCCTDocumentGetChildLabelId(OCCTDocumentRef doc, int64_t parentLabelId, int32_t index);

/// Get the referred shape label for a reference
/// @param doc Document
/// @param refLabelId Reference label ID
/// @return Referred label ID, or -1 if not a reference
int64_t OCCTDocumentGetReferredLabelId(OCCTDocumentRef doc, int64_t refLabelId);

/// Get shape for a label (without location transform applied)
/// @param doc Document
/// @param labelId Label identifier
/// @return Shape reference (caller must release), or NULL on failure
OCCTShapeRef OCCTDocumentGetShape(OCCTDocumentRef doc, int64_t labelId);

/// Get shape with location transform applied
/// @param doc Document
/// @param labelId Label identifier
/// @return Shape reference with transform applied (caller must release), or NULL on failure
OCCTShapeRef OCCTDocumentGetShapeWithLocation(OCCTDocumentRef doc, int64_t labelId);

// MARK: - XDE Transforms

/// Get location transform as 4x4 matrix (column-major, suitable for simd_float4x4)
/// @param doc Document
/// @param labelId Label identifier
/// @param outMatrix16 Output array for 16 floats (column-major 4x4 matrix)
void OCCTDocumentGetLocation(OCCTDocumentRef doc, int64_t labelId, float* outMatrix16);

// MARK: - XDE Colors

/// Color type (matches XCAFDoc_ColorType)
typedef enum {
    OCCTColorTypeGeneric = 0,   // Generic color
    OCCTColorTypeSurface = 1,   // Surface color (overrides generic)
    OCCTColorTypeCurve = 2      // Curve color (overrides generic)
} OCCTColorType;

/// RGBA color with set flag
typedef struct {
    double r, g, b, a;
    bool isSet;
} OCCTColor;

/// Get color for a label
/// @param doc Document
/// @param labelId Label identifier
/// @param colorType Type of color to retrieve
/// @return Color structure (check isSet to see if color was assigned)
OCCTColor OCCTDocumentGetLabelColor(OCCTDocumentRef doc, int64_t labelId, OCCTColorType colorType);

/// Set color for a label
/// @param doc Document
/// @param labelId Label identifier
/// @param colorType Type of color to set
/// @param r, g, b RGB values (0.0-1.0)
void OCCTDocumentSetLabelColor(OCCTDocumentRef doc, int64_t labelId, OCCTColorType colorType, double r, double g, double b);

// MARK: - XDE Materials (PBR)

/// PBR Material properties
typedef struct {
    OCCTColor baseColor;
    double metallic;        // 0.0-1.0
    double roughness;       // 0.0-1.0
    OCCTColor emissive;
    double transparency;    // 0.0-1.0
    bool isSet;
} OCCTMaterial;

/// Get PBR material for a label
/// @param doc Document
/// @param labelId Label identifier
/// @return Material structure (check isSet to see if material was assigned)
OCCTMaterial OCCTDocumentGetLabelMaterial(OCCTDocumentRef doc, int64_t labelId);

/// Set PBR material for a label
/// @param doc Document
/// @param labelId Label identifier
/// @param material Material properties to set
void OCCTDocumentSetLabelMaterial(OCCTDocumentRef doc, int64_t labelId, OCCTMaterial material);

// MARK: - XDE Utility

/// Free a string returned by OCCTDocumentGetLabelName
void OCCTStringFree(const char* str);

// MARK: - 2D Drawing / HLR Projection (v0.6.0)

/// Opaque handle for 2D drawing (HLR projection result)
typedef struct OCCTDrawing* OCCTDrawingRef;

/// Projection type
typedef enum {
    OCCTProjectionOrthographic = 0,
    OCCTProjectionPerspective = 1
} OCCTProjectionType;

/// Edge visibility type
typedef enum {
    OCCTEdgeTypeVisible = 0,
    OCCTEdgeTypeHidden = 1,
    OCCTEdgeTypeOutline = 2
} OCCTEdgeType;

/// Create 2D projection using Hidden Line Removal (HLR)
/// @param shape Shape to project
/// @param dirX, dirY, dirZ View direction (will be normalized)
/// @param projectionType Orthographic or perspective projection
/// @return Drawing reference, or NULL on failure
OCCTDrawingRef OCCTDrawingCreate(OCCTShapeRef shape, double dirX, double dirY, double dirZ, OCCTProjectionType projectionType);

/// Release drawing resources
void OCCTDrawingRelease(OCCTDrawingRef drawing);

/// Get projected edges by visibility type as a compound shape
/// @param drawing Drawing to query
/// @param edgeType Type of edges to retrieve
/// @return Shape containing 2D edges (caller must release), or NULL if no edges
OCCTShapeRef OCCTDrawingGetEdges(OCCTDrawingRef drawing, OCCTEdgeType edgeType);


// MARK: - Advanced Modeling (v0.8.0)

/// Fillet specific edges with uniform radius
/// @param shape The shape to fillet
/// @param edgeIndices Array of edge indices (0-based)
/// @param edgeCount Number of edges to fillet
/// @param radius Fillet radius
/// @return Filleted shape, or NULL on failure
OCCTShapeRef OCCTShapeFilletEdges(OCCTShapeRef shape, const int32_t* edgeIndices,
                                   int32_t edgeCount, double radius);

/// Fillet specific edges with linear radius interpolation
/// @param shape The shape to fillet
/// @param edgeIndices Array of edge indices (0-based)
/// @param edgeCount Number of edges to fillet
/// @param startRadius Radius at start of each edge
/// @param endRadius Radius at end of each edge
/// @return Filleted shape, or NULL on failure
OCCTShapeRef OCCTShapeFilletEdgesLinear(OCCTShapeRef shape, const int32_t* edgeIndices,
                                         int32_t edgeCount, double startRadius, double endRadius);

/// Add draft angle to faces for mold release
/// @param shape The shape to draft
/// @param faceIndices Array of face indices (0-based)
/// @param faceCount Number of faces to draft
/// @param dirX, dirY, dirZ Pull direction (typically vertical)
/// @param angle Draft angle in radians
/// @param planeX, planeY, planeZ Point on neutral plane
/// @param planeNx, planeNy, planeNz Normal of neutral plane
/// @return Drafted shape, or NULL on failure
OCCTShapeRef OCCTShapeDraft(OCCTShapeRef shape, const int32_t* faceIndices, int32_t faceCount,
                            double dirX, double dirY, double dirZ, double angle,
                            double planeX, double planeY, double planeZ,
                            double planeNx, double planeNy, double planeNz);

/// Remove features (faces) from shape using defeaturing
/// @param shape The shape to modify
/// @param faceIndices Array of face indices to remove (0-based)
/// @param faceCount Number of faces to remove
/// @return Shape with features removed, or NULL on failure
OCCTShapeRef OCCTShapeRemoveFeatures(OCCTShapeRef shape, const int32_t* faceIndices, int32_t faceCount);

/// Pipe sweep mode for advanced sweeps
typedef enum {
    OCCTPipeModeFrenet = 0,           // Standard Frenet trihedron
    OCCTPipeModeCorrectedFrenet = 1,  // Corrected for singularities
    OCCTPipeModeFixedBinormal = 2,    // Fixed binormal direction
    OCCTPipeModeAuxiliary = 3         // Guided by auxiliary curve
} OCCTPipeMode;

/// Create pipe shell with sweep mode
/// @param spine Path wire for sweep
/// @param profile Profile wire to sweep
/// @param mode Sweep mode (Frenet, corrected Frenet, etc.)
/// @param solid If true, create solid; if false, create shell
/// @return Swept shape, or NULL on failure
OCCTShapeRef OCCTShapeCreatePipeShell(OCCTWireRef spine, OCCTWireRef profile,
                                       OCCTPipeMode mode, bool solid);

/// Create pipe shell with fixed binormal direction
/// @param spine Path wire for sweep
/// @param profile Profile wire to sweep
/// @param bnX, bnY, bnZ Fixed binormal direction
/// @param solid If true, create solid; if false, create shell
/// @return Swept shape, or NULL on failure
OCCTShapeRef OCCTShapeCreatePipeShellWithBinormal(OCCTWireRef spine, OCCTWireRef profile,
                                                   double bnX, double bnY, double bnZ, bool solid);

/// Create pipe shell guided by auxiliary spine
/// @param spine Main path wire
/// @param profile Profile wire to sweep
/// @param auxSpine Auxiliary spine for twist control
/// @param solid If true, create solid; if false, create shell
/// @return Swept shape, or NULL on failure
OCCTShapeRef OCCTShapeCreatePipeShellWithAuxSpine(OCCTWireRef spine, OCCTWireRef profile,
                                                   OCCTWireRef auxSpine, bool solid);


// MARK: - Surfaces & Curves (v0.9.0)

/// Curve analysis result structure
typedef struct {
    double length;
    bool isClosed;
    bool isPeriodic;
    double startX, startY, startZ;
    double endX, endY, endZ;
    bool isValid;
} OCCTCurveInfo;

/// Curve point with derivatives
typedef struct {
    double posX, posY, posZ;      // Position
    double tanX, tanY, tanZ;      // Tangent vector
    double curvature;              // Curvature magnitude
    double normX, normY, normZ;   // Principal normal (if curvature > 0)
    bool hasNormal;
    bool isValid;
} OCCTCurvePoint;

/// Get comprehensive curve information for a wire
/// @param wire The wire to analyze
/// @return Curve information structure with isValid indicating success
OCCTCurveInfo OCCTWireGetCurveInfo(OCCTWireRef wire);

/// Get the length of a wire
/// @param wire The wire to measure
/// @return Length in linear units, or -1.0 on error
double OCCTWireGetLength(OCCTWireRef wire);

/// Get point on wire at normalized parameter (0.0 to 1.0)
/// @param wire The wire to sample
/// @param param Parameter value from 0.0 (start) to 1.0 (end)
/// @param x, y, z Output: point coordinates
/// @return true on success, false on error
bool OCCTWireGetPointAt(OCCTWireRef wire, double param, double* x, double* y, double* z);

/// Get tangent vector at normalized parameter
/// @param wire The wire to sample
/// @param param Parameter value from 0.0 to 1.0
/// @param tx, ty, tz Output: tangent vector components (normalized)
/// @return true on success, false on error
bool OCCTWireGetTangentAt(OCCTWireRef wire, double param, double* tx, double* ty, double* tz);

/// Get curvature at normalized parameter
/// @param wire The wire to sample
/// @param param Parameter value from 0.0 to 1.0
/// @return Curvature value (1/radius), or -1.0 on error
double OCCTWireGetCurvatureAt(OCCTWireRef wire, double param);

/// Get full curve point with position, tangent, and curvature
/// @param wire The wire to sample
/// @param param Parameter value from 0.0 to 1.0
/// @return Curve point structure with isValid indicating success
OCCTCurvePoint OCCTWireGetCurvePointAt(OCCTWireRef wire, double param);

/// Offset wire in 3D space along a direction
/// @param wire The wire to offset
/// @param distance Offset distance
/// @param dirX, dirY, dirZ Direction vector for offset
/// @return Offset wire, or NULL on failure
OCCTWireRef OCCTWireOffset3D(OCCTWireRef wire, double distance, double dirX, double dirY, double dirZ);

/// Create B-spline surface from a grid of control points
/// @param poles Control points as [x,y,z,...] in row-major order (uCount * vCount * 3 doubles)
/// @param uCount Number of control points in U direction
/// @param vCount Number of control points in V direction
/// @param uDegree Degree in U direction (typically 3)
/// @param vDegree Degree in V direction (typically 3)
/// @return Face shape from B-spline surface, or NULL on failure
OCCTShapeRef OCCTShapeCreateBSplineSurface(const double* poles, int32_t uCount, int32_t vCount,
                                            int32_t uDegree, int32_t vDegree);

/// Create ruled surface between two wires
/// @param wire1 First boundary wire
/// @param wire2 Second boundary wire
/// @return Face shape from ruled surface, or NULL on failure
OCCTShapeRef OCCTShapeCreateRuled(OCCTWireRef wire1, OCCTWireRef wire2);

/// Create shell (hollow solid) with specific faces left open
/// @param shape The solid to shell
/// @param thickness Shell wall thickness (positive = inward, negative = outward)
/// @param openFaceIndices Array of face indices to leave open (0-based)
/// @param faceCount Number of faces to leave open
/// @return Shelled shape, or NULL on failure
OCCTShapeRef OCCTShapeShellWithOpenFaces(OCCTShapeRef shape, double thickness,
                                          const int32_t* openFaceIndices, int32_t faceCount);


// MARK: - IGES Import/Export (v0.10.0)

/// Import IGES file
/// @param path Path to IGES file
/// @return Shape reference, or NULL on failure
OCCTShapeRef OCCTImportIGES(const char* path);

/// Import IGES file with automatic repair (sewing, healing)
/// @param path Path to IGES file
/// @return Shape reference with healing applied, or NULL on failure
OCCTShapeRef OCCTImportIGESRobust(const char* path);

/// Export shape to IGES file
/// @param shape The shape to export
/// @param path Output file path
/// @return true on success
bool OCCTExportIGES(OCCTShapeRef shape, const char* path);


// MARK: - BREP Native Format (v0.10.0)

/// Import OCCT native BREP file
/// @param path Path to BREP file
/// @return Shape reference, or NULL on failure
OCCTShapeRef OCCTImportBREP(const char* path);

/// Export shape to OCCT native BREP file
/// @param shape The shape to export
/// @param path Output file path
/// @return true on success
bool OCCTExportBREP(OCCTShapeRef shape, const char* path);

/// Export shape to BREP file with options for triangulation
/// @param shape The shape to export
/// @param path Output file path
/// @param withTriangles Include triangulation data
/// @param withNormals Include normal data (only if withTriangles is true)
/// @return true on success
bool OCCTExportBREPWithTriangles(OCCTShapeRef shape, const char* path, bool withTriangles, bool withNormals);


// MARK: - Geometry Construction (v0.11.0)

/// Create a planar face from a closed wire
/// @param wire Closed wire defining the face boundary
/// @param planar If true, require the wire to be planar; if false, attempt to create face anyway
/// @return Face shape, or NULL on failure
OCCTShapeRef OCCTShapeCreateFaceFromWire(OCCTWireRef wire, bool planar);

/// Create a face with holes from an outer wire and inner wires
/// @param outer Outer boundary wire (closed)
/// @param holes Array of inner boundary wires (holes)
/// @param holeCount Number of holes
/// @return Face shape with holes, or NULL on failure
OCCTShapeRef OCCTShapeCreateFaceWithHoles(OCCTWireRef outer, const OCCTWireRef* holes, int32_t holeCount);

/// Create a solid from a closed shell
/// @param shell Shell shape (must be closed)
/// @return Solid shape, or NULL on failure
OCCTShapeRef OCCTShapeCreateSolidFromShell(OCCTShapeRef shell);

/// Sew multiple faces/shapes into a shell or solid
/// @param shapes Array of shapes to sew
/// @param count Number of shapes
/// @param tolerance Sewing tolerance (use 1e-6 for default)
/// @return Sewn shape (shell or solid), or NULL on failure
OCCTShapeRef OCCTShapeSew(const OCCTShapeRef* shapes, int32_t count, double tolerance);

/// Sew two shapes together
/// @param shape1 First shape
/// @param shape2 Second shape
/// @param tolerance Sewing tolerance
/// @return Sewn shape, or NULL on failure
OCCTShapeRef OCCTShapeSewTwo(OCCTShapeRef shape1, OCCTShapeRef shape2, double tolerance);

/// Create a smooth curve interpolating through given points
/// @param points Points as [x,y,z,...] triplets (count * 3 doubles)
/// @param count Number of points (minimum 2)
/// @param closed If true, create a closed (periodic) curve
/// @param tolerance Interpolation tolerance (use 1e-6 for default)
/// @return Wire representing the interpolated curve, or NULL on failure
OCCTWireRef OCCTWireInterpolate(const double* points, int32_t count, bool closed, double tolerance);

/// Create a curve interpolating through points with specified end tangents
/// @param points Points as [x,y,z,...] triplets (count * 3 doubles)
/// @param count Number of points (minimum 2)
/// @param startTanX, startTanY, startTanZ Tangent vector at start point
/// @param endTanX, endTanY, endTanZ Tangent vector at end point
/// @param tolerance Interpolation tolerance
/// @return Wire with specified end tangents, or NULL on failure
OCCTWireRef OCCTWireInterpolateWithTangents(const double* points, int32_t count,
                                             double startTanX, double startTanY, double startTanZ,
                                             double endTanX, double endTanY, double endTanZ,
                                             double tolerance);


// MARK: - Feature-Based Modeling (v0.12.0)

/// Add a prismatic boss to a shape by extruding a profile
/// @param shape The base shape to modify
/// @param profile Wire profile to extrude (must be on a face of shape)
/// @param dirX, dirY, dirZ Extrusion direction
/// @param height Extrusion height
/// @param fuse If true, fuse with base shape; if false, cut from base shape
/// @return Modified shape with boss/pocket, or NULL on failure
OCCTShapeRef OCCTShapePrism(OCCTShapeRef shape, OCCTWireRef profile,
                            double dirX, double dirY, double dirZ,
                            double height, bool fuse);

/// Drill a cylindrical hole into a shape
/// @param shape The shape to drill
/// @param posX, posY, posZ Position of hole center on surface
/// @param dirX, dirY, dirZ Drill direction (into the shape)
/// @param radius Hole radius
/// @param depth Hole depth (0 for through-hole)
/// @return Shape with hole, or NULL on failure
OCCTShapeRef OCCTShapeDrillHole(OCCTShapeRef shape,
                                 double posX, double posY, double posZ,
                                 double dirX, double dirY, double dirZ,
                                 double radius, double depth);

/// Split a shape using a cutting tool (wire, face, or shape)
/// @param shape The shape to split
/// @param tool The cutting tool
/// @param outCount Output: number of resulting shapes
/// @return Array of split shapes (caller must free with OCCTFreeShapeArray), or NULL on failure
OCCTShapeRef* OCCTShapeSplit(OCCTShapeRef shape, OCCTShapeRef tool, int32_t* outCount);

/// Split a shape by a plane
/// @param shape The shape to split
/// @param planeX, planeY, planeZ Point on the cutting plane
/// @param normalX, normalY, normalZ Normal vector of the cutting plane
/// @param outCount Output: number of resulting shapes
/// @return Array of split shapes (caller must free with OCCTFreeShapeArray), or NULL on failure
OCCTShapeRef* OCCTShapeSplitByPlane(OCCTShapeRef shape,
                                     double planeX, double planeY, double planeZ,
                                     double normalX, double normalY, double normalZ,
                                     int32_t* outCount);

/// Free an array of shapes returned by split operations
/// @param shapes Array of shape references
/// @param count Number of shapes in the array
void OCCTFreeShapeArray(OCCTShapeRef* shapes, int32_t count);

/// Free only the shape array container, not the shapes themselves
/// @param shapes Array of shape references
void OCCTFreeShapeArrayOnly(OCCTShapeRef* shapes);

/// Glue two shapes together at coincident faces
/// @param shape1 First shape
/// @param shape2 Second shape (must have faces coincident with shape1)
/// @param tolerance Tolerance for face matching
/// @return Glued shape, or NULL on failure
OCCTShapeRef OCCTShapeGlue(OCCTShapeRef shape1, OCCTShapeRef shape2, double tolerance);

/// Create an evolved shape (profile swept along spine with rotation)
/// @param spine The spine wire
/// @param profile The profile wire to sweep
/// @return Evolved shape, or NULL on failure
OCCTShapeRef OCCTShapeCreateEvolved(OCCTWireRef spine, OCCTWireRef profile);

/// Create a linear pattern of a shape
/// @param shape The shape to pattern
/// @param dirX, dirY, dirZ Direction of the pattern
/// @param spacing Distance between copies
/// @param count Number of copies (including original)
/// @return Compound of patterned shapes, or NULL on failure
OCCTShapeRef OCCTShapeLinearPattern(OCCTShapeRef shape,
                                     double dirX, double dirY, double dirZ,
                                     double spacing, int32_t count);

/// Create a circular pattern of a shape
/// @param shape The shape to pattern
/// @param axisX, axisY, axisZ Point on the rotation axis
/// @param axisDirX, axisDirY, axisDirZ Direction of the rotation axis
/// @param count Number of copies (including original)
/// @param angle Total angle to span (radians), 0 for full circle
/// @return Compound of patterned shapes, or NULL on failure
OCCTShapeRef OCCTShapeCircularPattern(OCCTShapeRef shape,
                                       double axisX, double axisY, double axisZ,
                                       double axisDirX, double axisDirY, double axisDirZ,
                                       int32_t count, double angle);

// MARK: - Shape Healing & Analysis (v0.13.0)

/// Shape analysis result structure
typedef struct {
    int32_t smallEdgeCount;        // Number of edges smaller than tolerance
    int32_t smallFaceCount;        // Number of faces smaller than tolerance
    int32_t gapCount;              // Number of gaps between edges/faces
    int32_t selfIntersectionCount; // Number of self-intersections
    int32_t freeEdgeCount;         // Number of free (unconnected) edges
    int32_t freeFaceCount;         // Number of free faces (shell not closed)
    bool hasInvalidTopology;       // Whether topology is invalid
    bool isValid;                  // Whether analysis succeeded
} OCCTShapeAnalysisResult;

/// Analyze a shape for problems
/// @param shape The shape to analyze
/// @param tolerance Tolerance for small feature detection
/// @return Analysis result with problem counts
OCCTShapeAnalysisResult OCCTShapeAnalyze(OCCTShapeRef shape, double tolerance);

/// Fix a wire (close gaps, remove degenerate edges, reorder)
/// @param wire The wire to fix
/// @param tolerance Tolerance for fixing operations
/// @return Fixed wire, or NULL on failure
OCCTWireRef OCCTWireFix(OCCTWireRef wire, double tolerance);

/// Fix a face (wire orientation, missing seams, surface parameters)
/// @param face The face to fix
/// @param tolerance Tolerance for fixing operations
/// @return Fixed face as a shape, or NULL on failure
OCCTShapeRef OCCTFaceFix(OCCTFaceRef face, double tolerance);

/// Fix a shape with detailed control
/// @param shape The shape to fix
/// @param tolerance Tolerance for fixing operations
/// @param fixSolid Whether to fix solid orientation
/// @param fixShell Whether to fix shell closure
/// @param fixFace Whether to fix face issues
/// @param fixWire Whether to fix wire issues
/// @return Fixed shape, or NULL on failure
OCCTShapeRef OCCTShapeFixDetailed(OCCTShapeRef shape, double tolerance,
                                   bool fixSolid, bool fixShell,
                                   bool fixFace, bool fixWire);

/// Unify faces and edges lying on the same geometry
/// @param shape The shape to simplify
/// @param unifyEdges Whether to unify edges on same curve
/// @param unifyFaces Whether to unify faces on same surface
/// @param concatBSplines Whether to concatenate adjacent B-splines
/// @return Unified shape, or NULL on failure
OCCTShapeRef OCCTShapeUnifySameDomain(OCCTShapeRef shape,
                                       bool unifyEdges, bool unifyFaces,
                                       bool concatBSplines);

/// Remove internal wires (holes) smaller than area threshold
/// @param shape The shape to clean
/// @param minArea Minimum area threshold for holes
/// @return Cleaned shape, or NULL on failure
OCCTShapeRef OCCTShapeRemoveSmallFaces(OCCTShapeRef shape, double minArea);

/// Simplify shape by removing small features
/// @param shape The shape to simplify
/// @param tolerance Size threshold for small features
/// @return Simplified shape, or NULL on failure
OCCTShapeRef OCCTShapeSimplify(OCCTShapeRef shape, double tolerance);

// MARK: - Camera (Metal Visualization)

typedef struct OCCTCamera* OCCTCameraRef;

OCCTCameraRef OCCTCameraCreate(void);
void          OCCTCameraDestroy(OCCTCameraRef cam);

void OCCTCameraSetEye(OCCTCameraRef cam, double x, double y, double z);
void OCCTCameraGetEye(OCCTCameraRef cam, double* x, double* y, double* z);
void OCCTCameraSetCenter(OCCTCameraRef cam, double x, double y, double z);
void OCCTCameraGetCenter(OCCTCameraRef cam, double* x, double* y, double* z);
void OCCTCameraSetUp(OCCTCameraRef cam, double x, double y, double z);
void OCCTCameraGetUp(OCCTCameraRef cam, double* x, double* y, double* z);

void OCCTCameraSetProjectionType(OCCTCameraRef cam, int type);
int  OCCTCameraGetProjectionType(OCCTCameraRef cam);
void OCCTCameraSetFOV(OCCTCameraRef cam, double degrees);
double OCCTCameraGetFOV(OCCTCameraRef cam);
void OCCTCameraSetScale(OCCTCameraRef cam, double scale);
double OCCTCameraGetScale(OCCTCameraRef cam);
void OCCTCameraSetZRange(OCCTCameraRef cam, double zNear, double zFar);
void OCCTCameraGetZRange(OCCTCameraRef cam, double* zNear, double* zFar);
void OCCTCameraSetAspect(OCCTCameraRef cam, double aspect);

void OCCTCameraGetProjectionMatrix(OCCTCameraRef cam, float* out16);
void OCCTCameraGetViewMatrix(OCCTCameraRef cam, float* out16);

void OCCTCameraProject(OCCTCameraRef cam, double wX, double wY, double wZ,
                       double* sX, double* sY, double* sZ);
void OCCTCameraUnproject(OCCTCameraRef cam, double sX, double sY, double sZ,
                         double* wX, double* wY, double* wZ);

void OCCTCameraFitBBox(OCCTCameraRef cam, double xMin, double yMin, double zMin,
                       double xMax, double yMax, double zMax);

// MARK: - Presentation Mesh (Metal Visualization)

typedef struct {
    float* vertices;
    int32_t vertexCount;
    int32_t* indices;
    int32_t triangleCount;
} OCCTShadedMeshData;

typedef struct {
    float* vertices;
    int32_t vertexCount;
    int32_t* segmentStarts;
    int32_t segmentCount;
} OCCTEdgeMeshData;

bool OCCTShapeGetShadedMesh(OCCTShapeRef shape, double deflection, OCCTShadedMeshData* out);
void OCCTShadedMeshDataFree(OCCTShadedMeshData* data);

bool OCCTShapeGetEdgeMesh(OCCTShapeRef shape, double deflection, OCCTEdgeMeshData* out);
void OCCTEdgeMeshDataFree(OCCTEdgeMeshData* data);

// MARK: - Selector (Metal Visualization)

typedef struct OCCTSelector* OCCTSelectorRef;

typedef struct {
    int32_t shapeId;
    double depth;
    double pointX, pointY, pointZ;
} OCCTPickResult;

OCCTSelectorRef OCCTSelectorCreate(void);
void            OCCTSelectorDestroy(OCCTSelectorRef sel);

bool OCCTSelectorAddShape(OCCTSelectorRef sel, OCCTShapeRef shape, int32_t shapeId);
bool OCCTSelectorRemoveShape(OCCTSelectorRef sel, int32_t shapeId);
void OCCTSelectorClear(OCCTSelectorRef sel);

int32_t OCCTSelectorPick(OCCTSelectorRef sel, OCCTCameraRef cam,
                         double viewW, double viewH,
                         double pixelX, double pixelY,
                         OCCTPickResult* out, int32_t maxResults);

int32_t OCCTSelectorPickRect(OCCTSelectorRef sel, OCCTCameraRef cam,
                             double viewW, double viewH,
                             double xMin, double yMin, double xMax, double yMax,
                             OCCTPickResult* out, int32_t maxResults);

// MARK: - Clip Plane (Metal Visualization)

typedef struct OCCTClipPlane* OCCTClipPlaneRef;

/// Create a clip plane from an equation Ax + By + Cz + D = 0
OCCTClipPlaneRef OCCTClipPlaneCreate(double a, double b, double c, double d);
void OCCTClipPlaneDestroy(OCCTClipPlaneRef plane);

void OCCTClipPlaneSetEquation(OCCTClipPlaneRef plane, double a, double b, double c, double d);
void OCCTClipPlaneGetEquation(OCCTClipPlaneRef plane, double* a, double* b, double* c, double* d);

/// Get the reversed equation (for back-face clipping)
void OCCTClipPlaneGetReversedEquation(OCCTClipPlaneRef plane, double* a, double* b, double* c, double* d);

void OCCTClipPlaneSetOn(OCCTClipPlaneRef plane, bool on);
bool OCCTClipPlaneIsOn(OCCTClipPlaneRef plane);

void OCCTClipPlaneSetCapping(OCCTClipPlaneRef plane, bool on);
bool OCCTClipPlaneIsCapping(OCCTClipPlaneRef plane);

void OCCTClipPlaneSetCappingColor(OCCTClipPlaneRef plane, double r, double g, double b);
void OCCTClipPlaneGetCappingColor(OCCTClipPlaneRef plane, double* r, double* g, double* b);

/// Set capping hatch style (see Aspect_HatchStyle values)
void OCCTClipPlaneSetCappingHatch(OCCTClipPlaneRef plane, int32_t style);
int32_t OCCTClipPlaneGetCappingHatch(OCCTClipPlaneRef plane);
void OCCTClipPlaneSetCappingHatchOn(OCCTClipPlaneRef plane, bool on);
bool OCCTClipPlaneIsCappingHatchOn(OCCTClipPlaneRef plane);

/// Probe a point against the clip plane chain. Returns: 0=Out, 1=In, 2=On
int32_t OCCTClipPlaneProbePoint(OCCTClipPlaneRef plane, double x, double y, double z);

/// Probe an axis-aligned bounding box against the clip plane chain. Returns: 0=Out, 1=In, 2=On
int32_t OCCTClipPlaneProbeBox(OCCTClipPlaneRef plane,
                               double xMin, double yMin, double zMin,
                               double xMax, double yMax, double zMax);

/// Chain another plane for logical AND clipping (conjunction)
void OCCTClipPlaneSetChainNext(OCCTClipPlaneRef plane, OCCTClipPlaneRef next);
/// Get the number of planes in the forward chain (including this one)
int32_t OCCTClipPlaneChainLength(OCCTClipPlaneRef plane);

// MARK: - Z-Layer Settings (Metal Visualization)

typedef struct OCCTZLayerSettings* OCCTZLayerSettingsRef;

OCCTZLayerSettingsRef OCCTZLayerSettingsCreate(void);
void OCCTZLayerSettingsDestroy(OCCTZLayerSettingsRef settings);

void OCCTZLayerSettingsSetName(OCCTZLayerSettingsRef settings, const char* name);

void OCCTZLayerSettingsSetDepthTest(OCCTZLayerSettingsRef settings, bool on);
bool OCCTZLayerSettingsGetDepthTest(OCCTZLayerSettingsRef settings);
void OCCTZLayerSettingsSetDepthWrite(OCCTZLayerSettingsRef settings, bool on);
bool OCCTZLayerSettingsGetDepthWrite(OCCTZLayerSettingsRef settings);
void OCCTZLayerSettingsSetClearDepth(OCCTZLayerSettingsRef settings, bool on);
bool OCCTZLayerSettingsGetClearDepth(OCCTZLayerSettingsRef settings);

/// Set polygon offset: mode (0=Off,1=Fill,2=Line,4=Point,7=All), factor, units
void OCCTZLayerSettingsSetPolygonOffset(OCCTZLayerSettingsRef settings, int32_t mode, float factor, float units);
void OCCTZLayerSettingsGetPolygonOffset(OCCTZLayerSettingsRef settings, int32_t* mode, float* factor, float* units);

/// Convenience: set minimal positive depth offset (factor=1, units=1)
void OCCTZLayerSettingsSetDepthOffsetPositive(OCCTZLayerSettingsRef settings);
/// Convenience: set minimal negative depth offset (factor=1, units=-1)
void OCCTZLayerSettingsSetDepthOffsetNegative(OCCTZLayerSettingsRef settings);

void OCCTZLayerSettingsSetImmediate(OCCTZLayerSettingsRef settings, bool on);
bool OCCTZLayerSettingsGetImmediate(OCCTZLayerSettingsRef settings);
void OCCTZLayerSettingsSetRaytracable(OCCTZLayerSettingsRef settings, bool on);
bool OCCTZLayerSettingsGetRaytracable(OCCTZLayerSettingsRef settings);

void OCCTZLayerSettingsSetEnvironmentTexture(OCCTZLayerSettingsRef settings, bool on);
bool OCCTZLayerSettingsGetEnvironmentTexture(OCCTZLayerSettingsRef settings);

void OCCTZLayerSettingsSetRenderInDepthPrepass(OCCTZLayerSettingsRef settings, bool on);
bool OCCTZLayerSettingsGetRenderInDepthPrepass(OCCTZLayerSettingsRef settings);

/// Set culling distance (set to negative or zero to disable)
void OCCTZLayerSettingsSetCullingDistance(OCCTZLayerSettingsRef settings, double distance);
double OCCTZLayerSettingsGetCullingDistance(OCCTZLayerSettingsRef settings);

/// Set culling size (set to negative or zero to disable)
void OCCTZLayerSettingsSetCullingSize(OCCTZLayerSettingsRef settings, double size);
double OCCTZLayerSettingsGetCullingSize(OCCTZLayerSettingsRef settings);

/// Set layer origin (for coordinate precision in large scenes)
void OCCTZLayerSettingsSetOrigin(OCCTZLayerSettingsRef settings, double x, double y, double z);
void OCCTZLayerSettingsGetOrigin(OCCTZLayerSettingsRef settings, double* x, double* y, double* z);

// MARK: - Advanced Blends & Surface Filling (v0.14.0)

/// Apply variable radius fillet to a specific edge
/// @param shape The shape to fillet
/// @param edgeIndex Index of the edge to fillet
/// @param radii Array of radius values along the edge
/// @param params Array of parameter values (0-1) where radii apply
/// @param count Number of radius/parameter pairs
/// @return Filleted shape, or NULL on failure
OCCTShapeRef OCCTShapeFilletVariable(OCCTShapeRef shape, int32_t edgeIndex,
                                      const double* radii, const double* params, int32_t count);

/// Apply 2D fillet to a wire at a specific vertex
/// @param wire The wire to fillet
/// @param vertexIndex Index of the vertex to fillet
/// @param radius Fillet radius
/// @return Filleted wire, or NULL on failure
OCCTWireRef OCCTWireFillet2D(OCCTWireRef wire, int32_t vertexIndex, double radius);

/// Apply 2D fillet to all vertices of a wire
/// @param wire The wire to fillet
/// @param radius Fillet radius for all corners
/// @return Filleted wire, or NULL on failure
OCCTWireRef OCCTWireFilletAll2D(OCCTWireRef wire, double radius);

/// Apply 2D chamfer to a wire at a specific vertex
/// @param wire The wire to chamfer
/// @param vertexIndex Index of the vertex to chamfer
/// @param dist1 First chamfer distance
/// @param dist2 Second chamfer distance
/// @return Chamfered wire, or NULL on failure
OCCTWireRef OCCTWireChamfer2D(OCCTWireRef wire, int32_t vertexIndex, double dist1, double dist2);

/// Apply 2D chamfer to all vertices of a wire
/// @param wire The wire to chamfer
/// @param distance Chamfer distance for all corners
/// @return Chamfered wire, or NULL on failure
OCCTWireRef OCCTWireChamferAll2D(OCCTWireRef wire, double distance);

/// Blend multiple edges with individual radii
/// @param shape The shape to blend
/// @param edgeIndices Array of edge indices
/// @param radii Array of radii (one per edge)
/// @param count Number of edges
/// @return Blended shape, or NULL on failure
OCCTShapeRef OCCTShapeBlendEdges(OCCTShapeRef shape,
                                  const int32_t* edgeIndices, const double* radii, int32_t count);

/// Parameters for surface filling operation
typedef struct {
    int32_t continuity;   // 0=GeomAbs_C0, 1=GeomAbs_G1, 2=GeomAbs_G2
    double tolerance;     // Surface tolerance
    int32_t maxDegree;    // Maximum surface degree (default 8)
    int32_t maxSegments;  // Maximum segments (default 9)
} OCCTFillingParams;

/// Fill an N-sided boundary with a surface
/// @param boundaries Array of boundary wires
/// @param wireCount Number of boundary wires
/// @param params Filling parameters
/// @return Filled face, or NULL on failure
OCCTShapeRef OCCTShapeFill(const OCCTWireRef* boundaries, int32_t wireCount,
                            OCCTFillingParams params);

/// Create a surface constrained to pass through points
/// @param points Array of points [x,y,z triplets]
/// @param pointCount Number of points
/// @param tolerance Surface tolerance
/// @return Surface face, or NULL on failure
OCCTShapeRef OCCTShapePlatePoints(const double* points, int32_t pointCount, double tolerance);

/// Create a surface constrained by curves
/// @param curves Array of constraint curves
/// @param curveCount Number of curves
/// @param continuity Desired continuity (0=C0, 1=G1, 2=G2)
/// @param tolerance Surface tolerance
/// @return Surface face, or NULL on failure
OCCTShapeRef OCCTShapePlateCurves(const OCCTWireRef* curves, int32_t curveCount,
                                   int32_t continuity, double tolerance);


#ifdef __cplusplus
}
#endif

#endif /* OCCTBridge_h */
