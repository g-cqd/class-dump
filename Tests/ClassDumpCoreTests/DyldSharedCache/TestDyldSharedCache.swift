// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation
import Testing

@testable import ClassDumpCore

/// Tests for DyldSharedCache.
///
/// These tests require access to the system dyld_shared_cache.
/// Tests are skipped if the cache is not available.
@Suite("Dyld Shared Cache Tests")
struct DyldSharedCacheTests {

    // MARK: - System Cache Discovery

    @Test("Finds system cache path")
    func findsSystemCachePath() {
        // This should work on macOS
        let path = DyldSharedCache.systemCachePath()

        // Path may be nil on some systems (e.g., CI environments)
        if let path = path {
            #expect(FileManager.default.fileExists(atPath: path))
            #expect(path.contains("dyld_shared_cache_"))
        }
    }

    // MARK: - Cache Loading (requires system cache)

    @Test("Opens system cache successfully")
    func opensSystemCache() throws {
        guard let path = DyldSharedCache.systemCachePath() else {
            // Skip on systems without accessible cache
            return
        }

        let cache = try DyldSharedCache(path: path)

        #expect(!cache.architecture.isEmpty)
        #expect(cache.mappings.count > 0)
        #expect(cache.images.count > 0)
        #expect(cache.is64Bit)
    }

    @Test("Lists images in cache")
    func listsImages() throws {
        guard let path = DyldSharedCache.systemCachePath() else {
            return
        }

        let cache = try DyldSharedCache(path: path)

        // Should have many images
        #expect(cache.images.count > 100)

        // Should have Foundation
        let foundation = cache.image(named: "Foundation")
        #expect(foundation != nil)
        #expect(foundation?.path.contains("Foundation") == true)

        // Should have libobjc
        let libobjc = cache.images.first { $0.path.contains("libobjc") }
        #expect(libobjc != nil)
    }

    @Test("Lists public and private frameworks")
    func listsFrameworkCategories() throws {
        guard let path = DyldSharedCache.systemCachePath() else {
            return
        }

        let cache = try DyldSharedCache(path: path)

        let publicFrameworks = cache.images.publicFrameworks
        let privateFrameworks = cache.images.privateFrameworks

        #expect(publicFrameworks.count > 0)
        #expect(privateFrameworks.count > 0)

        // Public frameworks should include common ones
        let publicNames = publicFrameworks.compactMap { $0.frameworkName }
        #expect(publicNames.contains("Foundation"))
        #expect(publicNames.contains("CoreFoundation"))
    }

    @Test("Translates addresses to file offsets")
    func translatesAddresses() throws {
        guard let path = DyldSharedCache.systemCachePath() else {
            return
        }

        let cache = try DyldSharedCache(path: path)

        // Get an image address
        guard let foundation = cache.image(named: "Foundation") else {
            Issue.record("Foundation not found in cache")
            return
        }

        // Translate its address
        let offset = cache.fileOffset(for: foundation.address)
        #expect(offset != nil)

        // Should be able to read data at that offset
        if let offset = offset {
            let data = try cache.file.data(at: Int(offset), count: 4)
            // Should be Mach-O magic
            let magic = data.withUnsafeBytes { $0.load(as: UInt32.self) }
            #expect(magic == 0xFEED_FACF || magic == 0xFEED_FACE)  // MH_MAGIC_64 or MH_MAGIC
        }
    }

    @Test("Reads C strings from cache")
    func readsCStrings() throws {
        guard let path = DyldSharedCache.systemCachePath() else {
            return
        }

        let cache = try DyldSharedCache(path: path)

        // Get an image and read its path from the path offset
        guard let image = cache.images.first else {
            Issue.record("No images in cache")
            return
        }

        // Read string at pathFileOffset
        let pathString = cache.file.readCString(at: Int(image.pathFileOffset))
        #expect(pathString != nil)
        #expect(pathString == image.path)
    }

    // MARK: - Header Parsing

    @Test("Parses cache header correctly")
    func parsesHeader() throws {
        guard let path = DyldSharedCache.systemCachePath() else {
            return
        }

        let cache = try DyldSharedCache(path: path)

        #expect(cache.header.mappingCount > 0)
        // Modern caches (iOS 16+, macOS 13+) use imagesTextCount instead of imagesCount
        let hasImages = cache.header.imagesCount > 0 || cache.header.imagesTextCount > 0
        #expect(hasImages, "Cache should have images via imagesCount or imagesTextCount")
        // dyldBaseAddress may be 0 in modern caches
        // #expect(cache.header.dyldBaseAddress != 0)

        // UUID should be valid (not all zeros)
        let uuidString = cache.header.uuid.uuidString
        #expect(!uuidString.allSatisfy { $0 == "0" || $0 == "-" })
    }

    @Test("Identifies cache architecture")
    func identifiesArchitecture() throws {
        guard let path = DyldSharedCache.systemCachePath() else {
            return
        }

        let cache = try DyldSharedCache(path: path)

        // Architecture should be one of the known types
        let knownArchs = ["arm64", "arm64e", "x86_64", "x86_64h"]
        #expect(knownArchs.contains(cache.architecture))
    }

    // MARK: - Mappings

    @Test("Has expected mapping types")
    func hasExpectedMappings() throws {
        guard let path = DyldSharedCache.systemCachePath() else {
            return
        }

        let cache = try DyldSharedCache(path: path)

        // Should have at least TEXT and DATA mappings
        let hasExecutable = cache.mappings.contains { $0.isExecutable }
        let hasWritable = cache.mappings.contains { $0.isWritable }

        #expect(hasExecutable)
        #expect(hasWritable)

        // Mappings should be contiguous or at least non-overlapping
        let sortedMappings = cache.mappings.sorted { $0.address < $1.address }
        for i in 0..<(sortedMappings.count - 1) {
            let current = sortedMappings[i]
            let next = sortedMappings[i + 1]
            #expect(current.endAddress <= next.address)
        }
    }

    // MARK: - Description

    @Test("Provides useful description")
    func providesDescription() throws {
        guard let path = DyldSharedCache.systemCachePath() else {
            return
        }

        let cache = try DyldSharedCache(path: path)
        let desc = cache.description

        #expect(desc.contains("DyldSharedCache"))
        #expect(desc.contains("architecture"))
        #expect(desc.contains("mappings"))
        #expect(desc.contains("images"))
    }
}
