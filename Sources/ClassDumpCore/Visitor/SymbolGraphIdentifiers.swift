// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

// MARK: - ObjC Symbol Identifier Generator

/// Pure functions for generating ObjC symbol precise identifiers.
///
/// These identifiers follow Apple's USR (Unified Symbol Resolution) format
/// for Objective-C symbols, enabling linking between symbol graphs and
/// integration with documentation tools.
///
/// ## Identifier Format
///
/// ObjC identifiers use the format: `c:objc({prefix}){name}({suffix}){member}`
///
/// Where:
/// - `c:` indicates a C-family symbol
/// - `objc({prefix})` specifies the ObjC symbol type:
///   - `cs` for class
///   - `pl` for protocol
/// - `{name}` is the class/protocol name
/// - `({suffix})` specifies the member type:
///   - `im` for instance method
///   - `cm` for class method
///   - `py` for property
///   - `ivar` for instance variable
/// - `{member}` is the member name/selector
public enum ObjCSymbolIdentifiers {

    // MARK: - Type Identifiers

    /// Generate a precise identifier for an ObjC class.
    ///
    /// Pure function.
    ///
    /// - Parameter name: The class name.
    /// - Returns: Precise identifier string.
    public static func classIdentifier(_ name: String) -> String {
        "c:objc(cs)\(name)"
    }

    /// Generate a precise identifier for an ObjC protocol.
    ///
    /// Pure function.
    ///
    /// - Parameter name: The protocol name.
    /// - Returns: Precise identifier string.
    public static func protocolIdentifier(_ name: String) -> String {
        "c:objc(pl)\(name)"
    }

    // MARK: - Method Identifiers

    /// Generate a precise identifier for an ObjC method.
    ///
    /// Pure function.
    ///
    /// - Parameters:
    ///   - selector: The method selector.
    ///   - isClassMethod: Whether this is a class method (+) or instance method (-).
    ///   - parentName: Name of the containing class or protocol.
    ///   - isProtocol: Whether the parent is a protocol.
    /// - Returns: Precise identifier string.
    public static func methodIdentifier(
        selector: String,
        isClassMethod: Bool,
        parentName: String,
        isProtocol: Bool
    ) -> String {
        let parentPrefix = isProtocol ? "pl" : "cs"
        let methodPrefix = isClassMethod ? "cm" : "im"
        return "c:objc(\(parentPrefix))\(parentName)(\(methodPrefix))\(selector)"
    }

    /// Generate a precise identifier for an instance method.
    ///
    /// Pure function, convenience wrapper.
    ///
    /// - Parameters:
    ///   - selector: The method selector.
    ///   - parentName: Name of the containing class or protocol.
    ///   - isProtocol: Whether the parent is a protocol.
    /// - Returns: Precise identifier string.
    public static func instanceMethodIdentifier(
        selector: String,
        parentName: String,
        isProtocol: Bool = false
    ) -> String {
        methodIdentifier(
            selector: selector,
            isClassMethod: false,
            parentName: parentName,
            isProtocol: isProtocol
        )
    }

    /// Generate a precise identifier for a class method.
    ///
    /// Pure function, convenience wrapper.
    ///
    /// - Parameters:
    ///   - selector: The method selector.
    ///   - parentName: Name of the containing class or protocol.
    ///   - isProtocol: Whether the parent is a protocol.
    /// - Returns: Precise identifier string.
    public static func classMethodIdentifier(
        selector: String,
        parentName: String,
        isProtocol: Bool = false
    ) -> String {
        methodIdentifier(
            selector: selector,
            isClassMethod: true,
            parentName: parentName,
            isProtocol: isProtocol
        )
    }

    // MARK: - Property Identifiers

    /// Generate a precise identifier for an ObjC property.
    ///
    /// Pure function.
    ///
    /// - Parameters:
    ///   - name: The property name.
    ///   - parentName: Name of the containing class or protocol.
    ///   - isProtocol: Whether the parent is a protocol.
    /// - Returns: Precise identifier string.
    public static func propertyIdentifier(
        name: String,
        parentName: String,
        isProtocol: Bool
    ) -> String {
        let parentPrefix = isProtocol ? "pl" : "cs"
        return "c:objc(\(parentPrefix))\(parentName)(py)\(name)"
    }

    // MARK: - Ivar Identifiers

    /// Generate a precise identifier for an ObjC instance variable.
    ///
    /// Pure function.
    ///
    /// - Parameters:
    ///   - name: The ivar name.
    ///   - className: Name of the containing class.
    /// - Returns: Precise identifier string.
    public static func ivarIdentifier(name: String, className: String) -> String {
        "c:objc(cs)\(className)(ivar)\(name)"
    }

