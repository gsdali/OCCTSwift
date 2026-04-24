import Foundation

/// Sheet-metal composition API.
///
/// Builds bent sheet-metal parts by extruding planar flanges along their sheet
/// normal, fusing them, then filleting the shared seam edges with the bend
/// radius. Each flange is a 2D profile in its own `(u, v)` plane; `Bend`
/// declares which pair of flanges meet and the inside radius of their bend.
///
/// OCCT has no sheet-metal bend primitive — `BRepFeat_Fold` and friends do not
/// exist. This namespace is the canonical composition of `Shape.extrude`,
/// `Shape.union`, and `Shape.filleted` that downstream consumers can drive
/// from a declarative description (see issue #85).
///
/// The reverse direction — unwrapping a bent sheet-metal solid to a flat
/// cutting pattern — is intended to live in this namespace as well; it is not
/// yet implemented.
///
/// ## Limitations (v0.151)
///
/// - **Stepped seams do not bend.** If two flanges meet along a seam that is
///   shorter than either flange's extent in the seam direction (e.g. a narrow
///   upright sitting on a wider base), the seam edge terminates at a
///   free-face boundary and OCCT cannot cleanly fillet it. The builder
///   reports this as `BuildError.filletFailed`. Workaround: match flange
///   widths along the seam, or split the wider flange so the seam spans the
///   full meeting length.
/// - **Bends apply a single radius to the seam edge as-is**, which in OCCT's
///   classification is the *outside* corner of an L-bracket (the outer
///   surface of the fold). The inner corner stays sharp. Real sheet-metal
///   parts want inner radius `r` and outer radius `r + thickness`; modeling
///   that requires a different construction and is not yet implemented.
public enum SheetMetal {

    /// A single sheet-metal flange: a closed 2D profile positioned in world
    /// space via `(origin, uAxis, vAxis)`, extruded along `normal` by the
    /// builder's `thickness`.
    ///
    /// `uAxis` and `vAxis` need not be derivable from `normal` — explicit
    /// control of all three axes lets you position a flange in any world
    /// orientation without handedness surprises. If `vAxis` is omitted, it is
    /// derived as `cross(normal, uAxis)`.
    public struct Flange: Sendable {
        public let id: String
        public let profile: [SIMD2<Double>]
        public let origin: SIMD3<Double>
        public let uAxis: SIMD3<Double>
        public let vAxis: SIMD3<Double>
        public let normal: SIMD3<Double>

        public init(
            id: String,
            profile: [SIMD2<Double>],
            origin: SIMD3<Double>,
            normal: SIMD3<Double>,
            uAxis: SIMD3<Double>,
            vAxis: SIMD3<Double>? = nil
        ) {
            self.id = id
            self.profile = profile
            self.origin = origin
            self.uAxis = uAxis
            let n = Vector3DMath.normalize(normal) ?? normal
            self.normal = n
            self.vAxis = vAxis ?? Vector3DMath.cross(n, uAxis)
        }

        /// Map a 2D profile point to world space.
        fileprivate func worldPoint(_ p: SIMD2<Double>) -> SIMD3<Double> {
            origin + p.x * uAxis + p.y * vAxis
        }
    }

    /// A bend between two flanges. `radius` is applied as a fillet to the
    /// seam edge(s) where the two flanges meet in the fused body.
    public struct Bend: Sendable {
        public let fromFlangeID: String
        public let toFlangeID: String
        public let radius: Double

        public init(from fromID: String, to toID: String, radius: Double) {
            self.fromFlangeID = fromID
            self.toFlangeID = toID
            self.radius = radius
        }
    }

    public enum BuildError: Error, CustomStringConvertible {
        case invalidThickness(Double)
        case noFlanges
        case duplicateFlangeID(String)
        case unknownFlangeID(String)
        case invalidFlangeProfile(id: String)
        case flangeExtrusionFailed(id: String)
        case unionFailed
        case parallelFlangesHaveNoSeam(fromID: String, toID: String)
        case noSeamEdgeFound(fromID: String, toID: String)
        case filletFailed(fromID: String, toID: String, radius: Double)

        public var description: String {
            switch self {
            case .invalidThickness(let t):
                return "SheetMetal: thickness must be > 0 (got \(t))"
            case .noFlanges:
                return "SheetMetal: at least one flange is required"
            case .duplicateFlangeID(let id):
                return "SheetMetal: duplicate flange id '\(id)'"
            case .unknownFlangeID(let id):
                return "SheetMetal: unknown flange id '\(id)' referenced by bend"
            case .invalidFlangeProfile(let id):
                return "SheetMetal: flange '\(id)' profile is invalid (need >=3 points)"
            case .flangeExtrusionFailed(let id):
                return "SheetMetal: failed to extrude flange '\(id)'"
            case .unionFailed:
                return "SheetMetal: boolean union of flanges failed"
            case .parallelFlangesHaveNoSeam(let a, let b):
                return "SheetMetal: flanges '\(a)' and '\(b)' are parallel — no bend seam"
            case .noSeamEdgeFound(let a, let b):
                return "SheetMetal: no shared seam edge found between '\(a)' and '\(b)' — check flange placement"
            case .filletFailed(let a, let b, let r):
                return "SheetMetal: fillet of radius \(r) between '\(a)' and '\(b)' failed"
            }
        }
    }

    /// Composes a list of flanges and bends into a single bent `Shape`.
    public struct Builder: Sendable {
        public let thickness: Double

