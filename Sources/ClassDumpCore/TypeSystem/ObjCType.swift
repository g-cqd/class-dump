import Foundation

/// Represents a parsed Objective-C type encoding.
///
/// ObjC type encodings are strings like "i" (int), "@" (id), "{CGRect=dddd}" (struct).
/// This type provides a structured representation that can be formatted for output.
public indirect enum ObjCType: Sendable, Equatable {
    // MARK: - Primitive Types

    /// Signed char (c).
    case char
    /// Signed int (i).
    case int
    /// Signed short (s).
    case short
    /// Signed long (l).
    case long
    /// Signed long long (q).
    case longLong
    /// Unsigned char (C).
    case unsignedChar
    /// Unsigned int (I).
    case unsignedInt
    /// Unsigned short (S).
    case unsignedShort
    /// Unsigned long (L).
    case unsignedLong
    /// Unsigned long long (Q).
    case unsignedLongLong
    /// Float (f).
    case float
    /// Double (d).
    case double
    /// Long double (D).
    case longDouble
    /// C99 _Bool or C++ bool (B).
    case bool
    /// Void (v).
    case void
    /// C string / char* (*).
    case cString
    /// Objective-C Class (#).
    case objcClass
    /// Objective-C SEL (:).
    case selector
    /// Unknown/void (?).
    case unknown
    /// NXAtom (%).
    case atom
    /// Signed 128-bit integer __int128 (t).
    case int128
    /// Unsigned 128-bit integer unsigned __int128 (T).
    case unsignedInt128

    // MARK: - Complex Types

    /// id type, optionally with a class name and/or protocols.
    case id(className: String?, protocols: [String])
    /// Pointer to another type (^).
    case pointer(ObjCType)
    /// Array with count and element type ([count type]).
    case array(count: String, elementType: ObjCType)
    /// Struct with optional name and members ({name=members}).
    case structure(name: ObjCTypeName?, members: [ObjCTypedMember])
    /// Union with optional name and members ((name=members)).
    case union(name: ObjCTypeName?, members: [ObjCTypedMember])
    /// Bitfield with size (bN).
    case bitfield(size: String)
    /// Function pointer (^?).
    case functionPointer
    /// Block type with optional signature (@?).
    case block(types: [ObjCType]?)

    // MARK: - Modifiers

    /// const modifier (r).
    case const(ObjCType?)
    /// in modifier (n).
    case `in`(ObjCType?)
    /// inout modifier (N).
    case `inout`(ObjCType?)
    /// out modifier (o).
    case out(ObjCType?)
    /// bycopy modifier (O).
    case bycopy(ObjCType?)
    /// byref modifier (R).
    case byref(ObjCType?)
    /// oneway modifier (V).
    case oneway(ObjCType?)
    /// _Complex modifier (j).
    case complex(ObjCType?)
    /// _Atomic modifier (A).
    case atomic(ObjCType?)

    // MARK: - Initialization

    /// Create a type from a single-character primitive type code.
    public static func primitive(from code: Character) -> ObjCType? {
        switch code {
            case "c": return .char
            case "i": return .int
            case "s": return .short
            case "l": return .long
            case "q": return .longLong
            case "C": return .unsignedChar
            case "I": return .unsignedInt
            case "S": return .unsignedShort
            case "L": return .unsignedLong
            case "Q": return .unsignedLongLong
            case "f": return .float
            case "d": return .double
            case "D": return .longDouble
            case "B": return .bool
            case "v": return .void
            case "*": return .cString
            case "#": return .objcClass
            case ":": return .selector
            case "?": return .unknown
            case "%": return .atom
            case "t": return .int128
            case "T": return .unsignedInt128
            default: return nil
        }
    }

    // MARK: - Properties

    /// Whether this is an id type (@ without a class name).
    public var isIDType: Bool {
        if case .id(className: nil, protocols: _) = self { return true }
        return false
    }

    /// Whether this is a named object type (@ with a class name).
    public var isNamedObject: Bool {
        if case .id(className: let name?, protocols: _) = self { return !name.isEmpty }
        return false
    }

    /// Whether this is a modifier type.
    public var isModifier: Bool {
        switch self {
            case .const, .in, .inout, .out, .bycopy, .byref, .oneway, .complex, .atomic:
                return true
            default:
                return false
        }
    }

    /// The underlying type, ignoring modifiers.
    public var typeIgnoringModifiers: ObjCType {
        switch self {
            case .const(let t), .in(let t), .inout(let t), .out(let t),
                .bycopy(let t), .byref(let t), .oneway(let t), .complex(let t), .atomic(let t):
                return t?.typeIgnoringModifiers ?? self
            default:
                return self
        }
    }

    /// The depth of nested structures/unions.
    public var structureDepth: Int {
        switch self {
            case .pointer(let t), .array(_, let t):
                return t.structureDepth
            case .const(let t), .in(let t), .inout(let t), .out(let t),
                .bycopy(let t), .byref(let t), .oneway(let t), .complex(let t), .atomic(let t):
                return t?.structureDepth ?? 0
            case .structure(_, let members), .union(_, let members):
                let maxDepth = members.map { $0.type.structureDepth }.max() ?? 0
                return maxDepth + 1
            default:
                return 0
        }
    }

    // MARK: - Type String Generation

    /// Generate the encoded type string representation.
    public var typeString: String {
        typeString(includeVariableNames: true, showObjectTypes: true)
    }

    /// Generate the bare type string (no variable names).
    public var bareTypeString: String {
        typeString(includeVariableNames: false, showObjectTypes: true)
    }

    private func typeString(includeVariableNames: Bool, showObjectTypes: Bool) -> String {
        switch self {
            case .char: return "c"
            case .int: return "i"
            case .short: return "s"
            case .long: return "l"
            case .longLong: return "q"
            case .unsignedChar: return "C"
            case .unsignedInt: return "I"
            case .unsignedShort: return "S"
            case .unsignedLong: return "L"
            case .unsignedLongLong: return "Q"
            case .float: return "f"
            case .double: return "d"
            case .longDouble: return "D"
            case .bool: return "B"
            case .void: return "v"
            case .cString: return "*"
            case .objcClass: return "#"
            case .selector: return ":"
            case .unknown: return "?"
            case .atom: return "%"
            case .int128: return "t"
            case .unsignedInt128: return "T"

            case .id(let className, _):
                if showObjectTypes, let name = className {
                    return "@\"\(name)\""
                }
                return "@"

            case .pointer(let t):
                return "^\(t.typeString(includeVariableNames: includeVariableNames, showObjectTypes: showObjectTypes))"

            case .array(let count, let t):
                return
                    "[\(count)\(t.typeString(includeVariableNames: includeVariableNames, showObjectTypes: showObjectTypes))]"

            case .structure(let name, let members):
                if members.isEmpty {
                    return "{\(name?.description ?? "?")}"
                }
                let membersStr =
                    members.map { m -> String in
                        var s = ""
                        if includeVariableNames, let varName = m.name {
                            s += "\"\(varName)\""
                        }
                        s += m.type.typeString(
                            includeVariableNames: includeVariableNames,
                            showObjectTypes: showObjectTypes
                        )
                        return s
                    }
                    .joined()
                if let name = name {
                    return "{\(name)=\(membersStr)}"
                }
                return "{\(membersStr)}"

            case .union(let name, let members):
                if members.isEmpty {
                    return "(\(name?.description ?? "?"))"
                }
                let membersStr =
                    members.map { m -> String in
                        var s = ""
                        if includeVariableNames, let varName = m.name {
                            s += "\"\(varName)\""
                        }
                        s += m.type.typeString(
                            includeVariableNames: includeVariableNames,
                            showObjectTypes: showObjectTypes
                        )
                        return s
                    }
                    .joined()
                if let name = name {
                    return "(\(name)=\(membersStr))"
                }
                return "(\(membersStr))"

            case .bitfield(let size):
                return "b\(size)"

            case .functionPointer:
                return "^?"

            case .block:
                return "@?"

            case .const(let t):
                return
                    "r\(t?.typeString(includeVariableNames: includeVariableNames, showObjectTypes: showObjectTypes) ?? "")"
            case .`in`(let t):
                return
                    "n\(t?.typeString(includeVariableNames: includeVariableNames, showObjectTypes: showObjectTypes) ?? "")"
            case .`inout`(let t):
                return
                    "N\(t?.typeString(includeVariableNames: includeVariableNames, showObjectTypes: showObjectTypes) ?? "")"
            case .out(let t):
                return
                    "o\(t?.typeString(includeVariableNames: includeVariableNames, showObjectTypes: showObjectTypes) ?? "")"
            case .bycopy(let t):
                return
                    "O\(t?.typeString(includeVariableNames: includeVariableNames, showObjectTypes: showObjectTypes) ?? "")"
            case .byref(let t):
                return
                    "R\(t?.typeString(includeVariableNames: includeVariableNames, showObjectTypes: showObjectTypes) ?? "")"
            case .oneway(let t):
                return
                    "V\(t?.typeString(includeVariableNames: includeVariableNames, showObjectTypes: showObjectTypes) ?? "")"
            case .complex(let t):
                return
                    "j\(t?.typeString(includeVariableNames: includeVariableNames, showObjectTypes: showObjectTypes) ?? "")"
            case .atomic(let t):
                return
                    "A\(t?.typeString(includeVariableNames: includeVariableNames, showObjectTypes: showObjectTypes) ?? "")"
        }
    }
}

