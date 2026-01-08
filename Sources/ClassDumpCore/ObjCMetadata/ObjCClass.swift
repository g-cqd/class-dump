import Foundation

/// Reference to an Objective-C class (may be resolved or unresolved).
public struct ObjCClassReference: Sendable, Hashable {
    /// The class name
    public let name: String

    /// The address of the class (0 if external/unresolved)
    public let address: UInt64

    /// Whether this is an external class reference
    public var isExternal: Bool {
        address == 0
    }

    public init(name: String, address: UInt64 = 0) {
        self.name = name
        self.address = address
    }
}

extension ObjCClassReference: CustomStringConvertible {
    public var description: String {
        if address != 0 {
            return "\(name) (0x\(String(address, radix: 16)))"
        }
        return name
    }
}

/// Represents an Objective-C class (@interface).
public final class ObjCClass: ObjCDeclarationContainer, @unchecked Sendable {
    public let name: String

    /// Address where this class was found
    public let address: UInt64

    /// Reference to the superclass (nil for root classes like NSObject)
    public var superclassRef: ObjCClassReference?

    /// The superclass name (convenience)
    public var superclassName: String? {
        superclassRef?.name
    }

    /// Instance variables declared by this class
    public private(set) var instanceVariables: [ObjCInstanceVariable] = []

    /// Adopted protocols
    public private(set) var adoptedProtocols: [ObjCProtocol] = []

    /// Class methods
    public private(set) var classMethods: [ObjCMethod] = []

    /// Instance methods
    public private(set) var instanceMethods: [ObjCMethod] = []

    /// Properties
    public private(set) var properties: [ObjCProperty] = []

    /// Whether this class is exported (visible to other binaries)
    public var isExported: Bool = true

    /// Whether this is a Swift class exposed to Objective-C
    public var isSwiftClass: Bool = false

    /// Class data from the runtime (for ObjC 2.0)
    public var classDataAddress: UInt64 = 0

    /// Metaclass address (for ObjC 2.0)
    public var metaclassAddress: UInt64 = 0

    public init(name: String, address: UInt64 = 0) {
        self.name = name
        self.address = address
    }

    // MARK: - Adding members

    public func addInstanceVariable(_ ivar: ObjCInstanceVariable) {
        instanceVariables.append(ivar)
    }

    public func addAdoptedProtocol(_ proto: ObjCProtocol) {
        adoptedProtocols.append(proto)
    }

    public func addClassMethod(_ method: ObjCMethod) {
        classMethods.append(method)
    }

    public func addInstanceMethod(_ method: ObjCMethod) {
        instanceMethods.append(method)
    }

    public func addProperty(_ property: ObjCProperty) {
        properties.append(property)
    }

    // MARK: - Queries

    /// Names of all adopted protocols
    public var adoptedProtocolNames: [String] {
        adoptedProtocols.map(\.name)
    }

    /// Formatted string of adopted protocols
    public var adoptedProtocolsString: String {
        guard !adoptedProtocols.isEmpty else { return "" }
        return "<\(adoptedProtocolNames.joined(separator: ", "))>"
    }

    /// Whether this class has any methods
    public var hasMethods: Bool {
        !classMethods.isEmpty || !instanceMethods.isEmpty
    }

    /// All methods (class and instance)
    public var allMethods: [ObjCMethod] {
        classMethods + instanceMethods
    }

    // MARK: - Sorting

    public func sortMembers() {
        instanceVariables.sort()
        classMethods.sort()
        instanceMethods.sort()
        properties.sort()
        adoptedProtocols.sort { $0.name < $1.name }
    }
}

extension ObjCClass: Hashable {
    public static func == (lhs: ObjCClass, rhs: ObjCClass) -> Bool {
        lhs.name == rhs.name && lhs.address == rhs.address
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(address)
    }
}

extension ObjCClass: Comparable {
    public static func < (lhs: ObjCClass, rhs: ObjCClass) -> Bool {
        lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
}

extension ObjCClass: CustomStringConvertible {
    public var description: String {
        var str = "@interface \(name)"
        if let superName = superclassName {
            str += " : \(superName)"
        }
        if !adoptedProtocols.isEmpty {
            str += " \(adoptedProtocolsString)"
        }
        return str
    }
}
