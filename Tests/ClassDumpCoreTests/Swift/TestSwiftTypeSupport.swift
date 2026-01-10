// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation
import Testing

@testable import ClassDumpCore

/// Tests for Swift type support features including extensions, property wrappers, and result builders.
@Suite("Swift Type Support Tests")
struct SwiftTypeSupportTests {

    // MARK: - Swift Extension Tests

    @Test("SwiftExtension stores extension metadata")
    func extensionMetadata() {
        let ext = SwiftExtension(
            address: 0x1000,
            extendedTypeName: "Array",
            mangledExtendedTypeName: "$sSa",
            moduleName: "Swift",
            addedConformances: ["CustomStringConvertible"],
            genericParameters: ["Element"],
            genericParamCount: 1,
            genericRequirements: [
                SwiftGenericRequirement(
                    kind: .protocol,
                    param: "Element",
                    constraint: "Equatable"
                )
            ],
            flags: TypeContextDescriptorFlags(rawValue: 0x81)  // Generic extension
        )

        #expect(ext.address == 0x1000)
        #expect(ext.extendedTypeName == "Array")
        #expect(ext.moduleName == "Swift")
        #expect(ext.isGeneric)
        #expect(ext.addsConformances)
        #expect(ext.hasGenericConstraints)
        #expect(ext.whereClause == "where Element: Equatable")
    }

    @Test("SwiftExtension without generics")
    func nonGenericExtension() {
        let ext = SwiftExtension(
            address: 0x2000,
            extendedTypeName: "String",
            moduleName: "Foundation"
        )

        #expect(!ext.isGeneric)
        #expect(!ext.addsConformances)
        #expect(!ext.hasGenericConstraints)
        #expect(ext.whereClause.isEmpty)
    }

    // MARK: - Property Wrapper Tests

    @Test(
        "SwiftPropertyWrapper detects SwiftUI wrappers",
        arguments: [
            ("State<Int>", SwiftPropertyWrapper.state),
            ("Binding<String>", SwiftPropertyWrapper.binding),
            ("ObservedObject<ViewModel>", SwiftPropertyWrapper.observedObject),
            ("StateObject<Model>", SwiftPropertyWrapper.stateObject),
            ("EnvironmentObject<Settings>", SwiftPropertyWrapper.environmentObject),
            ("Environment<ColorScheme>", SwiftPropertyWrapper.environment),
            ("FocusState<Bool>", SwiftPropertyWrapper.focusState),
            ("AppStorage<String>", SwiftPropertyWrapper.appStorage),
            ("SceneStorage<Int>", SwiftPropertyWrapper.sceneStorage),
            ("FetchRequest<Entity>", SwiftPropertyWrapper.fetchRequest),
            ("Query<Model>", SwiftPropertyWrapper.query),
            ("Bindable<Item>", SwiftPropertyWrapper.bindable),
        ]
    )
    func detectSwiftUIWrappers(typeName: String, expected: SwiftPropertyWrapper) {
        let detected = SwiftPropertyWrapper.detect(from: typeName)
        #expect(detected == expected)
    }

    @Test("SwiftPropertyWrapper detects Combine wrappers")
    func detectCombineWrappers() {
        let detected = SwiftPropertyWrapper.detect(from: "Published<Int>")
        #expect(detected == .published)
    }

    @Test("SwiftPropertyWrapper detects module-qualified names")
    func detectModuleQualifiedWrappers() {
        #expect(SwiftPropertyWrapper.detect(from: "SwiftUI.State<Int>") == .state)
        #expect(SwiftPropertyWrapper.detect(from: "Combine.Published<String>") == .published)
        #expect(SwiftPropertyWrapper.detect(from: "SwiftUI.Binding<Bool>") == .binding)
    }

    @Test("SwiftPropertyWrapper returns nil for non-wrapper types")
    func detectNonWrapperTypes() {
        #expect(SwiftPropertyWrapper.detect(from: "String") == nil)
        #expect(SwiftPropertyWrapper.detect(from: "Array<Int>") == nil)
        #expect(SwiftPropertyWrapper.detect(from: "CustomType") == nil)
        #expect(SwiftPropertyWrapper.detect(from: "") == nil)
    }

    @Test("SwiftPropertyWrapper projected value types")
    func projectedValueTypes() {
        #expect(SwiftPropertyWrapper.state.projectedValueType == "Binding")
        #expect(SwiftPropertyWrapper.binding.projectedValueType == "Binding")
        #expect(SwiftPropertyWrapper.observedObject.projectedValueType == "ObservedObject.Wrapper")
        #expect(SwiftPropertyWrapper.published.projectedValueType == "Published.Publisher")
        #expect(SwiftPropertyWrapper.environment.projectedValueType == nil)
    }

    @Test("SwiftPropertyWrapper view context requirement")
    func viewContextRequirement() {
        #expect(SwiftPropertyWrapper.state.requiresViewContext)
        #expect(SwiftPropertyWrapper.binding.requiresViewContext)
        #expect(!SwiftPropertyWrapper.published.requiresViewContext)
        #expect(!SwiftPropertyWrapper.custom.requiresViewContext)
    }

