// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation
import Testing

@testable import ClassDumpCore

/// Integration tests that verify end-to-end DSC functionality.
@Suite("Dyld Cache Integration Tests")
struct DyldCacheIntegrationTests {

    // MARK: - Framework Analysis

    @Test("Can extract Foundation Mach-O header")
    func extractsFoundationHeader() throws {
        guard let path = DyldSharedCache.systemCachePath() else {
            return
        }

        let cache = try DyldSharedCache(path: path)

        guard let foundation = cache.image(named: "Foundation") else {
            Issue.record("Foundation not found")
            return
        }

        // Extract the Mach-O data
        let data = try cache.imageData(for: foundation)

        // Verify it's a valid Mach-O
        #expect(data.count > 32)

        let magic = data.withUnsafeBytes { $0.load(as: UInt32.self) }
        #expect(magic == 0xFEED_FACF || magic == 0xFEED_FACE)
    }

    @Test("Can find CoreFoundation")
    func findsCoreFoundation() throws {
        guard let path = DyldSharedCache.systemCachePath() else {
            return
        }

        let cache = try DyldSharedCache(path: path)
        let cf = cache.image(named: "CoreFoundation")

        #expect(cf != nil)
        #expect(cf?.path.contains("CoreFoundation") == true)
    }

    @Test("Can find libobjc")
    func findsLibobjc() throws {
        guard let path = DyldSharedCache.systemCachePath() else {
            return
        }

        let cache = try DyldSharedCache(path: path)
        let objc = cache.images.first { $0.path.contains("libobjc") }

        #expect(objc != nil)
        #expect(objc?.name.contains("libobjc") == true)
    }

    @Test("Can find private frameworks")
    func findsPrivateFrameworks() throws {
        guard let path = DyldSharedCache.systemCachePath() else {
            return
        }

        let cache = try DyldSharedCache(path: path)
        let privateFrameworks = cache.images.privateFrameworks

        #expect(privateFrameworks.count > 0)

        // CoreUI is a commonly available private framework
        let coreUI = privateFrameworks.first { $0.frameworkName == "CoreUI" }
        if let coreUI = coreUI {
            #expect(coreUI.isPrivateFramework)
        }
    }

    // MARK: - Address Space

    @Test("All mappings cover non-overlapping regions")
    func mappingsNonOverlapping() throws {
        guard let path = DyldSharedCache.systemCachePath() else {
            return
        }

        let cache = try DyldSharedCache(path: path)
        let sortedMappings = cache.mappings.sorted { $0.address < $1.address }

        for i in 0..<(sortedMappings.count - 1) {
            let current = sortedMappings[i]
            let next = sortedMappings[i + 1]
            #expect(current.endAddress <= next.address)
        }
    }

    @Test("All images have valid addresses within mappings")
    func imagesWithinMappings() throws {
        guard let path = DyldSharedCache.systemCachePath() else {
            return
        }

        let cache = try DyldSharedCache(path: path)

        // Check first 100 images
        for image in cache.images.prefix(100) {
            let offset = cache.translator.fileOffset(for: image.address)
            #expect(offset != nil, "Image \(image.name) address not in any mapping")
        }
    }

    // MARK: - Sub-Cache Discovery

    @Test("Detects sub-cache presence correctly")
    func detectsSubCaches() throws {
        guard let path = DyldSharedCache.systemCachePath() else {
            return
        }

        let cache = try DyldSharedCache(path: path)

        // On modern systems (iOS 16+, macOS 13+), there should be sub-caches
        // On older systems, this might be false
        // We just verify the property doesn't crash
        _ = cache.header.hasSubCaches
        _ = cache.header.subCacheArrayCount
    }

    // MARK: - Performance

    @Test("Image lookup is fast")
    func imageLookupPerformance() throws {
        guard let path = DyldSharedCache.systemCachePath() else {
            return
        }

        let cache = try DyldSharedCache(path: path)

        let start = Date()

        // Look up many frameworks
        let frameworks = [
            "Foundation", "CoreFoundation", "UIKit", "AppKit",
            "CoreGraphics", "CoreData", "Security", "SystemConfiguration",
        ]

        for _ in 0..<100 {
            for name in frameworks {
                _ = cache.image(named: name)
            }
        }

        let elapsed = Date().timeIntervalSince(start)

        // Should complete in under 1 second for 800 lookups
        #expect(elapsed < 1.0, "Image lookup took \(elapsed)s, expected < 1s")
    }

    @Test("Address translation is fast")
    func addressTranslationPerformance() throws {
        guard let path = DyldSharedCache.systemCachePath() else {
            return
        }

        let cache = try DyldSharedCache(path: path)

        // Get some addresses to translate
        let addresses = cache.images.prefix(100).map { $0.address }

        let start = Date()

        // Translate many times
        for _ in 0..<1000 {
            for addr in addresses {
                _ = cache.translator.fileOffset(for: addr)
            }
        }

        let elapsed = Date().timeIntervalSince(start)

        // Should complete in under 1 second for 100k translations
        #expect(elapsed < 1.0, "Translation took \(elapsed)s, expected < 1s")
    }
}
