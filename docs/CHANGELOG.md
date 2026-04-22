# Changelog

All notable changes to OCCTSwift.

## Current: v0.148.0

**4,024 wrapped operations | 3,274 tests | 1,153 suites | OCCT 8.0.0-rc5**

---

## Release History

### v0.148.0 (Apr 2026) — Drawing.append(_:) unified dispatcher

Small release closing #83 and #84 — both asked for the same thing: a public `Drawing.append(_:)` that dispatches every `DrawingAnnotation` case without the consumer-side switch blind spot.

- **`Drawing.append(_ annotation: DrawingAnnotation)`** — appends any `DrawingAnnotation` case (centreline, centermark, textLabel, hatch, cuttingPlaneLine). When new cases land, the dispatcher updates in one place, not in every consumer.
- **`Drawing.append(contentsOf: [DrawingAnnotation])`** — for factory output like `DrawingAnnotation.surfaceFinish(...)`, `.featureControlFrame(...)`, `.datumFeature(...)`, `.breakLine(...)`, `.cosmeticThreadSideView(...)` which all return arrays.
- **`Drawing.append(_ dimension: DrawingDimension)`** / `append(contentsOf: [DrawingDimension])` — symmetric for dimensions.

Downstream `replay(...)` helpers (OCCTSwiftScripts, OCCTSwiftPartsAgent) collapse to one-line `drawing.append(contentsOf: DrawingAnnotation.surfaceFinish(...))`. The existing `addCentreLine` / `addCentermark` / `addTextLabel` / `addHatch` / `addCuttingPlaneLine` typed factories continue to work unchanged; they're now a thin convenience over `append(_:)` conceptually (though the storage path is identical either way).

### v0.147.0 (Apr 2026) — Drawing + FeatureSpec consumer polish

