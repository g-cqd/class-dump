// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

// MARK: - Conformance Type Reference Kind Tests

@Suite("Conformance Type Reference Kind Tests")
struct ConformanceTypeReferenceKindTests {

    @Test(
        "Raw values are correct",
        arguments: [
            (ConformanceTypeReferenceKind.directTypeDescriptor, UInt8(0)),
            (ConformanceTypeReferenceKind.indirectTypeDescriptor, UInt8(1)),
            (ConformanceTypeReferenceKind.directObjCClass, UInt8(2)),
            (ConformanceTypeReferenceKind.indirectObjCClass, UInt8(3)),
        ])
    func kindRawValues(kind: ConformanceTypeReferenceKind, expectedRaw: UInt8) {
        #expect(kind.rawValue == expectedRaw)
    }

    @Test("Kind can be initialized from raw value")
    func kindFromRawValue() {
        #expect(ConformanceTypeReferenceKind(rawValue: 0) == .directTypeDescriptor)
        #expect(ConformanceTypeReferenceKind(rawValue: 1) == .indirectTypeDescriptor)
        #expect(ConformanceTypeReferenceKind(rawValue: 2) == .directObjCClass)
        #expect(ConformanceTypeReferenceKind(rawValue: 3) == .indirectObjCClass)
        #expect(ConformanceTypeReferenceKind(rawValue: 4) == nil)
        #expect(ConformanceTypeReferenceKind(rawValue: 255) == nil)
    }
}

// MARK: - Conformance Flags Tests

@Suite("Conformance Flags Tests")
struct ConformanceFlagsTests {

    @Test("Default flags have no special attributes")
    func defaultFlags() {
        let flags = ConformanceFlags(rawValue: 0)

        #expect(flags.typeReferenceKind == .directTypeDescriptor)
        #expect(flags.isRetroactive == false)
        #expect(flags.isSynthesizedNonUnique == false)
        #expect(flags.numConditionalRequirements == 0)
        #expect(flags.hasResilientWitnesses == false)
        #expect(flags.hasGenericWitnessTable == false)
    }

    @Test("Type reference kind is extracted from bits 0-2")
    func typeReferenceKindExtraction() {
        #expect(ConformanceFlags(rawValue: 0x0).typeReferenceKind == .directTypeDescriptor)
        #expect(ConformanceFlags(rawValue: 0x1).typeReferenceKind == .indirectTypeDescriptor)
        #expect(ConformanceFlags(rawValue: 0x2).typeReferenceKind == .directObjCClass)
        #expect(ConformanceFlags(rawValue: 0x3).typeReferenceKind == .indirectObjCClass)
    }

    @Test("Retroactive flag is at bit 3")
    func retroactiveFlag() {
        #expect(ConformanceFlags(rawValue: 0x8).isRetroactive == true)
        #expect(ConformanceFlags(rawValue: 0x7).isRetroactive == false)
        #expect(ConformanceFlags(rawValue: 0xF).isRetroactive == true)
    }

    @Test("Synthesized non-unique flag is at bit 4")
    func synthesizedNonUniqueFlag() {
        #expect(ConformanceFlags(rawValue: 0x10).isSynthesizedNonUnique == true)
        #expect(ConformanceFlags(rawValue: 0x0F).isSynthesizedNonUnique == false)
    }

    @Test("Resilient witnesses flag is at bit 5")
    func resilientWitnessesFlag() {
        #expect(ConformanceFlags(rawValue: 0x20).hasResilientWitnesses == true)
        #expect(ConformanceFlags(rawValue: 0x1F).hasResilientWitnesses == false)
    }

    @Test("Generic witness table flag is at bit 6")
    func genericWitnessTableFlag() {
        #expect(ConformanceFlags(rawValue: 0x40).hasGenericWitnessTable == true)
        #expect(ConformanceFlags(rawValue: 0x3F).hasGenericWitnessTable == false)
    }

    @Test("Conditional requirements count is in bits 8-15")
    func conditionalRequirementsCount() {
        #expect(ConformanceFlags(rawValue: 0x0100).numConditionalRequirements == 1)
        #expect(ConformanceFlags(rawValue: 0x0200).numConditionalRequirements == 2)
        #expect(ConformanceFlags(rawValue: 0x0500).numConditionalRequirements == 5)
        #expect(ConformanceFlags(rawValue: 0xFF00).numConditionalRequirements == 255)
        #expect(ConformanceFlags(rawValue: 0x00FF).numConditionalRequirements == 0)
    }

    @Test("Combined flags work correctly")
    func combinedFlags() {
        // Retroactive + indirect type descriptor + 3 conditional requirements
        let flags = ConformanceFlags(rawValue: 0x0309)

        #expect(flags.typeReferenceKind == .indirectTypeDescriptor)
        #expect(flags.isRetroactive == true)
        #expect(flags.numConditionalRequirements == 3)
    }

