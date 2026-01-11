// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

/// Encryption info load command (LC_ENCRYPTION_INFO, LC_ENCRYPTION_INFO_64).
public struct EncryptionInfoCommand: LoadCommandProtocol, Sendable {
    /// The command type.
    public let cmd: UInt32

    /// The size of the command in bytes.
    public let cmdsize: UInt32

    /// The file offset of the encrypted range.
    public let cryptoff: UInt32

    /// The size of the encrypted range in bytes.
    public let cryptsize: UInt32

    /// The encryption system ID (0 = not encrypted).
    public let cryptid: UInt32

    /// Padding (64-bit only).
    public let pad: UInt32

    /// Whether this is a 64-bit command.
    public let is64Bit: Bool

    /// Whether the segment is encrypted.
    public var isEncrypted: Bool {
        cryptid != 0
    }

    /// Parse an encryption info command from data.
    public init(data: Data, byteOrder: ByteOrder, is64Bit: Bool) throws {
        do {
            var cursor = try DataCursor(data: data, offset: 0)

            if byteOrder == .little {
                self.cmd = try cursor.readLittleInt32()
                self.cmdsize = try cursor.readLittleInt32()
                self.cryptoff = try cursor.readLittleInt32()
                self.cryptsize = try cursor.readLittleInt32()
                self.cryptid = try cursor.readLittleInt32()
                self.pad = is64Bit ? try cursor.readLittleInt32() : 0
            }
            else {
                self.cmd = try cursor.readBigInt32()
                self.cmdsize = try cursor.readBigInt32()
                self.cryptoff = try cursor.readBigInt32()
                self.cryptsize = try cursor.readBigInt32()
                self.cryptid = try cursor.readBigInt32()
                self.pad = is64Bit ? try cursor.readBigInt32() : 0
            }

            self.is64Bit = is64Bit
        }
        catch {
            throw LoadCommandError.dataTooSmall(expected: is64Bit ? 24 : 20, actual: data.count)
        }
    }
}

extension EncryptionInfoCommand: CustomStringConvertible {
    /// A textual description of the command.
    public var description: String {
        "EncryptionInfoCommand(offset: 0x\(String(cryptoff, radix: 16)), size: \(cryptsize), encrypted: \(isEncrypted))"
    }
}
