import Foundation

/// Options for type formatting.
public struct ObjCTypeFormatterOptions: Sendable {
    /// Base indentation level
    public var baseLevel: Int = 0

    /// Number of spaces per indentation level
    public var spacesPerLevel: Int = 4

    /// Whether to expand struct/union members
    public var shouldExpand: Bool = false

    /// Whether to auto-expand certain types
    public var shouldAutoExpand: Bool = false

    /// Style for demangling Swift names in type references
    public var demangleStyle: DemangleStyle = .swift

    /// Output style for type formatting (objc or swift)
    public var outputStyle: OutputStyle = .objc

    public init(
        baseLevel: Int = 0,
        spacesPerLevel: Int = 4,
        shouldExpand: Bool = false,
        shouldAutoExpand: Bool = false,
        demangleStyle: DemangleStyle = .swift,
        outputStyle: OutputStyle = .objc
    ) {
        self.baseLevel = baseLevel
        self.spacesPerLevel = spacesPerLevel
        self.shouldExpand = shouldExpand
        self.shouldAutoExpand = shouldAutoExpand
        self.demangleStyle = demangleStyle
        self.outputStyle = outputStyle
    }
}

/// Formatter for converting ObjCType to human-readable strings.
public struct ObjCTypeFormatter: Sendable {
    /// Formatting options
    public var options: ObjCTypeFormatterOptions

    /// Optional registry for resolving forward-declared structures
    public var structureRegistry: StructureRegistry?

    /// Optional registry for looking up richer method signatures (especially for blocks)
    public var methodSignatureRegistry: MethodSignatureRegistry?

    /// Callback for referenced class names
    public var onClassNameReferenced: (@Sendable (String) -> Void)?

    /// Callback for referenced protocol names
    public var onProtocolNamesReferenced: (@Sendable ([String]) -> Void)?

    /// Callback for referenced structure names (name, isForwardDeclared)
    public var onStructureReferenced: (@Sendable (String, Bool) -> Void)?

    public init(
        options: ObjCTypeFormatterOptions = .init(),
        structureRegistry: StructureRegistry? = nil,
        methodSignatureRegistry: MethodSignatureRegistry? = nil
    ) {
        self.options = options
        self.structureRegistry = structureRegistry
        self.methodSignatureRegistry = methodSignatureRegistry
    }

    // MARK: - Demangling Helpers

    /// Demangle a Swift name according to the configured style.
    private func demangleName(_ name: String) -> String {
        var result: String
        switch options.demangleStyle {
        case .none:
            result = name
        case .swift:
            result = SwiftDemangler.demangleSwiftName(name)
        case .objc:
            let demangled = SwiftDemangler.demangleSwiftName(name)
            // Strip module prefix for ObjC style
            if let lastDot = demangled.lastIndex(of: ".") {
                result = String(demangled[demangled.index(after: lastDot)...])
            } else {
                result = demangled
            }
        }

        // Convert Swift syntax to ObjC if in ObjC output mode
        if options.outputStyle == .objc {
            result = convertSwiftSyntaxToObjC(result)
        }

        return result
    }

    /// Convert Swift-style type syntax to Objective-C syntax.
    ///
    /// This handles:
    /// - `[Type]` → `NSArray`
    /// - `[Key: Value]` → `NSDictionary`
    /// - `Set<Type>` → `NSSet`
    /// - `Type?` → `Type` (optionality represented by pointer)
    private func convertSwiftSyntaxToObjC(_ typeName: String) -> String {
        var result = typeName

        // Handle Swift optional suffix: Type? → Type
        if result.hasSuffix("?") {
            result = String(result.dropLast())
        }

        // Handle Swift Array syntax: [Type] → NSArray
        if result.hasPrefix("[") && result.hasSuffix("]") && !result.contains(":") {
            return "NSArray"
        }

        // Handle Swift Dictionary syntax: [Key: Value] → NSDictionary
        if result.hasPrefix("[") && result.hasSuffix("]") && result.contains(":") {
            return "NSDictionary"
        }

        // Handle Swift Set syntax: Set<Type> → NSSet
        if result.hasPrefix("Set<") && result.hasSuffix(">") {
            return "NSSet"
        }

        // Handle Swift Array syntax with generic: Array<Type> → NSArray
        if result.hasPrefix("Array<") && result.hasSuffix(">") {
            return "NSArray"
        }

        // Handle Swift Dictionary syntax with generic: Dictionary<K, V> → NSDictionary
        if result.hasPrefix("Dictionary<") && result.hasSuffix(">") {
            return "NSDictionary"
        }

        return result
    }

