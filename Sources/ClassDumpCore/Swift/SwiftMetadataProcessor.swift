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
public final class SwiftMetadataProcessor {
    private let data: Data
    private let segments: [SegmentCommand]
    private let byteOrder: ByteOrder
    private let is64Bit: Bool

    /// Cache of field descriptors by mangled type name.
    private var fieldDescriptorsByType: [String: SwiftFieldDescriptor] = [:]

    /// Cache of type names by address (for resolving type refs).
    private var typeNamesByAddress: [UInt64: String] = [:]

    public init(
        data: Data,
        segments: [SegmentCommand],
        byteOrder: ByteOrder,
        is64Bit: Bool
    ) {
        self.data = data
        self.segments = segments
        self.byteOrder = byteOrder
        self.is64Bit = is64Bit
    }

    /// Convenience initializer from a MachOFile.
    public convenience init(machOFile: MachOFile) {
        self.init(
            data: machOFile.data,
            segments: machOFile.segments,
            byteOrder: machOFile.byteOrder,
            is64Bit: machOFile.uses64BitABI
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
        } else {
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

            let mangledTypeNameOffset = descriptorOffset
            let superclassOffset = descriptorOffset + 4
            let kindOffset = descriptorOffset + 8
            let fieldRecordSizeOffset = descriptorOffset + 10
            let numFieldsOffset = descriptorOffset + 12

            let mangledTypeName = readRelativeString(at: mangledTypeNameOffset) ?? ""
            let superclassMangledName = readRelativeString(at: superclassOffset)

            let kindRaw: UInt16
            if byteOrder == .little {
                kindRaw = data.withUnsafeBytes { ptr in
                    ptr.loadUnaligned(fromByteOffset: kindOffset, as: UInt16.self).littleEndian
                }
            } else {
                kindRaw = data.withUnsafeBytes { ptr in
                    ptr.loadUnaligned(fromByteOffset: kindOffset, as: UInt16.self).bigEndian
                }
            }

            let fieldRecordSize: UInt16
            if byteOrder == .little {
                fieldRecordSize = data.withUnsafeBytes { ptr in
                    ptr.loadUnaligned(fromByteOffset: fieldRecordSizeOffset, as: UInt16.self).littleEndian
                }
            } else {
                fieldRecordSize = data.withUnsafeBytes { ptr in
                    ptr.loadUnaligned(fromByteOffset: fieldRecordSizeOffset, as: UInt16.self).bigEndian
                }
            }

            let numFields: UInt32
            if byteOrder == .little {
                numFields = data.withUnsafeBytes { ptr in
                    ptr.loadUnaligned(fromByteOffset: numFieldsOffset, as: UInt32.self).littleEndian
                }
            } else {
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
                } else {
                    flags = data.withUnsafeBytes { ptr in
                        ptr.loadUnaligned(fromByteOffset: recordOffset, as: UInt32.self).bigEndian
                    }
                }

                let fieldTypeName = readRelativeString(at: recordOffset + 4) ?? ""
                let fieldName = readRelativeString(at: recordOffset + 8) ?? ""

                records.append(
                    SwiftFieldRecord(
                        flags: flags,
                        name: fieldName,
                        mangledTypeName: fieldTypeName
                    ))
            }

            let kind = SwiftFieldDescriptorKind(rawValue: kindRaw) ?? .struct

            descriptors.append(
                SwiftFieldDescriptor(
                    address: UInt64(descriptorOffset),
                    kind: kind,
                    mangledTypeName: mangledTypeName,
                    superclassMangledName: superclassMangledName,
                    records: records
                ))

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
        guard fileOffset + 16 <= data.count else { return nil }

        // struct TargetContextDescriptor {
        //   uint32_t Flags;
        //   int32_t Parent;  // relative pointer
        // }
        // struct TargetTypeContextDescriptor : TargetContextDescriptor {
        //   int32_t Name;          // relative pointer
        //   int32_t AccessFunction; // relative pointer
        //   int32_t Fields;        // relative pointer to FieldDescriptor
        // }

        let flags: UInt32
        if byteOrder == .little {
            flags = data.withUnsafeBytes { ptr in
                ptr.loadUnaligned(fromByteOffset: fileOffset, as: UInt32.self).littleEndian
            }
        } else {
            flags = data.withUnsafeBytes { ptr in
                ptr.loadUnaligned(fromByteOffset: fileOffset, as: UInt32.self).bigEndian
            }
        }

        let kindRaw = UInt8(flags & 0x1F)
        guard let kind = SwiftContextDescriptorKind(rawValue: kindRaw), kind.isType else {
            return nil
        }

        // Read name
        let nameOffset = fileOffset + 8
        let name = readRelativeString(at: nameOffset) ?? ""

        // Read parent (for module/namespace)
        let parentOffset = fileOffset + 4
        var parentName: String?
        if let parentDescOffset = readRelativePointer(at: parentOffset),
            parentDescOffset > 0, Int(parentDescOffset) + 8 < data.count
        {
            // Try to read parent's name
            let parentNameOffset = Int(parentDescOffset) + 8
            parentName = readRelativeString(at: parentNameOffset)
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
            superclassName: nil,
            fields: fields,
            genericParameters: []
        )
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
        guard fileOffset + 24 <= data.count else { return nil }

        // struct TargetProtocolDescriptor {
        //   ContextDescriptorFlags Flags;
        //   int32_t Parent;
        //   int32_t Name;
        //   // ... more fields
        // }

        let nameOffset = fileOffset + 8
        let name = readRelativeString(at: nameOffset) ?? ""

        return SwiftProtocol(
            address: UInt64(fileOffset),
            name: name,
            mangledName: "",
            requirements: []
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
            //   int32_t Protocol;     // relative pointer to protocol descriptor
            //   int32_t TypeRef;      // type reference
            //   int32_t WitnessTablePattern;
            //   uint32_t Flags;
            // }

            let protocolOffset = entryOffset
            let typeRefOffset = entryOffset + 4

            // Read protocol name (via protocol descriptor)
            var protocolName = ""
            if let protoDescOffset = readRelativePointer(at: protocolOffset),
                protoDescOffset > 0
            {
                let protoNameOffset = Int(protoDescOffset) + 8
                protocolName = readRelativeString(at: protoNameOffset) ?? ""
            }

            // Read type name
            let typeName = readRelativeString(at: typeRefOffset) ?? ""

            if !protocolName.isEmpty || !typeName.isEmpty {
                conformances.append(
                    SwiftConformance(
                        typeAddress: UInt64(entryOffset),
                        typeName: typeName,
                        protocolName: protocolName
                    ))
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
            for section in segment.sections {
                if section.sectionName.hasPrefix("__swift5_") {
                    return true
                }
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
