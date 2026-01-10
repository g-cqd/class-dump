// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

// MARK: - Type String Generation

@Suite("Type String Generation")
struct TypeStringGenerationTests {
    @Test("Type string for primitives")
    func typeStringPrimitives() {
        #expect(ObjCType.char.typeString == "c")
        #expect(ObjCType.int.typeString == "i")
        #expect(ObjCType.short.typeString == "s")
        #expect(ObjCType.long.typeString == "l")
        #expect(ObjCType.longLong.typeString == "q")
        #expect(ObjCType.unsignedChar.typeString == "C")
        #expect(ObjCType.unsignedInt.typeString == "I")
        #expect(ObjCType.unsignedShort.typeString == "S")
        #expect(ObjCType.unsignedLong.typeString == "L")
        #expect(ObjCType.unsignedLongLong.typeString == "Q")
        #expect(ObjCType.float.typeString == "f")
        #expect(ObjCType.double.typeString == "d")
        #expect(ObjCType.longDouble.typeString == "D")
        #expect(ObjCType.bool.typeString == "B")
        #expect(ObjCType.void.typeString == "v")
        #expect(ObjCType.objcClass.typeString == "#")
        #expect(ObjCType.selector.typeString == ":")
        #expect(ObjCType.unknown.typeString == "?")
        #expect(ObjCType.atom.typeString == "%")
    }

    @Test("Type string for id")
    func typeStringID() {
        #expect(ObjCType.id(className: nil, protocols: []).typeString == "@")
        #expect(ObjCType.id(className: "NSString", protocols: []).typeString == "@\"NSString\"")
    }

    @Test("Type string for pointer")
    func typeStringPointer() {
        #expect(ObjCType.pointer(.int).typeString == "^i")
        #expect(ObjCType.pointer(.pointer(.double)).typeString == "^^d")
    }

    @Test("Type string for array")
    func typeStringArray() {
        #expect(ObjCType.array(count: "10", elementType: .int).typeString == "[10i]")
    }

    @Test("Type string for struct")
    func typeStringStruct() {
        let structType = ObjCType.structure(
            name: ObjCTypeName(name: "CGPoint"),
            members: [
                ObjCTypedMember(type: .double, name: "x"),
                ObjCTypedMember(type: .double, name: "y"),
            ]
        )
        #expect(structType.typeString == "{CGPoint=\"x\"d\"y\"d}")
    }

    @Test("Type string for bitfield")
    func typeStringBitfield() {
        #expect(ObjCType.bitfield(size: "4").typeString == "b4")
    }

    @Test("Type string for block")
    func typeStringBlock() {
        #expect(ObjCType.block(types: nil).typeString == "@?")
    }

    @Test("Type string for function pointer")
    func typeStringFunctionPointer() {
        #expect(ObjCType.functionPointer.typeString == "^?")
    }

    @Test("Type string for modifiers")
    func typeStringModifiers() {
        #expect(ObjCType.const(.int).typeString == "ri")
        #expect(ObjCType.in(.pointer(.int)).typeString == "n^i")
        #expect(ObjCType.out(.id(className: nil, protocols: [])).typeString == "o@")
    }
}

// MARK: - Type Formatting

@Suite("Type Formatting")
struct TypeFormattingTests {
    @Test("Format primitives")
    func formatPrimitives() {
        #expect(ObjCType.char.formatted() == "char")
        #expect(ObjCType.int.formatted() == "int")
        #expect(ObjCType.short.formatted() == "short")
        #expect(ObjCType.long.formatted() == "long")
        #expect(ObjCType.longLong.formatted() == "long long")
        #expect(ObjCType.unsignedChar.formatted() == "unsigned char")
        #expect(ObjCType.unsignedInt.formatted() == "unsigned int")
        #expect(ObjCType.unsignedShort.formatted() == "unsigned short")
        #expect(ObjCType.unsignedLong.formatted() == "unsigned long")
        #expect(ObjCType.unsignedLongLong.formatted() == "unsigned long long")
        #expect(ObjCType.float.formatted() == "float")
        #expect(ObjCType.double.formatted() == "double")
        #expect(ObjCType.longDouble.formatted() == "long double")
        #expect(ObjCType.bool.formatted() == "_Bool")
        #expect(ObjCType.void.formatted() == "void")
        #expect(ObjCType.objcClass.formatted() == "Class")
        #expect(ObjCType.selector.formatted() == "SEL")
    }

