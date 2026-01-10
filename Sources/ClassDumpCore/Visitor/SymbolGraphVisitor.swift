// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

// MARK: - Symbol Graph Data Structures

/// Root structure for Symbol Graph output (DocC compatible).
///
/// A Symbol Graph models a module as a directed graph where nodes are symbols
/// (declarations) and edges are relationships between symbols.
///
/// Reference: https://github.com/swiftlang/swift-docc-symbolkit
public struct SymbolGraph: Codable, Sendable {
    /// Metadata about this symbol graph file.
    public let metadata: Metadata

    /// The module this symbol graph describes.
    public let module: Module

    /// Array of symbol nodes in the graph.
    public let symbols: [Symbol]

    /// Array of relationship edges in the graph.
    public let relationships: [Relationship]

    // MARK: - Nested Types

    /// Metadata about the symbol graph.
    public struct Metadata: Codable, Sendable {
        /// Format version of the symbol graph.
        public let formatVersion: SemanticVersion

        /// Name of the tool that generated this graph.
        public let generator: String
    }

    /// Semantic version for format versioning.
    public struct SemanticVersion: Codable, Sendable {
        public let major: Int
        public let minor: Int
        public let patch: Int
    }

    /// Module information.
    public struct Module: Codable, Sendable {
        /// Name of the module.
        public let name: String

        /// Platform information.
        public let platform: Platform

        /// Optional bystander modules.
        public let bystanders: [String]?
    }

    /// Platform information.
    public struct Platform: Codable, Sendable {
        /// Operating system name (e.g., "macosx", "ios").
        public let operatingSystem: OperatingSystem?

        /// CPU architecture (e.g., "arm64", "x86_64").
        public let architecture: String?

        /// SDK/vendor name.
        public let vendor: String?

        /// OS information.
        public struct OperatingSystem: Codable, Sendable {
            /// OS name.
            public let name: String

            /// Minimum deployment version.
            public let minimumVersion: SemanticVersion?
        }
    }
}

// MARK: - Symbol

extension SymbolGraph {
    /// A symbol (declaration node) in the graph.
    public struct Symbol: Codable, Sendable {
        /// Unique identifier for this symbol.
        public let identifier: Identifier

        /// Kind of symbol (class, method, property, etc.).
        public let kind: Kind

        /// Path components for documentation navigation.
        public let pathComponents: [String]

        /// Display names for the symbol.
        public let names: Names

        /// Documentation comment, if available.
        public let docComment: DocComment?

        /// Access level (public, internal, private, etc.).
        public let accessLevel: String

        /// Declaration fragments for syntax highlighting.
        public let declarationFragments: [DeclarationFragment]?

        /// Function signature for callable symbols.
        public let functionSignature: FunctionSignature?

        /// Symbol identifier with precise name and language.
        public struct Identifier: Codable, Sendable {
            /// Unique precise identifier (may be mangled).
            public let precise: String

            /// Interface language ("objective-c" or "swift").
            public let interfaceLanguage: String
        }

        /// Symbol kind with identifier and display name.
        public struct Kind: Codable, Sendable {
            /// Kind identifier (e.g., "class", "method", "property").
            public let identifier: String

            /// Human-readable display name.
            public let displayName: String
        }

        /// Display names for various contexts.
        public struct Names: Codable, Sendable {
            /// Title for documentation pages.
            public let title: String

            /// Fragments for navigator display.
            public let navigator: [DeclarationFragment]?

            /// Fragments for subheading display.
            public let subHeading: [DeclarationFragment]?
        }

        /// Documentation comment structure.
        public struct DocComment: Codable, Sendable {
            /// Lines of the documentation comment.
            public let lines: [Line]

            /// A single line in the comment.
            public struct Line: Codable, Sendable {
                /// The text of the line.
                public let text: String
            }
        }

        /// A fragment of a declaration for syntax highlighting.
        public struct DeclarationFragment: Codable, Sendable {
            /// Kind of fragment for coloring.
            public let kind: String

            /// The text content.
            public let spelling: String

            /// Precise identifier for linking (typeIdentifier only).
            public let preciseIdentifier: String?
        }

        /// Function signature for methods and functions.
        public struct FunctionSignature: Codable, Sendable {
            /// Return type fragments.
            public let returns: [DeclarationFragment]?

            /// Parameters of the function.
            public let parameters: [Parameter]?

            /// A function parameter.
            public struct Parameter: Codable, Sendable {
                /// Parameter name.
                public let name: String

                /// Declaration fragments for the parameter type.
                public let declarationFragments: [DeclarationFragment]
            }
        }
    }
}

// MARK: - Relationship

extension SymbolGraph {
    /// A relationship (edge) between two symbols.
    public struct Relationship: Codable, Sendable {
        /// Precise identifier of the source symbol.
        public let source: String

