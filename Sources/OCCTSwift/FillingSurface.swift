import Foundation
import simd
import OCCTBridge

/// Continuity order for filling surface constraints
public enum FillingContinuity: Int32, Sendable {
    /// Positional continuity (G0) — surface passes through the constraint
    case c0 = 0
    /// Tangent continuity (C1) — surface is tangent along the constraint
    case c1 = 1
    /// Curvature continuity (C2) — surface has curvature continuity along the constraint
    case c2 = 2
}

/// Builder for N-sided surface filling using BRepFill_Filling.
///
/// Creates a smooth surface that satisfies boundary edge constraints and optional
/// interior point constraints. Useful for creating patches that fill holes or
/// connect multiple surface boundaries.
///
/// ```swift
/// let edges = box.edges()
/// let filling = FillingSurface()
/// filling.add(edge: edges[0], continuity: .c0)
/// filling.add(edge: edges[1], continuity: .c0)
/// filling.add(edge: edges[2], continuity: .c0)
/// filling.add(edge: edges[3], continuity: .c0)
/// filling.add(point: SIMD3(5, 5, 3))  // surface passes through this point
/// let face = filling.build()
/// ```
public final class FillingSurface: @unchecked Sendable {
    private let handle: OCCTFillingRef

    /// Create a filling surface builder.
    ///
    /// - Parameters:
    ///   - degree: Target polynomial degree (default 3)
    ///   - pointsOnCurve: Number of discretization points on each constraint curve (default 15)
    ///   - maxDegree: Maximum polynomial degree (default 8)
    ///   - maxSegments: Maximum number of segments (default 9)
    ///   - tolerance: 3D tolerance (default 1e-4)
    public init(degree: Int = 3, pointsOnCurve: Int = 15, maxDegree: Int = 8,
                maxSegments: Int = 9, tolerance: Double = 1e-4) {
        self.handle = OCCTFillingCreate(Int32(degree), Int32(pointsOnCurve),
                                         Int32(maxDegree), Int32(maxSegments), tolerance)
    }

    deinit {
        OCCTFillingRelease(handle)
    }

    /// Add a boundary edge constraint.
    ///
    /// - Parameters:
    ///   - edge: Edge to add as boundary constraint
    ///   - continuity: Continuity order at this edge (default .c0)
    /// - Returns: true if the edge was added successfully
    @discardableResult
    public func add(edge: Edge, continuity: FillingContinuity = .c0) -> Bool {
        OCCTFillingAddEdge(handle, edge.handle, continuity.rawValue)
    }

    /// Add a free (non-boundary) edge constraint.
    ///
    /// Free edges are not required to be topologically connected to other edges.
    ///
    /// - Parameters:
    ///   - freeEdge: Edge to add as a free constraint
    ///   - continuity: Continuity order at this edge (default .c0)
    /// - Returns: true if the edge was added successfully
    @discardableResult
    public func add(freeEdge edge: Edge, continuity: FillingContinuity = .c0) -> Bool {
        OCCTFillingAddFreeEdge(handle, edge.handle, continuity.rawValue)
    }

    /// Add a point constraint that the filling surface must pass through.
    ///
    /// - Parameter point: 3D point the surface must interpolate
    /// - Returns: true if the point was added successfully
    @discardableResult
    public func add(point: SIMD3<Double>) -> Bool {
        OCCTFillingAddPoint(handle, point.x, point.y, point.z)
    }

    /// Build the filling surface and return the resulting shape.
    ///
    /// - Returns: The filled face as a Shape, or nil if building failed
    public func build() -> Shape? {
        guard OCCTFillingBuild(handle) else { return nil }
        guard let ref = OCCTFillingGetFace(handle) else { return nil }
        return Shape(handle: ref)
    }

    /// Whether the filling surface has been successfully built.
    public var isDone: Bool {
        OCCTFillingIsDone(handle)
    }

    /// Positional (G0) error of the built surface.
    ///
    /// Returns the maximum distance from the surface to its constraints.
    public var g0Error: Double? {
        let err = OCCTFillingG0Error(handle)
        return err >= 0 ? err : nil
    }

    /// Tangent (G1) error of the built surface.
    public var g1Error: Double? {
        let err = OCCTFillingG1Error(handle)
        return err >= 0 ? err : nil
    }

    /// Curvature (G2) error of the built surface.
    public var g2Error: Double? {
        let err = OCCTFillingG2Error(handle)
        return err >= 0 ? err : nil
    }
}
