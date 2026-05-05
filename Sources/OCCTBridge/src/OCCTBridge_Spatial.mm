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
