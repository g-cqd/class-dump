// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

/// Dylinker load command (LC_LOAD_DYLINKER, LC_ID_DYLINKER, LC_DYLD_ENVIRONMENT).
public struct DylinkerCommand: LoadCommandProtocol, Sendable {
    /// The command type.
    public let cmd: UInt32

    /// The size of the command in bytes.
    public let cmdsize: UInt32

    /// The dynamic linker path name.
    public let name: String

    /// Parse a dylinker command from data.
    public init(data: Data, byteOrder: ByteOrder) throws {
        do {
            var cursor = try DataCursor(data: data, offset: 0)

            if byteOrder == .little {
                self.cmd = try cursor.readLittleInt32()
                self.cmdsize = try cursor.readLittleInt32()
                let nameOffset = try cursor.readLittleInt32()
                cursor = try DataCursor(data: data, offset: Int(nameOffset))
                self.name = try cursor.readCString()
            }
            else {
                self.cmd = try cursor.readBigInt32()
                self.cmdsize = try cursor.readBigInt32()
                let nameOffset = try cursor.readBigInt32()
                cursor = try DataCursor(data: data, offset: Int(nameOffset))
                self.name = try cursor.readCString()
            }
        }
        catch {
            throw LoadCommandError.dataTooSmall(expected: 12, actual: data.count)
        }
    }
}

extension DylinkerCommand: CustomStringConvertible {
    /// A textual description of the command.
    public var description: String {
        "DylinkerCommand(\(commandName), \(name))"
    }
}
