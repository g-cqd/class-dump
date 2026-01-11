// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

// MARK: - Container Type Resolution

extension SwiftSymbolicResolver {

    /// Resolve a mangled type that contains embedded symbolic references.
    ///
    /// This intelligently parses container types (Array, Dictionary, Set) and resolves
    /// symbolic references for each type argument, producing properly formatted output.
    func resolveTypeWithEmbeddedRefs(mangledData: Data, sourceOffset: Int) -> String {
        let bytes = Array(mangledData)

        // Try to parse as a known container type with embedded refs
        if let containerResult = parseContainerTypeWithRefs(bytes: bytes, sourceOffset: sourceOffset) {
            return containerResult
        }

        // Fall back to simple concatenation approach
        return resolveTypeWithEmbeddedRefsFallback(mangledData: mangledData, sourceOffset: sourceOffset)
    }

    /// Parse a container type (Array, Dictionary, Set, Optional) with embedded symbolic refs.
    ///
    /// Container types have the format:
    /// - Array: `Say<element_type>G`
    /// - Dictionary: `SDy<key_type><value_type>G`
    /// - Set: `Shy<element_type>G`
    /// - Optional: `<base_type>Sg`
    func parseContainerTypeWithRefs(bytes: [UInt8], sourceOffset: Int) -> String? {
        guard bytes.count >= 3 else { return nil }

        // Try each container pattern
        if let result = parseArrayWithRefs(bytes: bytes, sourceOffset: sourceOffset) {
            return result
        }

        if let result = parseDictionaryWithRefs(bytes: bytes, sourceOffset: sourceOffset) {
            return result
        }

        if let result = parseSetWithRefs(bytes: bytes, sourceOffset: sourceOffset) {
            return result
        }

        // Check for direct symbolic reference at start
        if let result = parseDirectSymbolicRef(bytes: bytes, sourceOffset: sourceOffset) {
            return result
        }

        return nil
    }

    // MARK: - Array Parsing

    /// Parse an Array type.
    ///
    /// Expected format: `Say<element>G`
    private func parseArrayWithRefs(bytes: [UInt8], sourceOffset: Int) -> String? {
        guard bytes.count >= 4,
            bytes[0] == 0x53, bytes[1] == 0x61, bytes[2] == 0x79  // "Say"
        else {
            return nil
        }

        var index = 3
        guard
            let (element, newIndex) = parseTypeArgWithRefs(
                bytes: bytes,
                startIndex: index,
                sourceOffset: sourceOffset
            )
        else {
            return nil
        }

        index = newIndex

        // Check for closing 'G'
        guard index < bytes.count && SwiftTypeShortcuts.isGenericClosing(bytes[index]) else {
            return nil
        }

        var result = "[\(element)]"
        index += 1

        // Check for Optional suffix
        if SwiftTypeShortcuts.hasOptionalSuffix(bytes, at: index) {
            result += "?"
        }

        return result
    }

    // MARK: - Dictionary Parsing

    /// Parse a Dictionary type.
    ///
    /// Expected format: `SDy<key><value>G`
    private func parseDictionaryWithRefs(bytes: [UInt8], sourceOffset: Int) -> String? {
        guard bytes.count >= 4,
            bytes[0] == 0x53, bytes[1] == 0x44, bytes[2] == 0x79  // "SDy"
        else {
            return nil
        }

        var index = 3
        var typeArgs: [String] = []

        // Parse key and value types
        while typeArgs.count < 2 && index < bytes.count {
            guard
                let (arg, newIndex) = parseTypeArgWithRefs(
                    bytes: bytes,
                    startIndex: index,
                    sourceOffset: sourceOffset
                )
            else {
                break
            }
            typeArgs.append(arg)
            index = newIndex
        }

        // Need exactly 2 type args and closing 'G'
        guard typeArgs.count == 2,
            index < bytes.count,
            SwiftTypeShortcuts.isGenericClosing(bytes[index])
        else {
            return nil
        }

        var result = "[\(typeArgs[0]): \(typeArgs[1])]"
        index += 1

        // Check for Optional suffix
        if SwiftTypeShortcuts.hasOptionalSuffix(bytes, at: index) {
            result += "?"
        }

        return result
    }

    // MARK: - Set Parsing

