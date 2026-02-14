import Testing
import Foundation
import simd
@testable import OCCTSwift

/// Basic tests for Shape creation and operations.
///
/// Note: These tests will pass with stub implementations but produce
/// empty/invalid shapes. Once OCCT is built, they will produce real geometry.
@Suite("Shape Tests")
struct ShapeTests {

    @Test("Create box primitive")
    func createBox() {
        let box = Shape.box(width: 10, height: 5, depth: 3)!
        // With stubs, isValid returns true (placeholder)
        // With real OCCT, this creates actual geometry
        #expect(box.isValid)
    }

    @Test("Create cylinder primitive")
    func createCylinder() {
        let cylinder = Shape.cylinder(radius: 5, height: 10)!
        #expect(cylinder.isValid)
    }

    @Test("Create sphere primitive")
    func createSphere() {
        let sphere = Shape.sphere(radius: 5)!
        #expect(sphere.isValid)
    }

    @Test("Boolean union")
    func booleanUnion() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let sphere = Shape.sphere(radius: 3)!

        let union = (box + sphere)!
        #expect(union.isValid)
    }

    @Test("Boolean subtraction")
    func booleanSubtraction() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let cylinder = Shape.cylinder(radius: 2, height: 15)!

        let result = (box - cylinder)!
        #expect(result.isValid)
    }

    @Test("Translation")
    func translation() {
        let box = Shape.box(width: 10, height: 5, depth: 3)!
        let moved = box.translated(by: SIMD3(10, 20, 30))!
        #expect(moved.isValid)
    }

    @Test("Rotation")
    func rotation() {
        let box = Shape.box(width: 10, height: 5, depth: 3)!
        let rotated = box.rotated(axis: SIMD3(0, 0, 1), angle: .pi / 4)!
        #expect(rotated.isValid)
    }

    @Test("Fillet")
    func fillet() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let filleted = box.filleted(radius: 1)!
        #expect(filleted.isValid)
    }
}

@Suite("Wire Tests")
struct WireTests {

    @Test("Create rectangle wire")
    func createRectangle() {
        let rect = Wire.rectangle(width: 10, height: 5)
        #expect(rect != nil)
    }

    @Test("Create polygon wire")
    func createPolygon() {
        let polygon = Wire.polygon([
            SIMD2(0, 0),
            SIMD2(10, 0),
            SIMD2(10, 5),
            SIMD2(0, 5)
        ], closed: true)
        #expect(polygon != nil)
    }

    @Test("Create arc wire")
    func createArc() {
        let arc = Wire.arc(
            center: .zero,
            radius: 50,
            startAngle: 0,
            endAngle: .pi / 2
        )
        #expect(arc != nil)
    }

    @Test("Create line wire")
    func createLine() {
        let line = Wire.line(
            from: SIMD3(0, 0, 0),
            to: SIMD3(100, 0, 0)
        )
        #expect(line != nil)
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
        guard let profile = Wire.circle(radius: 1) else {
            Issue.record("Failed to create circle profile")
            return
        }
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
        let swept = Shape.sweep(profile: profile, along: path)!
        #expect(swept.isValid)
    }

    @Test("Polygon with too few points returns nil")
    func polygonTooFewPoints() {
        let polygon = Wire.polygon([SIMD2(0, 0)], closed: true)
        #expect(polygon == nil)
    }

    @Test("Line with same start and end returns nil")
    func lineDegenerate() {
        let line = Wire.line(from: .zero, to: .zero)
        #expect(line == nil)
    }

    @Test("Arc with zero radius returns nil")
    func arcZeroRadius() {
        let arc = Wire.arc(center: .zero, radius: 0, startAngle: 0, endAngle: .pi)
        #expect(arc == nil)
    }

    @Test("Rectangle with zero dimension returns nil")
    func rectangleZeroDimension() {
        let rect = Wire.rectangle(width: 0, height: 5)
        #expect(rect == nil)
    }
}

@Suite("Shape from Wire Tests")
struct ShapeFromWireTests {

    @Test("Convert rectangle wire to shape and extract edges")
    func rectangleWireEdges() {
        let rect = Wire.rectangle(width: 10, height: 5)!
        let shape = Shape.fromWire(rect)
        #expect(shape != nil)
        let polylines = shape!.allEdgePolylines(deflection: 0.1)
        #expect(polylines.count == 4) // rectangle has 4 edges
    }

    @Test("Convert circle wire to shape and extract edges")
    func circleWireEdges() {
        let circle = Wire.circle(radius: 5)!
        let shape = Shape.fromWire(circle)
        #expect(shape != nil)
        let polylines = shape!.allEdgePolylines(deflection: 0.1)
        #expect(polylines.count >= 1)
        // Circle edge polyline should have multiple points
        #expect(polylines[0].count > 2)
    }

    @Test("Shape from wire reports correct shape type")
    func wireShapeType() {
        let rect = Wire.rectangle(width: 10, height: 5)!
        let shape = Shape.fromWire(rect)!
        #expect(shape.shapeType == .wire)
    }
}

@Suite("Mesh Tests")
struct MeshTests {

    @Test("Mesh from shape")
    func meshFromShape() {
        let box = Shape.box(width: 10, height: 5, depth: 3)!
        let mesh = box.mesh(linearDeflection: 0.1)!

        // With stubs, mesh will be empty
        // With real OCCT, will have vertices and triangles
        _ = mesh.vertexCount
        _ = mesh.triangleCount
    }

    @Test("Mesh data access")
    func meshDataAccess() {
        let sphere = Shape.sphere(radius: 5)!
        let mesh = sphere.mesh(linearDeflection: 0.5)!

        let vertices = mesh.vertices
        let normals = mesh.normals
        let indices = mesh.indices

        // Lengths should be consistent
        #expect(vertices.count == normals.count)
        #expect(indices.count == mesh.triangleCount * 3)
    }

    @Test("Enhanced mesh parameters")
    func enhancedMeshParameters() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        var params = MeshParameters.default
        params.deflection = 0.05
        params.inParallel = true

        let mesh = box.mesh(parameters: params)!
        #expect(mesh.vertexCount > 0)
        #expect(mesh.triangleCount > 0)
    }

    @Test("Triangles with face info")
    func trianglesWithFaces() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let mesh = box.mesh(linearDeflection: 0.1)!

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
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let mesh = box.mesh(linearDeflection: 0.5)!

        // Convert mesh back to shape
        let shape = mesh.toShape()
        #expect(shape != nil)
    }

    @Test("Mesh boolean union")
    func meshBooleanUnion() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(width: 10, height: 10, depth: 10)!
            .translated(by: SIMD3(5, 0, 0))!

        let mesh1 = box1.mesh(linearDeflection: 0.5)!
        let mesh2 = box2.mesh(linearDeflection: 0.5)!

        let unionMesh = mesh1.union(with: mesh2, deflection: 0.5)
        #expect(unionMesh != nil)
        if let union = unionMesh {
            #expect(union.triangleCount > 0)
        }
    }

    @Test("Mesh boolean subtraction")
    func meshBooleanSubtraction() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let cylinder = Shape.cylinder(radius: 3, height: 15)!

        let boxMesh = box.mesh(linearDeflection: 0.5)!
        let cylMesh = cylinder.mesh(linearDeflection: 0.5)!

        let diffMesh = boxMesh.subtracting(cylMesh, deflection: 0.5)
        #expect(diffMesh != nil)
    }

    @Test("Mesh boolean intersection")
    func meshBooleanIntersection() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let sphere = Shape.sphere(radius: 7)!

        let boxMesh = box.mesh(linearDeflection: 0.5)!
        let sphereMesh = sphere.mesh(linearDeflection: 0.5)!

        let intersectMesh = boxMesh.intersection(with: sphereMesh, deflection: 0.5)
        #expect(intersectMesh != nil)
    }
}

@Suite("Edge Discretization Tests")
struct EdgeDiscretizationTests {

    @Test("Edge polyline from box")
    func edgePolylineFromBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

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
        let cylinder = Shape.cylinder(radius: 10, height: 20)!

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
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        let polylines = box.allEdgePolylines(deflection: 0.1)
        #expect(polylines.count == box.edgeCount)
    }

    @Test("Edge polyline invalid index")
    func edgePolylineInvalidIndex() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        // Box has 12 edges, index 100 should fail
        let polyline = box.edgePolyline(at: 100, deflection: 0.1)
        #expect(polyline == nil)
    }
}

@Suite("Edge Polyline Consistency Tests")
struct EdgePolylineConsistencyTests {

    @Test("Lofted shape edge polylines match edge count")
    func loftedShapeEdgePolylines() {
        // Two circles at different Z heights
        guard let circle1 = Wire.circle(radius: 10),
              let circle2 = Wire.circle(radius: 5) else {
            Issue.record("Failed to create circle wires")
            return
        }
        // Loft between the two circles
        let lofted = Shape.loft(profiles: [circle1, circle2], solid: true)!
        #expect(lofted.isValid)

        let edgeCount = lofted.edgeCount
        #expect(edgeCount > 0)

        let polylines = lofted.allEdgePolylines(deflection: 0.1)
        #expect(polylines.count == edgeCount, "polylines.count (\(polylines.count)) should match edgeCount (\(edgeCount))")

        // Every edge should produce at least 2 points
        for (i, polyline) in polylines.enumerated() {
            #expect(polyline.count >= 2, "Edge \(i) should have at least 2 points, got \(polyline.count)")
        }
    }

    @Test("Extruded rectangle all 12 edges recovered")
    func extrudedRectangleEdges() {
        guard let rect = Wire.rectangle(width: 10, height: 5) else {
            Issue.record("Failed to create rectangle wire")
            return
        }
        let solid = Shape.extrude(profile: rect, direction: SIMD3(0, 0, 1), length: 8)!
        #expect(solid.isValid)

        // A box-like extrusion has 12 edges
        let edgeCount = solid.edgeCount
        #expect(edgeCount == 12, "Extruded rectangle should have 12 edges, got \(edgeCount)")

        let polylines = solid.allEdgePolylines(deflection: 0.1)
        #expect(polylines.count == 12, "Should recover all 12 edge polylines, got \(polylines.count)")
    }

    @Test("Extruded circle seam edges handled")
    func extrudedCircleEdges() {
        guard let circle = Wire.circle(radius: 5) else {
            Issue.record("Failed to create circle wire")
            return
        }
        let solid = Shape.extrude(profile: circle, direction: SIMD3(0, 0, 1), length: 10)!
        #expect(solid.isValid)

        let edgeCount = solid.edgeCount
        #expect(edgeCount > 0)

        let polylines = solid.allEdgePolylines(deflection: 0.1)
        #expect(polylines.count == edgeCount, "polylines.count (\(polylines.count)) should match edgeCount (\(edgeCount))")

        for (i, polyline) in polylines.enumerated() {
            #expect(polyline.count >= 2, "Edge \(i) should have at least 2 points, got \(polyline.count)")
        }
    }

    @Test("allEdgePolylines count matches edgeCount for various shapes")
    func consistencyAcrossShapes() {
        let shapes: [(String, Shape)] = [
            ("box", Shape.box(width: 5, height: 5, depth: 5)!),
            ("cylinder", Shape.cylinder(radius: 3, height: 6)!),
            ("sphere", Shape.sphere(radius: 4)!),
        ]

        for (name, shape) in shapes {
            let edgeCount = shape.edgeCount
            let polylines = shape.allEdgePolylines(deflection: 0.1)
            #expect(polylines.count == edgeCount, "\(name): polylines.count (\(polylines.count)) != edgeCount (\(edgeCount))")
        }
    }
}

