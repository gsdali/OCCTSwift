import Foundation
import simd
import OCCTBridge

// MARK: - Edge Convexity

/// Classification of the dihedral angle at an edge between two faces
public enum EdgeConvexity: Int32, Sendable {
    case concave = -1   // Interior angle > 180° (pocket-like, going inward)
    case smooth = 0     // Tangent faces (~180°)
    case convex = 1     // Interior angle < 180° (fillet-like, going outward)

    init(fromOCCT value: OCCTEdgeConvexity) {
        switch value {
        case OCCTEdgeConvexityConcave: self = .concave
        case OCCTEdgeConvexitySmooth: self = .smooth
        case OCCTEdgeConvexityConvex: self = .convex
        default: self = .smooth
        }
    }
}

// MARK: - Attributed Adjacency Graph

/// A node in the Attributed Adjacency Graph representing a B-Rep face
public struct AAGNode: Sendable {
    /// Index of the face in the shape
    public let faceIndex: Int

    /// Face normal at center (if computable)
    public let normal: SIMD3<Double>?

    /// Whether face is planar
    public let isPlanar: Bool

    /// Whether face is horizontal (normal points up or down)
    public let isHorizontal: Bool

    /// Whether face is upward-facing
    public let isUpward: Bool

    /// Whether face is downward-facing
    public let isDownward: Bool

    /// Whether face is vertical
    public let isVertical: Bool

    /// Z level if horizontal planar face
    public let zLevel: Double?

    /// Bounding box of the face
    public let bounds: (min: SIMD3<Double>, max: SIMD3<Double>)
}

/// An edge in the Attributed Adjacency Graph representing adjacency between two faces
public struct AAGEdge: Sendable {
    /// Index of first adjacent face
    public let face1Index: Int

    /// Index of second adjacent face
    public let face2Index: Int

    /// Convexity classification of the shared edge(s)
    public let convexity: EdgeConvexity

    /// Number of shared edges between the faces
    public let sharedEdgeCount: Int
}

/// Attributed Adjacency Graph for feature recognition
///
/// The AAG represents the topology of a solid as a graph where:
/// - Nodes are faces
/// - Edges connect adjacent faces (those sharing a B-Rep edge)
/// - Each graph edge is attributed with convexity information
public final class AAG: @unchecked Sendable {
    /// The shape this graph represents
    public let shape: Shape

    /// All nodes (faces) in the graph
    public private(set) var nodes: [AAGNode] = []

    /// All edges (adjacencies) in the graph
    public private(set) var edges: [AAGEdge] = []

    /// Adjacency list: for each face index, list of (neighbor index, edge index)
    public private(set) var adjacencyList: [[Int: Int]] = []

    /// Create an AAG from a shape
    public init(shape: Shape) {
        self.shape = shape
        buildGraph()
    }

    private func buildGraph() {
        let faces = shape.faces()
        let faceCount = faces.count

        // Initialize adjacency list
        adjacencyList = Array(repeating: [:], count: faceCount)

        // Build nodes
        for (index, face) in faces.enumerated() {
            let node = AAGNode(
                faceIndex: index,
                normal: face.normal,
                isPlanar: face.isPlanar,
                isHorizontal: face.isHorizontal(),
                isUpward: face.isUpwardFacing(),
                isDownward: face.isDownwardFacing(),
                isVertical: face.isVertical(),
                zLevel: face.zLevel,
                bounds: face.bounds
            )
            nodes.append(node)
        }

        // Build edges by checking all face pairs for adjacency
        for i in 0..<faceCount {
            for j in (i+1)..<faceCount {
                let face1 = faces[i]
                let face2 = faces[j]

                // Check if adjacent
                if OCCTFacesAreAdjacent(shape.handle, face1.handle, face2.handle) {
                    // Get shared edge count and convexity
                    var sharedEdges: [OCCTEdgeRef?] = Array(repeating: nil, count: 10)
                    let edgeCount = OCCTFaceGetSharedEdges(
                        shape.handle, face1.handle, face2.handle,
                        &sharedEdges, 10
                    )

                    // Get convexity from first shared edge
                    var convexity: EdgeConvexity = .smooth
                    if edgeCount > 0, let firstEdge = sharedEdges[0] {
                        let occtConvexity = OCCTEdgeGetConvexity(
                            shape.handle, firstEdge,
                            face1.handle, face2.handle
                        )
                        convexity = EdgeConvexity(fromOCCT: occtConvexity)

                        // Release edges
                        for k in 0..<Int(edgeCount) {
                            if let edge = sharedEdges[k] {
                                OCCTEdgeRelease(edge)
                            }
                        }
                    }

                    let edgeIndex = edges.count
                    let edge = AAGEdge(
                        face1Index: i,
                        face2Index: j,
                        convexity: convexity,
                        sharedEdgeCount: Int(edgeCount)
                    )
                    edges.append(edge)

                    // Update adjacency list (bidirectional)
                    adjacencyList[i][j] = edgeIndex
                    adjacencyList[j][i] = edgeIndex
                }
            }
        }
    }

    /// Get neighbors of a face
    public func neighbors(of faceIndex: Int) -> [Int] {
        guard faceIndex < adjacencyList.count else { return [] }
        return Array(adjacencyList[faceIndex].keys)
    }

    /// Get the edge between two faces (if adjacent)
    public func edge(between face1: Int, and face2: Int) -> AAGEdge? {
        guard face1 < adjacencyList.count else { return nil }
        guard let edgeIndex = adjacencyList[face1][face2] else { return nil }
        return edges[edgeIndex]
    }

