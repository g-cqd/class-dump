import Foundation

/// Represents an Objective-C method (instance or class method).
public struct ObjCMethod: Sendable, Hashable {
    /// The method selector name (e.g., "initWithFrame:")
    public let name: String

    /// The encoded type string (e.g., "@24@0:8{CGRect=dddd}16")
    public let typeString: String

    /// The implementation address (0 if not available)
    public let address: UInt64

    public init(name: String, typeString: String, address: UInt64 = 0) {
        self.name = name
        self.typeString = typeString
        self.address = address
    }

    /// Whether this is an instance method (vs class method).
    /// Note: This property must be set based on context when parsing.
    public var isInstanceMethod: Bool {
        // This would need to be determined from context during parsing
        true
    }

    /// The number of arguments based on colons in the selector.
    public var argumentCount: Int {
        name.filter { $0 == ":" }.count
    }

    /// Whether this method takes no arguments (unary selector).
    public var isUnary: Bool {
        argumentCount == 0
    }
}

extension ObjCMethod: Comparable {
    public static func < (lhs: ObjCMethod, rhs: ObjCMethod) -> Bool {
        lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
}

extension ObjCMethod: CustomStringConvertible {
    public var description: String {
        if address != 0 {
            return "ObjCMethod(\(name), addr: 0x\(String(address, radix: 16)))"
        }
        return "ObjCMethod(\(name))"
    }
}
