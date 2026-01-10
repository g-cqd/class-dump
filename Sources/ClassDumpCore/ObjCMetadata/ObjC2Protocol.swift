// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

/// ObjC 2.0 protocol structure.
public struct ObjC2Protocol: Sendable {
  /// Pointer to isa (usually null).
  public let isa: UInt64

  /// Pointer to name string.
  public let name: UInt64

  /// Pointer to adopted protocols.
  public let protocols: UInt64

  /// Pointer to instance methods.
  public let instanceMethods: UInt64

  /// Pointer to class methods.
  public let classMethods: UInt64

  /// Pointer to optional instance methods.
  public let optionalInstanceMethods: UInt64

  /// Pointer to optional class methods.
  public let optionalClassMethods: UInt64

  /// Pointer to instance properties.
  public let instanceProperties: UInt64

  /// Size of the protocol structure.
  public let size: UInt32

  /// Protocol flags.
  public let flags: UInt32

  /// Pointer to extended method types.
  public let extendedMethodTypes: UInt64

  /// Parse a protocol structure.
  public init(cursor: inout DataCursor, byteOrder: ByteOrder, is64Bit: Bool, ptrSize: Int) throws {
    if is64Bit {
      if byteOrder == .little {
        self.isa = try cursor.readLittleInt64()
        self.name = try cursor.readLittleInt64()
        self.protocols = try cursor.readLittleInt64()
        self.instanceMethods = try cursor.readLittleInt64()
        self.classMethods = try cursor.readLittleInt64()
        self.optionalInstanceMethods = try cursor.readLittleInt64()
        self.optionalClassMethods = try cursor.readLittleInt64()
        self.instanceProperties = try cursor.readLittleInt64()
        self.size = try cursor.readLittleInt32()
        self.flags = try cursor.readLittleInt32()

        // Check if there's an extended method types field
        let hasExtendedMethodTypes = size > UInt32(8 * ptrSize + 2 * 4)
        self.extendedMethodTypes = hasExtendedMethodTypes ? try cursor.readLittleInt64() : 0
      } else {
        self.isa = try cursor.readBigInt64()
        self.name = try cursor.readBigInt64()
        self.protocols = try cursor.readBigInt64()
        self.instanceMethods = try cursor.readBigInt64()
        self.classMethods = try cursor.readBigInt64()
        self.optionalInstanceMethods = try cursor.readBigInt64()
        self.optionalClassMethods = try cursor.readBigInt64()
        self.instanceProperties = try cursor.readBigInt64()
        self.size = try cursor.readBigInt32()
        self.flags = try cursor.readBigInt32()

        let hasExtendedMethodTypes = size > UInt32(8 * ptrSize + 2 * 4)
        self.extendedMethodTypes = hasExtendedMethodTypes ? try cursor.readBigInt64() : 0
      }
    } else {
      if byteOrder == .little {
        self.isa = UInt64(try cursor.readLittleInt32())
        self.name = UInt64(try cursor.readLittleInt32())
        self.protocols = UInt64(try cursor.readLittleInt32())
        self.instanceMethods = UInt64(try cursor.readLittleInt32())
        self.classMethods = UInt64(try cursor.readLittleInt32())
        self.optionalInstanceMethods = UInt64(try cursor.readLittleInt32())
        self.optionalClassMethods = UInt64(try cursor.readLittleInt32())
        self.instanceProperties = UInt64(try cursor.readLittleInt32())
        self.size = try cursor.readLittleInt32()
        self.flags = try cursor.readLittleInt32()

        let hasExtendedMethodTypes = size > UInt32(8 * ptrSize + 2 * 4)
        self.extendedMethodTypes =
          hasExtendedMethodTypes ? UInt64(try cursor.readLittleInt32()) : 0
      } else {
        self.isa = UInt64(try cursor.readBigInt32())
        self.name = UInt64(try cursor.readBigInt32())
        self.protocols = UInt64(try cursor.readBigInt32())
        self.instanceMethods = UInt64(try cursor.readBigInt32())
        self.classMethods = UInt64(try cursor.readBigInt32())
        self.optionalInstanceMethods = UInt64(try cursor.readBigInt32())
        self.optionalClassMethods = UInt64(try cursor.readBigInt32())
        self.instanceProperties = UInt64(try cursor.readBigInt32())
        self.size = try cursor.readBigInt32()
        self.flags = try cursor.readBigInt32()

        let hasExtendedMethodTypes = size > UInt32(8 * ptrSize + 2 * 4)
        self.extendedMethodTypes = hasExtendedMethodTypes ? UInt64(try cursor.readBigInt32()) : 0
      }
    }
  }
}
