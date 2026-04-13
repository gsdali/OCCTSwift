//
//  BRepGraph.swift
//  OCCTSwift
//
//  Graph-based B-Rep topology representation (OCCT BRepGraph)
//

import OCCTBridge

/// A graph-based representation of B-Rep topology.
///
/// `TopologyGraph` provides cache-friendly traversal, O(1) upward navigation,
/// and parallel geometry extraction over a shape's topology. Built from a
/// `Shape`, it indexes all faces, edges, vertices, wires, shells, and solids
/// as flat entity vectors with integer cross-references.
///
/// ```swift
/// let box = Shape.box(width: 10, height: 10, depth: 10)
/// let graph = TopologyGraph(shape: box)!
/// print(graph.stats)  // faces: 6, edges: 12, vertices: 8
///
/// // Fast adjacency queries
/// let neighbors = graph.adjacentFaces(of: 0)  // [1, 2, 3, 4]
/// let shared = graph.sharedEdges(between: 0, and: 1)  // [3]
/// ```
public final class TopologyGraph: @unchecked Sendable {
    internal let handle: OCCTBRepGraphRef

    /// Build a topology graph from a shape.
    /// - Parameters:
    ///   - shape: The shape to analyze.
    ///   - parallel: Whether to build using parallel threads (default: false).
    public init?(shape: Shape, parallel: Bool = false) {
        guard let h = OCCTBRepGraphCreate(shape.handle, parallel) else { return nil }
        self.handle = h
    }

    deinit {
        OCCTBRepGraphRelease(handle)
    }

    // MARK: - Topology Counts

    /// Total number of nodes in the graph (all entity kinds).
    public var nodeCount: Int { Int(OCCTBRepGraphNbNodes(handle)) }

    /// Number of faces.
    public var faceCount: Int { Int(OCCTBRepGraphNbFaces(handle)) }
    /// Number of active (non-removed) faces.
    public var activeFaceCount: Int { Int(OCCTBRepGraphNbActiveFaces(handle)) }
    /// Number of edges.
    public var edgeCount: Int { Int(OCCTBRepGraphNbEdges(handle)) }
    /// Number of active edges.
    public var activeEdgeCount: Int { Int(OCCTBRepGraphNbActiveEdges(handle)) }
    /// Number of vertices.
    public var vertexCount: Int { Int(OCCTBRepGraphNbVertices(handle)) }
    /// Number of active vertices.
    public var activeVertexCount: Int { Int(OCCTBRepGraphNbActiveVertices(handle)) }
    /// Number of wires.
    public var wireCount: Int { Int(OCCTBRepGraphNbWires(handle)) }
    /// Number of shells.
    public var shellCount: Int { Int(OCCTBRepGraphNbShells(handle)) }
    /// Number of solids.
    public var solidCount: Int { Int(OCCTBRepGraphNbSolids(handle)) }
    /// Number of coedges (half-edges).
    public var coedgeCount: Int { Int(OCCTBRepGraphNbCoEdges(handle)) }
    /// Number of compounds.
    public var compoundCount: Int { Int(OCCTBRepGraphNbCompounds(handle)) }

    // MARK: - Geometry Counts

    /// Number of distinct surfaces.
    public var surfaceCount: Int { Int(OCCTBRepGraphNbSurfaces(handle)) }
    /// Number of distinct 3D curves.
    public var curve3DCount: Int { Int(OCCTBRepGraphNbCurves3D(handle)) }
    /// Number of distinct 2D curves.
    public var curve2DCount: Int { Int(OCCTBRepGraphNbCurves2D(handle)) }

    // MARK: - Face Queries

    /// Indices of faces adjacent to a given face (sharing an edge).
    public func adjacentFaces(of faceIndex: Int) -> [Int] {
        let count = Int(OCCTBRepGraphFaceAdjacentCount(handle, Int32(faceIndex)))
        if count == 0 { return [] }
        var indices = [Int32](repeating: 0, count: count)
        indices.withUnsafeMutableBufferPointer { buf in
            OCCTBRepGraphFaceAdjacentIndices(handle, Int32(faceIndex), buf.baseAddress!)
        }
        return indices.map { Int($0) }
    }

