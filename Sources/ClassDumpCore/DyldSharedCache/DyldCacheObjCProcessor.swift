// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation
import Synchronization

/// Processor for ObjC metadata from images within a dyld_shared_cache.
///
/// This processor is specialized for DSC images, handling:
/// - Address resolution across the entire cache
/// - Shared selector and string references
/// - External class references to other frameworks
///
/// ## Architecture
///
/// The processor is organized using functional programming principles:
/// - **Pure Functions**: Pointer decoding and registry building are pure functions
/// - **Extensions**: Loading logic is separated by concern (protocols, classes, categories, members)
/// - **Caching**: Thread-safe caches prevent redundant parsing
///
/// ## Extensions
///
/// - `DyldCacheObjCProcessor+Protocols.swift` - Protocol loading
/// - `DyldCacheObjCProcessor+Classes.swift` - Class loading
/// - `DyldCacheObjCProcessor+Categories.swift` - Category loading
/// - `DyldCacheObjCProcessor+Members.swift` - Method, property, and ivar loading
///
/// ## Usage
///
/// ```swift
/// let cache = try DyldSharedCache(path: cachePath)
/// guard let foundation = cache.image(named: "Foundation") else { return }
///
/// let processor = try DyldCacheObjCProcessor(cache: cache, image: foundation)
/// let metadata = try await processor.process()
///
/// for cls in metadata.classes {
///     print(cls.name)
/// }
/// ```
///
/// ## Thread Safety
///
/// This class is thread-safe and can be used from multiple tasks concurrently.
/// Internal caches use thread-safe data structures.
///
public final class DyldCacheObjCProcessor: @unchecked Sendable {

    // MARK: - Core State

    /// The shared cache.
    let cache: DyldSharedCache

    /// The image being processed.
    private let image: DyldCacheImageInfo

    /// Data provider for the image.
    let dataProvider: DyldCacheDataProvider

    /// Whether the cache is 64-bit.
    let is64Bit: Bool

    /// Byte order (always little for modern DSC).
    let byteOrder: ByteOrder = .little

    /// Pointer size in bytes.
    var ptrSize: Int { is64Bit ? 8 : 4 }

    /// Shared region base address for pointer decoding.
    private let sharedRegionBase: UInt64

    // MARK: - Caches

    /// Thread-safe cache of loaded classes.
    let classesByAddress = ThreadSafeCache<UInt64, ObjCClass>()

    /// Thread-safe cache of loaded protocols.
    let protocolsByAddress = ThreadSafeCache<UInt64, ObjCProtocol>()

    /// Thread-safe string cache.
    private let stringCache = StringTableCache()

    // MARK: - Small Method Resolution

    /// Base address for relative method selector resolution.
    ///
    /// For small methods in DSC, the selector `nameOffset` is relative to this base address
    /// (when using direct selectors, i.e., iOS 16+). This is obtained from the
    /// `relativeMethodSelectorBaseAddressOffset` field in the ObjC optimization header.
    let relativeMethodSelectorBase: UInt64?

    // MARK: - Initialization

    /// Initialize a processor for an image in a cache.
    ///
    /// - Parameters:
    ///   - cache: The dyld_shared_cache.
    ///   - image: The image to process.
    /// - Throws: If the image cannot be accessed.
    public init(cache: DyldSharedCache, image: DyldCacheImageInfo) throws {
        self.cache = cache
        self.image = image
        self.is64Bit = cache.is64Bit
        self.dataProvider = try DyldCacheDataProvider(cache: cache, image: image)
        self.sharedRegionBase = cache.mappings.first?.address ?? 0
        self.relativeMethodSelectorBase = Self.loadRelativeMethodSelectorBase(from: cache)
    }

    /// Load the relative method selector base address from the cache's ObjC optimization header.
    ///
    /// The `relativeMethodSelectorBaseAddressOffset` field in the ObjC optimization header
    /// is an offset relative to the header's own address. When added to the header's VM address,
    /// it gives the virtual address of the selector strings base.
    ///
    /// On modern caches (macOS 14+/iOS 17+), the ObjC optimization header is embedded in
    /// libobjc.A.dylib's `__TEXT.__objc_opt_ro` section rather than at the cache header's
    /// `objcOptOffset`. This method handles both cases.
    private static func loadRelativeMethodSelectorBase(from cache: DyldSharedCache) -> UInt64? {
        do {
            let result = try cache.objcOptimizationHeaderWithFallback()
            let offset = result.header.relativeMethodSelectorBaseAddressOffset
            guard offset != 0 else { return nil }

            let selectorBaseAddress = UInt64(Int64(result.vmAddress) + offset)

            // Validate address is within a valid mapping
            if cache.translator.fileOffsetInt(for: selectorBaseAddress) != nil {
                return selectorBaseAddress
            }

            return nil
        }
        catch {
            return nil
        }
    }

    // MARK: - Public API

