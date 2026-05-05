//
//  OCCTBridge_Spatial.mm
//  OCCTSwift
//
//  Per-OCCT-module TU for spatial / numerical helpers:
//
//  - NCollection_KDTree spatial queries (nearest / k-NN / range / box)
//  - math_DirectPolynomialRoots (quadratic / cubic / quartic solvers)
//  - Bnd_OBB oriented bounding box helpers (when Topology delegates)
//
//  Public C surface unchanged. No symbol changes — pure file move.
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

#include <Intrv_Interval.hxx>
#include <Intrv_Intervals.hxx>
#include <NCollection_Array1.hxx>
#include <NCollection_KDTree.hxx>
#include <math_DirectPolynomialRoots.hxx>

#include <gp_Pnt.hxx>
#include <gp_Lin.hxx>
#include <gp_Pln.hxx>
#include <gp_Circ.hxx>
#include <gp_Sphere.hxx>
#include <gp_Torus.hxx>
#include <Precision.hxx>
#include <Bnd_Sphere.hxx>
#include <BndLib.hxx>
#include <BndLib_Add3dCurve.hxx>
#include <BndLib_AddSurface.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <gp_Cylinder.hxx>
#include <gp_Cone.hxx>
#include <IntAna_QuadQuadGeo.hxx>
#include <TopoDS.hxx>
#include <TopAbs.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <GProp_PEquation.hxx>

#include <algorithm>
#include <cmath>
#include <vector>

// MARK: - KD-Tree Spatial Queries (v0.28.0)

#include <NCollection_KDTree.hxx>

struct OCCTKDTree {
    NCollection_KDTree<gp_Pnt, 3> tree;
    std::vector<gp_Pnt> points;
};

OCCTKDTreeRef OCCTKDTreeBuild(const double* coords, int32_t count) {
    if (!coords || count <= 0) return nullptr;
    try {
        auto* kd = new OCCTKDTree();
        kd->points.resize(count);
        for (int32_t i = 0; i < count; i++) {
            kd->points[i] = gp_Pnt(coords[i*3], coords[i*3+1], coords[i*3+2]);
        }
        kd->tree.Build(kd->points.data(), (size_t)count);
        return kd;
    } catch (...) {
        return nullptr;
    }
}

void OCCTKDTreeRelease(OCCTKDTreeRef tree) {
    delete tree;
}

int32_t OCCTKDTreeNearestPoint(OCCTKDTreeRef tree,
                                double qx, double qy, double qz,
                                double* outDistance) {
    if (!tree || tree->tree.IsEmpty()) return -1;
    try {
        gp_Pnt query(qx, qy, qz);
        double sqDist = 0;
        size_t idx = tree->tree.NearestPoint(query, sqDist);
        if (outDistance) *outDistance = std::sqrt(sqDist);
        return (int32_t)(idx - 1); // OCCT uses 1-based → convert to 0-based
    } catch (...) {
        return -1;
    }
}