    /// Indices of edges shared between two faces.
    public func sharedEdges(between faceA: Int, and faceB: Int) -> [Int] {
        let count = Int(OCCTBRepGraphFaceSharedEdgeCount(handle, Int32(faceA), Int32(faceB)))
        if count == 0 { return [] }
        var indices = [Int32](repeating: 0, count: count)
        indices.withUnsafeMutableBufferPointer { buf in
            OCCTBRepGraphFaceSharedEdgeIndices(handle, Int32(faceA), Int32(faceB), buf.baseAddress!)
        }
        return indices.map { Int($0) }
    }

    /// Index of the outer wire of a face.
    public func outerWire(of faceIndex: Int) -> Int {
        Int(OCCTBRepGraphFaceOuterWire(handle, Int32(faceIndex)))
    }

    // MARK: - Edge Queries

    /// Number of faces an edge belongs to.
    public func faceCount(of edgeIndex: Int) -> Int {
        Int(OCCTBRepGraphEdgeNbFaces(handle, Int32(edgeIndex)))
    }

    /// Indices of faces an edge belongs to.
    public func faces(of edgeIndex: Int) -> [Int] {
        let count = faceCount(of: edgeIndex)
        if count == 0 { return [] }
        var indices = [Int32](repeating: 0, count: count)
        indices.withUnsafeMutableBufferPointer { buf in
            OCCTBRepGraphEdgeFaceIndices(handle, Int32(edgeIndex), buf.baseAddress!)
        }
        return indices.map { Int($0) }
    }

    /// Whether an edge is a boundary edge (belongs to only one face).
    public func isBoundaryEdge(_ edgeIndex: Int) -> Bool {
        OCCTBRepGraphEdgeIsBoundary(handle, Int32(edgeIndex))
    }

    /// Whether an edge is manifold (belongs to exactly two faces).
    public func isManifoldEdge(_ edgeIndex: Int) -> Bool {
        OCCTBRepGraphEdgeIsManifold(handle, Int32(edgeIndex))
    }

    /// Indices of edges adjacent to a given edge (sharing a vertex).
    public func adjacentEdges(of edgeIndex: Int) -> [Int] {
        let count = Int(OCCTBRepGraphEdgeAdjacentCount(handle, Int32(edgeIndex)))
        if count == 0 { return [] }
        var indices = [Int32](repeating: 0, count: count)
        indices.withUnsafeMutableBufferPointer { buf in
            OCCTBRepGraphEdgeAdjacentIndices(handle, Int32(edgeIndex), buf.baseAddress!)
        }
        return indices.map { Int($0) }
    }

    // MARK: - Vertex Queries

    /// Indices of edges connected to a vertex.
    public func edges(of vertexIndex: Int) -> [Int] {
        let count = Int(OCCTBRepGraphVertexEdgeCount(handle, Int32(vertexIndex)))
        if count == 0 { return [] }
        var indices = [Int32](repeating: 0, count: count)
        indices.withUnsafeMutableBufferPointer { buf in
            OCCTBRepGraphVertexEdgeIndices(handle, Int32(vertexIndex), buf.baseAddress!)
        }
        return indices.map { Int($0) }
    }

    // MARK: - Explorers

    /// Node kind enumeration matching OCCT BRepGraph_NodeId::Kind.
    public enum NodeKind: Int32, Sendable {
        case solid = 0
        case shell = 1
        case face = 2
        case wire = 3
        case edge = 4
        case vertex = 5
        case compound = 6
        case compSolid = 7
        case coedge = 8
    }

    /// Count descendant nodes of a given kind from a root node.
    public func childCount(rootKind: NodeKind, rootIndex: Int, targetKind: NodeKind) -> Int {
        Int(OCCTBRepGraphChildCount(handle, rootKind.rawValue, Int32(rootIndex), targetKind.rawValue))
    }

    /// Count parent nodes of a given node.
    public func parentCount(nodeKind: NodeKind, nodeIndex: Int) -> Int {
        Int(OCCTBRepGraphParentCount(handle, nodeKind.rawValue, Int32(nodeIndex)))
    }

    // MARK: - Node Status

    /// Check if a node has been soft-removed.
    public func isRemoved(nodeKind: NodeKind, nodeIndex: Int) -> Bool {
        OCCTBRepGraphIsRemoved(handle, nodeKind.rawValue, Int32(nodeIndex))
    }

    // MARK: - Root Nodes

    /// Root node as (kind, index) pair.
    public struct RootNode: Sendable {
        public let kind: NodeKind
        public let index: Int
    }

