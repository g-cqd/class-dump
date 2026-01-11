// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation

// MARK: - Symbol Graph Visitor

/// A visitor that generates DocC-compatible Symbol Graph JSON output.
///
/// This visitor collects ObjC metadata and outputs it in the Symbol Graph format
/// used by DocC for documentation generation. The output can be consumed by
/// `docc` or other tools that support the Symbol Graph format.
///
/// ## Example Usage
///
/// ```swift
/// let visitor = SymbolGraphVisitor()
/// processor.acceptVisitor(visitor)
/// // visitor.resultString contains Symbol Graph JSON
/// ```
///
/// ## Output Format
///
/// The visitor generates JSON conforming to the Symbol Graph format:
/// ```json
/// {
///   "metadata": { "formatVersion": {...}, "generator": "class-dump" },
///   "module": { "name": "MyFramework", "platform": {...} },
///   "symbols": [...],
///   "relationships": [...]
/// }
/// ```
public final class SymbolGraphVisitor: ClassDumpVisitor, @unchecked Sendable {

    // MARK: - Properties

    /// The accumulated result string.
    public var resultString: String = ""

    /// Visitor options.
    public var options: ClassDumpVisitorOptions

    /// Type formatter for generating type strings.
    public var typeFormatter: ObjCTypeFormatter

    /// Header string (unused for Symbol Graph, but required by protocol).
    public var headerString: String = ""

    // MARK: - Module Info

    private var moduleName: String = "Module"
    private var platform: SymbolGraph.Platform?

    // MARK: - Collected Data

    private var symbols: [SymbolGraph.Symbol] = []
    private var relationships: [SymbolGraph.Relationship] = []

    // MARK: - Current Context

    private var currentProtocol: ObjCProtocol?
    private var currentClass: ObjCClass?
    private var currentCategory: ObjCCategory?
    private var inOptionalSection = false

    // MARK: - Initialization

    /// Initialize a Symbol Graph output visitor.
    ///
    /// - Parameter options: Visitor options for formatting.
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

    /// Build declaration fragments for a method using the type formatter.
    private func methodDeclarationFragments(
        _ method: ObjCMethod,
        isClassMethod: Bool
    ) -> [SymbolGraph.Symbol.DeclarationFragment] {
        guard let methodTypes = try? ObjCType.parseMethodType(method.typeString),
            !methodTypes.isEmpty
        else {
            return DeclarationFragmentBuilder.simpleMethodFragments(
                selector: method.name,
                isClassMethod: isClassMethod
            )
        }

        let returnType = typeFormatter.formatVariable(name: nil, type: methodTypes[0].type)
        let parameterTypes = methodTypes.dropFirst(3)
            .map { methodType in
                typeFormatter.formatVariable(name: nil, type: methodType.type)
            }

        return DeclarationFragmentBuilder.methodFragments(
            selector: method.name,
            isClassMethod: isClassMethod,
            returnType: returnType,
            parameterTypes: parameterTypes
        )
    }

    /// Build function signature for a method.
    private func methodFunctionSignature(
        _ method: ObjCMethod
    ) -> SymbolGraph.Symbol.FunctionSignature? {
        guard let methodTypes = try? ObjCType.parseMethodType(method.typeString),
            !methodTypes.isEmpty
        else {
            return nil
        }

        let returnType = typeFormatter.formatVariable(name: nil, type: methodTypes[0].type)
        let selectorParts = method.name.split(separator: ":", omittingEmptySubsequences: false)
            .dropLast()
            .map(String.init)

        var parameters: [(name: String, type: String)] = []
        for (i, part) in selectorParts.enumerated() {
            let paramIndex = i + 3  // Skip return, self, _cmd
            if paramIndex < methodTypes.count {
                let paramType = typeFormatter.formatVariable(
                    name: nil,
                    type: methodTypes[paramIndex].type
                )
                parameters.append((name: part, type: paramType))
            }
        }

        return FunctionSignatureBuilder.buildSignature(
            returnType: returnType,
            parameters: parameters
        )
    }

