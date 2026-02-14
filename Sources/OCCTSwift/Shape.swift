import Foundation
import simd
import OCCTBridge

/// A 3D solid shape backed by OpenCASCADE B-Rep geometry
public final class Shape: @unchecked Sendable {
    internal let handle: OCCTShapeRef

    internal init(handle: OCCTShapeRef) {
        self.handle = handle
    }

    deinit {
        OCCTShapeRelease(handle)
    }

    // MARK: - Primitive Creation

    /// Create a box centered at origin
    public static func box(width: Double, height: Double, depth: Double) -> Shape? {
        guard let handle = OCCTShapeCreateBox(width, height, depth) else { return nil }
        return Shape(handle: handle)
    }

    /// Create a box at a specific position
    public static func box(
        origin: SIMD3<Double>,
        width: Double,
        height: Double,
        depth: Double
    ) -> Shape? {
        guard let handle = OCCTShapeCreateBoxAt(
            origin.x, origin.y, origin.z,
            width, height, depth
        ) else { return nil }
        return Shape(handle: handle)
    }

    /// Create a cylinder along Z axis
    public static func cylinder(radius: Double, height: Double) -> Shape? {
        guard let handle = OCCTShapeCreateCylinder(radius, height) else { return nil }
        return Shape(handle: handle)
    }

    /// Create a cylinder at a specific XY position with bottom at specified Z
    public static func cylinder(
        at position: SIMD2<Double>,
        bottomZ: Double,
        radius: Double,
        height: Double
    ) -> Shape? {
        guard let handle = OCCTShapeCreateCylinderAt(position.x, position.y, bottomZ, radius, height) else { return nil }
        return Shape(handle: handle)
    }

    /// Create a tool sweep solid - the volume swept by a cylindrical tool moving between two points
    /// Used for CAM simulation to calculate material removal
    public static func toolSweep(
        radius: Double,
        height: Double,
        from start: SIMD3<Double>,
        to end: SIMD3<Double>
    ) -> Shape? {
        guard let handle = OCCTShapeCreateToolSweep(
            radius, height,
            start.x, start.y, start.z,
            end.x, end.y, end.z
        ) else { return nil }
        return Shape(handle: handle)
    }

    /// Create a sphere centered at origin
    public static func sphere(radius: Double) -> Shape? {
        guard let handle = OCCTShapeCreateSphere(radius) else { return nil }
        return Shape(handle: handle)
    }

    /// Create a cone along Z axis
    public static func cone(bottomRadius: Double, topRadius: Double, height: Double) -> Shape? {
        guard let handle = OCCTShapeCreateCone(bottomRadius, topRadius, height) else { return nil }
        return Shape(handle: handle)
    }

    /// Create a torus in XY plane
    public static func torus(majorRadius: Double, minorRadius: Double) -> Shape? {
        guard let handle = OCCTShapeCreateTorus(majorRadius, minorRadius) else { return nil }
        return Shape(handle: handle)
    }

    // MARK: - Sweep Operations

    /// Sweep a 2D profile along a path to create a solid
    public static func sweep(profile: Wire, along path: Wire) -> Shape? {
        guard let handle = OCCTShapeCreatePipeSweep(profile.handle, path.handle) else { return nil }
        return Shape(handle: handle)
    }

    /// Extrude a 2D profile in a direction
    public static func extrude(profile: Wire, direction: SIMD3<Double>, length: Double) -> Shape? {
        guard let handle = OCCTShapeCreateExtrusion(
            profile.handle,
            direction.x, direction.y, direction.z,
            length
        ) else { return nil }
        return Shape(handle: handle)
    }

    /// Revolve a 2D profile around an axis
    public static func revolve(
        profile: Wire,
        axisOrigin: SIMD3<Double>,
        axisDirection: SIMD3<Double>,
        angle: Double = .pi * 2
    ) -> Shape? {
        guard let handle = OCCTShapeCreateRevolution(
            profile.handle,
            axisOrigin.x, axisOrigin.y, axisOrigin.z,
            axisDirection.x, axisDirection.y, axisDirection.z,
            angle
        ) else { return nil }
        return Shape(handle: handle)
    }

    /// Loft through multiple profile wires
    public static func loft(profiles: [Wire], solid: Bool = true) -> Shape? {
        let handles: [OCCTWireRef?] = profiles.map { $0.handle }
        guard let handle = handles.withUnsafeBufferPointer({ buffer in
            OCCTShapeCreateLoft(buffer.baseAddress, Int32(profiles.count), solid)
        }) else { return nil }
        return Shape(handle: handle)
    }

    // MARK: - Boolean Operations

    /// Union (add) two shapes together
    public func union(with other: Shape) -> Shape? {
        guard let handle = OCCTShapeUnion(self.handle, other.handle) else { return nil }
        return Shape(handle: handle)
    }

    /// Subtract another shape from this one
    public func subtracting(_ other: Shape) -> Shape? {
        guard let handle = OCCTShapeSubtract(self.handle, other.handle) else { return nil }
        return Shape(handle: handle)
    }

    /// Intersection of two shapes
    public func intersection(with other: Shape) -> Shape? {
        guard let handle = OCCTShapeIntersect(self.handle, other.handle) else { return nil }
        return Shape(handle: handle)
    }

    // MARK: - Modifications

    /// Fillet (round) all edges with given radius
    public func filleted(radius: Double) -> Shape? {
        guard let handle = OCCTShapeFillet(self.handle, radius) else { return nil }
        return Shape(handle: handle)
    }

    /// Chamfer all edges with given distance
    public func chamfered(distance: Double) -> Shape? {
        guard let handle = OCCTShapeChamfer(self.handle, distance) else { return nil }
        return Shape(handle: handle)
    }

    /// Create a hollow shell by removing material from inside
    public func shelled(thickness: Double) -> Shape? {
        guard let handle = OCCTShapeShell(self.handle, thickness) else { return nil }
        return Shape(handle: handle)
    }

    /// Offset all faces by a distance (positive = outward)
    public func offset(by distance: Double) -> Shape? {
        guard let handle = OCCTShapeOffset(self.handle, distance) else { return nil }
        return Shape(handle: handle)
    }

    // MARK: - Transformations

    /// Translate the shape
    public func translated(by offset: SIMD3<Double>) -> Shape? {
        guard let handle = OCCTShapeTranslate(self.handle, offset.x, offset.y, offset.z) else { return nil }
        return Shape(handle: handle)
    }

    /// Rotate around an axis through origin
    public func rotated(axis: SIMD3<Double>, angle: Double) -> Shape? {
        guard let handle = OCCTShapeRotate(self.handle, axis.x, axis.y, axis.z, angle) else { return nil }
        return Shape(handle: handle)
    }

    /// Scale uniformly from origin
    public func scaled(by factor: Double) -> Shape? {
        guard let handle = OCCTShapeScale(self.handle, factor) else { return nil }
        return Shape(handle: handle)
    }

    /// Mirror across a plane
    public func mirrored(planeNormal: SIMD3<Double>, planeOrigin: SIMD3<Double> = .zero) -> Shape? {
        guard let handle = OCCTShapeMirror(
            self.handle,
            planeOrigin.x, planeOrigin.y, planeOrigin.z,
            planeNormal.x, planeNormal.y, planeNormal.z
        ) else { return nil }
        return Shape(handle: handle)
    }

    // MARK: - Compound Operations

    /// Combine multiple shapes into a compound (no boolean, just grouping)
    public static func compound(_ shapes: [Shape]) -> Shape? {
        let handles: [OCCTShapeRef?] = shapes.map { $0.handle }
        guard let handle = handles.withUnsafeBufferPointer({ buffer in
            OCCTShapeCreateCompound(buffer.baseAddress, Int32(shapes.count))
        }) else { return nil }
        return Shape(handle: handle)
    }

    // MARK: - Conversion

    /// Wrap a Wire as a Shape to access edge extraction and other Shape methods.
    ///
    /// Since `TopoDS_Wire` inherits from `TopoDS_Shape` in OCCT, this is a
    /// lightweight conversion that enables using Shape methods like
    /// `allEdgePolylines()` on wire geometry without creating solid geometry.
    ///
    /// - Parameter wire: The wire to wrap.
    /// - Returns: A Shape wrapping the wire, or `nil` on failure.
    public static func fromWire(_ wire: Wire) -> Shape? {
        guard let handle = OCCTShapeFromWire(wire.handle) else { return nil }
        return Shape(handle: handle)
    }

    // MARK: - Validation

    /// Check if shape is valid
    public var isValid: Bool {
        OCCTShapeIsValid(handle)
    }

    /// Attempt to repair/heal the shape
    public func healed() -> Shape? {
        guard let handle = OCCTShapeHeal(self.handle) else { return nil }
        return Shape(handle: handle)
    }

    // MARK: - Meshing

    /// Generate a triangulated mesh for visualization
    public func mesh(
        linearDeflection: Double = 0.1,
        angularDeflection: Double = 0.5
    ) -> Mesh? {
        guard let meshHandle = OCCTShapeCreateMesh(handle, linearDeflection, angularDeflection) else { return nil }
        return Mesh(handle: meshHandle)
    }

    /// Generate a triangulated mesh with enhanced parameters.
    ///
    /// This method provides fine-grained control over tessellation quality,
    /// useful for CAM toolpath generation or high-quality visualization.
    ///
    /// ```swift
    /// var params = MeshParameters.default
    /// params.deflection = 0.02  // Very fine mesh
    /// params.inParallel = true  // Multi-threaded
    /// let mesh = shape.mesh(parameters: params)
    /// ```
    ///
    /// - Parameter parameters: Enhanced mesh parameters
    /// - Returns: A `Mesh` with the specified quality settings
    public func mesh(parameters: MeshParameters) -> Mesh? {
        let bridgeParams = parameters.toBridge()
        guard let meshHandle = OCCTShapeCreateMeshWithParams(handle, bridgeParams) else { return nil }
        return Mesh(handle: meshHandle)
    }

