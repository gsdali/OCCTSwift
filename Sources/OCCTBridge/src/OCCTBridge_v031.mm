//
//  OCCTBridge_v031.mm
//  OCCTSwift
//
//  Extracted from OCCTBridge.mm — issue #99.
//
//  v0.31 cluster — ten sub-sections of additive operations.
//  Per-area #include directives stay inline at section boundaries.
//
//  Areas: Quasi-uniform curve / deflection sampling, Bezier surface
//  fill, Quilt faces, Fix small faces, Remove locations, Revolution
//  from curve, Document layers, Document materials, Linear rib feature.
//
//  Public C surface unchanged. No symbol changes — pure file move.
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

// === Headers shared across multiple subsections ===

#include <gp_Ax1.hxx>
#include <gp_Dir.hxx>
#include <gp_Pln.hxx>
#include <gp_Pnt.hxx>
#include <gp_Vec.hxx>

#include <Geom_Curve.hxx>
#include <Geom_Surface.hxx>
#include <Geom_Plane.hxx>

#include <BRep_Tool.hxx>
#include <BRep_Builder.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepLib_FindSurface.hxx>
#include <GeomAdaptor_Curve.hxx>

#include <TopAbs.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopTools_ListOfShape.hxx>

#include <TDF_Label.hxx>
#include <TDF_LabelSequence.hxx>
#include <TCollection_AsciiString.hxx>
#include <TCollection_ExtendedString.hxx>

// MARK: - Quasi-Uniform Curve Sampling (v0.31.0)

#include <GCPnts_QuasiUniformAbscissa.hxx>

int32_t OCCTCurve3DQuasiUniformAbscissa(OCCTCurve3DRef curve, int32_t nbPoints, double* outParams) {
    if (!curve || curve->curve.IsNull() || !outParams || nbPoints <= 0) return 0;
    try {
        GeomAdaptor_Curve adaptor(curve->curve);
        GCPnts_QuasiUniformAbscissa sampler(adaptor, nbPoints);
        if (!sampler.IsDone()) return 0;
        int32_t n = sampler.NbPoints();
        for (int32_t i = 0; i < n; i++) {
            outParams[i] = sampler.Parameter(i + 1);
        }
        return n;
    } catch (...) {
        return 0;
    }
}

// MARK: - Quasi-Uniform Deflection Sampling (v0.31.0)

#include <GCPnts_QuasiUniformDeflection.hxx>

int32_t OCCTCurve3DQuasiUniformDeflection(OCCTCurve3DRef curve, double deflection, double* outXYZ, int32_t maxPoints) {
    if (!curve || curve->curve.IsNull() || !outXYZ || maxPoints <= 0) return 0;
    try {
        GeomAdaptor_Curve adaptor(curve->curve);
        GCPnts_QuasiUniformDeflection sampler(adaptor, deflection);
        if (!sampler.IsDone()) return 0;
        int32_t n = std::min((int32_t)sampler.NbPoints(), maxPoints);
        for (int32_t i = 0; i < n; i++) {
            gp_Pnt p = sampler.Value(i + 1);
            outXYZ[i*3] = p.X();
            outXYZ[i*3+1] = p.Y();
            outXYZ[i*3+2] = p.Z();
        }
        return n;
    } catch (...) {
        return 0;
    }
}

// MARK: - Bezier Surface Fill (v0.31.0)

#include <GeomFill_BezierCurves.hxx>
#include <GeomFill_FillingStyle.hxx>
#include <Geom_BezierCurve.hxx>
#include <Geom_BezierSurface.hxx>

OCCTSurfaceRef OCCTSurfaceBezierFill4(OCCTCurve3DRef c1, OCCTCurve3DRef c2,
                                        OCCTCurve3DRef c3, OCCTCurve3DRef c4,
                                        int32_t fillStyle) {
    if (!c1 || c1->curve.IsNull() ||
        !c2 || c2->curve.IsNull() ||
        !c3 || c3->curve.IsNull() ||
        !c4 || c4->curve.IsNull()) return nullptr;
    try {
        Handle(Geom_BezierCurve) bc1 = Handle(Geom_BezierCurve)::DownCast(c1->curve);
        Handle(Geom_BezierCurve) bc2 = Handle(Geom_BezierCurve)::DownCast(c2->curve);
        Handle(Geom_BezierCurve) bc3 = Handle(Geom_BezierCurve)::DownCast(c3->curve);
        Handle(Geom_BezierCurve) bc4 = Handle(Geom_BezierCurve)::DownCast(c4->curve);
        if (bc1.IsNull() || bc2.IsNull() || bc3.IsNull() || bc4.IsNull()) return nullptr;
        GeomFill_FillingStyle style = GeomFill_StretchStyle;
        if (fillStyle == 1) style = GeomFill_CoonsStyle;
        else if (fillStyle == 2) style = GeomFill_CurvedStyle;
        GeomFill_BezierCurves filler(bc1, bc2, bc3, bc4, style);
        Handle(Geom_BezierSurface) surf = filler.Surface();
        if (surf.IsNull()) return nullptr;
        return new OCCTSurface(surf);
    } catch (...) {
        return nullptr;
    }
}

