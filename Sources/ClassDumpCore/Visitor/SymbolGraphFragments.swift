// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

// MARK: - Declaration Fragment Builder

/// Pure functions for building declaration fragments.
///
/// Declaration fragments are used for syntax highlighting in documentation.
/// Each fragment has a kind (keyword, text, identifier, etc.) and spelling (text).
public enum DeclarationFragmentBuilder {

    // MARK: - Type Fragments

    /// Build declaration fragments for a type name.
    ///
    /// Handles pointer types by splitting into base type and pointer indicator.
    ///
    /// Pure function.
    ///
    /// - Parameter typeName: The type name string.
    /// - Returns: Array of declaration fragments.
    public static func typeFragments(_ typeName: String) -> [SymbolGraph.Symbol.DeclarationFragment] {
        if typeName.hasSuffix("*") {
            let baseType = String(typeName.dropLast()).trimmingCharacters(in: .whitespaces)
            return [
                .typeIdentifier(baseType, preciseIdentifier: ObjCSymbolIdentifiers.classIdentifier(baseType)),
                .text(" *"),
            ]
        }
        return [.typeIdentifier(typeName)]
    }

    /// Build declaration fragments for a type with a linking identifier.
    ///
    /// Pure function.
    ///
    /// - Parameters:
    ///   - typeName: The type name string.
    ///   - identifier: Optional precise identifier for linking.
    /// - Returns: Array of declaration fragments.
    public static func linkedTypeFragments(
        _ typeName: String,
        identifier: String?
    ) -> [SymbolGraph.Symbol.DeclarationFragment] {
        if typeName.hasSuffix("*") {
            let baseType = String(typeName.dropLast()).trimmingCharacters(in: .whitespaces)
            return [
                .typeIdentifier(baseType, preciseIdentifier: identifier),
                .text(" *"),
            ]
        }
        return [.typeIdentifier(typeName, preciseIdentifier: identifier)]
    }

    // MARK: - Method Fragments

    /// Build declaration fragments for an ObjC method.
    ///
    /// Pure function that creates fragments for method declarations like:
    /// `- (ReturnType)selectorPart:(ParamType)param1 otherPart:(ParamType)param2`
    ///
    /// - Parameters:
    ///   - selector: The method selector.
    ///   - isClassMethod: Whether this is a class method.
    ///   - returnType: The return type string.
    ///   - parameterTypes: Array of parameter type strings.
    /// - Returns: Array of declaration fragments.
    public static func methodFragments(
        selector: String,
        isClassMethod: Bool,
        returnType: String,
        parameterTypes: [String]
    ) -> [SymbolGraph.Symbol.DeclarationFragment] {
        var fragments: [SymbolGraph.Symbol.DeclarationFragment] = []

        // Method type indicator
        fragments.append(.text(isClassMethod ? "+ " : "- "))

        // Return type
        fragments.append(.text("("))
        fragments.append(contentsOf: typeFragments(returnType))
        fragments.append(.text(")"))

        // Selector and parameters
        let selectorParts = selector.split(separator: ":", omittingEmptySubsequences: false)

        if selectorParts.count <= 1 {
            // Simple selector without parameters
            fragments.append(.identifier(selector))
        }
        else {
            // Selector with parameters
            for (i, part) in selectorParts.dropLast().enumerated() {
                if i > 0 {
                    fragments.append(.text(" "))
                }
                fragments.append(.identifier(String(part)))
                fragments.append(.text(":"))

                // Parameter type
                if i < parameterTypes.count {
                    fragments.append(.text("("))
                    fragments.append(contentsOf: typeFragments(parameterTypes[i]))
                    fragments.append(.text(")"))
                }
                else {
                    fragments.append(.text("(id)"))
                }
                fragments.append(.identifier("arg\(i)"))
            }
        }

        return fragments
    }

