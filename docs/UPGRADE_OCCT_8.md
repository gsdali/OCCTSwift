# Upgrading OCCTSwift to OCCT 8.0

## Overview

This branch (`occt-8.0`) prepares OCCTSwift for OpenCASCADE Technology 8.0.

**Current version:** 8.0.0-rc3 (December 15, 2024)
**Expected stable release:** February 2025 (based on OCCT release patterns)

## Why Upgrade?

1. **Fixes STEP export segfault** (bug #33656) - Crash during program exit with complex geometry
2. **RTTI modernization** - Standard C++ type_info instead of custom system
3. **Performance improvements** - Math functions, threading, BSpline computation
4. **Modern C++** - Move semantics, constexpr, noexcept throughout

## Breaking Changes to Address

### 1. StepType() API Change

`StepData_ReadWriteModule::StepType()` now returns `std::string_view` instead of `TCollection_AsciiString`.

**Impact:** We don't use this API directly - no changes needed.

### 2. Deprecated Math Functions

Functions like `Sqrt()`, `Cos()`, `Sin()` are deprecated in favor of `std::sqrt()`, etc.

**Impact:** Checked - we don't use these in OCCTBridge - no changes needed.

### 3. Standard_Mutex Deprecated

Replace with `std::mutex`.

**Impact:** We don't use this - no changes needed.

### 4. Removed Classes

- `OSD_MAllocHook` - memory debugging (not used)
- `PLib_Base` and `PLib_DoubleJacobiPolynomial` - polynomial utilities (not used)
- `TopTools_MutexForShapeProvider` - threading (not used)

**Impact:** None of these are used in OCCTBridge.

## Build Instructions

```bash
# Remove old OCCT build artifacts
cd Libraries
rm -rf occt-src occt-build-* occt-install-* OCCT.xcframework

# Build OCCT 8.0.0-rc3 for iOS/macOS
./Scripts/build-occt.sh
```

Build time: ~30-60 minutes

## Testing Checklist

- [x] Full rebuild of OCCT.xcframework (546MB total)
- [x] Swift package builds (6.55s)
- [x] All 23 tests pass
- [x] STEP export without segfault at exit (**Exit code 0!**)
- [x] STL export works
- [x] Face analysis works
- [x] Wire offset works
- [x] Boolean operations work

**Verified 2025-12-31**: OCCT 8.0.0-rc3 build successful. Segfault at exit is fixed.

## Version Notes

### 8.0.0-rc3 Changes (from rc2)
- 157 improvements and bug fixes
- Math functions migrated to C++ standard library
- Threading improvements (std::mutex)
- Performance optimizations

### When to Update to 8.0.0 Final

1. Wait for 8.0.0 stable release (expected February 2025)
2. Update `OCCT_VERSION` and clear `OCCT_RC` in build script
3. Full rebuild and test
4. Merge to main

## Files Changed

- `Scripts/build-occt.sh` - Updated version and GitHub clone for RCs
- `docs/UPGRADE_OCCT_8.md` - This file
