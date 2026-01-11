// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

/// Runpath load command (LC_RPATH).
public struct RpathCommand: LoadCommandProtocol, Sendable {
    /// The command type (LC_RPATH).
    public let cmd: UInt32

    /// The size of the command in bytes.
    public let cmdsize: UInt32

    /// The runpath string.
    public let path: String

    /// Parse an rpath command from data.
    public init(data: Data, byteOrder: ByteOrder) throws {
        do {
            var cursor = try DataCursor(data: data, offset: 0)

            if byteOrder == .little {
                self.cmd = try cursor.readLittleInt32()
                self.cmdsize = try cursor.readLittleInt32()
                let pathOffset = try cursor.readLittleInt32()
                cursor = try DataCursor(data: data, offset: Int(pathOffset))
                self.path = try cursor.readCString()
            }
            else {
                self.cmd = try cursor.readBigInt32()
                self.cmdsize = try cursor.readBigInt32()
                let pathOffset = try cursor.readBigInt32()
                cursor = try DataCursor(data: data, offset: Int(pathOffset))
                self.path = try cursor.readCString()
            }
        }
        catch {
            throw LoadCommandError.dataTooSmall(expected: 12, actual: data.count)
        }
    }
}

extension RpathCommand: CustomStringConvertible {
    /// A textual description of the command.
    public var description: String {
        "RpathCommand(\(path))"
    }
}
