// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

/// A visitor that generates mixed Objective-C and Swift output.
///
/// This visitor outputs declarations in both ObjC and Swift syntax, which is
/// useful for understanding bridging between the two languages and generating
/// bridging headers.
///
/// ## Example Output
///
/// ```objc
/// // === Objective-C ===
/// @protocol MyProtocol <NSObject>
/// - (void)requiredMethod;
/// @optional
/// - (void)optionalMethod;
/// @end
///
/// // === Swift ===
/// @objc public protocol MyProtocol : NSObject {
///   @objc func requiredMethod()
///   @objc optional func optionalMethod()
/// }
/// ```
///
public final class MixedOutputVisitor: ClassDumpVisitor, @unchecked Sendable {
    /// The accumulated result string.
    public var resultString: String = ""

    /// Visitor options.
    public var options: ClassDumpVisitorOptions

    /// Type formatter for ObjC output.
    public var objcTypeFormatter: ObjCTypeFormatter

    /// Type formatter for Swift output.
    public var swiftTypeFormatter: ObjCTypeFormatter

    /// Header string to prepend to output.
    public var headerString: String = ""

    /// Current indentation level for Swift output.
    private var swiftIndentLevel: Int = 0

    /// Whether we're in the optional methods section.
    private var inOptionalSection: Bool = false

    /// Buffered ObjC output for current entity.
    private var objcBuffer: String = ""

    /// Buffered Swift output for current entity.
    private var swiftBuffer: String = ""

    /// Current entity name for section headers.
    private var currentEntityName: String = ""

    /// Initialize a mixed output visitor.
    public init(options: ClassDumpVisitorOptions = .init()) {
        self.options = options

        // Configure ObjC type formatter
        var objcFormatterOptions = ObjCTypeFormatterOptions()
        objcFormatterOptions.demangleStyle = options.demangleStyle
        objcFormatterOptions.outputStyle = .objc
        self.objcTypeFormatter = ObjCTypeFormatter(options: objcFormatterOptions)

        // Configure Swift type formatter
        var swiftFormatterOptions = ObjCTypeFormatterOptions()
        swiftFormatterOptions.demangleStyle = options.demangleStyle
        swiftFormatterOptions.outputStyle = .swift
        self.swiftTypeFormatter = ObjCTypeFormatter(options: swiftFormatterOptions)
    }

    // MARK: - Output Helpers

    private var swiftIndent: String {
        String(repeating: "  ", count: swiftIndentLevel)
    }

    private func append(_ text: String) {
        resultString.append(text)
    }

    private func appendLine(_ text: String = "") {
        if text.isEmpty {
            resultString.append("\n")
        }
        else {
            resultString.append("\(text)\n")
        }
    }

    private func appendToObjC(_ text: String) {
        objcBuffer.append(text)
    }

    private func appendLineToObjC(_ text: String = "") {
        if text.isEmpty {
            objcBuffer.append("\n")
        }
        else {
            objcBuffer.append("\(text)\n")
        }
    }

    private func appendToSwift(_ text: String) {
        swiftBuffer.append(text)
    }

    private func appendLineToSwift(_ text: String = "") {
        if text.isEmpty {
            swiftBuffer.append("\n")
        }
        else {
            swiftBuffer.append("\(swiftIndent)\(text)\n")
        }
    }

