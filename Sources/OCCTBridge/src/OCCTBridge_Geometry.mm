//
//  OCCTBridge_Geometry.mm
//  OCCTSwift
//
//  Extracted from OCCTBridge.mm — issue #99.
//
//  Geometry construction (v0.11) + Feature-based modeling (v0.12):
//
//  - Geometry construction: face from wire, sewing, BSpline interpolation,
//    extrude / revolve, evolved sweep, transform / mirror / scale, splitter
//  - Feature-based modeling: prism + revolve features, draft fillets and
//    related composite-face operations
//
//  Both blocks share the BRepAlgoAPI / BRepBuilderAPI / BRepPrimAPI stack
//  + GeomAPI_Interpolate, so they extract together.
//
//  Public C surface unchanged. No symbol changes — pure file move.
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

// === Area-specific OCCT headers ===

#include <BRep_Builder.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepAlgoAPI_Splitter.hxx>
#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeSolid.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_Sewing.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepOffsetAPI_MakeEvolved.hxx>
#include <BRepPrimAPI_MakePrism.hxx>
#include <BRepPrimAPI_MakeRevol.hxx>

#include <Geom_BSplineCurve.hxx>
#include <GeomAPI_Interpolate.hxx>

#include <gp_Ax1.hxx>
#include <gp_Dir.hxx>
#include <gp_Pln.hxx>
#include <gp_Pnt.hxx>
#include <gp_Trsf.hxx>
#include <gp_Vec.hxx>

#include <ShapeFix_Solid.hxx>
#include <TColgp_HArray1OfPnt.hxx>

#include <TopAbs.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <TopoDS_Shell.hxx>
#include <TopoDS_Solid.hxx>
#include <TopTools_ListOfShape.hxx>
#include <Bnd_Box.hxx>

// MARK: - Geometry Construction (v0.11.0)

