// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

/// Processes Swift metadata from Mach-O binaries.
///
/// This processor extracts Swift type information from the `__swift5_*` sections:
/// - `__swift5_types`: Type context descriptors (classes, structs, enums)
/// - `__swift5_fieldmd`: Field descriptors (properties, enum cases)
/// - `__swift5_protos`: Protocol descriptors
/// - `__swift5_proto`: Protocol conformance records
/// - `__swift5_typeref`: Type reference strings
/// - `__swift5_reflstr`: Reflection strings (field names)
///
/// ## Thread Safety
///
/// This class is **not thread-safe** for concurrent access. It maintains internal caches
/// (`fieldDescriptorsByType`, `typeNamesByAddress`) that are mutated during processing.
///
/// **Usage Pattern**: Create an instance, call `process()` once, then safely share
/// the resulting `SwiftMetadata` struct (which is `Sendable`). Do not call processing methods
/// concurrently from multiple tasks.
public final class SwiftMetadataProcessor {

    // MARK: - Properties

    let data: Data
    let segments: [SegmentCommand]
    let byteOrder: ByteOrder
    let is64Bit: Bool
    let chainedFixups: ChainedFixups?

    /// Cache of field descriptors by mangled type name.
    private var fieldDescriptorsByType: [String: SwiftFieldDescriptor] = [:]

    /// Cache of type names by address (for resolving type refs).
    private var typeNamesByAddress: [UInt64: String] = [:]

    // MARK: - Initialization

    /// Initialize the Swift metadata processor.
    public init(
        data: Data,
        segments: [SegmentCommand],
        byteOrder: ByteOrder,
        is64Bit: Bool,
        chainedFixups: ChainedFixups? = nil
    ) {
        self.data = data
        self.segments = segments
        self.byteOrder = byteOrder
        self.is64Bit = is64Bit
        self.chainedFixups = chainedFixups
    }

    /// Convenience initializer from a MachOFile.
    public convenience init(machOFile: MachOFile) {
        let fixups = try? machOFile.parseChainedFixups()
        self.init(
            data: machOFile.data,
            segments: machOFile.segments,
            byteOrder: machOFile.byteOrder,
            is64Bit: machOFile.uses64BitABI,
            chainedFixups: fixups
        )
    }

    // MARK: - Public API

    /// Check if this binary contains Swift metadata.
    public var hasSwiftMetadata: Bool {
        findSection(segment: "__TEXT", section: "__swift5_types") != nil
            || findSection(segment: "__TEXT", section: "__swift5_fieldmd") != nil
    }

    /// Process all Swift metadata from the binary.
    ///
    /// This is the main entry point for extracting Swift metadata.
    /// It parses all sections and returns a complete `SwiftMetadata` result.
    ///
    /// - Returns: Parsed Swift metadata.
    public func process() throws -> SwiftMetadata {
        // Parse field descriptors first (needed for type field resolution)
        let fieldDescriptors = try parseFieldDescriptors()

        // Build lookup cache
        fieldDescriptorsByType = SwiftFieldDescriptorCache.buildIndex(from: fieldDescriptors)

        // Parse types and extensions together (they're in the same section)
        let (types, extensions) = try parseTypesAndExtensions()

        // Parse protocols
        let protocols = try parseProtocols()

        // Parse conformances
        let conformances = try parseConformances()

        return SwiftMetadata(
            types: types,
            protocols: protocols,
            conformances: conformances,
            fieldDescriptors: fieldDescriptors,
            extensions: extensions
        )
    }

    /// Look up field information for a mangled type name.
    ///
    /// This can be used to resolve Swift ivar types that ObjC runtime doesn't provide.
    public func fieldDescriptor(forMangledType mangledType: String) -> SwiftFieldDescriptor? {
        fieldDescriptorsByType[mangledType]
    }

