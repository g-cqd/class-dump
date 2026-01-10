import Foundation
import Synchronization

/// Errors that can occur during ObjC metadata processing.
public enum ObjCProcessorError: Error, Sendable {
    case sectionNotFound(String)
    case invalidAddress(UInt64)
    case invalidData(String)
    case invalidPointer(UInt64)
}

/// Result of processing ObjC metadata from a binary.
public struct ObjCMetadata: Sendable {
    /// The processed classes.
    public let classes: [ObjCClass]

    /// The processed protocols.
    public let protocols: [ObjCProtocol]

    /// The processed categories.
    public let categories: [ObjCCategory]

    /// The image info (if available).
    public let imageInfo: ObjC2ImageInfo?

    /// Registry of detected structures.
    public let structureRegistry: StructureRegistry

    /// Registry of method signatures.
    public let methodSignatureRegistry: MethodSignatureRegistry

    /// Initialize metadata results.
    public init(
        classes: [ObjCClass] = [],
        protocols: [ObjCProtocol] = [],
        categories: [ObjCCategory] = [],
        imageInfo: ObjC2ImageInfo? = nil,
        structureRegistry: StructureRegistry? = nil,
        methodSignatureRegistry: MethodSignatureRegistry? = nil
    ) {
        self.classes = classes
        self.protocols = protocols
        self.categories = categories
        self.imageInfo = imageInfo
        self.structureRegistry = structureRegistry ?? StructureRegistry()
        self.methodSignatureRegistry = methodSignatureRegistry ?? MethodSignatureRegistry()
    }

    /// Returns a sorted copy of this metadata.
    public func sorted() -> ObjCMetadata {
        ObjCMetadata(
            classes: classes.sorted(),
            protocols: protocols.sorted(),
            categories: categories.sorted(),
            imageInfo: imageInfo,
            structureRegistry: structureRegistry,
            methodSignatureRegistry: methodSignatureRegistry
        )
    }
}

// MARK: - Streaming API

/// A single item from the streaming metadata processor.
///
/// Use this with `ObjC2Processor.stream()` to process large binaries with
/// bounded memory usage. Items are yielded as they're processed.
public enum ObjCMetadataItem: Sendable {
    /// The binary's image info (always first if present).
    case imageInfo(ObjC2ImageInfo)

    /// A protocol definition.
    case `protocol`(ObjCProtocol)

    /// A class definition.
    case `class`(ObjCClass)

    /// A category definition.
    case category(ObjCCategory)

    /// Processing progress update.
    case progress(ProcessingProgress)
}

/// Progress information during streaming processing.
public struct ProcessingProgress: Sendable {
    /// Current phase of processing.
    public let phase: ProcessingPhase

    /// Number of items processed so far in this phase.
    public let processed: Int

    /// Total items to process in this phase (if known).
    public let total: Int?

    /// Percentage complete (0-100) if total is known.
    public var percentComplete: Int? {
        guard let total = total, total > 0 else { return nil }
        return min(100, (processed * 100) / total)
    }
}

/// Processing phases for streaming.
public enum ProcessingPhase: String, Sendable {
    case protocols = "Loading protocols"
    case classes = "Loading classes"
    case categories = "Loading categories"
    case complete = "Complete"
}

/// Processor for ObjC 2.0 metadata in Mach-O binaries.
///
/// ## Thread Safety
///
/// This class uses thread-safe caches for classes, protocols, and strings, enabling
/// concurrent access during processing. The internal caches (`classesByAddress`,
/// `protocolsByAddress`, `stringCache`) are protected by `Mutex<T>` from the Swift
/// Synchronization framework - providing automatic `Sendable` conformance and
/// minimal overhead compared to actors.
///
/// **Usage Pattern**: Create an instance, call `process()` or `processAsync()`,
/// then safely share the resulting `ObjCMetadata` struct (which is `Sendable`).
///
/// The `@unchecked Sendable` conformance is provided because the class uses internal
/// synchronization via Mutex-based caches and immutable initialization state.
public final class ObjC2Processor: @unchecked Sendable {
    /// The raw binary data.
    private let data: Data

    /// All segment commands in the binary.
    private let segments: [SegmentCommand]

    /// Byte order of the binary.
    private let byteOrder: ByteOrder

    /// Whether the binary is 64-bit.
    private let is64Bit: Bool

    /// Chained fixups for resolving bind ordinals to symbol names.
    private let chainedFixups: ChainedFixups?

    /// Swift metadata for resolving Swift ivar types.
    private var swiftMetadata: SwiftMetadata?

    /// Swift field descriptors indexed by mangled type name.
    private var swiftFieldsByMangledName: [String: SwiftFieldDescriptor] = [:]

    /// Swift field descriptors indexed by simple class name (for ObjC lookup).
    private var swiftFieldsByClassName: [String: SwiftFieldDescriptor] = [:]

    /// Pre-computed demangled names for field descriptors (avoids re-demangling during lookup).
    ///
    /// Maps mangled type name → demangled type name.
    private var demangledNameCache: [String: String] = [:]

    /// All class name variants for comprehensive lookup (includes suffixes and components).
    ///
    /// This enables O(1) lookup instead of O(d) linear scan with demangling.
    private var swiftFieldsByVariant: [String: SwiftFieldDescriptor] = [:]

    // MARK: - Chained Fixup Constants

    /// Pre-computed bit mask for 36-bit target address extraction (DYLD_CHAINED_PTR_64 format).
    ///
    /// Using a static constant avoids recomputation on every pointer decode.
    private static let chainedFixupTargetMask36: UInt64 = (1 << 36) - 1  // 0xFFFFFFFFF

    /// Pre-computed bit mask for extracting high8 bits (bits 36-43).
    private static let chainedFixupHigh8Mask: UInt64 = 0xFF

    /// Pre-computed bit mask for clearing low 3 bits (pointer alignment).
    private static let pointerAlignmentMask: UInt64 = ~0x7

    /// Pointer size in bytes.
    private var ptrSize: Int {
        is64Bit ? 8 : 4
    }

    /// Thread-safe cache of loaded classes by address.
    ///
    /// Uses Mutex<T> from Swift Synchronization framework for thread safety.
    private let classesByAddress = ThreadSafeCache<UInt64, ObjCClass>()

    /// Thread-safe cache of loaded protocols by address (for uniquing).
    ///
    /// Uses Mutex<T> from Swift Synchronization framework for thread safety.
    private let protocolsByAddress = ThreadSafeCache<UInt64, ObjCProtocol>()

    /// Thread-safe cache for string table lookups (reduces repeated reads).
    ///
    /// Uses Mutex<T> from Swift Synchronization framework for thread safety.
    private let stringCache = StringTableCache()

    /// Fast address-to-file-offset translator with binary search.
    private let addressTranslator: AddressTranslator

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

        // Initialize the address translator with binary search index
        self.addressTranslator = AddressTranslator(segments: segments)

        // Initialize the symbolic resolver (actor) for thread-safe access
        self.symbolicResolver = SwiftSymbolicResolver(
            data: data,
            segments: segments,
            byteOrder: byteOrder,
            chainedFixups: chainedFixups
        )

