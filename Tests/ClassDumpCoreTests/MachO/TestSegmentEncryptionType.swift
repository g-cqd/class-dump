// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation
import MachO
import Testing

@testable import ClassDumpCore

@Suite("SegmentEncryptionType Tests", .serialized)
struct TestSegmentEncryptionType {
    @Test("Encryption type from magic")
    func testEncryptionTypeFromMagic() {
        let none = SegmentEncryptionType(magic: SegmentEncryptionType.magicNone)
        #expect(none.canDecrypt == true)

        let aes = SegmentEncryptionType(magic: SegmentEncryptionType.magicAES)
        #expect(aes.canDecrypt == true)

        let blowfish = SegmentEncryptionType(magic: SegmentEncryptionType.magicBlowfish)
        #expect(blowfish.canDecrypt == true)

        let unknown = SegmentEncryptionType(magic: 0xDEAD_BEEF)
        #expect(unknown.canDecrypt == false)
    }
}
