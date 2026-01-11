// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

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
