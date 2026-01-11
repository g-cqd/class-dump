// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

@Suite("Union Type Parsing")
struct UnionTypeParsingTests {
    @Test("Parse union")
    func parseUnion() throws {
        let type = try ObjCType.parse("(data=id)")
        guard case .union(let name, let members) = type else {
            Issue.record("Expected union type")
            return
        }
        #expect(name?.name == "data")
        #expect(members.count == 2)
    }
}