        public init(thickness: Double) {
            self.thickness = thickness
        }

        /// Build the bent sheet-metal part.
        ///
        /// 1. Validate inputs and extrude each flange along its normal by
        ///    `thickness`.
        /// 2. Fuse the flange solids in the order supplied.
        /// 3. For each bend, locate the seam edge(s) between the two flanges
        ///    and apply a fillet of the given radius. Bends are applied in
        ///    order; each fillet re-evaluates the current shape's edges.
        public func build(flanges: [Flange], bends: [Bend] = []) throws -> Shape {
            guard thickness > 0 else { throw BuildError.invalidThickness(thickness) }
            guard !flanges.isEmpty else { throw BuildError.noFlanges }

            var flangeByID: [String: Flange] = [:]
            for f in flanges {
                if flangeByID[f.id] != nil { throw BuildError.duplicateFlangeID(f.id) }
                if f.profile.count < 3 { throw BuildError.invalidFlangeProfile(id: f.id) }
                flangeByID[f.id] = f
            }

            var bodies: [String: Shape] = [:]
            for f in flanges {
                guard let body = Self.extrude(flange: f, thickness: thickness) else {
                    throw BuildError.flangeExtrusionFailed(id: f.id)
                }
                bodies[f.id] = body
            }

            var fused = bodies[flanges[0].id]!
            for f in flanges.dropFirst() {
                guard let next = fused.union(bodies[f.id]!) else {
                    throw BuildError.unionFailed
                }
                fused = next
            }

            for bend in bends {
                guard let a = flangeByID[bend.fromFlangeID] else {
                    throw BuildError.unknownFlangeID(bend.fromFlangeID)
                }
                guard let b = flangeByID[bend.toFlangeID] else {
                    throw BuildError.unknownFlangeID(bend.toFlangeID)
                }

                let seamDir = Vector3DMath.cross(a.normal, b.normal)
                guard let seamUnit = Vector3DMath.normalize(seamDir) else {
                    throw BuildError.parallelFlangesHaveNoSeam(
                        fromID: bend.fromFlangeID, toID: bend.toFlangeID)
                }

                let seamEdges = Self.findSeamEdges(
                    in: fused, between: a, and: b,
                    seamUnit: seamUnit, thickness: thickness)
                guard !seamEdges.isEmpty else {
                    throw BuildError.noSeamEdgeFound(
                        fromID: bend.fromFlangeID, toID: bend.toFlangeID)
                }

                guard let filleted = fused.filleted(edges: seamEdges, radius: bend.radius) else {
                    throw BuildError.filletFailed(
                        fromID: bend.fromFlangeID, toID: bend.toFlangeID, radius: bend.radius)
                }
                fused = filleted
            }

            return fused
        }

        private static func extrude(flange: Flange, thickness: Double) -> Shape? {
            let points3D = flange.profile.map { flange.worldPoint($0) }
            guard let wire = Wire.polygon3D(points3D, closed: true) else { return nil }
            return Shape.extrude(profile: wire, direction: flange.normal, length: thickness)
        }

        /// Find the seam edge(s) between two flanges in the fused shape.
        ///
        /// The bend sits at the intersection of two specific faces — each
        /// flange's face pointing *toward* the other. Every other edge where
        /// the two flange planes cross (the convex back corner of an L, for
        /// instance) lies on the opposite pair of faces, so the toward-plane
        /// test uniquely selects the bend.
        ///
        /// Note: OCCT classifies an L-bracket's bend edge as CONVEX (looking
        /// from outside the solid, you turn outward around it). We do not use
        /// `edgeConcavities` — it splits along-bend behavior by orientation
        /// and does not help discriminate here.
        private static func findSeamEdges(
            in shape: Shape,
            between a: Flange, and b: Flange,
            seamUnit: SIMD3<Double>,
            thickness: Double
        ) -> [Edge] {
            let parallelTol = 1e-4
            let planeTol = max(1e-6, thickness * 1e-4)

            // Each flange's "toward-other" face is the one its body midpoint
            // is farther from (i.e., the face the other flange sits beside).
            let midA = bodyMidpoint(of: a, thickness: thickness)
            let midB = bodyMidpoint(of: b, thickness: thickness)
            let aTowardB: Double = Vector3DMath.dot(midB - a.origin, a.normal) > thickness * 0.5 ? thickness : 0
            let bTowardA: Double = Vector3DMath.dot(midA - b.origin, b.normal) > thickness * 0.5 ? thickness : 0

            return shape.edges().filter { edge in
                guard edge.isLine else { return false }
                let (start, end) = edge.endpoints
                let edgeVec = end - start
                guard let edgeUnit = Vector3DMath.normalize(edgeVec) else { return false }

                let dot = Vector3DMath.dot(edgeUnit, seamUnit)
                if abs(abs(dot) - 1.0) > parallelTol { return false }

                let mid = (start + end) * 0.5
                let dA = Vector3DMath.dot(mid - a.origin, a.normal)
                let dB = Vector3DMath.dot(mid - b.origin, b.normal)
                return abs(dA - aTowardB) < planeTol && abs(dB - bTowardA) < planeTol
            }
        }

        private static func bodyMidpoint(of flange: Flange, thickness: Double) -> SIMD3<Double> {
            var sum = SIMD3<Double>(repeating: 0)
            for p in flange.profile { sum += flange.worldPoint(p) }
            let profileCenter = sum / Double(flange.profile.count)
            return profileCenter + 0.5 * thickness * flange.normal
        }
    }
}
