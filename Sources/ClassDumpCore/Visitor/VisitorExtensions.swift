import Foundation

// MARK: - ObjCClass Extensions for Visitors

extension ObjCClass {
    /// Protocol names as strings (for visitor use)
    public var protocols: [String] {
        adoptedProtocolNames
    }
}

// MARK: - ObjCCategory Extensions for Visitors

extension ObjCCategory {
    /// Protocol names as strings (for visitor use)
    public var protocols: [String] {
        adoptedProtocolNames
    }

    /// The class name (non-optional for visitor use)
    public var classNameForVisitor: String {
        className ?? ""
    }
}

// MARK: - ObjCProtocol Extensions for Visitors

extension ObjCProtocol {
    /// Protocol names as strings (for visitor use)
    public var protocols: [String] {
        adoptedProtocolNames
    }
}

// MARK: - ObjCProperty Extensions for Visitors

extension ObjCProperty {
    /// Parse the type encoding to get the ObjCType
    public var parsedType: ObjCType? {
        guard !encodedType.isEmpty else { return nil }
        return try? ObjCType.parse(encodedType)
    }

    /// Get the raw attribute components as strings (for visitor formatting)
    public var attributeComponents: [String] {
        attributeString.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
    }
}

// MARK: - ObjCInstanceVariable Extensions for Visitors

extension ObjCInstanceVariable {
    /// The type encoding string (alias for typeString for visitor use)
    public var typeEncoding: String {
        typeString
    }

    /// Parse the type encoding to get the ObjCType
    public var parsedType: ObjCType? {
        guard !typeString.isEmpty else { return nil }
        return try? ObjCType.parse(typeString)
    }
}

// MARK: - ObjCMethod Extensions for Visitors

extension ObjCMethod {
    /// The type encoding string (alias for typeString for visitor use)
    public var typeEncoding: String {
        typeString
    }

    /// Parse the type encoding to get the method types
    public var parsedTypes: [ObjCMethodType]? {
        try? ObjCType.parseMethodType(typeString)
    }

    /// The return type
    public var returnType: ObjCType? {
        parsedTypes?.first?.type
    }

    /// The argument types (excluding self and _cmd)
    public var argumentTypes: [ObjCType] {
        guard let types = parsedTypes, types.count > 3 else { return [] }
        return types.dropFirst(3).map(\.type)
    }
}