int32_t OCCTKDTreeKNearest(OCCTKDTreeRef tree,
                            double qx, double qy, double qz,
                            int32_t k,
                            int32_t* outIndices,
                            double* outSqDistances) {
    if (!tree || !outIndices || k <= 0 || tree->tree.IsEmpty()) return 0;
    try {
        gp_Pnt query(qx, qy, qz);
        NCollection_Array1<size_t> indices(1, k);
        NCollection_Array1<double> distances(1, k);
        size_t found = tree->tree.KNearestPoints(query, (size_t)k, indices, distances);

        int32_t n = (int32_t)found;
        for (int32_t i = 0; i < n; i++) {
            outIndices[i] = (int32_t)(indices.Value(i + 1) - 1); // 1-based → 0-based
        }
        if (outSqDistances) {
            for (int32_t i = 0; i < n; i++) {
                outSqDistances[i] = distances.Value(i + 1);
            }
        }
        return n;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTKDTreeRangeSearch(OCCTKDTreeRef tree,
                               double qx, double qy, double qz,
                               double radius,
                               int32_t* outIndices, int32_t maxResults) {
    if (!tree || !outIndices || maxResults <= 0 || tree->tree.IsEmpty()) return 0;
    try {
        gp_Pnt query(qx, qy, qz);
        auto results = tree->tree.RangeSearch(query, radius);

        int32_t n = std::min((int32_t)results.Size(), maxResults);
        for (int32_t i = 0; i < n; i++) {
            outIndices[i] = (int32_t)(results[i] - 1); // 1-based → 0-based
        }
        return n;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTKDTreeBoxSearch(OCCTKDTreeRef tree,
                             double minX, double minY, double minZ,
                             double maxX, double maxY, double maxZ,
                             int32_t* outIndices, int32_t maxResults) {
    if (!tree || !outIndices || maxResults <= 0 || tree->tree.IsEmpty()) return 0;
    try {
        gp_Pnt minPt(minX, minY, minZ);
        gp_Pnt maxPt(maxX, maxY, maxZ);
        auto results = tree->tree.BoxSearch(minPt, maxPt);

        int32_t n = std::min((int32_t)results.Size(), maxResults);
        for (int32_t i = 0; i < n; i++) {
            outIndices[i] = (int32_t)(results[i] - 1); // 1-based → 0-based
        }
        return n;
    } catch (...) {
        return 0;
    }
}
// MARK: - Polynomial Solvers (v0.29.0)

#include <math_DirectPolynomialRoots.hxx>
#include <algorithm>

OCCTPolynomialRoots OCCTSolveQuadratic(double a, double b, double c) {
    OCCTPolynomialRoots result;
    result.count = 0;
    result.roots[0] = result.roots[1] = result.roots[2] = result.roots[3] = 0.0;
    try {
        math_DirectPolynomialRoots solver(a, b, c);
        if (!solver.IsDone()) return result;
        result.count = std::min(solver.NbSolutions(), 4);
        for (int i = 0; i < result.count; i++) {
            result.roots[i] = solver.Value(i + 1);
        }
        std::sort(result.roots, result.roots + result.count);
    } catch (...) {}
    return result;
}

OCCTPolynomialRoots OCCTSolveCubic(double a, double b, double c, double d) {
    OCCTPolynomialRoots result;
    result.count = 0;
    result.roots[0] = result.roots[1] = result.roots[2] = result.roots[3] = 0.0;
    try {
        math_DirectPolynomialRoots solver(a, b, c, d);
        if (!solver.IsDone()) return result;
        result.count = std::min(solver.NbSolutions(), 4);
        for (int i = 0; i < result.count; i++) {
            result.roots[i] = solver.Value(i + 1);
        }
        std::sort(result.roots, result.roots + result.count);
    } catch (...) {}
    return result;
}

OCCTPolynomialRoots OCCTSolveQuartic(double a, double b, double c, double d, double e) {
    OCCTPolynomialRoots result;
    result.count = 0;
    result.roots[0] = result.roots[1] = result.roots[2] = result.roots[3] = 0.0;
    try {
        math_DirectPolynomialRoots solver(a, b, c, d, e);
        if (!solver.IsDone()) return result;
        result.count = std::min(solver.NbSolutions(), 4);
        for (int i = 0; i < result.count; i++) {
            result.roots[i] = solver.Value(i + 1);
        }
        std::sort(result.roots, result.roots + result.count);
    } catch (...) {}
    return result;
}


bool OCCTAnalyzePointCloud(const double* coords, int32_t pointCount,
                            double tolerance, OCCTPointCloudGeometry* outResult) {
    if (!coords || pointCount < 1 || !outResult) return false;
    try {
        TColgp_Array1OfPnt pts(1, pointCount);
        for (int32_t i = 0; i < pointCount; i++) {
            pts.SetValue(i + 1, gp_Pnt(coords[i*3], coords[i*3+1], coords[i*3+2]));
        }

        GProp_PEquation eq(pts, tolerance);

        if (eq.IsPoint()) {
            outResult->type = 0;
            gp_Pnt pt = eq.Point();
            outResult->pointX = pt.X();
            outResult->pointY = pt.Y();
            outResult->pointZ = pt.Z();
        } else if (eq.IsLinear()) {
            outResult->type = 1;
            gp_Lin lin = eq.Line();
            gp_Pnt o = lin.Location();
            gp_Dir d = lin.Direction();
            outResult->pointX = o.X();
            outResult->pointY = o.Y();
            outResult->pointZ = o.Z();
            outResult->dirX = d.X();
            outResult->dirY = d.Y();
            outResult->dirZ = d.Z();
        } else if (eq.IsPlanar()) {
            outResult->type = 2;
            gp_Pln pln = eq.Plane();
            gp_Pnt o = pln.Location();
            gp_Dir n = pln.Axis().Direction();
            outResult->pointX = o.X();
            outResult->pointY = o.Y();
            outResult->pointZ = o.Z();
            outResult->normalX = n.X();
            outResult->normalY = n.Y();
            outResult->normalZ = n.Z();
        } else {
            outResult->type = 3;
            // No specific geometry for space points
        }
        return true;
    } catch (...) {
        return false;
    }
}

// MARK: - Intrv_Interval (v0.73)
// --- Intrv_Interval ---

struct OCCTIntrvInterval {
    Intrv_Interval interval;
};

OCCTIntrvIntervalRef _Nonnull OCCTIntrvIntervalCreate(double start, double end,
    float tolStart, float tolEnd) {
    auto* ref = new OCCTIntrvInterval();
    ref->interval = Intrv_Interval(start, tolStart, end, tolEnd);
    return ref;
}

void OCCTIntrvIntervalRelease(OCCTIntrvIntervalRef _Nonnull interval) {
    delete interval;
}

OCCTIntrvBounds OCCTIntrvIntervalBounds(OCCTIntrvIntervalRef _Nonnull interval) {
    OCCTIntrvBounds b;
    interval->interval.Bounds(b.start, b.tolStart, b.end, b.tolEnd);
    return b;
}

bool OCCTIntrvIntervalIsProbablyEmpty(OCCTIntrvIntervalRef _Nonnull interval) {
    return interval->interval.IsProbablyEmpty();
}

int32_t OCCTIntrvIntervalPosition(OCCTIntrvIntervalRef _Nonnull interval,
    OCCTIntrvIntervalRef _Nonnull other) {
    return (int32_t)interval->interval.Position(other->interval);
}

bool OCCTIntrvIntervalIsBefore(OCCTIntrvIntervalRef _Nonnull interval,
    OCCTIntrvIntervalRef _Nonnull other) {
    return interval->interval.IsBefore(other->interval);
}

bool OCCTIntrvIntervalIsAfter(OCCTIntrvIntervalRef _Nonnull interval,
    OCCTIntrvIntervalRef _Nonnull other) {
    return interval->interval.IsAfter(other->interval);
}

bool OCCTIntrvIntervalIsInside(OCCTIntrvIntervalRef _Nonnull interval,
    OCCTIntrvIntervalRef _Nonnull other) {
    return interval->interval.IsInside(other->interval);
}

bool OCCTIntrvIntervalIsEnclosing(OCCTIntrvIntervalRef _Nonnull interval,
    OCCTIntrvIntervalRef _Nonnull other) {
    return interval->interval.IsEnclosing(other->interval);
}

bool OCCTIntrvIntervalIsSimilar(OCCTIntrvIntervalRef _Nonnull interval,
    OCCTIntrvIntervalRef _Nonnull other) {
    return interval->interval.IsSimilar(other->interval);
}

void OCCTIntrvIntervalSetStart(OCCTIntrvIntervalRef _Nonnull interval, double start, float tol) {
    interval->interval.SetStart(start, tol);
}

void OCCTIntrvIntervalSetEnd(OCCTIntrvIntervalRef _Nonnull interval, double end, float tol) {
    interval->interval.SetEnd(end, tol);
}

void OCCTIntrvIntervalFuseAtStart(OCCTIntrvIntervalRef _Nonnull interval, double start, float tol) {
    interval->interval.FuseAtStart(start, tol);
}

void OCCTIntrvIntervalFuseAtEnd(OCCTIntrvIntervalRef _Nonnull interval, double end, float tol) {
    interval->interval.FuseAtEnd(end, tol);
}

void OCCTIntrvIntervalCutAtStart(OCCTIntrvIntervalRef _Nonnull interval, double start, float tol) {
    interval->interval.CutAtStart(start, tol);
}

void OCCTIntrvIntervalCutAtEnd(OCCTIntrvIntervalRef _Nonnull interval, double end, float tol) {
    interval->interval.CutAtEnd(end, tol);
}

// MARK: - Intrv_Intervals (v0.73)
// --- Intrv_Intervals ---

struct OCCTIntrvIntervals {
    Intrv_Intervals intervals;
};

OCCTIntrvIntervalsRef _Nonnull OCCTIntrvIntervalsCreate(double start, double end) {
    auto* ref = new OCCTIntrvIntervals();
    ref->intervals = Intrv_Intervals(Intrv_Interval(start, end));
    return ref;
}

OCCTIntrvIntervalsRef _Nonnull OCCTIntrvIntervalsCreateEmpty(void) {
    auto* ref = new OCCTIntrvIntervals();
    ref->intervals = Intrv_Intervals();
    return ref;
}

void OCCTIntrvIntervalsRelease(OCCTIntrvIntervalsRef _Nonnull intervals) {
    delete intervals;
}

int32_t OCCTIntrvIntervalsCount(OCCTIntrvIntervalsRef _Nonnull intervals) {
    return (int32_t)intervals->intervals.NbIntervals();
}

OCCTIntrvBounds OCCTIntrvIntervalsValue(OCCTIntrvIntervalsRef _Nonnull intervals, int32_t index) {
    OCCTIntrvBounds b = {0, 0, 0, 0};
    try {
        const Intrv_Interval& iv = intervals->intervals.Value(index);
        iv.Bounds(b.start, b.tolStart, b.end, b.tolEnd);
    } catch (...) {}
    return b;
}

void OCCTIntrvIntervalsUnite(OCCTIntrvIntervalsRef _Nonnull intervals, double start, double end) {
    intervals->intervals.Unite(Intrv_Interval(start, end));
}

void OCCTIntrvIntervalsSubtract(OCCTIntrvIntervalsRef _Nonnull intervals, double start, double end) {
    intervals->intervals.Subtract(Intrv_Interval(start, end));
}

void OCCTIntrvIntervalsIntersect(OCCTIntrvIntervalsRef _Nonnull intervals, double start, double end) {
    intervals->intervals.Intersect(Intrv_Interval(start, end));
}

void OCCTIntrvIntervalsXUnite(OCCTIntrvIntervalsRef _Nonnull intervals, double start, double end) {
    intervals->intervals.XUnite(Intrv_Interval(start, end));
}

// MARK: - v0.92: Bnd_Range
// MARK: - Bnd_Range (v0.92.0)

#include <Bnd_Range.hxx>

struct OCCTRange {
    Bnd_Range range;
};

OCCTRangeRef OCCTRangeCreate(double min, double max) {
    auto* ref = new OCCTRange();
    ref->range = Bnd_Range(min, max);
    return ref;
}

OCCTRangeRef OCCTRangeCreateVoid() {
    return new OCCTRange();
}

void OCCTRangeRelease(OCCTRangeRef range) { delete range; }

bool OCCTRangeIsVoid(OCCTRangeRef range) { return range->range.IsVoid(); }

bool OCCTRangeGetBounds(OCCTRangeRef range, double* first, double* last) {
    return range->range.GetBounds(*first, *last);
}

double OCCTRangeDelta(OCCTRangeRef range) { return range->range.Delta(); }

bool OCCTRangeContains(OCCTRangeRef range, double value) { return range->range.Contains(value); }

void OCCTRangeAddValue(OCCTRangeRef range, double value) { range->range.Add(value); }

void OCCTRangeAddRange(OCCTRangeRef range, OCCTRangeRef other) { range->range.Add(other->range); }

void OCCTRangeCommon(OCCTRangeRef range, OCCTRangeRef other) { range->range.Common(other->range); }

void OCCTRangeEnlarge(OCCTRangeRef range, double delta) { range->range.Enlarge(delta); }

void OCCTRangeTrimFrom(OCCTRangeRef range, double lower) { range->range.TrimFrom(lower); }

void OCCTRangeTrimTo(OCCTRangeRef range, double upper) { range->range.TrimTo(upper); }

// MARK: - v0.94: math_Matrix/Gauss/SVD/DirectPolynomialRoots/Jacobi
// MARK: - math_Matrix (v0.94.0)

#include <math_Matrix.hxx>
#include <math_Vector.hxx>
#include <math_Gauss.hxx>
#include <math_SVD.hxx>
#include <math_DirectPolynomialRoots.hxx>
#include <math_Jacobi.hxx>

struct OCCTMathMatrix {
    math_Matrix mat;
    OCCTMathMatrix(int r, int c, double v) : mat(1, r, 1, c, v) {}
};

OCCTMathMatrixRef OCCTMathMatrixCreate(int32_t rows, int32_t cols, double initValue) {
    return new OCCTMathMatrix(rows, cols, initValue);
}

void OCCTMathMatrixRelease(OCCTMathMatrixRef m) { delete m; }
int32_t OCCTMathMatrixRows(OCCTMathMatrixRef m) { return m->mat.RowNumber(); }
int32_t OCCTMathMatrixCols(OCCTMathMatrixRef m) { return m->mat.ColNumber(); }

double OCCTMathMatrixGetValue(OCCTMathMatrixRef m, int32_t row, int32_t col) {
    return m->mat(row, col);
}

void OCCTMathMatrixSetValue(OCCTMathMatrixRef m, int32_t row, int32_t col, double value) {
    m->mat(row, col) = value;
}

double OCCTMathMatrixDeterminant(OCCTMathMatrixRef m) {
    try { return m->mat.Determinant(); } catch (...) { return 0.0; }
}

bool OCCTMathMatrixInvert(OCCTMathMatrixRef m) {
    try { m->mat.Invert(); return true; } catch (...) { return false; }
}

void OCCTMathMatrixMultiplyScalar(OCCTMathMatrixRef m, double scalar) { m->mat.Multiply(scalar); }
void OCCTMathMatrixTranspose(OCCTMathMatrixRef m) { m->mat.Transpose(); }

// MARK: - math_Gauss (v0.94.0)

bool OCCTMathGaussSolve(const double* matrixData, int32_t n,
                         const double* rhs, double* outSolution) {
    try {
        math_Matrix A(1, n, 1, n, 0.0);
        for (int i = 0; i < n; i++)
            for (int j = 0; j < n; j++)
                A(i+1, j+1) = matrixData[i*n + j];
        math_Gauss gauss(A);
        if (!gauss.IsDone()) return false;
        math_Vector B(1, n, 0.0);
        for (int i = 0; i < n; i++) B(i+1) = rhs[i];
        math_Vector X(1, n, 0.0);
        gauss.Solve(B, X);
        for (int i = 0; i < n; i++) outSolution[i] = X(i+1);
        return true;
    } catch (...) { return false; }
}

double OCCTMathGaussDeterminant(const double* matrixData, int32_t n) {
    try {
        math_Matrix A(1, n, 1, n, 0.0);
        for (int i = 0; i < n; i++)
            for (int j = 0; j < n; j++)
                A(i+1, j+1) = matrixData[i*n + j];
        math_Gauss gauss(A);
        if (!gauss.IsDone()) return 0.0;
        return gauss.Determinant();
    } catch (...) { return 0.0; }
}

// MARK: - math_SVD (v0.94.0)

bool OCCTMathSVDSolve(const double* matrixData, int32_t rows, int32_t cols,
                       const double* rhs, double* outSolution) {
    try {
        math_Matrix A(1, rows, 1, cols, 0.0);
        for (int i = 0; i < rows; i++)
            for (int j = 0; j < cols; j++)
                A(i+1, j+1) = matrixData[i*cols + j];
        math_SVD svd(A);
        if (!svd.IsDone()) return false;
        math_Vector B(1, rows, 0.0);
        for (int i = 0; i < rows; i++) B(i+1) = rhs[i];
        math_Vector X(1, cols, 0.0);
        svd.Solve(B, X);
        for (int i = 0; i < cols; i++) outSolution[i] = X(i+1);
        return true;
    } catch (...) { return false; }
}

// MARK: - math_DirectPolynomialRoots (v0.94.0)

int32_t OCCTMathPolynomialRoots(const double* coeffs, int32_t nCoeffs, double* outRoots) {
    try {
        math_DirectPolynomialRoots* roots = nullptr;
        switch (nCoeffs) {
            case 2: roots = new math_DirectPolynomialRoots(coeffs[0], coeffs[1]); break;
            case 3: roots = new math_DirectPolynomialRoots(coeffs[0], coeffs[1], coeffs[2]); break;
            case 4: roots = new math_DirectPolynomialRoots(coeffs[0], coeffs[1], coeffs[2], coeffs[3]); break;
            case 5: roots = new math_DirectPolynomialRoots(coeffs[0], coeffs[1], coeffs[2], coeffs[3], coeffs[4]); break;
            default: return -1;
        }
        if (!roots->IsDone()) { delete roots; return -1; }
        int n = roots->NbSolutions();
        for (int i = 0; i < n && i < 4; i++) outRoots[i] = roots->Value(i+1);
        delete roots;
        return n;
    } catch (...) { return -1; }
}

// MARK: - math_Jacobi (v0.94.0)

bool OCCTMathJacobiEigenvalues(const double* matrixData, int32_t n, double* outEigenvalues) {
    try {
        math_Matrix A(1, n, 1, n, 0.0);
        for (int i = 0; i < n; i++)
            for (int j = 0; j < n; j++)
                A(i+1, j+1) = matrixData[i*n + j];
        math_Jacobi jacobi(A);
        if (!jacobi.IsDone()) return false;
        for (int i = 0; i < n; i++) outEigenvalues[i] = jacobi.Value(i+1);
        return true;
    } catch (...) { return false; }
}

// MARK: - v0.95: math_Householder/Crout
// MARK: - math_Householder (v0.95.0)

#include <math_Householder.hxx>

bool OCCTMathHouseholderSolve(const double* matrixData, int32_t rows, int32_t cols,
                               const double* rhs, double* outSolution) {
    try {
        math_Matrix A(1, rows, 1, cols, 0.0);
        for (int i = 0; i < rows; i++)
            for (int j = 0; j < cols; j++)
                A(i+1, j+1) = matrixData[i*cols + j];
        math_Vector B(1, rows, 0.0);
        for (int i = 0; i < rows; i++) B(i+1) = rhs[i];
        math_Householder hh(A, B);
        if (!hh.IsDone()) return false;
        math_Vector sol(1, cols, 0.0);
        hh.Value(sol, 1);
        for (int i = 0; i < cols; i++) outSolution[i] = sol(i+1);
        return true;
    } catch (...) { return false; }
}

// MARK: - math_Crout (v0.95.0)

#include <math_Crout.hxx>

bool OCCTMathCroutSolve(const double* matrixData, int32_t n,
                          const double* rhs, double* outSolution) {
    try {
        math_Matrix A(1, n, 1, n, 0.0);
        for (int i = 0; i < n; i++)
            for (int j = 0; j < n; j++)
                A(i+1, j+1) = matrixData[i*n + j];
        math_Crout crout(A);
        if (!crout.IsDone()) return false;
        math_Vector B(1, n, 0.0);
        for (int i = 0; i < n; i++) B(i+1) = rhs[i];
        math_Vector X(1, n, 0.0);
        crout.Solve(B, X);
        for (int i = 0; i < n; i++) outSolution[i] = X(i+1);
        return true;
    } catch (...) { return false; }
}

double OCCTMathCroutDeterminant(const double* matrixData, int32_t n) {
    try {
        math_Matrix A(1, n, 1, n, 0.0);
        for (int i = 0; i < n; i++)
            for (int j = 0; j < n; j++)
                A(i+1, j+1) = matrixData[i*n + j];
        math_Crout crout(A);
        if (!crout.IsDone()) return 0.0;
        return crout.Determinant();
    } catch (...) { return 0.0; }
}

// MARK: - v0.97/v0.98: Precision + IntAna
// MARK: - Precision (v0.97.0)

#include <Precision.hxx>

double OCCTPrecisionConfusion() { return Precision::Confusion(); }
double OCCTPrecisionAngular() { return Precision::Angular(); }
double OCCTPrecisionIntersection() { return Precision::Intersection(); }
double OCCTPrecisionApproximation() { return Precision::Approximation(); }
double OCCTPrecisionInfinite() { return Precision::Infinite(); }
double OCCTPrecisionPConfusion() { return Precision::PConfusion(); }
bool OCCTPrecisionIsInfinite(double value) { return Precision::IsInfinite(value); }
// MARK: - IntAna (v0.98.0)

#include <IntAna_IntConicQuad.hxx>
#include <IntAna_QuadQuadGeo.hxx>
#include <IntAna_Int3Pln.hxx>
#include <IntAna_IntLinTorus.hxx>
#include <IntAna_Quadric.hxx>

OCCTIntConicQuadResult OCCTIntAnaLineQuad(double lox, double loy, double loz,
                                            double ldx, double ldy, double ldz,
                                            double pox, double poy, double poz,
                                            double pnx, double pny, double pnz) {
    OCCTIntConicQuadResult r = {};
    try {
        gp_Lin line(gp_Pnt(lox,loy,loz), gp_Dir(ldx,ldy,ldz));
        gp_Pln plane(gp_Pnt(pox,poy,poz), gp_Dir(pnx,pny,pnz));
        IntAna_IntConicQuad inter(line, plane, Precision::Angular());
        if (!inter.IsDone()) return r;
        r.isParallel = inter.IsParallel();
        r.isInQuadric = inter.IsInQuadric();
        r.count = inter.NbPoints();
        for (int i = 0; i < r.count && i < 4; i++) {
            gp_Pnt p = inter.Point(i+1);
            r.points[i*3] = p.X(); r.points[i*3+1] = p.Y(); r.points[i*3+2] = p.Z();
            r.params[i] = inter.ParamOnConic(i+1);
        }
    } catch (...) {}
    return r;
}

OCCTIntConicQuadResult OCCTIntAnaLineSphere(double lox, double loy, double loz,
                                              double ldx, double ldy, double ldz,
                                              double sx, double sy, double sz,
                                              double snx, double sny, double snz, double radius) {
    OCCTIntConicQuadResult r = {};
    try {
        gp_Lin line(gp_Pnt(lox,loy,loz), gp_Dir(ldx,ldy,ldz));
        IntAna_Quadric quad;
        quad.SetQuadric(gp_Sphere(gp_Ax3(gp_Pnt(sx,sy,sz), gp_Dir(snx,sny,snz)), radius));
        IntAna_IntConicQuad inter(line, quad);
        if (!inter.IsDone()) return r;
        r.isParallel = inter.IsParallel();
        r.count = inter.NbPoints();
        for (int i = 0; i < r.count && i < 4; i++) {
            gp_Pnt p = inter.Point(i+1);
            r.points[i*3] = p.X(); r.points[i*3+1] = p.Y(); r.points[i*3+2] = p.Z();
            r.params[i] = inter.ParamOnConic(i+1);
        }
    } catch (...) {}
    return r;
}

OCCTQuadQuadGeoResult OCCTIntAnaPlanePlane(double p1ox, double p1oy, double p1oz,
                                             double p1nx, double p1ny, double p1nz,
                                             double p2ox, double p2oy, double p2oz,
                                             double p2nx, double p2ny, double p2nz) {
    OCCTQuadQuadGeoResult r = {};
    try {
        gp_Pln pl1(gp_Pnt(p1ox,p1oy,p1oz), gp_Dir(p1nx,p1ny,p1nz));
        gp_Pln pl2(gp_Pnt(p2ox,p2oy,p2oz), gp_Dir(p2nx,p2ny,p2nz));
        IntAna_QuadQuadGeo inter(pl1, pl2, Precision::Angular(), Precision::Confusion());
        if (!inter.IsDone()) return r;
        r.solutionCount = inter.NbSolutions();
        r.resultType = (int32_t)inter.TypeInter();
        for (int i = 0; i < r.solutionCount && i < 4; i++) {
            try {
                gp_Lin line = inter.Line(i+1);
                gp_Pnt o = line.Location();
                gp_Dir d = line.Direction();
                r.lines[i*6] = o.X(); r.lines[i*6+1] = o.Y(); r.lines[i*6+2] = o.Z();
                r.lines[i*6+3] = d.X(); r.lines[i*6+4] = d.Y(); r.lines[i*6+5] = d.Z();
            } catch (...) {}
        }
    } catch (...) {}
    return r;
}

OCCTQuadQuadGeoResult OCCTIntAnaPlaneSphere(double pox, double poy, double poz,
                                              double pnx, double pny, double pnz,
                                              double sx, double sy, double sz,
                                              double snx, double sny, double snz, double radius) {
    OCCTQuadQuadGeoResult r = {};
    try {
        gp_Pln plane(gp_Pnt(pox,poy,poz), gp_Dir(pnx,pny,pnz));
        gp_Sphere sphere(gp_Ax3(gp_Pnt(sx,sy,sz), gp_Dir(snx,sny,snz)), radius);
        IntAna_QuadQuadGeo inter(plane, sphere);
        if (!inter.IsDone()) return r;
        r.solutionCount = inter.NbSolutions();
        r.resultType = (int32_t)inter.TypeInter();
        for (int i = 0; i < r.solutionCount && i < 4; i++) {
            try { gp_Pnt p = inter.Point(i+1);
                r.points[i*3] = p.X(); r.points[i*3+1] = p.Y(); r.points[i*3+2] = p.Z();
            } catch (...) {}
        }
    } catch (...) {}
    return r;
}

bool OCCTIntAna3Planes(double p1ox, double p1oy, double p1oz, double p1nx, double p1ny, double p1nz,
                        double p2ox, double p2oy, double p2oz, double p2nx, double p2ny, double p2nz,
                        double p3ox, double p3oy, double p3oz, double p3nx, double p3ny, double p3nz,
                        double* outX, double* outY, double* outZ) {
    try {
        IntAna_Int3Pln inter(gp_Pln(gp_Pnt(p1ox,p1oy,p1oz), gp_Dir(p1nx,p1ny,p1nz)),
                             gp_Pln(gp_Pnt(p2ox,p2oy,p2oz), gp_Dir(p2nx,p2ny,p2nz)),
                             gp_Pln(gp_Pnt(p3ox,p3oy,p3oz), gp_Dir(p3nx,p3ny,p3nz)));
        if (!inter.IsDone() || inter.IsEmpty()) return false;
        gp_Pnt p = inter.Value();
        *outX = p.X(); *outY = p.Y(); *outZ = p.Z();
        return true;
    } catch (...) { return false; }
}

int32_t OCCTIntAnaLineTorus(double lox, double loy, double loz,
                              double ldx, double ldy, double ldz,
                              double tox, double toy, double toz,
                              double tnx, double tny, double tnz,
                              double majorRadius, double minorRadius,
                              double* outPoints) {
    try {
        gp_Lin line(gp_Pnt(lox,loy,loz), gp_Dir(ldx,ldy,ldz));
        gp_Torus torus(gp_Ax3(gp_Pnt(tox,toy,toz), gp_Dir(tnx,tny,tnz)), majorRadius, minorRadius);
        IntAna_IntLinTorus inter(line, torus);
        if (!inter.IsDone()) return 0;
        int n = inter.NbPoints();
        for (int i = 0; i < n && i < 4; i++) {
            gp_Pnt p = inter.Value(i+1);
            outPoints[i*3] = p.X(); outPoints[i*3+1] = p.Y(); outPoints[i*3+2] = p.Z();
        }
        return n;
    } catch (...) { return 0; }
}

// MARK: - v0.103/v0.104: Bnd_Sphere + BndLib Analytic + IntAna_IntQuadQuad
// MARK: - Bnd_Sphere (v0.103.0)

struct OCCTBndSphere {
    Bnd_Sphere sphere;
};

OCCTBndSphereRef OCCTBndSphereCreate(double cx, double cy, double cz, double radius) {
    auto s = new OCCTBndSphere();
    s->sphere = Bnd_Sphere(gp_XYZ(cx, cy, cz), radius, 0, 0);
    s->sphere.SetValid(true);
    return s;
}

void OCCTBndSphereRelease(OCCTBndSphereRef sphere) { delete sphere; }

double OCCTBndSphereRadius(OCCTBndSphereRef sphere) { return sphere->sphere.Radius(); }

void OCCTBndSphereCenter(OCCTBndSphereRef sphere, double* x, double* y, double* z) {
    gp_XYZ c = sphere->sphere.Center();
    *x = c.X(); *y = c.Y(); *z = c.Z();
}

double OCCTBndSphereDistance(OCCTBndSphereRef sphere, double x, double y, double z) {
    return sphere->sphere.Distance(gp_XYZ(x, y, z));
}

bool OCCTBndSphereIsOut(OCCTBndSphereRef sphere, double x, double y, double z) {
    double maxDist = 0;
    return sphere->sphere.IsOut(gp_XYZ(x, y, z), maxDist);
}

bool OCCTBndSphereIsOutSphere(OCCTBndSphereRef s1, OCCTBndSphereRef s2) {
    return s1->sphere.IsOut(s2->sphere);
}

void OCCTBndSphereAdd(OCCTBndSphereRef sphere, OCCTBndSphereRef other) {
    sphere->sphere.Add(other->sphere);
}
// MARK: - BndLib Analytic Bounding (v0.104.0)

#include <BndLib.hxx>
#include <BndLib_Add3dCurve.hxx>
#include <BndLib_AddSurface.hxx>

void OCCTBndLibLine(double px, double py, double pz, double dx, double dy, double dz,
                     double p1, double p2, double tol,
                     double* xmin, double* ymin, double* zmin,
                     double* xmax, double* ymax, double* zmax) {
    try {
        Bnd_Box box;
        gp_Lin line(gp_Pnt(px,py,pz), gp_Dir(dx,dy,dz));
        BndLib::Add(line, p1, p2, tol, box);
        box.Get(*xmin, *ymin, *zmin, *xmax, *ymax, *zmax);
    } catch (...) { *xmin=*ymin=*zmin=*xmax=*ymax=*zmax=0; }
}

void OCCTBndLibCircle(double cx, double cy, double cz, double nx, double ny, double nz,
                       double radius, double tol,
                       double* xmin, double* ymin, double* zmin,
                       double* xmax, double* ymax, double* zmax) {
    try {
        Bnd_Box box;
        gp_Ax2 ax(gp_Pnt(cx,cy,cz), gp_Dir(nx,ny,nz));
        gp_Circ circ(ax, radius);
        BndLib::Add(circ, tol, box);
        box.Get(*xmin, *ymin, *zmin, *xmax, *ymax, *zmax);
    } catch (...) { *xmin=*ymin=*zmin=*xmax=*ymax=*zmax=0; }
}

void OCCTBndLibSphere(double cx, double cy, double cz, double radius, double tol,
                       double* xmin, double* ymin, double* zmin,
                       double* xmax, double* ymax, double* zmax) {
    try {
        Bnd_Box box;
        gp_Sphere sphere(gp_Ax3(gp_Pnt(cx,cy,cz), gp_Dir(0,0,1)), radius);
        BndLib::Add(sphere, tol, box);
        box.Get(*xmin, *ymin, *zmin, *xmax, *ymax, *zmax);
    } catch (...) { *xmin=*ymin=*zmin=*xmax=*ymax=*zmax=0; }
}

void OCCTBndLibCylinder(double cx, double cy, double cz, double nx, double ny, double nz,
                          double radius, double vmin, double vmax, double tol,
                          double* xmin, double* ymin, double* zmin,
                          double* xmax, double* ymax, double* zmax) {
    try {
        Bnd_Box box;
        gp_Cylinder cyl(gp_Ax3(gp_Pnt(cx,cy,cz), gp_Dir(nx,ny,nz)), radius);
        BndLib::Add(cyl, vmin, vmax, tol, box);
        box.Get(*xmin, *ymin, *zmin, *xmax, *ymax, *zmax);
    } catch (...) { *xmin=*ymin=*zmin=*xmax=*ymax=*zmax=0; }
}

void OCCTBndLibTorus(double cx, double cy, double cz, double nx, double ny, double nz,
                      double majorRadius, double minorRadius, double tol,
                      double* xmin, double* ymin, double* zmin,
                      double* xmax, double* ymax, double* zmax) {
    try {
        Bnd_Box box;
        gp_Torus torus(gp_Ax3(gp_Pnt(cx,cy,cz), gp_Dir(nx,ny,nz)), majorRadius, minorRadius);
        BndLib::Add(torus, tol, box);
        box.Get(*xmin, *ymin, *zmin, *xmax, *ymax, *zmax);
    } catch (...) { *xmin=*ymin=*zmin=*xmax=*ymax=*zmax=0; }
}

void OCCTBndLibEdge(OCCTShapeRef shape, double tol,
                     double* xmin, double* ymin, double* zmin,
                     double* xmax, double* ymax, double* zmax) {
    try {
        Bnd_Box box;
        BRepAdaptor_Curve ac(TopoDS::Edge(shape->shape));
        BndLib_Add3dCurve::Add(ac, tol, box);
        box.Get(*xmin, *ymin, *zmin, *xmax, *ymax, *zmax);
    } catch (...) { *xmin=*ymin=*zmin=*xmax=*ymax=*zmax=0; }
}

void OCCTBndLibFace(OCCTShapeRef shape, double tol,
                     double* xmin, double* ymin, double* zmin,
                     double* xmax, double* ymax, double* zmax) {
    try {
        Bnd_Box box;
        BRepAdaptor_Surface as(TopoDS::Face(shape->shape));
        BndLib_AddSurface::Add(as, tol, box);
        box.Get(*xmin, *ymin, *zmin, *xmax, *ymax, *zmax);
    } catch (...) { *xmin=*ymin=*zmin=*xmax=*ymax=*zmax=0; }
}
// MARK: - IntAna_IntQuadQuad (v0.104.0)

#include <IntAna_IntQuadQuad.hxx>
#include <IntAna_Quadric.hxx>

int32_t OCCTIntAnaCylinderSphere(double cylRadius,
                                   double sphCx, double sphCy, double sphCz, double sphRadius,
                                   double tol) {
    try {
        gp_Cylinder cyl(gp_Ax3(gp_Pnt(0,0,0), gp_Dir(0,0,1)), cylRadius);
        IntAna_Quadric quad;
        quad.SetQuadric(gp_Sphere(gp_Ax3(gp_Pnt(sphCx,sphCy,sphCz), gp_Dir(0,0,1)), sphRadius));
        IntAna_IntQuadQuad iqq(cyl, quad, tol);
        if (!iqq.IsDone()) return -1;
        if (iqq.IdenticalElements()) return -2;
        return (int32_t)iqq.NbCurve();
    } catch (...) { return -1; }
}

bool OCCTIntAnaCylinderSphereIdentical(double cylRadius,
                                         double sphCx, double sphCy, double sphCz, double sphRadius,
                                         double tol) {
    try {
        gp_Cylinder cyl(gp_Ax3(gp_Pnt(0,0,0), gp_Dir(0,0,1)), cylRadius);
        IntAna_Quadric quad;
        quad.SetQuadric(gp_Sphere(gp_Ax3(gp_Pnt(sphCx,sphCy,sphCz), gp_Dir(0,0,1)), sphRadius));
        IntAna_IntQuadQuad iqq(cyl, quad, tol);
        return iqq.IsDone() && iqq.IdenticalElements();
    } catch (...) { return false; }
}

// MARK: - v0.105: BndLib extras + IntAna extensions
// MARK: - BndLib extras (v0.105.0)

#include <BndLib.hxx>
#include <Bnd_Box.hxx>

static void fillBounds6(const Bnd_Box& box, double* bounds6) {
    double x0, y0, z0, x1, y1, z1;
    box.Get(x0, y0, z0, x1, y1, z1);
    bounds6[0] = x0; bounds6[1] = y0; bounds6[2] = z0;
    bounds6[3] = x1; bounds6[4] = y1; bounds6[5] = z1;
}

void OCCTBndLibEllipse(double cx, double cy, double cz,
                        double nx, double ny, double nz,
                        double xdx, double xdy, double xdz,
                        double major, double minor, double tol,
                        double* bounds6) {
    try {
        gp_Ax2 ax(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz), gp_Dir(xdx, xdy, xdz));
        gp_Elips elips(ax, major, minor);
        Bnd_Box box;
        BndLib::Add(elips, tol, box);
        fillBounds6(box, bounds6);
    } catch (...) {
        for (int i = 0; i < 6; i++) bounds6[i] = 0;
    }
}

void OCCTBndLibCone(double cx, double cy, double cz,
                     double nx, double ny, double nz,
                     double semiAngle, double refRadius,
                     double vmin, double vmax, double tol,
                     double* bounds6) {
    try {
        gp_Ax3 ax(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz));
        gp_Cone cone(ax, semiAngle, refRadius);
        Bnd_Box box;
        BndLib::Add(cone, vmin, vmax, tol, box);
        fillBounds6(box, bounds6);
    } catch (...) {
        for (int i = 0; i < 6; i++) bounds6[i] = 0;
    }
}

void OCCTBndLibCircleArc(double cx, double cy, double cz,
                          double nx, double ny, double nz,
                          double radius, double u1, double u2, double tol,
                          double* bounds6) {
    try {
        gp_Ax2 ax(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz));
        gp_Circ circ(ax, radius);
        Bnd_Box box;
        BndLib::Add(circ, u1, u2, tol, box);
        fillBounds6(box, bounds6);
    } catch (...) {
        for (int i = 0; i < 6; i++) bounds6[i] = 0;
    }
}

void OCCTBndLibEllipseArc(double cx, double cy, double cz,
                           double nx, double ny, double nz,
                           double xdx, double xdy, double xdz,
                           double major, double minor,
                           double u1, double u2, double tol,
                           double* bounds6) {
    try {
        gp_Ax2 ax(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz), gp_Dir(xdx, xdy, xdz));
        gp_Elips elips(ax, major, minor);
        Bnd_Box box;
        BndLib::Add(elips, u1, u2, tol, box);
        fillBounds6(box, bounds6);
    } catch (...) {
        for (int i = 0; i < 6; i++) bounds6[i] = 0;
    }
}