        /// Precise identifier of the target symbol.
        public let target: String

        /// Kind of relationship.
        public let kind: String

        /// Fallback name for target if not in graph.
        public let targetFallback: String?
    }
}

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

// MARK: - Declaration Fragment Kind Constants

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

// MARK: - Symbol Graph Merging

extension SymbolGraph {
    /// Merge multiple symbol graphs into a single unified graph.
    ///
    /// This is useful when processing multiple frameworks or binaries
    /// and generating a combined documentation set.
    ///
    /// - Parameters:
    ///   - graphs: The symbol graphs to merge.
    ///   - moduleName: The name for the merged module (defaults to "Combined").
    ///   - platform: Platform info for the merged graph.
    /// - Returns: A new SymbolGraph containing all symbols and relationships.
    public static func merge(
        _ graphs: [SymbolGraph],
        moduleName: String = "Combined",
        platform: Platform? = nil
    ) -> SymbolGraph {
        guard !graphs.isEmpty else {
            return SymbolGraph(
                metadata: Metadata(
                    formatVersion: SemanticVersion(major: 0, minor: 6, patch: 0),
                    generator: "class-dump"
                ),
                module: Module(
                    name: moduleName,
                    platform: platform
                        ?? Platform(
                            operatingSystem: nil,
                            architecture: nil,
                            vendor: "apple"
                        ),
                    bystanders: nil
                ),
                symbols: [],
                relationships: []
            )
        }

        // Collect unique symbols by precise identifier
        var symbolsByIdentifier: [String: Symbol] = [:]
        var allRelationships: [Relationship] = []
        var seenRelationships: Set<String> = []
        var bystanderModules: Set<String> = []

        for graph in graphs {
            // Track bystander modules (all modules except the merged one)
            bystanderModules.insert(graph.module.name)

            // Add symbols, preferring the first occurrence
            for symbol in graph.symbols {
                let key = symbol.identifier.precise
                if symbolsByIdentifier[key] == nil {
                    symbolsByIdentifier[key] = symbol
                }
            }

            // Add relationships, deduplicating
            for rel in graph.relationships {
                let key = "\(rel.source)|\(rel.target)|\(rel.kind)"
                if !seenRelationships.contains(key) {
                    seenRelationships.insert(key)
                    allRelationships.append(rel)
                }
            }
        }

        // Use the first graph's platform if not provided
        let resolvedPlatform =
            platform ?? graphs.first?.module.platform
            ?? Platform(
                operatingSystem: nil,
                architecture: nil,
                vendor: "apple"
            )

        return SymbolGraph(
            metadata: Metadata(
                formatVersion: SemanticVersion(major: 0, minor: 6, patch: 0),
                generator: "class-dump"
            ),
            module: Module(
                name: moduleName,
                platform: resolvedPlatform,
                bystanders: bystanderModules.sorted()
            ),
            symbols: Array(symbolsByIdentifier.values)
                .sorted {
                    $0.identifier.precise < $1.identifier.precise
                },
            relationships: allRelationships.sorted {
                ($0.source, $0.target, $0.kind) < ($1.source, $1.target, $1.kind)
            }
        )
    }

    /// Merge this symbol graph with another.
    ///
    /// - Parameter other: The symbol graph to merge with.
    /// - Returns: A new merged SymbolGraph.
    public func merging(with other: SymbolGraph) -> SymbolGraph {
        Self.merge([self, other], moduleName: self.module.name, platform: self.module.platform)
    }
}

// MARK: - Symbol Graph JSON Utilities

