//
//  OCCTBridge_Document.mm
//  OCCTSwift
//
//  Extracted from OCCTBridge.mm — issue #99.
//
//  XDE / XCAF document support: document creation + lifecycle, assembly
//  traversal, transforms, colors, PBR + common visual materials, plus the
//  generic OCCTStringFree helper (declared in the public header but
//  defined here because every label-name getter that allocates a heap
//  string is in this block).
//
//  Public C surface unchanged. No symbol changes — pure file move.
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

// === Area-specific OCCT headers ===

#include <STEPCAFControl_Reader.hxx>
#include <STEPCAFControl_Writer.hxx>
#include <STEPControl_StepModelType.hxx>
#include <IFSelect_ReturnStatus.hxx>
#include <XCAFDoc_DocumentTool.hxx>
#include <XCAFDoc_VisMaterial.hxx>
#include <XCAFDoc_VisMaterialCommon.hxx>
#include <XCAFDoc_VisMaterialPBR.hxx>
#include <XCAFDoc_ColorType.hxx>
#include <TDF_LabelSequence.hxx>
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
#include <TDF_Tool.hxx>
#include <TCollection_HAsciiString.hxx>
#include <TColStd_HArray1OfReal.hxx>
#include <TDataStd_Name.hxx>
#include <TCollection_AsciiString.hxx>
#include <TCollection_ExtendedString.hxx>
#include <Quantity_Color.hxx>
#include <Quantity_ColorRGBA.hxx>
#include <Graphic3d_Vec3.hxx>
#include <Graphic3d_Vec4.hxx>
#include <gp_Trsf.hxx>
#include <TopLoc_Location.hxx>

#include <cstring>

// MARK: - XDE/XCAF Document Support (v0.6.0)

OCCTDocumentRef OCCTDocumentCreate(void) {
    OCCTDocument* document = nullptr;
    try {
        document = new OCCTDocument();

        // Create a new document
        document->app->NewDocument("MDTV-XCAF", document->doc);

        if (document->doc.IsNull()) {
            delete document;
            return nullptr;
        }

        // Get the tools
        document->shapeTool = XCAFDoc_DocumentTool::ShapeTool(document->doc->Main());
        document->colorTool = XCAFDoc_DocumentTool::ColorTool(document->doc->Main());
        document->materialTool = XCAFDoc_DocumentTool::VisMaterialTool(document->doc->Main());

        return document;
    } catch (...) {
        delete document;
        return nullptr;
    }
}

OCCTDocumentRef OCCTDocumentLoadSTEP(const char* path) {
    if (!path) return nullptr;

    OCCTDocument* document = nullptr;
    try {
        document = new OCCTDocument();

        // Create a new document
        document->app->NewDocument("MDTV-XCAF", document->doc);

        if (document->doc.IsNull()) {
            delete document;
            return nullptr;
        }

        // Configure the reader
        STEPCAFControl_Reader reader;
        reader.SetColorMode(Standard_True);
        reader.SetNameMode(Standard_True);
        reader.SetLayerMode(Standard_True);
        reader.SetPropsMode(Standard_True);
        reader.SetMatMode(Standard_True);  // Enable material reading

        // Read the file
        IFSelect_ReturnStatus status = reader.ReadFile(path);
        if (status != IFSelect_RetDone) {
            delete document;
            return nullptr;
        }

        // Transfer to document
        if (!reader.Transfer(document->doc)) {
            delete document;
            return nullptr;
        }

        // Get the tools
        document->shapeTool = XCAFDoc_DocumentTool::ShapeTool(document->doc->Main());
        document->colorTool = XCAFDoc_DocumentTool::ColorTool(document->doc->Main());
        document->materialTool = XCAFDoc_DocumentTool::VisMaterialTool(document->doc->Main());

        return document;
    } catch (...) {
        delete document;
        return nullptr;
    }
}

