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

// MARK: - Bounds

void OCCTShapeGetBounds(OCCTShapeRef shape, double* minX, double* minY, double* minZ, double* maxX, double* maxY, double* maxZ);

// MARK: - Slicing

OCCTShapeRef OCCTShapeSliceAtZ(OCCTShapeRef shape, double z);
int32_t OCCTShapeGetEdgeCount(OCCTShapeRef shape);
int32_t OCCTShapeGetEdgePoints(OCCTShapeRef shape, int32_t edgeIndex, double* outPoints, int32_t maxPoints);
int32_t OCCTShapeGetContourPoints(OCCTShapeRef shape, double* outPoints, int32_t maxPoints);

#ifdef __cplusplus
}
#endif

#endif /* OCCTBridge_h */