    /// Flush both buffers to result with section headers.
    private func flushBuffers() {
        if !objcBuffer.isEmpty || !swiftBuffer.isEmpty {
            appendLine(String(repeating: "/", count: 80))
            appendLine("// \(currentEntityName)")
            appendLine(String(repeating: "/", count: 80))
            appendLine()

            if !objcBuffer.isEmpty {
                appendLine("// === Objective-C ===")
                append(objcBuffer)
                appendLine()
            }

            if !swiftBuffer.isEmpty {
                appendLine("// === Swift ===")
                append(swiftBuffer)
                appendLine()
            }

            objcBuffer = ""
            swiftBuffer = ""
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

    // MARK: - Type Conversion for Swift

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

    /// Called when visiting begins, outputs the file header.
    public func willBeginVisiting() {
        if !headerString.isEmpty {
            append(headerString)
        }
        appendLine("/*")
        appendLine(" * Mixed ObjC/Swift output generated by class-dump")
        appendLine(" * This shows declarations in both Objective-C and Swift syntax")
        appendLine(" */")
        appendLine()
        appendLine("#import <Foundation/Foundation.h>")
        appendLine()
    }

    /// Called when visiting ends, writes output to stdout.
    public func didEndVisiting() {
        writeResultToStandardOutput()
    }

    // MARK: - Processor Visits

    /// Called before visiting a processor, sets up type formatters.
    public func willVisitProcessor(_ processor: ObjCProcessorInfo) {
        if let structureRegistry = processor.structureRegistry {
            objcTypeFormatter.structureRegistry = structureRegistry
            swiftTypeFormatter.structureRegistry = structureRegistry
        }
        if let methodSignatureRegistry = processor.methodSignatureRegistry {
            objcTypeFormatter.methodSignatureRegistry = methodSignatureRegistry
            swiftTypeFormatter.methodSignatureRegistry = methodSignatureRegistry
        }
    }

    /// Called to visit processor info, outputs warning if no ObjC info present.
    public func visitProcessor(_ processor: ObjCProcessorInfo) {
        if !processor.hasObjectiveCRuntimeInfo {
            appendLine("// This file does not contain any Objective-C runtime information.")
            appendLine()
        }
    }

    /// Called after visiting a processor.
    public func didVisitProcessor(_ processor: ObjCProcessorInfo) {}

    // MARK: - Protocol Visits

    /// Called before visiting a protocol, outputs protocol declaration.
    public func willVisitProtocol(_ proto: ObjCProtocol) {
        let protoName = demangle(proto.name)
        currentEntityName = "Protocol: \(protoName)"

        objcBuffer = ""
        swiftBuffer = ""
        inOptionalSection = false

        // ObjC format
        appendToObjC("@protocol \(protoName)")
        if !proto.protocols.isEmpty {
            let inherited = proto.protocols.map { demangle($0) }.joined(separator: ", ")
            appendToObjC(" <\(inherited)>")
        }
        appendLineToObjC()

        // Swift format
        appendToSwift("@objc public protocol \(protoName)")
        if !proto.protocols.isEmpty {
            let inherited = proto.protocols.map { demangle($0) }.joined(separator: ", ")
            appendToSwift(" : \(inherited)")
        }
        swiftBuffer.append(" {\n")
        swiftIndentLevel += 1
    }

    /// Called after visiting a protocol, outputs closing syntax.
    public func didVisitProtocol(_ proto: ObjCProtocol) {
        // ObjC format
        appendLineToObjC("@end")

        // Swift format
        swiftIndentLevel -= 1
        appendLineToSwift("}")

        inOptionalSection = false
        flushBuffers()
    }

    /// Called before visiting protocol properties.
    public func willVisitPropertiesOfProtocol(_ proto: ObjCProtocol) {}

    /// Called after visiting protocol properties.
    public func didVisitPropertiesOfProtocol(_ proto: ObjCProtocol) {}

    /// Called when entering optional methods section.
    public func willVisitOptionalMethods() {
        inOptionalSection = true
        appendLineToObjC()
        appendLineToObjC("@optional")
        appendLineToSwift()
        appendLineToSwift("// MARK: - Optional")
    }

    /// Called when leaving optional methods section.
    public func didVisitOptionalMethods() {
        inOptionalSection = false
    }

    // MARK: - Class Visits

    /// Called before visiting a class, outputs class declaration.
    public func willVisitClass(_ objcClass: ObjCClass) {
        let className = demangle(objcClass.name)
        currentEntityName = "Class: \(className)"

        objcBuffer = ""
        swiftBuffer = ""
        inOptionalSection = false

        // ObjC format
        if !objcClass.isExported {
            appendLineToObjC("__attribute__((visibility(\"hidden\")))")
        }
        appendToObjC("@interface \(className)")
        if let superName = objcClass.superclassName {
            appendToObjC(" : \(demangle(superName))")
        }
        if !objcClass.protocols.isEmpty {
            let protos = objcClass.protocols.map { demangle($0) }.joined(separator: ", ")
            appendToObjC(" <\(protos)>")
        }
        appendLineToObjC()

        // Swift format
        var swiftDecl = "@objc"
        if !objcClass.isExported {
            swiftDecl += " @_implementationOnly"
        }
        swiftDecl += " public class \(className)"
        if let superName = objcClass.superclassName {
            swiftDecl += " : \(demangle(superName))"
        }
        if !objcClass.protocols.isEmpty {
            let separator = objcClass.superclassName != nil ? ", " : " : "
            let protos = objcClass.protocols.map { demangle($0) }.joined(separator: ", ")
            swiftDecl += separator + protos
        }
        swiftDecl += " {"
        appendLineToSwift(swiftDecl)
        swiftIndentLevel += 1
    }

    /// Called after visiting a class, outputs closing syntax.
    public func didVisitClass(_ objcClass: ObjCClass) {
        // ObjC format
        if objcClass.hasMethods {
            appendLineToObjC()
        }
        appendLineToObjC("@end")

        // Swift format
        swiftIndentLevel -= 1
        appendLineToSwift("}")

        flushBuffers()
    }

    /// Called before visiting instance variables.
    public func willVisitIvarsOfClass(_ objcClass: ObjCClass) {
        appendLineToObjC("{")
        appendLineToSwift()
        appendLineToSwift("// MARK: - Instance Variables")
    }

    /// Called after visiting instance variables.
    public func didVisitIvarsOfClass(_ objcClass: ObjCClass) {
        appendLineToObjC("}")
        appendLineToObjC()
    }

    /// Called before visiting class properties.
    public func willVisitPropertiesOfClass(_ objcClass: ObjCClass) {}

    /// Called after visiting class properties.
    public func didVisitPropertiesOfClass(_ objcClass: ObjCClass) {
        if !objcClass.properties.isEmpty {
            appendLineToObjC()
        }
    }

    // MARK: - Category Visits

    /// Called before visiting a category, outputs extension declaration.
    public func willVisitCategory(_ category: ObjCCategory) {
        let className = demangle(category.classNameForVisitor)
        let categoryName = category.name
        currentEntityName = "Category: \(className)+\(categoryName)"

        objcBuffer = ""
        swiftBuffer = ""
        inOptionalSection = false

        // ObjC format
        appendToObjC("@interface \(className) (\(categoryName))")
        if !category.protocols.isEmpty {
            let protos = category.protocols.map { demangle($0) }.joined(separator: ", ")
            appendToObjC(" <\(protos)>")
        }
        appendLineToObjC()

        // Swift format
        appendLineToSwift("// MARK: - \(className)+\(categoryName)")
        appendLineToSwift()
        if !category.protocols.isEmpty {
            let protos = category.protocols.map { demangle($0) }.joined(separator: ", ")
            appendLineToSwift("// Conforms to: \(protos)")
        }
        appendLineToSwift("@objc public extension \(className) {")
        swiftIndentLevel += 1
    }

    /// Called after visiting a category, outputs closing syntax.
    public func didVisitCategory(_ category: ObjCCategory) {
        // ObjC format
        appendLineToObjC("@end")

        // Swift format
        swiftIndentLevel -= 1
        appendLineToSwift("}")

        flushBuffers()
    }

    /// Called before visiting category properties.
    public func willVisitPropertiesOfCategory(_ category: ObjCCategory) {
        if !category.properties.isEmpty {
            appendLineToObjC()
        }
    }

    /// Called after visiting category properties.
    public func didVisitPropertiesOfCategory(_ category: ObjCCategory) {
        if !category.properties.isEmpty {
            appendLineToObjC()
        }
    }

    // MARK: - Member Visits

    /// Outputs a class method in both ObjC and Swift formats.
    public func visitClassMethod(_ method: ObjCMethod) {
        // ObjC format
        appendToObjC("+ ")
        appendObjCMethod(method)
        appendLineToObjC()

        // Swift format
        let swiftDecl = formatSwiftMethod(method, isClassMethod: true)
        appendLineToSwift(swiftDecl)
    }

    /// Outputs an instance method in both ObjC and Swift formats, skipping property accessors.
    public func visitInstanceMethod(_ method: ObjCMethod, propertyState: VisitorPropertyState) {
        // Skip property accessors
        if propertyState.property(forAccessor: method.name) != nil {
            return
        }

        // ObjC format
        appendToObjC("- ")
        appendObjCMethod(method)
        appendLineToObjC()

        // Swift format
        let swiftDecl = formatSwiftMethod(method, isClassMethod: false)
        appendLineToSwift(swiftDecl)
    }

    /// Outputs an instance variable in both ObjC and Swift formats.
    public func visitIvar(_ ivar: ObjCInstanceVariable) {
        // ObjC format
        if let parsedType = ivar.parsedType {
            let formatted = objcTypeFormatter.formatVariable(name: ivar.name, type: parsedType)
            appendToObjC("    \(formatted);")
        }
        else if ivar.typeEncoding.isEmpty {
            appendToObjC("    Swift.AnyObject \(ivar.name);")
        }
        else {
            appendToObjC("    /* \(ivar.typeEncoding) */ \(ivar.name);")
        }

        if options.shouldShowIvarOffsets {
            appendToObjC(" // +\(ivar.offset)")
        }
        appendLineToObjC()

        // Swift format
        var typeStr: String
        if !ivar.typeString.isEmpty && ivar.typeString != ivar.typeEncoding {
            typeStr = ivar.typeString
        }
        else if let parsed = ivar.parsedType {
            typeStr = swiftType(from: parsed)
        }
        else {
            typeStr = swiftType(from: ivar.typeEncoding)
        }

        var swiftDecl = "private var \(ivar.name): \(typeStr)"
        if options.shouldShowIvarOffsets && ivar.offset != 0 {
            swiftDecl += String(format: " // offset: 0x%llx", ivar.offset)
        }
        appendLineToSwift(swiftDecl)
    }

    /// Outputs a property in both ObjC and Swift formats.
    public func visitProperty(_ property: ObjCProperty) {
        guard let parsedType = property.parsedType else {
            appendLineToObjC("// Error parsing property: \(property.name)")
            appendLineToSwift("// Error parsing property: \(property.name)")
            return
        }

        // ObjC format
        appendObjCProperty(property, parsedType: parsedType)

        // Swift format
        let typeStr = swiftType(from: parsedType)
        var swiftDecl = inOptionalSection ? "@objc optional " : "@objc "
        if property.isReadOnly {
            swiftDecl += "public var \(property.name): \(typeStr) { get }"
        }
        else {
            swiftDecl += "public var \(property.name): \(typeStr) { get set }"
        }
        appendLineToSwift(swiftDecl)
    }

    /// Called to output any remaining properties not covered by instance methods.
    public func visitRemainingProperties(_ propertyState: VisitorPropertyState) {}

    // MARK: - ObjC Formatting Helpers

    private func appendObjCMethod(_ method: ObjCMethod) {
        if let formatted = objcTypeFormatter.formatMethodName(method.name, typeString: method.typeEncoding) {
            appendToObjC(formatted)
            appendToObjC(";")
        }
        else {
            appendToObjC("(\(method.typeEncoding))\(method.name);")
        }

        if options.shouldShowMethodAddresses && method.address != 0 {
            appendToObjC(String(format: " // IMP=0x%llx", method.address))
        }
        if options.shouldShowRawTypes {
            appendToObjC(" // \(method.typeEncoding)")
        }
    }

    private func appendObjCProperty(_ property: ObjCProperty, parsedType: ObjCType) {
        var attributes: [String] = []
        var isWeak = false

        for attr in property.attributeComponents {
            if attr.hasPrefix("T") {
                // Type attribute - handled separately
            }
            else if attr.hasPrefix("R") {
                attributes.append("readonly")
            }
            else if attr.hasPrefix("C") {
                attributes.append("copy")
            }
            else if attr.hasPrefix("&") {
                attributes.append("retain")
            }
            else if attr.hasPrefix("G") {
                attributes.append("getter=\(String(attr.dropFirst()))")
            }
            else if attr.hasPrefix("S") {
                attributes.append("setter=\(String(attr.dropFirst()))")
            }
            else if attr.hasPrefix("N") {
                attributes.append("nonatomic")
            }
            else if attr.hasPrefix("W") {
                isWeak = true
            }
        }

        if !attributes.isEmpty {
            appendToObjC("@property(\(attributes.joined(separator: ", "))) ")
        }
        else {
            appendToObjC("@property ")
        }

        if isWeak {
            appendToObjC("__weak ")
        }

        let formatted = objcTypeFormatter.formatVariable(name: property.name, type: parsedType)
        appendToObjC("\(formatted);")
        appendLineToObjC()
    }

    // MARK: - Swift Method Formatting

    private func formatSwiftMethod(_ method: ObjCMethod, isClassMethod: Bool) -> String {
        if let formatted = swiftTypeFormatter.formatSwiftMethodName(
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

        // Fallback
        return formatSwiftMethodManual(method, isClassMethod: isClassMethod)
    }

    private func formatSwiftMethodManual(_ method: ObjCMethod, isClassMethod: Bool) -> String {
        var result = inOptionalSection ? "@objc optional " : "@objc "
        result += isClassMethod ? "class func " : "func "

        let parts = method.name.split(separator: ":", omittingEmptySubsequences: false)

        if parts.count == 1 && !method.name.contains(":") {
            result += "\(method.name)()"
        }
        else {
            let methodTypes: [ObjCMethodType]
            do {
                methodTypes = try ObjCType.parseMethodType(method.typeEncoding)
            }
            catch {
                result += "\(parts[0])(_ ...)"
                return result
            }

            result += "\(parts[0])("

            var paramStrings: [String] = []
            for (i, part) in parts.dropFirst().enumerated() {
                let paramIndex = i + 3
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
