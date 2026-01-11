// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

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
