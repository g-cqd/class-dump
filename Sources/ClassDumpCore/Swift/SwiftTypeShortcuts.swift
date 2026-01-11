// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

// MARK: - Swift Type Shortcuts

/// Pure functions for resolving Swift type shortcut encodings.
///
/// Swift mangled names use compact shortcut encodings for common types.
/// This enum provides pure lookup functions to decode these shortcuts.
///
/// ## Shortcut Categories
///
/// - **Two-character shortcuts**: `SS` (String), `Si` (Int), etc.
/// - **Single-character shortcuts**: `a` (Array), `D` (Dictionary), etc.
/// - **Container prefixes**: `Say` (Array), `SDy` (Dictionary), `Shy` (Set)
public enum SwiftTypeShortcuts {

    // MARK: - Two-Character Shortcuts

    /// Resolve a standard two-character type shortcut.
    ///
    /// Swift uses two-character codes prefixed with 'S' for common types.
    ///
    /// Pure function.
    ///
    /// | Code | Type |
    /// |------|------|
    /// | SS | String |
    /// | Si | Int |
    /// | Su | UInt |
    /// | Sb | Bool |
    /// | Sd | Double |
    /// | Sf | Float |
    ///
    /// - Parameter chars: A two-character code (e.g., "SS", "Si").
    /// - Returns: The resolved type name, or nil if not a known shortcut.
    public static func resolveStandardShortcut(_ chars: String) -> String? {
        switch chars {
            case "SS": return "String"
            case "Si": return "Int"
            case "Su": return "UInt"
            case "Sb": return "Bool"
            case "Sd": return "Double"
            case "Sf": return "Float"
            case "Sg": return nil  // Optional suffix, not a type
            default: return nil
        }
    }

    // MARK: - Single-Character Shortcuts

    /// Resolve a single-character type shortcut.
    ///
    /// Some types have single-character encodings (mostly lowercase letters).
    ///
    /// Pure function.
    ///
    /// | Byte | Type |
    /// |------|------|
    /// | 0x61 ('a') | Array |
    /// | 0x62 ('b') | Bool |
    /// | 0x44 ('D') | Dictionary |
    /// | 0x64 ('d') | Double |
    /// | 0x66 ('f') | Float |
    /// | 0x68 ('h') | Set |
    /// | 0x69 ('i') | Int |
    /// | 0x75 ('u') | UInt |
    ///
    /// - Parameter byte: The byte value of the shortcut character.
    /// - Returns: The resolved type name, or nil if not a known shortcut.
    public static func resolveSingleCharShortcut(_ byte: UInt8) -> String? {
        switch byte {
            case 0x61: return "Array"  // 'a'
            case 0x62: return "Bool"  // 'b'
            case 0x44: return "Dictionary"  // 'D'
            case 0x64: return "Double"  // 'd'
            case 0x66: return "Float"  // 'f'
            case 0x68: return "Set"  // 'h'
            case 0x69: return "Int"  // 'i'
            case 0x75: return "UInt"  // 'u'
            default: return nil
        }
    }

    // MARK: - Container Type Detection

    /// Container type patterns in Swift mangling.
    public enum ContainerPattern {
        /// Array: `Say<element>G`
        case array
        /// Dictionary: `SDy<key><value>G`
        case dictionary
        /// Set: `Shy<element>G`
        case set
        /// Optional suffix: `Sg`
        case optional

        /// The byte sequence that starts this container pattern.
        public var prefix: [UInt8] {
            switch self {
                case .array: return [0x53, 0x61, 0x79]  // "Say"
                case .dictionary: return [0x53, 0x44, 0x79]  // "SDy"
                case .set: return [0x53, 0x68, 0x79]  // "Shy"
                case .optional: return [0x53, 0x67]  // "Sg"
            }
        }

        /// The number of type arguments this container expects.
        public var argumentCount: Int {
            switch self {
                case .array, .set, .optional: return 1
                case .dictionary: return 2
            }
        }
    }

    /// Detect if bytes start with a container type pattern.
    ///
    /// Pure function.
    ///
    /// - Parameter bytes: The bytes to check.
    /// - Returns: The detected container pattern, or nil if none matches.
    public static func detectContainerPattern(_ bytes: [UInt8]) -> ContainerPattern? {
        guard bytes.count >= 3 else { return nil }

        if bytes.starts(with: ContainerPattern.array.prefix) {
            return .array
        }
        if bytes.starts(with: ContainerPattern.dictionary.prefix) {
            return .dictionary
        }
        if bytes.starts(with: ContainerPattern.set.prefix) {
            return .set
        }

        return nil
    }

    /// Check if bytes end with Optional suffix "Sg".
    ///
    /// Pure function.
    ///
    /// - Parameters:
    ///   - bytes: The bytes to check.
    ///   - index: The index to check at.
    /// - Returns: True if "Sg" is found at the index.
    public static func hasOptionalSuffix(_ bytes: [UInt8], at index: Int) -> Bool {
        index + 1 < bytes.count
            && bytes[index] == 0x53  // 'S'
            && bytes[index + 1] == 0x67  // 'g'
    }

    /// Check if a byte is the generic closing marker 'G'.
    ///
    /// Pure function.
    ///
    /// - Parameter byte: The byte to check.
    /// - Returns: True if the byte is 'G' (0x47).
    @inlinable
    public static func isGenericClosing(_ byte: UInt8) -> Bool {
        byte == 0x47  // 'G'
    }

    /// Check if a byte is a digit (0-9).
    ///
    /// Pure function.
    ///
    /// - Parameter byte: The byte to check.
    /// - Returns: True if the byte is an ASCII digit.
    @inlinable
    public static func isDigit(_ byte: UInt8) -> Bool {
        byte >= 0x30 && byte <= 0x39  // '0'-'9'
    }

    /// Check if a byte is a type suffix marker (C, V, O, P).
    ///
    /// These markers indicate type kinds:
    /// - C: Class
    /// - V: Struct
    /// - O: Enum
    /// - P: Protocol
    ///
    /// Pure function.
    ///
    /// - Parameter byte: The byte to check.
    /// - Returns: True if the byte is a type suffix marker.
    @inlinable
    public static func isTypeSuffixMarker(_ byte: UInt8) -> Bool {
        byte == 0x43 || byte == 0x56 || byte == 0x4F || byte == 0x50
    }
}
