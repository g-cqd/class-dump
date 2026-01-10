// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

/// A visitor that generates Swift-style output similar to .swiftinterface files.
///
/// This visitor outputs declarations in Swift syntax rather than Objective-C header format.
/// The output is similar to what you'd see in a `.swiftinterface` file.
///
/// ## Example Output
///
/// ```swift
/// @objc public class MyClass : NSObject {
///   @objc public func doSomething(_ arg: String) -> Bool
///   @objc public var name: String { get set }
/// }
///
/// @objc public protocol MyProtocol {
///   @objc func requiredMethod()
///   @objc optional func optionalMethod()
/// }
/// ```
///
public final class SwiftOutputVisitor: ClassDumpVisitor, @unchecked Sendable {
    /// The accumulated result string.
    public var resultString: String = ""

    /// Visitor options.
    public var options: ClassDumpVisitorOptions

    /// Type formatter for generating type strings.
    public var typeFormatter: ObjCTypeFormatter

    /// Header string to prepend to output.
    public var headerString: String = ""

    /// Current indentation level.
    private var indentLevel: Int = 0

    /// Whether we're in the optional methods section.
    private var inOptionalSection: Bool = false

    /// Initialize a Swift output visitor.
    public init(options: ClassDumpVisitorOptions = .init()) {
        self.options = options

        // Configure type formatter for Swift output
        var formatterOptions = ObjCTypeFormatterOptions()
        formatterOptions.demangleStyle = options.demangleStyle
        formatterOptions.outputStyle = .swift  // Always use Swift output style
        self.typeFormatter = ObjCTypeFormatter(options: formatterOptions)
    }

    // MARK: - Output Helpers

    private var indent: String {
        String(repeating: "  ", count: indentLevel)
    }

    private func append(_ text: String) {
        resultString.append(text)
    }

    private func appendLine(_ text: String = "") {
        if text.isEmpty {
            resultString.append("\n")
        }
        else {
            resultString.append("\(indent)\(text)\n")
        }
    }

    /// Write the result to standard output.
    public func writeResultToStandardOutput() {
        if let data = resultString.data(using: .utf8) {
            FileHandle.standardOutput.write(data)
        }
    }

    // MARK: - Demangling

    private func demangle(_ name: String) -> String {
        switch options.demangleStyle {
            case .none:
                return name
            case .swift:
                return SwiftDemangler.demangleSwiftName(name)
            case .objc:
                let demangled = SwiftDemangler.demangleSwiftName(name)
                if let lastDot = demangled.lastIndex(of: ".") {
                    return String(demangled[demangled.index(after: lastDot)...])
                }
                return demangled
        }
    }

    // MARK: - Type Conversion

    /// Convert an ObjC type encoding to Swift syntax.
    private func swiftType(from typeEncoding: String) -> String {
        guard let parsedType = try? ObjCType.parse(typeEncoding) else {
            return "Any"
        }
        return swiftType(from: parsedType)
    }

    /// Convert a parsed ObjC type to Swift syntax.
    private func swiftType(from type: ObjCType) -> String {
        switch type {
            case .void:
                return "Void"
            case .char, .unsignedChar:
                return "CChar"
            case .short:
                return "Int16"
            case .unsignedShort:
                return "UInt16"
            case .int:
                return "Int32"
            case .unsignedInt:
                return "UInt32"
            case .long:
                return "Int"
            case .unsignedLong:
                return "UInt"
            case .longLong:
                return "Int64"
            case .unsignedLongLong:
                return "UInt64"
            case .float:
                return "Float"
            case .double:
                return "Double"
            case .bool:
                return "Bool"
            case .selector:
                return "Selector"
            case .cString:
                return "UnsafePointer<CChar>?"
            case .objcClass:
                return "AnyClass?"
            case .id(let className, let protocols):
                if let className = className, !className.isEmpty {
                    let demangled = demangle(className)
                    if protocols.isEmpty {
                        return "\(demangled)?"
                    }
                    return "\(demangled) & \(protocols.joined(separator: " & "))?"
                }
                if !protocols.isEmpty {
                    return protocols.joined(separator: " & ")
                }
                return "AnyObject?"
            case .pointer(let pointee):
                let inner = swiftType(from: pointee)
                if inner == "Void" {
                    return "UnsafeRawPointer?"
                }
                return "UnsafePointer<\(inner)>?"
            case .array(_, let elementType):
                return "[\(swiftType(from: elementType))]"
            case .structure(let name, _):
                if let name = name {
                    return name.name
                }
                return "OpaqueStruct"
            case .union(let name, _):
                if let name = name {
                    return name.name
                }
                return "OpaqueUnion"
            case .block(let types):
                if let types = types, types.count > 1 {
                    let returnType = swiftType(from: types[0])
                    let params = types.dropFirst().map { swiftType(from: $0) }.joined(separator: ", ")
                    if returnType == "Void" {
                        return "@escaping (\(params)) -> Void"
                    }
                    return "@escaping (\(params)) -> \(returnType)"
                }
                return "@escaping () -> Void"
            case .const(let inner):
                if let inner = inner {
                    return swiftType(from: inner)
                }
                return "Any"
            case .functionPointer:
                return "@convention(c) () -> Void"
            case .bitfield:
                return "Int"
            default:
                return "Any"
        }
    }

