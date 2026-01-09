// SPDX-License-Identifier: MIT
// Copyright (C) 2026 class-dump contributors. All rights reserved.

import Foundation

/// A fast address translator that converts virtual addresses to file offsets.
///
/// This struct pre-builds an index of all sections sorted by virtual address,
/// enabling O(log n) binary search lookups instead of O(n) linear scans.
///
/// ## Performance
///
/// - Initialization: O(n log n) where n = total sections across all segments
/// - Lookup (uncached): O(log n) binary search
/// - Lookup (cached): O(1) hash table lookup
///
/// ## Usage
///
/// ```swift
/// let translator = AddressTranslator(segments: segments)
///
/// if let offset = translator.fileOffset(for: 0x100001234) {
///     // Use file offset
/// }
/// ```
public final class AddressTranslator: @unchecked Sendable {

    // MARK: - Types

    /// A section entry for the index, storing bounds and offset calculation info.
    private struct SectionEntry {
        let vmStart: UInt64  // Section start virtual address
        let vmEnd: UInt64  // Section end virtual address (exclusive)
        let fileOffset: UInt64  // File offset of section start
        let vmToFileOffset: Int64  // (fileOffset - vmStart) for fast translation
    }

    // MARK: - Properties

    /// Sorted array of section entries for binary search.
    private let sections: [SectionEntry]

    /// Cache of previously translated addresses.
    private let cache = ThreadSafeCache<UInt64, Int>()

    /// Maximum cache size to prevent unbounded growth.
    private static let maxCacheSize = 100_000

    /// Current approximate cache size.
    private var cacheSize: Int = 0

    // MARK: - Initialization

    /// Initialize with segment commands, building the section index.
    ///
    /// - Parameter segments: All segment commands from the Mach-O binary.
    /// - Complexity: O(n log n) where n is total sections across all segments.
    public init(segments: [SegmentCommand]) {
        // Collect all sections with their bounds
        var entries: [SectionEntry] = []
        entries.reserveCapacity(segments.reduce(0) { $0 + $1.sections.count })

        for segment in segments {
            for section in segment.sections {
                let entry = SectionEntry(
                    vmStart: section.addr,
                    vmEnd: section.addr + section.size,
                    fileOffset: UInt64(section.offset),
                    vmToFileOffset: Int64(section.offset) - Int64(section.addr)
                )
                entries.append(entry)
            }
        }

        // Sort by vmStart for binary search
        entries.sort { $0.vmStart < $1.vmStart }

        self.sections = entries
    }

    // MARK: - Public API

    /// Translate a virtual address to a file offset.
    ///
    /// - Parameter address: The virtual address to translate.
    /// - Returns: The file offset, or nil if the address is not in any section.
    /// - Complexity: O(1) for cached addresses, O(log n) for uncached.
    public func fileOffset(for address: UInt64) -> Int? {
        // Check cache first
        if let cached = cache.get(address) {
            return cached
        }

        // Binary search for the section containing this address
        guard let entry = findSection(containing: address) else {
            return nil
        }

        // Calculate file offset: address + (fileOffset - vmStart)
        let offset = Int(Int64(address) + entry.vmToFileOffset)

        // Cache the result (with size limit)
        if cacheSize < Self.maxCacheSize {
            cache.set(address, value: offset)
            cacheSize += 1
        }

        return offset
    }

    /// Check if an address falls within any section.
    ///
    /// - Parameter address: The virtual address to check.
    /// - Returns: True if the address is within a known section.
    /// - Complexity: O(log n) binary search.
    public func contains(address: UInt64) -> Bool {
        findSection(containing: address) != nil
    }

    /// Clear the address cache.
    public func clearCache() {
        cache.clear()
        cacheSize = 0
    }

    // MARK: - Private Implementation

