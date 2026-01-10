// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

/// Pure lookup tables for Swift name demangling.
///
/// This enum serves as a namespace for all constant lookup tables used
/// in the demangling process. All tables are pure data with no side effects.
///
/// The tables are organized by category:
/// - Type shortcuts: Single and multi-character type abbreviations
/// - Protocol shortcuts: Common protocol abbreviations
/// - Builtin types: Low-level Swift builtins
/// - ObjC mappings: Objective-C to Swift type conversions
/// - Function markers: Function kind indicators
enum SwiftDemanglerTables: Sendable {

  // MARK: - Type Shortcuts

  /// Standard library type shortcuts (single character).
  ///
  /// These are single-character codes used in Swift name mangling
  /// to represent common stdlib types.
  ///
  /// Reference: Swift ABI stability documentation.
  static let typeShortcuts: [Character: String] = [
    "a": "Array",
    "b": "Bool",
    "D": "Dictionary",
    "d": "Double",
    "f": "Float",
    "h": "Set",
    "i": "Int",
    "J": "Character",
    "N": "ClosedRange",
    "n": "Range",
    "O": "ObjectIdentifier",
    "P": "UnsafePointer",
    "p": "UnsafeMutablePointer",
    "q": "Optional",
    "R": "UnsafeBufferPointer",
    "r": "UnsafeMutableBufferPointer",
    "S": "String",
    "s": "Substring",
    "u": "UInt",
    "V": "UnsafeRawPointer",
    "v": "UnsafeMutableRawPointer",
  ]

  // MARK: - Builtin Types

  /// Builtin type mappings.
  ///
  /// These represent low-level Swift/LLVM builtin types that
  /// appear in mangled names with a 'B' prefix.
  static let builtinTypes: [String: String] = [
    "Bb": "Builtin.BridgeObject",
    "Bo": "Builtin.NativeObject",
    "BO": "Builtin.UnknownObject",
    "Bp": "Builtin.RawPointer",
    "Bw": "Builtin.Word",
    "BB": "Builtin.UnsafeValueBuffer",
    "BD": "Builtin.DefaultActorStorage",
    "Be": "Builtin.Executor",
    "Bi": "Builtin.Int",
    "Bf": "Builtin.FPIEEE",
    "Bv": "Builtin.Vec",
  ]

  // MARK: - Common Patterns

  /// Common mangled type patterns.
  ///
  /// Two-character codes and common patterns that map directly
  /// to well-known Swift types. Organized by category.
  static let commonPatterns: [String: String] = [
    // Basic types with S prefix
    "Sa": "Array",
    "Sb": "Bool",
    "SD": "Dictionary",
    "Sd": "Double",
    "Sf": "Float",
    "Sh": "Set",
    "Si": "Int",
    "SS": "String",
    "Su": "UInt",
    "SZ": "UInt8",
    "Ss": "Int8",

    // Fixed-width integers (fully qualified)
    "s5Int8V": "Int8",
    "s6UInt8V": "UInt8",
    "s5Int16V": "Int16",
    "s6UInt16V": "UInt16",
    "s5Int32V": "Int32",
    "s6UInt32V": "UInt32",
    "s5Int64V": "Int64",
    "s6UInt64V": "UInt64",

    // Optional patterns
    "Sg": "Optional",
    "ySg": "?",
    "Sq": "Optional",

    // Void
    "yt": "Void",

    // Concurrency types (Sc prefix)
    "ScT": "Task",
    "Scg": "TaskGroup",
    "ScG": "ThrowingTaskGroup",
    "ScP": "TaskPriority",
    "ScA": "Actor",
    "ScM": "MainActor",
    "ScC": "CheckedContinuation",
    "ScU": "UnsafeContinuation",
    "ScS": "AsyncStream",
    "ScF": "AsyncThrowingStream",
  ]

  // MARK: - Protocol Shortcuts