    /// Build declaration fragments for a property.
    private func propertyDeclarationFragments(
        _ property: ObjCProperty
    ) -> [SymbolGraph.Symbol.DeclarationFragment] {
        let typeName: String
        if let parsedType = property.parsedType {
            typeName = typeFormatter.formatVariable(name: nil, type: parsedType)
        }
        else {
            typeName = "id"
        }

        let attributes = DeclarationFragmentBuilder.PropertyAttributes(
            isNonatomic: property.isNonatomic,
            isReadOnly: property.isReadOnly,
            isCopy: property.isCopy,
            isWeak: property.isWeak,
            isStrong: property.isRetain
        )

        return DeclarationFragmentBuilder.propertyFragments(
            name: property.name,
            typeName: typeName,
            attributes: attributes
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
        symbols = []
        relationships = []
        moduleName = "Module"
        platform = nil
    }

    /// Called when visiting ends, encodes and outputs Symbol Graph JSON.
    public func didEndVisiting() {
        let graph = SymbolGraph(
            metadata: SymbolGraph.Metadata(
                formatVersion: SymbolGraph.SemanticVersion(major: 0, minor: 6, patch: 0),
                generator: "class-dump"
            ),
            module: SymbolGraph.Module(
                name: moduleName,
                platform: platform
                    ?? SymbolGraph.Platform(
                        operatingSystem: nil,
                        architecture: nil,
                        vendor: "apple"
                    ),
                bystanders: nil
            ),
            symbols: symbols,
            relationships: relationships
        )

        do {
            resultString = try graph.jsonString(prettyPrint: true)
        }
        catch {
            resultString = "{\"error\": \"Failed to encode Symbol Graph: \(error.localizedDescription)\"}"
        }

        writeResultToStandardOutput()
    }

    // MARK: - Processor Visits

    /// Called before visiting a processor, sets up module info.
    public func willVisitProcessor(_ processor: ObjCProcessorInfo) {
        if let structureRegistry = processor.structureRegistry {
            typeFormatter.structureRegistry = structureRegistry
        }
        if let methodSignatureRegistry = processor.methodSignatureRegistry {
            typeFormatter.methodSignatureRegistry = methodSignatureRegistry
        }

        let machO = processor.machOFile

        // Extract module name from filename
        moduleName =
            URL(fileURLWithPath: machO.filename)
            .deletingPathExtension()
            .lastPathComponent

        // Build platform info
        platform = buildPlatformInfo(from: machO)
    }

    /// Build platform info from a Mach-O file info.
    private func buildPlatformInfo(from machO: VisitorMachOFileInfo) -> SymbolGraph.Platform {
        var osInfo: SymbolGraph.Platform.OperatingSystem?

        if let macVersion = machO.minMacOSVersion {
            osInfo = parseOSVersion(macVersion, osName: "macosx")
        }
        else if let iosVersion = machO.minIOSVersion {
            osInfo = parseOSVersion(iosVersion, osName: "ios")
        }

        return SymbolGraph.Platform(
            operatingSystem: osInfo,
            architecture: machO.archName,
            vendor: "apple"
        )
    }

    /// Parse OS version string into structured format.
    private func parseOSVersion(
        _ version: String,
        osName: String
    ) -> SymbolGraph.Platform.OperatingSystem {
        let parts = version.split(separator: ".")
        let major = parts.count > 0 ? Int(parts[0]) ?? 10 : 10
        let minor = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
        let patch = parts.count > 2 ? Int(parts[2]) ?? 0 : 0

        return SymbolGraph.Platform.OperatingSystem(
            name: osName,
            minimumVersion: SymbolGraph.SemanticVersion(
                major: major,
                minor: minor,
                patch: patch
            )
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
        inOptionalSection = false
    }

    /// Called after visiting a protocol, builds and stores protocol symbol.
    public func didVisitProtocol(_ proto: ObjCProtocol) {
        let displayName = demangle(proto.name)
        let preciseId = ObjCSymbolIdentifiers.protocolIdentifier(displayName)

        let adoptedNames = proto.protocols.map(demangle)
        let declFragments = DeclarationFragmentBuilder.protocolFragments(
            name: displayName,
            adoptedProtocols: adoptedNames
        )

        let symbol = SymbolGraph.Symbol(
            identifier: SymbolGraph.Symbol.Identifier(
                precise: preciseId,
                interfaceLanguage: "objective-c"
            ),
            kind: .objcProtocol,
            pathComponents: [displayName],
            names: SymbolGraph.Symbol.Names(
                title: displayName,
                navigator: [.identifier(displayName)],
                subHeading: [.identifier(displayName)]
            ),
            docComment: nil,
            accessLevel: "public",
            declarationFragments: declFragments,
            functionSignature: nil
        )

        symbols.append(symbol)

        // Add conformsTo relationships for adopted protocols
        for adopted in proto.protocols {
            let adoptedName = demangle(adopted)
            relationships.append(
                SymbolGraph.Relationship(
                    source: preciseId,
                    target: ObjCSymbolIdentifiers.protocolIdentifier(adoptedName),
                    kind: SymbolGraph.Relationship.conformsToKind,
                    targetFallback: adoptedName
                )
            )
        }

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
    }

    /// Called after visiting a class, builds and stores class symbol.
    public func didVisitClass(_ objcClass: ObjCClass) {
        let displayName = demangle(objcClass.name)
        let preciseId = ObjCSymbolIdentifiers.classIdentifier(displayName)

        let superclassName = objcClass.superclassName.map(demangle)
        let protocolNames = objcClass.protocols.map(demangle)

        let declFragments = DeclarationFragmentBuilder.classFragments(
            name: displayName,
            superclassName: superclassName,
            protocols: protocolNames
        )

        let symbol = SymbolGraph.Symbol(
            identifier: SymbolGraph.Symbol.Identifier(
                precise: preciseId,
                interfaceLanguage: "objective-c"
            ),
            kind: .objcClass,
            pathComponents: [displayName],
            names: SymbolGraph.Symbol.Names(
                title: displayName,
                navigator: [.identifier(displayName)],
                subHeading: [.identifier(displayName)]
            ),
            docComment: nil,
            accessLevel: objcClass.isExported ? "public" : "internal",
            declarationFragments: declFragments,
            functionSignature: nil
        )

        symbols.append(symbol)

        // Add inheritsFrom relationship for superclass
        if let superclass = superclassName {
            relationships.append(
                SymbolGraph.Relationship(
                    source: preciseId,
                    target: ObjCSymbolIdentifiers.classIdentifier(superclass),
                    kind: SymbolGraph.Relationship.inheritsFromKind,
                    targetFallback: superclass
                )
            )
        }

        // Add conformsTo relationships for protocols
        for proto in protocolNames {
            relationships.append(
                SymbolGraph.Relationship(
                    source: preciseId,
                    target: ObjCSymbolIdentifiers.protocolIdentifier(proto),
                    kind: SymbolGraph.Relationship.conformsToKind,
                    targetFallback: proto
                )
            )
        }

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
    }

    /// Called after visiting a category.
    public func didVisitCategory(_ category: ObjCCategory) {
        // Categories are represented as extensions to the base class
        currentCategory = nil
    }

    /// Called before visiting category properties.
    public func willVisitPropertiesOfCategory(_ category: ObjCCategory) {}

    /// Called after visiting category properties.
    public func didVisitPropertiesOfCategory(_ category: ObjCCategory) {}

    // MARK: - Member Visits

    /// Records a class method in the appropriate context.
    public func visitClassMethod(_ method: ObjCMethod) {
        guard let context = currentMemberContext() else { return }

        let methodId = ObjCSymbolIdentifiers.methodIdentifier(
            selector: method.name,
            isClassMethod: true,
            parentName: context.parentName,
            isProtocol: context.isProtocol
        )

        let symbol = SymbolGraph.Symbol(
            identifier: SymbolGraph.Symbol.Identifier(
                precise: methodId,
                interfaceLanguage: "objective-c"
            ),
            kind: .typeMethod,
            pathComponents: [context.parentName, method.name],
            names: SymbolGraph.Symbol.Names(
                title: method.name,
                navigator: [.identifier(method.name)],
                subHeading: [.text("+"), .identifier(method.name)]
            ),
            docComment: nil,
            accessLevel: "public",
            declarationFragments: methodDeclarationFragments(method, isClassMethod: true),
            functionSignature: methodFunctionSignature(method)
        )

        symbols.append(symbol)
        addMemberRelationship(memberId: methodId, context: context)
    }

    /// Records an instance method in the appropriate context, skipping property accessors.
    public func visitInstanceMethod(_ method: ObjCMethod, propertyState: VisitorPropertyState) {
        // Skip property accessors
        if propertyState.property(forAccessor: method.name) != nil {
            return
        }

        guard let context = currentMemberContext() else { return }

        let methodId = ObjCSymbolIdentifiers.methodIdentifier(
            selector: method.name,
            isClassMethod: false,
            parentName: context.parentName,
            isProtocol: context.isProtocol
        )

        let symbol = SymbolGraph.Symbol(
            identifier: SymbolGraph.Symbol.Identifier(
                precise: methodId,
                interfaceLanguage: "objective-c"
            ),
            kind: .instanceMethod,
            pathComponents: [context.parentName, method.name],
            names: SymbolGraph.Symbol.Names(
                title: method.name,
                navigator: [.identifier(method.name)],
                subHeading: [.text("-"), .identifier(method.name)]
            ),
            docComment: nil,
            accessLevel: "public",
            declarationFragments: methodDeclarationFragments(method, isClassMethod: false),
            functionSignature: methodFunctionSignature(method)
        )

        symbols.append(symbol)
        addMemberRelationship(memberId: methodId, context: context)
    }

    /// Records an instance variable.
    public func visitIvar(_ ivar: ObjCInstanceVariable) {
        guard let cls = currentClass else { return }

        let className = demangle(cls.name)
        let classId = ObjCSymbolIdentifiers.classIdentifier(className)
        let ivarId = ObjCSymbolIdentifiers.ivarIdentifier(name: ivar.name, className: className)

        let typeName: String
        if let parsed = ivar.parsedType {
            typeName = typeFormatter.formatVariable(name: nil, type: parsed)
        }
        else {
            typeName = "id"
        }

        let declFragments = DeclarationFragmentBuilder.ivarFragments(
            name: ivar.name,
            typeName: typeName
        )

        let symbol = SymbolGraph.Symbol(
            identifier: SymbolGraph.Symbol.Identifier(
                precise: ivarId,
                interfaceLanguage: "objective-c"
            ),
            kind: .ivar,
            pathComponents: [className, ivar.name],
            names: SymbolGraph.Symbol.Names(
                title: ivar.name,
                navigator: [.identifier(ivar.name)],
                subHeading: nil
            ),
            docComment: nil,
            accessLevel: "internal",
            declarationFragments: declFragments,
            functionSignature: nil
        )

        symbols.append(symbol)

        relationships.append(
            SymbolGraph.Relationship(
                source: ivarId,
                target: classId,
                kind: SymbolGraph.Relationship.memberOfKind,
                targetFallback: nil
            )
        )
    }

    /// Records a property in the appropriate context.
    public func visitProperty(_ property: ObjCProperty) {
        guard let context = currentMemberContext() else { return }

        let propId = ObjCSymbolIdentifiers.propertyIdentifier(
            name: property.name,
            parentName: context.parentName,
            isProtocol: context.isProtocol
        )

        let symbol = SymbolGraph.Symbol(
            identifier: SymbolGraph.Symbol.Identifier(
                precise: propId,
                interfaceLanguage: "objective-c"
            ),
            kind: .property,
            pathComponents: [context.parentName, property.name],
            names: SymbolGraph.Symbol.Names(
                title: property.name,
                navigator: [.identifier(property.name)],
                subHeading: [.identifier(property.name)]
            ),
            docComment: nil,
            accessLevel: "public",
            declarationFragments: propertyDeclarationFragments(property),
            functionSignature: nil
        )

        symbols.append(symbol)

        let relationshipKind =
            context.isProtocol
            ? SymbolGraph.Relationship.requirementOfKind
            : SymbolGraph.Relationship.memberOfKind

        relationships.append(
            SymbolGraph.Relationship(
                source: propId,
                target: context.parentId,
                kind: relationshipKind,
                targetFallback: nil
            )
        )
    }

    /// Called to output any remaining properties not covered by instance methods.
    public func visitRemainingProperties(_ propertyState: VisitorPropertyState) {}

    // MARK: - Context Helpers

    /// Context for the current member being visited.
    private struct MemberContext {
        let parentName: String
        let parentId: String
        let isProtocol: Bool
    }

    /// Get the current member context based on active protocol/class/category.
    private func currentMemberContext() -> MemberContext? {
        if let proto = currentProtocol {
            let name = demangle(proto.name)
            return MemberContext(
                parentName: name,
                parentId: ObjCSymbolIdentifiers.protocolIdentifier(name),
                isProtocol: true
            )
        }
        else if let cls = currentClass {
            let name = demangle(cls.name)
            return MemberContext(
                parentName: name,
                parentId: ObjCSymbolIdentifiers.classIdentifier(name),
                isProtocol: false
            )
        }
        else if let cat = currentCategory {
            let name = demangle(cat.classNameForVisitor)
            return MemberContext(
                parentName: name,
                parentId: ObjCSymbolIdentifiers.classIdentifier(name),
                isProtocol: false
            )
        }
        return nil
    }

    /// Add a member relationship based on context.
    private func addMemberRelationship(memberId: String, context: MemberContext) {
        let relationshipKind: String
        if context.isProtocol {
            relationshipKind =
                inOptionalSection
                ? SymbolGraph.Relationship.optionalRequirementOfKind
                : SymbolGraph.Relationship.requirementOfKind
        }
        else {
            relationshipKind = SymbolGraph.Relationship.memberOfKind
        }

        relationships.append(
            SymbolGraph.Relationship(
                source: memberId,
                target: context.parentId,
                kind: relationshipKind,
                targetFallback: nil
            )
        )
    }
}
