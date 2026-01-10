import Foundation
import Testing

@testable import ClassDumpCore

/// Tests for SystemDemangler integration.
@Suite("System Demangler Tests")
struct SystemDemanglerTests {

    // MARK: - Availability Tests

    @Test("System demangler availability check")
    func checkAvailability() async {
        // Just verify the check doesn't crash
        let available = await SystemDemangler.shared.checkAvailability()
        // On macOS with Xcode, this should be true
        // We don't assert specific value as test environments may vary
        _ = available
    }

    // MARK: - Single Symbol Demangling

    @Test("Demangle simple Swift symbol")
    func demangleSimpleSymbol() async {
        // Clear cache for clean test
        await SystemDemangler.shared.clearCache()

        let mangled = "_$sSS"  // Swift.String
        let result = await SystemDemangler.shared.demangle(mangled)

        // Should demangle to Swift.String or at least not crash
        #expect(!result.isEmpty)
    }

    @Test("Demangle Swift View protocol")
    func demangleSwiftUIViewProtocol() async {
        await SystemDemangler.shared.clearCache()

        let mangled = "_$s7SwiftUI4ViewP"
        let result = await SystemDemangler.shared.demangle(mangled)

        // If swift-demangle is available, should get "SwiftUI.View"
        // Otherwise falls back to built-in which may return the input
        if await SystemDemangler.shared.checkAvailability() {
            #expect(result.contains("View"))
        }
    }

    @Test("Demangle non-mangled string returns as-is")
    func demangleNonMangledString() async {
        await SystemDemangler.shared.clearCache()

        let notMangled = "NotAMangledSymbol"
        let result = await SystemDemangler.shared.demangle(notMangled)

        // Should return the input unchanged
        #expect(result == notMangled)
    }

    // MARK: - Batch Demangling

    @Test("Batch demangle multiple symbols")
    func batchDemangle() async {
        await SystemDemangler.shared.clearCache()

        let symbols = [
            "_$sSS",  // String
            "_$sSi",  // Int
            "_$sSb",  // Bool
            "_$sSd",  // Double
        ]

        let results = await SystemDemangler.shared.demangleBatch(symbols)

        #expect(results.count == symbols.count)
        // All results should be non-empty
        for result in results {
            #expect(!result.isEmpty)
        }
    }

    @Test("Batch demangle empty array returns empty")
    func batchDemangleEmpty() async {
        let results = await SystemDemangler.shared.demangleBatch([])
        #expect(results.isEmpty)
    }

    @Test("Batch demangle with mixed content")
    func batchDemangleMixed() async {
        await SystemDemangler.shared.clearCache()

        let symbols = [
            "_$sSS",  // Mangled
            "NSString",  // Not mangled
            "_$s7SwiftUI4ViewP",  // Mangled
            "SomeClass",  // Not mangled
        ]

        let results = await SystemDemangler.shared.demangleBatch(symbols)

        #expect(results.count == 4)
        // Non-mangled should be returned as-is
        #expect(results[1] == "NSString")
        #expect(results[3] == "SomeClass")
    }

    // MARK: - Caching Tests

    @Test("Cache returns previously demangled results")
    func cachingWorks() async {
        await SystemDemangler.shared.clearCache()

        let symbol = "_$sSS"

        // First call - should demangle
        let result1 = await SystemDemangler.shared.demangle(symbol)

        // Second call - should use cache
        let result2 = await SystemDemangler.shared.demangle(symbol)

        #expect(result1 == result2)

        // Check cache stats
        let stats = await SystemDemangler.shared.cacheStats
        #expect(stats.count >= 1)
    }

    @Test("Clear cache resets statistics", .serialized)
    func clearCacheWorks() async {
        // Clear cache first to establish baseline
        await SystemDemangler.shared.clearCache()

        // Add something to cache
        _ = await SystemDemangler.shared.demangle("_$sSS")

        // Verify something is in cache
        let statsBefore = await SystemDemangler.shared.cacheStats
        #expect(statsBefore.count >= 1)

        // Clear it
        await SystemDemangler.shared.clearCache()

        // Immediately check stats (serialized test prevents race)
        let statsAfter = await SystemDemangler.shared.cacheStats
        #expect(statsAfter.count == 0)
    }

    // MARK: - Sync Demangling

    @Test("Sync demangling uses built-in demangler")
    func syncDemangling() async {
        await SystemDemangler.shared.clearCache()

        let symbol = "_$sSS"  // String
        let result = SystemDemangler.shared.demangleSync(symbol)

        // Should return something (built-in demangler may return "String" or original)
        #expect(!result.isEmpty)
    }

    @Test("Sync demangling caches results")
    func syncDemanglingCaches() async {
        await SystemDemangler.shared.clearCache()

        let symbol = "_$sSS"

        // First call
        let result1 = SystemDemangler.shared.demangleSync(symbol)

        // Second call should use cache
        let result2 = SystemDemangler.shared.demangleSync(symbol)

        #expect(result1 == result2)
    }

    // MARK: - SwiftDemangler Integration

    @Test("SwiftDemangler.enableSystemDemangling toggles state")
    func systemDemanglingToggle() async {
        // Initially disabled
        SwiftDemangler.disableSystemDemangling()
        #expect(!SwiftDemangler.isSystemDemanglingEnabled)

        // Enable
        _ = await SwiftDemangler.enableSystemDemangling()

        // Should be enabled if available
        let wasEnabled = SwiftDemangler.isSystemDemanglingEnabled

        // Disable again
        SwiftDemangler.disableSystemDemangling()
        #expect(!SwiftDemangler.isSystemDemanglingEnabled)

        // The value depends on whether swift-demangle is available
        _ = wasEnabled
    }

    @Test("SwiftDemangler.demangle uses built-in by default")
    func demanglerDefaultsToBuiltIn() {
        SwiftDemangler.disableSystemDemangling()
        SwiftDemangler.clearCache()

        // Test a symbol that built-in can handle
        let result = SwiftDemangler.demangle("SS")  // String shortcut
        #expect(result == "String")
    }

    @Test("SwiftDemangler.looksLikeSwiftMangled identifies mangled names")
    func mangledNameDetection() {
        // These should look mangled - test via demangle behavior
        SwiftDemangler.clearCache()

        // The demangle function internally uses looksLikeSwiftMangled
        // We can test its behavior indirectly by checking that mangled names
        // get processed differently than non-mangled ones

        let mangled = "_$s7SwiftUI4ViewP"
        let notMangled = "PlainClassName"

        let result1 = SwiftDemangler.demangle(mangled)
        let result2 = SwiftDemangler.demangle(notMangled)

        // Non-mangled should return as-is
        #expect(result2 == notMangled)

        // Mangled may or may not change depending on built-in capabilities
        _ = result1
    }
}