  /// Swift standard library protocol shortcuts.
  ///
  /// Two-character codes and qualified names for common protocols.
  static let protocolShortcuts: [String: String] = [
    // Two-character shortcuts
    "SH": "Hashable",
    "SE": "Equatable",
    "SQ": "Equatable",
    "Sl": "Collection",
    "ST": "Sequence",
    "Sj": "Numeric",
    "SL": "Comparable",
    "Sz": "BinaryInteger",
    "SZ": "SignedInteger",
    "SU": "UnsignedInteger",
    "Sx": "ExpressibleByIntegerLiteral",
    "SY": "RawRepresentable",
    "Sc": "UnicodeScalar",
    "SK": "BidirectionalCollection",
    "Sk": "RandomAccessCollection",
    "SM": "MutableCollection",
    "Sm": "RangeReplaceableCollection",
    "SN": "FixedWidthInteger",
    "Se": "Encodable",
    "SD": "Decodable",

    // Qualified protocol names
    "s10StringProtocol": "StringProtocol",
    "s8SendableP": "Sendable",
    "s5ErrorP": "Error",
    "s7CodableP": "Codable",
    "s10ComparableP": "Comparable",
    "s8HashableP": "Hashable",
    "s9EquatableP": "Equatable",
    "s16TextOutputStreamP": "TextOutputStream",
    "s17CustomStringConvertibleP": "CustomStringConvertible",
    "s18AdditiveArithmeticP": "AdditiveArithmetic",
    "s5ActorP": "Actor",
    "s12AsyncSequenceP": "AsyncSequence",
    "s17AsyncIteratorProtocolP": "AsyncIteratorProtocol",
    "s16IteratorProtocolP": "IteratorProtocol",
    "s10IdentifiableP": "Identifiable",
  ]

  // MARK: - ObjC Type Mappings

  /// ObjC type to Swift type mappings.
  ///
  /// Maps Objective-C type names to their Swift equivalents
  /// for better readability in demangled output.
  static let objcToSwiftTypes: [String: String] = [
    // GCD types
    "OS_dispatch_queue": "DispatchQueue",
    "OS_dispatch_group": "DispatchGroup",
    "OS_dispatch_semaphore": "DispatchSemaphore",
    "OS_dispatch_source": "DispatchSource",
    "OS_dispatch_data": "DispatchData",
    "OS_dispatch_io": "DispatchIO",
    "OS_dispatch_workloop": "DispatchWorkloop",

    // Foundation types
    "NSObject": "NSObject",
    "NSString": "String",
    "NSArray": "Array",
    "NSDictionary": "Dictionary",
    "NSSet": "Set",
    "NSNumber": "NSNumber",
    "NSError": "NSError",
    "NSURL": "URL",
    "NSData": "Data",
    "NSDate": "Date",
  ]

  // MARK: - Function Markers

  /// Function kind markers that indicate a function symbol.
  ///
  /// These characters appear at the end of a mangled function symbol
  /// to indicate the kind of function.
  static let functionKindMarkers: Set<Character> = [
    "F",  // Regular function
    "f",  // Function implementation
    "g",  // Getter
    "s",  // Setter
    "W",  // Witness method
    "Z",  // Static method
  ]

  // MARK: - Lookup Functions

  /// Look up a type shortcut by character.
  ///
  /// Pure function: `Character -> String?`
  static func typeShortcut(for char: Character) -> String? {
    typeShortcuts[char]
  }

  /// Look up a builtin type.
  ///
  /// Pure function: `String -> String?`
  static func builtinType(for key: String) -> String? {
    builtinTypes[key]
  }

  /// Look up a common pattern.
  ///
  /// Pure function: `String -> String?`
  static func commonPattern(for key: String) -> String? {
    commonPatterns[key]
  }

  /// Look up a protocol shortcut.
  ///
  /// Pure function: `String -> String?`
  static func protocolShortcut(for key: String) -> String? {
    protocolShortcuts[key]
  }

  /// Look up an ObjC type mapping.
  ///
  /// Pure function: `String -> String?`
  static func swiftType(forObjC objcType: String) -> String? {
    objcToSwiftTypes[objcType]
  }

  /// Check if a character is a function kind marker.
  ///
  /// Pure function: `Character -> Bool`
  static func isFunctionKindMarker(_ char: Character) -> Bool {
    functionKindMarkers.contains(char)
  }
}