    @Test("Format id types")
    func formatID() {
        #expect(ObjCType.id(className: nil, protocols: []).formatted() == "id")
        #expect(ObjCType.id(className: "NSString", protocols: []).formatted() == "NSString *")
        #expect(ObjCType.id(className: nil, protocols: ["NSCopying"]).formatted() == "id <NSCopying>")
        #expect(ObjCType.id(className: "NSArray", protocols: ["NSCopying"]).formatted() == "NSArray<NSCopying> *")
    }

    @Test("Format with variable name")
    func formatWithVariableName() {
        #expect(ObjCType.int.formatted(variableName: "count") == "int count")
        #expect(ObjCType.id(className: "NSString", protocols: []).formatted(variableName: "name") == "NSString *name")
        #expect(ObjCType.pointer(.int).formatted(variableName: "ptr") == "int *ptr")
    }

    @Test("Format pointer")
    func formatPointer() {
        #expect(ObjCType.pointer(.int).formatted() == "int *")
        #expect(ObjCType.pointer(.pointer(.double)).formatted() == "double **")
        #expect(ObjCType.pointer(.void).formatted() == "void *")
    }

    @Test("Format array")
    func formatArray() {
        #expect(ObjCType.array(count: "10", elementType: .int).formatted() == "int [10]")
        #expect(ObjCType.array(count: "10", elementType: .int).formatted(variableName: "arr") == "int arr[10]")
    }

    @Test("Format pointer to array")
    func formatPointerToArray() {
        let type = ObjCType.pointer(.array(count: "10", elementType: .int))
        #expect(type.formatted(variableName: "ptr") == "int (*ptr)[10]")
    }

    @Test("Format struct")
    func formatStruct() {
        let structType = ObjCType.structure(
            name: ObjCTypeName(name: "CGPoint"),
            members: []
        )
        #expect(structType.formatted() == "struct CGPoint")
    }

    @Test("Format struct with expansion")
    func formatStructWithExpansion() {
        let structType = ObjCType.structure(
            name: ObjCTypeName(name: "CGPoint"),
            members: [
                ObjCTypedMember(type: .double, name: "x"),
                ObjCTypedMember(type: .double, name: "y"),
            ]
        )
        let options = ObjCTypeFormatterOptions(shouldExpand: true)
        let formatted = structType.formatted(options: options)
        #expect(formatted.contains("struct CGPoint {"))
        #expect(formatted.contains("double x;"))
        #expect(formatted.contains("double y;"))
    }

    @Test("Format bitfield")
    func formatBitfield() {
        #expect(ObjCType.bitfield(size: "4").formatted() == "unsigned int :4")
        #expect(ObjCType.bitfield(size: "4").formatted(variableName: "flags") == "unsigned int flags:4")
    }

    @Test("Format block without signature")
    func formatBlockWithoutSignature() {
        // Blocks without signature information are formatted as id with a comment
        // indicating it's a block (cleaner than the old "CDUnknownBlockType")
        #expect(ObjCType.block(types: nil).formatted() == "id /* block */")
        #expect(ObjCType.block(types: nil).formatted(variableName: "handler") == "id /* block */ handler")
    }

    @Test("Format function pointer")
    func formatFunctionPointer() {
        #expect(ObjCType.functionPointer.formatted() == "CDUnknownFunctionPointerType")
    }

    @Test("Format modifiers")
    func formatModifiers() {
        #expect(ObjCType.const(.int).formatted() == "const int")
        #expect(ObjCType.const(.pointer(.char)).formatted() == "const char *")
    }
}

// MARK: - Type Properties

@Suite("Type Properties")
struct TypePropertiesTests {
    @Test("isIDType property")
    func isIDType() {
        #expect(ObjCType.id(className: nil, protocols: []).isIDType == true)
        #expect(ObjCType.id(className: "NSString", protocols: []).isIDType == false)
        #expect(ObjCType.int.isIDType == false)
    }

