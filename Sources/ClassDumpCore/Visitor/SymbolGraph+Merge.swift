// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

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
            return SymbolGraphMerger.createEmptyGraph(
                moduleName: moduleName,
                platform: platform
            )
        }

        let mergeResult = SymbolGraphMerger.mergeGraphs(graphs)

        // Use the first graph's platform if not provided
        let resolvedPlatform =
            platform
            ?? graphs.first?.module.platform
            ?? Platform(operatingSystem: nil, architecture: nil, vendor: "apple")

        return SymbolGraph(
            metadata: Metadata(
                formatVersion: SemanticVersion(major: 0, minor: 6, patch: 0),
                generator: "class-dump"
            ),
            module: Module(
                name: moduleName,
                platform: resolvedPlatform,
                bystanders: mergeResult.bystanderModules.sorted()
            ),
            symbols: mergeResult.symbols,
            relationships: mergeResult.relationships
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

// MARK: - Symbol Graph Merger

/// Pure functions for merging symbol graphs.
///
/// These functions operate on immutable data and have no side effects.
public enum SymbolGraphMerger {

    /// Result of merging multiple symbol graphs.
    public struct MergeResult {
        /// Merged symbols from all graphs.
        public let symbols: [SymbolGraph.Symbol]
        /// Merged relationships from all graphs.
        public let relationships: [SymbolGraph.Relationship]
        /// Module names that contributed to the merge.
        public let bystanderModules: Set<String>
    }

    /// Create an empty symbol graph with default metadata.
    ///
    /// Pure factory function.
    ///
    /// - Parameters:
    ///   - moduleName: Name for the module.
    ///   - platform: Optional platform info.
    /// - Returns: An empty symbol graph.
    public static func createEmptyGraph(
        moduleName: String,
        platform: SymbolGraph.Platform?
    ) -> SymbolGraph {
        SymbolGraph(
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
            symbols: [],
            relationships: []
        )
    }

    /// Merge multiple graphs into a single result.
    ///
    /// Pure function that combines symbols and relationships,
    /// deduplicating by identifier.
    ///
    /// - Parameter graphs: The graphs to merge.
    /// - Returns: Merged symbols, relationships, and bystander modules.
    public static func mergeGraphs(_ graphs: [SymbolGraph]) -> MergeResult {
        var symbolsByIdentifier: [String: SymbolGraph.Symbol] = [:]
        var allRelationships: [SymbolGraph.Relationship] = []
        var seenRelationships: Set<String> = []
        var bystanderModules: Set<String> = []

        for graph in graphs {
            // Track bystander modules
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
                let key = relationshipKey(rel)
                if !seenRelationships.contains(key) {
                    seenRelationships.insert(key)
                    allRelationships.append(rel)
                }
            }
        }

        return MergeResult(
            symbols: sortSymbols(Array(symbolsByIdentifier.values)),
            relationships: sortRelationships(allRelationships),
            bystanderModules: bystanderModules
        )
    }

    /// Generate a unique key for a relationship.
    ///
    /// Pure function for deduplication.
    ///
    /// - Parameter relationship: The relationship to key.
    /// - Returns: A unique string key.
    public static func relationshipKey(_ relationship: SymbolGraph.Relationship) -> String {
        "\(relationship.source)|\(relationship.target)|\(relationship.kind)"
    }

    /// Sort symbols by precise identifier.
    ///
    /// Pure function for consistent output.
    ///
    /// - Parameter symbols: The symbols to sort.
    /// - Returns: Sorted symbols.
    public static func sortSymbols(_ symbols: [SymbolGraph.Symbol]) -> [SymbolGraph.Symbol] {
        symbols.sorted { $0.identifier.precise < $1.identifier.precise }
    }

    /// Sort relationships by source, target, and kind.
    ///
    /// Pure function for consistent output.
    ///
    /// - Parameter relationships: The relationships to sort.
    /// - Returns: Sorted relationships.
    public static func sortRelationships(
        _ relationships: [SymbolGraph.Relationship]
    ) -> [SymbolGraph.Relationship] {
        relationships.sorted {
            ($0.source, $0.target, $0.kind) < ($1.source, $1.target, $1.kind)
        }
    }

    /// Count symbols by kind.
    ///
    /// Pure function for analysis.
    ///
    /// - Parameter graph: The graph to analyze.
    /// - Returns: Dictionary mapping kind identifiers to counts.
    public static func symbolCountsByKind(_ graph: SymbolGraph) -> [String: Int] {
        Dictionary(grouping: graph.symbols, by: { $0.kind.identifier })
            .mapValues(\.count)
    }

    /// Count relationships by kind.
    ///
    /// Pure function for analysis.
    ///
    /// - Parameter graph: The graph to analyze.
    /// - Returns: Dictionary mapping kind strings to counts.
    public static func relationshipCountsByKind(_ graph: SymbolGraph) -> [String: Int] {
        Dictionary(grouping: graph.relationships, by: \.kind)
            .mapValues(\.count)
    }

    /// Find orphan symbols (symbols with no relationships).
    ///
    /// Pure function for graph validation.
    ///
    /// - Parameter graph: The graph to analyze.
    /// - Returns: Symbols that have no relationships.
    public static func orphanSymbols(_ graph: SymbolGraph) -> [SymbolGraph.Symbol] {
        let symbolsInRelationships = Set(
            graph.relationships.flatMap { [$0.source, $0.target] }
        )

        return graph.symbols.filter { symbol in
            !symbolsInRelationships.contains(symbol.identifier.precise)
        }
    }

    /// Find missing targets (relationships pointing to non-existent symbols).
    ///
    /// Pure function for graph validation.
    ///
    /// - Parameter graph: The graph to analyze.
    /// - Returns: Relationships with missing target symbols.
    public static func relationshipsWithMissingTargets(
        _ graph: SymbolGraph
    ) -> [SymbolGraph.Relationship] {
        let symbolIdentifiers = Set(graph.symbols.map(\.identifier.precise))

        return graph.relationships.filter { rel in
            !symbolIdentifiers.contains(rel.target) && rel.targetFallback == nil
        }
    }
}
