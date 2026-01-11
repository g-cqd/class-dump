// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

@Suite("Complex Nested Struct Tests")
struct ComplexNestedStructTests {

    @Test("Parse deeply nested struct (3 levels)")
    func parseDeeplyNestedStruct() throws {
        // {A={B={C=ii}i}i}
        let type = try ObjCType.parse("{A={B={C=ii}i}i}")
        guard case .structure(let nameA, let membersA) = type else {
            Issue.record("Expected structure type A")
            return
        }
        #expect(nameA?.name == "A")
        #expect(membersA.count == 2)

        guard case .structure(let nameB, let membersB) = membersA[0].type else {
            Issue.record("Expected structure type B")
            return
        }
        #expect(nameB?.name == "B")
        #expect(membersB.count == 2)

        guard case .structure(let nameC, let membersC) = membersB[0].type else {
            Issue.record("Expected structure type C")
            return
        }
        #expect(nameC?.name == "C")
        #expect(membersC.count == 2)
        #expect(membersC[0].type == .int)
        #expect(membersC[1].type == .int)
    }

    @Test("Parse CGRect with full names")
    func parseCGRectFullyNamed() throws {
        let encoding = "{CGRect=\"origin\"{CGPoint=\"x\"d\"y\"d}\"size\"{CGSize=\"width\"d\"height\"d}}"
        let type = try ObjCType.parse(encoding)

        guard case .structure(let name, let members) = type else {
            Issue.record("Expected structure type")
            return
        }
        #expect(name?.name == "CGRect")
        #expect(members.count == 2)
        #expect(members[0].name == "origin")
        #expect(members[1].name == "size")

        guard case .structure(let originName, let originMembers) = members[0].type else {
            Issue.record("Expected structure type for origin")
            return
        }
        #expect(originName?.name == "CGPoint")
        #expect(originMembers.count == 2)
        #expect(originMembers[0].name == "x")
        #expect(originMembers[1].name == "y")
    }

    @Test("Parse struct with pointer member")
    func parseStructWithPointerMember() throws {
        let type = try ObjCType.parse("{Node=\"value\"i\"next\"^{Node}}")
        guard case .structure(let name, let members) = type else {
            Issue.record("Expected structure type")
            return
        }
        #expect(name?.name == "Node")
        #expect(members.count == 2)
        #expect(members[0].name == "value")
        #expect(members[0].type == .int)
        #expect(members[1].name == "next")

        guard case .pointer(let pointee) = members[1].type else {
            Issue.record("Expected pointer type")
            return
        }
        guard case .structure(let pointeeName, _) = pointee else {
            Issue.record("Expected structure pointee")
            return
        }
        #expect(pointeeName?.name == "Node")
    }

    @Test("Parse struct with array member")
    func parseStructWithArrayMember() throws {
        let type = try ObjCType.parse("{Matrix=\"data\"[16d]}")
        guard case .structure(let name, let members) = type else {
            Issue.record("Expected structure type")
            return
        }
        #expect(name?.name == "Matrix")
        #expect(members.count == 1)
        #expect(members[0].name == "data")

        guard case .array(let count, let elementType) = members[0].type else {
            Issue.record("Expected array type")
            return
        }
        #expect(count == "16")
        #expect(elementType == .double)
    }

    @Test("Parse anonymous struct")
    func parseAnonymousStruct() throws {
        let type = try ObjCType.parse("{?=ii}")
        guard case .structure(let name, let members) = type else {
            Issue.record("Expected structure type")
            return
        }
        #expect(name?.name == "?")
        #expect(members.count == 2)
    }

    @Test("Calculate structure depth for deeply nested struct")
    func structureDepthDeeplyNested() throws {
        // 4 levels deep: {A={B={C={D=i}}}}
        let type = try ObjCType.parse("{A={B={C={D=i}}}}")
        #expect(type.structureDepth == 4)
    }
}
