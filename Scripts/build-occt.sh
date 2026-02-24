#!/bin/bash
#
# Build OpenCASCADE for iOS and macOS
#
# Usage: ./build-occt.sh
#
# This script downloads OCCT source and builds it as static libraries
# for iOS (arm64), iOS Simulator (arm64), and macOS (arm64).
# The result is an XCFramework at Libraries/OCCT.xcframework.
#
# Prerequisites:
#   - Xcode 15+ with Command Line Tools
#   - CMake 3.20+ (brew install cmake)
#   - ~10GB free disk space
#
# Build time: ~30-60 minutes depending on hardware
#

set -e

OCCT_VERSION="8.0.0"
OCCT_RC="rc4"
# RC tags use format V8_0_0_rc3, release uses V8_0_0
if [ -n "$OCCT_RC" ]; then
    OCCT_TAG="V${OCCT_VERSION//./_}_${OCCT_RC}"
else
    OCCT_TAG="V${OCCT_VERSION//./_}"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LIBRARIES_DIR="$PROJECT_DIR/Libraries"

# Parallelism
JOBS=$(sysctl -n hw.ncpu)

# SDK paths
IOS_SDK=$(xcrun --sdk iphoneos --show-sdk-path)
SIM_SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
MACOS_SDK=$(xcrun --sdk macosx --show-sdk-path)

# Compiler
CC=$(xcrun --find clang)
CXX=$(xcrun --find clang++)

echo "========================================"
echo "Building OCCT $OCCT_VERSION for iOS/macOS"
echo "========================================"
echo "Project directory: $PROJECT_DIR"
echo "Libraries directory: $LIBRARIES_DIR"
echo "Parallel jobs: $JOBS"
echo "iOS SDK: $IOS_SDK"
echo "Simulator SDK: $SIM_SDK"
echo "macOS SDK: $MACOS_SDK"
echo ""

cd "$LIBRARIES_DIR"

# --------------------
# Download OCCT source
# --------------------

if [ ! -d "occt-src" ]; then
    echo ">>> Downloading OCCT source..."
    # Use GitHub for RCs (faster, has latest tags), official repo for releases
    if [ -n "$OCCT_RC" ]; then
        git clone --depth 1 --branch "$OCCT_TAG" \
            https://github.com/Open-Cascade-SAS/OCCT.git occt-src
    else
        git clone --depth 1 --branch "$OCCT_TAG" \
            https://git.dev.opencascade.org/repos/occt.git occt-src
    fi
else
    echo ">>> OCCT source already exists, skipping download"
fi

# --------------------
# Common CMake options (minimal build for modeling + export)
# --------------------

CMAKE_COMMON_OPTS=(
    -DBUILD_LIBRARY_TYPE=Static
    -DBUILD_MODULE_ApplicationFramework=OFF
    -DBUILD_MODULE_DataExchange=ON
    -DBUILD_MODULE_Draw=OFF
    -DBUILD_MODULE_FoundationClasses=ON
    -DBUILD_MODULE_ModelingAlgorithms=ON
    -DBUILD_MODULE_ModelingData=ON
    -DBUILD_MODULE_Visualization=OFF
    -DBUILD_SAMPLES_QT=OFF
    -DBUILD_DOC_Overview=OFF
    -DBUILD_PATCH=OFF
    -DUSE_FREETYPE=OFF
    -DUSE_FREEIMAGE=OFF
    -DUSE_RAPIDJSON=OFF
    -DUSE_TBB=OFF
    -DUSE_VTK=OFF
    -DUSE_OPENGL=OFF
    -DUSE_GLES2=OFF
    -DUSE_D3D=OFF
    -DUSE_DRACO=OFF
    -DUSE_FFMPEG=OFF
    -DUSE_OPENVR=OFF
    -DUSE_XLIB=OFF
    -DUSE_TCL=OFF
    -DINSTALL_SAMPLES=OFF
    -DINSTALL_TEST_CASES=OFF
    -DINSTALL_DOC_Overview=OFF
    -DCMAKE_CXX_STANDARD=17
)

# --------------------
# Build for iOS Device using Unix Makefiles
# --------------------

echo ""
echo ">>> Building for iOS (arm64)..."
rm -rf occt-build-ios
mkdir -p occt-build-ios
cd occt-build-ios

# iOS-specific flags
IOS_FLAGS="-arch arm64 -isysroot $IOS_SDK -miphoneos-version-min=15.0 -fembed-bitcode-marker"

cmake ../occt-src \
    -G "Unix Makefiles" \
    "${CMAKE_COMMON_OPTS[@]}" \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT="$IOS_SDK" \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
    -DCMAKE_C_COMPILER="$CC" \
    -DCMAKE_CXX_COMPILER="$CXX" \
    -DCMAKE_C_FLAGS="$IOS_FLAGS" \
    -DCMAKE_CXX_FLAGS="$IOS_FLAGS" \
    -DCMAKE_C_COMPILER_WORKS=TRUE \
    -DCMAKE_CXX_COMPILER_WORKS=TRUE \
    -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=../occt-install-ios

