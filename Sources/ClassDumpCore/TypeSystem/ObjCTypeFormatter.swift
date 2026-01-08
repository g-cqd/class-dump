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

    public init(
        baseLevel: Int = 0,
        spacesPerLevel: Int = 4,
        shouldExpand: Bool = false,
        shouldAutoExpand: Bool = false
    ) {
        self.baseLevel = baseLevel
        self.spacesPerLevel = spacesPerLevel
        self.shouldExpand = shouldExpand
        self.shouldAutoExpand = shouldAutoExpand
    }
}

/// Formatter for converting ObjCType to human-readable strings.
public struct ObjCTypeFormatter: Sendable {
    /// Formatting options
    public var options: ObjCTypeFormatterOptions

    /// Callback for referenced class names
    public var onClassNameReferenced: (@Sendable (String) -> Void)?

    /// Callback for referenced protocol names
    public var onProtocolNamesReferenced: (@Sendable ([String]) -> Void)?

    public init(options: ObjCTypeFormatterOptions = .init()) {
        self.options = options
    }

    // MARK: - Public API

    /// Format a type with an optional variable name.
    public func formatVariable(name: String?, type: ObjCType) -> String {
        format(type: type, previousName: name, level: 0)
    }

    /// Format a method signature from a type string.
    public func formatMethodName(_ name: String, typeString: String) -> String? {
        guard let methodTypes = try? ObjCType.parseMethodType(typeString),
            !methodTypes.isEmpty
        else {
            return nil
        }

        // First type is return type
        let returnType = methodTypes[0].type
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
                let paramType = paramTypes[paramTypes.startIndex + paramIndex].type
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

    // MARK: - Private Formatting

    private func format(type: ObjCType, previousName: String?, level: Int) -> String {
        let currentName = previousName

        // Report referenced protocols
        if case .id(_, let protocols) = type, !protocols.isEmpty {
            onProtocolNamesReferenced?(protocols)
        }

        switch type {
        case .id(let className, let protocols):
            onClassNameReferenced?(className ?? "")

            if let className = className {
                let protocolStr = protocols.isEmpty ? "" : "<\(protocols.joined(separator: ", "))>"
                if let name = currentName {
                    return "\(className)\(protocolStr) *\(name)"
                }
                return "\(className)\(protocolStr) *"
            } else {
                let protocolStr = protocols.isEmpty ? "" : " <\(protocols.joined(separator: ", "))>"
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
                return formatBlockSignature(types: types)
            }
            if let name = currentName {
                return "CDUnknownBlockType \(name)"
            }
            return "CDUnknownBlockType"

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

        let nameStr = typeName?.description
        if nameStr == nil || nameStr == "?" {
            baseType = keyword
        } else if let name = nameStr {
            baseType = "\(keyword) \(name)"
        } else {
            baseType = keyword
        }

        // Decide whether to expand
        let shouldExpandHere =
            (level == 0 && options.shouldExpand && !members.isEmpty) || (options.shouldAutoExpand && !members.isEmpty)

        if shouldExpandHere {
            let membersStr = formatMembers(members, level: level + 1)
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

    private func formatBlockSignature(types: [ObjCType]) -> String {
        guard !types.isEmpty else { return "CDUnknownBlockType" }

        var result = ""

        for (i, type) in types.enumerated() {
            if i == 0 {
                // Return type
                result += format(type: type, previousName: nil, level: 0)
                result += " "
            } else if i == 1 {
                // Block pointer itself
                result += "(^)"
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
