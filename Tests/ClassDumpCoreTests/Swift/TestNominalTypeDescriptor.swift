// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

// MARK: - Type Context Descriptor Flags Tests

@Suite("Type Context Descriptor Flags Tests")
struct TypeContextDescriptorFlagsTests {

    @Test("parses kind from flags")
    func parsesKind() {
        // Class kind (16) in low bits
        let classFlags = TypeContextDescriptorFlags(rawValue: 0x10)
        #expect(classFlags.kind == .class)

        // Struct kind (17) in low bits
        let structFlags = TypeContextDescriptorFlags(rawValue: 0x11)
        #expect(structFlags.kind == .struct)

        // Enum kind (18) in low bits
        let enumFlags = TypeContextDescriptorFlags(rawValue: 0x12)
        #expect(enumFlags.kind == .enum)
    }

    @Test("parses isGeneric flag")
    func parsesIsGeneric() {
        // Bit 7 (0x80) indicates generic
        let genericFlags = TypeContextDescriptorFlags(rawValue: 0x90)  // 0x80 | 0x10 (class)
        #expect(genericFlags.isGeneric == true)
        #expect(genericFlags.kind == .class)

        let nonGenericFlags = TypeContextDescriptorFlags(rawValue: 0x10)
        #expect(nonGenericFlags.isGeneric == false)
    }

    @Test("parses isUnique flag")
    func parsesIsUnique() {
        // Bit 6 (0x40) indicates unique
        let uniqueFlags = TypeContextDescriptorFlags(rawValue: 0x50)  // 0x40 | 0x10 (class)
        #expect(uniqueFlags.isUnique == true)

        let nonUniqueFlags = TypeContextDescriptorFlags(rawValue: 0x10)
        #expect(nonUniqueFlags.isUnique == false)
    }

    @Test("parses class-specific hasVTable flag")
    func parsesHasVTable() {
        // Bit 15 (0x8000) indicates vtable
        let withVTable = TypeContextDescriptorFlags(rawValue: 0x8010)
        #expect(withVTable.hasVTable == true)

        let withoutVTable = TypeContextDescriptorFlags(rawValue: 0x0010)
        #expect(withoutVTable.hasVTable == false)
    }

    @Test("parses class-specific hasOverrideTable flag")
    func parsesHasOverrideTable() {
        // Bit 14 (0x4000) indicates override table
        let withOverride = TypeContextDescriptorFlags(rawValue: 0x4010)
        #expect(withOverride.hasOverrideTable == true)

        let withoutOverride = TypeContextDescriptorFlags(rawValue: 0x0010)
        #expect(withoutOverride.hasOverrideTable == false)
    }

    @Test("parses class-specific hasResilientSuperclass flag")
    func parsesHasResilientSuperclass() {
        // Bit 13 (0x2000) indicates resilient superclass
        let resilient = TypeContextDescriptorFlags(rawValue: 0x2010)
        #expect(resilient.hasResilientSuperclass == true)

        let nonResilient = TypeContextDescriptorFlags(rawValue: 0x0010)
        #expect(nonResilient.hasResilientSuperclass == false)
    }

    @Test("parses metadata initialization kind")
    func parsesMetadataInitKind() {
        // Bits 8-9 indicate initialization kind
        let noInit = TypeContextDescriptorFlags(rawValue: 0x0010)
        #expect(noInit.metadataInitializationKind == 0)
        #expect(noInit.hasSingletonMetadataInitialization == false)
        #expect(noInit.hasForeignMetadataInitialization == false)

        let singleton = TypeContextDescriptorFlags(rawValue: 0x0110)  // bit 8 set
        #expect(singleton.metadataInitializationKind == 1)
        #expect(singleton.hasSingletonMetadataInitialization == true)

        let foreign = TypeContextDescriptorFlags(rawValue: 0x0210)  // bit 9 set
        #expect(foreign.metadataInitializationKind == 2)
        #expect(foreign.hasForeignMetadataInitialization == true)
    }

    @Test("combined flags parse correctly")
    func combinedFlags() {
        // Generic class with vtable and unique: 0x8000 | 0x80 | 0x40 | 0x10
        let combined = TypeContextDescriptorFlags(rawValue: 0x80D0)
        #expect(combined.kind == .class)
        #expect(combined.isGeneric == true)
        #expect(combined.isUnique == true)
        #expect(combined.hasVTable == true)
    }
}

// MARK: - Generic Requirement Kind Tests

@Suite("Generic Requirement Kind Tests")
struct GenericRequirementKindTests {

    @Test("raw values match Swift ABI")
    func rawValues() {
        #expect(GenericRequirementKind.protocol.rawValue == 0)
        #expect(GenericRequirementKind.sameType.rawValue == 1)
        #expect(GenericRequirementKind.baseClass.rawValue == 2)
        #expect(GenericRequirementKind.sameConformance.rawValue == 3)
        #expect(GenericRequirementKind.layout.rawValue == 4)
    }

