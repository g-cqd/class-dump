// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation
import Testing

@testable import ClassDumpCore

/// Tests for DyldCacheHeader and related structures.
@Suite("Dyld Cache Header Tests")
struct DyldCacheHeaderTests {

    // MARK: - Magic Detection

    @Test("Parses arm64 magic string")
    func parsesArm64Magic() {
        let magic = DyldCacheMagic(magic: "dyld_v1   arm64")
        #expect(magic == .arm64)
        #expect(magic?.architecture == "arm64")
        #expect(magic?.is64Bit == true)
    }

    @Test("Parses arm64e magic string")
    func parsesArm64eMagic() {
        let magic = DyldCacheMagic(magic: "dyld_v1  arm64e")
        #expect(magic == .arm64e)
        #expect(magic?.architecture == "arm64e")
        #expect(magic?.is64Bit == true)
    }

    @Test("Parses x86_64 magic string")
    func parsesX86_64Magic() {
        let magic = DyldCacheMagic(magic: "dyld_v1  x86_64")
        #expect(magic == .x86_64)
        #expect(magic?.architecture == "x86_64")
        #expect(magic?.is64Bit == true)
    }

    @Test("Rejects invalid magic string")
    func rejectsInvalidMagic() {
        let magic = DyldCacheMagic(magic: "not_a_valid_magic")
        #expect(magic == nil)
    }

    @Test("All magic constants have unique architectures")
    func allMagicsUnique() {
        let archs = DyldCacheMagic.allCases.map { $0.architecture }
        let uniqueArchs = Set(archs)
        #expect(archs.count == uniqueArchs.count)
    }

    // MARK: - Mapping Info

    @Test("VMProtection flags work correctly")
    func vmProtectionFlags() {
        let readOnly = VMProtection.read
        #expect(readOnly.description == "r--")

        let readWrite = VMProtection([.read, .write])
        #expect(readWrite.description == "rw-")

        let readExecute = VMProtection([.read, .execute])
        #expect(readExecute.description == "r-x")

        let all = VMProtection([.read, .write, .execute])
        #expect(all.description == "rwx")
    }

    @Test("Mapping info address containment")
    func mappingContainment() {
        let mapping = DyldCacheMappingInfo(
            address: 0x1_8000_0000,
            size: 0x1000_0000,
            fileOffset: 0x0,
            maxProtection: .read,
            initialProtection: .read
        )

        #expect(mapping.contains(address: 0x1_8000_0000))
        #expect(mapping.contains(address: 0x1_8FFF_FFFF))
        #expect(!mapping.contains(address: 0x1_9000_0000))
        #expect(!mapping.contains(address: 0x1_7000_0000))
    }

    @Test("Mapping info file offset calculation")
    func mappingFileOffset() {
        let mapping = DyldCacheMappingInfo(
            address: 0x1_8000_0000,
            size: 0x1000_0000,
            fileOffset: 0x1000,
            maxProtection: .read,
            initialProtection: .read
        )

        let offset = mapping.fileOffset(for: 0x1_8000_1234)
        #expect(offset == 0x1000 + 0x1234)

        let nilOffset = mapping.fileOffset(for: 0x1_7000_0000)
        #expect(nilOffset == nil)
    }

    // MARK: - Translator

    @Test("Translator finds correct mapping")
    func translatorFindsMappings() {
        let mappings = [
            DyldCacheMappingInfo(
                address: 0x1_8000_0000,
                size: 0x1000_0000,
                fileOffset: 0x0,
                maxProtection: VMProtection([.read, .execute]),
                initialProtection: VMProtection([.read, .execute])
            ),
            DyldCacheMappingInfo(
                address: 0x1_A000_0000,
                size: 0x8000000,
                fileOffset: 0x1000_0000,
                maxProtection: VMProtection([.read, .write]),
                initialProtection: VMProtection([.read, .write])
            ),
        ]

        let translator = DyldCacheTranslator(mappings: mappings)

        // First mapping
        let offset1 = translator.fileOffset(for: 0x1_8000_1000)
        #expect(offset1 == 0x1000)

        // Second mapping
        let offset2 = translator.fileOffset(for: 0x1_A000_1000)
        #expect(offset2 == 0x1000_1000)

        // Not in any mapping
        let offset3 = translator.fileOffset(for: 0x1_0000_0000)
        #expect(offset3 == nil)
    }

