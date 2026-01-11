// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

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
