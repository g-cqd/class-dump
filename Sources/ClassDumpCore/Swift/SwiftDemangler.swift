// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation
import Synchronization

/// Swift name demangler for converting mangled Swift type names to human-readable form.
///
/// This provides basic demangling for common Swift types. For full demangling,
/// the system's swift-demangle or libswiftDemangle would be needed.
///
/// ## Architecture
///
/// The demangler is organized around functional programming principles:
/// - **Pure Parsers**: All parsing logic is implemented as pure functions
/// - **Composable**: Small parsers combine into complex ones via higher-order functions
/// - **Isolated State**: Cache and configuration are isolated from parsing logic
///
/// ## Entry Points
///
/// - ``demangle(_:)`` - Primary entry point for demangling type references
/// - ``demangleClassName(_:)`` - For ObjC-style Swift class names (`_TtC...`)
/// - ``demangleNestedClassName(_:)`` - For nested class paths
/// - ``extractTypeName(_:)`` - For extracting readable type names from various formats
/// - ``demangleComplexType(_:)`` - For complex generic type expressions
/// - ``demangleFunctionSignature(_:)`` - For Swift function symbols (`_$s...F`)
/// - ``demangleClosureType(_:)`` - For closure/function type expressions
///
/// ## System Demangling
///
/// For complex symbols that the built-in demangler cannot handle, you can enable
/// system demangling which shells out to `swift-demangle`:
///
/// ```swift
/// // Enable at startup (before processing)
/// await SwiftDemangler.enableSystemDemangling()
///
/// // Now demangle() will use system demangler for complex cases
/// let result = SwiftDemangler.demangle("_$s...")
/// ```
public enum SwiftDemangler: Sendable {

  // MARK: - Configuration State

  /// Whether to use system demangler as fallback for complex symbols.
  private static let useSystemDemangler = Mutex<Bool>(false)

  /// Whether to use dynamic demangler (dlopen) as fallback.
  private static let useDynamicDemangler = Mutex<Bool>(false)

  /// Thread-safe cache for memoizing demangled results.
  private static let demangleCache = MutexCache<String, String>()

  // MARK: - Configuration API

  /// Enable system demangling via `swift-demangle` for complex symbols.
  ///
  /// When enabled, symbols that the built-in demangler cannot handle will be
  /// demangled using the system's `swift-demangle` tool.
  ///
  /// - Returns: `true` if system demangling is available.
  @discardableResult
  public static func enableSystemDemangling() async -> Bool {
    let available = await SystemDemangler.shared.checkAvailability()
    useSystemDemangler.withLock { $0 = available }
    return available
  }

  /// Disable system demangling (use built-in only).
  public static func disableSystemDemangling() {
    useSystemDemangler.withLock { $0 = false }
  }

  /// Check if system demangling is enabled.
  public static var isSystemDemanglingEnabled: Bool {
    useSystemDemangler.withLock { $0 }
  }

  /// Enable dynamic library demangling via dlopen/dlsym.
  ///
  /// When enabled, symbols that the built-in demangler cannot handle will be
  /// demangled using the system's libswiftCore.dylib or libswiftDemangle.dylib.
  ///
  /// - Returns: `true` if dynamic demangling is available.
  @discardableResult
  public static func enableDynamicDemangling() -> Bool {
    let available = DynamicSwiftDemangler.shared.isAvailable
    useDynamicDemangler.withLock { $0 = available }
    return available
  }

  /// Disable dynamic library demangling.
  public static func disableDynamicDemangling() {
    useDynamicDemangler.withLock { $0 = false }
  }

  /// Check if dynamic demangling is enabled.
  public static var isDynamicDemanglingEnabled: Bool {
    useDynamicDemangler.withLock { $0 } && DynamicSwiftDemangler.shared.isAvailable
  }

  // MARK: - Cache Management

  /// Clear the demangling cache.
  ///
  /// Useful for testing or when processing multiple unrelated binaries.
  public static func clearCache() {
    demangleCache.clear()
  }

  /// Get cache statistics for debugging/profiling.
  public static var cacheStats: (count: Int, description: String) {
    let count = demangleCache.count
    return (count, "SwiftDemangler cache: \(count) entries")
  }

