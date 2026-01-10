// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

/// Kind of generic requirement.
public enum GenericRequirementKind: UInt8, Sendable {
  /// A protocol conformance requirement (T: Protocol).
  case `protocol` = 0
  /// A same-type requirement (T == U or T == SomeType).
  case sameType = 1
  /// A base class requirement (T: BaseClass).
  case baseClass = 2
  /// A same-conformance requirement.
  case sameConformance = 3
  /// A layout requirement (T: AnyObject, T: class).
  case layout = 4
}

/// A generic requirement (constraint) for a type.
public struct SwiftGenericRequirement: Sendable {
  /// The kind of requirement.
  public let kind: GenericRequirementKind

  /// The parameter being constrained (e.g., "T", "Element").
  public let param: String

  /// The constraint type or protocol name (e.g., "Equatable", "Int").
  public let constraint: String

  /// Raw flags from the requirement descriptor.
  public let flags: UInt32

  /// Initialize a generic requirement.
  public init(kind: GenericRequirementKind, param: String, constraint: String, flags: UInt32 = 0) {
    self.kind = kind
    self.param = param
    self.constraint = constraint
    self.flags = flags
  }

  /// Whether this requirement has a key argument.
  public var hasKeyArgument: Bool {
    (flags & 0x80) != 0
  }

  /// Whether this requirement has an extra argument.
  public var hasExtraArgument: Bool {
    (flags & 0x40) != 0
  }

  /// Format as a Swift-style constraint string.
  public var description: String {
    switch kind {
    case .protocol:
      return "\(param): \(constraint)"
    case .sameType:
      return "\(param) == \(constraint)"
    case .baseClass:
      return "\(param): \(constraint)"
    case .sameConformance:
      return "\(param): \(constraint)"
    case .layout:
      if constraint == "AnyObject" || constraint == "class" {
        return "\(param): AnyObject"
      }
      return "\(param): \(constraint)"
    }
  }
}
