// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

// MARK: - JSON Data Structures

/// Root structure for JSON output.
public struct ClassDumpJSON: Codable, Sendable {
    /// Version of the JSON schema.
    public let schemaVersion: String

    /// Generator information.
    public let generator: GeneratorInfo

    /// Information about the Mach-O file.
    public let file: FileInfo?

    /// Protocols declared in the binary.
    public let protocols: [ProtocolJSON]

    /// Classes declared in the binary.
    public let classes: [ClassJSON]

    /// Categories declared in the binary.
    public let categories: [CategoryJSON]

    /// Generator info for provenance.
    public struct GeneratorInfo: Codable, Sendable {
        /// Name of the generator tool.
        public let name: String
        /// Version of the generator.
        public let version: String
        /// ISO 8601 timestamp of generation.
        public let timestamp: String
    }

    /// File metadata.
    public struct FileInfo: Codable, Sendable {
        /// Name of the Mach-O file.
        public let filename: String
        /// UUID of the binary, if present.
        public let uuid: String?
        /// CPU architecture (e.g., "arm64").
        public let architecture: String
        /// Minimum OS version, if available.
        public let minOSVersion: String?
        /// SDK version, if available.
        public let sdkVersion: String?
    }
}

/// JSON representation of an ObjC protocol.
public struct ProtocolJSON: Codable, Sendable {
    /// Display name of the protocol.
    public let name: String
    /// Swift-mangled name, if applicable.
    public let mangledName: String?
    /// Names of protocols this protocol adopts.
    public let adoptedProtocols: [String]
    /// Required class methods.
    public let classMethods: [MethodJSON]
    /// Required instance methods.
    public let instanceMethods: [MethodJSON]
    /// Optional class methods.
    public let optionalClassMethods: [MethodJSON]
    /// Optional instance methods.
    public let optionalInstanceMethods: [MethodJSON]
    /// Declared properties.
    public let properties: [PropertyJSON]
}

/// JSON representation of an ObjC class.
public struct ClassJSON: Codable, Sendable {
    /// Display name of the class.
    public let name: String
    /// Swift-mangled name, if applicable.
    public let mangledName: String?
    /// Virtual address of the class object in hex.
    public let address: String?
    /// Name of the superclass, if any.
    public let superclass: String?
    /// Names of protocols the class adopts.
    public let adoptedProtocols: [String]
    /// Swift protocol conformances.
    public let swiftConformances: [String]
    /// Whether this is a Swift class.
    public let isSwiftClass: Bool
    /// Whether the class is exported (visible).
    public let isExported: Bool
    /// Instance variables declared by the class.
    public let instanceVariables: [IvarJSON]
    /// Class methods.
    public let classMethods: [MethodJSON]
    /// Instance methods.
    public let instanceMethods: [MethodJSON]
    /// Declared properties.
    public let properties: [PropertyJSON]
}

/// JSON representation of an ObjC category.
public struct CategoryJSON: Codable, Sendable {
    /// Name of the category.
    public let name: String
    /// Name of the class being extended.
    public let className: String
    /// Names of protocols the category adopts.
    public let adoptedProtocols: [String]
    /// Class methods added by the category.
    public let classMethods: [MethodJSON]
    /// Instance methods added by the category.
    public let instanceMethods: [MethodJSON]
    /// Properties added by the category.
    public let properties: [PropertyJSON]
}

/// JSON representation of an ObjC method.
public struct MethodJSON: Codable, Sendable {
    /// The method selector name.
    public let selector: String
    /// The ObjC type encoding string.
    public let typeEncoding: String
    /// Implementation address in hex, if available.
    public let address: String?
    /// Parsed return type, if available.
    public let returnType: String?
    /// Method parameters, if parsed.
    public let parameters: [ParameterJSON]?
}

/// JSON representation of a method parameter.
public struct ParameterJSON: Codable, Sendable {
    /// Parameter name from selector, if extractable.
    public let name: String?
    /// Type of the parameter.
    public let type: String
}

