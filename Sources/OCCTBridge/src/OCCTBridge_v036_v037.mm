//
//  OCCTBridge_v036_v037.mm
//  OCCTSwift
//
//  Extracted from OCCTBridge.mm — issue #99.
//
//  v0.36 + v0.37 cluster — eleven sub-sections.
//  Per-area #include directives stay inline at section boundaries.
//
//  v0.36 areas: Conical Projection, Encode Regularity, Update Tolerances,
//  Shape Divide by Number, Surface to Bezier Patches, Boolean with
//  Modified Shapes.
//
//  v0.37 areas: Thick Solid / Hollowing, Wire Analysis, Surface
//  Singularity Analysis, Shell from Surface, Multi-Tool Boolean Common.
//
//  Public C surface unchanged. No symbol changes — pure file move.
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

// === Headers shared across multiple subsections ===

#include <gp_Ax1.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>

#include <Geom_Surface.hxx>
#include <Geom_BezierSurface.hxx>

#include <BRep_Tool.hxx>
#include <BRep_Builder.hxx>
#include <BRepProj_Projection.hxx>
#include <BRepBuilderAPI_Copy.hxx>
#include <BRepLib.hxx>
#include <GeomAbs_JoinType.hxx>
#include <BRepOffset.hxx>
#include <GeomConvert.hxx>

#include <TopAbs.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>

// MARK: - Conical Projection (v0.36.0)

