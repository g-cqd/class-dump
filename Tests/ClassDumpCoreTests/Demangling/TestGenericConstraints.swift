// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

// MARK: - Constraint Kind Tests

@Suite("Constraint Kind Tests")
struct ConstraintKindTests {

    @Test("constraint kinds exist")
    func constraintKindsExist() {
        let conformance = SwiftDemangler.ConstraintKind.conformance
        let sameType = SwiftDemangler.ConstraintKind.sameType
        let layout = SwiftDemangler.ConstraintKind.layout
        let baseClass = SwiftDemangler.ConstraintKind.baseClass

        #expect(conformance == .conformance)
        #expect(sameType == .sameType)
        #expect(layout == .layout)
        #expect(baseClass == .baseClass)
    }

    @Test("constraint kinds are equatable")
    func constraintKindsEquatable() {
        #expect(SwiftDemangler.ConstraintKind.conformance == SwiftDemangler.ConstraintKind.conformance)
        #expect(SwiftDemangler.ConstraintKind.conformance != SwiftDemangler.ConstraintKind.sameType)
    }
}

// MARK: - Demangled Constraint Tests

@Suite("Demangled Constraint Tests")
struct DemangledConstraintTests {

    @Test("conformance constraint formats correctly")
    func conformanceFormat() {
        let constraint = SwiftDemangler.DemangledConstraint(
            subject: "T",
            kind: .conformance,
            constraint: "Hashable"
        )
        #expect(constraint.description == "T: Hashable")
    }

    @Test("same-type constraint formats correctly")
    func sameTypeFormat() {
        let constraint = SwiftDemangler.DemangledConstraint(
            subject: "T",
            kind: .sameType,
            constraint: "Int"
        )
        #expect(constraint.description == "T == Int")
    }

    @Test("layout constraint formats correctly")
    func layoutFormat() {
        let constraint = SwiftDemangler.DemangledConstraint(
            subject: "T",
            kind: .layout,
            constraint: "AnyObject"
        )
        #expect(constraint.description == "T: AnyObject")
    }

    @Test("base class constraint formats correctly")
    func baseClassFormat() {
        let constraint = SwiftDemangler.DemangledConstraint(
            subject: "T",
            kind: .baseClass,
            constraint: "NSObject"
        )
        #expect(constraint.description == "T: NSObject")
    }

    @Test("associated type constraint formats correctly")
    func associatedTypeFormat() {
        let constraint = SwiftDemangler.DemangledConstraint(
            subject: "T.Element",
            kind: .conformance,
            constraint: "Hashable"
        )
        #expect(constraint.description == "T.Element: Hashable")
    }

    @Test("same-type associated type constraint formats correctly")
    func sameTypeAssociatedFormat() {
        let constraint = SwiftDemangler.DemangledConstraint(
            subject: "T.Element",
            kind: .sameType,
            constraint: "String"
        )
        #expect(constraint.description == "T.Element == String")
    }
}

// MARK: - Generic Signature Tests

@Suite("Generic Signature Tests")
struct GenericSignatureTests {

    @Test("empty constraints produce empty where clause")
    func emptyConstraints() {
        let sig = SwiftDemangler.GenericSignature(
            parameters: ["T"],
            constraints: []
        )
        #expect(sig.whereClause == "")
    }

    @Test("single constraint produces where clause")
    func singleConstraint() {
        let sig = SwiftDemangler.GenericSignature(
            parameters: ["T"],
            constraints: [
                SwiftDemangler.DemangledConstraint(
                    subject: "T",
                    kind: .conformance,
                    constraint: "Hashable"
                )
            ]
        )
        #expect(sig.whereClause == "where T: Hashable")
    }

    @Test("multiple constraints joined correctly")
    func multipleConstraints() {
        let sig = SwiftDemangler.GenericSignature(
            parameters: ["T", "U"],
            constraints: [
                SwiftDemangler.DemangledConstraint(
                    subject: "T",
                    kind: .conformance,
                    constraint: "Equatable"
                ),
                SwiftDemangler.DemangledConstraint(
                    subject: "U",
                    kind: .conformance,
                    constraint: "Codable"
                ),
            ]
        )
        #expect(sig.whereClause == "where T: Equatable, U: Codable")
    }