    /// Parse a Set type.
    ///
    /// Expected format: `Shy<element>G`
    private func parseSetWithRefs(bytes: [UInt8], sourceOffset: Int) -> String? {
        guard bytes.count >= 4,
            bytes[0] == 0x53, bytes[1] == 0x68, bytes[2] == 0x79  // "Shy"
        else {
            return nil
        }

        var index = 3
        guard
            let (element, newIndex) = parseTypeArgWithRefs(
                bytes: bytes,
                startIndex: index,
                sourceOffset: sourceOffset
            )
        else {
            return nil
        }

        index = newIndex

        // Check for closing 'G'
        guard index < bytes.count && SwiftTypeShortcuts.isGenericClosing(bytes[index]) else {
            return nil
        }

        var result = "Set<\(element)>"
        index += 1

        // Check for Optional suffix
        if SwiftTypeShortcuts.hasOptionalSuffix(bytes, at: index) {
            result += "?"
        }

        return result
    }

    // MARK: - Direct Symbolic Reference

    /// Parse a direct symbolic reference at the start of bytes.
    private func parseDirectSymbolicRef(bytes: [UInt8], sourceOffset: Int) -> String? {
        guard bytes.count >= 5, SwiftSymbolicReferenceKind.isSymbolicMarker(bytes[0]) else {
            return nil
        }

        let refData = Data(bytes)
        var result = resolveSymbolicReference(
            kind: SwiftSymbolicReferenceKind(marker: bytes[0]),
            data: refData,
            sourceOffset: sourceOffset
        )

        // Check for trailing Optional suffix
        if bytes.count >= 7, bytes[5] == 0x53, bytes[6] == 0x67 {  // "Sg"
            if !result.hasPrefix("/*") {
                result += "?"
            }
        }

        if !result.isEmpty && !result.hasPrefix("/*") {
            return result
        }

        return nil
    }

    // MARK: - Type Argument Parsing

    /// Parse a single type argument which may be a symbolic reference or standard mangled type.
    ///
    /// - Parameters:
    ///   - bytes: The byte array to parse from.
    ///   - startIndex: The index to start parsing at.
    ///   - sourceOffset: The file offset for symbolic reference resolution.
    ///   - depth: Recursion depth to prevent infinite loops.
    /// - Returns: Tuple of (resolved type name, new index after parsing) or nil.
    func parseTypeArgWithRefs(
        bytes: [UInt8],
        startIndex: Int,
        sourceOffset: Int,
        depth: Int = 0
    ) -> (String, Int)? {
        guard startIndex < bytes.count else { return nil }
        guard depth < 10 else { return nil }  // Prevent infinite recursion

        let byte = bytes[startIndex]

        // Try symbolic reference first
        if let result = tryParseSymbolicRef(bytes: bytes, index: startIndex, sourceOffset: sourceOffset) {
            return result
        }

        // Try nested container types
        if let result = tryParseNestedContainer(
            bytes: bytes,
            index: startIndex,
            sourceOffset: sourceOffset,
            depth: depth
        ) {
            return result
        }

        // Try standard type shortcuts
        if let result = tryParseTypeShortcut(bytes: bytes, index: startIndex, byte: byte) {
            return result
        }

        // Try length-prefixed type name
        if let result = tryParseLengthPrefixedType(bytes: bytes, index: startIndex, byte: byte) {
            return result
        }

        // Try ObjC imported type (So prefix)
        if let result = tryParseObjCImportedType(bytes: bytes, index: startIndex, byte: byte) {
            return result
        }

        return nil
    }

    // MARK: - Parsing Helpers

    /// Try to parse a symbolic reference at the given index.
    private func tryParseSymbolicRef(
        bytes: [UInt8],
        index: Int,
        sourceOffset: Int
    ) -> (String, Int)? {
        let byte = bytes[index]

        guard SwiftSymbolicReferenceKind.isSymbolicMarker(byte),
            index + 5 <= bytes.count
        else {
            return nil
        }

        let refData = Data(bytes[index...])
        let refOffset = sourceOffset + index

        let resolved = resolveSymbolicReference(
            kind: SwiftSymbolicReferenceKind(marker: byte),
            data: refData,
            sourceOffset: refOffset
        )

        if !resolved.isEmpty && !resolved.hasPrefix("/*") {
            return (resolved, index + 5)
        }

        // If symbolic resolution failed, skip the 5 bytes anyway
        return ("?", index + 5)
    }

