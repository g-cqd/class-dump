// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

// MARK: - Swift Metadata Types

/// Represents Swift metadata extracted from a Mach-O binary.
public struct SwiftMetadata: Sendable {
    /// Swift types (classes, structs, enums) found in the binary.
    public let types: [SwiftType]

    /// Swift protocols found in the binary.
    public let protocols: [SwiftProtocol]

    /// Protocol conformances.
    public let conformances: [SwiftConformance]

    /// Field descriptors (for resolving ivar types).
    public let fieldDescriptors: [SwiftFieldDescriptor]

    /// Swift extensions found in the binary.
    public let extensions: [SwiftExtension]

    /// Lookup table for types by simple name.
    private let typesByName: [String: SwiftType]

    /// Lookup table for types by full name (Module.TypeName).
    private let typesByFullName: [String: SwiftType]

    /// Lookup table for types by descriptor address.
    private let typesByAddress: [UInt64: SwiftType]

    /// Lookup table for conformances by type name.
    private let conformancesByTypeName: [String: [SwiftConformance]]

    /// Lookup table for conformances by protocol name.
    private let conformancesByProtocolName: [String: [SwiftConformance]]

    /// Lookup table for extensions by extended type name.
    private let extensionsByTypeName: [String: [SwiftExtension]]

    /// Initialize metadata results.
    public init(
        types: [SwiftType] = [],
        protocols: [SwiftProtocol] = [],
        conformances: [SwiftConformance] = [],
        fieldDescriptors: [SwiftFieldDescriptor] = [],
        extensions: [SwiftExtension] = []
    ) {
        self.types = types
        self.protocols = protocols
        self.conformances = conformances
        self.fieldDescriptors = fieldDescriptors
        self.extensions = extensions

        // Build type lookup tables
        var byName: [String: SwiftType] = [:]
        var byFullName: [String: SwiftType] = [:]
        var byAddress: [UInt64: SwiftType] = [:]
        for type in types {
            byName[type.name] = type
            byFullName[type.fullName] = type
            byAddress[type.address] = type
        }
        self.typesByName = byName
        self.typesByFullName = byFullName
        self.typesByAddress = byAddress

        // Build conformance lookup tables
        var confByType: [String: [SwiftConformance]] = [:]
        var confByProtocol: [String: [SwiftConformance]] = [:]
        for conformance in conformances {
            let typeName = conformance.typeName
            if !typeName.isEmpty {
                confByType[typeName, default: []].append(conformance)
            }
            let protoName = conformance.protocolName
            if !protoName.isEmpty {
                confByProtocol[protoName, default: []].append(conformance)
            }
        }
        self.conformancesByTypeName = confByType
        self.conformancesByProtocolName = confByProtocol

        // Build extension lookup table
        var extByType: [String: [SwiftExtension]] = [:]
        for ext in extensions {
            let typeName = ext.extendedTypeName
            if !typeName.isEmpty {
                extByType[typeName, default: []].append(ext)
            }
        }
        self.extensionsByTypeName = extByType
    }

    /// Look up a Swift type by simple name.
    public func type(named name: String) -> SwiftType? {
        typesByName[name]
    }

    /// Look up a Swift type by full name (Module.TypeName).
    public func type(fullName: String) -> SwiftType? {
        typesByFullName[fullName]
    }

    /// Look up a Swift type by ObjC mangled name (e.g., _TtC10ModuleName9ClassName).
    public func type(mangledObjCName: String) -> SwiftType? {
        // Extract the simple name from the mangled ObjC name
        if mangledObjCName.hasPrefix("_TtC") || mangledObjCName.hasPrefix("_TtGC") {
            if let (module, name) = SwiftDemangler.demangleClassName(mangledObjCName) {
                // Try full name first
                if let type = typesByFullName["\(module).\(name)"] {
                    return type
                }
                // Fall back to simple name
                return typesByName[name]
            }
        }
        return nil
    }

    /// Look up a Swift type by descriptor address.
    public func type(atAddress address: UInt64) -> SwiftType? {
        typesByAddress[address]
    }

    /// Get all generic types.
    public var genericTypes: [SwiftType] {
        types.filter { $0.isGeneric }
    }

    /// Get all classes.
    public var classes: [SwiftType] {
        types.filter { $0.kind == .class }
    }

    /// Get all structs.
    public var structs: [SwiftType] {
        types.filter { $0.kind == .struct }
    }

    /// Get all enums.
    public var enums: [SwiftType] {
        types.filter { $0.kind == .enum }
    }

    /// Get all nested types (types inside other types, not modules).
    public var nestedTypes: [SwiftType] {
        types.filter(\.isNestedType)
    }

    /// Get all types with generic constraints (where clauses).
    public var typesWithConstraints: [SwiftType] {
        types.filter(\.hasGenericConstraints)
    }

    // MARK: - Conformance Lookup

    /// Get all conformances for a given type name.
    public func conformances(forType typeName: String) -> [SwiftConformance] {
        conformancesByTypeName[typeName] ?? []
    }