bool OCCTDocumentWriteSTEP(OCCTDocumentRef doc, const char* path) {
    if (!doc || !path) return false;

    try {
        STEPCAFControl_Writer writer;
        writer.SetColorMode(Standard_True);
        writer.SetNameMode(Standard_True);
        writer.SetLayerMode(Standard_True);
        writer.SetPropsMode(Standard_True);
        writer.SetMaterialMode(Standard_True);  // Enable material writing

        if (!writer.Transfer(doc->doc, STEPControl_AsIs)) {
            return false;
        }

        IFSelect_ReturnStatus status = writer.Write(path);
        return status == IFSelect_RetDone;
    } catch (...) {
        return false;
    }
}

void OCCTDocumentRelease(OCCTDocumentRef doc) {
    if (!doc) return;

    try {
        if (!doc->doc.IsNull()) {
            doc->app->Close(doc->doc);
        }
    } catch (...) {
        // Ignore cleanup errors
    }

    delete doc;
}

// MARK: - XDE Assembly Traversal

int32_t OCCTDocumentGetRootCount(OCCTDocumentRef doc) {
    if (!doc || doc->shapeTool.IsNull()) return 0;

    try {
        TDF_LabelSequence roots;
        doc->shapeTool->GetFreeShapes(roots);
        return static_cast<int32_t>(roots.Length());
    } catch (...) {
        return 0;
    }
}

int64_t OCCTDocumentGetRootLabelId(OCCTDocumentRef doc, int32_t index) {
    if (!doc || doc->shapeTool.IsNull() || index < 0) return -1;

    try {
        TDF_LabelSequence roots;
        doc->shapeTool->GetFreeShapes(roots);

        if (index >= roots.Length()) return -1;

        TDF_Label label = roots.Value(index + 1);  // OCCT is 1-based
        return doc->registerLabel(label);
    } catch (...) {
        return -1;
    }
}

const char* OCCTDocumentGetLabelName(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc) return nullptr;

    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return nullptr;

        Handle(TDataStd_Name) nameAttr;
        if (label.FindAttribute(TDataStd_Name::GetID(), nameAttr)) {
            TCollection_ExtendedString name = nameAttr->Get();
            TCollection_AsciiString asciiName(name);

            // Allocate and copy the string (caller must free with OCCTStringFree)
            char* result = new char[asciiName.Length() + 1];
            std::strcpy(result, asciiName.ToCString());
            return result;
        }

        return nullptr;
    } catch (...) {
        return nullptr;
    }
}

bool OCCTDocumentIsAssembly(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->shapeTool.IsNull()) return false;

    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;

        return doc->shapeTool->IsAssembly(label);
    } catch (...) {
        return false;
    }
}

bool OCCTDocumentIsReference(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->shapeTool.IsNull()) return false;

    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;

        return doc->shapeTool->IsReference(label);
    } catch (...) {
        return false;
    }
}

int32_t OCCTDocumentGetChildCount(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->shapeTool.IsNull()) return 0;

    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return 0;

        TDF_LabelSequence components;
        doc->shapeTool->GetComponents(label, components);
        return static_cast<int32_t>(components.Length());
    } catch (...) {
        return 0;
    }
}

int64_t OCCTDocumentGetChildLabelId(OCCTDocumentRef doc, int64_t parentLabelId, int32_t index) {
    if (!doc || doc->shapeTool.IsNull() || index < 0) return -1;

    try {
        TDF_Label parentLabel = doc->getLabel(parentLabelId);
        if (parentLabel.IsNull()) return -1;

        TDF_LabelSequence components;
        doc->shapeTool->GetComponents(parentLabel, components);

        if (index >= components.Length()) return -1;

        TDF_Label childLabel = components.Value(index + 1);  // OCCT is 1-based
        return doc->registerLabel(childLabel);
    } catch (...) {
        return -1;
    }
}

