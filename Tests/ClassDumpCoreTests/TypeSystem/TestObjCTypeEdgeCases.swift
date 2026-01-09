// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

// MARK: - Int128 Type Tests

@Suite("Int128 Type Tests")
struct Int128TypeTests {

    @Test("Parse signed __int128 (t)")
    func parseSignedInt128() throws {
        let type = try ObjCType.parse("t")
        #expect(type == .int128)
    }

    @Test("Parse unsigned __int128 (T)")
    func parseUnsignedInt128() throws {
        let type = try ObjCType.parse("T")
        #expect(type == .unsignedInt128)
    }

    @Test("Format signed __int128")
    func formatSignedInt128() {
        #expect(ObjCType.int128.formatted() == "__int128")
    }

    @Test("Format unsigned __int128")
    func formatUnsignedInt128() {
        #expect(ObjCType.unsignedInt128.formatted() == "unsigned __int128")
    }

    @Test("Type string for signed __int128")
    func typeStringSignedInt128() {
        #expect(ObjCType.int128.typeString == "t")
    }

    @Test("Type string for unsigned __int128")
    func typeStringUnsignedInt128() {
        #expect(ObjCType.unsignedInt128.typeString == "T")
    }

    @Test("Round-trip signed __int128")
    func roundTripSignedInt128() throws {
        let type = try ObjCType.parse("t")
        #expect(type.typeString == "t")
    }

    @Test("Round-trip unsigned __int128")
    func roundTripUnsignedInt128() throws {
        let type = try ObjCType.parse("T")
        #expect(type.typeString == "T")
    }

    @Test("Pointer to signed __int128")
    func pointerToSignedInt128() throws {
        let type = try ObjCType.parse("^t")
        #expect(type == .pointer(.int128))
        #expect(type.formatted() == "__int128 *")
    }

    @Test("Pointer to unsigned __int128")
    func pointerToUnsignedInt128() throws {
        let type = try ObjCType.parse("^T")
        #expect(type == .pointer(.unsignedInt128))
        #expect(type.formatted() == "unsigned __int128 *")
    }

    @Test("Array of signed __int128")
    func arrayOfSignedInt128() throws {
        let type = try ObjCType.parse("[4t]")
        #expect(type == .array(count: "4", elementType: .int128))
        #expect(type.formatted() == "__int128 [4]")
    }

    @Test("Struct with __int128 member")
    func structWithInt128Member() throws {
        let type = try ObjCType.parse("{LargeInt=\"low\"Q\"high\"q}")
        guard case .structure(let name, let members) = type else {
            Issue.record("Expected structure type")
            return
        }
        #expect(name?.name == "LargeInt")
        #expect(members.count == 2)
        #expect(members[0].type == .unsignedLongLong)
        #expect(members[0].name == "low")
    }
}

// MARK: - Complex Nested Struct Tests

@Suite("Complex Nested Struct Tests")
struct ComplexNestedStructTests {

    @Test("Parse deeply nested struct (3 levels)")
    func parseDeeplyNestedStruct() throws {
        // {A={B={C=ii}i}i}
        let type = try ObjCType.parse("{A={B={C=ii}i}i}")
        guard case .structure(let nameA, let membersA) = type else {
            Issue.record("Expected structure type A")
            return
        }
        #expect(nameA?.name == "A")
        #expect(membersA.count == 2)

        guard case .structure(let nameB, let membersB) = membersA[0].type else {
            Issue.record("Expected structure type B")
            return
        }
        #expect(nameB?.name == "B")
        #expect(membersB.count == 2)

        guard case .structure(let nameC, let membersC) = membersB[0].type else {
            Issue.record("Expected structure type C")
            return
        }
        #expect(nameC?.name == "C")
        #expect(membersC.count == 2)
        #expect(membersC[0].type == .int)
        #expect(membersC[1].type == .int)
    }