    /// Get all conformances for a given protocol name.
    public func conformances(forProtocol protocolName: String) -> [SwiftConformance] {
        conformancesByProtocolName[protocolName] ?? []
    }

    /// Get the protocol names that a type conforms to.
    public func protocolNames(forType typeName: String) -> [String] {
        conformances(forType: typeName).map(\.protocolName)
    }

    /// Check if a type conforms to a specific protocol.
    public func typeConforms(_ typeName: String, to protocolName: String) -> Bool {
        conformances(forType: typeName).contains { $0.protocolName == protocolName }
    }

    /// Get all retroactive conformances (conformances defined outside the type's module).
    public var retroactiveConformances: [SwiftConformance] {
        conformances.filter(\.isRetroactive)
    }

    /// Get all conditional conformances.
    public var conditionalConformances: [SwiftConformance] {
        conformances.filter(\.isConditional)
    }

    // MARK: - Extension Lookup

    /// Get all extensions for a given type name.
    public func extensions(forType typeName: String) -> [SwiftExtension] {
        extensionsByTypeName[typeName] ?? []
    }

    /// Get all extensions that add protocol conformances.
    public var extensionsWithConformances: [SwiftExtension] {
        extensions.filter(\.addsConformances)
    }

    /// Get all generic extensions (with where clauses).
    public var genericExtensions: [SwiftExtension] {
        extensions.filter(\.isGeneric)
    }

    /// Get all extensions with generic constraints.
    public var extensionsWithConstraints: [SwiftExtension] {
        extensions.filter(\.hasGenericConstraints)
    }
}

// MARK: - Swift Type Kinds

/// The kind of Swift context descriptor.
public enum SwiftContextDescriptorKind: UInt8, Sendable {
    case module = 0
    case `extension` = 1
    case anonymous = 2
    case `protocol` = 3
    case opaqueType = 4
    // Types start at 16
    case `class` = 16
    case `struct` = 17
    case `enum` = 18

    /// Check if this kind represents a type (class, struct, or enum).
    public var isType: Bool {
        rawValue >= 16 && rawValue <= 31
    }
}

// MARK: - Type Context Descriptor Flags

/// Flags parsed from a type context descriptor.
public struct TypeContextDescriptorFlags: Sendable, Equatable {
    /// The raw integer value of the flags.
    public let rawValue: UInt32

    /// Initialize flags from a raw value.
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    /// The kind of context descriptor (bits 0-4).
    public var kind: SwiftContextDescriptorKind? {
        SwiftContextDescriptorKind(rawValue: UInt8(rawValue & 0x1F))
    }

    /// Whether this type is generic (bit 7).
    public var isGeneric: Bool {
        (rawValue & 0x80) != 0
    }

    /// Whether the descriptor should be uniqued (bit 6).
    public var isUnique: Bool {
        (rawValue & 0x40) != 0
    }

    /// Version of the descriptor (bits 8-15 for non-class types).
    public var version: UInt8 {
        UInt8((rawValue >> 8) & 0xFF)
    }

    // MARK: - Class-Specific Flags (bits 8-15)

    /// Whether the class has a virtual table (bit 15).
    public var hasVTable: Bool {
        (rawValue & 0x8000) != 0
    }

    /// Whether the class has an override table (bit 14).
    public var hasOverrideTable: Bool {
        (rawValue & 0x4000) != 0
    }

    /// Whether the class has a resilient superclass (bit 13).
    public var hasResilientSuperclass: Bool {
        (rawValue & 0x2000) != 0
    }

    /// Whether the class has a static vtable (bit 12).
    public var hasStaticVTable: Bool {
        (rawValue & 0x1000) != 0
    }

    /// Metadata initialization kind (bits 8-9). 0 = none, 1 = singleton, 2 = foreign.
    public var metadataInitializationKind: Int {
        Int((rawValue >> 8) & 0x3)
    }

    /// Whether this class requires singleton metadata initialization.
    public var hasSingletonMetadataInitialization: Bool {
        metadataInitializationKind == 1
    }

    /// Whether this class has foreign metadata initialization.
    public var hasForeignMetadataInitialization: Bool {
        metadataInitializationKind == 2
    }
}

/// Kind of generic requirement.
public enum GenericRequirementKind: UInt8, Sendable {
    /// A protocol conformance requirement (T: Protocol).
    case `protocol` = 0
    /// A same-type requirement (T == U or T == SomeType).
    case sameType = 1
    /// A base class requirement (T: BaseClass).
    case baseClass = 2
    /// A same-conformance requirement.
    case sameConformance = 3
    /// A layout requirement (T: AnyObject, T: class).
    case layout = 4
}

/// A generic requirement (constraint) for a type.
public struct SwiftGenericRequirement: Sendable {
    /// The kind of requirement.
    public let kind: GenericRequirementKind

    /// The parameter being constrained (e.g., "T", "Element").
    public let param: String

    /// The constraint type or protocol name (e.g., "Equatable", "Int").
    public let constraint: String

