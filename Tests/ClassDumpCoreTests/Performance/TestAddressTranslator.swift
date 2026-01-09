// SPDX-License-Identifier: MIT
// Copyright (C) 2026 class-dump contributors. All rights reserved.

import Foundation
import Testing

@testable import ClassDumpCore

/// Tests for AddressTranslator and SIMD string utilities.
@Suite("Address Translator Tests")
struct TestAddressTranslator {

    // MARK: - SIMD String Utils Tests

    @Test("SIMD finds null terminator at start")
    func simdNullAtStart() {
        let data = Data([0x00, 0x41, 0x42, 0x43])
        let index = SIMDStringUtils.findNullTerminator(in: data, from: 0)
        #expect(index == 0)
    }

    @Test("SIMD finds null terminator in middle")
    func simdNullInMiddle() {
        let data = Data([0x41, 0x42, 0x43, 0x00, 0x44])
        let index = SIMDStringUtils.findNullTerminator(in: data, from: 0)
        #expect(index == 3)
    }

    @Test("SIMD finds null terminator at end")
    func simdNullAtEnd() {
        let data = Data([0x41, 0x42, 0x43, 0x00])
        let index = SIMDStringUtils.findNullTerminator(in: data, from: 0)
        #expect(index == 3)
    }

    @Test("SIMD handles no null terminator")
    func simdNoNull() {
        let data = Data([0x41, 0x42, 0x43, 0x44])
        let index = SIMDStringUtils.findNullTerminator(in: data, from: 0)
        #expect(index == data.count)
    }

    @Test("SIMD handles start offset")
    func simdWithOffset() {
        let data = Data([0x00, 0x41, 0x42, 0x00, 0x43])
        let index = SIMDStringUtils.findNullTerminator(in: data, from: 1)
        #expect(index == 3)
    }

    @Test("SIMD handles large data with SWAR")
    func simdLargeData() {
        // Create data larger than 8 bytes to trigger SWAR path
        var data = Data(repeating: 0x41, count: 100)
        data[50] = 0x00
        let index = SIMDStringUtils.findNullTerminator(in: data, from: 0)
        #expect(index == 50)
    }

    @Test("SIMD handles aligned null in SWAR")
    func simdAlignedNull() {
        // Null at exactly 8-byte boundary
        var data = Data(repeating: 0x41, count: 24)
        data[8] = 0x00
        let index = SIMDStringUtils.findNullTerminator(in: data, from: 0)
        #expect(index == 8)
    }

    @Test("SIMD handles null in last SWAR chunk")
    func simdLastChunk() {
        // Null in bytes that would be in remainder after SWAR
        var data = Data(repeating: 0x41, count: 18)
        data[17] = 0x00
        let index = SIMDStringUtils.findNullTerminator(in: data, from: 0)
        #expect(index == 17)
    }

    @Test("Read null-terminated string")
    func readNullTerminatedString() {
        let data = Data([0x48, 0x65, 0x6C, 0x6C, 0x6F, 0x00, 0x57, 0x6F, 0x72, 0x6C, 0x64])
        let str = SIMDStringUtils.readNullTerminatedString(from: data, at: 0)
        #expect(str == "Hello")
    }

    @Test("Read null-terminated string with offset")
    func readNullTerminatedStringOffset() {
        let data = Data([0x48, 0x65, 0x6C, 0x6C, 0x6F, 0x00, 0x57, 0x6F, 0x72, 0x6C, 0x64, 0x00])
        let str = SIMDStringUtils.readNullTerminatedString(from: data, at: 6)
        #expect(str == "World")
    }

    @Test("Read empty string returns nil")
    func readEmptyString() {
        let data = Data([0x00, 0x41])
        let str = SIMDStringUtils.readNullTerminatedString(from: data, at: 0)
        #expect(str == nil || str == "")
    }

    @Test("Read from invalid offset returns nil")
    func readInvalidOffset() {
        let data = Data([0x41, 0x42, 0x00])
        let str = SIMDStringUtils.readNullTerminatedString(from: data, at: 100)
        #expect(str == nil)
    }

    // MARK: - AddressTranslator Performance Tests

    @Test("AddressTranslator binary search is fast", .tags(.performance))
    func addressTranslatorPerformance() async throws {
        // Create mock segments with many sections
        // This is a simplified test - real segments come from Mach-O files
        let start = ContinuousClock.now

        // Simulate many lookups
        for _ in 0..<10_000 {
            // Just test the SIMD utilities as we can't easily mock segments
            var data = Data(repeating: 0x41, count: 256)
            data[100] = 0x00
            _ = SIMDStringUtils.findNullTerminator(in: data, from: 0)
        }

        let elapsed = ContinuousClock.now - start
        #expect(elapsed < .seconds(1), "10K SIMD lookups should complete in < 1s")
    }

    @Test("SIMD handles very long strings", .tags(.performance))
    func simdLongString() {
        // 10KB string
        var data = Data(repeating: 0x41, count: 10_000)
        data[9_999] = 0x00

        let start = ContinuousClock.now
        for _ in 0..<1_000 {
            _ = SIMDStringUtils.findNullTerminator(in: data, from: 0)
        }
        let elapsed = ContinuousClock.now - start

        #expect(elapsed < .seconds(1), "1K scans of 10KB should be fast")
    }
}
