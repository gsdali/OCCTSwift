//
//  OCCTBridge_v028.mm
//  OCCTSwift
//
//  Extracted from OCCTBridge.mm — issue #99.
//
//  v0.28 cluster — four small additive areas bundled together:
//
//  - Helix Curves: parametric helix wire generation
//    (HelixBRep_BuilderHelix)
//  - KD-Tree spatial queries: NCollection_KDTree-backed nearest-point /
//    k-NN / box / range searches over a 3D point cloud (OCCTKDTree
//    struct lives here, not used outside this TU)
//  - STEP optimization: tuning knobs for STEPControl reader / writer
//  - Batch Curve2D evaluation: vectorized D0 / D1 sampling against a
//    Geom2d_Curve (Geom2dGridEval helper)
//
//  Public C surface unchanged. No symbol changes — pure file move.
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

// === Area-specific OCCT headers ===

#include <HelixBRep_BuilderHelix.hxx>
#include <STEPControl_Reader.hxx>
#include <STEPControl_Writer.hxx>
#include <STEPControl_StepModelType.hxx>
#include <Interface_Static.hxx>
#include <IFSelect_ReturnStatus.hxx>

#include <Geom2d_Curve.hxx>

#include <gp_Ax3.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>
#include <gp_Pnt2d.hxx>

#include <NCollection_Array1.hxx>

#include <TopoDS.hxx>

// MARK: - Helix Curves (v0.28.0)

#include <HelixBRep_BuilderHelix.hxx>

OCCTWireRef OCCTWireCreateHelix(double originX, double originY, double originZ,
                                 double axisX, double axisY, double axisZ,
                                 double radius, double pitch, double turns,
                                 bool clockwise) {
    try {
        gp_Pnt origin(originX, originY, originZ);
        gp_Dir dir(axisX, axisY, axisZ);
        if (!clockwise) dir.Reverse();
        gp_Ax3 axis(origin, dir);

        double diameter = radius * 2.0;

        NCollection_Array1<double> pitchArr(1, 1);
        pitchArr.SetValue(1, pitch);
        NCollection_Array1<double> nbTurnsArr(1, 1);
        nbTurnsArr.SetValue(1, turns);

        HelixBRep_BuilderHelix builder;
        builder.SetParameters(axis, diameter, pitchArr, nbTurnsArr);
        builder.Perform();

        if (builder.ErrorStatus() != 0) return nullptr;

        const TopoDS_Shape& shape = builder.Shape();
        if (shape.IsNull()) return nullptr;

        return new OCCTWire(TopoDS::Wire(shape));
    } catch (...) {
        return nullptr;
    }
}

OCCTWireRef OCCTWireCreateHelixTapered(double originX, double originY, double originZ,
                                        double axisX, double axisY, double axisZ,
                                        double startRadius, double endRadius,
                                        double pitch, double turns,
                                        bool clockwise) {
    try {
        gp_Pnt origin(originX, originY, originZ);
        gp_Dir dir(axisX, axisY, axisZ);
        if (!clockwise) dir.Reverse();
        gp_Ax3 axis(origin, dir);

        double startDiam = startRadius * 2.0;
        double endDiam = endRadius * 2.0;

        NCollection_Array1<double> pitchArr(1, 1);
        pitchArr.SetValue(1, pitch);
        NCollection_Array1<double> nbTurnsArr(1, 1);
        nbTurnsArr.SetValue(1, turns);

        HelixBRep_BuilderHelix builder;
        builder.SetParameters(axis, startDiam, endDiam, pitchArr, nbTurnsArr);
        builder.Perform();

        if (builder.ErrorStatus() != 0) return nullptr;

        const TopoDS_Shape& shape = builder.Shape();
        if (shape.IsNull()) return nullptr;

        return new OCCTWire(TopoDS::Wire(shape));
    } catch (...) {
        return nullptr;
    }
}

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

// MARK: - STEP Optimization (v0.28.0)

#include <StepTidy_DuplicateCleaner.hxx>

bool OCCTStepTidyOptimize(const char* inputPath, const char* outputPath) {
    if (!inputPath || !outputPath) return false;
    try {
        STEPControl_Reader reader;
        if (reader.ReadFile(inputPath) != IFSelect_RetDone) return false;

        // Run tidy on the work session before transferring
        Handle(XSControl_WorkSession) ws = reader.WS();
        StepTidy_DuplicateCleaner cleaner(ws);
        cleaner.Perform();

        // Now transfer and write
        reader.TransferRoots();

        STEPControl_Writer writer;
        for (int i = 1; i <= reader.NbShapes(); i++) {
            writer.Transfer(reader.Shape(i), STEPControl_AsIs);
        }
        return writer.Write(outputPath) == IFSelect_RetDone;
    } catch (...) {
        return false;
    }
}

// MARK: - Batch Curve2D Evaluation (v0.28.0)

#include <Geom2dGridEval_Curve.hxx>
#include <Geom2dGridEval.hxx>

int32_t OCCTCurve2DEvaluateGrid(OCCTCurve2DRef curve,
                                 const double* params, int32_t paramCount,
                                 double* outXY) {
    if (!curve || curve->curve.IsNull() || !params || !outXY || paramCount <= 0) return 0;
    try {
        Geom2dGridEval_Curve evaluator(curve->curve);

        NCollection_Array1<double> paramArr(1, paramCount);
        for (int32_t i = 0; i < paramCount; i++) {
            paramArr.SetValue(i + 1, params[i]);
        }

        NCollection_Array1<gp_Pnt2d> results = evaluator.EvaluateGrid(paramArr);
        int32_t n = results.Size();
        for (int32_t i = 0; i < n; i++) {
            const gp_Pnt2d& pt = results.Value(i + 1);
            outXY[i*2]   = pt.X();
            outXY[i*2+1] = pt.Y();
        }
        return n;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTCurve2DEvaluateGridD1(OCCTCurve2DRef curve,
                                   const double* params, int32_t paramCount,
                                   double* outXY, double* outDXDY) {
    if (!curve || curve->curve.IsNull() || !params || !outXY || !outDXDY || paramCount <= 0) return 0;
    try {
        Geom2dGridEval_Curve evaluator(curve->curve);

        NCollection_Array1<double> paramArr(1, paramCount);
        for (int32_t i = 0; i < paramCount; i++) {
            paramArr.SetValue(i + 1, params[i]);
        }

        NCollection_Array1<Geom2dGridEval::CurveD1> results = evaluator.EvaluateGridD1(paramArr);
        int32_t n = results.Size();
        for (int32_t i = 0; i < n; i++) {
            const Geom2dGridEval::CurveD1& r = results.Value(i + 1);
            outXY[i*2]     = r.Point.X();
            outXY[i*2+1]   = r.Point.Y();
            outDXDY[i*2]   = r.D1.X();
            outDXDY[i*2+1] = r.D1.Y();
        }
        return n;
    } catch (...) {
        return 0;
    }
}