extension SymbolGraph {
    /// Encode this symbol graph to JSON data.
    ///
    /// - Parameter prettyPrint: Whether to format the JSON for readability (default: true).
    /// - Returns: JSON data representation of the symbol graph.
    /// - Throws: Encoding errors if the graph cannot be serialized.
    public func jsonData(prettyPrint: Bool = true) throws -> Data {
        let encoder = JSONEncoder()
        if prettyPrint {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        else {
            encoder.outputFormatting = [.sortedKeys]
        }
        return try encoder.encode(self)
    }

    /// Encode this symbol graph to a JSON string.
    ///
    /// - Parameter prettyPrint: Whether to format the JSON for readability (default: true).
    /// - Returns: JSON string representation of the symbol graph.
    /// - Throws: Encoding errors if the graph cannot be serialized.
    public func jsonString(prettyPrint: Bool = true) throws -> String {
        let data = try jsonData(prettyPrint: prettyPrint)
        guard let string = String(data: data, encoding: .utf8) else {
            throw EncodingError.invalidValue(
                self,
                EncodingError.Context(
                    codingPath: [],
                    debugDescription: "Failed to convert JSON data to UTF-8 string"
                )
            )
        }
        return string
    }

    /// Load a symbol graph from JSON data.
    ///
    /// - Parameter data: JSON data to decode.
    /// - Returns: A decoded SymbolGraph.
    /// - Throws: Decoding errors if the data is invalid.
    public static func from(jsonData data: Data) throws -> SymbolGraph {
        let decoder = JSONDecoder()
        return try decoder.decode(SymbolGraph.self, from: data)
    }

    /// Load a symbol graph from a file URL.
    ///
    /// - Parameter url: URL to the symbol graph JSON file.
    /// - Returns: A decoded SymbolGraph.
    /// - Throws: File or decoding errors.
    public static func from(url: URL) throws -> SymbolGraph {
        let data = try Data(contentsOf: url)
        return try from(jsonData: data)
    }

    /// Write this symbol graph to a file.
    ///
    /// - Parameters:
    ///   - url: Destination URL for the JSON file.
    ///   - prettyPrint: Whether to format the JSON for readability (default: true).
    /// - Throws: Encoding or file system errors.
    public func write(to url: URL, prettyPrint: Bool = true) throws {
        let data = try jsonData(prettyPrint: prettyPrint)
        try data.write(to: url, options: .atomic)
    }

    /// Generate the recommended filename for this symbol graph.
    ///
    /// Following Apple's naming convention: `{module}.symbols.json`
    /// For extension graphs: `{module}@{extended-module}.symbols.json`
    ///
    /// - Parameter extendedModule: If this graph contains extensions to another module.
    /// - Returns: The recommended filename.
    public func recommendedFilename(extendedModule: String? = nil) -> String {
        if let extended = extendedModule {
            return "\(module.name)@\(extended).symbols.json"
        }
        return "\(module.name).symbols.json"
    }
}

// MARK: - Symbol Graph Visitor

/// A visitor that generates DocC-compatible Symbol Graph JSON output.
///
/// This visitor collects ObjC metadata and outputs it in the Symbol Graph format
/// used by DocC for documentation generation. The output can be consumed by
/// `docc` or other tools that support the Symbol Graph format.
///
/// ## Example Usage
///
/// ```swift
/// let visitor = SymbolGraphVisitor()
/// processor.acceptVisitor(visitor)
/// // visitor.resultString contains Symbol Graph JSON
/// ```
///
/// ## Output Format
///
/// The visitor generates JSON conforming to the Symbol Graph format:
/// ```json
/// {
///   "metadata": { "formatVersion": {...}, "generator": "class-dump" },
///   "module": { "name": "MyFramework", "platform": {...} },
///   "symbols": [...],
///   "relationships": [...]
/// }
/// ```
public final class SymbolGraphVisitor: ClassDumpVisitor, @unchecked Sendable {
    /// The accumulated result string.
    public var resultString: String = ""

    /// Visitor options.
    public var options: ClassDumpVisitorOptions

    /// Type formatter for generating type strings.
    public var typeFormatter: ObjCTypeFormatter

    /// Header string (unused for Symbol Graph, but required by protocol).
    public var headerString: String = ""

    // MARK: - Module Info

    private var moduleName: String = "Module"
    private var platform: SymbolGraph.Platform?

    // MARK: - Collected Data

    private var symbols: [SymbolGraph.Symbol] = []
    private var relationships: [SymbolGraph.Relationship] = []

    // MARK: - Current Context

    private var currentProtocol: ObjCProtocol?
    private var currentClass: ObjCClass?
    private var currentCategory: ObjCCategory?
    private var inOptionalSection = false

    /// Initialize a Symbol Graph output visitor.
    ///
    /// - Parameter options: Visitor options for formatting.
    public init(options: ClassDumpVisitorOptions = .init()) {
        self.options = options

        var formatterOptions = ObjCTypeFormatterOptions()
        formatterOptions.demangleStyle = options.demangleStyle
        self.typeFormatter = ObjCTypeFormatter(options: formatterOptions)
    }

    // MARK: - Helpers

    private func demangle(_ name: String) -> String {
        switch options.demangleStyle {
            case .none:
                return name
            case .swift:
                return SwiftDemangler.demangleSwiftName(name)
            case .objc:
                let demangled = SwiftDemangler.demangleSwiftName(name)
                if let lastDot = demangled.lastIndex(of: ".") {
                    return String(demangled[demangled.index(after: lastDot)...])
                }
                return demangled
        }
    }

    /// Generate a precise identifier for a symbol.
    private func preciseIdentifier(for name: String, inModule module: String = "") -> String {
        // Use c: prefix for ObjC symbols
        "c:objc(cs)\(name)"
    }

    /// Generate a precise identifier for a protocol.
    private func protocolIdentifier(_ name: String) -> String {
        "c:objc(pl)\(name)"
    }