    @Test("Parse CGRect with full names")
    func parseCGRectFullyNamed() throws {
        let encoding = "{CGRect=\"origin\"{CGPoint=\"x\"d\"y\"d}\"size\"{CGSize=\"width\"d\"height\"d}}"
        let type = try ObjCType.parse(encoding)

        guard case .structure(let name, let members) = type else {
            Issue.record("Expected structure type")
            return
        }
        #expect(name?.name == "CGRect")
        #expect(members.count == 2)
        #expect(members[0].name == "origin")
        #expect(members[1].name == "size")

        guard case .structure(let originName, let originMembers) = members[0].type else {
            Issue.record("Expected structure type for origin")
            return
        }
        #expect(originName?.name == "CGPoint")
        #expect(originMembers.count == 2)
        #expect(originMembers[0].name == "x")
        #expect(originMembers[1].name == "y")
    }

    @Test("Parse struct with pointer member")
    func parseStructWithPointerMember() throws {
        let type = try ObjCType.parse("{Node=\"value\"i\"next\"^{Node}}")
        guard case .structure(let name, let members) = type else {
            Issue.record("Expected structure type")
            return
        }
        #expect(name?.name == "Node")
        #expect(members.count == 2)
        #expect(members[0].name == "value")
        #expect(members[0].type == .int)
        #expect(members[1].name == "next")

        guard case .pointer(let pointee) = members[1].type else {
            Issue.record("Expected pointer type")
            return
        }
        guard case .structure(let pointeeName, _) = pointee else {
            Issue.record("Expected structure pointee")
            return
        }
        #expect(pointeeName?.name == "Node")
    }

    @Test("Parse struct with array member")
    func parseStructWithArrayMember() throws {
        let type = try ObjCType.parse("{Matrix=\"data\"[16d]}")
        guard case .structure(let name, let members) = type else {
            Issue.record("Expected structure type")
            return
        }
        #expect(name?.name == "Matrix")
        #expect(members.count == 1)
        #expect(members[0].name == "data")

        guard case .array(let count, let elementType) = members[0].type else {
            Issue.record("Expected array type")
            return
        }
        #expect(count == "16")
        #expect(elementType == .double)
    }

    @Test("Parse anonymous struct")
    func parseAnonymousStruct() throws {
        let type = try ObjCType.parse("{?=ii}")
        guard case .structure(let name, let members) = type else {
            Issue.record("Expected structure type")
            return
        }
        #expect(name?.name == "?")
        #expect(members.count == 2)
    }

    @Test("Calculate structure depth for deeply nested struct")
    func structureDepthDeeplyNested() throws {
        // 4 levels deep: {A={B={C={D=i}}}}
        let type = try ObjCType.parse("{A={B={C={D=i}}}}")
        #expect(type.structureDepth == 4)
    }
}

// MARK: - Union Type Tests

@Suite("Union Type Tests")
struct UnionTypeTests {

    @Test("Parse simple union")
    func parseSimpleUnion() throws {
        let type = try ObjCType.parse("(Value=id)")
        guard case .union(let name, let members) = type else {
            Issue.record("Expected union type")
            return
        }
        #expect(name?.name == "Value")
        #expect(members.count == 2)  // i and d
    }

    @Test("Parse anonymous union with question mark")
    func parseAnonymousUnion() throws {
        // Anonymous unions use ? as placeholder name
        let type = try ObjCType.parse("(?=iQ)")
        guard case .union(let name, let members) = type else {
            Issue.record("Expected union type")
            return
        }
        #expect(name?.name == "?")
        #expect(members.count == 2)
        #expect(members[0].type == .int)
        #expect(members[1].type == .unsignedLongLong)
    }

    @Test("Parse union with named members")
    func parseUnionWithNamedMembers() throws {
        let type = try ObjCType.parse("(Data=\"intVal\"i\"floatVal\"f)")
        guard case .union(let name, let members) = type else {
            Issue.record("Expected union type")
            return
        }
        #expect(name?.name == "Data")
        #expect(members.count == 2)
        #expect(members[0].name == "intVal")
        #expect(members[0].type == .int)
        #expect(members[1].name == "floatVal")
        #expect(members[1].type == .float)
    }

