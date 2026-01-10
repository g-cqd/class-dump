// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

/// Generic type parsing extensions for SwiftDemangler.
///
/// This extension provides pure parsing functions for generic Swift types
/// including Array, Dictionary, Set, and custom generic types.
///
/// All functions in this extension are pure - they take input and return
/// output without side effects, making them easy to test and compose.
extension SwiftDemangler {

  // MARK: - Configuration

  /// Maximum recursion depth for nested generic parsing.
  ///
  /// Prevents stack overflow on deeply nested or malicious input.
  static let maxGenericNestingDepth = 10

  // MARK: - Generic Type Argument Parsing

  /// Parse a single generic type argument from a mangled string.
  ///
  /// This is the core recursive parser for type arguments. It handles:
  /// - Nested container types (Array, Dictionary, Set)
  /// - Type shortcuts (SS, Si, etc.)
  /// - ObjC imported types (So prefix)
  /// - Module-qualified types
  /// - Optional suffixes (Sg)
  ///
  /// - Parameters:
  ///   - input: The mangled type string to parse.
  ///   - depth: Current recursion depth (for safety limits).
  /// - Returns: A tuple of (demangled type name, remaining input) or nil if parsing fails.
  static func parseGenericTypeArg(_ input: Substring, depth: Int = 0) -> (String, Substring)? {
    guard !input.isEmpty, depth < maxGenericNestingDepth else { return nil }

    // Try parsers in order of specificity (most specific first)
    return parseNestedContainerType(input, depth: depth)
      ?? parseObjCImportedTypeArg(input, depth: depth)
      ?? parseConcurrencyTypeArg(input, depth: depth)
      ?? parseTwoCharPattern(input)
      ?? parseSingleCharShortcut(input)
      ?? parseSwiftModuleType(input)
      ?? parseModuleQualifiedType(input, depth: depth)
  }

  // MARK: - Container Type Parsers

  /// Parse any nested container type (Array, Dictionary, Set).
  ///
  /// Pure function that dispatches to specific container parsers.
  private static func parseNestedContainerType(_ input: Substring, depth: Int) -> (String, Substring)? {
    parseNestedArrayType(input, depth: depth)
      ?? parseNestedDictionaryType(input, depth: depth)
      ?? parseNestedSetType(input, depth: depth)
  }

  /// Parse a nested Array type (`Say...G`) recursively.
  ///
  /// Pure parser for Swift Array shorthand syntax.
  ///
  /// - Parameters:
  ///   - input: Input starting with "Say".
  ///   - depth: Current recursion depth.
  /// - Returns: Tuple of (formatted array type, remaining input) or nil.
  static func parseNestedArrayType(_ input: Substring, depth: Int) -> (String, Substring)? {
    guard input.hasPrefix("Say") else { return nil }

    var inner = input.dropFirst(3)  // Remove "Say"

    // Parse element type recursively
    guard let (element, rest) = parseGenericTypeArg(inner, depth: depth + 1) else {
      return nil
    }
    inner = rest

    // Look for closing G
    guard inner.hasPrefix("G") else { return nil }
    inner = inner.dropFirst()

    // Build result and check for optional suffix
    return applyOptionalSuffix("[\(element)]", to: inner)
  }

  /// Parse a nested Dictionary type (`SDy...G`) recursively.
  ///
  /// Pure parser for Swift Dictionary shorthand syntax.
  ///
  /// - Parameters:
  ///   - input: Input starting with "SDy".
  ///   - depth: Current recursion depth.
  /// - Returns: Tuple of (formatted dictionary type, remaining input) or nil.
  static func parseNestedDictionaryType(_ input: Substring, depth: Int) -> (String, Substring)? {
    guard input.hasPrefix("SDy") else { return nil }

    var inner = input.dropFirst(3)  // Remove "SDy"
    var typeArgs: [String] = []

    // Parse key and value types
    while typeArgs.count < 2 && !inner.isEmpty {
      guard let (arg, rest) = parseGenericTypeArg(inner, depth: depth + 1) else {
        break
      }
      typeArgs.append(arg)
      inner = rest
    }

    // Need exactly 2 type arguments and closing G
    guard typeArgs.count == 2, inner.hasPrefix("G") else { return nil }
    inner = inner.dropFirst()

    // Build result and check for optional suffix
    return applyOptionalSuffix("[\(typeArgs[0]): \(typeArgs[1])]", to: inner)
  }

