// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

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