    @Test("SwiftPropertyWrapperInfo stores wrapper details")
    func wrapperInfo() {
        let info = SwiftPropertyWrapperInfo(
            wrapper: .state,
            wrapperTypeName: "State<Int>",
            wrappedValueType: "Int"
        )

        #expect(info.wrapper == .state)
        #expect(info.wrapperTypeName == "State<Int>")
        #expect(info.wrappedValueType == "Int")
    }

    // MARK: - Result Builder Tests

    @Test(
        "SwiftResultBuilder detects SwiftUI builders",
        arguments: [
            ("ViewBuilder", SwiftResultBuilder.viewBuilder),
            ("SceneBuilder", SwiftResultBuilder.sceneBuilder),
            ("CommandsBuilder", SwiftResultBuilder.commandsBuilder),
            ("ToolbarContentBuilder", SwiftResultBuilder.toolbarContentBuilder),
            ("TableColumnBuilder", SwiftResultBuilder.tableColumnBuilder),
            ("TableRowBuilder", SwiftResultBuilder.tableRowBuilder),
        ]
    )
    func detectSwiftUIBuilders(attributeName: String, expected: SwiftResultBuilder) {
        let detected = SwiftResultBuilder.detect(from: attributeName)
        #expect(detected == expected)
    }

    @Test("SwiftResultBuilder detects module-qualified names")
    func detectModuleQualifiedBuilders() {
        #expect(SwiftResultBuilder.detect(from: "SwiftUI.ViewBuilder") == .viewBuilder)
        #expect(SwiftResultBuilder.detect(from: "SwiftUI.SceneBuilder") == .sceneBuilder)
    }

    @Test("SwiftResultBuilder returns nil for non-builder types")
    func detectNonBuilderTypes() {
        #expect(SwiftResultBuilder.detect(from: "String") == nil)
        #expect(SwiftResultBuilder.detect(from: "MyCustomType") == nil)
        #expect(SwiftResultBuilder.detect(from: "") == nil)
    }

    @Test("SwiftResultBuilderInfo stores builder details")
    func builderInfo() {
        let info = SwiftResultBuilderInfo(
            builder: .viewBuilder,
            builderTypeName: "SwiftUI.ViewBuilder"
        )

        #expect(info.builder == .viewBuilder)
        #expect(info.builderTypeName == "SwiftUI.ViewBuilder")
    }

    // MARK: - SwiftField Property Wrapper Detection

    @Test("SwiftField detects property wrapper from type name")
    func fieldPropertyWrapperDetection() {
        let field = SwiftField(
            name: "count",
            mangledTypeName: "$s7SwiftUI5StateVySiGD",
            typeName: "State<Int>",
            isVar: true
        )

        #expect(field.hasPropertyWrapper)
        let wrapper = field.propertyWrapper
        #expect(wrapper?.wrapper == .state)
        #expect(wrapper?.wrappedValueType == "Int")
    }

    @Test("SwiftField without property wrapper")
    func fieldNoPropertyWrapper() {
        let field = SwiftField(
            name: "value",
            typeName: "String",
            isVar: true
        )

        #expect(!field.hasPropertyWrapper)
        #expect(field.propertyWrapper == nil)
    }

    @Test("SwiftField extracts wrapped type correctly")
    func fieldWrappedTypeExtraction() {
        let field1 = SwiftField(name: "a", typeName: "State<Int>", isVar: true)
        #expect(field1.propertyWrapper?.wrappedValueType == "Int")

        let field2 = SwiftField(name: "b", typeName: "Binding<String?>", isVar: true)
        #expect(field2.propertyWrapper?.wrappedValueType == "String?")

        let field3 = SwiftField(name: "c", typeName: "ObservedObject<MyViewModel>", isVar: true)
        #expect(field3.propertyWrapper?.wrappedValueType == "MyViewModel")
    }

    // MARK: - SwiftTypeDetection Utility Tests

    @Test("SwiftTypeDetection.detectPropertyWrapper works correctly")
    func typeDetectionPropertyWrapper() {
        let info = SwiftTypeDetection.detectPropertyWrapper(from: "State<Bool>")
        #expect(info?.wrapper == .state)
        #expect(info?.wrappedValueType == "Bool")

        #expect(SwiftTypeDetection.detectPropertyWrapper(from: "String") == nil)
    }

    @Test("SwiftTypeDetection.detectResultBuilder works correctly")
    func typeDetectionResultBuilder() {
        let info = SwiftTypeDetection.detectResultBuilder(from: "ViewBuilder")
        #expect(info?.builder == .viewBuilder)

        #expect(SwiftTypeDetection.detectResultBuilder(from: "String") == nil)
    }

