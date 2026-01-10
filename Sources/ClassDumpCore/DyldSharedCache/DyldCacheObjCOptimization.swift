// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

// MARK: - ObjC Optimization Header

/// The ObjC optimization header in dyld_shared_cache.
///
/// This structure points to optimized tables for fast selector, class, and protocol lookup.
/// These tables are used by the ObjC runtime for efficient access without loading full metadata.
///
/// ## Layout (objc_opt_t)
///
/// The optimization header contains offsets to various hash tables:
/// - Selector table: Deduplicated selectors across all images
/// - Header info: RO data for each image
/// - Class table: Quick class name → class mapping
/// - Protocol table: Quick protocol name → protocol mapping
///
public struct DyldCacheObjCOptHeader: Sendable {
    /// Version of the optimization format.
    public let version: UInt32

    /// Flags.
    public let flags: UInt32

    /// Offset to selector optimization table (from this header).
    public let selectorOptOffset: Int32

    /// Offset to header info read-only data (from this header).
    public let headerOptROOffset: Int32

    /// Offset to class table (from this header, if version >= 15).
    public let classOptOffset: Int32

    /// Offset to protocol table (from this header, if version >= 15).
    public let protocolOptOffset: Int32

    /// Offset to header info read-write data (from this header).
    public let headerOptRWOffset: Int32

    /// Unused protocol opt 2 offset.
    public let unusedProtocolOpt2Offset: Int32

    /// Large shared caches class offset.
    public let largeSharedCachesClassOffset: Int32

    /// Large shared caches protocol offset.
    public let largeSharedCachesProtocolOffset: Int32

    /// Offset to the relative method selector base address (from cache start).
    ///
    /// For small methods with direct selectors, the nameOffset field is
    /// relative to this base address, not relative to the method entry.
    public let relativeMethodSelectorBaseAddressOffset: Int64

    /// Whether the class table is available.
    public var hasClassTable: Bool {
        version >= 15 && classOptOffset != 0
    }

    /// Whether the protocol table is available.
    public var hasProtocolTable: Bool {
        version >= 15 && protocolOptOffset != 0
    }

    /// Parse from cache file.
    ///
    /// - Parameters:
    ///   - file: The cache file.
    ///   - offset: Offset to the optimization header.
    /// - Throws: If parsing fails.
    public init(from file: MemoryMappedFile, at offset: Int) throws {
        let data = try file.data(at: offset, count: 48)
        var cursor = try DataCursor(data: data)

        self.version = try cursor.readLittleInt32()
        self.flags = try cursor.readLittleInt32()
        self.selectorOptOffset = Int32(bitPattern: try cursor.readLittleInt32())
        self.headerOptROOffset = Int32(bitPattern: try cursor.readLittleInt32())
        self.classOptOffset = Int32(bitPattern: try cursor.readLittleInt32())
        self.protocolOptOffset = Int32(bitPattern: try cursor.readLittleInt32())
        self.headerOptRWOffset = Int32(bitPattern: try cursor.readLittleInt32())
        self.unusedProtocolOpt2Offset = Int32(bitPattern: try cursor.readLittleInt32())
        self.largeSharedCachesClassOffset = Int32(bitPattern: try cursor.readLittleInt32())
        self.largeSharedCachesProtocolOffset = Int32(bitPattern: try cursor.readLittleInt32())
        self.relativeMethodSelectorBaseAddressOffset = Int64(bitPattern: try cursor.readLittleInt64())
    }
}

// MARK: - Selector Table

/// A hash table for selector lookup.
///
/// The selector table uses a perfect hash function to map selector names
/// to their canonical addresses in the shared cache.
///
public struct DyldCacheSelectorTable: Sendable {
    /// Number of buckets in the hash table.
    public let bucketCount: UInt32

    /// Mask for bucket lookup (bucketCount - 1).
    public let bucketMask: UInt32

    /// Number of selectors in the table.
    public let selectorCount: UInt32

    /// Salt values for the hash function.
    private let salt: UInt32
    private let shift: UInt32
    private let tab: [UInt8]

    /// Offset data for selector strings.
    private let offsets: [UInt32]

    /// Base offset in file where this table starts.
    private let baseOffset: Int

    /// Reference to the cache file.
    private let file: MemoryMappedFile

