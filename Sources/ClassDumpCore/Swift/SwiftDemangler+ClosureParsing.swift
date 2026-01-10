// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

/// Closure and function type parsing extensions for SwiftDemangler.
///
/// This extension provides pure parsing functions for Swift closure
/// and function type expressions including calling conventions, effects,
/// and parameter/return types.
///
/// All functions are pure - they take input and return output without side effects.
extension SwiftDemangler {

  // MARK: - Closure Convention Parsing

  /// Parse calling convention from mangled suffix.
  ///
  /// Pure function that determines the closure convention from suffix markers.
  ///
  /// Convention suffixes:
  /// - `XB` - @convention(block) (ObjC block)
  /// - `XC` - @convention(c) (C function pointer)
  /// - `XE` - noescape function type
  /// - `Xf` - @thin function type
  /// - `c`  - escaping function type
  ///
  /// - Parameter input: The mangled closure string.
  /// - Returns: Tuple of (convention, isEscaping, input with suffix removed) or nil.
  static func parseClosureConvention(_ input: Substring) -> (
    convention: ClosureConvention, isEscaping: Bool, rest: Substring
  )? {
    if input.hasSuffix("XB") {
      return (.block, true, input.dropLast(2))
    }
    if input.hasSuffix("XC") {
      return (.cFunction, true, input.dropLast(2))
    }
    if input.hasSuffix("XE") {
      return (.swift, false, input.dropLast(2))  // noescape
    }
    if input.hasSuffix("Xf") {
      return (.thin, true, input.dropLast(2))
    }
    if input.hasSuffix("c") {
      return (.swift, true, input.dropLast(1))  // escaping
    }

    // No recognized function type suffix
    return nil
  }

  // MARK: - Closure Type Parsing

  /// Parse closure type components from mangled input.
  ///
  /// Pure function that extracts all closure components including
  /// parameters, return type, and effect markers.
  ///
  /// Effect markers:
  /// - `Ya` - async
  /// - `Yb` - @Sendable
  /// - `K`  - throws
  /// - `y`  - empty list (Void)
  ///
  /// - Parameter input: The mangled closure body (without convention suffix).
  /// - Returns: A `ClosureParseResult` with all parsed components.
  static func parseClosureTypeComponents(_ input: Substring) -> ClosureParseResult {
    var remaining = input
    var parsedTypes: [String] = []
    var isAsync = false
    var isThrowing = false
    var isSendable = false

    while !remaining.isEmpty {
      // Try effect markers first
      if let (effect, rest) = parseEffectMarker(remaining) {
        switch effect {
        case .async:
          isAsync = true
        case .sendable:
          isSendable = true
        case .throwing:
          isThrowing = true
        case .voidMarker:
          parsedTypes.append("Void")
        }
        remaining = rest
        continue
      }

      // Try to parse a type
      if let (typeName, rest) = parseGenericTypeArg(remaining, depth: 0) {
        parsedTypes.append(typeName)
        remaining = rest
        continue
      }

      if let (typeName, rest) = SwiftDemanglerParsers.lengthPrefixed(remaining) {
        parsedTypes.append(typeName)
        remaining = rest
        // Skip type suffix
        while let c = remaining.first, "CVO".contains(c) {
          remaining = remaining.dropFirst()
        }
        continue
      }

      // Can't parse more, stop
      break
    }

    // Interpret parsed types:
    // In Swift mangling, return type comes first, then params
    let returnType = parsedTypes.first ?? "Void"
    let params = parsedTypes.count >= 2
      ? Array(parsedTypes[1...]).filter { $0 != "Void" }
      : []

    return ClosureParseResult(
      params: params,
      returnType: returnType,
      isAsync: isAsync,
      isThrowing: isThrowing,
      isSendable: isSendable
    )
  }

  // MARK: - Function Signature Parsing

