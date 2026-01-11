// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

@Suite("VisitorMachOFileInfo Tests")
struct VisitorMachOFileInfoTests {
    @Test("VisitorMachOFileInfo initialization")
    func machOFileInfoInit() {
        let info = VisitorMachOFileInfo(
            filename: "/path/to/file",
            archName: "arm64"
        )

        #expect(info.filename == "/path/to/file")
        #expect(info.archName == "arm64")
        #expect(info.uuid == nil)
        #expect(!info.isEncrypted)
    }

    @Test("VisitorMachOFileInfo with dylib")
    func machOFileInfoDylib() {
        let dylib = DylibInfo(
            name: "libTest.dylib",
            currentVersion: "1.0.0",
            compatibilityVersion: "1.0.0"
        )

        let info = VisitorMachOFileInfo(
            filename: "/usr/lib/libTest.dylib",
            archName: "x86_64",
            filetype: 6,  // MH_DYLIB
            dylibIdentifier: dylib
        )

        #expect(info.filetype == 6)
        #expect(info.dylibIdentifier?.name == "libTest.dylib")
    }
}