    /// Build declaration fragments for a simple method (no type info).
    ///
    /// Pure function for fallback when type info is unavailable.
    ///
    /// - Parameters:
    ///   - selector: The method selector.
    ///   - isClassMethod: Whether this is a class method.
    /// - Returns: Array of declaration fragments.
    public static func simpleMethodFragments(
        selector: String,
        isClassMethod: Bool
    ) -> [SymbolGraph.Symbol.DeclarationFragment] {
        var fragments: [SymbolGraph.Symbol.DeclarationFragment] = []

        fragments.append(.text(isClassMethod ? "+ " : "- "))
        fragments.append(.text("(id)"))

        let selectorParts = selector.split(separator: ":", omittingEmptySubsequences: false)

        if selectorParts.count <= 1 {
            fragments.append(.identifier(selector))
        }
        else {
            for (i, part) in selectorParts.dropLast().enumerated() {
                if i > 0 {
                    fragments.append(.text(" "))
                }
                fragments.append(.identifier(String(part)))
                fragments.append(.text(":(id)arg\(i)"))
            }
        }

        return fragments
    }

    // MARK: - Property Fragments

    /// Build declaration fragments for an ObjC property.
    ///
    /// Pure function that creates fragments for property declarations like:
    /// `@property (nonatomic, strong) Type *name`
    ///
    /// - Parameters:
    ///   - name: The property name.
    ///   - typeName: The property type string.
    ///   - attributes: Property attributes.
    /// - Returns: Array of declaration fragments.
    public static func propertyFragments(
        name: String,
        typeName: String,
        attributes: PropertyAttributes
    ) -> [SymbolGraph.Symbol.DeclarationFragment] {
        var fragments: [SymbolGraph.Symbol.DeclarationFragment] = []

        fragments.append(.attribute("@property"))
        fragments.append(.text(" "))

        // Build attribute list
        var attrs: [String] = []
        if attributes.isNonatomic {
            attrs.append("nonatomic")
        }
        if attributes.isReadOnly {
            attrs.append("readonly")
        }
        if attributes.isCopy {
            attrs.append("copy")
        }
        if attributes.isWeak {
            attrs.append("weak")
        }
        else if attributes.isStrong {
            attrs.append("strong")
        }

        if !attrs.isEmpty {
            fragments.append(.text("(\(attrs.joined(separator: ", "))) "))
        }

        // Type
        fragments.append(contentsOf: typeFragments(typeName))
        fragments.append(.text(" "))

        // Name
        fragments.append(.identifier(name))

        return fragments
    }

    /// Property attributes for fragment generation.
    public struct PropertyAttributes: Sendable {
        /// Whether the property is nonatomic.
        public let isNonatomic: Bool
        /// Whether the property is read-only.
        public let isReadOnly: Bool
        /// Whether the property uses copy semantics.
        public let isCopy: Bool
        /// Whether the property is weak.
        public let isWeak: Bool
        /// Whether the property is strong.
        public let isStrong: Bool

        /// Create property attributes.
        ///
        /// - Parameters:
        ///   - isNonatomic: Whether the property is nonatomic.
        ///   - isReadOnly: Whether the property is read-only.
        ///   - isCopy: Whether the property uses copy semantics.
        ///   - isWeak: Whether the property is weak.
        ///   - isStrong: Whether the property is strong.
        public init(
            isNonatomic: Bool = false,
            isReadOnly: Bool = false,
            isCopy: Bool = false,
            isWeak: Bool = false,
            isStrong: Bool = false
        ) {
            self.isNonatomic = isNonatomic
            self.isReadOnly = isReadOnly
            self.isCopy = isCopy
            self.isWeak = isWeak
            self.isStrong = isStrong
        }
    }

    // MARK: - Class/Protocol Fragments

    /// Build declaration fragments for an ObjC class.
    ///
    /// Pure function that creates fragments for class declarations like:
    /// `@interface ClassName : SuperClass <Protocol1, Protocol2>`
    ///
    /// - Parameters:
    ///   - name: The class name.
    ///   - superclassName: Optional superclass name.
    ///   - protocols: Adopted protocol names.
    /// - Returns: Array of declaration fragments.
    public static func classFragments(
        name: String,
        superclassName: String?,
        protocols: [String]
    ) -> [SymbolGraph.Symbol.DeclarationFragment] {
        var fragments: [SymbolGraph.Symbol.DeclarationFragment] = [
            .keyword("@interface"),
            .text(" "),
            .identifier(name),
        ]

        if let superclass = superclassName {
            fragments.append(.text(" : "))
            fragments.append(
                .typeIdentifier(
                    superclass,
                    preciseIdentifier: ObjCSymbolIdentifiers.classIdentifier(superclass)
                )
            )
        }

        if !protocols.isEmpty {
            fragments.append(.text(" <"))
            for (i, proto) in protocols.enumerated() {
                if i > 0 {
                    fragments.append(.text(", "))
                }
                fragments.append(
                    .typeIdentifier(
                        proto,
                        preciseIdentifier: ObjCSymbolIdentifiers.protocolIdentifier(proto)
                    )
                )
            }
            fragments.append(.text(">"))
        }

        return fragments
    }

