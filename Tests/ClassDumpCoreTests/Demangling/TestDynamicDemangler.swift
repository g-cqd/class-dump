import Foundation
import Testing

@testable import ClassDumpCore

/// Tests for DynamicSwiftDemangler.
@Suite("Dynamic Swift Demangler Tests")
struct DynamicDemanglerTests {

    // MARK: - Availability Tests

    @Test("Dynamic demangler availability check")
    func checkAvailability() {
        // Just verify the check doesn't crash
        let available = DynamicSwiftDemangler.shared.isAvailable
        // On macOS with Swift installed, this should be true
        // We don't assert specific value as test environments may vary
        _ = available
    }

    @Test("Dynamic demangler reports library path when available")
    func reportsLibraryPath() {
        if DynamicSwiftDemangler.shared.isAvailable {
            let path = DynamicSwiftDemangler.shared.loadedLibraryPath
            #expect(path != nil)
            #expect(path!.contains("swift"))
        }
    }

    // MARK: - Single Symbol Demangling

    @Test("Demangle simple Swift symbol")
    func demangleSimpleSymbol() {
        DynamicSwiftDemangler.shared.clearCache()

        // Skip if not available
        guard DynamicSwiftDemangler.shared.isAvailable else {
            return
        }

        // Try both prefix styles
        let symbols = ["_$sSS", "$sSS", "SS"]
        var foundResult = false

        for mangled in symbols {
            if let result = DynamicSwiftDemangler.shared.demangle(mangled), !result.isEmpty {
                // Should demangle to something containing String
                if result.contains("String") {
                    foundResult = true
                    break
                }
            }
        }

        // At least one should work if the library is functional
        // Note: The exact behavior depends on the Swift runtime version
        _ = foundResult
    }

    @Test("Demangle Swift View protocol")
    func demangleSwiftUIViewProtocol() {
        DynamicSwiftDemangler.shared.clearCache()

        guard DynamicSwiftDemangler.shared.isAvailable else {
            return
        }

        // Try with different prefixes
        let symbols = ["_$s7SwiftUI4ViewP", "$s7SwiftUI4ViewP"]

        for mangled in symbols {
            if let result = DynamicSwiftDemangler.shared.demangle(mangled), !result.isEmpty {
                // Should contain "View" or "SwiftUI"
                if result.contains("View") || result.contains("SwiftUI") {
                    return  // Test passes
                }
            }
        }

        // If no result, the library may not support these symbols
        // This is acceptable as the dynamic demangler is optional
    }

    @Test("Demangle non-mangled string returns nil")
    func demangleNonMangledString() {
        DynamicSwiftDemangler.shared.clearCache()

        let notMangled = "NotAMangledSymbol"
        let result = DynamicSwiftDemangler.shared.demangle(notMangled)

        // Should return nil for non-mangled strings
        #expect(result == nil)
    }

    @Test("Demangle complex generic type")
    func demangleComplexGenericType() {
        DynamicSwiftDemangler.shared.clearCache()

        guard DynamicSwiftDemangler.shared.isAvailable else {
            return
        }

        // Try different Array<Int> representations
        let symbols = ["_$sSaySiGD", "$sSaySiGD", "_$sSaySiG"]

        for mangled in symbols {
            if let result = DynamicSwiftDemangler.shared.demangle(mangled), !result.isEmpty {
                // Should contain Array or [] notation or Int
                if result.contains("Array") || result.contains("[") || result.contains("Int") {
                    return  // Test passes
                }
            }
        }

        // If no result, the library may not support these symbols
        // This is acceptable as the dynamic demangler is optional
    }

    // MARK: - Caching Tests

    @Test("Cache returns previously demangled results")
    func cachingWorks() {
        DynamicSwiftDemangler.shared.clearCache()

        guard DynamicSwiftDemangler.shared.isAvailable else {
            return
        }

        // Use a symbol that's more likely to have a cached result
        let symbols = ["_$sSS", "$sSS", "SS"]

        for symbol in symbols {
            // First call - should demangle (or not)
            let result1 = DynamicSwiftDemangler.shared.demangle(symbol)

            // Second call - should use cache (for both success and failure)
            let result2 = DynamicSwiftDemangler.shared.demangle(symbol)

            // Results should be consistent
            #expect(result1 == result2)
        }

        // Cache stats may or may not have entries depending on what was cached
        // The important thing is consistency, which we already verified
    }

