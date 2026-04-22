# Changelog

All notable changes to OCCTSwift.

## Current: v0.138.0

**3,605 wrapped operations | 3,127 tests | 1,117 suites | OCCT 8.0.0-rc5**

---

## Release History

### v0.138.0 (Apr 2026) — Engineering Drawings II: DXF export + thread features

Second release in the v0.137 → v0.139 arc. Closes #63 (DXF export) and #66 (ISO thread features). ~50 ops.

- **DXF 2D writer (#63)**: Custom pure-Swift DXF R12 ASCII writer (OCCT ships no DXF support — confirmed by audit). `Exporter.writeDXF(drawing:to:deflection:)` walks a `Drawing`'s visible / hidden / outline edges through `Shape.allEdgePolylines` and emits LINE / LWPOLYLINE / CIRCLE / ARC / TEXT entities. Layers: VISIBLE / HIDDEN / OUTLINE / CENTER / DIMENSION / TEXT, with appropriate linetypes (CONTINUOUS / DASHED / CHAIN). Dimensions from v0.137's `DrawingDimension` are emitted as exploded LINE+TEXT geometry (universally readable). `Exporter.writeDXF(shape:to:viewDirection:)` convenience combines projection and write. Public `DXFWriter` for callers composing DXF manually.
- **Thread features (#66)**: `ThreadForm` enum (iso68 / unified); `ThreadSpec` struct with `parse("M5x0.8")`, `parse("1/4-20 UNC")`, metric-coarse-pitch table, theoretical and cut depth accessors, minor-diameter computation. `Shape.threadedHole(axisOrigin:axisDirection:spec:depth:)` and `Shape.threadedShaft(axisOrigin:axisDirection:spec:length:)` produce helical cut / boss geometry via `BRepOffsetAPI_MakePipeShell` sweep of a circular profile. Integrates with #62's `FeatureReconstructor` — `FeatureSpec.Thread` can now route through real geometry instead of annotation-only.

Scope decisions: v1 threads use a circular sweep cross-section rather than full 60° flank triangle — produces correct handedness, pitch, diameter, and depth for reprojection diff and visualisation; manufacturing-accurate flanks land in a follow-up release. Multi-start threads, ACME / BSP / NPT forms, and full BRepOffsetAPI_MakePipeShell option wrapping (SetForceApproxC1, multi-profile Add()) deferred. GLTF Shape-level export, PLY import, STEP/IGES option completeness dropped from v0.138 — Document-level GLTF already ships, and the remaining gaps are low priority vs. closed-loop pipeline needs.

### v0.137.0 (Apr 2026) — Engineering Drawings I: axes, dimensions, centrelines

Keystone release for the v0.137 → v0.139 "Engineering Drawings" series (tracked in #67). Adds axis extraction from shapes (#65), a pure-Swift value-type dimensioning API on `Drawing` (#64), and auto-centreline generation bridging the two. ~60 ops.

- **Axis extraction (#65)**: `Face.primaryAxis`, `Shape.revolutionAxes(tolerance:)`, `Shape.symmetryAxes(fractionalTolerance:)`, `Surface.torusAxis`, `Surface.revolutionAxis`. New `ShapeAxis` value type with `.cylinder`/`.cone`/`.sphere`/`.torus`/`.revolution`/`.extrusion`/`.symmetry` kinds. Bridge: `OCCTSurfaceTorusAxis`, `OCCTSurfaceRevolutionAxis`, `OCCTSurfaceRevolutionLocation`, `OCCTFaceGetPrimaryAxis`, `OCCTShapeRevolutionAxes`, `OCCTShapeSymmetryAxes`.
- **Surface introspection completeness**: typed `Surface.SurfaceType` + `Surface.surfaceKind`; `Surface.Continuity` + `Surface.continuityClass`; type-predicate conveniences `isPlane` / `isCylinder` / `isCone` / `isSphere` / `isTorus` / `isBezier` / `isBSpline` / `isSurfaceOfRevolution` / `isSurfaceOfExtrusion` / `isOffsetSurface`.
- **Drawing dimensioning API (#64)**: `DrawingDimension` tagged union (linear / radial / diameter / angular) + `DrawingAnnotation` tagged union (centreline / centremark / text label). `DrawingLineStyle` enum. Methods on `Drawing`: `addLinearDimension`, `addRadialDimension`, `addDiameterDimension`, `addAngularDimension`, `addCentreLine`, `addCentermark`, `addTextLabel`, `clearAnnotations`, plus `dimensions` / `annotations` accessors. Pure-Swift value types — XDE round-trip deferred to v0.139 (#67).
- **Auto-centreline generation (#64 ↔ #65)**: `Drawing.addAutoCentrelines(from:viewDirection:overshoot:tolerance:bounds:)` projects a shape's revolution axes into the drawing's view plane and emits chain-pattern centrelines; axes parallel to the view direction are returned in `.skipped`.

Scope decisions (see #67 for rationale): Full PrsDim display-dimension completeness (MaxRadius / MinRadius / Chamf2d / Chamf3d) and PrsDim geometric-relation wrapping (Concentric / Parallel / etc.) were cut from v0.137 — they are AIS display objects with low marginal value compared to the Swift value-type API that drives the closed-loop drawing workflow.

### v0.132.0 - v0.136.0 (Apr 2026) — BRepGraph Topology Graph

Wraps OCCT's new BRepGraph API — graph-based B-Rep topology with cache-friendly traversal, O(1) upward navigation, and parallel geometry extraction. 163 operations across 5 releases.

- **v0.136.0**: ML-friendly graph export (COO adjacency, node features, JSON), UV-grid face sampling (positions/normals/curvatures), edge curve sampling — for GNN/UV-Net/BRepNet pipelines
- **v0.135.0**: Builder mutations — AddVertex/Shell/Solid, AddFaceToShell/ShellToSolid, AddCompound, RemoveNode/Subgraph, AppendShape, deferred invalidation, SplitEdge, ReplaceEdgeInWire
- **v0.134.0**: Product/Occurrence assembly queries, RefsView per-kind counts and entry access, edge start/end vertices, shell closure, compound hierarchy
- **v0.133.0**: Shape reconstruction from graph nodes, BRepGraph_Tool vertex/edge/face geometry access, CoEdge half-edge queries, history tracking, graph copy/transform, poly counts
- **v0.132.0**: Core graph — build from shape, topology/geometry counts, face adjacency, shared edges, edge boundary/manifold, child/parent explorers, validate, compact, deduplicate, stats

### v0.129.0 - v0.131.0 (Apr 2026) — RC5 New APIs

- **v0.131.0**: Approx_BSplineApproxInterp, GeomEval TBezier/AHTBezier curves+surfaces, GeomAdaptor_TransformedCurve
- **v0.130.0**: GeomEval analytical curves (helix, sine wave), analytical surfaces (ellipsoid, hyperboloid, paraboloid, helicoid), Geom2dEval spirals, GeomFill_Gordon, PointSetLib, ExtremaPC
- **v0.129.0**: IGES mutex serialization (thread safety fix per OCCT #1179)

### v0.120.0 - v0.128.0 (Apr 2026) — Completion & Polish

Final method-level coverage of all user-facing OCCT classes.

- **v0.128.0**: v0.128.0 release (3333 ops total)
- **v0.125.0**: BSplineSurface deep (20), Geom2d_BSpline (20), BezierCurve (8), BezierSurface (12)
- **v0.124.0**: ChamferBuilder (20), FilletBuilder (16), WireAnalyzer (18)
- **v0.123.0**: ThruSections/CellsBuilder/PipeShell/UnifySameDomain/Section extensions
- **v0.122.0**: WireFixer, ShapeFix_Edge, BRepTools/BRepLib statics, History, Sewing extensions
- **v0.121.0**: GLTF import/export (xcframework rebuilt with RapidJSON), FilletBuilder, ChamferBuilder
- **v0.120.0**: IsCN, ReversedParameter, ParametricTransformation, gp extras, surface reversed copies

### v0.110.0 - v0.119.0 (Mar-Apr 2026) — Constraint Solvers & Serialization

- **v0.119.0**: BREP serialization, gp_Pln/gp_Lin distance/contains, BezierSurface queries
- **v0.118.0**: BRepBndLib, ShapeAnalysis tolerance, BRepAlgoAPI_Check/Defeaturing
- **v0.116.0**: Helix construction, gp_Ax3/GTrsf2d/Mat2d, quaternion interpolation
- **v0.115.0**: Interpolation expansion, ThruSections builder, Triangulation queries
- **v0.114.0**: TopoDS_Builder, ShapeContents, FreeBoundsProperties, WireBuilder
- **v0.113.0**: MakeEdge completions, multi-result projections, DistShapeShape full results
- **v0.112.0**: RWMesh iterators, Intf_Tool, BRepAlgo_AsDes, BiTgte, wire/shell construction
- **v0.111.0**: PSO, GlobOptMin, FunctionRoots, GaussIntegration, BRepLProp
- **v0.110.0**: Constraint solver infrastructure — C callback adapters for OCCT math solvers

### v0.100.0 - v0.109.0 (Mar 2026) — Geometry Factories & Extrema

- **v0.109.0**: Extrema elementary distances, TrigRoots, IntAna2d, BRepAlgo_NormalProjection
- **v0.108.0**: Complete Geom_ and Geom2d_ method coverage — all conic/surface property methods
- **v0.107.0**: BSpline manipulation (3D/2D/surface), Bezier methods, BRepTools, Sewing, Hatch
- **v0.106.0**: GC surface factories, ShapeAnalysis_Wire/Edge, BRepLib_MakeEdge2d
- **v0.105.0**: GC/GCE2d geometry factories, GCPnts uniform sampling, CompCurveToBSpline (90 ops)
- **v0.104.0**: BndLib analytic bounding, OSD_Host/PerfMeter, IntAna_IntQuadQuad
- **v0.103.0**: gce transform factories, GProp element properties, Plate constraints
- **v0.102.0**: TopExp adjacency, Poly_Connect mesh adjacency, BRepOffset_Analyse
- **v0.101.0**: Geom_TrimmedCurve, BRepLib_FindSurface, ShapeAnalysis_Surface, Resource_Manager
- **v0.100.0**: RWStl I/O, ShapeAnalysis_Curve statics, BRepExtrema_SelfIntersection

### v0.90.0 - v0.99.0 (Mar 2026) — OCAF Extensions & Math

- **v0.99.0**: Convert_CompBezierCurves, Geom_OffsetSurface, OSD_File, ShapeFix_Wireframe
- **v0.98.0**: IntAna analytic intersections, OSD_Chronometer/Process, Draft_Modification
- **v0.97.0**: BRepAlgo_Loop, Bnd_BoundSortBox, BRepGProp_Domain, TNaming_Naming, Precision
- **v0.96.0**: XCAFDoc_AssemblyItemRef, BRepAlgo_Image, OSD_Path, BRepClass_FClassifier
- **v0.95.0**: Convert ellipse/hyperbola/parabola/cylinder/cone/torus to BSpline
- **v0.94.0**: math_Matrix/Gauss/SVD/PolynomialRoots/Jacobi, Convert circle/sphere to BSpline
- **v0.93.0**: OSD_MemInfo, ShapeFix_EdgeProjAux, Geom2dAPI_Interpolate, BRepAlgo_FaceRestrictor
- **v0.92.0**: Bnd_OBB, Bnd_Range, BRepClass3d point-in-solid, TDataXtd_Constraint
- **v0.91.0**: ElCLib curve evaluation, ElSLib surface evaluation, gp_Quaternion, OSD_Timer
- **v0.90.0**: TDF_ChildIDIterator, TDocStd_PathParser, TFunction_DriverTable, TNaming extensions

### v0.80.0 - v0.89.0 (Mar 2026) — Extrema, Color Science & OCAF Deep

- **v0.89.0**: TDF_Transaction/Delta, TDF_ComparisonTool, TDocStd_XLinkTool
- **v0.88.0**: TNaming extensions, TDataStd_IntPackedMap, TDataStd_NoteBook
- **v0.87.0**: TDataStd_Tick/Current, ShapeAnalysis_Shell, CanonicalRecognition
- **v0.86.0**: TDataStd extended attributes (BooleanArray, ByteArray, IntegerList, etc.)
- **v0.85.0**: UnitsAPI, BinTools binary I/O, Message_Messenger/Report
- **v0.84.0**: VrmlAPI_Writer, TDataStd_Directory/Variable, TDocStd_XLink
- **v0.83.0**: XCAFDoc attributes, Notes, ClippingPlaneTool, AssemblyGraph (97 ops)
- **v0.82.0**: Quantity_Period/Date, Font_FontMgr, Image_AlienPixMap (39 ops)
- **v0.81.0**: Quantity_Color, Quantity_ColorRGBA, Graphic3d materials (24 ops)
- **v0.80.0**: Extrema 3D/2D, GeomTools persistence, ProjLib, gce factories (35 ops)

### v0.70.0 - v0.79.0 (Mar 2026) — TKBool, TKFillet, TKHlr & Geometry Deep

- **v0.79.0**: Poly_CoherentTriangulation, BRepFill_Evolved, BRepExtrema_DistanceSS, GeomFill
- **v0.78.0**: BRepTools modifications, ShapeUpgrade_SplitSurface, GeomConvert, Poly_Polygon
- **v0.77.0**: GeomLib utilities, GccAna circle/line solvers, Approx_SameParameter
- **v0.76.0**: Geom_CartesianPoint, Geom_Direction, Axis1/2Placement, ShapeConstruct_Curve (41 ops)
- **v0.75.0**: BiTgte_Blend, GeomConvert_ApproxCurve/Surface, GCPnts, BRepGProp
- **v0.74.0**: TKMesh/TKOffset/TKPrim/TKShHealing/TKTopAlgo gap closure
- **v0.73.0**: Extended HLR edges, HLRAppli_ReflectLines, Intrv_Interval (29 ops)
- **v0.72.0**: LocOpe_Gluer, ChFi2d_Builder/ChamferAPI/FilletAPI, FilletSurf_Builder
- **v0.71.0**: IntTools_BeanFaceIntersector, BOPAlgo_WireSplitter, BRepFeat_SplitShape
- **v0.70.0**: IntTools EdgeEdge/EdgeFace/FaceFace, BOPAlgo BuilderFace/BuilderSolid

### v0.60.0 - v0.69.0 (Mar 2026) — Data Exchange & TKGeomAlgo

- **v0.69.0**: NLPlate G2/G3, Plate_Plate solver, GeomPlate, GeomFill Generator (20 ops)
- **v0.68.0**: TopTrans_CurveTransition, GeomFill trihedrons, GccAna_Circ2d3Tan (18 ops)
- **v0.67.0**: FairCurve, LocalAnalysis, TopTrans SurfaceTransition (8 ops)
- **v0.66.0**: Full TkG2d — Point2D, Transform2D, AxisPlacement2D, Vector2D (44 ops)
- **v0.65.0**: BOPAlgo RemoveFeatures/Section, ShapeBuild, ShapeExtend, ShapeUpgrade (24 ops)
- **v0.64.0**: ProjLib, BRepOffset_Offset, Adaptor3d_IsoCurve (9 ops)
- **v0.63.0**: GeomLProp, BRepOffset_SimpleOffset, GeomInt_IntSS, Contap_Contour (17 ops)
- **v0.62.0**: BRepLib topology, MakeEdge2d, ShapeCustom, LocOpe, CPnts (22 ops)
- **v0.61.0**: Approx, Contap, BOPAlgo, IntCurvesFace, BRepMesh, GeomPlate (19 ops)
- **v0.60.0**: XDE/XCAF Full Coverage (42 ops)

### v0.50.0 - v0.59.0 (Feb-Mar 2026) — OCAF & Data Exchange

- **v0.59.0**: IGES/OBJ/PLY Full Coverage (23 ops)
- **v0.58.0**: STEP Full Coverage (25 ops)
- **v0.57.0**: OCAF Persistence (17 ops)
- **v0.56.0**: TDataXtd + TFunction (29 ops)
- **v0.55.0**: TDataStd Attributes (25 ops)
- **v0.54.0**: TDF Core + TDocStd (31 ops)
- v0.50.0-v0.53.0: Various additions

### v0.38.0 - v0.49.0 (Feb 2026) — Audit & Gap Closure

Systematic OCCT test suite audit rounds (7 rounds total), closing gaps in primitives, sweeps, booleans, modifications, healing, measurement, and topology.

### v0.27.0 - v0.37.0 (Feb 2026) — RC4 Upgrade & Feature Expansion

- OCCT 8.0.0-rc3 → rc4 upgrade
- Feature-based modeling, pattern operations, shape editing
- Topological naming (TNaming), OCAF framework
- TDataStd/TDataXtd attributes, TFunction framework

### v0.16.0 - v0.26.0 (Feb 2026) — Parametric Geometry

- 2D/3D parametric curves (Geom2d, Geom) with Metal draw methods
- Parametric surfaces with curvature analysis
- Law functions for variable-section sweeps
- Medial axis transform
- Camera, selection, presentation mesh
- Color science, materials

### v0.6.0 - v0.15.0 (Jan 2026) — XDE & Annotations

- XDE document support (assembly, colors, materials, GD&T)
- Annotations (dimensions, text labels, point clouds)
- KD-tree spatial queries
- Polynomial solver, hatch patterns

### v0.1.0 - v0.5.0 (Dec 2025 - Jan 2026) — Foundation

- Basic primitives, booleans, transforms
- Wire creation, sweep operations
- Mesh generation, STL/STEP import/export
- Shape validation and healing
- STEP optimization
