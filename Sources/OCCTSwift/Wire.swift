import Foundation
import simd
import OCCTBridge

/// A wire represents a connected sequence of edges (curves).
///
/// Wires are used for two main purposes:
/// 1. **2D Profiles**: Cross-sections to be swept, extruded, or revolved into solids
/// 2. **3D Paths**: Curves along which profiles are swept
///
/// ## Creating 2D Profiles
///
/// ```swift
/// // Simple rectangle
/// let rect = Wire.rectangle(width: 10, height: 5)
///
/// // Custom polygon (rail cross-section)
/// let railProfile = Wire.polygon([
///     SIMD2(0, 0),
///     SIMD2(2.5, 0),
///     SIMD2(2.5, 1),
///     SIMD2(1.5, 7),
///     SIMD2(0, 7)
/// ], closed: true)
/// ```
///
/// ## Creating 3D Paths
///
/// ```swift
/// // Straight line
/// let straight = Wire.line(from: .zero, to: SIMD3(100, 0, 0))
///
/// // Circular arc
/// let curve = Wire.arc(
///     center: .zero,
///     radius: 500,
///     startAngle: 0,
///     endAngle: .pi / 4
/// )
/// ```
///
/// ## Sweeping Profiles Along Paths
///
/// ```swift
/// let rail = Shape.sweep(profile: railProfile, along: curve)
/// ```
public final class Wire: @unchecked Sendable {
    internal let handle: OCCTWireRef

    internal init(handle: OCCTWireRef) {
        self.handle = handle
    }

    deinit {
        OCCTWireRelease(handle)
    }

    // MARK: - 2D Profiles (for Extrusion/Sweep)

    /// Create a rectangular profile centered at origin in XY plane.
    ///
    /// - Parameters:
    ///   - width: Width of rectangle (X dimension)
    ///   - height: Height of rectangle (Y dimension)
    /// - Returns: A closed rectangular wire
    ///
    /// The rectangle is centered at origin with corners at (±width/2, ±height/2).
    public static func rectangle(width: Double, height: Double) -> Wire {
        let handle = OCCTWireCreateRectangle(width, height)
        return Wire(handle: handle!)
    }

    /// Create a circular profile centered at origin in XY plane.
    ///
    /// - Parameter radius: Radius of the circle
    /// - Returns: A closed circular wire
    public static func circle(radius: Double) -> Wire {
        let handle = OCCTWireCreateCircle(radius)
        return Wire(handle: handle!)
    }

    /// Create a polygon from 2D points in XY plane.
    ///
    /// - Parameters:
    ///   - points: Array of 2D points defining vertices
    ///   - closed: If true, connects last point to first
    /// - Returns: A polygonal wire
    ///
    /// Points are connected in order. For a closed profile (suitable for
    /// extrusion), pass `closed: true`.
    ///
    /// ## Example: Rail Profile
    ///
    /// ```swift
    /// let railProfile = Wire.polygon([
    ///     SIMD2(0, 0),       // Base left
    ///     SIMD2(2.5, 0),     // Base right
    ///     SIMD2(2.5, 0.8),   // Web start right
    ///     SIMD2(1.8, 0.8),   // Web right
    ///     SIMD2(1.8, 6.5),   // Head start right
    ///     SIMD2(1.0, 7.0),   // Head right
    ///     SIMD2(0, 7.0),     // Head left
    ///     SIMD2(0, 0.8),     // Web left
    /// ], closed: true)
    /// ```
    public static func polygon(_ points: [SIMD2<Double>], closed: Bool = true) -> Wire {
        // Flatten to array of doubles: [x1, y1, x2, y2, ...]
        var flatPoints: [Double] = []
        flatPoints.reserveCapacity(points.count * 2)
        for point in points {
            flatPoints.append(point.x)
            flatPoints.append(point.y)
        }

        let handle = flatPoints.withUnsafeBufferPointer { buffer in
            OCCTWireCreatePolygon(buffer.baseAddress, Int32(points.count), closed)
        }
        return Wire(handle: handle!)
    }

    // MARK: - 3D Paths (for Pipe Sweep)

    /// Create a straight line segment in 3D space.
    ///
    /// - Parameters:
    ///   - from: Start point
    ///   - to: End point
    /// - Returns: A wire consisting of a single straight edge
    public static func line(from start: SIMD3<Double>, to end: SIMD3<Double>) -> Wire {
        let handle = OCCTWireCreateLine(
            start.x, start.y, start.z,
            end.x, end.y, end.z
        )
        return Wire(handle: handle!)
    }