OCCTShapeRef OCCTShapeCreateFaceFromWire(OCCTWireRef wire, bool planar) {
    if (!wire) return nullptr;

    try {
        BRepBuilderAPI_MakeFace makeFace(wire->wire, planar);
        if (!makeFace.IsDone()) {
            return nullptr;
        }

        TopoDS_Face face = makeFace.Face();
        if (face.IsNull()) return nullptr;

        return new OCCTShape(face);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateFaceWithHoles(OCCTWireRef outer, const OCCTWireRef* holes, int32_t holeCount) {
    if (!outer) return nullptr;

    try {
        // First create face from outer wire
        BRepBuilderAPI_MakeFace makeFace(outer->wire, true);  // planar
        if (!makeFace.IsDone()) {
            return nullptr;
        }

        // Add holes (inner wires)
        for (int32_t i = 0; i < holeCount; i++) {
            if (holes[i]) {
                // Inner wires must be reversed to represent holes
                TopoDS_Wire reversed = TopoDS::Wire(holes[i]->wire.Reversed());
                makeFace.Add(reversed);
            }
        }

        if (!makeFace.IsDone()) {
            return nullptr;
        }

        TopoDS_Face face = makeFace.Face();
        if (face.IsNull()) return nullptr;

        return new OCCTShape(face);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateSolidFromShell(OCCTShapeRef shell) {
    if (!shell) return nullptr;

    try {
        // Extract shell from shape
        TopoDS_Shell topoShell;
        if (shell->shape.ShapeType() == TopAbs_SHELL) {
            topoShell = TopoDS::Shell(shell->shape);
        } else {
            // Try to find a shell in the shape
            TopExp_Explorer exp(shell->shape, TopAbs_SHELL);
            if (exp.More()) {
                topoShell = TopoDS::Shell(exp.Current());
            } else {
                return nullptr;
            }
        }

        BRepBuilderAPI_MakeSolid makeSolid(topoShell);
        if (!makeSolid.IsDone()) {
            return nullptr;
        }

        TopoDS_Solid solid = makeSolid.Solid();
        if (solid.IsNull()) return nullptr;

        // Optionally fix the solid orientation
        ShapeFix_Solid fixer(solid);
        fixer.Perform();
        TopoDS_Shape fixedShape = fixer.Solid();
        if (fixedShape.IsNull() || fixedShape.ShapeType() != TopAbs_SOLID) {
            return new OCCTShape(solid);  // Return original if fix failed
        }

        return new OCCTShape(TopoDS::Solid(fixedShape));
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeSew(const OCCTShapeRef* shapes, int32_t count, double tolerance) {
    if (!shapes || count < 1) return nullptr;

    try {
        BRepBuilderAPI_Sewing sewing(tolerance);

        for (int32_t i = 0; i < count; i++) {
            if (shapes[i]) {
                sewing.Add(shapes[i]->shape);
            }
        }

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

OCCTShapeRef OCCTShapeSewTwo(OCCTShapeRef shape1, OCCTShapeRef shape2, double tolerance) {
    if (!shape1 || !shape2) return nullptr;

    OCCTShapeRef shapes[2] = { shape1, shape2 };
    return OCCTShapeSew(shapes, 2, tolerance);
}

OCCTWireRef OCCTWireInterpolate(const double* points, int32_t count, bool closed, double tolerance) {
    if (!points || count < 2) return nullptr;

    try {
        // Build array of points
        Handle(TColgp_HArray1OfPnt) hPoints = new TColgp_HArray1OfPnt(1, count);
        for (int32_t i = 0; i < count; i++) {
            hPoints->SetValue(i + 1, gp_Pnt(points[i*3], points[i*3+1], points[i*3+2]));
        }

        // Create interpolator
        GeomAPI_Interpolate interpolator(hPoints, closed, tolerance);
        interpolator.Perform();

        if (!interpolator.IsDone()) {
            return nullptr;
        }

        Handle(Geom_BSplineCurve) curve = interpolator.Curve();
        if (curve.IsNull()) return nullptr;

        // Create edge from curve
        BRepBuilderAPI_MakeEdge makeEdge(curve);
        if (!makeEdge.IsDone()) return nullptr;

        // Create wire from edge
        BRepBuilderAPI_MakeWire makeWire(makeEdge.Edge());
        if (!makeWire.IsDone()) return nullptr;

        return new OCCTWire(makeWire.Wire());
    } catch (...) {
        return nullptr;
    }
}

OCCTWireRef OCCTWireInterpolateWithTangents(const double* points, int32_t count,
                                             double startTanX, double startTanY, double startTanZ,
                                             double endTanX, double endTanY, double endTanZ,
                                             double tolerance) {
    if (!points || count < 2) return nullptr;

    try {
        // Build array of points
        Handle(TColgp_HArray1OfPnt) hPoints = new TColgp_HArray1OfPnt(1, count);
        for (int32_t i = 0; i < count; i++) {
            hPoints->SetValue(i + 1, gp_Pnt(points[i*3], points[i*3+1], points[i*3+2]));
        }

        // Create interpolator (not closed since we have tangent constraints)
        GeomAPI_Interpolate interpolator(hPoints, Standard_False, tolerance);

        // Set tangent constraints
        gp_Vec startTangent(startTanX, startTanY, startTanZ);
        gp_Vec endTangent(endTanX, endTanY, endTanZ);
        interpolator.Load(startTangent, endTangent);

        interpolator.Perform();

        if (!interpolator.IsDone()) {
            return nullptr;
        }

        Handle(Geom_BSplineCurve) curve = interpolator.Curve();
        if (curve.IsNull()) return nullptr;

        // Create edge from curve
        BRepBuilderAPI_MakeEdge makeEdge(curve);
        if (!makeEdge.IsDone()) return nullptr;

        // Create wire from edge
        BRepBuilderAPI_MakeWire makeWire(makeEdge.Edge());
        if (!makeWire.IsDone()) return nullptr;

        return new OCCTWire(makeWire.Wire());
    } catch (...) {
        return nullptr;
    }
}


// MARK: - Feature-Based Modeling (v0.12.0)

OCCTShapeRef OCCTShapePrism(OCCTShapeRef shape, OCCTWireRef profile,
                            double dirX, double dirY, double dirZ,
                            double height, bool fuse) {
    if (!shape || !profile) return nullptr;

    try {
        // Create face from profile wire
        BRepBuilderAPI_MakeFace makeFace(profile->wire, true);
        if (!makeFace.IsDone()) return nullptr;
        TopoDS_Face profileFace = makeFace.Face();

        // Create the prism direction
        gp_Vec dir(dirX, dirY, dirZ);
        dir.Normalize();
        dir.Scale(height);

        // Create the prism shape (extrusion of the profile)
        BRepPrimAPI_MakePrism makePrism(profileFace, dir);
        if (!makePrism.IsDone()) return nullptr;
        TopoDS_Shape prismShape = makePrism.Shape();

        // Fuse or cut with base shape
        TopoDS_Shape result;
        if (fuse) {
            BRepAlgoAPI_Fuse fuseOp(shape->shape, prismShape);
            if (!fuseOp.IsDone()) return nullptr;
            result = fuseOp.Shape();
        } else {
            BRepAlgoAPI_Cut cutOp(shape->shape, prismShape);
            if (!cutOp.IsDone()) return nullptr;
            result = cutOp.Shape();
        }

        if (result.IsNull()) return nullptr;
        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeDrillHole(OCCTShapeRef shape,
                                 double posX, double posY, double posZ,
                                 double dirX, double dirY, double dirZ,
                                 double radius, double depth) {
    if (!shape || radius <= 0) return nullptr;

    try {
        gp_Vec direction(dirX, dirY, dirZ);
        double dirLen = direction.Magnitude();
        if (dirLen < 1e-10) return nullptr;
        direction.Normalize();

        // Determine depth - if depth is 0 or negative, make it through the shape
        double actualDepth = depth;
        if (actualDepth <= 0) {
            // Calculate shape extent for through hole
            Bnd_Box bounds;
            BRepBndLib::Add(shape->shape, bounds);
            double xmin, ymin, zmin, xmax, ymax, zmax;
            bounds.Get(xmin, ymin, zmin, xmax, ymax, zmax);
            double diagonal = std::sqrt((xmax-xmin)*(xmax-xmin) +
                                        (ymax-ymin)*(ymax-ymin) +
                                        (zmax-zmin)*(zmax-zmin));
            actualDepth = diagonal * 2;  // Make sure it goes through
        }

        // Calculate the bottom of the hole (endpoint of drill)
        double bottomX = posX + direction.X() * actualDepth;
        double bottomY = posY + direction.Y() * actualDepth;
        double bottomZ = posZ + direction.Z() * actualDepth;

        // Create cylinder using OCCTShapeCreateCylinderAt pattern
        // The cylinder's base is at the "bottom" of the hole, extending upward
        OCCTShapeRef cylRef = OCCTShapeCreateCylinderAt(bottomX, bottomY, bottomZ, radius, actualDepth);
        if (!cylRef) return nullptr;

        // Subtract using the existing working function
        OCCTShapeRef result = OCCTShapeSubtract(shape, cylRef);
        OCCTShapeRelease(cylRef);

        return result;
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef* OCCTShapeSplit(OCCTShapeRef shape, OCCTShapeRef tool, int32_t* outCount) {
    if (!shape || !tool || !outCount) return nullptr;
    *outCount = 0;

    try {
        // Use BRepAlgoAPI_Splitter for general splitting
        BRepAlgoAPI_Splitter splitter;

        // Set arguments (shapes to be split)
        TopTools_ListOfShape arguments;
        arguments.Append(shape->shape);
        splitter.SetArguments(arguments);

        // Set tools (cutting shapes)
        TopTools_ListOfShape tools;
        tools.Append(tool->shape);
        splitter.SetTools(tools);

        // Perform split
        splitter.Build();
        if (!splitter.IsDone()) return nullptr;

        TopoDS_Shape result = splitter.Shape();
        if (result.IsNull()) return nullptr;

        // Extract solids from result
        std::vector<TopoDS_Shape> solids;
        for (TopExp_Explorer exp(result, TopAbs_SOLID); exp.More(); exp.Next()) {
            solids.push_back(exp.Current());
        }

        // If no solids, try shells
        if (solids.empty()) {
            for (TopExp_Explorer exp(result, TopAbs_SHELL); exp.More(); exp.Next()) {
                solids.push_back(exp.Current());
            }
        }

        // If still nothing, return the whole result as one shape
        if (solids.empty()) {
            solids.push_back(result);
        }

        // Allocate array
        *outCount = static_cast<int32_t>(solids.size());
        OCCTShapeRef* shapes = new OCCTShapeRef[*outCount];
        for (int32_t i = 0; i < *outCount; i++) {
            shapes[i] = new OCCTShape(solids[i]);
        }

        return shapes;
    } catch (...) {
        *outCount = 0;
        return nullptr;
    }
}

OCCTShapeRef* OCCTShapeSplitByPlane(OCCTShapeRef shape,
                                     double planeX, double planeY, double planeZ,
                                     double normalX, double normalY, double normalZ,
                                     int32_t* outCount) {
    if (!shape || !outCount) return nullptr;
    *outCount = 0;

    try {
        // Create plane
        gp_Pnt pnt(planeX, planeY, planeZ);
        gp_Dir normal(normalX, normalY, normalZ);
        gp_Pln plane(pnt, normal);

        // Create a large face from the plane for cutting
        // Get shape bounds to size the cutting plane
        Bnd_Box bounds;
        BRepBndLib::Add(shape->shape, bounds);
        double xmin, ymin, zmin, xmax, ymax, zmax;
        bounds.Get(xmin, ymin, zmin, xmax, ymax, zmax);
        double size = std::sqrt((xmax-xmin)*(xmax-xmin) +
                                (ymax-ymin)*(ymax-ymin) +
                                (zmax-zmin)*(zmax-zmin)) * 2;

        BRepBuilderAPI_MakeFace makeFace(plane, -size, size, -size, size);
        if (!makeFace.IsDone()) return nullptr;
        TopoDS_Shape planeFace = makeFace.Face();

        // Use splitter
        BRepAlgoAPI_Splitter splitter;

        TopTools_ListOfShape arguments;
        arguments.Append(shape->shape);
        splitter.SetArguments(arguments);

        TopTools_ListOfShape tools;
        tools.Append(planeFace);
        splitter.SetTools(tools);

        splitter.Build();
        if (!splitter.IsDone()) return nullptr;

        TopoDS_Shape result = splitter.Shape();
        if (result.IsNull()) return nullptr;

        // Extract solids from result
        std::vector<TopoDS_Shape> solids;
        for (TopExp_Explorer exp(result, TopAbs_SOLID); exp.More(); exp.Next()) {
            solids.push_back(exp.Current());
        }

        if (solids.empty()) {
            for (TopExp_Explorer exp(result, TopAbs_SHELL); exp.More(); exp.Next()) {
                solids.push_back(exp.Current());
            }
        }

        if (solids.empty()) {
            solids.push_back(result);
        }

        *outCount = static_cast<int32_t>(solids.size());
        OCCTShapeRef* shapes = new OCCTShapeRef[*outCount];
        for (int32_t i = 0; i < *outCount; i++) {
            shapes[i] = new OCCTShape(solids[i]);
        }

        return shapes;
    } catch (...) {
        *outCount = 0;
        return nullptr;
    }
}

void OCCTFreeShapeArray(OCCTShapeRef* shapes, int32_t count) {
    if (!shapes) return;
    for (int32_t i = 0; i < count; i++) {
        delete shapes[i];
    }
    delete[] shapes;
}

void OCCTFreeShapeArrayOnly(OCCTShapeRef* shapes) {
    if (!shapes) return;
    delete[] shapes;
}

OCCTShapeRef OCCTShapeGlue(OCCTShapeRef shape1, OCCTShapeRef shape2, double tolerance) {
    if (!shape1 || !shape2) return nullptr;

    try {
        // Use BRepAlgoAPI_Fuse with glue option for coincident faces
        BRepAlgoAPI_Fuse fuse;
        fuse.SetGlue(BOPAlgo_GlueShift);  // Enable gluing mode
        fuse.SetFuzzyValue(tolerance);

        TopTools_ListOfShape args;
        args.Append(shape1->shape);
        args.Append(shape2->shape);
        fuse.SetArguments(args);

        fuse.Build();
        if (!fuse.IsDone()) {
            // Fallback to regular fuse
            BRepAlgoAPI_Fuse regularFuse(shape1->shape, shape2->shape);
            if (!regularFuse.IsDone()) return nullptr;
            return new OCCTShape(regularFuse.Shape());
        }

        TopoDS_Shape result = fuse.Shape();
        if (result.IsNull()) return nullptr;

        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCreateEvolved(OCCTWireRef spine, OCCTWireRef profile) {
    if (!spine || !profile) return nullptr;

    try {
        BRepOffsetAPI_MakeEvolved evolved(spine->wire, profile->wire);
        if (!evolved.IsDone()) return nullptr;

        TopoDS_Shape result = evolved.Shape();
        if (result.IsNull()) return nullptr;

        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeLinearPattern(OCCTShapeRef shape,
                                     double dirX, double dirY, double dirZ,
                                     double spacing, int32_t count) {
    if (!shape || count < 1) return nullptr;

    try {
        BRep_Builder builder;
        TopoDS_Compound compound;
        builder.MakeCompound(compound);

        gp_Vec direction(dirX, dirY, dirZ);
        direction.Normalize();

        for (int32_t i = 0; i < count; i++) {
            gp_Trsf transform;
            transform.SetTranslation(direction * (spacing * i));

            BRepBuilderAPI_Transform xform(shape->shape, transform, true);
            if (xform.IsDone()) {
                builder.Add(compound, xform.Shape());
            }
        }

        return new OCCTShape(compound);
    } catch (...) {
        return nullptr;
    }
}

OCCTShapeRef OCCTShapeCircularPattern(OCCTShapeRef shape,
                                       double axisX, double axisY, double axisZ,
                                       double axisDirX, double axisDirY, double axisDirZ,
                                       int32_t count, double angle) {
    if (!shape || count < 1) return nullptr;

    try {
        BRep_Builder builder;
        TopoDS_Compound compound;
        builder.MakeCompound(compound);

        gp_Pnt axisPoint(axisX, axisY, axisZ);
        gp_Dir axisDir(axisDirX, axisDirY, axisDirZ);
        gp_Ax1 axis(axisPoint, axisDir);

        // If angle is 0, use full circle
        double totalAngle = (angle == 0) ? (2.0 * M_PI) : angle;
        double stepAngle = totalAngle / count;

        for (int32_t i = 0; i < count; i++) {
            gp_Trsf transform;
            transform.SetRotation(axis, stepAngle * i);

            BRepBuilderAPI_Transform xform(shape->shape, transform, true);
            if (xform.IsDone()) {
                builder.Add(compound, xform.Shape());
            }
        }

        return new OCCTShape(compound);
    } catch (...) {
        return nullptr;
    }
}

