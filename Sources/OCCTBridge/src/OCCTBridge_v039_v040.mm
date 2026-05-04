//
//  OCCTBridge_v039_v040.mm
//  OCCTSwift
//
//  Extracted from OCCTBridge.mm — issue #99.
//
//  v0.39 + v0.40 cluster — two block-style sections.
//  Per-area #include directives stay inline at section boundaries.
//
//  v0.39 areas: Poly HLR (HLRBRep_PolyAlgo), Free Bounds (ShapeAnalysis_
//  FreeBounds), Pipe Feature, Semi-Infinite Extrusion.
//
//  v0.40 areas: Mass Properties (BRepGProp:VolumeProperties /
//  SurfaceProperties / LinearProperties), Geometry Conversion (BSpline/
//  Bezier helpers), Distance Analysis (BRepExtrema_DistShapeShape).
//
//  Public C surface unchanged. No symbol changes — pure file move.
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

// === Headers shared across multiple subsections ===

#include <gp_Ax1.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>
#include <gp_Vec.hxx>

#include <Geom_Curve.hxx>
#include <Geom_Surface.hxx>

#include <BRep_Tool.hxx>
#include <BRep_Builder.hxx>
#include <BRepPrimAPI_MakePrism.hxx>
#include <BRepFeat_MakePrism.hxx>
#include <gp_Ax2.hxx>
#include <HLRAlgo_Projector.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>

#include <TopAbs.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>

// MARK: - v0.39.0: Poly HLR, Free Bounds, Pipe Feature, Semi-Infinite Extrusion

#include <HLRBRep_PolyAlgo.hxx>
#include <HLRBRep_PolyHLRToShape.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <ShapeAnalysis_FreeBounds.hxx>
#include <ShapeFix_FreeBounds.hxx>
#include <BRepFeat_MakePipe.hxx>

