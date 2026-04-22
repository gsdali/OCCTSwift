import Foundation
import simd

// MARK: - DXF 2D export (#63)
//
// OCCT ships no DXF reader or writer. This is a pure-Swift implementation of the
// DXF R12 ASCII subset sufficient to round-trip 2D engineering drawings into
// LibreCAD / QCAD / AutoCAD. It covers LINE, CIRCLE, ARC, LWPOLYLINE, TEXT, and
// the DIMENSION entity (as exploded LINE/TEXT geometry — most consumers can
// read full DIMENSION entities but composing them correctly across implementations
// is finicky, and the exploded form is universally readable).
//
// Layers/linetypes follow technical-drawing convention:
//   VISIBLE   — solid
//   HIDDEN    — DASHED
//   OUTLINE   — solid
//   CENTER    — CHAIN (short-long pattern)
//   DIMENSION — solid
//   TEXT      — solid
//
// v1 renders non-line edges as LWPOLYLINEs from `Shape.allEdgePolylines`. Future
// iterations can emit CIRCLE/ARC/ELLIPSE natively once circle-centre/radius is
// wrapped for Edge.

public enum DXFError: Error, LocalizedError {
    case writeFailed(String)
    case drawingEmpty

    public var errorDescription: String? {
        switch self {
        case .writeFailed(let msg): return "DXF write failed: \(msg)"
        case .drawingEmpty:         return "Drawing contains no edges or annotations"
        }
    }
}

extension Exporter {
    /// Export a `Drawing` (HLR projection + optional dimensions/annotations) to DXF R12.
    public static func writeDXF(drawing: Drawing, to url: URL,
                                deflection: Double = 0.1) throws {
        let writer = DXFWriter(deflection: deflection)
        writer.collectFromDrawing(drawing)
        try writer.write(to: url)
    }

    /// Convenience: project the shape along `viewDirection` and export the projection as DXF.
    public static func writeDXF(shape: Shape, to url: URL,
                                viewDirection: SIMD3<Double> = SIMD3(0, 0, 1),
                                deflection: Double = 0.1) throws {
        guard let drawing = Drawing.project(shape, direction: viewDirection) else {
            throw DXFError.writeFailed("projection failed")
        }
        try writeDXF(drawing: drawing, to: url, deflection: deflection)
    }
}

/// Pure-Swift DXF R12 ASCII writer. Public so callers can stage entities manually
/// (useful for tests and for scripts that compose DXFs from mixed sources).
public final class DXFWriter: @unchecked Sendable {
    public let deflection: Double
    private var lines: [(a: SIMD2<Double>, b: SIMD2<Double>, layer: String)] = []
    private var polylines: [(points: [SIMD2<Double>], closed: Bool, layer: String)] = []
    private var circles: [(centre: SIMD2<Double>, radius: Double, layer: String)] = []
    private var arcs: [(centre: SIMD2<Double>, radius: Double, startAngleDeg: Double, endAngleDeg: Double, layer: String)] = []
    private var texts: [(position: SIMD2<Double>, text: String, height: Double, rotationDeg: Double, layer: String)] = []

    public init(deflection: Double = 0.1) {
        self.deflection = deflection
    }

    // MARK: - Entity staging

    public func addLine(from a: SIMD2<Double>, to b: SIMD2<Double>, layer: String = "VISIBLE") {
        lines.append((a, b, layer))
    }

    public func addPolyline(_ points: [SIMD2<Double>], closed: Bool = false, layer: String = "VISIBLE") {
        guard points.count >= 2 else { return }
        polylines.append((points, closed, layer))
    }

    public func addCircle(centre: SIMD2<Double>, radius: Double, layer: String = "VISIBLE") {
        circles.append((centre, radius, layer))
    }

    public func addArc(centre: SIMD2<Double>, radius: Double,
                       startAngleDeg: Double, endAngleDeg: Double,
                       layer: String = "VISIBLE") {
        arcs.append((centre, radius, startAngleDeg, endAngleDeg, layer))
    }

    public func addText(_ text: String, at position: SIMD2<Double>,
                        height: Double = 3.5, rotationDeg: Double = 0,
                        layer: String = "TEXT") {
        texts.append((position, text, height, rotationDeg, layer))
    }

    // MARK: - Collection from Drawing

    public func collectFromDrawing(_ drawing: Drawing) {
        collectProjectedEdges(drawing.visibleEdges, layer: "VISIBLE")
        collectProjectedEdges(drawing.hiddenEdges,  layer: "HIDDEN")
        collectProjectedEdges(drawing.outlineEdges, layer: "OUTLINE")
        collectAnnotations(drawing.annotations)
        collectDimensions(drawing.dimensions)
    }

    private func collectProjectedEdges(_ compound: Shape?, layer: String) {
        guard let compound else { return }
        let polys = compound.allEdgePolylines(deflection: deflection)
        for poly in polys {
            guard poly.count >= 2 else { continue }
            let points2D = poly.map { SIMD2($0.x, $0.y) }
            if points2D.count == 2 {
                addLine(from: points2D[0], to: points2D[1], layer: layer)
            } else {
                addPolyline(points2D, closed: false, layer: layer)
            }
        }
    }

