// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

/// Kind of field descriptor.
public enum SwiftFieldDescriptorKind: UInt16, Sendable {
  case `struct` = 0
  case `class` = 1
  case `enum` = 2
  case multiPayloadEnum = 3
  case `protocol` = 4
  case classProtocol = 5
  case objcProtocol = 6
  case objcClass = 7
}

/// A Swift field descriptor from __swift5_fieldmd section.
public struct SwiftFieldDescriptor: Sendable {
  /// Address of the field descriptor.
  public let address: UInt64

  /// Kind of descriptor.
  public let kind: SwiftFieldDescriptorKind

  /// Mangled type name.
  public let mangledTypeName: String

  /// Raw bytes of the mangled type name (for symbolic reference resolution).
  public let mangledTypeNameData: Data

  /// File offset where the mangled type name was read (for symbolic resolution).
  public let mangledTypeNameOffset: Int

  /// Mangled name of the superclass (if any).
  public let superclassMangledName: String?

  /// Field records.
  public let records: [SwiftFieldRecord]

  /// Check if the owning type uses a symbolic reference.
  public var hasSymbolicReference: Bool {
    guard !mangledTypeNameData.isEmpty else { return false }
    let firstByte = mangledTypeNameData[mangledTypeNameData.startIndex]
    return SwiftSymbolicReferenceKind.isSymbolicMarker(firstByte)
  }

  /// Initialize a field descriptor.
  public init(
    address: UInt64,
    kind: SwiftFieldDescriptorKind,
    mangledTypeName: String,
    mangledTypeNameData: Data = Data(),
    mangledTypeNameOffset: Int = 0,
    superclassMangledName: String? = nil,
    records: [SwiftFieldRecord] = []
  ) {
    self.address = address
    self.kind = kind
    self.mangledTypeName = mangledTypeName
    self.mangledTypeNameData = mangledTypeNameData
    self.mangledTypeNameOffset = mangledTypeNameOffset
    self.superclassMangledName = superclassMangledName
    self.records = records
  }
}

// MARK: - Field Record

/// A field record within a field descriptor.
public struct SwiftFieldRecord: Sendable {
  /// Field flags.
  public let flags: UInt32

  /// Field name.
  public let name: String

  /// Mangled type name of the field.
  public let mangledTypeName: String

  /// Raw bytes of the mangled type name (for symbolic reference resolution).
  public let mangledTypeData: Data

  /// File offset where the mangled type name was read (for symbolic resolution).
  public let mangledTypeNameOffset: Int

  /// Whether this is a variable (vs let).
  public var isVar: Bool { (flags & 0x2) != 0 }

  /// Whether this is an indirect field (enum case).
  public var isIndirect: Bool { (flags & 0x1) != 0 }

  /// Check if the type uses a symbolic reference at the start.
  public var hasSymbolicReference: Bool {
    guard !mangledTypeData.isEmpty else { return false }
    let firstByte = mangledTypeData[mangledTypeData.startIndex]
    return SwiftSymbolicReferenceKind.isSymbolicMarker(firstByte)
  }

  /// Check if the type contains any embedded symbolic references.
  ///
  /// Swift mangled names can have symbolic refs embedded anywhere, not just at the start.
  public var hasEmbeddedSymbolicReference: Bool {
    guard mangledTypeData.count >= 6 else { return false }
    let bytes = Array(mangledTypeData)
    // Look for symbolic reference markers (0x01, 0x02) after the first byte
    // A symbolic ref is 5 bytes, so the marker can appear at most at count-4
    for i in 1..<bytes.count {
      let byte = bytes[i]
      if byte == 0x01 || byte == 0x02 {
        return true
      }
    }
    return false
  }

  /// Initialize a field record.
  public init(
    flags: UInt32,
    name: String,
    mangledTypeName: String,
    mangledTypeData: Data = Data(),
    mangledTypeNameOffset: Int = 0
  ) {
    self.flags = flags
    self.name = name
    self.mangledTypeName = mangledTypeName
    self.mangledTypeData = mangledTypeData
    self.mangledTypeNameOffset = mangledTypeNameOffset
  }
}