    // MARK: - Identifier Parsing

    /// Parse a precise identifier to extract its components.
    ///
    /// Pure function.
    ///
    /// - Parameter identifier: The precise identifier string.
    /// - Returns: Parsed components or nil if invalid.
    public static func parse(_ identifier: String) -> ParsedIdentifier? {
        guard identifier.hasPrefix("c:objc(") else { return nil }

        // Extract parent prefix (cs or pl)
        let afterPrefix = identifier.dropFirst("c:objc(".count)
        guard let closeIndex = afterPrefix.firstIndex(of: ")") else { return nil }

        let parentPrefix = String(afterPrefix[..<closeIndex])
        let isProtocol = parentPrefix == "pl"

        let afterParentPrefix = afterPrefix[afterPrefix.index(after: closeIndex)...]

        // Find member prefix if present
        guard let memberStart = afterParentPrefix.firstIndex(of: "(") else {
            // Top-level type (no member)
            return ParsedIdentifier(
                isProtocol: isProtocol,
                parentName: String(afterParentPrefix),
                memberKind: nil,
                memberName: nil
            )
        }
        let parentName = String(afterParentPrefix[..<memberStart])
        let memberPart = afterParentPrefix[afterParentPrefix.index(after: memberStart)...]

        guard let memberPrefixEnd = memberPart.firstIndex(of: ")") else { return nil }
        let memberPrefix = String(memberPart[..<memberPrefixEnd])
        let memberName = String(memberPart[memberPart.index(after: memberPrefixEnd)...])

        let memberKind = MemberKind(prefix: memberPrefix)

        return ParsedIdentifier(
            isProtocol: isProtocol,
            parentName: parentName,
            memberKind: memberKind,
            memberName: memberName
        )
    }

    /// Parsed components of a precise identifier.
    public struct ParsedIdentifier: Sendable {
        /// Whether the parent is a protocol.
        public let isProtocol: Bool
        /// Name of the containing class or protocol.
        public let parentName: String
        /// Kind of member (method, property, ivar) or nil for types.
        public let memberKind: MemberKind?
        /// Name of the member or nil for types.
        public let memberName: String?

        /// Whether this identifier represents a top-level type.
        public var isType: Bool {
            memberKind == nil
        }

        /// Whether this identifier represents a method.
        public var isMethod: Bool {
            memberKind == .instanceMethod || memberKind == .classMethod
        }
    }

    /// Kind of member in an identifier.
    public enum MemberKind: Sendable {
        case instanceMethod
        case classMethod
        case property
        case ivar

        init?(prefix: String) {
            switch prefix {
                case "im": self = .instanceMethod
                case "cm": self = .classMethod
                case "py": self = .property
                case "ivar": self = .ivar
                default: return nil
            }
        }
    }

    // MARK: - Identifier Predicates

    /// Check if an identifier represents a class.
    ///
    /// Pure predicate function.
    ///
    /// - Parameter identifier: The identifier to check.
    /// - Returns: True if the identifier is for a class.
    public static func isClassIdentifier(_ identifier: String) -> Bool {
        identifier.hasPrefix("c:objc(cs)") && !identifier.contains("(im)")
            && !identifier.contains("(cm)") && !identifier.contains("(py)")
            && !identifier.contains("(ivar)")
    }

    /// Check if an identifier represents a protocol.
    ///
    /// Pure predicate function.
    ///
    /// - Parameter identifier: The identifier to check.
    /// - Returns: True if the identifier is for a protocol.
    public static func isProtocolIdentifier(_ identifier: String) -> Bool {
        identifier.hasPrefix("c:objc(pl)") && !identifier.contains("(im)")
            && !identifier.contains("(cm)") && !identifier.contains("(py)")
    }

    /// Check if an identifier represents a method.
    ///
    /// Pure predicate function.
    ///
    /// - Parameter identifier: The identifier to check.
    /// - Returns: True if the identifier is for a method.
    public static func isMethodIdentifier(_ identifier: String) -> Bool {
        identifier.contains("(im)") || identifier.contains("(cm)")
    }

    /// Check if an identifier represents a property.
    ///
    /// Pure predicate function.
    ///
    /// - Parameter identifier: The identifier to check.
    /// - Returns: True if the identifier is for a property.
    public static func isPropertyIdentifier(_ identifier: String) -> Bool {
        identifier.contains("(py)")
    }
}
