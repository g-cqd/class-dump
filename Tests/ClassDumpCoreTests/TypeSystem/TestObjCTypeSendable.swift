// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

@Suite("ObjCType Sendable Tests")
struct ObjCTypeSendableTests {

    @Test("ObjCType is Sendable")
    func objcTypeSendable() async {
        let type = ObjCType.int
        let task = Task { type }
        let result = await task.value
        #expect(result == .int)
    }

    @Test("ObjCTypedMember is Sendable")
    func objcTypedMemberSendable() async {
        let member = ObjCTypedMember(type: .double, name: "value")
        let task = Task { member.name }
        let result = await task.value
        #expect(result == "value")
    }

    @Test("ObjCTypeName is Sendable")
    func objcTypeNameSendable() async {
        let name = ObjCTypeName(name: "CGPoint")
        let task = Task { name.description }
        let result = await task.value
        #expect(result == "CGPoint")
    }

    @Test("ObjCMethodType is Sendable")
    func objcMethodTypeSendable() async {
        let methodType = ObjCMethodType(type: .void, offset: "0")
        let task = Task { methodType.offset }
        let result = await task.value
        #expect(result == "0")
    }
}
