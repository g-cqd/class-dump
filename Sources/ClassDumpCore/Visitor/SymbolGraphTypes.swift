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

    /// Initialize a symbol graph.
    public init(
        metadata: Metadata,
        module: Module,
        symbols: [Symbol],
        relationships: [Relationship]
    ) {
        self.metadata = metadata
        self.module = module
        self.symbols = symbols
        self.relationships = relationships
    }
}

// MARK: - Metadata

extension SymbolGraph {
    /// Metadata about the symbol graph.
    public struct Metadata: Codable, Sendable {
        /// Format version of the symbol graph.
        public let formatVersion: SemanticVersion

        /// Name of the tool that generated this graph.
        public let generator: String

        /// Initialize metadata.
        public init(formatVersion: SemanticVersion, generator: String) {
            self.formatVersion = formatVersion
            self.generator = generator
        }
    }

    /// Semantic version for format versioning.
    public struct SemanticVersion: Codable, Sendable {
        /// Major version component.
        public let major: Int
        /// Minor version component.
        public let minor: Int
        /// Patch version component.
        public let patch: Int

        /// Initialize a semantic version.
        public init(major: Int, minor: Int, patch: Int) {
            self.major = major
            self.minor = minor
            self.patch = patch
        }
    }
}

// MARK: - Module

extension SymbolGraph {
    /// Module information.
    public struct Module: Codable, Sendable {
        /// Name of the module.
        public let name: String

        /// Platform information.
        public let platform: Platform

        /// Optional bystander modules.
        public let bystanders: [String]?

        /// Initialize module info.
        public init(name: String, platform: Platform, bystanders: [String]? = nil) {
            self.name = name
            self.platform = platform
            self.bystanders = bystanders
        }
    }

    /// Platform information.
    public struct Platform: Codable, Sendable {
        /// Operating system name (e.g., "macosx", "ios").
        public let operatingSystem: OperatingSystem?

        /// CPU architecture (e.g., "arm64", "x86_64").
        public let architecture: String?

        /// SDK/vendor name.
        public let vendor: String?

        /// Initialize platform info.
        public init(
            operatingSystem: OperatingSystem? = nil,
            architecture: String? = nil,
            vendor: String? = nil
        ) {
            self.operatingSystem = operatingSystem
            self.architecture = architecture
            self.vendor = vendor
        }

        /// OS information.
        public struct OperatingSystem: Codable, Sendable {
            /// OS name.
            public let name: String

            /// Minimum deployment version.
            public let minimumVersion: SemanticVersion?

            /// Initialize OS info.
            public init(name: String, minimumVersion: SemanticVersion? = nil) {
                self.name = name
                self.minimumVersion = minimumVersion
            }
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

        /// Initialize a symbol.
        public init(
            identifier: Identifier,
            kind: Kind,
            pathComponents: [String],
            names: Names,
            docComment: DocComment? = nil,
            accessLevel: String,
            declarationFragments: [DeclarationFragment]? = nil,
            functionSignature: FunctionSignature? = nil
        ) {
            self.identifier = identifier
            self.kind = kind
            self.pathComponents = pathComponents
            self.names = names
            self.docComment = docComment
            self.accessLevel = accessLevel
            self.declarationFragments = declarationFragments
            self.functionSignature = functionSignature
        }

        /// Symbol identifier with precise name and language.
        public struct Identifier: Codable, Sendable {
            /// Unique precise identifier (may be mangled).
            public let precise: String

            /// Interface language ("objective-c" or "swift").
            public let interfaceLanguage: String

            /// Initialize an identifier.
            public init(precise: String, interfaceLanguage: String) {
                self.precise = precise
                self.interfaceLanguage = interfaceLanguage
            }
        }

        /// Symbol kind with identifier and display name.
        public struct Kind: Codable, Sendable {
            /// Kind identifier (e.g., "class", "method", "property").
            public let identifier: String

            /// Human-readable display name.
            public let displayName: String

            /// Initialize a kind.
            public init(identifier: String, displayName: String) {
                self.identifier = identifier
                self.displayName = displayName
            }
        }

        /// Display names for various contexts.
        public struct Names: Codable, Sendable {
            /// Title for documentation pages.
            public let title: String

            /// Fragments for navigator display.
            public let navigator: [DeclarationFragment]?

            /// Fragments for subheading display.
            public let subHeading: [DeclarationFragment]?

            /// Initialize names.
            public init(
                title: String,
                navigator: [DeclarationFragment]? = nil,
                subHeading: [DeclarationFragment]? = nil
            ) {
                self.title = title
                self.navigator = navigator
                self.subHeading = subHeading
            }
        }

        /// Documentation comment structure.
        public struct DocComment: Codable, Sendable {
            /// Lines of the documentation comment.
            public let lines: [Line]

            /// Initialize a doc comment.
            public init(lines: [Line]) {
                self.lines = lines
            }

            /// A single line in the comment.
            public struct Line: Codable, Sendable {
                /// The text of the line.
                public let text: String

                /// Initialize a line.
                public init(text: String) {
                    self.text = text
                }
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

            /// Initialize a fragment.
            public init(kind: String, spelling: String, preciseIdentifier: String? = nil) {
                self.kind = kind
                self.spelling = spelling
                self.preciseIdentifier = preciseIdentifier
            }
        }

        /// Function signature for methods and functions.
        public struct FunctionSignature: Codable, Sendable {
            /// Return type fragments.
            public let returns: [DeclarationFragment]?

            /// Parameters of the function.
            public let parameters: [Parameter]?

            /// Initialize a function signature.
            public init(
                returns: [DeclarationFragment]? = nil,
                parameters: [Parameter]? = nil
            ) {
                self.returns = returns
                self.parameters = parameters
            }

            /// A function parameter.
            public struct Parameter: Codable, Sendable {
                /// Parameter name.
                public let name: String

                /// Declaration fragments for the parameter type.
                public let declarationFragments: [DeclarationFragment]

                /// Initialize a parameter.
                public init(name: String, declarationFragments: [DeclarationFragment]) {
                    self.name = name
                    self.declarationFragments = declarationFragments
                }
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

        /// Initialize a relationship.
        public init(
            source: String,
            target: String,
            kind: String,
            targetFallback: String? = nil
        ) {
            self.source = source
            self.target = target
            self.kind = kind
            self.targetFallback = targetFallback
        }
    }
}
