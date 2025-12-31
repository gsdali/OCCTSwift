import Testing
@testable import OCCTSwift

/// Basic tests for Shape creation and operations.
///
/// Note: These tests will pass with stub implementations but produce
/// empty/invalid shapes. Once OCCT is built, they will produce real geometry.
@Suite("Shape Tests")
struct ShapeTests {

    @Test("Create box primitive")
    func createBox() {
        let box = Shape.box(width: 10, height: 5, depth: 3)
        // With stubs, isValid returns true (placeholder)
        // With real OCCT, this creates actual geometry
        #expect(box.isValid)
    }

    @Test("Create cylinder primitive")
    func createCylinder() {
        let cylinder = Shape.cylinder(radius: 5, height: 10)
        #expect(cylinder.isValid)
    }

    @Test("Create sphere primitive")
    func createSphere() {
        let sphere = Shape.sphere(radius: 5)
        #expect(sphere.isValid)
    }

    @Test("Boolean union")
    func booleanUnion() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        let sphere = Shape.sphere(radius: 3)

        let union = box + sphere
        #expect(union.isValid)
    }

    @Test("Boolean subtraction")
    func booleanSubtraction() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        let cylinder = Shape.cylinder(radius: 2, height: 15)

        let result = box - cylinder
        #expect(result.isValid)
    }

    @Test("Translation")
    func translation() {
        let box = Shape.box(width: 10, height: 5, depth: 3)
        let moved = box.translated(by: SIMD3(10, 20, 30))
        #expect(moved.isValid)
    }

    @Test("Rotation")
    func rotation() {
        let box = Shape.box(width: 10, height: 5, depth: 3)
        let rotated = box.rotated(axis: SIMD3(0, 0, 1), angle: .pi / 4)
        #expect(rotated.isValid)
    }

    @Test("Fillet")
    func fillet() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        let filleted = box.filleted(radius: 1)
        #expect(filleted.isValid)
    }
}

@Suite("Wire Tests")
struct WireTests {

    @Test("Create rectangle wire")
    func createRectangle() {
        let rect = Wire.rectangle(width: 10, height: 5)
        // Wire doesn't have isValid, but it should create successfully
        _ = rect  // Ensure it compiles
    }

    @Test("Create polygon wire")
    func createPolygon() {
        let polygon = Wire.polygon([
            SIMD2(0, 0),
            SIMD2(10, 0),
            SIMD2(10, 5),
            SIMD2(0, 5)
        ], closed: true)
        _ = polygon
    }

    @Test("Create arc wire")
    func createArc() {
        let arc = Wire.arc(
            center: .zero,
            radius: 50,
            startAngle: 0,
            endAngle: .pi / 2
        )
        _ = arc
    }

    @Test("Create line wire")
    func createLine() {
        let line = Wire.line(
            from: SIMD3(0, 0, 0),
            to: SIMD3(100, 0, 0)
        )
        _ = line
    }

    @Test("Create cubic B-spline")
    func createCubicBSpline() {
        let poles = [
            SIMD3<Double>(0, 0, 0),
            SIMD3<Double>(10, 5, 0),
            SIMD3<Double>(20, 0, 0),
            SIMD3<Double>(30, 5, 0),
            SIMD3<Double>(40, 0, 0)
        ]
        let curve = Wire.cubicBSpline(poles: poles)
        #expect(curve != nil)
    }

    @Test("Create NURBS with uniform knots")
    func createNURBSUniform() {
        let poles = [
            SIMD3<Double>(0, 0, 0),
            SIMD3<Double>(10, 10, 0),
            SIMD3<Double>(20, 0, 0),
            SIMD3<Double>(30, 10, 0)
        ]
        let curve = Wire.nurbsUniform(poles: poles, degree: 2)
        #expect(curve != nil)
    }

    @Test("Create weighted NURBS (rational curve)")
    func createWeightedNURBS() {
        // Quadratic rational B-spline can represent exact conic sections
        let poles = [
            SIMD3<Double>(0, 0, 0),
            SIMD3<Double>(10, 10, 0),
            SIMD3<Double>(20, 0, 0)
        ]
        let weights = [1.0, 0.707, 1.0]  // sqrt(2)/2 for 90-degree arc
        let curve = Wire.nurbsUniform(poles: poles, weights: weights, degree: 2)
        #expect(curve != nil)
    }

