import Foundation

/// Represents property attributes parsed from the encoded attribute string.
public struct ObjCPropertyAttributes: OptionSet, Sendable, Hashable {
  public let rawValue: UInt32

  public init(rawValue: UInt32) {
    self.rawValue = rawValue
  }

  public static let readonly = ObjCPropertyAttributes(rawValue: 1 << 0)
  public static let copy = ObjCPropertyAttributes(rawValue: 1 << 1)
  public static let retain = ObjCPropertyAttributes(rawValue: 1 << 2)
  public static let nonatomic = ObjCPropertyAttributes(rawValue: 1 << 3)
  public static let dynamic = ObjCPropertyAttributes(rawValue: 1 << 4)
  public static let weak = ObjCPropertyAttributes(rawValue: 1 << 5)
  public static let garbageCollected = ObjCPropertyAttributes(rawValue: 1 << 6)
}

/// Represents an Objective-C property.
public struct ObjCProperty: Sendable, Hashable {
  /// The property name
  public let name: String

  /// The raw attribute string (e.g., "T@\"NSString\",C,N,V_name")
  public let attributeString: String

  /// The encoded type from the attribute string
  public let encodedType: String

  /// Parsed attributes
  public let attributes: ObjCPropertyAttributes

  /// Custom getter name (nil if using default)
  public let customGetter: String?

  /// Custom setter name (nil if using default)
  public let customSetter: String?

  /// The backing instance variable name
  public let ivarName: String?

  public init(name: String, attributeString: String) {
    self.name = name
    self.attributeString = attributeString

    // Parse the attribute string
    var encodedType = ""
    var attrs = ObjCPropertyAttributes()
    var getter: String? = nil
    var setter: String? = nil
    var ivar: String? = nil

    let components = attributeString.split(separator: ",", omittingEmptySubsequences: false)
    for component in components {
      guard !component.isEmpty else { continue }
      let first = component.first!
      let rest = String(component.dropFirst())

      switch first {
      case "T":
        encodedType = rest
      case "R":
        attrs.insert(.readonly)
      case "C":
        attrs.insert(.copy)
      case "&":
        attrs.insert(.retain)
      case "N":
        attrs.insert(.nonatomic)
      case "D":
        attrs.insert(.dynamic)
      case "W":
        attrs.insert(.weak)
      case "P":
        attrs.insert(.garbageCollected)
      case "G":
        getter = rest
      case "S":
        setter = rest
      case "V":
        ivar = rest
      default:
        break
      }
    }

    self.encodedType = encodedType
    self.attributes = attrs
    self.customGetter = getter
    self.customSetter = setter
    self.ivarName = ivar
  }

  /// Whether this is a readonly property
  public var isReadOnly: Bool {
    attributes.contains(.readonly)
  }

  /// Whether this is a dynamic property (@dynamic)
  public var isDynamic: Bool {
    attributes.contains(.dynamic)
  }

  /// Whether this is a weak property
  public var isWeak: Bool {
    attributes.contains(.weak)
  }

  /// Whether this is a copy property
  public var isCopy: Bool {
    attributes.contains(.copy)
  }

  /// Whether this is a retain/strong property
  public var isRetain: Bool {
    attributes.contains(.retain)
  }

  /// Whether this is nonatomic
  public var isNonatomic: Bool {
    attributes.contains(.nonatomic)
  }

  /// The getter method name
  public var getter: String {
    customGetter ?? name
  }

  /// The setter method name (nil if readonly)
  public var setter: String? {
    guard !isReadOnly else { return nil }
    if let custom = customSetter {
      return custom
    }
    // Default setter: setName:
    let first = name.prefix(1).uppercased()
    let rest = name.dropFirst()
    return "set\(first)\(rest):"
  }
}

extension ObjCProperty: Comparable {
  public static func < (lhs: ObjCProperty, rhs: ObjCProperty) -> Bool {
    lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
  }
}

extension ObjCProperty: CustomStringConvertible {
  public var description: String {
    var parts: [String] = []
    if isNonatomic { parts.append("nonatomic") }
    if isReadOnly { parts.append("readonly") }
    if isCopy { parts.append("copy") }
    if isRetain { parts.append("retain") }
    if isWeak { parts.append("weak") }
    let attrStr = parts.isEmpty ? "" : "(\(parts.joined(separator: ", "))) "
    return "@property \(attrStr)\(name)"
  }
}
