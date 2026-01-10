import Foundation
import Testing

@testable import ClassDumpCore

/// Tests for JSONOutputVisitor.
@Suite("JSON Output Visitor Tests")
struct JSONOutputVisitorTests {

    // MARK: - Basic Output Tests

    @Test("JSON output visitor produces valid JSON")
    func producesValidJSON() throws {
        let visitor = JSONOutputVisitor(options: .init())
        visitor.willBeginVisiting()

        let proto = ObjCProtocol(name: "TestProtocol")
        visitor.willVisitProtocol(proto)
        visitor.didVisitProtocol(proto)

        // Manually trigger JSON generation
        visitor.didEndVisiting()

        // Parse JSON to verify it's valid
        let data = visitor.resultString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["schemaVersion"] as? String == "1.0")
        #expect(json["protocols"] != nil)
        #expect(json["classes"] != nil)
        #expect(json["categories"] != nil)
    }

    @Test("JSON output includes generator info")
    func includesGeneratorInfo() throws {
        let visitor = JSONOutputVisitor(options: .init())
        visitor.willBeginVisiting()
        visitor.didEndVisiting()

        let data = visitor.resultString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let generator = json["generator"] as! [String: Any]

        #expect(generator["name"] as? String == "class-dump")
        #expect(generator["version"] as? String == "4.0.3")
        #expect(generator["timestamp"] != nil)
    }

    // MARK: - Protocol Tests

    @Test("JSON output formats protocol correctly")
    func formatsProtocolCorrectly() throws {
        let visitor = JSONOutputVisitor(options: .init())
        visitor.willBeginVisiting()

        let proto = ObjCProtocol(name: "TestProtocol")
        let nsObjectProto = ObjCProtocol(name: "NSObject")
        proto.addAdoptedProtocol(nsObjectProto)

        visitor.willVisitProtocol(proto)
        visitor.didVisitProtocol(proto)
        visitor.didEndVisiting()

        let data = visitor.resultString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let protocols = json["protocols"] as! [[String: Any]]

        #expect(protocols.count == 1)
        #expect(protocols[0]["name"] as? String == "TestProtocol")
        #expect((protocols[0]["adoptedProtocols"] as? [String])?.contains("NSObject") == true)
    }

    @Test("JSON output includes optional methods section")
    func includesOptionalMethods() throws {
        let visitor = JSONOutputVisitor(options: .init())
        visitor.willBeginVisiting()

        let proto = ObjCProtocol(name: "TestDelegate")
        visitor.willVisitProtocol(proto)

        // Required method
        let requiredMethod = ObjCMethod(name: "requiredMethod", typeString: "v16@0:8")
        visitor.visitClassMethod(requiredMethod)

        // Optional method
        visitor.willVisitOptionalMethods()
        let optionalMethod = ObjCMethod(name: "optionalMethod", typeString: "v16@0:8")
        visitor.visitClassMethod(optionalMethod)
        visitor.didVisitOptionalMethods()

        visitor.didVisitProtocol(proto)
        visitor.didEndVisiting()

        let data = visitor.resultString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let protocols = json["protocols"] as! [[String: Any]]
        let protoJSON = protocols[0]

        let classMethods = protoJSON["classMethods"] as? [[String: Any]] ?? []
        let optionalClassMethods = protoJSON["optionalClassMethods"] as? [[String: Any]] ?? []

        #expect(classMethods.count == 1)
        #expect(classMethods[0]["selector"] as? String == "requiredMethod")
        #expect(optionalClassMethods.count == 1)
        #expect(optionalClassMethods[0]["selector"] as? String == "optionalMethod")
    }

    // MARK: - Class Tests

    @Test("JSON output formats class correctly")
    func formatsClassCorrectly() throws {
        let visitor = JSONOutputVisitor(options: .init())
        visitor.willBeginVisiting()

        let objcClass = ObjCClass(name: "TestClass")
        objcClass.superclassRef = ObjCClassReference(name: "NSObject")
        let nscodingProto = ObjCProtocol(name: "NSCoding")
        objcClass.addAdoptedProtocol(nscodingProto)

        visitor.willVisitClass(objcClass)
        visitor.didVisitClass(objcClass)
        visitor.didEndVisiting()

        let data = visitor.resultString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let classes = json["classes"] as! [[String: Any]]

        #expect(classes.count == 1)
        #expect(classes[0]["name"] as? String == "TestClass")
        #expect(classes[0]["superclass"] as? String == "NSObject")
        #expect((classes[0]["adoptedProtocols"] as? [String])?.contains("NSCoding") == true)
    }

    @Test("JSON output includes Swift class metadata")
    func includesSwiftClassMetadata() throws {
        let visitor = JSONOutputVisitor(options: .init())
        visitor.willBeginVisiting()

        let objcClass = ObjCClass(name: "MyApp.SwiftClass", address: 0x1000)
        objcClass.isSwiftClass = true
        objcClass.isExported = false

        visitor.willVisitClass(objcClass)
        visitor.didVisitClass(objcClass)
        visitor.didEndVisiting()

        let data = visitor.resultString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let classes = json["classes"] as! [[String: Any]]

        #expect(classes[0]["isSwiftClass"] as? Bool == true)
        #expect(classes[0]["isExported"] as? Bool == false)
    }

    // MARK: - Category Tests

    @Test("JSON output formats category correctly")
    func formatsCategoryCorrectly() throws {
        let visitor = JSONOutputVisitor(options: .init())
        visitor.willBeginVisiting()

        let category = ObjCCategory(name: "Additions")
        category.classRef = ObjCClassReference(name: "NSString")

        visitor.willVisitCategory(category)
        visitor.didVisitCategory(category)
        visitor.didEndVisiting()

        let data = visitor.resultString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let categories = json["categories"] as! [[String: Any]]

        #expect(categories.count == 1)
        #expect(categories[0]["name"] as? String == "Additions")
        #expect(categories[0]["className"] as? String == "NSString")
    }

    // MARK: - Method Tests

    @Test("JSON output formats method with parameters")
    func formatsMethodWithParameters() throws {
        let visitor = JSONOutputVisitor(options: .init())
        visitor.willBeginVisiting()

        let objcClass = ObjCClass(name: "TestClass")
        visitor.willVisitClass(objcClass)

        // Method with parameters: - (void)doSomething:(id)arg1 withValue:(int)arg2;
        let method = ObjCMethod(name: "doSomething:withValue:", typeString: "@28@0:8@16i24")
        visitor.visitClassMethod(method)

        visitor.didVisitClass(objcClass)
        visitor.didEndVisiting()

        let data = visitor.resultString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let classes = json["classes"] as! [[String: Any]]
        let classMethods = classes[0]["classMethods"] as! [[String: Any]]

        #expect(classMethods.count == 1)
        #expect(classMethods[0]["selector"] as? String == "doSomething:withValue:")
        #expect(classMethods[0]["typeEncoding"] as? String == "@28@0:8@16i24")
    }

    // MARK: - Property Tests

    @Test("JSON output formats property attributes")
    func formatsPropertyAttributes() throws {
        let visitor = JSONOutputVisitor(options: .init())
        visitor.willBeginVisiting()

        let objcClass = ObjCClass(name: "TestClass")
        visitor.willVisitClass(objcClass)

        let property = ObjCProperty(name: "title", attributeString: "T@\"NSString\",C,N,V_title")
        visitor.visitProperty(property)

        visitor.didVisitClass(objcClass)
        visitor.didEndVisiting()

        let data = visitor.resultString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let classes = json["classes"] as! [[String: Any]]
        let properties = classes[0]["properties"] as! [[String: Any]]
        let attrs = properties[0]["attributes"] as! [String: Any]

        #expect(properties[0]["name"] as? String == "title")
        #expect(attrs["isCopy"] as? Bool == true)
        #expect(attrs["isNonatomic"] as? Bool == true)
        #expect(attrs["isReadOnly"] as? Bool == false)
    }

    // MARK: - Instance Variable Tests

    @Test("JSON output formats instance variables")
    func formatsInstanceVariables() throws {
        let visitor = JSONOutputVisitor(options: .init())
        visitor.willBeginVisiting()

        let objcClass = ObjCClass(name: "TestClass")
        visitor.willVisitClass(objcClass)

        let ivar = ObjCInstanceVariable(name: "_count", typeEncoding: "i", offset: 8)
        visitor.visitIvar(ivar)

        visitor.didVisitClass(objcClass)
        visitor.didEndVisiting()

        let data = visitor.resultString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let classes = json["classes"] as! [[String: Any]]
        let ivars = classes[0]["instanceVariables"] as! [[String: Any]]

        #expect(ivars.count == 1)
        #expect(ivars[0]["name"] as? String == "_count")
        #expect(ivars[0]["typeEncoding"] as? String == "i")
        #expect(ivars[0]["offset"] as? String == "0x8")
    }

    // MARK: - Demangling Tests

    @Test("JSON output demangles Swift names")
    func demanglesSwiftNames() throws {
        var options = ClassDumpVisitorOptions()
        options.demangleStyle = .swift

        let visitor = JSONOutputVisitor(options: options)
        visitor.willBeginVisiting()

        let objcClass = ObjCClass(name: "_TtC10TestModule9TestClass")
        visitor.willVisitClass(objcClass)
        visitor.didVisitClass(objcClass)
        visitor.didEndVisiting()

        let data = visitor.resultString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let classes = json["classes"] as! [[String: Any]]

        // Should demangle to TestModule.TestClass
        #expect(classes[0]["name"] as? String == "TestModule.TestClass")
        // Should preserve mangled name
        #expect(classes[0]["mangledName"] as? String == "_TtC10TestModule9TestClass")
    }

    @Test("JSON output preserves raw names when demangling disabled")
    func preservesRawNamesWhenDemanglingDisabled() throws {
        var options = ClassDumpVisitorOptions()
        options.demangleStyle = .none

        let visitor = JSONOutputVisitor(options: options)
        visitor.willBeginVisiting()

        let objcClass = ObjCClass(name: "_TtC10TestModule9TestClass")
        visitor.willVisitClass(objcClass)
        visitor.didVisitClass(objcClass)
        visitor.didEndVisiting()

        let data = visitor.resultString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let classes = json["classes"] as! [[String: Any]]

        #expect(classes[0]["name"] as? String == "_TtC10TestModule9TestClass")
        // No mangled name when not demangled
        #expect(classes[0]["mangledName"] == nil)
    }

    // MARK: - Address Display Tests

    @Test("JSON output shows addresses when enabled")
    func showsAddressesWhenEnabled() throws {
        var options = ClassDumpVisitorOptions()
        options.shouldShowMethodAddresses = true

        let visitor = JSONOutputVisitor(options: options)
        visitor.willBeginVisiting()

        let objcClass = ObjCClass(name: "TestClass", address: 0x1000)
        visitor.willVisitClass(objcClass)

        let method = ObjCMethod(name: "test", typeString: "v16@0:8", address: 0x1234)
        visitor.visitClassMethod(method)

        visitor.didVisitClass(objcClass)
        visitor.didEndVisiting()

        let data = visitor.resultString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let classes = json["classes"] as! [[String: Any]]
        let classMethods = classes[0]["classMethods"] as! [[String: Any]]

        #expect(classes[0]["address"] as? String == "0x1000")
        #expect(classMethods[0]["address"] as? String == "0x1234")
    }

    @Test("JSON output hides addresses when disabled")
    func hidesAddressesWhenDisabled() throws {
        var options = ClassDumpVisitorOptions()
        options.shouldShowMethodAddresses = false

        let visitor = JSONOutputVisitor(options: options)
        visitor.willBeginVisiting()

        let objcClass = ObjCClass(name: "TestClass", address: 0x1000)
        visitor.willVisitClass(objcClass)

        let method = ObjCMethod(name: "test", typeString: "v16@0:8", address: 0x1234)
        visitor.visitClassMethod(method)

        visitor.didVisitClass(objcClass)
        visitor.didEndVisiting()

        let data = visitor.resultString.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let classes = json["classes"] as! [[String: Any]]
        let classMethods = classes[0]["classMethods"] as! [[String: Any]]

        #expect(classes[0]["address"] == nil)
        #expect(classMethods[0]["address"] == nil)
    }

    // MARK: - Codable Structure Tests

    @Test("JSON output is decodable back to structures")
    func isDecodable() throws {
        let visitor = JSONOutputVisitor(options: .init())
        visitor.willBeginVisiting()

        let objcClass = ObjCClass(name: "TestClass")
        objcClass.superclassRef = ObjCClassReference(name: "NSObject")
        visitor.willVisitClass(objcClass)
        visitor.didVisitClass(objcClass)

        let proto = ObjCProtocol(name: "TestProtocol")
        visitor.willVisitProtocol(proto)
        visitor.didVisitProtocol(proto)

        visitor.didEndVisiting()

        // Decode the JSON back to our structures
        let data = visitor.resultString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ClassDumpJSON.self, from: data)

        #expect(decoded.schemaVersion == "1.0")
        #expect(decoded.classes.count == 1)
        #expect(decoded.classes[0].name == "TestClass")
        #expect(decoded.classes[0].superclass == "NSObject")
        #expect(decoded.protocols.count == 1)
        #expect(decoded.protocols[0].name == "TestProtocol")
    }
}
