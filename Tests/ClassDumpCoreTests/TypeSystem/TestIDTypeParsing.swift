// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

@Suite("ID Type Parsing")
struct IDTypeParsingTests {
    @Test("Parse plain id")
    func parseIDPlain() throws {
        let type = try ObjCType.parse("@")
        #expect(type == .id(className: nil, protocols: []))
    }

    @Test("Parse id with class name")
    func parseIDWithClassName() throws {
        let type = try ObjCType.parse("@\"NSString\"")
        #expect(type == .id(className: "NSString", protocols: []))
    }

    @Test("Parse id with protocol")
    func parseIDWithProtocol() throws {
        let type = try ObjCType.parse("@\"<NSCopying>\"")
        #expect(type == .id(className: nil, protocols: ["NSCopying"]))
    }

    @Test("Parse id with class and protocol")
    func parseIDWithClassAndProtocol() throws {
        let type = try ObjCType.parse("@\"NSArray<NSFastEnumeration>\"")
        #expect(type == .id(className: "NSArray", protocols: ["NSFastEnumeration"]))
    }

    @Test("Parse id with multiple protocols")
    func parseIDWithMultipleProtocols() throws {
        let type = try ObjCType.parse("@\"NSObject<NSCopying, NSCoding>\"")
        #expect(type == .id(className: "NSObject", protocols: ["NSCopying", "NSCoding"]))
    }
}
