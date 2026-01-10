// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

/// ObjC 2.0 category structure.
public struct ObjC2Category: Sendable {
  /// Pointer to category name.
  public let name: UInt64

  /// Pointer to class (note: 'class' is a Swift keyword).
  public let cls: UInt64

  /// Pointer to instance methods.
  public let instanceMethods: UInt64

  /// Pointer to class methods.
  public let classMethods: UInt64

  /// Pointer to adopted protocols.
  public let protocols: UInt64

  /// Pointer to instance properties.
  public let instanceProperties: UInt64

  /// Reserved field 1.
  public let v7: UInt64

  /// Reserved field 2.
  public let v8: UInt64

  /// Parse a category structure.
  public init(cursor: inout DataCursor, byteOrder: ByteOrder, is64Bit: Bool) throws {
    if is64Bit {
      if byteOrder == .little {
        self.name = try cursor.readLittleInt64()
        self.cls = try cursor.readLittleInt64()
        self.instanceMethods = try cursor.readLittleInt64()
        self.classMethods = try cursor.readLittleInt64()
        self.protocols = try cursor.readLittleInt64()
        self.instanceProperties = try cursor.readLittleInt64()
        self.v7 = try cursor.readLittleInt64()
        self.v8 = try cursor.readLittleInt64()
      } else {
        self.name = try cursor.readBigInt64()
        self.cls = try cursor.readBigInt64()
        self.instanceMethods = try cursor.readBigInt64()
        self.classMethods = try cursor.readBigInt64()
        self.protocols = try cursor.readBigInt64()
        self.instanceProperties = try cursor.readBigInt64()
        self.v7 = try cursor.readBigInt64()
        self.v8 = try cursor.readBigInt64()
      }
    } else {
      if byteOrder == .little {
        self.name = UInt64(try cursor.readLittleInt32())
        self.cls = UInt64(try cursor.readLittleInt32())
        self.instanceMethods = UInt64(try cursor.readLittleInt32())
        self.classMethods = UInt64(try cursor.readLittleInt32())
        self.protocols = UInt64(try cursor.readLittleInt32())
        self.instanceProperties = UInt64(try cursor.readLittleInt32())
        self.v7 = UInt64(try cursor.readLittleInt32())
        self.v8 = UInt64(try cursor.readLittleInt32())
      } else {
        self.name = UInt64(try cursor.readBigInt32())
        self.cls = UInt64(try cursor.readBigInt32())
        self.instanceMethods = UInt64(try cursor.readBigInt32())
        self.classMethods = UInt64(try cursor.readBigInt32())
        self.protocols = UInt64(try cursor.readBigInt32())
        self.instanceProperties = UInt64(try cursor.readBigInt32())
        self.v7 = UInt64(try cursor.readBigInt32())
        self.v8 = UInt64(try cursor.readBigInt32())
      }
    }
  }
}
