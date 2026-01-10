// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

/// ObjC-style Swift name parsing extensions for SwiftDemangler.
///
/// This extension provides pure parsing functions for Objective-C style
/// Swift class names (those with `_Tt` prefix) used for ObjC interoperability.
///
/// All functions are pure - they take input and return output without side effects.
extension SwiftDemangler {

  // MARK: - Class Name Parsing

  /// Parse an ObjC-style Swift class name.
  ///
  /// Pure function that parses mangled class names with `_Tt` prefix.
  ///
  /// Handles:
  /// - `_TtC` - Simple class
  /// - `_TtCC` - Nested class
  /// - `_TtGC` - Generic class
  ///
  /// - Parameter name: The mangled class name.
  /// - Returns: Tuple of (module name, class name) or nil.
  static func parseObjCSwiftClassName(_ name: String) -> (module: String, name: String)? {
    var input: Substring
    var isNested = false

    // Determine prefix and nesting level
    switch true {
    case name.hasPrefix("_TtGC"):
      input = name.dropFirst(5)
    case name.hasPrefix("_TtCC"):
      input = name.dropFirst(5)
      isNested = true
    case name.hasPrefix("_TtC"):
      input = name.dropFirst(4)
    case name.hasPrefix("_Tt"):
      input = name.dropFirst(3)
      guard let first = input.first, first.isNumber else { return nil }
    default:
      return nil
    }

    // Parse module name
    guard let (moduleName, rest1) = SwiftDemanglerParsers.lengthPrefixed(input) else {
      return nil
    }
    input = rest1

    // Parse class name
    guard let (className, rest2) = SwiftDemanglerParsers.lengthPrefixed(input) else {
      return nil
    }
    input = rest2

    // For nested classes, parse inner class name
    if isNested {
      if let (innerName, _) = SwiftDemanglerParsers.lengthPrefixed(input) {
        return (moduleName, "\(className).\(innerName)")
      }
    }

    return (moduleName, className)
  }

  /// Parse all nested class names from a mangled class name.
  ///
  /// Pure function that extracts all class names in a nesting hierarchy.
  ///
  /// For `_TtCC13IDEFoundation22IDEBuildNoticeProvider16BuildLogObserver`
  /// returns `["IDEBuildNoticeProvider", "BuildLogObserver"]`
  ///
  /// - Parameter name: The mangled class name.
  /// - Returns: Array of class names from outermost to innermost.
  static func parseNestedClassNames(_ name: String) -> [String] {
    var input: Substring
    var names: [String] = []

    // Determine prefix
    switch true {
    case name.hasPrefix("_TtCCC"):
      input = name.dropFirst(6)
    case name.hasPrefix("_TtCC"):
      input = name.dropFirst(5)
    case name.hasPrefix("_TtC"):
      input = name.dropFirst(4)
    case name.hasPrefix("_Tt"):
      input = name.dropFirst(3)
    default:
      return []
    }

    // Skip module name
    guard let (_, rest) = SwiftDemanglerParsers.lengthPrefixed(input) else {
      return []
    }
    input = rest

    // Parse all class names until we hit a non-digit
    while let (className, rest) = SwiftDemanglerParsers.lengthPrefixed(input) {
      names.append(className)
      input = rest
      if let first = input.first, !first.isNumber {
        break
      }
    }

    return names
  }

  // MARK: - ObjC Imported Type Demangling

  /// Demangle an ObjC imported type (after stripping "So" prefix).
  ///
  /// Pure function for demangling Objective-C bridged types.
  ///
  /// - Parameter rest: The mangled type name after "So" prefix.
  /// - Returns: The demangled type name.
  static func demangleObjCImportedType(_ rest: String) -> String {
    guard let first = rest.first, first.isNumber else {
      return rest
    }

    if let (typeName, remainder) = SwiftDemanglerParsers.lengthPrefixed(Substring(rest)) {
      // Check for known mappings
      if let mapped = SwiftDemanglerTables.swiftType(forObjC: typeName) {
        return mapped
      }
      // Skip type suffix (C=class, V=struct, etc.)
      if let suffix = remainder.first, "CVOP".contains(suffix) {
        return typeName
      }
      return typeName
    }

    return rest
  }

  // MARK: - ObjC Type Name Parsing

  /// Parse a type name with the given prefix (for enums, structs).
  ///
  /// Pure function for parsing ObjC-style type names.
  ///
  /// - Parameters:
  ///   - mangledName: The full mangled name.
  ///   - prefix: The expected prefix (e.g., "_TtO", "_TtV").
  /// - Returns: The demangled type name or nil.
  static func parseObjCSwiftTypeName(_ mangledName: String, prefix: String) -> String? {
    guard mangledName.hasPrefix(prefix) else { return nil }

    var input = mangledName.dropFirst(prefix.count)

    // Handle nested types (O, C, V prefixes)
    while let first = input.first, "OCV".contains(first) {
      input = input.dropFirst()
    }

    // Parse module name
    guard let (moduleName, rest1) = SwiftDemanglerParsers.lengthPrefixed(input) else {
      return nil
    }

    // Parse type name
    guard let (typeName, _) = SwiftDemanglerParsers.lengthPrefixed(rest1) else {
      return nil
    }

    return moduleName == "Swift" ? typeName : "\(moduleName).\(typeName)"
  }

