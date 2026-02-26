import Foundation
import simd
import OCCTBridge

/// A parametric surface backed by OpenCASCADE Handle(Geom_Surface).
///
/// Wraps analytic surfaces (plane, cylinder, cone, sphere, torus),
/// swept surfaces (extrusion, revolution), freeform surfaces (Bezier, BSpline),
/// and derived surfaces (trimmed, offset) polymorphically.
public final class Surface: @unchecked Sendable {
    internal let handle: OCCTSurfaceRef

    internal init(handle: OCCTSurfaceRef) {
        self.handle = handle
    }

    deinit {
        OCCTSurfaceRelease(handle)
    }

    // MARK: - Properties

    /// Parameter domain (uMin, uMax, vMin, vMax)
    public var domain: (uMin: Double, uMax: Double, vMin: Double, vMax: Double) {
        var uMin: Double = 0, uMax: Double = 0, vMin: Double = 0, vMax: Double = 0
        OCCTSurfaceGetDomain(handle, &uMin, &uMax, &vMin, &vMax)
        return (uMin, uMax, vMin, vMax)
    }

    /// Whether the surface is closed in U direction
    public var isUClosed: Bool {
        OCCTSurfaceIsUClosed(handle)
    }

    /// Whether the surface is closed in V direction
    public var isVClosed: Bool {
        OCCTSurfaceIsVClosed(handle)
    }

    /// Whether the surface is periodic in U direction
    public var isUPeriodic: Bool {
        OCCTSurfaceIsUPeriodic(handle)
    }

    /// Whether the surface is periodic in V direction
    public var isVPeriodic: Bool {
        OCCTSurfaceIsVPeriodic(handle)
    }

    /// Period in U direction (nil if not periodic)
    public var uPeriod: Double? {
        guard isUPeriodic else { return nil }
        return OCCTSurfaceGetUPeriod(handle)
    }

    /// Period in V direction (nil if not periodic)
    public var vPeriod: Double? {
        guard isVPeriodic else { return nil }
        return OCCTSurfaceGetVPeriod(handle)
    }

    // MARK: - Evaluation

