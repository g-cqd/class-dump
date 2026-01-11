// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

/// Type and extension descriptor parsing extensions for SwiftMetadataProcessor.
///
/// This extension provides functions for parsing Swift type context descriptors
/// (classes, structs, enums) and extension descriptors from the `__swift5_types`
/// section.
extension SwiftMetadataProcessor {

    // MARK: - Type and Extension Parsing

    /// Parse all types and extensions from the binary.
    ///
    /// The `__swift5_types` section contains relative offsets pointing to both
    /// type context descriptors and extension context descriptors.
    ///
    /// - Returns: Tuple of parsed types and extensions.
    func parseTypesAndExtensions() throws -> ([SwiftType], [SwiftExtension]) {
        guard
            let section = findSection(segment: "__TEXT", section: "__swift5_types")
                ?? findSection(segment: "__DATA_CONST", section: "__swift5_types")
        else {
            return ([], [])
        }

        guard let sectionData = readSectionData(section) else { return ([], []) }

        return parseTypesAndExtensionsFromSection(
            sectionData: sectionData,
            sectionOffset: Int(section.offset)
        )
    }

    /// Parse types and extensions from section data.
    ///
    /// - Parameters:
    ///   - sectionData: Raw bytes of the __swift5_types section.
    ///   - sectionOffset: File offset where the section starts.
    /// - Returns: Tuple of parsed types and extensions.
    private func parseTypesAndExtensionsFromSection(
        sectionData: Data,
        sectionOffset: Int
    ) -> ([SwiftType], [SwiftExtension]) {
        var types: [SwiftType] = []
        var extensions: [SwiftExtension] = []

        // __swift5_types contains an array of 32-bit relative offsets
        var offset = 0
        while offset + 4 <= sectionData.count {
            let entryOffset = sectionOffset + offset

            // Read relative offset to descriptor
            guard let descriptorOffset = readRelativePointer(at: entryOffset) else {
                offset += 4
                continue
            }

            let fileOffset = Int(descriptorOffset)
            guard fileOffset + 8 <= data.count else {
                offset += 4
                continue
            }

            // Check the kind to determine if it's a type or extension
            let rawFlags = readUInt32(at: fileOffset)
            let kindRaw = UInt8(rawFlags & 0x1F)

            if kindRaw == SwiftContextDescriptorKind.extension.rawValue {
                // Parse as extension
                if let ext = parseExtensionDescriptor(at: fileOffset) {
                    extensions.append(ext)
                }
            }
            else if let kind = SwiftContextDescriptorKind(rawValue: kindRaw), kind.isType {
                // Parse as type
                if let type = parseTypeDescriptor(at: fileOffset) {
                    types.append(type)
                }
            }

            offset += 4
        }

        return (types, extensions)
    }

    // MARK: - Type Descriptor Parsing

    /// Parse a type context descriptor at the given file offset.
    ///
    /// Type descriptor layout:
    /// ```
    /// struct TargetTypeContextDescriptor {
    ///   uint32_t Flags;            // +0
    ///   int32_t Parent;            // +4 (relative pointer)
    ///   int32_t Name;              // +8 (relative pointer)
    ///   int32_t AccessFunction;    // +12 (relative pointer)
    ///   int32_t Fields;            // +16 (relative pointer to FieldDescriptor)
    /// }
    ///
    /// // For classes:
    /// struct TargetClassDescriptor : TargetTypeContextDescriptor {
    ///   int32_t Superclass;        // +20
    ///   uint32_t MetadataNegSize;  // +24
    ///   uint32_t MetadataPosSize;  // +28
    ///   uint32_t NumImmediateMembers; // +32
    ///   uint32_t NumFields;        // +36
    ///   uint32_t FieldOffsetVectorOffset; // +40
    ///   // GenericContextDescriptorHeader at +44 if generic
    /// }
    /// ```
    ///
    /// - Parameter fileOffset: File offset of the descriptor.
    /// - Returns: Parsed SwiftType or nil if invalid.
    func parseTypeDescriptor(at fileOffset: Int) -> SwiftType? {
        guard fileOffset + 20 <= data.count else { return nil }

        let rawFlags = readUInt32(at: fileOffset)
        let typeFlags = TypeContextDescriptorFlags(rawValue: rawFlags)
        let kindRaw = UInt8(rawFlags & 0x1F)

        guard let kind = SwiftContextDescriptorKind(rawValue: kindRaw), kind.isType else {
            return nil
        }

        let isGeneric = typeFlags.isGeneric

        // Read name
        let name = readRelativeString(at: fileOffset + 8) ?? ""

        // Read parent and determine parent kind
        let (parentName, parentKind) = parseParentDescriptor(at: fileOffset + 4)

        // Parse type-specific fields
        let typeSpecificData = parseTypeSpecificFields(
            at: fileOffset,
            kind: kind,
            flags: typeFlags,
            isGeneric: isGeneric
        )

        return SwiftType(
            address: UInt64(fileOffset),
            kind: kind,
            name: name,
            mangledName: "",
            parentName: parentName,
            parentKind: parentKind,
            superclassName: typeSpecificData.superclassName,
            fields: [],
            genericParameters: typeSpecificData.genericParameters,
            genericParamCount: typeSpecificData.genericParamCount,
            genericRequirements: typeSpecificData.genericRequirements,
            flags: typeFlags,
            objcClassAddress: nil
        )
    }