    /// Resolve a field's mangled type name using the symbolic resolver.
    ///
    /// - Parameters:
    ///   - mangledTypeName: The mangled type name (may contain symbolic refs).
    ///   - sourceOffset: The file offset where this name was read.
    /// - Returns: A human-readable type name.
    public func resolveFieldType(_ mangledTypeName: String, at sourceOffset: Int) async -> String {
        guard !mangledTypeName.isEmpty else { return "" }

        // Check if it starts with a symbolic reference marker
        if let firstByte = mangledTypeName.utf8.first,
            SwiftSymbolicReferenceKind.isSymbolicMarker(firstByte)
        {
            let resolver = SwiftSymbolicResolver(
                data: data,
                segments: segments,
                byteOrder: byteOrder,
                chainedFixups: chainedFixups
            )

            if let mangledData = mangledTypeName.data(using: .utf8) {
                return await resolver.resolveType(mangledData: mangledData, sourceOffset: sourceOffset)
            }
        }

        // Fall back to regular demangling
        return SwiftDemangler.demangle(mangledTypeName)
    }

    /// Resolve a field's mangled type using raw data bytes.
    ///
    /// This is more reliable than string-based resolution for symbolic references.
    ///
    /// - Parameters:
    ///   - mangledData: Raw bytes of the mangled type name.
    ///   - sourceOffset: The file offset where this data was read.
    /// - Returns: A human-readable type name.
    public func resolveFieldTypeFromData(_ mangledData: Data, at sourceOffset: Int) async -> String {
        guard !mangledData.isEmpty else { return "" }

        let firstByte = mangledData[mangledData.startIndex]

        // Check if it starts with a symbolic reference marker
        if SwiftSymbolicReferenceKind.isSymbolicMarker(firstByte) {
            let resolver = SwiftSymbolicResolver(
                data: data,
                segments: segments,
                byteOrder: byteOrder,
                chainedFixups: chainedFixups
            )
            return await resolver.resolveType(mangledData: mangledData, sourceOffset: sourceOffset)
        }

        // Fall back to regular demangling
        if let str = String(data: mangledData, encoding: .utf8) {
            return SwiftDemangler.demangle(str)
        }

        return ""
    }

    // MARK: - Section Finding

    /// Find a section by segment and section name.
    ///
    /// Pure lookup function.
    ///
    /// - Parameters:
    ///   - segmentName: Name of the segment.
    ///   - sectionName: Name of the section.
    /// - Returns: The section if found.
    func findSection(segment segmentName: String, section sectionName: String) -> Section? {
        for segment in segments where segment.name == segmentName {
            if let section = segment.sections.first(where: { $0.sectionName == sectionName }) {
                return section
            }
        }
        return nil
    }

    /// Read section data.
    ///
    /// - Parameter section: The section to read.
    /// - Returns: Raw section data or nil if out of bounds.
    func readSectionData(_ section: Section) -> Data? {
        let start = Int(section.offset)
        let end = start + Int(section.size)
        guard start >= 0, end <= data.count else { return nil }
        return data.subdata(in: start..<end)
    }

    // MARK: - Address Translation

    /// Convert virtual address to file offset.
    ///
    /// Pure lookup function.
    ///
    /// - Parameter address: Virtual address.
    /// - Returns: File offset or nil if address is not in any segment.
    func fileOffset(for address: UInt64) -> Int? {
        for segment in segments {
            if let offset = segment.fileOffset(for: address) {
                return Int(offset)
            }
        }
        return nil
    }

    /// Read a null-terminated string at a virtual address.
    ///
    /// - Parameter address: Virtual address of the string.
    /// - Returns: The string or nil if invalid.
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

    // MARK: - Relative Pointer Reading

