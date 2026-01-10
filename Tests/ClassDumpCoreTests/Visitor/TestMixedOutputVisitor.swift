// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation
import Testing

@testable import ClassDumpCore

/// Tests for MixedOutputVisitor.
@Suite("Mixed Output Visitor Tests")
struct MixedOutputVisitorTests {

    // MARK: - Basic Output Tests

    @Test("Mixed output visitor produces header")
    func producesHeader() {
        let visitor = MixedOutputVisitor(options: .init())
        visitor.willBeginVisiting()

        #expect(visitor.resultString.contains("import <Foundation/Foundation.h>"))
        #expect(visitor.resultString.contains("Mixed ObjC/Swift"))
    }

    @Test("Mixed output visitor formats protocol in both styles")
    func formatsProtocolInBothStyles() {
        let visitor = MixedOutputVisitor(options: .init())
        visitor.willBeginVisiting()

        let proto = ObjCProtocol(name: "TestProtocol")
        let nsObjectProto = ObjCProtocol(name: "NSObject")
        proto.addAdoptedProtocol(nsObjectProto)

        visitor.willVisitProtocol(proto)
        visitor.didVisitProtocol(proto)

        // Should have ObjC format
        #expect(visitor.resultString.contains("@protocol TestProtocol"))
        #expect(visitor.resultString.contains("@end"))

        // Should have Swift format
        #expect(visitor.resultString.contains("@objc public protocol TestProtocol"))
        #expect(visitor.resultString.contains(": NSObject"))

        // Should have section markers
        #expect(visitor.resultString.contains("=== Objective-C ==="))
        #expect(visitor.resultString.contains("=== Swift ==="))
    }

    @Test("Mixed output visitor formats class in both styles")
    func formatsClassInBothStyles() {
        let visitor = MixedOutputVisitor(options: .init())
        visitor.willBeginVisiting()

        let objcClass = ObjCClass(name: "TestClass")
        objcClass.superclassRef = ObjCClassReference(name: "NSObject")
        let nscodingProto = ObjCProtocol(name: "NSCoding")
        objcClass.addAdoptedProtocol(nscodingProto)

        visitor.willVisitClass(objcClass)
        visitor.didVisitClass(objcClass)

        // Should have ObjC format
        #expect(visitor.resultString.contains("@interface TestClass : NSObject"))
        #expect(visitor.resultString.contains("<NSCoding>"))
        #expect(visitor.resultString.contains("@end"))

        // Should have Swift format
        #expect(visitor.resultString.contains("@objc public class TestClass : NSObject"))
        #expect(visitor.resultString.contains(", NSCoding"))
    }

    @Test("Mixed output visitor formats category in both styles")
    func formatsCategoryInBothStyles() {
        let visitor = MixedOutputVisitor(options: .init())
        visitor.willBeginVisiting()

        let category = ObjCCategory(name: "Additions")
        category.classRef = ObjCClassReference(name: "NSString")

        visitor.willVisitCategory(category)
        visitor.didVisitCategory(category)

        // Should have ObjC format
        #expect(visitor.resultString.contains("@interface NSString (Additions)"))
        #expect(visitor.resultString.contains("@end"))

        // Should have Swift format
        #expect(visitor.resultString.contains("@objc public extension NSString"))
        #expect(visitor.resultString.contains("// MARK: - NSString+Additions"))
    }

    // MARK: - Method Formatting Tests

    @Test("Mixed output visitor formats instance method in both styles")
    func formatsInstanceMethodInBothStyles() {
        let visitor = MixedOutputVisitor(options: .init())
        visitor.willBeginVisiting()

        let objcClass = ObjCClass(name: "TestClass")
        visitor.willVisitClass(objcClass)

        let method = ObjCMethod(name: "doSomething", typeString: "v16@0:8")
        let propertyState = VisitorPropertyState(properties: [])

        visitor.visitInstanceMethod(method, propertyState: propertyState)
        visitor.didVisitClass(objcClass)

        // Should have ObjC format
        #expect(visitor.resultString.contains("- (void)doSomething;"))

        // Should have Swift format
        #expect(visitor.resultString.contains("@objc func doSomething"))
    }

