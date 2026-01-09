// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

// MARK: - Swift Method Style Tests

@Suite("Swift Method Style Formatting")
struct SwiftMethodStyleTests {

    @Test("MethodStyle enum values")
    func methodStyleEnumValues() {
        #expect(MethodStyle.objc.rawValue == "objc")
        #expect(MethodStyle.swift.rawValue == "swift")
    }

    @Test("ClassDumpVisitorOptions methodStyle default")
    func methodStyleDefault() {
        let options = ClassDumpVisitorOptions()
        #expect(options.methodStyle == .objc)
    }

    @Test("ClassDumpVisitorOptions methodStyle custom")
    func methodStyleCustom() {
        let options = ClassDumpVisitorOptions(methodStyle: .swift)
        #expect(options.methodStyle == .swift)
    }

    @Test("Instance method ObjC style output")
    func instanceMethodObjCStyle() {
        let options = ClassDumpVisitorOptions(methodStyle: .objc)
        let visitor = TextClassDumpVisitor(options: options)
        let propertyState = VisitorPropertyState(properties: [])

        let method = ObjCMethod(name: "testMethod:", typeString: "v24@0:8@16")
        visitor.visitInstanceMethod(method, propertyState: propertyState)

        #expect(visitor.resultString.contains("- (void)testMethod:(id)arg1;"))
    }

    @Test("Instance method Swift style output")
    func instanceMethodSwiftStyle() {
        let options = ClassDumpVisitorOptions(methodStyle: .swift)
        let visitor = TextClassDumpVisitor(options: options)
        let propertyState = VisitorPropertyState(properties: [])

        let method = ObjCMethod(name: "testMethod:", typeString: "v24@0:8@16")
        visitor.visitInstanceMethod(method, propertyState: propertyState)

        #expect(visitor.resultString.contains("func testMethod"))
        #expect(visitor.resultString.contains("Any"))
        #expect(!visitor.resultString.contains("- ("))
    }

    @Test("Class method ObjC style output")
    func classMethodObjCStyle() {
        let options = ClassDumpVisitorOptions(methodStyle: .objc)
        let visitor = TextClassDumpVisitor(options: options)

        let method = ObjCMethod(name: "sharedInstance", typeString: "@16@0:8")
        visitor.visitClassMethod(method)

        #expect(visitor.resultString.contains("+ (id)sharedInstance;"))
    }

    @Test("Class method Swift style output")
    func classMethodSwiftStyle() {
        let options = ClassDumpVisitorOptions(methodStyle: .swift)
        let visitor = TextClassDumpVisitor(options: options)

        let method = ObjCMethod(name: "sharedInstance", typeString: "@16@0:8")
        visitor.visitClassMethod(method)

        #expect(visitor.resultString.contains("class func sharedInstance"))
        #expect(visitor.resultString.contains("-> Any"))
        #expect(!visitor.resultString.contains("+ ("))
    }

    @Test("Multi-parameter method Swift style")
    func multiParamMethodSwiftStyle() {
        let options = ClassDumpVisitorOptions(methodStyle: .swift)
        let visitor = TextClassDumpVisitor(options: options)
        let propertyState = VisitorPropertyState(properties: [])

        // initWithFrame:backgroundColor:
        let method = ObjCMethod(name: "initWithFrame:backgroundColor:", typeString: "@48@0:8{CGRect=dddd}16@40")
        visitor.visitInstanceMethod(method, propertyState: propertyState)

        #expect(visitor.resultString.contains("func initWithFrame"))
        #expect(visitor.resultString.contains("backgroundColor"))
    }

    @Test("Void return type not shown in Swift style")
    func voidReturnNotShownInSwiftStyle() {
        let options = ClassDumpVisitorOptions(methodStyle: .swift)
        let visitor = TextClassDumpVisitor(options: options)
        let propertyState = VisitorPropertyState(properties: [])

        let method = ObjCMethod(name: "doSomething", typeString: "v16@0:8")
        visitor.visitInstanceMethod(method, propertyState: propertyState)

        #expect(visitor.resultString.contains("func doSomething()"))
        #expect(!visitor.resultString.contains("-> void"))
        #expect(!visitor.resultString.contains("-> Void"))
    }

    @Test("Boolean return type shown as Bool in Swift style")
    func boolReturnInSwiftStyle() {
        let options = ClassDumpVisitorOptions(methodStyle: .swift)
        let visitor = TextClassDumpVisitor(options: options)
        let propertyState = VisitorPropertyState(properties: [])

        let method = ObjCMethod(name: "isValid", typeString: "B16@0:8")
        visitor.visitInstanceMethod(method, propertyState: propertyState)

        #expect(visitor.resultString.contains("func isValid()"))
        #expect(visitor.resultString.contains("-> Bool"))
    }

