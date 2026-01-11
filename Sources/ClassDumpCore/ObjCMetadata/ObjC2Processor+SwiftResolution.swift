// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

/// Swift type resolution extensions for ObjC2Processor.
///
/// This extension provides functions for resolving Swift type information
/// for ObjC-visible properties of Swift classes. Swift classes expose ivars
/// to the ObjC runtime but don't provide complete type encodings, so we
/// look up types from Swift field descriptors.
extension ObjC2Processor {

    // MARK: - Swift Type Resolution

    /// Try to resolve a Swift type name for an ivar based on class name and field name.
    ///
    /// Swift classes expose ivars to ObjC runtime but don't provide type encodings.
    /// We can look up the type from Swift field descriptors if available.
    ///
    /// This function uses a pre-built comprehensive index for O(1) lookups in most cases.
    /// The index includes all name variants (suffixes, components) computed during initialization.
    ///
    /// - Parameters:
    ///   - className: The ObjC class name (may be mangled).
    ///   - ivarName: The ivar name to look up.
    /// - Returns: The resolved Swift type name or nil.
    /// - Complexity: O(1) average case (dictionary lookups), O(d) worst case for edge cases.
    func resolveSwiftIvarType(className: String, ivarName: String) async -> String? {
        guard swiftMetadata != nil else { return nil }

        // Extract the target class name from ObjC mangled name
        let targetInfo = extractTargetClassName(from: className)

        // Try comprehensive variant index (O(1) lookup)
        if let descriptor = swiftFieldsByVariant[targetInfo.targetClassName] {
            if let resolved = await resolveFieldFromDescriptor(descriptor, fieldName: ivarName) {
                return resolved
            }
        }

        // For nested classes, try the full nested path
        if targetInfo.nestedNames.count > 1 {
            let nestedPath = targetInfo.nestedNames.joined(separator: ".")
            if let descriptor = swiftFieldsByVariant[nestedPath] {
                if let resolved = await resolveFieldFromDescriptor(descriptor, fieldName: ivarName) {
                    return resolved
                }
            }
        }

        // Try full module-qualified name
        if let fullName = targetInfo.fullName {
            if let descriptor = swiftFieldsByVariant[fullName] {
                if let resolved = await resolveFieldFromDescriptor(descriptor, fieldName: ivarName) {
                    return resolved
                }
            }
        }

        // For non-mangled ObjC class names, try direct lookup
        if !className.hasPrefix("_Tt") {
            if let descriptor = swiftFieldsByVariant[className] {
                if let resolved = await resolveFieldFromDescriptor(descriptor, fieldName: ivarName) {
                    return resolved
                }
            }
        }

        // Fallback: linear scan with cached demangled names
        return await fallbackSwiftTypeResolution(
            targetClassName: targetInfo.targetClassName,
            ivarName: ivarName
        )
    }

    // MARK: - Class Name Extraction

    /// Information extracted from an ObjC class name.
    struct TargetClassInfo {
        let targetClassName: String
        let nestedNames: [String]
        let fullName: String?
    }

    /// Extract the target class name from an ObjC class name.
    ///
    /// Pure function that parses mangled ObjC Swift class names.
    ///
    /// - Parameter className: The ObjC class name (may be mangled).
    /// - Returns: Extracted class name information.
    private func extractTargetClassName(from className: String) -> TargetClassInfo {
        var targetClassName = className
        var nestedNames: [String] = []
        var fullName: String?

        if className.hasPrefix("_TtCC") || className.hasPrefix("_TtCCC") {
            // Handle nested classes first
            nestedNames = SwiftDemangler.demangleNestedClassName(className)
            if let last = nestedNames.last {
                targetClassName = last
            }
        }
        else if className.hasPrefix("_TtC") || className.hasPrefix("_TtGC") {
            if let (module, name) = SwiftDemangler.demangleClassName(className) {
                targetClassName = name
                fullName = "\(module).\(name)"
            }
        }
        else if className.hasPrefix("_Tt") {
            // Other mangled formats - extract the last component
            targetClassName = extractSimpleClassName(from: className)
        }

        return TargetClassInfo(
            targetClassName: targetClassName,
            nestedNames: nestedNames,
            fullName: fullName
        )
    }