    /// Raw flags from the requirement descriptor.
    public let flags: UInt32

    /// Initialize a generic requirement.
    public init(kind: GenericRequirementKind, param: String, constraint: String, flags: UInt32 = 0) {
        self.kind = kind
        self.param = param
        self.constraint = constraint
        self.flags = flags
    }

    /// Whether this requirement has a key argument.
    public var hasKeyArgument: Bool {
        (flags & 0x80) != 0
    }

    /// Whether this requirement has an extra argument.
    public var hasExtraArgument: Bool {
        (flags & 0x40) != 0
    }

    /// Format as a Swift-style constraint string.
    public var description: String {
        switch kind {
            case .protocol:
                return "\(param): \(constraint)"
            case .sameType:
                return "\(param) == \(constraint)"
            case .baseClass:
                return "\(param): \(constraint)"
            case .sameConformance:
                return "\(param): \(constraint)"
            case .layout:
                if constraint == "AnyObject" || constraint == "class" {
                    return "\(param): AnyObject"
                }
                return "\(param): \(constraint)"
        }
    }
}

/// A Swift type (class, struct, or enum).
public struct SwiftType: Sendable {
    /// File offset of the type descriptor.
    public let address: UInt64

    /// Kind of type (class, struct, enum).
    public let kind: SwiftContextDescriptorKind

    /// Simple name of the type.
    public let name: String

    /// Mangled name (if available).
    public let mangledName: String

    /// Parent type/module name.
    public let parentName: String?

    /// Parent context kind (module, extension, class, struct, etc.).
    public let parentKind: SwiftContextDescriptorKind?

    /// Superclass name (for classes only).
    public let superclassName: String?

    /// Fields/properties of the type.
    public let fields: [SwiftField]

    /// Generic type parameter names (e.g., ["T", "U"] for `Foo<T, U>`).
    public let genericParameters: [String]

    /// Number of generic parameters (from descriptor header).
    public let genericParamCount: Int

    /// Generic requirements (where clauses).
    public let genericRequirements: [SwiftGenericRequirement]

    /// Type context descriptor flags.
    public let flags: TypeContextDescriptorFlags

    /// Whether this type is generic.
    public var isGeneric: Bool { genericParamCount > 0 }

    /// ObjC class metadata address (for Swift classes exposed to ObjC).
    ///
    /// This allows linking Swift type descriptors to ObjC class metadata.
    public let objcClassAddress: UInt64?

    /// Initialize a Swift type.
    public init(
        address: UInt64,
        kind: SwiftContextDescriptorKind,
        name: String,
        mangledName: String = "",
        parentName: String? = nil,
        parentKind: SwiftContextDescriptorKind? = nil,
        superclassName: String? = nil,
        fields: [SwiftField] = [],
        genericParameters: [String] = [],
        genericParamCount: Int = 0,
        genericRequirements: [SwiftGenericRequirement] = [],
        flags: TypeContextDescriptorFlags = TypeContextDescriptorFlags(rawValue: 0),
        objcClassAddress: UInt64? = nil
    ) {
        self.address = address
        self.kind = kind
        self.name = name
        self.mangledName = mangledName
        self.parentName = parentName
        self.parentKind = parentKind
        self.superclassName = superclassName
        self.fields = fields
        self.genericParameters = genericParameters
        self.genericParamCount = genericParamCount
        self.genericRequirements = genericRequirements
        self.flags = flags
        self.objcClassAddress = objcClassAddress
    }

    /// Full qualified name including parent.
    public var fullName: String {
        if let parent = parentName, !parent.isEmpty {
            return "\(parent).\(name)"
        }
        return name
    }

    /// Full name with generic parameters (e.g., "Module.Container<T>").
    public var fullNameWithGenerics: String {
        let base = fullName
        if genericParamCount > 0 {
            if genericParameters.isEmpty {
                // Use placeholder names if we don't have actual names
                let params = (0..<genericParamCount).map { "T\($0)" }
                return "\(base)<\(params.joined(separator: ", "))>"
            }
            return "\(base)<\(genericParameters.joined(separator: ", "))>"
        }
        return base
    }

    /// Whether this is a nested type (inside another type, not just a module).
    public var isNestedType: Bool {
        guard let parentKind else { return false }
        return parentKind.isType
    }

    /// Whether this type has generic constraints (where clauses).
    public var hasGenericConstraints: Bool {
        !genericRequirements.isEmpty
    }

    /// Format generic constraints as a where clause string.
    public var whereClause: String {
        guard !genericRequirements.isEmpty else { return "" }
        return "where " + genericRequirements.map(\.description).joined(separator: ", ")
    }

    /// Whether the type is unique (descriptor should be uniqued).
    public var isUnique: Bool {
        flags.isUnique
    }

    /// Whether the class has a virtual table (classes only).
    public var hasVTable: Bool {
        kind == .class && flags.hasVTable
    }

    /// Whether the class has a resilient superclass (classes only).
    public var hasResilientSuperclass: Bool {
        kind == .class && flags.hasResilientSuperclass
    }
}