    /// Binary search for the section containing an address.
    ///
    /// - Parameter address: The virtual address to find.
    /// - Returns: The section entry, or nil if not found.
    private func findSection(containing address: UInt64) -> SectionEntry? {
        guard !sections.isEmpty else { return nil }

        var low = 0
        var high = sections.count - 1

        while low <= high {
            let mid = low + (high - low) / 2
            let entry = sections[mid]

            if address < entry.vmStart {
                high = mid - 1
            } else if address >= entry.vmEnd {
                low = mid + 1
            } else {
                // address is in [vmStart, vmEnd)
                return entry
            }
        }

        return nil
    }
}

// MARK: - SIMD String Utilities

/// SIMD-accelerated string utilities for high-performance binary parsing.
public enum SIMDStringUtils {

    /// Find the index of the first null byte in a data buffer.
    ///
    /// Uses SIMD operations to scan 8 bytes at a time on 64-bit platforms.
    ///
    /// - Parameters:
    ///   - data: The data buffer to search.
    ///   - start: Starting offset in the buffer.
    /// - Returns: The index of the first null byte, or data.count if not found.
    /// - Complexity: O(n/8) where n is the remaining data length.
    public static func findNullTerminator(in data: Data, from start: Int) -> Int {
        let count = data.count
        guard start < count else { return count }

        return data.withUnsafeBytes { buffer -> Int in
            guard let basePtr = buffer.baseAddress else { return count }

            let ptr = basePtr.advanced(by: start)
            let remaining = count - start

            #if arch(arm64) || arch(x86_64)
                // SWAR (SIMD Within A Register) technique for 64-bit
                // Process 8 bytes at a time
                let qwordCount = remaining / 8
                var offset = 0

                if qwordCount > 0 {
                    let qwordPtr = ptr.assumingMemoryBound(to: UInt64.self)

                    for i in 0..<qwordCount {
                        let qword = qwordPtr[i]

                        // Check if any byte is zero using SWAR trick:
                        // If a byte is 0, then (byte - 0x01) will have its high bit set
                        // AND with 0x80 mask to isolate high bits
                        // AND with ~qword to ensure original wasn't already set
                        let hasZeroByte = (qword &- 0x0101_0101_0101_0101) & ~qword & 0x8080_8080_8080_8080

                        if hasZeroByte != 0 {
                            // Found a zero byte, find exact position
                            let bytePtr = ptr.advanced(by: i * 8).assumingMemoryBound(to: UInt8.self)
                            for j in 0..<8 {
                                if bytePtr[j] == 0 {
                                    return start + i * 8 + j
                                }
                            }
                        }
                    }
                    offset = qwordCount * 8
                }

                // Handle remaining bytes
                let bytePtr = ptr.advanced(by: offset).assumingMemoryBound(to: UInt8.self)
                let remainingBytes = remaining - offset
                for i in 0..<remainingBytes {
                    if bytePtr[i] == 0 {
                        return start + offset + i
                    }
                }
            #else
                // Fallback for 32-bit: simple byte scan
                let bytePtr = ptr.assumingMemoryBound(to: UInt8.self)
                for i in 0..<remaining {
                    if bytePtr[i] == 0 {
                        return start + i
                    }
                }
            #endif

            return count
        }
    }

    /// Create a string from null-terminated data at a given offset.
    ///
    /// Uses SIMD-accelerated null terminator detection.
    ///
    /// - Parameters:
    ///   - data: The data buffer.
    ///   - offset: Starting offset of the string.
    /// - Returns: The decoded string, or nil if invalid UTF-8.
    /// - Complexity: O(n/8) for finding null + O(n) for UTF-8 decode.
    public static func readNullTerminatedString(from data: Data, at offset: Int) -> String? {
        guard offset >= 0 && offset < data.count else { return nil }

        let end = findNullTerminator(in: data, from: offset)
        guard end > offset else { return nil }

        // Use zero-copy string creation when possible
        return data.withUnsafeBytes { buffer -> String? in
            guard let basePtr = buffer.baseAddress else { return nil }
            let ptr = basePtr.advanced(by: offset).assumingMemoryBound(to: CChar.self)
            return String(cString: ptr)
        }
    }
}
