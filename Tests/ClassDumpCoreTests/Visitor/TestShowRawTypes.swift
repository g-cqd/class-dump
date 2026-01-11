// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

@Suite("Show Raw Types Tests")
struct ShowRawTypesTests {
    @Test("Method shows raw type encoding when enabled")
    func methodShowsRawType() {
        let options = ClassDumpVisitorOptions(shouldShowRawTypes: true)
        let visitor = TextClassDumpVisitor(options: options)

        let method = ObjCMethod(
            name: "doSomething:",
            typeString: "@24@0:8@16",
            address: 0
        )

        visitor.append("- ")
        visitor.appendMethod(method)

        #expect(visitor.resultString.contains("// @24@0:8@16"))
    }

    @Test("Method hides raw type encoding when disabled")
    func methodHidesRawType() {
        let options = ClassDumpVisitorOptions(shouldShowRawTypes: false)
        let visitor = TextClassDumpVisitor(options: options)

        let method = ObjCMethod(
            name: "doSomething:",
            typeString: "@24@0:8@16",
            address: 0
        )

        visitor.append("- ")
        visitor.appendMethod(method)

        #expect(!visitor.resultString.contains("// @24@0:8@16"))
    }

    @Test("Ivar shows raw type encoding when enabled")
    func ivarShowsRawType() {
        let options = ClassDumpVisitorOptions(shouldShowRawTypes: true)
        let visitor = TextClassDumpVisitor(options: options)

        let ivar = ObjCInstanceVariable(
            name: "_value",
            typeEncoding: "@\"NSString\"",
            offset: 8
        )

        visitor.appendIvar(ivar)

        #expect(visitor.resultString.contains("// @\"NSString\""))
    }

    @Test("Property shows raw attribute string when enabled")
    func propertyShowsRawType() {
        let options = ClassDumpVisitorOptions(shouldShowRawTypes: true)
        let visitor = TextClassDumpVisitor(options: options)

        let property = ObjCProperty(
            name: "name",
            attributeString: "T@\"NSString\",R,C,V_name"
        )

        if let parsedType = property.parsedType {
            visitor.appendProperty(property, parsedType: parsedType)
            #expect(visitor.resultString.contains("// T@\"NSString\",R,C,V_name"))
        }
    }

    @Test("shouldShowRawTypes defaults to false")
    func defaultIsFalse() {
        let options = ClassDumpVisitorOptions()
        #expect(!options.shouldShowRawTypes)
    }
}