    /// Parse parent descriptor to extract name and kind.
    ///
    /// - Parameter offset: File offset of the parent pointer.
    /// - Returns: Tuple of parent name and kind.
    private func parseParentDescriptor(at offset: Int) -> (String?, SwiftContextDescriptorKind?) {
        guard let parentDescOffset = readRelativePointer(at: offset),
            parentDescOffset > 0,
            Int(parentDescOffset) + 8 < data.count
        else {
            return (nil, nil)
        }

        // Read parent's flags to determine its kind
        let parentFlags = readUInt32(at: Int(parentDescOffset))
        let parentKindRaw = UInt8(parentFlags & 0x1F)
        let parentKind = SwiftContextDescriptorKind(rawValue: parentKindRaw)

        // Read parent's name (at +8 in the parent descriptor)
        let parentNameOffset = Int(parentDescOffset) + 8
        let parentName = readRelativeString(at: parentNameOffset)

        return (parentName, parentKind)
    }

    /// Parse type-specific fields (superclass, generics) based on kind.
    ///
    /// - Parameters:
    ///   - fileOffset: File offset of the type descriptor.
    ///   - kind: The type's context descriptor kind.
    ///   - flags: Type context descriptor flags.
    ///   - isGeneric: Whether the type is generic.
    /// - Returns: Type-specific data structure.
    private func parseTypeSpecificFields(
        at fileOffset: Int,
        kind: SwiftContextDescriptorKind,
        flags: TypeContextDescriptorFlags,
        isGeneric: Bool
    ) -> TypeSpecificData {
        var superclassName: String?
        var genericParamCount = 0
        var genericParameters: [String] = []
        var genericRequirements: [SwiftGenericRequirement] = []

        if kind == .class {
            // Read superclass (at +20 for classes)
            if fileOffset + 24 <= data.count {
                superclassName = readRelativeString(at: fileOffset + 20)
                // Demangle superclass name if it's mangled
                if let sc = superclassName, sc.hasPrefix("_Tt") || sc.hasPrefix("$s") {
                    superclassName = SwiftDemangler.demangleSwiftName(sc)
                }
            }

            // Determine generic header offset based on class layout
            let genericHeaderOffset: Int
            if flags.hasResilientSuperclass {
                genericHeaderOffset = fileOffset + 48
            }
            else {
                genericHeaderOffset = fileOffset + 44
            }

            if isGeneric {
                let parsed = parseGenericHeader(
                    at: genericHeaderOffset,
                    isGeneric: isGeneric
                )
                genericParamCount = parsed.paramCount
                genericParameters = parsed.parameters
                genericRequirements = parsed.requirements
            }
        }
        else if kind == .struct || kind == .enum {
            // GenericContextDescriptorHeader is at +20 for non-class types
            let genericHeaderOffset = fileOffset + 20

            if isGeneric {
                let parsed = parseGenericHeader(
                    at: genericHeaderOffset,
                    isGeneric: isGeneric
                )
                genericParamCount = parsed.paramCount
                genericParameters = parsed.parameters
                genericRequirements = parsed.requirements
            }
        }

        return TypeSpecificData(
            superclassName: superclassName,
            genericParamCount: genericParamCount,
            genericParameters: genericParameters,
            genericRequirements: genericRequirements
        )
    }

