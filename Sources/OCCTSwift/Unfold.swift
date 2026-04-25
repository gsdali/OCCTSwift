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

        public init(
            rootFaceIndex: Int? = nil,
            pinnedCuts: Set<EdgeIdentifier> = [],
            pinnedFolds: Set<EdgeIdentifier> = [],
            tolerance: Double = 1e-7
        ) {
            self.rootFaceIndex = rootFaceIndex
            self.pinnedCuts = pinnedCuts
            self.pinnedFolds = pinnedFolds
            self.tolerance = tolerance
        }
    }

    public enum UnfoldError: Error, Sendable {
        case noFaces
        case nonPlanarFace(faceIndex: Int)
        case missingNormal(faceIndex: Int)
        case bridgeFailed(stage: String)
        case rootIndexOutOfRange(Int, faceCount: Int)
    }

    /// Tier 1 — unfold a shell whose every face is planar.
    ///
    /// Throws `nonPlanarFace` if any face is not planar; for cylinders, cones,
    /// and other developables, see `developable(_:)` (future checkpoint).
    public static func polyhedral(
        _ shape: Shape,
        parameters: Parameters = .init()
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
        transform[rootIdx] = laydownTransform(face: faces[rootIdx])

        var folds: [FoldEdge] = []
        var foldEdges: Set<EdgeIdentifier> = []
        var cuts: [EdgeIdentifier] = []
        var cutSet: Set<EdgeIdentifier> = []
        var visited: Set<Int> = [rootIdx]
        var queue: [Int] = [rootIdx]
        var head = 0

        while head < queue.count {
            let parent = queue[head]
            head += 1
            let parentT = transform[parent]!
            let parentNormalLaid = transformNormal(parentT, faces[parent].normal)

            for (child, edgeIdx) in adjacency[parent] {
                let id = EdgeIdentifier(shapeHash: shapeHash, edgeIndex: edgeIdx)
                if foldEdges.contains(id) { continue }
                if visited.contains(child) {
                    if cutSet.insert(id).inserted {
                        cuts.append(id)
                    }
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
                queue.append(child)
            }
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

private func anyBoundingBoxOverlap(in shapes: [Shape], tolerance: Double) -> Bool {
    guard shapes.count > 1 else { return false }
    let boxes = shapes.map { $0.bounds }
    for i in 0..<boxes.count {
        for j in (i + 1)..<boxes.count {
            let a = boxes[i], b = boxes[j]
            let xOverlap = a.min.x <= b.max.x - tolerance && b.min.x <= a.max.x - tolerance
            let yOverlap = a.min.y <= b.max.y - tolerance && b.min.y <= a.max.y - tolerance
            if xOverlap && yOverlap {
                return true
            }
        }
    }
    return false
}