        // Build Swift field lookups with comprehensive indexing for O(1) lookup
        // Note: Uses simple demangling during init since resolver is async
        if let swift = swiftMetadata {
            buildSwiftFieldIndex(swift: swift)
        }
    }

    /// Build comprehensive Swift field descriptor index for O(1) lookups.
    ///
    /// This pre-computes and caches all name variants during initialization to avoid
    /// expensive demangling operations during lookup. The index includes:
    /// - Raw mangled type names
    /// - Demangled names (cached)
    /// - All suffix variants (e.g., for "A.B.C", also indexes "B.C" and "C")
    /// - Address-based lookups from SwiftType metadata
    ///
    /// Note: Symbolic resolution is done at runtime via the actor-based resolver
    /// since it requires async access.
    ///
    /// - Complexity: O(d * k) where d = field descriptors, k = avg name components
    private func buildSwiftFieldIndex(swift: SwiftMetadata) {
        // Build address-to-name mappings from SwiftTypes
        var typeNameByAddress: [UInt64: String] = [:]
        var fullNameByAddress: [UInt64: String] = [:]
        for swiftType in swift.types {
            typeNameByAddress[swiftType.address] = swiftType.name
            fullNameByAddress[swiftType.address] = swiftType.fullName
        }

        // Helper to add all suffix variants of a dotted name to the index
        func indexAllVariants(_ name: String, descriptor: SwiftFieldDescriptor) {
            guard !name.isEmpty && !name.hasPrefix("/*") else { return }

            // Index the full name
            swiftFieldsByVariant[name] = descriptor
            swiftFieldsByClassName[name] = descriptor

            // If it contains dots, index all suffix variants
            if name.contains(".") {
                let components = name.split(separator: ".")
                // Index progressively shorter suffixes: A.B.C → B.C → C
                for i in 1..<components.count {
                    let suffix = components[i...].joined(separator: ".")
                    swiftFieldsByVariant[suffix] = descriptor
                    swiftFieldsByClassName[suffix] = descriptor
                }
                // Also index just the last component
                if let last = components.last {
                    swiftFieldsByVariant[String(last)] = descriptor
                    swiftFieldsByClassName[String(last)] = descriptor
                }
            }
        }

        for fd in swift.fieldDescriptors {
            // Index by raw mangled type name
            swiftFieldsByMangledName[fd.mangledTypeName] = fd

            // Pre-demangle and cache the result using SwiftDemangler (sync)
            let demangled = SwiftDemangler.extractTypeName(fd.mangledTypeName)
            if !demangled.isEmpty {
                demangledNameCache[fd.mangledTypeName] = demangled
                indexAllVariants(demangled, descriptor: fd)
            }

            // Index by address mappings from SwiftType metadata
            if let typeName = typeNameByAddress[fd.address] {
                indexAllVariants(typeName, descriptor: fd)
            }
            if let fullName = fullNameByAddress[fd.address] {
                indexAllVariants(fullName, descriptor: fd)
            }

            // Extract and index class name from mangled format if present
            if fd.mangledTypeName.hasPrefix("_Tt") {
                if let (module, className) = SwiftDemangler.demangleClassName(fd.mangledTypeName) {
                    indexAllVariants("\(module).\(className)", descriptor: fd)
                    indexAllVariants(className, descriptor: fd)
                }
            }
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
    /// - Note: This blocks the current thread while waiting for async processing to complete.
    public func process() throws -> ObjCMetadata {
        // Use a Mutex-protected box to ensure proper memory visibility across threads.
        // The semaphore provides ordering but Swift's memory model needs
        // explicit synchronization for value visibility.
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

    // MARK: - Async Parallel Processing

    /// Process all ObjC metadata from the binary using parallel loading.
    ///
    /// This async version uses structured concurrency to load classes and protocols
    /// in parallel, providing significant speedup on multi-core systems.
    ///
    /// - Returns: The processed ObjC metadata.
    /// - Throws: If processing fails.
    /// - Complexity: O(n/p) where n = total items and p = available parallelism.
    public func processAsync() async throws -> ObjCMetadata {
        // Clear caches (sync - Mutex-based)
        classesByAddress.clear()
        protocolsByAddress.clear()
        stringCache.clear()

        // Load image info first (quick, not worth parallelizing)
        let imageInfo = try? loadImageInfo()

        // Load protocols first (they may be referenced by classes) - parallel
        let protocols = try await loadProtocolsAsync()

        // Load classes - parallel
        let classes = try await loadClassesAsync()

        // Load categories (typically few, sequential is fine)
        let categories = try await loadCategoriesAsync()

        // Build structure registry from all type encodings
        let structureRegistry = await buildStructureRegistry(
            classes: classes,
            protocols: protocols,
            categories: categories
        )

        // Build method signature registry from protocols
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

    // MARK: - Streaming Processing

    /// Process ObjC metadata as a stream for memory-efficient handling of large binaries.
    ///
    /// This method yields metadata items as they're processed, allowing callers to:
    /// - Process arbitrarily large binaries with bounded memory
    /// - Output items immediately without waiting for full processing
    /// - Cancel processing early if desired
    ///
    /// ## Example
    /// ```swift
    /// for await item in processor.stream() {
    ///     switch item {
    ///     case .protocol(let proto):
    ///         print("Protocol: \(proto.name)")
    ///     case .class(let cls):
    ///         print("Class: \(cls.name)")
    ///     case .category(let cat):
    ///         print("Category: \(cat.name)")
    ///     case .progress(let progress):
    ///         print("\(progress.phase.rawValue): \(progress.processed)/\(progress.total ?? 0)")
    ///     case .imageInfo:
    ///         break
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter includeProgress: Whether to yield progress updates (default: false).
    /// - Returns: An async sequence of metadata items.
    public func stream(includeProgress: Bool = false) -> AsyncStream<ObjCMetadataItem> {
        AsyncStream { continuation in
            Task {
                do {
                    try await self.streamProcessing(continuation: continuation, includeProgress: includeProgress)
                    continuation.finish()
                }
                catch {
                    continuation.finish()
                }
            }
        }
    }

    /// Internal streaming implementation.
    private func streamProcessing(
        continuation: AsyncStream<ObjCMetadataItem>.Continuation,
        includeProgress: Bool
    ) async throws {
        // Clear caches
        classesByAddress.clear()
        protocolsByAddress.clear()
        stringCache.clear()

        // Yield image info first
        if let imageInfo = try? loadImageInfo() {
            continuation.yield(.imageInfo(imageInfo))
        }

        // Stream protocols
        let protocolAddresses = try collectProtocolAddresses()
        let protocolTotal = protocolAddresses.count

        if includeProgress {
            continuation.yield(
                .progress(
                    ProcessingProgress(
                        phase: .protocols,
                        processed: 0,
                        total: protocolTotal
                    )
                )
            )
        }

        for (index, address) in protocolAddresses.enumerated() {
            if let proto = try await loadProtocolAsync(at: address) {
                continuation.yield(.protocol(proto))
            }

            if includeProgress && (index + 1) % 50 == 0 {
                continuation.yield(
                    .progress(
                        ProcessingProgress(
                            phase: .protocols,
                            processed: index + 1,
                            total: protocolTotal
                        )
                    )
                )
            }
        }

        // Stream classes
        let classAddresses = try collectClassAddresses()
        let classTotal = classAddresses.count

        if includeProgress {
            continuation.yield(
                .progress(
                    ProcessingProgress(
                        phase: .classes,
                        processed: 0,
                        total: classTotal
                    )
                )
            )
        }

        for (index, address) in classAddresses.enumerated() {
            if let cls = try await loadClassAsync(at: address) {
                continuation.yield(.class(cls))
            }

            if includeProgress && (index + 1) % 50 == 0 {
                continuation.yield(
                    .progress(
                        ProcessingProgress(
                            phase: .classes,
                            processed: index + 1,
                            total: classTotal
                        )
                    )
                )
            }
        }

        // Stream categories
        let categoryAddresses = try collectCategoryAddresses()
        let categoryTotal = categoryAddresses.count

        if includeProgress {
            continuation.yield(
                .progress(
                    ProcessingProgress(
                        phase: .categories,
                        processed: 0,
                        total: categoryTotal
                    )
                )
            )
        }

        for (index, address) in categoryAddresses.enumerated() {
            if let category = try await loadCategoryAsync(at: address) {
                continuation.yield(.category(category))
            }

            if includeProgress && (index + 1) % 50 == 0 {
                continuation.yield(
                    .progress(
                        ProcessingProgress(
                            phase: .categories,
                            processed: index + 1,
                            total: categoryTotal
                        )
                    )
                )
            }
        }

        if includeProgress {
            continuation.yield(
                .progress(
                    ProcessingProgress(
                        phase: .complete,
                        processed: protocolTotal + classTotal + categoryTotal,
                        total: protocolTotal + classTotal + categoryTotal
                    )
                )
            )
        }
    }

    /// Load all protocol addresses from the binary.
    private func collectProtocolAddresses() throws -> [UInt64] {
        guard
            let section = findSection(segment: "__DATA", section: "__objc_protolist")
                ?? findSection(segment: "__DATA_CONST", section: "__objc_protolist")
        else {
            return []
        }

        guard let sectionData = readSectionData(section) else {
            return []
        }

        var cursor = try DataCursor(data: sectionData, offset: 0)
        var addresses: [UInt64] = []

        while cursor.offset < sectionData.count {
            let rawAddress: UInt64
            if is64Bit {
                rawAddress = byteOrder == .little ? try cursor.readLittleInt64() : try cursor.readBigInt64()
            }
            else {
                let value = byteOrder == .little ? try cursor.readLittleInt32() : try cursor.readBigInt32()
                rawAddress = UInt64(value)
            }

            let protocolAddress = decodeChainedFixupPointer(rawAddress)
            if protocolAddress != 0 {
                addresses.append(protocolAddress)
            }
        }

        return addresses
    }

    /// Load all class addresses from the binary.
    private func collectClassAddresses() throws -> [UInt64] {
        guard
            let section = findSection(segment: "__DATA", section: "__objc_classlist")
                ?? findSection(segment: "__DATA_CONST", section: "__objc_classlist")
        else {
            return []
        }

        guard let sectionData = readSectionData(section) else {
            return []
        }

        var cursor = try DataCursor(data: sectionData, offset: 0)
        var addresses: [UInt64] = []

        while cursor.offset < sectionData.count {
            let rawAddress: UInt64
            if is64Bit {
                rawAddress = byteOrder == .little ? try cursor.readLittleInt64() : try cursor.readBigInt64()
            }
            else {
                let value = byteOrder == .little ? try cursor.readLittleInt32() : try cursor.readBigInt32()
                rawAddress = UInt64(value)
            }

            let classAddress = decodeChainedFixupPointer(rawAddress)
            if classAddress != 0 {
                addresses.append(classAddress)
            }
        }

        return addresses
    }

    /// Load all category addresses from the binary.
    private func collectCategoryAddresses() throws -> [UInt64] {
        guard
            let section = findSection(segment: "__DATA", section: "__objc_catlist")
                ?? findSection(segment: "__DATA_CONST", section: "__objc_catlist")
        else {
            return []
        }

        guard let sectionData = readSectionData(section) else {
            return []
        }

        var cursor = try DataCursor(data: sectionData, offset: 0)
        var addresses: [UInt64] = []

        while cursor.offset < sectionData.count {
            let rawAddress: UInt64
            if is64Bit {
                rawAddress = byteOrder == .little ? try cursor.readLittleInt64() : try cursor.readBigInt64()
            }
            else {
                let value = byteOrder == .little ? try cursor.readLittleInt32() : try cursor.readBigInt32()
                rawAddress = UInt64(value)
            }

            let categoryAddress = decodeChainedFixupPointer(rawAddress)
            if categoryAddress != 0 {
                addresses.append(categoryAddress)
            }
        }

        return addresses
    }

    /// Load protocols in parallel using structured concurrency.
    private func loadProtocolsAsync() async throws -> [ObjCProtocol] {
        let addresses = try collectProtocolAddresses()

        // Use TaskGroup for parallel loading with actor-based caching
        return try await withThrowingTaskGroup(of: ObjCProtocol?.self, returning: [ObjCProtocol].self) { group in
            for address in addresses {
                group.addTask {
                    try await self.loadProtocolAsync(at: address)
                }
            }

            var protocols: [ObjCProtocol] = []
            protocols.reserveCapacity(addresses.count)

            for try await proto in group {
                if let proto = proto {
                    protocols.append(proto)
                }
            }

            return protocols
        }
    }

    /// Load classes in parallel using structured concurrency.
    private func loadClassesAsync() async throws -> [ObjCClass] {
        let addresses = try collectClassAddresses()

        // Use TaskGroup for parallel loading with actor-based caching
        return try await withThrowingTaskGroup(of: ObjCClass?.self, returning: [ObjCClass].self) { group in
            for address in addresses {
                group.addTask {
                    try await self.loadClassAsync(at: address)
                }
            }

            var classes: [ObjCClass] = []
            classes.reserveCapacity(addresses.count)

            for try await aClass in group {
                if let aClass = aClass {
                    classes.append(aClass)
                }
            }

            return classes
        }
    }

    /// Build a structure registry from all type encodings in the metadata.
    private func buildStructureRegistry(
        classes: [ObjCClass],
        protocols: [ObjCProtocol],
        categories: [ObjCCategory]
    ) async -> StructureRegistry {
        let registry = StructureRegistry()

        // Register structures from classes
        for objcClass in classes {
            // From instance variables
            for ivar in objcClass.instanceVariables {
                if let parsedType = ivar.parsedType {
                    await registry.register(parsedType)
                }
            }

            // From properties
            for property in objcClass.properties {
                if let parsedType = property.parsedType {
                    await registry.register(parsedType)
                }
            }

            // From methods
            for method in objcClass.classMethods {
                await registerMethodTypes(method, in: registry)
            }
            for method in objcClass.instanceMethods {
                await registerMethodTypes(method, in: registry)
            }
        }

        // Register structures from protocols
        for proto in protocols {
            for property in proto.properties {
                if let parsedType = property.parsedType {
                    await registry.register(parsedType)
                }
            }
            for method in proto.classMethods {
                await registerMethodTypes(method, in: registry)
            }
            for method in proto.instanceMethods {
                await registerMethodTypes(method, in: registry)
            }
            for method in proto.optionalClassMethods {
                await registerMethodTypes(method, in: registry)
            }
            for method in proto.optionalInstanceMethods {
                await registerMethodTypes(method, in: registry)
            }
        }

        // Register structures from categories
        for category in categories {
            for property in category.properties {
                if let parsedType = property.parsedType {
                    await registry.register(parsedType)
                }
            }
            for method in category.classMethods {
                await registerMethodTypes(method, in: registry)
            }
            for method in category.instanceMethods {
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
    ///
    /// Protocol methods often have richer type encodings (especially for blocks)
    /// than the implementing class methods. This registry allows cross-referencing
    /// to get better block signatures.
    private func buildMethodSignatureRegistry(protocols: [ObjCProtocol]) async -> MethodSignatureRegistry {
        let registry = MethodSignatureRegistry()

        for proto in protocols {
            await registry.registerProtocol(proto)
        }

        return registry
    }

    // MARK: - Section Loading

    /// Find a section by segment and section name.
    private func findSection(segment segmentName: String, section sectionName: String) -> Section? {
        for segment in segments where segment.name == segmentName || segment.name.hasPrefix(segmentName) {
            if let section = segment.section(named: sectionName) {
                return section
            }
        }
        return nil
    }

    /// Get the __DATA_CONST or __DATA segment (for ObjC metadata).
    private var dataConstSegment: SegmentCommand? {
        segments.first { $0.name == "__DATA_CONST" } ?? segments.first { $0.name == "__DATA" }
    }

    /// Read data from a section.
    private func readSectionData(_ section: Section) -> Data? {
        let start = Int(section.offset)
        let end = start + Int(section.size)
        guard start >= 0 && end <= data.count else { return nil }
        return data.subdata(in: start..<end)
    }

    // MARK: - Address Translation

    /// Translate a virtual address to a file offset.
    ///
    /// Uses the pre-built address translator with O(log n) binary search
    /// and O(1) cached lookups for repeated addresses.
    private func fileOffset(for address: UInt64) -> Int? {
        addressTranslator.fileOffset(for: address)
    }

    /// Read a null-terminated string at the given virtual address.
    ///
    /// Uses SIMD-accelerated null terminator detection for performance.
    /// Thread-safe caching via Mutex ensures concurrent access safety.
    private func readString(at address: UInt64) -> String? {
        guard address != 0 else { return nil }

        // Check cache first (Mutex-based, sync)
        return stringCache.getOrRead(at: address) {
            guard let offset = self.fileOffset(for: address) else { return nil }
            guard offset >= 0 && offset < self.data.count else { return nil }
            return SIMDStringUtils.readNullTerminatedString(from: self.data, at: offset)
        }
    }

    /// Read a pointer value at the given virtual address.
    private func readPointer(at address: UInt64) throws -> UInt64 {
        guard let offset = fileOffset(for: address) else {
            throw ObjCProcessorError.invalidAddress(address)
        }

        var cursor = try DataCursor(data: data, offset: offset)

        guard is64Bit else {
            let value = byteOrder == .little ? try cursor.readLittleInt32() : try cursor.readBigInt32()
            return UInt64(value)
        }
        let rawValue = byteOrder == .little ? try cursor.readLittleInt64() : try cursor.readBigInt64()
        return decodeChainedFixupPointer(rawValue)
    }

    /// Result of decoding a pointer that may be a chained fixup.
    private enum PointerDecodeResult {
        case address(UInt64)
        case bindSymbol(String)
        case bindOrdinal(UInt32)  // When we have ordinal but no symbol table
    }

    /// Decode a raw pointer value, returning either an address or bind symbol.
    private func decodePointerWithBindInfo(_ rawPointer: UInt64) -> PointerDecodeResult {
        // Use ChainedFixups if available for accurate decoding
        if let fixups = chainedFixups {
            let result = fixups.decodePointer(rawPointer)
            switch result {
                case .rebase(let target):
                    return .address(target)
                case .bind(let ordinal, _):
                    if let symbolName = fixups.symbolName(forOrdinal: ordinal) {
                        // Strip leading underscore if present
                        let name = symbolName.hasPrefix("_") ? String(symbolName.dropFirst()) : symbolName
                        return .bindSymbol(name)
                    }
                    return .bindOrdinal(ordinal)
                case .notFixup:
                    return .address(rawPointer)
            }
        }

        // Fallback to heuristic decoding
        return .address(decodeChainedFixupPointer(rawPointer))
    }

    /// Decode a chained fixup pointer to get the actual target address.
    ///
    /// Modern arm64/arm64e binaries use chained fixups where pointers are encoded
    /// with metadata in the high bits and the target address in the low bits.
    private func decodeChainedFixupPointer(_ rawPointer: UInt64) -> UInt64 {
        // Check if this looks like a chained fixup pointer
        // Chained fixups have metadata in the high bits (above 36 bits)
        let highBits = rawPointer >> 36
        let hasChainedFixup = highBits != 0

        if hasChainedFixup {
            // For DYLD_CHAINED_PTR_64 format:
            // - Bits 0-35: target address (36 bits, relative to image base or absolute)
            // - Bits 36-43: high8 (upper 8 bits of target, for addresses > 36 bits)
            // - Bits 44-50: reserved (7 bits)
            // - Bits 51-63: next (13 bits, delta to next fixup in chain, divided by stride)
            //
            // For DYLD_CHAINED_PTR_ARM64E format:
            // - Bits 0-42: target (43 bits)
            // - Bits 43-50: diversity (8 bits)
            // - Bits 51: addrDiv flag
            // - Bits 52-53: key (2 bits)
            // - Bits 54-62: next (9 bits)
            // - Bit 63: bind flag (0 = rebase, 1 = bind)
            //
            // We use a heuristic: if bit 63 is set, it's likely a bind (skip).
            // Otherwise, extract the low 36-43 bits as the target.

            let bindFlag = (rawPointer >> 63) & 1
            if bindFlag == 1 {
                // This is a bind to an external symbol - we can't resolve it statically
                return 0
            }

            // Try 36-bit target first (DYLD_CHAINED_PTR_64)
            let target = rawPointer & Self.chainedFixupTargetMask36

            // high8 is at bits 36-43
            let high8 = (rawPointer >> 36) & Self.chainedFixupHigh8Mask

            // If high8 is non-zero and looks like part of a valid address, incorporate it
            // Otherwise just return the 36-bit target
            if high8 != 0 {
                // Combine: high8 provides upper bits if needed
                // For typical user-space addresses, high8 is usually 0
                return target | (high8 << 56)
            }

            return target
        }

        // Not a chained fixup - return as-is
        return rawPointer
    }

    // MARK: - Swift Type Resolution

    /// Actor-based symbolic resolver for Swift type references.
    ///
    /// Initialized at startup for thread-safe access from parallel tasks.
    private let symbolicResolver: SwiftSymbolicResolver

    /// Try to resolve a Swift type name for an ivar based on class name and field name.
    ///
    /// Swift classes expose ivars to ObjC runtime but don't provide type encodings.
    /// We can look up the type from Swift field descriptors if available.
    ///
    /// This function uses a pre-built comprehensive index for O(1) lookups in most cases.
    /// The index includes all name variants (suffixes, components) computed during initialization.
    ///
    /// - Complexity: O(1) average case (dictionary lookups), O(d) worst case for edge cases
    private func resolveSwiftIvarType(className: String, ivarName: String) async -> String? {
        guard swiftMetadata != nil else { return nil }

        // Extract the demangled class name from ObjC mangled name
        // ObjC names look like "_TtC13IDEFoundation25SomeClassName"
        var targetClassName = className
        var nestedNames: [String] = []

        // Try to extract the actual class name from mangled ObjC format
        if className.hasPrefix("_TtCC") || className.hasPrefix("_TtCCC") {
            // Handle nested classes first
            nestedNames = SwiftDemangler.demangleNestedClassName(className)
            if let last = nestedNames.last {
                targetClassName = last
            }
        }
        else if className.hasPrefix("_TtC") || className.hasPrefix("_TtGC") {
            if let (_, name) = SwiftDemangler.demangleClassName(className) {
                targetClassName = name
            }
        }
        else if className.hasPrefix("_Tt") {
            // Other mangled formats - try to extract the last component
            // The class name is typically at the end after module name
            targetClassName = extractSimpleClassName(from: className)
        }

        // Use comprehensive variant index for O(1) lookup
        // The index contains all suffix variants computed during initialization
        if let descriptor = swiftFieldsByVariant[targetClassName] {
            if let resolved = await resolveFieldFromDescriptor(descriptor, fieldName: ivarName) {
                return resolved
            }
        }

        // For nested classes, try looking up by the full nested path
        if nestedNames.count > 1 {
            let nestedPath = nestedNames.joined(separator: ".")
            if let descriptor = swiftFieldsByVariant[nestedPath] {
                if let resolved = await resolveFieldFromDescriptor(descriptor, fieldName: ivarName) {
                    return resolved
                }
            }
        }

        // Try lookup by full demangled name if we have the module
        if className.hasPrefix("_TtC") || className.hasPrefix("_TtGC") {
            if let (module, name) = SwiftDemangler.demangleClassName(className) {
                let fullName = "\(module).\(name)"
                if let descriptor = swiftFieldsByVariant[fullName] {
                    if let resolved = await resolveFieldFromDescriptor(descriptor, fieldName: ivarName) {
                        return resolved
                    }
                }
            }
        }

        // For non-mangled ObjC class names that are Swift classes, try the class name directly
        // This handles cases like "IDEBuildNoticeProvider" exposed to ObjC
        if !className.hasPrefix("_Tt") {
            // Try direct lookup - the class name might match a Swift type name
            if let descriptor = swiftFieldsByVariant[className] {
                if let resolved = await resolveFieldFromDescriptor(descriptor, fieldName: ivarName) {
                    return resolved
                }
            }
        }

        // Optimized fallback using pre-cached demangled names (no runtime demangling)
        // This handles edge cases where the comprehensive index didn't match
        for (mangledTypeName, descriptor) in swiftFieldsByMangledName {
            // Use cached demangled name instead of re-demangling at runtime
            let demangled = demangledNameCache[mangledTypeName] ?? ""

            // Check if this descriptor matches our class
            let descriptorClassName = extractSimpleClassName(from: demangled)

            if descriptorClassName == targetClassName || demangled.hasSuffix(targetClassName)
                || mangledTypeName.contains(targetClassName)
            {
                if let resolved = await resolveFieldFromDescriptor(descriptor, fieldName: ivarName) {
                    return resolved
                }
            }
        }

        return nil
    }

    /// Resolve a field's type from a descriptor by field name.
    private func resolveFieldFromDescriptor(
        _ descriptor: SwiftFieldDescriptor,
        fieldName ivarName: String
    ) async
        -> String?
    {
        for record in descriptor.records {
            // Handle lazy storage prefix and other Swift internal prefixes
            var fieldName = record.name
            fieldName = fieldName.replacingOccurrences(of: "$__lazy_storage_$_", with: "")
            fieldName = fieldName.replacingOccurrences(of: "_$s", with: "")

            // Check for exact match or match with common prefixes removed/added
            let matches =
                fieldName == ivarName || record.name == ivarName || fieldName == "_" + ivarName
                || "_" + fieldName == ivarName || fieldName == "$" + ivarName || "$" + fieldName == ivarName

            if matches {
                // Try to resolve the type using symbolic resolver (actor - async)
                // Always try the resolver first with raw data (handles embedded refs too)
                if !record.mangledTypeData.isEmpty {
                    let resolved = await symbolicResolver.resolveType(
                        mangledData: record.mangledTypeData,
                        sourceOffset: record.mangledTypeNameOffset
                    )
                    if !resolved.isEmpty && !resolved.hasPrefix("/*") && resolved != record.mangledTypeName {
                        return resolved
                    }
                }

                // Fall back to regular demangling if resolver didn't work
                if !record.mangledTypeName.isEmpty {
                    let demangled = SwiftDemangler.demangle(record.mangledTypeName)
                    // Check if demangling worked (result is different from input and not a symbolic ref)
                    if !demangled.isEmpty {
                        // Return demangled even if it equals the original (at least we have something)
                        return demangled
                    }
                }
            }
        }
        return nil
    }

    /// Extract simple class name from a fully qualified or mangled name.
    private func extractSimpleClassName(from name: String) -> String {
        // If it's a fully qualified name (Module.ClassName), extract last component
        if name.contains(".") {
            return String(name.split(separator: ".").last ?? Substring(name))
        }

        // If it looks like a mangled name, try to extract class name
        if name.hasPrefix("_Tt") {
            if let (_, className) = SwiftDemangler.demangleClassName(name) {
                return className
            }
        }

        return name
    }

    /// Check if a class name looks like a Swift class (has mangled name format).
    private func isSwiftClass(name: String) -> Bool {
        name.hasPrefix("_Tt") || name.hasPrefix("_$s")
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

        var cursor = try DataCursor(data: data, offset: Int(section.offset))
        return try ObjC2ImageInfo(cursor: &cursor, byteOrder: byteOrder)
    }

    // MARK: - Protocol Loading

    private func loadProtocolAsync(at address: UInt64) async throws -> ObjCProtocol? {
        guard address != 0 else { return nil }

        // Check Mutex cache first (sync)
        if let cached = protocolsByAddress.get(address) {
            return cached
        }

        guard let offset = fileOffset(for: address) else {
            return nil
        }

        var cursor = try DataCursor(data: data, offset: offset)
        let rawProtocol = try ObjC2Protocol(cursor: &cursor, byteOrder: byteOrder, is64Bit: is64Bit, ptrSize: ptrSize)

        // Decode name address (may be a chained fixup)
        let nameAddr = decodeChainedFixupPointer(rawProtocol.name)
        guard let name = readString(at: nameAddr) else {
            return nil
        }

        let proto = ObjCProtocol(name: name, address: address)

        // Cache immediately to handle circular references (sync)
        protocolsByAddress.set(address, value: proto)

        // Load adopted protocols
        if rawProtocol.protocols != 0 {
            let adoptedAddresses = try loadProtocolAddressList(at: rawProtocol.protocols)
            for adoptedAddr in adoptedAddresses {
                if let adoptedProto = try await loadProtocolAsync(at: adoptedAddr) {
                    proto.addAdoptedProtocol(adoptedProto)
                }
            }
        }

        // Load methods
        for method in try loadMethods(
            at: rawProtocol.instanceMethods,
            extendedTypesAddress: rawProtocol.extendedMethodTypes
        ) {
            proto.addInstanceMethod(method)
        }

        for method in try loadMethods(
            at: rawProtocol.classMethods,
            extendedTypesAddress: rawProtocol.extendedMethodTypes
        ) {
            proto.addClassMethod(method)
        }

        for method in try loadMethods(at: rawProtocol.optionalInstanceMethods, extendedTypesAddress: 0) {
            proto.addOptionalInstanceMethod(method)
        }

        for method in try loadMethods(at: rawProtocol.optionalClassMethods, extendedTypesAddress: 0) {
            proto.addOptionalClassMethod(method)
        }

        // Load properties
        for property in try loadProperties(at: rawProtocol.instanceProperties) {
            proto.addProperty(property)
        }

        return proto
    }

    private func loadProtocolAddressList(at address: UInt64) throws -> [UInt64] {
        guard address != 0 else { return [] }
        let decodedAddress = decodeChainedFixupPointer(address)
        guard let offset = fileOffset(for: decodedAddress) else { return [] }

        var cursor = try DataCursor(data: data, offset: offset)
        var addresses: [UInt64] = []

        // First entry is the count
        let rawCount: UInt64
        if is64Bit {
            rawCount = byteOrder == .little ? try cursor.readLittleInt64() : try cursor.readBigInt64()
        }
        else {
            let value = byteOrder == .little ? try cursor.readLittleInt32() : try cursor.readBigInt32()
            rawCount = UInt64(value)
        }
        // The count itself shouldn't be a chained fixup, but decode just in case
        let count = decodeChainedFixupPointer(rawCount)

        for _ in 0..<count {
            let rawAddr: UInt64
            if is64Bit {
                rawAddr = byteOrder == .little ? try cursor.readLittleInt64() : try cursor.readBigInt64()
            }
            else {
                let value = byteOrder == .little ? try cursor.readLittleInt32() : try cursor.readBigInt32()
                rawAddr = UInt64(value)
            }
            let addr = decodeChainedFixupPointer(rawAddr)
            if addr != 0 {
                addresses.append(addr)
            }
        }

        return addresses
    }

    // MARK: - Class Loading

    private func loadClassAsync(at address: UInt64) async throws -> ObjCClass? {
        guard address != 0 else { return nil }

        // Check Mutex cache first (sync)
        if let cached = classesByAddress.get(address) {
            return cached
        }

        guard let offset = fileOffset(for: address) else {
            return nil
        }

        var cursor = try DataCursor(data: data, offset: offset)
        let rawClass = try ObjC2Class(cursor: &cursor, byteOrder: byteOrder, is64Bit: is64Bit)

        // Load class data (class_ro_t)
        let rawDataPointer = rawClass.dataPointer
        let decodedDataPointer = decodeChainedFixupPointer(rawDataPointer)
        let dataPointerClean = decodedDataPointer & Self.pointerAlignmentMask

        guard dataPointerClean != 0 else {
            return nil
        }

        guard let dataOffset = fileOffset(for: dataPointerClean) else {
            return nil
        }

        var dataCursor = try DataCursor(data: data, offset: dataOffset)
        let classData = try ObjC2ClassROData(cursor: &dataCursor, byteOrder: byteOrder, is64Bit: is64Bit)

        // Name pointer may also be a chained fixup
        let namePointer = decodeChainedFixupPointer(classData.name)
        guard let name = readString(at: namePointer) else {
            return nil
        }

        let aClass = ObjCClass(name: name, address: address)
        aClass.isSwiftClass = rawClass.isSwiftClass
        aClass.classDataAddress = rawClass.dataPointer
        aClass.metaclassAddress = rawClass.isa

        // Cache immediately to handle circular references (sync)
        classesByAddress.set(address, value: aClass)

        // Load superclass - may be an address or a bind to external symbol
        let superclassResult = decodePointerWithBindInfo(rawClass.superclass)
        switch superclassResult {
            case .address(let superclassAddr):
                if superclassAddr != 0, let superclass = try await loadClassAsync(at: superclassAddr) {
                    aClass.superclassRef = ObjCClassReference(name: superclass.name, address: superclassAddr)
                }
            case .bindSymbol(let symbolName):
                let className: String
                if symbolName.hasPrefix("OBJC_CLASS_$_") {
                    className = String(symbolName.dropFirst("OBJC_CLASS_$_".count))
                }
                else {
                    className = symbolName
                }
                aClass.superclassRef = ObjCClassReference(name: className, address: 0)
            case .bindOrdinal(let ordinal):
                aClass.superclassRef = ObjCClassReference(name: "/* bind ordinal \(ordinal) */", address: 0)
        }

        // Load instance methods
        for method in try loadMethods(at: classData.baseMethods) {
            aClass.addInstanceMethod(method)
        }

        // Load class methods from metaclass
        let isaAddr = decodeChainedFixupPointer(rawClass.isa)
        if isaAddr != 0 {
            for method in try loadClassMethods(at: isaAddr) {
                aClass.addClassMethod(method)
            }
        }

        // Load instance variables (async - uses actor-based Swift resolver)
        for ivar in try await loadInstanceVariables(
            at: classData.ivars,
            className: aClass.name,
            isSwiftClass: aClass.isSwiftClass
        ) {
            aClass.addInstanceVariable(ivar)
        }

        // Load protocols using Mutex cache (sync)
        let protocolAddresses = try loadProtocolAddressList(at: classData.baseProtocols)
        for protoAddr in protocolAddresses {
            if let proto = protocolsByAddress.get(protoAddr) {
                aClass.addAdoptedProtocol(proto)
            }
            else if let proto = try? await loadProtocolAsync(at: protoAddr) {
                aClass.addAdoptedProtocol(proto)
            }
        }

        // Link Swift protocol conformances
        if aClass.isSwiftClass, let swift = swiftMetadata {
            let conformances = swift.conformances(forType: name)
            for conformance in conformances where !conformance.protocolName.isEmpty {
                aClass.addSwiftConformance(conformance.protocolName)
            }
        }

        // Load properties
        for property in try loadProperties(at: classData.baseProperties) {
            aClass.addProperty(property)
        }

        return aClass
    }

    private func loadClassMethods(at metaclassAddress: UInt64) throws -> [ObjCMethod] {
        guard metaclassAddress != 0 else { return [] }
        guard let offset = fileOffset(for: metaclassAddress) else { return [] }

        var cursor = try DataCursor(data: data, offset: offset)
        let rawClass = try ObjC2Class(cursor: &cursor, byteOrder: byteOrder, is64Bit: is64Bit)

        // Decode dataPointer (may be chained fixup) and mask Swift flags
        let decodedDataPointer = decodeChainedFixupPointer(rawClass.dataPointer)
        let dataPointerClean = decodedDataPointer & Self.pointerAlignmentMask
        guard dataPointerClean != 0 else { return [] }
        guard let dataOffset = fileOffset(for: dataPointerClean) else { return [] }

        var dataCursor = try DataCursor(data: data, offset: dataOffset)
        let classData = try ObjC2ClassROData(cursor: &dataCursor, byteOrder: byteOrder, is64Bit: is64Bit)

        return try loadMethods(at: classData.baseMethods)
    }

    // MARK: - Category Loading

    /// Async version of loadCategories using actor-based caching.
    private func loadCategoriesAsync() async throws -> [ObjCCategory] {
        guard
            let section = findSection(segment: "__DATA", section: "__objc_catlist")
                ?? findSection(segment: "__DATA_CONST", section: "__objc_catlist")
        else {
            return []
        }

        guard let sectionData = readSectionData(section) else {
            return []
        }

        var cursor = try DataCursor(data: sectionData, offset: 0)
        var categories: [ObjCCategory] = []

        while cursor.offset < sectionData.count {
            let rawAddress: UInt64
            if is64Bit {
                rawAddress = byteOrder == .little ? try cursor.readLittleInt64() : try cursor.readBigInt64()
            }
            else {
                let value = byteOrder == .little ? try cursor.readLittleInt32() : try cursor.readBigInt32()
                rawAddress = UInt64(value)
            }

            let categoryAddress = decodeChainedFixupPointer(rawAddress)
            if categoryAddress != 0 {
                if let category = try await loadCategoryAsync(at: categoryAddress) {
                    categories.append(category)
                }
            }
        }

        return categories
    }

    private func loadCategoryAsync(at address: UInt64) async throws -> ObjCCategory? {
        guard address != 0 else { return nil }
        guard let offset = fileOffset(for: address) else { return nil }

        var cursor = try DataCursor(data: data, offset: offset)
        let rawCategory = try ObjC2Category(cursor: &cursor, byteOrder: byteOrder, is64Bit: is64Bit)

        // Decode name address (may be a chained fixup)
        let nameAddr = decodeChainedFixupPointer(rawCategory.name)
        guard let name = readString(at: nameAddr) else {
            return nil
        }

        let category = ObjCCategory(name: name, address: address)

        // Set class reference - may be an address or a bind to external class
        let clsResult = decodePointerWithBindInfo(rawCategory.cls)
        switch clsResult {
            case .address(let clsAddr):
                if clsAddr != 0 {
                    if let aClass = classesByAddress.get(clsAddr) {
                        category.classRef = ObjCClassReference(name: aClass.name, address: clsAddr)
                    }
                    else if let aClass = try? await loadClassAsync(at: clsAddr) {
                        category.classRef = ObjCClassReference(name: aClass.name, address: clsAddr)
                    }
                }
            case .bindSymbol(let symbolName):
                let className: String
                if symbolName.hasPrefix("OBJC_CLASS_$_") {
                    className = String(symbolName.dropFirst("OBJC_CLASS_$_".count))
                }
                else {
                    className = symbolName
                }
                category.classRef = ObjCClassReference(name: className, address: 0)
            case .bindOrdinal(let ordinal):
                category.classRef = ObjCClassReference(name: "/* bind ordinal \(ordinal) */", address: 0)
        }

        // Load instance methods
        for method in try loadMethods(at: rawCategory.instanceMethods) {
            category.addInstanceMethod(method)
        }

        // Load class methods
        for method in try loadMethods(at: rawCategory.classMethods) {
            category.addClassMethod(method)
        }

        // Load protocols using Mutex cache (sync)
        let protocolAddresses = try loadProtocolAddressList(at: rawCategory.protocols)
        for protoAddr in protocolAddresses {
            if let proto = protocolsByAddress.get(protoAddr) {
                category.addAdoptedProtocol(proto)
            }
            else if let proto = try? await loadProtocolAsync(at: protoAddr) {
                category.addAdoptedProtocol(proto)
            }
        }

        // Load properties
        for property in try loadProperties(at: rawCategory.instanceProperties) {
            category.addProperty(property)
        }

        return category
    }

    // MARK: - Method Loading

    private func loadMethods(at address: UInt64, extendedTypesAddress: UInt64 = 0) throws -> [ObjCMethod] {
        guard address != 0 else { return [] }

        // Decode the address (may be a chained fixup pointer)
        let decodedAddress = decodeChainedFixupPointer(address)
        guard let offset = fileOffset(for: decodedAddress) else { return [] }

        var cursor = try DataCursor(data: data, offset: offset)
        let listHeader = try ObjC2ListHeader(cursor: &cursor, byteOrder: byteOrder)

        var methods: [ObjCMethod] = []

        // Check if this uses small methods (modern format with relative offsets)
        if listHeader.usesSmallMethods {
            return try loadSmallMethods(at: decodedAddress, listHeader: listHeader)
        }

        // Set up extended types cursor if available
        var extendedTypesCursor: DataCursor?
        if extendedTypesAddress != 0, let extOffset = fileOffset(for: extendedTypesAddress) {
            extendedTypesCursor = try DataCursor(data: data, offset: extOffset)
        }

        for _ in 0..<listHeader.count {
            let rawMethod = try ObjC2Method(cursor: &cursor, byteOrder: byteOrder, is64Bit: is64Bit)

            // Decode the name pointer (may be a chained fixup)
            let nameAddr = decodeChainedFixupPointer(rawMethod.name)
            guard let name = readString(at: nameAddr) else { continue }

            var typeString: String?

            // Try extended types first
            if var extCursor = extendedTypesCursor {
                let extTypesAddr: UInt64
                if is64Bit {
                    extTypesAddr = byteOrder == .little ? try extCursor.readLittleInt64() : try extCursor.readBigInt64()
                }
                else {
                    let value = byteOrder == .little ? try extCursor.readLittleInt32() : try extCursor.readBigInt32()
                    extTypesAddr = UInt64(value)
                }
                extendedTypesCursor = extCursor
                let decodedExtTypes = decodeChainedFixupPointer(extTypesAddr)
                typeString = readString(at: decodedExtTypes)
            }

            // Fall back to regular types
            if typeString == nil {
                let typesAddr = decodeChainedFixupPointer(rawMethod.types)
                typeString = readString(at: typesAddr)
            }

            let method = ObjCMethod(
                name: name,
                typeString: typeString ?? "",
                address: rawMethod.imp
            )
            methods.append(method)
        }

        return methods.reversed()
    }

    /// Load methods using the small method format (relative offsets).
    ///
    /// Used in iOS 14+ / macOS 11+ binaries.
    private func loadSmallMethods(at listAddress: UInt64, listHeader: ObjC2ListHeader) throws -> [ObjCMethod] {
        guard let offset = fileOffset(for: listAddress) else { return [] }

        // Skip the header (8 bytes)
        var cursor = try DataCursor(data: data, offset: offset + 8)

        var methods: [ObjCMethod] = []

        for i in 0..<listHeader.count {
            let smallMethod = try ObjC2SmallMethod(cursor: &cursor, byteOrder: byteOrder)

            // Calculate the VM address of the current method entry
            // Each small method is 12 bytes, and they start after the 8-byte header
            let methodEntryVMAddr = listAddress + 8 + UInt64(i) * 12

            // The name offset is relative to the name field's address (offset 0 in the entry)
            let nameFieldVMAddr = methodEntryVMAddr
            let selectorRefVMAddr = UInt64(Int64(nameFieldVMAddr) + Int64(smallMethod.nameOffset))

            // The types offset is relative to the types field's address (offset 4 in the entry)
            let typesFieldVMAddr = methodEntryVMAddr + 4
            let typesVMAddr = UInt64(Int64(typesFieldVMAddr) + Int64(smallMethod.typesOffset))

            // The imp offset is relative to the imp field's address (offset 8 in the entry)
            let impFieldVMAddr = methodEntryVMAddr + 8
            let impVMAddr = UInt64(Int64(impFieldVMAddr) + Int64(smallMethod.impOffset))

            // Read the selector name
            // For small methods, the name offset points to a selector reference in __objc_selrefs,
            // which contains a pointer (possibly with chained fixup) to the actual string in __objc_methname.
            // We first try to read it as a pointer dereference, then fall back to direct string read.
            var name: String?
            if let selectorRefOffset = fileOffset(for: selectorRefVMAddr) {
                // Try to read as a pointer first (for __objc_selrefs entries)
                var selectorCursor = try DataCursor(data: data, offset: selectorRefOffset)
                let rawSelectorPtr =
                    byteOrder == .little ? try selectorCursor.readLittleInt64() : try selectorCursor.readBigInt64()
                let selectorAddr = decodeChainedFixupPointer(rawSelectorPtr)
                if selectorAddr != 0 {
                    name = readString(at: selectorAddr)
                }
                // If that didn't work, try reading as direct string
                if name == nil {
                    name = readString(at: selectorRefVMAddr)
                }
            }
            guard let selectorName = name else { continue }

            // Read the type string
            let typeString = readString(at: typesVMAddr) ?? ""

            let method = ObjCMethod(
                name: selectorName,
                typeString: typeString,
                address: impVMAddr
            )
            methods.append(method)
        }

        return methods.reversed()
    }

    // MARK: - Instance Variable Loading

    private func loadInstanceVariables(
        at address: UInt64,
        className: String = "",
        isSwiftClass: Bool = false
    ) async throws
        -> [ObjCInstanceVariable]
    {
        guard address != 0 else { return [] }

        // Decode the address (may be a chained fixup pointer)
        let decodedAddress = decodeChainedFixupPointer(address)
        guard let offset = fileOffset(for: decodedAddress) else { return [] }

        var cursor = try DataCursor(data: data, offset: offset)
        let listHeader = try ObjC2ListHeader(cursor: &cursor, byteOrder: byteOrder)

        var ivars: [ObjCInstanceVariable] = []

        // Always try Swift type resolution if we have Swift metadata
        // This handles @objc classes that inherit from Swift classes
        // Even ObjC classes might have Swift-defined ivars in extensions
        let isSwift = swiftMetadata != nil || isSwiftClass || self.isSwiftClass(name: className)

        for _ in 0..<listHeader.count {
            let rawIvar = try ObjC2Ivar(cursor: &cursor, byteOrder: byteOrder, is64Bit: is64Bit)

            // Decode chained fixup pointers
            let nameAddr = decodeChainedFixupPointer(rawIvar.name)
            guard nameAddr != 0 else { continue }
            guard let name = readString(at: nameAddr) else { continue }

            let typeAddr = decodeChainedFixupPointer(rawIvar.type)
            let typeEncoding = readString(at: typeAddr) ?? ""
            var typeString = ""

            // For Swift classes, try to resolve from Swift metadata even if encoding exists
            // (Swift encodings are often generic/incomplete like '@' or 'B')
            if isSwift {
                if let swiftType = await resolveSwiftIvarType(className: className, ivarName: name) {
                    typeString = swiftType
                }
            }

            // Read the actual offset value from the offset pointer
            var actualOffset: UInt64 = 0
            let offsetAddr = decodeChainedFixupPointer(rawIvar.offset)
            if offsetAddr != 0, let offsetPtr = fileOffset(for: offsetAddr) {
                var offsetCursor = try DataCursor(data: data, offset: offsetPtr)
                // The offset is stored as a pointer-sized value but represents a 32-bit offset
                if is64Bit {
                    let value =
                        byteOrder == .little ? try offsetCursor.readLittleInt64() : try offsetCursor.readBigInt64()
                    actualOffset = UInt64(UInt32(truncatingIfNeeded: value))
                }
                else {
                    let value =
                        byteOrder == .little ? try offsetCursor.readLittleInt32() : try offsetCursor.readBigInt32()
                    actualOffset = UInt64(value)
                }
            }

            let ivar = ObjCInstanceVariable(
                name: name,
                typeEncoding: typeEncoding,
                typeString: typeString,
                offset: actualOffset,
                size: UInt64(rawIvar.size),
                alignment: rawIvar.alignment
            )
            ivars.append(ivar)
        }

        return ivars
    }

    // MARK: - Property Loading

    private func loadProperties(at address: UInt64) throws -> [ObjCProperty] {
        guard address != 0 else { return [] }

        // Decode the address (may be a chained fixup pointer)
        let decodedAddress = decodeChainedFixupPointer(address)
        guard let offset = fileOffset(for: decodedAddress) else { return [] }

        var cursor = try DataCursor(data: data, offset: offset)
        let listHeader = try ObjC2ListHeader(cursor: &cursor, byteOrder: byteOrder)

        var properties: [ObjCProperty] = []

        for _ in 0..<listHeader.count {
            let rawProperty = try ObjC2Property(cursor: &cursor, byteOrder: byteOrder, is64Bit: is64Bit)

            // Decode chained fixup pointers for name and attributes
            let nameAddr = decodeChainedFixupPointer(rawProperty.name)
            guard let name = readString(at: nameAddr) else { continue }

            let attrAddr = decodeChainedFixupPointer(rawProperty.attributes)
            let attributeString = readString(at: attrAddr) ?? ""

            let property = ObjCProperty(name: name, attributeString: attributeString)
            properties.append(property)
        }

        return properties
    }
}
