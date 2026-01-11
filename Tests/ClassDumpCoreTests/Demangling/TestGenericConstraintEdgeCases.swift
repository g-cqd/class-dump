// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

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