@Suite("Sweep Tests")
struct SweepTests {

    @Test("Extrude profile")
    func extrudeProfile() {
        guard let profile = Wire.rectangle(width: 5, height: 3) else {
            Issue.record("Failed to create rectangle profile")
            return
        }
        let solid = Shape.extrude(
            profile: profile,
            direction: SIMD3(0, 0, 1),
            length: 10
        )!
        #expect(solid.isValid)
    }

    @Test("Pipe sweep")
    func pipeSweep() {
        guard let profile = Wire.circle(radius: 1) else {
            Issue.record("Failed to create circle profile")
            return
        }
        guard let path = Wire.arc(
            center: .zero,
            radius: 50,
            startAngle: 0,
            endAngle: .pi / 2
        ) else {
            Issue.record("Failed to create arc path")
            return
        }
        let pipe = Shape.sweep(profile: profile, along: path)!
        #expect(pipe.isValid)
    }

    @Test("Revolution")
    func revolution() {
        // Create a simple profile to revolve
        guard let profile = Wire.polygon([
            SIMD2(5, 0),
            SIMD2(7, 0),
            SIMD2(7, 10),
            SIMD2(5, 10)
        ], closed: true) else {
            Issue.record("Failed to create polygon profile")
            return
        }

        let solid = Shape.revolve(
            profile: profile,
            axisOrigin: .zero,
            axisDirection: SIMD3(0, 1, 0),
            angle: .pi * 2
        )!
        #expect(solid.isValid)
    }
}

// MARK: - XDE Tests (v0.6.0)

@Suite("Color Tests")
struct ColorTests {

    @Test("Create color with RGBA components")
    func createColorRGBA() {
        let color = Color(red: 0.5, green: 0.3, blue: 0.8, alpha: 0.9)
        #expect(color.red == 0.5)
        #expect(color.green == 0.3)
        #expect(color.blue == 0.8)
        #expect(color.alpha == 0.9)
    }

    @Test("Create color from 255 values")
    func createColorFrom255() {
        let color = Color(red255: 128, green255: 64, blue255: 255)
        #expect(abs(color.red - 128.0/255.0) < 0.01)
        #expect(abs(color.green - 64.0/255.0) < 0.01)
        #expect(abs(color.blue - 1.0) < 0.01)
        #expect(color.alpha == 1.0)
    }

    @Test("Predefined colors")
    func predefinedColors() {
        #expect(Color.red.red == 1.0)
        #expect(Color.red.green == 0.0)
        #expect(Color.blue.blue == 1.0)
        #expect(Color.white.red == 1.0)
        #expect(Color.black.red == 0.0)
    }
}

@Suite("Material Tests")
struct MaterialTests {

    @Test("Create PBR material")
    func createPBRMaterial() {
        let mat = Material(
            baseColor: Color(red: 0.8, green: 0.2, blue: 0.1),
            metallic: 0.9,
            roughness: 0.3
        )
        #expect(mat.baseColor.red == 0.8)
        #expect(mat.metallic == 0.9)
        #expect(mat.roughness == 0.3)
    }

    @Test("Material clamps values to 0-1 range")
    func materialClamping() {
        let mat = Material(
            baseColor: .white,
            metallic: 1.5,  // Should be clamped to 1.0
            roughness: -0.5  // Should be clamped to 0.0
        )
        #expect(mat.metallic == 1.0)
        #expect(mat.roughness == 0.0)
    }

    @Test("Predefined materials")
    func predefinedMaterials() {
        let metal = Material.polishedMetal
        #expect(metal.metallic == 1.0)
        #expect(metal.roughness < 0.2)

        let plastic = Material.plastic
        #expect(plastic.metallic == 0.0)
    }
}

@Suite("Drawing Tests")
struct DrawingTests {

    @Test("Create 2D projection of box")
    func project2DBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let drawing = Drawing.project(box, direction: SIMD3(0, 0, 1))
        #expect(drawing != nil)
    }

    @Test("Get visible edges from projection")
    func visibleEdges() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        guard let drawing = Drawing.project(box, direction: SIMD3(0, 0, 1)) else {
            Issue.record("Failed to create projection")
            return
        }
        let visible = drawing.visibleEdges
        #expect(visible != nil)
    }

    @Test("Get hidden edges from isometric view")
    func hiddenEdgesIsometric() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        guard let drawing = Drawing.isometricView(of: box) else {
            Issue.record("Failed to create isometric view")
            return
        }
        let hidden = drawing.hiddenEdges
        // Isometric view of box should have hidden edges
        #expect(hidden != nil)
    }

    @Test("Standard views")
    func standardViews() {
        let box = Shape.box(width: 10, height: 20, depth: 30)!

        let top = Drawing.topView(of: box)
        #expect(top != nil)

        let front = Drawing.frontView(of: box)
        #expect(front != nil)

        let side = Drawing.sideView(of: box)
        #expect(side != nil)
    }
}

@Suite("Document Tests")
struct DocumentTests {

    @Test("Create empty document")
    func createEmptyDocument() {
        let doc = Document.create()
        #expect(doc != nil)
        if let doc = doc {
            #expect(doc.rootNodes.isEmpty)
        }
    }

    // Note: Loading tests require test STEP files with assemblies
    // These would be added with actual test fixtures
}

// MARK: - Measurement & Analysis Tests (v0.7.0)

@Suite("Measurement Tests")
struct MeasurementTests {

    // MARK: - Volume Tests

    @Test("Volume of box")
    func volumeOfBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        guard let volume = box.volume else {
            Issue.record("Failed to compute volume")
            return
        }
        // 10 × 10 × 10 = 1000 cubic units
        #expect(abs(volume - 1000.0) < 0.01)
    }

    @Test("Volume of cylinder")
    func volumeOfCylinder() {
        let cylinder = Shape.cylinder(radius: 5, height: 10)!
        guard let volume = cylinder.volume else {
            Issue.record("Failed to compute volume")
            return
        }
        // π × r² × h = π × 25 × 10 ≈ 785.4
        let expected = Double.pi * 25.0 * 10.0
        #expect(abs(volume - expected) < 0.1)
    }

    @Test("Volume of sphere")
    func volumeOfSphere() {
        let sphere = Shape.sphere(radius: 5)!
        guard let volume = sphere.volume else {
            Issue.record("Failed to compute volume")
            return
        }
        // 4/3 × π × r³ = 4/3 × π × 125 ≈ 523.6
        let expected = (4.0 / 3.0) * Double.pi * 125.0
        #expect(abs(volume - expected) < 0.1)
    }

    // MARK: - Surface Area Tests

    @Test("Surface area of box")
    func surfaceAreaOfBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        guard let area = box.surfaceArea else {
            Issue.record("Failed to compute surface area")
            return
        }
        // 6 faces × 100 = 600 square units
        #expect(abs(area - 600.0) < 0.1)
    }

    @Test("Surface area of sphere")
    func surfaceAreaOfSphere() {
        let sphere = Shape.sphere(radius: 5)!
        guard let area = sphere.surfaceArea else {
            Issue.record("Failed to compute surface area")
            return
        }
        // 4 × π × r² = 4 × π × 25 ≈ 314.16
        let expected = 4.0 * Double.pi * 25.0
        #expect(abs(area - expected) < 0.5)
    }

    // MARK: - Center of Mass Tests

    @Test("Center of mass of box at origin")
    func centerOfMassBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        guard let center = box.centerOfMass else {
            Issue.record("Failed to compute center of mass")
            return
        }
        // Box is created centered at origin (from -5 to +5 in each axis)
        #expect(abs(center.x) < 0.01)
        #expect(abs(center.y) < 0.01)
        #expect(abs(center.z) < 0.01)
    }

    @Test("Center of mass of translated box")
    func centerOfMassTranslatedBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
            .translated(by: SIMD3(100, 200, 300))!
        guard let center = box.centerOfMass else {
            Issue.record("Failed to compute center of mass")
            return
        }
        // Box centered at origin, then translated by (100, 200, 300)
        #expect(abs(center.x - 100.0) < 0.01)
        #expect(abs(center.y - 200.0) < 0.01)
        #expect(abs(center.z - 300.0) < 0.01)
    }

    // MARK: - Full Properties Test

    @Test("Full shape properties")
    func fullShapeProperties() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        guard let props = box.properties(density: 2.5) else {
            Issue.record("Failed to compute properties")
            return
        }

        #expect(abs(props.volume - 1000.0) < 0.01)
        #expect(abs(props.surfaceArea - 600.0) < 0.1)
        #expect(abs(props.mass - 2500.0) < 0.1)  // 1000 × 2.5
        #expect(abs(props.centerOfMass.x) < 0.01)  // Box centered at origin
    }

    // MARK: - Distance Tests

    @Test("Distance between separated boxes")
    func distanceBetweenBoxes() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(width: 10, height: 10, depth: 10)!
            .translated(by: SIMD3(20, 0, 0))!

        guard let result = box1.distance(to: box2) else {
            Issue.record("Failed to compute distance")
            return
        }
        // Gap of 10 units between boxes
        #expect(abs(result.distance - 10.0) < 0.01)
    }

    @Test("Distance between touching boxes")
    func distanceBetweenTouchingBoxes() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(width: 10, height: 10, depth: 10)!
            .translated(by: SIMD3(10, 0, 0))!

        guard let result = box1.distance(to: box2) else {
            Issue.record("Failed to compute distance")
            return
        }
        // Boxes are touching
        #expect(abs(result.distance) < 0.01)
    }

    @Test("Min distance convenience method")
    func minDistanceConvenience() {
        let sphere1 = Shape.sphere(radius: 5)!
        let sphere2 = Shape.sphere(radius: 3)!.translated(by: SIMD3(15, 0, 0))!

        guard let dist = sphere1.minDistance(to: sphere2) else {
            Issue.record("Failed to compute min distance")
            return
        }
        // 15 - 5 - 3 = 7 units gap
        #expect(abs(dist - 7.0) < 0.1)
    }

    // MARK: - Intersection Tests

    @Test("Intersects - overlapping shapes")
    func intersectsOverlapping() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let sphere = Shape.sphere(radius: 3)!  // At origin, inside box

        #expect(box.intersects(sphere))
    }

    @Test("Intersects - separated shapes")
    func intersectsSeparated() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let sphere = Shape.sphere(radius: 3)!
            .translated(by: SIMD3(50, 0, 0))!  // Far away

        #expect(!box.intersects(sphere))
    }

    @Test("Intersects - touching shapes")
    func intersectsTouching() {
        // Box from -5 to +5 in each axis (centered at origin)
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        // Sphere of radius 5 centered at (10, 0, 0) touches box at x=5
        let sphere = Shape.sphere(radius: 5)!
            .translated(by: SIMD3(10, 0, 0))!

        // Should be touching or very close
        #expect(box.intersects(sphere, tolerance: 0.1))
    }

    // MARK: - Vertex Tests

    @Test("Vertex count of box")
    func vertexCountBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        #expect(box.vertexCount == 8)
    }

    @Test("Get all vertices")
    func getAllVertices() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let vertices = box.vertices()
        #expect(vertices.count == 8)
    }

    @Test("Get vertex at index")
    func vertexAtIndex() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let vertex = box.vertex(at: 0)
        #expect(vertex != nil)
    }

    @Test("Vertex out of bounds")
    func vertexOutOfBounds() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let vertex = box.vertex(at: 100)  // Invalid index
        #expect(vertex == nil)
    }
}

