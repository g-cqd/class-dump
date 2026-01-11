// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

@Suite("Array Edge Cases")
struct ArrayEdgeCaseTests {

    @Test("Parse zero-size array")
    func parseZeroSizeArray() throws {
        let type = try ObjCType.parse("[0i]")
        guard case .array(let count, let elementType) = type else {
            Issue.record("Expected array type")
            return
        }
        #expect(count == "0")
        #expect(elementType == .int)
    }

    @Test("Parse very large array")
    func parseVeryLargeArray() throws {
        let type = try ObjCType.parse("[1000000i]")
        guard case .array(let count, let elementType) = type else {
            Issue.record("Expected array type")
            return
        }
        #expect(count == "1000000")
        #expect(elementType == .int)
    }

    @Test("Parse multi-dimensional array")
    func parseMultiDimensionalArray() throws {
        let type = try ObjCType.parse("[3[4[5d]]]")
        guard case .array(let count1, let elementType1) = type else {
            Issue.record("Expected array type")
            return
        }
        #expect(count1 == "3")

        guard case .array(let count2, let elementType2) = elementType1 else {
            Issue.record("Expected nested array type")
            return
        }
        #expect(count2 == "4")

        guard case .array(let count3, let elementType3) = elementType2 else {
            Issue.record("Expected double-nested array type")
            return
        }
        #expect(count3 == "5")
        #expect(elementType3 == .double)
    }

    @Test("Parse array of structs")
    func parseArrayOfStructs() throws {
        let type = try ObjCType.parse("[10{Point=dd}]")
        guard case .array(let count, let elementType) = type else {
            Issue.record("Expected array type")
            return
        }
        #expect(count == "10")

        guard case .structure(let name, _) = elementType else {
            Issue.record("Expected structure element type")
            return
        }
        #expect(name?.name == "Point")
    }
}
