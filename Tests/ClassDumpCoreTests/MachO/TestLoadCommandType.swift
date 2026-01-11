// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation
import MachO
import Testing

@testable import ClassDumpCore

@Suite("LoadCommandType Tests", .serialized)
struct TestLoadCommandType {
    @Test("Load command type names")
    func testLoadCommandTypeNames() {
        #expect(LoadCommandType.segment.name == "LC_SEGMENT")
        #expect(LoadCommandType.segment64.name == "LC_SEGMENT_64")
        #expect(LoadCommandType.symtab.name == "LC_SYMTAB")
        #expect(LoadCommandType.dysymtab.name == "LC_DYSYMTAB")
        #expect(LoadCommandType.uuid.name == "LC_UUID")
        #expect(LoadCommandType.main.name == "LC_MAIN")
        #expect(LoadCommandType.buildVersion.name == "LC_BUILD_VERSION")
    }

    @Test("Must understand to execute")
    func testMustUnderstandToExecute() {
        #expect(LoadCommandType.main.mustUnderstandToExecute == true)
        #expect(LoadCommandType.dyldInfoOnly.mustUnderstandToExecute == true)
        #expect(LoadCommandType.loadWeakDylib.mustUnderstandToExecute == true)
        #expect(LoadCommandType.segment.mustUnderstandToExecute == false)
        #expect(LoadCommandType.uuid.mustUnderstandToExecute == false)
    }

    @Test("Name for unknown command")
    func testUnknownCommandName() {
        let name = LoadCommandType.name(for: 0xDEAD_BEEF)
        #expect(name.contains("UNKNOWN"))
        #expect(name.contains("deadbeef"))
    }
}
