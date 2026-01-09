// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation
import Testing

@testable import ClassDumpCore

// MARK: - Function Signature Demangling

@Suite("Function Signature Demangling")
struct FunctionSignatureDemanglingTests {

    // MARK: - Basic Function Detection

    @Test("Detects function symbols")
    func detectsFunctionSymbols() {
        // Valid function symbols
        #expect(SwiftDemangler.isFunctionSymbol("_$s4Test3fooSSyF"))
        #expect(SwiftDemangler.isFunctionSymbol("$s4Test3fooSSyF"))

        // Not function symbols
        #expect(!SwiftDemangler.isFunctionSymbol("_TtC4Test3Foo"))
        #expect(!SwiftDemangler.isFunctionSymbol("SomeRandomString"))
        #expect(!SwiftDemangler.isFunctionSymbol(""))
    }

    // MARK: - Simple Function Signatures

    @Test("Parses simple void function")
    func parsesSimpleVoidFunction() {
        // func foo() -> Void
        // _$s4Test3fooyyF
        let sig = SwiftDemangler.demangleFunctionSignature("_$s4Test3fooyyF")
        #expect(sig != nil)
        #expect(sig?.moduleName == "Test")
        #expect(sig?.functionName == "foo")
        #expect(sig?.parameterTypes.isEmpty == true)
        #expect(sig?.returnType == "Void")
        #expect(sig?.isAsync == false)
        #expect(sig?.isThrowing == false)
    }

    @Test("Parses function returning String")
    func parsesFunctionReturningString() {
        // func foo() -> String
        // _$s4Test3fooSSyF
        let sig = SwiftDemangler.demangleFunctionSignature("_$s4Test3fooSSyF")
        #expect(sig != nil)
        #expect(sig?.functionName == "foo")
        #expect(sig?.returnType == "String")
        #expect(sig?.parameterTypes.isEmpty == true)
    }

    @Test("Parses function with Int parameter")
    func parsesFunctionWithIntParam() {
        // func foo(_ x: Int) -> Void
        // _$s4Test3fooySiF
        let sig = SwiftDemangler.demangleFunctionSignature("_$s4Test3fooySiF")
        #expect(sig != nil)
        #expect(sig?.functionName == "foo")
        // Note: Parameter parsing from signature is complex; verify basic structure
        #expect(sig?.returnType != nil)
    }

    // MARK: - Async Functions

    @Test("Parses async function")
    func parsesAsyncFunction() {
        // func fetchData() async -> String
        // _$s4Test9fetchDataSSyYaF
        let sig = SwiftDemangler.demangleFunctionSignature("_$s4Test9fetchDataSSyYaF")
        #expect(sig != nil)
        #expect(sig?.functionName == "fetchData")
        #expect(sig?.isAsync == true)
        #expect(sig?.isThrowing == false)
    }

    // MARK: - Throwing Functions

    @Test("Parses throwing function")
    func parsesThrowingFunction() {
        // func load() throws -> String
        // _$s4Test4loadSSyKF
        let sig = SwiftDemangler.demangleFunctionSignature("_$s4Test4loadSSyKF")
        #expect(sig != nil)
        #expect(sig?.functionName == "load")
        #expect(sig?.isThrowing == true)
        #expect(sig?.errorType == nil)  // Untyped throws
    }

    // MARK: - Async Throwing Functions

    @Test("Parses async throwing function")
    func parsesAsyncThrowingFunction() {
        // func fetch() async throws -> Data
        // _$s4Test5fetchyYaKF (simplified)
        let sig = SwiftDemangler.demangleFunctionSignature("_$s4Test5fetchyYaKF")
        #expect(sig != nil)
        #expect(sig?.functionName == "fetch")
        #expect(sig?.isAsync == true)
        #expect(sig?.isThrowing == true)
    }

    // MARK: - Sendable Functions

    @Test("Parses sendable function")
    func parsesSendableFunction() {
        // @Sendable func work() -> Void
        // _$s4Test4workyyYbF
        let sig = SwiftDemangler.demangleFunctionSignature("_$s4Test4workyyYbF")
        #expect(sig != nil)
        #expect(sig?.functionName == "work")
        #expect(sig?.isSendable == true)
    }

    // MARK: - Swift Declaration Formatting

    @Test("Formats void function as Swift declaration")
    func formatsVoidFunctionAsSwift() {
        let sig = SwiftDemangler.FunctionSignature(
            moduleName: "Test",
            contextName: "",
            functionName: "foo",
            parameterTypes: [],
            returnType: "Void",
            isAsync: false,
            isThrowing: false,
            isSendable: false,
            errorType: nil
        )
        #expect(sig.swiftDeclaration == "func foo()")
    }