// MARK: - ObjCTypedMember

/// A struct/union member with an optional variable name.
public struct ObjCTypedMember: Sendable, Equatable {
    /// The type of the member.
    public let type: ObjCType

    /// The optional variable name.
    public let name: String?

    /// Initialize a typed member.
    public init(type: ObjCType, name: String? = nil) {
        self.type = type
        self.name = name
    }
}

// MARK: - ObjCTypeName

/// Represents a type name, possibly with C++ template parameters.
public struct ObjCTypeName: Sendable, Equatable, CustomStringConvertible {
    /// The base name.
    public var name: String

    /// Template type parameters (for C++ templates).
    public var templateTypes: [ObjCTypeName]

    /// Suffix after template parameters.
    public var suffix: String?

    /// Initialize a type name.
    public init(name: String = "?", templateTypes: [ObjCTypeName] = [], suffix: String? = nil) {
        self.name = name
        self.templateTypes = templateTypes
        self.suffix = suffix
    }

    /// Whether this is a template type.
    public var isTemplateType: Bool {
        !templateTypes.isEmpty
    }

    /// A textual description of the type name.
    public var description: String {
        var result = name
        if !templateTypes.isEmpty {
            result += "<\(templateTypes.map(\.description).joined(separator: ", "))>"
        }
        if let suffix = suffix {
            result += suffix
        }
        return result
    }
}

// MARK: - ObjCMethodType

/// Represents a single type in a method signature, with its stack offset.
public struct ObjCMethodType: Sendable, Equatable {
    /// The type.
    public let type: ObjCType

    /// The stack offset (as a string, since it may be empty).
    public let offset: String?

    /// Initialize a method type.
    public init(type: ObjCType, offset: String? = nil) {
        self.type = type
        self.offset = offset
    }
}
