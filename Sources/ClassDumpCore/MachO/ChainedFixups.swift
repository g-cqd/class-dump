// ChainedFixups.swift
// Parsing and resolution of LC_DYLD_CHAINED_FIXUPS for iOS 14+ binaries.

import Foundation

// MARK: - Pointer Format Types

/// Chained pointer format types from dyld.
public enum ChainedPointerFormat: UInt16, Sendable {
    case arm64e = 1  // DYLD_CHAINED_PTR_ARM64E
    case ptr64 = 2  // DYLD_CHAINED_PTR_64
    case ptr32 = 3  // DYLD_CHAINED_PTR_32
    case ptr32Cache = 4  // DYLD_CHAINED_PTR_32_CACHE
    case ptr32Firmware = 5  // DYLD_CHAINED_PTR_32_FIRMWARE
    case ptr64Offset = 6  // DYLD_CHAINED_PTR_64_OFFSET
    case arm64eKernel = 7  // DYLD_CHAINED_PTR_ARM64E_KERNEL
    case ptr64KernelCache = 8  // DYLD_CHAINED_PTR_64_KERNEL_CACHE
    case arm64eUserland = 9  // DYLD_CHAINED_PTR_ARM64E_USERLAND
    case arm64eFirmware = 10  // DYLD_CHAINED_PTR_ARM64E_FIRMWARE
    // swift-format-ignore: AlwaysUseLowerCamelCase
    case x86_64KernelCache = 11  // DYLD_CHAINED_PTR_X86_64_KERNEL_CACHE
    case arm64eUserland24 = 12  // DYLD_CHAINED_PTR_ARM64E_USERLAND24
    case arm64eSharedCache = 13  // DYLD_CHAINED_PTR_ARM64E_SHARED_CACHE
    case arm64eSegmented = 14  // DYLD_CHAINED_PTR_ARM64E_SEGMENTED

    /// Stride in bytes between fixup locations.
    public var stride: Int {
        switch self {
            case .arm64e, .arm64eUserland, .arm64eUserland24, .arm64eSharedCache:
                return 8
            case .arm64eKernel, .arm64eFirmware, .ptr32Firmware, .ptr64, .ptr64Offset,
                .ptr32, .ptr32Cache, .ptr64KernelCache, .arm64eSegmented:
                return 4
            case .x86_64KernelCache:
                return 1
        }
    }

    /// Pointer size in bytes.
    public var pointerSize: Int {
        switch self {
            case .ptr32, .ptr32Cache, .ptr32Firmware:
                return 4
            default:
                return 8
        }
    }
}

// MARK: - Import Format

/// Import table format from dyld_chained_fixups_header.imports_format.
public enum ChainedImportFormat: UInt32, Sendable {
    case standard = 1  // DYLD_CHAINED_IMPORT
    case addend = 2  // DYLD_CHAINED_IMPORT_ADDEND
    case addend64 = 3  // DYLD_CHAINED_IMPORT_ADDEND64
}

// MARK: - Chained Fixups Header

/// Header of the LC_DYLD_CHAINED_FIXUPS payload.
public struct ChainedFixupsHeader: Sendable {
    /// The fixups version.
    public let fixupsVersion: UInt32

    /// The offset of the starts info.
    public let startsOffset: UInt32

    /// The offset of the imports table.
    public let importsOffset: UInt32

    /// The offset of the symbols table.
    public let symbolsOffset: UInt32

    /// The number of imports.
    public let importsCount: UInt32

    /// The format of the imports table.
    public let importsFormat: ChainedImportFormat

    /// The format of the symbols table.
    public let symbolsFormat: UInt32  // 0 = uncompressed, 1 = zlib

    /// Parse a chained fixups header from data.
    public init(data: Data, byteOrder: ByteOrder) throws {
        guard data.count >= 24 else {
            throw ChainedFixupsError.dataTooSmall
        }

        var cursor = try DataCursor(data: data, offset: 0)
        if byteOrder == .little {
            fixupsVersion = try cursor.readLittleInt32()
            startsOffset = try cursor.readLittleInt32()
            importsOffset = try cursor.readLittleInt32()
            symbolsOffset = try cursor.readLittleInt32()
            importsCount = try cursor.readLittleInt32()
            let rawImportsFormat = try cursor.readLittleInt32()
            importsFormat = ChainedImportFormat(rawValue: rawImportsFormat) ?? .standard
            symbolsFormat = try cursor.readLittleInt32()
        }
        else {
            fixupsVersion = try cursor.readBigInt32()
            startsOffset = try cursor.readBigInt32()
            importsOffset = try cursor.readBigInt32()
            symbolsOffset = try cursor.readBigInt32()
            importsCount = try cursor.readBigInt32()
            let rawImportsFormat = try cursor.readBigInt32()
            importsFormat = ChainedImportFormat(rawValue: rawImportsFormat) ?? .standard
            symbolsFormat = try cursor.readBigInt32()
        }
    }
}