    /// Parse generic context header.
    ///
    /// Generic header layout:
    /// ```
    /// struct GenericContextDescriptorHeader {
    ///   uint16_t NumParams;
    ///   uint16_t NumRequirements;
    ///   uint16_t NumKeyArguments;
    ///   uint16_t NumExtraArguments;
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - offset: File offset of the generic header.
    ///   - isGeneric: Whether the type is marked as generic.
    /// - Returns: Parsed generic data.
    private func parseGenericHeader(
        at offset: Int,
        isGeneric: Bool
    ) -> (paramCount: Int, parameters: [String], requirements: [SwiftGenericRequirement]) {
        guard offset + 8 <= data.count else {
            return isGeneric ? (1, ["T"], []) : (0, [], [])
        }

        let rawParamCount = Int(readUInt16(at: offset))
        let numRequirements = Int(readUInt16(at: offset + 2))

        // Sanity check: param count should be reasonable (1-16)
        guard rawParamCount > 0 && rawParamCount <= 16 else {
            return isGeneric ? (1, ["T"], []) : (0, [], [])
        }

        let parameters = SwiftGenericParameterGenerator.generateNames(count: rawParamCount)
        var requirements: [SwiftGenericRequirement] = []

        // Parse generic requirements if present
        if numRequirements > 0 && numRequirements <= 32 {
            let requirementsOffset = offset + 8
            requirements = parseGenericRequirements(
                at: requirementsOffset,
                count: numRequirements,
                paramNames: parameters
            )
        }

        return (rawParamCount, parameters, requirements)
    }

    // MARK: - Extension Descriptor Parsing

    /// Parse an extension context descriptor at the given file offset.
    ///
    /// Extension descriptor layout:
    /// ```
    /// struct TargetExtensionContextDescriptor {
    ///   uint32_t Flags;              // +0
    ///   int32_t Parent;              // +4 (relative pointer to module/context)
    ///   int32_t ExtendedContext;     // +8 (relative pointer to extended type name)
    /// }
    /// // GenericContextDescriptorHeader follows at +12 if generic
    /// ```
    ///
    /// - Parameter fileOffset: File offset of the descriptor.
    /// - Returns: Parsed SwiftExtension or nil if invalid.
    func parseExtensionDescriptor(at fileOffset: Int) -> SwiftExtension? {
        guard fileOffset + 12 <= data.count else { return nil }

        let rawFlags = readUInt32(at: fileOffset)
        let typeFlags = TypeContextDescriptorFlags(rawValue: rawFlags)
        let isGeneric = typeFlags.isGeneric

        // Read parent (module name)
        let moduleName = parseExtensionModuleName(at: fileOffset + 4)

        // Read extended type name
        let (extendedTypeName, mangledExtendedTypeName) = parseExtendedTypeName(at: fileOffset + 8)

        // Parse generic parameters if present
        var genericParamCount = 0
        var genericParameters: [String] = []
        var genericRequirements: [SwiftGenericRequirement] = []

        if isGeneric {
            let genericHeaderOffset = fileOffset + 12

            if genericHeaderOffset + 8 <= data.count {
                let rawParamCount = Int(readUInt16(at: genericHeaderOffset))
                let numRequirements = Int(readUInt16(at: genericHeaderOffset + 2))

                // Sanity check
                if rawParamCount > 0 && rawParamCount <= 16 {
                    genericParamCount = rawParamCount
                    genericParameters = SwiftGenericParameterGenerator.generateNames(
                        count: genericParamCount
                    )

                    // Parse requirements if present
                    if numRequirements > 0 && numRequirements <= 32 {
                        let requirementsOffset = genericHeaderOffset + 8
                        genericRequirements = parseGenericRequirements(
                            at: requirementsOffset,
                            count: numRequirements,
                            paramNames: genericParameters
                        )
                    }
                }
            }
        }

        guard !extendedTypeName.isEmpty else { return nil }

        return SwiftExtension(
            address: UInt64(fileOffset),
            extendedTypeName: extendedTypeName,
            mangledExtendedTypeName: mangledExtendedTypeName,
            moduleName: moduleName,
            addedConformances: [],
            genericParameters: genericParameters,
            genericParamCount: genericParamCount,
            genericRequirements: genericRequirements,
            flags: typeFlags
        )
    }

    /// Parse module name from extension parent pointer.
    ///
    /// - Parameter offset: File offset of the parent pointer.
    /// - Returns: Module name or nil.
    private func parseExtensionModuleName(at offset: Int) -> String? {
        guard let parentDescOffset = readRelativePointer(at: offset),
            parentDescOffset > 0,
            Int(parentDescOffset) + 8 < data.count
        else {
            return nil
        }

        // Parent is typically a module descriptor, which has name at offset +8
        return readRelativeString(at: Int(parentDescOffset) + 8)
    }

