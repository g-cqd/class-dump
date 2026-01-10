// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

// MARK: - Magic Constants

/// Known dyld_shared_cache magic strings.
public enum DyldCacheMagic: String, CaseIterable, Sendable {
    case arm64 = "dyld_v1   arm64"
    case arm64e = "dyld_v1  arm64e"
    case x86_64 = "dyld_v1  x86_64"
    case x86_64h = "dyld_v1 x86_64h"
    case armv7k = "dyld_v1  armv7k"
    case arm64_32 = "dyld_v1arm64_32"

    /// The architecture name for this cache type.
    public var architecture: String {
        switch self {
            case .arm64: return "arm64"
            case .arm64e: return "arm64e"
            case .x86_64: return "x86_64"
            case .x86_64h: return "x86_64h"
            case .armv7k: return "armv7k"
            case .arm64_32: return "arm64_32"
        }
    }

    /// Whether this is a 64-bit architecture.
    public var is64Bit: Bool {
        switch self {
            case .arm64, .arm64e, .x86_64, .x86_64h:
                return true
            case .armv7k, .arm64_32:
                return false
        }
    }

    /// Initialize from a 16-byte magic string.
    public init?(magic: String) {
        // Normalize to 16 characters
        let normalized = String(magic.prefix(16))
        for value in Self.allCases where normalized.hasPrefix(value.rawValue.trimmingCharacters(in: .whitespaces)) {
            // Handle padding variations
            self = value
            return
        }
        // Try exact match
        self.init(rawValue: normalized)
    }
}

// MARK: - Header Structure

/// The dyld_shared_cache header.
///
/// This structure represents the header at the beginning of a dyld_shared_cache file.
/// The format has evolved over time; this implementation supports modern caches (iOS 14+).
///
/// ## Layout
///
/// The header contains offsets to various tables:
/// - Mapping info: Describes memory regions and their file offsets
/// - Image info: Lists all dylibs in the cache
/// - Slide info: For ASLR pointer adjustment
/// - Local symbols: Symbol information (if not stripped)
///
public struct DyldCacheHeader: Sendable {
    // MARK: - Core Fields

    /// The magic identifier (e.g., "dyld_v1   arm64").
    public let magic: DyldCacheMagic

    /// Offset to the first `dyld_cache_mapping_info` structure.
    public let mappingOffset: UInt32

    /// Number of `dyld_cache_mapping_info` structures.
    public let mappingCount: UInt32

    /// Offset to the first `dyld_cache_image_info` structure (legacy).
    public let imagesOffset: UInt32

    /// Number of `dyld_cache_image_info` structures (legacy).
    public let imagesCount: UInt32

    /// Base address where dyld lives in the cache.
    public let dyldBaseAddress: UInt64

    // MARK: - Code Signature

    /// File offset of code signature blob.
    public let codeSignatureOffset: UInt64

    /// Size of code signature blob (zero if none).
    public let codeSignatureSize: UInt64

    // MARK: - Slide Info

    /// File offset of kernel slid info.
    public let slideInfoOffset: UInt64

    /// Size of kernel slid info.
    public let slideInfoSize: UInt64

    // MARK: - Local Symbols

    /// File offset of where local symbols are stored.
    public let localSymbolsOffset: UInt64

    /// Size of local symbols information.
    public let localSymbolsSize: UInt64

    // MARK: - UUID

    /// Unique identifier for this cache.
    public let uuid: UUID

    // MARK: - Cache Type

    /// Type of cache (0 = development, 1 = production).
    public let cacheType: UInt64

    // MARK: - Branch Pools (arm64e)

    /// Offset to array of branch pool addresses.
    public let branchPoolsOffset: UInt32

    /// Number of branch pools.
    public let branchPoolsCount: UInt32

    // MARK: - Accelerate Info (for dyld)

    /// File offset to dyld's shared accelerate info.
    public let accelerateInfoAddr: UInt64

    /// Size of the accelerate tables.
    public let accelerateInfoSize: UInt64

    // MARK: - Image Text Info

    /// File offset to array of `dyld_cache_image_text_info`.
    public let imagesTextOffset: UInt64

    /// Number of entries in imagesText.
    public let imagesTextCount: UInt64

    // MARK: - Additional Mappings (iOS 14+)

    /// File offset to first `dyld_cache_mapping_and_slide_info`.
    public let mappingWithSlideOffset: UInt64

    /// Number of `dyld_cache_mapping_and_slide_info` entries.
    public let mappingWithSlideCount: UInt64

    // MARK: - ObjC Optimization (iOS 14+)

    /// File offset to ObjC optimization tables.
    public let objcOptOffset: UInt64

    /// Size of ObjC optimization tables.
    public let objcOptSize: UInt64

    /// Shared region start address.
    public let sharedRegionStart: UInt64

    /// Shared region size.
    public let sharedRegionSize: UInt64

    // MARK: - Sub-Caches (iOS 16+ / macOS 13+)

    /// UUID of the associated .symbols sub-cache.
    public let symbolsSubCacheUUID: UUID?

    /// Number of sub-cache files (.01, .02, etc.).
    public let subCacheArrayCount: UInt32

    /// File offset to array of sub-cache entries.
    public let subCacheArrayOffset: UInt32

    // MARK: - Computed Properties

    /// Whether this cache has sub-caches.
    public var hasSubCaches: Bool {
        subCacheArrayCount > 0
    }

    /// Whether this cache has slide info.
    public var hasSlideInfo: Bool {
        slideInfoSize > 0
    }

    /// Whether this cache has local symbols.
    public var hasLocalSymbols: Bool {
        localSymbolsSize > 0
    }

    // MARK: - Raw Header Size