void OCCTBndLibParabolaArc(double cx, double cy, double cz,
                            double nx, double ny, double nz,
                            double xdx, double xdy, double xdz,
                            double focal, double u1, double u2, double tol,
                            double* bounds6) {
    try {
        gp_Ax2 ax(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz), gp_Dir(xdx, xdy, xdz));
        gp_Parab parab(ax, focal);
        Bnd_Box box;
        BndLib::Add(parab, u1, u2, tol, box);
        fillBounds6(box, bounds6);
    } catch (...) {
        for (int i = 0; i < 6; i++) bounds6[i] = 0;
    }
}

void OCCTBndLibHyperbolaArc(double cx, double cy, double cz,
                             double nx, double ny, double nz,
                             double xdx, double xdy, double xdz,
                             double major, double minor,
                             double u1, double u2, double tol,
                             double* bounds6) {
    try {
        gp_Ax2 ax(gp_Pnt(cx, cy, cz), gp_Dir(nx, ny, nz), gp_Dir(xdx, xdy, xdz));
        gp_Hypr hypr(ax, major, minor);
        Bnd_Box box;
        BndLib::Add(hypr, u1, u2, tol, box);
        fillBounds6(box, bounds6);
    } catch (...) {
        for (int i = 0; i < 6; i++) bounds6[i] = 0;
    }
}
// MARK: - IntAna extensions (v0.105.0)

