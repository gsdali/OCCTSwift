import Foundation
import simd
import OCCTBridge

/// A face from a 3D solid shape - represents a bounded surface
public final class Face: @unchecked Sendable {
    internal let handle: OCCTFaceRef

    internal init(handle: OCCTFaceRef) {
        self.handle = handle
    }

    deinit {
        OCCTFaceRelease(handle)
    }

    // MARK: - Properties

    /// Get the normal vector at the center of the face
    public var normal: SIMD3<Double>? {
        var nx: Double = 0, ny: Double = 0, nz: Double = 0
        guard OCCTFaceGetNormal(handle, &nx, &ny, &nz) else {
            return nil
        }
        return SIMD3(nx, ny, nz)
    }

    /// Get the outer wire (boundary) of the face
    public var outerWire: Wire? {
        guard let wireHandle = OCCTFaceGetOuterWire(handle) else {
            return nil
        }
        return Wire(handle: wireHandle)
    }

    /// Get the bounding box of the face
    public var bounds: (min: SIMD3<Double>, max: SIMD3<Double>) {
        var minX: Double = 0, minY: Double = 0, minZ: Double = 0
        var maxX: Double = 0, maxY: Double = 0, maxZ: Double = 0
        OCCTFaceGetBounds(handle, &minX, &minY, &minZ, &maxX, &maxY, &maxZ)
        return (min: SIMD3(minX, minY, minZ), max: SIMD3(maxX, maxY, maxZ))
    }

    /// Check if the face is planar (flat)
    public var isPlanar: Bool {
        OCCTFaceIsPlanar(handle)
    }

    /// Check if the face is horizontal (normal points up or down)
    /// - Parameter tolerance: Angle tolerance in radians (default ~0.5 degrees)
    public func isHorizontal(tolerance: Double = 0.01) -> Bool {
        guard let n = normal else { return false }
        return abs(n.z) > cos(tolerance)
    }

    /// Check if the face is upward-facing (normal points up)
    /// - Parameter tolerance: Angle tolerance in radians (default ~0.5 degrees)
    public func isUpwardFacing(tolerance: Double = 0.01) -> Bool {
        guard let n = normal else { return false }
        return n.z > cos(tolerance)
    }

    /// Get the Z level of a horizontal planar face
    /// Returns nil if face is not horizontal or not planar
    public var zLevel: Double? {
        var z: Double = 0
        guard OCCTFaceGetZLevel(handle, &z) else {
            return nil
        }
        return z
    }
}

// MARK: - Shape Extension for Face Analysis

extension Shape {
    /// Get all faces from the solid
    public func faces() -> [Face] {
        var count: Int32 = 0
        guard let faceArray = OCCTShapeGetFaces(handle, &count) else {
            return []
        }
        // Use OCCTFreeFaceArrayOnly - Swift Face objects now own the face handles
        // and will release them in their deinit. We only need to free the array container.
        defer { OCCTFreeFaceArrayOnly(faceArray) }

        var faces: [Face] = []
        for i in 0..<Int(count) {
            if let faceHandle = faceArray[i] {
                faces.append(Face(handle: faceHandle))
            }
        }

        return faces
    }

    /// Get horizontal faces (normals pointing up or down)
    /// - Parameter tolerance: Angle tolerance in radians (default ~0.5 degrees)
    public func horizontalFaces(tolerance: Double = 0.01) -> [Face] {
        var count: Int32 = 0
        guard let faceArray = OCCTShapeGetHorizontalFaces(handle, tolerance, &count) else {
            return []
        }
        defer { OCCTFreeFaceArrayOnly(faceArray) }

        var faces: [Face] = []
        for i in 0..<Int(count) {
            if let faceHandle = faceArray[i] {
                faces.append(Face(handle: faceHandle))
            }
        }

        return faces
    }

    /// Get upward-facing horizontal faces (potential pocket floors)
    /// - Parameter tolerance: Angle tolerance in radians (default ~0.5 degrees)
    public func upwardFaces(tolerance: Double = 0.01) -> [Face] {
        var count: Int32 = 0
        guard let faceArray = OCCTShapeGetUpwardFaces(handle, tolerance, &count) else {
            return []
        }
        defer { OCCTFreeFaceArrayOnly(faceArray) }

        var faces: [Face] = []
        for i in 0..<Int(count) {
            if let faceHandle = faceArray[i] {
                faces.append(Face(handle: faceHandle))
            }
        }

        return faces
    }

    /// Get faces grouped by Z level (for CAM pocket detection)
    /// - Parameter tolerance: Z tolerance for grouping faces
    /// - Returns: Dictionary mapping Z levels to arrays of faces at that level
    public func facesByZLevel(tolerance: Double = 0.01) -> [Double: [Face]] {
        let horizontal = horizontalFaces()
        var result: [Double: [Face]] = [:]

        for face in horizontal {
            guard let z = face.zLevel else { continue }

            // Find existing group within tolerance
            var foundGroup = false
            for (existingZ, _) in result {
                if abs(existingZ - z) < tolerance {
                    result[existingZ]?.append(face)
                    foundGroup = true
                    break
                }
            }

            if !foundGroup {
                result[z] = [face]
            }
        }

        return result
    }
}