// MARK: - Import Entry

/// A single import entry from the chained fixups import table.
public struct ChainedImport: Sendable {
    /// The import ordinal.
    public let ordinal: UInt32

    /// The symbol name.
    public let name: String

    /// The library ordinal.
    public let libOrdinal: Int

    /// Whether this is a weak import.
    public let isWeakImport: Bool

    /// The addend.
    public let addend: Int64

    /// Initialize a chained import entry.
    public init(ordinal: UInt32, name: String, libOrdinal: Int, isWeakImport: Bool, addend: Int64 = 0) {
        self.ordinal = ordinal
        self.name = name
        self.libOrdinal = libOrdinal
        self.isWeakImport = isWeakImport
        self.addend = addend
    }
}

// MARK: - Fixup Result

/// Result of resolving a chained fixup pointer.
public enum ChainedFixupResult: Sendable {
    /// A rebase to an internal address.
    case rebase(target: UInt64)
    /// A bind to an external symbol.
    case bind(ordinal: UInt32, addend: Int64)
    /// Not a chained fixup pointer.
    case notFixup
}

// MARK: - Chained Fixups Error

/// Errors that can occur when parsing chained fixups.
public enum ChainedFixupsError: Error, Sendable {
    case dataTooSmall
    case invalidFormat
    case unsupportedPointerFormat(UInt16)
    case symbolNotFound(ordinal: UInt32)
}

// MARK: - Chained Fixups

/// Parser for LC_DYLD_CHAINED_FIXUPS data.
public struct ChainedFixups: Sendable {
    /// The parsed header.
    public let header: ChainedFixupsHeader

    /// Import table: ordinal → symbol name.
    public let imports: [ChainedImport]

    /// The pointer format used by this binary (if uniform across segments).
    public let pointerFormat: ChainedPointerFormat?

    /// The raw fixups data.
    private let data: Data
    private let byteOrder: ByteOrder

    /// Initialize from the raw data pointed to by LC_DYLD_CHAINED_FIXUPS.
    public init(data: Data, byteOrder: ByteOrder) throws {
        self.data = data
        self.byteOrder = byteOrder
        self.header = try ChainedFixupsHeader(data: data, byteOrder: byteOrder)

        // Parse imports table
        var parsedImports: [ChainedImport] = []
        parsedImports.reserveCapacity(Int(header.importsCount))

        let importsData = Data(data.dropFirst(Int(header.importsOffset)))
        let symbolsData = data.dropFirst(Int(header.symbolsOffset))

        var cursor = try DataCursor(data: importsData, offset: 0)

        for ordinal in 0..<header.importsCount {
            let (libOrdinal, isWeak, nameOffset, addend) = try ChainedFixups.parseImportEntry(
                cursor: &cursor,
                format: header.importsFormat,
                byteOrder: byteOrder
            )

            // Read symbol name from symbols table
            let name = ChainedFixups.readString(from: symbolsData, at: Int(nameOffset))

            parsedImports.append(
                ChainedImport(
                    ordinal: ordinal,
                    name: name,
                    libOrdinal: libOrdinal,
                    isWeakImport: isWeak,
                    addend: addend
                )
            )
        }

        self.imports = parsedImports

        // Try to determine pointer format from starts info
        self.pointerFormat = try? ChainedFixups.parsePointerFormat(
            data: data,
            startsOffset: header.startsOffset,
            byteOrder: byteOrder
        )
    }

