// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OCCTSwift",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "OCCTSwift",
            targets: ["OCCTSwift"]
        ),
    ],
    targets: [
        // Swift API layer - public interface
        .target(
            name: "OCCTSwift",
            dependencies: ["OCCTBridge"],
            path: "Sources/OCCTSwift",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),

        // Objective-C++ bridge to OCCT
        .target(
            name: "OCCTBridge",
            dependencies: ["OCCT"],
            path: "Sources/OCCTBridge",
            sources: ["src"],
            publicHeadersPath: "include",
            cxxSettings: [
                // Platform-specific header search paths for XCFramework
                .headerSearchPath("../../Libraries/OCCT.xcframework/macos-arm64/Headers", .when(platforms: [.macOS])),
                .headerSearchPath("../../Libraries/OCCT.xcframework/ios-arm64/Headers", .when(platforms: [.iOS])),
                .headerSearchPath("../../Libraries/OCCT.xcframework/ios-arm64-simulator/Headers", .when(platforms: [.iOS])),
                .define("OCCT_AVAILABLE", to: "1"),
                .unsafeFlags(["-std=c++17"])
            ],
            linkerSettings: [
                .linkedLibrary("c++")
            ]
        ),

        // OCCT binary framework (remote for SPM consumers)
        .binaryTarget(
            name: "OCCT",
            url: "https://github.com/gsdali/OCCTSwift/releases/download/v0.5.0/OCCT.xcframework.zip",
            checksum: "4f42d7854452946fb8e5141e654c84c2f3bdfcfebff703c143c7961ec340b7f7"
        ),

        // Tests
        .testTarget(
            name: "OCCTSwiftTests",
            dependencies: ["OCCTSwift"],
            path: "Tests/OCCTSwiftTests"
        ),

        // Test executable
        .executableTarget(
            name: "OCCTTest",
            dependencies: ["OCCTSwift"],
            path: "Sources/OCCTTest",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
    ],
    cxxLanguageStandard: .cxx17
)
