// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

@Suite("Bitfield Type Parsing")
struct BitfieldTypeParsingTests {
    @Test("Parse bitfield")
    func parseBitfield() throws {
        let type = try ObjCType.parse("b4")
        #expect(type == .bitfield(size: "4"))
    }

    @Test("Parse large bitfield")
    func parseBitfieldLarge() throws {
        let type = try ObjCType.parse("b32")
        #expect(type == .bitfield(size: "32"))
    }
}
