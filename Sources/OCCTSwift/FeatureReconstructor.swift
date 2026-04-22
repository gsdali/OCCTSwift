import Foundation
import simd

// MARK: - FeatureReconstructor (#62, on #72 substrate)
//
// Declarative feature-spec → Shape dispatcher. Consumes a sequence of typed
// FeatureSpec entries (revolve / extrude / hole / thread / fillet / chamfer /
// boolean) and produces a Shape via staged evaluation:
//
//   additive (revolve, extrude, boolean union)
//   → subtractive (hole, boolean subtract)
//   → finishing (fillet, chamfer)
//   → annotation (thread)
//
// The EdgeSelector carried by fillet / chamfer uses TopologyRef (from #72
// Phase 1) — so "the edge created by extrude op #3" is a stable reference that
// survives subsequent mutations, rather than an index-based heuristic.
//
// This is the v1 implementation. It:
//   - Does not yet use TopologyGraph history recording during dispatch (the
//     shapes produced are built from primitives; each FeatureSpec gets tagged
//     with its own opName so downstream callers can use TopologyRef.createdBy
//     against the final graph).
//   - Supports partial reconstruction: failures accumulate in skipped[] rather
//     than aborting the whole build.
//   - Emits threads as annotations (metadata) rather than geometry — the
//     Shape.threadedHole / threadedShaft path from v0.139 can be invoked by
//     the caller if real thread geometry is wanted.

public enum FeatureSpec: Sendable, Hashable {
    case revolve(Revolve)
    case extrude(Extrude)
    case hole(Hole)
    case thread(Thread)
    case fillet(Fillet)
    case chamfer(Chamfer)
    case boolean(Boolean)

    public var id: String? {
        switch self {
        case .revolve(let r): return r.id
        case .extrude(let e): return e.id
        case .hole(let h):    return h.id
        case .thread(let t):  return t.id
        case .fillet(let f):  return f.id
        case .chamfer(let c): return c.id
        case .boolean(let b): return b.id
        }
    }

    public struct Revolve: Sendable, Hashable {
        public var profilePoints2D: [SIMD2<Double>]
        public var axisOrigin: SIMD3<Double>
        public var axisDirection: SIMD3<Double>
        public var angleDeg: Double
        public var id: String?

        public init(profilePoints2D: [SIMD2<Double>],
                    axisOrigin: SIMD3<Double>,
                    axisDirection: SIMD3<Double>,
                    angleDeg: Double = 360,
                    id: String? = nil) {
            self.profilePoints2D = profilePoints2D
            self.axisOrigin = axisOrigin
            self.axisDirection = axisDirection
            self.angleDeg = angleDeg
            self.id = id
        }
    }

    public struct Extrude: Sendable, Hashable {
        public var profilePoints2D: [SIMD2<Double>]
        public var planeOrigin: SIMD3<Double>
        public var planeNormal: SIMD3<Double>
        public var length: Double
        public var id: String?

        public init(profilePoints2D: [SIMD2<Double>],
                    planeOrigin: SIMD3<Double>,
                    planeNormal: SIMD3<Double>,
                    length: Double,
                    id: String? = nil) {
            self.profilePoints2D = profilePoints2D
            self.planeOrigin = planeOrigin
            self.planeNormal = planeNormal
            self.length = length
            self.id = id
        }
    }

    public struct Hole: Sendable, Hashable {
        public var axisPoint: SIMD3<Double>
        public var axisDirection: SIMD3<Double>
        public var diameter: Double
        public var depth: Double?
        public var id: String?

        public init(axisPoint: SIMD3<Double>,
                    axisDirection: SIMD3<Double>,
                    diameter: Double,
                    depth: Double? = nil,
                    id: String? = nil) {
            self.axisPoint = axisPoint
            self.axisDirection = axisDirection
            self.diameter = diameter
            self.depth = depth
            self.id = id
        }
    }

    public struct Thread: Sendable, Hashable {
        public var holeRef: String
        public var spec: String    // "M5x0.8", "1/4-20 UNC"
        public var length: Double?
        public var id: String?

        public init(holeRef: String, spec: String, length: Double? = nil, id: String? = nil) {
            self.holeRef = holeRef
            self.spec = spec
            self.length = length
            self.id = id
        }
    }

    public enum EdgeSelector: Sendable, Hashable {
        case all
        case nearPoint(SIMD3<Double>, tolerance: Double)
        case onFeature(String)                // feature id; maps to TopologyRef.createdBy
    }

    public struct Fillet: Sendable, Hashable {
        public var edgeSelector: EdgeSelector
        public var radius: Double
        public var id: String?

        public init(edgeSelector: EdgeSelector, radius: Double, id: String? = nil) {
            self.edgeSelector = edgeSelector
            self.radius = radius
            self.id = id
        }
    }

