// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

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
