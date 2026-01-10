// SPDX-License-Identifier: MIT
// Copyright (C) 2026 class-dump contributors. All rights reserved.

import Foundation

/// Registry for collecting and resolving structure/union definitions.
///
/// This registry accumulates structure definitions from type encodings and provides
/// resolution services to convert forward-declared structures to their full definitions.
///
/// ## Thread Safety
///
/// This registry is implemented as an actor for explicit, compiler-verified thread safety.
/// All access is automatically isolated, eliminating data races by design.
///
/// ## Usage
/// ```swift
/// let registry = StructureRegistry()
///
/// // Register structures as they're encountered
/// await registry.register(structureType)
///
/// // Resolve forward declarations to full definitions
/// let resolved = await registry.resolve(forwardDeclaredType)
///
/// // Generate CDStructures.h content
/// let header = await registry.generateStructureDefinitions()
/// ```
public actor StructureRegistry {
    /// Maps structure/union name -> full definition (with members).
    private var definitions: [String: ObjCType] = [:]

    /// Maps typedef alias -> underlying type name
    /// Pre-populated with common CoreGraphics/Foundation typedefs (64-bit platform).
    private var typedefMappings: [String: String] = [
        // CoreGraphics scalar types
        "CGFloat": "double",

        // Foundation scalar types (64-bit)
        "NSInteger": "long",
        "NSUInteger": "unsigned long",

        // Size/offset types
        "CGGlyph": "unsigned short",
        "UniChar": "unsigned short",
        "UTF32Char": "unsigned int",

        // Boolean types
        "Boolean": "unsigned char",

        // Time types
        "CFTimeInterval": "double",
        "CFAbsoluteTime": "double",
        "NSTimeInterval": "double",

        // Index types
        "CFIndex": "long",
        "CFOptionFlags": "unsigned long",
        "CFTypeID": "unsigned long",
        "CFHashCode": "unsigned long",

        // OSStatus and related
        "OSStatus": "int",
        "OSType": "unsigned int",
        "FourCharCode": "unsigned int",
    ]

    /// Structures that were only seen as forward declarations.
    private var unresolvedNames: Set<String> = []

    /// All structure names that have been encountered (resolved or not).
    private var allNames: Set<String> = []

    /// Initialize an empty registry.
    public init() {}

    // MARK: - Registration

    /// Register a type, storing its definition if it's a structure/union with members.
    ///
    /// - Parameter type: The type to register.
    public func register(_ type: ObjCType) {
        registerInternal(type)
    }

    /// Register multiple types at once.
    ///
    /// - Parameter types: The types to register.
    public func registerAll(_ types: [ObjCType]) {
        for type in types {
            registerInternal(type)
        }
    }

    private func registerInternal(_ type: ObjCType) {
        switch type {
            case .structure(let typeName, let members):
                guard let name = typeName?.description, name != "?" else { return }

                allNames.insert(name)

                if members.isEmpty {
                    // Forward declaration - mark as unresolved if we don't have a definition
                    if definitions[name] == nil {
                        unresolvedNames.insert(name)
                    }
                }
                else {
                    // Full definition - store it
                    unresolvedNames.remove(name)

                    // Keep the definition with the most members
                    if let existing = definitions[name] {
                        if case .structure(_, let existingMembers) = existing,
                            members.count > existingMembers.count
                        {
                            definitions[name] = type
                        }
                    }
                    else {
                        definitions[name] = type
                    }

                    // Recursively register nested structures
                    for member in members {
                        registerInternal(member.type)
                    }
                }

            case .union(let typeName, let members):
                guard let name = typeName?.description, name != "?" else { return }

                allNames.insert(name)

                if members.isEmpty {
                    if definitions[name] == nil {
                        unresolvedNames.insert(name)
                    }
                }
                else {
                    unresolvedNames.remove(name)

                    if let existing = definitions[name] {
                        if case .union(_, let existingMembers) = existing,
                            members.count > existingMembers.count
                        {
                            definitions[name] = type
                        }
                    }
                    else {
                        definitions[name] = type
                    }

                    for member in members {
                        registerInternal(member.type)
                    }
                }

            case .pointer(let pointee):
                registerInternal(pointee)

            case .array(_, let elementType):
                registerInternal(elementType)

            case .const(let subtype), .in(let subtype), .inout(let subtype),
                .out(let subtype), .bycopy(let subtype), .byref(let subtype),
                .oneway(let subtype), .complex(let subtype), .atomic(let subtype):
                if let sub = subtype {
                    registerInternal(sub)
                }

            case .block(let types):
                if let types = types {
                    for t in types {
                        registerInternal(t)
                    }
                }

            default:
                break
        }
    }

    // MARK: - Resolution

    /// Resolve a forward-declared structure to its full definition.
    ///
    /// If the type is a forward-declared structure and a full definition is available,
    /// returns the full definition. Otherwise returns the original type.
    ///
    /// - Parameter type: The type to resolve.
    /// - Returns: The resolved type.
    public func resolve(_ type: ObjCType) -> ObjCType {
        resolveInternal(type, visited: [])
    }

    private func resolveInternal(_ type: ObjCType, visited: Set<String>) -> ObjCType {
        switch type {
            case .structure(let typeName, let members):
                guard let name = typeName?.description, name != "?" else { return type }

                // Check for circular reference
                if visited.contains(name) {
                    return type
                }

                // If this is a forward declaration and we have a definition, resolve it
                if members.isEmpty, let definition = definitions[name] {
                    return definition
                }

                // If it has members, resolve nested structures
                if !members.isEmpty {
                    var newVisited = visited
                    newVisited.insert(name)

                    let resolvedMembers = members.map { member in
                        ObjCTypedMember(
                            type: resolveInternal(member.type, visited: newVisited),
                            name: member.name
                        )
                    }
                    return .structure(name: typeName, members: resolvedMembers)
                }

                return type

            case .union(let typeName, let members):
                guard let name = typeName?.description, name != "?" else { return type }

                if visited.contains(name) {
                    return type
                }

                if members.isEmpty, let definition = definitions[name] {
                    return definition
                }

                if !members.isEmpty {
                    var newVisited = visited
                    newVisited.insert(name)

                    let resolvedMembers = members.map { member in
                        ObjCTypedMember(
                            type: resolveInternal(member.type, visited: newVisited),
                            name: member.name
                        )
                    }
                    return .union(name: typeName, members: resolvedMembers)
                }

                return type

            case .pointer(let pointee):
                return .pointer(resolveInternal(pointee, visited: visited))

            case .array(let count, let elementType):
                return .array(count: count, elementType: resolveInternal(elementType, visited: visited))

            case .const(let subtype):
                return .const(subtype.map { resolveInternal($0, visited: visited) })
            case .in(let subtype):
                return .in(subtype.map { resolveInternal($0, visited: visited) })
            case .inout(let subtype):
                return .inout(subtype.map { resolveInternal($0, visited: visited) })
            case .out(let subtype):
                return .out(subtype.map { resolveInternal($0, visited: visited) })
            case .bycopy(let subtype):
                return .bycopy(subtype.map { resolveInternal($0, visited: visited) })
            case .byref(let subtype):
                return .byref(subtype.map { resolveInternal($0, visited: visited) })
            case .oneway(let subtype):
                return .oneway(subtype.map { resolveInternal($0, visited: visited) })
            case .complex(let subtype):
                return .complex(subtype.map { resolveInternal($0, visited: visited) })
            case .atomic(let subtype):
                return .atomic(subtype.map { resolveInternal($0, visited: visited) })

            case .block(let types):
                if let types = types {
                    return .block(types: types.map { resolveInternal($0, visited: visited) })
                }
                return type

            default:
                return type
        }
    }

    // MARK: - Queries

    /// Check if a structure name has a known full definition.
    ///
    /// - Parameter name: The structure name to check.
    /// - Returns: `true` if a full definition is available.
    public func hasDefinition(for name: String) -> Bool {
        definitions[name] != nil
    }

    /// Get the full definition for a structure name.
    ///
    /// - Parameter name: The structure name.
    /// - Returns: The full definition, or `nil` if not available.
    public func definition(for name: String) -> ObjCType? {
        definitions[name]
    }

    /// Get all structure names that remain unresolved (forward declarations only).
    public var unresolvedStructureNames: Set<String> {
        unresolvedNames
    }

    /// Get all structure names that have full definitions.
    public var resolvedStructureNames: Set<String> {
        Set(definitions.keys)
    }

    /// Get the total number of structures registered.
    public var count: Int {
        allNames.count
    }

    /// Get the number of fully defined structures.
    public var definedCount: Int {
        definitions.count
    }

    // MARK: - Typedef Support

    /// Register a typedef mapping.
    ///
    /// - Parameters:
    ///   - alias: The typedef alias name.
    ///   - underlyingType: The underlying type name.
    public func registerTypedef(alias: String, underlyingType: String) {
        typedefMappings[alias] = underlyingType
    }

    /// Resolve a typedef alias to its underlying type name.
    ///
    /// - Parameter alias: The typedef alias.
    /// - Returns: The underlying type name, or `nil` if not found.
    public func resolveTypedef(_ alias: String) -> String? {
        typedefMappings[alias]
    }

    /// Get all registered typedef mappings.
    public var allTypedefs: [String: String] {
        typedefMappings
    }

    /// Check if a typedef is a builtin (platform-provided) typedef.
    ///
    /// - Parameter alias: The typedef alias.
    /// - Returns: `true` if this is a builtin typedef.
    public func isBuiltinTypedef(_ alias: String) -> Bool {
        // Builtin typedefs are the ones we initialize
        let builtins: Set<String> = [
            "CGFloat", "NSInteger", "NSUInteger",
            "CGGlyph", "UniChar", "UTF32Char",
            "Boolean", "CFTimeInterval", "CFAbsoluteTime", "NSTimeInterval",
            "CFIndex", "CFOptionFlags", "CFTypeID", "CFHashCode",
            "OSStatus", "OSType", "FourCharCode",
        ]
        return builtins.contains(alias)
    }

    // MARK: - Output Generation

    /// Generate CDStructures.h content with all structure definitions.
    ///
    /// - Parameter formatter: Optional formatter for customizing output.
    /// - Returns: The header file content as a string.
    public func generateStructureDefinitions(formatter: ObjCTypeFormatter? = nil) -> String {
        guard !definitions.isEmpty else { return "" }

        var result = ""
        let fmt = formatter ?? ObjCTypeFormatter(options: ObjCTypeFormatterOptions(shouldExpand: true))

        // Sort structures for stable output
        let sortedNames = definitions.keys.sorted()

        // Build dependency order (define inner structures before outer)
        let ordered = topologicalSort(sortedNames)

        for name in ordered {
            guard let type = definitions[name] else { continue }

            let formatted = fmt.formatVariable(name: nil, type: type)
            result += "typedef \(formatted) \(name);\n\n"
        }

        // Add forward declarations for unresolved structures
        if !unresolvedNames.isEmpty {
            result += "// Forward declarations (definitions not found)\n"
            for name in unresolvedNames.sorted() {
                result += "// struct \(name);\n"
            }
            result += "\n"
        }

        return result
    }

    /// Topologically sort structure names based on dependencies.
    ///
    /// Uses optimized Kahn's algorithm with in-degree tracking for O(n+m) complexity
    /// where n = number of structures and m = number of dependency edges.
    private func topologicalSort(_ names: [String]) -> [String] {
        guard !names.isEmpty else { return [] }

        let nameSet = Set(names)

        // Build dependency graph and compute in-degrees
        // dependencies[A] = {B, C} means A depends on B and C
        // dependents[B] = {A, ...} means A (and others) depend on B
        var dependencies: [String: Set<String>] = [:]
        var dependents: [String: [String]] = [:]  // Reverse graph
        var inDegree: [String: Int] = [:]

        for name in names {
            let deps = getDependencies(for: name).intersection(nameSet)
            dependencies[name] = deps
            inDegree[name] = deps.count

            for dep in deps {
                dependents[dep, default: []].append(name)
            }
        }

        // Initialize ready queue with nodes that have no dependencies
        var ready: [String] = []
        for name in names where inDegree[name] == 0 {
            ready.append(name)
        }

        // Sort initially for deterministic output
        ready.sort()

        var result: [String] = []
        result.reserveCapacity(names.count)

        // Process ready queue
        while !ready.isEmpty {
            let name = ready.removeFirst()
            result.append(name)

            // Decrement in-degree of all dependents
            if let deps = dependents[name] {
                for dependent in deps {
                    let currentDegree = inDegree[dependent] ?? 0
                    if currentDegree > 0 {
                        inDegree[dependent] = currentDegree - 1
                        if currentDegree - 1 == 0 {
                            // Insert in sorted position for deterministic output
                            let insertIndex = ready.firstIndex { $0 > dependent } ?? ready.endIndex
                            ready.insert(dependent, at: insertIndex)
                        }
                    }
                }
            }
        }

        // Handle cycles: add any remaining nodes
        if result.count < names.count {
            let processed = Set(result)
            let remaining = names.filter { !processed.contains($0) }.sorted()
            result.append(contentsOf: remaining)
        }

        return result
    }

    /// Get the structure names that a given structure depends on.
    private func getDependencies(for name: String) -> Set<String> {
        guard let type = definitions[name] else { return [] }

        var deps = Set<String>()
        collectDependencies(from: type, into: &deps)
        deps.remove(name)  // Don't depend on self
        return deps
    }

    private func collectDependencies(from type: ObjCType, into deps: inout Set<String>) {
        switch type {
            case .structure(let typeName, let members):
                if let name = typeName?.description, name != "?" {
                    deps.insert(name)
                }
                for member in members {
                    collectDependencies(from: member.type, into: &deps)
                }

            case .union(let typeName, let members):
                if let name = typeName?.description, name != "?" {
                    deps.insert(name)
                }
                for member in members {
                    collectDependencies(from: member.type, into: &deps)
                }

            case .pointer(let pointee):
                // Pointers create weak dependencies (forward declaration sufficient)
                // But we still track them for ordering
                if case .structure(let typeName, _) = pointee,
                    let name = typeName?.description, name != "?"
                {
                    deps.insert(name)
                }
                if case .union(let typeName, _) = pointee,
                    let name = typeName?.description, name != "?"
                {
                    deps.insert(name)
                }

            case .array(_, let elementType):
                collectDependencies(from: elementType, into: &deps)

            case .const(let sub), .in(let sub), .inout(let sub),
                .out(let sub), .bycopy(let sub), .byref(let sub),
                .oneway(let sub), .complex(let sub), .atomic(let sub):
                if let s = sub {
                    collectDependencies(from: s, into: &deps)
                }

            default:
                break
        }
    }

    // MARK: - Merging

    /// Merge another registry's data into this one.
    ///
    /// This method takes snapshots of the other registry's data to merge.
    /// For actor-to-actor merging, use `mergeAsync` instead.
    ///
    /// - Parameters:
    ///   - otherDefinitions: The definitions from the other registry.
    ///   - otherAllNames: All names from the other registry.
    ///   - otherUnresolvedNames: Unresolved names from the other registry.
    ///   - otherTypedefMappings: Typedef mappings from the other registry.
    public func merge(
        definitions otherDefinitions: [String: ObjCType],
        allNames otherAllNames: Set<String>,
        unresolvedNames otherUnresolvedNames: Set<String>,
        typedefMappings otherTypedefMappings: [String: String]
    ) {
        for (name, type) in otherDefinitions {
            if let existing = definitions[name] {
                // Keep the one with more members
                if case .structure(_, let existingMembers) = existing,
                    case .structure(_, let newMembers) = type,
                    newMembers.count > existingMembers.count
                {
                    definitions[name] = type
                }
                else if case .union(_, let existingMembers) = existing,
                    case .union(_, let newMembers) = type,
                    newMembers.count > existingMembers.count
                {
                    definitions[name] = type
                }
            }
            else {
                definitions[name] = type
            }
        }

        allNames.formUnion(otherAllNames)

        // Update unresolved: only unresolved if we still don't have a definition
        for name in otherUnresolvedNames where definitions[name] == nil {
            unresolvedNames.insert(name)
        }

        for (alias, underlying) in otherTypedefMappings {
            typedefMappings[alias] = underlying
        }
    }

    /// Get a snapshot of this registry's definitions for merging.
    public var definitionsSnapshot: [String: ObjCType] {
        definitions
    }

    /// Get a snapshot of this registry's all names for merging.
    public var allNamesSnapshot: Set<String> {
        allNames
    }

    /// Get a snapshot of this registry's unresolved names for merging.
    public var unresolvedNamesSnapshot: Set<String> {
        unresolvedNames
    }

    /// Get a snapshot of this registry's typedef mappings for merging.
    public var typedefMappingsSnapshot: [String: String] {
        typedefMappings
    }

    // MARK: - Debug

    /// Get a debug description of the registry contents.
    public var debugDescription: String {
        var result = "StructureRegistry:\n"
        result += "  Defined: \(definitions.count)\n"
        result += "  Unresolved: \(unresolvedNames.count)\n"

        if !definitions.isEmpty {
            result += "  Definitions:\n"
            for name in definitions.keys.sorted() {
                result += "    - \(name)\n"
            }
        }

        if !unresolvedNames.isEmpty {
            result += "  Forward declarations:\n"
            for name in unresolvedNames.sorted() {
                result += "    - \(name)\n"
            }
        }

        return result
    }
}

// MARK: - ObjCType Extensions for Structure Detection

extension ObjCType {
    /// Whether this is a forward-declared structure (has name but no members).
    public var isForwardDeclaredStructure: Bool {
        switch self {
            case .structure(let name, let members):
                return name != nil && members.isEmpty
            case .union(let name, let members):
                return name != nil && members.isEmpty
            default:
                return false
        }
    }

    /// The structure/union name, if this is a structure or union type.
    public var structureName: String? {
        switch self {
            case .structure(let name, _):
                return name?.description
            case .union(let name, _):
                return name?.description
            default:
                return nil
        }
    }

    /// Whether this structure/union has a complete definition (has members).
    public var hasCompleteDefinition: Bool {
        switch self {
            case .structure(_, let members):
                return !members.isEmpty
            case .union(_, let members):
                return !members.isEmpty
            default:
                return false
        }
    }

    /// Create a resolved version of this type using the given registry.
    ///
    /// - Parameter registry: The registry to use for resolution.
    /// - Returns: A new type with forward declarations resolved.
    public func resolved(using registry: StructureRegistry) async -> ObjCType {
        await registry.resolve(self)
    }
}