    private func collectAnnotations(_ anns: [DrawingAnnotation]) {
        for a in anns {
            switch a {
            case .centreline(let c):
                addLine(from: c.from, to: c.to, layer: "CENTER")
            case .centermark(let m):
                let h = m.extent / 2
                addLine(from: SIMD2(m.centre.x - h, m.centre.y),
                        to:   SIMD2(m.centre.x + h, m.centre.y), layer: "CENTER")
                addLine(from: SIMD2(m.centre.x, m.centre.y - h),
                        to:   SIMD2(m.centre.x, m.centre.y + h), layer: "CENTER")
            case .textLabel(let t):
                addText(t.text, at: t.position, height: t.height,
                        rotationDeg: t.rotation * 180 / .pi, layer: "TEXT")
            }
        }
    }

    private func collectDimensions(_ dims: [DrawingDimension]) {
        for d in dims {
            switch d {
            case .linear(let lin):   emitLinear(lin)
            case .radial(let rad):   emitRadial(rad)
            case .diameter(let dia): emitDiameter(dia)
            case .angular(let ang):  emitAngular(ang)
            }
        }
    }

    private func emitLinear(_ d: DrawingDimension.Linear) {
        // Render dimension as: two extension lines + the dimension line + the text label.
        // Direction of dimension line = perpendicular to the from-to vector, offset distance.
        let dir = simd_normalize(d.to - d.from)
        let perp = SIMD2<Double>(-dir.y, dir.x)
        let from2 = d.from + perp * d.offset
        let to2   = d.to   + perp * d.offset
        // Extension lines (from measured endpoint to dimension line endpoint)
        addLine(from: d.from, to: from2, layer: "DIMENSION")
        addLine(from: d.to,   to: to2,   layer: "DIMENSION")
        // The dimension line itself
        addLine(from: from2, to: to2, layer: "DIMENSION")
        // Label
        let mid = (from2 + to2) / 2
        let label = d.label ?? String(format: "%.2f", d.value)
        let rotDeg = atan2(dir.y, dir.x) * 180 / .pi
        addText(label, at: mid + perp * 2, height: 3.5, rotationDeg: rotDeg, layer: "TEXT")
    }

    private func emitRadial(_ d: DrawingDimension.Radial) {
        let endOnCircle = SIMD2(d.centre.x + d.radius * cos(d.leaderAngle),
                                 d.centre.y + d.radius * sin(d.leaderAngle))
        let leaderTip = SIMD2(d.centre.x + (d.radius + 10) * cos(d.leaderAngle),
                               d.centre.y + (d.radius + 10) * sin(d.leaderAngle))
        addCircle(centre: d.centre, radius: d.radius, layer: "DIMENSION")
        addLine(from: endOnCircle, to: leaderTip, layer: "DIMENSION")
        let label = d.label ?? String(format: "R%.2f", d.value)
        addText(label, at: leaderTip, height: 3.5, layer: "TEXT")
    }

    private func emitDiameter(_ d: DrawingDimension.Diameter) {
        let cos_ = cos(d.leaderAngle)
        let sin_ = sin(d.leaderAngle)
        let pA = SIMD2(d.centre.x - d.radius * cos_, d.centre.y - d.radius * sin_)
        let pB = SIMD2(d.centre.x + d.radius * cos_, d.centre.y + d.radius * sin_)
        addLine(from: pA, to: pB, layer: "DIMENSION")
        let tip = SIMD2(pB.x + 5 * cos_, pB.y + 5 * sin_)
        let label = d.label ?? String(format: "⌀%.2f", d.value)
        addText(label, at: tip, height: 3.5, layer: "TEXT")
    }

    private func emitAngular(_ d: DrawingDimension.Angular) {
        let v1 = simd_normalize(d.ray1 - d.vertex)
        let v2 = simd_normalize(d.ray2 - d.vertex)
        let a1 = atan2(v1.y, v1.x)
        let a2 = atan2(v2.y, v2.x)
        var start = a1, end = a2
        if end < start { swap(&start, &end) }
        addArc(centre: d.vertex, radius: d.arcRadius,
               startAngleDeg: start * 180 / .pi,
               endAngleDeg: end * 180 / .pi,
               layer: "DIMENSION")
        let midAngle = (start + end) / 2
        let textPos = SIMD2(d.vertex.x + (d.arcRadius + 3) * cos(midAngle),
                             d.vertex.y + (d.arcRadius + 3) * sin(midAngle))
        let label = d.label ?? String(format: "%.1f°", d.value * 180 / .pi)
        addText(label, at: textPos, height: 3.5, layer: "TEXT")
    }

    // MARK: - Serialization

    public func write(to url: URL) throws {
        var out = ""
        out.reserveCapacity(8192)
        out += header()
        out += tables()
        out += blocks()
        out += entities()
        out += eof()
        do {
            try out.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw DXFError.writeFailed(error.localizedDescription)
        }
    }

    // MARK: - DXF sections

