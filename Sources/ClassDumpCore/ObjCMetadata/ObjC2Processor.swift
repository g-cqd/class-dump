// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation
import Synchronization

/// Processor for ObjC 2.0 metadata in Mach-O binaries.
///
/// ## Architecture
///
/// The processor is organized using functional programming principles:
/// - **Pure Parsers**: All parsing logic is implemented as pure functions in extensions
/// - **Composable**: Small parsing functions combine into complex ones
/// - **Isolated State**: Caches use Mutex for thread-safe access
///
/// ## Extensions
///
/// - `ObjC2Processor+Classes.swift` - Class loading
/// - `ObjC2Processor+Protocols.swift` - Protocol loading
/// - `ObjC2Processor+Categories.swift` - Category loading
/// - `ObjC2Processor+Methods.swift` - Method loading (regular + small formats)
/// - `ObjC2Processor+Properties.swift` - Property and ivar loading
/// - `ObjC2Processor+SwiftResolution.swift` - Swift type resolution
///
/// ## Thread Safety
///
/// This class uses thread-safe caches for classes, protocols, and strings, enabling
/// concurrent access during processing. The internal caches (`classesByAddress`,
/// `protocolsByAddress`, `stringCache`) are protected by `Mutex<T>` from the Swift
/// Synchronization framework.
///
/// The `@unchecked Sendable` conformance is provided because the class uses internal
/// synchronization via Mutex-based caches and immutable initialization state.
public final class ObjC2Processor: @unchecked Sendable {

    // MARK: - Core State

    /// The raw binary data.
    let data: Data

    /// All segment commands in the binary.
    private let segments: [SegmentCommand]

    /// Byte order of the binary.
    let byteOrder: ByteOrder

    /// Whether the binary is 64-bit.
    let is64Bit: Bool

    /// Chained fixups for resolving bind ordinals to symbol names.
    private let chainedFixups: ChainedFixups?

    /// Swift metadata for resolving Swift ivar types.
    var swiftMetadata: SwiftMetadata?

    /// Pointer size in bytes.
    var ptrSize: Int { is64Bit ? 8 : 4 }

    // MARK: - Swift Field Lookups

    /// Swift field descriptors indexed by mangled type name.
    var swiftFieldsByMangledName: [String: SwiftFieldDescriptor] = [:]

    /// Swift field descriptors indexed by simple class name.
    var swiftFieldsByClassName: [String: SwiftFieldDescriptor] = [:]

    /// Pre-computed demangled names for field descriptors.
    var demangledNameCache: [String: String] = [:]

    /// All class name variants for comprehensive lookup.
    var swiftFieldsByVariant: [String: SwiftFieldDescriptor] = [:]

    // MARK: - Caches

    /// Thread-safe cache of loaded classes by address.
    let classesByAddress = ThreadSafeCache<UInt64, ObjCClass>()

    /// Thread-safe cache of loaded protocols by address.
    let protocolsByAddress = ThreadSafeCache<UInt64, ObjCProtocol>()

    /// Thread-safe cache for string table lookups.
    private let stringCache = StringTableCache()

    /// Fast address-to-file-offset translator.
    private let addressTranslator: AddressTranslator

    /// Actor-based symbolic resolver for Swift type references.
    let symbolicResolver: SwiftSymbolicResolver

    // MARK: - Constants

    /// Bit mask for 36-bit target address extraction (DYLD_CHAINED_PTR_64 format).
    static let chainedFixupTargetMask36: UInt64 = (1 << 36) - 1

    /// Bit mask for extracting high8 bits (bits 36-43).
    private static let chainedFixupHigh8Mask: UInt64 = 0xFF

    /// Bit mask for clearing low 3 bits (pointer alignment).
    static let pointerAlignmentMask: UInt64 = ~0x7

    // MARK: - Initialization

    /// Initialize with binary data and segment information.
    public init(
        data: Data,
        segments: [SegmentCommand],
        byteOrder: ByteOrder,
        is64Bit: Bool,
        chainedFixups: ChainedFixups? = nil,
        swiftMetadata: SwiftMetadata? = nil
    ) {
        self.data = data
        self.segments = segments
        self.byteOrder = byteOrder
        self.is64Bit = is64Bit
        self.chainedFixups = chainedFixups
        self.swiftMetadata = swiftMetadata

        self.addressTranslator = AddressTranslator(segments: segments)
        self.symbolicResolver = SwiftSymbolicResolver(
            data: data,
            segments: segments,
            byteOrder: byteOrder,
            chainedFixups: chainedFixups
        )

        // Build Swift field lookups using pure function
        if let swift = swiftMetadata {
            let index = SwiftFieldIndexBuilder.buildIndex(from: swift)
            self.swiftFieldsByVariant = index.byVariant
            self.swiftFieldsByMangledName = index.byMangledName
            self.demangledNameCache = index.demangledCache
            self.swiftFieldsByClassName = index.byVariant  // Same data for compatibility
        }
    }

