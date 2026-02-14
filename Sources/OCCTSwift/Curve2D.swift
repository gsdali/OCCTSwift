import Foundation
import simd
import OCCTBridge

/// A parametric 2D curve backed by `Geom2d_Curve`.
///
/// `Curve2D` wraps the full OpenCASCADE `Geom2d` package polymorphically:
/// lines, segments, circles, arcs, ellipses, parabolas, hyperbolas,
/// B-splines, and Bezier curves are all represented by this single type.
///
/// ## Creating Curves
///
/// ```swift
/// let segment = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 5))
/// let circle = Curve2D.circle(center: .zero, radius: 5)
/// let arc = Curve2D.arcOfCircle(center: .zero, radius: 5,
///                               startAngle: 0, endAngle: .pi / 2)
/// ```
///
/// ## Discretizing for Metal Rendering
///
/// ```swift
/// let polyline = circle!.drawAdaptive()  // → [SIMD2<Double>]
/// let uniform  = circle!.drawUniform(pointCount: 64)
/// ```
public final class Curve2D: @unchecked Sendable {
    internal let handle: OCCTCurve2DRef

    internal init(handle: OCCTCurve2DRef) {
        self.handle = handle
    }

    deinit {
        OCCTCurve2DRelease(handle)
    }

    // MARK: - Properties

    /// The parameter domain of the curve as a closed range `[first, last]`.
    public var domain: ClosedRange<Double> {
        var first: Double = 0
        var last: Double = 0
        OCCTCurve2DGetDomain(handle, &first, &last)
        return first...last
    }

    /// Whether the curve forms a closed loop.
    public var isClosed: Bool {
        OCCTCurve2DIsClosed(handle)
    }

    /// Whether the curve is periodic (e.g. a full circle or ellipse).
    public var isPeriodic: Bool {
        OCCTCurve2DIsPeriodic(handle)
    }

    /// The period of the curve, or `nil` if the curve is not periodic.
    public var period: Double? {
        guard isPeriodic else { return nil }
        return OCCTCurve2DGetPeriod(handle)
    }

    /// The point at the start of the parameter domain.
    public var startPoint: SIMD2<Double> {
        point(at: domain.lowerBound)
    }

    /// The point at the end of the parameter domain.
    public var endPoint: SIMD2<Double> {
        point(at: domain.upperBound)
    }

    // MARK: - Evaluation

    /// Evaluate the curve position at parameter `u`.
    public func point(at u: Double) -> SIMD2<Double> {
        var x: Double = 0, y: Double = 0
        OCCTCurve2DGetPoint(handle, u, &x, &y)
        return SIMD2(x, y)
    }

    /// Evaluate position and first derivative (tangent) at parameter `u`.
    public func d1(at u: Double) -> (point: SIMD2<Double>, tangent: SIMD2<Double>) {
        var px: Double = 0, py: Double = 0
        var vx: Double = 0, vy: Double = 0
        OCCTCurve2DD1(handle, u, &px, &py, &vx, &vy)
        return (SIMD2(px, py), SIMD2(vx, vy))
    }

    /// Evaluate position, first derivative, and second derivative at parameter `u`.
    public func d2(at u: Double) -> (point: SIMD2<Double>, d1: SIMD2<Double>, d2: SIMD2<Double>) {
        var px: Double = 0, py: Double = 0
        var v1x: Double = 0, v1y: Double = 0
        var v2x: Double = 0, v2y: Double = 0
        OCCTCurve2DD2(handle, u, &px, &py, &v1x, &v1y, &v2x, &v2y)
        return (SIMD2(px, py), SIMD2(v1x, v1y), SIMD2(v2x, v2y))
    }

    // MARK: - Primitive Curves

    /// Create an infinite line through a point in a given direction.
    public static func line(through point: SIMD2<Double>, direction: SIMD2<Double>) -> Curve2D? {
        guard let h = OCCTCurve2DCreateLine(point.x, point.y, direction.x, direction.y) else { return nil }
        return Curve2D(handle: h)
    }

    /// Create a line segment between two points.
    public static func segment(from p1: SIMD2<Double>, to p2: SIMD2<Double>) -> Curve2D? {
        guard let h = OCCTCurve2DCreateSegment(p1.x, p1.y, p2.x, p2.y) else { return nil }
        return Curve2D(handle: h)
    }

    /// Create a full circle.
    public static func circle(center: SIMD2<Double>, radius: Double) -> Curve2D? {
        guard let h = OCCTCurve2DCreateCircle(center.x, center.y, radius) else { return nil }
        return Curve2D(handle: h)
    }

