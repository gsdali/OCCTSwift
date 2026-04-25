import Foundation
import simd
import OCCTBridge

/// Surface unwrapping / unfolding into a flat 2D pattern.
///
/// `Unfold` converts a 3D shape into a flat compound of 2D faces in the XY
/// plane. Use cases span sheet-metal manufacturing, ship-hull plate
/// development, aerospace skinning, model making, and paper craft. It is the
/// inverse of `SheetMetal.Builder`.
///
/// The pipeline is incremental and tier-based:
///
/// - **Tier 1 (this checkpoint, `polyhedral`)** — exact unfolding for shells
///   whose every face is planar. Walks the face-adjacency graph from a chosen
///   root, lays out each face by rotating around its shared edge with the
///   already-placed parent. Distortion is zero.
/// - Tier 2 (`developable`, future) — adds analytic single-curvature
///   surfaces (cylinder, cone, frustum) using closed-form parameterization.
/// - Tier 3 (`sheetMetal`, future) — adds bend-allowance / K-factor for
///   cylindrical-fillet bend topology.
/// - Solid input (`solid`, future) — extracts a mid-surface from a closed
///   solid before routing into the sheet-metal path.
///
/// All current entry points are read-only on the input shape — the input is
/// not mutated. Output is a new `Shape` (compound of laid-out faces).
public enum Unfold {

    /// Stable identifier for an edge within a parent shape.
    ///
    /// Pairs the OCCT-level shape hash with the 0-based index of the edge in
    /// `shape.subShapes(ofType: .edge)`. Stable across repeated traversals of
    /// the same shape; not stable across shapes built by independent
    /// constructions (each fresh build has its own indexing).
    public struct EdgeIdentifier: Hashable, Sendable {
        public let shapeHash: Int
        public let edgeIndex: Int

        public init(shapeHash: Int, edgeIndex: Int) {
            self.shapeHash = shapeHash
            self.edgeIndex = edgeIndex
        }
    }

    /// A spanning-tree edge that stayed connected across the unfold (a fold,
    /// as opposed to a cut). Carries the dihedral angle that was straightened
    /// out — `0` means the faces were already coplanar; `±π` is a fully
    /// closed sheet.
    public struct FoldEdge: Sendable {
        public let edge: EdgeIdentifier
        public let parentFaceIndex: Int
        public let childFaceIndex: Int
        public let dihedralAngle: Double
    }

    public struct Result: Sendable {
        /// Compound of every face after unfolding, in the XY plane.
        public let flat: Shape
        /// Per-face flat shapes, keyed by their 0-based index in the input
        /// `subShapes(ofType: .face)`.
        public let faces: [Int: Shape]
        public let folds: [FoldEdge]
        public let cuts: [EdgeIdentifier]
        /// CP1: `true` if any pairwise 2D bounding box of the laid-out faces
        /// overlaps. CP5 will return per-pair detail and resolve via re-cuts.
        public let overlaps: Bool
        public let rootFaceIndex: Int
    }

    public struct Parameters: Sendable {
        /// 0-based face index to start the unfold from. Default: face with
        /// the largest area.
        public var rootFaceIndex: Int?
        /// Edges that must be cut (excluded from the spanning tree).
        public var pinnedCuts: Set<EdgeIdentifier>
        /// Edges that must remain folded. Currently advisory — the BFS picks
        /// folds itself; if a pinned edge ends up as a cycle-closing cut,
        /// CP5's overlap-resolution will respect this hint.
        public var pinnedFolds: Set<EdgeIdentifier>
        public var tolerance: Double
        /// CP5: when true, `polyhedral(_:)` iteratively cuts edges to
        /// resolve self-overlaps. Each iteration adds one cut; up to
        /// `maxOverlapIterations` iterations are performed before giving up.
        public var resolveOverlaps: Bool
        public var maxOverlapIterations: Int

        public init(
            rootFaceIndex: Int? = nil,
            pinnedCuts: Set<EdgeIdentifier> = [],
            pinnedFolds: Set<EdgeIdentifier> = [],
            tolerance: Double = 1e-7,
            resolveOverlaps: Bool = false,
            maxOverlapIterations: Int = 30
        ) {
            self.rootFaceIndex = rootFaceIndex
            self.pinnedCuts = pinnedCuts
            self.pinnedFolds = pinnedFolds
            self.tolerance = tolerance
            self.resolveOverlaps = resolveOverlaps
            self.maxOverlapIterations = maxOverlapIterations
        }
    }

    public enum UnfoldError: Error, Sendable {
        case noFaces
        case nonPlanarFace(faceIndex: Int)
        case nonDevelopableFace(faceIndex: Int)
        case missingNormal(faceIndex: Int)
        case bridgeFailed(stage: String)
        case rootIndexOutOfRange(Int, faceCount: Int)
        case bendDetectionFailed(faceIndex: Int, reason: String)
        case noPanels
    }

    /// Sheet-metal-specific parameters for the bend-allowance calculation.
    ///
    /// Bend allowance is the developed length of the cylindrical fillet at
    /// the neutral fiber: `BA = θ · (R + K · t)` where `θ` is the bend
    /// angle in radians, `R` is the inside bend radius, `K` is the K-factor
    /// (typically 0.33–0.5; 0.44 is a reasonable default for mild steel),
    /// and `t` is the sheet thickness.
    public struct SheetMetalParameters: Sendable {
        public var thickness: Double
        public var kFactor: Double

        public init(thickness: Double, kFactor: Double = 0.44) {
            self.thickness = thickness
            self.kFactor = kFactor
        }

        public func bendAllowance(radius R: Double, angle theta: Double) -> Double {
            return theta * (R + kFactor * thickness)
        }
    }

    /// A detected bend in a sheet-metal shell.
    public struct Bend: Sendable {
        /// 0-based index of the cylindrical face in `subShapes(ofType: .face)`.
        public let cylindricalFaceIndex: Int
        public let radius: Double
        public let axisOrigin: SIMD3<Double>
        public let axisDirection: SIMD3<Double>
        /// Length of the bend along its axis (= `vMax − vMin`).
        public let length: Double
        /// Bend angle in radians = `uMax − uMin` of the cylindrical face.
        public let angle: Double
        /// 0-based indices of the two adjacent planar faces (the panels the
        /// bend connects). Always 2 entries for a well-formed sheet-metal
        /// bend.
        public let panelFaceIndices: [Int]
    }

    /// Tier 1 — unfold a shell whose every face is planar.
    ///
    /// Throws `nonPlanarFace` if any face is not planar; for cylinders, cones,
    /// and other developables, see `developable(_:)` (future checkpoint).
    ///
    /// When `parameters.resolveOverlaps` is true, the unfolder prefers a
    /// **connected non-overlapping net**:
    ///
    /// 1. **Try every face as root.** Different roots produce different
    ///    spanning trees and different 2D layouts. Schlickenrieder (1997)
    ///    showed empirically that essentially every convex polyhedron has
    ///    a non-overlapping edge unfolding from at least one root, even
    ///    though it's an open conjecture in general (Shephard 1975).
    ///    This phase is cheap — N BFS attempts on N-face shapes — and
    ///    almost always finds a connected solution for the Platonic
    ///    solids and ordinary CAD polyhedra.
    /// 2. **Fall back to fragmentation cuts.** If no rooting gives a
    ///    connected non-overlapping unfold, iteratively pin each
    ///    overlap-victim face's tree-parent edge so it becomes a fresh
    ///    island root. Up to `parameters.maxOverlapIterations` cuts are
    ///    added before giving up. The result has `overlaps == true`
    ///    if even fragmentation can't clear the bbox-overlap test.
    ///
    /// `parameters.rootFaceIndex` is honoured even when
    /// `resolveOverlaps` is true: if the caller pinned a root, that root
    /// is the only one tried in phase 1.
    public static func polyhedral(
        _ shape: Shape,
        parameters: Parameters = .init()
    ) throws -> Result {
        if !parameters.resolveOverlaps {
            return try polyhedralOnce(shape, parameters: parameters)
        }
        // Phase 1: try every face as root × {BFS, DFS} traversals, looking
        // for a connected non-overlapping unfold. BFS produces balanced
        // (compact-fan) layouts; DFS produces strip-like ones. Different
        // shapes prefer different orderings — the icosahedron, for
        // example, almost always overlaps under BFS but unfolds cleanly
        // under DFS from many roots.
        let faceCount = shape.subShapes(ofType: .face).count
        var rootedParams = parameters
        rootedParams.resolveOverlaps = false
        let rootsToTry: [Int]
        if let pinned = parameters.rootFaceIndex {
            rootsToTry = [pinned]
        } else if faceCount > 0 {
            rootsToTry = Array(0..<faceCount)
        } else {
            rootsToTry = []
        }
        // Try natural ordering first (deterministic), then random shuffles.
        // Seed 0 = natural; seeds 1…N = random permutations of each
        // node's adjacency list. For 30 edges the spanning-tree count is
        // huge; sampling a few hundred random orderings reliably finds a
        // non-overlapping unfold for any Platonic solid.
        let shuffleSeeds: [UInt64] = [0] + (1...32).map { UInt64($0) }
        for seed in shuffleSeeds {
            for traversal in [TraversalOrder.bfs, .dfs] {
                for r in rootsToTry {
                    rootedParams.rootFaceIndex = r
                    if let result = try? polyhedralOnce(
                        shape,
                        parameters: rootedParams,
                        traversal: traversal,
                        childShuffleSeed: seed
                    ), !result.overlaps {
                        return result
                    }
                }
            }
        }
        rootedParams.rootFaceIndex = parameters.rootFaceIndex

        // Phase 2: no single connected non-overlapping unfold found. Fall
        // back to iterative fragmentation cuts. The strategy is "pin B's
        // tree-parent edge" — when a pair (A, B) overlaps, we promote B
        // to its own island next round by cutting the edge that brought
        // it into A's tree.
        var params = parameters
        params.resolveOverlaps = false
        var lastResult: Result?
        var addedCuts: Set<EdgeIdentifier> = []
        for _ in 0..<parameters.maxOverlapIterations {
            let result = try polyhedralOnce(shape, parameters: params)
            lastResult = result
            if !result.overlaps { break }
            guard let edgeToCut = pickEdgeToIsolateOverlap(result) else { break }
            if !params.pinnedCuts.insert(edgeToCut).inserted { break }
            addedCuts.insert(edgeToCut)
        }
        // Merge added cuts into the final result so callers can see them.
        guard var final = lastResult else {
            return try polyhedralOnce(shape, parameters: params)
        }
        if !addedCuts.isEmpty {
            var combined = final.cuts
            let existing = Set(final.cuts)
            for c in addedCuts where !existing.contains(c) {
                combined.append(c)
            }
            final = Result(
                flat: final.flat,
                faces: final.faces,
                folds: final.folds,
                cuts: combined,
                overlaps: final.overlaps,
                rootFaceIndex: final.rootFaceIndex
            )
        }
        return final
    }

