import Foundation

/// Errors that can occur during type parsing.
public enum ObjCTypeParserError: Error, Sendable {
    case syntaxError(String, remaining: String)
    case unexpectedToken(expected: String, got: String, remaining: String)
    case unexpectedEndOfInput
}

/// Parser for Objective-C type encoding strings.
///
/// Parses type encodings like "i" (int), "@\"NSString\"" (NSString*),
/// "{CGRect=\"origin\"{CGPoint=\"x\"d\"y\"d}\"size\"{CGSize=\"width\"d\"height\"d}}" (CGRect struct).
public final class ObjCTypeParser: @unchecked Sendable {
    /// The lexer used for tokenization.
    public let lexer: ObjCTypeLexer

    /// Current lookahead token.
    private var lookahead: ObjCTypeToken = .eos

    /// Initialize with a type encoding string.
    public init(string: String) {
        self.lexer = ObjCTypeLexer(string: string)
    }

    // MARK: - Public API

    /// Parse a method type string (return type + arguments with offsets).
    public func parseMethodType() throws -> [ObjCMethodType] {
        lookahead = lexer.scanNextToken()
        return try parseMethodTypeInternal()
    }

    /// Parse a single type.
    public func parseType() throws -> ObjCType {
        lookahead = lexer.scanNextToken()
        return try parseTypeInternal()
    }

    // MARK: - Token Matching

    private func match(_ expected: Character) throws {
        try match(expected, enterState: lexer.state)
    }

    private func match(_ expected: Character, enterState: ObjCTypeLexerState) throws {
        guard case .char(let c) = lookahead, c == expected else {
            throw ObjCTypeParserError.unexpectedToken(
                expected: String(expected),
                got: tokenDescription(lookahead),
                remaining: lexer.remainingString
            )
        }
        lexer.state = enterState
        lookahead = lexer.scanNextToken()
    }

    private func tokenDescription(_ token: ObjCTypeToken) -> String {
        switch token {
            case .eos: return "EOS"
            case .number(let n): return "NUMBER(\(n))"
            case .identifier(let i): return "IDENTIFIER(\(i))"
            case .quotedString(let s): return "QUOTED(\(s))"
            case .char(let c): return "CHAR(\(c))"
        }
    }

    // MARK: - Token Set Checks

    private func isTokenInSimpleTypeSet(_ token: ObjCTypeToken) -> Bool {
        guard case .char(let c) = token else { return false }
        return "cislqCISLQfdDBv*#:%?tT".contains(c)
    }

    private func isTokenInModifierSet(_ token: ObjCTypeToken) -> Bool {
        guard case .char(let c) = token else { return false }
        return "jrnNoORVA".contains(c)
    }

    private func isTokenInTypeSet(_ token: ObjCTypeToken) -> Bool {
        if isTokenInModifierSet(token) || isTokenInSimpleTypeSet(token) {
            return true
        }
        guard case .char(let c) = token else { return false }
        return "^b@{([".contains(c)
    }

    private func isTokenInTypeStartSet(_ token: ObjCTypeToken) -> Bool {
        if isTokenInSimpleTypeSet(token) {
            return true
        }
        guard case .char(let c) = token else { return false }
        return "rnNoORVA^b@{([".contains(c)
    }

    // MARK: - Parsing Methods

    private func parseMethodTypeInternal() throws -> [ObjCMethodType] {
        var methodTypes: [ObjCMethodType] = []

        while isTokenInTypeStartSet(lookahead) {
            let type = try parseTypeInternal()
            let offset = parseNumber()
            methodTypes.append(ObjCMethodType(type: type, offset: offset))
        }

        return methodTypes
    }

    private func parseTypeInternal() throws -> ObjCType {
        try parseTypeInternal(inStruct: false)
    }

