// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation
import Testing

@testable import ClassDumpCore

@Suite("ObjCClass Tests", .serialized)
struct ObjCClassTests {
    @Test("Class creation")
    func creation() {
        let aClass = ObjCClass(name: "MyClass", address: 0x2000)
        #expect(aClass.name == "MyClass")
        #expect(aClass.address == 0x2000)
        #expect(aClass.superclassName == nil)
    }

    @Test("Superclass reference")
    func superclass() {
        let aClass = ObjCClass(name: "MyClass", address: 0)
        aClass.superclassRef = ObjCClassReference(name: "NSObject", address: 0x1000)

        #expect(aClass.superclassName == "NSObject")
    }

    @Test("Adding members")
    func addMembers() {
        let aClass = ObjCClass(name: "TestClass", address: 0)

        let ivar = ObjCInstanceVariable(name: "_value", typeEncoding: "Q", offset: 8)
        aClass.addInstanceVariable(ivar)

        let method = ObjCMethod(name: "doWork", typeString: "v16@0:8")
        aClass.addInstanceMethod(method)

        let classMethod = ObjCMethod(name: "className", typeString: "@16@0:8")
        aClass.addClassMethod(classMethod)

        let property = ObjCProperty(name: "value", attributeString: "TQ,N,V_value")
        aClass.addProperty(property)

        #expect(aClass.instanceVariables.count == 1)
        #expect(aClass.instanceMethods.count == 1)
        #expect(aClass.classMethods.count == 1)
        #expect(aClass.properties.count == 1)
        #expect(aClass.hasMethods)
        #expect(aClass.allMethods.count == 2)
    }

    @Test("Class description")
    func description() {
        let aClass = ObjCClass(name: "MyView", address: 0)
        aClass.superclassRef = ObjCClassReference(name: "UIView", address: 0)

        #expect(aClass.description.contains("@interface MyView : UIView"))
    }
}