    /// Create an arc of a circle between two angles (in radians).
    public static func arcOfCircle(center: SIMD2<Double>, radius: Double,
                                   startAngle: Double, endAngle: Double) -> Curve2D? {
        guard let h = OCCTCurve2DCreateArcOfCircle(center.x, center.y, radius,
                                                    startAngle, endAngle) else { return nil }
        return Curve2D(handle: h)
    }

    /// Create a circular arc passing through three points.
    public static func arcThrough(_ p1: SIMD2<Double>, _ p2: SIMD2<Double>,
                                  _ p3: SIMD2<Double>) -> Curve2D? {
        guard let h = OCCTCurve2DCreateArcThrough(p1.x, p1.y, p2.x, p2.y,
                                                   p3.x, p3.y) else { return nil }
        return Curve2D(handle: h)
    }

    /// Create a full ellipse.
    /// - Parameters:
    ///   - center: Center point
    ///   - majorRadius: Semi-major axis length (must be >= minorRadius)
    ///   - minorRadius: Semi-minor axis length
    ///   - rotation: Rotation of the major axis from the X axis (radians)
    public static func ellipse(center: SIMD2<Double>, majorRadius: Double,
                               minorRadius: Double, rotation: Double = 0) -> Curve2D? {
        guard let h = OCCTCurve2DCreateEllipse(center.x, center.y,
                                                majorRadius, minorRadius, rotation) else { return nil }
        return Curve2D(handle: h)
    }

    /// Create an arc of an ellipse between two angles.
    public static func arcOfEllipse(center: SIMD2<Double>, majorRadius: Double,
                                    minorRadius: Double, rotation: Double = 0,
                                    startAngle: Double, endAngle: Double) -> Curve2D? {
        guard let h = OCCTCurve2DCreateArcOfEllipse(center.x, center.y,
                                                     majorRadius, minorRadius, rotation,
                                                     startAngle, endAngle) else { return nil }
        return Curve2D(handle: h)
    }

    /// Create a parabola.
    /// - Parameters:
    ///   - focus: Focus point of the parabola
    ///   - direction: Axis direction (from vertex toward focus)
    ///   - focalLength: Distance from vertex to focus
    public static func parabola(focus: SIMD2<Double>, direction: SIMD2<Double>,
                                focalLength: Double) -> Curve2D? {
        guard let h = OCCTCurve2DCreateParabola(focus.x, focus.y,
                                                 direction.x, direction.y,
                                                 focalLength) else { return nil }
        return Curve2D(handle: h)
    }

    /// Create a hyperbola.
    public static func hyperbola(center: SIMD2<Double>, majorRadius: Double,
                                 minorRadius: Double, rotation: Double = 0) -> Curve2D? {
        guard let h = OCCTCurve2DCreateHyperbola(center.x, center.y,
                                                  majorRadius, minorRadius, rotation) else { return nil }
        return Curve2D(handle: h)
    }

    // MARK: - Draw (Discretization for Metal)

    /// Adaptively discretize the curve using angular and chordal deflection criteria.
    ///
    /// Produces more points where curvature is high and fewer where the curve is straight.
    /// - Parameters:
    ///   - angularDeflection: Maximum angular deflection in radians (default 0.1)
    ///   - chordalDeflection: Maximum chordal deflection (default 0.01)
    ///   - maxPoints: Maximum number of output points (default 4096)
    /// - Returns: Array of 2D points approximating the curve
    public func drawAdaptive(angularDeflection: Double = 0.1,
                             chordalDeflection: Double = 0.01,
                             maxPoints: Int = 4096) -> [SIMD2<Double>] {
        var buffer = [Double](repeating: 0, count: maxPoints * 2)
        let n = Int(OCCTCurve2DDrawAdaptive(handle, angularDeflection, chordalDeflection,
                                            &buffer, Int32(maxPoints)))
        return (0..<n).map { SIMD2(buffer[$0 * 2], buffer[$0 * 2 + 1]) }
    }

    /// Discretize the curve with exactly `pointCount` uniformly-spaced-by-arc-length points.
    public func drawUniform(pointCount: Int) -> [SIMD2<Double>] {
        var buffer = [Double](repeating: 0, count: pointCount * 2)
        let n = Int(OCCTCurve2DDrawUniform(handle, Int32(pointCount), &buffer))
        return (0..<n).map { SIMD2(buffer[$0 * 2], buffer[$0 * 2 + 1]) }
    }

