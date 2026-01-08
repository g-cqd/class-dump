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
    /// This walks through the data, extracting regular text and resolving
    /// symbolic references inline.
    private func resolveTypeWithEmbeddedRefs(mangledData: Data, sourceOffset: Int) -> String {
        var result = ""
        let bytes = Array(mangledData)
        var i = 0

        while i < bytes.count {
            let byte = bytes[i]

            // Check for symbolic reference markers
            if (byte == 0x01 || byte == 0x02) && i + 5 <= bytes.count {
                // Extract the symbolic reference (5 bytes: marker + 4-byte offset)
                // We pass the rest of the buffer to allow resolving generic params that follow
                let refData = Data(bytes[i..<bytes.count])
                let refOffset = sourceOffset + i

                let resolved = resolveSymbolicReference(
                    kind: SwiftSymbolicReferenceKind(marker: byte),
                    data: refData,
                    sourceOffset: refOffset
                )

                // If we got a useful resolution, use it; otherwise use placeholder
                if !resolved.isEmpty && !resolved.hasPrefix("/*") {
                    result += resolved
                } else {
                    result += "?"  // Unknown embedded type
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

        // Now try to demangle the assembled string
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
