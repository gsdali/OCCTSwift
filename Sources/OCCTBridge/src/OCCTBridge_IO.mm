//
//  OCCTBridge_IO.mm
//  OCCTSwift
//
//  Extracted from OCCTBridge.mm — issue #99.
//
//  File I/O surface: STEP / IGES / STL / BREP / OBJ writers and the matching
//  importers. Plus the import-progress + cancellation channel from v0.168.0
//  / v0.169.0 (issue #98), since those entry points share readers/writers
//  with the synchronous variants.
//
//  Public C surface unchanged. No symbol changes — pure file move.
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

// === Area-specific OCCT headers ===

#include <STEPControl_Reader.hxx>
#include <STEPControl_Writer.hxx>
#include <STEPControl_StepModelType.hxx>
#include <STEPCAFControl_Reader.hxx>
#include <STEPCAFControl_Writer.hxx>
#include <IGESControl_Reader.hxx>
#include <IGESControl_Writer.hxx>
#include <Interface_Static.hxx>
#include <IFSelect_ReturnStatus.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepBuilderAPI_Sewing.hxx>
#include <BRepBuilderAPI_MakeSolid.hxx>
#include <ShapeFix_Shape.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Shell.hxx>
#include <Message_ProgressIndicator.hxx>
#include <Message_ProgressScope.hxx>
#include <Message_ProgressRange.hxx>
#include <XCAFDoc_DocumentTool.hxx>
#include <TDF_LabelSequence.hxx>
#include <TDF_Label.hxx>
#include <RWObj_CafReader.hxx>
#include <RWObj_CafWriter.hxx>
#include <RWPly_CafWriter.hxx>
#include <TDocStd_Document.hxx>
#include <XCAFApp_Application.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <StlAPI_Writer.hxx>
#include <StlAPI_Reader.hxx>
#include <BinTools.hxx>
#include <BRepTools.hxx>
#include <BRep_Builder.hxx>

// MARK: - Export

bool OCCTExportSTL(OCCTShapeRef shape, const char* path, double deflection) {
    if (!shape || !path) return false;

    try {
        // Mesh the shape first
        BRepMesh_IncrementalMesh mesher(shape->shape, deflection);
        mesher.Perform();

        StlAPI_Writer writer;
        writer.ASCIIMode() = Standard_False; // Binary STL for smaller files
        return writer.Write(shape->shape, path);
    } catch (...) {
        return false;
    }
}

bool OCCTExportSTLWithMode(OCCTShapeRef shape, const char* path, double deflection, bool ascii) {
    if (!shape || !path) return false;

    try {
        BRepMesh_IncrementalMesh mesher(shape->shape, deflection);
        mesher.Perform();

        StlAPI_Writer writer;
        writer.ASCIIMode() = ascii ? Standard_True : Standard_False;
        return writer.Write(shape->shape, path);
    } catch (...) {
        return false;
    }
}

bool OCCTExportSTEP(OCCTShapeRef shape, const char* path) {
    if (!shape || !path) return false;

    try {
        // Use a scoped block to ensure all OCCT objects are destroyed before return
        bool success = false;
        {
            STEPControl_Writer writer;
            Interface_Static::SetCVal("write.step.schema", "AP214");

            IFSelect_ReturnStatus status = writer.Transfer(shape->shape, STEPControl_AsIs);
            if (status != IFSelect_RetDone) {
                return false;
            }

            status = writer.Write(path);
            success = (status == IFSelect_RetDone);

            // Writer goes out of scope here and is automatically destroyed
        }
        return success;
    } catch (...) {
        return false;
    }
}

bool OCCTExportSTEPWithName(OCCTShapeRef shape, const char* path, const char* name) {
    if (!shape || !path) return false;

    try {
        // Use a scoped block to ensure all OCCT objects are destroyed before return
        bool success = false;
        {
            STEPControl_Writer writer;
            Interface_Static::SetCVal("write.step.schema", "AP214");
            if (name) {
                Interface_Static::SetCVal("write.step.product.name", name);
            }

            IFSelect_ReturnStatus status = writer.Transfer(shape->shape, STEPControl_AsIs);
            if (status != IFSelect_RetDone) {
                return false;
            }

            status = writer.Write(path);
            success = (status == IFSelect_RetDone);

            // Writer goes out of scope here and is automatically destroyed
        }
        return success;
    } catch (...) {
        return false;
    }
}

// MARK: - Import progress + cancellation (v0.168.0, issue #98)

#include <Message_ProgressIndicator.hxx>
#include <Message_ProgressScope.hxx>
#include <Message_ProgressRange.hxx>

// Forward decl: igesMutex() is defined alongside the existing IGES bridge functions
// further down in the file. The Progress variants need to take the same lock.

namespace {

class BridgeProgressIndicator : public Message_ProgressIndicator {
public:
    BridgeProgressIndicator(const OCCTImportProgress* ctx) : myCtx(ctx) {}

    void Show(const Message_ProgressScope& theScope, const Standard_Boolean isForce) override {
        (void)isForce;
        if (!myCtx || !myCtx->onProgress) return;
        // GetPosition() reports global progress 0.0...1.0.
        const double fraction = GetPosition();
        const char* name = theScope.Name();
        myCtx->onProgress(fraction, name, myCtx->userData);
    }

    Standard_Boolean UserBreak() override {
        if (!myCtx || !myCtx->shouldCancel) return Standard_False;
        return myCtx->shouldCancel(myCtx->userData) ? Standard_True : Standard_False;
    }

    DEFINE_STANDARD_RTTI_INLINE(BridgeProgressIndicator, Message_ProgressIndicator)

private:
    const OCCTImportProgress* myCtx;
};

DEFINE_STANDARD_HANDLE(BridgeProgressIndicator, Message_ProgressIndicator)

static inline void clearCancelOut(bool* outCancelled) {
    if (outCancelled) *outCancelled = false;
}
static inline void setCancelOut(bool* outCancelled, opencascade::handle<BridgeProgressIndicator>& ind) {
    if (outCancelled && !ind.IsNull()) *outCancelled = ind->UserBreak() ? true : false;
}

}

