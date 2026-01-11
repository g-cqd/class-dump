// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

/// Field descriptor parsing extensions for SwiftMetadataProcessor.
///
/// This extension provides functions for parsing Swift field descriptors from
/// the `__swift5_fieldmd` section. Field descriptors contain information about
/// struct/class/enum fields including their names and types.
extension SwiftMetadataProcessor {

    // MARK: - Field Descriptor Parsing

    /// Parse all field descriptors from the binary.
    ///
    /// Field descriptors are stored in the `__swift5_fieldmd` section and contain
    /// information about the fields (properties, ivars) of Swift types.
    ///
    /// - Returns: Array of parsed field descriptors.
    func parseFieldDescriptors() throws -> [SwiftFieldDescriptor] {
        guard
            let section = findSection(segment: "__TEXT", section: "__swift5_fieldmd")
                ?? findSection(segment: "__DATA_CONST", section: "__swift5_fieldmd")
        else {
            return []
        }

        guard let sectionData = readSectionData(section) else { return [] }

        return parseFieldDescriptorsFromSection(
            sectionData: sectionData,
            sectionOffset: Int(section.offset)
        )
    }

    /// Parse field descriptors from section data.
    ///
    /// Pure parsing function that extracts field descriptors from raw section bytes.
    ///
    /// - Parameters:
    ///   - sectionData: Raw bytes of the __swift5_fieldmd section.
    ///   - sectionOffset: File offset where the section starts.
    /// - Returns: Array of parsed field descriptors.
    private func parseFieldDescriptorsFromSection(
        sectionData: Data,
        sectionOffset: Int
    ) -> [SwiftFieldDescriptor] {
        var descriptors: [SwiftFieldDescriptor] = []
        var offset = 0

        while offset + 16 <= sectionData.count {
            let descriptorOffset = sectionOffset + offset

            guard let descriptor = parseFieldDescriptor(at: descriptorOffset) else {
                // Skip to next potential descriptor
                offset += 16
                continue
            }

            descriptors.append(descriptor.descriptor)

            // Move to next descriptor (header + records)
            offset += 16 + descriptor.recordsSize
        }

        return descriptors
    }

    /// Parse a single field descriptor at the given file offset.
    ///
    /// Field descriptor layout:
    /// ```
    /// struct FieldDescriptor {
    ///   int32_t MangledTypeName;  // +0: relative pointer
    ///   int32_t Superclass;       // +4: relative pointer
    ///   uint16_t Kind;            // +8
    ///   uint16_t FieldRecordSize; // +10
    ///   uint32_t NumFields;       // +12
    ///   // FieldRecord records[NumFields] follow
    /// }
    /// ```
    ///
    /// - Parameter descriptorOffset: File offset of the descriptor.
    /// - Returns: Tuple of parsed descriptor and total records size, or nil if invalid.
    private func parseFieldDescriptor(
        at descriptorOffset: Int
    ) -> (descriptor: SwiftFieldDescriptor, recordsSize: Int)? {
        guard descriptorOffset + 16 <= data.count else { return nil }

        // Read header fields
        let header = FieldDescriptorHeader(
            mangledTypeNamePointerOffset: descriptorOffset,
            superclassOffset: descriptorOffset + 4,
            kindOffset: descriptorOffset + 8,
            fieldRecordSizeOffset: descriptorOffset + 10,
            numFieldsOffset: descriptorOffset + 12
        )

        // Read mangled type name (both string and raw data)
        let mangledTypeName = readRelativeString(at: header.mangledTypeNamePointerOffset) ?? ""
        let mangledTypeNameData = readRelativeData(at: header.mangledTypeNamePointerOffset) ?? Data()

        // Calculate the actual offset where the type name data starts
        let mangledTypeNameDataOffset: Int
        if let targetOffset = readRelativePointer(at: header.mangledTypeNamePointerOffset) {
            mangledTypeNameDataOffset = Int(targetOffset)
        }
        else {
            mangledTypeNameDataOffset = 0
        }

        let superclassMangledName = readRelativeString(at: header.superclassOffset)

        let kindRaw = readUInt16(at: header.kindOffset)
        let fieldRecordSize = Int(readUInt16(at: header.fieldRecordSizeOffset))
        let numFields = Int(readUInt32(at: header.numFieldsOffset))

        // Parse field records
        let recordsStart = descriptorOffset + 16
        let records = parseFieldRecords(
            startOffset: recordsStart,
            count: numFields,
            recordSize: fieldRecordSize
        )

        let kind = SwiftFieldDescriptorKind(rawValue: kindRaw) ?? .struct

        let descriptor = SwiftFieldDescriptor(
            address: UInt64(descriptorOffset),
            kind: kind,
            mangledTypeName: mangledTypeName,
            mangledTypeNameData: mangledTypeNameData,
            mangledTypeNameOffset: mangledTypeNameDataOffset,
            superclassMangledName: superclassMangledName,
            records: records
        )

        return (descriptor, numFields * fieldRecordSize)
    }

    /// Parse field records for a field descriptor.
    ///
    /// Field record layout:
    /// ```
    /// struct FieldRecord {
    ///   uint32_t Flags;           // +0
    ///   int32_t MangledTypeName;  // +4: relative pointer
    ///   int32_t FieldName;        // +8: relative pointer
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - startOffset: File offset where records begin.
    ///   - count: Number of records to parse.
    ///   - recordSize: Size of each record in bytes.
    /// - Returns: Array of parsed field records.
    private func parseFieldRecords(
        startOffset: Int,
        count: Int,
        recordSize: Int
    ) -> [SwiftFieldRecord] {
        (0..<count)
            .compactMap { index in
                parseFieldRecord(
                    at: startOffset + index * recordSize,
                    recordSize: recordSize
                )
            }
    }

