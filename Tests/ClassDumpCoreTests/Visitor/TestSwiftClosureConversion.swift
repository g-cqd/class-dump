// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

@Suite("Swift Closure to ObjC Block Conversion")
struct SwiftClosureConversionTests {
    @Test("Swift closure with void return converts to ObjC block")
    func voidReturnClosure() {
        let options = ClassDumpVisitorOptions(outputStyle: .objc)
        let visitor = TextClassDumpVisitor(options: options)

        let ivar = ObjCInstanceVariable(
            name: "_handler",
            typeEncoding: "@?",
            typeString: "(String) -> Void",
            offset: 8
        )

        visitor.appendIvar(ivar)

        #expect(visitor.resultString.contains("void (^)(NSString *)"))
    }

    @Test("Swift closure with return type converts to ObjC block")
    func returnTypeClosure() {
        let options = ClassDumpVisitorOptions(outputStyle: .objc)
        let visitor = TextClassDumpVisitor(options: options)

        let ivar = ObjCInstanceVariable(
            name: "_transform",
            typeEncoding: "@?",
            typeString: "(Int) -> String",
            offset: 8
        )

        visitor.appendIvar(ivar)

        #expect(visitor.resultString.contains("NSString * (^)(NSInteger)"))
    }

    @Test("Swift closure with multiple parameters converts correctly")
    func multipleParamsClosure() {
        let options = ClassDumpVisitorOptions(outputStyle: .objc)
        let visitor = TextClassDumpVisitor(options: options)

        let ivar = ObjCInstanceVariable(
            name: "_callback",
            typeEncoding: "@?",
            typeString: "(String, Bool) -> Int",
            offset: 8
        )

        visitor.appendIvar(ivar)

        #expect(visitor.resultString.contains("NSInteger (^)(NSString *, BOOL)"))
    }

    @Test("Swift closure with no parameters converts correctly")
    func noParamsClosure() {
        let options = ClassDumpVisitorOptions(outputStyle: .objc)
        let visitor = TextClassDumpVisitor(options: options)

        let ivar = ObjCInstanceVariable(
            name: "_action",
            typeEncoding: "@?",
            typeString: "() -> Void",
            offset: 8
        )

        visitor.appendIvar(ivar)

        #expect(visitor.resultString.contains("void (^)(void)"))
    }

    @Test("Swift @escaping closure strips attribute")
    func escapingClosure() {
        let options = ClassDumpVisitorOptions(outputStyle: .objc)
        let visitor = TextClassDumpVisitor(options: options)

        let ivar = ObjCInstanceVariable(
            name: "_completion",
            typeEncoding: "@?",
            typeString: "@escaping (Data?) -> Void",
            offset: 8
        )

        visitor.appendIvar(ivar)

        #expect(visitor.resultString.contains("void (^)(NSData *)"))
    }

    @Test("Swift @Sendable closure strips attribute")
    func sendableClosure() {
        let options = ClassDumpVisitorOptions(outputStyle: .objc)
        let visitor = TextClassDumpVisitor(options: options)

        let ivar = ObjCInstanceVariable(
            name: "_task",
            typeEncoding: "@?",
            typeString: "@Sendable () -> String",
            offset: 8
        )

        visitor.appendIvar(ivar)

        #expect(visitor.resultString.contains("NSString * (^)(void)"))
    }

    @Test("Swift mode preserves closure syntax")
    func swiftModePreservesClosure() {
        let options = ClassDumpVisitorOptions(outputStyle: .swift)
        let visitor = TextClassDumpVisitor(options: options)

        let ivar = ObjCInstanceVariable(
            name: "_handler",
            typeEncoding: "@?",
            typeString: "(String) -> Void",
            offset: 8
        )

        visitor.appendIvar(ivar)

        // Swift mode should preserve the original Swift syntax
        #expect(visitor.resultString.contains("(String) -> Void"))
    }
}