/// A Swift field (property or enum case).
public struct SwiftField: Sendable {
    /// The field name.
    public let name: String

    /// The mangled type name.
    public let mangledTypeName: String

    /// The human-readable type name.
    public let typeName: String

    /// Whether this is a variable (vs let).
    public let isVar: Bool

    /// Whether this is an indirect field (enum case).
    public let isIndirect: Bool

    /// Initialize a Swift field.
    public init(
        name: String,
        mangledTypeName: String = "",
        typeName: String = "",
        isVar: Bool = false,
        isIndirect: Bool = false
    ) {
        self.name = name
        self.mangledTypeName = mangledTypeName
        self.typeName = typeName
        self.isVar = isVar
        self.isIndirect = isIndirect
    }

    // MARK: - Property Wrapper Detection

    /// Detect if this field uses a property wrapper.
    ///
    /// Returns the detected wrapper info if the field's type matches a known wrapper pattern.
    public var propertyWrapper: SwiftPropertyWrapperInfo? {
        guard !typeName.isEmpty else { return nil }

        // Check for known property wrapper patterns
        if let wrapper = SwiftPropertyWrapper.detect(from: typeName) {
            let wrappedType = extractWrappedType(from: typeName)
            return SwiftPropertyWrapperInfo(
                wrapper: wrapper,
                wrapperTypeName: typeName,
                wrappedValueType: wrappedType
            )
        }

        return nil
    }

    /// Whether this field uses a property wrapper.
    public var hasPropertyWrapper: Bool {
        propertyWrapper != nil
    }

    /// Extract the wrapped type from a wrapper type name like "State<Int>" -> "Int".
    private func extractWrappedType(from wrapperTypeName: String) -> String? {
        // Look for generic parameter: WrapperName<WrappedType>
        guard let startIndex = wrapperTypeName.firstIndex(of: "<"),
            let endIndex = wrapperTypeName.lastIndex(of: ">")
        else {
            return nil
        }

        let afterStart = wrapperTypeName.index(after: startIndex)
        guard afterStart < endIndex else { return nil }

        return String(wrapperTypeName[afterStart..<endIndex])
    }
}

/// A Swift protocol.
public struct SwiftProtocol: Sendable {
    /// Address of the protocol descriptor.
    public let address: UInt64

    /// Protocol name.
    public let name: String

    /// Mangled protocol name.
    public let mangledName: String

    /// Parent module or namespace name.
    public let parentName: String?

    /// Associated type names declared by this protocol.
    public let associatedTypeNames: [String]

    /// Protocols that this protocol inherits from.
    public let inheritedProtocols: [String]

    /// All requirements of this protocol.
    public let requirements: [SwiftProtocolRequirement]

    /// Initialize a Swift protocol.
    public init(
        address: UInt64,
        name: String,
        mangledName: String = "",
        parentName: String? = nil,
        associatedTypeNames: [String] = [],
        inheritedProtocols: [String] = [],
        requirements: [SwiftProtocolRequirement] = []
    ) {
        self.address = address
        self.name = name
        self.mangledName = mangledName
        self.parentName = parentName
        self.associatedTypeNames = associatedTypeNames
        self.inheritedProtocols = inheritedProtocols
        self.requirements = requirements
    }

    /// Full qualified name including parent module.
    public var fullName: String {
        if let parent = parentName, !parent.isEmpty {
            return "\(parent).\(name)"
        }
        return name
    }

    /// Number of method requirements.
    public var methodCount: Int {
        requirements.filter { $0.kind == .method }.count
    }

    /// Number of property requirements (getters + setters).
    public var propertyCount: Int {
        requirements.filter { $0.kind == .getter }.count
    }

    /// Number of initializer requirements.
    public var initializerCount: Int {
        requirements.filter { $0.kind == .initializer }.count
    }
}

/// A Swift protocol requirement.
public struct SwiftProtocolRequirement: Sendable {
    /// Kind of requirement.
    public enum Kind: UInt8, Sendable {
        case baseProtocol = 0
        case method = 1
        case initializer = 2
        case getter = 3
        case setter = 4
        case readCoroutine = 5
        case modifyCoroutine = 6
        case associatedTypeAccessFunction = 7
        case associatedConformanceAccessFunction = 8

        /// Human-readable description of this requirement kind.
        public var description: String {
            switch self {
                case .baseProtocol: return "base protocol"
                case .method: return "method"
                case .initializer: return "initializer"
                case .getter: return "getter"
                case .setter: return "setter"
                case .readCoroutine: return "read coroutine"
                case .modifyCoroutine: return "modify coroutine"
                case .associatedTypeAccessFunction: return "associated type"
                case .associatedConformanceAccessFunction: return "associated conformance"
            }
        }
    }

    /// The kind of requirement.
    public let kind: Kind

    /// The requirement name.
    public let name: String

    /// Whether this is an instance requirement (vs static/class).
    public let isInstance: Bool

    /// Whether this is an async requirement.
    public let isAsync: Bool

