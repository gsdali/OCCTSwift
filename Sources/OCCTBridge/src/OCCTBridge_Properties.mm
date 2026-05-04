//
//  OCCTBridge_Properties.mm
//  OCCTSwift
//
//  Extracted from OCCTBridge.mm — issue #99.
//
//  v0.18 properties + projection + proximity cluster:
//
//  - Face surface properties (area, mean / Gaussian / principal
//    curvatures, surface type, primary axis, UV bounds, eval at UV,
//    normal at UV)
//  - Edge 3D curve properties (curve type, parameter bounds, point /
//    tangent / normal / curvature / torsion / center of curvature,
//    project point onto edge)
//  - Point projection (onto curves and surfaces)
//  - Shape proximity (BRepExtrema_ShapeProximity overlap detection)
//  - Surface intersection (face / face section curves via
//    BRepAlgoAPI_Section)
//
//  Public C surface unchanged. No symbol changes — pure file move.
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

// === Area-specific OCCT headers ===

#include <BRep_Tool.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepAlgoAPI_Section.hxx>
#include <BRepExtrema_OverlapTool.hxx>
#include <BRepExtrema_ShapeProximity.hxx>
#include <BRepGProp.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepTools.hxx>

#include <Geom_Curve.hxx>
#include <Geom_Surface.hxx>
#include <Geom_SurfaceOfLinearExtrusion.hxx>
#include <Geom_SurfaceOfRevolution.hxx>
#include <GeomAbs_CurveType.hxx>
#include <GeomAbs_SurfaceType.hxx>
#include <GeomAPI_ProjectPointOnCurve.hxx>
#include <GeomAPI_ProjectPointOnSurf.hxx>
#include <GeomLProp_CLProps.hxx>
#include <GeomLProp_SLProps.hxx>

#include <gp_Ax1.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>
#include <gp_Sphere.hxx>
#include <gp_Vec.hxx>
#include <GProp_GProps.hxx>

#include <TopAbs.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopTools_ListOfShape.hxx>

// MARK: - Face Surface Properties (v0.18.0)

#include <GeomLProp_SLProps.hxx>
#include <BRepGProp.hxx>

bool OCCTFaceGetUVBounds(OCCTFaceRef face,
                         double* uMin, double* uMax,
                         double* vMin, double* vMax) {
    if (!face || !uMin || !uMax || !vMin || !vMax) return false;

    try {
        BRepTools::UVBounds(face->face, *uMin, *uMax, *vMin, *vMax);
        return true;
    } catch (...) {
        return false;
    }
}

bool OCCTFaceEvaluateAtUV(OCCTFaceRef face, double u, double v,
                          double* px, double* py, double* pz) {
    if (!face || !px || !py || !pz) return false;

    try {
        Handle(Geom_Surface) surface = BRep_Tool::Surface(face->face);
        if (surface.IsNull()) return false;

        gp_Pnt pnt;
        surface->D0(u, v, pnt);
        *px = pnt.X();
        *py = pnt.Y();
        *pz = pnt.Z();
        return true;
    } catch (...) {
        return false;
    }
}

bool OCCTFaceGetNormalAtUV(OCCTFaceRef face, double u, double v,
                           double* nx, double* ny, double* nz) {
    if (!face || !nx || !ny || !nz) return false;

    try {
        Handle(Geom_Surface) surface = BRep_Tool::Surface(face->face);
        if (surface.IsNull()) return false;

        GeomLProp_SLProps props(surface, u, v, 1, Precision::Confusion());
        if (!props.IsNormalDefined()) return false;

        gp_Dir normal = props.Normal();
        // Reverse if face orientation is reversed
        if (face->face.Orientation() == TopAbs_REVERSED) {
            normal.Reverse();
        }
        *nx = normal.X();
        *ny = normal.Y();
        *nz = normal.Z();
        return true;
    } catch (...) {
        return false;
    }
}

bool OCCTFaceGetGaussianCurvature(OCCTFaceRef face, double u, double v,
                                   double* curvature) {
    if (!face || !curvature) return false;

    try {
        Handle(Geom_Surface) surface = BRep_Tool::Surface(face->face);
        if (surface.IsNull()) return false;

        GeomLProp_SLProps props(surface, u, v, 2, Precision::Confusion());
        if (!props.IsCurvatureDefined()) return false;

        *curvature = props.GaussianCurvature();
        return true;
    } catch (...) {
        return false;
    }
}