    /// Root nodes of the graph.
    public var rootNodes: [RootNode] {
        let count = Int(OCCTBRepGraphRootCount(handle))
        if count == 0 { return [] }
        var kinds = [Int32](repeating: 0, count: count)
        var indices = [Int32](repeating: 0, count: count)
        kinds.withUnsafeMutableBufferPointer { kBuf in
            indices.withUnsafeMutableBufferPointer { iBuf in
                OCCTBRepGraphRootNodes(handle, kBuf.baseAddress!, iBuf.baseAddress!)
            }
        }
        return (0..<count).compactMap { i in
            guard let kind = NodeKind(rawValue: kinds[i]) else { return nil }
            return RootNode(kind: kind, index: Int(indices[i]))
        }
    }

    // MARK: - Validate

    /// Validation result.
    public struct ValidationResult: Sendable {
        public let isValid: Bool
        public let errorCount: Int
        public let warningCount: Int
    }

    /// Validate the graph structure.
    public func validate() -> ValidationResult {
        let r = OCCTBRepGraphValidateDetailed(handle)
        return ValidationResult(isValid: r.isValid,
                                errorCount: Int(r.errorCount),
                                warningCount: Int(r.warningCount))
    }

    /// Whether the graph is structurally valid.
    public var isValid: Bool { OCCTBRepGraphValidate(handle) }

    // MARK: - Compact

    /// Compaction result.
    public struct CompactResult: Sendable {
        public let removedVertices: Int
        public let removedEdges: Int
        public let removedFaces: Int
        public let nodesAfter: Int
    }

    /// Compact the graph by removing unreferenced nodes.
    @discardableResult
    public func compact() -> CompactResult {
        let r = OCCTBRepGraphCompact(handle)
        return CompactResult(removedVertices: Int(r.removedVertices),
                             removedEdges: Int(r.removedEdges),
                             removedFaces: Int(r.removedFaces),
                             nodesAfter: Int(r.nodesAfter))
    }

    // MARK: - Deduplicate

    /// Deduplication result.
    public struct DeduplicateResult: Sendable {
        public let canonicalSurfaces: Int
        public let canonicalCurves: Int
        public let surfaceRewrites: Int
        public let curveRewrites: Int
    }

    /// Deduplicate shared geometry in the graph.
    @discardableResult
    public func deduplicate() -> DeduplicateResult {
        let r = OCCTBRepGraphDeduplicate(handle)
        return DeduplicateResult(canonicalSurfaces: Int(r.canonicalSurfaces),
                                 canonicalCurves: Int(r.canonicalCurves),
                                 surfaceRewrites: Int(r.surfaceRewrites),
                                 curveRewrites: Int(r.curveRewrites))
    }

    // MARK: - Statistics

    /// Comprehensive graph statistics.
    public struct Stats: Sendable, CustomStringConvertible {
        public let solids: Int
        public let shells: Int
        public let faces: Int
        public let wires: Int
        public let edges: Int
        public let vertices: Int
        public let coedges: Int
        public let compounds: Int
        public let totalNodes: Int
        public let surfaces: Int
        public let curves3D: Int
        public let curves2D: Int

        public var description: String {
            "TopologyGraph.Stats(solids: \(solids), shells: \(shells), faces: \(faces), " +
            "wires: \(wires), edges: \(edges), vertices: \(vertices), coedges: \(coedges), " +
            "nodes: \(totalNodes), surfaces: \(surfaces), curves3D: \(curves3D), curves2D: \(curves2D))"
        }
    }

    /// Get comprehensive graph statistics.
    public var stats: Stats {
        let s = OCCTBRepGraphGetStats(handle)
        return Stats(solids: Int(s.solids), shells: Int(s.shells), faces: Int(s.faces),
                     wires: Int(s.wires), edges: Int(s.edges), vertices: Int(s.vertices),
                     coedges: Int(s.coedges), compounds: Int(s.compounds),
                     totalNodes: Int(s.totalNodes), surfaces: Int(s.surfaces),
                     curves3D: Int(s.curves3d), curves2D: Int(s.curves2d))
    }

    // MARK: - Shape Reconstruction (v0.133.0)

    /// Reconstruct a TopoDS_Shape from a graph node.
    public func shape(nodeKind: NodeKind, nodeIndex: Int) -> Shape? {
        guard let ref = OCCTBRepGraphShapeFromNode(handle, nodeKind.rawValue, Int32(nodeIndex)) else {
            return nil
        }
        return Shape(handle: ref)
    }