    @Test("all kinds can be created from raw values")
    func fromRawValues() {
        #expect(GenericRequirementKind(rawValue: 0) == .protocol)
        #expect(GenericRequirementKind(rawValue: 1) == .sameType)
        #expect(GenericRequirementKind(rawValue: 2) == .baseClass)
        #expect(GenericRequirementKind(rawValue: 3) == .sameConformance)
        #expect(GenericRequirementKind(rawValue: 4) == .layout)
        #expect(GenericRequirementKind(rawValue: 5) == nil)
    }
}

// MARK: - Swift Generic Requirement Tests

@Suite("Swift Generic Requirement Tests")
struct SwiftGenericRequirementTests {

    @Test("protocol requirement description")
    func protocolDescription() {
        let req = SwiftGenericRequirement(kind: .protocol, param: "T", constraint: "Equatable")
        #expect(req.description == "T: Equatable")
    }

    @Test("same-type requirement description")
    func sameTypeDescription() {
        let req = SwiftGenericRequirement(kind: .sameType, param: "T", constraint: "Int")
        #expect(req.description == "T == Int")
    }

    @Test("base class requirement description")
    func baseClassDescription() {
        let req = SwiftGenericRequirement(kind: .baseClass, param: "T", constraint: "NSObject")
        #expect(req.description == "T: NSObject")
    }

    @Test("layout requirement description for AnyObject")
    func layoutAnyObjectDescription() {
        let req = SwiftGenericRequirement(kind: .layout, param: "T", constraint: "AnyObject")
        #expect(req.description == "T: AnyObject")
    }

    @Test("layout requirement description for class")
    func layoutClassDescription() {
        let req = SwiftGenericRequirement(kind: .layout, param: "T", constraint: "class")
        #expect(req.description == "T: AnyObject")
    }

    @Test("hasKeyArgument flag parsing")
    func hasKeyArgument() {
        let withKey = SwiftGenericRequirement(kind: .protocol, param: "T", constraint: "P", flags: 0x80)
        #expect(withKey.hasKeyArgument == true)

        let withoutKey = SwiftGenericRequirement(kind: .protocol, param: "T", constraint: "P", flags: 0x00)
        #expect(withoutKey.hasKeyArgument == false)
    }

    @Test("hasExtraArgument flag parsing")
    func hasExtraArgument() {
        let withExtra = SwiftGenericRequirement(kind: .protocol, param: "T", constraint: "P", flags: 0x40)
        #expect(withExtra.hasExtraArgument == true)

        let withoutExtra = SwiftGenericRequirement(kind: .protocol, param: "T", constraint: "P", flags: 0x00)
        #expect(withoutExtra.hasExtraArgument == false)
    }
}

// MARK: - Swift Type Tests

@Suite("Swift Type Enhanced Tests")
struct SwiftTypeEnhancedTests {

    @Test("isNestedType detects nested types")
    func isNestedType() {
        // Type nested in a class
        let nested = SwiftType(
            address: 0x1000,
            kind: .struct,
            name: "Inner",
            parentName: "Outer",
            parentKind: .class
        )
        #expect(nested.isNestedType == true)

        // Type in a module (not nested)
        let topLevel = SwiftType(
            address: 0x2000,
            kind: .class,
            name: "MyClass",
            parentName: "MyModule",
            parentKind: .module
        )
        #expect(topLevel.isNestedType == false)

        // Type with no parent kind
        let noParent = SwiftType(
            address: 0x3000,
            kind: .struct,
            name: "Orphan"
        )
        #expect(noParent.isNestedType == false)
    }

    @Test("hasGenericConstraints detects constraints")
    func hasGenericConstraints() {
        let withConstraints = SwiftType(
            address: 0x1000,
            kind: .struct,
            name: "Container",
            genericParameters: ["T"],
            genericParamCount: 1,
            genericRequirements: [
                SwiftGenericRequirement(kind: .protocol, param: "T", constraint: "Equatable")
            ]
        )
        #expect(withConstraints.hasGenericConstraints == true)

        let withoutConstraints = SwiftType(
            address: 0x2000,
            kind: .struct,
            name: "Box",
            genericParameters: ["T"],
            genericParamCount: 1
        )
        #expect(withoutConstraints.hasGenericConstraints == false)
    }

    @Test("whereClause formats correctly")
    func whereClause() {
        let type = SwiftType(
            address: 0x1000,
            kind: .struct,
            name: "Dictionary",
            genericParameters: ["Key", "Value"],
            genericParamCount: 2,
            genericRequirements: [
                SwiftGenericRequirement(kind: .protocol, param: "Key", constraint: "Hashable"),
                SwiftGenericRequirement(kind: .protocol, param: "Value", constraint: "Codable"),
            ]
        )
        #expect(type.whereClause == "where Key: Hashable, Value: Codable")
    }

