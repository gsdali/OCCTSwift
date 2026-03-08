import Foundation
import OCCTBridge

/// An evolution function defining how a scalar value varies along a parameter range.
///
/// Used with `Shape.pipeShellWithLaw()` for variable-section sweeps where the
/// cross-section scales smoothly along the spine path.
public final class LawFunction: @unchecked Sendable {
    internal let handle: OCCTLawFunctionRef

    internal init(handle: OCCTLawFunctionRef) {
        self.handle = handle
    }

    deinit {
        OCCTLawFunctionRelease(handle)
    }

    // MARK: - Evaluation

    /// Evaluate the law function at a given parameter
    public func value(at parameter: Double) -> Double {
        OCCTLawFunctionValue(handle, parameter)
    }

    /// Parameter bounds of the law function
    public var bounds: ClosedRange<Double> {
        var first: Double = 0, last: Double = 0
        OCCTLawFunctionBounds(handle, &first, &last)
        return first...last
    }

    // MARK: - Factory Methods

    /// Create a constant law: the value is uniform over [first, last]
    public static func constant(_ value: Double, from first: Double = 0,
                                to last: Double = 1) -> LawFunction? {
        guard let h = OCCTLawCreateConstant(value, first, last) else { return nil }
        return LawFunction(handle: h)
    }

    /// Create a linear law: value ramps from startValue to endValue
    public static func linear(from startValue: Double, to endValue: Double,
                              parameterRange: ClosedRange<Double> = 0...1) -> LawFunction? {
        guard let h = OCCTLawCreateLinear(parameterRange.lowerBound, startValue,
                                           parameterRange.upperBound, endValue)
        else { return nil }
        return LawFunction(handle: h)
    }

    /// Create an S-curve law: smooth sigmoid transition between start and end values
    public static func sCurve(from startValue: Double, to endValue: Double,
                              parameterRange: ClosedRange<Double> = 0...1) -> LawFunction? {
        guard let h = OCCTLawCreateS(parameterRange.lowerBound, startValue,
                                      parameterRange.upperBound, endValue)
        else { return nil }
        return LawFunction(handle: h)
    }

    /// Create an interpolated law from (parameter, value) pairs
    /// - Parameters:
    ///   - points: Array of (parameter, value) tuples in ascending parameter order
    ///   - periodic: Whether the law is periodic
    public static func interpolate(points: [(parameter: Double, value: Double)],
                                   periodic: Bool = false) -> LawFunction? {
        guard points.count >= 2 else { return nil }
        var flat = [Double]()
        flat.reserveCapacity(points.count * 2)
        for pt in points {
            flat.append(pt.parameter)
            flat.append(pt.value)
        }
        let h = flat.withUnsafeBufferPointer { ptr in
            OCCTLawCreateInterpolate(ptr.baseAddress, Int32(points.count), periodic)
        }
        guard let h = h else { return nil }
        return LawFunction(handle: h)
    }

    /// Create a BSpline law from control poles and knot vector
    /// - Parameters:
    ///   - poles: Control point values (1D)
    ///   - knots: Knot values
    ///   - multiplicities: Knot multiplicities
    ///   - degree: Polynomial degree
    public static func bspline(poles: [Double], knots: [Double],
                               multiplicities: [Int32],
                               degree: Int) -> LawFunction? {
        guard poles.count >= 2, knots.count >= 2 else { return nil }
        let h = poles.withUnsafeBufferPointer { pPtr in
            knots.withUnsafeBufferPointer { kPtr in
                multiplicities.withUnsafeBufferPointer { mPtr in
                    OCCTLawCreateBSpline(pPtr.baseAddress, Int32(poles.count),
                                         kPtr.baseAddress, Int32(knots.count),
                                         mPtr.baseAddress, Int32(degree))
                }
            }
        }
        guard let h = h else { return nil }
        return LawFunction(handle: h)
    }

    // MARK: - v0.68.0: Composite Law and Knot Splitting

    /// Create a composite law by stitching multiple sub-laws together.
    ///
    /// - Parameters:
    ///   - laws: Array of sub-law functions in parameter order
    ///   - range: Overall parametric range
    /// - Returns: Composite law function
    public static func composite(laws: [LawFunction],
                                 range: ClosedRange<Double> = 0...1) -> LawFunction? {
        guard laws.count >= 1 else { return nil }
        let handles = laws.map { $0.handle as OCCTLawFunctionRef }
        return handles.withUnsafeBufferPointer { buf in
            guard let h = OCCTLawComposite(buf.baseAddress!, Int32(laws.count),
                range.lowerBound, range.upperBound) else { return nil as LawFunction? }
            return LawFunction(handle: h)
        }
    }

    /// Find knot indices where a BSpline law drops below given continuity.
    ///
    /// Only works on BSpline-based law functions.
    ///
    /// - Parameter continuityOrder: Continuity level (0=C0, 1=C1, 2=C2)
    /// - Returns: Array of knot indices where continuity breaks, or empty array
    public func knotSplitting(continuityOrder: Int = 2) -> [Int] {
        let maxIndices: Int32 = 100
        var indices = [Int32](repeating: 0, count: Int(maxIndices))
        let count = OCCTLawBSplineKnotSplitting(handle, Int32(continuityOrder), &indices, maxIndices)
        return (0..<Int(count)).map { Int(indices[$0]) }
    }
}