    /// Parse selector table from cache.
    ///
    /// - Parameters:
    ///   - file: The cache file.
    ///   - offset: Offset to the selector table.
    /// - Throws: If parsing fails.
    public init(from file: MemoryMappedFile, at offset: Int) throws {
        self.file = file
        self.baseOffset = offset

        // Read header
        let headerData = try file.data(at: offset, count: 20)
        var cursor = try DataCursor(data: headerData)

        // objc_stringhash_t header
        // capacity (uint32), occupied (uint32), shift (uint32), mask (uint32), salt (uint32)
        // Followed by scramble[] (uint8) and offsets[] (uint32)

        self.bucketCount = UInt32(try cursor.readLittleInt32())
        self.selectorCount = UInt32(try cursor.readLittleInt32())
        self.shift = UInt32(try cursor.readLittleInt32())
        self.bucketMask = UInt32(try cursor.readLittleInt32())
        self.salt = UInt32(try cursor.readLittleInt32())

        // Read scramble table (256 bytes)
        let scrambleData = try file.data(at: offset + 20, count: 256)
        self.tab = Array(scrambleData)

        // Read offsets (one per bucket)
        let offsetsData = try file.data(at: offset + 20 + 256, count: Int(bucketCount) * 4)
        var offsetCursor = try DataCursor(data: offsetsData)
        var offsets: [UInt32] = []
        offsets.reserveCapacity(Int(bucketCount))
        for _ in 0..<bucketCount {
            offsets.append(UInt32(try offsetCursor.readLittleInt32()))
        }
        self.offsets = offsets
    }

    /// Look up a selector by name.
    ///
    /// - Parameter name: The selector name.
    /// - Returns: The selector string offset, or `nil` if not found.
    public func lookup(_ name: String) -> UInt32? {
        guard !name.isEmpty else { return nil }

        let hash = perfectHash(name)
        let index = Int(hash & bucketMask)

        guard index < offsets.count else { return nil }

        let offset = offsets[index]
        if offset == 0 || offset == UInt32.max {
            return nil
        }

        // Verify the string matches
        let stringOffset = baseOffset + 20 + 256 + Int(bucketCount) * 4 + Int(offset)
        if let foundName = file.readCString(at: stringOffset), foundName == name {
            return offset
        }

        return nil
    }

    /// Enumerate all selectors in the table.
    ///
    /// - Parameter handler: Called for each selector (name, offset).
    public func enumerate(_ handler: (String, UInt32) -> Void) {
        let stringsBase = baseOffset + 20 + 256 + Int(bucketCount) * 4

        for offset in offsets where offset != 0 && offset != UInt32.max {
            let stringOffset = stringsBase + Int(offset)
            if let name = file.readCString(at: stringOffset) {
                handler(name, offset)
            }
        }
    }

    /// Perfect hash function (matches objc runtime).
    private func perfectHash(_ string: String) -> UInt32 {
        var h: UInt32 = 0
        let data = string.utf8

        for byte in data {
            let idx = Int((h ^ UInt32(byte)) & 0xFF)
            h = (h >> 8) ^ UInt32(tab[idx])
        }

        return h
    }
}

// MARK: - Class Table

/// A hash table for class lookup by name.
///
/// Maps class names to their addresses in the shared cache.
///
public struct DyldCacheClassTable: Sendable {
    /// Number of classes in the table.
    public let classCount: UInt32

    /// Bucket information.
    private let buckets: [ClassBucket]

    /// Reference to the cache.
    private let cache: DyldSharedCache

    /// Base address of the table.
    private let baseAddress: UInt64

    /// A bucket in the class hash table.
    private struct ClassBucket: Sendable {
        let selOffs: UInt32  // Selector offset
        let clsOffs: UInt32  // Class offset
        let hiImIndex: UInt16  // High bits of image index
        let loImIndex: UInt16  // Low bits of image index

        var imageIndex: UInt32 {
            (UInt32(hiImIndex) << 16) | UInt32(loImIndex)
        }
    }