    // MARK: - Public API

    /// Format a type with an optional variable name.
    public func formatVariable(name: String?, type: ObjCType) -> String {
        format(type: type, previousName: name, level: 0)
    }

    /// Format a method signature from a type string (ObjC style).
    public func formatMethodName(_ name: String, typeString: String) -> String? {
        guard let methodTypes = try? ObjCType.parseMethodType(typeString),
            !methodTypes.isEmpty
        else {
            return nil
        }

        // First type is return type
        let returnType = enhanceBlockType(methodTypes[0].type, selector: name, argumentIndex: -1)
        let returnString = format(type: returnType, previousName: nil, level: 0)

        // Skip self and _cmd (indices 1 and 2)
        let paramTypes = methodTypes.dropFirst(3)

        // Parse the selector into parts
        let selectorParts = name.split(separator: ":")

        if selectorParts.isEmpty {
            // No arguments
            return "(\(returnString))\(name)"
        }

        var result = "(\(returnString))"
        var paramIndex = 0

        for (i, part) in selectorParts.enumerated() {
            if i > 0 {
                result += " "
            }
            result += String(part)

            if paramIndex < paramTypes.count {
                var paramType = paramTypes[paramTypes.startIndex + paramIndex].type
                // Try to enhance empty block types using the registry
                paramType = enhanceBlockType(paramType, selector: name, argumentIndex: paramIndex)
                let paramString = format(type: paramType, previousName: nil, level: 0)
                result += ":(\(paramString))arg\(paramIndex + 1)"
                paramIndex += 1
            } else if i < selectorParts.count - 1 || name.hasSuffix(":") {
                result += ":(id)arg\(paramIndex + 1)"
                paramIndex += 1
            }
        }

        return result
    }

    /// Enhance a block type by looking up a richer signature in the registry.
    ///
    /// If the type is a block without a signature (e.g., `@?` parsed as `.block(types: nil)`),
    /// this tries to find a richer signature from protocol methods with the same selector.
    ///
    /// - Parameters:
    ///   - type: The type to potentially enhance.
    ///   - selector: The method selector name.
    ///   - argumentIndex: The argument index (0-based), or -1 for return type.
    /// - Returns: The original type or an enhanced block type with full signature.
    private func enhanceBlockType(_ type: ObjCType, selector: String, argumentIndex: Int) -> ObjCType {
        // Only enhance blocks without signatures
        guard case .block(let existingTypes) = type else { return type }

        // If already has a full signature, keep it
        if let types = existingTypes, !types.isEmpty {
            return type
        }

        // Try to look up a richer signature from the registry
        guard let registry = methodSignatureRegistry else { return type }

        // For return types (argumentIndex == -1), we'd need a different lookup
        // For now, focus on parameter types
        guard argumentIndex >= 0 else { return type }

        if let richBlockTypes = registry.blockSignature(forSelector: selector, argumentIndex: argumentIndex) {
            return .block(types: richBlockTypes)
        }

        return type
    }

