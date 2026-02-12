# OCCTSwift - Claude Handoff Documentation

> **Last Updated**: 2026-01-23
> **Current Version**: v0.14.0 (with safe API additions)
> **Repository**: https://github.com/gsdali/OCCTSwift

This document provides complete context for a new Claude instance to manage this repository.

---

## 1. Repository Overview

**OCCTSwift** is a Swift wrapper for [OpenCASCADE Technology (OCCT)](https://www.opencascade.com/), providing B-Rep solid modeling capabilities for iOS and macOS applications.

### Key Facts
- **Language**: Swift 6.0 with Objective-C++ bridge
- **Platforms**: iOS 18+, macOS 15+
- **OCCT Version**: 8.0.0-rc3
- **License**: LGPL-2.1
- **Operations**: 120 wrapped OCCT operations across 17 categories
- **Tests**: 159 unit tests

### Primary Use Cases
- CAD/CAM applications
- 3D printing preparation
- AR/VR geometry processing
- CNC toolpath generation (PadCAM integration)

---

## 2. Repository Structure

```
OCCTSwift/
├── Sources/
│   ├── OCCTSwift/           # Swift public API
│   │   ├── Shape.swift      # 3D solid shapes, booleans, transforms
│   │   ├── Wire.swift       # 2D profiles, 3D paths
│   │   ├── Face.swift       # Face extraction and analysis
│   │   ├── Edge.swift       # Edge access and discretization
│   │   ├── Mesh.swift       # Triangulated mesh, RealityKit conversion
│   │   ├── Exporter.swift   # STL/STEP export
│   │   ├── Selection.swift  # Ray-casting, index access
│   │   └── FeatureRecognition.swift  # AAG, pocket detection
│   │
│   ├── OCCTBridge/          # Objective-C++ bridge to OCCT
│   │   ├── include/OCCTBridge.h    # C function declarations
│   │   └── src/OCCTBridge.mm       # OCCT C++ implementations
│   │
│   └── OCCTTest/            # Test executable
│       └── main.swift
│
├── Tests/OCCTSwiftTests/    # Unit tests
│   └── ShapeTests.swift
│
├── Libraries/               # Local development (gitignored)
│   ├── OCCT.xcframework/    # Pre-built OCCT binary
│   ├── OCCT.xcframework.zip # Zipped for release
│   └── occt-src/            # OCCT source (for building)
│
├── Scripts/
│   └── build-occt.sh        # Script to build OCCT xcframework
│
├── docs/
│   ├── CHANGELOG.md         # Version history
│   ├── EXTENDING.md         # How to add new OCCT functions
│   ├── RELEASE_NOTES_*.md   # Per-version release notes
│   └── CLAUDE_HANDOFF.md    # This document
│
└── Package.swift            # SPM package definition
```

---

## 3. Architecture

### Three-Layer Design

```
┌─────────────────────────────────────┐
│         Swift API (OCCTSwift)       │  ← Public interface
│  Shape, Wire, Face, Mesh, etc.      │
├─────────────────────────────────────┤
│      Objective-C++ Bridge           │  ← C functions callable from Swift
│         (OCCTBridge)                │
├─────────────────────────────────────┤
│     OCCT C++ Library                │  ← Pre-built xcframework
│      (OCCT.xcframework)             │
└─────────────────────────────────────┘
```

### Key Patterns

1. **Handle-based memory management**: OCCT objects are wrapped in opaque handles (`OCCTShapeRef`, `OCCTWireRef`, etc.) with explicit `Release` functions.

2. **Swift classes wrap handles**: Each Swift class (Shape, Wire, Face) holds a handle and calls `Release` in `deinit`.

3. **Factory methods**: Most objects are created via static factory methods (e.g., `Shape.box()`, `Wire.rectangle()`).

4. **Optionals for fallible operations**: Operations that can fail return optionals (e.g., `Wire.rectangle() -> Wire?`).

---

## 4. Building and Testing

### Prerequisites
- Xcode 16.0+
- Swift 6.1+
- macOS 12+ (for building)

### Local Development Setup

The package uses a **binary target** for OCCT. For local development:

1. **Option A: Use local xcframework** (recommended for development)

   Modify `Package.swift`:
   ```swift
   .binaryTarget(
       name: "OCCT",
       path: "Libraries/OCCT.xcframework"
   )
   ```

2. **Option B: Use remote binary** (for release/consumers)
   ```swift
   .binaryTarget(
       name: "OCCT",
       url: "https://github.com/gsdali/OCCTSwift/releases/download/v0.5.0/OCCT.xcframework.zip",
       checksum: "4f42d7854452946fb8e5141e654c84c2f3bdfcfebff703c143c7961ec340b7f7"
   )
   ```

### Build Commands

```bash
# Build
swift build

# Run tests (37 tests as of v0.5.0)
swift test

# Run test executable
swift run OCCTTest
```

### Building OCCT from Source

Only needed if upgrading OCCT version:

```bash
# See Scripts/build-occt.sh for full instructions
# Creates Libraries/OCCT.xcframework with:
#   - ios-arm64
#   - ios-arm64-simulator
#   - macos-arm64
```

---

## 5. Release Process

### Pre-Release Checklist

1. **Verify build and tests pass**
   ```bash
   swift build && swift test && swift run OCCTTest
   ```

2. **Update documentation**
   - Add entry to `docs/CHANGELOG.md`
   - Create `docs/RELEASE_NOTES_vX.Y.Z.md`
   - Update version in `README.md` SPM snippet

3. **Prepare binary** (if OCCT changed)
   ```bash
   # Copy to package_binaries for upload
   cp Libraries/OCCT.xcframework.zip ~/Projects/package_binaries/

   # Get checksum
   shasum -a 256 ~/Projects/package_binaries/OCCT.xcframework.zip
   ```

4. **Update Package.swift**
   - Change URL to new version tag
   - Update checksum if binary changed

### Release Commands

```bash
# 1. Commit release prep
git add -A
git commit -m "Prepare vX.Y.Z release"

# 2. Tag
git tag vX.Y.Z

# 3. Push
git push origin main --tags

# 4. Create GitHub release with asset
gh release create vX.Y.Z \
  --repo gsdali/OCCTSwift \
  --title "vX.Y.Z - Title" \
  --notes-file docs/RELEASE_NOTES_vX.Y.Z.md \
  ~/Projects/package_binaries/OCCT.xcframework.zip
```

### Package Binary Location

- **Local dev copy**: `~/Projects/OCCTSwift/Libraries/OCCT.xcframework.zip`
- **Release staging**: `~/Projects/package_binaries/OCCT.xcframework.zip`
- **Current checksum**: `4f42d7854452946fb8e5141e654c84c2f3bdfcfebff703c143c7961ec340b7f7`

---

## 6. Current State (as of v0.14.0)

### Recent Releases

| Version | Date | Key Changes |
|---------|------|-------------|
| v0.14.0 | 2026-01-22 | Variable radius fillet, multi-edge blend, 2D fillet/chamfer, surface filling, plate surfaces |
| v0.13.0 | 2026-01-21 | Shape analysis, fixing, unification, simplification |
| v0.12.0 | 2026-01-20 | Boss, pocket, drilling, splitting, gluing, evolved, patterns |
| v0.11.0 | 2026-01-19 | Face from wire, sewing, solid from shell, curve interpolation |
| v0.10.0 | 2026-01-18 | IGES import/export, BREP native format |
| v0.9.0 | 2026-01-17 | B-spline surfaces, ruled surfaces, curve analysis |
| v0.8.0 | 2026-01-16 | Draft angles, selective fillet, defeaturing, pipe shell modes |
| v0.7.0 | 2026-01-15 | Volume, surface area, distance measurement, center of mass |
| v0.6.0 | 2026-01-14 | XDE/XCAF document support, 2D drawing projection |
| v0.5.0 | 2026-01-02 | AAG feature recognition, Wire optionals, RealityKit |

### Demo App (OCCTSwiftDemo)

A companion demo app has been created to showcase OCCTSwift:
- **Location**: ~/Projects/OCCTSwiftDemo
- **Status**: Phase 1 complete, tested on iOS device (2026-01-23)
- **Features**: CadQuery-inspired JavaScript scripting, ViewportKit 3D display
- **iOS Testing**: App runs on iPhone with some issues (to be documented)
- **See**: [DEMO_APP_PROPOSAL.md](DEMO_APP_PROPOSAL.md)

### Safe API Additions (2026-01-23)

Added optional-returning versions of operations that can fail, preventing crashes when OCCT operations return nil:

```swift
// Safe primitives
Shape.tryBox(width:height:depth:) -> Shape?
Shape.tryCylinder(radius:height:) -> Shape?
Shape.trySphere(radius:) -> Shape?
Shape.tryCone(bottomRadius:topRadius:height:) -> Shape?
Shape.tryTorus(majorRadius:minorRadius:) -> Shape?

// Safe booleans
shape.tryUnion(with:) -> Shape?
shape.trySubtracting(_:) -> Shape?
shape.tryIntersection(with:) -> Shape?

// Safe modifications
shape.tryFilleted(radius:) -> Shape?
shape.tryChamfered(distance:) -> Shape?
shape.tryShelled(thickness:) -> Shape?
shape.tryOffset(by:) -> Shape?

// Safe transforms
shape.tryTranslated(by:) -> Shape?
shape.tryRotated(axis:angle:) -> Shape?
shape.tryScaled(by:) -> Shape?
shape.tryMirrored(planeNormal:planeOrigin:) -> Shape?
```

These are used by OCCTSwiftDemo to gracefully handle failures on iOS.

### Open Issues

| # | Title | Priority | Notes |
|---|-------|----------|-------|
| 1 | SPM header paths don't work as dependency | Bug | Real issue, not yet fixed |
| 25 | Demo App - Parent Issue | Feature | Phase 1 complete |
| 26 | Demo App Phase 1: MVP | Feature | ✅ Complete |
| 27 | Demo App Phase 2: Workplanes | Feature | Pending |
| 28 | Demo App Phase 3: Polish | Feature | Pending |

### Closed Issues (Recent)

| # | Title | Resolution |
|---|-------|------------|
| 24 | v0.14.0 Release | Completed |
| 18 | Wire.polygon crashes | Fixed in v0.5.0 |
| 17 | v0.4.0 missing binary asset | Fixed |

---

## 7. API Overview (120+ Operations)

### Shape (3D Solids)

```swift
// Primitives (7 + safe variants)
Shape.box(width:height:depth:)
Shape.tryBox(width:height:depth:) -> Shape?      // safe version
Shape.cylinder(radius:height:)
Shape.tryCylinder(radius:height:) -> Shape?      // safe version
Shape.cylinder(at:bottomZ:radius:height:)        // positioned
Shape.sphere(radius:)
Shape.trySphere(radius:) -> Shape?               // safe version
Shape.cone(bottomRadius:topRadius:height:)
Shape.tryCone(...) -> Shape?                     // safe version
Shape.torus(majorRadius:minorRadius:)
Shape.tryTorus(...) -> Shape?                    // safe version
Shape.surface(...)  // B-spline surface

// Booleans (3 + safe variants)
shape1 + shape2  // union
shape1 - shape2  // subtract
shape1 & shape2  // intersect
shape.tryUnion(with:) -> Shape?                  // safe version
shape.trySubtracting(_:) -> Shape?               // safe version
shape.tryIntersection(with:) -> Shape?           // safe version

// Transforms (4 + safe variants)
shape.translated(by:)
shape.tryTranslated(by:) -> Shape?               // safe version
shape.rotated(axis:angle:)
shape.tryRotated(axis:angle:) -> Shape?          // safe version
shape.scaled(by:)
shape.tryScaled(by:) -> Shape?                   // safe version
shape.mirrored(planeNormal:planeOrigin:)
shape.tryMirrored(...) -> Shape?                 // safe version

// Modifications (9 + safe variants)
shape.filleted(radius:)
shape.tryFilleted(radius:) -> Shape?             // safe version
shape.filleted(edges:radius:)                    // selective
shape.filletedVariable(...)                      // variable radius (v0.14.0)
shape.blendedMultiEdge(...)                      // multi-edge blend (v0.14.0)
shape.chamfered(distance:)
shape.tryChamfered(distance:) -> Shape?          // safe version
shape.shelled(thickness:)
shape.tryShelled(thickness:) -> Shape?           // safe version
shape.shelled(thickness:openFaces:)
shape.offset(by:)
shape.tryOffset(by:) -> Shape?                   // safe version
shape.drafted(...)
shape.defeatured(facesToRemove:)

// Sweeps (6)
Shape.extrude(profile:direction:length:)
Shape.revolve(profile:...)
Shape.sweep(profile:along:)
Shape.pipeShell(profile:spine:...)
Shape.loft(profiles:solid:)
Shape.ruled(wire1:wire2:)

// Feature-Based (10)
Shape.boss(on:profile:height:draft:fillet:)
Shape.pocket(in:profile:depth:draft:fillet:)
Shape.prism(profile:height:draft:)
shape.drilled(...)
shape.split(by:)
Shape.glue(shapes:tolerance:)
Shape.evolved(spine:profile:)
shape.linearPattern(...)
shape.circularPattern(...)

// Geometry Construction (7)
Shape.face(from:)
Shape.face(outer:holes:)
Shape.solid(from:)
Shape.sew(shapes:tolerance:)
Shape.fill(boundary:)                   // N-sided fill (v0.14.0)
Shape.plateSurface(through:)            // plate surface (v0.14.0)
Shape.plateCurves(wires:...)            // plate from curves (v0.14.0)

// Healing/Analysis (7)
shape.analyze()
shape.fixed()
shape.unified()
shape.simplified()
shape.withoutSmallFaces(minArea:)

// Measurement (7)
shape.volume
shape.surfaceArea
shape.centerOfMass
shape.properties
shape.distance(to:)
shape.minDistance(to:)
shape.intersects(_:)

// Import/Export (10)
Shape.load(from:)           // STEP
Shape.loadIGES(from:)
Shape.loadBREP(from:)
shape.writeSTEP(to:)
shape.writeSTL(to:deflection:)
shape.writeIGES(to:)
shape.writeBREP(to:)
shape.mesh(...)

// XDE/Document (10)
Document.load(from:)
document.rootNodes
AssemblyNode properties...
```

### Wire (17 Operations)

```swift
Wire.rectangle(width:height:)
Wire.circle(radius:)
Wire.polygon(_:closed:)
Wire.line(from:to:)
Wire.arc(center:radius:startAngle:endAngle:normal:)
Wire.bspline(_:)
Wire.nurbs(poles:weights:knots:multiplicities:degree:)
Wire.path(_:)
Wire.join(_:)
Wire.interpolate(through:)

wire.offset(by:joinType:)
wire.offset3D(distance:)
wire.filleted2D(radius:)      // 2D fillet (v0.14.0)
wire.filletedAll2D(radius:)   // all corners (v0.14.0)
wire.chamfered2D(distance:)   // 2D chamfer (v0.14.0)
wire.chamferedAll2D(distance:)
wire.fixed()
```

### Curve Analysis (6)

```swift
edge.length
edge.curveInfo()
edge.point(at:)
edge.tangent(at:)
edge.curvature(at:)
edge.curvePoint(at:)
```

### Mesh

```swift
let mesh = shape.mesh(linearDeflection:angularDeflection:)
mesh.vertices      // [SIMD3<Float>]
mesh.normals       // [SIMD3<Float>]
mesh.indices       // [UInt32]

mesh.sceneKitGeometry()
mesh.toMeshResource()       // RealityKit
```

### Feature Recognition

```swift
let aag = AAG(shape: shape)
let pockets = aag.detectPockets()
let holes = aag.detectHoles()
```

---

## 8. Common Operations

### Adding a New OCCT Function

1. **Add C declaration** in `Sources/OCCTBridge/include/OCCTBridge.h`
2. **Implement in C++** in `Sources/OCCTBridge/src/OCCTBridge.mm`
3. **Add Swift wrapper** in appropriate file under `Sources/OCCTSwift/`
4. **Add tests** in `Tests/OCCTSwiftTests/ShapeTests.swift`

See `docs/EXTENDING.md` for detailed guide.

### Upgrading OCCT Version

1. Download new OCCT source to `Libraries/occt-src/`
2. Run `Scripts/build-occt.sh` (modify for new version)
3. Test thoroughly
4. Zip the xcframework
5. Update Package.swift checksum
6. Create new release with binary asset

### Debugging Build Issues

- **"Standard.hxx not found"**: Header search paths issue. Check Package.swift `headerSearchPath` settings.
- **Binary target 404**: Release asset may not be uploaded. Check `gh release view <tag>`.
- **Link errors**: Ensure `linkedLibrary("c++")` is present.

---

## 9. External Integrations

### PadCAM

OCCTSwift is used by PadCAM for CNC toolpath generation:
- Repository: https://github.com/gsdali/PadCAM
- Uses: Shape loading, slicing, face analysis, pocket detection

### Known Issue #1 (SPM Dependency)

When used as SPM dependency, header paths fail. Workaround options in Issue #1:
- Symlink headers
- Bundle headers in repo
- Use Package plugin

---

## 10. Key Files Quick Reference

| File | Purpose |
|------|---------|
| `Package.swift` | SPM definition, binary target URL/checksum |
| `Sources/OCCTBridge/include/OCCTBridge.h` | All C function declarations |
| `Sources/OCCTBridge/src/OCCTBridge.mm` | All OCCT C++ implementations |
| `Sources/OCCTSwift/Shape.swift` | Main Shape class |
| `Sources/OCCTSwift/Wire.swift` | Wire/path creation |
| `docs/CHANGELOG.md` | Version history |
| `docs/EXTENDING.md` | How to add new functions |
| `Libraries/OCCT.xcframework.zip` | Local binary (143MB, gitignored) |
| `~/Projects/package_binaries/` | Release binary staging area |

---

## 11. Useful Commands

```bash
# Repository status
gh repo view gsdali/OCCTSwift
gh pr list --repo gsdali/OCCTSwift
gh issue list --repo gsdali/OCCTSwift

# Release management
gh release list --repo gsdali/OCCTSwift
gh release view <tag> --repo gsdali/OCCTSwift
gh release download <tag> --repo gsdali/OCCTSwift --pattern "*.zip"

# Build/test
swift build
swift test
swift run OCCTTest

# Checksum
shasum -a 256 <file>
```

---

## 12. Contact & Resources

- **GitHub**: https://github.com/gsdali/OCCTSwift
- **OCCT Docs**: https://dev.opencascade.org/doc/overview/html/
- **OCCT Source**: https://github.com/Open-Cascade-SAS/OCCT

---

*This document should be updated with each major release or significant change.*