    /// Generate a precise identifier for a method.
    private func methodIdentifier(
        selector: String,
        isClassMethod: Bool,
        parentName: String,
        isProtocol: Bool
    ) -> String {
        let parentPrefix = isProtocol ? "pl" : "cs"
        let methodPrefix = isClassMethod ? "cm" : "im"
        return "c:objc(\(parentPrefix))\(parentName)(\(methodPrefix))\(selector)"
    }

    /// Generate a precise identifier for a property.
    private func propertyIdentifier(name: String, parentName: String, isProtocol: Bool) -> String {
        let parentPrefix = isProtocol ? "pl" : "cs"
        return "c:objc(\(parentPrefix))\(parentName)(py)\(name)"
    }

    /// Generate a precise identifier for an ivar.
    private func ivarIdentifier(name: String, className: String) -> String {
        "c:objc(cs)\(className)(ivar)\(name)"
    }

    /// Build declaration fragments for a type.
    private func typeFragments(_ typeName: String) -> [SymbolGraph.Symbol.DeclarationFragment] {
        // Check if it's a pointer type
        if typeName.hasSuffix("*") {
            let baseType = String(typeName.dropLast()).trimmingCharacters(in: .whitespaces)
            return [
                .typeIdentifier(baseType, preciseIdentifier: preciseIdentifier(for: baseType)),
                .text(" *"),
            ]
        }
        return [.typeIdentifier(typeName)]
    }

    /// Build declaration fragments for a method.
    private func methodDeclarationFragments(
        _ method: ObjCMethod,
        isClassMethod: Bool
    ) -> [SymbolGraph.Symbol.DeclarationFragment] {
        var fragments: [SymbolGraph.Symbol.DeclarationFragment] = []

        // Method type indicator
        fragments.append(.text(isClassMethod ? "+ " : "- "))

        // Return type
        if let methodTypes = try? ObjCType.parseMethodType(method.typeString), !methodTypes.isEmpty {
            let returnType = typeFormatter.formatVariable(name: nil, type: methodTypes[0].type)
            fragments.append(.text("("))
            fragments.append(contentsOf: typeFragments(returnType))
            fragments.append(.text(")"))
        }
        else {
            fragments.append(.text("(id)"))
        }

        // Selector and parameters
        let selectorParts = method.name.split(separator: ":", omittingEmptySubsequences: false)
        if selectorParts.count <= 1 {
            // Simple selector without parameters
            fragments.append(.identifier(method.name))
        }
        else {
            // Selector with parameters
            if let methodTypes = try? ObjCType.parseMethodType(method.typeString), methodTypes.count > 3 {
                for (i, part) in selectorParts.dropLast().enumerated() {
                    if i > 0 {
                        fragments.append(.text(" "))
                    }
                    fragments.append(.identifier(String(part)))
                    fragments.append(.text(":"))

                    // Parameter type
                    let paramIndex = i + 3  // Skip return, self, _cmd
                    if paramIndex < methodTypes.count {
                        let paramType = typeFormatter.formatVariable(
                            name: nil,
                            type: methodTypes[paramIndex].type
                        )
                        fragments.append(.text("("))
                        fragments.append(contentsOf: typeFragments(paramType))
                        fragments.append(.text(")"))
                    }
                    else {
                        fragments.append(.text("(id)"))
                    }
                    fragments.append(.identifier("arg\(i)"))
                }
            }
            else {
                // Fallback without type info
                for (i, part) in selectorParts.dropLast().enumerated() {
                    if i > 0 {
                        fragments.append(.text(" "))
                    }
                    fragments.append(.identifier(String(part)))
                    fragments.append(.text(":(id)arg\(i)"))
                }
            }
        }

        return fragments
    }

    /// Build function signature for a method.
    private func methodFunctionSignature(_ method: ObjCMethod) -> SymbolGraph.Symbol.FunctionSignature? {
        guard let methodTypes = try? ObjCType.parseMethodType(method.typeString), !methodTypes.isEmpty else {
            return nil
        }

        // Return type
        let returnType = typeFormatter.formatVariable(name: nil, type: methodTypes[0].type)
        let returnFragments = typeFragments(returnType)

        // Parameters (skip self, _cmd)
        var parameters: [SymbolGraph.Symbol.FunctionSignature.Parameter] = []
        let selectorParts = method.name.split(separator: ":", omittingEmptySubsequences: false)

        for i in 3..<methodTypes.count {
            let paramType = typeFormatter.formatVariable(name: nil, type: methodTypes[i].type)
            let paramName = i - 3 < selectorParts.count ? String(selectorParts[i - 3]) : "arg\(i - 3)"
            parameters.append(
                SymbolGraph.Symbol.FunctionSignature.Parameter(
                    name: paramName,
                    declarationFragments: typeFragments(paramType)
                )
            )
        }

        return SymbolGraph.Symbol.FunctionSignature(
            returns: returnFragments,
            parameters: parameters.isEmpty ? nil : parameters
        )
    }

