import Foundation
import simd
import OCCTBridge

/// 2D projection of a 3D shape using Hidden Line Removal (HLR)
///
/// Use `Drawing` to create technical drawings, 2D views, or DXF exports.
///
/// ```swift
/// let box = Shape.box(width: 100, height: 50, depth: 30)
/// let topView = Drawing.project(box, direction: SIMD3(0, 0, 1))
/// let visibleEdges = topView.edges(ofType: .visible)
/// ```
public final class Drawing: @unchecked Sendable {

    /// Projection type for creating 2D views
    public enum ProjectionType: UInt32 {
        /// Orthographic projection (parallel lines)
        case orthographic = 0
        /// Perspective projection (converging lines)
        case perspective = 1
    }

    /// Type of edges in a 2D projection
    public enum EdgeType: UInt32 {
        /// Visible edges (not obscured by other geometry)
        case visible = 0
        /// Hidden edges (behind other geometry)
        case hidden = 1
        /// Outline/silhouette edges
        case outline = 2
    }

    internal let handle: OCCTDrawingRef
    internal let annotationStore = DrawingAnnotationStore()

    internal init(handle: OCCTDrawingRef) {
        self.handle = handle
    }

    deinit {
        OCCTDrawingRelease(handle)
    }

    // MARK: - Dimensions and annotations (v0.137, #64)

    /// All dimensions attached to this drawing.
    public var dimensions: [DrawingDimension] { annotationStore.dimensions }

    /// All non-dimensional annotations (centrelines, centremarks, text) attached to this drawing.
    public var annotations: [DrawingAnnotation] { annotationStore.annotations }

    @discardableResult
    public func addLinearDimension(from: SIMD2<Double>, to: SIMD2<Double>,
                                   offset: Double = 10,
                                   label: String? = nil,
                                   style: DrawingLineStyle = .solid,
                                   id: String? = nil) -> DrawingDimension {
        let d = DrawingDimension.linear(.init(from: from, to: to, offset: offset,
                                              label: label, style: style, id: id))
        annotationStore.appendDimension(d)
        return d
    }

    @discardableResult
    public func addRadialDimension(centre: SIMD2<Double>, radius: Double,
                                   leaderAngle: Double = .pi / 4,
                                   label: String? = nil,
                                   style: DrawingLineStyle = .solid,
                                   id: String? = nil) -> DrawingDimension {
        let d = DrawingDimension.radial(.init(centre: centre, radius: radius,
                                              leaderAngle: leaderAngle,
                                              label: label, style: style, id: id))
        annotationStore.appendDimension(d)
        return d
    }

    @discardableResult
    public func addDiameterDimension(centre: SIMD2<Double>, radius: Double,
                                     leaderAngle: Double = .pi / 4,
                                     label: String? = nil,
                                     style: DrawingLineStyle = .solid,
                                     id: String? = nil) -> DrawingDimension {
        let d = DrawingDimension.diameter(.init(centre: centre, radius: radius,
                                                leaderAngle: leaderAngle,
                                                label: label, style: style, id: id))
        annotationStore.appendDimension(d)
        return d
    }

    @discardableResult
    public func addAngularDimension(vertex: SIMD2<Double>,
                                    ray1: SIMD2<Double>,
                                    ray2: SIMD2<Double>,
                                    arcRadius: Double = 20,
                                    label: String? = nil,
                                    style: DrawingLineStyle = .solid,
                                    id: String? = nil) -> DrawingDimension {
        let d = DrawingDimension.angular(.init(vertex: vertex, ray1: ray1, ray2: ray2,
                                               arcRadius: arcRadius,
                                               label: label, style: style, id: id))
        annotationStore.appendDimension(d)
        return d
    }

    @discardableResult
    public func addCentreLine(from: SIMD2<Double>, to: SIMD2<Double>,
                              style: DrawingLineStyle = .chain,
                              id: String? = nil) -> DrawingAnnotation {
        let a = DrawingAnnotation.centreline(.init(from: from, to: to, style: style, id: id))
        annotationStore.appendAnnotation(a)
        return a
    }

    @discardableResult
    public func addCentermark(centre: SIMD2<Double>, extent: Double = 8,
                              style: DrawingLineStyle = .chain,
                              id: String? = nil) -> DrawingAnnotation {
        let a = DrawingAnnotation.centermark(.init(centre: centre, extent: extent, style: style, id: id))
        annotationStore.appendAnnotation(a)
        return a
    }

    @discardableResult
    public func addTextLabel(_ text: String, at position: SIMD2<Double>,
                             height: Double = 3.5, rotation: Double = 0,
                             id: String? = nil) -> DrawingAnnotation {
        let a = DrawingAnnotation.textLabel(.init(position: position, text: text,
                                                  height: height, rotation: rotation, id: id))
        annotationStore.appendAnnotation(a)
        return a
    }

