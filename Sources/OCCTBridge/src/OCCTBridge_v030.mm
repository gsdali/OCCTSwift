//
//  OCCTBridge_v030.mm
//  OCCTSwift
//
//  Extracted from OCCTBridge.mm — issue #99.
//
//  v0.30 cluster — twenty-three sub-sections of additive operations.
//  Per-area #include directives stay inline at section boundaries to
//  match the original layout.
//
//  Areas: Non-uniform transform, Make shell / vertex, Simple offset,
//  Middle path, Fuse edges, Maker volume, Make connected, Curve-curve
//  / curve-surface / surface-surface extrema + intersection + distance,
//  Curve / Surface analytical recognition, Shape contents, Canonical
//  recognition, Edge analysis, Find surface, Contiguous edges, Shape
//  fix wireframe, Remove internal wires, Document length unit.
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
#include <gp_Trsf.hxx>
#include <gp_GTrsf.hxx>
#include <gp_Vec.hxx>

#include <Geom_Curve.hxx>
#include <Geom_Surface.hxx>
#include <Geom_Plane.hxx>

#include <BRep_Tool.hxx>
#include <BRep_Builder.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepAdaptor_Surface.hxx>

#include <TopAbs.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>

// MARK: - Non-Uniform Transform (v0.30.0)

#include <BRepBuilderAPI_GTransform.hxx>
#include <gp_GTrsf.hxx>
#include <gp_Mat.hxx>