    /// Build declaration fragments for a property.
    private func propertyDeclarationFragments(
        _ property: ObjCProperty
    ) -> [SymbolGraph.Symbol.DeclarationFragment] {
        var fragments: [SymbolGraph.Symbol.DeclarationFragment] = []

        fragments.append(.attribute("@property"))
        fragments.append(.text(" "))

        // Property attributes
        var attrs: [String] = []
        if property.isNonatomic {
            attrs.append("nonatomic")
        }
        if property.isReadOnly {
            attrs.append("readonly")
        }
        if property.isCopy {
            attrs.append("copy")
        }
        if property.isWeak {
            attrs.append("weak")
        }
        else if property.isRetain {
            attrs.append("strong")
        }

        if !attrs.isEmpty {
            fragments.append(.text("(\(attrs.joined(separator: ", "))) "))
        }

        // Type
        if let parsedType = property.parsedType {
            let typeStr = typeFormatter.formatVariable(name: nil, type: parsedType)
            fragments.append(contentsOf: typeFragments(typeStr))
            fragments.append(.text(" "))
        }
        else {
            fragments.append(.text("id "))
        }

        // Name
        fragments.append(.identifier(property.name))

        return fragments
    }

    // MARK: - Output

    /// Write the result to standard output.
    public func writeResultToStandardOutput() {
        if let data = resultString.data(using: .utf8) {
            FileHandle.standardOutput.write(data)
        }
    }

    // MARK: - Lifecycle

    /// Called when visiting begins, resets state.
    public func willBeginVisiting() {
        symbols = []
        relationships = []
        moduleName = "Module"
        platform = nil
    }

    /// Called when visiting ends, encodes and outputs Symbol Graph JSON.
    public func didEndVisiting() {
        let graph = SymbolGraph(
            metadata: SymbolGraph.Metadata(
                formatVersion: SymbolGraph.SemanticVersion(major: 0, minor: 6, patch: 0),
                generator: "class-dump"
            ),
            module: SymbolGraph.Module(
                name: moduleName,
                platform: platform
                    ?? SymbolGraph.Platform(
                        operatingSystem: nil,
                        architecture: nil,
                        vendor: "apple"
                    ),
                bystanders: nil
            ),
            symbols: symbols,
            relationships: relationships
        )

        // Encode to JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let data = try encoder.encode(graph)
            resultString = String(data: data, encoding: .utf8) ?? "{}"
        }
        catch {
            resultString = "{\"error\": \"Failed to encode Symbol Graph: \(error.localizedDescription)\"}"
        }

        writeResultToStandardOutput()
    }

    // MARK: - Processor Visits

    /// Called before visiting a processor, sets up module info.
    public func willVisitProcessor(_ processor: ObjCProcessorInfo) {
        if let structureRegistry = processor.structureRegistry {
            typeFormatter.structureRegistry = structureRegistry
        }
        if let methodSignatureRegistry = processor.methodSignatureRegistry {
            typeFormatter.methodSignatureRegistry = methodSignatureRegistry
        }

        let machO = processor.machOFile

        // Extract module name from filename
        moduleName =
            URL(fileURLWithPath: machO.filename)
            .deletingPathExtension()
            .lastPathComponent

        // Build platform info
        var osInfo: SymbolGraph.Platform.OperatingSystem?

        if let macVersion = machO.minMacOSVersion {
            let parts = macVersion.split(separator: ".")
            let major = parts.count > 0 ? Int(parts[0]) ?? 10 : 10
            let minor = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
            let patch = parts.count > 2 ? Int(parts[2]) ?? 0 : 0
            osInfo = SymbolGraph.Platform.OperatingSystem(
                name: "macosx",
                minimumVersion: SymbolGraph.SemanticVersion(major: major, minor: minor, patch: patch)
            )
        }
        else if let iosVersion = machO.minIOSVersion {
            let parts = iosVersion.split(separator: ".")
            let major = parts.count > 0 ? Int(parts[0]) ?? 14 : 14
            let minor = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
            let patch = parts.count > 2 ? Int(parts[2]) ?? 0 : 0
            osInfo = SymbolGraph.Platform.OperatingSystem(
                name: "ios",
                minimumVersion: SymbolGraph.SemanticVersion(major: major, minor: minor, patch: patch)
            )
        }

        platform = SymbolGraph.Platform(
            operatingSystem: osInfo,
            architecture: machO.archName,
            vendor: "apple"
        )
    }