    /// Format a method signature in Swift style.
    ///
    /// Converts ObjC selector format to Swift function syntax:
    /// - `initWithFrame:backgroundColor:` → `func initWithFrame(_ arg1: CGRect, backgroundColor arg2: UIColor)`
    /// - Unary methods like `count` → `func count() -> Int`
    ///
    /// - Parameters:
    ///   - name: The ObjC selector name.
    ///   - typeString: The encoded type string.
    ///   - isClassMethod: Whether this is a class method (uses `static`/`class`).
    /// - Returns: A Swift-style method declaration string, or nil if parsing fails.
    public func formatSwiftMethodName(_ name: String, typeString: String, isClassMethod: Bool = false) -> String? {
        guard let methodTypes = try? ObjCType.parseMethodType(typeString),
            !methodTypes.isEmpty
        else {
            return nil
        }

        // First type is return type
        let returnType = enhanceBlockType(methodTypes[0].type, selector: name, argumentIndex: -1)
        var returnString = format(type: returnType, previousName: nil, level: 0)

        // Simplify pointer types for Swift display
        returnString = simplifyTypeForSwift(returnString)

        // Skip self and _cmd (indices 1 and 2)
        let paramTypes = Array(methodTypes.dropFirst(3))

        // Parse the selector into parts
        let selectorParts = name.split(separator: ":")

        // Build prefix
        let prefix = isClassMethod ? "class func " : "func "

        // Handle unary methods (no arguments)
        if selectorParts.isEmpty || (!name.contains(":") && selectorParts.count == 1) {
            let funcName = String(selectorParts.first ?? Substring(name))
            if returnString == "void" {
                return "\(prefix)\(funcName)()"
            }
            return "\(prefix)\(funcName)() -> \(returnString)"
        }

        // Build Swift-style parameter list
        var params: [String] = []
        for (i, part) in selectorParts.enumerated() {
            let label = String(part)

            // Get parameter type (with block enhancement)
            var paramTypeStr: String
            if i < paramTypes.count {
                var paramType = paramTypes[i].type
                paramType = enhanceBlockType(paramType, selector: name, argumentIndex: i)
                paramTypeStr = format(type: paramType, previousName: nil, level: 0)
                paramTypeStr = simplifyTypeForSwift(paramTypeStr)
            } else {
                paramTypeStr = "Any"
            }

            // Swift convention: first part often has no external label
            if i == 0 {
                // Use _ for first parameter external label (common Swift pattern)
                params.append("_ \(label): \(paramTypeStr)")
            } else {
                // Subsequent parts: selector part is both external and internal label
                params.append("\(label) arg\(i + 1): \(paramTypeStr)")
            }
        }

        // Build final declaration
        let funcName = String(selectorParts[0])
        let paramsStr = params.joined(separator: ", ")

        if returnString == "void" {
            return "\(prefix)\(funcName)(\(paramsStr))"
        }
        return "\(prefix)\(funcName)(\(paramsStr)) -> \(returnString)"
    }

    /// Simplify ObjC type strings for Swift-style display.
    private func simplifyTypeForSwift(_ typeStr: String) -> String {
        var result = typeStr

        // Remove pointer asterisks from object types (Swift doesn't show them)
        if result.hasSuffix(" *") {
            result = String(result.dropLast(2))
        }
        if result.hasSuffix("*") {
            result = String(result.dropLast(1))
        }

        // Map common ObjC types to Swift equivalents
        switch result {
        case "id":
            return "Any"
        case "Class":
            return "AnyClass"
        case "_Bool":
            return "Bool"
        case "SEL":
            return "Selector"
        case "NSInteger":
            return "Int"
        case "NSUInteger":
            return "UInt"
        case "CGFloat":
            return "CGFloat"
        case "NSString":
            return "String"
        case "NSArray":
            return "[Any]"
        case "NSDictionary":
            return "[AnyHashable: Any]"
        case "NSSet":
            return "Set<AnyHashable>"
        default:
            return result
        }
    }

    // MARK: - Private Formatting

