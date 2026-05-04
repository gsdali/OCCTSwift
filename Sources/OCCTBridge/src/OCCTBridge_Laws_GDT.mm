//
//  OCCTBridge_Laws_GDT.mm
//  OCCTSwift
//
//  Extracted from OCCTBridge.mm — issue #99.
//
//  Three v0.21 / v0.140 areas that share the XDE document apparatus:
//
//  - Law Functions (v0.21): Law_Function family for parametric scalar
//    functions used to drive variable-radius fillets, swept surfaces,
//    and BSpline knot splittings.
//  - XDE GD&T / Dimension Tolerance read path (v0.21): traverse a doc's
//    dimension + datum + tolerance labels.
//  - GD&T write path (v0.140): construct + attach dimensions, datums,
//    geometric tolerances to shapes inside a doc.
//
//  OCCTLawFunction struct kept in BOTH this TU and OCCTBridge.mm
//  (identical layout, ODR-safe across TUs) — main has out-of-area code
//  in v0.29+ batch helpers that still passes OCCTLawFunctionRef around.
//
//  Public C surface unchanged. No symbol changes — pure file move.
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

// === Area-specific OCCT headers ===

#include <Law_BSpFunc.hxx>
#include <Law_BSpline.hxx>
#include <Law_Constant.hxx>
#include <Law_Function.hxx>
#include <Law_Interpol.hxx>
#include <Law_Linear.hxx>
#include <Law_S.hxx>

#include <BRepOffsetAPI_MakePipeShell.hxx>

#include <XCAFDoc_DocumentTool.hxx>
#include <XCAFDoc_DimTolTool.hxx>
#include <XCAFDoc_Datum.hxx>
#include <XCAFDoc_Dimension.hxx>
#include <XCAFDoc_GeomTolerance.hxx>
#include <XCAFDoc_ShapeTool.hxx>
#include <XCAFDimTolObjects_DatumObject.hxx>
#include <XCAFDimTolObjects_DimensionObject.hxx>
#include <XCAFDimTolObjects_DimensionType.hxx>
#include <XCAFDimTolObjects_GeomToleranceObject.hxx>
#include <XCAFDimTolObjects_GeomToleranceType.hxx>
#include <TDF_Label.hxx>
#include <TDF_LabelSequence.hxx>
#include <TDF_Tool.hxx>
#include <TCollection_AsciiString.hxx>
#include <TCollection_HAsciiString.hxx>

#include <TColStd_Array1OfInteger.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColStd_HArray1OfReal.hxx>

#include <gp_Pnt2d.hxx>
#include <TColgp_Array1OfPnt2d.hxx>

#include <cstring>

// MARK: - Law Functions (v0.21.0)
// ============================================================================

#include <Law_Function.hxx>
#include <Law_Constant.hxx>
#include <Law_Linear.hxx>
#include <Law_S.hxx>
#include <Law_Interpol.hxx>
#include <Law_BSpline.hxx>
#include <Law_BSpFunc.hxx>
#include <TColgp_Array1OfPnt2d.hxx>

struct OCCTLawFunction {
    Handle(Law_Function) law;
    OCCTLawFunction() {}
    OCCTLawFunction(const Handle(Law_Function)& l) : law(l) {}
};

void OCCTLawFunctionRelease(OCCTLawFunctionRef l) {
    delete l;
}

double OCCTLawFunctionValue(OCCTLawFunctionRef l, double param) {
    if (!l || l->law.IsNull()) return 0.0;
    try {
        return l->law->Value(param);
    } catch (...) {
        return 0.0;
    }
}

void OCCTLawFunctionBounds(OCCTLawFunctionRef l, double* first, double* last) {
    if (!l || l->law.IsNull() || !first || !last) return;
    try {
        l->law->Bounds(*first, *last);
    } catch (...) {
        *first = 0;
        *last = 0;
    }
}

OCCTLawFunctionRef OCCTLawCreateConstant(double value, double first, double last) {
    try {
        Handle(Law_Constant) law = new Law_Constant();
        law->Set(value, first, last);
        return new OCCTLawFunction(law);
    } catch (...) {
        return nullptr;
    }
}

OCCTLawFunctionRef OCCTLawCreateLinear(double first, double startVal,
                                        double last, double endVal) {
    try {
        Handle(Law_Linear) law = new Law_Linear();
        law->Set(first, startVal, last, endVal);
        return new OCCTLawFunction(law);
    } catch (...) {
        return nullptr;
    }
}

OCCTLawFunctionRef OCCTLawCreateS(double first, double startVal,
                                   double last, double endVal) {
    try {
        Handle(Law_S) law = new Law_S();
        law->Set(first, startVal, last, endVal);
        return new OCCTLawFunction(law);
    } catch (...) {
        return nullptr;
    }
}