    /// Tree traversal order for `polyhedralOnce`. Different orders produce
    /// different spanning trees and different 2D layouts. Some shapes (the
    /// icosahedron, in particular) self-overlap under BFS but unfold
    /// cleanly under DFS, which produces strip-like rather than balanced
    /// layouts.
    fileprivate enum TraversalOrder { case bfs, dfs }

    /// Single-pass polyhedral unfold (no overlap iteration).
    ///
    /// `childShuffleSeed`: when non-zero, deterministically permutes the
    /// child-visit order at each node. Used by `polyhedral`'s connected-
    /// net search to explore many spanning trees from each root: 20
    /// roots × 2 traversals × ~10 shuffle seeds = 400 candidate trees,
    /// which reliably finds a non-overlapping unfold for the Platonic
    /// solids and almost all convex polyhedra encountered in practice.
    fileprivate static func polyhedralOnce(
        _ shape: Shape,
        parameters: Parameters,
        traversal: TraversalOrder = .bfs,
        childShuffleSeed: UInt64 = 0
    ) throws -> Result {
        let faceShapes = shape.subShapes(ofType: .face)
        guard !faceShapes.isEmpty else { throw UnfoldError.noFaces }

        let edgeShapes = shape.subShapes(ofType: .edge)
        let shapeHash = shape.hashCode

        var faces: [FaceInfo] = []
        faces.reserveCapacity(faceShapes.count)
        for (i, fs) in faceShapes.enumerated() {
            guard let face = Face(fs) else {
                throw UnfoldError.bridgeFailed(stage: "Face from shape #\(i)")
            }
            guard face.isPlanar else {
                throw UnfoldError.nonPlanarFace(faceIndex: i)
            }
            guard let n = face.normal else {
                throw UnfoldError.missingNormal(faceIndex: i)
            }
            let origin = anyPointOnFace(face, fallbackShape: fs)
                ?? fs.center
            faces.append(FaceInfo(
                shape: fs,
                normal: simd_normalize(n),
                origin: origin,
                area: face.area()
            ))
        }

        var edges: [EdgeRecord] = []
        edges.reserveCapacity(edgeShapes.count)
        for (i, es) in edgeShapes.enumerated() {
            guard let edge = Edge(es) else {
                throw UnfoldError.bridgeFailed(stage: "Edge from shape #\(i)")
            }
            let adj = shape.adjacentFaces(forEdge: es).map { $0 - 1 }
            edges.append(EdgeRecord(
                index: i,
                shape: es,
                endpoints: edge.endpoints,
                adjacentFaces: adj
            ))
        }

        var adjacency: [[(neighbor: Int, edgeIndex: Int)]] =
            Array(repeating: [], count: faces.count)
        for e in edges {
            let id = EdgeIdentifier(shapeHash: shapeHash, edgeIndex: e.index)
            if parameters.pinnedCuts.contains(id) { continue }
            guard e.adjacentFaces.count == 2 else { continue }
            let a = e.adjacentFaces[0]
            let b = e.adjacentFaces[1]
            guard faces.indices.contains(a), faces.indices.contains(b) else {
                continue
            }
            adjacency[a].append((b, e.index))
            adjacency[b].append((a, e.index))
        }

        if childShuffleSeed != 0 {
            var rng = SplitMix64(seed: childShuffleSeed)
            for i in adjacency.indices {
                adjacency[i].shuffle(using: &rng)
            }
        }

        let rootIdx: Int
        if let pinned = parameters.rootFaceIndex {
            guard faces.indices.contains(pinned) else {
                throw UnfoldError.rootIndexOutOfRange(pinned, faceCount: faces.count)
            }
            rootIdx = pinned
        } else {
            rootIdx = faces.indices.max(by: { faces[$0].area < faces[$1].area }) ?? 0
        }

        var transform: [simd_double4x4?] = Array(repeating: nil, count: faces.count)
        var folds: [FoldEdge] = []
        var foldEdges: Set<EdgeIdentifier> = []
        var cuts: [EdgeIdentifier] = []
        var cutSet: Set<EdgeIdentifier> = []
        var visited: Set<Int> = []
        // Forest BFS: when pinned cuts disconnect the dual graph into
        // multiple components, lay each as its own island. The first
        // component starts at `rootIdx`; subsequent components pick the
        // largest unvisited face as their root and offset its laydown
        // along +X past the prior islands' bounding boxes.
        var nextIslandX: Double = 0
        let islandPadding: Double = 1.0
        var firstRoot = rootIdx
        while true {
            let root: Int
            if visited.isEmpty {
                root = firstRoot
            } else if let r = faces.indices
                .filter({ !visited.contains($0) })
                .max(by: { faces[$0].area < faces[$1].area }) {
                root = r
            } else {
                break
            }
            // Lay this island's root at (nextIslandX, 0) plus its laydown.
            var rootT = laydownTransform(face: faces[root])
            if !visited.isEmpty {
                rootT = translation(SIMD3(nextIslandX, 0, 0)) * rootT
            }
            transform[root] = rootT
            visited.insert(root)
            firstRoot = root // last seed (used to set rootFaceIndex on result)

            var pending: [Int] = [root]
            while !pending.isEmpty {
                let parent: Int
                switch traversal {
                case .bfs: parent = pending.removeFirst()
                case .dfs: parent = pending.removeLast()
                }
                let parentT = transform[parent]!
                let parentNormalLaid = transformNormal(parentT, faces[parent].normal)
                for (child, edgeIdx) in adjacency[parent] {
                    let id = EdgeIdentifier(shapeHash: shapeHash, edgeIndex: edgeIdx)
                    if foldEdges.contains(id) { continue }
                    if visited.contains(child) {
                        if cutSet.insert(id).inserted { cuts.append(id) }
                        continue
                    }
                    visited.insert(child)
                    let edge = edges[edgeIdx]
                    let edgeStartLaid = transformPoint(parentT, edge.endpoints.start)
                    let edgeEndLaid = transformPoint(parentT, edge.endpoints.end)
                    let childNormalLaid = transformNormal(parentT, faces[child].normal)
                    let unfoldRot = rotationMatrix(
                        axisStart: edgeStartLaid,
                        axisEnd: edgeEndLaid,
                        fromNormal: childNormalLaid,
                        toNormal: parentNormalLaid
                    )
                    let childT = unfoldRot.matrix * parentT
                    transform[child] = childT
                    foldEdges.insert(id)
                    folds.append(FoldEdge(
                        edge: id,
                        parentFaceIndex: parent,
                        childFaceIndex: child,
                        dihedralAngle: unfoldRot.angle
                    ))
                    pending.append(child)
                }
            }

            // Advance island cursor past the laid components' actual bbox
            // (in 2D). Use the exact post-transform bounds rather than a
            // radius-of-area proxy — for highly anisotropic faces (long
            // strips) the proxy under-estimates extent.
            var maxX = -Double.infinity
            for i in faces.indices {
                guard let t = transform[i] else { continue }
                let mat = matrix12(from: t)
                guard let laid = faces[i].shape.transformed(matrix: mat) else { continue }
                let b = laid.bounds
                if b.max.x > maxX { maxX = b.max.x }
            }
            if maxX.isFinite {
                nextIslandX = maxX + islandPadding
            }
            if visited.count == faces.count { break }
        }

        var laidShapes: [Int: Shape] = [:]
        var laidArray: [Shape] = []
        for i in faces.indices {
            guard let t = transform[i] else { continue }
            let mat = matrix12(from: t)
            guard let flat = faces[i].shape.transformed(matrix: mat) else {
                throw UnfoldError.bridgeFailed(stage: "transform face #\(i)")
            }
            laidShapes[i] = flat
            laidArray.append(flat)
        }

        let compound: Shape
        if laidArray.count == 1 {
            compound = laidArray[0]
        } else if let merged = Shape.compound(laidArray) {
            compound = merged
        } else {
            throw UnfoldError.bridgeFailed(stage: "compound flat faces")
        }

        let overlaps = anyBoundingBoxOverlap(in: laidArray, tolerance: parameters.tolerance)

        return Result(
            flat: compound,
            faces: laidShapes,
            folds: folds,
            cuts: cuts,
            overlaps: overlaps,
            rootFaceIndex: rootIdx
        )
    }
}

// MARK: - Mid-surface extraction + closed-solid input (CP4)

extension Unfold {

