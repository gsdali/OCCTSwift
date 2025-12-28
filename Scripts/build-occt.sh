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

OCCT_VERSION="7.8.1"
OCCT_TAG="V${OCCT_VERSION//./_}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LIBRARIES_DIR="$PROJECT_DIR/Libraries"

# Parallelism
JOBS=$(sysctl -n hw.ncpu)

echo "========================================"
echo "Building OCCT $OCCT_VERSION for iOS/macOS"
echo "========================================"
echo "Project directory: $PROJECT_DIR"
echo "Libraries directory: $LIBRARIES_DIR"
echo "Parallel jobs: $JOBS"
echo ""

cd "$LIBRARIES_DIR"

# --------------------
# Download OCCT source
# --------------------

if [ ! -d "occt-src" ]; then
    echo ">>> Downloading OCCT source..."
    git clone --depth 1 --branch "$OCCT_TAG" \
        https://git.dev.opencascade.org/repos/occt.git occt-src
else
    echo ">>> OCCT source already exists, skipping download"
fi

# --------------------
# Common CMake options
# --------------------

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
    -DCMAKE_CXX_STANDARD=17
)

# --------------------
# Build for iOS Device
# --------------------

echo ""
echo ">>> Building for iOS (arm64)..."
mkdir -p occt-build-ios
cd occt-build-ios

cmake ../occt-src \
    "${CMAKE_COMMON_OPTS[@]}" \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_SYSROOT="$(xcrun --sdk iphoneos --show-sdk-path)" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
    -DCMAKE_INSTALL_PREFIX=../occt-install-ios

cmake --build . --config Release --parallel "$JOBS"
cmake --install .
cd ..

# --------------------
# Build for iOS Simulator
# --------------------

echo ""
echo ">>> Building for iOS Simulator (arm64)..."
mkdir -p occt-build-sim
cd occt-build-sim

cmake ../occt-src \
    "${CMAKE_COMMON_OPTS[@]}" \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_SYSROOT="$(xcrun --sdk iphonesimulator --show-sdk-path)" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
    -DCMAKE_INSTALL_PREFIX=../occt-install-sim

cmake --build . --config Release --parallel "$JOBS"
cmake --install .
cd ..

# --------------------
# Build for macOS
# --------------------

echo ""
echo ">>> Building for macOS (arm64)..."
mkdir -p occt-build-macos
cd occt-build-macos

cmake ../occt-src \
    "${CMAKE_COMMON_OPTS[@]}" \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 \
    -DCMAKE_INSTALL_PREFIX=../occt-install-macos

cmake --build . --config Release --parallel "$JOBS"
cmake --install .
cd ..

# --------------------
# Create combined libraries
# --------------------

echo ""
echo ">>> Creating combined static libraries..."

libtool -static -o libOCCT-ios.a occt-install-ios/lib/*.a
libtool -static -o libOCCT-sim.a occt-install-sim/lib/*.a
libtool -static -o libOCCT-macos.a occt-install-macos/lib/*.a

# --------------------
# Create XCFramework
# --------------------

echo ""
echo ">>> Creating XCFramework..."

rm -rf OCCT.xcframework

xcodebuild -create-xcframework \
    -library libOCCT-ios.a -headers occt-install-ios/include \
    -library libOCCT-sim.a -headers occt-install-sim/include \
    -library libOCCT-macos.a -headers occt-install-macos/include \
    -output OCCT.xcframework

# --------------------
# Cleanup
# --------------------

echo ""
echo ">>> Cleaning up temporary files..."

rm -f libOCCT-ios.a libOCCT-sim.a libOCCT-macos.a

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
