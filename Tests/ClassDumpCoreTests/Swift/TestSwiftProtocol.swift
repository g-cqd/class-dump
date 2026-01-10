// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

// MARK: - Protocol Requirement Kind Tests

@Suite("Protocol Requirement Kind Tests")
struct ProtocolRequirementKindTests {

    @Test(
        "Raw values are correct",
        arguments: [
            (SwiftProtocolRequirement.Kind.baseProtocol, UInt8(0)),
            (SwiftProtocolRequirement.Kind.method, UInt8(1)),
            (SwiftProtocolRequirement.Kind.initializer, UInt8(2)),
            (SwiftProtocolRequirement.Kind.getter, UInt8(3)),
            (SwiftProtocolRequirement.Kind.setter, UInt8(4)),
            (SwiftProtocolRequirement.Kind.readCoroutine, UInt8(5)),
            (SwiftProtocolRequirement.Kind.modifyCoroutine, UInt8(6)),
            (SwiftProtocolRequirement.Kind.associatedTypeAccessFunction, UInt8(7)),
            (SwiftProtocolRequirement.Kind.associatedConformanceAccessFunction, UInt8(8)),
        ]
    )
    func kindRawValues(kind: SwiftProtocolRequirement.Kind, expectedRaw: UInt8) {
        #expect(kind.rawValue == expectedRaw)
    }

    @Test(
        "Kind descriptions are human-readable",
        arguments: [
            (SwiftProtocolRequirement.Kind.baseProtocol, "base protocol"),
            (SwiftProtocolRequirement.Kind.method, "method"),
            (SwiftProtocolRequirement.Kind.initializer, "initializer"),
            (SwiftProtocolRequirement.Kind.getter, "getter"),
            (SwiftProtocolRequirement.Kind.setter, "setter"),
            (SwiftProtocolRequirement.Kind.associatedTypeAccessFunction, "associated type"),
        ]
    )
    func kindDescriptions(kind: SwiftProtocolRequirement.Kind, expectedDescription: String) {
        #expect(kind.description == expectedDescription)
    }

    @Test("Kind can be initialized from raw value")
    func kindFromRawValue() {
        #expect(SwiftProtocolRequirement.Kind(rawValue: 0) == .baseProtocol)
        #expect(SwiftProtocolRequirement.Kind(rawValue: 1) == .method)
        #expect(SwiftProtocolRequirement.Kind(rawValue: 2) == .initializer)
        #expect(SwiftProtocolRequirement.Kind(rawValue: 9) == nil)
        #expect(SwiftProtocolRequirement.Kind(rawValue: 255) == nil)
    }
}

// MARK: - Protocol Requirement Tests

@Suite("Protocol Requirement Tests")
struct ProtocolRequirementTests {

    @Test("Default initializer sets correct defaults")
    func defaultInitializer() {
        let req = SwiftProtocolRequirement(kind: .method, name: "doSomething")

        #expect(req.kind == .method)
        #expect(req.name == "doSomething")
        #expect(req.isInstance == true)
        #expect(req.isAsync == false)
        #expect(req.hasDefaultImplementation == false)
    }

    @Test("Full initializer sets all properties")
    func fullInitializer() {
        let req = SwiftProtocolRequirement(
            kind: .method,
            name: "fetchData",
            isInstance: false,
            isAsync: true,
            hasDefaultImplementation: true
        )

        #expect(req.kind == .method)
        #expect(req.name == "fetchData")
        #expect(req.isInstance == false)
        #expect(req.isAsync == true)
        #expect(req.hasDefaultImplementation == true)
    }

    @Test("Async instance method requirement")
    func asyncInstanceMethod() {
        let req = SwiftProtocolRequirement(
            kind: .method,
            name: "loadAsync",
            isInstance: true,
            isAsync: true
        )

        #expect(req.isInstance == true)
        #expect(req.isAsync == true)
    }

    @Test("Static method requirement")
    func staticMethod() {
        let req = SwiftProtocolRequirement(
            kind: .method,
            name: "shared",
            isInstance: false
        )

        #expect(req.isInstance == false)
    }

    @Test("Associated type requirement")
    func associatedType() {
        let req = SwiftProtocolRequirement(
            kind: .associatedTypeAccessFunction,
            name: "Element"
        )

        #expect(req.kind == .associatedTypeAccessFunction)
        #expect(req.name == "Element")
    }

    @Test("Getter requirement")
    func getterRequirement() {
        let req = SwiftProtocolRequirement(
            kind: .getter,
            name: "count"
        )

        #expect(req.kind == .getter)
        #expect(req.name == "count")
    }