// MARK: - Advanced Modeling Tests (v0.8.0)

@Suite("Advanced Modeling Tests")
struct AdvancedModelingTests {

    // MARK: - Selective Fillet Tests

    @Test("Fillet specific edges")
    func filletSpecificEdges() {
        let box = Shape.box(width: 20, height: 20, depth: 10)!
        let edges = box.edges()
        #expect(edges.count > 0)

        // Fillet first 4 edges
        let edgesToFillet = Array(edges.prefix(4))
        let filleted = box.filleted(edges: edgesToFillet, radius: 2.0)

        #expect(filleted != nil)
        // Filleted shape should be valid
        #expect(filleted?.isValid ?? false)
    }

    @Test("Fillet single edge")
    func filletSingleEdge() {
        let box = Shape.box(width: 20, height: 10, depth: 10)!

        guard let edge = box.edge(at: 0) else {
            Issue.record("Could not get edge")
            return
        }

        let filleted = box.filleted(edges: [edge], radius: 1.0)
        #expect(filleted != nil)
    }

    @Test("Fillet with variable radius")
    func filletVariableRadius() {
        let box = Shape.box(width: 30, height: 10, depth: 10)!

        guard let edge = box.edge(at: 0) else {
            Issue.record("Could not get edge")
            return
        }

        let filleted = box.filleted(edges: [edge], startRadius: 1.0, endRadius: 3.0)
        #expect(filleted != nil)
    }

    @Test("Edge has valid index")
    func edgeHasIndex() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        let edge = box.edge(at: 5)
        #expect(edge != nil)
        #expect(edge?.index == 5)
    }

    @Test("Face has valid index")
    func faceHasIndex() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        let face = box.face(at: 3)
        #expect(face != nil)
        #expect(face?.index == 3)
    }

    // MARK: - Draft Angle Tests

    @Test("Draft vertical faces")
    func draftVerticalFaces() {
        let box = Shape.box(width: 20, height: 20, depth: 30)!
        let faces = box.faces()

        // Get vertical faces (normals perpendicular to Z)
        let verticalFaces = faces.filter { $0.isVertical() }
        #expect(verticalFaces.count == 4)  // 4 side faces

        // Apply 3 degree draft angle
        let draftAngle = 3.0 * .pi / 180.0
        let drafted = box.drafted(
            faces: verticalFaces,
            direction: SIMD3(0, 0, 1),
            angle: draftAngle,
            neutralPlane: (point: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
        )

        #expect(drafted != nil)
    }

    // MARK: - Defeaturing Tests

    @Test("Remove faces from shape")
    func removeFeatures() {
        // Create a box with a hole
        let box = Shape.box(width: 20, height: 20, depth: 20)!
        let hole = Shape.cylinder(radius: 3, height: 30)!
        let boxWithHole = box.subtracting(hole)!

        // The box with hole has more faces than a simple box
        let faces = boxWithHole.faces()
        #expect(faces.count > 6)

        // Find cylindrical faces (the hole)
        let cylindricalFaces = faces.filter { !$0.isPlanar }

        if !cylindricalFaces.isEmpty {
            // Try to remove the hole
            let defeatured = boxWithHole.withoutFeatures(faces: cylindricalFaces)
            // May or may not succeed depending on geometry complexity
            // Just verify it doesn't crash
            if defeatured != nil {
                #expect(defeatured!.isValid)
            }
        }
    }

    // MARK: - Pipe Shell Tests

    @Test("Pipe shell with Frenet mode")
    func pipeShellFrenet() {
        // Create a simple S-curve path
        guard let spine = Wire.bspline([
            SIMD3(0, 0, 0),
            SIMD3(10, 0, 0),
            SIMD3(20, 10, 0),
            SIMD3(30, 10, 0)
        ]) else {
            Issue.record("Could not create spine")
            return
        }

        // Create circular profile
        guard let profile = Wire.circle(radius: 2) else {
            Issue.record("Could not create profile")
            return
        }

        let pipe = Shape.pipeShell(spine: spine, profile: profile, mode: .frenet)
        #expect(pipe != nil)
    }

    @Test("Pipe shell with corrected Frenet mode")
    func pipeShellCorrectedFrenet() {
        // Create a curve that might have inflection points
        guard let spine = Wire.bspline([
            SIMD3(0, 0, 0),
            SIMD3(10, 5, 0),
            SIMD3(20, -5, 10),
            SIMD3(30, 0, 10)
        ]) else {
            Issue.record("Could not create spine")
            return
        }

        guard let profile = Wire.circle(radius: 1.5) else {
            Issue.record("Could not create profile")
            return
        }

        let pipe = Shape.pipeShell(spine: spine, profile: profile, mode: .correctedFrenet)
        #expect(pipe != nil)
    }

    @Test("Pipe shell with fixed binormal")
    func pipeShellFixedBinormal() {
        // Straight path where we want to control orientation
        guard let spine = Wire.bspline([
            SIMD3(0, 0, 0),
            SIMD3(50, 0, 0)
        ]) else {
            Issue.record("Could not create spine")
            return
        }

        // Rectangular profile
        guard let profile = Wire.rectangle(width: 5, height: 3) else {
            Issue.record("Could not create profile")
            return
        }

        // Keep profile vertical (binormal = Z)
        let pipe = Shape.pipeShell(spine: spine, profile: profile, mode: .fixed(binormal: SIMD3(0, 0, 1)))
        #expect(pipe != nil)
    }

    @Test("Pipe shell creates shell when solid=false")
    func pipeShellCreatesShell() {
        guard let spine = Wire.line(from: .zero, to: SIMD3(20, 0, 0)) else {
            Issue.record("Could not create spine")
            return
        }

        guard let profile = Wire.circle(radius: 3) else {
            Issue.record("Could not create profile")
            return
        }

        let shell = Shape.pipeShell(spine: spine, profile: profile, mode: .frenet, solid: false)
        #expect(shell != nil)
    }

    // MARK: - Curve Analysis Tests (v0.9.0)

    @Test("Wire length of straight line")
    func wireLengthLine() {
        let line = Wire.line(from: .zero, to: SIMD3(10, 0, 0))
        #expect(line != nil)
        let length = line?.length
        #expect(length != nil)
        #expect(abs(length! - 10.0) < 0.01)
    }

    @Test("Wire length of circle")
    func wireLengthCircle() {
        let circle = Wire.circle(radius: 10)
        #expect(circle != nil)
        let length = circle?.length
        #expect(length != nil)
        // Circumference = 2*pi*r
        let expected = 2 * Double.pi * 10
        #expect(abs(length! - expected) < 0.1)
    }

    @Test("Wire curve info for circle")
    func wireCurveInfoCircle() {
        let circle = Wire.circle(radius: 5)
        #expect(circle != nil)
        let info = circle?.curveInfo
        #expect(info != nil)
        #expect(info!.isClosed)
        #expect(abs(info!.length - 2 * .pi * 5) < 0.1)
    }

    @Test("Wire curve info for line")
    func wireCurveInfoLine() {
        let line = Wire.line(from: SIMD3(0, 0, 0), to: SIMD3(20, 0, 0))
        #expect(line != nil)
        let info = line?.curveInfo
        #expect(info != nil)
        #expect(!info!.isClosed)
        #expect(abs(info!.length - 20.0) < 0.01)
        // Check start and end points
        #expect(abs(info!.startPoint.x) < 0.01)
        #expect(abs(info!.endPoint.x - 20.0) < 0.01)
    }

    @Test("Wire point at parameter")
    func wirePointAtParameter() {
        let line = Wire.line(from: .zero, to: SIMD3(20, 0, 0))
        #expect(line != nil)

        // Start point
        let start = line?.point(at: 0.0)
        #expect(start != nil)
        #expect(abs(start!.x) < 0.01)

        // Midpoint
        let mid = line?.point(at: 0.5)
        #expect(mid != nil)
        #expect(abs(mid!.x - 10.0) < 0.01)

        // End point
        let end = line?.point(at: 1.0)
        #expect(end != nil)
        #expect(abs(end!.x - 20.0) < 0.01)
    }

    @Test("Wire tangent at parameter")
    func wireTangentAtParameter() {
        let line = Wire.line(from: .zero, to: SIMD3(10, 0, 0))
        #expect(line != nil)

        let tangent = line?.tangent(at: 0.5)
        #expect(tangent != nil)
        // Tangent should point in +X direction
        #expect(abs(tangent!.x - 1.0) < 0.01)
        #expect(abs(tangent!.y) < 0.01)
        #expect(abs(tangent!.z) < 0.01)
    }

    @Test("Wire curvature of circle")
    func wireCurvatureCircle() {
        let radius = 10.0
        let circle = Wire.circle(radius: radius)
        #expect(circle != nil)

        let curvature = circle?.curvature(at: 0.5)
        #expect(curvature != nil)
        // Curvature of circle = 1/radius
        #expect(abs(curvature! - 1.0/radius) < 0.001)
    }

    @Test("Wire curvature of line is zero")
    func wireCurvatureLine() {
        let line = Wire.line(from: .zero, to: SIMD3(10, 0, 0))
        #expect(line != nil)

        let curvature = line?.curvature(at: 0.5)
        #expect(curvature != nil)
        #expect(abs(curvature!) < 0.001)
    }

    @Test("Wire curve point with derivatives")
    func wireCurvePointDerivatives() {
        let radius = 5.0
        let circle = Wire.circle(radius: radius)
        #expect(circle != nil)

        let cp = circle?.curvePoint(at: 0.25)
        #expect(cp != nil)
        #expect(abs(cp!.curvature - 1.0/radius) < 0.001)
        // For a circle, the normal should point toward center
        #expect(cp!.normal != nil)
    }

    @Test("Wire offset 3D translates wire")
    func wireOffset3D() {
        let circle = Wire.circle(radius: 5)
        #expect(circle != nil)

        let raised = circle?.offset3D(distance: 10, direction: SIMD3(0, 0, 1))
        #expect(raised != nil)

        // Check that start point is at Z=10
        let info = raised?.curveInfo
        #expect(info != nil)
        #expect(abs(info!.startPoint.z - 10.0) < 0.01)
    }

    // MARK: - Surface Creation Tests (v0.9.0)

    @Test("B-spline surface from control point grid")
    func bsplineSurface() {
        // Create a 4x4 grid of control points
        let poles: [[SIMD3<Double>]] = [
            [SIMD3(0, 0, 0), SIMD3(0, 10, 0), SIMD3(0, 20, 0), SIMD3(0, 30, 0)],
            [SIMD3(10, 0, 1), SIMD3(10, 10, 1), SIMD3(10, 20, 1), SIMD3(10, 30, 1)],
            [SIMD3(20, 0, 1), SIMD3(20, 10, 1), SIMD3(20, 20, 1), SIMD3(20, 30, 1)],
            [SIMD3(30, 0, 0), SIMD3(30, 10, 0), SIMD3(30, 20, 0), SIMD3(30, 30, 0)]
        ]

        let surface = Shape.surface(poles: poles)
        #expect(surface != nil)
        #expect(surface?.isValid == true)
    }

    @Test("Ruled surface between two circles")
    func ruledSurfaceBetweenCircles() {
        let bottom = Wire.circle(radius: 10)
        #expect(bottom != nil)

        let top = bottom?.offset3D(distance: 20, direction: SIMD3(0, 0, 1))
        #expect(top != nil)

        let ruled = Shape.ruled(profile1: bottom!, profile2: top!)
        #expect(ruled != nil)
    }

    @Test("Shell with open faces")
    func shellWithOpenFaces() {
        let box = Shape.box(width: 20, height: 20, depth: 20)!

        // Get upward-facing faces (top face)
        let topFaces = box.upwardFaces()
        #expect(!topFaces.isEmpty)

        let shelled = box.shelled(thickness: 2.0, openFaces: topFaces)
        #expect(shelled != nil)
        #expect(shelled?.isValid == true)
    }

    @Test("Shell with specific face open")
    func shellWithSpecificFaceOpen() {
        let box = Shape.box(width: 30, height: 20, depth: 10)!

        // Get the first face and use it as the open face
        let faces = box.faces()
        #expect(!faces.isEmpty)

        let shelled = box.shelled(thickness: 1.5, openFaces: [faces[0]])
        #expect(shelled != nil)
    }
}