    /// Convenience initializer from a MachOFile.
    public convenience init(machOFile: MachOFile) {
        let fixups = try? machOFile.parseChainedFixups()
        let swift = try? machOFile.parseSwiftMetadata()
        self.init(
            data: machOFile.data,
            segments: machOFile.segments,
            byteOrder: machOFile.byteOrder,
            is64Bit: machOFile.uses64BitABI,
            chainedFixups: fixups,
            swiftMetadata: swift
        )
    }

    // MARK: - Public API

    /// Process all ObjC metadata from the binary (synchronous wrapper).
    ///
    /// This method provides backwards compatibility by wrapping the async version.
    /// For better performance, prefer using `processAsync()` in an async context.
    ///
    /// - Note: This blocks the current thread while waiting for async processing.
    public func process() throws -> ObjCMetadata {
        let resultBox = MutexCache<Int, Result<ObjCMetadata, Error>>()
        let semaphore = DispatchSemaphore(value: 0)

        Task { @Sendable in
            do {
                let metadata = try await self.processAsync()
                resultBox.set(0, value: .success(metadata))
            }
            catch {
                resultBox.set(0, value: .failure(error))
            }
            semaphore.signal()
        }

        semaphore.wait()

        guard let result = resultBox.get(0) else {
            throw ObjCProcessorError.invalidData("Failed to retrieve processing result")
        }
        return try result.get()
    }

    /// Process all ObjC metadata from the binary using parallel loading.
    ///
    /// This async version uses structured concurrency to load classes and protocols
    /// in parallel, providing significant speedup on multi-core systems.
    ///
    /// - Returns: The processed ObjC metadata.
    /// - Throws: If processing fails.
    /// - Complexity: O(n/p) where n = total items and p = available parallelism.
    public func processAsync() async throws -> ObjCMetadata {
        clearCaches()

        // Load image info first
        let imageInfo = try? loadImageInfo()

        // Load in dependency order: protocols → classes → categories
        let protocols = try await loadProtocolsAsync()
        let classes = try await loadClassesAsync()
        let categories = try await loadCategoriesAsync()

        // Build registries
        let structureRegistry = await buildStructureRegistry(
            classes: classes,
            protocols: protocols,
            categories: categories
        )
        let methodSignatureRegistry = await buildMethodSignatureRegistry(protocols: protocols)

        return ObjCMetadata(
            classes: classes,
            protocols: protocols,
            categories: categories,
            imageInfo: imageInfo,
            structureRegistry: structureRegistry,
            methodSignatureRegistry: methodSignatureRegistry
        )
    }

    // MARK: - Streaming API

    /// Process ObjC metadata as a stream for memory-efficient handling.
    ///
    /// Yields metadata items as they're processed, enabling bounded memory
    /// usage for arbitrarily large binaries.
    ///
    /// - Parameter includeProgress: Whether to yield progress updates.
    /// - Returns: An async sequence of metadata items.
    public func stream(includeProgress: Bool = false) -> AsyncStream<ObjCMetadataItem> {
        AsyncStream { continuation in
            Task {
                do {
                    try await self.streamProcessing(
                        continuation: continuation,
                        includeProgress: includeProgress
                    )
                    continuation.finish()
                }
                catch {
                    continuation.finish()
                }
            }
        }
    }

    // MARK: - Section & Address Utilities

    /// Find a section by segment and section name.
    func findSection(segment segmentName: String, section sectionName: String) -> Section? {
        for segment in segments where segment.name == segmentName || segment.name.hasPrefix(segmentName) {
            if let section = segment.section(named: sectionName) {
                return section
            }
        }
        return nil
    }

    /// Read data from a section.
    func readSectionData(_ section: Section) -> Data? {
        let start = Int(section.offset)
        let end = start + Int(section.size)
        guard start >= 0 && end <= data.count else { return nil }
        return data.subdata(in: start..<end)
    }

    /// Translate a virtual address to a file offset.
    func fileOffset(for address: UInt64) -> Int? {
        addressTranslator.fileOffset(for: address)
    }

    /// Read a null-terminated string at the given virtual address.
    func readString(at address: UInt64) -> String? {
        guard address != 0 else { return nil }

        return stringCache.getOrRead(at: address) {
            guard let offset = self.fileOffset(for: address) else { return nil }
            guard offset >= 0 && offset < self.data.count else { return nil }
            return SIMDStringUtils.readNullTerminatedString(from: self.data, at: offset)
        }
    }

