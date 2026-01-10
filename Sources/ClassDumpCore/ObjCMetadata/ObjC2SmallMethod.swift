// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

/// ObjC 2.0 small method structure (relative offsets).
///
/// Used in iOS 14+ / macOS 11+ binaries.
public struct ObjC2SmallMethod: Sendable {
  /// Relative offset to selector reference.
  public let nameOffset: Int32

  /// Relative offset to type encoding.
  public let typesOffset: Int32

  /// Relative offset to implementation.
  public let impOffset: Int32

  /// Parse a small method structure.
  public init(cursor: inout DataCursor, byteOrder: ByteOrder) throws {
    if byteOrder == .little {
      self.nameOffset = Int32(bitPattern: try cursor.readLittleInt32())
      self.typesOffset = Int32(bitPattern: try cursor.readLittleInt32())
      self.impOffset = Int32(bitPattern: try cursor.readLittleInt32())
    } else {
      self.nameOffset = Int32(bitPattern: try cursor.readBigInt32())
      self.typesOffset = Int32(bitPattern: try cursor.readBigInt32())
      self.impOffset = Int32(bitPattern: try cursor.readBigInt32())
    }
  }
}