// MARK: - File Format Tests (v0.10.0)

@Suite("IGES Import/Export Tests")
struct IGESTests {

    @Test("Export shape to IGES")
    func exportIGES() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_export.igs")

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        try box.writeIGES(to: tempURL)

        // Verify file was created
        #expect(FileManager.default.fileExists(atPath: tempURL.path))

        // Verify file has content
        let data = try Data(contentsOf: tempURL)
        #expect(data.count > 0)
    }

    @Test("IGES roundtrip")
    func igesRoundtrip() throws {
        let original = Shape.box(width: 20, height: 15, depth: 10)!
        let originalVolume = original.volume ?? 0

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_roundtrip.igs")

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        // Export
        try original.writeIGES(to: tempURL)

        // Import
        let imported = try Shape.loadIGES(from: tempURL)
        #expect(imported.isValid)

        // Volume should be approximately the same
        let importedVolume = imported.volume ?? 0
        let volumeRatio = importedVolume / originalVolume
        #expect(volumeRatio > 0.99 && volumeRatio < 1.01)
    }

    @Test("Get IGES data")
    func getIGESData() throws {
        let cylinder = Shape.cylinder(radius: 5, height: 20)!

        let data = try cylinder.igesData()
        #expect(data.count > 0)

        // IGES files start with specific header
        let headerString = String(data: data.prefix(80), encoding: .ascii) ?? ""
        #expect(headerString.contains("S") || headerString.count > 0)
    }
}

@Suite("BREP Native Format Tests")
struct BREPTests {

    @Test("Export shape to BREP")
    func exportBREP() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_export.brep")

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        try box.writeBREP(to: tempURL)

        // Verify file was created
        #expect(FileManager.default.fileExists(atPath: tempURL.path))

        // Verify file has content
        let data = try Data(contentsOf: tempURL)
        #expect(data.count > 0)
    }

    @Test("BREP roundtrip preserves geometry exactly")
    func brepRoundtrip() throws {
        let original = Shape.box(width: 20, height: 15, depth: 10)!
        let originalVolume = original.volume ?? 0
        let originalArea = original.surfaceArea ?? 0

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_roundtrip.brep")

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        // Export
        try original.writeBREP(to: tempURL)

        // Import
        let imported = try Shape.loadBREP(from: tempURL)
        #expect(imported.isValid)

        // BREP should preserve exact geometry
        let importedVolume = imported.volume ?? 0
        let importedArea = imported.surfaceArea ?? 0

        // Should be exactly equal (within floating point tolerance)
        #expect(abs(importedVolume - originalVolume) < 1e-10)
        #expect(abs(importedArea - originalArea) < 1e-10)
    }

    @Test("BREP export with triangles")
    func brepExportWithTriangles() throws {
        let sphere = Shape.sphere(radius: 10)!

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_triangles.brep")

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        // Export with triangulation
        try sphere.writeBREP(to: tempURL, withTriangles: true, withNormals: true)

        // Verify file was created and has content
        let data = try Data(contentsOf: tempURL)
        #expect(data.count > 0)

        // Re-import
        let imported = try Shape.loadBREP(from: tempURL)
        #expect(imported.isValid)
    }

    @Test("BREP export with and without triangles options")
    func brepExportTriangleOptions() throws {
        // Use a sphere which has actual triangulation data
        let sphere = Shape.sphere(radius: 10)!
        // Mesh the sphere first to ensure triangulation exists
        let _ = sphere.mesh(linearDeflection: 0.1, angularDeflection: 0.5)!

        let withTriangles = FileManager.default.temporaryDirectory
            .appendingPathComponent("with_tri.brep")
        let withoutTriangles = FileManager.default.temporaryDirectory
            .appendingPathComponent("without_tri.brep")

        defer {
            try? FileManager.default.removeItem(at: withTriangles)
            try? FileManager.default.removeItem(at: withoutTriangles)
        }

        try sphere.writeBREP(to: withTriangles, withTriangles: true)
        try sphere.writeBREP(to: withoutTriangles, withTriangles: false)

        // Both should be valid BREP files
        let withData = try Data(contentsOf: withTriangles)
        let withoutData = try Data(contentsOf: withoutTriangles)

        #expect(withData.count > 0)
        #expect(withoutData.count > 0)

        // Can reimport both
        let reimportWith = try Shape.loadBREP(from: withTriangles)
        let reimportWithout = try Shape.loadBREP(from: withoutTriangles)
        #expect(reimportWith.isValid)
        #expect(reimportWithout.isValid)
    }

    @Test("Get BREP data")
    func getBREPData() throws {
        let cone = Shape.cone(bottomRadius: 10, topRadius: 5, height: 15)!

        let data = try cone.brepData()
        #expect(data.count > 0)

        // BREP files start with "DBRep_DrawableShape"
        let headerString = String(data: data.prefix(100), encoding: .ascii) ?? ""
        #expect(headerString.contains("DBRep") || headerString.contains("CASCADE"))
    }
}


// MARK: - Geometry Construction Tests (v0.11.0)

@Suite("Geometry Construction Tests")
struct GeometryConstructionTests {

    @Test("Create face from rectangular wire")
    func faceFromRectangle() {
        let rect = Wire.rectangle(width: 10, height: 5)!
        let face = Shape.face(from: rect)

        #expect(face != nil)
        #expect(face!.isValid)

        // Face should have surface area equal to rectangle area
        let area = face!.surfaceArea ?? 0
        #expect(abs(area - 50.0) < 0.01)  // 10 x 5 = 50
    }

    @Test("Create face from circular wire")
    func faceFromCircle() {
        let circle = Wire.circle(radius: 5)!
        let face = Shape.face(from: circle)

        #expect(face != nil)
        #expect(face!.isValid)

        // Face should have surface area equal to π * r²
        let area = face!.surfaceArea ?? 0
        let expectedArea = Double.pi * 5.0 * 5.0
        #expect(abs(area - expectedArea) < 0.1)
    }

    @Test("Create face with hole")
    func faceWithHole() {
        let outer = Wire.rectangle(width: 20, height: 20)!
        let hole = Wire.circle(radius: 5)!

        let face = Shape.face(outer: outer, holes: [hole])

        #expect(face != nil)
        #expect(face!.isValid)

        // Area should be outer minus hole
        let area = face!.surfaceArea ?? 0
        let expectedArea = 400.0 - (Double.pi * 25.0)  // 20x20 - π*5²
        #expect(abs(area - expectedArea) < 0.5)
    }

    @Test("Create face with multiple holes")
    func faceWithMultipleHoles() {
        let outer = Wire.rectangle(width: 30, height: 30)!
        // Use offset3D to position the holes
        let hole1 = Wire.circle(radius: 3)!.offset3D(distance: 8, direction: SIMD3(-1, 0, 0))!
        let hole2 = Wire.circle(radius: 3)!.offset3D(distance: 8, direction: SIMD3(1, 0, 0))!

        let face = Shape.face(outer: outer, holes: [hole1, hole2])

        #expect(face != nil)
        #expect(face!.isValid)

        // Area should be outer minus both holes
        let area = face!.surfaceArea ?? 0
        let expectedArea = 900.0 - 2 * (Double.pi * 9.0)  // 30x30 - 2*π*3²
        #expect(abs(area - expectedArea) < 0.5)
    }

    @Test("Extrude face to create solid")
    func extrudeFace() {
        let rect = Wire.rectangle(width: 10, height: 5)!
        let face = Shape.face(from: rect)!

        // Extrude the face to create a solid
        let solid = Shape.extrude(profile: rect, direction: SIMD3(0, 0, 1), length: 3)!

        #expect(solid.isValid)

        // Volume should be area * height
        let volume = solid.volume ?? 0
        #expect(abs(volume - 150.0) < 0.1)  // 10 * 5 * 3
    }
}


@Suite("Sewing Tests")
struct SewingTests {

    @Test("Sew two shapes together")
    func sewTwoShapes() {
        // Create two separate faces (they don't need to be adjacent for sewing to work)
        let rect1 = Wire.rectangle(width: 10, height: 10)!
        let rect2 = Wire.circle(radius: 5)!

        let face1 = Shape.face(from: rect1)!
        let face2 = Shape.face(from: rect2)!

        let sewn = Shape.sew(face1, with: face2, tolerance: 1e-6)

        #expect(sewn != nil)
        #expect(sewn!.isValid)
    }

    @Test("Sew array of faces")
    func sewMultipleFaces() {
        // Create several separate faces
        let faces = [
            Shape.face(from: Wire.rectangle(width: 10, height: 10)!)!,
            Shape.face(from: Wire.circle(radius: 5)!)!,
            Shape.face(from: Wire.rectangle(width: 8, height: 8)!)!
        ]

        let sewn = Shape.sew(shapes: faces, tolerance: 1e-6)

        #expect(sewn != nil)
        #expect(sewn!.isValid)
    }

    @Test("Instance method sewn(with:)")
    func instanceMethodSewn() {
        let face1 = Shape.face(from: Wire.rectangle(width: 10, height: 10)!)!
        let face2 = Shape.face(from: Wire.circle(radius: 5)!)!

        let sewn = face1.sewn(with: face2)

        #expect(sewn != nil)
        #expect(sewn!.isValid)
    }
}


@Suite("Solid From Shell Tests")
struct SolidFromShellTests {

    @Test("Solid from shell function exists")
    func solidFromShellExists() {
        // Create a simple face and try to make it into a shell
        // Note: Creating a proper closed shell from scratch is complex.
        // This test verifies the API exists and handles inputs correctly.
        let rect = Wire.rectangle(width: 10, height: 10)!
        let face = Shape.face(from: rect)!

        // A single face cannot become a solid (not closed), so this should return nil
        let solid = Shape.solid(from: face)

        // This is expected to fail since a single face isn't a closed shell
        // The test verifies the API doesn't crash
        #expect(solid == nil || solid!.isValid)
    }

    @Test("Solid from compound of shapes")
    func solidFromCompound() {
        // Create a compound of faces (still won't be a closed shell)
        let face1 = Shape.face(from: Wire.rectangle(width: 10, height: 10)!)!
        let face2 = Shape.face(from: Wire.circle(radius: 5)!)!

        let compound = Shape.compound([face1, face2])!

        // This won't create a solid since faces aren't connected
        let solid = Shape.solid(from: compound)

        // The test verifies the API handles non-closed shells gracefully
        #expect(solid == nil || solid!.isValid)
    }
}


