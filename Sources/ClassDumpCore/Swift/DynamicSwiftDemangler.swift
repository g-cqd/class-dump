// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

/// Dynamic Swift demangler that uses dlopen to load libswiftDemangle or libswiftCore.
///
/// This provides the highest fidelity demangling by using the same demangling code
/// that the Swift compiler uses, loaded dynamically at runtime.
///
/// ## Usage
///
/// ```swift
/// // Single symbol
/// if let result = DynamicSwiftDemangler.shared.demangle("$s7SwiftUI4ViewP") {
///     print(result)  // "SwiftUI.View"
/// }
///
/// // Check availability
/// if DynamicSwiftDemangler.shared.isAvailable {
///     // Use dynamic demangling
/// }
/// ```
///
/// ## Library Search Order
///
/// 1. libswiftDemangle.dylib (standalone demangler library)
/// 2. libswiftCore.dylib (Swift runtime, includes demangling)
///
/// ## Thread Safety
///
/// This class is thread-safe. The demangling function is stateless and can be
/// called concurrently from multiple threads.
///
public final class DynamicSwiftDemangler: @unchecked Sendable {
    /// Shared singleton instance.
    public static let shared = DynamicSwiftDemangler()

    // MARK: - Types

    /// Function signature for swift_demangle.
    ///
    /// ```c
    /// char *swift_demangle(const char *mangledName,
    ///                      size_t mangledNameLength,
    ///                      char *outputBuffer,
    ///                      size_t *outputBufferSize,
    ///                      uint32_t flags);
    /// ```
    private typealias SwiftDemangleFunc =
        @convention(c) (
            UnsafePointer<CChar>?,  // mangledName
            Int,  // mangledNameLength
            UnsafeMutablePointer<CChar>?,  // outputBuffer
            UnsafeMutablePointer<Int>?,  // outputBufferSize
            UInt32  // flags
        ) -> UnsafeMutablePointer<CChar>?

    // MARK: - State

    /// Handle to the loaded library.
    private var libraryHandle: UnsafeMutableRawPointer?

    /// Pointer to the swift_demangle function.
    private var demangleFunc: SwiftDemangleFunc?

    /// Whether we've attempted to load the library.
    private var hasAttemptedLoad = false

    /// Lock for thread-safe initialization.
    private let lock = NSLock()

    /// Cache for demangled results.
    private let cache = MutexCache<String, String>()

    // MARK: - Public API

    /// Whether dynamic demangling is available.
    ///
    /// This will attempt to load the library on first access.
    public var isAvailable: Bool {
        ensureLoaded()
        return demangleFunc != nil
    }

    /// The path to the loaded library, if available.
    public private(set) var loadedLibraryPath: String?

    /// Demangle a Swift symbol using the dynamic library.
    ///
    /// - Parameter mangledName: The mangled Swift symbol.
    /// - Returns: The demangled name, or `nil` if demangling failed or is unavailable.
    public func demangle(_ mangledName: String) -> String? {
        // Check cache first
        if let cached = cache.get(mangledName) {
            return cached == mangledName ? nil : cached
        }

        // Ensure library is loaded
        ensureLoaded()

        guard let demangleFunc = demangleFunc else {
            return nil
        }

        // Call the demangling function
        let result = mangledName.withCString { cString -> String? in
            // Call swift_demangle with:
            // - mangledName: the input string
            // - mangledNameLength: length of input (0 means null-terminated)
            // - outputBuffer: nil (let it allocate)
            // - outputBufferSize: nil
            // - flags: 0
            guard let resultPtr = demangleFunc(cString, 0, nil, nil, 0) else {
                return nil
            }

            // Convert to Swift string
            let resultString = String(cString: resultPtr)

            // Free the allocated memory
            free(resultPtr)

            // Don't return if it's the same as input (wasn't demangled)
            if resultString == mangledName {
                return nil
            }

            return resultString
        }

        // Cache the result
        cache.set(mangledName, value: result ?? mangledName)

        return result
    }

    /// Clear the demangling cache.
    public func clearCache() {
        cache.clear()
    }

    /// Get cache statistics.
    public var cacheStats: (count: Int, description: String) {
        let count = cache.count
        return (count, "DynamicSwiftDemangler cache: \(count) entries")
    }

    // MARK: - Library Loading

    /// Ensure the library is loaded (thread-safe).
    private func ensureLoaded() {
        lock.lock()
        defer { lock.unlock() }

        guard !hasAttemptedLoad else { return }
        hasAttemptedLoad = true

        loadLibrary()
    }

    /// Attempt to load the Swift demangling library.
    private func loadLibrary() {
        // Library search paths in order of preference
        let libraryPaths = [
            // Standalone demangler (if available)
            "/usr/lib/swift/libswiftDemangle.dylib",
            // Swift runtime (includes demangling)
            "/usr/lib/swift/libswiftCore.dylib",
            // Xcode toolchain paths
            xcodeDeveloperPath()
                .map { "\($0)/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/macosx/libswiftDemangle.dylib" },
            xcodeDeveloperPath()
                .map { "\($0)/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/macosx/libswiftCore.dylib" },
            // Command Line Tools paths
            "/Library/Developer/CommandLineTools/usr/lib/swift/macosx/libswiftDemangle.dylib",
            "/Library/Developer/CommandLineTools/usr/lib/swift/macosx/libswiftCore.dylib",
        ]
        .compactMap { $0 }

        for path in libraryPaths {
            if let handle = dlopen(path, RTLD_LAZY | RTLD_LOCAL) {
                // Look for swift_demangle symbol
                if let funcPtr = dlsym(handle, "swift_demangle") {
                    libraryHandle = handle
                    loadedLibraryPath = path
                    demangleFunc = unsafeBitCast(funcPtr, to: SwiftDemangleFunc.self)
                    return
                }

                // Symbol not found, close handle and try next
                dlclose(handle)
            }
        }

        // Also try loading without explicit path (uses system search)
        if let handle = dlopen("libswiftCore.dylib", RTLD_LAZY | RTLD_LOCAL) {
            if let funcPtr = dlsym(handle, "swift_demangle") {
                libraryHandle = handle
                loadedLibraryPath = "libswiftCore.dylib (system)"
                demangleFunc = unsafeBitCast(funcPtr, to: SwiftDemangleFunc.self)
                return
            }
            dlclose(handle)
        }
    }

    /// Get the Xcode developer directory path.
    private func xcodeDeveloperPath() -> String? {
        // Try xcode-select first
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcode-select")
        process.arguments = ["-p"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                    !path.isEmpty
                {
                    return path
                }
            }
        }
        catch {
            // Fall through to default
        }

        // Default Xcode path
        let defaultPath = "/Applications/Xcode.app/Contents/Developer"
        if FileManager.default.fileExists(atPath: defaultPath) {
            return defaultPath
        }

        return nil
    }

    // MARK: - Initialization

    private init() {}

    deinit {
        if let handle = libraryHandle {
            dlclose(handle)
        }
    }
}