  /// Parse a nested Set type (`Shy...G`) recursively.
  ///
  /// Pure parser for Swift Set shorthand syntax.
  ///
  /// - Parameters:
  ///   - input: Input starting with "Shy".
  ///   - depth: Current recursion depth.
  /// - Returns: Tuple of (formatted set type, remaining input) or nil.
  static func parseNestedSetType(_ input: Substring, depth: Int) -> (String, Substring)? {
    guard input.hasPrefix("Shy") else { return nil }

    var inner = input.dropFirst(3)  // Remove "Shy"

    // Parse element type recursively
    guard let (element, rest) = parseGenericTypeArg(inner, depth: depth + 1) else {
      return nil
    }
    inner = rest

    // Look for closing G
    guard inner.hasPrefix("G") else { return nil }
    inner = inner.dropFirst()

    // Build result and check for optional suffix
    return applyOptionalSuffix("Set<\(element)>", to: inner)
  }

  // MARK: - ObjC Imported Type Parsing

  /// Parse an ObjC imported type argument (So prefix).
  ///
  /// Pure parser for Objective-C bridged types.
  private static func parseObjCImportedTypeArg(_ input: Substring, depth: Int) -> (String, Substring)? {
    guard input.hasPrefix("So") else { return nil }

    var rest = input.dropFirst(2)
    guard let (typeName, remaining) = SwiftDemanglerParsers.lengthPrefixed(rest) else {
      return nil
    }

    let mapped = SwiftDemanglerTables.swiftType(forObjC: typeName) ?? typeName
    rest = remaining

    // Skip type kind suffixes
    rest = skipTypeSuffixes(rest)

    // Handle protocol existential suffix
    if rest.hasPrefix("_p") {
      rest = rest.dropFirst(2)
    }

    // Check for optional suffix
    return applyOptionalSuffix(mapped, to: rest)
  }

  // MARK: - Concurrency Type Parsing

  /// Parse concurrency type arguments (Task, AsyncStream, etc.).
  ///
  /// Pure parser for Swift concurrency types with generic parameters.
  private static func parseConcurrencyTypeArg(_ input: Substring, depth: Int) -> (String, Substring)? {
    parseTaskType(input, depth: depth)
      ?? parseAsyncStreamType(input, depth: depth)
  }

  /// Parse a Task type with generic parameters.
  ///
  /// Format: `ScTy<success>y<failure>G`
  private static func parseTaskType(_ input: Substring, depth: Int) -> (String, Substring)? {
    guard input.hasPrefix("ScTy") else { return nil }

    let remaining = input.dropFirst(4)  // Remove "ScTy"
    return parseTaskGenericArgsFromInput(remaining, depth: depth)
  }

  /// Parse an AsyncStream type with generic parameter.
  ///
  /// Format: `ScSy<element>G`
  private static func parseAsyncStreamType(_ input: Substring, depth: Int) -> (String, Substring)? {
    guard input.hasPrefix("ScSy") else { return nil }

    var remaining = input.dropFirst(4)  // Remove "ScSy"

    guard let (element, rest) = parseGenericTypeArg(remaining, depth: depth + 1) else {
      return nil
    }
    remaining = rest

    if remaining.hasPrefix("G") {
      remaining = remaining.dropFirst()
    }

    return ("AsyncStream<\(element)>", remaining)
  }

