// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

/// Processes Swift metadata from Mach-O binaries.
///
/// This processor extracts Swift type information from the `__swift5_*` sections:
/// - `__swift5_types`: Type context descriptors (classes, structs, enums)
/// - `__swift5_fieldmd`: Field descriptors (properties, enum cases)
/// - `__swift5_protos`: Protocol descriptors
/// - `__swift5_proto`: Protocol conformance records
/// - `__swift5_typeref`: Type reference strings
/// - `__swift5_reflstr`: Reflection strings (field names)
///
/// ## Thread Safety
///
/// This class is **not thread-safe** for concurrent access. It maintains internal caches
/// (`fieldDescriptorsByType`, `typeNamesByAddress`) that are mutated during processing.
///
/// **Usage Pattern**: Create an instance, call `parseMetadata()` once, then safely share
/// the resulting `SwiftMetadata` struct (which is `Sendable`). Do not call processing methods
/// concurrently from multiple tasks.
public final class SwiftMetadataProcessor {
    private let data: Data
    private let segments: [SegmentCommand]
    private let byteOrder: ByteOrder
    private let is64Bit: Bool
    private let chainedFixups: ChainedFixups?

    /// Cache of field descriptors by mangled type name.
    private var fieldDescriptorsByType: [String: SwiftFieldDescriptor] = [:]

    /// Cache of type names by address (for resolving type refs).
    private var typeNamesByAddress: [UInt64: String] = [:]

    /// Initialize the Swift metadata processor.
    public init(
        data: Data,
        segments: [SegmentCommand],
        byteOrder: ByteOrder,
        is64Bit: Bool,
        chainedFixups: ChainedFixups? = nil
    ) {
        self.data = data
        self.segments = segments
        self.byteOrder = byteOrder
        self.is64Bit = is64Bit
        self.chainedFixups = chainedFixups
    }

    /// Convenience initializer from a MachOFile.
    public convenience init(machOFile: MachOFile) {
        let fixups = try? machOFile.parseChainedFixups()
        self.init(
            data: machOFile.data,
            segments: machOFile.segments,
            byteOrder: machOFile.byteOrder,
            is64Bit: machOFile.uses64BitABI,
            chainedFixups: fixups
        )
    }

    // MARK: - Public API

    /// Check if this binary contains Swift metadata.
    public var hasSwiftMetadata: Bool {
        findSection(segment: "__TEXT", section: "__swift5_types") != nil
            || findSection(segment: "__TEXT", section: "__swift5_fieldmd") != nil
    }

    /// Process all Swift metadata from the binary.
    public func process() throws -> SwiftMetadata {
        // Parse field descriptors first (needed for type field resolution)
        let fieldDescriptors = try parseFieldDescriptors()

        // Build lookup cache
        for fd in fieldDescriptors {
            fieldDescriptorsByType[fd.mangledTypeName] = fd
        }

        // Parse types
        let types = try parseTypes()

        // Parse protocols
        let protocols = try parseProtocols()

        // Parse conformances
        let conformances = try parseConformances()

        return SwiftMetadata(
            types: types,
            protocols: protocols,
            conformances: conformances,
            fieldDescriptors: fieldDescriptors
        )
    }

    /// Look up field information for a mangled type name.
    ///
    /// This can be used to resolve Swift ivar types that ObjC runtime doesn't provide.
    public func fieldDescriptor(forMangledType mangledType: String) -> SwiftFieldDescriptor? {
        fieldDescriptorsByType[mangledType]
    }

    /// Resolve a field's mangled type name using the symbolic resolver.
    ///
    /// - Parameters:
    ///   - mangledTypeName: The mangled type name (may contain symbolic refs).
    ///   - sourceOffset: The file offset where this name was read.
    /// - Returns: A human-readable type name.
    public func resolveFieldType(_ mangledTypeName: String, at sourceOffset: Int) async -> String {
        guard !mangledTypeName.isEmpty else { return "" }

        // Check if it starts with a symbolic reference marker
        if let firstByte = mangledTypeName.utf8.first,
            SwiftSymbolicReferenceKind.isSymbolicMarker(firstByte)
        {
            let resolver = SwiftSymbolicResolver(
                data: data,
                segments: segments,
                byteOrder: byteOrder,
                chainedFixups: chainedFixups
            )

            if let mangledData = mangledTypeName.data(using: .utf8) {
                return await resolver.resolveType(mangledData: mangledData, sourceOffset: sourceOffset)
            }
        }

        // Fall back to regular demangling
        return SwiftDemangler.demangle(mangledTypeName)
    }

