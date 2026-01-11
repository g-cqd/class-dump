// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

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
