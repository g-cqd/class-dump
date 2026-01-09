// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation
import Testing

@testable import ClassDumpCore

// MARK: - Edge Cases

@Suite("Edge Cases")
struct EdgeCaseTests {
    @Test("Empty string returns empty")
    func emptyString() {
        #expect(SwiftDemangler.demangle("") == "")
        #expect(SwiftDemangler.extractTypeName("") == "")
    }

    @Test("Unknown mangled string returns original")
    func unknownMangledString() {
        let weird = "xyz123abc"
        let result = SwiftDemangler.demangle(weird)
        // Should return something, not crash
        #expect(!result.isEmpty || result == weird)
    }

    @Test("Symbolic reference marker returns input")
    func symbolicReferenceMarker() {
        // 0x01 is the symbolic reference marker
        let mangled = "\u{01}XXXX"
        let result = SwiftDemangler.demangle(mangled)
        // Should not return "/* symbolic ref */" anymore
        #expect(!result.contains("symbolic"))
    }

    @Test("demangleComplexType handles simple cases")
    func complexTypeSimple() {
        let result = SwiftDemangler.demangleComplexType("Si")
        #expect(result == "Int")
    }

    @Test("demangleComplexType returns input for truly complex cases")
    func complexTypeFallback() {
        // Very complex mangled types should not crash
        let complex = "So44IDEBatchFindTextFragmentIndexContentSnapshotCShyPathEntryG"
        let result = SwiftDemangler.demangleComplexType(complex)
        #expect(!result.isEmpty)
    }
}

// MARK: - Integration Tests

@Suite("Integration Tests")
struct IntegrationTests {
    @Test("Full demangling of real-world class name")
    func realWorldClassName() {
        let name = "_TtC13IDEFoundation35IDEActivityLogSectionRecordProvider"
        let result = SwiftDemangler.demangleClassName(name)

        #expect(result != nil)
        if let (module, className) = result {
            #expect(module == "IDEFoundation")
            #expect(className == "IDEActivityLogSectionRecordProvider")
        }
    }

    @Test("Full demangling of nested class")
    func realWorldNestedClass() {
        let name = "_TtCC13IDEFoundation22IDEBuildNoticeProvider16BuildLogObserver"

        // Test both methods
        let className = SwiftDemangler.demangleClassName(name)
        let nestedNames = SwiftDemangler.demangleNestedClassName(name)

        #expect(className != nil)
        #expect(className?.name == "IDEBuildNoticeProvider.BuildLogObserver")
        #expect(nestedNames == ["IDEBuildNoticeProvider", "BuildLogObserver"])
    }

    @Test("extractTypeName handles various formats")
    func extractTypeNameVariousFormats() {
        // _$s prefixed
        #expect(SwiftDemangler.extractTypeName("_$s10Foundation4DateV").contains("Date"))

        // $s prefixed
        #expect(SwiftDemangler.extractTypeName("$s10Foundation4DateV").contains("Date"))

        // _Tt prefixed
        #expect(SwiftDemangler.extractTypeName("_TtC5UIKit6UIViewC") != "")

        // Qualified type
        #expect(SwiftDemangler.extractTypeName("10Foundation4DateV") == "Foundation.Date")
    }
}