    /// Called to visit processor info.
    public func visitProcessor(_ processor: ObjCProcessorInfo) {}

    /// Called after visiting a processor.
    public func didVisitProcessor(_ processor: ObjCProcessorInfo) {}

    // MARK: - Protocol Visits

    /// Called before visiting a protocol, initializes state.
    public func willVisitProtocol(_ proto: ObjCProtocol) {
        currentProtocol = proto
        inOptionalSection = false
    }

    /// Called after visiting a protocol, builds and stores protocol symbol.
    public func didVisitProtocol(_ proto: ObjCProtocol) {
        let displayName = demangle(proto.name)
        let preciseId = protocolIdentifier(displayName)

        // Build declaration fragments
        var declFragments: [SymbolGraph.Symbol.DeclarationFragment] = [
            .keyword("@protocol"),
            .text(" "),
            .identifier(displayName),
        ]

        if !proto.protocols.isEmpty {
            declFragments.append(.text(" <"))
            for (i, adopted) in proto.protocols.enumerated() {
                if i > 0 {
                    declFragments.append(.text(", "))
                }
                let adoptedName = demangle(adopted)
                declFragments.append(.typeIdentifier(adoptedName, preciseIdentifier: protocolIdentifier(adoptedName)))
            }
            declFragments.append(.text(">"))
        }

        let symbol = SymbolGraph.Symbol(
            identifier: SymbolGraph.Symbol.Identifier(
                precise: preciseId,
                interfaceLanguage: "objective-c"
            ),
            kind: .objcProtocol,
            pathComponents: [displayName],
            names: SymbolGraph.Symbol.Names(
                title: displayName,
                navigator: [.identifier(displayName)],
                subHeading: [.identifier(displayName)]
            ),
            docComment: nil,
            accessLevel: "public",
            declarationFragments: declFragments,
            functionSignature: nil
        )

        symbols.append(symbol)

        // Add conformsTo relationships for adopted protocols
        for adopted in proto.protocols {
            let adoptedName = demangle(adopted)
            relationships.append(
                SymbolGraph.Relationship(
                    source: preciseId,
                    target: protocolIdentifier(adoptedName),
                    kind: SymbolGraph.Relationship.conformsToKind,
                    targetFallback: adoptedName
                )
            )
        }

        currentProtocol = nil
    }

    /// Called before visiting protocol properties.
    public func willVisitPropertiesOfProtocol(_ proto: ObjCProtocol) {}

    /// Called after visiting protocol properties.
    public func didVisitPropertiesOfProtocol(_ proto: ObjCProtocol) {}

    /// Called when entering optional methods section.
    public func willVisitOptionalMethods() {
        inOptionalSection = true
    }

    /// Called when leaving optional methods section.
    public func didVisitOptionalMethods() {
        inOptionalSection = false
    }

    // MARK: - Class Visits

    /// Called before visiting a class, initializes state.
    public func willVisitClass(_ objcClass: ObjCClass) {
        currentClass = objcClass
    }

    /// Called after visiting a class, builds and stores class symbol.
    public func didVisitClass(_ objcClass: ObjCClass) {
        let displayName = demangle(objcClass.name)
        let preciseId = preciseIdentifier(for: displayName)

        // Build declaration fragments
        var declFragments: [SymbolGraph.Symbol.DeclarationFragment] = [
            .keyword("@interface"),
            .text(" "),
            .identifier(displayName),
        ]

        if let superclass = objcClass.superclassName {
            let superName = demangle(superclass)
            declFragments.append(.text(" : "))
            declFragments.append(.typeIdentifier(superName, preciseIdentifier: preciseIdentifier(for: superName)))
        }

        if !objcClass.protocols.isEmpty {
            declFragments.append(.text(" <"))
            for (i, proto) in objcClass.protocols.enumerated() {
                if i > 0 {
                    declFragments.append(.text(", "))
                }
                let protoName = demangle(proto)
                declFragments.append(.typeIdentifier(protoName, preciseIdentifier: protocolIdentifier(protoName)))
            }
            declFragments.append(.text(">"))
        }

        let symbol = SymbolGraph.Symbol(
            identifier: SymbolGraph.Symbol.Identifier(
                precise: preciseId,
                interfaceLanguage: "objective-c"
            ),
            kind: .objcClass,
            pathComponents: [displayName],
            names: SymbolGraph.Symbol.Names(
                title: displayName,
                navigator: [.identifier(displayName)],
                subHeading: [.identifier(displayName)]
            ),
            docComment: nil,
            accessLevel: objcClass.isExported ? "public" : "internal",
            declarationFragments: declFragments,
            functionSignature: nil
        )

        symbols.append(symbol)

        // Add inheritsFrom relationship for superclass
        if let superclass = objcClass.superclassName {
            let superName = demangle(superclass)
            relationships.append(
                SymbolGraph.Relationship(
                    source: preciseId,
                    target: preciseIdentifier(for: superName),
                    kind: SymbolGraph.Relationship.inheritsFromKind,
                    targetFallback: superName
                )
            )
        }

        // Add conformsTo relationships for protocols
        for proto in objcClass.protocols {
            let protoName = demangle(proto)
            relationships.append(
                SymbolGraph.Relationship(
                    source: preciseId,
                    target: protocolIdentifier(protoName),
                    kind: SymbolGraph.Relationship.conformsToKind,
                    targetFallback: protoName
                )
            )
        }

        currentClass = nil
    }

