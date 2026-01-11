// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation
import MachO
import Testing

@testable import ClassDumpCore

@Suite("Symbol Tests", .serialized)
struct TestSymbol {
    @Test("Symbol type flags")
    func testSymbolTypeFlags() {
        let external = SymbolTypeFlags(rawValue: UInt8(N_EXT))
        #expect(external.isExternal == true)

        let defined = SymbolTypeFlags(rawValue: UInt8(N_SECT) | UInt8(N_EXT))
        #expect(defined.isExternal == true)
        #expect(defined.isInSection == true)
        #expect(defined.isUndefined == false)
    }

    @Test("Symbol short type description")
    func testSymbolShortType() {
        var nlist = nlist_64()
        nlist.n_type = UInt8(N_SECT) | UInt8(N_EXT)
        nlist.n_value = 0x1000

        let symbol = Symbol(name: "_main", nlist64: nlist)
        #expect(symbol.shortTypeDescription == "S")  // External in section
        #expect(symbol.isDefined == true)
        #expect(symbol.isExternal == true)
    }

    @Test("ObjC class name extraction")
    func testObjCClassName() {
        let className = Symbol.className(from: "_OBJC_CLASS_$_NSObject")
        #expect(className == "NSObject")

        let nonClass = Symbol.className(from: "_some_function")
        #expect(nonClass == nil)
    }
}