    /// Parse a single import entry based on format.
    private static func parseImportEntry(
        cursor: inout DataCursor,
        format: ChainedImportFormat,
        byteOrder: ByteOrder
    ) throws -> (libOrdinal: Int, isWeak: Bool, nameOffset: UInt64, addend: Int64) {
        switch format {
            case .standard:
                // DYLD_CHAINED_IMPORT: 4 bytes
                // Bits 0-7: lib ordinal (signed)
                // Bit 8: weak import
                // Bits 9-31: name offset
                let raw = byteOrder == .little ? try cursor.readLittleInt32() : try cursor.readBigInt32()
                let libOrdinal = Int(Int8(truncatingIfNeeded: raw & 0xFF))
                let isWeak = (raw >> 8) & 1 != 0
                let nameOffset = UInt64((raw >> 9) & 0x7FFFFF)
                return (libOrdinal, isWeak, nameOffset, 0)

            case .addend:
                // DYLD_CHAINED_IMPORT_ADDEND: 4 + 4 bytes
                let raw = byteOrder == .little ? try cursor.readLittleInt32() : try cursor.readBigInt32()
                let libOrdinal = Int(Int8(truncatingIfNeeded: raw & 0xFF))
                let isWeak = (raw >> 8) & 1 != 0
                let nameOffset = UInt64((raw >> 9) & 0x7FFFFF)
                let addendRaw = byteOrder == .little ? try cursor.readLittleInt32() : try cursor.readBigInt32()
                let addend = Int64(Int32(bitPattern: addendRaw))
                return (libOrdinal, isWeak, nameOffset, addend)

            case .addend64:
                // DYLD_CHAINED_IMPORT_ADDEND64: 8 + 8 bytes
                let raw = byteOrder == .little ? try cursor.readLittleInt64() : try cursor.readBigInt64()
                let libOrdinal = Int(Int16(truncatingIfNeeded: raw & 0xFFFF))
                let isWeak = (raw >> 16) & 1 != 0
                let nameOffset = (raw >> 32) & 0xFFFF_FFFF
                let addendRaw = byteOrder == .little ? try cursor.readLittleInt64() : try cursor.readBigInt64()
                let addend = Int64(bitPattern: addendRaw)
                return (libOrdinal, isWeak, nameOffset, addend)
        }
    }

    /// Read a null-terminated string from data at offset.
    private static func readString(from data: Data.SubSequence, at offset: Int) -> String {
        guard offset >= 0, offset < data.count else { return "" }

        var end = data.startIndex + offset
        while end < data.endIndex && data[end] != 0 {
            end += 1
        }

        let stringData = data[(data.startIndex + offset)..<end]
        return String(data: Data(stringData), encoding: .utf8) ?? ""
    }

    /// Parse the pointer format from starts info.
    private static func parsePointerFormat(
        data: Data,
        startsOffset: UInt32,
        byteOrder: ByteOrder
    ) throws -> ChainedPointerFormat? {
        guard startsOffset > 0 else { return nil }

        let startsData = Data(data.dropFirst(Int(startsOffset)))
        guard startsData.count >= 4 else { return nil }

        var cursor = try DataCursor(data: startsData, offset: 0)

        // dyld_chained_starts_in_image
        let segCount = byteOrder == .little ? try cursor.readLittleInt32() : try cursor.readBigInt32()
        guard segCount > 0 else { return nil }

        // Read first non-zero segment offset to find pointer format
        for _ in 0..<segCount {
            let segInfoOffset = byteOrder == .little ? try cursor.readLittleInt32() : try cursor.readBigInt32()
            if segInfoOffset != 0 {
                // Parse dyld_chained_starts_in_segment
                let segData = Data(startsData.dropFirst(Int(segInfoOffset)))
                guard segData.count >= 22 else { continue }

                var segCursor = try DataCursor(data: segData, offset: 0)
                _ = byteOrder == .little ? try segCursor.readLittleInt32() : try segCursor.readBigInt32()  // size
                _ = byteOrder == .little ? try segCursor.readLittleInt16() : try segCursor.readBigInt16()  // page_size
                let pointerFormatRaw =
                    byteOrder == .little ? try segCursor.readLittleInt16() : try segCursor.readBigInt16()

                if let format = ChainedPointerFormat(rawValue: pointerFormatRaw) {
                    return format
                }
            }
        }

        return nil
    }

    /// Look up a symbol name by bind ordinal.
    public func symbolName(forOrdinal ordinal: UInt32) -> String? {
        guard ordinal < imports.count else { return nil }
        return imports[Int(ordinal)].name
    }

    /// Decode a raw pointer value to determine if it's a bind or rebase.
    public func decodePointer(_ rawPointer: UInt64, format: ChainedPointerFormat? = nil) -> ChainedFixupResult {
        let fmt = format ?? pointerFormat ?? .ptr64

        switch fmt {
            case .arm64e, .arm64eUserland, .arm64eKernel, .arm64eFirmware:
                return decodeArm64ePointer(rawPointer)

            case .arm64eUserland24:
                return decodeArm64eUserland24Pointer(rawPointer)

            case .ptr64, .ptr64Offset:
                return decodePtr64Pointer(rawPointer)

            case .ptr32:
                return decodePtr32Pointer(UInt32(truncatingIfNeeded: rawPointer))

            default:
                // For other formats, use heuristic
                return decodeHeuristicPointer(rawPointer)
        }
    }

    // MARK: - Format-Specific Decoders