    /// Parse a single field record.
    ///
    /// - Parameters:
    ///   - offset: File offset of the record.
    ///   - recordSize: Size of the record in bytes.
    /// - Returns: Parsed field record or nil if invalid.
    private func parseFieldRecord(
        at offset: Int,
        recordSize: Int
    ) -> SwiftFieldRecord? {
        guard offset + 12 <= data.count else { return nil }

        let flags = readUInt32(at: offset)

        // Calculate the actual offset where the type name data starts
        let typeNamePointerOffset = offset + 4
        let typeNameDataOffset: Int
        if let targetOffset = readRelativePointer(at: typeNamePointerOffset) {
            typeNameDataOffset = Int(targetOffset)
        }
        else {
            typeNameDataOffset = 0
        }

        // Read both string representation and raw bytes
        let fieldTypeName = readRelativeString(at: offset + 4) ?? ""
        let fieldTypeData = readRelativeData(at: offset + 4) ?? Data()
        let fieldName = readRelativeString(at: offset + 8) ?? ""

        return SwiftFieldRecord(
            flags: flags,
            name: fieldName,
            mangledTypeName: fieldTypeName,
            mangledTypeData: fieldTypeData,
            mangledTypeNameOffset: typeNameDataOffset
        )
    }
}

// MARK: - Helper Types

/// Offsets for field descriptor header fields.
private struct FieldDescriptorHeader {
    let mangledTypeNamePointerOffset: Int
    let superclassOffset: Int
    let kindOffset: Int
    let fieldRecordSizeOffset: Int
    let numFieldsOffset: Int
}

// MARK: - Field Descriptor Analyzer

/// Pure functions for analyzing Swift field descriptors.
///
/// These functions operate on immutable data and have no side effects,
/// making them thread-safe and easily testable.
public enum SwiftFieldDescriptorAnalyzer {

    /// Get all field names from a field descriptor.
    ///
    /// Pure function that extracts field names.
    ///
    /// - Parameter descriptor: The field descriptor to analyze.
    /// - Returns: Array of field names.
    public static func fieldNames(in descriptor: SwiftFieldDescriptor) -> [String] {
        descriptor.records.map(\.name)
    }

    /// Check if a field descriptor has any fields with symbolic type references.
    ///
    /// Symbolic references are used for types that can't be represented as
    /// simple mangled names (e.g., generic types with specific arguments).
    ///
    /// Pure predicate function.
    ///
    /// - Parameter descriptor: The field descriptor to check.
    /// - Returns: True if any field has symbolic type data.
    public static func hasSymbolicTypeReferences(_ descriptor: SwiftFieldDescriptor) -> Bool {
        descriptor.records.contains { record in
            guard let firstByte = record.mangledTypeData.first else { return false }
            return SwiftSymbolicReferenceKind.isSymbolicMarker(firstByte)
        }
    }

    /// Get fields that are likely optional types.
    ///
    /// Checks for Optional mangling pattern in type names.
    ///
    /// Pure function for filtering optional fields.
    ///
    /// - Parameter descriptor: The field descriptor to analyze.
    /// - Returns: Array of field records with optional types.
    public static func optionalFields(in descriptor: SwiftFieldDescriptor) -> [SwiftFieldRecord] {
        descriptor.records.filter { record in
            record.mangledTypeName.contains("Sg")  // Swift generic Optional suffix
        }
    }

    /// Count fields by their flag patterns.
    ///
    /// Pure function for field analysis.
    ///
    /// - Parameter descriptor: The field descriptor to analyze.
    /// - Returns: Dictionary mapping flag values to counts.
    public static func fieldCountsByFlags(_ descriptor: SwiftFieldDescriptor) -> [UInt32: Int] {
        Dictionary(grouping: descriptor.records, by: \.flags)
            .mapValues(\.count)
    }

    /// Check if this is a class field descriptor (has superclass).
    ///
    /// Pure predicate function.
    ///
    /// - Parameter descriptor: The field descriptor to check.
    /// - Returns: True if the descriptor has a superclass reference.
    public static func hasSupeclass(_ descriptor: SwiftFieldDescriptor) -> Bool {
        descriptor.superclassMangledName != nil
    }

    /// Group field descriptors by their kind.
    ///
    /// Pure function for organizing descriptors.
    ///
    /// - Parameter descriptors: Array of field descriptors.
    /// - Returns: Dictionary mapping kinds to descriptors.
    public static func groupByKind(
        _ descriptors: [SwiftFieldDescriptor]
    ) -> [SwiftFieldDescriptorKind: [SwiftFieldDescriptor]] {
        Dictionary(grouping: descriptors, by: \.kind)
    }

    /// Find field descriptors with empty field lists.
    ///
    /// These may represent marker types or types with only static members.
    ///
    /// Pure function for filtering.
    ///
    /// - Parameter descriptors: Array of field descriptors.
    /// - Returns: Descriptors with no fields.
    public static func emptyDescriptors(
        _ descriptors: [SwiftFieldDescriptor]
    ) -> [SwiftFieldDescriptor] {
        descriptors.filter { $0.records.isEmpty }
    }
}