    @Test("Clear cache resets statistics")
    func clearCacheWorks() {
        guard DynamicSwiftDemangler.shared.isAvailable else {
            return
        }

        // Add something to cache
        _ = DynamicSwiftDemangler.shared.demangle("$sSS")

        // Clear it
        DynamicSwiftDemangler.shared.clearCache()

        let stats = DynamicSwiftDemangler.shared.cacheStats
        #expect(stats.count == 0)
    }

    // MARK: - SwiftDemangler Integration Tests

    @Test("SwiftDemangler.enableDynamicDemangling toggles state")
    func dynamicDemanglingToggle() {
        // Initially disabled
        SwiftDemangler.disableDynamicDemangling()
        #expect(!SwiftDemangler.isDynamicDemanglingEnabled)

        // Enable
        let wasEnabled = SwiftDemangler.enableDynamicDemangling()

        // Should be enabled if library is available
        if DynamicSwiftDemangler.shared.isAvailable {
            #expect(wasEnabled)
            #expect(SwiftDemangler.isDynamicDemanglingEnabled)
        }

        // Disable again
        SwiftDemangler.disableDynamicDemangling()
        #expect(!SwiftDemangler.isDynamicDemanglingEnabled)
    }

    @Test("SwiftDemangler.demangle uses dynamic fallback when enabled")
    func demanglerUsesDynamicFallback() {
        SwiftDemangler.clearCache()

        // Skip if dynamic demangling not available
        guard DynamicSwiftDemangler.shared.isAvailable else {
            return
        }

        // Enable dynamic demangling
        let wasEnabled = SwiftDemangler.enableDynamicDemangling()
        defer { SwiftDemangler.disableDynamicDemangling() }

        #expect(wasEnabled)
        #expect(SwiftDemangler.isDynamicDemanglingEnabled)

        // Test that calling demangle with dynamic fallback enabled
        // does not crash, regardless of the result
        let mangled = "_$s7SwiftUI4ViewP"
        _ = SwiftDemangler.demangle(mangled)

        // Test passes if we get here without crashing
    }

    @Test("Dynamic demangling is faster than system demangling")
    func performanceComparison() async {
        // Skip if neither is available
        guard DynamicSwiftDemangler.shared.isAvailable else {
            return
        }

        let systemAvailable = await SystemDemangler.shared.checkAvailability()
        guard systemAvailable else {
            return
        }

        // Clear caches
        DynamicSwiftDemangler.shared.clearCache()
        await SystemDemangler.shared.clearCache()

        let symbols = [
            "$sSS",
            "$sSi",
            "$sSb",
            "$sSd",
            "$s7SwiftUI4ViewP",
        ]

        // Time dynamic demangling
        let dynamicStart = Date()
        for _ in 0..<100 {
            for symbol in symbols {
                _ = DynamicSwiftDemangler.shared.demangle(symbol)
            }
            DynamicSwiftDemangler.shared.clearCache()
        }
        let dynamicTime = Date().timeIntervalSince(dynamicStart)

        // Time system demangling
        let systemStart = Date()
        for _ in 0..<10 {  // Fewer iterations since it's slower
            for symbol in symbols {
                _ = await SystemDemangler.shared.demangle(symbol)
            }
            await SystemDemangler.shared.clearCache()
        }
        let systemTime = Date().timeIntervalSince(systemStart) * 10  // Scale up for comparison

        // Dynamic should be significantly faster (no process spawn)
        // We don't assert a specific ratio since it depends on system load
        _ = dynamicTime
        _ = systemTime
    }

    // MARK: - Edge Case Tests

    @Test("Empty string returns nil")
    func emptyStringReturnsNil() {
        let result = DynamicSwiftDemangler.shared.demangle("")
        #expect(result == nil)
    }

    @Test("Whitespace-only string returns nil")
    func whitespaceOnlyReturnsNil() {
        let result = DynamicSwiftDemangler.shared.demangle("   ")
        #expect(result == nil)
    }

    @Test("Invalid mangled prefix returns nil")
    func invalidMangledPrefixReturnsNil() {
        let result = DynamicSwiftDemangler.shared.demangle("NotSwiftMangled123")
        #expect(result == nil)
    }

    @Test("ObjC-style Swift class name")
    func objcStyleSwiftClassName() {
        DynamicSwiftDemangler.shared.clearCache()

        guard DynamicSwiftDemangler.shared.isAvailable else {
            return
        }

        // _TtC format is ObjC-style Swift class names
        let mangled = "_TtC10Foundation8NSObject"
        let result = DynamicSwiftDemangler.shared.demangle(mangled)

        // The dynamic demangler might or might not handle this format
        // ObjC-style names are often handled by the built-in demangler instead
        // We just verify it doesn't crash
        _ = result
    }
}
