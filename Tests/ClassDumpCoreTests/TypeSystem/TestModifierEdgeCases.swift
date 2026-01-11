// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

@Suite("Modifier Edge Cases")
struct ModifierEdgeCaseTests {

    @Test("Parse multiple stacked modifiers")
    func parseStackedModifiers() throws {
        // const const int is valid
        let type = try ObjCType.parse("rri")
        guard case .const(let inner1) = type else {
            Issue.record("Expected const type")
            return
        }
        guard case .const(let inner2) = inner1 else {
            Issue.record("Expected nested const type")
            return
        }
        #expect(inner2 == .int)
    }

    @Test("Parse const pointer to const int")
    func parseConstPointerToConstInt() throws {
        // r^ri - const pointer to const int
        let type = try ObjCType.parse("r^ri")
        guard case .const(let inner1) = type else {
            Issue.record("Expected const type")
            return
        }
        guard case .pointer(let inner2) = inner1 else {
            Issue.record("Expected pointer type")
            return
        }
        guard case .const(let inner3) = inner2 else {
            Issue.record("Expected inner const type")
            return
        }
        #expect(inner3 == .int)
    }

    @Test("Parse atomic struct")
    func parseAtomicStruct() throws {
        let type = try ObjCType.parse("A{Point=dd}")
        guard case .atomic(let inner) = type else {
            Issue.record("Expected atomic type")
            return
        }
        guard case .structure(let name, _) = inner else {
            Issue.record("Expected structure type")
            return
        }
        #expect(name?.name == "Point")
    }

    @Test("Parse complex double")
    func parseComplexDouble() throws {
        let type = try ObjCType.parse("jd")
        guard case .complex(let inner) = type else {
            Issue.record("Expected complex type")
            return
        }
        #expect(inner == .double)
    }

    @Test("Parse complex float")
    func parseComplexFloat() throws {
        let type = try ObjCType.parse("jf")
        guard case .complex(let inner) = type else {
            Issue.record("Expected complex type")
            return
        }
        #expect(inner == .float)
    }

    @Test("Format complex double")
    func formatComplexDouble() throws {
        let type = try ObjCType.parse("jd")
        #expect(type.formatted() == "_Complex double")
    }

    @Test("Format atomic int")
    func formatAtomicInt() throws {
        let type = try ObjCType.parse("Ai")
        #expect(type.formatted() == "_Atomic int")
    }
}