    /// Find the node (kind, index) for a shape. Returns nil if not found.
    public func findNode(for shape: Shape) -> (kind: NodeKind, index: Int)? {
        var outKind: Int32 = -1
        var outIndex: Int32 = -1
        OCCTBRepGraphFindNode(handle, shape.handle, &outKind, &outIndex)
        if outKind < 0 { return nil }
        guard let kind = NodeKind(rawValue: outKind) else { return nil }
        return (kind: kind, index: Int(outIndex))
    }

    /// Check if a shape is known to the graph.
    public func hasNode(for shape: Shape) -> Bool {
        OCCTBRepGraphHasNode(handle, shape.handle)
    }

    // MARK: - Vertex Geometry (v0.133.0)

    /// Get the 3D point of a vertex.
    public func vertexPoint(_ vertexIndex: Int) -> (x: Double, y: Double, z: Double) {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTBRepGraphVertexPoint(handle, Int32(vertexIndex), &x, &y, &z)
        return (x, y, z)
    }

    /// Get the tolerance of a vertex.
    public func vertexTolerance(_ vertexIndex: Int) -> Double {
        OCCTBRepGraphVertexTolerance(handle, Int32(vertexIndex))
    }

    // MARK: - Edge Geometry (v0.133.0)

    /// Get the tolerance of an edge.
    public func edgeTolerance(_ edgeIndex: Int) -> Double {
        OCCTBRepGraphEdgeTolerance(handle, Int32(edgeIndex))
    }

    /// Check if an edge is degenerated.
    public func isEdgeDegenerated(_ edgeIndex: Int) -> Bool {
        OCCTBRepGraphEdgeIsDegenerated(handle, Int32(edgeIndex))
    }

    /// Check if an edge has the SameParameter flag.
    public func isEdgeSameParameter(_ edgeIndex: Int) -> Bool {
        OCCTBRepGraphEdgeIsSameParameter(handle, Int32(edgeIndex))
    }

    /// Check if an edge has the SameRange flag.
    public func isEdgeSameRange(_ edgeIndex: Int) -> Bool {
        OCCTBRepGraphEdgeIsSameRange(handle, Int32(edgeIndex))
    }

    /// Get the parameter range of an edge.
    public func edgeRange(_ edgeIndex: Int) -> (first: Double, last: Double) {
        var first = 0.0, last = 0.0
        OCCTBRepGraphEdgeRange(handle, Int32(edgeIndex), &first, &last)
        return (first, last)
    }

    /// Check if an edge has a 3D curve.
    public func edgeHasCurve(_ edgeIndex: Int) -> Bool {
        OCCTBRepGraphEdgeHasCurve(handle, Int32(edgeIndex))
    }

    /// Check if an edge is a seam (closed) on a face.
    public func isEdgeClosedOnFace(edgeIndex: Int, faceIndex: Int) -> Bool {
        OCCTBRepGraphEdgeIsClosedOnFace(handle, Int32(edgeIndex), Int32(faceIndex))
    }

    /// Check if an edge has a 3D polygon.
    public func edgeHasPolygon3D(_ edgeIndex: Int) -> Bool {
        OCCTBRepGraphEdgeHasPolygon3D(handle, Int32(edgeIndex))
    }

    /// Get the maximum continuity order of an edge (GeomAbs_Shape enum as Int).
    public func edgeMaxContinuity(_ edgeIndex: Int) -> Int {
        Int(OCCTBRepGraphEdgeMaxContinuity(handle, Int32(edgeIndex)))
    }

    // MARK: - Face Geometry (v0.133.0)

    /// Get the tolerance of a face.
    public func faceTolerance(_ faceIndex: Int) -> Double {
        OCCTBRepGraphFaceTolerance(handle, Int32(faceIndex))
    }

    /// Check if a face has the natural restriction flag.
    public func isFaceNaturalRestriction(_ faceIndex: Int) -> Bool {
        OCCTBRepGraphFaceIsNaturalRestriction(handle, Int32(faceIndex))
    }

    /// Check if a face has a surface.
    public func faceHasSurface(_ faceIndex: Int) -> Bool {
        OCCTBRepGraphFaceHasSurface(handle, Int32(faceIndex))
    }

    /// Check if a face has a triangulation.
    public func faceHasTriangulation(_ faceIndex: Int) -> Bool {
        OCCTBRepGraphFaceHasTriangulation(handle, Int32(faceIndex))
    }

    // MARK: - Wire Queries (v0.133.0)

    /// Check if a wire is topologically closed.
    public func isWireClosed(_ wireIndex: Int) -> Bool {
        OCCTBRepGraphWireIsClosed(handle, Int32(wireIndex))
    }