  /// Parse function signature types from mangled input.
  ///
  /// Pure function for parsing complete function signatures including
  /// typed throws support.
  ///
  /// - Parameter input: The mangled function signature.
  /// - Returns: A `FunctionSignatureParseResult` with all parsed components.
  static func parseFunctionSignatureTypes(_ input: Substring) -> FunctionSignatureParseResult {
    var remaining = input
    var parsedTypes: [String] = []
    var isAsync = false
    var isThrowing = false
    var isSendable = false
    var errorType: String? = nil

    while !remaining.isEmpty {
      // Check for effect markers
      if remaining.hasPrefix("Ya") {
        isAsync = true
        remaining = remaining.dropFirst(2)
        continue
      }
      if remaining.hasPrefix("Yb") {
        isSendable = true
        remaining = remaining.dropFirst(2)
        continue
      }
      if remaining.hasPrefix("YK") {
        // Typed throws - the error type was parsed before this
        isThrowing = true
        if let lastType = parsedTypes.popLast(), lastType != "Void" {
          errorType = lastType
        }
        remaining = remaining.dropFirst(2)
        continue
      }
      if remaining.hasPrefix("K") && !remaining.hasPrefix("KZ") {
        // Simple throws (not part of another marker)
        isThrowing = true
        remaining = remaining.dropFirst()
        continue
      }

      // Check for function kind terminator
      if remaining.count == 1,
        let c = remaining.first,
        SwiftDemanglerTables.isFunctionKindMarker(c)
      {
        break
      }

      // Check for empty-list marker (void/no params)
      if remaining.hasPrefix("y") {
        parsedTypes.append("Void")
        remaining = remaining.dropFirst()
        continue
      }

      // Try to parse a type
      if let (typeName, rest) = parseGenericTypeArg(remaining, depth: 0) {
        parsedTypes.append(typeName)
        remaining = rest
        continue
      }

      if let (typeName, rest) = SwiftDemanglerParsers.lengthPrefixed(remaining) {
        parsedTypes.append(typeName)
        remaining = rest
        // Skip type suffix
        while let c = remaining.first, "CVO".contains(c) {
          remaining = remaining.dropFirst()
        }
        continue
      }

      // Can't parse more, stop
      break
    }

    // Interpret parsed types:
    // In Swift mangling, result type comes first, then params
    let returnType = parsedTypes.first ?? "Void"
    let params = parsedTypes.count >= 2
      ? Array(parsedTypes[1...]).filter { $0 != "Void" }
      : []

    return FunctionSignatureParseResult(
      params: params,
      returnType: returnType,
      isAsync: isAsync,
      isThrowing: isThrowing,
      isSendable: isSendable,
      errorType: errorType
    )
  }

  // MARK: - Effect Marker Types

  /// Types of effect markers in mangled names.
  enum EffectMarker {
    case async
    case sendable
    case throwing
    case voidMarker
  }

  /// Parse a single effect marker.
  ///
  /// Pure function for extracting effect markers from input.
  private static func parseEffectMarker(_ input: Substring) -> (EffectMarker, Substring)? {
    if input.hasPrefix("Ya") {
      return (.async, input.dropFirst(2))
    }
    if input.hasPrefix("Yb") {
      return (.sendable, input.dropFirst(2))
    }
    if input.hasPrefix("K") && !input.hasPrefix("KZ") {
      return (.throwing, input.dropFirst())
    }
    if input.hasPrefix("y") {
      return (.voidMarker, input.dropFirst())
    }
    return nil
  }

  // MARK: - Closure Type Detection

  /// Check if a mangled string represents a closure/function type.
  ///
  /// Pure predicate function.
  ///
  /// - Parameter mangled: The mangled string to check.
  /// - Returns: True if it appears to be a function type.
  static func detectClosureType(_ mangled: String) -> Bool {
    guard !mangled.isEmpty else { return false }

    // Check for function type suffixes
    if mangled.hasSuffix("XB")
      || mangled.hasSuffix("XC")
      || mangled.hasSuffix("XE")
      || mangled.hasSuffix("Xf")
    {
      return true
    }

    // Check for escaping function suffix 'c'
    // Must not be confused with other uses of 'c'
    if mangled.hasSuffix("c") && mangled.count > 1 {
      let beforeC = mangled.dropLast()
      // Function types have param/return markers
      return beforeC.contains("y")
        || beforeC.contains("S")
        || beforeC.hasSuffix("Ya")
        || beforeC.hasSuffix("Yb")
        || beforeC.hasSuffix("K")
    }

    return false
  }

  // MARK: - Function Symbol Detection

  /// Check if a mangled symbol is a Swift function symbol.
  ///
  /// Pure predicate function.
  ///
  /// - Parameter symbol: The symbol to check.
  /// - Returns: True if the symbol appears to be a Swift function.
  static func detectFunctionSymbol(_ symbol: String) -> Bool {
    guard symbol.hasPrefix("_$s") || symbol.hasPrefix("$s") else {
      return false
    }
    guard let lastChar = symbol.last else {
      return false
    }
    return SwiftDemanglerTables.isFunctionKindMarker(lastChar)
  }

  // MARK: - Swift Mangled Name Detection

  /// Check if a string looks like a Swift mangled name.
  ///
  /// Pure heuristic function to avoid unnecessary processing.
  ///
  /// - Parameter s: The string to check.
  /// - Returns: True if the string appears to be a Swift mangled name.
  static func detectSwiftMangled(_ s: String) -> Bool {
    // Swift 5+ symbols start with $s or _$s
    if s.hasPrefix("$s") || s.hasPrefix("_$s") {
      return true
    }
    // Legacy Swift symbols start with _T or _$S
    if s.hasPrefix("_T") || s.hasPrefix("_$S") {
      return true
    }
    // ObjC-style Swift class names
    if s.hasPrefix("_Tt") {
      return true
    }
    return false
  }
}
