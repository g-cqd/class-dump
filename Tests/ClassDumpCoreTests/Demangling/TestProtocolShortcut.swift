// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

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
