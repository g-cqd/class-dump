// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

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