    public struct Chamfer: Sendable, Hashable {
        public var edgeSelector: EdgeSelector
        public var distance: Double
        public var id: String?

        public init(edgeSelector: EdgeSelector, distance: Double, id: String? = nil) {
            self.edgeSelector = edgeSelector
            self.distance = distance
            self.id = id
        }
    }

    public struct Boolean: Sendable, Hashable {
        public enum Op: String, Sendable, Codable { case union, subtract, intersect }
        public var op: Op
        public var leftID: String
        public var rightID: String
        public var id: String?

        public init(op: Op, leftID: String, rightID: String, id: String? = nil) {
            self.op = op; self.leftID = leftID; self.rightID = rightID; self.id = id
        }
    }
}

public struct FeatureReconstructor: Sendable {
    public struct BuildResult: Sendable {
        public let shape: Shape?
        public let fulfilled: [String]
        public let skipped: [Skipped]
        public let annotations: [Annotation]
    }

    public struct Skipped: Sendable {
        public enum Reason: Sendable {
            case underDetermined(String)
            case occtFailure(String)
            case unresolvedRef(String)
            case unsupported(String)
        }
        public enum Stage: String, Sendable { case additive, subtractive, finishing, annotation }
        public let featureID: String
        public let reason: Reason
        public let stage: Stage
    }

    public struct Annotation: Sendable {
        public enum Kind: Sendable {
            case thread(spec: String, holeRef: String, length: Double?)
        }
        public let kind: Kind
        public let featureID: String
    }

    // MARK: - Entry point

    public static func build(from specs: [FeatureSpec]) -> BuildResult {
        var current: Shape?
        var fulfilled: [String] = []
        var skipped: [Skipped] = []
        var annotations: [Annotation] = []

        // Stage 1: additive
        for spec in specs {
            switch spec {
            case .revolve(let r):
                applyRevolve(r, current: &current, fulfilled: &fulfilled, skipped: &skipped)
            case .extrude(let e):
                applyExtrude(e, current: &current, fulfilled: &fulfilled, skipped: &skipped)
            case .boolean(let b) where b.op == .union:
                // Union needs two named shapes; in v1 we don't maintain a named-shape
                // registry. Treat as unsupported until Phase 7 introduces one.
                skipped.append(Skipped(featureID: b.id ?? "boolean-union",
                                       reason: .unsupported("named-shape registry for unions not yet implemented"),
                                       stage: .additive))
            default: break
            }
        }

        // Stage 2: subtractive
        for spec in specs {
            switch spec {
            case .hole(let h):
                applyHole(h, current: &current, fulfilled: &fulfilled, skipped: &skipped)
            case .boolean(let b) where b.op == .subtract:
                skipped.append(Skipped(featureID: b.id ?? "boolean-subtract",
                                       reason: .unsupported("named-shape registry for booleans not yet implemented"),
                                       stage: .subtractive))
            default: break
            }
        }

        // Stage 3: finishing
        for spec in specs {
            switch spec {
            case .fillet(let f):
                applyFillet(f, current: &current, fulfilled: &fulfilled, skipped: &skipped)
            case .chamfer(let c):
                applyChamfer(c, current: &current, fulfilled: &fulfilled, skipped: &skipped)
            default: break
            }
        }

        // Stage 4: annotation
        for spec in specs {
            if case .thread(let t) = spec {
                annotations.append(Annotation(
                    kind: .thread(spec: t.spec, holeRef: t.holeRef, length: t.length),
                    featureID: t.id ?? "thread"))
                if let id = t.id { fulfilled.append(id) }
            }
        }

        return BuildResult(shape: current, fulfilled: fulfilled,
                           skipped: skipped, annotations: annotations)
    }

    // MARK: - Stage handlers

    private static func applyRevolve(_ r: FeatureSpec.Revolve,
                                     current: inout Shape?,
                                     fulfilled: inout [String],
                                     skipped: inout [Skipped]) {
        guard r.profilePoints2D.count >= 3 else {
            if let id = r.id {
                skipped.append(Skipped(featureID: id,
                                       reason: .underDetermined("revolve profile needs ≥3 points"),
                                       stage: .additive))
            }
            return
        }
        // Build a wire from the 2D points in a plane containing the axis. For v1
        // we place the profile in the XZ plane and let the revolve axis be
        // specified in world coords — downstream can transform afterwards.
        let pts3D = r.profilePoints2D.map { SIMD3<Double>($0.x, 0, $0.y) }
        guard let wire = Wire.polygon3D(pts3D, closed: true) else {
            if let id = r.id {
                skipped.append(Skipped(featureID: id,
                                       reason: .occtFailure("wire construction failed"),
                                       stage: .additive))
            }
            return
        }
        let angle = r.angleDeg * .pi / 180
        guard let body = Shape.revolve(profile: wire,
                                        axisOrigin: r.axisOrigin,
                                        axisDirection: r.axisDirection,
                                        angle: angle) else {
            if let id = r.id {
                skipped.append(Skipped(featureID: id,
                                       reason: .occtFailure("revolve failed"),
                                       stage: .additive))
            }
            return
        }
        current = current.flatMap { $0.union(body) } ?? body
        if let id = r.id { fulfilled.append(id) }
    }

