// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

/// Protocol descriptor parsing extensions for SwiftMetadataProcessor.
///
/// This extension provides functions for parsing Swift protocol descriptors
/// from the `__swift5_protos` section.
extension SwiftMetadataProcessor {

    // MARK: - Protocol Parsing

    /// Parse all protocol descriptors from the binary.
    ///
    /// Protocols are stored in the `__swift5_protos` section as an array
    /// of relative offsets pointing to protocol descriptors.
    ///
    /// - Returns: Array of parsed Swift protocols.
    func parseProtocols() throws -> [SwiftProtocol] {
        guard
            let section = findSection(segment: "__TEXT", section: "__swift5_protos")
                ?? findSection(segment: "__DATA_CONST", section: "__swift5_protos")
        else {
            return []
        }

        guard let sectionData = readSectionData(section) else { return [] }

        return parseProtocolsFromSection(
            sectionData: sectionData,
            sectionOffset: Int(section.offset)
        )
    }

    /// Parse protocols from section data.
    ///
    /// - Parameters:
    ///   - sectionData: Raw bytes of the __swift5_protos section.
    ///   - sectionOffset: File offset where the section starts.
    /// - Returns: Array of parsed protocols.
    private func parseProtocolsFromSection(
        sectionData: Data,
        sectionOffset: Int
    ) -> [SwiftProtocol] {
        var protocols: [SwiftProtocol] = []

        var offset = 0
        while offset + 4 <= sectionData.count {
            let entryOffset = sectionOffset + offset

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

    // MARK: - Protocol Descriptor Parsing

    /// Parse a protocol descriptor at the given file offset.
    ///
    /// Protocol descriptor layout:
    /// ```
    /// struct TargetProtocolDescriptor {
    ///   uint32_t Flags;                    // +0
    ///   int32_t Parent;                    // +4 relative pointer to module/context
    ///   int32_t Name;                      // +8 relative pointer to name string
    ///   int32_t NumRequirementsInSignature; // +12 (generic requirements count)
    ///   int32_t NumRequirements;           // +16 (witness table requirements)
    ///   int32_t Requirements;              // +20 relative pointer to requirements array
    ///   int32_t AssociatedTypeNames;       // +24 relative pointer to space-separated names
    /// }
    /// ```
    ///
    /// - Parameter fileOffset: File offset of the descriptor.
    /// - Returns: Parsed SwiftProtocol or nil if invalid.
    private func parseProtocolDescriptor(at fileOffset: Int) -> SwiftProtocol? {
        guard fileOffset + 28 <= data.count else { return nil }

        // Read protocol name
        let name = readRelativeString(at: fileOffset + 8) ?? ""

        // Read parent module name
        let parentName = parseProtocolParentName(at: fileOffset + 4)

        // Read associated type names
        let associatedTypeNames = parseAssociatedTypeNames(at: fileOffset)

        // Determine requirements layout and parse
        let (requirements, inheritedProtocols) = parseProtocolRequirements(
            at: fileOffset,
            associatedTypeNames: associatedTypeNames
        )

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

    /// Parse protocol parent name from descriptor.
    ///
    /// - Parameter offset: File offset of the parent pointer.
    /// - Returns: Parent name or nil.
    private func parseProtocolParentName(at offset: Int) -> String? {
        guard let parentDescOffset = readRelativePointer(at: offset),
            parentDescOffset > 0,
            Int(parentDescOffset) + 8 < data.count
        else {
            return nil
        }

        // Parent is typically a module descriptor, which has name at offset +8
        return readRelativeString(at: Int(parentDescOffset) + 8)
    }

    /// Parse associated type names from protocol descriptor.
    ///
    /// Associated type names are stored as a space-separated string.
    ///
    /// - Parameter fileOffset: Base offset of protocol descriptor.
    /// - Returns: Array of associated type names.
    private func parseAssociatedTypeNames(at fileOffset: Int) -> [String] {
        // Try offset +24 first (standard), then +12 (older format)
        var namesString = readRelativeString(at: fileOffset + 24) ?? ""
        if namesString.isEmpty {
            namesString = readRelativeString(at: fileOffset + 12) ?? ""
        }

        guard !namesString.isEmpty else { return [] }

        return
            namesString
            .split(separator: " ")
            .map(String.init)
    }

    /// Parse protocol requirements from descriptor.
    ///
    /// - Parameters:
    ///   - fileOffset: Base offset of protocol descriptor.
    ///   - associatedTypeNames: Associated type names for consumption.
    /// - Returns: Tuple of (requirements, inherited protocol names).
    private func parseProtocolRequirements(
        at fileOffset: Int,
        associatedTypeNames: [String]
    ) -> ([SwiftProtocolRequirement], [String]) {
        // Read number of requirements
        var numRequirements = Int(readUInt32(at: fileOffset + 16))
        var requirementsPointerOffset = fileOffset + 20

        // Validate: if numRequirements seems too large, try alternate layout
        if numRequirements > 1000 {
            numRequirements = Int(readUInt32(at: fileOffset + 20))
            requirementsPointerOffset = fileOffset + 24
        }

        guard numRequirements > 0,
            let requirementsStart = readRelativePointer(at: requirementsPointerOffset)
        else {
            return ([], [])
        }

        return parseRequirementsList(
            at: Int(requirementsStart),
            count: numRequirements,
            associatedTypeNames: associatedTypeNames
        )
    }

    /// Parse a list of protocol requirements.
    ///
    /// Requirement layout:
    /// ```
    /// struct ProtocolRequirement {
    ///   uint32_t Flags;              // +0: low 4 bits = kind, bit 4 = isInstance, bit 5 = isAsync
    ///   int32_t DefaultImpl;         // +4: relative pointer to default impl (0 if none)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - offset: File offset of requirements array.
    ///   - count: Number of requirements.
    ///   - associatedTypeNames: Associated type names for consumption.
    /// - Returns: Tuple of (requirements, inherited protocol names).
    private func parseRequirementsList(
        at offset: Int,
        count: Int,
        associatedTypeNames: [String]
    ) -> ([SwiftProtocolRequirement], [String]) {
        var requirements: [SwiftProtocolRequirement] = []
        var inheritedProtocols: [String] = []
        var remainingAssociatedTypes = associatedTypeNames
        var currentOffset = offset

        requirements.reserveCapacity(max(0, count))

        for _ in 0..<count {
            guard currentOffset + 8 <= data.count else { break }

            if let parsed = parseProtocolRequirement(
                at: currentOffset,
                remainingAssociatedTypes: &remainingAssociatedTypes
            ) {
                requirements.append(parsed.requirement)
                if let inheritedProtocol = parsed.inheritedProtocol {
                    inheritedProtocols.append(inheritedProtocol)
                }
            }

            currentOffset += 8
        }

        return (requirements, inheritedProtocols)
    }

    /// Parse a single protocol requirement.
    ///
    /// - Parameters:
    ///   - offset: File offset of the requirement.
    ///   - remainingAssociatedTypes: Mutable array of associated types to consume.
    /// - Returns: Parsed requirement and inherited protocol (if base protocol requirement).
    private func parseProtocolRequirement(
        at offset: Int,
        remainingAssociatedTypes: inout [String]
    ) -> (requirement: SwiftProtocolRequirement, inheritedProtocol: String?)? {
        let flags = readUInt32(at: offset)
        let kindValue = UInt8(flags & 0x0F)
        let isInstance = (flags & 0x10) != 0
        let isAsync = (flags & 0x20) != 0

        guard let kind = SwiftProtocolRequirement.Kind(rawValue: kindValue) else {
            return nil
        }

        // Check for default implementation
        var hasDefaultImpl = false
        if let defaultImplOffset = readRelativePointer(at: offset + 4),
            defaultImplOffset != 0
        {
            hasDefaultImpl = true
        }

        var requirementName = ""
        var inheritedProtocol: String?

        switch kind {
            case .baseProtocol:
                // The DefaultImpl pointer actually points to the protocol descriptor
                if let protoDescOffset = readRelativePointer(at: offset + 4),
                    protoDescOffset > 0,
                    Int(protoDescOffset) + 12 < data.count,
                    let protoName = readRelativeString(at: Int(protoDescOffset) + 8),
                    !protoName.isEmpty
                {
                    requirementName = protoName
                    inheritedProtocol = protoName
                }
                // Don't count this as having a "default impl" since it's actually a protocol reference
                hasDefaultImpl = false

            case .associatedTypeAccessFunction:
                // Consume the next associated type name
                if !remainingAssociatedTypes.isEmpty {
                    requirementName = remainingAssociatedTypes.removeFirst()
                }

            case .associatedConformanceAccessFunction,
                .method, .initializer,
                .getter, .setter,
                .readCoroutine, .modifyCoroutine:
                // These don't have explicit names in the descriptor
                break
        }

        let requirement = SwiftProtocolRequirement(
            kind: kind,
            name: requirementName,
            isInstance: isInstance,
            isAsync: isAsync,
            hasDefaultImplementation: hasDefaultImpl
        )

        return (requirement, inheritedProtocol)
    }
}

// MARK: - Swift Protocol Analyzer

/// Pure functions for analyzing Swift protocols.
///
/// These functions operate on immutable data and have no side effects.
public enum SwiftProtocolAnalyzer {

    /// Get protocols with associated types.
    ///
    /// Pure filtering function.
    ///
    /// - Parameter protocols: Array of Swift protocols.
    /// - Returns: Protocols that have associated types.
    public static func protocolsWithAssociatedTypes(
        _ protocols: [SwiftProtocol]
    ) -> [SwiftProtocol] {
        protocols.filter { !$0.associatedTypeNames.isEmpty }
    }

    /// Get protocols with inherited protocols.
    ///
    /// Pure filtering function.
    ///
    /// - Parameter protocols: Array of Swift protocols.
    /// - Returns: Protocols that inherit from other protocols.
    public static func protocolsWithInheritance(
        _ protocols: [SwiftProtocol]
    ) -> [SwiftProtocol] {
        protocols.filter { !$0.inheritedProtocols.isEmpty }
    }

    /// Get all associated type names across protocols.
    ///
    /// Pure function for extracting associated types.
    ///
    /// - Parameter protocols: Array of Swift protocols.
    /// - Returns: Set of all associated type names.
    public static func allAssociatedTypeNames(
        _ protocols: [SwiftProtocol]
    ) -> Set<String> {
        Set(protocols.flatMap(\.associatedTypeNames))
    }

    /// Build protocol inheritance graph.
    ///
    /// Pure function that creates a map of protocol → inherited protocols.
    ///
    /// - Parameter protocols: Array of Swift protocols.
    /// - Returns: Dictionary mapping protocol names to their inherited protocols.
    public static func inheritanceGraph(
        _ protocols: [SwiftProtocol]
    ) -> [String: [String]] {
        Dictionary(
            protocols.map { ($0.name, $0.inheritedProtocols) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    /// Count requirements by kind across protocols.
    ///
    /// Pure function for protocol analysis.
    ///
    /// - Parameter protocols: Array of Swift protocols.
    /// - Returns: Dictionary mapping requirement kinds to counts.
    public static func requirementCountsByKind(
        _ protocols: [SwiftProtocol]
    ) -> [SwiftProtocolRequirement.Kind: Int] {
        let allRequirements = protocols.flatMap(\.requirements)

        return Dictionary(grouping: allRequirements, by: \.kind)
            .mapValues(\.count)
    }

    /// Get protocols with default implementations.
    ///
    /// Pure filtering function.
    ///
    /// - Parameter protocols: Array of Swift protocols.
    /// - Returns: Protocols that have at least one default implementation.
    public static func protocolsWithDefaults(_ protocols: [SwiftProtocol]) -> [SwiftProtocol] {
        protocols.filter { proto in
            proto.requirements.contains { $0.hasDefaultImplementation }
        }
    }

    /// Group protocols by module.
    ///
    /// Pure function for organizing protocols.
    ///
    /// - Parameter protocols: Array of Swift protocols.
    /// - Returns: Dictionary mapping module names to protocols.
    public static func groupByModule(_ protocols: [SwiftProtocol]) -> [String: [SwiftProtocol]] {
        Dictionary(grouping: protocols) { proto in
            proto.parentName ?? "Unknown"
        }
    }

    /// Calculate protocol complexity score.
    ///
    /// Complexity is based on:
    /// - Number of required methods
    /// - Number of associated types
    /// - Number of inherited protocols
    ///
    /// Pure function for analysis.
    ///
    /// - Parameter proto: The protocol to analyze.
    /// - Returns: Complexity score.
    public static func complexityScore(_ proto: SwiftProtocol) -> Int {
        proto.requirements.count
            + proto.associatedTypeNames.count * 2
            + proto.inheritedProtocols.count
    }
}
