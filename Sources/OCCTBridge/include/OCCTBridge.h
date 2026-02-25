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

/// Ensure all edges in a shape have explicit 3D curves.
/// Call before allEdgePolylines on lofted/swept shapes where edges may only have pcurves.
/// Safe to call multiple times — only builds missing curves.
void OCCTShapeBuildCurves3d(OCCTShapeRef shape);

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
bool OCCTExportSTLWithMode(OCCTShapeRef shape, const char* path, double deflection, bool ascii);
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
double OCCTCameraGetAspect(OCCTCameraRef cam);

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
    int32_t subShapeType;   // TopAbs_ShapeEnum: 7=VERTEX, 6=EDGE, 5=WIRE, 4=FACE, 8=SHAPE
    int32_t subShapeIndex;  // 1-based index of sub-shape within parent, 0 if whole shape
} OCCTPickResult;

OCCTSelectorRef OCCTSelectorCreate(void);
void            OCCTSelectorDestroy(OCCTSelectorRef sel);

bool OCCTSelectorAddShape(OCCTSelectorRef sel, OCCTShapeRef shape, int32_t shapeId);
bool OCCTSelectorRemoveShape(OCCTSelectorRef sel, int32_t shapeId);
void OCCTSelectorClear(OCCTSelectorRef sel);

/// Activate a selection mode for a shape (0=shape, 1=vertex, 2=edge, 3=wire, 4=face).
/// Mode 0 is activated automatically when adding a shape.
void OCCTSelectorActivateMode(OCCTSelectorRef sel, int32_t shapeId, int32_t mode);

/// Deactivate a selection mode for a shape. Pass -1 to deactivate all modes.
void OCCTSelectorDeactivateMode(OCCTSelectorRef sel, int32_t shapeId, int32_t mode);

/// Check if a selection mode is active for a shape.
bool OCCTSelectorIsModeActive(OCCTSelectorRef sel, int32_t shapeId, int32_t mode);

/// Set pixel tolerance for picking near edges/vertices (default 2).
void OCCTSelectorSetPixelTolerance(OCCTSelectorRef sel, int32_t tolerance);
int32_t OCCTSelectorGetPixelTolerance(OCCTSelectorRef sel);

int32_t OCCTSelectorPick(OCCTSelectorRef sel, OCCTCameraRef cam,
                         double viewW, double viewH,
                         double pixelX, double pixelY,
                         OCCTPickResult* out, int32_t maxResults);

int32_t OCCTSelectorPickRect(OCCTSelectorRef sel, OCCTCameraRef cam,
                             double viewW, double viewH,
                             double xMin, double yMin, double xMax, double yMax,
                             OCCTPickResult* out, int32_t maxResults);

/// Polyline (lasso) pick: select shapes within a closed polygon defined by 2D pixel points.
/// polyXY is an array of x,y pairs (length = pointCount * 2).
int32_t OCCTSelectorPickPoly(OCCTSelectorRef sel, OCCTCameraRef cam,
                             double viewW, double viewH,
                             const double* polyXY, int32_t pointCount,
                             OCCTPickResult* out, int32_t maxResults);

// MARK: - Drawer-Aware Mesh Extraction

typedef struct OCCTDrawer* OCCTDrawerRef;

/// Extract shaded mesh using a DisplayDrawer for tessellation control.
bool OCCTShapeGetShadedMeshWithDrawer(OCCTShapeRef shape, OCCTDrawerRef drawer, OCCTShadedMeshData* out);
bool OCCTShapeGetEdgeMeshWithDrawer(OCCTShapeRef shape, OCCTDrawerRef drawer, OCCTEdgeMeshData* out);

// MARK: - Display Drawer (Metal Visualization)

OCCTDrawerRef OCCTDrawerCreate(void);
void OCCTDrawerDestroy(OCCTDrawerRef drawer);

/// Chordal deviation coefficient (relative to bounding box). Default ~0.001.
void OCCTDrawerSetDeviationCoefficient(OCCTDrawerRef drawer, double coeff);
double OCCTDrawerGetDeviationCoefficient(OCCTDrawerRef drawer);

/// Angular deviation in radians. Default 20 degrees (M_PI/9).
void OCCTDrawerSetDeviationAngle(OCCTDrawerRef drawer, double angle);
double OCCTDrawerGetDeviationAngle(OCCTDrawerRef drawer);

/// Maximal chordal deviation (absolute). Applies when type of deflection is absolute.
void OCCTDrawerSetMaximalChordialDeviation(OCCTDrawerRef drawer, double deviation);
double OCCTDrawerGetMaximalChordialDeviation(OCCTDrawerRef drawer);

/// Type of deflection: 0=relative (default), 1=absolute.
void OCCTDrawerSetTypeOfDeflection(OCCTDrawerRef drawer, int32_t type);
int32_t OCCTDrawerGetTypeOfDeflection(OCCTDrawerRef drawer);

/// Auto-triangulation on/off. Default true.
void OCCTDrawerSetAutoTriangulation(OCCTDrawerRef drawer, bool on);
bool OCCTDrawerGetAutoTriangulation(OCCTDrawerRef drawer);

/// Number of iso-parameter lines (U and V). Default 1.
void OCCTDrawerSetIsoOnTriangulation(OCCTDrawerRef drawer, bool on);
bool OCCTDrawerGetIsoOnTriangulation(OCCTDrawerRef drawer);

/// Discretisation (number of points for curves). Default 30.
void OCCTDrawerSetDiscretisation(OCCTDrawerRef drawer, int32_t value);
int32_t OCCTDrawerGetDiscretisation(OCCTDrawerRef drawer);

/// Face boundary display on/off. Default false.
void OCCTDrawerSetFaceBoundaryDraw(OCCTDrawerRef drawer, bool on);
bool OCCTDrawerGetFaceBoundaryDraw(OCCTDrawerRef drawer);

/// Wire frame display on/off. Default true.
void OCCTDrawerSetWireDraw(OCCTDrawerRef drawer, bool on);
bool OCCTDrawerGetWireDraw(OCCTDrawerRef drawer);

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


// MARK: - 2D Curve (Geom2d) — v0.16.0

typedef struct OCCTCurve2D* OCCTCurve2DRef;

void OCCTCurve2DRelease(OCCTCurve2DRef curve);

// Properties
void   OCCTCurve2DGetDomain(OCCTCurve2DRef curve, double* first, double* last);
bool   OCCTCurve2DIsClosed(OCCTCurve2DRef curve);
bool   OCCTCurve2DIsPeriodic(OCCTCurve2DRef curve);
double OCCTCurve2DGetPeriod(OCCTCurve2DRef curve);

// Evaluation
void OCCTCurve2DGetPoint(OCCTCurve2DRef curve, double u, double* x, double* y);
void OCCTCurve2DD1(OCCTCurve2DRef curve, double u,
                   double* px, double* py, double* vx, double* vy);
void OCCTCurve2DD2(OCCTCurve2DRef curve, double u,
                   double* px, double* py,
                   double* v1x, double* v1y, double* v2x, double* v2y);

// Primitives
OCCTCurve2DRef OCCTCurve2DCreateLine(double px, double py, double dx, double dy);
OCCTCurve2DRef OCCTCurve2DCreateSegment(double p1x, double p1y, double p2x, double p2y);
OCCTCurve2DRef OCCTCurve2DCreateCircle(double cx, double cy, double radius);
OCCTCurve2DRef OCCTCurve2DCreateArcOfCircle(double cx, double cy, double radius,
                                            double startAngle, double endAngle);
OCCTCurve2DRef OCCTCurve2DCreateArcThrough(double p1x, double p1y,
                                           double p2x, double p2y,
                                           double p3x, double p3y);
OCCTCurve2DRef OCCTCurve2DCreateEllipse(double cx, double cy,
                                        double majorR, double minorR, double rotation);
OCCTCurve2DRef OCCTCurve2DCreateArcOfEllipse(double cx, double cy,
                                             double majorR, double minorR,
                                             double rotation,
                                             double startAngle, double endAngle);
OCCTCurve2DRef OCCTCurve2DCreateParabola(double fx, double fy,
                                         double dx, double dy, double focal);
OCCTCurve2DRef OCCTCurve2DCreateHyperbola(double cx, double cy,
                                          double majorR, double minorR,
                                          double rotation);

// Draw (discretization for Metal)
int32_t OCCTCurve2DDrawAdaptive(OCCTCurve2DRef curve, double angularDefl, double chordalDefl,
                                double* outXY, int32_t maxPoints);
int32_t OCCTCurve2DDrawUniform(OCCTCurve2DRef curve, int32_t pointCount, double* outXY);
int32_t OCCTCurve2DDrawDeflection(OCCTCurve2DRef curve, double deflection,
                                  double* outXY, int32_t maxPoints);

// BSpline & Bezier
OCCTCurve2DRef OCCTCurve2DCreateBSpline(const double* poles, int32_t poleCount,
                                        const double* weights,
                                        const double* knots, int32_t knotCount,
                                        const int32_t* multiplicities, int32_t degree);
OCCTCurve2DRef OCCTCurve2DCreateBezier(const double* poles, int32_t poleCount,
                                       const double* weights);

// Interpolation & Fitting
OCCTCurve2DRef OCCTCurve2DInterpolate(const double* points, int32_t count,
                                      bool closed, double tolerance);
OCCTCurve2DRef OCCTCurve2DInterpolateWithTangents(const double* points, int32_t count,
                                                  double stx, double sty,
                                                  double etx, double ety,
                                                  double tolerance);
OCCTCurve2DRef OCCTCurve2DFitPoints(const double* points, int32_t count,
                                    int32_t minDeg, int32_t maxDeg, double tolerance);

// BSpline queries
int32_t OCCTCurve2DGetPoleCount(OCCTCurve2DRef curve);
int32_t OCCTCurve2DGetPoles(OCCTCurve2DRef curve, double* outXY);
int32_t OCCTCurve2DGetDegree(OCCTCurve2DRef curve);

// Operations
OCCTCurve2DRef OCCTCurve2DTrim(OCCTCurve2DRef curve, double u1, double u2);
OCCTCurve2DRef OCCTCurve2DOffset(OCCTCurve2DRef curve, double distance);
OCCTCurve2DRef OCCTCurve2DReversed(OCCTCurve2DRef curve);
OCCTCurve2DRef OCCTCurve2DTranslate(OCCTCurve2DRef curve, double dx, double dy);
OCCTCurve2DRef OCCTCurve2DRotate(OCCTCurve2DRef curve, double cx, double cy, double angle);
OCCTCurve2DRef OCCTCurve2DScale(OCCTCurve2DRef curve, double cx, double cy, double factor);
OCCTCurve2DRef OCCTCurve2DMirrorAxis(OCCTCurve2DRef curve, double px, double py,
                                     double dx, double dy);
OCCTCurve2DRef OCCTCurve2DMirrorPoint(OCCTCurve2DRef curve, double px, double py);
double OCCTCurve2DGetLength(OCCTCurve2DRef curve);
double OCCTCurve2DGetLengthBetween(OCCTCurve2DRef curve, double u1, double u2);

// Intersection
typedef struct {
    double x, y, u1, u2;
} OCCTCurve2DIntersection;

int32_t OCCTCurve2DIntersect(OCCTCurve2DRef c1, OCCTCurve2DRef c2, double tolerance,
                             OCCTCurve2DIntersection* out, int32_t max);
int32_t OCCTCurve2DSelfIntersect(OCCTCurve2DRef curve, double tolerance,
                                 OCCTCurve2DIntersection* out, int32_t max);

// Projection
typedef struct {
    double x, y, parameter, distance;
} OCCTCurve2DProjection;

OCCTCurve2DProjection OCCTCurve2DProjectPoint(OCCTCurve2DRef curve, double px, double py);
int32_t OCCTCurve2DProjectPointAll(OCCTCurve2DRef curve, double px, double py,
                                   OCCTCurve2DProjection* out, int32_t max);

