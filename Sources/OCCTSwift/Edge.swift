import Foundation
import simd
import OCCTBridge

/// An edge from a 3D solid shape - represents a curve between vertices
public final class Edge: @unchecked Sendable {
    internal let handle: OCCTEdgeRef

    /// Index of this edge within the parent shape (-1 if standalone)
    public let index: Int

    internal init(handle: OCCTEdgeRef, index: Int = -1) {
        self.handle = handle
        self.index = index
    }
    
    deinit {
        OCCTEdgeRelease(handle)
    }
    
    // MARK: - Properties
    
    /// Get the length of the edge
    public var length: Double {
        OCCTEdgeGetLength(handle)
    }
    
    /// Get the bounding box of the edge
    public var bounds: (min: SIMD3<Double>, max: SIMD3<Double>) {
        var minX: Double = 0, minY: Double = 0, minZ: Double = 0
        var maxX: Double = 0, maxY: Double = 0, maxZ: Double = 0
        OCCTEdgeGetBounds(handle, &minX, &minY, &minZ, &maxX, &maxY, &maxZ)
        return (min: SIMD3(minX, minY, minZ), max: SIMD3(maxX, maxY, maxZ))
    }
    
    /// Check if the edge is a straight line
    public var isLine: Bool {
        OCCTEdgeIsLine(handle)
    }
    
    /// Check if the edge is a circular arc
    public var isCircle: Bool {
        OCCTEdgeIsCircle(handle)
    }
    
    /// Get the start and end points of the edge
    public var endpoints: (start: SIMD3<Double>, end: SIMD3<Double>) {
        var startX: Double = 0, startY: Double = 0, startZ: Double = 0
        var endX: Double = 0, endY: Double = 0, endZ: Double = 0
        OCCTEdgeGetEndpoints(handle, &startX, &startY, &startZ, &endX, &endY, &endZ)
        return (start: SIMD3(startX, startY, startZ), end: SIMD3(endX, endY, endZ))
    }
    
    // MARK: - Sampling
    
    // MARK: - 3D Curve Properties (v0.18.0)

    /// Curve type classification
    public enum CurveType: Int32, Sendable {
        case line = 0, circle = 1, ellipse = 2, hyperbola = 3, parabola = 4
        case bezierCurve = 5, bsplineCurve = 6, offsetCurve = 7, other = 8
    }

    /// Projection result for a point onto this edge's curve
    public struct CurveProjection: Sendable {
        public let point: SIMD3<Double>
        public let parameter: Double
        public let distance: Double
    }

    /// Get the parameter bounds of the edge's underlying curve
    public var parameterBounds: (first: Double, last: Double)? {
        var first: Double = 0, last: Double = 0
        guard OCCTEdgeGetParameterBounds(handle, &first, &last) else {
            return nil
        }
        return (first: first, last: last)
    }

    /// Get the curve type of this edge
    public var curveType: CurveType {
        CurveType(rawValue: OCCTEdgeGetCurveType(handle)) ?? .other
    }

    /// Get 3D point at a curve parameter
    public func point(at parameter: Double) -> SIMD3<Double>? {
        var px: Double = 0, py: Double = 0, pz: Double = 0
        guard OCCTEdgeGetPointAtParam(handle, parameter, &px, &py, &pz) else {
            return nil
        }
        return SIMD3(px, py, pz)
    }

    /// Get curvature at a curve parameter
    public func curvature(at parameter: Double) -> Double? {
        var curvature: Double = 0
        guard OCCTEdgeGetCurvature3D(handle, parameter, &curvature) else {
            return nil
        }
        return curvature
    }

    /// Get tangent direction at a curve parameter
    public func tangent(at parameter: Double) -> SIMD3<Double>? {
        var tx: Double = 0, ty: Double = 0, tz: Double = 0
        guard OCCTEdgeGetTangent3D(handle, parameter, &tx, &ty, &tz) else {
            return nil
        }
        return SIMD3(tx, ty, tz)
    }

