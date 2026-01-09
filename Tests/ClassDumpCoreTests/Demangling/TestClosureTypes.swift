// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation
import Testing

@testable import ClassDumpCore

// MARK: - Closure Type Demangling (Task 45.2)

@Suite("Closure Type Demangling")
struct ClosureTypeDemanglingTests {

    // MARK: - Closure Type Detection

    @Test("Detects escaping closure type")
    func detectsEscapingClosureType() {
        // yyc = () -> Void (escaping)
        #expect(SwiftDemangler.isClosureType("yyc"))
        #expect(SwiftDemangler.isClosureType("SSSic"))  // (Int) -> String
    }

    @Test("Detects block closure type")
    func detectsBlockClosureType() {
        // XB suffix = @convention(block)
        #expect(SwiftDemangler.isClosureType("yyXB"))
        #expect(SwiftDemangler.isClosureType("SSSiXB"))
    }

    @Test("Detects C function pointer type")
    func detectsCFunctionPointerType() {
        // XC suffix = @convention(c)
        #expect(SwiftDemangler.isClosureType("yyXC"))
        #expect(SwiftDemangler.isClosureType("SiSiXC"))
    }

    @Test("Detects noescape closure type")
    func detectsNoescapeClosureType() {
        // XE suffix = noescape
        #expect(SwiftDemangler.isClosureType("yyXE"))
        #expect(SwiftDemangler.isClosureType("SSSiXE"))
    }

    @Test("Detects thin function type")
    func detectsThinFunctionType() {
        // Xf suffix = @thin
        #expect(SwiftDemangler.isClosureType("yyXf"))
    }

    @Test("Non-closure types return false")
    func nonClosureTypesReturnFalse() {
        #expect(!SwiftDemangler.isClosureType("SS"))
        #expect(!SwiftDemangler.isClosureType("Si"))
        #expect(!SwiftDemangler.isClosureType(""))
        #expect(!SwiftDemangler.isClosureType("_TtC4Test3Foo"))
    }

    // MARK: - Basic Closure Parsing

    @Test("Parses void to void escaping closure")
    func parsesVoidToVoidEscaping() {
        // () -> Void, escaping
        let closure = SwiftDemangler.demangleClosureType("yyc")
        #expect(closure != nil)
        #expect(closure?.parameterTypes.isEmpty == true)
        #expect(closure?.returnType == "Void")
        #expect(closure?.isEscaping == true)
        #expect(closure?.convention == .swift)
    }

    @Test("Parses closure with String parameter")
    func parsesClosureWithStringParam() {
        // (String) -> Void, escaping
        let closure = SwiftDemangler.demangleClosureType("ySSc")
        #expect(closure != nil)
        #expect(closure?.parameterTypes == ["String"])
        #expect(closure?.returnType == "Void")
    }

    @Test("Parses closure with return type")
    func parsesClosureWithReturnType() {
        // () -> String, escaping
        let closure = SwiftDemangler.demangleClosureType("SSyc")
        #expect(closure != nil)
        #expect(closure?.parameterTypes.isEmpty == true)
        #expect(closure?.returnType == "String")
    }

    @Test("Parses closure with param and return")
    func parsesClosureWithParamAndReturn() {
        // (Int) -> String, escaping
        let closure = SwiftDemangler.demangleClosureType("SSSic")
        #expect(closure != nil)
        #expect(closure?.parameterTypes == ["Int"])
        #expect(closure?.returnType == "String")
    }

    // MARK: - Convention Tests

    @Test("Parses @convention(block) closure")
    func parsesBlockConvention() {
        // void (^)(void) = yyXB
        let closure = SwiftDemangler.demangleClosureType("yyXB")
        #expect(closure != nil)
        #expect(closure?.convention == .block)
        #expect(closure?.parameterTypes.isEmpty == true)
        #expect(closure?.returnType == "Void")
    }

    @Test("Parses @convention(c) closure")
    func parsesCFunctionConvention() {
        // void (*)(int) = ySiXC
        let closure = SwiftDemangler.demangleClosureType("ySiXC")
        #expect(closure != nil)
        #expect(closure?.convention == .cFunction)
        #expect(closure?.parameterTypes == ["Int"])
    }

    @Test("Parses noescape closure")
    func parsesNoescapeClosure() {
        // () -> Void, noescape = yyXE
        let closure = SwiftDemangler.demangleClosureType("yyXE")
        #expect(closure != nil)
        #expect(closure?.convention == .swift)
        #expect(closure?.isEscaping == false)
    }

    @Test("Parses @thin function type")
    func parsesThinFunction() {
        // @thin () -> Void = yyXf
        let closure = SwiftDemangler.demangleClosureType("yyXf")
        #expect(closure != nil)
        #expect(closure?.convention == .thin)
    }

    // MARK: - Effect Tests

    @Test("Parses async closure")
    func parsesAsyncClosure() {
        // () async -> String
        let closure = SwiftDemangler.demangleClosureType("SSyYac")
        #expect(closure != nil)
        #expect(closure?.isAsync == true)
        #expect(closure?.returnType == "String")
    }

    @Test("Parses throwing closure")
    func parsesThrowingClosure() {
        // () throws -> String
        let closure = SwiftDemangler.demangleClosureType("SSyKc")
        #expect(closure != nil)
        #expect(closure?.isThrowing == true)
        #expect(closure?.returnType == "String")
    }

    @Test("Parses @Sendable closure")
    func parsesSendableClosure() {
        // @Sendable () -> Void
        let closure = SwiftDemangler.demangleClosureType("yyYbc")
        #expect(closure != nil)
        #expect(closure?.isSendable == true)
    }

