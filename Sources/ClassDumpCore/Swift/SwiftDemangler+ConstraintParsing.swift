// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

/// Generic constraint parsing extensions for SwiftDemangler.
///
/// This extension provides pure parsing functions for Swift generic
/// constraints including conformance, same-type, layout, and base class
/// requirements.
///
/// All functions are pure - they take input and return output without side effects.
extension SwiftDemangler {

    // MARK: - Generic Signature Parsing

    /// Parse a generic signature from mangled format.
    ///
    /// Generic signatures in Swift mangling use various markers to encode constraints:
    ///   - `Rz` - conformance requirement (T: Protocol)
    ///   - `Rs` - same-type requirement (T == Type)
    ///   - `Rl` - layout requirement (T: AnyObject)
    ///   - `Rb` - base class requirement (T: BaseClass)
    ///   - `R_` - general requirement prefix
    ///
    /// Pure function for parsing complete generic signatures.
    ///
    /// - Parameter mangled: The mangled string containing the generic signature.
    /// - Returns: A parsed `GenericSignature`, or nil if parsing fails.
    static func parseGenericSignature(_ mangled: String) -> GenericSignature? {
        guard !mangled.isEmpty else { return nil }

        var input = Substring(mangled)
        var constraints: [DemangledConstraint] = []

        // Default parameter names: T, U, V, W
        let paramNames = ["T", "U", "V", "W"]

        // Parse constraints until we hit 'l' (end of signature) or run out
        while !input.isEmpty {
            // Check for end of generic signature marker
            if input.hasPrefix("l") {
                input = input.dropFirst()
                break
            }

            // Check for multi-param marker (r0_, r1_, etc.)
            if input.hasPrefix("r") {
                input = input.dropFirst()
                // Skip parameter index
                while let c = input.first, c.isNumber || c == "_" {
                    input = input.dropFirst()
                }
                continue
            }

            // Parse constraint
            if let (constraint, rest) = parseGenericConstraint(input, paramNames: paramNames) {
                constraints.append(constraint)
                input = rest
            }
            else {
                // Skip unrecognized content
                input = input.dropFirst()
            }
        }

        return GenericSignature(
            parameters: Array(paramNames.prefix(max(1, constraints.count))),
            constraints: constraints
        )
    }

    /// Parse a single generic constraint from mangled input.
    ///
    /// Pure function for extracting individual constraints.
    ///
    /// - Parameters:
    ///   - input: The mangled input starting at a constraint marker.
    ///   - paramNames: Available parameter names to reference.
    /// - Returns: A parsed constraint and remaining input, or nil if not a constraint.
    static func parseGenericConstraint(
        _ input: Substring,
        paramNames: [String]
    ) -> (DemangledConstraint, Substring)? {
        var remaining = input

        // Parse the protocol/type that forms the constraint first
        var protocolName: String?

        // Check for protocol shortcut (SH, SE, Sl, etc.)
        if remaining.count >= 2 {
            let twoChars = String(remaining.prefix(2))
            if let proto = SwiftDemanglerTables.protocolShortcut(for: twoChars) {
                protocolName = proto
                remaining = remaining.dropFirst(2)
            }
            else if let typeName = SwiftDemanglerTables.commonPattern(for: twoChars) {
                protocolName = typeName
                remaining = remaining.dropFirst(2)
            }
        }

        // Check for length-prefixed protocol name
        if protocolName == nil, let first = remaining.first, first.isNumber {
            if let (name, rest) = SwiftDemanglerParsers.lengthPrefixed(remaining) {
                protocolName = name
                remaining = rest
                // Skip protocol suffix 'P'
                if remaining.hasPrefix("P") {
                    remaining = remaining.dropFirst()
                }
            }
        }

        // Check for Swift module protocol (s + length + name + P)
        if protocolName == nil, remaining.hasPrefix("s") {
            let afterS = remaining.dropFirst()
            if let first = afterS.first, first.isNumber {
                if let (name, rest) = SwiftDemanglerParsers.lengthPrefixed(afterS) {
                    protocolName = name
                    remaining = rest
                    if remaining.hasPrefix("P") {
                        remaining = remaining.dropFirst()
                    }
                }
            }
        }

        // Now look for requirement marker
        guard remaining.hasPrefix("R") else {
            return nil
        }

        remaining = remaining.dropFirst()  // Skip 'R'

        // Determine constraint kind
        guard let kindChar = remaining.first else {
            return nil
        }

        var kind: ConstraintKind
        var subject = paramNames.first ?? "T"
        var constraintTarget = protocolName ?? "Unknown"

        switch kindChar {
            case "z":
                // Conformance requirement (T: Protocol)
                kind = .conformance
                remaining = remaining.dropFirst()

            case "s":
                // Same-type requirement (T == Type)
                kind = .sameType
                remaining = remaining.dropFirst()
                if let (typeName, rest) = parseConstraintType(remaining) {
                    constraintTarget = typeName
                    remaining = rest
                }

            case "l":
                // Layout requirement (T: AnyObject)
                kind = .layout
                remaining = remaining.dropFirst()
                constraintTarget = "AnyObject"

            case "b":
                // Base class requirement (T: BaseClass)
                kind = .baseClass
                remaining = remaining.dropFirst()
                if let (className, rest) = parseConstraintType(remaining) {
                    constraintTarget = className
                    remaining = rest
                }

            case "_":
                // Associated type constraint marker
                remaining = remaining.dropFirst()
                if let (path, rest) = parseAssociatedTypePath(remaining, baseParam: subject) {
                    subject = path
                    remaining = rest
                }
                kind = .conformance

            default:
                remaining = remaining.dropFirst()
                kind = .conformance
        }

        // Check for subject parameter override
        if remaining.hasPrefix("_") {
            remaining = remaining.dropFirst()
        }

        return (
            DemangledConstraint(
                subject: subject,
                kind: kind,
                constraint: constraintTarget
            ),
            remaining
        )
    }