OCCTShapeRef OCCTImportSTEPProgress(const char* path,
                                      const OCCTImportProgress* ctx,
                                      bool* outCancelled) {
    clearCancelOut(outCancelled);
    if (!path) return nullptr;
    try {
        STEPControl_Reader reader;
        IFSelect_ReturnStatus status = reader.ReadFile(path);
        if (status != IFSelect_RetDone) return nullptr;

        opencascade::handle<BridgeProgressIndicator> indicator = new BridgeProgressIndicator(ctx);
        Message_ProgressRange range = indicator->Start();
        reader.TransferRoots(range);
        if (indicator->UserBreak()) { setCancelOut(outCancelled, indicator); return nullptr; }

        TopoDS_Shape shape = reader.OneShape();
        if (shape.IsNull()) return nullptr;
        return new OCCTShape(shape);
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTImportSTEPRobustProgress(const char* path,
                                            const OCCTImportProgress* ctx,
                                            bool* outCancelled) {
    clearCancelOut(outCancelled);
    if (!path) return nullptr;
    try {
        STEPControl_Reader reader;
        Interface_Static::SetIVal("read.precision.mode", 0);
        Interface_Static::SetRVal("read.maxprecision.val", 0.1);
        Interface_Static::SetIVal("read.surfacecurve.mode", 3);
        Interface_Static::SetIVal("read.step.product.mode", 1);

        IFSelect_ReturnStatus status = reader.ReadFile(path);
        if (status != IFSelect_RetDone) return nullptr;

        opencascade::handle<BridgeProgressIndicator> indicator = new BridgeProgressIndicator(ctx);
        Message_ProgressRange range = indicator->Start();
        if (reader.TransferRoots(range) == 0) return nullptr;
        if (indicator->UserBreak()) { setCancelOut(outCancelled, indicator); return nullptr; }

        TopoDS_Shape shape = reader.OneShape();
        if (shape.IsNull()) return nullptr;

        TopAbs_ShapeEnum shapeType = shape.ShapeType();
        if (shapeType == TopAbs_SOLID) {
            ShapeFix_Shape fixer(shape);
            fixer.Perform();
            TopoDS_Shape fixed = fixer.Shape();
            return new OCCTShape(fixed.IsNull() ? shape : fixed);
        }
        if (shapeType == TopAbs_COMPOUND || shapeType == TopAbs_SHELL || shapeType == TopAbs_FACE) {
            BRepBuilderAPI_Sewing sewing(1.0e-4);
            sewing.SetNonManifoldMode(Standard_False);
            sewing.Add(shape);
            sewing.Perform();
            TopoDS_Shape sewedShape = sewing.SewedShape();
            if (sewedShape.IsNull()) sewedShape = shape;

            TopoDS_Shape resultShape = sewedShape;
            if (sewedShape.ShapeType() != TopAbs_SOLID) {
                TopExp_Explorer shellExp(sewedShape, TopAbs_SHELL);
                if (shellExp.More()) {
                    BRepBuilderAPI_MakeSolid makeSolid(TopoDS::Shell(shellExp.Current()));
                    if (makeSolid.IsDone()) resultShape = makeSolid.Solid();
                }
            }
            ShapeFix_Shape fixer(resultShape);
            fixer.Perform();
            TopoDS_Shape fixed = fixer.Shape();
            return new OCCTShape(fixed.IsNull() ? resultShape : fixed);
        }
        ShapeFix_Shape fixer(shape);
        fixer.Perform();
        TopoDS_Shape fixed = fixer.Shape();
        return new OCCTShape(fixed.IsNull() ? shape : fixed);
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTImportSTEPWithUnitProgress(const char* path, double unitInMeters,
                                              const OCCTImportProgress* ctx,
                                              bool* outCancelled) {
    clearCancelOut(outCancelled);
    if (!path) return nullptr;
    try {
        STEPControl_Reader reader;
        reader.SetSystemLengthUnit(unitInMeters);
        IFSelect_ReturnStatus status = reader.ReadFile(path);
        if (status != IFSelect_RetDone) return nullptr;

        opencascade::handle<BridgeProgressIndicator> indicator = new BridgeProgressIndicator(ctx);
        Message_ProgressRange range = indicator->Start();
        reader.TransferRoots(range);
        if (indicator->UserBreak()) { setCancelOut(outCancelled, indicator); return nullptr; }

        TopoDS_Shape shape = reader.OneShape();
        if (shape.IsNull()) return nullptr;
        return new OCCTShape(shape);
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTImportIGESProgress(const char* path,
                                      const OCCTImportProgress* ctx,
                                      bool* outCancelled) {
    clearCancelOut(outCancelled);
    if (!path) return nullptr;
    std::lock_guard<std::mutex> igesLock(igesMutex());
    try {
        IGESControl_Reader reader;
        IFSelect_ReturnStatus status = reader.ReadFile(path);
        if (status != IFSelect_RetDone) return nullptr;

        opencascade::handle<BridgeProgressIndicator> indicator = new BridgeProgressIndicator(ctx);
        Message_ProgressRange range = indicator->Start();
        reader.TransferRoots(range);
        if (indicator->UserBreak()) { setCancelOut(outCancelled, indicator); return nullptr; }

        TopoDS_Shape shape = reader.OneShape();
        if (shape.IsNull()) return nullptr;
        return new OCCTShape(shape);
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTImportIGESRobustProgress(const char* path,
                                            const OCCTImportProgress* ctx,
                                            bool* outCancelled) {
    clearCancelOut(outCancelled);
    if (!path) return nullptr;
    std::lock_guard<std::mutex> igesLock(igesMutex());
    try {
        IGESControl_Reader reader;
        Interface_Static::SetIVal("read.precision.mode", 0);
        Interface_Static::SetRVal("read.precision.val", 0.0001);

        IFSelect_ReturnStatus status = reader.ReadFile(path);
        if (status != IFSelect_RetDone) return nullptr;

        opencascade::handle<BridgeProgressIndicator> indicator = new BridgeProgressIndicator(ctx);
        Message_ProgressRange range = indicator->Start();
        if (reader.TransferRoots(range) == 0) return nullptr;
        if (indicator->UserBreak()) { setCancelOut(outCancelled, indicator); return nullptr; }

        TopoDS_Shape shape = reader.OneShape();
        if (shape.IsNull()) return nullptr;

        ShapeFix_Shape fixer(shape);
        fixer.Perform();
        TopoDS_Shape fixed = fixer.Shape();
        return new OCCTShape(fixed.IsNull() ? shape : fixed);
    } catch (...) { return nullptr; }
}

OCCTDocumentRef OCCTDocumentLoadSTEPProgress(const char* path,
                                               const OCCTImportProgress* ctx,
                                               bool* outCancelled) {
    clearCancelOut(outCancelled);
    if (!path) return nullptr;
    OCCTDocument* document = nullptr;
    try {
        document = new OCCTDocument();
        document->app->NewDocument("MDTV-XCAF", document->doc);
        if (document->doc.IsNull()) { delete document; return nullptr; }

        STEPCAFControl_Reader reader;
        reader.SetColorMode(Standard_True);
        reader.SetNameMode(Standard_True);
        reader.SetLayerMode(Standard_True);
        reader.SetPropsMode(Standard_True);
        reader.SetMatMode(Standard_True);

        IFSelect_ReturnStatus status = reader.ReadFile(path);
        if (status != IFSelect_RetDone) { delete document; return nullptr; }

        opencascade::handle<BridgeProgressIndicator> indicator = new BridgeProgressIndicator(ctx);
        Message_ProgressRange range = indicator->Start();
        bool ok = reader.Transfer(document->doc, range);
        if (indicator->UserBreak()) { setCancelOut(outCancelled, indicator); delete document; return nullptr; }
        if (!ok) { delete document; return nullptr; }

        document->shapeTool = XCAFDoc_DocumentTool::ShapeTool(document->doc->Main());
        document->colorTool = XCAFDoc_DocumentTool::ColorTool(document->doc->Main());
        document->materialTool = XCAFDoc_DocumentTool::VisMaterialTool(document->doc->Main());
        return document;
    } catch (...) { delete document; return nullptr; }
}

// MARK: - Mesh + export progress (v0.169.0, issue #98 follow-up)

OCCTShapeRef OCCTShapeIncrementalMeshProgress(OCCTShapeRef shape,
                                                double linearDeflection,
                                                double angularDeflection,
                                                const OCCTImportProgress* ctx,
                                                bool* outCancelled) {
    clearCancelOut(outCancelled);
    if (!shape) return nullptr;
    try {
        opencascade::handle<BridgeProgressIndicator> indicator = new BridgeProgressIndicator(ctx);
        Message_ProgressRange range = indicator->Start();
        BRepMesh_IncrementalMesh mesher(shape->shape, linearDeflection, Standard_False, angularDeflection);
        mesher.Perform(range);
        if (indicator->UserBreak()) { setCancelOut(outCancelled, indicator); return nullptr; }
        // Return a new OCCTShape wrapping the same (now-meshed) TopoDS_Shape so callers
        // can chain. The original handle is also valid.
        return new OCCTShape(shape->shape);
    } catch (...) { return nullptr; }
}

bool OCCTExportSTEPProgress(OCCTShapeRef shape, const char* path,
                              const OCCTImportProgress* ctx, bool* outCancelled) {
    clearCancelOut(outCancelled);
    if (!shape || !path) return false;
    try {
        STEPControl_Writer writer;
        Interface_Static::SetCVal("write.step.schema", "AP214");
        opencascade::handle<BridgeProgressIndicator> indicator = new BridgeProgressIndicator(ctx);
        Message_ProgressRange range = indicator->Start();
        IFSelect_ReturnStatus status = writer.Transfer(shape->shape, STEPControl_AsIs, true, range);
        if (indicator->UserBreak()) { setCancelOut(outCancelled, indicator); return false; }
        if (status != IFSelect_RetDone) return false;
        return writer.Write(path) == IFSelect_RetDone;
    } catch (...) { return false; }
}

bool OCCTExportSTEPWithModeProgress(OCCTShapeRef shape, const char* path, int32_t modelType,
                                      const OCCTImportProgress* ctx, bool* outCancelled) {
    clearCancelOut(outCancelled);
    if (!shape || !path) return false;
    try {
        STEPControl_Writer writer;
        Interface_Static::SetCVal("write.step.schema", "AP214");
        opencascade::handle<BridgeProgressIndicator> indicator = new BridgeProgressIndicator(ctx);
        Message_ProgressRange range = indicator->Start();
        STEPControl_StepModelType mode = static_cast<STEPControl_StepModelType>(modelType);
        IFSelect_ReturnStatus status = writer.Transfer(shape->shape, mode, true, range);
        if (indicator->UserBreak()) { setCancelOut(outCancelled, indicator); return false; }
        if (status != IFSelect_RetDone) return false;
        return writer.Write(path) == IFSelect_RetDone;
    } catch (...) { return false; }
}

bool OCCTExportIGESProgress(OCCTShapeRef shape, const char* path,
                              const OCCTImportProgress* ctx, bool* outCancelled) {
    clearCancelOut(outCancelled);
    if (!shape || !path || shape->shape.IsNull()) return false;
    std::lock_guard<std::mutex> igesLock(igesMutex());
    try {
        BRepCheck_Analyzer analyzer(shape->shape);
        if (!analyzer.IsValid()) return false;

        IGESControl_Writer writer("MM", 0);
        opencascade::handle<BridgeProgressIndicator> indicator = new BridgeProgressIndicator(ctx);
        Message_ProgressRange range = indicator->Start();
        if (!writer.AddShape(shape->shape, range)) return false;
        if (indicator->UserBreak()) { setCancelOut(outCancelled, indicator); return false; }
        writer.ComputeModel();
        return writer.Write(path);
    } catch (...) { return false; }
}

bool OCCTDocumentWriteSTEPProgress(OCCTDocumentRef doc, const char* path,
                                     const OCCTImportProgress* ctx, bool* outCancelled) {
    clearCancelOut(outCancelled);
    if (!doc || !path) return false;
    try {
        STEPCAFControl_Writer writer;
        writer.SetColorMode(Standard_True);
        writer.SetNameMode(Standard_True);
        writer.SetLayerMode(Standard_True);
        writer.SetPropsMode(Standard_True);
        writer.SetMaterialMode(Standard_True);
        opencascade::handle<BridgeProgressIndicator> indicator = new BridgeProgressIndicator(ctx);
        Message_ProgressRange range = indicator->Start();
        if (!writer.Transfer(doc->doc, STEPControl_AsIs, nullptr, range)) {
            if (indicator->UserBreak()) { setCancelOut(outCancelled, indicator); return false; }
            return false;
        }
        if (indicator->UserBreak()) { setCancelOut(outCancelled, indicator); return false; }
        IFSelect_ReturnStatus status = writer.Write(path);
        return status == IFSelect_RetDone;
    } catch (...) { return false; }
}

OCCTDocumentRef OCCTDocumentLoadSTEPWithModesProgress(const char* path,
                                                        bool colorMode, bool nameMode, bool layerMode,
                                                        bool propsMode, bool gdtMode, bool matMode,
                                                        const OCCTImportProgress* ctx,
                                                        bool* outCancelled) {
    clearCancelOut(outCancelled);
    if (!path) return nullptr;
    OCCTDocument* document = nullptr;
    try {
        document = new OCCTDocument();
        document->app->NewDocument("MDTV-XCAF", document->doc);
        if (document->doc.IsNull()) { delete document; return nullptr; }

        STEPCAFControl_Reader reader;
        reader.SetColorMode(colorMode);
        reader.SetNameMode(nameMode);
        reader.SetLayerMode(layerMode);
        reader.SetPropsMode(propsMode);
        reader.SetGDTMode(gdtMode);
        reader.SetMatMode(matMode);

        IFSelect_ReturnStatus status = reader.ReadFile(path);
        if (status != IFSelect_RetDone) { delete document; return nullptr; }

        opencascade::handle<BridgeProgressIndicator> indicator = new BridgeProgressIndicator(ctx);
        Message_ProgressRange range = indicator->Start();
        bool ok = reader.Transfer(document->doc, range);
        if (indicator->UserBreak()) { setCancelOut(outCancelled, indicator); delete document; return nullptr; }
        if (!ok) { delete document; return nullptr; }

        document->shapeTool = XCAFDoc_DocumentTool::ShapeTool(document->doc->Main());
        document->colorTool = XCAFDoc_DocumentTool::ColorTool(document->doc->Main());
        document->materialTool = XCAFDoc_DocumentTool::VisMaterialTool(document->doc->Main());
        return document;
    } catch (...) { delete document; return nullptr; }
}

// MARK: - Import

OCCTShapeRef OCCTImportSTEP(const char* path) {
    if (!path) return nullptr;

    try {
        STEPControl_Reader reader;
        IFSelect_ReturnStatus status = reader.ReadFile(path);
        if (status != IFSelect_RetDone) return nullptr;

        // Transfer all roots
        reader.TransferRoots();

        // Get the result as a single shape (compound if multiple)
        TopoDS_Shape shape = reader.OneShape();
        if (shape.IsNull()) return nullptr;

        return new OCCTShape(shape);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - Robust STEP Import

int OCCTShapeGetType(OCCTShapeRef shape) {
    if (!shape) return -1;
    return static_cast<int>(shape->shape.ShapeType());
}

bool OCCTShapeIsValidSolid(OCCTShapeRef shape) {
    if (!shape) return false;
    try {
        if (shape->shape.ShapeType() != TopAbs_SOLID) return false;
        BRepCheck_Analyzer analyzer(shape->shape);
        return analyzer.IsValid();
    } catch (...) {
        return false;
    }
}

OCCTShapeRef OCCTImportSTEPRobust(const char* path) {
    if (!path) return nullptr;

    try {
        STEPControl_Reader reader;

        // Configure reader for better precision handling
        Interface_Static::SetIVal("read.precision.mode", 0);
        Interface_Static::SetRVal("read.maxprecision.val", 0.1);
        Interface_Static::SetIVal("read.surfacecurve.mode", 3);
        Interface_Static::SetIVal("read.step.product.mode", 1);

        IFSelect_ReturnStatus status = reader.ReadFile(path);
        if (status != IFSelect_RetDone) return nullptr;

        if (reader.TransferRoots() == 0) return nullptr;

        TopoDS_Shape shape = reader.OneShape();
        if (shape.IsNull()) return nullptr;

        TopAbs_ShapeEnum shapeType = shape.ShapeType();

        // If already a solid, just apply healing
        if (shapeType == TopAbs_SOLID) {
            ShapeFix_Shape fixer(shape);
            fixer.Perform();
            TopoDS_Shape fixed = fixer.Shape();
            return new OCCTShape(fixed.IsNull() ? shape : fixed);
        }

        // Try sewing and solid creation for non-solids
        if (shapeType == TopAbs_COMPOUND || shapeType == TopAbs_SHELL ||
            shapeType == TopAbs_FACE) {

            // Sew disconnected faces/shells
            BRepBuilderAPI_Sewing sewing(1.0e-4);
            sewing.SetNonManifoldMode(Standard_False);
            sewing.Add(shape);
            sewing.Perform();
            TopoDS_Shape sewedShape = sewing.SewedShape();
            if (sewedShape.IsNull()) sewedShape = shape;

            // Try to create solid from shell
            TopoDS_Shape resultShape = sewedShape;
            if (sewedShape.ShapeType() != TopAbs_SOLID) {
                TopExp_Explorer shellExp(sewedShape, TopAbs_SHELL);
                if (shellExp.More()) {
                    BRepBuilderAPI_MakeSolid makeSolid(TopoDS::Shell(shellExp.Current()));
                    if (makeSolid.IsDone()) {
                        resultShape = makeSolid.Solid();
                    }
                }
            }

            // Apply shape healing
            ShapeFix_Shape fixer(resultShape);
            fixer.Perform();
            TopoDS_Shape fixed = fixer.Shape();
            return new OCCTShape(fixed.IsNull() ? resultShape : fixed);
        }

        // Fallback: just heal whatever we got
        ShapeFix_Shape fixer(shape);
        fixer.Perform();
        TopoDS_Shape fixed = fixer.Shape();
        return new OCCTShape(fixed.IsNull() ? shape : fixed);

    } catch (...) {
        return nullptr;
    }
}

OCCTSTEPImportResult OCCTImportSTEPWithDiagnostics(const char* path) {
    OCCTSTEPImportResult result = {nullptr, -1, -1, false, false, false};
    if (!path) return result;

    try {
        STEPControl_Reader reader;

        // Configure reader
        Interface_Static::SetIVal("read.precision.mode", 0);
        Interface_Static::SetRVal("read.maxprecision.val", 0.1);
        Interface_Static::SetIVal("read.surfacecurve.mode", 3);
        Interface_Static::SetIVal("read.step.product.mode", 1);

        if (reader.ReadFile(path) != IFSelect_RetDone) return result;
        if (reader.TransferRoots() == 0) return result;

        TopoDS_Shape shape = reader.OneShape();
        if (shape.IsNull()) return result;

        result.originalType = static_cast<int>(shape.ShapeType());

        // Process non-solids
        if (shape.ShapeType() != TopAbs_SOLID) {
            // Try sewing
            BRepBuilderAPI_Sewing sewing(1.0e-4);
            sewing.SetNonManifoldMode(Standard_False);
            sewing.Add(shape);
            sewing.Perform();
            TopoDS_Shape sewedShape = sewing.SewedShape();
            if (!sewedShape.IsNull() && !sewedShape.IsSame(shape)) {
                shape = sewedShape;
                result.sewingApplied = true;
            }

            // Try solid creation
            if (shape.ShapeType() != TopAbs_SOLID) {
                TopExp_Explorer shellExp(shape, TopAbs_SHELL);
                if (shellExp.More()) {
                    BRepBuilderAPI_MakeSolid makeSolid(TopoDS::Shell(shellExp.Current()));
                    if (makeSolid.IsDone()) {
                        shape = makeSolid.Solid();
                        result.solidCreated = true;
                    }
                }
            }
        }

        // Apply shape healing
        ShapeFix_Shape fixer(shape);
        fixer.Perform();
        TopoDS_Shape fixed = fixer.Shape();
        if (!fixed.IsNull()) {
            shape = fixed;
            result.healingApplied = true;
        }

        result.shape = new OCCTShape(shape);
        result.resultType = static_cast<int>(shape.ShapeType());
        return result;

    } catch (...) {
        return result;
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
// MARK: - STL Import (v0.17.0)

#include <StlAPI_Reader.hxx>

OCCTShapeRef OCCTImportSTL(const char* path) {
    if (!path) return nullptr;

    try {
        TopoDS_Shape shape;
        StlAPI_Reader reader;
        if (!reader.Read(shape, path)) return nullptr;
        if (shape.IsNull()) return nullptr;
        return new OCCTShape(shape);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTImportSTLRobust(const char* path, double sewingTolerance) {
    if (!path) return nullptr;

    try {
        TopoDS_Shape shape;
        StlAPI_Reader reader;
        if (!reader.Read(shape, path)) return nullptr;
        if (shape.IsNull()) return nullptr;

        // Sew disconnected faces
        BRepBuilderAPI_Sewing sewing(sewingTolerance);
        sewing.Add(shape);
        sewing.Perform();
        TopoDS_Shape sewedShape = sewing.SewedShape();
        if (sewedShape.IsNull()) sewedShape = shape;

        // Try to create solid from shell
        TopoDS_Shape resultShape = sewedShape;
        if (sewedShape.ShapeType() != TopAbs_SOLID) {
            TopExp_Explorer shellExp(sewedShape, TopAbs_SHELL);
            if (shellExp.More()) {
                BRepBuilderAPI_MakeSolid makeSolid(TopoDS::Shell(shellExp.Current()));
                if (makeSolid.IsDone()) {
                    resultShape = makeSolid.Solid();
                }
            }
        }

        // Apply shape healing
        ShapeFix_Shape fixer(resultShape);
        fixer.Perform();
        TopoDS_Shape fixed = fixer.Shape();
        return new OCCTShape(fixed.IsNull() ? resultShape : fixed);
    } catch (...) {
        return nullptr;
    }
}


// MARK: - OBJ Import/Export (v0.17.0)

#include <RWObj_CafReader.hxx>
#include <RWObj_CafWriter.hxx>
#include <TDocStd_Document.hxx>
#include <XCAFApp_Application.hxx>
#include <XCAFDoc_DocumentTool.hxx>
#include <Message_ProgressRange.hxx>

OCCTShapeRef OCCTImportOBJ(const char* path) {
    if (!path) return nullptr;

    try {
        // Use RWObj_CafReader for OBJ import
        RWObj_CafReader objReader;

        // Create an XDE document
        Handle(TDocStd_Document) doc;
        Handle(XCAFApp_Application) app = XCAFApp_Application::GetApplication();
        app->NewDocument("MDTV-XCAF", doc);

        objReader.SetDocument(doc);
        TCollection_AsciiString filePath(path);
        if (!objReader.Perform(filePath, Message_ProgressRange())) return nullptr;

        // Extract shape from document
        Handle(XCAFDoc_ShapeTool) shapeTool = XCAFDoc_DocumentTool::ShapeTool(doc->Main());
        TopoDS_Shape shape = shapeTool->GetOneShape();
        if (shape.IsNull()) return nullptr;

        // Close document
        app->Close(doc);

        return new OCCTShape(shape);
    } catch (...) {
        return nullptr;
    }
}

bool OCCTExportOBJ(OCCTShapeRef shape, const char* path, double deflection) {
    if (!shape || !path) return false;

    try {
        // Tessellate the shape first
        BRepMesh_IncrementalMesh mesher(shape->shape, deflection);
        mesher.Perform();

        // Create an XDE document
        Handle(TDocStd_Document) doc;
        Handle(XCAFApp_Application) app = XCAFApp_Application::GetApplication();
        app->NewDocument("MDTV-XCAF", doc);

        Handle(XCAFDoc_ShapeTool) shapeTool = XCAFDoc_DocumentTool::ShapeTool(doc->Main());
        shapeTool->AddShape(shape->shape);

        // Write OBJ
        RWObj_CafWriter writer(path);
        NCollection_Sequence<TDF_Label> rootLabels;
        TDF_LabelSequence freeShapes;
        shapeTool->GetFreeShapes(freeShapes);
        for (int i = 1; i <= freeShapes.Length(); ++i) {
            rootLabels.Append(freeShapes.Value(i));
        }
        NCollection_IndexedDataMap<TCollection_AsciiString, TCollection_AsciiString> fileInfo;
        bool success = writer.Perform(doc, rootLabels, nullptr, fileInfo, Message_ProgressRange());

        app->Close(doc);
        return success;
    } catch (...) {
        return false;
    }
}


// MARK: - PLY Export (v0.17.0)

#include <RWPly_CafWriter.hxx>

bool OCCTExportPLY(OCCTShapeRef shape, const char* path, double deflection) {
    if (!shape || !path) return false;

    try {
        // Tessellate the shape first
        BRepMesh_IncrementalMesh mesher(shape->shape, deflection);
        mesher.Perform();

        // Create an XDE document
        Handle(TDocStd_Document) doc;
        Handle(XCAFApp_Application) app = XCAFApp_Application::GetApplication();
        app->NewDocument("MDTV-XCAF", doc);

        Handle(XCAFDoc_ShapeTool) shapeTool = XCAFDoc_DocumentTool::ShapeTool(doc->Main());
        shapeTool->AddShape(shape->shape);

        // Write PLY
        RWPly_CafWriter writer(path);
        writer.SetNormals(true);
        NCollection_Sequence<TDF_Label> rootLabels;
        TDF_LabelSequence freeShapes;
        shapeTool->GetFreeShapes(freeShapes);
        for (int i = 1; i <= freeShapes.Length(); ++i) {
            rootLabels.Append(freeShapes.Value(i));
        }
        NCollection_IndexedDataMap<TCollection_AsciiString, TCollection_AsciiString> fileInfo;
        bool success = writer.Perform(doc, rootLabels, nullptr, fileInfo, Message_ProgressRange());

        app->Close(doc);
        return success;
    } catch (...) {
        return false;
    }
}


// MARK: - STEP Full Coverage — STEPControl_Writer (v0.58.0)

bool OCCTExportSTEPWithMode(OCCTShapeRef shape, const char* path, int32_t modelType) {
    if (!shape || !path) return false;
    try {
        STEPControl_Writer writer;
        Interface_Static::SetCVal("write.step.schema", "AP214");
        STEPControl_StepModelType mode = static_cast<STEPControl_StepModelType>(modelType);
        IFSelect_ReturnStatus status = writer.Transfer(shape->shape, mode);
        if (status != IFSelect_RetDone) return false;
        status = writer.Write(path);
        return status == IFSelect_RetDone;
    } catch (...) { return false; }
}

bool OCCTExportSTEPWithModeAndTolerance(OCCTShapeRef shape, const char* path,
                                         int32_t modelType, double tolerance) {
    if (!shape || !path) return false;
    try {
        STEPControl_Writer writer;
        Interface_Static::SetCVal("write.step.schema", "AP214");
        writer.SetTolerance(tolerance);
        STEPControl_StepModelType mode = static_cast<STEPControl_StepModelType>(modelType);
        IFSelect_ReturnStatus status = writer.Transfer(shape->shape, mode);
        if (status != IFSelect_RetDone) return false;
        status = writer.Write(path);
        return status == IFSelect_RetDone;
    } catch (...) { return false; }
}

bool OCCTExportSTEPCleanDuplicates(OCCTShapeRef shape, const char* path, int32_t modelType) {
    if (!shape || !path) return false;
    try {
        STEPControl_Writer writer;
        Interface_Static::SetCVal("write.step.schema", "AP214");
        STEPControl_StepModelType mode = static_cast<STEPControl_StepModelType>(modelType);
        IFSelect_ReturnStatus status = writer.Transfer(shape->shape, mode);
        if (status != IFSelect_RetDone) return false;
        writer.CleanDuplicateEntities();
        status = writer.Write(path);
        return status == IFSelect_RetDone;
    } catch (...) { return false; }
}

// MARK: - STEP Full Coverage — STEPControl_Reader (v0.58.0)

int32_t OCCTSTEPReaderNbRoots(const char* path) {
    if (!path) return 0;
    try {
        STEPControl_Reader reader;
        IFSelect_ReturnStatus status = reader.ReadFile(path);
        if (status != IFSelect_RetDone) return 0;
        return reader.NbRootsForTransfer();
    } catch (...) { return 0; }
}

OCCTShapeRef OCCTImportSTEPRoot(const char* path, int32_t rootIndex) {
    if (!path || rootIndex < 1) return nullptr;
    try {
        STEPControl_Reader reader;
        IFSelect_ReturnStatus status = reader.ReadFile(path);
        if (status != IFSelect_RetDone) return nullptr;
        int nbRoots = reader.NbRootsForTransfer();
        if (rootIndex > nbRoots) return nullptr;
        if (!reader.TransferRoot(rootIndex)) return nullptr;
        TopoDS_Shape shape = reader.OneShape();
        if (shape.IsNull()) return nullptr;
        return new OCCTShape(shape);
    } catch (...) { return nullptr; }
}

OCCTShapeRef OCCTImportSTEPWithUnit(const char* path, double unitInMeters) {
    if (!path) return nullptr;
    try {
        STEPControl_Reader reader;
        reader.SetSystemLengthUnit(unitInMeters);
        IFSelect_ReturnStatus status = reader.ReadFile(path);
        if (status != IFSelect_RetDone) return nullptr;
        reader.TransferRoots();
        TopoDS_Shape shape = reader.OneShape();
        if (shape.IsNull()) return nullptr;
        return new OCCTShape(shape);
    } catch (...) { return nullptr; }
}

int32_t OCCTSTEPReaderNbShapes(const char* path) {
    if (!path) return 0;
    try {
        STEPControl_Reader reader;
        IFSelect_ReturnStatus status = reader.ReadFile(path);
        if (status != IFSelect_RetDone) return 0;
        reader.TransferRoots();
        return reader.NbShapes();
    } catch (...) { return 0; }
}

// MARK: - STEP Full Coverage — STEPCAFControl Modes (v0.58.0)

OCCTDocumentRef OCCTDocumentLoadSTEPWithModes(const char* path,
    bool colorMode, bool nameMode, bool layerMode,
    bool propsMode, bool gdtMode, bool matMode) {
    if (!path) return nullptr;

    OCCTDocument* document = nullptr;
    try {
        document = new OCCTDocument();
        document->app->NewDocument("MDTV-XCAF", document->doc);
        if (document->doc.IsNull()) {
            delete document;
            return nullptr;
        }

        STEPCAFControl_Reader reader;
        reader.SetColorMode(colorMode);
        reader.SetNameMode(nameMode);
        reader.SetLayerMode(layerMode);
        reader.SetPropsMode(propsMode);
        reader.SetGDTMode(gdtMode);
        reader.SetMatMode(matMode);

        IFSelect_ReturnStatus status = reader.ReadFile(path);
        if (status != IFSelect_RetDone) {
            delete document;
            return nullptr;
        }

        if (!reader.Transfer(document->doc)) {
            delete document;
            return nullptr;
        }

        document->shapeTool = XCAFDoc_DocumentTool::ShapeTool(document->doc->Main());
        document->colorTool = XCAFDoc_DocumentTool::ColorTool(document->doc->Main());
        document->materialTool = XCAFDoc_DocumentTool::VisMaterialTool(document->doc->Main());

        return document;
    } catch (...) {
        delete document;
        return nullptr;
    }
}

bool OCCTDocumentWriteSTEPWithModes(OCCTDocumentRef doc, const char* path,
    int32_t modelType, bool colorMode, bool nameMode, bool layerMode,
    bool dimTolMode, bool materialMode) {
    if (!doc || !path || doc->doc.IsNull()) return false;

    try {
        STEPCAFControl_Writer writer;
        writer.SetColorMode(colorMode);
        writer.SetNameMode(nameMode);
        writer.SetLayerMode(layerMode);
        writer.SetDimTolMode(dimTolMode);
        writer.SetMaterialMode(materialMode);

        STEPControl_StepModelType mode = static_cast<STEPControl_StepModelType>(modelType);
        if (!writer.Transfer(doc->doc, mode)) return false;

        IFSelect_ReturnStatus status = writer.Write(path);
        return status == IFSelect_RetDone;
    } catch (...) { return false; }
}

// MARK: - IGES Full Coverage — Reader (v0.59.0)

int32_t OCCTIGESReaderNbRoots(const char* path) {
    if (!path) return 0;
    std::lock_guard<std::mutex> igesLock(igesMutex());
    try {
        IGESControl_Reader reader;
        IFSelect_ReturnStatus status = reader.ReadFile(path);
        if (status != IFSelect_RetDone) return 0;
        return reader.NbRootsForTransfer();
    } catch (...) { return 0; }
}

OCCTShapeRef OCCTImportIGESRoot(const char* path, int32_t rootIndex) {
    if (!path || rootIndex < 1) return nullptr;
    std::lock_guard<std::mutex> igesLock(igesMutex());
    try {
        IGESControl_Reader reader;
        IFSelect_ReturnStatus status = reader.ReadFile(path);
        if (status != IFSelect_RetDone) return nullptr;
        int nbRoots = reader.NbRootsForTransfer();
        if (rootIndex > nbRoots) return nullptr;
        if (!reader.TransferOneRoot(rootIndex)) return nullptr;
        TopoDS_Shape shape = reader.OneShape();
        if (shape.IsNull()) return nullptr;
        return new OCCTShape(shape);
    } catch (...) { return nullptr; }
}

int32_t OCCTIGESReaderNbShapes(const char* path) {
    if (!path) return 0;
    std::lock_guard<std::mutex> igesLock(igesMutex());
    try {
        IGESControl_Reader reader;
        IFSelect_ReturnStatus status = reader.ReadFile(path);
        if (status != IFSelect_RetDone) return 0;
        reader.TransferRoots();
        return reader.NbShapes();
    } catch (...) { return 0; }
}

OCCTShapeRef OCCTImportIGESVisible(const char* path) {
    if (!path) return nullptr;
    std::lock_guard<std::mutex> igesLock(igesMutex());
    try {
        IGESControl_Reader reader;
        reader.SetReadVisible(true);
        IFSelect_ReturnStatus status = reader.ReadFile(path);
        if (status != IFSelect_RetDone) return nullptr;
        reader.TransferRoots();
        TopoDS_Shape shape = reader.OneShape();
        if (shape.IsNull()) return nullptr;
        return new OCCTShape(shape);
    } catch (...) { return nullptr; }
}

// MARK: - IGES Full Coverage — Writer (v0.59.0)

bool OCCTExportIGESWithUnit(OCCTShapeRef shape, const char* path, const char* unit) {
    if (!shape || !path || !unit) return false;
    if (shape->shape.IsNull()) return false;
    std::lock_guard<std::mutex> igesLock(igesMutex());
    try {
        BRepCheck_Analyzer analyzer(shape->shape);
        if (!analyzer.IsValid()) return false;
        IGESControl_Writer writer(unit, 0); // 0 = Faces mode
        if (!writer.AddShape(shape->shape)) return false;
        writer.ComputeModel();
        return writer.Write(path);
    } catch (...) { return false; }
}

bool OCCTExportIGESBRepMode(OCCTShapeRef shape, const char* path) {
    if (!shape || !path) return false;
    if (shape->shape.IsNull()) return false;
    std::lock_guard<std::mutex> igesLock(igesMutex());
    try {
        BRepCheck_Analyzer analyzer(shape->shape);
        if (!analyzer.IsValid()) return false;
        IGESControl_Writer writer("MM", 1); // 1 = BRep mode
        if (!writer.AddShape(shape->shape)) return false;
        writer.ComputeModel();
        return writer.Write(path);
    } catch (...) { return false; }
}

bool OCCTExportIGESMultiShape(const OCCTShapeRef* shapes, int32_t count, const char* path) {
    if (!shapes || count <= 0 || !path) return false;
    std::lock_guard<std::mutex> igesLock(igesMutex());
    try {
        IGESControl_Writer writer;
        int added = 0;
        for (int32_t i = 0; i < count; i++) {
            if (!shapes[i] || shapes[i]->shape.IsNull()) continue;
            // Validate each shape before adding to IGES writer
            BRepCheck_Analyzer analyzer(shapes[i]->shape);
            if (!analyzer.IsValid()) continue;
            writer.AddShape(shapes[i]->shape);
            added++;
        }
        if (added == 0) return false;
        writer.ComputeModel();
        return writer.Write(path);
    } catch (...) { return false; }
}

// MARK: - OBJ Document I/O (v0.59.0)

#include <RWMesh_CoordinateSystemConverter.hxx>
#include <RWMesh_CoordinateSystem.hxx>

OCCTDocumentRef OCCTDocumentLoadOBJ(const char* path) {
    if (!path) return nullptr;
    try {
        OCCTDocument* document = new OCCTDocument();
        document->app->NewDocument("MDTV-XCAF", document->doc);
        if (document->doc.IsNull()) { delete document; return nullptr; }

        RWObj_CafReader objReader;
        objReader.SetDocument(document->doc);
        TCollection_AsciiString filePath(path);
        if (!objReader.Perform(filePath, Message_ProgressRange())) {
            delete document;
            return nullptr;
        }

        document->shapeTool = XCAFDoc_DocumentTool::ShapeTool(document->doc->Main());
        document->colorTool = XCAFDoc_DocumentTool::ColorTool(document->doc->Main());
        document->materialTool = XCAFDoc_DocumentTool::VisMaterialTool(document->doc->Main());
        return document;
    } catch (...) { return nullptr; }
}

OCCTDocumentRef OCCTDocumentLoadOBJWithOptions(const char* path,
    bool singlePrecision, double systemLengthUnit) {
    if (!path) return nullptr;
    try {
        OCCTDocument* document = new OCCTDocument();
        document->app->NewDocument("MDTV-XCAF", document->doc);
        if (document->doc.IsNull()) { delete document; return nullptr; }

        RWObj_CafReader objReader;
        objReader.SetDocument(document->doc);
        objReader.SetSinglePrecision(singlePrecision);
        if (systemLengthUnit > 0) {
            objReader.SetSystemLengthUnit(systemLengthUnit);
        }

        TCollection_AsciiString filePath(path);
        if (!objReader.Perform(filePath, Message_ProgressRange())) {
            delete document;
            return nullptr;
        }

        document->shapeTool = XCAFDoc_DocumentTool::ShapeTool(document->doc->Main());
        document->colorTool = XCAFDoc_DocumentTool::ColorTool(document->doc->Main());
        document->materialTool = XCAFDoc_DocumentTool::VisMaterialTool(document->doc->Main());
        return document;
    } catch (...) { return nullptr; }
}

bool OCCTDocumentWriteOBJ(OCCTDocumentRef doc, const char* path, double deflection) {
    if (!doc || !path || doc->doc.IsNull() || doc->shapeTool.IsNull()) return false;
    try {
        // Re-mesh if deflection > 0
        if (deflection > 0) {
            TDF_LabelSequence freeShapes;
            doc->shapeTool->GetFreeShapes(freeShapes);
            for (int i = 1; i <= freeShapes.Length(); i++) {
                TopoDS_Shape shape = doc->shapeTool->GetShape(freeShapes.Value(i));
                if (!shape.IsNull()) {
                    BRepMesh_IncrementalMesh mesher(shape, deflection);
                    mesher.Perform();
                }
            }
        }

        RWObj_CafWriter writer(path);
        NCollection_IndexedDataMap<TCollection_AsciiString, TCollection_AsciiString> fileInfo;
        return writer.Perform(doc->doc, fileInfo, Message_ProgressRange());
    } catch (...) { return false; }
}

// MARK: - PLY Export Expansion (v0.59.0)

bool OCCTDocumentWritePLY(OCCTDocumentRef doc, const char* path, double deflection,
    bool normals, bool colors, bool texCoords) {
    if (!doc || !path || doc->doc.IsNull() || doc->shapeTool.IsNull()) return false;
    try {
        // Re-mesh if deflection > 0
        if (deflection > 0) {
            TDF_LabelSequence freeShapes;
            doc->shapeTool->GetFreeShapes(freeShapes);
            for (int i = 1; i <= freeShapes.Length(); i++) {
                TopoDS_Shape shape = doc->shapeTool->GetShape(freeShapes.Value(i));
                if (!shape.IsNull()) {
                    BRepMesh_IncrementalMesh mesher(shape, deflection);
                    mesher.Perform();
                }
            }
        }

        RWPly_CafWriter writer(path);
        writer.SetNormals(normals);
        writer.SetColors(colors);
        writer.SetTexCoords(texCoords);
        NCollection_IndexedDataMap<TCollection_AsciiString, TCollection_AsciiString> fileInfo;
        return writer.Perform(doc->doc, fileInfo, Message_ProgressRange());
    } catch (...) { return false; }
}

bool OCCTExportPLYWithOptions(OCCTShapeRef shape, const char* path, double deflection,
    bool normals, bool colors, bool texCoords) {
    if (!shape || !path) return false;
    try {
        BRepMesh_IncrementalMesh mesher(shape->shape, deflection);
        mesher.Perform();

        Handle(TDocStd_Document) doc;
        Handle(XCAFApp_Application) app = XCAFApp_Application::GetApplication();
        app->NewDocument("MDTV-XCAF", doc);

        Handle(XCAFDoc_ShapeTool) shapeTool = XCAFDoc_DocumentTool::ShapeTool(doc->Main());
        shapeTool->AddShape(shape->shape);

        RWPly_CafWriter writer(path);
        writer.SetNormals(normals);
        writer.SetColors(colors);
        writer.SetTexCoords(texCoords);
        NCollection_Sequence<TDF_Label> rootLabels;
        TDF_LabelSequence freeShapes;
        shapeTool->GetFreeShapes(freeShapes);
        for (int i = 1; i <= freeShapes.Length(); ++i) {
            rootLabels.Append(freeShapes.Value(i));
        }
        NCollection_IndexedDataMap<TCollection_AsciiString, TCollection_AsciiString> fileInfo;
        bool success = writer.Perform(doc, rootLabels, nullptr, fileInfo, Message_ProgressRange());
        app->Close(doc);
        return success;
    } catch (...) { return false; }
}

// MARK: - RWMesh Coordinate System (v0.59.0)

OCCTDocumentRef OCCTDocumentLoadOBJWithCS(const char* path,
    int32_t inputCS, int32_t outputCS, double inputLengthUnit, double outputLengthUnit) {
    if (!path) return nullptr;
    try {
        OCCTDocument* document = new OCCTDocument();
        document->app->NewDocument("MDTV-XCAF", document->doc);
        if (document->doc.IsNull()) { delete document; return nullptr; }

        RWObj_CafReader objReader;
        objReader.SetDocument(document->doc);

        if (inputLengthUnit > 0) objReader.SetFileLengthUnit(inputLengthUnit);
        if (outputLengthUnit > 0) objReader.SetSystemLengthUnit(outputLengthUnit);

        if (inputCS >= 0) {
            objReader.SetFileCoordinateSystem(static_cast<RWMesh_CoordinateSystem>(inputCS));
        }
        if (outputCS >= 0) {
            objReader.SetSystemCoordinateSystem(static_cast<RWMesh_CoordinateSystem>(outputCS));
        }

        TCollection_AsciiString filePath(path);
        if (!objReader.Perform(filePath, Message_ProgressRange())) {
            delete document;
            return nullptr;
        }

        document->shapeTool = XCAFDoc_DocumentTool::ShapeTool(document->doc->Main());
        document->colorTool = XCAFDoc_DocumentTool::ColorTool(document->doc->Main());
        document->materialTool = XCAFDoc_DocumentTool::VisMaterialTool(document->doc->Main());
        return document;
    } catch (...) { return nullptr; }
}