    /// Tier 4 — unfold a closed thick sheet-metal solid by first extracting a
    /// mid-surface thin-shell, then routing through `sheetMetal(_:)`.
    ///
    /// Pair every face with another face at distance `sheet.thickness` whose
    /// normal is anti-parallel (planar pair) or whose axis is coincident with
    /// radii differing by `sheet.thickness` (cylindrical pair). For each
    /// pair, emit a mid-surface face — the average position. Side faces
    /// that have no pair within tolerance are dropped (they're the swept
    /// thickness perimeter, not part of the developable shell).
    ///
    /// Limitations:
    /// - Only **planar/planar** and **cylindrical/cylindrical** pairs are
    ///   detected. Pairs across surface types (e.g. a planar inner corner
    ///   meeting an outer cylindrical fillet) throw `bendDetectionFailed`.
    /// - Pairing tolerance is `parameters.tolerance` (default 1e-7),
    ///   loosened internally by 100× for the offset-distance check because
    ///   tessellated input isn't always geometrically exact.
    public static func solid(
        _ shape: Shape,
        parameters: Parameters = .init(),
        sheet: SheetMetalParameters
    ) throws -> Result {
        let thinShell = try midSurface(
            of: shape,
            thickness: sheet.thickness,
            tolerance: max(parameters.tolerance, 1e-5))
        return try sheetMetal(thinShell, parameters: parameters, sheet: sheet)
    }

    /// Extract the mid-surface thin-shell from a thick shape.
    ///
    /// Returns a compound (or sewn shell) of the mid-surface faces. The
    /// caller can pass it to `sheetMetal(_:)` or `developable(_:)`.
    public static func midSurface(
        of shape: Shape,
        thickness t: Double,
        tolerance: Double = 1e-5
    ) throws -> Shape {
        let faceShapes = shape.subShapes(ofType: .face)
        guard !faceShapes.isEmpty else { throw UnfoldError.noFaces }

        // Cache surface info per face for pairing.
        var infos: [MidPairFaceInfo?] = Array(repeating: nil, count: faceShapes.count)
        for (i, fs) in faceShapes.enumerated() {
            guard let face = Face(fs) else { continue }
            switch face.surfaceType {
            case .plane:
                guard let n = face.normal else { continue }
                let centroid = fs.center
                infos[i] = MidPairFaceInfo(
                    shape: fs, face: face,
                    kind: .plane(normal: simd_normalize(n), centroid: centroid))
            case .cylinder:
                guard let surf = fs.faceSurfaceGeom() else { continue }
                let cyl = surf.cylinderProperties
                let axis = cyl.axis
                infos[i] = MidPairFaceInfo(
                    shape: fs, face: face,
                    kind: .cylinder(
                        radius: cyl.radius,
                        axisOrigin: axis.position,
                        axisDirection: simd_normalize(axis.direction)))
            default:
                infos[i] = nil // ignored — no pairing possible
            }
        }

        var paired: Set<Int> = []
        var midFaces: [Shape] = []
        let distTol = max(tolerance * 100, 1e-4)

        for i in 0..<faceShapes.count {
            if paired.contains(i) { continue }
            guard let infoA = infos[i] else { continue }
            for j in (i + 1)..<faceShapes.count {
                if paired.contains(j) { continue }
                guard let infoB = infos[j] else { continue }
                if let mid = try makeMidFaceIfPair(
                    infoA, infoB, thickness: t, tolerance: distTol)
                {
                    midFaces.append(mid)
                    paired.insert(i); paired.insert(j)
                    break
                }
            }
        }

        guard !midFaces.isEmpty else {
            throw UnfoldError.bendDetectionFailed(
                faceIndex: -1,
                reason: "no offset face pairs found at distance \(t)")
        }

        // Sew if multiple faces, else return the single face.
        if midFaces.count == 1 { return midFaces[0] }
        if let sewn = Shape.sew(shapes: midFaces, tolerance: distTol) {
            return sewn
        }
        // Fall back to compound if sewing fails.
        return Shape.compound(midFaces) ?? midFaces[0]
    }
}

// MARK: - CP4 internal helpers

private struct MidPairFaceInfo {
    let shape: Shape
    let face: Face
    let kind: Kind

    enum Kind {
        case plane(normal: SIMD3<Double>, centroid: SIMD3<Double>)
        case cylinder(radius: Double, axisOrigin: SIMD3<Double>, axisDirection: SIMD3<Double>)
    }
}

private func makeMidFaceIfPair(
    _ a: MidPairFaceInfo,
    _ b: MidPairFaceInfo,
    thickness t: Double,
    tolerance: Double
) throws -> Shape? {
    switch (a.kind, b.kind) {
    case let (.plane(nA, cA), .plane(nB, cB)):
        // Parallel or anti-parallel normals (covers both oriented closed
        // shells and unoriented compounds).
        let dot = abs(simd_dot(nA, nB))
        guard dot > 1.0 - tolerance else { return nil }
        // Distance between planes ≈ thickness, measured along nB.
        let d = simd_dot(cA - cB, nB)
        guard abs(abs(d) - t) < tolerance else { return nil }
        // Mid-plane is the geometric midpoint of the two centroids;
        // translate face A by half the centroid difference.
        let delta = (cB - cA) * 0.5
        guard let translated = a.shape.translated(by: delta) else { return nil }
        return translated

    case let (.cylinder(rA, oA, dA), .cylinder(rB, oB, dB)):
        // Same axis: directions parallel (or anti-parallel) and the line
        // through `oA, dA` passes within tolerance of `oB`.
        let dirDot = abs(simd_dot(dA, dB))
        guard dirDot > 1.0 - tolerance else { return nil }
        // Distance from oB to axis line of (oA, dA).
        let v = oB - oA
        let along = simd_dot(v, dA) * dA
        let perp = v - along
        guard simd_length(perp) < tolerance else { return nil }
        // Radii differ by thickness.
        guard abs(abs(rA - rB) - t) < tolerance else { return nil }
        // Build mid-cylinder at average radius. Use face A's UV bounds —
        // both should match for a true offset pair.
        guard let uvA = a.face.uvBounds else { return nil }
        let midRadius = (rA + rB) / 2
        guard let mid = Shape.faceFromCylinder(
            origin: oA,
            axis: dA,
            radius: midRadius,
            uRange: uvA.uMin...uvA.uMax,
            vRange: uvA.vMin...uvA.vMax
        ) else { return nil }
        return mid

    default:
        return nil
    }
}

// MARK: - Stock nesting / layout (CP6)

extension Unfold {

    public struct NestingParameters: Sendable {
        /// Maximum stock width along X. `nil` = unbounded.
        public var stockWidth: Double?
        /// Maximum stock height along Y. `nil` = unbounded.
        public var stockHeight: Double?
        /// Minimum gap between adjacent islands.
        public var padding: Double
        /// Layout objective.
        public var objective: Objective
        /// Whether to try 90° rotations of each island; the rotation that
        /// gives the best objective wins.
        public var allowRotation: Bool

        public enum Objective: Sendable {
            /// Minimize the bounding-box diagonal of the union of all
            /// island bboxes — the user's stated goal.
            case boundingBoxDiagonal
            /// Minimize the bounding-box area of the union.
            case boundingBoxArea
            /// Maximize stock utilization (= sum-of-island-area /
            /// bbox-area). Equivalent to minimising bbox-area when total
            /// island area is fixed; provided for clarity.
            case stockUtilization
        }

        public init(
            stockWidth: Double? = nil,
            stockHeight: Double? = nil,
            padding: Double = 1.0,
            objective: Objective = .boundingBoxDiagonal,
            allowRotation: Bool = true
        ) {
            self.stockWidth = stockWidth
            self.stockHeight = stockHeight
            self.padding = padding
            self.objective = objective
            self.allowRotation = allowRotation
        }
    }

    public enum NestingError: Error, Sendable {
        case stockTooSmall
    }

    /// Re-pack the islands of an unfold result using bottom-left-fill, then
    /// optionally try the four 90° rotations per island and keep whichever
    /// minimises `parameters.objective`.
    ///
    /// Operates only on `result.faces` and `result.folds` — the input shape
    /// is not consulted. The output is a new `Result` whose faces have been
    /// translated (and, if `allowRotation`, rotated about each island's own
    /// origin) to a tighter layout.
    ///
    /// Limitations: simple bottom-left-fill on axis-aligned bounding
    /// rectangles. Islands are treated as their bounding rectangle; tight
    /// nesting of irregular shapes (no-fit-polygon) is out of scope.
    public static func nest(
        _ result: Result,
        parameters: NestingParameters = .init()
    ) throws -> Result {
        let islands = computeIslands(result)
        guard !islands.isEmpty else { return result }

        var infos: [packBLFIsland] = []
        for (id, faceIndices) in islands.enumerated() {
            let bbox = islandBoundingBox(faceIndices: faceIndices, faces: result.faces)
            infos.append(packBLFIsland(
                id: id, faceIndices: faceIndices,
                originalBBox: bbox, rotation: 0, translation: .zero))
        }
        // Larger islands first so BLF places them anchoring the layout.
        infos.sort { $0.area > $1.area }

        // Try each global rotation, keep the one with best objective.
        let rotations = parameters.allowRotation ? [0, 1, 2, 3] : [0]
        var best: ([packBLFIsland], Double)?
        for rot in rotations {
            var trial = infos
            for i in trial.indices { trial[i].rotation = rot }
            packBLF(islands: &trial, parameters: parameters)
            let union = unionBoundingBox(trial)
            let totalArea = trial.reduce(0) { $0 + $1.area }
            let metric = computeObjective(
                union: union, totalIslandArea: totalArea, parameters: parameters)
            if let b = best {
                if metric < b.1 { best = (trial, metric) }
            } else {
                best = (trial, metric)
            }
        }
        guard let (chosen, _) = best else { return result }

        // Stock check.
        let union = unionBoundingBox(chosen)
        let unionW = union.max.x - union.min.x
        let unionH = union.max.y - union.min.y
        if let sw = parameters.stockWidth, unionW > sw + parameters.padding {
            throw NestingError.stockTooSmall
        }
        if let sh = parameters.stockHeight, unionH > sh + parameters.padding {
            throw NestingError.stockTooSmall
        }

        // Apply translations + rotations to each face.
        var newFaces: [Int: Shape] = [:]
        for info in chosen {
            for fi in info.faceIndices {
                guard let face = result.faces[fi] else { continue }
                let placed = applyIslandTransform(
                    face: face, info: info, parameters: parameters)
                newFaces[fi] = placed
            }
        }

        let allFaces = Array(newFaces.values)
        let compound: Shape
        if allFaces.count == 1 {
            compound = allFaces[0]
        } else if let c = Shape.compound(allFaces) {
            compound = c
        } else {
            return result
        }

        return Result(
            flat: compound,
            faces: newFaces,
            folds: result.folds,
            cuts: result.cuts,
            overlaps: false, // BLF doesn't produce overlaps
            rootFaceIndex: result.rootFaceIndex
        )
    }
}

