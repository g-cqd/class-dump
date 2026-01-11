// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation
import Testing

@testable import ClassDumpCore

@Suite("ObjCInstanceVariable Tests", .serialized)
struct ObjCInstanceVariableTests {
    @Test("Basic ivar")
    func basicIvar() {
        let ivar = ObjCInstanceVariable(name: "_name", typeEncoding: "@\"NSString\"", offset: 8)
        #expect(ivar.name == "_name")
        #expect(ivar.typeEncoding == "@\"NSString\"")
        #expect(ivar.offset == 8)
        #expect(ivar.isSynthesized)
    }

    @Test("Non-synthesized ivar")
    func nonSynthesized() {
        let ivar = ObjCInstanceVariable(name: "count", typeEncoding: "Q", offset: 16)
        #expect(!ivar.isSynthesized)
    }

    @Test("Ivar comparison by offset")
    func comparison() {
        let ivar1 = ObjCInstanceVariable(name: "_a", typeEncoding: "i", offset: 8)
        let ivar2 = ObjCInstanceVariable(name: "_b", typeEncoding: "i", offset: 16)
        #expect(ivar1 < ivar2)
    }
}
