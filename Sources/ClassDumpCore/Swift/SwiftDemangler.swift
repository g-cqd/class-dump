// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

/// Swift name demangler for converting mangled Swift type names to human-readable form.
///
/// This provides basic demangling for common Swift types. For full demangling,
/// the system's swift-demangle or libswiftDemangle would be needed.
public enum SwiftDemangler {
    // MARK: - Known Type Shortcuts

    /// Standard library type shortcuts (single character).
    private static let knownTypeShortcuts: [Character: String] = [
        "a": "Array",
        "b": "Bool",
        "D": "Dictionary",
        "d": "Double",
        "f": "Float",
        "h": "Set",
        "i": "Int",
        "J": "Character",
        "N": "ClosedRange",
        "n": "Range",
        "O": "ObjectIdentifier",
        "P": "UnsafePointer",
        "p": "UnsafeMutablePointer",
        "q": "Optional",
        "R": "UnsafeBufferPointer",
        "r": "UnsafeMutableBufferPointer",
        "S": "String",
        "s": "Substring",
        "u": "UInt",
        "V": "UnsafeRawPointer",
        "v": "UnsafeMutableRawPointer",
    ]

    /// Builtin type mappings.
    private static let builtinTypes: [String: String] = [
        "Bb": "Builtin.BridgeObject",
        "Bo": "Builtin.NativeObject",
        "BO": "Builtin.UnknownObject",
        "Bp": "Builtin.RawPointer",
        "Bw": "Builtin.Word",
        "BB": "Builtin.UnsafeValueBuffer",
    ]

    /// Common mangled type patterns.
    private static let commonPatterns: [String: String] = [
        "Sb": "Bool",
        "Si": "Int",
        "Su": "UInt",
        "Sf": "Float",
        "Sd": "Double",
        "SS": "String",
        "SZ": "UInt8",
        "Ss": "Int8",
        "s5Int8V": "Int8",
        "s6UInt8V": "UInt8",
        "s5Int16V": "Int16",
        "s6UInt16V": "UInt16",
        "s5Int32V": "Int32",
        "s6UInt32V": "UInt32",
        "s5Int64V": "Int64",
        "s6UInt64V": "UInt64",
        "Sg": "Optional",
        "ySg": "?",
        "Sq": "Optional",
    ]

    // MARK: - Public API

    /// Demangle a Swift type reference string.
    ///
    /// Swift type references in metadata often start with a symbolic reference
    /// marker (0x01-0x17) followed by a 4-byte relative offset, or they may
    /// be a mangled string starting with specific prefixes.
    ///
    /// - Parameter mangled: The mangled type name string.
    /// - Returns: A demangled type name, or the original if demangling fails.
    public static func demangle(_ mangled: String) -> String {
        guard !mangled.isEmpty else { return "" }

        // Handle symbolic references (binary format)
        if let first = mangled.first, first.asciiValue ?? 0 <= 0x17 {
            // This is a symbolic reference - we'd need to resolve it
            // from the binary. For now, return a placeholder.
            return "/* symbolic ref */"
        }

        // Try common patterns first
        if let result = commonPatterns[mangled] {
            return result
        }

        // Try to demangle using our simple demangler
        return simpleDemangle(mangled)
    }

    /// Demangle a class name from ObjC runtime format.
    ///
    /// Swift classes exposed to ObjC have names like `_TtC10ModuleName9ClassName`
    /// or the newer format `_TtC10ModuleName9ClassNameP33_...` for private types.
    ///
    /// - Parameter mangledClassName: The mangled class name.
    /// - Returns: A tuple of (moduleName, className) or nil if not a Swift class.
    public static func demangleClassName(_ mangledClassName: String) -> (module: String, name: String)? {
        // Check for Swift class prefix
        guard mangledClassName.hasPrefix("_TtC") || mangledClassName.hasPrefix("_TtGC") else {
            return nil
        }

        var input = mangledClassName.dropFirst(4)  // Skip "_TtC" or "_TtGC"

        // Parse module name (length-prefixed)
        guard let (moduleName, rest1) = parseLengthPrefixedString(input) else {
            return nil
        }
        input = rest1

        // Parse class name
        guard let (className, _) = parseLengthPrefixedString(input) else {
            return nil
        }

        return (moduleName, className)
    }

