// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

@Suite("Bitfield Edge Cases")
struct BitfieldEdgeCaseTests {

    @Test("Parse single bit bitfield")
    func parseSingleBitBitfield() throws {
        let type = try ObjCType.parse("b1")
        #expect(type == .bitfield(size: "1"))
    }

    @Test("Parse maximum reasonable bitfield")
    func parseMaxBitfield() throws {
        let type = try ObjCType.parse("b64")
        #expect(type == .bitfield(size: "64"))
    }

    @Test("Parse struct with multiple bitfields")
    func parseStructWithBitfields() throws {
        let type = try ObjCType.parse("{Flags=\"a\"b1\"b\"b2\"c\"b5}")
        guard case .structure(let name, let members) = type else {
            Issue.record("Expected structure type")
            return
        }
        #expect(name?.name == "Flags")
        #expect(members.count == 3)
        #expect(members[0].type == .bitfield(size: "1"))
        #expect(members[1].type == .bitfield(size: "2"))
        #expect(members[2].type == .bitfield(size: "5"))
    }

    @Test("Format bitfield with variable name")
    func formatBitfieldWithName() {
        let formatted = ObjCType.bitfield(size: "3").formatted(variableName: "flags")
        #expect(formatted == "unsigned int flags:3")
    }
}
