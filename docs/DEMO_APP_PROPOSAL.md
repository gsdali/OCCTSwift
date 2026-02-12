# OCCTSwift Demo App Proposal

> **Status**: Phase 1 Complete, iOS Device Testing (2026-01-23)
> **Repository**: ~/Projects/OCCTSwiftDemo

## Overview

This document outlines a proposal for creating a demo/showcase application for OCCTSwift that provides:
1. **Text-based modeling input** - CadQuery-inspired scripting
2. **3D visualization** - Using ViewportKit for display
3. **Cross-platform support** - iOS and macOS

## Goals

- Demonstrate OCCTSwift's 120 wrapped operations
- Provide an interactive way to explore CAD modeling
- Lower the barrier to entry for new users
- Serve as a reference implementation

## Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐     ┌──────────────┐
│  Text Input     │ ──▶ │  JavaScriptCore  │ ──▶ │  OCCTSwift      │ ──▶ │  ViewportKit │
│  (JS/CadQuery)  │     │  Interpreter     │     │  (Mesh → Entity)│     │  (RealityKit)│
└─────────────────┘     └──────────────────┘     └─────────────────┘     └──────────────┘
```

### Components

| Component | Technology | Purpose |
|-----------|------------|---------|
| Code Editor | SwiftUI TextEditor + syntax highlighting | User input |
| Interpreter | JavaScriptCore (built-in) | Parse & execute scripts |
| Modeling | OCCTSwift | Generate B-Rep geometry |
| Meshing | OCCTSwift Mesh API | Triangulate for display |
| Display | ViewportKit + RealityKit | 3D visualization |

## Why JavaScriptCore?

We evaluated several approaches for text-based model input:

| Approach | iOS Support | CadQuery Compatibility | Complexity | Dependencies |
|----------|-------------|------------------------|------------|--------------|
| **JavaScriptCore** | ✅ Built-in | ~70% syntax match | Medium | None |
| PythonKit | ❌ macOS only | 100% | Low | Python runtime |
| Custom Parser | ✅ | 95% | High | None |
| Lua | ✅ | ~50% | Medium | Lua library |

**JavaScriptCore wins because:**
1. Built into iOS and macOS - no external dependencies
2. Dynamic evaluation at runtime
3. JavaScript's method chaining naturally mirrors CadQuery's fluent API
4. Good error handling for user feedback
5. JIT compiled for fast execution

## API Design

### CadQuery (Python) vs. Proposed JavaScript API

```python
# CadQuery (Python)
result = (
    cq.Workplane("XY")
    .box(10, 20, 5)
    .faces(">Z")
    .workplane()
    .hole(3)
    .edges("|Z")
    .fillet(1)
)
```

```javascript
// Proposed JavaScript API
result = Workplane("XY")
    .box(10, 20, 5)
    .faces(">Z")
    .hole(3)
    .edges("|Z")
    .fillet(1)