    @Test("Parse pointer to union")
    func parsePointerToUnion() throws {
        let type = try ObjCType.parse("^(Value=id)")
        guard case .pointer(let pointee) = type else {
            Issue.record("Expected pointer type")
            return
        }
        guard case .union(let name, _) = pointee else {
            Issue.record("Expected union pointee")
            return
        }
        #expect(name?.name == "Value")
    }

    @Test("Parse struct containing union")
    func parseStructContainingUnion() throws {
        let type = try ObjCType.parse("{Container=\"tag\"i\"value\"(Data=id)}")
        guard case .structure(let name, let members) = type else {
            Issue.record("Expected structure type")
            return
        }
        #expect(name?.name == "Container")
        #expect(members.count == 2)
        #expect(members[0].name == "tag")

        guard case .union(let unionName, _) = members[1].type else {
            Issue.record("Expected union type for value member")
            return
        }
        #expect(unionName?.name == "Data")
    }

    @Test("Format union type")
    func formatUnionType() throws {
        let type = try ObjCType.parse("(Value=id)")
        #expect(type.formatted().contains("union Value"))
    }

    @Test("Union type string round-trip")
    func unionTypeStringRoundTrip() throws {
        let type = try ObjCType.parse("(Value=id)")
        let typeString = type.typeString
        #expect(typeString == "(Value=id)")
    }
}

// MARK: - SIMD/Vector Type Tests

@Suite("SIMD/Vector Type Tests")
struct SIMDVectorTypeTests {

    @Test("Parse simd_float2 as struct")
    func parseSimdFloat2() throws {
        let type = try ObjCType.parse("{simd_float2=ff}")
        guard case .structure(let name, let members) = type else {
            Issue.record("Expected structure type")
            return
        }
        #expect(name?.name == "simd_float2")
        #expect(members.count == 2)
        #expect(members[0].type == .float)
        #expect(members[1].type == .float)
    }

    @Test("Parse simd_float3 as struct")
    func parseSimdFloat3() throws {
        let type = try ObjCType.parse("{simd_float3=fff}")
        guard case .structure(let name, let members) = type else {
            Issue.record("Expected structure type")
            return
        }
        #expect(name?.name == "simd_float3")
        #expect(members.count == 3)
    }

    @Test("Parse simd_float4 as struct")
    func parseSimdFloat4() throws {
        let type = try ObjCType.parse("{simd_float4=ffff}")
        guard case .structure(let name, let members) = type else {
            Issue.record("Expected structure type")
            return
        }
        #expect(name?.name == "simd_float4")
        #expect(members.count == 4)
    }

    @Test("Parse simd_float4x4 matrix")
    func parseSimdFloat4x4() throws {
        let encoding = "{simd_float4x4=\"columns\"[4{simd_float4=ffff}]}"
        let type = try ObjCType.parse(encoding)

        guard case .structure(let name, let members) = type else {
            Issue.record("Expected structure type")
            return
        }
        #expect(name?.name == "simd_float4x4")
        #expect(members.count == 1)
        #expect(members[0].name == "columns")

        guard case .array(let count, let elementType) = members[0].type else {
            Issue.record("Expected array type")
            return
        }
        #expect(count == "4")

        guard case .structure(let vecName, let vecMembers) = elementType else {
            Issue.record("Expected structure element type")
            return
        }
        #expect(vecName?.name == "simd_float4")
        #expect(vecMembers.count == 4)
    }

    @Test("Parse simd_int4 as struct")
    func parseSimdInt4() throws {
        let type = try ObjCType.parse("{simd_int4=iiii}")
        guard case .structure(let name, let members) = type else {
            Issue.record("Expected structure type")
            return
        }
        #expect(name?.name == "simd_int4")
        #expect(members.count == 4)
        #expect(members.allSatisfy { $0.type == .int })
    }

