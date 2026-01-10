import Foundation

/// Registry for indexing method signatures to enable cross-referencing.
///
/// This registry allows looking up richer method signatures (typically from protocols)
/// to enhance block type information in class methods that may have incomplete signatures.
///
/// ## Thread Safety
///
/// This registry is implemented as an actor for explicit, compiler-verified thread safety.
/// All access is automatically isolated, eliminating data races by design.
///
/// ## Usage
/// ```swift
/// let registry = MethodSignatureRegistry()
///
/// // Register protocol methods
/// for method in protocol.instanceMethods {
///     await registry.registerMethod(method, source: .protocol(protocol.name))
/// }
///
/// // Look up block signature for a selector
/// if let blockTypes = await registry.blockSignature(forSelector: "fetchWithCompletion:", argumentIndex: 0) {
///     // Use the richer block signature
/// }
/// ```
public actor MethodSignatureRegistry {
    /// Source of a method signature for prioritization.
    public enum SignatureSource: Sendable, Hashable {
        case `protocol`(String)
        case `class`(String)
        case category(String)
    }

    /// A stored method signature with its source.
    private struct MethodEntry: Sendable {
        let selector: String
        let typeEncoding: String
        let parsedTypes: [ObjCMethodType]?
        let source: SignatureSource
    }

    /// Methods indexed by selector name.
    private var methodsBySelector: [String: [MethodEntry]] = [:]

    /// Initialize an empty registry.
    public init() {}

    // MARK: - Registration

    /// Register a method from a specific source.
    public func registerMethod(_ method: ObjCMethod, source: SignatureSource) {
        let parsedTypes = try? ObjCType.parseMethodType(method.typeString)

        let entry = MethodEntry(
            selector: method.name,
            typeEncoding: method.typeString,
            parsedTypes: parsedTypes,
            source: source
        )

        methodsBySelector[method.name, default: []].append(entry)
    }

    /// Register all methods from a protocol.
    public func registerProtocol(_ proto: ObjCProtocol) {
        let source = SignatureSource.protocol(proto.name)

        for method in proto.classMethods {
            registerMethod(method, source: source)
        }
        for method in proto.instanceMethods {
            registerMethod(method, source: source)
        }
        for method in proto.optionalClassMethods {
            registerMethod(method, source: source)
        }
        for method in proto.optionalInstanceMethods {
            registerMethod(method, source: source)
        }
    }

    // MARK: - Lookup

    /// Look up the best available block signature for a specific argument position in a selector.
    ///
    /// - Parameters:
    ///   - selector: The method selector name (e.g., "fetchWithCompletion:")
    ///   - argumentIndex: The argument position (0-based, not counting self and _cmd)
    /// - Returns: The block's parsed types if a richer signature is found, nil otherwise.
    public func blockSignature(forSelector selector: String, argumentIndex: Int) -> [ObjCType]? {
        guard let entries = methodsBySelector[selector] else { return nil }

        // Prefer protocol sources over class sources
        let sortedEntries = entries.sorted { lhs, rhs in
            switch (lhs.source, rhs.source) {
                case (.protocol, .class), (.protocol, .category):
                    return true
                case (.class, .protocol), (.category, .protocol):
                    return false
                default:
                    return false
            }
        }

        for entry in sortedEntries {
            guard let types = entry.parsedTypes else { continue }

            // Method types: [return, self, _cmd, arg0, arg1, ...]
            // So argument index 0 is at position 3
            let typeIndex = argumentIndex + 3

            guard typeIndex < types.count else { continue }

            let argType = types[typeIndex].type

            // Check if this is a block with full signature
            if case .block(let blockTypes) = argType, let blockTypes = blockTypes, !blockTypes.isEmpty {
                return blockTypes
            }
        }

        return nil
    }

    /// Look up the full parsed types for a selector.
    ///
    /// - Parameter selector: The method selector name
    /// - Returns: The best available parsed method types, nil if not found.
    public func methodTypes(forSelector selector: String) -> [ObjCMethodType]? {
        guard let entries = methodsBySelector[selector] else { return nil }

        // Prefer protocol sources
        let sortedEntries = entries.sorted { lhs, rhs in
            switch (lhs.source, rhs.source) {
                case (.protocol, .class), (.protocol, .category):
                    return true
                default:
                    return false
            }
        }

        for entry in sortedEntries {
            if let types = entry.parsedTypes, !types.isEmpty {
                return types
            }
        }

        return nil
    }

    /// Check if a selector has any registered entries.
    public func hasSelector(_ selector: String) -> Bool {
        methodsBySelector[selector] != nil
    }

    /// Get all registered selectors.
    public var allSelectors: Set<String> {
        Set(methodsBySelector.keys)
    }

    /// Get the count of registered methods.
    public var methodCount: Int {
        methodsBySelector.values.reduce(0) { $0 + $1.count }
    }
}