    /// Resolve a field's mangled type using raw data bytes.
    ///
    /// This is more reliable than string-based resolution for symbolic references.
    ///
    /// - Parameters:
    ///   - mangledData: Raw bytes of the mangled type name.
    ///   - sourceOffset: The file offset where this data was read.
    /// - Returns: A human-readable type name.
    public func resolveFieldTypeFromData(_ mangledData: Data, at sourceOffset: Int) async -> String {
        guard !mangledData.isEmpty else { return "" }

        let firstByte = mangledData[mangledData.startIndex]

        // Check if it starts with a symbolic reference marker
        if SwiftSymbolicReferenceKind.isSymbolicMarker(firstByte) {
            let resolver = SwiftSymbolicResolver(
                data: data,
                segments: segments,
                byteOrder: byteOrder,
                chainedFixups: chainedFixups
            )
            return await resolver.resolveType(mangledData: mangledData, sourceOffset: sourceOffset)
        }

        // Fall back to regular demangling
        if let str = String(data: mangledData, encoding: .utf8) {
            return SwiftDemangler.demangle(str)
        }

        return ""
    }

    // MARK: - Section Finding

    private func findSection(segment segmentName: String, section sectionName: String) -> Section? {
        for segment in segments where segment.name == segmentName {
            if let section = segment.sections.first(where: { $0.sectionName == sectionName }) {
                return section
            }
        }
        return nil
    }

    private func readSectionData(_ section: Section) -> Data? {
        let start = Int(section.offset)
        let end = start + Int(section.size)
        guard start >= 0, end <= data.count else { return nil }
        return data.subdata(in: start..<end)
    }

    // MARK: - Address Translation

    private func fileOffset(for address: UInt64) -> Int? {
        for segment in segments {
            if let offset = segment.fileOffset(for: address) {
                return Int(offset)
            }
        }
        return nil
    }

    private func readString(at address: UInt64) -> String? {
        guard address != 0 else { return nil }
        guard let offset = fileOffset(for: address) else { return nil }
        guard offset >= 0, offset < data.count else { return nil }

        var end = offset
        while end < data.count, data[end] != 0 {
            end += 1
        }

        guard end > offset else { return nil }
        let stringData = data.subdata(in: offset..<end)
        return String(data: stringData, encoding: .utf8)
    }

    /// Read a relative pointer (32-bit offset from current position).
    private func readRelativePointer(at fileOffset: Int) -> UInt64? {
        guard fileOffset + 4 <= data.count else { return nil }

        let relOffset: Int32
        if byteOrder == .little {
            relOffset = data.withUnsafeBytes { ptr in
                ptr.loadUnaligned(fromByteOffset: fileOffset, as: Int32.self).littleEndian
            }
        }
        else {
            relOffset = data.withUnsafeBytes { ptr in
                ptr.loadUnaligned(fromByteOffset: fileOffset, as: Int32.self).bigEndian
            }
        }

        // Convert file offset to VM address, apply relative offset
        // For simplicity, we compute directly from file offsets
        let targetOffset = fileOffset + Int(relOffset)
        guard targetOffset >= 0 else { return nil }

        return UInt64(targetOffset)
    }

    private func readUInt32(at offset: Int) -> UInt32 {
        guard offset + 4 <= data.count else { return 0 }
        return data.withUnsafeBytes { ptr in
            byteOrder == .little
                ? ptr.loadUnaligned(fromByteOffset: offset, as: UInt32.self).littleEndian
                : ptr.loadUnaligned(fromByteOffset: offset, as: UInt32.self).bigEndian
        }
    }

    /// Read a string via relative pointer.
    private func readRelativeString(at fileOffset: Int) -> String? {
        guard let targetOffset = readRelativePointer(at: fileOffset) else { return nil }
        guard targetOffset < data.count else { return nil }

        var end = Int(targetOffset)
        while end < data.count, data[end] != 0 {
            end += 1
        }

        guard end > Int(targetOffset) else { return nil }
        let stringData = data.subdata(in: Int(targetOffset)..<end)
        return String(data: stringData, encoding: .utf8)
    }

