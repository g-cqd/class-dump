// swift-tools-version: 6.2
import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
    .unsafeFlags(["-require-explicit-sendable"]),
]

let package = Package(
    name: "class-dump",
    defaultLocalization: "en",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "ClassDumpCore", targets: ["ClassDumpCore"]),
        .executable(name: "class-dump", targets: ["ClassDumpCLI"]),
        .executable(name: "deprotect", targets: ["DeprotectCLI"]),
        .executable(name: "formatType", targets: ["FormatTypeCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0")
    ],
    targets: [
        .target(
            name: "ClassDumpCore",
            path: "Sources/ClassDumpCore",
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "ClassDumpCLI",
            dependencies: [
                "ClassDumpCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "DeprotectCLI",
            dependencies: ["ClassDumpCore"],
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "FormatTypeCLI",
            dependencies: ["ClassDumpCore"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "ClassDumpCoreTests",
            dependencies: ["ClassDumpCore"],
            swiftSettings: swiftSettings
        ),
    ],
    swiftLanguageVersions: [.v6]
)
