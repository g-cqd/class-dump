// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

/// Protocol conformance parsing extensions for SwiftMetadataProcessor.
///
/// This extension provides functions for parsing Swift protocol conformance
/// records from the `__swift5_proto` section.
extension SwiftMetadataProcessor {

    // MARK: - Conformance Parsing

    /// Parse all protocol conformances from the binary.
    ///
    /// Conformances are stored in the `__swift5_proto` section as an array
    /// of conformance descriptor records.
    ///
    /// - Returns: Array of parsed protocol conformances.
    func parseConformances() throws -> [SwiftConformance] {
        guard
            let section = findSection(segment: "__TEXT", section: "__swift5_proto")
                ?? findSection(segment: "__DATA_CONST", section: "__swift5_proto")
        else {
            return []
        }

        guard let sectionData = readSectionData(section) else { return [] }

        return parseConformancesFromSection(
            sectionData: sectionData,
            sectionOffset: Int(section.offset)
        )
    }

    /// Parse conformances from section data.
    ///
    /// - Parameters:
    ///   - sectionData: Raw bytes of the __swift5_proto section.
    ///   - sectionOffset: File offset where the section starts.
    /// - Returns: Array of parsed conformances.
    private func parseConformancesFromSection(
        sectionData: Data,
        sectionOffset: Int
    ) -> [SwiftConformance] {
        var conformances: [SwiftConformance] = []

        // Conformance records are 16 bytes each
        var offset = 0
        while offset + 16 <= sectionData.count {
            let entryOffset = sectionOffset + offset

            if let conformance = parseConformanceRecord(
                at: entryOffset,
                sectionData: sectionData,
                localOffset: offset
            ) {
                conformances.append(conformance)
            }

            offset += 16
        }

        return conformances
    }

    // MARK: - Conformance Record Parsing

    /// Parse a single conformance record.
    ///
    /// Conformance record layout:
    /// ```
    /// struct TargetProtocolConformanceDescriptor {
    ///   int32_t Protocol;            // +0: relative pointer to protocol descriptor
    ///   int32_t TypeRef;             // +4: type reference (kind depends on flags)
    ///   int32_t WitnessTablePattern; // +8: witness table pattern
    ///   uint32_t Flags;              // +12: conformance flags
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - entryOffset: File offset of the record.
    ///   - sectionData: Raw section data.
    ///   - localOffset: Offset within section data.
    /// - Returns: Parsed conformance or nil if invalid.
    private func parseConformanceRecord(
        at entryOffset: Int,
        sectionData: Data,
        localOffset: Int
    ) -> SwiftConformance? {
        // Read flags
        let rawFlags = sectionData.withUnsafeBytes { bytes in
            bytes.load(fromByteOffset: localOffset + 12, as: UInt32.self)
        }
        let flags = ConformanceFlags(rawValue: rawFlags)

        // Parse protocol reference
        let protocolInfo = parseProtocolReference(at: entryOffset)

        // Parse type reference
        let typeInfo = parseTypeReference(
            at: entryOffset + 4,
            flags: flags
        )

        // Only include if we have meaningful data
        guard !protocolInfo.name.isEmpty || !typeInfo.name.isEmpty else {
            return nil
        }

        return SwiftConformance(
            address: UInt64(entryOffset),
            typeAddress: typeInfo.address,
            typeName: typeInfo.name,
            mangledTypeName: typeInfo.mangledName,
            protocolName: protocolInfo.name,
            protocolAddress: protocolInfo.address,
            flags: flags
        )
    }

    /// Parse protocol reference from conformance record.
    ///
    /// - Parameter offset: File offset of the protocol pointer.
    /// - Returns: Tuple of (name, address).
    private func parseProtocolReference(at offset: Int) -> (name: String, address: UInt64) {
        guard let protoDescOffset = readRelativePointer(at: offset),
            protoDescOffset > 0
        else {
            return ("", 0)
        }

        let protocolAddress = UInt64(protoDescOffset)

        // Protocol name is at offset +8 in the protocol descriptor
        let protoNameOffset = Int(protoDescOffset) + 8
        let protocolName = readRelativeString(at: protoNameOffset) ?? ""

        return (protocolName, protocolAddress)
    }

    /// Parse type reference from conformance record.
    ///
    /// The type reference format depends on the typeReferenceKind in flags.
    ///
    /// - Parameters:
    ///   - offset: File offset of the type reference pointer.
    ///   - flags: Conformance flags.
    /// - Returns: Tuple of (name, mangled name, address).
    private func parseTypeReference(
        at offset: Int,
        flags: ConformanceFlags
    ) -> (name: String, mangledName: String, address: UInt64) {
        var typeName = ""
        var mangledTypeName = ""
        var typeAddress: UInt64 = 0

        switch flags.typeReferenceKind {
            case .directTypeDescriptor, .indirectTypeDescriptor:
                // For type descriptors, read the mangled name
                if let typeDescOffset = readRelativePointer(at: offset),
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
                if let typeRefValue = readRelativePointer(at: offset) {
                    typeAddress = UInt64(typeRefValue)
                    // Try to demangle if it's a Swift-exposed ObjC name
                    typeName = readRelativeString(at: offset) ?? ""
                }
        }

        // Fallback: try reading directly
        if typeName.isEmpty {
            typeName = readRelativeString(at: offset) ?? ""
        }

        return (typeName, mangledTypeName, typeAddress)
    }
}

// MARK: - Swift Conformance Analyzer