    // MARK: - Edge Discretization

    /// Get a discretized edge as a polyline.
    ///
    /// This method adaptively samples points along a B-Rep edge using
    /// curvature-based deflection control. Useful for:
    /// - Contour toolpath generation
    /// - Edge visualization
    /// - G-code generation from curve edges
    ///
    /// - Parameters:
    ///   - index: Edge index (0-based)
    ///   - deflection: Maximum chord deviation
    ///   - maxPoints: Maximum number of points to return
    /// - Returns: Array of 3D points along the edge, or nil if edge not found
    public func edgePolyline(
        at index: Int,
        deflection: Double = 0.1,
        maxPoints: Int = 1000
    ) -> [SIMD3<Double>]? {
        var points = [Double](repeating: 0, count: maxPoints * 3)
        let numPoints = points.withUnsafeMutableBufferPointer { buffer in
            OCCTShapeGetEdgePolyline(handle, Int32(index), deflection, buffer.baseAddress, Int32(maxPoints))
        }

        guard numPoints > 0 else { return nil }

        var result: [SIMD3<Double>] = []
        result.reserveCapacity(Int(numPoints))

        for i in 0..<Int(numPoints) {
            result.append(SIMD3(
                points[i * 3],
                points[i * 3 + 1],
                points[i * 3 + 2]
            ))
        }

        return result
    }

    /// Get all edges as discretized polylines.
    ///
    /// Convenience method that calls `edgePolyline` for each edge in the shape.
    ///
    /// - Parameters:
    ///   - deflection: Maximum chord deviation
    ///   - maxPointsPerEdge: Maximum points per edge
    /// - Returns: Array of polylines, one per edge
    public func allEdgePolylines(
        deflection: Double = 0.1,
        maxPointsPerEdge: Int = 1000
    ) -> [[SIMD3<Double>]] {
        // Get edge count directly from C API
        let count = Int(OCCTShapeGetTotalEdgeCount(handle))
        var result: [[SIMD3<Double>]] = []
        result.reserveCapacity(count)

        for i in 0..<count {
            if let polyline = edgePolyline(at: i, deflection: deflection, maxPoints: maxPointsPerEdge) {
                result.append(polyline)
            }
        }

        return result
    }

    // MARK: - Import

    /// Load a shape from a STEP file
    public static func load(from url: URL) throws -> Shape {
        let path = url.path
        guard let handle = OCCTImportSTEP(path) else {
            throw ImportError.importFailed("Failed to import STEP file: \(url.lastPathComponent)")
        }
        return Shape(handle: handle)
    }

    /// Load a shape from a STEP file path
    public static func load(fromPath path: String) throws -> Shape {
        guard let handle = OCCTImportSTEP(path) else {
            throw ImportError.importFailed("Failed to import STEP file: \(path)")
        }
        return Shape(handle: handle)
    }

    // MARK: - Robust STEP Import

    /// Load a STEP file with robust handling: sewing, solid creation, and shape healing.
    ///
    /// This method is recommended for STEP files that may contain:
    /// - Disconnected faces that need sewing
    /// - Shells that need conversion to solids
    /// - Geometry issues that require healing
    ///
    /// - Parameter url: URL to the STEP file
    /// - Returns: Processed shape suitable for CAM operations
    /// - Throws: ImportError if import fails
    public static func loadRobust(from url: URL) throws -> Shape {
        guard let handle = OCCTImportSTEPRobust(url.path) else {
            throw ImportError.importFailed("Failed to import: \(url.lastPathComponent)")
        }
        return Shape(handle: handle)
    }

    /// Load a STEP file with robust handling: sewing, solid creation, and shape healing.
    ///
    /// - Parameter path: Path to the STEP file
    /// - Returns: Processed shape suitable for CAM operations
    /// - Throws: ImportError if import fails
    public static func loadRobust(fromPath path: String) throws -> Shape {
        guard let handle = OCCTImportSTEPRobust(path) else {
            throw ImportError.importFailed("Failed to import: \(path)")
        }
        return Shape(handle: handle)
    }

    /// Load a STEP file with diagnostic information about processing steps.
    ///
    /// Use this when you need to understand what processing was applied to the imported geometry.
    ///
    /// - Parameter url: URL to the STEP file
    /// - Returns: Import result containing the shape and processing information
    /// - Throws: ImportError if import fails
    ///
    /// ## Example
    ///
    /// ```swift
    /// let result = try Shape.loadWithDiagnostics(from: stepFile)
    /// print(result.summary)  // "Shell → Solid (processing: sewing, solid creation, healing)"
    /// let shape = result.shape
    /// ```
    public static func loadWithDiagnostics(from url: URL) throws -> ImportResult {
        let result = OCCTImportSTEPWithDiagnostics(url.path)
        guard let handle = result.shape else {
            throw ImportError.importFailed("Failed to import: \(url.lastPathComponent)")
        }
        return ImportResult(
            shape: Shape(handle: handle),
            originalType: ShapeType(rawValue: Int(result.originalType)) ?? .unknown,
            resultType: ShapeType(rawValue: Int(result.resultType)) ?? .unknown,
            sewingApplied: result.sewingApplied,
            solidCreated: result.solidCreated,
            healingApplied: result.healingApplied
        )
    }

    // MARK: - IGES Import (v0.10.0)

    /// Load a shape from an IGES file
    ///
    /// IGES (Initial Graphics Exchange Specification) is a legacy CAD format
    /// still commonly used in manufacturing and older CAD systems.
    ///
    /// - Parameter url: URL to the IGES file (.igs or .iges)
    /// - Returns: Imported shape
    /// - Throws: ImportError if import fails
    public static func loadIGES(from url: URL) throws -> Shape {
        guard let handle = OCCTImportIGES(url.path) else {
            throw ImportError.importFailed("Failed to import IGES file: \(url.lastPathComponent)")
        }
        return Shape(handle: handle)
    }

    /// Load a shape from an IGES file path
    public static func loadIGES(fromPath path: String) throws -> Shape {
        guard let handle = OCCTImportIGES(path) else {
            throw ImportError.importFailed("Failed to import IGES file: \(path)")
        }
        return Shape(handle: handle)
    }

    /// Load an IGES file with automatic repair (sewing and healing)
    ///
    /// - Parameter url: URL to the IGES file
    /// - Returns: Processed shape with healing applied
    /// - Throws: ImportError if import fails
    public static func loadIGESRobust(from url: URL) throws -> Shape {
        guard let handle = OCCTImportIGESRobust(url.path) else {
            throw ImportError.importFailed("Failed to import IGES file: \(url.lastPathComponent)")
        }
        return Shape(handle: handle)
    }

    // MARK: - BREP Import (v0.10.0)

    /// Load a shape from OCCT's native BREP format
    ///
    /// BREP is OCCT's native format for exact B-Rep geometry. It preserves
    /// the full precision of the geometry and is useful for:
    /// - Fast caching of intermediate results
    /// - Debugging geometry issues
    /// - Archiving exact geometry
    ///
    /// - Parameter url: URL to the BREP file (.brep)
    /// - Returns: Imported shape
    /// - Throws: ImportError if import fails
    public static func loadBREP(from url: URL) throws -> Shape {
        guard let handle = OCCTImportBREP(url.path) else {
            throw ImportError.importFailed("Failed to import BREP file: \(url.lastPathComponent)")
        }
        return Shape(handle: handle)
    }

    /// Load a shape from a BREP file path
    public static func loadBREP(fromPath path: String) throws -> Shape {
        guard let handle = OCCTImportBREP(path) else {
            throw ImportError.importFailed("Failed to import BREP file: \(path)")
        }
        return Shape(handle: handle)
    }

    // MARK: - STL Import (v0.17.0)

    /// Load a shape from an STL file
    ///
    /// - Parameter url: URL to the STL file (.stl)
    /// - Returns: Imported shape
    /// - Throws: ImportError if import fails
    public static func loadSTL(from url: URL) throws -> Shape {
        guard let handle = OCCTImportSTL(url.path) else {
            throw ImportError.importFailed("Failed to import STL file: \(url.lastPathComponent)")
        }
        return Shape(handle: handle)
    }

    /// Load a shape from an STL file path
    public static func loadSTL(fromPath path: String) throws -> Shape {
        guard let handle = OCCTImportSTL(path) else {
            throw ImportError.importFailed("Failed to import STL file: \(path)")
        }
        return Shape(handle: handle)
    }

    /// Load an STL file with robust healing (sew + solid creation + heal)
    ///
    /// - Parameters:
    ///   - url: URL to the STL file
    ///   - sewingTolerance: Tolerance for sewing disconnected faces (default: 1e-6)
    /// - Returns: Processed shape suitable for solid operations
    /// - Throws: ImportError if import fails
    public static func loadSTLRobust(from url: URL, sewingTolerance: Double = 1e-6) throws -> Shape {
        guard let handle = OCCTImportSTLRobust(url.path, sewingTolerance) else {
            throw ImportError.importFailed("Failed to import STL file: \(url.lastPathComponent)")
        }
        return Shape(handle: handle)
    }

    /// Load an STL file with robust healing from a path
    public static func loadSTLRobust(fromPath path: String, sewingTolerance: Double = 1e-6) throws -> Shape {
        guard let handle = OCCTImportSTLRobust(path, sewingTolerance) else {
            throw ImportError.importFailed("Failed to import STL file: \(path)")
        }
        return Shape(handle: handle)
    }

    // MARK: - OBJ Import (v0.17.0)

    /// Load a shape from an OBJ file
    ///
    /// - Parameter url: URL to the OBJ file (.obj)
    /// - Returns: Imported shape
    /// - Throws: ImportError if import fails
    public static func loadOBJ(from url: URL) throws -> Shape {
        guard let handle = OCCTImportOBJ(url.path) else {
            throw ImportError.importFailed("Failed to import OBJ file: \(url.lastPathComponent)")
        }
        return Shape(handle: handle)
    }