    /// Read raw bytes via relative pointer (for symbolic references).
    ///
    /// For symbolic references, we need to read a fixed amount of binary data
    /// because the relative offset bytes can contain nulls.
    private func readRelativeData(at fileOffset: Int) -> Data? {
        guard let targetOffset = readRelativePointer(at: fileOffset) else { return nil }
        guard targetOffset >= 0, targetOffset < data.count else { return nil }

        let startOffset = Int(targetOffset)
        let maxLen = min(256, data.count - startOffset)
        guard maxLen > 0 else { return nil }

        // Read data, handling embedded symbolic references
        // Symbolic refs are 5 bytes that can contain nulls in the offset bytes
        var end = startOffset

        while end < startOffset + maxLen {
            let byte = data[end]

            if byte == 0 {
                // Check if this could be part of a symbolic reference
                // Look back up to 4 bytes to see if there was a 0x01 or 0x02 marker
                var isInSymbolicRef = false
                for lookback in 1...4 where end - lookback >= startOffset {
                    let prevByte = data[end - lookback]
                    if prevByte == 0x01 || prevByte == 0x02 {
                        // This null is likely part of the 4-byte offset in a symbolic ref
                        isInSymbolicRef = true
                        break
                    }
                }

                if !isInSymbolicRef {
                    // Real null terminator
                    break
                }
            }

            // Check for symbolic reference markers in the middle
            if (byte == 0x01 || byte == 0x02) && end + 5 <= startOffset + maxLen {
                // Skip over the 5-byte symbolic reference
                end += 5
                continue
            }

            end += 1
        }

        guard end > startOffset else { return nil }
        return data.subdata(in: startOffset..<end)
    }

    // MARK: - Field Descriptor Parsing

    private func parseFieldDescriptors() throws -> [SwiftFieldDescriptor] {
        guard
            let section = findSection(segment: "__TEXT", section: "__swift5_fieldmd")
                ?? findSection(segment: "__DATA_CONST", section: "__swift5_fieldmd")
        else {
            return []
        }

        guard let sectionData = readSectionData(section) else { return [] }

        var descriptors: [SwiftFieldDescriptor] = []
        var offset = 0

        while offset + 16 <= sectionData.count {
            let descriptorOffset = Int(section.offset) + offset

            // Read field descriptor header
            // struct FieldDescriptor {
            //   int32_t MangledTypeName;  // relative pointer
            //   int32_t Superclass;       // relative pointer
            //   uint16_t Kind;
            //   uint16_t FieldRecordSize;
            //   uint32_t NumFields;
            // }

            let mangledTypeNamePointerOffset = descriptorOffset
            let superclassOffset = descriptorOffset + 4
            let kindOffset = descriptorOffset + 8
            let fieldRecordSizeOffset = descriptorOffset + 10
            let numFieldsOffset = descriptorOffset + 12

            // Read both string and raw data for the mangled type name
            let mangledTypeName = readRelativeString(at: mangledTypeNamePointerOffset) ?? ""
            let mangledTypeNameData = readRelativeData(at: mangledTypeNamePointerOffset) ?? Data()
            // Calculate the actual offset where the type name data starts
            var mangledTypeNameDataOffset = 0
            if let targetOffset = readRelativePointer(at: mangledTypeNamePointerOffset) {
                mangledTypeNameDataOffset = Int(targetOffset)
            }
            let superclassMangledName = readRelativeString(at: superclassOffset)

            let kindRaw: UInt16
            if byteOrder == .little {
                kindRaw = data.withUnsafeBytes { ptr in
                    ptr.loadUnaligned(fromByteOffset: kindOffset, as: UInt16.self).littleEndian
                }
            }
            else {
                kindRaw = data.withUnsafeBytes { ptr in
                    ptr.loadUnaligned(fromByteOffset: kindOffset, as: UInt16.self).bigEndian
                }
            }

            let fieldRecordSize: UInt16
            if byteOrder == .little {
                fieldRecordSize = data.withUnsafeBytes { ptr in
                    ptr.loadUnaligned(fromByteOffset: fieldRecordSizeOffset, as: UInt16.self).littleEndian
                }
            }
            else {
                fieldRecordSize = data.withUnsafeBytes { ptr in
                    ptr.loadUnaligned(fromByteOffset: fieldRecordSizeOffset, as: UInt16.self).bigEndian
                }
            }

            let numFields: UInt32
            if byteOrder == .little {
                numFields = data.withUnsafeBytes { ptr in
                    ptr.loadUnaligned(fromByteOffset: numFieldsOffset, as: UInt32.self).littleEndian
                }
            }
            else {
                numFields = data.withUnsafeBytes { ptr in
                    ptr.loadUnaligned(fromByteOffset: numFieldsOffset, as: UInt32.self).bigEndian
                }
            }

            // Parse field records
            var records: [SwiftFieldRecord] = []
            let recordsStart = descriptorOffset + 16

            for i in 0..<Int(numFields) {
                let recordOffset = recordsStart + i * Int(fieldRecordSize)
                guard recordOffset + 12 <= data.count else { break }

                // struct FieldRecord {
                //   uint32_t Flags;
                //   int32_t MangledTypeName;  // relative pointer
                //   int32_t FieldName;        // relative pointer
                // }

                let flags: UInt32
                if byteOrder == .little {
                    flags = data.withUnsafeBytes { ptr in
                        ptr.loadUnaligned(fromByteOffset: recordOffset, as: UInt32.self).littleEndian
                    }
                }
                else {
                    flags = data.withUnsafeBytes { ptr in
                        ptr.loadUnaligned(fromByteOffset: recordOffset, as: UInt32.self).bigEndian
                    }
                }

                // Calculate the actual offset where the type name data starts
                // The relative pointer is at recordOffset + 4, pointing to the type name
                let typeNamePointerOffset = recordOffset + 4
                var typeNameDataOffset = 0
                if let targetOffset = readRelativePointer(at: typeNamePointerOffset) {
                    typeNameDataOffset = Int(targetOffset)
                }

                // Read both string representation and raw bytes
                let fieldTypeName = readRelativeString(at: recordOffset + 4) ?? ""
                let fieldTypeData = readRelativeData(at: recordOffset + 4) ?? Data()
                let fieldName = readRelativeString(at: recordOffset + 8) ?? ""

                records.append(
                    SwiftFieldRecord(
                        flags: flags,
                        name: fieldName,
                        mangledTypeName: fieldTypeName,
                        mangledTypeData: fieldTypeData,
                        mangledTypeNameOffset: typeNameDataOffset
                    )
                )
            }

            let kind = SwiftFieldDescriptorKind(rawValue: kindRaw) ?? .struct

            descriptors.append(
                SwiftFieldDescriptor(
                    address: UInt64(descriptorOffset),
                    kind: kind,
                    mangledTypeName: mangledTypeName,
                    mangledTypeNameData: mangledTypeNameData,
                    mangledTypeNameOffset: mangledTypeNameDataOffset,
                    superclassMangledName: superclassMangledName,
                    records: records
                )
            )

            // Move to next descriptor
            offset += 16 + Int(numFields) * Int(fieldRecordSize)
        }

        return descriptors
    }

