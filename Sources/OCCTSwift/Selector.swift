import Foundation
import simd
import OCCTBridge

/// BVH-accelerated hit testing for interactive picking without OpenGL.
///
/// Manages a set of shapes identified by integer IDs and performs
/// point or rectangle picking against them using a camera's projection.
public final class Selector: @unchecked Sendable {
    let handle: OCCTSelectorRef

    /// Result of a pick operation.
    public struct PickResult: Sendable {
        /// The shape ID that was assigned when adding the shape.
        public let shapeId: Int32

        /// Depth of the hit (distance from camera).
        public let depth: Double

        /// 3D world-space point where the pick intersected.
        public let point: SIMD3<Double>
    }

    public init() {
        handle = OCCTSelectorCreate()
    }

    deinit {
        OCCTSelectorDestroy(handle)
    }

    /// Add a shape to the selector with a unique integer ID.
    ///
    /// If a shape with the same ID already exists, it is replaced.
    /// - Returns: `true` if the shape was added successfully.
    @discardableResult
    public func add(shape: Shape, id: Int32) -> Bool {
        OCCTSelectorAddShape(handle, shape.handle, id)
    }

    /// Remove a shape by its ID.
    /// - Returns: `true` if the shape was found and removed.
    @discardableResult
    public func remove(id: Int32) -> Bool {
        OCCTSelectorRemoveShape(handle, id)
    }

    /// Remove all shapes from the selector.
    public func clearAll() {
        OCCTSelectorClear(handle)
    }

    /// Pick shapes at a single pixel coordinate.
    ///
    /// - Parameters:
    ///   - pixel: Pixel coordinates in the viewport.
    ///   - camera: The camera providing projection/view transforms.
    ///   - viewSize: Viewport size in pixels (width, height).
    ///   - maxResults: Maximum number of results to return (default 32).
    /// - Returns: Array of pick results sorted by depth (nearest first).
    public func pick(at pixel: SIMD2<Double>,
                     camera: Camera,
                     viewSize: SIMD2<Double>,
                     maxResults: Int = 32) -> [PickResult] {
        var buffer = [OCCTPickResult](repeating: OCCTPickResult(), count: maxResults)
        let count = OCCTSelectorPick(handle, camera.handle,
                                     viewSize.x, viewSize.y,
                                     pixel.x, pixel.y,
                                     &buffer, Int32(maxResults))
        return (0..<Int(count)).map { i in
            PickResult(shapeId: buffer[i].shapeId,
                       depth: buffer[i].depth,
                       point: SIMD3(buffer[i].pointX, buffer[i].pointY, buffer[i].pointZ))
        }
    }

    /// Pick shapes within a rectangular region.
    ///
    /// - Parameters:
    ///   - rect: Rectangle defined by (min, max) pixel coordinates.
    ///   - camera: The camera providing projection/view transforms.
    ///   - viewSize: Viewport size in pixels (width, height).
    ///   - maxResults: Maximum number of results to return (default 32).
    /// - Returns: Array of pick results for all shapes intersecting the rectangle.
    public func pick(rect: (min: SIMD2<Double>, max: SIMD2<Double>),
                     camera: Camera,
                     viewSize: SIMD2<Double>,
                     maxResults: Int = 32) -> [PickResult] {
        var buffer = [OCCTPickResult](repeating: OCCTPickResult(), count: maxResults)
        let count = OCCTSelectorPickRect(handle, camera.handle,
                                         viewSize.x, viewSize.y,
                                         rect.min.x, rect.min.y,
                                         rect.max.x, rect.max.y,
                                         &buffer, Int32(maxResults))
        return (0..<Int(count)).map { i in
            PickResult(shapeId: buffer[i].shapeId,
                       depth: buffer[i].depth,
                       point: SIMD3(buffer[i].pointX, buffer[i].pointY, buffer[i].pointZ))
        }
    }
}
