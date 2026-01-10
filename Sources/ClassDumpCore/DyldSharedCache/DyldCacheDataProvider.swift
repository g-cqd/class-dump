// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

/// A protocol for providing data access to binary content.
///
/// This abstraction allows ObjC processing to work with both:
/// - Standalone Mach-O files (where data is contiguous)
/// - DSC images (where data is scattered across the cache)
///
/// ## Thread Safety
///
/// Implementations must be thread-safe for concurrent access.
///
public protocol BinaryDataProvider: Sendable {
    /// Translate a virtual address to a file offset.
    ///
    /// - Parameter address: The virtual address.
    /// - Returns: The file offset, or `nil` if not mapped.
    func fileOffset(for address: UInt64) -> Int?

    /// Read raw data at a file offset.
    ///
    /// - Parameters:
    ///   - offset: The file offset.
    ///   - count: Number of bytes to read.
    /// - Returns: The data.
    /// - Throws: If the read fails.
    func readData(at offset: Int, count: Int) throws -> Data

    /// Read raw data at a virtual address.
    ///
    /// - Parameters:
    ///   - address: The virtual address.
    ///   - count: Number of bytes to read.
    /// - Returns: The data.
    /// - Throws: If the address is invalid or read fails.
    func readData(atAddress address: UInt64, count: Int) throws -> Data

    /// Read a null-terminated C string at a virtual address.
    ///
    /// - Parameter address: The virtual address.
    /// - Returns: The string, or `nil` if invalid.
    func readCString(at address: UInt64) -> String?

    /// The total size of the data.
    var dataSize: Int { get }
}

// MARK: - Default Implementation

extension BinaryDataProvider {
    public func readData(atAddress address: UInt64, count: Int) throws -> Data {
        guard let offset = fileOffset(for: address) else {
            throw DataProviderError.addressNotMapped(address)
        }
        return try readData(at: offset, count: count)
    }
}

/// Errors from data provider operations.
public enum DataProviderError: Error, CustomStringConvertible {
    case addressNotMapped(UInt64)
    case readFailed(Int, Int)
    case outOfBounds(Int, Int)

    public var description: String {
        switch self {
            case .addressNotMapped(let addr):
                return "Address 0x\(String(addr, radix: 16)) not in mappings"
            case .readFailed(let offset, let count):
                return "Failed to read \(count) bytes at offset \(offset)"
            case .outOfBounds(let offset, let size):
                return "Offset \(offset) out of bounds (size: \(size))"
        }
    }
}

// MARK: - Standalone Data Provider

/// A data provider for standalone Mach-O files.
///
/// Wraps `Data` and `AddressTranslator` to provide the standard interface.
public final class StandaloneDataProvider: BinaryDataProvider, @unchecked Sendable {
    private let data: Data
    private let translator: AddressTranslator

    public var dataSize: Int { data.count }

    /// Initialize with binary data and segment information.
    ///
    /// - Parameters:
    ///   - data: The raw binary data.
    ///   - segments: The segment commands for address translation.
    public init(data: Data, segments: [SegmentCommand]) {
        self.data = data
        self.translator = AddressTranslator(segments: segments)
    }

    public func fileOffset(for address: UInt64) -> Int? {
        translator.fileOffset(for: address)
    }

    public func readData(at offset: Int, count: Int) throws -> Data {
        guard offset >= 0 && offset + count <= data.count else {
            throw DataProviderError.outOfBounds(offset, data.count)
        }
        return data.subdata(in: offset..<(offset + count))
    }

    public func readCString(at address: UInt64) -> String? {
        guard let offset = fileOffset(for: address) else { return nil }
        guard offset >= 0 && offset < data.count else { return nil }
        return SIMDStringUtils.readNullTerminatedString(from: data, at: offset)
    }
}

// MARK: - DSC Data Provider

/// A data provider for images within a dyld_shared_cache.
///
/// This provider resolves addresses using the DSC's mappings, allowing
/// access to data scattered across the cache file. It supports:
/// - Reading from the main cache file
/// - Reading from sub-caches (.01, .02, etc.)
/// - Shared string and selector resolution
///
public final class DyldCacheDataProvider: BinaryDataProvider, @unchecked Sendable {
    /// The shared cache.
    public let cache: DyldSharedCache

    /// The specific image being processed.
    public let image: DyldCacheImageInfo

    /// The image's segments (parsed from its Mach-O header in the cache).
    private let imageSegments: [SegmentCommand]

    /// Address translator for the image's own sections.
    private let imageTranslator: AddressTranslator