// Extrema
typedef struct {
    double p1x, p1y, p2x, p2y, u1, u2, distance;
} OCCTCurve2DExtrema;

OCCTCurve2DExtrema OCCTCurve2DMinDistance(OCCTCurve2DRef c1, OCCTCurve2DRef c2);
int32_t OCCTCurve2DAllExtrema(OCCTCurve2DRef c1, OCCTCurve2DRef c2,
                              OCCTCurve2DExtrema* out, int32_t max);

// Conversion
OCCTCurve2DRef OCCTCurve2DToBSpline(OCCTCurve2DRef curve, double tolerance);
int32_t OCCTCurve2DBSplineToBeziers(OCCTCurve2DRef curve, OCCTCurve2DRef* out, int32_t max);
void OCCTCurve2DFreeArray(OCCTCurve2DRef* curves, int32_t count);
OCCTCurve2DRef OCCTCurve2DJoinToBSpline(const OCCTCurve2DRef* curves, int32_t count,
                                        double tolerance);

// Local Properties (Geom2dLProp)
double OCCTCurve2DGetCurvature(OCCTCurve2DRef curve, double u);
bool   OCCTCurve2DGetNormal(OCCTCurve2DRef curve, double u, double* nx, double* ny);
bool   OCCTCurve2DGetTangentDir(OCCTCurve2DRef curve, double u, double* tx, double* ty);
bool   OCCTCurve2DGetCenterOfCurvature(OCCTCurve2DRef curve, double u, double* cx, double* cy);

/// Curve inflection/curvature result type: 0=Inflection, 1=MinCurvature, 2=MaxCurvature
typedef struct {
    double parameter;
    int32_t type;
} OCCTCurve2DCurvePoint;

int32_t OCCTCurve2DGetInflectionPoints(OCCTCurve2DRef curve, double* outParams, int32_t max);
int32_t OCCTCurve2DGetCurvatureExtrema(OCCTCurve2DRef curve, OCCTCurve2DCurvePoint* out, int32_t max);
int32_t OCCTCurve2DGetAllSpecialPoints(OCCTCurve2DRef curve, OCCTCurve2DCurvePoint* out, int32_t max);

// Bounding Box
bool OCCTCurve2DGetBoundingBox(OCCTCurve2DRef curve, double* xMin, double* yMin,
                               double* xMax, double* yMax);

// Additional Arc Types
OCCTCurve2DRef OCCTCurve2DCreateArcOfHyperbola(double cx, double cy,
                                               double majorR, double minorR,
                                               double rotation,
                                               double startAngle, double endAngle);
OCCTCurve2DRef OCCTCurve2DCreateArcOfParabola(double fx, double fy,
                                              double dx, double dy, double focal,
                                              double startParam, double endParam);

// Conversion Extras
OCCTCurve2DRef OCCTCurve2DApproximate(OCCTCurve2DRef curve, double tolerance,
                                      int32_t continuity, int32_t maxSegments, int32_t maxDegree);
int32_t OCCTCurve2DSplitAtDiscontinuities(OCCTCurve2DRef curve, int32_t continuity,
                                          int32_t* outKnotIndices, int32_t max);
int32_t OCCTCurve2DToArcsAndSegments(OCCTCurve2DRef curve, double tolerance,
                                     double angleTol, OCCTCurve2DRef* out, int32_t max);

// Gcc Constraint Solver — Qualifier enum
typedef enum {
    OCCTGccQualUnqualified = 0,
    OCCTGccQualEnclosing   = 1,
    OCCTGccQualEnclosed    = 2,
    OCCTGccQualOutside     = 3
} OCCTGccQualifier;

/// Circle tangent solution result
typedef struct {
    double cx, cy, radius;
    int32_t qualifier;
} OCCTGccCircleSolution;

/// Line tangent solution result
typedef struct {
    double px, py, dx, dy;
    int32_t qualifier;
} OCCTGccLineSolution;

// Gcc Circle Construction
int32_t OCCTGccCircle2d3Tan(OCCTCurve2DRef c1, int32_t q1,
                            OCCTCurve2DRef c2, int32_t q2,
                            OCCTCurve2DRef c3, int32_t q3,
                            double tolerance,
                            OCCTGccCircleSolution* out, int32_t max);
int32_t OCCTGccCircle2d2TanPt(OCCTCurve2DRef c1, int32_t q1,
                              OCCTCurve2DRef c2, int32_t q2,
                              double px, double py,
                              double tolerance,
                              OCCTGccCircleSolution* out, int32_t max);
int32_t OCCTGccCircle2dTanCen(OCCTCurve2DRef curve, int32_t qualifier,
                              double cx, double cy, double tolerance,
                              OCCTGccCircleSolution* out, int32_t max);
int32_t OCCTGccCircle2d2TanRad(OCCTCurve2DRef c1, int32_t q1,
                               OCCTCurve2DRef c2, int32_t q2,
                               double radius, double tolerance,
                               OCCTGccCircleSolution* out, int32_t max);
int32_t OCCTGccCircle2dTanPtRad(OCCTCurve2DRef curve, int32_t qualifier,
                                double px, double py,
                                double radius, double tolerance,
                                OCCTGccCircleSolution* out, int32_t max);
int32_t OCCTGccCircle2d2PtRad(double p1x, double p1y, double p2x, double p2y,
                              double radius, double tolerance,
                              OCCTGccCircleSolution* out, int32_t max);
int32_t OCCTGccCircle2d3Pt(double p1x, double p1y, double p2x, double p2y,
                           double p3x, double p3y, double tolerance,
                           OCCTGccCircleSolution* out, int32_t max);

// Gcc Line Construction
int32_t OCCTGccLine2d2Tan(OCCTCurve2DRef c1, int32_t q1,
                          OCCTCurve2DRef c2, int32_t q2,
                          double tolerance,
                          OCCTGccLineSolution* out, int32_t max);
int32_t OCCTGccLine2dTanPt(OCCTCurve2DRef curve, int32_t qualifier,
                           double px, double py, double tolerance,
                           OCCTGccLineSolution* out, int32_t max);

// Hatching
int32_t OCCTCurve2DHatch(const OCCTCurve2DRef* boundaries, int32_t boundaryCount,
                         double originX, double originY,
                         double dirX, double dirY,
                         double spacing, double tolerance,
                         double* outXY, int32_t maxPoints);

// Bisector
OCCTCurve2DRef OCCTCurve2DBisectorCC(OCCTCurve2DRef c1, OCCTCurve2DRef c2,
                                     double originX, double originY, bool side);
OCCTCurve2DRef OCCTCurve2DBisectorPC(double px, double py, OCCTCurve2DRef curve,
                                     double originX, double originY, bool side);


// MARK: - STL Import (v0.17.0)

/// Import an STL file as a shape (sews faces into a shell/solid)
OCCTShapeRef OCCTImportSTL(const char* path);

/// Import an STL file with robust healing (sew + solid creation + heal)
OCCTShapeRef OCCTImportSTLRobust(const char* path, double sewingTolerance);


// MARK: - OBJ Import/Export (v0.17.0)

/// Import an OBJ file as a shape
OCCTShapeRef OCCTImportOBJ(const char* path);

/// Export a shape to OBJ format
bool OCCTExportOBJ(OCCTShapeRef shape, const char* path, double deflection);


// MARK: - PLY Export (v0.17.0)

/// Export a shape to PLY format (Stanford Polygon Format)
bool OCCTExportPLY(OCCTShapeRef shape, const char* path, double deflection);


// MARK: - Advanced Healing (v0.17.0)

/// Divide a shape at continuity discontinuities
/// @param shape Shape to divide
/// @param continuity Target continuity (0=C0, 1=C1, 2=C2, 3=C3)
/// @return Divided shape, or NULL on failure
OCCTShapeRef OCCTShapeDivide(OCCTShapeRef shape, int32_t continuity);

/// Convert geometry to direct faces (canonical surfaces)
OCCTShapeRef OCCTShapeDirectFaces(OCCTShapeRef shape);

/// Scale shape geometry
OCCTShapeRef OCCTShapeScaleGeometry(OCCTShapeRef shape, double factor);

/// Convert BSpline surfaces to their closest analytical form
/// (planes, cylinders, cones, spheres, tori)
OCCTShapeRef OCCTShapeBSplineRestriction(OCCTShapeRef shape,
                                          double surfaceTol, double curveTol,
                                          int32_t maxDegree, int32_t maxSegments);

/// Convert swept surfaces to elementary (canonical) surfaces
OCCTShapeRef OCCTShapeSweptToElementary(OCCTShapeRef shape);

/// Convert surfaces of revolution to elementary surfaces
OCCTShapeRef OCCTShapeRevolutionToElementary(OCCTShapeRef shape);

/// Convert all surfaces to BSpline
OCCTShapeRef OCCTShapeConvertToBSpline(OCCTShapeRef shape);

/// Sew a single shape (reconnect disconnected faces)
OCCTShapeRef OCCTShapeSewSingle(OCCTShapeRef shape, double tolerance);

/// Upgrade shape: sew + make solid + heal (pipeline)
OCCTShapeRef OCCTShapeUpgrade(OCCTShapeRef shape, double tolerance);


// MARK: - Point Classification (v0.17.0)

/// Classification result: 0=IN, 1=OUT, 2=ON, 3=UNKNOWN
typedef int32_t OCCTTopAbsState;

/// Classify a point relative to a solid
OCCTTopAbsState OCCTClassifyPointInSolid(OCCTShapeRef solid,
                                          double px, double py, double pz,
                                          double tolerance);

/// Classify a point relative to a face (using 3D point)
OCCTTopAbsState OCCTClassifyPointOnFace(OCCTFaceRef face,
                                         double px, double py, double pz,
                                         double tolerance);

/// Classify a point relative to a face (using UV parameters)
OCCTTopAbsState OCCTClassifyPointOnFaceUV(OCCTFaceRef face,
                                           double u, double v,
                                           double tolerance);


// MARK: - Face Surface Properties (v0.18.0)

/// Get UV parameter bounds of a face
bool OCCTFaceGetUVBounds(OCCTFaceRef face,
                         double* uMin, double* uMax,
                         double* vMin, double* vMax);

/// Evaluate surface point at UV parameters
bool OCCTFaceEvaluateAtUV(OCCTFaceRef face, double u, double v,
                          double* px, double* py, double* pz);

/// Get surface normal at UV parameters
bool OCCTFaceGetNormalAtUV(OCCTFaceRef face, double u, double v,
                           double* nx, double* ny, double* nz);

/// Get Gaussian curvature at UV parameters
bool OCCTFaceGetGaussianCurvature(OCCTFaceRef face, double u, double v,
                                   double* curvature);

/// Get mean curvature at UV parameters
bool OCCTFaceGetMeanCurvature(OCCTFaceRef face, double u, double v,
                               double* curvature);

/// Get principal curvatures and directions at UV parameters
bool OCCTFaceGetPrincipalCurvatures(OCCTFaceRef face, double u, double v,
                                     double* k1, double* k2,
                                     double* d1x, double* d1y, double* d1z,
                                     double* d2x, double* d2y, double* d2z);

/// Get surface type: 0=Plane, 1=Cylinder, 2=Cone, 3=Sphere, 4=Torus,
///   5=BezierSurface, 6=BSplineSurface, 7=SurfaceOfRevolution,
///   8=SurfaceOfExtrusion, 9=OffsetSurface, 10=Other
int32_t OCCTFaceGetSurfaceType(OCCTFaceRef face);

/// Get surface area of a single face
double OCCTFaceGetArea(OCCTFaceRef face, double tolerance);


// MARK: - Edge 3D Curve Properties (v0.18.0)

