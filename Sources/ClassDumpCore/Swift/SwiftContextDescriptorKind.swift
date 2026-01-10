// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

/// The kind of Swift context descriptor.
public enum SwiftContextDescriptorKind: UInt8, Sendable {
  case module = 0
  case `extension` = 1
  case anonymous = 2
  case `protocol` = 3
  case opaqueType = 4
  // Types start at 16
  case `class` = 16
  case `struct` = 17
  case `enum` = 18

  /// Check if this kind represents a type (class, struct, or enum).
  public var isType: Bool {
    rawValue >= 16 && rawValue <= 31
  }
}
