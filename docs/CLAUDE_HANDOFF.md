# OCCTSwift - Claude Handoff Documentation

> **Last Updated**: 2026-01-14
> **Current Version**: v0.6.0
> **Repository**: https://github.com/gsdali/OCCTSwift

This document provides complete context for a new Claude instance to manage this repository.

---

## 1. Repository Overview

**OCCTSwift** is a Swift wrapper for [OpenCASCADE Technology (OCCT)](https://www.opencascade.com/), providing B-Rep solid modeling capabilities for iOS and macOS applications.

### Key Facts
- **Language**: Swift 6.1 with Objective-C++ bridge
- **Platforms**: iOS 15+, macOS 12+
- **OCCT Version**: 8.0.0-rc3
- **License**: MIT (wrapper), LGPL-2.1 (OCCT)

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

## 6. Current State (as of v0.5.0)

### Recent Releases

| Version | Date | Key Changes |
|---------|------|-------------|
| v0.5.0 | 2026-01-02 | AAG feature recognition, Wire optionals, RealityKit |
| v0.4.0 | 2025-12-31 | OCCT 8.0.0-rc3 upgrade, STEP export fix |
| v0.3.0 | 2025-12-31 | Face analysis for CAM |
| v0.2.1 | 2025-12-30 | Wire offset, NURBS, memory fix |

### Open Issues

| # | Title | Priority | Notes |
|---|-------|----------|-------|
| 1 | SPM header paths don't work as dependency | Bug | Real issue, not yet fixed |
| 2 | CAM: Wire Offsetting and Contour Extraction | Feature | Wire.offset() done, more pending |
| 3 | Coordinate System Support for CAM | Enhancement | Low priority, can do at app level |
| 4 | True Swept Solid for Tool Paths | Enhancement | Low priority, toolSweep() sufficient |

### Closed Issues (Recent)

| # | Title | Resolution |
|---|-------|------------|
| 18 | Wire.polygon crashes | Fixed in v0.5.0 (PR #19) |
| 17 | v0.4.0 missing binary asset | Fixed |
| 15-5 | Various feature requests | Implemented |

---

## 7. API Overview

### Shape (3D Solids)

```swift
// Primitives
Shape.box(width:height:depth:)
Shape.cylinder(radius:height:)
Shape.sphere(radius:)
Shape.cone(radius1:radius2:height:)
Shape.torus(majorRadius:minorRadius:)

// Booleans
shape1 + shape2  // union
shape1 - shape2  // subtract
shape1 & shape2  // intersect

// Transforms
shape.translated(by:)
shape.rotated(axis:angle:)
shape.scaled(by:)
shape.mirrored(planeNormal:planeOrigin:)

// Modifications
shape.filleted(radius:)
shape.chamfered(distance:)
shape.shelled(thickness:)

// Sweeps
Shape.extrude(profile:direction:length:)
Shape.revolve(profile:axisOrigin:axisDirection:angle:)
Shape.sweep(profile:along:)
Shape.loft(profiles:solid:)

// Import/Export
Shape.load(from:)           // STEP import
shape.writeSTEP(to:)
shape.writeSTL(to:deflection:)

// Analysis
shape.bounds
shape.isValid
shape.faces()
shape.sliceAtZ(_:)
shape.buildAAG()            // Feature recognition (v0.5.0)
```

### Wire (2D/3D Paths)

```swift
// All return Wire? (optional since v0.5.0)
Wire.rectangle(width:height:)
Wire.circle(radius:)
Wire.polygon(_:closed:)
Wire.line(from:to:)
Wire.arc(center:radius:startAngle:endAngle:normal:)
Wire.bspline(_:)
Wire.nurbs(poles:weights:knots:multiplicities:degree:)
Wire.join(_:)

// Operations
wire.offset(by:joinType:)   // Tool compensation
```

### Mesh

```swift
let mesh = shape.mesh(linearDeflection:angularDeflection:)
mesh.vertices      // [SIMD3<Float>]
mesh.normals       // [SIMD3<Float>]
mesh.triangles     // [(Int, Int, Int)]

// Export
mesh.sceneKitGeometry()
mesh.toMeshResource()       // RealityKit (v0.5.0)
mesh.toModelComponent()     // RealityKit (v0.5.0)
```

### Feature Recognition (v0.5.0)

```swift
let aag = AAG(shape: shape)
let pockets = aag.detectPockets()
let holes = aag.detectHoles()

// Pocket info
pocket.floorFaceIndex
pocket.wallFaceIndices
pocket.zLevel
pocket.depth
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