    /// Attempt to extract a readable type name from a mangled Swift type.
    ///
    /// - Parameter mangled: The mangled type string.
    /// - Returns: A simplified type name.
    public static func extractTypeName(_ mangled: String) -> String {
        // Handle empty
        guard !mangled.isEmpty else { return "" }

        // Handle ObjC-style Swift class names
        if mangled.hasPrefix("_Tt") {
            if let (module, name) = demangleClassName(mangled) {
                if module == "Swift" {
                    return name
                }
                return "\(module).\(name)"
            }
        }

        // Handle mangled names with module prefix
        // e.g., "10Foundation4DateV" -> "Foundation.Date"
        if let first = mangled.first, first.isNumber {
            return demangleQualifiedType(mangled)
        }

        // Handle single-character shortcuts
        if mangled.count == 1, let char = mangled.first,
            let shortcut = knownTypeShortcuts[char]
        {
            return shortcut
        }

        // Check builtin types
        if let builtin = builtinTypes[mangled] {
            return builtin
        }

        // For more complex mangling, try simple parsing
        return simpleDemangle(mangled)
    }

    // MARK: - Private Helpers

    /// Parse a length-prefixed string (e.g., "10Foundation" -> "Foundation").
    private static func parseLengthPrefixedString(_ input: Substring) -> (String, Substring)? {
        var lengthStr = ""
        var remaining = input

        // Read digits
        while let char = remaining.first, char.isNumber {
            lengthStr.append(char)
            remaining = remaining.dropFirst()
        }

        guard let length = Int(lengthStr), length > 0, remaining.count >= length else {
            return nil
        }

        let str = String(remaining.prefix(length))
        return (str, remaining.dropFirst(length))
    }

    /// Demangle a qualified type name like "10Foundation4DateV".
    private static func demangleQualifiedType(_ mangled: String) -> String {
        var components: [String] = []
        var input = Substring(mangled)

        while !input.isEmpty {
            // Check for type suffix
            if let first = input.first {
                switch first {
                case "V":  // struct
                    input = input.dropFirst()
                    continue
                case "C":  // class
                    input = input.dropFirst()
                    continue
                case "O":  // enum
                    input = input.dropFirst()
                    continue
                case "P":  // protocol (followed by underscore)
                    if input.hasPrefix("P_") {
                        input = input.dropFirst(2)
                        continue
                    }
                    // Could be start of private discriminator
                    break
                default:
                    break
                }
            }

            // Try to parse length-prefixed component
            if let first = input.first, first.isNumber {
                if let (component, rest) = parseLengthPrefixedString(input) {
                    components.append(component)
                    input = rest
                    continue
                }
            }

            // Skip unknown character
            input = input.dropFirst()
        }

        return components.joined(separator: ".")
    }

    /// Simple demangler for basic Swift type references.
    private static func simpleDemangle(_ mangled: String) -> String {
        let result = mangled

        // Handle Optional shorthand
        if result.hasSuffix("Sg") {
            let base = String(result.dropLast(2))
            let demangled = simpleDemangle(base)
            return "\(demangled)?"
        }

        // Handle Array shorthand (ySayG pattern)
        if result.hasPrefix("Say") && result.hasSuffix("G") {
            let inner = String(result.dropFirst(3).dropLast(1))
            let demangled = simpleDemangle(inner)
            return "[\(demangled)]"
        }

        // Handle Dictionary shorthand (ySDy...G pattern)
        if result.hasPrefix("SDy") && result.hasSuffix("G") {
            let inner = String(result.dropFirst(3).dropLast(1))
            // Dictionary has key_value separated by underscore in some encodings
            return "Dictionary<\(inner)>"
        }

        // Handle qualified names
        if let first = result.first, first.isNumber {
            return demangleQualifiedType(result)
        }

        // Handle Swift module prefix "s" or "S"
        if result.hasPrefix("s") || result.hasPrefix("S") {
            let rest = String(result.dropFirst())
            if let first = rest.first, first.isNumber {
                let typeName = demangleQualifiedType(rest)
                if !typeName.isEmpty {
                    return "Swift.\(typeName)"
                }
            }
        }

        // Check known shortcuts
        if result.count == 1, let char = result.first,
            let shortcut = knownTypeShortcuts[char]
        {
            return shortcut
        }

        return result
    }
}

// MARK: - Convenience Extensions

extension String {
    /// Attempt to demangle this string as a Swift type name.
    public var swiftDemangled: String {
        SwiftDemangler.demangle(self)
    }
}
