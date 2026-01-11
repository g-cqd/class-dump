// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

/// Source version load command (LC_SOURCE_VERSION).
public struct SourceVersionCommand: LoadCommandProtocol, Sendable {
    /// The command type (LC_SOURCE_VERSION).
    public let cmd: UInt32

    /// The size of the command in bytes.
    public let cmdsize: UInt32

    /// The source version.
    public let version: UInt64

    /// Parsed version components (A.B.C.D.E).
    public var versionString: String {
        let a = (version >> 40) & 0xFFFFFF
        let b = (version >> 30) & 0x3FF
        let c = (version >> 20) & 0x3FF
        let d = (version >> 10) & 0x3FF
        let e = version & 0x3FF
        return "\(a).\(b).\(c).\(d).\(e)"
    }

    /// Parse a source version command from data.
    public init(data: Data, byteOrder: ByteOrder) throws {
        do {
            var cursor = try DataCursor(data: data, offset: 0)

            if byteOrder == .little {
                self.cmd = try cursor.readLittleInt32()
                self.cmdsize = try cursor.readLittleInt32()
                self.version = try cursor.readLittleInt64()
            }
            else {
                self.cmd = try cursor.readBigInt32()
                self.cmdsize = try cursor.readBigInt32()
                self.version = try cursor.readBigInt64()
            }
        }
        catch {
            throw LoadCommandError.dataTooSmall(expected: 16, actual: data.count)
        }
    }
}

extension SourceVersionCommand: CustomStringConvertible {
    /// A textual description of the command.
    public var description: String {
        "SourceVersionCommand(\(versionString))"
    }
}