    @Test("Create full NURBS with explicit knots")
    func createFullNURBS() {
        // Cubic curve with 5 control points
        let poles = [
            SIMD3<Double>(0, 0, 0),
            SIMD3<Double>(5, 10, 0),
            SIMD3<Double>(15, 10, 0),
            SIMD3<Double>(20, 5, 0),
            SIMD3<Double>(25, 0, 0)
        ]
        // Clamped uniform knots for degree 3 with 5 poles
        // Total knots = poles + degree + 1 = 9
        // Distinct knots with multiplicities: [0,0,0,0, 0.5, 1,1,1,1]
        let knots: [Double] = [0.0, 0.5, 1.0]
        let mults: [Int32] = [4, 1, 4]

        let curve = Wire.nurbs(
            poles: poles,
            knots: knots,
            multiplicities: mults,
            degree: 3
        )
        #expect(curve != nil)
    }

    @Test("NURBS validation - too few poles")
    func nurbsTooFewPoles() {
        let poles = [SIMD3<Double>(0, 0, 0), SIMD3<Double>(10, 0, 0)]
        // Cubic needs at least 4 poles
        let curve = Wire.cubicBSpline(poles: poles)
        #expect(curve == nil)
    }

    @Test("Sweep profile along NURBS path")
    func sweepAlongNURBS() {
        let profile = Wire.circle(radius: 1)
        let pathPoles = [
            SIMD3<Double>(0, 0, 0),
            SIMD3<Double>(20, 0, 0),
            SIMD3<Double>(40, 10, 0),
            SIMD3<Double>(60, 20, 0),
            SIMD3<Double>(80, 20, 0)
        ]
        guard let path = Wire.cubicBSpline(poles: pathPoles) else {
            Issue.record("Failed to create NURBS path")
            return
        }
        let swept = Shape.sweep(profile: profile, along: path)
        #expect(swept.isValid)
    }
}

@Suite("Mesh Tests")
struct MeshTests {

    @Test("Mesh from shape")
    func meshFromShape() {
        let box = Shape.box(width: 10, height: 5, depth: 3)
        let mesh = box.mesh(linearDeflection: 0.1)

        // With stubs, mesh will be empty
        // With real OCCT, will have vertices and triangles
        _ = mesh.vertexCount
        _ = mesh.triangleCount
    }

    @Test("Mesh data access")
    func meshDataAccess() {
        let sphere = Shape.sphere(radius: 5)
        let mesh = sphere.mesh(linearDeflection: 0.5)

        let vertices = mesh.vertices
        let normals = mesh.normals
        let indices = mesh.indices

        // Lengths should be consistent
        #expect(vertices.count == normals.count)
        #expect(indices.count == mesh.triangleCount * 3)
    }

    @Test("Enhanced mesh parameters")
    func enhancedMeshParameters() {
        let box = Shape.box(width: 10, height: 10, depth: 10)

        var params = MeshParameters.default
        params.deflection = 0.05
        params.inParallel = true

        let mesh = box.mesh(parameters: params)
        #expect(mesh.vertexCount > 0)
        #expect(mesh.triangleCount > 0)
    }

    @Test("Triangles with face info")
    func trianglesWithFaceInfo() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        let mesh = box.mesh(linearDeflection: 0.1)

        let triangles = mesh.trianglesWithFaces()
        #expect(triangles.count == mesh.triangleCount)