OCCTSurfaceRef OCCTSurfaceBezierFill2(OCCTCurve3DRef c1, OCCTCurve3DRef c2,
                                        int32_t fillStyle) {
    if (!c1 || c1->curve.IsNull() ||
        !c2 || c2->curve.IsNull()) return nullptr;
    try {
        Handle(Geom_BezierCurve) bc1 = Handle(Geom_BezierCurve)::DownCast(c1->curve);
        Handle(Geom_BezierCurve) bc2 = Handle(Geom_BezierCurve)::DownCast(c2->curve);
        if (bc1.IsNull() || bc2.IsNull()) return nullptr;
        GeomFill_FillingStyle style = GeomFill_StretchStyle;
        if (fillStyle == 1) style = GeomFill_CoonsStyle;
        else if (fillStyle == 2) style = GeomFill_CurvedStyle;
        GeomFill_BezierCurves filler(bc1, bc2, style);
        Handle(Geom_BezierSurface) surf = filler.Surface();
        if (surf.IsNull()) return nullptr;
        return new OCCTSurface(surf);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Quilt Faces (v0.31.0)

#include <BRepTools_Quilt.hxx>

OCCTShapeRef OCCTShapeQuilt(OCCTShapeRef* shapes, int32_t count) {
    if (!shapes || count <= 0) return nullptr;
    try {
        BRepTools_Quilt quilt;
        for (int32_t i = 0; i < count; i++) {
            if (!shapes[i]) return nullptr;
            quilt.Add(shapes[i]->shape);
        }
        TopoDS_Shape result = quilt.Shells();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Fix Small Faces (v0.31.0)

#include <ShapeFix_FixSmallFace.hxx>

OCCTShapeRef OCCTShapeFixSmallFaces(OCCTShapeRef shape, double tolerance) {
    if (!shape) return nullptr;
    try {
        Handle(ShapeFix_FixSmallFace) fixer = new ShapeFix_FixSmallFace();
        fixer->Init(shape->shape);
        fixer->SetPrecision(tolerance);
        fixer->Perform();
        TopoDS_Shape result = fixer->Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Remove Locations (v0.31.0)

#include <ShapeUpgrade_RemoveLocations.hxx>

OCCTShapeRef OCCTShapeRemoveLocations(OCCTShapeRef shape) {
    if (!shape) return nullptr;
    try {
        ShapeUpgrade_RemoveLocations remover;
        remover.Remove(shape->shape);
        TopoDS_Shape result = remover.GetResult();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Revolution from Curve (v0.31.0)

#include <BRepPrimAPI_MakeRevolution.hxx>

OCCTShapeRef OCCTShapeCreateRevolutionFromCurve(OCCTCurve3DRef meridian,
                                                 double axOX, double axOY, double axOZ,
                                                 double axDX, double axDY, double axDZ,
                                                 double angle) {
    if (!meridian || meridian->curve.IsNull()) return nullptr;
    try {
        gp_Ax2 axes(gp_Pnt(axOX, axOY, axOZ), gp_Dir(axDX, axDY, axDZ));
        BRepPrimAPI_MakeRevolution maker(axes, meridian->curve, angle);
        maker.Build();
        if (!maker.IsDone()) return nullptr;
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Document Layers (v0.31.0)

#include <XCAFDoc_LayerTool.hxx>

int32_t OCCTDocumentGetLayerCount(OCCTDocumentRef doc) {
    if (!doc || doc->doc.IsNull()) return 0;
    try {
        Handle(XCAFDoc_LayerTool) layerTool = XCAFDoc_LayerTool::Set(doc->doc->Main());
        if (layerTool.IsNull()) return 0;
        TDF_LabelSequence labels;
        layerTool->GetLayerLabels(labels);
        return (int32_t)labels.Length();
    } catch (...) {
        return 0;
    }
}

bool OCCTDocumentGetLayerName(OCCTDocumentRef doc, int32_t index, char* outName, int32_t maxLen) {
    if (!doc || doc->doc.IsNull() || !outName || maxLen <= 0) return false;
    try {
        Handle(XCAFDoc_LayerTool) layerTool = XCAFDoc_LayerTool::Set(doc->doc->Main());
        if (layerTool.IsNull()) return false;
        TDF_LabelSequence labels;
        layerTool->GetLayerLabels(labels);
        if (index < 0 || index >= labels.Length()) return false;
        TDF_Label label = labels.Value(index + 1);
        TCollection_ExtendedString name;
        if (!layerTool->GetLayer(label, name)) return false;
        // Convert ExtendedString to ASCII
        TCollection_AsciiString ascii(name);
        int32_t len = ascii.Length();
        if (len >= maxLen) len = maxLen - 1;
        for (int32_t i = 0; i < len; i++) {
            outName[i] = ascii.Value(i + 1);
        }
        outName[len] = '\0';
        return true;
    } catch (...) {
        return false;
    }
}

// MARK: - Document Materials (v0.31.0)

#include <XCAFDoc_MaterialTool.hxx>
#include <TCollection_HAsciiString.hxx>

int32_t OCCTDocumentGetMaterialCount(OCCTDocumentRef doc) {
    if (!doc || doc->doc.IsNull()) return 0;
    try {
        Handle(XCAFDoc_MaterialTool) matTool = XCAFDoc_MaterialTool::Set(doc->doc->Main());
        if (matTool.IsNull()) return 0;
        TDF_LabelSequence labels;
        matTool->GetMaterialLabels(labels);
        return (int32_t)labels.Length();
    } catch (...) {
        return 0;
    }
}

bool OCCTDocumentGetMaterialInfo(OCCTDocumentRef doc, int32_t index, OCCTMaterialInfo* outInfo) {
    if (!doc || doc->doc.IsNull() || !outInfo) return false;
    try {
        Handle(XCAFDoc_MaterialTool) matTool = XCAFDoc_MaterialTool::Set(doc->doc->Main());
        if (matTool.IsNull()) return false;
        TDF_LabelSequence labels;
        matTool->GetMaterialLabels(labels);
        if (index < 0 || index >= labels.Length()) return false;
        TDF_Label label = labels.Value(index + 1);
        Handle(TCollection_HAsciiString) hName, hDesc, hDensName, hDensValType;
        double density = 0.0;
        matTool->GetMaterial(label, hName, hDesc, density, hDensName, hDensValType);
        memset(outInfo, 0, sizeof(OCCTMaterialInfo));
        if (!hName.IsNull()) {
            TCollection_AsciiString name = hName->String();
            int32_t len = std::min((int32_t)name.Length(), (int32_t)(sizeof(outInfo->name) - 1));
            for (int32_t i = 0; i < len; i++) {
                outInfo->name[i] = name.Value(i + 1);
            }
        }
        if (!hDesc.IsNull()) {
            TCollection_AsciiString desc = hDesc->String();
            int32_t len = std::min((int32_t)desc.Length(), (int32_t)(sizeof(outInfo->description) - 1));
            for (int32_t i = 0; i < len; i++) {
                outInfo->description[i] = desc.Value(i + 1);
            }
        }
        outInfo->density = density;
        return true;
    } catch (...) {
        return false;
    }
}

// MARK: - Linear Rib Feature (v0.31.0)

#include <BRepFeat_MakeLinearForm.hxx>

OCCTShapeRef OCCTShapeAddLinearRib(OCCTShapeRef shape, OCCTWireRef profile,
                                    double dirX, double dirY, double dirZ,
                                    double dir1X, double dir1Y, double dir1Z,
                                    bool fuse) {
    if (!shape || !profile) return nullptr;
    try {
        BRepLib_FindSurface finder(profile->wire);
        if (!finder.Found()) return nullptr;
        Handle(Geom_Plane) plane = Handle(Geom_Plane)::DownCast(finder.Surface());
        if (plane.IsNull()) return nullptr;
        gp_Vec dir(dirX, dirY, dirZ);
        gp_Vec dir1(dir1X, dir1Y, dir1Z);
        BRepFeat_MakeLinearForm maker(shape->shape, profile->wire, plane, dir, dir1,
                                       fuse ? 1 : 0, false);
        maker.Perform();
        if (!maker.IsDone()) return nullptr;
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