    /// Process all ObjC metadata from the image.
    ///
    /// - Returns: The processed metadata.
    /// - Throws: If processing fails.
    public func process() async throws -> ObjCMetadata {
        // Clear caches for fresh processing
        clearCaches()

        // Load image info
        let imageInfo = try? loadImageInfo()

        // Load metadata with resilient error handling
        let protocols = (try? await loadProtocols()) ?? []
        let classes = (try? await loadClasses()) ?? []
        let categories = (try? await loadCategories()) ?? []

        // Build registries using pure functions
        let structureRegistry = await DyldCacheRegistryBuilder.buildStructureRegistry(
            classes: classes,
            protocols: protocols,
            categories: categories
        )

        let methodSignatureRegistry = await DyldCacheRegistryBuilder.buildMethodSignatureRegistry(
            protocols: protocols
        )

        return ObjCMetadata(
            classes: classes,
            protocols: protocols,
            categories: categories,
            imageInfo: imageInfo,
            structureRegistry: structureRegistry,
            methodSignatureRegistry: methodSignatureRegistry
        )
    }

    /// Clear all caches.
    private func clearCaches() {
        classesByAddress.clear()
        protocolsByAddress.clear()
        stringCache.clear()
    }

    // MARK: - Image Info

    private func loadImageInfo() throws -> ObjC2ImageInfo? {
        guard
            let section = findSection(segment: "__DATA", section: "__objc_imageinfo")
                ?? findSection(segment: "__DATA_CONST", section: "__objc_imageinfo")
        else {
            return nil
        }

        guard section.size >= 8 else { return nil }

        let data = try dataProvider.readSectionData(section)
        var cursor = try DataCursor(data: data)
        return try ObjC2ImageInfo(cursor: &cursor, byteOrder: byteOrder)
    }

    // MARK: - Section Access

    /// Find a section in the image.
    func findSection(segment: String, section: String) -> Section? {
        dataProvider.findSection(segment: segment, section: section)
    }

    /// Read section data.
    func readSectionData(_ section: Section) -> Data? {
        try? dataProvider.readSectionData(section)
    }

    // MARK: - Address Translation

    /// Translate a virtual address to file offset.
    func fileOffset(for address: UInt64) -> Int? {
        dataProvider.fileOffset(for: address)
    }

    /// Read a string at a virtual address using the string cache.
    func readString(at address: UInt64) -> String? {
        guard address != 0 else { return nil }

        return stringCache.getOrRead(at: address) {
            self.dataProvider.readCString(at: address)
        }
    }

    /// Read a pointer at a virtual address.
    func readPointer(at address: UInt64) throws -> UInt64 {
        let data = try dataProvider.readData(atAddress: address, count: ptrSize)
        var cursor = try DataCursor(data: data)

        guard is64Bit else {
            return UInt64(try cursor.readLittleInt32())
        }
        return try cursor.readLittleInt64()
    }

    // MARK: - Pointer Decoding

    /// Decode a chained fixup pointer.
    ///
    /// In modern DSC (arm64e), pointers use different encodings depending on context.
    /// This method tries multiple decoding strategies and validates the result.
    ///
    /// - Parameter rawPointer: The raw pointer value from the binary.
    /// - Returns: The decoded virtual address, or 0 if decoding fails.
    func decodePointer(_ rawPointer: UInt64) -> UInt64 {
        guard rawPointer != 0 else { return 0 }

        // Strategy 1: Check if already a valid direct pointer
        if isInSharedRegion(rawPointer) {
            return rawPointer
        }

        // Check for encoded format (high bits set)
        let highBits = rawPointer >> 32
        if highBits != 0 {
            // Strategy 2: Try 32-bit offset (authenticated pointers)
            if let decoded = try32BitOffset(rawPointer) {
                return decoded
            }

            // Strategy 3: Try 51-bit offset (non-authenticated rebases)
            if let decoded = try51BitOffset(rawPointer) {
                return decoded
            }

            return 0
        }

        // Small value - try adding base
        return tryDirectOffset(rawPointer)
    }

    /// Check if an address is within the shared region.
    private func isInSharedRegion(_ address: UInt64) -> Bool {
        DyldCachePointerDecoder.isInSharedRegion(address, base: sharedRegionBase)
    }

    /// Try to decode as 32-bit offset.
    private func try32BitOffset(_ rawPointer: UInt64) -> UInt64? {
        let offset32 = rawPointer & 0xFFFF_FFFF
        let decoded = sharedRegionBase + offset32

        guard isInSharedRegion(decoded) else { return nil }
        guard cache.translator.fileOffsetInt(for: decoded) != nil else { return nil }

        return decoded
    }

    /// Try to decode as 51-bit offset.
    private func try51BitOffset(_ rawPointer: UInt64) -> UInt64? {
        let offset51 = rawPointer & 0x7_FFFF_FFFF_FFFF
        let decoded = sharedRegionBase + offset51

        guard isInSharedRegion(decoded) else { return nil }
        guard cache.translator.fileOffsetInt(for: decoded) != nil else { return nil }

        return decoded
    }

    /// Try to decode as direct offset from base.
    private func tryDirectOffset(_ rawPointer: UInt64) -> UInt64 {
        let withBase = sharedRegionBase + rawPointer

        guard isInSharedRegion(withBase) else { return rawPointer }
        guard cache.translator.fileOffsetInt(for: withBase) != nil else { return rawPointer }

        return withBase
    }
}
