import Foundation

/// Tracks property state during visitor traversal.
///
/// This helper class maps accessor method names to properties, allowing the visitor
/// to emit properties when their accessor methods are encountered, and track which
/// properties have been emitted.
public final class VisitorPropertyState: @unchecked Sendable {
  /// Properties indexed by accessor name (getter or setter)
  private var propertiesByAccessor: [String: ObjCProperty]

  /// Properties indexed by property name (tracks which haven't been emitted)
  private var propertiesByName: [String: ObjCProperty]

  /// Initialize with a list of properties.
  public init(properties: [ObjCProperty]) {
    propertiesByAccessor = [:]
    propertiesByName = [:]

    for property in properties {
      propertiesByName[property.name] = property
      propertiesByAccessor[property.getter] = property
      if !property.isReadOnly, let setter = property.setter {
        propertiesByAccessor[setter] = property
      }
    }
  }

  /// Get the property associated with an accessor method name.
  public func property(forAccessor accessor: String) -> ObjCProperty? {
    propertiesByAccessor[accessor]
  }

  /// Check if a property has already been used (emitted).
  public func hasUsedProperty(_ property: ObjCProperty) -> Bool {
    propertiesByName[property.name] == nil
  }

  /// Mark a property as used (emitted).
  public func useProperty(_ property: ObjCProperty) {
    propertiesByName.removeValue(forKey: property.name)
  }

  /// Get remaining properties that haven't been emitted, sorted by name.
  public var remainingProperties: [ObjCProperty] {
    propertiesByName.values.sorted { $0.name < $1.name }
  }
}
