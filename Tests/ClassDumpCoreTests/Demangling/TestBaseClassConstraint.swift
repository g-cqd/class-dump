// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

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
