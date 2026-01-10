// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

/// ObjC 2.0 instance variable structure.
public struct ObjC2Ivar: Sendable {
  /// Pointer to offset value.
  public let offset: UInt64

  /// Pointer to name string.
  public let name: UInt64

  /// Pointer to type string.
  public let type: UInt64

  /// Ivar alignment.
  public let alignment: UInt32

  /// Ivar size.
  public let size: UInt32

  /// Parse an instance variable structure.
  public init(cursor: inout DataCursor, byteOrder: ByteOrder, is64Bit: Bool) throws {
    if is64Bit {
      if byteOrder == .little {
        self.offset = try cursor.readLittleInt64()
        self.name = try cursor.readLittleInt64()
        self.type = try cursor.readLittleInt64()
        self.alignment = try cursor.readLittleInt32()
        self.size = try cursor.readLittleInt32()
      } else {
        self.offset = try cursor.readBigInt64()
        self.name = try cursor.readBigInt64()
        self.type = try cursor.readBigInt64()
        self.alignment = try cursor.readBigInt32()
        self.size = try cursor.readBigInt32()
      }
    } else {
      if byteOrder == .little {
        self.offset = UInt64(try cursor.readLittleInt32())
        self.name = UInt64(try cursor.readLittleInt32())
        self.type = UInt64(try cursor.readLittleInt32())
        self.alignment = try cursor.readLittleInt32()
        self.size = try cursor.readLittleInt32()
      } else {
        self.offset = UInt64(try cursor.readBigInt32())
        self.name = UInt64(try cursor.readBigInt32())
        self.type = UInt64(try cursor.readBigInt32())
        self.alignment = try cursor.readBigInt32()
        self.size = try cursor.readBigInt32()
      }
    }
  }
}