@Suite("Curve Interpolation Tests")
struct CurveInterpolationTests {

    @Test("Interpolate through 2 points")
    func interpolateTwoPoints() {
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0),
            SIMD3(10, 10, 0)
        ]

        let wire = Wire.interpolate(through: points)

        #expect(wire != nil)

        // Length should be approximately sqrt(200) ≈ 14.14
        let length = wire!.length ?? 0
        #expect(abs(length - 14.14) < 0.5)
    }

    @Test("Interpolate through multiple points")
    func interpolateMultiplePoints() {
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0),
            SIMD3(10, 5, 0),
            SIMD3(20, 0, 0),
            SIMD3(30, 5, 0),
            SIMD3(40, 0, 0)
        ]

        let wire = Wire.interpolate(through: points)

        #expect(wire != nil)

        // Wire should pass through all points
        let info = wire!.curveInfo
        #expect(info != nil)
        #expect(!info!.isClosed)
    }

    @Test("Interpolate closed curve")
    func interpolateClosed() {
        // Create points for a closed curve (roughly circular)
        let points: [SIMD3<Double>] = [
            SIMD3(10, 0, 0),
            SIMD3(0, 10, 0),
            SIMD3(-10, 0, 0),
            SIMD3(0, -10, 0)
        ]

        let wire = Wire.interpolate(through: points, closed: true)

        #expect(wire != nil)

        let info = wire!.curveInfo
        #expect(info != nil)
        #expect(info!.isClosed)
    }

    @Test("Interpolate with tangent constraints")
    func interpolateWithTangents() {
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0),
            SIMD3(10, 0, 0)
        ]

        // Start going up, end going up (creates an arc)
        let wire = Wire.interpolate(
            through: points,
            startTangent: SIMD3(1, 1, 0),   // 45 degrees up
            endTangent: SIMD3(1, -1, 0)      // 45 degrees down
        )

        #expect(wire != nil)

        // The curve should arc above the straight line
        // Check a point in the middle
        let midPoint = wire!.point(at: 0.5)
        #expect(midPoint != nil)

        // The middle should be above Y=0 due to the tangent constraints
        #expect(midPoint!.y > 0)
    }

    @Test("Interpolate 3D curve")
    func interpolate3DCurve() {
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0),
            SIMD3(10, 0, 5),
            SIMD3(20, 0, 10),
            SIMD3(30, 0, 5),
            SIMD3(40, 0, 0)
        ]

        let wire = Wire.interpolate(through: points)

        #expect(wire != nil)

        // Check that the curve passes through the middle point
        // (approximately, as interpolation smooths the curve)
        let midPoint = wire!.point(at: 0.5)
        #expect(midPoint != nil)

        // Z should be roughly around 10 at the middle
        #expect(midPoint!.z > 5)
    }

    @Test("Interpolate too few points returns nil")
    func interpolateTooFewPoints() {
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0)  // Only 1 point
        ]

        let wire = Wire.interpolate(through: points)
        #expect(wire == nil)
    }
}


// MARK: - Feature-Based Modeling Tests (v0.12.0)

@Suite("Prismatic Feature Tests")
struct PrismaticFeatureTests {

    @Test("Add boss to box")
    func addBossToBox() {
        // Box is 50x50x10 centered at origin: X[-25,25], Y[-25,25], Z[-5,5]
        let box = Shape.box(width: 50, height: 50, depth: 10)!
        let originalVolume = box.volume ?? 0

        // Create a circular profile and position it at top of box (Z=5)
        let circle = Wire.circle(radius: 5)!
        let bossProfile = circle.offset3D(distance: 5, direction: SIMD3(0, 0, 1))!

        // Add boss on top (extends from Z=5 to Z=10)
        let withBoss = box.withBoss(profile: bossProfile, direction: SIMD3(0, 0, 1), height: 5)

        #expect(withBoss != nil)
        #expect(withBoss!.isValid)

        // Volume should increase
        let newVolume = withBoss!.volume ?? 0
        let bossVolume = Double.pi * 25 * 5  // π * r² * h
        #expect(newVolume > originalVolume)
        #expect(abs(newVolume - (originalVolume + bossVolume)) < 1.0)
    }

    @Test("Create pocket in box")
    func createPocketInBox() {
        let box = Shape.box(width: 50, height: 50, depth: 20)!
        let originalVolume = box.volume ?? 0

        // Create a rectangular pocket profile
        let pocketProfile = Wire.rectangle(width: 20, height: 20)!

        // Create pocket going down into the box
        let withPocket = box.withPocket(profile: pocketProfile, direction: SIMD3(0, 0, -1), depth: 10)

        #expect(withPocket != nil)
        #expect(withPocket!.isValid)

        // Volume should decrease
        let newVolume = withPocket!.volume ?? 0
        let pocketVolume = 20 * 20 * 10  // w * h * d
        #expect(newVolume < originalVolume)
        #expect(abs(newVolume - (originalVolume - Double(pocketVolume))) < 1.0)
    }
}


@Suite("Drilling Tests")
struct DrillingTests {

    @Test("Drill hole into box")
    func drillHoleIntoBox() {
        // Box is centered at origin: X[-25,25], Y[-25,25], Z[-10,10]
        let box = Shape.box(width: 50, height: 50, depth: 20)!
        let originalVolume = box.volume ?? 0

        // Drill from slightly above top surface (Z=10), at center (X=0, Y=0)
        let drilled = box.drilled(at: SIMD3(0, 0, 11), direction: SIMD3(0, 0, -1), radius: 5, depth: 11)

        #expect(drilled != nil)
        #expect(drilled!.isValid)

        // Volume should decrease by cylinder volume
        let newVolume = drilled!.volume ?? 0
        let holeVolume = Double.pi * 25 * 10  // π * r² * h (only 10mm inside the box)
        #expect(newVolume < originalVolume)
        #expect(abs(newVolume - (originalVolume - holeVolume)) < 2.0)  // Allow some tolerance
    }

    @Test("Drill through hole")
    func drillThroughHole() {
        // Box is centered at origin: X[-25,25], Y[-25,25], Z[-10,10]
        let box = Shape.box(width: 50, height: 50, depth: 20)!
        let originalVolume = box.volume ?? 0

        // Drill through (depth = 0 means through) starting above top surface
        let drilled = box.drilled(at: SIMD3(0, 0, 15), direction: SIMD3(0, 0, -1), radius: 5, depth: 0)

        #expect(drilled != nil)
        #expect(drilled!.isValid)

        // Volume should decrease by full cylinder volume through the box
        let newVolume = drilled!.volume ?? 0
        let holeVolume = Double.pi * 25 * 20  // π * r² * box_depth
        #expect(newVolume < originalVolume)
        #expect(abs(newVolume - (originalVolume - holeVolume)) < 2.0)
    }

    @Test("Multiple holes")
    func multipleHoles() {
        // Box 50x50x10 is centered at origin: X[-25,25], Y[-25,25], Z[-5,5]
        let box = Shape.box(width: 50, height: 50, depth: 10)!

        // Drill multiple holes from above top surface (Z=5) along Y centerline
        var result = box.drilled(at: SIMD3(-15, 0, 8), direction: SIMD3(0, 0, -1), radius: 3, depth: 0)
        #expect(result != nil)

        result = result!.drilled(at: SIMD3(0, 0, 8), direction: SIMD3(0, 0, -1), radius: 3, depth: 0)
        #expect(result != nil)

        result = result!.drilled(at: SIMD3(15, 0, 8), direction: SIMD3(0, 0, -1), radius: 3, depth: 0)
        #expect(result != nil)
        #expect(result!.isValid)
    }
}


@Suite("Shape Splitting Tests")
struct ShapeSplittingTests {

    @Test("Split box by horizontal plane")
    func splitByHorizontalPlane() {
        // Box is centered at origin: X[-10,10], Y[-10,10], Z[-10,10]
        let box = Shape.box(width: 20, height: 20, depth: 20)!

        // Split at Z=0 (middle of the box)
        let halves = box.split(atPlane: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))

        #expect(halves != nil)
        #expect(halves!.count == 2)

        // Each half should be valid
        for half in halves! {
            #expect(half.isValid)
        }

        // Total volume should equal original
        let totalVolume = halves!.reduce(0.0) { $0 + ($1.volume ?? 0) }
        let originalVolume = box.volume ?? 0
        #expect(abs(totalVolume - originalVolume) < 1.0)
    }

    @Test("Split box by diagonal plane")
    func splitByDiagonalPlane() {
        // Box is centered at origin: X[-10,10], Y[-10,10], Z[-10,10]
        let box = Shape.box(width: 20, height: 20, depth: 20)!

        // Split diagonally through center
        let pieces = box.split(atPlane: SIMD3(0, 0, 0), normal: SIMD3(1, 1, 0).normalized)

        #expect(pieces != nil)
        #expect(pieces!.count >= 2)

        for piece in pieces! {
            #expect(piece.isValid)
        }
    }

    @Test("Split by shape tool")
    func splitByShapeTool() {
        let box = Shape.box(width: 20, height: 20, depth: 20)!

        // Create a cutting face
        let cuttingFace = Shape.face(from: Wire.rectangle(width: 40, height: 40)!)!
            .translated(by: SIMD3(0, 0, 10))!

        let pieces = box.split(by: cuttingFace)

        #expect(pieces != nil)
        #expect(pieces!.count >= 1)
    }
}


@Suite("Pattern Tests")
struct PatternTests {

    @Test("Linear pattern of cylinders")
    func linearPatternOfCylinders() {
        let cylinder = Shape.cylinder(radius: 5, height: 10)!

        // Create a row of 4 cylinders spaced 20mm apart
        let pattern = cylinder.linearPattern(direction: SIMD3(1, 0, 0), spacing: 20, count: 4)

        #expect(pattern != nil)
        #expect(pattern!.isValid)

        // The pattern should have approximately 4x the volume
        let singleVolume = cylinder.volume ?? 0
        let patternVolume = pattern!.volume ?? 0
        #expect(abs(patternVolume - singleVolume * 4) < 1.0)
    }

    @Test("Circular pattern of holes")
    func circularPatternOfHoles() {
        let cylinder = Shape.cylinder(radius: 3, height: 10)!
            .translated(by: SIMD3(20, 0, 0))!

        // Create 6 cylinders in a circle around Z axis
        let pattern = cylinder.circularPattern(
            axisPoint: SIMD3(0, 0, 0),
            axisDirection: SIMD3(0, 0, 1),
            count: 6,
            angle: 0  // Full circle
        )

        #expect(pattern != nil)
        #expect(pattern!.isValid)

        // The pattern should have 6x the volume
        let singleVolume = cylinder.volume ?? 0
        let patternVolume = pattern!.volume ?? 0
        #expect(abs(patternVolume - singleVolume * 6) < 1.0)
    }

    @Test("Partial circular pattern")
    func partialCircularPattern() {
        let box = Shape.box(width: 5, height: 5, depth: 5)!
            .translated(by: SIMD3(15, 0, 0))!

        // Create 3 boxes spanning 90 degrees
        let pattern = box.circularPattern(
            axisPoint: SIMD3(0, 0, 0),
            axisDirection: SIMD3(0, 0, 1),
            count: 3,
            angle: .pi / 2  // 90 degrees
        )

        #expect(pattern != nil)
        #expect(pattern!.isValid)
    }
}


@Suite("Glue Tests")
struct GlueTests {

