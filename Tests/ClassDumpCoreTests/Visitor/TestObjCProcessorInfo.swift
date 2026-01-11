// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Testing

@testable import ClassDumpCore

@Suite("ObjCProcessorInfo Tests")
struct ObjCProcessorInfoTests {
    @Test("ObjCProcessorInfo creation")
    func processorInfoCreation() {
        let machOFile = VisitorMachOFileInfo(
            filename: "Test.app",
            archName: "arm64"
        )

        let info = ObjCProcessorInfo(
            machOFile: machOFile,
            hasObjectiveCRuntimeInfo: true,
            garbageCollectionStatus: nil
        )

        #expect(info.hasObjectiveCRuntimeInfo)
        #expect(info.garbageCollectionStatus == nil)
    }
}