    /// Called before visiting instance variables.
    public func willVisitIvarsOfClass(_ objcClass: ObjCClass) {}

    /// Called after visiting instance variables.
    public func didVisitIvarsOfClass(_ objcClass: ObjCClass) {}

    /// Called before visiting class properties.
    public func willVisitPropertiesOfClass(_ objcClass: ObjCClass) {}

    /// Called after visiting class properties.
    public func didVisitPropertiesOfClass(_ objcClass: ObjCClass) {}

    // MARK: - Category Visits

    /// Called before visiting a category, initializes state.
    public func willVisitCategory(_ category: ObjCCategory) {
        currentCategory = category
    }

    /// Called after visiting a category.
    public func didVisitCategory(_ category: ObjCCategory) {
        // Categories are represented as extensions to the base class
        // We don't create a separate symbol for the category itself,
        // but the methods/properties get added with memberOf to the base class
        currentCategory = nil
    }

    /// Called before visiting category properties.
    public func willVisitPropertiesOfCategory(_ category: ObjCCategory) {}

    /// Called after visiting category properties.
    public func didVisitPropertiesOfCategory(_ category: ObjCCategory) {}

    // MARK: - Member Visits

    /// Records a class method in the appropriate context.
    public func visitClassMethod(_ method: ObjCMethod) {
        let parentName: String
        let parentId: String
        let isProtocol: Bool

        if let proto = currentProtocol {
            parentName = demangle(proto.name)
            parentId = protocolIdentifier(parentName)
            isProtocol = true
        }
        else if let cls = currentClass {
            parentName = demangle(cls.name)
            parentId = preciseIdentifier(for: parentName)
            isProtocol = false
        }
        else if let cat = currentCategory {
            parentName = demangle(cat.classNameForVisitor)
            parentId = preciseIdentifier(for: parentName)
            isProtocol = false
        }
        else {
            return
        }

        let methodId = methodIdentifier(
            selector: method.name,
            isClassMethod: true,
            parentName: parentName,
            isProtocol: isProtocol
        )

        let symbol = SymbolGraph.Symbol(
            identifier: SymbolGraph.Symbol.Identifier(
                precise: methodId,
                interfaceLanguage: "objective-c"
            ),
            kind: .typeMethod,
            pathComponents: [parentName, method.name],
            names: SymbolGraph.Symbol.Names(
                title: method.name,
                navigator: [.identifier(method.name)],
                subHeading: [.text("+"), .identifier(method.name)]
            ),
            docComment: nil,
            accessLevel: "public",
            declarationFragments: methodDeclarationFragments(method, isClassMethod: true),
            functionSignature: methodFunctionSignature(method)
        )

        symbols.append(symbol)

        // Add relationship
        let relationshipKind: String
        if isProtocol {
            relationshipKind =
                inOptionalSection
                ? SymbolGraph.Relationship.optionalRequirementOfKind
                : SymbolGraph.Relationship.requirementOfKind
        }
        else {
            relationshipKind = SymbolGraph.Relationship.memberOfKind
        }

        relationships.append(
            SymbolGraph.Relationship(
                source: methodId,
                target: parentId,
                kind: relationshipKind,
                targetFallback: nil
            )
        )
    }

