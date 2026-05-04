//
//  OCCTBridge_Misc017.mm
//  OCCTSwift
//
//  Extracted from OCCTBridge.mm — issue #99.
//
//  v0.17 miscellany — small adjacent areas that fit one TU:
//
//  - Hatching (Geom2dHatch_Hatcher + HatchGen_Domain — 2D hatch line
//    intersection)
//  - Bisector (Bisector_BisecCC / Bisector_BisecPC — 2D bisector curves)
//  - STL Import (StlAPI_Reader)
//  - OBJ Import / Export (RWObj_CafReader / RWObj_CafWriter)
//  - PLY Export (RWPly_CafWriter)
//  - Advanced healing (ShapeUpgrade_ShapeDivideContinuity, ShapeFix_Shape
//    repair flows)
//  - Point classification (BRepClass_FaceClassifier, BRepClass — In/Out/On
//    point-in-shape state queries)
//
//  Public C surface unchanged. No symbol changes — pure file move.
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

// === Area-specific OCCT headers ===

#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <BRepBuilderAPI_MakeSolid.hxx>
#include <BRepBuilderAPI_Sewing.hxx>
#include <BRepClass_FaceClassifier.hxx>
#include <BRepClass3d_SolidClassifier.hxx>
#include <BRepMesh_IncrementalMesh.hxx>

#include <Geom2d_Curve.hxx>
#include <Geom2d_Line.hxx>
#include <Geom2dAdaptor_Curve.hxx>
#include <Geom2dHatch_Hatcher.hxx>
#include <Geom2dHatch_Intersector.hxx>
#include <HatchGen_Domain.hxx>
#include <BndLib_Add2dCurve.hxx>
#include <Bnd_Box2d.hxx>
#include <TDF_LabelSequence.hxx>
#include <Bisector_BisecCC.hxx>
#include <Bisector_BisecPC.hxx>

#include <StlAPI_Reader.hxx>
#include <RWObj_CafReader.hxx>
#include <RWObj_CafWriter.hxx>
#include <RWPly_CafWriter.hxx>

#include <ShapeFix_Shape.hxx>
#include <ShapeUpgrade.hxx>
#include <ShapeUpgrade_ShapeDivideContinuity.hxx>

#include <gp_Dir2d.hxx>
#include <gp_Lin2d.hxx>
#include <gp_Pnt.hxx>
#include <gp_Pnt2d.hxx>

#include <Bnd_Box.hxx>
#include <GeomAbs_Shape.hxx>
#include <TColgp_Array1OfPnt2d.hxx>

#include <TopAbs.hxx>
#include <TopAbs_State.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopTools_ListOfShape.hxx>

// MARK: - Hatching

#include <Geom2dHatch_Hatcher.hxx>
#include <Geom2dHatch_Intersector.hxx>
#include <HatchGen_Domain.hxx>

int32_t OCCTCurve2DHatch(const OCCTCurve2DRef* boundaries, int32_t boundaryCount,
                         double originX, double originY,
                         double dirX, double dirY,
                         double spacing, double tolerance,
                         double* outXY, int32_t maxPoints) {
    if (!boundaries || boundaryCount <= 0 || !outXY || maxPoints <= 0 || spacing <= 0) return 0;
    try {
        Geom2dHatch_Intersector intersector(tolerance, tolerance);
        Geom2dHatch_Hatcher hatcher(intersector, tolerance, tolerance);

        // Add boundary elements
        for (int32_t i = 0; i < boundaryCount; i++) {
            if (!boundaries[i] || boundaries[i]->curve.IsNull()) continue;
            Geom2dAdaptor_Curve adaptor(boundaries[i]->curve);
            hatcher.AddElement(adaptor, TopAbs_FORWARD);
        }

        // Compute bounding box for hatch range
        Bnd_Box2d box;
        for (int32_t i = 0; i < boundaryCount; i++) {
            if (!boundaries[i] || boundaries[i]->curve.IsNull()) continue;
            BndLib_Add2dCurve::Add(boundaries[i]->curve, 0.0, box);
        }
        if (box.IsVoid()) return 0;

        double xMin, yMin, xMax, yMax;
        box.Get(xMin, yMin, xMax, yMax);
        double diag = sqrt((xMax - xMin) * (xMax - xMin) + (yMax - yMin) * (yMax - yMin));
        if (diag < tolerance) return 0;

        gp_Dir2d dir(dirX, dirY);
        gp_Dir2d perp(-dirY, dirX);
        gp_Pnt2d origin(originX, originY);

        // Compute perpendicular extent
        double minPerp = 1e100, maxPerp = -1e100;
        double corners[4][2] = {{xMin, yMin}, {xMax, yMin}, {xMax, yMax}, {xMin, yMax}};
        for (int i = 0; i < 4; i++) {
            double dx = corners[i][0] - originX;
            double dy = corners[i][1] - originY;
            double proj = dx * perp.X() + dy * perp.Y();
            if (proj < minPerp) minPerp = proj;
            if (proj > maxPerp) maxPerp = proj;
        }

        // Add hatch lines
        int nLines = (int)((maxPerp - minPerp) / spacing) + 2;
        std::vector<int> hatchIndices;
        for (int i = 0; i < nLines; i++) {
            double offset = minPerp + i * spacing;
            gp_Pnt2d p(originX + perp.X() * offset, originY + perp.Y() * offset);
            gp_Lin2d line(p, dir);
            Geom2dAdaptor_Curve lineAdaptor(new Geom2d_Line(line));
            int idx = hatcher.AddHatching(lineAdaptor);
            hatchIndices.push_back(idx);
        }

        hatcher.Trim();
        hatcher.ComputeDomains();

        // Extract hatch segments
        int32_t pointIdx = 0;
        for (int idx : hatchIndices) {
            if (!hatcher.IsDone(idx)) continue;
            int nDomains = hatcher.NbDomains(idx);
            for (int d = 1; d <= nDomains; d++) {
                HatchGen_Domain domain = hatcher.Domain(idx, d);
                if (!domain.HasFirstPoint() || !domain.HasSecondPoint()) continue;
                double u1 = domain.FirstPoint().Parameter();
                double u2 = domain.SecondPoint().Parameter();
                // Get the hatch line curve
                const Geom2dAdaptor_Curve& hatchCurve = hatcher.HatchingCurve(idx);
                gp_Pnt2d p1 = hatchCurve.Value(u1);
                gp_Pnt2d p2 = hatchCurve.Value(u2);
                if (pointIdx + 4 > maxPoints * 2) break;
                outXY[pointIdx++] = p1.X();
                outXY[pointIdx++] = p1.Y();
                outXY[pointIdx++] = p2.X();
                outXY[pointIdx++] = p2.Y();
            }
        }
        return pointIdx / 4; // Each segment = 2 points = 4 doubles
    } catch (...) {
        return 0;
    }
}

