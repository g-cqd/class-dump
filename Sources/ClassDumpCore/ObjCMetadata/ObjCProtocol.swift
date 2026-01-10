import Foundation

/// Protocol for types that have Objective-C method and property declarations.
public protocol ObjCDeclarationContainer {
    var name: String { get }
    var classMethods: [ObjCMethod] { get }
    var instanceMethods: [ObjCMethod] { get }
    var properties: [ObjCProperty] { get }
}

/// Represents an Objective-C protocol (@protocol).
public final class ObjCProtocol: ObjCDeclarationContainer, @unchecked Sendable {
    /// The protocol name.
    public let name: String

    /// Address where this protocol was found.
    public let address: UInt64

    /// Adopted protocols.
    public private(set) var adoptedProtocols: [ObjCProtocol] = []

    /// Required class methods.
    public private(set) var classMethods: [ObjCMethod] = []

    /// Required instance methods.
    public private(set) var instanceMethods: [ObjCMethod] = []

    /// Optional class methods.
    public private(set) var optionalClassMethods: [ObjCMethod] = []

    /// Optional instance methods.
    public private(set) var optionalInstanceMethods: [ObjCMethod] = []

    /// Properties declared by this protocol.
    public private(set) var properties: [ObjCProperty] = []

    /// Initialize a protocol.
    public init(name: String, address: UInt64 = 0) {
        self.name = name
        self.address = address
    }

    // MARK: - Adding members

    /// Add an adopted protocol.
    public func addAdoptedProtocol(_ proto: ObjCProtocol) {
        adoptedProtocols.append(proto)
    }

    /// Add a required class method.
    public func addClassMethod(_ method: ObjCMethod) {
        classMethods.append(method)
    }

    /// Add a required instance method.
    public func addInstanceMethod(_ method: ObjCMethod) {
        instanceMethods.append(method)
    }

    /// Add an optional class method.
    public func addOptionalClassMethod(_ method: ObjCMethod) {
        optionalClassMethods.append(method)
    }

    /// Add an optional instance method.
    public func addOptionalInstanceMethod(_ method: ObjCMethod) {
        optionalInstanceMethods.append(method)
    }

    /// Add a property.
    public func addProperty(_ property: ObjCProperty) {
        properties.append(property)
    }

    // MARK: - Queries

    /// Names of all adopted protocols.
    public var adoptedProtocolNames: [String] {
        adoptedProtocols.map(\.name)
    }

    /// Formatted string of adopted protocols (e.g., "<NSCoding, NSCopying>").
    public var adoptedProtocolsString: String {
        guard !adoptedProtocols.isEmpty else { return "" }
        return "<\(adoptedProtocolNames.joined(separator: ", "))>"
    }

    /// Whether this protocol declares any methods (required or optional).
    public var hasMethods: Bool {
        !classMethods.isEmpty || !instanceMethods.isEmpty || !optionalClassMethods.isEmpty
            || !optionalInstanceMethods.isEmpty
    }

    /// All methods (required and optional, class and instance).
    public var allMethods: [ObjCMethod] {
        classMethods + instanceMethods + optionalClassMethods + optionalInstanceMethods
    }

    // MARK: - Sorting

    /// Sort all members (methods, properties, protocols).
    public func sortMembers() {
        classMethods.sort()
        instanceMethods.sort()
        optionalClassMethods.sort()
        optionalInstanceMethods.sort()
        properties.sort()
        adoptedProtocols.sort { $0.name < $1.name }
    }
}

extension ObjCProtocol: Hashable {
    /// Check if two protocols are equal.
    public static func == (lhs: ObjCProtocol, rhs: ObjCProtocol) -> Bool {
        lhs.name == rhs.name && lhs.address == rhs.address
    }

    /// Hash the protocol.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(address)
    }
}

extension ObjCProtocol: Comparable {
    /// Compare two protocols by name.
    public static func < (lhs: ObjCProtocol, rhs: ObjCProtocol) -> Bool {
        lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
}

extension ObjCProtocol: CustomStringConvertible {
    /// A textual description of the protocol.
    public var description: String {
        var str = "@protocol \(name)"
        if !adoptedProtocols.isEmpty {
            str += " \(adoptedProtocolsString)"
        }
        return str
    }
}