    @Test("Parses async throwing sendable closure")
    func parsesAsyncThrowingSendable() {
        // @Sendable () async throws -> Data
        let closure = SwiftDemangler.demangleClosureType("10Foundation4DataVyYaKYbc")
        #expect(closure != nil)
        #expect(closure?.isAsync == true)
        #expect(closure?.isThrowing == true)
        #expect(closure?.isSendable == true)
    }

    // MARK: - Swift Declaration Formatting

    @Test("Formats simple closure as Swift declaration")
    func formatsSimpleClosureAsSwift() {
        let closure = SwiftDemangler.ClosureType(
            parameterTypes: [],
            returnType: "Void",
            isEscaping: false,
            isSendable: false,
            isAsync: false,
            isThrowing: false,
            convention: .swift
        )
        #expect(closure.swiftDeclaration == "() -> Void")
    }

    @Test("Formats escaping closure as Swift declaration")
    func formatsEscapingClosureAsSwift() {
        let closure = SwiftDemangler.ClosureType(
            parameterTypes: ["String"],
            returnType: "Int",
            isEscaping: true,
            isSendable: false,
            isAsync: false,
            isThrowing: false,
            convention: .swift
        )
        #expect(closure.swiftDeclaration == "@escaping (String) -> Int")
    }

    @Test("Formats @Sendable closure as Swift declaration")
    func formatsSendableClosureAsSwift() {
        let closure = SwiftDemangler.ClosureType(
            parameterTypes: [],
            returnType: "Void",
            isEscaping: true,
            isSendable: true,
            isAsync: false,
            isThrowing: false,
            convention: .swift
        )
        #expect(closure.swiftDeclaration == "@Sendable @escaping () -> Void")
    }

    @Test("Formats async throwing closure as Swift declaration")
    func formatsAsyncThrowingClosureAsSwift() {
        let closure = SwiftDemangler.ClosureType(
            parameterTypes: [],
            returnType: "Data",
            isEscaping: true,
            isSendable: false,
            isAsync: true,
            isThrowing: true,
            convention: .swift
        )
        #expect(closure.swiftDeclaration == "@escaping () async throws -> Data")
    }

    @Test("Formats @convention(block) as Swift declaration")
    func formatsBlockConventionAsSwift() {
        let closure = SwiftDemangler.ClosureType(
            parameterTypes: ["String"],
            returnType: "Void",
            isEscaping: true,
            isSendable: false,
            isAsync: false,
            isThrowing: false,
            convention: .block
        )
        #expect(closure.swiftDeclaration == "@convention(block) (String) -> Void")
    }

    @Test("Formats @convention(c) as Swift declaration")
    func formatsCConventionAsSwift() {
        let closure = SwiftDemangler.ClosureType(
            parameterTypes: ["Int"],
            returnType: "Int",
            isEscaping: true,
            isSendable: false,
            isAsync: false,
            isThrowing: false,
            convention: .cFunction
        )
        #expect(closure.swiftDeclaration == "@convention(c) (Int) -> Int")
    }

    // MARK: - ObjC Block Declaration Formatting

    @Test("Formats simple block as ObjC declaration")
    func formatsSimpleBlockAsObjC() {
        let closure = SwiftDemangler.ClosureType(
            parameterTypes: [],
            returnType: "Void",
            isEscaping: true,
            isSendable: false,
            isAsync: false,
            isThrowing: false,
            convention: .block
        )
        #expect(closure.objcBlockDeclaration == "void (^)(void)")
    }

    @Test("Formats block with String param as ObjC declaration")
    func formatsBlockWithStringParamAsObjC() {
        let closure = SwiftDemangler.ClosureType(
            parameterTypes: ["String"],
            returnType: "Void",
            isEscaping: true,
            isSendable: false,
            isAsync: false,
            isThrowing: false,
            convention: .block
        )
        #expect(closure.objcBlockDeclaration == "void (^)(NSString *)")
    }

    @Test("Formats block with return type as ObjC declaration")
    func formatsBlockWithReturnAsObjC() {
        let closure = SwiftDemangler.ClosureType(
            parameterTypes: [],
            returnType: "Bool",
            isEscaping: true,
            isSendable: false,
            isAsync: false,
            isThrowing: false,
            convention: .block
        )
        #expect(closure.objcBlockDeclaration == "BOOL (^)(void)")
    }

    @Test("Formats block with multiple params as ObjC declaration")
    func formatsBlockWithMultipleParamsAsObjC() {
        let closure = SwiftDemangler.ClosureType(
            parameterTypes: ["String", "Int"],
            returnType: "Bool",
            isEscaping: true,
            isSendable: false,
            isAsync: false,
            isThrowing: false,
            convention: .block
        )
        #expect(closure.objcBlockDeclaration == "BOOL (^)(NSString *, NSInteger)")
    }

    // MARK: - Edge Cases

    @Test("Returns nil for empty string")
    func returnsNilForEmptyString() {
        let closure = SwiftDemangler.demangleClosureType("")
        #expect(closure == nil)
    }

    @Test("Returns nil for non-closure type")
    func returnsNilForNonClosureType() {
        let closure = SwiftDemangler.demangleClosureType("SS")
        #expect(closure == nil)
    }

    @Test("Returns nil for class type")
    func returnsNilForClassType() {
        let closure = SwiftDemangler.demangleClosureType("_TtC4Test3Foo")
        #expect(closure == nil)
    }
}
