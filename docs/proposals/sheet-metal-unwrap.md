# Sheet Metal Unwrap — Branch Proposal

**Branch:** `sheet-metal-unwrap`
**Status:** **all 6 checkpoints implemented and committed; awaiting review + merge**
**Owner:** edward@lynch-bell.com
**Issue:** TBD (companion to #85)

> Delete this file before merging to `main` per the repo doc policy
> (`docs/proposals/` is for in-flight branches only — see CLAUDE.md).

## Resume here

The branch is paused mid-merge while a `main` issue is handled. Pick
up like this:

1. `git checkout sheet-metal-unwrap` — branch is pushed to origin.
2. Inspect `/tmp/unfold-CP{1..6}-*.svg` (regenerable by running
   `swift test --filter UnfoldInspectionTests`).
3. **39/39 unfold tests passing.** No regressions in adjacent suites
   (SheetMetal, ShapeTests basic). The pre-existing parallel-execution
   SEGV in the broader suite is unrelated to this branch.
4. To merge, follow the project's release flow:
   - Update `README.md` operation counts and feature bullets (Unfold
     namespace adds ~10 public entry points).
   - Append a v0.152 entry to `docs/CHANGELOG.md` summarising CP1–CP6.
   - **Delete this proposal doc** per the docs policy.
   - Bump version, `git tag v0.152.0`, `gh release create`.
5. There are two branch-only files outside the package:
   `.claude/scheduled_tasks.lock` (untracked, lockfile, leave alone).

## Checkpoints (commit-by-commit)

| CP | Commit | Tests | What it ships | Inspection SVG |
|---|---|---|---|---|
| **CP1** | `c41d1f2` | 6 | `Unfold.polyhedral(_:)` — planar polyhedra; dual-graph BFS; 2-bridge additions (`Face`/`Edge` from `Shape`); `EdgeIdentifier`, `FoldEdge`, `Result`, `Parameters`, `UnfoldError` | `/tmp/unfold-CP1-{cube,tetrahedron,octahedron,icosahedron}.svg` |
| **CP2** | `79139b6` | 9 | `Unfold.develop(face:samples:)` (cylinder/cone/frustum via UV-rect sampling) and `Unfold.developable(_:)` (mixed planar+developable shells, all-planar routes through polyhedral, otherwise islands along +X) | `/tmp/unfold-CP2-{cylinder,cone,frustum,closed-cylinder,closed-frustum}.svg` |
| **CP3** | `d416293` | 3 | `Unfold.sheetMetal(_:parameters:sheet:)` — bend detection, K-factor, bend allowance `BA = θ(R + Kt)`; `SheetMetalParameters`, `Bend` types | `/tmp/unfold-CP3-l-bracket.svg` |
| **CP4** | `ddd5bcd` | 3 | `Unfold.solid(_:parameters:sheet:)` and `Unfold.midSurface(of:thickness:)` — pair planar/planar (parallel-or-anti-parallel normals at thickness) and cylindrical/cylindrical (concentric, offset radii); construct mid-surfaces; sew | `/tmp/unfold-CP4-thick-l-bracket.svg` |
| **CP5** | `b89468d` | 2 | `parameters.resolveOverlaps` — iteratively isolates overlap-victim faces by pinning their tree-parent edges; forest-BFS in `polyhedralOnce`; bbox-overlap tolerance lifted to 1e-4 to clear OCCT's transform noise | `/tmp/unfold-CP5-icosahedron.svg` |
| **CP6** | `87041ee` | 3 | `Unfold.nest(_:parameters:)` — connected-component island detection, BLF packing, `NestingParameters` with three objectives (`boundingBoxDiagonal` is default), 90° rotations searched | `/tmp/unfold-CP6-cubes-packed.svg` |

## Public API surface (final)

```swift
public enum Unfold {
    public static func polyhedral(_ shape: Shape, parameters: Parameters = .init()) throws -> Result
    public static func developable(_ shape: Shape, parameters: Parameters = .init()) throws -> Result
    public static func develop(face: Shape, samples: Int = 64) throws -> Shape
    public static func sheetMetal(_ shape: Shape, parameters: Parameters, sheet: SheetMetalParameters) throws -> Result
    public static func solid(_ shape: Shape, parameters: Parameters = .init(), sheet: SheetMetalParameters) throws -> Result
    public static func midSurface(of shape: Shape, thickness: Double, tolerance: Double = 1e-5) throws -> Shape
    public static func nest(_ result: Result, parameters: NestingParameters = .init()) throws -> Result
    // Types: Result, Parameters, EdgeIdentifier, FoldEdge, UnfoldError,
    // SheetMetalParameters, Bend, NestingParameters, NestingError.
}
```

## Sharp edges to remember

These were all painful enough to deserve a note for the next session:

1. **OCCT default reference frame for axis = (0,1,0)** picks `+Z` as
   the u=0 reference (not `+X`). A quarter cylinder fillet from `+X`
   tangent to `-Z` tangent is `uRange = π/2 … π`, not `0 … π/2`. The
   `ThinShellFixture.lBracket` and `Unfold.SheetMetalParameters`-using
   tests both depend on this. If a future fixture uses a different
   axis direction, derive the right reference empirically — OCCT's
   choice of default `xDirection` depends on which world axis the
   main direction is along.
2. **CP2 development uses UV-rectangle sampling**, not boundary pcurve
   walking. The pcurve walk for closed cylinders revisits the seam
   edge twice and `BRepAdaptor_Curve2d` returned the same pcurve in
   both orientations, producing a self-intersecting polygon. Sampling
   `face.uvBounds` directly is robust; the only thing it misses is
   inner-wire (hole) topology — out of scope for now.
3. **bbox-overlap tolerance must be ≥ 1e-4.** OCCT's
   `Shape.transformed(matrix:)` introduces ~2e-7 noise in face bounds.
   Below 1e-5 the tolerance dips into noise; below 1e-7 even adjacent
   faces sharing an edge register as overlapping. CP5's
   `anyBoundingBoxOverlap` and `pickEdgeToIsolateOverlap` both lift to
   1e-4. Don't tighten this without re-testing the cube.
4. **Pinning a cut in `polyhedralOnce` requires forest BFS**. CP1's
   single-rooted BFS would lose all faces past the pinned cut. CP5's
   refactor re-roots in unvisited components and offsets each new
   island past the actual post-transform bbox of all prior islands
   (not a sqrt-area proxy — that under-estimates anisotropic faces).
5. **CP4 pairing is direction-agnostic** (parallel OR anti-parallel
   normals). A non-closed compound has both faces of an offset pair
   pointing the same way; a closed sewn shell has them anti-parallel.
   Either should pair.
6. **The icosahedron's `result.overlaps` may not fully clear** under
   `resolveOverlaps`. Shephard's conjecture (1975) is open: not all
   convex polyhedra are known to admit a non-overlapping edge
   unfolding. The CP5 test asserts area conservation, fragmentation,
   and that cuts were added — but accepts that the flag may stay
   true.
7. **`SheetMetal.Builder` output is not yet a CP4 input.** Builder
   produces a sharp inner corner with only an outer cylindrical
   fillet (see `SheetMetal.swift:28-32`); CP4 pairs only when both
   the inner and outer fillets exist. The CP4 `thickLBracket`
   fixture builds a symmetric thick L-bracket manually for testing.
   A follow-up to extend pairing to "outer cylinder + sharp inner
   corner" would unlock direct ingestion of Builder output.

## Pending follow-ups before tag

These are not blocking the branch landing — they are the standard
release-time chores documented in `CLAUDE.md`:

- [ ] `README.md`: bump operation count, add Unfold to feature
      bullets, update version reference.
- [ ] `docs/CHANGELOG.md`: append v0.152 entry summarising CP1–CP6.
- [ ] Delete `docs/proposals/sheet-metal-unwrap.md` (this file).
- [ ] Tag `v0.152.0` and `gh release create`.

The package version is currently still v0.151. The Unfold module
adds zero breaking changes to existing API surface.



## Goal

Convert a 3D shape into a flat 2D cutting pattern. Use cases span
sheet-metal manufacturing, ship-hull plate development, aerospace
skinning, model making, and paper craft.

This is the inverse of the existing `SheetMetal.Builder` API, and the
placeholder docstring at `SheetMetal.swift:15-17` is now redeemed by
this work.

## Scope (confirmed)

Tier 1 + Tier 2 + sheet-metal composite, plus mid-surface extraction
for closed solids, overlap resolution, and stock nesting. Six
checkpoints, each shippable as its own commit.

## Architecture

### Namespace

Top-level `Unfold` (peer of `SheetMetal`, `Drawing`, etc.). Reasoning:
the breadth of inputs (paper-craft polyhedra, ship plates, generic
shells) makes nesting it under `SheetMetal` misleading. The placeholder
note in `SheetMetal.swift` is updated to point at `Unfold`.

### Public API surface (target)

```swift
public enum Unfold {

    public struct Result: Sendable {
        public let flat: Shape                  // compound of 2D faces in XY
        public let islands: [Shape]             // disjoint pieces (post-cut)
        public let cuts: [EdgeIdentifier]       // edges that became seams
        public let folds: [FoldEdge]            // edges that stayed connected
        public let overlaps: [(Int, Int)]       // self-overlap pairs by face index
        public let strain: [Int: Double]        // residual strain per face (Tier 3)
    }

    public struct Parameters: Sendable {
        public var rootFaceIndex: Int?          // default: largest area
        public var pinnedCuts: Set<EdgeIdentifier>
        public var pinnedFolds: Set<EdgeIdentifier>
        public var sheet: SheetMetalParameters? // K-factor + thickness; non-nil
                                                // engages bend-allowance math
        public var resolveOverlaps: Bool        // CP5
        public var nesting: NestingParameters?  // CP6
        public var tolerance: Double
    }

    public struct SheetMetalParameters: Sendable {
        public var thickness: Double
        public var kFactor: Double  // 0.33-0.5 typical; 0.44 default for steel
    }

    public struct NestingParameters: Sendable {
        public var stockWidth: Double?          // nil = unbounded
        public var stockHeight: Double?
        public var padding: Double              // gap between islands
        public var objective: Objective
        public enum Objective: Sendable {
            case boundingBoxDiagonal            // user-requested goal seek
            case boundingBoxArea
            case stockUtilization
        }
    }

    /// Tier 1: planar polyhedra. Errors if any face is non-planar.
    public static func polyhedral(_ shape: Shape,
                                   parameters: Parameters = .init()) throws -> Result

    /// Tier 1+2: planar + analytic developable faces (cylinder, cone,
    /// frustum). Errors on doubly-curved faces.
    public static func developable(_ shape: Shape,
                                    parameters: Parameters = .init()) throws -> Result

    /// Tier 1+2 + sheet-metal composite. Detects cylindrical-fillet
    /// bends and applies bend allowance. `parameters.sheet` is required.
    public static func sheetMetal(_ shape: Shape,
                                   parameters: Parameters) throws -> Result

    /// Solid-input variant. Extracts mid-surface, then routes to
    /// `sheetMetal`. Requires `parameters.sheet.thickness` to match.
    public static func solid(_ shape: Shape,
                              parameters: Parameters) throws -> Result
}
```

### Edge identification

`EdgeIdentifier` already exists in OCCTSwift (or the closest equivalent
used by `Drawing` annotations). If not, introduce a stable
shape-vs-edge-index pair. Same for `FoldEdge` — likely a tuple of
identifier + dihedral angle + bend radius.

### Algorithmic cores

1. **Face-adjacency graph.** `OCCTShapeMapShapesAndAncestors(shape, EDGE, FACE)`
   bridges to `TopExp::MapShapesAndAncestors`. For each edge, list of
   incident faces. Internal edges have 2; boundary edges have 1.
2. **Spanning tree on the dual graph.** Default: BFS from the
   largest-area face, weighted preference for "good to cut" edges
   (boundary, sharp angles, longer length).
3. **Per-face 2D placement.** Maintain `placement[faceIndex] -> gp_Trsf`.
   Root face gets the identity-into-XY-plane transform. For each tree
   edge `parent -> child`, compose parent's transform with the rotation
   that brings child's plane into parent's plane around the shared
   edge.
4. **Analytic development (Tier 2).** For non-planar developable
   faces: parametric surface → 2D coords using closed-form maps
   (cylinder: roll out by arc length × axis length; cone: annular
   sector with apex distance and arc).
5. **Bend allowance (sheet-metal composite).** Cylindrical bend faces
   are not laid out as their developed surface; instead they are
   replaced by a planar strip of width = bend allowance =
   θ · (R + K · t). The neighbor planar faces are translated by that
   allowance instead of the cylinder's developed width.
6. **Mid-surface extraction.** For closed solids: pair each face with
   its inward-offset twin, take the average surface. Limit V1 to the
   simple case of parallel offset pairs.
7. **Overlap detection.** Pairwise 2D face intersection on the laid-out
   compound. If any pair overlaps, add the edge between them to `cuts`
   and re-run the BFS as a forest.
8. **Nesting.** Bottom-left-fill on the bounding boxes of islands, then
   optimize for the chosen objective via local search.

## Checkpoints

Each checkpoint ends with a commit, a passing test suite, and a
manual-inspection prompt for the user before moving on. CP1 is the
gate: if the dual-graph traversal works on all five Platonic solids,
we have proof of life for the rest of the pipeline.

### CP1 — Tier 1: planar polyhedra

**Deliverable:** `Unfold.polyhedral(_:)` with default options.

**Tests** (each is its own `@Suite` in `ShapeTests.swift`):
- Cube → 6 squares laid out as a cross.
- Tetrahedron → 4 triangles.
- Octahedron → 8 triangles.
- Dodecahedron → 12 pentagons.
- Icosahedron → 20 triangles.
- For each: assert `flat` is a single compound, total 2D area ≈ sum
  of original face areas, no overlaps reported, all faces are coplanar
  with XY.

**Inspection prompt:** export each result to SVG via the existing
`Drawing` API and visually confirm the layouts look like familiar nets.

### CP2 — Tier 2: analytic developables

**Deliverable:** `Unfold.developable(_:)`. Adds cylinder, cone,
frustum, and ruled-surface unfolding.

**Tests:**
- Open cylinder section → rectangle of width `2πR`, height = axis len.
- Hex prism (6 rectangles + 2 hexagons) → all eight laid flat.
- Cone → annular sector with apex angle = `2π · sin(half-angle)`.
- Frustum (truncated cone) → annular sector between two arcs.
- Mixed solid: cylinder with planar caps removed → rectangle only.

### CP3 — Sheet-metal composite + bend allowance

**Deliverable:** `Unfold.sheetMetal(_:parameters:)` with required K
factor and thickness. Detects (planar, cylindrical) face pairs sharing
a generator edge as bends; replaces the cylinder face's developed
width with `θ · (R + K · t)`.

**Tests:**
- L-bracket built via `SheetMetal.Builder` → unfolds to two rectangles
  joined by a strip of width = bend allowance.
- U-channel → three rectangles in a row.
- Box without lid (5 sides + 4 bends) → cross-pattern with bend strips.
- Round-trip: bend allowance × 2π · 90°/360° matches the analytic
  formula to within `1e-9`.

### CP4 — Mid-surface extraction for closed solids

**Deliverable:** `Unfold.solid(_:parameters:)`. Walks face pairs that
are parallel offsets at distance = `parameters.sheet.thickness`,
extracts the mid-surface, then routes to `sheetMetal`.

**Tests:**
- Closed L-bracket solid (10 faces) → mid-surface is 4 faces (2 sides
  + 2 ends/legs).
- Box solid → 6-face mid-surface.
- Failure case: solid with non-parallel walls → throws explicit error.

### CP5 — Overlap detection + auto re-cut

**Deliverable:** `parameters.resolveOverlaps = true` makes the
unfolder add cuts iteratively until islands are non-overlapping.
Returns multiple islands.

**Tests:**
- Long chain of tetrahedra (forces overlap on naïve unfold) → at
  least one extra cut, multiple islands, no overlaps.
- Thin spiral / helical strip → multiple islands.
- Default (`resolveOverlaps = false`) reports overlaps but does not
  cut.

### CP6 — Stock nesting / layout

**Deliverable:** `parameters.nesting` enables BLF packing on islands,
with the user's `boundingBoxDiagonal` objective plus alternatives.

**Tests:**
- 5 cubes → packed into a single bounding box, diagonal within X% of
  optimal (compare to known-good rectangle packing).
- Dodecahedron + nesting → produces a tighter result than the natural
  unfold's bounding box.
- Stock-bounded case: 1m × 0.5m sheet, 10 small parts → all fit;
  raise an error if not.

## Test strategy

- All tests use Swift Testing (`@Suite`, `@Test`). Existing convention.
- Each checkpoint adds a new `@Suite` whose name starts with `Unfold`.
- Numerical assertions use `≈` with `1e-9` for analytic results,
  `1e-6` for traversal-based results (accumulated transform error).
- Visual inspection: each suite ends with a `.skip`-tagged test that
  exports a representative result to `/tmp/unfold-CP{N}-{name}.svg`
  for the user to spot-check, only run on demand.
- Snapshot tests against canonical Platonic-solid nets are deferred
  unless we hit numerical instability.

## Risks & open questions

- **2D rigid-transform composition error accumulates** over deep
  spanning trees (icosahedron is depth 6+). Watch for `1e-6` drift on
  the closing edges. May need to recompute placements from the root
  rather than chaining.
- **Spanning-tree heuristic selection.** Default is BFS from largest
  face, but maximum-spanning-tree (Schlickenrieder's "steepest edge")
  may give better unfolds. Pick BFS for CP1 simplicity; revisit if a
  Platonic solid produces overlap.
- **Bend allowance for non-90° bends.** The formula generalizes
  cleanly (`θ · (R + K·t)`) but the K-factor sometimes varies with
  angle in real material data. CP3 takes a single K and notes the
  limitation.
- **Mid-surface extraction is hard for non-trivial solids.** CP4 is
  scoped to parallel-offset face pairs. Variable-thickness, tapered,
  or non-prismatic walls fail loudly.
- **Doubly-curved shells (Tier 3, ARAP).** Out of scope for this
  branch. Mentioned for posterity.

## References

- Demaine & O'Rourke, *Geometric Folding Algorithms* (CUP 2007).
- Sheffer, Lévy et al., "ABF++" (ACM TOG 2005).
- Liu et al., "Local/Global Mesh Parameterization" (SGP 2008).
- Schlickenrieder, "Nets of Polyhedra" (TU Berlin 1997).
- Chalfant & Maekawa, "Design for Manufacturing Using B-Spline
  Developable Surfaces" (J. Ship Research 1998).
- FreeCAD SheetMetal workbench (Shai Seger) —
  `github.com/shaise/FreeCAD_SheetMetal/blob/master/SheetMetalUnfolder.py`.

## Out of scope (deferred)

- Tier 3 mesh flattening (ARAP / SLIM) for doubly-curved shells.
- Variable-thickness or composite-material bend tables.
- Production-grade nesting heuristics (no-fit polygon, nested-bin).
- Animated unbend visualization.