    @Test("Translator caches results")
    func translatorCaches() {
        let mappings = [
            DyldCacheMappingInfo(
                address: 0x1_8000_0000,
                size: 0x1000_0000,
                fileOffset: 0x0,
                maxProtection: .read,
                initialProtection: .read
            )
        ]

        let translator = DyldCacheTranslator(mappings: mappings)

        // First lookup
        let offset1 = translator.fileOffset(for: 0x1_8000_1000)
        #expect(offset1 == 0x1000)

        // Second lookup (should use cache)
        let offset2 = translator.fileOffset(for: 0x1_8000_1000)
        #expect(offset2 == 0x1000)

        // Check cache stats
        let stats = translator.cacheStats
        #expect(stats.count > 0)

        // Clear cache
        translator.clearCache()
        let afterClear = translator.cacheStats
        #expect(afterClear.count == 0)
    }

    // MARK: - Image Info Helpers

    @Test("Image info framework detection")
    func imageFrameworkDetection() {
        let framework = DyldCacheImageInfo(
            address: 0x1_8000_0000,
            modificationTime: 0,
            inode: 0,
            pathFileOffset: 0,
            padding: 0,
            path: "/System/Library/Frameworks/Foundation.framework/Foundation"
        )

        #expect(framework.isPublicFramework)
        #expect(!framework.isPrivateFramework)
        #expect(framework.frameworkName == "Foundation")
        #expect(framework.name == "Foundation")

        let privateFramework = DyldCacheImageInfo(
            address: 0x1_8000_0000,
            modificationTime: 0,
            inode: 0,
            pathFileOffset: 0,
            padding: 0,
            path: "/System/Library/PrivateFrameworks/CoreUI.framework/CoreUI"
        )

        #expect(!privateFramework.isPublicFramework)
        #expect(privateFramework.isPrivateFramework)
        #expect(privateFramework.frameworkName == "CoreUI")

        let dylib = DyldCacheImageInfo(
            address: 0x1_8000_0000,
            modificationTime: 0,
            inode: 0,
            pathFileOffset: 0,
            padding: 0,
            path: "/usr/lib/libobjc.A.dylib"
        )

        #expect(!dylib.isPublicFramework)
        #expect(!dylib.isPrivateFramework)
        #expect(dylib.frameworkName == nil)
        #expect(dylib.name == "libobjc.A.dylib")
    }

    @Test("Image array filtering")
    func imageArrayFiltering() {
        let images = [
            DyldCacheImageInfo(
                address: 0x1_8000_0000,
                modificationTime: 0,
                inode: 0,
                pathFileOffset: 0,
                padding: 0,
                path: "/System/Library/Frameworks/Foundation.framework/Foundation"
            ),
            DyldCacheImageInfo(
                address: 0x1_8010_0000,
                modificationTime: 0,
                inode: 0,
                pathFileOffset: 0,
                padding: 0,
                path: "/System/Library/PrivateFrameworks/CoreUI.framework/CoreUI"
            ),
            DyldCacheImageInfo(
                address: 0x1_8020_0000,
                modificationTime: 0,
                inode: 0,
                pathFileOffset: 0,
                padding: 0,
                path: "/usr/lib/libobjc.A.dylib"
            ),
        ]

        #expect(images.publicFrameworks.count == 1)
        #expect(images.privateFrameworks.count == 1)
        #expect(images.framework(named: "Foundation")?.path.contains("Foundation") == true)
        #expect(images.framework(named: "CoreUI")?.path.contains("CoreUI") == true)
        #expect(images.framework(named: "NotAFramework") == nil)
    }
}
