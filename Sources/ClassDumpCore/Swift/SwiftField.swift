// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

/// A Swift field (property or enum case).
public struct SwiftField: Sendable {
    /// The field name.
    public let name: String

    /// The mangled type name.
    public let mangledTypeName: String

    /// The human-readable type name.
    public let typeName: String

    /// Whether this is a variable (vs let).
    public let isVar: Bool

    /// Whether this is an indirect field (enum case).
    public let isIndirect: Bool

    /// Initialize a Swift field.
    public init(
        name: String,
        mangledTypeName: String = "",
        typeName: String = "",
        isVar: Bool = false,
        isIndirect: Bool = false
    ) {
        self.name = name
        self.mangledTypeName = mangledTypeName
        self.typeName = typeName
        self.isVar = isVar
        self.isIndirect = isIndirect
    }

    // MARK: - Property Wrapper Detection

    /// Detect if this field uses a property wrapper.
    ///
    /// Returns the detected wrapper info if the field's type matches a known wrapper pattern.
    public var propertyWrapper: SwiftPropertyWrapperInfo? {
        guard !typeName.isEmpty else { return nil }

        // Check for known property wrapper patterns
        if let wrapper = SwiftPropertyWrapper.detect(from: typeName) {
            let wrappedType = extractWrappedType(from: typeName)
            return SwiftPropertyWrapperInfo(
                wrapper: wrapper,
                wrapperTypeName: typeName,
                wrappedValueType: wrappedType
            )
        }

        return nil
    }

    /// Whether this field uses a property wrapper.
    public var hasPropertyWrapper: Bool {
        propertyWrapper != nil
    }

    /// Extract the wrapped type from a wrapper type name like "State<Int>" -> "Int".
    private func extractWrappedType(from wrapperTypeName: String) -> String? {
        // Look for generic parameter: WrapperName<WrappedType>
        guard let startIndex = wrapperTypeName.firstIndex(of: "<"),
            let endIndex = wrapperTypeName.lastIndex(of: ">")
        else {
            return nil
        }

        let afterStart = wrapperTypeName.index(after: startIndex)
        guard afterStart < endIndex else { return nil }

        return String(wrapperTypeName[afterStart..<endIndex])
    }
}
