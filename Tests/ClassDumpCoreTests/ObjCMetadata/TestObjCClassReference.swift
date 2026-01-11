// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation
import Testing

@testable import ClassDumpCore

@Suite("ObjCClassReference Tests", .serialized)
struct ObjCClassReferenceTests {
    @Test("Internal reference")
    func internalRef() {
        let ref = ObjCClassReference(name: "MyClass", address: 0x1000)
        #expect(!ref.isExternal)
        #expect(ref.name == "MyClass")
    }

    @Test("External reference")
    func externalRef() {
        let ref = ObjCClassReference(name: "NSObject", address: 0)
        #expect(ref.isExternal)
    }
}