    @Test("Flags equality works")
    func flagsEquality() {
        let flags1 = ConformanceFlags(rawValue: 0x0108)
        let flags2 = ConformanceFlags(rawValue: 0x0108)
        let flags3 = ConformanceFlags(rawValue: 0x0208)

        #expect(flags1 == flags2)
        #expect(flags1 != flags3)
    }
}

// MARK: - Swift Conformance Tests

@Suite("Swift Conformance Tests")
struct SwiftConformanceTests {

    @Test("Default initializer creates basic conformance")
    func defaultInitializer() {
        let conformance = SwiftConformance(
            typeAddress: 0x1000,
            typeName: "MyType",
            protocolName: "Equatable"
        )

        #expect(conformance.address == 0)
        #expect(conformance.typeAddress == 0x1000)
        #expect(conformance.typeName == "MyType")
        #expect(conformance.mangledTypeName == "")
        #expect(conformance.protocolName == "Equatable")
        #expect(conformance.protocolAddress == 0)
        #expect(conformance.flags.rawValue == 0)
    }

    @Test("Full initializer sets all properties")
    func fullInitializer() {
        let flags = ConformanceFlags(rawValue: 0x0308)
        let conformance = SwiftConformance(
            address: 0x500,
            typeAddress: 0x1000,
            typeName: "MyGeneric",
            mangledTypeName: "$s7MyModule9MyGenericVyxG",
            protocolName: "Hashable",
            protocolAddress: 0x2000,
            flags: flags
        )

        #expect(conformance.address == 0x500)
        #expect(conformance.typeAddress == 0x1000)
        #expect(conformance.typeName == "MyGeneric")
        #expect(conformance.mangledTypeName == "$s7MyModule9MyGenericVyxG")
        #expect(conformance.protocolName == "Hashable")
        #expect(conformance.protocolAddress == 0x2000)
        #expect(conformance.flags.rawValue == 0x0308)
    }

    @Test("isRetroactive is derived from flags")
    func isRetroactiveFromFlags() {
        let retroactive = SwiftConformance(
            typeAddress: 0,
            typeName: "String",
            protocolName: "CustomProtocol",
            flags: ConformanceFlags(rawValue: 0x8)
        )
        let nonRetroactive = SwiftConformance(
            typeAddress: 0,
            typeName: "MyType",
            protocolName: "CustomProtocol",
            flags: ConformanceFlags(rawValue: 0)
        )

        #expect(retroactive.isRetroactive == true)
        #expect(nonRetroactive.isRetroactive == false)
    }

    @Test("isConditional is derived from conditional requirement count")
    func isConditionalFromFlags() {
        let conditional = SwiftConformance(
            typeAddress: 0,
            typeName: "Array",
            protocolName: "Equatable",
            flags: ConformanceFlags(rawValue: 0x0100)  // 1 conditional requirement
        )
        let unconditional = SwiftConformance(
            typeAddress: 0,
            typeName: "Int",
            protocolName: "Equatable",
            flags: ConformanceFlags(rawValue: 0)
        )

        #expect(conditional.isConditional == true)
        #expect(conditional.conditionalRequirementCount == 1)
        #expect(unconditional.isConditional == false)
        #expect(unconditional.conditionalRequirementCount == 0)
    }

    @Test("Description formats correctly")
    func descriptionFormatting() {
        let simple = SwiftConformance(
            typeAddress: 0,
            typeName: "Int",
            protocolName: "Hashable"
        )
        #expect(simple.description == "Int: Hashable")

        let retroactive = SwiftConformance(
            typeAddress: 0,
            typeName: "String",
            protocolName: "MyProtocol",
            flags: ConformanceFlags(rawValue: 0x8)
        )
        #expect(retroactive.description == "String: MyProtocol (retroactive)")

        let conditional = SwiftConformance(
            typeAddress: 0,
            typeName: "Array",
            protocolName: "Equatable",
            flags: ConformanceFlags(rawValue: 0x0200)  // 2 conditional requirements
        )
        #expect(conditional.description == "Array: Equatable (conditional)")

        let both = SwiftConformance(
            typeAddress: 0,
            typeName: "Dictionary",
            protocolName: "Comparable",
            flags: ConformanceFlags(rawValue: 0x0108)  // retroactive + 1 conditional
        )
        #expect(both.description == "Dictionary: Comparable (retroactive) (conditional)")
    }
}

// MARK: - Swift Metadata Conformance Lookup Tests

@Suite("Swift Metadata Conformance Lookup Tests")
struct SwiftMetadataConformanceLookupTests {

