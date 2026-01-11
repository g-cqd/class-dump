// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

/// ObjC 2.0 method structure.
public struct ObjC2Method: Sendable {
    /// Pointer to selector name.
    public let name: UInt64

    /// Pointer to type encoding.
    public let types: UInt64

    /// Implementation address.
    public let imp: UInt64

    /// Parse a method structure.
    public init(cursor: inout DataCursor, byteOrder: ByteOrder, is64Bit: Bool) throws {
        if is64Bit {
            if byteOrder == .little {
                self.name = try cursor.readLittleInt64()
                self.types = try cursor.readLittleInt64()
                self.imp = try cursor.readLittleInt64()
            }
            else {
                self.name = try cursor.readBigInt64()
                self.types = try cursor.readBigInt64()
                self.imp = try cursor.readBigInt64()
            }
        }
        else {
            if byteOrder == .little {
                self.name = UInt64(try cursor.readLittleInt32())
                self.types = UInt64(try cursor.readLittleInt32())
                self.imp = UInt64(try cursor.readLittleInt32())
            }
            else {
                self.name = UInt64(try cursor.readBigInt32())
                self.types = UInt64(try cursor.readBigInt32())
                self.imp = UInt64(try cursor.readBigInt32())
            }
        }
    }
}
