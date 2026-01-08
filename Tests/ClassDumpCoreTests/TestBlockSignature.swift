import Testing

@testable import ClassDumpCore

@Suite("Block Signature Tests")
struct TestBlockSignature {
    // MARK: - Basic Block Signatures

    @Test("Block with zero arguments")
    func zeroArguments() {
        // void (^)(void)
        // types[0] = return type (void)
        // types[1] = block self (@?)
        let types: [ObjCType] = [.void, .block(types: nil)]
        let block = ObjCType.block(types: types)
        #expect(block.formatted() == "void (^)(void)")
    }

    @Test("Block with one argument")
    func oneArgument() {
        // void (^)(NSData *)
        let nsData = ObjCType.id(className: "NSData", protocols: [])
        let types: [ObjCType] = [.void, .block(types: nil), nsData]
        let block = ObjCType.block(types: types)
        #expect(block.formatted() == "void (^)(NSData *)")
    }

    @Test("Block with two arguments")
    func twoArguments() {
        // void (^)(id, NSError *)
        let idType = ObjCType.id(className: nil, protocols: [])
        let nsError = ObjCType.id(className: "NSError", protocols: [])
        let types: [ObjCType] = [.void, .block(types: nil), idType, nsError]
        let block = ObjCType.block(types: types)
        #expect(block.formatted() == "void (^)(id, NSError *)")
    }

    @Test("Block with block argument (nested)")
    func blockArgument() {
        // void (^)(void (^)(void))
        let nestedTypes: [ObjCType] = [.void, .block(types: nil)]
        let nestedBlock = ObjCType.block(types: nestedTypes)

        let types: [ObjCType] = [.void, .block(types: nil), nestedBlock]
        let block = ObjCType.block(types: types)
        #expect(block.formatted() == "void (^)(void (^)(void))")
    }

    @Test("Block with char argument")
    func charArgument() {
        let types: [ObjCType] = [.void, .block(types: nil), .char]
        let block = ObjCType.block(types: types)
        #expect(block.formatted() == "void (^)(char)")
    }

    // MARK: - Block Return Types

    @Test("Block returning BOOL")
    func boolReturnType() {
        // BOOL (^)(void)
        let types: [ObjCType] = [.bool, .block(types: nil)]
        let block = ObjCType.block(types: types)
        #expect(block.formatted() == "_Bool (^)(void)")
    }

    @Test("Block returning id")
    func idReturnType() {
        // id (^)(void)
        let idType = ObjCType.id(className: nil, protocols: [])
        let types: [ObjCType] = [idType, .block(types: nil)]
        let block = ObjCType.block(types: types)
        #expect(block.formatted() == "id (^)(void)")
    }

    @Test("Block returning NSString")
    func nsStringReturnType() {
        // NSString * (^)(void)
        let nsString = ObjCType.id(className: "NSString", protocols: [])
        let types: [ObjCType] = [nsString, .block(types: nil)]
        let block = ObjCType.block(types: types)
        #expect(block.formatted() == "NSString * (^)(void)")
    }

    // MARK: - Block with Variable Name

    @Test("Block with variable name - no signature")
    func blockWithVariableNameNoSignature() {
        // id /* block */ completionHandler
        let block = ObjCType.block(types: nil)
        #expect(block.formatted(variableName: "completionHandler") == "id /* block */ completionHandler")
    }

    @Test("Block with variable name - with signature")
    func blockWithVariableNameWithSignature() {
        // void (^completionHandler)(void)
        let types: [ObjCType] = [.void, .block(types: nil)]
        let block = ObjCType.block(types: types)
        #expect(block.formatted(variableName: "completionHandler") == "void (^completionHandler)(void)")
    }

    @Test("Block with variable name - with arguments")
    func blockWithVariableNameWithArgs() {
        // void (^handler)(BOOL, NSError *)
        let nsError = ObjCType.id(className: "NSError", protocols: [])
        let types: [ObjCType] = [.void, .block(types: nil), .bool, nsError]
        let block = ObjCType.block(types: types)
        #expect(block.formatted(variableName: "handler") == "void (^handler)(_Bool, NSError *)")
    }

    // MARK: - Block Parsing

    @Test("Parse block without signature")
    func parseBlockWithoutSignature() throws {
        let type = try ObjCType.parse("@?")
        #expect(type == .block(types: nil))
        #expect(type.formatted() == "id /* block */")
    }

    @Test("Parse block with void signature")
    func parseBlockWithVoidSignature() throws {
        // @?<v@?> means: block returning void, with block self parameter
        let type = try ObjCType.parse("@?<v@?>")
        guard case .block(let types) = type else {
            Issue.record("Expected block type")
            return
        }
        #expect(types?.count == 2)
        #expect(types?[0] == .void)
        #expect(type.formatted() == "void (^)(void)")
    }

    @Test("Parse block with id parameter")
    func parseBlockWithIdParameter() throws {
        // @?<v@?@> means: block returning void, block self, id parameter
        let type = try ObjCType.parse("@?<v@?@>")
        guard case .block(let types) = type else {
            Issue.record("Expected block type")
            return
        }
        #expect(types?.count == 3)
        #expect(types?[0] == .void)
        #expect(types?[2] == .id(className: nil, protocols: []))
        #expect(type.formatted() == "void (^)(id)")
    }

    @Test("Parse block returning BOOL with two id parameters")
    func parseBlockReturningBoolWithParams() throws {
        // @?<B@?@@> means: block returning BOOL, block self, id, id
        let type = try ObjCType.parse("@?<B@?@@>")
        guard case .block(let types) = type else {
            Issue.record("Expected block type")
            return
        }
        #expect(types?.count == 4)
        #expect(types?[0] == .bool)
        #expect(type.formatted() == "_Bool (^)(id, id)")
    }

    // MARK: - Completion Handler Patterns

    @Test("Completion handler pattern - success/error")
    func completionHandlerSuccessError() {
        // Common pattern: void (^)(BOOL success, NSError *error)
        let nsError = ObjCType.id(className: "NSError", protocols: [])
        let types: [ObjCType] = [.void, .block(types: nil), .bool, nsError]
        let block = ObjCType.block(types: types)
        #expect(block.formatted() == "void (^)(_Bool, NSError *)")
    }

    @Test("Completion handler pattern - data/response/error")
    func completionHandlerDataResponseError() {
        // Common pattern: void (^)(NSData *data, NSURLResponse *response, NSError *error)
        let nsData = ObjCType.id(className: "NSData", protocols: [])
        let nsURLResponse = ObjCType.id(className: "NSURLResponse", protocols: [])
        let nsError = ObjCType.id(className: "NSError", protocols: [])
        let types: [ObjCType] = [.void, .block(types: nil), nsData, nsURLResponse, nsError]
        let block = ObjCType.block(types: types)
        #expect(block.formatted() == "void (^)(NSData *, NSURLResponse *, NSError *)")
    }
}
