// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

/// Dyld info load command (LC_DYLD_INFO, LC_DYLD_INFO_ONLY).
public struct DyldInfoCommand: LoadCommandProtocol, Sendable {
    /// The command type.
    public let cmd: UInt32

    /// The size of the command in bytes.
    public let cmdsize: UInt32

    // Rebase info
    /// The file offset of the rebase info.
    public let rebaseOff: UInt32

    /// The size of the rebase info in bytes.
    public let rebaseSize: UInt32

    // Binding info
    /// The file offset of the binding info.
    public let bindOff: UInt32

    /// The size of the binding info in bytes.
    public let bindSize: UInt32

    // Weak binding info
    /// The file offset of the weak binding info.
    public let weakBindOff: UInt32

    /// The size of the weak binding info in bytes.
    public let weakBindSize: UInt32

    // Lazy binding info
    /// The file offset of the lazy binding info.
    public let lazyBindOff: UInt32

    /// The size of the lazy binding info in bytes.
    public let lazyBindSize: UInt32

    // Export info
    /// The file offset of the export info.
    public let exportOff: UInt32

    /// The size of the export info in bytes.
    public let exportSize: UInt32

    /// Parse a dyld info command from data.
    public init(data: Data, byteOrder: ByteOrder) throws {
        do {
            var cursor = try DataCursor(data: data, offset: 0)

            if byteOrder == .little {
                self.cmd = try cursor.readLittleInt32()
                self.cmdsize = try cursor.readLittleInt32()
                self.rebaseOff = try cursor.readLittleInt32()
                self.rebaseSize = try cursor.readLittleInt32()
                self.bindOff = try cursor.readLittleInt32()
                self.bindSize = try cursor.readLittleInt32()
                self.weakBindOff = try cursor.readLittleInt32()
                self.weakBindSize = try cursor.readLittleInt32()
                self.lazyBindOff = try cursor.readLittleInt32()
                self.lazyBindSize = try cursor.readLittleInt32()
                self.exportOff = try cursor.readLittleInt32()
                self.exportSize = try cursor.readLittleInt32()
            }
            else {
                self.cmd = try cursor.readBigInt32()
                self.cmdsize = try cursor.readBigInt32()
                self.rebaseOff = try cursor.readBigInt32()
                self.rebaseSize = try cursor.readBigInt32()
                self.bindOff = try cursor.readBigInt32()
                self.bindSize = try cursor.readBigInt32()
                self.weakBindOff = try cursor.readBigInt32()
                self.weakBindSize = try cursor.readBigInt32()
                self.lazyBindOff = try cursor.readBigInt32()
                self.lazyBindSize = try cursor.readBigInt32()
                self.exportOff = try cursor.readBigInt32()
                self.exportSize = try cursor.readBigInt32()
            }
        }
        catch {
            throw LoadCommandError.dataTooSmall(expected: 48, actual: data.count)
        }
    }
}

extension DyldInfoCommand: CustomStringConvertible {
    /// A textual description of the command.
    public var description: String {
        "DyldInfoCommand(rebase: \(rebaseSize), bind: \(bindSize), weak: \(weakBindSize), lazy: \(lazyBindSize), export: \(exportSize))"
    }
}