    /// Read a pointer value at the given virtual address.
    func readPointer(at address: UInt64) throws -> UInt64 {
        guard let offset = fileOffset(for: address) else {
            throw ObjCProcessorError.invalidAddress(address)
        }

        var cursor = try DataCursor(data: data, offset: offset)

        guard is64Bit else {
            let value =
                byteOrder == .little
                ? try cursor.readLittleInt32()
                : try cursor.readBigInt32()
            return UInt64(value)
        }
        let rawValue =
            byteOrder == .little
            ? try cursor.readLittleInt64()
            : try cursor.readBigInt64()
        return decodeChainedFixupPointer(rawValue)
    }

    // MARK: - Chained Fixup Decoding

    /// Decode a raw pointer value, returning either an address or bind info.
    func decodePointerWithBindInfo(_ rawPointer: UInt64) -> PointerDecodeResult {
        if let fixups = chainedFixups {
            let result = fixups.decodePointer(rawPointer)
            switch result {
                case .rebase(let target):
                    return .address(target)
                case .bind(let ordinal, _):
                    if let symbolName = fixups.symbolName(forOrdinal: ordinal) {
                        let name = symbolName.hasPrefix("_") ? String(symbolName.dropFirst()) : symbolName
                        return .bindSymbol(name)
                    }
                    return .bindOrdinal(ordinal)
                case .notFixup:
                    return .address(rawPointer)
            }
        }
        return .address(decodeChainedFixupPointer(rawPointer))
    }

    /// Decode a chained fixup pointer to get the actual target address.
    ///
    /// Modern arm64/arm64e binaries use chained fixups where pointers are encoded
    /// with metadata in high bits and the target address in low bits.
    func decodeChainedFixupPointer(_ rawPointer: UInt64) -> UInt64 {
        let highBits = rawPointer >> 36
        let hasChainedFixup = highBits != 0

        guard hasChainedFixup else { return rawPointer }

        // Check bind flag (bit 63)
        let bindFlag = (rawPointer >> 63) & 1
        if bindFlag == 1 {
            return 0  // External symbol bind - can't resolve statically
        }

        // Extract 36-bit target
        let target = rawPointer & Self.chainedFixupTargetMask36

        // Handle high8 bits (bits 36-43)
        let high8 = (rawPointer >> 36) & Self.chainedFixupHigh8Mask
        if high8 != 0 {
            return target | (high8 << 56)
        }

        return target
    }

    // MARK: - Address Collection

    /// Collect addresses from a section containing pointers.
    ///
    /// Pure function that reads a section and extracts all non-zero addresses.
    ///
    /// - Parameters:
    ///   - sectionName: Name of the section to read.
    ///   - segmentNames: Segment names to search (in order).
    /// - Returns: Array of decoded addresses.
    /// - Throws: `DataCursorError` if reading section data fails.
    func collectAddresses(
        fromSection sectionName: String,
        inSegments segmentNames: [String]
    ) throws -> [UInt64] {
        var section: Section?
        for segmentName in segmentNames {
            if let found = findSection(segment: segmentName, section: sectionName) {
                section = found
                break
            }
        }

        guard let section = section else { return [] }
        guard let sectionData = readSectionData(section) else { return [] }

        var cursor = try DataCursor(data: sectionData, offset: 0)
        var addresses: [UInt64] = []

        while cursor.offset < sectionData.count {
            let rawAddress: UInt64
            if is64Bit {
                rawAddress =
                    byteOrder == .little
                    ? try cursor.readLittleInt64()
                    : try cursor.readBigInt64()
            }
            else {
                let value =
                    byteOrder == .little
                    ? try cursor.readLittleInt32()
                    : try cursor.readBigInt32()
                rawAddress = UInt64(value)
            }

            let address = decodeChainedFixupPointer(rawAddress)
            if address != 0 {
                addresses.append(address)
            }
        }

        return addresses
    }

    // MARK: - Private Implementation

    /// Clear all caches before processing.
    private func clearCaches() {
        classesByAddress.clear()
        protocolsByAddress.clear()
        stringCache.clear()
    }

    /// Load image info from the binary.
    private func loadImageInfo() throws -> ObjC2ImageInfo? {
        guard
            let section = findSection(segment: "__DATA", section: "__objc_imageinfo")
                ?? findSection(segment: "__DATA_CONST", section: "__objc_imageinfo")
        else {
            return nil
        }

        guard section.size >= 8 else { return nil }

        var cursor = try DataCursor(data: data, offset: Int(section.offset))
        return try ObjC2ImageInfo(cursor: &cursor, byteOrder: byteOrder)
    }

