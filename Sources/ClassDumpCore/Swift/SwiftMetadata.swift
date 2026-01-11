// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

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

    // MARK: - Type Lookup

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

    // MARK: - Type Filters

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
