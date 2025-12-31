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
    public static func box(width: Double, height: Double, depth: Double) -> Shape {
        let handle = OCCTShapeCreateBox(width, height, depth)
        return Shape(handle: handle!)
    }

    /// Create a box at a specific position
    public static func box(
        origin: SIMD3<Double>,
        width: Double,
        height: Double,
        depth: Double
    ) -> Shape {
        let handle = OCCTShapeCreateBoxAt(
            origin.x, origin.y, origin.z,
            width, height, depth
        )
        return Shape(handle: handle!)
    }

    /// Create a cylinder along Z axis
    public static func cylinder(radius: Double, height: Double) -> Shape {
        let handle = OCCTShapeCreateCylinder(radius, height)
        return Shape(handle: handle!)
    }

    /// Create a cylinder at a specific XY position with bottom at specified Z
    public static func cylinder(
        at position: SIMD2<Double>,
        bottomZ: Double,
        radius: Double,
        height: Double
    ) -> Shape {
        let handle = OCCTShapeCreateCylinderAt(position.x, position.y, bottomZ, radius, height)
        return Shape(handle: handle!)
    }

    /// Create a tool sweep solid - the volume swept by a cylindrical tool moving between two points
    /// Used for CAM simulation to calculate material removal
    public static func toolSweep(
        radius: Double,
        height: Double,
        from start: SIMD3<Double>,
        to end: SIMD3<Double>
    ) -> Shape {
        let handle = OCCTShapeCreateToolSweep(
            radius, height,
            start.x, start.y, start.z,
            end.x, end.y, end.z
        )
        return Shape(handle: handle!)
    }

    /// Create a sphere centered at origin
    public static func sphere(radius: Double) -> Shape {
        let handle = OCCTShapeCreateSphere(radius)
        return Shape(handle: handle!)
    }

    /// Create a cone along Z axis
    public static func cone(bottomRadius: Double, topRadius: Double, height: Double) -> Shape {
        let handle = OCCTShapeCreateCone(bottomRadius, topRadius, height)
        return Shape(handle: handle!)
    }

    /// Create a torus in XY plane
    public static func torus(majorRadius: Double, minorRadius: Double) -> Shape {
        let handle = OCCTShapeCreateTorus(majorRadius, minorRadius)
        return Shape(handle: handle!)
    }

    // MARK: - Sweep Operations

    /// Sweep a 2D profile along a path to create a solid
    public static func sweep(profile: Wire, along path: Wire) -> Shape {
        let handle = OCCTShapeCreatePipeSweep(profile.handle, path.handle)
        return Shape(handle: handle!)
    }

    /// Extrude a 2D profile in a direction
    public static func extrude(profile: Wire, direction: SIMD3<Double>, length: Double) -> Shape {
        let handle = OCCTShapeCreateExtrusion(
            profile.handle,
            direction.x, direction.y, direction.z,
            length
        )
        return Shape(handle: handle!)
    }

    /// Revolve a 2D profile around an axis
    public static func revolve(
        profile: Wire,
        axisOrigin: SIMD3<Double>,
        axisDirection: SIMD3<Double>,
        angle: Double = .pi * 2
    ) -> Shape {
        let handle = OCCTShapeCreateRevolution(
            profile.handle,
            axisOrigin.x, axisOrigin.y, axisOrigin.z,
            axisDirection.x, axisDirection.y, axisDirection.z,
            angle
        )
        return Shape(handle: handle!)
    }

    /// Loft through multiple profile wires
    public static func loft(profiles: [Wire], solid: Bool = true) -> Shape {
        let handles: [OCCTWireRef?] = profiles.map { $0.handle }
        let handle = handles.withUnsafeBufferPointer { buffer in
            OCCTShapeCreateLoft(buffer.baseAddress, Int32(profiles.count), solid)
        }
        return Shape(handle: handle!)
    }

    // MARK: - Boolean Operations

    /// Union (add) two shapes together
    public func union(with other: Shape) -> Shape {
        let handle = OCCTShapeUnion(self.handle, other.handle)
        return Shape(handle: handle!)
    }

    /// Subtract another shape from this one
    public func subtracting(_ other: Shape) -> Shape {
        let handle = OCCTShapeSubtract(self.handle, other.handle)
        return Shape(handle: handle!)
    }

    /// Intersection of two shapes
    public func intersection(with other: Shape) -> Shape {
        let handle = OCCTShapeIntersect(self.handle, other.handle)
        return Shape(handle: handle!)
    }

    // MARK: - Modifications

    /// Fillet (round) all edges with given radius
    public func filleted(radius: Double) -> Shape {
        let handle = OCCTShapeFillet(self.handle, radius)
        return Shape(handle: handle!)
    }

    /// Chamfer all edges with given distance
    public func chamfered(distance: Double) -> Shape {
        let handle = OCCTShapeChamfer(self.handle, distance)
        return Shape(handle: handle!)
    }

    /// Create a hollow shell by removing material from inside
    public func shelled(thickness: Double) -> Shape {
        let handle = OCCTShapeShell(self.handle, thickness)
        return Shape(handle: handle!)
    }

    /// Offset all faces by a distance (positive = outward)
    public func offset(by distance: Double) -> Shape {
        let handle = OCCTShapeOffset(self.handle, distance)
        return Shape(handle: handle!)
    }

    // MARK: - Transformations

    /// Translate the shape
    public func translated(by offset: SIMD3<Double>) -> Shape {
        let handle = OCCTShapeTranslate(self.handle, offset.x, offset.y, offset.z)
        return Shape(handle: handle!)
    }

    /// Rotate around an axis through origin
    public func rotated(axis: SIMD3<Double>, angle: Double) -> Shape {
        let handle = OCCTShapeRotate(self.handle, axis.x, axis.y, axis.z, angle)
        return Shape(handle: handle!)
    }

    /// Scale uniformly from origin
    public func scaled(by factor: Double) -> Shape {
        let handle = OCCTShapeScale(self.handle, factor)
        return Shape(handle: handle!)
    }

    /// Mirror across a plane
    public func mirrored(planeNormal: SIMD3<Double>, planeOrigin: SIMD3<Double> = .zero) -> Shape {
        let handle = OCCTShapeMirror(
            self.handle,
            planeOrigin.x, planeOrigin.y, planeOrigin.z,
            planeNormal.x, planeNormal.y, planeNormal.z
        )
        return Shape(handle: handle!)
    }

    // MARK: - Compound Operations

    /// Combine multiple shapes into a compound (no boolean, just grouping)
    public static func compound(_ shapes: [Shape]) -> Shape {
        let handles: [OCCTShapeRef?] = shapes.map { $0.handle }
        let handle = handles.withUnsafeBufferPointer { buffer in
            OCCTShapeCreateCompound(buffer.baseAddress, Int32(shapes.count))
        }
        return Shape(handle: handle!)
    }

    // MARK: - Validation

    /// Check if shape is valid
    public var isValid: Bool {
        OCCTShapeIsValid(handle)
    }

    /// Attempt to repair/heal the shape
    public func healed() -> Shape {
        let handle = OCCTShapeHeal(self.handle)
        return Shape(handle: handle!)
    }

    // MARK: - Meshing

    /// Generate a triangulated mesh for visualization
    public func mesh(
        linearDeflection: Double = 0.1,
        angularDeflection: Double = 0.5
    ) -> Mesh {
        let meshHandle = OCCTShapeCreateMesh(handle, linearDeflection, angularDeflection)
        return Mesh(handle: meshHandle!)
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
    public func mesh(parameters: MeshParameters) -> Mesh {
        let bridgeParams = parameters.toBridge()
        let meshHandle = OCCTShapeCreateMeshWithParams(handle, bridgeParams)
        return Mesh(handle: meshHandle!)
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
    public static func + (lhs: Shape, rhs: Shape) -> Shape {
        lhs.union(with: rhs)
    }

    public static func - (lhs: Shape, rhs: Shape) -> Shape {
        lhs.subtracting(rhs)
    }

    public static func & (lhs: Shape, rhs: Shape) -> Shape {
        lhs.intersection(with: rhs)
    }
}