/// Pure functions for analyzing Swift protocol conformances.
///
/// These functions operate on immutable data and have no side effects.
public enum SwiftConformanceAnalyzer {

    /// Get all retroactive conformances.
    ///
    /// Retroactive conformances are defined outside the type's module.
    ///
    /// Pure filtering function.
    ///
    /// - Parameter conformances: Array of conformances.
    /// - Returns: Retroactive conformances.
    public static func retroactiveConformances(
        _ conformances: [SwiftConformance]
    ) -> [SwiftConformance] {
        conformances.filter(\.isRetroactive)
    }

    /// Get all conditional conformances.
    ///
    /// Conditional conformances have generic requirements.
    ///
    /// Pure filtering function.
    ///
    /// - Parameter conformances: Array of conformances.
    /// - Returns: Conditional conformances.
    public static func conditionalConformances(
        _ conformances: [SwiftConformance]
    ) -> [SwiftConformance] {
        conformances.filter(\.isConditional)
    }

    /// Group conformances by type name.
    ///
    /// Pure function for organizing conformances.
    ///
    /// - Parameter conformances: Array of conformances.
    /// - Returns: Dictionary mapping type names to conformances.
    public static func groupByType(
        _ conformances: [SwiftConformance]
    ) -> [String: [SwiftConformance]] {
        Dictionary(grouping: conformances, by: \.typeName)
    }

    /// Group conformances by protocol name.
    ///
    /// Pure function for organizing conformances.
    ///
    /// - Parameter conformances: Array of conformances.
    /// - Returns: Dictionary mapping protocol names to conformances.
    public static func groupByProtocol(
        _ conformances: [SwiftConformance]
    ) -> [String: [SwiftConformance]] {
        Dictionary(grouping: conformances, by: \.protocolName)
    }

    /// Get protocol names that a type conforms to.
    ///
    /// Pure function for extracting conformance information.
    ///
    /// - Parameters:
    ///   - typeName: Name of the type.
    ///   - conformances: Array of conformances.
    /// - Returns: Array of protocol names.
    public static func protocolNames(
        for typeName: String,
        in conformances: [SwiftConformance]
    ) -> [String] {
        conformances
            .filter { $0.typeName == typeName }
            .map(\.protocolName)
    }

    /// Get types that conform to a specific protocol.
    ///
    /// Pure function for extracting conformance information.
    ///
    /// - Parameters:
    ///   - protocolName: Name of the protocol.
    ///   - conformances: Array of conformances.
    /// - Returns: Array of type names.
    public static func typeNames(
        conformingTo protocolName: String,
        in conformances: [SwiftConformance]
    ) -> [String] {
        conformances
            .filter { $0.protocolName == protocolName }
            .map(\.typeName)
    }

    /// Check if a type conforms to a protocol.
    ///
    /// Pure predicate function.
    ///
    /// - Parameters:
    ///   - typeName: Name of the type.
    ///   - protocolName: Name of the protocol.
    ///   - conformances: Array of conformances.
    /// - Returns: True if conformance exists.
    public static func typeConforms(
        _ typeName: String,
        to protocolName: String,
        in conformances: [SwiftConformance]
    ) -> Bool {
        conformances.contains { conformance in
            conformance.typeName == typeName && conformance.protocolName == protocolName
        }
    }

    /// Count conformances by type reference kind.
    ///
    /// Pure function for analysis.
    ///
    /// - Parameter conformances: Array of conformances.
    /// - Returns: Dictionary mapping type reference kinds to counts.
    public static func countsByTypeReferenceKind(
        _ conformances: [SwiftConformance]
    ) -> [ConformanceTypeReferenceKind: Int] {
        Dictionary(grouping: conformances) { $0.flags.typeReferenceKind }
            .mapValues(\.count)
    }

    /// Get synthesized non-unique conformances.
    ///
    /// These are compiler-generated conformances that may not be unique.
    ///
    /// Pure filtering function.
    ///
    /// - Parameter conformances: Array of conformances.
    /// - Returns: Synthesized conformances.
    public static func synthesizedConformances(
        _ conformances: [SwiftConformance]
    ) -> [SwiftConformance] {
        conformances.filter { $0.flags.isSynthesizedNonUnique }
    }

    /// Build a conformance matrix.
    ///
    /// Creates a map showing which types conform to which protocols.
    ///
    /// Pure function for analysis.
    ///
    /// - Parameter conformances: Array of conformances.
    /// - Returns: Dictionary of type → set of protocols.
    public static func conformanceMatrix(
        _ conformances: [SwiftConformance]
    ) -> [String: Set<String>] {
        var matrix: [String: Set<String>] = [:]

        for conformance in conformances where !conformance.typeName.isEmpty {
            matrix[conformance.typeName, default: []].insert(conformance.protocolName)
        }

        return matrix
    }

    /// Find types that conform to multiple protocols from a set.
    ///
    /// Useful for finding types that satisfy composite protocol requirements.
    ///
    /// Pure function for analysis.
    ///
    /// - Parameters:
    ///   - protocolNames: Set of protocol names to match.
    ///   - conformances: Array of conformances.
    /// - Returns: Types that conform to all specified protocols.
    public static func typesConformingToAll(
        _ protocolNames: Set<String>,
        in conformances: [SwiftConformance]
    ) -> [String] {
        let matrix = conformanceMatrix(conformances)

        return matrix.compactMap { typeName, protocols in
            protocolNames.isSubset(of: protocols) ? typeName : nil
        }
    }
}