    public var dataSize: Int { cache.file.size }

    /// Initialize with a cache and image.
    ///
    /// - Parameters:
    ///   - cache: The dyld_shared_cache.
    ///   - image: The image to process.
    /// - Throws: If the image's Mach-O header cannot be parsed.
    public init(cache: DyldSharedCache, image: DyldCacheImageInfo) throws {
        self.cache = cache
        self.image = image

        // Parse the image's segments from its Mach-O header
        let headerData = try cache.imageData(for: image)
        let segments = try Self.parseSegments(from: headerData, imageAddress: image.address)
        self.imageSegments = segments
        self.imageTranslator = AddressTranslator(segments: segments)
    }

    /// Parse segment commands from Mach-O header data.
    private static func parseSegments(from data: Data, imageAddress: UInt64) throws -> [SegmentCommand] {
        var cursor = try DataCursor(data: data)

        // Read Mach-O header
        let magic = try cursor.readLittleInt32()
        let is64Bit = (magic == 0xFEED_FACF || magic == 0xCFFA_EDFE)
        let isBigEndian = (magic == 0xCEFA_EDFE || magic == 0xCFFA_EDFE)
        let byteOrder: ByteOrder = isBigEndian ? .big : .little

        // Read header fields
        _ = try cursor.readLittleInt32()  // cputype
        _ = try cursor.readLittleInt32()  // cpusubtype
        _ = try cursor.readLittleInt32()  // filetype
        let ncmds = try cursor.readLittleInt32()
        _ = try cursor.readLittleInt32()  // sizeofcmds
        _ = try cursor.readLittleInt32()  // flags
        if is64Bit {
            _ = try cursor.readLittleInt32()  // reserved
        }

        // Parse load commands
        var segments: [SegmentCommand] = []

        for _ in 0..<ncmds {
            let cmdStart = cursor.offset
            let cmd = try cursor.readLittleInt32()
            let cmdsize = try cursor.readLittleInt32()

            let isSegment64 = (cmd == 0x19)  // LC_SEGMENT_64
            let isSegment32 = (cmd == 0x01)  // LC_SEGMENT

            if isSegment64 || isSegment32 {
                // Extract the segment command data
                let segmentData = data.subdata(in: cmdStart..<(cmdStart + Int(cmdsize)))
                if let segment = try? SegmentCommand(data: segmentData, byteOrder: byteOrder, is64Bit: is64Bit) {
                    segments.append(segment)
                }
            }

            // Skip to next command
            try cursor.reset(to: cmdStart + Int(cmdsize))
        }

        return segments
    }

    public func fileOffset(for address: UInt64) -> Int? {
        // First, check if the address is within the image's own sections
        // The image sections have virtual addresses, but those map to DSC file offsets
        // So we use the DSC translator, not the image translator

        // Use DSC cache translator
        if let offset = cache.translator.fileOffsetInt(for: address) {
            return offset
        }

        // Try sub-caches
        for subCache in cache.subCaches {
            if let offset = subCache.translator.fileOffsetInt(for: address) {
                return offset
            }
        }

        return nil
    }

    public func readData(at offset: Int, count: Int) throws -> Data {
        return try cache.file.data(at: offset, count: count)
    }

    public func readData(atAddress address: UInt64, count: Int) throws -> Data {
        // Use the DSC's readData which handles multi-file caches
        return try cache.readData(at: address, count: count)
    }

    public func readCString(at address: UInt64) -> String? {
        // Use the DSC's readCString which handles multi-file caches
        return cache.readCString(at: address)
    }

    // MARK: - Image-Specific Access

    /// Get the image's segments.
    public var segments: [SegmentCommand] {
        imageSegments
    }

    /// Find a section within the image.
    public func findSection(segment: String, section: String) -> Section? {
        for seg in imageSegments where seg.name == segment || seg.name.hasPrefix(segment) {
            if let sect = seg.section(named: section) {
                return sect
            }
        }
        return nil
    }

    /// Read section data for an image section.
    ///
    /// - Parameter section: The section to read.
    /// - Returns: The section data.
    /// - Throws: If the section cannot be read.
    public func readSectionData(_ section: Section) throws -> Data {
        // The section's addr is a virtual address in DSC space
        // We need to translate it and read from the cache
        guard let offset = cache.translator.fileOffsetInt(for: section.addr) else {
            throw DataProviderError.addressNotMapped(section.addr)
        }
        return try cache.file.data(at: offset, count: Int(section.size))
    }
}