  // MARK: - Primary Entry Points

  /// Demangle a Swift type reference string.
  ///
  /// This is the main entry point for demangling. It handles:
  /// - Common pattern shortcuts (Sb, Si, SS, etc.)
  /// - Standard library type shortcuts (single characters)
  /// - Builtin types
  /// - ObjC imported types (So prefix)
  /// - Qualified type names (length-prefixed)
  /// - Optional suffixes (Sg)
  /// - Array/Dictionary shorthands
  ///
  /// The function composes pure parsing functions with caching and
  /// fallback demangling for a complete solution.
  ///
  /// - Parameter mangled: The mangled type name string.
  /// - Returns: A demangled type name, or the original if demangling fails.
  public static func demangle(_ mangled: String) -> String {
    guard !mangled.isEmpty else { return "" }

    // Handle symbolic references (binary format) - return as-is for resolver
    if let first = mangled.first, let firstAscii = first.asciiValue, firstAscii <= 0x17 {
      return mangled
    }

    // Fast path: common patterns lookup (pure function)
    if let result = SwiftDemanglerTables.commonPattern(for: mangled) {
      return result
    }

    // Fast path: single-character shortcuts (pure function)
    if mangled.count == 1, let char = mangled.first,
      let shortcut = SwiftDemanglerTables.typeShortcut(for: char)
    {
      return shortcut
    }

    // Fast path: builtin types (pure function)
    if let builtin = SwiftDemanglerTables.builtinType(for: mangled) {
      return builtin
    }

    // Check memoization cache
    if let cached = demangleCache.get(mangled) {
      return cached
    }

    // Detailed demangling (composition of pure parsers)
    var result = demangleDetailed(mangled)

    // Fallback to system demanglers for complex cases
    if result == mangled && detectSwiftMangled(mangled) {
      result = applyFallbackDemanglers(mangled) ?? result
    }

    demangleCache.set(mangled, value: result)
    return result
  }

  /// Demangle an ObjC-style Swift class name.
  ///
  /// Swift classes exposed to ObjC have names like:
  /// - `_TtC10ModuleName9ClassName` - Simple class
  /// - `_TtCC10ModuleName5Outer5Inner` - Nested class
  /// - `_TtGC10ModuleName7GenericSS_` - Generic class
  ///
  /// - Parameter mangledClassName: The mangled class name.
  /// - Returns: A tuple of (moduleName, className) or nil if not a Swift class.
  public static func demangleClassName(_ mangledClassName: String) -> (module: String, name: String)? {
    parseObjCSwiftClassName(mangledClassName)
  }

  /// Demangle an ObjC-style Swift protocol name.
  ///
  /// Swift protocols exposed to ObjC have names like:
  /// - `_TtP10Foundation8Hashable_` - Simple protocol
  ///
  /// - Parameter mangledProtocolName: The mangled protocol name.
  /// - Returns: A tuple of (moduleName, protocolName) or nil.
  public static func demangleProtocolName(_ mangledProtocolName: String) -> (module: String, name: String)? {
    guard mangledProtocolName.hasPrefix("_TtP"),
      mangledProtocolName.hasSuffix("_")
    else {
      return nil
    }

    var input = mangledProtocolName.dropFirst(4).dropLast()

    guard let (moduleName, rest1) = SwiftDemanglerParsers.lengthPrefixed(input) else {
      return nil
    }
    input = rest1

    guard let (protocolName, _) = SwiftDemanglerParsers.lengthPrefixed(input) else {
      return nil
    }

    return (moduleName, protocolName)
  }