    /// Load a shape from an OBJ file path
    public static func loadOBJ(fromPath path: String) throws -> Shape {
        guard let handle = OCCTImportOBJ(path) else {
            throw ImportError.importFailed("Failed to import OBJ file: \(path)")
        }
        return Shape(handle: handle)
    }

    // MARK: - Geometry Construction (v0.11.0)

    /// Create a planar face from a closed wire
    ///
    /// - Parameters:
    ///   - wire: A closed wire defining the face boundary
    ///   - planar: If true, requires the wire to be planar (default: true)
    ///
    /// - Returns: A face shape, or nil if creation fails
    ///
    /// ## Example
    ///
    /// ```swift
    /// let rect = Wire.rectangle(width: 10, height: 5)!
    /// let face = Shape.face(from: rect)!
    /// let box = face.extruded(direction: [0, 0, 1], length: 3)
    /// ```
    public static func face(from wire: Wire, planar: Bool = true) -> Shape? {
        guard let handle = OCCTShapeCreateFaceFromWire(wire.handle, planar) else {
            return nil
        }
        return Shape(handle: handle)
    }

    /// Create a face with holes from outer and inner wires
    ///
    /// - Parameters:
    ///   - outer: The outer boundary wire (closed)
    ///   - holes: Array of inner boundary wires defining holes
    ///
    /// - Returns: A face with holes, or nil if creation fails
    ///
    /// ## Example
    ///
    /// ```swift
    /// let outer = Wire.rectangle(width: 20, height: 20)!
    /// let hole1 = Wire.circle(radius: 3)!.translated(x: -5, y: 0, z: 0)
    /// let hole2 = Wire.circle(radius: 3)!.translated(x: 5, y: 0, z: 0)
    /// let face = Shape.face(outer: outer, holes: [hole1, hole2])!
    /// ```
    public static func face(outer: Wire, holes: [Wire]) -> Shape? {
        var holeHandles = holes.map { $0.handle as OCCTWireRef? }
        guard let handle = holeHandles.withUnsafeMutableBufferPointer({ buffer in
            OCCTShapeCreateFaceWithHoles(outer.handle, buffer.baseAddress, Int32(holes.count))
        }) else {
            return nil
        }
        return Shape(handle: handle)
    }

    /// Create a solid from a closed shell
    ///
    /// Converts a shell (set of connected faces) into a solid. The shell
    /// must be closed (no gaps) for this to succeed.
    ///
    /// - Parameter shell: A shell shape (typically from sewing operations)
    /// - Returns: A solid shape, or nil if the shell is not closed
    ///
    /// ## Example
    ///
    /// ```swift
    /// let sewn = Shape.sew(faces: faces, tolerance: 1e-6)!
    /// let solid = Shape.solid(from: sewn)!
    /// ```
    public static func solid(from shell: Shape) -> Shape? {
        guard let handle = OCCTShapeCreateSolidFromShell(shell.handle) else {
            return nil
        }
        return Shape(handle: handle)
    }

    /// Sew multiple shapes into a connected shell or solid
    ///
    /// Sewing connects faces that share edges within the tolerance. This is
    /// useful for repairing imported geometry or combining separately created faces.
    ///
    /// - Parameters:
    ///   - shapes: Array of shapes (faces, shells) to sew together
    ///   - tolerance: Maximum gap size to close (default: 1e-6)
    ///
    /// - Returns: Sewn shape (shell or solid if closed), or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Create faces manually and sew into solid
    /// let faces = [topFace, bottomFace, frontFace, backFace, leftFace, rightFace]
    /// let solid = Shape.sew(shapes: faces, tolerance: 0.01)!
    /// ```
    public static func sew(shapes: [Shape], tolerance: Double = 1e-6) -> Shape? {
        guard !shapes.isEmpty else { return nil }

        var shapeHandles = shapes.map { $0.handle as OCCTShapeRef? }
        guard let handle = shapeHandles.withUnsafeMutableBufferPointer({ buffer in
            OCCTShapeSew(buffer.baseAddress, Int32(shapes.count), tolerance)
        }) else {
            return nil
        }
        return Shape(handle: handle)
    }

    /// Sew two shapes together
    ///
    /// - Parameters:
    ///   - shape: First shape to sew
    ///   - other: Second shape to sew
    ///   - tolerance: Maximum gap size to close (default: 1e-6)
    ///
    /// - Returns: Sewn shape, or nil on failure
    public static func sew(_ shape: Shape, with other: Shape, tolerance: Double = 1e-6) -> Shape? {
        guard let handle = OCCTShapeSewTwo(shape.handle, other.handle, tolerance) else {
            return nil
        }
        return Shape(handle: handle)
    }

    /// Sew this shape with another
    ///
    /// - Parameters:
    ///   - other: Shape to sew with
    ///   - tolerance: Maximum gap size to close (default: 1e-6)
    ///
    /// - Returns: Sewn shape, or nil on failure
    public func sewn(with other: Shape, tolerance: Double = 1e-6) -> Shape? {
        Shape.sew(self, with: other, tolerance: tolerance)
    }

    // MARK: - Feature-Based Modeling (v0.12.0)

    /// Add a prismatic boss or pocket to the shape
    ///
    /// - Parameters:
    ///   - profile: Wire profile to extrude (should be on a face of this shape)
    ///   - direction: Extrusion direction
    ///   - height: Extrusion height
    ///   - fuse: If true, adds material (boss); if false, removes material (pocket)
    ///
    /// - Returns: Modified shape, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// let box = Shape.box(width: 50, height: 50, depth: 10)
    /// let bossProfile = Wire.circle(radius: 5)!.offset3D(distance: 25, direction: SIMD3(0, 0, 1))!
    /// let withBoss = box.withPrism(profile: bossProfile, direction: SIMD3(0, 0, 1), height: 5, fuse: true)
    /// ```
    public func withPrism(profile: Wire, direction: SIMD3<Double>, height: Double, fuse: Bool) -> Shape? {
        guard let handle = OCCTShapePrism(self.handle, profile.handle,
                                          direction.x, direction.y, direction.z,
                                          height, fuse) else {
            return nil
        }
        return Shape(handle: handle)
    }

    /// Add a boss (raised feature) to the shape
    ///
    /// - Parameters:
    ///   - profile: Wire profile to extrude
    ///   - direction: Extrusion direction
    ///   - height: Boss height
    ///
    /// - Returns: Shape with added boss, or nil on failure
    public func withBoss(profile: Wire, direction: SIMD3<Double>, height: Double) -> Shape? {
        withPrism(profile: profile, direction: direction, height: height, fuse: true)
    }

    /// Create a pocket (depression) in the shape
    ///
    /// - Parameters:
    ///   - profile: Wire profile defining the pocket boundary
    ///   - direction: Pocket direction (into the shape)
    ///   - depth: Pocket depth
    ///
    /// - Returns: Shape with pocket, or nil on failure
    public func withPocket(profile: Wire, direction: SIMD3<Double>, depth: Double) -> Shape? {
        withPrism(profile: profile, direction: direction, height: depth, fuse: false)
    }

    /// Drill a cylindrical hole into the shape
    ///
    /// - Parameters:
    ///   - position: Position of hole center on surface
    ///   - direction: Drill direction (into the shape)
    ///   - radius: Hole radius
    ///   - depth: Hole depth (0 for through-hole)
    ///
    /// - Returns: Shape with drilled hole, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// let plate = Shape.box(width: 50, height: 50, depth: 10)
    /// let drilled = plate.drilled(at: SIMD3(25, 25, 10), direction: SIMD3(0, 0, -1), radius: 5, depth: 0)
    /// ```
    public func drilled(at position: SIMD3<Double>, direction: SIMD3<Double>, radius: Double, depth: Double = 0) -> Shape? {
        guard let handle = OCCTShapeDrillHole(self.handle,
                                              position.x, position.y, position.z,
                                              direction.x, direction.y, direction.z,
                                              radius, depth) else {
            return nil
        }
        return Shape(handle: handle)
    }

    /// Split the shape using a cutting tool
    ///
    /// - Parameter tool: Shape to use as cutting tool
    /// - Returns: Array of resulting shapes after split, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// let box = Shape.box(width: 20, height: 20, depth: 20)
    /// let cuttingPlane = Shape.face(from: Wire.rectangle(width: 40, height: 40)!)!
    /// let halves = box.split(by: cuttingPlane.translated(by: SIMD3(0, 0, 10)))
    /// ```
    public func split(by tool: Shape) -> [Shape]? {
        var count: Int32 = 0
        guard let shapesPtr = OCCTShapeSplit(self.handle, tool.handle, &count),
              count > 0 else {
            return nil
        }

        var shapes: [Shape] = []
        for i in 0..<Int(count) {
            if let shapeHandle = shapesPtr[i] {
                shapes.append(Shape(handle: shapeHandle))
            }
        }

        // Free only the array, not the shapes (we've taken ownership)
        OCCTFreeShapeArrayOnly(shapesPtr)

        return shapes.isEmpty ? nil : shapes
    }

    /// Split the shape by a plane
    ///
    /// - Parameters:
    ///   - point: A point on the cutting plane
    ///   - normal: Normal vector of the cutting plane
    ///
    /// - Returns: Array of resulting shapes after split, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// let cube = Shape.box(width: 20, height: 20, depth: 20)
    /// // Split horizontally at Z=10
    /// let halves = cube.split(atPlane: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1))
    /// ```
    public func split(atPlane point: SIMD3<Double>, normal: SIMD3<Double>) -> [Shape]? {
        var count: Int32 = 0
        guard let shapesPtr = OCCTShapeSplitByPlane(self.handle,
                                                     point.x, point.y, point.z,
                                                     normal.x, normal.y, normal.z,
                                                     &count),
              count > 0 else {
            return nil
        }

        var shapes: [Shape] = []
        for i in 0..<Int(count) {
            if let shapeHandle = shapesPtr[i] {
                shapes.append(Shape(handle: shapeHandle))
            }
        }

        OCCTFreeShapeArrayOnly(shapesPtr)

        return shapes.isEmpty ? nil : shapes
    }

