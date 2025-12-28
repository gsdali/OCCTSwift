# Building OpenCASCADE for iOS/macOS

This guide explains how to build OCCT as static libraries for use with OCCTSwift.

## Prerequisites

- macOS 13+ (Ventura or later)
- Xcode 15+ with Command Line Tools
- CMake 3.20+ (`brew install cmake`)
- About 10GB free disk space (source + build)

## Quick Start

```bash
cd /path/to/OCCTSwift
./Scripts/build-occt.sh
```

This will:
1. Download OCCT 7.8.1 source
2. Build for iOS (arm64) and iOS Simulator (arm64)
3. Build for macOS (arm64)
4. Create `Libraries/OCCT.xcframework`

## Manual Build Steps

### 1. Download OCCT Source

```bash
cd /path/to/OCCTSwift/Libraries

# Download from official source
curl -L -o occt-7.8.1.tar.gz \
    https://git.dev.opencascade.org/gitweb/?p=occt.git;a=snapshot;h=refs/tags/V7_8_1;sf=tgz

# Or clone the repository
git clone --depth 1 --branch V7_8_1 \
    https://git.dev.opencascade.org/repos/occt.git occt-src
```

### 2. Configure CMake for iOS

Create a toolchain file `ios.toolchain.cmake`:

```cmake
set(CMAKE_SYSTEM_NAME iOS)
set(CMAKE_OSX_ARCHITECTURES arm64)
set(CMAKE_OSX_DEPLOYMENT_TARGET 15.0)
set(CMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH NO)

# Ensure we build static libraries
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)

# Find the iOS SDK
execute_process(
    COMMAND xcrun --sdk iphoneos --show-sdk-path
    OUTPUT_VARIABLE CMAKE_OSX_SYSROOT
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
```

### 3. Build for iOS Device

```bash
mkdir -p occt-build-ios && cd occt-build-ios

cmake ../occt-src \
    -DCMAKE_TOOLCHAIN_FILE=../ios.toolchain.cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=../occt-install-ios \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_MODULE_Draw=OFF \
    -DBUILD_MODULE_Visualization=OFF \
    -DUSE_FREETYPE=OFF \
    -DUSE_FREEIMAGE=OFF \
    -DUSE_RAPIDJSON=OFF \
    -DUSE_TBB=OFF \
    -DUSE_VTK=OFF \
    -DUSE_OPENGL=OFF

cmake --build . --config Release --parallel $(sysctl -n hw.ncpu)
cmake --install .
```

### 4. Build for iOS Simulator

```bash
mkdir -p occt-build-sim && cd occt-build-sim

# Modify toolchain for simulator
cmake ../occt-src \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_SYSROOT=$(xcrun --sdk iphonesimulator --show-sdk-path) \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=../occt-install-sim \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_MODULE_Draw=OFF \
    -DBUILD_MODULE_Visualization=OFF \
    -DUSE_FREETYPE=OFF \
    -DUSE_FREEIMAGE=OFF \
    -DUSE_RAPIDJSON=OFF \
    -DUSE_TBB=OFF \
    -DUSE_VTK=OFF \
    -DUSE_OPENGL=OFF

cmake --build . --config Release --parallel $(sysctl -n hw.ncpu)
cmake --install .
```

### 5. Build for macOS

```bash
mkdir -p occt-build-macos && cd occt-build-macos

cmake ../occt-src \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=../occt-install-macos \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_MODULE_Draw=OFF \
    -DBUILD_MODULE_Visualization=OFF \
    -DUSE_FREETYPE=OFF \
    -DUSE_FREEIMAGE=OFF \
    -DUSE_RAPIDJSON=OFF \
    -DUSE_TBB=OFF \
    -DUSE_VTK=OFF \
    -DUSE_OPENGL=OFF

cmake --build . --config Release --parallel $(sysctl -n hw.ncpu)
cmake --install .
```

