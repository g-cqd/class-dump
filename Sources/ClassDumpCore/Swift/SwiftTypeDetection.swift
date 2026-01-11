// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

/// Utilities for detecting Swift-specific features from type names and mangled symbols.
public enum SwiftTypeDetection {
    /// Detect a property wrapper from a type name.
    ///
    /// - Parameter typeName: The type name (e.g., "State<Int>", "SwiftUI.Binding<String>").
    /// - Returns: Property wrapper info if detected, nil otherwise.
    public static func detectPropertyWrapper(from typeName: String) -> SwiftPropertyWrapperInfo? {
        guard let wrapper = SwiftPropertyWrapper.detect(from: typeName) else {
            return nil
        }
        let wrappedType = extractGenericParameter(from: typeName)
        return SwiftPropertyWrapperInfo(
            wrapper: wrapper,
            wrapperTypeName: typeName,
            wrappedValueType: wrappedType
        )
    }

    /// Detect a result builder from a type or attribute name.
    ///
    /// - Parameter attributeName: The attribute name (e.g., "ViewBuilder", "SwiftUI.SceneBuilder").
    /// - Returns: Result builder info if detected, nil otherwise.
    public static func detectResultBuilder(from attributeName: String) -> SwiftResultBuilderInfo? {
        guard let builder = SwiftResultBuilder.detect(from: attributeName) else {
            return nil
        }
        return SwiftResultBuilderInfo(builder: builder, builderTypeName: attributeName)
    }

    /// Check if a type name looks like a closure type with a result builder.
    ///
    /// Result builder closures often have patterns like `@ViewBuilder () -> some View`.
    ///
    /// - Parameter typeName: The full type signature.
    /// - Returns: Tuple of (builder info, closure type) if detected.
    public static func detectResultBuilderClosure(
        from typeName: String
    ) -> (builder: SwiftResultBuilderInfo, closureType: String)? {
        // Look for @Builder pattern followed by closure
        for builder in SwiftResultBuilder.allCases {
            if builder == .custom { continue }
            let pattern = "@\(builder.rawValue)"
            if typeName.contains(pattern) {
                // Extract the closure part after the builder
                if let range = typeName.range(of: pattern) {
                    let closurePart = typeName[range.upperBound...].trimmingCharacters(in: .whitespaces)
                    return (
                        SwiftResultBuilderInfo(builder: builder, builderTypeName: builder.rawValue),
                        closurePart
                    )
                }
            }
        }
        return nil
    }

    /// Extract the generic parameter from a generic type like "State<Int>" -> "Int".
    ///
    /// - Parameter typeName: The generic type name.
    /// - Returns: The inner type, or nil if not found.
    public static func extractGenericParameter(from typeName: String) -> String? {
        guard let startIndex = typeName.firstIndex(of: "<"),
            let endIndex = typeName.lastIndex(of: ">")
        else {
            return nil
        }

        let afterStart = typeName.index(after: startIndex)
        guard afterStart < endIndex else { return nil }

        return String(typeName[afterStart..<endIndex])
    }

    /// Check if a type looks like a Swift async type.
    ///
    /// Async functions have specific mangling patterns.
    ///
    /// - Parameter mangledName: The mangled function name.
    /// - Returns: true if the function appears to be async.
    public static func looksLikeAsyncFunction(_ mangledName: String) -> Bool {
        // Swift async functions have specific mangling patterns
        // The convention attribute in mangling includes 'a' for async
        // Pattern: $sSOME_NAME followed by convention markers
        // In practice, async functions have 'Ta' (thin async) or similar markers
        if mangledName.contains("Ta") || mangledName.contains("YaK") {
            return true
        }
        // Also check for async thunk markers
        if mangledName.contains("ScM") || mangledName.contains("Tu") {
            return true
        }
        return false
    }

    /// Check if a type represents a Sendable closure.
    ///
    /// - Parameter typeName: The type name.
    /// - Returns: true if the type looks like a @Sendable closure.
    public static func looksLikeSendableClosure(_ typeName: String) -> Bool {
        // @Sendable closures have specific patterns
        typeName.contains("@Sendable") || typeName.contains("Sendable")
    }

    /// Check if a type represents an actor.
    ///
    /// - Parameter typeName: The type name.
    /// - Returns: true if the type mentions actor isolation.
    public static func looksLikeActor(_ typeName: String) -> Bool {
        // Actor types or isolated parameters
        typeName.contains("actor") || typeName.contains("@isolated") || typeName.contains("@MainActor")
    }

    /// Check if a type represents an opaque return type (some Protocol).
    ///
    /// - Parameter typeName: The type name.
    /// - Returns: true if the type is an opaque type.
    public static func looksLikeOpaqueType(_ typeName: String) -> Bool {
        typeName.hasPrefix("some ") || typeName.contains("some ")
    }
}