/// Get parameter bounds of an edge's curve
bool OCCTEdgeGetParameterBounds(OCCTEdgeRef edge, double* first, double* last);

/// Get 3D curvature at parameter on edge curve
bool OCCTEdgeGetCurvature3D(OCCTEdgeRef edge, double param, double* curvature);

/// Get tangent direction at parameter on edge curve
bool OCCTEdgeGetTangent3D(OCCTEdgeRef edge, double param,
                           double* tx, double* ty, double* tz);

/// Get principal normal at parameter on edge curve
bool OCCTEdgeGetNormal3D(OCCTEdgeRef edge, double param,
                          double* nx, double* ny, double* nz);

/// Get center of curvature at parameter on edge curve
bool OCCTEdgeGetCenterOfCurvature3D(OCCTEdgeRef edge, double param,
                                     double* cx, double* cy, double* cz);

/// Get torsion at parameter on edge curve
bool OCCTEdgeGetTorsion(OCCTEdgeRef edge, double param, double* torsion);

/// Get point at parameter (uses actual curve parameterization)
bool OCCTEdgeGetPointAtParam(OCCTEdgeRef edge, double param,
                              double* px, double* py, double* pz);

/// Get curve type: 0=Line, 1=Circle, 2=Ellipse, 3=Hyperbola, 4=Parabola,
///   5=BezierCurve, 6=BSplineCurve, 7=OffsetCurve, 8=Other
int32_t OCCTEdgeGetCurveType(OCCTEdgeRef edge);


// MARK: - Point Projection (v0.18.0)

/// Projection result for point-on-surface
typedef struct {
    double px, py, pz;   // closest 3D point
    double u, v;          // UV parameters
    double distance;      // distance from original point
    bool isValid;
} OCCTSurfaceProjectionResult;

/// Project point onto face (closest point)
OCCTSurfaceProjectionResult OCCTFaceProjectPoint(OCCTFaceRef face,
                                                  double px, double py, double pz);

/// Get all projection results (multiple solutions)
int32_t OCCTFaceProjectPointAll(OCCTFaceRef face,
                                 double px, double py, double pz,
                                 OCCTSurfaceProjectionResult* results,
                                 int32_t maxResults);

/// Projection result for point-on-curve
typedef struct {
    double px, py, pz;   // closest 3D point on curve
    double parameter;     // curve parameter
    double distance;      // distance from original point
    bool isValid;
} OCCTCurveProjectionResult;

/// Project point onto edge curve (closest point)
OCCTCurveProjectionResult OCCTEdgeProjectPoint(OCCTEdgeRef edge,
                                                double px, double py, double pz);


// MARK: - Shape Proximity (v0.18.0)

/// Face proximity pair result
typedef struct {
    int32_t face1Index;
    int32_t face2Index;
} OCCTFaceProximityPair;

/// Detect face pairs between two shapes that are within tolerance
int32_t OCCTShapeProximity(OCCTShapeRef shape1, OCCTShapeRef shape2,
                            double tolerance,
                            OCCTFaceProximityPair* outPairs,
                            int32_t maxPairs);

/// Check if a shape self-intersects
bool OCCTShapeSelfIntersects(OCCTShapeRef shape);


// MARK: - Surface Intersection (v0.18.0)

/// Intersect two faces and return intersection curves as edges
OCCTShapeRef OCCTFaceIntersect(OCCTFaceRef face1, OCCTFaceRef face2,
                                double tolerance);


// MARK: - Curve3D: 3D Parametric Curves (v0.19.0)

typedef struct OCCTCurve3D* OCCTCurve3DRef;

void OCCTCurve3DRelease(OCCTCurve3DRef curve);

// Properties
void   OCCTCurve3DGetDomain(OCCTCurve3DRef curve, double* first, double* last);
bool   OCCTCurve3DIsClosed(OCCTCurve3DRef curve);
bool   OCCTCurve3DIsPeriodic(OCCTCurve3DRef curve);
double OCCTCurve3DGetPeriod(OCCTCurve3DRef curve);

// Evaluation
void OCCTCurve3DGetPoint(OCCTCurve3DRef curve, double u,
                         double* x, double* y, double* z);
void OCCTCurve3DD1(OCCTCurve3DRef curve, double u,
                   double* px, double* py, double* pz,
                   double* vx, double* vy, double* vz);
void OCCTCurve3DD2(OCCTCurve3DRef curve, double u,
                   double* px, double* py, double* pz,
                   double* v1x, double* v1y, double* v1z,
                   double* v2x, double* v2y, double* v2z);

// Primitive Curves
OCCTCurve3DRef OCCTCurve3DCreateLine(double px, double py, double pz,
                                      double dx, double dy, double dz);
OCCTCurve3DRef OCCTCurve3DCreateSegment(double p1x, double p1y, double p1z,
                                         double p2x, double p2y, double p2z);
OCCTCurve3DRef OCCTCurve3DCreateCircle(double cx, double cy, double cz,
                                        double nx, double ny, double nz,
                                        double radius);
OCCTCurve3DRef OCCTCurve3DCreateArcOfCircle(double p1x, double p1y, double p1z,
                                             double p2x, double p2y, double p2z,
                                             double p3x, double p3y, double p3z);
OCCTCurve3DRef OCCTCurve3DCreateArc3Points(double p1x, double p1y, double p1z,
                                            double pmx, double pmy, double pmz,
                                            double p2x, double p2y, double p2z);
OCCTCurve3DRef OCCTCurve3DCreateEllipse(double cx, double cy, double cz,
                                         double nx, double ny, double nz,
                                         double majorR, double minorR);
OCCTCurve3DRef OCCTCurve3DCreateParabola(double cx, double cy, double cz,
                                          double nx, double ny, double nz,
                                          double focal);
OCCTCurve3DRef OCCTCurve3DCreateHyperbola(double cx, double cy, double cz,
                                           double nx, double ny, double nz,
                                           double majorR, double minorR);

// BSpline / Bezier / Interpolation
OCCTCurve3DRef OCCTCurve3DCreateBSpline(const double* poles, int32_t poleCount,
                                         const double* weights,
                                         const double* knots, int32_t knotCount,
                                         const int32_t* multiplicities, int32_t degree);
OCCTCurve3DRef OCCTCurve3DCreateBezier(const double* poles, int32_t poleCount,
                                        const double* weights);
OCCTCurve3DRef OCCTCurve3DInterpolate(const double* points, int32_t count,
                                       bool closed, double tolerance);
OCCTCurve3DRef OCCTCurve3DInterpolateWithTangents(const double* points, int32_t count,
                                                   double stx, double sty, double stz,
                                                   double etx, double ety, double etz,
                                                   double tolerance);
OCCTCurve3DRef OCCTCurve3DFitPoints(const double* points, int32_t count,
                                     int32_t minDeg, int32_t maxDeg, double tolerance);

// BSpline queries
int32_t OCCTCurve3DGetPoleCount(OCCTCurve3DRef curve);
int32_t OCCTCurve3DGetPoles(OCCTCurve3DRef curve, double* outXYZ);
int32_t OCCTCurve3DGetDegree(OCCTCurve3DRef curve);

// Operations
OCCTCurve3DRef OCCTCurve3DTrim(OCCTCurve3DRef curve, double u1, double u2);
OCCTCurve3DRef OCCTCurve3DReversed(OCCTCurve3DRef curve);
OCCTCurve3DRef OCCTCurve3DTranslate(OCCTCurve3DRef curve, double dx, double dy, double dz);
OCCTCurve3DRef OCCTCurve3DRotate(OCCTCurve3DRef curve,
                                  double axisOx, double axisOy, double axisOz,
                                  double axisDx, double axisDy, double axisDz,
                                  double angle);
OCCTCurve3DRef OCCTCurve3DScale(OCCTCurve3DRef curve,
                                 double cx, double cy, double cz, double factor);
OCCTCurve3DRef OCCTCurve3DMirrorPoint(OCCTCurve3DRef curve,
                                       double px, double py, double pz);
OCCTCurve3DRef OCCTCurve3DMirrorAxis(OCCTCurve3DRef curve,
                                      double px, double py, double pz,
                                      double dx, double dy, double dz);
OCCTCurve3DRef OCCTCurve3DMirrorPlane(OCCTCurve3DRef curve,
                                       double px, double py, double pz,
                                       double nx, double ny, double nz);
double OCCTCurve3DGetLength(OCCTCurve3DRef curve);
double OCCTCurve3DGetLengthBetween(OCCTCurve3DRef curve, double u1, double u2);

// Conversion (GeomConvert)
OCCTCurve3DRef OCCTCurve3DToBSpline(OCCTCurve3DRef curve);
int32_t OCCTCurve3DBSplineToBeziers(OCCTCurve3DRef curve,
                                     OCCTCurve3DRef* out, int32_t max);
void OCCTCurve3DFreeArray(OCCTCurve3DRef* curves, int32_t count);
OCCTCurve3DRef OCCTCurve3DJoinToBSpline(const OCCTCurve3DRef* curves, int32_t count,
                                         double tolerance);
OCCTCurve3DRef OCCTCurve3DApproximate(OCCTCurve3DRef curve, double tolerance,
                                       int32_t continuity, int32_t maxSegments,
                                       int32_t maxDegree);

// Draw Methods (discretization for Metal)
int32_t OCCTCurve3DDrawAdaptive(OCCTCurve3DRef curve,
                                 double angularDefl, double chordalDefl,
                                 double* outXYZ, int32_t maxPoints);
int32_t OCCTCurve3DDrawUniform(OCCTCurve3DRef curve,
                                int32_t pointCount, double* outXYZ);
int32_t OCCTCurve3DDrawDeflection(OCCTCurve3DRef curve, double deflection,
                                   double* outXYZ, int32_t maxPoints);

// Local Properties
double OCCTCurve3DGetCurvature(OCCTCurve3DRef curve, double u);
bool   OCCTCurve3DGetTangent(OCCTCurve3DRef curve, double u,
                              double* tx, double* ty, double* tz);
bool   OCCTCurve3DGetNormal(OCCTCurve3DRef curve, double u,
                             double* nx, double* ny, double* nz);
bool   OCCTCurve3DGetCenterOfCurvature(OCCTCurve3DRef curve, double u,
                                        double* cx, double* cy, double* cz);
double OCCTCurve3DGetTorsion(OCCTCurve3DRef curve, double u);

// Bounding Box
bool OCCTCurve3DGetBoundingBox(OCCTCurve3DRef curve,
                                double* xMin, double* yMin, double* zMin,
                                double* xMax, double* yMax, double* zMax);


// MARK: - Surface: Parametric Surfaces (v0.20.0)

typedef struct OCCTSurface* OCCTSurfaceRef;

void OCCTSurfaceRelease(OCCTSurfaceRef surface);

// Properties
void   OCCTSurfaceGetDomain(OCCTSurfaceRef surface,
                             double* uMin, double* uMax,
                             double* vMin, double* vMax);
bool   OCCTSurfaceIsUClosed(OCCTSurfaceRef surface);
bool   OCCTSurfaceIsVClosed(OCCTSurfaceRef surface);
bool   OCCTSurfaceIsUPeriodic(OCCTSurfaceRef surface);
bool   OCCTSurfaceIsVPeriodic(OCCTSurfaceRef surface);
double OCCTSurfaceGetUPeriod(OCCTSurfaceRef surface);
double OCCTSurfaceGetVPeriod(OCCTSurfaceRef surface);

// Evaluation
void OCCTSurfaceGetPoint(OCCTSurfaceRef surface, double u, double v,
                          double* x, double* y, double* z);
void OCCTSurfaceD1(OCCTSurfaceRef surface, double u, double v,
                    double* px, double* py, double* pz,
                    double* dux, double* duy, double* duz,
                    double* dvx, double* dvy, double* dvz);
