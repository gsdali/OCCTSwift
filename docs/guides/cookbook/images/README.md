# Cookbook figures

Figures for the cookbook pages live here. They are **rendered headlessly out-of-repo** by
[OCCTSwiftViewport](https://github.com/gsdali/OCCTSwiftViewport) (OCCTSwift ships no renderer —
visualization is OFF in the xcframework). Each PNG is generated from the exact Swift snippet it
illustrates, so code and figure stay in sync.

Pages reference figures by name (e.g. `booleans-three-ops.png`) with an HTML comment noting what to
render; the images are committed once produced. See [`../README.md`](../README.md) → "Figures".
