//
//  OCCTBridge_v034_v035.mm
//  OCCTSwift
//
//  Extracted from OCCTBridge.mm — issue #99.
//
//  v0.34 + v0.35 cluster — eleven sub-sections.
//  Per-area #include directives stay inline at section boundaries.
//
//  v0.34 areas: Shape-to-Shape Section, Boolean Pre-Validation,
//  Split Shape by Wire / Angle, Drop Small Edges, Multi-Tool Boolean
//  Fuse.
//
//  v0.35 areas: Multi-Offset Wire, Surface-Surface Intersection,
//  Curve-Surface Intersection, Cylindrical Projection, Same Parameter.
//
//  Public C surface unchanged. No symbol changes — pure file move.
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

// === Headers shared across multiple subsections ===

#include <gp_Ax1.hxx>
#include <gp_Ax2.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>

#include <Geom_Curve.hxx>
#include <Geom_Surface.hxx>

#include <BRep_Tool.hxx>
#include <BRep_Builder.hxx>
#include <ShapeFix_Wireframe.hxx>
#include <BRepBuilderAPI_Copy.hxx>
#include <GeomAbs_JoinType.hxx>

#include <TopAbs.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>

// MARK: - Shape-to-Shape Section (v0.34.0)

#include <BRepAlgoAPI_Section.hxx>

