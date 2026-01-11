// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

/// ObjC 2.0 property structure.
public struct ObjC2Property: Sendable {
    /// Pointer to name string.
    public let name: UInt64

    /// Pointer to attributes string.
    public let attributes: UInt64

    /// Parse a property structure.
    public init(cursor: inout DataCursor, byteOrder: ByteOrder, is64Bit: Bool) throws {
        if is64Bit {
            if byteOrder == .little {
                self.name = try cursor.readLittleInt64()
                self.attributes = try cursor.readLittleInt64()
            }
            else {
                self.name = try cursor.readBigInt64()
                self.attributes = try cursor.readBigInt64()
            }
        }
        else {
            if byteOrder == .little {
                self.name = UInt64(try cursor.readLittleInt32())
                self.attributes = UInt64(try cursor.readLittleInt32())
            }
            else {
                self.name = UInt64(try cursor.readBigInt32())
                self.attributes = UInt64(try cursor.readBigInt32())
            }
        }
    }
}