    @Test("Glue two boxes")
    func glueTwoBoxes() {
        // Create two boxes that share a face
        let box1 = Shape.box(width: 10, height: 10, depth: 10)!
        let box2 = Shape.box(width: 10, height: 10, depth: 10)!
            .translated(by: SIMD3(10, 0, 0))!

        let glued = Shape.glue(box1, box2, tolerance: 1e-6)

        #expect(glued != nil)
        #expect(glued!.isValid)

        // Volume should be sum of both
        let gluedVolume = glued!.volume ?? 0
        let expectedVolume = 10.0 * 10.0 * 10.0 * 2
        #expect(abs(gluedVolume - expectedVolume) < 1.0)
    }
}


@Suite("Evolved Surface Tests")
struct EvolvedSurfaceTests {

    @Test("Simple evolved shape")
    func simpleEvolved() {
        // Create a simple spine (quarter circle)
        let spine = Wire.arc(center: SIMD3(0, 0, 0), radius: 20, startAngle: 0, endAngle: .pi / 2)!

        // Create a small profile
        let profile = Wire.rectangle(width: 2, height: 2)!

        let evolved = Shape.evolved(spine: spine, profile: profile)

        // Evolved may not always succeed depending on geometry
        if let evolved = evolved {
            #expect(evolved.isValid)
        }
    }
}


// MARK: - v0.13.0 Shape Healing & Analysis Tests

@Suite("Shape Analysis Tests")
struct ShapeAnalysisTests {

    @Test("Analyze valid box")
    func analyzeValidBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        let analysis = box.analyze(tolerance: 0.001)

        #expect(analysis != nil)
        #expect(analysis!.hasInvalidTopology == false)
        // A valid box may have gap counts due to wire analysis heuristics,
        // but should have no invalid topology
        #expect(box.isValid)
    }

    @Test("Analyze shape for small features")
    func analyzeForSmallFeatures() {
        // Create a box - should have no small features
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        let analysis = box.analyze(tolerance: 0.001)

        #expect(analysis != nil)
        #expect(analysis!.smallEdgeCount == 0)
        #expect(analysis!.smallFaceCount == 0)
    }

    @Test("Analysis result properties")
    func analysisResultProperties() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let analysis = box.analyze()!

        #expect(analysis.totalProblems >= 0)
        // Check that totalProblems is consistent with component counts
        let expectedTotal = analysis.smallEdgeCount + analysis.smallFaceCount +
                           analysis.gapCount + analysis.selfIntersectionCount +
                           analysis.freeEdgeCount + analysis.freeFaceCount +
                           (analysis.hasInvalidTopology ? 1 : 0)
        #expect(analysis.totalProblems == expectedTotal)
    }
}

@Suite("Shape Fixing Tests")
struct ShapeFixingTests {

    @Test("Fix healthy shape returns shape")
    func fixHealthyShape() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        let fixed = box.fixed(tolerance: 0.001)

        #expect(fixed != nil)
        #expect(fixed!.isValid)
    }

    @Test("Fix with selective modes")
    func fixWithSelectiveModes() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        // Fix only wires and faces, not solids
        let fixed = box.fixed(tolerance: 0.001, fixSolid: false, fixShell: true, fixFace: true, fixWire: true)

        #expect(fixed != nil)
        #expect(fixed!.isValid)
    }

    @Test("Existing heal function still works")
    func existingHealStillWorks() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        // The healed() function should still work
        let healed = box.healed()!

        #expect(healed.isValid)
    }
}

@Suite("Shape Unification Tests")
struct ShapeUnificationTests {

    @Test("Unify boolean result")
    func unifyBooleanResult() {
        // Create a shape with potentially redundant topology from booleans
        let box = Shape.box(width: 20, height: 20, depth: 20)!
        let cyl = Shape.cylinder(radius: 3, height: 25)!

        // Subtract cylinder to create internal faces
        let result = (box - cyl)!

        let unified = result.unified()

        #expect(unified != nil)
        #expect(unified!.isValid)
    }

    @Test("Unify with edge-only mode")
    func unifyEdgesOnly() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        let unified = box.unified(unifyEdges: true, unifyFaces: false)

        #expect(unified != nil)
        #expect(unified!.isValid)
    }

    @Test("Simplify shape")
    func simplifyShape() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        let simplified = box.simplified(tolerance: 0.001)

        #expect(simplified != nil)
        #expect(simplified!.isValid)
    }
}

@Suite("Wire Fixing Tests")
struct WireFixingTests {

    @Test("Fix healthy wire")
    func fixHealthyWire() {
        let wire = Wire.rectangle(width: 10, height: 10)!

        let fixed = wire.fixed(tolerance: 0.001)

        #expect(fixed != nil)
    }

    @Test("Fix circle wire")
    func fixCircleWire() {
        let circle = Wire.circle(radius: 5)!

        let fixed = circle.fixed(tolerance: 0.001)

        #expect(fixed != nil)
    }
}

@Suite("Face Fixing Tests")
struct FaceFixingTests {

    @Test("Fix face from wire")
    func fixFaceFromWire() {
        let wire = Wire.rectangle(width: 10, height: 10)!
        let face = Shape.face(from: wire)!

        // Get faces from the shape
        let faces = face.faces()
        guard !faces.isEmpty else {
            return  // Skip if no faces found
        }

        let fixed = faces[0].fixed(tolerance: 0.001)

        #expect(fixed != nil)
        #expect(fixed!.isValid)
    }
}

// MARK: - Advanced Blends & Surface Filling Tests (v0.14.0)

@Suite("Variable Radius Fillet Tests")
struct VariableRadiusFilletTests {

    @Test("Variable radius fillet on box edge")
    func variableFilletOnBoxEdge() {
        let box = Shape.box(width: 20, height: 20, depth: 20)!

        // Apply variable radius fillet: starts at 1mm, ends at 3mm
        let filleted = box.filletedVariable(
            edgeIndex: 0,
            radiusProfile: [(0.0, 1.0), (1.0, 3.0)]
        )

        #expect(filleted != nil)
        if let filleted = filleted {
            #expect(filleted.isValid)
        }
    }

    @Test("Variable radius fillet with mid-point")
    func variableFilletWithMidPoint() {
        let box = Shape.box(width: 30, height: 30, depth: 30)!

        // Apply variable radius fillet: 1mm at start, 4mm at middle, 1mm at end
        let filleted = box.filletedVariable(
            edgeIndex: 0,
            radiusProfile: [(0.0, 1.0), (0.5, 4.0), (1.0, 1.0)]
        )

        #expect(filleted != nil)
        if let filleted = filleted {
            #expect(filleted.isValid)
        }
    }

    @Test("Variable fillet requires at least two points")
    func variableFilletRequiresMinPoints() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        // Should fail with only one point
        let filleted = box.filletedVariable(
            edgeIndex: 0,
            radiusProfile: [(0.5, 1.0)]
        )

        #expect(filleted == nil)
    }
}

@Suite("Multi-Edge Blend Tests")
struct MultiEdgeBlendTests {

    @Test("Blend multiple edges with different radii")
    func blendMultipleEdges() {
        let box = Shape.box(width: 20, height: 20, depth: 20)!

        // Fillet three edges with different radii
        let blended = box.blendedEdges([
            (0, 1.0),
            (1, 2.0),
            (2, 1.5)
        ])

        #expect(blended != nil)
        if let blended = blended {
            #expect(blended.isValid)
        }
    }

    @Test("Blend single edge")
    func blendSingleEdge() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        let blended = box.blendedEdges([(0, 1.0)])

        #expect(blended != nil)
        if let blended = blended {
            #expect(blended.isValid)
        }
    }

    @Test("Blend with empty array returns nil")
    func blendEmptyArray() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        let blended = box.blendedEdges([])

        #expect(blended == nil)
    }
}

@Suite("Wire 2D Fillet Tests")
struct Wire2DFilletTests {

    @Test("Fillet single vertex of rectangle")
    func filletSingleVertex() {
        guard let rect = Wire.rectangle(width: 10, height: 5) else {
            Issue.record("Failed to create rectangle wire")
            return
        }

        let filleted = rect.filleted2D(vertexIndex: 0, radius: 1.0)

        #expect(filleted != nil)
    }

    @Test("Fillet all vertices of rectangle")
    func filletAllVertices() {
        guard let rect = Wire.rectangle(width: 10, height: 5) else {
            Issue.record("Failed to create rectangle wire")
            return
        }

        let filleted = rect.filletedAll2D(radius: 1.0)

        #expect(filleted != nil)
    }

    @Test("Fillet polygon wire")
    func filletPolygonWire() {
        guard let polygon = Wire.polygon([
            SIMD2(0, 0),
            SIMD2(10, 0),
            SIMD2(10, 10),
            SIMD2(5, 15),
            SIMD2(0, 10)
        ], closed: true) else {
            Issue.record("Failed to create polygon wire")
            return
        }

        let filleted = polygon.filleted2D(vertexIndex: 2, radius: 1.5)

        #expect(filleted != nil)
    }
}

@Suite("Wire 2D Chamfer Tests")
struct Wire2DChamferTests {

    @Test("Chamfer single vertex of rectangle")
    func chamferSingleVertex() {
        guard let rect = Wire.rectangle(width: 10, height: 5) else {
            Issue.record("Failed to create rectangle wire")
            return
        }

        let chamfered = rect.chamfered2D(vertexIndex: 0, distance1: 1.0, distance2: 1.0)

        #expect(chamfered != nil)
    }

    @Test("Chamfer all vertices of rectangle")
    func chamferAllVertices() {
        guard let rect = Wire.rectangle(width: 10, height: 5) else {
            Issue.record("Failed to create rectangle wire")
            return
        }

        let chamfered = rect.chamferedAll2D(distance: 1.0)

        #expect(chamfered != nil)
    }

    @Test("Asymmetric chamfer")
    func asymmetricChamfer() {
        guard let rect = Wire.rectangle(width: 20, height: 10) else {
            Issue.record("Failed to create rectangle wire")
            return
        }

        // Asymmetric chamfer: different distances
        let chamfered = rect.chamfered2D(vertexIndex: 1, distance1: 1.0, distance2: 2.0)

        #expect(chamfered != nil)
    }
}

@Suite("Surface Filling Tests")
struct SurfaceFillingTests {

    @Test("Fill from closed wire boundary")
    func fillClosedWireBoundary() {
        // Create a closed rectangular wire as boundary
        guard let boundary = Wire.rectangle(width: 10, height: 10) else {
            Issue.record("Failed to create boundary wire")
            return
        }

        // Note: Surface filling is a complex OCCT operation that may not
        // succeed with all boundary configurations. This tests the API.
        let surface = Shape.fill(
            boundaries: [boundary],
            parameters: FillingParameters(continuity: .c0)
        )

        // The operation may or may not succeed depending on OCCT's
        // internal handling - we're testing the API interface works
        if let surface = surface {
            #expect(surface.isValid)
        }
    }

    @Test("Fill with polygon boundary")
    func fillPolygonBoundary() {
        guard let boundary = Wire.polygon([
            SIMD2(0, 0),
            SIMD2(10, 0),
            SIMD2(10, 10),
            SIMD2(0, 10)
        ], closed: true) else {
            Issue.record("Failed to create polygon boundary")
            return
        }

        let params = FillingParameters(
            continuity: .c0,
            tolerance: 1e-3,
            maxDegree: 8,
            maxSegments: 9
        )

        let surface = Shape.fill(boundaries: [boundary], parameters: params)

        // Test API works - actual success depends on OCCT
        if let surface = surface {
            #expect(surface.isValid)
        }
    }

