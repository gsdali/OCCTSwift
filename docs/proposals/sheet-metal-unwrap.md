# Sheet Metal Unwrap — Branch Proposal

**Branch:** `sheet-metal-unwrap`
**Status:** active design — checkpoint-driven implementation
**Owner:** edward@lynch-bell.com
**Issue:** TBD (companion to #85)

> Delete this file before merging to `main` per the repo doc policy
> (`docs/proposals/` is for in-flight branches only — see CLAUDE.md).

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