    // MARK: - Lifecycle

    public func willBeginVisiting() {
        if !headerString.isEmpty {
            append(headerString)
        }
        appendLine("// Swift-style interface generated by class-dump")
        appendLine("// Note: This is a reconstruction from Objective-C runtime metadata")
        appendLine()
        appendLine("import Foundation")
        appendLine()
    }

    public func didEndVisiting() {
        writeResultToStandardOutput()
    }

    // MARK: - Processor Visits

    public func willVisitProcessor(_ processor: ObjCProcessorInfo) {
        if let structureRegistry = processor.structureRegistry {
            typeFormatter.structureRegistry = structureRegistry
        }
        if let methodSignatureRegistry = processor.methodSignatureRegistry {
            typeFormatter.methodSignatureRegistry = methodSignatureRegistry
        }
    }

    public func visitProcessor(_ processor: ObjCProcessorInfo) {
        if !processor.hasObjectiveCRuntimeInfo {
            appendLine("// This file does not contain any Objective-C runtime information.")
            appendLine()
        }
    }

    public func didVisitProcessor(_ processor: ObjCProcessorInfo) {}

    // MARK: - Protocol Visits

    public func willVisitProtocol(_ proto: ObjCProtocol) {
        let protoName = demangle(proto.name)

        append("\(indent)@objc public protocol \(protoName)")

        if !proto.protocols.isEmpty {
            let inherited = proto.protocols.map { demangle($0) }.joined(separator: ", ")
            append(" : \(inherited)")
        }

        append(" {\n")
        indentLevel += 1
        inOptionalSection = false
    }

    public func didVisitProtocol(_ proto: ObjCProtocol) {
        indentLevel -= 1
        appendLine("}")
        appendLine()
        inOptionalSection = false
    }

    public func willVisitPropertiesOfProtocol(_ proto: ObjCProtocol) {}

    public func didVisitPropertiesOfProtocol(_ proto: ObjCProtocol) {}

    public func willVisitOptionalMethods() {
        inOptionalSection = true
        appendLine()
        appendLine("// MARK: - Optional")
    }

    public func didVisitOptionalMethods() {
        inOptionalSection = false
    }

    // MARK: - Class Visits

    public func willVisitClass(_ objcClass: ObjCClass) {
        let className = demangle(objcClass.name)

        var declaration = "@objc"
        if !objcClass.isExported {
            declaration += " @_implementationOnly"
        }
        declaration += " public class \(className)"

        // Superclass
        if let superName = objcClass.superclassName {
            declaration += " : \(demangle(superName))"
        }

        // Protocols
        if !objcClass.protocols.isEmpty {
            let separator = objcClass.superclassName != nil ? ", " : " : "
            let protos = objcClass.protocols.map { demangle($0) }.joined(separator: ", ")
            declaration += separator + protos
        }

        declaration += " {"

        appendLine(declaration)
        indentLevel += 1
    }

    public func didVisitClass(_ objcClass: ObjCClass) {
        indentLevel -= 1
        appendLine("}")
        appendLine()
    }

    public func willVisitIvarsOfClass(_ objcClass: ObjCClass) {
        appendLine()
        appendLine("// MARK: - Instance Variables")
    }

    public func didVisitIvarsOfClass(_ objcClass: ObjCClass) {}

    public func willVisitPropertiesOfClass(_ objcClass: ObjCClass) {}

    public func didVisitPropertiesOfClass(_ objcClass: ObjCClass) {}

    // MARK: - Category Visits

    public func willVisitCategory(_ category: ObjCCategory) {
        let className = demangle(category.classNameForVisitor)
        let categoryName = category.name

        appendLine("// MARK: - \(className)+\(categoryName)")
        appendLine()

        var declaration = "@objc public extension \(className)"

        if !category.protocols.isEmpty {
            // Note: Swift extensions can't add protocol conformance after-the-fact
            // We'll add a comment
            let protos = category.protocols.map { demangle($0) }.joined(separator: ", ")
            appendLine("// Conforms to: \(protos)")
        }

        declaration += " {"

        appendLine(declaration)
        indentLevel += 1
    }

