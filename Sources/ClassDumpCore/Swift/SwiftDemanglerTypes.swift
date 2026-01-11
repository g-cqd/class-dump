// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

// MARK: - Generic Constraint Types

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
///
/// This is an immutable value type representing a single constraint
/// in a generic signature's where clause.
public struct DemangledConstraint: Sendable, Equatable {
    /// The constrained type parameter (e.g., "T", "T.Element").
    public let subject: String
    /// The kind of constraint.
    public let kind: ConstraintKind
    /// The constraint target (protocol name, type name, or layout kind).
    public let constraint: String

    /// Create a new demangled constraint.
    ///
    /// - Parameters:
    ///   - subject: The constrained type parameter.
    ///   - kind: The kind of constraint.
    ///   - constraint: The constraint target.
    public init(subject: String, kind: ConstraintKind, constraint: String) {
        self.subject = subject
        self.kind = kind
        self.constraint = constraint
    }

    /// Format as Swift where clause component.
    ///
    /// Pure function that transforms this constraint into its string representation.
    public var description: String {
        switch kind {
            case .conformance, .baseClass, .layout:
                "\(subject): \(constraint)"
            case .sameType:
                "\(subject) == \(constraint)"
        }
    }
}

/// A parsed generic signature with constraints.
///
/// Immutable value type representing a complete generic signature
/// including all type parameters and their constraints.
public struct GenericSignature: Sendable, Equatable {
    /// Generic parameter names (e.g., ["T", "U"]).
    public let parameters: [String]
    /// Constraints on the generic parameters.
    public let constraints: [DemangledConstraint]

    /// Create a new generic signature.
    ///
    /// - Parameters:
    ///   - parameters: Generic parameter names.
    ///   - constraints: Constraints on the generic parameters.
    public init(parameters: [String], constraints: [DemangledConstraint]) {
        self.parameters = parameters
        self.constraints = constraints
    }

    /// Format as Swift where clause (empty string if no constraints).
    ///
    /// Pure function that transforms constraints into a where clause string.
    public var whereClause: String {
        guard !constraints.isEmpty else { return "" }
        return "where " + constraints.map(\.description).joined(separator: ", ")
    }
}

// MARK: - Closure/Function Type Types

/// Calling convention for closure types.
///
/// Represents the different calling conventions Swift supports for function types.
public enum ClosureConvention: Sendable, Equatable {
    /// Swift standard closure (thick, with context).
    case swift
    /// Objective-C block (`@convention(block)`).
    case block
    /// C function pointer (`@convention(c)`).
    case cFunction
    /// Thin function (no context, `@convention(thin)`).
    case thin

    /// The Swift attribute representation of this convention.
    ///
    /// Pure function returning the attribute string, or nil for default Swift convention.
    public var attribute: String? {
        switch self {
            case .swift: nil
            case .block: "@convention(block)"
            case .cFunction: "@convention(c)"
            case .thin: "@convention(thin)"
        }
    }
}

/// A parsed Swift closure/function type.
///
/// Immutable value type representing a complete function type signature
/// including parameters, return type, effects, and calling convention.
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

    /// Create a new closure type.
    ///
    /// - Parameters:
    ///   - parameterTypes: Parameter type names.
    ///   - returnType: Return type name.
    ///   - isEscaping: Whether the closure is escaping.
    ///   - isSendable: Whether the closure is @Sendable.
    ///   - isAsync: Whether the closure is async.
    ///   - isThrowing: Whether the closure throws.
    ///   - convention: Calling convention.
    public init(
        parameterTypes: [String],
        returnType: String,
        isEscaping: Bool,
        isSendable: Bool,
        isAsync: Bool,
        isThrowing: Bool,
        convention: ClosureConvention
    ) {
        self.parameterTypes = parameterTypes
        self.returnType = returnType
        self.isEscaping = isEscaping
        self.isSendable = isSendable
        self.isAsync = isAsync
        self.isThrowing = isThrowing
        self.convention = convention
    }

    /// Format as Swift-style closure declaration.
    ///
    /// Pure function transforming this closure type into Swift syntax.
    ///
    /// Examples:
    /// - `(String) -> Void`
    /// - `@escaping (Int, Int) -> Bool`
    /// - `@Sendable () async throws -> Data`
    /// - `@convention(block) (NSString) -> Void`
    public var swiftDeclaration: String {
        let attributeParts = buildAttributes()
        let functionPart = buildFunctionType()
        return (attributeParts + [functionPart]).joined(separator: " ")
    }

    /// Format as ObjC-style block declaration.
    ///
    /// Pure function transforming this closure type into Objective-C block syntax.
    ///
    /// Examples:
    /// - `void (^)(void)`
    /// - `BOOL (^)(NSString *, NSInteger)`
    public var objcBlockDeclaration: String {
        let returnStr = Self.mapToObjCType(returnType)
        let params =
            parameterTypes.isEmpty
            ? "void"
            : parameterTypes.map { Self.mapToObjCType($0) }.joined(separator: ", ")
        return "\(returnStr) (^)(\(params))"
    }

    // MARK: - Private Pure Functions

    private func buildAttributes() -> [String] {
        var parts: [String] = []

        if let attr = convention.attribute {
            parts.append(attr)
        }

        if isSendable {
            parts.append("@Sendable")
        }

        if isEscaping && convention == .swift {
            parts.append("@escaping")
        }

        return parts
    }

    private func buildFunctionType() -> String {
        let params =
            parameterTypes.isEmpty
            ? "()"
            : "(\(parameterTypes.joined(separator: ", ")))"

        var funcParts: [String] = [params]

        if isAsync { funcParts.append("async") }
        if isThrowing { funcParts.append("throws") }

        funcParts.append("->")
        funcParts.append(returnType)

        return funcParts.joined(separator: " ")
    }

    /// Map Swift type to ObjC equivalent for block declarations.
    ///
    /// Pure function for type conversion.
    private static func mapToObjCType(_ swiftType: String) -> String {
        switch swiftType {
            case "Void", "()":
                return "void"
            case "Bool":
                return "BOOL"
            case "Int":
                return "NSInteger"
            case "UInt":
                return "NSUInteger"
            case "Float":
                return "float"
            case "Double":
                return "double"
            case "String":
                return "NSString *"
            case "Data":
                return "NSData *"
            case "Array":
                return "NSArray *"
            case "Dictionary":
                return "NSDictionary *"
            case "Set":
                return "NSSet *"
            default:
                if swiftType.hasSuffix("?") {
                    let base = String(swiftType.dropLast())
                    return "\(mapToObjCType(base)) _Nullable"
                }
                return "\(swiftType) *"
        }
    }
}