    /// Discretize the curve with a maximum chordal deflection.
    public func drawDeflection(deflection: Double = 0.01,
                               maxPoints: Int = 4096) -> [SIMD2<Double>] {
        var buffer = [Double](repeating: 0, count: maxPoints * 2)
        let n = Int(OCCTCurve2DDrawDeflection(handle, deflection, &buffer, Int32(maxPoints)))
        return (0..<n).map { SIMD2(buffer[$0 * 2], buffer[$0 * 2 + 1]) }
    }

    // MARK: - BSpline & Bezier

    /// Create a B-spline curve from control points, knots, and multiplicities.
    public static func bspline(poles: [SIMD2<Double>], weights: [Double]? = nil,
                               knots: [Double], multiplicities: [Int32],
                               degree: Int) -> Curve2D? {
        let flatPoles = poles.flatMap { [$0.x, $0.y] }
        let h = flatPoles.withUnsafeBufferPointer { polesPtr in
            knots.withUnsafeBufferPointer { knotsPtr in
                multiplicities.withUnsafeBufferPointer { multsPtr in
                    if let w = weights {
                        return w.withUnsafeBufferPointer { wPtr in
                            OCCTCurve2DCreateBSpline(polesPtr.baseAddress, Int32(poles.count),
                                                     wPtr.baseAddress,
                                                     knotsPtr.baseAddress, Int32(knots.count),
                                                     multsPtr.baseAddress, Int32(degree))
                        }
                    } else {
                        return OCCTCurve2DCreateBSpline(polesPtr.baseAddress, Int32(poles.count),
                                                        nil,
                                                        knotsPtr.baseAddress, Int32(knots.count),
                                                        multsPtr.baseAddress, Int32(degree))
                    }
                }
            }
        }
        guard let h = h else { return nil }
        return Curve2D(handle: h)
    }

    /// Create a Bezier curve from control points with optional weights.
    public static func bezier(poles: [SIMD2<Double>], weights: [Double]? = nil) -> Curve2D? {
        let flatPoles = poles.flatMap { [$0.x, $0.y] }
        let h: OCCTCurve2DRef?
        if let w = weights {
            h = flatPoles.withUnsafeBufferPointer { pp in
                w.withUnsafeBufferPointer { wp in
                    OCCTCurve2DCreateBezier(pp.baseAddress, Int32(poles.count), wp.baseAddress)
                }
            }
        } else {
            h = flatPoles.withUnsafeBufferPointer { pp in
                OCCTCurve2DCreateBezier(pp.baseAddress, Int32(poles.count), nil)
            }
        }
        guard let h = h else { return nil }
        return Curve2D(handle: h)
    }

    /// Interpolate a smooth B-spline curve through the given points.
    public static func interpolate(through points: [SIMD2<Double>], closed: Bool = false,
                                   tolerance: Double = 1e-6) -> Curve2D? {
        let flat = points.flatMap { [$0.x, $0.y] }
        guard let h = flat.withUnsafeBufferPointer({ ptr in
            OCCTCurve2DInterpolate(ptr.baseAddress, Int32(points.count), closed, tolerance)
        }) else { return nil }
        return Curve2D(handle: h)
    }

    /// Interpolate through points with specified start and end tangents.
    public static func interpolate(through points: [SIMD2<Double>],
                                   startTangent: SIMD2<Double>,
                                   endTangent: SIMD2<Double>,
                                   tolerance: Double = 1e-6) -> Curve2D? {
        let flat = points.flatMap { [$0.x, $0.y] }
        guard let h = flat.withUnsafeBufferPointer({ ptr in
            OCCTCurve2DInterpolateWithTangents(ptr.baseAddress, Int32(points.count),
                                               startTangent.x, startTangent.y,
                                               endTangent.x, endTangent.y, tolerance)
        }) else { return nil }
        return Curve2D(handle: h)
    }

    /// Approximate a B-spline curve fitting through points within tolerance.
    public static func fit(through points: [SIMD2<Double>], minDegree: Int = 3,
                           maxDegree: Int = 8, tolerance: Double = 1e-3) -> Curve2D? {
        let flat = points.flatMap { [$0.x, $0.y] }
        guard let h = flat.withUnsafeBufferPointer({ ptr in
            OCCTCurve2DFitPoints(ptr.baseAddress, Int32(points.count),
                                 Int32(minDegree), Int32(maxDegree), tolerance)
        }) else { return nil }
        return Curve2D(handle: h)
    }

    // MARK: - BSpline Queries

    /// The number of control points (poles), or `nil` if not a BSpline/Bezier.
    public var poleCount: Int? {
        let n = Int(OCCTCurve2DGetPoleCount(handle))
        return n > 0 ? n : nil
    }

