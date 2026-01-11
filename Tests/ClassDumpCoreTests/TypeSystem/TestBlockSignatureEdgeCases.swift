// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

@Suite("Block Signature Edge Cases")
struct BlockSignatureEdgeCaseTests {

    @Test("Parse block returning void with no arguments")
    func parseVoidBlockNoArgs() throws {
        let type = try ObjCType.parse("@?<v@?>")
        guard case .block(let types) = type else {
            Issue.record("Expected block type")
            return
        }
        #expect(types?.count == 2)  // void return, block self
    }

    @Test("Parse block returning id with id argument")
    func parseIdBlockIdArg() throws {
        let type = try ObjCType.parse("@?<@@?@>")
        guard case .block(let types) = type else {
            Issue.record("Expected block type")
            return
        }
        #expect(types?.count == 3)  // id return, block self, id arg
    }

    @Test("Parse block returning int with multiple arguments")
    func parseIntBlockMultipleArgs() throws {
        let type = try ObjCType.parse("@?<i@?id>")
        guard case .block(let types) = type else {
            Issue.record("Expected block type")
            return
        }
        #expect(types?.count == 4)  // int return, block self, int arg, double arg
    }

    @Test("Parse nested block in block signature")
    func parseNestedBlockInSignature() throws {
        let type = try ObjCType.parse("@?<v@?@?>")
        guard case .block(let types) = type else {
            Issue.record("Expected block type")
            return
        }
        #expect(types?.count == 3)
        // Third type should be a block
        if let types = types, types.count > 2 {
            guard case .block = types[2] else {
                Issue.record("Expected nested block type")
                return
            }
        }
    }
}