    /// Build a structure registry from all type encodings.
    private func buildStructureRegistry(
        classes: [ObjCClass],
        protocols: [ObjCProtocol],
        categories: [ObjCCategory]
    ) async -> StructureRegistry {
        let registry = StructureRegistry()

        // Register from classes
        for objcClass in classes {
            for ivar in objcClass.instanceVariables {
                if let parsedType = ivar.parsedType {
                    await registry.register(parsedType)
                }
            }
            for property in objcClass.properties {
                if let parsedType = property.parsedType {
                    await registry.register(parsedType)
                }
            }
            for method in objcClass.classMethods + objcClass.instanceMethods {
                await registerMethodTypes(method, in: registry)
            }
        }

        // Register from protocols
        for proto in protocols {
            for property in proto.properties {
                if let parsedType = property.parsedType {
                    await registry.register(parsedType)
                }
            }
            let allMethods =
                proto.classMethods + proto.instanceMethods
                + proto.optionalClassMethods + proto.optionalInstanceMethods
            for method in allMethods {
                await registerMethodTypes(method, in: registry)
            }
        }

        // Register from categories
        for category in categories {
            for property in category.properties {
                if let parsedType = property.parsedType {
                    await registry.register(parsedType)
                }
            }
            for method in category.classMethods + category.instanceMethods {
                await registerMethodTypes(method, in: registry)
            }
        }

        return registry
    }

    /// Register structures from a method's type encoding.
    private func registerMethodTypes(_ method: ObjCMethod, in registry: StructureRegistry) async {
        guard let types = try? ObjCType.parseMethodType(method.typeEncoding) else { return }
        for methodType in types {
            await registry.register(methodType.type)
        }
    }

    /// Build a method signature registry from protocols.
    private func buildMethodSignatureRegistry(protocols: [ObjCProtocol]) async -> MethodSignatureRegistry {
        let registry = MethodSignatureRegistry()
        for proto in protocols {
            await registry.registerProtocol(proto)
        }
        return registry
    }

    /// Internal streaming implementation.
    private func streamProcessing(
        continuation: AsyncStream<ObjCMetadataItem>.Continuation,
        includeProgress: Bool
    ) async throws {
        clearCaches()

        // Yield image info first
        if let imageInfo = try? loadImageInfo() {
            continuation.yield(.imageInfo(imageInfo))
        }

        // Stream protocols
        let protocolAddresses = try collectProtocolAddresses()
        try await streamItems(
            addresses: protocolAddresses,
            phase: .protocols,
            includeProgress: includeProgress,
            continuation: continuation
        ) { address in
            if let proto = try await self.loadProtocolAsync(at: address) {
                return .protocol(proto)
            }
            return nil
        }

        // Stream classes
        let classAddresses = try collectClassAddresses()
        try await streamItems(
            addresses: classAddresses,
            phase: .classes,
            includeProgress: includeProgress,
            continuation: continuation
        ) { address in
            if let cls = try await self.loadClassAsync(at: address) {
                return .class(cls)
            }
            return nil
        }

        // Stream categories
        let categoryAddresses = try collectCategoryAddresses()
        try await streamItems(
            addresses: categoryAddresses,
            phase: .categories,
            includeProgress: includeProgress,
            continuation: continuation
        ) { address in
            if let category = try await self.loadCategoryAsync(at: address) {
                return .category(category)
            }
            return nil
        }

        if includeProgress {
            let total = protocolAddresses.count + classAddresses.count + categoryAddresses.count
            continuation.yield(.progress(ProcessingProgress(phase: .complete, processed: total, total: total)))
        }
    }

    /// Stream items from a list of addresses.
    private func streamItems(
        addresses: [UInt64],
        phase: ProcessingPhase,
        includeProgress: Bool,
        continuation: AsyncStream<ObjCMetadataItem>.Continuation,
        loader: (UInt64) async throws -> ObjCMetadataItem?
    ) async throws {
        if includeProgress {
            continuation.yield(.progress(ProcessingProgress(phase: phase, processed: 0, total: addresses.count)))
        }

        for (index, address) in addresses.enumerated() {
            if let item = try await loader(address) {
                continuation.yield(item)
            }

            if includeProgress && (index + 1) % 50 == 0 {
                continuation.yield(
                    .progress(
                        ProcessingProgress(
                            phase: phase,
                            processed: index + 1,
                            total: addresses.count
                        )
                    )
                )
            }
        }
    }
}
