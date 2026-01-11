// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

@Suite("DylibInfo Tests")
struct DylibInfoTests {
    @Test("DylibInfo creation")
    func dylibInfoCreation() {
        let info = DylibInfo(
            name: "MyLib",
            currentVersion: "2.5.0",
            compatibilityVersion: "1.0.0"
        )

        #expect(info.name == "MyLib")
        #expect(info.currentVersion == "2.5.0")
        #expect(info.compatibilityVersion == "1.0.0")
    }
}
