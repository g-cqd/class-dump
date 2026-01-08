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
public final class SwiftSymbolicResolver {
    private let data: Data
    private let segments: [SegmentCommand]
    private let byteOrder: ByteOrder

    /// Cache of resolved type names by their descriptor address.
    private var resolvedTypes: [Int: String] = [:]

    /// Cache of module names by their descriptor address.
    private var moduleNames: [Int: String] = [:]

    public init(data: Data, segments: [SegmentCommand], byteOrder: ByteOrder) {
        self.data = data
        self.segments = segments
        self.byteOrder = byteOrder
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

        // Check if this is a symbolic reference
        let firstByte = mangledData[mangledData.startIndex]
        if SwiftSymbolicReferenceKind.isSymbolicMarker(firstByte) {
            return resolveSymbolicReference(
                kind: SwiftSymbolicReferenceKind(marker: firstByte),
                data: mangledData,
                sourceOffset: sourceOffset
            )
        }

        // Otherwise try to demangle as a regular mangled name
        if let mangledString = String(data: mangledData, encoding: .utf8) {
            return SwiftDemangler.demangle(mangledString)
        }

        return "/* unknown type */"
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

        // Read descriptor flags to determine kind
        let flags = readUInt32(at: offset)
        let kind = flags & 0x1F  // Lower 5 bits are the kind

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
            let suffix = resolveGenericSuffix(mangledData: mangledData)
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
    private func resolveGenericSuffix(mangledData: Data) -> String {
        guard mangledData.count > 5 else { return "" }

        let suffix = mangledData.subdata(in: 5..<mangledData.count)

        // Check for common patterns
        // "Sg" = Optional wrapper
        // "yG" = Generic type
        if let suffixStr = String(data: suffix, encoding: .utf8) {
            if suffixStr.hasSuffix("Sg") || suffixStr.contains("Sg") {
                return "?"  // Optional
            }
            if suffixStr.hasPrefix("y") {
                // Generic parameter - try to parse
                let params = suffixStr.dropFirst()
                if !params.isEmpty {
                    let demangled = SwiftDemangler.demangle(String(params))
                    if demangled != String(params) {
                        return "<\(demangled)>"
                    }
                }
            }
        }

        return ""
    }

    // MARK: - Helper Methods

    private func contextKindName(_ kind: UInt32) -> String {
        switch kind {
        case 0: return ""  // Module
        case 1: return ""  // Extension
        case 2: return ""  // Anonymous
        case 16: return ""  // Class
        case 17: return ""  // Struct
        case 18: return ""  // Enum
        case 19: return ""  // Protocol
        case 20: return ""  // TypeAlias
        case 21: return ""  // OpaqueType
        default: return ""
        }
    }

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