bool OCCTFaceGetMeanCurvature(OCCTFaceRef face, double u, double v,
                               double* curvature) {
    if (!face || !curvature) return false;

    try {
        Handle(Geom_Surface) surface = BRep_Tool::Surface(face->face);
        if (surface.IsNull()) return false;

        GeomLProp_SLProps props(surface, u, v, 2, Precision::Confusion());
        if (!props.IsCurvatureDefined()) return false;

        *curvature = props.MeanCurvature();
        return true;
    } catch (...) {
        return false;
    }
}

bool OCCTFaceGetPrincipalCurvatures(OCCTFaceRef face, double u, double v,
                                     double* k1, double* k2,
                                     double* d1x, double* d1y, double* d1z,
                                     double* d2x, double* d2y, double* d2z) {
    if (!face || !k1 || !k2 || !d1x || !d1y || !d1z || !d2x || !d2y || !d2z)
        return false;

    try {
        Handle(Geom_Surface) surface = BRep_Tool::Surface(face->face);
        if (surface.IsNull()) return false;

        GeomLProp_SLProps props(surface, u, v, 2, Precision::Confusion());
        if (!props.IsCurvatureDefined()) return false;

        *k1 = props.MinCurvature();
        *k2 = props.MaxCurvature();

        gp_Dir dir1, dir2;
        props.CurvatureDirections(dir1, dir2);
        *d1x = dir1.X(); *d1y = dir1.Y(); *d1z = dir1.Z();
        *d2x = dir2.X(); *d2y = dir2.Y(); *d2z = dir2.Z();
        return true;
    } catch (...) {
        return false;
    }
}

int32_t OCCTFaceGetSurfaceType(OCCTFaceRef face) {
    if (!face) return 10; // Other

    try {
        BRepAdaptor_Surface adaptor(face->face);
        switch (adaptor.GetType()) {
            case GeomAbs_Plane:              return 0;
            case GeomAbs_Cylinder:           return 1;
            case GeomAbs_Cone:               return 2;
            case GeomAbs_Sphere:             return 3;
            case GeomAbs_Torus:              return 4;
            case GeomAbs_BezierSurface:      return 5;
            case GeomAbs_BSplineSurface:     return 6;
            case GeomAbs_SurfaceOfRevolution:return 7;
            case GeomAbs_SurfaceOfExtrusion: return 8;
            case GeomAbs_OffsetSurface:      return 9;
            default:                         return 10;
        }
    } catch (...) {
        return 10;
    }
}

double OCCTFaceGetArea(OCCTFaceRef face, double tolerance) {
    if (!face) return -1.0;

    try {
        GProp_GProps props;
        BRepGProp::SurfaceProperties(face->face, props, tolerance);
        return props.Mass();
    } catch (...) {
        return -1.0;
    }
}

#include <Geom_SurfaceOfRevolution.hxx>
#include <Geom_SurfaceOfLinearExtrusion.hxx>

bool OCCTFaceGetPrimaryAxis(OCCTFaceRef face,
                             double* ox, double* oy, double* oz,
                             double* dx, double* dy, double* dz,
                             int32_t* outKind) {
    *ox = 0; *oy = 0; *oz = 0; *dx = 0; *dy = 0; *dz = 1; *outKind = 0;
    if (!face) return false;
    try {
        BRepAdaptor_Surface adaptor(face->face);
        gp_Ax1 axis;
        int kind = 0;
        switch (adaptor.GetType()) {
            case GeomAbs_Cylinder: {
                axis = adaptor.Cylinder().Axis();
                kind = 1;
                break;
            }
            case GeomAbs_Cone: {
                axis = adaptor.Cone().Axis();
                kind = 2;
                break;
            }
            case GeomAbs_Sphere: {
                gp_Sphere s = adaptor.Sphere();
                axis = gp_Ax1(s.Location(), s.Position().Direction());
                kind = 3;
                break;
            }
            case GeomAbs_Torus: {
                axis = adaptor.Torus().Axis();
                kind = 4;
                break;
            }
            case GeomAbs_SurfaceOfRevolution: {
                Handle(Geom_Surface) surf = BRep_Tool::Surface(face->face);
                Handle(Geom_SurfaceOfRevolution) rev = Handle(Geom_SurfaceOfRevolution)::DownCast(surf);
                if (rev.IsNull()) return false;
                axis = rev->Axis();
                kind = 5;
                break;
            }
            case GeomAbs_SurfaceOfExtrusion: {
                Handle(Geom_Surface) surf = BRep_Tool::Surface(face->face);
                Handle(Geom_SurfaceOfLinearExtrusion) ext = Handle(Geom_SurfaceOfLinearExtrusion)::DownCast(surf);
                if (ext.IsNull()) return false;
                gp_Dir dir = ext->Direction();
                // Extrusion has no canonical origin — use basis curve start.
                Handle(Geom_Curve) basis = ext->BasisCurve();
                gp_Pnt origin(0, 0, 0);
                if (!basis.IsNull()) {
                    origin = basis->Value(basis->FirstParameter());
                }
                axis = gp_Ax1(origin, dir);
                kind = 6;
                break;
            }
            default:
                return false;
        }
        const gp_Pnt& p = axis.Location();
        const gp_Dir& d = axis.Direction();
        *ox = p.X(); *oy = p.Y(); *oz = p.Z();
        *dx = d.X(); *dy = d.Y(); *dz = d.Z();
        *outKind = kind;
        return true;
    } catch (...) {
        return false;
    }
}


