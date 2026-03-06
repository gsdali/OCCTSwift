# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Summary

OCCTSwift is a comprehensive Swift wrapper for OpenCASCADE Technology (OCCT) 8.0.0-rc4. It exposes B-Rep solid modeling capabilities to Swift via a three-layer architecture: Swift public API → Objective-C++ bridge (C functions) → OCCT C++ library.

## Build & Test Commands

```bash
swift build                # Build the package
swift test                 # Run all tests (1162 tests, 330 suites)
swift test --filter "SuiteName"  # Run a single test suite
swift run OCCTTest         # Run test executable
```

### Compile a Ground Truth C++ Test

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  /tmp/occt_vXX_test.mm -o /tmp/occt_vXX_test
/tmp/occt_vXX_test
```

### Verify OCCT Symbols

```bash
nm -C Libraries/OCCT.xcframework/macos-arm64/libOCCT-macos.a 2>/dev/null | grep "ClassName" | head -5
```

## Architecture

```
Sources/OCCTSwift/          Swift public API (Shape, Wire, Surface, Face, Edge, Curve3D, Mesh, etc.)
Sources/OCCTBridge/include/ C function declarations (OCCTBridge.h)
Sources/OCCTBridge/src/     Objective-C++ implementations (OCCTBridge.mm)
Libraries/OCCT.xcframework  Pre-built OCCT static library (arm64 macOS/iOS)
Tests/OCCTSwiftTests/       All tests in ShapeTests.swift (Swift Testing framework)
Scripts/build-occt.sh       Builds OCCT.xcframework from source
```

### Handle-Based Memory Management

Opaque handle types (`OCCTShapeRef`, `OCCTWireRef`, `OCCTFaceRef`, `OCCTEdgeRef`, `OCCTMeshRef`) are typedef'd pointers. Swift classes wrap these handles and call the corresponding `Release` function in `deinit`. Every bridge function that creates an OCCT object must have a matching `Release` function.

### Adding a New Wrapped Operation

1. **Bridge header** (`OCCTBridge.h`): Add C function declaration
2. **Bridge impl** (`OCCTBridge.mm`): Add Objective-C++ implementation calling OCCT C++ API
3. **Swift wrapper** (appropriate `.swift` file): Add public method/static factory
4. **Test** (`ShapeTests.swift`): Add `@Suite`/`@Test` using Swift Testing

## Naming Conventions

- Bridge functions: `OCCTShape...`, `OCCTWire...`, `OCCTFace...`, `OCCTEdge...`
- Wire-to-shape conversion: `OCCTShapeFromWire()` (NOT `OCCTWireToShape`)
- Check enum values: `OCCTCheckNoError` (NOT `OCCTCheckStatusNoError`)
- `vertices()` is a method, not a property
- Swift factory methods are static: `Shape.box()`, `Wire.rectangle()`
- Fallible operations return optionals, not force-unwrapped values

## Test Conventions

- Framework: Swift Testing (`@Suite`, `@Test`, `#expect`)
- **Never force-unwrap in `#expect`** — Swift Testing does NOT short-circuit. Use:
  ```swift
  if let r = result { #expect(r.isValid) }
  ```
  Not: `#expect(result != nil); #expect(result!.isValid)`
- Edge indices may vary across runs — iterate edges to find a working one when testing edge-specific operations
- Wrap OCCT calls that may throw `StdFail_NotDone` in try-catch on the C bridge side

## Known OCCT Bugs

- `BRepExtrema_ExtCC` crashes when edges are parallel — guard with `if (result.isParallel) { return result; }` before accessing points
- Container-overflow in NCollection on arm64 macOS — pre-existing OCCT race condition that manifests as non-deterministic SEGV under parallel test execution
- `LocOpe_SplitDrafts` throws on incompatible geometry — always wrap `Perform()` in try-catch in bridge

## Release Process

Each release adds ~20-25 new operations following this strict order:

1. Ground truth C++ test at `/tmp/occt_vXX_test.mm` — compile and run
2. C bridge declarations + implementations
3. `swift build` — zero errors
4. Swift wrappers
5. `swift build` — zero errors
6. Tests
7. `swift test` — all pass
8. Update README.md (table counts, feature bullets, totals)
9. `git commit`, `git push`, `git tag vX.Y.Z`, `gh release create`

## Workflow Automations

### Slash Commands

- **`/audit-occt`** — Scans all 6,612 OCCT headers against `OCCTBridge.h` and produces a categorized gap report with Tier 1/2/3 priorities and a recommended next-release scope. Use this to plan what to wrap next.
- **`/ground-truth`** `<version> <Class1> <Class2> ...` — Generates `/tmp/occt_v{XX}_test.mm`, compiles it against the xcframework, runs it, and reports pass/fail. Use this as step 1 of the release process.

### Subagents (`.claude/agents/`)

- **`occt-header-analyzer`** — Reads OCCT `.hxx` headers for specified classes. Extracts constructors, methods, Handle usage, and dependencies. Proposes C bridge function signatures following project conventions. Flags abstract classes and complex hierarchies.
- **`bridge-generator`** — Takes header analysis and generates all four code artifacts: bridge header declarations, bridge Obj-C++ implementations, Swift wrappers, and Swift Testing tests. Encodes exact patterns from the codebase.

### Typical Wrapping Workflow

1. `/audit-occt` → pick ~20-25 operations for the next release
2. `/ground-truth v51 Class1 Class2 ...` → verify OCCT APIs work
3. Invoke `occt-header-analyzer` agent on the class list → get API analysis
4. Invoke `bridge-generator` agent with the analysis → get code artifacts
5. Insert generated code, `swift build`, `swift test`, iterate on failures
6. Update README.md, commit, tag, release

## User Directives

- Wrap **everything** — comprehensive wrapper, leave nothing out
- Each release should be ~20-25 new operations
- Infinite OCCT surfaces must be trimmed before converting to BSpline