    /// Whether this requirement has a default implementation.
    public let hasDefaultImplementation: Bool

    /// Initialize a protocol requirement.
    public init(
        kind: Kind,
        name: String,
        isInstance: Bool = true,
        isAsync: Bool = false,
        hasDefaultImplementation: Bool = false
    ) {
        self.kind = kind
        self.name = name
        self.isInstance = isInstance
        self.isAsync = isAsync
        self.hasDefaultImplementation = hasDefaultImplementation
    }
}

/// The kind of type reference in a conformance descriptor.
public enum ConformanceTypeReferenceKind: UInt8, Sendable {
    /// Direct reference to a type descriptor.
    case directTypeDescriptor = 0
    /// Indirect reference through a type descriptor pointer.
    case indirectTypeDescriptor = 1
    /// Direct reference to an ObjC class.
    case directObjCClass = 2
    /// Indirect reference to an ObjC class.
    case indirectObjCClass = 3
}

/// Flags describing a protocol conformance.
public struct ConformanceFlags: Sendable, Equatable {
    /// The raw integer value of the flags.
    public let rawValue: UInt32

    /// Initialize flags from a raw value.
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    /// The kind of type reference.
    public var typeReferenceKind: ConformanceTypeReferenceKind {
        ConformanceTypeReferenceKind(rawValue: UInt8(rawValue & 0x7)) ?? .directTypeDescriptor
    }

    /// Whether this is a retroactive conformance.
    public var isRetroactive: Bool {
        (rawValue & 0x8) != 0
    }

    /// Whether this conformance applies to a synthesized type.
    public var isSynthesizedNonUnique: Bool {
        (rawValue & 0x10) != 0
    }

    /// Number of conditional requirements.
    public var numConditionalRequirements: Int {
        Int((rawValue >> 8) & 0xFF)
    }

    /// Whether this has a resilient witness count.
    public var hasResilientWitnesses: Bool {
        (rawValue & 0x20) != 0
    }

    /// Whether this has a generic witness table.
    public var hasGenericWitnessTable: Bool {
        (rawValue & 0x40) != 0
    }
}

/// A Swift protocol conformance.
public struct SwiftConformance: Sendable {
    /// Address of the conformance descriptor.
    public let address: UInt64

    /// Address of the conforming type descriptor (if available).
    public let typeAddress: UInt64

    /// Name of the conforming type.
    public let typeName: String

    /// Mangled name of the conforming type (if available).
    public let mangledTypeName: String

    /// Name of the protocol being conformed to.
    public let protocolName: String

    /// Address of the protocol descriptor.
    public let protocolAddress: UInt64

    /// Conformance flags.
    public let flags: ConformanceFlags

    /// Whether this is a retroactive conformance (defined in a different module than the type).
    public var isRetroactive: Bool {
        flags.isRetroactive
    }

    /// Whether this conformance has conditional requirements (e.g., `where T: Equatable`).
    public var isConditional: Bool {
        flags.numConditionalRequirements > 0
    }

    /// Number of conditional requirements.
    public var conditionalRequirementCount: Int {
        flags.numConditionalRequirements
    }

    /// Initialize a Swift conformance.
    public init(
        address: UInt64 = 0,
        typeAddress: UInt64,
        typeName: String,
        mangledTypeName: String = "",
        protocolName: String,
        protocolAddress: UInt64 = 0,
        flags: ConformanceFlags = ConformanceFlags(rawValue: 0)
    ) {
        self.address = address
        self.typeAddress = typeAddress
        self.typeName = typeName
        self.mangledTypeName = mangledTypeName
        self.protocolName = protocolName
        self.protocolAddress = protocolAddress
        self.flags = flags
    }

    /// Full description of this conformance.
    public var description: String {
        var result = "\(typeName): \(protocolName)"
        if isRetroactive {
            result += " (retroactive)"
        }
        if isConditional {
            result += " (conditional)"
        }
        return result
    }
}

// MARK: - Field Descriptor

/// Kind of field descriptor.
public enum SwiftFieldDescriptorKind: UInt16, Sendable {
    case `struct` = 0
    case `class` = 1
    case `enum` = 2
    case multiPayloadEnum = 3
    case `protocol` = 4
    case classProtocol = 5
    case objcProtocol = 6
    case objcClass = 7
}

/// A Swift field descriptor from __swift5_fieldmd section.
public struct SwiftFieldDescriptor: Sendable {
    /// Address of the field descriptor.
    public let address: UInt64

    /// Kind of descriptor.
    public let kind: SwiftFieldDescriptorKind

    /// Mangled type name.
    public let mangledTypeName: String

    /// Raw bytes of the mangled type name (for symbolic reference resolution).
    public let mangledTypeNameData: Data

    /// File offset where the mangled type name was read (for symbolic resolution).
    public let mangledTypeNameOffset: Int

    /// Mangled name of the superclass (if any).
    public let superclassMangledName: String?

    /// Field records.
    public let records: [SwiftFieldRecord]