// MARK: - CP6 internal helpers

/// Connected components of the fold graph. Returns one array of face indices
/// per component. Faces with no fold edges form singleton components.
private func computeIslands(_ result: Unfold.Result) -> [[Int]] {
    let allFaceIndices = Set(result.faces.keys)
    var adjacency: [Int: Set<Int>] = [:]
    for f in allFaceIndices { adjacency[f] = [] }
    for fold in result.folds {
        guard adjacency[fold.parentFaceIndex] != nil,
              adjacency[fold.childFaceIndex] != nil else { continue }
        adjacency[fold.parentFaceIndex]?.insert(fold.childFaceIndex)
        adjacency[fold.childFaceIndex]?.insert(fold.parentFaceIndex)
    }
    var visited: Set<Int> = []
    var components: [[Int]] = []
    for start in allFaceIndices.sorted() where !visited.contains(start) {
        var component: [Int] = []
        var stack: [Int] = [start]
        while let node = stack.popLast() {
            if !visited.insert(node).inserted { continue }
            component.append(node)
            for n in adjacency[node] ?? [] where !visited.contains(n) {
                stack.append(n)
            }
        }
        components.append(component)
    }
    return components
}

private func islandBoundingBox(
    faceIndices: [Int],
    faces: [Int: Shape]
) -> (min: SIMD2<Double>, max: SIMD2<Double>) {
    var minX = Double.infinity, minY = Double.infinity
    var maxX = -Double.infinity, maxY = -Double.infinity
    for fi in faceIndices {
        guard let face = faces[fi] else { continue }
        let b = face.bounds
        if b.min.x < minX { minX = b.min.x }
        if b.min.y < minY { minY = b.min.y }
        if b.max.x > maxX { maxX = b.max.x }
        if b.max.y > maxY { maxY = b.max.y }
    }
    if minX == .infinity {
        return (.zero, .zero)
    }
    return (SIMD2(minX, minY), SIMD2(maxX, maxY))
}

/// Bottom-left-fill packing on axis-aligned rectangles. Updates each
/// island's `translation` so its placed bounding box sits at
/// `translation … translation + (width, height)`.
private func packBLF(
    islands: inout [packBLFIsland],
    parameters: Unfold.NestingParameters
) {
    // Place greedily: sort already done by caller.
    var placed: [(min: SIMD2<Double>, max: SIMD2<Double>)] = []
    for i in islands.indices {
        let w = islands[i].width
        let h = islands[i].height
        // Generate candidate positions: (0, 0), and for each placed box,
        // (placed.max.x + padding, placed.min.y) and (placed.min.x,
        // placed.max.y + padding).
        var candidates: [SIMD2<Double>] = [SIMD2(0, 0)]
        for p in placed {
            candidates.append(SIMD2(p.max.x + parameters.padding, 0))
            candidates.append(SIMD2(0, p.max.y + parameters.padding))
            candidates.append(SIMD2(p.max.x + parameters.padding, p.min.y))
            candidates.append(SIMD2(p.min.x, p.max.y + parameters.padding))
        }
        // Sort: bottom-left preference (smaller y first, then smaller x).
        candidates.sort { (a, b) in
            if a.y != b.y { return a.y < b.y }
            return a.x < b.x
        }
        var chosen: SIMD2<Double>?
        for c in candidates {
            let trial = (min: c, max: c + SIMD2(w, h))
            if !placed.contains(where: { rectsOverlap($0, trial, padding: parameters.padding) }) {
                if let sw = parameters.stockWidth, trial.max.x > sw { continue }
                if let sh = parameters.stockHeight, trial.max.y > sh { continue }
                chosen = c
                break
            }
        }
        let pos = chosen ?? candidates[0]
        islands[i].translation = pos
        placed.append((min: pos, max: pos + SIMD2(w, h)))
    }
}

private struct packBLFIsland {
    let id: Int
    let faceIndices: [Int]
    /// The island's bbox in its source layout (before rotation/translation).
    let originalBBox: (min: SIMD2<Double>, max: SIMD2<Double>)
    var rotation: Int    // 0=0°, 1=90°, 2=180°, 3=270°
    var translation: SIMD2<Double>

    private var origWidth: Double { originalBBox.max.x - originalBBox.min.x }
    private var origHeight: Double { originalBBox.max.y - originalBBox.min.y }
    var width: Double {
        rotation == 1 || rotation == 3 ? origHeight : origWidth
    }
    var height: Double {
        rotation == 1 || rotation == 3 ? origWidth : origHeight
    }
    var area: Double { width * height }
}

private func rectsOverlap(
    _ a: (min: SIMD2<Double>, max: SIMD2<Double>),
    _ b: (min: SIMD2<Double>, max: SIMD2<Double>),
    padding: Double
) -> Bool {
    let x = a.min.x < b.max.x + padding && b.min.x < a.max.x + padding
    let y = a.min.y < b.max.y + padding && b.min.y < a.max.y + padding
    return x && y
}

private func unionBoundingBox(_ islands: [packBLFIsland]) -> (min: SIMD2<Double>, max: SIMD2<Double>) {
    var minX = Double.infinity, minY = Double.infinity
    var maxX = -Double.infinity, maxY = -Double.infinity
    for i in islands {
        let pos = i.translation
        let w = i.width, h = i.height
        if pos.x < minX { minX = pos.x }
        if pos.y < minY { minY = pos.y }
        if pos.x + w > maxX { maxX = pos.x + w }
        if pos.y + h > maxY { maxY = pos.y + h }
    }
    if minX == .infinity { return (.zero, .zero) }
    return (SIMD2(minX, minY), SIMD2(maxX, maxY))
}

private func computeObjective(
    union: (min: SIMD2<Double>, max: SIMD2<Double>),
    totalIslandArea: Double,
    parameters: Unfold.NestingParameters
) -> Double {
    let w = union.max.x - union.min.x
    let h = union.max.y - union.min.y
    switch parameters.objective {
    case .boundingBoxDiagonal:
        return sqrt(w * w + h * h)
    case .boundingBoxArea:
        return w * h
    case .stockUtilization:
        let bboxArea = w * h
        guard bboxArea > 0 else { return Double.infinity }
        return -totalIslandArea / bboxArea // negate so smaller = better
    }
}

private func applyIslandTransform(
    face: Shape,
    info: packBLFIsland,
    parameters: Unfold.NestingParameters
) -> Shape {
    var working = face
    if info.rotation != 0 {
        // Rotate about the original-bbox min so the island stays anchored.
        let pivot = info.originalBBox.min
        if let recentred = working.translated(by: SIMD3(-pivot.x, -pivot.y, 0)),
           let rotated = recentred.rotated(
               axis: SIMD3(0, 0, 1),
               angle: Double(info.rotation) * .pi / 2
           ) {
            working = rotated
        }
    }
    // Place the island so its post-rotation bbox.min sits at translation.
    let postBounds = working.bounds
    let dx = info.translation.x - postBounds.min.x
    let dy = info.translation.y - postBounds.min.y
    if let translated = working.translated(by: SIMD3(dx, dy, 0)) {
        return translated
    }
    return working
}

// MARK: - Sheet-metal composite (CP3)