    private func parseTypeInternal(inStruct: Bool) throws -> ObjCType {
        // Handle modifiers
        if isTokenInModifierSet(lookahead) {
            guard case .char(let modifier) = lookahead else {
                throw ObjCTypeParserError.syntaxError("Expected modifier", remaining: lexer.remainingString)
            }
            lookahead = lexer.scanNextToken()

            let subtype: ObjCType?
            if isTokenInTypeStartSet(lookahead) {
                subtype = try parseTypeInternal(inStruct: inStruct)
            }
            else {
                subtype = nil
            }

            switch modifier {
                case "j": return .complex(subtype)
                case "r": return .const(subtype)
                case "n": return .in(subtype)
                case "N": return .inout(subtype)
                case "o": return .out(subtype)
                case "O": return .bycopy(subtype)
                case "R": return .byref(subtype)
                case "V": return .oneway(subtype)
                case "A": return .atomic(subtype)
                default:
                    throw ObjCTypeParserError.syntaxError(
                        "Unknown modifier: \(modifier)",
                        remaining: lexer.remainingString
                    )
            }
        }

        // Handle pointer
        if case .char("^") = lookahead {
            lookahead = lexer.scanNextToken()

            // Check for void pointer or function pointer
            if case .quotedString = lookahead {
                // Safari on 10.5 has: "m_function"{?="__pfn"^"__delta"i}
                return .pointer(.void)
            }
            else if case .char("}") = lookahead {
                return .pointer(.void)
            }
            else if case .char(")") = lookahead {
                return .pointer(.void)
            }
            else if case .char("?") = lookahead {
                lookahead = lexer.scanNextToken()
                return .functionPointer
            }
            else {
                let pointee = try parseTypeInternal(inStruct: inStruct)
                return .pointer(pointee)
            }
        }

        // Handle bitfield
        if case .char("b") = lookahead {
            lookahead = lexer.scanNextToken()
            guard let size = parseNumber() else {
                throw ObjCTypeParserError.syntaxError("Expected bitfield size", remaining: lexer.remainingString)
            }
            return .bitfield(size: size)
        }

        // Handle id type
        if case .char("@") = lookahead {
            lookahead = lexer.scanNextToken()

            // Check for quoted class name
            if case .quotedString(let str) = lookahead {
                // Check if this is a class name or a variable name in a struct
                let shouldParseAsClassName =
                    !inStruct || str.first?.isUppercase == true || !isTokenInTypeStartSet(charToken(lexer.peekChar))

                if shouldParseAsClassName {
                    lookahead = lexer.scanNextToken()

                    // Parse protocols if present: @"ClassName<Protocol1,Protocol2>"
                    if let protocolStart = str.firstIndex(of: "<"),
                        let protocolEnd = str.lastIndex(of: ">")
                    {
                        let protocolRange = str.index(after: protocolStart)..<protocolEnd
                        let protocols = str[protocolRange].split(separator: ",")
                            .map {
                                String($0).trimmingCharacters(in: .whitespaces)
                            }
                        let typeName = String(str[..<protocolStart]).trimmingCharacters(in: .whitespaces)

                        if typeName.isEmpty || typeName == "id" {
                            return .id(className: nil, protocols: protocols)
                        }
                        return .id(className: typeName, protocols: protocols)
                    }

                    return .id(className: str, protocols: [])
                }

                // Fall through - it's a variable name, not a class name
                return .id(className: nil, protocols: [])
            }

            // Check for block type
            if case .char("?") = lookahead {
                lookahead = lexer.scanNextToken()

                // Check for block signature
                if case .char("<") = lookahead {
                    try match("<")
                    let blockTypes = try parseMethodTypeInternal().map { $0.type }
                    try match(">")
                    return .block(types: blockTypes)
                }

                return .block(types: nil)
            }

            return .id(className: nil, protocols: [])
        }

        // Handle struct
        if case .char("{") = lookahead {
            let savedState = lexer.state
            try match("{", enterState: .identifier)
            let typeName = try parseTypeName()
            let members = try parseOptionalMembers()
            try match("}", enterState: savedState)
            return .structure(name: typeName, members: members)
        }

        // Handle union
        if case .char("(") = lookahead {
            let savedState = lexer.state
            try match("(", enterState: .identifier)

            guard case .identifier = lookahead else {
                let unionTypes = try parseUnionTypes()
                try match(")", enterState: savedState)
                return .union(name: nil, members: unionTypes)
            }
            let typeName = try parseTypeName()
            let members = try parseOptionalMembers()
            try match(")", enterState: savedState)
            return .union(name: typeName, members: members)
        }

        // Handle array
        if case .char("[") = lookahead {
            try match("[")
            let count = parseNumber() ?? "0"
            let elementType = try parseTypeInternal()
            try match("]")
            return .array(count: count, elementType: elementType)
        }

        // Handle simple types
        if isTokenInSimpleTypeSet(lookahead) {
            guard case .char(let c) = lookahead else {
                throw ObjCTypeParserError.syntaxError("Expected simple type", remaining: lexer.remainingString)
            }
            lookahead = lexer.scanNextToken()

            // Special case: * is char*
            if c == "*" {
                return .pointer(.char)
            }

            if let type = ObjCType.primitive(from: c) {
                return type
            }
        }

        // Missing type - create a placeholder
        return .id(className: "MISSING_TYPE", protocols: [])
    }

    private func parseUnionTypes() throws -> [ObjCTypedMember] {
        var members: [ObjCTypedMember] = []
        while isTokenInTypeSet(lookahead) {
            let type = try parseTypeInternal()
            members.append(ObjCTypedMember(type: type))
        }
        return members
    }