    /// Create a circular arc in 3D space.
    ///
    /// - Parameters:
    ///   - center: Center point of the arc
    ///   - radius: Radius of the arc
    ///   - startAngle: Starting angle in radians (0 = positive X direction)
    ///   - endAngle: Ending angle in radians
    ///   - normal: Normal vector defining the arc plane (default: Z-up)
    /// - Returns: A wire consisting of a single arc edge
    ///
    /// The arc is created in a plane perpendicular to the normal vector.
    /// Angles are measured from the X-axis direction rotated into the plane.
    ///
    /// ## Example: Quarter Circle for Track Curve
    ///
    /// ```swift
    /// let curve = Wire.arc(
    ///     center: SIMD3(0, 0, 0),
    ///     radius: 500,              // 500mm radius
    ///     startAngle: 0,
    ///     endAngle: .pi / 2,        // 90 degrees
    ///     normal: SIMD3(0, 1, 0)    // Horizontal plane (Y-up)
    /// )
    /// ```
    public static func arc(
        center: SIMD3<Double>,
        radius: Double,
        startAngle: Double,
        endAngle: Double,
        normal: SIMD3<Double> = SIMD3(0, 0, 1)
    ) -> Wire {
        let handle = OCCTWireCreateArc(
            center.x, center.y, center.z,
            radius,
            startAngle, endAngle,
            normal.x, normal.y, normal.z
        )
        return Wire(handle: handle!)
    }

    /// Create a 3D path from points in 3D space.
    ///
    /// - Parameters:
    ///   - points: Array of 3D points
    ///   - closed: If true, connects last point to first
    /// - Returns: A wire with straight edges between points
    ///
    /// For a smooth path, use `bspline(_:)` instead.
    public static func path(_ points: [SIMD3<Double>], closed: Bool = false) -> Wire {
        var flatPoints: [Double] = []
        flatPoints.reserveCapacity(points.count * 3)
        for point in points {
            flatPoints.append(point.x)
            flatPoints.append(point.y)
            flatPoints.append(point.z)
        }

        let handle = flatPoints.withUnsafeBufferPointer { buffer in
            OCCTWireCreateFromPoints3D(buffer.baseAddress, Int32(points.count), closed)
        }
        return Wire(handle: handle!)
    }

    /// Create a smooth B-spline curve through control points.
    ///
    /// - Parameter controlPoints: Array of 3D control points
    /// - Returns: A smooth curve wire
    ///
    /// The curve will pass near (but not necessarily through) the control points.
    /// For a curve that passes exactly through points, more sophisticated
    /// interpolation is needed.
    ///
    /// ## Example: Easement Curve
    ///
    /// ```swift
    /// let easement = Wire.bspline([
    ///     SIMD3(0, 0, 0),      // Start (straight)
    ///     SIMD3(50, 0, 0),     // Transition begins
    ///     SIMD3(100, 10, 0),   // Curve develops
    ///     SIMD3(150, 30, 0),   // Full curve
    ///     SIMD3(180, 50, 0)    // Continues curving
    /// ])
    /// ```
    public static func bspline(_ controlPoints: [SIMD3<Double>]) -> Wire {
        var flatPoints: [Double] = []
        flatPoints.reserveCapacity(controlPoints.count * 3)
        for point in controlPoints {
            flatPoints.append(point.x)
            flatPoints.append(point.y)
            flatPoints.append(point.z)
        }

        let handle = flatPoints.withUnsafeBufferPointer { buffer in
            OCCTWireCreateBSpline(buffer.baseAddress, Int32(controlPoints.count))
        }
        return Wire(handle: handle!)
    }

    // MARK: - NURBS Curves

