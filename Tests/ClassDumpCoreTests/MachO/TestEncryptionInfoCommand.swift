// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation
import MachO
import Testing

@testable import ClassDumpCore

@Suite("EncryptionInfoCommand Tests", .serialized)
struct TestEncryptionInfoCommand {
    @Test("Parse encryption info command")
    func testParseEncryptionInfo() throws {
        var data = Data()

        var cmd: UInt32 = UInt32(LC_ENCRYPTION_INFO_64)
        data.append(contentsOf: withUnsafeBytes(of: &cmd) { Array($0) })

        var cmdsize: UInt32 = 24
        data.append(contentsOf: withUnsafeBytes(of: &cmdsize) { Array($0) })

        var cryptoff: UInt32 = 0x4000
        data.append(contentsOf: withUnsafeBytes(of: &cryptoff) { Array($0) })

        var cryptsize: UInt32 = 0x10000
        data.append(contentsOf: withUnsafeBytes(of: &cryptsize) { Array($0) })

        var cryptid: UInt32 = 0  // Not encrypted
        data.append(contentsOf: withUnsafeBytes(of: &cryptid) { Array($0) })

        var pad: UInt32 = 0
        data.append(contentsOf: withUnsafeBytes(of: &pad) { Array($0) })

        let encInfo = try EncryptionInfoCommand(data: data, byteOrder: .little, is64Bit: true)

        #expect(encInfo.cmd == UInt32(LC_ENCRYPTION_INFO_64))
        #expect(encInfo.cryptoff == 0x4000)
        #expect(encInfo.cryptsize == 0x10000)
        #expect(encInfo.isEncrypted == false)
    }
}
