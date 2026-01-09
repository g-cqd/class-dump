import Foundation

/// A visitor that generates text output of class dumps.
///
/// This visitor traverses the ObjC metadata tree and builds a string representation
/// of classes, protocols, categories, methods, properties, and ivars.
open class TextClassDumpVisitor: ClassDumpVisitor, @unchecked Sendable {
    /// The accumulated result string
    public var resultString: String = ""

    /// Visitor options
    public var options: ClassDumpVisitorOptions

    /// Type formatter for generating type strings
    public var typeFormatter: ObjCTypeFormatter

    /// Callback when a class name is referenced
    public var onClassNameReferenced: ((String) -> Void)?

    /// Callback when protocol names are referenced
    public var onProtocolNamesReferenced: (([String]) -> Void)?

    public init(options: ClassDumpVisitorOptions = .init()) {
        self.options = options

        // Configure type formatter with matching demangle and output styles
        var formatterOptions = ObjCTypeFormatterOptions()
        formatterOptions.demangleStyle = options.demangleStyle
        formatterOptions.outputStyle = options.outputStyle
        self.typeFormatter = ObjCTypeFormatter(options: formatterOptions)

        // Wire up type formatter callbacks
        typeFormatter.onClassNameReferenced = { [weak self] name in
            self?.onClassNameReferenced?(name)
        }
        typeFormatter.onProtocolNamesReferenced = { [weak self] names in
            self?.onProtocolNamesReferenced?(names)
        }
    }

    // MARK: - Lifecycle

    open func willBeginVisiting() {}

    open func didEndVisiting() {}

    // MARK: - Processor Visits

    open func willVisitProcessor(_ processor: ObjCProcessorInfo) {
        // Configure type formatter with registries for enhanced type resolution
        if let structureRegistry = processor.structureRegistry {
            typeFormatter.structureRegistry = structureRegistry
        }
        if let methodSignatureRegistry = processor.methodSignatureRegistry {
            typeFormatter.methodSignatureRegistry = methodSignatureRegistry
        }
    }

    open func visitProcessor(_ processor: ObjCProcessorInfo) {}

    open func didVisitProcessor(_ processor: ObjCProcessorInfo) {}

    // MARK: - Output Helpers

    /// Append text to the result string.
    public func append(_ text: String) {
        resultString.append(text)
    }

    /// Append a newline to the result string.
    public func appendNewline() {
        resultString.append("\n")
    }

    /// Clear the result string.
    public func clearResult() {
        resultString = ""
    }

    /// Write the result to standard output.
    public func writeResultToStandardOutput() {
        if let data = resultString.data(using: .utf8) {
            FileHandle.standardOutput.write(data)
        }
    }

    // MARK: - Swift to ObjC Conversion

    /// Convert Swift type syntax to Objective-C syntax.
    ///
    /// This handles:
    /// - `[Type]` → `NSArray *`
    /// - `[Key: Value]` → `NSDictionary *`
    /// - `Set<Type>` → `NSSet *`
    /// - `Type?` → `Type *`
    /// - `Module.ClassName` → `Module.ClassName *` (adds pointer for class types)
    private func convertSwiftTypeToObjC(_ typeName: String) -> String {
        var result = typeName

        // Handle Swift.AnyObject and AnyObject → id
        if result == "Swift.AnyObject" || result == "AnyObject" {
            return "id"
        }

        // Handle Swift closure syntax: (Params) -> Return → Return (^)(Params)
        // This handles both `(Type) -> Void` and `@escaping (Type) -> Void` patterns
        if let converted = convertSwiftClosureToObjCBlock(result) {
            return converted
        }

        // Handle Swift optional suffix: Type? → Type *
        if result.hasSuffix("?") {
            let base = String(result.dropLast())
            // Handle optional Swift.AnyObject specially
            if base == "Swift.AnyObject" || base == "AnyObject" {
                return "id"
            }
            result = base
            return "\(result) *"
        }

        // Handle Swift Array syntax: [Type] → NSArray *
        if result.hasPrefix("[") && result.hasSuffix("]") && !result.contains(":") {
            return "NSArray *"
        }

        // Handle Swift Dictionary syntax: [Key: Value] → NSDictionary *
        if result.hasPrefix("[") && result.hasSuffix("]") && result.contains(":") {
            return "NSDictionary *"
        }

        // Handle Swift Set syntax: Set<Type> → NSSet *
        if result.hasPrefix("Set<") && result.hasSuffix(">") {
            return "NSSet *"
        }

        // Handle Swift Array syntax with generic: Array<Type> → NSArray *
        if result.hasPrefix("Array<") && result.hasSuffix(">") {
            return "NSArray *"
        }

        // Handle Swift Dictionary syntax with generic: Dictionary<K, V> → NSDictionary *
        if result.hasPrefix("Dictionary<") && result.hasSuffix(">") {
            return "NSDictionary *"
        }

        // Check if this looks like a class type (Module.ClassName or just ClassName)
        // Class types need pointer asterisks in ObjC
        if looksLikeClassType(result) {
            return "\(result) *"
        }

        return result
    }