int64_t OCCTDocumentGetReferredLabelId(OCCTDocumentRef doc, int64_t refLabelId) {
    if (!doc || doc->shapeTool.IsNull()) return -1;

    try {
        TDF_Label refLabel = doc->getLabel(refLabelId);
        if (refLabel.IsNull()) return -1;

        TDF_Label referredLabel;
        if (!doc->shapeTool->GetReferredShape(refLabel, referredLabel)) {
            return -1;
        }

        return doc->registerLabel(referredLabel);
    } catch (...) {
        return -1;
    }
}

OCCTShapeRef OCCTDocumentGetShape(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->shapeTool.IsNull()) return nullptr;

    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return nullptr;

        TopoDS_Shape shape = doc->shapeTool->GetShape(label);
        if (shape.IsNull()) return nullptr;

        return new OCCTShape(shape);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTDocumentGetShapeWithLocation(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->shapeTool.IsNull()) return nullptr;

    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return nullptr;

        // Get shape with accumulated location
        TopoDS_Shape shape;

        // If it's a reference, get the referred shape with location
        if (doc->shapeTool->IsReference(label)) {
            TDF_Label referredLabel;
            if (doc->shapeTool->GetReferredShape(label, referredLabel)) {
                shape = doc->shapeTool->GetShape(referredLabel);
                // Apply location from reference
                TopLoc_Location loc = doc->shapeTool->GetLocation(label);
                shape.Location(loc);
            }
        } else {
            shape = doc->shapeTool->GetShape(label);
        }

        if (shape.IsNull()) return nullptr;

        return new OCCTShape(shape);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - XDE Transforms

void OCCTDocumentGetLocation(OCCTDocumentRef doc, int64_t labelId, float* outMatrix16) {
    if (!doc || !outMatrix16) return;

    // Initialize to identity matrix (column-major)
    for (int i = 0; i < 16; i++) {
        outMatrix16[i] = (i % 5 == 0) ? 1.0f : 0.0f;
    }

    if (doc->shapeTool.IsNull()) return;

    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return;

        TopLoc_Location loc = doc->shapeTool->GetLocation(label);
        if (loc.IsIdentity()) return;

        gp_Trsf trsf = loc.Transformation();

        // Extract rotation/scale part (3x3)
        for (int row = 0; row < 3; row++) {
            for (int col = 0; col < 3; col++) {
                outMatrix16[col * 4 + row] = static_cast<float>(trsf.Value(row + 1, col + 1));
            }
        }

        // Extract translation
        outMatrix16[12] = static_cast<float>(trsf.TranslationPart().X());
        outMatrix16[13] = static_cast<float>(trsf.TranslationPart().Y());
        outMatrix16[14] = static_cast<float>(trsf.TranslationPart().Z());
        outMatrix16[15] = 1.0f;
    } catch (...) {
        // Keep identity matrix on error
    }
}

// MARK: - XDE Colors

OCCTColor OCCTDocumentGetLabelColor(OCCTDocumentRef doc, int64_t labelId, OCCTColorType colorType) {
    OCCTColor result = {0, 0, 0, 1.0, false};

    if (!doc || doc->colorTool.IsNull()) return result;

    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return result;

        Quantity_ColorRGBA color;
        XCAFDoc_ColorType xcafType;

        switch (colorType) {
            case OCCTColorTypeSurface:
                xcafType = XCAFDoc_ColorSurf;
                break;
            case OCCTColorTypeCurve:
                xcafType = XCAFDoc_ColorCurv;
                break;
            default:
                xcafType = XCAFDoc_ColorGen;
                break;
        }

        // Try to get color from this label
        if (doc->colorTool->GetColor(label, xcafType, color)) {
            result.r = color.GetRGB().Red();
            result.g = color.GetRGB().Green();
            result.b = color.GetRGB().Blue();
            result.a = color.Alpha();
            result.isSet = true;
            return result;
        }

        // If this is a reference, try to get color from referred shape
        if (doc->shapeTool->IsReference(label)) {
            TDF_Label referredLabel;
            if (doc->shapeTool->GetReferredShape(label, referredLabel)) {
                if (doc->colorTool->GetColor(referredLabel, xcafType, color)) {
                    result.r = color.GetRGB().Red();
                    result.g = color.GetRGB().Green();
                    result.b = color.GetRGB().Blue();
                    result.a = color.Alpha();
                    result.isSet = true;
                }
            }
        }

        return result;
    } catch (...) {
        return result;
    }
}