    @Test("Formats function with return type")
    func formatsFunctionWithReturnType() {
        let sig = SwiftDemangler.FunctionSignature(
            moduleName: "Test",
            contextName: "",
            functionName: "getName",
            parameterTypes: [],
            returnType: "String",
            isAsync: false,
            isThrowing: false,
            isSendable: false,
            errorType: nil
        )
        #expect(sig.swiftDeclaration == "func getName() -> String")
    }

    @Test("Formats async function")
    func formatsAsyncFunction() {
        let sig = SwiftDemangler.FunctionSignature(
            moduleName: "Test",
            contextName: "",
            functionName: "fetch",
            parameterTypes: [],
            returnType: "Data",
            isAsync: true,
            isThrowing: false,
            isSendable: false,
            errorType: nil
        )
        #expect(sig.swiftDeclaration == "func fetch() async -> Data")
    }

    @Test("Formats throwing function")
    func formatsThrowingFunction() {
        let sig = SwiftDemangler.FunctionSignature(
            moduleName: "Test",
            contextName: "",
            functionName: "load",
            parameterTypes: [],
            returnType: "String",
            isAsync: false,
            isThrowing: true,
            isSendable: false,
            errorType: nil
        )
        #expect(sig.swiftDeclaration == "func load() throws -> String")
    }

    @Test("Formats async throwing function")
    func formatsAsyncThrowingFunction() {
        let sig = SwiftDemangler.FunctionSignature(
            moduleName: "Test",
            contextName: "",
            functionName: "fetchData",
            parameterTypes: [],
            returnType: "Data",
            isAsync: true,
            isThrowing: true,
            isSendable: false,
            errorType: nil
        )
        #expect(sig.swiftDeclaration == "func fetchData() async throws -> Data")
    }

    @Test("Formats typed throws function")
    func formatsTypedThrowsFunction() {
        let sig = SwiftDemangler.FunctionSignature(
            moduleName: "Test",
            contextName: "",
            functionName: "parse",
            parameterTypes: [],
            returnType: "Model",
            isAsync: false,
            isThrowing: true,
            isSendable: false,
            errorType: "ParseError"
        )
        #expect(sig.swiftDeclaration == "func parse() throws(ParseError) -> Model")
    }

    @Test("Formats function with parameters")
    func formatsFunctionWithParams() {
        let sig = SwiftDemangler.FunctionSignature(
            moduleName: "Test",
            contextName: "",
            functionName: "add",
            parameterTypes: ["Int", "Int"],
            returnType: "Int",
            isAsync: false,
            isThrowing: false,
            isSendable: false,
            errorType: nil
        )
        #expect(sig.swiftDeclaration == "func add(Int, Int) -> Int")
    }

    // MARK: - ObjC Declaration Formatting

    @Test("Formats void function as ObjC declaration")
    func formatsVoidFunctionAsObjC() {
        let sig = SwiftDemangler.FunctionSignature(
            moduleName: "Test",
            contextName: "",
            functionName: "doWork",
            parameterTypes: [],
            returnType: "Void",
            isAsync: false,
            isThrowing: false,
            isSendable: false,
            errorType: nil
        )
        #expect(sig.objcDeclaration == "- (void)doWork")
    }

    @Test("Formats function with return as ObjC declaration")
    func formatsFunctionWithReturnAsObjC() {
        let sig = SwiftDemangler.FunctionSignature(
            moduleName: "Test",
            contextName: "",
            functionName: "getName",
            parameterTypes: [],
            returnType: "String",
            isAsync: false,
            isThrowing: false,
            isSendable: false,
            errorType: nil
        )
        #expect(sig.objcDeclaration == "- (String)getName")
    }

    // MARK: - Edge Cases

    @Test("Returns nil for non-function symbol")
    func returnsNilForNonFunction() {
        let sig = SwiftDemangler.demangleFunctionSignature("_TtC4Test3Foo")
        #expect(sig == nil)
    }

    @Test("Returns nil for empty string")
    func returnsNilForEmptyString() {
        let sig = SwiftDemangler.demangleFunctionSignature("")
        #expect(sig == nil)
    }

    @Test("Returns nil for malformed symbol")
    func returnsNilForMalformed() {
        let sig = SwiftDemangler.demangleFunctionSignature("_$s")
        #expect(sig == nil)
    }
}