    /// Try to parse a nested container type (Array, Dictionary, Set).
    private func tryParseNestedContainer(
        bytes: [UInt8],
        index: Int,
        sourceOffset: Int,
        depth: Int
    ) -> (String, Int)? {
        let byte = bytes[index]

        // Nested Array: Say...G
        if index + 3 < bytes.count,
            byte == 0x53, bytes[index + 1] == 0x61, bytes[index + 2] == 0x79
        {
            return parseNestedArray(bytes: bytes, index: index, sourceOffset: sourceOffset, depth: depth)
        }

        // Nested Dictionary: SDy...G
        if index + 3 < bytes.count,
            byte == 0x53, bytes[index + 1] == 0x44, bytes[index + 2] == 0x79
        {
            return parseNestedDictionary(bytes: bytes, index: index, sourceOffset: sourceOffset, depth: depth)
        }

        // Nested Set: Shy...G
        if index + 3 < bytes.count,
            byte == 0x53, bytes[index + 1] == 0x68, bytes[index + 2] == 0x79
        {
            return parseNestedSet(bytes: bytes, index: index, sourceOffset: sourceOffset, depth: depth)
        }

        return nil
    }

    /// Parse a nested Array type.
    private func parseNestedArray(
        bytes: [UInt8],
        index: Int,
        sourceOffset: Int,
        depth: Int
    ) -> (String, Int)? {
        var innerIndex = index + 3

        guard
            let (element, newIndex) = parseTypeArgWithRefs(
                bytes: bytes,
                startIndex: innerIndex,
                sourceOffset: sourceOffset,
                depth: depth + 1
            )
        else {
            return nil
        }

        innerIndex = newIndex

        guard innerIndex < bytes.count && SwiftTypeShortcuts.isGenericClosing(bytes[innerIndex]) else {
            return nil
        }

        var result = "[\(element)]"
        innerIndex += 1

        // Check for Optional suffix
        if SwiftTypeShortcuts.hasOptionalSuffix(bytes, at: innerIndex) {
            result += "?"
            innerIndex += 2
        }

        return (result, innerIndex)
    }

    /// Parse a nested Dictionary type.
    private func parseNestedDictionary(
        bytes: [UInt8],
        index: Int,
        sourceOffset: Int,
        depth: Int
    ) -> (String, Int)? {
        var innerIndex = index + 3
        var typeArgs: [String] = []

        while typeArgs.count < 2 && innerIndex < bytes.count {
            guard
                let (arg, newIndex) = parseTypeArgWithRefs(
                    bytes: bytes,
                    startIndex: innerIndex,
                    sourceOffset: sourceOffset,
                    depth: depth + 1
                )
            else {
                break
            }
            typeArgs.append(arg)
            innerIndex = newIndex
        }

        guard typeArgs.count == 2,
            innerIndex < bytes.count,
            SwiftTypeShortcuts.isGenericClosing(bytes[innerIndex])
        else {
            return nil
        }

        var result = "[\(typeArgs[0]): \(typeArgs[1])]"
        innerIndex += 1

        // Check for Optional suffix
        if SwiftTypeShortcuts.hasOptionalSuffix(bytes, at: innerIndex) {
            result += "?"
            innerIndex += 2
        }

        return (result, innerIndex)
    }

    /// Parse a nested Set type.
    private func parseNestedSet(
        bytes: [UInt8],
        index: Int,
        sourceOffset: Int,
        depth: Int
    ) -> (String, Int)? {
        var innerIndex = index + 3

        guard
            let (element, newIndex) = parseTypeArgWithRefs(
                bytes: bytes,
                startIndex: innerIndex,
                sourceOffset: sourceOffset,
                depth: depth + 1
            )
        else {
            return nil
        }

        innerIndex = newIndex

        guard innerIndex < bytes.count && SwiftTypeShortcuts.isGenericClosing(bytes[innerIndex]) else {
            return nil
        }

        var result = "Set<\(element)>"
        innerIndex += 1

        // Check for Optional suffix
        if SwiftTypeShortcuts.hasOptionalSuffix(bytes, at: innerIndex) {
            result += "?"
            innerIndex += 2
        }

        return (result, innerIndex)
    }

