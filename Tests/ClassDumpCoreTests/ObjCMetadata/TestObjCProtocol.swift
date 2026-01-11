// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation
import Testing

@testable import ClassDumpCore

@Suite("ObjCProtocol Tests", .serialized)
struct ObjCProtocolTests {
    @Test("Protocol creation")
    func creation() {
        let proto = ObjCProtocol(name: "NSCopying", address: 0x1000)
        #expect(proto.name == "NSCopying")
        #expect(proto.address == 0x1000)
    }

    @Test("Adding methods")
    func addMethods() {
        let proto = ObjCProtocol(name: "TestProtocol", address: 0)

        let instanceMethod = ObjCMethod(name: "doSomething", typeString: "v16@0:8")
        proto.addInstanceMethod(instanceMethod)

        let classMethod = ObjCMethod(name: "sharedInstance", typeString: "@16@0:8")
        proto.addClassMethod(classMethod)

        let optInstanceMethod = ObjCMethod(name: "optionalMethod", typeString: "v16@0:8")
        proto.addOptionalInstanceMethod(optInstanceMethod)

        #expect(proto.instanceMethods.count == 1)
        #expect(proto.classMethods.count == 1)
        #expect(proto.optionalInstanceMethods.count == 1)
        #expect(proto.hasMethods)
        #expect(proto.allMethods.count == 3)
    }

    @Test("Adopted protocols")
    func adoptedProtocols() {
        let proto = ObjCProtocol(name: "NSCopying", address: 0)
        let adopted = ObjCProtocol(name: "NSObject", address: 0)
        proto.addAdoptedProtocol(adopted)

        #expect(proto.adoptedProtocolNames == ["NSObject"])
        #expect(proto.adoptedProtocolsString == "<NSObject>")
    }
}