    /// Minimum header size (older format).
    public static let minimumSize = 0x100  // 256 bytes

    /// Modern header size (iOS 16+).
    public static let modernSize = 0x1F0  // ~500 bytes

    // MARK: - Parsing

    /// Parse a dyld_cache_header from memory-mapped data.
    ///
    /// - Parameter file: The memory-mapped cache file.
    /// - Throws: `ParseError` if the header is invalid.
    public init(from file: MemoryMappedFile) throws {
        guard file.size >= Self.minimumSize else {
            throw ParseError.fileTooSmall(file.size)
        }

        // Read and validate magic
        let magicData = try file.data(at: 0, count: 16)
        let magicString = String(data: magicData, encoding: .ascii) ?? ""
        guard let magic = DyldCacheMagic(magic: magicString) else {
            throw ParseError.invalidMagic(magicString)
        }
        self.magic = magic

        // Read core header fields
        self.mappingOffset = try file.read(UInt32.self, at: 0x10)
        self.mappingCount = try file.read(UInt32.self, at: 0x14)
        self.imagesOffset = try file.read(UInt32.self, at: 0x18)
        self.imagesCount = try file.read(UInt32.self, at: 0x1C)
        self.dyldBaseAddress = try file.read(UInt64.self, at: 0x20)

        // Code signature
        self.codeSignatureOffset = try file.read(UInt64.self, at: 0x28)
        self.codeSignatureSize = try file.read(UInt64.self, at: 0x30)

        // Slide info
        self.slideInfoOffset = try file.read(UInt64.self, at: 0x38)
        self.slideInfoSize = try file.read(UInt64.self, at: 0x40)

        // Local symbols
        self.localSymbolsOffset = try file.read(UInt64.self, at: 0x48)
        self.localSymbolsSize = try file.read(UInt64.self, at: 0x50)

        // UUID (16 bytes at offset 0x58)
        let uuidData = try file.data(at: 0x58, count: 16)
        self.uuid = UUID(uuid: uuidData.withUnsafeBytes { $0.load(as: uuid_t.self) })

        // Cache type
        self.cacheType = try file.read(UInt64.self, at: 0x68)

        // Branch pools
        self.branchPoolsOffset = try file.read(UInt32.self, at: 0x70)
        self.branchPoolsCount = try file.read(UInt32.self, at: 0x74)

        // Accelerate info
        self.accelerateInfoAddr = try file.read(UInt64.self, at: 0x78)
        self.accelerateInfoSize = try file.read(UInt64.self, at: 0x80)

        // Images text
        self.imagesTextOffset = try file.read(UInt64.self, at: 0x88)
        self.imagesTextCount = try file.read(UInt64.self, at: 0x90)

        // Mapping with slide (iOS 14+)
        if file.size >= 0xA8 {
            self.mappingWithSlideOffset = try file.read(UInt64.self, at: 0x98)
            self.mappingWithSlideCount = try file.read(UInt64.self, at: 0xA0)
        }
        else {
            self.mappingWithSlideOffset = 0
            self.mappingWithSlideCount = 0
        }

        // ObjC Optimization (iOS 14+)
        if file.size >= 0xC0 {
            self.objcOptOffset = try file.read(UInt64.self, at: 0xA8)
            self.objcOptSize = try file.read(UInt64.self, at: 0xB0)
        }
        else {
            self.objcOptOffset = 0
            self.objcOptSize = 0
        }

        // Shared region info
        if file.size >= 0xD8 {
            self.sharedRegionStart = try file.read(UInt64.self, at: 0xC8)
            self.sharedRegionSize = try file.read(UInt64.self, at: 0xD0)
        }
        else {
            self.sharedRegionStart = 0
            self.sharedRegionSize = 0
        }

        // Sub-caches (iOS 16+ / macOS 13+)
        if file.size >= 0x130 {
            let subUUIDData = try file.data(at: 0x108, count: 16)
            let allZero = subUUIDData.allSatisfy { $0 == 0 }
            if !allZero {
                self.symbolsSubCacheUUID = UUID(uuid: subUUIDData.withUnsafeBytes { $0.load(as: uuid_t.self) })
            }
            else {
                self.symbolsSubCacheUUID = nil
            }
            self.subCacheArrayCount = try file.read(UInt32.self, at: 0x118)
            self.subCacheArrayOffset = try file.read(UInt32.self, at: 0x11C)
        }
        else {
            self.symbolsSubCacheUUID = nil
            self.subCacheArrayCount = 0
            self.subCacheArrayOffset = 0
        }
    }

    // MARK: - Errors

    public enum ParseError: Error, CustomStringConvertible {
        case fileTooSmall(Int)
        case invalidMagic(String)

        public var description: String {
            switch self {
                case .fileTooSmall(let size):
                    return "File too small for dyld_shared_cache header: \(size) bytes"
                case .invalidMagic(let magic):
                    return "Invalid dyld_shared_cache magic: '\(magic)'"
            }
        }
    }
}

// MARK: - Debug Description

extension DyldCacheHeader: CustomStringConvertible {
    public var description: String {
        """
        DyldCacheHeader {
          magic: \(magic.rawValue)
          architecture: \(magic.architecture)
          mappings: \(mappingCount) at offset 0x\(String(mappingOffset, radix: 16))
          images: \(imagesCount) at offset 0x\(String(imagesOffset, radix: 16))
          dyldBaseAddress: 0x\(String(dyldBaseAddress, radix: 16))
          uuid: \(uuid)
          hasSlideInfo: \(hasSlideInfo)
          hasLocalSymbols: \(hasLocalSymbols)
          hasSubCaches: \(hasSubCaches) (\(subCacheArrayCount) sub-caches)
        }
        """
    }
}