    @Test("Method style with address display")
    func methodStyleWithAddress() {
        let options = ClassDumpVisitorOptions(
            shouldShowMethodAddresses: true,
            methodStyle: .swift
        )
        let visitor = TextClassDumpVisitor(options: options)
        let propertyState = VisitorPropertyState(properties: [])

        let method = ObjCMethod(name: "test", typeString: "v16@0:8", address: 0x1000)
        visitor.visitInstanceMethod(method, propertyState: propertyState)

        #expect(visitor.resultString.contains("func test()"))
        #expect(visitor.resultString.contains("// IMP=0x1000"))
    }

    @Test("Property accessor skipped in Swift style")
    func propertyAccessorSkippedInSwiftStyle() {
        let options = ClassDumpVisitorOptions(methodStyle: .swift)
        let visitor = TextClassDumpVisitor(options: options)

        let property = ObjCProperty(name: "value", attributeString: "Ti,V_value")
        let propertyState = VisitorPropertyState(properties: [property])

        // The getter method should be skipped because it's a property accessor
        let method = ObjCMethod(name: "value", typeString: "i16@0:8")
        visitor.visitInstanceMethod(method, propertyState: propertyState)

        #expect(visitor.resultString.isEmpty)
    }
}

// MARK: - ObjCTypeFormatter Swift Method Tests

@Suite("ObjCTypeFormatter Swift Method Formatting")
struct TypeFormatterSwiftMethodTests {

    @Test("formatSwiftMethodName unary method")
    func formatSwiftMethodUnary() {
        let formatter = ObjCTypeFormatter()
        let result = formatter.formatSwiftMethodName("count", typeString: "q16@0:8")

        #expect(result == "func count() -> long long")
    }

    @Test("formatSwiftMethodName with parameter")
    func formatSwiftMethodWithParam() {
        let formatter = ObjCTypeFormatter()
        let result = formatter.formatSwiftMethodName("setValue:", typeString: "v24@0:8i16")

        #expect(result != nil)
        #expect(result!.contains("func setValue"))
        #expect(result!.contains("int"))
    }

    @Test("formatSwiftMethodName class method")
    func formatSwiftMethodClassMethod() {
        let formatter = ObjCTypeFormatter()
        let result = formatter.formatSwiftMethodName("shared", typeString: "@16@0:8", isClassMethod: true)

        #expect(result != nil)
        #expect(result!.hasPrefix("class func "))
        #expect(result!.contains("-> Any"))
    }

    @Test("formatSwiftMethodName void return")
    func formatSwiftMethodVoidReturn() {
        let formatter = ObjCTypeFormatter()
        let result = formatter.formatSwiftMethodName("doWork", typeString: "v16@0:8")

        #expect(result == "func doWork()")
        #expect(!result!.contains("->"))
    }

    @Test("formatSwiftMethodName id parameter becomes Any")
    func formatSwiftMethodIdParamBecomesAny() {
        let formatter = ObjCTypeFormatter()
        let result = formatter.formatSwiftMethodName("process:", typeString: "v24@0:8@16")

        #expect(result != nil)
        #expect(result!.contains("Any"))
        #expect(!result!.contains("id "))
    }

    @Test("formatSwiftMethodName BOOL parameter becomes Bool")
    func formatSwiftMethodBoolParam() {
        let formatter = ObjCTypeFormatter()
        let result = formatter.formatSwiftMethodName("setEnabled:", typeString: "v20@0:8B16")

        #expect(result != nil)
        #expect(result!.contains("Bool"))
    }

    @Test("formatSwiftMethodName multi-parameter method")
    func formatSwiftMethodMultiParam() {
        let formatter = ObjCTypeFormatter()
        // initWithName:value:
        let result = formatter.formatSwiftMethodName("initWithName:value:", typeString: "@32@0:8@16i24")

        #expect(result != nil)
        #expect(result!.contains("func initWithName"))
        #expect(result!.contains("value"))
        #expect(result!.contains("-> Any"))
    }

    @Test("formatSwiftMethodName returns nil for invalid encoding")
    func formatSwiftMethodInvalidEncoding() {
        let formatter = ObjCTypeFormatter()
        let result = formatter.formatSwiftMethodName("test", typeString: "")

        #expect(result == nil)
    }

    @Test("formatSwiftMethodName SEL becomes Selector")
    func formatSwiftMethodSelectorParam() {
        let formatter = ObjCTypeFormatter()
        let result = formatter.formatSwiftMethodName("performSelector:", typeString: "@24@0:8:16")

        #expect(result != nil)
        #expect(result!.contains("Selector"))
    }

    @Test("formatSwiftMethodName Class becomes AnyClass")
    func formatSwiftMethodClassParam() {
        let formatter = ObjCTypeFormatter()
        let result = formatter.formatSwiftMethodName("isKindOfClass:", typeString: "B24@0:8#16")

        #expect(result != nil)
        #expect(result!.contains("AnyClass"))
        #expect(result!.contains("-> Bool"))
    }
}