    /// Evaluate surface point at (u, v)
    public func point(atU u: Double, v: Double) -> SIMD3<Double> {
        var x: Double = 0, y: Double = 0, z: Double = 0
        OCCTSurfaceGetPoint(handle, u, v, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// First-order derivatives at (u, v)
    public func d1(atU u: Double, v: Double) -> (point: SIMD3<Double>, du: SIMD3<Double>, dv: SIMD3<Double>) {
        var px: Double = 0, py: Double = 0, pz: Double = 0
        var dux: Double = 0, duy: Double = 0, duz: Double = 0
        var dvx: Double = 0, dvy: Double = 0, dvz: Double = 0
        OCCTSurfaceD1(handle, u, v, &px, &py, &pz, &dux, &duy, &duz, &dvx, &dvy, &dvz)
        return (SIMD3(px, py, pz), SIMD3(dux, duy, duz), SIMD3(dvx, dvy, dvz))
    }

    /// Second-order derivatives at (u, v)
    public func d2(atU u: Double, v: Double) -> (
        point: SIMD3<Double>,
        d1u: SIMD3<Double>, d1v: SIMD3<Double>,
        d2u: SIMD3<Double>, d2v: SIMD3<Double>, d2uv: SIMD3<Double>
    ) {
        var px: Double = 0, py: Double = 0, pz: Double = 0
        var d1ux: Double = 0, d1uy: Double = 0, d1uz: Double = 0
        var d1vx: Double = 0, d1vy: Double = 0, d1vz: Double = 0
        var d2ux: Double = 0, d2uy: Double = 0, d2uz: Double = 0
        var d2vx: Double = 0, d2vy: Double = 0, d2vz: Double = 0
        var d2uvx: Double = 0, d2uvy: Double = 0, d2uvz: Double = 0
        OCCTSurfaceD2(handle, u, v, &px, &py, &pz,
                       &d1ux, &d1uy, &d1uz, &d1vx, &d1vy, &d1vz,
                       &d2ux, &d2uy, &d2uz, &d2vx, &d2vy, &d2vz,
                       &d2uvx, &d2uvy, &d2uvz)
        return (SIMD3(px, py, pz),
                SIMD3(d1ux, d1uy, d1uz), SIMD3(d1vx, d1vy, d1vz),
                SIMD3(d2ux, d2uy, d2uz), SIMD3(d2vx, d2vy, d2vz),
                SIMD3(d2uvx, d2uvy, d2uvz))
    }

    /// Surface normal at (u, v)
    public func normal(atU u: Double, v: Double) -> SIMD3<Double>? {
        var nx: Double = 0, ny: Double = 0, nz: Double = 0
        guard OCCTSurfaceGetNormal(handle, u, v, &nx, &ny, &nz) else { return nil }
        return SIMD3(nx, ny, nz)
    }

    // MARK: - Analytic Surfaces

    /// Create an infinite plane from a point and normal direction
    public static func plane(origin: SIMD3<Double>, normal: SIMD3<Double>) -> Surface? {
        guard let h = OCCTSurfaceCreatePlane(origin.x, origin.y, origin.z,
                                              normal.x, normal.y, normal.z)
        else { return nil }
        return Surface(handle: h)
    }

    /// Create a cylindrical surface
    public static func cylinder(origin: SIMD3<Double>, axis: SIMD3<Double>,
                                radius: Double) -> Surface? {
        guard let h = OCCTSurfaceCreateCylinder(origin.x, origin.y, origin.z,
                                                 axis.x, axis.y, axis.z, radius)
        else { return nil }
        return Surface(handle: h)
    }

    /// Create a conical surface
    public static func cone(origin: SIMD3<Double>, axis: SIMD3<Double>,
                            radius: Double, semiAngle: Double) -> Surface? {
        guard let h = OCCTSurfaceCreateCone(origin.x, origin.y, origin.z,
                                             axis.x, axis.y, axis.z,
                                             radius, semiAngle)
        else { return nil }
        return Surface(handle: h)
    }

    /// Create a spherical surface
    public static func sphere(center: SIMD3<Double>, radius: Double) -> Surface? {
        guard let h = OCCTSurfaceCreateSphere(center.x, center.y, center.z, radius)
        else { return nil }
        return Surface(handle: h)
    }

    /// Create a toroidal surface
    public static func torus(origin: SIMD3<Double>, axis: SIMD3<Double>,
                             majorRadius: Double, minorRadius: Double) -> Surface? {
        guard let h = OCCTSurfaceCreateTorus(origin.x, origin.y, origin.z,
                                              axis.x, axis.y, axis.z,
                                              majorRadius, minorRadius)
        else { return nil }
        return Surface(handle: h)
    }

    // MARK: - Swept Surfaces

    /// Create a surface by extruding a curve along a direction
    public static func extrusion(profile: Curve3D, direction: SIMD3<Double>) -> Surface? {
        guard let h = OCCTSurfaceCreateExtrusion(profile.handle,
                                                  direction.x, direction.y, direction.z)
        else { return nil }
        return Surface(handle: h)
    }

    /// Create a surface of revolution by revolving a curve around an axis
    public static func revolution(meridian: Curve3D,
                                  axisOrigin: SIMD3<Double>,
                                  axisDirection: SIMD3<Double>) -> Surface? {
        guard let h = OCCTSurfaceCreateRevolution(meridian.handle,
                                                   axisOrigin.x, axisOrigin.y, axisOrigin.z,
                                                   axisDirection.x, axisDirection.y, axisDirection.z)
        else { return nil }
        return Surface(handle: h)
    }

    // MARK: - Freeform Surfaces

    /// Create a Bezier surface from control points
    /// - Parameters:
    ///   - poles: 2D array of control points [uRow][vCol]
    ///   - weights: Optional 2D array of weights (same dimensions as poles)
    public static func bezier(poles: [[SIMD3<Double>]],
                              weights: [[Double]]? = nil) -> Surface? {
        let uCount = Int32(poles.count)
        guard uCount >= 2 else { return nil }
        let vCount = Int32(poles[0].count)
        guard vCount >= 2 else { return nil }

        var flatPoles = [Double]()
        flatPoles.reserveCapacity(Int(uCount * vCount) * 3)
        for row in poles {
            for p in row {
                flatPoles.append(p.x)
                flatPoles.append(p.y)
                flatPoles.append(p.z)
            }
        }

        if let w = weights {
            var flatWeights = [Double]()
            flatWeights.reserveCapacity(Int(uCount * vCount))
            for row in w {
                flatWeights.append(contentsOf: row)
            }
            let h = flatPoles.withUnsafeBufferPointer { pPtr in
                flatWeights.withUnsafeBufferPointer { wPtr in
                    OCCTSurfaceCreateBezier(pPtr.baseAddress, uCount, vCount,
                                            wPtr.baseAddress)
                }
            }
            guard let h = h else { return nil }
            return Surface(handle: h)
        } else {
            let h = flatPoles.withUnsafeBufferPointer { pPtr in
                OCCTSurfaceCreateBezier(pPtr.baseAddress, uCount, vCount, nil)
            }
            guard let h = h else { return nil }
            return Surface(handle: h)
        }
    }

    /// Create a BSpline surface
    /// - Parameters:
    ///   - poles: 2D array of control points [uRow][vCol]
    ///   - weights: Optional 2D array of weights
    ///   - knotsU: Knot values in U direction
    ///   - multiplicitiesU: Knot multiplicities in U direction
    ///   - knotsV: Knot values in V direction
    ///   - multiplicitiesV: Knot multiplicities in V direction
    ///   - degreeU: Polynomial degree in U
    ///   - degreeV: Polynomial degree in V
    public static func bspline(poles: [[SIMD3<Double>]],
                               weights: [[Double]]? = nil,
                               knotsU: [Double], multiplicitiesU: [Int32],
                               knotsV: [Double], multiplicitiesV: [Int32],
                               degreeU: Int, degreeV: Int) -> Surface? {
        let uCount = Int32(poles.count)
        guard uCount >= 2 else { return nil }
        let vCount = Int32(poles[0].count)
        guard vCount >= 2 else { return nil }

        var flatPoles = [Double]()
        flatPoles.reserveCapacity(Int(uCount * vCount) * 3)
        for row in poles {
            for p in row {
                flatPoles.append(p.x)
                flatPoles.append(p.y)
                flatPoles.append(p.z)
            }
        }

        let result: OCCTSurfaceRef? = flatPoles.withUnsafeBufferPointer { pPtr in
            knotsU.withUnsafeBufferPointer { kuPtr in
                knotsV.withUnsafeBufferPointer { kvPtr in
                    multiplicitiesU.withUnsafeBufferPointer { muPtr in
                        multiplicitiesV.withUnsafeBufferPointer { mvPtr in
                            if let w = weights {
                                var flatWeights = [Double]()
                                flatWeights.reserveCapacity(Int(uCount * vCount))
                                for row in w { flatWeights.append(contentsOf: row) }
                                return flatWeights.withUnsafeBufferPointer { wPtr in
                                    OCCTSurfaceCreateBSpline(
                                        pPtr.baseAddress, uCount, vCount,
                                        wPtr.baseAddress,
                                        kuPtr.baseAddress, Int32(knotsU.count),
                                        kvPtr.baseAddress, Int32(knotsV.count),
                                        muPtr.baseAddress, mvPtr.baseAddress,
                                        Int32(degreeU), Int32(degreeV))
                                }
                            } else {
                                return OCCTSurfaceCreateBSpline(
                                    pPtr.baseAddress, uCount, vCount,
                                    nil,
                                    kuPtr.baseAddress, Int32(knotsU.count),
                                    kvPtr.baseAddress, Int32(knotsV.count),
                                    muPtr.baseAddress, mvPtr.baseAddress,
                                    Int32(degreeU), Int32(degreeV))
                            }
                        }
                    }
                }
            }
        }
        guard let h = result else { return nil }
        return Surface(handle: h)
    }

    // MARK: - Operations

    /// Create a rectangular trim of this surface
    public func trimmed(u1: Double, u2: Double, v1: Double, v2: Double) -> Surface? {
        guard let h = OCCTSurfaceTrim(handle, u1, u2, v1, v2) else { return nil }
        return Surface(handle: h)
    }

    /// Create an offset surface at a given distance from this surface
    public func offset(distance: Double) -> Surface? {
        guard let h = OCCTSurfaceOffset(handle, distance) else { return nil }
        return Surface(handle: h)
    }

    /// Translated copy
    public func translated(by delta: SIMD3<Double>) -> Surface? {
        guard let h = OCCTSurfaceTranslate(handle, delta.x, delta.y, delta.z) else { return nil }
        return Surface(handle: h)
    }

    /// Rotated copy around an axis
    public func rotated(axisOrigin: SIMD3<Double>, axisDirection: SIMD3<Double>,
                        angle: Double) -> Surface? {
        guard let h = OCCTSurfaceRotate(handle,
                                         axisOrigin.x, axisOrigin.y, axisOrigin.z,
                                         axisDirection.x, axisDirection.y, axisDirection.z,
                                         angle)
        else { return nil }
        return Surface(handle: h)
    }

    /// Scaled copy from a center point
    public func scaled(center: SIMD3<Double>, factor: Double) -> Surface? {
        guard let h = OCCTSurfaceScale(handle, center.x, center.y, center.z, factor)
        else { return nil }
        return Surface(handle: h)
    }

    /// Mirrored copy across a plane
    public func mirrored(planeOrigin: SIMD3<Double>, planeNormal: SIMD3<Double>) -> Surface? {
        guard let h = OCCTSurfaceMirrorPlane(handle,
                                              planeOrigin.x, planeOrigin.y, planeOrigin.z,
                                              planeNormal.x, planeNormal.y, planeNormal.z)
        else { return nil }
        return Surface(handle: h)
    }

    // MARK: - Conversion

    /// Convert to BSpline representation
    public func toBSpline() -> Surface? {
        guard let h = OCCTSurfaceToBSpline(handle) else { return nil }
        return Surface(handle: h)
    }

    /// Approximate as a BSpline surface within tolerance
    public func approximated(tolerance: Double = 0.01, continuity: Int = 2,
                             maxSegments: Int = 100, maxDegree: Int = 10) -> Surface? {
        guard let h = OCCTSurfaceApproximate(handle, tolerance, Int32(continuity),
                                              Int32(maxSegments), Int32(maxDegree))
        else { return nil }
        return Surface(handle: h)
    }

    // MARK: - Iso Curves

    /// Extract a U-iso curve (constant U, varying V)
    public func uIso(at u: Double) -> Curve3D? {
        guard let h = OCCTSurfaceUIso(handle, u) else { return nil }
        return Curve3D(handle: h)
    }

    /// Extract a V-iso curve (constant V, varying U)
    public func vIso(at v: Double) -> Curve3D? {
        guard let h = OCCTSurfaceVIso(handle, v) else { return nil }
        return Curve3D(handle: h)
    }

    // MARK: - Pipe Surfaces

    /// Create a pipe surface by sweeping a circle along a path
    public static func pipe(path: Curve3D, radius: Double) -> Surface? {
        guard let h = OCCTSurfaceCreatePipe(path.handle, radius) else { return nil }
        return Surface(handle: h)
    }

    /// Create a pipe surface by sweeping a section curve along a path
    public static func pipe(path: Curve3D, section: Curve3D) -> Surface? {
        guard let h = OCCTSurfaceCreatePipeWithSection(path.handle, section.handle)
        else { return nil }
        return Surface(handle: h)
    }

    // MARK: - Draw Methods

    /// Draw iso-parameter grid lines for Metal visualization
    /// - Parameters:
    ///   - uLineCount: Number of U-iso lines
    ///   - vLineCount: Number of V-iso lines
    ///   - pointsPerLine: Points per iso line
    /// - Returns: Array of polylines, each a [SIMD3<Double>]
    public func drawGrid(uLineCount: Int = 10, vLineCount: Int = 10,
                         pointsPerLine: Int = 50) -> [[SIMD3<Double>]] {
        let maxLines = uLineCount + vLineCount
        let maxPoints = maxLines * pointsPerLine
        var buffer = [Double](repeating: 0, count: maxPoints * 3)
        var lineLengths = [Int32](repeating: 0, count: maxLines)

        let totalPoints = Int(OCCTSurfaceDrawGrid(
            handle, Int32(uLineCount), Int32(vLineCount), Int32(pointsPerLine),
            &buffer, Int32(maxPoints), &lineLengths, Int32(maxLines)))

        guard totalPoints > 0 else { return [] }

        var result = [[SIMD3<Double>]]()
        var offset = 0
        for i in 0..<maxLines {
            let count = Int(lineLengths[i])
            if count == 0 { continue }
            var line = [SIMD3<Double>]()
            line.reserveCapacity(count)
            for j in 0..<count {
                let idx = (offset + j) * 3
                line.append(SIMD3(buffer[idx], buffer[idx + 1], buffer[idx + 2]))
            }
            result.append(line)
            offset += count
        }
        return result
    }

    /// Sample a uniform mesh grid of points for Metal visualization
    /// - Returns: 2D array [uIndex][vIndex] of surface points
    public func drawMesh(uCount: Int = 20, vCount: Int = 20) -> [[SIMD3<Double>]] {
        let total = uCount * vCount
        var buffer = [Double](repeating: 0, count: total * 3)
        let n = Int(OCCTSurfaceDrawMesh(handle, Int32(uCount), Int32(vCount), &buffer))
        guard n == total else { return [] }

        var grid = [[SIMD3<Double>]]()
        grid.reserveCapacity(uCount)
        for i in 0..<uCount {
            var row = [SIMD3<Double>]()
            row.reserveCapacity(vCount)
            for j in 0..<vCount {
                let idx = (i * vCount + j) * 3
                row.append(SIMD3(buffer[idx], buffer[idx + 1], buffer[idx + 2]))
            }
            grid.append(row)
        }
        return grid
    }

    // MARK: - Local Properties

    /// Gaussian curvature at (u, v)
    public func gaussianCurvature(atU u: Double, v: Double) -> Double {
        OCCTSurfaceGetGaussianCurvature(handle, u, v)
    }

    /// Mean curvature at (u, v)
    public func meanCurvature(atU u: Double, v: Double) -> Double {
        OCCTSurfaceGetMeanCurvature(handle, u, v)
    }

    /// Principal curvature result
    public struct PrincipalCurvatures: Sendable {
        public let kMin: Double
        public let kMax: Double
        public let dirMin: SIMD3<Double>
        public let dirMax: SIMD3<Double>
    }

    /// Principal curvatures and directions at (u, v)
    public func principalCurvatures(atU u: Double, v: Double) -> PrincipalCurvatures? {
        var kMin: Double = 0, kMax: Double = 0
        var d1x: Double = 0, d1y: Double = 0, d1z: Double = 0
        var d2x: Double = 0, d2y: Double = 0, d2z: Double = 0
        guard OCCTSurfaceGetPrincipalCurvatures(handle, u, v, &kMin, &kMax,
                                                 &d1x, &d1y, &d1z,
                                                 &d2x, &d2y, &d2z)
        else { return nil }
        return PrincipalCurvatures(kMin: kMin, kMax: kMax,
                                   dirMin: SIMD3(d1x, d1y, d1z),
                                   dirMax: SIMD3(d2x, d2y, d2z))
    }

    // MARK: - Bounding Box

    /// Axis-aligned bounding box (nil for infinite surfaces)
    public var boundingBox: (min: SIMD3<Double>, max: SIMD3<Double>)? {
        var xMin: Double = 0, yMin: Double = 0, zMin: Double = 0
        var xMax: Double = 0, yMax: Double = 0, zMax: Double = 0
        guard OCCTSurfaceGetBoundingBox(handle, &xMin, &yMin, &zMin,
                                         &xMax, &yMax, &zMax)
        else { return nil }
        return (SIMD3(xMin, yMin, zMin), SIMD3(xMax, yMax, zMax))
    }

    // MARK: - BSpline/Bezier Queries

    /// Number of control points in U direction (0 if not BSpline/Bezier)
    public var uPoleCount: Int {
        Int(OCCTSurfaceGetUPoleCount(handle))
    }

    /// Number of control points in V direction (0 if not BSpline/Bezier)
    public var vPoleCount: Int {
        Int(OCCTSurfaceGetVPoleCount(handle))
    }

    /// Control points as 2D array [uRow][vCol] (empty if not BSpline/Bezier)
    public var poles: [[SIMD3<Double>]] {
        let uCount = uPoleCount
        let vCount = vPoleCount
        guard uCount > 0 && vCount > 0 else { return [] }
        var buffer = [Double](repeating: 0, count: uCount * vCount * 3)
        let n = Int(OCCTSurfaceGetPoles(handle, &buffer))
        guard n == uCount * vCount else { return [] }
        var result = [[SIMD3<Double>]]()
        for i in 0..<uCount {
            var row = [SIMD3<Double>]()
            for j in 0..<vCount {
                let idx = (i * vCount + j) * 3
                row.append(SIMD3(buffer[idx], buffer[idx + 1], buffer[idx + 2]))
            }
            result.append(row)
        }
        return result
    }

    /// Polynomial degree in U direction (0 if not BSpline/Bezier)
    public var uDegree: Int {
        Int(OCCTSurfaceGetUDegree(handle))
    }

    /// Polynomial degree in V direction (0 if not BSpline/Bezier)
    public var vDegree: Int {
        Int(OCCTSurfaceGetVDegree(handle))
    }

    // MARK: - Curve Projection (v0.22.0)

    /// Result of projecting a point onto a surface
    public struct SurfaceProjection: Sendable {
        public let u: Double
        public let v: Double
        public let distance: Double
    }

    /// Project a 3D curve onto this surface, returning a 2D (UV) parametric curve.
    ///
    /// Uses `GeomProjLib::Curve2d` for analytic projection. The result is a
    /// `Curve2D` in the surface's UV parameter space.
    /// - Parameters:
    ///   - curve: The 3D curve to project
    ///   - tolerance: Projection tolerance (default 1e-4)
    /// - Returns: A 2D curve in UV space, or nil if projection fails
    public func projectCurve(_ curve: Curve3D, tolerance: Double = 1e-4) -> Curve2D? {
        guard let h = OCCTSurfaceProjectCurve2D(handle, curve.handle, tolerance) else {
            return nil
        }
        return Curve2D(handle: h)
    }

    /// Project a 3D curve onto this surface using composite projection.
    ///
    /// Uses `ProjLib_CompProjectedCurve` which handles cases where the curve
    /// projects as multiple disconnected segments in UV space (e.g., when
    /// the curve crosses surface seams or boundaries).
    /// - Parameters:
    ///   - curve: The 3D curve to project
    ///   - tolerance: Projection tolerance (default 1e-4)
    /// - Returns: Array of 2D curves in UV space (may be empty)
    public func projectCurveSegments(_ curve: Curve3D, tolerance: Double = 1e-4) -> [Curve2D] {
        var buffer = [OCCTCurve2DRef?](repeating: nil, count: 32)
        let count = buffer.withUnsafeMutableBufferPointer { ptr in
            OCCTSurfaceProjectCurveSegments(handle, curve.handle, tolerance,
                                             ptr.baseAddress, 32)
        }
        var result = [Curve2D]()
        for i in 0..<Int(count) {
            if let h = buffer[i] {
                result.append(Curve2D(handle: h))
            }
        }
        return result
    }

    /// Project a 3D curve onto this surface, returning the result as a 3D curve.
    ///
    /// Uses `GeomProjLib::Project` for normal projection. The result is a
    /// 3D curve that lies on the surface.
    /// - Parameter curve: The 3D curve to project
    /// - Returns: A 3D curve on the surface, or nil if projection fails
    public func projectCurve3D(_ curve: Curve3D) -> Curve3D? {
        guard let h = OCCTSurfaceProjectCurve3D(handle, curve.handle) else {
            return nil
        }
        return Curve3D(handle: h)
    }

    /// Project a 3D point onto this surface (closest point).
    ///
    /// Uses `GeomAPI_ProjectPointOnSurf` to find the nearest point
    /// on the surface to the given point.
    /// - Parameter point: The 3D point to project
    /// - Returns: UV parameters and distance, or nil if projection fails
    public func projectPoint(_ point: SIMD3<Double>) -> SurfaceProjection? {
        var u: Double = 0, v: Double = 0, distance: Double = 0
        guard OCCTSurfaceProjectPoint(handle, point.x, point.y, point.z,
                                       &u, &v, &distance) else {
            return nil
        }
        return SurfaceProjection(u: u, v: v, distance: distance)
    }

    // MARK: - Advanced Plate Surfaces (v0.23.0)

    /// Create a plate surface (parametric) interpolating through 3D points.
    ///
    /// Uses `GeomPlate_BuildPlateSurface` + `GeomPlate_MakeApprox` to produce
    /// a BSpline surface that passes through all given points.
    ///
    /// - Parameters:
    ///   - points: Array of 3D points (minimum 3)
    ///   - degree: Maximum polynomial degree (default 3)
    ///   - tolerance: Approximation tolerance (default 0.01)
    /// - Returns: A parametric BSpline surface, or nil on failure
    public static func plateThrough(
        _ points: [SIMD3<Double>],
        degree: Int = 3,
        tolerance: Double = 0.01
    ) -> Surface? {
        guard points.count >= 3 else { return nil }

        var flatPoints: [Double] = []
        for p in points {
            flatPoints.append(p.x)
            flatPoints.append(p.y)
            flatPoints.append(p.z)
        }

        guard let h = OCCTSurfacePlateThrough(
            &flatPoints, Int32(points.count),
            Int32(degree), tolerance
        ) else { return nil }
        return Surface(handle: h)
    }

    /// Deform this surface to pass through target positions (NLPlate G0).
    ///
    /// Uses the non-linear plate solver to compute a displacement field on
    /// this surface, then samples and approximates as a BSpline. Each constraint
    /// specifies a (u, v) parameter and a target 3D position.
    ///
    /// - Parameters:
    ///   - constraints: Array of (uv parameter, target 3D position) pairs
    ///   - maxIterations: Maximum solver iterations (default 4)
    ///   - tolerance: Approximation tolerance (default 1e-3)
    /// - Returns: A new deformed surface, or nil on failure
    public func nlPlateDeformed(
        constraints: [(uv: SIMD2<Double>, target: SIMD3<Double>)],
        maxIterations: Int = 4,
        tolerance: Double = 1e-3
    ) -> Surface? {
        guard !constraints.isEmpty else { return nil }

        // Flat array: (u, v, targetX, targetY, targetZ) per constraint
        var flat: [Double] = []
        for c in constraints {
            flat.append(c.uv.x)
            flat.append(c.uv.y)
            flat.append(c.target.x)
            flat.append(c.target.y)
            flat.append(c.target.z)
        }

        guard let h = OCCTSurfaceNLPlateG0(
            handle, &flat, Int32(constraints.count),
            Int32(maxIterations), tolerance
        ) else { return nil }
        return Surface(handle: h)
    }

    /// Deform this surface with position + tangent constraints (NLPlate G0+G1).
    ///
    /// Each constraint specifies a (u, v) parameter, a target 3D position, and
    /// desired partial derivatives (tangent vectors) in the U and V directions.
    ///
    /// - Parameters:
    ///   - constraints: Array of (uv, target, tangentU, tangentV) tuples
    ///   - maxIterations: Maximum solver iterations (default 4)
    ///   - tolerance: Approximation tolerance (default 1e-3)
    /// - Returns: A new deformed surface, or nil on failure
    public func nlPlateDeformedG1(
        constraints: [(uv: SIMD2<Double>, target: SIMD3<Double>, tangentU: SIMD3<Double>, tangentV: SIMD3<Double>)],
        maxIterations: Int = 4,
        tolerance: Double = 1e-3
    ) -> Surface? {
        guard !constraints.isEmpty else { return nil }

        // Flat: (u, v, targetX, targetY, targetZ, d1uX, d1uY, d1uZ, d1vX, d1vY, d1vZ)
        var flat: [Double] = []
        for c in constraints {
            flat.append(c.uv.x)
            flat.append(c.uv.y)
            flat.append(c.target.x)
            flat.append(c.target.y)
            flat.append(c.target.z)
            flat.append(c.tangentU.x)
            flat.append(c.tangentU.y)
            flat.append(c.tangentU.z)
            flat.append(c.tangentV.x)
            flat.append(c.tangentV.y)
            flat.append(c.tangentV.z)
        }

        guard let h = OCCTSurfaceNLPlateG1(
            handle, &flat, Int32(constraints.count),
            Int32(maxIterations), tolerance
        ) else { return nil }
        return Surface(handle: h)
    }
}

// MARK: - Batch Evaluation (v0.29.0)

extension Surface {
    /// Evaluate the surface at a UV grid in one call.
    ///
    /// Returns points in row-major order (u varies fastest).
    ///
    /// - Parameters:
    ///   - uParameters: Array of U parameter values
    ///   - vParameters: Array of V parameter values
    /// - Returns: 2D array of evaluated 3D points [v][u]
    public func evaluateGrid(uParameters: [Double], vParameters: [Double]) -> [[SIMD3<Double>]] {
        guard !uParameters.isEmpty, !vParameters.isEmpty else { return [] }
        let total = uParameters.count * vParameters.count
        var outXYZ = [Double](repeating: 0, count: total * 3)
        let n = Int(OCCTSurfaceEvaluateGrid(handle,
                                             uParameters, Int32(uParameters.count),
                                             vParameters, Int32(vParameters.count),
                                             &outXYZ))
        guard n == total else { return [] }
        var result = [[SIMD3<Double>]]()
        for v in 0..<vParameters.count {
            var row = [SIMD3<Double>]()
            for u in 0..<uParameters.count {
                let i = v * uParameters.count + u
                row.append(SIMD3(outXYZ[i * 3], outXYZ[i * 3 + 1], outXYZ[i * 3 + 2]))
            }
            result.append(row)
        }
        return result
    }
}

// MARK: - Surface Intersection & Conversion (v0.30.0)

extension Surface {
    /// Intersect this surface with another surface.
    ///
    /// - Parameters:
    ///   - other: The other surface
    ///   - tolerance: Intersection tolerance
    ///   - maxCurves: Maximum number of intersection curves
    /// - Returns: Array of intersection curves
    public func intersections(with other: Surface, tolerance: Double = 1e-6, maxCurves: Int = 50) -> [Curve3D] {
        var handles = [OCCTCurve3DRef?](repeating: nil, count: maxCurves)
        let n = Int(OCCTSurfaceIntersect(handle, other.handle, tolerance, &handles, Int32(maxCurves)))
        return (0..<n).compactMap { i in
            guard let h = handles[i] else { return nil }
            return Curve3D(handle: h)
        }
    }

    /// Convert this freeform surface to an analytical surface if possible.
    ///
    /// Recognizes if the surface is actually a plane, cylinder, cone,
    /// sphere, or torus within the given tolerance.
    ///
    /// - Parameter tolerance: Recognition tolerance
    /// - Returns: The analytical surface, or nil if not recognizable
    public func toAnalytical(tolerance: Double = 1e-4) -> Surface? {
        guard let h = OCCTSurfaceToAnalytical(handle, tolerance) else { return nil }
        return Surface(handle: h)
    }
}

// MARK: - Bezier Surface Fill (v0.31.0)

/// Filling style for Bezier surface construction.
public enum BezierFillStyle: Int32, Sendable {
    /// Stretch style — minimal surface area
    case stretch = 0
    /// Coons style — bilinear blending
    case coons = 1
    /// Curved style — smooth curved interpolation
    case curved = 2
}

extension Surface {
    /// Create a Bezier surface by filling 4 Bezier boundary curves.
    ///
    /// The four curves must be Bezier curves forming a closed boundary.
    ///
    /// - Parameters:
    ///   - c1: First boundary curve
    ///   - c2: Second boundary curve
    ///   - c3: Third boundary curve
    ///   - c4: Fourth boundary curve
    ///   - style: Filling style
    /// - Returns: Bezier surface, or nil on failure
    public static func bezierFill(_ c1: Curve3D, _ c2: Curve3D, _ c3: Curve3D, _ c4: Curve3D,
                                  style: BezierFillStyle = .stretch) -> Surface? {
        guard let h = OCCTSurfaceBezierFill4(c1.handle, c2.handle, c3.handle, c4.handle,
                                              style.rawValue) else { return nil }
        return Surface(handle: h)
    }

    /// Create a Bezier surface by filling 2 Bezier boundary curves.
    ///
    /// The two curves are used as opposite edges of the surface.
    ///
    /// - Parameters:
    ///   - c1: First boundary curve
    ///   - c2: Second boundary curve
    ///   - style: Filling style
    /// - Returns: Bezier surface, or nil on failure
    public static func bezierFill(_ c1: Curve3D, _ c2: Curve3D,
                                  style: BezierFillStyle = .stretch) -> Surface? {
        guard let h = OCCTSurfaceBezierFill2(c1.handle, c2.handle, style.rawValue) else { return nil }
        return Surface(handle: h)
    }

    // MARK: - Face from Surface (v0.33.0)

    /// Create a face from this surface using its full parameter domain.
    ///
    /// - Parameter tolerance: Tolerance for face creation
    /// - Returns: Face shape, or nil on failure
    public func toFace(tolerance: Double = 1e-6) -> Shape? {
        let d = domain
        return Shape.face(from: self, uRange: d.uMin...d.uMax, vRange: d.vMin...d.vMax, tolerance: tolerance)
    }

    /// Create a face from this surface with specific UV parameter bounds.
    ///
    /// - Parameters:
    ///   - uRange: U parameter range
    ///   - vRange: V parameter range
    ///   - tolerance: Tolerance for face creation
    /// - Returns: Face shape, or nil on failure
    public func toFace(uRange: ClosedRange<Double>, vRange: ClosedRange<Double>,
                       tolerance: Double = 1e-6) -> Shape? {
        return Shape.face(from: self, uRange: uRange, vRange: vRange, tolerance: tolerance)
    }

    // MARK: - Surface-Surface Intersection (v0.35.0)

    /// Compute intersection curves between this surface and another.
    ///
    /// Returns the parametric curves where the two surfaces intersect.
    ///
    /// - Parameters:
    ///   - other: The other surface to intersect with
    ///   - tolerance: Intersection tolerance
    /// - Returns: Array of 3D intersection curves
    public func intersectionCurves(with other: Surface, tolerance: Double = 1e-6) -> [Curve3D] {
        let maxCurves: Int32 = 64
        var curveRefs = [OCCTCurve3DRef?](repeating: nil, count: Int(maxCurves))
        let count = curveRefs.withUnsafeMutableBufferPointer { buf in
            OCCTSurfaceSurfaceIntersect(handle, other.handle, tolerance,
                                         buf.baseAddress, maxCurves)
        }
        return (0..<Int(count)).compactMap { i in
            guard let ref = curveRefs[i] else { return nil }
            return Curve3D(handle: ref)
        }
    }
}

// MARK: - Curve-Surface Intersection (v0.35.0)

/// Result of a curve-surface intersection point.
public struct CurveSurfaceIntersection: Sendable {
    /// 3D intersection point
    public var point: SIMD3<Double>
    /// Surface parameters (u, v) at the intersection
    public var surfaceUV: SIMD2<Double>
    /// Curve parameter at the intersection
    public var curveParameter: Double
}

extension Curve3D {
    /// Compute intersection points between this curve and a surface.
    ///
    /// - Parameter surface: The surface to intersect with
    /// - Returns: Array of intersection results with 3D points, surface UV, and curve parameter
    public func intersections(with surface: Surface) -> [CurveSurfaceIntersection] {
        let maxPoints: Int32 = 64
        var points = [OCCTCurveSurfacePoint](repeating: OCCTCurveSurfacePoint(), count: Int(maxPoints))
        let count = points.withUnsafeMutableBufferPointer { buf in
            OCCTCurveSurfaceIntersect(handle, surface.handle, buf.baseAddress, maxPoints)
        }
        return (0..<Int(count)).map { i in
            let p = points[i]
            return CurveSurfaceIntersection(
                point: SIMD3(p.x, p.y, p.z),
                surfaceUV: SIMD2(p.u, p.v),
                curveParameter: p.w
            )
        }
    }
}

// MARK: - Surface to Bezier Patches (v0.36.0)

extension Surface {
    /// Convert this surface to an array of Bezier surface patches.
    ///
    /// Decomposes a B-spline surface into a grid of Bezier patches. The surface
    /// is first converted to B-spline if needed.
    ///
    /// - Returns: Array of Bezier surface patches, or empty if conversion fails
    public func toBezierPatches() -> [Surface] {
        let maxPatches: Int32 = 256
        var patchRefs = [OCCTSurfaceRef?](repeating: nil, count: Int(maxPatches))
        let count = patchRefs.withUnsafeMutableBufferPointer { buf in
            OCCTSurfaceToBezierPatches(handle, buf.baseAddress, maxPatches)
        }
        return (0..<Int(count)).compactMap { i in
            guard let ref = patchRefs[i] else { return nil }
            return Surface(handle: ref)
        }
    }
}
