// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

/// Symbolic reference kinds in Swift metadata.
///
/// Swift uses symbolic references (0x01-0x17) to point to type metadata
/// via relative offsets. This allows compact encoding of type information.
public enum SwiftSymbolicReferenceKind: UInt8 {
    /// Direct reference to a context descriptor.
    case directContext = 0x01

    /// Indirect reference through a pointer to a context descriptor.
    case indirectContext = 0x02

    /// Direct reference to an Objective-C protocol.
    case directObjCProtocol = 0x09

    /// Unknown/invalid reference.
    case unknown = 0xFF

    public init(marker: UInt8) {
        switch marker {
        case 0x01: self = .directContext
        case 0x02: self = .indirectContext
        case 0x09: self = .directObjCProtocol
        default: self = .unknown
        }
    }

    /// Check if a byte is a symbolic reference marker.
    public static func isSymbolicMarker(_ byte: UInt8) -> Bool {
        byte >= 0x01 && byte <= 0x17
    }
}

/// Resolves Swift symbolic type references in binary metadata.
///
/// Swift type references are often stored as:
/// - A 1-byte marker (0x01-0x17) indicating the reference kind
/// - A 4-byte signed relative offset to the actual type descriptor
///
/// This class resolves those references to actual type names.
///
/// ## Thread Safety
///
/// This class is **not thread-safe** for concurrent access. It maintains internal caches
/// (`resolvedTypes`, `moduleNames`) that are mutated during resolution.
///
/// **Usage Pattern**: Create an instance per processing task and use it from a single thread.
/// The resolved type names can then be safely shared as they are plain `String` values.
public final class SwiftSymbolicResolver {
    private let data: Data
    private let segments: [SegmentCommand]
    private let byteOrder: ByteOrder
    private let chainedFixups: ChainedFixups?

    /// Cache of resolved type names by their descriptor address.
    private var resolvedTypes: [Int: String] = [:]

    /// Cache of module names by their descriptor address.
    private var moduleNames: [Int: String] = [:]

    public init(data: Data, segments: [SegmentCommand], byteOrder: ByteOrder, chainedFixups: ChainedFixups? = nil) {
        self.data = data
        self.segments = segments
        self.byteOrder = byteOrder
        self.chainedFixups = chainedFixups
    }

    // MARK: - Public API

    /// Resolve a mangled type name that may contain symbolic references.
    ///
    /// - Parameters:
    ///   - mangledData: The raw bytes of the mangled type name.
    ///   - sourceOffset: The file offset where this mangled name starts.
    /// - Returns: A human-readable type name.
    public func resolveType(mangledData: Data, sourceOffset: Int) -> String {
        guard !mangledData.isEmpty else { return "" }

        // Check if this is a symbolic reference at the start
        let firstByte = mangledData[mangledData.startIndex]
        if SwiftSymbolicReferenceKind.isSymbolicMarker(firstByte) {
            return resolveSymbolicReference(
                kind: SwiftSymbolicReferenceKind(marker: firstByte),
                data: mangledData,
                sourceOffset: sourceOffset
            )
        }

        // Check for embedded symbolic references
        if hasEmbeddedSymbolicRef(mangledData) {
            return resolveTypeWithEmbeddedRefs(mangledData: mangledData, sourceOffset: sourceOffset)
        }

        // Otherwise try to demangle as a regular mangled name
        if let mangledString = String(data: mangledData, encoding: .utf8) {
            return SwiftDemangler.demangle(mangledString)
        }

        return "/* unknown type */"
    }

    /// Check if data contains embedded symbolic references (0x01 or 0x02).
    private func hasEmbeddedSymbolicRef(_ data: Data) -> Bool {
        guard data.count >= 6 else { return false }
        let bytes = Array(data)
        // Look for symbolic reference markers after the first byte
        for i in 1..<bytes.count {
            let byte = bytes[i]
            if byte == 0x01 || byte == 0x02 {
                return true
            }
        }
        return false
    }