    private func parseOptionalMembers() throws -> [ObjCTypedMember] {
        if case .char("=") = lookahead {
            // Reset to normal state so type codes are scanned properly
            lexer.state = .normal
            lookahead = lexer.scanNextToken()
            return try parseMemberList()
        }
        return []
    }

    private func parseMemberList() throws -> [ObjCTypedMember] {
        var members: [ObjCTypedMember] = []

        while case .quotedString = lookahead, true {
            members.append(try parseMember())
        }

        // Also handle members without names
        while isTokenInTypeSet(lookahead) {
            members.append(try parseMember())
        }

        return members
    }

    private func parseMember() throws -> ObjCTypedMember {
        var variableName: String? = nil

        // Parse variable name(s) if present
        while case .quotedString(let name) = lookahead {
            if variableName == nil {
                variableName = name
            }
            else if let existingName = variableName {
                // Multiple quoted strings - concatenate them
                variableName = "\(existingName)__\(name)"
            }
            lookahead = lexer.scanNextToken()
        }

        let type = try parseTypeInternal(inStruct: true)
        return ObjCTypedMember(type: type, name: variableName)
    }

    private func parseTypeName() throws -> ObjCTypeName? {
        guard let name = parseIdentifier() else {
            return nil
        }

        var typeName = ObjCTypeName(name: name)

        // Parse template parameters if present
        if case .char("<") = lookahead {
            let savedState = lexer.state
            try match("<", enterState: .templateTypes)

            if let first = try parseTypeName() {
                typeName.templateTypes.append(first)
            }

            while case .char(",") = lookahead {
                try match(",")
                if let next = try parseTypeName() {
                    typeName.templateTypes.append(next)
                }
            }

            try match(">", enterState: savedState)

            // Parse suffix if in template types state
            if lexer.state == .templateTypes {
                if case .identifier(let suffix) = lookahead {
                    typeName.suffix = suffix
                    lookahead = lexer.scanNextToken()
                }
            }
        }

        return typeName
    }

    private func parseIdentifier() -> String? {
        if case .identifier(let id) = lookahead {
            lookahead = lexer.scanNextToken()
            return id
        }
        return nil
    }

    private func parseNumber() -> String? {
        if case .number(let num) = lookahead {
            lookahead = lexer.scanNextToken()
            return num
        }
        return nil
    }

    private func charToken(_ char: Character?) -> ObjCTypeToken {
        guard let c = char else { return .eos }
        return .char(c)
    }
}

// MARK: - Convenience Extensions

extension ObjCType {
    // MARK: - Static Parse Caches

    /// Shared cache for parsed single types.
    ///
    /// This eliminates redundant parsing of common type encodings like "@", "i", "v", etc.
    private static let typeCache = TypeEncodingCache()

    /// Shared cache for parsed method types.
    ///
    /// This eliminates redundant parsing of common method encodings like "@24@0:8@16".
    private static let methodTypeCache = MethodTypeCache()

    /// Parse a type encoding string with caching.
    ///
    /// Common type encodings are cached to avoid redundant parsing.
    /// This provides significant speedup when the same types appear in many methods.
    ///
    /// - Parameter string: The ObjC type encoding string.
    /// - Returns: The parsed type.
    /// - Throws: If parsing fails.
    /// - Complexity: O(1) for cached types, O(n) for uncached where n = encoding length.
    public static func parse(_ string: String) throws -> ObjCType {
        // Check cache first
        if let cached = typeCache.get(encoding: string) {
            return cached
        }

        // Parse and cache
        let parser = ObjCTypeParser(string: string)
        let result = try parser.parseType()
        typeCache.set(encoding: string, type: result)
        return result
    }

    /// Parse a method type encoding string with caching.
    ///
    /// Method type encodings are cached to avoid redundant parsing.
    /// Many methods share the same type signature (e.g., "-[SomeClass init]" and
    /// "- [OtherClass init]" both have the same encoding "@16@0:8").
    ///
    /// - Parameter string: The ObjC method type encoding string.
    /// - Returns: The parsed method types (return type + arguments).
    /// - Throws: If parsing fails.
    /// - Complexity: O(1) for cached encodings, O(n) for uncached where n = encoding length.
    public static func parseMethodType(_ string: String) throws -> [ObjCMethodType] {
        return try methodTypeCache.getOrParse(encoding: string) {
            let parser = ObjCTypeParser(string: string)
            return try parser.parseMethodType()
        }
    }

    /// Clear all type parsing caches.
    ///
    /// This is primarily useful for testing or when memory pressure is high.
    public static func clearParseCaches() {
        typeCache.clear()
        methodTypeCache.clear()
    }

    /// Get cache statistics for debugging/profiling.
    ///
    /// - Returns: A tuple with (typeCount, methodTypeCount) cached entries.
    public static var parseCacheStats: (types: Int, methodTypes: Int) {
        (typeCache.count, methodTypeCache.count)
    }
}
