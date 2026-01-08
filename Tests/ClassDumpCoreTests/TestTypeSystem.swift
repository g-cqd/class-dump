import Testing

@testable import ClassDumpCore

@Suite("Type System Tests")
struct TestTypeSystem {
    // MARK: - Primitive Types

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

    // MARK: - ID Types

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

    // MARK: - Pointer Types

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

    // MARK: - Array Types

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

    // MARK: - Struct Types

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

    // MARK: - Union Types

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

    // MARK: - Bitfield Types

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

    // MARK: - Block Types

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

    // MARK: - Modifier Types

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

    // MARK: - Method Type Parsing

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

    // MARK: - Type String Generation

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

    // MARK: - Formatting Tests

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

    // MARK: - Type Properties

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

    // MARK: - Lexer Tests

    @Test("Lexer simple tokens")
    func lexerSimpleTokens() {
        let lexer = ObjCTypeLexer(string: "ic@")
        #expect(lexer.scanNextToken() == .char("i"))
        #expect(lexer.scanNextToken() == .char("c"))
        #expect(lexer.scanNextToken() == .char("@"))
        #expect(lexer.scanNextToken() == .eos)
    }

    @Test("Lexer numbers")
    func lexerNumbers() {
        let lexer = ObjCTypeLexer(string: "123")
        #expect(lexer.scanNextToken() == .number("123"))
    }

    @Test("Lexer negative numbers")
    func lexerNegativeNumbers() {
        let lexer = ObjCTypeLexer(string: "-42")
        #expect(lexer.scanNextToken() == .number("-42"))
    }

    @Test("Lexer quoted string")
    func lexerQuotedString() {
        let lexer = ObjCTypeLexer(string: "\"NSString\"")
        #expect(lexer.scanNextToken() == .quotedString("NSString"))
    }

    @Test("Lexer identifier state")
    func lexerIdentifier() {
        let lexer = ObjCTypeLexer(string: "{CGPoint=dd}")
        #expect(lexer.scanNextToken() == .char("{"))
        lexer.state = .identifier
        #expect(lexer.scanNextToken() == .identifier("CGPoint"))
        #expect(lexer.scanNextToken() == .char("="))
        // In identifier state, "dd" is scanned as an identifier
        // For actual parsing, we reset to normal state after "=" to scan types
        #expect(lexer.scanNextToken() == .identifier("dd"))
        #expect(lexer.scanNextToken() == .char("}"))
        #expect(lexer.scanNextToken() == .eos)
    }

    // MARK: - ObjCTypeName Tests

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

    // MARK: - Round-trip Tests

    @Test(
        "Round-trip primitives",
        arguments: ["c", "i", "s", "l", "q", "C", "I", "S", "L", "Q", "f", "d", "D", "B", "v", "#", ":", "?", "%"])
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

    // MARK: - Swift Generic Types in Property Declarations

    @Test("Format Swift generic class type with demangling")
    func formatGenericClassWithDemangling() {
        // _TtGC<module_len><module><class_len><class><type_arg>_
        // "ModuleName" = 10 chars, "Container" = 9 chars
        let type = ObjCType.id(className: "_TtGC10ModuleName9ContainerSS_", protocols: [])
        let options = ObjCTypeFormatterOptions(demangleStyle: .swift)
        let result = type.formatted(options: options)
        #expect(result.contains("ModuleName.Container<String>"))
    }

    @Test("Format Swift generic class with Int type argument")
    func formatGenericClassWithInt() {
        let type = ObjCType.id(className: "_TtGC10ModuleName7WrapperSi_", protocols: [])
        let options = ObjCTypeFormatterOptions(demangleStyle: .swift)
        let result = type.formatted(options: options)
        #expect(result.contains("ModuleName.Wrapper<Int>"))
    }

    @Test("Format Swift generic struct type")
    func formatGenericStructType() {
        // _TtGV prefix for generic struct
        let type = ObjCType.id(className: "_TtGV10ModuleName7WrapperSS_", protocols: [])
        let options = ObjCTypeFormatterOptions(demangleStyle: .swift)
        let result = type.formatted(options: options)
        #expect(result.contains("ModuleName.Wrapper<String>"))
    }