    @Test("Initializer requirement")
    func initializerRequirement() {
        let req = SwiftProtocolRequirement(
            kind: .initializer,
            name: ""
        )

        #expect(req.kind == .initializer)
    }

    @Test("Base protocol requirement")
    func baseProtocolRequirement() {
        let req = SwiftProtocolRequirement(
            kind: .baseProtocol,
            name: "Equatable"
        )

        #expect(req.kind == .baseProtocol)
        #expect(req.name == "Equatable")
    }
}

// MARK: - Swift Protocol Tests

@Suite("Swift Protocol Tests")
struct SwiftProtocolTests {

    @Test("Default initializer creates empty protocol")
    func defaultInitializer() {
        let proto = SwiftProtocol(
            address: 0x1000,
            name: "MyProtocol"
        )

        #expect(proto.address == 0x1000)
        #expect(proto.name == "MyProtocol")
        #expect(proto.mangledName == "")
        #expect(proto.parentName == nil)
        #expect(proto.associatedTypeNames.isEmpty)
        #expect(proto.inheritedProtocols.isEmpty)
        #expect(proto.requirements.isEmpty)
    }

    @Test("Full initializer sets all properties")
    func fullInitializer() {
        let requirements = [
            SwiftProtocolRequirement(kind: .method, name: "doWork"),
            SwiftProtocolRequirement(kind: .getter, name: "value"),
        ]

        let proto = SwiftProtocol(
            address: 0x2000,
            name: "Worker",
            mangledName: "$s10MyModule6WorkerP",
            parentName: "MyModule",
            associatedTypeNames: ["Result", "Error"],
            inheritedProtocols: ["Sendable", "Identifiable"],
            requirements: requirements
        )

        #expect(proto.address == 0x2000)
        #expect(proto.name == "Worker")
        #expect(proto.mangledName == "$s10MyModule6WorkerP")
        #expect(proto.parentName == "MyModule")
        #expect(proto.associatedTypeNames == ["Result", "Error"])
        #expect(proto.inheritedProtocols == ["Sendable", "Identifiable"])
        #expect(proto.requirements.count == 2)
    }

    @Test("Full name includes parent module")
    func fullNameWithParent() {
        let proto = SwiftProtocol(
            address: 0,
            name: "DataSource",
            parentName: "UIKit"
        )

        #expect(proto.fullName == "UIKit.DataSource")
    }

    @Test("Full name without parent is just name")
    func fullNameWithoutParent() {
        let proto = SwiftProtocol(
            address: 0,
            name: "DataSource"
        )

        #expect(proto.fullName == "DataSource")
    }

    @Test("Full name with empty parent is just name")
    func fullNameWithEmptyParent() {
        let proto = SwiftProtocol(
            address: 0,
            name: "DataSource",
            parentName: ""
        )

        #expect(proto.fullName == "DataSource")
    }

    @Test("Method count returns correct value")
    func methodCount() {
        let requirements = [
            SwiftProtocolRequirement(kind: .method, name: "method1"),
            SwiftProtocolRequirement(kind: .method, name: "method2"),
            SwiftProtocolRequirement(kind: .getter, name: "prop"),
            SwiftProtocolRequirement(kind: .initializer, name: ""),
        ]

        let proto = SwiftProtocol(
            address: 0,
            name: "Test",
            requirements: requirements
        )

        #expect(proto.methodCount == 2)
    }

    @Test("Property count returns getter count")
    func propertyCount() {
        let requirements = [
            SwiftProtocolRequirement(kind: .getter, name: "prop1"),
            SwiftProtocolRequirement(kind: .setter, name: "prop1"),
            SwiftProtocolRequirement(kind: .getter, name: "prop2"),
            SwiftProtocolRequirement(kind: .method, name: "method"),
        ]

        let proto = SwiftProtocol(
            address: 0,
            name: "Test",
            requirements: requirements
        )

        #expect(proto.propertyCount == 2)
    }

    @Test("Initializer count returns correct value")
    func initializerCount() {
        let requirements = [
            SwiftProtocolRequirement(kind: .initializer, name: ""),
            SwiftProtocolRequirement(kind: .initializer, name: ""),
            SwiftProtocolRequirement(kind: .method, name: "method"),
        ]

        let proto = SwiftProtocol(
            address: 0,
            name: "Test",
            requirements: requirements
        )

        #expect(proto.initializerCount == 2)
    }

