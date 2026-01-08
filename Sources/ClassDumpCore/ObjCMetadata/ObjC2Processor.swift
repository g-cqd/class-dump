import Foundation

/// Errors that can occur during ObjC metadata processing.
public enum ObjCProcessorError: Error, Sendable {
    case sectionNotFound(String)
    case invalidAddress(UInt64)
    case invalidData(String)
    case invalidPointer(UInt64)
}

/// Result of processing ObjC metadata from a binary.
public struct ObjCMetadata: Sendable {
    public let classes: [ObjCClass]
    public let protocols: [ObjCProtocol]
    public let categories: [ObjCCategory]
    public let imageInfo: ObjC2ImageInfo?

    public init(
        classes: [ObjCClass] = [],
        protocols: [ObjCProtocol] = [],
        categories: [ObjCCategory] = [],
        imageInfo: ObjC2ImageInfo? = nil
    ) {
        self.classes = classes
        self.protocols = protocols
        self.categories = categories
        self.imageInfo = imageInfo
    }

    /// Returns a sorted copy of this metadata.
    public func sorted() -> ObjCMetadata {
        ObjCMetadata(
            classes: classes.sorted(),
            protocols: protocols.sorted(),
            categories: categories.sorted(),
            imageInfo: imageInfo
        )
    }
}

