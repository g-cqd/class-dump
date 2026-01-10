// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

/// A Swift type (class, struct, or enum).
public struct SwiftType: Sendable {
  /// File offset of the type descriptor.
  public let address: UInt64

  /// Kind of type (class, struct, enum).
  public let kind: SwiftContextDescriptorKind

  /// Simple name of the type.
  public let name: String

  /// Mangled name (if available).
  public let mangledName: String

  /// Parent type/module name.
  public let parentName: String?

  /// Parent context kind (module, extension, class, struct, etc.).
  public let parentKind: SwiftContextDescriptorKind?

  /// Superclass name (for classes only).
  public let superclassName: String?

  /// Fields/properties of the type.
  public let fields: [SwiftField]

  /// Generic type parameter names (e.g., ["T", "U"] for `Foo<T, U>`).
  public let genericParameters: [String]

  /// Number of generic parameters (from descriptor header).
  public let genericParamCount: Int

  /// Generic requirements (where clauses).
  public let genericRequirements: [SwiftGenericRequirement]

  /// Type context descriptor flags.
  public let flags: TypeContextDescriptorFlags

  /// Whether this type is generic.
  public var isGeneric: Bool { genericParamCount > 0 }

  /// ObjC class metadata address (for Swift classes exposed to ObjC).
  ///
  /// This allows linking Swift type descriptors to ObjC class metadata.
  public let objcClassAddress: UInt64?

  /// Initialize a Swift type.
  public init(
    address: UInt64,
    kind: SwiftContextDescriptorKind,
    name: String,
    mangledName: String = "",
    parentName: String? = nil,
    parentKind: SwiftContextDescriptorKind? = nil,
    superclassName: String? = nil,
    fields: [SwiftField] = [],
    genericParameters: [String] = [],
    genericParamCount: Int = 0,
    genericRequirements: [SwiftGenericRequirement] = [],
    flags: TypeContextDescriptorFlags = TypeContextDescriptorFlags(rawValue: 0),
    objcClassAddress: UInt64? = nil
  ) {
    self.address = address
    self.kind = kind
    self.name = name
    self.mangledName = mangledName
    self.parentName = parentName
    self.parentKind = parentKind
    self.superclassName = superclassName
    self.fields = fields
    self.genericParameters = genericParameters
    self.genericParamCount = genericParamCount
    self.genericRequirements = genericRequirements
    self.flags = flags
    self.objcClassAddress = objcClassAddress
  }

  /// Full qualified name including parent.
  public var fullName: String {
    if let parent = parentName, !parent.isEmpty {
      return "\(parent).\(name)"
    }
    return name
  }

  /// Full name with generic parameters (e.g., "Module.Container<T>").
  public var fullNameWithGenerics: String {
    let base = fullName
    if genericParamCount > 0 {
      if genericParameters.isEmpty {
        // Use placeholder names if we don't have actual names
        let params = (0..<genericParamCount).map { "T\($0)" }
        return "\(base)<\(params.joined(separator: ", "))>"
      }
      return "\(base)<\(genericParameters.joined(separator: ", "))>"
    }
    return base
  }

  /// Whether this is a nested type (inside another type, not just a module).
  public var isNestedType: Bool {
    guard let parentKind else { return false }
    return parentKind.isType
  }

  /// Whether this type has generic constraints (where clauses).
  public var hasGenericConstraints: Bool {
    !genericRequirements.isEmpty
  }

  /// Format generic constraints as a where clause string.
  public var whereClause: String {
    guard !genericRequirements.isEmpty else { return "" }
    return "where " + genericRequirements.map(\.description).joined(separator: ", ")
  }

  /// Whether the type is unique (descriptor should be uniqued).
  public var isUnique: Bool {
    flags.isUnique
  }

  /// Whether the class has a virtual table (classes only).
  public var hasVTable: Bool {
    kind == .class && flags.hasVTable
  }

  /// Whether the class has a resilient superclass (classes only).
  public var hasResilientSuperclass: Bool {
    kind == .class && flags.hasResilientSuperclass
  }
}