    @Test("Empty protocol has zero counts")
    func emptyProtocolCounts() {
        let proto = SwiftProtocol(address: 0, name: "Empty")

        #expect(proto.methodCount == 0)
        #expect(proto.propertyCount == 0)
        #expect(proto.initializerCount == 0)
    }
}

// MARK: - Protocol with Complex Requirements Tests

@Suite("Protocol Complex Requirements Tests")
struct ProtocolComplexRequirementsTests {

    @Test("Protocol with mixed async and sync methods")
    func mixedAsyncSyncMethods() {
        let requirements = [
            SwiftProtocolRequirement(kind: .method, name: "syncMethod", isAsync: false),
            SwiftProtocolRequirement(kind: .method, name: "asyncMethod", isAsync: true),
            SwiftProtocolRequirement(kind: .method, name: "anotherAsync", isAsync: true),
        ]

        let proto = SwiftProtocol(
            address: 0,
            name: "AsyncWorker",
            requirements: requirements
        )

        let asyncCount = proto.requirements.filter { $0.isAsync }.count
        let syncCount = proto.requirements.filter { !$0.isAsync }.count

        #expect(asyncCount == 2)
        #expect(syncCount == 1)
    }

    @Test("Protocol with default implementations")
    func protocolWithDefaults() {
        let requirements = [
            SwiftProtocolRequirement(kind: .method, name: "required", hasDefaultImplementation: false),
            SwiftProtocolRequirement(kind: .method, name: "optional", hasDefaultImplementation: true),
        ]

        let proto = SwiftProtocol(
            address: 0,
            name: "WithDefaults",
            requirements: requirements
        )

        let withDefault = proto.requirements.filter { $0.hasDefaultImplementation }.count
        let withoutDefault = proto.requirements.filter { !$0.hasDefaultImplementation }.count

        #expect(withDefault == 1)
        #expect(withoutDefault == 1)
    }

    @Test("Protocol with static and instance requirements")
    func staticAndInstanceRequirements() {
        let requirements = [
            SwiftProtocolRequirement(kind: .method, name: "instanceMethod", isInstance: true),
            SwiftProtocolRequirement(kind: .method, name: "staticMethod", isInstance: false),
            SwiftProtocolRequirement(kind: .getter, name: "instanceProp", isInstance: true),
            SwiftProtocolRequirement(kind: .getter, name: "staticProp", isInstance: false),
        ]

        let proto = SwiftProtocol(
            address: 0,
            name: "MixedRequirements",
            requirements: requirements
        )

        let instanceReqs = proto.requirements.filter { $0.isInstance }.count
        let staticReqs = proto.requirements.filter { !$0.isInstance }.count

        #expect(instanceReqs == 2)
        #expect(staticReqs == 2)
    }

    @Test("Protocol inheriting multiple protocols")
    func multipleInheritance() {
        let proto = SwiftProtocol(
            address: 0,
            name: "CombinedProtocol",
            inheritedProtocols: ["Hashable", "Codable", "Sendable", "Identifiable"]
        )

        #expect(proto.inheritedProtocols.count == 4)
        #expect(proto.inheritedProtocols.contains("Hashable"))
        #expect(proto.inheritedProtocols.contains("Codable"))
        #expect(proto.inheritedProtocols.contains("Sendable"))
        #expect(proto.inheritedProtocols.contains("Identifiable"))
    }

    @Test("Protocol with multiple associated types")
    func multipleAssociatedTypes() {
        let proto = SwiftProtocol(
            address: 0,
            name: "Collection",
            associatedTypeNames: ["Element", "Index", "SubSequence", "Iterator"]
        )

        #expect(proto.associatedTypeNames.count == 4)
        #expect(proto.associatedTypeNames.first == "Element")
        #expect(proto.associatedTypeNames.last == "Iterator")
    }
}

// MARK: - Protocol Sendable Conformance Tests

@Suite("Protocol Sendable Conformance Tests")
struct ProtocolSendableTests {

    @Test("SwiftProtocol is Sendable")
    func protocolIsSendable() {
        let proto = SwiftProtocol(address: 0, name: "Test")
        let _: any Sendable = proto
        #expect(true)  // If compilation succeeds, the type is Sendable
    }

    @Test("SwiftProtocolRequirement is Sendable")
    func requirementIsSendable() {
        let req = SwiftProtocolRequirement(kind: .method, name: "test")
        let _: any Sendable = req
        #expect(true)
    }

    @Test("SwiftProtocolRequirement.Kind is Sendable")
    func kindIsSendable() {
        let kind = SwiftProtocolRequirement.Kind.method
        let _: any Sendable = kind
        #expect(true)
    }
}
