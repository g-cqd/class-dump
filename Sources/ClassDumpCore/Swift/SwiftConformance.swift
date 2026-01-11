// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

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
