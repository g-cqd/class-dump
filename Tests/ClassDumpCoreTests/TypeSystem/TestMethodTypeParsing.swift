// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

@Suite("Method Type Parsing")
struct MethodTypeParsingTests {
    @Test("Parse method type")
    func parseMethodType() throws {
        // -(void)method has type "v@:" (void return, self, _cmd)
        let types = try ObjCType.parseMethodType("v16@0:8")
        #expect(types.count == 3)
        #expect(types[0].type == .void)
        #expect(types[0].offset == "16")
        #expect(types[1].type == .id(className: nil, protocols: []))
        #expect(types[1].offset == "0")
        #expect(types[2].type == .selector)
        #expect(types[2].offset == "8")
    }

    @Test("Parse method type with argument")
    func parseMethodTypeWithArg() throws {
        // -(int)methodWithInt:(int)arg has type "i@:i"
        let types = try ObjCType.parseMethodType("i24@0:8i16")
        #expect(types.count == 4)
        #expect(types[0].type == .int)
        #expect(types[3].type == .int)
    }
}