Closes four small follow-up issues (#79, #80, #81, #82) that downstream consumers (OCCTSwiftScripts, OCCTDesignLoop, MCP tooling) asked for to remove boilerplate and unblock JSON-driven workflows.

- **#80 `Edge.curve3D`**: Direct `Edge → Curve3D` bridge. Ensures the 3D curve is built via `BRepLib::BuildCurves3d` for pcurve-only edges. Returns the raw `Geom_Curve` so consumers can call `curve.circleProperties` / `lineProperties` / etc. without DownCast gymnastics.
- **#79 `Drawing.addAutoCentermarks(from:viewDirection:extent:minRadius:bounds:)`**: symmetric to `addAutoCentrelines`. Walks circular edges, projects each centre into the view plane, adds `.centermark` annotations. Skips edges whose circle plane is parallel to the view (edge-on). `minRadius` filters small holes; `bounds` filters centermarks outside the view.
- **#81 `DrawingAnnotation.CuttingPlaneLine` + `Drawing.addCuttingPlaneLine`**: typed ISO 128-40 cutting-plane line. Computes trace in view 2D from cutting plane normal × view direction. DXFWriter renders heavy-chain ends, thin-chain middle, perpendicular arrows, and label letters at both ends.
- **#82 `FeatureSpec` Codable conformance**: `FeatureSpec` + all nested types (`Revolve`, `Extrude`, `Hole`, `Thread`, `EdgeSelector`, `Fillet`, `Chamfer`, `Boolean`) now `Codable`. Unblocks `FeatureReconstructor.buildJSON` + Python / MCP driven reconstruction pipelines without each consumer mirroring the types in their own schema.

### v0.146.0 (Apr 2026) — ISO drawings III: cosmetic threads, surface finish, GD&T symbols, detail views

Closes the ISO drawings arc (#78). Final release ships cosmetic threads (#77), ISO 1302 surface finish, ISO 1101 GD&T symbols, and compressed-view conventions (detail + break lines).

- **#77 `DrawingAnnotation.cosmeticThreadSideView` / `cosmeticThreadEndView`**: ISO 6410 cosmetic thread representation. Side view: two parallel lines at minor diameter spanning the thread length, optional callout text. End view: 3/4 broken arc set (0–90° / 90–180° / 180–315° with a 45° gap). `Drawing.addCosmeticThreadSide(...)` and `DXFWriter.addCosmeticThreadEndView(...)` convenience wrappers.
- **ISO 1302 surface finish**: `SurfaceFinishSymbol` enum (`.any` / `.machiningRequired` / `.machiningProhibited`). `DrawingAnnotation.surfaceFinish(at:leaderTo:ra:symbol:method:)` produces the check-mark geometry with Ra value label, horizontal bar for machiningRequired, optional production-method text, and leader line to the target feature.
- **ISO 1101 GD&T symbols**: `GDTSymbol` enum covering all 15 ASME/ISO geometric characteristics (straightness, flatness, circularity, cylindricity, profile of line/surface, perpendicularity, parallelism, angularity, position, concentricity, symmetry, coaxiality, circular runout, total runout). `DrawingAnnotation.featureControlFrame(at:symbol:tolerance:datums:leaderTo:)` emits the classic `[⌖] [0.1] [A] [B] [C]` rectangular frame. `DrawingAnnotation.datumFeature(label:at:pointingTo:)` emits the boxed letter + triangle pointer.
- **Detail views**: `Drawing.detailView(at:scale:)` returns a `TransformedDrawing` suitable for placing a scaled-up region of the parent drawing at a specific sheet location.
- **Break lines**: `DrawingAnnotation.breakLine(from:to:amplitude:)` emits ISO 128-30 compressed-length zigzag marker as 5 line segments.

### v0.145.0 (Apr 2026) — ISO drawings II: sheet templates, title blocks, projection symbols

Second release in the ISO drawings arc (#78). Closes #76 — adds ISO 5457 trimmed-sheet templates, ISO 7200 title blocks, and ISO 5456-2 projection symbols as first-class OCCTSwift API.

- **`PaperSize`**: `A0` / `A1` / `A2` / `A3` / `A4` with `.size(in: .landscape)` / `.portrait` returning ISO 5457 trimmed dimensions in mm.
- **`Orientation`**: `.landscape` / `.portrait`.
- **`ProjectionAngle`**: `.first` (ISO / Europe) / `.third` (ANSI / USA).
- **`TitleBlock`**: ISO 7200 mandatory + optional fields (title, drawingNumber, owner, creator, approver, documentType, dateOfIssue, revision, sheetNumber, language, material, weight, scale).
- **`Sheet`**: ties PaperSize + Orientation + ProjectionAngle + TitleBlock together. `render(into: DXFWriter)` emits border + ISO 5457 inner frame with correct margins (20 mm binding left, 10 mm other edges on A0–A3), centring marks at edge midpoints, and the title block in the bottom-right. `innerFrame` property exposes the drawable rectangle for layout.
- **`ProjectionSymbol`**: `ProjectionSymbol.render(.first, at:, into:)` emits the ISO 5456-2 truncated-cone + circle pair at the correct relative position for first / third angle.
- DXFWriter gets two new layers: `BORDER` and `TITLE`.

### v0.144.0 (Apr 2026) — ISO drawings I: section views, hatch, multi-view, style foundations

First of a three-release ISO-drawings arc (tracked in #78). Closes #73, #74, #75 and adds the ISO 128-20 / 3098 / 5455 style primitives every downstream sheet producer needs.

- **#75 `Drawing.transformed(translate:scale:)` + `Drawing.bounds`**: new `TransformedDrawing` wrapper and `DXFWriter.collectFromDrawing(_ transformed:)` overload. `Drawing.bounds(deflection:includeAnnotations:)` returns the drawing's 2D axis-aligned bounding box. Unblocks multi-view sheet composition: `writer.collectFromDrawing(view.transformed(translate: offset, scale: 0.5))`.
- **#73 `Shape.section2D(planeOrigin:planeNormal:planeU:deflection:)`** + `Shape.section2DView(...)`: slice a shape with a plane, return a `Drawing` in the plane's own 2D frame (not world space). `section2DView` wraps the contour with automatic ISO 128-40 hatching at 45° and an optional "A-A" label.
- **#74 `Drawing.addHatch(boundary:angle:spacing:islands:)`**: ISO 128-50 sectional-view fill. DXFWriter tessellates into line segments at the specified angle and spacing with island (hole) subtraction via even-odd rule scanlines. Adds `HATCH` + `SECTION` XCAF layers.
- **G1 ISO 128-20 line widths + ISO 128-21 arrows + ISO 3098 text heights**: `DrawingLineWidth` enum (w013 → w200, ISO 1:1.4 series), `DrawingTextHeight` enum (h25 → h200) with `.recommended(forPaper:)` and `.snap(_:)`, `DrawingArrowStyle` (filledClosed / openClosed90 / openClosed30 / tick), `DrawingLineStyle.defaultWidth` / `.boldWidth` per style.
- **G2 ISO 5455 `DrawingScale`**: enum cases `.one` / `.reduction(Int)` / `.enlargement(Int)` / `.custom(Double)` with `.factor` and `.label` accessors. `DrawingScale.preferred` returns the ISO-standard scale series (50:1 down to 1:1000).

### v0.143.0 (Apr 2026) — Measurement ergonomics + clearing v0.142 deferrals

Small-but-broad release that sands the measurement papercuts surfaced by the v0.143 audit and retires every deferral the v0.142 release notes flagged. Roughly 40 ops: 4 measurement additions, 5 deferral clearings.

**Measurement ergonomics (M1–M4):**

- **`Shape.volume` / `Shape.surfaceArea`** — verified already wrapped as optional properties (audit had missed them); no new code, just confirmation.
- **`Curve3D.distance(to: SIMD3)` / `Edge.distance(to: SIMD3)`** — one-liner point-to-curve distance when you don't need the projected point / parameter.
- **Angle helpers**: `Edge.angle(to:)`, `Edge.isParallel(to:tolerance:)`, `Edge.isPerpendicular(to:tolerance:)`, `Face.angle(to:)`, `Face.isParallel(to:)`, `Face.isPerpendicular(to:)`, `Face.isCoplanar(with:tolerance:)`. Plus `ConstructionAxis.angle(to:in:)`, `ConstructionPlane.angle(to:in:)`. `unsignedAngle(between:and:)` free function for SIMD3 pairs.
- **Circle / revolution property extraction**: `Edge.circleProperties` returns `(center, radius, axis, isFullCircle, startAngle, endAngle)?` for circular edges (three-point circle fit). `Face.revolutionProperties` returns `(axis, radius)?` for cylindrical / conical / spherical / toroidal / surface-of-revolution faces.

**Deferral clearings (from v0.142 release notes):**

- **Constructionspeak persistence (D1)**: `Document.addConstructionShape(_:)` tags a shape with the `CONSTRUCTION` XCAF layer; `Document.constructionShapeLabels` enumerates on reload. `ConstructionContext.materialize(in:graph:options:)` resolves every plane/axis/point recipe and creates a finite representative shape (rectangular face for planes, bounded edge for axes, vertex for points) on the layer. STEP export preserves layer tags; import produces layer-marked shapes but not the typed recipes. Matches FreeCAD's long-standing ceiling.
- **Arc / circle tessellation in `Sketch.buildProfile` (D2)**: `SketchElement.CurveKind.tessellate2D(segmentsPerRadian:)` for all four curve kinds (line / polyline / arc / circle). `Sketch.buildProfile` now lifts tessellated samples through the host plane's frame. D-shaped and circular profiles now produce wires.
- **Named-shape registry for `FeatureSpec.Boolean` (D3)**: Each feature with a non-nil `id` registers its produced shape in an internal dict; `Boolean.leftID` / `rightID` look up by id. `.union` / `.subtract` / `.intersect` all supported. Missing-id cases report `.unresolvedRef`.
- **Multi-leaf `.createdBy` disambiguation (D4)**: new `leafOccurrence: Int? = 0` parameter on `TopologyRef.createdBy` — pick the Nth leaf when a creation has split into multiple live descendants. `TopologyGraph.currentForms(of:)` returns all leaves. `leafOccurrence: nil` disables forward-walk.
- **FeatureReconstructor ↔ TopologyGraph coupling for `EdgeSelector` (D5)**: `.nearPoint(point, tolerance)` resolves edges by midpoint-distance within the target shape. `.onFeature(featureID)` looks up the source feature's shape via the named-shape registry and heuristically matches target edges whose midpoints coincide with the source's edges. `.all` for uniform fillet/chamfer still works. (v1 heuristic; full graph-history dispatch remains available if consumers need per-op edge identity.)

Scope cuts: chamfer per-edge selector still requires a per-edge distance array the bridge doesn't yet expose — falls through to `.unsupported` for `.nearPoint` / `.onFeature` on chamfer specifically. Uniform chamfer (`.all`) works. Flagged as a v0.144 candidate.

### v0.142.0 (Apr 2026) — Construction geometry, sketches, FeatureReconstructor

Second release in the v0.141 → v0.143 arc — ships Phases 2–6 from #72 plus #62 in one go. With this release, OCCTSwift has the full construction-geometry vocabulary that agentic modelling needs: recipe-based references (v0.141) → typed construction entities → document context → sketches → declarative feature reconstruction.

- **`ConstructionPlane` / `ConstructionAxis` / `ConstructionPoint`** (#72 Phase 2): Fusion-style recipe enums carrying `TopologyRef`s. 7 plane variants (absolute, offsetFromFace, throughAxis, tangentToFace, midPlane, byThreePoints, normalToEdge), 5 axis variants (absolute, alongEdge, normalToFace, throughPoints, intersectionOfPlanes), 6 point variants (absolute, atVertex, midpointOfEdge, centroidOfFace, atEdgeParameter, intersectionOfAxisAndPlane). Resolvers compute `Placement` / `(origin, direction)` / `SIMD3<Double>` against a `TopologyGraph`. Typed `ConstructionResolutionError`.
- **`TopologyRef.containedIn` now resolves** (#72 Phase 2 unblock): new `OCCTBRepGraphChildIndices` bridge + `TopologyGraph.childIndices(rootKind:rootIndex:targetKind:)` Swift wrapper.
- **`ConstructionContext`** (#72 Phase 3): Document-level collection with typed opaque IDs (`PlaneID` / `AxisID` / `PointID`), named entities, per-entity resolution against a graph, and `allBroken(in:)` diagnostic returning every entity that fails to resolve. `Document.constructionContext` is a lazy per-document property.
- **`Sketch` + `SketchElement`** (#72 Phase 4): `Sketch` is hosted on a `ConstructionPlane` ID, carries an array of `SketchElement`s with per-element `isConstruction` flag. `buildProfile(in:graph:)` is the **single filter site** (FreeCAD-inspired) — construction elements are excluded when assembling the profile wire. Elements: `.line`, `.polyline`, `.arc`, `.circle` (arcs/circles tessellation comes later).
- **`FeatureReconstructor`** (#62): Declarative `FeatureSpec` tagged union (revolve / extrude / hole / thread / fillet / chamfer / boolean). `FeatureReconstructor.build(from:)` with staged additive → subtractive → finishing → annotation dispatch. `EdgeSelector` enum with `.all`, `.nearPoint`, `.onFeature` — `.onFeature` currently reports `.unsupported` pending full TopologyGraph-integrated dispatcher; `.all` works today for uniform fillet/chamfer. `FeatureReconstructor.buildJSON(_:)` front end parses the OCCTDesignLoop-compatible schema.
- **`Placement`** shared value type (origin + orthonormal basis) with ergonomic `init(origin:normal:)` that picks deterministic x/y axes.

Scope of what the v1 implementation deliberately does **not** do (deferred to later iterations as concrete consumers surface):
- Constraint solving in `Sketch` — explicit non-goal (see #72).
- Named-shape registry for `FeatureSpec.Boolean` with id-based left/right selection.
- `.onFeature` / `.nearPoint` edge resolution in fillet/chamfer dispatch — requires coupling `FeatureReconstructor` to a live `TopologyGraph`, which is the natural next iteration once agents drive it.
- XCAF `CONSTRUCTION` layer persistence — recipes live in-memory; STEP round-trip drops them (matches FreeCAD's 20-year limitation documented in #72).
- Multi-leaf `.createdBy` disambiguation when a single creation splits into many live descendants.

### v0.141.0 (Apr 2026) — Construction-geometry foundation: BRepGraph history readback + TopologyRef

First release in the v0.141 → v0.143 "Construction Geometry" arc (tracked in #72). Builds the substrate for recipe-based topology references that survive mutations — the prerequisite for agent-driven CAD where construction planes / axes / points stay attached to model features through edits.

- **BRepGraph history record readback (#72 Phase 0)**: Exposes the old→new node mappings that the OCCT kernel was already recording. `TopologyGraph.historyRecord(at:)`, `.historyRecords`, `.findOriginal(of:)`, `.findDerived(of:)`, `.recordHistory(operationName:original:replacements:)`. New `TopologyGraph.NodeRef` value type (kind + index) and `HistoryRecord` with full mapping.
- **`TopologyRef` recipe type (#72 Phase 1)**: Indirect enum expressing topology references as *recipes evaluated against the current graph*, not as indices (Onshape FeatureScript-inspired). Cases: `.literal(NodeRef)`, `.createdBy(operationName:kind:occurrence:)`, `.containedIn(parent:kind:occurrence:)`, `.splitOf(original:occurrence:)`. Typed `TopologyResolutionError` enum for failure modes.
- **`TopologyGraph.resolve(_:)`**: Evaluates recipes by walking history records, returns `Result<NodeRef, TopologyResolutionError>`. `.createdBy` picks up newly-introduced replacements by operation name and walks forward to the current form; `.splitOf` picks the Nth replacement of a split original; ancestor-resolution failures surface as `.ancestorMissing`.

Scope: `.containedIn` returns `.noCurrentDescendant` until Phase 2 adds child-at-index accessors. `.createdBy` current-form walk picks the first leaf in deterministic order; multi-leaf disambiguation (useful when a single creation splits into many live descendants) comes in later phases.

### v0.140.0 (Apr 2026) — GD&T write path + typed dimension/tolerance enums

Completes the read-only GD&T support shipped in v0.21.0 with a write path. Downstream callers can now author `XCAFDoc_Dimension` / `XCAFDoc_GeomTolerance` / `XCAFDoc_Datum` attributes, attach them to shape labels, and round-trip through STEP AP242. Typed Swift enums replace the raw `Int32` type codes from v0.21.0 for the full list of XCAFDimTolObjects types.

- **Typed enums**: `Document.DimensionType` (all 32 `XCAFDimTolObjects_DimensionType` cases — Location_Linear, Size_Diameter, Size_Radius, toroidal variants, etc.) and `Document.GeomToleranceType` (all 16 — flatness, perpendicularity, position, profileOfLine, etc.).
- **Typed value types**: `Document.Dimension`, `Document.GeomTolerance`, `Document.Datum`. Accessors: `typedDimension(at:)`, `typedGeomTolerance(at:)`, `typedDatum(at:)`, `typedDimensions`, `typedGeomTolerances`, `typedDatums`.
- **Write path**: `Document.createDimension(on:type:value:lowerTolerance:upperTolerance:)`, `createGeomTolerance(on:type:value:)`, `createDatum(name:)`, `setDimensionTolerance(at:lower:upper:)`. Returns the new attribute's index or nil on failure.
- **Bridge additions**: `OCCTDocumentCreateDimension`, `OCCTDocumentCreateGeomTolerance`, `OCCTDocumentCreateDatum`, `OCCTDocumentSetDimensionTolerance`.

Scope: full modifier / qualifier / grade sequences (`XCAFDimTolObjects_DimensionModif`, `GeomToleranceModif`, `DatumSingleModif` etc.) remain partial wrapping — added on demand. This release covers the 90%-case authoring path.

### v0.139.0 (Apr 2026) — Thread Form v2 + cleanup

Replaces v0.138's circular-sweep thread placeholder with a real truncated V-profile following ISO-68 / UN conventions. Also folds in two quality-of-life cleanups (#68 boolean arg labels, #69 versioned MARK headers).

**Behaviour change**: callers of v0.138's `Shape.threadedHole` / `threadedShaft` will now receive geometry that actually looks like a thread in HLR reprojection (alternating diagonal edges at pitch spacing) rather than a helical groove. API signatures unchanged; new default parameters (`starts: 1`, `runout: .none`) preserve single-start no-runout behaviour.

- **Thread Form v2 (#66 follow-up)**: `ThreadCutterProfile` builds a truncated trapezoidal cross-section with 30° flanks (60° included), H/8 crest flat, H/4 root flat. Swept along a helical spine with `BRepOffsetAPI_MakePipeShell` (correctedFrenet mode) and boolean-cut against the target. New `crestFlat` / `rootFlat` / `minorDiameter` accessors on `ThreadSpec`. New `RunoutStyle` enum (`.none` / `.filleted(radius:)` / `.tapered(turns:)`). New `starts: Int` parameter on `threadedHole` / `threadedShaft` for multi-start threads.
- **Boolean op labels (#68)**: `Shape.union(_:)`, `Shape.intersection(_:)`, `Shape.section(_:)` now match `Shape.subtracting(_:)` — all unlabelled, consistent with `Set.union(_:)` / `Set.intersection(_:)`. Deprecated `with:`-labelled shims kept for backwards compatibility.
- **MARK header refactor (#69)**: 32 versioned grab-bag MARK headers (`// MARK: - v0.X.Y: A, B, C`) renamed to feature-first format (`// MARK: - A, B, C (v0.X.Y)`). Xcode jump-to-section and grep-for-feature now work; OCCTMCP's MARK-based API-reference generator can categorise without a regex fallback.

Tapered-runout law-based pipe-shell is tracked as a follow-up — the `.tapered` case falls back to `.filleted` until `BRepOffsetAPI_MakePipeShell::SetLaw` is wrapped.

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
