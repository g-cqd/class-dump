// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

/// A Swift extension on a type.
///
/// Extensions in Swift can add protocol conformances, methods, and computed properties
/// to existing types. This structure captures extension metadata from `__swift5_types`.
public struct SwiftExtension: Sendable {
  /// File offset of the extension descriptor.
  public let address: UInt64

  /// The name of the extended type.
  public let extendedTypeName: String

  /// Mangled name of the extended type.
  public let mangledExtendedTypeName: String

  /// Module containing the extension.
  public let moduleName: String?

  /// Protocol conformances added by this extension.
  public let addedConformances: [String]

  /// Generic parameters (if extension is generic).
  public let genericParameters: [String]

  /// Number of generic parameters.
  public let genericParamCount: Int

  /// Generic requirements (where clauses).
  public let genericRequirements: [SwiftGenericRequirement]

  /// Type context descriptor flags.
  public let flags: TypeContextDescriptorFlags

  /// Whether this extension is generic.
  public var isGeneric: Bool { genericParamCount > 0 }

  /// Whether this extension adds protocol conformances.
  public var addsConformances: Bool { !addedConformances.isEmpty }

  /// Whether this extension has generic constraints (where clauses).
  public var hasGenericConstraints: Bool { !genericRequirements.isEmpty }

  /// Format generic constraints as a where clause string.
  public var whereClause: String {
    guard !genericRequirements.isEmpty else { return "" }
    return "where " + genericRequirements.map(\.description).joined(separator: ", ")
  }

  /// Initialize a Swift extension.
  public init(
    address: UInt64,
    extendedTypeName: String,
    mangledExtendedTypeName: String = "",
    moduleName: String? = nil,
    addedConformances: [String] = [],
    genericParameters: [String] = [],
    genericParamCount: Int = 0,
    genericRequirements: [SwiftGenericRequirement] = [],
    flags: TypeContextDescriptorFlags = TypeContextDescriptorFlags(rawValue: 0)
  ) {
    self.address = address
    self.extendedTypeName = extendedTypeName
    self.mangledExtendedTypeName = mangledExtendedTypeName
    self.moduleName = moduleName
    self.addedConformances = addedConformances
    self.genericParameters = genericParameters
    self.genericParamCount = genericParamCount
    self.genericRequirements = genericRequirements
    self.flags = flags
  }
}
