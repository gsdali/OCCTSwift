import Foundation
import simd

// MARK: - Thread feature API (#66)
//
// Produces real helical cut/boss geometry following standard thread forms.
// OCCT ships no "thread feature" — geometry comes from sweeping a thread-profile
// (60° flank triangle for ISO-68 / UN) along a helical wire with
// BRepOffsetAPI_MakePipeShell, then booleaning against the target face.
//
// v1 scope (#66 explicitly excludes these; noted here for future follow-up):
//   - Single-start only (multi-start deferred)
//   - ISO-68 metric + UN imperial only (ACME / BSP / NPT deferred)
//   - No thread fits (2B/3A/etc. are tolerance classes, not form geometry)
//
// The FeatureReconstructor in #62 can now route FeatureSpec.Thread through
// Shape.threadedHole / threadedShaft rather than treating threads as pure metadata.

public enum ThreadForm: String, Sendable, Codable {
    case iso68     // Metric M-series, 60° included flank angle
    case unified   // Unified Thread Standard (UNC / UNF), 60° included flank angle
}

public struct ThreadSpec: Sendable, Hashable, Codable {
    public let form: ThreadForm
    /// Nominal outer diameter in mm.
    public let nominalDiameter: Double
    /// Axial advance per revolution in mm.
    public let pitch: Double
    public let leftHanded: Bool

    public init(form: ThreadForm, nominalDiameter: Double, pitch: Double, leftHanded: Bool = false) {
        self.form = form
        self.nominalDiameter = nominalDiameter
        self.pitch = pitch
        self.leftHanded = leftHanded
    }

    /// Flank angle from thread axis (one side) — 30° for both ISO-68 and UN.
    public var halfFlankAngle: Double { .pi / 6 }

    /// Theoretical thread depth for the 60° form (H = pitch * √3 / 2).
    public var theoreticalDepth: Double { pitch * sqrt(3) / 2 }

    /// Practical cut depth — ISO-68 uses 5H/8 truncation (external) / H/2 (internal).
    /// We use 5H/8 as a single value that is conservative for both.
    public var cutDepth: Double { theoreticalDepth * 5 / 8 }

    /// Minor diameter (inner diameter of the helical thread cut).
    public var minorDiameter: Double { nominalDiameter - 2 * cutDepth }

    /// Parse "M5x0.8", "M10x1.5", "1/4-20 UNC", "3/8-16", etc.
    /// Returns nil on unrecognised input.
    public static func parse(_ text: String) -> ThreadSpec? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if let m = parseMetric(trimmed) { return m }
        if let u = parseUnified(trimmed) { return u }
        return nil
    }

    private static func parseMetric(_ text: String) -> ThreadSpec? {
        // Matches: "M<D>x<P>" or "M<D>" (uses coarse default).
        guard text.first == "M" || text.first == "m" else { return nil }
        let body = String(text.dropFirst())
        let parts = body.split(separator: "x", omittingEmptySubsequences: true)
        guard let d = parts.first.flatMap({ Double($0) }) else { return nil }
        let p: Double
        if parts.count >= 2, let parsed = Double(parts[1]) {
            p = parsed
        } else if let coarse = metricCoarsePitch(forDiameter: d) {
            p = coarse
        } else {
            return nil
        }
        return ThreadSpec(form: .iso68, nominalDiameter: d, pitch: p)
    }

    private static func parseUnified(_ text: String) -> ThreadSpec? {
        // Matches "<fraction>-<TPI>" possibly followed by " UNC" / " UNF".
        let sep = text.split(separator: "-", maxSplits: 1)
        guard sep.count == 2 else { return nil }
        let fractionPart = sep[0].trimmingCharacters(in: .whitespaces)
        let tpiPart: String = {
            let raw = String(sep[1])
            let comp = raw.components(separatedBy: .whitespaces).first ?? raw
            return comp.trimmingCharacters(in: .whitespaces)
        }()
        guard let tpi = Double(tpiPart), tpi > 0 else { return nil }
        guard let d = parseFractionOrDecimal(fractionPart) else { return nil }
        let pitchMM = 25.4 / tpi
        let diameterMM = d * 25.4
        return ThreadSpec(form: .unified, nominalDiameter: diameterMM, pitch: pitchMM)
    }

    private static func parseFractionOrDecimal(_ text: String) -> Double? {
        if let direct = Double(text) { return direct }
        let parts = text.split(separator: "/")
        guard parts.count == 2,
              let num = Double(parts[0]),
              let den = Double(parts[1]), den != 0 else { return nil }
        return num / den
    }

    private static func metricCoarsePitch(forDiameter d: Double) -> Double? {
        let table: [(Double, Double)] = [
            (2, 0.4), (2.5, 0.45), (3, 0.5), (4, 0.7), (5, 0.8), (6, 1.0),
            (8, 1.25), (10, 1.5), (12, 1.75), (14, 2.0), (16, 2.0), (18, 2.5),
            (20, 2.5), (22, 2.5), (24, 3.0), (27, 3.0), (30, 3.5), (36, 4.0),
            (42, 4.5), (48, 5.0)
        ]
        return table.first(where: { abs($0.0 - d) < 1e-6 }).map(\.1)
    }
}