OCCTShapeRef OCCTShapeSection(OCCTShapeRef shape1, OCCTShapeRef shape2) {
    if (!shape1 || !shape2) return nullptr;
    try {
        BRepAlgoAPI_Section section(shape1->shape, shape2->shape, Standard_False);
        section.ComputePCurveOn1(Standard_True);
        section.Approximation(Standard_True);
        section.Build();
        if (!section.IsDone()) return nullptr;
        TopoDS_Shape result = section.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Boolean Pre-Validation (v0.34.0)

#include <BRepAlgoAPI_Check.hxx>

bool OCCTShapeBooleanCheck(OCCTShapeRef shape1, OCCTShapeRef shape2) {
    if (!shape1) return false;
    try {
        if (shape2) {
            BRepAlgoAPI_Check checker(shape1->shape, shape2->shape);
            return checker.IsValid();
        } else {
            BRepAlgoAPI_Check checker(shape1->shape);
            return checker.IsValid();
        }
    } catch (...) {
        return false;
    }
}

// MARK: - Split Shape by Wire (v0.34.0)

#include <BRepFeat_SplitShape.hxx>

OCCTShapeRef OCCTShapeSplitByWire(OCCTShapeRef shape, OCCTWireRef wire, int32_t faceIndex) {
    if (!shape || !wire) return nullptr;
    try {
        TopTools_IndexedMapOfShape faceMap;
        TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);
        int32_t idx = faceIndex + 1; // Convert 0-based to 1-based
        if (idx < 1 || idx > faceMap.Extent()) return nullptr;
        TopoDS_Face face = TopoDS::Face(faceMap(idx));
        BRepFeat_SplitShape splitter(shape->shape);
        splitter.Add(wire->wire, face);
        splitter.Build();
        if (!splitter.IsDone()) return nullptr;
        TopoDS_Shape result = splitter.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Split Shape by Angle (v0.34.0)

#include <ShapeUpgrade_ShapeDivideAngle.hxx>

OCCTShapeRef OCCTShapeSplitByAngle(OCCTShapeRef shape, double maxAngleDegrees) {
    if (!shape) return nullptr;
    try {
        double maxAngleRadians = maxAngleDegrees * M_PI / 180.0;
        ShapeUpgrade_ShapeDivideAngle divider(maxAngleRadians, shape->shape);
        if (!divider.Perform()) return nullptr;
        TopoDS_Shape result = divider.Result();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Drop Small Edges (v0.34.0)

OCCTShapeRef OCCTShapeDropSmallEdges(OCCTShapeRef shape, double tolerance) {
    if (!shape) return nullptr;
    try {
        Handle(ShapeFix_Wireframe) wireframe = new ShapeFix_Wireframe(shape->shape);
        wireframe->SetPrecision(tolerance);
        wireframe->ModeDropSmallEdges() = true;
        wireframe->FixSmallEdges();
        TopoDS_Shape result = wireframe->Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Multi-Tool Boolean Fuse (v0.34.0)

#include <BRepAlgoAPI_BuilderAlgo.hxx>

OCCTShapeRef OCCTShapeFuseMulti(const OCCTShapeRef* shapes, int32_t count) {
    if (!shapes || count < 2) return nullptr;
    try {
        TopTools_ListOfShape arguments;
        for (int32_t i = 0; i < count; ++i) {
            if (!shapes[i]) return nullptr;
            arguments.Append(shapes[i]->shape);
        }
        BRepAlgoAPI_BuilderAlgo builder;
        builder.SetArguments(arguments);
        builder.SetRunParallel(Standard_True);
        builder.Build();
        if (!builder.IsDone()) return nullptr;
        TopoDS_Shape result = builder.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Multi-Offset Wire (v0.35.0)

#include <BRepOffsetAPI_MakeOffset.hxx>

int32_t OCCTWireMultiOffset(OCCTShapeRef face, const double* offsets, int32_t count,
                             int32_t joinType, OCCTWireRef* outWires, int32_t maxWires) {
    if (!face || !offsets || count < 1 || !outWires || maxWires < 1) return 0;
    try {
        // Extract the face from the shape
        TopTools_IndexedMapOfShape faceMap;
        TopExp::MapShapes(face->shape, TopAbs_FACE, faceMap);
        if (faceMap.Extent() < 1) return 0;
        TopoDS_Face topoFace = TopoDS::Face(faceMap(1));

        GeomAbs_JoinType join = GeomAbs_Arc;
        if (joinType == 1) join = GeomAbs_Tangent;
        else if (joinType == 2) join = GeomAbs_Intersection;

        BRepOffsetAPI_MakeOffset offsetMaker(topoFace, join);

        int32_t totalWires = 0;
        for (int32_t i = 0; i < count && totalWires < maxWires; ++i) {
            offsetMaker.Perform(offsets[i]);
            if (!offsetMaker.IsDone()) continue;
            TopoDS_Shape result = offsetMaker.Shape();
            // Extract wires from the result
            TopExp_Explorer wireExp(result, TopAbs_WIRE);
            while (wireExp.More() && totalWires < maxWires) {
                outWires[totalWires] = new OCCTWire(TopoDS::Wire(wireExp.Current()));
                totalWires++;
                wireExp.Next();
            }
        }
        return totalWires;
    } catch (...) {
        return 0;
    }
}

// MARK: - Surface-Surface Intersection (v0.35.0)

#include <GeomAPI_IntSS.hxx>

int32_t OCCTSurfaceSurfaceIntersect(OCCTSurfaceRef surface1, OCCTSurfaceRef surface2,
                                     double tolerance,
                                     OCCTCurve3DRef* outCurves, int32_t maxCurves) {
    if (!surface1 || !surface2 || !outCurves || maxCurves < 1) return 0;
    if (surface1->surface.IsNull() || surface2->surface.IsNull()) return 0;
    try {
        GeomAPI_IntSS intersector(surface1->surface, surface2->surface, tolerance);
        if (!intersector.IsDone()) return 0;
        int32_t nbLines = intersector.NbLines();
        int32_t count = std::min(nbLines, maxCurves);
        for (int32_t i = 0; i < count; ++i) {
            Handle(Geom_Curve) curve = intersector.Line(i + 1); // 1-based
            if (curve.IsNull()) {
                outCurves[i] = nullptr;
            } else {
                outCurves[i] = new OCCTCurve3D(curve);
            }
        }
        return count;
    } catch (...) {
        return 0;
    }
}

// MARK: - Curve-Surface Intersection (v0.35.0)

#include <GeomAPI_IntCS.hxx>

int32_t OCCTCurveSurfaceIntersect(OCCTCurve3DRef curve, OCCTSurfaceRef surface,
                                   OCCTCurveSurfacePoint* outPoints, int32_t maxPoints) {
    if (!curve || !surface || !outPoints || maxPoints < 1) return 0;
    if (curve->curve.IsNull() || surface->surface.IsNull()) return 0;
    try {
        GeomAPI_IntCS intersector(curve->curve, surface->surface);
        if (!intersector.IsDone()) return 0;
        int32_t nbPoints = intersector.NbPoints();
        int32_t count = std::min(nbPoints, maxPoints);
        for (int32_t i = 0; i < count; ++i) {
            gp_Pnt pt = intersector.Point(i + 1);
            double u, v, w;
            intersector.Parameters(i + 1, u, v, w);
            outPoints[i].x = pt.X();
            outPoints[i].y = pt.Y();
            outPoints[i].z = pt.Z();
            outPoints[i].u = u;
            outPoints[i].v = v;
            outPoints[i].w = w;
        }
        return count;
    } catch (...) {
        return 0;
    }
}

// MARK: - Cylindrical Projection (v0.35.0)

#include <BRepProj_Projection.hxx>

OCCTShapeRef OCCTShapeProjectWire(OCCTShapeRef wire, OCCTShapeRef shape,
                                   double dirX, double dirY, double dirZ) {
    if (!wire || !shape) return nullptr;
    try {
        gp_Dir direction(dirX, dirY, dirZ);
        BRepProj_Projection projection(wire->shape, shape->shape, direction);
        if (!projection.IsDone()) return nullptr;
        TopoDS_Compound result = projection.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Same Parameter (v0.35.0)

#include <BRepLib.hxx>

OCCTShapeRef OCCTShapeSameParameter(OCCTShapeRef shape, double tolerance) {
    if (!shape) return nullptr;
    try {
        // Make a copy so we don't modify the original
        BRepBuilderAPI_Copy copier(shape->shape);
        if (!copier.IsDone()) return nullptr;
        TopoDS_Shape result = copier.Shape();
        BRepLib::SameParameter(result, tolerance);
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