    /// Glue two shapes together at coincident faces
    ///
    /// More efficient than boolean union when shapes have faces that perfectly align.
    ///
    /// - Parameters:
    ///   - shape1: First shape
    ///   - shape2: Second shape with coincident faces
    ///   - tolerance: Tolerance for face matching (default: 1e-6)
    ///
    /// - Returns: Glued shape, or nil on failure
    public static func glue(_ shape1: Shape, _ shape2: Shape, tolerance: Double = 1e-6) -> Shape? {
        guard let handle = OCCTShapeGlue(shape1.handle, shape2.handle, tolerance) else {
            return nil
        }
        return Shape(handle: handle)
    }

    /// Create an evolved shape (profile swept along spine with rotation)
    ///
    /// The profile is swept along the spine, with its orientation evolving
    /// to stay perpendicular to the spine.
    ///
    /// - Parameters:
    ///   - spine: Path wire to sweep along
    ///   - profile: Profile wire to sweep
    ///
    /// - Returns: Evolved shape, or nil on failure
    public static func evolved(spine: Wire, profile: Wire) -> Shape? {
        guard let handle = OCCTShapeCreateEvolved(spine.handle, profile.handle) else {
            return nil
        }
        return Shape(handle: handle)
    }

    /// Create a linear pattern of the shape
    ///
    /// - Parameters:
    ///   - direction: Direction of the pattern
    ///   - spacing: Distance between copies
    ///   - count: Number of copies (including original)
    ///
    /// - Returns: Compound containing all copies, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// let hole = Shape.cylinder(radius: 3, height: 10)
    /// let rowOfHoles = hole.linearPattern(direction: SIMD3(20, 0, 0), spacing: 20, count: 5)
    /// ```
    public func linearPattern(direction: SIMD3<Double>, spacing: Double, count: Int) -> Shape? {
        guard let handle = OCCTShapeLinearPattern(self.handle,
                                                   direction.x, direction.y, direction.z,
                                                   spacing, Int32(count)) else {
            return nil
        }
        return Shape(handle: handle)
    }

    /// Create a circular pattern of the shape
    ///
    /// - Parameters:
    ///   - axisPoint: Point on the rotation axis
    ///   - axisDirection: Direction of the rotation axis
    ///   - count: Number of copies (including original)
    ///   - angle: Total angle to span in radians (0 for full circle)
    ///
    /// - Returns: Compound containing all copies, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// let hole = Shape.cylinder(radius: 3, height: 10).translated(by: SIMD3(20, 0, 0))
    /// // Create 6 holes in a circle around the Z axis
    /// let boltPattern = hole.circularPattern(
    ///     axisPoint: .zero,
    ///     axisDirection: SIMD3(0, 0, 1),
    ///     count: 6,
    ///     angle: 0  // Full circle
    /// )
    /// ```
    public func circularPattern(axisPoint: SIMD3<Double>, axisDirection: SIMD3<Double>, count: Int, angle: Double = 0) -> Shape? {
        guard let handle = OCCTShapeCircularPattern(self.handle,
                                                     axisPoint.x, axisPoint.y, axisPoint.z,
                                                     axisDirection.x, axisDirection.y, axisDirection.z,
                                                     Int32(count), angle) else {
            return nil
        }
        return Shape(handle: handle)
    }

    // MARK: - Shape Type

    /// The topological type of the shape
    public var shapeType: ShapeType {
        ShapeType(rawValue: Int(OCCTShapeGetType(handle))) ?? .unknown
    }

    /// Whether the shape is a valid closed solid suitable for CAM operations
    public var isValidSolid: Bool {
        OCCTShapeIsValidSolid(handle)
    }

    // MARK: - Bounds

    /// Get the axis-aligned bounding box of the shape
    public var bounds: (min: SIMD3<Double>, max: SIMD3<Double>) {
        var minX: Double = 0, minY: Double = 0, minZ: Double = 0
        var maxX: Double = 0, maxY: Double = 0, maxZ: Double = 0
        OCCTShapeGetBounds(handle, &minX, &minY, &minZ, &maxX, &maxY, &maxZ)
        return (min: SIMD3(minX, minY, minZ), max: SIMD3(maxX, maxY, maxZ))
    }

    /// Size of the bounding box
    public var size: SIMD3<Double> {
        let b = bounds
        return b.max - b.min
    }

    /// Center of the bounding box
    public var center: SIMD3<Double> {
        let b = bounds
        return (b.min + b.max) / 2
    }

    // MARK: - Slicing

    /// Slice the shape at a given Z height, returning the cross-section as edges
    public func sliceAtZ(_ z: Double) -> Shape? {
        guard let handle = OCCTShapeSliceAtZ(self.handle, z) else {
            return nil
        }
        return Shape(handle: handle)
    }

    /// Get closed wires from a section at Z level.
    ///
    /// This is useful for CAM operations where you need to work with closed contours
    /// that can be offset for tool compensation.
    ///
    /// - Parameters:
    ///   - z: The Z level to section at
    ///   - tolerance: Tolerance for connecting edges into wires. Use larger values
    ///                (e.g., 1e-4) for imprecise geometry. Default is 1e-6.
    /// - Returns: Array of closed wires representing contours at that Z level.
    ///            Returns empty array if no contours exist at that level.
    ///
    /// Unlike `sliceAtZ(_:)` which returns a shape with loose edges, this method
    /// chains the edges into closed wires that can be used with `Wire.offset(by:)`.
    ///
    /// ## Example: CAM Safety Boundary
    ///
    /// ```swift
    /// let model = try Shape.load(from: stepFile)
    ///
    /// // Get model contour at Z = 5.0
    /// let wires = model.sectionWiresAtZ(5.0)
    ///
    /// for contour in wires {
    ///     // Offset outward by tool radius + stock allowance
    ///     if let safetyBoundary = contour.offset(by: toolRadius + stockAllowance) {
    ///         // Tool center must stay outside this boundary
    ///     }
    /// }
    /// ```
    public func sectionWiresAtZ(_ z: Double, tolerance: Double = 1e-6) -> [Wire] {
        var count: Int32 = 0
        guard let wireArray = OCCTShapeSectionWiresAtZ(handle, z, tolerance, &count) else {
            return []
        }
        // Use OCCTFreeWireArrayOnly - Swift Wire objects now own the wire handles
        // and will release them in their deinit. We only need to free the array container.
        defer { OCCTFreeWireArrayOnly(wireArray) }

        var wires: [Wire] = []
        for i in 0..<Int(count) {
            if let wireHandle = wireArray[i] {
                wires.append(Wire(handle: wireHandle))
            }
        }
        return wires
    }

    /// Get points along an edge at the given index.
    ///
    /// Points are sampled uniformly along the edge curve from start to end.
    /// - Parameter index: The edge index (0 to edgeCount-1)
    /// - Parameter maxPoints: Maximum points to return (capped at 20 internally for performance)
    /// - Returns: Array of 3D points along the edge curve
    public func edgePoints(at index: Int, maxPoints: Int = 20) -> [SIMD3<Double>] {
        var buffer = [Double](repeating: 0, count: maxPoints * 3)
        let count = OCCTShapeGetEdgePoints(handle, Int32(index), &buffer, Int32(maxPoints))
        var points: [SIMD3<Double>] = []
        for i in 0..<Int(count) {
            points.append(SIMD3(buffer[i*3], buffer[i*3+1], buffer[i*3+2]))
        }
        return points
    }

    /// Get all contour points from the shape's edges.
    ///
    /// Note: This returns edge START vertices only, not intermediate curve points.
    /// For curved edges, use `edgePoints(at:maxPoints:)` to get curve samples.
    /// This is suitable for simple polygon contours from Z-plane slices.
    ///
    /// - Parameter maxPoints: Maximum number of points to return
    /// - Returns: Array of 3D points (one per edge start vertex)
    public func contourPoints(maxPoints: Int = 1000) -> [SIMD3<Double>] {
        var buffer = [Double](repeating: 0, count: maxPoints * 3)
        let count = OCCTShapeGetContourPoints(handle, &buffer, Int32(maxPoints))
        var points: [SIMD3<Double>] = []
        for i in 0..<Int(count) {
            points.append(SIMD3(buffer[i*3], buffer[i*3+1], buffer[i*3+2]))
        }
        return points
    }
}

// MARK: - Errors

public enum ImportError: Error, LocalizedError {
    case importFailed(String)

    public var errorDescription: String? {
        switch self {
        case .importFailed(let message):
            return message
        }
    }
}

// MARK: - Shape Type

/// Topological type of a shape (matches OCCT TopAbs_ShapeEnum)
public enum ShapeType: Int, CustomStringConvertible, Sendable {
    case compound = 0
    case compSolid = 1
    case solid = 2
    case shell = 3
    case face = 4
    case wire = 5
    case edge = 6
    case vertex = 7
    case unknown = -1

    public var description: String {
        switch self {
        case .compound: return "Compound"
        case .compSolid: return "CompSolid"
        case .solid: return "Solid"
        case .shell: return "Shell"
        case .face: return "Face"
        case .wire: return "Wire"
        case .edge: return "Edge"
        case .vertex: return "Vertex"
        case .unknown: return "Unknown"
        }
    }
}

// MARK: - Import Result

/// Result of a robust STEP import with diagnostic information
public struct ImportResult: Sendable {
    /// The imported and processed shape
    public let shape: Shape

    /// Original shape type as read from STEP file
    public let originalType: ShapeType

    /// Final shape type after processing
    public let resultType: ShapeType

    /// Whether sewing was applied to connect disconnected faces
    public let sewingApplied: Bool

