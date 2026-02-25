import Foundation
import OCCTBridge

/// Results from polynomial root solving.
public struct PolynomialRoots: Sendable {
    /// The real roots found, sorted ascending.
    public let roots: [Double]

    /// Number of real roots found.
    public var count: Int { roots.count }
}

/// Analytical polynomial solvers for degrees 2-4.
///
/// Uses OCCT's numerically stable implementations with
/// Newton-Raphson refinement and degenerate case handling.
///
/// ## Example
///
/// ```swift
/// // Solve x² - 5x + 6 = 0  →  x = 2, 3
/// let result = PolynomialSolver.quadratic(a: 1, b: -5, c: 6)
/// // result.roots == [2.0, 3.0]
///
/// // Solve x³ - 6x² + 11x - 6 = 0  →  x = 1, 2, 3
/// let cubic = PolynomialSolver.cubic(a: 1, b: -6, c: 11, d: -6)
/// ```
public enum PolynomialSolver {
    /// Solve a quadratic equation: ax² + bx + c = 0
    ///
    /// - Returns: 0, 1, or 2 real roots sorted ascending
    public static func quadratic(a: Double, b: Double, c: Double) -> PolynomialRoots {
        let result = OCCTSolveQuadratic(a, b, c)
        let n = Int(result.count)
        var roots = [Double]()
        if n > 0 { roots.append(result.roots.0) }
        if n > 1 { roots.append(result.roots.1) }
        return PolynomialRoots(roots: roots)
    }

    /// Solve a cubic equation: ax³ + bx² + cx + d = 0
    ///
    /// - Returns: 1, 2, or 3 real roots sorted ascending
    public static func cubic(a: Double, b: Double, c: Double, d: Double) -> PolynomialRoots {
        let result = OCCTSolveCubic(a, b, c, d)
        let n = Int(result.count)
        var roots = [Double]()
        if n > 0 { roots.append(result.roots.0) }
        if n > 1 { roots.append(result.roots.1) }
        if n > 2 { roots.append(result.roots.2) }
        return PolynomialRoots(roots: roots)
    }

    /// Solve a quartic equation: ax⁴ + bx³ + cx² + dx + e = 0
    ///
    /// - Returns: 0-4 real roots sorted ascending
    public static func quartic(a: Double, b: Double, c: Double, d: Double, e: Double) -> PolynomialRoots {
        let result = OCCTSolveQuartic(a, b, c, d, e)
        let n = Int(result.count)
        var roots = [Double]()
        if n > 0 { roots.append(result.roots.0) }
        if n > 1 { roots.append(result.roots.1) }
        if n > 2 { roots.append(result.roots.2) }
        if n > 3 { roots.append(result.roots.3) }
        return PolynomialRoots(roots: roots)
    }
}