    // MARK: - Field Resolution

    /// Resolve a field's type from a descriptor by field name.
    ///
    /// - Parameters:
    ///   - descriptor: The Swift field descriptor.
    ///   - ivarName: The field name to match.
    /// - Returns: The resolved type name or nil.
    func resolveFieldFromDescriptor(
        _ descriptor: SwiftFieldDescriptor,
        fieldName ivarName: String
    ) async -> String? {
        for record in descriptor.records where fieldNameMatches(record.name, ivarName: ivarName) {
            return await resolveFieldRecordType(record)
        }
        return nil
    }

    /// Check if a field record name matches the target ivar name.
    ///
    /// Pure matching function that handles Swift internal prefixes.
    ///
    /// - Parameters:
    ///   - recordName: The name from the field record.
    ///   - ivarName: The target ivar name.
    /// - Returns: True if they match.
    private func fieldNameMatches(_ recordName: String, ivarName: String) -> Bool {
        // Handle lazy storage prefix and other Swift internal prefixes
        var fieldName = recordName
        fieldName = fieldName.replacingOccurrences(of: "$__lazy_storage_$_", with: "")
        fieldName = fieldName.replacingOccurrences(of: "_$s", with: "")

        // Check for exact match or match with common prefixes removed/added
        return fieldName == ivarName
            || recordName == ivarName
            || fieldName == "_" + ivarName
            || "_" + fieldName == ivarName
            || fieldName == "$" + ivarName
            || "$" + fieldName == ivarName
    }

    /// Resolve the type from a field record.
    ///
    /// Uses the symbolic resolver for embedded references, then falls back
    /// to regular demangling.
    ///
    /// - Parameter record: The field record.
    /// - Returns: The resolved type name or nil.
    private func resolveFieldRecordType(_ record: SwiftFieldRecord) async -> String? {
        // Try symbolic resolver first with raw data (handles embedded refs)
        if !record.mangledTypeData.isEmpty {
            let resolved = await symbolicResolver.resolveType(
                mangledData: record.mangledTypeData,
                sourceOffset: record.mangledTypeNameOffset
            )
            if !resolved.isEmpty && !resolved.hasPrefix("/*") && resolved != record.mangledTypeName {
                return resolved
            }
        }

        // Fall back to regular demangling
        if !record.mangledTypeName.isEmpty {
            let demangled = SwiftDemangler.demangle(record.mangledTypeName)
            if !demangled.isEmpty {
                return demangled
            }
        }

        return nil
    }

    // MARK: - Fallback Resolution

    /// Fallback resolution using linear scan with cached demangled names.
    ///
    /// This handles edge cases where the comprehensive index didn't match.
    /// Uses pre-cached demangled names to avoid runtime demangling.
    ///
    /// - Parameters:
    ///   - targetClassName: The target class name to match.
    ///   - ivarName: The ivar name to look up.
    /// - Returns: The resolved type name or nil.
    private func fallbackSwiftTypeResolution(
        targetClassName: String,
        ivarName: String
    ) async -> String? {
        for (mangledTypeName, descriptor) in swiftFieldsByMangledName {
            // Use cached demangled name instead of re-demangling
            let demangled = demangledNameCache[mangledTypeName] ?? ""
            let descriptorClassName = extractSimpleClassName(from: demangled)

            if descriptorClassName == targetClassName
                || demangled.hasSuffix(targetClassName)
                || mangledTypeName.contains(targetClassName)
            {
                if let resolved = await resolveFieldFromDescriptor(descriptor, fieldName: ivarName) {
                    return resolved
                }
            }
        }
        return nil
    }

    // MARK: - Utility Functions

    /// Extract simple class name from a fully qualified or mangled name.
    ///
    /// Pure function for extracting the last component of a type name.
    ///
    /// - Parameter name: The full type name.
    /// - Returns: The simple class name.
    func extractSimpleClassName(from name: String) -> String {
        // If it's a fully qualified name (Module.ClassName), extract last component
        if name.contains(".") {
            return String(name.split(separator: ".").last ?? Substring(name))
        }

        // If it looks like a mangled name, try to extract class name
        if name.hasPrefix("_Tt") {
            if let (_, className) = SwiftDemangler.demangleClassName(name) {
                return className
            }
        }

        return name
    }

