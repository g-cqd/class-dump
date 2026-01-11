// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

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