    /// Check if the owning type uses a symbolic reference.
    public var hasSymbolicReference: Bool {
        guard !mangledTypeNameData.isEmpty else { return false }
        let firstByte = mangledTypeNameData[mangledTypeNameData.startIndex]
        return SwiftSymbolicReferenceKind.isSymbolicMarker(firstByte)
    }

    /// Initialize a field descriptor.
    public init(
        address: UInt64,
        kind: SwiftFieldDescriptorKind,
        mangledTypeName: String,
        mangledTypeNameData: Data = Data(),
        mangledTypeNameOffset: Int = 0,
        superclassMangledName: String? = nil,
        records: [SwiftFieldRecord] = []
    ) {
        self.address = address
        self.kind = kind
        self.mangledTypeName = mangledTypeName
        self.mangledTypeNameData = mangledTypeNameData
        self.mangledTypeNameOffset = mangledTypeNameOffset
        self.superclassMangledName = superclassMangledName
        self.records = records
    }
}

/// A field record within a field descriptor.
public struct SwiftFieldRecord: Sendable {
    /// Field flags.
    public let flags: UInt32

    /// Field name.
    public let name: String

    /// Mangled type name of the field.
    public let mangledTypeName: String

    /// Raw bytes of the mangled type name (for symbolic reference resolution).
    public let mangledTypeData: Data

    /// File offset where the mangled type name was read (for symbolic resolution).
    public let mangledTypeNameOffset: Int

    /// Whether this is a variable (vs let).
    public var isVar: Bool { (flags & 0x2) != 0 }

    /// Whether this is an indirect field (enum case).
    public var isIndirect: Bool { (flags & 0x1) != 0 }

    /// Check if the type uses a symbolic reference at the start.
    public var hasSymbolicReference: Bool {
        guard !mangledTypeData.isEmpty else { return false }
        let firstByte = mangledTypeData[mangledTypeData.startIndex]
        return SwiftSymbolicReferenceKind.isSymbolicMarker(firstByte)
    }

    /// Check if the type contains any embedded symbolic references.
    ///
    /// Swift mangled names can have symbolic refs embedded anywhere, not just at the start.
    public var hasEmbeddedSymbolicReference: Bool {
        guard mangledTypeData.count >= 6 else { return false }
        let bytes = Array(mangledTypeData)
        // Look for symbolic reference markers (0x01, 0x02) after the first byte
        // A symbolic ref is 5 bytes, so the marker can appear at most at count-4
        for i in 1..<bytes.count {
            let byte = bytes[i]
            if byte == 0x01 || byte == 0x02 {
                return true
            }
        }
        return false
    }

    /// Initialize a field record.
    public init(
        flags: UInt32,
        name: String,
        mangledTypeName: String,
        mangledTypeData: Data = Data(),
        mangledTypeNameOffset: Int = 0
    ) {
        self.flags = flags
        self.name = name
        self.mangledTypeName = mangledTypeName
        self.mangledTypeData = mangledTypeData
        self.mangledTypeNameOffset = mangledTypeNameOffset
    }
}

// MARK: - Swift Extensions

/// A Swift extension on a type.
///
/// Extensions in Swift can add protocol conformances, methods, and computed properties
/// to existing types. This structure captures extension metadata from `__swift5_types`.
public struct SwiftExtension: Sendable {
    /// File offset of the extension descriptor.
    public let address: UInt64

    /// The name of the extended type.
    public let extendedTypeName: String

    /// Mangled name of the extended type.
    public let mangledExtendedTypeName: String

    /// Module containing the extension.
    public let moduleName: String?

    /// Protocol conformances added by this extension.
    public let addedConformances: [String]

    /// Generic parameters (if extension is generic).
    public let genericParameters: [String]

    /// Number of generic parameters.
    public let genericParamCount: Int

    /// Generic requirements (where clauses).
    public let genericRequirements: [SwiftGenericRequirement]

    /// Type context descriptor flags.
    public let flags: TypeContextDescriptorFlags

    /// Whether this extension is generic.
    public var isGeneric: Bool { genericParamCount > 0 }

    /// Whether this extension adds protocol conformances.
    public var addsConformances: Bool { !addedConformances.isEmpty }

    /// Whether this extension has generic constraints (where clauses).
    public var hasGenericConstraints: Bool { !genericRequirements.isEmpty }

    /// Format generic constraints as a where clause string.
    public var whereClause: String {
        guard !genericRequirements.isEmpty else { return "" }
        return "where " + genericRequirements.map(\.description).joined(separator: ", ")
    }

    /// Initialize a Swift extension.
    public init(
        address: UInt64,
        extendedTypeName: String,
        mangledExtendedTypeName: String = "",
        moduleName: String? = nil,
        addedConformances: [String] = [],
        genericParameters: [String] = [],
        genericParamCount: Int = 0,
        genericRequirements: [SwiftGenericRequirement] = [],
        flags: TypeContextDescriptorFlags = TypeContextDescriptorFlags(rawValue: 0)
    ) {
        self.address = address
        self.extendedTypeName = extendedTypeName
        self.mangledExtendedTypeName = mangledExtendedTypeName
        self.moduleName = moduleName
        self.addedConformances = addedConformances
        self.genericParameters = genericParameters
        self.genericParamCount = genericParamCount
        self.genericRequirements = genericRequirements
        self.flags = flags
    }
}

