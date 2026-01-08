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

/// A Swift type (class, struct, or enum).
public struct SwiftType: Sendable {
    public let address: UInt64
    public let kind: SwiftContextDescriptorKind
    public let name: String
    public let mangledName: String
    public let parentName: String?
    public let superclassName: String?
    public let fields: [SwiftField]
    public let genericParameters: [String]

    public init(
        address: UInt64,
        kind: SwiftContextDescriptorKind,
        name: String,
        mangledName: String = "",
        parentName: String? = nil,
        superclassName: String? = nil,
        fields: [SwiftField] = [],
        genericParameters: [String] = []
    ) {
        self.address = address
        self.kind = kind
        self.name = name
        self.mangledName = mangledName
        self.parentName = parentName
        self.superclassName = superclassName
        self.fields = fields
        self.genericParameters = genericParameters
    }

    /// Full qualified name including parent.
    public var fullName: String {
        if let parent = parentName, !parent.isEmpty {
            return "\(parent).\(name)"
        }
        return name
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
    public let requirements: [SwiftProtocolRequirement]

    public init(
        address: UInt64,
        name: String,
        mangledName: String = "",
        requirements: [SwiftProtocolRequirement] = []
    ) {
        self.address = address
        self.name = name
        self.mangledName = mangledName
        self.requirements = requirements
    }
}

/// A Swift protocol requirement.
public struct SwiftProtocolRequirement: Sendable {
    public enum Kind: Sendable {
        case baseProtocol
        case method
        case initializer
        case getter
        case setter
        case readCoroutine
        case modifyCoroutine
        case associatedTypeAccessFunction
        case associatedConformanceAccessFunction
    }

    public let kind: Kind
    public let name: String

    public init(kind: Kind, name: String) {
        self.kind = kind
        self.name = name
    }
}

/// A Swift protocol conformance.
public struct SwiftConformance: Sendable {
    public let typeAddress: UInt64
    public let typeName: String
    public let protocolName: String

    public init(typeAddress: UInt64, typeName: String, protocolName: String) {
        self.typeAddress = typeAddress
        self.typeName = typeName
        self.protocolName = protocolName
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