    /// Whether a solid was created from a shell
    public let solidCreated: Bool

    /// Whether shape healing was applied
    public let healingApplied: Bool

    /// Human-readable summary of the import processing
    public var summary: String {
        var steps: [String] = []
        if sewingApplied { steps.append("sewing") }
        if solidCreated { steps.append("solid creation") }
        if healingApplied { steps.append("healing") }
        let processing = steps.isEmpty ? "none" : steps.joined(separator: ", ")
        return "\(originalType) → \(resultType) (processing: \(processing))"
    }
}

// MARK: - Operators

extension Shape {
    public static func + (lhs: Shape, rhs: Shape) -> Shape? {
        lhs.union(with: rhs)
    }

    public static func - (lhs: Shape, rhs: Shape) -> Shape? {
        lhs.subtracting(rhs)
    }

    public static func & (lhs: Shape, rhs: Shape) -> Shape? {
        lhs.intersection(with: rhs)
    }
}

// MARK: - Measurement & Analysis (v0.7.0)

/// Mass and geometric properties of a shape
public struct ShapeProperties: Sendable, Equatable {
    /// Volume in cubic units
    public var volume: Double

    /// Surface area in square units
    public var surfaceArea: Double

    /// Mass (volume × density)
    public var mass: Double

    /// Center of mass location
    public var centerOfMass: SIMD3<Double>

    /// Moment of inertia tensor (3x3 matrix)
    public var momentOfInertia: simd_double3x3

    public init(
        volume: Double,
        surfaceArea: Double,
        mass: Double,
        centerOfMass: SIMD3<Double>,
        momentOfInertia: simd_double3x3
    ) {
        self.volume = volume
        self.surfaceArea = surfaceArea
        self.mass = mass
        self.centerOfMass = centerOfMass
        self.momentOfInertia = momentOfInertia
    }
}

/// Result of distance measurement between two shapes
public struct DistanceResult: Sendable, Equatable {
    /// Minimum distance between the shapes
    public var distance: Double

    /// Closest point on the first shape
    public var pointOnShape1: SIMD3<Double>

    /// Closest point on the second shape
    public var pointOnShape2: SIMD3<Double>

    /// Number of solutions found (may be > 1 for symmetric cases)
    public var solutionCount: Int

    public init(
        distance: Double,
        pointOnShape1: SIMD3<Double>,
        pointOnShape2: SIMD3<Double>,
        solutionCount: Int
    ) {
        self.distance = distance
        self.pointOnShape1 = pointOnShape1
        self.pointOnShape2 = pointOnShape2
        self.solutionCount = solutionCount
    }
}

// MARK: - Shape Measurement Extensions

extension Shape {

    /// Get full mass properties of the shape
    ///
    /// - Parameter density: Material density for mass calculation (default 1.0)
    /// - Returns: Properties including volume, surface area, center of mass, and inertia tensor,
    ///            or nil if calculation fails
    public func properties(density: Double = 1.0) -> ShapeProperties? {
        let result = OCCTShapeGetProperties(handle, density)
        guard result.isValid else { return nil }

        let inertia = simd_double3x3(
            SIMD3<Double>(result.ixx, result.iyx, result.izx),
            SIMD3<Double>(result.ixy, result.iyy, result.izy),
            SIMD3<Double>(result.ixz, result.iyz, result.izz)
        )

        return ShapeProperties(
            volume: result.volume,
            surfaceArea: result.surfaceArea,
            mass: result.mass,
            centerOfMass: SIMD3<Double>(result.centerX, result.centerY, result.centerZ),
            momentOfInertia: inertia
        )
    }

    /// Volume of the shape in cubic units
    public var volume: Double? {
        let v = OCCTShapeGetVolume(handle)
        return v >= 0 ? v : nil
    }

    /// Surface area of the shape in square units
    public var surfaceArea: Double? {
        let a = OCCTShapeGetSurfaceArea(handle)
        return a >= 0 ? a : nil
    }

    /// Center of mass (centroid) of the shape
    public var centerOfMass: SIMD3<Double>? {
        var x: Double = 0, y: Double = 0, z: Double = 0
        guard OCCTShapeGetCenterOfMass(handle, &x, &y, &z) else { return nil }
        return SIMD3<Double>(x, y, z)
    }

    /// Compute minimum distance between this shape and another
    ///
    /// - Parameters:
    ///   - other: The other shape to measure distance to
    ///   - deflection: Tolerance for curved geometry (default 1e-6)
    /// - Returns: Distance result with closest points, or nil if calculation fails
    public func distance(to other: Shape, deflection: Double = 1e-6) -> DistanceResult? {
        let result = OCCTShapeDistance(handle, other.handle, deflection)
        guard result.isValid else { return nil }

        return DistanceResult(
            distance: result.distance,
            pointOnShape1: SIMD3<Double>(result.p1x, result.p1y, result.p1z),
            pointOnShape2: SIMD3<Double>(result.p2x, result.p2y, result.p2z),
            solutionCount: Int(result.solutionCount)
        )
    }

    /// Get minimum distance between this shape and another
    ///
    /// - Parameter other: The other shape
    /// - Returns: Minimum distance, or nil if calculation fails
    public func minDistance(to other: Shape) -> Double? {
        distance(to: other)?.distance
    }

    /// Check if this shape intersects (overlaps or touches) another shape
    ///
    /// - Parameters:
    ///   - other: The other shape to test
    ///   - tolerance: Distance threshold for intersection (default 1e-6)
    /// - Returns: true if shapes intersect or touch within tolerance
    public func intersects(_ other: Shape, tolerance: Double = 1e-6) -> Bool {
        OCCTShapeIntersects(handle, other.handle, tolerance)
    }

    /// Number of vertices (corners) in the shape
    public var vertexCount: Int {
        Int(OCCTShapeGetVertexCount(handle))
    }

    /// Get all vertices (corner points) of the shape
    ///
    /// - Returns: Array of vertex positions
    public func vertices() -> [SIMD3<Double>] {
        let count = OCCTShapeGetVertexCount(handle)
        guard count > 0 else { return [] }

        var coords = [Double](repeating: 0, count: Int(count) * 3)
        let written = OCCTShapeGetVertices(handle, &coords)

        var result: [SIMD3<Double>] = []
        result.reserveCapacity(Int(written))

        for i in 0..<Int(written) {
            result.append(SIMD3<Double>(
                coords[i * 3],
                coords[i * 3 + 1],
                coords[i * 3 + 2]
            ))
        }
        return result
    }

    /// Get vertex at specific index
    ///
    /// - Parameter index: Zero-based vertex index
    /// - Returns: Vertex position, or nil if index out of bounds
    public func vertex(at index: Int) -> SIMD3<Double>? {
        var x: Double = 0, y: Double = 0, z: Double = 0
        guard OCCTShapeGetVertexAt(handle, Int32(index), &x, &y, &z) else { return nil }
        return SIMD3<Double>(x, y, z)
    }
}

// MARK: - Advanced Modeling (v0.8.0)

/// Sweep mode for advanced pipe creation
public enum PipeSweepMode: Sendable {
    /// Standard Frenet trihedron - profile orientation follows spine curvature
    case frenet
    /// Corrected Frenet - avoids twisting at inflection points
    case correctedFrenet
    /// Fixed binormal direction - profile maintains constant orientation
    case fixed(binormal: SIMD3<Double>)
    /// Auxiliary spine - twist controlled by secondary curve
    case auxiliary(spine: Wire)
}

extension Shape {
    // MARK: - Selective Fillet

    /// Fillet specific edges with uniform radius
    ///
    /// - Parameters:
    ///   - edges: Edges to fillet (must have valid indices from this shape)
    ///   - radius: Fillet radius
    /// - Returns: Filleted shape, or nil on failure
    public func filleted(edges: [Edge], radius: Double) -> Shape? {
        guard !edges.isEmpty, radius > 0 else { return nil }

        // Extract indices from edges
        var indices = [Int32]()
        indices.reserveCapacity(edges.count)
        for edge in edges {
            guard edge.index >= 0 else { return nil }
            indices.append(Int32(edge.index))
        }

        return indices.withUnsafeBufferPointer { buffer in
            guard let result = OCCTShapeFilletEdges(handle, buffer.baseAddress, Int32(indices.count), radius) else {
                return nil
            }
            return Shape(handle: result)
        }
    }

    /// Fillet specific edges with linear radius interpolation
    ///
    /// - Parameters:
    ///   - edges: Edges to fillet (must have valid indices from this shape)
    ///   - startRadius: Radius at start of each edge
    ///   - endRadius: Radius at end of each edge
    /// - Returns: Filleted shape, or nil on failure
    public func filleted(edges: [Edge], startRadius: Double, endRadius: Double) -> Shape? {
        guard !edges.isEmpty, startRadius > 0, endRadius > 0 else { return nil }

        var indices = [Int32]()
        indices.reserveCapacity(edges.count)
        for edge in edges {
            guard edge.index >= 0 else { return nil }
            indices.append(Int32(edge.index))
        }

        return indices.withUnsafeBufferPointer { buffer in
            guard let result = OCCTShapeFilletEdgesLinear(handle, buffer.baseAddress, Int32(indices.count), startRadius, endRadius) else {
                return nil
            }
            return Shape(handle: result)
        }
    }

    // MARK: - Draft Angle

