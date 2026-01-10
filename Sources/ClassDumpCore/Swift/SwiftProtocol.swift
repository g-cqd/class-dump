// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

/// A Swift protocol.
public struct SwiftProtocol: Sendable {
  /// Address of the protocol descriptor.
  public let address: UInt64

  /// Protocol name.
  public let name: String

  /// Mangled protocol name.
  public let mangledName: String

  /// Parent module or namespace name.
  public let parentName: String?

  /// Associated type names declared by this protocol.
  public let associatedTypeNames: [String]

  /// Protocols that this protocol inherits from.
  public let inheritedProtocols: [String]

  /// All requirements of this protocol.
  public let requirements: [SwiftProtocolRequirement]

  /// Initialize a Swift protocol.
  public init(
    address: UInt64,
    name: String,
    mangledName: String = "",
    parentName: String? = nil,
    associatedTypeNames: [String] = [],
    inheritedProtocols: [String] = [],
    requirements: [SwiftProtocolRequirement] = []
  ) {
    self.address = address
    self.name = name
    self.mangledName = mangledName
    self.parentName = parentName
    self.associatedTypeNames = associatedTypeNames
    self.inheritedProtocols = inheritedProtocols
    self.requirements = requirements
  }

  /// Full qualified name including parent module.
  public var fullName: String {
    if let parent = parentName, !parent.isEmpty {
      return "\(parent).\(name)"
    }
    return name
  }

  /// Number of method requirements.
  public var methodCount: Int {
    requirements.filter { $0.kind == .method }.count
  }

  /// Number of property requirements (getters + setters).
  public var propertyCount: Int {
    requirements.filter { $0.kind == .getter }.count
  }

  /// Number of initializer requirements.
  public var initializerCount: Int {
    requirements.filter { $0.kind == .initializer }.count
  }
}

// MARK: - Protocol Requirement

/// A Swift protocol requirement.
public struct SwiftProtocolRequirement: Sendable {
  /// Kind of requirement.
  public enum Kind: UInt8, Sendable {
    case baseProtocol = 0
    case method = 1
    case initializer = 2
    case getter = 3
    case setter = 4
    case readCoroutine = 5
    case modifyCoroutine = 6
    case associatedTypeAccessFunction = 7
    case associatedConformanceAccessFunction = 8

    /// Human-readable description of this requirement kind.
    public var description: String {
      switch self {
      case .baseProtocol: return "base protocol"
      case .method: return "method"
      case .initializer: return "initializer"
      case .getter: return "getter"
      case .setter: return "setter"
      case .readCoroutine: return "read coroutine"
      case .modifyCoroutine: return "modify coroutine"
      case .associatedTypeAccessFunction: return "associated type"
      case .associatedConformanceAccessFunction: return "associated conformance"
      }
    }
  }

  /// The kind of requirement.
  public let kind: Kind

  /// The requirement name.
  public let name: String

  /// Whether this is an instance requirement (vs static/class).
  public let isInstance: Bool

  /// Whether this is an async requirement.
  public let isAsync: Bool

  /// Whether this requirement has a default implementation.
  public let hasDefaultImplementation: Bool

  /// Initialize a protocol requirement.
  public init(
    kind: Kind,
    name: String,
    isInstance: Bool = true,
    isAsync: Bool = false,
    hasDefaultImplementation: Bool = false
  ) {
    self.kind = kind
    self.name = name
    self.isInstance = isInstance
    self.isAsync = isAsync
    self.hasDefaultImplementation = hasDefaultImplementation
  }
}
