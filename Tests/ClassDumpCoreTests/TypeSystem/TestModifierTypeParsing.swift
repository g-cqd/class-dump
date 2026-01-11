// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

@Suite("Modifier Type Parsing")
struct ModifierTypeParsingTests {
    @Test("Parse const modifier")
    func parseConstModifier() throws {
        let type = try ObjCType.parse("ri")
        #expect(type == .const(.int))
    }

    @Test("Parse in modifier")
    func parseInModifier() throws {
        let type = try ObjCType.parse("n^i")
        #expect(type == .in(.pointer(.int)))
    }

    @Test("Parse out modifier")
    func parseOutModifier() throws {
        let type = try ObjCType.parse("o^i")
        #expect(type == .out(.pointer(.int)))
    }

    @Test("Parse inout modifier")
    func parseInoutModifier() throws {
        let type = try ObjCType.parse("N^i")
        #expect(type == .inout(.pointer(.int)))
    }

    @Test("Parse bycopy modifier")
    func parseBycopyModifier() throws {
        let type = try ObjCType.parse("O@")
        #expect(type == .bycopy(.id(className: nil, protocols: [])))
    }

    @Test("Parse byref modifier")
    func parseByrefModifier() throws {
        let type = try ObjCType.parse("R@")
        #expect(type == .byref(.id(className: nil, protocols: [])))
    }

    @Test("Parse oneway modifier")
    func parseOnewayModifier() throws {
        let type = try ObjCType.parse("Vv")
        #expect(type == .oneway(.void))
    }

    @Test("Parse atomic modifier")
    func parseAtomicModifier() throws {
        let type = try ObjCType.parse("Ai")
        #expect(type == .atomic(.int))
    }

    @Test("Parse complex modifier")
    func parseComplexModifier() throws {
        let type = try ObjCType.parse("jd")
        #expect(type == .complex(.double))
    }
}