/// JSON representation of an ObjC property.
public struct PropertyJSON: Codable, Sendable {
    /// Property name.
    public let name: String
    /// ObjC type encoding string.
    public let typeEncoding: String
    /// Parsed type, if available.
    public let type: String?
    /// Property attribute flags.
    public let attributes: PropertyAttributesJSON
    /// Getter selector name.
    public let getter: String
    /// Setter selector name, if not readonly.
    public let setter: String?
    /// Backing instance variable name, if any.
    public let ivarName: String?
}

/// JSON representation of property attributes.
public struct PropertyAttributesJSON: Codable, Sendable {
    /// Whether the property is readonly.
    public let isReadOnly: Bool
    /// Whether the property uses copy semantics.
    public let isCopy: Bool
    /// Whether the property uses retain/strong semantics.
    public let isRetain: Bool
    /// Whether the property is nonatomic.
    public let isNonatomic: Bool
    /// Whether the property is weak.
    public let isWeak: Bool
    /// Whether the property is @dynamic.
    public let isDynamic: Bool
}

/// JSON representation of an instance variable.
public struct IvarJSON: Codable, Sendable {
    /// Instance variable name.
    public let name: String
    /// ObjC type encoding string.
    public let typeEncoding: String
    /// Parsed type, if available.
    public let type: String?
    /// Offset from object base in hex.
    public let offset: String
    /// Size in bytes, if known.
    public let size: String?
}

// MARK: - JSON Output Visitor

/// A visitor that collects ObjC metadata and outputs JSON.
///
/// This visitor accumulates all protocols, classes, and categories,
/// then serializes them to JSON format when visiting completes.
///
/// ## Example Output
///
/// ```json
/// {
///   "schemaVersion": "1.0",
///   "generator": { "name": "class-dump", "version": "4.0.3" },
///   "protocols": [...],
///   "classes": [...],
///   "categories": [...]
/// }
/// ```
public final class JSONOutputVisitor: ClassDumpVisitor, @unchecked Sendable {
    /// The accumulated result string.
    public var resultString: String = ""

    /// Visitor options.
    public var options: ClassDumpVisitorOptions

    /// Type formatter for generating type strings.
    public var typeFormatter: ObjCTypeFormatter

    /// Header string (unused for JSON, but required by protocol).
    public var headerString: String = ""

    // MARK: - Collected Data

    private var fileInfo: ClassDumpJSON.FileInfo?
    private var protocols: [ProtocolJSON] = []
    private var classes: [ClassJSON] = []
    private var categories: [CategoryJSON] = []

    // MARK: - Current Context

    private var currentProtocol: ObjCProtocol?
    private var currentProtocolClassMethods: [MethodJSON] = []
    private var currentProtocolInstanceMethods: [MethodJSON] = []
    private var currentProtocolOptionalClassMethods: [MethodJSON] = []
    private var currentProtocolOptionalInstanceMethods: [MethodJSON] = []
    private var currentProtocolProperties: [PropertyJSON] = []
    private var inOptionalSection = false

    private var currentClass: ObjCClass?
    private var currentClassIvars: [IvarJSON] = []
    private var currentClassClassMethods: [MethodJSON] = []
    private var currentClassInstanceMethods: [MethodJSON] = []
    private var currentClassProperties: [PropertyJSON] = []

    private var currentCategory: ObjCCategory?
    private var currentCategoryClassMethods: [MethodJSON] = []
    private var currentCategoryInstanceMethods: [MethodJSON] = []
    private var currentCategoryProperties: [PropertyJSON] = []

    /// Initialize a JSON output visitor.
    public init(options: ClassDumpVisitorOptions = .init()) {
        self.options = options

        var formatterOptions = ObjCTypeFormatterOptions()
        formatterOptions.demangleStyle = options.demangleStyle
        self.typeFormatter = ObjCTypeFormatter(options: formatterOptions)
    }