    /// Read a relative pointer (32-bit offset from current position).
    ///
    /// - Parameter fileOffset: File offset where the pointer is stored.
    /// - Returns: Target file offset or nil if invalid.
    func readRelativePointer(at fileOffset: Int) -> UInt64? {
        guard fileOffset + 4 <= data.count else { return nil }

        let relOffset: Int32
        if byteOrder == .little {
            relOffset = data.withUnsafeBytes { ptr in
                ptr.loadUnaligned(fromByteOffset: fileOffset, as: Int32.self).littleEndian
            }
        }
        else {
            relOffset = data.withUnsafeBytes { ptr in
                ptr.loadUnaligned(fromByteOffset: fileOffset, as: Int32.self).bigEndian
            }
        }

        let targetOffset = fileOffset + Int(relOffset)
        guard targetOffset >= 0 else { return nil }

        return UInt64(targetOffset)
    }

    /// Read a string via relative pointer.
    ///
    /// - Parameter fileOffset: File offset of the relative pointer.
    /// - Returns: The string or nil if invalid.
    func readRelativeString(at fileOffset: Int) -> String? {
        guard let targetOffset = readRelativePointer(at: fileOffset) else { return nil }
        guard targetOffset < data.count else { return nil }

        var end = Int(targetOffset)
        while end < data.count, data[end] != 0 {
            end += 1
        }

        guard end > Int(targetOffset) else { return nil }
        let stringData = data.subdata(in: Int(targetOffset)..<end)
        return String(data: stringData, encoding: .utf8)
    }

    /// Read raw bytes via relative pointer (for symbolic references).
    ///
    /// For symbolic references, we need to read a fixed amount of binary data
    /// because the relative offset bytes can contain nulls.
    ///
    /// - Parameter fileOffset: File offset of the relative pointer.
    /// - Returns: Raw data or nil if invalid.
    func readRelativeData(at fileOffset: Int) -> Data? {
        guard let targetOffset = readRelativePointer(at: fileOffset) else { return nil }
        guard targetOffset >= 0, targetOffset < data.count else { return nil }

        let startOffset = Int(targetOffset)
        let maxLen = min(256, data.count - startOffset)
        guard maxLen > 0 else { return nil }

        // Read data, handling embedded symbolic references
        var end = startOffset

        while end < startOffset + maxLen {
            let byte = data[end]

            if byte == 0 {
                // Check if this could be part of a symbolic reference
                var isInSymbolicRef = false
                for lookback in 1...4 where end - lookback >= startOffset {
                    let prevByte = data[end - lookback]
                    if prevByte == 0x01 || prevByte == 0x02 {
                        isInSymbolicRef = true
                        break
                    }
                }

                if !isInSymbolicRef {
                    break
                }
            }

            // Check for symbolic reference markers in the middle
            if (byte == 0x01 || byte == 0x02) && end + 5 <= startOffset + maxLen {
                end += 5
                continue
            }

            end += 1
        }

        guard end > startOffset else { return nil }
        return data.subdata(in: startOffset..<end)
    }

    // MARK: - Primitive Reading

    /// Read a UInt32 at the given offset.
    ///
    /// - Parameter offset: File offset.
    /// - Returns: The value or 0 if out of bounds.
    func readUInt32(at offset: Int) -> UInt32 {
        guard offset + 4 <= data.count else { return 0 }
        return data.withUnsafeBytes { ptr in
            byteOrder == .little
                ? ptr.loadUnaligned(fromByteOffset: offset, as: UInt32.self).littleEndian
                : ptr.loadUnaligned(fromByteOffset: offset, as: UInt32.self).bigEndian
        }
    }

    /// Read a UInt16 at the given offset.
    ///
    /// - Parameter offset: File offset.
    /// - Returns: The value or 0 if out of bounds.
    func readUInt16(at offset: Int) -> UInt16 {
        guard offset + 2 <= data.count else { return 0 }
        return data.withUnsafeBytes { ptr in
            byteOrder == .little
                ? ptr.loadUnaligned(fromByteOffset: offset, as: UInt16.self).littleEndian
                : ptr.loadUnaligned(fromByteOffset: offset, as: UInt16.self).bigEndian
        }
    }
}

// MARK: - Field Descriptor Cache

