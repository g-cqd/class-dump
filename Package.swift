// swift-tools-version: 6.0
import PackageDescription

let swiftSettings: [SwiftSetting] = [
  .enableExperimentalFeature("StrictConcurrency"),
  .unsafeFlags(["-require-explicit-sendable"]),
]

let package = Package(
  name: "class-dump",
  platforms: [.macOS(.v15)],
  products: [
    .library(name: "ClassDumpCore", targets: ["ClassDumpCore"]),
    .executable(name: "class-dump", targets: ["ClassDumpCLI"]),
    .executable(name: "deprotect", targets: ["DeprotectCLI"]),
    .executable(name: "formatType", targets: ["FormatTypeCLI"]),
  ],
  targets: [
    .target(
      name: "ClassDumpCore",
      swiftSettings: swiftSettings
    ),
    .executableTarget(
      name: "ClassDumpCLI",
      dependencies: ["ClassDumpCore"],
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
  ],
  swiftLanguageVersions: [.v6]
)