    /// Convert a Swift closure type to ObjC block syntax.
    ///
    /// Examples:
    /// - `(String) -> Void` → `void (^)(NSString *)`
    /// - `@escaping (Int, Bool) -> String` → `NSString * (^)(NSInteger, BOOL)`
    /// - `() -> Void` → `void (^)(void)`
    private func convertSwiftClosureToObjCBlock(_ typeName: String) -> String? {
        var input = typeName

        // Strip @escaping, @Sendable, or other attributes
        while input.hasPrefix("@") {
            if let spaceIndex = input.firstIndex(of: " ") {
                input = String(input[input.index(after: spaceIndex)...])
            } else {
                break
            }
        }

        input = input.trimmingCharacters(in: .whitespaces)

        // Look for " -> " arrow indicating a closure type
        guard let arrowRange = input.range(of: " -> ") else {
            return nil
        }

        // Extract parameters and return type
        let paramsSection = String(input[..<arrowRange.lowerBound])
        let returnSection = String(input[arrowRange.upperBound...]).trimmingCharacters(in: .whitespaces)

        // Parameters must be wrapped in parentheses
        guard paramsSection.hasPrefix("(") && paramsSection.hasSuffix(")") else {
            return nil
        }

        // Parse parameter types
        let paramsInner = String(paramsSection.dropFirst().dropLast())
        let paramTypes = parseClosureParameters(paramsInner)

        // Convert return type to ObjC
        let objcReturn = convertSwiftTypeComponentToObjC(returnSection)

        // Convert parameter types to ObjC
        let objcParams: String
        if paramTypes.isEmpty {
            objcParams = "void"
        } else {
            objcParams = paramTypes.map { convertSwiftTypeComponentToObjC($0) }.joined(separator: ", ")
        }

        return "\(objcReturn) (^)(\(objcParams))"
    }

    /// Parse closure parameter types, handling nested parentheses and generics.
    private func parseClosureParameters(_ paramsString: String) -> [String] {
        let trimmed = paramsString.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed == "()" {
            return []
        }

        var params: [String] = []
        var current = ""
        var depth = 0
        var genericDepth = 0

        for char in trimmed {
            switch char {
            case "(":
                depth += 1
                current.append(char)
            case ")":
                depth -= 1
                current.append(char)
            case "<":
                genericDepth += 1
                current.append(char)
            case ">":
                genericDepth -= 1
                current.append(char)
            case ",":
                if depth == 0 && genericDepth == 0 {
                    params.append(current.trimmingCharacters(in: .whitespaces))
                    current = ""
                } else {
                    current.append(char)
                }
            default:
                current.append(char)
            }
        }

        if !current.isEmpty {
            params.append(current.trimmingCharacters(in: .whitespaces))
        }

        return params
    }

    /// Convert a single Swift type component to ObjC.
    private func convertSwiftTypeComponentToObjC(_ swiftType: String) -> String {
        let trimmed = swiftType.trimmingCharacters(in: .whitespaces)

        // Handle Void
        if trimmed == "Void" || trimmed == "()" {
            return "void"
        }

        // Handle common Swift-to-ObjC type mappings
        let typeMap: [String: String] = [
            "String": "NSString *",
            "Int": "NSInteger",
            "UInt": "NSUInteger",
            "Bool": "BOOL",
            "Double": "double",
            "Float": "float",
            "Any": "id",
            "AnyObject": "id",
            "Swift.AnyObject": "id",
            "Data": "NSData *",
            "Date": "NSDate *",
            "URL": "NSURL *",
            "Error": "NSError *",
        ]

        if let mapped = typeMap[trimmed] {
            return mapped
        }

        // Handle optionals
        if trimmed.hasSuffix("?") {
            let base = String(trimmed.dropLast())
            let converted = convertSwiftTypeComponentToObjC(base)
            // If already a pointer, just return it; otherwise add pointer
            if converted.hasSuffix("*") || converted == "void" || converted == "BOOL"
                || converted == "NSInteger" || converted == "NSUInteger"
                || converted == "double" || converted == "float"
            {
                return converted
            }
            return converted + " *"
        }

        // Handle arrays
        if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") && !trimmed.contains(":") {
            return "NSArray *"
        }

