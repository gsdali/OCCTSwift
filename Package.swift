// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import Foundation

// Use local xcframework when developing (repo checkout), remote URL when consumed as a dependency.
// Set OCCTSWIFT_LOCAL=1 to force local path, or OCCTSWIFT_REMOTE=1 to force remote URL.
let useLocalBinary: Bool = {
    if ProcessInfo.processInfo.environment["OCCTSWIFT_REMOTE"] == "1" { return false }
    if ProcessInfo.processInfo.environment["OCCTSWIFT_LOCAL"] == "1" { return true }
    // Auto-detect: use local if Libraries/OCCT.xcframework exists
    return FileManager.default.fileExists(atPath: "Libraries/OCCT.xcframework/Info.plist")
}()

let occtTarget: Target = useLocalBinary
    ? .binaryTarget(
        name: "OCCT",
        path: "Libraries/OCCT.xcframework"
    )
    : .binaryTarget(
        name: "OCCT",
        url: "https://github.com/gsdali/OCCTSwift/releases/download/v0.167.0/OCCT.xcframework.zip",
        checksum: "5147b7d65cd9af5a6c3af1b38a1492365e645ed5c76a663bf9311c2f54043d87"
    )

let package = Package(
    name: "OCCTSwift",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .visionOS(.v1),
        .tvOS(.v15)
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
                .headerSearchPath("../../Libraries/OCCT.xcframework/xros-arm64/Headers", .when(platforms: [.visionOS])),
                .headerSearchPath("../../Libraries/OCCT.xcframework/xros-arm64-simulator/Headers", .when(platforms: [.visionOS])),
                .headerSearchPath("../../Libraries/OCCT.xcframework/tvos-arm64/Headers", .when(platforms: [.tvOS])),
                .headerSearchPath("../../Libraries/OCCT.xcframework/tvos-arm64-simulator/Headers", .when(platforms: [.tvOS])),
                .define("OCCT_AVAILABLE", to: "1")
            ],
            linkerSettings: [
                .linkedLibrary("c++")
            ]
        ),

        // OCCT binary framework - auto-selects local or remote
        occtTarget,

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