    /// Create a NURBS (Non-Uniform Rational B-Spline) curve with full control.
    ///
    /// - Parameters:
    ///   - poles: Control points (poles) defining the curve shape
    ///   - weights: Weight for each control point (nil for uniform weights = B-spline)
    ///   - knots: Knot values defining parameterization
    ///   - multiplicities: Multiplicity of each knot (nil for all 1s)
    ///   - degree: Curve degree (1=linear, 2=quadratic, 3=cubic)
    /// - Returns: A NURBS curve wire, or nil if parameters are invalid
    ///
    /// NURBS curves provide exact representation of conic sections (circles, ellipses)
    /// and are the standard for CAD data exchange. Use this when you need precise
    /// control over the curve shape, especially for importing/exporting to CAD formats.
    ///
    /// ## Example: Weighted Curve
    ///
    /// ```swift
    /// // A rational quadratic B-spline (can represent exact circle arcs)
    /// let poles = [
    ///     SIMD3(0, 0, 0),
    ///     SIMD3(1, 1, 0),  // Off-curve control point
    ///     SIMD3(2, 0, 0)
    /// ]
    /// let weights = [1.0, 0.707, 1.0]  // sqrt(2)/2 for quarter circle
    /// let knots = [0.0, 1.0]
    /// let mults = [3, 3]  // Clamped at endpoints
    ///
    /// let arc = Wire.nurbs(poles: poles, weights: weights,
    ///                      knots: knots, multiplicities: mults, degree: 2)
    /// ```
    public static func nurbs(
        poles: [SIMD3<Double>],
        weights: [Double]? = nil,
        knots: [Double],
        multiplicities: [Int32]? = nil,
        degree: Int32
    ) -> Wire? {
        guard poles.count >= 2, knots.count >= 2, degree >= 1 else { return nil }

        var flatPoles: [Double] = []
        flatPoles.reserveCapacity(poles.count * 3)
        for pole in poles {
            flatPoles.append(pole.x)
            flatPoles.append(pole.y)
            flatPoles.append(pole.z)
        }

        let handle: OCCTWireRef? = flatPoles.withUnsafeBufferPointer { polesBuffer in
            knots.withUnsafeBufferPointer { knotsBuffer in
                if let weights = weights {
                    return weights.withUnsafeBufferPointer { weightsBuffer in
                        if let mults = multiplicities {
                            return mults.withUnsafeBufferPointer { multsBuffer in
                                OCCTWireCreateNURBS(
                                    polesBuffer.baseAddress,
                                    Int32(poles.count),
                                    weightsBuffer.baseAddress,
                                    knotsBuffer.baseAddress,
                                    Int32(knots.count),
                                    multsBuffer.baseAddress,
                                    degree
                                )
                            }
                        } else {
                            return OCCTWireCreateNURBS(
                                polesBuffer.baseAddress,
                                Int32(poles.count),
                                weightsBuffer.baseAddress,
                                knotsBuffer.baseAddress,
                                Int32(knots.count),
                                nil,
                                degree
                            )
                        }
                    }
                } else {
                    if let mults = multiplicities {
                        return mults.withUnsafeBufferPointer { multsBuffer in
                            OCCTWireCreateNURBS(
                                polesBuffer.baseAddress,
                                Int32(poles.count),
                                nil,
                                knotsBuffer.baseAddress,
                                Int32(knots.count),
                                multsBuffer.baseAddress,
                                degree
                            )
                        }
                    } else {
                        return OCCTWireCreateNURBS(
                            polesBuffer.baseAddress,
                            Int32(poles.count),
                            nil,
                            knotsBuffer.baseAddress,
                            Int32(knots.count),
                            nil,
                            degree
                        )
                    }
                }
            }
        }

        guard let handle = handle else { return nil }
        return Wire(handle: handle)
    }

    /// Create a NURBS curve with uniform (clamped) knot vector.
    ///
    /// - Parameters:
    ///   - poles: Control points defining the curve shape
    ///   - weights: Weight for each control point (nil for uniform = B-spline)
    ///   - degree: Curve degree (1=linear, 2=quadratic, 3=cubic)
    /// - Returns: A NURBS curve wire, or nil if parameters are invalid
    ///
    /// This is a simplified NURBS creation that automatically generates a
    /// clamped uniform knot vector. The curve starts at the first control
    /// point and ends at the last.
    ///
    /// ## Example: Cubic B-Spline with Control Polygon
    ///
    /// ```swift
    /// let controlPolygon = [
    ///     SIMD3(0, 0, 0),
    ///     SIMD3(10, 5, 0),
    ///     SIMD3(20, 0, 0),
    ///     SIMD3(30, 5, 0),
    ///     SIMD3(40, 0, 0)
    /// ]
    /// let curve = Wire.nurbsUniform(poles: controlPolygon, degree: 3)
    /// ```
    public static func nurbsUniform(
        poles: [SIMD3<Double>],
        weights: [Double]? = nil,
        degree: Int32
    ) -> Wire? {
        guard poles.count >= Int(degree) + 1, degree >= 1 else { return nil }

        var flatPoles: [Double] = []
        flatPoles.reserveCapacity(poles.count * 3)
        for pole in poles {
            flatPoles.append(pole.x)
            flatPoles.append(pole.y)
            flatPoles.append(pole.z)
        }

        let handle: OCCTWireRef? = flatPoles.withUnsafeBufferPointer { polesBuffer in
            if let weights = weights {
                return weights.withUnsafeBufferPointer { weightsBuffer in
                    OCCTWireCreateNURBSUniform(
                        polesBuffer.baseAddress,
                        Int32(poles.count),
                        weightsBuffer.baseAddress,
                        degree
                    )
                }
            } else {
                return OCCTWireCreateNURBSUniform(
                    polesBuffer.baseAddress,
                    Int32(poles.count),
                    nil,
                    degree
                )
            }
        }

        guard let handle = handle else { return nil }
        return Wire(handle: handle)
    }