// MARK: - Property Wrappers

/// Known Swift property wrapper types.
public enum SwiftPropertyWrapper: String, Sendable, CaseIterable {
    // SwiftUI wrappers
    case state = "State"
    case binding = "Binding"
    case observedObject = "ObservedObject"
    case stateObject = "StateObject"
    case environmentObject = "EnvironmentObject"
    case environment = "Environment"
    case focusState = "FocusState"
    case gestureState = "GestureState"
    case scaledMetric = "ScaledMetric"
    case appStorage = "AppStorage"
    case sceneStorage = "SceneStorage"
    case fetchRequest = "FetchRequest"
    case sectionedFetchRequest = "SectionedFetchRequest"
    case query = "Query"  // SwiftData
    case bindable = "Bindable"  // iOS 17+

    // Combine wrappers
    case published = "Published"

    // Custom or unknown wrapper
    case custom = "_custom"

    /// The projected value prefix ($ prefix) type, if any.
    public var projectedValueType: String? {
        switch self {
            case .state, .binding: return "Binding"
            case .observedObject: return "ObservedObject.Wrapper"
            case .stateObject: return "ObservedObject.Wrapper"
            case .environmentObject: return "EnvironmentObject.Wrapper"
            case .focusState: return "FocusState.Binding"
            case .gestureState: return "GestureState.Binding"
            case .published: return "Published.Publisher"
            case .environment, .scaledMetric, .appStorage, .sceneStorage,
                .fetchRequest, .sectionedFetchRequest, .query, .bindable, .custom:
                return nil
        }
    }

    /// Whether this wrapper requires a view context (SwiftUI wrappers).
    public var requiresViewContext: Bool {
        switch self {
            case .state, .binding, .observedObject, .stateObject, .environmentObject,
                .environment, .focusState, .gestureState, .scaledMetric,
                .appStorage, .sceneStorage, .fetchRequest, .sectionedFetchRequest,
                .query, .bindable:
                return true
            case .published, .custom:
                return false
        }
    }

    /// Detect property wrapper from a type name.
    public static func detect(from typeName: String) -> SwiftPropertyWrapper? {
        // Direct match by wrapper name
        for wrapper in SwiftPropertyWrapper.allCases {
            if wrapper == .custom { continue }
            if typeName == wrapper.rawValue || typeName.hasPrefix("\(wrapper.rawValue)<") {
                return wrapper
            }
            // Check for module-qualified names like SwiftUI.State
            if typeName.hasSuffix(".\(wrapper.rawValue)")
                || typeName.contains(".\(wrapper.rawValue)<")
            {
                return wrapper
            }
        }
        return nil
    }
}

/// Information about a property wrapper applied to a field.
public struct SwiftPropertyWrapperInfo: Sendable {
    /// The detected property wrapper.
    public let wrapper: SwiftPropertyWrapper

    /// The wrapper type name as it appears in the mangled type.
    public let wrapperTypeName: String

    /// The wrapped value type (inner type).
    public let wrappedValueType: String?

    /// Initialize property wrapper info.
    public init(
        wrapper: SwiftPropertyWrapper,
        wrapperTypeName: String,
        wrappedValueType: String? = nil
    ) {
        self.wrapper = wrapper
        self.wrapperTypeName = wrapperTypeName
        self.wrappedValueType = wrappedValueType
    }
}

// MARK: - Result Builders

/// Known Swift result builder types.
public enum SwiftResultBuilder: String, Sendable, CaseIterable {
    // SwiftUI builders
    case viewBuilder = "ViewBuilder"
    case sceneBuilder = "SceneBuilder"
    case commandsBuilder = "CommandsBuilder"
    case toolbarContentBuilder = "ToolbarContentBuilder"
    case tableColumnBuilder = "TableColumnBuilder"
    case tableRowBuilder = "TableRowBuilder"
    case accessibilityRotorContentBuilder = "AccessibilityRotorContentBuilder"

    // Other common builders
    case stringInterpolation = "StringInterpolation"
    case regexComponentBuilder = "RegexComponentBuilder"

    // Custom or unknown builder
    case custom = "_custom"

    /// Detect result builder from an attribute name.
    public static func detect(from attributeName: String) -> SwiftResultBuilder? {
        // Direct match by builder name
        for builder in SwiftResultBuilder.allCases {
            if builder == .custom { continue }
            if attributeName == builder.rawValue {
                return builder
            }
            // Check for module-qualified names like SwiftUI.ViewBuilder
            if attributeName.hasSuffix(".\(builder.rawValue)") {
                return builder
            }
        }
        return nil
    }
}

/// Information about a result builder attribute on a method or parameter.
public struct SwiftResultBuilderInfo: Sendable {
    /// The detected result builder.
    public let builder: SwiftResultBuilder