    @Test("whereClause is empty without constraints")
    func whereClauseEmpty() {
        let type = SwiftType(
            address: 0x1000,
            kind: .class,
            name: "Array",
            genericParameters: ["Element"],
            genericParamCount: 1
        )
        #expect(type.whereClause == "")
    }

    @Test("isUnique reads from flags")
    func isUnique() {
        let unique = SwiftType(
            address: 0x1000,
            kind: .class,
            name: "Unique",
            flags: TypeContextDescriptorFlags(rawValue: 0x50)  // 0x40 (unique) | 0x10 (class)
        )
        #expect(unique.isUnique == true)

        let nonUnique = SwiftType(
            address: 0x2000,
            kind: .class,
            name: "Normal",
            flags: TypeContextDescriptorFlags(rawValue: 0x10)
        )
        #expect(nonUnique.isUnique == false)
    }

    @Test("hasVTable reads from flags for classes")
    func hasVTable() {
        let withVTable = SwiftType(
            address: 0x1000,
            kind: .class,
            name: "WithVTable",
            flags: TypeContextDescriptorFlags(rawValue: 0x8010)  // 0x8000 (vtable) | 0x10 (class)
        )
        #expect(withVTable.hasVTable == true)

        // Struct can't have vtable
        let structWithFlag = SwiftType(
            address: 0x2000,
            kind: .struct,
            name: "Struct",
            flags: TypeContextDescriptorFlags(rawValue: 0x8011)
        )
        #expect(structWithFlag.hasVTable == false)
    }

    @Test("hasResilientSuperclass reads from flags")
    func hasResilientSuperclass() {
        let resilient = SwiftType(
            address: 0x1000,
            kind: .class,
            name: "Resilient",
            flags: TypeContextDescriptorFlags(rawValue: 0x2010)  // 0x2000 (resilient) | 0x10 (class)
        )
        #expect(resilient.hasResilientSuperclass == true)
    }
}

// MARK: - Swift Metadata Lookup Tests

@Suite("Swift Metadata Lookup Tests")
struct SwiftMetadataLookupTests {

    @Test("lookup type by address")
    func lookupByAddress() {
        let type1 = SwiftType(address: 0x1000, kind: .class, name: "ClassA")
        let type2 = SwiftType(address: 0x2000, kind: .struct, name: "StructB")
        let metadata = SwiftMetadata(types: [type1, type2])

        #expect(metadata.type(atAddress: 0x1000)?.name == "ClassA")
        #expect(metadata.type(atAddress: 0x2000)?.name == "StructB")
        #expect(metadata.type(atAddress: 0x3000) == nil)
    }

    @Test("nestedTypes filters correctly")
    func nestedTypes() {
        let nested = SwiftType(
            address: 0x1000,
            kind: .struct,
            name: "Inner",
            parentName: "Outer",
            parentKind: .class
        )
        let topLevel = SwiftType(
            address: 0x2000,
            kind: .class,
            name: "TopLevel",
            parentName: "Module",
            parentKind: .module
        )
        let metadata = SwiftMetadata(types: [nested, topLevel])

        #expect(metadata.nestedTypes.count == 1)
        #expect(metadata.nestedTypes.first?.name == "Inner")
    }

    @Test("typesWithConstraints filters correctly")
    func typesWithConstraints() {
        let constrained = SwiftType(
            address: 0x1000,
            kind: .struct,
            name: "Constrained",
            genericRequirements: [
                SwiftGenericRequirement(kind: .protocol, param: "T", constraint: "Codable")
            ]
        )
        let unconstrained = SwiftType(
            address: 0x2000,
            kind: .struct,
            name: "Unconstrained"
        )
        let metadata = SwiftMetadata(types: [constrained, unconstrained])

        #expect(metadata.typesWithConstraints.count == 1)
        #expect(metadata.typesWithConstraints.first?.name == "Constrained")
    }
}

// MARK: - Sendable Conformance Tests

@Suite("Nominal Type Descriptor Sendable Tests")
struct NominalTypeDescriptorSendableTests {

    @Test("TypeContextDescriptorFlags is Sendable")
    func flagsSendable() async {
        let flags = TypeContextDescriptorFlags(rawValue: 0x8010)
        let task = Task { flags.isGeneric }
        let result = await task.value
        #expect(result == false)
    }

    @Test("GenericRequirementKind is Sendable")
    func kindSendable() async {
        let kind = GenericRequirementKind.protocol
        let task = Task { kind.rawValue }
        let result = await task.value
        #expect(result == 0)
    }

    @Test("SwiftGenericRequirement is Sendable")
    func requirementSendable() async {
        let req = SwiftGenericRequirement(kind: .protocol, param: "T", constraint: "Equatable")
        let task = Task { req.description }
        let result = await task.value
        #expect(result == "T: Equatable")
    }
}