void OCCTDocumentSetLabelColor(OCCTDocumentRef doc, int64_t labelId, OCCTColorType colorType, double r, double g, double b) {
    if (!doc || doc->colorTool.IsNull()) return;

    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return;

        Quantity_Color color(r, g, b, Quantity_TOC_RGB);
        XCAFDoc_ColorType xcafType;

        switch (colorType) {
            case OCCTColorTypeSurface:
                xcafType = XCAFDoc_ColorSurf;
                break;
            case OCCTColorTypeCurve:
                xcafType = XCAFDoc_ColorCurv;
                break;
            default:
                xcafType = XCAFDoc_ColorGen;
                break;
        }

        doc->colorTool->SetColor(label, color, xcafType);
    } catch (...) {
        // Ignore errors
    }
}

// MARK: - XDE Materials (PBR)

OCCTMaterial OCCTDocumentGetLabelMaterial(OCCTDocumentRef doc, int64_t labelId) {
    OCCTMaterial result = {{0, 0, 0, 1.0, false}, 0.0, 0.5, {0, 0, 0, 1.0, false}, 0.0, false};

    if (!doc || doc->materialTool.IsNull()) return result;

    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return result;

        // Get shape to find material
        TopoDS_Shape shape = doc->shapeTool->GetShape(label);
        if (shape.IsNull()) {
            // Try from reference
            if (doc->shapeTool->IsReference(label)) {
                TDF_Label referredLabel;
                if (doc->shapeTool->GetReferredShape(label, referredLabel)) {
                    shape = doc->shapeTool->GetShape(referredLabel);
                }
            }
        }

        if (shape.IsNull()) return result;

        // Try to get material from shape
        Handle(XCAFDoc_VisMaterial) visMat = doc->materialTool->GetShapeMaterial(shape);
        if (visMat.IsNull()) return result;

        result.isSet = true;

        // Get PBR properties if available
        if (visMat->HasPbrMaterial()) {
            XCAFDoc_VisMaterialPBR pbr = visMat->PbrMaterial();

            // Base color
            Quantity_ColorRGBA baseColor = pbr.BaseColor;
            result.baseColor.r = baseColor.GetRGB().Red();
            result.baseColor.g = baseColor.GetRGB().Green();
            result.baseColor.b = baseColor.GetRGB().Blue();
            result.baseColor.a = baseColor.Alpha();
            result.baseColor.isSet = true;

            // Metallic and roughness
            result.metallic = pbr.Metallic;
            result.roughness = pbr.Roughness;

            // Emissive (Graphic3d_Vec3)
            result.emissive.r = pbr.EmissiveFactor.x();
            result.emissive.g = pbr.EmissiveFactor.y();
            result.emissive.b = pbr.EmissiveFactor.z();
            result.emissive.a = 1.0;
            result.emissive.isSet = true;
        } else if (visMat->HasCommonMaterial()) {
            // Fall back to common material
            XCAFDoc_VisMaterialCommon common = visMat->CommonMaterial();

            result.baseColor.r = common.DiffuseColor.Red();
            result.baseColor.g = common.DiffuseColor.Green();
            result.baseColor.b = common.DiffuseColor.Blue();
            result.baseColor.a = 1.0 - common.Transparency;
            result.baseColor.isSet = true;

            result.transparency = common.Transparency;

            // Estimate roughness from shininess
            result.roughness = 1.0 - (common.Shininess / 100.0);
        }

        return result;
    } catch (...) {
        return result;
    }
}