        // Each triangle should have valid data
        for tri in triangles {
            #expect(tri.v1 < UInt32(mesh.vertexCount))
            #expect(tri.v2 < UInt32(mesh.vertexCount))
            #expect(tri.v3 < UInt32(mesh.vertexCount))
            // Face index should be valid (>= 0 for box with 6 faces)
            #expect(tri.faceIndex >= 0)
        }
    }

    @Test("Mesh to shape conversion")
    func meshToShape() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        let mesh = box.mesh(linearDeflection: 0.5)

        // Convert mesh back to shape
        let shape = mesh.toShape()
        #expect(shape != nil)
    }

    @Test("Mesh boolean union")
    func meshBooleanUnion() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)
        let box2 = Shape.box(width: 10, height: 10, depth: 10)
            .translated(by: SIMD3(5, 0, 0))

        let mesh1 = box1.mesh(linearDeflection: 0.5)
        let mesh2 = box2.mesh(linearDeflection: 0.5)

        let unionMesh = mesh1.union(with: mesh2, deflection: 0.5)
        #expect(unionMesh != nil)
        if let union = unionMesh {
            #expect(union.triangleCount > 0)
        }
    }

    @Test("Mesh boolean subtraction")
    func meshBooleanSubtraction() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        let cylinder = Shape.cylinder(radius: 3, height: 15)

        let boxMesh = box.mesh(linearDeflection: 0.5)
        let cylMesh = cylinder.mesh(linearDeflection: 0.5)

        let diffMesh = boxMesh.subtracting(cylMesh, deflection: 0.5)
        #expect(diffMesh != nil)
    }

    @Test("Mesh boolean intersection")
    func meshBooleanIntersection() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        let sphere = Shape.sphere(radius: 7)

        let boxMesh = box.mesh(linearDeflection: 0.5)
        let sphereMesh = sphere.mesh(linearDeflection: 0.5)

        let intersectMesh = boxMesh.intersection(with: sphereMesh, deflection: 0.5)
        #expect(intersectMesh != nil)
    }
}

@Suite("Edge Discretization Tests")
struct EdgeDiscretizationTests {

    @Test("Edge polyline from box")
    func edgePolylineFromBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)

        // Box has edges (OCCT may count shared edges per face)
        #expect(box.edgeCount > 0)

        // Get polyline for first edge
        let polyline = box.edgePolyline(at: 0, deflection: 0.1)
        #expect(polyline != nil)
        if let pts = polyline {
            #expect(pts.count >= 2)  // At least start and end
        }
    }

    @Test("Edge polyline from curved shape")
    func edgePolylineFromCylinder() {
        let cylinder = Shape.cylinder(radius: 10, height: 20)

        // Cylinder has curved edges
        let polyline = cylinder.edgePolyline(at: 0, deflection: 0.1)
        #expect(polyline != nil)
        if let pts = polyline {
            // Curved edges should have many points
            #expect(pts.count > 2)
        }
    }

    @Test("All edge polylines")
    func allEdgePolylines() {
        let box = Shape.box(width: 10, height: 10, depth: 10)

        let polylines = box.allEdgePolylines(deflection: 0.1)
        #expect(polylines.count == box.edgeCount)
    }

    @Test("Edge polyline invalid index")
    func edgePolylineInvalidIndex() {
        let box = Shape.box(width: 10, height: 10, depth: 10)

        // Box has 12 edges, index 100 should fail
        let polyline = box.edgePolyline(at: 100, deflection: 0.1)
        #expect(polyline == nil)
    }
}

@Suite("Sweep Tests")
struct SweepTests {

    @Test("Extrude profile")
    func extrudeProfile() {
        let profile = Wire.rectangle(width: 5, height: 3)
        let solid = Shape.extrude(
            profile: profile,
            direction: SIMD3(0, 0, 1),
            length: 10
        )
        #expect(solid.isValid)
    }

    @Test("Pipe sweep")
    func pipeSweep() {
        let profile = Wire.circle(radius: 1)
        let path = Wire.arc(
            center: .zero,
            radius: 50,
            startAngle: 0,
            endAngle: .pi / 2
        )
        let pipe = Shape.sweep(profile: profile, along: path)
        #expect(pipe.isValid)
    }

    @Test("Revolution")
    func revolution() {
        // Create a simple profile to revolve
        let profile = Wire.polygon([
            SIMD2(5, 0),
            SIMD2(7, 0),
            SIMD2(7, 10),
            SIMD2(5, 10)
        ], closed: true)

        let solid = Shape.revolve(
            profile: profile,
            axisOrigin: .zero,
            axisDirection: SIMD3(0, 1, 0),
            angle: .pi * 2
        )
        #expect(solid.isValid)
    }
}