    @Test("Parse simd_double2 as struct")
    func parseSimdDouble2() throws {
        let type = try ObjCType.parse("{simd_double2=dd}")
        guard case .structure(let name, let members) = type else {
            Issue.record("Expected structure type")
            return
        }
        #expect(name?.name == "simd_double2")
        #expect(members.count == 2)
        #expect(members.allSatisfy { $0.type == .double })
    }
}

// MARK: - Bitfield Edge Cases

@Suite("Bitfield Edge Cases")
struct BitfieldEdgeCaseTests {

    @Test("Parse single bit bitfield")
    func parseSingleBitBitfield() throws {
        let type = try ObjCType.parse("b1")
        #expect(type == .bitfield(size: "1"))
    }

    @Test("Parse maximum reasonable bitfield")
    func parseMaxBitfield() throws {
        let type = try ObjCType.parse("b64")
        #expect(type == .bitfield(size: "64"))
    }

    @Test("Parse struct with multiple bitfields")
    func parseStructWithBitfields() throws {
        let type = try ObjCType.parse("{Flags=\"a\"b1\"b\"b2\"c\"b5}")
        guard case .structure(let name, let members) = type else {
            Issue.record("Expected structure type")
            return
        }
        #expect(name?.name == "Flags")
        #expect(members.count == 3)
        #expect(members[0].type == .bitfield(size: "1"))
        #expect(members[1].type == .bitfield(size: "2"))
        #expect(members[2].type == .bitfield(size: "5"))
    }

    @Test("Format bitfield with variable name")
    func formatBitfieldWithName() {
        let formatted = ObjCType.bitfield(size: "3").formatted(variableName: "flags")
        #expect(formatted == "unsigned int flags:3")
    }
}

// MARK: - Block Signature Edge Cases

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

// MARK: - Modifier Edge Cases

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

// MARK: - Array Edge Cases

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

// MARK: - C++ Template Type Name Tests

@Suite("C++ Template Type Name Tests")
struct CppTemplateTypeNameTests {

    @Test("Parse struct with C++ template name")
    func parseStructWithTemplateName() throws {
        let type = try ObjCType.parse("{std::vector<int>=^i^i}")
        guard case .structure(let name, let members) = type else {
            Issue.record("Expected structure type")
            return
        }
        #expect(name?.description.contains("vector") == true)
        #expect(members.count == 2)
    }

    @Test("Parse nested C++ template")
    func parseNestedTemplate() throws {
        let type = try ObjCType.parse("{map<string, vector<int>>=^i}")
        guard case .structure(let name, _) = type else {
            Issue.record("Expected structure type")
            return
        }
        #expect(name?.description.contains("map") == true)
    }
}

// MARK: - Sendable Conformance Tests

@Suite("ObjCType Sendable Tests")
struct ObjCTypeSendableTests {

    @Test("ObjCType is Sendable")
    func objcTypeSendable() async {
        let type = ObjCType.int
        let task = Task { type }
        let result = await task.value
        #expect(result == .int)
    }

    @Test("ObjCTypedMember is Sendable")
    func objcTypedMemberSendable() async {
        let member = ObjCTypedMember(type: .double, name: "value")
        let task = Task { member.name }
        let result = await task.value
        #expect(result == "value")
    }

    @Test("ObjCTypeName is Sendable")
    func objcTypeNameSendable() async {
        let name = ObjCTypeName(name: "CGPoint")
        let task = Task { name.description }
        let result = await task.value
        #expect(result == "CGPoint")
    }

    @Test("ObjCMethodType is Sendable")
    func objcMethodTypeSendable() async {
        let methodType = ObjCMethodType(type: .void, offset: "0")
        let task = Task { methodType.offset }
        let result = await task.value
        #expect(result == "0")
    }
}