    /// Create a cubic B-spline curve (non-rational, degree 3).
    ///
    /// - Parameter poles: Control points (minimum 4 for cubic)
    /// - Returns: A cubic B-spline wire, or nil if fewer than 4 points
    ///
    /// Cubic B-splines are the most common choice for smooth curves.
    /// They provide C² continuity (smooth curvature) and good local control.
    ///
    /// ## Example: Transition Curve Path
    ///
    /// ```swift
    /// let transitionPoles = [
    ///     SIMD3(0, 0, 0),      // Start tangent to straight
    ///     SIMD3(20, 0, 0),
    ///     SIMD3(40, 2, 0),     // Begin curving
    ///     SIMD3(60, 8, 0),
    ///     SIMD3(80, 20, 0),    // Full curve
    ///     SIMD3(90, 30, 0)
    /// ]
    /// let easement = Wire.cubicBSpline(poles: transitionPoles)
    /// ```
    public static func cubicBSpline(poles: [SIMD3<Double>]) -> Wire? {
        guard poles.count >= 4 else { return nil }

        var flatPoles: [Double] = []
        flatPoles.reserveCapacity(poles.count * 3)
        for pole in poles {
            flatPoles.append(pole.x)
            flatPoles.append(pole.y)
            flatPoles.append(pole.z)
        }

        let handle: OCCTWireRef? = flatPoles.withUnsafeBufferPointer { buffer in
            OCCTWireCreateCubicBSpline(buffer.baseAddress, Int32(poles.count))
        }

        guard let handle = handle else { return nil }
        return Wire(handle: handle)
    }

    // MARK: - Wire Composition

    /// Join multiple wires into a single connected wire.
    ///
    /// - Parameter wires: Array of wires to join
    /// - Returns: A single wire containing all edges
    ///
    /// Wires should be geometrically connected (end of one near start of next).
    /// OCCT will attempt to connect them within tolerance.
    ///
    /// ## Example: Complex Path
    ///
    /// ```swift
    /// let straight1 = Wire.line(from: .zero, to: SIMD3(100, 0, 0))
    /// let curve = Wire.arc(center: SIMD3(100, 50, 0), radius: 50, ...)
    /// let straight2 = Wire.line(from: curveEnd, to: finalPoint)
    ///
    /// let fullPath = Wire.join([straight1, curve, straight2])
    /// ```
    public static func join(_ wires: [Wire]) -> Wire {
        let handles: [OCCTWireRef?] = wires.map { $0.handle }
        let handle = handles.withUnsafeBufferPointer { buffer in
            OCCTWireJoin(buffer.baseAddress, Int32(wires.count))
        }
        return Wire(handle: handle!)
    }
}

// MARK: - Convenience Extensions

extension Wire {
    /// Create a rail profile based on standard rail specifications.
    ///
    /// - Parameters:
    ///   - headWidth: Width of rail head (top running surface)
    ///   - headHeight: Height of rail head
    ///   - webThickness: Thickness of the web (vertical part)
    ///   - baseWidth: Width of rail base (foot)
    ///   - baseHeight: Height of rail base
    ///   - totalHeight: Total height from base to head top
    /// - Returns: A closed wire representing the rail cross-section
    ///
    /// Creates a simplified rail profile suitable for model railway use.
    /// For more accurate profiles, use `polygon(_:closed:)` with exact dimensions.
    public static func railProfile(
        headWidth: Double,
        headHeight: Double,
        webThickness: Double,
        baseWidth: Double,
        baseHeight: Double,
        totalHeight: Double
    ) -> Wire {
        let webHeight = totalHeight - headHeight - baseHeight

        // Build profile from bottom-left, clockwise
        let points: [SIMD2<Double>] = [
            // Base
            SIMD2(0, 0),
            SIMD2(baseWidth, 0),
            SIMD2(baseWidth, baseHeight),

            // Right side of web
            SIMD2((baseWidth + webThickness) / 2, baseHeight),
            SIMD2((baseWidth + webThickness) / 2, baseHeight + webHeight),

            // Head right
            SIMD2((baseWidth + headWidth) / 2, baseHeight + webHeight),
            SIMD2((baseWidth + headWidth) / 2, totalHeight),

            // Head top
            SIMD2((baseWidth - headWidth) / 2, totalHeight),

            // Head left
            SIMD2((baseWidth - headWidth) / 2, baseHeight + webHeight),

            // Left side of web
            SIMD2((baseWidth - webThickness) / 2, baseHeight + webHeight),
            SIMD2((baseWidth - webThickness) / 2, baseHeight),

            // Back to base
            SIMD2(0, baseHeight)
        ]

        return polygon(points, closed: true)
    }
}
