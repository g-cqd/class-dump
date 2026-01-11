// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation
import MachO
import Testing

@testable import ClassDumpCore

@Suite("SymtabCommand Tests", .serialized)
struct TestSymtabCommand {
    @Test("Parse symtab command")
    func testParseSymtab() throws {
        var data = Data()

        var cmd: UInt32 = UInt32(LC_SYMTAB)
        data.append(contentsOf: withUnsafeBytes(of: &cmd) { Array($0) })

        var cmdsize: UInt32 = 24
        data.append(contentsOf: withUnsafeBytes(of: &cmdsize) { Array($0) })

        var symoff: UInt32 = 0x1000
        data.append(contentsOf: withUnsafeBytes(of: &symoff) { Array($0) })

        var nsyms: UInt32 = 100
        data.append(contentsOf: withUnsafeBytes(of: &nsyms) { Array($0) })

        var stroff: UInt32 = 0x2000
        data.append(contentsOf: withUnsafeBytes(of: &stroff) { Array($0) })

        var strsize: UInt32 = 5000
        data.append(contentsOf: withUnsafeBytes(of: &strsize) { Array($0) })

        let symtab = try SymtabCommand(data: data, byteOrder: .little)

        #expect(symtab.cmd == UInt32(LC_SYMTAB))
        #expect(symtab.cmdsize == 24)
        #expect(symtab.symoff == 0x1000)
        #expect(symtab.nsyms == 100)
        #expect(symtab.stroff == 0x2000)
        #expect(symtab.strsize == 5000)
    }
}