    /// The control points (poles), or `nil` if not a BSpline/Bezier.
    public var poles: [SIMD2<Double>]? {
        guard let count = poleCount else { return nil }
        var buffer = [Double](repeating: 0, count: count * 2)
        let n = Int(OCCTCurve2DGetPoles(handle, &buffer))
        guard n > 0 else { return nil }
        return (0..<n).map { SIMD2(buffer[$0 * 2], buffer[$0 * 2 + 1]) }
    }

    /// The curve degree, or `nil` if not a BSpline/Bezier.
    public var degree: Int? {
        let d = Int(OCCTCurve2DGetDegree(handle))
        return d >= 0 ? d : nil
    }

    // MARK: - Operations

    /// Create a trimmed copy of this curve between parameters `from` and `to`.
    public func trimmed(from u1: Double, to u2: Double) -> Curve2D? {
        guard let h = OCCTCurve2DTrim(handle, u1, u2) else { return nil }
        return Curve2D(handle: h)
    }

    /// Create an offset curve at the given distance.
    /// Positive distance offsets to the left of the curve direction.
    public func offset(by distance: Double) -> Curve2D? {
        guard let h = OCCTCurve2DOffset(handle, distance) else { return nil }
        return Curve2D(handle: h)
    }

    /// Create a reversed copy of this curve (parameter direction flipped).
    public func reversed() -> Curve2D? {
        guard let h = OCCTCurve2DReversed(handle) else { return nil }
        return Curve2D(handle: h)
    }

    /// Create a translated copy of this curve.
    public func translated(by delta: SIMD2<Double>) -> Curve2D? {
        guard let h = OCCTCurve2DTranslate(handle, delta.x, delta.y) else { return nil }
        return Curve2D(handle: h)
    }

    /// Create a rotated copy of this curve.
    public func rotated(around center: SIMD2<Double>, angle: Double) -> Curve2D? {
        guard let h = OCCTCurve2DRotate(handle, center.x, center.y, angle) else { return nil }
        return Curve2D(handle: h)
    }

    /// Create a scaled copy of this curve.
    public func scaled(from center: SIMD2<Double>, factor: Double) -> Curve2D? {
        guard let h = OCCTCurve2DScale(handle, center.x, center.y, factor) else { return nil }
        return Curve2D(handle: h)
    }

    /// Create a copy mirrored across an axis line.
    public func mirrored(acrossLine point: SIMD2<Double>, direction: SIMD2<Double>) -> Curve2D? {
        guard let h = OCCTCurve2DMirrorAxis(handle, point.x, point.y,
                                             direction.x, direction.y) else { return nil }
        return Curve2D(handle: h)
    }

    /// Create a copy mirrored across a point.
    public func mirrored(acrossPoint point: SIMD2<Double>) -> Curve2D? {
        guard let h = OCCTCurve2DMirrorPoint(handle, point.x, point.y) else { return nil }
        return Curve2D(handle: h)
    }

    /// The total arc length of the curve, or `nil` on error.
    public var length: Double? {
        let l = OCCTCurve2DGetLength(handle)
        return l >= 0 ? l : nil
    }

    /// Arc length between two parameter values.
    public func length(from u1: Double, to u2: Double) -> Double? {
        let l = OCCTCurve2DGetLengthBetween(handle, u1, u2)
        return l >= 0 ? l : nil
    }

    // MARK: - Analysis

    /// Find intersection points between this curve and another.
    public func intersections(with other: Curve2D, tolerance: Double = 1e-6) -> [Curve2DIntersection] {
        var buffer = [OCCTCurve2DIntersection](repeating: OCCTCurve2DIntersection(), count: 128)
        let n = Int(OCCTCurve2DIntersect(handle, other.handle, tolerance, &buffer, 128))
        return (0..<n).map {
            Curve2DIntersection(point: SIMD2(buffer[$0].x, buffer[$0].y),
                                parameter1: buffer[$0].u1, parameter2: buffer[$0].u2)
        }
    }

    /// Find self-intersection points of this curve.
    public func selfIntersections(tolerance: Double = 1e-6) -> [Curve2DIntersection] {
        var buffer = [OCCTCurve2DIntersection](repeating: OCCTCurve2DIntersection(), count: 128)
        let n = Int(OCCTCurve2DSelfIntersect(handle, tolerance, &buffer, 128))
        return (0..<n).map {
            Curve2DIntersection(point: SIMD2(buffer[$0].x, buffer[$0].y),
                                parameter1: buffer[$0].u1, parameter2: buffer[$0].u2)
        }
    }

