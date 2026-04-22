import Foundation
import simd

// MARK: - Auto-centreline generation from #65 revolution axes
//
// Given a Drawing produced by projecting a Shape, extend the drawing with
// centrelines corresponding to the shape's axes of revolution. The axis is
// projected into the view plane and clipped to the drawing's 2D bounding box
// with a configurable overshoot.

extension Drawing {
    /// Result of auto-centreline generation, returned separately so callers can
    /// inspect what was added without re-querying `annotations`.
    public struct AutoCentrelineResult: Sendable {
        public let added: [DrawingAnnotation]
        public let skipped: [ShapeAxis]        // axes that projected to a point in view
    }

    /// Project the shape's axes of revolution into this drawing's view plane and
    /// add them as `.chain` centrelines.
    ///
    /// - Parameters:
    ///   - shape: The source 3D shape (typically the one this drawing was projected from).
    ///   - viewDirection: The projection direction used to create this drawing. Pass the same
    ///     vector you used for `Drawing.project(_:direction:)`; assumed unit-length.
    ///   - overshoot: Extra length (drawing units) added past the drawing bounding box on
    ///     both ends of the projected axis. Default 5.
    ///   - tolerance: Axis-deduplication tolerance passed to `Shape.revolutionAxes`.
    ///   - bounds: Optional override for the 2D bounding box used for clipping. When nil,
    ///     falls back to a sensible default (±1000 square centred at origin) — the caller
    ///     should pass the drawing's actual bbox when it's known.
    @discardableResult
    public func addAutoCentrelines(from shape: Shape,
                                   viewDirection: SIMD3<Double>,
                                   overshoot: Double = 5,
                                   tolerance: Double = 1e-6,
                                   bounds: (min: SIMD2<Double>, max: SIMD2<Double>)? = nil) -> AutoCentrelineResult {
        let axes = shape.revolutionAxes(tolerance: tolerance)
        let bb = bounds ?? (min: SIMD2(-1000, -1000), max: SIMD2(1000, 1000))
        var added: [DrawingAnnotation] = []
        var skipped: [ShapeAxis] = []
        let viewZ = simd_normalize(viewDirection)

        for axis in axes {
            guard let (p1, p2) = projectAxisToPlane(origin: axis.origin,
                                                     direction: axis.direction,
                                                     viewDirection: viewZ,
                                                     bounds: bb,
                                                     overshoot: overshoot) else {
                skipped.append(axis)
                continue
            }
            let ann = addCentreLine(from: p1, to: p2, id: "auto-\(axis.kind)-\(added.count)")
            added.append(ann)
        }
        return AutoCentrelineResult(added: added, skipped: skipped)
    }
}

/// Project a 3D axis (origin + direction) into the 2D plane perpendicular to
/// `viewDirection` and clip to the given bounds. Returns nil if the axis projects
/// to a point (i.e. it is parallel to the view direction).
///
/// The 2D coordinate frame follows OCCT's HLR convention used by `Drawing.project`:
/// X goes along the projection's right axis and Y along the up axis. We recover
/// these by orthogonalising against an arbitrary up vector.
internal func projectAxisToPlane(origin: SIMD3<Double>,
                                  direction: SIMD3<Double>,
                                  viewDirection: SIMD3<Double>,
                                  bounds: (min: SIMD2<Double>, max: SIMD2<Double>),
                                  overshoot: Double) -> (SIMD2<Double>, SIMD2<Double>)? {
    // Build a basis (right, up) perpendicular to viewDirection.
    let worldUp = SIMD3<Double>(0, 0, 1)
    var rightRaw = simd_cross(worldUp, viewDirection)
    if simd_length(rightRaw) < 1e-9 {
        rightRaw = simd_cross(SIMD3(0, 1, 0), viewDirection)
    }
    let right = simd_normalize(rightRaw)
    let up = simd_normalize(simd_cross(viewDirection, right))

    // Project axis direction onto view plane. If it collapses to a point, skip.
    let dir2 = SIMD2(simd_dot(direction, right), simd_dot(direction, up))
    if simd_length(dir2) < 1e-9 { return nil }
    let dir2n = simd_normalize(dir2)
    let origin2 = SIMD2(simd_dot(origin, right), simd_dot(origin, up))

    // Parameterise the line as origin2 + t * dir2n and clip to bounds.
    var tMin = -Double.infinity
    var tMax = Double.infinity
    // X slab
    if abs(dir2n.x) > 1e-12 {
        let t1 = (bounds.min.x - origin2.x) / dir2n.x
        let t2 = (bounds.max.x - origin2.x) / dir2n.x
        tMin = max(tMin, min(t1, t2))
        tMax = min(tMax, max(t1, t2))
    } else if origin2.x < bounds.min.x || origin2.x > bounds.max.x {
        return nil
    }
    // Y slab
    if abs(dir2n.y) > 1e-12 {
        let t1 = (bounds.min.y - origin2.y) / dir2n.y
        let t2 = (bounds.max.y - origin2.y) / dir2n.y
        tMin = max(tMin, min(t1, t2))
        tMax = min(tMax, max(t1, t2))
    } else if origin2.y < bounds.min.y || origin2.y > bounds.max.y {
        return nil
    }
    if tMin >= tMax { return nil }
    let p1 = origin2 + (tMin - overshoot) * dir2n
    let p2 = origin2 + (tMax + overshoot) * dir2n
    return (p1, p2)
}