// MARK: - Function Signature Types

/// A parsed Swift function signature.
///
/// Immutable value type representing a complete function signature
/// including module context, name, parameters, return type, and effects.
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

    /// Create a new function signature.
    ///
    /// - Parameters:
    ///   - moduleName: Module name where the function is defined.
    ///   - contextName: Context name (class/struct/enum for methods).
    ///   - functionName: Function name.
    ///   - parameterTypes: Parameter type names.
    ///   - returnType: Return type name.
    ///   - isAsync: Whether the function is async.
    ///   - isThrowing: Whether the function throws.
    ///   - isSendable: Whether the function is sendable.
    ///   - errorType: Error type for typed throws.
    public init(
        moduleName: String,
        contextName: String,
        functionName: String,
        parameterTypes: [String],
        returnType: String,
        isAsync: Bool,
        isThrowing: Bool,
        isSendable: Bool,
        errorType: String?
    ) {
        self.moduleName = moduleName
        self.contextName = contextName
        self.functionName = functionName
        self.parameterTypes = parameterTypes
        self.returnType = returnType
        self.isAsync = isAsync
        self.isThrowing = isThrowing
        self.isSendable = isSendable
        self.errorType = errorType
    }

    /// Format as Swift-style function declaration.
    ///
    /// Pure function transforming this signature into Swift syntax.
    public var swiftDeclaration: String {
        let params =
            parameterTypes.isEmpty
            ? "()"
            : "(\(parameterTypes.joined(separator: ", ")))"

        var parts: [String] = ["func \(functionName)\(params)"]

        if isAsync { parts.append("async") }

        if isThrowing {
            if let errorType {
                parts.append("throws(\(errorType))")
            }
            else {
                parts.append("throws")
            }
        }

        if returnType != "Void" && returnType != "()" {
            parts.append("-> \(returnType)")
        }

        return parts.joined(separator: " ")
    }

    /// Format as ObjC-style method declaration.
    ///
    /// Pure function transforming this signature into Objective-C syntax.
    public var objcDeclaration: String {
        let returnStr = returnType == "Void" || returnType == "()" ? "void" : returnType
        let params = parameterTypes.isEmpty ? "" : ":\(parameterTypes.joined(separator: " :"))"
        return "- (\(returnStr))\(functionName)\(params)"
    }
}

// MARK: - Parse Result Types

/// Result of parsing a closure type's components.
///
/// Immutable value type holding all parsed closure components.
public struct ClosureParseResult: Sendable, Equatable {
    /// Parameter types.
    public let params: [String]
    /// Return type.
    public let returnType: String
    /// Whether the closure is async.
    public let isAsync: Bool
    /// Whether the closure throws.
    public let isThrowing: Bool
    /// Whether the closure is @Sendable.
    public let isSendable: Bool

    /// Create a new closure parse result.
    ///
    /// - Parameters:
    ///   - params: Parameter types.
    ///   - returnType: Return type.
    ///   - isAsync: Whether the closure is async.
    ///   - isThrowing: Whether the closure throws.
    ///   - isSendable: Whether the closure is @Sendable.
    public init(
        params: [String] = [],
        returnType: String = "Void",
        isAsync: Bool = false,
        isThrowing: Bool = false,
        isSendable: Bool = false
    ) {
        self.params = params
        self.returnType = returnType
        self.isAsync = isAsync
        self.isThrowing = isThrowing
        self.isSendable = isSendable
    }
}

/// Result of parsing a function signature's components.
///
/// Immutable value type holding all parsed function signature components.
public struct FunctionSignatureParseResult: Sendable, Equatable {
    /// Parameter types.
    public let params: [String]
    /// Return type.
    public let returnType: String
    /// Whether the function is async.
    public let isAsync: Bool
    /// Whether the function throws.
    public let isThrowing: Bool
    /// Whether the function is @Sendable.
    public let isSendable: Bool
    /// Error type for typed throws (nil for untyped throws).
    public let errorType: String?

    /// Create a new function signature parse result.
    ///
    /// - Parameters:
    ///   - params: Parameter types.
    ///   - returnType: Return type.
    ///   - isAsync: Whether the function is async.
    ///   - isThrowing: Whether the function throws.
    ///   - isSendable: Whether the function is @Sendable.
    ///   - errorType: Error type for typed throws.
    public init(
        params: [String] = [],
        returnType: String = "Void",
        isAsync: Bool = false,
        isThrowing: Bool = false,
        isSendable: Bool = false,
        errorType: String? = nil
    ) {
        self.params = params
        self.returnType = returnType
        self.isAsync = isAsync
        self.isThrowing = isThrowing
        self.isSendable = isSendable
        self.errorType = errorType
    }
}