void OCCTDocumentSetLabelMaterial(OCCTDocumentRef doc, int64_t labelId, OCCTMaterial material) {
    if (!doc || doc->materialTool.IsNull() || !material.isSet) return;

    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return;

        TopoDS_Shape shape = doc->shapeTool->GetShape(label);
        if (shape.IsNull()) return;

        // Create new material
        Handle(XCAFDoc_VisMaterial) visMat = new XCAFDoc_VisMaterial();

        // Set PBR properties
        XCAFDoc_VisMaterialPBR pbr;
        pbr.BaseColor = Quantity_ColorRGBA(
            Quantity_Color(material.baseColor.r, material.baseColor.g, material.baseColor.b, Quantity_TOC_RGB),
            static_cast<float>(material.baseColor.a)
        );
        pbr.Metallic = static_cast<Standard_ShortReal>(material.metallic);
        pbr.Roughness = static_cast<Standard_ShortReal>(material.roughness);
        pbr.EmissiveFactor = Graphic3d_Vec3(
            static_cast<float>(material.emissive.r),
            static_cast<float>(material.emissive.g),
            static_cast<float>(material.emissive.b)
        );

        visMat->SetPbrMaterial(pbr);

        // Add material and bind to shape
        TDF_Label matLabel = doc->materialTool->AddMaterial(visMat, TCollection_AsciiString("Material"));
        doc->materialTool->SetShapeMaterial(shape, matLabel);
    } catch (...) {
        // Ignore errors
    }
}

// MARK: - XDE Utility

void OCCTStringFree(const char* str) {
    delete[] str;
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

// MARK: - TNaming: Topological Naming History (v0.25.0)

#include <TNaming_Builder.hxx>
#include <TNaming_NamedShape.hxx>
#include <TNaming_Selector.hxx>
#include <TNaming_Iterator.hxx>
#include <TNaming_NewShapeIterator.hxx>
#include <TNaming_OldShapeIterator.hxx>
#include <TNaming_Tool.hxx>
#include <TDF_Label.hxx>
#include <TDF_LabelMap.hxx>
#include <TDF_Data.hxx>

int64_t OCCTDocumentCreateLabel(OCCTDocumentRef doc, int64_t parentLabelId) {
    if (!doc || doc->doc.IsNull()) return -1;
    try {
        TDF_Label parentLabel;
        if (parentLabelId < 0) {
            // Create under document root
            parentLabel = doc->doc->Main();
        } else {
            parentLabel = doc->getLabel(parentLabelId);
            if (parentLabel.IsNull()) return -1;
        }
        TDF_Label newLabel = parentLabel.NewChild();
        return doc->registerLabel(newLabel);
    } catch (...) {
        return -1;
    }
}

bool OCCTDocumentNamingRecord(OCCTDocumentRef doc, int64_t labelId,
                               OCCTNamingEvolution evolution,
                               OCCTShapeRef oldShape, OCCTShapeRef newShape) {
    if (!doc || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;

        TNaming_Builder builder(label);
        switch (evolution) {
            case OCCTNamingPrimitive:
                if (!newShape) return false;
                builder.Generated(newShape->shape);
                break;
            case OCCTNamingGenerated:
                if (!oldShape || !newShape) return false;
                builder.Generated(oldShape->shape, newShape->shape);
                break;
            case OCCTNamingModify:
                if (!oldShape || !newShape) return false;
                builder.Modify(oldShape->shape, newShape->shape);
                break;
            case OCCTNamingDelete:
                if (!oldShape) return false;
                builder.Delete(oldShape->shape);
                break;
            case OCCTNamingSelected:
                if (!oldShape || !newShape) return false;
                builder.Select(newShape->shape, oldShape->shape);
                break;
            default:
                return false;
        }
        return true;
    } catch (...) {
        return false;
    }
}

OCCTShapeRef OCCTDocumentNamingGetCurrentShape(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return nullptr;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return nullptr;

        Handle(TNaming_NamedShape) ns;
        if (!label.FindAttribute(TNaming_NamedShape::GetID(), ns)) return nullptr;
        if (ns.IsNull() || ns->IsEmpty()) return nullptr;

        TopoDS_Shape current = TNaming_Tool::CurrentShape(ns);
        if (current.IsNull()) return nullptr;

        return new OCCTShape(current);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTDocumentNamingGetShape(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return nullptr;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return nullptr;

        Handle(TNaming_NamedShape) ns;
        if (!label.FindAttribute(TNaming_NamedShape::GetID(), ns)) return nullptr;
        if (ns.IsNull() || ns->IsEmpty()) return nullptr;

        TopoDS_Shape shape = TNaming_Tool::GetShape(ns);
        if (shape.IsNull()) return nullptr;

        return new OCCTShape(shape);
    } catch (...) {
        return nullptr;
    }
}

int32_t OCCTDocumentNamingHistoryCount(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return 0;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return 0;

        Handle(TNaming_NamedShape) ns;
        if (!label.FindAttribute(TNaming_NamedShape::GetID(), ns)) return 0;

        int32_t count = 0;
        for (TNaming_Iterator it(ns); it.More(); it.Next()) {
            count++;
        }
        return count;
    } catch (...) {
        return 0;
    }
}