    /// Parse extended type name from extension descriptor.
    ///
    /// - Parameter offset: File offset of the extended context pointer.
    /// - Returns: Tuple of demangled name and mangled name.
    private func parseExtendedTypeName(at offset: Int) -> (String, String) {
        guard readRelativePointer(at: offset) != nil else {
            return ("", "")
        }

        // Try to read as mangled type name string
        if let mangled = readRelativeString(at: offset) {
            let demangled = SwiftDemangler.demangleSwiftName(mangled)
            if !demangled.isEmpty && demangled != mangled {
                return (demangled, mangled)
            }

            // Fall back to simple cleaning if demangling fails
            let cleaned =
                mangled
                .replacingOccurrences(of: "$s", with: "")
                .replacingOccurrences(of: "_Tt", with: "")
            return (cleaned, mangled)
        }

        // Try to read as direct type descriptor reference
        if let extendedTypeOffset = readRelativePointer(at: offset) {
            let typeDescOffset = Int(extendedTypeOffset)
            if typeDescOffset + 12 < data.count {
                let descFlags = readUInt32(at: typeDescOffset)
                let descKind = UInt8(descFlags & 0x1F)
                if let kind = SwiftContextDescriptorKind(rawValue: descKind), kind.isType {
                    if let name = readRelativeString(at: typeDescOffset + 8) {
                        return (name, "")
                    }
                }
            }
        }

        return ("", "")
    }

    // MARK: - Generic Requirements Parsing

    /// Parse generic requirements from a requirements array.
    ///
    /// Requirement layout:
    /// ```
    /// struct GenericRequirementDescriptor {
    ///   uint32_t Flags;           // +0: bits 0-3 = kind, bits 4-7 = extra info
    ///   int32_t Param;            // +4: relative pointer to param mangled name
    ///   int32_t Type/Protocol;    // +8: relative pointer to type/protocol
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - offset: File offset of the requirements array.
    ///   - count: Number of requirements.
    ///   - paramNames: Available parameter names for fallback.
    /// - Returns: Array of parsed requirements.
    func parseGenericRequirements(
        at offset: Int,
        count: Int,
        paramNames: [String]
    ) -> [SwiftGenericRequirement] {
        var requirements: [SwiftGenericRequirement] = []
        var currentOffset = offset

        for _ in 0..<count {
            guard currentOffset + 12 <= data.count else { break }

            if let requirement = parseGenericRequirement(
                at: currentOffset,
                paramNames: paramNames
            ) {
                requirements.append(requirement)
            }

            currentOffset += 12
        }

        return requirements
    }

    /// Parse a single generic requirement.
    ///
    /// - Parameters:
    ///   - offset: File offset of the requirement.
    ///   - paramNames: Available parameter names for fallback.
    /// - Returns: Parsed requirement or nil.
    private func parseGenericRequirement(
        at offset: Int,
        paramNames: [String]
    ) -> SwiftGenericRequirement? {
        let flags = readUInt32(at: offset)
        let kindRaw = UInt8(flags & 0x0F)

        guard let kind = GenericRequirementKind(rawValue: kindRaw) else {
            return nil
        }

        // Read parameter name
        var paramName = ""
        if readRelativePointer(at: offset + 4) != nil {
            if let name = readRelativeString(at: offset + 4) {
                paramName = SwiftDemangler.demangle(name)
            }
        }

        // Fallback to index-based name
        if paramName.isEmpty {
            let paramIndex = Int((flags >> 16) & 0xFF)
            if paramIndex < paramNames.count {
                paramName = paramNames[paramIndex]
            }
            else {
                paramName = "T\(paramIndex)"
            }
        }

        // Read constraint
        var constraint = ""
        if let constraintName = readRelativeString(at: offset + 8) {
            constraint = SwiftDemangler.demangle(constraintName)
        }

        // Handle layout constraints
        if kind == .layout && constraint.isEmpty {
            constraint = "AnyObject"
        }

        return SwiftGenericRequirement(
            kind: kind,
            param: paramName,
            constraint: constraint,
            flags: flags
        )
    }
}

// MARK: - Helper Types

/// Type-specific data parsed from descriptors.
private struct TypeSpecificData {
    let superclassName: String?
    let genericParamCount: Int
    let genericParameters: [String]
    let genericRequirements: [SwiftGenericRequirement]
}

// MARK: - Generic Parameter Generator

/// Pure functions for generating generic parameter names.
public enum SwiftGenericParameterGenerator {

    /// Generate generic parameter names for a given count.
    ///
    /// Uses conventional Swift naming: T, U, V, W for small counts,
    /// T0, T1, T2... for larger counts.
    ///
    /// Pure function for name generation.
    ///
    /// - Parameter count: Number of parameters needed.
    /// - Returns: Array of parameter names.
    public static func generateNames(count: Int) -> [String] {
        switch count {
            case 1:
                return ["T"]
            case 2...4:
                return Array(["T", "U", "V", "W"].prefix(count))
            default:
                return (0..<count).map { "T\($0)" }
        }
    }
}