void OCCTSurfaceD2(OCCTSurfaceRef surface, double u, double v,
                    double* px, double* py, double* pz,
                    double* d1ux, double* d1uy, double* d1uz,
                    double* d1vx, double* d1vy, double* d1vz,
                    double* d2ux, double* d2uy, double* d2uz,
                    double* d2vx, double* d2vy, double* d2vz,
                    double* d2uvx, double* d2uvy, double* d2uvz);
bool OCCTSurfaceGetNormal(OCCTSurfaceRef surface, double u, double v,
                           double* nx, double* ny, double* nz);

// Analytic Surfaces
OCCTSurfaceRef OCCTSurfaceCreatePlane(double px, double py, double pz,
                                       double nx, double ny, double nz);
OCCTSurfaceRef OCCTSurfaceCreateCylinder(double px, double py, double pz,
                                          double dx, double dy, double dz,
                                          double radius);
OCCTSurfaceRef OCCTSurfaceCreateCone(double px, double py, double pz,
                                      double dx, double dy, double dz,
                                      double radius, double semiAngle);
OCCTSurfaceRef OCCTSurfaceCreateSphere(double cx, double cy, double cz,
                                        double radius);
OCCTSurfaceRef OCCTSurfaceCreateTorus(double px, double py, double pz,
                                       double dx, double dy, double dz,
                                       double majorRadius, double minorRadius);

// Swept Surfaces
OCCTSurfaceRef OCCTSurfaceCreateExtrusion(OCCTCurve3DRef profile,
                                           double dx, double dy, double dz);
OCCTSurfaceRef OCCTSurfaceCreateRevolution(OCCTCurve3DRef meridian,
                                            double px, double py, double pz,
                                            double dx, double dy, double dz);

// Freeform Surfaces
OCCTSurfaceRef OCCTSurfaceCreateBezier(const double* poles,
                                        int32_t uCount, int32_t vCount,
                                        const double* weights);
OCCTSurfaceRef OCCTSurfaceCreateBSpline(const double* poles,
                                         int32_t uPoleCount, int32_t vPoleCount,
                                         const double* weights,
                                         const double* uKnots, int32_t uKnotCount,
                                         const double* vKnots, int32_t vKnotCount,
                                         const int32_t* uMults, const int32_t* vMults,
                                         int32_t uDegree, int32_t vDegree);

// Operations
OCCTSurfaceRef OCCTSurfaceTrim(OCCTSurfaceRef surface,
                                double u1, double u2, double v1, double v2);
OCCTSurfaceRef OCCTSurfaceOffset(OCCTSurfaceRef surface, double distance);
OCCTSurfaceRef OCCTSurfaceTranslate(OCCTSurfaceRef surface,
                                     double dx, double dy, double dz);
OCCTSurfaceRef OCCTSurfaceRotate(OCCTSurfaceRef surface,
                                  double axOx, double axOy, double axOz,
                                  double axDx, double axDy, double axDz,
                                  double angle);
OCCTSurfaceRef OCCTSurfaceScale(OCCTSurfaceRef surface,
                                 double cx, double cy, double cz, double factor);
OCCTSurfaceRef OCCTSurfaceMirrorPlane(OCCTSurfaceRef surface,
                                       double px, double py, double pz,
                                       double nx, double ny, double nz);

// Conversion
OCCTSurfaceRef OCCTSurfaceToBSpline(OCCTSurfaceRef surface);
OCCTSurfaceRef OCCTSurfaceApproximate(OCCTSurfaceRef surface, double tolerance,
                                       int32_t continuity, int32_t maxSegments,
                                       int32_t maxDegree);

// Iso Curves (returns Curve3D)
OCCTCurve3DRef OCCTSurfaceUIso(OCCTSurfaceRef surface, double u);
OCCTCurve3DRef OCCTSurfaceVIso(OCCTSurfaceRef surface, double v);

// Pipe Surface (GeomFill_Pipe)
OCCTSurfaceRef OCCTSurfaceCreatePipe(OCCTCurve3DRef path, double radius);
OCCTSurfaceRef OCCTSurfaceCreatePipeWithSection(OCCTCurve3DRef path,
                                                 OCCTCurve3DRef section);

// Draw Methods (discretization for Metal)
/// Draw iso-parameter grid lines: uCount U-iso lines + vCount V-iso lines
/// Returns total point count. outXYZ[pointIndex*3..+3] for coordinates.
/// outLineLengths[lineIndex] = number of points in that line.
int32_t OCCTSurfaceDrawGrid(OCCTSurfaceRef surface,
                             int32_t uCount, int32_t vCount,
                             int32_t pointsPerLine,
                             double* outXYZ, int32_t maxPoints,
                             int32_t* outLineLengths, int32_t maxLines);

/// Sample a uniform grid of points for mesh triangulation
/// Returns total point count (uCount * vCount)
int32_t OCCTSurfaceDrawMesh(OCCTSurfaceRef surface,
                             int32_t uCount, int32_t vCount,
                             double* outXYZ);

// Local Properties (GeomLProp_SLProps)
double OCCTSurfaceGetGaussianCurvature(OCCTSurfaceRef surface, double u, double v);
double OCCTSurfaceGetMeanCurvature(OCCTSurfaceRef surface, double u, double v);
bool   OCCTSurfaceGetPrincipalCurvatures(OCCTSurfaceRef surface, double u, double v,
                                          double* kMin, double* kMax,
                                          double* d1x, double* d1y, double* d1z,
                                          double* d2x, double* d2y, double* d2z);

// Bounding Box
bool OCCTSurfaceGetBoundingBox(OCCTSurfaceRef surface,
                                double* xMin, double* yMin, double* zMin,
                                double* xMax, double* yMax, double* zMax);

// BSpline Queries
int32_t OCCTSurfaceGetUPoleCount(OCCTSurfaceRef surface);
int32_t OCCTSurfaceGetVPoleCount(OCCTSurfaceRef surface);
int32_t OCCTSurfaceGetPoles(OCCTSurfaceRef surface, double* outXYZ);
int32_t OCCTSurfaceGetUDegree(OCCTSurfaceRef surface);
int32_t OCCTSurfaceGetVDegree(OCCTSurfaceRef surface);


// MARK: - Law Functions (v0.21.0)

typedef struct OCCTLawFunction* OCCTLawFunctionRef;

void OCCTLawFunctionRelease(OCCTLawFunctionRef law);

/// Evaluate law value at parameter
double OCCTLawFunctionValue(OCCTLawFunctionRef law, double param);

/// Get law parameter bounds
void OCCTLawFunctionBounds(OCCTLawFunctionRef law, double* first, double* last);

/// Create a constant law: value is constant over [first, last]
OCCTLawFunctionRef OCCTLawCreateConstant(double value, double first, double last);

/// Create a linear law: linearly interpolates from (first, startVal) to (last, endVal)
OCCTLawFunctionRef OCCTLawCreateLinear(double first, double startVal,
                                        double last, double endVal);

/// Create an S-curve law: smooth sigmoid between (first, startVal) and (last, endVal)
OCCTLawFunctionRef OCCTLawCreateS(double first, double startVal,
                                   double last, double endVal);

/// Create an interpolated law from (parameter, value) pairs
/// points is array of [param0, val0, param1, val1, ...]
OCCTLawFunctionRef OCCTLawCreateInterpolate(const double* paramValues,
                                             int32_t count, bool periodic);

/// Create a BSpline law
OCCTLawFunctionRef OCCTLawCreateBSpline(const double* poles, int32_t poleCount,
                                         const double* knots, int32_t knotCount,
                                         const int32_t* multiplicities,
                                         int32_t degree);

/// Create pipe shell with law-based scaling along spine
/// profile: wire cross-section, spine: wire path, law: scaling evolution
OCCTShapeRef OCCTShapeCreatePipeShellWithLaw(OCCTWireRef spine,
                                              OCCTWireRef profile,
                                              OCCTLawFunctionRef law,
                                              bool solid);

// MARK: - XDE GD&T / Dimension Tolerance (v0.21.0)

/// Get count of dimension labels in document
int32_t OCCTDocumentGetDimensionCount(OCCTDocumentRef doc);

/// Get count of geometric tolerance labels in document
int32_t OCCTDocumentGetGeomToleranceCount(OCCTDocumentRef doc);

/// Get count of datum labels in document
int32_t OCCTDocumentGetDatumCount(OCCTDocumentRef doc);

/// Dimension info result
typedef struct {
    int32_t type;         // XCAFDimTolObjects_DimensionType enum
    double value;         // primary value
    double lowerTol;      // lower tolerance
    double upperTol;      // upper tolerance
    bool isValid;
} OCCTDimensionInfo;

/// Get dimension info at index
OCCTDimensionInfo OCCTDocumentGetDimensionInfo(OCCTDocumentRef doc, int32_t index);

/// Geometric tolerance info result
typedef struct {
    int32_t type;         // XCAFDimTolObjects_GeomToleranceType enum
    double value;         // tolerance value
    bool isValid;
} OCCTGeomToleranceInfo;

/// Get geometric tolerance info at index
OCCTGeomToleranceInfo OCCTDocumentGetGeomToleranceInfo(OCCTDocumentRef doc, int32_t index);

/// Datum info result
typedef struct {
    char name[64];        // datum identifier (A, B, C, etc.)
    bool isValid;
} OCCTDatumInfo;

/// Get datum info at index
OCCTDatumInfo OCCTDocumentGetDatumInfo(OCCTDocumentRef doc, int32_t index);


// MARK: - NLPlate: Advanced Plate Surfaces (v0.23.0)

/// Constraint order for advanced plate surface construction
typedef enum {
    OCCTPlateConstraintG0 = 0,  // Position only
    OCCTPlateConstraintG1 = 1,  // Position + tangent
    OCCTPlateConstraintG2 = 2   // Position + tangent + curvature
} OCCTPlateConstraintOrder;

/// Create a plate surface through points with specified constraint orders.
/// points: flat array of (x,y,z). orders: G0/G1/G2 per point.
/// Returns a BSpline face approximation.
OCCTShapeRef OCCTShapePlatePointsAdvanced(const double* points, int32_t pointCount,
                                           const int32_t* orders, int32_t degree,
                                           int32_t nbPtsOnCur, int32_t nbIter,
                                           double tolerance);

/// Create a plate surface with mixed point and curve constraints.
OCCTShapeRef OCCTShapePlateMixed(const double* points, const int32_t* pointOrders,
                                  int32_t pointCount,
                                  const OCCTWireRef* curves, const int32_t* curveOrders,
                                  int32_t curveCount,
                                  int32_t degree, double tolerance);

/// Create a plate surface (as parametric Surface) through points.
/// Uses GeomPlate_BuildPlateSurface + GeomPlate_MakeApprox.
OCCTSurfaceRef OCCTSurfacePlateThrough(const double* points, int32_t pointCount,
                                        int32_t degree, double tolerance);

/// Deform a surface to pass through constraint points (NLPlate G0).
/// constraints: flat array of (u, v, targetX, targetY, targetZ) per point.
OCCTSurfaceRef OCCTSurfaceNLPlateG0(OCCTSurfaceRef initialSurface,
                                     const double* constraints, int32_t constraintCount,
                                     int32_t maxIter, double tolerance);

/// Deform a surface with position + tangent constraints (NLPlate G0+G1).
/// constraints: flat (u, v, targetX, targetY, targetZ, d1uX, d1uY, d1uZ, d1vX, d1vY, d1vZ) per point.
OCCTSurfaceRef OCCTSurfaceNLPlateG1(OCCTSurfaceRef initialSurface,
                                     const double* constraints, int32_t constraintCount,
                                     int32_t maxIter, double tolerance);


// MARK: - ProjLib: Curve Projection onto Surfaces (v0.22.0)