    /// Add draft angle to faces for mold release
    ///
    /// Draft angles are used in injection molding and casting to allow parts to
    /// be released from the mold. The angle is measured from the pull direction.
    ///
    /// - Parameters:
    ///   - faces: Faces to add draft to (must have valid indices from this shape)
    ///   - direction: Pull direction (typically vertical, e.g., [0, 0, 1])
    ///   - angle: Draft angle in radians (typically 1-5 degrees)
    ///   - neutralPlane: Plane where draft angle is zero (point and normal)
    /// - Returns: Drafted shape, or nil on failure
    public func drafted(
        faces: [Face],
        direction: SIMD3<Double>,
        angle: Double,
        neutralPlane: (point: SIMD3<Double>, normal: SIMD3<Double>)
    ) -> Shape? {
        guard !faces.isEmpty else { return nil }

        var indices = [Int32]()
        indices.reserveCapacity(faces.count)
        for face in faces {
            guard face.index >= 0 else { return nil }
            indices.append(Int32(face.index))
        }

        return indices.withUnsafeBufferPointer { buffer in
            guard let result = OCCTShapeDraft(
                handle,
                buffer.baseAddress,
                Int32(indices.count),
                direction.x, direction.y, direction.z,
                angle,
                neutralPlane.point.x, neutralPlane.point.y, neutralPlane.point.z,
                neutralPlane.normal.x, neutralPlane.normal.y, neutralPlane.normal.z
            ) else {
                return nil
            }
            return Shape(handle: result)
        }
    }

    // MARK: - Defeaturing

    /// Remove features by deleting faces
    ///
    /// The defeaturing algorithm removes specified faces and heals the resulting
    /// gaps by extending adjacent faces. Useful for simplifying geometry for
    /// analysis or removing small features.
    ///
    /// - Parameter faces: Faces to remove (must have valid indices from this shape)
    /// - Returns: Shape with features removed, or nil on failure
    public func withoutFeatures(faces: [Face]) -> Shape? {
        guard !faces.isEmpty else { return nil }

        var indices = [Int32]()
        indices.reserveCapacity(faces.count)
        for face in faces {
            guard face.index >= 0 else { return nil }
            indices.append(Int32(face.index))
        }

        return indices.withUnsafeBufferPointer { buffer in
            guard let result = OCCTShapeRemoveFeatures(handle, buffer.baseAddress, Int32(indices.count)) else {
                return nil
            }
            return Shape(handle: result)
        }
    }

    // MARK: - Advanced Pipe Sweep

    /// Create a pipe (sweep) with advanced sweep modes
    ///
    /// Unlike the basic `pipe(profile:path:)`, this method provides control over
    /// how the profile is oriented along the sweep path.
    ///
    /// - Parameters:
    ///   - spine: Path wire along which to sweep
    ///   - profile: Profile wire to sweep
    ///   - mode: Sweep mode controlling profile orientation
    ///   - solid: If true, create a solid; if false, create a shell
    /// - Returns: Swept shape, or nil on failure
    public static func pipeShell(
        spine: Wire,
        profile: Wire,
        mode: PipeSweepMode = .frenet,
        solid: Bool = true
    ) -> Shape? {
        let result: OCCTShapeRef?

        switch mode {
        case .frenet:
            result = OCCTShapeCreatePipeShell(spine.handle, profile.handle, OCCTPipeModeFrenet, solid)
        case .correctedFrenet:
            result = OCCTShapeCreatePipeShell(spine.handle, profile.handle, OCCTPipeModeCorrectedFrenet, solid)
        case .fixed(let binormal):
            result = OCCTShapeCreatePipeShellWithBinormal(spine.handle, profile.handle, binormal.x, binormal.y, binormal.z, solid)
        case .auxiliary(let auxSpine):
            result = OCCTShapeCreatePipeShellWithAuxSpine(spine.handle, profile.handle, auxSpine.handle, solid)
        }

        guard let shapeRef = result else { return nil }
        return Shape(handle: shapeRef)
    }

    // MARK: - Surface Creation (v0.9.0)

    /// Create a B-spline surface from a grid of control points.
    ///
    /// The surface interpolates approximately through the control point grid.
    /// Control points are specified in row-major order (U varies fastest).
    ///
    /// - Parameters:
    ///   - poles: 2D array of control points [uIndex][vIndex]
    ///   - uDegree: Degree in U direction (default 3 for cubic)
    ///   - vDegree: Degree in V direction (default 3 for cubic)
    /// - Returns: A face shape from the B-spline surface, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Create a 4x4 control point grid for a curved surface
    /// let poles: [[SIMD3<Double>]] = [
    ///     [SIMD3(0, 0, 0), SIMD3(0, 10, 0), SIMD3(0, 20, 0), SIMD3(0, 30, 0)],
    ///     [SIMD3(10, 0, 2), SIMD3(10, 10, 2), SIMD3(10, 20, 2), SIMD3(10, 30, 2)],
    ///     [SIMD3(20, 0, 2), SIMD3(20, 10, 2), SIMD3(20, 20, 2), SIMD3(20, 30, 2)],
    ///     [SIMD3(30, 0, 0), SIMD3(30, 10, 0), SIMD3(30, 20, 0), SIMD3(30, 30, 0)]
    /// ]
    /// let surface = Shape.surface(poles: poles)
    /// ```
    public static func surface(
        poles: [[SIMD3<Double>]],
        uDegree: Int = 3,
        vDegree: Int = 3
    ) -> Shape? {
        guard !poles.isEmpty, let firstRow = poles.first, !firstRow.isEmpty else { return nil }

        let uCount = poles.count
        let vCount = firstRow.count

        // Verify all rows have the same count
        for row in poles {
            guard row.count == vCount else { return nil }
        }

        guard uCount >= uDegree + 1, vCount >= vDegree + 1 else { return nil }

        // Flatten to array of doubles in row-major order
        var flatPoles: [Double] = []
        flatPoles.reserveCapacity(uCount * vCount * 3)

        for row in poles {
            for point in row {
                flatPoles.append(point.x)
                flatPoles.append(point.y)
                flatPoles.append(point.z)
            }
        }

        return flatPoles.withUnsafeBufferPointer { buffer in
            guard let result = OCCTShapeCreateBSplineSurface(
                buffer.baseAddress,
                Int32(uCount),
                Int32(vCount),
                Int32(uDegree),
                Int32(vDegree)
            ) else {
                return nil
            }
            return Shape(handle: result)
        }
    }

    /// Create a ruled surface between two wires.
    ///
    /// A ruled surface is created by connecting corresponding points on two
    /// boundary curves with straight lines. The result is a smooth surface
    /// that linearly interpolates between the two profiles.
    ///
    /// - Parameters:
    ///   - profile1: First boundary wire
    ///   - profile2: Second boundary wire
    /// - Returns: A shell shape containing the ruled surface, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Create a cone-like surface between two circles
    /// let bottom = Wire.circle(radius: 10)!
    /// let top = Wire.circle(radius: 5)!.offset3D(distance: 20, direction: SIMD3(0, 0, 1))!
    /// let cone = Shape.ruled(profile1: bottom, profile2: top)
    /// ```
    public static func ruled(profile1: Wire, profile2: Wire) -> Shape? {
        guard let result = OCCTShapeCreateRuled(profile1.handle, profile2.handle) else {
            return nil
        }
        return Shape(handle: result)
    }

    /// Create a shell (hollow solid) with specific faces left open.
    ///
    /// Unlike the basic `shelled(thickness:)` method, this allows you to specify
    /// which faces should be removed to create openings.
    ///
    /// - Parameters:
    ///   - thickness: Wall thickness (positive = inward, negative = outward)
    ///   - openFaces: Faces to leave open (must have valid indices from this shape)
    /// - Returns: Shelled shape with specified faces open, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Create a box with an open top
    /// let box = Shape.box(width: 20, height: 20, depth: 20)!
    /// let topFaces = box.upwardFaces()
    /// let openBox = box.shelled(thickness: 2.0, openFaces: topFaces)
    /// ```
    public func shelled(thickness: Double, openFaces: [Face]) -> Shape? {
        guard !openFaces.isEmpty else { return nil }

        var indices = [Int32]()
        indices.reserveCapacity(openFaces.count)
        for face in openFaces {
            guard face.index >= 0 else { return nil }
            indices.append(Int32(face.index))
        }

        return indices.withUnsafeBufferPointer { buffer in
            guard let result = OCCTShapeShellWithOpenFaces(
                handle,
                thickness,
                buffer.baseAddress,
                Int32(indices.count)
            ) else {
                return nil
            }
            return Shape(handle: result)
        }
    }
}

// MARK: - Shape Healing & Analysis (v0.13.0)

/// Result of shape analysis, containing counts of various problems found.
public struct ShapeAnalysisResult {
    /// Number of edges smaller than tolerance
    public let smallEdgeCount: Int

    /// Number of faces smaller than tolerance
    public let smallFaceCount: Int

    /// Number of gaps between edges/faces
    public let gapCount: Int

    /// Number of self-intersections detected
    public let selfIntersectionCount: Int

    /// Number of free (unconnected) edges
    public let freeEdgeCount: Int

    /// Number of free faces (shell not closed)
    public let freeFaceCount: Int

    /// Whether the topology is invalid
    public let hasInvalidTopology: Bool

    /// Total number of problems found
    public var totalProblems: Int {
        smallEdgeCount + smallFaceCount + gapCount + selfIntersectionCount + freeEdgeCount + freeFaceCount + (hasInvalidTopology ? 1 : 0)
    }

    /// Whether the shape appears to be healthy (no problems found)
    public var isHealthy: Bool {
        totalProblems == 0 && !hasInvalidTopology
    }
}

extension Shape {

    // MARK: - Shape Analysis (v0.13.0)

    /// Analyze a shape for problems such as small edges, gaps, and invalid topology.
    ///
    /// - Parameter tolerance: Size threshold for detecting small features
    /// - Returns: Analysis result with problem counts, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// let shape = Shape.load(from: stepURL)!
    /// if let analysis = shape.analyze(tolerance: 0.001) {
    ///     print("Found \(analysis.totalProblems) problems")
    ///     if analysis.hasInvalidTopology {
    ///         print("Shape has invalid topology!")
    ///     }
    /// }
    /// ```
    public func analyze(tolerance: Double = 1e-6) -> ShapeAnalysisResult? {
        let result = OCCTShapeAnalyze(handle, tolerance)
        guard result.isValid else { return nil }

        return ShapeAnalysisResult(
            smallEdgeCount: Int(result.smallEdgeCount),
            smallFaceCount: Int(result.smallFaceCount),
            gapCount: Int(result.gapCount),
            selfIntersectionCount: Int(result.selfIntersectionCount),
            freeEdgeCount: Int(result.freeEdgeCount),
            freeFaceCount: Int(result.freeFaceCount),
            hasInvalidTopology: result.hasInvalidTopology
        )
    }

