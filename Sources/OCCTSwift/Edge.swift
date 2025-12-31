import Foundation
import simd
import OCCTBridge

/// An edge from a 3D solid shape - represents a curve between vertices
public final class Edge: @unchecked Sendable {
    internal let handle: OCCTEdgeRef
    
    internal init(handle: OCCTEdgeRef) {
        self.handle = handle
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
        return Edge(handle: edgeHandle)
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