    // MARK: - Helpers

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

    private func hexAddress(_ addr: UInt64) -> String? {
        guard addr != 0, options.shouldShowMethodAddresses else { return nil }
        return String(format: "0x%llx", addr)
    }

    private func formatMethodJSON(_ method: ObjCMethod) -> MethodJSON {
        var returnType: String?
        var parameters: [ParameterJSON]?

        if let methodTypes = try? ObjCType.parseMethodType(method.typeString) {
            if !methodTypes.isEmpty {
                returnType = typeFormatter.formatVariable(name: nil, type: methodTypes[0].type)
            }
            // Skip self (index 1) and _cmd (index 2)
            if methodTypes.count > 3 {
                let selectorParts = method.name.split(separator: ":", omittingEmptySubsequences: false)
                var params: [ParameterJSON] = []
                for (i, methodType) in methodTypes.dropFirst(3).enumerated() {
                    let paramName = i < selectorParts.count ? String(selectorParts[i]) : nil
                    params.append(
                        ParameterJSON(
                            name: paramName,
                            type: typeFormatter.formatVariable(name: nil, type: methodType.type)
                        )
                    )
                }
                parameters = params.isEmpty ? nil : params
            }
        }

        return MethodJSON(
            selector: method.name,
            typeEncoding: method.typeString,
            address: hexAddress(method.address),
            returnType: returnType,
            parameters: parameters
        )
    }

    private func formatPropertyJSON(_ property: ObjCProperty) -> PropertyJSON {
        var typeStr: String?
        if let parsed = property.parsedType {
            typeStr = typeFormatter.formatVariable(name: nil, type: parsed)
        }

        return PropertyJSON(
            name: property.name,
            typeEncoding: property.encodedType,
            type: typeStr,
            attributes: PropertyAttributesJSON(
                isReadOnly: property.isReadOnly,
                isCopy: property.isCopy,
                isRetain: property.isRetain,
                isNonatomic: property.isNonatomic,
                isWeak: property.isWeak,
                isDynamic: property.isDynamic
            ),
            getter: property.getter,
            setter: property.setter,
            ivarName: property.ivarName
        )
    }

    private func formatIvarJSON(_ ivar: ObjCInstanceVariable) -> IvarJSON {
        var typeStr: String?
        if !ivar.typeString.isEmpty && ivar.typeString != ivar.typeEncoding {
            typeStr = ivar.typeString
        }
        else if let parsed = ivar.parsedType {
            typeStr = typeFormatter.formatVariable(name: nil, type: parsed)
        }

        return IvarJSON(
            name: ivar.name,
            typeEncoding: ivar.typeEncoding,
            type: typeStr,
            offset: String(format: "0x%llx", ivar.offset),
            size: ivar.size.map { String($0) }
        )
    }

    // MARK: - Output

    /// Write the result to standard output.
    public func writeResultToStandardOutput() {
        if let data = resultString.data(using: .utf8) {
            FileHandle.standardOutput.write(data)
        }
    }

    // MARK: - Lifecycle

    /// Called when visiting begins, resets state.
    public func willBeginVisiting() {
        // Reset state
        protocols = []
        classes = []
        categories = []
        fileInfo = nil
    }

    /// Called when visiting ends, encodes and outputs JSON.
    public func didEndVisiting() {
        // Build the final JSON structure
        let timestamp = ISO8601DateFormatter().string(from: Date())

        let json = ClassDumpJSON(
            schemaVersion: "1.0",
            generator: ClassDumpJSON.GeneratorInfo(
                name: "class-dump",
                version: "4.0.3",
                timestamp: timestamp
            ),
            file: fileInfo,
            protocols: protocols,
            classes: classes,
            categories: categories
        )

        // Encode to JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let data = try encoder.encode(json)
            resultString = String(data: data, encoding: .utf8) ?? "{}"
        }
        catch {
            resultString = "{\"error\": \"Failed to encode JSON: \(error.localizedDescription)\"}"
        }

