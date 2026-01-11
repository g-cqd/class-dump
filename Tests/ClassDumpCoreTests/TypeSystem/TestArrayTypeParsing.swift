// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

@Suite("Array Type Parsing")
struct ArrayTypeParsingTests {
    @Test("Parse array")
    func parseArray() throws {
        let type = try ObjCType.parse("[10i]")
        #expect(type == .array(count: "10", elementType: .int))
    }

    @Test("Parse nested array")
    func parseNestedArray() throws {
        let type = try ObjCType.parse("[5[3d]]")
        #expect(type == .array(count: "5", elementType: .array(count: "3", elementType: .double)))
    }

    @Test("Parse array of pointers")
    func parseArrayOfPointers() throws {
        let type = try ObjCType.parse("[4^i]")
        #expect(type == .array(count: "4", elementType: .pointer(.int)))
    }
}