/// Processor for ObjC 2.0 metadata in Mach-O binaries.
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

    /// Pointer size in bytes.
    private var ptrSize: Int {
        is64Bit ? 8 : 4
    }

    /// Cache of loaded classes by address.
    private var classesByAddress: [UInt64: ObjCClass] = [:]

    /// Cache of loaded protocols by address (for uniquing).
    private var protocolsByAddress: [UInt64: ObjCProtocol] = [:]

    /// Initialize with binary data and segment information.
    public init(
        data: Data, segments: [SegmentCommand], byteOrder: ByteOrder, is64Bit: Bool,
        chainedFixups: ChainedFixups? = nil, swiftMetadata: SwiftMetadata? = nil
    ) {
        self.data = data
        self.segments = segments
        self.byteOrder = byteOrder
        self.is64Bit = is64Bit
        self.chainedFixups = chainedFixups
        self.swiftMetadata = swiftMetadata

        // Build Swift field lookups
        if let swift = swiftMetadata {
            // First, build a mapping from Swift types to their simple names
            var typeNameByAddress: [UInt64: String] = [:]
            for swiftType in swift.types {
                typeNameByAddress[swiftType.address] = swiftType.name
            }

            for fd in swift.fieldDescriptors {
                // Index by raw mangled type name
                swiftFieldsByMangledName[fd.mangledTypeName] = fd

                // Try to extract a simple name from the mangled type
                var simpleName: String?

                // First try extracting from the mangled name
                let demangled = SwiftDemangler.extractTypeName(fd.mangledTypeName)
                if !demangled.isEmpty && !demangled.hasPrefix("/*") {
                    // Extract just the class name (last component)
                    if demangled.contains(".") {
                        simpleName = String(demangled.split(separator: ".").last ?? Substring(demangled))
                    } else {
                        simpleName = demangled
                    }
                }

                // If we have a simple name, index by it
                if let name = simpleName, !name.isEmpty, name != fd.mangledTypeName {
                    swiftFieldsByClassName[name] = fd
                }

                // Also index by the address if we can match to a SwiftType
                if let typeName = typeNameByAddress[fd.address] {
                    swiftFieldsByClassName[typeName] = fd
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

    /// Process all ObjC metadata from the binary.
    public func process() throws -> ObjCMetadata {
        // Clear caches
        classesByAddress.removeAll()
        protocolsByAddress.removeAll()

        // Load image info first
        let imageInfo = try? loadImageInfo()

        // Load protocols first (they may be referenced by classes)
        let protocols = try loadProtocols()

        // Load classes
        let classes = try loadClasses()

        // Load categories
        let categories = try loadCategories()

        return ObjCMetadata(
            classes: classes,
            protocols: protocols,
            categories: categories,
            imageInfo: imageInfo
        )
    }

    // MARK: - Section Loading

    /// Find a section by segment and section name.
    private func findSection(segment segmentName: String, section sectionName: String) -> Section? {
        for segment in segments {
            if segment.name == segmentName || segment.name.hasPrefix(segmentName) {
                if let section = segment.section(named: sectionName) {
                    return section
                }
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
    private func fileOffset(for address: UInt64) -> Int? {
        for segment in segments {
            if let offset = segment.fileOffset(for: address) {
                return Int(offset)
            }
        }
        return nil
    }

    /// Read a null-terminated string at the given virtual address.
    private func readString(at address: UInt64) -> String? {
        guard address != 0 else { return nil }
        guard let offset = fileOffset(for: address) else { return nil }
        guard offset >= 0 && offset < data.count else { return nil }

        // Find the null terminator
        var end = offset
        while end < data.count && data[end] != 0 {
            end += 1
        }

        guard end > offset else { return nil }
        let stringData = data.subdata(in: offset..<end)
        return String(data: stringData, encoding: .utf8)
    }

    /// Read a pointer value at the given virtual address.
    private func readPointer(at address: UInt64) throws -> UInt64 {
        guard let offset = fileOffset(for: address) else {
            throw ObjCProcessorError.invalidAddress(address)
        }

        var cursor = try DataCursor(data: data, offset: offset)

        if is64Bit {
            let rawValue = byteOrder == .little ? try cursor.readLittleInt64() : try cursor.readBigInt64()
            return decodeChainedFixupPointer(rawValue)
        } else {
            let value = byteOrder == .little ? try cursor.readLittleInt32() : try cursor.readBigInt32()
            return UInt64(value)
        }
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
            let targetMask36: UInt64 = (1 << 36) - 1  // 0xFFFFFFFFF (36 bits)
            let target = rawPointer & targetMask36

            // high8 is at bits 36-43
            let high8 = (rawPointer >> 36) & 0xFF

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

    /// Lazy symbolic resolver for Swift type references.
    private lazy var symbolicResolver: SwiftSymbolicResolver? = {
        SwiftSymbolicResolver(data: data, segments: segments, byteOrder: byteOrder)
    }()

    /// Try to resolve a Swift type name for an ivar based on class name and field name.
    ///
    /// Swift classes expose ivars to ObjC runtime but don't provide type encodings.
    /// We can look up the type from Swift field descriptors if available.
    private func resolveSwiftIvarType(className: String, ivarName: String) -> String? {
        guard swiftMetadata != nil else { return nil }

        // Extract the demangled class name from ObjC mangled name
        // ObjC names look like "_TtC13IDEFoundation25SomeClassName"
        var targetClassName = className

        // Try to extract the actual class name from mangled ObjC format
        if className.hasPrefix("_TtC") {
            if let (_, name) = SwiftDemangler.demangleClassName(className) {
                targetClassName = name
            }
        } else if className.hasPrefix("_Tt") {
            // Other mangled formats - try to extract the last component
            // The class name is typically at the end after module name
            targetClassName = extractSimpleClassName(from: className)
        }

        // First, try direct lookup by class name (fastest path)
        if let descriptor = swiftFieldsByClassName[targetClassName] {
            if let resolved = resolveFieldFromDescriptor(descriptor, fieldName: ivarName) {
                return resolved
            }
        }

        // Fall back to searching through all descriptors
        for (mangledTypeName, descriptor) in swiftFieldsByMangledName {
            // The mangled type name in field descriptors may be a symbolic reference
            // or a mangled string. Try to match based on demangled class name.
            let demangled = SwiftDemangler.extractTypeName(mangledTypeName)

            // Check if this descriptor matches our class
            let descriptorClassName = extractSimpleClassName(from: demangled)

            if descriptorClassName == targetClassName || demangled.hasSuffix(targetClassName)
                || mangledTypeName.contains(targetClassName)
            {
                if let resolved = resolveFieldFromDescriptor(descriptor, fieldName: ivarName) {
                    return resolved
                }
            }
        }

        return nil
    }

    /// Resolve a field's type from a descriptor by field name.
    private func resolveFieldFromDescriptor(_ descriptor: SwiftFieldDescriptor, fieldName ivarName: String)
        -> String?
    {
        for record in descriptor.records {
            // Handle lazy storage prefix and other Swift internal prefixes
            var fieldName = record.name
            fieldName = fieldName.replacingOccurrences(of: "$__lazy_storage_$_", with: "")
            fieldName = fieldName.replacingOccurrences(of: "_$s", with: "")

            if fieldName == ivarName || record.name == ivarName {
                // Try to resolve the type using symbolic resolver
                // Prefer raw data for symbolic references
                if record.hasSymbolicReference {
                    // Use symbolic resolver with raw data
                    if let resolver = symbolicResolver {
                        let resolved = resolver.resolveType(
                            mangledData: record.mangledTypeData,
                            sourceOffset: record.mangledTypeNameOffset
                        )
                        if !resolved.isEmpty && !resolved.hasPrefix("/*") {
                            return resolved
                        }
                    }
                } else if !record.mangledTypeName.isEmpty {
                    // Regular mangled name
                    let demangled = SwiftDemangler.demangle(record.mangledTypeName)
                    if demangled != "/* symbolic ref */" && demangled != record.mangledTypeName {
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

    private func loadProtocols() throws -> [ObjCProtocol] {
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
        var protocols: [ObjCProtocol] = []

        while cursor.offset < sectionData.count {
            let rawAddress: UInt64
            if is64Bit {
                rawAddress = byteOrder == .little ? try cursor.readLittleInt64() : try cursor.readBigInt64()
            } else {
                let value = byteOrder == .little ? try cursor.readLittleInt32() : try cursor.readBigInt32()
                rawAddress = UInt64(value)
            }

            let protocolAddress = decodeChainedFixupPointer(rawAddress)
            if protocolAddress != 0 {
                if let proto = try loadProtocol(at: protocolAddress) {
                    protocols.append(proto)
                }
            }
        }

        return protocols
    }

    private func loadProtocol(at address: UInt64) throws -> ObjCProtocol? {
        guard address != 0 else { return nil }

        // Check cache first
        if let cached = protocolsByAddress[address] {
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

        // Cache immediately to handle circular references
        protocolsByAddress[address] = proto

        // Load adopted protocols
        if rawProtocol.protocols != 0 {
            let adoptedAddresses = try loadProtocolAddressList(at: rawProtocol.protocols)
            for adoptedAddr in adoptedAddresses {
                if let adoptedProto = try loadProtocol(at: adoptedAddr) {
                    proto.addAdoptedProtocol(adoptedProto)
                }
            }
        }

        // Load methods
        for method in try loadMethods(
            at: rawProtocol.instanceMethods, extendedTypesAddress: rawProtocol.extendedMethodTypes)
        {
            proto.addInstanceMethod(method)
        }

        for method in try loadMethods(
            at: rawProtocol.classMethods, extendedTypesAddress: rawProtocol.extendedMethodTypes)
        {
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
        } else {
            let value = byteOrder == .little ? try cursor.readLittleInt32() : try cursor.readBigInt32()
            rawCount = UInt64(value)
        }
        // The count itself shouldn't be a chained fixup, but decode just in case
        let count = decodeChainedFixupPointer(rawCount)

        for _ in 0..<count {
            let rawAddr: UInt64
            if is64Bit {
                rawAddr = byteOrder == .little ? try cursor.readLittleInt64() : try cursor.readBigInt64()
            } else {
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

    private func loadClasses() throws -> [ObjCClass] {
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
        var classes: [ObjCClass] = []

        while cursor.offset < sectionData.count {
            let rawAddress: UInt64
            if is64Bit {
                rawAddress = byteOrder == .little ? try cursor.readLittleInt64() : try cursor.readBigInt64()
            } else {
                let value = byteOrder == .little ? try cursor.readLittleInt32() : try cursor.readBigInt32()
                rawAddress = UInt64(value)
            }

            let classAddress = decodeChainedFixupPointer(rawAddress)
            if classAddress != 0 {
                if let aClass = try loadClass(at: classAddress) {
                    classes.append(aClass)
                }
            }
        }

        return classes
    }

    private func loadClass(at address: UInt64) throws -> ObjCClass? {
        guard address != 0 else { return nil }

        // Check cache first
        if let cached = classesByAddress[address] {
            return cached
        }

        guard let offset = fileOffset(for: address) else {
            return nil
        }

        var cursor = try DataCursor(data: data, offset: offset)
        let rawClass = try ObjC2Class(cursor: &cursor, byteOrder: byteOrder, is64Bit: is64Bit)

        // Load class data (class_ro_t)
        // The dataPointer may have the Swift flag in bit 0, and may be a chained fixup pointer
        let rawDataPointer = rawClass.dataPointer
        let decodedDataPointer = decodeChainedFixupPointer(rawDataPointer)
        // Mask off low bits (Swift class flags)
        let dataPointerClean = decodedDataPointer & ~0x7

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

        // Cache immediately
        classesByAddress[address] = aClass

        // Load superclass - may be an address or a bind to external symbol
        let superclassResult = decodePointerWithBindInfo(rawClass.superclass)
        switch superclassResult {
        case .address(let superclassAddr):
            if superclassAddr != 0, let superclass = try loadClass(at: superclassAddr) {
                aClass.superclassRef = ObjCClassReference(name: superclass.name, address: superclassAddr)
            }
        case .bindSymbol(let symbolName):
            // External superclass (e.g., NSObject from Foundation)
            // The symbol name is the class name prefixed with OBJC_CLASS_$_
            let className: String
            if symbolName.hasPrefix("OBJC_CLASS_$_") {
                className = String(symbolName.dropFirst("OBJC_CLASS_$_".count))
            } else {
                className = symbolName
            }
            aClass.superclassRef = ObjCClassReference(name: className, address: 0)
        case .bindOrdinal(let ordinal):
            // We have an ordinal but couldn't resolve the name
            aClass.superclassRef = ObjCClassReference(name: "/* bind ordinal \(ordinal) */", address: 0)
        }

        // Load instance methods
        for method in try loadMethods(at: classData.baseMethods) {
            aClass.addInstanceMethod(method)
        }

        // Load class methods from metaclass (decode chained fixup pointer)
        let isaAddr = decodeChainedFixupPointer(rawClass.isa)
        if isaAddr != 0 {
            for method in try loadClassMethods(at: isaAddr) {
                aClass.addClassMethod(method)
            }
        }

        // Load instance variables (pass class name for Swift type resolution)
        for ivar in try loadInstanceVariables(at: classData.ivars, className: aClass.name) {
            aClass.addInstanceVariable(ivar)
        }

        // Load protocols
        let protocolAddresses = try loadProtocolAddressList(at: classData.baseProtocols)
        for protoAddr in protocolAddresses {
            if let proto = protocolsByAddress[protoAddr] ?? (try? loadProtocol(at: protoAddr)) {
                aClass.addAdoptedProtocol(proto)
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
        let dataPointerClean = decodedDataPointer & ~0x7
        guard dataPointerClean != 0 else { return [] }
        guard let dataOffset = fileOffset(for: dataPointerClean) else { return [] }

        var dataCursor = try DataCursor(data: data, offset: dataOffset)
        let classData = try ObjC2ClassROData(cursor: &dataCursor, byteOrder: byteOrder, is64Bit: is64Bit)

        return try loadMethods(at: classData.baseMethods)
    }

    // MARK: - Category Loading

    private func loadCategories() throws -> [ObjCCategory] {
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
            } else {
                let value = byteOrder == .little ? try cursor.readLittleInt32() : try cursor.readBigInt32()
                rawAddress = UInt64(value)
            }

            let categoryAddress = decodeChainedFixupPointer(rawAddress)
            if categoryAddress != 0 {
                if let category = try loadCategory(at: categoryAddress) {
                    categories.append(category)
                }
            }
        }

        return categories
    }

    private func loadCategory(at address: UInt64) throws -> ObjCCategory? {
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
            if clsAddr != 0, let aClass = classesByAddress[clsAddr] ?? (try? loadClass(at: clsAddr)) {
                category.classRef = ObjCClassReference(name: aClass.name, address: clsAddr)
            }
        case .bindSymbol(let symbolName):
            // External class (e.g., NSObject from Foundation)
            let className: String
            if symbolName.hasPrefix("OBJC_CLASS_$_") {
                className = String(symbolName.dropFirst("OBJC_CLASS_$_".count))
            } else {
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

        // Load protocols
        let protocolAddresses = try loadProtocolAddressList(at: rawCategory.protocols)
        for protoAddr in protocolAddresses {
            if let proto = protocolsByAddress[protoAddr] ?? (try? loadProtocol(at: protoAddr)) {
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
                } else {
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

    private func loadInstanceVariables(at address: UInt64, className: String = "") throws -> [ObjCInstanceVariable] {
        guard address != 0 else { return [] }

        // Decode the address (may be a chained fixup pointer)
        let decodedAddress = decodeChainedFixupPointer(address)
        guard let offset = fileOffset(for: decodedAddress) else { return [] }

        var cursor = try DataCursor(data: data, offset: offset)
        let listHeader = try ObjC2ListHeader(cursor: &cursor, byteOrder: byteOrder)

        var ivars: [ObjCInstanceVariable] = []

        // Check if this is a Swift class (for type resolution)
        let isSwift = isSwiftClass(name: className)

        for _ in 0..<listHeader.count {
            let rawIvar = try ObjC2Ivar(cursor: &cursor, byteOrder: byteOrder, is64Bit: is64Bit)

            // Decode chained fixup pointers
            let nameAddr = decodeChainedFixupPointer(rawIvar.name)
            guard nameAddr != 0 else { continue }
            guard let name = readString(at: nameAddr) else { continue }

            let typeAddr = decodeChainedFixupPointer(rawIvar.type)
            var typeString = readString(at: typeAddr) ?? ""

            // For Swift classes with empty type strings, try to resolve from Swift metadata
            if typeString.isEmpty && isSwift {
                if let swiftType = resolveSwiftIvarType(className: className, ivarName: name) {
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
                } else {
                    let value =
                        byteOrder == .little ? try offsetCursor.readLittleInt32() : try offsetCursor.readBigInt32()
                    actualOffset = UInt64(value)
                }
            }

            let ivar = ObjCInstanceVariable(
                name: name,
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
