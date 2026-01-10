// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

/// Translates virtual addresses to file offsets within a dyld_shared_cache.
///
/// Similar to `AddressTranslator` but optimized for DSC mappings.
/// Uses binary search on sorted mappings for O(log n) lookup.
///
/// ## Thread Safety
///
/// This class is thread-safe. The mapping data is immutable after initialization.
///
public final class DyldCacheTranslator: @unchecked Sendable {
    /// Sorted mappings for binary search.
    private let sortedMappings: [DyldCacheMappingInfo]

    /// Cache for recently translated addresses.
    private let cache = MutexCache<UInt64, UInt64>()

    /// Maximum cache size.
    private static let maxCacheSize = 100_000

    /// Initialize with cache mappings.
    ///
    /// - Parameter mappings: The mapping info structures from the cache header.
    public init(mappings: [DyldCacheMappingInfo]) {
        // Sort by address for binary search
        self.sortedMappings = mappings.sorted { $0.address < $1.address }
    }

    // MARK: - Address Translation

    /// Translate a virtual address to a file offset.
    ///
    /// - Parameter address: The virtual address to translate.
    /// - Returns: The file offset, or `nil` if the address is not in any mapping.
    public func fileOffset(for address: UInt64) -> UInt64? {
        // Check cache first
        if let cached = cache.get(address) {
            return cached
        }

        // Binary search for the mapping containing this address
        guard let mapping = findMapping(containing: address) else {
            return nil
        }

        // Calculate file offset
        let offset = mapping.fileOffset + (address - mapping.address)

        // Cache the result
        if cache.count < Self.maxCacheSize {
            cache.set(address, value: offset)
        }

        return offset
    }

    /// Translate a virtual address to a file offset as Int.
    ///
    /// - Parameter address: The virtual address to translate.
    /// - Returns: The file offset as Int, or `nil` if the address is not in any mapping.
    public func fileOffsetInt(for address: UInt64) -> Int? {
        guard let offset = fileOffset(for: address) else { return nil }
        return Int(offset)
    }

    /// Check if an address is within the cache's mapped regions.
    ///
    /// - Parameter address: The virtual address to check.
    /// - Returns: `true` if the address is in a mapped region.
    public func contains(address: UInt64) -> Bool {
        findMapping(containing: address) != nil
    }

    /// Find the mapping containing the given address.
    ///
    /// - Parameter address: The virtual address.
    /// - Returns: The mapping containing this address, or `nil`.
    public func findMapping(containing address: UInt64) -> DyldCacheMappingInfo? {
        // Binary search for the right mapping
        var low = 0
        var high = sortedMappings.count - 1

        while low <= high {
            let mid = (low + high) / 2
            let mapping = sortedMappings[mid]

            if address < mapping.address {
                high = mid - 1
            }
            else if address >= mapping.endAddress {
                low = mid + 1
            }
            else {
                return mapping
            }
        }

        return nil
    }

    // MARK: - Cache Management

    /// Clear the translation cache.
    public func clearCache() {
        cache.clear()
    }

    /// Get cache statistics.
    public var cacheStats: (count: Int, description: String) {
        let count = cache.count
        return (count, "DyldCacheTranslator cache: \(count) entries")
    }

    // MARK: - Debugging

    /// Get all mappings.
    public var mappings: [DyldCacheMappingInfo] {
        sortedMappings
    }

    /// Print mapping summary for debugging.
    public func printMappingSummary() {
        print("DyldCacheTranslator mappings:")
        for (i, mapping) in sortedMappings.enumerated() {
            print("  [\(i)] \(mapping)")
        }
    }
}

// MARK: - Multi-File Support

/// A translator that spans multiple DSC files (main + sub-caches).
///
/// Modern DSC files are split into multiple files (.01, .02, etc.).
/// This translator handles addresses across all of them.
public final class MultiFileTranslator: @unchecked Sendable {
    /// File index and local translator pairs.
    private struct FileEntry {
        let fileIndex: Int
        let translator: DyldCacheTranslator
        let baseAddress: UInt64
        let endAddress: UInt64
    }

    /// Sorted file entries for binary search.
    private let entries: [FileEntry]

    /// File references (memory mapped files).
    public let files: [MemoryMappedFile]

    /// Initialize with multiple cache files.
    ///
    /// - Parameter files: Array of (file, mappings) tuples.
    public init(files: [(file: MemoryMappedFile, mappings: [DyldCacheMappingInfo])]) {
        self.files = files.map { $0.file }

        var allEntries: [FileEntry] = []

        for (index, (_, mappings)) in files.enumerated() {
            guard let minAddr = mappings.map(\.address).min(),
                let maxAddr = mappings.map(\.endAddress).max()
            else {
                continue
            }

            let translator = DyldCacheTranslator(mappings: mappings)
            allEntries.append(
                FileEntry(
                    fileIndex: index,
                    translator: translator,
                    baseAddress: minAddr,
                    endAddress: maxAddr
                )
            )
        }

        // Sort by base address
        self.entries = allEntries.sorted { $0.baseAddress < $1.baseAddress }
    }

    /// Translate a virtual address to a file index and offset.
    ///
    /// - Parameter address: The virtual address.
    /// - Returns: Tuple of (fileIndex, fileOffset), or `nil` if not found.
    public func resolve(address: UInt64) -> (fileIndex: Int, fileOffset: UInt64)? {
        // Binary search for the file containing this address
        var low = 0
        var high = entries.count - 1

        while low <= high {
            let mid = (low + high) / 2
            let entry = entries[mid]

            if address < entry.baseAddress {
                high = mid - 1
            }
            else if address >= entry.endAddress {
                low = mid + 1
            }
            else {
                // Found the file, translate within it
                if let offset = entry.translator.fileOffset(for: address) {
                    return (entry.fileIndex, offset)
                }
                return nil
            }
        }

        return nil
    }

    /// Read data at a virtual address.
    ///
    /// - Parameters:
    ///   - address: The virtual address.
    ///   - count: Number of bytes to read.
    /// - Returns: The data, or `nil` if the address is invalid.
    public func readData(at address: UInt64, count: Int) -> Data? {
        guard let (fileIndex, offset) = resolve(address: address) else {
            return nil
        }

        do {
            return try files[fileIndex].data(at: Int(offset), count: count)
        }
        catch {
            return nil
        }
    }

    /// Read a C string at a virtual address.
    ///
    /// - Parameter address: The virtual address.
    /// - Returns: The string, or `nil` if invalid.
    public func readCString(at address: UInt64) -> String? {
        guard let (fileIndex, offset) = resolve(address: address) else {
            return nil
        }
        return files[fileIndex].readCString(at: Int(offset))
    }
}