/// Project a 3D curve onto a surface, returning a 2D (UV) curve.
/// Uses GeomProjLib::Curve2d. Returns NULL on failure.
OCCTCurve2DRef OCCTSurfaceProjectCurve2D(OCCTSurfaceRef surface,
                                          OCCTCurve3DRef curve,
                                          double tolerance);

/// Project a 3D curve onto a surface using composite projection (multiple segments).
/// Returns the number of 2D curve segments written to outCurves (up to maxCurves).
/// Uses ProjLib_CompProjectedCurve.
int32_t OCCTSurfaceProjectCurveSegments(OCCTSurfaceRef surface,
                                         OCCTCurve3DRef curve,
                                         double tolerance,
                                         OCCTCurve2DRef* outCurves,
                                         int32_t maxCurves);

/// Project a 3D curve onto a surface, returning the result as a 3D curve.
/// Uses GeomProjLib::Project. Returns NULL on failure.
OCCTCurve3DRef OCCTSurfaceProjectCurve3D(OCCTSurfaceRef surface,
                                          OCCTCurve3DRef curve);

/// Project a 3D curve onto a plane along a direction, returning a 3D curve.
/// Uses GeomProjLib::ProjectOnPlane.
/// (oX,oY,oZ) = plane origin, (nX,nY,nZ) = plane normal, (dX,dY,dZ) = projection direction.
OCCTCurve3DRef OCCTCurve3DProjectOnPlane(OCCTCurve3DRef curve,
                                          double oX, double oY, double oZ,
                                          double nX, double nY, double nZ,
                                          double dX, double dY, double dZ);

/// Project a point onto a parametric surface (closest point).
/// Returns true on success, writing UV parameters and distance.
/// Uses GeomAPI_ProjectPointOnSurf.
bool OCCTSurfaceProjectPoint(OCCTSurfaceRef surface,
                              double px, double py, double pz,
                              double* u, double* v, double* distance);


// MARK: - BRepMAT2d: Medial Axis Transform (v0.24.0)

/// Opaque handle for a computed medial axis of a planar face.
typedef struct OCCTMedialAxis* OCCTMedialAxisRef;

/// Node in the medial axis graph: position (x,y) and distance to boundary.
typedef struct {
    int32_t index;
    double x;
    double y;
    double distance;  // inscribed circle radius at this node
    bool isPending;   // true if node has only one linked arc (endpoint)
    bool isOnBoundary;
} OCCTMedialAxisNode;

/// Arc in the medial axis graph: connects two nodes, separates two boundary elements.
typedef struct {
    int32_t index;
    int32_t geomIndex;
    int32_t firstNodeIndex;
    int32_t secondNodeIndex;
    int32_t firstEltIndex;
    int32_t secondEltIndex;
} OCCTMedialAxisArc;

/// Compute the medial axis of a planar face.
/// The shape must contain at least one face; the first face is used.
/// Returns NULL on failure.
OCCTMedialAxisRef OCCTMedialAxisCompute(OCCTShapeRef shape, double tolerance);

/// Release a medial axis computation.
void OCCTMedialAxisRelease(OCCTMedialAxisRef ma);

/// Get the number of arcs (bisector curves) in the medial axis graph.
int32_t OCCTMedialAxisGetArcCount(OCCTMedialAxisRef ma);

/// Get the number of nodes (arc endpoints) in the medial axis graph.
int32_t OCCTMedialAxisGetNodeCount(OCCTMedialAxisRef ma);

/// Get information about a node by index (1-based).
/// Returns true on success.
bool OCCTMedialAxisGetNode(OCCTMedialAxisRef ma, int32_t index, OCCTMedialAxisNode* outNode);

/// Get information about an arc by index (1-based).
/// Returns true on success.
bool OCCTMedialAxisGetArc(OCCTMedialAxisRef ma, int32_t index, OCCTMedialAxisArc* outArc);

/// Sample points along a bisector arc. Returns the number of points written.
/// Points are written as (x,y) pairs into outXY (so outXY needs 2*maxPoints capacity).
/// index is 1-based.
int32_t OCCTMedialAxisDrawArc(OCCTMedialAxisRef ma, int32_t arcIndex,
                               double* outXY, int32_t maxPoints);

/// Sample all bisector arcs. Returns total number of points written.
/// outXY receives (x,y) pairs. lineStarts receives the starting index in outXY
/// for each arc. maxLines should be >= arc count.
int32_t OCCTMedialAxisDrawAll(OCCTMedialAxisRef ma,
                               double* outXY, int32_t maxPoints,
                               int32_t* lineStarts, int32_t* lineLengths, int32_t maxLines);

/// Get the inscribed circle distance (radius) at a point along an arc.
/// arcIndex is 1-based, t is in [0,1] where 0=firstNode, 1=secondNode.
double OCCTMedialAxisDistanceOnArc(OCCTMedialAxisRef ma, int32_t arcIndex, double t);

/// Get the minimum distance (half-thickness) across the entire medial axis.
/// Returns the smallest inscribed circle radius found at any node.
double OCCTMedialAxisMinThickness(OCCTMedialAxisRef ma);

/// Get the number of boundary elements (input edges) in the medial axis.
int32_t OCCTMedialAxisGetBasicEltCount(OCCTMedialAxisRef ma);


// MARK: - TNaming: Topological Naming History (v0.25.0)

/// Evolution type for TNaming history records.
typedef enum {
    OCCTNamingPrimitive  = 0,  ///< New entity created (old=NULL, new=shape)
    OCCTNamingGenerated  = 1,  ///< Entity generated from another (old=generator, new=result)
    OCCTNamingModify     = 2,  ///< Entity modified (old=before, new=after)
    OCCTNamingDelete     = 3,  ///< Entity deleted (old=shape, new=NULL)
    OCCTNamingSelected   = 4   ///< Named selection (old=context, new=selected)
} OCCTNamingEvolution;

/// A single entry in the naming history of a label.
typedef struct {
    OCCTNamingEvolution evolution;
    bool hasOldShape;
    bool hasNewShape;
    bool isModification;
} OCCTNamingHistoryEntry;

/// Create a new child label under the given parent label.
/// Pass parentLabelId = -1 to create under the document root.
/// Returns the new label's ID, or -1 on failure.
int64_t OCCTDocumentCreateLabel(OCCTDocumentRef doc, int64_t parentLabelId);

/// Record a naming evolution on a label.
/// For PRIMITIVE: oldShape=NULL, newShape=the created shape.
/// For GENERATED: oldShape=generator, newShape=generated result.
/// For MODIFY: oldShape=before, newShape=after.
/// For DELETE: oldShape=deleted shape, newShape=NULL.
/// For SELECTED: oldShape=context, newShape=selected shape.
/// Returns true on success.
bool OCCTDocumentNamingRecord(OCCTDocumentRef doc, int64_t labelId,
                               OCCTNamingEvolution evolution,
                               OCCTShapeRef oldShape, OCCTShapeRef newShape);

/// Get the current (most recent) shape stored on a label via TNaming.
/// Uses TNaming_Tool::CurrentShape. Returns NULL if no naming exists.
OCCTShapeRef OCCTDocumentNamingGetCurrentShape(OCCTDocumentRef doc, int64_t labelId);

/// Get the shape stored in the NamedShape attribute on a label.
/// Uses TNaming_Tool::GetShape. Returns NULL if no naming exists.
OCCTShapeRef OCCTDocumentNamingGetShape(OCCTDocumentRef doc, int64_t labelId);

/// Get the number of history entries (old/new pairs) on a label.
int32_t OCCTDocumentNamingHistoryCount(OCCTDocumentRef doc, int64_t labelId);

/// Get a specific history entry by index (0-based).
/// Returns true on success.
bool OCCTDocumentNamingGetHistoryEntry(OCCTDocumentRef doc, int64_t labelId,
                                        int32_t index, OCCTNamingHistoryEntry* outEntry);

/// Get the old shape from a specific history entry (0-based index).
/// Returns NULL if the entry has no old shape.
OCCTShapeRef OCCTDocumentNamingGetOldShape(OCCTDocumentRef doc, int64_t labelId, int32_t index);

/// Get the new shape from a specific history entry (0-based index).
/// Returns NULL if the entry has no new shape.
OCCTShapeRef OCCTDocumentNamingGetNewShape(OCCTDocumentRef doc, int64_t labelId, int32_t index);

/// Trace forward: find all shapes generated/modified from the given shape.
/// Uses TNaming_NewShapeIterator. accessLabelId provides the label scope.
/// Returns the number of shapes written to outShapes (up to maxCount).
/// Caller must release each returned shape.
int32_t OCCTDocumentNamingTraceForward(OCCTDocumentRef doc, int64_t accessLabelId,
                                        OCCTShapeRef shape,
                                        OCCTShapeRef* outShapes, int32_t maxCount);

/// Trace backward: find all shapes that generated/preceded the given shape.
/// Uses TNaming_OldShapeIterator. accessLabelId provides the label scope.
/// Returns the number of shapes written to outShapes (up to maxCount).
/// Caller must release each returned shape.
int32_t OCCTDocumentNamingTraceBackward(OCCTDocumentRef doc, int64_t accessLabelId,
                                         OCCTShapeRef shape,
                                         OCCTShapeRef* outShapes, int32_t maxCount);

/// Select a shape for persistent naming.
/// Creates a TNaming_Selector on the label and selects the shape within context.
/// Returns true on success.
bool OCCTDocumentNamingSelect(OCCTDocumentRef doc, int64_t labelId,
                               OCCTShapeRef selection, OCCTShapeRef context);

/// Resolve a previously selected shape after modifications.
/// Uses TNaming_Selector::Solve to update the selection.
/// Returns the resolved shape, or NULL on failure.
OCCTShapeRef OCCTDocumentNamingResolve(OCCTDocumentRef doc, int64_t labelId);

/// Get the evolution type of the NamedShape attribute on a label.
/// Returns -1 if no NamedShape exists on the label.
int32_t OCCTDocumentNamingGetEvolution(OCCTDocumentRef doc, int64_t labelId);


// ============================================================
// MARK: - AIS Annotations & Measurements (v0.26.0)
// ============================================================

/// Opaque handle to a dimension measurement (length, radius, angle, or diameter).
typedef struct OCCTDimension* OCCTDimensionRef;

/// Opaque handle to a positioned text label.
typedef struct OCCTTextLabel* OCCTTextLabelRef;

/// Opaque handle to a point cloud.
typedef struct OCCTPointCloud* OCCTPointCloudRef;

/// Kind of dimension measurement.
typedef enum {
    OCCTDimensionKindLength   = 0,
    OCCTDimensionKindRadius   = 1,
    OCCTDimensionKindAngle    = 2,
    OCCTDimensionKindDiameter = 3
} OCCTDimensionKind;

/// Geometry extracted from a dimension for Metal rendering.
typedef struct {
    double firstPoint[3];     ///< First attachment point (on geometry)
    double secondPoint[3];    ///< Second attachment point (on geometry)
    double centerPoint[3];    ///< Angle vertex; or circle center for radius/diameter
    double textPosition[3];   ///< Suggested text placement position
    double circleNormal[3];   ///< Circle axis for radius/diameter dimensions
    double circleRadius;      ///< Circle radius for radius/diameter dimensions
    double value;             ///< Measured value (distance in model units, angle in radians)
    int32_t kind;             ///< OCCTDimensionKind
    bool isValid;             ///< Whether the geometry is valid
} OCCTDimensionGeometry;

/// Info extracted from a text label.
typedef struct {
    double position[3];
    double height;
    char text[256];
} OCCTTextLabelInfo;

// --- Dimension creation ---

/// Create a length dimension between two 3D points.
OCCTDimensionRef OCCTDimensionCreateLengthFromPoints(
    double p1x, double p1y, double p1z,
    double p2x, double p2y, double p2z);

/// Create a length dimension measuring a linear edge.
OCCTDimensionRef OCCTDimensionCreateLengthFromEdge(OCCTShapeRef edge);

