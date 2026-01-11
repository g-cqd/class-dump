// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

// MARK: - Symbol Kind Constants

extension SymbolGraph.Symbol.Kind {
    /// Protocol declaration.
    public static let objcProtocol = Self(identifier: "protocol", displayName: "Protocol")

    /// Class declaration.
    public static let objcClass = Self(identifier: "class", displayName: "Class")

    /// Instance method.
    public static let instanceMethod = Self(identifier: "method", displayName: "Instance Method")

    /// Class/type method.
    public static let typeMethod = Self(identifier: "typeMethod", displayName: "Type Method")

    /// Property declaration.
    public static let property = Self(identifier: "property", displayName: "Property")

    /// Instance variable.
    public static let ivar = Self(identifier: "ivar", displayName: "Instance Variable")

    /// Enumeration.
    public static let enumeration = Self(identifier: "enum", displayName: "Enumeration")

    /// Enumeration case.
    public static let enumCase = Self(identifier: "case", displayName: "Case")

    /// Type alias.
    public static let typeAlias = Self(identifier: "typealias", displayName: "Type Alias")

    /// Structure.
    public static let structure = Self(identifier: "struct", displayName: "Structure")
}

// MARK: - Relationship Kind Constants

extension SymbolGraph.Relationship {
    /// Relationship kind: symbol is a member of another.
    public static let memberOfKind = "memberOf"

    /// Relationship kind: protocol conforms to another protocol.
    public static let conformsToKind = "conformsTo"

    /// Relationship kind: class inherits from another.
    public static let inheritsFromKind = "inheritsFrom"

    /// Relationship kind: optional requirement of a protocol.
    public static let optionalRequirementOfKind = "optionalRequirementOf"

    /// Relationship kind: required requirement of a protocol.
    public static let requirementOfKind = "requirementOf"
}

// MARK: - Declaration Fragment Factories

extension SymbolGraph.Symbol.DeclarationFragment {
    /// Keyword fragment (e.g., "@interface", "class").
    public static func keyword(_ text: String) -> Self {
        Self(kind: "keyword", spelling: text, preciseIdentifier: nil)
    }

    /// Text fragment (whitespace, punctuation).
    public static func text(_ text: String) -> Self {
        Self(kind: "text", spelling: text, preciseIdentifier: nil)
    }

    /// Identifier fragment (symbol name).
    public static func identifier(_ text: String) -> Self {
        Self(kind: "identifier", spelling: text, preciseIdentifier: nil)
    }

    /// Type identifier fragment with optional linking.
    public static func typeIdentifier(_ text: String, preciseIdentifier: String? = nil) -> Self {
        Self(kind: "typeIdentifier", spelling: text, preciseIdentifier: preciseIdentifier)
    }

    /// Generic parameter fragment.
    public static func genericParameter(_ text: String) -> Self {
        Self(kind: "genericParameter", spelling: text, preciseIdentifier: nil)
    }

    /// Attribute fragment (e.g., "@property").
    public static func attribute(_ text: String) -> Self {
        Self(kind: "attribute", spelling: text, preciseIdentifier: nil)
    }

    /// Number literal fragment.
    public static func number(_ text: String) -> Self {
        Self(kind: "number", spelling: text, preciseIdentifier: nil)
    }

    /// String literal fragment.
    public static func string(_ text: String) -> Self {
        Self(kind: "string", spelling: text, preciseIdentifier: nil)
    }
}

// MARK: - Symbol Kind Analyzer

/// Pure functions for analyzing symbol kinds.
public enum SymbolKindAnalyzer {

    /// Check if a kind represents a type (class, struct, enum, protocol).
    ///
    /// Pure predicate function.
    ///
    /// - Parameter kind: The kind to check.
    /// - Returns: True if the kind is a type declaration.
    public static func isTypeDeclaration(_ kind: SymbolGraph.Symbol.Kind) -> Bool {
        let typeKinds = ["class", "struct", "enum", "protocol", "typealias"]
        return typeKinds.contains(kind.identifier)
    }

    /// Check if a kind represents a member (method, property, ivar).
    ///
    /// Pure predicate function.
    ///
    /// - Parameter kind: The kind to check.
    /// - Returns: True if the kind is a member.
    public static func isMember(_ kind: SymbolGraph.Symbol.Kind) -> Bool {
        let memberKinds = ["method", "typeMethod", "property", "ivar", "case"]
        return memberKinds.contains(kind.identifier)
    }

    /// Check if a kind represents a callable (method, function).
    ///
    /// Pure predicate function.
    ///
    /// - Parameter kind: The kind to check.
    /// - Returns: True if the kind is callable.
    public static func isCallable(_ kind: SymbolGraph.Symbol.Kind) -> Bool {
        let callableKinds = ["method", "typeMethod", "func", "init"]
        return callableKinds.contains(kind.identifier)
    }
}

// MARK: - Relationship Kind Analyzer

/// Pure functions for analyzing relationship kinds.
public enum RelationshipKindAnalyzer {

    /// Check if a relationship kind represents hierarchy (inheritance, conformance).
    ///
    /// Pure predicate function.
    ///
    /// - Parameter kind: The relationship kind string.
    /// - Returns: True if the relationship is hierarchical.
    public static func isHierarchical(_ kind: String) -> Bool {
        let hierarchyKinds = [
            SymbolGraph.Relationship.inheritsFromKind,
            SymbolGraph.Relationship.conformsToKind,
        ]
        return hierarchyKinds.contains(kind)
    }

    /// Check if a relationship kind represents membership.
    ///
    /// Pure predicate function.
    ///
    /// - Parameter kind: The relationship kind string.
    /// - Returns: True if the relationship is membership.
    public static func isMembership(_ kind: String) -> Bool {
        let membershipKinds = [
            SymbolGraph.Relationship.memberOfKind,
            SymbolGraph.Relationship.requirementOfKind,
            SymbolGraph.Relationship.optionalRequirementOfKind,
        ]
        return membershipKinds.contains(kind)
    }

    /// Check if a relationship kind represents a protocol requirement.
    ///
    /// Pure predicate function.
    ///
    /// - Parameter kind: The relationship kind string.
    /// - Returns: True if the relationship is a requirement.
    public static func isRequirement(_ kind: String) -> Bool {
        kind == SymbolGraph.Relationship.requirementOfKind
            || kind == SymbolGraph.Relationship.optionalRequirementOfKind
    }
}
