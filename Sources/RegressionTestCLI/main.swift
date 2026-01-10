import ArgumentParser
import Foundation

/// Regression testing tool for class-dump.
///
/// Compares output from an old version of class-dump with the current version
/// against system frameworks and applications to detect regressions.
@main
struct RegressionTestCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "regression-test",
        abstract: "Regression testing tool for class-dump.",
        discussion: """
            Compares output from a reference version of class-dump with the current version
            against system frameworks and applications to detect regressions.

            Examples:
              regression-test --reference ~/bin/class-dump-3.5
              regression-test --reference ~/bin/class-dump-3.5 --ios
              regression-test --reference ~/bin/class-dump-3.5 --sdk iphoneos
            """,
        version: "4.0.3 (Swift)"
    )

    // MARK: - Required Options

    @Option(name: .long, help: "Path to the reference (old) class-dump binary")
    var reference: String

    @Option(name: .long, help: "Path to the new class-dump binary (defaults to 'class-dump' in PATH)")
    var current: String = "class-dump"

    // MARK: - Target Options

    @Flag(name: .long, help: "Test iOS targets instead of macOS")
    var ios: Bool = false

    @Option(name: .long, help: "Specify an SDK to use (e.g., iphoneos, macosx)")
    var sdk: String?

    // MARK: - Output Options

    @Option(name: .shortAndLong, help: "Output directory for test results")
    var output: String = "/tmp/class-dump-regression"

    @Flag(name: .long, help: "Open diff tool after testing (requires Kaleidoscope)")
    var diff: Bool = false

    @Flag(name: .long, help: "List available SDKs and exit")
    var showSdks: Bool = false

    @Flag(name: .long, help: "Verbose output")
    var verbose: Bool = false

    // MARK: - Filter Options

    @Option(name: .long, help: "Only test targets matching this pattern")
    var filter: String?

    @Option(name: .long, help: "Maximum number of targets to test (useful for quick checks)")
    var limit: Int?

    mutating func run() async throws {
        if showSdks {
            try await listSdks()
            return
        }

        // Validate reference binary exists
        guard FileManager.default.fileExists(atPath: reference) else {
            throw RegressionTestError.binaryNotFound(reference)
        }

        // Find the current binary
        let currentPath = try await resolveBinaryPath(current)
        guard FileManager.default.fileExists(atPath: currentPath) else {
            throw RegressionTestError.binaryNotFound(currentPath)
        }

        print("╔══════════════════════════════════════════════════════════════════╗")
        print("║               class-dump Regression Test                         ║")
        print("╚══════════════════════════════════════════════════════════════════╝")
        print()
        print("Started at: \(Date().formatted())")
        print()
        print("Reference binary: \(reference)")
        print("Current binary:   \(currentPath)")
        print()

        // Get SDK root if needed
        let sdkRoot = try await resolveSDKRoot()
        if let sdkRoot {
            print("SDK root: \(sdkRoot)")
        }

        // Collect targets
        let targets = try await collectTargets(sdkRoot: sdkRoot)
        print()
        print("Found \(targets.frameworks.count) frameworks")
        print("Found \(targets.apps.count) applications")
        print("Found \(targets.bundles.count) bundles")
        print("Total: \(targets.total) targets")
        print()

        // Setup output directories
        let outputURL = URL(fileURLWithPath: output)
        let oldDir = outputURL.appendingPathComponent("reference")
        let newDir = outputURL.appendingPathComponent("current")

        try? FileManager.default.removeItem(at: outputURL)
        try FileManager.default.createDirectory(at: oldDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: newDir, withIntermediateDirectories: true)

        // Run tests
        var allTargets = targets.frameworks + targets.apps + targets.bundles
        if let filter {
            let regex = try Regex(filter)
            allTargets = allTargets.filter { $0.lastPathComponent.contains(regex) }
            print("Filtered to \(allTargets.count) targets matching '\(filter)'")
        }
        if let limit {
            allTargets = Array(allTargets.prefix(limit))
            print("Limited to \(allTargets.count) targets")
        }

        print()
        print("Running tests...")
        print()

        var tested = 0
        var errors = 0

        for target in allTargets {
            let result = try await testTarget(
                target,
                referenceBinary: reference,
                currentBinary: currentPath,
                sdkRoot: sdkRoot,
                referenceDir: oldDir,
                currentDir: newDir
            )
            tested += 1
            if !result.success {
                errors += 1
            }
            if verbose || !result.success {
                let status = result.success ? "✓" : "✗"
                print("\(status) \(target.lastPathComponent)")
                if !result.success, let error = result.error {
                    print("  Error: \(error)")
                }
            }
            else {
                // Progress indicator
                if tested % 10 == 0 {
                    print("  Tested \(tested)/\(allTargets.count)...")
                }
            }
        }

        print()
        print("════════════════════════════════════════════════════════════════════")
        print("Completed at: \(Date().formatted())")
        print("Tested: \(tested) targets")
        print("Errors: \(errors)")
        print()
        print("Results saved to:")
        print("  Reference: \(oldDir.path)")
        print("  Current:   \(newDir.path)")
        print()

        // Clean up files with no ObjC content
        try await cleanupEmptyResults(in: oldDir)
        try await cleanupEmptyResults(in: newDir)

        if diff {
            print("Opening diff tool...")
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-a", "Kaleidoscope", oldDir.path, newDir.path]
            try? process.run()
        }
        else {
            print("To compare results, run:")
            print("  diff -r '\(oldDir.path)' '\(newDir.path)'")
            print("  # or")
            print("  ksdiff '\(oldDir.path)' '\(newDir.path)'")
        }
    }

    // MARK: - Helper Methods

    private func listSdks() async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
        process.arguments = ["-showsdks"]
        try process.run()
        process.waitUntilExit()
    }

    private func resolveBinaryPath(_ path: String) async throws -> String {
        if path.hasPrefix("/") || path.hasPrefix(".") {
            return path
        }
        // Try to find in PATH
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [path]
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let result = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
            !result.isEmpty
        {
            return result
        }
        return path
    }

    private func resolveSDKRoot() async throws -> String? {
        if let sdk {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
            process.arguments = ["-version", "-sdk", sdk, "Path"]
            let pipe = Pipe()
            process.standardOutput = pipe
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let result = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                return result
            }
        }
        else if ios {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
            process.arguments = ["-version", "-sdk", "iphoneos", "Path"]
            let pipe = Pipe()
            process.standardOutput = pipe
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let result = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                return result
            }
        }
        return nil
    }

    private func collectTargets(sdkRoot: String?) async throws -> TargetCollection {
        var frameworks: [URL] = []
        var apps: [URL] = []
        var bundles: [URL] = []

        if let sdkRoot {
            // iOS SDK paths
            frameworks += globPaths("\(sdkRoot)/System/Library/Frameworks/*.framework")
            frameworks += globPaths("\(sdkRoot)/System/Library/PrivateFrameworks/*.framework")
        }
        else {
            // macOS paths
            frameworks += globPaths("/System/Library/Frameworks/*.framework")
            frameworks += globPaths("/System/Library/PrivateFrameworks/*.framework")

            apps += globPaths("/Applications/*.app")
            apps += globPaths("/Applications/*/*.app")
            apps += globPaths("/Applications/Utilities/*.app")
            apps += globPaths("/System/Library/CoreServices/*.app")

            bundles += globPaths("/System/Library/CoreServices/*.bundle")

            // Xcode paths
            if let developerRoot = try? await getDeveloperRoot() {
                frameworks += globPaths("\(developerRoot)/Library/Frameworks/*.framework")
                frameworks += globPaths("\(developerRoot)/Library/PrivateFrameworks/*.framework")
                frameworks += globPaths("\(developerRoot)/../Frameworks/*.framework")
                frameworks += globPaths("\(developerRoot)/../OtherFrameworks/*.framework")
                apps += globPaths("\(developerRoot)/../Applications/*.app")
                bundles += globPaths("\(developerRoot)/../Plugins/*.ideplugin")
            }
        }

        // Filter out known problematic apps
        apps = apps.filter { !$0.lastPathComponent.hasPrefix("Hopper") }

        return TargetCollection(
            frameworks: frameworks,
            apps: apps,
            bundles: bundles
        )
    }

    private func getDeveloperRoot() async throws -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcode-select")
        process.arguments = ["--print-path"]
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func globPaths(_ pattern: String) -> [URL] {
        let expandedPattern = NSString(string: pattern).expandingTildeInPath
        var gt = glob_t()
        defer { globfree(&gt) }

        let flags = GLOB_TILDE | GLOB_BRACE | GLOB_MARK
        guard Darwin.glob(expandedPattern, flags, nil, &gt) == 0 else {
            return []
        }

        var results: [URL] = []
        for i in 0..<Int(gt.gl_matchc) {
            if let path = gt.gl_pathv[i], let str = String(validatingCString: path) {
                let cleanPath = str.hasSuffix("/") ? String(str.dropLast()) : str
                results.append(URL(fileURLWithPath: cleanPath))
            }
        }
        return results
    }

    private func testTarget(
        _ target: URL,
        referenceBinary: String,
        currentBinary: String,
        sdkRoot: String?,
        referenceDir: URL,
        currentDir: URL
    ) async throws -> TestResult {
        let baseName = target.deletingPathExtension().lastPathComponent
        let ext = target.pathExtension

        // Get architectures
        let arches = try await getArchitectures(binary: currentBinary, target: target)

        var success = true
        var errorMessage: String?

        for arch in arches {
            let suffix = arch == "none" ? ext : "\(arch)-\(ext)"
            let refOutput = referenceDir.appendingPathComponent("\(baseName)-\(suffix).txt")
            let curOutput = currentDir.appendingPathComponent("\(baseName)-\(suffix).txt")

            // Run reference binary
            let refResult = try await runClassDump(
                binary: referenceBinary,
                target: target,
                arch: arch == "none" ? nil : arch,
                sdkRoot: nil,  // Old binary might not support --sdk-root
                output: refOutput
            )

            // Run current binary
            let curResult = try await runClassDump(
                binary: currentBinary,
                target: target,
                arch: arch == "none" ? nil : arch,
                sdkRoot: sdkRoot,
                output: curOutput
            )

            if !refResult || !curResult {
                success = false
                errorMessage = "Failed to run class-dump"
            }
        }

        return TestResult(success: success, error: errorMessage)
    }

    private func getArchitectures(binary: String, target: URL) async throws -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = ["--list-arches", target.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
            !output.isEmpty
        {
            return output.components(separatedBy: " ")
        }
        return ["none"]
    }

    private func runClassDump(
        binary: String,
        target: URL,
        arch: String?,
        sdkRoot: String?,
        output: URL
    ) async throws -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)

        var args = ["-s", "-t", target.path]
        if let arch {
            args.insert(contentsOf: ["--arch", arch], at: 0)
        }
        if let sdkRoot {
            args.append(contentsOf: ["--sdk-root", sdkRoot])
        }
        process.arguments = args

        FileManager.default.createFile(atPath: output.path, contents: nil)
        let fileHandle = try FileHandle(forWritingTo: output)
        process.standardOutput = fileHandle
        process.standardError = fileHandle

        try process.run()
        process.waitUntilExit()
        try fileHandle.close()

        return process.terminationStatus == 0
    }

    private func cleanupEmptyResults(in directory: URL) async throws {
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)

        for file in contents where file.pathExtension == "txt" {
            if let content = try? String(contentsOf: file, encoding: .utf8),
                content.contains("This file does not contain")
            {
                try? fm.removeItem(at: file)
            }
        }
    }
}

// MARK: - Supporting Types

struct TargetCollection: Sendable {
    let frameworks: [URL]
    let apps: [URL]
    let bundles: [URL]

    var total: Int {
        frameworks.count + apps.count + bundles.count
    }
}

struct TestResult: Sendable {
    let success: Bool
    let error: String?
}

enum RegressionTestError: Error, CustomStringConvertible {
    case binaryNotFound(String)
    case sdkNotFound(String)
    case testFailed(String)

    var description: String {
        switch self {
            case .binaryNotFound(let path):
                return "Binary not found: \(path)"
            case .sdkNotFound(let sdk):
                return "SDK not found: \(sdk)"
            case .testFailed(let reason):
                return "Test failed: \(reason)"
        }
    }
}