bool OCCTDocumentNamingGetHistoryEntry(OCCTDocumentRef doc, int64_t labelId,
                                        int32_t index, OCCTNamingHistoryEntry* outEntry) {
    if (!doc || !outEntry || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;

        Handle(TNaming_NamedShape) ns;
        if (!label.FindAttribute(TNaming_NamedShape::GetID(), ns)) return false;

        int32_t i = 0;
        for (TNaming_Iterator it(ns); it.More(); it.Next(), i++) {
            if (i == index) {
                TNaming_Evolution evo = it.Evolution();
                outEntry->hasOldShape = !it.OldShape().IsNull();
                outEntry->hasNewShape = !it.NewShape().IsNull();
                outEntry->isModification = it.IsModification();
                switch (evo) {
                    case TNaming_PRIMITIVE: outEntry->evolution = OCCTNamingPrimitive; break;
                    case TNaming_GENERATED: outEntry->evolution = OCCTNamingGenerated; break;
                    case TNaming_MODIFY: outEntry->evolution = OCCTNamingModify; break;
                    case TNaming_DELETE: outEntry->evolution = OCCTNamingDelete; break;
                    case TNaming_SELECTED: outEntry->evolution = OCCTNamingSelected; break;
                    default: outEntry->evolution = OCCTNamingPrimitive; break;
                }
                return true;
            }
        }
        return false;
    } catch (...) {
        return false;
    }
}

OCCTShapeRef OCCTDocumentNamingGetOldShape(OCCTDocumentRef doc, int64_t labelId, int32_t index) {
    if (!doc || doc->doc.IsNull()) return nullptr;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return nullptr;

        Handle(TNaming_NamedShape) ns;
        if (!label.FindAttribute(TNaming_NamedShape::GetID(), ns)) return nullptr;

        int32_t i = 0;
        for (TNaming_Iterator it(ns); it.More(); it.Next(), i++) {
            if (i == index) {
                TopoDS_Shape old = it.OldShape();
                if (old.IsNull()) return nullptr;
                return new OCCTShape(old);
            }
        }
        return nullptr;
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTDocumentNamingGetNewShape(OCCTDocumentRef doc, int64_t labelId, int32_t index) {
    if (!doc || doc->doc.IsNull()) return nullptr;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return nullptr;

        Handle(TNaming_NamedShape) ns;
        if (!label.FindAttribute(TNaming_NamedShape::GetID(), ns)) return nullptr;

        int32_t i = 0;
        for (TNaming_Iterator it(ns); it.More(); it.Next(), i++) {
            if (i == index) {
                TopoDS_Shape nw = it.NewShape();
                if (nw.IsNull()) return nullptr;
                return new OCCTShape(nw);
            }
        }
        return nullptr;
    } catch (...) {
        return nullptr;
    }
}