    // MARK: - Shape Fixing (v0.13.0)

    /// Fix shape problems with detailed control over what to fix.
    ///
    /// - Parameters:
    ///   - tolerance: Tolerance for fixing operations
    ///   - fixSolid: Whether to fix solid orientation
    ///   - fixShell: Whether to fix shell closure
    ///   - fixFace: Whether to fix face issues
    ///   - fixWire: Whether to fix wire issues
    /// - Returns: Fixed shape, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Fix only wire and face issues, not solid
    /// let fixed = shape.fixed(tolerance: 0.001, fixSolid: false)
    /// ```
    public func fixed(tolerance: Double = 1e-6,
                      fixSolid: Bool = true,
                      fixShell: Bool = true,
                      fixFace: Bool = true,
                      fixWire: Bool = true) -> Shape? {
        guard let result = OCCTShapeFixDetailed(handle, tolerance, fixSolid, fixShell, fixFace, fixWire) else {
            return nil
        }
        return Shape(handle: result)
    }

    // MARK: - Shape Unification (v0.13.0)

    /// Unify faces and edges lying on the same geometry.
    ///
    /// After boolean operations, shapes often have unnecessary internal subdivisions.
    /// This method merges faces that share the same underlying surface and edges
    /// that share the same underlying curve.
    ///
    /// - Parameters:
    ///   - unifyEdges: Whether to merge edges on same curve (default: true)
    ///   - unifyFaces: Whether to merge faces on same surface (default: true)
    ///   - concatBSplines: Whether to concatenate adjacent B-splines (default: true)
    /// - Returns: Unified shape, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// // After subtracting multiple cylinders, unify to simplify topology
    /// let result = box - cyl1 - cyl2 - cyl3
    /// let clean = result.unified()
    /// print("Faces reduced from \(result.faceCount) to \(clean.faceCount)")
    /// ```
    public func unified(unifyEdges: Bool = true,
                        unifyFaces: Bool = true,
                        concatBSplines: Bool = true) -> Shape? {
        guard let result = OCCTShapeUnifySameDomain(handle, unifyEdges, unifyFaces, concatBSplines) else {
            return nil
        }
        return Shape(handle: result)
    }

    /// Remove faces smaller than the specified area threshold.
    ///
    /// Useful for cleaning up shapes with very small faces that can cause
    /// problems in downstream operations.
    ///
    /// - Parameter minArea: Minimum area threshold; faces smaller than this are removed
    /// - Returns: Cleaned shape, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Remove faces smaller than 0.01 mm²
    /// let cleaned = shape.withoutSmallFaces(minArea: 0.01)
    /// ```
    public func withoutSmallFaces(minArea: Double) -> Shape? {
        guard let result = OCCTShapeRemoveSmallFaces(handle, minArea) else {
            return nil
        }
        return Shape(handle: result)
    }

    /// Simplify a shape by unifying same-domain geometry and healing.
    ///
    /// This is a convenience method that combines `unified()` and `healed()`.
    ///
    /// - Parameter tolerance: Tolerance for simplification operations
    /// - Returns: Simplified shape, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Clean up a complex boolean result
    /// let simplified = result.simplified(tolerance: 0.001)
    /// ```
    public func simplified(tolerance: Double = 1e-6) -> Shape? {
        guard let result = OCCTShapeSimplify(handle, tolerance) else {
            return nil
        }
        return Shape(handle: result)
    }
}

extension Wire {

    // MARK: - Wire Fixing (v0.13.0)

    /// Fix wire problems such as gaps, degenerate edges, and incorrect ordering.
    ///
    /// - Parameter tolerance: Tolerance for fixing operations
    /// - Returns: Fixed wire, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Fix a wire with small gaps between edges
    /// let fixedWire = problematicWire.fixed(tolerance: 0.001)
    /// ```
    public func fixed(tolerance: Double = 1e-6) -> Wire? {
        guard let result = OCCTWireFix(handle, tolerance) else {
            return nil
        }
        return Wire(handle: result)
    }
}

extension Face {

    // MARK: - Face Fixing (v0.13.0)

    /// Fix face problems such as incorrect wire orientation, missing seams, and surface parameters.
    ///
    /// - Parameter tolerance: Tolerance for fixing operations
    /// - Returns: Fixed face as a shape, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Fix a face with wire orientation issues
    /// let fixedShape = problematicFace.fixed(tolerance: 0.001)
    /// ```
    public func fixed(tolerance: Double = 1e-6) -> Shape? {
        guard let result = OCCTFaceFix(handle, tolerance) else {
            return nil
        }
        return Shape(handle: result)
    }
}

// MARK: - Advanced Blends & Surface Filling (v0.14.0)

/// Continuity specification for surface filling operations
public enum SurfaceContinuity: Int32 {
    /// Positional continuity (surfaces touch)
    case c0 = 0
    /// Tangent continuity (smooth transition)
    case g1 = 1
    /// Curvature continuity (very smooth)
    case g2 = 2
}

/// Parameters for surface filling operations
public struct FillingParameters {
    /// Surface continuity at boundaries
    public var continuity: SurfaceContinuity
    /// Surface tolerance
    public var tolerance: Double
    /// Maximum surface degree
    public var maxDegree: Int
    /// Maximum number of segments
    public var maxSegments: Int

    /// Create filling parameters with defaults
    public init(
        continuity: SurfaceContinuity = .g1,
        tolerance: Double = 1e-4,
        maxDegree: Int = 8,
        maxSegments: Int = 9
    ) {
        self.continuity = continuity
        self.tolerance = tolerance
        self.maxDegree = maxDegree
        self.maxSegments = maxSegments
    }

    internal var cParams: OCCTFillingParams {
        OCCTFillingParams(
            continuity: continuity.rawValue,
            tolerance: tolerance,
            maxDegree: Int32(maxDegree),
            maxSegments: Int32(maxSegments)
        )
    }
}

extension Shape {
    // MARK: - Variable Radius Fillet (v0.14.0)

    /// Apply a variable radius fillet to a specific edge.
    ///
    /// The radius varies along the edge according to the given radius/parameter pairs.
    /// Parameters are normalized from 0.0 (start of edge) to 1.0 (end of edge).
    ///
    /// - Parameters:
    ///   - edgeIndex: Index of the edge to fillet
    ///   - radiusProfile: Array of (parameter, radius) pairs defining the radius along the edge
    /// - Returns: Filleted shape, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Fillet with radius varying from 1mm at start to 3mm at end
    /// let filleted = shape.filletedVariable(
    ///     edgeIndex: 0,
    ///     radiusProfile: [(0.0, 1.0), (1.0, 3.0)]
    /// )
    ///
    /// // Fillet with radius varying: 1mm at start, 2mm at middle, 1mm at end
    /// let complexFillet = shape.filletedVariable(
    ///     edgeIndex: 0,
    ///     radiusProfile: [(0.0, 1.0), (0.5, 2.0), (1.0, 1.0)]
    /// )
    /// ```
    public func filletedVariable(
        edgeIndex: Int,
        radiusProfile: [(parameter: Double, radius: Double)]
    ) -> Shape? {
        guard radiusProfile.count >= 2 else { return nil }

        var radii = radiusProfile.map { $0.radius }
        var params = radiusProfile.map { $0.parameter }

        guard let result = OCCTShapeFilletVariable(
            handle,
            Int32(edgeIndex),
            &radii,
            &params,
            Int32(radii.count)
        ) else {
            return nil
        }
        return Shape(handle: result)
    }

    // MARK: - Multi-Edge Blend (v0.14.0)

    /// Apply fillets to multiple edges with individual radii.
    ///
    /// Each edge can have its own fillet radius, allowing for more control
    /// than applying a uniform fillet to all edges.
    ///
    /// - Parameter edgeRadii: Array of (edgeIndex, radius) pairs
    /// - Returns: Filleted shape, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Apply different radii to different edges
    /// let blended = shape.blendedEdges([
    ///     (0, 1.0),  // Edge 0 gets 1mm fillet
    ///     (1, 2.0),  // Edge 1 gets 2mm fillet
    ///     (2, 0.5)   // Edge 2 gets 0.5mm fillet
    /// ])
    /// ```
    public func blendedEdges(_ edgeRadii: [(edgeIndex: Int, radius: Double)]) -> Shape? {
        guard !edgeRadii.isEmpty else { return nil }

        var indices = edgeRadii.map { Int32($0.edgeIndex) }
        var radii = edgeRadii.map { $0.radius }

        guard let result = OCCTShapeBlendEdges(
            handle,
            &indices,
            &radii,
            Int32(edgeRadii.count)
        ) else {
            return nil
        }
        return Shape(handle: result)
    }

    // MARK: - Surface Filling (v0.14.0)