  /// Demangle a Swift function symbol into a structured signature.
  ///
  /// - Parameter mangledSymbol: The mangled function symbol.
  /// - Returns: A parsed `FunctionSignature`, or nil if not a function symbol.
  public static func demangleFunctionSignature(_ mangledSymbol: String) -> FunctionSignature? {
    var input: Substring
    if mangledSymbol.hasPrefix("_$s") {
      input = mangledSymbol.dropFirst(3)
    } else if mangledSymbol.hasPrefix("$s") {
      input = mangledSymbol.dropFirst(2)
    } else {
      return nil
    }

    guard let lastChar = mangledSymbol.last,
      SwiftDemanglerTables.isFunctionKindMarker(lastChar)
    else {
      return nil
    }

    // Parse module name
    var words: [String] = []
    guard let (moduleName, rest1) = SwiftDemanglerParsers.lengthPrefixed(input) else {
      return nil
    }
    addWords(from: moduleName, to: &words)
    input = rest1

    // Parse context (class/struct name) if present
    var contextName = ""
    var funcName = ""

    if let first = input.first, "CVO".contains(first) {
      input = input.dropFirst()
      if let (ctxName, rest2) = parseIdentifierWithSubstitutions(input, words: &words) {
        contextName = ctxName
        input = rest2
        while let c = input.first, "CVO".contains(c) {
          input = input.dropFirst()
        }
      }
    }

    // Parse function name
    if let (name, rest3) = parseIdentifierWithSubstitutions(input, words: &words) {
      funcName = name
      input = rest3
    }

    guard !funcName.isEmpty else { return nil }

    // Parse function signature
    let signatureResult = parseFunctionSignatureTypes(input)

    return FunctionSignature(
      moduleName: moduleName,
      contextName: contextName,
      functionName: funcName,
      parameterTypes: signatureResult.params,
      returnType: signatureResult.returnType,
      isAsync: signatureResult.isAsync,
      isThrowing: signatureResult.isThrowing,
      isSendable: signatureResult.isSendable,
      errorType: signatureResult.errorType
    )
  }

  /// Check if a mangled symbol is a Swift function symbol.
  public static func isFunctionSymbol(_ symbol: String) -> Bool {
    detectFunctionSymbol(symbol)
  }

  /// Demangle a Swift closure/function type expression.
  ///
  /// - Parameter mangled: The mangled closure type string.
  /// - Returns: A parsed `ClosureType`, or nil if not a closure type.
  public static func demangleClosureType(_ mangled: String) -> ClosureType? {
    guard !mangled.isEmpty else { return nil }

    guard let (convention, isEscaping, rest) = parseClosureConvention(Substring(mangled)) else {
      return nil
    }

    let parsed = parseClosureTypeComponents(rest)

    return ClosureType(
      parameterTypes: parsed.params,
      returnType: parsed.returnType,
      isEscaping: isEscaping,
      isSendable: parsed.isSendable,
      isAsync: parsed.isAsync,
      isThrowing: parsed.isThrowing,
      convention: convention
    )
  }

  /// Check if a mangled string represents a closure/function type.
  public static func isClosureType(_ mangled: String) -> Bool {
    detectClosureType(mangled)
  }