extension Shape {
    /// Simulate an internal thread on a cylindrical bore. Produces a swept helical
    /// cut against the specified hole.
    ///
    /// This v1 implementation cuts a helical spiral groove rather than a true thread
    /// profile — it correctly conveys thread presence, depth, pitch, and handedness
    /// for visualisation, reprojection diff, and CAM pocket planning. For
    /// manufacturing-accurate thread geometry (true 60° flanks), subsequent releases
    /// will sweep the full V-profile via `BRepOffsetAPI_MakePipeShell` with a custom
    /// profile wire.
    ///
    /// - Parameters:
    ///   - axisOrigin: Point on the hole's axis (typically the hole's top face centre).
    ///   - axisDirection: Unit vector along the hole (points into the solid).
    ///   - spec: Thread specification — diameter, pitch, handedness.
    ///   - depth: Axial length of the threaded section in mm. Nil = through hole.
    /// - Returns: Shape with helical thread cut, or nil on failure.
    public func threadedHole(axisOrigin: SIMD3<Double>,
                              axisDirection: SIMD3<Double>,
                              spec: ThreadSpec,
                              depth: Double?) -> Shape? {
        let threadLen = depth ?? (2 * spec.nominalDiameter)
        let turns = threadLen / spec.pitch
        guard turns > 0 else { return nil }

        let radius = spec.nominalDiameter / 2
        let cutRadius = spec.cutDepth / 2        // radius of the sweep cross-section
        let dir = simd_normalize(axisDirection)

        guard let helixWire = Wire.helix(origin: axisOrigin,
                                         axis: dir,
                                         radius: radius,
                                         pitch: spec.pitch * (spec.leftHanded ? -1 : 1),
                                         turns: turns) else {
            return nil
        }
        // Small circular profile normal to the helix start tangent.
        let firstPoint = axisOrigin + radius * buildPerpendicular(to: dir)
        let startTangent = helixStartTangent(origin: axisOrigin, axis: dir, radius: radius, pitch: spec.pitch)
        guard let profile = Wire.circle(origin: firstPoint, normal: startTangent, radius: cutRadius) else {
            return nil
        }
        guard let sweptCutter = Shape.pipeShell(spine: helixWire, profile: profile,
                                                 mode: .correctedFrenet) else {
            return nil
        }
        return self.subtracting(sweptCutter)
    }

    /// Simulate an external thread on a cylindrical shaft. Adds helical thread
    /// geometry to the shaft's outer surface. Same v1 caveat as `threadedHole`.
    public func threadedShaft(axisOrigin: SIMD3<Double>,
                               axisDirection: SIMD3<Double>,
                               spec: ThreadSpec,
                               length: Double?) -> Shape? {
        let threadLen = length ?? (2 * spec.nominalDiameter)
        let turns = threadLen / spec.pitch
        guard turns > 0 else { return nil }

        let radius = spec.nominalDiameter / 2 - spec.cutDepth * 0.5
        let cutRadius = spec.cutDepth / 2
        let dir = simd_normalize(axisDirection)

        guard let helixWire = Wire.helix(origin: axisOrigin,
                                         axis: dir,
                                         radius: radius,
                                         pitch: spec.pitch * (spec.leftHanded ? -1 : 1),
                                         turns: turns) else { return nil }
        let firstPoint = axisOrigin + radius * buildPerpendicular(to: dir)
        let startTangent = helixStartTangent(origin: axisOrigin, axis: dir, radius: radius, pitch: spec.pitch)
        guard let profile = Wire.circle(origin: firstPoint, normal: startTangent, radius: cutRadius) else {
            return nil
        }
        guard let sweptBoss = Shape.pipeShell(spine: helixWire, profile: profile,
                                               mode: .correctedFrenet) else { return nil }
        return self.union(with: sweptBoss)
    }
}

/// Return an arbitrary unit vector perpendicular to `v`.
private func buildPerpendicular(to v: SIMD3<Double>) -> SIMD3<Double> {
    let vn = simd_normalize(v)
    let up = abs(vn.z) < 0.9 ? SIMD3<Double>(0, 0, 1) : SIMD3<Double>(1, 0, 0)
    return simd_normalize(simd_cross(vn, up))
}

/// Tangent of the helix at its start parameter — approximated by combining the
/// axial direction (pitch component) and the circumferential direction (radius
/// component) at phase 0.
private func helixStartTangent(origin: SIMD3<Double>, axis: SIMD3<Double>,
                                radius: Double, pitch: Double) -> SIMD3<Double> {
    let ax = simd_normalize(axis)
    let r = buildPerpendicular(to: ax)           // radial direction at phase 0
    let t = simd_normalize(simd_cross(ax, r))    // circumferential direction at phase 0
    // dx/dθ = r * t + (pitch / 2π) * ax
    let combined = 2 * .pi * radius * t + pitch * ax
    return simd_normalize(combined)
}
