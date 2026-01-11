// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation
import Testing

@testable import ClassDumpCore

@Suite("ObjCProperty Tests", .serialized)
struct ObjCPropertyTests {
    @Test("Parse property attributes")
    func parseAttributes() {
        let property = ObjCProperty(name: "name", attributeString: "T@\"NSString\",C,N,V_name")
        #expect(property.name == "name")
        #expect(property.encodedType == "@\"NSString\"")
        #expect(property.isCopy)
        #expect(property.isNonatomic)
        #expect(!property.isReadOnly)
        #expect(!property.isWeak)
        #expect(property.ivarName == "_name")
    }

    @Test("Parse readonly property")
    func parseReadonly() {
        let property = ObjCProperty(name: "count", attributeString: "TQ,R,N")
        #expect(property.name == "count")
        #expect(property.encodedType == "Q")
        #expect(property.isReadOnly)
        #expect(property.isNonatomic)
        #expect(property.setter == nil)
    }

    @Test("Parse weak property")
    func parseWeak() {
        let property = ObjCProperty(name: "delegate", attributeString: "T@\"NSObject\",W,N,V_delegate")
        #expect(property.isWeak)
        #expect(!property.isRetain)
    }

    @Test("Custom getter and setter")
    func customAccessors() {
        let property = ObjCProperty(name: "enabled", attributeString: "TB,GisEnabled,SsetEnabled:,N")
        #expect(property.getter == "isEnabled")
        #expect(property.setter == "setEnabled:")
    }

    @Test("Default getter and setter")
    func defaultAccessors() {
        let property = ObjCProperty(name: "title", attributeString: "T@\"NSString\",&,N,V_title")
        #expect(property.getter == "title")
        #expect(property.setter == "setTitle:")
    }
}