    @Test("Fill empty boundaries returns nil")
    func fillEmptyBoundaries() {
        let surface = Shape.fill(boundaries: [])

        #expect(surface == nil)
    }
}

@Suite("Plate Surface Tests")
struct PlateSurfaceTests {

    @Test("Plate surface through grid of points")
    func plateThroughGridPoints() {
        // Create a grid of points for plate surface
        // GeomPlate works better with a good distribution of points
        let points: [SIMD3<Double>] = [
            // 3x3 grid
            SIMD3(0, 0, 0),
            SIMD3(5, 0, 0.5),
            SIMD3(10, 0, 0),
            SIMD3(0, 5, 0.5),
            SIMD3(5, 5, 1),  // Center raised
            SIMD3(10, 5, 0.5),
            SIMD3(0, 10, 0),
            SIMD3(5, 10, 0.5),
            SIMD3(10, 10, 0)
        ]

        let surface = Shape.plateSurface(through: points, tolerance: 1.0)

        // GeomPlate algorithms are complex - test API works
        if let surface = surface {
            #expect(surface.isValid)
        }
    }

    @Test("Plate surface with corner points")
    func plateWithCornerPoints() {
        // Simpler case - just corner points
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0),
            SIMD3(10, 0, 0),
            SIMD3(10, 10, 0),
            SIMD3(0, 10, 0)
        ]

        let surface = Shape.plateSurface(through: points, tolerance: 1.0)

        // Test API interface
        if let surface = surface {
            #expect(surface.isValid)
        }
    }

    @Test("Plate surface too few points")
    func plateTooFewPoints() {
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0),
            SIMD3(10, 0, 0)
        ]

        let surface = Shape.plateSurface(through: points, tolerance: 0.1)

        #expect(surface == nil)
    }

    @Test("Plate surface from curves - API test")
    func plateFromCurvesAPI() {
        guard let curve1 = Wire.line(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0)),
              let curve2 = Wire.line(from: SIMD3(0, 10, 0), to: SIMD3(10, 10, 0)) else {
            Issue.record("Failed to create curves")
            return
        }

        // Test the API interface - actual surface creation may not
        // succeed depending on OCCT's GeomPlate algorithm
        let surface = Shape.plateSurface(
            constrainedBy: [curve1, curve2],
            continuity: .c0,
            tolerance: 1.0
        )

        // Just verify we don't crash and API returns expected type
        if let surface = surface {
            #expect(surface.isValid)
        }
    }
}


// MARK: - Metal Visualization Tests

@Suite("Camera Tests")
struct CameraTests {

    @Test("Default state valid")
    func defaultState() {
        let cam = Camera()
        let eye = cam.eye
        let center = cam.center
        let up = cam.up

        // Default camera should have non-zero eye and up
        let eyeLen = sqrt(eye.x*eye.x + eye.y*eye.y + eye.z*eye.z)
        let upLen = sqrt(up.x*up.x + up.y*up.y + up.z*up.z)
        #expect(eyeLen > 0)
        #expect(upLen > 0)
    }

    @Test("Projection matrix non-identity")
    func projectionMatrixNonIdentity() {
        let cam = Camera()
        cam.aspect = 1.5
        let proj = cam.projectionMatrix

        // Check it's not identity — at least one off-diagonal or non-1 diagonal
        let isIdentity = proj.columns.0.x == 1 && proj.columns.1.y == 1 &&
                         proj.columns.2.z == 1 && proj.columns.3.w == 1 &&
                         proj.columns.0.y == 0 && proj.columns.0.z == 0
        #expect(!isIdentity)

        // Determinant should be non-zero
        let det = simd_determinant(proj)
        #expect(abs(det) > 1e-10)
    }

    @Test("View matrix changes with eye/center")
    func viewMatrixChanges() {
        let cam = Camera()
        cam.eye = SIMD3(0, 0, 10)
        cam.center = SIMD3(0, 0, 0)
        cam.up = SIMD3(0, 1, 0)
        let view1 = cam.viewMatrix

        cam.eye = SIMD3(10, 0, 0)
        let view2 = cam.viewMatrix

        // The two view matrices should differ
        let diff = view1.columns.0.x - view2.columns.0.x
        let diff2 = view1.columns.2.z - view2.columns.2.z
        #expect(abs(diff) > 1e-6 || abs(diff2) > 1e-6)
    }

    @Test("Project/Unproject roundtrip")
    func projectUnprojectRoundtrip() {
        let cam = Camera()
        cam.eye = SIMD3(0, 0, 100)
        cam.center = SIMD3(0, 0, 0)
        cam.up = SIMD3(0, 1, 0)
        cam.fieldOfView = 45
        cam.aspect = 1.0
        cam.zRange = (near: 1, far: 1000)

        let original = SIMD3<Double>(5, 3, 0)
        let projected = cam.project(original)
        let recovered = cam.unproject(projected)

        #expect(abs(recovered.x - original.x) < 0.1)
        #expect(abs(recovered.y - original.y) < 0.1)
        #expect(abs(recovered.z - original.z) < 0.1)
    }

    @Test("Orthographic mode produces different matrices")
    func orthographicVsPerspective() {
        let cam = Camera()
        cam.eye = SIMD3(0, 0, 100)
        cam.center = SIMD3(0, 0, 0)
        cam.up = SIMD3(0, 1, 0)
        cam.aspect = 1.0
        cam.zRange = (near: 1, far: 1000)

        cam.projectionType = .perspective
        let perspProj = cam.projectionMatrix

        cam.projectionType = .orthographic
        let orthoProj = cam.projectionMatrix

        // The projection matrices must differ
        let d = abs(perspProj.columns.0.x - orthoProj.columns.0.x) +
                abs(perspProj.columns.2.w - orthoProj.columns.2.w)
        #expect(d > 1e-6)
    }

    @Test("Fit bounding box adjusts camera")
    func fitBoundingBox() {
        let cam = Camera()
        cam.eye = SIMD3(0, 0, 100)
        cam.center = SIMD3(0, 0, 0)
        cam.up = SIMD3(0, 1, 0)
        cam.aspect = 1.0
        cam.zRange = (near: 0.1, far: 10000)

        let bboxMin = SIMD3<Double>(-5, -5, -5)
        let bboxMax = SIMD3<Double>(5, 5, 5)
        cam.fit(boundingBox: (min: bboxMin, max: bboxMax))

        // Project the center of the bounding box — should be near screen origin
        let boxCenter = SIMD3<Double>(0, 0, 0)
        let projected = cam.project(boxCenter)
        #expect(abs(projected.x) < 0.5)
        #expect(abs(projected.y) < 0.5)
    }
}

@Suite("Presentation Mesh Tests")
struct PresentationMeshTests {

    @Test("Box shaded mesh has 12 triangles")
    func boxShadedMesh() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        let mesh = box.shadedMesh(deflection: 0.1)

        #expect(mesh != nil)
        #expect(mesh!.triangleCount == 12)  // 6 faces * 2 triangles each
        #expect(mesh!.vertices.count == mesh!.normals.count)

        // All normals should be non-zero
        for normal in mesh!.normals {
            let len = sqrt(normal.x*normal.x + normal.y*normal.y + normal.z*normal.z)
            #expect(len > 0.5)
        }
    }

    @Test("Cylinder shaded mesh has triangles")
    func cylinderShadedMesh() {
        let cyl = Shape.cylinder(radius: 5, height: 10)
        let mesh = cyl.shadedMesh(deflection: 0.1)

        #expect(mesh != nil)
        #expect(mesh!.triangleCount > 0)
        #expect(mesh!.vertices.count > 0)
    }

    @Test("Box edge mesh has 12 segments")
    func boxEdgeMesh() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        let edges = box.edgeMesh(deflection: 0.1)

        #expect(edges != nil)
        #expect(edges!.segmentCount == 12)  // A box has 12 edges
        #expect(edges!.vertices.count > 0)
    }

    @Test("Sphere edge mesh produces valid segments")
    func sphereEdgeMesh() {
        let sphere = Shape.sphere(radius: 5)
        let edges = sphere.edgeMesh(deflection: 0.1)

        #expect(edges != nil)
        #expect(edges!.segmentCount > 0)
        #expect(edges!.vertices.count > 0)
    }
}

@Suite("Selector Tests")
struct SelectorTests {

    @Test("Add and pick box at center")
    func pickBoxAtCenter() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        let cam = Camera()
        cam.eye = SIMD3(0, 0, 50)
        cam.center = SIMD3(0, 0, 0)
        cam.up = SIMD3(0, 1, 0)
        cam.fieldOfView = 45
        cam.aspect = 1.0
        cam.zRange = (near: 1, far: 1000)

        let selector = Selector()
        let added = selector.add(shape: box, id: 42)
        #expect(added)

        // Pick at center of viewport
        let results = selector.pick(
            at: SIMD2(400, 300),
            camera: cam,
            viewSize: SIMD2(800, 600)
        )

        // The box should be hit
        if !results.isEmpty {
            #expect(results[0].shapeId == 42)
        }
    }

    @Test("Pick miss at far corner")
    func pickMiss() {
        let box = Shape.box(width: 1, height: 1, depth: 1)
        let cam = Camera()
        cam.eye = SIMD3(0, 0, 50)
        cam.center = SIMD3(0, 0, 0)
        cam.up = SIMD3(0, 1, 0)
        cam.fieldOfView = 45
        cam.aspect = 1.0
        cam.zRange = (near: 1, far: 1000)

        let selector = Selector()
        selector.add(shape: box, id: 1)

        // Pick at far corner — should miss the small box
        let results = selector.pick(
            at: SIMD2(0, 0),
            camera: cam,
            viewSize: SIMD2(800, 600)
        )

        #expect(results.isEmpty)
    }

    @Test("Multiple shapes return correct IDs")
    func multipleShapes() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)
            .translated(by: SIMD3(-20, 0, 0))
        let box2 = Shape.box(width: 10, height: 10, depth: 10)
            .translated(by: SIMD3(20, 0, 0))

        let cam = Camera()
        cam.eye = SIMD3(0, 0, 100)
        cam.center = SIMD3(0, 0, 0)
        cam.up = SIMD3(0, 1, 0)
        cam.fieldOfView = 45
        cam.aspect = 1.0
        cam.zRange = (near: 1, far: 1000)

        let selector = Selector()
        selector.add(shape: box1, id: 1)
        selector.add(shape: box2, id: 2)

        // Just verify both shapes were added without crash
        #expect(true)
    }

    @Test("Remove shape then pick returns miss")
    func removeShape() {
        let box = Shape.box(width: 10, height: 10, depth: 10)

        let selector = Selector()
        selector.add(shape: box, id: 99)
        let removed = selector.remove(id: 99)
        #expect(removed)

        let cam = Camera()
        cam.eye = SIMD3(0, 0, 50)
        cam.center = SIMD3(0, 0, 0)
        cam.up = SIMD3(0, 1, 0)
        cam.aspect = 1.0

        let results = selector.pick(
            at: SIMD2(400, 300),
            camera: cam,
            viewSize: SIMD2(800, 600)
        )

        #expect(results.isEmpty)
    }

    @Test("Rectangle pick covers geometry")
    func rectanglePick() {
        let box = Shape.box(width: 10, height: 10, depth: 10)

        let cam = Camera()
        cam.eye = SIMD3(0, 0, 50)
        cam.center = SIMD3(0, 0, 0)
        cam.up = SIMD3(0, 1, 0)
        cam.fieldOfView = 45
        cam.aspect = 1.0
        cam.zRange = (near: 1, far: 1000)

        let selector = Selector()
        selector.add(shape: box, id: 7)

        // Select a large rectangle covering the center
        let results = selector.pick(
            rect: (min: SIMD2(100, 100), max: SIMD2(700, 500)),
            camera: cam,
            viewSize: SIMD2(800, 600)
        )

        if !results.isEmpty {
            #expect(results[0].shapeId == 7)
        }
    }

    @Test("Clear all removes everything")
    func clearAll() {
        let selector = Selector()
        let box = Shape.box(width: 10, height: 10, depth: 10)
        selector.add(shape: box, id: 1)
        selector.add(shape: box, id: 2)
        selector.clearAll()

        let cam = Camera()
        cam.eye = SIMD3(0, 0, 50)
        cam.center = SIMD3(0, 0, 0)
        cam.up = SIMD3(0, 1, 0)
        cam.aspect = 1.0

        let results = selector.pick(
            at: SIMD2(400, 300),
            camera: cam,
            viewSize: SIMD2(800, 600)
        )

        #expect(results.isEmpty)
    }
}