### 6. Create XCFramework

```bash
# Combine all static libraries into single fat library per platform
# (OCCT produces many .a files, we need to combine them)

# For each platform, create combined library:
libtool -static -o libOCCT-ios.a \
    occt-install-ios/lib/*.a

libtool -static -o libOCCT-sim.a \
    occt-install-sim/lib/*.a

libtool -static -o libOCCT-macos.a \
    occt-install-macos/lib/*.a

# Create XCFramework
xcodebuild -create-xcframework \
    -library libOCCT-ios.a -headers occt-install-ios/include \
    -library libOCCT-sim.a -headers occt-install-sim/include \
    -library libOCCT-macos.a -headers occt-install-macos/include \
    -output OCCT.xcframework
```

## Required OCCT Modules

For OCCTSwift, we need these modules:

| Module | Purpose | Required |
|--------|---------|----------|
| TKernel | Core utilities | Yes |
| TKMath | Math primitives | Yes |
| TKG2d | 2D geometry | Yes |
| TKG3d | 3D geometry | Yes |
| TKGeomBase | Geometric entities | Yes |
| TKGeomAlgo | Geometric algorithms | Yes |
| TKBRep | B-Rep structures | Yes |
| TKTopAlgo | Topological algorithms | Yes |
| TKPrim | Primitives | Yes |
| TKShHealing | Shape repair | Yes |
| TKBO | Boolean operations | Yes |
| TKFillet | Fillet/chamfer | Yes |
| TKOffset | Offset/shell | Yes |
| TKMesh | Meshing | Yes |
| TKSTEP | STEP export | Yes |
| TKSTL | STL export | Yes |
| TKBinXCAF | Persistent storage | Optional |
| TKXCAF | Assembly framework | Optional |

## Build Options Explained

```cmake
# Disable modules we don't need
-DBUILD_MODULE_Draw=OFF          # Interactive test harness
-DBUILD_MODULE_Visualization=OFF # OpenGL visualization (using SceneKit instead)

# Disable optional dependencies
-DUSE_FREETYPE=OFF    # Font rendering (not needed)
-DUSE_FREEIMAGE=OFF   # Image loading (not needed)
-DUSE_RAPIDJSON=OFF   # JSON (not needed for core)
-DUSE_TBB=OFF         # Intel threading (iOS has GCD)
-DUSE_VTK=OFF         # VTK visualization (not needed)
-DUSE_OPENGL=OFF      # Direct OpenGL (using SceneKit)
```

## Troubleshooting

### "No CMAKE_CXX_COMPILER could be found"

Install Xcode Command Line Tools:
```bash
xcode-select --install
```

### Undefined symbols for architecture arm64

Make sure all libraries are built for the same architecture:
```bash
lipo -info libTKernel.a  # Should show: arm64
```

### Build fails with C++17 errors

Ensure CMake uses C++17:
```cmake
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
```

### Library too large

The full OCCT build can be 500MB+. To reduce size:

1. Build only required modules (see table above)
2. Strip debug symbols: `strip -S libOCCT.a`
3. Use `-Os` optimization: `-DCMAKE_CXX_FLAGS="-Os"`

### Simulator build fails

Ensure you're using the correct SDK:
```bash
xcrun --sdk iphonesimulator --show-sdk-path
```

## Verifying the Build

### Check library contents

```bash
# List symbols
nm -g OCCT.xcframework/ios-arm64/libOCCT.a | grep BRepPrimAPI

# Check architectures
lipo -info OCCT.xcframework/ios-arm64/libOCCT.a
```

### Test in Xcode

1. Create new iOS app project
2. Drag OCCT.xcframework into project
3. Add simple test code:

```objc
// In a .mm file
#include <BRepPrimAPI_MakeBox.hxx>

void testOCCT() {
    BRepPrimAPI_MakeBox box(10, 20, 30);
    TopoDS_Shape shape = box.Shape();
    // If this compiles and runs, OCCT is working
}
```

