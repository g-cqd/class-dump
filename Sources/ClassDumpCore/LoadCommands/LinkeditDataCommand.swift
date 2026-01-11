// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

/// Linkedit data load command (LC_CODE_SIGNATURE, LC_FUNCTION_STARTS, etc.).
public struct LinkeditDataCommand: LoadCommandProtocol, Sendable {
    /// The command type.
    public let cmd: UInt32

    /// The size of the command in bytes.
    public let cmdsize: UInt32

    /// The file offset of the data.
    public let dataoff: UInt32

    /// The size of the data in bytes.
    public let datasize: UInt32

    /// Parse a linkedit data command from data.
    public init(data: Data, byteOrder: ByteOrder) throws {
        do {
            var cursor = try DataCursor(data: data, offset: 0)

            if byteOrder == .little {
                self.cmd = try cursor.readLittleInt32()
                self.cmdsize = try cursor.readLittleInt32()
                self.dataoff = try cursor.readLittleInt32()
                self.datasize = try cursor.readLittleInt32()
            }
            else {
                self.cmd = try cursor.readBigInt32()
                self.cmdsize = try cursor.readBigInt32()
                self.dataoff = try cursor.readBigInt32()
                self.datasize = try cursor.readBigInt32()
            }
        }
        catch {
            throw LoadCommandError.dataTooSmall(expected: 16, actual: data.count)
        }
    }
}

extension LinkeditDataCommand: CustomStringConvertible {
    /// A textual description of the command.
    public var description: String {
        "LinkeditDataCommand(\(commandName), offset: 0x\(String(dataoff, radix: 16)), size: \(datasize))"
    }
}