    // MARK: - Type Descriptor Parsing

    private func parseTypes() throws -> [SwiftType] {
        guard
            let section = findSection(segment: "__TEXT", section: "__swift5_types")
                ?? findSection(segment: "__DATA_CONST", section: "__swift5_types")
        else {
            return []
        }

        guard let sectionData = readSectionData(section) else { return [] }

        var types: [SwiftType] = []

        // __swift5_types contains an array of 32-bit relative offsets
        // pointing to type context descriptors
        var offset = 0
        while offset + 4 <= sectionData.count {
            let entryOffset = Int(section.offset) + offset

            // Read relative offset to type descriptor
            guard let descriptorOffset = readRelativePointer(at: entryOffset) else {
                offset += 4
                continue
            }

            // Parse the type context descriptor
            if let type = parseTypeDescriptor(at: Int(descriptorOffset)) {
                types.append(type)
            }

            offset += 4
        }

        return types
    }

    private func parseTypeDescriptor(at fileOffset: Int) -> SwiftType? {
        guard fileOffset + 20 <= data.count else { return nil }

        // struct TargetContextDescriptor {
        //   uint32_t Flags;            // +0
        //   int32_t Parent;            // +4 (relative pointer)
        // }
        // struct TargetTypeContextDescriptor : TargetContextDescriptor {
        //   int32_t Name;              // +8 (relative pointer)
        //   int32_t AccessFunction;    // +12 (relative pointer)
        //   int32_t Fields;            // +16 (relative pointer to FieldDescriptor)
        // }
        // struct TargetClassDescriptor : TargetTypeContextDescriptor {
        //   int32_t Superclass;        // +20 (relative pointer to superclass name or descriptor)
        //   uint32_t MetadataNegSize;  // +24
        //   uint32_t MetadataPosSize;  // +28
        //   uint32_t NumImmediateMembers; // +32
        //   uint32_t NumFields;        // +36
        //   uint32_t FieldOffsetVectorOffset; // +40
        //   // If generic (flags & 0x80): GenericContextDescriptorHeader at +44
        // }

        let rawFlags = readUInt32(at: fileOffset)
        let typeFlags = TypeContextDescriptorFlags(rawValue: rawFlags)
        let kindRaw = UInt8(rawFlags & 0x1F)
        guard let kind = SwiftContextDescriptorKind(rawValue: kindRaw), kind.isType else {
            return nil
        }

        // Check if type is generic (bit 7 of flags)
        let isGeneric = typeFlags.isGeneric

        // Read name
        let nameOffset = fileOffset + 8
        let name = readRelativeString(at: nameOffset) ?? ""

        // Read parent (for module/namespace) and determine parent kind
        let parentOffset = fileOffset + 4
        var parentName: String?
        var parentKind: SwiftContextDescriptorKind?
        if let parentDescOffset = readRelativePointer(at: parentOffset),
            parentDescOffset > 0, Int(parentDescOffset) + 8 < data.count
        {
            // Read parent's flags to determine its kind
            let parentFlags = readUInt32(at: Int(parentDescOffset))
            let parentKindRaw = UInt8(parentFlags & 0x1F)
            parentKind = SwiftContextDescriptorKind(rawValue: parentKindRaw)

            // Read parent's name (at +8 in the parent descriptor)
            let parentNameOffset = Int(parentDescOffset) + 8
            parentName = readRelativeString(at: parentNameOffset)
        }

        // Parse class-specific fields
        var superclassName: String?
        var genericParamCount = 0
        var genericParameters: [String] = []
        var genericRequirements: [SwiftGenericRequirement] = []
        let objcClassAddress: UInt64? = nil

        if kind == .class {
            // Read superclass (at +20 for classes)
            if fileOffset + 24 <= data.count {
                superclassName = readRelativeString(at: fileOffset + 20)
                // Demangle superclass name if it's mangled
                if let sc = superclassName, sc.hasPrefix("_Tt") || sc.hasPrefix("$s") {
                    superclassName = SwiftDemangler.demangleSwiftName(sc)
                }
            }

            // Try to find ObjC metadata address
            // For classes with vtable, the metadata accessor is at a known offset
            // This is complex and varies by class layout, so we'll use a heuristic
            if typeFlags.hasVTable && fileOffset + 48 <= data.count {
                // The vtable offset is at +44 for classes with generic header, or +44 without
                // We'll try to find the metadata accessor or class object
                // Note: Full implementation would require more complex analysis
            }

            // Parse generic context header if present
            // Note: The exact offset depends on presence of resilient superclass, etc.
            let genericHeaderOffset: Int
            if typeFlags.hasResilientSuperclass {
                // With resilient superclass, layout is shifted
                genericHeaderOffset = fileOffset + 48
            }
            else {
                // Standard layout: GenericContextDescriptorHeader is at +44 for classes
                genericHeaderOffset = fileOffset + 44
            }

            if isGeneric && genericHeaderOffset + 8 <= data.count {
                // struct GenericContextDescriptorHeader {
                //   uint16_t NumParams;
                //   uint16_t NumRequirements;
                //   uint16_t NumKeyArguments;
                //   uint16_t NumExtraArguments;
                // }
                let rawParamCount = Int(readUInt16(at: genericHeaderOffset))
                let numRequirements = Int(readUInt16(at: genericHeaderOffset + 2))

                // Sanity check: param count should be reasonable (1-16)
                if rawParamCount > 0 && rawParamCount <= 16 {
                    genericParamCount = rawParamCount
                    genericParameters = generateGenericParamNames(count: genericParamCount)

                    // Parse generic requirements if present
                    if numRequirements > 0 && numRequirements <= 32 {
                        let requirementsOffset = genericHeaderOffset + 8
                        genericRequirements = parseGenericRequirements(
                            at: requirementsOffset,
                            count: numRequirements,
                            paramNames: genericParameters
                        )
                    }
                }
                else if isGeneric {
                    // If marked generic but we couldn't parse count, assume at least 1 param
                    genericParamCount = 1
                    genericParameters = ["T"]
                }
            }
            else if isGeneric {
                // Type is generic but we don't have enough data - assume 1 param
                genericParamCount = 1
                genericParameters = ["T"]
            }
        }
        else if kind == .struct || kind == .enum {
            // Struct/Enum have similar layout but without superclass
            // GenericContextDescriptorHeader is at +20 for non-class types
            let genericHeaderOffset = fileOffset + 20

            if isGeneric && genericHeaderOffset + 8 <= data.count {
                let rawParamCount = Int(readUInt16(at: genericHeaderOffset))
                let numRequirements = Int(readUInt16(at: genericHeaderOffset + 2))

                // Sanity check: param count should be reasonable (1-16)
                if rawParamCount > 0 && rawParamCount <= 16 {
                    genericParamCount = rawParamCount
                    genericParameters = generateGenericParamNames(count: genericParamCount)

                    // Parse generic requirements if present
                    if numRequirements > 0 && numRequirements <= 32 {
                        let requirementsOffset = genericHeaderOffset + 8
                        genericRequirements = parseGenericRequirements(
                            at: requirementsOffset,
                            count: numRequirements,
                            paramNames: genericParameters
                        )
                    }
                }
                else if isGeneric {
                    genericParamCount = 1
                    genericParameters = ["T"]
                }
            }
            else if isGeneric {
                genericParamCount = 1
                genericParameters = ["T"]
            }
        }

        // Try to get fields from field descriptor
        let fields: [SwiftField] = []
        let fieldsOffset = fileOffset + 16
        if let fieldDescOffset = readRelativePointer(at: fieldsOffset), fieldDescOffset > 0 {
            // We could parse inline, but we already have parsed field descriptors
            // Just note that fields exist
        }

        return SwiftType(
            address: UInt64(fileOffset),
            kind: kind,
            name: name,
            mangledName: "",
            parentName: parentName,
            parentKind: parentKind,
            superclassName: superclassName,
            fields: fields,
            genericParameters: genericParameters,
            genericParamCount: genericParamCount,
            genericRequirements: genericRequirements,
            flags: typeFlags,
            objcClassAddress: objcClassAddress
        )
    }

