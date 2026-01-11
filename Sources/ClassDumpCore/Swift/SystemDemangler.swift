// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

/// System demangler that shells out to `swift-demangle` for accurate demangling.
///
/// This provides higher-fidelity demangling than the built-in ``SwiftDemangler`` by using
/// the system's `swift-demangle` tool. Results are cached for performance.
///
/// ## Usage
///
/// ```swift
/// // Single symbol
/// let result = await SystemDemangler.shared.demangle("_$s7SwiftUI4ViewP")
/// // result: "SwiftUI.View"
///
/// // Batch demangling (more efficient)
/// let symbols = ["_$s7SwiftUI4ViewP", "_$sSS"]
/// let results = await SystemDemangler.shared.demangleBatch(symbols)
/// ```
///
/// ## Fallback Behavior
///
/// If `swift-demangle` is not available (e.g., no Xcode installed), the system demangler
/// falls back to the built-in ``SwiftDemangler`` implementation.
///
public actor SystemDemangler {
    /// Shared singleton instance.
    public static let shared = SystemDemangler()

    // MARK: - State

    /// Path to swift-demangle, resolved lazily.
    private var swiftDemanglePath: String?

    /// Whether we've attempted to locate swift-demangle.
    private var hasResolvedPath = false

    /// Whether system demangling is available.
    private var isAvailable = false

    /// Thread-safe cache for demangled results.
    ///
    /// Uses MutexCache with lock-scoped operations for atomicity across
    /// both actor-isolated and nonisolated access.
    private let cache = MutexCache<String, String>()

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Demangle a single symbol using the system demangler.
    ///
    /// - Parameter symbol: The mangled Swift symbol.
    /// - Returns: The demangled name, or the original if demangling fails.
    public func demangle(_ symbol: String) async -> String {
        // Check cache first (lock-scoped for atomicity)
        if let cached = cache.withLock({ $0[symbol] }) {
            return cached
        }

        // Ensure path is resolved
        await resolvePathIfNeeded()

        // If system demangler not available, use built-in
        guard isAvailable, let path = swiftDemanglePath else {
            let result = SwiftDemangler.demangle(symbol)
            cache.withLock { $0[symbol] = result }
            return result
        }

        // Call system demangler
        let result = await executeDemangler(path: path, symbols: [symbol]).first ?? symbol
        cache.withLock { $0[symbol] = result }
        return result
    }

    /// Demangle multiple symbols efficiently using batch processing.
    ///
    /// This is more efficient than calling ``demangle(_:)`` repeatedly because
    /// it makes a single call to `swift-demangle` with all symbols.
    ///
    /// - Parameter symbols: Array of mangled Swift symbols.
    /// - Returns: Array of demangled names in the same order as input.
    public func demangleBatch(_ symbols: [String]) async -> [String] {
        guard !symbols.isEmpty else { return [] }

        // Separate cached and uncached symbols (lock-scoped for atomicity)
        var results = [String](repeating: "", count: symbols.count)
        var uncachedIndices: [Int] = []
        var uncachedSymbols: [String] = []

        cache.withLock { dict in
            for (index, symbol) in symbols.enumerated() {
                if let cached = dict[symbol] {
                    results[index] = cached
                }
                else {
                    uncachedIndices.append(index)
                    uncachedSymbols.append(symbol)
                }
            }
        }

        // If all cached, return early
        if uncachedSymbols.isEmpty {
            return results
        }

        // Ensure path is resolved
        await resolvePathIfNeeded()

        // Demangle uncached symbols
        let demangled: [String]
        if isAvailable, let path = swiftDemanglePath {
            demangled = await executeDemangler(path: path, symbols: uncachedSymbols)
        }
        else {
            // Fall back to built-in demangler
            demangled = uncachedSymbols.map { SwiftDemangler.demangle($0) }
        }

        // Merge results and cache (lock-scoped for atomicity)
        cache.withLock { dict in
            for (i, index) in uncachedIndices.enumerated() {
                let result = i < demangled.count ? demangled[i] : uncachedSymbols[i]
                results[index] = result
                dict[uncachedSymbols[i]] = result
            }
        }

        return results
    }

    /// Check if system demangling is available.
    ///
    /// - Returns: `true` if `swift-demangle` was found.
    public func checkAvailability() async -> Bool {
        await resolvePathIfNeeded()
        return isAvailable
    }

    /// Clear the demangling cache.
    public func clearCache() {
        cache.clear()
    }

    /// Get cache statistics.
    public var cacheStats: (count: Int, description: String) {
        let count = cache.count
        return (count, "SystemDemangler cache: \(count) entries")
    }

    // MARK: - Path Resolution

    /// Resolve the path to swift-demangle if not already done.
    private func resolvePathIfNeeded() async {
        guard !hasResolvedPath else { return }
        hasResolvedPath = true

        // Try to find swift-demangle via xcrun
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            process.arguments = ["--find", "swift-demangle"]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice

            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                    !path.isEmpty
                {
                    swiftDemanglePath = path
                    isAvailable = true
                    return
                }
            }
        }
        catch {
            // xcrun failed, try common paths
        }

        // Try common paths as fallback
        let commonPaths = [
            "/usr/bin/swift-demangle",
            "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift-demangle",
        ]

        for path in commonPaths where FileManager.default.isExecutableFile(atPath: path) {
            swiftDemanglePath = path
            isAvailable = true
            return
        }

        // Not available
        isAvailable = false
    }

    // MARK: - Process Execution

    /// Execute swift-demangle with the given symbols.
    ///
    /// - Parameters:
    ///   - path: Path to swift-demangle executable.
    ///   - symbols: Symbols to demangle.
    /// - Returns: Demangled results in the same order as input.
    private func executeDemangler(path: String, symbols: [String]) async -> [String] {
        // swift-demangle reads from stdin (one symbol per line) and writes to stdout
        let input = symbols.joined(separator: "\n")

        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)

            let inputPipe = Pipe()
            let outputPipe = Pipe()

            process.standardInput = inputPipe
            process.standardOutput = outputPipe
            process.standardError = FileHandle.nullDevice

            try process.run()

            // Write input
            inputPipe.fileHandleForWriting.write(input.data(using: .utf8) ?? Data())
            inputPipe.fileHandleForWriting.closeFile()

            // Wait for completion with timeout using Task.sleep
            let startTime = Date()
            while process.isRunning {
                if Date().timeIntervalSince(startTime) > 5.0 {
                    process.terminate()
                    return symbols  // Timeout, return original
                }
                try? await Task.sleep(for: .milliseconds(10))
            }

            // Read output
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: outputData, encoding: .utf8) else {
                return symbols
            }

            // Parse results
            var results = output.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

            // Ensure we have the right number of results
            while results.count < symbols.count {
                results.append(symbols[results.count])
            }

            return Array(results.prefix(symbols.count))
        }
        catch {
            // Process failed, return original symbols
            return symbols
        }
    }
}

// MARK: - Convenience Extensions

extension SystemDemangler {
    /// Demangle a symbol synchronously using the built-in demangler only.
    ///
    /// This is useful when async context is not available.
    /// For best results, prefer the async ``demangle(_:)`` method.
    ///
    /// - Parameter symbol: The mangled Swift symbol.
    /// - Returns: The demangled name from the built-in demangler.
    public nonisolated func demangleSync(_ symbol: String) -> String {
        // Use lock-scoped access for thread-safe caching
        cache.withLock { dict in
            if let cached = dict[symbol] {
                return cached
            }
            let result = SwiftDemangler.demangle(symbol)
            dict[symbol] = result
            return result
        }
    }
}
