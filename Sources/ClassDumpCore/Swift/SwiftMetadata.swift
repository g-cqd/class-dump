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

    public init(
        types: [SwiftType] = [],
        protocols: [SwiftProtocol] = [],
        conformances: [SwiftConformance] = [],
        fieldDescriptors: [SwiftFieldDescriptor] = []
    ) {
        self.types = types
        self.protocols = protocols
        self.conformances = conformances
        self.fieldDescriptors = fieldDescriptors

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

    public var isType: Bool {
        rawValue >= 16 && rawValue <= 31
    }
}

// MARK: - Type Context Descriptor Flags

/// Flags parsed from a type context descriptor.
public struct TypeContextDescriptorFlags: Sendable, Equatable {
    public let rawValue: UInt32

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

    /// Metadata initialization kind (bits 8-9).
    /// 0 = none, 1 = singleton, 2 = foreign
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
    /// This allows linking Swift type descriptors to ObjC class metadata.
    public let objcClassAddress: UInt64?

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
    public let name: String
    public let mangledTypeName: String
    public let typeName: String
    public let isVar: Bool
    public let isIndirect: Bool

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
}

/// A Swift protocol.
public struct SwiftProtocol: Sendable {
    public let address: UInt64
    public let name: String
    public let mangledName: String
    /// Parent module or namespace name.
    public let parentName: String?
    /// Associated type names declared by this protocol.
    public let associatedTypeNames: [String]
    /// Protocols that this protocol inherits from.
    public let inheritedProtocols: [String]
    /// All requirements of this protocol.
    public let requirements: [SwiftProtocolRequirement]

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

    public let kind: Kind
    public let name: String
    /// Whether this is an instance requirement (vs static/class).
    public let isInstance: Bool
    /// Whether this is an async requirement.
    public let isAsync: Bool
    /// Whether this requirement has a default implementation.
    public let hasDefaultImplementation: Bool

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
    public let rawValue: UInt32

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
    public let address: UInt64
    public let kind: SwiftFieldDescriptorKind
    public let mangledTypeName: String
    /// Raw bytes of the mangled type name (for symbolic reference resolution).
    public let mangledTypeNameData: Data
    /// File offset where the mangled type name was read (for symbolic resolution).
    public let mangledTypeNameOffset: Int
    public let superclassMangledName: String?
    public let records: [SwiftFieldRecord]

    /// Check if the owning type uses a symbolic reference.
    public var hasSymbolicReference: Bool {
        guard !mangledTypeNameData.isEmpty else { return false }
        let firstByte = mangledTypeNameData[mangledTypeNameData.startIndex]
        return SwiftSymbolicReferenceKind.isSymbolicMarker(firstByte)
    }

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
    public let flags: UInt32
    public let name: String
    public let mangledTypeName: String
    /// Raw bytes of the mangled type name (for symbolic reference resolution).
    public let mangledTypeData: Data
    /// File offset where the mangled type name was read (for symbolic resolution).
    public let mangledTypeNameOffset: Int

    public var isVar: Bool { (flags & 0x2) != 0 }
    public var isIndirect: Bool { (flags & 0x1) != 0 }

    /// Check if the type uses a symbolic reference at the start.
    public var hasSymbolicReference: Bool {
        guard !mangledTypeData.isEmpty else { return false }
        let firstByte = mangledTypeData[mangledTypeData.startIndex]
        return SwiftSymbolicReferenceKind.isSymbolicMarker(firstByte)
    }

    /// Check if the type contains any embedded symbolic references.
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