// MARK: - Swift Type Analyzer

/// Pure functions for analyzing Swift types.
///
/// These functions operate on immutable data and have no side effects.
public enum SwiftTypeAnalyzer {

    /// Get all generic types from a collection.
    ///
    /// Pure filtering function.
    ///
    /// - Parameter types: Array of Swift types.
    /// - Returns: Types that are generic.
    public static func genericTypes(_ types: [SwiftType]) -> [SwiftType] {
        types.filter(\.isGeneric)
    }

    /// Get all types with constraints (where clauses).
    ///
    /// Pure filtering function.
    ///
    /// - Parameter types: Array of Swift types.
    /// - Returns: Types that have generic constraints.
    public static func typesWithConstraints(_ types: [SwiftType]) -> [SwiftType] {
        types.filter(\.hasGenericConstraints)
    }

    /// Group types by their kind.
    ///
    /// Pure function for organizing types.
    ///
    /// - Parameter types: Array of Swift types.
    /// - Returns: Dictionary mapping kinds to types.
    public static func groupByKind(
        _ types: [SwiftType]
    ) -> [SwiftContextDescriptorKind: [SwiftType]] {
        Dictionary(grouping: types, by: \.kind)
    }

    /// Get nested types (types inside other types, not modules).
    ///
    /// Pure filtering function.
    ///
    /// - Parameter types: Array of Swift types.
    /// - Returns: Types that are nested.
    public static func nestedTypes(_ types: [SwiftType]) -> [SwiftType] {
        types.filter(\.isNestedType)
    }

    /// Find types by parent name.
    ///
    /// Pure filtering function.
    ///
    /// - Parameters:
    ///   - types: Array of Swift types.
    ///   - parentName: Name of the parent to filter by.
    /// - Returns: Types with the specified parent.
    public static func typesByParent(
        _ types: [SwiftType],
        parentName: String
    ) -> [SwiftType] {
        types.filter { $0.parentName == parentName }
    }

    /// Get inheritance depth statistics.
    ///
    /// Pure function for analyzing class hierarchies.
    ///
    /// - Parameter types: Array of Swift types.
    /// - Returns: Tuple of (min depth, max depth, average depth) for classes with superclasses.
    public static func inheritanceStats(_ types: [SwiftType]) -> (min: Int, max: Int, avg: Double) {
        let classesWithSuper = types.filter { $0.kind == .class && $0.superclassName != nil }

        guard !classesWithSuper.isEmpty else {
            return (0, 0, 0.0)
        }

        // All classes with superclasses have at least depth 1
        let depths = classesWithSuper.map { _ in 1 }
        let sum = depths.reduce(0, +)

        return (
            min: depths.min() ?? 0,
            max: depths.max() ?? 0,
            avg: Double(sum) / Double(depths.count)
        )
    }
}

// MARK: - Swift Extension Analyzer

/// Pure functions for analyzing Swift extensions.
public enum SwiftExtensionAnalyzer {

    /// Get extensions that add protocol conformances.
    ///
    /// Pure filtering function.
    ///
    /// - Parameter extensions: Array of Swift extensions.
    /// - Returns: Extensions with added conformances.
    public static func extensionsWithConformances(_ extensions: [SwiftExtension]) -> [SwiftExtension] {
        extensions.filter(\.addsConformances)
    }

    /// Get generic extensions.
    ///
    /// Pure filtering function.
    ///
    /// - Parameter extensions: Array of Swift extensions.
    /// - Returns: Extensions that are generic.
    public static func genericExtensions(_ extensions: [SwiftExtension]) -> [SwiftExtension] {
        extensions.filter(\.isGeneric)
    }

    /// Group extensions by extended type name.
    ///
    /// Pure function for organizing extensions.
    ///
    /// - Parameter extensions: Array of Swift extensions.
    /// - Returns: Dictionary mapping type names to extensions.
    public static func groupByType(_ extensions: [SwiftExtension]) -> [String: [SwiftExtension]] {
        Dictionary(grouping: extensions, by: \.extendedTypeName)
    }

    /// Group extensions by module.
    ///
    /// Pure function for organizing extensions.
    ///
    /// - Parameter extensions: Array of Swift extensions.
    /// - Returns: Dictionary mapping module names to extensions.
    public static func groupByModule(_ extensions: [SwiftExtension]) -> [String: [SwiftExtension]] {
        Dictionary(grouping: extensions) { ext in
            ext.moduleName ?? "Unknown"
        }
    }
}
