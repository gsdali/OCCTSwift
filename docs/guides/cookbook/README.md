# OCCTSwift Cookbook

Task-oriented, **example-rich** guides for the OCCTSwift Swift API — one page per area, each a
short bit of prose followed by runnable Swift snippets. This is the Swift-side counterpart to
OCCT's own `dox/user_guides/` (which document the C++ API and are indexed on context7 as
`/open-cascade-sas/occt`). Goal: make the **Swift** surface answerable by context7 too — see
[issue #210](https://github.com/gsdali/OCCTSwift/issues/210).

## Conventions

- **Every example is runnable Swift** in a ```` ```swift ```` block, using the real current API
  (fallible factories return optionals — examples unwrap with `guard`/`if let`, never force-unwrap).
  Examples double as living docs; keep them compiling against the shipped API.
- **One canonical place per topic.** These pages hold *usage*; the Swift→OCCT mapping table lives in
  [`../../API_REFERENCE.md`](../../API_REFERENCE.md), concepts in
  [`occt-concepts.md`](../occt-concepts.md). Link, don't duplicate.
- **Replicate OCCT's examples.** Where OCCT's user guide shows a C++/Tcl example, port it to Swift so
  the same task is discoverable from either side.

## Figures (rendered headlessly via OCCTSwiftViewport)

OCCTSwift ships **no renderer** — visualization is OFF in the xcframework
(`BUILD_MODULE_Visualization=OFF`, see [`../../visualization-research.md`](../../visualization-research.md)).
Figures for these pages are produced **out-of-repo** by [OCCTSwiftViewport](https://github.com/gsdali/OCCTSwiftViewport)'s
headless Metal renderer (mesh-extraction path) and committed under `images/`. Each figure is
generated from the exact snippet above it, so the picture and the code never drift.

> Render workflow (in an OCCTSwiftViewport checkout that depends on this package):
> `swift run occtviewport-render --headless --input <example>.step --out docs/.../images/<name>.png`
> Image generation is tracked separately; pages are written image-ready (placeholders noted) so the
> prose + code (what context7 indexes) lands first.

## Pages

- [Booleans](booleans.md) — union / subtracting / intersection, fuzzy value, glue, timeout, self-intersection checks.
- _(more areas per #210: lofting & sweeps, threads, healing & validity, meshing & export, XCAF assemblies, topology graph)_
