// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation
import Testing

@testable import ClassDumpCore

@Suite("ObjC2RuntimeStructs Tests", .serialized)
struct ObjC2RuntimeStructsTests {
    @Test("ObjC2ListHeader parsing")
    func listHeader() throws {
        var data = Data()
        // entsize = 24, count = 5
        data.append(contentsOf: [0x18, 0x00, 0x00, 0x00])  // entsize
        data.append(contentsOf: [0x05, 0x00, 0x00, 0x00])  // count

        var cursor = try DataCursor(data: data, offset: 0)
        let header = try ObjC2ListHeader(cursor: &cursor, byteOrder: .little)

        #expect(header.entsize == 24)
        #expect(header.count == 5)
        #expect(header.actualEntsize == 24)
    }

    @Test("ObjC2ListHeader with flags")
    func listHeaderWithFlags() throws {
        var data = Data()
        // entsize = 24 with flag bits set
        data.append(contentsOf: [0x1B, 0x00, 0x00, 0x00])  // entsize (24 | 3)
        data.append(contentsOf: [0x03, 0x00, 0x00, 0x00])  // count

        var cursor = try DataCursor(data: data, offset: 0)
        let header = try ObjC2ListHeader(cursor: &cursor, byteOrder: .little)

        #expect(header.entsize == 0x1B)
        #expect(header.actualEntsize == 24)  // flags masked out
        #expect(header.count == 3)
    }

    @Test("ObjC2ImageInfo parsing")
    func imageInfo() throws {
        var data = Data()
        // version = 0, flags = 0x42 (supports GC, signed class RO)
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x00])  // version
        data.append(contentsOf: [0x42, 0x00, 0x00, 0x00])  // flags

        var cursor = try DataCursor(data: data, offset: 0)
        let imageInfo = try ObjC2ImageInfo(cursor: &cursor, byteOrder: .little)

        #expect(imageInfo.version == 0)
        #expect(imageInfo.flags == 0x42)
        #expect(imageInfo.parsedFlags.contains(.supportsGC))
    }

    @Test("ObjC2Class Swift flag")
    func classSwiftFlag() throws {
        var data = Data()
        // 64-bit class structure with Swift bit set in data pointer
        for _ in 0..<4 {  // isa, superclass, cache, vtable
            data.append(contentsOf: [0x00, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        }
        // data pointer with Swift bit (bit 0) set
        data.append(contentsOf: [0x01, 0x20, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        // reserved1, reserved2, reserved3
        for _ in 0..<3 {
            data.append(contentsOf: [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        }

        var cursor = try DataCursor(data: data, offset: 0)
        let objc2Class = try ObjC2Class(cursor: &cursor, byteOrder: .little, is64Bit: true)

        #expect(objc2Class.isSwiftClass)
        #expect(objc2Class.dataPointer == 0x2000)  // bits stripped
    }
}
