import Foundation
import simd

// MARK: - Value types for 2D drawing dimensions and annotations
//
// These live entirely in Swift — they do NOT round-trip through OCCT's PrsDim /
// XCAFDoc display-dimension classes. That decision is deliberate and recorded on
// the release-plan tracking issue (#67): the v1 closed-loop workflow needs
// dimensions as data (to compare across reconstruction iterations and to hand to
// a DXF writer), not as AIS display objects. XDE-backed round-trip is on the
// v0.139 roadmap if and when STEP AP242 GD&T preservation becomes a requirement.

/// Standard technical-drawing linetypes. Used when rendering a `DrawingDimension`
/// or `DrawingAnnotation` to DXF, PDF, or a viewport.
public enum DrawingLineStyle: String, Sendable, Hashable, Codable {
    case solid
    case dashed      // hidden-line pattern
    case phantom     // long-dash + 2 short-dash
    case chain       // long-dash + short-dash (centreline)
    case dotted
}

/// A dimension attached to a `Drawing`. Each case carries just the geometric
/// definition needed to render it; there's no OCCT handle inside.
public enum DrawingDimension: Sendable, Hashable {
    case linear(Linear)
    case radial(Radial)
    case diameter(Diameter)
    case angular(Angular)

    public struct Linear: Sendable, Hashable {
        public var from: SIMD2<Double>
        public var to: SIMD2<Double>
        /// Perpendicular offset of the dimension line from the measured segment (drawing units).
        public var offset: Double
        /// Optional user-supplied label; nil means auto-format the measured value.
        public var label: String?
        public var style: DrawingLineStyle
        public var id: String?

        public init(from: SIMD2<Double>, to: SIMD2<Double>,
                    offset: Double = 10, label: String? = nil,
                    style: DrawingLineStyle = .solid, id: String? = nil) {
            self.from = from; self.to = to
            self.offset = offset; self.label = label
            self.style = style; self.id = id
        }

        /// Measured 2D distance between `from` and `to`.
        public var value: Double { simd_distance(from, to) }
    }

    public struct Radial: Sendable, Hashable {
        public var centre: SIMD2<Double>
        public var radius: Double
        /// Angle (radians) at which the leader line exits the circle.
        public var leaderAngle: Double
        public var label: String?
        public var style: DrawingLineStyle
        public var id: String?

        public init(centre: SIMD2<Double>, radius: Double,
                    leaderAngle: Double = .pi / 4,
                    label: String? = nil,
                    style: DrawingLineStyle = .solid, id: String? = nil) {
            self.centre = centre; self.radius = radius
            self.leaderAngle = leaderAngle
            self.label = label; self.style = style; self.id = id
        }

        public var value: Double { radius }
    }

    public struct Diameter: Sendable, Hashable {
        public var centre: SIMD2<Double>
        public var radius: Double
        public var leaderAngle: Double
        public var label: String?
        public var style: DrawingLineStyle
        public var id: String?

        public init(centre: SIMD2<Double>, radius: Double,
                    leaderAngle: Double = .pi / 4,
                    label: String? = nil,
                    style: DrawingLineStyle = .solid, id: String? = nil) {
            self.centre = centre; self.radius = radius
            self.leaderAngle = leaderAngle
            self.label = label; self.style = style; self.id = id
        }

        public var value: Double { 2 * radius }
    }

    public struct Angular: Sendable, Hashable {
        /// Vertex at which the two rays meet.
        public var vertex: SIMD2<Double>
        public var ray1: SIMD2<Double>
        public var ray2: SIMD2<Double>
        /// Radius at which the dimension arc is drawn.
        public var arcRadius: Double
        public var label: String?
        public var style: DrawingLineStyle
        public var id: String?

        public init(vertex: SIMD2<Double>, ray1: SIMD2<Double>, ray2: SIMD2<Double>,
                    arcRadius: Double = 20,
                    label: String? = nil,
                    style: DrawingLineStyle = .solid, id: String? = nil) {
            self.vertex = vertex; self.ray1 = ray1; self.ray2 = ray2
            self.arcRadius = arcRadius
            self.label = label; self.style = style; self.id = id
        }

        /// Measured angle between the two rays, in radians (0 ≤ θ ≤ π).
        public var value: Double {
            let v1 = simd_normalize(ray1 - vertex)
            let v2 = simd_normalize(ray2 - vertex)
            return acos(max(-1.0, min(1.0, simd_dot(v1, v2))))
        }
    }