## Automated Build Script

Save as `Scripts/build-occt.sh`:

```bash
#!/bin/bash
set -e

OCCT_VERSION="7.8.1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LIBRARIES_DIR="$PROJECT_DIR/Libraries"

echo "Building OCCT $OCCT_VERSION for iOS and macOS..."

cd "$LIBRARIES_DIR"

# Download if needed
if [ ! -d "occt-src" ]; then
    echo "Downloading OCCT source..."
    git clone --depth 1 --branch "V${OCCT_VERSION//./_}" \
        https://git.dev.opencascade.org/repos/occt.git occt-src
fi

# Common CMake options
CMAKE_COMMON_OPTS=(
    -DBUILD_SHARED_LIBS=OFF
    -DBUILD_MODULE_Draw=OFF
    -DBUILD_MODULE_Visualization=OFF
    -DUSE_FREETYPE=OFF
    -DUSE_FREEIMAGE=OFF
    -DUSE_RAPIDJSON=OFF
    -DUSE_TBB=OFF
    -DUSE_VTK=OFF
    -DUSE_OPENGL=OFF
    -DCMAKE_BUILD_TYPE=Release
)

# Build for iOS device
echo "Building for iOS..."
mkdir -p occt-build-ios && cd occt-build-ios
cmake ../occt-src \
    "${CMAKE_COMMON_OPTS[@]}" \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_SYSROOT="$(xcrun --sdk iphoneos --show-sdk-path)" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
    -DCMAKE_INSTALL_PREFIX=../occt-install-ios
cmake --build . --config Release --parallel "$(sysctl -n hw.ncpu)"
cmake --install .
cd ..

# Build for iOS Simulator
echo "Building for iOS Simulator..."
mkdir -p occt-build-sim && cd occt-build-sim
cmake ../occt-src \
    "${CMAKE_COMMON_OPTS[@]}" \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_SYSROOT="$(xcrun --sdk iphonesimulator --show-sdk-path)" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
    -DCMAKE_INSTALL_PREFIX=../occt-install-sim
cmake --build . --config Release --parallel "$(sysctl -n hw.ncpu)"
cmake --install .
cd ..

# Build for macOS
echo "Building for macOS..."
mkdir -p occt-build-macos && cd occt-build-macos
cmake ../occt-src \
    "${CMAKE_COMMON_OPTS[@]}" \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 \
    -DCMAKE_INSTALL_PREFIX=../occt-install-macos
cmake --build . --config Release --parallel "$(sysctl -n hw.ncpu)"
cmake --install .
cd ..

# Create combined libraries
echo "Creating combined libraries..."
libtool -static -o libOCCT-ios.a occt-install-ios/lib/*.a
libtool -static -o libOCCT-sim.a occt-install-sim/lib/*.a
libtool -static -o libOCCT-macos.a occt-install-macos/lib/*.a

# Create XCFramework
echo "Creating XCFramework..."
rm -rf OCCT.xcframework
xcodebuild -create-xcframework \
    -library libOCCT-ios.a -headers occt-install-ios/include \
    -library libOCCT-sim.a -headers occt-install-sim/include \
    -library libOCCT-macos.a -headers occt-install-macos/include \
    -output OCCT.xcframework

# Cleanup
rm -f libOCCT-ios.a libOCCT-sim.a libOCCT-macos.a

echo "Done! OCCT.xcframework created in $LIBRARIES_DIR"
```

Make executable:
```bash
chmod +x Scripts/build-occt.sh
```

## Alternative: Pre-built Binaries

If you don't want to build OCCT yourself:

1. **Open Cascade Commercial**: Contact sales@opencascade.com for pre-built iOS libraries
2. **Community Builds**: Check OCCT forum for community-provided builds
3. **Build Service**: Use GitHub Actions to build (see `.github/workflows/build-occt.yml`)
