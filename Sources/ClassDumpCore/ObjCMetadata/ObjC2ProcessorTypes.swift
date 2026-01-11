// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

/// Types and result structures for ObjC2Processor.
///
/// This file contains the error types, result containers, and streaming types
/// used by the ObjC metadata processor. All types are `Sendable` for safe
/// concurrent access.

// MARK: - Error Types

/// Errors that can occur during ObjC metadata processing.
public enum ObjCProcessorError: Error, Sendable {
    case sectionNotFound(String)
    case invalidAddress(UInt64)
    case invalidData(String)
    case invalidPointer(UInt64)
}

// MARK: - Result Types

/// Result of processing ObjC metadata from a binary.
///
/// This immutable container holds all processed metadata including classes,
/// protocols, categories, and the associated registries for structure and
/// method signature lookup.
public struct ObjCMetadata: Sendable {
    /// The processed classes.
    public let classes: [ObjCClass]

    /// The processed protocols.
    public let protocols: [ObjCProtocol]

    /// The processed categories.
    public let categories: [ObjCCategory]

    /// The image info (if available).
    public let imageInfo: ObjC2ImageInfo?

    /// Registry of detected structures.
    public let structureRegistry: StructureRegistry

    /// Registry of method signatures.
    public let methodSignatureRegistry: MethodSignatureRegistry

    /// Initialize metadata results.
    public init(
        classes: [ObjCClass] = [],
        protocols: [ObjCProtocol] = [],
        categories: [ObjCCategory] = [],
        imageInfo: ObjC2ImageInfo? = nil,
        structureRegistry: StructureRegistry? = nil,
        methodSignatureRegistry: MethodSignatureRegistry? = nil
    ) {
        self.classes = classes
        self.protocols = protocols
        self.categories = categories
        self.imageInfo = imageInfo
        self.structureRegistry = structureRegistry ?? StructureRegistry()
        self.methodSignatureRegistry = methodSignatureRegistry ?? MethodSignatureRegistry()
    }

    /// Returns a sorted copy of this metadata.
    ///
    /// Pure function that creates a new `ObjCMetadata` with sorted collections.
    public func sorted() -> ObjCMetadata {
        ObjCMetadata(
            classes: classes.sorted(),
            protocols: protocols.sorted(),
            categories: categories.sorted(),
            imageInfo: imageInfo,
            structureRegistry: structureRegistry,
            methodSignatureRegistry: methodSignatureRegistry
        )
    }

    /// Returns metadata filtered by a predicate applied to class names.
    ///
    /// Pure function for filtering metadata.
    ///
    /// - Parameter predicate: A closure that takes a class name and returns true to include.
    /// - Returns: A new `ObjCMetadata` with only matching items.
    public func filtered(byClassName predicate: (String) -> Bool) -> ObjCMetadata {
        ObjCMetadata(
            classes: classes.filter { predicate($0.name) },
            protocols: protocols,
            categories: categories.filter { cat in
                guard let classRef = cat.classRef else { return true }
                return predicate(classRef.name)
            },
            imageInfo: imageInfo,
            structureRegistry: structureRegistry,
            methodSignatureRegistry: methodSignatureRegistry
        )
    }
}

// MARK: - Streaming Types

/// A single item from the streaming metadata processor.
///
/// Use this with `ObjC2Processor.stream()` to process large binaries with
/// bounded memory usage. Items are yielded as they're processed.
public enum ObjCMetadataItem: Sendable {
    /// The binary's image info (always first if present).
    case imageInfo(ObjC2ImageInfo)

    /// A protocol definition.
    case `protocol`(ObjCProtocol)

    /// A class definition.
    case `class`(ObjCClass)

    /// A category definition.
    case category(ObjCCategory)

    /// Processing progress update.
    case progress(ProcessingProgress)
}

/// Progress information during streaming processing.
public struct ProcessingProgress: Sendable {
    /// Current phase of processing.
    public let phase: ProcessingPhase

    /// Number of items processed so far in this phase.
    public let processed: Int

    /// Total items to process in this phase (if known).
    public let total: Int?

    /// Initialize progress info.
    public init(phase: ProcessingPhase, processed: Int, total: Int?) {
        self.phase = phase
        self.processed = processed
        self.total = total
    }

    /// Percentage complete (0-100) if total is known.
    ///
    /// Pure computed property.
    public var percentComplete: Int? {
        guard let total = total, total > 0 else { return nil }
        return min(100, (processed * 100) / total)
    }
}

/// Processing phases for streaming.
public enum ProcessingPhase: String, Sendable {
    case protocols = "Loading protocols"
    case classes = "Loading classes"
    case categories = "Loading categories"
    case complete = "Complete"
}

// MARK: - Pointer Decode Result

/// Result of decoding a pointer that may be a chained fixup.
///
/// Modern arm64/arm64e binaries use chained fixups where pointers encode
/// either a rebase target address or a bind to an external symbol.
public enum PointerDecodeResult: Sendable, Equatable {
    /// A resolved virtual address in the binary.
    case address(UInt64)

    /// A bind to an external symbol by name.
    case bindSymbol(String)

    /// A bind ordinal when symbol table is unavailable.
    case bindOrdinal(UInt32)

    /// Whether this result represents a valid address.
    public var isAddress: Bool {
        if case .address = self { return true }
        return false
    }

    /// Extract the address if this is an address result.
    public var addressValue: UInt64? {
        if case .address(let addr) = self { return addr }
        return nil
    }

    /// Extract the symbol name if this is a bind result.
    public var symbolName: String? {
        if case .bindSymbol(let name) = self { return name }
        return nil
    }
}

// MARK: - Processing Context

/// Context passed to pure parsing functions.
///
/// This struct encapsulates all the immutable state needed for parsing,
/// enabling pure functions that don't depend on processor state.
public struct ObjCParsingContext: Sendable {
    /// The raw binary data.
    public let data: Data

    /// Byte order of the binary.
    public let byteOrder: ByteOrder

    /// Whether the binary is 64-bit.
    public let is64Bit: Bool

    /// Pointer size in bytes.
    public var ptrSize: Int { is64Bit ? 8 : 4 }

    /// Initialize a parsing context.
    public init(data: Data, byteOrder: ByteOrder, is64Bit: Bool) {
        self.data = data
        self.byteOrder = byteOrder
        self.is64Bit = is64Bit
    }
}