// MARK: - Bisector

#include <Bisector_BisecCC.hxx>
#include <Bisector_BisecPC.hxx>

OCCTCurve2DRef OCCTCurve2DBisectorCC(OCCTCurve2DRef c1, OCCTCurve2DRef c2,
                                     double originX, double originY, bool side) {
    if (!c1 || c1->curve.IsNull() || !c2 || c2->curve.IsNull()) return nullptr;
    try {
        Handle(Bisector_BisecCC) bisector = new Bisector_BisecCC();
        gp_Pnt2d origin(originX, originY);
        double s = side ? 1.0 : -1.0;
        bisector->Perform(c1->curve, c2->curve, s, s, origin);
        if (bisector->IsEmpty()) return nullptr;
        // Return as Geom2d_Curve (Bisector_BisecCC inherits from Geom2d_Curve)
        Handle(Geom2d_Curve) result = bisector;
        return new OCCTCurve2D(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTCurve2DRef OCCTCurve2DBisectorPC(double px, double py, OCCTCurve2DRef curve,
                                     double originX, double originY, bool side) {
    if (!curve || curve->curve.IsNull()) return nullptr;
    try {
        Handle(Bisector_BisecPC) bisector = new Bisector_BisecPC();
        gp_Pnt2d point(px, py);
        bisector->Perform(curve->curve, point, side ? 1.0 : -1.0);
        if (bisector->IsEmpty()) return nullptr;
        Handle(Geom2d_Curve) result = bisector;
        return new OCCTCurve2D(result);
    } catch (...) {
        return nullptr;
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


// MARK: - Advanced Healing (v0.17.0)

#include <ShapeUpgrade_ShapeDivide.hxx>
#include <ShapeUpgrade_ShapeDivideContinuity.hxx>
#include <ShapeCustom.hxx>
#include <ShapeCustom_RestrictionParameters.hxx>

OCCTShapeRef OCCTShapeDivide(OCCTShapeRef shape, int32_t continuity) {
    if (!shape) return nullptr;

    try {
        // Map continuity: 0=C0, 1=C1, 2=C2, 3=C3
        GeomAbs_Shape cont;
        switch (continuity) {
            case 0:  cont = GeomAbs_C0; break;
            case 1:  cont = GeomAbs_C1; break;
            case 2:  cont = GeomAbs_C2; break;
            case 3:  cont = GeomAbs_C3; break;
            default: cont = GeomAbs_C1; break;
        }

        ShapeUpgrade_ShapeDivideContinuity divider(shape->shape);
        divider.SetBoundaryCriterion(cont);
        divider.SetPCurveCriterion(cont);
        divider.SetSurfaceCriterion(cont);
        divider.SetSurfaceSegmentMode(Standard_True);
        if (!divider.Perform()) return nullptr;

        TopoDS_Shape result = divider.Result();
        if (result.IsNull()) return nullptr;

        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeDirectFaces(OCCTShapeRef shape) {
    if (!shape) return nullptr;

    try {
        TopoDS_Shape result = ShapeCustom::DirectFaces(shape->shape);
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeScaleGeometry(OCCTShapeRef shape, double factor) {
    if (!shape) return nullptr;

    try {
        TopoDS_Shape result = ShapeCustom::ScaleShape(shape->shape, factor);
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeBSplineRestriction(OCCTShapeRef shape,
                                          double surfaceTol, double curveTol,
                                          int32_t maxDegree, int32_t maxSegments) {
    if (!shape) return nullptr;

    try {
        // Static method signature:
        // BSplineRestriction(shape, Tol3d, Tol2d, MaxDegree, MaxNbSegment,
        //                    Continuity3d, Continuity2d, Degree, Rational, aParameters)
        Handle(ShapeCustom_RestrictionParameters) params = new ShapeCustom_RestrictionParameters();
        TopoDS_Shape result = ShapeCustom::BSplineRestriction(
            shape->shape,
            surfaceTol,
            curveTol,
            maxDegree,
            maxSegments,
            GeomAbs_C1,       // Continuity3d
            GeomAbs_C1,       // Continuity2d
            Standard_True,     // Degree priority
            Standard_True,     // Rational
            params
        );
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeSweptToElementary(OCCTShapeRef shape) {
    if (!shape) return nullptr;

    try {
        TopoDS_Shape result = ShapeCustom::SweptToElementary(shape->shape);
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeRevolutionToElementary(OCCTShapeRef shape) {
    if (!shape) return nullptr;

    try {
        TopoDS_Shape result = ShapeCustom::ConvertToRevolution(shape->shape);
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeConvertToBSpline(OCCTShapeRef shape) {
    if (!shape) return nullptr;

    try {
        // ConvertToBSpline(shape, extrMode, revolMode, offsetMode, planeMode)
        TopoDS_Shape result = ShapeCustom::ConvertToBSpline(
            shape->shape,
            Standard_True,   // Convert extrusion surfaces
            Standard_True,   // Convert revolution surfaces
            Standard_True,   // Convert offset surfaces
            Standard_False   // Don't convert planes
        );
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeSewSingle(OCCTShapeRef shape, double tolerance) {
    if (!shape) return nullptr;

    try {
        BRepBuilderAPI_Sewing sewing(tolerance);
        sewing.Add(shape->shape);
        sewing.Perform();
        TopoDS_Shape sewn = sewing.SewedShape();
        if (sewn.IsNull()) return nullptr;

        // Try to make a solid if we got a closed shell
        if (sewn.ShapeType() == TopAbs_SHELL) {
            TopoDS_Shell shell = TopoDS::Shell(sewn);
            if (shell.Closed()) {
                BRepBuilderAPI_MakeSolid makeSolid(shell);
                if (makeSolid.IsDone()) {
                    return new OCCTShape(makeSolid.Solid());
                }
            }
        }

        return new OCCTShape(sewn);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeUpgrade(OCCTShapeRef shape, double tolerance) {
    if (!shape) return nullptr;

    try {
        // Step 1: Sew
        BRepBuilderAPI_Sewing sewing(tolerance);
        sewing.Add(shape->shape);
        sewing.Perform();
        TopoDS_Shape sewedShape = sewing.SewedShape();
        if (sewedShape.IsNull()) sewedShape = shape->shape;

        // Step 2: Try to create solid from shell
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

        // Step 3: Apply shape healing
        ShapeFix_Shape fixer(resultShape);
        fixer.Perform();
        TopoDS_Shape fixed = fixer.Shape();
        return new OCCTShape(fixed.IsNull() ? resultShape : fixed);
    } catch (...) {
        return nullptr;
    }
}


// MARK: - Point Classification (v0.17.0)

#include <BRepClass3d_SolidClassifier.hxx>
#include <BRepClass_FaceClassifier.hxx>
#include <TopAbs_State.hxx>

static int32_t mapTopAbsState(TopAbs_State state) {
    switch (state) {
        case TopAbs_IN:      return 0;
        case TopAbs_OUT:     return 1;
        case TopAbs_ON:      return 2;
        case TopAbs_UNKNOWN: return 3;
        default:             return 3;
    }
}

OCCTTopAbsState OCCTClassifyPointInSolid(OCCTShapeRef solid,
                                          double px, double py, double pz,
                                          double tolerance) {
    if (!solid) return 3; // UNKNOWN

    try {
        BRepClass3d_SolidClassifier classifier(solid->shape, gp_Pnt(px, py, pz), tolerance);
        return mapTopAbsState(classifier.State());
    } catch (...) {
        return 3; // UNKNOWN
    }
}

OCCTTopAbsState OCCTClassifyPointOnFace(OCCTFaceRef face,
                                         double px, double py, double pz,
                                         double tolerance) {
    if (!face) return 3; // UNKNOWN

    try {
        BRepClass_FaceClassifier classifier(face->face, gp_Pnt(px, py, pz), tolerance);
        return mapTopAbsState(classifier.State());
    } catch (...) {
        return 3; // UNKNOWN
    }
}

OCCTTopAbsState OCCTClassifyPointOnFaceUV(OCCTFaceRef face,
                                           double u, double v,
                                           double tolerance) {
    if (!face) return 3; // UNKNOWN

    try {
        BRepClass_FaceClassifier classifier(face->face, gp_Pnt2d(u, v), tolerance);
        return mapTopAbsState(classifier.State());
    } catch (...) {
        return 3; // UNKNOWN
    }
}


