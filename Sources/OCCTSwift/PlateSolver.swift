import Foundation
import OCCTBridge

/// A thin plate spline solver for surface deformation.
///
/// `PlateSolver` provides direct access to the OCCT `Plate_Plate` variational
/// solver. It computes a smooth displacement field that passes through a set
/// of pinpoint constraints (position and/or derivative) while minimizing bending energy.
///
/// Unlike the higher-level NLPlate methods on `Surface`, `PlateSolver` works
/// directly in the UV parameter space and returns raw XYZ displacements.
///
/// Usage:
/// ```swift
/// let solver = PlateSolver()
/// solver.loadPinpoint(u: 0, v: 0, position: .zero)
/// solver.loadPinpoint(u: 1, v: 0, position: SIMD3(1, 0, 0))
/// solver.loadPinpoint(u: 0.5, v: 0.5, position: SIMD3(0.5, 0.5, 1.0))
/// if solver.solve() {
///     let point = solver.evaluate(u: 0.5, v: 0.5)
/// }
/// ```
public final class PlateSolver: @unchecked Sendable {
    private let handle: OCCTPlateRef

    /// Create a new Plate solver.
    public init() {
        self.handle = OCCTPlateCreate()!
    }

    deinit {
        OCCTPlateRelease(handle)
    }

    // MARK: - Loading Constraints

    /// Load a pinpoint constraint (position at a UV point).
    ///
    /// - Parameters:
    ///   - u: U parameter
    ///   - v: V parameter
    ///   - position: Target 3D position
    public func loadPinpoint(u: Double, v: Double, position: SIMD3<Double>) {
        OCCTPlateLoadPinpoint(handle, u, v, position.x, position.y, position.z, 0, 0)
    }

    /// Load a derivative constraint at a UV point.
    ///
    /// - Parameters:
    ///   - u: U parameter
    ///   - v: V parameter
    ///   - value: Target derivative value
    ///   - derivativeOrderU: U derivative order (0 for position, 1+ for derivatives)
    ///   - derivativeOrderV: V derivative order
    public func loadDerivativeConstraint(u: Double, v: Double, value: SIMD3<Double>,
                                          derivativeOrderU: Int, derivativeOrderV: Int) {
        OCCTPlateLoadPinpoint(handle, u, v, value.x, value.y, value.z,
                              Int32(derivativeOrderU), Int32(derivativeOrderV))
    }

    /// Load a geometric-to-continuity (GtoC) constraint at G1 level.
    ///
    /// Constrains the surface derivatives to transition from one tangent frame
    /// to another at a given UV point.
    ///
    /// - Parameters:
    ///   - u: U parameter
    ///   - v: V parameter
    ///   - sourceD1: Source surface first derivatives (tangentU, tangentV) as flat 6 doubles
    ///   - targetD1: Target surface first derivatives
    public func loadGtoC(u: Double, v: Double,
                          sourceD1: (tangentU: SIMD3<Double>, tangentV: SIMD3<Double>),
                          targetD1: (tangentU: SIMD3<Double>, tangentV: SIMD3<Double>)) {
        var d1s: [Double] = [sourceD1.tangentU.x, sourceD1.tangentU.y, sourceD1.tangentU.z,
                             sourceD1.tangentV.x, sourceD1.tangentV.y, sourceD1.tangentV.z]
        var d1t: [Double] = [targetD1.tangentU.x, targetD1.tangentU.y, targetD1.tangentU.z,
                             targetD1.tangentV.x, targetD1.tangentV.y, targetD1.tangentV.z]
        OCCTPlateLoadGtoC(handle, u, v, &d1s, &d1t)
    }

    // MARK: - Solving

    /// Solve the plate system.
    ///
    /// - Parameters:
    ///   - order: Solution polynomial order (default 4)
    ///   - anisotropy: Anisotropy parameter (default 1.0)
    /// - Returns: true if solve succeeded
    @discardableResult
    public func solve(order: Int = 4, anisotropy: Double = 1.0) -> Bool {
        OCCTPlateSolve(handle, Int32(order), anisotropy)
    }

    /// Check if the last solve succeeded.
    public var isDone: Bool {
        OCCTPlateIsDone(handle)
    }

    // MARK: - Evaluation

    /// Evaluate the plate at a UV point.
    ///
    /// Returns the 3D displacement/position computed by the solver.
    /// Must call `solve()` first.
    public func evaluate(u: Double, v: Double) -> SIMD3<Double> {
        var x: Double = 0, y: Double = 0, z: Double = 0
        OCCTPlateEvaluate(handle, u, v, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Evaluate a derivative at a UV point.
    ///
    /// - Parameters:
    ///   - u: U parameter
    ///   - v: V parameter
    ///   - derivativeOrderU: U derivative order
    ///   - derivativeOrderV: V derivative order
    public func evaluateDerivative(u: Double, v: Double,
                                    derivativeOrderU: Int, derivativeOrderV: Int) -> SIMD3<Double> {
        var x: Double = 0, y: Double = 0, z: Double = 0
        OCCTPlateEvaluateDerivative(handle, u, v, Int32(derivativeOrderU), Int32(derivativeOrderV),
                                    &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// UV bounding box of the constraint points.
    public var uvBox: (umin: Double, umax: Double, vmin: Double, vmax: Double) {
        var umin: Double = 0, umax: Double = 0, vmin: Double = 0, vmax: Double = 0
        OCCTPlateUVBox(handle, &umin, &umax, &vmin, &vmax)
        return (umin, umax, vmin, vmax)
    }

    /// Continuity order of the plate solution.
    public var continuity: Int {
        Int(OCCTPlateContinuity(handle))
    }
}
