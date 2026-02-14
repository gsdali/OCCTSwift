import Foundation
import simd
import OCCTBridge

/// A 3D parametric curve backed by OpenCASCADE Handle(Geom_Curve).
///
/// Mirrors the Curve2D API for 3D space. Wraps lines, circles, ellipses, arcs,
/// BSplines, Bezier curves, and trimmed/offset curves polymorphically.
public final class Curve3D: @unchecked Sendable {
    internal let handle: OCCTCurve3DRef

    internal init(handle: OCCTCurve3DRef) {
        self.handle = handle
    }

    deinit {
        OCCTCurve3DRelease(handle)
    }

    // MARK: - Properties

    /// Parameter domain [first, last]
    public var domain: ClosedRange<Double> {
        var first: Double = 0, last: Double = 0
        OCCTCurve3DGetDomain(handle, &first, &last)
        return first...last
    }

    /// Whether the curve forms a closed loop
    public var isClosed: Bool {
        OCCTCurve3DIsClosed(handle)
    }

    /// Whether the curve is periodic (repeats)
    public var isPeriodic: Bool {
        OCCTCurve3DIsPeriodic(handle)
    }

    /// Period of the curve (nil if not periodic)
    public var period: Double? {
        guard isPeriodic else { return nil }
        return OCCTCurve3DGetPeriod(handle)
    }

    /// Point at start of domain
    public var startPoint: SIMD3<Double> {
        point(at: domain.lowerBound)
    }

    /// Point at end of domain
    public var endPoint: SIMD3<Double> {
        point(at: domain.upperBound)
    }

    // MARK: - Evaluation