    public var id: String? {
        switch self {
        case .linear(let d):    return d.id
        case .radial(let d):    return d.id
        case .diameter(let d):  return d.id
        case .angular(let d):   return d.id
        }
    }

    public var label: String? {
        switch self {
        case .linear(let d):    return d.label
        case .radial(let d):    return d.label
        case .diameter(let d):  return d.label
        case .angular(let d):   return d.label
        }
    }

    public var value: Double {
        switch self {
        case .linear(let d):    return d.value
        case .radial(let d):    return d.value
        case .diameter(let d):  return d.value
        case .angular(let d):   return d.value
        }
    }
}

/// Non-dimensional 2D annotations attached to a `Drawing` — centrelines, centremarks,
/// construction points, free-form text labels, hatch fills.
public enum DrawingAnnotation: Sendable, Hashable {
    case centreline(Centreline)
    case centermark(Centermark)
    case textLabel(TextLabel)
    case hatch(Hatch)

    public struct Centreline: Sendable, Hashable {
        public var from: SIMD2<Double>
        public var to: SIMD2<Double>
        public var style: DrawingLineStyle    // typically .chain
        public var id: String?

        public init(from: SIMD2<Double>, to: SIMD2<Double>,
                    style: DrawingLineStyle = .chain,
                    id: String? = nil) {
            self.from = from; self.to = to; self.style = style; self.id = id
        }
    }

    public struct Centermark: Sendable, Hashable {
        public var centre: SIMD2<Double>
        /// Full length of each of the two crossing line segments (drawing units).
        public var extent: Double
        public var style: DrawingLineStyle    // typically .chain
        public var id: String?

        public init(centre: SIMD2<Double>, extent: Double = 8,
                    style: DrawingLineStyle = .chain,
                    id: String? = nil) {
            self.centre = centre; self.extent = extent
            self.style = style; self.id = id
        }
    }

    public struct TextLabel: Sendable, Hashable {
        public var position: SIMD2<Double>
        public var text: String
        public var height: Double
        public var rotation: Double     // radians
        public var id: String?

        public init(position: SIMD2<Double>, text: String,
                    height: Double = 3.5, rotation: Double = 0,
                    id: String? = nil) {
            self.position = position; self.text = text
            self.height = height; self.rotation = rotation; self.id = id
        }
    }

    /// ISO 128-50 section-view hatching — a closed outer boundary filled with
    /// parallel lines at `angle` radians, spaced `spacing` drawing-units apart.
    /// Optional `islands` are inner boundaries (holes) that are subtracted
    /// from the hatched region.
    public struct Hatch: Sendable, Hashable {
        public var boundary: [SIMD2<Double>]     // closed polygon (first != last)
        public var angle: Double                 // radians; ISO default π/4 = 45°
        public var spacing: Double               // drawing units; ISO typical 2–4 mm
        public var islands: [[SIMD2<Double>]]    // inner holes (each closed polygon)
        public var layer: String                 // DXF layer, default "HATCH"
        public var id: String?

        public init(boundary: [SIMD2<Double>],
                    angle: Double = .pi / 4,
                    spacing: Double = 3.0,
                    islands: [[SIMD2<Double>]] = [],
                    layer: String = "HATCH",
                    id: String? = nil) {
            self.boundary = boundary
            self.angle = angle
            self.spacing = spacing
            self.islands = islands
            self.layer = layer
            self.id = id
        }
    }
}

/// Storage for drawing-level dimensions and annotations. Wrapped inside `Drawing`
/// so each Drawing carries its own mutable collection without breaking Sendable.
internal final class DrawingAnnotationStore: @unchecked Sendable {
    private let lock = NSLock()
    private var _dimensions: [DrawingDimension] = []
    private var _annotations: [DrawingAnnotation] = []

    var dimensions: [DrawingDimension] { lock.lock(); defer { lock.unlock() }; return _dimensions }
    var annotations: [DrawingAnnotation] { lock.lock(); defer { lock.unlock() }; return _annotations }

    func appendDimension(_ d: DrawingDimension) {
        lock.lock(); defer { lock.unlock() }
        _dimensions.append(d)
    }

    func appendAnnotation(_ a: DrawingAnnotation) {
        lock.lock(); defer { lock.unlock() }
        _annotations.append(a)
    }

    func replaceAnnotations(_ new: [DrawingAnnotation]) {
        lock.lock(); defer { lock.unlock() }
        _annotations = new
    }

    func clear() {
        lock.lock(); defer { lock.unlock() }
        _dimensions.removeAll()
        _annotations.removeAll()
    }
}