OCCTDrawingRef OCCTDrawingCreatePoly(OCCTShapeRef shape,
                                      double dirX, double dirY, double dirZ,
                                      int32_t projectionType, double deflection) {
    if (!shape) return nullptr;
    try {
        // Ensure the shape has a triangulation
        BRepMesh_IncrementalMesh mesh(shape->shape, deflection);

        gp_Dir viewDir(dirX, dirY, dirZ);
        gp_Ax2 projAxis(gp_Pnt(0, 0, 0), viewDir);
        HLRAlgo_Projector projector(projAxis);

        Handle(HLRBRep_PolyAlgo) polyAlgo = new HLRBRep_PolyAlgo();
        polyAlgo->Projector(projector);
        polyAlgo->Load(shape->shape);
        polyAlgo->Update();

        HLRBRep_PolyHLRToShape shapes;
        shapes.Update(polyAlgo);

        OCCTDrawing* drawing = new OCCTDrawing();
        drawing->visibleSharp = shapes.VCompound();
        drawing->visibleSmooth = shapes.Rg1LineVCompound();
        drawing->visibleOutline = shapes.OutLineVCompound();
        drawing->hiddenSharp = shapes.HCompound();
        drawing->hiddenSmooth = shapes.Rg1LineHCompound();
        drawing->hiddenOutline = shapes.OutLineHCompound();

        return drawing;
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeFreeBounds(OCCTShapeRef shape, double sewingTolerance,
                                  int32_t* outClosedCount, int32_t* outOpenCount) {
    if (!shape || !outClosedCount || !outOpenCount) return nullptr;
    try {
        ShapeAnalysis_FreeBounds analyzer(shape->shape, sewingTolerance);

        TopoDS_Compound closedWires = analyzer.GetClosedWires();
        TopoDS_Compound openWires = analyzer.GetOpenWires();

        // Count wires in each compound
        int32_t closedCount = 0, openCount = 0;
        TopExp_Explorer expClosed(closedWires, TopAbs_WIRE);
        while (expClosed.More()) { closedCount++; expClosed.Next(); }
        TopExp_Explorer expOpen(openWires, TopAbs_WIRE);
        while (expOpen.More()) { openCount++; expOpen.Next(); }

        *outClosedCount = closedCount;
        *outOpenCount = openCount;

        // Return compound of all free boundary wires
        BRep_Builder builder;
        TopoDS_Compound result;
        builder.MakeCompound(result);
        if (!closedWires.IsNull()) builder.Add(result, closedWires);
        if (!openWires.IsNull()) builder.Add(result, openWires);

        if (closedCount == 0 && openCount == 0) return nullptr;

        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeFixFreeBounds(OCCTShapeRef shape, double sewingTolerance,
                                     double closingTolerance, int32_t* outFixedCount) {
    if (!shape || !outFixedCount) return nullptr;
    try {
        ShapeFix_FreeBounds fixer(shape->shape, sewingTolerance, closingTolerance,
                                   Standard_True, Standard_True);

        TopoDS_Compound closedWires = fixer.GetClosedWires();
        TopoDS_Compound openWires = fixer.GetOpenWires();

        int32_t closedCount = 0;
        TopExp_Explorer exp(closedWires, TopAbs_WIRE);
        while (exp.More()) { closedCount++; exp.Next(); }

        *outFixedCount = closedCount;

        BRep_Builder builder;
        TopoDS_Compound result;
        builder.MakeCompound(result);
        if (!closedWires.IsNull()) builder.Add(result, closedWires);
        if (!openWires.IsNull()) builder.Add(result, openWires);

        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapePipeFeature(OCCTShapeRef shape, int32_t profileFaceIndex,
                                   int32_t sketchFaceIndex, OCCTWireRef spine,
                                   int32_t fuse) {
    if (!shape || !spine) return nullptr;
    try {
        TopTools_IndexedMapOfShape faceMap;
        TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);

        int32_t profIdx = profileFaceIndex + 1;
        int32_t sketchIdx = sketchFaceIndex + 1;
        if (profIdx < 1 || profIdx > faceMap.Extent()) return nullptr;
        if (sketchIdx < 1 || sketchIdx > faceMap.Extent()) return nullptr;

        TopoDS_Face profileFace = TopoDS::Face(faceMap(profIdx));
        TopoDS_Face sketchFace = TopoDS::Face(faceMap(sketchIdx));

        BRepFeat_MakePipe maker(shape->shape, profileFace, sketchFace,
                                 spine->wire, fuse, true);
        maker.Perform();
        if (!maker.IsDone()) return nullptr;

        TopoDS_Shape result = maker.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapePipeFeatureFromProfile(OCCTShapeRef baseShape, OCCTShapeRef profileShape,
                                              int32_t sketchFaceIndex, OCCTWireRef spine,
                                              int32_t fuse) {
    if (!baseShape || !profileShape || !spine) return nullptr;
    try {
        TopTools_IndexedMapOfShape faceMap;
        TopExp::MapShapes(baseShape->shape, TopAbs_FACE, faceMap);

        int32_t sketchIdx = sketchFaceIndex + 1;
        if (sketchIdx < 1 || sketchIdx > faceMap.Extent()) return nullptr;

        TopoDS_Face sketchFace = TopoDS::Face(faceMap(sketchIdx));

        BRepFeat_MakePipe maker(baseShape->shape, profileShape->shape, sketchFace,
                                 spine->wire, fuse, true);
        maker.Perform();
        if (!maker.IsDone()) return nullptr;

        TopoDS_Shape result = maker.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeExtrudeSemiInfinite(OCCTShapeRef profile,
                                           double dirX, double dirY, double dirZ,
                                           bool semiInfinite) {
    if (!profile) return nullptr;
    try {
        gp_Dir dir(dirX, dirY, dirZ);
        BRepPrimAPI_MakePrism maker(profile->shape, dir,
                                     !semiInfinite);
        maker.Build();
        if (!maker.IsDone()) return nullptr;
        return new OCCTShape(maker.Shape());
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapePrismUntilFace(OCCTShapeRef baseShape, OCCTShapeRef profileShape,
                                      int32_t sketchFaceIndex,
                                      double dirX, double dirY, double dirZ,
                                      int32_t fuse, int32_t untilFaceIndex) {
    if (!baseShape || !profileShape) return nullptr;
    try {
        TopTools_IndexedMapOfShape faceMap;
        TopExp::MapShapes(baseShape->shape, TopAbs_FACE, faceMap);

        int32_t sketchIdx = sketchFaceIndex + 1;
        if (sketchIdx < 1 || sketchIdx > faceMap.Extent()) return nullptr;

        TopoDS_Face sketchFace = TopoDS::Face(faceMap(sketchIdx));
        gp_Dir dir(dirX, dirY, dirZ);

        BRepFeat_MakePrism maker(baseShape->shape, profileShape->shape,
                                  sketchFace, dir, fuse, true);

        if (untilFaceIndex < 0) {
            // Thru-all
            maker.PerformThruAll();
        } else {
            int32_t untilIdx = untilFaceIndex + 1;
            if (untilIdx < 1 || untilIdx > faceMap.Extent()) return nullptr;
            TopoDS_Face untilFace = TopoDS::Face(faceMap(untilIdx));
            maker.Perform(untilFace);
        }

        if (!maker.IsDone()) return nullptr;
        TopoDS_Shape result = maker.Shape();
        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// MARK: - v0.40.0: Mass Properties, Geometry Conversion, Distance Analysis

#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <GProp_PrincipalProps.hxx>
#include <GeomConvert_BSplineSurfaceToBezierSurface.hxx>
#include <GeomConvert_BSplineCurveKnotSplitting.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_BSplineCurve.hxx>
#include <Geom_BezierSurface.hxx>
#include <BRepLib_FindSurface.hxx>
#include <BRepExtrema_DistShapeShape.hxx>

bool OCCTShapeInertiaProperties(OCCTShapeRef shape, OCCTInertiaProperties* outProps) {
    if (!shape || !outProps) return false;
    try {
        GProp_GProps props;
        BRepGProp::VolumeProperties(shape->shape, props);

        outProps->volume = props.Mass();
        gp_Pnt cm = props.CentreOfMass();
        outProps->centerX = cm.X();
        outProps->centerY = cm.Y();
        outProps->centerZ = cm.Z();

        gp_Mat mat = props.MatrixOfInertia();
        outProps->inertia[0] = mat(1,1); outProps->inertia[1] = mat(1,2); outProps->inertia[2] = mat(1,3);
        outProps->inertia[3] = mat(2,1); outProps->inertia[4] = mat(2,2); outProps->inertia[5] = mat(2,3);
        outProps->inertia[6] = mat(3,1); outProps->inertia[7] = mat(3,2); outProps->inertia[8] = mat(3,3);

        GProp_PrincipalProps pp = props.PrincipalProperties();
        double Ix, Iy, Iz;
        pp.Moments(Ix, Iy, Iz);
        outProps->principalIx = Ix;
        outProps->principalIy = Iy;
        outProps->principalIz = Iz;

        gp_Vec v1 = pp.FirstAxisOfInertia();
        gp_Vec v2 = pp.SecondAxisOfInertia();
        gp_Vec v3 = pp.ThirdAxisOfInertia();
        outProps->principalAxes[0] = v1.X(); outProps->principalAxes[1] = v1.Y(); outProps->principalAxes[2] = v1.Z();
        outProps->principalAxes[3] = v2.X(); outProps->principalAxes[4] = v2.Y(); outProps->principalAxes[5] = v2.Z();
        outProps->principalAxes[6] = v3.X(); outProps->principalAxes[7] = v3.Y(); outProps->principalAxes[8] = v3.Z();

        outProps->hasSymmetryAxis = pp.HasSymmetryAxis();
        outProps->hasSymmetryPoint = pp.HasSymmetryPoint();

        return true;
    } catch (...) {
        return false;
    }
}

bool OCCTShapeSurfaceInertiaProperties(OCCTShapeRef shape, OCCTInertiaProperties* outProps) {
    if (!shape || !outProps) return false;
    try {
        GProp_GProps props;
        BRepGProp::SurfaceProperties(shape->shape, props);

        outProps->volume = props.Mass(); // Surface area in this context
        gp_Pnt cm = props.CentreOfMass();
        outProps->centerX = cm.X();
        outProps->centerY = cm.Y();
        outProps->centerZ = cm.Z();

        gp_Mat mat = props.MatrixOfInertia();
        outProps->inertia[0] = mat(1,1); outProps->inertia[1] = mat(1,2); outProps->inertia[2] = mat(1,3);
        outProps->inertia[3] = mat(2,1); outProps->inertia[4] = mat(2,2); outProps->inertia[5] = mat(2,3);
        outProps->inertia[6] = mat(3,1); outProps->inertia[7] = mat(3,2); outProps->inertia[8] = mat(3,3);

        GProp_PrincipalProps pp = props.PrincipalProperties();
        double Ix, Iy, Iz;
        pp.Moments(Ix, Iy, Iz);
        outProps->principalIx = Ix;
        outProps->principalIy = Iy;
        outProps->principalIz = Iz;

        gp_Vec v1 = pp.FirstAxisOfInertia();
        gp_Vec v2 = pp.SecondAxisOfInertia();
        gp_Vec v3 = pp.ThirdAxisOfInertia();
        outProps->principalAxes[0] = v1.X(); outProps->principalAxes[1] = v1.Y(); outProps->principalAxes[2] = v1.Z();
        outProps->principalAxes[3] = v2.X(); outProps->principalAxes[4] = v2.Y(); outProps->principalAxes[5] = v2.Z();
        outProps->principalAxes[6] = v3.X(); outProps->principalAxes[7] = v3.Y(); outProps->principalAxes[8] = v3.Z();

        outProps->hasSymmetryAxis = pp.HasSymmetryAxis();
        outProps->hasSymmetryPoint = pp.HasSymmetryPoint();

        return true;
    } catch (...) {
        return false;
    }
}

