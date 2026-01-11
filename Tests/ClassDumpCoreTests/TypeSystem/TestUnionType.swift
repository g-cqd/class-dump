// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

@Suite("Union Type Tests")
struct UnionTypeTests {

    @Test("Parse simple union")
    func parseSimpleUnion() throws {
        let type = try ObjCType.parse("(Value=id)")
        guard case .union(let name, let members) = type else {
            Issue.record("Expected union type")
            return
        }
        #expect(name?.name == "Value")
        #expect(members.count == 2)  // i and d
    }

    @Test("Parse anonymous union with question mark")
    func parseAnonymousUnion() throws {
        // Anonymous unions use ? as placeholder name
        let type = try ObjCType.parse("(?=iQ)")
        guard case .union(let name, let members) = type else {
            Issue.record("Expected union type")
            return
        }
        #expect(name?.name == "?")
        #expect(members.count == 2)
        #expect(members[0].type == .int)
        #expect(members[1].type == .unsignedLongLong)
    }

    @Test("Parse union with named members")
    func parseUnionWithNamedMembers() throws {
        let type = try ObjCType.parse("(Data=\"intVal\"i\"floatVal\"f)")
        guard case .union(let name, let members) = type else {
            Issue.record("Expected union type")
            return
        }
        #expect(name?.name == "Data")
        #expect(members.count == 2)
        #expect(members[0].name == "intVal")
        #expect(members[0].type == .int)
        #expect(members[1].name == "floatVal")
        #expect(members[1].type == .float)
    }

    @Test("Parse pointer to union")
    func parsePointerToUnion() throws {
        let type = try ObjCType.parse("^(Value=id)")
        guard case .pointer(let pointee) = type else {
            Issue.record("Expected pointer type")
            return
        }
        guard case .union(let name, _) = pointee else {
            Issue.record("Expected union pointee")
            return
        }
        #expect(name?.name == "Value")
    }

    @Test("Parse struct containing union")
    func parseStructContainingUnion() throws {
        let type = try ObjCType.parse("{Container=\"tag\"i\"value\"(Data=id)}")
        guard case .structure(let name, let members) = type else {
            Issue.record("Expected structure type")
            return
        }
        #expect(name?.name == "Container")
        #expect(members.count == 2)
        #expect(members[0].name == "tag")

        guard case .union(let unionName, _) = members[1].type else {
            Issue.record("Expected union type for value member")
            return
        }
        #expect(unionName?.name == "Data")
    }

    @Test("Format union type")
    func formatUnionType() throws {
        let type = try ObjCType.parse("(Value=id)")
        #expect(type.formatted().contains("union Value"))
    }

    @Test("Union type string round-trip")
    func unionTypeStringRoundTrip() throws {
        let type = try ObjCType.parse("(Value=id)")
        let typeString = type.typeString
        #expect(typeString == "(Value=id)")
    }
}
