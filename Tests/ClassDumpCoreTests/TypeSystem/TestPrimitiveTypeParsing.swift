// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

@Suite("Primitive Type Parsing")
struct PrimitiveTypeParsingTests {
    @Test("Parse primitive char")
    func parsePrimitiveChar() throws {
        let type = try ObjCType.parse("c")
        #expect(type == .char)
    }

    @Test("Parse primitive int")
    func parsePrimitiveInt() throws {
        let type = try ObjCType.parse("i")
        #expect(type == .int)
    }

    @Test("Parse primitive short")
    func parsePrimitiveShort() throws {
        let type = try ObjCType.parse("s")
        #expect(type == .short)
    }

    @Test("Parse primitive long")
    func parsePrimitiveLong() throws {
        let type = try ObjCType.parse("l")
        #expect(type == .long)
    }

    @Test("Parse primitive long long")
    func parsePrimitiveLongLong() throws {
        let type = try ObjCType.parse("q")
        #expect(type == .longLong)
    }

    @Test("Parse primitive unsigned char")
    func parsePrimitiveUnsignedChar() throws {
        let type = try ObjCType.parse("C")
        #expect(type == .unsignedChar)
    }

    @Test("Parse primitive unsigned int")
    func parsePrimitiveUnsignedInt() throws {
        let type = try ObjCType.parse("I")
        #expect(type == .unsignedInt)
    }

    @Test("Parse primitive unsigned short")
    func parsePrimitiveUnsignedShort() throws {
        let type = try ObjCType.parse("S")
        #expect(type == .unsignedShort)
    }

    @Test("Parse primitive unsigned long")
    func parsePrimitiveUnsignedLong() throws {
        let type = try ObjCType.parse("L")
        #expect(type == .unsignedLong)
    }

    @Test("Parse primitive unsigned long long")
    func parsePrimitiveUnsignedLongLong() throws {
        let type = try ObjCType.parse("Q")
        #expect(type == .unsignedLongLong)
    }

    @Test("Parse primitive float")
    func parsePrimitiveFloat() throws {
        let type = try ObjCType.parse("f")
        #expect(type == .float)
    }

    @Test("Parse primitive double")
    func parsePrimitiveDouble() throws {
        let type = try ObjCType.parse("d")
        #expect(type == .double)
    }

    @Test("Parse primitive long double")
    func parsePrimitiveLongDouble() throws {
        let type = try ObjCType.parse("D")
        #expect(type == .longDouble)
    }

    @Test("Parse primitive bool")
    func parsePrimitiveBool() throws {
        let type = try ObjCType.parse("B")
        #expect(type == .bool)
    }

    @Test("Parse primitive void")
    func parsePrimitiveVoid() throws {
        let type = try ObjCType.parse("v")
        #expect(type == .void)
    }

    @Test("Parse primitive C string (char*)")
    func parsePrimitiveCString() throws {
        let type = try ObjCType.parse("*")
        #expect(type == .pointer(.char))
    }

    @Test("Parse primitive Class")
    func parsePrimitiveClass() throws {
        let type = try ObjCType.parse("#")
        #expect(type == .objcClass)
    }

    @Test("Parse primitive selector")
    func parsePrimitiveSelector() throws {
        let type = try ObjCType.parse(":")
        #expect(type == .selector)
    }

    @Test("Parse primitive unknown")
    func parsePrimitiveUnknown() throws {
        let type = try ObjCType.parse("?")
        #expect(type == .unknown)
    }

    @Test("Parse primitive atom")
    func parsePrimitiveAtom() throws {
        let type = try ObjCType.parse("%")
        #expect(type == .atom)
    }
}
