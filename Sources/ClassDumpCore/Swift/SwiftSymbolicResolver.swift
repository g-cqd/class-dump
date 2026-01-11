// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

/// Resolves Swift symbolic type references in binary metadata.
///
/// Swift type references are often stored as:
/// - A 1-byte marker (0x01-0x17) indicating the reference kind
/// - A 4-byte signed relative offset to the actual type descriptor
///
/// This actor resolves those references to actual type names.
///
/// ## Architecture
///
/// The resolver is organized into focused extensions:
/// - `SwiftSymbolicResolver+ContainerTypes.swift` - Container type parsing (Array, Dict, Set)
/// - `SwiftSymbolicResolver+ContextResolution.swift` - Context descriptor resolution
///
/// Related pure function enums:
/// - `SwiftSymbolicReferenceKind` - Reference kind enumeration
/// - `SwiftTypeShortcuts` - Type shortcut lookups
///
/// ## Thread Safety
///
/// This actor is thread-safe for concurrent access via Swift's actor model.
/// It maintains internal caches (`resolvedTypes`, `moduleNames`) that are
/// protected by actor isolation. Use `await` to access methods from any context.
public actor SwiftSymbolicResolver {

    // MARK: - Core State

    /// The raw binary data.
    private let data: Data

    /// All segment commands in the binary.
    let segments: [SegmentCommand]

    /// Byte order of the binary.
    let byteOrder: ByteOrder

    /// Chained fixups for resolving bind ordinals to symbol names.
    let chainedFixups: ChainedFixups?

    /// Count of bytes in data (cached for performance).
    var dataCount: Int { data.count }

    // MARK: - Caches

    /// Cache of resolved type names by their descriptor address.
    private var resolvedTypes: [Int: String] = [:]

    /// Cache of module names by their descriptor address.
    private var moduleNames: [Int: String] = [:]

    // MARK: - Initialization

    /// Initialize a symbolic resolver with binary data.
    ///
    /// - Parameters:
    ///   - data: The raw binary data.
    ///   - segments: Segment commands for address translation.
    ///   - byteOrder: Byte order of the binary.
    ///   - chainedFixups: Optional chained fixups for pointer resolution.
    public init(
        data: Data,
        segments: [SegmentCommand],
        byteOrder: ByteOrder,
        chainedFixups: ChainedFixups? = nil
    ) {
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

        let firstByte = mangledData[mangledData.startIndex]

        // Check for symbolic reference at start
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

        // Try to demangle as a regular mangled name
        if let mangledString = String(data: mangledData, encoding: .utf8) {
            return SwiftDemangler.demangle(mangledString)
        }

        return "/* unknown type */"
    }

    /// Check if data contains embedded symbolic references (0x01 or 0x02).
    func hasEmbeddedSymbolicRef(_ data: Data) -> Bool {
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

    // MARK: - Symbolic Reference Resolution

    /// Resolve a symbolic reference to a type name.
    ///
    /// - Parameters:
    ///   - kind: The kind of symbolic reference.
    ///   - mangledData: The full mangled data (including marker byte).
    ///   - sourceOffset: The file offset where the mangled data starts.
    /// - Returns: The resolved type name.
    public func resolveSymbolicReference(
        kind: SwiftSymbolicReferenceKind,
        data mangledData: Data,
        sourceOffset: Int
    ) -> String {
        // Need at least 5 bytes: 1 marker + 4 offset bytes
        guard mangledData.count >= 5 else {
            return "/* incomplete ref */"
        }

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

        // Cache and return
        resolvedTypes[targetOffset] = result
        return result
    }

    // MARK: - Cache Management

    /// Get a cached module name.
    func getCachedModuleName(at offset: Int) -> String? {
        moduleNames[offset]
    }

    /// Cache a module name.
    func cacheModuleName(_ name: String, at offset: Int) {
        moduleNames[offset] = name
    }

    // MARK: - Data Reading Helpers

    /// Read an unsigned 32-bit integer at the given offset.
    func readUInt32(at offset: Int) -> UInt32 {
        guard offset + 4 <= data.count else { return 0 }
        return data.withUnsafeBytes { ptr in
            byteOrder == .little
                ? ptr.loadUnaligned(fromByteOffset: offset, as: UInt32.self).littleEndian
                : ptr.loadUnaligned(fromByteOffset: offset, as: UInt32.self).bigEndian
        }
    }

    /// Read an unsigned 64-bit integer at the given offset.
    func readUInt64(at offset: Int) -> UInt64 {
        guard offset + 8 <= data.count else { return 0 }
        return data.withUnsafeBytes { ptr in
            byteOrder == .little
                ? ptr.loadUnaligned(fromByteOffset: offset, as: UInt64.self).littleEndian
                : ptr.loadUnaligned(fromByteOffset: offset, as: UInt64.self).bigEndian
        }
    }

    /// Read a relative pointer and return the target offset.
    func readRelativePointer(at fileOffset: Int) -> Int? {
        guard fileOffset + 4 <= data.count else { return nil }

        let relOffset: Int32 = data.withUnsafeBytes { ptr in
            byteOrder == .little
                ? ptr.loadUnaligned(fromByteOffset: fileOffset, as: Int32.self).littleEndian
                : ptr.loadUnaligned(fromByteOffset: fileOffset, as: Int32.self).bigEndian
        }

        let target = fileOffset + Int(relOffset)
        return target >= 0 ? target : nil
    }

    /// Read a null-terminated string via relative pointer.
    func readRelativeString(at fileOffset: Int) -> String? {
        guard let targetOffset = readRelativePointer(at: fileOffset) else {
            return nil
        }
        guard targetOffset >= 0, targetOffset < data.count else {
            return nil
        }

        var end = targetOffset
        while end < data.count, data[end] != 0 {
            end += 1
        }

        guard end > targetOffset else { return nil }
        let stringData = data.subdata(in: targetOffset..<end)
        return String(data: stringData, encoding: .utf8)
    }

    /// Read a null-terminated string at a virtual address.
    func readString(at address: UInt64) -> String? {
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

    /// Convert a virtual address to a file offset.
    func fileOffset(for address: UInt64) -> Int? {
        for segment in segments {
            if let offset = segment.fileOffset(for: address) {
                return Int(offset)
            }
        }
        return nil
    }
}