    /// Get all concave neighbors of a face
    public func concaveNeighbors(of faceIndex: Int) -> [Int] {
        guard faceIndex < adjacencyList.count else { return [] }
        return adjacencyList[faceIndex].compactMap { (neighbor, edgeIndex) in
            edges[edgeIndex].convexity == .concave ? neighbor : nil
        }
    }

    /// Get all convex neighbors of a face
    public func convexNeighbors(of faceIndex: Int) -> [Int] {
        guard faceIndex < adjacencyList.count else { return [] }
        return adjacencyList[faceIndex].compactMap { (neighbor, edgeIndex) in
            edges[edgeIndex].convexity == .convex ? neighbor : nil
        }
    }
}

// MARK: - Pocket Feature

/// A recognized pocket feature in a solid
public struct PocketFeature: Sendable {
    /// Index of the floor face
    public let floorFaceIndex: Int

    /// Indices of the wall faces
    public let wallFaceIndices: [Int]

    /// Z level of the pocket floor
    public let zLevel: Double

    /// Bounding box of the pocket
    public let bounds: (min: SIMD3<Double>, max: SIMD3<Double>)

    /// Whether this is an open pocket (not fully enclosed)
    public let isOpen: Bool

    /// Approximate depth of the pocket
    public var depth: Double {
        bounds.max.z - zLevel
    }
}

// MARK: - Feature Recognition Extensions

extension AAG {
    /// Detect pockets in the shape using AAG analysis
    ///
    /// A pocket is identified by:
    /// 1. An upward-facing horizontal floor face
    /// 2. Surrounded by vertical wall faces
    /// 3. Connected to walls via concave edges
    public func detectPockets() -> [PocketFeature] {
        var pockets: [PocketFeature] = []

        // Find all upward-facing horizontal faces as potential floors
        let potentialFloors = nodes.enumerated().filter { _, node in
            node.isUpward && node.isHorizontal && node.isPlanar
        }

        for (floorIndex, floorNode) in potentialFloors {
            guard let floorZ = floorNode.zLevel else { continue }

            // Get concave neighbors (these should be walls)
            let concaveNeighbors = self.concaveNeighbors(of: floorIndex)

            // Filter to vertical faces only
            let wallIndices = concaveNeighbors.filter { neighborIndex in
                nodes[neighborIndex].isVertical
            }

            // Need at least one wall to be a pocket
            guard !wallIndices.isEmpty else { continue }

            // Calculate pocket bounds from floor and walls
            var minX = floorNode.bounds.min.x
            var minY = floorNode.bounds.min.y
            var maxX = floorNode.bounds.max.x
            var maxY = floorNode.bounds.max.y
            var maxZ = floorZ

            for wallIndex in wallIndices {
                let wallBounds = nodes[wallIndex].bounds
                minX = min(minX, wallBounds.min.x)
                minY = min(minY, wallBounds.min.y)
                maxX = max(maxX, wallBounds.max.x)
                maxY = max(maxY, wallBounds.max.y)
                maxZ = max(maxZ, wallBounds.max.z)
            }

            // Check if pocket is closed (all walls connected to each other form a loop)
            // For now, consider it open if it has fewer than 3 walls
            let isOpen = wallIndices.count < 3

            let pocket = PocketFeature(
                floorFaceIndex: floorIndex,
                wallFaceIndices: wallIndices,
                zLevel: floorZ,
                bounds: (
                    min: SIMD3(minX, minY, floorZ),
                    max: SIMD3(maxX, maxY, maxZ)
                ),
                isOpen: isOpen
            )

            pockets.append(pocket)
        }

        // Sort by Z level (deepest first)
        pockets.sort { $0.zLevel < $1.zLevel }

        return pockets
    }

    /// Detect holes (through or blind) in the shape
    ///
    /// A hole is identified by:
    /// 1. A cylindrical or conical face
    /// 2. With concave edges connecting to other faces
    public func detectHoles() -> [(faceIndex: Int, radius: Double, depth: Double)] {
        var holes: [(faceIndex: Int, radius: Double, depth: Double)] = []

        // Find cylindrical faces that are holes (all edges are concave)
        for (index, node) in nodes.enumerated() {
            // Check if all neighbors are connected via concave edges
            let allNeighbors = neighbors(of: index)
            let concaveNeighbors = self.concaveNeighbors(of: index)

            // If all adjacencies are concave, this might be a hole
            guard allNeighbors.count == concaveNeighbors.count && allNeighbors.count >= 1 else {
                continue
            }

            // For now, use bounds to estimate if circular
            let width = node.bounds.max.x - node.bounds.min.x
            let height = node.bounds.max.y - node.bounds.min.y
            let depth = node.bounds.max.z - node.bounds.min.z

            // Check if roughly circular in XY (for vertical holes)
            let aspectRatio = max(width, height) / min(width, height)
            if aspectRatio < 1.2 && !node.isPlanar {
                let radius = (width + height) / 4.0
                holes.append((faceIndex: index, radius: radius, depth: depth))
            }
        }

        return holes
    }
}

// MARK: - Shape Extension

extension Shape {
    /// Build an Attributed Adjacency Graph for this shape
    public func buildAAG() -> AAG {
        return AAG(shape: self)
    }

    /// Detect pockets using AAG-based feature recognition
    public func detectPocketsAAG() -> [PocketFeature] {
        let aag = buildAAG()
        return aag.detectPockets()
    }
}