    @Test("conformances(forType:) returns matching conformances")
    func conformancesByType() {
        let conformances = [
            SwiftConformance(typeAddress: 0, typeName: "MyType", protocolName: "Equatable"),
            SwiftConformance(typeAddress: 0, typeName: "MyType", protocolName: "Hashable"),
            SwiftConformance(typeAddress: 0, typeName: "OtherType", protocolName: "Codable"),
        ]
        let metadata = SwiftMetadata(conformances: conformances)

        let myTypeConformances = metadata.conformances(forType: "MyType")
        #expect(myTypeConformances.count == 2)
        #expect(myTypeConformances.map(\.protocolName).contains("Equatable"))
        #expect(myTypeConformances.map(\.protocolName).contains("Hashable"))
    }

    @Test("conformances(forProtocol:) returns matching conformances")
    func conformancesByProtocol() {
        let conformances = [
            SwiftConformance(typeAddress: 0, typeName: "Int", protocolName: "Equatable"),
            SwiftConformance(typeAddress: 0, typeName: "String", protocolName: "Equatable"),
            SwiftConformance(typeAddress: 0, typeName: "Array", protocolName: "Collection"),
        ]
        let metadata = SwiftMetadata(conformances: conformances)

        let equatableConformances = metadata.conformances(forProtocol: "Equatable")
        #expect(equatableConformances.count == 2)
        #expect(equatableConformances.map(\.typeName).contains("Int"))
        #expect(equatableConformances.map(\.typeName).contains("String"))
    }

    @Test("protocolNames(forType:) returns protocol names")
    func protocolNamesForType() {
        let conformances = [
            SwiftConformance(typeAddress: 0, typeName: "MyType", protocolName: "Equatable"),
            SwiftConformance(typeAddress: 0, typeName: "MyType", protocolName: "Hashable"),
            SwiftConformance(typeAddress: 0, typeName: "MyType", protocolName: "Codable"),
        ]
        let metadata = SwiftMetadata(conformances: conformances)

        let protocols = metadata.protocolNames(forType: "MyType")
        #expect(protocols.count == 3)
        #expect(protocols.contains("Equatable"))
        #expect(protocols.contains("Hashable"))
        #expect(protocols.contains("Codable"))
    }

    @Test("typeConforms checks for specific conformance")
    func typeConformsCheck() {
        let conformances = [
            SwiftConformance(typeAddress: 0, typeName: "MyType", protocolName: "Equatable"),
            SwiftConformance(typeAddress: 0, typeName: "MyType", protocolName: "Hashable"),
        ]
        let metadata = SwiftMetadata(conformances: conformances)

        #expect(metadata.typeConforms("MyType", to: "Equatable") == true)
        #expect(metadata.typeConforms("MyType", to: "Hashable") == true)
        #expect(metadata.typeConforms("MyType", to: "Codable") == false)
        #expect(metadata.typeConforms("OtherType", to: "Equatable") == false)
    }

    @Test("retroactiveConformances filters correctly")
    func retroactiveConformancesFilter() {
        let conformances = [
            SwiftConformance(
                typeAddress: 0, typeName: "String", protocolName: "MyProtocol",
                flags: ConformanceFlags(rawValue: 0x8)),
            SwiftConformance(
                typeAddress: 0, typeName: "MyType", protocolName: "Equatable",
                flags: ConformanceFlags(rawValue: 0)),
            SwiftConformance(
                typeAddress: 0, typeName: "Int", protocolName: "OtherProtocol",
                flags: ConformanceFlags(rawValue: 0x8)),
        ]
        let metadata = SwiftMetadata(conformances: conformances)

        let retroactive = metadata.retroactiveConformances
        #expect(retroactive.count == 2)
        #expect(retroactive.map(\.typeName).contains("String"))
        #expect(retroactive.map(\.typeName).contains("Int"))
    }

    @Test("conditionalConformances filters correctly")
    func conditionalConformancesFilter() {
        let conformances = [
            SwiftConformance(
                typeAddress: 0, typeName: "Array", protocolName: "Equatable",
                flags: ConformanceFlags(rawValue: 0x0100)),  // 1 conditional
            SwiftConformance(
                typeAddress: 0, typeName: "Int", protocolName: "Equatable",
                flags: ConformanceFlags(rawValue: 0)),
            SwiftConformance(
                typeAddress: 0, typeName: "Optional", protocolName: "Hashable",
                flags: ConformanceFlags(rawValue: 0x0200)),  // 2 conditionals
        ]
        let metadata = SwiftMetadata(conformances: conformances)

        let conditional = metadata.conditionalConformances
        #expect(conditional.count == 2)
        #expect(conditional.map(\.typeName).contains("Array"))
        #expect(conditional.map(\.typeName).contains("Optional"))
    }