    @Test("mixed constraint types in where clause")
    func mixedConstraints() {
        let sig = SwiftDemangler.GenericSignature(
            parameters: ["T"],
            constraints: [
                SwiftDemangler.DemangledConstraint(
                    subject: "T",
                    kind: .conformance,
                    constraint: "Collection"
                ),
                SwiftDemangler.DemangledConstraint(
                    subject: "T.Element",
                    kind: .sameType,
                    constraint: "String"
                ),
            ]
        )
        #expect(sig.whereClause == "where T: Collection, T.Element == String")
    }
}

// MARK: - Protocol Shortcut Tests

@Suite("Protocol Shortcut Parsing Tests")
struct ProtocolShortcutTests {

    @Test("parses Hashable shortcut (SH)")
    func hashableShortcut() {
        let sig = SwiftDemangler.demangleGenericSignature("SHRzl")
        #expect(sig != nil)
        #expect(sig?.constraints.count == 1)
        #expect(sig?.constraints.first?.constraint == "Hashable")
        #expect(sig?.constraints.first?.kind == .conformance)
    }

    @Test("parses Equatable shortcut (SE)")
    func equatableShortcut() {
        let sig = SwiftDemangler.demangleGenericSignature("SERzl")
        #expect(sig != nil)
        #expect(sig?.constraints.first?.constraint == "Equatable")
    }

    @Test("parses Collection shortcut (Sl)")
    func collectionShortcut() {
        let sig = SwiftDemangler.demangleGenericSignature("SlRzl")
        #expect(sig != nil)
        #expect(sig?.constraints.first?.constraint == "Collection")
    }

    @Test("parses Sequence shortcut (ST)")
    func sequenceShortcut() {
        let sig = SwiftDemangler.demangleGenericSignature("STRzl")
        #expect(sig != nil)
        #expect(sig?.constraints.first?.constraint == "Sequence")
    }

    @Test("parses Comparable shortcut (SL)")
    func comparableShortcut() {
        let sig = SwiftDemangler.demangleGenericSignature("SLRzl")
        #expect(sig != nil)
        #expect(sig?.constraints.first?.constraint == "Comparable")
    }

    @Test("parses Numeric shortcut (Sj)")
    func numericShortcut() {
        let sig = SwiftDemangler.demangleGenericSignature("SjRzl")
        #expect(sig != nil)
        #expect(sig?.constraints.first?.constraint == "Numeric")
    }
}

// MARK: - Conformance Constraint Tests

@Suite("Conformance Constraint Parsing Tests")
struct ConformanceConstraintTests {

    @Test("parses Rz conformance marker")
    func conformanceMarker() {
        let sig = SwiftDemangler.demangleGenericSignature("SHRzl")
        #expect(sig?.constraints.first?.kind == .conformance)
    }

    @Test("parses named protocol conformance")
    func namedProtocol() {
        // Protocol name with length prefix: 8Sendable followed by Rz
        let sig = SwiftDemangler.demangleGenericSignature("8SendableRzl")
        #expect(sig?.constraints.first?.constraint == "Sendable")
    }

    @Test("parses Swift module protocol")
    func swiftModuleProtocol() {
        // s prefix for Swift module: s5Error then P for protocol, then Rz
        let sig = SwiftDemangler.demangleGenericSignature("s5ErrorPRzl")
        #expect(sig?.constraints.first?.constraint == "Error")
    }
}

// MARK: - Same-Type Constraint Tests

@Suite("Same-Type Constraint Parsing Tests")
struct SameTypeConstraintTests {

    @Test("parses Rs same-type marker")
    func sameTypeMarker() {
        // Rs marker followed by type
        let sig = SwiftDemangler.demangleGenericSignature("SiRsl")
        #expect(sig?.constraints.first?.kind == .sameType)
    }