    private static func applyExtrude(_ e: FeatureSpec.Extrude,
                                     current: inout Shape?,
                                     fulfilled: inout [String],
                                     skipped: inout [Skipped]) {
        guard e.profilePoints2D.count >= 3 else {
            if let id = e.id {
                skipped.append(Skipped(featureID: id,
                                       reason: .underDetermined("extrude profile needs ≥3 points"),
                                       stage: .additive))
            }
            return
        }
        // Lift the 2D profile into 3D on the given plane.
        let placement = Placement(origin: e.planeOrigin, normal: e.planeNormal)
        let pts3D = e.profilePoints2D.map {
            placement.origin + $0.x * placement.xAxis + $0.y * placement.yAxis
        }
        guard let wire = Wire.polygon3D(pts3D, closed: true) else {
            if let id = e.id {
                skipped.append(Skipped(featureID: id,
                                       reason: .occtFailure("wire construction failed"),
                                       stage: .additive))
            }
            return
        }
        guard let body = Shape.extrude(profile: wire,
                                        direction: simd_normalize(e.planeNormal),
                                        length: e.length) else {
            if let id = e.id {
                skipped.append(Skipped(featureID: id,
                                       reason: .occtFailure("extrude failed"),
                                       stage: .additive))
            }
            return
        }
        current = current.flatMap { $0.union(body) } ?? body
        if let id = e.id { fulfilled.append(id) }
    }

    private static func applyHole(_ h: FeatureSpec.Hole,
                                  current: inout Shape?,
                                  fulfilled: inout [String],
                                  skipped: inout [Skipped]) {
        guard let target = current else {
            if let id = h.id {
                skipped.append(Skipped(featureID: id,
                                       reason: .underDetermined("no target shape"),
                                       stage: .subtractive))
            }
            return
        }
        let depth = h.depth ?? 100.0
        guard let drill = Shape.cylinder(at: h.axisPoint,
                                          direction: h.axisDirection,
                                          radius: h.diameter / 2,
                                          height: depth) else {
            if let id = h.id {
                skipped.append(Skipped(featureID: id,
                                       reason: .occtFailure("drill cylinder failed"),
                                       stage: .subtractive))
            }
            return
        }
        guard let cut = target.subtracting(drill) else {
            if let id = h.id {
                skipped.append(Skipped(featureID: id,
                                       reason: .occtFailure("boolean subtract failed"),
                                       stage: .subtractive))
            }
            return
        }
        current = cut
        if let id = h.id { fulfilled.append(id) }
    }

    private static func applyFillet(_ f: FeatureSpec.Fillet,
                                    current: inout Shape?,
                                    fulfilled: inout [String],
                                    skipped: inout [Skipped]) {
        guard let target = current else {
            if let id = f.id {
                skipped.append(Skipped(featureID: id,
                                       reason: .underDetermined("no target shape"),
                                       stage: .finishing))
            }
            return
        }
        // For v1, `.all` applies a uniform fillet; `.nearPoint` and `.onFeature`
        // require edge-resolution machinery that's not yet wired (planned for
        // a later release once TopologyGraph is integrated into the dispatcher).
        switch f.edgeSelector {
        case .all:
            if let filleted = target.filleted(radius: f.radius) {
                current = filleted
                if let id = f.id { fulfilled.append(id) }
            } else if let id = f.id {
                skipped.append(Skipped(featureID: id,
                                       reason: .occtFailure("uniform fillet failed"),
                                       stage: .finishing))
            }
        case .nearPoint, .onFeature:
            if let id = f.id {
                skipped.append(Skipped(featureID: id,
                                       reason: .unsupported("edge selector requires TopologyGraph dispatcher integration"),
                                       stage: .finishing))
            }
        }
    }