    @Test("SwiftTypeDetection.extractGenericParameter extracts correctly")
    func extractGenericParameter() {
        #expect(SwiftTypeDetection.extractGenericParameter(from: "Array<Int>") == "Int")
        #expect(SwiftTypeDetection.extractGenericParameter(from: "Dictionary<String, Int>") == "String, Int")
        #expect(SwiftTypeDetection.extractGenericParameter(from: "State<Bool?>") == "Bool?")
        #expect(SwiftTypeDetection.extractGenericParameter(from: "String") == nil)
        #expect(SwiftTypeDetection.extractGenericParameter(from: "Array<>") == nil)
    }

    @Test("SwiftTypeDetection.detectResultBuilderClosure detects patterns")
    func detectResultBuilderClosure() {
        let result = SwiftTypeDetection.detectResultBuilderClosure(
            from: "@ViewBuilder () -> some View"
        )
        #expect(result?.builder.builder == .viewBuilder)
        #expect(result?.closureType == "() -> some View")

        #expect(SwiftTypeDetection.detectResultBuilderClosure(from: "() -> Void") == nil)
    }

    @Test("SwiftTypeDetection.looksLikeSendableClosure detects patterns")
    func detectSendableClosure() {
        #expect(SwiftTypeDetection.looksLikeSendableClosure("@Sendable () -> Void"))
        #expect(SwiftTypeDetection.looksLikeSendableClosure("@escaping @Sendable () -> Int"))
        #expect(!SwiftTypeDetection.looksLikeSendableClosure("() -> Void"))
    }

    @Test("SwiftTypeDetection.looksLikeActor detects patterns")
    func detectActorPatterns() {
        #expect(SwiftTypeDetection.looksLikeActor("@MainActor func test()"))
        #expect(SwiftTypeDetection.looksLikeActor("actor MyActor"))
        #expect(SwiftTypeDetection.looksLikeActor("@isolated(any) parameter"))
        #expect(!SwiftTypeDetection.looksLikeActor("class MyClass"))
    }

    @Test("SwiftTypeDetection.looksLikeOpaqueType detects patterns")
    func detectOpaqueType() {
        #expect(SwiftTypeDetection.looksLikeOpaqueType("some View"))
        #expect(SwiftTypeDetection.looksLikeOpaqueType("-> some Equatable"))
        #expect(!SwiftTypeDetection.looksLikeOpaqueType("View"))
        #expect(!SwiftTypeDetection.looksLikeOpaqueType("AnyView"))
    }

    // MARK: - SwiftMetadata Extension Lookup Tests

    @Test("SwiftMetadata stores and looks up extensions")
    func metadataExtensionLookup() {
        let ext1 = SwiftExtension(
            address: 0x1000,
            extendedTypeName: "Array",
            moduleName: "MyModule"
        )
        let ext2 = SwiftExtension(
            address: 0x2000,
            extendedTypeName: "Array",
            moduleName: "OtherModule"
        )
        let ext3 = SwiftExtension(
            address: 0x3000,
            extendedTypeName: "String"
        )

        let metadata = SwiftMetadata(extensions: [ext1, ext2, ext3])

        #expect(metadata.extensions.count == 3)
        #expect(metadata.extensions(forType: "Array").count == 2)
        #expect(metadata.extensions(forType: "String").count == 1)
        #expect(metadata.extensions(forType: "Int").isEmpty)
    }

    @Test("SwiftMetadata extension filters work correctly")
    func metadataExtensionFilters() {
        let genericExt = SwiftExtension(
            address: 0x1000,
            extendedTypeName: "Array",
            genericParameters: ["T"],
            genericParamCount: 1,
            genericRequirements: [
                SwiftGenericRequirement(kind: .protocol, param: "T", constraint: "Equatable")
            ]
        )
        let conformanceExt = SwiftExtension(
            address: 0x2000,
            extendedTypeName: "String",
            addedConformances: ["MyProtocol"]
        )
        let simpleExt = SwiftExtension(
            address: 0x3000,
            extendedTypeName: "Int"
        )

        let metadata = SwiftMetadata(extensions: [genericExt, conformanceExt, simpleExt])

        #expect(metadata.genericExtensions.count == 1)
        #expect(metadata.extensionsWithConformances.count == 1)
        #expect(metadata.extensionsWithConstraints.count == 1)
    }

    // MARK: - Generic Requirement Tests

    @Test(
        "SwiftGenericRequirement formats correctly",
        arguments: [
            (GenericRequirementKind.protocol, "T", "Equatable", "T: Equatable"),
            (GenericRequirementKind.sameType, "T", "Int", "T == Int"),
            (GenericRequirementKind.baseClass, "T", "NSObject", "T: NSObject"),
            (GenericRequirementKind.layout, "T", "AnyObject", "T: AnyObject"),
        ]
    )
    func genericRequirementFormatting(
        kind: GenericRequirementKind,
        param: String,
        constraint: String,
        expected: String
    ) {
        let req = SwiftGenericRequirement(kind: kind, param: param, constraint: constraint)
        #expect(req.description == expected)
    }
}
