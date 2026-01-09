// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

/// Swift name demangler for converting mangled Swift type names to human-readable form.
///
/// This provides basic demangling for common Swift types. For full demangling,
/// the system's swift-demangle or libswiftDemangle would be needed.
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
public enum SwiftDemangler: Sendable {

    // MARK: - Generic Constraint Structures

    /// Kind of generic constraint parsed from mangled names.
    public enum ConstraintKind: Sendable, Equatable {
        /// Protocol conformance constraint (T: Protocol).
        case conformance
        /// Same-type constraint (T == Type or T.Element == Type).
        case sameType
        /// Layout constraint (T: AnyObject, T: class).
        case layout
        /// Base class constraint (T: BaseClass).
        case baseClass
    }

    /// A parsed generic constraint from a mangled name.
    public struct DemangledConstraint: Sendable, Equatable {
        /// The constrained type parameter (e.g., "T", "T.Element").
        public let subject: String
        /// The kind of constraint.
        public let kind: ConstraintKind
        /// The constraint target (protocol name, type name, or layout kind).
        public let constraint: String

        /// Format as Swift where clause component.
        public var description: String {
            switch kind {
            case .conformance, .baseClass, .layout:
                return "\(subject): \(constraint)"
            case .sameType:
                return "\(subject) == \(constraint)"
            }
        }
    }

    /// A parsed generic signature with constraints.
    public struct GenericSignature: Sendable, Equatable {
        /// Generic parameter names (e.g., ["T", "U"]).
        public let parameters: [String]
        /// Constraints on the generic parameters.
        public let constraints: [DemangledConstraint]

        /// Format as Swift where clause (empty string if no constraints).
        public var whereClause: String {
            guard !constraints.isEmpty else { return "" }
            return "where " + constraints.map(\.description).joined(separator: ", ")
        }
    }

    // MARK: - Closure/Function Type Structures

    /// Calling convention for closure types.
    public enum ClosureConvention: Sendable, Equatable {
        /// Swift standard closure (thick, with context).
        case swift
        /// Objective-C block (`@convention(block)`).
        case block
        /// C function pointer (`@convention(c)`).
        case cFunction
        /// Thin function (no context, `@convention(thin)`).
        case thin
    }

    /// A parsed Swift closure/function type.
    public struct ClosureType: Sendable, Equatable {
        /// Parameter types.
        public let parameterTypes: [String]
        /// Return type.
        public let returnType: String
        /// Whether the closure is escaping.
        public let isEscaping: Bool
        /// Whether the closure is @Sendable.
        public let isSendable: Bool
        /// Whether the closure is async.
        public let isAsync: Bool
        /// Whether the closure throws.
        public let isThrowing: Bool
        /// Calling convention.
        public let convention: ClosureConvention

        /// Format as Swift-style closure declaration.
        ///
        /// Examples:
        /// - `(String) -> Void`
        /// - `@escaping (Int, Int) -> Bool`
        /// - `@Sendable () async throws -> Data`
        /// - `@convention(block) (NSString) -> Void`
        public var swiftDeclaration: String {
            var parts: [String] = []

            // Add convention if not standard swift
            switch convention {
            case .swift:
                break  // Standard closure, no annotation needed
            case .block:
                parts.append("@convention(block)")
            case .cFunction:
                parts.append("@convention(c)")
            case .thin:
                parts.append("@convention(thin)")
            }

            // Add @Sendable
            if isSendable {
                parts.append("@Sendable")
            }

            // Add @escaping if it's escaping (only meaningful in parameter position)
            if isEscaping && convention == .swift {
                parts.append("@escaping")
            }

            // Build the function type
            var funcParts: [String] = []

            // Parameter list
            let params =
                parameterTypes.isEmpty
                ? "()"
                : "(\(parameterTypes.joined(separator: ", ")))"
            funcParts.append(params)

            // Add effects
            if isAsync { funcParts.append("async") }
            if isThrowing { funcParts.append("throws") }

            // Return type
            funcParts.append("->")
            funcParts.append(returnType)

            parts.append(funcParts.joined(separator: " "))

            return parts.joined(separator: " ")
        }

        /// Format as ObjC-style block declaration.
        ///
        /// Examples:
        /// - `void (^)(void)`
        /// - `BOOL (^)(NSString *, NSInteger)`
        /// - `void (^)(void (^)(void))`
        public var objcBlockDeclaration: String {
            let returnStr = mapToObjCType(returnType)
            let params =
                parameterTypes.isEmpty
                ? "void"
                : parameterTypes.map { mapToObjCType($0) }.joined(separator: ", ")
            return "\(returnStr) (^)(\(params))"
        }

        /// Map Swift type to ObjC equivalent for block declarations.
        private func mapToObjCType(_ swiftType: String) -> String {
            switch swiftType {
            case "Void", "()": return "void"
            case "Bool": return "BOOL"
            case "Int": return "NSInteger"
            case "UInt": return "NSUInteger"
            case "Float": return "float"
            case "Double": return "double"
            case "String": return "NSString *"
            case "Data": return "NSData *"
            case "Array": return "NSArray *"
            case "Dictionary": return "NSDictionary *"
            case "Set": return "NSSet *"
            default:
                // Check if it's a pointer type or class
                if swiftType.hasSuffix("?") {
                    let base = String(swiftType.dropLast())
                    return "\(mapToObjCType(base)) _Nullable"
                }
                // Assume class type
                return "\(swiftType) *"
            }
        }
    }

    // MARK: - Function Signature Types

    /// A parsed Swift function signature.
    public struct FunctionSignature: Sendable, Equatable {
        /// Module name where the function is defined.
        public let moduleName: String
        /// Context name (class/struct/enum name for methods, empty for free functions).
        public let contextName: String
        /// Function name.
        public let functionName: String
        /// Parameter types.
        public let parameterTypes: [String]
        /// Return type.
        public let returnType: String
        /// Whether the function is async.
        public let isAsync: Bool
        /// Whether the function throws.
        public let isThrowing: Bool
        /// Whether the function is sendable.
        public let isSendable: Bool
        /// Error type for typed throws (nil for untyped throws).
        public let errorType: String?

        /// Format as Swift-style function declaration.
        public var swiftDeclaration: String {
            var parts: [String] = []

            // Build function name with parameters
            let params = parameterTypes.isEmpty ? "()" : "(\(parameterTypes.joined(separator: ", ")))"
            parts.append("func \(functionName)\(params)")

            // Add effects
            if isAsync { parts.append("async") }
            if isThrowing {
                if let errorType {
                    parts.append("throws(\(errorType))")
                } else {
                    parts.append("throws")
                }
            }

            // Add return type
            if returnType != "Void" && returnType != "()" {
                parts.append("-> \(returnType)")
            }

            return parts.joined(separator: " ")
        }