    private static func applyChamfer(_ c: FeatureSpec.Chamfer,
                                     current: inout Shape?,
                                     fulfilled: inout [String],
                                     skipped: inout [Skipped]) {
        guard let target = current else {
            if let id = c.id {
                skipped.append(Skipped(featureID: id,
                                       reason: .underDetermined("no target shape"),
                                       stage: .finishing))
            }
            return
        }
        switch c.edgeSelector {
        case .all:
            if let ch = target.chamfered(distance: c.distance) {
                current = ch
                if let id = c.id { fulfilled.append(id) }
            } else if let id = c.id {
                skipped.append(Skipped(featureID: id,
                                       reason: .occtFailure("uniform chamfer failed"),
                                       stage: .finishing))
            }
        case .nearPoint, .onFeature:
            if let id = c.id {
                skipped.append(Skipped(featureID: id,
                                       reason: .unsupported("edge selector requires TopologyGraph dispatcher integration"),
                                       stage: .finishing))
            }
        }
    }
}

// MARK: - JSON front end

extension FeatureReconstructor {
    /// Minimal JSON front end: parses a top-level `{"features": [...]}` object
    /// with `kind`-discriminated entries. The full schema mirrors the OCCTDesignLoop
    /// part_graph.py contract; this is a starting surface for JSON-driven
    /// dispatch, to be extended as the schema stabilises.
    public static func buildJSON(_ data: Data) throws -> BuildResult {
        struct Envelope: Decodable {
            var features: [FeatureEntry]
        }
        let env = try JSONDecoder().decode(Envelope.self, from: data)
        return build(from: env.features.compactMap { $0.spec })
    }
}

// MARK: - JSON decoding helpers

private struct FeatureEntry: Decodable {
    let spec: FeatureSpec?

    enum CodingKeys: String, CodingKey {
        case kind
        case profilePoints2D = "profile_points_2d"
        case axisOrigin = "axis_origin"
        case axisDirection = "axis_direction"
        case planeOrigin = "plane_origin"
        case planeNormal = "plane_normal"
        case angleDeg = "angle_deg"
        case length
        case axisPoint = "axis_point"
        case diameter
        case depth
        case radius
        case distance
        case holeRef = "hole_ref"
        case spec = "thread_spec"
        case threadSpec = "spec"
        case id
        case op
        case leftID = "left"
        case rightID = "right"
        case edgeSelector = "edges"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(String.self, forKey: .kind)
        let id = try c.decodeIfPresent(String.self, forKey: .id)

        switch kind {
        case "revolve":
            let pts = try c.decode([[Double]].self, forKey: .profilePoints2D).map { SIMD2($0[0], $0[1]) }
            let axisOrigin = try c.decode([Double].self, forKey: .axisOrigin)
            let axisDir = try c.decode([Double].self, forKey: .axisDirection)
            let angle = try c.decodeIfPresent(Double.self, forKey: .angleDeg) ?? 360
            self.spec = .revolve(.init(
                profilePoints2D: pts,
                axisOrigin: SIMD3(axisOrigin[0], axisOrigin[1], axisOrigin[2]),
                axisDirection: SIMD3(axisDir[0], axisDir[1], axisDir[2]),
                angleDeg: angle, id: id))
        case "extrude":
            let pts = try c.decode([[Double]].self, forKey: .profilePoints2D).map { SIMD2($0[0], $0[1]) }
            let origin = try c.decode([Double].self, forKey: .planeOrigin)
            let normal = try c.decode([Double].self, forKey: .planeNormal)
            let length = try c.decode(Double.self, forKey: .length)
            self.spec = .extrude(.init(
                profilePoints2D: pts,
                planeOrigin: SIMD3(origin[0], origin[1], origin[2]),
                planeNormal: SIMD3(normal[0], normal[1], normal[2]),
                length: length, id: id))
        case "hole":
            let axisPoint = try c.decode([Double].self, forKey: .axisPoint)
            let axisDir = try c.decode([Double].self, forKey: .axisDirection)
            let d = try c.decode(Double.self, forKey: .diameter)
            let depth = try c.decodeIfPresent(Double.self, forKey: .depth)
            self.spec = .hole(.init(
                axisPoint: SIMD3(axisPoint[0], axisPoint[1], axisPoint[2]),
                axisDirection: SIMD3(axisDir[0], axisDir[1], axisDir[2]),
                diameter: d, depth: depth, id: id))
        case "thread":
            let holeRef = try c.decode(String.self, forKey: .holeRef)
            let threadSpec = try c.decode(String.self, forKey: .spec)
            let length = try c.decodeIfPresent(Double.self, forKey: .length)
            self.spec = .thread(.init(holeRef: holeRef, spec: threadSpec, length: length, id: id))
        case "fillet":
            let radius = try c.decode(Double.self, forKey: .radius)
            self.spec = .fillet(.init(edgeSelector: .all, radius: radius, id: id))
        case "chamfer":
            let distance = try c.decode(Double.self, forKey: .distance)
            self.spec = .chamfer(.init(edgeSelector: .all, distance: distance, id: id))
        default:
            self.spec = nil
        }
    }
}