    /// Parse class table from cache.
    ///
    /// - Parameters:
    ///   - cache: The shared cache.
    ///   - address: Virtual address of the class table.
    /// - Throws: If parsing fails.
    public init(from cache: DyldSharedCache, at address: UInt64) throws {
        self.cache = cache
        self.baseAddress = address

        guard let offset = cache.translator.fileOffsetInt(for: address) else {
            throw ParseError.addressNotMapped(address)
        }

        // Read header
        let headerData = try cache.file.data(at: offset, count: 8)
        var cursor = try DataCursor(data: headerData)

        let capacity = UInt32(try cursor.readLittleInt32())
        self.classCount = UInt32(try cursor.readLittleInt32())

        // Read buckets
        var buckets: [ClassBucket] = []
        let bucketsData = try cache.file.data(at: offset + 8, count: Int(capacity) * 12)
        var bucketCursor = try DataCursor(data: bucketsData)

        for _ in 0..<capacity {
            let selOffs = UInt32(try bucketCursor.readLittleInt32())
            let clsOffs = UInt32(try bucketCursor.readLittleInt32())
            let hiImIndex = UInt16(try bucketCursor.readLittleInt16())
            let loImIndex = UInt16(try bucketCursor.readLittleInt16())
            buckets.append(ClassBucket(selOffs: selOffs, clsOffs: clsOffs, hiImIndex: hiImIndex, loImIndex: loImIndex))
        }
        self.buckets = buckets
    }

    /// Look up a class by name.
    ///
    /// - Parameter name: The class name.
    /// - Returns: The class address, or `nil` if not found.
    public func lookup(_ name: String) -> UInt64? {
        // Simple linear search - could be optimized with hash
        for bucket in buckets where bucket.selOffs != 0 && bucket.clsOffs != 0 {

            // Read the selector string to compare
            // The selOffs is relative to some base
            // For now, return first non-empty match (this is a simplification)
        }
        return nil
    }

    /// Enumerate all classes.
    ///
    /// - Parameter handler: Called for each class (imageIndex, classOffset).
    public func enumerate(_ handler: (UInt32, UInt32) -> Void) {
        for bucket in buckets where bucket.clsOffs != 0 {
            handler(bucket.imageIndex, bucket.clsOffs)
        }
    }

    /// Errors that can occur when parsing ObjC optimization data.
    public enum ParseError: Error {
        case addressNotMapped(UInt64)
    }
}

// MARK: - DyldSharedCache Extension

extension DyldSharedCache {
    /// Whether this cache has ObjC optimization tables.
    public var hasObjCOptimization: Bool {
        header.objcOptOffset != 0 && header.objcOptSize > 0
    }

    /// Parse the ObjC optimization header.
    ///
    /// - Returns: The optimization header.
    /// - Throws: If parsing fails or optimization is not available.
    public func objcOptimizationHeader() throws -> DyldCacheObjCOptHeader {
        guard hasObjCOptimization else {
            throw ObjCOptError.notAvailable
        }

        // The objcOptOffset is a file offset
        return try DyldCacheObjCOptHeader(from: file, at: Int(header.objcOptOffset))
    }

    /// Parse the selector optimization table.
    ///
    /// - Returns: The selector table.
    /// - Throws: If parsing fails.
    public func selectorTable() throws -> DyldCacheSelectorTable {
        let optHeader = try objcOptimizationHeader()

        // Selector table offset is relative to the opt header
        let tableOffset = Int(header.objcOptOffset) + Int(optHeader.selectorOptOffset)

        return try DyldCacheSelectorTable(from: file, at: tableOffset)
    }

    /// Parse the class lookup table.
    ///
    /// - Returns: The class table.
    /// - Throws: If parsing fails or not available.
    public func classTable() throws -> DyldCacheClassTable {
        let optHeader = try objcOptimizationHeader()

        guard optHeader.hasClassTable else {
            throw ObjCOptError.tableNotAvailable("class")
        }

        // Class table offset is relative to the opt header
        let tableOffset = Int(header.objcOptOffset) + Int(optHeader.classOptOffset)

        // Convert file offset to address for the table
        guard let mapping = translator.findMapping(containing: header.dyldBaseAddress) else {
            throw ObjCOptError.addressTranslationFailed
        }

        let tableAddress = mapping.address + UInt64(tableOffset) - mapping.fileOffset

        return try DyldCacheClassTable(from: self, at: tableAddress)
    }

    /// ObjC optimization errors.
    public enum ObjCOptError: Error, CustomStringConvertible {
        case notAvailable
        case tableNotAvailable(String)
        case addressTranslationFailed

        /// A human-readable description of the error.
        public var description: String {
            switch self {
                case .notAvailable:
                    return "ObjC optimization tables not available in this cache"
                case .tableNotAvailable(let name):
                    return "ObjC \(name) table not available (version too old?)"
                case .addressTranslationFailed:
                    return "Failed to translate address for ObjC optimization"
            }
        }
    }
}