        // Handle dictionaries
        if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") && trimmed.contains(":") {
            return "NSDictionary *"
        }

        // For other types, assume they're objects that need a pointer
        if let first = trimmed.first, first.isUppercase {
            return "\(trimmed) *"
        }

        return trimmed
    }

    /// Check if a type name looks like a class/reference type.
    ///
    /// Heuristics:
    /// - Contains a dot (module-qualified name like `Module.ClassName`)
    /// - Starts with an uppercase letter and isn't a known value type
    /// - Contains generic parameters like `Container<String>`
    private func looksLikeClassType(_ typeName: String) -> Bool {
        // Module-qualified names are class types
        if typeName.contains(".") {
            return true
        }

        // Generic types are reference types in this context
        if typeName.contains("<") && typeName.contains(">") {
            return true
        }

        // Known Swift primitive/value types
        let valueTypes: Set<String> = [
            "Int", "Int8", "Int16", "Int32", "Int64",
            "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
            "Float", "Double", "Bool", "String", "Character",
            "CGFloat", "CGPoint", "CGSize", "CGRect", "CGVector",
            "NSInteger", "NSUInteger", "CGAffineTransform",
            "UIEdgeInsets", "NSEdgeInsets", "UIOffset",
            "void", "Void",
        ]

        if valueTypes.contains(typeName) {
            return false
        }

        // If starts with uppercase and not a known value type, likely a class
        if let first = typeName.first, first.isUppercase {
            return true
        }

        return false
    }

    // MARK: - Demangling Helpers

    /// Demangle a Swift name according to the configured style.
    ///
    /// - Parameter name: The potentially mangled name.
    /// - Returns: The demangled name based on `options.demangleStyle`.
    public func demangleName(_ name: String) -> String {
        switch options.demangleStyle {
        case .none:
            return name
        case .swift:
            return SwiftDemangler.demangleSwiftName(name)
        case .objc:
            let demangled = SwiftDemangler.demangleSwiftName(name)
            // Strip module prefix for ObjC style
            if let lastDot = demangled.lastIndex(of: ".") {
                return String(demangled[demangled.index(after: lastDot)...])
            }
            return demangled
        }
    }

    // MARK: - Class Visits

    open func willVisitClass(_ objcClass: ObjCClass) {
        if !objcClass.isExported {
            append("__attribute__((visibility(\"hidden\")))\n")
        }

        let className = demangleName(objcClass.name)
        append("@interface \(className)")
        if let superName = objcClass.superclassName {
            let demangledSuper = demangleName(superName)
            append(" : \(demangledSuper)")
        }

        if !objcClass.protocols.isEmpty {
            let demangledProtocols = objcClass.protocols.map { demangleName($0) }
            append(" <\(demangledProtocols.joined(separator: ", "))>")
        }

        appendNewline()
    }

    open func didVisitClass(_ objcClass: ObjCClass) {
        if objcClass.hasMethods {
            appendNewline()
        }
        append("@end\n\n")
    }

    open func willVisitIvarsOfClass(_ objcClass: ObjCClass) {
        append("{\n")
    }

    open func didVisitIvarsOfClass(_ objcClass: ObjCClass) {
        append("}\n\n")
    }

    open func didVisitPropertiesOfClass(_ objcClass: ObjCClass) {
        if !objcClass.properties.isEmpty {
            appendNewline()
        }
    }

    // MARK: - Category Visits

    open func willVisitCategory(_ category: ObjCCategory) {
        let className = demangleName(category.classNameForVisitor)
        append("@interface \(className) (\(category.name))")

        if !category.protocols.isEmpty {
            let demangledProtocols = category.protocols.map { demangleName($0) }
            append(" <\(demangledProtocols.joined(separator: ", "))>")
        }

        appendNewline()
    }

    open func didVisitCategory(_ category: ObjCCategory) {
        append("@end\n\n")
    }

    open func willVisitPropertiesOfCategory(_ category: ObjCCategory) {
        if !category.properties.isEmpty {
            appendNewline()
        }
    }

    open func didVisitPropertiesOfCategory(_ category: ObjCCategory) {
        if !category.properties.isEmpty {
            appendNewline()
        }
    }

    // MARK: - Protocol Visits

    open func willVisitProtocol(_ proto: ObjCProtocol) {
        let protoName = demangleName(proto.name)
        append("@protocol \(protoName)")

        if !proto.protocols.isEmpty {
            let demangledProtocols = proto.protocols.map { demangleName($0) }
            append(" <\(demangledProtocols.joined(separator: ", "))>")
        }

        appendNewline()
    }

    open func didVisitProtocol(_ proto: ObjCProtocol) {
        append("@end\n\n")
    }

    open func willVisitOptionalMethods() {
        append("\n@optional\n")
    }

    open func willVisitPropertiesOfProtocol(_ proto: ObjCProtocol) {
        if !proto.properties.isEmpty {
            appendNewline()
        }
    }

    open func didVisitPropertiesOfProtocol(_ proto: ObjCProtocol) {
        if !proto.properties.isEmpty {
            appendNewline()
        }
    }

    // MARK: - Method Visits

    open func visitClassMethod(_ method: ObjCMethod) {
        switch options.methodStyle {
        case .objc:
            append("+ ")
            appendMethod(method)
        case .swift:
            appendSwiftMethod(method, isClassMethod: true)
        }
        appendNewline()
    }

    open func visitInstanceMethod(_ method: ObjCMethod, propertyState: VisitorPropertyState) {
        if propertyState.property(forAccessor: method.name) != nil {
            // This method is a property accessor - skip it since properties are output separately
            return
        }
        // Regular instance method
        switch options.methodStyle {
        case .objc:
            append("- ")
            appendMethod(method)
        case .swift:
            appendSwiftMethod(method, isClassMethod: false)
        }
        appendNewline()
    }

    open func visitIvar(_ ivar: ObjCInstanceVariable) {
        appendIvar(ivar)
        appendNewline()
    }

    open func visitProperty(_ property: ObjCProperty) {
        guard let parsedType = property.parsedType else {
            if property.attributeString.hasPrefix("T") {
                append("// Error parsing type for property \(property.name):\n")
                append("// Property attributes: \(property.attributeString)\n\n")
            } else {
                append(
                    "// Error: Property attributes should begin with the type ('T') attribute, property name: \(property.name)\n"
                )
                append("// Property attributes: \(property.attributeString)\n\n")
            }
            return
        }

        appendProperty(property, parsedType: parsedType)
    }

    open func visitRemainingProperties(_ propertyState: VisitorPropertyState) {
        // Properties are now visited explicitly, so no remaining properties to handle
    }

    // MARK: - Formatting Helpers

    /// Append a formatted method declaration (ObjC style).
    open func appendMethod(_ method: ObjCMethod) {
        if let formatted = typeFormatter.formatMethodName(method.name, typeString: method.typeEncoding) {
            append(formatted)
            append(";")
        } else {
            // Fallback if formatting fails
            append("(\(method.typeEncoding))\(method.name);")
        }

        // Show implementation address if enabled
        if options.shouldShowMethodAddresses && method.address != 0 {
            append(String(format: " // IMP=0x%llx", method.address))
        }

        // Show raw type encoding if enabled (for debugging)
        if options.shouldShowRawTypes {
            append(" // \(method.typeEncoding)")
        }
    }

    /// Append a formatted method declaration (Swift style).
    open func appendSwiftMethod(_ method: ObjCMethod, isClassMethod: Bool) {
        if let formatted = typeFormatter.formatSwiftMethodName(
            method.name,
            typeString: method.typeEncoding,
            isClassMethod: isClassMethod
        ) {
            append(formatted)
        } else {
            // Fallback if formatting fails - show basic Swift syntax
            let prefix = isClassMethod ? "class func " : "func "
            append("\(prefix)\(method.name.replacingOccurrences(of: ":", with: "_"))(_ ...)")
        }

        // Show implementation address if enabled
        if options.shouldShowMethodAddresses && method.address != 0 {
            append(String(format: " // IMP=0x%llx", method.address))
        }

        // Show raw type encoding if enabled (for debugging)
        if options.shouldShowRawTypes {
            append(" // \(method.typeEncoding)")
        }
    }

    /// Append a formatted ivar declaration.
    open func appendIvar(_ ivar: ObjCInstanceVariable) {
        // Prioritize resolved Swift types over ObjC encoding/parsing
        if !ivar.typeString.isEmpty && ivar.typeString != ivar.typeEncoding {
            var typeStr = ivar.typeString
            // Apply ObjC conversion if in ObjC output mode
            if options.outputStyle == .objc {
                typeStr = convertSwiftTypeToObjC(typeStr)
            }
            append("    \(typeStr) \(ivar.name);")
            // Show ivar offset if enabled
            if options.shouldShowIvarOffsets {
                append(" // +\(ivar.offset)")
            }
            // Show raw type encoding if enabled (for debugging)
            if options.shouldShowRawTypes && !ivar.typeEncoding.isEmpty {
                append(" // \(ivar.typeEncoding)")
            }
            return
        }

        if let parsedType = ivar.parsedType {
            let formatted = typeFormatter.formatVariable(name: ivar.name, type: parsedType)
            append("    \(formatted);")
        } else if ivar.typeEncoding.isEmpty {
            // Swift ivars often have no ObjC type encoding
            // Show Swift.AnyObject as the type (since we know it's a Swift type but not which one)
            append("    Swift.AnyObject \(ivar.name);")
        } else {
            append("    /* \(ivar.typeEncoding) */ \(ivar.name);")
        }

        // Show ivar offset if enabled
        if options.shouldShowIvarOffsets {
            append(" // +\(ivar.offset)")
        }

        // Show raw type encoding if enabled (for debugging)
        if options.shouldShowRawTypes && !ivar.typeEncoding.isEmpty {
            append(" // \(ivar.typeEncoding)")
        }
    }

    /// Append a formatted property declaration.
    open func appendProperty(_ property: ObjCProperty, parsedType: ObjCType) {
        var attributes: [String] = []
        var backingVar: String? = nil
        var isWeak = false
        var isDynamic = false
        var unknownAttrs: [String] = []

        for attr in property.attributeComponents {
            if attr.hasPrefix("T") {
                // Type attribute - handled separately
            } else if attr.hasPrefix("R") {
                attributes.append("readonly")
            } else if attr.hasPrefix("C") {
                attributes.append("copy")
            } else if attr.hasPrefix("&") {
                attributes.append("retain")
            } else if attr.hasPrefix("G") {
                attributes.append("getter=\(String(attr.dropFirst()))")
            } else if attr.hasPrefix("S") {
                attributes.append("setter=\(String(attr.dropFirst()))")
            } else if attr.hasPrefix("V") {
                backingVar = String(attr.dropFirst())
            } else if attr.hasPrefix("N") {
                attributes.append("nonatomic")
            } else if attr.hasPrefix("W") {
                isWeak = true
            } else if attr.hasPrefix("P") {
                isWeak = false
            } else if attr.hasPrefix("D") {
                isDynamic = true
            } else if attr == "?" {
                attributes.append("nullable")
            } else {
                unknownAttrs.append(attr)
            }
        }

        if !attributes.isEmpty {
            append("@property(\(attributes.joined(separator: ", "))) ")
        } else {
            append("@property ")
        }

        if isWeak {
            append("__weak ")
        }

        let formatted = typeFormatter.formatVariable(name: property.name, type: parsedType)
        append("\(formatted);")

        if isDynamic {
            append(" // @dynamic \(property.name);")
        } else if let backing = backingVar {
            if backing == property.name {
                append(" // @synthesize \(property.name);")
            } else {
                append(" // @synthesize \(property.name)=\(backing);")
            }
        }

        // Show raw attribute string if enabled (for debugging)
        if options.shouldShowRawTypes {
            append(" // \(property.attributeString)")
        }

        appendNewline()

        if !unknownAttrs.isEmpty {
            append("// Preceding property had unknown attributes: \(unknownAttrs.joined(separator: ","))\n")
            append("// Original attribute string: \(property.attributeString)\n\n")
        }
    }
}