  /// Parse complex nested types with mixed class/enum/struct hierarchy.
  ///
  /// Pure function for parsing deeply nested type hierarchies.
  ///
  /// - Parameter mangledName: The mangled type name.
  /// - Returns: The demangled nested type name or nil.
  static func parseComplexNestedType(_ mangledName: String) -> String? {
    guard mangledName.hasPrefix("_Tt") else { return nil }

    var input = mangledName.dropFirst(3)  // Skip _Tt
    var typeKinds: [Character] = []

    // Collect type kind markers (C, O, V)
    while let first = input.first, "COV".contains(first) {
      typeKinds.append(first)
      input = input.dropFirst()
    }

    guard !typeKinds.isEmpty else { return nil }

    // Parse module name
    guard let (moduleName, rest) = SwiftDemanglerParsers.lengthPrefixed(input) else {
      return nil
    }
    input = rest

    // Parse each nested type name
    var names: [String] = []
    while !input.isEmpty {
      // Check for private type discriminator
      if input.hasPrefix("P33_") || input.hasPrefix("P") {
        // Skip private discriminator
        if let pRange = input.range(of: "P33_") {
          let afterP = input[pRange.upperBound...]
          if afterP.count > 32 {
            input = afterP.dropFirst(32)
            continue
          }
        }
        break
      }

      guard let (name, rest) = SwiftDemanglerParsers.lengthPrefixed(input) else {
        break
      }
      names.append(name)
      input = rest
    }

    guard !names.isEmpty else { return nil }

    let joinedNames = names.joined(separator: ".")
    return moduleName == "Swift" ? joinedNames : "\(moduleName).\(joinedNames)"
  }

  // MARK: - Private Type Extraction

  /// Extract private type name from a mangled name with P33_ discriminator.
  ///
  /// Format: `_TtC<module>P33_<32-hex-chars><name-len><name>`
  ///
  /// Pure function for extracting private type names.
  static func extractPrivateTypeName(_ mangledName: String) -> String? {
    // Look for P33_ followed by 32 hex characters
    guard let p33Range = mangledName.range(of: "P33_") else {
      return nil
    }

    // Skip the P33_ prefix and 32 hex characters
    let afterP33 = mangledName[p33Range.upperBound...]
    guard afterP33.count > 32 else { return nil }

    let afterHex = afterP33.dropFirst(32)

    // Parse the type name that follows
    if let (typeName, _) = SwiftDemanglerParsers.lengthPrefixed(afterHex) {
      // Try to extract module name from before P33_
      let beforeP33 = mangledName[..<p33Range.lowerBound]
      if let moduleName = extractModuleName(from: String(beforeP33)) {
        return "\(moduleName).(private).\(typeName)"
      }
      return "(private).\(typeName)"
    }

    return nil
  }

  /// Extract module name from a partial mangled string.
  ///
  /// Pure function for extracting module name from prefix.
  static func extractModuleName(from partial: String) -> String? {
    var input = Substring(partial)

    // Skip common prefixes
    let prefixes = [
      "_TtCC", "_TtCO", "_TtCV", "_TtOO", "_TtOC",
      "_TtVO", "_TtVC", "_TtC", "_TtO", "_TtV",
    ]

    for prefix in prefixes where input.hasPrefix(prefix) {
      input = input.dropFirst(prefix.count)
      break
    }

    // Parse module name
    if let (moduleName, _) = SwiftDemanglerParsers.lengthPrefixed(input) {
      return moduleName
    }
    return nil
  }

  // MARK: - Qualified Type Parsing

  /// Parse a qualified type name like "10Foundation4DateV".
  ///
  /// Pure function for parsing fully qualified type names.
  ///
  /// - Parameter input: The mangled type substring.
  /// - Returns: The demangled qualified type name.
  static func parseQualifiedType(_ input: Substring) -> String {
    var components: [String] = []
    var remaining = input

    while !remaining.isEmpty {
      // Skip type suffixes
      if let first = remaining.first {
        switch first {
        case "V", "C", "O":
          remaining = remaining.dropFirst()
          continue
        case "P":
          if remaining.hasPrefix("P_") {
            remaining = remaining.dropFirst(2)
            continue
          }
        default:
          break
        }
      }

      // Parse length-prefixed component
      if let first = remaining.first, first.isNumber {
        if let (component, rest) = SwiftDemanglerParsers.lengthPrefixed(remaining) {
          components.append(component)
          remaining = rest
          continue
        }
      }

      remaining = remaining.dropFirst()
    }

    return components.joined(separator: ".")
  }

  // MARK: - Swift 5+ Symbol Demangling

