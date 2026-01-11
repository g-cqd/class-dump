// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

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