extension Unfold {
    /// Tier 3 — unfold a thin-shell sheet-metal part with cylindrical bends.
    ///
    /// Detects each cylindrical face whose two straight-generator edges are
    /// shared with planar neighbours as a *bend*; replaces it with a planar
    /// strip of width = bend allowance `θ · (R + K · t)` between the two
    /// panels. The result lays the panels coplanar in 2D, separated by
    /// developed bend strips on layer "BEND".
    ///
    /// **Input contract.** A 2-manifold shell (typically a closed shell or
    /// connected open shell) with planar panel faces and cylindrical
    /// fillets at every bend. Tangent continuity between panels and bend
    /// fillets is required — the cylindrical face's two generator edges
    /// must be shared with the adjacent panels. Closed thick solids belong
    /// in CP4 (`solid(_:)`, mid-surface extraction).
    ///
    /// **Limitations (CP3):**
    /// - Compound bends (a cylinder shared with another cylinder, or three
    ///   panels meeting at one bend) are not yet handled — they're cut.
    /// - Variable-angle K-factor is not supported. A single `kFactor` is
    ///   applied to every bend.
    /// - Bend axes that are not perpendicular to a panel pair's shared
    ///   plane are not auto-detected — they're treated as cuts.
    public static func sheetMetal(
        _ shape: Shape,
        parameters: Parameters,
        sheet: SheetMetalParameters
    ) throws -> Result {
        let faceShapes = shape.subShapes(ofType: .face)
        guard !faceShapes.isEmpty else { throw UnfoldError.noFaces }

        // Classify faces: panel (planar) vs bend (cylindrical) vs other.
        var faces: [SheetFaceKind] = []
        for (i, fs) in faceShapes.enumerated() {
            guard let face = Face(fs) else {
                throw UnfoldError.bridgeFailed(stage: "Face from shape #\(i)")
            }
            switch face.surfaceType {
            case .plane:
                guard let n = face.normal else {
                    throw UnfoldError.missingNormal(faceIndex: i)
                }
                let origin = face.outerWire?.edges().first?.endpoints.start
                    ?? fs.center
                faces.append(.panel(PanelInfo(
                    index: i, shape: fs, normal: simd_normalize(n),
                    origin: origin, area: face.area())))
            case .cylinder:
                faces.append(.cylinder(fs, face))
            default:
                throw UnfoldError.nonDevelopableFace(faceIndex: i)
            }
        }

        // Detect bends: each cylindrical face contributes a Bend if its two
        // straight-generator shared edges connect to two planar panels.
        var bends: [Bend] = []
        var bendByFaceIndex: [Int: Int] = [:] // cyl face index → bends array idx
        for (i, kind) in faces.enumerated() {
            guard case .cylinder(let cylShape, let cylFace) = kind else { continue }
            let bend = try detectBend(
                cylFaceIndex: i,
                cylFaceShape: cylShape,
                cylFace: cylFace,
                allFaces: faces,
                shape: shape
            )
            if let bend {
                bendByFaceIndex[i] = bends.count
                bends.append(bend)
            }
        }

        // Build panel-to-panel adjacency through bends.
        // adjacency[panelIdx] = [(otherPanel, bendIdx)]
        var adjacency: [Int: [(other: Int, bend: Int)]] = [:]
        for (bi, bend) in bends.enumerated() {
            guard bend.panelFaceIndices.count == 2 else { continue }
            let a = bend.panelFaceIndices[0]
            let b = bend.panelFaceIndices[1]
            adjacency[a, default: []].append((b, bi))
            adjacency[b, default: []].append((a, bi))
        }

        // Pick root panel (largest area).
        let panelIndices = faces.indices.compactMap { i -> Int? in
            if case .panel = faces[i] { return i } else { return nil }
        }
        guard !panelIndices.isEmpty else { throw UnfoldError.noPanels }
        let rootIdx = parameters.rootFaceIndex.flatMap { panelIndices.contains($0) ? $0 : nil }
            ?? panelIndices.max(by: { lhs, rhs in
                panelArea(faces[lhs]) < panelArea(faces[rhs])
            })!

        // BFS panels, computing each panel's 2D placement.
        // Each panel gets a 2D rigid placement: origin in XY + rotation +
        // optional mirror flag (we encode the local frame as origin +
        // u/v axes). For simplicity store as a 4×4 transform from world
        // 3D into XY 2D; for panels the mapping is identical to CP1's
        // laydown.
        var transform: [Int: simd_double4x4] = [:]
        // Root: lay flat onto XY centred on its first vertex.
        let rootPanel = panelInfo(faces[rootIdx])!
        transform[rootIdx] = laydownTransform(face: FaceInfo(
            shape: rootPanel.shape, normal: rootPanel.normal,
            origin: rootPanel.origin, area: rootPanel.area))

        var foldEdges: [FoldEdge] = []
        var bendStrips: [BendStrip] = [] // for output
        var visited: Set<Int> = [rootIdx]
        var queue: [Int] = [rootIdx]
        var head = 0

        while head < queue.count {
            let parent = queue[head]; head += 1
            let parentT = transform[parent]!
            for (other, bendIdx) in adjacency[parent] ?? [] {
                if visited.contains(other) { continue }
                let bend = bends[bendIdx]
                let parentPanel = panelInfo(faces[parent])!
                let otherPanel = panelInfo(faces[other])!

                // The shared generator between parent and bend is a line
                // edge in 3D. Find it.
                guard let parentSharedEdge = sharedStraightEdge(
                    a: parentPanel.shape, b: faceShapes[bend.cylindricalFaceIndex],
                    in: shape
                ) else {
                    throw UnfoldError.bendDetectionFailed(
                        faceIndex: bend.cylindricalFaceIndex,
                        reason: "no shared straight edge with parent panel")
                }
                guard let otherSharedEdge = sharedStraightEdge(
                    a: otherPanel.shape, b: faceShapes[bend.cylindricalFaceIndex],
                    in: shape
                ) else {
                    throw UnfoldError.bendDetectionFailed(
                        faceIndex: bend.cylindricalFaceIndex,
                        reason: "no shared straight edge with other panel")
                }

                let pStart = parentSharedEdge.start, pEnd = parentSharedEdge.end
                let pStartLaid = transformPoint(parentT, pStart)
                let pEndLaid = transformPoint(parentT, pEnd)

                // Outward direction at parent's shared edge in laid-out 2D:
                // perpendicular to the edge, in parent's plane (z=0 after
                // laydown), pointing AWAY from parent's interior.
                let parentNormalLaid = transformNormal(parentT, parentPanel.normal)
                let edgeDirLaid = simd_normalize(pEndLaid - pStartLaid)
                // Perpendicular within plane = cross(normal, edgeDir).
                // After laydown, normal ≈ +Z, so perp = (+Z × edgeDir) which
                // lies in XY. Choose sign so it points away from parent's
                // centroid.
                var outwardLaid = simd_cross(parentNormalLaid, edgeDirLaid)
                outwardLaid.z = 0
                outwardLaid = simd_normalize(outwardLaid)
                let parentCentroidLaid = transformPoint(parentT, parentPanel.origin)
                let edgeMidLaid = (pStartLaid + pEndLaid) * 0.5
                if simd_dot(outwardLaid, parentCentroidLaid - edgeMidLaid) > 0 {
                    outwardLaid = -outwardLaid
                }

                // Bend allowance strip
                let BA = sheet.bendAllowance(radius: bend.radius, angle: bend.angle)
                // The far edge of the bend strip is parallel to the parent
                // edge, offset by BA in outwardLaid direction.
                let farStart = pStartLaid + Double(BA) * outwardLaid
                let farEnd = pEndLaid + Double(BA) * outwardLaid

                // Record the strip as a 2D quad (parent edge → far edge).
                bendStrips.append(BendStrip(
                    bendIndex: bendIdx,
                    nearStart: SIMD2(pStartLaid.x, pStartLaid.y),
                    nearEnd: SIMD2(pEndLaid.x, pEndLaid.y),
                    farStart: SIMD2(farStart.x, farStart.y),
                    farEnd: SIMD2(farEnd.x, farEnd.y)
                ))

                // Now compute child's transform: it must lay so that its
                // "shared edge with bend" (otherSharedEdge in 3D) maps to
                // the far edge of the strip in 2D.
                // We treat the far edge as the "virtual shared edge" for
                // the child panel. Compute child's 3D rigid transform that:
                //   1. Rotates child's plane onto parent's plane (so they
                //      become coplanar in 2D after laydown).
                //   2. Translates so child's shared-edge-with-bend endpoints
                //      land at (farStart, farEnd).
                //
                // Step A: rotation around child's shared edge that brings
                // child's normal coplanar with parent's normal — same idea
                // as CP1, but the rotation pivot is otherSharedEdge (in 3D)
                // and the angle is the dihedral between parent and child
                // (which equals bend.angle since the cylinder spans that
                // dihedral; sign chosen so child unfolds outward).
                let childT_step1 = unfoldChildTransform(
                    parentT: parentT,
                    parentPanel: parentPanel,
                    otherPanel: otherPanel,
                    otherSharedEdgeStart: otherSharedEdge.start,
                    otherSharedEdgeEnd: otherSharedEdge.end
                )

                // Step B: child is now coplanar with parent. Its laid-out
                // shared edge sits where the cylinder's other generator
                // lands. Translate to the bend-strip's far edge.
                let childOtherStartLaid = transformPoint(childT_step1, otherSharedEdge.start)
                let childOtherEndLaid = transformPoint(childT_step1, otherSharedEdge.end)
                let childOtherMid = (childOtherStartLaid + childOtherEndLaid) * 0.5
                let farMid = (farStart + farEnd) * 0.5
                let translateChild = translation(farMid - childOtherMid)
                let childT = translateChild * childT_step1

                transform[other] = childT
                visited.insert(other)
                queue.append(other)

                // Record a fold across the cylinder (synthetic — the bend's
                // edges are the parent + other shared generators).
                if let edgeId = parentSharedEdge.identifier {
                    foldEdges.append(FoldEdge(
                        edge: edgeId,
                        parentFaceIndex: parent,
                        childFaceIndex: other,
                        dihedralAngle: bend.angle
                    ))
                }
            }
        }

        // Apply transforms and assemble result.
        var laidShapes: [Int: Shape] = [:]
        var laidArray: [Shape] = []
        for (i, kind) in faces.enumerated() {
            guard case .panel(let info) = kind, let t = transform[i] else { continue }
            let mat = matrix12(from: t)
            guard let flat = info.shape.transformed(matrix: mat) else {
                throw UnfoldError.bridgeFailed(stage: "transform panel #\(i)")
            }
            laidShapes[i] = flat
            laidArray.append(flat)
        }
        // Add bend strips as 2D faces (rectangles).
        for (idx, strip) in bendStrips.enumerated() {
            let pts: [SIMD3<Double>] = [
                SIMD3(strip.nearStart.x, strip.nearStart.y, 0),
                SIMD3(strip.nearEnd.x, strip.nearEnd.y, 0),
                SIMD3(strip.farEnd.x, strip.farEnd.y, 0),
                SIMD3(strip.farStart.x, strip.farStart.y, 0),
            ]
            if let wire = Wire.polygon3D(pts, closed: true),
               let face = Shape.face(from: wire, planar: true) {
                // Encode bend strip with a synthetic face index past the
                // largest real index, so callers can recognise it.
                laidShapes[10_000 + idx] = face
                laidArray.append(face)
            }
        }

        let compound: Shape
        if laidArray.count == 1 {
            compound = laidArray[0]
        } else if let c = Shape.compound(laidArray) {
            compound = c
        } else {
            throw UnfoldError.bridgeFailed(stage: "compound sheet-metal")
        }

        let overlaps = anyBoundingBoxOverlap(in: laidArray, tolerance: parameters.tolerance)

        return Result(
            flat: compound,
            faces: laidShapes,
            folds: foldEdges,
            cuts: [],
            overlaps: overlaps,
            rootFaceIndex: rootIdx
        )
    }
}

