// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import Foundation

// Check if OCCT.xcframework exists
let occtFrameworkPath = "Libraries/OCCT.xcframework"
let occtExists = FileManager.default.fileExists(atPath: occtFrameworkPath)

// Build target list based on whether OCCT is available
var targets: [Target] = [
    // Swift API layer - public interface
    .target(
        name: "OCCTSwift",
        dependencies: ["OCCTBridge"],
        path: "Sources/OCCTSwift",
        swiftSettings: [
            .swiftLanguageMode(.v6)
        ]
    ),

    // Tests
    .testTarget(
        name: "OCCTSwiftTests",
        dependencies: ["OCCTSwift"],
        path: "Tests/OCCTSwiftTests"
    ),
]

// OCCTBridge configuration depends on whether OCCT is built
if occtExists {
    // Full configuration with OCCT library
    targets.append(
        .target(
            name: "OCCTBridge",
            dependencies: ["OCCT"],
            path: "Sources/OCCTBridge",
            sources: ["src"],
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("../../Libraries/OCCT.xcframework/Headers"),
                .define("OCCT_AVAILABLE", to: "1"),
                .unsafeFlags(["-std=c++17"])
            ],
            linkerSettings: [
                .linkedLibrary("c++")
            ]
        )
    )
    targets.append(
        .binaryTarget(
            name: "OCCT",
            path: "Libraries/OCCT.xcframework"
        )
    )
} else {
    // Stub configuration - OCCT not yet built
    // Bridge compiles but operations return empty/null results
    targets.append(
        .target(
            name: "OCCTBridge",
            path: "Sources/OCCTBridge",
            sources: ["src"],
            publicHeadersPath: "include",
            cxxSettings: [
                .define("OCCT_AVAILABLE", to: "0"),
                .unsafeFlags(["-std=c++17"])
            ],
            linkerSettings: [
                .linkedLibrary("c++")
            ]
        )
    )
}

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
    targets: targets,
    cxxLanguageStandard: .cxx17
)
