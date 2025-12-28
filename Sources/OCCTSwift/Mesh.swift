import Foundation
import simd
import OCCTBridge

#if canImport(SceneKit)
import SceneKit
#endif

/// A triangulated mesh representation of a shape.
///
/// Meshes are created by tessellating a `Shape` and contain triangle data
/// suitable for visualization (SceneKit, RealityKit) or export (STL, OBJ).
///
/// ## Creating a Mesh
///
/// ```swift
/// let box = Shape.box(width: 10, height: 5, depth: 3)
/// let mesh = box.mesh(linearDeflection: 0.1)
/// ```
///
/// ## Deflection Parameters
///
/// The quality of tessellation is controlled by deflection:
/// - **linearDeflection**: Maximum distance between mesh and true surface (mm)
/// - **angularDeflection**: Maximum angle between adjacent triangles (radians)
///
/// Smaller values = more triangles = smoother appearance = larger files.
///
/// | Use Case | Linear | Angular |
/// |----------|--------|---------|
/// | Quick preview | 0.5 | 1.0 |
/// | Interactive display | 0.1 | 0.5 |
/// | 3D printing (FDM) | 0.05 | 0.3 |
/// | 3D printing (SLA) | 0.02 | 0.2 |
///
/// ## Using with SceneKit
///
/// ```swift
/// let geometry = mesh.sceneKitGeometry()
/// geometry.materials = [myMaterial]
/// let node = SCNNode(geometry: geometry)
/// scene.rootNode.addChildNode(node)
/// ```
public final class Mesh: @unchecked Sendable {
    internal let handle: OCCTMeshRef

    internal init(handle: OCCTMeshRef) {
        self.handle = handle
    }

    deinit {
        OCCTMeshRelease(handle)
    }

    // MARK: - Mesh Data

    /// Number of vertices in the mesh.
    public var vertexCount: Int {
        Int(OCCTMeshGetVertexCount(handle))
    }

    /// Number of triangles in the mesh.
    public var triangleCount: Int {
        Int(OCCTMeshGetTriangleCount(handle))
    }

    /// Vertex positions as array of SIMD3<Float>.
    ///
    /// Each vertex is a 3D point (x, y, z).
    /// Array length equals `vertexCount`.
    public var vertices: [SIMD3<Float>] {
        let count = vertexCount
        guard count > 0 else { return [] }

        var floats = [Float](repeating: 0, count: count * 3)
        floats.withUnsafeMutableBufferPointer { buffer in
            OCCTMeshGetVertices(handle, buffer.baseAddress)
        }

        var result: [SIMD3<Float>] = []
        result.reserveCapacity(count)
        for i in 0..<count {
            result.append(SIMD3(
                floats[i * 3],
                floats[i * 3 + 1],
                floats[i * 3 + 2]
            ))
        }
        return result
    }

    /// Vertex normals as array of SIMD3<Float>.
    ///
    /// Each normal is a unit vector perpendicular to the surface at that vertex.
    /// Array length equals `vertexCount`.
    public var normals: [SIMD3<Float>] {
        let count = vertexCount
        guard count > 0 else { return [] }

        var floats = [Float](repeating: 0, count: count * 3)
        floats.withUnsafeMutableBufferPointer { buffer in
            OCCTMeshGetNormals(handle, buffer.baseAddress)
        }

        var result: [SIMD3<Float>] = []
        result.reserveCapacity(count)
        for i in 0..<count {
            result.append(SIMD3(
                floats[i * 3],
                floats[i * 3 + 1],
                floats[i * 3 + 2]
            ))
        }
        return result
    }

    /// Triangle indices as array of UInt32.
    ///
    /// Every three consecutive indices define one triangle.
    /// Array length equals `triangleCount * 3`.
    ///
    /// ```swift
    /// // Triangle 0 uses vertices at indices[0], indices[1], indices[2]
    /// // Triangle 1 uses vertices at indices[3], indices[4], indices[5]
    /// // etc.
    /// ```
    public var indices: [UInt32] {
        let count = triangleCount
        guard count > 0 else { return [] }

        var result = [UInt32](repeating: 0, count: count * 3)
        result.withUnsafeMutableBufferPointer { buffer in
            OCCTMeshGetIndices(handle, buffer.baseAddress)
        }
        return result
    }

    /// Raw vertex data as contiguous Float array.
    ///
    /// Format: [x0, y0, z0, x1, y1, z1, ...]
    /// Length: `vertexCount * 3`
    public var vertexData: [Float] {
        let count = vertexCount
        guard count > 0 else { return [] }

        var result = [Float](repeating: 0, count: count * 3)
        result.withUnsafeMutableBufferPointer { buffer in
            OCCTMeshGetVertices(handle, buffer.baseAddress)
        }
        return result
    }