    /// Number of coedges in a wire.
    public func wireCoEdgeCount(_ wireIndex: Int) -> Int {
        Int(OCCTBRepGraphWireNbCoEdges(handle, Int32(wireIndex)))
    }

    /// Number of faces a wire belongs to.
    public func wireFaceCount(_ wireIndex: Int) -> Int {
        Int(OCCTBRepGraphWireFaceCount(handle, Int32(wireIndex)))
    }

    /// Indices of faces a wire belongs to.
    public func wireFaces(_ wireIndex: Int) -> [Int] {
        let count = wireFaceCount(wireIndex)
        if count == 0 { return [] }
        var indices = [Int32](repeating: 0, count: count)
        indices.withUnsafeMutableBufferPointer { buf in
            OCCTBRepGraphWireFaceIndices(handle, Int32(wireIndex), buf.baseAddress!)
        }
        return indices.map { Int($0) }
    }

    // MARK: - CoEdge Queries (v0.133.0)

    /// Get the edge index of a coedge.
    public func coedgeEdge(_ coedgeIndex: Int) -> Int {
        Int(OCCTBRepGraphCoEdgeEdge(handle, Int32(coedgeIndex)))
    }

    /// Get the face index of a coedge.
    public func coedgeFace(_ coedgeIndex: Int) -> Int {
        Int(OCCTBRepGraphCoEdgeFace(handle, Int32(coedgeIndex)))
    }

    /// Get the seam pair coedge index, or nil if none.
    public func coedgeSeamPair(_ coedgeIndex: Int) -> Int? {
        let idx = Int(OCCTBRepGraphCoEdgeSeamPair(handle, Int32(coedgeIndex)))
        return idx >= 0 ? idx : nil
    }

    /// Check if a coedge has a PCurve.
    public func coedgeHasPCurve(_ coedgeIndex: Int) -> Bool {
        OCCTBRepGraphCoEdgeHasPCurve(handle, Int32(coedgeIndex))
    }

    /// Get the PCurve parameter range of a coedge.
    public func coedgeRange(_ coedgeIndex: Int) -> (first: Double, last: Double) {
        var first = 0.0, last = 0.0
        OCCTBRepGraphCoEdgeRange(handle, Int32(coedgeIndex), &first, &last)
        return (first, last)
    }

    // MARK: - Shell Queries (v0.133.0)

    /// Number of solids a shell belongs to.
    public func shellSolidCount(_ shellIndex: Int) -> Int {
        Int(OCCTBRepGraphShellSolidCount(handle, Int32(shellIndex)))
    }

    /// Indices of solids a shell belongs to.
    public func shellSolids(_ shellIndex: Int) -> [Int] {
        let count = shellSolidCount(shellIndex)
        if count == 0 { return [] }
        var indices = [Int32](repeating: 0, count: count)
        indices.withUnsafeMutableBufferPointer { buf in
            OCCTBRepGraphShellSolidIndices(handle, Int32(shellIndex), buf.baseAddress!)
        }
        return indices.map { Int($0) }
    }

    // MARK: - Solid Queries (v0.133.0)

    /// Number of comp-solids a solid belongs to.
    public func solidCompSolidCount(_ solidIndex: Int) -> Int {
        Int(OCCTBRepGraphSolidCompSolidCount(handle, Int32(solidIndex)))
    }

    // MARK: - History (v0.133.0)

    /// Number of history records.
    public var historyRecordCount: Int {
        Int(OCCTBRepGraphHistoryNbRecords(handle))
    }

    /// Whether history recording is enabled.
    public var isHistoryEnabled: Bool {
        get { OCCTBRepGraphHistoryIsEnabled(handle) }
        set { OCCTBRepGraphHistorySetEnabled(handle, newValue) }
    }

    /// Clear all history records.
    public func clearHistory() {
        OCCTBRepGraphHistoryClear(handle)
    }

    // MARK: - Poly Counts (v0.133.0)

    /// Number of triangulations in the graph.
    public var triangulationCount: Int { Int(OCCTBRepGraphNbTriangulations(handle)) }

    /// Number of 3D polygons in the graph.
    public var polygon3DCount: Int { Int(OCCTBRepGraphNbPolygons3D(handle)) }

    // MARK: - Active Geometry Counts (v0.133.0)

    /// Number of active (non-removed) surfaces.
    public var activeSurfaceCount: Int { Int(OCCTBRepGraphNbActiveSurfaces(handle)) }

