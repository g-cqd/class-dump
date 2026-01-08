import Foundation

/// Represents an Objective-C instance variable (ivar).
public struct ObjCInstanceVariable: Sendable, Hashable {
    /// The ivar name
    public let name: String

    /// The encoded type string
    public let typeString: String

    /// The offset of this ivar within the object
    public let offset: UInt64

    /// The size of this ivar (if known)
    public let size: UInt64?

    /// The alignment of this ivar (if known)
    public let alignment: UInt32?

    public init(
        name: String,
        typeString: String,
        offset: UInt64,
        size: UInt64? = nil,
        alignment: UInt32? = nil
    ) {
        self.name = name
        self.typeString = typeString
        self.offset = offset
        self.size = size
        self.alignment = alignment
    }

    /// Whether this appears to be a synthesized ivar (starts with underscore)
    public var isSynthesized: Bool {
        name.hasPrefix("_")
    }
}

extension ObjCInstanceVariable: Comparable {
    public static func < (lhs: ObjCInstanceVariable, rhs: ObjCInstanceVariable) -> Bool {
        lhs.offset < rhs.offset
    }
}

extension ObjCInstanceVariable: CustomStringConvertible {
    public var description: String {
        "ObjCInstanceVariable(\(name), offset: \(offset))"
    }
}