    @Test("isNamedObject property")
    func isNamedObject() {
        #expect(ObjCType.id(className: "NSString", protocols: []).isNamedObject == true)
        #expect(ObjCType.id(className: nil, protocols: []).isNamedObject == false)
        #expect(ObjCType.int.isNamedObject == false)
    }

    @Test("isModifier property")
    func isModifier() {
        #expect(ObjCType.const(.int).isModifier == true)
        #expect(ObjCType.in(.pointer(.int)).isModifier == true)
        #expect(ObjCType.out(.id(className: nil, protocols: [])).isModifier == true)
        #expect(ObjCType.int.isModifier == false)
        #expect(ObjCType.pointer(.int).isModifier == false)
    }

    @Test("typeIgnoringModifiers property")
    func typeIgnoringModifiers() {
        #expect(ObjCType.const(.int).typeIgnoringModifiers == .int)
        #expect(ObjCType.const(.const(.int)).typeIgnoringModifiers == .int)
        #expect(ObjCType.int.typeIgnoringModifiers == .int)
    }

    @Test("structureDepth property")
    func structureDepth() {
        #expect(ObjCType.int.structureDepth == 0)
        #expect(ObjCType.pointer(.int).structureDepth == 0)

        let simpleStruct = ObjCType.structure(
            name: ObjCTypeName(name: "Point"),
            members: [ObjCTypedMember(type: .double), ObjCTypedMember(type: .double)]
        )
        #expect(simpleStruct.structureDepth == 1)

        let nestedStruct = ObjCType.structure(
            name: ObjCTypeName(name: "Rect"),
            members: [ObjCTypedMember(type: simpleStruct), ObjCTypedMember(type: simpleStruct)]
        )
        #expect(nestedStruct.structureDepth == 2)
    }
}

// MARK: - Round-trip Tests

@Suite("Round-trip Tests")
struct RoundTripTests {
    @Test(
        "Round-trip primitives",
        arguments: ["c", "i", "s", "l", "q", "C", "I", "S", "L", "Q", "f", "d", "D", "B", "v", "#", ":", "?", "%"]
    )
    func roundTripPrimitives(encoding: String) throws {
        let type = try ObjCType.parse(encoding)
        #expect(type.typeString == encoding)
    }

    @Test("Round-trip pointer")
    func roundTripPointer() throws {
        let type = try ObjCType.parse("^i")
        #expect(type.typeString == "^i")
    }

    @Test("Round-trip array")
    func roundTripArray() throws {
        let type = try ObjCType.parse("[10d]")
        #expect(type.typeString == "[10d]")
    }

    @Test("Round-trip bitfield")
    func roundTripBitfield() throws {
        let type = try ObjCType.parse("b8")
        #expect(type.typeString == "b8")
    }

    @Test("Round-trip struct")
    func roundTripStruct() throws {
        let type = try ObjCType.parse("{CGPoint=dd}")
        #expect(type.bareTypeString == "{CGPoint=dd}")
    }

    @Test("Round-trip modifiers")
    func roundTripModifiers() throws {
        let type = try ObjCType.parse("r^i")
        #expect(type.typeString == "r^i")
    }
}

// MARK: - ObjCTypeName Tests

@Suite("ObjCTypeName Tests")
struct ObjCTypeNameTests {
    @Test("Simple type name")
    func typeNameSimple() {
        let name = ObjCTypeName(name: "CGPoint")
        #expect(name.description == "CGPoint")
        #expect(name.isTemplateType == false)
    }

    @Test("Template type name")
    func typeNameTemplate() {
        let name = ObjCTypeName(
            name: "vector",
            templateTypes: [ObjCTypeName(name: "int")]
        )
        #expect(name.description == "vector<int>")
        #expect(name.isTemplateType == true)
    }

    @Test("Nested template type name")
    func typeNameNestedTemplate() {
        let name = ObjCTypeName(
            name: "map",
            templateTypes: [
                ObjCTypeName(name: "string"),
                ObjCTypeName(name: "vector", templateTypes: [ObjCTypeName(name: "int")]),
            ]
        )
        #expect(name.description == "map<string, vector<int>>")
    }
}