// MARK: - Edge 3D Curve Properties (v0.18.0)

#include <GeomLProp_CLProps.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <GeomAbs_CurveType.hxx>

bool OCCTEdgeGetParameterBounds(OCCTEdgeRef edge, double* first, double* last) {
    if (!edge || !first || !last) return false;

    try {
        Standard_Real f, l;
        Handle(Geom_Curve) curve = BRep_Tool::Curve(edge->edge, f, l);
        if (curve.IsNull()) return false;

        *first = f;
        *last = l;
        return true;
    } catch (...) {
        return false;
    }
}

bool OCCTEdgeGetCurvature3D(OCCTEdgeRef edge, double param, double* curvature) {
    if (!edge || !curvature) return false;

    try {
        Standard_Real f, l;
        Handle(Geom_Curve) curve = BRep_Tool::Curve(edge->edge, f, l);
        if (curve.IsNull()) return false;

        GeomLProp_CLProps props(curve, 2, Precision::Confusion());
        props.SetParameter(param);
        if (!props.IsTangentDefined()) return false;

        *curvature = props.Curvature();
        return true;
    } catch (...) {
        return false;
    }
}

bool OCCTEdgeGetTangent3D(OCCTEdgeRef edge, double param,
                           double* tx, double* ty, double* tz) {
    if (!edge || !tx || !ty || !tz) return false;

    try {
        Standard_Real f, l;
        Handle(Geom_Curve) curve = BRep_Tool::Curve(edge->edge, f, l);
        if (curve.IsNull()) return false;

        GeomLProp_CLProps props(curve, 1, Precision::Confusion());
        props.SetParameter(param);
        if (!props.IsTangentDefined()) return false;

        gp_Dir dir;
        props.Tangent(dir);
        *tx = dir.X();
        *ty = dir.Y();
        *tz = dir.Z();
        return true;
    } catch (...) {
        return false;
    }
}

bool OCCTEdgeGetNormal3D(OCCTEdgeRef edge, double param,
                          double* nx, double* ny, double* nz) {
    if (!edge || !nx || !ny || !nz) return false;

    try {
        Standard_Real f, l;
        Handle(Geom_Curve) curve = BRep_Tool::Curve(edge->edge, f, l);
        if (curve.IsNull()) return false;

        GeomLProp_CLProps props(curve, 2, Precision::Confusion());
        props.SetParameter(param);
        if (!props.IsTangentDefined()) return false;

        gp_Dir dir;
        props.Normal(dir);
        *nx = dir.X();
        *ny = dir.Y();
        *nz = dir.Z();
        return true;
    } catch (...) {
        return false;
    }
}

bool OCCTEdgeGetCenterOfCurvature3D(OCCTEdgeRef edge, double param,
                                     double* cx, double* cy, double* cz) {
    if (!edge || !cx || !cy || !cz) return false;

    try {
        Standard_Real f, l;
        Handle(Geom_Curve) curve = BRep_Tool::Curve(edge->edge, f, l);
        if (curve.IsNull()) return false;

        GeomLProp_CLProps props(curve, 2, Precision::Confusion());
        props.SetParameter(param);
        if (!props.IsTangentDefined()) return false;

        if (props.Curvature() < Precision::Confusion()) return false;

        gp_Pnt center;
        props.CentreOfCurvature(center);
        *cx = center.X();
        *cy = center.Y();
        *cz = center.Z();
        return true;
    } catch (...) {
        return false;
    }
}