    @Test("same-type to String")
    func sameTypeString() {
        let sig = SwiftDemangler.demangleGenericSignature("SSRsl")
        #expect(sig?.constraints.first?.kind == .sameType)
        #expect(sig?.constraints.first?.constraint == "String")
    }

    @Test("same-type to Int")
    func sameTypeInt() {
        let sig = SwiftDemangler.demangleGenericSignature("SiRsl")
        #expect(sig?.constraints.first?.kind == .sameType)
        #expect(sig?.constraints.first?.constraint == "Int")
    }
}

// MARK: - Layout Constraint Tests

@Suite("Layout Constraint Parsing Tests")
struct LayoutConstraintTests {

    @Test("parses Rl layout marker")
    func layoutMarker() {
        let sig = SwiftDemangler.demangleGenericSignature("Rll")
        #expect(sig?.constraints.first?.kind == .layout)
        #expect(sig?.constraints.first?.constraint == "AnyObject")
    }

    @Test("layout produces AnyObject constraint")
    func layoutAnyObject() {
        let sig = SwiftDemangler.demangleGenericSignature("Rll")
        #expect(sig?.constraints.first?.description == "T: AnyObject")
    }
}

// MARK: - Base Class Constraint Tests

@Suite("Base Class Constraint Parsing Tests")
struct BaseClassConstraintTests {

    @Test("parses Rb base class marker")
    func baseClassMarker() {
        // Rb followed by class name
        let sig = SwiftDemangler.demangleGenericSignature("8NSObjectRbl")
        #expect(sig?.constraints.first?.kind == .baseClass)
    }

    @Test("base class to NSObject")
    func baseClassNSObject() {
        let sig = SwiftDemangler.demangleGenericSignature("8NSObjectRbl")
        #expect(sig?.constraints.first?.constraint == "NSObject")
        #expect(sig?.constraints.first?.description == "T: NSObject")
    }
}

// MARK: - Edge Cases

@Suite("Generic Constraint Edge Cases")
struct GenericConstraintEdgeCases {

    @Test("handles empty input")
    func emptyInput() {
        let sig = SwiftDemangler.demangleGenericSignature("")
        #expect(sig == nil)
    }

    @Test("handles input with only end marker")
    func onlyEndMarker() {
        let sig = SwiftDemangler.demangleGenericSignature("l")
        #expect(sig != nil)
        #expect(sig?.constraints.isEmpty == true)
    }

    @Test("handles unrecognized content gracefully")
    func unrecognizedContent() {
        // Should not crash on unrecognized input
        let sig = SwiftDemangler.demangleGenericSignature("XYZl")
        #expect(sig != nil)
    }

    @Test("demangleWithConstraints returns base name")
    func demangleWithConstraintsBaseName() {
        // _TtC prefix, 10=ModuleName length, 7=MyClass length
        let result = SwiftDemangler.demangleWithConstraints("_TtC10ModuleName7MyClass")
        #expect(result?.name == "ModuleName.MyClass")
    }
}

// MARK: - Sendable Conformance Tests

@Suite("Generic Constraint Sendable Tests")
struct GenericConstraintSendableTests {

    @Test("ConstraintKind is Sendable")
    func constraintKindSendable() async {
        let kind = SwiftDemangler.ConstraintKind.conformance
        let task = Task { kind }
        let result = await task.value
        #expect(result == .conformance)
    }

    @Test("DemangledConstraint is Sendable")
    func demangledConstraintSendable() async {
        let constraint = SwiftDemangler.DemangledConstraint(
            subject: "T",
            kind: .conformance,
            constraint: "Hashable"
        )
        let task = Task { constraint.description }
        let result = await task.value
        #expect(result == "T: Hashable")
    }

    @Test("GenericSignature is Sendable")
    func genericSignatureSendable() async {
        let sig = SwiftDemangler.GenericSignature(
            parameters: ["T"],
            constraints: [
                SwiftDemangler.DemangledConstraint(
                    subject: "T",
                    kind: .conformance,
                    constraint: "Equatable"
                )
            ]
        )
        let task = Task { sig.whereClause }
        let result = await task.value
        #expect(result == "where T: Equatable")
    }
}