        writeResultToStandardOutput()
    }

    // MARK: - Processor Visits

    /// Called before visiting a processor, sets up type formatters and file info.
    public func willVisitProcessor(_ processor: ObjCProcessorInfo) {
        if let structureRegistry = processor.structureRegistry {
            typeFormatter.structureRegistry = structureRegistry
        }
        if let methodSignatureRegistry = processor.methodSignatureRegistry {
            typeFormatter.methodSignatureRegistry = methodSignatureRegistry
        }

        let machO = processor.machOFile
        fileInfo = ClassDumpJSON.FileInfo(
            filename: machO.filename,
            uuid: machO.uuid?.uuidString,
            architecture: machO.archName,
            minOSVersion: machO.minMacOSVersion ?? machO.minIOSVersion,
            sdkVersion: machO.sdkVersion
        )
    }

    /// Called to visit processor info.
    public func visitProcessor(_ processor: ObjCProcessorInfo) {}
    /// Called after visiting a processor.
    public func didVisitProcessor(_ processor: ObjCProcessorInfo) {}

    // MARK: - Protocol Visits

    /// Called before visiting a protocol, initializes state.
    public func willVisitProtocol(_ proto: ObjCProtocol) {
        currentProtocol = proto
        currentProtocolClassMethods = []
        currentProtocolInstanceMethods = []
        currentProtocolOptionalClassMethods = []
        currentProtocolOptionalInstanceMethods = []
        currentProtocolProperties = []
        inOptionalSection = false
    }

    /// Called after visiting a protocol, builds and stores ProtocolJSON.
    public func didVisitProtocol(_ proto: ObjCProtocol) {
        let demangledName = demangle(proto.name)
        let mangledName = demangledName != proto.name ? proto.name : nil

        let protocolJSON = ProtocolJSON(
            name: demangledName,
            mangledName: mangledName,
            adoptedProtocols: proto.protocols.map { demangle($0) },
            classMethods: currentProtocolClassMethods,
            instanceMethods: currentProtocolInstanceMethods,
            optionalClassMethods: currentProtocolOptionalClassMethods,
            optionalInstanceMethods: currentProtocolOptionalInstanceMethods,
            properties: currentProtocolProperties
        )

        protocols.append(protocolJSON)
        currentProtocol = nil
    }

    /// Called before visiting protocol properties.
    public func willVisitPropertiesOfProtocol(_ proto: ObjCProtocol) {}
    /// Called after visiting protocol properties.
    public func didVisitPropertiesOfProtocol(_ proto: ObjCProtocol) {}

    /// Called when entering optional methods section.
    public func willVisitOptionalMethods() {
        inOptionalSection = true
    }

    /// Called when leaving optional methods section.
    public func didVisitOptionalMethods() {
        inOptionalSection = false
    }

    // MARK: - Class Visits

    /// Called before visiting a class, initializes state.
    public func willVisitClass(_ objcClass: ObjCClass) {
        currentClass = objcClass
        currentClassIvars = []
        currentClassClassMethods = []
        currentClassInstanceMethods = []
        currentClassProperties = []
    }

    /// Called after visiting a class, builds and stores ClassJSON.
    public func didVisitClass(_ objcClass: ObjCClass) {
        let demangledName = demangle(objcClass.name)
        let mangledName = demangledName != objcClass.name ? objcClass.name : nil

        let classJSON = ClassJSON(
            name: demangledName,
            mangledName: mangledName,
            address: hexAddress(objcClass.address),
            superclass: objcClass.superclassName.map { demangle($0) },
            adoptedProtocols: objcClass.protocols.map { demangle($0) },
            swiftConformances: objcClass.swiftConformances,
            isSwiftClass: objcClass.isSwiftClass,
            isExported: objcClass.isExported,
            instanceVariables: currentClassIvars,
            classMethods: currentClassClassMethods,
            instanceMethods: currentClassInstanceMethods,
            properties: currentClassProperties
        )

        classes.append(classJSON)
        currentClass = nil
    }

    /// Called before visiting instance variables.
    public func willVisitIvarsOfClass(_ objcClass: ObjCClass) {}
    /// Called after visiting instance variables.
    public func didVisitIvarsOfClass(_ objcClass: ObjCClass) {}
    /// Called before visiting class properties.
    public func willVisitPropertiesOfClass(_ objcClass: ObjCClass) {}
    /// Called after visiting class properties.
    public func didVisitPropertiesOfClass(_ objcClass: ObjCClass) {}

    // MARK: - Category Visits

    /// Called before visiting a category, initializes state.
    public func willVisitCategory(_ category: ObjCCategory) {
        currentCategory = category
        currentCategoryClassMethods = []
        currentCategoryInstanceMethods = []
        currentCategoryProperties = []
    }

    /// Called after visiting a category, builds and stores CategoryJSON.
    public func didVisitCategory(_ category: ObjCCategory) {
        let categoryJSON = CategoryJSON(
            name: category.name,
            className: demangle(category.classNameForVisitor),
            adoptedProtocols: category.protocols.map { demangle($0) },
            classMethods: currentCategoryClassMethods,
            instanceMethods: currentCategoryInstanceMethods,
            properties: currentCategoryProperties
        )

        categories.append(categoryJSON)
        currentCategory = nil
    }

    /// Called before visiting category properties.
    public func willVisitPropertiesOfCategory(_ category: ObjCCategory) {}
    /// Called after visiting category properties.
    public func didVisitPropertiesOfCategory(_ category: ObjCCategory) {}

    // MARK: - Member Visits

    /// Records a class method in the appropriate context.
    public func visitClassMethod(_ method: ObjCMethod) {
        let methodJSON = formatMethodJSON(method)

        if currentProtocol != nil {
            if inOptionalSection {
                currentProtocolOptionalClassMethods.append(methodJSON)
            }
            else {
                currentProtocolClassMethods.append(methodJSON)
            }
        }
        else if currentClass != nil {
            currentClassClassMethods.append(methodJSON)
        }
        else if currentCategory != nil {
            currentCategoryClassMethods.append(methodJSON)
        }
    }

    /// Records an instance method in the appropriate context, skipping property accessors.
    public func visitInstanceMethod(_ method: ObjCMethod, propertyState: VisitorPropertyState) {
        // Skip property accessors
        if propertyState.property(forAccessor: method.name) != nil {
            return
        }

        let methodJSON = formatMethodJSON(method)

        if currentProtocol != nil {
            if inOptionalSection {
                currentProtocolOptionalInstanceMethods.append(methodJSON)
            }
            else {
                currentProtocolInstanceMethods.append(methodJSON)
            }
        }
        else if currentClass != nil {
            currentClassInstanceMethods.append(methodJSON)
        }
        else if currentCategory != nil {
            currentCategoryInstanceMethods.append(methodJSON)
        }
    }

    /// Records an instance variable.
    public func visitIvar(_ ivar: ObjCInstanceVariable) {
        let ivarJSON = formatIvarJSON(ivar)
        currentClassIvars.append(ivarJSON)
    }

    /// Records a property in the appropriate context.
    public func visitProperty(_ property: ObjCProperty) {
        let propertyJSON = formatPropertyJSON(property)

        if currentProtocol != nil {
            currentProtocolProperties.append(propertyJSON)
        }
        else if currentClass != nil {
            currentClassProperties.append(propertyJSON)
        }
        else if currentCategory != nil {
            currentCategoryProperties.append(propertyJSON)
        }
    }

    /// Called to output any remaining properties not covered by instance methods.
    public func visitRemainingProperties(_ propertyState: VisitorPropertyState) {}
}
