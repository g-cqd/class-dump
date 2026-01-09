// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation
import Testing

@testable import ClassDumpCore

// MARK: - Protocol Demangling

@Suite("Protocol Demangling")
struct ProtocolDemanglingTests {
    @Test("Demangle simple protocol name")
    func simpleProtocolName() {
        let mangled = "_TtP10Foundation8Hashable_"
        let result = SwiftDemangler.demangleProtocolName(mangled)

        #expect(result != nil)
        if let (module, name) = result {
            #expect(module == "Foundation")
            #expect(name == "Hashable")
        }
    }

    @Test("Demangle long protocol name")
    func longProtocolName() {
        let mangled = "_TtP15XCSourceControl30XCSourceControlXPCBaseProtocol_"
        let result = SwiftDemangler.demangleProtocolName(mangled)

        #expect(result != nil)
        if let (module, name) = result {
            #expect(module == "XCSourceControl")
            #expect(name == "XCSourceControlXPCBaseProtocol")
        }
    }

    @Test("Non-protocol name returns nil")
    func nonProtocolReturnsNil() {
        // Class name (not protocol)
        #expect(SwiftDemangler.demangleProtocolName("_TtC10Foundation4Date") == nil)

        // Missing trailing underscore
        #expect(SwiftDemangler.demangleProtocolName("_TtP10Foundation8Hashable") == nil)

        // Not _TtP prefix
        #expect(SwiftDemangler.demangleProtocolName("_TtC10Foundation8Hashable_") == nil)
    }
}
