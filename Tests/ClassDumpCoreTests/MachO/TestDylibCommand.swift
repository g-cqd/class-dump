// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation
import MachO
import Testing

@testable import ClassDumpCore

@Suite("DylibCommand Tests", .serialized)
struct TestDylibCommand {
    @Test("Parse dylib command")
    func testParseDylib() throws {
        var data = Data()

        var cmd: UInt32 = UInt32(LC_LOAD_DYLIB)
        data.append(contentsOf: withUnsafeBytes(of: &cmd) { Array($0) })

        var cmdsize: UInt32 = 56  // Will be updated based on string length
        data.append(contentsOf: withUnsafeBytes(of: &cmdsize) { Array($0) })

        // name offset (starts after the fixed fields = 24 bytes)
        var nameOffset: UInt32 = 24
        data.append(contentsOf: withUnsafeBytes(of: &nameOffset) { Array($0) })

        var timestamp: UInt32 = 2
        data.append(contentsOf: withUnsafeBytes(of: &timestamp) { Array($0) })

        // current_version = 1.2.3 (packed)
        var currentVersion: UInt32 = (1 << 16) | (2 << 8) | 3
        data.append(contentsOf: withUnsafeBytes(of: &currentVersion) { Array($0) })

        // compatibility_version = 1.0.0
        var compatVersion: UInt32 = (1 << 16)
        data.append(contentsOf: withUnsafeBytes(of: &compatVersion) { Array($0) })

        // Name string
        let name = "/usr/lib/libSystem.B.dylib\0"
        data.append(name.data(using: .utf8)!)

        let dylib = try DylibCommand(data: data, byteOrder: .little)

        #expect(dylib.cmd == UInt32(LC_LOAD_DYLIB))
        #expect(dylib.name == "/usr/lib/libSystem.B.dylib")
        #expect(dylib.currentVersion.major == 1)
        #expect(dylib.currentVersion.minor == 2)
        #expect(dylib.currentVersion.patch == 3)
        #expect(dylib.compatibilityVersion.major == 1)
        #expect(dylib.dylibType == .load)
    }

    @Test("Version string formatting")
    func testVersionString() {
        let version1 = DylibCommand.Version(packed: (1 << 16) | (2 << 8) | 3)
        #expect(version1.description == "1.2.3")

        let version2 = DylibCommand.Version(packed: (10 << 16) | (0 << 8) | 0)
        #expect(version2.description == "10.0")
    }
}