```

The syntax is nearly identical, making it easy for CadQuery users to adapt.

### API Mapping: CadQuery → OCCTSwift

#### Primitives (Phase 1)

| CadQuery | JavaScript API | OCCTSwift | Status |
|----------|----------------|-----------|--------|
| `cq.Workplane().box(l,w,h)` | `.box(l, w, h)` | `Shape.box(width:height:depth:)` | ✅ Ready |
| `.cylinder(h, r)` | `.cylinder(r, h)` | `Shape.cylinder(radius:height:)` | ✅ Ready |
| `.sphere(r)` | `.sphere(r)` | `Shape.sphere(radius:)` | ✅ Ready |
| `.cone(r1, r2, h)` | `.cone(r1, r2, h)` | `Shape.cone(bottomRadius:topRadius:height:)` | ✅ Ready |
| `.torus(r1, r2)` | `.torus(r1, r2)` | `Shape.torus(majorRadius:minorRadius:)` | ✅ Ready |

#### Boolean Operations (Phase 1)

| CadQuery | JavaScript API | OCCTSwift | Status |
|----------|----------------|-----------|--------|
| `.union(other)` | `.union(other)` | `shape + other` | ✅ Ready |
| `.cut(other)` | `.cut(other)` | `shape - other` | ✅ Ready |
| `.intersect(other)` | `.intersect(other)` | `shape & other` | ✅ Ready |

#### Modifications (Phase 1)

| CadQuery | JavaScript API | OCCTSwift | Status |
|----------|----------------|-----------|--------|
| `.fillet(r)` | `.fillet(r)` | `shape.filleted(radius:)` | ✅ Ready |
| `.chamfer(d)` | `.chamfer(d)` | `shape.chamfered(distance:)` | ✅ Ready |
| `.shell(t)` | `.shell(t)` | `shape.shelled(thickness:)` | ✅ Ready |

#### Transformations (Phase 1)

| CadQuery | JavaScript API | OCCTSwift | Status |
|----------|----------------|-----------|--------|
| `.translate((x,y,z))` | `.translate(x, y, z)` | `shape.translated(by:)` | ✅ Ready |
| `.rotate((x,y,z), (dx,dy,dz), a)` | `.rotate(ax, ay, az, angle)` | `shape.rotated(axis:angle:)` | ✅ Ready |
| `.mirror(plane)` | `.mirror(nx, ny, nz)` | `shape.mirrored(planeNormal:)` | ✅ Ready |

#### Selectors (Phase 2)

| CadQuery Selector | Meaning | Implementation |
|-------------------|---------|----------------|
| `">Z"` | Top face (normal +Z) | Filter faces by normal |
| `"<Z"` | Bottom face (normal -Z) | Filter faces by normal |
| `">X"`, `"<X"` | Right/left faces | Filter faces by normal |
| `"\|Z"` | Edges parallel to Z | Filter edges by direction |
| `"#Z"` | Edges perpendicular to Z | Filter edges by direction |

#### Sweep Operations (Phase 2)

| CadQuery | JavaScript API | OCCTSwift | Status |
|----------|----------------|-----------|--------|
| `.extrude(h)` | `.extrude(h)` | `Shape.extrude(profile:direction:length:)` | ✅ Ready |
| `.revolve(angle)` | `.revolve(angle)` | `Shape.revolve(profile:...)` | ✅ Ready |
| `.sweep(path)` | `.sweep(path)` | `Shape.sweep(profile:along:)` | ✅ Ready |
| `.loft([profiles])` | `.loft(profiles)` | `Shape.loft(profiles:)` | ✅ Ready |

#### Advanced Features (Phase 3)

| CadQuery | JavaScript API | OCCTSwift | Status |
|----------|----------------|-----------|--------|
| `.hole(d)` | `.hole(d)` | Boolean with cylinder | ✅ Ready |
| `.cboreHole(d, cbd, cbh)` | `.cboreHole(d, cbd, cbh)` | Multiple booleans | ✅ Ready |
| `.rect(w, h)` | `.rect(w, h)` | `Wire.rectangle()` | ✅ Ready |
| `.circle(r)` | `.circle(r)` | `Wire.circle()` | ✅ Ready |
| `.polygon(pts)` | `.polygon(pts)` | `Wire.polygon()` | ✅ Ready |

## Implementation Plan

### Phase 1: MVP (Core Functionality) ✅ COMPLETE

**Goal:** Basic shapes, booleans, and modifications with viewport display

**Status:** Completed 2026-01-22, iOS device testing 2026-01-23

**Components:**
1. ✅ JavaScriptCore bridge with basic API (`CadQueryInterpreter.swift`, `CadQueryShape.swift`)
2. ✅ Simple code editor (`CodeEditorView.swift` with line numbers)
3. ✅ ViewportKit integration (entity-based rendering)
4. ✅ Error display (`ConsoleView.swift`)
5. ✅ Platform-adaptive UI (macOS HSplitView, iPad 3-column, iPhone TabView)
6. ✅ Example library with presets
7. ✅ Safe operation handling (uses OCCTSwift try* methods to prevent crashes)

**API Coverage:**
- ✅ Primitives: box, cylinder, sphere, cone, torus
- ✅ Booleans: union, cut, intersect
- ✅ Modifications: fillet, chamfer, shell
- ✅ Transforms: translate, rotate, scale, mirror
- ✅ Holes: hole, cboreHole
- ✅ Face selection: >Z, <Z, >X, <X, >Y, <Y

**iOS Device Testing (2026-01-23):**
- ✅ App runs on iPhone
- ✅ Safe API prevents crashes when OCCT operations fail
- ⚠️ Some issues identified (to be documented)

**Files Created:**
```
~/Projects/OCCTSwiftDemo/
├── project.yml
├── Sources/
│   ├── App/OCCTSwiftDemoApp.swift
│   ├── App/AppState.swift
│   ├── Views/ContentView.swift
│   ├── Views/CodeEditorView.swift
│   ├── Views/ConsoleView.swift
│   ├── CadQueryBridge/CadQueryInterpreter.swift
│   ├── CadQueryBridge/CadQueryShape.swift  # Uses safe try* methods
│   └── CadQueryBridge/Examples.swift
└── Resources/Assets.xcassets/
```

### Phase 2: Workplanes & Selectors ⏳ PENDING

**Goal:** CadQuery-style workplane operations and face/edge selection

**Components:**
1. Selector parser (">Z", "|Z", etc.) - basic implemented, full pending
2. Workplane stack
3. 2D sketch operations
4. Context-sensitive operations (hole at selected face)

**API Coverage:**
- Selectors: faces(">Z"), edges("|Z"), vertices()
- Workplanes: workplane(), transformed()
- Sketches: rect(), circle(), polygon()
- Sweeps: extrude(), revolve()

**Tracked in:** [GitHub Issue #27](https://github.com/gsdali/OCCTSwift/issues/27)

### Phase 3: Polish & Examples ⏳ PENDING

**Goal:** Production-ready demo with examples

**Components:**
1. Syntax highlighting
2. Example library with presets (basic version done)
3. Properties panel (volume, area, etc.) - done
4. Export functionality
5. Save/load scripts

**Tracked in:** [GitHub Issue #28](https://github.com/gsdali/OCCTSwift/issues/28)

## UI Design

### Main Interface

```
┌─────────────────────────────────────────────────────────────────────────┐
│  OCCTSwift Playground                              [Examples ▼] [Run ▶] │
├────────────────────────────┬────────────────────────────────────────────┤
│                            │                                            │
│  // JavaScript Editor      │           ┌────────────────────┐           │
│  ────────────────────      │           │                    │           │
│  result = Workplane("XY")  │           │   [3D Viewport]    │           │
│    .box(10, 20, 5)         │           │                    │           │
│    .faces(">Z")            │           │    ViewportKit     │           │
│    .hole(3)                │           │                    │           │
│    .edges("|Z")            │           │  ┌──┐              │           │
│    .fillet(1)              │           │  │VC│ ViewCube     │           │
│                            │           └──┴──┴──────────────┘           │
│                            │                                            │
├────────────────────────────┼────────────────────────────────────────────┤
│  Console                   │  Properties                                │
│  ─────────                 │  ──────────                                │
│  ✓ Model created           │  Volume: 892.3 mm³                         │
│    Faces: 10               │  Surface Area: 614.2 mm²                   │
│    Edges: 24               │  Center of Mass: (5.0, 10.0, 2.5)          │
│    Vertices: 16            │  Bounding Box: 10 × 20 × 5 mm              │
└────────────────────────────┴────────────────────────────────────────────┘
```

### Example Scripts

**Basic Box with Fillet:**
```javascript
result = Workplane("XY")
    .box(30, 20, 10)
    .edges("|Z")
    .fillet(2)