    public func didVisitCategory(_ category: ObjCCategory) {
        indentLevel -= 1
        appendLine("}")
        appendLine()
    }

    public func willVisitPropertiesOfCategory(_ category: ObjCCategory) {}

    public func didVisitPropertiesOfCategory(_ category: ObjCCategory) {}

    // MARK: - Member Visits

    public func visitClassMethod(_ method: ObjCMethod) {
        let decl = formatSwiftMethod(method, isClassMethod: true)
        appendLine(decl)
    }

    public func visitInstanceMethod(_ method: ObjCMethod, propertyState: VisitorPropertyState) {
        // Skip property accessors
        if propertyState.property(forAccessor: method.name) != nil {
            return
        }

        let decl = formatSwiftMethod(method, isClassMethod: false)
        appendLine(decl)
    }

    public func visitIvar(_ ivar: ObjCInstanceVariable) {
        var typeStr: String
        if !ivar.typeString.isEmpty && ivar.typeString != ivar.typeEncoding {
            // Use resolved Swift type
            typeStr = ivar.typeString
        }
        else if let parsed = ivar.parsedType {
            typeStr = swiftType(from: parsed)
        }
        else {
            typeStr = swiftType(from: ivar.typeEncoding)
        }

        var decl = "private var \(ivar.name): \(typeStr)"

        if options.shouldShowIvarOffsets && ivar.offset != 0 {
            decl += String(format: " // offset: 0x%llx", ivar.offset)
        }

        appendLine(decl)
    }

    public func visitProperty(_ property: ObjCProperty) {
        guard let parsedType = property.parsedType else {
            appendLine("// Error parsing property: \(property.name)")
            return
        }

        let typeStr = swiftType(from: parsedType)

        // Build property declaration
        var decl = inOptionalSection ? "@objc optional " : "@objc "

        // Access level
        if property.isReadOnly {
            decl += "public var \(property.name): \(typeStr) { get }"
        }
        else {
            decl += "public var \(property.name): \(typeStr) { get set }"
        }

        appendLine(decl)
    }

    public func visitRemainingProperties(_ propertyState: VisitorPropertyState) {}

    // MARK: - Method Formatting

    private func formatSwiftMethod(_ method: ObjCMethod, isClassMethod: Bool) -> String {
        // Try to use the type formatter first
        if let formatted = typeFormatter.formatSwiftMethodName(
            method.name,
            typeString: method.typeEncoding,
            isClassMethod: isClassMethod
        ) {
            var result = inOptionalSection ? "@objc optional " : "@objc "
            result += formatted

            if options.shouldShowMethodAddresses && method.address != 0 {
                result += String(format: " // IMP=0x%llx", method.address)
            }
            if options.shouldShowRawTypes {
                result += " // \(method.typeEncoding)"
            }

            return result
        }

        // Fallback: manual formatting
        return formatSwiftMethodManual(method, isClassMethod: isClassMethod)
    }

    private func formatSwiftMethodManual(_ method: ObjCMethod, isClassMethod: Bool) -> String {
        var result = inOptionalSection ? "@objc optional " : "@objc "
        result += isClassMethod ? "class func " : "func "

        // Parse method name parts
        let parts = method.name.split(separator: ":", omittingEmptySubsequences: false)

        if parts.count == 1 && !method.name.contains(":") {
            // No parameters
            result += "\(method.name)()"
        }
        else {
            // Has parameters
            let methodTypes: [ObjCMethodType]
            do {
                methodTypes = try ObjCType.parseMethodType(method.typeEncoding)
            }
            catch {
                result += "\(parts[0])(_ ...)"
                return result
            }

            // First part is method name
            result += "\(parts[0])("

            // Build parameters (skip return type at index 0, self at 1, _cmd at 2)
            var paramStrings: [String] = []
            for (i, part) in parts.dropFirst().enumerated() {
                let paramIndex = i + 3  // Account for return, self, _cmd
                let paramName = part.isEmpty ? "_" : String(part)
                let paramType: String
                if paramIndex < methodTypes.count {
                    paramType = swiftType(from: methodTypes[paramIndex].type)
                }
                else {
                    paramType = "Any"
                }
                paramStrings.append("\(paramName): \(paramType)")
            }

            result += paramStrings.joined(separator: ", ")
            result += ")"

            // Return type
            if !methodTypes.isEmpty {
                let returnType = swiftType(from: methodTypes[0].type)
                if returnType != "Void" {
                    result += " -> \(returnType)"
                }
            }
        }

        if options.shouldShowMethodAddresses && method.address != 0 {
            result += String(format: " // IMP=0x%llx", method.address)
        }
        if options.shouldShowRawTypes {
            result += " // \(method.typeEncoding)"
        }

        return result
    }
}