    @Test("Mixed output visitor formats class method in both styles")
    func formatsClassMethodInBothStyles() {
        let visitor = MixedOutputVisitor(options: .init())
        visitor.willBeginVisiting()

        let objcClass = ObjCClass(name: "TestClass")
        visitor.willVisitClass(objcClass)

        let method = ObjCMethod(name: "sharedInstance", typeString: "@16@0:8")

        visitor.visitClassMethod(method)
        visitor.didVisitClass(objcClass)

        // Should have ObjC format
        #expect(visitor.resultString.contains("+ ") || visitor.resultString.contains("+"))

        // Should have Swift format
        #expect(visitor.resultString.contains("class func sharedInstance"))
    }

    // MARK: - Property Formatting Tests

    @Test("Mixed output visitor formats property in both styles")
    func formatsPropertyInBothStyles() {
        let visitor = MixedOutputVisitor(options: .init())
        visitor.willBeginVisiting()

        let objcClass = ObjCClass(name: "TestClass")
        visitor.willVisitClass(objcClass)

        let property = ObjCProperty(name: "name", attributeString: "T@\"NSString\",&,N")

        visitor.visitProperty(property)
        visitor.didVisitClass(objcClass)

        // Should have ObjC format
        #expect(visitor.resultString.contains("@property"))
        #expect(visitor.resultString.contains("name"))

        // Should have Swift format
        #expect(visitor.resultString.contains("@objc public var name"))
        #expect(visitor.resultString.contains("{ get set }"))
    }

    @Test("Mixed output visitor formats readonly property")
    func formatsReadonlyPropertyInBothStyles() {
        let visitor = MixedOutputVisitor(options: .init())
        visitor.willBeginVisiting()

        let objcClass = ObjCClass(name: "TestClass")
        visitor.willVisitClass(objcClass)

        let property = ObjCProperty(name: "count", attributeString: "Ti,R")

        visitor.visitProperty(property)
        visitor.didVisitClass(objcClass)

        // ObjC should have readonly
        #expect(visitor.resultString.contains("readonly"))

        // Swift should have only { get }
        #expect(visitor.resultString.contains("{ get }"))
        #expect(!visitor.resultString.contains("{ get set }"))
    }

    // MARK: - Instance Variable Tests

    @Test("Mixed output visitor formats ivar in both styles")
    func formatsIvarInBothStyles() {
        let visitor = MixedOutputVisitor(options: .init())
        visitor.willBeginVisiting()

        let objcClass = ObjCClass(name: "TestClass")
        visitor.willVisitClass(objcClass)
        visitor.willVisitIvarsOfClass(objcClass)

        let ivar = ObjCInstanceVariable(
            name: "myInt",
            typeEncoding: "i",
            offset: 8
        )

        visitor.visitIvar(ivar)
        visitor.didVisitIvarsOfClass(objcClass)
        visitor.didVisitClass(objcClass)

        // Should have ObjC format
        #expect(visitor.resultString.contains("myInt;"))

        // Should have Swift format
        #expect(visitor.resultString.contains("private var myInt"))
        #expect(visitor.resultString.contains("Int32"))
    }

    // MARK: - Optional Methods Tests

    @Test("Mixed output visitor handles optional methods")
    func handlesOptionalMethods() {
        let visitor = MixedOutputVisitor(options: .init())
        visitor.willBeginVisiting()

        let proto = ObjCProtocol(name: "TestDelegate")
        visitor.willVisitProtocol(proto)

        visitor.willVisitOptionalMethods()

        let method = ObjCMethod(name: "optionalCallback", typeString: "v16@0:8")
        let propertyState = VisitorPropertyState(properties: [])
        visitor.visitInstanceMethod(method, propertyState: propertyState)

        visitor.didVisitOptionalMethods()
        visitor.didVisitProtocol(proto)

        // ObjC should have @optional
        #expect(visitor.resultString.contains("@optional"))

        // Swift should have @objc optional
        #expect(visitor.resultString.contains("@objc optional func optionalCallback"))
    }

