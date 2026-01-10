// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

/// Known Swift result builder types.
public enum SwiftResultBuilder: String, Sendable, CaseIterable {
  // SwiftUI builders
  case viewBuilder = "ViewBuilder"
  case sceneBuilder = "SceneBuilder"
  case commandsBuilder = "CommandsBuilder"
  case toolbarContentBuilder = "ToolbarContentBuilder"
  case tableColumnBuilder = "TableColumnBuilder"
  case tableRowBuilder = "TableRowBuilder"
  case accessibilityRotorContentBuilder = "AccessibilityRotorContentBuilder"

  // Other common builders
  case stringInterpolation = "StringInterpolation"
  case regexComponentBuilder = "RegexComponentBuilder"

  // Custom or unknown builder
  case custom = "_custom"

  /// Detect result builder from an attribute name.
  public static func detect(from attributeName: String) -> SwiftResultBuilder? {
    // Direct match by builder name
    for builder in SwiftResultBuilder.allCases {
      if builder == .custom { continue }
      if attributeName == builder.rawValue {
        return builder
      }
      // Check for module-qualified names like SwiftUI.ViewBuilder
      if attributeName.hasSuffix(".\(builder.rawValue)") {
        return builder
      }
    }
    return nil
  }
}

// MARK: - Result Builder Info

/// Information about a result builder attribute on a method or parameter.
public struct SwiftResultBuilderInfo: Sendable {
  /// The detected result builder.
  public let builder: SwiftResultBuilder

  /// The builder type name as it appears in the attribute.
  public let builderTypeName: String

  /// Initialize result builder info.
  public init(
    builder: SwiftResultBuilder,
    builderTypeName: String
  ) {
    self.builder = builder
    self.builderTypeName = builderTypeName
  }
}