    /// Check if a class name looks like a Swift class (has mangled name format).
    ///
    /// Pure predicate function.
    ///
    /// - Parameter name: The class name to check.
    /// - Returns: True if it appears to be a Swift class.
    func isSwiftClass(name: String) -> Bool {
        name.hasPrefix("_Tt") || name.hasPrefix("_$s")
    }
}

// MARK: - Swift Field Index Builder

/// Pure functions for building the Swift field descriptor index.
///
/// These functions create a comprehensive lookup index from Swift metadata,
/// enabling O(1) field type resolution by name.
public enum SwiftFieldIndexBuilder {

    /// Index entry for a field descriptor.
    public struct IndexEntry {
        /// The Swift field descriptor.
        public let descriptor: SwiftFieldDescriptor
        /// All name variants for lookup (simple name, full name, suffixes).
        public let variants: [String]
    }

    /// Build a comprehensive field index from Swift metadata.
    ///
    /// Pure function that creates lookup dictionaries for field descriptors.
    ///
    /// - Parameter metadata: The Swift metadata to index.
    /// - Returns: Tuple of (byVariant, byMangledName, demangledCache) dictionaries.
    public static func buildIndex(
        from metadata: SwiftMetadata
    ) -> (
        byVariant: [String: SwiftFieldDescriptor],
        byMangledName: [String: SwiftFieldDescriptor],
        demangledCache: [String: String]
    ) {
        // Build address-to-name mappings from SwiftTypes
        let typeNameByAddress = Dictionary(
            uniqueKeysWithValues: metadata.types.map { ($0.address, $0.name) }
        )
        let fullNameByAddress = Dictionary(
            uniqueKeysWithValues: metadata.types.map { ($0.address, $0.fullName) }
        )

        var byVariant: [String: SwiftFieldDescriptor] = [:]
        var byMangledName: [String: SwiftFieldDescriptor] = [:]
        var demangledCache: [String: String] = [:]

        for fd in metadata.fieldDescriptors {
            // Index by raw mangled type name
            byMangledName[fd.mangledTypeName] = fd

            // Pre-demangle and cache the result
            let demangled = SwiftDemangler.extractTypeName(fd.mangledTypeName)
            if !demangled.isEmpty {
                demangledCache[fd.mangledTypeName] = demangled
                indexAllVariants(demangled, descriptor: fd, into: &byVariant)
            }

            // Index by address mappings from SwiftType metadata
            if let typeName = typeNameByAddress[fd.address] {
                indexAllVariants(typeName, descriptor: fd, into: &byVariant)
            }
            if let fullName = fullNameByAddress[fd.address] {
                indexAllVariants(fullName, descriptor: fd, into: &byVariant)
            }

            // Extract and index class name from mangled format if present
            if fd.mangledTypeName.hasPrefix("_Tt") {
                if let (module, className) = SwiftDemangler.demangleClassName(fd.mangledTypeName) {
                    indexAllVariants("\(module).\(className)", descriptor: fd, into: &byVariant)
                    indexAllVariants(className, descriptor: fd, into: &byVariant)
                }
            }
        }

        return (byVariant, byMangledName, demangledCache)
    }

    /// Index all suffix variants of a dotted name.
    ///
    /// Pure function that adds entries for "A.B.C", "B.C", and "C".
    ///
    /// - Parameters:
    ///   - name: The full name to index.
    ///   - descriptor: The field descriptor.
    ///   - index: The dictionary to populate.
    private static func indexAllVariants(
        _ name: String,
        descriptor: SwiftFieldDescriptor,
        into index: inout [String: SwiftFieldDescriptor]
    ) {
        guard !name.isEmpty && !name.hasPrefix("/*") else { return }

        // Index the full name
        index[name] = descriptor

        // If it contains dots, index all suffix variants
        guard name.contains(".") else { return }

        let components = name.split(separator: ".")
        // Index progressively shorter suffixes: A.B.C → B.C → C
        for i in 1..<components.count {
            let suffix = components[i...].joined(separator: ".")
            index[suffix] = descriptor
        }
        // Also index just the last component
        if let last = components.last {
            index[String(last)] = descriptor
        }
    }
}