    /// Generate generic parameter names for a given count.
    private func generateGenericParamNames(count: Int) -> [String] {
        if count == 1 {
            return ["T"]
        }
        else if count <= 4 {
            return Array(["T", "U", "V", "W"].prefix(count))
        }
        else {
            return (0..<count).map { "T\($0)" }
        }
    }

    /// Parse generic requirements from a requirements array.
    private func parseGenericRequirements(
        at offset: Int,
        count: Int,
        paramNames: [String]
    ) -> [SwiftGenericRequirement] {
        var requirements: [SwiftGenericRequirement] = []
        var currentOffset = offset

        // struct GenericRequirementDescriptor {
        //   uint32_t Flags;           // +0: bits 0-3 = kind, bits 4-7 = extra info
        //   int32_t Param;            // +4: relative pointer to param mangled name
        //   int32_t Type/Protocol;    // +8: relative pointer to type/protocol
        // }

        for _ in 0..<count {
            guard currentOffset + 12 <= data.count else { break }

            let flags = readUInt32(at: currentOffset)
            let kindRaw = UInt8(flags & 0x0F)

            guard let kind = GenericRequirementKind(rawValue: kindRaw) else {
                currentOffset += 12
                continue
            }

            // Read parameter name
            var paramName = ""
            if readRelativePointer(at: currentOffset + 4) != nil {
                // The param is typically an index into the generic params
                // Try to read it as a string first
                if let name = readRelativeString(at: currentOffset + 4) {
                    paramName = SwiftDemangler.demangle(name)
                }
            }

            // If we couldn't get the param name, use a placeholder based on index
            if paramName.isEmpty {
                let paramIndex = Int((flags >> 16) & 0xFF)
                if paramIndex < paramNames.count {
                    paramName = paramNames[paramIndex]
                }
                else {
                    paramName = "T\(paramIndex)"
                }
            }

            // Read constraint type or protocol
            var constraint = ""
            if let constraintName = readRelativeString(at: currentOffset + 8) {
                constraint = SwiftDemangler.demangle(constraintName)
            }

            // Handle special cases
            if kind == .layout && constraint.isEmpty {
                // Layout constraints are typically AnyObject
                constraint = "AnyObject"
            }

            requirements.append(
                SwiftGenericRequirement(
                    kind: kind,
                    param: paramName,
                    constraint: constraint,
                    flags: flags
                )
            )

            currentOffset += 12
        }

        return requirements
    }

