// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

/// Common list header for ObjC 2.0 data structures.
public struct ObjC2ListHeader: Sendable {
  /// The size of each entry in the list.
  public let entsize: UInt32

  /// The number of entries in the list.
  public let count: UInt32

  /// Flags in the high bits of entsize.
  private static let smallMethodsFlag: UInt32 = 0x8000_0000  // Bit 31
  private static let directSelectorsFlag: UInt32 = 0x4000_0000  // Bit 30 (iOS 16+)
  private static let flagsMask: UInt32 = 0xFFFF_0000  // High 16 bits are flags

  /// The actual entry size (with flags masked out).
  ///
  /// The high bits contain flags and the low bits contain the entry size.
  public var actualEntsize: UInt32 {
    entsize & ~Self.flagsMask & ~3
  }

  /// Whether this list uses small methods (bit 31 set).
  ///
  /// Small methods use 12-byte relative entries instead of 24-byte absolute pointers.
  public var usesSmallMethods: Bool {
    (entsize & Self.smallMethodsFlag) != 0
  }

  /// Whether this list uses direct selectors (bit 30 set, iOS 16+).
  ///
  /// With direct selectors, the nameOffset points directly to the selector string,
  /// not to a selector reference that then points to the string.
  public var usesDirectSelectors: Bool {
    (entsize & Self.directSelectorsFlag) != 0
  }

  /// Initialize a list header manually.
  public init(entsize: UInt32, count: UInt32) {
    self.entsize = entsize
    self.count = count
  }

  /// Parse a list header from data.
  public init(cursor: inout DataCursor, byteOrder: ByteOrder) throws {
    if byteOrder == .little {
      self.entsize = try cursor.readLittleInt32()
      self.count = try cursor.readLittleInt32()
    } else {
      self.entsize = try cursor.readBigInt32()
      self.count = try cursor.readBigInt32()
    }
  }
}