int32_t OCCTDocumentNamingTraceForward(OCCTDocumentRef doc, int64_t accessLabelId,
                                        OCCTShapeRef shape,
                                        OCCTShapeRef* outShapes, int32_t maxCount) {
    if (!doc || !shape || !outShapes || doc->doc.IsNull()) return 0;
    try {
        TDF_Label access = doc->getLabel(accessLabelId);
        if (access.IsNull()) return 0;

        int32_t count = 0;
        for (TNaming_NewShapeIterator it(shape->shape, access);
             it.More() && count < maxCount; it.Next()) {
            TopoDS_Shape s = it.Shape();
            if (!s.IsNull()) {
                outShapes[count] = new OCCTShape(s);
                count++;
            }
        }
        return count;
    } catch (...) {
        return 0;
    }
}

int32_t OCCTDocumentNamingTraceBackward(OCCTDocumentRef doc, int64_t accessLabelId,
                                         OCCTShapeRef shape,
                                         OCCTShapeRef* outShapes, int32_t maxCount) {
    if (!doc || !shape || !outShapes || doc->doc.IsNull()) return 0;
    try {
        TDF_Label access = doc->getLabel(accessLabelId);
        if (access.IsNull()) return 0;

        int32_t count = 0;
        for (TNaming_OldShapeIterator it(shape->shape, access);
             it.More() && count < maxCount; it.Next()) {
            TopoDS_Shape s = it.Shape();
            if (!s.IsNull()) {
                outShapes[count] = new OCCTShape(s);
                count++;
            }
        }
        return count;
    } catch (...) {
        return 0;
    }
}

bool OCCTDocumentNamingSelect(OCCTDocumentRef doc, int64_t labelId,
                               OCCTShapeRef selection, OCCTShapeRef context) {
    if (!doc || !selection || !context || doc->doc.IsNull()) return false;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return false;

        TNaming_Selector selector(label);
        return selector.Select(selection->shape, context->shape);
    } catch (...) {
        return false;
    }
}

OCCTShapeRef OCCTDocumentNamingResolve(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return nullptr;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return nullptr;

        TNaming_Selector selector(label);
        TDF_LabelMap valid;
        if (!selector.Solve(valid)) return nullptr;

        Handle(TNaming_NamedShape) ns = selector.NamedShape();
        if (ns.IsNull() || ns->IsEmpty()) return nullptr;

        TopoDS_Shape shape = TNaming_Tool::CurrentShape(ns);
        if (shape.IsNull()) return nullptr;

        return new OCCTShape(shape);
    } catch (...) {
        return nullptr;
    }
}

int32_t OCCTDocumentNamingGetEvolution(OCCTDocumentRef doc, int64_t labelId) {
    if (!doc || doc->doc.IsNull()) return -1;
    try {
        TDF_Label label = doc->getLabel(labelId);
        if (label.IsNull()) return -1;

        Handle(TNaming_NamedShape) ns;
        if (!label.FindAttribute(TNaming_NamedShape::GetID(), ns)) return -1;

        switch (ns->Evolution()) {
            case TNaming_PRIMITIVE: return OCCTNamingPrimitive;
            case TNaming_GENERATED: return OCCTNamingGenerated;
            case TNaming_MODIFY: return OCCTNamingModify;
            case TNaming_DELETE: return OCCTNamingDelete;
            case TNaming_SELECTED: return OCCTNamingSelected;
            default: return -1;
        }
    } catch (...) {
        return -1;
    }
}


// ============================================================
