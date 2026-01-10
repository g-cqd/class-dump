// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

// MARK: - Memory Protection Constants

/// Memory protection flags matching mach/vm_prot.h.
public struct VMProtection: OptionSet, Sendable {
    /// The raw protection bits.
    public let rawValue: UInt32

    /// Creates a protection value from raw bits.
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    /// Read permission.
    public static let read = VMProtection(rawValue: 1 << 0)
    /// Write permission.
    public static let write = VMProtection(rawValue: 1 << 1)
    /// Execute permission.
    public static let execute = VMProtection(rawValue: 1 << 2)

    /// A human-readable representation like "rwx" or "r-x".
    public var description: String {
        var parts: [String] = []
        if contains(.read) {
            parts.append("r")
        }
        else {
            parts.append("-")
        }
        if contains(.write) {
            parts.append("w")
        }
        else {
            parts.append("-")
        }
        if contains(.execute) {
            parts.append("x")
        }
        else {
            parts.append("-")
        }
        return parts.joined()
    }
}

// MARK: - Mapping Info

/// Information about a memory mapping in the dyld_shared_cache.
///
/// The cache is divided into several mappings, typically:
/// - `__TEXT`: Executable code (r-x)
/// - `__DATA`: Read-write data (rw-)
/// - `__DATA_CONST`: Constant data (r--)
/// - `__AUTH`: Authenticated pointers (arm64e)
/// - `__LINKEDIT`: Symbol tables and signatures (r--)
///
/// ## Structure (32 bytes)
///
/// ```c
/// struct dyld_cache_mapping_info {
///     uint64_t    address;
///     uint64_t    size;
///     uint64_t    fileOffset;
///     uint32_t    maxProt;
///     uint32_t    initProt;
/// };
/// ```
///
public struct DyldCacheMappingInfo: Sendable {
    /// The virtual memory address for this mapping.
    public let address: UInt64

    /// The size of this mapping in bytes.
    public let size: UInt64

    /// The file offset where this mapping's data begins.
    public let fileOffset: UInt64

    /// Maximum memory protection allowed.
    public let maxProtection: VMProtection

    /// Initial memory protection.
    public let initialProtection: VMProtection

    /// Size of the raw structure in bytes.
    public static let structureSize = 32

    // MARK: - Computed Properties

    /// The end address of this mapping (exclusive).
    public var endAddress: UInt64 {
        address &+ size
    }

    /// Whether this mapping contains executable code.
    public var isExecutable: Bool {
        initialProtection.contains(.execute)
    }

    /// Whether this mapping is writable.
    public var isWritable: Bool {
        initialProtection.contains(.write)
    }

    /// A descriptive name based on protection flags.
    public var segmentName: String {
        if initialProtection.contains(.execute) {
            return "__TEXT"
        }
        else if initialProtection.contains(.write) {
            return "__DATA"
        }
        else {
            return "__LINKEDIT"
        }
    }

    // MARK: - Address Checking

    /// Check if the given virtual address falls within this mapping.
    ///
    /// - Parameter virtualAddress: The address to check.
    /// - Returns: `true` if the address is within this mapping's range.
    public func contains(address virtualAddress: UInt64) -> Bool {
        virtualAddress >= address && virtualAddress < endAddress
    }

    /// Convert a virtual address to a file offset.
    ///
    /// - Parameter virtualAddress: The virtual address to convert.
    /// - Returns: The file offset, or `nil` if the address is not in this mapping.
    public func fileOffset(for virtualAddress: UInt64) -> UInt64? {
        guard contains(address: virtualAddress) else { return nil }
        return fileOffset + (virtualAddress - address)
    }

    // MARK: - Parsing

    /// Parse a mapping info structure from a memory-mapped file.
    ///
    /// - Parameters:
    ///   - file: The memory-mapped file.
    ///   - offset: The offset to read from.
    /// - Returns: The parsed mapping info.
    /// - Throws: `MemoryMappedFile.Error` if reading fails.
    public static func parse(from file: MemoryMappedFile, at offset: Int) throws -> DyldCacheMappingInfo {
        DyldCacheMappingInfo(
            address: try file.read(UInt64.self, at: offset),
            size: try file.read(UInt64.self, at: offset + 8),
            fileOffset: try file.read(UInt64.self, at: offset + 16),
            maxProtection: VMProtection(rawValue: try file.read(UInt32.self, at: offset + 24)),
            initialProtection: VMProtection(rawValue: try file.read(UInt32.self, at: offset + 28))
        )
    }

    /// Parse all mapping info structures from a cache header.
    ///
    /// - Parameters:
    ///   - file: The memory-mapped file.
    ///   - header: The cache header containing offset and count.
    /// - Returns: An array of mapping info structures.
    /// - Throws: `MemoryMappedFile.Error` if reading fails.
    public static func parseAll(
        from file: MemoryMappedFile,
        header: DyldCacheHeader
    ) throws -> [DyldCacheMappingInfo] {
        var mappings: [DyldCacheMappingInfo] = []
        mappings.reserveCapacity(Int(header.mappingCount))

        var offset = Int(header.mappingOffset)
        for _ in 0..<header.mappingCount {
            let mapping = try parse(from: file, at: offset)
            mappings.append(mapping)
            offset += structureSize
        }

        return mappings
    }
}

// MARK: - Debug Description

extension DyldCacheMappingInfo: CustomStringConvertible {
    /// A human-readable description showing segment name, address range, protection, and file offset.
    public var description: String {
        let prot = initialProtection.description
        let endAddr = String(endAddress, radix: 16, uppercase: true)
        let addr = String(address, radix: 16, uppercase: true)
        let fileOff = String(fileOffset, radix: 16, uppercase: true)
        return "\(segmentName.padding(toLength: 12, withPad: " ", startingAt: 0)) "
            + "0x\(addr.padding(toLength: 16, withPad: "0", startingAt: 0))—"
            + "0x\(endAddr.padding(toLength: 16, withPad: "0", startingAt: 0)) " + "[\(prot)] fileOffset: 0x\(fileOff)"
    }
}