    private func decodeArm64ePointer(_ raw: UInt64) -> ChainedFixupResult {
        let auth = (raw >> 63) & 1
        let bind = (raw >> 62) & 1

        if bind != 0 {
            // Bind
            let ordinal = UInt32(raw & 0xFFFF)
            let addendRaw = (raw >> 32) & 0x7FFFF
            let addend = signExtend19(addendRaw)
            return .bind(ordinal: ordinal, addend: addend)
        }
        else if auth != 0 {
            // Auth rebase
            let target = raw & 0xFFFF_FFFF  // 32-bit target
            return .rebase(target: target)
        }
        else {
            // Regular rebase
            let target = raw & 0x7FF_FFFF_FFFF  // 43-bit target
            let high8 = (raw >> 43) & 0xFF
            return .rebase(target: (high8 << 56) | target)
        }
    }

    private func decodeArm64eUserland24Pointer(_ raw: UInt64) -> ChainedFixupResult {
        let auth = (raw >> 63) & 1
        let bind = (raw >> 62) & 1

        if bind != 0 {
            // Bind with 24-bit ordinal
            let ordinal = UInt32(raw & 0xFFFFFF)
            let addendRaw = (raw >> 32) & 0x7FFFF
            let addend = signExtend19(addendRaw)
            return .bind(ordinal: ordinal, addend: addend)
        }
        else if auth != 0 {
            // Auth rebase
            let target = raw & 0xFFFF_FFFF
            return .rebase(target: target)
        }
        else {
            // Regular rebase
            let target = raw & 0x7FF_FFFF_FFFF
            let high8 = (raw >> 43) & 0xFF
            return .rebase(target: (high8 << 56) | target)
        }
    }

    private func decodePtr64Pointer(_ raw: UInt64) -> ChainedFixupResult {
        let bind = (raw >> 63) & 1

        guard bind != 0 else {
            // Rebase
            let target = raw & 0xF_FFFF_FFFF  // 36-bit target
            let high8 = (raw >> 36) & 0xFF
            return .rebase(target: (high8 << 56) | target)
        }
        // Bind
        let ordinal = UInt32(raw & 0xFFFFFF)
        let addend = Int64((raw >> 24) & 0xFF)
        return .bind(ordinal: ordinal, addend: addend)
    }

    private func decodePtr32Pointer(_ raw: UInt32) -> ChainedFixupResult {
        let bind = (raw >> 31) & 1

        guard bind != 0 else {
            // Rebase
            let target = UInt64(raw & 0x3FFFFFF)  // 26-bit target
            return .rebase(target: target)
        }
        // Bind
        let ordinal = raw & 0xFFFFF  // 20-bit ordinal
        let addend = Int64((raw >> 20) & 0x3F)
        return .bind(ordinal: ordinal, addend: addend)
    }

    private func decodeHeuristicPointer(_ raw: UInt64) -> ChainedFixupResult {
        // Check if high bits indicate a chained fixup
        let highBits = raw >> 36
        guard highBits != 0 else {
            return .notFixup
        }

        // Check bind flag
        let bind = (raw >> 63) & 1
        if bind != 0 {
            // Likely a bind - extract ordinal from low bits
            let ordinal = UInt32(raw & 0xFFFFFF)
            return .bind(ordinal: ordinal, addend: 0)
        }

        // Rebase - extract target from low 36 bits
        let target = raw & 0xF_FFFF_FFFF
        let high8 = (raw >> 36) & 0xFF
        if high8 != 0 {
            return .rebase(target: (high8 << 56) | target)
        }
        return .rebase(target: target)
    }

    /// Sign-extend a 19-bit value to Int64.
    private func signExtend19(_ value: UInt64) -> Int64 {
        if (value & 0x40000) != 0 {
            return Int64(value | 0xFFFF_FFFF_FFFC_0000)
        }
        return Int64(value)
    }
}

// MARK: - ChainedFixups + MachOFile Integration

extension MachOFile {
    /// Parse chained fixups from LC_DYLD_CHAINED_FIXUPS if present.
    public func parseChainedFixups() throws -> ChainedFixups? {
        // Find LC_DYLD_CHAINED_FIXUPS load command
        guard
            let fixupsCommand = loadCommands.first(where: {
                $0.cmd == 0x8000_0034  // LC_DYLD_CHAINED_FIXUPS
            })
        else {
            return nil
        }

        // Get the linkedit data command info
        guard case .linkeditData(let linkedit) = fixupsCommand else {
            return nil
        }

        // Read the fixups data directly from file data
        let offset = Int(linkedit.dataoff)
        let size = Int(linkedit.datasize)
        guard offset >= 0, size > 0, offset + size <= data.count else {
            throw ChainedFixupsError.dataTooSmall
        }

        let fixupsData = data.subdata(in: offset..<(offset + size))
        return try ChainedFixups(data: fixupsData, byteOrder: byteOrder)
    }

    /// Check if this binary uses chained fixups.
    public var hasChainedFixups: Bool {
        loadCommands.contains { $0.cmd == 0x8000_0034 }
    }
}