    /// ISO 128-50 section-view hatching over a closed boundary polygon. Angle
    /// defaults to 45° and spacing to 3 mm per ISO convention. `islands` are
    /// optional inner boundaries excluded from the fill.
    @discardableResult
    public func addHatch(boundary: [SIMD2<Double>],
                         angle: Double = .pi / 4,
                         spacing: Double = 3.0,
                         islands: [[SIMD2<Double>]] = [],
                         layer: String = "HATCH",
                         id: String? = nil) -> DrawingAnnotation {
        let a = DrawingAnnotation.hatch(.init(boundary: boundary, angle: angle,
                                              spacing: spacing, islands: islands,
                                              layer: layer, id: id))
        annotationStore.appendAnnotation(a)
        return a
    }

    /// Remove all dimensions and annotations from this drawing.
    public func clearAnnotations() { annotationStore.clear() }

    // MARK: - Creation

    /// Create a 2D projection of a 3D shape
    ///
    /// - Parameters:
    ///   - shape: The 3D shape to project
    ///   - direction: View direction (the direction you're looking from)
    ///   - type: Projection type (orthographic or perspective)
    /// - Returns: Drawing containing the projected edges, or nil if projection fails
    public static func project(
        _ shape: Shape,
        direction: SIMD3<Double>,
        type: ProjectionType = .orthographic
    ) -> Drawing? {
        guard let handle = OCCTDrawingCreate(
            shape.handle,
            direction.x, direction.y, direction.z,
            OCCTProjectionType(rawValue: type.rawValue)
        ) else {
            return nil
        }
        return Drawing(handle: handle)
    }

    // MARK: - Standard Views

    /// Create a top view (looking down Z axis)
    public static func topView(of shape: Shape) -> Drawing? {
        project(shape, direction: SIMD3(0, 0, 1))
    }

    /// Create a front view (looking down Y axis)
    public static func frontView(of shape: Shape) -> Drawing? {
        project(shape, direction: SIMD3(0, 1, 0))
    }

    /// Create a side view (looking down X axis)
    public static func sideView(of shape: Shape) -> Drawing? {
        project(shape, direction: SIMD3(1, 0, 0))
    }

    /// Create an isometric view
    public static func isometricView(of shape: Shape) -> Drawing? {
        let dir = SIMD3<Double>(1, 1, 1) / sqrt(3.0)
        return project(shape, direction: dir)
    }

    // MARK: - Fast Polygon-Based Projection (v0.39.0)

    /// Create a fast polygon-based 2D projection of a 3D shape.
    ///
    /// Uses the triangulation mesh rather than exact geometry for significantly faster
    /// HLR computation. The result is approximate but perfectly adequate for interactive
    /// previews and most technical drawing use cases.
    /// - Parameters:
    ///   - shape: The 3D shape to project
    ///   - direction: View direction
    ///   - deflection: Mesh deflection (smaller = more accurate, default 0.01)
    /// - Returns: Drawing containing the projected edges, or nil if projection fails
    public static func projectFast(
        _ shape: Shape,
        direction: SIMD3<Double>,
        deflection: Double = 0.01
    ) -> Drawing? {
        guard let handle = OCCTDrawingCreatePoly(
            shape.handle,
            direction.x, direction.y, direction.z,
            0, deflection
        ) else {
            return nil
        }
        return Drawing(handle: handle)
    }

    /// Create a fast top view using polygon-based HLR
    public static func fastTopView(of shape: Shape, deflection: Double = 0.01) -> Drawing? {
        projectFast(shape, direction: SIMD3(0, 0, 1), deflection: deflection)
    }

    /// Create a fast isometric view using polygon-based HLR
    public static func fastIsometricView(of shape: Shape, deflection: Double = 0.01) -> Drawing? {
        let dir = SIMD3<Double>(1, 1, 1) / sqrt(3.0)
        return projectFast(shape, direction: dir, deflection: deflection)
    }

    // MARK: - Edge Access

    /// Get projected edges of a specific type as a compound shape
    ///
    /// - Parameter type: The type of edges to retrieve
    /// - Returns: Shape containing the 2D edges, or nil if no edges of that type
    public func edges(ofType type: EdgeType) -> Shape? {
        guard let shapeHandle = OCCTDrawingGetEdges(handle, OCCTEdgeType(rawValue: type.rawValue)) else {
            return nil
        }
        return Shape(handle: shapeHandle)
    }

    /// Get visible edges as a shape
    public var visibleEdges: Shape? {
        edges(ofType: .visible)
    }

    /// Get hidden edges as a shape
    public var hiddenEdges: Shape? {
        edges(ofType: .hidden)
    }

    /// Get outline/silhouette edges as a shape
    public var outlineEdges: Shape? {
        edges(ofType: .outline)
    }

}

// MARK: - Errors

/// Errors that can occur when working with 2D drawings
public enum DrawingError: Error, LocalizedError {
    case projectionFailed

    public var errorDescription: String? {
        switch self {
        case .projectionFailed:
            return "Failed to create 2D projection"
        }
    }
}