    @Test("Empty metadata returns empty results")
    func emptyMetadata() {
        let metadata = SwiftMetadata()

        #expect(metadata.conformances(forType: "MyType").isEmpty)
        #expect(metadata.conformances(forProtocol: "Equatable").isEmpty)
        #expect(metadata.protocolNames(forType: "MyType").isEmpty)
        #expect(metadata.typeConforms("MyType", to: "Equatable") == false)
        #expect(metadata.retroactiveConformances.isEmpty)
        #expect(metadata.conditionalConformances.isEmpty)
    }
}

// MARK: - ObjC Class Swift Conformances Tests

@Suite("ObjC Class Swift Conformances Tests")
struct ObjCClassSwiftConformancesTests {

    @Test("Swift conformances can be added")
    func addSwiftConformance() {
        let cls = ObjCClass(name: "MySwiftClass")

        cls.addSwiftConformance("Equatable")
        cls.addSwiftConformance("Hashable")

        #expect(cls.swiftConformances.count == 2)
        #expect(cls.swiftConformances.contains("Equatable"))
        #expect(cls.swiftConformances.contains("Hashable"))
    }

    @Test("Duplicate Swift conformances are not added")
    func noDuplicateConformances() {
        let cls = ObjCClass(name: "MySwiftClass")

        cls.addSwiftConformance("Equatable")
        cls.addSwiftConformance("Equatable")  // Duplicate

        #expect(cls.swiftConformances.count == 1)
    }

    @Test("Swift conformances can be set in batch")
    func setSwiftConformances() {
        let cls = ObjCClass(name: "MySwiftClass")

        cls.setSwiftConformances(["Codable", "Sendable", "Identifiable"])

        #expect(cls.swiftConformances.count == 3)
        #expect(cls.swiftConformances == ["Codable", "Sendable", "Identifiable"])
    }

    @Test("hasSwiftConformances returns correct value")
    func hasSwiftConformances() {
        let cls = ObjCClass(name: "MySwiftClass")
        #expect(cls.hasSwiftConformances == false)

        cls.addSwiftConformance("Equatable")
        #expect(cls.hasSwiftConformances == true)
    }

    @Test("swiftConformancesString formats correctly")
    func swiftConformancesString() {
        let cls = ObjCClass(name: "MySwiftClass")
        #expect(cls.swiftConformancesString == "")

        cls.addSwiftConformance("Equatable")
        #expect(cls.swiftConformancesString == "<Equatable>")

        cls.addSwiftConformance("Hashable")
        #expect(cls.swiftConformancesString == "<Equatable, Hashable>")
    }

    @Test("protocols property includes Swift conformances")
    func protocolsIncludesSwiftConformances() {
        let cls = ObjCClass(name: "MySwiftClass")
        let objcProtocol = ObjCProtocol(name: "NSCoding")
        cls.addAdoptedProtocol(objcProtocol)
        cls.addSwiftConformance("Codable")

        let protocols = cls.protocols
        #expect(protocols.count == 2)
        #expect(protocols.contains("NSCoding"))
        #expect(protocols.contains("Codable"))
    }

    @Test("protocols avoids duplicates")
    func protocolsAvoidsDuplicates() {
        let cls = ObjCClass(name: "MySwiftClass")
        let objcProtocol = ObjCProtocol(name: "Sendable")
        cls.addAdoptedProtocol(objcProtocol)
        cls.addSwiftConformance("Sendable")  // Same name

        let protocols = cls.protocols
        #expect(protocols.count == 1)
        #expect(protocols == ["Sendable"])
    }

    @Test("sortMembers sorts Swift conformances")
    func sortMembersSortsConformances() {
        let cls = ObjCClass(name: "MySwiftClass")
        cls.setSwiftConformances(["Zebra", "Alpha", "Middle"])

        cls.sortMembers()

        #expect(cls.swiftConformances == ["Alpha", "Middle", "Zebra"])
    }
}

// MARK: - Sendable Conformance Tests

@Suite("Conformance Sendable Tests")
struct ConformanceSendableTests {

    @Test("SwiftConformance is Sendable")
    func conformanceIsSendable() {
        let conformance = SwiftConformance(
            typeAddress: 0,
            typeName: "Test",
            protocolName: "Sendable"
        )
        let _: any Sendable = conformance
        #expect(true)
    }

    @Test("ConformanceFlags is Sendable")
    func flagsIsSendable() {
        let flags = ConformanceFlags(rawValue: 0)
        let _: any Sendable = flags
        #expect(true)
    }

    @Test("ConformanceTypeReferenceKind is Sendable")
    func kindIsSendable() {
        let kind = ConformanceTypeReferenceKind.directTypeDescriptor
        let _: any Sendable = kind
        #expect(true)
    }
}