  /// Parse Task generic arguments from input.
  ///
  /// Task has two type parameters: Success and Failure.
  ///
  /// - Parameters:
  ///   - input: Input starting after "ScTy".
  ///   - depth: Current recursion depth.
  /// - Returns: Tuple of (formatted Task type, remaining input) or nil.
  static func parseTaskGenericArgsFromInput(
    _ input: Substring,
    depth: Int = 0
  ) -> (String, Substring)? {
    var inner = input
    var typeArgs: [String] = []

    // Parse success type
    guard let (successArg, rest1) = parseGenericTypeArg(inner, depth: depth + 1) else {
      return nil
    }
    typeArgs.append(successArg)
    inner = rest1

    // Check for 'y' separator
    if inner.hasPrefix("y") {
      inner = inner.dropFirst()
    }

    // Parse failure type
    guard let (failureArg, rest2) = parseGenericTypeArg(inner, depth: depth + 1) else {
      return nil
    }
    typeArgs.append(failureArg)
    inner = rest2

    // Look for closing G
    if inner.hasPrefix("G") {
      inner = inner.dropFirst()
    }

    guard typeArgs.count == 2 else { return nil }

    return ("Task<\(typeArgs[0]), \(typeArgs[1])>", inner)
  }

  // MARK: - Pattern Lookup Parsers

  /// Parse a two-character common pattern (SS, Si, Sb, etc.).
  ///
  /// Pure lookup parser for common type shortcuts.
  private static func parseTwoCharPattern(_ input: Substring) -> (String, Substring)? {
    guard input.count >= 2 else { return nil }

    let twoChars = String(input.prefix(2))
    guard let result = SwiftDemanglerTables.commonPattern(for: twoChars) else {
      return nil
    }

    let remaining = input.dropFirst(2)
    return applyOptionalSuffix(result, to: remaining)
  }

  /// Parse a single-character type shortcut.
  ///
  /// Pure lookup parser for single-character shortcuts.
  /// Note: Does NOT match 'S' alone (handled by two-char patterns).
  private static func parseSingleCharShortcut(_ input: Substring) -> (String, Substring)? {
    guard let first = input.first, first != "S" else { return nil }
    guard let shortcut = SwiftDemanglerTables.typeShortcut(for: first) else { return nil }

    let remaining = input.dropFirst()
    return applyOptionalSuffix(shortcut, to: remaining)
  }

  // MARK: - Module-Qualified Type Parsing

  /// Parse a Swift module type (s + length-prefixed name).
  ///
  /// Pure parser for types qualified with Swift module prefix.
  private static func parseSwiftModuleType(_ input: Substring) -> (String, Substring)? {
    guard input.hasPrefix("s") else { return nil }

    let afterS = input.dropFirst()
    guard let firstAfterS = afterS.first, firstAfterS.isNumber else { return nil }

    guard let (name, rest) = SwiftDemanglerParsers.lengthPrefixed(afterS) else {
      return nil
    }

    var remaining = skipTypeSuffixes(rest)

    // Handle protocol existential suffix
    if remaining.hasPrefix("_p") {
      remaining = remaining.dropFirst(2)
    }

    return applyOptionalSuffix(name, to: remaining)
  }

  /// Parse a module-qualified type (e.g., 13IDEFoundation19IDETestingSpecifier).
  ///
  /// Pure parser for fully qualified type names.
  ///
  /// - Parameters:
  ///   - input: Input starting with a digit.
  ///   - depth: Current recursion depth.
  /// - Returns: Tuple of (type name, remaining input) or nil.
  static func parseModuleQualifiedType(_ input: Substring, depth: Int = 0) -> (String, Substring)? {
    guard let first = input.first, first.isNumber else {
      return nil
    }

    // Parse first component
    guard let (firstName, afterFirst) = SwiftDemanglerParsers.lengthPrefixed(input) else {
      return nil
    }

    // Check if there's another length-prefixed component (module.type pattern)
    if let secondFirst = afterFirst.first, secondFirst.isNumber {
      if let (secondName, afterSecond) = SwiftDemanglerParsers.lengthPrefixed(afterFirst) {
        // Check for protocol existential suffix (_p)
        if afterSecond.hasPrefix("_p") {
          let remaining = afterSecond.dropFirst(2)
          return ("any \(secondName)", remaining)
        }
        // Regular module.type
        return ("\(firstName).\(secondName)", afterSecond)
      }
    }

    // Single component - check for protocol existential suffix
    if afterFirst.hasPrefix("_p") {
      let remaining = afterFirst.dropFirst(2)
      return ("any \(firstName)", remaining)
    }

    return (firstName, afterFirst)
  }