// MARK: - CP3 internal types & helpers

private enum SheetFaceKind {
    case panel(PanelInfo)
    case cylinder(Shape, Face) // shape + face wrapper
}

private struct PanelInfo {
    let index: Int
    let shape: Shape
    let normal: SIMD3<Double>
    let origin: SIMD3<Double>
    let area: Double
}

private func panelInfo(_ kind: SheetFaceKind) -> PanelInfo? {
    if case .panel(let info) = kind { return info }
    return nil
}

private func panelArea(_ kind: SheetFaceKind) -> Double {
    if case .panel(let info) = kind { return info.area }
    return 0
}

private struct BendStrip {
    let bendIndex: Int
    let nearStart: SIMD2<Double>
    let nearEnd: SIMD2<Double>
    let farStart: SIMD2<Double>
    let farEnd: SIMD2<Double>
}

private struct SharedEdgeInfo {
    let start: SIMD3<Double>
    let end: SIMD3<Double>
    let identifier: Unfold.EdgeIdentifier?
}

private func detectBend(
    cylFaceIndex: Int,
    cylFaceShape: Shape,
    cylFace: Face,
    allFaces: [SheetFaceKind],
    shape: Shape
) throws -> Unfold.Bend? {
    guard let surface = cylFaceShape.faceSurfaceGeom() else { return nil }
    let cyl = surface.cylinderProperties
    guard let bounds = cylFace.uvBounds else { return nil }

    // Walk the cylinder face's edges; find shared planar neighbours.
    let edgeShapes = shape.subShapes(ofType: .edge)
    var panelNeighbours: Set<Int> = []
    for es in edgeShapes {
        let adj = shape.adjacentFaces(forEdge: es).map { $0 - 1 }
        guard adj.contains(cylFaceIndex) else { continue }
        for other in adj where other != cylFaceIndex {
            if case .panel = allFaces[other] {
                guard let edge = Edge(es), edge.isLine else { continue }
                panelNeighbours.insert(other)
            }
        }
    }
    guard panelNeighbours.count == 2 else { return nil }

    return Unfold.Bend(
        cylindricalFaceIndex: cylFaceIndex,
        radius: cyl.radius,
        axisOrigin: cyl.axis.position,
        axisDirection: simd_normalize(cyl.axis.direction),
        length: bounds.vMax - bounds.vMin,
        angle: bounds.uMax - bounds.uMin,
        panelFaceIndices: Array(panelNeighbours).sorted()
    )
}

private func sharedStraightEdge(a: Shape, b: Shape, in parent: Shape) -> SharedEdgeInfo? {
    let edgeShapes = parent.subShapes(ofType: .edge)
    let aFaceIndex = faceIndex(of: a, in: parent)
    let bFaceIndex = faceIndex(of: b, in: parent)
    guard aFaceIndex >= 0, bFaceIndex >= 0 else { return nil }
    for (ei, es) in edgeShapes.enumerated() {
        let adj = parent.adjacentFaces(forEdge: es).map { $0 - 1 }
        guard adj.contains(aFaceIndex), adj.contains(bFaceIndex) else { continue }
        guard let edge = Edge(es), edge.isLine else { continue }
        let ep = edge.endpoints
        return SharedEdgeInfo(
            start: ep.start,
            end: ep.end,
            identifier: Unfold.EdgeIdentifier(
                shapeHash: parent.hashCode, edgeIndex: ei)
        )
    }
    return nil
}

private func faceIndex(of face: Shape, in parent: Shape) -> Int {
    let faceShapes = parent.subShapes(ofType: .face)
    for (i, fs) in faceShapes.enumerated() {
        if fs.isSame(as: face) { return i }
    }
    return -1
}

/// Compute child panel's 3D-to-XY transform so that it becomes coplanar
/// with the already-placed parent panel, rotating around `otherSharedEdge`
/// (the child's straight generator with the bend cylinder).
///
/// Strategy: the cylinder spans the dihedral between parent and child by
/// definition. Once we lay parent flat, child's plane needs to rotate by
/// `±bend.angle` around `otherSharedEdge` to become coplanar. The sign and
/// the residual translation come out by demanding parent's outward
/// direction matches the bend's outward direction.
private func unfoldChildTransform(
    parentT: simd_double4x4,
    parentPanel: PanelInfo,
    otherPanel: PanelInfo,
    otherSharedEdgeStart: SIMD3<Double>,
    otherSharedEdgeEnd: SIMD3<Double>
) -> simd_double4x4 {
    // Apply parent's transform to child's normal direction first to bring
    // it into the laid-out frame; then rotate around the shared edge in 3D
    // to make child coplanar with parent.
    let unfoldRot = rotationMatrix(
        axisStart: otherSharedEdgeStart,
        axisEnd: otherSharedEdgeEnd,
        fromNormal: otherPanel.normal,
        toNormal: parentPanel.normal
    )
    return parentT * unfoldRot.matrix
}

// MARK: - Multi-face developable shells (CP2)

extension Unfold {
    /// Tier 2 — unfold a shell that may contain planar, cylindrical, and
    /// conical faces.
    ///
    /// Behaviour:
    /// - **All faces planar** — equivalent to `polyhedral(_:)`. Returns a
    ///   single connected net.
    /// - **Mixed planar + developable** — every face is developed
    ///   independently using `develop(face:)`, then laid out as disjoint
    ///   islands along the X axis with `parameters.tolerance` padding.
    ///   Shared edges between developable and planar faces are not folded
    ///   in this checkpoint; that's CP3's job (sheet-metal composite, where
    ///   the bend allowance and K-factor turn cylindrical fillets into
    ///   correctly-attached planar strips).
    /// - **Any non-developable face** (sphere, torus, generic BSpline, …) —
    ///   throws `nonDevelopableFace`.
    ///
    /// For a closed cylinder (1 cylindrical side + 2 planar caps) this
    /// returns 3 islands: a `2πR × h` rectangle and two disks. For a closed
    /// cone, 2 islands. For a hex prism, 8 connected planar faces (via the
    /// polyhedral path).
    public static func developable(
        _ shape: Shape,
        parameters: Parameters = .init()
    ) throws -> Result {
        let faceShapes = shape.subShapes(ofType: .face)
        guard !faceShapes.isEmpty else { throw UnfoldError.noFaces }

        var allPlanar = true
        for (i, fs) in faceShapes.enumerated() {
            guard let f = Face(fs) else {
                throw UnfoldError.bridgeFailed(stage: "Face from shape #\(i)")
            }
            switch f.surfaceType {
            case .plane:
                break
            case .cylinder, .cone:
                allPlanar = false
            default:
                throw UnfoldError.nonDevelopableFace(faceIndex: i)
            }
        }

        if allPlanar {
            return try polyhedral(shape, parameters: parameters)
        }

        // Mixed shell: develop each face, lay out as side-by-side islands.
        let padding: Double = max(parameters.tolerance, 1.0)
        var laid: [Int: Shape] = [:]
        var laidArray: [Shape] = []
        var cursorX = 0.0
        for (i, fs) in faceShapes.enumerated() {
            let dev = try develop(face: fs, samples: 64)
            let b = dev.bounds
            let dx = cursorX - b.min.x
            let dy = -b.min.y
            guard let placed = dev.translated(by: SIMD3(dx, dy, 0)) else {
                throw UnfoldError.bridgeFailed(stage: "place island #\(i)")
            }
            laid[i] = placed
            laidArray.append(placed)
            cursorX = placed.bounds.max.x + padding
        }

        let compound: Shape
        if laidArray.count == 1 {
            compound = laidArray[0]
        } else if let c = Shape.compound(laidArray) {
            compound = c
        } else {
            throw UnfoldError.bridgeFailed(stage: "compound islands")
        }

        return Result(
            flat: compound,
            faces: laid,
            folds: [],
            cuts: [],
            overlaps: false,
            rootFaceIndex: 0
        )
    }
}

// MARK: - Single-face development (CP2)

extension Unfold {
    /// Develop a single face into a 2D face on the XY plane.
    ///
    /// Supported surface types:
    /// - **Plane** — laid flat using the same rigid transform as `polyhedral`.
    /// - **Cylinder** — boundary is sampled along its `(u, v)` parametric
    ///   curves and mapped to `(R · u, v)`.
    /// - **Cone** — boundary points map to polar coordinates around the apex:
    ///   slant length `s = |P − apex|` becomes the 2D radius and the angular
    ///   position `u` is multiplied by `sin(α)` to get the developed angle.
    ///   Frusta and full cones use the same code path.
    ///
    /// Other developable types (`SurfaceOfExtrusion` along a line,
    /// `SurfaceOfRevolution` of a line, ruled tangent-plane developables) are
    /// not yet supported; they throw `nonDevelopableFace`.
    ///
    /// `samples` controls how many points are sampled along each curved
    /// boundary edge. Straight edges always use 2 points.
    public static func develop(face faceShape: Shape, samples: Int = 64) throws -> Shape {
        guard let face = Face(faceShape) else {
            throw UnfoldError.bridgeFailed(stage: "Face from shape")
        }
        switch face.surfaceType {
        case .plane:
            return try developPlane(faceShape: faceShape, face: face)
        case .cylinder:
            return try developCylinder(faceShape: faceShape, face: face, samples: samples)
        case .cone:
            return try developCone(faceShape: faceShape, face: face, samples: samples)
        default:
            throw UnfoldError.nonDevelopableFace(faceIndex: face.index)
        }
    }
}

