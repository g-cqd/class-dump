// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

@Suite("VisitorPropertyState Tests")
struct VisitorPropertyStateTests {
    @Test("Property state initialization")
    func propertyStateInit() {
        let properties = [
            ObjCProperty(name: "name", attributeString: "T@\"NSString\",R,C,V_name"),
            ObjCProperty(name: "count", attributeString: "Tq,N,V_count"),
        ]

        let state = VisitorPropertyState(properties: properties)
        #expect(state.remainingProperties.count == 2)
    }

    @Test("Property state tracks by accessor")
    func propertyStateAccessor() {
        let property = ObjCProperty(name: "name", attributeString: "T@\"NSString\",R,C,V_name")
        let state = VisitorPropertyState(properties: [property])

        // Getter should find the property
        let found = state.property(forAccessor: "name")
        #expect(found != nil)
        #expect(found?.name == "name")
    }

    @Test("Property state marks used")
    func propertyStateUsed() {
        let property = ObjCProperty(name: "test", attributeString: "Ti,V_test")
        let state = VisitorPropertyState(properties: [property])

        #expect(!state.hasUsedProperty(property))
        state.useProperty(property)
        #expect(state.hasUsedProperty(property))
        #expect(state.remainingProperties.isEmpty)
    }
}