OCCTLawFunctionRef OCCTLawCreateInterpolate(const double* paramValues,
                                             int32_t count, bool periodic) {
    if (!paramValues || count < 2) return nullptr;
    try {
        TColgp_Array1OfPnt2d pts(1, count);
        for (int32_t i = 0; i < count; i++) {
            pts.SetValue(i + 1, gp_Pnt2d(paramValues[i * 2], paramValues[i * 2 + 1]));
        }
        Handle(Law_Interpol) law = new Law_Interpol();
        law->Set(pts, periodic ? Standard_True : Standard_False);
        return new OCCTLawFunction(law);
    } catch (...) {
        return nullptr;
    }
}

OCCTLawFunctionRef OCCTLawCreateBSpline(const double* poles, int32_t poleCount,
                                         const double* knots, int32_t knotCount,
                                         const int32_t* multiplicities,
                                         int32_t degree) {
    if (!poles || !knots || !multiplicities || poleCount < 2 || knotCount < 2)
        return nullptr;
    try {
        TColStd_Array1OfReal poleArr(1, poleCount);
        for (int32_t i = 0; i < poleCount; i++) poleArr.SetValue(i + 1, poles[i]);

        TColStd_Array1OfReal knotArr(1, knotCount);
        for (int32_t i = 0; i < knotCount; i++) knotArr.SetValue(i + 1, knots[i]);

        TColStd_Array1OfInteger multArr(1, knotCount);
        for (int32_t i = 0; i < knotCount; i++) multArr.SetValue(i + 1, multiplicities[i]);

        Handle(Law_BSpline) bsp = new Law_BSpline(poleArr, knotArr, multArr, degree);
        Handle(Law_BSpFunc) law = new Law_BSpFunc(bsp, knots[0], knots[knotCount - 1]);
        return new OCCTLawFunction(law);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreatePipeShellWithLaw(OCCTWireRef spine,
                                              OCCTWireRef profile,
                                              OCCTLawFunctionRef law,
                                              bool solid) {
    if (!spine || !profile || !law || law->law.IsNull()) return nullptr;
    try {
        BRepOffsetAPI_MakePipeShell pipeShell(spine->wire);
        pipeShell.SetMode(Standard_False); // Frenet
        pipeShell.SetLaw(profile->wire, law->law, Standard_False, Standard_False);
        pipeShell.SetIsBuildHistory(false); // avoid SEGV on closed spine+profile (OCCT bug)
        pipeShell.Build();
        if (!pipeShell.IsDone()) return nullptr;

        TopoDS_Shape result = pipeShell.Shape();
        if (solid) {
            pipeShell.MakeSolid();
            if (pipeShell.IsDone()) {
                result = pipeShell.Shape();
            }
        }
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// ============================================================================
// MARK: - XDE GD&T / Dimension Tolerance (v0.21.0)
// ============================================================================

#include <XCAFDoc_DimTolTool.hxx>
#include <XCAFDoc_Dimension.hxx>
#include <XCAFDoc_GeomTolerance.hxx>
#include <XCAFDoc_Datum.hxx>
#include <XCAFDimTolObjects_DimensionObject.hxx>
#include <XCAFDimTolObjects_GeomToleranceObject.hxx>
#include <XCAFDimTolObjects_DatumObject.hxx>

int32_t OCCTDocumentGetDimensionCount(OCCTDocumentRef doc) {
    if (!doc || doc->doc.IsNull()) return 0;
    try {
        Handle(XCAFDoc_DimTolTool) dimTolTool =
            XCAFDoc_DimTolTool::Set(doc->doc->Main());
        TDF_LabelSequence labels;
        dimTolTool->GetDimensionLabels(labels);
        return (int32_t)labels.Length();
    } catch (...) {
        return 0;
    }
}

int32_t OCCTDocumentGetGeomToleranceCount(OCCTDocumentRef doc) {
    if (!doc || doc->doc.IsNull()) return 0;
    try {
        Handle(XCAFDoc_DimTolTool) dimTolTool =
            XCAFDoc_DimTolTool::Set(doc->doc->Main());
        TDF_LabelSequence labels;
        dimTolTool->GetGeomToleranceLabels(labels);
        return (int32_t)labels.Length();
    } catch (...) {
        return 0;
    }
}

int32_t OCCTDocumentGetDatumCount(OCCTDocumentRef doc) {
    if (!doc || doc->doc.IsNull()) return 0;
    try {
        Handle(XCAFDoc_DimTolTool) dimTolTool =
            XCAFDoc_DimTolTool::Set(doc->doc->Main());
        TDF_LabelSequence labels;
        dimTolTool->GetDatumLabels(labels);
        return (int32_t)labels.Length();
    } catch (...) {
        return 0;
    }
}

OCCTDimensionInfo OCCTDocumentGetDimensionInfo(OCCTDocumentRef doc, int32_t index) {
    OCCTDimensionInfo info = {};
    info.isValid = false;
    if (!doc || doc->doc.IsNull()) return info;
    try {
        Handle(XCAFDoc_DimTolTool) dimTolTool =
            XCAFDoc_DimTolTool::Set(doc->doc->Main());
        TDF_LabelSequence labels;
        dimTolTool->GetDimensionLabels(labels);
        if (index < 0 || index >= (int32_t)labels.Length()) return info;

        TDF_Label label = labels.Value(index + 1);
        Handle(XCAFDoc_Dimension) dimAttr;
        if (!label.FindAttribute(XCAFDoc_Dimension::GetID(), dimAttr)) return info;

        Handle(XCAFDimTolObjects_DimensionObject) dimObj = dimAttr->GetObject();
        if (dimObj.IsNull()) return info;

        info.type = (int32_t)dimObj->GetType();
        Handle(TColStd_HArray1OfReal) vals = dimObj->GetValues();
        if (!vals.IsNull() && vals->Length() > 0) {
            info.value = vals->Value(vals->Lower());
        }
        info.lowerTol = dimObj->GetLowerTolValue();
        info.upperTol = dimObj->GetUpperTolValue();
        info.isValid = true;
        return info;
    } catch (...) {
        return info;
    }
}

OCCTGeomToleranceInfo OCCTDocumentGetGeomToleranceInfo(OCCTDocumentRef doc, int32_t index) {
    OCCTGeomToleranceInfo info = {};
    info.isValid = false;
    if (!doc || doc->doc.IsNull()) return info;
    try {
        Handle(XCAFDoc_DimTolTool) dimTolTool =
            XCAFDoc_DimTolTool::Set(doc->doc->Main());
        TDF_LabelSequence labels;
        dimTolTool->GetGeomToleranceLabels(labels);
        if (index < 0 || index >= (int32_t)labels.Length()) return info;

        TDF_Label label = labels.Value(index + 1);
        Handle(XCAFDoc_GeomTolerance) tolAttr;
        if (!label.FindAttribute(XCAFDoc_GeomTolerance::GetID(), tolAttr)) return info;

        Handle(XCAFDimTolObjects_GeomToleranceObject) tolObj = tolAttr->GetObject();
        if (tolObj.IsNull()) return info;

        info.type = (int32_t)tolObj->GetType();
        info.value = tolObj->GetValue();
        info.isValid = true;
        return info;
    } catch (...) {
        return info;
    }
}

OCCTDatumInfo OCCTDocumentGetDatumInfo(OCCTDocumentRef doc, int32_t index) {
    OCCTDatumInfo info = {};
    info.isValid = false;
    memset(info.name, 0, sizeof(info.name));
    if (!doc || doc->doc.IsNull()) return info;
    try {
        Handle(XCAFDoc_DimTolTool) dimTolTool =
            XCAFDoc_DimTolTool::Set(doc->doc->Main());
        TDF_LabelSequence labels;
        dimTolTool->GetDatumLabels(labels);
        if (index < 0 || index >= (int32_t)labels.Length()) return info;

        TDF_Label label = labels.Value(index + 1);
        Handle(XCAFDoc_Datum) datumAttr;
        if (!label.FindAttribute(XCAFDoc_Datum::GetID(), datumAttr)) return info;

        Handle(XCAFDimTolObjects_DatumObject) datumObj = datumAttr->GetObject();
        if (datumObj.IsNull()) return info;

        Handle(TCollection_HAsciiString) hName = datumObj->GetName();
        if (!hName.IsNull() && hName->Length() > 0) {
            strncpy(info.name, hName->String().ToCString(),
                    std::min((int)sizeof(info.name) - 1, hName->Length()));
        }
        info.isValid = true;
        return info;
    } catch (...) {
        return info;
    }
}

// MARK: - GD&T Write Path (v0.140)

#include <XCAFDoc_ShapeTool.hxx>
#include <XCAFDoc_DocumentTool.hxx>
#include <TDF_Tool.hxx>
#include <TCollection_AsciiString.hxx>

int32_t OCCTDocumentCreateDimension(OCCTDocumentRef doc,
                                     int64_t shapeLabelId,
                                     int32_t type,
                                     double value) {
    if (!doc || doc->doc.IsNull()) return -1;
    try {
        Handle(XCAFDoc_DimTolTool) dimTolTool =
            XCAFDoc_DimTolTool::Set(doc->doc->Main());
        TDF_Label shapeLabel = doc->getLabel(shapeLabelId);
        if (shapeLabel.IsNull()) return -1;

        TDF_Label dimLabel = dimTolTool->AddDimension();
        TDF_LabelSequence shapeSeq;
        shapeSeq.Append(shapeLabel);
        dimTolTool->SetDimension(shapeSeq, shapeSeq, dimLabel);

        Handle(XCAFDoc_Dimension) dimAttr;
        if (!dimLabel.FindAttribute(XCAFDoc_Dimension::GetID(), dimAttr)) return -1;

        Handle(XCAFDimTolObjects_DimensionObject) dimObj =
            new XCAFDimTolObjects_DimensionObject();
        dimObj->SetType((XCAFDimTolObjects_DimensionType)type);
        Handle(TColStd_HArray1OfReal) vals = new TColStd_HArray1OfReal(1, 1);
        vals->SetValue(1, value);
        dimObj->SetValues(vals);
        dimAttr->SetObject(dimObj);

        // Return the index of the new dimension.
        TDF_LabelSequence labels;
        dimTolTool->GetDimensionLabels(labels);
        return (int32_t)labels.Length() - 1;
    } catch (...) {
        return -1;
    }
}

int32_t OCCTDocumentCreateGeomTolerance(OCCTDocumentRef doc,
                                         int64_t shapeLabelId,
                                         int32_t type,
                                         double value) {
    if (!doc || doc->doc.IsNull()) return -1;
    try {
        Handle(XCAFDoc_DimTolTool) dimTolTool =
            XCAFDoc_DimTolTool::Set(doc->doc->Main());
        TDF_Label shapeLabel = doc->getLabel(shapeLabelId);
        if (shapeLabel.IsNull()) return -1;

        TDF_Label tolLabel = dimTolTool->AddGeomTolerance();
        TDF_LabelSequence shapeSeq;
        shapeSeq.Append(shapeLabel);
        dimTolTool->SetGeomTolerance(shapeSeq, tolLabel);

        Handle(XCAFDoc_GeomTolerance) tolAttr;
        if (!tolLabel.FindAttribute(XCAFDoc_GeomTolerance::GetID(), tolAttr)) return -1;

        Handle(XCAFDimTolObjects_GeomToleranceObject) tolObj =
            new XCAFDimTolObjects_GeomToleranceObject();
        tolObj->SetType((XCAFDimTolObjects_GeomToleranceType)type);
        tolObj->SetValue(value);
        tolAttr->SetObject(tolObj);

        TDF_LabelSequence labels;
        dimTolTool->GetGeomToleranceLabels(labels);
        return (int32_t)labels.Length() - 1;
    } catch (...) {
        return -1;
    }
}

int32_t OCCTDocumentCreateDatum(OCCTDocumentRef doc, const char* name) {
    if (!doc || doc->doc.IsNull() || !name) return -1;
    try {
        Handle(XCAFDoc_DimTolTool) dimTolTool =
            XCAFDoc_DimTolTool::Set(doc->doc->Main());

        TDF_Label datLabel = dimTolTool->AddDatum();
        Handle(XCAFDoc_Datum) datAttr;
        if (!datLabel.FindAttribute(XCAFDoc_Datum::GetID(), datAttr)) return -1;

        Handle(XCAFDimTolObjects_DatumObject) datObj =
            new XCAFDimTolObjects_DatumObject();
        datObj->SetName(new TCollection_HAsciiString(name));
        datAttr->SetObject(datObj);

        TDF_LabelSequence labels;
        dimTolTool->GetDatumLabels(labels);
        return (int32_t)labels.Length() - 1;
    } catch (...) {
        return -1;
    }
}

bool OCCTDocumentSetDimensionTolerance(OCCTDocumentRef doc,
                                        int32_t dimensionIndex,
                                        double lowerTol, double upperTol) {
    if (!doc || doc->doc.IsNull() || dimensionIndex < 0) return false;
    try {
        Handle(XCAFDoc_DimTolTool) dimTolTool =
            XCAFDoc_DimTolTool::Set(doc->doc->Main());
        TDF_LabelSequence labels;
        dimTolTool->GetDimensionLabels(labels);
        if (dimensionIndex >= (int32_t)labels.Length()) return false;

        TDF_Label label = labels.Value(dimensionIndex + 1);
        Handle(XCAFDoc_Dimension) dimAttr;
        if (!label.FindAttribute(XCAFDoc_Dimension::GetID(), dimAttr)) return false;

        Handle(XCAFDimTolObjects_DimensionObject) dimObj = dimAttr->GetObject();
        if (dimObj.IsNull()) return false;

        dimObj->SetLowerTolValue(lowerTol);
        dimObj->SetUpperTolValue(upperTol);
        dimAttr->SetObject(dimObj);
        return true;
    } catch (...) {
        return false;
    }
}