    /// Parse a type reference in a constraint.
    ///
    /// Pure function for extracting constraint type references.
    static func parseConstraintType(_ input: Substring) -> (String, Substring)? {
        var remaining = input

        // Check for common type patterns
        if remaining.count >= 2 {
            let twoChars = String(remaining.prefix(2))
            if let typeName = SwiftDemanglerTables.commonPattern(for: twoChars) {
                return (typeName, remaining.dropFirst(2))
            }
        }

        // Check for single-character shortcuts
        if let first = remaining.first,
            let typeName = SwiftDemanglerTables.typeShortcut(for: first)
        {
            return (typeName, remaining.dropFirst())
        }

        // Check for length-prefixed type
        if let first = remaining.first, first.isNumber {
            if let (name, rest) = SwiftDemanglerParsers.lengthPrefixed(remaining) {
                var r = rest
                while let c = r.first, "CVOPy_".contains(c) {
                    r = r.dropFirst()
                }
                return (name, r)
            }
        }

        // Check for ObjC imported type (So prefix)
        if remaining.hasPrefix("So") {
            remaining = remaining.dropFirst(2)
            if let (name, rest) = SwiftDemanglerParsers.lengthPrefixed(remaining) {
                var r = rest
                while let c = r.first, "CVOPy_".contains(c) {
                    r = r.dropFirst()
                }
                return (name, r)
            }
        }

        // Check for Swift module type (s prefix)
        if remaining.hasPrefix("s") {
            let afterS = remaining.dropFirst()
            if let first = afterS.first, first.isNumber {
                if let (name, rest) = SwiftDemanglerParsers.lengthPrefixed(afterS) {
                    var r = rest
                    while let c = r.first, "CVOPy_".contains(c) {
                        r = r.dropFirst()
                    }
                    return (name, r)
                }
            }
        }

        return nil
    }

    /// Parse an associated type path (e.g., "T.Element").
    ///
    /// Pure function for extracting associated type paths.
    static func parseAssociatedTypePath(
        _ input: Substring,
        baseParam: String
    ) -> (String, Substring)? {
        var remaining = input
        var path = baseParam

        // Look for associated type name
        if let first = remaining.first, first.isNumber {
            if let (assocName, rest) = SwiftDemanglerParsers.lengthPrefixed(remaining) {
                path = "\(baseParam).\(assocName)"
                remaining = rest
            }
        }
        else if remaining.count >= 7, remaining.hasPrefix("Element") {
            path = "\(baseParam).Element"
            remaining = remaining.dropFirst(7)
        }

        return path != baseParam ? (path, remaining) : nil
    }

    // MARK: - Constraint With Name Demangling

    /// Demangle a symbol that may contain generic constraints.
    ///
    /// Pure convenience function that extracts and formats the where clause
    /// from a mangled symbol if present.
    ///
    /// - Parameter mangled: The mangled symbol.
    /// - Returns: A tuple of (base demangled name, where clause) or nil.
    static func demangleNameWithConstraints(
        _ mangled: String
    ) -> (
        name: String, whereClause: String
    )? {
        // First get the basic demangled name
        let baseName = demangleSwiftName(mangled)

        // Look for constraint portion
        var input = Substring(mangled)

        // Skip to generic portion
        while !input.isEmpty
            && !input.hasPrefix("Rz")
            && !input.hasPrefix("Rs")
            && !input.hasPrefix("Rl")
            && !input.hasPrefix("Rb")
        {
            if input.hasPrefix("l") && input.count > 1 {
                break
            }
            input = input.dropFirst()
        }

        // If we found a constraint marker, try to parse from there
        if input.hasPrefix("R") {
            let offset = mangled.count - input.count - 2
            if offset >= 0 {
                let signatureStart = String(mangled.dropFirst(offset))
                if let sig = parseGenericSignature(signatureStart) {
                    return (baseName, sig.whereClause)
                }
            }
        }

        return (baseName, "")
    }
}