```

**Mounting Bracket:**
```javascript
// Base plate
result = Workplane("XY")
    .box(60, 40, 5)
    .faces(">Z")
    .workplane()
    .rect(50, 30, {forConstruction: true})
    .vertices()
    .hole(4)
    .faces(">Z")
    .workplane()
    .center(0, 10)
    .rect(20, 30)
    .extrude(25)
    .edges("|Z")
    .fillet(3)
```

**Pipe Fitting:**
```javascript
outer = Workplane("XY").cylinder(5, 30)
inner = Workplane("XY").cylinder(4, 30)
result = outer.cut(inner)
    .faces(">Z")
    .fillet(0.5)
    .faces("<Z")
    .fillet(0.5)
```

## File Structure

```
OCCTSwiftDemo/
├── Package.swift
├── Sources/
│   └── OCCTSwiftDemo/
│       ├── App/
│       │   ├── OCCTSwiftDemoApp.swift
│       │   ├── ContentView.swift
│       │   └── AppState.swift
│       ├── Editor/
│       │   ├── CodeEditorView.swift
│       │   ├── SyntaxHighlighter.swift
│       │   └── ConsoleView.swift
│       ├── Viewport/
│       │   ├── ModelViewport.swift
│       │   └── PropertiesView.swift
│       ├── CadQueryBridge/
│       │   ├── CadQueryContext.swift
│       │   ├── CadQueryShape.swift
│       │   ├── CadQueryWorkplane.swift
│       │   ├── CadQuerySelectors.swift
│       │   └── CadQueryExports.swift
│       └── Examples/
│           ├── ExampleLoader.swift
│           └── Examples.json
└── Resources/
    └── Examples/
        ├── basic_box.js
        ├── filleted_box.js
        ├── bracket.js
        └── pipe_fitting.js
```

## Dependencies

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/gsdali/OCCTSwift.git", from: "0.14.0"),
    .package(url: "https://github.com/gsdali/ViewportKit.git", from: "1.0.0")
]
```

## Success Criteria

1. **Functional:** Users can type CadQuery-like scripts and see 3D results
2. **Educational:** Examples demonstrate OCCTSwift capabilities
3. **Responsive:** Updates display in <1 second for simple models
4. **Cross-platform:** Works on iOS and macOS
5. **Error handling:** Clear error messages for invalid scripts

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Complex selector parsing | Medium | Start with simple selectors (">Z", "|Z") |
| Performance with large models | Medium | Debounce execution, show progress |
| JSContext memory management | Low | Proper cleanup, weak references |
| ViewportKit compatibility | Low | Both use RealityKit, should integrate cleanly |

## Next Steps

1. Create GitHub issues for tracking
2. Set up demo app project structure
3. Implement Phase 1 JavaScriptCore bridge
4. Integrate with ViewportKit
5. Build example library

## References

- [CadQuery Documentation](https://cadquery.readthedocs.io/)
- [JavaScriptCore Framework](https://developer.apple.com/documentation/javascriptcore)
- [ViewportKit](https://github.com/gsdali/ViewportKit)
- [OCCTSwift](https://github.com/gsdali/OCCTSwift)