    /// Get principal normal direction at a curve parameter
    public func normal(at parameter: Double) -> SIMD3<Double>? {
        var nx: Double = 0, ny: Double = 0, nz: Double = 0
        guard OCCTEdgeGetNormal3D(handle, parameter, &nx, &ny, &nz) else {
            return nil
        }
        return SIMD3(nx, ny, nz)
    }

    /// Get center of curvature at a curve parameter
    public func centerOfCurvature(at parameter: Double) -> SIMD3<Double>? {
        var cx: Double = 0, cy: Double = 0, cz: Double = 0
        guard OCCTEdgeGetCenterOfCurvature3D(handle, parameter, &cx, &cy, &cz) else {
            return nil
        }
        return SIMD3(cx, cy, cz)
    }

    /// Get torsion at a curve parameter
    public func torsion(at parameter: Double) -> Double? {
        var torsion: Double = 0
        guard OCCTEdgeGetTorsion(handle, parameter, &torsion) else {
            return nil
        }
        return torsion
    }

    /// Project a 3D point onto this edge's curve (closest point)
    public func project(point: SIMD3<Double>) -> CurveProjection? {
        let result = OCCTEdgeProjectPoint(handle, point.x, point.y, point.z)
        guard result.isValid else { return nil }
        return CurveProjection(
            point: SIMD3(result.px, result.py, result.pz),
            parameter: result.parameter,
            distance: result.distance
        )
    }

    // MARK: - Sampling

    /// Get points along the edge curve
    /// - Parameter count: Number of points to generate (default: automatic based on length)
    /// - Returns: Array of 3D points along the edge
    public func points(count: Int? = nil) -> [SIMD3<Double>] {
        let pointCount = count ?? max(2, Int(length / 0.5) + 1)  // ~0.5mm spacing default
        guard pointCount >= 2 else { return [] }
        
        var buffer = [Double](repeating: 0, count: pointCount * 3)
        let actualCount = OCCTEdgeGetPoints(handle, Int32(pointCount), &buffer)
        
        guard actualCount > 0 else { return [] }
        
        var result = [SIMD3<Double>]()
        result.reserveCapacity(Int(actualCount))
        
        for i in 0..<Int(actualCount) {
            let x = buffer[i * 3]
            let y = buffer[i * 3 + 1]
            let z = buffer[i * 3 + 2]
            result.append(SIMD3(x, y, z))
        }
        
        return result
    }
}

// MARK: - Shape Extension for Edge Access

extension Shape {
    /// Get total number of edges in the shape
    public var edgeCount: Int {
        Int(OCCTShapeGetTotalEdgeCount(handle))
    }
    
    /// Get edge by index (0-based)
    /// - Parameter index: The edge index
    /// - Returns: Edge at the given index, or nil if index is out of bounds
    public func edge(at index: Int) -> Edge? {
        guard let edgeHandle = OCCTShapeGetEdgeAtIndex(handle, Int32(index)) else {
            return nil
        }
        return Edge(handle: edgeHandle, index: index)
    }
    
    /// Get all edges from the shape
    public func edges() -> [Edge] {
        let count = edgeCount
        var edges = [Edge]()
        edges.reserveCapacity(count)
        
        for i in 0..<count {
            if let edge = edge(at: i) {
                edges.append(edge)
            }
        }
        
        return edges
    }
}

// MARK: - Edge Analysis (v0.30.0)

extension Edge {
    /// Whether this edge has an underlying 3D curve.
    public var hasCurve3D: Bool {
        OCCTEdgeHasCurve3D(handle)
    }

    /// Whether this edge is closed (start and end vertices coincide).
    public var isClosed3D: Bool {
        OCCTEdgeIsClosed3D(handle)
    }

    /// Whether this edge is a seam edge on the given face.
    ///
    /// A seam edge appears twice on a face with different orientations
    /// (e.g., the seam of a cylindrical face).
    ///
    /// - Parameter face: The face to check against
    /// - Returns: true if this edge is a seam on the face
    public func isSeam(on face: Face) -> Bool {
        OCCTEdgeIsSeam(handle, face.handle)
    }
}