    /// Records an instance method in the appropriate context, skipping property accessors.
    public func visitInstanceMethod(_ method: ObjCMethod, propertyState: VisitorPropertyState) {
        // Skip property accessors
        if propertyState.property(forAccessor: method.name) != nil {
            return
        }

        let parentName: String
        let parentId: String
        let isProtocol: Bool

        if let proto = currentProtocol {
            parentName = demangle(proto.name)
            parentId = protocolIdentifier(parentName)
            isProtocol = true
        }
        else if let cls = currentClass {
            parentName = demangle(cls.name)
            parentId = preciseIdentifier(for: parentName)
            isProtocol = false
        }
        else if let cat = currentCategory {
            parentName = demangle(cat.classNameForVisitor)
            parentId = preciseIdentifier(for: parentName)
            isProtocol = false
        }
        else {
            return
        }

        let methodId = methodIdentifier(
            selector: method.name,
            isClassMethod: false,
            parentName: parentName,
            isProtocol: isProtocol
        )

        let symbol = SymbolGraph.Symbol(
            identifier: SymbolGraph.Symbol.Identifier(
                precise: methodId,
                interfaceLanguage: "objective-c"
            ),
            kind: .instanceMethod,
            pathComponents: [parentName, method.name],
            names: SymbolGraph.Symbol.Names(
                title: method.name,
                navigator: [.identifier(method.name)],
                subHeading: [.text("-"), .identifier(method.name)]
            ),
            docComment: nil,
            accessLevel: "public",
            declarationFragments: methodDeclarationFragments(method, isClassMethod: false),
            functionSignature: methodFunctionSignature(method)
        )

        symbols.append(symbol)

        // Add relationship
        let relationshipKind: String
        if isProtocol {
            relationshipKind =
                inOptionalSection
                ? SymbolGraph.Relationship.optionalRequirementOfKind
                : SymbolGraph.Relationship.requirementOfKind
        }
        else {
            relationshipKind = SymbolGraph.Relationship.memberOfKind
        }

        relationships.append(
            SymbolGraph.Relationship(
                source: methodId,
                target: parentId,
                kind: relationshipKind,
                targetFallback: nil
            )
        )
    }

    /// Records an instance variable.
    public func visitIvar(_ ivar: ObjCInstanceVariable) {
        guard let cls = currentClass else { return }

        let className = demangle(cls.name)
        let classId = preciseIdentifier(for: className)
        let ivarId = ivarIdentifier(name: ivar.name, className: className)

        var typeFragments: [SymbolGraph.Symbol.DeclarationFragment] = []
        if let parsed = ivar.parsedType {
            let typeStr = typeFormatter.formatVariable(name: nil, type: parsed)
            typeFragments = self.typeFragments(typeStr)
        }
        else {
            typeFragments = [.typeIdentifier("id")]
        }

        var declFragments: [SymbolGraph.Symbol.DeclarationFragment] = typeFragments
        declFragments.append(.text(" "))
        declFragments.append(.identifier(ivar.name))

        let symbol = SymbolGraph.Symbol(
            identifier: SymbolGraph.Symbol.Identifier(
                precise: ivarId,
                interfaceLanguage: "objective-c"
            ),
            kind: .ivar,
            pathComponents: [className, ivar.name],
            names: SymbolGraph.Symbol.Names(
                title: ivar.name,
                navigator: [.identifier(ivar.name)],
                subHeading: nil
            ),
            docComment: nil,
            accessLevel: "internal",
            declarationFragments: declFragments,
            functionSignature: nil
        )

        symbols.append(symbol)

        relationships.append(
            SymbolGraph.Relationship(
                source: ivarId,
                target: classId,
                kind: SymbolGraph.Relationship.memberOfKind,
                targetFallback: nil
            )
        )
    }

    /// Records a property in the appropriate context.
    public func visitProperty(_ property: ObjCProperty) {
        let parentName: String
        let parentId: String
        let isProtocol: Bool

        if let proto = currentProtocol {
            parentName = demangle(proto.name)
            parentId = protocolIdentifier(parentName)
            isProtocol = true
        }
        else if let cls = currentClass {
            parentName = demangle(cls.name)
            parentId = preciseIdentifier(for: parentName)
            isProtocol = false
        }
        else if let cat = currentCategory {
            parentName = demangle(cat.classNameForVisitor)
            parentId = preciseIdentifier(for: parentName)
            isProtocol = false
        }
        else {
            return
        }

        let propId = propertyIdentifier(name: property.name, parentName: parentName, isProtocol: isProtocol)

        let symbol = SymbolGraph.Symbol(
            identifier: SymbolGraph.Symbol.Identifier(
                precise: propId,
                interfaceLanguage: "objective-c"
            ),
            kind: .property,
            pathComponents: [parentName, property.name],
            names: SymbolGraph.Symbol.Names(
                title: property.name,
                navigator: [.identifier(property.name)],
                subHeading: [.identifier(property.name)]
            ),
            docComment: nil,
            accessLevel: "public",
            declarationFragments: propertyDeclarationFragments(property),
            functionSignature: nil
        )

        symbols.append(symbol)

        // Add relationship
        let relationshipKind =
            isProtocol
            ? SymbolGraph.Relationship.requirementOfKind
            : SymbolGraph.Relationship.memberOfKind

        relationships.append(
            SymbolGraph.Relationship(
                source: propId,
                target: parentId,
                kind: relationshipKind,
                targetFallback: nil
            )
        )
    }

    /// Called to output any remaining properties not covered by instance methods.
    public func visitRemainingProperties(_ propertyState: VisitorPropertyState) {}
}