    @Test("Format Swift generic with multiple type parameters")
    func formatGenericWithMultipleParams() {
        // PairMap<String, Int>: "PairMap" = 7 chars
        let type = ObjCType.id(className: "_TtGC10ModuleName7PairMapSSSi_", protocols: [])
        let options = ObjCTypeFormatterOptions(demangleStyle: .swift)
        let result = type.formatted(options: options)
        #expect(result.contains("ModuleName.PairMap<String, Int>"))
    }

    @Test("Format Swift class without demangling when style is none")
    func formatSwiftClassNoDemangling() {
        let type = ObjCType.id(className: "_TtGC10ModuleName9ContainerSS_", protocols: [])
        let options = ObjCTypeFormatterOptions(demangleStyle: .none)
        let result = type.formatted(options: options)
        #expect(result.contains("_TtGC10ModuleName9ContainerSS_"))
    }

    @Test("Format Swift generic class with ObjC style strips module")
    func formatGenericClassObjCStyle() {
        let type = ObjCType.id(className: "_TtGC10ModuleName9ContainerSS_", protocols: [])
        let options = ObjCTypeFormatterOptions(demangleStyle: .objc)
        let result = type.formatted(options: options)
        #expect(result.contains("Container<String>"))
        #expect(!result.contains("ModuleName."))
    }

    @Test("Format simple Swift class type")
    func formatSimpleSwiftClass() {
        // _TtC<module_len><module><class_len><class>
        // "MyModule" = 8 chars, "MyClass" = 7 chars
        let type = ObjCType.id(className: "_TtC8MyModule7MyClass", protocols: [])
        let options = ObjCTypeFormatterOptions(demangleStyle: .swift)
        let result = type.formatted(options: options)
        #expect(result.contains("MyModule.MyClass"))
    }

    @Test("Format property with Swift generic class name and variable")
    func formatPropertyWithGenericClass() {
        let type = ObjCType.id(className: "_TtGC10ModuleName9ContainerSS_", protocols: [])
        let options = ObjCTypeFormatterOptions(demangleStyle: .swift)
        let result = type.formatted(variableName: "_items", options: options)
        #expect(result.contains("ModuleName.Container<String>"))
        #expect(result.contains("_items"))
    }

    @Test("Regular ObjC class type unchanged")
    func formatRegularObjCClass() {
        let type = ObjCType.id(className: "NSArray", protocols: [])
        let options = ObjCTypeFormatterOptions(demangleStyle: .swift)
        let result = type.formatted(options: options)
        #expect(result == "NSArray *")
    }

    // MARK: - Optional Type Formatting

    @Test("Format Optional String type")
    func formatOptionalString() {
        // SSSg = Optional<String>: SS=String, Sg=Optional suffix
        let type = ObjCType.id(className: "_TtSSSg", protocols: [])
        let options = ObjCTypeFormatterOptions(demangleStyle: .swift)
        let result = type.formatted(options: options)
        // Should show "String?" instead of "Optional<String>"
        #expect(result.contains("String?"))
    }

    @Test("Format Optional Int type")
    func formatOptionalInt() {
        // SiSg = Optional<Int>
        let type = ObjCType.id(className: "_TtSiSg", protocols: [])
        let options = ObjCTypeFormatterOptions(demangleStyle: .swift)
        let result = type.formatted(options: options)
        #expect(result.contains("Int?"))
    }

    @Test("Format Array of String type")
    func formatArrayOfString() {
        // SaySS_G = Array<String>
        let type = ObjCType.id(className: "_TtSaySSG", protocols: [])
        let options = ObjCTypeFormatterOptions(demangleStyle: .swift)
        let result = type.formatted(options: options)
        // Should show "[String]"
        #expect(result.contains("[String]"))
    }

    @Test("Format Dictionary String to Int type")
    func formatDictionaryStringToInt() {
        // SDySSSiG = Dictionary<String, Int>
        let type = ObjCType.id(className: "_TtSDySSSiG", protocols: [])
        let options = ObjCTypeFormatterOptions(demangleStyle: .swift)
        let result = type.formatted(options: options)
        // Should show "[String: Int]"
        #expect(result.contains("[String: Int]"))
    }

    @Test("Format Result type")
    func formatResultType() {
        // Result<String, Error> - typically mangled as custom module type
        // This is a placeholder for when we encounter Result in real binaries
        let type = ObjCType.id(className: "NSObject", protocols: [])
        let options = ObjCTypeFormatterOptions(demangleStyle: .swift)
        let result = type.formatted(options: options)
        #expect(result == "NSObject *")
    }
}