// MARK: - Per-surface development helpers (CP2)

private func developPlane(faceShape: Shape, face: Face) throws -> Shape {
    guard let n = face.normal else {
        throw Unfold.UnfoldError.missingNormal(faceIndex: face.index)
    }
    let origin = face.outerWire?.edges().first?.endpoints.start ?? faceShape.center
    let info = FaceInfo(shape: faceShape, normal: simd_normalize(n), origin: origin, area: face.area())
    let m = matrix12(from: laydownTransform(face: info))
    guard let flat = faceShape.transformed(matrix: m) else {
        throw Unfold.UnfoldError.bridgeFailed(stage: "transform planar face")
    }
    return flat
}

private func developCylinder(faceShape: Shape, face: Face, samples: Int) throws -> Shape {
    guard let surface = faceShape.faceSurfaceGeom() else {
        throw Unfold.UnfoldError.bridgeFailed(stage: "cylinder surface")
    }
    let R = surface.cylinderProperties.radius
    let pts = try sampledUVRectBoundary(face: face, samples: samples) { uv in
        SIMD2(R * uv.x, uv.y)
    }
    return try buildPlanarFace(from: pts)
}

private func developCone(faceShape: Shape, face: Face, samples: Int) throws -> Shape {
    guard let surface = faceShape.faceSurfaceGeom() else {
        throw Unfold.UnfoldError.bridgeFailed(stage: "cone surface")
    }
    let cone = surface.coneProperties
    let apex = cone.apex
    let sinHalf = sin(cone.semiAngle)
    let pts = try sampledUVRectBoundary(face: face, samples: samples) { uv in
        guard let p3 = face.point(atU: uv.x, v: uv.y) else { return nil }
        let s = simd_length(p3 - apex)
        let theta = uv.x * sinHalf
        return SIMD2(s * cos(theta), s * sin(theta))
    }
    return try buildPlanarFace(from: pts)
}

/// Sample the boundary of the face's `(u, v)` parameter-space rectangle and
/// map each sample through `map`. Robust against seam edges (where the same
/// `TopoDS_Edge` would appear twice in the wire walk with different
/// orientations) because we never look at the topology — we walk the
/// parameter rectangle `[uMin, uMax] × [vMin, vMax]` directly.
///
/// Side order: bottom (vMin, u increasing) → right (uMax, v increasing) →
/// top (vMax, u decreasing) → left (uMin, v decreasing). Counter-clockwise
/// in `(u, v)` space; the mapping function determines the resulting 2D
/// winding.
///
/// Caveat: works for primitives whose boundary is exactly the parameter
/// rectangle (full cylinders, cones, frusta, partial sections). Faces with
/// trimmed inner wires (holes) or non-rectangular parameter-domain
/// boundaries need pcurve-based walking — out of scope for CP2.
private func sampledUVRectBoundary(
    face: Face,
    samples: Int,
    map: (SIMD2<Double>) -> SIMD2<Double>?
) throws -> [SIMD2<Double>] {
    guard let bounds = face.uvBounds else {
        throw Unfold.UnfoldError.bridgeFailed(stage: "face uvBounds")
    }
    let uMin = bounds.uMin, uMax = bounds.uMax
    let vMin = bounds.vMin, vMax = bounds.vMax
    let n = max(2, samples)

    var points: [SIMD2<Double>] = []
    func append(_ uv: SIMD2<Double>) {
        guard let p = map(uv) else { return }
        if let last = points.last, simd_length(p - last) < 1e-9 { return }
        points.append(p)
    }
    // Bottom: u from uMin to uMax at v = vMin.
    for i in 0..<n {
        let t = Double(i) / Double(n - 1)
        append(SIMD2(uMin + (uMax - uMin) * t, vMin))
    }
    // Right: v from vMin to vMax at u = uMax.
    for i in 1..<n {
        let t = Double(i) / Double(n - 1)
        append(SIMD2(uMax, vMin + (vMax - vMin) * t))
    }
    // Top: u from uMax to uMin at v = vMax.
    for i in 1..<n {
        let t = Double(i) / Double(n - 1)
        append(SIMD2(uMax - (uMax - uMin) * t, vMax))
    }
    // Left: v from vMax to vMin at u = uMin.
    for i in 1..<n {
        let t = Double(i) / Double(n - 1)
        append(SIMD2(uMin, vMax - (vMax - vMin) * t))
    }
    if let first = points.first, let last = points.last,
       points.count > 1, simd_length(last - first) < 1e-9 {
        points.removeLast()
    }
    return points
}

private func buildPlanarFace(from points2D: [SIMD2<Double>]) throws -> Shape {
    guard points2D.count >= 3 else {
        throw Unfold.UnfoldError.bridgeFailed(stage: "develop boundary too short")
    }
    let pts3D = points2D.map { SIMD3<Double>($0.x, $0.y, 0) }
    guard let wire = Wire.polygon3D(pts3D, closed: true) else {
        throw Unfold.UnfoldError.bridgeFailed(stage: "develop wire")
    }
    guard let face = Shape.face(from: wire, planar: true) else {
        throw Unfold.UnfoldError.bridgeFailed(stage: "develop face")
    }
    return face
}

// MARK: - CP5 overlap-resolution helpers

/// Pick an edge to cut to **isolate** one of the overlapping faces from its
/// tree parent — that face becomes a new island root next iteration. This
/// is more aggressive than `pickEdgeToCutForOverlap` and converges faster
/// on highly-connected dual graphs (e.g. the icosahedron) where cutting
/// arbitrary middle edges of A→B paths just reroutes the same overlap.
private func pickEdgeToIsolateOverlap(
    _ result: Unfold.Result
) -> Unfold.EdgeIdentifier? {
    let eps: Double = 1e-4
    let entries = result.faces.map { (index: $0.key, shape: $0.value) }
    var parentEdge: [Int: Unfold.EdgeIdentifier] = [:]
    for fold in result.folds {
        parentEdge[fold.childFaceIndex] = fold.edge
    }
    for i in 0..<entries.count {
        for j in (i + 1)..<entries.count {
            let a = entries[i].shape.bounds
            let b = entries[j].shape.bounds
            let xOverlap = a.min.x <= b.max.x - eps && b.min.x <= a.max.x - eps
            let yOverlap = a.min.y <= b.max.y - eps && b.min.y <= a.max.y - eps
            if xOverlap && yOverlap {
                // Prefer to isolate the face that has a parent edge (i.e.,
                // is not itself a root). Try j first, fall back to i.
                if let edge = parentEdge[entries[j].index] { return edge }
                if let edge = parentEdge[entries[i].index] { return edge }
            }
        }
    }
    return nil
}

/// Pick an edge to cut to resolve a face-pair overlap. Returns the middle
/// edge of the spanning-tree path between the first overlapping pair.
private func pickEdgeToCutForOverlap(
    _ result: Unfold.Result
) -> Unfold.EdgeIdentifier? {
    let eps: Double = 1e-4 // match anyBoundingBoxOverlap's threshold
    let entries = result.faces.map { (index: $0.key, shape: $0.value) }
    for i in 0..<entries.count {
        for j in (i + 1)..<entries.count {
            let a = entries[i].shape.bounds
            let b = entries[j].shape.bounds
            let xOverlap = a.min.x <= b.max.x - eps && b.min.x <= a.max.x - eps
            let yOverlap = a.min.y <= b.max.y - eps && b.min.y <= a.max.y - eps
            if xOverlap && yOverlap {
                let path = treePath(
                    from: entries[i].index,
                    to: entries[j].index,
                    folds: result.folds
                )
                guard !path.isEmpty else { continue }
                return path[path.count / 2]
            }
        }
    }
    return nil
}

/// Walk the BFS spanning tree (encoded by `folds`) to find the edge path
/// from face `a` to face `b`. Returns the edges on that path in order.
private func treePath(
    from a: Int,
    to b: Int,
    folds: [Unfold.FoldEdge]
) -> [Unfold.EdgeIdentifier] {
    var parent: [Int: (parent: Int, edge: Unfold.EdgeIdentifier)] = [:]
    for fold in folds {
        parent[fold.childFaceIndex] = (fold.parentFaceIndex, fold.edge)
    }
    // Ancestors of a, including a itself.
    var ancestorsA: Set<Int> = [a]
    var node = a
    while let p = parent[node]?.parent {
        ancestorsA.insert(p); node = p
    }
    // Walk up from b until hitting an ancestor of a — that's the LCA.
    var lca = b
    while !ancestorsA.contains(lca) {
        guard let p = parent[lca]?.parent else { return [] }
        lca = p
    }
    // Path a → LCA.
    var aPath: [Unfold.EdgeIdentifier] = []
    node = a
    while node != lca, let pe = parent[node] {
        aPath.append(pe.edge); node = pe.parent
    }
    // Path b → LCA.
    var bPath: [Unfold.EdgeIdentifier] = []
    node = b
    while node != lca, let pe = parent[node] {
        bPath.append(pe.edge); node = pe.parent
    }
    return aPath + bPath
}

// MARK: - Internal types

private struct FaceInfo {
    let shape: Shape
    let normal: SIMD3<Double>
    let origin: SIMD3<Double>
    let area: Double
}

private struct EdgeRecord {
    let index: Int
    let shape: Shape
    let endpoints: (start: SIMD3<Double>, end: SIMD3<Double>)
    let adjacentFaces: [Int]
}

// MARK: - Geometry helpers

