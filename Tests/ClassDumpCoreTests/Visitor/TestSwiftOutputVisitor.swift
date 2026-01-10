import Foundation
import Testing

@testable import ClassDumpCore

/// Tests for SwiftOutputVisitor.
@Suite("Swift Output Visitor Tests")
struct SwiftOutputVisitorTests {

    // MARK: - Basic Output Tests

    @Test("Swift output visitor produces Swift-style header")
    func producesSwiftStyleHeader() {
        let visitor = SwiftOutputVisitor(options: .init())
        visitor.willBeginVisiting()

        #expect(visitor.resultString.contains("import Foundation"))
        #expect(visitor.resultString.contains("Swift-style interface"))
    }

    @Test("Swift output visitor formats protocol correctly")
    func formatsProtocolCorrectly() {
        let visitor = SwiftOutputVisitor(options: .init())
        visitor.willBeginVisiting()

        let proto = ObjCProtocol(name: "TestProtocol")
        // Add an adopted protocol
        let nsObjectProto = ObjCProtocol(name: "NSObject")
        proto.addAdoptedProtocol(nsObjectProto)

        visitor.willVisitProtocol(proto)
        visitor.didVisitProtocol(proto)

        #expect(visitor.resultString.contains("@objc public protocol TestProtocol : NSObject"))
        #expect(visitor.resultString.contains("{"))
        #expect(visitor.resultString.contains("}"))
    }

    @Test("Swift output visitor formats class correctly")
    func formatsClassCorrectly() {
        let visitor = SwiftOutputVisitor(options: .init())
        visitor.willBeginVisiting()

        let objcClass = ObjCClass(name: "TestClass")
        objcClass.superclassRef = ObjCClassReference(name: "NSObject")
        // Add a protocol conformance
        let nscodingProto = ObjCProtocol(name: "NSCoding")
        objcClass.addAdoptedProtocol(nscodingProto)

        visitor.willVisitClass(objcClass)
        visitor.didVisitClass(objcClass)

        #expect(visitor.resultString.contains("@objc public class TestClass : NSObject, NSCoding"))
        #expect(visitor.resultString.contains("{"))
        #expect(visitor.resultString.contains("}"))
    }

    @Test("Swift output visitor formats category as extension")
    func formatsCategoryAsExtension() {
        let visitor = SwiftOutputVisitor(options: .init())
        visitor.willBeginVisiting()

        let category = ObjCCategory(name: "Additions")
        category.classRef = ObjCClassReference(name: "NSString")

        visitor.willVisitCategory(category)
        visitor.didVisitCategory(category)

        #expect(visitor.resultString.contains("@objc public extension NSString"))
        #expect(visitor.resultString.contains("// MARK: - NSString+Additions"))
    }

    // MARK: - Method Formatting Tests

    @Test("Swift output visitor formats instance method")
    func formatsInstanceMethod() {
        let visitor = SwiftOutputVisitor(options: .init())
        visitor.willBeginVisiting()

        let method = ObjCMethod(name: "doSomething", typeString: "v16@0:8")
        let propertyState = VisitorPropertyState(properties: [])

        visitor.visitInstanceMethod(method, propertyState: propertyState)

        #expect(visitor.resultString.contains("@objc func doSomething"))
    }

    @Test("Swift output visitor formats class method")
    func formatsClassMethod() {
        let visitor = SwiftOutputVisitor(options: .init())
        visitor.willBeginVisiting()

        let method = ObjCMethod(name: "sharedInstance", typeString: "@16@0:8")

        visitor.visitClassMethod(method)

        #expect(visitor.resultString.contains("@objc class func sharedInstance"))
    }

    // MARK: - Property Formatting Tests

    @Test("Swift output visitor formats readonly property")
    func formatsReadonlyProperty() {
        let visitor = SwiftOutputVisitor(options: .init())
        visitor.willBeginVisiting()

        let property = ObjCProperty(name: "count", attributeString: "Ti,R")

        visitor.visitProperty(property)

        // Should have { get } without set
        #expect(visitor.resultString.contains("count"))
        #expect(visitor.resultString.contains("{ get }"))
        #expect(!visitor.resultString.contains("{ get set }"))
    }

    @Test("Swift output visitor formats readwrite property")
    func formatsReadwriteProperty() {
        let visitor = SwiftOutputVisitor(options: .init())
        visitor.willBeginVisiting()

        let property = ObjCProperty(name: "name", attributeString: "T@\"NSString\",&")

        visitor.visitProperty(property)

        // Should have { get set }
        #expect(visitor.resultString.contains("name"))
        #expect(visitor.resultString.contains("{ get set }"))
    }

    // MARK: - Type Conversion Tests

    @Test("Swift output visitor converts ObjC types to Swift")
    func convertsTypes() {
        let visitor = SwiftOutputVisitor(options: .init())
        visitor.willBeginVisiting()

        // Test with a class that has typed ivars
        let ivar = ObjCInstanceVariable(
            name: "myInt",
            typeEncoding: "i",
            offset: 0
        )

        visitor.visitIvar(ivar)

        // Int32 is the Swift equivalent of int (i)
        #expect(visitor.resultString.contains("Int32"))
    }

    // MARK: - Optional Methods Tests

    @Test("Swift output visitor marks optional methods")
    func marksOptionalMethods() {
        let visitor = SwiftOutputVisitor(options: .init())
        visitor.willBeginVisiting()

        visitor.willVisitOptionalMethods()

        let method = ObjCMethod(name: "optionalMethod", typeString: "v16@0:8")
        let propertyState = VisitorPropertyState(properties: [])
        visitor.visitInstanceMethod(method, propertyState: propertyState)

        visitor.didVisitOptionalMethods()

        #expect(visitor.resultString.contains("@objc optional func optionalMethod"))
    }

    // MARK: - Demangling Tests

    @Test("Swift output visitor demangles Swift names")
    func demanglesSwiftNames() {
        var options = ClassDumpVisitorOptions()
        options.demangleStyle = .swift

        let visitor = SwiftOutputVisitor(options: options)
        visitor.willBeginVisiting()

        // Use a mangled Swift class name
        let objcClass = ObjCClass(name: "_TtC10TestModule9TestClass")
        objcClass.superclassRef = ObjCClassReference(name: "NSObject")

        visitor.willVisitClass(objcClass)
        visitor.didVisitClass(objcClass)

        // Should demangle to TestModule.TestClass
        #expect(visitor.resultString.contains("TestModule.TestClass"))
    }

    // MARK: - Address Display Tests

    @Test("Swift output visitor shows addresses when enabled")
    func showsAddressesWhenEnabled() {
        var options = ClassDumpVisitorOptions()
        options.shouldShowMethodAddresses = true

        let visitor = SwiftOutputVisitor(options: options)
        visitor.willBeginVisiting()

        let method = ObjCMethod(name: "test", typeString: "v16@0:8", address: 0x1234)
        let propertyState = VisitorPropertyState(properties: [])

        visitor.visitInstanceMethod(method, propertyState: propertyState)

        #expect(visitor.resultString.contains("IMP=0x1234"))
    }

    @Test("Swift output visitor shows raw types when enabled")
    func showsRawTypesWhenEnabled() {
        var options = ClassDumpVisitorOptions()
        options.shouldShowRawTypes = true

        let visitor = SwiftOutputVisitor(options: options)
        visitor.willBeginVisiting()

        let method = ObjCMethod(name: "test", typeString: "v16@0:8")
        let propertyState = VisitorPropertyState(properties: [])

        visitor.visitInstanceMethod(method, propertyState: propertyState)

        #expect(visitor.resultString.contains("v16@0:8"))
    }
}