#include <IntAna_Curve.hxx>

int32_t OCCTIntAnaConeSphere(double semiAngle, double refRadius,
                              double sphCx, double sphCy, double sphCz, double sphRadius,
                              double tol) {
    try {
        gp_Cone cone(gp_Ax3(gp_Pnt(0,0,0), gp_Dir(0,0,1)), semiAngle, refRadius);
        IntAna_Quadric quad;
        quad.SetQuadric(gp_Sphere(gp_Ax3(gp_Pnt(sphCx, sphCy, sphCz), gp_Dir(0,0,1)), sphRadius));
        IntAna_IntQuadQuad iqq(cone, quad, tol);
        if (!iqq.IsDone()) return -1;
        if (iqq.IdenticalElements()) return -2;
        return (int32_t)iqq.NbCurve();
    } catch (...) { return -1; }
}

int32_t OCCTIntAnaConeSpherePoints(double semiAngle, double refRadius,
                                    double sphCx, double sphCy, double sphCz, double sphRadius,
                                    double tol, int32_t curveIndex, int32_t nbSamples,
                                    double* xs, double* ys, double* zs) {
    try {
        gp_Cone cone(gp_Ax3(gp_Pnt(0,0,0), gp_Dir(0,0,1)), semiAngle, refRadius);
        IntAna_Quadric quad;
        quad.SetQuadric(gp_Sphere(gp_Ax3(gp_Pnt(sphCx, sphCy, sphCz), gp_Dir(0,0,1)), sphRadius));
        IntAna_IntQuadQuad iqq(cone, quad, tol);
        if (!iqq.IsDone() || curveIndex < 1 || curveIndex > (int32_t)iqq.NbCurve()) return 0;
        IntAna_Curve curve = iqq.Curve(curveIndex);
        double first, last;
        curve.Domain(first, last);
        int32_t actual = nbSamples;
        for (int32_t i = 0; i < actual; i++) {
            double t = first + (last - first) * i / (actual - 1);
            gp_Pnt p = curve.Value(t);
            xs[i] = p.X(); ys[i] = p.Y(); zs[i] = p.Z();
        }
        return actual;
    } catch (...) { return 0; }
}