    /// The builder type name as it appears in the attribute.
    public let builderTypeName: String

    /// Initialize result builder info.
    public init(
        builder: SwiftResultBuilder,
        builderTypeName: String
    ) {
        self.builder = builder
        self.builderTypeName = builderTypeName
    }
}

// MARK: - Swift Type Detection Utilities

/// Utilities for detecting Swift-specific features from type names and mangled symbols.
public enum SwiftTypeDetection {
    /// Detect a property wrapper from a type name.
    ///
    /// - Parameter typeName: The type name (e.g., "State<Int>", "SwiftUI.Binding<String>").
    /// - Returns: Property wrapper info if detected, nil otherwise.
    public static func detectPropertyWrapper(from typeName: String) -> SwiftPropertyWrapperInfo? {
        guard let wrapper = SwiftPropertyWrapper.detect(from: typeName) else {
            return nil
        }
        let wrappedType = extractGenericParameter(from: typeName)
        return SwiftPropertyWrapperInfo(
            wrapper: wrapper,
            wrapperTypeName: typeName,
            wrappedValueType: wrappedType
        )
    }

    /// Detect a result builder from a type or attribute name.
    ///
    /// - Parameter attributeName: The attribute name (e.g., "ViewBuilder", "SwiftUI.SceneBuilder").
    /// - Returns: Result builder info if detected, nil otherwise.
    public static func detectResultBuilder(from attributeName: String) -> SwiftResultBuilderInfo? {
        guard let builder = SwiftResultBuilder.detect(from: attributeName) else {
            return nil
        }
        return SwiftResultBuilderInfo(builder: builder, builderTypeName: attributeName)
    }

    /// Check if a type name looks like a closure type with a result builder.
    ///
    /// Result builder closures often have patterns like `@ViewBuilder () -> some View`.
    ///
    /// - Parameter typeName: The full type signature.
    /// - Returns: Tuple of (builder info, closure type) if detected.
    public static func detectResultBuilderClosure(
        from typeName: String
    ) -> (builder: SwiftResultBuilderInfo, closureType: String)? {
        // Look for @Builder pattern followed by closure
        for builder in SwiftResultBuilder.allCases {
            if builder == .custom { continue }
            let pattern = "@\(builder.rawValue)"
            if typeName.contains(pattern) {
                // Extract the closure part after the builder
                if let range = typeName.range(of: pattern) {
                    let closurePart = typeName[range.upperBound...].trimmingCharacters(in: .whitespaces)
                    return (
                        SwiftResultBuilderInfo(builder: builder, builderTypeName: builder.rawValue),
                        closurePart
                    )
                }
            }
        }
        return nil
    }

    /// Extract the generic parameter from a generic type like "State<Int>" -> "Int".
    ///
    /// - Parameter typeName: The generic type name.
    /// - Returns: The inner type, or nil if not found.
    public static func extractGenericParameter(from typeName: String) -> String? {
        guard let startIndex = typeName.firstIndex(of: "<"),
            let endIndex = typeName.lastIndex(of: ">")
        else {
            return nil
        }

        let afterStart = typeName.index(after: startIndex)
        guard afterStart < endIndex else { return nil }

        return String(typeName[afterStart..<endIndex])
    }

    /// Check if a type looks like a Swift async type.
    ///
    /// Async functions have specific mangling patterns.
    ///
    /// - Parameter mangledName: The mangled function name.
    /// - Returns: true if the function appears to be async.
    public static func looksLikeAsyncFunction(_ mangledName: String) -> Bool {
        // Swift async functions have specific mangling patterns
        // The convention attribute in mangling includes 'a' for async
        // Pattern: $sSOME_NAME followed by convention markers
        // In practice, async functions have 'Ta' (thin async) or similar markers
        if mangledName.contains("Ta") || mangledName.contains("YaK") {
            return true
        }
        // Also check for async thunk markers
        if mangledName.contains("ScM") || mangledName.contains("Tu") {
            return true
        }
        return false
    }

    /// Check if a type represents a Sendable closure.
    ///
    /// - Parameter typeName: The type name.
    /// - Returns: true if the type looks like a @Sendable closure.
    public static func looksLikeSendableClosure(_ typeName: String) -> Bool {
        // @Sendable closures have specific patterns
        typeName.contains("@Sendable") || typeName.contains("Sendable")
    }

    /// Check if a type represents an actor.
    ///
    /// - Parameter typeName: The type name.
    /// - Returns: true if the type mentions actor isolation.
    public static func looksLikeActor(_ typeName: String) -> Bool {
        // Actor types or isolated parameters
        typeName.contains("actor") || typeName.contains("@isolated") || typeName.contains("@MainActor")
    }

    /// Check if a type represents an opaque return type (some Protocol).
    ///
    /// - Parameter typeName: The type name.
    /// - Returns: true if the type is an opaque type.
    public static func looksLikeOpaqueType(_ typeName: String) -> Bool {
        typeName.hasPrefix("some ") || typeName.contains("some ")
    }
}