/// Pure functions for building field descriptor caches.
public enum SwiftFieldDescriptorCache {

    /// Build a lookup index from field descriptors.
    ///
    /// Pure function that creates a dictionary mapping mangled type names
    /// to their field descriptors.
    ///
    /// - Parameter descriptors: Array of field descriptors.
    /// - Returns: Dictionary for fast lookup.
    public static func buildIndex(
        from descriptors: [SwiftFieldDescriptor]
    ) -> [String: SwiftFieldDescriptor] {
        Dictionary(
            descriptors.map { ($0.mangledTypeName, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }
}

// MARK: - MachOFile Extension

extension MachOFile {
    /// Check if this binary contains Swift metadata.
    public var hasSwiftMetadata: Bool {
        // Check for __swift5_types or __swift5_fieldmd sections
        for segment in segments where segment.name == "__TEXT" || segment.name == "__DATA_CONST" {
            for section in segment.sections where section.sectionName.hasPrefix("__swift5_") {
                return true
            }
        }
        return false
    }

    /// Parse Swift metadata from this binary.
    public func parseSwiftMetadata() throws -> SwiftMetadata {
        let processor = SwiftMetadataProcessor(machOFile: self)
        return try processor.process()
    }
}

// MARK: - Swift Metadata Analyzer

/// Pure functions for analyzing Swift metadata as a whole.
///
/// These functions operate on immutable SwiftMetadata and have no side effects.
public enum SwiftMetadataAnalyzer {

    /// Get summary statistics for Swift metadata.
    ///
    /// Pure function for metadata analysis.
    ///
    /// - Parameter metadata: The metadata to analyze.
    /// - Returns: Summary statistics.
    public static func summary(_ metadata: SwiftMetadata) -> MetadataSummary {
        MetadataSummary(
            typeCount: metadata.types.count,
            classCount: metadata.classes.count,
            structCount: metadata.structs.count,
            enumCount: metadata.enums.count,
            protocolCount: metadata.protocols.count,
            conformanceCount: metadata.conformances.count,
            extensionCount: metadata.extensions.count,
            genericTypeCount: metadata.genericTypes.count,
            retroactiveConformanceCount: metadata.retroactiveConformances.count
        )
    }

    /// Check if metadata is empty.
    ///
    /// Pure predicate function.
    ///
    /// - Parameter metadata: The metadata to check.
    /// - Returns: True if no types, protocols, or conformances exist.
    public static func isEmpty(_ metadata: SwiftMetadata) -> Bool {
        metadata.types.isEmpty
            && metadata.protocols.isEmpty
            && metadata.conformances.isEmpty
            && metadata.extensions.isEmpty
    }

    /// Get all unique module names from the metadata.
    ///
    /// Pure function for extracting module information.
    ///
    /// - Parameter metadata: The metadata to analyze.
    /// - Returns: Set of module names.
    public static func moduleNames(_ metadata: SwiftMetadata) -> Set<String> {
        var modules = Set<String>()

        for type in metadata.types {
            if let parent = type.parentName, type.parentKind == .module {
                modules.insert(parent)
            }
        }

        for proto in metadata.protocols {
            if let parent = proto.parentName {
                modules.insert(parent)
            }
        }

        for ext in metadata.extensions {
            if let module = ext.moduleName {
                modules.insert(module)
            }
        }

        return modules
    }
}

/// Summary statistics for Swift metadata.
public struct MetadataSummary: Sendable {
    /// Total number of types.
    public let typeCount: Int
    /// Number of classes.
    public let classCount: Int
    /// Number of structs.
    public let structCount: Int
    /// Number of enums.
    public let enumCount: Int
    /// Number of protocols.
    public let protocolCount: Int
    /// Number of protocol conformances.
    public let conformanceCount: Int
    /// Number of extensions.
    public let extensionCount: Int
    /// Number of generic types.
    public let genericTypeCount: Int
    /// Number of retroactive conformances.
    public let retroactiveConformanceCount: Int
}
