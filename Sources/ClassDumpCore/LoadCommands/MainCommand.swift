// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

/// Main entry point load command (LC_MAIN).
public struct MainCommand: LoadCommandProtocol, Sendable {
    /// The command type (LC_MAIN).
    public let cmd: UInt32

    /// The size of the command in bytes.
    public let cmdsize: UInt32

    /// The file offset of the entry point.
    public let entryoff: UInt64

    /// The initial stack size.
    public let stacksize: UInt64

    /// Parse a main command from data.
    public init(data: Data, byteOrder: ByteOrder) throws {
        do {
            var cursor = try DataCursor(data: data, offset: 0)

            if byteOrder == .little {
                self.cmd = try cursor.readLittleInt32()
                self.cmdsize = try cursor.readLittleInt32()
                self.entryoff = try cursor.readLittleInt64()
                self.stacksize = try cursor.readLittleInt64()
            }
            else {
                self.cmd = try cursor.readBigInt32()
                self.cmdsize = try cursor.readBigInt32()
                self.entryoff = try cursor.readBigInt64()
                self.stacksize = try cursor.readBigInt64()
            }
        }
        catch {
            throw LoadCommandError.dataTooSmall(expected: 24, actual: data.count)
        }
    }
}

extension MainCommand: CustomStringConvertible {
    /// A textual description of the command.
    public var description: String {
        "MainCommand(entryoff: 0x\(String(entryoff, radix: 16)), stacksize: \(stacksize))"
    }
}