bool OCCTIntAnaConeSphereIsOpen(double semiAngle, double refRadius,
                                 double sphCx, double sphCy, double sphCz, double sphRadius,
                                 double tol, int32_t curveIndex) {
    try {
        gp_Cone cone(gp_Ax3(gp_Pnt(0,0,0), gp_Dir(0,0,1)), semiAngle, refRadius);
        IntAna_Quadric quad;
        quad.SetQuadric(gp_Sphere(gp_Ax3(gp_Pnt(sphCx, sphCy, sphCz), gp_Dir(0,0,1)), sphRadius));
        IntAna_IntQuadQuad iqq(cone, quad, tol);
        if (!iqq.IsDone() || curveIndex < 1 || curveIndex > (int32_t)iqq.NbCurve()) return true;
        IntAna_Curve curve = iqq.Curve(curveIndex);
        return curve.IsOpen();
    } catch (...) { return true; }
}

void OCCTIntAnaConeSphereGetDomain(double semiAngle, double refRadius,
                                    double sphCx, double sphCy, double sphCz, double sphRadius,
                                    double tol, int32_t curveIndex,
                                    double* first, double* last) {
    *first = 0; *last = 0;
    try {
        gp_Cone cone(gp_Ax3(gp_Pnt(0,0,0), gp_Dir(0,0,1)), semiAngle, refRadius);
        IntAna_Quadric quad;
        quad.SetQuadric(gp_Sphere(gp_Ax3(gp_Pnt(sphCx, sphCy, sphCz), gp_Dir(0,0,1)), sphRadius));
        IntAna_IntQuadQuad iqq(cone, quad, tol);
        if (!iqq.IsDone() || curveIndex < 1 || curveIndex > (int32_t)iqq.NbCurve()) return;
        IntAna_Curve curve = iqq.Curve(curveIndex);
        curve.Domain(*first, *last);
    } catch (...) {}
}
