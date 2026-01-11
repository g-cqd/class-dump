// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

@Suite("Block Type Parsing")
struct BlockTypeParsingTests {
    @Test("Parse simple block")
    func parseBlockSimple() throws {
        let type = try ObjCType.parse("@?")
        #expect(type == .block(types: nil))
    }

    @Test("Parse block with signature")
    func parseBlockWithSignature() throws {
        let type = try ObjCType.parse("@?<v@?>")
        guard case .block(let types) = type else {
            Issue.record("Expected block type")
            return
        }
        #expect(types != nil)
        #expect(types?.count == 2)
        #expect(types?[0] == .void)
    }
}