    /// Resolve a mangled type that contains embedded symbolic references.
    ///
    /// This intelligently parses container types (Array, Dictionary, Set) and resolves
    /// symbolic references for each type argument, producing properly formatted output.
    private func resolveTypeWithEmbeddedRefs(mangledData: Data, sourceOffset: Int) -> String {
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
    private func parseContainerTypeWithRefs(bytes: [UInt8], sourceOffset: Int) -> String? {
        guard bytes.count >= 3 else { return nil }

        // Check for Array: Say...G
        if bytes.count >= 4, bytes[0] == 0x53, bytes[1] == 0x61, bytes[2] == 0x79 {  // "Say"
            var index = 3
            if let (element, newIndex) = parseTypeArgWithRefs(
                bytes: bytes, startIndex: index, sourceOffset: sourceOffset)
            {
                index = newIndex
                // Check for closing 'G'
                if index < bytes.count && bytes[index] == 0x47 {  // 'G'
                    var result = "[\(element)]"
                    index += 1
                    // Check for Optional suffix
                    if index + 1 < bytes.count && bytes[index] == 0x53 && bytes[index + 1] == 0x67 {  // "Sg"
                        result += "?"
                    }
                    return result
                }
            }
        }

        // Check for Dictionary: SDy...G
        if bytes.count >= 4, bytes[0] == 0x53, bytes[1] == 0x44, bytes[2] == 0x79 {  // "SDy"
            var index = 3
            var typeArgs: [String] = []

            // Parse key and value types
            while typeArgs.count < 2 && index < bytes.count {
                if let (arg, newIndex) = parseTypeArgWithRefs(
                    bytes: bytes, startIndex: index, sourceOffset: sourceOffset)
                {
                    typeArgs.append(arg)
                    index = newIndex
                } else {
                    break
                }
            }

            // Check for closing 'G'
            if typeArgs.count == 2 && index < bytes.count && bytes[index] == 0x47 {  // 'G'
                var result = "[\(typeArgs[0]): \(typeArgs[1])]"
                index += 1
                // Check for Optional suffix
                if index + 1 < bytes.count && bytes[index] == 0x53 && bytes[index + 1] == 0x67 {  // "Sg"
                    result += "?"
                }
                return result
            }
        }

        // Check for Set: Shy...G
        if bytes.count >= 4, bytes[0] == 0x53, bytes[1] == 0x68, bytes[2] == 0x79 {  // "Shy"
            var index = 3
            if let (element, newIndex) = parseTypeArgWithRefs(
                bytes: bytes, startIndex: index, sourceOffset: sourceOffset)
            {
                index = newIndex
                // Check for closing 'G'
                if index < bytes.count && bytes[index] == 0x47 {  // 'G'
                    var result = "Set<\(element)>"
                    index += 1
                    // Check for Optional suffix
                    if index + 1 < bytes.count && bytes[index] == 0x53 && bytes[index + 1] == 0x67 {  // "Sg"
                        result += "?"
                    }
                    return result
                }
            }
        }

        // Check for direct symbolic reference at start (the most common case)
        if bytes.count >= 5 && SwiftSymbolicReferenceKind.isSymbolicMarker(bytes[0]) {
            let refData = Data(bytes)
            var result = resolveSymbolicReference(
                kind: SwiftSymbolicReferenceKind(marker: bytes[0]),
                data: refData,
                sourceOffset: sourceOffset
            )

            // Check for trailing Optional suffix
            if bytes.count >= 7 && bytes[5] == 0x53 && bytes[6] == 0x67 {  // "Sg"
                if !result.hasPrefix("/*") {
                    result += "?"
                }
            }

            if !result.isEmpty && !result.hasPrefix("/*") {
                return result
            }
        }

        return nil
    }

    /// Parse a single type argument which may be a symbolic reference or standard mangled type.
    ///
    /// - Returns: Tuple of (resolved type name, new index after parsing) or nil.
    private func parseTypeArgWithRefs(bytes: [UInt8], startIndex: Int, sourceOffset: Int, depth: Int = 0) -> (
        String, Int
    )? {
        guard startIndex < bytes.count else { return nil }
        guard depth < 10 else { return nil }  // Prevent infinite recursion

        let index = startIndex
        let byte = bytes[index]

        // Check for symbolic reference
        if SwiftSymbolicReferenceKind.isSymbolicMarker(byte) && index + 5 <= bytes.count {
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

        // Check for nested Array: Say...G
        if index + 3 < bytes.count && byte == 0x53 && bytes[index + 1] == 0x61 && bytes[index + 2] == 0x79 {  // "Say"
            var innerIndex = index + 3
            if let (element, newIndex) = parseTypeArgWithRefs(
                bytes: bytes, startIndex: innerIndex, sourceOffset: sourceOffset, depth: depth + 1)
            {
                innerIndex = newIndex
                // Check for closing 'G'
                if innerIndex < bytes.count && bytes[innerIndex] == 0x47 {  // 'G'
                    var result = "[\(element)]"
                    innerIndex += 1
                    // Check for Optional suffix "Sg"
                    if innerIndex + 1 < bytes.count && bytes[innerIndex] == 0x53 && bytes[innerIndex + 1] == 0x67 {
                        result += "?"
                        innerIndex += 2
                    }
                    return (result, innerIndex)
                }
            }
        }

        // Check for nested Dictionary: SDy...G
        if index + 3 < bytes.count && byte == 0x53 && bytes[index + 1] == 0x44 && bytes[index + 2] == 0x79 {  // "SDy"
            var innerIndex = index + 3
            var typeArgs: [String] = []

            // Parse key and value types
            while typeArgs.count < 2 && innerIndex < bytes.count {
                if let (arg, newIndex) = parseTypeArgWithRefs(
                    bytes: bytes, startIndex: innerIndex, sourceOffset: sourceOffset, depth: depth + 1)
                {
                    typeArgs.append(arg)
                    innerIndex = newIndex
                } else {
                    break
                }
            }

            // Check for closing 'G'
            if typeArgs.count == 2 && innerIndex < bytes.count && bytes[innerIndex] == 0x47 {  // 'G'
                var result = "[\(typeArgs[0]): \(typeArgs[1])]"
                innerIndex += 1
                // Check for Optional suffix
                if innerIndex + 1 < bytes.count && bytes[innerIndex] == 0x53 && bytes[innerIndex + 1] == 0x67 {  // "Sg"
                    result += "?"
                    innerIndex += 2
                }
                return (result, innerIndex)
            }
        }

        // Check for nested Set: Shy...G
        if index + 3 < bytes.count && byte == 0x53 && bytes[index + 1] == 0x68 && bytes[index + 2] == 0x79 {  // "Shy"
            var innerIndex = index + 3
            if let (element, newIndex) = parseTypeArgWithRefs(
                bytes: bytes, startIndex: innerIndex, sourceOffset: sourceOffset, depth: depth + 1)
            {
                innerIndex = newIndex
                // Check for closing 'G'
                if innerIndex < bytes.count && bytes[innerIndex] == 0x47 {  // 'G'
                    var result = "Set<\(element)>"
                    innerIndex += 1
                    // Check for Optional suffix "Sg"
                    if innerIndex + 1 < bytes.count && bytes[innerIndex] == 0x53 && bytes[innerIndex + 1] == 0x67 {
                        result += "?"
                        innerIndex += 2
                    }
                    return (result, innerIndex)
                }
            }
        }

        // Check for two-character standard types (SS, Si, Sb, Sd, Sf, Su)
        if index + 1 < bytes.count && byte == 0x53 {  // 'S' prefix
            let secondByte = bytes[index + 1]
            let twoChar = String(bytes: [byte, secondByte], encoding: .ascii) ?? ""

            if let typeName = resolveStandardTypeShortcut(twoChar) {
                return (typeName, index + 2)
            }
        }

        // Check for single-character shortcuts (but not 'S' which needs 2 chars)
        if let typeName = resolveSingleCharTypeShortcut(byte) {
            return (typeName, index + 1)
        }

        // Check for empty tuple marker 'y' (used for Void in function types)
        if byte == 0x79 {  // 'y'
            return ("Void", index + 1)
        }

        // Check for length-prefixed type name (starts with digit)
        if byte >= 0x30 && byte <= 0x39 {  // '0'-'9'
            if let (typeName, newIndex) = parseLengthPrefixedType(bytes: bytes, startIndex: index) {
                return (typeName, newIndex)
            }
        }

        // Check for ObjC imported type (So prefix)
        if byte == 0x53 && index + 2 < bytes.count && bytes[index + 1] == 0x6F {  // "So"
            if let (typeName, parsedIndex) = parseLengthPrefixedType(bytes: bytes, startIndex: index + 2) {
                var adjustedIndex = parsedIndex
                // Handle _p protocol existential suffix
                if adjustedIndex + 1 < bytes.count && bytes[adjustedIndex] == 0x5F
                    && bytes[adjustedIndex + 1] == 0x70
                {  // "_p"
                    adjustedIndex += 2
                }
                return (typeName, adjustedIndex)
            }
        }

        return nil
    }

    /// Resolve a standard two-character type shortcut.
    private func resolveStandardTypeShortcut(_ chars: String) -> String? {
        switch chars {
        case "SS": return "String"
        case "Si": return "Int"
        case "Su": return "UInt"
        case "Sb": return "Bool"
        case "Sd": return "Double"
        case "Sf": return "Float"
        case "Sg": return nil  // This is Optional suffix, not a type
        default: return nil
        }
    }

    /// Resolve a single-character type shortcut (lowercase letters mostly).
    private func resolveSingleCharTypeShortcut(_ byte: UInt8) -> String? {
        switch byte {
        case 0x61: return "Array"  // 'a'
        case 0x62: return "Bool"  // 'b'
        case 0x44: return "Dictionary"  // 'D'
        case 0x64: return "Double"  // 'd'
        case 0x66: return "Float"  // 'f'
        case 0x68: return "Set"  // 'h'
        case 0x69: return "Int"  // 'i'
        case 0x75: return "UInt"  // 'u'
        default: return nil
        }
    }

    /// Parse a length-prefixed type name from bytes.
    private func parseLengthPrefixedType(bytes: [UInt8], startIndex: Int) -> (String, Int)? {
        var index = startIndex
        var lengthStr = ""

        // Collect digits for length
        while index < bytes.count {
            let byte = bytes[index]
            if byte >= 0x30 && byte <= 0x39 {  // '0'-'9'
                lengthStr.append(Character(UnicodeScalar(byte)))
                index += 1
            } else {
                break
            }
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
        while index < bytes.count {
            let byte = bytes[index]
            if byte == 0x43 || byte == 0x56 || byte == 0x4F || byte == 0x50 {  // C, V, O, P
                index += 1
            } else {
                break
            }
        }

        return (name, index)
    }

    /// Fallback resolution that concatenates resolved refs (for complex cases).
    private func resolveTypeWithEmbeddedRefsFallback(mangledData: Data, sourceOffset: Int) -> String {
        var result = ""
        let bytes = Array(mangledData)
        var i = 0

        while i < bytes.count {
            let byte = bytes[i]

            // Check for symbolic reference markers
            if SwiftSymbolicReferenceKind.isSymbolicMarker(byte) && i + 5 <= bytes.count {
                // Extract the symbolic reference (5 bytes: marker + 4-byte offset)
                let refData = Data(bytes[i..<bytes.count])
                let refOffset = sourceOffset + i

                let resolved = resolveSymbolicReference(
                    kind: SwiftSymbolicReferenceKind(marker: byte),
                    data: refData,
                    sourceOffset: refOffset
                )

                // If we got a useful resolution, use it
                if !resolved.isEmpty && !resolved.hasPrefix("/*") {
                    result += resolved
                } else {
                    result += "?"
                }

                // Skip the 5-byte symbolic reference
                i += 5
            } else if byte == 0 {
                // Null terminator - stop
                break
            } else {
                // Regular character - only add if it's a valid ASCII character
                if byte >= 0x20 && byte < 0x7F {
                    result.append(Character(UnicodeScalar(byte)))
                }
                i += 1
            }
        }

        // Try to demangle the assembled string
        return SwiftDemangler.demangle(result)
    }

    /// Resolve a symbolic reference to a type name.
    ///
    /// - Parameters:
    ///   - kind: The kind of symbolic reference.
    ///   - data: The full mangled data (including marker byte).
    ///   - sourceOffset: The file offset where the mangled data starts.
    /// - Returns: The resolved type name.
    public func resolveSymbolicReference(
        kind: SwiftSymbolicReferenceKind,
        data mangledData: Data,
        sourceOffset: Int
    ) -> String {
        // Need at least 5 bytes: 1 marker + 4 offset bytes
        guard mangledData.count >= 5 else { return "/* incomplete ref */" }

        // Read the 4-byte relative offset (little-endian signed)
        let offsetBytes = mangledData.subdata(in: 1..<5)
        let relativeOffset = offsetBytes.withUnsafeBytes { ptr in
            ptr.loadUnaligned(fromByteOffset: 0, as: Int32.self).littleEndian
        }

        // Calculate target address: source + 1 (for marker) + relativeOffset
        let targetOffset = sourceOffset + 1 + Int(relativeOffset)

        // Check cache
        if let cached = resolvedTypes[targetOffset] {
            return cached
        }

        // Resolve based on kind
        let result: String
        switch kind {
        case .directContext:
            result = resolveContextDescriptor(at: targetOffset, mangledData: mangledData)
        case .indirectContext:
            result = resolveIndirectContextDescriptor(at: targetOffset, mangledData: mangledData)
        case .directObjCProtocol:
            result = resolveObjCProtocol(at: targetOffset)
        case .unknown:
            result = "/* unknown ref 0x\(String(format: "%02x", mangledData[mangledData.startIndex])) */"
        }

        resolvedTypes[targetOffset] = result
        return result
    }

    // MARK: - Context Descriptor Resolution

    /// Resolve a direct context descriptor reference.
    private func resolveContextDescriptor(at offset: Int, mangledData: Data) -> String {
        guard offset >= 0, offset + 16 <= data.count else {
            return "/* invalid offset: \(offset) */"
        }

        // Try to read the name
        // For nominal types, the name is at offset 8 (after Flags and Parent)
        // as a relative pointer
        let nameOffset = offset + 8
        guard let name = readRelativeString(at: nameOffset), !name.isEmpty else {
            // Try alternate layout - sometimes name is at offset 12
            let altNameOffset = offset + 12
            if let altName = readRelativeString(at: altNameOffset), !altName.isEmpty {
                return altName
            }
            return resolveFromMangledSuffix(mangledData)
        }

        // Try to get the module/parent name
        let parentOffset = offset + 4
        let parentName = resolveParentContext(at: parentOffset)

        // Build the full type name
        let fullName: String
        if let parent = parentName, !parent.isEmpty, parent != "Swift" {
            fullName = "\(parent).\(name)"
        } else {
            fullName = name
        }

        // Handle generic types - check if there's more data after the symbolic ref
        if mangledData.count > 5 {
            let (suffix, _) = resolveGenericSuffix(mangledData: mangledData, offset: offset + 5)
            if !suffix.isEmpty {
                return "\(fullName)\(suffix)"
            }
        }

        return fullName
    }

    /// Resolve an indirect context descriptor (pointer to pointer).
    ///
    /// Indirect references (0x02) point to a location that contains a pointer
    /// to the actual type context descriptor. This is typically used for
    /// external types from other modules.
    private func resolveIndirectContextDescriptor(at offset: Int, mangledData: Data) -> String {
        guard offset >= 0, offset + 8 <= data.count else {
            return "/* invalid indirect offset */"
        }

        // The offset points to a GOT-like entry containing a pointer
        // First try reading it as a 64-bit pointer (most common case)
        let targetPointer = readUInt64(at: offset)

        // Check for chained fixups
        if let fixups = chainedFixups {
            let result = fixups.decodePointer(targetPointer)
            switch result {
            case .bind(let ordinal, _):
                // It's bound to an external symbol
                if let symbolName = fixups.symbolName(forOrdinal: ordinal) {
                    // Symbol name like _$s10Foundation4DateV...
                    // We can demangle this directly
                    return SwiftDemangler.extractTypeName(symbolName)
                }
            case .rebase(let target):
                // It's a rebase to a local address
                if let fileOff = self.fileOffset(for: target) {
                    return resolveContextDescriptor(at: fileOff, mangledData: mangledData)
                }
            case .notFixup:
                break  // Fall through to standard handling
            }
        }

        // If the pointer is 0, this is likely an unresolved external reference
        if targetPointer == 0 {
            // Try to get the type from mangled suffix if available
            if mangledData.count > 5 {
                return resolveFromMangledSuffix(mangledData)
            }
            return "/* external type */"
        }

        // Convert VM address to file offset
        if let fileOff = self.fileOffset(for: targetPointer) {
            return resolveContextDescriptor(at: fileOff, mangledData: mangledData)
        }

        // The pointer might already be a file offset in some cases
        if targetPointer < UInt64(data.count) {
            return resolveContextDescriptor(at: Int(targetPointer), mangledData: mangledData)
        }

        // Try reading as a 32-bit pointer (for 32-bit binaries)
        let targetPointer32 = readUInt32(at: offset)
        if targetPointer32 != 0 {
            if let fileOff = self.fileOffset(for: UInt64(targetPointer32)) {
                return resolveContextDescriptor(at: fileOff, mangledData: mangledData)
            }
        }

        // Try to extract from mangled suffix
        if mangledData.count > 5 {
            return resolveFromMangledSuffix(mangledData)
        }

        return "/* unresolved indirect */"
    }

    /// Resolve an Objective-C protocol reference.
    private func resolveObjCProtocol(at offset: Int) -> String {
        guard offset >= 0, offset + 8 <= data.count else {
            return "/* invalid protocol offset */"
        }

        // Try to read the protocol name as a C string pointer
        let namePointer = readUInt64(at: offset)
        if let name = readString(at: namePointer) {
            return name
        }

        // Try as a relative pointer
        if let name = readRelativeString(at: offset) {
            return name
        }

        return "/* unknown protocol */"
    }

    /// Resolve the parent context (module or enclosing type).
    private func resolveParentContext(at offset: Int) -> String? {
        guard let parentDescOffset = readRelativePointer(at: offset) else { return nil }

        // Check cache
        if let cached = moduleNames[parentDescOffset] {
            return cached
        }

        guard parentDescOffset > 0, parentDescOffset + 8 <= data.count else { return nil }

        // Read parent flags
        let flags = readUInt32(at: parentDescOffset)
        let kind = flags & 0x1F

        // If it's a module (kind 0), read the module name
        if kind == 0 {
            // Module descriptor: Flags, Parent, Name
            let nameOffset = parentDescOffset + 8
            if let name = readRelativeString(at: nameOffset) {
                moduleNames[parentDescOffset] = name
                return name
            }
        }

        // Otherwise it might be an enclosing type
        let nameOffset = parentDescOffset + 8
        if let name = readRelativeString(at: nameOffset) {
            moduleNames[parentDescOffset] = name
            return name
        }

        return nil
    }

    /// Try to extract type name from mangled suffix after symbolic ref.
    private func resolveFromMangledSuffix(_ mangledData: Data) -> String {
        guard mangledData.count > 5 else { return "/* type */" }

        // The data after the 5-byte symbolic ref might be mangled type info
        let suffix = mangledData.subdata(in: 5..<mangledData.count)
        if let suffixStr = String(data: suffix, encoding: .utf8) {
            return SwiftDemangler.demangle(suffixStr)
        }

        return "/* type */"
    }

    /// Resolve generic type parameters from mangled suffix.
    /// - Returns: Tuple of (resolved string, bytes consumed)
    private func resolveGenericSuffix(mangledData: Data, offset: Int) -> (String, Int) {
        guard mangledData.count > 5 else { return ("", 0) }

        let suffix = mangledData.subdata(in: 5..<mangledData.count)

        // If the suffix contains embedded symbolic references, we need to resolve them first
        if hasEmbeddedSymbolicRef(suffix) {
            let resolvedSuffix = resolveTypeWithEmbeddedRefs(mangledData: suffix, sourceOffset: offset)

            // Now check for generic pattern in the resolved string
            if resolvedSuffix.hasPrefix("y") {
                var params = resolvedSuffix.dropFirst()
                if params.hasSuffix("G") {
                    params = params.dropLast()
                }

                if !params.isEmpty {
                    let demangled = SwiftDemangler.demangleComplexType(String(params))
                    return ("<\(demangled)>", suffix.count)
                }
            }

            return ("", 0)
        }

        // Check for common patterns
        // "Sg" = Optional wrapper
        // "yG" = Generic type
        if let suffixStr = String(data: suffix, encoding: .utf8) {
            if suffixStr.hasSuffix("Sg") || suffixStr.contains("Sg") {
                return ("?", suffix.count)  // Assume it consumes all
            }
            if suffixStr.hasPrefix("y") {
                // Generic parameter - try to parse
                var params = suffixStr.dropFirst()
                if params.hasSuffix("G") {
                    params = params.dropLast()
                }
                if !params.isEmpty {
                    let demangled = SwiftDemangler.demangleComplexType(String(params))
                    if demangled != String(params) || !demangled.isEmpty {
                        return ("<\(demangled)>", suffix.count)
                    }
                }
            }
        }

        return ("", 0)
    }

    // MARK: - Helper Methods

    private func readUInt32(at offset: Int) -> UInt32 {
        guard offset + 4 <= data.count else { return 0 }
        return data.withUnsafeBytes { ptr in
            byteOrder == .little
                ? ptr.loadUnaligned(fromByteOffset: offset, as: UInt32.self).littleEndian
                : ptr.loadUnaligned(fromByteOffset: offset, as: UInt32.self).bigEndian
        }
    }

    private func readUInt64(at offset: Int) -> UInt64 {
        guard offset + 8 <= data.count else { return 0 }
        return data.withUnsafeBytes { ptr in
            byteOrder == .little
                ? ptr.loadUnaligned(fromByteOffset: offset, as: UInt64.self).littleEndian
                : ptr.loadUnaligned(fromByteOffset: offset, as: UInt64.self).bigEndian
        }
    }

    private func readRelativePointer(at fileOffset: Int) -> Int? {
        guard fileOffset + 4 <= data.count else { return nil }

        let relOffset: Int32 = data.withUnsafeBytes { ptr in
            byteOrder == .little
                ? ptr.loadUnaligned(fromByteOffset: fileOffset, as: Int32.self).littleEndian
                : ptr.loadUnaligned(fromByteOffset: fileOffset, as: Int32.self).bigEndian
        }

        let target = fileOffset + Int(relOffset)
        return target >= 0 ? target : nil
    }

    private func readRelativeString(at fileOffset: Int) -> String? {
        guard let targetOffset = readRelativePointer(at: fileOffset) else { return nil }
        guard targetOffset >= 0, targetOffset < data.count else { return nil }

        var end = targetOffset
        while end < data.count, data[end] != 0 {
            end += 1
        }

        guard end > targetOffset else { return nil }
        let stringData = data.subdata(in: targetOffset..<end)
        return String(data: stringData, encoding: .utf8)
    }

    private func readString(at address: UInt64) -> String? {
        guard address != 0 else { return nil }
        guard let offset = fileOffset(for: address) else { return nil }
        guard offset >= 0, offset < data.count else { return nil }

        var end = offset
        while end < data.count, data[end] != 0 {
            end += 1
        }

        guard end > offset else { return nil }
        let stringData = data.subdata(in: offset..<end)
        return String(data: stringData, encoding: .utf8)
    }

    private func fileOffset(for address: UInt64) -> Int? {
        for segment in segments {
            if let offset = segment.fileOffset(for: address) {
                return Int(offset)
            }
        }
        return nil
    }
}

// Note: SwiftMetadataProcessor extension moved to SwiftMetadataProcessor.swift
// to access private properties.
