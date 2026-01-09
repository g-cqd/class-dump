// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

// MARK: - Primitive Type Parsing

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

// MARK: - ID Type Parsing

@Suite("ID Type Parsing")
struct IDTypeParsingTests {
    @Test("Parse plain id")
    func parseIDPlain() throws {
        let type = try ObjCType.parse("@")
        #expect(type == .id(className: nil, protocols: []))
    }

    @Test("Parse id with class name")
    func parseIDWithClassName() throws {
        let type = try ObjCType.parse("@\"NSString\"")
        #expect(type == .id(className: "NSString", protocols: []))
    }

    @Test("Parse id with protocol")
    func parseIDWithProtocol() throws {
        let type = try ObjCType.parse("@\"<NSCopying>\"")
        #expect(type == .id(className: nil, protocols: ["NSCopying"]))
    }

    @Test("Parse id with class and protocol")
    func parseIDWithClassAndProtocol() throws {
        let type = try ObjCType.parse("@\"NSArray<NSFastEnumeration>\"")
        #expect(type == .id(className: "NSArray", protocols: ["NSFastEnumeration"]))
    }

    @Test("Parse id with multiple protocols")
    func parseIDWithMultipleProtocols() throws {
        let type = try ObjCType.parse("@\"NSObject<NSCopying, NSCoding>\"")
        #expect(type == .id(className: "NSObject", protocols: ["NSCopying", "NSCoding"]))
    }
}

// MARK: - Pointer Type Parsing

@Suite("Pointer Type Parsing")
struct PointerTypeParsingTests {
    @Test("Parse pointer to int")
    func parsePointerToInt() throws {
        let type = try ObjCType.parse("^i")
        #expect(type == .pointer(.int))
    }

    @Test("Parse pointer to pointer")
    func parsePointerToPointer() throws {
        let type = try ObjCType.parse("^^i")
        #expect(type == .pointer(.pointer(.int)))
    }

    @Test("Parse pointer to void")
    func parsePointerToVoid() throws {
        let type = try ObjCType.parse("^v")
        #expect(type == .pointer(.void))
    }

    @Test("Parse function pointer")
    func parseFunctionPointer() throws {
        let type = try ObjCType.parse("^?")
        #expect(type == .functionPointer)
    }
}

// MARK: - Array Type Parsing

@Suite("Array Type Parsing")
struct ArrayTypeParsingTests {
    @Test("Parse array")
    func parseArray() throws {
        let type = try ObjCType.parse("[10i]")
        #expect(type == .array(count: "10", elementType: .int))
    }

    @Test("Parse nested array")
    func parseNestedArray() throws {
        let type = try ObjCType.parse("[5[3d]]")
        #expect(type == .array(count: "5", elementType: .array(count: "3", elementType: .double)))
    }

    @Test("Parse array of pointers")
    func parseArrayOfPointers() throws {
        let type = try ObjCType.parse("[4^i]")
        #expect(type == .array(count: "4", elementType: .pointer(.int)))
    }
}

// MARK: - Struct Type Parsing

@Suite("Struct Type Parsing")
struct StructTypeParsingTests {
    @Test("Parse empty struct")
    func parseStructEmpty() throws {
        let type = try ObjCType.parse("{CGPoint}")
        guard case .structure(let name, let members) = type else {
            Issue.record("Expected structure type")
            return
        }
        #expect(name?.name == "CGPoint")
        #expect(members.isEmpty)
    }

    @Test("Parse struct with members")
    func parseStructWithMembers() throws {
        let type = try ObjCType.parse("{CGPoint=dd}")
        guard case .structure(let name, let members) = type else {
            Issue.record("Expected structure type")
            return
        }
        #expect(name?.name == "CGPoint")
        #expect(members.count == 2)
        #expect(members[0].type == .double)
        #expect(members[1].type == .double)
    }

    @Test("Parse struct with named members")
    func parseStructWithNamedMembers() throws {
        let type = try ObjCType.parse("{CGPoint=\"x\"d\"y\"d}")
        guard case .structure(let name, let members) = type else {
            Issue.record("Expected structure type")
            return
        }
        #expect(name?.name == "CGPoint")
        #expect(members.count == 2)
        #expect(members[0].type == .double)
        #expect(members[0].name == "x")
        #expect(members[1].type == .double)
        #expect(members[1].name == "y")
    }

    @Test("Parse nested struct")
    func parseNestedStruct() throws {
        let type = try ObjCType.parse("{CGRect={CGPoint=dd}{CGSize=dd}}")
        guard case .structure(let name, let members) = type else {
            Issue.record("Expected structure type")
            return
        }
        #expect(name?.name == "CGRect")
        #expect(members.count == 2)

        guard case .structure(let originName, _) = members[0].type else {
            Issue.record("Expected nested structure for origin")
            return
        }
        #expect(originName?.name == "CGPoint")

        guard case .structure(let sizeName, _) = members[1].type else {
            Issue.record("Expected nested structure for size")
            return
        }
        #expect(sizeName?.name == "CGSize")
    }
}

// MARK: - Union Type Parsing

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

// MARK: - Bitfield Type Parsing

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

// MARK: - Block Type Parsing

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

// MARK: - Modifier Type Parsing

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

// MARK: - Method Type Parsing

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