  /// Demangle a Swift name for display.
  ///
  /// This is the primary method for formatting Swift names in output.
  ///
  /// - Parameter mangledName: The potentially mangled name.
  /// - Returns: A human-readable name, or the original if not mangled.
  public static func demangleSwiftName(_ mangledName: String) -> String {
    guard mangledName.hasPrefix("_Tt")
      || mangledName.hasPrefix("$s")
      || mangledName.hasPrefix("_$s")
    else {
      return mangledName
    }

    // Swift 5+ symbols
    if mangledName.hasPrefix("_$s") || mangledName.hasPrefix("$s") {
      let result = extractTypeName(mangledName)
      if result != mangledName && !result.isEmpty {
        return result
      }
      return mangledName
    }

    // Protocol names
    if mangledName.hasPrefix("_TtP") && mangledName.hasSuffix("_") {
      if let (module, name) = demangleProtocolName(mangledName) {
        return module == "Swift" ? name : "\(module).\(name)"
      }
      return mangledName
    }

    // Swift stdlib types with _Tt prefix
    if mangledName.hasPrefix("_TtS") && !mangledName.hasPrefix("_TtSo") {
      let inner = String(mangledName.dropFirst(3))
      let demangled = demangle(inner)
      if demangled != inner {
        return demangled
      }
    }

    // Swift stdlib internal types like _TtCs12_SwiftObject
    if mangledName.hasPrefix("_TtCs") {
      let input = mangledName.dropFirst(5)
      if let (typeName, _) = SwiftDemanglerParsers.lengthPrefixed(input) {
        return typeName
      }
      return mangledName
    }

    // Generic types
    if mangledName.hasPrefix("_TtG") {
      if let result = demangleGenericType(mangledName) {
        return result
      }
      if let (module, name) = demangleClassName(mangledName) {
        return module == "Swift" ? name : "\(module).\(name)"
      }
      return mangledName
    }

    // Nested classes
    if mangledName.hasPrefix("_TtCC") || mangledName.hasPrefix("_TtCCC") {
      let names = demangleNestedClassName(mangledName)
      if !names.isEmpty {
        if let (module, _) = demangleClassName(mangledName) {
          let joinedNames = names.joined(separator: ".")
          return module == "Swift" ? joinedNames : "\(module).\(joinedNames)"
        }
        return names.joined(separator: ".")
      }
      return mangledName
    }

    // Simple class names
    if mangledName.hasPrefix("_TtC") {
      if let (module, name) = demangleClassName(mangledName) {
        return module == "Swift" ? name : "\(module).\(name)"
      }
      if let privateName = extractPrivateTypeName(mangledName) {
        return privateName
      }
      return mangledName
    }

    // Enum types
    if mangledName.hasPrefix("_TtO") {
      if let result = parseObjCSwiftTypeName(mangledName, prefix: "_TtO") {
        return result
      }
      if let privateName = extractPrivateTypeName(mangledName) {
        return privateName
      }
      return mangledName
    }

    // Value types/structs
    if mangledName.hasPrefix("_TtV") {
      if let result = parseObjCSwiftTypeName(mangledName, prefix: "_TtV") {
        return result
      }
      if let privateName = extractPrivateTypeName(mangledName) {
        return privateName
      }
      return mangledName
    }

    // Complex nested types
    if mangledName.hasPrefix("_TtC")
      || mangledName.hasPrefix("_TtO")
      || mangledName.hasPrefix("_TtV")
    {
      if let result = parseComplexNestedType(mangledName) {
        return result
      }
    }

    return extractTypeName(mangledName)
  }

  /// Demangle a nested class name and return all class names in the hierarchy.
  public static func demangleNestedClassName(_ mangledClassName: String) -> [String] {
    parseNestedClassNames(mangledClassName)
  }

  /// Extract a readable type name from various mangled formats.
  public static func extractTypeName(_ mangled: String) -> String {
    guard !mangled.isEmpty else { return "" }

    // Swift 5+ mangled symbols
    if mangled.hasPrefix("_$s") {
      return demangleSwift5Symbol(String(mangled.dropFirst(3)))
    }
    if mangled.hasPrefix("$s") {
      return demangleSwift5Symbol(String(mangled.dropFirst(2)))
    }

    // ObjC-style Swift class names
    if mangled.hasPrefix("_Tt") {
      if let (module, name) = demangleClassName(mangled) {
        return module == "Swift" ? name : "\(module).\(name)"
      }
    }

    // Qualified types (start with digit)
    if let first = mangled.first, first.isNumber {
      return parseQualifiedType(Substring(mangled))
    }

    return demangle(mangled)
  }

  /// Demangle a complex type expression that may contain generics.
  public static func demangleComplexType(_ mangled: String) -> String {
    demangle(mangled)
  }

  /// Parse a generic signature from mangled format.
  public static func demangleGenericSignature(_ mangled: String) -> GenericSignature? {
    parseGenericSignature(mangled)
  }

  /// Demangle a symbol that may contain generic constraints.
  public static func demangleWithConstraints(_ mangled: String) -> (name: String, whereClause: String)? {
    demangleNameWithConstraints(mangled)
  }

  // MARK: - Private Implementation