    /// Number of active 3D curves.
    public var activeCurve3DCount: Int { Int(OCCTBRepGraphNbActiveCurves3D(handle)) }

    /// Number of active 2D curves.
    public var activeCurve2DCount: Int { Int(OCCTBRepGraphNbActiveCurves2D(handle)) }

    // MARK: - SameDomain (v0.133.0)

    /// Indices of same-domain faces for a given face.
    public func sameDomainFaces(of faceIndex: Int) -> [Int] {
        let count = Int(OCCTBRepGraphFaceSameDomainCount(handle, Int32(faceIndex)))
        if count == 0 { return [] }
        var indices = [Int32](repeating: 0, count: count)
        indices.withUnsafeMutableBufferPointer { buf in
            OCCTBRepGraphFaceSameDomainIndices(handle, Int32(faceIndex), buf.baseAddress!)
        }
        return indices.map { Int($0) }
    }

    // MARK: - Copy and Transform (v0.133.0)

    /// Deep copy of the graph.
    public func copy(copyGeometry: Bool = true) -> TopologyGraph? {
        guard let ref = OCCTBRepGraphCopy(handle, copyGeometry) else { return nil }
        return TopologyGraph(borrowedHandle: ref)
    }

    /// Copy a single face sub-graph.
    public func copyFace(_ faceIndex: Int, copyGeometry: Bool = true) -> TopologyGraph? {
        guard let ref = OCCTBRepGraphCopyFace(handle, Int32(faceIndex), copyGeometry) else {
            return nil
        }
        return TopologyGraph(borrowedHandle: ref)
    }

    /// Transform the graph by a translation.
    public func translated(dx: Double, dy: Double, dz: Double, copyGeometry: Bool = true) -> TopologyGraph? {
        guard let ref = OCCTBRepGraphTransformTranslation(handle, dx, dy, dz, copyGeometry) else {
            return nil
        }
        return TopologyGraph(borrowedHandle: ref)
    }

    /// Internal initializer from an already-created handle (takes ownership).
    internal init(borrowedHandle: OCCTBRepGraphRef) {
        self.handle = borrowedHandle
    }

    // MARK: - Product (Assembly) Queries (v0.134.0)

    /// Number of products in the graph (0 for simple shapes).
    public var productCount: Int { Int(OCCTBRepGraphNbProducts(handle)) }

    /// Number of occurrences in the graph (0 for simple shapes).
    public var occurrenceCount: Int { Int(OCCTBRepGraphNbOccurrences(handle)) }

    /// Whether product at index is an assembly.
    public func productIsAssembly(_ productIndex: Int) -> Bool {
        OCCTBRepGraphProductIsAssembly(handle, Int32(productIndex))
    }

    /// Whether product at index is a part.
    public func productIsPart(_ productIndex: Int) -> Bool {
        OCCTBRepGraphProductIsPart(handle, Int32(productIndex))
    }

    /// Number of active child occurrences of a product.
    public func productComponentCount(_ productIndex: Int) -> Int {
        Int(OCCTBRepGraphProductNbComponents(handle, Int32(productIndex)))
    }

    /// Shape root node of a product, or nil if assembly/invalid.
    public func productShapeRoot(_ productIndex: Int) -> (kind: NodeKind, index: Int)? {
        let k = OCCTBRepGraphProductShapeRootKind(handle, Int32(productIndex))
        let i = OCCTBRepGraphProductShapeRootIndex(handle, Int32(productIndex))
        guard k >= 0, let kind = NodeKind(rawValue: k) else { return nil }
        return (kind: kind, index: Int(i))
    }

    /// Product index of an occurrence.
    public func occurrenceProduct(_ occIndex: Int) -> Int {
        Int(OCCTBRepGraphOccurrenceProduct(handle, Int32(occIndex)))
    }

    /// Parent product index of an occurrence.
    public func occurrenceParentProduct(_ occIndex: Int) -> Int {
        Int(OCCTBRepGraphOccurrenceParentProduct(handle, Int32(occIndex)))
    }

    /// Parent occurrence index of an occurrence, or nil if top-level.
    public func occurrenceParentOccurrence(_ occIndex: Int) -> Int? {
        let idx = Int(OCCTBRepGraphOccurrenceParentOccurrence(handle, Int32(occIndex)))
        return idx >= 0 ? idx : nil
    }

    /// Number of root products.
    public var rootProductCount: Int {
        Int(OCCTBRepGraphRootProductCount(handle))
    }

