// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

@Suite("C++ Template Type Name Tests")
struct CppTemplateTypeNameTests {

    @Test("Parse struct with C++ template name")
    func parseStructWithTemplateName() throws {
        let type = try ObjCType.parse("{std::vector<int>=^i^i}")
        guard case .structure(let name, let members) = type else {
            Issue.record("Expected structure type")
            return
        }
        #expect(name?.description.contains("vector") == true)
        #expect(members.count == 2)
    }

    @Test("Parse nested C++ template")
    func parseNestedTemplate() throws {
        let type = try ObjCType.parse("{map<string, vector<int>>=^i}")
        guard case .structure(let name, _) = type else {
            Issue.record("Expected structure type")
            return
        }
        #expect(name?.description.contains("map") == true)
    }
}