  /// Demangle a Swift 5+ symbol (after stripping _$s or $s prefix).
  ///
  /// Pure function for demangling modern Swift symbols.
  ///
  /// - Parameter mangled: The symbol without the leading prefix.
  /// - Returns: The demangled symbol name.
  static func demangleSwift5Symbol(_ mangled: String) -> String {
    var input = Substring(mangled)
    var words: [String] = []
    var moduleName: String = ""
    var typeName: String = ""

    // Handle known module substitutions
    if input.hasPrefix("So") {
      input = input.dropFirst(2)
      moduleName = "__C"
      if let (name, _) = SwiftDemanglerParsers.lengthPrefixed(input) {
        typeName = name
        return SwiftDemanglerTables.swiftType(forObjC: typeName) ?? "\(moduleName).\(typeName)"
      }
    } else if input.hasPrefix("s") && !(input.first?.isNumber ?? true) {
      input = input.dropFirst()
      moduleName = "Swift"
    }

    // Parse module name
    if moduleName.isEmpty {
      guard let (name, rest) = SwiftDemanglerParsers.lengthPrefixed(input) else {
        return mangled
      }
      moduleName = name
      addWords(from: name, to: &words)
      input = rest
    }

    // Parse type name (may use word substitutions)
    if let (name, rest) = parseIdentifierWithSubstitutions(input, words: &words) {
      typeName = name
      input = rest
    }

    // Skip type suffix
    if let first = input.first, "CVOP".contains(first) {
      input = input.dropFirst()
    }

    // Handle generic arguments
    var genericArgs: [String] = []
    if input.hasPrefix("y") {
      input = input.dropFirst()
      while !input.isEmpty && !input.hasPrefix("G") {
        guard let (arg, rest) = parseTypeArgument(input, words: &words, moduleName: moduleName)
        else {
          break
        }
        genericArgs.append(arg)
        input = rest
      }
      if input.hasPrefix("G") {
        input = input.dropFirst()
      }
    }

    guard !typeName.isEmpty else { return mangled }

    var result = moduleName == "Swift" ? typeName : "\(moduleName).\(typeName)"
    if !genericArgs.isEmpty {
      result += "<\(genericArgs.joined(separator: ", "))>"
    }
    return result
  }

  // MARK: - Word Substitution Helpers

  /// Parse an identifier that may contain word substitutions.
  ///
  /// Pure function for parsing identifiers with compression.
  static func parseIdentifierWithSubstitutions(
    _ input: Substring,
    words: inout [String]
  ) -> (String, Substring)? {
    var input = input

    // Check for word substitution mode (starts with 0)
    if input.hasPrefix("0") {
      input = input.dropFirst()
      var result = ""

      while !input.isEmpty {
        guard let char = input.first else { break }

        if char.isLowercase && char >= "a" && char <= "z" {
          // Non-final word reference
          let charValue = char.asciiValue ?? 0
          let aValue = Character("a").asciiValue ?? 97
          let index = Int(charValue - aValue)
          if index < words.count {
            result += words[index]
          }
          input = input.dropFirst()
        } else if char.isUppercase && char >= "A" && char <= "Z" {
          // Final word reference
          let charValue = char.asciiValue ?? 0
          let capitalAValue = Character("A").asciiValue ?? 65
          let index = Int(charValue - capitalAValue)
          if index < words.count {
            result += words[index]
          }
          input = input.dropFirst()

          // Check for trailing literal
          if let next = input.first, next.isNumber {
            if let (literal, rest) = SwiftDemanglerParsers.lengthPrefixed(input) {
              result += literal
              addWords(from: literal, to: &words)
              input = rest
            }
          }
          break  // Uppercase terminates
        } else if char.isNumber {
          // Literal string
          guard let (literal, rest) = SwiftDemanglerParsers.lengthPrefixed(input) else {
            break
          }
          result += literal
          addWords(from: literal, to: &words)
          input = rest
        } else {
          break
        }
      }

      if !result.isEmpty {
        addWords(from: result, to: &words)
        return (result, input)
      }
    }

    // Regular length-prefixed identifier
    if let (name, rest) = SwiftDemanglerParsers.lengthPrefixed(input) {
      addWords(from: name, to: &words)
      return (name, rest)
    }

    return nil
  }

  /// Parse a type argument in generic bounds.
  ///
  /// Pure function for parsing type arguments.
  static func parseTypeArgument(
    _ input: Substring,
    words: inout [String],
    moduleName: String
  ) -> (String, Substring)? {
    // Handle common shortcuts
    if let first = input.first,
      let shortcut = SwiftDemanglerTables.typeShortcut(for: first)
    {
      return (shortcut, input.dropFirst())
    }

    // Handle word substitutions
    if let (name, rest) = parseIdentifierWithSubstitutions(input, words: &words) {
      return (name, rest)
    }

    return nil
  }

  /// Add words from a name to the substitution dictionary.
  ///
  /// Pure function for word extraction (simplified approximation).
  static func addWords(from name: String, to words: inout [String]) {
    words.append(name)
  }
}
