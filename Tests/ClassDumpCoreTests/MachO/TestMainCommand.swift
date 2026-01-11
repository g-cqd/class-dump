// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation
import MachO
import Testing

@testable import ClassDumpCore

@Suite("MainCommand Tests", .serialized)
struct TestMainCommand {
    @Test("Parse main command")
    func testParseMain() throws {
        var data = Data()

        var cmd: UInt32 = 0x8000_0028  // LC_MAIN
        data.append(contentsOf: withUnsafeBytes(of: &cmd) { Array($0) })

        var cmdsize: UInt32 = 24
        data.append(contentsOf: withUnsafeBytes(of: &cmdsize) { Array($0) })

        var entryoff: UInt64 = 0x1234
        data.append(contentsOf: withUnsafeBytes(of: &entryoff) { Array($0) })

        var stacksize: UInt64 = 0
        data.append(contentsOf: withUnsafeBytes(of: &stacksize) { Array($0) })

        let main = try MainCommand(data: data, byteOrder: .little)

        #expect(main.cmd == 0x8000_0028)
        #expect(main.entryoff == 0x1234)
        #expect(main.stacksize == 0)
        #expect(main.mustUnderstandToExecute == true)
    }
}
