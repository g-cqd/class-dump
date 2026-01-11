// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

@Suite("Pointer Type Parsing")
struct PointerTypeParsingTests {
    @Test("Parse pointer to int")
    func parsePointerToInt() throws {
        let type = try ObjCType.parse("^i")
        #expect(type == .pointer(.int))
    }

    @Test("Parse pointer to pointer")
    func parsePointerToPointer() throws {
        let type = try ObjCType.parse("^^i")
        #expect(type == .pointer(.pointer(.int)))
    }

    @Test("Parse pointer to void")
    func parsePointerToVoid() throws {
        let type = try ObjCType.parse("^v")
        #expect(type == .pointer(.void))
    }

    @Test("Parse function pointer")
    func parseFunctionPointer() throws {
        let type = try ObjCType.parse("^?")
        #expect(type == .functionPointer)
    }
}
