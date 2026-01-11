// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

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