    private func format(type: ObjCType, previousName: String?, level: Int) -> String {
        let currentName = previousName

        // Report referenced protocols
        if case .id(_, let protocols) = type, !protocols.isEmpty {
            onProtocolNamesReferenced?(protocols)
        }

        switch type {
        case .id(let className, let protocols):
            if let className = className {
                onClassNameReferenced?(className)
            }

            if let className = className {
                // Demangle Swift class names for display
                let displayName = demangleName(className)

                // In ObjC output mode, convert Swift.AnyObject and AnyObject to id
                if options.outputStyle == .objc
                    && (displayName == "AnyObject" || displayName == "Swift.AnyObject" || className == "Swift.AnyObject"
                        || className == "AnyObject")
                {
                    // Demangle protocol names even when no class name
                    let demangledProtocols = protocols.map { demangleName($0) }
                    let protocolStr =
                        demangledProtocols.isEmpty ? "" : " <\(demangledProtocols.joined(separator: ", "))>"
                    if let name = currentName {
                        return "id\(protocolStr) \(name)"
                    }
                    return "id\(protocolStr)"
                }

                // Also demangle any Swift protocol names
                let demangledProtocols = protocols.map { demangleName($0) }
                let protocolStr =
                    demangledProtocols.isEmpty ? "" : "<\(demangledProtocols.joined(separator: ", "))>"
                if let name = currentName {
                    return "\(displayName)\(protocolStr) *\(name)"
                }
                return "\(displayName)\(protocolStr) *"
            } else {
                // Demangle protocol names even when no class name
                let demangledProtocols = protocols.map { demangleName($0) }
                let protocolStr = demangledProtocols.isEmpty ? "" : " <\(demangledProtocols.joined(separator: ", "))>"
                if let name = currentName {
                    return "id\(protocolStr) \(name)"
                }
                return "id\(protocolStr)"
            }

        case .bitfield(let size):
            if let name = currentName {
                return "unsigned int \(name):\(size)"
            }
            return "unsigned int :\(size)"

        case .array(let count, let elementType):
            let arrayPart: String
            if let name = currentName {
                arrayPart = "\(name)[\(count)]"
            } else {
                arrayPart = "[\(count)]"
            }
            return format(type: elementType, previousName: arrayPart, level: level)

        case .structure(let typeName, let members):
            return formatStructOrUnion(
                keyword: "struct",
                typeName: typeName,
                members: members,
                currentName: currentName,
                level: level
            )

        case .union(let typeName, let members):
            return formatStructOrUnion(
                keyword: "union",
                typeName: typeName,
                members: members,
                currentName: currentName,
                level: level
            )

        case .pointer(let pointee):
            let ptrPart: String
            if let name = currentName {
                ptrPart = "*\(name)"
            } else {
                ptrPart = "*"
            }

            // Wrap in parens if pointing to array
            if case .array = pointee {
                return format(type: pointee, previousName: "(\(ptrPart))", level: level)
            }
            return format(type: pointee, previousName: ptrPart, level: level)

        case .functionPointer:
            if let name = currentName {
                return "CDUnknownFunctionPointerType \(name)"
            }
            return "CDUnknownFunctionPointerType"

        case .block(let types):
            if let types = types, !types.isEmpty {
                return formatBlockSignature(types: types, variableName: currentName)
            }
            // No signature information available - show as block with unknown parameters
            // This is cleaner than "CDUnknownBlockType" which is a non-existent typedef
            if let name = currentName {
                return "id /* block */ \(name)"
            }
            return "id /* block */"

        case .const(let subtype), .in(let subtype), .inout(let subtype),
            .out(let subtype), .bycopy(let subtype), .byref(let subtype),
            .oneway(let subtype), .complex(let subtype), .atomic(let subtype):
            let modifierName = simpleTypeName(for: type)
            if let sub = subtype {
                return "\(modifierName) \(format(type: sub, previousName: currentName, level: level))"
            }
            if let name = currentName {
                return "\(modifierName) \(name)"
            }
            return modifierName

        default:
            let typeName = simpleTypeName(for: type)
            if let name = currentName {
                return "\(typeName) \(name)"
            }
            return typeName
        }
    }