    private func pair(_ code: Int, _ value: String) -> String {
        "\(code)\n\(value)\n"
    }
    private func pair(_ code: Int, _ value: Double) -> String {
        pair(code, String(format: "%.6f", value))
    }
    private func pair(_ code: Int, _ value: Int) -> String {
        pair(code, "\(value)")
    }

    private func header() -> String {
        pair(0, "SECTION") + pair(2, "HEADER")
            + pair(9, "$ACADVER") + pair(1, "AC1009")
            + pair(9, "$INSUNITS") + pair(70, 4)   // mm
            + pair(0, "ENDSEC")
    }

    private func tables() -> String {
        var s = pair(0, "SECTION") + pair(2, "TABLES")

        // LTYPE
        s += pair(0, "TABLE") + pair(2, "LTYPE") + pair(70, 4)
        s += pair(0, "LTYPE") + pair(2, "CONTINUOUS") + pair(70, 0) + pair(3, "Solid line") + pair(72, 65) + pair(73, 0) + pair(40, 0.0)
        s += pair(0, "LTYPE") + pair(2, "DASHED")     + pair(70, 0) + pair(3, "Dashed ____ ____ ____") + pair(72, 65) + pair(73, 2) + pair(40, 7.5)
            + pair(49, 5.0) + pair(49, -2.5)
        s += pair(0, "LTYPE") + pair(2, "CHAIN")      + pair(70, 0) + pair(3, "Chain ____ _ ____ _") + pair(72, 65) + pair(73, 4) + pair(40, 15.0)
            + pair(49, 10.0) + pair(49, -2.5) + pair(49, 0.0) + pair(49, -2.5)
        s += pair(0, "ENDTAB")

        // LAYER
        s += pair(0, "TABLE") + pair(2, "LAYER") + pair(70, 6)
        s += layer("0",         colour: 7, linetype: "CONTINUOUS")
        s += layer("VISIBLE",   colour: 7, linetype: "CONTINUOUS")
        s += layer("HIDDEN",    colour: 8, linetype: "DASHED")
        s += layer("OUTLINE",   colour: 7, linetype: "CONTINUOUS")
        s += layer("CENTER",    colour: 1, linetype: "CHAIN")
        s += layer("DIMENSION", colour: 5, linetype: "CONTINUOUS")
        s += layer("TEXT",      colour: 3, linetype: "CONTINUOUS")
        s += pair(0, "ENDTAB")

        // Required STYLE table (one default style)
        s += pair(0, "TABLE") + pair(2, "STYLE") + pair(70, 1)
        s += pair(0, "STYLE") + pair(2, "STANDARD") + pair(70, 0) + pair(40, 0.0) + pair(41, 1.0) + pair(50, 0.0) + pair(71, 0) + pair(42, 2.5) + pair(3, "txt") + pair(4, "")
        s += pair(0, "ENDTAB")

        s += pair(0, "ENDSEC")
        return s
    }

    private func layer(_ name: String, colour: Int, linetype: String) -> String {
        pair(0, "LAYER") + pair(2, name) + pair(70, 0) + pair(62, colour) + pair(6, linetype)
    }

    private func blocks() -> String {
        // Empty BLOCKS section required by R12.
        pair(0, "SECTION") + pair(2, "BLOCKS") + pair(0, "ENDSEC")
    }

    private func entities() -> String {
        var s = pair(0, "SECTION") + pair(2, "ENTITIES")
        for l in lines {
            s += pair(0, "LINE") + pair(8, l.layer)
                + pair(10, l.a.x) + pair(20, l.a.y) + pair(30, 0.0)
                + pair(11, l.b.x) + pair(21, l.b.y) + pair(31, 0.0)
        }
        for p in polylines {
            s += pair(0, "LWPOLYLINE") + pair(8, p.layer)
                + pair(90, p.points.count) + pair(70, p.closed ? 1 : 0)
            for pt in p.points {
                s += pair(10, pt.x) + pair(20, pt.y)
            }
        }
        for c in circles {
            s += pair(0, "CIRCLE") + pair(8, c.layer)
                + pair(10, c.centre.x) + pair(20, c.centre.y) + pair(30, 0.0)
                + pair(40, c.radius)
        }
        for a in arcs {
            s += pair(0, "ARC") + pair(8, a.layer)
                + pair(10, a.centre.x) + pair(20, a.centre.y) + pair(30, 0.0)
                + pair(40, a.radius)
                + pair(50, a.startAngleDeg) + pair(51, a.endAngleDeg)
        }
        for t in texts {
            s += pair(0, "TEXT") + pair(8, t.layer)
                + pair(10, t.position.x) + pair(20, t.position.y) + pair(30, 0.0)
                + pair(40, t.height)
                + pair(1, t.text)
                + pair(50, t.rotationDeg)
        }
        s += pair(0, "ENDSEC")
        return s
    }

    private func eof() -> String {
        pair(0, "EOF")
    }

    // MARK: - Introspection (used by tests)

    public var entityCounts: (lines: Int, polylines: Int, circles: Int, arcs: Int, texts: Int) {
        (lines.count, polylines.count, circles.count, arcs.count, texts.count)
    }
}
