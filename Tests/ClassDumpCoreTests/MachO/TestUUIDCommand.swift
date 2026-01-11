// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation
import MachO
import Testing

@testable import ClassDumpCore

@Suite("UUIDCommand Tests", .serialized)
struct TestUUIDCommand {
    @Test("Parse UUID command")
    func testParseUUID() throws {
        var data = Data()

        var cmd: UInt32 = UInt32(LC_UUID)
        data.append(contentsOf: withUnsafeBytes(of: &cmd) { Array($0) })

        var cmdsize: UInt32 = 24
        data.append(contentsOf: withUnsafeBytes(of: &cmdsize) { Array($0) })

        // Add a known UUID (16 bytes)
        let uuidBytes: [UInt8] = [
            0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF,
            0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF,
        ]
        data.append(contentsOf: uuidBytes)

        let uuidCmd = try UUIDCommand(data: data)

        #expect(uuidCmd.cmd == UInt32(LC_UUID))
        #expect(uuidCmd.cmdsize == 24)
        #expect(uuidCmd.uuidString.count == 36)  // UUID string format
    }
}
