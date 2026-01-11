// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation
import MachO
import Testing

@testable import ClassDumpCore

@Suite("SourceVersionCommand Tests", .serialized)
struct TestSourceVersionCommand {
    @Test("Parse source version command")
    func testParseSourceVersion() throws {
        var data = Data()

        var cmd: UInt32 = UInt32(LC_SOURCE_VERSION)
        data.append(contentsOf: withUnsafeBytes(of: &cmd) { Array($0) })

        var cmdsize: UInt32 = 16
        data.append(contentsOf: withUnsafeBytes(of: &cmdsize) { Array($0) })

        // Version 1.2.3.4.5 packed
        // A.B.C.D.E where A is 24 bits, B-E are 10 bits each
        var version: UInt64 = (1 << 40) | (2 << 30) | (3 << 20) | (4 << 10) | 5
        data.append(contentsOf: withUnsafeBytes(of: &version) { Array($0) })

        let srcVersion = try SourceVersionCommand(data: data, byteOrder: .little)

        #expect(srcVersion.cmd == UInt32(LC_SOURCE_VERSION))
        #expect(srcVersion.versionString == "1.2.3.4.5")
    }
}