    /// Build declaration fragments for an ObjC protocol.
    ///
    /// Pure function that creates fragments for protocol declarations like:
    /// `@protocol ProtocolName <AdoptedProtocol1, AdoptedProtocol2>`
    ///
    /// - Parameters:
    ///   - name: The protocol name.
    ///   - adoptedProtocols: Names of adopted protocols.
    /// - Returns: Array of declaration fragments.
    public static func protocolFragments(
        name: String,
        adoptedProtocols: [String]
    ) -> [SymbolGraph.Symbol.DeclarationFragment] {
        var fragments: [SymbolGraph.Symbol.DeclarationFragment] = [
            .keyword("@protocol"),
            .text(" "),
            .identifier(name),
        ]

        if !adoptedProtocols.isEmpty {
            fragments.append(.text(" <"))
            for (i, proto) in adoptedProtocols.enumerated() {
                if i > 0 {
                    fragments.append(.text(", "))
                }
                fragments.append(
                    .typeIdentifier(
                        proto,
                        preciseIdentifier: ObjCSymbolIdentifiers.protocolIdentifier(proto)
                    )
                )
            }
            fragments.append(.text(">"))
        }

        return fragments
    }

    // MARK: - Ivar Fragments

    /// Build declaration fragments for an ObjC instance variable.
    ///
    /// Pure function that creates fragments for ivar declarations like:
    /// `Type *_ivarName`
    ///
    /// - Parameters:
    ///   - name: The ivar name.
    ///   - typeName: The ivar type string.
    /// - Returns: Array of declaration fragments.
    public static func ivarFragments(
        name: String,
        typeName: String
    ) -> [SymbolGraph.Symbol.DeclarationFragment] {
        var fragments = typeFragments(typeName)
        fragments.append(.text(" "))
        fragments.append(.identifier(name))
        return fragments
    }
}

// MARK: - Function Signature Builder

/// Pure functions for building function signatures.
public enum FunctionSignatureBuilder {

    /// Build a function signature from return type and parameters.
    ///
    /// Pure function.
    ///
    /// - Parameters:
    ///   - returnType: The return type string.
    ///   - parameters: Array of (name, type) tuples.
    /// - Returns: Function signature or nil if no meaningful data.
    public static func buildSignature(
        returnType: String,
        parameters: [(name: String, type: String)]
    ) -> SymbolGraph.Symbol.FunctionSignature? {
        let returnFragments = DeclarationFragmentBuilder.typeFragments(returnType)

        let params: [SymbolGraph.Symbol.FunctionSignature.Parameter]? =
            parameters.isEmpty
            ? nil
            : parameters.map { param in
                SymbolGraph.Symbol.FunctionSignature.Parameter(
                    name: param.name,
                    declarationFragments: DeclarationFragmentBuilder.typeFragments(param.type)
                )
            }

        return SymbolGraph.Symbol.FunctionSignature(
            returns: returnFragments,
            parameters: params
        )
    }

    /// Build a function signature from a method selector and types.
    ///
    /// Pure function that parses selector parts for parameter names.
    ///
    /// - Parameters:
    ///   - selector: The method selector.
    ///   - returnType: The return type string.
    ///   - parameterTypes: Array of parameter type strings.
    /// - Returns: Function signature or nil if no meaningful data.
    public static func buildFromSelector(
        selector: String,
        returnType: String,
        parameterTypes: [String]
    ) -> SymbolGraph.Symbol.FunctionSignature? {
        let selectorParts = selector.split(separator: ":", omittingEmptySubsequences: false)
            .dropLast()
            .map(String.init)

        let parameters: [(name: String, type: String)] = zip(selectorParts, parameterTypes)
            .map { (name: $0, type: $1) }

        return buildSignature(returnType: returnType, parameters: parameters)
    }
}