    private func formatStructOrUnion(
        keyword: String,
        typeName: ObjCTypeName?,
        members: [ObjCTypedMember],
        currentName: String?,
        level: Int
    ) -> String {
        var baseType: String
        var resolvedMembers = members

        let nameStr = typeName?.description
        let isForwardDeclared = members.isEmpty && nameStr != nil && nameStr != "?"

        // Try to resolve forward-declared structures using the registry
        if isForwardDeclared, let name = nameStr, let registry = structureRegistry {
            let forwardType: ObjCType =
                keyword == "struct"
                ? .structure(name: ObjCTypeName(name: name), members: [])
                : .union(name: ObjCTypeName(name: name), members: [])
            let resolved = registry.resolve(forwardType)

            // Extract resolved members if available
            switch resolved {
            case .structure(_, let newMembers), .union(_, let newMembers):
                if !newMembers.isEmpty {
                    resolvedMembers = newMembers
                }
            default:
                break
            }
        }

        // Report structure reference
        if let name = nameStr, name != "?" {
            onStructureReferenced?(name, resolvedMembers.isEmpty)
        }

        if nameStr == nil || nameStr == "?" {
            baseType = keyword
        } else if let name = nameStr {
            baseType = "\(keyword) \(name)"
        } else {
            baseType = keyword
        }

        // Decide whether to expand
        let shouldExpandHere =
            (level == 0 && options.shouldExpand && !resolvedMembers.isEmpty)
            || (options.shouldAutoExpand && !resolvedMembers.isEmpty)

        if shouldExpandHere {
            let membersStr = formatMembers(resolvedMembers, level: level + 1)
            let indent = String(repeating: " ", count: (options.baseLevel + level) * options.spacesPerLevel)
            baseType += " {\n\(membersStr)\(indent)}"
        }

        if let name = currentName {
            return "\(baseType) \(name)"
        }
        return baseType
    }

    private func formatMembers(_ members: [ObjCTypedMember], level: Int) -> String {
        var result = ""
        let indent = String(repeating: " ", count: (options.baseLevel + level) * options.spacesPerLevel)

        for member in members {
            let memberStr = format(type: member.type, previousName: member.name, level: level)
            result += "\(indent)\(memberStr);\n"
        }

        return result
    }

    private func formatBlockSignature(types: [ObjCType], variableName: String? = nil) -> String {
        guard !types.isEmpty else {
            if let name = variableName {
                return "id /* block */ \(name)"
            }
            return "id /* block */"
        }

        var result = ""

        for (i, type) in types.enumerated() {
            if i == 0 {
                // Return type
                result += format(type: type, previousName: nil, level: 0)
                result += " "
            } else if i == 1 {
                // Block pointer itself - include variable name if provided
                if let name = variableName {
                    result += "(^\(name))"
                } else {
                    result += "(^)"
                }
                result += "("
            } else {
                // Parameter types
                if i > 2 {
                    result += ", "
                }
                result += format(type: type, previousName: nil, level: 0)
            }
        }

        // Close parameters
        if types.count == 2 {
            result += "void)"
        } else if types.count > 2 {
            result += ")"
        }

        return result
    }

    private func simpleTypeName(for type: ObjCType) -> String {
        switch type {
        case .char: return "char"
        case .int: return "int"
        case .short: return "short"
        case .long: return "long"
        case .longLong: return "long long"
        case .unsignedChar: return "unsigned char"
        case .unsignedInt: return "unsigned int"
        case .unsignedShort: return "unsigned short"
        case .unsignedLong: return "unsigned long"
        case .unsignedLongLong: return "unsigned long long"
        case .float: return "float"
        case .double: return "double"
        case .longDouble: return "long double"
        case .bool: return "_Bool"
        case .void: return "void"
        case .cString: return "char *"
        case .objcClass: return "Class"
        case .selector: return "SEL"
        case .unknown: return "void"
        case .atom: return "NXAtom"
        case .int128: return "__int128"
        case .unsignedInt128: return "unsigned __int128"
        case .const: return "const"
        case .in: return "in"
        case .inout: return "inout"
        case .out: return "out"
        case .bycopy: return "bycopy"
        case .byref: return "byref"
        case .oneway: return "oneway"
        case .complex: return "_Complex"
        case .atomic: return "_Atomic"
        default: return "void"
        }
    }
}

// MARK: - Convenience Extensions

extension ObjCType {
    /// Format this type as a human-readable string.
    public func formatted(variableName: String? = nil, options: ObjCTypeFormatterOptions = .init()) -> String {
        let formatter = ObjCTypeFormatter(options: options)
        return formatter.formatVariable(name: variableName, type: self)
    }
}