OCCTShapeRef OCCTShapeNonUniformScale(OCCTShapeRef shape, double sx, double sy, double sz) {
    if (!shape) return nullptr;
    try {
        gp_GTrsf gtrsf;
        gtrsf.SetVectorialPart(gp_Mat(sx, 0, 0, 0, sy, 0, 0, 0, sz));
        BRepBuilderAPI_GTransform builder(shape->shape, gtrsf, true);
        if (!builder.IsDone()) return nullptr;
        return new OCCTShape(builder.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Make Shell (v0.30.0)

#include <BRepBuilderAPI_MakeShell.hxx>

OCCTShapeRef OCCTShapeCreateShellFromSurface(OCCTSurfaceRef surface) {
    if (!surface || surface->surface.IsNull()) return nullptr;
    try {
        BRepBuilderAPI_MakeShell builder(surface->surface);
        if (!builder.IsDone()) return nullptr;
        return new OCCTShape(builder.Shell());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Make Vertex (v0.30.0)

#include <BRepBuilderAPI_MakeVertex.hxx>

OCCTShapeRef OCCTShapeCreateVertex(double x, double y, double z) {
    try {
        BRepBuilderAPI_MakeVertex builder(gp_Pnt(x, y, z));
        if (!builder.IsDone()) return nullptr;
        return new OCCTShape(builder.Vertex());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Simple Offset (v0.30.0)

#include <BRepOffset_MakeSimpleOffset.hxx>

OCCTShapeRef OCCTShapeSimpleOffset(OCCTShapeRef shape, double offsetValue) {
    if (!shape) return nullptr;
    try {
        BRepOffset_MakeSimpleOffset builder(shape->shape, offsetValue);
        builder.SetBuildSolidFlag(true);
        builder.Perform();
        if (!builder.IsDone()) return nullptr;
        return new OCCTShape(builder.GetResultShape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Middle Path (v0.30.0)

#include <BRepOffsetAPI_MiddlePath.hxx>

OCCTShapeRef OCCTShapeMiddlePath(OCCTShapeRef shape, OCCTShapeRef startShape, OCCTShapeRef endShape) {
    if (!shape || !startShape || !endShape) return nullptr;
    try {
        BRepOffsetAPI_MiddlePath builder(shape->shape, startShape->shape, endShape->shape);
        builder.Build();
        if (!builder.IsDone()) return nullptr;
        return new OCCTShape(builder.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Fuse Edges (v0.30.0)

#include <BRepLib_FuseEdges.hxx>

OCCTShapeRef OCCTShapeFuseEdges(OCCTShapeRef shape) {
    if (!shape) return nullptr;
    try {
        BRepLib_FuseEdges fuser(shape->shape);
        fuser.Perform();
        return new OCCTShape(fuser.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Maker Volume (v0.30.0)

#include <BOPAlgo_MakerVolume.hxx>

OCCTShapeRef OCCTShapeMakeVolume(OCCTShapeRef* shapes, int32_t count) {
    if (!shapes || count <= 0) return nullptr;
    try {
        BOPAlgo_MakerVolume maker;
        for (int32_t i = 0; i < count; i++) {
            if (!shapes[i]) return nullptr;
            maker.AddArgument(shapes[i]->shape);
        }
        maker.Perform();
        if (maker.HasErrors()) return nullptr;
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Make Connected (v0.30.0)

#include <BOPAlgo_MakeConnected.hxx>

OCCTShapeRef OCCTShapeMakeConnected(OCCTShapeRef* shapes, int32_t count) {
    if (!shapes || count <= 0) return nullptr;
    try {
        BOPAlgo_MakeConnected maker;
        for (int32_t i = 0; i < count; i++) {
            if (!shapes[i]) return nullptr;
            maker.AddArgument(shapes[i]->shape);
        }
        maker.Perform();
        if (maker.HasErrors()) return nullptr;
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Curve-Curve Extrema (v0.30.0)

#include <GeomAPI_ExtremaCurveCurve.hxx>

double OCCTCurve3DMinDistanceToCurve(OCCTCurve3DRef c1, OCCTCurve3DRef c2) {
    if (!c1 || c1->curve.IsNull() || !c2 || c2->curve.IsNull()) return -1.0;
    try {
        GeomAPI_ExtremaCurveCurve extrema(c1->curve, c2->curve);
        if (extrema.NbExtrema() == 0) return -1.0;
        return extrema.LowerDistance();
    } catch (...) {
        return -1.0;
    }
}

int32_t OCCTCurve3DExtrema(OCCTCurve3DRef c1, OCCTCurve3DRef c2, OCCTCurveExtrema* outExtrema, int32_t maxCount) {
    if (!c1 || c1->curve.IsNull() || !c2 || c2->curve.IsNull() || !outExtrema || maxCount <= 0) return 0;
    try {
        GeomAPI_ExtremaCurveCurve extrema(c1->curve, c2->curve);
        int32_t nb = extrema.NbExtrema();
        int32_t count = (nb < maxCount) ? nb : maxCount;
        for (int32_t i = 0; i < count; i++) {
            gp_Pnt p1, p2;
            extrema.Points(i + 1, p1, p2);
            double u1, u2;
            extrema.Parameters(i + 1, u1, u2);
            outExtrema[i].distance = extrema.Distance(i + 1);
            outExtrema[i].point1[0] = p1.X();
            outExtrema[i].point1[1] = p1.Y();
            outExtrema[i].point1[2] = p1.Z();
            outExtrema[i].point2[0] = p2.X();
            outExtrema[i].point2[1] = p2.Y();
            outExtrema[i].point2[2] = p2.Z();
            outExtrema[i].param1 = u1;
            outExtrema[i].param2 = u2;
        }
        return count;
    } catch (...) {
        return 0;
    }
}

// MARK: - Curve-Surface Intersection (v0.30.0)

#include <GeomAPI_IntCS.hxx>

int32_t OCCTCurve3DIntersectSurface(OCCTCurve3DRef curve, OCCTSurfaceRef surface,
                                     OCCTCurveSurfaceIntersection* outHits, int32_t maxHits) {
    if (!curve || curve->curve.IsNull() || !surface || surface->surface.IsNull() || !outHits || maxHits <= 0) return 0;
    try {
        GeomAPI_IntCS inter(curve->curve, surface->surface);
        if (!inter.IsDone()) return 0;
        int32_t nb = inter.NbPoints();
        int32_t count = (nb < maxHits) ? nb : maxHits;
        for (int32_t i = 0; i < count; i++) {
            gp_Pnt pt = inter.Point(i + 1);
            double w, u, v;
            inter.Parameters(i + 1, u, v, w);
            outHits[i].point[0] = pt.X();
            outHits[i].point[1] = pt.Y();
            outHits[i].point[2] = pt.Z();
            outHits[i].paramCurve = w;
            outHits[i].paramU = u;
            outHits[i].paramV = v;
        }
        return count;
    } catch (...) {
        return 0;
    }
}

// MARK: - Surface-Surface Intersection (v0.30.0)

#include <GeomAPI_IntSS.hxx>

int32_t OCCTSurfaceIntersect(OCCTSurfaceRef s1, OCCTSurfaceRef s2, double tolerance,
                              OCCTCurve3DRef* outCurves, int32_t maxCurves) {
    if (!s1 || s1->surface.IsNull() || !s2 || s2->surface.IsNull() || !outCurves || maxCurves <= 0) return 0;
    try {
        GeomAPI_IntSS inter(s1->surface, s2->surface, tolerance);
        if (!inter.IsDone()) return 0;
        int32_t nb = inter.NbLines();
        int32_t count = (nb < maxCurves) ? nb : maxCurves;
        for (int32_t i = 0; i < count; i++) {
            Handle(Geom_Curve) c = inter.Line(i + 1);
            if (c.IsNull()) {
                outCurves[i] = nullptr;
            } else {
                outCurves[i] = new OCCTCurve3D(c);
            }
        }
        return count;
    } catch (...) {
        return 0;
    }
}

// MARK: - Curve-Surface Distance (v0.30.0)

#include <GeomAPI_ExtremaCurveSurface.hxx>

double OCCTCurve3DDistanceToSurface(OCCTCurve3DRef curve, OCCTSurfaceRef surface) {
    if (!curve || curve->curve.IsNull() || !surface || surface->surface.IsNull()) return -1.0;
    try {
        GeomAPI_ExtremaCurveSurface extrema(curve->curve, surface->surface);
        if (extrema.NbExtrema() == 0) return -1.0;
        return extrema.LowerDistance();
    } catch (...) {
        return -1.0;
    }
}

// MARK: - Curve to Analytical (v0.30.0)

#include <GeomConvert_CurveToAnaCurve.hxx>

OCCTCurve3DRef OCCTCurve3DToAnalytical(OCCTCurve3DRef curve, double tolerance) {
    if (!curve || curve->curve.IsNull()) return nullptr;
    try {
        GeomConvert_CurveToAnaCurve converter(curve->curve);
        Handle(Geom_Curve) result;
        double newFirst, newLast;
        bool ok = converter.ConvertToAnalytical(tolerance, result,
                                                 curve->curve->FirstParameter(),
                                                 curve->curve->LastParameter(),
                                                 newFirst, newLast);
        if (!ok || result.IsNull()) return nullptr;
        return new OCCTCurve3D(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Surface to Analytical (v0.30.0)

#include <GeomConvert_SurfToAnaSurf.hxx>

OCCTSurfaceRef OCCTSurfaceToAnalytical(OCCTSurfaceRef surface, double tolerance) {
    if (!surface || surface->surface.IsNull()) return nullptr;
    try {
        GeomConvert_SurfToAnaSurf converter(surface->surface);
        Handle(Geom_Surface) result = converter.ConvertToAnalytical(tolerance);
        if (result.IsNull()) return nullptr;
        // If the result is the same handle, it was already analytical or couldn't convert
        if (result == surface->surface) return nullptr;
        return new OCCTSurface(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Shape Contents (v0.30.0)

#include <ShapeAnalysis_ShapeContents.hxx>

OCCTShapeContents OCCTShapeGetContents(OCCTShapeRef shape) {
    OCCTShapeContents result = {};
    if (!shape) return result;
    try {
        ShapeAnalysis_ShapeContents contents;
        contents.Perform(shape->shape);
        result.nbSolids = contents.NbSolids();
        result.nbShells = contents.NbShells();
        result.nbFaces = contents.NbFaces();
        result.nbWires = contents.NbWires();
        result.nbEdges = contents.NbEdges();
        result.nbVertices = contents.NbVertices();
        result.nbFreeEdges = contents.NbFreeEdges();
        result.nbFreeWires = contents.NbFreeWires();
        result.nbFreeFaces = contents.NbFreeFaces();
        return result;
    } catch (...) {
        return result;
    }
}

// MARK: - Canonical Recognition (v0.30.0)

#include <ShapeAnalysis_CanonicalRecognition.hxx>
#include <gp_Elips.hxx>

OCCTCanonicalForm OCCTShapeRecognizeCanonical(OCCTShapeRef shape, double tolerance) {
    OCCTCanonicalForm result = {};
    if (!shape) return result;
    try {
        ShapeAnalysis_CanonicalRecognition recog(shape->shape);
        gp_Pln pln;
        if (recog.IsPlane(tolerance, pln)) {
            result.type = 1;
            result.origin[0] = pln.Location().X();
            result.origin[1] = pln.Location().Y();
            result.origin[2] = pln.Location().Z();
            result.direction[0] = pln.Axis().Direction().X();
            result.direction[1] = pln.Axis().Direction().Y();
            result.direction[2] = pln.Axis().Direction().Z();
            result.gap = recog.GetGap();
            return result;
        }
        gp_Cylinder cyl;
        if (recog.IsCylinder(tolerance, cyl)) {
            result.type = 2;
            result.origin[0] = cyl.Location().X();
            result.origin[1] = cyl.Location().Y();
            result.origin[2] = cyl.Location().Z();
            result.direction[0] = cyl.Axis().Direction().X();
            result.direction[1] = cyl.Axis().Direction().Y();
            result.direction[2] = cyl.Axis().Direction().Z();
            result.radius = cyl.Radius();
            result.gap = recog.GetGap();
            return result;
        }
        gp_Cone cone;
        if (recog.IsCone(tolerance, cone)) {
            result.type = 3;
            result.origin[0] = cone.Location().X();
            result.origin[1] = cone.Location().Y();
            result.origin[2] = cone.Location().Z();
            result.direction[0] = cone.Axis().Direction().X();
            result.direction[1] = cone.Axis().Direction().Y();
            result.direction[2] = cone.Axis().Direction().Z();
            result.radius = cone.RefRadius();
            result.radius2 = cone.SemiAngle();
            result.gap = recog.GetGap();
            return result;
        }
        gp_Sphere sph;
        if (recog.IsSphere(tolerance, sph)) {
            result.type = 4;
            result.origin[0] = sph.Location().X();
            result.origin[1] = sph.Location().Y();
            result.origin[2] = sph.Location().Z();
            result.direction[0] = sph.Position().Direction().X();
            result.direction[1] = sph.Position().Direction().Y();
            result.direction[2] = sph.Position().Direction().Z();
            result.radius = sph.Radius();
            result.gap = recog.GetGap();
            return result;
        }
        gp_Lin lin;
        if (recog.IsLine(tolerance, lin)) {
            result.type = 5;
            result.origin[0] = lin.Location().X();
            result.origin[1] = lin.Location().Y();
            result.origin[2] = lin.Location().Z();
            result.direction[0] = lin.Direction().X();
            result.direction[1] = lin.Direction().Y();
            result.direction[2] = lin.Direction().Z();
            result.gap = recog.GetGap();
            return result;
        }
        gp_Circ circ;
        if (recog.IsCircle(tolerance, circ)) {
            result.type = 6;
            result.origin[0] = circ.Location().X();
            result.origin[1] = circ.Location().Y();
            result.origin[2] = circ.Location().Z();
            result.direction[0] = circ.Axis().Direction().X();
            result.direction[1] = circ.Axis().Direction().Y();
            result.direction[2] = circ.Axis().Direction().Z();
            result.radius = circ.Radius();
            result.gap = recog.GetGap();
            return result;
        }
        gp_Elips elips;
        if (recog.IsEllipse(tolerance, elips)) {
            result.type = 7;
            result.origin[0] = elips.Location().X();
            result.origin[1] = elips.Location().Y();
            result.origin[2] = elips.Location().Z();
            result.direction[0] = elips.Axis().Direction().X();
            result.direction[1] = elips.Axis().Direction().Y();
            result.direction[2] = elips.Axis().Direction().Z();
            result.radius = elips.MajorRadius();
            result.radius2 = elips.MinorRadius();
            result.gap = recog.GetGap();
            return result;
        }
        return result;
    } catch (...) {
        return result;
    }
}

// MARK: - Edge Analysis (v0.30.0)

#include <ShapeAnalysis_Edge.hxx>

bool OCCTEdgeHasCurve3D(OCCTShapeRef edge) {
    if (!edge) return false;
    try {
        if (edge->shape.ShapeType() != TopAbs_EDGE) return false;
        ShapeAnalysis_Edge analyzer;
        return analyzer.HasCurve3d(TopoDS::Edge(edge->shape));
    } catch (...) {
        return false;
    }
}

bool OCCTEdgeIsClosed3D(OCCTShapeRef edge) {
    if (!edge) return false;
    try {
        if (edge->shape.ShapeType() != TopAbs_EDGE) return false;
        ShapeAnalysis_Edge analyzer;
        return analyzer.IsClosed3d(TopoDS::Edge(edge->shape));
    } catch (...) {
        return false;
    }
}

bool OCCTEdgeIsSeam(OCCTShapeRef edge, OCCTShapeRef face) {
    if (!edge || !face) return false;
    try {
        if (edge->shape.ShapeType() != TopAbs_EDGE) return false;
        if (face->shape.ShapeType() != TopAbs_FACE) return false;
        ShapeAnalysis_Edge analyzer;
        return analyzer.IsSeam(TopoDS::Edge(edge->shape), TopoDS::Face(face->shape));
    } catch (...) {
        return false;
    }
}

// MARK: - Find Surface (v0.30.0)

#include <BRepLib_FindSurface.hxx>

OCCTSurfaceRef OCCTShapeFindSurface(OCCTShapeRef shape, double tolerance) {
    if (!shape) return nullptr;
    try {
        BRepLib_FindSurface finder(shape->shape, tolerance);
        if (!finder.Found()) return nullptr;
        Handle(Geom_Surface) surf = finder.Surface();
        if (surf.IsNull()) return nullptr;
        return new OCCTSurface(surf);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Contiguous Edges (v0.30.0)

#include <BRepOffsetAPI_FindContigousEdges.hxx>

int32_t OCCTShapeFindContiguousEdges(OCCTShapeRef shape, double tolerance) {
    if (!shape) return 0;
    try {
        BRepOffsetAPI_FindContigousEdges finder(tolerance);
        finder.Add(shape->shape);
        finder.Perform();
        return finder.NbContigousEdges();
    } catch (...) {
        return 0;
    }
}

// MARK: - Shape Fix Wireframe (v0.30.0)

#include <ShapeFix_Wireframe.hxx>

OCCTShapeRef OCCTShapeFixWireframe(OCCTShapeRef shape, double tolerance) {
    if (!shape) return nullptr;
    try {
        Handle(ShapeFix_Wireframe) fixer = new ShapeFix_Wireframe(shape->shape);
        fixer->SetPrecision(tolerance);
        fixer->FixSmallEdges();
        fixer->FixWireGaps();
        TopoDS_Shape result = fixer->Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Remove Internal Wires (v0.30.0)

#include <ShapeUpgrade_RemoveInternalWires.hxx>

OCCTShapeRef OCCTShapeRemoveInternalWires(OCCTShapeRef shape, double minArea) {
    if (!shape) return nullptr;
    try {
        Handle(ShapeUpgrade_RemoveInternalWires) remover = new ShapeUpgrade_RemoveInternalWires(shape->shape);
        remover->MinArea() = minArea;
        remover->Perform();
        TopoDS_Shape result = remover->GetResult();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Document Length Unit (v0.30.0)

#include <XCAFDoc_LengthUnit.hxx>

bool OCCTDocumentGetLengthUnit(OCCTDocumentRef doc, double* unitScale, char* unitName, int32_t maxNameLen) {
    if (!doc || doc->doc.IsNull() || !unitScale) return false;
    try {
        TDF_Label rootLabel = doc->doc->Main().Root();
        Handle(XCAFDoc_LengthUnit) luAttr;
        if (!rootLabel.FindAttribute(XCAFDoc_LengthUnit::GetID(), luAttr)) {
            // Try the main label
            TDF_Label mainLabel = doc->doc->Main();
            if (!mainLabel.FindAttribute(XCAFDoc_LengthUnit::GetID(), luAttr)) {
                return false;
            }
        }
        *unitScale = luAttr->GetUnitValue();
        if (unitName && maxNameLen > 0) {
            TCollection_AsciiString name = luAttr->GetUnitName();
            int len = name.Length();
            if (len >= maxNameLen) len = maxNameLen - 1;
            for (int i = 0; i < len; i++) {
                unitName[i] = name.Value(i + 1);
            }
            unitName[len] = '\0';
        }
        return true;
    } catch (...) {
        return false;
    }
}

