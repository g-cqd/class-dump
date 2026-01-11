// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

// MARK: - Symbol Graph JSON Utilities

extension SymbolGraph {
    /// Encode this symbol graph to JSON data.
    ///
    /// - Parameter prettyPrint: Whether to format the JSON for readability (default: true).
    /// - Returns: JSON data representation of the symbol graph.
    /// - Throws: Encoding errors if the graph cannot be serialized.
    public func jsonData(prettyPrint: Bool = true) throws -> Data {
        try SymbolGraphSerializer.encode(self, prettyPrint: prettyPrint)
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
        try SymbolGraphSerializer.decode(from: data)
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
        SymbolGraphSerializer.recommendedFilename(
            moduleName: module.name,
            extendedModule: extendedModule
        )
    }
}

// MARK: - Symbol Graph Serializer

/// Pure functions for serializing and deserializing symbol graphs.
///
/// These functions encapsulate JSON encoding/decoding logic.
public enum SymbolGraphSerializer {

    /// Encode a symbol graph to JSON data.
    ///
    /// Pure function for serialization.
    ///
    /// - Parameters:
    ///   - graph: The symbol graph to encode.
    ///   - prettyPrint: Whether to format for readability.
    /// - Returns: Encoded JSON data.
    /// - Throws: Encoding errors.
    public static func encode(_ graph: SymbolGraph, prettyPrint: Bool = true) throws -> Data {
        let encoder = JSONEncoder()
        if prettyPrint {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        else {
            encoder.outputFormatting = [.sortedKeys]
        }
        return try encoder.encode(graph)
    }

    /// Decode a symbol graph from JSON data.
    ///
    /// Pure function for deserialization.
    ///
    /// - Parameter data: JSON data to decode.
    /// - Returns: Decoded symbol graph.
    /// - Throws: Decoding errors.
    public static func decode(from data: Data) throws -> SymbolGraph {
        let decoder = JSONDecoder()
        return try decoder.decode(SymbolGraph.self, from: data)
    }

    /// Generate recommended filename for a module.
    ///
    /// Pure function following Apple's naming convention.
    ///
    /// - Parameters:
    ///   - moduleName: Name of the module.
    ///   - extendedModule: Optional extended module name.
    /// - Returns: Recommended filename.
    public static func recommendedFilename(
        moduleName: String,
        extendedModule: String? = nil
    ) -> String {
        if let extended = extendedModule {
            return "\(moduleName)@\(extended).symbols.json"
        }
        return "\(moduleName).symbols.json"
    }

    /// Validate JSON data as a symbol graph.
    ///
    /// Pure function for validation without full parsing.
    ///
    /// - Parameter data: JSON data to validate.
    /// - Returns: Validation result with any errors.
    public static func validate(_ data: Data) -> ValidationResult {
        do {
            let graph = try decode(from: data)
            return ValidationResult(
                isValid: true,
                symbolCount: graph.symbols.count,
                relationshipCount: graph.relationships.count,
                errors: []
            )
        }
        catch {
            return ValidationResult(
                isValid: false,
                symbolCount: 0,
                relationshipCount: 0,
                errors: [error.localizedDescription]
            )
        }
    }

    /// Result of symbol graph validation.
    public struct ValidationResult: Sendable {
        /// Whether the symbol graph is valid.
        public let isValid: Bool
        /// Number of symbols in the graph.
        public let symbolCount: Int
        /// Number of relationships in the graph.
        public let relationshipCount: Int
        /// Any validation errors encountered.
        public let errors: [String]
    }

    /// Calculate the approximate size of a symbol graph in JSON format.
    ///
    /// Pure function for size estimation without full encoding.
    ///
    /// - Parameter graph: The graph to measure.
    /// - Returns: Approximate byte size.
    public static func approximateSize(_ graph: SymbolGraph) -> Int {
        // Rough estimation: each symbol ~500 bytes, each relationship ~100 bytes
        let symbolSize = graph.symbols.count * 500
        let relationshipSize = graph.relationships.count * 100
        let overhead = 1000  // metadata, module, JSON structure
        return symbolSize + relationshipSize + overhead
    }
}

// MARK: - Symbol Graph Statistics

/// Pure functions for computing symbol graph statistics.
public enum SymbolGraphStatistics {

    /// Summary statistics for a symbol graph.
    public struct Summary: Sendable {
        /// Total number of symbols.
        public let symbolCount: Int
        /// Total number of relationships.
        public let relationshipCount: Int
        /// Symbols grouped by kind.
        public let symbolsByKind: [String: Int]
        /// Relationships grouped by kind.
        public let relationshipsByKind: [String: Int]
        /// Symbols grouped by access level.
        public let accessLevelDistribution: [String: Int]
    }

    /// Compute summary statistics for a symbol graph.
    ///
    /// Pure function for analysis.
    ///
    /// - Parameter graph: The graph to analyze.
    /// - Returns: Summary statistics.
    public static func summary(_ graph: SymbolGraph) -> Summary {
        Summary(
            symbolCount: graph.symbols.count,
            relationshipCount: graph.relationships.count,
            symbolsByKind: symbolsByKind(graph),
            relationshipsByKind: relationshipsByKind(graph),
            accessLevelDistribution: accessLevelDistribution(graph)
        )
    }

    /// Count symbols by kind.
    ///
    /// Pure function.
    ///
    /// - Parameter graph: The graph to analyze.
    /// - Returns: Dictionary of kind to count.
    public static func symbolsByKind(_ graph: SymbolGraph) -> [String: Int] {
        Dictionary(grouping: graph.symbols, by: { $0.kind.identifier })
            .mapValues(\.count)
    }

    /// Count relationships by kind.
    ///
    /// Pure function.
    ///
    /// - Parameter graph: The graph to analyze.
    /// - Returns: Dictionary of kind to count.
    public static func relationshipsByKind(_ graph: SymbolGraph) -> [String: Int] {
        Dictionary(grouping: graph.relationships, by: \.kind)
            .mapValues(\.count)
    }

    /// Count symbols by access level.
    ///
    /// Pure function.
    ///
    /// - Parameter graph: The graph to analyze.
    /// - Returns: Dictionary of access level to count.
    public static func accessLevelDistribution(_ graph: SymbolGraph) -> [String: Int] {
        Dictionary(grouping: graph.symbols, by: \.accessLevel)
            .mapValues(\.count)
    }

    /// Get all unique path prefixes in the graph.
    ///
    /// Pure function for namespace analysis.
    ///
    /// - Parameter graph: The graph to analyze.
    /// - Returns: Set of first path components.
    public static func topLevelPaths(_ graph: SymbolGraph) -> Set<String> {
        Set(graph.symbols.compactMap(\.pathComponents.first))
    }
}
