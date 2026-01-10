// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

/// Known Swift property wrapper types.
public enum SwiftPropertyWrapper: String, Sendable, CaseIterable {
  // SwiftUI wrappers
  case state = "State"
  case binding = "Binding"
  case observedObject = "ObservedObject"
  case stateObject = "StateObject"
  case environmentObject = "EnvironmentObject"
  case environment = "Environment"
  case focusState = "FocusState"
  case gestureState = "GestureState"
  case scaledMetric = "ScaledMetric"
  case appStorage = "AppStorage"
  case sceneStorage = "SceneStorage"
  case fetchRequest = "FetchRequest"
  case sectionedFetchRequest = "SectionedFetchRequest"
  case query = "Query"  // SwiftData
  case bindable = "Bindable"  // iOS 17+

  // Combine wrappers
  case published = "Published"

  // Custom or unknown wrapper
  case custom = "_custom"

  /// The projected value prefix ($ prefix) type, if any.
  public var projectedValueType: String? {
    switch self {
    case .state, .binding: return "Binding"
    case .observedObject: return "ObservedObject.Wrapper"
    case .stateObject: return "ObservedObject.Wrapper"
    case .environmentObject: return "EnvironmentObject.Wrapper"
    case .focusState: return "FocusState.Binding"
    case .gestureState: return "GestureState.Binding"
    case .published: return "Published.Publisher"
    case .environment, .scaledMetric, .appStorage, .sceneStorage,
      .fetchRequest, .sectionedFetchRequest, .query, .bindable, .custom:
      return nil
    }
  }

  /// Whether this wrapper requires a view context (SwiftUI wrappers).
  public var requiresViewContext: Bool {
    switch self {
    case .state, .binding, .observedObject, .stateObject, .environmentObject,
      .environment, .focusState, .gestureState, .scaledMetric,
      .appStorage, .sceneStorage, .fetchRequest, .sectionedFetchRequest,
      .query, .bindable:
      return true
    case .published, .custom:
      return false
    }
  }

  /// Detect property wrapper from a type name.
  public static func detect(from typeName: String) -> SwiftPropertyWrapper? {
    // Direct match by wrapper name
    for wrapper in SwiftPropertyWrapper.allCases {
      if wrapper == .custom { continue }
      if typeName == wrapper.rawValue || typeName.hasPrefix("\(wrapper.rawValue)<") {
        return wrapper
      }
      // Check for module-qualified names like SwiftUI.State
      if typeName.hasSuffix(".\(wrapper.rawValue)")
        || typeName.contains(".\(wrapper.rawValue)<")
      {
        return wrapper
      }
    }
    return nil
  }
}

// MARK: - Property Wrapper Info

/// Information about a property wrapper applied to a field.
public struct SwiftPropertyWrapperInfo: Sendable {
  /// The detected property wrapper.
  public let wrapper: SwiftPropertyWrapper

  /// The wrapper type name as it appears in the mangled type.
  public let wrapperTypeName: String

  /// The wrapped value type (inner type).
  public let wrappedValueType: String?

  /// Initialize property wrapper info.
  public init(
    wrapper: SwiftPropertyWrapper,
    wrapperTypeName: String,
    wrappedValueType: String? = nil
  ) {
    self.wrapper = wrapper
    self.wrapperTypeName = wrapperTypeName
    self.wrappedValueType = wrappedValueType
  }
}