    /// Project a point onto this curve, returning the nearest projection.
    public func project(point p: SIMD2<Double>) -> Curve2DProjection? {
        let r = OCCTCurve2DProjectPoint(handle, p.x, p.y)
        guard r.distance >= 0 else { return nil }
        return Curve2DProjection(point: SIMD2(r.x, r.y), parameter: r.parameter, distance: r.distance)
    }

    /// Project a point onto this curve, returning all projections.
    public func allProjections(of p: SIMD2<Double>) -> [Curve2DProjection] {
        var buffer = [OCCTCurve2DProjection](repeating: OCCTCurve2DProjection(), count: 64)
        let n = Int(OCCTCurve2DProjectPointAll(handle, p.x, p.y, &buffer, 64))
        return (0..<n).map {
            Curve2DProjection(point: SIMD2(buffer[$0].x, buffer[$0].y),
                              parameter: buffer[$0].parameter, distance: buffer[$0].distance)
        }
    }

    /// Find the minimum distance between this curve and another.
    public func minDistance(to other: Curve2D) -> Curve2DExtremaResult? {
        let r = OCCTCurve2DMinDistance(handle, other.handle)
        guard r.distance >= 0 else { return nil }
        return Curve2DExtremaResult(pointOnCurve1: SIMD2(r.p1x, r.p1y),
                                    pointOnCurve2: SIMD2(r.p2x, r.p2y),
                                    parameter1: r.u1, parameter2: r.u2,
                                    distance: r.distance)
    }

    /// Find all extrema (local min/max distances) between this curve and another.
    public func allExtrema(with other: Curve2D) -> [Curve2DExtremaResult] {
        var buffer = [OCCTCurve2DExtrema](repeating: OCCTCurve2DExtrema(), count: 64)
        let n = Int(OCCTCurve2DAllExtrema(handle, other.handle, &buffer, 64))
        return (0..<n).map {
            Curve2DExtremaResult(pointOnCurve1: SIMD2(buffer[$0].p1x, buffer[$0].p1y),
                                 pointOnCurve2: SIMD2(buffer[$0].p2x, buffer[$0].p2y),
                                 parameter1: buffer[$0].u1, parameter2: buffer[$0].u2,
                                 distance: buffer[$0].distance)
        }
    }

    // MARK: - Conversion

    /// Convert this curve to an equivalent B-spline representation.
    public func toBSpline(tolerance: Double = 1e-6) -> Curve2D? {
        guard let h = OCCTCurve2DToBSpline(handle, tolerance) else { return nil }
        return Curve2D(handle: h)
    }

    /// Split a B-spline curve into its constituent Bezier segments.
    public func toBezierSegments() -> [Curve2D]? {
        var buffer = [OCCTCurve2DRef?](repeating: nil, count: 64)
        let n = Int(buffer.withUnsafeMutableBufferPointer { ptr in
            OCCTCurve2DBSplineToBeziers(handle, ptr.baseAddress, 64)
        })
        guard n > 0 else { return nil }
        return (0..<n).compactMap { i in
            guard let h = buffer[i] else { return nil }
            return Curve2D(handle: h)
        }
    }

    /// Join multiple curves into a single B-spline.
    public static func join(_ curves: [Curve2D], tolerance: Double = 1e-6) -> Curve2D? {
        let handles = curves.map { $0.handle as OCCTCurve2DRef? }
        let h = handles.withUnsafeBufferPointer { ptr in
            OCCTCurve2DJoinToBSpline(ptr.baseAddress, Int32(curves.count), tolerance)
        }
        guard let h = h else { return nil }
        return Curve2D(handle: h)
    }
}

// MARK: - Result Types

/// An intersection point between two 2D curves.
public struct Curve2DIntersection: Sendable {
    /// The intersection point in 2D space.
    public let point: SIMD2<Double>
    /// Parameter on the first curve at the intersection.
    public let parameter1: Double
    /// Parameter on the second curve at the intersection.
    public let parameter2: Double
}

/// A projection of a point onto a 2D curve.
public struct Curve2DProjection: Sendable {
    /// The projected point on the curve.
    public let point: SIMD2<Double>
    /// The curve parameter at the projected point.
    public let parameter: Double
    /// The distance from the original point to the projected point.
    public let distance: Double
}

/// A distance extremum between two 2D curves.
public struct Curve2DExtremaResult: Sendable {
    /// The point on the first curve at the extremum.
    public let pointOnCurve1: SIMD2<Double>
    /// The point on the second curve at the extremum.
    public let pointOnCurve2: SIMD2<Double>
    /// Parameter on the first curve.
    public let parameter1: Double
    /// Parameter on the second curve.
    public let parameter2: Double
    /// The distance between the two points.
    public let distance: Double
}