  /// Detailed demangling for types that don't match simple patterns.
  ///
  /// This composes various pure parsing functions to handle complex cases.
  private static func demangleDetailed(_ mangled: String) -> String {
    // Task type with generic parameters
    if mangled.hasPrefix("ScTy") && mangled.hasSuffix("G") {
      let inner = String(mangled.dropFirst(4).dropLast(1))
      if let (success, failure) = parseTaskGenericArgs(inner) {
        return "Task<\(success), \(failure)>"
      }
    }

    // AsyncStream with generic parameter
    if mangled.hasPrefix("ScSy") && mangled.hasSuffix("G") {
      let inner = String(mangled.dropFirst(4).dropLast(1))
      if let (element, _) = parseGenericTypeArg(Substring(inner), depth: 0) {
        return "AsyncStream<\(element)>"
      }
    }

    // AsyncThrowingStream with generic parameter
    if mangled.hasPrefix("ScFy") && mangled.hasSuffix("G") {
      let inner = String(mangled.dropFirst(4).dropLast(1))
      if let (element, _) = parseGenericTypeArg(Substring(inner), depth: 0) {
        return "AsyncThrowingStream<\(element)>"
      }
    }

    // CheckedContinuation with generic parameters
    if mangled.hasPrefix("ScCy") && mangled.hasSuffix("G") {
      if let (result, _) = parseTaskGenericArgsFromInput(Substring(mangled.dropFirst(4))) {
        return result.replacingOccurrences(of: "Task", with: "CheckedContinuation")
      }
    }

    // UnsafeContinuation with generic parameters
    if mangled.hasPrefix("ScUy") && mangled.hasSuffix("G") {
      if let (result, _) = parseTaskGenericArgsFromInput(Substring(mangled.dropFirst(4))) {
        return result.replacingOccurrences(of: "Task", with: "UnsafeContinuation")
      }
    }

    // Optional suffix
    if mangled.hasSuffix("Sg") {
      let base = String(mangled.dropLast(2))
      let inner = demangle(base)
      return "\(inner)?"
    }

    // Array shorthand
    if mangled.hasPrefix("Say") {
      if let (arrayType, _) = parseNestedArrayType(Substring(mangled), depth: 0) {
        return arrayType
      }
    }

    // Dictionary shorthand
    if mangled.hasPrefix("SDy") {
      if let (dictType, _) = parseNestedDictionaryType(Substring(mangled), depth: 0) {
        return dictType
      }
    }

    // Set shorthand
    if mangled.hasPrefix("Shy") {
      if let (setType, _) = parseNestedSetType(Substring(mangled), depth: 0) {
        return setType
      }
    }

    // ObjC imported type
    if mangled.hasPrefix("So") {
      return demangleObjCImportedType(String(mangled.dropFirst(2)))
    }

    // Swift module type
    if mangled.hasPrefix("s") || mangled.hasPrefix("S") {
      let rest = String(mangled.dropFirst())
      if let first = rest.first, first.isNumber {
        let typeName = parseQualifiedType(Substring(rest))
        if !typeName.isEmpty {
          return "Swift.\(typeName)"
        }
      }
    }

    // Qualified type
    if let first = mangled.first, first.isNumber {
      return parseQualifiedType(Substring(mangled))
    }

    return mangled
  }

  /// Apply fallback demanglers for complex symbols.
  ///
  /// Pure function that checks availability and applies demanglers in order.
  private static func applyFallbackDemanglers(_ mangled: String) -> String? {
    // Try dynamic demangling first (in-process, faster)
    if isDynamicDemanglingEnabled,
      let dynamicResult = DynamicSwiftDemangler.shared.demangle(mangled)
    {
      return dynamicResult
    }

    // Fall back to system demangling (out-of-process)
    if isSystemDemanglingEnabled {
      return SystemDemangler.shared.demangleSync(mangled)
    }

    return nil
  }


  // MARK: - Type Aliases for API Compatibility

  /// Calling convention for closure types.
  public typealias ClosureConvention = ClassDumpCore.ClosureConvention

  /// A parsed Swift closure/function type.
  public typealias ClosureType = ClassDumpCore.ClosureType

  /// A parsed Swift function signature.
  public typealias FunctionSignature = ClassDumpCore.FunctionSignature

  /// Kind of generic constraint parsed from mangled names.
  public typealias ConstraintKind = ClassDumpCore.ConstraintKind

  /// A parsed generic constraint from a mangled name.
  public typealias DemangledConstraint = ClassDumpCore.DemangledConstraint

  /// A parsed generic signature with constraints.
  public typealias GenericSignature = ClassDumpCore.GenericSignature
}

// MARK: - String Extension

extension String {
  /// Attempt to demangle this string as a Swift type name.
  public var swiftDemangled: String {
    SwiftDemangler.demangle(self)
  }
}