OCCTShapeRef OCCTShapeProjectWireConical(OCCTShapeRef wire, OCCTShapeRef shape,
                                          double eyeX, double eyeY, double eyeZ) {
    if (!wire || !shape) return nullptr;
    try {
        gp_Pnt eye(eyeX, eyeY, eyeZ);
        BRepProj_Projection projection(wire->shape, shape->shape, eye);
        if (!projection.IsDone()) return nullptr;
        TopoDS_Compound result = projection.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Encode Regularity (v0.36.0)

OCCTShapeRef OCCTShapeEncodeRegularity(OCCTShapeRef shape, double toleranceAngleDegrees) {
    if (!shape) return nullptr;
    try {
        BRepBuilderAPI_Copy copier(shape->shape);
        if (!copier.IsDone()) return nullptr;
        TopoDS_Shape result = copier.Shape();
        double tolAngle = toleranceAngleDegrees * M_PI / 180.0;
        BRepLib::EncodeRegularity(result, tolAngle);
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Update Tolerances (v0.36.0)

OCCTShapeRef OCCTShapeUpdateTolerances(OCCTShapeRef shape, bool verifyFaceTolerance) {
    if (!shape) return nullptr;
    try {
        BRepBuilderAPI_Copy copier(shape->shape);
        if (!copier.IsDone()) return nullptr;
        TopoDS_Shape result = copier.Shape();
        BRepLib::UpdateTolerances(result, verifyFaceTolerance);
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Shape Divide by Number (v0.36.0)

#include <ShapeUpgrade_ShapeDivide.hxx>
#include <ShapeUpgrade_FaceDivideArea.hxx>

OCCTShapeRef OCCTShapeDivideByNumber(OCCTShapeRef shape, int32_t nbU, int32_t nbV) {
    if (!shape || nbU < 1 || nbV < 1) return nullptr;
    try {
        ShapeUpgrade_ShapeDivide divider(shape->shape);
        // Use FaceDivideArea with splitting-by-number mode
        Handle(ShapeUpgrade_FaceDivideArea) faceDivide = new ShapeUpgrade_FaceDivideArea();
        faceDivide->SetSplittingByNumber(true);
        faceDivide->NbParts() = nbU * nbV;
        divider.SetSplitFaceTool(faceDivide);
        if (!divider.Perform()) return nullptr;
        TopoDS_Shape result = divider.Result();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Surface to Bezier Patches (v0.36.0)

#include <GeomConvert_BSplineSurfaceToBezierSurface.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_BezierSurface.hxx>

int32_t OCCTSurfaceToBezierPatches(OCCTSurfaceRef surface,
                                    OCCTSurfaceRef* outPatches, int32_t maxPatches) {
    if (!surface || !outPatches || maxPatches < 1) return 0;
    if (surface->surface.IsNull()) return 0;
    try {
        // First convert to BSpline if needed
        Handle(Geom_BSplineSurface) bspline = Handle(Geom_BSplineSurface)::DownCast(surface->surface);
        if (bspline.IsNull()) {
            // Try approximate conversion
            Handle(Geom_Surface) surf = surface->surface;
            // Use ShapeConstruct to convert
            bspline = GeomConvert::SurfaceToBSplineSurface(surf);
            if (bspline.IsNull()) return 0;
        }
        GeomConvert_BSplineSurfaceToBezierSurface converter(bspline);
        int32_t nbU = converter.NbUPatches();
        int32_t nbV = converter.NbVPatches();
        int32_t total = nbU * nbV;
        int32_t count = std::min(total, maxPatches);
        int32_t idx = 0;
        for (int32_t i = 1; i <= nbU && idx < count; ++i) {
            for (int32_t j = 1; j <= nbV && idx < count; ++j) {
                Handle(Geom_BezierSurface) patch = converter.Patch(i, j);
                if (!patch.IsNull()) {
                    outPatches[idx] = new OCCTSurface(patch);
                    idx++;
                } else {
                    outPatches[idx] = nullptr;
                    idx++;
                }
            }
        }
        return idx;
    } catch (...) {
        return 0;
    }
}

// MARK: - Boolean with Modified Shapes (v0.36.0)

#include <BRepAlgoAPI_Fuse.hxx>

int32_t OCCTShapeFuseWithHistory(OCCTShapeRef shape1, OCCTShapeRef shape2,
                                  OCCTShapeRef* outModified, int32_t maxModified) {
    if (!shape1 || !shape2 || !outModified || maxModified < 1) return -1;
    try {
        BRepAlgoAPI_Fuse fuse(shape1->shape, shape2->shape);
        if (!fuse.IsDone()) return -1;
        // Collect modified shapes from shape1's faces
        int32_t count = 0;
        TopExp_Explorer explorer(shape1->shape, TopAbs_FACE);
        while (explorer.More() && count < maxModified) {
            const TopTools_ListOfShape& modified = fuse.Modified(explorer.Current());
            TopTools_ListIteratorOfListOfShape it(modified);
            while (it.More() && count < maxModified) {
                outModified[count] = new OCCTShape(it.Value());
                count++;
                it.Next();
            }
            explorer.Next();
        }
        return count;
    } catch (...) {
        return -1;
    }
}

// MARK: - Thick Solid / Hollowing (v0.37.0)

#include <BRepOffsetAPI_MakeThickSolid.hxx>

OCCTShapeRef OCCTShapeMakeThickSolid(OCCTShapeRef shape, const int32_t* faceIndices,
                                      int32_t faceCount, double offset, double tolerance,
                                      int32_t joinType) {
    if (!shape || !faceIndices || faceCount < 1) return nullptr;
    try {
        TopTools_IndexedMapOfShape faceMap;
        TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);

        TopTools_ListOfShape closingFaces;
        for (int32_t i = 0; i < faceCount; ++i) {
            int32_t idx = faceIndices[i] + 1; // 0-based to 1-based
            if (idx < 1 || idx > faceMap.Extent()) return nullptr;
            closingFaces.Append(faceMap(idx));
        }

        GeomAbs_JoinType join = GeomAbs_Arc;
        if (joinType == 1) join = GeomAbs_Tangent;
        else if (joinType == 2) join = GeomAbs_Intersection;

        BRepOffsetAPI_MakeThickSolid maker;
        maker.MakeThickSolidByJoin(shape->shape, closingFaces, offset, tolerance,
                                    BRepOffset_Skin, false, false, join);
        maker.Build();
        if (!maker.IsDone()) return nullptr;
        TopoDS_Shape result = maker.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Wire Analysis (v0.37.0)

#include <ShapeAnalysis_Wire.hxx>
#include <ShapeExtend_WireData.hxx>

bool OCCTWireAnalyze(OCCTWireRef wire, double tolerance, OCCTWireAnalysisResult* result) {
    if (!wire || !result) return false;
    try {
        // Create a dummy planar face for wire analysis
        TopoDS_Face face;
        ShapeAnalysis_Wire analyzer;
        analyzer.Load(wire->wire);
        analyzer.SetPrecision(tolerance);

        result->edgeCount = analyzer.NbEdges();
        // CheckClosed returns true when there IS a problem, so negate it
        result->isClosed = wire->wire.Closed() || !analyzer.CheckClosed(tolerance);
        result->hasSmallEdges = analyzer.CheckSmall(tolerance);
        result->hasGaps3d = analyzer.CheckGaps3d();
        result->hasSelfIntersection = analyzer.CheckSelfIntersection();
        result->isOrdered = !analyzer.CheckOrder();
        result->minDistance3d = analyzer.MinDistance3d();
        result->maxDistance3d = analyzer.MaxDistance3d();
        return true;
    } catch (...) {
        return false;
    }
}

// MARK: - Surface Singularity Analysis (v0.37.0)

#include <ShapeAnalysis_Surface.hxx>

int32_t OCCTSurfaceSingularityCount(OCCTSurfaceRef surface, double tolerance) {
    if (!surface || surface->surface.IsNull()) return 0;
    try {
        ShapeAnalysis_Surface analyzer(surface->surface);
        return analyzer.NbSingularities(tolerance);
    } catch (...) {
        return 0;
    }
}

bool OCCTSurfaceIsDegenerated(OCCTSurfaceRef surface, double x, double y, double z, double tolerance) {
    if (!surface || surface->surface.IsNull()) return false;
    try {
        ShapeAnalysis_Surface analyzer(surface->surface);
        gp_Pnt point(x, y, z);
        return analyzer.IsDegenerated(point, tolerance);
    } catch (...) {
        return false;
    }
}

// MARK: - Shell from Surface (v0.37.0)

#include <BRepBuilderAPI_MakeShell.hxx>

OCCTShapeRef OCCTShapeMakeShell(OCCTSurfaceRef surface,
                                 double uMin, double uMax,
                                 double vMin, double vMax) {
    if (!surface || surface->surface.IsNull()) return nullptr;
    try {
        BRepBuilderAPI_MakeShell maker(surface->surface, uMin, uMax, vMin, vMax);
        if (!maker.IsDone()) return nullptr;
        TopoDS_Shell shell = maker.Shell();
        if (shell.IsNull()) return nullptr;
        return new OCCTShape(shell);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Multi-Tool Boolean Common (v0.37.0)

#include <BRepAlgoAPI_Common.hxx>

OCCTShapeRef OCCTShapeCommonMulti(const OCCTShapeRef* shapes, int32_t count) {
    if (!shapes || count < 2) return nullptr;
    try {
        // Start with the common of first two shapes, then iteratively intersect with rest
        for (int32_t i = 0; i < count; ++i) {
            if (!shapes[i]) return nullptr;
        }
        TopoDS_Shape result = shapes[0]->shape;
        for (int32_t i = 1; i < count; ++i) {
            BRepAlgoAPI_Common common(result, shapes[i]->shape);
            if (!common.IsDone()) return nullptr;
            result = common.Shape();
            if (result.IsNull()) return nullptr;
        }
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