/// A point on the face's plane. Uses the start vertex of the first boundary
/// edge so the chosen origin is exactly on the face (not just nominally).
private func anyPointOnFace(_ face: Face, fallbackShape: Shape) -> SIMD3<Double>? {
    if let outer = face.outerWire,
       let firstEdge = outer.edges().first {
        return firstEdge.endpoints.start
    }
    return nil
}

/// 4×4 transform that takes a face's 3D plane onto z = 0 with normal +Z and
/// the chosen origin at world (0, 0, 0).
private func laydownTransform(face: FaceInfo) -> simd_double4x4 {
    let zAxis = SIMD3<Double>(0, 0, 1)
    let n = face.normal
    let p = face.origin
    let dotNZ = simd_dot(n, zAxis)

    let rot: simd_double4x4
    if dotNZ > 1.0 - 1e-12 {
        rot = matrix_identity_double4x4
    } else if dotNZ < -1.0 + 1e-12 {
        rot = rotationAroundOrigin(axis: SIMD3(1, 0, 0), angle: .pi)
    } else {
        let axis = simd_normalize(simd_cross(n, zAxis))
        let angle = acos(min(max(dotNZ, -1.0), 1.0))
        rot = rotationAroundOrigin(axis: axis, angle: angle)
    }

    let pAfter = transformPoint(rot, p)
    let translate = translation(SIMD3(-pAfter.x, -pAfter.y, -pAfter.z))
    return translate * rot
}

/// Rotation around the line `(axisStart, axisEnd)` that brings `fromNormal`
/// into alignment with `toNormal`. Returns the matrix and the signed angle.
private func rotationMatrix(
    axisStart: SIMD3<Double>,
    axisEnd: SIMD3<Double>,
    fromNormal: SIMD3<Double>,
    toNormal: SIMD3<Double>
) -> (matrix: simd_double4x4, angle: Double) {
    let axisDir = simd_normalize(axisEnd - axisStart)
    let f = projectOntoPlane(fromNormal, axis: axisDir)
    let t = projectOntoPlane(toNormal, axis: axisDir)
    let fNorm = simd_length(f)
    let tNorm = simd_length(t)
    guard fNorm > 1e-12, tNorm > 1e-12 else {
        return (matrix_identity_double4x4, 0)
    }
    let fU = f / fNorm
    let tU = t / tNorm
    let cosA = simd_dot(fU, tU)
    let sinA = simd_dot(simd_cross(fU, tU), axisDir)
    let angle = atan2(sinA, cosA)
    let mat = rotationAroundLine(axis: axisDir, point: axisStart, angle: angle)
    return (mat, angle)
}

private func projectOntoPlane(_ v: SIMD3<Double>, axis: SIMD3<Double>) -> SIMD3<Double> {
    return v - simd_dot(v, axis) * axis
}

private func rotationAroundOrigin(axis: SIMD3<Double>, angle: Double) -> simd_double4x4 {
    let n = simd_normalize(axis)
    let c = cos(angle)
    let s = sin(angle)
    let k = 1 - c
    let xx = n.x * n.x, yy = n.y * n.y, zz = n.z * n.z
    let xy = n.x * n.y, xz = n.x * n.z, yz = n.y * n.z
    let xs = n.x * s, ys = n.y * s, zs = n.z * s
    return simd_double4x4(columns: (
        SIMD4(xx * k + c,  xy * k + zs, xz * k - ys, 0),
        SIMD4(xy * k - zs, yy * k + c,  yz * k + xs, 0),
        SIMD4(xz * k + ys, yz * k - xs, zz * k + c,  0),
        SIMD4(0, 0, 0, 1)
    ))
}

private func rotationAroundLine(
    axis: SIMD3<Double>,
    point: SIMD3<Double>,
    angle: Double
) -> simd_double4x4 {
    let toOrigin = translation(-point)
    let rot = rotationAroundOrigin(axis: axis, angle: angle)
    let back = translation(point)
    return back * rot * toOrigin
}

private func translation(_ t: SIMD3<Double>) -> simd_double4x4 {
    return simd_double4x4(columns: (
        SIMD4(1, 0, 0, 0),
        SIMD4(0, 1, 0, 0),
        SIMD4(0, 0, 1, 0),
        SIMD4(t.x, t.y, t.z, 1)
    ))
}

private func transformPoint(_ m: simd_double4x4, _ p: SIMD3<Double>) -> SIMD3<Double> {
    let r = m * SIMD4(p.x, p.y, p.z, 1)
    return SIMD3(r.x, r.y, r.z)
}

private func transformNormal(_ m: simd_double4x4, _ n: SIMD3<Double>) -> SIMD3<Double> {
    let r = m * SIMD4(n.x, n.y, n.z, 0)
    return SIMD3(r.x, r.y, r.z)
}

/// Convert a `simd_double4x4` (column-major) to the 12-element row-major
/// array that `Shape.transformed(matrix:)` expects:
/// `[r00,r01,r02, r10,r11,r12, r20,r21,r22, tx,ty,tz]`.
private func matrix12(from m: simd_double4x4) -> [Double] {
    let c0 = m.columns.0
    let c1 = m.columns.1
    let c2 = m.columns.2
    let c3 = m.columns.3
    return [
        c0.x, c1.x, c2.x,
        c0.y, c1.y, c2.y,
        c0.z, c1.z, c2.z,
        c3.x, c3.y, c3.z,
    ]
}

/// SplitMix64 — a small, deterministic, statistically-decent PRNG used to
/// shuffle child-visit order during the connected-net search. Reproducible
/// across runs from the same seed; not cryptographically secure (we only
/// need a varied permutation of small lists).
fileprivate struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

private func anyBoundingBoxOverlap(in shapes: [Shape], tolerance: Double) -> Bool {
    guard shapes.count > 1 else { return false }
    // OCCT's `Shape.transformed(matrix:)` introduces ~1e-7 numerical noise
    // in face bounds. Use an effective overlap threshold above that noise
    // floor so that adjacent faces sharing an edge don't register as
    // overlapping.
    let eps = max(tolerance, 1e-4)

    // Pre-compute boxes and 2D polygon outlines once per face. Bbox overlap
    // is a cheap necessary test but reports false positives for
    // non-axis-aligned faces (two triangles sharing only a corner can have
    // overlapping bboxes even though their interiors are disjoint), which
    // matters a lot for triangulated polyhedra like the icosahedron. When
    // bboxes overlap we confirm with a polygon-polygon separating-axis
    // test on the actual face outlines.
    let boxes = shapes.map { $0.bounds }
    var polygons: [[SIMD2<Double>]?] = Array(repeating: nil, count: shapes.count)
    func polygon(at index: Int) -> [SIMD2<Double>]? {
        if let cached = polygons[index] { return cached }
        let pts = facePolygon2D(shapes[index])
        polygons[index] = pts
        return pts.isEmpty ? nil : pts
    }

    for i in 0..<boxes.count {
        for j in (i + 1)..<boxes.count {
            let a = boxes[i], b = boxes[j]
            let xOverlap = a.min.x <= b.max.x - eps && b.min.x <= a.max.x - eps
            let yOverlap = a.min.y <= b.max.y - eps && b.min.y <= a.max.y - eps
            if !(xOverlap && yOverlap) { continue }
            // Bboxes overlap — confirm with polygon-SAT.
            guard let pa = polygon(at: i), let pb = polygon(at: j) else {
                // Couldn't extract a polygon — fall back to bbox result.
                return true
            }
            if convexPolygonsOverlap(pa, pb, tolerance: eps) {
                return true
            }
        }
    }
    return false
}

/// Extract a 2D polygon outline (XY only) from a face Shape lying in z = 0.
/// Returns the vertex sequence of the outer wire — for triangle/quad/
/// pentagon faces this is the natural face boundary. Used for polygon-SAT
/// overlap testing.
private func facePolygon2D(_ face: Shape) -> [SIMD2<Double>] {
    guard let f = Face(face), let outer = f.outerWire else { return [] }
    var pts: [SIMD2<Double>] = []
    for edge in outer.edges() {
        let endpoints = edge.endpoints
        let p = SIMD2(endpoints.start.x, endpoints.start.y)
        if let last = pts.last, simd_length(p - last) < 1e-9 { continue }
        pts.append(p)
    }
    if let first = pts.first, let last = pts.last,
       pts.count > 1, simd_length(first - last) < 1e-9 {
        pts.removeLast()
    }
    return pts
}

/// Separating-axis-theorem test for convex polygons. Returns `true` if the
/// polygons' interiors penetrate by more than `tolerance` along every
/// candidate axis (the edge normals of both polygons). Edge-sharing or
/// corner-touching at the tolerance scale registers as not-overlapping.
///
/// Concave polygons may produce false positives — for the unfold use case
/// (Platonic solids and rectangular flanges) all faces are convex.
private func convexPolygonsOverlap(
    _ a: [SIMD2<Double>],
    _ b: [SIMD2<Double>],
    tolerance: Double
) -> Bool {
    guard a.count >= 3, b.count >= 3 else { return false }
    func axes(of p: [SIMD2<Double>]) -> [SIMD2<Double>] {
        var out: [SIMD2<Double>] = []
        out.reserveCapacity(p.count)
        for i in 0..<p.count {
            let edge = p[(i + 1) % p.count] - p[i]
            let n = SIMD2(-edge.y, edge.x)
            let len = simd_length(n)
            if len > 1e-12 { out.append(n / len) }
        }
        return out
    }
    for axis in axes(of: a) + axes(of: b) {
        let projA = a.map { simd_dot($0, axis) }
        let projB = b.map { simd_dot($0, axis) }
        let aMin = projA.min()!, aMax = projA.max()!
        let bMin = projB.min()!, bMax = projB.max()!
        // Separated along this axis (with tolerance) → polygons don't
        // overlap. Edge-shared / corner-touching pairs hit this branch.
        if aMax < bMin + tolerance || bMax < aMin + tolerance {
            return false
        }
    }
    return true
}
