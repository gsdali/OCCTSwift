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

    /// Loft through profile wires with advanced options.
    ///
    /// - Parameters:
    ///   - profiles: Wire profiles to loft through
    ///   - solid: Whether to create a solid (true) or shell (false)
    ///   - ruled: Whether to use ruled surfaces (true) or smooth B-spline (false)
    ///   - firstVertex: Optional starting vertex (for cone/taper tips)
    ///   - lastVertex: Optional ending vertex (for cone/taper tips)
    /// - Returns: Lofted shape, or nil on failure
    public static func loft(profiles: [Wire], solid: Bool = true, ruled: Bool,
                            firstVertex: SIMD3<Double>? = nil,
                            lastVertex: SIMD3<Double>? = nil) -> Shape? {
        let handles: [OCCTWireRef?] = profiles.map { $0.handle }
        let fv = firstVertex ?? SIMD3<Double>(Double.nan, Double.nan, Double.nan)
        let lv = lastVertex ?? SIMD3<Double>(Double.nan, Double.nan, Double.nan)
        guard let handle = handles.withUnsafeBufferPointer({ buffer in
            OCCTShapeCreateLoftAdvanced(buffer.baseAddress, Int32(profiles.count),
                                        solid, ruled,
                                        fv.x, fv.y, fv.z,
                                        lv.x, lv.y, lv.z)
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

    /// Chamfer specific edges with two different distances (asymmetric).
    ///
    /// Each entry specifies an edge, a reference face adjacent to that edge,
    /// and two distances. `dist1` is measured on the reference face side,
    /// `dist2` on the opposite side.
    ///
    /// - Parameter edges: Array of (edgeIndex, faceIndex, dist1, dist2) tuples
    /// - Returns: Chamfered shape, or nil on failure
    public func chamferedTwoDistances(_ edges: [(edgeIndex: Int, faceIndex: Int, dist1: Double, dist2: Double)]) -> Shape? {
        let ei = edges.map { Int32($0.edgeIndex) }
        let fi = edges.map { Int32($0.faceIndex) }
        let d1 = edges.map { $0.dist1 }
        let d2 = edges.map { $0.dist2 }
        guard let h = OCCTShapeChamferTwoDistances(handle, ei, fi, d1, d2, Int32(edges.count)) else { return nil }
        return Shape(handle: h)
    }

    /// Chamfer specific edges with distance + angle.
    ///
    /// Each entry specifies an edge, a reference face adjacent to that edge,
    /// a distance measured on the reference face, and a chamfer angle in degrees
    /// (must be between 0 and 90, exclusive).
    ///
    /// - Parameter edges: Array of (edgeIndex, faceIndex, distance, angleDegrees) tuples
    /// - Returns: Chamfered shape, or nil on failure
    public func chamferedDistAngle(_ edges: [(edgeIndex: Int, faceIndex: Int, distance: Double, angleDegrees: Double)]) -> Shape? {
        let ei = edges.map { Int32($0.edgeIndex) }
        let fi = edges.map { Int32($0.faceIndex) }
        let d = edges.map { $0.distance }
        let a = edges.map { $0.angleDegrees }
        guard let h = OCCTShapeChamferDistAngle(handle, ei, fi, d, a, Int32(edges.count)) else { return nil }
        return Shape(handle: h)
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

    /// Offset all faces using the proper join algorithm.
    ///
    /// This uses `PerformByJoin` which is more robust than the simple offset.
    /// It handles gap filling between parallel faces using the specified join type.
    ///
    /// - Parameters:
    ///   - distance: Offset distance (positive = outward, negative = inward)
    ///   - tolerance: Coincidence tolerance (default: 1e-7)
    ///   - joinType: How to fill gaps between offset faces
    ///   - removeInternalEdges: Whether to clean up internal edges
    /// - Returns: Offset shape, or nil on failure
    public func offset(by distance: Double, tolerance: Double = 1e-7,
                       joinType: OffsetJoinType = .arc,
                       removeInternalEdges: Bool = false) -> Shape? {
        guard let h = OCCTShapeOffsetByJoin(handle, distance, tolerance,
                                             joinType.rawValue, removeInternalEdges) else { return nil }
        return Shape(handle: h)
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
        // Build 3D curves for all edges upfront. Lofted/swept shapes may only
        // have pcurves; this ensures explicit 3D curves exist before discretization.
        OCCTShapeBuildCurves3d(handle)

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

    /// Create an evolved shape with full parameter control.
    ///
    /// Extends the basic `evolved` method with control over join type, coordinate
    /// system, solid/volume mode, and tolerance.
    ///
    /// - Parameters:
    ///   - spine: Path wire to sweep along
    ///   - profile: Profile wire to sweep
    ///   - joinType: How to join offset edges (default: .arc)
    ///   - axeProf: If true, profile is in global coordinates; if false, local to spine
    ///   - solid: If true, produce a solid result
    ///   - volume: If true, use volume mode (removes self-intersections)
    ///   - tolerance: Tolerance for evolved shape creation
    /// - Returns: Evolved shape, or nil on failure
    public static func evolvedAdvanced(spine: Shape, profile: Wire,
                                       joinType: OffsetJoinType = .arc,
                                       axeProf: Bool = true,
                                       solid: Bool = true,
                                       volume: Bool = false,
                                       tolerance: Double = 1e-4) -> Shape? {
        guard let h = OCCTShapeCreateEvolvedAdvanced(spine.handle, profile.handle,
                                                      joinType.rawValue, axeProf,
                                                      solid, volume, tolerance) else { return nil }
        return Shape(handle: h)
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

    // MARK: - Sub-Shape Extraction

    /// Get the number of sub-shapes of a given topological type.
    ///
    /// - Parameter type: The topological type to count (e.g., `.face`, `.edge`, `.vertex`)
    /// - Returns: Number of sub-shapes of that type
    public func subShapeCount(ofType type: ShapeType) -> Int {
        Int(OCCTShapeGetSubShapeCount(handle, Int32(type.rawValue)))
    }

    /// Get a sub-shape by type and 0-based index.
    ///
    /// Uses `TopExp::MapShapes` to enumerate sub-shapes of the given type,
    /// then returns the one at the specified index as a `Shape` handle.
    ///
    /// - Parameters:
    ///   - type: The topological type (e.g., `.face`, `.edge`, `.vertex`)
    ///   - index: 0-based index into the sub-shapes of that type
    /// - Returns: The sub-shape as a Shape, or nil if index is out of range
    public func subShape(type: ShapeType, index: Int) -> Shape? {
        guard let ref = OCCTShapeGetSubShapeByTypeIndex(handle, Int32(type.rawValue), Int32(index)) else {
            return nil
        }
        return Shape(handle: ref)
    }

    /// Get all sub-shapes of a given topological type.
    ///
    /// - Parameter type: The topological type (e.g., `.face`, `.edge`, `.vertex`)
    /// - Returns: Array of sub-shapes
    public func subShapes(ofType type: ShapeType) -> [Shape] {
        let count = subShapeCount(ofType: type)
        return (0..<count).compactMap { subShape(type: type, index: $0) }
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

/// Transition mode for pipe shell at spine discontinuities (corners).
public enum PipeTransitionMode: Int32, Sendable {
    /// Transformed — smooth transition (default)
    case transformed = 0
    /// Right corner — sharp right-angle transitions
    case rightCorner = 1
    /// Round corner — filleted transitions
    case roundCorner = 2
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

    /// Create a pipe shell with transition mode control.
    ///
    /// Controls how the profile transitions at discontinuities (corners) in the spine.
    ///
    /// - Parameters:
    ///   - spine: Path wire along which to sweep
    ///   - profile: Profile wire to sweep
    ///   - mode: Sweep mode controlling profile orientation
    ///   - transition: How to handle transitions at spine corners
    ///   - solid: If true, create a solid; if false, create a shell
    /// - Returns: Swept shape, or nil on failure
    public static func pipeShellWithTransition(
        spine: Wire,
        profile: Wire,
        mode: PipeSweepMode = .frenet,
        transition: PipeTransitionMode = .transformed,
        solid: Bool = true
    ) -> Shape? {
        let modeInt: Int32 = {
            switch mode {
            case .correctedFrenet: return 1
            default: return 0
            }
        }()
        guard let h = OCCTShapeCreatePipeShellWithTransition(
            spine.handle, profile.handle, modeInt, transition.rawValue, solid
        ) else { return nil }
        return Shape(handle: h)
    }

    // MARK: - Variable-Section Sweep (v0.21.0)

    /// Create a pipe shell with a law function controlling cross-section scaling.
    ///
    /// The law function defines how the profile scales along the spine.
    /// A law value of 1.0 means no scaling; 2.0 means double size, etc.
    public static func pipeShellWithLaw(
        spine: Wire,
        profile: Wire,
        law: LawFunction,
        solid: Bool = true
    ) -> Shape? {
        guard let result = OCCTShapeCreatePipeShellWithLaw(
            spine.handle, profile.handle, law.handle, solid)
        else { return nil }
        return Shape(handle: result)
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

/// Constraint order for advanced plate surface construction (v0.23.0)
public enum PlateConstraintOrder: Int32 {
    /// Position only — surface must pass through the point
    case g0 = 0
    /// Position + tangent — surface must be tangent-continuous
    case g1 = 1
    /// Position + tangent + curvature — surface must be curvature-continuous
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

    // MARK: - Advanced Plate Surfaces (v0.23.0)

    /// Create a plate surface through points with specified constraint orders per point.
    ///
    /// Each point can independently specify G0 (position only), G1 (position + tangent),
    /// or G2 (position + tangent + curvature) continuity.
    ///
    /// - Parameters:
    ///   - points: Array of 3D points the surface must satisfy
    ///   - orders: Constraint order per point (`.g0`, `.g1`, or `.g2`)
    ///   - degree: Maximum polynomial degree (default 3)
    ///   - pointsOnCurves: Number of sample points on curves (default 15)
    ///   - iterations: Number of solver iterations (default 2)
    ///   - tolerance: Approximation tolerance (default 0.01)
    /// - Returns: Surface face, or nil on failure
    public static func plateSurface(
        through points: [SIMD3<Double>],
        orders: [PlateConstraintOrder],
        degree: Int = 3,
        pointsOnCurves: Int = 15,
        iterations: Int = 2,
        tolerance: Double = 0.01
    ) -> Shape? {
        guard points.count >= 3, points.count == orders.count else { return nil }

        var flatPoints: [Double] = []
        for p in points {
            flatPoints.append(p.x)
            flatPoints.append(p.y)
            flatPoints.append(p.z)
        }
        var rawOrders = orders.map { Int32($0.rawValue) }

        guard let result = OCCTShapePlatePointsAdvanced(
            &flatPoints, Int32(points.count),
            &rawOrders, Int32(degree),
            Int32(pointsOnCurves), Int32(iterations),
            tolerance
        ) else { return nil }
        return Shape(handle: result)
    }

    /// Create a plate surface with mixed point and curve constraints.
    ///
    /// Combines point constraints (each with its own continuity order) and
    /// curve constraints (wires with continuity orders) into a single plate surface.
    ///
    /// - Parameters:
    ///   - points: Point constraints with positions and orders
    ///   - curves: Curve constraints with wires and orders
    ///   - degree: Maximum polynomial degree (default 3)
    ///   - tolerance: Approximation tolerance (default 0.01)
    /// - Returns: Surface face, or nil on failure
    public static func plateSurface(
        pointConstraints points: [(point: SIMD3<Double>, order: PlateConstraintOrder)],
        curveConstraints curves: [(wire: Wire, order: PlateConstraintOrder)],
        degree: Int = 3,
        tolerance: Double = 0.01
    ) -> Shape? {
        guard !points.isEmpty || !curves.isEmpty else { return nil }

        var flatPoints: [Double] = []
        var pointOrders: [Int32] = []
        for (p, order) in points {
            flatPoints.append(p.x)
            flatPoints.append(p.y)
            flatPoints.append(p.z)
            pointOrders.append(Int32(order.rawValue))
        }

        var wireHandles = curves.map { $0.wire.handle as OCCTWireRef? }
        var curveOrders = curves.map { Int32($0.order.rawValue) }

        let result: OCCTShapeRef? = flatPoints.withUnsafeMutableBufferPointer { ptBuf in
            pointOrders.withUnsafeMutableBufferPointer { ordBuf in
                wireHandles.withUnsafeMutableBufferPointer { wireBuf in
                    curveOrders.withUnsafeMutableBufferPointer { coBuf in
                        OCCTShapePlateMixed(
                            points.isEmpty ? nil : ptBuf.baseAddress,
                            points.isEmpty ? nil : ordBuf.baseAddress,
                            Int32(points.count),
                            curves.isEmpty ? nil : wireBuf.baseAddress,
                            curves.isEmpty ? nil : coBuf.baseAddress,
                            Int32(curves.count),
                            Int32(degree), tolerance
                        )
                    }
                }
            }
        }
        guard let result else { return nil }
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


// MARK: - Shape Proximity (v0.18.0)

extension Shape {

    /// A pair of face indices detected as near-miss (within tolerance)
    public struct FaceProximityPair: Sendable {
        public let face1Index: Int
        public let face2Index: Int
    }

    /// Detect face pairs between this shape and another that are within tolerance
    public func proximityFaces(with other: Shape, tolerance: Double) -> [FaceProximityPair] {
        var buffer = [OCCTFaceProximityPair](repeating: OCCTFaceProximityPair(), count: 256)
        let count = OCCTShapeProximity(handle, other.handle, tolerance, &buffer, 256)

        var pairs = [FaceProximityPair]()
        for i in 0..<Int(count) {
            pairs.append(FaceProximityPair(
                face1Index: Int(buffer[i].face1Index),
                face2Index: Int(buffer[i].face2Index)
            ))
        }
        return pairs
    }

    /// Check if this shape self-intersects
    public var selfIntersects: Bool {
        OCCTShapeSelfIntersects(handle)
    }
}

// MARK: - Wedge Primitive (v0.29.0)

extension Shape {
    /// Create a wedge (tapered box).
    ///
    /// A wedge is a box whose top face is narrowed in the X direction.
    /// When `ltx` equals `dx`, the result is a regular box.
    /// When `ltx` is 0, the result is a pyramid.
    ///
    /// - Parameters:
    ///   - dx: Width in X
    ///   - dy: Height in Y
    ///   - dz: Depth in Z
    ///   - ltx: Width of top face in X (0 to dx)
    /// - Returns: A wedge solid, or nil on failure
    public static func wedge(dx: Double, dy: Double, dz: Double, ltx: Double) -> Shape? {
        guard dx > 0, dy > 0, dz > 0, ltx >= 0 else { return nil }
        guard let h = OCCTShapeCreateWedge(dx, dy, dz, ltx) else { return nil }
        return Shape(handle: h)
    }

    /// Create an advanced wedge with custom top face bounds.
    ///
    /// - Parameters:
    ///   - dx, dy, dz: Box dimensions
    ///   - xmin, zmin, xmax, zmax: Top face bounds within the box
    /// - Returns: A wedge solid, or nil on failure
    public static func wedge(dx: Double, dy: Double, dz: Double,
                             xmin: Double, zmin: Double,
                             xmax: Double, zmax: Double) -> Shape? {
        guard dx > 0, dy > 0, dz > 0 else { return nil }
        guard let h = OCCTShapeCreateWedgeAdvanced(dx, dy, dz, xmin, zmin, xmax, zmax)
        else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - NURBS Conversion (v0.29.0)

extension Shape {
    /// Convert all curves and surfaces to NURBS representation.
    ///
    /// Useful for ensuring uniform representation before export
    /// or for algorithms that require NURBS geometry.
    ///
    /// - Returns: A new shape with all geometry converted to NURBS, or nil on failure
    public func convertedToNURBS() -> Shape? {
        guard let h = OCCTShapeConvertToNURBS(handle) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Fast Sewing (v0.29.0)

extension Shape {
    /// Sew faces using the fast sewing algorithm.
    ///
    /// Faster than `sewn(tolerance:)` for large models, but may handle
    /// fewer edge cases.
    ///
    /// - Parameter tolerance: Sewing tolerance (default: 1e-6)
    /// - Returns: The sewn shape, or nil on failure
    public func fastSewn(tolerance: Double = 1e-6) -> Shape? {
        guard let h = OCCTShapeFastSewn(handle, tolerance) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Normal Projection (v0.29.0)

extension Shape {
    /// Project a wire or edge onto this shape along surface normals.
    ///
    /// - Parameters:
    ///   - wireOrEdge: The wire or edge to project
    ///   - tolerance3D: 3D tolerance (default: 1e-4)
    ///   - tolerance2D: 2D tolerance (default: 1e-5)
    ///   - maxDegree: Maximum BSpline degree (default: 14)
    ///   - maxSegments: Maximum BSpline segments (default: 16)
    /// - Returns: The projected shape, or nil on failure
    public func normalProjection(of wireOrEdge: Shape,
                                  tolerance3D: Double = 1e-4,
                                  tolerance2D: Double = 1e-5,
                                  maxDegree: Int = 14,
                                  maxSegments: Int = 16) -> Shape? {
        guard let h = OCCTShapeNormalProjection(wireOrEdge.handle, handle,
                                                 tolerance3D, tolerance2D,
                                                 Int32(maxDegree), Int32(maxSegments))
        else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Half-Space (v0.29.0)

extension Shape {
    /// Create a half-space solid from a face.
    ///
    /// A half-space is an infinite solid on one side of a face.
    /// The reference point indicates which side is solid.
    ///
    /// - Parameters:
    ///   - face: A shape containing the dividing face
    ///   - referencePoint: A point on the solid side
    /// - Returns: A half-space solid, or nil on failure
    public static func halfSpace(face: Shape, referencePoint: SIMD3<Double>) -> Shape? {
        guard let h = OCCTShapeCreateHalfSpace(face.handle,
                                                referencePoint.x, referencePoint.y, referencePoint.z)
        else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Sub-Shape Replacement (v0.29.0)

extension Shape {
    /// Replace a sub-shape within this shape.
    ///
    /// - Parameters:
    ///   - oldSubShape: The sub-shape to replace
    ///   - newSubShape: The replacement sub-shape
    /// - Returns: The modified shape, or nil on failure
    public func replacingSubShape(_ oldSubShape: Shape, with newSubShape: Shape) -> Shape? {
        guard let h = OCCTShapeReplaceSubShape(handle, oldSubShape.handle, newSubShape.handle)
        else { return nil }
        return Shape(handle: h)
    }

    /// Remove a sub-shape from this shape.
    ///
    /// - Parameter subShape: The sub-shape to remove
    /// - Returns: The modified shape, or nil on failure
    public func removingSubShape(_ subShape: Shape) -> Shape? {
        guard let h = OCCTShapeRemoveSubShape(handle, subShape.handle) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Periodic Shapes (v0.29.0)

extension Shape {
    /// Make this shape periodic in one or more directions.
    ///
    /// - Parameters:
    ///   - xPeriod: Period in X (nil = not periodic in X)
    ///   - yPeriod: Period in Y (nil = not periodic in Y)
    ///   - zPeriod: Period in Z (nil = not periodic in Z)
    /// - Returns: A periodic shape, or nil on failure
    public func makePeriodic(xPeriod: Double? = nil,
                              yPeriod: Double? = nil,
                              zPeriod: Double? = nil) -> Shape? {
        guard let h = OCCTShapeMakePeriodic(
            handle,
            xPeriod != nil, xPeriod ?? 0,
            yPeriod != nil, yPeriod ?? 0,
            zPeriod != nil, zPeriod ?? 0
        ) else { return nil }
        return Shape(handle: h)
    }

    /// Repeat this shape periodically in one or more directions.
    ///
    /// - Parameters:
    ///   - xPeriod: Period in X (nil = no repetition in X)
    ///   - yPeriod: Period in Y (nil = no repetition in Y)
    ///   - zPeriod: Period in Z (nil = no repetition in Z)
    ///   - xCount: Number of repetitions in X
    ///   - yCount: Number of repetitions in Y
    ///   - zCount: Number of repetitions in Z
    /// - Returns: The repeated shape, or nil on failure
    public func repeated(xPeriod: Double? = nil, xCount: Int = 0,
                          yPeriod: Double? = nil, yCount: Int = 0,
                          zPeriod: Double? = nil, zCount: Int = 0) -> Shape? {
        guard let h = OCCTShapeRepeat(
            handle,
            xPeriod != nil, xPeriod ?? 0,
            yPeriod != nil, yPeriod ?? 0,
            zPeriod != nil, zPeriod ?? 0,
            Int32(xCount), Int32(yCount), Int32(zCount)
        ) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Draft from Shape (v0.29.0)

extension Shape {
    /// Create a draft shell by sweeping this shape along a direction with taper angle.
    ///
    /// - Parameters:
    ///   - direction: Draft direction
    ///   - angle: Taper angle in radians
    ///   - length: Maximum draft length
    /// - Returns: A draft shell shape, or nil on failure
    public func draft(direction: SIMD3<Double>, angle: Double, length: Double) -> Shape? {
        guard let h = OCCTShapeMakeDraft(handle,
                                          direction.x, direction.y, direction.z,
                                          angle, length)
        else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Non-Uniform Scale (v0.30.0)

extension Shape {
    /// Scale this shape non-uniformly along each axis.
    ///
    /// Unlike `scaled(by:)` which applies uniform scaling, this allows
    /// different scale factors for X, Y, and Z axes.
    ///
    /// - Parameters:
    ///   - sx: Scale factor along X axis
    ///   - sy: Scale factor along Y axis
    ///   - sz: Scale factor along Z axis
    /// - Returns: The scaled shape, or nil on failure
    public func nonUniformScaled(sx: Double, sy: Double, sz: Double) -> Shape? {
        guard let h = OCCTShapeNonUniformScale(handle, sx, sy, sz) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Shell & Vertex Creation (v0.30.0)

extension Shape {
    /// Create a shell from a parametric surface.
    ///
    /// Converts a `Surface` to a topological shell shape.
    ///
    /// - Parameter surface: The parametric surface to convert
    /// - Returns: A shell shape, or nil on failure
    public static func shell(from surface: Surface) -> Shape? {
        guard let h = OCCTShapeCreateShellFromSurface(surface.handle) else { return nil }
        return Shape(handle: h)
    }

    /// Create a vertex shape at a point.
    ///
    /// - Parameter point: The 3D point position
    /// - Returns: A vertex shape
    public static func vertex(at point: SIMD3<Double>) -> Shape? {
        guard let h = OCCTShapeCreateVertex(point.x, point.y, point.z) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Simple Offset (v0.30.0)

extension Shape {
    /// Create a simple surface-level offset of this shape.
    ///
    /// Moves each face by a constant distance without filleting intersections.
    /// Faster than `offset(by:)` for thin-wall operations.
    ///
    /// - Parameter distance: Offset distance (positive = outward)
    /// - Returns: The offset shape, or nil on failure
    public func simpleOffset(by distance: Double) -> Shape? {
        guard let h = OCCTShapeSimpleOffset(handle, distance) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Middle Path (v0.30.0)

extension Shape {
    /// Extract the middle (spine) path from a pipe-like shape.
    ///
    /// Given two end faces/wires of a pipe-like shape, computes the
    /// spine wire running through the middle. Useful for reverse-engineering
    /// sweep operations from imported geometry.
    ///
    /// - Parameters:
    ///   - startShape: One end of the pipe (face or wire)
    ///   - endShape: Other end of the pipe (face or wire)
    /// - Returns: The middle path wire, or nil on failure
    public func middlePath(start startShape: Shape, end endShape: Shape) -> Shape? {
        guard let h = OCCTShapeMiddlePath(handle, startShape.handle, endShape.handle) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Fuse Edges (v0.30.0)

extension Shape {
    /// Merge connected edges that lie on the same curve.
    ///
    /// Removes unnecessary edge splits introduced by boolean operations
    /// or other operations, simplifying the topology.
    ///
    /// - Returns: Shape with fused edges, or nil on failure
    public func fusedEdges() -> Shape? {
        guard let h = OCCTShapeFuseEdges(handle) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Volume from Faces (v0.30.0)

extension Shape {
    /// Create a solid volume from a set of overlapping faces/shells.
    ///
    /// Useful for closing open geometry or creating solids from imported face soups.
    ///
    /// - Parameter shapes: Array of face/shell shapes
    /// - Returns: A solid shape, or nil on failure
    public static func makeVolume(from shapes: [Shape]) -> Shape? {
        var handles = shapes.map { $0.handle as OCCTShapeRef? }
        guard let h = OCCTShapeMakeVolume(&handles, Int32(shapes.count)) else { return nil }
        return Shape(handle: h)
    }

    /// Connect separate shapes by making them share common geometry.
    ///
    /// Makes shapes share geometry at coincident boundaries.
    /// Useful for finite element mesh preparation.
    ///
    /// - Parameter shapes: Array of shapes to connect
    /// - Returns: Connected shape, or nil on failure
    public static func makeConnected(_ shapes: [Shape]) -> Shape? {
        var handles = shapes.map { $0.handle as OCCTShapeRef? }
        guard let h = OCCTShapeMakeConnected(&handles, Int32(shapes.count)) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Shape Contents (v0.30.0)

/// Census of sub-shape counts in a shape.
public struct ShapeContents: Sendable {
    public let solids: Int
    public let shells: Int
    public let faces: Int
    public let wires: Int
    public let edges: Int
    public let vertices: Int
    public let freeEdges: Int
    public let freeWires: Int
    public let freeFaces: Int
}

extension Shape {
    /// Get a census of sub-shape counts in this shape.
    ///
    /// Reports topology complexity metrics: counts of solids, shells,
    /// faces, wires, edges, vertices, and free (unconnected) elements.
    public var contents: ShapeContents {
        let c = OCCTShapeGetContents(handle)
        return ShapeContents(
            solids: Int(c.nbSolids), shells: Int(c.nbShells),
            faces: Int(c.nbFaces), wires: Int(c.nbWires),
            edges: Int(c.nbEdges), vertices: Int(c.nbVertices),
            freeEdges: Int(c.nbFreeEdges), freeWires: Int(c.nbFreeWires),
            freeFaces: Int(c.nbFreeFaces)
        )
    }
}

// MARK: - Canonical Recognition (v0.30.0)

/// Recognized canonical geometric form.
public struct CanonicalForm: Sendable {
    /// Type of the recognized form.
    public enum FormType: Int32, Sendable {
        case unknown = 0
        case plane = 1
        case cylinder = 2
        case cone = 3
        case sphere = 4
        case line = 5
        case circle = 6
        case ellipse = 7
    }

    public let type: FormType
    public let origin: SIMD3<Double>
    public let direction: SIMD3<Double>
    public let radius: Double
    public let radius2: Double
    public let gap: Double
}

extension Shape {
    /// Recognize canonical geometric forms in this shape.
    ///
    /// Identifies whether the shape's geometry matches a canonical
    /// form (plane, cylinder, cone, sphere, line, circle, ellipse).
    ///
    /// - Parameter tolerance: Recognition tolerance
    /// - Returns: The recognized form, or nil if no canonical form found
    public func recognizeCanonical(tolerance: Double = 1e-4) -> CanonicalForm? {
        let r = OCCTShapeRecognizeCanonical(handle, tolerance)
        guard let formType = CanonicalForm.FormType(rawValue: r.type), formType != .unknown else { return nil }
        return CanonicalForm(
            type: formType,
            origin: SIMD3(r.origin.0, r.origin.1, r.origin.2),
            direction: SIMD3(r.direction.0, r.direction.1, r.direction.2),
            radius: r.radius, radius2: r.radius2, gap: r.gap
        )
    }
}

// MARK: - Find Surface (v0.30.0)

extension Shape {
    /// Find the underlying surface of a shape (edges or wire).
    ///
    /// Determines the best-fit surface for a set of edges or a wire.
    /// Useful for reconstructing faces from imported wireframes.
    ///
    /// - Parameter tolerance: Surface fitting tolerance
    /// - Returns: The found surface, or nil
    public func findSurface(tolerance: Double = -1) -> Surface? {
        guard let h = OCCTShapeFindSurface(handle, tolerance) else { return nil }
        return Surface(handle: h)
    }
}

// MARK: - Fix Wireframe (v0.30.0)

extension Shape {
    /// Fix wireframe issues (small edges, gaps).
    ///
    /// - Parameter tolerance: Fixing tolerance
    /// - Returns: Shape with fixed wireframe, or nil on failure
    public func fixedWireframe(tolerance: Double = 1e-4) -> Shape? {
        guard let h = OCCTShapeFixWireframe(handle, tolerance) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Remove Internal Wires (v0.30.0)

extension Shape {
    /// Remove internal wires (holes) smaller than a minimum area.
    ///
    /// - Parameter minArea: Minimum area threshold for holes to keep
    /// - Returns: Shape with small holes removed, or nil on failure
    public func removingInternalWires(minArea: Double) -> Shape? {
        guard let h = OCCTShapeRemoveInternalWires(handle, minArea) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Contiguous Edges (v0.30.0)

extension Shape {
    /// Find pairs of edges that are coincident within tolerance.
    ///
    /// Useful for pre-sewing diagnostics to identify edges that
    /// could be merged.
    ///
    /// - Parameter tolerance: Contiguity tolerance
    /// - Returns: Number of contiguous edge pairs found
    public func contiguousEdgeCount(tolerance: Double = 1e-6) -> Int {
        Int(OCCTShapeFindContiguousEdges(handle, tolerance))
    }
}

// MARK: - Quilt Faces (v0.31.0)

extension Shape {
    /// Quilt multiple shapes (faces/shells) together into a single shell.
    ///
    /// Joins faces that share common edges into a connected shell.
    ///
    /// - Parameter shapes: Array of shapes to quilt together
    /// - Returns: Quilted shell, or nil on failure
    public static func quilt(_ shapes: [Shape]) -> Shape? {
        var handles = shapes.map { $0.handle as OCCTShapeRef? }
        guard let h = OCCTShapeQuilt(&handles, Int32(shapes.count)) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Fix Small Faces (v0.31.0)

extension Shape {
    /// Fix small faces by removing or merging them.
    ///
    /// - Parameter tolerance: Precision tolerance for identifying small faces
    /// - Returns: Shape with small faces fixed, or nil on failure
    public func fixingSmallFaces(tolerance: Double = 1e-4) -> Shape? {
        guard let h = OCCTShapeFixSmallFaces(handle, tolerance) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Remove Locations (v0.31.0)

extension Shape {
    /// Remove all location transforms, baking them into the geometry.
    ///
    /// Converts a shape with nested transforms into an equivalent shape
    /// where all geometry coordinates are in the global frame.
    ///
    /// - Returns: Shape with locations removed, or nil on failure
    public func removingLocations() -> Shape? {
        guard let h = OCCTShapeRemoveLocations(handle) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Revolution from Curve (v0.31.0)

extension Shape {
    /// Create a solid of revolution by revolving a meridian curve.
    ///
    /// Unlike `revolution(profile:...)` which takes a wire profile,
    /// this creates a revolution directly from a `Geom_Curve`.
    ///
    /// - Parameters:
    ///   - meridian: The curve to revolve
    ///   - axisOrigin: Origin point of the revolution axis
    ///   - axisDirection: Direction of the revolution axis
    ///   - angle: Revolution angle in radians (default: full revolution)
    /// - Returns: Revolved shape, or nil on failure
    public static func revolution(meridian: Curve3D,
                                  axisOrigin: SIMD3<Double> = .zero,
                                  axisDirection: SIMD3<Double> = SIMD3<Double>(0, 0, 1),
                                  angle: Double = 2 * .pi) -> Shape? {
        guard let h = OCCTShapeCreateRevolutionFromCurve(
            meridian.handle,
            axisOrigin.x, axisOrigin.y, axisOrigin.z,
            axisDirection.x, axisDirection.y, axisDirection.z,
            angle) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Linear Rib Feature (v0.31.0)

extension Shape {
    /// Add a linear rib feature to a shape.
    ///
    /// Creates a rib (reinforcement) or slot by extruding a wire profile
    /// in the given direction on the base shape.
    ///
    /// - Parameters:
    ///   - profile: The wire profile of the rib
    ///   - direction: Extrusion direction of the rib
    ///   - draftDirection: Secondary direction controlling draft angle
    ///   - fuse: true to add material (rib), false to remove material (slot)
    /// - Returns: Shape with rib/slot added, or nil on failure
    public func addingLinearRib(profile: Wire,
                                direction: SIMD3<Double>,
                                draftDirection: SIMD3<Double>,
                                fuse: Bool = true) -> Shape? {
        guard let h = OCCTShapeAddLinearRib(
            handle, profile.handle,
            direction.x, direction.y, direction.z,
            draftDirection.x, draftDirection.y, draftDirection.z,
            fuse) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Offset Join Type (v0.32.0)

/// Join type for offset operations.
public enum OffsetJoinType: Int32, Sendable {
    /// Arc — fill gaps with pipe arcs and spheres (smooth, rounded)
    case arc = 0
    /// Tangent — tangent extension of faces
    case tangent = 1
    /// Intersection — extend and intersect adjacent faces (sharp edges)
    case intersection = 2
}

// MARK: - Revolution Form Feature (v0.32.0)

extension Shape {
    /// Add a revolution form (revolved rib or groove) to a shape.
    ///
    /// Similar to `addingLinearRib`, but the rib follows a rotational
    /// path around the given axis.
    ///
    /// - Parameters:
    ///   - profile: Wire profile of the rib
    ///   - axisOrigin: Origin of the revolution axis
    ///   - axisDirection: Direction of the revolution axis
    ///   - height1: Height on one side
    ///   - height2: Height on the other side
    ///   - fuse: true for rib (add material), false for groove (remove material)
    /// - Returns: Shape with revolution form, or nil on failure
    public func addingRevolutionForm(profile: Wire,
                                     axisOrigin: SIMD3<Double>,
                                     axisDirection: SIMD3<Double>,
                                     height1: Double, height2: Double,
                                     fuse: Bool = true) -> Shape? {
        guard let h = OCCTShapeAddRevolutionForm(
            handle, profile.handle,
            axisOrigin.x, axisOrigin.y, axisOrigin.z,
            axisDirection.x, axisDirection.y, axisDirection.z,
            height1, height2, fuse) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Draft Prism Feature (v0.32.0)

extension Shape {
    /// Add a draft prism (tapered extrusion) to a shape.
    ///
    /// Creates a boss or pocket with draft angle (taper), commonly used
    /// in injection mold design.
    ///
    /// - Parameters:
    ///   - profile: Wire profile to extrude
    ///   - sketchFaceIndex: 0-based index of the face on which the profile sits
    ///   - draftAngle: Draft angle in degrees
    ///   - height: Extrusion height
    ///   - fuse: true to add material (boss), false to cut (pocket)
    /// - Returns: Shape with draft prism, or nil on failure
    public func addingDraftPrism(profile: Wire, sketchFaceIndex: Int,
                                 draftAngle: Double, height: Double,
                                 fuse: Bool = true) -> Shape? {
        guard let h = OCCTShapeDraftPrism(handle, Int32(sketchFaceIndex),
                                           profile.handle, draftAngle,
                                           height, fuse) else { return nil }
        return Shape(handle: h)
    }

    /// Add a draft prism that extends through the entire shape.
    ///
    /// - Parameters:
    ///   - profile: Wire profile to extrude
    ///   - sketchFaceIndex: 0-based index of the face on which the profile sits
    ///   - draftAngle: Draft angle in degrees
    ///   - fuse: true to add material, false to cut
    /// - Returns: Shape with draft prism, or nil on failure
    public func addingDraftPrismThruAll(profile: Wire, sketchFaceIndex: Int,
                                        draftAngle: Double,
                                        fuse: Bool = true) -> Shape? {
        guard let h = OCCTShapeDraftPrismThruAll(handle, Int32(sketchFaceIndex),
                                                  profile.handle, draftAngle,
                                                  fuse) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Revolution Feature (v0.32.0)

extension Shape {
    /// Add a revolved feature (boss or pocket) to a shape.
    ///
    /// Revolves a profile around an axis to add or remove material.
    /// Commonly used for turned parts (lathe operations).
    ///
    /// - Parameters:
    ///   - profile: Wire profile to revolve
    ///   - sketchFaceIndex: 0-based index of the face on which the profile sits
    ///   - axisOrigin: Origin of the revolution axis
    ///   - axisDirection: Direction of the revolution axis
    ///   - angle: Revolution angle in degrees
    ///   - fuse: true to add material (boss), false to cut (pocket)
    /// - Returns: Shape with revolved feature, or nil on failure
    public func addingRevolvedFeature(profile: Wire, sketchFaceIndex: Int,
                                      axisOrigin: SIMD3<Double>,
                                      axisDirection: SIMD3<Double>,
                                      angle: Double = 360,
                                      fuse: Bool = true) -> Shape? {
        guard let h = OCCTShapeRevolFeature(handle, Int32(sketchFaceIndex),
                                             profile.handle,
                                             axisOrigin.x, axisOrigin.y, axisOrigin.z,
                                             axisDirection.x, axisDirection.y, axisDirection.z,
                                             angle, fuse) else { return nil }
        return Shape(handle: h)
    }

    /// Add a revolved feature that revolves through 360 degrees.
    ///
    /// - Parameters:
    ///   - profile: Wire profile to revolve
    ///   - sketchFaceIndex: 0-based index of the face on which the profile sits
    ///   - axisOrigin: Origin of the revolution axis
    ///   - axisDirection: Direction of the revolution axis
    ///   - fuse: true to add material, false to cut
    /// - Returns: Shape with revolved feature, or nil on failure
    public func addingRevolvedFeatureThruAll(profile: Wire, sketchFaceIndex: Int,
                                             axisOrigin: SIMD3<Double>,
                                             axisDirection: SIMD3<Double>,
                                             fuse: Bool = true) -> Shape? {
        guard let h = OCCTShapeRevolFeatureThruAll(handle, Int32(sketchFaceIndex),
                                                    profile.handle,
                                                    axisOrigin.x, axisOrigin.y, axisOrigin.z,
                                                    axisDirection.x, axisDirection.y, axisDirection.z,
                                                    fuse) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Face from Surface (v0.33.0)

extension Shape {
    /// Create a face from a surface with specific UV parameter bounds.
    ///
    /// - Parameters:
    ///   - surface: The parametric surface
    ///   - uRange: U parameter range (uMin, uMax)
    ///   - vRange: V parameter range (vMin, vMax)
    ///   - tolerance: Tolerance for face creation
    /// - Returns: Face shape, or nil on failure
    public static func face(from surface: Surface,
                            uRange: ClosedRange<Double>,
                            vRange: ClosedRange<Double>,
                            tolerance: Double = 1e-6) -> Shape? {
        guard let h = OCCTShapeCreateFaceFromSurface(surface.handle,
                                                      uRange.lowerBound, uRange.upperBound,
                                                      vRange.lowerBound, vRange.upperBound,
                                                      tolerance) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Edges to Faces (v0.33.0)

extension Shape {
    /// Reconstruct faces from a compound of loose edges.
    ///
    /// Takes a shape containing edges and tries to build closed wires,
    /// then creates faces from those wires.
    ///
    /// - Parameters:
    ///   - compound: Shape containing edges to assemble into faces
    ///   - onlyPlanar: If true, only create planar faces
    /// - Returns: Compound of faces, or nil on failure
    public static func facesFromEdges(_ compound: Shape, onlyPlanar: Bool = true) -> Shape? {
        guard let h = OCCTShapeEdgesToFaces(compound.handle, onlyPlanar) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Shape-to-Shape Section (v0.34.0)

extension Shape {
    /// Compute the intersection curves/edges between two shapes.
    ///
    /// Returns the intersection geometry (edges/wires) where the two shapes overlap.
    /// Useful for finding contact curves, trim boundaries, and interference analysis.
    ///
    /// - Parameter other: The second shape to intersect with
    /// - Returns: Shape containing intersection edges, or nil on failure
    public func section(with other: Shape) -> Shape? {
        guard let h = OCCTShapeSection(handle, other.handle) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Boolean Pre-Validation (v0.34.0)

extension Shape {
    /// Check whether this shape is valid for boolean operations.
    ///
    /// - Returns: true if the shape is suitable for boolean operations
    public var isValidForBoolean: Bool {
        OCCTShapeBooleanCheck(handle, nil)
    }

    /// Check whether two shapes are valid for boolean operations with each other.
    ///
    /// - Parameter other: The other shape to check compatibility with
    /// - Returns: true if both shapes are suitable for boolean operations together
    public func isValidForBoolean(with other: Shape) -> Bool {
        OCCTShapeBooleanCheck(handle, other.handle)
    }
}

// MARK: - Split Shape by Wire (v0.34.0)

extension Shape {
    /// Split a face by imprinting a wire onto it.
    ///
    /// The wire is projected/imprinted onto the specified face, dividing it
    /// into multiple faces. Useful for mesh preparation and feature line imprinting.
    ///
    /// - Parameters:
    ///   - wire: Wire to imprint onto the face
    ///   - faceIndex: 0-based index of the face to split
    /// - Returns: Shape with the face split by the wire, or nil on failure
    public func splittingFace(with wire: Wire, faceIndex: Int) -> Shape? {
        guard let h = OCCTShapeSplitByWire(handle, wire.handle, Int32(faceIndex)) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Split by Angle (v0.34.0)

extension Shape {
    /// Split surfaces that span more than a specified angle.
    ///
    /// Useful for export to systems that cannot handle full 360° surfaces
    /// (e.g., splitting a full cylinder into quarter-cylinders with maxAngle=90).
    ///
    /// - Parameter maxAngleDegrees: Maximum angle in degrees (e.g., 90 for quarter-turns)
    /// - Returns: Shape with surfaces split at angle boundaries, or nil on failure
    public func splitByAngle(_ maxAngleDegrees: Double) -> Shape? {
        guard let h = OCCTShapeSplitByAngle(handle, maxAngleDegrees) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Drop Small Edges (v0.34.0)

extension Shape {
    /// Remove degenerate/tiny edges from a shape.
    ///
    /// Useful for cleaning up imported geometry with tolerance issues.
    ///
    /// - Parameter tolerance: Tolerance below which edges are considered small
    /// - Returns: Shape with small edges removed, or nil on failure
    public func droppingSmallEdges(tolerance: Double = 1e-6) -> Shape? {
        guard let h = OCCTShapeDropSmallEdges(handle, tolerance) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Multi-Tool Boolean Fuse (v0.34.0)

extension Shape {
    /// Fuse multiple shapes simultaneously.
    ///
    /// More robust than sequential pairwise `union(with:)` calls, as it avoids
    /// intermediate tolerance issues and processes all intersections at once.
    ///
    /// - Parameter shapes: Array of shapes to fuse together
    /// - Returns: Fused shape, or nil on failure
    public static func fuseAll(_ shapes: [Shape]) -> Shape? {
        guard shapes.count >= 2 else { return nil }
        let handles: [OCCTShapeRef?] = shapes.map { $0.handle }
        let result = handles.withUnsafeBufferPointer { buffer in
            OCCTShapeFuseMulti(buffer.baseAddress, Int32(shapes.count))
        }
        guard let h = result else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Multi-Offset Wire (v0.35.0)

extension Shape {
    /// Generate multiple parallel offset wires from a planar face boundary.
    ///
    /// More efficient than calling `Wire.offset` multiple times, and produces
    /// consistent results for CNC toolpath generation.
    ///
    /// - Parameters:
    ///   - offsets: Array of offset distances (positive = outward, negative = inward)
    ///   - joinType: How to join offset segments (default: .arc)
    /// - Returns: Array of offset wires
    public func multiOffsetWires(offsets: [Double],
                                 joinType: OffsetJoinType = .arc) -> [Wire] {
        guard !offsets.isEmpty else { return [] }
        let maxWires = offsets.count * 10 // Allow for multi-contour results
        var wireRefs = [OCCTWireRef?](repeating: nil, count: maxWires)
        let count = offsets.withUnsafeBufferPointer { offsetBuf in
            wireRefs.withUnsafeMutableBufferPointer { wireBuf in
                OCCTWireMultiOffset(handle, offsetBuf.baseAddress, Int32(offsets.count),
                                    joinType.rawValue, wireBuf.baseAddress, Int32(maxWires))
            }
        }
        return (0..<Int(count)).compactMap { i in
            guard let ref = wireRefs[i] else { return nil }
            return Wire(handle: ref)
        }
    }
}

// MARK: - Cylindrical Projection (v0.35.0)

extension Shape {
    /// Project a wire/edge shape onto another shape along a direction (cylindrical projection).
    ///
    /// - Parameters:
    ///   - wire: Wire or edge shape to project
    ///   - target: Target shape to project onto
    ///   - direction: Projection direction
    /// - Returns: Compound of projected wires, or nil on failure
    public static func projectWire(_ wire: Shape, onto target: Shape,
                                   direction: SIMD3<Double>) -> Shape? {
        guard let h = OCCTShapeProjectWire(wire.handle, target.handle,
                                            direction.x, direction.y, direction.z) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Same Parameter (v0.35.0)

extension Shape {
    /// Enforce same-parameter consistency on the shape.
    ///
    /// Ensures 3D and 2D curve representations are consistent. Important
    /// for imported geometry and after complex operations.
    ///
    /// - Parameter tolerance: Tolerance for same-parameter check
    /// - Returns: Fixed shape, or nil on failure
    public func sameParameter(tolerance: Double = 1e-6) -> Shape? {
        guard let h = OCCTShapeSameParameter(handle, tolerance) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Conical Projection (v0.36.0)

extension Shape {
    /// Project a wire/edge shape onto another shape from a point (conical projection).
    ///
    /// Unlike cylindrical projection (parallel rays), conical projection fans out
    /// from a point source, like a spotlight or perspective camera.
    ///
    /// - Parameters:
    ///   - wire: Wire or edge shape to project
    ///   - target: Target shape to project onto
    ///   - eye: Point source of projection rays
    /// - Returns: Compound of projected wires, or nil on failure
    public static func projectWireConical(_ wire: Shape, onto target: Shape,
                                          eye: SIMD3<Double>) -> Shape? {
        guard let h = OCCTShapeProjectWireConical(wire.handle, target.handle,
                                                   eye.x, eye.y, eye.z) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Encode Regularity (v0.36.0)

extension Shape {
    /// Mark smooth (G1-continuous) edges as "regular."
    ///
    /// Downstream algorithms can skip regular edges for better performance.
    /// The angular tolerance controls what is considered "smooth."
    ///
    /// - Parameter toleranceDegrees: Angular tolerance in degrees (default: 1e-10)
    /// - Returns: Shape with regularity encoded, or nil on failure
    public func encodingRegularity(toleranceDegrees: Double = 1e-10) -> Shape? {
        guard let h = OCCTShapeEncodeRegularity(handle, toleranceDegrees) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Update Tolerances (v0.36.0)

extension Shape {
    /// Recalculate and update geometric tolerances on the shape.
    ///
    /// - Parameter verifyFaces: Whether to verify and correct face tolerances
    /// - Returns: Shape with updated tolerances, or nil on failure
    public func updatingTolerances(verifyFaces: Bool = true) -> Shape? {
        guard let h = OCCTShapeUpdateTolerances(handle, verifyFaces) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Divide by Number (v0.36.0)

extension Shape {
    /// Split faces into approximately the specified number of patches.
    ///
    /// Useful for mesh preparation and parametric surface subdivision.
    ///
    /// - Parameter parts: Approximate number of patches per face
    /// - Returns: Shape with divided faces, or nil on failure
    public func dividedByNumber(_ parts: Int) -> Shape? {
        guard parts > 1 else { return nil }
        guard let h = OCCTShapeDivideByNumber(handle, Int32(parts), 1) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Boolean with History (v0.36.0)

/// Result of a boolean operation with shape tracking.
public struct BooleanResult: Sendable {
    /// The result shape
    public let shape: Shape
    /// Shapes in the result that are modifications of faces from the first operand
    public let modifiedFaces: [Shape]
}

extension Shape {
    /// Fuse this shape with another and track which faces were modified.
    ///
    /// - Parameter other: Shape to fuse with
    /// - Returns: Boolean result with modified face tracking, or nil on failure
    public func fuseWithHistory(_ other: Shape) -> BooleanResult? {
        let maxModified: Int32 = 256
        var modRefs = [OCCTShapeRef?](repeating: nil, count: Int(maxModified))
        let count = modRefs.withUnsafeMutableBufferPointer { buf in
            OCCTShapeFuseWithHistory(handle, other.handle, buf.baseAddress, maxModified)
        }
        guard count >= 0 else { return nil }
        // The fuse result is the union
        guard let fused = self.union(with: other) else { return nil }
        let modified = (0..<Int(count)).compactMap { i -> Shape? in
            guard let ref = modRefs[i] else { return nil }
            return Shape(handle: ref)
        }
        return BooleanResult(shape: fused, modifiedFaces: modified)
    }
}

// MARK: - Thick Solid / Hollowing (v0.37.0)

extension Shape {
    /// Create a hollowed (thick) solid by removing faces and offsetting inward.
    ///
    /// Removes the specified faces and creates a shell with uniform wall thickness.
    /// The removed faces become openings in the resulting hollow shape.
    ///
    /// - Parameters:
    ///   - faceIndices: 0-based indices of faces to remove (become openings)
    ///   - thickness: Wall thickness (positive = offset inward)
    ///   - tolerance: Tolerance for the operation
    ///   - joinType: How to join offset edges (default: .arc)
    /// - Returns: Hollowed solid, or nil on failure
    public func hollowed(removingFaces faceIndices: [Int],
                         thickness: Double,
                         tolerance: Double = 1e-3,
                         joinType: OffsetJoinType = .arc) -> Shape? {
        guard !faceIndices.isEmpty else { return nil }
        let indices = faceIndices.map { Int32($0) }
        let result = indices.withUnsafeBufferPointer { buf in
            OCCTShapeMakeThickSolid(handle, buf.baseAddress, Int32(faceIndices.count),
                                     thickness, tolerance, joinType.rawValue)
        }
        guard let h = result else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Shell from Surface (v0.37.0)

extension Shape {
    /// Create a shell from a parametric surface with UV bounds.
    ///
    /// - Parameters:
    ///   - surface: The parametric surface
    ///   - uRange: U parameter range
    ///   - vRange: V parameter range
    /// - Returns: Shell shape, or nil on failure
    public static func shell(from surface: Surface,
                             uRange: ClosedRange<Double>,
                             vRange: ClosedRange<Double>) -> Shape? {
        guard let h = OCCTShapeMakeShell(surface.handle,
                                          uRange.lowerBound, uRange.upperBound,
                                          vRange.lowerBound, vRange.upperBound) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Multi-Tool Boolean Common (v0.37.0)

extension Shape {
    /// Compute the common (intersection) of multiple shapes simultaneously.
    ///
    /// - Parameter shapes: Array of shapes to intersect
    /// - Returns: Common shape (intersection of all), or nil on failure
    public static func commonAll(_ shapes: [Shape]) -> Shape? {
        guard shapes.count >= 2 else { return nil }
        let handles: [OCCTShapeRef?] = shapes.map { $0.handle }
        let result = handles.withUnsafeBufferPointer { buffer in
            OCCTShapeCommonMulti(buffer.baseAddress, Int32(shapes.count))
        }
        guard let h = result else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Oriented Bounding Box (v0.38.0)

/// An oriented (rotated) bounding box that fits tightly around a shape.
public struct OrientedBoundingBox: Sendable {
    /// Center of the bounding box.
    public var center: SIMD3<Double>
    /// X-axis direction of the box.
    public var xDirection: SIMD3<Double>
    /// Y-axis direction of the box.
    public var yDirection: SIMD3<Double>
    /// Z-axis direction of the box.
    public var zDirection: SIMD3<Double>
    /// Half-dimensions along each axis.
    public var halfSizes: SIMD3<Double>

    /// Volume of the bounding box.
    public var volume: Double { 8.0 * halfSizes.x * halfSizes.y * halfSizes.z }

    /// Full dimensions of the bounding box.
    public var dimensions: SIMD3<Double> { 2.0 * halfSizes }
}

extension Shape {
    /// Compute an oriented (tight-fit, rotated) bounding box.
    ///
    /// - Parameter optimal: If true, compute a tighter OBB (slower). Default is false.
    /// - Returns: The oriented bounding box, or nil on failure.
    public func orientedBoundingBox(optimal: Bool = false) -> OrientedBoundingBox? {
        var result = OCCTOrientedBoundingBox()
        guard OCCTShapeOrientedBoundingBox(handle, optimal, &result) else { return nil }
        return OrientedBoundingBox(
            center: SIMD3(result.centerX, result.centerY, result.centerZ),
            xDirection: SIMD3(result.xDirX, result.xDirY, result.xDirZ),
            yDirection: SIMD3(result.yDirX, result.yDirY, result.yDirZ),
            zDirection: SIMD3(result.zDirX, result.zDirY, result.zDirZ),
            halfSizes: SIMD3(result.halfX, result.halfY, result.halfZ)
        )
    }

    /// Get the 8 corners of the oriented bounding box.
    ///
    /// - Parameter optimal: If true, compute a tighter OBB. Default is false.
    /// - Returns: Array of 8 corner points, or nil on failure.
    public func orientedBoundingBoxCorners(optimal: Bool = false) -> [SIMD3<Double>]? {
        var obb = OCCTOrientedBoundingBox()
        guard OCCTShapeOrientedBoundingBox(handle, optimal, &obb) else { return nil }
        var corners = [Double](repeating: 0, count: 24)
        OCCTOrientedBoundingBoxCorners(&obb, &corners)
        var result = [SIMD3<Double>]()
        result.reserveCapacity(8)
        for i in stride(from: 0, to: 24, by: 3) {
            result.append(SIMD3(corners[i], corners[i+1], corners[i+2]))
        }
        return result
    }
}

// MARK: - Deep Shape Copy (v0.38.0)

extension Shape {
    /// Create a deep, independent copy of this shape.
    ///
    /// - Parameters:
    ///   - copyGeometry: If true, copy the underlying geometry (default: true).
    ///   - copyMesh: If true, also copy mesh data (default: false).
    /// - Returns: A new independent shape, or nil on failure.
    public func copy(copyGeometry: Bool = true, copyMesh: Bool = false) -> Shape? {
        guard let h = OCCTShapeCopy(handle, copyGeometry, copyMesh) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Sub-Shape Extraction (v0.38.0)

extension Shape {
    /// Number of solid sub-shapes.
    public var solidCount: Int { Int(OCCTShapeGetSolidCount(handle)) }

    /// Extract all solid sub-shapes.
    public var solids: [Shape] {
        let count = OCCTShapeGetSolidCount(handle)
        guard count > 0 else { return [] }
        var handles = [OCCTShapeRef?](repeating: nil, count: Int(count))
        let actual = OCCTShapeGetSolids(handle, &handles, count)
        return handles.prefix(Int(actual)).compactMap { h in
            h.map { Shape(handle: $0) }
        }
    }

    /// Number of shell sub-shapes.
    public var shellCount: Int { Int(OCCTShapeGetShellCount(handle)) }

    /// Extract all shell sub-shapes.
    public var shells: [Shape] {
        let count = OCCTShapeGetShellCount(handle)
        guard count > 0 else { return [] }
        var handles = [OCCTShapeRef?](repeating: nil, count: Int(count))
        let actual = OCCTShapeGetShells(handle, &handles, count)
        return handles.prefix(Int(actual)).compactMap { h in
            h.map { Shape(handle: $0) }
        }
    }

    /// Number of wire sub-shapes.
    public var wireCount: Int { Int(OCCTShapeGetWireCount(handle)) }

    /// Extract all wire sub-shapes.
    public var wires: [Shape] {
        let count = OCCTShapeGetWireCount(handle)
        guard count > 0 else { return [] }
        var handles = [OCCTShapeRef?](repeating: nil, count: Int(count))
        let actual = OCCTShapeGetWires(handle, &handles, count)
        return handles.prefix(Int(actual)).compactMap { h in
            h.map { Shape(handle: $0) }
        }
    }
}

// MARK: - Fuse and Blend (v0.38.0)

extension Shape {
    /// Fuse with another shape and fillet the intersection edges.
    ///
    /// - Parameters:
    ///   - other: Shape to fuse with.
    ///   - radius: Fillet radius for intersection edges.
    /// - Returns: Fused and filleted shape, or nil on failure.
    public func fusedAndBlended(with other: Shape, radius: Double) -> Shape? {
        guard let h = OCCTShapeFuseAndBlend(handle, other.handle, radius) else { return nil }
        return Shape(handle: h)
    }

    /// Cut another shape and fillet the intersection edges.
    ///
    /// - Parameters:
    ///   - other: Shape to cut from this shape.
    ///   - radius: Fillet radius for intersection edges.
    /// - Returns: Cut and filleted shape, or nil on failure.
    public func cutAndBlended(with other: Shape, radius: Double) -> Shape? {
        guard let h = OCCTShapeCutAndBlend(handle, other.handle, radius) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Multi-Edge Evolving Fillet (v0.38.0)

/// Describes an evolving radius along an edge for filleting.
public struct EvolvingFilletEdge: Sendable {
    /// 1-based edge index.
    public var edgeIndex: Int
    /// Array of (parameter, radius) pairs defining the radius evolution along the edge.
    public var radiusPoints: [(parameter: Double, radius: Double)]

    public init(edgeIndex: Int, radiusPoints: [(parameter: Double, radius: Double)]) {
        self.edgeIndex = edgeIndex
        self.radiusPoints = radiusPoints
    }
}

extension Shape {
    /// Apply evolving-radius fillets to multiple edges simultaneously.
    ///
    /// - Parameter edges: Array of edge specifications with radius evolution.
    /// - Returns: Filleted shape, or nil on failure.
    public func filletEvolving(_ edges: [EvolvingFilletEdge]) -> Shape? {
        guard !edges.isEmpty else { return nil }

        let edgeIndices = edges.map { Int32($0.edgeIndex) }
        let pointCounts = edges.map { Int32($0.radiusPoints.count) }
        var radiusPoints = [OCCTFilletRadiusPoint]()
        for edge in edges {
            for rp in edge.radiusPoints {
                radiusPoints.append(OCCTFilletRadiusPoint(parameter: rp.parameter, radius: rp.radius))
            }
        }

        guard let h = OCCTShapeFilletEvolving(handle, edgeIndices, Int32(edges.count),
                                               radiusPoints, pointCounts) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Per-Face Variable Offset (v0.38.0)

extension Shape {
    /// Offset a shape with different distances per face.
    ///
    /// - Parameters:
    ///   - defaultOffset: Default offset distance for all faces.
    ///   - faceOffsets: Dictionary mapping 1-based face indices to custom offset distances.
    ///   - tolerance: Offset tolerance (default: 1e-3).
    ///   - joinType: Join type for offset gaps (default: .arc).
    /// - Returns: Offset shape, or nil on failure.
    public func offsetPerFace(defaultOffset: Double,
                               faceOffsets: [Int: Double],
                               tolerance: Double = 1e-3,
                               joinType: OffsetJoinType = .arc) -> Shape? {
        let indices = Array(faceOffsets.keys).map { Int32($0) }
        let offsets = Array(faceOffsets.keys).map { faceOffsets[$0]! }

        guard let h = OCCTShapeOffsetPerFace(handle, defaultOffset,
                                              indices, offsets,
                                              Int32(faceOffsets.count),
                                              tolerance, Int32(joinType.rawValue)) else { return nil }
        return Shape(handle: h)
    }

    // MARK: - Free Boundary Analysis (v0.39.0)

    /// Result of free boundary analysis
    public struct FreeBoundsResult: Sendable {
        /// Compound shape containing all free boundary wires
        public let wires: Shape
        /// Number of closed free boundary wires
        public let closedCount: Int
        /// Number of open free boundary wires
        public let openCount: Int
    }

    /// Analyze free boundary wires (open edges not shared by two faces).
    ///
    /// Free boundaries indicate gaps in a shell. A watertight shell has no free boundaries.
    /// - Parameter sewingTolerance: Tolerance for grouping free edges into wires
    /// - Returns: Free bounds result, or nil if no free boundaries found
    public func freeBounds(sewingTolerance: Double = 1e-6) -> FreeBoundsResult? {
        var closedCount: Int32 = 0
        var openCount: Int32 = 0
        guard let h = OCCTShapeFreeBounds(handle, sewingTolerance,
                                           &closedCount, &openCount) else { return nil }
        return FreeBoundsResult(wires: Shape(handle: h),
                                closedCount: Int(closedCount),
                                openCount: Int(openCount))
    }

    /// Fix free boundary wires by closing gaps.
    ///
    /// - Parameters:
    ///   - sewingTolerance: Tolerance for sewing free edges
    ///   - closingTolerance: Maximum distance to close a gap
    /// - Returns: Tuple of (fixed shape, number of wires fixed), or nil on failure
    public func fixedFreeBounds(sewingTolerance: Double = 1e-6,
                                 closingTolerance: Double = 1e-4) -> (shape: Shape, fixedCount: Int)? {
        var fixedCount: Int32 = 0
        guard let h = OCCTShapeFixFreeBounds(handle, sewingTolerance,
                                              closingTolerance, &fixedCount) else { return nil }
        return (shape: Shape(handle: h), fixedCount: Int(fixedCount))
    }

    // MARK: - Pipe Feature (v0.39.0)

    /// Create a pipe feature by sweeping a profile along a spine, fused with or cut from this shape.
    ///
    /// - Parameters:
    ///   - profile: Profile shape (face) to sweep along the spine
    ///   - sketchFaceIndex: Index (0-based) of the face on this shape where the profile sits
    ///   - spine: Wire defining the sweep path
    ///   - fuse: If true, add material; if false, remove material
    /// - Returns: Modified shape, or nil on failure
    public func pipeFeature(profile: Shape, sketchFaceIndex: Int,
                            spine: Wire, fuse: Bool = true) -> Shape? {
        guard let h = OCCTShapePipeFeatureFromProfile(
            handle, profile.handle, Int32(sketchFaceIndex),
            spine.handle, fuse ? 1 : 0
        ) else { return nil }
        return Shape(handle: h)
    }

    // MARK: - Semi-Infinite Extrusion (v0.39.0)

    /// Extrude a shape semi-infinitely in a direction.
    ///
    /// Creates a solid that extends infinitely in one direction from the profile.
    /// Useful for half-spaces and trimming operations.
    /// - Parameters:
    ///   - direction: Direction of extrusion
    ///   - infinite: If true, extrude in both directions (infinite); if false, one direction (semi-infinite)
    /// - Returns: Extruded shape, or nil on failure
    public func extrudedSemiInfinite(direction: SIMD3<Double>, infinite: Bool = false) -> Shape? {
        guard let h = OCCTShapeExtrudeSemiInfinite(handle,
                                                    direction.x, direction.y, direction.z,
                                                    !infinite) else { return nil }
        return Shape(handle: h)
    }

    // MARK: - Prism Until Face (v0.39.0)

    /// Extrude a profile until it reaches a target face, with automatic fuse/cut.
    ///
    /// Uses BRepFeat_MakePrism which is smarter than simple extrusion+boolean.
    /// - Parameters:
    ///   - profile: Profile face to extrude
    ///   - sketchFaceIndex: Face on this shape where the profile sits (0-based)
    ///   - direction: Extrusion direction
    ///   - fuse: If true, add material; if false, remove material
    ///   - untilFaceIndex: Face index (0-based) where extrusion stops. Pass nil for thru-all.
    /// - Returns: Modified shape, or nil on failure
    public func prismUntilFace(profile: Shape, sketchFaceIndex: Int,
                               direction: SIMD3<Double>, fuse: Bool = true,
                               untilFaceIndex: Int? = nil) -> Shape? {
        guard let h = OCCTShapePrismUntilFace(
            handle, profile.handle, Int32(sketchFaceIndex),
            direction.x, direction.y, direction.z,
            fuse ? 1 : 0, Int32(untilFaceIndex ?? -1)
        ) else { return nil }
        return Shape(handle: h)
    }

    // MARK: - Inertia Properties (v0.40.0)

    /// Volume-based inertia properties (volume, center of mass, inertia tensor, principal moments)
    public struct InertiaProperties {
        /// Volume (for volume properties) or surface area (for surface properties)
        public let mass: Double
        /// Center of mass
        public let centerOfMass: SIMD3<Double>
        /// 3x3 inertia matrix (row-major: [Ixx, Ixy, Ixz, Iyx, Iyy, Iyz, Izx, Izy, Izz])
        public let inertiaMatrix: [Double]
        /// Principal moments of inertia (Ix, Iy, Iz)
        public let principalMoments: SIMD3<Double>
        /// Principal axes of inertia (three unit vectors)
        public let principalAxes: (SIMD3<Double>, SIMD3<Double>, SIMD3<Double>)
        /// Whether the shape has a symmetry axis
        public let hasSymmetryAxis: Bool
        /// Whether the shape has a symmetry point
        public let hasSymmetryPoint: Bool
    }

    /// Compute volume-based inertia properties
    ///
    /// Returns volume, center of mass, 3x3 inertia tensor, principal moments,
    /// and principal axes of inertia.
    /// - Returns: Inertia properties, or nil if computation fails
    public func inertiaProperties() -> InertiaProperties? {
        var props = OCCTInertiaProperties()
        guard OCCTShapeInertiaProperties(handle, &props) else { return nil }
        let mat = withUnsafeBytes(of: &props.inertia) { buf in
            Array(buf.bindMemory(to: Double.self))
        }
        return InertiaProperties(
            mass: props.volume,
            centerOfMass: SIMD3(props.centerX, props.centerY, props.centerZ),
            inertiaMatrix: mat,
            principalMoments: SIMD3(props.principalIx, props.principalIy, props.principalIz),
            principalAxes: (
                SIMD3(props.principalAxes.0, props.principalAxes.1, props.principalAxes.2),
                SIMD3(props.principalAxes.3, props.principalAxes.4, props.principalAxes.5),
                SIMD3(props.principalAxes.6, props.principalAxes.7, props.principalAxes.8)
            ),
            hasSymmetryAxis: props.hasSymmetryAxis,
            hasSymmetryPoint: props.hasSymmetryPoint
        )
    }

    /// Compute surface-area-based inertia properties
    ///
    /// Similar to `inertiaProperties()` but uses surface area instead of volume.
    /// The `mass` field contains surface area.
    /// - Returns: Inertia properties, or nil if computation fails
    public func surfaceInertiaProperties() -> InertiaProperties? {
        var props = OCCTInertiaProperties()
        guard OCCTShapeSurfaceInertiaProperties(handle, &props) else { return nil }
        let mat = withUnsafeBytes(of: &props.inertia) { buf in
            Array(buf.bindMemory(to: Double.self))
        }
        return InertiaProperties(
            mass: props.volume,
            centerOfMass: SIMD3(props.centerX, props.centerY, props.centerZ),
            inertiaMatrix: mat,
            principalMoments: SIMD3(props.principalIx, props.principalIy, props.principalIz),
            principalAxes: (
                SIMD3(props.principalAxes.0, props.principalAxes.1, props.principalAxes.2),
                SIMD3(props.principalAxes.3, props.principalAxes.4, props.principalAxes.5),
                SIMD3(props.principalAxes.6, props.principalAxes.7, props.principalAxes.8)
            ),
            hasSymmetryAxis: props.hasSymmetryAxis,
            hasSymmetryPoint: props.hasSymmetryPoint
        )
    }

    // MARK: - Extended Distance (v0.40.0)

    /// A distance solution between two shapes
    public struct DistanceSolution {
        /// Closest point on the first shape
        public let point1: SIMD3<Double>
        /// Closest point on the second shape
        public let point2: SIMD3<Double>
        /// Distance between the two points
        public let distance: Double
    }

    /// Compute all distance solutions between this shape and another
    ///
    /// Returns all extremal point pairs, not just the minimum distance.
    /// Useful for finding multiple closest/farthest point pairs.
    /// - Parameters:
    ///   - other: The other shape
    ///   - maxSolutions: Maximum number of solutions to return (default 32)
    /// - Returns: Array of distance solutions, or nil on failure
    public func allDistanceSolutions(to other: Shape, maxSolutions: Int = 32) -> [DistanceSolution]? {
        var buffer = [OCCTDistanceSolution](repeating: OCCTDistanceSolution(), count: maxSolutions)
        let count = OCCTShapeAllDistanceSolutions(handle, other.handle, &buffer, Int32(maxSolutions))
        guard count >= 0 else { return nil }
        return (0..<min(Int(count), maxSolutions)).map { i in
            DistanceSolution(
                point1: SIMD3(buffer[i].point1X, buffer[i].point1Y, buffer[i].point1Z),
                point2: SIMD3(buffer[i].point2X, buffer[i].point2Y, buffer[i].point2Z),
                distance: buffer[i].distance
            )
        }
    }

    /// Check if this shape is fully contained inside another shape
    ///
    /// Uses BRepExtrema_DistShapeShape inner solution detection.
    /// - Parameter container: The potential container shape
    /// - Returns: true if this shape is inside the container, nil on failure
    public func isInside(_ container: Shape) -> Bool? {
        let result = OCCTShapeIsInnerDistance(handle, container.handle)
        guard result >= 0 else { return nil }
        return result == 1
    }

    // MARK: - Find Surface (v0.40.0)

    /// Find the underlying geometric surface of a shape (wire or edges)
    ///
    /// Analyzes the edges of a shape to determine if they lie on a common surface.
    /// - Parameters:
    ///   - tolerance: Tolerance for surface detection (default 1e-6)
    ///   - onlyPlane: If true, only look for planar surfaces (default false)
    /// - Returns: The underlying surface, or nil if none found
    public func findSurfaceEx(tolerance: Double = 1e-6, onlyPlane: Bool = false) -> Surface? {
        var found = false
        guard let surfHandle = OCCTShapeFindSurfaceEx(handle, tolerance, onlyPlane, &found),
              found else { return nil }
        return Surface(handle: surfHandle)
    }

    // MARK: - Shape Surgery (v0.41.0)

    /// Remove sub-shapes from this shape
    ///
    /// Uses BRepTools_ReShape to surgically remove faces, edges, or vertices
    /// while preserving the remaining topology.
    /// - Parameter subShapes: Sub-shapes to remove
    /// - Returns: Shape with sub-shapes removed, or nil on failure
    public func removingSubShapes(_ subShapes: [Shape]) -> Shape? {
        var handles = subShapes.map { $0.handle as OCCTShapeRef? }
        guard let h = handles.withUnsafeMutableBufferPointer({ buf in
            OCCTShapeRemoveSubShapes(handle, buf.baseAddress, Int32(subShapes.count))
        }) else { return nil }
        return Shape(handle: h)
    }

    /// Replace sub-shapes in this shape
    ///
    /// Uses BRepTools_ReShape to replace specific sub-shapes with new ones.
    /// - Parameter replacements: Array of (old, new) shape pairs
    /// - Returns: Shape with replacements applied, or nil on failure
    public func replacingSubShapes(_ replacements: [(old: Shape, new: Shape)]) -> Shape? {
        var oldHandles = replacements.map { $0.old.handle as OCCTShapeRef? }
        var newHandles = replacements.map { $0.new.handle as OCCTShapeRef? }
        guard let h = oldHandles.withUnsafeMutableBufferPointer({ oldBuf in
            newHandles.withUnsafeMutableBufferPointer({ newBuf in
                OCCTShapeReplaceSubShapes(handle, oldBuf.baseAddress, newBuf.baseAddress,
                                           Int32(replacements.count))
            })
        }) else { return nil }
        return Shape(handle: h)
    }

    // MARK: - Plane Detection (v0.41.0)

    /// Result of plane detection
    public struct DetectedPlane {
        /// Plane normal direction
        public let normal: SIMD3<Double>
        /// Plane origin point
        public let origin: SIMD3<Double>
    }

    /// Find if this shape's edges lie in a plane
    ///
    /// Uses BRepBuilderAPI_FindPlane to detect if a wire, edge set, or shape
    /// lies in a single geometric plane.
    /// - Parameter tolerance: Tolerance for planarity check (default 1e-6)
    /// - Returns: Detected plane, or nil if shape is not planar
    public func findPlane(tolerance: Double = 1e-6) -> DetectedPlane? {
        var nx = 0.0, ny = 0.0, nz = 0.0
        var ox = 0.0, oy = 0.0, oz = 0.0
        guard OCCTShapeFindPlane(handle, tolerance, &nx, &ny, &nz, &ox, &oy, &oz) else {
            return nil
        }
        return DetectedPlane(normal: SIMD3(nx, ny, nz), origin: SIMD3(ox, oy, oz))
    }

    // MARK: - Closed Edge Splitting (v0.41.0)

    /// Split closed (periodic) edges in the shape
    ///
    /// Periodic edges (like circles) can cause issues in some algorithms.
    /// This splits each closed edge into segments.
    /// - Parameter splitPoints: Number of split points per closed edge (default 1, doubles the edge count)
    /// - Returns: Shape with closed edges split, or nil on failure
    public func dividedClosedEdges(splitPoints: Int = 1) -> Shape? {
        guard let h = OCCTShapeDivideClosedEdges(handle, Int32(splitPoints)) else { return nil }
        return Shape(handle: h)
    }

    // MARK: - Geometry Conversion (v0.41.0)

    /// Convert all surfaces to BSpline form
    ///
    /// Uses ShapeCustom::ConvertToBSpline to convert extrusion, revolution,
    /// offset, and/or planar surfaces to BSpline representation.
    /// - Parameters:
    ///   - extrusion: Convert extrusion surfaces (default true)
    ///   - revolution: Convert revolution surfaces (default true)
    ///   - offset: Convert offset surfaces (default true)
    ///   - plane: Convert planar surfaces (default false)
    /// - Returns: Shape with surfaces converted, or nil on failure
    public func withSurfacesAsBSpline(extrusion: Bool = true, revolution: Bool = true,
                                       offset: Bool = true, plane: Bool = false) -> Shape? {
        guard let h = OCCTShapeCustomConvertToBSpline(handle, extrusion, revolution, offset, plane) else {
            return nil
        }
        return Shape(handle: h)
    }

    /// Convert surfaces to revolution form
    ///
    /// Uses ShapeCustom::ConvertToRevolution to convert surfaces that can be
    /// represented as surfaces of revolution.
    /// - Returns: Shape with surfaces converted, or nil on failure
    public func withSurfacesAsRevolution() -> Shape? {
        guard let h = OCCTShapeCustomConvertToRevolution(handle) else { return nil }
        return Shape(handle: h)
    }

    // MARK: - Face Restriction (v0.41.0)

    /// Create restricted faces from a face and wire boundaries
    ///
    /// Uses BRepAlgo_FaceRestrictor to build faces on the underlying surface
    /// of this shape's first face, bounded by the given wires.
    /// - Parameter boundaries: Wire boundaries that define the restricted regions
    /// - Returns: Array of restricted face shapes, or nil on failure
    public func faceRestricted(by boundaries: [Wire]) -> [Shape]? {
        let maxFaces: Int32 = 64
        var wireHandles = boundaries.map { $0.handle as OCCTWireRef? }
        var outFaces = [OCCTShapeRef?](repeating: nil, count: Int(maxFaces))

        let count = wireHandles.withUnsafeMutableBufferPointer { wireBuf in
            outFaces.withUnsafeMutableBufferPointer { faceBuf in
                OCCTShapeFaceRestrict(handle, wireBuf.baseAddress, Int32(boundaries.count),
                                       faceBuf.baseAddress, maxFaces)
            }
        }
        guard count > 0 else { return nil }
        return (0..<Int(count)).compactMap { i in
            guard let ref = outFaces[i] else { return nil }
            return Shape(handle: ref)
        }
    }

    // MARK: - v0.42.0: Solid Construction, 2D Fillet/Chamfer, Point Cloud Analysis

    /// Create a solid from one or more shell shapes.
    ///
    /// Uses BRepBuilderAPI_MakeSolid to construct a solid from shells extracted from
    /// the given shapes. The first shape provides the outer shell, and additional shapes
    /// provide cavity (inner) shells.
    ///
    /// - Parameter shells: Array of shapes containing shells (first = outer, rest = cavities)
    /// - Returns: Solid shape, or nil on failure
    public static func solidFromShells(_ shells: [Shape]) -> Shape? {
        guard !shells.isEmpty else { return nil }
        var handles = shells.map { $0.handle as OCCTShapeRef? }
        let result = handles.withUnsafeMutableBufferPointer { buffer in
            OCCTSolidFromShells(buffer.baseAddress, Int32(shells.count))
        }
        guard let result = result else { return nil }
        return Shape(handle: result)
    }

    /// Apply 2D fillets (rounded corners) to a planar face at specified vertices.
    ///
    /// Uses BRepFilletAPI_MakeFillet2d to round corners of a planar face.
    /// Vertex indices are 0-based and correspond to the topological vertex order.
    ///
    /// - Parameters:
    ///   - vertexIndices: 0-based indices of vertices to fillet
    ///   - radii: Fillet radius for each vertex (must match vertexIndices count)
    /// - Returns: Modified shape with fillets, or nil on failure
    public func fillet2D(vertexIndices: [Int], radii: [Double]) -> Shape? {
        guard !vertexIndices.isEmpty, vertexIndices.count == radii.count else { return nil }
        let indices = vertexIndices.map { Int32($0) }
        let result = indices.withUnsafeBufferPointer { idxBuf in
            radii.withUnsafeBufferPointer { radBuf in
                OCCTFace2DFillet(handle, idxBuf.baseAddress, radBuf.baseAddress, Int32(vertexIndices.count))
            }
        }
        guard let result = result else { return nil }
        return Shape(handle: result)
    }

    /// Apply 2D chamfers (angled cuts) to a planar face between adjacent edge pairs.
    ///
    /// Uses BRepFilletAPI_MakeFillet2d to add chamfers at the intersection of
    /// adjacent edges. Edge indices are 0-based and correspond to the topological edge order.
    ///
    /// - Parameters:
    ///   - edgePairs: Array of (edge1Index, edge2Index) pairs identifying adjacent edges
    ///   - distances: Chamfer distance for each edge pair
    /// - Returns: Modified shape with chamfers, or nil on failure
    public func chamfer2D(edgePairs: [(Int, Int)], distances: [Double]) -> Shape? {
        guard !edgePairs.isEmpty, edgePairs.count == distances.count else { return nil }
        let edge1Indices = edgePairs.map { Int32($0.0) }
        let edge2Indices = edgePairs.map { Int32($0.1) }
        let result = edge1Indices.withUnsafeBufferPointer { e1Buf in
            edge2Indices.withUnsafeBufferPointer { e2Buf in
                distances.withUnsafeBufferPointer { distBuf in
                    OCCTFace2DChamfer(handle, e1Buf.baseAddress, e2Buf.baseAddress,
                                       distBuf.baseAddress, Int32(edgePairs.count))
                }
            }
        }
        guard let result = result else { return nil }
        return Shape(handle: result)
    }

    /// Result of point cloud geometry analysis.
    public enum PointCloudGeometry {
        /// All points are coincident (within tolerance)
        case point(SIMD3<Double>)
        /// Points are collinear — fit a line
        case linear(origin: SIMD3<Double>, direction: SIMD3<Double>)
        /// Points are coplanar — fit a plane
        case planar(origin: SIMD3<Double>, normal: SIMD3<Double>)
        /// Points are dispersed in 3D space
        case space
    }

    /// Analyze a set of 3D points to determine their geometric arrangement.
    ///
    /// Uses GProp_PEquation to classify points as coincident, collinear, coplanar,
    /// or dispersed in 3D space. Useful for determining degeneracy of point sets
    /// before constructing geometry.
    ///
    /// - Parameters:
    ///   - points: Array of 3D points (minimum 1)
    ///   - tolerance: Tolerance for classification
    /// - Returns: Classification result, or nil on failure
    public static func analyzePointCloud(_ points: [SIMD3<Double>], tolerance: Double = 1e-6) -> PointCloudGeometry? {
        guard !points.isEmpty else { return nil }
        var coords: [Double] = []
        coords.reserveCapacity(points.count * 3)
        for p in points {
            coords.append(p.x)
            coords.append(p.y)
            coords.append(p.z)
        }
        var result = OCCTPointCloudGeometry()
        let ok = coords.withUnsafeBufferPointer { buffer in
            OCCTAnalyzePointCloud(buffer.baseAddress, Int32(points.count), tolerance, &result)
        }
        guard ok else { return nil }
        switch result.type {
        case 0:
            return .point(SIMD3(result.pointX, result.pointY, result.pointZ))
        case 1:
            return .linear(
                origin: SIMD3(result.pointX, result.pointY, result.pointZ),
                direction: SIMD3(result.dirX, result.dirY, result.dirZ)
            )
        case 2:
            return .planar(
                origin: SIMD3(result.pointX, result.pointY, result.pointZ),
                normal: SIMD3(result.normalX, result.normalY, result.normalZ)
            )
        case 3:
            return .space
        default:
            return nil
        }
    }

    // MARK: - v0.43.0: Face Subdivision, Small Face Detection, Location Purge

    /// Subdivide faces whose area exceeds a maximum threshold.
    ///
    /// Uses ShapeUpgrade_ShapeDivideArea to split faces larger than the specified area.
    /// Useful for mesh quality control and FEA preprocessing.
    ///
    /// - Parameter maxArea: Maximum face area — faces larger than this are split
    /// - Returns: Shape with subdivided faces, or nil on failure
    public func dividedByArea(maxArea: Double) -> Shape? {
        guard let ref = OCCTShapeDivideByArea(handle, maxArea) else { return nil }
        return Shape(handle: ref)
    }

    /// Subdivide faces into a target number of parts.
    ///
    /// Uses ShapeUpgrade_ShapeDivideArea in splitting-by-number mode.
    ///
    /// - Parameter parts: Target number of parts per face
    /// - Returns: Shape with subdivided faces, or nil on failure
    public func dividedByParts(_ parts: Int) -> Shape? {
        guard let ref = OCCTShapeDivideByParts(handle, Int32(parts)) else { return nil }
        return Shape(handle: ref)
    }

    /// Result of small/degenerate face analysis.
    public struct SmallFaceInfo: Sendable {
        /// Whether the face is collapsed to a point
        public let isSpotFace: Bool
        /// Whether the face has negligible width
        public let isStripFace: Bool
        /// Whether the face is twisted
        public let isTwisted: Bool
        /// Location of spot face (if isSpotFace is true)
        public let spotLocation: SIMD3<Double>?
    }

    /// Check faces for degenerate conditions (spot, strip, twisted).
    ///
    /// Uses ShapeAnalysis_CheckSmallFace to analyze each face of the shape.
    /// Returns only faces that have at least one degenerate condition.
    ///
    /// - Parameter tolerance: Analysis tolerance (default 1e-6)
    /// - Returns: Array of degenerate face descriptions, empty if none found
    public func checkSmallFaces(tolerance: Double = 1e-6) -> [SmallFaceInfo] {
        let maxResults: Int32 = 256
        var results = [OCCTSmallFaceResult](repeating: OCCTSmallFaceResult(), count: Int(maxResults))
        let count = results.withUnsafeMutableBufferPointer { buffer in
            OCCTShapeCheckSmallFaces(handle, tolerance, buffer.baseAddress, maxResults)
        }
        return (0..<Int(count)).map { i in
            let r = results[i]
            return SmallFaceInfo(
                isSpotFace: r.isSpotFace,
                isStripFace: r.isStripFace,
                isTwisted: r.isTwisted,
                spotLocation: r.isSpotFace ? SIMD3(r.spotX, r.spotY, r.spotZ) : nil
            )
        }
    }

    /// Purge problematic location datums from the shape.
    ///
    /// Removes negative-scale and non-unit-scale transforms from the shape and all
    /// sub-shapes. Useful for cleaning imported geometry from STEP/IGES files.
    ///
    /// - Returns: Cleaned shape, or nil if purge was unnecessary or failed
    public var purgedLocations: Shape? {
        guard let ref = OCCTShapePurgeLocations(handle) else { return nil }
        return Shape(handle: ref)
    }

    // MARK: - Curve-on-Surface Check

    /// Result of a curve-on-surface consistency check.
    public struct CurveOnSurfaceCheck {
        /// Maximum deviation between 3D edge curves and their pcurves on faces
        public let maxDistance: Double
        /// Curve parameter where the maximum deviation occurs
        public let maxParameter: Double
    }

    /// Check edge-on-surface consistency.
    ///
    /// Examines all edge-face pairs in the shape and reports the maximum deviation
    /// between each edge's 3D curve and its parametric curve (pcurve) on the face surface.
    /// Useful for validating imported geometry or checking repair results.
    ///
    /// - Returns: Check result with max distance and parameter, or nil if check fails
    public var curveOnSurfaceCheck: CurveOnSurfaceCheck? {
        var maxDist: Double = 0
        var maxParam: Double = 0
        guard OCCTShapeCheckCurveOnSurface(handle, &maxDist, &maxParam) else { return nil }
        return CurveOnSurfaceCheck(maxDistance: maxDist, maxParameter: maxParam)
    }

    // MARK: - Edge Connection

    /// Connect edges by merging shared vertices in the shape.
    ///
    /// Uses ShapeFix_EdgeConnect to identify edges that share geometric positions
    /// and merges their vertices. Useful for healing imported geometry where
    /// topologically disconnected edges actually meet at the same point.
    ///
    /// - Returns: Shape with connected edges, or nil on failure
    public var connectedEdges: Shape? {
        guard let ref = OCCTShapeConnectEdges(handle) else { return nil }
        return Shape(handle: ref)
    }

    // MARK: - Self-Intersection Detection (v0.45.0)

    /// Result of a self-intersection check
    public struct SelfIntersectionResult: Sendable {
        /// Number of overlapping triangle pairs found
        public let overlapCount: Int
        /// Whether the check completed successfully
        public let isDone: Bool
    }

    /// Check the shape for self-intersection using BVH-accelerated triangle mesh overlap.
    ///
    /// Meshes the shape and uses BRepExtrema_SelfIntersection to detect overlapping
    /// triangle pairs, which indicate self-intersection.
    ///
    /// - Parameters:
    ///   - tolerance: Tolerance for detecting intersections (default 0.001)
    ///   - meshDeflection: Mesh deflection for triangulation (default 0.5)
    /// - Returns: Self-intersection result, or nil if the check failed
    public func selfIntersection(tolerance: Double = 0.001,
                                  meshDeflection: Double = 0.5) -> SelfIntersectionResult? {
        let result = OCCTShapeSelfIntersection(handle, tolerance, meshDeflection)
        guard result.isDone else { return nil }
        return SelfIntersectionResult(overlapCount: Int(result.overlapCount), isDone: true)
    }

    // MARK: - Bezier Conversion

    /// Convert all curves and surfaces in the shape to Bezier representations.
    ///
    /// Uses ShapeUpgrade_ShapeConvertToBezier to replace BSpline curves and surfaces
    /// with their Bezier equivalents. Converts 2D/3D curves, surfaces, lines, circles,
    /// conics, planes, revolutions, extrusions, and BSpline entities.
    ///
    /// - Returns: Shape with Bezier geometry, or nil on failure
    public var convertedToBezier: Shape? {
        guard let ref = OCCTShapeConvertToBezier(handle) else { return nil }
        return Shape(handle: ref)
    }

    // MARK: - Edge Concavity Analysis (v0.46.0)

    /// Edge concavity type from BRepOffset_Analyse
    public enum EdgeConcavity: Sendable {
        /// Edge connects two faces at a convex angle (outer edge of a box)
        case convex
        /// Edge connects two faces at a concave angle (inner edge of a groove)
        case concave
        /// Edge connects two faces that are tangent (smooth transition)
        case tangent
    }

    /// Classify all edges by their concavity type using BRepOffset_Analyse.
    ///
    /// Analyzes the angles between adjacent faces at each edge to determine
    /// whether each edge is convex, concave, or tangent.
    ///
    /// - Parameter angle: Threshold angle for tangent classification (radians, default 0.01)
    /// - Returns: Array of (edge, concavity) pairs, or nil on error
    public func edgeConcavities(angle: Double = 0.01) -> [(Edge, EdgeConcavity)]? {
        let count = edgeCount
        guard count > 0 else { return nil }

        var outTypes = [OCCTEdgeConcavity](repeating: OCCTEdgeConcavity(type: OCCTConcavityConvex),
                                            count: count)
        let classified = OCCTShapeAnalyzeEdgeConcavity(handle, angle, &outTypes, Int32(count))
        guard classified > 0 else { return nil }

        var result = [(Edge, EdgeConcavity)]()
        result.reserveCapacity(Int(classified))

        let allEdges = edges()
        for i in 0..<min(Int(classified), allEdges.count) {
            let concavity: EdgeConcavity
            switch outTypes[i].type {
            case OCCTConcavityConvex: concavity = .convex
            case OCCTConcavityConcave: concavity = .concave
            case OCCTConcavityTangent: concavity = .tangent
            default: concavity = .tangent
            }
            result.append((allEdges[i], concavity))
        }
        return result
    }

    /// Count edges of a specific concavity type.
    ///
    /// - Parameters:
    ///   - type: Concavity type to count
    ///   - angle: Threshold angle for tangent classification (radians, default 0.01)
    /// - Returns: Number of edges of the specified type, or nil on error
    public func edgeConcavityCount(_ type: EdgeConcavity, angle: Double = 0.01) -> Int? {
        let typeValue: Int32
        switch type {
        case .convex: typeValue = 0
        case .concave: typeValue = 1
        case .tangent: typeValue = 2
        }
        let count = OCCTShapeCountEdgeConcavity(handle, angle, typeValue)
        return count >= 0 ? Int(count) : nil
    }

    // MARK: - Local Prism (v0.46.0)

    /// Create a local prism (extrusion) from this shape along a direction.
    ///
    /// Uses LocOpe_Prism which tracks generated shapes for each input sub-shape,
    /// providing more detailed operation history than standard extrusion.
    ///
    /// - Parameter direction: Direction and distance of extrusion
    /// - Returns: Extruded shape, or nil on failure
    public func localPrism(direction: SIMD3<Double>) -> Shape? {
        guard let ref = OCCTLocOpePrism(handle, direction.x, direction.y, direction.z) else {
            return nil
        }
        return Shape(handle: ref)
    }

    /// Create a local prism with an additional translation.
    ///
    /// - Parameters:
    ///   - direction: Primary direction and distance of extrusion
    ///   - translation: Secondary translation vector
    /// - Returns: Extruded shape, or nil on failure
    public func localPrism(direction: SIMD3<Double>, translation: SIMD3<Double>) -> Shape? {
        guard let ref = OCCTLocOpePrismWithTranslation(
            handle, direction.x, direction.y, direction.z,
            translation.x, translation.y, translation.z
        ) else {
            return nil
        }
        return Shape(handle: ref)
    }

    // MARK: - Volume Inertia Properties (v0.46.0)

    /// Volume inertia properties of a solid shape.
    public struct VolumeInertia: Sendable {
        /// Volume of the shape
        public let volume: Double
        /// Center of mass
        public let centerOfMass: SIMD3<Double>
        /// 3x3 inertia tensor (row-major)
        public let inertiaTensor: [Double]
        /// Principal moments of inertia (sorted)
        public let principalMoments: SIMD3<Double>
        /// Principal axes of inertia (3 unit vectors)
        public let principalAxes: (SIMD3<Double>, SIMD3<Double>, SIMD3<Double>)
        /// Radii of gyration about principal axes
        public let gyrationRadii: SIMD3<Double>
    }

    /// Compute volume inertia properties of this shape.
    ///
    /// Returns volume, center of mass, inertia tensor, principal moments
    /// and axes of inertia, and radii of gyration.
    ///
    /// - Returns: Volume inertia result, or nil on error
    public var volumeInertia: VolumeInertia? {
        var result = OCCTVolumeInertiaResult()
        guard OCCTShapeVolumeInertia(handle, &result) else { return nil }

        let tensor = withUnsafeBytes(of: &result.inertia) { buf in
            Array(buf.bindMemory(to: Double.self))
        }

        return VolumeInertia(
            volume: result.volume,
            centerOfMass: SIMD3(result.centerX, result.centerY, result.centerZ),
            inertiaTensor: tensor,
            principalMoments: SIMD3(result.principalMoment1, result.principalMoment2, result.principalMoment3),
            principalAxes: (
                SIMD3(result.axis1X, result.axis1Y, result.axis1Z),
                SIMD3(result.axis2X, result.axis2Y, result.axis2Z),
                SIMD3(result.axis3X, result.axis3Y, result.axis3Z)
            ),
            gyrationRadii: SIMD3(result.gyrationRadius1, result.gyrationRadius2, result.gyrationRadius3)
        )
    }

    /// Surface inertia properties of a shape.
    public struct SurfaceInertia: Sendable {
        /// Total surface area
        public let area: Double
        /// Center of mass of the surface
        public let centerOfMass: SIMD3<Double>
        /// 3x3 inertia tensor (row-major)
        public let inertiaTensor: [Double]
        /// Principal moments of inertia
        public let principalMoments: SIMD3<Double>
    }

    /// Compute surface (area) inertia properties of this shape.
    ///
    /// - Returns: Surface inertia result, or nil on error
    public var surfaceInertia: SurfaceInertia? {
        var result = OCCTSurfaceInertiaResult()
        guard OCCTShapeSurfaceInertia(handle, &result) else { return nil }

        let tensor = withUnsafeBytes(of: &result.inertia) { buf in
            Array(buf.bindMemory(to: Double.self))
        }

        return SurfaceInertia(
            area: result.area,
            centerOfMass: SIMD3(result.centerX, result.centerY, result.centerZ),
            inertiaTensor: tensor,
            principalMoments: SIMD3(result.principalMoment1, result.principalMoment2, result.principalMoment3)
        )
    }
}
