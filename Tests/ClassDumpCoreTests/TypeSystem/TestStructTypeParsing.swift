// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

@Suite("Struct Type Parsing")
struct StructTypeParsingTests {
    @Test("Parse empty struct")
    func parseStructEmpty() throws {
        let type = try ObjCType.parse("{CGPoint}")
        guard case .structure(let name, let members) = type else {
            Issue.record("Expected structure type")
            return
        }
        #expect(name?.name == "CGPoint")
        #expect(members.isEmpty)
    }

    @Test("Parse struct with members")
    func parseStructWithMembers() throws {
        let type = try ObjCType.parse("{CGPoint=dd}")
        guard case .structure(let name, let members) = type else {
            Issue.record("Expected structure type")
            return
        }
        #expect(name?.name == "CGPoint")
        #expect(members.count == 2)
        #expect(members[0].type == .double)
        #expect(members[1].type == .double)
    }

    @Test("Parse struct with named members")
    func parseStructWithNamedMembers() throws {
        let type = try ObjCType.parse("{CGPoint=\"x\"d\"y\"d}")
        guard case .structure(let name, let members) = type else {
            Issue.record("Expected structure type")
            return
        }
        #expect(name?.name == "CGPoint")
        #expect(members.count == 2)
        #expect(members[0].type == .double)
        #expect(members[0].name == "x")
        #expect(members[1].type == .double)
        #expect(members[1].name == "y")
    }

    @Test("Parse nested struct")
    func parseNestedStruct() throws {
        let type = try ObjCType.parse("{CGRect={CGPoint=dd}{CGSize=dd}}")
        guard case .structure(let name, let members) = type else {
            Issue.record("Expected structure type")
            return
        }
        #expect(name?.name == "CGRect")
        #expect(members.count == 2)

        guard case .structure(let originName, _) = members[0].type else {
            Issue.record("Expected nested structure for origin")
            return
        }
        #expect(originName?.name == "CGPoint")

        guard case .structure(let sizeName, _) = members[1].type else {
            Issue.record("Expected nested structure for size")
            return
        }
        #expect(sizeName?.name == "CGSize")
    }
}