bool OCCTEdgeGetTorsion(OCCTEdgeRef edge, double param, double* torsion) {
    if (!edge || !torsion) return false;

    try {
        Standard_Real f, l;
        Handle(Geom_Curve) curve = BRep_Tool::Curve(edge->edge, f, l);
        if (curve.IsNull()) return false;

        // Need 3rd derivative for torsion
        gp_Pnt pnt;
        gp_Vec d1, d2, d3;
        curve->D3(param, pnt, d1, d2, d3);

        // Torsion = (d1 x d2) . d3 / |d1 x d2|^2
        gp_Vec cross = d1.Crossed(d2);
        double crossMag2 = cross.SquareMagnitude();
        if (crossMag2 < Precision::Confusion()) {
            *torsion = 0.0;
            return true;
        }
        *torsion = cross.Dot(d3) / crossMag2;
        return true;
    } catch (...) {
        return false;
    }
}

bool OCCTEdgeGetPointAtParam(OCCTEdgeRef edge, double param,
                              double* px, double* py, double* pz) {
    if (!edge || !px || !py || !pz) return false;

    try {
        Standard_Real f, l;
        Handle(Geom_Curve) curve = BRep_Tool::Curve(edge->edge, f, l);
        if (curve.IsNull()) return false;

        gp_Pnt pnt;
        curve->D0(param, pnt);
        *px = pnt.X();
        *py = pnt.Y();
        *pz = pnt.Z();
        return true;
    } catch (...) {
        return false;
    }
}

int32_t OCCTEdgeGetCurveType(OCCTEdgeRef edge) {
    if (!edge) return 8; // Other

    try {
        BRepAdaptor_Curve adaptor(edge->edge);
        switch (adaptor.GetType()) {
            case GeomAbs_Line:       return 0;
            case GeomAbs_Circle:     return 1;
            case GeomAbs_Ellipse:    return 2;
            case GeomAbs_Hyperbola:  return 3;
            case GeomAbs_Parabola:   return 4;
            case GeomAbs_BezierCurve:return 5;
            case GeomAbs_BSplineCurve:return 6;
            case GeomAbs_OffsetCurve:return 7;
            default:                 return 8;
        }
    } catch (...) {
        return 8;
    }
}


// MARK: - Point Projection (v0.18.0)

#include <GeomAPI_ProjectPointOnSurf.hxx>
#include <GeomAPI_ProjectPointOnCurve.hxx>

OCCTSurfaceProjectionResult OCCTFaceProjectPoint(OCCTFaceRef face,
                                                  double px, double py, double pz) {
    OCCTSurfaceProjectionResult result = {};
    result.isValid = false;
    if (!face) return result;

    try {
        Handle(Geom_Surface) surface = BRep_Tool::Surface(face->face);
        if (surface.IsNull()) return result;

        double uMin, uMax, vMin, vMax;
        BRepTools::UVBounds(face->face, uMin, uMax, vMin, vMax);

        GeomAPI_ProjectPointOnSurf proj(gp_Pnt(px, py, pz), surface,
                                         uMin, uMax, vMin, vMax,
                                         Precision::Confusion());
        if (proj.NbPoints() == 0) return result;

        gp_Pnt nearest = proj.NearestPoint();
        result.px = nearest.X();
        result.py = nearest.Y();
        result.pz = nearest.Z();
        proj.LowerDistanceParameters(result.u, result.v);
        result.distance = proj.LowerDistance();
        result.isValid = true;
        return result;
    } catch (...) {
        return result;
    }
}

int32_t OCCTFaceProjectPointAll(OCCTFaceRef face,
                                 double px, double py, double pz,
                                 OCCTSurfaceProjectionResult* results,
                                 int32_t maxResults) {
    if (!face || !results || maxResults <= 0) return 0;

    try {
        Handle(Geom_Surface) surface = BRep_Tool::Surface(face->face);
        if (surface.IsNull()) return 0;

        double uMin, uMax, vMin, vMax;
        BRepTools::UVBounds(face->face, uMin, uMax, vMin, vMax);

        GeomAPI_ProjectPointOnSurf proj(gp_Pnt(px, py, pz), surface,
                                         uMin, uMax, vMin, vMax,
                                         Precision::Confusion());

        int32_t count = std::min((int32_t)proj.NbPoints(), maxResults);
        for (int32_t i = 0; i < count; i++) {
            gp_Pnt pnt = proj.Point(i + 1);
            results[i].px = pnt.X();
            results[i].py = pnt.Y();
            results[i].pz = pnt.Z();
            proj.Parameters(i + 1, results[i].u, results[i].v);
            results[i].distance = proj.Distance(i + 1);
            results[i].isValid = true;
        }
        return count;
    } catch (...) {
        return 0;
    }
}

