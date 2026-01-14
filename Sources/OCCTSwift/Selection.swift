import Foundation
import simd
import OCCTBridge

// MARK: - Ray Hit Result

/// Result from a ray cast against a shape
public struct RayHit: Sendable {
    /// 3D point where ray intersects surface
    public let point: SIMD3<Double>
    
    /// Surface normal at intersection point
    public let normal: SIMD3<Double>
    
    /// Index of the face that was hit (0-based)
    public let faceIndex: Int
    
    /// Distance from ray origin to intersection point
    public let distance: Double
    
    /// UV parameters on the surface at intersection
    public let uv: SIMD2<Double>
}

// MARK: - Shape Ray Casting Extension

extension Shape {
    /// Cast a ray against the shape and find all intersections
    /// - Parameters:
    ///   - origin: Starting point of the ray
    ///   - direction: Direction of the ray (will be normalized)
    ///   - tolerance: Intersection tolerance (default: 0.001)
    ///   - maxHits: Maximum number of hits to return (default: 100)
    /// - Returns: Array of ray hits sorted by distance
    public func raycast(
        origin: SIMD3<Double>,
        direction: SIMD3<Double>,
        tolerance: Double = 0.001,
        maxHits: Int = 100
    ) -> [RayHit] {
        guard maxHits > 0 else { return [] }
        
        // Allocate buffer for hits
        var hitBuffer = [OCCTRayHit](repeating: OCCTRayHit(), count: maxHits)
        
        let hitCount = OCCTShapeRaycast(
            handle,
            origin.x, origin.y, origin.z,
            direction.x, direction.y, direction.z,
            tolerance,
            &hitBuffer,
            Int32(maxHits)
        )
        
        guard hitCount > 0 else { return [] }
        
        // Convert to Swift structs
        var results = [RayHit]()
        results.reserveCapacity(Int(hitCount))
        
        for i in 0..<Int(hitCount) {
            let hit = hitBuffer[i]
            results.append(RayHit(
                point: SIMD3(hit.point.0, hit.point.1, hit.point.2),
                normal: SIMD3(hit.normal.0, hit.normal.1, hit.normal.2),
                faceIndex: Int(hit.faceIndex),
                distance: hit.distance,
                uv: SIMD2(hit.uv.0, hit.uv.1)
            ))
        }
        
        // Sort by distance (nearest first)
        results.sort { $0.distance < $1.distance }
        
        return results
    }
    
    /// Cast a ray and return only the nearest hit
    /// - Parameters:
    ///   - origin: Starting point of the ray
    ///   - direction: Direction of the ray
    ///   - tolerance: Intersection tolerance
    /// - Returns: Nearest hit, or nil if no intersection
    public func raycastNearest(
        origin: SIMD3<Double>,
        direction: SIMD3<Double>,
        tolerance: Double = 0.001
    ) -> RayHit? {
        raycast(origin: origin, direction: direction, tolerance: tolerance, maxHits: 100).first
    }
}

// MARK: - Shape Face Index Access Extension

extension Shape {
    /// Get total number of faces in the shape
    public var faceCount: Int {
        Int(OCCTShapeGetFaceCount(handle))
    }
    
    /// Get face by index (0-based)
    /// - Parameter index: The face index
    /// - Returns: Face at the given index, or nil if index is out of bounds
    public func face(at index: Int) -> Face? {
        guard let faceHandle = OCCTShapeGetFaceAtIndex(handle, Int32(index)) else {
            return nil
        }
        return Face(handle: faceHandle, index: index)
    }
}
