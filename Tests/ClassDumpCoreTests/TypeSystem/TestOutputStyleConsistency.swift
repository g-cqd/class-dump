// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

// MARK: - Output Style Consistency Tests

@Suite("Output Style Consistency")
struct OutputStyleConsistencyTests {

    // MARK: - ObjC Output Mode Tests

    @Test("ObjC mode converts Swift Array syntax to NSArray")
    func objcModeConvertsArray() {
        let type = ObjCType.id(className: "_TtSaySSG", protocols: [])
        let options = ObjCTypeFormatterOptions(demangleStyle: .swift, outputStyle: .objc)
        let result = type.formatted(options: options)
        #expect(result == "NSArray *")
    }

    @Test("ObjC mode converts Swift Dictionary syntax to NSDictionary")
    func objcModeConvertsDictionary() {
        let type = ObjCType.id(className: "_TtSDySSSiG", protocols: [])
        let options = ObjCTypeFormatterOptions(demangleStyle: .swift, outputStyle: .objc)
        let result = type.formatted(options: options)
        #expect(result == "NSDictionary *")
    }

    @Test("ObjC mode converts Swift Optional to pointer")
    func objcModeConvertsOptional() {
        let type = ObjCType.id(className: "_TtSSSg", protocols: [])
        let options = ObjCTypeFormatterOptions(demangleStyle: .swift, outputStyle: .objc)
        let result = type.formatted(options: options)
        // String? → String (with pointer added by formatter)
        #expect(result == "String *")
    }

    @Test("ObjC mode adds pointer to module-qualified class")
    func objcModeAddsPointerToClass() {
        let type = ObjCType.id(className: "_TtC8MyModule7MyClass", protocols: [])
        let options = ObjCTypeFormatterOptions(demangleStyle: .swift, outputStyle: .objc)
        let result = type.formatted(options: options)
        #expect(result == "MyModule.MyClass *")
    }

    @Test("ObjC mode preserves regular ObjC class pointer")
    func objcModePreservesObjCClass() {
        let type = ObjCType.id(className: "NSString", protocols: [])
        let options = ObjCTypeFormatterOptions(demangleStyle: .swift, outputStyle: .objc)
        let result = type.formatted(options: options)
        #expect(result == "NSString *")
    }

    // MARK: - Swift Output Mode Tests

    @Test("Swift mode preserves Array syntax")
    func swiftModePreservesArray() {
        let type = ObjCType.id(className: "_TtSaySSG", protocols: [])
        let options = ObjCTypeFormatterOptions(demangleStyle: .swift, outputStyle: .swift)
        let result = type.formatted(options: options)
        #expect(result.contains("[String]"))
    }

    @Test("Swift mode preserves Dictionary syntax")
    func swiftModePreservesDictionary() {
        let type = ObjCType.id(className: "_TtSDySSSiG", protocols: [])
        let options = ObjCTypeFormatterOptions(demangleStyle: .swift, outputStyle: .swift)
        let result = type.formatted(options: options)
        #expect(result.contains("[String: Int]"))
    }

    @Test("Swift mode preserves Optional syntax")
    func swiftModePreservesOptional() {
        let type = ObjCType.id(className: "_TtSSSg", protocols: [])
        let options = ObjCTypeFormatterOptions(demangleStyle: .swift, outputStyle: .swift)
        let result = type.formatted(options: options)
        #expect(result.contains("String?"))
    }

    // MARK: - Visitor Output Style Tests

    @Test("TextClassDumpVisitor respects ObjC output style for ivars")
    func visitorObjcOutputStyle() {
        let visitorOptions = ClassDumpVisitorOptions(
            demangleStyle: .swift,
            outputStyle: .objc
        )
        let visitor = TextClassDumpVisitor(options: visitorOptions)

        let ivar = ObjCInstanceVariable(
            name: "_items",
            typeEncoding: "@",
            typeString: "[String]",
            offset: 16
        )
        visitor.visitIvar(ivar)

        // ObjC mode should convert [String] to NSArray *
        #expect(visitor.resultString.contains("NSArray *"))
        #expect(visitor.resultString.contains("_items"))
    }

    @Test("TextClassDumpVisitor respects Swift output style for ivars")
    func visitorSwiftOutputStyle() {
        let visitorOptions = ClassDumpVisitorOptions(
            demangleStyle: .swift,
            outputStyle: .swift
        )
        let visitor = TextClassDumpVisitor(options: visitorOptions)

        let ivar = ObjCInstanceVariable(
            name: "_items",
            typeEncoding: "@",
            typeString: "[String]",
            offset: 16
        )
        visitor.visitIvar(ivar)

        // Swift mode should preserve [String]
        #expect(visitor.resultString.contains("[String]"))
        #expect(visitor.resultString.contains("_items"))
    }

    @Test("TextClassDumpVisitor converts class types in ObjC mode")
    func visitorConvertsClassTypes() {
        let visitorOptions = ClassDumpVisitorOptions(
            demangleStyle: .swift,
            outputStyle: .objc
        )
        let visitor = TextClassDumpVisitor(options: visitorOptions)

        let ivar = ObjCInstanceVariable(
            name: "_delegate",
            typeEncoding: "@",
            typeString: "MyModule.MyDelegate",
            offset: 24
        )
        visitor.visitIvar(ivar)

        // ObjC mode should add pointer to class type
        #expect(visitor.resultString.contains("MyModule.MyDelegate *"))
        #expect(visitor.resultString.contains("_delegate"))
    }

    @Test("TextClassDumpVisitor converts optional types in ObjC mode")
    func visitorConvertsOptionalTypes() {
        let visitorOptions = ClassDumpVisitorOptions(
            demangleStyle: .swift,
            outputStyle: .objc
        )
        let visitor = TextClassDumpVisitor(options: visitorOptions)

        let ivar = ObjCInstanceVariable(
            name: "_name",
            typeEncoding: "@",
            typeString: "String?",
            offset: 32
        )
        visitor.visitIvar(ivar)

        // ObjC mode should convert String? to String *
        #expect(visitor.resultString.contains("String *"))
        #expect(visitor.resultString.contains("_name"))
    }

    // MARK: - Default Behavior Tests

    @Test("Default output style is ObjC")
    func defaultOutputStyleIsObjC() {
        let options = ObjCTypeFormatterOptions()
        #expect(options.outputStyle == .objc)
    }

    @Test("Default visitor output style is ObjC")
    func defaultVisitorOutputStyleIsObjC() {
        let options = ClassDumpVisitorOptions()
        #expect(options.outputStyle == .objc)
    }
}
