// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

@Suite("Int128 Type Tests")
struct Int128TypeTests {

    @Test("Parse signed __int128 (t)")
    func parseSignedInt128() throws {
        let type = try ObjCType.parse("t")
        #expect(type == .int128)
    }

    @Test("Parse unsigned __int128 (T)")
    func parseUnsignedInt128() throws {
        let type = try ObjCType.parse("T")
        #expect(type == .unsignedInt128)
    }

    @Test("Format signed __int128")
    func formatSignedInt128() {
        #expect(ObjCType.int128.formatted() == "__int128")
    }

    @Test("Format unsigned __int128")
    func formatUnsignedInt128() {
        #expect(ObjCType.unsignedInt128.formatted() == "unsigned __int128")
    }

    @Test("Type string for signed __int128")
    func typeStringSignedInt128() {
        #expect(ObjCType.int128.typeString == "t")
    }

    @Test("Type string for unsigned __int128")
    func typeStringUnsignedInt128() {
        #expect(ObjCType.unsignedInt128.typeString == "T")
    }

    @Test("Round-trip signed __int128")
    func roundTripSignedInt128() throws {
        let type = try ObjCType.parse("t")
        #expect(type.typeString == "t")
    }

    @Test("Round-trip unsigned __int128")
    func roundTripUnsignedInt128() throws {
        let type = try ObjCType.parse("T")
        #expect(type.typeString == "T")
    }

    @Test("Pointer to signed __int128")
    func pointerToSignedInt128() throws {
        let type = try ObjCType.parse("^t")
        #expect(type == .pointer(.int128))
        #expect(type.formatted() == "__int128 *")
    }

    @Test("Pointer to unsigned __int128")
    func pointerToUnsignedInt128() throws {
        let type = try ObjCType.parse("^T")
        #expect(type == .pointer(.unsignedInt128))
        #expect(type.formatted() == "unsigned __int128 *")
    }

    @Test("Array of signed __int128")
    func arrayOfSignedInt128() throws {
        let type = try ObjCType.parse("[4t]")
        #expect(type == .array(count: "4", elementType: .int128))
        #expect(type.formatted() == "__int128 [4]")
    }

    @Test("Struct with __int128 member")
    func structWithInt128Member() throws {
        let type = try ObjCType.parse("{LargeInt=\"low\"Q\"high\"q}")
        guard case .structure(let name, let members) = type else {
            Issue.record("Expected structure type")
            return
        }
        #expect(name?.name == "LargeInt")
        #expect(members.count == 2)
        #expect(members[0].type == .unsignedLongLong)
        #expect(members[0].name == "low")
    }
}
