// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation
import Testing

@testable import ClassDumpCore

@Suite("ObjCMetadata Tests", .serialized)
struct ObjCMetadataTests {
    @Test("Empty metadata")
    func emptyMetadata() {
        let metadata = ObjCMetadata()
        #expect(metadata.classes.isEmpty)
        #expect(metadata.protocols.isEmpty)
        #expect(metadata.categories.isEmpty)
        #expect(metadata.imageInfo == nil)
    }

    @Test("Sorted metadata")
    func sortedMetadata() {
        let class1 = ObjCClass(name: "ZClass", address: 0)
        let class2 = ObjCClass(name: "AClass", address: 0)

        let proto1 = ObjCProtocol(name: "ZProtocol", address: 0)
        let proto2 = ObjCProtocol(name: "AProtocol", address: 0)

        let metadata = ObjCMetadata(
            classes: [class1, class2],
            protocols: [proto1, proto2],
            categories: []
        )

        let sorted = metadata.sorted()
        #expect(sorted.classes[0].name == "AClass")
        #expect(sorted.classes[1].name == "ZClass")
        #expect(sorted.protocols[0].name == "AProtocol")
        #expect(sorted.protocols[1].name == "ZProtocol")
    }
}
