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
  public let name: String

  /// Address where this protocol was found
  public let address: UInt64

  /// Adopted protocols
  public private(set) var adoptedProtocols: [ObjCProtocol] = []

  /// Required class methods
  public private(set) var classMethods: [ObjCMethod] = []

  /// Required instance methods
  public private(set) var instanceMethods: [ObjCMethod] = []

  /// Optional class methods
  public private(set) var optionalClassMethods: [ObjCMethod] = []

  /// Optional instance methods
  public private(set) var optionalInstanceMethods: [ObjCMethod] = []

  /// Properties declared by this protocol
  public private(set) var properties: [ObjCProperty] = []

  public init(name: String, address: UInt64 = 0) {
    self.name = name
    self.address = address
  }

  // MARK: - Adding members

  public func addAdoptedProtocol(_ proto: ObjCProtocol) {
    adoptedProtocols.append(proto)
  }

  public func addClassMethod(_ method: ObjCMethod) {
    classMethods.append(method)
  }

  public func addInstanceMethod(_ method: ObjCMethod) {
    instanceMethods.append(method)
  }

  public func addOptionalClassMethod(_ method: ObjCMethod) {
    optionalClassMethods.append(method)
  }

  public func addOptionalInstanceMethod(_ method: ObjCMethod) {
    optionalInstanceMethods.append(method)
  }

  public func addProperty(_ property: ObjCProperty) {
    properties.append(property)
  }

  // MARK: - Queries

  /// Names of all adopted protocols
  public var adoptedProtocolNames: [String] {
    adoptedProtocols.map(\.name)
  }

  /// Formatted string of adopted protocols (e.g., "<NSCoding, NSCopying>")
  public var adoptedProtocolsString: String {
    guard !adoptedProtocols.isEmpty else { return "" }
    return "<\(adoptedProtocolNames.joined(separator: ", "))>"
  }

  /// Whether this protocol declares any methods (required or optional)
  public var hasMethods: Bool {
    !classMethods.isEmpty || !instanceMethods.isEmpty ||
    !optionalClassMethods.isEmpty || !optionalInstanceMethods.isEmpty
  }

  /// All methods (required and optional, class and instance)
  public var allMethods: [ObjCMethod] {
    classMethods + instanceMethods + optionalClassMethods + optionalInstanceMethods
  }

  // MARK: - Sorting

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
  public static func == (lhs: ObjCProtocol, rhs: ObjCProtocol) -> Bool {
    lhs.name == rhs.name && lhs.address == rhs.address
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(name)
    hasher.combine(address)
  }
}

extension ObjCProtocol: Comparable {
  public static func < (lhs: ObjCProtocol, rhs: ObjCProtocol) -> Bool {
    lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
  }
}

extension ObjCProtocol: CustomStringConvertible {
  public var description: String {
    var str = "@protocol \(name)"
    if !adoptedProtocols.isEmpty {
      str += " \(adoptedProtocolsString)"
    }
    return str
  }
}