    private func readUInt16(at offset: Int) -> UInt16 {
        guard offset + 2 <= data.count else { return 0 }
        return data.withUnsafeBytes { ptr in
            byteOrder == .little
                ? ptr.loadUnaligned(fromByteOffset: offset, as: UInt16.self).littleEndian
                : ptr.loadUnaligned(fromByteOffset: offset, as: UInt16.self).bigEndian
        }
    }

    // MARK: - Protocol Parsing

    private func parseProtocols() throws -> [SwiftProtocol] {
        guard
            let section = findSection(segment: "__TEXT", section: "__swift5_protos")
                ?? findSection(segment: "__DATA_CONST", section: "__swift5_protos")
        else {
            return []
        }

        guard let sectionData = readSectionData(section) else { return [] }

        var protocols: [SwiftProtocol] = []

        // Similar to types, contains relative offsets to protocol descriptors
        var offset = 0
        while offset + 4 <= sectionData.count {
            let entryOffset = Int(section.offset) + offset

            guard let descriptorOffset = readRelativePointer(at: entryOffset) else {
                offset += 4
                continue
            }

            if let proto = parseProtocolDescriptor(at: Int(descriptorOffset)) {
                protocols.append(proto)
            }

            offset += 4
        }

        return protocols
    }

    private func parseProtocolDescriptor(at fileOffset: Int) -> SwiftProtocol? {
        guard fileOffset + 28 <= data.count else { return nil }

        // Protocol descriptor layout:
        // struct TargetProtocolDescriptor {
        //   uint32_t Flags;                    // +0
        //   int32_t Parent;                    // +4 relative pointer to module/context
        //   int32_t Name;                      // +8 relative pointer to name string
        //   int32_t NumRequirementsInSignature; // +12 (generic requirements count)
        //   int32_t NumRequirements;           // +16 (witness table requirements)
        //   int32_t Requirements;              // +20 relative pointer to requirements array
        //   int32_t AssociatedTypeNames;       // +24 relative pointer to space-separated names
        // }
        //
        // Note: Layout may vary slightly based on flags. We handle the most common case.

        // Read protocol name
        let name = readRelativeString(at: fileOffset + 8) ?? ""

        // Read parent module name
        var parentName: String?
        if let parentDescOffset = readRelativePointer(at: fileOffset + 4),
            parentDescOffset > 0, Int(parentDescOffset) + 8 < data.count
        {
            // Parent is typically a module descriptor, which has name at offset +8
            parentName = readRelativeString(at: Int(parentDescOffset) + 8)
        }

        // Read associated type names (space-separated)
        // Try offset +24 first (standard), then +12 (older format)
        var associatedTypeNamesStr = readRelativeString(at: fileOffset + 24) ?? ""
        if associatedTypeNamesStr.isEmpty {
            associatedTypeNamesStr = readRelativeString(at: fileOffset + 12) ?? ""
        }
        let associatedTypeNamesList =
            associatedTypeNamesStr.isEmpty
            ? [String]()
            : associatedTypeNamesStr.split(separator: " ").map(String.init)
        let associatedTypeNames = associatedTypeNamesList

        // Read number of requirements
        // Try offset +16 first (standard), then +20 (older format)
        var numRequirements = Int(readUInt32(at: fileOffset + 16))
        var requirementsPointerOffset = fileOffset + 20

        // Validate: if numRequirements seems too large, try alternate layout
        if numRequirements > 1000 {
            numRequirements = Int(readUInt32(at: fileOffset + 20))
            requirementsPointerOffset = fileOffset + 24
        }

        var requirements: [SwiftProtocolRequirement] = []
        var inheritedProtocols: [String] = []
        requirements.reserveCapacity(max(0, numRequirements))

        if numRequirements > 0,
            let requirementsStart = readRelativePointer(at: requirementsPointerOffset)
        {
            // Create a mutable copy for consuming associated types
            var remainingAssociatedTypes = associatedTypeNamesList

            var currentOffset = Int(requirementsStart)
            for _ in 0..<numRequirements {
                guard currentOffset + 8 <= data.count else { break }

                // Requirement layout:
                // struct ProtocolRequirement {
                //   uint32_t Flags;              // +0: low 4 bits = kind, bit 4 = isInstance, bit 5 = isAsync
                //   int32_t DefaultImpl;         // +4: relative pointer to default impl (0 if none)
                // }

                let flags = readUInt32(at: currentOffset)
                let kindValue = UInt8(flags & 0x0F)
                let isInstance = (flags & 0x10) != 0
                let isAsync = (flags & 0x20) != 0

                // Check for default implementation
                var hasDefaultImpl = false
                if let defaultImplOffset = readRelativePointer(at: currentOffset + 4),
                    defaultImplOffset != 0
                {
                    hasDefaultImpl = true
                }

                let kind = SwiftProtocolRequirement.Kind(rawValue: kindValue)

                if let kind {
                    var requirementName = ""

                    switch kind {
                        case .baseProtocol:
                            // The DefaultImpl pointer actually points to the protocol descriptor
                            if let protoDescOffset = readRelativePointer(at: currentOffset + 4),
                                protoDescOffset > 0, Int(protoDescOffset) + 12 < data.count,
                                let protoName = readRelativeString(at: Int(protoDescOffset) + 8),
                                !protoName.isEmpty
                            {
                                requirementName = protoName
                                inheritedProtocols.append(protoName)
                            }
                            // Don't count this as having a "default impl" since it's actually a protocol reference
                            hasDefaultImpl = false

                        case .associatedTypeAccessFunction:
                            // Consume the next associated type name
                            if !remainingAssociatedTypes.isEmpty {
                                requirementName = remainingAssociatedTypes.removeFirst()
                            }

                        case .associatedConformanceAccessFunction:
                            // Associated conformances don't have explicit names in the descriptor
                            break

                        case .method, .initializer:
                            // Method/initializer names are not stored directly in the descriptor
                            // They would need to be resolved from symbol table or witness tables
                            break

                        case .getter, .setter:
                            // Property names are not stored directly in the descriptor
                            // The getter and setter share the same property, so we could track pairs
                            break

                        case .readCoroutine, .modifyCoroutine:
                            // Coroutine accessors for properties
                            break
                    }

                    requirements.append(
                        SwiftProtocolRequirement(
                            kind: kind,
                            name: requirementName,
                            isInstance: isInstance,
                            isAsync: isAsync,
                            hasDefaultImplementation: hasDefaultImpl
                        )
                    )
                }

                currentOffset += 8
            }
        }

        return SwiftProtocol(
            address: UInt64(fileOffset),
            name: name,
            mangledName: "",
            parentName: parentName,
            associatedTypeNames: associatedTypeNames,
            inheritedProtocols: inheritedProtocols,
            requirements: requirements
        )
    }