    /// Try to parse a type shortcut (single or two-character).
    private func tryParseTypeShortcut(bytes: [UInt8], index: Int, byte: UInt8) -> (String, Int)? {
        // Two-character standard types
        if index + 1 < bytes.count && byte == 0x53 {  // 'S' prefix
            let secondByte = bytes[index + 1]
            let twoChar = String(bytes: [byte, secondByte], encoding: .ascii) ?? ""

            if let typeName = SwiftTypeShortcuts.resolveStandardShortcut(twoChar) {
                return (typeName, index + 2)
            }
        }

        // Single-character shortcuts
        if let typeName = SwiftTypeShortcuts.resolveSingleCharShortcut(byte) {
            return (typeName, index + 1)
        }

        // Empty tuple marker 'y' (Void)
        if byte == 0x79 {  // 'y'
            return ("Void", index + 1)
        }

        return nil
    }

    /// Try to parse a length-prefixed type name.
    private func tryParseLengthPrefixedType(bytes: [UInt8], index: Int, byte: UInt8) -> (String, Int)? {
        guard SwiftTypeShortcuts.isDigit(byte) else {
            return nil
        }

        return parseLengthPrefixedType(bytes: bytes, startIndex: index)
    }

    /// Try to parse an ObjC imported type (So prefix).
    private func tryParseObjCImportedType(bytes: [UInt8], index: Int, byte: UInt8) -> (String, Int)? {
        guard byte == 0x53,
            index + 2 < bytes.count,
            bytes[index + 1] == 0x6F  // "So"
        else {
            return nil
        }

        guard
            let (typeName, parsedIndex) = parseLengthPrefixedType(
                bytes: bytes,
                startIndex: index + 2
            )
        else {
            return nil
        }

        var adjustedIndex = parsedIndex

        // Handle _p protocol existential suffix
        if adjustedIndex + 1 < bytes.count,
            bytes[adjustedIndex] == 0x5F,  // '_'
            bytes[adjustedIndex + 1] == 0x70  // 'p'
        {
            adjustedIndex += 2
        }

        return (typeName, adjustedIndex)
    }

    /// Parse a length-prefixed type name from bytes.
    func parseLengthPrefixedType(bytes: [UInt8], startIndex: Int) -> (String, Int)? {
        var index = startIndex
        var lengthStr = ""

        // Collect digits for length
        while index < bytes.count {
            let byte = bytes[index]
            guard SwiftTypeShortcuts.isDigit(byte) else {
                break
            }
            lengthStr.append(Character(UnicodeScalar(byte)))
            index += 1
        }

        guard let length = Int(lengthStr), length > 0, index + length <= bytes.count else {
            return nil
        }

        // Extract the type name
        let nameBytes = Array(bytes[index..<(index + length)])
        guard let name = String(bytes: nameBytes, encoding: .utf8) else {
            return nil
        }

        index += length

        // Skip type suffix markers (C, V, O, P)
        while index < bytes.count && SwiftTypeShortcuts.isTypeSuffixMarker(bytes[index]) {
            index += 1
        }

        return (name, index)
    }

    /// Fallback resolution that concatenates resolved refs (for complex cases).
    func resolveTypeWithEmbeddedRefsFallback(mangledData: Data, sourceOffset: Int) -> String {
        var result = ""
        let bytes = Array(mangledData)
        var i = 0

        while i < bytes.count {
            let byte = bytes[i]

            // Check for symbolic reference markers
            if SwiftSymbolicReferenceKind.isSymbolicMarker(byte) && i + 5 <= bytes.count {
                let refData = Data(bytes[i..<bytes.count])
                let refOffset = sourceOffset + i

                let resolved = resolveSymbolicReference(
                    kind: SwiftSymbolicReferenceKind(marker: byte),
                    data: refData,
                    sourceOffset: refOffset
                )

                if !resolved.isEmpty && !resolved.hasPrefix("/*") {
                    result += resolved
                }
                else {
                    result += "?"
                }

                i += 5
            }
            else if byte == 0 {
                // Null terminator
                break
            }
            else {
                // Regular character - only add if it's valid ASCII
                if byte >= 0x20 && byte < 0x7F {
                    result.append(Character(UnicodeScalar(byte)))
                }
                i += 1
            }
        }

        return SwiftDemangler.demangle(result)
    }
}