    /// Fill an N-sided boundary with a smooth surface.
    ///
    /// Creates a surface that passes through the given boundary wires
    /// with the specified continuity.
    ///
    /// - Parameters:
    ///   - boundaries: Array of wires defining the boundary
    ///   - parameters: Filling parameters (continuity, tolerance, etc.)
    /// - Returns: Face shape covering the boundary, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Fill a 4-sided boundary with a smooth surface
    /// let wire1 = Wire.line(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))
    /// let wire2 = Wire.line(from: SIMD3(10, 0, 0), to: SIMD3(10, 10, 5))
    /// let wire3 = Wire.line(from: SIMD3(10, 10, 5), to: SIMD3(0, 10, 3))
    /// let wire4 = Wire.line(from: SIMD3(0, 10, 3), to: SIMD3(0, 0, 0))
    ///
    /// let surface = Shape.fill(
    ///     boundaries: [wire1, wire2, wire3, wire4],
    ///     parameters: FillingParameters(continuity: .g1)
    /// )
    /// ```
    public static func fill(
        boundaries: [Wire],
        parameters: FillingParameters = FillingParameters()
    ) -> Shape? {
        guard !boundaries.isEmpty else { return nil }

        var handles = boundaries.map { $0.handle as OCCTWireRef? }

        guard let result = handles.withUnsafeMutableBufferPointer({ buffer in
            OCCTShapeFill(buffer.baseAddress, Int32(boundaries.count), parameters.cParams)
        }) else {
            return nil
        }
        return Shape(handle: result)
    }

    // MARK: - Plate Surfaces (v0.14.0)

    /// Create a surface constrained to pass through specific points.
    ///
    /// Uses a plate surface algorithm to create a smooth surface
    /// that interpolates through all given points.
    ///
    /// - Parameters:
    ///   - points: Array of 3D points the surface must pass through
    ///   - tolerance: Surface approximation tolerance
    /// - Returns: Surface face, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Create a surface through scattered points
    /// let surface = Shape.plateSurface(
    ///     through: [
    ///         SIMD3(0, 0, 0),
    ///         SIMD3(10, 0, 1),
    ///         SIMD3(10, 10, 2),
    ///         SIMD3(0, 10, 1),
    ///         SIMD3(5, 5, 3)  // Point in middle raises surface
    ///     ],
    ///     tolerance: 0.01
    /// )
    /// ```
    public static func plateSurface(
        through points: [SIMD3<Double>],
        tolerance: Double = 0.01
    ) -> Shape? {
        guard points.count >= 3 else { return nil }

        var flatPoints: [Double] = []
        for point in points {
            flatPoints.append(point.x)
            flatPoints.append(point.y)
            flatPoints.append(point.z)
        }

        guard let result = OCCTShapePlatePoints(
            &flatPoints,
            Int32(points.count),
            tolerance
        ) else {
            return nil
        }
        return Shape(handle: result)
    }

    /// Create a surface constrained by boundary curves.
    ///
    /// Uses a plate surface algorithm to create a smooth surface
    /// that follows the given boundary curves with specified continuity.
    ///
    /// - Parameters:
    ///   - curves: Array of wires defining boundary constraints
    ///   - continuity: Continuity requirement at boundaries
    ///   - tolerance: Surface approximation tolerance
    /// - Returns: Surface face, or nil on failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Create a surface bounded by curves
    /// let curve1 = Wire.bspline([...])
    /// let curve2 = Wire.bspline([...])
    ///
    /// let surface = Shape.plateSurface(
    ///     constrainedBy: [curve1, curve2],
    ///     continuity: .g1,
    ///     tolerance: 0.01
    /// )
    /// ```
    public static func plateSurface(
        constrainedBy curves: [Wire],
        continuity: SurfaceContinuity = .g1,
        tolerance: Double = 0.01
    ) -> Shape? {
        guard !curves.isEmpty else { return nil }

        var handles = curves.map { $0.handle as OCCTWireRef? }

        guard let result = handles.withUnsafeMutableBufferPointer({ buffer in
            OCCTShapePlateCurves(
                buffer.baseAddress,
                Int32(curves.count),
                continuity.rawValue,
                tolerance
            )
        }) else {
            return nil
        }
        return Shape(handle: result)
    }
}

// MARK: - Advanced Healing (v0.17.0)

/// Target geometric continuity for shape divide operations
public enum GeometricContinuity: Int32, Sendable {
    case c0 = 0
    case c1 = 1
    case c2 = 2
    case c3 = 3
}

extension Shape {

    /// Divide a shape at continuity discontinuities
    ///
    /// - Parameter continuity: Target continuity level
    /// - Returns: Divided shape, or nil on failure
    public func divided(at continuity: GeometricContinuity) -> Shape? {
        guard let handle = OCCTShapeDivide(self.handle, continuity.rawValue) else { return nil }
        return Shape(handle: handle)
    }

    /// Convert geometry to direct faces (canonical surfaces)
    ///
    /// - Returns: Shape with canonical surfaces, or nil on failure
    public func directFaces() -> Shape? {
        guard let handle = OCCTShapeDirectFaces(self.handle) else { return nil }
        return Shape(handle: handle)
    }

    /// Scale shape geometry by a factor
    ///
    /// Unlike `scaled(by:)` which applies a geometric transform, this modifies the
    /// underlying surface and curve definitions.
    ///
    /// - Parameter factor: Scale factor
    /// - Returns: Scaled shape, or nil on failure
    public func scaledGeometry(factor: Double) -> Shape? {
        guard let handle = OCCTShapeScaleGeometry(self.handle, factor) else { return nil }
        return Shape(handle: handle)
    }

    /// Convert BSpline surfaces to their closest analytical form
    ///
    /// Attempts to convert BSpline surfaces to planes, cylinders, cones, spheres, or tori.
    ///
    /// - Parameters:
    ///   - surfaceTolerance: Tolerance for surface approximation (default: 0.01)
    ///   - curveTolerance: Tolerance for curve approximation (default: 0.01)
    ///   - maxDegree: Maximum degree for BSpline restriction (default: 9)
    ///   - maxSegments: Maximum number of segments (default: 10000)
    /// - Returns: Shape with restricted BSplines, or nil on failure
    public func bsplineRestriction(surfaceTolerance: Double = 0.01,
                                   curveTolerance: Double = 0.01,
                                   maxDegree: Int = 9,
                                   maxSegments: Int = 10000) -> Shape? {
        guard let handle = OCCTShapeBSplineRestriction(self.handle, surfaceTolerance, curveTolerance,
                                                        Int32(maxDegree), Int32(maxSegments)) else { return nil }
        return Shape(handle: handle)
    }

    /// Convert swept surfaces to elementary (canonical) surfaces
    ///
    /// - Returns: Shape with elementary surfaces, or nil on failure
    public func sweptToElementary() -> Shape? {
        guard let handle = OCCTShapeSweptToElementary(self.handle) else { return nil }
        return Shape(handle: handle)
    }

    /// Convert surfaces of revolution to elementary surfaces
    ///
    /// - Returns: Shape with elementary surfaces, or nil on failure
    public func revolutionToElementary() -> Shape? {
        guard let handle = OCCTShapeRevolutionToElementary(self.handle) else { return nil }
        return Shape(handle: handle)
    }

    /// Convert all surfaces to BSpline
    ///
    /// - Returns: Shape with BSpline surfaces, or nil on failure
    public func convertedToBSpline() -> Shape? {
        guard let handle = OCCTShapeConvertToBSpline(self.handle) else { return nil }
        return Shape(handle: handle)
    }

    /// Sew disconnected faces in this shape together
    ///
    /// - Parameter tolerance: Sewing tolerance (default: 1e-6)
    /// - Returns: Sewn shape, or nil on failure
    public func sewn(tolerance: Double = 1e-6) -> Shape? {
        guard let handle = OCCTShapeSewSingle(self.handle, tolerance) else { return nil }
        return Shape(handle: handle)
    }

    /// Upgrade shape: sew + make solid + heal pipeline
    ///
    /// Performs a complete upgrade of the shape by sewing disconnected faces,
    /// attempting to create a solid from shells, and applying shape healing.
    ///
    /// - Parameter tolerance: Tolerance for sewing and healing (default: 1e-6)
    /// - Returns: Upgraded shape, or nil on failure
    public func upgraded(tolerance: Double = 1e-6) -> Shape? {
        guard let handle = OCCTShapeUpgrade(self.handle, tolerance) else { return nil }
        return Shape(handle: handle)
    }
}

// MARK: - Point Classification (v0.17.0)

/// Classification of a point relative to a shape
public enum PointClassification: Int32, Sendable {
    /// Point is inside the shape
    case inside = 0      // TopAbs_IN
    /// Point is outside the shape
    case outside = 1     // TopAbs_OUT
    /// Point is on the boundary of the shape
    case onBoundary = 2  // TopAbs_ON
    /// Classification could not be determined
    case unknown = 3     // TopAbs_UNKNOWN
}

extension Shape {

    /// Classify a point relative to this solid
    ///
    /// Determines whether a 3D point is inside, outside, or on the boundary of
    /// this shape. The shape should be a solid for reliable results.
    ///
    /// - Parameters:
    ///   - point: The 3D point to classify
    ///   - tolerance: Tolerance for boundary detection (default: 1e-6)
    /// - Returns: Classification result
    public func classify(point: SIMD3<Double>, tolerance: Double = 1e-6) -> PointClassification {
        let state = OCCTClassifyPointInSolid(handle, point.x, point.y, point.z, tolerance)
        return PointClassification(rawValue: state) ?? .unknown
    }
}

extension Face {

    /// Classify a point relative to this face using a 3D point
    ///
    /// - Parameters:
    ///   - point: The 3D point to classify
    ///   - tolerance: Tolerance for boundary detection (default: 1e-6)
    /// - Returns: Classification result
    public func classify(point: SIMD3<Double>, tolerance: Double = 1e-6) -> PointClassification {
        let state = OCCTClassifyPointOnFace(handle, point.x, point.y, point.z, tolerance)
        return PointClassification(rawValue: state) ?? .unknown
    }

    /// Classify a point relative to this face using UV parameters
    ///
    /// - Parameters:
    ///   - u: U parameter on the face surface
    ///   - v: V parameter on the face surface
    ///   - tolerance: Tolerance for boundary detection (default: 1e-6)
    /// - Returns: Classification result
    public func classify(u: Double, v: Double, tolerance: Double = 1e-6) -> PointClassification {
        let state = OCCTClassifyPointOnFaceUV(handle, u, v, tolerance)
        return PointClassification(rawValue: state) ?? .unknown
    }
}
