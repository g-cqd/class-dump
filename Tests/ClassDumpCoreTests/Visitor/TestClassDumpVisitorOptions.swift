// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

@Suite("ClassDumpVisitorOptions Tests")
struct ClassDumpVisitorOptionsTests {
    @Test("ClassDumpVisitorOptions defaults")
    func visitorOptionsDefaults() {
        let options = ClassDumpVisitorOptions()

        #expect(options.shouldShowStructureSection)
        #expect(options.shouldShowProtocolSection)
    }

    @Test("ClassDumpVisitorOptions custom")
    func visitorOptionsCustom() {
        let options = ClassDumpVisitorOptions(
            shouldShowStructureSection: false,
            shouldShowProtocolSection: false
        )

        #expect(!options.shouldShowStructureSection)
        #expect(!options.shouldShowProtocolSection)
    }
}
