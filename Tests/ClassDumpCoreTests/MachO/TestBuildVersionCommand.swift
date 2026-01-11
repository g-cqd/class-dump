// SPDX-License-Identifier: MIT
// Copyright © 2026 class-dump contributors. All rights reserved.

import Foundation
import MachO
import Testing

@testable import ClassDumpCore

@Suite("BuildVersionCommand Tests", .serialized)
struct TestBuildVersionCommand {
    @Test("Parse build version command")
    func testParseBuildVersion() throws {
        var data = Data()

        var cmd: UInt32 = UInt32(LC_BUILD_VERSION)
        data.append(contentsOf: withUnsafeBytes(of: &cmd) { Array($0) })

        var cmdsize: UInt32 = 24
        data.append(contentsOf: withUnsafeBytes(of: &cmdsize) { Array($0) })

        var platform: UInt32 = 1  // macOS
        data.append(contentsOf: withUnsafeBytes(of: &platform) { Array($0) })

        // minos = 14.0.0 (packed as 0x000E0000)
        var minos: UInt32 = 0x000E_0000
        data.append(contentsOf: withUnsafeBytes(of: &minos) { Array($0) })

        // sdk = 14.0.0
        var sdk: UInt32 = 0x000E_0000
        data.append(contentsOf: withUnsafeBytes(of: &sdk) { Array($0) })

        var ntools: UInt32 = 0
        data.append(contentsOf: withUnsafeBytes(of: &ntools) { Array($0) })

        let buildVersion = try BuildVersionCommand(data: data, byteOrder: .little)

        #expect(buildVersion.cmd == UInt32(LC_BUILD_VERSION))
        #expect(buildVersion.platform == .macOS)
        #expect(buildVersion.minos.major == 14)
        #expect(buildVersion.tools.isEmpty)
    }

    @Test("Build platform names")
    func testBuildPlatformNames() {
        #expect(BuildPlatform.macOS.name == "macOS")
        #expect(BuildPlatform.iOS.name == "iOS")
        #expect(BuildPlatform.visionOS.name == "visionOS")
    }
}