    /// Indices of root products.
    public var rootProductIndices: [Int] {
        let count = rootProductCount
        if count == 0 { return [] }
        var indices = [Int32](repeating: 0, count: count)
        indices.withUnsafeMutableBufferPointer { buf in
            OCCTBRepGraphRootProductIndices(handle, buf.baseAddress!)
        }
        return indices.map { Int($0) }
    }

    // MARK: - Reference Counts (v0.134.0)

    /// Reference kind enumeration matching BRepGraph_RefId::Kind.
    public enum RefKind: Int32, Sendable {
        case shell = 0
        case face = 1
        case wire = 2
        case coedge = 3
        case vertex = 4
        case solid = 5
        case child = 6
        case occurrence = 7
    }

    /// Number of shell reference entries.
    public var shellRefCount: Int { Int(OCCTBRepGraphNbShellRefs(handle)) }

    /// Number of face reference entries.
    public var faceRefCount: Int { Int(OCCTBRepGraphNbFaceRefs(handle)) }

    /// Number of wire reference entries.
    public var wireRefCount: Int { Int(OCCTBRepGraphNbWireRefs(handle)) }

    /// Number of coedge reference entries.
    public var coedgeRefCount: Int { Int(OCCTBRepGraphNbCoEdgeRefs(handle)) }

    /// Number of vertex reference entries.
    public var vertexRefCount: Int { Int(OCCTBRepGraphNbVertexRefs(handle)) }

    /// Number of solid reference entries.
    public var solidRefCount: Int { Int(OCCTBRepGraphNbSolidRefs(handle)) }

    /// Number of child reference entries.
    public var childRefCount: Int { Int(OCCTBRepGraphNbChildRefs(handle)) }

    /// Number of occurrence reference entries.
    public var occurrenceRefCount: Int { Int(OCCTBRepGraphNbOccurrenceRefs(handle)) }

    // MARK: - Reference Entry Queries (v0.134.0)

    /// Child node kind from a reference entry.
    public func refChildNodeKind(_ refKind: RefKind, refIndex: Int) -> NodeKind? {
        let k = OCCTBRepGraphRefChildNodeKind(handle, refKind.rawValue, Int32(refIndex))
        guard k >= 0 else { return nil }
        return NodeKind(rawValue: k)
    }

    /// Child node index from a reference entry.
    public func refChildNodeIndex(_ refKind: RefKind, refIndex: Int) -> Int {
        Int(OCCTBRepGraphRefChildNodeIndex(handle, refKind.rawValue, Int32(refIndex)))
    }

    /// Whether a reference entry is removed.
    public func isRefRemoved(_ refKind: RefKind, refIndex: Int) -> Bool {
        OCCTBRepGraphRefIsRemoved(handle, refKind.rawValue, Int32(refIndex))
    }

    /// Orientation of a reference entry (TopAbs_Orientation as Int).
    public func refOrientation(_ refKind: RefKind, refIndex: Int) -> Int {
        Int(OCCTBRepGraphRefOrientation(handle, refKind.rawValue, Int32(refIndex)))
    }

    // MARK: - Face Definition Details (v0.134.0)

    /// Number of wire refs on a face.
    public func faceWireCount(_ faceIndex: Int) -> Int {
        Int(OCCTBRepGraphFaceNbWires(handle, Int32(faceIndex)))
    }

    /// Number of isolated vertex refs on a face.
    public func faceVertexRefCount(_ faceIndex: Int) -> Int {
        Int(OCCTBRepGraphFaceNbVertexRefs(handle, Int32(faceIndex)))
    }

    // MARK: - Edge Definition Details (v0.134.0)

    /// Start vertex definition index of an edge, or nil if invalid.
    public func edgeStartVertex(_ edgeIndex: Int) -> Int? {
        let idx = Int(OCCTBRepGraphEdgeStartVertex(handle, Int32(edgeIndex)))
        return idx >= 0 ? idx : nil
    }

    /// End vertex definition index of an edge, or nil if invalid.
    public func edgeEndVertex(_ edgeIndex: Int) -> Int? {
        let idx = Int(OCCTBRepGraphEdgeEndVertex(handle, Int32(edgeIndex)))
        return idx >= 0 ? idx : nil
    }

    /// Whether an edge is topologically closed (start == end vertex).
    public func isEdgeClosed(_ edgeIndex: Int) -> Bool {
        OCCTBRepGraphEdgeIsClosed(handle, Int32(edgeIndex))
    }