/// Create a length dimension between two parallel faces.
OCCTDimensionRef OCCTDimensionCreateLengthFromFaces(
    OCCTShapeRef face1, OCCTShapeRef face2);

/// Create a radius dimension from a shape with circular geometry.
OCCTDimensionRef OCCTDimensionCreateRadiusFromShape(OCCTShapeRef shape);

/// Create an angle dimension between two edges.
OCCTDimensionRef OCCTDimensionCreateAngleFromEdges(
    OCCTShapeRef edge1, OCCTShapeRef edge2);

/// Create an angle dimension from three points (first, vertex, second).
OCCTDimensionRef OCCTDimensionCreateAngleFromPoints(
    double p1x, double p1y, double p1z,
    double cx, double cy, double cz,
    double p2x, double p2y, double p2z);

/// Create an angle dimension between two planar faces.
OCCTDimensionRef OCCTDimensionCreateAngleFromFaces(
    OCCTShapeRef face1, OCCTShapeRef face2);

/// Create a diameter dimension from a shape with circular geometry.
OCCTDimensionRef OCCTDimensionCreateDiameterFromShape(OCCTShapeRef shape);

// --- Dimension common functions ---

/// Release a dimension handle.
void OCCTDimensionRelease(OCCTDimensionRef dim);

/// Get the measured (or custom) value of a dimension.
double OCCTDimensionGetValue(OCCTDimensionRef dim);

/// Get the full dimension geometry for rendering.
bool OCCTDimensionGetGeometry(OCCTDimensionRef dim, OCCTDimensionGeometry* outGeometry);

/// Override the dimension value with a custom number.
void OCCTDimensionSetCustomValue(OCCTDimensionRef dim, double value);

/// Check if the dimension geometry is valid.
bool OCCTDimensionIsValid(OCCTDimensionRef dim);

/// Get the kind of this dimension.
int32_t OCCTDimensionGetKind(OCCTDimensionRef dim);

// --- Text Label ---

/// Create a text label at a 3D position.
OCCTTextLabelRef OCCTTextLabelCreate(const char* text,
                                      double x, double y, double z);

/// Release a text label handle.
void OCCTTextLabelRelease(OCCTTextLabelRef label);

/// Set the label text.
void OCCTTextLabelSetText(OCCTTextLabelRef label, const char* text);

/// Set the label position.
void OCCTTextLabelSetPosition(OCCTTextLabelRef label,
                               double x, double y, double z);

/// Set the label text height.
void OCCTTextLabelSetHeight(OCCTTextLabelRef label, double height);

/// Get label info (text, position, height).
bool OCCTTextLabelGetInfo(OCCTTextLabelRef label, OCCTTextLabelInfo* outInfo);

// --- Point Cloud ---

/// Create a point cloud from xyz coordinate triples.
/// @param coords Array of [x0,y0,z0, x1,y1,z1, ...] (3 * count doubles)
/// @param count Number of points
OCCTPointCloudRef OCCTPointCloudCreate(const double* coords, int32_t count);

/// Create a colored point cloud.
/// @param coords Array of xyz triples (3 * count doubles)
/// @param colors Array of rgb triples (3 * count floats, each in [0,1])
/// @param count Number of points
OCCTPointCloudRef OCCTPointCloudCreateColored(const double* coords,
                                               const float* colors,
                                               int32_t count);

/// Release a point cloud handle.
void OCCTPointCloudRelease(OCCTPointCloudRef cloud);

/// Get the number of points in the cloud.
int32_t OCCTPointCloudGetCount(OCCTPointCloudRef cloud);

/// Get the axis-aligned bounding box.
/// Returns true on success, fills minXYZ[3] and maxXYZ[3].
bool OCCTPointCloudGetBounds(OCCTPointCloudRef cloud,
                              double* outMinXYZ, double* outMaxXYZ);

/// Copy point coordinates into the output buffer.
/// @param outCoords Buffer for xyz triples (must hold at least 3 * count doubles)
/// @param maxCount Maximum number of points to copy
/// @return Number of points copied
int32_t OCCTPointCloudGetPoints(OCCTPointCloudRef cloud,
                                 double* outCoords, int32_t maxCount);

/// Copy point colors into the output buffer.
/// @param outColors Buffer for rgb triples (must hold at least 3 * count floats)
/// @param maxCount Maximum number of colors to copy
/// @return Number of colors copied (0 if uncolored)
int32_t OCCTPointCloudGetColors(OCCTPointCloudRef cloud,
                                 float* outColors, int32_t maxCount);


// MARK: - Helix Curves (v0.28.0)

/// Create a helical wire (constant radius).
/// @param originX/Y/Z Helix axis origin
/// @param axisX/Y/Z Helix axis direction
/// @param radius Helix radius
/// @param pitch Distance between consecutive turns
/// @param turns Number of turns
/// @param clockwise true for clockwise, false for counter-clockwise
OCCTWireRef OCCTWireCreateHelix(double originX, double originY, double originZ,
                                 double axisX, double axisY, double axisZ,
                                 double radius, double pitch, double turns,
                                 bool clockwise);

/// Create a tapered (conical) helical wire.
/// @param startRadius Radius at the start
/// @param endRadius Radius at the end
OCCTWireRef OCCTWireCreateHelixTapered(double originX, double originY, double originZ,
                                        double axisX, double axisY, double axisZ,
                                        double startRadius, double endRadius,
                                        double pitch, double turns,
                                        bool clockwise);

// MARK: - KD-Tree Spatial Queries (v0.28.0)

/// Opaque handle to a KD-tree for 3D point queries.
typedef struct OCCTKDTree* OCCTKDTreeRef;

/// Build a KD-tree from 3D points.
/// @param coords Flat array of xyz coordinates (3 * count doubles)
/// @param count Number of points
OCCTKDTreeRef OCCTKDTreeBuild(const double* coords, int32_t count);

/// Release a KD-tree.
void OCCTKDTreeRelease(OCCTKDTreeRef tree);

/// Find the nearest point in the tree to a query point.
/// @param outDistance If non-null, receives the distance (not squared)
/// @return 0-based index of the nearest point, or -1 on error
int32_t OCCTKDTreeNearestPoint(OCCTKDTreeRef tree,
                                double qx, double qy, double qz,
                                double* outDistance);

/// Find the K nearest points.
/// @param outIndices Buffer for 0-based indices (must hold at least k entries)
/// @param outSqDistances Buffer for squared distances (may be null)
/// @param k Number of neighbors to find
/// @return Number of points found
int32_t OCCTKDTreeKNearest(OCCTKDTreeRef tree,
                            double qx, double qy, double qz,
                            int32_t k,
                            int32_t* outIndices,
                            double* outSqDistances);

/// Find all points within a sphere of given radius.
/// @param outIndices Buffer for 0-based indices
/// @param maxResults Maximum number of results
/// @return Number of points found
int32_t OCCTKDTreeRangeSearch(OCCTKDTreeRef tree,
                               double qx, double qy, double qz,
                               double radius,
                               int32_t* outIndices, int32_t maxResults);

/// Find all points within an axis-aligned bounding box.
int32_t OCCTKDTreeBoxSearch(OCCTKDTreeRef tree,
                             double minX, double minY, double minZ,
                             double maxX, double maxY, double maxZ,
                             int32_t* outIndices, int32_t maxResults);

// MARK: - STEP Optimization (v0.28.0)

/// Optimize a STEP file by merging duplicate entities.
/// Reads a STEP file, deduplicates geometric entities, and writes the result.
/// @param inputPath Path to input STEP file
/// @param outputPath Path to output STEP file
/// @return true on success
bool OCCTStepTidyOptimize(const char* inputPath, const char* outputPath);

// MARK: - Batch Curve2D Evaluation (v0.28.0)

/// Evaluate a 2D curve at multiple parameter values (batch).
/// @param curve The curve to evaluate
/// @param params Array of parameter values
/// @param paramCount Number of parameters
/// @param outXY Output buffer for xy pairs (must hold 2 * paramCount doubles)
/// @return Number of points evaluated
int32_t OCCTCurve2DEvaluateGrid(OCCTCurve2DRef curve,
                                 const double* params, int32_t paramCount,
                                 double* outXY);

/// Evaluate a 2D curve and its first derivative at multiple parameters (batch).
/// @param outXY Output buffer for point xy pairs (2 * paramCount doubles)
/// @param outDXDY Output buffer for derivative xy pairs (2 * paramCount doubles)
/// @return Number of points evaluated
int32_t OCCTCurve2DEvaluateGridD1(OCCTCurve2DRef curve,
                                   const double* params, int32_t paramCount,
                                   double* outXY, double* outDXDY);


// MARK: - Wedge Primitive (v0.29.0)

/// Create a wedge (tapered box) primitive.
/// @param dx, dy, dz Full dimensions in X, Y, Z
/// @param ltx X dimension at the top (0 for a full taper to a ridge)
/// @return Wedge shape, or NULL on failure
OCCTShapeRef OCCTShapeCreateWedge(double dx, double dy, double dz, double ltx);

/// Create a wedge primitive with min/max control on the top face.
/// @param dx, dy, dz Full dimensions in X, Y, Z
/// @param xmin, zmin, xmax, zmax Bounds of the top face within the base
/// @return Wedge shape, or NULL on failure
OCCTShapeRef OCCTShapeCreateWedgeAdvanced(double dx, double dy, double dz,
                                           double xmin, double zmin, double xmax, double zmax);


// MARK: - NURBS Conversion (v0.29.0)

/// Convert all geometry in a shape to NURBS representation.
/// @param shape The shape to convert
/// @return NURBS shape, or NULL on failure
OCCTShapeRef OCCTShapeConvertToNURBS(OCCTShapeRef shape);


// MARK: - Fast Sewing (v0.29.0)

/// Sew faces using the fast sewing algorithm (less robust but faster).
/// @param shape The shape to sew
/// @param tolerance Sewing tolerance
/// @return Sewn shape, or NULL on failure
OCCTShapeRef OCCTShapeFastSewn(OCCTShapeRef shape, double tolerance);


// MARK: - Normal Projection (v0.29.0)

/// Project a wire or edge normally onto a surface shape.
/// @param wireOrEdge Wire or edge to project
/// @param surface Surface shape to project onto
/// @param tol3d 3D tolerance
/// @param tol2d 2D tolerance
/// @param maxDegree Maximum degree of resulting curve
/// @param maxSeg Maximum segments of resulting curve
/// @return Projected shape, or NULL on failure
OCCTShapeRef OCCTShapeNormalProjection(OCCTShapeRef wireOrEdge, OCCTShapeRef surface,
                                        double tol3d, double tol2d, int maxDegree, int maxSeg);


// MARK: - Batch Curve3D Evaluation (v0.29.0)

/// Evaluate a 3D curve at multiple parameter values (batch).
/// @param curve The curve to evaluate
/// @param params Array of parameter values
/// @param paramCount Number of parameters
/// @param outXYZ Output buffer for xyz triples (must hold 3 * paramCount doubles)
/// @return Number of points evaluated
int32_t OCCTCurve3DEvaluateGrid(OCCTCurve3DRef curve, const double* params, int32_t paramCount,
                                 double* outXYZ);

/// Evaluate a 3D curve and its first derivative at multiple parameters (batch).
/// @param outXYZ Output buffer for point xyz triples (3 * paramCount doubles)
/// @param outDXDYDZ Output buffer for derivative xyz triples (3 * paramCount doubles)
/// @return Number of points evaluated
int32_t OCCTCurve3DEvaluateGridD1(OCCTCurve3DRef curve, const double* params, int32_t paramCount,
                                   double* outXYZ, double* outDXDYDZ);


// MARK: - Batch Surface Evaluation (v0.29.0)

