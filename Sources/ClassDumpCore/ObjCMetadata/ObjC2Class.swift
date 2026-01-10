// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

/// ObjC 2.0 class structure.
public struct ObjC2Class: Sendable {
  /// Pointer to metaclass.
  public let isa: UInt64

  /// Pointer to superclass.
  public let superclass: UInt64

  /// Pointer to method cache.
  public let cache: UInt64

  /// Pointer to virtual function table.
  public let vtable: UInt64

  /// Pointer to class_ro_t (low bits may have flags).
  public let data: UInt64

  /// Reserved field 1.
  public let reserved1: UInt64

  /// Reserved field 2.
  public let reserved2: UInt64

  /// Reserved field 3.
  public let reserved3: UInt64

  /// The actual data pointer (with flags stripped).
  public var dataPointer: UInt64 {
    data & ~7
  }

  /// Whether this is a Swift class (bit 0 of data).
  public var isSwiftClass: Bool {
    (data & 1) != 0
  }

  /// Parse an ObjC class structure.
  public init(cursor: inout DataCursor, byteOrder: ByteOrder, is64Bit: Bool) throws {
    if is64Bit {
      if byteOrder == .little {
        self.isa = try cursor.readLittleInt64()
        self.superclass = try cursor.readLittleInt64()
        self.cache = try cursor.readLittleInt64()
        self.vtable = try cursor.readLittleInt64()
        self.data = try cursor.readLittleInt64()
        self.reserved1 = try cursor.readLittleInt64()
        self.reserved2 = try cursor.readLittleInt64()
        self.reserved3 = try cursor.readLittleInt64()
      } else {
        self.isa = try cursor.readBigInt64()
        self.superclass = try cursor.readBigInt64()
        self.cache = try cursor.readBigInt64()
        self.vtable = try cursor.readBigInt64()
        self.data = try cursor.readBigInt64()
        self.reserved1 = try cursor.readBigInt64()
        self.reserved2 = try cursor.readBigInt64()
        self.reserved3 = try cursor.readBigInt64()
      }
    } else {
      if byteOrder == .little {
        self.isa = UInt64(try cursor.readLittleInt32())
        self.superclass = UInt64(try cursor.readLittleInt32())
        self.cache = UInt64(try cursor.readLittleInt32())
        self.vtable = UInt64(try cursor.readLittleInt32())
        self.data = UInt64(try cursor.readLittleInt32())
        self.reserved1 = UInt64(try cursor.readLittleInt32())
        self.reserved2 = UInt64(try cursor.readLittleInt32())
        self.reserved3 = UInt64(try cursor.readLittleInt32())
      } else {
        self.isa = UInt64(try cursor.readBigInt32())
        self.superclass = UInt64(try cursor.readBigInt32())
        self.cache = UInt64(try cursor.readBigInt32())
        self.vtable = UInt64(try cursor.readBigInt32())
        self.data = UInt64(try cursor.readBigInt32())
        self.reserved1 = UInt64(try cursor.readBigInt32())
        self.reserved2 = UInt64(try cursor.readBigInt32())
        self.reserved3 = UInt64(try cursor.readBigInt32())
      }
    }
  }
}