    /// Raw normal data as contiguous Float array.
    ///
    /// Format: [nx0, ny0, nz0, nx1, ny1, nz1, ...]
    /// Length: `vertexCount * 3`
    public var normalData: [Float] {
        let count = vertexCount
        guard count > 0 else { return [] }

        var result = [Float](repeating: 0, count: count * 3)
        result.withUnsafeMutableBufferPointer { buffer in
            OCCTMeshGetNormals(handle, buffer.baseAddress)
        }
        return result
    }

    // MARK: - Statistics

    /// Bounding box of the mesh.
    ///
    /// Returns (min, max) corners of the axis-aligned bounding box.
    public var boundingBox: (min: SIMD3<Float>, max: SIMD3<Float>) {
        let verts = vertices
        guard !verts.isEmpty else {
            return (.zero, .zero)
        }

        var minPt = verts[0]
        var maxPt = verts[0]

        for v in verts {
            minPt = min(minPt, v)
            maxPt = max(maxPt, v)
        }

        return (minPt, maxPt)
    }

    /// Size of the mesh in each dimension.
    public var size: SIMD3<Float> {
        let (minPt, maxPt) = boundingBox
        return maxPt - minPt
    }

    /// Center point of the mesh.
    public var center: SIMD3<Float> {
        let (minPt, maxPt) = boundingBox
        return (minPt + maxPt) / 2
    }
}

// MARK: - SceneKit Integration

#if canImport(SceneKit)
extension Mesh {
    /// Create a SceneKit geometry from this mesh.
    ///
    /// - Returns: An `SCNGeometry` suitable for use in a SceneKit scene
    ///
    /// The geometry includes vertex positions and normals.
    /// Apply materials separately:
    ///
    /// ```swift
    /// let geometry = mesh.sceneKitGeometry()
    ///
    /// let material = SCNMaterial()
    /// material.diffuse.contents = UIColor.gray
    /// material.metalness.contents = 0.8
    /// geometry.materials = [material]
    ///
    /// let node = SCNNode(geometry: geometry)
    /// ```
    public func sceneKitGeometry() -> SCNGeometry {
        let vertexData = self.vertexData
        let normalData = self.normalData
        let indexData = self.indices

        guard !vertexData.isEmpty else {
            // Return empty geometry
            return SCNGeometry()
        }

        // Create geometry sources
        let vertexSource = SCNGeometrySource(
            data: Data(bytes: vertexData, count: vertexData.count * MemoryLayout<Float>.size),
            semantic: .vertex,
            vectorCount: vertexCount,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<Float>.size * 3
        )

        let normalSource = SCNGeometrySource(
            data: Data(bytes: normalData, count: normalData.count * MemoryLayout<Float>.size),
            semantic: .normal,
            vectorCount: vertexCount,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<Float>.size * 3
        )

        // Create geometry element (triangle indices)
        let element = SCNGeometryElement(
            data: Data(bytes: indexData, count: indexData.count * MemoryLayout<UInt32>.size),
            primitiveType: .triangles,
            primitiveCount: triangleCount,
            bytesPerIndex: MemoryLayout<UInt32>.size
        )

        return SCNGeometry(sources: [vertexSource, normalSource], elements: [element])
    }

    /// Create a SceneKit node with this mesh and optional material.
    ///
    /// - Parameter material: Optional material to apply
    /// - Returns: An `SCNNode` ready to add to a scene
    public func sceneKitNode(material: SCNMaterial? = nil) -> SCNNode {
        let geometry = sceneKitGeometry()
        if let material = material {
            geometry.materials = [material]
        }
        return SCNNode(geometry: geometry)
    }
}
#endif

// MARK: - Metal Integration

extension Mesh {
    /// Get vertex data suitable for Metal buffers.
    ///
    /// - Returns: Tuple of (positions, normals, indices) as Data objects
    ///
    /// Use with `MTLDevice.makeBuffer(bytes:length:options:)`:
    ///
    /// ```swift
    /// let (positions, normals, indices) = mesh.metalBufferData()
    /// let vertexBuffer = device.makeBuffer(
    ///     bytes: positions.bytes,
    ///     length: positions.count,
    ///     options: .storageModeShared
    /// )
    /// ```
    public func metalBufferData() -> (positions: Data, normals: Data, indices: Data) {
        let vertexData = self.vertexData
        let normalData = self.normalData
        let indexData = self.indices

        let positionsData = Data(bytes: vertexData, count: vertexData.count * MemoryLayout<Float>.size)
        let normalsData = Data(bytes: normalData, count: normalData.count * MemoryLayout<Float>.size)
        let indicesData = Data(bytes: indexData, count: indexData.count * MemoryLayout<UInt32>.size)

        return (positionsData, normalsData, indicesData)
    }
}