/// Evaluate a surface at a grid of UV parameter values (batch).
/// Output is row-major (u varies fastest): outXYZ[(iv * uCount + iu) * 3 + {0,1,2}].
/// @param surface The surface to evaluate
/// @param uParams Array of U parameter values
/// @param uCount Number of U parameters
/// @param vParams Array of V parameter values
/// @param vCount Number of V parameters
/// @param outXYZ Output buffer for xyz triples (must hold 3 * uCount * vCount doubles)
/// @return Number of points evaluated (uCount * vCount on success)
int32_t OCCTSurfaceEvaluateGrid(OCCTSurfaceRef surface,
                                 const double* uParams, int32_t uCount,
                                 const double* vParams, int32_t vCount,
                                 double* outXYZ);


// MARK: - Wire Explorer (v0.29.0)

/// Get the number of edges in a wire by ordered traversal.
/// @param wire The wire to explore
/// @return Number of edges
int32_t OCCTWireExplorerEdgeCount(OCCTWireRef wire);

/// Get a discretized edge from a wire by ordered traversal index.
/// @param wire The wire to explore
/// @param index 0-based edge index
/// @param outPoints Output buffer for xyz triples [x,y,z,...]
/// @param maxPoints Maximum number of points to output
/// @param outPointCount Output: actual number of points written
/// @return true on success
bool OCCTWireExplorerGetEdge(OCCTWireRef wire, int32_t index,
                              double* outPoints, int32_t maxPoints, int32_t* outPointCount);


// MARK: - Half-Space (v0.29.0)

/// Create a half-space solid from a face and a reference point.
/// The half-space is the solid containing the reference point.
/// @param faceShape Shape containing a face (first face is used)
/// @param refX, refY, refZ Reference point in the desired half-space
/// @return Half-space solid, or NULL on failure
OCCTShapeRef OCCTShapeCreateHalfSpace(OCCTShapeRef faceShape, double refX, double refY, double refZ);


// MARK: - Polynomial Solvers (v0.29.0)

/// Result of a polynomial root finding operation.
typedef struct {
    int32_t count;
    double roots[4];
} OCCTPolynomialRoots;

/// Solve a quadratic equation: a*x^2 + b*x + c = 0
OCCTPolynomialRoots OCCTSolveQuadratic(double a, double b, double c);

/// Solve a cubic equation: a*x^3 + b*x^2 + c*x + d = 0
OCCTPolynomialRoots OCCTSolveCubic(double a, double b, double c, double d);

/// Solve a quartic equation: a*x^4 + b*x^3 + c*x^2 + d*x + e = 0
OCCTPolynomialRoots OCCTSolveQuartic(double a, double b, double c, double d, double e);


// MARK: - Sub-Shape Replacement (v0.29.0)

/// Replace a sub-shape within a shape.
/// @param shape The parent shape
/// @param oldSub Sub-shape to replace
/// @param newSub Replacement sub-shape
/// @return Modified shape, or NULL on failure
OCCTShapeRef OCCTShapeReplaceSubShape(OCCTShapeRef shape, OCCTShapeRef oldSub, OCCTShapeRef newSub);

/// Remove a sub-shape from a shape.
/// @param shape The parent shape
/// @param subToRemove Sub-shape to remove
/// @return Modified shape, or NULL on failure
OCCTShapeRef OCCTShapeRemoveSubShape(OCCTShapeRef shape, OCCTShapeRef subToRemove);


// MARK: - Periodic Shapes (v0.29.0)

/// Make a shape periodic in one or more directions.
/// @param shape The shape to make periodic
/// @param xPeriodic, yPeriodic, zPeriodic Enable periodicity in each direction
/// @param xPeriod, yPeriod, zPeriod Period value in each direction
/// @return Periodic shape, or NULL on failure
OCCTShapeRef OCCTShapeMakePeriodic(OCCTShapeRef shape,
                                    bool xPeriodic, double xPeriod,
                                    bool yPeriodic, double yPeriod,
                                    bool zPeriodic, double zPeriod);

/// Repeat a periodic shape in one or more directions.
/// @param shape The base shape (should be made periodic first)
/// @param xPeriodic, yPeriodic, zPeriodic Enable repetition in each direction
/// @param xPeriod, yPeriod, zPeriod Period value for repetition
/// @param xTimes, yTimes, zTimes Number of repetitions in each direction
/// @return Repeated shape, or NULL on failure
OCCTShapeRef OCCTShapeRepeat(OCCTShapeRef shape,
                              bool xPeriodic, double xPeriod,
                              bool yPeriodic, double yPeriod,
                              bool zPeriodic, double zPeriod,
                              int32_t xTimes, int32_t yTimes, int32_t zTimes);


// MARK: - Hatch Patterns (v0.29.0)

/// Generate hatch line segments within a 2D polygon boundary.
/// @param boundaryXY Flat array of (x,y) pairs defining the boundary polygon
/// @param boundaryCount Number of boundary points
/// @param dirX, dirY Hatch line direction
/// @param spacing Distance between hatch lines
/// @param offset Offset of the first hatch line from origin
/// @param outSegments Output buffer: pairs of (x1,y1,x2,y2) per segment (4 doubles each)
/// @param maxSegments Maximum number of output segments
/// @return Number of segments written
int32_t OCCTHatchLines(const double* boundaryXY, int32_t boundaryCount,
                        double dirX, double dirY, double spacing, double offset,
                        double* outSegments, int32_t maxSegments);


// MARK: - Draft from Shape (v0.29.0)

/// Create a draft shell by sweeping a shape along a direction with taper angle.
/// @param shape Wire or edge to draft from
/// @param dirX, dirY, dirZ Draft direction
/// @param angle Taper angle in radians
/// @param lengthMax Maximum draft length
/// @return Draft shell shape, or NULL on failure
OCCTShapeRef OCCTShapeMakeDraft(OCCTShapeRef shape, double dirX, double dirY, double dirZ,
                                 double angle, double lengthMax);


// MARK: - Curve Planarity Check (v0.29.0)

/// Check if a 3D curve is planar.
/// @param curve The curve to check
/// @param tolerance Planarity tolerance
/// @param outNX, outNY, outNZ Output: normal of the plane (if planar)
/// @return true if the curve is planar
bool OCCTCurve3DIsPlanar(OCCTCurve3DRef curve, double tolerance,
                          double* outNX, double* outNY, double* outNZ);


// MARK: - Revolution Feature (v0.29.0)

// NOTE: BRepFeat_MakeRevol is complex (requires sketch face identification).
// This function is omitted because identifying the correct sketch face from the
// profile shape is highly context-dependent and error-prone in a generic C bridge.
// Users should instead use OCCTShapeCreateRevolution (sweep-based) for revolution solids,
// or BRepAlgoAPI_Fuse/Cut for adding/subtracting revolved material.


// MARK: - Non-Uniform Transform (v0.30.0)

/// Apply non-uniform scaling to a shape using BRepBuilderAPI_GTransform.
/// @param shape The shape to scale
/// @param sx Scale factor in X direction
/// @param sy Scale factor in Y direction
/// @param sz Scale factor in Z direction
/// @return Scaled shape, or NULL on failure
OCCTShapeRef OCCTShapeNonUniformScale(OCCTShapeRef shape, double sx, double sy, double sz);


// MARK: - Make Shell (v0.30.0)

/// Create a shell from a surface using BRepBuilderAPI_MakeShell.
/// @param surface The surface to convert to a shell
/// @return Shell shape, or NULL on failure
OCCTShapeRef OCCTShapeCreateShellFromSurface(OCCTSurfaceRef surface);


// MARK: - Make Vertex (v0.30.0)

/// Create a vertex at a point using BRepBuilderAPI_MakeVertex.
/// @param x X coordinate
/// @param y Y coordinate
/// @param z Z coordinate
/// @return Vertex shape, or NULL on failure
OCCTShapeRef OCCTShapeCreateVertex(double x, double y, double z);


// MARK: - Simple Offset (v0.30.0)

/// Create a simple offset of a shape using BRepOffset_MakeSimpleOffset.
/// @param shape The shape to offset
/// @param offsetValue Offset distance (positive = outward)
/// @return Offset shape, or NULL on failure
OCCTShapeRef OCCTShapeSimpleOffset(OCCTShapeRef shape, double offsetValue);


// MARK: - Middle Path (v0.30.0)

/// Compute the middle path between two sub-shapes using BRepOffsetAPI_MiddlePath.
/// @param shape The main shape (typically a solid or shell)
/// @param startShape Start sub-shape (wire or edge on the shape)
/// @param endShape End sub-shape (wire or edge on the shape)
/// @return Middle path wire, or NULL on failure
OCCTShapeRef OCCTShapeMiddlePath(OCCTShapeRef shape, OCCTShapeRef startShape, OCCTShapeRef endShape);


// MARK: - Fuse Edges (v0.30.0)

/// Fuse connected edges sharing the same geometry using BRepLib_FuseEdges.
/// @param shape The shape containing edges to fuse
/// @return Shape with fused edges, or NULL on failure
OCCTShapeRef OCCTShapeFuseEdges(OCCTShapeRef shape);


// MARK: - Maker Volume (v0.30.0)

/// Create a solid volume from a set of shapes using BOPAlgo_MakerVolume.
/// @param shapes Array of shape references
/// @param count Number of shapes
/// @return Volume solid, or NULL on failure
OCCTShapeRef OCCTShapeMakeVolume(OCCTShapeRef* shapes, int32_t count);


// MARK: - Make Connected (v0.30.0)

/// Make a set of shapes connected using BOPAlgo_MakeConnected.
/// @param shapes Array of shape references
/// @param count Number of shapes
/// @return Connected shape, or NULL on failure
OCCTShapeRef OCCTShapeMakeConnected(OCCTShapeRef* shapes, int32_t count);


// MARK: - Curve-Curve Extrema (v0.30.0)

/// Result structure for curve-curve extrema computation.
typedef struct {
    double distance;    ///< Distance between closest points
    double point1[3];   ///< Closest point on curve 1 (x, y, z)
    double point2[3];   ///< Closest point on curve 2 (x, y, z)
    double param1;      ///< Parameter on curve 1
    double param2;      ///< Parameter on curve 2
} OCCTCurveExtrema;

/// Compute the minimum distance between two 3D curves.
/// @param c1 First curve
/// @param c2 Second curve
/// @return Minimum distance, or -1.0 on failure
double OCCTCurve3DMinDistanceToCurve(OCCTCurve3DRef c1, OCCTCurve3DRef c2);

/// Compute all extrema (closest/farthest point pairs) between two 3D curves.
/// @param c1 First curve
/// @param c2 Second curve
/// @param outExtrema Output buffer for extrema results
/// @param maxCount Maximum number of results to write
/// @return Number of extrema found, or 0 on failure
int32_t OCCTCurve3DExtrema(OCCTCurve3DRef c1, OCCTCurve3DRef c2, OCCTCurveExtrema* outExtrema, int32_t maxCount);


// MARK: - Curve-Surface Intersection (v0.30.0)

/// Result structure for curve-surface intersection.
typedef struct {
    double point[3];    ///< Intersection point (x, y, z)
    double paramCurve;  ///< W parameter on the curve
    double paramU;      ///< U parameter on the surface
    double paramV;      ///< V parameter on the surface
} OCCTCurveSurfaceIntersection;

/// Compute intersection points between a 3D curve and a surface.
/// @param curve The 3D curve
/// @param surface The surface
/// @param outHits Output buffer for intersection results
/// @param maxHits Maximum number of results to write
/// @return Number of intersections found, or 0 on failure
int32_t OCCTCurve3DIntersectSurface(OCCTCurve3DRef curve, OCCTSurfaceRef surface,
                                     OCCTCurveSurfaceIntersection* outHits, int32_t maxHits);


// MARK: - Surface-Surface Intersection (v0.30.0)

