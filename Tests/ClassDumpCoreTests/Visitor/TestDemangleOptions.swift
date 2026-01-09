// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

// MARK: - Protocol Demangling in Visitor Output Tests

@Suite("Protocol Demangling in Visitor Output")
struct ProtocolDemanglingVisitorTests {
    @Test("Protocol names demangled in class declaration - swift style")
    func protocolDemangledInClassSwiftStyle() {
        let options = ClassDumpVisitorOptions(demangleStyle: .swift)
        let visitor = TextClassDumpVisitor(options: options)

        // Correct mangled format: _TtC<module_len><module><class_len><class>
        // "MyModule" = 8 chars, "MyClass" = 7 chars
        let cls = ObjCClass(name: "_TtC8MyModule7MyClass")
        // Add a Swift protocol with mangled name
        let swiftProto = ObjCProtocol(name: "_TtP10Foundation8Hashable_")
        cls.addAdoptedProtocol(swiftProto)

        visitor.willVisitClass(cls)

        // Should demangle both class name and protocol name
        #expect(visitor.resultString.contains("MyModule.MyClass"))
        #expect(visitor.resultString.contains("Foundation.Hashable"))
        #expect(!visitor.resultString.contains("_TtP"))
    }

    @Test("Protocol names demangled in class declaration - objc style")
    func protocolDemangledInClassObjCStyle() {
        let options = ClassDumpVisitorOptions(demangleStyle: .objc)
        let visitor = TextClassDumpVisitor(options: options)

        // "MyModule" = 8 chars, "MyClass" = 7 chars
        let cls = ObjCClass(name: "_TtC8MyModule7MyClass")
        let swiftProto = ObjCProtocol(name: "_TtP10Foundation8Hashable_")
        cls.addAdoptedProtocol(swiftProto)

        visitor.willVisitClass(cls)

        // ObjC style should strip module prefix
        #expect(visitor.resultString.contains("MyClass"))
        #expect(visitor.resultString.contains("Hashable"))
        #expect(!visitor.resultString.contains("MyModule."))
        #expect(!visitor.resultString.contains("Foundation."))
    }

    @Test("Protocol names not demangled when style is none")
    func protocolNotDemangledWhenStyleNone() {
        let options = ClassDumpVisitorOptions(demangleStyle: .none)
        let visitor = TextClassDumpVisitor(options: options)

        // "MyModule" = 8 chars, "MyClass" = 7 chars
        let cls = ObjCClass(name: "_TtC8MyModule7MyClass")
        let swiftProto = ObjCProtocol(name: "_TtP10Foundation8Hashable_")
        cls.addAdoptedProtocol(swiftProto)

        visitor.willVisitClass(cls)

        // Should keep mangled names
        #expect(visitor.resultString.contains("_TtC8MyModule7MyClass"))
        #expect(visitor.resultString.contains("_TtP10Foundation8Hashable_"))
    }

    @Test("Multiple protocols demangled in class declaration")
    func multipleProtocolsDemangledInClass() {
        let options = ClassDumpVisitorOptions(demangleStyle: .swift)
        let visitor = TextClassDumpVisitor(options: options)

        let cls = ObjCClass(name: "TestClass")
        let proto1 = ObjCProtocol(name: "_TtP10Foundation8Hashable_")
        let proto2 = ObjCProtocol(name: "_TtP10Foundation9Equatable_")
        let proto3 = ObjCProtocol(name: "NSCoding")  // ObjC protocol, not mangled
        cls.addAdoptedProtocol(proto1)
        cls.addAdoptedProtocol(proto2)
        cls.addAdoptedProtocol(proto3)

        visitor.willVisitClass(cls)

        #expect(visitor.resultString.contains("Foundation.Hashable"))
        #expect(visitor.resultString.contains("Foundation.Equatable"))
        #expect(visitor.resultString.contains("NSCoding"))
    }

    @Test("Protocol parent protocols demangled")
    func protocolParentProtocolsDemangled() {
        let options = ClassDumpVisitorOptions(demangleStyle: .swift)
        let visitor = TextClassDumpVisitor(options: options)

        let proto = ObjCProtocol(name: "_TtP8MyModule10MyProtocol_")
        let parentProto = ObjCProtocol(name: "_TtP10Foundation8Hashable_")
        proto.addAdoptedProtocol(parentProto)

        visitor.willVisitProtocol(proto)

        // Protocol name and parent protocol should both be demangled
        #expect(visitor.resultString.contains("@protocol MyModule.MyProtocol"))
        #expect(visitor.resultString.contains("<Foundation.Hashable>"))
    }

    @Test("Category protocols demangled")
    func categoryProtocolsDemangled() {
        let options = ClassDumpVisitorOptions(demangleStyle: .swift)
        let visitor = TextClassDumpVisitor(options: options)

        let category = ObjCCategory(name: "SwiftAdditions")
        category.classRef = ObjCClassReference(name: "NSObject")
        let swiftProto = ObjCProtocol(name: "_TtP8MyModule12MyProtocol01_")
        category.addAdoptedProtocol(swiftProto)

        visitor.willVisitCategory(category)

        #expect(visitor.resultString.contains("@interface NSObject (SwiftAdditions)"))
        #expect(visitor.resultString.contains("MyModule.MyProtocol01"))
    }

    @Test("Long protocol name demangled correctly")
    func longProtocolNameDemangled() {
        let options = ClassDumpVisitorOptions(demangleStyle: .swift)
        let visitor = TextClassDumpVisitor(options: options)

        let cls = ObjCClass(name: "TestClass")
        // Real-world example from XCSourceControl
        let proto = ObjCProtocol(name: "_TtP15XCSourceControl30XCSourceControlXPCBaseProtocol_")
        cls.addAdoptedProtocol(proto)

        visitor.willVisitClass(cls)

        #expect(visitor.resultString.contains("XCSourceControl.XCSourceControlXPCBaseProtocol"))
    }
}
