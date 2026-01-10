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
///
public final class DyldCacheObjCProcessor: @unchecked Sendable {
    /// The shared cache.
    private let cache: DyldSharedCache

    /// The image being processed.
    private let image: DyldCacheImageInfo

    /// Data provider for the image.
    private let dataProvider: DyldCacheDataProvider

    /// Whether the cache is 64-bit.
    private let is64Bit: Bool

    /// Byte order (always little for modern DSC).
    private let byteOrder: ByteOrder = .little

    /// Pointer size.
    private var ptrSize: Int { is64Bit ? 8 : 4 }

    /// Shared region base address for pointer decoding.
    private let sharedRegionBase: UInt64

    /// Thread-safe cache of loaded classes.
    private let classesByAddress = ThreadSafeCache<UInt64, ObjCClass>()

    /// Thread-safe cache of loaded protocols.
    private let protocolsByAddress = ThreadSafeCache<UInt64, ObjCProtocol>()

    /// Thread-safe string cache.
    private let stringCache = StringTableCache()

    /// Base address for relative method selector resolution.
    ///
    /// For small methods in DSC, the selector `nameOffset` is relative to this base address
    /// (when using direct selectors, i.e., iOS 16+). This is obtained from the
    /// `relativeMethodSelectorBaseAddressOffset` field in the ObjC optimization header.
    private let relativeMethodSelectorBase: UInt64?

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
        // Use first mapping's address as shared region base for pointer decoding
        self.sharedRegionBase = cache.mappings.first?.address ?? 0

