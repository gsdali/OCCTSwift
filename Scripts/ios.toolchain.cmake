# iOS Toolchain for OCCT
# Based on standard CMake iOS toolchain settings

set(CMAKE_SYSTEM_NAME iOS)
set(CMAKE_SYSTEM_PROCESSOR arm64)

# Find the iOS SDK
execute_process(
    COMMAND xcrun --sdk iphoneos --show-sdk-path
    OUTPUT_VARIABLE CMAKE_OSX_SYSROOT
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

set(CMAKE_OSX_ARCHITECTURES arm64)
set(CMAKE_OSX_DEPLOYMENT_TARGET 15.0)

# Force static libraries
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)

# Compiler flags for iOS
set(CMAKE_C_FLAGS_INIT "-fembed-bitcode-marker")
set(CMAKE_CXX_FLAGS_INIT "-fembed-bitcode-marker")

# Ensure we find the right compilers
set(CMAKE_C_COMPILER_WORKS TRUE)
set(CMAKE_CXX_COMPILER_WORKS TRUE)

# Skip try_compile for cross-compilation
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

# iOS-specific settings
set(CMAKE_MACOSX_BUNDLE NO)
set(CMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH NO)

# Link against iOS frameworks
set(CMAKE_EXE_LINKER_FLAGS "-framework Foundation -framework CoreFoundation")