    /// Evaluate point at parameter u
    public func point(at u: Double) -> SIMD3<Double> {
        var x: Double = 0, y: Double = 0, z: Double = 0
        OCCTCurve3DGetPoint(handle, u, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// First derivative: point and tangent vector at parameter u
    public func d1(at u: Double) -> (point: SIMD3<Double>, tangent: SIMD3<Double>) {
        var px: Double = 0, py: Double = 0, pz: Double = 0
        var vx: Double = 0, vy: Double = 0, vz: Double = 0
        OCCTCurve3DD1(handle, u, &px, &py, &pz, &vx, &vy, &vz)
        return (SIMD3(px, py, pz), SIMD3(vx, vy, vz))
    }

    /// Second derivative: point, first and second derivative vectors
    public func d2(at u: Double) -> (point: SIMD3<Double>, d1: SIMD3<Double>, d2: SIMD3<Double>) {
        var px: Double = 0, py: Double = 0, pz: Double = 0
        var v1x: Double = 0, v1y: Double = 0, v1z: Double = 0
        var v2x: Double = 0, v2y: Double = 0, v2z: Double = 0
        OCCTCurve3DD2(handle, u, &px, &py, &pz, &v1x, &v1y, &v1z, &v2x, &v2y, &v2z)
        return (SIMD3(px, py, pz), SIMD3(v1x, v1y, v1z), SIMD3(v2x, v2y, v2z))
    }

    // MARK: - Primitive Curves

    /// Infinite line through a point in a direction
    public static func line(through point: SIMD3<Double>, direction: SIMD3<Double>) -> Curve3D? {
        guard let h = OCCTCurve3DCreateLine(point.x, point.y, point.z,
                                             direction.x, direction.y, direction.z) else { return nil }
        return Curve3D(handle: h)
    }

    /// Line segment between two points
    public static func segment(from p1: SIMD3<Double>, to p2: SIMD3<Double>) -> Curve3D? {
        guard let h = OCCTCurve3DCreateSegment(p1.x, p1.y, p1.z,
                                                p2.x, p2.y, p2.z) else { return nil }
        return Curve3D(handle: h)
    }

    /// Full circle in a plane defined by center and normal
    public static func circle(center: SIMD3<Double>, normal: SIMD3<Double>, radius: Double) -> Curve3D? {
        guard let h = OCCTCurve3DCreateCircle(center.x, center.y, center.z,
                                               normal.x, normal.y, normal.z,
                                               radius) else { return nil }
        return Curve3D(handle: h)
    }

    /// Circular arc through three points (start, interior, end)
    public static func arcOfCircle(start: SIMD3<Double>, interior: SIMD3<Double>, end: SIMD3<Double>) -> Curve3D? {
        guard let h = OCCTCurve3DCreateArcOfCircle(start.x, start.y, start.z,
                                                    interior.x, interior.y, interior.z,
                                                    end.x, end.y, end.z) else { return nil }
        return Curve3D(handle: h)
    }

    /// Circular arc through three points (alias)
    public static func arc(through p1: SIMD3<Double>, _ pm: SIMD3<Double>, _ p2: SIMD3<Double>) -> Curve3D? {
        guard let h = OCCTCurve3DCreateArc3Points(p1.x, p1.y, p1.z,
                                                   pm.x, pm.y, pm.z,
                                                   p2.x, p2.y, p2.z) else { return nil }
        return Curve3D(handle: h)
    }

    /// Ellipse in a plane defined by center and normal
    public static func ellipse(center: SIMD3<Double>, normal: SIMD3<Double>,
                               majorRadius: Double, minorRadius: Double) -> Curve3D? {
        guard let h = OCCTCurve3DCreateEllipse(center.x, center.y, center.z,
                                                normal.x, normal.y, normal.z,
                                                majorRadius, minorRadius) else { return nil }
        return Curve3D(handle: h)
    }

    /// Parabola in a plane defined by center/normal with given focal length
    public static func parabola(center: SIMD3<Double>, normal: SIMD3<Double>,
                                focal: Double) -> Curve3D? {
        guard let h = OCCTCurve3DCreateParabola(center.x, center.y, center.z,
                                                 normal.x, normal.y, normal.z,
                                                 focal) else { return nil }
        return Curve3D(handle: h)
    }

    /// Hyperbola in a plane defined by center/normal
    public static func hyperbola(center: SIMD3<Double>, normal: SIMD3<Double>,
                                 majorRadius: Double, minorRadius: Double) -> Curve3D? {
        guard let h = OCCTCurve3DCreateHyperbola(center.x, center.y, center.z,
                                                  normal.x, normal.y, normal.z,
                                                  majorRadius, minorRadius) else { return nil }
        return Curve3D(handle: h)
    }

    // MARK: - BSpline & Bezier

    /// Create a BSpline curve from poles, knots, and multiplicities
    public static func bspline(poles: [SIMD3<Double>], weights: [Double]? = nil,
                               knots: [Double], multiplicities: [Int32],
                               degree: Int) -> Curve3D? {
        let flatPoles = poles.flatMap { [$0.x, $0.y, $0.z] }
        let h = flatPoles.withUnsafeBufferPointer { polesPtr in
            knots.withUnsafeBufferPointer { knotsPtr in
                multiplicities.withUnsafeBufferPointer { multsPtr in
                    if let w = weights {
                        return w.withUnsafeBufferPointer { wPtr in
                            OCCTCurve3DCreateBSpline(polesPtr.baseAddress, Int32(poles.count),
                                                      wPtr.baseAddress,
                                                      knotsPtr.baseAddress, Int32(knots.count),
                                                      multsPtr.baseAddress, Int32(degree))
                        }
                    } else {
                        return OCCTCurve3DCreateBSpline(polesPtr.baseAddress, Int32(poles.count),
                                                         nil,
                                                         knotsPtr.baseAddress, Int32(knots.count),
                                                         multsPtr.baseAddress, Int32(degree))
                    }
                }
            }
        }
        guard let h = h else { return nil }
        return Curve3D(handle: h)
    }

    /// Create a Bezier curve from control points
    public static func bezier(poles: [SIMD3<Double>], weights: [Double]? = nil) -> Curve3D? {
        let flatPoles = poles.flatMap { [$0.x, $0.y, $0.z] }
        let h: OCCTCurve3DRef?
        if let w = weights {
            h = flatPoles.withUnsafeBufferPointer { pp in
                w.withUnsafeBufferPointer { wp in
                    OCCTCurve3DCreateBezier(pp.baseAddress, Int32(poles.count), wp.baseAddress)
                }
            }
        } else {
            h = flatPoles.withUnsafeBufferPointer { pp in
                OCCTCurve3DCreateBezier(pp.baseAddress, Int32(poles.count), nil)
            }
        }
        guard let h = h else { return nil }
        return Curve3D(handle: h)
    }

    /// Interpolate through 3D points
    public static func interpolate(points: [SIMD3<Double>], closed: Bool = false,
                                   tolerance: Double = 1e-6) -> Curve3D? {
        let flat = points.flatMap { [$0.x, $0.y, $0.z] }
        let h = flat.withUnsafeBufferPointer { ptr in
            OCCTCurve3DInterpolate(ptr.baseAddress, Int32(points.count), closed, tolerance)
        }
        guard let h = h else { return nil }
        return Curve3D(handle: h)
    }

    /// Interpolate through points with start/end tangent constraints
    public static func interpolate(points: [SIMD3<Double>],
                                   startTangent: SIMD3<Double>,
                                   endTangent: SIMD3<Double>,
                                   tolerance: Double = 1e-6) -> Curve3D? {
        let flat = points.flatMap { [$0.x, $0.y, $0.z] }
        let h = flat.withUnsafeBufferPointer { ptr in
            OCCTCurve3DInterpolateWithTangents(ptr.baseAddress, Int32(points.count),
                                                startTangent.x, startTangent.y, startTangent.z,
                                                endTangent.x, endTangent.y, endTangent.z,
                                                tolerance)
        }
        guard let h = h else { return nil }
        return Curve3D(handle: h)
    }

    /// Fit a BSpline curve through points (least-squares approximation)
    public static func fit(points: [SIMD3<Double>], minDegree: Int = 3, maxDegree: Int = 8,
                           tolerance: Double = 1e-3) -> Curve3D? {
        let flat = points.flatMap { [$0.x, $0.y, $0.z] }
        let h = flat.withUnsafeBufferPointer { ptr in
            OCCTCurve3DFitPoints(ptr.baseAddress, Int32(points.count),
                                  Int32(minDegree), Int32(maxDegree), tolerance)
        }
        guard let h = h else { return nil }
        return Curve3D(handle: h)
    }

    // MARK: - BSpline Queries

    /// Number of poles (control points) for BSpline/Bezier curves
    public var poleCount: Int {
        Int(OCCTCurve3DGetPoleCount(handle))
    }

    /// Get poles (control points) for BSpline/Bezier curves
    public var poles: [SIMD3<Double>]? {
        let n = poleCount
        guard n > 0 else { return nil }
        var buffer = [Double](repeating: 0, count: n * 3)
        let actual = Int(OCCTCurve3DGetPoles(handle, &buffer))
        guard actual > 0 else { return nil }
        return (0..<actual).map { SIMD3(buffer[$0*3], buffer[$0*3+1], buffer[$0*3+2]) }
    }

    /// Degree of BSpline/Bezier curve (-1 if not applicable)
    public var degree: Int {
        Int(OCCTCurve3DGetDegree(handle))
    }

    // MARK: - Operations

    /// Trim curve to parameter range [u1, u2]
    public func trimmed(from u1: Double, to u2: Double) -> Curve3D? {
        guard let h = OCCTCurve3DTrim(handle, u1, u2) else { return nil }
        return Curve3D(handle: h)
    }

    /// Reverse curve parameterization
    public func reversed() -> Curve3D? {
        guard let h = OCCTCurve3DReversed(handle) else { return nil }
        return Curve3D(handle: h)
    }

    /// Translate curve by a displacement vector
    public func translated(by delta: SIMD3<Double>) -> Curve3D? {
        guard let h = OCCTCurve3DTranslate(handle, delta.x, delta.y, delta.z) else { return nil }
        return Curve3D(handle: h)
    }

    /// Rotate curve around an axis
    public func rotated(around axisOrigin: SIMD3<Double>, direction: SIMD3<Double>,
                        angle: Double) -> Curve3D? {
        guard let h = OCCTCurve3DRotate(handle,
                                         axisOrigin.x, axisOrigin.y, axisOrigin.z,
                                         direction.x, direction.y, direction.z,
                                         angle) else { return nil }
        return Curve3D(handle: h)
    }

    /// Scale curve from a center point
    public func scaled(from center: SIMD3<Double>, factor: Double) -> Curve3D? {
        guard let h = OCCTCurve3DScale(handle, center.x, center.y, center.z,
                                        factor) else { return nil }
        return Curve3D(handle: h)
    }

    /// Mirror curve across a point
    public func mirrored(acrossPoint point: SIMD3<Double>) -> Curve3D? {
        guard let h = OCCTCurve3DMirrorPoint(handle, point.x, point.y, point.z) else { return nil }
        return Curve3D(handle: h)
    }

    /// Mirror curve across an axis (line)
    public func mirrored(acrossAxis point: SIMD3<Double>, direction: SIMD3<Double>) -> Curve3D? {
        guard let h = OCCTCurve3DMirrorAxis(handle, point.x, point.y, point.z,
                                             direction.x, direction.y, direction.z) else { return nil }
        return Curve3D(handle: h)
    }

    /// Mirror curve across a plane
    public func mirrored(acrossPlane point: SIMD3<Double>, normal: SIMD3<Double>) -> Curve3D? {
        guard let h = OCCTCurve3DMirrorPlane(handle, point.x, point.y, point.z,
                                              normal.x, normal.y, normal.z) else { return nil }
        return Curve3D(handle: h)
    }

    /// Arc length of the full curve
    public var length: Double? {
        let l = OCCTCurve3DGetLength(handle)
        return l >= 0 ? l : nil
    }

    /// Arc length between two parameters
    public func length(from u1: Double, to u2: Double) -> Double? {
        let l = OCCTCurve3DGetLengthBetween(handle, u1, u2)
        return l >= 0 ? l : nil
    }

    // MARK: - Conversion (GeomConvert)

    /// Convert to BSpline representation
    public func toBSpline() -> Curve3D? {
        guard let h = OCCTCurve3DToBSpline(handle) else { return nil }
        return Curve3D(handle: h)
    }

    /// Split BSpline into Bezier segments
    public func toBezierSegments() -> [Curve3D]? {
        var buffer = [OCCTCurve3DRef?](repeating: nil, count: 128)
        let n = buffer.withUnsafeMutableBufferPointer { ptr in
            OCCTCurve3DBSplineToBeziers(handle, ptr.baseAddress, 128)
        }
        guard n > 0 else { return nil }
        var result = [Curve3D]()
        for i in 0..<Int(n) {
            if let h = buffer[i] {
                result.append(Curve3D(handle: h))
            }
        }
        return result.isEmpty ? nil : result
    }

    /// Join multiple curves into a single BSpline
    public static func join(_ curves: [Curve3D], tolerance: Double = 1e-6) -> Curve3D? {
        let handles: [OCCTCurve3DRef?] = curves.map { $0.handle }
        let h = handles.withUnsafeBufferPointer { ptr in
            OCCTCurve3DJoinToBSpline(ptr.baseAddress, Int32(curves.count), tolerance)
        }
        guard let h = h else { return nil }
        return Curve3D(handle: h)
    }

    /// Approximate the curve with a BSpline of specified continuity
    public func approximated(tolerance: Double = 1e-3, continuity: Int = 2,
                             maxSegments: Int = 100, maxDegree: Int = 8) -> Curve3D? {
        guard let h = OCCTCurve3DApproximate(handle, tolerance, Int32(continuity),
                                              Int32(maxSegments), Int32(maxDegree)) else { return nil }
        return Curve3D(handle: h)
    }

    // MARK: - Draw (Discretization for Metal)

    /// Adaptive discretization using angular and chordal deflection criteria
    public func drawAdaptive(angularDeflection: Double = 0.1,
                             chordalDeflection: Double = 0.01,
                             maxPoints: Int = 4096) -> [SIMD3<Double>] {
        var buffer = [Double](repeating: 0, count: maxPoints * 3)
        let n = Int(OCCTCurve3DDrawAdaptive(handle, angularDeflection, chordalDeflection,
                                             &buffer, Int32(maxPoints)))
        return (0..<n).map { SIMD3(buffer[$0*3], buffer[$0*3+1], buffer[$0*3+2]) }
    }

    /// Uniform arc-length spacing discretization
    public func drawUniform(pointCount: Int) -> [SIMD3<Double>] {
        var buffer = [Double](repeating: 0, count: pointCount * 3)
        let n = Int(OCCTCurve3DDrawUniform(handle, Int32(pointCount), &buffer))
        return (0..<n).map { SIMD3(buffer[$0*3], buffer[$0*3+1], buffer[$0*3+2]) }
    }

    /// Chordal deflection discretization
    public func drawDeflection(deflection: Double = 0.01,
                               maxPoints: Int = 4096) -> [SIMD3<Double>] {
        var buffer = [Double](repeating: 0, count: maxPoints * 3)
        let n = Int(OCCTCurve3DDrawDeflection(handle, deflection, &buffer, Int32(maxPoints)))
        return (0..<n).map { SIMD3(buffer[$0*3], buffer[$0*3+1], buffer[$0*3+2]) }
    }

    // MARK: - Local Properties

    /// Curvature at parameter u
    public func curvature(at u: Double) -> Double {
        OCCTCurve3DGetCurvature(handle, u)
    }

    /// Unit tangent direction at parameter u
    public func tangentDirection(at u: Double) -> SIMD3<Double>? {
        var tx: Double = 0, ty: Double = 0, tz: Double = 0
        guard OCCTCurve3DGetTangent(handle, u, &tx, &ty, &tz) else { return nil }
        return SIMD3(tx, ty, tz)
    }

    /// Principal normal direction at parameter u
    public func normal(at u: Double) -> SIMD3<Double>? {
        var nx: Double = 0, ny: Double = 0, nz: Double = 0
        guard OCCTCurve3DGetNormal(handle, u, &nx, &ny, &nz) else { return nil }
        return SIMD3(nx, ny, nz)
    }

    /// Center of curvature at parameter u
    public func centerOfCurvature(at u: Double) -> SIMD3<Double>? {
        var cx: Double = 0, cy: Double = 0, cz: Double = 0
        guard OCCTCurve3DGetCenterOfCurvature(handle, u, &cx, &cy, &cz) else { return nil }
        return SIMD3(cx, cy, cz)
    }

    /// Torsion at parameter u (twist out of the osculating plane)
    public func torsion(at u: Double) -> Double {
        OCCTCurve3DGetTorsion(handle, u)
    }

    // MARK: - Bounding Box

    /// Axis-aligned bounding box of the curve
    public var boundingBox: (min: SIMD3<Double>, max: SIMD3<Double>)? {
        var xMin: Double = 0, yMin: Double = 0, zMin: Double = 0
        var xMax: Double = 0, yMax: Double = 0, zMax: Double = 0
        guard OCCTCurve3DGetBoundingBox(handle, &xMin, &yMin, &zMin,
                                         &xMax, &yMax, &zMax) else { return nil }
        return (min: SIMD3(xMin, yMin, zMin), max: SIMD3(xMax, yMax, zMax))
    }

    // MARK: - Projection (v0.22.0)

    /// Project this curve onto a plane along a given direction.
    ///
    /// Uses `GeomProjLib::ProjectOnPlane`. The result is a 3D curve
    /// lying in the target plane.
    /// - Parameters:
    ///   - origin: A point on the target plane
    ///   - normal: Normal direction of the target plane
    ///   - direction: Projection direction (must not be parallel to the plane normal)
    /// - Returns: The projected 3D curve, or nil if projection fails
    public func projectedOnPlane(origin: SIMD3<Double>,
                                  normal: SIMD3<Double>,
                                  direction: SIMD3<Double>) -> Curve3D? {
        guard let h = OCCTCurve3DProjectOnPlane(handle,
                                                 origin.x, origin.y, origin.z,
                                                 normal.x, normal.y, normal.z,
                                                 direction.x, direction.y, direction.z)
        else { return nil }
        return Curve3D(handle: h)
    }
}
