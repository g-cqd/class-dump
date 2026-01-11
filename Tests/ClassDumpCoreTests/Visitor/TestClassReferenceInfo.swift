// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

@Suite("ClassReferenceInfo Tests")
struct ClassReferenceInfoTests {
    @Test("ClassReferenceInfo external")
    func classReferenceExternal() {
        let ref = ClassReferenceInfo(
            isExternal: true,
            className: "NSObject",
            frameworkName: "Foundation"
        )

        #expect(ref.isExternal)
        #expect(ref.className == "NSObject")
        #expect(ref.frameworkName == "Foundation")
    }

    @Test("ClassReferenceInfo internal")
    func classReferenceInternal() {
        let ref = ClassReferenceInfo(
            isExternal: false,
            className: "MyClass",
            frameworkName: nil
        )

        #expect(!ref.isExternal)
        #expect(ref.className == "MyClass")
        #expect(ref.frameworkName == nil)
    }
}
