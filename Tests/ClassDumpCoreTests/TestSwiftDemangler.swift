// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

@Suite("Swift Demangler Tests")
struct TestSwiftDemangler {
    @Test("Demangle ObjC Swift class name")
    func testDemangleClassName() throws {
        let name = "_TtC13IDEFoundation16IDEActionHistory"
        let result = SwiftDemangler.demangleClassName(name)

        #expect(result != nil, "Should demangle Swift class name")
        if let (module, className) = result {
            #expect(module == "IDEFoundation", "Module should be IDEFoundation")
            #expect(className == "IDEActionHistory", "Class should be IDEActionHistory")
        }
    }

    @Test("Demangle long class name")
    func testDemangleLongClassName() throws {
        let name = "_TtC13IDEFoundation61IDETestTagReferenceTreeItemCollectionSourceConsolidatedSource"
        let result = SwiftDemangler.demangleClassName(name)

        #expect(result != nil, "Should demangle long Swift class name")
        if let (module, className) = result {
            #expect(module == "IDEFoundation")
            #expect(
                className == "IDETestTagReferenceTreeItemCollectionSourceConsolidatedSource",
                "Class name: \(className)"
            )
        }
    }

    @Test("Extract type name from simple mangled name")
    func testExtractTypeName() throws {
        // Simple mangled struct
        #expect(SwiftDemangler.demangle("Sb") == "Bool")
        #expect(SwiftDemangler.demangle("Si") == "Int")
        #expect(SwiftDemangler.demangle("SS") == "String")
    }
}