  // MARK: - Helper Functions

  /// Skip type kind suffixes (C, V, O, P, y).
  ///
  /// Pure function to advance past type markers.
  private static func skipTypeSuffixes(_ input: Substring) -> Substring {
    var remaining = input
    while let c = remaining.first, "CVOPpy".contains(c) {
      remaining = remaining.dropFirst()
    }
    return remaining
  }

  /// Apply optional suffix (Sg) if present.
  ///
  /// Pure function that appends "?" to type name if suffix found.
  private static func applyOptionalSuffix(_ typeName: String, to input: Substring) -> (String, Substring) {
    if input.hasPrefix("Sg") {
      return ("\(typeName)?", input.dropFirst(2))
    }
    return (typeName, input)
  }

  // MARK: - Generic Type Demangling

  /// Demangle a generic type with type arguments.
  ///
  /// Format: `_TtGC<module><class><type_args>_` or `_TtGV<module><struct><type_args>_`
  ///
  /// Pure function for demangling ObjC-style generic Swift types.
  ///
  /// Examples:
  /// - `_TtGC10ModuleName7GenericSS_` → `ModuleName.Generic<String>`
  /// - `_TtGC10ModuleName7PairMapSSSi_` → `ModuleName.PairMap<String, Int>`
  static func demangleGenericType(_ mangledName: String) -> String? {
    guard mangledName.hasPrefix("_TtG"), mangledName.hasSuffix("_") else {
      return nil
    }

    var input = mangledName.dropFirst(4).dropLast()  // Remove "_TtG" and "_"

    // Skip type kind (C=class, V=struct, O=enum)
    guard let kind = input.first, "CVO".contains(kind) else {
      return nil
    }
    input = input.dropFirst()

    // Parse module name
    guard let (moduleName, rest1) = SwiftDemanglerParsers.lengthPrefixed(input) else {
      return nil
    }
    input = rest1

    // Parse type name
    guard let (typeName, rest2) = SwiftDemanglerParsers.lengthPrefixed(input) else {
      return nil
    }
    input = rest2

    // Parse type arguments
    var typeArgs: [String] = []
    while !input.isEmpty {
      guard let (arg, rest) = parseGenericTypeArg(input) else {
        break
      }
      typeArgs.append(arg)
      input = rest
    }

    // Format result
    let prefix = moduleName == "Swift" ? "" : "\(moduleName)."
    guard !typeArgs.isEmpty else {
      return "\(prefix)\(typeName)"
    }
    return "\(prefix)\(typeName)<\(typeArgs.joined(separator: ", "))>"
  }

  // MARK: - Task Generic Arguments (Legacy)

  /// Parse generic constraints for Task type.
  ///
  /// Simplified parser for Success, Failure pattern.
  static func parseTaskGenericArgs(_ input: String) -> (success: String, failure: String)? {
    // Check for Never failure type
    if input.hasSuffix("s5NeverO") || input.hasSuffix("Never") {
      let suffixLen = input.hasSuffix("s5NeverO") ? 8 : 5
      let successPart = String(input.dropLast(suffixLen))
      let success = demangle(successPart)
      return (success, "Never")
    }

    // Check for Error failure type
    if input.hasSuffix("s5ErrorP") || input.hasSuffix("s5Errorp") {
      let successPart = String(input.dropLast(8))
      let success = demangle(successPart)
      return (success, "Error")
    }

    return (demangle(input), "Error")
  }
}
