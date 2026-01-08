import Foundation

/// Represents an Objective-C category (@interface ClassName (CategoryName)).
public final class ObjCCategory: ObjCDeclarationContainer, @unchecked Sendable {
  /// The category name (e.g., "Private" in @interface NSObject (Private))
  public let name: String

  /// Address where this category was found
  public let address: UInt64

  /// Reference to the class this category extends
  public var classRef: ObjCClassReference?

  /// The name of the class being extended
  public var className: String? {
    classRef?.name
  }

  /// Adopted protocols
  public private(set) var adoptedProtocols: [ObjCProtocol] = []

  /// Class methods added by this category
  public private(set) var classMethods: [ObjCMethod] = []

  /// Instance methods added by this category
  public private(set) var instanceMethods: [ObjCMethod] = []

  /// Properties added by this category
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

  /// Whether this category has any methods
  public var hasMethods: Bool {
    !classMethods.isEmpty || !instanceMethods.isEmpty
  }

  /// All methods (class and instance)
  public var allMethods: [ObjCMethod] {
    classMethods + instanceMethods
  }

  // MARK: - Sorting

  public func sortMembers() {
    classMethods.sort()
    instanceMethods.sort()
    properties.sort()
    adoptedProtocols.sort { $0.name < $1.name }
  }
}

extension ObjCCategory: Hashable {
  public static func == (lhs: ObjCCategory, rhs: ObjCCategory) -> Bool {
    lhs.name == rhs.name && lhs.className == rhs.className && lhs.address == rhs.address
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(name)
    hasher.combine(className)
    hasher.combine(address)
  }
}

extension ObjCCategory: Comparable {
  public static func < (lhs: ObjCCategory, rhs: ObjCCategory) -> Bool {
    // Sort by class name first, then category name
    if let lhsClass = lhs.className, let rhsClass = rhs.className {
      if lhsClass != rhsClass {
        return lhsClass.localizedStandardCompare(rhsClass) == .orderedAscending
      }
    }
    return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
  }
}

extension ObjCCategory: CustomStringConvertible {
  public var description: String {
    var str = "@interface "
    str += className ?? "?"
    str += " (\(name))"
    if !adoptedProtocols.isEmpty {
      str += " \(adoptedProtocolsString)"
    }
    return str
  }
}