OCCTCurveProjectionResult OCCTEdgeProjectPoint(OCCTEdgeRef edge,
                                                double px, double py, double pz) {
    OCCTCurveProjectionResult result = {};
    result.isValid = false;
    if (!edge) return result;

    try {
        Standard_Real first, last;
        Handle(Geom_Curve) curve = BRep_Tool::Curve(edge->edge, first, last);
        if (curve.IsNull()) return result;

        GeomAPI_ProjectPointOnCurve proj(gp_Pnt(px, py, pz), curve, first, last);
        if (proj.NbPoints() == 0) return result;

        gp_Pnt nearest = proj.NearestPoint();
        result.px = nearest.X();
        result.py = nearest.Y();
        result.pz = nearest.Z();
        result.parameter = proj.LowerDistanceParameter();
        result.distance = proj.LowerDistance();
        result.isValid = true;
        return result;
    } catch (...) {
        return result;
    }
}

// MARK: - Shape Proximity (v0.18.0)

#include <BRepExtrema_ShapeProximity.hxx>
#include <BRepExtrema_OverlapTool.hxx>

int32_t OCCTShapeProximity(OCCTShapeRef shape1, OCCTShapeRef shape2,
                            double tolerance,
                            OCCTFaceProximityPair* outPairs,
                            int32_t maxPairs) {
    if (!shape1 || !shape2 || !outPairs || maxPairs <= 0) return 0;

    try {
        // BRepExtrema_ShapeProximity requires triangulated shapes
        BRepMesh_IncrementalMesh mesh1(shape1->shape, 0.1);
        BRepMesh_IncrementalMesh mesh2(shape2->shape, 0.1);

        BRepExtrema_ShapeProximity prox(shape1->shape, shape2->shape, (Standard_Real)tolerance);
        prox.Perform();

        if (!prox.IsDone()) return 0;

        // Get overlapping face indices
        const auto& overlaps1 = prox.OverlapSubShapes1();
        int32_t count = 0;

        for (NCollection_DataMap<int, TColStd_PackedMapOfInteger>::Iterator it(overlaps1);
             it.More() && count < maxPairs; it.Next()) {
            int32_t face1Idx = (int32_t)it.Key();
            const TColStd_PackedMapOfInteger& face2Set = it.Value();
            for (TColStd_PackedMapOfInteger::Iterator it2(face2Set);
                 it2.More() && count < maxPairs; it2.Next()) {
                outPairs[count].face1Index = face1Idx;
                outPairs[count].face2Index = (int32_t)it2.Key();
                count++;
            }
        }
        return count;
    } catch (...) {
        return 0;
    }
}

#include <BOPAlgo_CheckerSI.hxx>
#include <BOPAlgo_Alerts.hxx>

bool OCCTShapeSelfIntersects(OCCTShapeRef shape) {
    if (!shape) return false;

    try {
        BOPAlgo_CheckerSI checker;
        TopTools_ListOfShape shapes;
        shapes.Append(shape->shape);
        checker.SetArguments(shapes);
        checker.Perform();
        return checker.HasErrors();
    } catch (...) {
        return false;
    }
}


// MARK: - Surface Intersection (v0.18.0)

OCCTShapeRef OCCTFaceIntersect(OCCTFaceRef face1, OCCTFaceRef face2,
                                double tolerance) {
    if (!face1 || !face2) return nullptr;

    try {
        BRepAlgoAPI_Section section(face1->face, face2->face, Standard_False);
        section.Approximation(Standard_True);
        section.ComputePCurveOn1(Standard_True);
        section.ComputePCurveOn2(Standard_True);
        section.SetFuzzyValue(tolerance);
        section.Build();

        if (!section.IsDone()) return nullptr;

        TopoDS_Shape result = section.Shape();
        if (result.IsNull()) return nullptr;

        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}


