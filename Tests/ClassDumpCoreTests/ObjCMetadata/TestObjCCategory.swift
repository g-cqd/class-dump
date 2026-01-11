// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation
import Testing

@testable import ClassDumpCore

@Suite("ObjCCategory Tests", .serialized)
struct ObjCCategoryTests {
    @Test("Category creation")
    func creation() {
        let category = ObjCCategory(name: "Private", address: 0x3000)
        #expect(category.name == "Private")
        #expect(category.address == 0x3000)
        #expect(category.className == nil)
    }

    @Test("Class reference")
    func classRef() {
        let category = ObjCCategory(name: "Additions", address: 0)
        category.classRef = ObjCClassReference(name: "NSString", address: 0)

        #expect(category.className == "NSString")
    }

    @Test("Category description")
    func description() {
        let category = ObjCCategory(name: "Private", address: 0)
        category.classRef = ObjCClassReference(name: "NSObject", address: 0)

        #expect(category.description.contains("@interface NSObject (Private)"))
    }
}
