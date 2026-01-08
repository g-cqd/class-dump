import Testing

@testable import ClassDumpCore

@Suite struct TestBlockSignature {
    @Test func zeroArguments() {
        // void (^)(void)
        // types[0] = return type (void)
        // types[1] = block self (@?)
        let types: [ObjCType] = [.void, .block(types: nil)]
        let block = ObjCType.block(types: types)
        #expect(block.formatted() == "void (^)(void)")
    }

    @Test func oneArgument() {
        // void (^)(NSData *)
        let nsData = ObjCType.id(className: "NSData", protocols: [])
        let types: [ObjCType] = [.void, .block(types: nil), nsData]
        let block = ObjCType.block(types: types)
        #expect(block.formatted() == "void (^)(NSData *)")
    }

    @Test func twoArguments() {
        // void (^)(id, NSError *)
        let idType = ObjCType.id(className: nil, protocols: [])
        let nsError = ObjCType.id(className: "NSError", protocols: [])
        let types: [ObjCType] = [.void, .block(types: nil), idType, nsError]
        let block = ObjCType.block(types: types)
        #expect(block.formatted() == "void (^)(id, NSError *)")
    }

    @Test func blockArgument() {
        // void (^)(void (^)(void))
        let nestedTypes: [ObjCType] = [.void, .block(types: nil)]
        let nestedBlock = ObjCType.block(types: nestedTypes)

        let types: [ObjCType] = [.void, .block(types: nil), nestedBlock]
        let block = ObjCType.block(types: types)
        #expect(block.formatted() == "void (^)(void (^)(void))")
    }

    @Test func charArgument() {
        // Legacy test called this "BoolArgument" but used 'c' (char).
        // New formatter outputs "char" for .char.
        let types: [ObjCType] = [.void, .block(types: nil), .char]
        let block = ObjCType.block(types: types)
        #expect(block.formatted() == "void (^)(char)")
    }
}
