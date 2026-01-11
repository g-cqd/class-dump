// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

/// Symbolic reference kinds in Swift metadata.
///
/// Swift uses symbolic references (0x01-0x17) to point to type metadata
/// via relative offsets. This allows compact encoding of type information.
///
/// ## Reference Format
///
/// A symbolic reference consists of:
/// - 1 byte: Marker indicating the reference kind
/// - 4 bytes: Signed little-endian relative offset to the target
///
/// The target address is calculated as: `source_address + 1 + offset`
public enum SwiftSymbolicReferenceKind: UInt8, Sendable {

    /// Direct reference to a context descriptor.
    ///
    /// The offset points directly to a nominal type context descriptor
    /// containing flags, parent, name, and other type metadata.
    case directContext = 0x01

    /// Indirect reference through a pointer to a context descriptor.
    ///
    /// The offset points to a GOT-like entry containing a pointer
    /// to the actual type context descriptor. Used for external types
    /// from other modules.
    case indirectContext = 0x02

    /// Direct reference to an Objective-C protocol.
    ///
    /// The offset points to an ObjC protocol structure containing
    /// the protocol name and metadata.
    case directObjCProtocol = 0x09

    /// Unknown or invalid reference kind.
    case unknown = 0xFF

    // MARK: - Initialization

    /// Initialize from a marker byte.
    ///
    /// - Parameter marker: The first byte of a symbolic reference.
    public init(marker: UInt8) {
        switch marker {
            case 0x01: self = .directContext
            case 0x02: self = .indirectContext
            case 0x09: self = .directObjCProtocol
            default: self = .unknown
        }
    }

    // MARK: - Validation

    /// Check if a byte is a symbolic reference marker.
    ///
    /// Valid markers are in the range 0x01-0x17.
    ///
    /// Pure function.
    ///
    /// - Parameter byte: The byte to check.
    /// - Returns: True if the byte is a valid symbolic reference marker.
    public static func isSymbolicMarker(_ byte: UInt8) -> Bool {
        byte >= 0x01 && byte <= 0x17
    }

    /// The size of a complete symbolic reference in bytes.
    ///
    /// A symbolic reference is always 5 bytes: 1 marker + 4 offset bytes.
    public static let referenceSize: Int = 5
}