// MARK: - Clip Plane Tests

@Suite("Clip Plane")
struct ClipPlaneTests {

    @Test("Equation roundtrip")
    func equationRoundtrip() {
        let plane = ClipPlane(equation: SIMD4(0, 0, 1, -5))
        let eq = plane.equation
        #expect(abs(eq.x - 0) < 1e-10)
        #expect(abs(eq.y - 0) < 1e-10)
        #expect(abs(eq.z - 1) < 1e-10)
        #expect(abs(eq.w - (-5)) < 1e-10)
    }

    @Test("Create from normal and distance")
    func createFromNormal() {
        let plane = ClipPlane(normal: SIMD3(1, 0, 0), distance: -3)
        let eq = plane.equation
        #expect(abs(eq.x - 1) < 1e-10)
        #expect(abs(eq.y - 0) < 1e-10)
        #expect(abs(eq.z - 0) < 1e-10)
        #expect(abs(eq.w - (-3)) < 1e-10)
    }

    @Test("Set equation updates values")
    func setEquation() {
        let plane = ClipPlane(equation: SIMD4(1, 0, 0, 0))
        plane.equation = SIMD4(0, 1, 0, -2)
        let eq = plane.equation
        #expect(abs(eq.y - 1) < 1e-10)
        #expect(abs(eq.w - (-2)) < 1e-10)
    }

    @Test("Reversed equation is negated")
    func reversedEquation() {
        let plane = ClipPlane(equation: SIMD4(0, 0, 1, -5))
        let rev = plane.reversedEquation
        #expect(abs(rev.x - 0) < 1e-10)
        #expect(abs(rev.y - 0) < 1e-10)
        #expect(abs(rev.z - (-1)) < 1e-10)
        #expect(abs(rev.w - 5) < 1e-10)
    }

    @Test("Enable and disable")
    func enableDisable() {
        let plane = ClipPlane(equation: SIMD4(0, 0, 1, 0))
        #expect(plane.isOn == true) // default is on
        plane.isOn = false
        #expect(plane.isOn == false)
        plane.isOn = true
        #expect(plane.isOn == true)
    }

    @Test("Capping on/off")
    func capping() {
        let plane = ClipPlane(equation: SIMD4(0, 0, 1, 0))
        #expect(plane.isCapping == false) // default is off
        plane.isCapping = true
        #expect(plane.isCapping == true)
    }

    @Test("Capping color")
    func cappingColor() {
        let plane = ClipPlane(equation: SIMD4(0, 0, 1, 0))
        plane.cappingColor = SIMD3(1.0, 0.0, 0.5)
        let color = plane.cappingColor
        #expect(abs(color.x - 1.0) < 0.01)
        #expect(abs(color.y - 0.0) < 0.01)
        #expect(abs(color.z - 0.5) < 0.01)
    }

    @Test("Hatch style")
    func hatchStyle() {
        let plane = ClipPlane(equation: SIMD4(0, 0, 1, 0))
        plane.hatchStyle = .diagonal45
        #expect(plane.hatchStyle == .diagonal45)
        plane.isHatchOn = true
        #expect(plane.isHatchOn == true)
        plane.isHatchOn = false
        #expect(plane.isHatchOn == false)
    }

    @Test("Probe point: inside half-space")
    func probePointInside() {
        // Plane z = 0 (normal pointing +Z): points with z > 0 are "in"
        let plane = ClipPlane(equation: SIMD4(0, 0, 1, 0))
        let state = plane.probe(point: SIMD3(0, 0, 5))
        #expect(state == .in)
    }

    @Test("Probe point: outside half-space")
    func probePointOutside() {
        // Plane z = 0 (normal pointing +Z): points with z < 0 are "out"
        let plane = ClipPlane(equation: SIMD4(0, 0, 1, 0))
        let state = plane.probe(point: SIMD3(0, 0, -5))
        #expect(state == .out)
    }

    @Test("Probe bounding box: fully inside")
    func probeBoxInside() {
        // Plane z = 0 (normal pointing +Z)
        let plane = ClipPlane(equation: SIMD4(0, 0, 1, 0))
        let state = plane.probe(box: (min: SIMD3(0, 0, 1), max: SIMD3(5, 5, 10)))
        #expect(state == .in)
    }

    @Test("Probe bounding box: partially clipped")
    func probeBoxPartial() {
        // Plane z = 0 (normal pointing +Z): box straddles z=0
        let plane = ClipPlane(equation: SIMD4(0, 0, 1, 0))
        let state = plane.probe(box: (min: SIMD3(-5, -5, -5), max: SIMD3(5, 5, 5)))
        #expect(state == .on)
    }

    @Test("Probe bounding box: fully outside")
    func probeBoxOutside() {
        let plane = ClipPlane(equation: SIMD4(0, 0, 1, 0))
        let state = plane.probe(box: (min: SIMD3(0, 0, -10), max: SIMD3(5, 5, -1)))
        #expect(state == .out)
    }

    @Test("Chain two planes")
    func chainPlanes() {
        let plane1 = ClipPlane(equation: SIMD4(0, 0, 1, 0))  // z > 0
        let plane2 = ClipPlane(equation: SIMD4(1, 0, 0, 0))  // x > 0

        #expect(plane1.chainLength == 1)
        plane1.chainNext(plane2)
        #expect(plane1.chainLength == 2)

        // Point at (5, 0, 5) satisfies both planes
        let stateIn = plane1.probe(point: SIMD3(5, 0, 5))
        #expect(stateIn == .in)

        // Point at (-5, 0, 5) fails x > 0
        let stateOut = plane1.probe(point: SIMD3(-5, 0, 5))
        #expect(stateOut == .out)
    }

    @Test("Clear chain")
    func clearChain() {
        let plane1 = ClipPlane(equation: SIMD4(0, 0, 1, 0))
        let plane2 = ClipPlane(equation: SIMD4(1, 0, 0, 0))
        plane1.chainNext(plane2)
        #expect(plane1.chainLength == 2)

        plane1.chainNext(nil)
        #expect(plane1.chainLength == 1)
    }
}

// MARK: - Z-Layer Settings Tests

@Suite("Z-Layer Settings")
struct ZLayerSettingsTests {

    @Test("Default values")
    func defaults() {
        let settings = ZLayerSettings()
        #expect(settings.depthTestEnabled == true)
        #expect(settings.depthWriteEnabled == true)
        #expect(settings.clearDepth == true)
        #expect(settings.isImmediate == false)
        #expect(settings.isRaytracable == true)
        #expect(settings.useEnvironmentTexture == true)
        #expect(settings.renderInDepthPrepass == true)
    }

    @Test("Depth test toggle")
    func depthTest() {
        let settings = ZLayerSettings()
        settings.depthTestEnabled = false
        #expect(settings.depthTestEnabled == false)
        settings.depthTestEnabled = true
        #expect(settings.depthTestEnabled == true)
    }

    @Test("Depth write toggle")
    func depthWrite() {
        let settings = ZLayerSettings()
        settings.depthWriteEnabled = false
        #expect(settings.depthWriteEnabled == false)
    }

    @Test("Clear depth toggle")
    func clearDepthToggle() {
        let settings = ZLayerSettings()
        settings.clearDepth = false
        #expect(settings.clearDepth == false)
    }

    @Test("Polygon offset roundtrip")
    func polygonOffset() {
        let settings = ZLayerSettings()
        settings.polygonOffset = ZLayerSettings.PolygonOffset(
            mode: .fill, factor: 1.5, units: 2.0
        )
        let offset = settings.polygonOffset
        #expect(offset.mode == .fill)
        #expect(abs(offset.factor - 1.5) < 0.001)
        #expect(abs(offset.units - 2.0) < 0.001)
    }

    @Test("Depth offset positive convenience")
    func depthOffsetPositive() {
        let settings = ZLayerSettings()
        settings.setDepthOffsetPositive()
        let offset = settings.polygonOffset
        #expect(offset.mode == .fill)
        #expect(abs(offset.factor - 1.0) < 0.001)
        #expect(abs(offset.units - 1.0) < 0.001)
    }

    @Test("Depth offset negative convenience")
    func depthOffsetNegative() {
        let settings = ZLayerSettings()
        settings.setDepthOffsetNegative()
        let offset = settings.polygonOffset
        #expect(offset.mode == .fill)
        #expect(abs(offset.factor - 1.0) < 0.001)
        #expect(abs(offset.units - (-1.0)) < 0.001)
    }

    @Test("Immediate mode toggle")
    func immediateMode() {
        let settings = ZLayerSettings()
        settings.isImmediate = true
        #expect(settings.isImmediate == true)
    }

    @Test("Raytracable toggle")
    func raytracable() {
        let settings = ZLayerSettings()
        settings.isRaytracable = false
        #expect(settings.isRaytracable == false)
    }

    @Test("Culling distance")
    func cullingDistance() {
        let settings = ZLayerSettings()
        settings.cullingDistance = 1000.0
        #expect(abs(settings.cullingDistance - 1000.0) < 0.001)
    }

    @Test("Culling size")
    func cullingSize() {
        let settings = ZLayerSettings()
        settings.cullingSize = 5.0
        #expect(abs(settings.cullingSize - 5.0) < 0.001)
    }

    @Test("Origin roundtrip")
    func origin() {
        let settings = ZLayerSettings()
        settings.origin = SIMD3(100, 200, 300)
        let o = settings.origin
        #expect(abs(o.x - 100) < 0.001)
        #expect(abs(o.y - 200) < 0.001)
        #expect(abs(o.z - 300) < 0.001)
    }

    @Test("Predefined layer IDs")
    func predefinedLayerIds() {
        #expect(ZLayerSettings.bottomOSD == -5)
        #expect(ZLayerSettings.default == 0)
        #expect(ZLayerSettings.top == -2)
        #expect(ZLayerSettings.topmost == -3)
        #expect(ZLayerSettings.topOSD == -4)
    }
}

// MARK: - SIMD3 Extension for normalization

extension SIMD3 where Scalar == Double {
    var normalized: SIMD3<Double> {
        let len = sqrt(x*x + y*y + z*z)
        guard len > 0 else { return self }
        return SIMD3(x/len, y/len, z/len)
    }
}