# Build libraries (ignore executable link failures - we only need static libs)
cmake --build . --parallel "$JOBS" || true
cmake --install . || true
cd ..

# --------------------
# Build for iOS Simulator
# --------------------

echo ""
echo ">>> Building for iOS Simulator (arm64)..."
rm -rf occt-build-sim
mkdir -p occt-build-sim
cd occt-build-sim

# Simulator-specific flags
SIM_FLAGS="-arch arm64 -isysroot $SIM_SDK -miphonesimulator-version-min=15.0"

cmake ../occt-src \
    -G "Unix Makefiles" \
    "${CMAKE_COMMON_OPTS[@]}" \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT="$SIM_SDK" \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
    -DCMAKE_C_COMPILER="$CC" \
    -DCMAKE_CXX_COMPILER="$CXX" \
    -DCMAKE_C_FLAGS="$SIM_FLAGS" \
    -DCMAKE_CXX_FLAGS="$SIM_FLAGS" \
    -DCMAKE_C_COMPILER_WORKS=TRUE \
    -DCMAKE_CXX_COMPILER_WORKS=TRUE \
    -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=../occt-install-sim

# Build libraries (ignore executable link failures - we only need static libs)
cmake --build . --parallel "$JOBS" || true
cmake --install . || true
cd ..

# --------------------
# Build for macOS
# --------------------

echo ""
echo ">>> Building for macOS (arm64)..."
rm -rf occt-build-macos
mkdir -p occt-build-macos
cd occt-build-macos

# macOS-specific flags
MACOS_FLAGS="-arch arm64 -isysroot $MACOS_SDK -mmacosx-version-min=12.0"

cmake ../occt-src \
    -G "Unix Makefiles" \
    "${CMAKE_COMMON_OPTS[@]}" \
    -DCMAKE_OSX_SYSROOT="$MACOS_SDK" \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 \
    -DCMAKE_C_COMPILER="$CC" \
    -DCMAKE_CXX_COMPILER="$CXX" \
    -DCMAKE_C_FLAGS="$MACOS_FLAGS" \
    -DCMAKE_CXX_FLAGS="$MACOS_FLAGS" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=../occt-install-macos

# Build libraries (ignore executable link failures - we only need static libs)
cmake --build . --parallel "$JOBS" || true
cmake --install . || true
cd ..

# --------------------
# Create combined libraries
# --------------------

echo ""
echo ">>> Creating combined static libraries..."

# Find all .a files and combine them
libtool -static -o libOCCT-ios.a occt-install-ios/lib/*.a 2>/dev/null || \
libtool -static -o libOCCT-ios.a $(find occt-install-ios -name "*.a")

libtool -static -o libOCCT-sim.a occt-install-sim/lib/*.a 2>/dev/null || \
libtool -static -o libOCCT-sim.a $(find occt-install-sim -name "*.a")

libtool -static -o libOCCT-macos.a occt-install-macos/lib/*.a 2>/dev/null || \
libtool -static -o libOCCT-macos.a $(find occt-install-macos -name "*.a")

# --------------------
# Prepare headers
# --------------------

echo ""
echo ">>> Preparing headers..."

# Copy headers to a clean location
rm -rf occt-headers
mkdir -p occt-headers
if [ -d "occt-install-ios/include/opencascade" ]; then
    cp -R occt-install-ios/include/opencascade/* occt-headers/
else
    cp -R occt-install-ios/include/* occt-headers/
fi

# --------------------
# Create XCFramework
# --------------------

echo ""
echo ">>> Creating XCFramework..."

rm -rf OCCT.xcframework

xcodebuild -create-xcframework \
    -library libOCCT-ios.a -headers occt-headers \
    -library libOCCT-sim.a -headers occt-headers \
    -library libOCCT-macos.a -headers occt-headers \
    -output OCCT.xcframework

# --------------------
# Cleanup
# --------------------

echo ""
echo ">>> Cleaning up temporary files..."

rm -f libOCCT-ios.a libOCCT-sim.a libOCCT-macos.a
rm -rf occt-headers

# Optionally remove build directories (uncomment to save space)
# rm -rf occt-build-ios occt-build-sim occt-build-macos
# rm -rf occt-install-ios occt-install-sim occt-install-macos
# rm -rf occt-src

# --------------------
# Summary
# --------------------

echo ""
echo "========================================"
echo "Build complete!"
echo "========================================"
echo ""
echo "XCFramework created at:"
echo "  $LIBRARIES_DIR/OCCT.xcframework"
echo ""
echo "Contents:"
ls -la OCCT.xcframework/
echo ""
echo "To use in your project:"
echo "  1. Add OCCTSwift as a Swift Package dependency"
echo "  2. Or drag OCCT.xcframework into your Xcode project"
echo ""