        /// Format as ObjC-style method declaration.
        public var objcDeclaration: String {
            let returnStr = returnType == "Void" || returnType == "()" ? "void" : returnType
            let params = parameterTypes.isEmpty ? "" : ":\(parameterTypes.joined(separator: " :"))"
            return "- (\(returnStr))\(functionName)\(params)"
        }
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
    /// - Parameter mangled: The mangled type name string.
    /// - Returns: A demangled type name, or the original if demangling fails.
    public static func demangle(_ mangled: String) -> String {
        guard !mangled.isEmpty else { return "" }

        // Handle symbolic references (binary format) - return as-is for resolver
        if let first = mangled.first, first.asciiValue ?? 0 <= 0x17 {
            return mangled
        }

        // Try common patterns first (fastest path)
        if let result = commonPatterns[mangled] {
            return result
        }

        // Try single-character shortcuts
        if mangled.count == 1, let char = mangled.first,
            let shortcut = typeShortcuts[char]
        {
            return shortcut
        }

        // Try builtin types
        if let builtin = builtinTypes[mangled] {
            return builtin
        }

        // Try detailed demangling
        return demangleDetailed(mangled)
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
    ///   For nested classes, className will be "OuterClass.InnerClass".
    public static func demangleClassName(_ mangledClassName: String) -> (module: String, name: String)? {
        guard let parsed = parseObjCSwiftClassName(mangledClassName) else {
            return nil
        }
        return parsed
    }

    /// Demangle an ObjC-style Swift protocol name.
    ///
    /// Swift protocols exposed to ObjC have names like:
    /// - `_TtP10Foundation8Hashable_` - Simple protocol
    /// - `_TtP15XCSourceControl30XCSourceControlXPCBaseProtocol_` - Long name
    ///
    /// - Parameter mangledProtocolName: The mangled protocol name.
    /// - Returns: A tuple of (moduleName, protocolName) or nil if not a Swift protocol.
    public static func demangleProtocolName(_ mangledProtocolName: String) -> (module: String, name: String)? {
        guard mangledProtocolName.hasPrefix("_TtP"),
            mangledProtocolName.hasSuffix("_")
        else {
            return nil
        }

        // Remove _TtP prefix and trailing underscore
        var input = mangledProtocolName.dropFirst(4).dropLast()

        // Parse module name
        guard let (moduleName, rest1) = parseLengthPrefixed(input) else {
            return nil
        }
        input = rest1

        // Parse protocol name
        guard let (protocolName, _) = parseLengthPrefixed(input) else {
            return nil
        }

        return (moduleName, protocolName)
    }

    /// Demangle a Swift function symbol into a structured signature.
    ///
    /// Swift 5+ function symbols have the format:
    /// - `_$s<module><context>...<name><signature>F` - Regular function
    /// - `_$s<module><type>C<name><signature>fC` - Method implementation
    ///
    /// The signature portion encodes:
    /// - Return type (or empty-list 'y' for Void)
    /// - Parameter types (or empty-list 'y' for no params)
    /// - Optional `Ya` for async
    /// - Optional `K` for throws or `type YK` for typed throws
    /// - Optional `Yb` for @Sendable
    ///
    /// - Parameter mangledSymbol: The mangled function symbol.
    /// - Returns: A parsed `FunctionSignature`, or nil if not a function symbol.
    ///
    /// Example:
    /// ```swift
    /// let sig = SwiftDemangler.demangleFunctionSignature("_$s4Test3fooSSyF")
    /// // sig?.functionName == "foo"
    /// // sig?.returnType == "String"
    /// // sig?.parameterTypes == []
    /// ```
    public static func demangleFunctionSignature(_ mangledSymbol: String) -> FunctionSignature? {
        // Must be a Swift 5+ symbol
        var input: Substring
        if mangledSymbol.hasPrefix("_$s") {
            input = mangledSymbol.dropFirst(3)
        } else if mangledSymbol.hasPrefix("$s") {
            input = mangledSymbol.dropFirst(2)
        } else {
            return nil
        }

        // Must end with a function kind marker
        guard let lastChar = mangledSymbol.last,
            functionKindMarkers.contains(lastChar)
        else {
            return nil
        }

        // Parse module name
        var words: [String] = []
        guard let (moduleName, rest1) = parseLengthPrefixed(input) else {
            return nil
        }
        addWords(from: moduleName, to: &words)
        input = rest1

        // Parse context (class/struct name) if present
        var contextName = ""
        var funcName = ""

        // Look for type context markers (C=class, V=struct, O=enum)
        if let first = input.first, "CVO".contains(first) {
            input = input.dropFirst()
            if let (ctxName, rest2) = parseIdentifierWithSubstitutions(input, words: &words) {
                contextName = ctxName
                input = rest2

                // Skip past type suffix
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

        // Skip to signature portion (look backwards from end)
        // The signature is everything between the function name and the final marker
        guard !funcName.isEmpty else {
            return nil
        }

        // Parse function signature from remaining input
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
    ///
    /// - Parameter symbol: The symbol to check.
    /// - Returns: True if the symbol appears to be a Swift function.
    public static func isFunctionSymbol(_ symbol: String) -> Bool {
        guard symbol.hasPrefix("_$s") || symbol.hasPrefix("$s") else {
            return false
        }
        guard let lastChar = symbol.last else {
            return false
        }
        return functionKindMarkers.contains(lastChar)
    }

    /// Demangle a Swift closure/function type expression.
    ///
    /// Swift function types have various mangling formats:
    /// - `...c` - escaping function type
    /// - `...XB` - @convention(block) (ObjC block)
    /// - `...XC` - @convention(c) (C function pointer)
    /// - `...XE` - noescape function type
    /// - `...Xf` - @thin function type
    ///
    /// Effect markers:
    /// - `Ya` - async
    /// - `Yb` - @Sendable
    /// - `K` - throws
    ///
    /// - Parameter mangled: The mangled closure type string.
    /// - Returns: A parsed `ClosureType`, or nil if not a closure type.
    ///
    /// Example:
    /// ```swift
    /// let closure = SwiftDemangler.demangleClosureType("ySScXB")
    /// // closure?.parameterTypes == ["String"]
    /// // closure?.returnType == "Void"
    /// // closure?.convention == .block
    /// ```
    public static func demangleClosureType(_ mangled: String) -> ClosureType? {
        guard !mangled.isEmpty else { return nil }

        var input = Substring(mangled)

        // Determine convention from suffix
        var convention: ClosureConvention = .swift
        var isEscaping = true  // Default for swift convention

        if input.hasSuffix("XB") {
            convention = .block
            input = input.dropLast(2)
        } else if input.hasSuffix("XC") {
            convention = .cFunction
            input = input.dropLast(2)
        } else if input.hasSuffix("XE") {
            convention = .swift
            isEscaping = false  // Noescape
            input = input.dropLast(2)
        } else if input.hasSuffix("Xf") {
            convention = .thin
            input = input.dropLast(2)
        } else if input.hasSuffix("c") {
            convention = .swift
            isEscaping = true
            input = input.dropLast(1)
        } else {
            // No recognized function type suffix
            return nil
        }

        // Parse effects and types from the remaining
        let parsed = parseClosureTypeComponents(input)

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
    ///
    /// - Parameter mangled: The mangled string to check.
    /// - Returns: True if it appears to be a function type.
    public static func isClosureType(_ mangled: String) -> Bool {
        guard !mangled.isEmpty else { return false }

        // Check for function type suffixes
        if mangled.hasSuffix("XB") || mangled.hasSuffix("XC") || mangled.hasSuffix("XE") || mangled.hasSuffix("Xf") {
            return true
        }

        // Check for escaping function suffix 'c'
        // Must not be confused with other uses of 'c'
        if mangled.hasSuffix("c") && mangled.count > 1 {
            // Verify it's not just a type ending in 'c'
            let beforeC = mangled.dropLast()
            // Function types have param/return markers
            return beforeC.contains("y") || beforeC.contains("S") || beforeC.hasSuffix("Ya") || beforeC.hasSuffix("Yb")
                || beforeC.hasSuffix("K")
        }

        return false
    }

    /// Parse closure type components from mangled input.
    private static func parseClosureTypeComponents(_ input: Substring) -> (
        params: [String], returnType: String, isAsync: Bool, isThrowing: Bool, isSendable: Bool
    ) {
        var remaining = input
        var params: [String] = []
        var returnType = "Void"
        var isAsync = false
        var isThrowing = false
        var isSendable = false

        // Parse all types and effects
        var parsedTypes: [String] = []

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
            if remaining.hasPrefix("K") && !remaining.hasPrefix("KZ") {
                isThrowing = true
                remaining = remaining.dropFirst()
                continue
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
            } else if let (typeName, rest) = parseLengthPrefixed(remaining) {
                parsedTypes.append(typeName)
                remaining = rest
                // Skip type suffix
                while let c = remaining.first, "CVO".contains(c) {
                    remaining = remaining.dropFirst()
                }
            } else {
                // Can't parse more, stop
                break
            }
        }

        // Interpret parsed types:
        // In Swift mangling, return type comes first, then params
        if parsedTypes.count >= 1 {
            returnType = parsedTypes[0]
        }
        if parsedTypes.count >= 2 {
            params = Array(parsedTypes[1...])
        }

        // Filter out "Void" from params (represents empty param list)
        params = params.filter { $0 != "Void" }

        return (params, returnType, isAsync, isThrowing, isSendable)
    }

    /// Function kind markers that indicate a function symbol.
    private static let functionKindMarkers: Set<Character> = [
        "F",  // Regular function
        "f",  // Function implementation
        "g",  // Getter
        "s",  // Setter
        "W",  // Witness method
        "Z",  // Static method
    ]

    /// Parse function signature types from mangled input.
    private static func parseFunctionSignatureTypes(_ input: Substring) -> (
        params: [String], returnType: String, isAsync: Bool, isThrowing: Bool, isSendable: Bool,
        errorType: String?
    ) {
        var remaining = input
        var params: [String] = []
        var returnType = "Void"
        var isAsync = false
        var isThrowing = false
        var isSendable = false
        var errorType: String? = nil

        // Parse types until we hit effect markers or end
        var parsedTypes: [String] = []

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
            if remaining.count == 1, let c = remaining.first, functionKindMarkers.contains(c) {
                break
            }

            // Check for empty-list marker (void/no params)
            if remaining.hasPrefix("y") {
                // Empty list - could be void return or no params
                parsedTypes.append("Void")
                remaining = remaining.dropFirst()
                continue
            }

            // Try to parse a type
            if let (typeName, rest) = parseGenericTypeArg(remaining, depth: 0) {
                parsedTypes.append(typeName)
                remaining = rest
            } else if let (typeName, rest) = parseLengthPrefixed(remaining) {
                parsedTypes.append(typeName)
                remaining = rest
                // Skip type suffix
                while let c = remaining.first, "CVO".contains(c) {
                    remaining = remaining.dropFirst()
                }
            } else {
                // Can't parse more, stop
                break
            }
        }

        // Interpret parsed types:
        // In Swift mangling, result type comes first, then params
        if parsedTypes.count >= 1 {
            returnType = parsedTypes[0]
        }
        if parsedTypes.count >= 2 {
            params = Array(parsedTypes[1...])
        }

        // Filter out "Void" from params (represents empty param list)
        params = params.filter { $0 != "Void" }

        return (params, returnType, isAsync, isThrowing, isSendable, errorType)
    }

    /// Demangle a Swift name (class, protocol, or other type) for display.
    ///
    /// This is the primary method for formatting Swift names in output.
    /// It handles:
    /// - `_TtC...` class names → `Module.ClassName`
    /// - `_TtCC...` nested classes → `Module.Outer.Inner`
    /// - `_TtP..._` protocol names → `Module.ProtocolName`
    /// - `_TtCs...` Swift stdlib types → `_SwiftObject`, etc.
    /// - `$s...` Swift 5+ symbols → demangled form
    /// - Names without mangling → returned as-is
    ///
    /// - Parameter mangledName: The potentially mangled name.
    /// - Returns: A human-readable name, or the original if not mangled.
    public static func demangleSwiftName(_ mangledName: String) -> String {
        // Not mangled
        guard mangledName.hasPrefix("_Tt") || mangledName.hasPrefix("$s") || mangledName.hasPrefix("_$s")
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

        // Swift standard library types with _Tt prefix (e.g., _TtSS, _TtSi, _TtSSSg)
        // Strip _Tt prefix and demangle the rest using standard demangle logic
        if mangledName.hasPrefix("_TtS") && !mangledName.hasPrefix("_TtSo") {
            let inner = String(mangledName.dropFirst(3))  // Remove "_Tt"
            let demangled = demangle(inner)
            if demangled != inner {
                return demangled
            }
        }

        // Swift stdlib internal types like _TtCs12_SwiftObject
        if mangledName.hasPrefix("_TtCs") {
            // Extract the type name (skip _TtCs prefix, parse length + name)
            let input = mangledName.dropFirst(5)
            if let (typeName, _) = parseLengthPrefixed(input) {
                return typeName
            }
            return mangledName
        }

        // Swift stdlib global actors and other types starting with _TtGC or _TtGV
        if mangledName.hasPrefix("_TtG") {
            if let result = demangleGenericType(mangledName) {
                return result
            }
            // Fall back to just class name without generics
            if let (module, name) = demangleClassName(mangledName) {
                return module == "Swift" ? name : "\(module).\(name)"
            }
            return mangledName
        }

        // Nested classes
        if mangledName.hasPrefix("_TtCC") || mangledName.hasPrefix("_TtCCC") {
            let names = demangleNestedClassName(mangledName)
            if !names.isEmpty {
                // Try to get module name too
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
            // Try extracting private class name even if full parsing failed
            if let privateName = extractPrivateTypeName(mangledName) {
                return privateName
            }
            return mangledName
        }

        // Enum types (_TtO prefix)
        if mangledName.hasPrefix("_TtO") {
            if let result = parseObjCSwiftTypeName(mangledName, prefix: "_TtO") {
                return result
            }
            if let privateName = extractPrivateTypeName(mangledName) {
                return privateName
            }
            return mangledName
        }

        // Value types/structs (_TtV prefix)
        if mangledName.hasPrefix("_TtV") {
            if let result = parseObjCSwiftTypeName(mangledName, prefix: "_TtV") {
                return result
            }
            if let privateName = extractPrivateTypeName(mangledName) {
                return privateName
            }
            return mangledName
        }

        // Combined nested types with enums/structs (_TtCO, _TtCV, _TtOO, etc.)
        if mangledName.hasPrefix("_TtC") || mangledName.hasPrefix("_TtO") || mangledName.hasPrefix("_TtV") {
            if let result = parseComplexNestedType(mangledName) {
                return result
            }
        }

        // Fallback for other _Tt prefixes
        return extractTypeName(mangledName)
    }

    /// Extract private type name from a mangled name with P33_ discriminator.
    ///
    /// Format: `_TtC<module>P33_<32-hex-chars><name-len><name>`
    private static func extractPrivateTypeName(_ mangledName: String) -> String? {
        // Look for P33_ followed by 32 hex characters
        guard let p33Range = mangledName.range(of: "P33_") else {
            return nil
        }

        // Skip the P33_ prefix and 32 hex characters
        let afterP33 = mangledName[p33Range.upperBound...]
        guard afterP33.count > 32 else { return nil }

        let afterHex = afterP33.dropFirst(32)

        // Parse the type name that follows
        if let (typeName, _) = parseLengthPrefixed(afterHex) {
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
    private static func extractModuleName(from partial: String) -> String? {
        // Try to find module name pattern at the start after prefix
        var input = Substring(partial)

        // Skip common prefixes
        for prefix in ["_TtCC", "_TtCO", "_TtCV", "_TtOO", "_TtOC", "_TtVO", "_TtVC", "_TtC", "_TtO", "_TtV"] {
            if input.hasPrefix(prefix) {
                input = input.dropFirst(prefix.count)
                break
            }
        }

        // Parse module name
        if let (moduleName, _) = parseLengthPrefixed(input) {
            return moduleName
        }
        return nil
    }

    /// Parse a type name with the given prefix (for enums, structs).
    private static func parseObjCSwiftTypeName(_ mangledName: String, prefix: String) -> String? {
        guard mangledName.hasPrefix(prefix) else { return nil }

        var input = mangledName.dropFirst(prefix.count)

        // Handle nested types (O, C, V prefixes)
        while let first = input.first, "OCV".contains(first) {
            input = input.dropFirst()
        }

        // Parse module name
        guard let (moduleName, rest1) = parseLengthPrefixed(input) else {
            return nil
        }

        // Parse type name
        guard let (typeName, _) = parseLengthPrefixed(rest1) else {
            return nil
        }

        return moduleName == "Swift" ? typeName : "\(moduleName).\(typeName)"
    }

    /// Parse complex nested types with mixed class/enum/struct hierarchy.
    private static func parseComplexNestedType(_ mangledName: String) -> String? {
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
        guard let (moduleName, rest) = parseLengthPrefixed(input) else {
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

            if let (name, rest) = parseLengthPrefixed(input) {
                names.append(name)
                input = rest
            } else {
                break
            }
        }

        guard !names.isEmpty else { return nil }

        let joinedNames = names.joined(separator: ".")
        return moduleName == "Swift" ? joinedNames : "\(moduleName).\(joinedNames)"
    }

    /// Demangle a nested class name and return all class names in the hierarchy.
    ///
    /// For `_TtCC13IDEFoundation22IDEBuildNoticeProvider16BuildLogObserver`
    /// returns `["IDEBuildNoticeProvider", "BuildLogObserver"]`
    ///
    /// - Parameter mangledClassName: The mangled class name.
    /// - Returns: Array of class names from outermost to innermost.
    public static func demangleNestedClassName(_ mangledClassName: String) -> [String] {
        return parseNestedClassNames(mangledClassName)
    }

    /// Extract a readable type name from various mangled formats.
    ///
    /// This handles:
    /// - Swift 5+ symbols (`_$s...` or `$s...`)
    /// - ObjC-style Swift classes (`_Tt...`)
    /// - Qualified types (`10Module4TypeV`)
    /// - Standard shortcuts and builtins
    ///
    /// - Parameter mangled: The mangled type string.
    /// - Returns: A simplified type name.
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

        // Fall back to main demangle
        return demangle(mangled)
    }

    /// Demangle a complex type expression that may contain generics.
    ///
    /// Use this for types that may have nested generic parameters.
    ///
    /// - Parameter mangled: The mangled type string.
    /// - Returns: A demangled type string, or the original if too complex.
    public static func demangleComplexType(_ mangled: String) -> String {
        let result = demangle(mangled)
        if result != mangled {
            return result
        }
        return demangleDetailed(mangled)
    }

    // MARK: - Type Lookup Tables

    /// Standard library type shortcuts (single character).
    private static let typeShortcuts: [Character: String] = [
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

    /// Builtin type mappings.
    private static let builtinTypes: [String: String] = [
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

    /// Common mangled type patterns.
    private static let commonPatterns: [String: String] = [
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
        "s5Int8V": "Int8",
        "s6UInt8V": "UInt8",
        "s5Int16V": "Int16",
        "s6UInt16V": "UInt16",
        "s5Int32V": "Int32",
        "s6UInt32V": "UInt32",
        "s5Int64V": "Int64",
        "s6UInt64V": "UInt64",
        "Sg": "Optional",
        "ySg": "?",
        "Sq": "Optional",
        "yt": "()",
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

    /// Swift standard library protocol shortcuts.
    /// These are two-character codes used in mangled names for common protocols.
    private static let protocolShortcuts: [String: String] = [
        "SH": "Hashable",
        "SE": "Equatable",
        "SQ": "Equatable",  // Alternative
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
        "s10StringProtocol": "StringProtocol",
        "SK": "BidirectionalCollection",
        "Sk": "RandomAccessCollection",
        "SM": "MutableCollection",
        "Sm": "RangeReplaceableCollection",
        "s8SendableP": "Sendable",
        "s5ErrorP": "Error",
        "s7CodableP": "Codable",
        "Se": "Encodable",
        "SD": "Decodable",
        "SN": "FixedWidthInteger",
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

    /// ObjC type to Swift type mappings.
    private static let objcToSwiftTypes: [String: String] = [
        "OS_dispatch_queue": "DispatchQueue",
        "OS_dispatch_group": "DispatchGroup",
        "OS_dispatch_semaphore": "DispatchSemaphore",
        "OS_dispatch_source": "DispatchSource",
        "OS_dispatch_data": "DispatchData",
        "OS_dispatch_io": "DispatchIO",
        "OS_dispatch_workloop": "DispatchWorkloop",
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

    // MARK: - Detailed Demangling

    /// Detailed demangling for types that don't match simple patterns.
    private static func demangleDetailed(_ mangled: String) -> String {
        // Task type with generic parameters (ScTy...G)
        if mangled.hasPrefix("ScTy") && mangled.hasSuffix("G") {
            let inner = String(mangled.dropFirst(4).dropLast(1))
            if let (success, failure) = parseTaskGenericArgs(inner) {
                return "Task<\(success), \(failure)>"
            }
        }

        // AsyncStream with generic parameter (ScSy...G)
        if mangled.hasPrefix("ScSy") && mangled.hasSuffix("G") {
            let inner = String(mangled.dropFirst(4).dropLast(1))
            if let (element, _) = parseGenericTypeArg(Substring(inner), depth: 0) {
                return "AsyncStream<\(element)>"
            }
        }

        // AsyncThrowingStream with generic parameter (ScFy...G)
        if mangled.hasPrefix("ScFy") && mangled.hasSuffix("G") {
            let inner = String(mangled.dropFirst(4).dropLast(1))
            if let (element, _) = parseGenericTypeArg(Substring(inner), depth: 0) {
                return "AsyncThrowingStream<\(element)>"
            }
        }

        // CheckedContinuation with generic parameters (ScCy...G)
        if mangled.hasPrefix("ScCy") && mangled.hasSuffix("G") {
            if let (result, _) = parseTaskGenericArgsFromInput(
                Substring(mangled.dropFirst(4)))
            {
                // CheckedContinuation uses same format as Task: <Success, Failure>
                return result.replacingOccurrences(of: "Task", with: "CheckedContinuation")
            }
        }

        // UnsafeContinuation with generic parameters (ScUy...G)
        if mangled.hasPrefix("ScUy") && mangled.hasSuffix("G") {
            if let (result, _) = parseTaskGenericArgsFromInput(
                Substring(mangled.dropFirst(4)))
            {
                return result.replacingOccurrences(of: "Task", with: "UnsafeContinuation")
            }
        }

        // Optional suffix (Sg)
        if mangled.hasSuffix("Sg") {
            let base = String(mangled.dropLast(2))
            let inner = demangle(base)
            return "\(inner)?"
        }

        // Array shorthand (Say...G) - use recursive parsing for nested generics
        if mangled.hasPrefix("Say") {
            if let (arrayType, _) = parseNestedArrayType(Substring(mangled), depth: 0) {
                return arrayType
            }
        }

        // Dictionary shorthand (SDy...G) - use recursive parsing for nested generics
        if mangled.hasPrefix("SDy") {
            if let (dictType, _) = parseNestedDictionaryType(Substring(mangled), depth: 0) {
                return dictType
            }
        }

        // Set shorthand (Shy...G) - use recursive parsing for nested generics
        if mangled.hasPrefix("Shy") {
            if let (setType, _) = parseNestedSetType(Substring(mangled), depth: 0) {
                return setType
            }
        }

        // ObjC imported type (So prefix)
        if mangled.hasPrefix("So") {
            return demangleObjCImportedType(String(mangled.dropFirst(2)))
        }

        // Swift module type (s prefix)
        if mangled.hasPrefix("s") || mangled.hasPrefix("S") {
            let rest = String(mangled.dropFirst())
            if let first = rest.first, first.isNumber {
                let typeName = parseQualifiedType(Substring(rest))
                if !typeName.isEmpty {
                    return "Swift.\(typeName)"
                }
            }
        }

        // Qualified type (starts with digit)
        if let first = mangled.first, first.isNumber {
            return parseQualifiedType(Substring(mangled))
        }

        return mangled
    }

    // MARK: - Generic Type Parsing

    /// Demangle a generic type with type arguments.
    ///
    /// Format: `_TtGC<module><class><type_args>_` or `_TtGV<module><struct><type_args>_`
    ///
    /// Examples:
    /// - `_TtGC10ModuleName7GenericSS_` → `ModuleName.Generic<String>`
    /// - `_TtGC10ModuleName7PairMapSSSi_` → `ModuleName.PairMap<String, Int>`
    private static func demangleGenericType(_ mangledName: String) -> String? {
        guard mangledName.hasPrefix("_TtG"), mangledName.hasSuffix("_") else {
            return nil
        }

        var input = mangledName.dropFirst(4)  // Remove "_TtG"
        input = input.dropLast()  // Remove trailing "_"

        // Skip type kind (C=class, V=struct, O=enum)
        guard let kind = input.first, "CVO".contains(kind) else {
            return nil
        }
        input = input.dropFirst()

        // Parse module name
        guard let (moduleName, rest1) = parseLengthPrefixed(input) else {
            return nil
        }
        input = rest1

        // Parse type name
        guard let (typeName, rest2) = parseLengthPrefixed(input) else {
            return nil
        }
        input = rest2

        // Parse type arguments
        var typeArgs: [String] = []
        while !input.isEmpty {
            if let (arg, rest) = parseGenericTypeArg(input) {
                typeArgs.append(arg)
                input = rest
            } else {
                break
            }
        }

        // Format result
        let prefix = moduleName == "Swift" ? "" : "\(moduleName)."
        if typeArgs.isEmpty {
            return "\(prefix)\(typeName)"
        } else {
            return "\(prefix)\(typeName)<\(typeArgs.joined(separator: ", "))>"
        }
    }

    /// Maximum recursion depth for nested generic parsing.
    private static let maxGenericNestingDepth = 10

    /// Parse a single generic type argument from a mangled string.
    ///
    /// Handles common type shortcuts, module-qualified types, and nested generics.
    ///
    /// - Parameters:
    ///   - input: The mangled type string to parse.
    ///   - depth: Current recursion depth (for safety limits).
    /// - Returns: A tuple of (demangled type name, remaining input) or nil if parsing fails.
    private static func parseGenericTypeArg(_ input: Substring, depth: Int = 0) -> (String, Substring)? {
        guard !input.isEmpty else { return nil }
        guard depth < maxGenericNestingDepth else { return nil }

        // Check for nested Array type (Say...G)
        if input.hasPrefix("Say") {
            if let (arrayType, rest) = parseNestedArrayType(input, depth: depth) {
                return (arrayType, rest)
            }
        }

        // Check for nested Dictionary type (SDy...G)
        if input.hasPrefix("SDy") {
            if let (dictType, rest) = parseNestedDictionaryType(input, depth: depth) {
                return (dictType, rest)
            }
        }

        // Check for nested Set type (Shy...G)
        if input.hasPrefix("Shy") {
            if let (setType, rest) = parseNestedSetType(input, depth: depth) {
                return (setType, rest)
            }
        }

        // Check for literal "Never" - used in Task failure type
        if input.hasPrefix("Never") {
            return ("Never", input.dropFirst(5))
        }

        // Check for ObjC imported type (So prefix) - MUST be before single-char shortcuts
        // to prevent 'S' from matching as String
        if input.hasPrefix("So") {
            var rest = input.dropFirst(2)
            if let (typeName, remaining) = parseLengthPrefixed(rest) {
                let mapped = objcToSwiftTypes[typeName] ?? typeName
                // Skip type suffix
                rest = remaining
                // Skip type kind suffixes: C=class, V=struct, O=enum, P=protocol metatype
                while let c = rest.first, "CVOPy".contains(c) {
                    rest = rest.dropFirst()
                }
                // Handle _p protocol existential suffix
                if rest.hasPrefix("_p") {
                    rest = rest.dropFirst(2)
                }
                // Check for Optional suffix
                if rest.hasPrefix("Sg") {
                    return ("\(mapped)?", rest.dropFirst(2))
                }
                return (mapped, rest)
            }
        }

        // Check for stdlib type shortcuts that start with 'S' (before single-char 'S' = String)
        // Sa = Array, SD = Dictionary (note: SDy is handled above), Sc = concurrency types
        if input.hasPrefix("Sa") {
            let remaining = input.dropFirst(2)
            if remaining.hasPrefix("Sg") {
                return ("Array?", remaining.dropFirst(2))
            }
            return ("Array", remaining)
        }

        // Check for concurrency types with generic parameters (ScTy...G, ScSy...G, etc.)
        if input.hasPrefix("ScT") && input.dropFirst(3).hasPrefix("y") {
            // Task with generic parameters: ScTy<success>y<failure>G
            let afterScT = input.dropFirst(3)  // Remove "ScT"
            if afterScT.hasPrefix("y") {
                let remaining = afterScT.dropFirst()  // Remove first 'y'
                if let (task, rest) = parseTaskGenericArgsFromInput(remaining) {
                    return (task, rest)
                }
            }
        }

        if input.hasPrefix("ScS") && input.dropFirst(3).hasPrefix("y") {
            // AsyncStream with generic parameter: ScSy<element>G
            let afterScS = input.dropFirst(3)  // Remove "ScS"
            if afterScS.hasPrefix("y") {
                let remaining = afterScS.dropFirst()  // Remove 'y'
                if let (element, rest) = parseGenericTypeArg(remaining, depth: depth + 1) {
                    var finalRest = rest
                    if finalRest.hasPrefix("G") {
                        finalRest = finalRest.dropFirst()
                    }
                    return ("AsyncStream<\(element)>", finalRest)
                }
            }
        }

        // Check for two-character patterns (SS, Si, Sb, Sd, Sf, Su, Sc*, etc.)
        if input.count >= 2 {
            let twoChars = String(input.prefix(2))
            if let result = commonPatterns[twoChars] {
                // Check for Optional suffix on simple types
                let remaining = input.dropFirst(2)
                if remaining.hasPrefix("Sg") {
                    return ("\(result)?", remaining.dropFirst(2))
                }
                return (result, remaining)
            }
        }

        // Check for single-character shortcuts (but NOT 'S' which needs special handling above)
        if let first = input.first, first != "S", let shortcut = typeShortcuts[first] {
            // Check for Optional suffix
            let remaining = input.dropFirst()
            if remaining.hasPrefix("Sg") {
                return ("\(shortcut)?", remaining.dropFirst(2))
            }
            return (shortcut, remaining)
        }

        // Check for length-prefixed module.type (including protocol existentials)
        if let first = input.first, first.isNumber {
            if let (typeName, rest) = parseModuleQualifiedType(input, depth: depth) {
                // Skip type suffix
                var remaining = rest
                while let c = remaining.first, "CVOPy".contains(c) {
                    remaining = remaining.dropFirst()
                }
                // Check for Optional suffix
                if remaining.hasPrefix("Sg") {
                    return ("\(typeName)?", remaining.dropFirst(2))
                }
                return (typeName, remaining)
            }
        }

        return nil
    }

    /// Parse a nested Array type (Say...G) recursively.
    ///
    /// - Parameters:
    ///   - input: Input starting with "Say".
    ///   - depth: Current recursion depth.
    /// - Returns: Tuple of (formatted array type, remaining input) or nil.
    private static func parseNestedArrayType(_ input: Substring, depth: Int) -> (String, Substring)? {
        guard input.hasPrefix("Say") else { return nil }

        var inner = input.dropFirst(3)  // Remove "Say"
        var elementType: String?
        var foundClosing = false

        // Parse element type recursively
        if let (element, rest) = parseGenericTypeArg(inner, depth: depth + 1) {
            elementType = element
            inner = rest
        } else {
            return nil
        }

        // Look for closing G
        if inner.hasPrefix("G") {
            inner = inner.dropFirst()
            foundClosing = true
        }

        guard foundClosing, let element = elementType else { return nil }

        var result = "[\(element)]"

        // Check for Optional suffix on the array itself
        if inner.hasPrefix("Sg") {
            result += "?"
            inner = inner.dropFirst(2)
        }

        return (result, inner)
    }

    /// Parse a nested Dictionary type (SDy...G) recursively.
    ///
    /// - Parameters:
    ///   - input: Input starting with "SDy".
    ///   - depth: Current recursion depth.
    /// - Returns: Tuple of (formatted dictionary type, remaining input) or nil.
    private static func parseNestedDictionaryType(_ input: Substring, depth: Int) -> (String, Substring)? {
        guard input.hasPrefix("SDy") else { return nil }

        var inner = input.dropFirst(3)  // Remove "SDy"
        var typeArgs: [String] = []

        // Parse key and value types
        while typeArgs.count < 2 && !inner.isEmpty {
            if let (arg, rest) = parseGenericTypeArg(inner, depth: depth + 1) {
                typeArgs.append(arg)
                inner = rest
            } else {
                break
            }
        }

        // Look for closing G
        guard inner.hasPrefix("G") else { return nil }
        inner = inner.dropFirst()

        guard typeArgs.count == 2 else { return nil }

        var result = "[\(typeArgs[0]): \(typeArgs[1])]"

        // Check for Optional suffix on the dictionary itself
        if inner.hasPrefix("Sg") {
            result += "?"
            inner = inner.dropFirst(2)
        }

        return (result, inner)
    }

    /// Parse a nested Set type (Shy...G) recursively.
    ///
    /// - Parameters:
    ///   - input: Input starting with "Shy".
    ///   - depth: Current recursion depth.
    /// - Returns: Tuple of (formatted set type, remaining input) or nil.
    private static func parseNestedSetType(_ input: Substring, depth: Int) -> (String, Substring)? {
        guard input.hasPrefix("Shy") else { return nil }

        var inner = input.dropFirst(3)  // Remove "Shy"
        var elementType: String?

        // Parse element type recursively
        if let (element, rest) = parseGenericTypeArg(inner, depth: depth + 1) {
            elementType = element
            inner = rest
        } else {
            return nil
        }

        // Look for closing G
        guard inner.hasPrefix("G") else { return nil }
        inner = inner.dropFirst()

        guard let element = elementType else { return nil }

        var result = "Set<\(element)>"

        // Check for Optional suffix on the set itself
        if inner.hasPrefix("Sg") {
            result += "?"
            inner = inner.dropFirst(2)
        }

        return (result, inner)
    }

    /// Parse Task generic arguments from input.
    ///
    /// Task has two type parameters: Success and Failure.
    /// Format: `ScTy<success><failure>G` where success can be `yt` (Void) and failure is often `Never` (s5NeverO).
    ///
    /// - Parameter input: Input starting after "ScTy".
    /// - Returns: Tuple of (formatted Task type, remaining input) or nil.
    private static func parseTaskGenericArgsFromInput(_ input: Substring) -> (String, Substring)? {
        var inner = input
        var typeArgs: [String] = []

        // Parse success type
        if let (arg, rest) = parseGenericTypeArg(inner, depth: 0) {
            typeArgs.append(arg)
            inner = rest
        } else {
            return nil
        }

        // Check for second 'y' separator or continue parsing failure type
        if inner.hasPrefix("y") {
            inner = inner.dropFirst()
        }

        // Parse failure type
        if let (arg, rest) = parseGenericTypeArg(inner, depth: 0) {
            typeArgs.append(arg)
            inner = rest
        } else {
            return nil
        }

        // Look for closing G
        if inner.hasPrefix("G") {
            inner = inner.dropFirst()
        }

        guard typeArgs.count == 2 else { return nil }

        return ("Task<\(typeArgs[0]), \(typeArgs[1])>", inner)
    }

    /// Parse a module-qualified type (e.g., 13IDEFoundation19IDETestingSpecifier).
    ///
    /// Handles:
    /// - Single component: `7MyClass` → "MyClass"
    /// - Module.Type: `13IDEFoundation19IDETestingSpecifier` → "IDEFoundation.IDETestingSpecifier"
    /// - Protocol existential: `13IDEFoundation19IDETestingSpecifier_p` → "any IDETestingSpecifier"
    ///
    /// - Parameters:
    ///   - input: Input starting with a digit.
    ///   - depth: Current recursion depth.
    /// - Returns: Tuple of (type name, remaining input) or nil.
    private static func parseModuleQualifiedType(_ input: Substring, depth: Int = 0) -> (String, Substring)? {
        guard let first = input.first, first.isNumber else {
            return nil
        }

        // Parse first component
        guard let (firstName, afterFirst) = parseLengthPrefixed(input) else {
            return nil
        }

        // Check if there's another length-prefixed component (module.type pattern)
        if let secondFirst = afterFirst.first, secondFirst.isNumber {
            if let (secondName, afterSecond) = parseLengthPrefixed(afterFirst) {
                // Check for protocol existential suffix (_p)
                if afterSecond.hasPrefix("_p") {
                    let remaining = afterSecond.dropFirst(2)  // Remove "_p"
                    return ("any \(secondName)", remaining)
                }
                // Regular module.type
                return ("\(firstName).\(secondName)", afterSecond)
            }
        }

        // Single component - check for protocol existential suffix
        if afterFirst.hasPrefix("_p") {
            let remaining = afterFirst.dropFirst(2)  // Remove "_p"
            return ("any \(firstName)", remaining)
        }

        return (firstName, afterFirst)
    }

    // MARK: - ObjC Class Name Parsing

    /// Parse an ObjC-style Swift class name.
    private static func parseObjCSwiftClassName(_ name: String) -> (module: String, name: String)? {
        var input: Substring
        var isNested = false

        // Determine prefix and nesting level
        if name.hasPrefix("_TtGC") {
            input = name.dropFirst(5)
        } else if name.hasPrefix("_TtCC") {
            input = name.dropFirst(5)
            isNested = true
        } else if name.hasPrefix("_TtC") {
            input = name.dropFirst(4)
        } else if name.hasPrefix("_Tt") {
            input = name.dropFirst(3)
            guard let first = input.first, first.isNumber else { return nil }
        } else {
            return nil
        }

        // Parse module name
        guard let (moduleName, rest1) = parseLengthPrefixed(input) else {
            return nil
        }
        input = rest1

        // Parse class name
        guard let (className, rest2) = parseLengthPrefixed(input) else {
            return nil
        }
        input = rest2

        // For nested classes, parse inner class name
        if isNested {
            if let (innerName, _) = parseLengthPrefixed(input) {
                return (moduleName, "\(className).\(innerName)")
            }
        }

        return (moduleName, className)
    }

    /// Parse all nested class names from a mangled class name.
    private static func parseNestedClassNames(_ name: String) -> [String] {
        var input: Substring
        var names: [String] = []

        // Determine prefix
        if name.hasPrefix("_TtCCC") {
            input = name.dropFirst(6)
        } else if name.hasPrefix("_TtCC") {
            input = name.dropFirst(5)
        } else if name.hasPrefix("_TtC") {
            input = name.dropFirst(4)
        } else if name.hasPrefix("_Tt") {
            input = name.dropFirst(3)
        } else {
            return []
        }

        // Skip module name
        guard let (_, rest) = parseLengthPrefixed(input) else {
            return []
        }
        input = rest

        // Parse all class names until we hit a non-digit
        while let (name, rest) = parseLengthPrefixed(input) {
            names.append(name)
            input = rest
            if let first = input.first, !first.isNumber {
                break
            }
        }

        return names
    }

    // MARK: - ObjC Import Demangling

    /// Demangle an ObjC imported type (after stripping "So" prefix).
    private static func demangleObjCImportedType(_ rest: String) -> String {
        guard let first = rest.first, first.isNumber else {
            return rest
        }

        if let (typeName, remainder) = parseLengthPrefixed(Substring(rest)) {
            // Check for known mappings
            if let mapped = objcToSwiftTypes[typeName] {
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

    // MARK: - Swift 5+ Symbol Demangling

    /// Demangle a Swift 5+ symbol (after stripping _$s or $s prefix).
    private static func demangleSwift5Symbol(_ mangled: String) -> String {
        var input = Substring(mangled)
        var words: [String] = []
        var moduleName: String = ""
        var typeName: String = ""

        // Handle known module substitutions
        if input.hasPrefix("So") {
            input = input.dropFirst(2)
            moduleName = "__C"
            if let (name, _) = parseLengthPrefixed(input) {
                typeName = name
                return objcToSwiftTypes[typeName] ?? "\(moduleName).\(typeName)"
            }
        } else if input.hasPrefix("s") && !(input.first?.isNumber ?? true) {
            input = input.dropFirst()
            moduleName = "Swift"
        }

        // Parse module name
        if moduleName.isEmpty {
            guard let (name, rest) = parseLengthPrefixed(input) else {
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
                if let (arg, rest) = parseTypeArgument(input, words: &words, moduleName: moduleName) {
                    genericArgs.append(arg)
                    input = rest
                } else {
                    break
                }
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

    // MARK: - Qualified Type Parsing

    /// Parse a qualified type name like "10Foundation4DateV".
    private static func parseQualifiedType(_ input: Substring) -> String {
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
                if let (component, rest) = parseLengthPrefixed(remaining) {
                    components.append(component)
                    remaining = rest
                    continue
                }
            }

            remaining = remaining.dropFirst()
        }

        return components.joined(separator: ".")
    }

    // MARK: - Word Substitution Helpers

    /// Parse an identifier that may contain word substitutions.
    private static func parseIdentifierWithSubstitutions(
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
                    let index = Int(char.asciiValue! - Character("a").asciiValue!)
                    if index < words.count {
                        result += words[index]
                    }
                    input = input.dropFirst()
                } else if char.isUppercase && char >= "A" && char <= "Z" {
                    // Final word reference
                    let index = Int(char.asciiValue! - Character("A").asciiValue!)
                    if index < words.count {
                        result += words[index]
                    }
                    input = input.dropFirst()

                    // Check for trailing literal
                    if let next = input.first, next.isNumber {
                        if let (literal, rest) = parseLengthPrefixed(input) {
                            result += literal
                            addWords(from: literal, to: &words)
                            input = rest
                        }
                    }
                    break  // Uppercase terminates
                } else if char.isNumber {
                    // Literal string
                    if let (literal, rest) = parseLengthPrefixed(input) {
                        result += literal
                        addWords(from: literal, to: &words)
                        input = rest
                    } else {
                        break
                    }
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
        if let (name, rest) = parseLengthPrefixed(input) {
            addWords(from: name, to: &words)
            return (name, rest)
        }

        return nil
    }

    /// Parse a type argument in generic bounds.
    private static func parseTypeArgument(
        _ input: Substring,
        words: inout [String],
        moduleName: String
    ) -> (String, Substring)? {
        var input = input

        if let first = input.first {
            // Standard library shortcuts
            if let shortcut = typeShortcuts[first] {
                return (shortcut, input.dropFirst())
            }

            // Two-character patterns
            if first == "S" && input.count >= 2 {
                let twoChar = String(input.prefix(2))
                if let pattern = commonPatterns[twoChar] {
                    return (pattern, input.dropFirst(2))
                }
            }

            // ObjC imported type
            if first == "S" && input.count >= 2 {
                let second = input[input.index(after: input.startIndex)]
                if second == "o" {
                    input = input.dropFirst(2)
                    if let (name, rest) = parseLengthPrefixed(input) {
                        let mapped = objcToSwiftTypes[name] ?? name
                        var remaining = rest
                        while let c = remaining.first, "CVOPy_".contains(c) {
                            remaining = remaining.dropFirst()
                        }
                        return (mapped, remaining)
                    }
                }
            }
        }

        // Try as qualified type
        if let (name, rest) = parseIdentifierWithSubstitutions(input, words: &words) {
            return (name, rest)
        }

        return nil
    }

    /// Add words from an identifier to the word dictionary.
    private static func addWords(from identifier: String, to words: inout [String]) {
        if !words.contains(identifier) {
            words.append(identifier)
        }

        // Split on uppercase boundaries
        var currentWord = ""
        for char in identifier {
            if char.isUppercase && !currentWord.isEmpty {
                if !words.contains(currentWord) {
                    words.append(currentWord)
                }
                currentWord = String(char)
            } else {
                currentWord.append(char)
            }
        }
        if !currentWord.isEmpty && !words.contains(currentWord) {
            words.append(currentWord)
        }
    }

    // MARK: - Concurrency Type Parsing

    /// Parse generic arguments for Task<Success, Failure>.
    ///
    /// Input format: `<success-type><failure-type>`
    /// Examples:
    /// - `ytNever` → (Void, Never)
    /// - `SSs5Errorp` → (String, Error)
    /// - `SiNever` → (Int, Never)
    private static func parseTaskGenericArgs(_ input: String) -> (success: String, failure: String)? {
        var remaining = Substring(input)

        // Parse success type
        guard let (successType, rest) = parseGenericType(remaining) else {
            return nil
        }
        remaining = rest

        // Parse failure type
        guard let (failureType, _) = parseGenericType(remaining) else {
            return nil
        }

        return (successType, failureType)
    }

    /// Parse a single generic type from a mangled string.
    ///
    /// Returns the demangled type name and remaining input.
    private static func parseGenericType(_ input: Substring) -> (String, Substring)? {
        guard !input.isEmpty else { return nil }

        // Check for Void tuple (yt)
        if input.hasPrefix("yt") {
            return ("Void", input.dropFirst(2))
        }

        // Check for "Never" (literal word) - must check before single-char shortcuts
        if input.hasPrefix("Never") {
            return ("Never", input.dropFirst(5))
        }

        // Check for Swift Error protocol (s5Errorp) - must check before 's' shortcut
        if input.hasPrefix("s5Errorp") {
            return ("Error", input.dropFirst(8))
        }

        // Check for qualified type (starts with 's' + digit for Swift module)
        if input.hasPrefix("s"), input.count > 1 {
            let afterS = input.dropFirst()
            if let first = afterS.first, first.isNumber {
                if let (typeName, rest) = parseLengthPrefixed(afterS) {
                    // Skip type suffix (V, C, O, p)
                    var remaining = rest
                    while let c = remaining.first, "VCOpP".contains(c) {
                        remaining = remaining.dropFirst()
                    }
                    return (typeName, remaining)
                }
            }
        }

        // Check for two-character patterns (SS, Si, Sb, Sd, Sf, Su)
        if input.count >= 2 {
            let twoChars = String(input.prefix(2))
            if let result = commonPatterns[twoChars] {
                return (result, input.dropFirst(2))
            }
        }

        // Check for single-character shortcuts
        if let first = input.first, let result = typeShortcuts[first] {
            return (result, input.dropFirst())
        }

        // Check for length-prefixed type
        if let first = input.first, first.isNumber {
            if let (typeName, rest) = parseLengthPrefixed(input) {
                // Skip type suffix
                var remaining = rest
                while let c = remaining.first, "VCOpP".contains(c) {
                    remaining = remaining.dropFirst()
                }
                return (typeName, remaining)
            }
        }

        return nil
    }

    // MARK: - Primitive Parsing Helpers

    /// Parse a length-prefixed string (e.g., "10Foundation" -> "Foundation").
    private static func parseLengthPrefixed(_ input: Substring) -> (String, Substring)? {
        var lengthStr = ""
        var remaining = input

        while let char = remaining.first, char.isNumber {
            lengthStr.append(char)
            remaining = remaining.dropFirst()
        }

        guard let length = Int(lengthStr), length > 0, remaining.count >= length else {
            return nil
        }

        let str = String(remaining.prefix(length))
        return (str, remaining.dropFirst(length))
    }

    // MARK: - Generic Signature and Constraint Parsing

    /// Demangle a generic signature with constraints.
    ///
    /// This parses the generic signature portion of a mangled name, extracting
    /// type parameters and constraints (where clauses).
    ///
    /// Format in mangling:
    /// - Generic params: `x`, `q_`, `q0_`, etc. (first param, second, third...)
    /// - Constraints end with `l` (lowercase L)
    /// - Constraint markers:
    ///   - `Rz` - conformance requirement (T: Protocol)
    ///   - `Rs` - same-type requirement (T == Type)
    ///   - `Rl` - layout requirement (T: AnyObject)
    ///   - `Rb` - base class requirement (T: BaseClass)
    ///   - `R_` - general requirement prefix
    ///
    /// - Parameter mangled: The mangled string portion containing the generic signature.
    /// - Returns: A parsed `GenericSignature`, or nil if parsing fails.
    ///
    /// Example:
    /// ```
    /// // Container<T> where T: Hashable
    /// // Mangled: ...yxGSHRzl...
    /// let sig = demangleGenericSignature("SHRzl")
    /// // sig?.constraints == [DemangledConstraint(subject: "T", kind: .conformance, constraint: "Hashable")]
    /// ```
    public static func demangleGenericSignature(_ mangled: String) -> GenericSignature? {
        guard !mangled.isEmpty else { return nil }

        var input = Substring(mangled)
        var constraints: [DemangledConstraint] = []

        // Generate parameter names based on depth/index references found
        // Default to common names: T, U, V, W for first 4 params
        let paramNames = ["T", "U", "V", "W"]

        // Parse constraints until we hit 'l' (end of signature) or run out
        while !input.isEmpty {
            // Check for end of generic signature marker
            if input.hasPrefix("l") {
                input = input.dropFirst()
                break
            }

            // Check for multi-param marker (r0_, r1_, etc.)
            if input.hasPrefix("r") {
                input = input.dropFirst()
                // Skip parameter index
                while let c = input.first, c.isNumber || c == "_" {
                    input = input.dropFirst()
                }
                continue
            }

            // Parse constraint
            if let (constraint, rest) = parseGenericConstraint(input, paramNames: paramNames) {
                constraints.append(constraint)
                input = rest
            } else {
                // Try to skip unrecognized content
                input = input.dropFirst()
            }
        }

        return GenericSignature(
            parameters: Array(paramNames.prefix(max(1, constraints.count))),
            constraints: constraints
        )
    }

    /// Parse a single generic constraint from mangled input.
    ///
    /// - Parameters:
    ///   - input: The mangled input starting at a constraint marker.
    ///   - paramNames: Available parameter names to reference.
    /// - Returns: A parsed constraint and remaining input, or nil if not a constraint.
    private static func parseGenericConstraint(
        _ input: Substring,
        paramNames: [String]
    ) -> (DemangledConstraint, Substring)? {
        var remaining = input

        // Parse the protocol/type that forms the constraint first
        var protocolName: String?

        // Check for protocol shortcut (SH, SE, Sl, etc.)
        if remaining.count >= 2 {
            let twoChars = String(remaining.prefix(2))
            if let proto = protocolShortcuts[twoChars] {
                protocolName = proto
                remaining = remaining.dropFirst(2)
            } else if let typeName = commonPatterns[twoChars] {
                // Also check common type patterns (SS, Si, etc.)
                protocolName = typeName
                remaining = remaining.dropFirst(2)
            }
        }

        // Check for length-prefixed protocol name
        if protocolName == nil, let first = remaining.first, first.isNumber {
            if let (name, rest) = parseLengthPrefixed(remaining) {
                protocolName = name
                remaining = rest
                // Skip protocol suffix 'P'
                if remaining.hasPrefix("P") {
                    remaining = remaining.dropFirst()
                }
            }
        }

        // Check for Swift module protocol (s + length + name + P)
        if protocolName == nil, remaining.hasPrefix("s") {
            let afterS = remaining.dropFirst()
            if let first = afterS.first, first.isNumber {
                if let (name, rest) = parseLengthPrefixed(afterS) {
                    protocolName = name
                    remaining = rest
                    // Skip protocol suffix 'P'
                    if remaining.hasPrefix("P") {
                        remaining = remaining.dropFirst()
                    }
                }
            }
        }

        // Now look for requirement marker
        guard remaining.hasPrefix("R") else {
            // No requirement marker found
            return nil
        }

        remaining = remaining.dropFirst()  // Skip 'R'

        // Determine constraint kind
        guard let kindChar = remaining.first else {
            return nil
        }

        var kind: ConstraintKind
        var subject = paramNames.first ?? "T"  // Default to first param
        var constraintTarget = protocolName ?? "Unknown"

        switch kindChar {
        case "z":
            // Conformance requirement (T: Protocol)
            kind = .conformance
            remaining = remaining.dropFirst()

        case "s":
            // Same-type requirement (T == Type)
            kind = .sameType
            remaining = remaining.dropFirst()
            // For same-type, we need to parse the target type
            if let (typeName, rest) = parseConstraintType(remaining) {
                constraintTarget = typeName
                remaining = rest
            }

        case "l":
            // Layout requirement (T: AnyObject)
            kind = .layout
            remaining = remaining.dropFirst()
            constraintTarget = "AnyObject"

        case "b":
            // Base class requirement (T: BaseClass)
            kind = .baseClass
            remaining = remaining.dropFirst()
            if let (className, rest) = parseConstraintType(remaining) {
                constraintTarget = className
                remaining = rest
            }

        case "_":
            // Associated type constraint marker (deeper path)
            remaining = remaining.dropFirst()
            // Parse associated type path
            if let (path, rest) = parseAssociatedTypePath(remaining, baseParam: subject) {
                subject = path
                remaining = rest
            }
            kind = .conformance

        default:
            // Unknown requirement type, try to continue
            remaining = remaining.dropFirst()
            kind = .conformance
        }

        // Check for subject parameter override (underscore followed by index)
        if remaining.hasPrefix("_") {
            // This indicates a parameter index follows
            remaining = remaining.dropFirst()
        }

        return (
            DemangledConstraint(
                subject: subject,
                kind: kind,
                constraint: constraintTarget
            ),
            remaining
        )
    }

    /// Parse a type reference in a constraint.
    private static func parseConstraintType(_ input: Substring) -> (String, Substring)? {
        var remaining = input

        // Check for common type patterns
        if remaining.count >= 2 {
            let twoChars = String(remaining.prefix(2))
            if let typeName = commonPatterns[twoChars] {
                return (typeName, remaining.dropFirst(2))
            }
        }

        // Check for single-character shortcuts
        if let first = remaining.first, let typeName = typeShortcuts[first] {
            return (typeName, remaining.dropFirst())
        }

        // Check for length-prefixed type
        if let first = remaining.first, first.isNumber {
            if let (name, rest) = parseLengthPrefixed(remaining) {
                // Skip type suffix
                var r = rest
                while let c = r.first, "CVOPy_".contains(c) {
                    r = r.dropFirst()
                }
                return (name, r)
            }
        }

        // Check for ObjC imported type (So prefix)
        if remaining.hasPrefix("So") {
            remaining = remaining.dropFirst(2)
            if let (name, rest) = parseLengthPrefixed(remaining) {
                // Skip type suffix
                var r = rest
                while let c = r.first, "CVOPy_".contains(c) {
                    r = r.dropFirst()
                }
                return (name, r)
            }
        }

        // Check for Swift module type (s prefix)
        if remaining.hasPrefix("s") {
            let afterS = remaining.dropFirst()
            if let first = afterS.first, first.isNumber {
                if let (name, rest) = parseLengthPrefixed(afterS) {
                    // Skip type suffix
                    var r = rest
                    while let c = r.first, "CVOPy_".contains(c) {
                        r = r.dropFirst()
                    }
                    return (name, r)
                }
            }
        }

        return nil
    }

    /// Parse an associated type path (e.g., "T.Element").
    private static func parseAssociatedTypePath(
        _ input: Substring,
        baseParam: String
    ) -> (String, Substring)? {
        var remaining = input
        var path = baseParam

        // Look for associated type name
        if let first = remaining.first, first.isNumber {
            if let (assocName, rest) = parseLengthPrefixed(remaining) {
                path = "\(baseParam).\(assocName)"
                remaining = rest
            }
        } else if remaining.count >= 7, remaining.hasPrefix("Element") {
            path = "\(baseParam).Element"
            remaining = remaining.dropFirst(7)
        }

        return path != baseParam ? (path, remaining) : nil
    }

    /// Demangle a symbol that may contain generic constraints.
    ///
    /// This is a convenience method that extracts and formats the where clause
    /// from a mangled symbol if present.
    ///
    /// - Parameter mangled: The mangled symbol.
    /// - Returns: A tuple of (base demangled name, where clause) or nil.
    public static func demangleWithConstraints(_ mangled: String) -> (name: String, whereClause: String)? {
        // First get the basic demangled name
        let baseName = demangleSwiftName(mangled)

        // Look for constraint portion - typically after 'G' and before 'l'
        var input = Substring(mangled)

        // Skip to generic portion
        while !input.isEmpty && !input.hasPrefix("Rz") && !input.hasPrefix("Rs") && !input.hasPrefix("Rl")
            && !input.hasPrefix("Rb")
        {
            // Check if we're at the end or hit end-of-signature marker
            if input.hasPrefix("l") && input.count > 1 {
                break
            }
            input = input.dropFirst()
        }

        // If we found a constraint marker, try to parse from there
        if input.hasPrefix("R") {
            // Back up to include the protocol reference
            if let sig = demangleGenericSignature(String(mangled.dropFirst(mangled.count - input.count - 2))) {
                return (baseName, sig.whereClause)
            }
        }

        return (baseName, "")
    }
}

// MARK: - String Extension

extension String {
    /// Attempt to demangle this string as a Swift type name.
    public var swiftDemangled: String {
        SwiftDemangler.demangle(self)
    }
}
