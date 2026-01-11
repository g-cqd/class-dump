// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

// MARK: - Registry Building

/// Pure functions for building type registries from ObjC metadata.
///
/// These functions extract types from ObjC classes, protocols, and categories
/// for registration with `StructureRegistry` and `MethodSignatureRegistry`.
///
/// ## Design
///
/// The functions are pure transformations that extract parsed types without
/// side effects. The actual registration with actor-based registries is
/// performed by the caller.
public enum DyldCacheRegistryBuilder {

    // MARK: - Type Extraction

    /// Extract all parsed types from classes for registry registration.
    ///
    /// Pure function that collects types from instance variables and properties.
    ///
    /// - Parameter classes: The classes to extract types from.
    /// - Returns: Array of unique parsed types.
    public static func extractTypes(from classes: [ObjCClass]) -> [ObjCType] {
        classes.flatMap { cls -> [ObjCType] in
            let ivarTypes = cls.instanceVariables.compactMap(\.parsedType)
            let propertyTypes = cls.properties.compactMap(\.parsedType)
            return ivarTypes + propertyTypes
        }
    }

    /// Extract all parsed types from protocols for registry registration.
    ///
    /// Pure function that collects types from protocol properties.
    ///
    /// - Parameter protocols: The protocols to extract types from.
    /// - Returns: Array of parsed types.
    public static func extractTypes(from protocols: [ObjCProtocol]) -> [ObjCType] {
        protocols.flatMap { proto in
            proto.properties.compactMap(\.parsedType)
        }
    }

    /// Extract all parsed types from categories for registry registration.
    ///
    /// Pure function that collects types from category properties.
    ///
    /// - Parameter categories: The categories to extract types from.
    /// - Returns: Array of parsed types.
    public static func extractTypes(from categories: [ObjCCategory]) -> [ObjCType] {
        categories.flatMap { category in
            category.properties.compactMap(\.parsedType)
        }
    }

    /// Extract all parsed types from metadata for registry registration.
    ///
    /// Pure function that combines types from all sources.
    ///
    /// - Parameters:
    ///   - classes: The classes to extract from.
    ///   - protocols: The protocols to extract from.
    ///   - categories: The categories to extract from.
    /// - Returns: Array of all parsed types.
    public static func extractAllTypes(
        classes: [ObjCClass],
        protocols: [ObjCProtocol],
        categories: [ObjCCategory]
    ) -> [ObjCType] {
        extractTypes(from: classes)
            + extractTypes(from: protocols)
            + extractTypes(from: categories)
    }

    // MARK: - Registry Population

    /// Build a structure registry from ObjC metadata.
    ///
    /// Async function that populates the registry with extracted types.
    ///
    /// - Parameters:
    ///   - classes: Classes to register types from.
    ///   - protocols: Protocols to register types from.
    ///   - categories: Categories to register types from.
    /// - Returns: Populated structure registry.
    public static func buildStructureRegistry(
        classes: [ObjCClass],
        protocols: [ObjCProtocol],
        categories: [ObjCCategory]
    ) async -> StructureRegistry {
        let registry = StructureRegistry()
        let types = extractAllTypes(
            classes: classes,
            protocols: protocols,
            categories: categories
        )

        for type in types {
            await registry.register(type)
        }

        return registry
    }

    /// Build a method signature registry from protocols.
    ///
    /// Async function that registers all protocol method signatures.
    ///
    /// - Parameter protocols: Protocols to register.
    /// - Returns: Populated method signature registry.
    public static func buildMethodSignatureRegistry(
        protocols: [ObjCProtocol]
    ) async -> MethodSignatureRegistry {
        let registry = MethodSignatureRegistry()

        for proto in protocols {
            await registry.registerProtocol(proto)
        }

        return registry
    }
}

// MARK: - Type Collection Helpers

extension DyldCacheRegistryBuilder {

    /// Count of unique structure types in metadata.
    ///
    /// Pure function for analysis.
    ///
    /// - Parameters:
    ///   - classes: Classes to analyze.
    ///   - protocols: Protocols to analyze.
    ///   - categories: Categories to analyze.
    /// - Returns: Count of unique structure references.
    public static func uniqueStructureCount(
        classes: [ObjCClass],
        protocols: [ObjCProtocol],
        categories: [ObjCCategory]
    ) -> Int {
        let types = extractAllTypes(
            classes: classes,
            protocols: protocols,
            categories: categories
        )

        let structureNames = types.compactMap { type -> String? in
            switch type {
                case .structure(let name, _):
                    return name?.name
                case .pointer(.structure(let name, _)):
                    return name?.name
                default:
                    return nil
            }
        }

        return Set(structureNames).count
    }
}