    // MARK: - Compound/CompSolid Queries (v0.134.0)

    /// Number of parent compounds of a compound.
    public func compoundParentCount(_ compoundIndex: Int) -> Int {
        Int(OCCTBRepGraphCompoundParentCount(handle, Int32(compoundIndex)))
    }

    /// Number of child refs of a compound.
    public func compoundChildCount(_ compoundIndex: Int) -> Int {
        Int(OCCTBRepGraphCompoundChildCount(handle, Int32(compoundIndex)))
    }

    /// Number of solid refs in a comp-solid.
    public func compSolidSolidCount(_ compSolidIndex: Int) -> Int {
        Int(OCCTBRepGraphCompSolidSolidCount(handle, Int32(compSolidIndex)))
    }

    /// Number of parent compounds of a comp-solid.
    public func compSolidCompoundCount(_ compSolidIndex: Int) -> Int {
        Int(OCCTBRepGraphCompSolidCompoundCount(handle, Int32(compSolidIndex)))
    }

    // MARK: - Edge Additional Queries (v0.134.0)

    /// Indices of wires an edge belongs to.
    public func edgeWires(_ edgeIndex: Int) -> [Int] {
        let count = Int(OCCTBRepGraphEdgeWireCount(handle, Int32(edgeIndex)))
        if count == 0 { return [] }
        var indices = [Int32](repeating: 0, count: count)
        indices.withUnsafeMutableBufferPointer { buf in
            OCCTBRepGraphEdgeWireIndices(handle, Int32(edgeIndex), buf.baseAddress!)
        }
        return indices.map { Int($0) }
    }

    /// Indices of coedges of an edge.
    public func edgeCoEdges(_ edgeIndex: Int) -> [Int] {
        let count = Int(OCCTBRepGraphEdgeCoEdgeCount(handle, Int32(edgeIndex)))
        if count == 0 { return [] }
        var indices = [Int32](repeating: 0, count: count)
        indices.withUnsafeMutableBufferPointer { buf in
            OCCTBRepGraphEdgeCoEdgeIndices(handle, Int32(edgeIndex), buf.baseAddress!)
        }
        return indices.map { Int($0) }
    }

    /// Find the coedge index for an (edge, face) pair, or nil if not found.
    public func edgeFindCoEdge(edgeIndex: Int, faceIndex: Int) -> Int? {
        let idx = Int(OCCTBRepGraphEdgeFindCoEdge(handle, Int32(edgeIndex), Int32(faceIndex)))
        return idx >= 0 ? idx : nil
    }

    // MARK: - Face Additional Queries (v0.134.0)

    /// Number of shells a face belongs to.
    public func faceShellCount(_ faceIndex: Int) -> Int {
        Int(OCCTBRepGraphFaceShellCount(handle, Int32(faceIndex)))
    }

    /// Indices of shells a face belongs to.
    public func faceShells(_ faceIndex: Int) -> [Int] {
        let count = faceShellCount(faceIndex)
        if count == 0 { return [] }
        var indices = [Int32](repeating: 0, count: count)
        indices.withUnsafeMutableBufferPointer { buf in
            OCCTBRepGraphFaceShellIndices(handle, Int32(faceIndex), buf.baseAddress!)
        }
        return indices.map { Int($0) }
    }

    /// Number of compounds a face belongs to.
    public func faceCompoundCount(_ faceIndex: Int) -> Int {
        Int(OCCTBRepGraphFaceCompoundCount(handle, Int32(faceIndex)))
    }

    // MARK: - Shell Additional Queries (v0.134.0)

    /// Number of compounds a shell belongs to.
    public func shellCompoundCount(_ shellIndex: Int) -> Int {
        Int(OCCTBRepGraphShellCompoundCount(handle, Int32(shellIndex)))
    }

    /// Whether a shell is closed.
    public func isShellClosed(_ shellIndex: Int) -> Bool {
        OCCTBRepGraphShellIsClosed(handle, Int32(shellIndex))
    }

    // MARK: - Solid Additional Queries (v0.134.0)

    /// Number of compounds a solid belongs to.
    public func solidCompoundCount(_ solidIndex: Int) -> Int {
        Int(OCCTBRepGraphSolidCompoundCount(handle, Int32(solidIndex)))
    }

    // MARK: - CompSolid Count (v0.134.0)

    /// Number of comp-solids in the graph.
    public var compSolidCount: Int { Int(OCCTBRepGraphNbCompSolids(handle)) }
}