    // MARK: - Demangling Tests

    @Test("Mixed output visitor demangles Swift names in both outputs")
    func demanglesSwiftNames() {
        var options = ClassDumpVisitorOptions()
        options.demangleStyle = .swift

        let visitor = MixedOutputVisitor(options: options)
        visitor.willBeginVisiting()

        let objcClass = ObjCClass(name: "_TtC10TestModule9TestClass")
        objcClass.superclassRef = ObjCClassReference(name: "NSObject")

        visitor.willVisitClass(objcClass)
        visitor.didVisitClass(objcClass)

        // Should demangle to TestModule.TestClass in both outputs
        #expect(visitor.resultString.contains("TestModule.TestClass"))
    }

    // MARK: - Address Display Tests

    @Test("Mixed output visitor shows addresses when enabled")
    func showsAddressesWhenEnabled() {
        var options = ClassDumpVisitorOptions()
        options.shouldShowMethodAddresses = true

        let visitor = MixedOutputVisitor(options: options)
        visitor.willBeginVisiting()

        let objcClass = ObjCClass(name: "TestClass")
        visitor.willVisitClass(objcClass)

        let method = ObjCMethod(name: "test", typeString: "v16@0:8", address: 0x1234)
        let propertyState = VisitorPropertyState(properties: [])

        visitor.visitInstanceMethod(method, propertyState: propertyState)
        visitor.didVisitClass(objcClass)

        // Should show IMP in both outputs
        #expect(visitor.resultString.contains("IMP=0x1234"))
    }

    // MARK: - Section Headers Tests

    @Test("Mixed output visitor includes entity name in section header")
    func includesEntityNameInSectionHeader() {
        let visitor = MixedOutputVisitor(options: .init())
        visitor.willBeginVisiting()

        let proto = ObjCProtocol(name: "MyProtocol")
        visitor.willVisitProtocol(proto)
        visitor.didVisitProtocol(proto)

        #expect(visitor.resultString.contains("Protocol: MyProtocol"))
    }

    @Test("Mixed output visitor includes class name in section header")
    func includesClassNameInSectionHeader() {
        let visitor = MixedOutputVisitor(options: .init())
        visitor.willBeginVisiting()

        let objcClass = ObjCClass(name: "MyClass")
        visitor.willVisitClass(objcClass)
        visitor.didVisitClass(objcClass)

        #expect(visitor.resultString.contains("Class: MyClass"))
    }

    @Test("Mixed output visitor includes category name in section header")
    func includesCategoryNameInSectionHeader() {
        let visitor = MixedOutputVisitor(options: .init())
        visitor.willBeginVisiting()

        let category = ObjCCategory(name: "Helpers")
        category.classRef = ObjCClassReference(name: "NSArray")
        visitor.willVisitCategory(category)
        visitor.didVisitCategory(category)

        #expect(visitor.resultString.contains("Category: NSArray+Helpers"))
    }

    // MARK: - Hidden Class Tests

    @Test("Mixed output visitor handles hidden classes")
    func handlesHiddenClasses() {
        let visitor = MixedOutputVisitor(options: .init())
        visitor.willBeginVisiting()

        let objcClass = ObjCClass(name: "InternalClass")
        objcClass.isExported = false

        visitor.willVisitClass(objcClass)
        visitor.didVisitClass(objcClass)

        // ObjC should have visibility attribute
        #expect(visitor.resultString.contains("visibility(\"hidden\")"))

        // Swift should have @_implementationOnly
        #expect(visitor.resultString.contains("@_implementationOnly"))
    }
}