/// Compute intersection curves between two surfaces.
/// @param s1 First surface
/// @param s2 Second surface
/// @param tolerance Intersection tolerance
/// @param outCurves Output buffer for intersection curve references
/// @param maxCurves Maximum number of curves to write
/// @return Number of intersection curves found, or 0 on failure
int32_t OCCTSurfaceIntersect(OCCTSurfaceRef s1, OCCTSurfaceRef s2, double tolerance,
                              OCCTCurve3DRef* outCurves, int32_t maxCurves);


// MARK: - Curve-Surface Distance (v0.30.0)

/// Compute the minimum distance between a 3D curve and a surface.
/// @param curve The 3D curve
/// @param surface The surface
/// @return Minimum distance, or -1.0 on failure
double OCCTCurve3DDistanceToSurface(OCCTCurve3DRef curve, OCCTSurfaceRef surface);


// MARK: - Curve to Analytical (v0.30.0)

/// Convert a curve to its analytical (canonical) form if possible.
/// @param curve The input curve
/// @param tolerance Conversion tolerance
/// @return Analytical curve, or NULL if conversion is not possible
OCCTCurve3DRef OCCTCurve3DToAnalytical(OCCTCurve3DRef curve, double tolerance);


// MARK: - Surface to Analytical (v0.30.0)

/// Convert a surface to its analytical (canonical) form if possible.
/// @param surface The input surface
/// @param tolerance Conversion tolerance
/// @return Analytical surface, or NULL if conversion is not possible
OCCTSurfaceRef OCCTSurfaceToAnalytical(OCCTSurfaceRef surface, double tolerance);


// MARK: - Shape Contents (v0.30.0)

/// Structure containing counts of topological entities in a shape.
typedef struct {
    int32_t nbSolids;      ///< Number of solids
    int32_t nbShells;      ///< Number of shells
    int32_t nbFaces;       ///< Number of faces
    int32_t nbWires;       ///< Number of wires
    int32_t nbEdges;       ///< Number of edges
    int32_t nbVertices;    ///< Number of vertices
    int32_t nbFreeEdges;   ///< Number of free (unattached) edges
    int32_t nbFreeWires;   ///< Number of free (unattached) wires
    int32_t nbFreeFaces;   ///< Number of free (unattached) faces
} OCCTShapeContents;

/// Analyze shape contents and return counts of topological entities.
/// @param shape The shape to analyze
/// @return Structure with entity counts (all zeros on failure)
OCCTShapeContents OCCTShapeGetContents(OCCTShapeRef shape);


// MARK: - Canonical Recognition (v0.30.0)

/// Structure describing a recognized canonical geometric form.
typedef struct {
    int32_t type;       ///< 0=unknown, 1=plane, 2=cylinder, 3=cone, 4=sphere, 5=line, 6=circle, 7=ellipse
    double origin[3];   ///< Origin point (x, y, z)
    double direction[3];///< Direction or normal (x, y, z)
    double radius;      ///< Primary radius (for cylinder/cone/sphere/circle)
    double radius2;     ///< Secondary radius (for cone/ellipse)
    double gap;         ///< Approximation gap
} OCCTCanonicalForm;

/// Attempt to recognize a shape as a canonical geometric form.
/// @param shape The shape to recognize (face, edge, etc.)
/// @param tolerance Recognition tolerance
/// @return Recognized form (type=0 if unrecognized)
OCCTCanonicalForm OCCTShapeRecognizeCanonical(OCCTShapeRef shape, double tolerance);


// MARK: - Edge Analysis (v0.30.0)

/// Check if an edge has a 3D curve representation.
/// @param edge The edge shape
/// @return true if the edge has a 3D curve
bool OCCTEdgeHasCurve3D(OCCTShapeRef edge);

/// Check if an edge is closed (start == end) in 3D.
/// @param edge The edge shape
/// @return true if the edge is closed
bool OCCTEdgeIsClosed3D(OCCTShapeRef edge);

/// Check if an edge is a seam edge on a face.
/// @param edge The edge shape
/// @param face The face shape
/// @return true if the edge is a seam edge on the face
bool OCCTEdgeIsSeam(OCCTShapeRef edge, OCCTShapeRef face);


// MARK: - Find Surface (v0.30.0)

/// Find a surface that approximates a shape (wire, set of edges, etc.).
/// @param shape The shape to find a surface for
/// @param tolerance Approximation tolerance
/// @return Surface reference, or NULL if not found
OCCTSurfaceRef OCCTShapeFindSurface(OCCTShapeRef shape, double tolerance);


// MARK: - Contiguous Edges (v0.30.0)

/// Find contiguous edge pairs in a shape.
/// @param shape The shape to analyze
/// @param tolerance Contiguity tolerance
/// @return Number of contiguous edge pairs found, or 0 on failure
int32_t OCCTShapeFindContiguousEdges(OCCTShapeRef shape, double tolerance);


// MARK: - Shape Fix Wireframe (v0.30.0)

/// Fix wireframe issues (small edges, wire gaps) in a shape.
/// @param shape The shape to fix
/// @param tolerance Precision for fixing
/// @return Fixed shape, or NULL on failure
OCCTShapeRef OCCTShapeFixWireframe(OCCTShapeRef shape, double tolerance);


// MARK: - Remove Internal Wires (v0.30.0)

/// Remove internal wires (holes) below a minimum area from a shape.
/// @param shape The shape to process
/// @param minArea Minimum area threshold; wires enclosing less area are removed
/// @return Shape with internal wires removed, or NULL on failure
OCCTShapeRef OCCTShapeRemoveInternalWires(OCCTShapeRef shape, double minArea);


// MARK: - Document Length Unit (v0.30.0)

/// Get the length unit information from an XDE document.
/// @param doc The document to query
/// @param unitScale Output: the scale factor relative to mm (e.g. 1.0 for mm, 10.0 for cm)
/// @param unitName Output: buffer for unit name string
/// @param maxNameLen Maximum length of the unitName buffer
/// @return true if length unit information was found
bool OCCTDocumentGetLengthUnit(OCCTDocumentRef doc, double* unitScale, char* unitName, int32_t maxNameLen);


// MARK: - Quasi-Uniform Curve Sampling (v0.31.0)

/// Sample curve parameters using quasi-uniform abscissa distribution.
/// @param curve The curve to sample
/// @param nbPoints Desired number of sample points
/// @param outParams Output array for parameter values (must hold nbPoints doubles)
/// @return Actual number of parameters written, or 0 on failure
int32_t OCCTCurve3DQuasiUniformAbscissa(OCCTCurve3DRef curve, int32_t nbPoints, double* outParams);


// MARK: - Quasi-Uniform Deflection Sampling (v0.31.0)

/// Sample curve points using quasi-uniform deflection distribution.
/// @param curve The curve to sample
/// @param deflection Maximum deflection tolerance
/// @param outXYZ Output array for point coordinates (x,y,z triples; must hold maxPoints*3 doubles)
/// @param maxPoints Maximum number of points to return
/// @return Actual number of points written, or 0 on failure
int32_t OCCTCurve3DQuasiUniformDeflection(OCCTCurve3DRef curve, double deflection, double* outXYZ, int32_t maxPoints);


// MARK: - Bezier Surface Fill (v0.31.0)

/// Create a Bezier surface by filling 4 Bezier boundary curves.
/// @param c1, c2, c3, c4 The four boundary curves (must be Bezier curves)
/// @param fillStyle Filling style: 0=stretch, 1=coons, 2=curved
/// @return Surface reference, or NULL on failure
OCCTSurfaceRef OCCTSurfaceBezierFill4(OCCTCurve3DRef c1, OCCTCurve3DRef c2,
                                        OCCTCurve3DRef c3, OCCTCurve3DRef c4,
                                        int32_t fillStyle);

/// Create a Bezier surface by filling 2 Bezier boundary curves.
/// @param c1, c2 The two boundary curves (must be Bezier curves)
/// @param fillStyle Filling style: 0=stretch, 1=coons, 2=curved
/// @return Surface reference, or NULL on failure
OCCTSurfaceRef OCCTSurfaceBezierFill2(OCCTCurve3DRef c1, OCCTCurve3DRef c2,
                                        int32_t fillStyle);


// MARK: - Quilt Faces (v0.31.0)

/// Quilt multiple shapes (faces/shells) together into a single shell.
/// @param shapes Array of shape references to quilt
/// @param count Number of shapes in the array
/// @return Resulting shell shape, or NULL on failure
OCCTShapeRef OCCTShapeQuilt(OCCTShapeRef* shapes, int32_t count);


// MARK: - Fix Small Faces (v0.31.0)

/// Fix small faces in a shape by removing or merging them.
/// @param shape The shape to fix
/// @param tolerance Precision tolerance for identifying small faces
/// @return Fixed shape, or NULL on failure
OCCTShapeRef OCCTShapeFixSmallFaces(OCCTShapeRef shape, double tolerance);


// MARK: - Remove Locations (v0.31.0)

/// Remove all locations (transformations) from a shape, baking them into geometry.
/// @param shape The shape to process
/// @return Shape with locations removed, or NULL on failure
OCCTShapeRef OCCTShapeRemoveLocations(OCCTShapeRef shape);


// MARK: - Revolution from Curve (v0.31.0)

/// Create a solid of revolution from a meridian curve.
/// @param meridian The curve to revolve (meridian profile)
/// @param axOX, axOY, axOZ Origin of the revolution axis
/// @param axDX, axDY, axDZ Direction of the revolution axis
/// @param angle Revolution angle in radians (use 2*pi for full revolution)
/// @return Revolved shape, or NULL on failure
OCCTShapeRef OCCTShapeCreateRevolutionFromCurve(OCCTCurve3DRef meridian,
                                                 double axOX, double axOY, double axOZ,
                                                 double axDX, double axDY, double axDZ,
                                                 double angle);


// MARK: - Document Layers (v0.31.0)

/// Get the number of layers in a document.
/// @param doc The document to query
/// @return Number of layers, or 0 on failure
int32_t OCCTDocumentGetLayerCount(OCCTDocumentRef doc);

/// Get the name of a layer by index.
/// @param doc The document to query
/// @param index Zero-based layer index
/// @param outName Output buffer for the layer name
/// @param maxLen Maximum length of the output buffer
/// @return true if the layer name was retrieved successfully
bool OCCTDocumentGetLayerName(OCCTDocumentRef doc, int32_t index, char* outName, int32_t maxLen);


// MARK: - Document Materials (v0.31.0)

/// Material info structure returned by OCCTDocumentGetMaterialInfo.
typedef struct {
    char name[128];
    char description[256];
    double density;
} OCCTMaterialInfo;

/// Get the number of materials in a document.
/// @param doc The document to query
/// @return Number of materials, or 0 on failure
int32_t OCCTDocumentGetMaterialCount(OCCTDocumentRef doc);

/// Get material information by index.
/// @param doc The document to query
/// @param index Zero-based material index
/// @param outInfo Output material info structure
/// @return true if the material info was retrieved successfully
bool OCCTDocumentGetMaterialInfo(OCCTDocumentRef doc, int32_t index, OCCTMaterialInfo* outInfo);


// MARK: - Linear Rib Feature (v0.31.0)

/// Add a linear rib feature to a shape.
/// @param shape The base shape to add the rib to
/// @param profile The wire profile of the rib
/// @param dirX, dirY, dirZ Direction of the rib extrusion
/// @param dir1X, dir1Y, dir1Z Secondary direction (draft direction)
/// @param fuse true to fuse (add material), false to cut (remove material)
/// @return Shape with rib added, or NULL on failure
OCCTShapeRef OCCTShapeAddLinearRib(OCCTShapeRef shape, OCCTWireRef profile,
                                    double dirX, double dirY, double dirZ,
                                    double dir1X, double dir1Y, double dir1Z,
                                    bool fuse);


#ifdef __cplusplus
}
#endif

#endif /* OCCTBridge_h */