        // Try to load the relative method selector base from ObjC optimization header
        self.relativeMethodSelectorBase = Self.loadRelativeMethodSelectorBase(from: cache)
    }

    /// Load the relative method selector base address from the cache's ObjC optimization header.
    ///
    /// The `relativeMethodSelectorBaseAddressOffset` field in the ObjC optimization header
    /// is a file offset that, when added to the cache's base virtual address, gives the
    /// virtual address of the selector strings base.
    ///
    /// For small methods with direct selectors (iOS 16+), the method's `nameOffset` is
    /// relative to this base address.
    private static func loadRelativeMethodSelectorBase(from cache: DyldSharedCache) -> UInt64? {
        guard cache.hasObjCOptimization else { return nil }

        do {
            let optHeader = try cache.objcOptimizationHeader()
            let offset = optHeader.relativeMethodSelectorBaseAddressOffset
            guard offset != 0 else { return nil }

            // The relativeMethodSelectorBaseAddressOffset is a file offset in the cache.
            // We need to convert it to a virtual address.
            // According to Apple's dyld source, it's computed as:
            //   (uint64_t)cacheHeader + relativeMethodSelectorBaseAddressOffset
            // where cacheHeader is the in-memory base of the cache.

            // Get the base virtual address from the first mapping
            guard let firstMapping = cache.mappings.first else { return nil }

            // The offset is relative to the cache file start.
            // First mapping starts at file offset 0 with address `firstMapping.address`.
            // So the virtual address is: firstMapping.address + offset
            let selectorBaseAddress = UInt64(Int64(firstMapping.address) + offset)

            // Validate that this address is within a valid mapping
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
        // Clear caches
        classesByAddress.clear()
        protocolsByAddress.clear()
        stringCache.clear()

        // Load image info
        let imageInfo = try? loadImageInfo()

        // Load protocols first (may be referenced by classes)
        // Use resilient loading to continue past errors
        let protocols: [ObjCProtocol]
        do {
            protocols = try await loadProtocols()
        }
        catch {
            // Log but continue
            protocols = []
        }

        // Load classes
        let classes: [ObjCClass]
        do {
            classes = try await loadClasses()
        }
        catch {
            // Class loading failed - continue with empty classes
            classes = []
        }

        // Load categories
        let categories: [ObjCCategory]
        do {
            categories = try await loadCategories()
        }
        catch {
            categories = []
        }

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

    // MARK: - Section Finding

    /// Find a section in the image.
    private func findSection(segment: String, section: String) -> Section? {
        dataProvider.findSection(segment: segment, section: section)
    }

    /// Read section data.
    private func readSectionData(_ section: Section) -> Data? {
        try? dataProvider.readSectionData(section)
    }

    // MARK: - Address Translation

    /// Translate a virtual address to file offset.
    private func fileOffset(for address: UInt64) -> Int? {
        dataProvider.fileOffset(for: address)
    }

    /// Read a string at a virtual address.
    private func readString(at address: UInt64) -> String? {
        guard address != 0 else { return nil }

        return stringCache.getOrRead(at: address) {
            self.dataProvider.readCString(at: address)
        }
    }

    /// Read a pointer at a virtual address.
    private func readPointer(at address: UInt64) throws -> UInt64 {
        let data = try dataProvider.readData(atAddress: address, count: ptrSize)
        var cursor = try DataCursor(data: data)

        guard is64Bit else {
            return UInt64(try cursor.readLittleInt32())
        }
        return try cursor.readLittleInt64()
    }

    /// Decode a chained fixup pointer.
    ///
    /// In modern DSC (arm64e), pointers use different encodings:
    ///
    /// 1. Direct pointers: Already in the shared region address range (0x18...)
    /// 2. Non-authenticated rebases (classlist): 51-bit offset from shared region base
    /// 3. Authenticated rebases (objc_data): 32-bit offset with PAC in high bits
    ///
    /// We try multiple decoding strategies and validate which produces a valid address.
    private func decodePointer(_ rawPointer: UInt64) -> UInt64 {
        guard rawPointer != 0 else { return 0 }

        // Strategy 1: Check if already a valid direct pointer
        if rawPointer >= sharedRegionBase && rawPointer < (sharedRegionBase + 0x10_0000_0000) {
            return rawPointer
        }

        // Check for encoded format (high bits set)
        let highBits = rawPointer >> 32
        if highBits != 0 {
            // Strategy 2: Try 32-bit offset (authenticated pointers in __objc_data)
            // These have PAC/diversity in high bits, offset in lower 32 bits
            let offset32 = rawPointer & 0xFFFF_FFFF
            let decoded32 = sharedRegionBase + offset32
            if decoded32 >= sharedRegionBase && decoded32 < (sharedRegionBase + 0x10_0000_0000) {
                // Validate by checking if address translates
                if cache.translator.fileOffsetInt(for: decoded32) != nil {
                    return decoded32
                }
            }

            // Strategy 3: Try 51-bit offset (non-authenticated rebases in classlist)
            let offset51 = rawPointer & 0x7_FFFF_FFFF_FFFF
            let decoded51 = sharedRegionBase + offset51
            if decoded51 >= sharedRegionBase && decoded51 < (sharedRegionBase + 0x10_0000_0000) {
                if cache.translator.fileOffsetInt(for: decoded51) != nil {
                    return decoded51
                }
            }

            // Neither worked
            return 0
        }

        // Small value - might be a direct offset, try adding base
        let withBase = sharedRegionBase + rawPointer
        if withBase >= sharedRegionBase && withBase < (sharedRegionBase + 0x10_0000_0000) {
            if cache.translator.fileOffsetInt(for: withBase) != nil {
                return withBase
            }
        }

        return rawPointer
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

    // MARK: - Protocol Loading

    private func loadProtocols() async throws -> [ObjCProtocol] {
        guard
            let section = findSection(segment: "__DATA", section: "__objc_protolist")
                ?? findSection(segment: "__DATA_CONST", section: "__objc_protolist")
        else {
            return []
        }

        guard let sectionData = readSectionData(section) else {
            return []
        }

        var cursor = try DataCursor(data: sectionData)
        var protocols: [ObjCProtocol] = []

        while cursor.offset < sectionData.count {
            let rawAddress: UInt64
            if is64Bit {
                rawAddress = try cursor.readLittleInt64()
            }
            else {
                rawAddress = UInt64(try cursor.readLittleInt32())
            }

            let address = decodePointer(rawAddress)
            if address != 0, let proto = try await loadProtocol(at: address) {
                protocols.append(proto)
            }
        }

        return protocols
    }

    private func loadProtocol(at address: UInt64) async throws -> ObjCProtocol? {
        guard address != 0 else { return nil }

        // Check cache
        if let cached = protocolsByAddress.get(address) {
            return cached
        }

        guard let offset = fileOffset(for: address) else { return nil }

        let data = try cache.file.data(at: offset, count: is64Bit ? 80 : 40)
        var cursor = try DataCursor(data: data)
        let rawProtocol = try ObjC2Protocol(cursor: &cursor, byteOrder: byteOrder, is64Bit: is64Bit, ptrSize: ptrSize)

        let nameAddr = decodePointer(rawProtocol.name)
        guard let name = readString(at: nameAddr) else { return nil }

        let proto = ObjCProtocol(name: name, address: address)

        // Cache immediately
        protocolsByAddress.set(address, value: proto)

        // Load adopted protocols
        if rawProtocol.protocols != 0 {
            let adoptedAddresses = try loadProtocolAddressList(at: rawProtocol.protocols)
            for adoptedAddr in adoptedAddresses {
                if let adopted = try await loadProtocol(at: adoptedAddr) {
                    proto.addAdoptedProtocol(adopted)
                }
            }
        }

        // Load methods
        for method in try loadMethods(at: rawProtocol.instanceMethods) {
            proto.addInstanceMethod(method)
        }
        for method in try loadMethods(at: rawProtocol.classMethods) {
            proto.addClassMethod(method)
        }
        for method in try loadMethods(at: rawProtocol.optionalInstanceMethods) {
            proto.addOptionalInstanceMethod(method)
        }
        for method in try loadMethods(at: rawProtocol.optionalClassMethods) {
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
        let decodedAddress = decodePointer(address)
        guard let offset = fileOffset(for: decodedAddress) else { return [] }

        var addresses: [UInt64] = []

        let countData = try cache.file.data(at: offset, count: ptrSize)
        var countCursor = try DataCursor(data: countData)
        let rawCount: UInt64
        if is64Bit {
            rawCount = try countCursor.readLittleInt64()
        }
        else {
            rawCount = UInt64(try countCursor.readLittleInt32())
        }
        let count = decodePointer(rawCount)

        guard count > 0 && count < 10000 else { return [] }

        let listData = try cache.file.data(at: offset + ptrSize, count: Int(count) * ptrSize)
        var listCursor = try DataCursor(data: listData)

        for _ in 0..<count {
            let rawAddr: UInt64
            if is64Bit {
                rawAddr = try listCursor.readLittleInt64()
            }
            else {
                rawAddr = UInt64(try listCursor.readLittleInt32())
            }
            let addr = decodePointer(rawAddr)
            if addr != 0 {
                addresses.append(addr)
            }
        }

        return addresses
    }

    // MARK: - Class Loading

    private func loadClasses() async throws -> [ObjCClass] {
        guard
            let section = findSection(segment: "__DATA", section: "__objc_classlist")
                ?? findSection(segment: "__DATA_CONST", section: "__objc_classlist")
        else {
            return []
        }

        guard let sectionData = readSectionData(section) else {
            return []
        }

        var cursor = try DataCursor(data: sectionData)
        var classes: [ObjCClass] = []

        while cursor.offset < sectionData.count {
            let rawAddress: UInt64
            if is64Bit {
                rawAddress = try cursor.readLittleInt64()
            }
            else {
                rawAddress = UInt64(try cursor.readLittleInt32())
            }

            let address = decodePointer(rawAddress)
            if address != 0 {
                // Wrap individual class loading to continue on errors
                do {
                    if let cls = try await loadClass(at: address) {
                        classes.append(cls)
                    }
                }
                catch {
                    // Skip this class but continue with others
                }
            }
        }

        return classes
    }

    private func loadClass(at address: UInt64) async throws -> ObjCClass? {
        guard address != 0 else { return nil }

        // Check cache
        if let cached = classesByAddress.get(address) {
            return cached
        }

        guard let offset = fileOffset(for: address) else {
            return nil
        }

        let classSize = is64Bit ? 64 : 32  // 8 UInt64 (64-bit) or 8 UInt32 (32-bit)
        let classData = try cache.file.data(at: offset, count: classSize)
        var cursor = try DataCursor(data: classData)
        let rawClass = try ObjC2Class(cursor: &cursor, byteOrder: byteOrder, is64Bit: is64Bit)

        // Load class_ro_t - the data pointer in DSC also needs decoding
        let dataPointerCleared = rawClass.data & ~0x7  // Clear flags
        let dataPointer = decodePointer(dataPointerCleared)

        guard dataPointer != 0 else {
            return nil
        }

        guard let dataOffset = fileOffset(for: dataPointer) else {
            return nil
        }

        let roSize = is64Bit ? 80 : 48
        let roData = try cache.file.data(at: dataOffset, count: roSize)
        var roCursor = try DataCursor(data: roData)
        let classROData = try ObjC2ClassROData(cursor: &roCursor, byteOrder: byteOrder, is64Bit: is64Bit)

        let namePointer = decodePointer(classROData.name)
        guard let name = readString(at: namePointer) else {
            return nil
        }

        let cls = ObjCClass(name: name, address: address)
        cls.isSwiftClass = rawClass.isSwiftClass
        cls.classDataAddress = rawClass.dataPointer
        cls.metaclassAddress = rawClass.isa

        // Cache immediately
        classesByAddress.set(address, value: cls)

        // Superclass
        let superclassAddr = decodePointer(rawClass.superclass)
        if superclassAddr != 0 {
            if let superclass = try await loadClass(at: superclassAddr) {
                cls.superclassRef = ObjCClassReference(name: superclass.name, address: superclassAddr)
            }
            else {
                // External class - try to read name
                if let superName = readExternalClassName(at: superclassAddr) {
                    cls.superclassRef = ObjCClassReference(name: superName, address: superclassAddr)
                }
            }
        }

        // Instance methods
        for method in try loadMethods(at: classROData.baseMethods) {
            cls.addInstanceMethod(method)
        }

        // Class methods from metaclass
        let metaclassAddr = decodePointer(rawClass.isa)
        if metaclassAddr != 0 {
            for method in try loadClassMethods(at: metaclassAddr) {
                cls.addClassMethod(method)
            }
        }

        // Instance variables
        for ivar in try loadInstanceVariables(at: classROData.ivars) {
            cls.addInstanceVariable(ivar)
        }

        // Protocols
        let protocolAddresses = try loadProtocolAddressList(at: classROData.baseProtocols)
        for protoAddr in protocolAddresses {
            if let proto = protocolsByAddress.get(protoAddr) {
                cls.addAdoptedProtocol(proto)
            }
            else if let proto = try? await loadProtocol(at: protoAddr) {
                cls.addAdoptedProtocol(proto)
            }
        }

        // Properties
        for property in try loadProperties(at: classROData.baseProperties) {
            cls.addProperty(property)
        }

        return cls
    }

    /// Try to read an external class name from another framework in the cache.
    private func readExternalClassName(at address: UInt64) -> String? {
        guard let offset = fileOffset(for: address) else { return nil }

        // Read the class structure
        do {
            let classSize = is64Bit ? 64 : 32  // 8 UInt64 (64-bit) or 8 UInt32 (32-bit)
            let classData = try cache.file.data(at: offset, count: classSize)
            var cursor = try DataCursor(data: classData)
            let rawClass = try ObjC2Class(cursor: &cursor, byteOrder: byteOrder, is64Bit: is64Bit)

            let dataPointer = decodePointer(rawClass.dataPointer) & ~0x7
            guard dataPointer != 0, let dataOffset = fileOffset(for: dataPointer) else { return nil }

            let roSize = is64Bit ? 80 : 48
            let roData = try cache.file.data(at: dataOffset, count: roSize)
            var roCursor = try DataCursor(data: roData)
            let classROData = try ObjC2ClassROData(cursor: &roCursor, byteOrder: byteOrder, is64Bit: is64Bit)

            let namePointer = decodePointer(classROData.name)
            return readString(at: namePointer)
        }
        catch {
            return nil
        }
    }

    private func loadClassMethods(at metaclassAddress: UInt64) throws -> [ObjCMethod] {
        guard metaclassAddress != 0 else { return [] }
        guard let offset = fileOffset(for: metaclassAddress) else { return [] }

        let classSize = is64Bit ? 64 : 32  // 8 UInt64 (64-bit) or 8 UInt32 (32-bit)
        let classData = try cache.file.data(at: offset, count: classSize)
        var cursor = try DataCursor(data: classData)
        let rawClass = try ObjC2Class(cursor: &cursor, byteOrder: byteOrder, is64Bit: is64Bit)

        let dataPointer = decodePointer(rawClass.dataPointer) & ~0x7
        guard dataPointer != 0, let dataOffset = fileOffset(for: dataPointer) else { return [] }

        let roSize = is64Bit ? 80 : 48
        let roData = try cache.file.data(at: dataOffset, count: roSize)
        var roCursor = try DataCursor(data: roData)
        let classROData = try ObjC2ClassROData(cursor: &roCursor, byteOrder: byteOrder, is64Bit: is64Bit)

        return try loadMethods(at: classROData.baseMethods)
    }

    // MARK: - Category Loading

    private func loadCategories() async throws -> [ObjCCategory] {
        guard
            let section = findSection(segment: "__DATA", section: "__objc_catlist")
                ?? findSection(segment: "__DATA_CONST", section: "__objc_catlist")
        else {
            return []
        }

        guard let sectionData = readSectionData(section) else {
            return []
        }

        var cursor = try DataCursor(data: sectionData)
        var categories: [ObjCCategory] = []

        while cursor.offset < sectionData.count {
            let rawAddress: UInt64
            if is64Bit {
                rawAddress = try cursor.readLittleInt64()
            }
            else {
                rawAddress = UInt64(try cursor.readLittleInt32())
            }

            let address = decodePointer(rawAddress)
            if address != 0, let category = try await loadCategory(at: address) {
                categories.append(category)
            }
        }

        return categories
    }

    private func loadCategory(at address: UInt64) async throws -> ObjCCategory? {
        guard address != 0 else { return nil }
        guard let offset = fileOffset(for: address) else { return nil }

        let catSize = is64Bit ? 48 : 24
        let catData = try cache.file.data(at: offset, count: catSize)
        var cursor = try DataCursor(data: catData)
        let rawCategory = try ObjC2Category(cursor: &cursor, byteOrder: byteOrder, is64Bit: is64Bit)

        let nameAddr = decodePointer(rawCategory.name)
        guard let name = readString(at: nameAddr) else { return nil }

        let category = ObjCCategory(name: name, address: address)

        // Class reference
        let clsAddr = decodePointer(rawCategory.cls)
        if clsAddr != 0 {
            if let cls = classesByAddress.get(clsAddr) {
                category.classRef = ObjCClassReference(name: cls.name, address: clsAddr)
            }
            else if let cls = try? await loadClass(at: clsAddr) {
                category.classRef = ObjCClassReference(name: cls.name, address: clsAddr)
            }
            else if let className = readExternalClassName(at: clsAddr) {
                category.classRef = ObjCClassReference(name: className, address: clsAddr)
            }
        }

        // Methods
        for method in try loadMethods(at: rawCategory.instanceMethods) {
            category.addInstanceMethod(method)
        }
        for method in try loadMethods(at: rawCategory.classMethods) {
            category.addClassMethod(method)
        }

        // Protocols
        let protocolAddresses = try loadProtocolAddressList(at: rawCategory.protocols)
        for protoAddr in protocolAddresses {
            if let proto = protocolsByAddress.get(protoAddr) {
                category.addAdoptedProtocol(proto)
            }
            else if let proto = try? await loadProtocol(at: protoAddr) {
                category.addAdoptedProtocol(proto)
            }
        }

        // Properties
        for property in try loadProperties(at: rawCategory.instanceProperties) {
            category.addProperty(property)
        }

        return category
    }

    // MARK: - Method Loading

    private func loadMethods(at address: UInt64) throws -> [ObjCMethod] {
        guard address != 0 else { return [] }

        let decodedAddress = decodePointer(address)
        guard let offset = fileOffset(for: decodedAddress) else { return [] }

        // Read list header
        let headerData = try cache.file.data(at: offset, count: 8)
        var headerCursor = try DataCursor(data: headerData)
        let listHeader = try ObjC2ListHeader(cursor: &headerCursor, byteOrder: byteOrder)

        // Check for small methods format
        if listHeader.usesSmallMethods {
            return try loadSmallMethods(
                at: decodedAddress,
                listHeader: listHeader,
                usesDirectSelectors: listHeader.usesDirectSelectors
            )
        }

        // Regular methods
        var methods: [ObjCMethod] = []
        let entrySize = is64Bit ? 24 : 12
        let listData = try cache.file.data(at: offset + 8, count: Int(listHeader.count) * entrySize)
        var cursor = try DataCursor(data: listData)

        for _ in 0..<listHeader.count {
            let rawMethod = try ObjC2Method(cursor: &cursor, byteOrder: byteOrder, is64Bit: is64Bit)

            let nameAddr = decodePointer(rawMethod.name)
            guard let name = readString(at: nameAddr) else { continue }

            let typesAddr = decodePointer(rawMethod.types)
            let typeString = readString(at: typesAddr) ?? ""

            let method = ObjCMethod(name: name, typeString: typeString, address: rawMethod.imp)
            methods.append(method)
        }

        return methods.reversed()
    }

    /// Load methods using the small method format (relative offsets).
    ///
    /// In modern DSC (iOS 14+), methods use a compact 12-byte format with relative offsets:
    /// - `nameOffset`: Int32 relative offset to selector
    /// - `typesOffset`: Int32 relative offset to type encoding
    /// - `impOffset`: Int32 relative offset to implementation
    ///
    /// For selector resolution:
    /// - With direct selectors (iOS 16+): nameOffset is relative to `relativeMethodSelectorBase`
    /// - Without direct selectors: nameOffset points to a selector reference that dereferences to the string
    ///
    /// - Parameters:
    ///   - listAddress: Virtual address of the method list.
    ///   - listHeader: The parsed list header.
    ///   - usesDirectSelectors: Whether selectors use direct offsets (iOS 16+).
    /// - Returns: Array of parsed methods.
    private func loadSmallMethods(
        at listAddress: UInt64,
        listHeader: ObjC2ListHeader,
        usesDirectSelectors: Bool
    ) throws -> [ObjCMethod] {
        guard let offset = fileOffset(for: listAddress) else { return [] }

        // Read all small method entries (12 bytes each, after 8-byte header)
        let entrySize = 12
        let listData = try cache.file.data(at: offset + 8, count: Int(listHeader.count) * entrySize)
        var cursor = try DataCursor(data: listData)

        var methods: [ObjCMethod] = []

        for i in 0..<listHeader.count {
            let smallMethod = try ObjC2SmallMethod(cursor: &cursor, byteOrder: byteOrder)

            // Calculate VM addresses for this method entry
            // Each small method is 12 bytes, starting after the 8-byte header
            let methodEntryVMAddr = listAddress + 8 + UInt64(i) * 12

            // Resolve the selector name
            let name: String?

            if usesDirectSelectors {
                // iOS 16+: nameOffset is relative to the selector strings base.
                // The selector string is directly at: selectorBase + nameOffset.
                // If we don't have the selector base, we cannot resolve direct selectors.
                guard let selectorBase = relativeMethodSelectorBase else {
                    // Cannot resolve direct selectors without the base address.
                    // This can happen when:
                    // 1. The cache doesn't have an embedded ObjC optimization header
                    // 2. The header parsing failed
                    // 3. The relativeMethodSelectorBaseAddressOffset is 0
                    // In this case, skip small methods entirely to avoid garbled output.
                    return []
                }
                let selectorAddr = UInt64(Int64(selectorBase) + Int64(smallMethod.nameOffset))
                name = readString(at: selectorAddr)
            }
            else {
                // Pre-iOS 16: nameOffset is relative to the name field's address
                // and points to a selector reference (SEL *) that dereferences to the string
                let nameFieldVMAddr = methodEntryVMAddr
                let selectorRefVMAddr = UInt64(Int64(nameFieldVMAddr) + Int64(smallMethod.nameOffset))

                // Try to read as pointer dereference first
                if let selectorRefOffset = fileOffset(for: selectorRefVMAddr) {
                    let refData = try cache.file.data(at: selectorRefOffset, count: is64Bit ? 8 : 4)
                    var refCursor = try DataCursor(data: refData)
                    let rawSelectorPtr: UInt64
                    if is64Bit {
                        rawSelectorPtr = try refCursor.readLittleInt64()
                    }
                    else {
                        rawSelectorPtr = UInt64(try refCursor.readLittleInt32())
                    }
                    let selectorAddr = decodePointer(rawSelectorPtr)
                    if selectorAddr != 0 {
                        name = readString(at: selectorAddr)
                    }
                    else {
                        // Fallback: try reading directly as a string
                        name = readString(at: selectorRefVMAddr)
                    }
                }
                else {
                    name = nil
                }
            }

            guard let selectorName = name, !selectorName.isEmpty else { continue }

            // Resolve the type encoding
            // typesOffset is relative to the types field's address (offset 4 in entry)
            let typesFieldVMAddr = methodEntryVMAddr + 4
            let typesVMAddr = UInt64(Int64(typesFieldVMAddr) + Int64(smallMethod.typesOffset))
            let typeString = readString(at: typesVMAddr) ?? ""

            // Resolve the implementation address
            // impOffset is relative to the imp field's address (offset 8 in entry)
            let impFieldVMAddr = methodEntryVMAddr + 8
            let impVMAddr = UInt64(Int64(impFieldVMAddr) + Int64(smallMethod.impOffset))

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

    private func loadInstanceVariables(at address: UInt64) throws -> [ObjCInstanceVariable] {
        guard address != 0 else { return [] }

        let decodedAddress = decodePointer(address)
        guard let offset = fileOffset(for: decodedAddress) else { return [] }

        // Read list header
        let headerData = try cache.file.data(at: offset, count: 8)
        var headerCursor = try DataCursor(data: headerData)
        let listHeader = try ObjC2ListHeader(cursor: &headerCursor, byteOrder: byteOrder)

        var ivars: [ObjCInstanceVariable] = []
        let entrySize = is64Bit ? 32 : 20
        let listData = try cache.file.data(at: offset + 8, count: Int(listHeader.count) * entrySize)
        var cursor = try DataCursor(data: listData)

        for _ in 0..<listHeader.count {
            let rawIvar = try ObjC2Ivar(cursor: &cursor, byteOrder: byteOrder, is64Bit: is64Bit)

            let nameAddr = decodePointer(rawIvar.name)
            guard nameAddr != 0 else { continue }
            guard let name = readString(at: nameAddr) else { continue }

            let typeAddr = decodePointer(rawIvar.type)
            let typeEncoding = readString(at: typeAddr) ?? ""

            // Read actual offset
            var actualOffset: UInt64 = 0
            let offsetAddr = decodePointer(rawIvar.offset)
            if offsetAddr != 0, let offsetPtr = fileOffset(for: offsetAddr) {
                let offsetData = try cache.file.data(at: offsetPtr, count: is64Bit ? 8 : 4)
                var offsetCursor = try DataCursor(data: offsetData)
                if is64Bit {
                    let value = try offsetCursor.readLittleInt64()
                    actualOffset = UInt64(UInt32(truncatingIfNeeded: value))
                }
                else {
                    actualOffset = UInt64(try offsetCursor.readLittleInt32())
                }
            }

            let ivar = ObjCInstanceVariable(
                name: name,
                typeEncoding: typeEncoding,
                typeString: "",
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

        let decodedAddress = decodePointer(address)
        guard let offset = fileOffset(for: decodedAddress) else { return [] }

        // Read list header
        let headerData = try cache.file.data(at: offset, count: 8)
        var headerCursor = try DataCursor(data: headerData)
        let listHeader = try ObjC2ListHeader(cursor: &headerCursor, byteOrder: byteOrder)

        var properties: [ObjCProperty] = []
        let entrySize = is64Bit ? 16 : 8
        let listData = try cache.file.data(at: offset + 8, count: Int(listHeader.count) * entrySize)
        var cursor = try DataCursor(data: listData)

        for _ in 0..<listHeader.count {
            let rawProperty = try ObjC2Property(cursor: &cursor, byteOrder: byteOrder, is64Bit: is64Bit)

            let nameAddr = decodePointer(rawProperty.name)
            guard let name = readString(at: nameAddr) else { continue }

            let attrAddr = decodePointer(rawProperty.attributes)
            let attributeString = readString(at: attrAddr) ?? ""

            let property = ObjCProperty(name: name, attributeString: attributeString)
            properties.append(property)
        }

        return properties
    }

    // MARK: - Registry Building

    private func buildStructureRegistry(
        classes: [ObjCClass],
        protocols: [ObjCProtocol],
        categories: [ObjCCategory]
    ) async -> StructureRegistry {
        let registry = StructureRegistry()

        // Register from classes
        for cls in classes {
            for ivar in cls.instanceVariables {
                if let parsed = ivar.parsedType {
                    await registry.register(parsed)
                }
            }
            for property in cls.properties {
                if let parsed = property.parsedType {
                    await registry.register(parsed)
                }
            }
        }

        // Register from protocols
        for proto in protocols {
            for property in proto.properties {
                if let parsed = property.parsedType {
                    await registry.register(parsed)
                }
            }
        }

        // Register from categories
        for category in categories {
            for property in category.properties {
                if let parsed = property.parsedType {
                    await registry.register(parsed)
                }
            }
        }

        return registry
    }

    private func buildMethodSignatureRegistry(protocols: [ObjCProtocol]) async -> MethodSignatureRegistry {
        let registry = MethodSignatureRegistry()
        for proto in protocols {
            await registry.registerProtocol(proto)
        }
        return registry
    }
}
