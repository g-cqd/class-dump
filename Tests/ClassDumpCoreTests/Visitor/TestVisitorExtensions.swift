// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

// MARK: - ObjCClass Visitor Extensions

@Suite("ObjCClass Visitor Extensions")
struct ObjCClassVisitorExtensionsTests {
    @Test("ObjCClass protocols extension")
    func objcClassProtocols() {
        let cls = ObjCClass(name: "TestClass")
        let proto1 = ObjCProtocol(name: "NSCoding")
        let proto2 = ObjCProtocol(name: "NSCopying")
        cls.addAdoptedProtocol(proto1)
        cls.addAdoptedProtocol(proto2)

        #expect(cls.protocols.count == 2)
        #expect(cls.protocols.contains("NSCoding"))
        #expect(cls.protocols.contains("NSCopying"))
    }
}

// MARK: - ObjCCategory Visitor Extensions

@Suite("ObjCCategory Visitor Extensions")
struct ObjCCategoryVisitorExtensionsTests {
    @Test("ObjCCategory classNameForVisitor")
    func objcCategoryClassName() {
        let category = ObjCCategory(name: "Helper")
        category.classRef = ObjCClassReference(name: "NSString")
        #expect(category.classNameForVisitor == "NSString")

        let categoryNoClass = ObjCCategory(name: "Unknown")
        #expect(categoryNoClass.classNameForVisitor == "")
    }

    @Test("ObjCCategory protocols extension")
    func objcCategoryProtocols() {
        let category = ObjCCategory(name: "Helper")
        category.classRef = ObjCClassReference(name: "NSString")
        let proto = ObjCProtocol(name: "NSSecureCoding")
        category.addAdoptedProtocol(proto)

        #expect(category.protocols.count == 1)
        #expect(category.protocols.first == "NSSecureCoding")
    }
}

// MARK: - ObjCProtocol Visitor Extensions

@Suite("ObjCProtocol Visitor Extensions")
struct ObjCProtocolVisitorExtensionsTests {
    @Test("ObjCProtocol protocols extension")
    func objcProtocolProtocols() {
        let proto = ObjCProtocol(name: "MyProtocol")
        let nsObjectProto = ObjCProtocol(name: "NSObject")
        proto.addAdoptedProtocol(nsObjectProto)

        #expect(proto.protocols.count == 1)
        #expect(proto.protocols.first == "NSObject")
    }
}

// MARK: - ObjCMethod Visitor Extensions

@Suite("ObjCMethod Visitor Extensions")
struct ObjCMethodVisitorExtensionsTests {
    @Test("ObjCMethod typeEncoding alias")
    func methodTypeEncoding() {
        let method = ObjCMethod(name: "test", typeString: "v16@0:8")
        #expect(method.typeEncoding == "v16@0:8")
    }

    @Test("ObjCMethod parsedTypes")
    func methodParsedTypes() {
        let method = ObjCMethod(name: "test", typeString: "v16@0:8")
        let types = method.parsedTypes

        #expect(types != nil)
        #expect(types?.count == 3)
        #expect(types?[0].type == .void)
    }

    @Test("ObjCMethod returnType")
    func methodReturnType() {
        let method = ObjCMethod(name: "getValue", typeString: "i16@0:8")
        #expect(method.returnType == .int)
    }

    @Test("ObjCMethod argumentTypes")
    func methodArgumentTypes() {
        let method = ObjCMethod(name: "setValue:", typeString: "v24@0:8i16")
        let args = method.argumentTypes

        #expect(args.count == 1)
        #expect(args[0] == .int)
    }
}

// MARK: - ObjCInstanceVariable Visitor Extensions

@Suite("ObjCInstanceVariable Visitor Extensions")
struct ObjCInstanceVariableVisitorExtensionsTests {
    @Test("ObjCInstanceVariable typeEncoding property")
    func ivarTypeEncoding() {
        let ivar = ObjCInstanceVariable(name: "_value", typeEncoding: "i", offset: 8)
        #expect(ivar.typeEncoding == "i")
    }

    @Test("ObjCInstanceVariable parsedType")
    func ivarParsedType() {
        let ivar = ObjCInstanceVariable(name: "_string", typeEncoding: "@\"NSString\"", offset: 8)
        #expect(ivar.parsedType == .id(className: "NSString", protocols: []))
    }
}

// MARK: - ObjCProperty Visitor Extensions

@Suite("ObjCProperty Visitor Extensions")
struct ObjCPropertyVisitorExtensionsTests {
    @Test("ObjCProperty parsedType")
    func propertyParsedType() {
        let property = ObjCProperty(name: "name", attributeString: "T@\"NSString\",R,C,V_name")
        let type = property.parsedType

        #expect(type == .id(className: "NSString", protocols: []))
    }

    @Test("ObjCProperty attributeComponents")
    func propertyAttributeComponents() {
        let property = ObjCProperty(name: "count", attributeString: "Tq,N,V_count")
        let components = property.attributeComponents

        #expect(components.count == 3)
        #expect(components[0] == "Tq")
        #expect(components[1] == "N")
        #expect(components[2] == "V_count")
    }
}