    // MARK: - Conformance Parsing

    private func parseConformances() throws -> [SwiftConformance] {
        guard
            let section = findSection(segment: "__TEXT", section: "__swift5_proto")
                ?? findSection(segment: "__DATA_CONST", section: "__swift5_proto")
        else {
            return []
        }

        guard let sectionData = readSectionData(section) else { return [] }

        var conformances: [SwiftConformance] = []

        // Conformance records are 16 bytes each
        var offset = 0
        while offset + 16 <= sectionData.count {
            let entryOffset = Int(section.offset) + offset

            // struct TargetProtocolConformanceDescriptor {
            //   int32_t Protocol;            // +0: relative pointer to protocol descriptor
            //   int32_t TypeRef;             // +4: type reference (kind depends on flags)
            //   int32_t WitnessTablePattern; // +8: witness table pattern
            //   uint32_t Flags;              // +12: conformance flags
            // }

            let protocolOffset = entryOffset
            let typeRefOffset = entryOffset + 4

            // Read flags
            let rawFlags = sectionData.withUnsafeBytes { bytes in
                bytes.load(fromByteOffset: offset + 12, as: UInt32.self)
            }
            let flags = ConformanceFlags(rawValue: rawFlags)

            // Read protocol descriptor address and name
            var protocolName = ""
            var protocolAddress: UInt64 = 0
            if let protoDescOffset = readRelativePointer(at: protocolOffset),
                protoDescOffset > 0
            {
                protocolAddress = UInt64(protoDescOffset)
                // Protocol name is at offset +8 in the protocol descriptor
                let protoNameOffset = Int(protoDescOffset) + 8
                protocolName = readRelativeString(at: protoNameOffset) ?? ""
            }

            // Read type name based on type reference kind
            var typeName = ""
            var mangledTypeName = ""
            var typeAddress: UInt64 = 0

            switch flags.typeReferenceKind {
                case .directTypeDescriptor, .indirectTypeDescriptor:
                    // For type descriptors, read the mangled name
                    if let typeDescOffset = readRelativePointer(at: typeRefOffset),
                        typeDescOffset > 0
                    {
                        typeAddress = UInt64(typeDescOffset)
                        // Type name is at offset +8 in the type descriptor
                        let typeNameOffset = Int(typeDescOffset) + 8
                        if let name = readRelativeString(at: typeNameOffset) {
                            typeName = name
                        }
                        // Try to read mangled name at offset +16
                        let mangledOffset = Int(typeDescOffset) + 16
                        if let mangled = readRelativeString(at: mangledOffset) {
                            mangledTypeName = mangled
                        }
                    }

                case .directObjCClass, .indirectObjCClass:
                    // For ObjC classes, try to read the class name
                    if let typeRefValue = readRelativePointer(at: typeRefOffset) {
                        typeAddress = UInt64(typeRefValue)
                        // Try to demangle if it's a Swift-exposed ObjC name
                        typeName = readRelativeString(at: typeRefOffset) ?? ""
                    }
            }

            // If we still don't have a type name, try reading directly
            if typeName.isEmpty {
                typeName = readRelativeString(at: typeRefOffset) ?? ""
            }

            if !protocolName.isEmpty || !typeName.isEmpty {
                conformances.append(
                    SwiftConformance(
                        address: UInt64(entryOffset),
                        typeAddress: typeAddress,
                        typeName: typeName,
                        mangledTypeName: mangledTypeName,
                        protocolName: protocolName,
                        protocolAddress: protocolAddress,
                        flags: flags
                    )
                )
            }

            offset += 16
        }

        return conformances
    }
}

// MARK: - MachOFile Extension

extension MachOFile {
    /// Check if this binary contains Swift metadata.
    public var hasSwiftMetadata: Bool {
        // Check for __swift5_types or __swift5_fieldmd sections
        for segment in segments where segment.name == "__TEXT" || segment.name == "__DATA_CONST" {
            for section in segment.sections where section.sectionName.hasPrefix("__swift5_") {
                return true
            }
        }
        return false
    }

    /// Parse Swift metadata from this binary.
    public func parseSwiftMetadata() throws -> SwiftMetadata {
        let processor = SwiftMetadataProcessor(machOFile: self)
        return try processor.process()
    }
}
